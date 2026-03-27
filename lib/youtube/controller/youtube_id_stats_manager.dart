part of 'youtube_controller.dart';

class _YoutubeIDStatsManager {
  late final _statsDBManager = DBWrapper.openFromInfo(
    fileInfo: AppPaths.VIDEO_ID_STATS_DB_INFO,
    config: const DBConfig(createIfNotExist: true),
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
    );
    return _statsDBManager.put(item.id, newStats.toJsonWithoutVideoId());
  }
}
