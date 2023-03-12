import 'package:namida/class/track.dart';
import 'package:namida/core/extensions.dart';

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

  Queue.fromJson(Map<String, dynamic> json) {
    final List<String> res = List.castFrom<dynamic, String>(json['tracks'] ?? []);
    name = json['name'] ?? '';
    tracks = res.toTracks;
    date = json['date'] ?? DateTime.now().millisecondsSinceEpoch;
    comment = json['comment'] ?? '';
    modes = List<String>.from(json['modes'] ?? []);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};

    data['name'] = name;
    data['tracks'] = tracks.map((e) => e.path).toList();
    data['date'] = date;
    data['comment'] = comment;
    data['modes'] = modes;

    return data;
  }
}
