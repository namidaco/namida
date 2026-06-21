import 'dart:convert';
import 'dart:isolate';

import 'package:history_manager/history_manager.dart';
import 'package:lrc/lrc.dart';

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
  final String Function(String)? textCleanedMinorForSearch;

  const TracksSearchWrapper._(
    this.cleanup,
    this._tracksExtended,
    this.textCleanedForSearch,
    this.textCleanedMinorForSearch,
  );

  static Map<String, dynamic> generateParams(SendPort sendPort, Iterable<TrackExtended> tracks, ListensSortedMap<Track> topTracksMapListens) {
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
              'lc': topTracksMapListens[e.asTrack()]?.length,
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
    final textCleanedMinorForSearch = cleanup ? _functionOfCleanup(false) : null;

    _Property? splitThis(String? property, bool split) {
      if (!split || property == null) return null;
      return _splitTextCleanedAndCleanedMinor(
        property,
        textCleanedForSearch,
        textCleanedMinorForSearch,
      );
    }

    final tracksExtended = <_CustomTrackExtended>[];
    for (final trMap in tracks) {
      final path = trMap['path'] as String;
      final title = trMap['title'] as String;
      final isVideo = trMap['v'] == true;
      final year = trMap['year'] as int?;
      final track = Track.decide(path, isVideo);

      final listensCount = trMap['lc'] as int?;

      tracksExtended.add(
        _CustomTrackExtended(
          track: track,
          splitTitle: splitThis(title, stitle),
          splitFilename: splitThis(path.getFilename, sfilename),
          splitFolder: splitThis(Track.explicit(path).folderName, sfolder),
          splitAlbum: salbum
              ? _mapListCleanedAndCleanedMinor(
                  Indexer.splitAlbum(
                    trMap['album'],
                    config: splitConfig.albumConfig,
                  ),
                  textCleanedForSearch,
                  textCleanedMinorForSearch,
                )
              : null,
          splitAlbumArtist: splitThis(trMap['albumArtist'], salbumartist),
          splitArtist: sartist
              ? _mapListCleanedAndCleanedMinor(
                  Indexer.splitArtist(
                    title: title,
                    originalArtist: trMap['artist'],
                    config: splitConfig.artistsConfig,
                  ),
                  textCleanedForSearch,
                  textCleanedMinorForSearch,
                )
              : null,
          splitGenre: sgenre
              ? _mapListCleanedAndCleanedMinor(
                  Indexer.splitGenre(
                    trMap['genre'],
                    config: splitConfig.genresConfig,
                  ),
                  textCleanedForSearch,
                  textCleanedMinorForSearch,
                )
              : null,
          splitComposer: splitThis(trMap['composer'], scomposer),
          splitComment: splitThis(trMap['comment'], scomment),
          description: !sdescription ? null : _PropertySimple.orNull(trMap['description'] as String?),
          splitMoods: smoods
              ? _mapListCleanedAndCleanedMinorOrNull(
                  trMap['moods'] as List<String>?,
                  textCleanedForSearch,
                  textCleanedMinorForSearch,
                )
              : null,
          splitTags: stags
              ? _mapListCleanedAndCleanedMinorOrNull(
                  trMap['tags'] as List<String>?,
                  textCleanedForSearch,
                  textCleanedMinorForSearch,
                )
              : null,
          year: !syear || year == null || year == 0
              ? null
              : _PropertySimple.orNull(
                  _splitTextCleanedAndCleanedMinor(
                    year.toString(),
                    textCleanedForSearch,
                    textCleanedMinorForSearch,
                  ).joinedCleaned,
                ),
          lyrics: !slyrics
              ? null
              : _fillAllAvailableLyrics(
                  track,
                  trMap['lyrics'] as String? ?? '',
                  lyricsCacheDirectory,
                ),
          listensCount: listensCount,
        ),
      );
    }
    return TracksSearchWrapper._(
      cleanup,
      tracksExtended,
      textCleanedForSearch,
      textCleanedMinorForSearch,
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

  static _Property _splitTextCleanedAndCleanedMinor(String text, String Function(String) textCleanedForSearch, String Function(String)? textCleanedMinorForSearch) {
    final allParts = <String>[];
    for (final item in text.split(' ')) {
      var cleaned = textCleanedForSearch(item);
      if (cleaned.isNotEmpty) {
        allParts.add(cleaned);
      }
      var cleanedMinor = textCleanedMinorForSearch?.call(item);
      if (cleanedMinor != null) {
        if (cleanedMinor.isNotEmpty) {
          if (!allParts.contains(cleanedMinor)) {
            allParts.add(cleanedMinor);
          }
        }
      }
    }
    return _Property._(
      splits: allParts,
      joinedCleaned: textCleanedForSearch(text),
      joinedCleanedMinor: textCleanedMinorForSearch?.call(text),
    );
  }

  static _Property? _mapListCleanedAndCleanedMinorOrNull(List<String>? splitted, String Function(String) textCleanedForSearch, String Function(String)? textCleanedMinorForSearch) {
    if (splitted == null) return null;
    return _mapListCleanedAndCleanedMinor(splitted, textCleanedForSearch, textCleanedMinorForSearch);
  }

  static _Property _mapListCleanedAndCleanedMinor(List<String> splitted, String Function(String) textCleanedForSearch, String Function(String)? textCleanedMinorForSearch) {
    final allParts = <String>[];
    final cleanedParts = <String>[];
    final cleanedMinorParts = <String>[];

    for (final item in splitted) {
      var cleaned = textCleanedForSearch(item);
      if (cleaned.isNotEmpty) {
        cleanedParts.add(cleaned);
        allParts.add(cleaned);
      }

      var cleanedMinor = textCleanedMinorForSearch?.call(item);
      if (cleanedMinor != null) {
        if (cleanedMinor.isNotEmpty) {
          cleanedMinorParts.add(cleanedMinor);
          if (!allParts.contains(cleanedMinor)) {
            allParts.add(cleanedMinor);
          }
        }
      }
    }

    final joinedCleaned = cleanedParts.join(' ');
    final joinedCleanedMinor = cleanedMinorParts.join(' ');

    return _Property._(
      splits: allParts,
      joinedCleaned: joinedCleaned,
      joinedCleanedMinor: joinedCleanedMinor,
    );
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
    final lctextCleaned = textCleanedForSearch(text);
    final lctextCleanedMinor = textCleanedMinorForSearch == null ? null : textCleanedMinorForSearch!(text);
    final lctextProperty = _splitTextCleanedAndCleanedMinor(text, textCleanedForSearch, textCleanedMinorForSearch);
    final lctextSplit = lctextProperty.splits;

    bool containsWordSequence(List<String> fieldTokens, List<String> queryTokens) {
      if (queryTokens.isEmpty || queryTokens.length > fieldTokens.length) return false;
      for (var i = 0; i <= fieldTokens.length - queryTokens.length; i++) {
        var match = true;
        for (var j = 0; j < queryTokens.length; j++) {
          if (fieldTokens[i + j] != queryTokens[j]) {
            match = false;
            break;
          }
        }
        if (match) return true;
      }
      return false;
    }

    const maxScore = 1200;

    int matchScore(_CustomTrackExtended trExt) {
      int score = 0;

      void scorePropertySimple(_PropertySimple? propertyString, {int multiplier = 1}) {
        if (propertyString == null) return;

        if (propertyString.joined.contains(lctextCleaned)) {
          score += 20 * multiplier;
        }
      }

      void scoreProperty(_Property? property, {int multiplier = 1}) {
        if (property == null) return;

        if (property.joinedCleaned.isEmpty) return;

        final propertyJoinedCleaned = property.joinedCleaned;
        final propertyJoinedCleanedMinor = property.joinedCleanedMinor;

        if (lctextCleaned.isNotEmpty) {
          if (propertyJoinedCleaned == lctextCleaned) {
            score += 400 * multiplier;
            return;
          } else if (propertyJoinedCleanedMinor != null && propertyJoinedCleanedMinor == lctextCleanedMinor) {
            score += 400 * multiplier;
            return;
          }
        }

        if (containsWordSequence(property.splits, lctextSplit)) {
          final coverage = lctextSplit.length / property.splits.length;
          score += (100 + 50 * coverage).round() * multiplier;
          return;
        }

        int exactWordHits = 0;
        int substringHits = 0;
        for (final word in lctextSplit) {
          if (property.splits.contains(word)) {
            exactWordHits++;
          } else if (propertyJoinedCleaned.contains(word) || propertyJoinedCleanedMinor?.contains(word) == true) {
            substringHits++;
          }
        }

        final splitsCount = property.splits.length;
        if (splitsCount > 0) {
          final exactRatio = exactWordHits / splitsCount;
          final substringRatio = substringHits / splitsCount;
          final partial = (100 * exactRatio + 10 * substringRatio).round();
          score += partial * multiplier;
        }
      }

      bool scorePropertySimpleAndIsEnough(_PropertySimple? property, {int multiplier = 1}) {
        scorePropertySimple(property, multiplier: multiplier);
        return score >= maxScore;
      }

      bool scorePropertyAndIsEnough(_Property? property, {int multiplier = 1}) {
        scoreProperty(property, multiplier: multiplier);
        return score >= maxScore;
      }

      if (scorePropertyAndIsEnough(trExt.splitTitle, multiplier: 4)) return score;
      if (scorePropertyAndIsEnough(trExt.splitArtist, multiplier: 2)) return score;
      if (scorePropertyAndIsEnough(trExt.splitAlbum, multiplier: 2)) return score;
      if (scorePropertyAndIsEnough(trExt.splitFilename, multiplier: 1)) return score;
      if (scorePropertyAndIsEnough(trExt.splitFolder)) return score;
      if (scorePropertyAndIsEnough(trExt.splitAlbumArtist)) return score;
      if (scorePropertyAndIsEnough(trExt.splitGenre)) return score;
      if (scorePropertyAndIsEnough(trExt.splitComposer)) return score;
      if (scorePropertyAndIsEnough(trExt.splitComment)) return score;
      if (scorePropertySimpleAndIsEnough(trExt.description)) return score;
      if (scorePropertyAndIsEnough(trExt.splitMoods)) return score;
      if (scorePropertyAndIsEnough(trExt.splitTags)) return score;
      if (scorePropertySimpleAndIsEnough(trExt.year)) return score;
      if (scorePropertySimpleAndIsEnough(trExt.lyrics)) return score;

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
    for (final scoreKey in sortedKeys) {
      final innerList = scored[scoreKey]!;
      if (innerList.length > 1 && scoreKey > sortForScoreAbove) innerList.sortByReverse((e) => e.$1.listensCount ?? 0);
      for (final e in innerList) {
        onMatch(e.$1, e.$2);
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
  final String joinedCleaned;
  final String? joinedCleanedMinor;

  const _Property._({
    required this.splits,
    required this.joinedCleaned,
    required this.joinedCleanedMinor,
  });
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
