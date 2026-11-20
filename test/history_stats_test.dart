// by claude
import 'dart:collection';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:history_manager/history_manager.dart';

import 'package:namida/class/history_stats.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';

void main() {
  late Directory dir;
  final sep = Platform.pathSeparator;
  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('namida_history_stats_test');
    AppDirs.USER_DATA = dir.path;
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  test('a big history gives the same counts while computing in slices, and listens added meanwhile do not break it', () async {
    const daysCount = 2000;
    const listensPerDay = 60;
    const tracksCount = 300;
    final tracks = List.generate(tracksCount, (i) => Track.explicit('${dir.path}$sep$i.m4a'), growable: false);

    final historyMap = SplayTreeMap<int, List<TrackWithDate>>((date1, date2) => date2.compareTo(date1));
    final expectedCounts = <Track, int>{};
    final startMS = DateTime(2020, 1, 1, 12).millisecondsSinceEpoch;
    for (int d = 0; d < daysCount; d++) {
      final dayMS = startMS + d * Duration.millisecondsPerDay;
      final dayListens = <TrackWithDate>[];
      for (int i = listensPerDay - 1; i >= 0; i--) {
        final track = tracks[(d * 7 + i * 13) % tracksCount];
        dayListens.add(TrackWithDate(dateAdded: dayMS + i * 60000, track: track, source: TrackSource.local));
        expectedCounts[track] = (expectedCounts[track] ?? 0) + 1;
      }
      historyMap[dayMS.toDaysSince1970()] = dayListens;
    }
    final firstDay = startMS.toDaysSince1970();
    final lastDay = firstDay + daysCount - 1;

    final history = HistoryController.inst;
    history.historyMap.value = historyMap;

    final computing = HistoryStatsSnapshot.compute(
      history: history,
      resolver: const _TestResolver(),
      firstDay: firstDay,
      lastDay: lastDay,
      dailyListenTime: const {},
      listenTimeKeys: const [],
    );
    final laterMS = startMS + (daysCount + 5) * Duration.millisecondsPerDay;
    historyMap[laterMS.toDaysSince1970()] = [TrackWithDate(dateAdded: laterMS, track: tracks.first, source: TrackSource.local)];
    final snapshot = await computing;

    expect(snapshot.totalListens, daysCount * listensPerDay);
    expect(snapshot.daysWithListens, daysCount);
    expect(snapshot.listensPerDay.every((e) => e == listensPerDay), true);
    expect(snapshot.uniqueItems, tracksCount);
    for (final entry in snapshot.topItems) {
      expect(entry.count, expectedCounts[entry.key]);
    }
    final expectedTopCounts = expectedCounts.values.toList()..sort((a, b) => b.compareTo(a));
    expect(snapshot.topItems.map((e) => e.count).toList(), expectedTopCounts.take(snapshot.topItems.length).toList());
  });

  test('listening clock reads each listen in the offset of its own date, summer and winter alike', () async {
    final track = Track.explicit('${dir.path}${sep}clock.m4a');
    final listenDates = [
      DateTime(2026, 1, 4, 6, 15),
      DateTime(2026, 4, 5, 6, 15),
      DateTime(2026, 7, 5, 6, 15),
      DateTime(2026, 10, 4, 6, 15),
      DateTime(2026, 10, 4, 0, 20),
    ];
    final historyMap = SplayTreeMap<int, List<TrackWithDate>>((date1, date2) => date2.compareTo(date1));
    for (final date in listenDates) {
      final ms = date.millisecondsSinceEpoch;
      final dayListens = historyMap[ms.toDaysSince1970()] ??= [];
      dayListens.insert(0, TrackWithDate(dateAdded: ms, track: track, source: TrackSource.local));
    }

    final history = HistoryController.inst;
    history.historyMap.value = historyMap;

    final firstDay = listenDates.first.millisecondsSinceEpoch.toDaysSince1970();
    final lastDay = listenDates.last.millisecondsSinceEpoch.toDaysSince1970();
    final snapshot = await HistoryStatsSnapshot.compute(
      history: history,
      resolver: const _TestResolver(),
      firstDay: firstDay,
      lastDay: lastDay,
      dailyListenTime: const {},
      listenTimeKeys: const [],
    );

    const sundayIndex = 0;
    expect(listenDates.every((e) => e.weekday == DateTime.sunday), true);
    expect(snapshot.hours[6], 4);
    expect(snapshot.hours[0], 1);
    expect(snapshot.weekdays[sundayIndex], listenDates.length);
    expect(snapshot.weekHours[sundayIndex * 24 + 6], 4);
  });

  group('listen time', () {
    const key = 'k';
    const measuredSecondsPerDay = 100;
    const trackSeconds = 180;
    late final known = Track.explicit('${dir.path}${sep}known.m4a');
    late final unknown = Track.explicit('${dir.path}${sep}unknown.m4a');
    final day0 = DateTime(2025, 3, 1, 12).millisecondsSinceEpoch.toDaysSince1970();

    // -- days 0-4 before the daily db, days 5-9 measured with an apple music listen each, days 10-11 measured only
    SplayTreeMap<int, List<TrackWithDate>> buildHistory(Track localTrack) {
      final historyMap = SplayTreeMap<int, List<TrackWithDate>>((date1, date2) => date2.compareTo(date1));
      for (int i = 0; i < 12; i++) {
        final day = day0 + i;
        final dayMS = HistoryManager.daysSince1970ToMilliseconds(day) + 12 * 3600000;
        historyMap[day] = [
          if (i >= 5 && i < 10) TrackWithDate(dateAdded: dayMS + 120000, track: known, source: TrackSource.appleMusic),
          TrackWithDate(dateAdded: dayMS + 60000, track: localTrack, source: TrackSource.local),
          TrackWithDate(dateAdded: dayMS, track: localTrack, source: TrackSource.local),
        ];
      }
      return historyMap;
    }

    final daily = {
      for (int i = 5; i < 12; i++) day0 + i: {key: measuredSecondsPerDay},
    };

    Future<HistoryStatsSnapshot<Track>> computeRange(int firstOffset, int lastOffset, _TestResolver resolver) {
      return HistoryStatsSnapshot.compute(
        history: HistoryController.inst,
        resolver: resolver,
        firstDay: day0 + firstOffset,
        lastDay: day0 + lastOffset,
        dailyListenTime: daily,
        listenTimeKeys: const [key],
      );
    }

    test('measured days are exact, older and imported listens add their durations', () async {
      HistoryController.inst.historyMap.value = buildHistory(known);
      const resolver = _TestResolver();

      final all = await computeRange(0, 11, resolver);
      expect(all.listenSeconds, 7 * measuredSecondsPerDay + 10 * trackSeconds + 5 * trackSeconds);
      expect(all.listenSecondsExact, false);

      final beforeDb = await computeRange(0, 4, resolver);
      expect(beforeDb.listenSeconds, 10 * trackSeconds);
      expect(beforeDb.listenSecondsExact, false);

      final measuredWithImports = await computeRange(5, 9, resolver);
      expect(measuredWithImports.listenSeconds, 5 * measuredSecondsPerDay + 5 * trackSeconds);
      expect(measuredWithImports.listenSecondsExact, false);

      final measuredOnly = await computeRange(10, 11, resolver);
      expect(measuredOnly.listenSeconds, 2 * measuredSecondsPerDay);
      expect(measuredOnly.listenSecondsExact, true);
    });

    test('unknown durations take the known average, or the measured average when none is known', () async {
      HistoryController.inst.historyMap.value = buildHistory(unknown);

      final withKnownImports = await computeRange(0, 9, _TestResolver(unknownDurationTracks: {unknown}));
      expect(withKnownImports.listenSeconds, 5 * measuredSecondsPerDay + 15 * trackSeconds);

      final noneKnown = await computeRange(0, 4, _TestResolver(unknownDurationTracks: {unknown, known}));
      const measuredSecondsPerLocalListen = 7 * measuredSecondsPerDay / 14;
      expect(noneKnown.listenSeconds, (10 * measuredSecondsPerLocalListen).round());
    });
  });
}

class _TestResolver extends HistoryStatsResolver<Track> {
  final Set<Track> unknownDurationTracks;

  const _TestResolver({this.unknownDurationTracks = const {}});

  @override
  int durationSeconds(Track item) => unknownDurationTracks.contains(item) ? 0 : 180;

  @override
  List<String> artists(Track item) => const ['Artist'];

  @override
  List<String> genres(Track item) => const ['Genre'];

  @override
  String? album(Track item) => 'Album';
}
