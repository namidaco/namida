import 'package:namida/class/track.dart';

class Playlist {
  late final String name;
  late final List<TrackWithDate> tracks;
  late final int date;
  late final String comment;
  late final List<String> modes;

  Playlist(
    this.name,
    this.tracks,
    this.date,
    this.comment,
    this.modes,
  );

  Playlist.fromJson(Map<String, dynamic> json) {
    name = json['name'] ?? '';
    tracks = List<TrackWithDate>.from((json['tracks'] ?? []).map((track) => TrackWithDate.fromJson(track)).toList());
    date = json['date'] ?? DateTime.now().millisecondsSinceEpoch;
    comment = json['comment'] ?? '';
    modes = List<String>.from(json['modes'] ?? []);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['name'] = name;
    data['tracks'] = tracks.map((track) => track.toJson()).toList();
    data['date'] = date;
    data['comment'] = comment;
    data['modes'] = modes;

    return data;
  }
}
