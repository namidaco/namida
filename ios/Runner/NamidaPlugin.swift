// by claude
import AVFoundation
import Flutter
import UIKit

/// the `namida` channel: files & links the app was opened with, app icons, background work and the audio session rate.
final class NamidaPlugin: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate {
  private let openedUrls: NamidaOpenedUrls

  private init(channel: FlutterMethodChannel) {
    openedUrls = NamidaOpenedUrls(channel: channel)
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "namida", binaryMessenger: registrar.messenger())
    let instance = NamidaPlugin(channel: channel)
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.addSceneDelegate(instance)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "sdk":
      let version = ProcessInfo.processInfo.operatingSystemVersion
      result(version.majorVersion * 10000 + version.minorVersion * 100 + version.patchVersion)

    case "consumeOpenedUrls":
      result(openedUrls.consume())

    case "isAppIconEnabled":
      let key = args?["key"] as? String
      let current = UIApplication.shared.alternateIconName
      result(key == Self.primaryIconKey ? current == nil : current == key)

    case "changeAppIcon":
      changeAppIcon(key: args?["key"] as? String, result: result)

    case "setPreferredSampleRate":
      let sampleRate = args?["sampleRate"] as? Int ?? 0
      setPreferredSampleRate(sampleRate)
      result(nil)

    case "setKeepRunningInBackground":
      let keepRunning = args?["keepRunning"] as? Bool ?? false
      NamidaBackgroundWork.shared.setRunning(keepRunning)
      result(nil)

    case "updateBackgroundWorkProgress":
      let progress = args?["progress"] as? Int ?? 0
      let totalProgress = args?["totalProgress"] as? Int ?? 0
      let itemsCount = args?["itemsCount"] as? Int ?? 0
      NamidaBackgroundWork.shared.updateProgress(completed: Int64(progress), total: Int64(totalProgress), itemsCount: itemsCount)
      result(nil)

    case "openInFiles":
      let path = args?["path"] as? String ?? ""
      let isDirectory = args?["isDirectory"] as? Bool ?? false
      openInFiles(path: path, isDirectory: isDirectory)
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - opened urls

  @objc(scene:willConnectToSession:options:)
  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions?) -> Bool {
    guard let contexts = connectionOptions?.urlContexts, !contexts.isEmpty else { return false }
    addOpenedUrls(contexts)
    return true
  }

  @objc(scene:openURLContexts:)
  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    addOpenedUrls(URLContexts)
    return true
  }

  private func addOpenedUrls(_ contexts: Set<UIOpenURLContext>) {
    var urls: [URL] = []
    for context in contexts {
      let url = context.url
      if let sharedTexts = NamidaShareUrl.parse(url) {
        openedUrls.add(items: sharedTexts)
        continue
      }
      if url.isFileURL && context.options.openInPlace {
        // -- opened in place from another app's folder, readable only while access is held, which is the whole session
        _ = url.startAccessingSecurityScopedResource()
      }
      urls.append(url)
    }
    if !urls.isEmpty { openedUrls.add(urls) }
  }

  // MARK: - app icons

  private static let primaryIconKey = "namida"

  private func changeAppIcon(key: String?, result: @escaping FlutterResult) {
    let application = UIApplication.shared
    guard application.supportsAlternateIcons else {
      result(false)
      return
    }
    let iconName = key == nil || key == Self.primaryIconKey ? nil : key
    application.setAlternateIconName(iconName) { error in
      result(error == nil)
    }
  }

  // MARK: - files

  /// the files app opens at `shareddocuments://<folder>`.
  private func openInFiles(path: String, isDirectory: Bool) {
    let folder = isDirectory ? path : (path as NSString).deletingLastPathComponent
    var components = URLComponents()
    components.scheme = "shareddocuments"
    components.path = folder
    guard let url = components.url else { return }
    UIApplication.shared.open(url)
  }

  // MARK: - audio

  /// the session runs at the hardware rate the system picked, an output at the source rate needs no resampling.
  private func setPreferredSampleRate(_ sampleRate: Int) {
    guard sampleRate > 0 else { return }
    let session = AVAudioSession.sharedInstance()
    guard session.sampleRate != Double(sampleRate) else { return }
    try? session.setPreferredSampleRate(Double(sampleRate))
  }
}

enum NamidaPaths {
  static var containerPath: String {
    return (NSHomeDirectory() as NSString).standardizingPath
  }

  static func isInsideContainer(_ path: String) -> Bool {
    return isPath(path, inside: containerPath)
  }

  static func isPath(_ path: String, inside folder: String) -> Bool {
    return path == folder || path.hasPrefix(folder + "/")
  }

  /// one is the other or holds it.
  static func overlap(_ path: String, _ otherPath: String) -> Bool {
    return isPath(path, inside: otherPath) || isPath(otherPath, inside: path)
  }

  /// the view controller every picker is presented from.
  static func topViewController() -> UIViewController? {
    let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let windows = windowScenes.flatMap { $0.windows }
    let keyWindow = windows.first { $0.isKeyWindow } ?? windows.first
    var top = keyWindow?.rootViewController
    while let presented = top?.presentedViewController, !presented.isBeingDismissed {
      top = presented
    }
    return top
  }
}
