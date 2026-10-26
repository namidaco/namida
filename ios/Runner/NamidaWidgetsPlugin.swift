// by claude
#if NAMIDA_WIDGETS
import ActivityKit
import Flutter
import ImageIO
import UIKit
import WidgetKit

/// the `namida/widgets` channel: home widget data, the lyrics live activity, and the buttons of the widget & control center.
/// compiled only with the widget extension, a build that had to drop it leaves dart without this channel.
final class NamidaWidgetsPlugin: NSObject, FlutterPlugin {
  private static let artworkMaxPixelSize = 360
  private static let pendingMediaActionMaxAge: TimeInterval = 30
  private static let queuedMediaActionTimeout: TimeInterval = 10

  private let channel: FlutterMethodChannel
  private let artworkQueue = DispatchQueue(label: "namida.widgets.artwork", qos: .utility)

  /// presses wait here until dart's player is ready.
  private var queuedMediaActions: [(action: String, waiter: MediaActionWaiter?)] = []
  private var isDartAttached = false

  /// changes are only reported once dart asked.
  private var isWidgetsStateRequested = false
  private var hasWidgets: Bool?

  /// an `Activity<NamidaLyricsActivityAttributes>`, typed loosely since stored properties can't be limited to ios 16.2.
  private var liveActivity: AnyObject?
  /// updates & ends run one after the other, unordered ones could leave an older line shown.
  private var liveActivityTask: Task<Void, Never>?
  /// an activity the user swiped away stays away until the next item.
  private var dismissedActivityTitle: String?

  private init(channel: FlutterMethodChannel) {
    self.channel = channel
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "namida/widgets", binaryMessenger: registrar.messenger())
    let instance = NamidaWidgetsPlugin(channel: channel)
    registrar.addMethodCallDelegate(instance, channel: channel)
    NamidaWidgetsShared.mediaActionHandler = { [weak instance] action in
      await instance?.performMediaAction(action)
    }
    if let pending = NamidaWidgetsShared.pendingMediaAction {
      NamidaWidgetsShared.pendingMediaAction = nil
      let age = Date().timeIntervalSince(pending.date)
      if age < pendingMediaActionMaxAge {
        instance.queuedMediaActions.append((pending.action, nil))
      }
    }
    let notificationCenter = NotificationCenter.default
    notificationCenter.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak instance] _ in
      instance?.refreshHasWidgets()
    }
    notificationCenter.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: .main) { _ in
      Self.endAllLiveActivitiesBeforeExit()
    }
    instance.endStaleLiveActivities()
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "isAvailable":
      // -- a dart (re)start, presses wait for its player again
      isDartAttached = false
      guard #available(iOS 16.2, *) else {
        result(false)
        return
      }
      isWidgetsStateRequested = true
      hasWidgets = nil
      result(true)
      refreshHasWidgets()

    case "attachMediaActions":
      isDartAttached = true
      let queued = queuedMediaActions
      queuedMediaActions.removeAll()
      for queuedAction in queued {
        invokeMediaAction(queuedAction.action, waiter: queuedAction.waiter)
      }
      result(nil)

    case "updateHomeWidget":
      updateHomeWidget(args)
      result(nil)

    case "updateLiveActivity":
      let title = args["title"] as? String ?? ""
      let artist = args["artist"] as? String
      let line = args["line"] as? String
      let isSupported = updateLiveActivity(title: title, artist: artist, line: line)
      result(isSupported)

    case "endLiveActivity":
      endLiveActivity()
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - media actions

  /// a press also means a widget or control exists, one added while the app was away starts getting its data.
  @MainActor
  private func performMediaAction(_ action: String) async {
    refreshHasWidgets()
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      let waiter = MediaActionWaiter(continuation)
      if isDartAttached {
        invokeMediaAction(action, waiter: waiter)
        return
      }
      queuedMediaActions.append((action, waiter))
      // -- dart may never attach (ex: a failed init), the intent isn't left hanging and the stale press is dropped
      DispatchQueue.main.asyncAfter(deadline: .now() + Self.queuedMediaActionTimeout) { [weak self] in
        self?.queuedMediaActions.removeAll { $0.waiter === waiter }
        waiter.resume()
      }
    }
  }

  private func invokeMediaAction(_ action: String, waiter: MediaActionWaiter?) {
    channel.invokeMethod("onMediaAction", arguments: action) { _ in
      waiter?.resume()
    }
  }

  // MARK: - home widget

  /// a widget added while the app was away gets its data once the app comes back.
  private func refreshHasWidgets() {
    guard isWidgetsStateRequested else { return }
    WidgetCenter.shared.getCurrentConfigurations { [weak self] configurations in
      let hasWidgets = Self.hasNowPlayingWidget(configurations)
      DispatchQueue.main.async {
        guard let self, hasWidgets != self.hasWidgets else { return }
        self.hasWidgets = hasWidgets
        self.channel.invokeMethod("onHasWidgetsChanged", arguments: hasWidgets)
      }
    }
  }

  /// unknown counts as present, so the data keeps being written.
  private static func hasNowPlayingWidget(_ configurations: Result<[WidgetInfo], Error>) -> Bool {
    guard let widgets = try? configurations.get() else { return true }
    return widgets.contains { $0.kind == NamidaWidgetsShared.nowPlayingKind }
  }

  /// only the keys dart sent changed, a missing key keeps its stored value.
  private func updateHomeWidget(_ data: [String: Any]) {
    guard let defaults = NamidaWidgetsShared.defaults else { return }
    typealias Key = NamidaWidgetsShared.Key
    if data.keys.contains(Key.title) {
      let title = data[Key.title] as? String
      defaults.set(title, forKey: Key.title)
    }
    if data.keys.contains(Key.message) {
      let message = data[Key.message] as? String
      defaults.set(message, forKey: Key.message)
    }
    if let isPlaying = data[Key.playing] as? Bool {
      defaults.set(isPlaying, forKey: Key.playing)
    }
    if let isFavourite = data[Key.favourite] as? Bool {
      defaults.set(isFavourite, forKey: Key.favourite)
    }
    guard data.keys.contains("image") else {
      Self.reloadNowPlaying()
      return
    }
    let imageUri = data["image"] as? String
    artworkQueue.async {
      Self.writeArtwork(fromUri: imageUri)
      DispatchQueue.main.async {
        Self.reloadNowPlaying()
      }
    }
  }

  private static func writeArtwork(fromUri imageUri: String?) {
    guard let destination = NamidaWidgetsShared.artworkURL else { return }
    let source = imageUri.flatMap { URL(string: $0) }
    guard let source, let artwork = downsampledImage(at: source) else {
      try? FileManager.default.removeItem(at: destination)
      return
    }
    let jpegData = UIImage(cgImage: artwork).jpegData(compressionQuality: 0.85)
    try? jpegData?.write(to: destination, options: .atomic)
  }

  /// decoded straight at the widget's size, widgets get a few MBs of memory and a full size cover takes tens on the way.
  private static func downsampledImage(at url: URL) -> CGImage? {
    let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
    let thumbnailOptions = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceThumbnailMaxPixelSize: artworkMaxPixelSize,
    ] as CFDictionary
    return CGImageSourceCreateThumbnailAtIndex(imageSource, 0, thumbnailOptions)
  }

  private static func reloadNowPlaying() {
    WidgetCenter.shared.reloadTimelines(ofKind: NamidaWidgetsShared.nowPlayingKind)
  }

  // MARK: - live activity

  private func enqueueLiveActivityWork(_ work: @escaping () async -> Void) {
    let previousTask = liveActivityTask
    liveActivityTask = Task {
      await previousTask?.value
      await work()
    }
  }

  /// false only when live activities can't exist on this system, a start that isn't possible now is retried with the next update.
  private func updateLiveActivity(title: String, artist: String?, line: String?) -> Bool {
    guard #available(iOS 16.2, *) else { return false }
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return true }
    let state = NamidaLyricsActivityAttributes.ContentState(title: title, artist: artist, line: line)
    let content = ActivityContent(state: state, staleDate: nil)
    if let activity = liveActivity as? Activity<NamidaLyricsActivityAttributes> {
      let activityState = activity.activityState
      if activityState == .active || activityState == .stale {
        enqueueLiveActivityWork {
          await activity.update(content)
        }
        return true
      }
      if activityState == .dismissed {
        dismissedActivityTitle = activity.content.state.title
      }
      liveActivity = nil
    }
    if title == dismissedActivityTitle { return true }
    // -- only allowed while the app is in the foreground
    guard UIApplication.shared.applicationState != .background else { return true }
    dismissedActivityTitle = nil
    liveActivity = try? Activity.request(attributes: NamidaLyricsActivityAttributes(), content: content, pushType: nil)
    return true
  }

  private func endLiveActivity() {
    guard #available(iOS 16.2, *) else { return }
    dismissedActivityTitle = nil
    let activity = liveActivity as? Activity<NamidaLyricsActivityAttributes>
    liveActivity = nil
    guard let activity else { return }
    enqueueLiveActivityWork {
      await activity.end(nil, dismissalPolicy: .immediate)
    }
  }

  /// activities outlive the app, the ones from a killed session would otherwise stay on the lock screen.
  /// listed right away, an activity this session starts meanwhile isn't one of them.
  private func endStaleLiveActivities() {
    guard #available(iOS 16.2, *) else { return }
    let staleActivities = Activity<NamidaLyricsActivityAttributes>.activities
    guard !staleActivities.isEmpty else { return }
    enqueueLiveActivityWork {
      for activity in staleActivities {
        await activity.end(nil, dismissalPolicy: .immediate)
      }
    }
  }

  /// the system gives a few seconds before exiting, the main thread waits for the ends to go through.
  private static func endAllLiveActivitiesBeforeExit() {
    guard #available(iOS 16.2, *) else { return }
    let activities = Activity<NamidaLyricsActivityAttributes>.activities
    guard !activities.isEmpty else { return }
    let semaphore = DispatchSemaphore(value: 0)
    Task.detached {
      for activity in activities {
        await activity.end(nil, dismissalPolicy: .immediate)
      }
      semaphore.signal()
    }
    _ = semaphore.wait(timeout: .now() + 2)
  }
}

/// resumes the intent waiting on a press once, whether dart performed it or it timed out.
private final class MediaActionWaiter {
  private var continuation: CheckedContinuation<Void, Never>?

  init(_ continuation: CheckedContinuation<Void, Never>) {
    self.continuation = continuation
  }

  func resume() {
    continuation?.resume()
    continuation = nil
  }
}
#endif
