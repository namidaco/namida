package com.msob7y.namida

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Build
import com.ryanheise.audioservice.AudioService
import io.flutter.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

// -- channel methods that don't need the activity, android auto & wear start the engine without it
class NamidaAppChannels private constructor(private val context: Context) {
  companion object {
    const val CHANNELNAME = "namida"
    const val CHANNELNAME_STORAGE = "namida/storage"

    private var instance: NamidaAppChannels? = null

    fun get(context: Context): NamidaAppChannels {
      return instance ?: NamidaAppChannels(context.applicationContext).also { instance = it }
    }
  }

  val storageUtils by lazy { StorageUtils(context) }
  val safUtils by lazy { SafUtils(context) }
  private var multicastLock: WifiManager.MulticastLock? = null

  fun configureEngine(flutterEngine: FlutterEngine) {
    try {
      flutterEngine.plugins.add(FAudioTagger())
    } catch (e: Exception) {
      Log.e("NamidaAppChannels", "Error registering plugin FAudioTagger, com.msob7y.namida.FAudioTagger", e)
    }

    val messenger = flutterEngine.dartExecutor.binaryMessenger
    val channel = MethodChannel(messenger, CHANNELNAME)
    channel.setMethodCallHandler { call, result ->
      if (!handleCall(call, result, channel)) result.notImplemented()
    }
    MethodChannel(messenger, CHANNELNAME_STORAGE).setMethodCallHandler { call, result ->
      if (!handleStorageCall(call, result)) result.notImplemented()
    }
  }

  fun handleCall(call: MethodCall, result: MethodChannel.Result, channel: MethodChannel): Boolean {
    when (call.method) {
      "sdk" -> result.success(Build.VERSION.SDK_INT)
      "consumeExitReports" -> {
        CoroutineScope(Dispatchers.IO).launch {
          val reports = try {
            ProcessExitReporter.consume(context)
          } catch (_: Exception) {
            emptyList()
          }
          withContext(Dispatchers.Main) { result.success(reports) }
        }
      }
      "sendBroadcast" -> {
        val action = call.argument<String>("action")
        val extras = call.argument<Map<String, Any?>>("extras")
        if (action == null) {
          result.success(false)
        } else {
          val intent = Intent(action)
          intent.addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES)
          extras?.forEach { (key, value) ->
            when (value) {
              is String -> intent.putExtra(key, value)
              is Boolean -> intent.putExtra(key, value)
              is Int -> intent.putExtra(key, value)
              is Long -> intent.putExtra(key, value)
              is Double -> intent.putExtra(key, value)
            }
          }
          context.sendBroadcast(intent)
          result.success(true)
        }
      }
      "sendSuperLyric" -> {
        val sent = SuperLyricPublisher.send(
          title = call.argument<String>("title"),
          artist = call.argument<String>("artist"),
          album = call.argument<String>("album"),
          text = call.argument<String>("text"),
          startMS = call.argument<Number>("startMS")?.toLong() ?: 0L,
          endMS = call.argument<Number>("endMS")?.toLong() ?: 0L,
        )
        result.success(sent)
      }
      "releaseSuperLyric" -> {
        SuperLyricPublisher.release()
        result.success(null)
      }
      "setMulticastLock" -> {
        val enabled = call.argument<Boolean>("enabled") ?: false
        try {
          if (enabled) {
            if (multicastLock == null) {
              val wifi = context.getSystemService(Context.WIFI_SERVICE) as WifiManager
              multicastLock = wifi.createMulticastLock("namida_mdns").apply { setReferenceCounted(false) }
            }
            multicastLock?.acquire()
          } else {
            multicastLock?.let { if (it.isHeld) it.release() }
          }
          result.success(true)
        } catch (e: Exception) {
          result.error("MULTICAST_LOCK", e.message, null)
        }
      }
      "getSystemAccentColor" -> result.success(SystemAccentColor.get(context))
      "getSystemProxy" -> result.success(NetworkProxyManager.getSystemProxy(context))
      "listenSystemProxy" -> {
        NetworkProxyManager.listenSystemProxy(context) { channel.invokeMethod("onSystemProxyChanged", null) }
        result.success(null)
      }
      "setAppProxy" -> {
        NetworkProxyManager.setAppProxy(call.arguments as Map<*, *>?)
        result.success(null)
      }
      "setUsbDacHandlerEnabled" -> {
        val enabled = call.argument<Boolean>("enabled") ?: false
        val state = if (enabled) PackageManager.COMPONENT_ENABLED_STATE_ENABLED else PackageManager.COMPONENT_ENABLED_STATE_DISABLED
        context.packageManager.setComponentEnabledSetting(
          ComponentName(context, "com.msob7y.namida.UsbDacHandler"),
          state,
          PackageManager.DONT_KILL_APP,
        )
        result.success(null)
      }
      "consumeTrustedMediaCommand" -> {
        val wasSelfSent = NamidaConstants.selfSentMediaCommand
        NamidaConstants.selfSentMediaCommand = false
        val wasFromBrowsingClient = AudioService.consumePlayRequestedByBrowsingClient()
        result.success(wasSelfSent || wasFromBrowsingClient)
      }
      else -> return false
    }
    return true
  }

  fun handleStorageCall(call: MethodCall, result: MethodChannel.Result): Boolean {
    when (call.method) {
      "getStorageDirs" -> {
        storageUtils.fillStoragePaths()
        result.success(storageUtils.storagePaths)
      }

      "getStorageDirsData" -> {
        result.success(storageUtils.getStorageDirsData())
      }

      "getStorageDirsCache" -> {
        result.success(storageUtils.getStorageDirsCache())
      }

      "getRealPath" -> {
        val contentUri = call.argument<String?>("contentUri")
        val realPath = storageUtils.contentUriToPath(Uri.parse(contentUri))
        result.success(realPath)
      }

      "safHasAccess" -> {
        val path = call.argument<String?>("path")
        result.success(path != null && safUtils.findDocumentUri(path) != null)
      }

      "safCopyFile" -> {
        val source = call.argument<String?>("source")
        val dest = call.argument<String?>("dest")
        if (source == null || dest == null) {
          result.success("source or dest parameters aren't provided")
        } else {
          CoroutineScope(Dispatchers.IO).launch {
            val error = safUtils.copyFileToDocument(source, dest)
            withContext(Dispatchers.Main) { result.success(error) }
          }
        }
      }

      "safTreeHasAccess" -> {
        val treeUri = call.argument<String?>("treeUri")
        result.success(treeUri != null && safUtils.hasTreeAccess(Uri.parse(treeUri)))
      }

      "safListTree" -> {
        val treeUri = call.argument<String?>("treeUri")
        if (treeUri == null) {
          result.success(null)
        } else {
          CoroutineScope(Dispatchers.IO).launch {
            val listing = safUtils.listTree(Uri.parse(treeUri))
            withContext(Dispatchers.Main) { result.success(listing) }
          }
        }
      }

      "safCopyDocument" -> {
        val documentUri = call.argument<String?>("documentUri")
        val dest = call.argument<String?>("dest")
        if (documentUri == null || dest == null) {
          result.success("documentUri or dest parameters aren't provided")
        } else {
          CoroutineScope(Dispatchers.IO).launch {
            val error = safUtils.copyDocumentToFile(Uri.parse(documentUri), dest)
            withContext(Dispatchers.Main) { result.success(error) }
          }
        }
      }

      else -> return false
    }
    return true
  }
}
