import 'dart:convert';
import 'dart:isolate';

import 'package:lrc/lrc.dart';

import 'package:namida/class/split_config.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/history_controller.dart';
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
    final addDescription = filters.contains(TrackSearchFilter.description);
    final addLyrics = filters.contains(TrackSearchFilter.lyrics);
    final addMoods = filters.contains(TrackSearchFilter.moods);
    final addTags = filters.contains(TrackSearchFilter.tags);
    return {
      'tracks': tracks
          .map(
            (e) => {
              'title': e.title,
              'artist': e.originalArtist,
              'album': e.originalAlbum,
              'albumArtist': e.albumArtist,
              'genre': e.originalGenre,
              'composer': e.composer,
              'year': e.year,
              'comment': e.comment,
              if (addDescription) 'description': e.description,
              if (addLyrics) 'lyrics': e.lyrics,
              if (addMoods) 'moods': e.effectiveMoods,
              if (addTags) 'tags': e.effectiveTags,
              'path': e.path,
              'v': e.isVideo,
              'lc': HistoryController.inst.topTracksMapListens.value[e.asTrack()]?.length,
            },
          )
          .toFixedList(),
      'splitConfig': SplitArtistGenreConfigsWrapper.settings(),
      'filters': filters,
      'cleanup': settings.enableSearchCleanup.value,
      'lyricsCacheDirectory': AppDirs.LYRICS,
      'sendPort': sendPort,
    };
  }

  factory TracksSearchWrapper.init(Map params) {
    final tracks = params['tracks'] as List<Map>;
    final splitConfig = params['splitConfig'] as SplitArtistGenreConfigsWrapper;
    final tsf = params['filters'] as List<TrackSearchFilter>;
    final cleanup = params['cleanup'] as bool;
    final lyricsCacheDirectory = params['lyricsCacheDirectory'] as String;

    var stitle = tsf.contains(TrackSearchFilter.title);
    final sfilename = tsf.contains(TrackSearchFilter.filename);
    final sfolder = tsf.contains(TrackSearchFilter.folder);
    final salbum = tsf.contains(TrackSearchFilter.album);
    final salbumartist = tsf.contains(TrackSearchFilter.albumartist);
    final sartist = tsf.contains(TrackSearchFilter.artist);
    final sgenre = tsf.contains(TrackSearchFilter.genre);
    final scomposer = tsf.contains(TrackSearchFilter.composer);
    final scomment = tsf.contains(TrackSearchFilter.comment);
    final sdescription = tsf.contains(TrackSearchFilter.description);
    final syear = tsf.contains(TrackSearchFilter.year);
    final smoods = tsf.contains(TrackSearchFilter.moods);
    final stags = tsf.contains(TrackSearchFilter.tags);
    final slyrics = tsf.contains(TrackSearchFilter.lyrics);

    if (tsf.isEmpty) stitle = true;

    final textCleanedForSearch = _functionOfCleanup(cleanup);
    final textNonCleanedForSearch = cleanup ? _functionOfCleanup(false) : null;

    _Property? splitThis(String? property, bool split) {
      if (!split || property == null) return null;
      return _splitTextCleanedAndNonCleaned(
        property,
        textCleanedForSearch,
        textNonCleanedForSearch,
      );
    }

    final tracksExtended = <_CustomTrackExtended>[];
    for (final trMap in tracks) {
      final path = trMap['path'] as String;
      final title = trMap['title'] as String;
      final isVideo = trMap['v'] == true;
      final year = trMap['year'] as int?;
      final track = Track.decide(path, isVideo);

      tracksExtended.add(
        _CustomTrackExtended(
          track: track,
          splitTitle: splitThis(title, stitle),
          splitFilename: splitThis(path.getFilename, sfilename),
          splitFolder: splitThis(Track.explicit(path).folderName, sfolder),
          splitAlbum: salbum
              ? _mapListCleanedAndNonCleaned(
                  Indexer.splitAlbum(
                    trMap['album'],
                    config: splitConfig.albumConfig,
                  ),
                  textCleanedForSearch,
                  textNonCleanedForSearch,
                )
              : null,
          splitAlbumArtist: splitThis(trMap['albumArtist'], salbumartist),
          splitArtist: sartist
              ? _mapListCleanedAndNonCleaned(
                  Indexer.splitArtist(
                    title: title,
                    originalArtist: trMap['artist'],
                    config: splitConfig.artistsConfig,
                  ),
                  textCleanedForSearch,
                  textNonCleanedForSearch,
                )
              : null,
          splitGenre: sgenre
              ? _mapListCleanedAndNonCleaned(
                  Indexer.splitGenre(
                    trMap['genre'],
                    config: splitConfig.genresConfig,
                  ),
                  textCleanedForSearch,
                  textNonCleanedForSearch,
                )
              : null,
          splitComposer: splitThis(trMap['composer'], scomposer),
          splitComment: splitThis(trMap['comment'], scomment),
          description: !sdescription ? null : _PropertySimple.orNull(trMap['description'] as String?),
          splitMoods: smoods ? _Property.fromListNull(trMap['moods'] as List<String>?) : null,
          splitTags: stags ? _Property.fromListNull(trMap['tags'] as List<String>?) : null,
          year: !syear || year == null || year == 0
              ? null
              : _PropertySimple.orNull(
                  _mapListCleanedAndNonCleaned(
                    [year.toString()],
                    textCleanedForSearch,
                    textNonCleanedForSearch,
                  )?.joined,
                ),
          lyrics: !slyrics
              ? null
              : _fillAllAvailableLyrics(
                  track,
                  trMap['lyrics'] as String? ?? '',
                  lyricsCacheDirectory,
                ),
          listensCount: trMap['lc'] as int?,
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

  static _PropertySimple? _fillAllAvailableLyrics(Track track, String embedded, String lyricsCacheDirectory) {
    final lyricsBuffer = StringBuffer();

    final lrcUtils = LrcSearchUtilsSelectableIsolate(
      mainLyricsCacheDirectory: lyricsCacheDirectory,
      kDummyExtendedTrack,
      track,
    );

    String? lrcContent;
    final syncedInCache = lrcUtils.cachedLRCFile;
    if (syncedInCache.existsAndValidSync()) {
      lrcContent = syncedInCache.readLrcStringSync();
    } else if (embedded.isNotEmpty) {
      lrcContent = embedded;
    }
    if (lrcContent == null) {
      final lyricsFilesLocal = lrcUtils.deviceLRCFiles;
      for (final lfn in lyricsFilesLocal) {
        final lf = lfn();
        if (lf.existsAndValidSync()) {
          lrcContent = lf.readLrcStringSync();
          break;
        }
      }
    }
    if (lrcContent == null) {
      final textInCache = lrcUtils.cachedTxtFile;
      if (textInCache.existsAndValidSync()) {
        lrcContent = textInCache.readLrcStringSync();
      }
    }
    if (lrcContent != null) {
      final lrc = lrcContent.parseLRC();
      if (lrc != null && lrc.lyrics.isNotEmpty) {
        for (final line in lrc.lyrics) {
          lyricsBuffer.writeln(line.readableText);
        }
      } else {
        final split = LineSplitter().convert(lrcContent);
        for (final line in split) {
          lyricsBuffer.writeln(line);
        }
      }
    }
    return _PropertySimple._(
      joined: lyricsBuffer.toString(),
    );
  }

  static _Property? _splitTextCleanedAndNonCleaned(String text, String Function(String) textCleanedForSearch, String Function(String)? textNonCleanedForSearch) {
    final splitted = text.split(' ');
    return _mapListCleanedAndNonCleaned(splitted, textCleanedForSearch, textNonCleanedForSearch);
  }

  static _Property? _mapListCleanedAndNonCleaned(List<String> splitted, String Function(String) textCleanedForSearch, String Function(String)? textNonCleanedForSearch) {
    final allParts = <String>[];

    for (final item in splitted) {
      var cleaned = textCleanedForSearch(item);
      if (cleaned.isNotEmpty) {
        allParts.add(cleaned);
      }

      var nonCleaned = textNonCleanedForSearch?.call(item);
      if (nonCleaned != null) {
        if (nonCleaned.isNotEmpty) {
          if (!allParts.contains(nonCleaned)) {
            allParts.add(nonCleaned);
          }
        }
      }
    }

    return _Property.fromList(allParts);
  }

  List<Track> filter(String text) {
    final result = <Track>[];
    _filter(text, (trExt, _) => result.add(trExt.track));
    return result;
  }

  List<int> filterIndicesAsList(String text) {
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
    final lctextProperty = _splitTextCleanedAndNonCleaned(text, textCleanedForSearch, textNonCleanedForSearch);
    final lctextSplit = lctextProperty?.splits ?? [];

    int matchScore(_CustomTrackExtended trExt) {
      int score = 0;

      void scorePropertySimple(_PropertySimple? propertyString, {int multiplier = 1}) {
        if (propertyString == null) return;

        if (propertyString.joined.contains(lctext)) {
          score += 20 * multiplier;
        }
      }

      void scoreProperty(_Property? property, {int multiplier = 1}) {
        if (property == null) return;

        if (score >= 1000) return;

        final propertyJoined = property.joined;

        if (propertyJoined == lctext) {
          score += 300 * multiplier;
          return;
        }

        if (propertyJoined.contains(lctext) || (lctextNonCleaned != null && propertyJoined.contains(lctextNonCleaned))) {
          score += 100 * multiplier;
          return;
        }

        final allWordsMatch = lctextSplit.every((word) => propertyJoined.contains(word));
        if (allWordsMatch) {
          score += 50 * multiplier;
          return;
        }

        final allWordsMatchSplit = lctextSplit.every((word) => property.splits.any((p) => p.contains(word)));
        if (allWordsMatchSplit) {
          score += 20 * multiplier;
          return;
        }

        for (final word in lctextSplit) {
          if (propertyJoined.contains(word)) {
            score += 5 * multiplier;
          }
        }
      }

      scoreProperty(trExt.splitTitle, multiplier: 4);
      scoreProperty(trExt.splitFilename, multiplier: 3);
      scoreProperty(trExt.splitArtist, multiplier: 2);
      scoreProperty(trExt.splitAlbum, multiplier: 2);
      scoreProperty(trExt.splitFolder);
      scoreProperty(trExt.splitAlbumArtist);
      scoreProperty(trExt.splitGenre);
      scoreProperty(trExt.splitComposer);
      scoreProperty(trExt.splitComment);
      scorePropertySimple(trExt.description);
      scoreProperty(trExt.splitMoods);
      scoreProperty(trExt.splitTags);
      scorePropertySimple(trExt.year);
      scorePropertySimple(trExt.lyrics);

      return score;
    }

    final scored = <int, List<(_CustomTrackExtended, int)>>{};

    int index = 0;
    for (final trExt in _tracksExtended) {
      final score = matchScore(trExt);
      if (score > 0) {
        (scored[score] ??= []).add((trExt, index));
      }
      index++;
    }

    final sortedKeys = scored.keys.toFixedList()..sort((a, b) => b.compareTo(a));
    final sortForScoreAbove = sortedKeys.length < 5 ? 0 : 100;
    for (final key in sortedKeys) {
      final innerList = scored[key]!;
      if (innerList.length > 1 && key > sortForScoreAbove) innerList.sortByReverse((e) => e.$1.listensCount ?? 0);
      for (final (trExt, i) in innerList) {
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
  final _Property? splitTitle;
  final _Property? splitFilename;
  final _Property? splitFolder;
  final _Property? splitAlbum;
  final _Property? splitAlbumArtist;
  final _Property? splitArtist;
  final _Property? splitGenre;
  final _Property? splitComposer;
  final _Property? splitComment;
  final _PropertySimple? description;
  final _Property? splitMoods;
  final _Property? splitTags;
  final _PropertySimple? year;
  final _PropertySimple? lyrics;
  final int? listensCount;

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
    required this.description,
    required this.splitMoods,
    required this.splitTags,
    required this.year,
    required this.lyrics,
    required this.listensCount,
  });
}

class _Property {
  final List<String> splits;
  final String joined;

  const _Property._({
    required this.splits,
    required this.joined,
  });

  static _Property? fromListNull(List<String>? list) {
    if (list == null) return null;
    return _Property.fromList(list);
  }

  static _Property? fromList(List<String> list) {
    if (list.isEmpty) return null;
    return _Property._(splits: list, joined: list.join(' '));
  }
}

class _PropertySimple {
  final String joined;

  const _PropertySimple._({
    required this.joined,
  });

  static _PropertySimple? orNull(String? joined) {
    if (joined == null) return null;
    return _PropertySimple._(joined: joined);
  }
}
