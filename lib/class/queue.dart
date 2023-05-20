import 'package:namida/class/track.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';

class Queue {
  late final String name;
  late final int date;
  late final bool isFav;
  late final List<Track> tracks;

  Queue(
    this.name,
    this.date,
    this.isFav,
    this.tracks,
  );

  /// Converts empty queue to AllTracksList.
  Queue.fromJson(Map<String, dynamic> json) {
    final List<Track> res = (json['tracks'] as List? ?? []).map((e) => (e as String).toTrack()).toList();
    final finalTracks = <Track>[];
    if (res.isEmpty) {
      finalTracks.addAll(allTracksInLibrary);
    } else {
      finalTracks.addAll(res);
    }

    name = json['name'] ?? '';
    date = json['date'] ?? DateTime.now().millisecondsSinceEpoch;
    isFav = json['isFav'] ?? false;
    tracks = finalTracks;
  }

  /// Saves an empty queue in case its the same as the AllTracksList.
  /// this should lower startup time and increase performance.
  Map<String, dynamic> toJson() {
    final finalTracks = checkIfQueueSameAsAllTracks(tracks) ? <Track>[] : tracks;
    return {
      'name': name,
      'date': date,
      'isFav': isFav,
      'tracks': finalTracks.map((e) => e.path).toList(),
    };
  }
}
