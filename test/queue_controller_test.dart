// by claude
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_test/flutter_test.dart';

import 'package:namico_db_wrapper/namico_db_wrapper.dart';

import 'package:namida/class/queue.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';

void main() {
  late Directory dir;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('namida_queue_controller_test');
    AppDirs.USER_DATA = '${dir.path}${Platform.pathSeparator}';
    Directory(AppDirs.QUEUES).createSync(recursive: true);
  });

  // -- the latest queue file is written with a 2s debounce
  tearDownAll(() async {
    await Future<void>.delayed(const Duration(milliseconds: 2300));
    dir.deleteSync(recursive: true);
  });

  setUp(() async {
    for (final file in Directory(AppDirs.QUEUES).listSync()) {
      file.deleteSync();
    }
    await QueueController.inst.prepareAllQueuesFile();
  });

  Map<int, Queue> queues() => QueueController.inst.queuesMap.value;

  String queuePath(int date) => '${AppDirs.QUEUES}$date.json';

  Track track(String name) => Track.explicit('/music/$name.mp3');

  Future<void> addQueue(QueueSourceBase source, int date, List<Track> tracks) {
    return QueueController.inst.addNewQueue(source: source, homePageItem: null, date: date, tracks: tracks);
  }

  List<int> u32(int value) => [value & 0xFF, value >> 8 & 0xFF, value >> 16 & 0xFF, value >> 24 & 0xFF];

  List<int> itemBytes(int typeId, String payload, {int? originalIndex}) {
    final payloadBytes = utf8.encode(payload);
    return [typeId, if (originalIndex != null) ...u32(originalIndex), ...u32(payloadBytes.length), ...payloadBytes];
  }

  List<int>? readBytes(String path) {
    try {
      return File(path).readAsBytesSync();
    } catch (_) {
      return null;
    }
  }

  List<Playable> readItems(String path) => QueueController.debugReadLatestQueueFile(path).$1;

  /// saving the player queue runs unawaited.
  Future<void> waitUntil(bool Function() condition) async {
    for (int i = 0; i < 300 && !condition(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  Future<void> waitForQueueFile(int date, int itemsCount) => waitUntil(() => readItems(queuePath(date)).length == itemsCount);

  group('storage format', () {
    test('a queue file holds its meta then its items in the binary layout', () async {
      await addQueue(QueueSource.allTracks, 1000, [Track.explicit('/music/a.mp3'), Video.explicit('/music/b.mp4')]);
      final meta = utf8.encode('{"source":"allTracks","homePageItem":null,"date":1000,"isFav":false}');
      final golden = [
        0x01,
        0x00,
        ...u32(meta.length),
        ...meta,
        ...u32(2),
        ...itemBytes(0, '/music/a.mp3'),
        ...itemBytes(1, '/music/b.mp4'),
      ];
      expect(readBytes(queuePath(1000)), golden);
    });

    test('a queue file loads back with its meta and item types', () async {
      await QueueController.inst.addNewQueue(
        source: QueueSource.playlist('mix'),
        homePageItem: HomePageItems.mixes,
        date: 1000,
        tracks: [track('a'), Video.explicit('/music/b.mp4')],
      );
      await QueueController.inst.prepareAllQueuesFile();
      final queue = queues()[1000]!;
      expect(queue.source, QueueSource.playlist('mix'));
      expect(queue.homePageItem, HomePageItems.mixes);
      expect(queue.isFav, isFalse);
      expect(queue.tracks, [track('a'), Video.explicit('/music/b.mp4')]);
      expect(queue.tracks[0], isNot(isA<Video>()));
      expect(queue.tracks[1], isA<Video>());
    });

    test('legacy json queue files still load', () async {
      final legacyQueue = {
        'source': 'allTracks',
        'homePageItem': null,
        'date': 2000,
        'isFav': true,
        'tracks': [
          '/music/a.mp3',
          {'t': '/music/b.mp4', 'v': true},
        ],
      };
      File(queuePath(2000)).writeAsStringSync(jsonEncode(legacyQueue));
      await QueueController.inst.prepareAllQueuesFile();
      final queue = queues()[2000]!;
      expect(queue.source, QueueSource.allTracks);
      expect(queue.isFav, isTrue);
      expect(queue.tracks, [track('a'), Video.explicit('/music/b.mp4')]);
      expect(queue.tracks[1], isA<Video>());
    });

    test('the latest queue file keeps the shuffled order with the original indices', () async {
      final items = <Playable>[track('a'), track('b'), Video.explicit('/music/c.mp4')];
      await QueueController.inst.updateLatestQueue(items, originalIndices: [2, 0, 1], source: QueueSource.playerQueue);
      final golden = [
        0x01,
        0x01,
        ...u32(0),
        ...u32(3),
        ...itemBytes(0, '/music/a.mp3', originalIndex: 2),
        ...itemBytes(0, '/music/b.mp3', originalIndex: 0),
        ...itemBytes(1, '/music/c.mp4', originalIndex: 1),
      ];
      await waitUntil(() => listEquals(readBytes(AppPaths.LATEST_QUEUE), golden));
      expect(readBytes(AppPaths.LATEST_QUEUE), golden);

      final (restoredItems, originalIndices) = QueueController.debugReadLatestQueueFile(AppPaths.LATEST_QUEUE);
      expect(restoredItems, items);
      expect(restoredItems[2], isA<Video>());
      expect(originalIndices, [2, 0, 1]);

      await waitUntil(() => queues().isNotEmpty);
      final savedQueue = queues().values.single;
      expect(savedQueue.tracks, [track('b'), Video.explicit('/music/c.mp4'), track('a')]);
      await waitForQueueFile(savedQueue.date, 3);
    });

    test('legacy json latest queue files still load', () {
      final legacyFile = File('${dir.path}${Platform.pathSeparator}legacy_latest_queue.json');
      legacyFile.writeAsStringSync(
        jsonEncode([
          {'t': 'tr', 'p': '/music/a.mp3', 'o': 1},
          {'t': 'v', 'p': '/music/b.mp4', 'o': 0},
        ]),
      );
      final (items, originalIndices) = QueueController.debugReadLatestQueueFile(legacyFile.path);
      expect(items, [track('a'), Video.explicit('/music/b.mp4')]);
      expect(items[1], isA<Video>());
      expect(originalIndices, [1, 0]);

      legacyFile.writeAsStringSync(
        jsonEncode([
          {'t': 'tr', 'p': '/music/a.mp3', 'o': 1},
          {'t': 'tr', 'p': '/music/b.mp3'},
        ]),
      );
      expect(QueueController.debugReadLatestQueueFile(legacyFile.path).$2, isNull);
    });
  });

  group('saving the player queue', () {
    test('an edit from the same source updates the latest queue in place', () async {
      await addQueue(QueueSource.playlist('mix'), 1000, [track('a'), track('b')]);
      await QueueController.inst.updateLatestQueue([track('a'), track('b'), track('c')], originalIndices: null, source: QueueSource.playlist('mix'));
      await waitForQueueFile(1000, 3);
      expect(queues().keys, [1000]);
      expect(queues()[1000]!.tracks, [track('a'), track('b'), track('c')]);
    });

    test('a queue from another source is added next to the latest one', () async {
      await addQueue(QueueSource.playlist('mix'), 1000, [track('a'), track('b')]);
      await QueueController.inst.updateLatestQueue([track('c')], originalIndices: null, source: QueueSource.playlist('other'));
      await waitUntil(() => queues().length == 2);
      final newDate = queues().keys.firstWhere((date) => date != 1000);
      await waitForQueueFile(newDate, 1);
      expect(queues()[newDate]!.source, QueueSource.playlist('other'));
      expect(queues()[1000]!.tracks, [track('a'), track('b')]);
      expect(QueueController.inst.totalQueuesCount.value, 2);
    });

    test('replaying the latest queue from the queues page keeps a single entry', () async {
      await addQueue(QueueSource.playlist('mix'), 1000, [track('a'), track('b')]);
      final previousBytes = readBytes(queuePath(1000));
      await QueueController.inst.updateLatestQueue([track('a'), track('b')], originalIndices: null, source: QueueSource.queuePageByName('1000'));
      await waitUntil(() {
        final bytes = readBytes(queuePath(1000));
        return bytes != null && !listEquals(bytes, previousBytes);
      });
      expect(queues().keys, [1000]);
      expect(queues()[1000]!.tracks, [track('a'), track('b')]);
    });

    test('a restored queue edited after a restart is added once, then updated in place', () async {
      await addQueue(QueueSource.playlist('mix'), 1000, [track('a'), track('b')]);
      await QueueController.inst.updateLatestQueue([track('a'), track('b'), track('c')], originalIndices: null, source: QueueSource.playerQueue);
      await waitUntil(() => queues().length == 2);
      final playerQueueDate = queues().keys.firstWhere((date) => date != 1000);
      await waitForQueueFile(playerQueueDate, 3);

      await QueueController.inst.updateLatestQueue([track('a'), track('b'), track('c'), track('d')], originalIndices: null, source: QueueSource.playerQueue);
      await waitForQueueFile(playerQueueDate, 4);
      expect(queues().length, 2);
      expect(queues()[playerQueueDate]!.tracks, [track('a'), track('b'), track('c'), track('d')]);
      expect(queues()[1000]!.tracks, [track('a'), track('b')]);
    });

    test('stale original indices keep every item, misplaced ones go last', () async {
      final items = [track('a'), track('b'), track('c'), track('d')];
      await QueueController.inst.updateLatestQueue(items, originalIndices: [1, 1, 0], source: QueueSource.playlist('stale'));
      await waitUntil(() => queues().isNotEmpty);
      final savedQueue = queues().values.single;
      expect(savedQueue.tracks, [track('c'), track('a'), track('b'), track('d')]);
      await waitForQueueFile(savedQueue.date, 4);
    });
  });

  group('queues not loaded at startup', () {
    Future<void> addQueues(int count) async {
      for (int i = 1; i <= count; i++) {
        await addQueue(QueueSource.playlist('p$i'), i * 1000, [Track.explicit('/old/dir/song$i.mp3'), Track.explicit('/kept/song$i.mp3')]);
      }
      await QueueController.inst.prepareAllQueuesFile();
    }

    Future<Map<int, Queue>> reloadAllQueues() async {
      await QueueController.inst.prepareAllQueuesFile();
      await QueueController.inst.loadAllQueues();
      return queues();
    }

    String normalizedPath(Track track) => track.path.replaceAll('\\', '/');

    test('only the newest 20 queues load, the count includes the rest', () async {
      await addQueues(25);
      expect(queues().length, 20);
      expect(queues().keys, everyElement(greaterThan(5000)));
      expect(QueueController.inst.totalQueuesCount.value, 25);
    });

    test('moving a directory updates the queues that were not loaded yet', () async {
      await addQueues(25);
      await QueueController.inst.replaceTracksDirectoryInQueues('/old/dir/', '/new/dir/');
      final reloaded = await reloadAllQueues();
      expect(reloaded.length, 25);
      for (int i = 1; i <= 25; i++) {
        final paths = reloaded[i * 1000]!.tracks.map(normalizedPath).toList();
        expect(paths, ['/new/dir/song$i.mp3', '/kept/song$i.mp3'], reason: 'queue $i');
      }
    });

    test('renaming a track updates the queues that were not loaded yet', () async {
      await addQueues(25);
      await QueueController.inst.replaceTrackInAllQueues({Track.explicit('/old/dir/song3.mp3'): Track.explicit('/new/dir/song3.mp3')});
      final reloaded = await reloadAllQueues();
      expect(reloaded[3000]!.tracks, [Track.explicit('/new/dir/song3.mp3'), Track.explicit('/kept/song3.mp3')]);
      expect(reloaded[4000]!.tracks, [Track.explicit('/old/dir/song4.mp3'), Track.explicit('/kept/song4.mp3')]);
    });

    test('renaming tracks replaces each one by its own new track, swapped ones included', () async {
      await addQueue(QueueSource.playlist('mix'), 1000, [track('a'), track('b'), track('a'), track('c')]);
      await addQueue(QueueSource.playlist('other'), 2000, [track('c'), track('e')]);
      await addQueue(QueueSource.playlist('untouched'), 3000, [track('e')]);
      final untouchedBytes = readBytes(queuePath(3000));
      await QueueController.inst.replaceTrackInAllQueues({track('a'): track('b'), track('b'): track('a'), track('c'): track('d')});
      final reloaded = await reloadAllQueues();
      expect(reloaded[1000]!.tracks, [track('b'), track('a'), track('b'), track('d')]);
      expect(reloaded[2000]!.tracks, [track('d'), track('e')]);
      expect(readBytes(queuePath(3000)), untouchedBytes);
    });

    test('removing queues that were not loaded yet deletes them and updates the count', () async {
      await addQueues(25);
      await QueueController.inst.removeQueues([1000, 2000, 25000]);
      expect(QueueController.inst.totalQueuesCount.value, 22);
      expect(File(queuePath(1000)).existsSync(), isFalse);
      expect(File(queuePath(2000)).existsSync(), isFalse);
      expect(File(queuePath(25000)).existsSync(), isFalse);

      await QueueController.inst.loadAllQueues();
      expect(queues().length, 22);
      expect(queues().keys, isNot(anyOf(contains(1000), contains(2000), contains(25000))));
      expect(QueueController.inst.totalQueuesCount.value, 22);
    });

    test('queues removed while the rest are still loading stay removed', () async {
      await addQueues(25);
      final loading = QueueController.inst.loadAllQueues();
      await Future<void>.microtask(() {});
      // -- blocks this isolate while the read finishes, so its result is handled after the removal
      sleep(const Duration(milliseconds: 300));
      final removing = QueueController.inst.removeQueues([5000, 4000]);
      await loading;
      await removing;
      expect(queues().keys, isNot(anyOf(contains(5000), contains(4000))));
      expect(queues().length, 23);
      expect(QueueController.inst.totalQueuesCount.value, 23);
      expect(File(queuePath(5000)).existsSync(), isFalse);
    });
  });

  group('latest played per source', () {
    // -- shared with the manager, closing it per test makes the manager reopen a handle the teardown can't delete
    late DBWrapperAsync db;
    setUpAll(() => db = DBWrapper.openFromInfo(fileInfo: AppPaths.LATEST_PLAYED_FOR_SOURCE, config: const DBConfig(createIfNotExist: true)));
    tearDownAll(() => db.close());

    Track libraryTrack(String name, String album, String albumArtist) {
      final path = '/music/$name.mp3';
      Indexer.inst.allTracksMappedByPath[path] = kDummyExtendedTrack.copyWith(
        path: path,
        originalAlbum: album,
        albumsList: [album],
        albumArtist: albumArtist,
        albumsIdentifiersWrappers: AlbumIdentifierWrapper.fromAlbums(albums: [album], albumArtist: albumArtist, year: '1992', mbAlbumId: '', mbAlbumArtistId: ''),
        generatePathHash: false,
      );
      return Track.explicit(path);
    }

    QueueSource albumSource(String album, String albumArtist) {
      final identifier = AlbumIdentifierWrapper(album: album, albumArtist: albumArtist, year: '', mbAlbumId: '', mbAlbumArtistId: '');
      return QueueSource.album(identifier, null);
    }

    test('album sources saved against cleaned up album names move to the real album', () async {
      final live = libraryTrack('live', 'AC/DC: Live!', 'AC/DC');
      final olderLive = libraryTrack('older_live', 'Up/Down: Live!', 'Band');
      final underscored = libraryTrack('underscored', 'snake_case', 'Band');
      Indexer.inst.mainMapsGroup.fillAll([live, olderLive, underscored], (tr) => tr.toTrackExt(), settings.albumIdentifiers.value);

      final cleanedUpSource = albumSource('AC_DC_ Live_', 'AC_DC');
      final slashesCleanedUpSource = albumSource('Up_Down: Live!', 'Band');
      final underscoredSource = albumSource('snake_case', 'Band');
      final savedItems = {cleanedUpSource: (live, 1000), slashesCleanedUpSource: (olderLive, 2000), underscoredSource: (underscored, 3000)};
      for (final MapEntry(key: source, value: (item, mt)) in savedItems.entries) {
        await db.put(source.toDbKey(), {'p': item.toJson(), 't': item.playableType.jsonKey, '_mt': mt});
      }

      final manager = QueueController.latestPlayedForSourceManager;
      await manager.prepareAll();
      final liveSource = albumSource('AC/DC: Live!', 'AC/DC');
      final olderLiveSource = albumSource('Up/Down: Live!', 'Band');
      expect(manager.map.value[liveSource], live);
      expect(manager.map.value[olderLiveSource], olderLive);
      expect(manager.map.value[underscoredSource], underscored);
      expect(manager.map.value.keys, isNot(anyOf(contains(cleanedUpSource), contains(slashesCleanedUpSource))));
      expect(manager.latestPlayedTime(liveSource), 1000);

      final cleanedUpKey = cleanedUpSource.toDbKey();
      for (int i = 0; i < 300 && await db.containsKey(cleanedUpKey); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      final keys = await db.loadAllKeysResult();
      expect(keys, unorderedEquals([liveSource.toDbKey(), olderLiveSource.toDbKey(), underscoredSource.toDbKey()]));
    });

    test('album sources saved against untrimmed album fields move to the real album, exact ones stay', () async {
      Indexer.inst.allTracksMappedByPath.clear();
      final spaced = libraryTrack('spaced', 'Spaced Out', 'Band');
      final padded = libraryTrack('padded', 'Padded', 'Band ');
      Indexer.inst.mainMapsGroup.fillAll([spaced, padded], (tr) => tr.toTrackExt(), settings.albumIdentifiers.value);

      final untrimmedSource = albumSource(' Spaced  Out', 'Band\t');
      final paddedSource = albumSource('Padded', 'Band ');
      final savedItems = {untrimmedSource: (spaced, 1000), paddedSource: (padded, 2000)};
      for (final MapEntry(key: source, value: (item, mt)) in savedItems.entries) {
        await db.put(source.toDbKey(), {'p': item.toJson(), 't': item.playableType.jsonKey, '_mt': mt});
      }

      final manager = QueueController.latestPlayedForSourceManager;
      await manager.prepareAll();
      final spacedSource = albumSource('Spaced Out', 'Band');
      expect(manager.map.value[spacedSource], spaced);
      expect(manager.map.value[paddedSource], padded);
      expect(manager.map.value.keys, isNot(contains(untrimmedSource)));
      expect(manager.latestPlayedTime(spacedSource), 1000);
      expect(manager.latestPlayedTime(paddedSource), 2000);

      final untrimmedKey = untrimmedSource.toDbKey();
      for (int i = 0; i < 300 && await db.containsKey(untrimmedKey); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      final keys = await db.loadAllKeysResult();
      expect(keys, containsAll([spacedSource.toDbKey(), paddedSource.toDbKey()]));
      expect(keys, isNot(contains(untrimmedKey)));
    });
  });
}
