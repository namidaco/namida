part of 'video_controller.dart';

class VideosPriorityManager {
  VideosPriorityManager();

  static const _priorityKey = 'priority';
  static const _dbConfig = DBConfig(
    createIfNotExist: true,
    customTypes: [
      DBColumnType(
        type: DBColumnTypeEnum.int,
        name: _priorityKey,
        nullable: true,
      ),
    ],
  );

  static DBWrapperAsync _openDb(DbWrapperFileInfo fileInfo) {
    return DBWrapper.openFromInfo(
      fileInfo: fileInfo,
      config: _dbConfig,
    );
  }

  late final cacheVideosPriorityDB = _openDb(AppPaths.CACHE_VIDEOS_PRIORITY);

  final _videosPriorityMap = <String, CacheVideoPriority>{};

  static Future<Map<String, CacheVideoPriority>> loadEverythingSync(DbWrapperFileInfo fileInfo) async {
    final values = CacheVideoPriority.values;
    final db = await DBWrapper.openFromInfoSyncTry(
      fileInfo: fileInfo,
      config: _dbConfig.copyWith(autoDisposeTimerDuration: null),
    );

    var videosPriorityMap = <String, CacheVideoPriority>{};
    db?.loadEverythingKeyed((key, map) {
      final int valueIndex = map[_priorityKey];
      videosPriorityMap[key] = values[valueIndex];
    });
    db?.close();
    return videosPriorityMap;
  }

  Iterable<String> getVideoIdsForPriority(CacheVideoPriority priority) sync* {
    for (final k in _videosPriorityMap.keys) {
      final val = _videosPriorityMap[k];
      if (val == priority) yield k;
    }
  }

  Iterable<String> getVideoIdsWhere(bool Function(String videoId, CacheVideoPriority priority) test) sync* {
    for (final k in _videosPriorityMap.keys) {
      final val = _videosPriorityMap[k]!;
      if (test(k, val)) yield k;
    }
  }

  FutureOr<CacheVideoPriority> getVideoPriority(String videoId) async {
    return _videosPriorityMap[videoId] ??= _mapToPriority(await cacheVideosPriorityDB.get(videoId)) ?? CacheVideoPriority.normal;
  }

  void setVideoPriority(String videoId, CacheVideoPriority priority) {
    final alreadySet = _videosPriorityMap[videoId] == priority;
    if (!alreadySet) {
      _videosPriorityMap[videoId] = priority;
      unawaited(cacheVideosPriorityDB.put(videoId, {_priorityKey: priority.index}));
    }
  }

  void setVideosPriority(Iterable<String> videoIds, CacheVideoPriority priority) {
    for (final videoId in videoIds) {
      setVideoPriority(videoId, priority);
    }
  }

  CacheVideoPriority? _mapToPriority(Map<String, dynamic>? map) {
    if (map == null) return null;
    final values = CacheVideoPriority.values;
    final int valueIndex = map[_priorityKey];
    return values[valueIndex];
  }

  Future<Uint8List?> buildSyncDbBytes() async {
    try {
      await cacheVideosPriorityDB.checkpoint();
    } catch (_) {}
    final file = AppPaths.CACHE_VIDEOS_PRIORITY.file;
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  static int? _syncTokenOf(Map<String, dynamic> map) {
    final index = map[_priorityKey];
    return index is int && index >= 0 && index < CacheVideoPriority.values.length ? index : null;
  }

  static bool _syncShouldReplace(int incomingIndex, int? localIndex) => localIndex == null || incomingIndex < localIndex;

  Future<int> importFromSyncDb(File incomingDbFile) async {
    final localFileInfo = AppPaths.CACHE_VIDEOS_PRIORITY;
    final changed = await Isolate.run(() => _importFromSyncDbIsolate(incomingDbFile, localFileInfo));
    _applyImportedPriorities(changed);
    return changed.length;
  }

  void _applyImportedPriorities(Map<String, int> changed) {
    final values = CacheVideoPriority.values;
    for (final e in changed.entries) {
      _videosPriorityMap[e.key] = values[e.value];
    }
  }

  /// returns map `{videoId: priorityIndex}` of the entries that were written.
  static Map<String, int> _importFromSyncDbIsolate(File incomingDbFile, DbWrapperFileInfo localFileInfo) {
    final changed = <String, int>{};
    final incomingDb = DBWrapper.openFromFileSync(incomingDbFile, config: _dbConfig);
    final localDb = DBWrapper.openFromInfoSync(fileInfo: localFileInfo, config: _dbConfig);
    try {
      incomingDb.loadEverythingKeyed((key, incomingMap) {
        final incomingIndex = _syncTokenOf(incomingMap);
        if (incomingIndex == null) return;
        final local = localDb.get(key);
        if (!_syncShouldReplace(incomingIndex, local == null ? null : _syncTokenOf(local))) return;
        localDb.put(key, {_priorityKey: incomingIndex});
        changed[key] = incomingIndex;
      });
    } finally {
      incomingDb.close();
      localDb.close();
    }
    return changed;
  }

  Future<Map<String, int>> buildSyncManifest() {
    final localFileInfo = AppPaths.CACHE_VIDEOS_PRIORITY;
    return Isolate.run(() {
      final manifest = <String, int>{};
      final localDb = DBWrapper.openFromInfoSync(fileInfo: localFileInfo, config: _dbConfig);
      try {
        localDb.loadEverythingKeyed((key, map) {
          final index = _syncTokenOf(map);
          if (index != null) manifest[key] = index;
        });
      } finally {
        localDb.close();
      }
      return manifest;
    });
  }

  Future<Map<String, Map<String, dynamic>>> buildSyncEntriesToSend(Map<String, dynamic> otherManifest) {
    final localFileInfo = AppPaths.CACHE_VIDEOS_PRIORITY;
    return Isolate.run(() {
      final toSend = <String, Map<String, dynamic>>{};
      final localDb = DBWrapper.openFromInfoSync(fileInfo: localFileInfo, config: _dbConfig);
      try {
        localDb.loadEverythingKeyed((key, map) {
          final index = _syncTokenOf(map);
          if (index == null) return;
          if (_syncShouldReplace(index, otherManifest[key] as int?)) toSend[key] = map;
        });
      } finally {
        localDb.close();
      }
      return toSend;
    });
  }

  Future<int> importSyncEntries(Map<String, dynamic> entries) async {
    final localFileInfo = AppPaths.CACHE_VIDEOS_PRIORITY;
    final changed = await Isolate.run(() {
      final changed = <String, int>{};
      final localDb = DBWrapper.openFromInfoSync(fileInfo: localFileInfo, config: _dbConfig);
      try {
        for (final e in entries.entries) {
          final incomingIndex = _syncTokenOf((e.value as Map).cast<String, dynamic>());
          if (incomingIndex == null) continue;
          final local = localDb.get(e.key);
          if (!_syncShouldReplace(incomingIndex, local == null ? null : _syncTokenOf(local))) continue;
          localDb.put(e.key, {_priorityKey: incomingIndex});
          changed[e.key] = incomingIndex;
        }
      } finally {
        localDb.close();
      }
      return changed;
    });
    _applyImportedPriorities(changed);
    return changed.length;
  }
}
