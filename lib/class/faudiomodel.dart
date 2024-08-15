import 'dart:io';
import 'dart:typed_data';

import 'package:namida/core/extensions.dart';

class FArtwork {
  /// if specified directory to save in.
  /// or to save a new artwork when writing tags.
  File? file;

  /// if no directory to save in was specified.
  Uint8List? bytes;

  int? size;

  bool get hasArtwork => file != null || bytes != null;

  int? get sizeActual => bytes?.length ?? file?.sizeInBytesSync();

  FArtwork({
    this.file,
    this.bytes,
    this.size,
  });

  factory FArtwork.fromMap(Map<String, dynamic> map) {
    final art = map["artwork"];
    return FArtwork(
      file: art is String ? File(art) : null,
      bytes: art is Uint8List ? art : null,
      size: map["artworkLength"],
    );
  }

  dynamic toMapValue() => file?.path ?? bytes;

  @override
  String toString() {
    return file?.toString() ?? bytes?.length.toString() ?? 'null';
  }
}

class FTags {
  /// Used for bulk extractions.
  final String path;
  final FArtwork artwork;
  final String? title;
  final String? album;
  final String? albumArtist;
  final String? artist;
  final String? composer;
  final String? genre;
  final String? trackNumber;
  final String? trackTotal;
  final String? discNumber;
  final String? discTotal;
  final String? lyrics;
  final String? comment;
  final String? year;
  final String? language;
  final String? lyricist;
  final String? djmixer;
  final String? mixer;
  final String? mood;
  final String? rating;
  final String? remixer;
  final String? tags;
  final String? tempo;
  final String? country;
  final String? recordLabel;

  const FTags({
    required this.path,
    required this.artwork,
    this.title,
    this.album,
    this.albumArtist,
    this.artist,
    this.composer,
    this.genre,
    this.trackNumber,
    this.trackTotal,
    this.discNumber,
    this.discTotal,
    this.lyrics,
    this.comment,
    this.year,
    this.language,
    this.lyricist,
    this.djmixer,
    this.mixer,
    this.mood,
    this.rating,
    this.remixer,
    this.tags,
    this.tempo,
    this.country,
    this.recordLabel,
  });

  static String? _listToString(List? list) {
    if (list == null || list.isEmpty) return null;
    if (list.length == 1) return list[0];
    return list.join('; ');
  }

  // -- upper cased are the ones extracted manually.
  factory FTags.fromMap(Map<String, dynamic> map) {
    var lyricsList = map["lyrics"] as List?;
    if (map["LYRICS"] is String) {
      // -- recreating bcz its fixed length.
      lyricsList = [
        map["LYRICS"] as String,
        ...?lyricsList,
      ];
    }

    return FTags(
      path: map["path"],
      artwork: FArtwork.fromMap(map),
      title: _listToString(map["title"]) ?? map["TITLE"],
      album: _listToString(map["album"]) ?? map["ALBUM"],
      albumArtist: _listToString(map["albumArtist"]) ?? map["ALBUMARTIST"],
      artist: _listToString(map["artist"]) ?? map["ARTIST"],
      composer: _listToString(map["composer"]) ?? map["COMPOSER"],
      genre: _listToString(map["genre"]) ?? map["GENRE"],
      trackNumber: map["trackNumber"] ?? map["TRACKNUMBER"],
      trackTotal: map["trackTotal"] ?? map["TRACKTOTAL"],
      discNumber: map["discNumber"] ?? map["DISCNUMBER"],
      discTotal: map["discTotal"] ?? map["DISCTOTAL"],
      lyrics: lyricsList?.firstWhereEff((e) => e is String ? e.isValidLRC() : false) ?? lyricsList?.firstOrNull,
      comment: _listToString(map["comment"]) ?? map["COMMENT"],
      year: _listToString(map["year"]) ?? map["YEAR"],
      language: _listToString(map["language"]) ?? map["LANGUAGE"],
      lyricist: _listToString(map["lyricist"]) ?? map["LYRICIST"],
      djmixer: _listToString(map["djmixer"]) ?? map["DJMIXER"],
      mixer: _listToString(map["mixer"]) ?? map["MIXER"],
      mood: _listToString(map["mood"]) ?? map["MOOD"],
      rating: map["rating"] ?? map["RATING"],
      remixer: _listToString(map["remixer"]) ?? map["REMIXER"],
      tags: _listToString(map["tags"]) ?? map["TAGS"],
      tempo: _listToString(map["tempo"]) ?? map["TEMPO"],
      country: _listToString(map["country"]) ?? map["COUNTRY"],
      recordLabel: _listToString(map["recordLabel"]) ?? map["RECORDLABEL"] ?? map["label"] ?? map["LABEL"],
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      "path": path,
      "artwork": artwork.toMapValue(),
      "title": title,
      "album": album,
      "albumArtist": albumArtist,
      "artist": artist,
      "composer": composer,
      "genre": genre,
      "comment": comment,
      "year": year,
      "trackNumber": trackNumber,
      "trackTotal": trackTotal,
      "discNumber": discNumber,
      "discTotal": discTotal,
      "lyrics": lyrics,
      "lyricist": lyricist,
      "djmixer": djmixer,
      "mixer": mixer,
      "mood": mood,
      "rating": rating,
      "remixer": remixer,
      "tags": tags,
      "tempo": tempo,
      "country": country,
      "recordLabel": recordLabel,
      "language": language,
    };
  }
}

class FAudioModel {
  final FTags tags;
  final int? length;
  final int? bitRate;
  final String? channels;
  final String? encodingType;
  final String? format;
  final int? sampleRate;
  final bool? isVariableBitRate;
  final bool? isLoseless;
  final bool hasError;
  final Map<String, String> errorsMap;

  const FAudioModel({
    required this.tags,
    this.length,
    this.bitRate,
    this.channels,
    this.encodingType,
    this.format,
    this.sampleRate,
    this.isVariableBitRate,
    this.isLoseless,
    this.hasError = false,
    this.errorsMap = const {},
  });

  factory FAudioModel.dummy(String? path) {
    return FAudioModel(tags: FTags(path: path ?? '', artwork: FArtwork(size: 0)), hasError: true);
  }

  factory FAudioModel.fromMap(Map<String, dynamic> map) {
    return FAudioModel(
      tags: FTags.fromMap(map),
      length: map["length"],
      bitRate: map["bitRate"],
      channels: map["channels"],
      encodingType: map["encodingType"],
      format: map["format"],
      sampleRate: map["sampleRate"],
      isVariableBitRate: map["isVariableBitRate"],
      isLoseless: map["isLoseless"],
      hasError: map["ERROR_FAULTY"] == true,
      errorsMap: (map["ERRORS"] as Map?)?.cast() ?? {},
    );
  }

  Map<String, dynamic> _toMapMini() {
    final tagsMap = tags.toMap();
    tagsMap.addAll(<String, dynamic>{
      "length": length,
      "bitRate": bitRate,
      "channels": channels,
      "encodingType": encodingType,
      "format": format,
      "sampleRate": sampleRate,
      "isVariableBitRate": isVariableBitRate,
      "isLoseless": isLoseless,
    });
    return tagsMap;
  }

  Map<String, dynamic> toMap() {
    final map = _toMapMini();
    map["artwork"] = tags.artwork.toMapValue();
    return map;
  }

  @override
  String toString() {
    final map = _toMapMini();
    map["artworkDetails"] = tags.artwork.toString();
    return map.toString();
  }
}
