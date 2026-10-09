// ignore_for_file: avoid_rx_value_getter_outside_obx
import 'dart:io';

import 'package:history_manager/history_manager.dart';
import 'package:playlist_manager/playlist_manager.dart';

import 'package:namida/class/faudiomodel.dart';
import 'package:namida/class/file_matcher.dart';
import 'package:namida/class/folder.dart';
import 'package:namida/class/media_chapter.dart';
import 'package:namida/class/replay_gain_data.dart';
import 'package:namida/class/split_config.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/directory_index.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/music_web_server/music_web_server_base.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/tags_extractor/tags_extractor.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/iso639.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/youtube/class/download_task_base.dart';

part 'album_identifier_wrapper.dart';

class TrackWithDate extends Selectable<Map<String, dynamic>> with ItemWithDate, PlaylistItemWithDate {
  @override
  String get key => track.key;

  @override
  Track get track => _track;

  @override
  TrackWithDate? get trackWithDate => this;

  @override
  PlayableType get playableType => PlayableType.trackWithDate;

  final int dateAdded;
  final Track _track;
  final QueueSourceBase? queueSource;
  @override
  final TrackSource? sourceNull;

  const TrackWithDate({
    required this.dateAdded,
    required this._track,
    this.queueSource,
    TrackSource? source,
  }) : sourceNull = source;

  factory TrackWithDate.fromJson(Map<String, dynamic> json) {
    final finalTrack = Track.fromJson(json['track'] as String, isVideo: json['v'] == true);
    return TrackWithDate(
      dateAdded: json['dateAdded'] ?? currentTimeMS,
      track: finalTrack,
      queueSource: QueueSource.fromJson(json['qs']),
      source: json['source'] == null ? null : TrackSource.values.getEnum(json['source']),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'dateAdded': dateAdded,
      'track': _track.path,
      if (queueSource != null) 'qs': queueSource?.toJson(),
      if (sourceNull != null) 'source': sourceNull?.name,
      if (_track is Video) 'v': true,
    };
  }

  @override
  int get dateAddedMS => dateAdded;

  @override
  bool operator ==(other) {
    if (other is! TrackWithDate) return false;
    if (identical(this, other)) return true;
    return other.dateAdded == dateAdded && other._track == _track && other.sourceNull == sourceNull;
  }

  @override
  int get hashCode => Object.hash(dateAdded, _track, sourceNull);

  @override
  String toString() => "track: ${track.toString()}, source: $source, dateAdded: $dateAdded";
}

extension TWDUtils on List<TrackWithDate> {
  List<Track> toTracks() => map((e) => e.track).toList();
}

class TrackStats extends PlayableItemStats {
  final Track track;

  TrackStats({
    required this.track,
    required super.rating,
    required super.tags,
    required super.moods,
    required super.lastPositionInMs,
    required super.audioTrackId,
    required super.bookmarks,
    super.modifiedDate,
  });

  factory TrackStats.fromJson(Map<String, dynamic> json) {
    final track = Track.fromJson(json['track'] ?? '', isVideo: json['v'] == true);
    return TrackStats.fromJsonWithoutTrack(track, json);
  }
  factory TrackStats.fromJsonWithoutTrack(Track track, Map<String, dynamic> json) {
    final stats = PlayableItemStats.fromJson(json);
    return TrackStats(
      track: track,
      rating: stats.rating,
      tags: stats.tags,
      moods: stats.moods,
      lastPositionInMs: stats.lastPositionInMs,
      audioTrackId: stats.audioTrackId,
      bookmarks: stats.bookmarks,
      modifiedDate: stats.modifiedDate,
    );
  }

  factory TrackStats.buildEffective(Track track) {
    return TrackStats(
      track: track,
      rating: track.effectiveRating,
      tags: track.effectiveTags,
      moods: track.effectiveMoods,
      lastPositionInMs: track.lastPlayedPositionInMs ?? 0,
      audioTrackId: track.effectiveAudioTrackId,
      bookmarks: track.statsRaw?.bookmarks,
    );
  }

  Map<String, dynamic>? toJsonWithoutTrack() => super.toJson();

  @override
  Map<String, dynamic> toJson() {
    return {
      'track': track.path,
      if (track is Video) 'v': true,
      ...?super.toJson(),
    };
  }
}

class PlayableItemStats {
  /// Rating of the track out of 100.
  int rating = 0;

  /// List of tags for the track.
  List<String>? tags = [];

  /// List of moods for the track.
  List<String>? moods = [];

  /// Last Played Position of the track in Milliseconds.
  int lastPositionInMs = 0;

  String? audioTrackId;

  /// sorted by position.
  List<PlayableBookmark>? bookmarks;

  int modifiedDate = 0;

  PlayableItemStats({
    required this.rating,
    required this.tags,
    required this.moods,
    required this.lastPositionInMs,
    required this.audioTrackId,
    required this.bookmarks,
    this.modifiedDate = 0,
  });

  static List<String>? _parseList(dynamic listJson) {
    if (listJson is List && listJson.isNotEmpty) {
      return listJson.cast<String>();
    }
    return null;
  }

  static List<PlayableBookmark>? _parseBookmarks(dynamic listJson) {
    if (listJson is! List || listJson.isEmpty) return null;
    return listJson.map((e) => PlayableBookmark.fromJson((e as Map).cast<String, dynamic>())).toFixedList();
  }

  static List<String>? _cleanList(List<String>? current) {
    if (current == null || current.isEmpty || (current.length == 1 && current[0].isEmpty)) return null;
    return current;
  }

  factory PlayableItemStats.fromJson(Map<String, dynamic> json) {
    return PlayableItemStats(
      rating: json['rating'] ?? 0,
      tags: _parseList(json['tags']) ?? [],
      moods: _parseList(json['moods']) ?? [],
      lastPositionInMs: json['pms'] ?? json['lastPositionInMs'] ?? 0,
      audioTrackId: json['aid'],
      bookmarks: _parseBookmarks(json['bm']),
      modifiedDate: json['_mt'] ?? 0,
    );
  }

  Map<String, dynamic>? toJson() {
    final tagsFinal = _cleanList(tags);
    final moodsFinal = _cleanList(moods);
    final bookmarks = this.bookmarks;
    final bookmarksFinal = bookmarks == null || bookmarks.isEmpty ? null : bookmarks.map((e) => e.toJson()).toFixedList();
    final map = {
      if (rating > 0) 'rating': rating,
      'tags': ?tagsFinal,
      'moods': ?moodsFinal,
      if (lastPositionInMs > 0) 'pms': lastPositionInMs,
      if (audioTrackId != null) 'aid': audioTrackId,
      'bm': ?bookmarksFinal,
    };
    if (modifiedDate > 0) map['_mt'] = modifiedDate;
    if (map.isEmpty) return null;
    return map;
  }

  @override
  String toString() {
    return 'PlayableItemStats(rating: $rating, tags: $tags, moods: $moods, pms: $lastPositionInMs, aid: $audioTrackId, bm: ${bookmarks?.length})';
  }
}

class PlayableBookmark {
  final int positionMS;
  final String? title;

  const PlayableBookmark({
    required this.positionMS,
    required this.title,
  });

  factory PlayableBookmark.fromJson(Map<String, dynamic> json) {
    return PlayableBookmark(
      positionMS: json['p'] ?? 0,
      title: json['t'],
    );
  }

  Map<String, dynamic> toJson() => {
    'p': positionMS,
    't': ?title,
  };
}

enum PlayableType {
  track('tr', 0),
  video('v', 1),
  trackWithDate('twd', 2),
  ytVideo('ytv', 3);

  final String jsonKey;
  final int binaryId;
  const PlayableType(this.jsonKey, this.binaryId);
}

abstract class Playable<T extends Object> {
  const Playable();

  String get key;

  PlayableType get playableType;

  T toJson();
}

abstract class Selectable<T extends Object> extends Playable<T> {
  const Selectable();

  Track get track;
  TrackWithDate? get trackWithDate;

  @override
  bool operator ==(other) {
    return other is Selectable && track == other.track;
  }

  @override
  int get hashCode => track.hashCode;
}

extension SelectableListUtils on Iterable<Selectable> {
  Iterable<Track> get tracks => map((e) => e.track);
  Iterable<TrackWithDate> get tracksWithDates => whereType<TrackWithDate>();
}

class Track extends Selectable<String> {
  @override
  String get key => path;

  Folder get folder => Folder.explicit(folderPath);

  @override
  Track get track => this;

  @override
  TrackWithDate? get trackWithDate => null;

  @override
  PlayableType get playableType => PlayableType.track;

  late final isPhysical = !isNetwork;
  late final isNetwork = path.startsWith('http');

  final String path;
  Track.explicit(this.path);

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

  Future<bool> exists() => isNetwork ? Future.value(true) : File(path).exists();
  bool existsSync() => isNetwork ? true : File(path).existsSync();

  @override
  bool operator ==(other) {
    return other is Track && path == other.path;
  }

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => "Track($path)";

  @override
  String toJson() => path;
}

class TrackExtended {
  final String title;
  final String originalArtist;
  final List<String> artistsList;
  final String originalAlbum;
  final List<String> albumsList;
  final String albumArtist;
  final List<String> albumArtistsList;
  final String originalGenre;
  final List<String> genresList;
  final String originalStyle;
  final List<String> stylesList;
  final String originalMood;
  final List<String> moodList;
  final String composer;
  final List<String> composersList;
  final int trackNo;
  final int trackTo;

  /// track's duration in milliseconds.
  final int durationMS;
  final int year;
  final String yearText;
  final int size;
  final int dateAdded;
  final int dateModified;
  final String path;
  final String comment;
  final String description;
  final String synopsis;
  final int bitrate;
  final int sampleRate;
  final int bits;
  final bool? isLossless;
  final String format;
  final String channels;
  final int discNo;
  final int discTo;
  final String language;
  final List<String> languagesList;
  final String lyrics;
  final String label;
  final String releaseType;
  final int? bpm;
  final String musicalKey;
  final double rating;
  final String? originalTags;
  final List<String> tagsList;
  final ReplayGainData? gainData;
  final FTagsSortInfo? sortInfo;
  final String? hashKey;

  /// identifiers keyed by their picard tag name (`MUSICBRAINZ_TRACKID`, `ISRC`, ...), see [FTags.pickExtraTags].
  final Map<String, String>? extraTags;

  /// sorted by start, null when the file has less than 2.
  final List<MediaChapter>? chapters;

  final List<AlbumIdentifierWrapper> albumsIdentifiersWrappers;
  final bool isVideo;
  final String? server;

  List<AlbumIdentifierWrapper> albumsIdentifiersWrappersModifed(List<AlbumIdentifier> identifiers) => albumsIdentifiersWrappers.map((e) => e.modifyOnly(identifiers)).toList();

  // -- cache for image path instead of resolving it each time.
  // -- ignores `uniqueArtworkHash` since toggling it requires reindexing (new instances)
  int _pathToImageStamp = -1;
  String? _pathToImageCache;

  TrackExtended({
    required this.title,
    required this.originalArtist,
    required this.artistsList,
    required this.originalAlbum,
    required this.albumsList,
    required this.albumArtist,
    required this.albumArtistsList,
    required this.originalGenre,
    required this.genresList,
    required this.originalStyle,
    required this.stylesList,
    required this.originalMood,
    required this.moodList,
    required this.composer,
    required this.composersList,
    required this.trackNo,
    required this.trackTo,
    required this.durationMS,
    required this.year,
    required this.yearText,
    required this.size,
    required this.dateAdded,
    required this.dateModified,
    required this.path,
    required this.comment,
    required this.description,
    required this.synopsis,
    required this.bitrate,
    required this.sampleRate,
    required this.bits,
    required this.isLossless,
    required this.format,
    required this.channels,
    required this.discNo,
    required this.discTo,
    required this.language,
    required this.languagesList,
    required this.lyrics,
    required this.label,
    required this.releaseType,
    required this.bpm,
    required this.musicalKey,
    required this.rating,
    required this.originalTags,
    required this.tagsList,
    required this.gainData,
    required this.sortInfo,
    required this.hashKey,
    required this.extraTags,
    required this.chapters,
    required this.albumsIdentifiersWrappers,
    required this.isVideo,
    required this.server,
  });

  late final String yearPreferyyyyMMdd = _computeYearPreferyyyyMMdd();

  static String _padInt(int val) => val.toString().padLeft(2, '0');
  static String _padYear(int val) {
    if (val < 100) return '20${_padInt(val)}'; // also pad cuz can be 5 not 05
    return val.toString();
  }

  static final _extractNumbersRegex = RegExp(r'\d+');
  static int? enforceYearFormat(String? fromYearString) {
    if (fromYearString == null) return null;
    if (fromYearString.length == 4) {
      final intVal = fromYearString.getIntValue();
      if (intVal != null && intVal > 1000) return intVal;
    }
    final dateParts = <int>[];
    final matches = _extractNumbersRegex.allMatches(fromYearString);
    for (final m in matches) {
      final text = m[0];
      if (text != null && text.isNotEmpty) {
        final value = int.tryParse(text);
        if (value != null) {
          dateParts.add(value);
        }
      }
    }
    if (dateParts.isEmpty || dateParts[0] == 0) return null;

    try {
      final buffer = StringBuffer();
      final yearText = _padYear(dateParts[0]); // can be 2/4 digits (separated) or 6 yyyyMM or 8 yyyyMMdd
      buffer.write(yearText);
      if (dateParts.length > 1) {
        buffer.write(_padInt(dateParts[1]));
        if (dateParts.length > 2) {
          buffer.write(_padInt(dateParts[2]));
        } else {
          buffer.write('01'); // only add day 01 if month was there
        }
      } else if (yearText.length == 6) {
        buffer.write('01'); // also add day 01 if year was 6 yyyyMM
      }
      return int.parse(buffer.toString());
    } catch (_) {}

    return null;
  }

  String _computeYearPreferyyyyMMdd() {
    final yearString = year.toString();
    if (yearString.length == 4) return '${yearString}0101';
    final parsed = DateTime.tryParse(yearString);
    if (parsed == null) return yearString;
    return '${parsed.year.toString().padLeft(4, '0')}${_padInt(parsed.month)}${_padInt(parsed.day)}';
  }

  static final _trNmbrRegex = RegExp(r'[/\\|,-]');
  static (int?, int?)? parseTrackNumber(String? trnmbr) {
    if (trnmbr == null) return null;
    final parts = trnmbr.split(_trNmbrRegex);
    return (
      parts[0].getIntValue(),
      parts.length > 1 ? parts[1].getIntValue() : null,
    );
  }

  static String buildAudioInfoFormatted(int durationMS, int size, int bitrate, int sampleRate, ReplayGainData? gain) {
    final initial = [
      durationMS.milliSecondsLabel,
      size.fileSizeFormatted,
      "$bitrate kb/s",
      "$sampleRate hz",
    ].join(' • ');
    final gainFormatted = gain == null ? null : TrackExtended.buildGainDataFormatted(gain);
    if (gainFormatted == null) return initial;
    return '$initial\n$gainFormatted';
  }

  static String? buildGainDataFormatted(ReplayGainData gain) {
    return [
      '${gain.trackGain ?? '?'} dB gain',
      if (gain.trackPeak != null) '${gain.trackPeak} peak',
      if (gain.albumGain != null) '${gain.albumGain} dB gain (album)',
      if (gain.albumPeak != null) '${gain.albumPeak} peak (album)',
    ].join(' • ');
  }

  static String buildAudioInfoFormattedCompact(String format, String channels, int bitrate, int sampleRate) {
    return [
      format.toUpperCase(),
      if (channels.isNotEmpty && channels != '2' && !channels.contains('stereo') && !channels.contains('unknown')) "$channels ch",
      "$bitrate kb/s",
      if (sampleRate > 0) "${sampleRate / 1000} kHz",
    ].joinText(separator: ' • ');
  }

  static String buildAudioInfoFormattedAlt(String format, int bits, int sampleRate) {
    return [
      "$bits-bit/${sampleRate / 1000} kHz",
      format.toUpperCase(),
    ].joinText(separator: ' • ');
  }

  static String? generateHashKeyIfEnabled(String? path, String newPath, String? currentHashKey) {
    if (!TagsExtractor.defaultUniqueArtworkHash) return null;
    if (newPath == path) return currentHashKey;
    return newPath.toFastHashKey();
  }

  factory TrackExtended.derive({
    required SplitArtistGenreConfigsWrapper splitConfig,
    required String mbAlbumId,
    required String mbAlbumArtistId,
    required String title,
    required String originalArtist,
    required String originalAlbum,
    required String albumArtist,
    required String originalGenre,
    required String originalStyle,
    required String originalMood,
    required String composer,
    required int trackNo,
    required int trackTo,
    required int durationMS,
    required int year,
    required String yearText,
    required int size,
    required int dateAdded,
    required int dateModified,
    required String path,
    required String comment,
    required String description,
    required String synopsis,
    required int bitrate,
    required int sampleRate,
    required int bits,
    required bool? isLossless,
    required String format,
    required String channels,
    required int discNo,
    required int discTo,
    required String language,
    required String lyrics,
    required String label,
    required String releaseType,
    required int? bpm,
    required String musicalKey,
    required double rating,
    required String? originalTags,
    required ReplayGainData? gainData,
    required FTagsSortInfo? sortInfo,
    required String? hashKey,
    required Map<String, String>? extraTags,
    required List<MediaChapter>? chapters,
    required bool isVideo,
    required String? server,
  }) {
    final artistsConfig = splitConfig.artistsConfig;
    final genresConfig = splitConfig.genresConfig;
    final generalConfig = splitConfig.generalConfig;
    final albumsList = Indexer.splitAlbum(originalAlbum, config: splitConfig.albumConfig);
    // -- rows indexed before `yearText` existed only have the number
    final albumYear = yearText.isEmpty && year > 0 ? year.toString() : yearText;
    return TrackExtended(
      title: title,
      originalArtist: originalArtist,
      artistsList: Indexer.splitArtist(title: title, originalArtist: originalArtist, config: artistsConfig),
      originalAlbum: originalAlbum,
      albumsList: albumsList,
      albumArtist: albumArtist,
      albumArtistsList: Indexer.splitAlbumArtist(albumArtist, config: artistsConfig),
      originalGenre: originalGenre,
      genresList: Indexer.splitGenre(originalGenre, config: genresConfig),
      originalStyle: originalStyle,
      stylesList: Indexer.splitStyle(originalStyle, config: genresConfig),
      originalMood: originalMood,
      moodList: Indexer.splitGeneral(originalMood, config: generalConfig),
      composer: composer,
      composersList: Indexer.splitComposer(composer, config: artistsConfig),
      trackNo: trackNo,
      trackTo: trackTo,
      durationMS: durationMS,
      year: year,
      yearText: yearText,
      size: size,
      dateAdded: dateAdded,
      dateModified: dateModified,
      path: path,
      comment: comment,
      description: description,
      synopsis: synopsis,
      bitrate: bitrate,
      sampleRate: sampleRate,
      bits: bits,
      isLossless: isLossless,
      format: format,
      channels: channels,
      discNo: discNo,
      discTo: discTo,
      language: language,
      languagesList: Iso639.splitToLabels(language),
      lyrics: lyrics,
      label: label,
      releaseType: releaseType,
      bpm: bpm,
      musicalKey: musicalKey,
      rating: rating,
      originalTags: originalTags,
      tagsList: Indexer.splitGeneral(originalTags, config: generalConfig),
      gainData: gainData,
      sortInfo: sortInfo,
      hashKey: hashKey,
      extraTags: extraTags,
      chapters: chapters,
      albumsIdentifiersWrappers: AlbumIdentifierWrapper.fromAlbums(
        albums: albumsList,
        albumArtist: albumArtist,
        year: albumYear,
        mbAlbumId: mbAlbumId,
        mbAlbumArtistId: mbAlbumArtistId,
      ),
      isVideo: isVideo,
      server: server,
    );
  }

  /// normalized [sentValue], [placeholder] when it was sent empty, null when it wasn't sent.
  static String? _sentOriginal(String? sentValue, SplitterConfig config, String placeholder) {
    if (sentValue == null) return null;
    final normalized = config.normalize(sentValue);
    return normalized.isEmpty ? placeholder : normalized;
  }

  factory TrackExtended.fromJson(
    String path,
    Map<String, dynamic> json, {
    required SplitArtistGenreConfigsWrapper splitConfig,
  }) {
    // -- legacy wrappers have cleaned up album names, only their musicbrainz ids are read
    final wrappersJson = json['albumsIdentifiersWrappers'] ?? json['albumIdentifierWrapper'];
    final firstWrapperJson = wrappersJson is List ? wrappersJson.firstOrNull : wrappersJson;
    final mbIdsJson = firstWrapperJson is Map ? firstWrapperJson : null;
    return TrackExtended.derive(
      splitConfig: splitConfig,
      mbAlbumId: mbIdsJson?['mbAlbumId'] as String? ?? '',
      mbAlbumArtistId: mbIdsJson?['mbAlbumArtistId'] as String? ?? '',
      title: json['title'] ?? '',
      originalArtist: json['originalArtist'] ?? '',
      originalAlbum: json['originalAlbum'] ?? json['album'] ?? '',
      albumArtist: json['albumArtist'] ?? '',
      originalGenre: json['originalGenre'] ?? '',
      originalStyle: json['originalStyle'] ?? '',
      originalMood: json['originalMood'] ?? '',
      composer: json['composer'] ?? '',
      trackNo: json['trackNo'] ?? 0,
      trackTo: json['trackTo'] ?? 0,
      durationMS: json['durationMS'] ?? (json['duration'] is int ? json['duration'] * 1000 : 0),
      year: json['year'] ?? 0,
      yearText: json['yearText'] ?? '',
      size: json['size'] ?? 0,
      dateAdded: json['dateAdded'] ?? 0,
      dateModified: json['dateModified'] ?? 0,
      path: path,
      comment: json['comment'] ?? '',
      description: json['description'] ?? '',
      synopsis: json['synopsis'] ?? '',
      bitrate: json['bitrate'] ?? 0,
      sampleRate: json['sampleRate'] ?? 0,
      bits: json['bits'] ?? 0,
      isLossless: json['isLossless'],
      format: json['format'] ?? '',
      channels: json['channels'] ?? '',
      discNo: json['discNo'] ?? 0,
      discTo: json['discTo'] ?? 0,
      language: json['language'] ?? '',
      lyrics: json['lyrics'] ?? '',
      label: json['label'] ?? '',
      releaseType: json['releaseType'] ?? '',
      bpm: json['bpm'] as int?,
      musicalKey: json['musicalKey'] ?? '',
      rating: json['rating'] ?? 0.0,
      originalTags: json['originalTags'],
      gainData: json['gainData'] == null ? null : ReplayGainData.fromMap(json['gainData']),
      sortInfo: json['sortInfo'] == null ? null : FTagsSortInfo.fromMap(json['sortInfo']),
      hashKey: json['hashKey'],
      extraTags: _extraTagsFromJson(json['extraTags']),
      chapters: MediaChapter.listFromJson(json['chapters']),
      isVideo: json['v'] ?? false,
      server: json['server'],
    );
  }

  static Map<String, String>? _extraTagsFromJson(dynamic json) {
    if (json is! Map || json.isEmpty) return null;
    return Map<String, String>.from(json);
  }

  Map<String, dynamic> toJsonWithoutPath() {
    return {
      if (title.isNotEmpty) 'title': title,
      if (originalArtist.isNotEmpty) 'originalArtist': originalArtist,
      if (originalAlbum.isNotEmpty) 'originalAlbum': originalAlbum,
      if (albumArtist.isNotEmpty) 'albumArtist': albumArtist,
      if (originalGenre.isNotEmpty) 'originalGenre': originalGenre,
      if (originalStyle.isNotEmpty) 'originalStyle': originalStyle,
      if (originalMood.isNotEmpty) 'originalMood': originalMood,
      if (composer.isNotEmpty) 'composer': composer,
      if (trackNo > 0) 'trackNo': trackNo,
      if (trackTo > 0) 'trackTo': trackTo,
      if (durationMS > 0) 'durationMS': durationMS,
      'chapters': ?chapters?.map((e) => e.toJson()).toFixedList(),
      if (year > 0) 'year': year,
      if (yearText.isNotEmpty) 'yearText': yearText,
      if (size > 0) 'size': size,
      if (dateAdded > 0) 'dateAdded': dateAdded,
      if (dateModified > 0) 'dateModified': dateModified,
      if (comment.isNotEmpty) 'comment': comment,
      if (description.isNotEmpty) 'description': description,
      if (synopsis.isNotEmpty) 'synopsis': synopsis,
      if (bitrate > 0) 'bitrate': bitrate,
      if (sampleRate > 0) 'sampleRate': sampleRate,
      if (bits > 0) 'bits': bits,
      if (isLossless != null) 'isLossless': isLossless,
      if (format.isNotEmpty) 'format': format,
      if (channels.isNotEmpty) 'channels': channels,
      if (discNo > 0) 'discNo': discNo,
      if (discTo > 0) 'discTo': discTo,
      if (language.isNotEmpty) 'language': language,
      if (lyrics.isNotEmpty) 'lyrics': lyrics,
      if (label.isNotEmpty) 'label': label,
      if (releaseType.isNotEmpty) 'releaseType': releaseType,
      if (bpm != null && bpm! > 0) 'bpm': bpm,
      if (musicalKey.isNotEmpty) 'musicalKey': musicalKey,
      if (rating > 0) 'rating': rating,
      if (originalTags?.isNotEmpty == true) 'originalTags': originalTags,
      if (gainData != null) 'gainData': ?gainData?.toMap(),
      if (sortInfo != null) 'sortInfo': ?sortInfo?.toMap(),
      if (hashKey != null) 'hashKey': hashKey,
      if (extraTags != null) 'extraTags': extraTags,
      if (albumsIdentifiersWrappers.isNotEmpty) 'albumsIdentifiersWrappers': albumsIdentifiersWrappers.map((e) => e.toMap()).toFixedList(),
      if (isVideo) 'v': isVideo,
      if (server != null) 'server': server,
    };
  }

  @override
  bool operator ==(other) {
    return other is TrackExtended && path == other.path;
  }

  @override
  int get hashCode => path.hashCode;
}

extension TrackExtUtils on TrackExtended {
  Track asTrack() => isVideo ? Video.explicit(path) : Track.explicit(path);
  bool get hasUnknownTitle => title == UnknownTags.TITLE;
  bool get hasUnknownAlbum => originalAlbum == '' || originalAlbum == UnknownTags.ALBUM;
  bool get hasUnknownAlbumArtist => albumArtist == '' || albumArtist == UnknownTags.ALBUMARTIST;
  bool get hasUnknownComposer => composer == '' || composer == UnknownTags.COMPOSER;
  bool get hasUnknownArtist => artistsList.isEmpty || artistsList.first == UnknownTags.ARTIST;
  bool get hasUnknownGenre => genresList.isEmpty || genresList.first == UnknownTags.GENRE;
  bool get hasUnknownStyle => stylesList.isEmpty || stylesList.first == UnknownTags.STYLE;
  static bool hasUnknownMoods(List<String> moods) => moods.isEmpty || moods.first == UnknownTags.MOOD || moods.first == UnknownTags.GENRE; // cuz moods get parsed like genres

  bool get isPhysical => !isNetwork;
  bool get isNetwork => path.startsWith('http');

  Folder get folder => Folder.explicit(folderPath);

  String get filename => path.getFilename;
  String get filenameWOExt => path.getFilenameWOExt;
  String get extension => path.getExtension;
  String get folderPath => isNetwork ? DirectoryIndexServer.parseFromEncodedUrlPath(path).toDbKey() : path.getDirectoryPath;
  String get folderName => folderPath.splitLast(Platform.pathSeparator);
  String get pathToImage {
    final stamp = _imageKeyStamp();
    if (stamp == _pathToImageStamp) return _pathToImageCache!;
    final dirPath = isVideo ? AppDirs.THUMBNAILS : AppDirs.ARTWORKS;
    final res = "$dirPath${this.cacheKeyForImage(dirPath)}.png";
    _pathToImageCache = res;
    _pathToImageStamp = stamp;
    return res;
  }

  static int _imageKeyStamp() {
    if (!settings.groupArtworksByAlbum.value) return 0;
    return AlbumIdentifierWrapper.identifiersStamp(settings.albumIdentifiers.value) | (1 << 30);
  }

  String rawCacheKey(String parentDirPath) {
    return this.isNetwork
        ? DownloadTaskFilename.cleanupFilename(
            [
              title,
              MusicWebServer.baseUrlToId(path) ?? '',
            ].joinText(separator: ' - '),
            parentDirPath: parentDirPath,
          )
        : this.filename;
  }

  String cacheKeyForImage(String parentDirPath) {
    if (settings.groupArtworksByAlbum.value) {
      final id = albumsIdentifiersModified.map((e) => e.resolved()).join();
      if (id.isNotEmpty) return id;
    }
    final rawCacheKey = this.rawCacheKey(parentDirPath);
    if (TagsExtractor.defaultUniqueArtworkHash) {
      return hashKey != null ? "${rawCacheKey}_$hashKey" : rawCacheKey;
    }
    return rawCacheKey;
  }

  List<AlbumIdentifierWrapper> get albumsIdentifiersModified => albumsIdentifiersWrappersModifed(settings.albumIdentifiers.value);
  List<AlbumIdentifierWrapper> getAlbumsIdentifiersModified(List<AlbumIdentifier> identifiers) => albumsIdentifiersWrappersModifed(identifiers);

  String get youtubeLink {
    var comment = this.comment;
    if (comment.isNotEmpty) {
      var link = NamidaLinkUtils.extractYoutubeLink(comment);
      if (link != null) return link;
    }
    var filename = this.filename;
    if (filename.isNotEmpty) {
      var id = NamidaLinkRegex.youtubeIdInFilenameRegex.firstMatch(filename)?.group(1);
      id ??= NamidaLinkUtils.extractYoutubeIdInTrailingBrackets(filename);
      if (id != null) return 'youtu.be/$id';
    }
    return '';
  }

  String get youtubeID => youtubeLink.getYoutubeID;

  DateTime? yearAsDateTime({String? yearString}) {
    yearString ??= year.toString();
    final parsed = yearString.length == 4 ? DateTime(year) : DateTime.tryParse(yearString);
    return parsed;
  }

  TrackStats? get statsRaw => Indexer.inst.trackStatsMap.value[asTrack()];

  int get effectiveRating {
    int? r = statsRaw?.rating;
    if (r != null && r > 0) return r;
    var percentageRatingEmbedded = this.rating;
    return (percentageRatingEmbedded * 100).round();
  }

  List<String> get effectiveMoods {
    List<String>? m = statsRaw?.moods;
    if (m != null && m.isNotEmpty) return m;
    var moodsEmbedded = this.moodList;
    return moodsEmbedded;
  }

  List<String> get effectiveTags {
    List<String>? s = statsRaw?.tags;
    if (s != null && s.isNotEmpty) return s;
    var tagsEmbedded = this.tagsList;
    return tagsEmbedded;
  }

  String get audioInfoFormatted {
    final trExt = this;
    return TrackExtended.buildAudioInfoFormatted(
      trExt.durationMS,
      trExt.size,
      trExt.bitrate,
      trExt.sampleRate,
      trExt.gainData,
    );
  }

  String? get gainDataFormatted {
    final gain = gainData;
    if (gain == null) return null;
    return TrackExtended.buildGainDataFormatted(gain);
  }

  String get audioInfoFormattedCompact {
    final trExt = this;
    return TrackExtended.buildAudioInfoFormattedCompact(
      trExt.format,
      trExt.channels,
      trExt.bitrate,
      trExt.sampleRate,
    );
  }

  String get audioInfoFormattedAlt {
    final trExt = this;
    return TrackExtended.buildAudioInfoFormattedAlt(
      trExt.format,
      trExt.bits,
      trExt.sampleRate,
    );
  }

  /// applies only the fields [tag] has, an empty one clears it.
  TrackExtended copyWithTag({
    required FTags tag,
    required SplitArtistGenreConfigsWrapper splittersConfigs,
    int? dateModified,
    String? path,
    required bool generatePathHash,
    String? server,
  }) {
    final artistsConfig = splittersConfigs.artistsConfig;
    final genresConfig = splittersConfigs.genresConfig;
    final newPath = path ?? this.path;
    final newHashKey = TrackExtended.generateHashKeyIfEnabled(path, newPath, this.hashKey);

    var title = TrackExtended._sentOriginal(tag.title, artistsConfig, UnknownTags.TITLE) ?? this.title;
    var originalArtist = TrackExtended._sentOriginal(tag.artist, artistsConfig, UnknownTags.ARTIST) ?? this.originalArtist;
    final isTitleUnknown = title == UnknownTags.TITLE;
    final isArtistUnknown = originalArtist == UnknownTags.ARTIST;
    if (isTitleUnknown || isArtistUnknown) {
      final fromFilename = FileMatcher.getTitleAndArtistFromFilename(newPath.getFilenameWOExt);
      if (isTitleUnknown) title = fromFilename.$1;
      if (isArtistUnknown) originalArtist = fromFilename.$2;
    }
    final originalAlbum = TrackExtended._sentOriginal(tag.album, splittersConfigs.albumConfig, UnknownTags.ALBUM) ?? this.originalAlbum;
    final albumArtist = TrackExtended._sentOriginal(tag.albumArtist, artistsConfig, UnknownTags.ALBUMARTIST) ?? this.albumArtist;
    final originalGenre = TrackExtended._sentOriginal(tag.genre, genresConfig, UnknownTags.GENRE) ?? this.originalGenre;
    final originalStyle = TrackExtended._sentOriginal(tag.style, genresConfig, UnknownTags.STYLE) ?? this.originalStyle;
    final originalMood = TrackExtended._sentOriginal(tag.mood, splittersConfigs.generalConfig, UnknownTags.MOOD) ?? this.originalMood;
    final composer = TrackExtended._sentOriginal(tag.composer, artistsConfig, UnknownTags.COMPOSER) ?? this.composer;

    final trackNumber = tag.trackNumber;
    final trackTotal = tag.trackTotal;
    final discNumber = tag.discNumber;
    final discTotal = tag.discTotal;
    final trackNoParsed = trackNumber == null ? null : TrackExtended.parseTrackNumber(trackNumber);
    final discNoParsed = discNumber == null ? null : TrackExtended.parseTrackNumber(discNumber);
    final trackNo = trackNoParsed == null ? this.trackNo : trackNoParsed.$1 ?? 0;
    final discNo = discNoParsed == null ? this.discNo : discNoParsed.$1 ?? 0;
    final trackToFromTotal = trackTotal == null ? trackTo : TrackExtended.parseTrackNumber(trackTotal)?.$1 ?? 0;
    final discToFromTotal = discTotal == null ? discTo : TrackExtended.parseTrackNumber(discTotal)?.$1 ?? 0;

    final yearText = tag.year;
    final year = yearText == null ? this.year : TrackExtended.enforceYearFormat(yearText) ?? 0;
    final firstWrapper = albumsIdentifiersWrappers.firstOrNull;

    return TrackExtended.derive(
      splitConfig: splittersConfigs,
      mbAlbumId: tag.mbAlbumId ?? firstWrapper?.mbAlbumId ?? '',
      mbAlbumArtistId: tag.mbAlbumArtistId ?? firstWrapper?.mbAlbumArtistId ?? '',
      title: title,
      originalArtist: originalArtist,
      originalAlbum: originalAlbum,
      albumArtist: albumArtist,
      originalGenre: originalGenre,
      originalStyle: originalStyle,
      originalMood: originalMood,
      composer: composer,
      trackNo: trackNo,
      trackTo: trackNoParsed?.$2 ?? trackToFromTotal,
      year: year,
      yearText: yearText ?? this.yearText,
      dateModified: dateModified ?? this.dateModified,
      path: newPath,
      comment: tag.comment ?? comment,
      description: tag.description ?? description,
      synopsis: tag.synopsis ?? synopsis,
      discNo: discNo,
      discTo: discNoParsed?.$2 ?? discToFromTotal,
      language: tag.language ?? language,
      lyrics: tag.lyrics ?? lyrics,
      label: tag.recordLabel ?? label,
      releaseType: tag.releaseType ?? releaseType,
      bpm: tag.bpm ?? bpm,
      musicalKey: tag.musicalKey ?? musicalKey,
      rating: tag.ratingPercentage ?? rating,
      originalTags: tag.tags ?? originalTags,
      gainData: tag.gainData ?? gainData,
      sortInfo: tag.sortInfo ?? sortInfo,
      extraTags: tag.extraTags ?? extraTags,
      chapters: tag.chapters ?? chapters,

      // -- uneditable fields
      bitrate: bitrate,
      channels: channels,
      dateAdded: dateAdded,
      durationMS: durationMS,
      format: format,
      sampleRate: sampleRate,
      bits: bits,
      isLossless: isLossless,
      size: size,
      isVideo: isVideo,
      hashKey: newHashKey,
      server: server ?? this.server,
    );
  }

  TrackExtended rederive(SplitArtistGenreConfigsWrapper splitConfig) {
    final firstWrapper = albumsIdentifiersWrappers.firstOrNull;
    return TrackExtended.derive(
      splitConfig: splitConfig,
      mbAlbumId: firstWrapper?.mbAlbumId ?? '',
      mbAlbumArtistId: firstWrapper?.mbAlbumArtistId ?? '',
      title: title,
      originalArtist: originalArtist,
      originalAlbum: originalAlbum,
      albumArtist: albumArtist,
      originalGenre: originalGenre,
      originalStyle: originalStyle,
      originalMood: originalMood,
      composer: composer,
      trackNo: trackNo,
      trackTo: trackTo,
      durationMS: durationMS,
      year: year,
      yearText: yearText,
      size: size,
      dateAdded: dateAdded,
      dateModified: dateModified,
      path: path,
      comment: comment,
      description: description,
      synopsis: synopsis,
      bitrate: bitrate,
      sampleRate: sampleRate,
      bits: bits,
      isLossless: isLossless,
      format: format,
      channels: channels,
      discNo: discNo,
      discTo: discTo,
      language: language,
      lyrics: lyrics,
      label: label,
      releaseType: releaseType,
      bpm: bpm,
      musicalKey: musicalKey,
      rating: rating,
      originalTags: originalTags,
      gainData: gainData,
      sortInfo: sortInfo,
      hashKey: hashKey,
      extraTags: extraTags,
      chapters: chapters,
      isVideo: isVideo,
      server: server,
    );
  }

  TrackExtended copyWith({
    String? title,
    String? originalArtist,
    List<String>? artistsList,
    String? originalAlbum,
    List<String>? albumsList,
    String? albumArtist,
    List<String>? albumArtistsList,
    String? originalGenre,
    List<String>? genresList,
    String? originalStyle,
    List<String>? stylesList,
    String? originalMood,
    List<String>? moodList,
    String? composer,
    List<String>? composersList,
    int? trackNo,
    int? trackTo,

    /// track's duration in milliseconds.
    int? durationMS,
    List<MediaChapter>? chapters,
    int? year,
    String? yearText,
    int? size,
    int? dateAdded,
    int? dateModified,
    String? path,
    String? comment,
    String? description,
    String? synopsis,
    int? bitrate,
    int? sampleRate,
    int? bits,
    bool? isLossless,
    String? format,
    String? channels,
    int? discNo,
    int? discTo,
    String? language,
    List<String>? languagesList,
    String? lyrics,
    String? label,
    String? releaseType,
    int? bpm,
    String? musicalKey,
    double? rating,
    String? originalTags,
    List<String>? tagsList,
    ReplayGainData? gainData,
    FTagsSortInfo? sortInfo,
    Map<String, String>? extraTags,
    List<AlbumIdentifierWrapper>? albumsIdentifiersWrappers,
    bool? isVideo,
    required bool generatePathHash,
    String? server,
  }) {
    final newPath = path ?? this.path;
    String? newHashKey = TrackExtended.generateHashKeyIfEnabled(path, newPath, this.hashKey);
    return TrackExtended(
      title: title ?? this.title,
      originalArtist: originalArtist ?? this.originalArtist,
      artistsList: artistsList ?? this.artistsList,
      originalAlbum: originalAlbum ?? this.originalAlbum,
      albumsList: albumsList ?? this.albumsList,
      albumArtist: albumArtist ?? this.albumArtist,
      albumArtistsList: albumArtistsList ?? this.albumArtistsList,
      originalGenre: originalGenre ?? this.originalGenre,
      genresList: genresList ?? this.genresList,
      originalStyle: originalStyle ?? this.originalStyle,
      stylesList: stylesList ?? this.stylesList,
      originalMood: originalMood ?? this.originalMood,
      moodList: moodList ?? this.moodList,
      composer: composer ?? this.composer,
      composersList: composersList ?? this.composersList,
      trackNo: trackNo ?? this.trackNo,
      trackTo: trackTo ?? this.trackTo,
      durationMS: durationMS ?? this.durationMS,
      year: year ?? this.year,
      yearText: yearText ?? this.yearText,
      size: size ?? this.size,
      dateAdded: dateAdded ?? this.dateAdded,
      dateModified: dateModified ?? this.dateModified,
      path: newPath,
      comment: comment ?? this.comment,
      description: description ?? this.description,
      synopsis: synopsis ?? this.synopsis,
      bitrate: bitrate ?? this.bitrate,
      sampleRate: sampleRate ?? this.sampleRate,
      bits: bits ?? this.bits,
      isLossless: isLossless ?? this.isLossless,
      format: format ?? this.format,
      channels: channels ?? this.channels,
      discNo: discNo ?? this.discNo,
      discTo: discTo ?? this.discTo,
      language: language ?? this.language,
      languagesList: languagesList ?? this.languagesList,
      lyrics: lyrics ?? this.lyrics,
      label: label ?? this.label,
      releaseType: releaseType ?? this.releaseType,
      bpm: bpm ?? this.bpm,
      musicalKey: musicalKey ?? this.musicalKey,
      rating: rating ?? this.rating,
      originalTags: originalTags ?? this.originalTags,
      tagsList: tagsList ?? this.tagsList,
      gainData: gainData ?? this.gainData,
      sortInfo: sortInfo ?? this.sortInfo,
      hashKey: newHashKey,
      extraTags: extraTags ?? this.extraTags,
      chapters: chapters ?? this.chapters,
      albumsIdentifiersWrappers: albumsIdentifiersWrappers ?? this.albumsIdentifiersWrappers,
      isVideo: isVideo ?? this.isVideo,
      server: server ?? this.server,
    );
  }
}

extension TrackUtils on Track {
  bool hasInfoInLibrary() => toTrackExtOrNull() != null;
  TrackExtended toTrackExt() =>
      toTrackExtOrNull() ?? kDummyExtendedTrack.copyWith(title: path.getFilenameWOExt, path: path, generatePathHash: TagsExtractor.defaultUniqueArtworkHash);
  TrackExtended? toTrackExtOrNull() => Indexer.inst.allTracksMappedByPath[path];
  PhysicalMedia? asPhysical() => isPhysical ? PhysicalMedia.fromTrack(this) : null;
  PhysicalMedia? asPhysicalOrError() {
    final p = asPhysical();
    if (p != null) return p;
    _showErrorForNetworkTracks();
    return null;
  }

  String get yearPreferyyyyMMdd => toTrackExt().yearPreferyyyyMMdd;

  String get title => toTrackExt().title;
  String get originalArtist => toTrackExt().originalArtist;
  List<String> get artistsList => toTrackExt().artistsList;
  String get originalAlbum => toTrackExt().originalAlbum;
  List<String> get albumsList => toTrackExt().albumsList;
  String get albumArtist => toTrackExt().albumArtist;
  List<String> get albumArtistsList => toTrackExt().albumArtistsList;
  String get originalGenre => toTrackExt().originalGenre;
  List<String> get genresList => toTrackExt().genresList;
  String get originalStyle => toTrackExt().originalStyle;
  List<String> get stylesList => toTrackExt().stylesList;
  String get originalMood => toTrackExt().originalMood;
  List<String> get moodList => toTrackExt().moodList;
  List<String> get tagsList => toTrackExt().tagsList;
  String get composer => toTrackExt().composer;
  List<String> get composersList => toTrackExt().composersList;
  int get trackNo => toTrackExt().trackNo;
  int get trackTo => toTrackExt().trackTo;
  int get durationMS => toTrackExt().durationMS;
  int get year => toTrackExt().year;
  DateTime? yearAsDateTime({String? yearString}) => toTrackExt().yearAsDateTime(yearString: yearString);
  int get size => toTrackExt().size;
  int get dateAdded => toTrackExt().dateAdded;
  int get dateModified => toTrackExt().dateModified;
  String get comment => toTrackExt().comment;
  String get description => toTrackExt().description;
  String get synopsis => toTrackExt().synopsis;
  int get bitrate => toTrackExt().bitrate;
  int get sampleRate => toTrackExt().sampleRate;
  int get bits => toTrackExt().bits;
  bool? get isLossless => toTrackExt().isLossless;
  String get format => toTrackExt().format;
  String get channels => toTrackExt().channels;
  int get discNo => toTrackExt().discNo;
  int get discTo => toTrackExt().discTo;
  String get language => toTrackExt().language;
  List<String> get languagesList => toTrackExt().languagesList;
  String get lyrics => toTrackExt().lyrics;
  String get label => toTrackExt().label;
  String get releaseType => toTrackExt().releaseType;
  int? get bpm => toTrackExt().bpm;
  String get musicalKey => toTrackExt().musicalKey;

  int? get lastPlayedPositionInMs => statsRaw?.lastPositionInMs;
  TrackStats? get statsRaw => Indexer.inst.trackStatsMap.value[this];
  int get effectiveRating {
    int? r = statsRaw?.rating;
    if (r != null && r > 0) return r;
    var percentageRatingEmbedded = toTrackExt().rating;
    return (percentageRatingEmbedded * 100).round();
  }

  List<String> get effectiveMoods {
    List<String>? m = statsRaw?.moods;
    if (m != null && m.isNotEmpty) return m;
    var moodsEmbedded = toTrackExt().moodList;
    return moodsEmbedded;
  }

  List<String> get effectiveTags {
    List<String>? s = statsRaw?.tags;
    if (s != null && s.isNotEmpty) return s;
    var tagsEmbedded = toTrackExt().tagsList;
    return tagsEmbedded;
  }

  String? get effectiveAudioTrackId {
    return statsRaw?.audioTrackId;
  }

  String get filename => path.getFilename;
  String get filenameWOExt => path.getFilenameWOExt;
  String get extension => path.getExtension;
  String get folderPath => isNetwork ? DirectoryIndexServer.parseFromEncodedUrlPath(path).toDbKey() : path.getDirectoryPath;
  String get folderName => folderPath.splitLast(Platform.pathSeparator);
  String get pathToImage {
    final trExt = toTrackExtOrNull();
    if (trExt != null && trExt.isVideo == (this is Video)) return trExt.pathToImage; // -- to benefit from cache
    final dirPath = this is Video ? AppDirs.THUMBNAILS : AppDirs.ARTWORKS;
    final identifier = this.cacheKeyForImage(dirPath);
    return "$dirPath$identifier.png";
  }

  String get youtubeLink => toTrackExt().youtubeLink;
  String get youtubeID => youtubeLink.getYoutubeID;

  String get audioInfoFormatted => toTrackExt().audioInfoFormatted;
  String? get gainDataFormatted => toTrackExt().gainDataFormatted;
  String get audioInfoFormattedCompact => toTrackExt().audioInfoFormattedCompact;

  String rawCacheKey(String parentDirPath) => toTrackExt().rawCacheKey(parentDirPath);
  String cacheKeyForImage(String parentDirPath) => toTrackExt().cacheKeyForImage(parentDirPath);
  List<AlbumIdentifierWrapper> get albumsIdentifiersModified => toTrackExt().albumsIdentifiersModified;
  List<AlbumIdentifierWrapper> getAlbumsIdentifiersModified(List<AlbumIdentifier> identifiers) => toTrackExt().getAlbumsIdentifiersModified(identifiers);

  ReplayGainData? get gainData => toTrackExt().gainData;
  FTagsSortInfo? get sortInfo => toTrackExt().sortInfo;
}

extension TrackListUtils on List<Track> {
  List<PhysicalMedia> asPhysical() => where((element) => element.isPhysical).map((e) => PhysicalMedia.fromTrack(e)).toList();
  List<PhysicalMedia> asPhysicalOrError() {
    final p = asPhysical();
    final diff = this.length - p.length;
    if (diff > 0) {
      _showErrorForNetworkTracks(diff, this.length);
    }
    return p;
  }
}

extension TrackIterableUtils on Iterable<Track> {
  List<PhysicalMedia> mapAsPhysical() {
    return mapPhysical((tr) => PhysicalMedia.fromTrack(tr));
  }

  List<T> mapPhysical<T>(T Function(Track tr) callback) {
    final pListRes = <T>[];
    for (final tr in this) {
      if (tr.isPhysical) {
        pListRes.add(callback(tr));
      }
    }
    return pListRes;
  }

  List<PhysicalMedia> mapAsPhysicalOrError() {
    return mapPhysicalOrError((tr) => PhysicalMedia.fromTrack(tr));
  }

  List<T> mapPhysicalOrError<T>(T Function(Track tr) callback) {
    int totalCount = 0;
    final pListRes = <T>[];
    for (final tr in this) {
      totalCount++;
      if (tr.isPhysical) {
        pListRes.add(callback(tr));
      }
    }
    final diff = totalCount - pListRes.length;
    if (diff > 0) {
      _showErrorForNetworkTracks(diff, totalCount);
    }
    return pListRes;
  }
}

mixin PhysicalMedia on Track {
  static PhysicalMedia fromTrack(Track tr) => tr is Video ? PhysicalVideo._explicit(tr.path) : PhysicalTrack._explicit(tr.path);
}

class PhysicalTrack extends Track with PhysicalMedia {
  PhysicalTrack._explicit(super.path) : super.explicit();
}

class PhysicalVideo extends Video with PhysicalMedia {
  PhysicalVideo._explicit(super.path) : super.explicit();
}

void _showErrorForNetworkTracks([int? count, int? totalCount]) {
  var msg = lang.notSupportedForNetworkFiles;
  if (count != null && count > 1) {
    final totalCountText = totalCount == null ? '' : '/$totalCount';
    msg = '$msg: $count$totalCountText';
  }
  snackyy(
    message: msg,
    isError: true,
  );
}
