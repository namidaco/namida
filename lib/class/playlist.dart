import 'package:namida/class/track.dart';

class Playlist {
  late final String name;
  late final List<TrackWithDate> tracks;
  late final int date;
  late final String comment;
  late final List<String> moods;
  late final bool isFav;

  Playlist(
    this.name,
    this.tracks,
    this.date,
    this.comment,
    this.moods,
    this.isFav,
  );

  Playlist.fromJson(Map<String, dynamic> json) {
    name = json['name'] ?? '';
    tracks = List<TrackWithDate>.from((json['tracks'] ?? []).map((track) => TrackWithDate.fromJson(track)).toList());
    date = json['date'] ?? DateTime.now().millisecondsSinceEpoch;
    comment = json['comment'] ?? '';
    moods = List<String>.from(json['moods'] ?? []);
    isFav = json['isFav'] ?? false;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'tracks': tracks.map((track) => track.toJson()).toList(),
      'date': date,
      'comment': comment,
      'moods': moods,
      'isFav': isFav,
    };
  }
}
