// by claude
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/sync_manager/sync_manager.dart';
import 'package:namida/core/constants.dart';

void main() {
  const androidSong = '/storage/emulated/0/Music/Ultimate Library/Library/modus/Albums/2026 - REGNUM ULTRA/08 Stay With You.flac';
  const windowsSong = r'C:\Users\User\Music\Ultimate Library\Library\modus\Albums\2026 - REGNUM ULTRA\08 Stay With You.flac';

  late Directory dir;
  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('namida_sync_path_resolver_test');
    AppDirs.USER_DATA = '${dir.path}${Platform.pathSeparator}';
  });
  tearDownAll(() {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {} // -- the history files can still be open
  });

  var devicesCount = 0;

  void setLibrary(List<String> localPaths) {
    Indexer.inst.allTracksMappedByPath = {
      for (final path in localPaths) path: kDummyExtendedTrack.copyWith(path: path, generatePathHash: false),
    };
  }

  /// the sender's fingerprints never match here, only the path end can.
  Future<String> buildDevice(List<String> localPaths, {List<String> senderPaths = const []}) async {
    setLibrary(localPaths);
    final senderDeviceId = 'device_${devicesCount++}';
    final entries = [
      for (final path in senderPaths) [path, -1, -1],
    ];
    await SyncPathResolver.buildForDevice(senderDeviceId, entries);
    return senderDeviceId;
  }

  test('a sender path the fingerprints miss resolves by its folders and file name', () async {
    final deviceId = await buildDevice([windowsSong], senderPaths: [androidSong]);
    expect(SyncPathResolver.resolvedTracksFor(deviceId).keys, [androidSong]);
    expect(SyncPathResolver.resolvePath(deviceId, androidSong, .history), windowsSong);
  });

  test('paths missing from the sender fingerprints resolve too, ex: listens of files it removed', () async {
    final deviceId = await buildDevice([windowsSong]);
    expect(SyncPathResolver.resolvePath(deviceId, androidSong, .history), windowsSong);
  });

  test('a path that exists here stays as is', () async {
    final deviceId = await buildDevice([windowsSong]);
    expect(SyncPathResolver.resolvePath(deviceId, windowsSong, .history), isNull);
    expect(SyncPathResolver.pendingStoresByPath.containsKey(windowsSong), isFalse);
  });

  test('the file name alone is not enough', () async {
    final deviceId = await buildDevice([r'C:\Music\Other Album\01 Intro.flac']);
    expect(SyncPathResolver.resolvePath(deviceId, '/storage/Music/Album/01 Intro.flac', .history), isNull);
  });

  test('a file name in several folders goes to the one sharing the most folders, a tie matches none', () async {
    const artistA = r'C:\Music\Artist A\Album\01.flac';
    const artistB = r'C:\Music\Artist B\Album\01.flac';
    final deviceId = await buildDevice([artistA, artistB]);
    expect(SyncPathResolver.resolvePath(deviceId, '/storage/Music/artist b/album/01.FLAC', .history), artistB);
    expect(SyncPathResolver.resolvePath(deviceId, '/storage/Music/Artist C/Album/01.flac', .history), isNull);
  });

  group('queue files from another device', () {
    Uint8List queueFileBytes(List<String> paths) {
      final json = {'source': 'others', 'date': 1, 'isFav': false, 'tracks': paths};
      return utf8.encode(jsonEncode(json));
    }

    test('keep their bytes when no track changes', () {
      final bytes = queueFileBytes([androidSong]);
      final resolved = QueueController.resolveQueueFileBytes(bytes, (_) => null);
      expect(identical(resolved, bytes), isTrue);
    });

    test('get the local paths', () async {
      final deviceId = await buildDevice([windowsSong]);
      const missingSong = '/storage/emulated/0/Music/missing.flac';
      final bytes = queueFileBytes([androidSong, missingSong]);
      final resolved = QueueController.resolveQueueFileBytes(bytes, (track) => SyncPathResolver.resolveTrack(deviceId, track, .queues));
      final resolvedPaths = <String>[];
      QueueController.resolveQueueFileBytes(resolved, (track) {
        resolvedPaths.add(track.path);
        return null;
      });
      expect(resolvedPaths, [windowsSong, missingSong]);
      expect(SyncPathResolver.pendingStoresByPath[missingSong], SyncPathStore.queues.bit);
    });
  });

  group('pending paths', () {
    test('only file paths are kept, ex: not yt id keys of audio configs', () async {
      final deviceId = await buildDevice([]);
      expect(SyncPathResolver.resolvePath(deviceId, 'dQw4w9WgXcQ', .audioConfigs), isNull);
      expect(SyncPathResolver.pendingStoresByPath.containsKey('dQw4w9WgXcQ'), isFalse);
    });

    test('a path keeps every store it was stored in', () async {
      const song = '/storage/emulated/0/Music/stores/song.flac';
      final deviceId = await buildDevice([]);
      SyncPathResolver.resolvePath(deviceId, song, .stats);
      SyncPathResolver.resolvePath(deviceId, song, .playlists);
      expect(SyncPathResolver.pendingStoresByPath[song], SyncPathStore.stats.bit | SyncPathStore.playlists.bit);
    });
  });

  group('the library changing on the receiver', () {
    const senderDeviceId = 'android';
    var listenDate = DateTime(2026, 11, 6, 21).millisecondsSinceEpoch;

    setUpAll(() => HistoryController.inst.prepareHistoryFile());

    HistoryListensMessage historyMessageOf(List<TrackWithDate> listens) {
      return HistoryListensMessage(
        listens: SyncTrackListens.fromItems(listens),
        messageInfo: const BaseMessageInfo(action: .add, senderDeviceId: senderDeviceId),
      );
    }

    /// what [SyncDiscovery] does with a message carrying paths.
    Future<int> receive(BaseMessage msg) async {
      if (SyncPathResolver.isReadyFor(senderDeviceId)) return msg.executeOnReceivedWithQueue();
      return SyncPathResolver.stashUntilReady(msg);
    }

    List<TrackWithDate> listensAt(int dateMS) => HistoryController.inst.historyTracks.where((e) => e.dateAdded == dateMS).toList();

    test('a listen synced before the track got indexed here moves to the local path, the next sync adds no copy', () async {
      listenDate += 60000;
      final dateMS = listenDate;
      final listen = TrackWithDate(dateAdded: dateMS, track: Track.explicit(androidSong));
      setLibrary([]);
      await SyncPathResolver.buildForDevice(senderDeviceId, [
        [androidSong, -1, -1],
      ]);

      await receive(historyMessageOf([listen]));
      expect(listensAt(dateMS).map((e) => e.track.path), [androidSong]);
      expect(SyncPathResolver.pendingStoresByPath[androidSong], SyncPathStore.history.bit);

      setLibrary([windowsSong]);
      expect(SyncPathResolver.isReadyFor(senderDeviceId), isFalse);
      final addedCount = await receive(historyMessageOf([listen]));

      expect(addedCount, 0);
      expect(listensAt(dateMS).map((e) => e.track.path), [windowsSong]);
      expect(SyncPathResolver.pendingStoresByPath.containsKey(androidSong), isFalse);
      expect(SyncPathResolver.isReadyFor(senderDeviceId), isTrue);
    });

    test('an in place library change rebuilds the table too', () async {
      setLibrary([]);
      await SyncPathResolver.buildForDevice(senderDeviceId, const []);
      expect(SyncPathResolver.isReadyFor(senderDeviceId), isTrue);
      Indexer.inst.allTracksMappedByPath[windowsSong] = kDummyExtendedTrack.copyWith(path: windowsSong, generatePathHash: false);
      Indexer.inst.libraryRevision++;
      expect(SyncPathResolver.isReadyFor(senderDeviceId), isFalse);
    });

    test('an older copy of a listen at the sender path goes away once both copies point at the local track', () async {
      listenDate += 60000;
      final dateMS = listenDate;
      final listen = TrackWithDate(dateAdded: dateMS, track: Track.explicit(androidSong));
      setLibrary([]);
      await SyncPathResolver.buildForDevice(senderDeviceId, const []);
      await receive(historyMessageOf([listen]));
      final localCopy = TrackWithDate(dateAdded: dateMS, track: Track.explicit(windowsSong));
      await HistoryController.inst.addTracksToHistory([localCopy]);
      expect(listensAt(dateMS).length, 2);

      setLibrary([windowsSong]);
      await receive(historyMessageOf([listen]));

      expect(listensAt(dateMS).map((e) => e.track.path), [windowsSong]);
    });

    test('messages arriving while new fingerprints get applied wait for them', () async {
      listenDate += 60000;
      final dateMS = listenDate;
      setLibrary([windowsSong]);
      final building = SyncPathResolver.buildForDevice(senderDeviceId, [
        [androidSong, -1, -1],
      ]);
      expect(SyncPathResolver.isReadyFor(senderDeviceId), isFalse);
      final listen = TrackWithDate(dateAdded: dateMS, track: Track.explicit(androidSong));
      final applying = receive(historyMessageOf([listen]));
      await building;
      expect(await applying, 1);
      expect(listensAt(dateMS).map((e) => e.track.path), [windowsSong]);
    });
  });
}
