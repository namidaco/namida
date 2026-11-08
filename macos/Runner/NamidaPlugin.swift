// by claude
import CFNetwork
import Cocoa
import FlutterMacOS
import SystemConfiguration

/// the `namida` channel: files & links (oauth redirects, party invites) the app was opened with, and the system proxy.
final class NamidaPlugin: NSObject, FlutterPlugin, FlutterAppLifecycleDelegate {
  private let channel: FlutterMethodChannel
  private let openedUrls: NamidaOpenedUrls
  private var proxyStore: SCDynamicStore?

  private init(channel: FlutterMethodChannel) {
    self.channel = channel
    openedUrls = NamidaOpenedUrls(channel: channel)
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "namida", binaryMessenger: registrar.messenger)
    let instance = NamidaPlugin(channel: channel)
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.addApplicationDelegate(instance)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "consumeOpenedUrls":
      result(openedUrls.consume())

    case "getSystemProxy":
      result(Self.systemProxy())

    case "listenSystemProxy":
      listenSystemProxy()
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - system proxy

  /// the http proxy of the system settings as `{host, port, bypass}`, pac setups aren't read.
  private static func systemProxy() -> [String: Any]? {
    guard let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any] else { return nil }
    let host: String
    let port: Int
    if settings["HTTPSEnable"] as? Int == 1, let httpsHost = settings["HTTPSProxy"] as? String, let httpsPort = settings["HTTPSPort"] as? Int {
      host = httpsHost
      port = httpsPort
    } else if settings["HTTPEnable"] as? Int == 1, let httpHost = settings["HTTPProxy"] as? String, let httpPort = settings["HTTPPort"] as? Int {
      host = httpHost
      port = httpPort
    } else {
      return nil
    }
    var bypass = settings["ExceptionsList"] as? [String] ?? []
    if settings["ExcludeSimpleHostnames"] as? Int == 1 { bypass.append("<local>") }
    return ["host": host, "port": port, "bypass": bypass]
  }

  /// the store calls back only when the proxy settings change.
  private func listenSystemProxy() {
    if proxyStore != nil { return }
    var context = SCDynamicStoreContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
    let callback: SCDynamicStoreCallBack = { _, _, info in
      guard let info else { return }
      let plugin = Unmanaged<NamidaPlugin>.fromOpaque(info).takeUnretainedValue()
      plugin.channel.invokeMethod("onSystemProxyChanged", arguments: nil)
    }
    guard let store = SCDynamicStoreCreate(nil, "namida" as CFString, callback, &context) else { return }
    let proxiesKey = SCDynamicStoreKeyCreateProxies(nil)
    SCDynamicStoreSetNotificationKeys(store, [proxiesKey] as CFArray, nil)
    guard let source = SCDynamicStoreCreateRunLoopSource(nil, store, 0) else { return }
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    proxyStore = store
  }

  /// swift imports `handleOpenURLs:` as `handleOpen(_:)`, the selector is spelled out so it's called either way.
  @objc(handleOpenURLs:)
  func handleOpen(_ urls: [URL]) -> Bool {
    openedUrls.add(urls)
    return true
  }
}
