// by claude
import Cocoa
import FlutterMacOS

/// the `namida` channel: files & links (oauth redirects, party invites) the app was opened with.
final class NamidaPlugin: NSObject, FlutterPlugin, FlutterAppLifecycleDelegate {
  private let openedUrls: NamidaOpenedUrls

  private init(channel: FlutterMethodChannel) {
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

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// swift imports `handleOpenURLs:` as `handleOpen(_:)`, the selector is spelled out so it's called either way.
  @objc(handleOpenURLs:)
  func handleOpen(_ urls: [URL]) -> Bool {
    openedUrls.add(urls)
    return true
  }
}
