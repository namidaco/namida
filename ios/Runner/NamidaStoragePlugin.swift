// by claude
import Flutter
import UIKit
import UniformTypeIdentifiers

/// the `namida/storage` channel: folders picked outside the app stay readable across launches through security-scoped bookmarks,
/// and caches are kept out of the icloud backup.
final class NamidaStoragePlugin: NSObject, FlutterPlugin, UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate {
  private static let bookmarksKey = "namida_picked_directories"

  /// keyed by the path dart last acknowledged, a folder the system moved keeps its old key until dart rewrote the paths it stored.
  private var bookmarks: [String: Data]
  /// same keys as [bookmarks], only the ones reachable this session. nil until resolved.
  private var resolvedFolders: [String: ResolvedFolder]?
  private var resolveCompletions: [() -> Void]?
  private var offlineFolderPaths = Set<String>()
  private var pendingPickResult: FlutterResult?

  private struct ResolvedFolder {
    let url: URL
    let path: String
  }

  private override init() {
    bookmarks = UserDefaults.standard.dictionary(forKey: Self.bookmarksKey) as? [String: Data] ?? [:]
    super.init()
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "namida/storage", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(NamidaStoragePlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "getPickedDirectories":
      withResolvedFolders { [self] in
        let info = pickedDirectoriesInfo()
        result(info)
      }

    case "acknowledgeMovedPickedDirectories":
      let moved = args?["moved"] as? [String: String] ?? [:]
      withResolvedFolders { [self] in
        acknowledgeMoves(moved)
        result(nil)
      }

    case "releasePickedDirectories":
      let removedPaths = args?["removed"] as? [String] ?? []
      let usedPaths = args?["used"] as? [String] ?? []
      withResolvedFolders { [self] in
        releaseFolders(overlapping: removedPaths, keeping: usedPaths)
        result(nil)
      }

    case "keepDirectoriesOffline":
      let paths = args?["paths"] as? [String] ?? []
      keepOffline(paths)
      result(nil)

    case "excludeFromBackup":
      let paths = args?["paths"] as? [String] ?? []
      Self.excludeFromBackup(paths)
      result(nil)

    case "pickDirectory":
      let initialDirectory = args?["initialDirectory"] as? String
      pickDirectory(initialDirectory: initialDirectory, result: result)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - bookmarks

  /// resolving can block on file providers & network shares, so it happens off the main thread, once, on first use.
  private func withResolvedFolders(_ completion: @escaping () -> Void) {
    if resolvedFolders != nil {
      completion()
      return
    }
    if resolveCompletions != nil {
      resolveCompletions?.append(completion)
      return
    }
    resolveCompletions = [completion]
    let bookmarksToResolve = bookmarks
    DispatchQueue.global(qos: .userInitiated).async {
      let resolution = Self.resolve(bookmarksToResolve)
      DispatchQueue.main.async { [self] in
        resolvedFolders = resolution.folders
        if !resolution.renewedBookmarks.isEmpty {
          bookmarks.merge(resolution.renewedBookmarks) { _, renewed in renewed }
          saveBookmarks()
        }
        let completions = resolveCompletions ?? []
        resolveCompletions = nil
        for pending in completions {
          pending()
        }
      }
    }
  }

  /// access is held for the whole session, dart reads these folders at any time.
  /// an unreachable folder (drive unplugged, provider signed out, moved to the trash) keeps its bookmark so it comes back once it's there again.
  private static func resolve(_ bookmarks: [String: Data]) -> (folders: [String: ResolvedFolder], renewedBookmarks: [String: Data]) {
    var folders: [String: ResolvedFolder] = [:]
    var renewedBookmarks: [String: Data] = [:]
    for (acknowledgedPath, data) in bookmarks {
      var isStale = false
      let resolvedUrl = try? URL(resolvingBookmarkData: data, options: [.withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &isStale)
      guard let url = resolvedUrl else { continue }
      let path = url.namidaStandardPath
      if isInTrash(path) { continue }
      guard url.startAccessingSecurityScopedResource() else { continue }
      if isStale, let renewed = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
        renewedBookmarks[acknowledgedPath] = renewed
      }
      folders[acknowledgedPath] = ResolvedFolder(url: url, path: path)
    }
    return (folders, renewedBookmarks)
  }

  /// a deleted folder's bookmark follows it to the trash, that isn't a move to take paths along.
  private static func isInTrash(_ path: String) -> Bool {
    return path.contains("/.Trash/") || path.hasSuffix("/.Trash")
  }

  private func pickedDirectoriesInfo() -> [String: Any] {
    let folders = resolvedFolders ?? [:]
    var moved: [String: String] = [:]
    for (acknowledgedPath, folder) in folders where folder.path != acknowledgedPath {
      moved[acknowledgedPath] = folder.path
    }
    let paths = folders.values.map { $0.path }
    return [
      "paths": paths,
      "moved": moved,
    ]
  }

  /// dart stored the moves, the folders are keyed by where they are now.
  /// all moved ones are taken out first, in a swap (a -> b while c -> a) one's new key is the other's old one.
  private func acknowledgeMoves(_ moved: [String: String]) {
    var movedFolders: [(newPath: String, folder: ResolvedFolder, data: Data)] = []
    for (oldPath, newPath) in moved {
      guard let folder = resolvedFolders?[oldPath], folder.path == newPath else { continue }
      guard let data = bookmarks.removeValue(forKey: oldPath) else { continue }
      resolvedFolders?.removeValue(forKey: oldPath)
      movedFolders.append((newPath, folder, data))
    }
    if movedFolders.isEmpty { return }
    for moved in movedFolders {
      if resolvedFolders?[moved.newPath]?.path == moved.newPath {
        // -- the new location was picked on its own too, its bookmark already holds the access
        moved.folder.url.stopAccessingSecurityScopedResource()
        continue
      }
      // -- a dead bookmark there (its folder deleted) is replaced
      bookmarks[moved.newPath] = moved.data
      resolvedFolders?[moved.newPath] = moved.folder
    }
    saveBookmarks()
  }

  /// folders overlapping the removed ones lose their access, unless a used path is inside one of them or holds it.
  /// both the acknowledged & current paths count, dart may still store the old one when a move wasn't migrated yet.
  private func releaseFolders(overlapping removedPaths: [String], keeping usedPaths: [String]) {
    var didChange = false
    for acknowledgedPath in Array(bookmarks.keys) {
      let folder = resolvedFolders?[acknowledgedPath]
      let folderPaths = [acknowledgedPath, folder?.path].compactMap { $0 }
      let isRemoved = removedPaths.contains { removedPath in folderPaths.contains { NamidaPaths.overlap(removedPath, $0) } }
      if !isRemoved { continue }
      let isUsed = usedPaths.contains { usedPath in folderPaths.contains { NamidaPaths.overlap(usedPath, $0) } }
      if isUsed { continue }
      folder?.url.stopAccessingSecurityScopedResource()
      resolvedFolders?.removeValue(forKey: acknowledgedPath)
      bookmarks.removeValue(forKey: acknowledgedPath)
      didChange = true
    }
    if didChange { saveBookmarks() }
  }

  private func saveBookmarks() {
    UserDefaults.standard.set(bookmarks, forKey: Self.bookmarksKey)
  }

  /// icloud keeps placeholders of files it evicted, a music library has to be on the device to play offline. once per folder per session.
  private func keepOffline(_ paths: [String]) {
    for path in paths where offlineFolderPaths.insert(path).inserted {
      let folder = URL(fileURLWithPath: path, isDirectory: true)
      Self.downloadUbiquitousItems(in: folder)
    }
  }

  /// in the background, it walks the whole folder and shouldn't compete with the indexer.
  private static func downloadUbiquitousItems(in folder: URL) {
    DispatchQueue.global(qos: .background).async {
      guard FileManager.default.isUbiquitousItem(at: folder) else { return }
      let keys: [URLResourceKey] = [.isRegularFileKey, .ubiquitousItemDownloadingStatusKey]
      let keysSet = Set(keys)
      guard let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: keys) else { return }
      for case let url as URL in enumerator {
        guard let values = try? url.resourceValues(forKeys: keysSet) else { continue }
        guard values.isRegularFile == true else { continue }
        guard values.ubiquitousItemDownloadingStatus != .current else { continue }
        let itemUrl = itemUrl(ofPlaceholder: url)
        try? FileManager.default.startDownloadingUbiquitousItem(at: itemUrl)
      }
    }
  }

  /// before ios 17 an evicted file shows as `.name.icloud`, the download is asked for by the item's own name.
  private static func itemUrl(ofPlaceholder url: URL) -> URL {
    let name = url.lastPathComponent
    guard name.hasPrefix("."), name.hasSuffix(".icloud") else { return url }
    let itemName = String(name.dropFirst().dropLast(".icloud".count))
    return url.deletingLastPathComponent().appendingPathComponent(itemName)
  }

  // MARK: - backup

  /// caches that can be rebuilt shouldn't count towards the user's icloud storage.
  /// every launch, a cache folder that was cleared & created again loses the flag.
  private static func excludeFromBackup(_ paths: [String]) {
    DispatchQueue.global(qos: .utility).async {
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      for path in paths {
        var url = URL(fileURLWithPath: path, isDirectory: true)
        try? url.setResourceValues(values)
      }
    }
  }

  // MARK: - picker

  private func pickDirectory(initialDirectory: String?, result: @escaping FlutterResult) {
    guard pendingPickResult == nil else {
      result(FlutterError(code: "busy", message: "a folder picker is already open", details: nil))
      return
    }
    guard let presenter = NamidaPaths.topViewController() else {
      result(nil)
      return
    }
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
    picker.delegate = self
    picker.allowsMultipleSelection = false
    if let initialDirectory {
      picker.directoryURL = URL(fileURLWithPath: initialDirectory, isDirectory: true)
    }
    // -- swiping the sheet down doesn't always reach documentPickerWasCancelled
    picker.presentationController?.delegate = self
    pendingPickResult = result
    presenter.present(picker, animated: true)
    // -- a presenter that's busy (presenting or dismissing) silently refuses
    if picker.presentingViewController == nil {
      completePickAsCancelled()
    }
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    let result = pendingPickResult
    pendingPickResult = nil
    guard let url = urls.first else {
      result?(nil)
      return
    }
    let didAccess = url.startAccessingSecurityScopedResource()
    let path = url.namidaStandardPath
    if NamidaPaths.isInsideContainer(path) {
      // -- namida's own folders need no bookmark
      if didAccess { url.stopAccessingSecurityScopedResource() }
      result?(path)
      return
    }
    let data: Data
    do {
      data = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
    } catch {
      if didAccess { url.stopAccessingSecurityScopedResource() }
      result?(FlutterError(code: "bookmark_failed", message: error.localizedDescription, details: nil))
      return
    }
    bookmarks[path] = data
    saveBookmarks()
    withResolvedFolders { [self] in
      if resolvedFolders?[path] != nil {
        if didAccess { url.stopAccessingSecurityScopedResource() }
      } else {
        resolvedFolders?[path] = ResolvedFolder(url: url, path: path)
      }
    }
    result?(path)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    completePickAsCancelled()
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    completePickAsCancelled()
  }

  private func completePickAsCancelled() {
    let result = pendingPickResult
    pendingPickResult = nil
    result?(nil)
  }
}
