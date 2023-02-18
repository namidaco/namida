import 'package:namida/class/track.dart';

class Playlist {
  late int id;
  late String name;
  late List<Track> tracks;
  late int date;
  late String comment;
  late List<String> modes;

  Playlist(
    this.id,
    this.name,
    this.tracks,
    this.date,
    this.comment,
    this.modes,
  );

  Playlist.fromJson(Map<String, dynamic> json) {
    id = json['id'] ?? 0;
    name = json['name'] ?? '';

    tracks = List<Track>.from(json['tracks'] ?? []);
    date = json['date'] ?? DateTime.now().millisecondsSinceEpoch;
    comment = json['comment'] ?? '';
    modes = List<String>.from(json['tracks'] ?? []);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};

    data['id'] = id;
    data['name'] = name;
    data['tracks'] = tracks;
    data['date'] = date;
    data['comment'] = comment;
    data['modes'] = modes;

    return data;
  }
}
