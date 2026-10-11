import 'dart:math' as math;

import 'package:namida/base/generator_base.dart';
import 'package:namida/class/file_matcher.dart';
import 'package:namida/class/library_item_map.dart';
import 'package:namida/class/queue_insertion.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/rhythm_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';

class NamidaGenerator extends NamidaGeneratorBase<TrackWithDate, Track> {
  static final NamidaGenerator inst = NamidaGenerator._internal();
  NamidaGenerator._internal() : super(HistoryController.inst);

  static Iterable<String> getHighMatcheFilesFromFilenameOldd(
    Iterable<String> files,
    String filePathToMatch, {
    Map<String, List<String>>? allFilesByName,
    Map<String, List<String>>? allFilesByNameWOExt,
    bool singleOnly = false,
  }) {
    int? latestPriority;
    bool requiresSorting = false;
    final matches = <(String, int)>[];

    void addMatch(String filePath, int priority) {
      matches.add((filePath, priority));
      if (requiresSorting == false) {
        if (priority != latestPriority) {
          if (latestPriority == null) {
            latestPriority = priority;
          } else {
            latestPriority = priority;
            requiresSorting = true;
          }
        }
      }
    }

    final filenameToMatch = filePathToMatch.getFilename;
    final filenameWOExtToMatch = filePathToMatch.getFilenameWOExt;

    if (allFilesByName != null) {
      final fileSystemsFilename = allFilesByName[filePathToMatch] ?? [];
      for (final e in fileSystemsFilename) {
        if (filenameToMatch == e) {
          if (singleOnly) return [e];
          addMatch(e, 0);
        }
      }
    }

    if (allFilesByNameWOExt != null) {
      final fileSystemsFilenameWOExt = allFilesByNameWOExt[filePathToMatch] ?? [];
      for (final e in fileSystemsFilenameWOExt) {
        if (filenameWOExtToMatch == e) {
          if (singleOnly) return [e];
          addMatch(e, 1);
        }
      }
    }

    final filenameToMatchCleaned = filenameToMatch.cleanUpForComparison;
    final l = FileMatcher.getTitleAndArtistFromFilename(filenameToMatch);
    final trackTitle = l.$1;
    final trackArtist = l.$2;

    for (final path in files) {
      final fileSystemFilename = path.getFilename;
      if (filenameToMatch == fileSystemFilename) {
        if (singleOnly) return [path];
        addMatch(path, 0);
        continue;
      }
      final fileSystemFilenameWOExt = path.getFilenameWOExt;
      if (filenameWOExtToMatch == fileSystemFilenameWOExt) {
        if (singleOnly) return [path];
        addMatch(path, 1);
        continue;
      }

      final fileSystemFilenameCleaned = fileSystemFilename.cleanUpForComparison;

      if (fileSystemFilenameCleaned.contains(filenameToMatchCleaned)) {
        addMatch(path, 2);
        continue;
      }
      if (fileSystemFilenameCleaned.contains(trackTitle.splitFirst('(')) && fileSystemFilenameCleaned.contains(trackArtist)) {
        addMatch(path, 3);
        continue;
      }
    }

    if (requiresSorting) {
      matches.sortBy((e) => e.$2); // lower priority means it should be first
    }

    return matches.map((e) => e.$1);
  }

  Iterable<Track> getRandomTracks({Track? exclude, int? min, int? max}) {
    return NamidaGeneratorBase.getRandomItems(allTracksInLibrary, exclude: exclude, min: min, max: max);
  }

  Iterable<Track> generateRecommendedSimilarDiscoverDate(Track track) {
    return super.generateRecommendedSimilarDiscoverDateFor(track, (current) => current.track);
  }

  Iterable<Track> generateRecommendedSimilarTimeRange(Track track) {
    return super.generateRecommendedSimilarTimeRangeFor(track, (current) => current.track);
  }

  Iterable<Track> generateRecommendedTrack(Track track, {int? sampleCount}) {
    return super.generateRecommendedItemsFor(track, (current) => current.track, sampleCount: sampleCount);
  }

  Future<List<Track>> generateSimilarTracks(Track track, QueueInsertion insertion) async {
    final sources = insertion.similarSources;
    final usesRhythm = sources.any((source) => source.isRhythm);
    final rhythm = RhythmController.inst;
    if (usesRhythm && rhythm.isEnabled) await rhythm.ensureLoaded();
    final historyListens = sources.contains(SimilarTracksSource.history) ? super.getRecommendedListensFor(track, (current) => current.track) : null;
    final scorer = _SimilarTracksScorer(track);
    scorer.score(sources, historyListens);
    return scorer.pick(insertion.numberOfTracks);
  }

  /// [daysRange] means taking n days before [yearTimeStamp] & n days after [yearTimeStamp].
  ///
  /// For best results, track should have the year tag in [yyyyMMdd] format (or any parsable format),
  /// Having a [yyyy] year tag will generate from the same year which is quite a wide range.
  List<Track> generateTracksFromSameEra(int yearTimeStamp, {int daysRange = 30, Track? currentTrack}) {
    final tracksAvailable = <Track>[];

    // -- [yyyy] year format.
    if (yearTimeStamp.toString().length == 4) {
      for (var e in allTracksInLibrary) {
        if (e.year != 0) {
          // -- if the track also has [yyyy]
          if (e.year.toString().length == 4) {
            if (e.year == yearTimeStamp) {
              tracksAvailable.add(e);
            }

            // -- if the track has parsable format
          } else {
            final dt = DateTime.tryParse(e.year.toString());
            if (dt != null && dt.year == yearTimeStamp) {
              tracksAvailable.add(e);
            }
          }
        }
      }

      // -- parsable year format.
    } else {
      final dateParsed = DateTime.tryParse(yearTimeStamp.toString());
      if (dateParsed == null) return [];

      for (var e in allTracksInLibrary) {
        if (e.year != 0) {
          final dt = e.yearAsDateTime();
          if (dt != null && (dt.difference(dateParsed).inDays).abs() <= daysRange) {
            tracksAvailable.add(e);
          }
        }
      }
    }
    tracksAvailable.remove(currentTrack);
    return tracksAvailable;
  }

  List<Track> generateTracksFromRatings(
    int minRating,
    int maxRating,
  ) {
    final finalTracks = <Track>[];
    Indexer.inst.trackStatsMap.value.forEach((key, value) {
      if (value.rating >= minRating && value.rating <= maxRating) {
        finalTracks.add(key);
      }
    });
    return finalTracks;
  }
}

// by claude
class _SimilarTracksScorer {
  final Track seed;
  final TrackExtended seedExt;

  _SimilarTracksScorer(this.seed) : seedExt = seed.toTrackExt();

  static const _maxPerAlbum = 3;
  static const _poolPerTrack = 3;
  static const _minRelativeScore = 0.25;
  static const _yearsRange = 8;
  static const _maxKeyCost = 1.5;
  static const RhythmFlow _unknownFlow = (bpm: 0.0, key: -1);

  static final _random = math.Random();

  final _scores = <Track, double>{};

  void _add(Track tr, double weight) {
    _scores.update(tr, (value) => value + weight, ifAbsent: () => weight);
  }

  void score(List<SimilarTracksSource> sources, Map<Track, int>? historyListens) {
    final indexer = Indexer.inst;
    final passSources = <SimilarTracksSource>{};
    for (final source in sources) {
      switch (source) {
        case SimilarTracksSource.genre:
          _addFromGroups(indexer.mainMapGenres, seedExt.genresList, source.weight);
        case SimilarTracksSource.style:
          _addFromGroups(indexer.mainMapStyles, seedExt.stylesList, source.weight);
        case SimilarTracksSource.artist:
          _addFromGroups(indexer.mainMapArtists, seedExt.artistsList, source.weight);
        case SimilarTracksSource.albumArtist:
          _addFromGroups(indexer.mainMapAlbumArtists, seedExt.albumArtistsList, source.weight);
        case SimilarTracksSource.composer:
          _addFromGroups(indexer.mainMapComposer, seedExt.composersList, source.weight);
        case SimilarTracksSource.language:
          _addFromGroups(indexer.mainMapLanguages, seedExt.languagesList, source.weight);
        case SimilarTracksSource.history:
          if (historyListens != null) _addFromHistory(historyListens, source.weight);
        case SimilarTracksSource.mood || SimilarTracksSource.tag || SimilarTracksSource.year || SimilarTracksSource.bpm || SimilarTracksSource.key:
          passSources.add(source);
      }
    }
    if (passSources.isNotEmpty) _addFromLibraryPass(passSources);
  }

  void _addFromGroups(LibraryItemMap map, List<String> seedValues, double weight) {
    final groups = map.value;
    for (final value in seedValues) {
      final tracks = groups[value];
      if (tracks == null) continue;
      for (final tr in tracks) {
        _add(tr, weight);
      }
    }
  }

  void _addFromHistory(Map<Track, int> historyListens, double weight) {
    if (historyListens.isEmpty) return;
    final maxListens = historyListens.values.reduce(math.max);
    for (final e in historyListens.entries) {
      _add(e.key, weight * e.value / maxListens);
    }
  }

  void _addFromLibraryPass(Set<SimilarTracksSource> sources) {
    final statsMap = Indexer.inst.trackStatsMap.value;
    final seedStats = statsMap[seed];
    final seedMoods = sources.contains(SimilarTracksSource.mood) ? {...seedExt.moodList, ...?seedStats?.moods} : const <String>{};
    final seedTags = sources.contains(SimilarTracksSource.tag) ? {...seedExt.tagsList, ...?seedStats?.tags} : const <String>{};
    final seedYear = sources.contains(SimilarTracksSource.year) ? _yearOf(seedExt.year) : 0;

    final rhythm = RhythmController.inst;
    final usesRhythm = sources.any((source) => source.isRhythm);
    final seedFlow = usesRhythm ? rhythm.flowOf(seed) : _unknownFlow;
    final seedBpm = sources.contains(SimilarTracksSource.bpm) ? seedFlow.bpm : 0.0;
    final seedKey = sources.contains(SimilarTracksSource.key) ? seedFlow.key : -1;

    final moodWeight = seedMoods.isEmpty ? 0.0 : SimilarTracksSource.mood.weight;
    final tagWeight = seedTags.isEmpty ? 0.0 : SimilarTracksSource.tag.weight;
    final yearWeight = seedYear == 0 ? 0.0 : SimilarTracksSource.year.weight;
    final bpmWeight = seedBpm <= 0 ? 0.0 : SimilarTracksSource.bpm.weight;
    final keyWeight = seedKey < 0 ? 0.0 : SimilarTracksSource.key.weight;
    final needsStats = moodWeight > 0 || tagWeight > 0;
    final needsFlow = bpmWeight > 0 || keyWeight > 0;
    if (!needsStats && !needsFlow && yearWeight == 0) return;

    for (final tr in allTracksInLibrary) {
      final trExt = tr.toTrackExtOrNull();
      if (trExt == null) continue;
      final trStats = needsStats ? statsMap[tr] : null;
      double score = 0.0;
      if (moodWeight > 0) score += moodWeight * _countShared(seedMoods, trExt.moodList, trStats?.moods);
      if (tagWeight > 0) score += tagWeight * _countShared(seedTags, trExt.tagsList, trStats?.tags);
      if (yearWeight > 0) {
        final year = _yearOf(trExt.year);
        final yearsApart = (year - seedYear).abs();
        if (year != 0 && yearsApart < _yearsRange) score += yearWeight * (1 - yearsApart / _yearsRange);
      }
      if (needsFlow) {
        final flow = rhythm.flowOf(tr);
        if (bpmWeight > 0 && flow.bpm > 0) {
          final tempoCost = RhythmController.tempoCostBetween(seedBpm, flow.bpm);
          score += bpmWeight * (1 - tempoCost / RhythmController.maxTempoCost);
        }
        if (keyWeight > 0 && flow.key >= 0) {
          final keyCost = RhythmController.keyCostBetween(seedKey, flow.key);
          if (keyCost < _maxKeyCost) score += keyWeight * (1 - keyCost / _maxKeyCost);
        }
      }
      if (score > 0) _add(tr, score);
    }
  }

  /// [fromStats] values already embedded count once.
  static int _countShared(Set<String> seedValues, List<String> embedded, List<String>? fromStats) {
    int count = 0;
    for (final value in embedded) {
      if (seedValues.contains(value)) count++;
    }
    if (fromStats != null) {
      for (final value in fromStats) {
        if (seedValues.contains(value) && !embedded.contains(value)) count++;
      }
    }
    return count;
  }

  /// [year] can be `yyyy` or `yyyyMMdd`.
  static int _yearOf(int year) => year < 10000 ? year : year ~/ 10000;

  /// a weighted random order over the best matches, at most [_maxPerAlbum] tracks of each album.
  List<Track> pick(int count) {
    _scores.remove(seed);
    if (_scores.isEmpty) return [];
    final maxScore = _scores.values.reduce(math.max);
    final minScore = maxScore * _minRelativeScore;
    final ranked = _scores.entries.where((e) => e.value >= minScore).toFixedList();
    ranked.sortByReverse((e) => e.value);
    final poolSize = count > 0 ? count * _poolPerTrack : ranked.length;
    final albumCounts = <String, int>{};
    final pool = <_SimilarTrackPick>[];
    for (final e in ranked) {
      if (pool.length >= poolSize) break;
      final score = e.value;
      final tr = e.key;
      final album = tr.originalAlbum;
      if (album.isNotEmpty) {
        final albumCount = albumCounts.update(album, (value) => value + 1, ifAbsent: () => 1);
        if (albumCount > _maxPerAlbum) continue;
      }
      final randomValue = _random.nextDouble();
      final priority = math.pow(randomValue, 1 / score).toDouble();
      pool.add((track: tr, priority: priority));
    }
    pool.sortByReverse((e) => e.priority);
    return pool.map((e) => e.track).toFixedList();
  }
}

typedef _SimilarTrackPick = ({Track track, double priority});
