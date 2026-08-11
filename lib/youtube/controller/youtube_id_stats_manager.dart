part of 'youtube_controller.dart';

class _YoutubeIDStatsManager {
  static const _dbConfig = DBConfig(createIfNotExist: true);

  late final _statsDBManager = DBWrapper.openFromInfo(
    fileInfo: AppPaths.VIDEO_ID_STATS_DB_INFO,
    config: _dbConfig,
  );

  Future<YoutubeIDStats?> getStats(YoutubeID item) async {
    final json = await _statsDBManager.get(item.id);
    if (json == null) return null;
    return YoutubeIDStats.fromJsonWithoutVideoId(item.id, json);
  }

  Future<void> updateStats(
    YoutubeID item, {
    String? ratingString,
    String? tagsString,
    String? moodsString,
    int? lastPositionInMs,
  }) async {
    final stats = await getStats(item);
    final rating = ratingString != null
        ? ratingString.isEmpty
              ? null
              : int.tryParse(ratingString) ?? stats?.rating
        : stats?.rating;
    final tags = tagsString != null ? Indexer.splitByCommaList(tagsString) : stats?.tags;
    final moods = moodsString != null ? Indexer.splitByCommaList(moodsString) : stats?.moods;
    lastPositionInMs ??= stats?.lastPositionInMs ?? 0;
    final newStats = YoutubeIDStats(
      videoId: item.id,
      rating: rating?.clampInt(0, 100) ?? 0,
      tags: tags,
      moods: moods,
      lastPositionInMs: lastPositionInMs,
      audioTrackId: stats?.audioTrackId,
      modifiedDate: currentTimeMS,
    );

    return _statsDBManager.put(item.id, newStats.toJsonWithoutVideoId());
  }

  Future<void> updateAudioTrackId(
    YoutubeID item, {
    required String? audioTrackId,
  }) async {
    final stats = await getStats(item);
    final newStats = YoutubeIDStats(
      videoId: item.id,
      rating: stats?.rating ?? 0,
      tags: stats?.tags,
      moods: stats?.moods,
      lastPositionInMs: stats?.lastPositionInMs ?? 0,
      audioTrackId: audioTrackId,
      modifiedDate: currentTimeMS,
    );
    return _statsDBManager.put(item.id, newStats.toJsonWithoutVideoId());
  }

  Future<Uint8List?> buildSyncDbBytes() async {
    try {
      await _statsDBManager.checkpoint();
    } catch (_) {}
    final file = AppPaths.VIDEO_ID_STATS_DB_INFO.file;
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  static int _syncTokenOf(Map<String, dynamic> map) => map['_mt'] as int? ?? 0;

  static bool _syncShouldReplace(int incomingToken, int? localToken) => localToken == null || incomingToken > localToken;

  /// returns the number of merged entries.
  Future<int> importFromSyncDb(File incomingDbFile) {
    final localFileInfo = AppPaths.VIDEO_ID_STATS_DB_INFO;
    return Isolate.run(() => _importFromSyncDbIsolate(incomingDbFile, localFileInfo));
  }

  static int _importFromSyncDbIsolate(File incomingDbFile, DbWrapperFileInfo localFileInfo) {
    int changed = 0;
    final incomingDb = DBWrapper.openFromFileSync(incomingDbFile, config: _dbConfig);
    final localDb = DBWrapper.openFromInfoSync(fileInfo: localFileInfo, config: _dbConfig);
    try {
      incomingDb.loadEverythingKeyed((key, incomingMap) {
        final local = localDb.get(key);
        if (!_syncShouldReplace(_syncTokenOf(incomingMap), local == null ? null : _syncTokenOf(local))) return;
        localDb.put(key, incomingMap);
        changed++;
      });
    } finally {
      incomingDb.close();
      localDb.close();
    }
    return changed;
  }

  Future<Map<String, int>> buildSyncManifest() {
    final localFileInfo = AppPaths.VIDEO_ID_STATS_DB_INFO;
    return Isolate.run(() {
      final manifest = <String, int>{};
      final localDb = DBWrapper.openFromInfoSync(fileInfo: localFileInfo, config: _dbConfig);
      try {
        localDb.loadEverythingKeyed((key, map) => manifest[key] = _syncTokenOf(map));
      } finally {
        localDb.close();
      }
      return manifest;
    });
  }

  Future<Map<String, Map<String, dynamic>>> buildSyncEntriesToSend(Map<String, dynamic> otherManifest) {
    final localFileInfo = AppPaths.VIDEO_ID_STATS_DB_INFO;
    return Isolate.run(() {
      final toSend = <String, Map<String, dynamic>>{};
      final localDb = DBWrapper.openFromInfoSync(fileInfo: localFileInfo, config: _dbConfig);
      try {
        localDb.loadEverythingKeyed((key, map) {
          if (_syncShouldReplace(_syncTokenOf(map), otherManifest[key] as int?)) toSend[key] = map;
        });
      } finally {
        localDb.close();
      }
      return toSend;
    });
  }

  Future<int> importSyncEntries(Map<String, dynamic> entries) {
    final localFileInfo = AppPaths.VIDEO_ID_STATS_DB_INFO;
    return Isolate.run(() {
      int changed = 0;
      final localDb = DBWrapper.openFromInfoSync(fileInfo: localFileInfo, config: _dbConfig);
      try {
        for (final e in entries.entries) {
          final incomingMap = (e.value as Map).cast<String, dynamic>();
          final local = localDb.get(e.key);
          if (!_syncShouldReplace(_syncTokenOf(incomingMap), local == null ? null : _syncTokenOf(local))) continue;
          localDb.put(e.key, incomingMap);
          changed++;
        }
      } finally {
        localDb.close();
      }
      return changed;
    });
  }
}
