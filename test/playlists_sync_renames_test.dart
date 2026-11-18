// by claude
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:playlist_manager/playlist_manager.dart';

import 'package:namida/class/sort_chain.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/smart_playlists/smart_playlists_controller.dart';
import 'package:namida/controller/sync_manager/sync_manager.dart';
import 'package:namida/core/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('namida_playlists_sync_renames_test');
    AppDirs.INTERNAL_STORAGE = dir.path;
    AppDirs.USER_DATA = '${dir.path}${Platform.pathSeparator}';
    Directory(AppDirs.M3UBackup).createSync(recursive: true);
    Directory(AppDirs.M3UPlaylists).createSync(recursive: true);
    Directory(AppDirs.SMART_PLAYLISTS_ARTWORKS).createSync(recursive: true);
  });
  tearDownAll(() {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {} // -- dbs stay open
  });

  group('sender', () {
    GeneralPlaylist<String, String> playlist(String name, {required int creationDate, required int modifiedDate, String? m3uPath}) => GeneralPlaylist(
      name: name,
      tracks: [],
      creationDate: creationDate,
      modifiedDate: modifiedDate,
      comment: '',
      moods: [],
      isFav: false,
      m3uPath: m3uPath,
      sortsType: null,
      sortReverse: false,
    );

    Map<String, GeneralPlaylist<String, String>> localOf(List<GeneralPlaylist<String, String>> playlists) => {for (final pl in playlists) pl.name: pl};

    PlaylistManifest manifest(String name, {required int? creationDate, required int modifiedDate}) => PlaylistManifest(
      name: name,
      modifiedDate: modifiedDate,
      creationDate: creationDate,
    );

    ({List<GeneralPlaylist<String, String>> playlists, PlaylistsSyncExtras extras}) compute(
      List<GeneralPlaylist<String, String>> local,
      List<PlaylistManifest> available, {
      List<String>? localOrder,
      int localOrderModifiedDate = 0,
      int? otherOrderModifiedDate = 0,
    }) => PlaylistsManifestResponseMessageUtils.computeRequiredPlaylists(
      localPlaylists: localOf(local),
      available: available,
      localOrder: localOrder,
      localOrderModifiedDate: localOrderModifiedDate,
      otherOrderModifiedDate: otherOrderModifiedDate,
    );

    test('a playlist renamed here goes with its old name', () {
      final res = compute(
        [playlist('new', creationDate: 1, modifiedDate: 200)],
        [manifest('old', creationDate: 1, modifiedDate: 100)],
      );
      expect(res.playlists.map((e) => e.name), ['new']);
      expect(res.extras.renamedFromByName, {'new': 'old'});
    });

    test('a playlist renamed there after our last change is not sent back', () {
      final res = compute(
        [playlist('old', creationDate: 1, modifiedDate: 100)],
        [manifest('new', creationDate: 1, modifiedDate: 200)],
      );
      expect(res.playlists, isEmpty);
      expect(res.extras.renamedFromByName, isEmpty);
    });

    test('no rename when we still have their name, the date is shared there, or it is unknown', () {
      final stillHaveTheirName = compute(
        [playlist('a', creationDate: 2, modifiedDate: 100), playlist('b', creationDate: 1, modifiedDate: 100)],
        [manifest('a', creationDate: 1, modifiedDate: 100)],
      );
      expect(stillHaveTheirName.playlists.map((e) => e.name), ['b']);
      expect(stillHaveTheirName.extras.renamedFromByName, isEmpty);

      final sharedThere = compute(
        [playlist('x', creationDate: 1, modifiedDate: 100)],
        [manifest('a', creationDate: 1, modifiedDate: 50), manifest('b', creationDate: 1, modifiedDate: 50)],
      );
      expect(sharedThere.playlists.map((e) => e.name), ['x']);
      expect(sharedThere.extras.renamedFromByName, isEmpty);

      final oldPeer = compute(
        [playlist('new', creationDate: 1, modifiedDate: 200)],
        [manifest('old', creationDate: null, modifiedDate: 100)],
      );
      expect(oldPeer.playlists.map((e) => e.name), ['new']);
      expect(oldPeer.extras.renamedFromByName, isEmpty);
    });

    test('m3u playlists are matched by name only', () {
      final res = compute(
        [playlist('new', creationDate: 1, modifiedDate: 200, m3uPath: 'x.m3u')],
        [manifest('old', creationDate: 1, modifiedDate: 100)],
      );
      expect(res.playlists.map((e) => e.name), ['new']);
      expect(res.extras.renamedFromByName, isEmpty);
    });

    test('the order goes only when ours is newer, even with no playlists to send', () {
      final ours = compute([], [], localOrder: ['b', 'a'], localOrderModifiedDate: 300, otherOrderModifiedDate: 100);
      expect(ours.extras.order, ['b', 'a']);

      final theirs = compute([], [], localOrder: ['b', 'a'], localOrderModifiedDate: 100, otherOrderModifiedDate: 300);
      expect(theirs.extras.order, isNull);

      final neverReordered = compute([], [], localOrder: ['b', 'a'], localOrderModifiedDate: 0, otherOrderModifiedDate: 0);
      expect(neverReordered.extras.order, isNull);
    });

    test('the order never goes when they do not take it', () {
      final res = compute([], [], localOrder: ['b', 'a'], localOrderModifiedDate: 300, otherOrderModifiedDate: null);
      expect(res.extras.order, isNull);
    });

    test('extras survive the message encoding', () {
      const extras = PlaylistsSyncExtras(renamedFromByName: {'new': 'old'}, order: ['b', 'a'], orderModifiedDate: 300);
      final decoded = PlaylistsSyncExtras.fromMap(extras.toMap());
      expect(decoded.renamedFromByName, {'new': 'old'});
      expect(decoded.order, ['b', 'a']);
      expect(decoded.orderModifiedDate, 300);

      final empty = PlaylistsSyncExtras.fromMap(const {});
      expect(empty.renamedFromByName, isEmpty);
      expect(empty.order, isNull);
    });

    test('a manifest tells a never reordered order apart from one they do not take', () {
      int? roundTrip(int? orderModifiedDate) {
        final map = PlaylistsManifestResponseMessageUtils.encodeToMap(const [], orderModifiedDate, null);
        return PlaylistsManifestResponseMessageUtils.orderModifiedDateFromMap(map);
      }

      expect(roundTrip(null), isNull);
      expect(roundTrip(0), 0);
      expect(roundTrip(300), 300);
    });
  });

  group('receiver', () {
    final controller = PlaylistController.inst;
    tearDown(() async {
      for (final name in controller.playlistsMap.value.keys.toList()) {
        await controller.removePlaylist(controller.playlistsMap.value[name]!);
      }
    });

    Future<LocalPlaylist> addPlaylist(String name) async {
      await controller.addNewPlaylist(name);
      return controller.playlistsMap.value[name]!;
    }

    Future<int> receive(List<LocalPlaylist> playlists, PlaylistsSyncExtras extras) => extras.importInto(controller, playlists, controller.importSyncedPlaylists);

    test('a playlist renamed there is renamed here, no copy is left with the old name', () async {
      final local = await addPlaylist('sync old');
      final incoming = local.copyWith(name: 'sync new', modifiedDate: local.modifiedDate + 1000, comment: 'edited there');
      final importedCount = await receive([incoming], const PlaylistsSyncExtras(renamedFromByName: {'sync new': 'sync old'}, order: null, orderModifiedDate: 0));

      expect(importedCount, 1);
      expect(controller.playlistsMap.value.containsKey('sync old'), isFalse);
      final renamed = controller.playlistsMap.value['sync new']!;
      expect(renamed.creationDate, local.creationDate);
      expect(renamed.comment, 'edited there');
      expect(controller.getFileForPlaylist('sync old').existsSync(), isFalse);
      expect(controller.getFileForPlaylist('sync new').existsSync(), isTrue);
    });

    test('a rename older than our last change is dropped, ours goes back to them later', () async {
      final local = await addPlaylist('kept old');
      final incoming = local.copyWith(name: 'stale new', modifiedDate: local.modifiedDate - 1000);
      final importedCount = await receive([incoming], const PlaylistsSyncExtras(renamedFromByName: {'stale new': 'kept old'}, order: null, orderModifiedDate: 0));

      expect(importedCount, 0);
      expect(controller.playlistsMap.value.keys, contains('kept old'));
      expect(controller.playlistsMap.value.containsKey('stale new'), isFalse);
    });

    test('a different playlist with the old name is never renamed', () async {
      final local = await addPlaylist('other old');
      final incoming = local.copyWith(name: 'other new', creationDate: local.creationDate + 1, modifiedDate: local.modifiedDate + 1000);
      await receive([incoming], const PlaylistsSyncExtras(renamedFromByName: {'other new': 'other old'}, order: null, orderModifiedDate: 0));

      expect(controller.playlistsMap.value.keys, containsAll(['other old', 'other new']));
    });

    test('the custom order is taken only if newer, names still on their way keep their place', () async {
      final playlistA = await addPlaylist('order a');
      await addPlaylist('order b');
      await addPlaylist('order local only');
      controller.ensureCustomOrderValid();
      final localModifiedDate = controller.customOrderModifiedDate;

      final didImport = controller.importCustomOrderIfNewer(['order b', 'order coming', 'order a'], localModifiedDate + 1000);
      expect(didImport, isTrue);
      expect(controller.customIndicesOrderRx.value, ['order b', 'order coming', 'order a', 'order local only']);

      final didImportOlder = controller.importCustomOrderIfNewer(['order a', 'order b'], localModifiedDate + 500);
      expect(didImportOlder, isFalse);
      expect(controller.customIndicesOrderRx.value!.first, 'order b');

      final arriving = playlistA.copyWith(name: 'order coming', creationDate: playlistA.creationDate + 1);
      await receive([arriving], const PlaylistsSyncExtras(renamedFromByName: {}, order: null, orderModifiedDate: 0));
      expect(controller.customIndicesOrderRx.value, ['order b', 'order coming', 'order a', 'order local only']);
    });
  });

  group('smart playlists', () {
    final controller = SmartPlaylistsController.inst;

    SmartPlaylist smartPlaylist(String name, {required DateTime creationDate, int modifiedDate = 0}) => SmartPlaylist(
      name: name,
      creationDate: creationDate,
      joiner: SmartJoiner.and,
      sorting: const SortChain([]),
      moods: [],
      ruleGroups: [],
      limit: null,
      modifiedDate: modifiedDate,
    );

    List<String> listedKeys() => controller.smartPlaylistsList.value.map((e) => e.value.key).toList();

    test('a smart playlist renamed there is renamed here and keeps its place', () async {
      final creationDate = DateTime(2026, 1, 1);
      await controller.create(smartPlaylist('smart first', creationDate: DateTime(2026, 1, 2)));
      await controller.create(smartPlaylist('smart old', creationDate: creationDate));
      await controller.create(smartPlaylist('smart last', creationDate: DateTime(2026, 1, 3)));
      final local = controller.getPlaylistForKey('smart old')!.value;

      final incoming = smartPlaylist('smart new', creationDate: creationDate, modifiedDate: local.modifiedDate + 1000);
      final importedCount = await controller.import([incoming]);

      expect(importedCount, 1);
      expect(controller.getPlaylistForKey('smart old'), isNull);
      expect(controller.getPlaylistForKey('smart new'), isNotNull);
      final keys = listedKeys();
      expect(keys.indexOf('smart new'), keys.indexOf('smart first') + 1);
    });

    test('no rename when the sender still has the old name, or ours is newer', () async {
      final creationDate = DateTime(2026, 2, 1);
      await controller.create(smartPlaylist('smart kept', creationDate: creationDate));
      final local = controller.getPlaylistForKey('smart kept')!.value;

      await controller.import([
        smartPlaylist('smart kept', creationDate: creationDate, modifiedDate: local.modifiedDate),
        smartPlaylist('smart copy', creationDate: creationDate, modifiedDate: local.modifiedDate + 1000),
      ]);
      expect(controller.getPlaylistForKey('smart kept'), isNotNull);
      expect(controller.getPlaylistForKey('smart copy'), isNotNull);

      final olderCreationDate = DateTime(2026, 3, 1);
      await controller.create(smartPlaylist('smart newer here', creationDate: olderCreationDate));
      await controller.import([smartPlaylist('smart stale rename', creationDate: olderCreationDate, modifiedDate: 1)]);
      expect(controller.getPlaylistForKey('smart newer here'), isNotNull);
      expect(controller.getPlaylistForKey('smart stale rename'), isNull);
    });
  });
}
