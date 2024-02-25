import 'dart:io';

import 'package:history_manager/history_manager.dart';
import 'package:intl/intl.dart';

import 'package:namida/class/faudiomodel.dart';
import 'package:namida/class/folder.dart';
import 'package:namida/class/split_config.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';

class TrackWithDate extends Selectable implements ItemWithDate {
  final int dateAdded;
  final Track track;
  final TrackSource source;

  const TrackWithDate({
    required this.dateAdded,
    required this.track,
    required this.source,
  });

  factory TrackWithDate.fromJson(Map<String, dynamic> json) {
    return TrackWithDate(
      dateAdded: json['dateAdded'] ?? currentTimeMS,
      track: (json['track'] as String).toTrack(),
      source: TrackSource.values.getEnum(json['source']) ?? TrackSource.local,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dateAdded': dateAdded,
      'track': track.path,
      'source': source.convertToString,
    };
  }

  @override
  DateTime get dateTimeAdded => DateTime.fromMillisecondsSinceEpoch(dateAdded);

  @override
  bool operator ==(other) {
    if (other is TrackWithDate) {
      return dateAdded == other.dateAdded && source == other.source && track == other.track;
    }
    return false;
  }

  @override
  int get hashCode => "$track$source$dateAdded".hashCode;

  @override
  String toString() => "track: ${track.toString()}, source: $source, dateAdded: $dateAdded";
}

extension TWDUtils on List<TrackWithDate> {
  List<Track> toTracks() => mapped((e) => e.track);
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

abstract class Playable {
  const Playable();
}

abstract class Selectable extends Playable {
  const Selectable();

  @override
  bool operator ==(other) {
    if (other is Selectable) {
      return track == other.track;
    }
    return false;
  }

  @override
  int get hashCode => track.hashCode;
}

extension SelectableUtils on Selectable {
  Track get track {
    final tortwd = this;
    return tortwd is TrackWithDate ? tortwd.track : tortwd as Track;
  }

  TrackWithDate? get trackWithDate {
    final tortwd = this;
    return tortwd is TrackWithDate ? tortwd : null;
  }
}

extension SelectableListUtils on Iterable<Selectable> {
  Iterable<Track> get tracks => map((e) => e.track);
  Iterable<TrackWithDate> get tracksWithDates => whereType<TrackWithDate>();
}

class Track extends Selectable {
  final String path;
  const Track(this.path);

  @override
  bool operator ==(other) {
    if (other is Track) {
      return path == other.path;
    }
    return false;
  }

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => "path: $path";
}

class TrackExtended {
  final String title;
  final String originalArtist;
  final List<String> artistsList;
  final String album;
  final String albumArtist;
  final String originalGenre;
  final List<String> genresList;
  final String originalMood;
  final List<String> moodList;
  final String composer;
  final int trackNo;

  /// track's duration in seconds.
  final int duration;
  final int year;
  final int size;
  final int dateAdded;
  final int dateModified;
  final String path;
  final String comment;
  final int bitrate;
  final int sampleRate;
  final String format;
  final String channels;
  final int discNo;
  final String language;
  final String lyrics;

  const TrackExtended({
    required this.title,
    required this.originalArtist,
    required this.artistsList,
    required this.album,
    required this.albumArtist,
    required this.originalGenre,
    required this.genresList,
    required this.originalMood,
    required this.moodList,
    required this.composer,
    required this.trackNo,
    required this.duration,
    required this.year,
    required this.size,
    required this.dateAdded,
    required this.dateModified,
    required this.path,
    required this.comment,
    required this.bitrate,
    required this.sampleRate,
    required this.format,
    required this.channels,
    required this.discNo,
    required this.language,
    required this.lyrics,
  });

  factory TrackExtended.fromJson(
    Map<String, dynamic> json, {
    required ArtistsSplitConfig artistsSplitConfig,
    required GenresSplitConfig genresSplitConfig,
  }) {
    return TrackExtended(
      title: json['title'] ?? '',
      originalArtist: json['originalArtist'] ?? '',
      artistsList: Indexer.splitArtist(
        title: json['title'],
        originalArtist: json['originalArtist'],
        config: artistsSplitConfig,
      ),
      album: json['album'] ?? '',
      albumArtist: json['albumArtist'] ?? '',
      originalGenre: json['originalGenre'] ?? '',
      genresList: Indexer.splitGenre(
        json['originalGenre'],
        config: genresSplitConfig,
      ),
      originalMood: json['originalMood'] ?? '',
      moodList: Indexer.splitGenre(
        json['originalMood'],
        config: genresSplitConfig,
      ),
      composer: json['composer'] ?? '',
      trackNo: json['trackNo'] ?? 0,
      duration: json['duration'] ?? 0,
      year: json['year'] ?? 0,
      size: json['size'] ?? 0,
      dateAdded: json['dateAdded'] ?? 0,
      dateModified: json['dateModified'] ?? 0,
      path: json['path'] ?? '',
      comment: json['comment'] ?? '',
      bitrate: json['bitrate'] ?? 0,
      sampleRate: json['sampleRate'] ?? 0,
      format: json['format'] ?? '',
      channels: json['channels'] ?? '',
      discNo: json['discNo'] ?? 0,
      language: json['language'] ?? '',
      lyrics: json['lyrics'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'originalArtist': originalArtist,
      'album': album,
      'albumArtist': albumArtist,
      'originalGenre': originalGenre,
      'originalMood': originalMood,
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
    if (other is Track) {
      return path == other.path;
    }
    return false;
  }

  @override
  int get hashCode => path.hashCode;
}

extension TrackExtUtils on TrackExtended {
  Track toTrack() => Track(path);
  bool get hasUnknownTitle => title == UnknownTags.TITLE;
  bool get hasUnknownAlbum => album == '' || album == UnknownTags.ALBUM;
  bool get hasUnknownAlbumArtist => albumArtist == '' || albumArtist == UnknownTags.ALBUMARTIST;
  bool get hasUnknownComposer => composer == '' || composer == UnknownTags.COMPOSER;
  bool get hasUnknownArtist => artistsList.isEmpty || artistsList.firstOrNull == UnknownTags.ARTIST;
  bool get hasUnknownGenre => genresList.isEmpty || genresList.firstOrNull == UnknownTags.GENRE;
  bool get hasUnknownMood => moodList.isEmpty || moodList.firstOrNull == UnknownTags.MOOD;

  String get filename => path.getFilename;
  String get filenameWOExt => path.getFilenameWOExt;
  String get extension => path.getExtension;
  String get folderPath => path.getDirectoryName;
  Folder get folder => Folder(folderPath);
  String get folderName => folderPath.split(Platform.pathSeparator).last;
  String get pathToImage {
    final identifier = settings.groupArtworksByAlbum.value ? albumIdentifier : filename;
    return "${AppDirs.ARTWORKS}$identifier.png";
  }

  String get albumIdentifier => getAlbumIdentifier(settings.albumIdentifiers);

  String getAlbumIdentifier(List<AlbumIdentifier> identifiers) {
    final n = identifiers.contains(AlbumIdentifier.albumName) ? album : '';
    final aa = identifiers.contains(AlbumIdentifier.albumArtist) ? albumArtist : '';
    final y = identifiers.contains(AlbumIdentifier.year) ? year : '';
    return "$n$aa$y";
  }

  String get youtubeLink {
    final match = comment.isEmpty ? null : NamidaLinkRegex.youtubeLinkRegex.firstMatch(comment)?[0];
    if (match != null) return match;
    final match2 = filename.isEmpty ? null : NamidaLinkRegex.youtubeLinkRegex.firstMatch(filename)?[0];
    if (match2 != null) return match2;
    return '';
  }

  String get youtubeID => youtubeLink.getYoutubeID;

  TrackStats get stats => Indexer.inst.trackStatsMap[toTrack()] ?? TrackStats(kDummyTrack, 0, [], [], 0);

  String get yearPreferyyyyMMdd {
    final tostr = year.toString();
    final parsed = DateTime.tryParse(tostr);
    if (parsed != null) {
      return DateFormat('yyyyMMdd').format(parsed);
    }
    return tostr;
  }

  TrackExtended copyWithTag({
    required FTags tag,
    int? dateModified,
    String? path,
  }) {
    return TrackExtended(
      title: tag.title ?? title,
      originalArtist: tag.artist ?? originalArtist,
      artistsList: tag.artist != null ? [tag.artist!] : artistsList,
      album: tag.album ?? album,
      albumArtist: tag.albumArtist ?? albumArtist,
      originalGenre: tag.genre ?? originalGenre,
      genresList: tag.genre != null ? [tag.genre!] : genresList,
      originalMood: tag.mood ?? originalMood,
      moodList: tag.mood != null ? [tag.mood!] : moodList,
      composer: tag.composer ?? composer,
      trackNo: tag.trackNumber.getIntValue() ?? trackNo,
      year: tag.year.getIntValue() ?? year,
      dateModified: dateModified ?? this.dateModified,
      path: path ?? this.path,
      comment: tag.comment ?? comment,
      discNo: tag.discNumber.getIntValue() ?? discNo,
      language: tag.language ?? language,
      lyrics: tag.lyrics ?? lyrics,

      // -- uneditable fields
      bitrate: bitrate,
      channels: channels,
      dateAdded: dateAdded,
      duration: duration,
      format: format,
      sampleRate: sampleRate,
      size: size,
    );
  }

  TrackExtended copyWith({
    String? title,
    String? originalArtist,
    List<String>? artistsList,
    String? album,
    String? albumArtist,
    String? originalGenre,
    List<String>? genresList,
    String? originalMood,
    List<String>? moodList,
    String? composer,
    int? trackNo,

    /// track's duration in seconds.
    int? duration,
    int? year,
    int? size,
    int? dateAdded,
    int? dateModified,
    String? path,
    String? comment,
    int? bitrate,
    int? sampleRate,
    String? format,
    String? channels,
    int? discNo,
    String? language,
    String? lyrics,
  }) {
    return TrackExtended(
      title: title ?? this.title,
      originalArtist: originalArtist ?? this.originalArtist,
      artistsList: artistsList ?? this.artistsList,
      album: album ?? this.album,
      albumArtist: albumArtist ?? this.albumArtist,
      originalGenre: originalGenre ?? this.originalGenre,
      genresList: genresList ?? this.genresList,
      originalMood: originalMood ?? this.originalMood,
      moodList: moodList ?? this.moodList,
      composer: composer ?? this.composer,
      trackNo: trackNo ?? this.trackNo,
      duration: duration ?? this.duration,
      year: year ?? this.year,
      size: size ?? this.size,
      dateAdded: dateAdded ?? this.dateAdded,
      dateModified: dateModified ?? this.dateModified,
      path: path ?? this.path,
      comment: comment ?? this.comment,
      bitrate: bitrate ?? this.bitrate,
      sampleRate: sampleRate ?? this.sampleRate,
      format: format ?? this.format,
      channels: channels ?? this.channels,
      discNo: discNo ?? this.discNo,
      language: language ?? this.language,
      lyrics: lyrics ?? this.lyrics,
    );
  }
}

extension TrackUtils on Track {
  TrackExtended toTrackExt() => path.toTrackExt();
  TrackExtended? toTrackExtOrNull() => path.toTrackExtOrNull();

  set duration(int value) {
    final trx = Indexer.inst.allTracksMappedByPath[this];
    if (trx != null) {
      Indexer.inst.allTracksMappedByPath[this] = trx.copyWith(duration: value);
    }
  }

  String get yearPreferyyyyMMdd => toTrackExt().yearPreferyyyyMMdd;

  String get title => toTrackExt().title;
  String get originalArtist => toTrackExt().originalArtist;
  List<String> get artistsList => toTrackExt().artistsList;
  String get album => toTrackExt().album;
  String get albumArtist => toTrackExt().albumArtist;
  String get originalGenre => toTrackExt().originalGenre;
  List<String> get genresList => toTrackExt().genresList;
  String get originalMood => toTrackExt().originalMood;
  List<String> get moodList => toTrackExt().moodList;
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
  String get pathToImage {
    final identifier = settings.groupArtworksByAlbum.value ? albumIdentifier : filename;
    return "${AppDirs.ARTWORKS}$identifier.png";
  }

  String get youtubeLink => toTrackExt().youtubeLink;
  String get youtubeID => youtubeLink.getYoutubeID;

  String get audioInfoFormatted {
    final trExt = toTrackExt();
    return [
      trExt.duration.secondsLabel,
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

  String get albumIdentifier => toTrackExt().albumIdentifier;
  String getAlbumIdentifier(List<AlbumIdentifier> identifiers) => toTrackExt().getAlbumIdentifier(identifiers);
}
