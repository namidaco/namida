import 'package:namida/class/track.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';

class Queue {
  final QueueSource source;
  final HomePageItems? homePageItem;
  final int date;
  final bool isFav;
  final List<Track> tracks;

  const Queue({
    required this.source,
    required this.homePageItem,
    required this.date,
    required this.isFav,
    required this.tracks,
  });

  /// // Converts empty queue to AllTracksList.
  /// BREAKING(>v2.5.6): no longer reads empty queue as allTracks.
  factory Queue.fromJson(Map<String, dynamic> json) {
    final finalTracks = (json['tracks'] as List? ?? []).mapped((e) => (e as String).toTrack());
    return Queue(
      source: QueueSource.values.getEnum(json['source'] ?? '') ?? QueueSource.others,
      homePageItem: HomePageItems.values.getEnum(json['homePageItem'] ?? ''),
      date: json['date'] ?? DateTime(1970),
      isFav: json['isFav'] ?? false,
      tracks: finalTracks,
    );
  }

  /// // Saves an empty queue in case its the same as the AllTracksList.
  /// // this should lower startup time and increase performance.
  /// BREAKING(>v2.5.6): no longer saving allTracks as empty queue.
  Map<String, dynamic> toJson() {
    return {
      'source': source.convertToString,
      'homePageItem': homePageItem?.convertToString,
      'date': date,
      'isFav': isFav,
      'tracks': tracks.mapped((e) => e.path),
    };
  }

  Queue copyWith({
    QueueSource? source,
    HomePageItems? homePageItem,
    int? date,
    bool? isFav,
    List<Track>? tracks,
  }) {
    return Queue(
      source: source ?? this.source,
      homePageItem: homePageItem ?? this.homePageItem,
      date: date ?? this.date,
      isFav: isFav ?? this.isFav,
      tracks: tracks ?? this.tracks,
    );
  }
}
