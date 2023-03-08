import 'package:namida/class/track.dart';
import 'package:namida/core/translations/strings.dart';

class Playlist {
  late int id;
  late String name;
  late List<TrackWithDate> tracks;
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
    name = (json['name']).replaceFirst('AUTO_GENERATED', Language.inst.AUTO_GENERATED) ?? '';
    tracks = List<TrackWithDate>.from(json['tracks'].map((track) => TrackWithDate.fromJson(track)).toList());
    date = json['date'] ?? DateTime.now().millisecondsSinceEpoch;
    comment = json['comment'] ?? '';
    modes = List<String>.from(json['modes'] ?? []);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};

    data['id'] = id;
    data['name'] = name;
    data['tracks'] = tracks.map((track) => track.toJson()).toList();
    data['date'] = date;
    data['comment'] = comment;
    data['modes'] = modes;

    return data;
  }
}
