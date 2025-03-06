import 'package:namida/class/track.dart';

class YoutubeIDStats extends PlayableItemStats {
  final String videoId;

  YoutubeIDStats({
    required this.videoId,
    required super.rating,
    required super.tags,
    required super.moods,
    required super.lastPositionInMs,
  });

  factory YoutubeIDStats.fromJson(Map<String, dynamic> json) {
    final videoId = json['videoId'] ?? '';
    return YoutubeIDStats.fromJsonWithoutVideoId(videoId, json);
  }
  factory YoutubeIDStats.fromJsonWithoutVideoId(String videoId, Map<String, dynamic> json) {
    final stats = PlayableItemStats.fromJson(json);
    return YoutubeIDStats(
      videoId: videoId,
      rating: stats.rating,
      tags: stats.tags,
      moods: stats.moods,
      lastPositionInMs: stats.lastPositionInMs,
    );
  }

  Map<String, dynamic>? toJsonWithoutVideoId() => super.toJson();

  @override
  Map<String, dynamic> toJson() {
    return {
      'videoId': videoId,
      ...?super.toJson(),
    };
  }
}
