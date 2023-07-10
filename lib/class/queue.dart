import 'package:namida/class/track.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';

class Queue {
  late final QueueSource source;
  late final int date;
  late bool isFav;
  late final List<Track> tracks;

  Queue(
    this.source,
    this.date,
    this.isFav,
    this.tracks,
  );

  /// Converts empty queue to AllTracksList.
  Queue.fromJson(Map<String, dynamic> json) {
    final res = (json['tracks'] as List? ?? []).map((e) => (e as String).toTrack());
    final finalTracks = <Track>[];
    if (res.isEmpty) {
      finalTracks.addAll(allTracksInLibrary);
    } else {
      finalTracks.addAll(res);
    }
    source = QueueSource.values.getEnum(json['source'] ?? '') ?? QueueSource.others;
    date = json['date'] ?? currentTimeMS;
    isFav = json['isFav'] ?? false;
    tracks = finalTracks;
  }

  /// Saves an empty queue in case its the same as the AllTracksList.
  /// this should lower startup time and increase performance.
  Map<String, dynamic> toJson() {
    final finalTracks = checkIfQueueSameAsAllTracks(tracks) ? <Track>[] : tracks;
    return {
      'source': source.convertToString,
      'date': date,
      'isFav': isFav,
      'tracks': finalTracks.map((e) => e.path).toList(),
    };
  }

  Queue copyWith({
    QueueSource? source,
    int? date,
    bool? isFav,
    List<Track>? tracks,
  }) {
    source ??= this.source;
    date ??= this.date;
    isFav ??= this.isFav;
    tracks ??= this.tracks;

    return Queue(source, date, isFav, tracks);
  }
}
