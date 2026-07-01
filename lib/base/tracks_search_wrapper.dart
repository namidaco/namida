import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data' show Uint32List;

import 'package:history_manager/history_manager.dart';
import 'package:lrc/lrc.dart';
import 'package:nampack/extensions/extensions.dart';

import 'package:namida/class/split_config.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/lyrics_search_utils/lrc_search_utils_selectable.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';

class TracksSearchWrapper {
  static final _matcher = _StringMatcher();

  final bool cleanup;
  final List<_CustomTrackExtended> _tracksExtended;
  final String Function(String) textCleanedForSearch;
  final String Function(String)? textCleanedMinorForSearch;
  final int maxListensCount;

  const TracksSearchWrapper._(
    this.cleanup,
    this._tracksExtended,
    this.textCleanedForSearch,
    this.textCleanedMinorForSearch,
    this.maxListensCount,
  );

  static Map<String, dynamic> generateParams(SendPort sendPort, Iterable<TrackExtended> tracks, ListensSortedMap<Track> topTracksMapListens) {
    final filters = settings.trackSearchFilter.value;
    final addDescription = filters.contains(TrackSearchFilter.description);
    final addLyrics = filters.contains(TrackSearchFilter.lyrics);
    final addMoods = filters.contains(TrackSearchFilter.moods);
    final addTags = filters.contains(TrackSearchFilter.tags);
    final maxListensCount = topTracksMapListens.values.firstOrNull?.length;
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
      'maxListensCount': maxListensCount,
      'sendPort': sendPort,
    };
  }

  factory TracksSearchWrapper.init(Map params) {
    final tracks = params['tracks'] as List<Map>;
    final splitConfig = params['splitConfig'] as SplitArtistGenreConfigsWrapper;
    final tsf = params['filters'] as List<TrackSearchFilter>;
    final cleanup = params['cleanup'] as bool;
    final lyricsCacheDirectory = params['lyricsCacheDirectory'] as String;
    final maxListensCount = params['maxListensCount'] as int? ?? 0;

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

    _Property? splitThis(String? property, bool split, {bool tryCutBeforeBrackets = false}) {
      if (!split || property == null) return null;
      return _splitTextCleanedAndCleanedMinor(
        property,
        textCleanedForSearch,
        textCleanedMinorForSearch,
        tryCutBeforeBrackets: tryCutBeforeBrackets,
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
          splitTitle: splitThis(title, stitle, tryCutBeforeBrackets: true),
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
      maxListensCount,
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

  static _Property _splitTextCleanedAndCleanedMinor(
    String text,
    String Function(String) textCleanedForSearch,
    String Function(String)? textCleanedMinorForSearch, {
    bool tryCutBeforeBrackets = false,
  }) {
    return _mapListCleanedAndCleanedMinor(
      text.split(' '),
      textCleanedForSearch,
      textCleanedMinorForSearch,
      text: text,
      tryCutBeforeBrackets: tryCutBeforeBrackets,
    );
  }

  static _Property? _mapListCleanedAndCleanedMinorOrNull(
    List<String>? splitted,
    String Function(String) textCleanedForSearch,
    String Function(String)? textCleanedMinorForSearch,
  ) {
    if (splitted == null) return null;
    return _mapListCleanedAndCleanedMinor(
      splitted,
      textCleanedForSearch,
      textCleanedMinorForSearch,
      text: null,
    );
  }

  static _Property _mapListCleanedAndCleanedMinor(
    List<String> splitted,
    String Function(String) textCleanedForSearch,
    String Function(String)? textCleanedMinorForSearch, {
    String? text,
    bool tryCutBeforeBrackets = false,
  }) {
    final cleanedParts = <String>[];
    final cleanedMinorParts = <String>[];

    int? cleanedCutAtIndex;
    int? cleanedMinorCutAtIndex;

    int index = 0;
    for (final item in splitted) {
      var cleaned = textCleanedForSearch(item);
      if (cleaned.isNotEmpty) {
        cleanedParts.add(cleaned);
      }

      var cleanedMinor = textCleanedMinorForSearch?.call(item);
      if (cleanedMinor != null) {
        if (cleanedMinor.isNotEmpty) {
          cleanedMinorParts.add(cleanedMinor);
        }
      }

      if (tryCutBeforeBrackets && cleanedCutAtIndex == null /* && cleanedMinorCutAtIndex == null */ ) {
        // ignore first (0-1) chars
        if (index > 1) {
          if (item.startsWith('(') || item.startsWith('[')) {
            cleanedCutAtIndex = index;
            cleanedMinorCutAtIndex = index;
          }
        }
      }

      index++;
    }

    String joinedCleaned;
    String joinedCleanedMinor;
    if (text != null) {
      joinedCleaned = textCleanedForSearch(text);
      joinedCleanedMinor = textCleanedMinorForSearch?.call(text) ?? '';
    } else {
      joinedCleaned = cleanedParts.join(' ');
      joinedCleanedMinor = cleanedMinorParts.join(' ');
    }

    String? joinedCutCleaned;
    String? joinedCutCleanedMinor;
    if (cleanedCutAtIndex != null) {
      joinedCutCleaned = cleanedParts.take(cleanedCutAtIndex).join(' ');
    }
    if (cleanedMinorCutAtIndex != null) {
      joinedCutCleanedMinor = cleanedMinorParts.take(cleanedMinorCutAtIndex).join(' ');
    }

    return _Property._(
      splitsCleaned: cleanedParts,
      splitsCleanedMinor: cleanedMinorParts,
      joinedCleaned: joinedCleaned,
      joinedCleanedMinor: joinedCleanedMinor,
      joinedCutCleaned: joinedCutCleaned,
      joinedCutCleanedMinor: joinedCutCleanedMinor,
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
    text = text.trimAll();
    final lctextCleaned = textCleanedForSearch(text);
    final lctextCleanedMinor = textCleanedMinorForSearch == null ? null : textCleanedMinorForSearch!(text);
    final lctextProperty = _splitTextCleanedAndCleanedMinor(text, textCleanedForSearch, textCleanedMinorForSearch);
    final lctextSplitCleaned = lctextProperty.splitsCleaned;
    final lctextSplitCleanedMinor = lctextProperty.splitsCleanedMinor;

    final calculator = _ScoreCalculator(
      matcher: _matcher,
      lctextCleaned: lctextCleaned,
      lctextCleanedMinor: lctextCleanedMinor,
      lctextSplitCleaned: lctextSplitCleaned,
      lctextSplitCleanedMinor: lctextSplitCleanedMinor,
    );

    final scored = <int, List<(_CustomTrackExtended, int)>>{};

    int index = 0;
    for (final trExt in _tracksExtended) {
      int score = calculator.calculate(trExt);
      if (maxListensCount > 0) {
        final listensPercentage = (trExt.listensCount ?? 0) / maxListensCount;
        final listensScore = (listensPercentage.roundDecimals(1) * 100).round();
        score += listensScore;
      }
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
  final List<String> splitsCleaned;
  final List<String>? splitsCleanedMinor;
  final String joinedCleaned;
  final String? joinedCleanedMinor;
  final String? joinedCutCleaned;
  final String? joinedCutCleanedMinor;

  const _Property._({
    required this.splitsCleaned,
    required this.splitsCleanedMinor,
    required this.joinedCleaned,
    required this.joinedCleanedMinor,
    required this.joinedCutCleaned,
    required this.joinedCutCleanedMinor,
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

class _ScoreCalculator {
  final _StringMatcher matcher;
  final String lctextCleaned;
  final String? lctextCleanedMinor;
  final List<String> lctextSplitCleaned;
  final List<String>? lctextSplitCleanedMinor;

  const _ScoreCalculator({
    required this.matcher,
    required this.lctextCleaned,
    required this.lctextCleanedMinor,
    required this.lctextSplitCleaned,
    required this.lctextSplitCleanedMinor,
  });

  static const int maxScore = 1200;
  static int score = 0;

  void scorePropertySimple(_PropertySimple? propertyString, {int multiplier = 1}) {
    if (propertyString == null) return;

    if (propertyString.joined.contains(lctextCleaned)) {
      score += 20 * multiplier;
    }
  }

  void scoreProperty(_Property? property, {int multiplier = 1, bool allowFuzzy = false}) {
    if (property == null) return;

    if (property.joinedCleaned.isEmpty) return;
    if (lctextCleaned.isEmpty) return;

    // -- exact match
    // -- ex: `"still here"` == `"still here"`
    final propertyJoinedCleaned = property.joinedCleaned;
    final propertyJoinedCleanedMinor = property.joinedCleanedMinor;
    if (propertyJoinedCleaned == lctextCleaned) {
      score += 400 * multiplier;
      return;
    } else if (propertyJoinedCleanedMinor != null && propertyJoinedCleanedMinor == lctextCleanedMinor) {
      score += 400 * multiplier;
      return;
    }

    // -- same as exact match, but without the brackets possibly in title
    // -- ex: `"still here"` == `"still here"(feat. amy)`
    // -- worth noting that _simpleRatioForSplits picks the best match ratio not combined average,
    // -- so this might not be always useful, but it shines when exact matches score better than
    // -- the ones with brackets, putting it further down instead of first.
    // -- (ex: "without" makes their score similar, but "without me" gives 'false?' advantage)
    final propertyJoinedCutCleaned = property.joinedCutCleaned;
    final propertyJoinedCutCleanedMinor = property.joinedCutCleanedMinor;
    if (propertyJoinedCutCleaned != null && propertyJoinedCutCleaned == lctextCleaned) {
      score += 400 * multiplier;
      return;
    } else if (propertyJoinedCutCleanedMinor != null && propertyJoinedCutCleanedMinor == lctextCleanedMinor) {
      score += 400 * multiplier;
      return;
    }

    final propertySplitsCleaned = property.splitsCleaned;
    final matchingPercentageCleaned = matcher.compareMatchingPercentage(
      lctextCleaned,
      lctextSplitCleaned,
      propertyJoinedCleaned,
      propertySplitsCleaned,
      allowFuzzy: allowFuzzy,
    );
    score += (matchingPercentageCleaned * 200).round() * multiplier;

    if (score > 0) return;

    final propertySplitsCleanedMinor = property.splitsCleanedMinor;
    if (lctextCleanedMinor != null && lctextSplitCleanedMinor != null && propertyJoinedCleanedMinor != null && propertySplitsCleanedMinor != null) {
      final matchingPercentageCleanedMinor = matcher.compareMatchingPercentage(
        lctextCleanedMinor!,
        lctextSplitCleanedMinor!,
        propertyJoinedCleanedMinor,
        propertySplitsCleanedMinor,
        allowFuzzy: allowFuzzy,
      );
      score += (matchingPercentageCleanedMinor * 300).round() * multiplier;
    }
  }

  bool scorePropertySimpleAndIsEnough(_PropertySimple? property, {int multiplier = 1}) {
    scorePropertySimple(property, multiplier: multiplier);
    return score >= maxScore;
  }

  bool scorePropertyAndIsEnough(_Property? property, {int multiplier = 1, bool allowFuzzy = false}) {
    scoreProperty(property, multiplier: multiplier, allowFuzzy: allowFuzzy);
    return score >= maxScore;
  }

  int calculate(_CustomTrackExtended trExt) {
    score = 0;

    if (scorePropertyAndIsEnough(trExt.splitTitle, multiplier: 6, allowFuzzy: true)) return score;
    if (scorePropertyAndIsEnough(trExt.splitArtist, multiplier: 2, allowFuzzy: true)) return score;
    if (scorePropertyAndIsEnough(trExt.splitAlbum, multiplier: 2, allowFuzzy: true)) return score;
    if (scorePropertyAndIsEnough(trExt.splitFilename, multiplier: 1, allowFuzzy: true)) return score;
    // -- prevent scoring more if already found in main properties
    // -- for example very useful to prevent lyrics in description from producing more score
    if (score > 0) return score;
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
}

class _StringMatcher {
  const _StringMatcher();

  /// Does NOT check if [query] == [property]. this must be done manually before calling this function.
  double compareMatchingPercentage(
    String query,
    List<String> querySplits,
    String property,
    List<String> propertySplits, {
    int roundDecimals = 1,
    bool allowFuzzy = false,
  }) {
    double finalRatio = _simpleRatio(
      query,
      property,
      queryMultiplier: 0.7,
    );

    if (finalRatio < 0.7) {
      final ratioForSplits = _simpleRatioForSplits(
        querySplits,
        propertySplits,
        queryMultiplier: 0.4,
        queryMorePartsMultiplier: 0.5,
      );
      if (ratioForSplits > finalRatio) finalRatio = ratioForSplits;
    }

    if (allowFuzzy && finalRatio < _kMaxLevenshtienRatio) {
      final levenshteinRatio = _levenshteinRatio(query, property) * _kMaxLevenshtienRatio;
      if (levenshteinRatio > finalRatio) finalRatio = levenshteinRatio;
    }

    if (roundDecimals > 0) {
      finalRatio = finalRatio.roundDecimals(roundDecimals);
    }

    return finalRatio;
  }

  double _simpleRatioForSplits(
    List<String> querySplits,
    List<String> propertySplits, {
    double queryMultiplier = 0.4,
    double queryMorePartsMultiplier = 0.5,
  }) {
    final querySplitsLength = querySplits.length;
    final propertySplitsLength = propertySplits.length;
    double combinedRatio = 0.0;
    for (final qPart in querySplits) {
      // -- max ratio has great advantage over combining all ratios
      // -- yes it will no longer favour shorter matches, but would
      // -- allow better sorting using other factors (ex: listens count)
      double maxRatioForQPart = 0.0;
      for (final pPart in propertySplits) {
        final qpRatio = _simpleRatio(qPart, pPart, queryMultiplier: queryMultiplier);
        if (qpRatio > maxRatioForQPart) maxRatioForQPart = qpRatio;
        if (maxRatioForQPart >= 1.0) break;
      }
      combinedRatio += maxRatioForQPart;
    }
    // -- ex: query="where go", property: "go"
    // -- so decrease score to allow tracks with "where do we go" to appear
    if (querySplitsLength > propertySplitsLength) combinedRatio *= queryMorePartsMultiplier;

    final combinedRatioAverage = combinedRatio / querySplitsLength;
    return combinedRatioAverage;
  }

  double _simpleRatio(
    String query,
    String property, {
    double queryMultiplier = 1.0,
    double propertyMultiplier = 1.0,
  }) {
    if (property.length < query.length) {
      final matchIndex = query.indexOf(property);
      if (matchIndex >= 0) {
        final offsetMultiplier = 1 - (matchIndex / query.length);
        return (property.length / query.length) * offsetMultiplier * queryMultiplier;
      }
    } else {
      final matchIndex = property.indexOf(query);
      if (matchIndex >= 0) {
        final offsetMultiplier = 1 - (matchIndex / property.length);
        return (query.length / property.length) * offsetMultiplier * propertyMultiplier;
      }
    }
    return 0.0;
  }

  double _levenshteinRatio(String a, String b) {
    final maxLen = a.length > b.length ? a.length : b.length;
    if (maxLen == 0) return _kEmptyStringsCompareRatio;
    final distance = _levenshteinDistance(a, b);
    return 1 - distance / maxLen;
  }

  // by claude.ai
  int _levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final units1 = s1.codeUnits;
    final units2 = s2.codeUnits;
    final len2 = units2.length;

    var prevRow = Uint32List(len2 + 1);
    for (var k = 0; k <= len2; k++) {
      prevRow[k] = k;
    }
    var currRow = Uint32List(len2 + 1);

    for (var i = 0; i < units1.length; i++) {
      currRow[0] = i + 1;
      final u1 = units1[i];
      for (var j = 0; j < len2; j++) {
        final cost = u1 == units2[j] ? 0 : 1 + _kSubstitutionExtraCost;
        final deletion = prevRow[j + 1] + 1;
        final insertion = currRow[j] + 1;
        final substitution = prevRow[j] + cost;

        var best = deletion;
        if (insertion < best) best = insertion;
        if (substitution < best) best = substitution;
        currRow[j + 1] = best;
      }

      final temp = prevRow;
      prevRow = currRow;
      currRow = temp;
    }

    return prevRow[len2];
  }

  static const int _kSubstitutionExtraCost = 4;
  static const double _kEmptyStringsCompareRatio = 0.0;
  static const double _kMaxLevenshtienRatio = 0.2;
}
