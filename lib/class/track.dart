import 'dart:io';

import 'package:namida/class/folder.dart';
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
    dateAdded = json['dateAdded'] ?? currentTimeMS;
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

extension TWDUtils on List<TrackWithDate> {
  List<Track> toTracks() {
    final list = <Track>[];
    loop((e, index) => list.add(e.track));
    return list;
  }
}

class TrackStats {
  /// Path of the track.
  late Track track;

  /// Rating of the track out of 100.
  int rating = 0;

  /// List of tags for the track.
  List<String> tags = [];

  /// List of moods for the track.
  List<String> moods = [];

  /// Last Played Position of the track in Milliseconds.
  int lastPositionInMs = 0;

  TrackStats(
    this.track,
    this.rating,
    this.tags,
    this.moods,
    this.lastPositionInMs,
  );
  TrackStats.fromJson(Map<String, dynamic> json) {
    track = Track(json['track'] ?? '');
    rating = json['rating'] ?? 0;
    tags = List<String>.from(json['tags'] ?? []);
    moods = List<String>.from(json['moods'] ?? []);
    lastPositionInMs = json['lastPositionInMs'] ?? 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'track': track.path,
      'rating': rating,
      'tags': tags,
      'moods': moods,
      'lastPositionInMs': lastPositionInMs,
    };
  }

  @override
  String toString() => '${track.toString()}, rating: $rating, tags: $tags, moods: $moods, lastPositionInMs: $lastPositionInMs';
}

class Track {
  final String path;
  const Track(this.path);

  @override
  bool operator ==(other) {
    if (other is! Track) {
      return false;
    }
    return path == other.path;
  }

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => "path: $path";
}

class TrackExtended {
  late final String title;
  late final String originalArtist;
  late final List<String> artistsList;
  late final String album;
  late final String albumArtist;
  late final String originalGenre;
  late final List<String> genresList;
  late final String composer;
  late final int trackNo;
  late int duration;
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

  TrackExtended(
    this.title,
    this.originalArtist,
    this.artistsList,
    this.album,
    this.albumArtist,
    this.originalGenre,
    this.genresList,
    this.composer,
    this.trackNo,
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
  );

  TrackExtended.fromJson(Map<String, dynamic> json) {
    title = json['title'] ?? '';
    originalArtist = json['originalArtist'] ?? '';
    artistsList = Indexer.inst.splitArtist(json['title'], json['originalArtist']);
    album = json['album'] ?? '';
    albumArtist = json['albumArtist'] ?? '';
    originalGenre = json['originalGenre'] ?? '';
    genresList = Indexer.inst.splitGenre(json['originalGenre']);
    composer = json['composer'] ?? '';
    trackNo = json['trackNo'] ?? 0;
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
      'trackNo': trackNo,
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
    return path == other.path;
  }

  @override
  int get hashCode => path.hashCode;
}

extension TrackExtUtils on TrackExtended {
  Track toTrack() => Track(path);
  bool get hasUnknownTitle => title == k_UNKNOWN_TRACK_TITLE;
  bool get hasUnknownAlbum => album == k_UNKNOWN_TRACK_ALBUM;
  bool get hasUnknownAlbumArtist => albumArtist == k_UNKNOWN_TRACK_ALBUMARTIST;
  bool get hasUnknownArtist => artistsList.firstOrNull == k_UNKNOWN_TRACK_ARTIST;
  bool get hasUnknownGenre => genresList.firstOrNull == k_UNKNOWN_TRACK_GENRE;
  bool get hasUnknownComposer => composer == k_UNKNOWN_TRACK_COMPOSER;

  String get filename => path.getFilename;
  String get filenameWOExt => path.getFilenameWOExt;
  String get extension => path.getExtension;
  String get folderPath => path.getDirectoryName;
  Folder get folder => Folder(folderPath);
  String get folderName => folderPath.split(Platform.pathSeparator).last;
  String get pathToImage => "$k_DIR_ARTWORKS$filename.png";

  TrackStats get stats => Indexer.inst.trackStatsMap[toTrack()] ?? TrackStats(kDummyTrack, 0, [], [], 0);
}

extension TrackUtils on Track {
  TrackExtended toTrackExt() => path.toTrackExt();
  TrackExtended? toTrackExtOrNull() => path.toTrackExtOrNull();

  set duration(int value) => Indexer.inst.allTracksMappedByPath[this]?.duration = value;

  String get title => toTrackExt().title;
  String get originalArtist => toTrackExt().originalArtist;
  List<String> get artistsList => toTrackExt().artistsList;
  String get album => toTrackExt().album;
  String get albumArtist => toTrackExt().albumArtist;
  String get originalGenre => toTrackExt().originalGenre;
  List<String> get genresList => toTrackExt().genresList;
  String get composer => toTrackExt().composer;
  int get trackNo => toTrackExt().trackNo;
  int get duration => toTrackExt().duration;
  int get year => toTrackExt().year;
  int get size => toTrackExt().size;
  int get dateAdded => toTrackExt().dateAdded;
  int get dateModified => toTrackExt().dateModified;
  String get comment => toTrackExt().comment;
  int get bitrate => toTrackExt().bitrate;
  int get sampleRate => toTrackExt().sampleRate;
  String get format => toTrackExt().format;
  String get channels => toTrackExt().channels;
  int get discNo => toTrackExt().discNo;
  String get language => toTrackExt().language;
  String get lyrics => toTrackExt().lyrics;
  TrackStats get stats => Indexer.inst.trackStatsMap[this] ?? TrackStats(kDummyTrack, 0, [], [], 0);

  String get filename => path.getFilename;
  String get filenameWOExt => path.getFilenameWOExt;
  String get extension => path.getExtension;
  String get folderPath => path.getDirectoryName;
  Folder get folder => Folder(folderPath);
  String get folderName => folderPath.split(Platform.pathSeparator).last;
  String get pathToImage => "$k_DIR_ARTWORKS$filename.png";
  String get youtubeLink {
    final trExt = toTrackExt();
    final match = trExt.comment.isEmpty ? null : kYoutubeRegex.firstMatch(trExt.comment)?[0];
    final match2 = filename.isEmpty ? null : kYoutubeRegex.firstMatch(filename)?[0];
    return match ?? match2 ?? '';
  }

  String get youtubeID => youtubeLink.getYoutubeID;
  String get audioInfoFormatted {
    final trExt = toTrackExt();
    return [
      Duration(milliseconds: trExt.duration).label,
      trExt.size.fileSizeFormatted,
      "${trExt.bitrate} kps",
      "${trExt.sampleRate} hz",
    ].join(' • ');
  }

  String get audioInfoFormattedCompact {
    final trExt = toTrackExt();
    return [
      trExt.format,
      "${trExt.channels} ch",
      "${trExt.bitrate} kps",
      "${trExt.sampleRate / 1000} khz",
    ].join(' • ');
  }
}
