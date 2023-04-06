import 'package:namida/class/track.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/functions.dart';

class Queue {
  late final int date;
  late final List<Track> tracks;

  Queue(
    this.date,
    this.tracks,
  );

  /// Converts empty queue to AllTracksList.
  Queue.fromJson(Map<String, dynamic> json) {
    final List<Track> res = (json['tracks'] as List? ?? []).map((e) => Track.fromJson(e)).toList();
    final finalTracks = <Track>[];
    if (res.isEmpty) {
      finalTracks.addAll(allTracksInLibrary);
    } else {
      finalTracks.addAll(res);
    }

    date = json['date'] ?? DateTime.now().millisecondsSinceEpoch;
    tracks = finalTracks;
  }

  /// Saves an empty queue in case its the same as the AllTracksList.
  /// this should lower startup time and increase performance.
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    final finalTracks = checkIfQueueSameAsAllTracks(tracks) ? <Track>[] : tracks;
    data['date'] = date;
    data['tracks'] = finalTracks.map((e) => e.toJson()).toList();
    return data;
  }
}
