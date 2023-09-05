import 'package:namida/class/track.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';

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

  /// Converts empty queue to AllTracksList.
  factory Queue.fromJson(Map<String, dynamic> json) {
    final res = (json['tracks'] as List? ?? []).mapped((e) => (e as String).toTrack());
    final finalTracks = <Track>[];
    if (res.isEmpty) {
      finalTracks.addAll(allTracksInLibrary);
    } else {
      finalTracks.addAll(res);
    }
    return Queue(
      source: QueueSource.values.getEnum(json['source'] ?? '') ?? QueueSource.others,
      homePageItem: HomePageItems.values.getEnum(json['homePageItem'] ?? ''),
      date: json['date'] ?? currentTimeMS,
      isFav: json['isFav'] ?? false,
      tracks: finalTracks,
    );
  }

  /// Saves an empty queue in case its the same as the AllTracksList.
  /// this should lower startup time and increase performance.
  Map<String, dynamic> toJson() {
    final finalTracks = checkIfQueueSameAsAllTracks(tracks) ? <Track>[] : tracks;
    return {
      'source': source.convertToString,
      'homePageItem': homePageItem?.convertToString,
      'date': date,
      'isFav': isFav,
      'tracks': finalTracks.mapped((e) => e.path),
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
