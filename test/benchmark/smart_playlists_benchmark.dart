// by claude
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/lang.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/smart_playlists/smart_playlists_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/language.dart';

import 'bench_data.dart';

void main() {
  late Directory dir;
  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('namida_smart_playlists_benchmark');
    AppDirs.USER_DATA = '${dir.path}${Platform.pathSeparator}';
    Language.inst.update(language: NamidaLanguage.fromCode('en'));
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  test('smart playlists resolving', () async {
    final runner = BenchRunner('smart_playlists');
    final synthetic = SyntheticLibrary.generate(kBenchTracksCount);
    final allTracks = <Track>[];
    for (final s in synthetic) {
      final track = Track.explicit(s.path);
      allTracks.add(track);
      final title = s.title ?? s.path.getFilename;
      final artist = s.artist;
      final genre = s.genre;
      Indexer.inst.allTracksMappedByPath[s.path] = kDummyExtendedTrack.copyWith(
        path: s.path,
        title: title,
        originalArtist: artist ?? UnknownTags.ARTIST,
        artistsList: artist == null ? const [UnknownTags.ARTIST] : [artist],
        genresList: genre == null ? const [UnknownTags.GENRE] : [genre],
        dateAdded: s.dateAddedMS,
        durationMS: s.durationMS,
        rating: s.rating,
        generatePathHash: false,
      );
    }

    final nowMS = DateTime.now().millisecondsSinceEpoch;
    const dayMS = Duration.millisecondsPerDay;
    final random = Random(7);
    final listensByTrack = <Track, List<int>>{};
    int listensCount = 0;
    while (listensCount < 200000) {
      final skew = pow(random.nextDouble(), 2.5);
      final trackIndex = (allTracks.length * skew).floor();
      final ageMS = (random.nextDouble() * 3 * 365 * dayMS).floor();
      final isNearBoundary = (ageMS - 30 * dayMS).abs() < dayMS;
      if (isNearBoundary) continue;
      final track = allTracks[trackIndex];
      final listenMS = nowMS - ageMS;
      listensByTrack.addForce(track, listenMS);
      listensCount++;
    }
    final topTracksMapListens = HistoryController.inst.topTracksMapListens.value;
    await runner.run('ListensSortedMap.assignAll ${listensByTrack.length} tracks / $listensCount listens', () {
      final copy = {for (final e in listensByTrack.entries) e.key: e.value.toList()};
      topTracksMapListens.assignAll(copy);
      return topTracksMapListens.length;
    }, iterations: 7);

    SmartPlaylist playlistOf(SmartPlaylistRuleBase rule) => SmartPlaylist(
      name: 'bench',
      creationDate: DateTime(2026),
      joiner: SmartJoiner.and,
      sorts: const [],
      sortReverse: false,
      moods: const [],
      ruleGroups: [
        SmartPlaylistRuleGroup.create(rules: [rule]),
      ],
      limit: null,
    );

    final rules = <String, SmartPlaylistRuleBase>{
      'text contains (cleanup)': SmartPlaylistRuleText(
        data: [SmartPlaylistTextDataTokenLiteral('love')],
        data2: null,
        filter: SmartPlaylistRuleFilterText.contains,
        source: SmartPlaylistRuleFilterTextSource.title,
        enableCleanup: true,
      ),
      'text regex (cleanup)': SmartPlaylistRuleText(
        data: [SmartPlaylistTextDataTokenLiteral(r'^(the|a)\s')],
        data2: null,
        filter: SmartPlaylistRuleFilterText.regexMatch,
        source: SmartPlaylistRuleFilterTextSource.title,
        enableCleanup: true,
      ),
      'date isWithinLast 30d (any listen)': SmartPlaylistRuleDateTime(
        data: null,
        data2: null,
        filter: SmartPlaylistRuleFilterDateTime.isWithinLast,
        source: SmartPlaylistRuleFilterDateTimeSource.anyListen,
        enableCleanup: false,
        clockOnly: false,
        relativeDuration: const SmartPlaylistRelativeDuration(amount: 30, unit: SmartPlaylistRelativeUnit.days),
      ),
      'number totalListens > 5': SmartPlaylistRuleNumber(
        data: 5,
        data2: null,
        filter: SmartPlaylistRuleFilterNumber.isGreaterThan,
        source: SmartPlaylistRuleFilterNumberSource.totalListens,
        enableCleanup: false,
        scope: SmartPlaylistNumberScope.track,
        aggregate: SmartPlaylistNumberAggregate.sum,
      ),
    };

    for (final e in rules.entries) {
      final ruleName = e.key;
      final playlist = playlistOf(e.value);
      final indices = playlist.resolveIterableUnSortedAsIndices(allTracks).toFixedList();
      runner.digest(ruleName, indices.map((e) => '$e'));
      await runner.run('$ruleName x${allTracks.length}', () => playlist.resolveIterableUnSorted(allTracks).length, iterations: 10);
    }
    runner.finish();
  }, timeout: Timeout.none);
}
