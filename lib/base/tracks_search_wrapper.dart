import 'dart:convert';
import 'dart:isolate';

import 'package:namida/class/split_config.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/lyrics_search_utils/lrc_search_utils_selectable.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';

class TracksSearchWrapper {
  final bool cleanup;
  final List<_CustomTrackExtended> _tracksExtended;
  final String Function(String) textCleanedForSearch;
  final String Function(String)? textNonCleanedForSearch;

  const TracksSearchWrapper._(
    this.cleanup,
    this._tracksExtended,
    this.textCleanedForSearch,
    this.textNonCleanedForSearch,
  );

  static Map<String, dynamic> generateParams(SendPort sendPort, Iterable<TrackExtended> tracks) {
    final filters = settings.trackSearchFilter.value;
    final addLyrics = filters.contains(TrackSearchFilter.lyrics);
    return {
      'tracks': tracks
          .map((e) => {
                'title': e.title,
                'artist': e.originalArtist,
                'album': e.album,
                'albumArtist': e.albumArtist,
                'genre': e.originalGenre,
                'composer': e.composer,
                'year': e.year,
                'comment': e.comment,
                if (addLyrics) 'lyrics': e.lyrics,
                'path': e.path,
                'v': e.isVideo,
              })
          .toList(),
      'artistsSplitConfig': ArtistsSplitConfig.settings().toMap(),
      'genresSplitConfig': GenresSplitConfig.settings().toMap(),
      'filters': filters,
      'cleanup': settings.enableSearchCleanup.value,
      'lyricsCacheDirectory': AppDirs.LYRICS,
      'sendPort': sendPort,
    };
  }

  factory TracksSearchWrapper.init(Map params) {
    final tracks = params['tracks'] as List<Map>;
    final artistsSplitConfig = ArtistsSplitConfig.fromMap(params['artistsSplitConfig']);
    final genresSplitConfig = GenresSplitConfig.fromMap(params['genresSplitConfig']);
    final tsf = params['filters'] as List<TrackSearchFilter>;
    final cleanup = params['cleanup'] as bool;
    final lyricsCacheDirectory = params['lyricsCacheDirectory'] as String;

    final tsfMap = <TrackSearchFilter, bool>{};
    tsf.loop((f) => tsfMap[f] = true);

    final stitle = tsfMap[TrackSearchFilter.title] ?? true;
    final sfilename = tsfMap[TrackSearchFilter.filename] ?? true;
    final sfolder = tsfMap[TrackSearchFilter.folder] ?? false;
    final salbum = tsfMap[TrackSearchFilter.album] ?? true;
    final salbumartist = tsfMap[TrackSearchFilter.albumartist] ?? false;
    final sartist = tsfMap[TrackSearchFilter.artist] ?? true;
    final sgenre = tsfMap[TrackSearchFilter.genre] ?? false;
    final scomposer = tsfMap[TrackSearchFilter.composer] ?? false;
    final scomment = tsfMap[TrackSearchFilter.comment] ?? false;
    final syear = tsfMap[TrackSearchFilter.year] ?? false;
    final slyrics = tsfMap[TrackSearchFilter.lyrics] ?? false;

    final textCleanedForSearch = _functionOfCleanup(cleanup);
    final textNonCleanedForSearch = cleanup ? _functionOfCleanup(false) : null;

    List<String>? splitThis(String? property, bool split) {
      if (!split || property == null) return null;
      return _splitTextCleanedAndNonCleaned(
        property,
        textCleanedForSearch,
        textNonCleanedForSearch,
      );
    }

    final tracksExtended = <_CustomTrackExtended>[];
    for (int i = 0; i < tracks.length; i++) {
      var trMap = tracks[i];
      final path = trMap['path'] as String;
      final title = trMap['title'] as String;
      final isVideo = trMap['v'] == true;
      final track = Track.decide(path, isVideo);

      tracksExtended.add(
        _CustomTrackExtended(
          track: track,
          splitTitle: splitThis(title, stitle),
          splitFilename: splitThis(path.getFilename, sfilename),
          splitFolder: splitThis(Track.explicit(path).folderName, sfolder),
          splitAlbum: splitThis(trMap['album'], salbum),
          splitAlbumArtist: splitThis(trMap['albumArtist'], salbumartist),
          splitArtist: sartist
              ? _mapListCleanedAndNonCleaned(
                  Indexer.splitArtist(
                    title: title,
                    originalArtist: trMap['artist'],
                    config: artistsSplitConfig,
                  ),
                  textCleanedForSearch,
                  textNonCleanedForSearch,
                )
              : [],
          splitGenre: sgenre
              ? _mapListCleanedAndNonCleaned(
                  Indexer.splitGenre(
                    trMap['genre'],
                    config: genresSplitConfig,
                  ),
                  textCleanedForSearch,
                  textNonCleanedForSearch,
                )
              : [],
          splitComposer: splitThis(trMap['composer'], scomposer),
          splitComment: splitThis(trMap['comment'], scomment),
          year: !syear
              ? null
              : _mapListCleanedAndNonCleaned(
                  [trMap['year'].toString()],
                  textCleanedForSearch,
                  textNonCleanedForSearch,
                ),
          lyrics: slyrics
              ? _fillAllAvailableLyrics(
                  track,
                  trMap['lyrics'] as String? ?? '',
                  lyricsCacheDirectory,
                )
              : null,
        ),
      );
    }
    return TracksSearchWrapper._(
      cleanup,
      tracksExtended,
      textCleanedForSearch,
      textNonCleanedForSearch,
    );
  }

  static List<String>? _fillAllAvailableLyrics(Track track, String embedded, String lyricsCacheDirectory) {
    final lyrics = <String>[];

    final lrcUtils = LrcSearchUtilsSelectableIsolate(
      mainLyricsCacheDirectory: lyricsCacheDirectory,
      kDummyExtendedTrack,
      track,
    );

    String? lrcContent;
    final lyricsFilesLocal = lrcUtils.deviceLRCFiles;
    for (final lf in lyricsFilesLocal) {
      if (lf.existsAndValidSync()) {
        lrcContent = lf.readAsStringSync();
        break;
      }
    }
    if (lrcContent == null) {
      final syncedInCache = lrcUtils.cachedLRCFile;
      if (syncedInCache.existsAndValidSync()) {
        lrcContent = syncedInCache.readAsStringSync();
      } else if (embedded.isNotEmpty) {
        lrcContent = embedded;
      }
    }
    if (lrcContent == null) {
      final textInCache = lrcUtils.cachedTxtFile;
      if (textInCache.existsAndValidSync()) {
        lrcContent = textInCache.readAsStringSync();
      }
    }
    if (lrcContent != null) {
      final lrc = lrcContent.parseLRC();
      if (lrc != null && lrc.lyrics.isNotEmpty) {
        for (final line in lrc.lyrics) {
          lyrics.add(line.readableText);
        }
      } else {
        final split = LineSplitter().convert(lrcContent);
        for (final line in split) {
          lyrics.add(line);
        }
      }
    }
    return lyrics;
  }

  static List<String> _splitTextCleanedAndNonCleaned(String text, String Function(String) textCleanedForSearch, String Function(String)? textNonCleanedForSearch) {
    final splitted = text.split(' ');
    return _mapListCleanedAndNonCleaned(splitted, textCleanedForSearch, textNonCleanedForSearch);
  }

  static List<String> _mapListCleanedAndNonCleaned(List<String> splitted, String Function(String) textCleanedForSearch, String Function(String)? textNonCleanedForSearch) {
    final allParts = <String>[];
    allParts.addAll(splitted.map((e) => textCleanedForSearch(e)));
    if (textNonCleanedForSearch != null) {
      for (int i = 0; i < splitted.length; i++) {
        var s = textNonCleanedForSearch(splitted[i]);
        if (!allParts.contains(s)) {
          allParts.add(s);
        }
      }
    }
    return allParts;
  }

  List<Track> filter(String text) {
    final result = <Track>[];
    _filter(text, (trExt, _) => result.add(trExt.track));
    return result;
  }

  List<int> filterIndices(String text) {
    final result = <int>[];
    _filter(text, (_, index) => result.add(index));
    return result;
  }

  Set<int> filterIndicesAsSet(String text) {
    final result = <int>{};
    _filter(text, (_, index) => result.add(index));
    return result;
  }

  void _filter(String text, void Function(_CustomTrackExtended trExt, int index) onMatch) {
    final lctext = textCleanedForSearch(text);
    final lctextNonCleaned = textNonCleanedForSearch == null ? null : textNonCleanedForSearch!(text);
    final lctextSplit = _splitTextCleanedAndNonCleaned(text, textCleanedForSearch, textNonCleanedForSearch);

    bool isMatch(List<String>? propertySplit) {
      if (propertySplit == null) return false;

      final match1 = lctextSplit.every((element) => propertySplit.any((p) => p.contains(element)));
      if (match1) return true;

      if (cleanup) {
        // cleanup means symbols and *spaces* are ignored.
        final propertyJoined = propertySplit.join();

        final match2 = propertyJoined.contains(lctext);
        if (match2) return true;

        if (lctextNonCleaned != null) {
          final match3 = propertyJoined.contains(lctextNonCleaned);
          if (match3) return true;
        }
      }

      return false;
    }

    bool isTrackMatch(_CustomTrackExtended trExt) {
      if (isMatch(trExt.splitTitle) ||
          isMatch(trExt.splitFolder) ||
          isMatch(trExt.splitFilename) ||
          isMatch(trExt.splitAlbum) ||
          isMatch(trExt.splitAlbumArtist) ||
          isMatch(trExt.splitArtist) ||
          isMatch(trExt.splitGenre) ||
          isMatch(trExt.splitComposer) ||
          isMatch(trExt.splitComment) ||
          isMatch(trExt.year) ||
          isMatch(trExt.lyrics)) {
        return true;
      }
      return false;
    }

    for (var i = 0; i < _tracksExtended.length; i++) {
      var trExt = _tracksExtended[i];
      if (isTrackMatch(trExt)) {
        onMatch(trExt, i);
      }
    }
  }

  static String Function(String text) _functionOfCleanup(bool enableSearchCleanup) {
    return (String textToClean) => enableSearchCleanup ? textToClean.cleanUpForComparison : textToClean.toLowerCase();
  }
}

class _CustomTrackExtended {
  final Track track;
  final List<String>? splitTitle;
  final List<String>? splitFilename;
  final List<String>? splitFolder;
  final List<String>? splitAlbum;
  final List<String>? splitAlbumArtist;
  final List<String>? splitArtist;
  final List<String>? splitGenre;
  final List<String>? splitComposer;
  final List<String>? splitComment;
  final List<String>? year;
  final List<String>? lyrics;

  const _CustomTrackExtended({
    required this.track,
    required this.splitTitle,
    required this.splitFilename,
    required this.splitFolder,
    required this.splitAlbum,
    required this.splitAlbumArtist,
    required this.splitArtist,
    required this.splitGenre,
    required this.splitComposer,
    required this.splitComment,
    required this.year,
    required this.lyrics,
  });
}
