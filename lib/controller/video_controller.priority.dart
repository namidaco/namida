part of 'video_controller.dart';

class _VideosPriorityManager {
  _VideosPriorityManager();

  static const _priorityKey = 'priority';

  static DBWrapper _openDb(DbWrapperFileInfo fileInfo) {
    return DBWrapper.openFromInfo(
      fileInfo: fileInfo,
      createIfNotExist: true,
      customTypes: [
        DBColumnType(
          type: DBColumnTypeEnum.int,
          name: _priorityKey,
          nullable: true,
        ),
      ],
    );
  }

  late final _cacheVideosPriorityDB = _openDb(AppPaths.CACHE_VIDEOS_PRIORITY);

  Future<Map<String, CacheVideoPriority>> get priorityLookupMap async {
    await _loadCompleter.future;
    return _videosPriorityMap;
  }

  final _loadCompleter = Completer<void>();

  var _videosPriorityMap = <String, CacheVideoPriority>{};

  Future<void> loadDb() async {
    final res = await _loadDbSync.thready(AppPaths.CACHE_VIDEOS_PRIORITY);
    final modifiedValues = Map<String, CacheVideoPriority>.from(_videosPriorityMap);
    _videosPriorityMap = res;
    _videosPriorityMap.addAll(modifiedValues);
    _loadCompleter.complete();
  }

  static Map<String, CacheVideoPriority> _loadDbSync(DbWrapperFileInfo fileInfo) {
    NamicoDBWrapper.initialize();
    final values = CacheVideoPriority.values;
    final db = _VideosPriorityManager._openDb(fileInfo);
    var videosPriorityMap = <String, CacheVideoPriority>{};
    db.loadEverythingKeyed((key, map) {
      final int valueIndex = map[_priorityKey];
      videosPriorityMap[key] = values[valueIndex];
    });
    db.close();
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

  void setVideoPriority(String videoId, CacheVideoPriority priority) {
    final alreadySet = _videosPriorityMap[videoId] == priority;
    if (!alreadySet) {
      _videosPriorityMap[videoId] = priority;
      _cacheVideosPriorityDB.putAsync(videoId, {_priorityKey: priority.index});
    }
  }

  void setVideosPriority(List<String> videoIds, CacheVideoPriority priority) {
    for (final videoId in videoIds) {
      setVideoPriority(videoId, priority);
    }
  }
}
