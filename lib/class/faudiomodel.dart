import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:namida/class/replay_gain_data.dart';
import 'package:namida/core/extensions.dart';

class FArtwork {
  /// if specified directory to save in.
  /// or to save a new artwork when writing tags.
  File? file;

  /// if no directory to save in was specified.
  Uint8List? bytes;

  int? size;

  bool get hasArtwork => file != null || bytes != null;

  FutureOr<int?> get sizeActual => bytes?.length ?? file?.fileSize();

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
  bool get isValid =>
      title?.isNotEmpty == true || //
      album?.isNotEmpty == true ||
      artist?.isNotEmpty == true ||
      albumArtist?.isNotEmpty == true;

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
  final String? description;
  final String? synopsis;
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

  final double? ratingPercentage;
  final ReplayGainData? gainData;

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
    this.description,
    this.synopsis,
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
    this.ratingPercentage,
    this.gainData,
  });

  static String? _listToString(dynamic list) {
    if (list is! List || list.isEmpty) return null;
    if (list.length == 1) return list[0];
    return list.join('; ');
  }

  static double? ratingUnsignedIntToPercentage(String? rating) {
    if (rating == null) return null;
    final unsignedInt = int.tryParse(rating);
    if (unsignedInt == null) return null;
    return unsignedInt / 255;
  }

  static int ratingPercentageToUnsignedInt(double ratingPercentage) {
    return (ratingPercentage * 255).round();
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

    final ratingString = map["rating"] ?? map["RATING"];

    return FTags(
      path: map["path"],
      artwork: FArtwork.fromMap(map),
      title: _listToString(map["title"]) ?? map["TITLE"],
      album: map["album"] ?? map["ALBUM"],
      albumArtist: map["albumArtist"] ?? map["ALBUMARTIST"],
      artist: _listToString(map["artist"]) ?? map["ARTIST"],
      composer: _listToString(map["composer"]) ?? map["COMPOSER"],
      genre: _listToString(map["genre"]) ?? map["GENRE"],
      trackNumber: map["trackNumber"] ?? map["TRACKNUMBER"],
      trackTotal: map["trackTotal"] ?? map["TRACKTOTAL"],
      discNumber: map["discNumber"] ?? map["DISCNUMBER"],
      discTotal: map["discTotal"] ?? map["DISCTOTAL"],
      lyrics: lyricsList?.firstWhereEff((e) => e is String ? e.isValidLRC() : false) ?? lyricsList?.firstOrNull,
      comment: _listToString(map["comment"]) ?? map["COMMENT"],
      description: map["description"] ?? map["desc"] ?? map["DESCRIPTION"] ?? map["DESC"],
      synopsis: _listToString(map["synopsis"]) ?? map["synopsis"] ?? map["SYNOPSIS"],
      year: map["year"] ?? map["YEAR"],
      language: _listToString(map["language"]) ?? map["LANGUAGE"],
      lyricist: _listToString(map["lyricist"]) ?? map["LYRICIST"],
      djmixer: _listToString(map["djmixer"]) ?? map["DJMIXER"],
      mixer: _listToString(map["mixer"]) ?? map["MIXER"],
      mood: _listToString(map["mood"]) ?? map["MOOD"],
      rating: ratingString,
      remixer: _listToString(map["remixer"]) ?? map["REMIXER"],
      tags: _listToString(map["tags"]) ?? map["TAGS"],
      tempo: _listToString(map["tempo"]) ?? map["TEMPO"],
      country: _listToString(map["country"]) ?? map["COUNTRY"],
      recordLabel: _listToString(map["recordLabel"]) ?? map["RECORDLABEL"] ?? map["label"] ?? map["LABEL"],
      ratingPercentage: ratingUnsignedIntToPercentage(ratingString),
      gainData: ReplayGainData.fromAndroidMap(map),
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
      "description": description,
      "synopsis": synopsis,
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
      "rating": ratingPercentage != null ? "${ratingPercentageToUnsignedInt(ratingPercentage!)}" : rating,
      "remixer": remixer,
      "tags": tags,
      "tempo": tempo,
      "country": country,
      "recordLabel": recordLabel,
      "language": language,
      "gainData": gainData?.toMap(),
    };
  }
}

class FAudioModel {
  final FTags tags;
  final int? durationMS;
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
    this.durationMS,
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

  factory FAudioModel.dummy(String? path, FArtwork? artwork) {
    return FAudioModel(tags: FTags(path: path ?? '', artwork: artwork ?? FArtwork(size: 0)), hasError: true);
  }

  factory FAudioModel.fromMap(Map<String, dynamic> map) {
    String? format = map["format"];
    if (format != null && format.isNotEmpty) format = format.replaceFirst(RegExp('flac', caseSensitive: false), 'FLAC');
    return FAudioModel(
      tags: FTags.fromMap(map),
      durationMS: map["durationMS"],
      bitRate: map["bitRate"],
      channels: map["channels"],
      encodingType: map["encodingType"],
      format: format,
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
      "durationMS": durationMS,
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
