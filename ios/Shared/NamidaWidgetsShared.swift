// by claude
#if NAMIDA_WIDGETS
import ActivityKit
import AppIntents
import Foundation

/// what the app and the widget extension both know: where the widget data lives and how buttons reach the player.
enum NamidaWidgetsShared {
  static let appGroupId = sideloadedAppGroupId() ?? "group.com.msob7y.namida"
  static let nowPlayingKind = "NamidaNowPlaying"
  static let playPauseControlKind = "NamidaPlayPause"

  /// set by the app's widgets plugin once its flutter engine is up, intents run in the app's process.
  /// returns once dart performed the press, the system keeps the app awake until then.
  static var mediaActionHandler: ((String) async -> Void)?

  /// a button pressed before the engine was up, performed once the plugin registers unless it's stale by then.
  static var pendingMediaAction: (action: String, date: Date)?

  enum Key {
    static let title = "title"
    static let message = "message"
    static let playing = "playing"
    static let favourite = "favourite"
  }

  static let defaults = UserDefaults(suiteName: appGroupId)

  /// the extension can't read the app's container, the artwork is copied here, downscaled.
  static let artworkURL: URL? = {
    let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
    return container?.appendingPathComponent("widget_artwork.jpg")
  }()

  /// sideloading tools (AltStore, SideStore) register their own group under the signing team and list it in the app's Info.plist.
  /// the extension reads it from the containing app.
  private static func sideloadedAppGroupId() -> String? {
    let key = "ALTAppGroups"
    if let groups = Bundle.main.object(forInfoDictionaryKey: key) as? [String], let group = groups.first {
      return group
    }
    let bundleURL = Bundle.main.bundleURL
    guard bundleURL.pathExtension == "appex" else { return nil }
    let appURL = bundleURL.deletingLastPathComponent().deletingLastPathComponent()
    let groups = Bundle(url: appURL)?.object(forInfoDictionaryKey: key) as? [String]
    return groups?.first
  }
}

@available(iOS 17.0, *)
struct NamidaLyricsActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var title: String
    var artist: String?
    var line: String?
  }
}

/// widget & control center buttons. an audio playback intent always runs in the app's process, never the extension's.
@available(iOS 17.0, *)
struct NamidaMediaIntent: AudioPlaybackIntent {
  /// raw values are the dart side's `HomeWidgetMediaAction` names.
  enum Action: String {
    case playPause
    case next
    case previous
    case favourite
  }

  static let title: LocalizedStringResource = "Namida playback"
  static let isDiscoverable = false

  @Parameter(title: "Action")
  var action: String

  init() {
    action = Action.playPause.rawValue
  }

  init(_ action: Action) {
    self.action = action.rawValue
  }

  @MainActor
  func perform() async throws -> some IntentResult {
    #if NAMIDA_WIDGETS_EXTENSION
    return .result()
    #else
    if let mediaActionHandler = NamidaWidgetsShared.mediaActionHandler {
      await mediaActionHandler(action)
      return .result()
    }
    // -- launched in the background with no flutter engine to play through, the app opens and performs it once dart is up
    NamidaWidgetsShared.pendingMediaAction = (action, Date())
    throw needsToContinueInForegroundError()
    #endif
  }
}

#if !NAMIDA_WIDGETS_EXTENSION
/// unavailable in app extensions, which never perform the intent anyway.
@available(iOS 17.0, *)
extension NamidaMediaIntent: ForegroundContinuableIntent {}
#endif
#endif
