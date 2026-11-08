// by claude
package com.msob7y.namida

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.ProxyInfo
import android.os.Build
import java.io.IOException
import java.net.Authenticator
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.PasswordAuthentication
import java.net.Proxy
import java.net.ProxySelector
import java.net.SocketAddress
import java.net.URI

/** system proxy reads, and the proxy java networking uses (media3 http streams, notification artwork). */
object NetworkProxyManager {
  private var proxyChangeReceiver: BroadcastReceiver? = null
  private var lastSystemProxy: Map<String, Any?>? = null
  private var onSystemProxyChanged: (() -> Unit)? = null

  fun getSystemProxy(context: Context): Map<String, Any?>? {
    val connectivityManager = context.getSystemService(ConnectivityManager::class.java) ?: return null
    return proxyInfoToMap(connectivityManager.defaultProxy)
  }

  private fun proxyInfoToMap(info: ProxyInfo?): Map<String, Any?>? {
    if (info == null) return null
    val host = info.host
    val port = info.port
    if (host.isNullOrEmpty() || port <= 0) return null
    return mapOf("host" to host, "port" to port, "bypass" to info.exclusionList?.toList())
  }

  /**
   * the system sends PROXY_CHANGE only when the default proxy changes (also on a network switch), nothing runs otherwise.
   * stays registered for the process, the flutter engine outlives the activity. a new engine replaces [onChanged].
   */
  fun listenSystemProxy(context: Context, onChanged: () -> Unit) {
    onSystemProxyChanged = onChanged
    if (proxyChangeReceiver != null) return
    val appContext = context.applicationContext
    lastSystemProxy = getSystemProxy(appContext)
    val receiver = object : BroadcastReceiver() {
      override fun onReceive(receiverContext: Context, intent: Intent) {
        // -- sticky, the current value also arrives right after registering
        val proxy = getSystemProxy(appContext)
        if (proxy == lastSystemProxy) return
        lastSystemProxy = proxy
        onSystemProxyChanged?.invoke()
      }
    }
    val filter = IntentFilter(android.net.Proxy.PROXY_CHANGE_ACTION)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      appContext.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
    } else {
      appContext.registerReceiver(receiver, filter)
    }
    proxyChangeReceiver = receiver
  }

  private var originalSelector: ProxySelector? = null
  private var didSetAuthenticator = false
  @Volatile private var appProxy: AppProxy? = null

  /** null restores the system behavior. */
  fun setAppProxy(args: Map<*, *>?) {
    if (args == null) {
      appProxy = null
      originalSelector?.let { ProxySelector.setDefault(it) }
      originalSelector = null
      if (didSetAuthenticator) {
        Authenticator.setDefault(null)
        didSetAuthenticator = false
      }
      return
    }

    val host = args["host"] as String
    val port = (args["port"] as Number).toInt()
    val bypass = (args["bypass"] as List<*>).filterIsInstance<String>()
    val proxy = Proxy(Proxy.Type.HTTP, InetSocketAddress.createUnresolved(host, port))
    appProxy = AppProxy(proxy, BypassRules.parse(bypass))
    if (originalSelector == null) {
      originalSelector = ProxySelector.getDefault()
      ProxySelector.setDefault(AppProxySelector)
    }

    val username = args["username"] as String?
    val password = args["password"] as String?
    if (username != null) {
      Authenticator.setDefault(ProxyAuthenticator(username, password ?: ""))
      didSetAuthenticator = true
    } else if (didSetAuthenticator) {
      Authenticator.setDefault(null)
      didSetAuthenticator = false
    }
  }

  private object AppProxySelector : ProxySelector() {
    override fun select(uri: URI?): List<Proxy> {
      val proxy = appProxy ?: return listOf(Proxy.NO_PROXY)
      val scheme = uri?.scheme?.lowercase()
      if (scheme != "http" && scheme != "https") return listOf(Proxy.NO_PROXY)
      val host = uri.host ?: return listOf(Proxy.NO_PROXY)
      if (proxy.bypass.matches(host)) return listOf(Proxy.NO_PROXY)
      return listOf(proxy.proxy)
    }

    override fun connectFailed(uri: URI?, sa: SocketAddress?, ioe: IOException?) {}
  }

  private class ProxyAuthenticator(private val username: String, private val password: String) : Authenticator() {
    override fun getPasswordAuthentication(): PasswordAuthentication? {
      if (requestorType != RequestorType.PROXY) return null
      return PasswordAuthentication(username, password.toCharArray())
    }
  }

  private class AppProxy(val proxy: Proxy, val bypass: BypassRules)

  /** same matching as the dart `NetworkProxy` and rhttp: curl style entries plus `<local>` for hostnames without a dot. */
  private class BypassRules(
    private val matchesAll: Boolean,
    private val matchesSimpleHostnames: Boolean,
    private val domains: List<String>,
    private val ipRanges: List<IpRange>,
  ) {
    companion object {
      fun parse(entries: List<String>): BypassRules {
        var matchesAll = false
        var matchesSimpleHostnames = false
        val domains = mutableListOf<String>()
        val ipRanges = mutableListOf<IpRange>()
        for (entry in entries) {
          when (entry) {
            "*" -> matchesAll = true
            "<local>" -> matchesSimpleHostnames = true
            else -> {
              val ipRange = IpRange.tryParse(entry)
              if (ipRange != null) {
                ipRanges.add(ipRange)
              } else {
                val domain = entry.removePrefix(".").lowercase()
                if (domain.isNotEmpty()) domains.add(domain)
              }
            }
          }
        }
        return BypassRules(matchesAll, matchesSimpleHostnames, domains, ipRanges)
      }
    }

    fun matches(hostPre: String): Boolean {
      if (matchesAll) return true
      val host = hostPre.removeSurrounding("[", "]")
      val ipBytes = parseIpLiteral(host)
      if (ipBytes != null) return ipRanges.any { it.contains(ipBytes) }
      if (matchesSimpleHostnames && !host.contains('.')) return true
      val hostLower = host.lowercase()
      return domains.any { domain ->
        hostLower == domain || (hostLower.length > domain.length && hostLower.endsWith(domain) && hostLower[hostLower.length - domain.length - 1] == '.')
      }
    }
  }

  private class IpRange(private val networkBytes: ByteArray, private val prefixLength: Int) {
    companion object {
      fun tryParse(entry: String): IpRange? {
        val separatorIndex = entry.indexOf('/')
        val ipText = if (separatorIndex == -1) entry else entry.substring(0, separatorIndex)
        val bytes = parseIpLiteral(ipText) ?: return null
        val maxPrefixLength = bytes.size * 8
        val prefixLength = if (separatorIndex == -1) maxPrefixLength else entry.substring(separatorIndex + 1).toIntOrNull()
        if (prefixLength == null || prefixLength < 0 || prefixLength > maxPrefixLength) return null
        return IpRange(bytes, prefixLength)
      }
    }

    fun contains(ipBytes: ByteArray): Boolean {
      if (ipBytes.size != networkBytes.size) return false
      val fullBytes = prefixLength shr 3
      for (i in 0 until fullBytes) {
        if (ipBytes[i] != networkBytes[i]) return false
      }
      val remainingBits = prefixLength and 7
      if (remainingBits == 0) return true
      val mask = (0xFF shl (8 - remainingBits)) and 0xFF
      return (ipBytes[fullBytes].toInt() and mask) == (networkBytes[fullBytes].toInt() and mask)
    }
  }

  private val ipv4LiteralRegex = Regex("""^\d{1,3}(\.\d{1,3}){3}$""")

  /** literals only, a hostname never reaches [InetAddress.getByName] so no dns lookup happens. */
  private fun parseIpLiteral(host: String): ByteArray? {
    if (!host.contains(':') && !ipv4LiteralRegex.matches(host)) return null
    return try {
      InetAddress.getByName(host).address
    } catch (_: Exception) {
      null
    }
  }
}
