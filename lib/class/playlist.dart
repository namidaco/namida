import 'package:namida/class/track.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';

class Playlist {
  late String name;
  late final List<TrackWithDate> tracks;
  late final int creationDate;
  late final int modifiedDate;
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
    tracks = List<TrackWithDate>.from((json['tracks'] as List? ?? []).mapped((track) => TrackWithDate.fromJson(track)));
    creationDate = json['creationDate'] ?? currentTimeMS;
    modifiedDate = json['modifiedDate'] ?? currentTimeMS;
    comment = json['comment'] ?? '';
    moods = List<String>.from(json['moods'] ?? []);
    isFav = json['isFav'] ?? false;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'tracks': tracks.mapped((track) => track.toJson()),
      'creationDate': creationDate,
      'modifiedDate': modifiedDate,
      'comment': comment,
      'moods': moods,
      'isFav': isFav,
    };
  }

  Playlist copyWith({
    String? name,
    List<TrackWithDate>? tracks,
    int? creationDate,
    int? modifiedDate,
    String? comment,
    bool? isFav,
    List<String>? moods,
  }) {
    name ??= this.name;
    tracks ??= this.tracks;
    creationDate ??= this.creationDate;
    modifiedDate ??= this.modifiedDate;
    comment ??= this.comment;
    moods ??= this.moods;
    isFav ??= this.isFav;
    return Playlist(name, tracks, creationDate, modifiedDate, comment, moods, isFav);
  }
}
