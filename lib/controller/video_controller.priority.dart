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

  static Map<String, CacheVideoPriority> loadEverythingSync(DbWrapperFileInfo fileInfo) {
    NamicoDBWrapper.initialize();
    final values = CacheVideoPriority.values;
    final db = DBWrapper.openFromInfoSync(
      fileInfo: fileInfo,
      config: _dbConfig.copyWith(autoDisposeTimerDuration: null),
    );
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
}
