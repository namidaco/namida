import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/core/extensions.dart';
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
    /// Since we are using paths instead of real Track Objects, we need to match all tracks with these paths
    final List<String> res = List.castFrom<dynamic, String>(json['tracks'] ?? []);
    final finalTracks = <Track>[];
    if (res.isEmpty) {
      finalTracks.addAll(Indexer.inst.tracksInfoList.toList());
    } else {
      finalTracks.addAll(res.toTracks);
    }

    date = json['date'] ?? DateTime.now().millisecondsSinceEpoch;
    tracks = finalTracks;
  }

  /// Saves an empty queue in case its the same as the AllTracksList.
  /// this should lower startup time and increase performance.
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    final finalTracks = checkIfQueueSameAsAllTracks(tracks) ? [] : tracks.map((e) => e.path).toList();
    data['date'] = date;
    data['tracks'] = finalTracks;
    return data;
  }
}
