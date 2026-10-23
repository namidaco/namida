// by claude
import BackgroundTasks
import UIKit

/// keeps work the user started (downloads) going after leaving the app: a short grace on every version,
/// and on ios 26 a continued processing task the system shows with its progress, without a time limit.
/// both can expire while the work goes on: the grace is started again every time the app is active again,
/// the continued task with every new download (the system only accepts one asked for by the user's action).
final class NamidaBackgroundWork {
  static let shared = NamidaBackgroundWork()

  /// read from Info.plist: sideloading tools can rename the bundle id, never this list, and an unlisted identifier crashes on register.
  private let continuedTaskIdentifier = (Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") as? [String])?.first

  private var isRunning = false
  private var graceTaskId: UIBackgroundTaskIdentifier = .invalid
  /// a `BGContinuedProcessingTask`, typed loosely since stored properties can't be limited to ios 26.
  private var continuedTask: AnyObject?
  private var latestProgress = (completed: Int64(0), total: Int64(0), itemsCount: 0)
  private var shownItemsCount: Int?

  private init() {
    NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
      guard let self, self.isRunning else { return }
      self.beginGraceTask()
    }
  }

  /// once, while the app launches.
  func registerContinuedTask() {
    #if compiler(>=6.2)
    guard #available(iOS 26.0, *), let identifier = continuedTaskIdentifier else { return }
    BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: .main) { [weak self] task in
      guard let self, let continued = task as? BGContinuedProcessingTask else {
        task.setTaskCompleted(success: false)
        return
      }
      self.onContinuedTaskStarted(continued)
    }
    #endif
  }

  /// called for every batch of downloads the user starts, the user's action a continued task needs.
  func setRunning(_ running: Bool) {
    if running {
      isRunning = true
      beginGraceTask()
      submitContinuedTask()
      return
    }
    guard isRunning else { return }
    isRunning = false
    latestProgress = (0, 0, 0)
    completeContinuedTask(success: true)
    endGraceTask()
  }

  func updateProgress(completed: Int64, total: Int64, itemsCount: Int) {
    latestProgress = (completed, total, itemsCount)
    applyProgress()
  }

  private func beginGraceTask() {
    guard graceTaskId == .invalid else { return }
    graceTaskId = UIApplication.shared.beginBackgroundTask(withName: "namida work") { [weak self] in
      self?.endGraceTask()
    }
  }

  private func endGraceTask() {
    guard graceTaskId != .invalid else { return }
    UIApplication.shared.endBackgroundTask(graceTaskId)
    graceTaskId = .invalid
  }

  /// only possible while the app is in the foreground, which is where downloads get started.
  private func submitContinuedTask() {
    #if compiler(>=6.2)
    guard continuedTask == nil else { return }
    guard #available(iOS 26.0, *), let identifier = continuedTaskIdentifier else { return }
    let request = BGContinuedProcessingTaskRequest(identifier: identifier, title: "Namida", subtitle: "Downloading")
    request.strategy = .fail
    try? BGTaskScheduler.shared.submit(request)
    #endif
  }

  private func completeContinuedTask(success: Bool) {
    #if compiler(>=6.2)
    if #available(iOS 26.0, *), let task = continuedTask as? BGContinuedProcessingTask {
      task.setTaskCompleted(success: success)
    }
    #endif
    continuedTask = nil
    shownItemsCount = nil
  }

  private func applyProgress() {
    #if compiler(>=6.2)
    guard #available(iOS 26.0, *), let task = continuedTask as? BGContinuedProcessingTask else { return }
    let total = max(latestProgress.total, 1)
    task.progress.totalUnitCount = total
    task.progress.completedUnitCount = min(latestProgress.completed, total)
    let itemsCount = latestProgress.itemsCount
    guard itemsCount != shownItemsCount else { return }
    shownItemsCount = itemsCount
    let subtitle = itemsCount == 1 ? "Downloading 1 file" : "Downloading \(itemsCount) files"
    task.updateTitle("Namida", subtitle: subtitle)
    #endif
  }

  #if compiler(>=6.2)
  @available(iOS 26.0, *)
  private func onContinuedTaskStarted(_ task: BGContinuedProcessingTask) {
    // -- queued and started after the work already ended
    guard isRunning else {
      task.setTaskCompleted(success: true)
      return
    }
    continuedTask = task
    task.expirationHandler = { [weak self, weak task] in
      DispatchQueue.main.async {
        guard let self, let task, self.continuedTask === task else { return }
        self.completeContinuedTask(success: false)
      }
    }
    applyProgress()
  }
  #endif
}
