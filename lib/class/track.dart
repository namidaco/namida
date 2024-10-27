// ignore_for_file: avoid_rx_value_getter_outside_obx
import 'dart:io';

import 'package:history_manager/history_manager.dart';
import 'package:intl/intl.dart';

import 'package:namida/class/faudiomodel.dart';
import 'package:namida/class/folder.dart';
import 'package:namida/class/replay_gain_data.dart';
import 'package:namida/class/split_config.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';

class TrackWithDate extends Selectable<Map<String, dynamic>> implements ItemWithDate {
  @override
  Track get track => _track;

  @override
  TrackWithDate? get trackWithDate => this;

  final int dateAdded;
  final Track _track;
  final TrackSource source;

  const TrackWithDate({
    required this.dateAdded,
    required Track track,
    required this.source,
  }) : _track = track;

  factory TrackWithDate.fromJson(Map<String, dynamic> json) {
    final finalTrack = Track.fromJson(json['track'] as String, isVideo: json['v'] == true);
    return TrackWithDate(
      dateAdded: json['dateAdded'] ?? currentTimeMS,
      track: finalTrack,
      source: TrackSource.values.getEnum(json['source']) ?? TrackSource.local,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'dateAdded': dateAdded,
      'track': _track.path,
      'source': source.name,
      if (_track is Video) 'v': true,
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
  final Track track;

  /// Rating of the track out of 100.
  int rating = 0;

  /// List of tags for the track.
  List<String> tags = [];

  /// List of moods for the track.
  List<String> moods = [];

  /// Last Played Position of the track in Milliseconds.
  int lastPositionInMs = 0;

  TrackStats({
    required this.track,
    required this.rating,
    required this.tags,
    required this.moods,
    required this.lastPositionInMs,
  });

  static List<String>? _parseList(dynamic listJson) {
    if (listJson is List && listJson.isNotEmpty) {
      return listJson.cast<String>();
    }
    return null;
  }

  static List<String>? _cleanList(List<String> current) {
    if (current.isEmpty || (current.length == 1 && current[0].isEmpty)) return null;
    return current;
  }

  factory TrackStats.fromJson(Map<String, dynamic> json) {
    final track = Track.fromJson(json['track'] ?? '', isVideo: json['v'] == true);
    return TrackStats.fromJsonWithoutTrack(track, json);
  }

  factory TrackStats.fromJsonWithoutTrack(Track track, Map<String, dynamic> json) {
    return TrackStats(
      track: track,
      rating: json['rating'] ?? 0,
      tags: _parseList(json['tags']) ?? [],
      moods: _parseList(json['moods']) ?? [],
      lastPositionInMs: json['lastPositionInMs'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'track': track.path,
      ...?toJsonWithoutTrack(),
    };
  }

  Map<String, dynamic>? toJsonWithoutTrack() {
    final tagsFinal = _cleanList(tags);
    final moodsFinal = _cleanList(moods);
    final map = {
      if (rating > 0) 'rating': rating,
      if (tagsFinal != null) 'tags': tagsFinal,
      if (moodsFinal != null) 'moods': moodsFinal,
      if (lastPositionInMs > 0) 'lastPositionInMs': lastPositionInMs,
      if (track is Video) 'v': true,
    };
    if (map.isEmpty) return null;
    return map;
  }

  @override
  String toString() {
    return 'TrackStats(track: $track, rating: $rating, tags: $tags, moods: $moods, lastPositionInMs: $lastPositionInMs)';
  }
}

abstract class Playable<T extends Object> {
  const Playable();

  T toJson();
}

abstract class Selectable<T extends Object> extends Playable<T> {
  const Selectable();

  Track get track;
  TrackWithDate? get trackWithDate;

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

extension SelectableListUtils on Iterable<Selectable> {
  Iterable<Track> get tracks => map((e) => e.track);
  Iterable<TrackWithDate> get tracksWithDates => whereType<TrackWithDate>();
}

class Track extends Selectable<String> {
  Folder get folder => Folder.explicit(folderPath);

  @override
  Track get track => this;

  @override
  TrackWithDate? get trackWithDate => null;

  final String path;
  const Track.explicit(this.path);

  factory Track.decide(String path, bool? isVideo) => isVideo == true ? Video.explicit(path) : Track.explicit(path);

  factory Track.orVideo(String path) {
    return path.isVideo() ? Video.explicit(path) : Track.explicit(path);
  }

  static T fromTypeParameter<T extends Track>(Type type, String path) {
    return type == Video ? Video.explicit(path) as T : Track.explicit(path) as T;
  }

  factory Track.fromJson(String path, {required bool isVideo}) {
    return isVideo ? Video.explicit(path) : Track.explicit(path);
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

  @override
  String toString() => "path: $path";

  @override
  String toJson() => path;
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

  /// track's duration in milliseconds.
  final int durationMS;
  final int year;
  final int size;
  final int dateAdded;
  final int dateModified;
  final String path;
  final String comment;
  final String description;
  final String synopsis;
  final int bitrate;
  final int sampleRate;
  final String format;
  final String channels;
  final int discNo;
  final String language;
  final String lyrics;
  final String label;
  final double rating;
  final String? originalTags;
  final List<String> tagsList;
  final ReplayGainData? gainData;

  final bool isVideo;

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
    required this.durationMS,
    required this.year,
    required this.size,
    required this.dateAdded,
    required this.dateModified,
    required this.path,
    required this.comment,
    required this.description,
    required this.synopsis,
    required this.bitrate,
    required this.sampleRate,
    required this.format,
    required this.channels,
    required this.discNo,
    required this.language,
    required this.lyrics,
    required this.label,
    required this.rating,
    required this.originalTags,
    required this.tagsList,
    required this.gainData,
    required this.isVideo,
  });

  static String _padInt(int val) => val.toString().padLeft(2, '0');

  static int? enforceYearFormat(String? fromYearString) {
    final intVal = fromYearString.getIntValue();
    if (intVal != null) return intVal;
    if (fromYearString != null) {
      try {
        final yearDate = DateTime.parse(fromYearString.replaceAll(RegExp(r'[\s]'), '-'));
        return int.parse("${yearDate.year}${_padInt(yearDate.month)}${_padInt(yearDate.day)}");
      } catch (_) {}
    }
    return null;
  }

  factory TrackExtended.fromJson(
    Map<String, dynamic> json, {
    required ArtistsSplitConfig artistsSplitConfig,
    required GenresSplitConfig genresSplitConfig,
    required GeneralSplitConfig generalSplitConfig,
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
      moodList: Indexer.splitGeneral(
        json['originalMood'],
        config: generalSplitConfig,
      ),
      composer: json['composer'] ?? '',
      trackNo: json['trackNo'] ?? 0,
      durationMS: json['durationMS'] ?? (json['duration'] is int ? json['duration'] * 1000 : 0),
      year: json['year'] ?? 0,
      size: json['size'] ?? 0,
      dateAdded: json['dateAdded'] ?? 0,
      dateModified: json['dateModified'] ?? 0,
      path: json['path'] ?? '',
      comment: json['comment'] ?? '',
      description: json['description'] ?? '',
      synopsis: json['synopsis'] ?? '',
      bitrate: json['bitrate'] ?? 0,
      sampleRate: json['sampleRate'] ?? 0,
      format: json['format'] ?? '',
      channels: json['channels'] ?? '',
      discNo: json['discNo'] ?? 0,
      language: json['language'] ?? '',
      lyrics: json['lyrics'] ?? '',
      label: json['label'] ?? '',
      rating: json['rating'] ?? 0.0,
      originalTags: json['originalTags'],
      tagsList: Indexer.splitGeneral(
        json['originalTags'],
        config: generalSplitConfig,
      ),
      gainData: json['gainData'] == null ? null : ReplayGainData.fromMap(json['gainData']),
      isVideo: json['v'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (title.isNotEmpty) 'title': title,
      if (originalArtist.isNotEmpty) 'originalArtist': originalArtist,
      if (album.isNotEmpty) 'album': album,
      if (albumArtist.isNotEmpty) 'albumArtist': albumArtist,
      if (originalGenre.isNotEmpty) 'originalGenre': originalGenre,
      if (originalMood.isNotEmpty) 'originalMood': originalMood,
      if (composer.isNotEmpty) 'composer': composer,
      if (trackNo > 0) 'trackNo': trackNo,
      if (durationMS > 0) 'durationMS': durationMS,
      if (year > 0) 'year': year,
      if (size > 0) 'size': size,
      if (dateAdded > 0) 'dateAdded': dateAdded,
      if (dateModified > 0) 'dateModified': dateModified,
      if (path.isNotEmpty) 'path': path,
      if (comment.isNotEmpty) 'comment': comment,
      if (description.isNotEmpty) 'description': description,
      if (synopsis.isNotEmpty) 'synopsis': synopsis,
      if (bitrate > 0) 'bitrate': bitrate,
      if (sampleRate > 0) 'sampleRate': sampleRate,
      if (format.isNotEmpty) 'format': format,
      if (channels.isNotEmpty) 'channels': channels,
      if (discNo > 0) 'discNo': discNo,
      if (language.isNotEmpty) 'language': language,
      if (lyrics.isNotEmpty) 'lyrics': lyrics,
      if (label.isNotEmpty) 'label': label,
      if (rating > 0) 'rating': rating,
      if (originalTags?.isNotEmpty == true) 'originalTags': originalTags,
      if (gainData != null) 'gainData': gainData?.toMap(),
      'v': isVideo,
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
  Track asTrack() => isVideo ? Video.explicit(path) : Track.explicit(path);
  bool get hasUnknownTitle => title == UnknownTags.TITLE;
  bool get hasUnknownAlbum => album == '' || album == UnknownTags.ALBUM;
  bool get hasUnknownAlbumArtist => albumArtist == '' || albumArtist == UnknownTags.ALBUMARTIST;
  bool get hasUnknownComposer => composer == '' || composer == UnknownTags.COMPOSER;
  bool get hasUnknownArtist => artistsList.isEmpty || artistsList.first == UnknownTags.ARTIST;
  bool get hasUnknownGenre => genresList.isEmpty || genresList.first == UnknownTags.GENRE;
  bool get hasUnknownMood => moodList.isEmpty || moodList.first == UnknownTags.MOOD || moodList.first == UnknownTags.GENRE; // cuz moods get parsed like genres

  String get filename => path.getFilename;
  String get filenameWOExt => path.getFilenameWOExt;
  String get extension => path.getExtension;
  String get folderPath => path.getDirectoryPath;
  String get folderName => folderPath.splitLast(Platform.pathSeparator);
  String get pathToImage {
    final identifier = settings.groupArtworksByAlbum.value ? albumIdentifier : filename;
    return "${isVideo ? AppDirs.THUMBNAILS : AppDirs.ARTWORKS}$identifier.png";
  }

  String get albumIdentifier => getAlbumIdentifier(settings.albumIdentifiers.value);

  String getAlbumIdentifier(List<AlbumIdentifier> identifiers) {
    final n = identifiers.contains(AlbumIdentifier.albumName) ? album : '';
    final aa = identifiers.contains(AlbumIdentifier.albumArtist) ? albumArtist : '';
    final y = identifiers.contains(AlbumIdentifier.year) ? year : '';
    return "$n$aa$y";
  }

  String get youtubeLink {
    var comment = this.comment;
    if (comment.isNotEmpty) {
      var link = NamidaLinkUtils.extractYoutubeLink(comment);
      if (link != null) return link;
    }
    var filename = this.filename;
    if (filename.isNotEmpty) {
      var id = RegExp('[v|id]=(.{11})').firstMatch(filename)?.group(1);
      if (id != null) return 'youtu.be/$id';
    }
    return '';
  }

  String get youtubeID => youtubeLink.getYoutubeID;

  TrackStats? get stats => Indexer.inst.trackStatsMap.value[asTrack()];

  String get yearPreferyyyyMMdd {
    final tostr = year.toString();
    final parsed = DateTime.tryParse(tostr);
    if (parsed != null) {
      return DateFormat('yyyyMMdd').format(parsed);
    }
    return tostr;
  }

  String get audioInfoFormatted {
    final trExt = this;
    final initial = [
      trExt.durationMS.milliSecondsLabel,
      trExt.size.fileSizeFormatted,
      "${trExt.bitrate} kbps",
      "${trExt.sampleRate} hz",
    ].join(' • ');
    final gainFormatted = trExt.gainDataFormatted;
    if (gainFormatted == null) return initial;
    return '$initial\n$gainFormatted';
  }

  String? get gainDataFormatted {
    final gain = gainData;
    if (gain == null) return null;
    return [
      '${gain.trackGain ?? '?'} dB gain',
      if (gain.trackPeak != null) '${gain.trackPeak} peak',
      if (gain.albumGain != null) '${gain.albumGain} dB gain (album)',
      if (gain.albumPeak != null) '${gain.albumPeak} peak (album)',
    ].join(' • ');
  }

  String get audioInfoFormattedCompact {
    final trExt = this;
    return [
      trExt.format,
      "${trExt.channels} ch",
      "${trExt.bitrate} kbps",
      "${trExt.sampleRate / 1000} khz",
    ].joinText(separator: ' • ');
  }

  TrackExtended copyWithTag({
    required FTags tag,
    required SplitArtistGenreConfigsWrapper splittersConfigs,
    int? dateModified,
    String? path,
  }) {
    final finaltitle = tag.title ?? title;
    final finalartists = tag.artist != null
        ? Indexer.splitArtist(
            title: finaltitle,
            originalArtist: tag.artist!,
            config: splittersConfigs.artistsConfig,
          )
        : artistsList;
    final finalgenres = tag.genre != null
        ? Indexer.splitGenre(
            tag.genre,
            config: splittersConfigs.genresConfig,
          )
        : genresList;
    final finalmoods = tag.mood != null
        ? Indexer.splitGeneral(
            tag.mood,
            config: splittersConfigs.generalConfig,
          )
        : moodList;
    final finaltagsEmbedded = tag.tags != null
        ? Indexer.splitGeneral(
            tag.tags,
            config: splittersConfigs.generalConfig,
          )
        : tagsList;
    return TrackExtended(
      title: finaltitle,
      originalArtist: tag.artist ?? originalArtist,
      artistsList: finalartists,
      album: tag.album ?? album,
      albumArtist: tag.albumArtist ?? albumArtist,
      originalGenre: tag.genre ?? originalGenre,
      genresList: finalgenres,
      originalMood: tag.mood ?? originalMood,
      moodList: finalmoods,
      composer: tag.composer ?? composer,
      trackNo: tag.trackNumber.getIntValue() ?? trackNo,
      year: TrackExtended.enforceYearFormat(tag.year) ?? year,
      dateModified: dateModified ?? this.dateModified,
      path: path ?? this.path,
      comment: tag.comment ?? comment,
      description: tag.description ?? description,
      synopsis: tag.synopsis ?? synopsis,
      discNo: tag.discNumber.getIntValue() ?? discNo,
      language: tag.language ?? language,
      lyrics: tag.lyrics ?? lyrics,
      label: tag.recordLabel ?? label,
      rating: tag.ratingPercentage ?? rating,
      originalTags: tag.tags ?? originalTags,
      tagsList: finaltagsEmbedded,
      gainData: tag.gainData ?? gainData,

      // -- uneditable fields
      bitrate: bitrate,
      channels: channels,
      dateAdded: dateAdded,
      durationMS: durationMS,
      format: format,
      sampleRate: sampleRate,
      size: size,
      isVideo: isVideo,
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

    /// track's duration in milliseconds.
    int? durationMS,
    int? year,
    int? size,
    int? dateAdded,
    int? dateModified,
    String? path,
    String? comment,
    String? description,
    String? synopsis,
    int? bitrate,
    int? sampleRate,
    String? format,
    String? channels,
    int? discNo,
    String? language,
    String? lyrics,
    String? label,
    double? rating,
    String? originalTags,
    List<String>? tagsList,
    ReplayGainData? gainData,
    bool? isVideo,
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
      durationMS: durationMS ?? this.durationMS,
      year: year ?? this.year,
      size: size ?? this.size,
      dateAdded: dateAdded ?? this.dateAdded,
      dateModified: dateModified ?? this.dateModified,
      path: path ?? this.path,
      comment: comment ?? this.comment,
      description: description ?? this.description,
      synopsis: synopsis ?? this.synopsis,
      bitrate: bitrate ?? this.bitrate,
      sampleRate: sampleRate ?? this.sampleRate,
      format: format ?? this.format,
      channels: channels ?? this.channels,
      discNo: discNo ?? this.discNo,
      language: language ?? this.language,
      lyrics: lyrics ?? this.lyrics,
      label: label ?? this.label,
      rating: rating ?? this.rating,
      originalTags: originalTags ?? this.originalTags,
      tagsList: tagsList ?? this.tagsList,
      gainData: gainData ?? this.gainData,
      isVideo: isVideo ?? this.isVideo,
    );
  }
}

extension TrackUtils on Track {
  bool hasInfoInLibrary() => toTrackExtOrNull() != null;
  TrackExtended toTrackExt() => toTrackExtOrNull() ?? kDummyExtendedTrack.copyWith(title: path.getFilenameWOExt, path: path);
  TrackExtended? toTrackExtOrNull() => Indexer.inst.allTracksMappedByPath[path];

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
  int get durationMS => toTrackExt().durationMS;
  int get year => toTrackExt().year;
  int get size => toTrackExt().size;
  int get dateAdded => toTrackExt().dateAdded;
  int get dateModified => toTrackExt().dateModified;
  String get comment => toTrackExt().comment;
  String get description => toTrackExt().description;
  String get synopsis => toTrackExt().synopsis;
  int get bitrate => toTrackExt().bitrate;
  int get sampleRate => toTrackExt().sampleRate;
  String get format => toTrackExt().format;
  String get channels => toTrackExt().channels;
  int get discNo => toTrackExt().discNo;
  String get language => toTrackExt().language;
  String get lyrics => toTrackExt().lyrics;
  String get label => toTrackExt().label;

  int? get lastPlayedPositionInMs => _stats?.lastPositionInMs;
  TrackStats? get _stats => Indexer.inst.trackStatsMap[this];
  int get effectiveRating {
    int? r = _stats?.rating;
    if (r != null && r > 0) return r;
    var percentageRatingEmbedded = toTrackExt().rating;
    return (percentageRatingEmbedded * 100).round();
  }

  List<String> get effectiveMoods {
    List<String>? m = _stats?.moods;
    if (m != null && m.isNotEmpty) return m;
    var moodsEmbedded = toTrackExt().moodList;
    return moodsEmbedded;
  }

  List<String> get effectiveTags {
    List<String>? s = _stats?.tags;
    if (s != null && s.isNotEmpty) return s;
    var tagsEmbedded = toTrackExt().tagsList;
    return tagsEmbedded;
  }

  String get filename => path.getFilename;
  String get filenameWOExt => path.getFilenameWOExt;
  String get extension => path.getExtension;
  String get folderPath => path.getDirectoryPath;
  String get folderName => folderPath.splitLast(Platform.pathSeparator);
  String get pathToImage {
    final identifier = settings.groupArtworksByAlbum.value ? albumIdentifier : filename;
    return "${this is Video ? AppDirs.THUMBNAILS : AppDirs.ARTWORKS}$identifier.png";
  }

  String get youtubeLink => toTrackExt().youtubeLink;
  String get youtubeID => youtubeLink.getYoutubeID;

  String get audioInfoFormatted => toTrackExt().audioInfoFormatted;
  String? get gainDataFormatted => toTrackExt().gainDataFormatted;
  String get audioInfoFormattedCompact => toTrackExt().audioInfoFormattedCompact;

  String get albumIdentifier => toTrackExt().albumIdentifier;
  String getAlbumIdentifier(List<AlbumIdentifier> identifiers) => toTrackExt().getAlbumIdentifier(identifiers);

  ReplayGainData? get gainData => toTrackExt().gainData;
}
