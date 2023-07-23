import 'package:namida/class/track.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';

class Playlist {
  final String name;
  final List<TrackWithDate> tracks;
  final int creationDate;
  final int modifiedDate;
  final String comment;
  final List<String> moods;
  final bool isFav;

  const Playlist({
    required this.name,
    required this.tracks,
    required this.creationDate,
    required this.modifiedDate,
    required this.comment,
    required this.moods,
    required this.isFav,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      name: json['name'] ?? '',
      tracks: List<TrackWithDate>.from((json['tracks'] as List? ?? []).map((track) => TrackWithDate.fromJson(track))),
      creationDate: json['creationDate'] ?? currentTimeMS,
      modifiedDate: json['modifiedDate'] ?? currentTimeMS,
      comment: json['comment'] ?? '',
      moods: List<String>.from(json['moods'] ?? []),
      isFav: json['isFav'] ?? false,
    );
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
    return Playlist(
      name: name,
      tracks: tracks,
      creationDate: creationDate,
      modifiedDate: modifiedDate,
      comment: comment,
      moods: moods,
      isFav: isFav,
    );
  }
}
