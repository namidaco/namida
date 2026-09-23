// all server cache logic by claude, including server_cache_widgets.dart
part of 'music_web_server_base.dart';

class ServerCacheController {
  static final inst = ServerCacheController._();
  ServerCacheController._();

  static const _kMaxParallelDownloads = 3;
  static const _kProgressUpdateIntervalMs = 100;

  /// `.part` is used by http_cache_stream while streaming the same file.
  static const _kPartExtension = '.dl';
  static const _kMetadataExtension = '.metadata';

  final keptPaths = <String>{}.obs;

  /// keyed by track path, in queue order.
  final tasks = <String, ServerCacheTask>{}.obs;
  final isPaused = false.obs;

  final _pending = Queue<ServerCacheTask>();
  int _activeCount = 0;
  bool _waitingForConnection = false;

  int _batchCompletedCount = 0;
  int _batchCompletedBytes = 0;
  DateTime? _batchStartTime;
  Timer? _notificationTimer;

  late final _priorityDb = VideosPriorityManager.openDb(AppPaths.CACHE_SERVERS_PRIORITY);

  Future<void>? _initializeFuture;
  Future<void> initialize() => _initializeFuture ??= _initialize();

  Future<void> _initialize() async {
    await _migrateLegacyCacheDirs.thready((legacyRoot: AppDirs.APP_CACHE, newRoot: AppDirs.SERVERS_CACHE));
    final priorities = await VideosPriorityManager.loadEverythingSync.thready(AppPaths.CACHE_SERVERS_PRIORITY);
    final kept = keptPaths.value;
    for (final e in priorities.entries) {
      if (e.value == CacheVideoPriority.VIP) kept.add(e.key);
    }
    if (kept.isNotEmpty) keptPaths.refresh();
  }

  /// streamed caches used to live in the app cache, which the system can clear anytime.
  static void _migrateLegacyCacheDirs(({String legacyRoot, String newRoot}) params) {
    for (final type in DirectoryIndexType.values) {
      if (!type.check(DirectoryIndexTypeTag.server)) continue;
      final legacyDir = Directory(p.join(params.legacyRoot, type.name));
      if (!legacyDir.existsSync()) continue;
      final newDir = Directory(p.join(params.newRoot, type.name));
      if (newDir.existsSync()) continue;
      try {
        newDir.parent.createSync(recursive: true);
        legacyDir.renameSync(newDir.path);
      } catch (_) {}
    }
  }

  static File cacheFileForPath(String trackPath) {
    final res = MediaUrlParseResult.parse(trackPath);
    return cacheFileFor(res.type, res.username, res.id ?? '');
  }

  static File cacheFileFor(DirectoryIndexType type, String username, String id) {
    final cleanId = id.startsWith('/') ? id.substring(1) : id;
    return File(p.normalize(p.join(AppDirs.SERVERS_CACHE, type.name, username, cleanId)));
  }

  bool isKept(Track track) => keptPaths.value.contains(track.path);

  Future<void> cacheTracks(Iterable<Track> tracks) async {
    await initialize();
    final kept = keptPaths.value;
    final tasksMap = tasks.value;
    bool added = false;
    for (final track in tracks) {
      if (!track.isNetwork) continue;
      final path = track.path;
      if (kept.contains(path) || tasksMap.containsKey(path)) continue;
      final task = ServerCacheTask._(track);
      tasksMap[path] = task;
      _pending.add(task);
      added = true;
    }
    if (!added) return;
    tasks.refresh();
    _startNotificationTimer();
    _pump();
  }

  void cancel(ServerCacheTask task) {
    final track = task.track;
    if (tasks.value[track.path] != task) return;
    tasks.remove(track.path);
    _stopAndDiscard(task);
    _pending.remove(task);
    _onQueueChanged();
  }

  void cancelAll() {
    final all = tasks.value.values.toList();
    tasks.clear();
    _pending.clear();
    for (final task in all) {
      _stopAndDiscard(task);
    }
    _onQueueChanged();
  }

  void _stopAndDiscard(ServerCacheTask task) {
    if (task.state.value == ServerCacheTaskState.downloading) {
      task._requestStop(); // -- the partial file is deleted once the transfer stops
    } else {
      _partFileOf(cacheFileForPath(task.track.path)).tryDeleting();
    }
  }

  void retry(ServerCacheTask task) {
    if (task.state.value != ServerCacheTaskState.failed) return;
    task.state.value = ServerCacheTaskState.queued;
    _pending.add(task);
    _startNotificationTimer();
    _pump();
  }

  void pause() {
    if (isPaused.value) return;
    isPaused.value = true;
    for (final task in tasks.value.values) {
      if (task.state.value == ServerCacheTaskState.downloading) task._requestStop();
    }
    _notificationTimer?.cancel();
    _notificationTimer = null;
    _postProgressNotification();
  }

  void resume() {
    if (!isPaused.value) return;
    isPaused.value = false;
    _startNotificationTimer();
    _pump();
  }

  Future<void> removeCached(Iterable<Track> tracks) async {
    await initialize();
    final kept = keptPaths.value;
    bool changed = false;
    for (final track in tracks) {
      if (!track.isNetwork) continue;
      final file = cacheFileForPath(track.path);
      await file.tryDeleting();
      await File('${file.path}$_kMetadataExtension').tryDeleting();
      if (kept.remove(track.path)) {
        changed = true;
        _priorityDb.delete(track.path);
      }
    }
    if (changed) keptPaths.refresh();
  }

  Future<int> getCachedSize(Iterable<Track> tracks) async {
    final filesPaths = <String>[];
    for (final track in tracks) {
      if (track.isNetwork) filesPaths.add(cacheFileForPath(track.path).path);
    }
    if (filesPaths.isEmpty) return 0;
    return _sumFilesSizesIsolate.thready(filesPaths);
  }

  static int _sumFilesSizesIsolate(List<String> filesPaths) {
    int size = 0;
    for (final path in filesPaths) {
      size += File(path).fileSizeSync() ?? 0;
    }
    return size;
  }

  Future<ServerCacheStats> getStats() async {
    await initialize();
    return _getStatsIsolate.thready((dirPath: AppDirs.SERVERS_CACHE, keptFilesPaths: _keptFilesPaths()));
  }

  /// active downloads are canceled first when [keepKept] is false, otherwise they're left untouched.
  Future<void> clear({required bool keepKept, required bool deleteOthers, required bool deleteTemp}) async {
    await initialize();
    if (!keepKept) cancelAll();
    await _clearIsolate.thready((
      dirPath: AppDirs.SERVERS_CACHE,
      keptFilesPaths: _keptFilesPaths(),
      skipPaths: _tasksPartFilesPaths(),
      deleteKept: !keepKept,
      deleteOthers: deleteOthers,
      deleteTemp: deleteTemp,
    ));
    if (!keepKept && keptPaths.value.isNotEmpty) {
      await _priorityDb.deleteEverything(claimFreeSpaceAndCheckpoint: true);
      keptPaths.value.clear();
      keptPaths.refresh();
    }
  }

  Future<int> trimExcessCache() async {
    final maxMB = settings.serversMaxCacheInMB.value;
    if (maxMB < 0) return 0;
    await initialize();
    return _trimIsolate.thready((
      dirPath: AppDirs.SERVERS_CACHE,
      keptFilesPaths: _keptFilesPaths(),
      skipPaths: _tasksPartFilesPaths(),
      maxBytes: maxMB * 1024 * 1024,
    ));
  }

  Set<String> _keptFilesPaths() {
    final paths = <String>{};
    for (final path in keptPaths.value) {
      paths.add(cacheFileForPath(path).path);
    }
    return paths;
  }

  Set<String> _tasksPartFilesPaths() {
    final paths = <String>{};
    for (final task in tasks.value.values) {
      paths.add(_partFileOf(cacheFileForPath(task.track.path)).path);
    }
    return paths;
  }

  static File _partFileOf(File file) => File('${file.path}$_kPartExtension');

  static String _stripExtraExtension(String path) {
    if (path.endsWith(_kPartExtension)) return path.substring(0, path.length - _kPartExtension.length);
    if (path.endsWith(_kMetadataExtension)) return path.substring(0, path.length - _kMetadataExtension.length);
    return path;
  }

  /// normalized to match [cacheFileFor].
  static List<File> _listFiles(String dirPath) {
    final files = <File>[];
    for (final e in Directory(dirPath).listSyncSafe(recursive: true)) {
      if (e is File) files.add(File(p.normalize(e.path)));
    }
    return files;
  }

  static ServerCacheStats _getStatsIsolate(({String dirPath, Set<String> keptFilesPaths}) params) {
    int keptCount = 0, keptSize = 0, otherCount = 0, otherSize = 0, tempSize = 0;
    for (final file in _listFiles(params.dirPath)) {
      final path = file.path;
      final size = file.fileSizeSync() ?? 0;
      if (path.endsWith(_kPartExtension)) {
        tempSize += size;
      } else if (params.keptFilesPaths.contains(_stripExtraExtension(path))) {
        keptSize += size;
        if (!path.endsWith(_kMetadataExtension)) keptCount++;
      } else {
        otherSize += size;
        if (!path.endsWith(_kMetadataExtension)) otherCount++;
      }
    }
    return ServerCacheStats(keptCount: keptCount, keptSize: keptSize, otherCount: otherCount, otherSize: otherSize, tempSize: tempSize);
  }

  static void _clearIsolate(
    ({String dirPath, Set<String> keptFilesPaths, Set<String> skipPaths, bool deleteKept, bool deleteOthers, bool deleteTemp}) params,
  ) {
    for (final file in _listFiles(params.dirPath)) {
      final path = file.path;
      if (params.skipPaths.contains(path)) continue;
      final bool shouldDelete;
      if (path.endsWith(_kPartExtension)) {
        shouldDelete = params.deleteTemp;
      } else if (params.keptFilesPaths.contains(_stripExtraExtension(path))) {
        shouldDelete = params.deleteKept;
      } else {
        shouldDelete = params.deleteOthers;
      }
      if (shouldDelete) {
        try {
          file.deleteSync();
        } catch (_) {}
      }
    }
  }

  /// kept files are never trimmed, but still count towards the limit.
  static int _trimIsolate(({String dirPath, Set<String> keptFilesPaths, Set<String> skipPaths, int maxBytes}) params) {
    final candidates = <(File, int accessed, int size)>[];
    int totalBytes = 0;
    for (final file in _listFiles(params.dirPath)) {
      try {
        final stat = file.statSync();
        final size = stat.size.withMinimum(0);
        totalBytes += size;
        if (params.skipPaths.contains(file.path) || params.keptFilesPaths.contains(_stripExtraExtension(file.path))) continue;
        candidates.add((file, stat.accessed.millisecondsSinceEpoch, size));
      } catch (_) {}
    }
    if (totalBytes <= params.maxBytes) return 0;

    candidates.sort((a, b) => a.$2.compareTo(b.$2));
    int deletedBytes = 0;
    for (final c in candidates) {
      if (totalBytes <= params.maxBytes) break;
      try {
        c.$1.deleteSync();
        totalBytes -= c.$3;
        deletedBytes += c.$3;
      } catch (_) {}
    }
    return deletedBytes;
  }

  void _pump() {
    if (isPaused.value || _waitingForConnection) return;
    while (_activeCount < _kMaxParallelDownloads && _pending.isNotEmpty) {
      _run(_pending.removeFirst());
    }
  }

  Future<void> _run(ServerCacheTask task) async {
    _activeCount++;
    task._stopRequested = false;
    task.state.value = ServerCacheTaskState.downloading;

    final track = task.track;
    final file = cacheFileForPath(track.path);
    Object? error;
    StackTrace? errorStack;
    try {
      await _downloadOriginal(task, file);
    } catch (e, st) {
      error = e;
      errorStack = st;
    }
    task._stopTransfer = null;
    _activeCount--;

    if (tasks.value[track.path] != task) {
      _partFileOf(file).tryDeleting(); // -- canceled
    } else if (error == null) {
      _onTaskDone(task, file);
    } else if (error is DownloadCanceledException) {
      task.state.value = ServerCacheTaskState.queued; // -- paused
      _pending.addFirst(task);
    } else if (!ConnectivityController.inst.hasConnection) {
      task.state.value = ServerCacheTaskState.queued;
      _pending.addFirst(task);
      _waitForConnection();
    } else {
      task.state.value = ServerCacheTaskState.failed;
      logger.error('ServerCacheController._run', e: error, st: errorStack);
    }

    _pump();
    _onQueueChanged();
  }

  Future<void> _downloadOriginal(ServerCacheTask task, File file) async {
    final track = task.track;
    final expectedSize = track.size;
    if (expectedSize > 0 && await file.fileSize() == expectedSize) return; // -- already cached while streaming

    final source = await MusicWebServer._executeIfHasServer<Future<_ServerFileSource?>>(
      track.path,
      (server, id) => server._getOriginalFileSource(id),
      (_, _) async => null,
    );
    if (source == null) throw Exception('No server found for this item: ${track.path}');
    task._throwIfStopped();

    final partFile = _partFileOf(file);
    final start = await partFile.fileSize() ?? 0;
    task.downloadedBytes.value = start;

    switch (source) {
      case _ServerFileSourceUrl():
        task._stopTransfer = () => FilesDownloadManager.inst.stopDownload(file: partFile);
        task._throwIfStopped();
        final exception = await FilesDownloadManager.inst.download(
          url: source.details.uri,
          headers: source.details.headers,
          file: partFile,
          downloadingStream: (bytes) => task.downloadedBytes.value += bytes,
        );
        if (exception != null) throw exception;
      case _ServerFileSourceStream():
        await _downloadStream(task, source, partFile, start);
    }
    task._throwIfStopped();
    await partFile.rename(file.path);
  }

  Future<void> _downloadStream(ServerCacheTask task, _ServerFileSourceStream source, File partFile, int start) async {
    final stream = await source.openRead(start);
    task._throwIfStopped();
    await partFile.create(recursive: true);
    final sink = partFile.openWrite(mode: FileMode.writeOnlyAppend);
    final completer = Completer<void>();
    int pendingBytes = 0;
    final stopwatch = Stopwatch()..start();
    final sub = stream.listen(
      (data) {
        sink.add(data);
        pendingBytes += data.length;
        if (stopwatch.elapsedMilliseconds >= _kProgressUpdateIntervalMs) {
          task.downloadedBytes.value += pendingBytes;
          pendingBytes = 0;
          stopwatch.reset();
        }
      },
      onError: (Object e, StackTrace st) => completer.completeErrorIfWasnt(e, st),
      onDone: completer.completeIfWasnt,
      cancelOnError: true,
    );
    task._stopTransfer = () {
      sub.cancel();
      completer.completeErrorIfWasnt(const DownloadCanceledException());
    };
    try {
      await completer.future;
    } finally {
      task.downloadedBytes.value += pendingBytes;
      await sink.flush().ignoreError();
      await sink.close().ignoreError();
    }
  }

  void _onTaskDone(ServerCacheTask task, File file) {
    final path = task.track.path;
    keptPaths.value.add(path);
    keptPaths.refresh();
    tasks.remove(path);
    _priorityDb.put(path, VideosPriorityManager.toDbValue(CacheVideoPriority.VIP));
    _batchCompletedCount++;
    _batchCompletedBytes += task.track.size;
  }

  void _waitForConnection() {
    if (_waitingForConnection) return;
    _waitingForConnection = true;
    ConnectivityController.inst.registerOnConnectionRestored(_onConnectionRestored);
  }

  void _onConnectionRestored() {
    _waitingForConnection = false; // -- the callback is fired only once
    _pump();
  }

  void _onQueueChanged() {
    if (_activeCount > 0 || _pending.isNotEmpty) return;
    _notificationTimer?.cancel();
    _notificationTimer = null;
    isPaused.value = false;
    if (_batchStartTime == null) return;

    final completed = _batchCompletedCount;
    _batchStartTime = null;
    _batchCompletedCount = 0;
    _batchCompletedBytes = 0;

    int failed = 0;
    for (final task in tasks.value.values) {
      if (task.state.value == ServerCacheTaskState.failed) failed++;
    }
    if (completed > 0 || failed > 0) {
      NotificationManager.instance.doneServerCacheNotification(
        title: lang.cache,
        subtitle: [
          completed.displayTrackKeyword,
          if (failed > 0) '${lang.failed}: $failed',
        ].join(' • '),
        failed: failed > 0,
      );
    } else {
      NotificationManager.instance.removeServerCacheNotification();
    }
  }

  void _startNotificationTimer() {
    if (_notificationTimer != null || isPaused.value) return;
    NotificationManager.instance.ensurePermissionGranted();
    _batchStartTime ??= DateTime.now();
    _notificationTimer = Timer.periodic(const Duration(seconds: 1), (_) => _postProgressNotification());
  }

  void _postProgressNotification() {
    final startTime = _batchStartTime;
    if (startTime == null) return;
    int totalBytes = _batchCompletedBytes;
    int doneBytes = _batchCompletedBytes;
    int remainingCount = 0;
    for (final task in tasks.value.values) {
      if (task.state.value == ServerCacheTaskState.failed) continue;
      remainingCount++;
      totalBytes += task.track.size;
      doneBytes += task.downloadedBytes.value;
    }
    final completed = _batchCompletedCount;
    NotificationManager.instance.serverCacheNotification(
      title: '${lang.cache} ($completed/${completed + remainingCount})',
      subtitle: (progressText) => progressText,
      progress: doneBytes,
      total: totalBytes,
      displayTime: startTime,
      isRunning: !isPaused.value,
    );
  }
}

class ServerCacheTask {
  final Track track;
  final downloadedBytes = 0.obs;
  final state = ServerCacheTaskState.queued.obs;

  ServerCacheTask._(this.track);

  bool _stopRequested = false;
  void Function()? _stopTransfer;

  void _requestStop() {
    _stopRequested = true;
    _stopTransfer?.call();
  }

  void _throwIfStopped() {
    if (_stopRequested) throw const DownloadCanceledException();
  }
}

enum ServerCacheTaskState { queued, downloading, failed }

class ServerCacheStats {
  final int keptCount;
  final int keptSize;
  final int otherCount;
  final int otherSize;
  final int tempSize;

  const ServerCacheStats({
    required this.keptCount,
    required this.keptSize,
    required this.otherCount,
    required this.otherSize,
    required this.tempSize,
  });

  int get totalSize => keptSize + otherSize + tempSize;
}

sealed class _ServerFileSource {
  const _ServerFileSource();
}

class _ServerFileSourceUrl extends _ServerFileSource {
  final WebStreamUriDetails details;
  const _ServerFileSourceUrl(this.details);
}

class _ServerFileSourceStream extends _ServerFileSource {
  final Future<Stream<List<int>>> Function(int start) openRead;
  const _ServerFileSourceStream(this.openRead);
}
