import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
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
    final finalTracks = (json['tracks'] as List?)?.map((e) {
          if (e is Map) {
            return Track.fromJson(e['t'] as String, isVideo: e['v'] == true);
          }
          return Track.fromJson(e as String, isVideo: false);
        }).toList() ??
        [];
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
      'source': source.name,
      'homePageItem': homePageItem?.name,
      'date': date,
      'isFav': isFav,
      'tracks': tracks.map((e) {
        return e is Video
            ? {
                't': e.toJson(),
                'v': true,
              }
            : e.toJson();
      }).toList(),
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
