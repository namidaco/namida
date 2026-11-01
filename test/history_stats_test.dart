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
      totalListenSeconds: 0,
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
}

class _TestResolver extends HistoryStatsResolver<Track> {
  const _TestResolver();

  @override
  int durationSeconds(Track item) => 180;

  @override
  List<String> artists(Track item) => const ['Artist'];

  @override
  List<String> genres(Track item) => const ['Genre'];

  @override
  String? album(Track item) => 'Album';
}
