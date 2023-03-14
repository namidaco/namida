import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';

class Queue {
  late String name;
  late List<Track> tracks;
  late int date;
  late String comment;
  late List<String> modes;

  Queue(
    this.name,
    this.tracks,
    this.date,
    this.comment,
    this.modes,
  );

  /// Converts empty queue to AllTracksList.
  Queue.fromJson(Map<String, dynamic> json) {
    final List<String> res = List.castFrom<dynamic, String>(json['tracks'] ?? []);
    final finalTracks = res.toTracks;
    if (finalTracks.isEmpty) finalTracks.addAll(Indexer.inst.tracksInfoList.toList());

    name = json['name'] ?? '';
    tracks = finalTracks;
    date = json['date'] ?? DateTime.now().millisecondsSinceEpoch;
    comment = json['comment'] ?? '';
    modes = List<String>.from(json['modes'] ?? []);
  }

  /// Saves an empty queue in case its the same as the AllTracksList.
  /// this should lower startup time and increase performance.
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    final finalTracks = checkIfQueueSameAsAllTracks(tracks) ? [] : tracks.map((e) => e.path).toList();
    data['name'] = name;
    data['tracks'] = finalTracks;
    data['date'] = date;
    data['comment'] = comment;
    data['modes'] = modes;

    return data;
  }
}
