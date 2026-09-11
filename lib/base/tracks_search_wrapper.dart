import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data' show Uint32List;

import 'package:history_manager/history_manager.dart';
import 'package:lrc/lrc.dart';
import 'package:nampack/extensions/extensions.dart';

import 'package:namida/class/fuzzy_matcher.dart';
import 'package:namida/class/split_config.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/lyrics_search_utils/lrc_search_utils_selectable.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';

// deep performance optimizations by claude, wrote some scary masking and bits shifting thingys
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
              'style': e.originalStyle,
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
    final sstyle = tsf.contains(TrackSearchFilter.style);
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
    int index = -1;
    for (final trMap in tracks) {
      index++;
      final path = trMap['path'] as String;
      final title = trMap['title'] as String;
      final isVideo = trMap['v'] == true;
      final year = trMap['year'] as int?;
      final track = Track.decide(path, isVideo);

      final listensCount = trMap['lc'] as int?;
      final listensScore = maxListensCount > 0 ? (((listensCount ?? 0) / maxListensCount).roundDecimals(1) * 100).round() : 0;

      tracksExtended.add(
        _CustomTrackExtended(
          ogIndex: index,
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
          splitStyle: sstyle
              ? _mapListCleanedAndCleanedMinor(
                  Indexer.splitStyle(
                    trMap['style'],
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
                  ).cleaned.text,
                ),
          lyrics: !slyrics
              ? null
              : _fillAllAvailableLyrics(
                  track,
                  trMap['lyrics'] as String? ?? '',
                  lyricsCacheDirectory,
                ),
          listensCount: listensCount,
          listensScore: listensScore,
        ),
      );
    }

    // -- sort here once instead of sorting each inner list after matching
    tracksExtended.sortByReverse((e) => e.listensCount ?? 0);

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
      final deviceLrcFile = lrcUtils.firstDeviceLRCFileSync();
      lrcContent = deviceLrcFile?.readLrcStringSync();
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
    return _PropertySimple.orNull(lyricsBuffer.toString());
  }

  static _Property _splitTextCleanedAndCleanedMinor(
    String text,
    String Function(String) textCleanedForSearch,
    String Function(String)? textCleanedMinorForSearch, {
    bool tryCutBeforeBrackets = false,
  }) {
    final joinedCleaned = textCleanedForSearch(text);
    final joinedCleanedMinor = textCleanedMinorForSearch?.call(text);

    final cleaned = _MatchText.splitJoined(joinedCleaned);
    final cleanedMinor = joinedCleanedMinor == null
        ? null
        : joinedCleanedMinor == joinedCleaned
        ? cleaned // -- cleanup changed nothing, share the same instance
        : _MatchText.splitJoined(joinedCleanedMinor);

    String? joinedCutCleaned;
    String? joinedCutCleanedMinor;
    if (tryCutBeforeBrackets) {
      final cutAtIndex = _indexOfFirstBracketPart(text);
      if (cutAtIndex != null) {
        joinedCutCleaned = cleaned.parts.take(cutAtIndex).join(' ');
        joinedCutCleanedMinor = cleanedMinor?.parts.take(cutAtIndex).join(' ');
      }
    }

    return _Property._(
      cleaned: cleaned,
      cleanedMinor: cleanedMinor,
      joinedCutCleaned: joinedCutCleaned,
      joinedCutCleanedMinor: joinedCutCleanedMinor,
    );
  }

  /// index of the first part starting with a bracket, ignoring the first (0-1) chars.
  static int? _indexOfFirstBracketPart(String text) {
    int index = 0;
    int charOffset = 0;
    for (final item in text.split(' ')) {
      if (charOffset > 1 && (item.startsWith('(') || item.startsWith('['))) return index;
      index++;
      charOffset += item.length;
    }
    return null;
  }

  static _Property? _mapListCleanedAndCleanedMinorOrNull(
    List<String>? splitted,
    String Function(String) textCleanedForSearch,
    String Function(String)? textCleanedMinorForSearch,
  ) {
    if (splitted == null) return null;
    return _mapListCleanedAndCleanedMinor(splitted, textCleanedForSearch, textCleanedMinorForSearch);
  }

  static _Property _mapListCleanedAndCleanedMinor(
    List<String> splitted,
    String Function(String) textCleanedForSearch,
    String Function(String)? textCleanedMinorForSearch,
  ) {
    final cleanedParts = <String>[];
    final cleanedMinorParts = textCleanedMinorForSearch == null ? null : <String>[];
    bool identicalToMinor = true;

    for (final item in splitted) {
      final cleaned = textCleanedForSearch(item);
      if (cleaned.isNotEmpty) cleanedParts.add(cleaned);

      if (cleanedMinorParts != null) {
        final cleanedMinor = textCleanedMinorForSearch!(item);
        if (cleanedMinor.isNotEmpty) cleanedMinorParts.add(cleanedMinor);
        if (identicalToMinor && cleanedMinor != cleaned) identicalToMinor = false;
      }
    }

    final cleaned = _MatchText(cleanedParts.join(' '), cleanedParts);
    final cleanedMinor = cleanedMinorParts == null
        ? null
        : identicalToMinor
        ? cleaned
        : _MatchText(cleanedMinorParts.join(' '), cleanedMinorParts);

    return _Property._(
      cleaned: cleaned,
      cleanedMinor: cleanedMinor,
      joinedCutCleaned: null,
      joinedCutCleanedMinor: null,
    );
  }

  List<Track> filter(String text) {
    final result = <Track>[];
    _filter(text, (trExt) => result.add(trExt.track));
    return result;
  }

  List<int> filterIndicesAsList(String text) {
    final result = <int>[];
    _filter(text, (trExt) => result.add(trExt.ogIndex));
    return result;
  }

  Set<int> filterIndicesAsSet(String text) {
    final result = <int>{};
    _filter(text, (trExt) => result.add(trExt.ogIndex));
    return result;
  }

  void _filter(String text, void Function(_CustomTrackExtended trExt) onMatch) {
    final queryProperty = _splitTextCleanedAndCleanedMinor(text.trimAll(), textCleanedForSearch, textCleanedMinorForSearch);

    final calculator = _ScoreCalculator(
      matcher: const _StringMatcher(),
      query: queryProperty.cleaned,
      queryMinor: queryProperty.cleanedMinor,
    );

    final scored = <int, List<_CustomTrackExtended>>{};

    for (final trExt in _tracksExtended) {
      final score = calculator.calculate(trExt);
      // -- score must be > 0, otherwise would always show results with high listen counts
      if (score > 0) {
        (scored[score + trExt.listensScore] ??= []).add(trExt);
      }
    }

    final sortedKeys = scored.keys.toFixedList()..sort((a, b) => b.compareTo(a));
    for (final scoreKey in sortedKeys) {
      final innerList = scored[scoreKey]!;
      for (final e in innerList) {
        onMatch(e);
      }
    }
  }

  static String Function(String text) _functionOfCleanup(bool enableSearchCleanup) {
    return (String textToClean) => enableSearchCleanup ? textToClean.cleanUpForComparison : textToClean.toLowerCase();
  }
}

class _CustomTrackExtended {
  final int ogIndex;
  final Track track;
  final _Property? splitTitle;
  final _Property? splitFilename;
  final _Property? splitFolder;
  final _Property? splitAlbum;
  final _Property? splitAlbumArtist;
  final _Property? splitArtist;
  final _Property? splitGenre;
  final _Property? splitStyle;
  final _Property? splitComposer;
  final _Property? splitComment;
  final _PropertySimple? description;
  final _Property? splitMoods;
  final _Property? splitTags;
  final _PropertySimple? year;
  final _PropertySimple? lyrics;
  final int? listensCount;
  final int listensScore;

  const _CustomTrackExtended({
    required this.ogIndex,
    required this.track,
    required this.splitTitle,
    required this.splitFilename,
    required this.splitFolder,
    required this.splitAlbum,
    required this.splitAlbumArtist,
    required this.splitArtist,
    required this.splitGenre,
    required this.splitStyle,
    required this.splitComposer,
    required this.splitComment,
    required this.description,
    required this.splitMoods,
    required this.splitTags,
    required this.year,
    required this.lyrics,
    required this.listensCount,
    required this.listensScore,
  });
}

/// A text alongside everything needed to match against it, precomputed once.
///
/// [mask] & [partsMasks] are character-presence bitsets, they allow rejecting
/// impossible substring matches without touching the strings themselves.
///
/// by claude
class _MatchText {
  final String text;
  final int length;
  final int mask;
  final List<String> parts;
  final Uint32List partsLengths;
  final Uint32List partsMasks;

  _MatchText(this.text, this.parts) : length = text.length, mask = charsMaskOf(text), partsLengths = Uint32List(parts.length), partsMasks = Uint32List(parts.length) {
    for (int i = 0; i < parts.length; i++) {
      final part = parts[i];
      partsLengths[i] = part.length;
      partsMasks[i] = charsMaskOf(part);
    }
  }

  factory _MatchText.splitJoined(String joined) {
    final parts = <String>[];
    for (final part in joined.split(' ')) {
      if (part.isNotEmpty) parts.add(part);
    }
    return _MatchText(joined, parts);
  }

  static int charsMaskOf(String text) {
    int mask = 0;
    for (int i = 0; i < text.length; i++) {
      mask |= 1 << (text.codeUnitAt(i) & 31);
    }
    return mask;
  }
}

class _Property {
  final _MatchText cleaned;

  /// null when cleanup is disabled, and identical to [cleaned] when cleanup changed nothing.
  final _MatchText? cleanedMinor;
  final String? joinedCutCleaned;
  final String? joinedCutCleanedMinor;

  const _Property._({
    required this.cleaned,
    required this.cleanedMinor,
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
    if (joined == null || joined.isEmpty) return null;
    return _PropertySimple._(joined: joined);
  }
}

class _ScoreCalculator {
  final _StringMatcher matcher;
  final _MatchText query;
  final _MatchText? queryMinor;

  /// cleanup changed nothing in the query, so a property that also wasn't
  /// changed by cleanup would be matched against the exact same text twice.
  final bool _queryMinorIsSame;

  _ScoreCalculator({
    required this.matcher,
    required this.query,
    required this.queryMinor,
  }) : _queryMinorIsSame = queryMinor == null || identical(queryMinor, query);

  late final FuzzyMatcher _queryFuzzy = FuzzyMatcher(query.text);
  late final FuzzyMatcher? _queryMinorFuzzy = queryMinor == null ? null : FuzzyMatcher(queryMinor!.text);

  static const int maxScore = 1200;
  int score = 0;

  void scorePropertySimple(_PropertySimple? propertyString, {int multiplier = 1}) {
    if (propertyString == null) return;

    if (propertyString.joined.contains(query.text)) {
      score += 20 * multiplier;
    }
  }

  void scoreProperty(_Property? property, {int multiplier = 1, bool allowFuzzy = false}) {
    if (property == null) return;

    final cleaned = property.cleaned;
    if (cleaned.length == 0) return;
    if (query.length == 0) return;

    final cleanedMinor = property.cleanedMinor;
    final queryMinorText = queryMinor?.text;

    // -- exact match
    // -- ex: `"still here"` == `"still here"`
    if (cleaned.text == query.text) {
      score += 400 * multiplier;
      return;
    } else if (cleanedMinor != null && cleanedMinor.text == queryMinorText) {
      score += 400 * multiplier;
      return;
    }

    // -- same as exact match, but without the brackets possibly in title
    // -- ex: `"still here"` == `"still here"(feat. amy)`
    // -- worth noting that _simpleRatioForSplits picks the best match ratio not combined average,
    // -- so this might not be always useful, but it shines when exact matches score better than
    // -- the ones with brackets, putting it further down instead of first.
    // -- (ex: "without" makes their score similar, but "without me" gives 'false?' advantage)
    final joinedCutCleaned = property.joinedCutCleaned;
    final joinedCutCleanedMinor = property.joinedCutCleanedMinor;
    if (joinedCutCleaned != null && joinedCutCleaned == query.text) {
      score += 400 * multiplier;
      return;
    } else if (joinedCutCleanedMinor != null && joinedCutCleanedMinor == queryMinorText) {
      score += 400 * multiplier;
      return;
    }

    final matchingPercentageCleaned = matcher.compareMatchingPercentage(query, cleaned, fuzzy: allowFuzzy ? _queryFuzzy : null);
    score += (matchingPercentageCleaned * 200).round() * multiplier;

    if (score > 0) return;

    if (cleanedMinor == null || queryMinor == null) return;
    // -- both sides are untouched by cleanup, the pass above already did this exact comparison.
    if (_queryMinorIsSame && identical(cleanedMinor, cleaned)) return;

    final matchingPercentageCleanedMinor = matcher.compareMatchingPercentage(queryMinor!, cleanedMinor, fuzzy: allowFuzzy ? _queryMinorFuzzy : null);
    score += (matchingPercentageCleanedMinor * 300).round() * multiplier;
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
    if (scorePropertyAndIsEnough(trExt.splitStyle)) return score;
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
    _MatchText query,
    _MatchText property, {
    FuzzyMatcher? fuzzy,
  }) {
    double finalRatio = 0.0;

    if (_maxSimpleRatio(query.length, property.length, 0.7, 1.0) > _kMinEffectiveRatio && _canContain(query.length, query.mask, property.length, property.mask)) {
      finalRatio = _simpleRatio(query.text, query.length, property.text, property.length, 0.7, 1.0);
    }

    if (finalRatio < 0.7) {
      final ratioForSplits = _simpleRatioForSplits(query, property, _requiredRatio(finalRatio));
      if (ratioForSplits > finalRatio) finalRatio = ratioForSplits;
    }

    if (fuzzy != null && finalRatio < _kMaxLevenshtienRatio) {
      final requiredRatio = _requiredRatio(finalRatio);
      // -- distance is at least the length difference, so the ratio can never exceed min/max length
      if (_maxSimpleRatio(query.length, property.length, _kMaxLevenshtienRatio, _kMaxLevenshtienRatio) > requiredRatio) {
        final maxLen = query.length > property.length ? query.length : property.length;
        final maxDistance = (maxLen * (1 - requiredRatio / _kMaxLevenshtienRatio)).floor();
        final distance = fuzzy.distanceTo(property.text, property.length, maxDistance);
        if (distance <= maxDistance) {
          final levenshteinRatio = (1 - distance / maxLen) * _kMaxLevenshtienRatio;
          if (levenshteinRatio > finalRatio) finalRatio = levenshteinRatio;
        }
      }
    }

    return finalRatio.roundDecimals(_kRoundDecimals);
  }

  /// anything below this rounds down to zero, so it doesn't affect the score
  static double _requiredRatio(double finalRatio) => finalRatio > _kMinEffectiveRatio ? finalRatio : _kMinEffectiveRatio;

  /// highest ratio [_simpleRatio] could possibly return for these lengths
  static double _maxSimpleRatio(int queryLength, int propertyLength, double queryMultiplier, double propertyMultiplier) {
    if (propertyLength < queryLength) {
      if (queryLength == 0) return 0.0;
      return (propertyLength / queryLength) * queryMultiplier;
    }
    if (propertyLength == 0) return 0.0;
    return (queryLength / propertyLength) * propertyMultiplier;
  }

  /// whether the shorter text can be contained in the longer one, judging by their characters only.
  static bool _canContain(int queryLength, int queryMask, int propertyLength, int propertyMask) {
    return propertyLength < queryLength ? propertyMask & ~queryMask == 0 : queryMask & ~propertyMask == 0;
  }

  double _simpleRatioForSplits(_MatchText query, _MatchText property, double requiredRatio) {
    final querySplitsLength = query.parts.length;
    final propertySplitsLength = property.parts.length;
    if (querySplitsLength == 0) return 0.0;

    // -- ex: query="where go", property: "go"
    // -- so decrease score to allow tracks with "where do we go" to appear
    final queryMorePartsMultiplier = querySplitsLength > propertySplitsLength ? 0.5 : 1.0;
    final requiredCombinedRatio = requiredRatio * querySplitsLength / queryMorePartsMultiplier;

    final queryLengths = query.partsLengths;
    final queryMasks = query.partsMasks;
    final propertyLengths = property.partsLengths;
    final propertyMasks = property.partsMasks;

    double combinedRatio = 0.0;
    for (int qi = 0; qi < querySplitsLength; qi++) {
      // -- even perfect matches for all the remaining parts wouldn't reach the required ratio
      if (combinedRatio + (querySplitsLength - qi) <= requiredCombinedRatio) return 0.0;

      final qLength = queryLengths[qi];
      final qMask = queryMasks[qi];

      // -- max ratio has great advantage over combining all ratios
      // -- yes it will no longer favour shorter matches, but would
      // -- allow better sorting using other factors (ex: listens count)
      double maxRatioForQPart = 0.0;
      for (int pi = 0; pi < propertySplitsLength; pi++) {
        final pLength = propertyLengths[pi];
        if (_maxSimpleRatio(qLength, pLength, 0.4, 1.0) <= maxRatioForQPart) continue;
        if (!_canContain(qLength, qMask, pLength, propertyMasks[pi])) continue;
        final qpRatio = _simpleRatio(query.parts[qi], qLength, property.parts[pi], pLength, 0.4, 1.0);
        if (qpRatio > maxRatioForQPart) maxRatioForQPart = qpRatio;
        if (maxRatioForQPart >= 1.0) break;
      }
      combinedRatio += maxRatioForQPart;
    }

    return combinedRatio * queryMorePartsMultiplier / querySplitsLength;
  }

  double _simpleRatio(
    String query,
    int queryLength,
    String property,
    int propertyLength,
    double queryMultiplier,
    double propertyMultiplier,
  ) {
    if (propertyLength < queryLength) {
      final matchIndex = query.indexOf(property);
      if (matchIndex >= 0) {
        final offsetMultiplier = 1 - (matchIndex / queryLength);
        return (propertyLength / queryLength) * offsetMultiplier * queryMultiplier;
      }
    } else {
      final matchIndex = property.indexOf(query);
      if (matchIndex >= 0) {
        final offsetMultiplier = 1 - (matchIndex / propertyLength);
        return (queryLength / propertyLength) * offsetMultiplier * propertyMultiplier;
      }
    }
    return 0.0;
  }

  static const int _kRoundDecimals = 1;
  static const double _kMaxLevenshtienRatio = 0.2;

  /// lowest ratio that survives [_kRoundDecimals] rounding, minus an epsilon so it stays inclusive.
  static const double _kMinEffectiveRatio = 0.05 - 1e-9;
}
