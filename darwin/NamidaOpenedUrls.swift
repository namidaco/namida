// by claude
#if os(iOS)
import Flutter
#else
import FlutterMacOS
#endif
import Foundation

/// files & links the app was opened with (ex: "open in", an oauth redirect, a party invite), for both the ios and macos runners.
/// held until dart listens, a cold start delivers them before any dart runs.
final class NamidaOpenedUrls {
  private let channel: FlutterMethodChannel
  private var pendingItems: [String] = []
  private var isDartListening = false

  init(channel: FlutterMethodChannel) {
    self.channel = channel
  }

  /// the items dart missed, the next ones go straight to it.
  func consume() -> [String] {
    isDartListening = true
    let items = pendingItems
    pendingItems.removeAll()
    return items
  }

  func add(_ urls: [URL]) {
    let items = urls.map { $0.isFileURL ? $0.namidaStandardPath : $0.absoluteString }
    add(items: items)
  }

  func add(items: [String]) {
    if isDartListening {
      channel.invokeMethod("onOpenedUrls", arguments: items)
    } else {
      pendingItems.append(contentsOf: items)
    }
  }
}

extension URL {
  /// `/private/var/...` and `/var/...` name the same folder, dart only ever sees the short form.
  var namidaStandardPath: String {
    return (path as NSString).standardizingPath
  }
}
