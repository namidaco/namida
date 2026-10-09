// by claude
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/sync_manager/sync_manager.dart';
import 'package:namida/core/constants.dart';

void main() {
  late Directory dir;
  const senderDeviceId = 'peer-device';
  final sep = Platform.pathSeparator;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('namida_track_stats_sync_test');
    AppDirs.USER_DATA = '${dir.path}$sep';
  });
  tearDownAll(() {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {} // -- the stats db can still be open
  });

  Track trackOf(String name) => Track.explicit('${dir.path}$sep$name.mp3');

  TrackStats statsOf(Track track, {int rating = 0, List<String>? tags, List<String>? moods, required int modifiedDate}) {
    return TrackStats(
      track: track,
      rating: rating,
      tags: tags ?? [],
      moods: moods ?? [],
      lastPositionInMs: 0,
      audioTrackId: null,
      bookmarks: null,
      modifiedDate: modifiedDate,
    );
  }

  Iterable<TrackStats> sendThroughSync(Iterable<TrackStats> stats) {
    final message = TrackStatsMessage(
      stats: stats,
      messageInfo: const BaseMessageInfo(action: MessageActionType.add, senderDeviceId: senderDeviceId),
    );
    final decoded = BaseMessage.decodeBytes(message.encodeBytes(), {senderDeviceId}, {});
    return (decoded as TrackStatsMessage).stats;
  }

  test('cleared stats keep their modified date through the sync codec', () {
    final track = trackOf('cleared');
    final received = sendThroughSync([statsOf(track, modifiedDate: 1700000000000)]).single;
    expect(received.track, track);
    expect(received.rating, 0);
    expect(received.modifiedDate, 1700000000000);
  });

  test('stats with values keep them through the sync codec', () {
    final track = trackOf('rated');
    final received = sendThroughSync([
      statsOf(track, rating: 80, tags: ['a'], moods: ['Happy'], modifiedDate: 5),
    ]).single;
    expect(received.rating, 80);
    expect(received.tags, ['a']);
    expect(received.moods, ['Happy']);
    expect(received.modifiedDate, 5);
  });

  test('cleared stats are stored with their modified date, never touched ones are not stored', () {
    final track = trackOf('stored');
    expect(statsOf(track, modifiedDate: 1700000000000).toJsonWithoutTrack(), {'_mt': 1700000000000});
    expect(statsOf(track, modifiedDate: 0).toJsonWithoutTrack(), isNull);
  });

  test('a newer cleared entry clears the local stats, an older one does not', () async {
    final newerTrack = trackOf('newer');
    final olderTrack = trackOf('older');
    final statsMap = Indexer.inst.trackStatsMap.value;
    statsMap[newerTrack] = statsOf(newerTrack, rating: 80, tags: ['x'], moods: ['Calm'], modifiedDate: 1000);
    statsMap[olderTrack] = statsOf(olderTrack, rating: 60, modifiedDate: 3000);

    final incoming = sendThroughSync([statsOf(newerTrack, modifiedDate: 2000), statsOf(olderTrack, modifiedDate: 2000)]);
    await Indexer.inst.importTrackStats(incoming, senderDeviceId);

    final newer = statsMap[newerTrack]!;
    expect(newer.rating, 0);
    expect(newer.tags, isEmpty);
    expect(newer.moods, isEmpty);
    expect(newer.modifiedDate, 2000);

    final older = statsMap[olderTrack]!;
    expect(older.rating, 60);
    expect(older.modifiedDate, 3000);
  });

  test('editing stats without tags or moods does not copy the embedded ones into the stats', () async {
    final track = trackOf('embedded');
    Indexer.inst.allTracksMappedByPath[track.path] = kDummyExtendedTrack.copyWith(
      path: track.path,
      tagsList: ['embedded tag'],
      moodList: ['Embedded Mood'],
      generatePathHash: false,
    );

    final stats = await Indexer.inst.updateTrackStats(track, lastPositionInMs: 5000);
    expect(stats.tags, anyOf(isNull, isEmpty));
    expect(stats.moods, anyOf(isNull, isEmpty));
    expect(stats.lastPositionInMs, 5000);
  });

  test('comma lists skip blank items and duplicates', () {
    expect(Indexer.splitByCommaList('a,  , b,a,'), ['a', 'b']);
    expect(Indexer.splitByCommaList(' '), isEmpty);
  });
}
