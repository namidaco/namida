import 'package:namida/class/track.dart';

class Playlist {
  late String name;
  late final List<TrackWithDate> tracks;
  late final int creationDate;
  late int modifiedDate;
  late final String comment;
  late final List<String> moods;
  late final bool isFav;

  Playlist(
    this.name,
    this.tracks,
    this.creationDate,
    this.modifiedDate,
    this.comment,
    this.moods,
    this.isFav,
  );

  Playlist.fromJson(Map<String, dynamic> json) {
    name = json['name'] ?? '';
    tracks = List<TrackWithDate>.from((json['tracks'] ?? []).map((track) => TrackWithDate.fromJson(track)).toList());
    creationDate = json['creationDate'] ?? DateTime.now().millisecondsSinceEpoch;
    modifiedDate = json['modifiedDate'] ?? DateTime.now().millisecondsSinceEpoch;
    comment = json['comment'] ?? '';
    moods = List<String>.from(json['moods'] ?? []);
    isFav = json['isFav'] ?? false;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'tracks': tracks.map((track) => track.toJson()).toList(),
      'creationDate': creationDate,
      'modifiedDate': modifiedDate,
      'comment': comment,
      'moods': moods,
      'isFav': isFav,
    };
  }
}
