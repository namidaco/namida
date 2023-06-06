import 'dart:io';

import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';

class TrackWithDate {
  late final int dateAdded;
  late final Track track;
  late final TrackSource source;

  TrackWithDate(
    this.dateAdded,
    this.track,
    this.source,
  );

  TrackWithDate.fromJson(Map<String, dynamic> json) {
    dateAdded = json['dateAdded'] ?? DateTime.now().millisecondsSinceEpoch;
    track = (json['track'] as String).toTrack();
    source = TrackSource.values.getEnum(json['source']) ?? TrackSource.local;
  }

  Map<String, dynamic> toJson() {
    return {
      'dateAdded': dateAdded,
      'track': track.path,
      'source': source.convertToString,
    };
  }
}

class TrackStats {
  /// Path of the track.
  String? path;

  /// Rating of the track out of 100.
  int rating = 0;

  /// List of tags for the track.
  List<String> tags = [];

  /// List of moods for the track.
  List<String> moods = [];

  /// Last Played Position of the track in Milliseconds.
  int lastPositionInMs = 0;

  TrackStats(
    this.path,
    this.rating,
    this.tags,
    this.moods,
    this.lastPositionInMs,
  );
  TrackStats.fromJson(Map<String, dynamic> json) {
    path = json['path'] ?? '';
    rating = json['rating'] ?? 0;
    tags = List<String>.from(json['tags'] ?? []);
    moods = List<String>.from(json['moods'] ?? []);
    lastPositionInMs = json['lastPositionInMs'] ?? 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'rating': rating,
      'tags': tags,
      'moods': moods,
      'lastPositionInMs': lastPositionInMs,
    };
  }
}

class Track {
  late final String title;
  late final String originalArtist;
  late final List<String> artistsList;
  late final String album;
  late final String albumArtist;
  late final String originalGenre;
  late final List<String> genresList;
  late final String composer;
  late final int track;
  late final int duration;
  late final int year;
  late final int size;
  late final int dateAdded;
  late final int dateModified;
  late final String path;
  late final String comment;
  late final int bitrate;
  late final int sampleRate;
  late final String format;
  late final String channels;
  late final int discNo;
  late final String language;
  late final String lyrics;
  TrackStats stats = TrackStats('', 0, [], [], 0);

  Track(
    this.title,
    this.originalArtist,
    this.artistsList,
    this.album,
    this.albumArtist,
    this.originalGenre,
    this.genresList,
    this.composer,
    this.track,
    this.duration,
    this.year,
    this.size,
    this.dateAdded,
    this.dateModified,
    this.path,
    this.comment,
    this.bitrate,
    this.sampleRate,
    this.format,
    this.channels,
    this.discNo,
    this.language,
    this.lyrics,
    this.stats,
  );

  Track.fromJson(Map<String, dynamic> json) {
    title = json['title'] ?? '';
    originalArtist = json['originalArtist'] ?? '';
    artistsList = Indexer.inst.splitArtist(json['title'], json['originalArtist']);
    album = json['album'] ?? '';
    albumArtist = json['albumArtist'] ?? '';
    originalGenre = json['originalGenre'] ?? '';
    genresList = Indexer.inst.splitGenre(json['originalGenre']);
    composer = json['composer'] ?? '';
    track = json['track'] ?? 0;
    duration = json['duration'] ?? 0;
    year = json['year'] ?? 0;
    size = json['size'] ?? 0;
    dateAdded = json['dateAdded'] ?? 0;
    dateModified = json['dateModified'] ?? 0;
    path = json['path'] ?? '';
    comment = json['comment'] ?? '';
    bitrate = json['bitrate'] ?? 0;
    sampleRate = json['sampleRate'] ?? 0;
    format = json['format'] ?? '';
    channels = json['channels'] ?? '';
    discNo = json['discNo'] ?? 0;
    language = json['language'] ?? '';
    lyrics = json['lyrics'] ?? '';
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'originalArtist': originalArtist,
      'album': album,
      'albumArtist': albumArtist,
      'originalGenre': originalGenre,
      'composer': composer,
      'track': track,
      'duration': duration,
      'year': year,
      'size': size,
      'dateAdded': dateAdded,
      'dateModified': dateModified,
      'path': path,
      'comment': comment,
      'bitrate': bitrate,
      'sampleRate': sampleRate,
      'format': format,
      'channels': channels,
      'discNo': discNo,
      'language': language,
      'lyrics': lyrics,
    };
  }

  @override
  bool operator ==(other) {
    if (other is! Track) {
      return false;
    }
    return path == other.path && title == other.title && album == other.album && artistsList == other.artistsList;
  }

  @override
  int get hashCode => (path + title + album + artistsList.toString()).hashCode;
}

extension TrackUtils on Track {
  String get filename => path.getFilename;
  String get filenameWOExt => path.getFilenameWOExt;
  String get extension => path.getExtension;
  String get folderPath => path.getDirectoryName;
  String get folderName => folderPath.split(Platform.pathSeparator).last;
  String get pathToImage => "$k_DIR_ARTWORKS$filename.png";
  String get youtubeLink {
    final match = comment.isEmpty ? null : kYoutubeRegex.firstMatch(comment)?[0];
    final match2 = filename.isEmpty ? null : kYoutubeRegex.firstMatch(filename)?[0];
    return match ?? match2 ?? '';
  }

  String get youtubeID => youtubeLink.getYoutubeID;
  String get audioInfoFormatted => [
        Duration(milliseconds: duration).label,
        size.fileSizeFormatted,
        "$bitrate kps",
        "$sampleRate hz",
      ].join(' • ');
  String get audioInfoFormattedCompact => [
        format,
        "$channels ch",
        "$bitrate kps",
        "${sampleRate / 1000} khz",
      ].join(' • ');

  bool get hasUnknownTitle => title == k_UNKNOWN_TRACK_TITLE;
  bool get hasUnknownAlbum => album == k_UNKNOWN_TRACK_ALBUM;
  bool get hasUnknownAlbumArtist => albumArtist == k_UNKNOWN_TRACK_ALBUMARTIST;
  bool get hasUnknownArtist => artistsList.first == k_UNKNOWN_TRACK_ARTIST;
  bool get hasUnknownGenre => genresList.first == k_UNKNOWN_TRACK_GENRE;
  bool get hasUnknownComposer => composer == k_UNKNOWN_TRACK_COMPOSER;
}
