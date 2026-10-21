import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:basic_audio_handler/basic_audio_handler.dart';
import 'package:history_manager/history_manager.dart';
import 'package:nampack/nampack.dart';

import 'package:namida/base/settings_file_writer.dart';
import 'package:namida/class/count_per_row.dart';
import 'package:namida/class/player_config_preset.dart';
import 'package:namida/class/sort_chain.dart';
import 'package:namida/class/named_presets.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/sync_manager/sync_manager.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';

void main() {
  late Directory dir;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('namida_settings_test');
    AppDirs.USER_DATA = '${dir.path}${Platform.pathSeparator}';
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  Future<void> loadSync(Map<String, dynamic>? fileContent) async {
    final file = File(AppPaths.SETTINGS_SYNC);
    if (fileContent == null) {
      file.deleteIfExistsSync();
    } else {
      file.writeAsStringSync(jsonEncode(fileContent));
    }
    await settings.sync.prepareSettingsFile();
  }

  Map<String, dynamic> syncRaw() => settings.sync.buildJson();

  Future<void> flushWrites() => Future.delayed(const Duration(milliseconds: 2300));

  Future<Map<String, dynamic>> readSyncFile() async {
    await flushWrites();
    final content = File(AppPaths.SETTINGS_SYNC).readAsStringSync();
    return jsonDecode(content) as Map<String, dynamic>;
  }

  final legacySyncFile = <String, dynamic>{
    'id': 'dev-1',
    'allowedServerIds': ['srv-1'],
    'manualServerAddresses': {'srv-1': '10.0.0.2'},
    'allowedDeviceIds': [],
    'blockedClientIds': [],
    'deviceIdNames': {'srv-1': 'Laptop'},
    'selectedSyncItems': ['history', 'playlists'],
    'autoReconnect': true,
    'autoSyncIntervalMinutes': 60,
    'serverWasRunning': false,
  };

  test('missing file falls back to defaults', () async {
    await loadSync(null);
    expect(settings.sync.uniqueId.value, null);
    expect(settings.sync.autoReconnect.userValue, null);
    expect(settings.sync.autoReconnect.value, true);
    expect(settings.sync.syncItems.value, SyncDataItem.essentialsSet);
    expect(syncRaw(), {'_v': 2});
  });

  test('legacy file loads, default-equal values are stripped', () async {
    await loadSync(legacySyncFile);
    expect(settings.sync.uniqueId.value, 'dev-1');
    expect(settings.sync.allowedServerIds.value, {'srv-1'});
    expect(settings.sync.manualServerAddresses.value, {'srv-1': '10.0.0.2'});
    expect(settings.sync.deviceIdNames.value, {'srv-1': 'Laptop'});
    expect(settings.sync.syncItems.value, {SyncDataItem.history, SyncDataItem.playlists});
    expect(settings.sync.autoSyncIntervalMinutes.value, 60);

    expect(settings.sync.allowedDeviceIds.userValue, null);
    expect(settings.sync.blockedClientIds.userValue, null);
    expect(settings.sync.autoReconnect.userValue, null);
    expect(settings.sync.serverWasRunning.userValue, null);

    final raw = syncRaw();
    expect(raw['_v'], 2);
    expect(raw.containsKey('_legacy'), false);
    expect(raw.containsKey('allowedDeviceIds'), false);
    expect(raw.containsKey('autoReconnect'), false);
    expect(raw['selectedSyncItems'], ['history', 'playlists']);
  });

  test('corrupted values fall back per key, unknown enum names are dropped', () async {
    await loadSync({
      'id': 5,
      'autoReconnect': 'x',
      'selectedSyncItems': ['history', 'nope'],
      'deviceIdNames': ['a'],
    });
    expect(settings.sync.uniqueId.value, null);
    expect(settings.sync.autoReconnect.value, true);
    expect(settings.sync.syncItems.value, {SyncDataItem.history});
    expect(settings.sync.deviceIdNames.userValue, null);
  });

  test('save stores only overrides, reset removes, unknown keys kept', () async {
    await loadSync({'_v': 2, 'unknown': 1});
    settings.sync.autoReconnect.save(false);
    settings.sync.uniqueId.save('dev-2');
    expect(syncRaw(), {'_v': 2, 'unknown': 1, 'autoReconnect': false, 'id': 'dev-2'});

    settings.sync.autoReconnect.reset();
    expect(settings.sync.autoReconnect.value, true);
    expect(syncRaw(), {'_v': 2, 'unknown': 1, 'id': 'dev-2'});
    expect(await readSyncFile(), {'_v': 2, 'unknown': 1, 'id': 'dev-2'});
  });

  test('update copies the default instead of mutating it', () async {
    await loadSync(null);
    final essentialsBefore = {...SyncDataItem.essentialsSet};
    settings.sync.syncItems.update((items) => items.remove(SyncDataItem.history));
    expect(SyncDataItem.essentialsSet, essentialsBefore);
    expect(settings.sync.syncItems.value, essentialsBefore..remove(SyncDataItem.history));
    expect(settings.sync.syncItems.value.contains(SyncDataItem.history), false);

    settings.sync.updateDeviceName('a', 'A');
    settings.sync.updateDeviceName('a', 'A');
    expect(settings.sync.deviceIdNames.value, {'a': 'A'});
    expect(syncRaw()['deviceIdNames'], {'a': 'A'});
  });

  test('collections are read-only outside update', () async {
    await loadSync({
      '_v': 2,
      'allowedServerIds': ['srv-1'],
    });
    expect(() => settings.sync.allowedServerIds.value.toSet().add('x'), returnsNormally);
    expect(() => (settings.sync.allowedServerIds.value as Set<String>).add('x'), throwsUnsupportedError);
    expect(() => (settings.sync.deviceIdNames.value as Map<String, String>)['a'] = 'A', throwsUnsupportedError);
    expect(() => (settings.party.recentRooms.value as List).add(<String, dynamic>{}), throwsUnsupportedError);
    expect(settings.sync.allowedServerIds.value, {'srv-1'});
  });

  test('transaction writes once at the end', () async {
    await flushWrites();
    await loadSync(null);
    final file = File(AppPaths.SETTINGS_SYNC);
    file.deleteIfExistsSync();
    settings.sync.transaction(() {
      settings.sync.allowedServerIds.update((ids) => ids.add('srv-9'));
      settings.sync.manualServerAddresses.update((addresses) => addresses['srv-9'] = '10.0.0.9');
      expect(file.existsSync(), false);
    });
    final written = await readSyncFile();
    expect(written['allowedServerIds'], ['srv-9']);
    expect(written['manualServerAddresses'], {'srv-9': '10.0.0.9'});
  });

  test('non-syncable file tracks no modification times and ignores deltas', () async {
    await loadSync(null);
    settings.sync.autoSyncIntervalMinutes.save(30);
    expect(syncRaw().containsKey('_m'), false);
    expect(settings.sync.syncDelta(0), null);
    settings.sync.applySyncDelta({
      'v': {'autoSyncIntervalMinutes': 90},
      'm': {'autoSyncIntervalMinutes': DateTime.now().millisecondsSinceEpoch + 1000},
    });
    expect(settings.sync.autoSyncIntervalMinutes.value, 30);
  });

  test('redactedJson masks sensitive keys without touching the stored map', () async {
    await loadSync(legacySyncFile);
    final redacted = settings.sync.redactedJson();
    expect(redacted['id'], SettingsFileWriter.kRedactedValue);
    expect(redacted['deviceIdNames'], SettingsFileWriter.kRedactedValue);
    expect(redacted['autoSyncIntervalMinutes'], 60);
    expect(syncRaw()['id'], 'dev-1');
  });

  test('tutorial: legacy llpfs flips to llpfsSeen', () async {
    final file = File(AppPaths.SETTINGS_TUTORIAL);
    file.writeAsStringSync(jsonEncode({'llpfs': false}));
    await settings.tutorial.prepareSettingsFile();
    expect(settings.tutorial.lyricsFullscreenTipSeen.value, true);
    expect(settings.tutorial.buildJson(), {'_v': 2, 'llpfsSeen': true});

    await flushWrites();
    file.writeAsStringSync(jsonEncode({'llpfs': true}));
    await settings.tutorial.prepareSettingsFile();
    expect(settings.tutorial.lyricsFullscreenTipSeen.userValue, null);
    expect(settings.tutorial.buildJson(), {'_v': 2});
  });

  test('syncable file: delta carries changed keys, newest wins, reset propagates', () async {
    File(AppPaths.SETTINGS_PLAYER).writeAsStringSync(jsonEncode({'_v': 2}));
    await settings.player.prepareSettingsFile();
    expect(settings.player.syncDelta(0), null);

    settings.player.volume.save(0.5);
    settings.player.speed.save(1.5);
    final delta = settings.player.syncDelta(0)!;
    expect(delta['v'], {'speed': 1.5});
    expect((delta['m'] as Map).keys, ['speed']);
    final speedMS = delta['m']['speed'] as int;
    expect(settings.player.syncDelta(speedMS), null);

    settings.player.applySyncDelta({
      'v': {'speed': 2.0},
      'm': {'speed': speedMS - 1},
    });
    expect(settings.player.speed.value, 1.5);

    settings.player.applySyncDelta({
      'v': {'speed': 2.0, 'pitch': 0.8},
      'm': {'speed': speedMS + 1, 'pitch': speedMS + 1},
    });
    expect(settings.player.speed.value, 2.0);
    expect(settings.player.pitch.value, 0.8);
    expect(settings.player.buildJson()['speed'], 2.0);

    settings.player.applySyncDelta({
      'v': {'volume': 0.2, '_v': 9},
      'm': {'volume': speedMS + 1, '_v': speedMS + 1},
    });
    expect(settings.player.volume.value, 0.5);
    expect(settings.player.buildJson()['_v'], 2);

    settings.player.applySyncDelta({
      'v': {},
      'm': {'speed': speedMS + 2},
    });
    expect(settings.player.speed.userValue, null);
    expect(settings.player.speed.value, 1.0);
    expect(settings.player.buildJson().containsKey('speed'), false);
    expect(settings.player.syncDelta(speedMS + 1)!['m'], {'speed': speedMS + 2});
  });

  test('saving the current value writes nothing, saving the default removes the override', () async {
    File(AppPaths.SETTINGS_PLAYER).writeAsStringSync(jsonEncode({'_v': 2}));
    await settings.player.prepareSettingsFile();
    settings.player.speed.save(1.0);
    expect(settings.player.speed.userValue, null);
    expect(settings.player.buildJson(), {'_v': 2});

    settings.player.speed.save(1.5);
    final Map modified = settings.player.buildJson()['_m'];
    modified['speed'] = 5;
    settings.player.speed.save(1.5);
    expect(modified['speed'], 5);

    settings.player.speed.save(1.0);
    expect(settings.player.speed.userValue, null);
    expect(settings.player.buildJson().containsKey('speed'), false);

    await loadSync(null);
    settings.sync.syncItems.update((items) => items.remove(SyncDataItem.history));
    settings.sync.syncItems.update((items) => items.add(SyncDataItem.history));
    expect(settings.sync.syncItems.userValue, null);
    expect(syncRaw().containsKey('selectedSyncItems'), false);
  });

  test('legacy file is fully migrated and rewritten on first load', () async {
    await flushWrites();
    final file = File(AppPaths.SETTINGS_PLAYER);
    file.writeAsStringSync(jsonEncode({'volume': 1.0, 'speed': 1.5, 'someRemovedKey': true}));
    await settings.player.prepareSettingsFile();
    final migrated = {
      '_v': 2,
      'speed': 1.5,
      '_m': {'speed': 1},
    };
    expect(settings.player.buildJson(), migrated);
    await flushWrites();
    expect(jsonDecode(file.readAsStringSync()), migrated);
  });

  test('map keys store only entries that differ from the default', () async {
    File(AppPaths.SETTINGS_PLAYER).writeAsStringSync(jsonEncode({'_v': 2}));
    await settings.player.prepareSettingsFile();
    settings.player.onInterrupted.update((actions) => actions[InterruptionType.shouldDuck] = InterruptionAction.pause);
    expect(settings.player.buildJson()['onInterrupted'], {'shouldDuck': 'pause'});
    expect(settings.player.onInterrupted.value[InterruptionType.unknown], InterruptionAction.pause);

    settings.player.onInterrupted.update((actions) => actions[InterruptionType.shouldDuck] = InterruptionAction.duckAudio);
    expect(settings.player.buildJson().containsKey('onInterrupted'), false);

    File(AppPaths.SETTINGS_PLAYER).writeAsStringSync(
      jsonEncode({
        '_v': 2,
        'onInterrupted': {'shouldPause': 'pause', 'unknown': 'doNothing'},
      }),
    );
    await settings.player.prepareSettingsFile();
    expect(settings.player.buildJson()['onInterrupted'], {'unknown': 'doNothing'});
    expect(settings.player.onInterrupted.value.length, 3);
  });

  test('customized enum lists pick up values added to the enum later', () async {
    final file = File(AppPaths.SETTINGS_YOUTUBE);
    const added = HomePageItems.lostMemories;
    final excludedNames = [
      for (final e in HomePageItems.values)
        if (e != HomePageItems.mixes && e != added) e.name,
    ];
    file.writeAsStringSync(
      jsonEncode({
        '_v': 2,
        'ytHomePageItems': ['mixes'],
        '_x': {'ytHomePageItems': excludedNames},
      }),
    );
    await settings.youtube.prepareSettingsFile();
    expect(settings.youtube.ytHomePageItems.value, [HomePageItems.mixes, added]);
    expect(settings.youtube.buildJson()['_x'], {'ytHomePageItems': excludedNames});
    expect(settings.youtube.buildJson().containsKey('_m'), false);

    settings.youtube.ytHomePageItems.update((items) => items.remove(HomePageItems.mixes));
    expect(settings.youtube.buildJson()['_x']['ytHomePageItems'], contains(HomePageItems.mixes.name));
    settings.youtube.ytHomePageItems.reset();
    expect(settings.youtube.buildJson().containsKey('_x'), false);

    await flushWrites();
    file.writeAsStringSync(
      jsonEncode({
        'ytHomePageItems': ['mixes'],
      }),
    );
    await settings.youtube.prepareSettingsFile();
    expect(settings.youtube.ytHomePageItems.value, [HomePageItems.mixes]);
    expect(settings.youtube.buildJson()['_x'], {
      'ytHomePageItems': [
        for (final e in HomePageItems.values)
          if (e != HomePageItems.mixes) e.name,
      ],
    });
  });

  test('int stored for a double key is accepted', () async {
    File(AppPaths.SETTINGS_PLAYER).writeAsStringSync(jsonEncode({'_v': 2, 'volume': 1}));
    await settings.player.prepareSettingsFile();
    expect(settings.player.volume.value, 1.0);
  });

  /// waits for pending writes first, so none of them lands on the file written here.
  Future<void> loadFile(SettingsFileWriter writer, Object? content) async {
    await flushWrites();
    final file = File(writer.filePath);
    if (content == null) {
      file.deleteIfExistsSync();
    } else {
      file.writeAsStringSync(content is String ? content : jsonEncode(content));
    }
    await writer.prepareSettingsFile();
  }

  List<String> namesExcept(List<Enum> values, Set<Enum> except) => [
    for (final e in values)
      if (!except.contains(e)) e.name,
  ];

  test('old notification toggles migrate to notification buttons', () async {
    const transport = [NotificationButton.previous, NotificationButton.playPause, NotificationButton.next];
    await loadFile(settings, {'_v': 2, 'displayFavouriteButtonInNotification': true, 'displayStopButtonInNotification': false});
    expect(settings.notificationButtons.value, [NotificationButton.favourite, ...transport]);
    expect(settings.buildJson().containsKey('displayFavouriteButtonInNotification'), false);
    expect(settings.buildJson().containsKey('displayStopButtonInNotification'), false);

    await loadFile(settings, {'_v': 2, 'displayStopButtonInNotification': true});
    expect(settings.notificationButtons.value, [...transport, NotificationButton.stop]);
    expect(settings.buildJson().containsKey('notificationButtons'), false);
  });

  test('old custom most played ranges cover their first and last days whole, once', () async {
    final picked = DateRange(oldest: DateTime(2024, 1, 10), newest: DateTime(2024, 1, 14));
    final singleDay = DateRange(oldest: DateTime(2024, 1, 20), newest: DateTime(2024, 1, 20));
    await loadFile(settings, {'_v': 2, 'mostPlayedCustomDateRange': picked.toJson(), 'ytMostPlayedCustomDateRange': singleDay.toJson()});
    expect(settings.mostPlayedCustomDateRange.value, DateRange(oldest: DateTime(2024, 1, 10), newest: DateTime(2024, 1, 14, 23, 59, 59, 999)));
    expect(settings.ytMostPlayedCustomDateRange.value, DateRange(oldest: DateTime(2024, 1, 20), newest: DateTime(2024, 1, 20, 23, 59, 59, 999)));
    expect(settings.buildJson().containsKey('mostPlayedCustomDateRange'), false);
    expect(settings.buildJson().containsKey('ytMostPlayedCustomDateRange'), false);

    final exact = DateRange(oldest: DateTime(2024, 1, 10, 12), newest: DateTime(2024, 1, 12, 12));
    settings.mostPlayedCustomDateRange.save(exact);
    await loadFile(settings, settings.buildJson());
    expect(settings.mostPlayedCustomDateRange.value, exact);

    await loadFile(settings, {'_v': 2, 'ytMostPlayedCustomDateRange': DateRange.dummy().toJson()});
    expect(settings.ytMostPlayedCustomDateRange.userValue, null);
  });

  group('keys', () {
    test('direct writes throw, the value stays', () async {
      await loadSync(null);
      final RxBase<bool> rx = settings.sync.autoReconnect;
      expect(() => rx.value = false, throwsUnsupportedError);
      expect(() => rx.set(false), throwsUnsupportedError);
      expect(settings.sync.autoReconnect.value, true);
      expect(syncRaw(), {'_v': 2});
    });

    test('replace stores the new collection, a default-equal one resets', () async {
      await loadFile(settings, {'_v': 2});
      settings.commonPrefixes.replace(['le ']);
      expect(settings.commonPrefixes.value, ['le ']);
      expect(settings.buildJson()['commonPrefixes'], ['le ']);
      settings.commonPrefixes.replace(['the ', 'a ', 'an ']);
      expect(settings.commonPrefixes.userValue, null);
      expect(settings.buildJson().containsKey('commonPrefixes'), false);

      await loadSync(null);
      settings.sync.allowedServerIds.replace({'srv'});
      expect(syncRaw()['allowedServerIds'], ['srv']);
      settings.sync.allowedServerIds.replace({});
      expect(settings.sync.allowedServerIds.userValue, null);
      settings.sync.deviceIdNames.replace({'a': 'A'});
      expect(syncRaw()['deviceIdNames'], {'a': 'A'});
      settings.sync.deviceIdNames.replace({});
      expect(settings.sync.deviceIdNames.userValue, null);
      expect(syncRaw(), {'_v': 2});
    });

    test('updates copy the default and drop the override once back on it', () async {
      await loadFile(settings, {'_v': 2});
      final defaults = settings.commonPrefixes.fallback.toList();
      settings.commonPrefixes.update((list) => list.add('le '));
      expect(settings.commonPrefixes.fallback, defaults);
      expect(settings.buildJson()['commonPrefixes'], [...defaults, 'le ']);
      settings.commonPrefixes.update((list) => list.remove('le '));
      expect(settings.commonPrefixes.userValue, null);
      expect(settings.buildJson().containsKey('commonPrefixes'), false);

      settings.updateActiveTrSearch(tracks: true, videos: false);
      expect(settings.activeTrSearch.value, {TrackTypeSearch.tr: true, TrackTypeSearch.v: false});
      expect(settings.activeTrSearch.fallback[TrackTypeSearch.v], true);
      expect(settings.buildJson()['activeTrSearch'], {'v': false});
      settings.updateActiveTrSearch(tracks: true, videos: true);
      expect(settings.activeTrSearch.userValue, null);
      expect(settings.buildJson().containsKey('activeTrSearch'), false);
    });

    test('nullable keys: null is the default, an explicit value is kept', () async {
      await loadFile(settings, {'_v': 2});
      expect(settings.fontScaleLRCFull.value, null);
      settings.fontScaleLRCFull.save(1.0);
      expect(settings.fontScaleLRCFull.value, 1.0);
      expect(settings.buildJson()['fontScaleLRCFull'], 1.0);
      settings.fontScaleLRCFull.reset();
      expect(settings.buildJson().containsKey('fontScaleLRCFull'), false);
    });
  });

  group('read-only collections', () {
    test('list forwards reads and throws on every write', () async {
      await loadFile(settings, {'_v': 2});
      final List<String> list = settings.commonPrefixes.value;
      expect(list[1], 'a ');
      expect(list.length, 3);
      expect(list.isEmpty, false);
      expect(list.isNotEmpty, true);
      expect(list.first, 'the ');
      expect(list.last, 'an ');
      expect(list.contains('a '), true);
      expect(list.indexOf('a '), 1);
      expect((list as List<Object?>).indexOf(5), -1);
      expect(list.toList(growable: false), ['the ', 'a ', 'an ']);
      final writes = <void Function()>[
        () => list.length = 0,
        () => list.first = 'x',
        () => list.last = 'x',
        () => list[0] = 'x',
        () => list.add('x'),
        () => list.addAll(['x']),
        () => list.insert(0, 'x'),
        () => list.insertAll(0, ['x']),
        () => list.remove('a '),
        () => list.removeAt(0),
        () => list.removeLast(),
        () => list.removeRange(0, 1),
        () => list.removeWhere((e) => true),
        () => list.retainWhere((e) => false),
        () => list.clear(),
        () => list.sort(),
        () => list.shuffle(),
        () => list.setAll(0, ['x']),
        () => list.setRange(0, 1, ['x']),
        () => list.replaceRange(0, 1, ['x']),
        () => list.fillRange(0, 1, 'x'),
      ];
      for (final write in writes) {
        expect(write, throwsUnsupportedError);
      }
      expect(list, ['the ', 'a ', 'an ']);
    });

    test('set forwards reads and throws on every write', () async {
      await loadSync({
        '_v': 2,
        'allowedServerIds': ['a', 'b'],
      });
      final Set<String> set = settings.sync.allowedServerIds.value;
      expect(set.length, 2);
      expect(set.isEmpty, false);
      expect(set.isNotEmpty, true);
      expect(set.contains('a'), true);
      expect(set.lookup('b'), 'b');
      expect(set.toSet(), {'a', 'b'});
      final writes = <void Function()>[
        () => set.add('x'),
        () => set.addAll(['x']),
        () => set.remove('a'),
        () => set.removeAll(['a']),
        () => set.retainAll(['a']),
        () => set.removeWhere((e) => true),
        () => set.retainWhere((e) => false),
        () => set.clear(),
      ];
      for (final write in writes) {
        expect(write, throwsUnsupportedError);
      }
      expect(set, {'a', 'b'});
    });

    test('map forwards reads and throws on every write', () async {
      await loadSync({
        '_v': 2,
        'deviceIdNames': {'a': 'A'},
      });
      final Map<String, String> map = settings.sync.deviceIdNames.value;
      expect(map['a'], 'A');
      expect(map.keys, ['a']);
      expect(map.values, ['A']);
      expect(map.entries.single.value, 'A');
      expect(map.length, 1);
      expect(map.isEmpty, false);
      expect(map.isNotEmpty, true);
      expect(map.containsKey('a'), true);
      expect(map.containsValue('A'), true);
      final writes = <void Function()>[
        () => map['b'] = 'B',
        () => map.addAll({'b': 'B'}),
        () => map.addEntries([const MapEntry('b', 'B')]),
        () => map.putIfAbsent('b', () => 'B'),
        () => map.remove('a'),
        () => map.removeWhere((k, v) => true),
        () => map.update('a', (v) => 'B'),
        () => map.updateAll((k, v) => 'B'),
        () => map.clear(),
      ];
      for (final write in writes) {
        expect(write, throwsUnsupportedError);
      }
      expect(map, {'a': 'A'});
    });
  });

  group('enum lists', () {
    test('a peer list is taken as is, nothing in it counts as added', () async {
      const kept = {HomePageItems.mixes, HomePageItems.recentListens};
      await loadFile(settings.youtube, {
        '_v': 2,
        'ytHomePageItems': [for (final e in kept) e.name],
        '_x': {'ytHomePageItems': namesExcept(HomePageItems.values, kept)},
      });
      expect(settings.youtube.ytHomePageItems.value, kept.toList());

      final ms = DateTime.now().millisecondsSinceEpoch + 1000;
      settings.youtube.applySyncDelta({
        'v': {
          'ytHomePageItems': ['mixes'],
        },
        'm': {'ytHomePageItems': ms},
      });
      expect(settings.youtube.ytHomePageItems.value, [HomePageItems.mixes]);
      expect(settings.youtube.buildJson()['_x'], {
        'ytHomePageItems': namesExcept(HomePageItems.values, {HomePageItems.mixes}),
      });
      expect(settings.youtube.buildJson()['_m'], {'ytHomePageItems': ms});
    });

    test('added values that complete the default drop the override', () async {
      final defaults = settings.youtube.ytHomePageItems.fallback.toList();
      final withoutLast = defaults.sublist(0, defaults.length - 1);
      await loadFile(settings.youtube, {
        '_v': 2,
        'ytHomePageItems': [for (final e in withoutLast) e.name],
        '_x': {'ytHomePageItems': namesExcept(HomePageItems.values, defaults.toSet())},
      });
      expect(settings.youtube.ytHomePageItems.value, defaults);
      expect(settings.youtube.ytHomePageItems.userValue, null);
      expect(settings.youtube.buildJson().containsKey('ytHomePageItems'), false);
      expect(settings.youtube.buildJson().containsKey('_x'), false);
    });

    test('library tab variants collapse to their group', () async {
      await loadFile(settings, {
        '_v': 2,
        'libraryTabs': ['tracksVideos', 'home', 'foldersMusic'],
      });
      expect(settings.libraryTabs.value, [LibraryTab.tracks, LibraryTab.home, LibraryTab.folders]);
      expect(settings.buildJson()['libraryTabs'], ['tracks', 'home', 'folders']);
    });

    test('duplicates are dropped, the first one keeps its place', () async {
      final storedPerVariant = ['home', 'folders', 'foldersMusic', 'foldersVideos', 'youtube', 'tracks', 'tracksMusic', 'tracksVideos', 'playlists', 'currentQueue'];
      final expected = [LibraryTab.home, LibraryTab.folders, LibraryTab.youtube, LibraryTab.tracks, LibraryTab.playlists, LibraryTab.currentQueue];
      await loadFile(settings, {'libraryTabs': storedPerVariant});
      expect(settings.libraryTabs.value, expected);

      final collapsed = ['home', 'folders', 'folders', 'folders', 'youtube', 'tracks', 'tracks', 'tracks', 'playlists', 'currentQueue'];
      await loadFile(settings, {
        '_v': 2,
        'libraryTabs': collapsed,
        '_x': {'libraryTabs': namesExcept(LibraryTab.values, expected.toSet())},
      });
      expect(settings.libraryTabs.value, expected);
    });
  });

  group('maps', () {
    test('a removed default entry comes back', () async {
      await loadFile(settings.player, {'_v': 2});
      settings.player.onInterrupted.update((actions) => actions.remove(InterruptionType.unknown));
      expect(settings.player.onInterrupted.value[InterruptionType.unknown], InterruptionAction.pause);
      expect(settings.player.onInterrupted.userValue, null);
    });

    test('the old fixed band equalizer moves to the parametric key, bad bands are skipped', () async {
      await loadFile(settings.equalizer, {
        '_v': 2,
        'equalizer': {'60.0': 2.5, 'bad': 1.0, '120.0': 'x', '910.0': -1.0},
      });
      final bands = settings.equalizer.equalizer.value.bands;
      expect([for (final b in bands) (b.frequency, b.gain)], [(60.0, 2.5), (910.0, -1.0)]);
      expect(settings.equalizer.buildJson().containsKey('equalizer'), false);
      expect(settings.equalizer.buildJson()['parametricEqualizer'], settings.equalizer.equalizer.value.toMap());
    });

    test('track sorting of a media type is stored as one chain, unchanged input does nothing', () async {
      await loadFile(settings, {'_v': 2});
      final albumSorting = settings.mediaItemsTrackSorting.value[MediaType.album]!;
      settings.updateMediaItemsTrackSorting(MediaType.album, albumSorting);
      expect(settings.buildJson().containsKey('mediaItemsTrackSorting_v2'), false);

      const titleSorting = SortChain([SortEntry(SortType.title, reverse: true), SortEntry(SortType.year)], reverse: true);
      settings.updateMediaItemsTrackSorting(MediaType.album, titleSorting);
      expect(settings.mediaItemsTrackSorting.value[MediaType.album], titleSorting);
      expect(settings.mediaItemsTrackSorting.value[MediaType.artist], settings.mediaItemsTrackSortingDefault.fallback[MediaType.artist]);
      expect(settings.buildJson()['mediaItemsTrackSorting_v2'], {
        'album': {
          'sorts': ['-title', 'year'],
          'reverse': true,
        },
      });

      settings.updateMediaItemsTrackSorting(MediaType.album, albumSorting);
      expect(settings.buildJson().containsKey('mediaItemsTrackSorting_v2'), false);
    });

    test('group sorting: variants share one entry, an empty chain falls back to the default', () async {
      await loadFile(settings, {
        '_v': 2,
        'mediaGroupSorting': {
          'genre': {'sorts': []},
        },
      });
      expect(settings.groupSortingOf(MediaType.genre), settings.mediaGroupSorting.fallback[MediaType.genre]);

      final yearSorting = SortChain.of(const [GroupSortType.year], reverse: true);
      settings.updateGroupSorting(MediaType.composer, yearSorting);
      expect(settings.groupSortingOf(MediaType.artist), yearSorting);
      expect(settings.groupSortingOf(MediaType.albumArtist), yearSorting);
      expect(settings.buildJson()['mediaGroupSorting'], {
        'artist': {
          'sorts': ['year'],
          'reverse': true,
        },
      });
      expect(settings.hasGroupSorting(MediaType.track), false);
    });

    test('track sort presets: the active one is sorted by and edited, the default chain stays', () async {
      await loadFile(settings, {'_v': 2});
      final albumSorting = settings.mediaItemsTrackSorting.value[MediaType.album]!;
      settings.addTrackSortPreset(MediaType.album, 'a');
      expect(settings.mediaItemsTrackSortingPresets.value[MediaType.album]?.activeIndex, 0);
      expect(settings.mediaItemsTrackSorting.value[MediaType.album], albumSorting);

      int sortsNotified = 0;
      void onSorts() => sortsNotified++;

      settings.mediaItemsTrackSorting.addListener(onSorts);
      addTearDown(() => settings.mediaItemsTrackSorting.removeListener(onSorts));

      const durationSorting = SortChain([SortEntry(SortType.duration, reverse: true)], reverse: true);
      settings.updateMediaItemsTrackSorting(MediaType.album, durationSorting);
      expect(settings.mediaItemsTrackSorting.value[MediaType.album], durationSorting);
      expect(sortsNotified, 1);
      expect(settings.buildJson().containsKey('mediaItemsTrackSorting_v2'), false);

      settings.renameTrackSortPreset(MediaType.album, 0, 'b');
      expect(sortsNotified, 1);

      settings.selectTrackSortPreset(MediaType.album, null);
      expect(settings.mediaItemsTrackSorting.value[MediaType.album], albumSorting);

      settings.selectTrackSortPreset(MediaType.album, 0);
      const titleSorting = SortChain([SortEntry(SortType.title)]);
      settings.updateMediaItemsTrackSorting(MediaType.album, titleSorting, toDefault: true);
      expect(settings.mediaItemsTrackSortingPresets.value[MediaType.album]?.activeIndex, null);
      expect(settings.mediaItemsTrackSorting.value[MediaType.album], titleSorting);
      expect(settings.mediaItemsTrackSortingPresets.value[MediaType.album]?.presets.first.value, durationSorting);

      await loadFile(settings, settings.buildJson());
      expect(settings.mediaItemsTrackSortingPresets.value[MediaType.album]?.presets.first.name, 'b');
      settings.selectTrackSortPreset(MediaType.album, 0);
      expect(settings.mediaItemsTrackSorting.value[MediaType.album], durationSorting);

      settings.addTrackSortPreset(MediaType.album, 'c');
      settings.selectTrackSortPreset(MediaType.album, 0);
      settings.removeTrackSortPreset(MediaType.album, 0);
      expect(settings.mediaItemsTrackSortingPresets.value[MediaType.album]?.activeIndex, null);
      expect(settings.mediaItemsTrackSorting.value[MediaType.album], titleSorting);
      settings.removeTrackSortPreset(MediaType.album, 0);
      expect(settings.buildJson().containsKey('mediaItemsTrackSortingPresets_v2'), false);
    });

    test('track search filter presets: the active one is searched by and edited, the default fields stay', () async {
      await loadFile(settings, {'_v': 2});
      final defaultFilters = settings.trackSearchFilter.value;
      settings.addTrackSearchFilterPreset('a');
      expect(settings.trackSearchFilterPresets.value.activeIndex, 0);
      expect(settings.trackSearchFilter.value, defaultFilters);

      int filtersNotified = 0;
      void onFilters() => filtersNotified++;

      settings.trackSearchFilter.addListener(onFilters);
      addTearDown(() => settings.trackSearchFilter.removeListener(onFilters));

      const lyricsFilters = [TrackSearchFilter.title, TrackSearchFilter.lyrics];
      settings.updateTrackSearchFilter(lyricsFilters);
      expect(settings.trackSearchFilter.value, lyricsFilters);
      expect(filtersNotified, 1);
      expect(settings.buildJson().containsKey('trackSearchFilter'), false);

      settings.renameTrackSearchFilterPreset(0, 'b');
      expect(filtersNotified, 1);

      settings.selectTrackSearchFilterPreset(null);
      expect(settings.trackSearchFilter.value, defaultFilters);
      const titleFilters = [TrackSearchFilter.title];
      settings.updateTrackSearchFilter(titleFilters);
      expect(settings.trackSearchFilter.value, titleFilters);
      expect(settings.buildJson()['trackSearchFilter'], ['title']);
      expect(settings.trackSearchFilterPresets.value.presets.first.value, lyricsFilters);

      await loadFile(settings, settings.buildJson());
      expect(settings.trackSearchFilterPresets.value.presets.first.name, 'b');
      settings.selectTrackSearchFilterPreset(0);
      expect(settings.trackSearchFilter.value, lyricsFilters);

      settings.addTrackSearchFilterPreset('c');
      settings.selectTrackSearchFilterPreset(0);
      settings.removeTrackSearchFilterPreset(0);
      expect(settings.trackSearchFilterPresets.value.activeIndex, null);
      expect(settings.trackSearchFilter.value, titleFilters);
      settings.removeTrackSearchFilterPreset(0);
      expect(settings.buildJson().containsKey('trackSearchFilterPresets'), false);
    });

    test('track search filter presets json: unknown filters and an invalid active index are dropped', () {
      const presets = TrackSearchFilterPresets(
        presets: [
          TrackSearchFilterPreset(name: 'a', value: [TrackSearchFilter.title]),
          TrackSearchFilterPreset(name: 'b', value: [TrackSearchFilter.lyrics, TrackSearchFilter.year]),
        ],
        activeIndex: 1,
      );
      final codec = NamedPresetsCodec.trackSearchFilter;
      final json = codec.encode(presets);
      final decoded = codec.decode(json);
      expect(codec.encode(decoded), json);
      expect(decoded.activePreset?.value, [TrackSearchFilter.lyrics, TrackSearchFilter.year]);

      final removedBefore = decoded.withRemoved(0);
      expect(removedBefore.activeIndex, 0);
      expect(removedBefore.activePreset?.name, 'b');
      expect(decoded.withRemoved(1).activeIndex, null);

      final corrupted = codec.decode({
        'presets': [
          {
            'name': 'x',
            'filters': ['title', 'gone'],
          },
        ],
        'active': 3,
      });
      expect(corrupted.activeIndex, null);
      expect(corrupted.presets.first.value, [TrackSearchFilter.title]);
    });

    test('grid counts fall back to auto', () async {
      await loadFile(settings, {'_v': 2});
      expect(settings.mediaGridCounts.value.get(LibraryTab.playlists).rawValue, 1);
      expect(settings.mediaGridCounts.value.get(LibraryTab.albums), CountPerRow.autoForTab(LibraryTab.albums));
    });
  });

  group('writer', () {
    test('nested transactions write once the outer one ends', () async {
      await loadSync(null);
      await flushWrites();
      final file = File(AppPaths.SETTINGS_SYNC);
      file.deleteIfExistsSync();
      settings.sync.transaction(() {
        settings.sync.transaction(() => settings.sync.autoReconnect.save(false));
        settings.sync.serverWasRunning.save(true);
      });
      settings.sync.transaction(() {});
      final written = await readSyncFile();
      expect(written['autoReconnect'], false);
      expect(written['serverWasRunning'], true);
    });

    test('delta leaves out names that are not synced keys', () async {
      await loadFile(settings.player, {
        '_v': 2,
        'speed': 1.2,
        'volume': 0.3,
        '_m': {'speed': 50, 'volume': 50, 'nope': 50},
      });
      expect(settings.player.syncDelta(0), {
        'v': {'speed': 1.2},
        'm': {'speed': 50},
      });
      expect(settings.player.syncDelta(50), null);
    });

    test('an interrupted migration finishes without touching real modification times', () async {
      await loadFile(settings.player, {
        '_v': 2,
        'speed': 1.2,
        'pitch': 0.9,
        'gone': 1,
        '_legacy': ['gone'],
        '_m': {'speed': 500},
      });
      expect(settings.player.buildJson(), {
        '_v': 2,
        'speed': 1.2,
        'pitch': 0.9,
        '_m': {'speed': 500, 'pitch': 1},
      });
    });

    test('a file without sensitive keys is redacted into an equal copy', () async {
      await loadFile(settings.player, {'_v': 2, 'speed': 1.2});
      final redacted = settings.player.redactedJson();
      expect(redacted, settings.player.buildJson());
      expect(identical(redacted, settings.player.buildJson()), false);
    });

    test('a corrupted file loads the defaults', () async {
      await loadFile(settings.tutorial, '{not json');
      expect(settings.tutorial.lyricsFullscreenTipSeen.value, false);
      expect(settings.tutorial.buildJson(), {'_v': 2});
    });

    test('a failed write keeps the value in memory', () async {
      await loadFile(settings.party, null);
      final dirAtPath = Directory(settings.party.filePath)..createSync(recursive: true);
      settings.party.createPublic.save(true);
      await flushWrites();
      expect(settings.party.createPublic.value, true);
      dirAtPath.deleteSync(recursive: true);
    });

    test('settings sync items map to their writers', () {
      expect(settings.syncWriterOf(SyncDataItem.settingsGeneral), same(settings));
      expect(settings.syncWriterOf(SyncDataItem.settingsPlayer), same(settings.player));
      expect(settings.syncWriterOf(SyncDataItem.settingsYoutube), same(settings.youtube));
      expect(() => settings.syncWriterOf(SyncDataItem.history), throwsArgumentError);
    });
  });

  group('legacy migrations', () {
    const arabic = {'code': 'ar_SA', 'name': 'العربية', 'country': 'Saudi Arabia'};

    test('main: renamed, reset and moved keys', () async {
      await loadFile(settings, {
        'selectedLanguage': arabic,
        'staticColor': kMainColorLightOldValue,
        'staticColorDark': 0xFF112233,
        'useMediaStore': true,
        'tracksSortSearchIsAuto': false,
        'showUnknownFieldsInTrackInfoDialog': true,
        'defaultBackupLocation': '/x',
        'backupItemslist': ['x'],
        'tracksSort': 'album',
        'tracksSortReversed': true,
        'fontScaleLRC': 1.4,
        'fontScaleLRCFull': 1.0,
      });
      expect(settings.language.value?.code, 'ar_SA');
      expect(settings.staticColor.value, null);
      expect(settings.staticColorDark.value, 0xFF112233);
      expect(settings.useMediaStore.userValue, null);
      expect(settings.tracksSortSearchIsAuto.userValue, null);
      expect(settings.mediaItemsTrackSorting.value[MediaType.track], SortChain.of(const [SortType.album, SortType.title, SortType.year], reverse: true));
      expect(settings.fontScaleLRC.value, 1.4);
      expect(settings.fontScaleLRCFull.value, 1.0);
      final raw = settings.buildJson();
      for (final name in ['selectedLanguage', 'staticColor', 'staticColorDark', 'useMediaStore', 'tracksSort', 'tracksSortReversed', 'backupItemslist', '_legacy']) {
        expect(raw.containsKey(name), false, reason: name);
      }
      expect(raw['_m'], containsPair('mediaItemsTrackSorting_v2', 1));
    });

    test('main: sorts and their reverse merge into one chain per media', () async {
      await loadFile(settings, {
        '_v': 2,
        'mediaItemsTrackSorting': {
          'album': ['title', 'year'],
        },
        'mediaItemsTrackSortingReverse': {'album': true, 'artist': true},
        'mediaItemsTrackSortingPresets': {
          'track': {
            'presets': [
              {
                'name': 'p',
                'sorts': ['rating'],
                'reverse': false,
              },
            ],
            'active': 0,
          },
        },
        'albumSorts': ['year'],
        'genreSortReversed': true,
      });
      expect(settings.mediaItemsTrackSortingDefault.value[MediaType.album], SortChain.of(const [SortType.title, SortType.year], reverse: true));
      expect(settings.mediaItemsTrackSortingDefault.value[MediaType.artist], SortChain.of(const [SortType.year, SortType.title], reverse: true));
      expect(settings.mediaItemsTrackSorting.value[MediaType.track], SortChain.of(const [SortType.rating]));
      expect(settings.groupSortingOf(MediaType.album), SortChain.of(const [GroupSortType.year]));
      expect(settings.groupSortingOf(MediaType.genre), SortChain.of(const [GroupSortType.genresList], reverse: true));
      expect(settings.groupSortingOf(MediaType.style), settings.groupSortingOf(MediaType.genre));
      final raw = settings.buildJson();
      for (final name in ['mediaItemsTrackSorting', 'mediaItemsTrackSortingReverse', 'mediaItemsTrackSortingPresets', 'albumSorts', 'genreSortReversed']) {
        expect(raw.containsKey(name), false, reason: name);
      }
    });

    test('main: playlists sorted by the albums date modified move to their own', () async {
      await loadFile(settings, {
        '_v': 2,
        'mediaGroupSorting': {
          'album': {
            'sorts': ['dateModified'],
          },
          'playlist': {
            'sorts': ['-dateModified', 'title'],
            'reverse': true,
          },
        },
        'ytPlaylistSort': 'dateModified',
      });
      expect(settings.groupSortingOf(MediaType.album), SortChain.of(const [GroupSortType.dateModified]));
      const playlistSorting = SortChain([SortEntry(GroupSortType.modifiedDate, reverse: true), SortEntry(GroupSortType.title)], reverse: true);
      expect(settings.groupSortingOf(MediaType.playlist), playlistSorting);
      expect(settings.ytPlaylistSort.value, GroupSortType.modifiedDate);
    });

    test('main: english and broken languages are dropped, a set language wins', () async {
      await loadFile(settings, {
        'selectedLanguage': {'code': 'en_US', 'name': 'English', 'country': 'United States'},
        'staticColor': 0xFF445566,
        'tracksSort': 'year',
        'mediaItemsTrackSorting': {
          'track': ['title'],
        },
      });
      expect(settings.language.value, null);
      expect(settings.staticColor.value, 0xFF445566);
      expect(settings.mediaItemsTrackSorting.value[MediaType.track], SortChain.of(const [SortType.year, SortType.title]));

      await loadFile(settings, {
        'selectedLanguage': {'name': 5},
      });
      expect(settings.language.value, null);

      await loadFile(settings, {
        'language': arabic,
        'selectedLanguage': {'code': 'fr_FR', 'name': 'Français', 'country': 'France'},
      });
      expect(settings.language.value?.code, 'ar_SA');
    });

    test('main: window bounds move to the extra file unless it has its own', () async {
      await flushWrites();
      File(AppPaths.SETTINGS).writeAsStringSync(
        jsonEncode({
          'windowBounds': {'l': 1, 't': 2, 'r': 3, 'b': 4},
        }),
      );
      File(AppPaths.SETTINGS_EXTRA).deleteIfExistsSync();
      await settings.prepareAllSettings();
      expect(settings.extra.windowBounds.value, const Rect.fromLTRB(1, 2, 3, 4));

      await flushWrites();
      File(AppPaths.SETTINGS).writeAsStringSync(
        jsonEncode({
          'windowBounds': {'l': 1, 't': 2, 'r': 3, 'b': 4},
        }),
      );
      File(AppPaths.SETTINGS_EXTRA).writeAsStringSync(
        jsonEncode({
          '_v': 2,
          'windowBounds': {'l': 5, 't': 6, 'r': 7, 'b': 8},
        }),
      );
      await settings.prepareAllSettings();
      expect(settings.extra.windowBounds.value, const Rect.fromLTRB(5, 6, 7, 8));
    });

    test('player: shuffle repeat mode and the replay gain bool', () async {
      await loadFile(settings.player, {'repeatMode': 'shuffle', 'replayGain': true, 'resumeAfterOnVolume0Pause': true});
      expect(settings.player.repeatMode.value, PlayerRepeatMode.all);
      expect(settings.player.shuffleQueue.value, true);
      expect(settings.player.replayGainType.value, ReplayGainType.getPlatformDefault());
      expect(settings.player.buildJson().containsKey('resumeAfterOnVolume0Pause'), false);

      await loadFile(settings.player, {'replayGain': false});
      expect(settings.player.replayGainType.value, ReplayGainType.off);

      await loadFile(settings.player, {'replayGain': 'x'});
      expect(settings.player.replayGainType.userValue, null);
      expect(settings.player.buildJson().containsKey('replayGain'), false);
    });

    test('equalizer and youtube: removed keys are dropped', () async {
      await loadFile(settings.equalizer, {'preset': 'x', 'equalizerEnabled': true});
      expect(settings.equalizer.buildJson(), {'_v': 2, 'equalizerEnabled': true});

      await loadFile(settings.youtube, {'innertubeClient': 'x', 'downloadParallelCount': 3, 'maxPageCacheDurationMin': 5});
      expect(settings.youtube.buildJson(), {'_v': 2});
    });
  });

  group('writer helpers', () {
    test('youtube: audio only mode is restored only when remembered', () async {
      await loadFile(settings.youtube, {'_v': 2, 'isAudioOnlyMode': true, 'rememberAudioOnly': false});
      expect(settings.youtube.isAudioOnlyMode.value, false);
      await loadFile(settings.youtube, {'_v': 2, 'isAudioOnlyMode': true, 'rememberAudioOnly': true});
      expect(settings.youtube.isAudioOnlyMode.value, true);
      expect(settings.youtube.kMaxDaysForPageCacheDuration, 90);
      expect(settings.youtube.kMinutesInMaxDaysForPageCache, 90 * 24 * 60);
      expect(settings.youtube.defaultFilenameBuilder, isNotEmpty);
    });

    test('extra: library tab selection', () async {
      await loadFile(settings.extra, {'_v': 2, 'autoLibraryTab': false, 'staticLibraryTab': 'albums', 'selectedLibraryTab': 'home'});
      expect(settings.extra.selectedLibraryTab.value, LibraryTab.albums);
      settings.extra.setSelectedLibraryTab(LibraryTab.tracksVideos);
      expect(settings.extra.selectedLibraryTab.value, LibraryTab.tracksVideos);
      expect(settings.extra.libraryTabGroupVariants.value, {LibraryTab.tracks: LibraryTab.tracksVideos});
      settings.extra.setSelectedLibraryTab(LibraryTab.playlists);
      expect(settings.extra.libraryTabGroupVariants.value, {LibraryTab.tracks: LibraryTab.tracksVideos});
      expect(settings.extra.getPreferredTabIndexIfLoggedInYT(), 0);
    });

    test('extra: yt home section sources', () async {
      await loadFile(settings.extra, {'_v': 2});
      expect(settings.extra.getYTHomeSectionSource(YTHomePages.home), YTHomeSource.local);
      expect(settings.extra.getYTHomeSectionSource(YTHomePages.notifications), YTHomeSource.youtube);
      expect(settings.extra.getYTHomeSectionSource(YTHomePages.downloads), YTHomeSource.local);

      settings.extra.setYTHomeSectionSource(YTHomePages.playlists, YTHomeSource.youtube);
      expect(settings.extra.getYTHomeSectionSource(YTHomePages.playlists), YTHomeSource.youtube);
      expect(settings.extra.getYTHomeSectionSource(YTHomePages.channels), YTHomeSource.local);
      settings.extra.setYTHomeSectionSource(YTHomePages.playlists, YTHomeSource.local);
      expect(settings.extra.getYTHomeSectionSource(YTHomePages.playlists), YTHomeSource.local);

      settings.extra.setYTHomeSectionSource(YTHomePages.channels, YTHomeSource.youtube);
      expect(settings.extra.buildJson(), {
        '_v': 2,
        'ytHomeSectionSources': {'playlists': 'local', 'channels': 'youtube'},
      });

      for (final section in YTHomePages.values) {
        expect(section.sources, isNotEmpty);
        expect(section.hasSourceChoice, section.sources.length > 1);
      }
    });

    test('extra: old yt split page indexes migrate to section sources', () async {
      await loadFile(settings.extra, {'_v': 2, 'ytInitialHomePage': 'channels', 'ytHomePageIndex': 1, 'ytChannelsPageIndex': 0, 'ytPlaylistsPageIndex': 'x'});
      expect(settings.extra.ytInitialHomePage.value, YTHomePages.channels);
      expect(settings.extra.ytHomeSectionSources.value, {YTHomePages.home: YTHomeSource.youtube, YTHomePages.channels: YTHomeSource.local});
      final migrated = settings.extra.buildJson();
      for (final oldName in ['ytHomePageIndex', 'ytChannelsPageIndex', 'ytPlaylistsPageIndex']) {
        expect(migrated.containsKey(oldName), false, reason: oldName);
      }

      await loadFile(settings.extra, migrated);
      expect(settings.extra.buildJson(), migrated);

      await loadFile(settings.extra, {'_v': 2, 'ytPlaylistsPageIndex': null});
      expect(settings.extra.buildJson(), {'_v': 2});
    });

    test('extra: recent searches', () async {
      await loadFile(settings.extra, {'_v': 2});
      settings.extra.addRecentSearch('a');
      expect(settings.extra.recentSearches.value, isEmpty);

      settings.extra.setRecentSearchesEnabled(true);
      settings.extra.addRecentSearch('a');
      settings.extra.addRecentSearch('b');
      settings.extra.addRecentSearch('a');
      settings.extra.addRecentSearch('a');
      expect(settings.extra.recentSearches.value, ['a', 'b']);
      for (int i = 0; i < 25; i++) {
        settings.extra.addRecentSearch('$i');
      }
      expect(settings.extra.recentSearches.value.length, 20);
      expect(settings.extra.recentSearches.value.first, '24');

      settings.extra.removeRecentSearch('24');
      expect(settings.extra.recentSearches.value.first, '23');
      settings.extra.clearRecentSearches();
      expect(settings.extra.recentSearches.userValue, null);

      settings.extra.addRecentSearch('c');
      settings.extra.setRecentSearchesEnabled(false);
      expect(settings.extra.recentSearches.value, isEmpty);
      expect(settings.extra.buildJson(), {'_v': 2, 'recentSearchesEnabled': false});
    });

    test('extra: window bounds round trip, broken bounds are dropped', () async {
      await loadFile(settings.extra, {'_v': 2});
      settings.extra.windowBounds.save(const Rect.fromLTRB(1, 2, 3, 4));
      expect(settings.extra.buildJson()['windowBounds'], {'l': 1.0, 't': 2.0, 'r': 3.0, 'b': 4.0});
      await loadFile(settings.extra, {
        '_v': 2,
        'windowBounds': {'l': 1, 't': 'x', 'r': 3, 'b': 4},
      });
      expect(settings.extra.windowBounds.value, null);
    });

    test('equalizer: config presets put in place, rename, remove and reload equal', () async {
      await loadFile(settings.equalizer, {'_v': 2});
      final defaults = PlayerConfig(
        skipSilence: false,
        loudnessEnhancerEnabled: false,
        loudnessEnhancer: 0.0,
        equalizerEnabled: false,
        equalizer: ParametricEqualizer.flat,
        preset: null,
        speed: 1.0,
        volume: 1.0,
        pitch: 1.0,
      );
      final bassPreset = EqualizerPreset.allDefaults[1];
      final night = PlayerConfigPreset(
        name: 'Night',
        config: defaults.copyWith(equalizerEnabled: true, equalizer: bassPreset.equalizer, preset: bassPreset, volume: 0.5, loudnessEnhancer: 2.5),
      );
      final slowed = PlayerConfigPreset(name: 'Slowed', config: defaults.copyWith(speed: 0.85, pitch: 0.85));
      settings.equalizer.putConfigPreset(slowed);
      settings.equalizer.putConfigPreset(night);
      settings.equalizer.putConfigPreset(slowed.copyWith(config: defaults.copyWith(speed: 0.8, pitch: 0.8)));
      settings.equalizer.putConfigPreset(night.copyWith(name: 'Late'), replacing: 'Night');
      expect(settings.equalizer.configPresets.value.map((e) => e.name), ['Slowed', 'Late']);
      expect(settings.equalizer.configPresets.value.first.config.speed, 0.8);

      final json = settings.equalizer.buildJson();
      await loadFile(settings.equalizer, json);
      final reloaded = settings.equalizer.configPresets.value;
      expect(reloaded[0].config, slowed.config.copyWith(speed: 0.8, pitch: 0.8));
      expect(reloaded[1].config, night.config);

      expect(settings.equalizer.findConfigPresetDuplicate(night.config, exceptName: 'Other')?.name, 'Late');
      expect(settings.equalizer.findConfigPresetDuplicate(night.config, exceptName: 'Late'), null);
      expect(settings.equalizer.findConfigPresetDuplicate(defaults, exceptName: 'Other'), null);

      settings.equalizer.removeConfigPreset('Slowed');
      settings.equalizer.removeConfigPreset('Late');
      expect(settings.equalizer.configPresets.userValue, null);
    });

    test('equalizer: a config preset stops matching once any value changes', () {
      final config = PlayerConfig(
        skipSilence: false,
        loudnessEnhancerEnabled: true,
        loudnessEnhancer: 2.5,
        equalizerEnabled: true,
        equalizer: EqualizerPreset.allDefaults[1].equalizer,
        preset: EqualizerPreset.allDefaults[1],
        speed: 1.25,
        volume: 0.5,
        pitch: 1.1,
      );
      final reloaded = PlayerConfig.fromMap(jsonDecode(jsonEncode(config.toMap())));
      expect(reloaded, config);
      final changed = [
        config.copyWith(skipSilence: true),
        config.copyWith(loudnessEnhancerEnabled: false),
        config.copyWith(loudnessEnhancer: 2.6),
        config.copyWith(equalizerEnabled: false),
        config.copyWith(equalizer: ParametricEqualizer.flat),
        config.copyWith(preset: EqualizerPreset.allDefaults[2]),
        config.copyWith(speed: 1.0),
        config.copyWith(volume: 0.6),
        config.copyWith(pitch: 1.25),
      ];
      for (final c in changed) {
        expect(c == config, false);
      }
    });

    test('party: reactions and hidden owners', () async {
      await loadFile(settings.party, {'_v': 2});
      final defaultReactions = settings.party.reactionsList();
      expect(defaultReactions.join(), settings.party.defaultReactions);
      settings.party.reactions.save('a b');
      expect(settings.party.reactionsList(), ['a', 'b']);
      settings.party.reactions.save('   ');
      expect(settings.party.reactionsList(), defaultReactions);

      expect(settings.party.toggleHiddenOwner('h'), true);
      expect(settings.party.hiddenOwners.value, {'h'});
      expect(settings.party.redactedJson()['hiddenOwners'], SettingsFileWriter.kRedactedValue);
      expect(settings.party.toggleHiddenOwner('h'), false);
      expect(settings.party.hiddenOwners.userValue, null);
    });

    test('sync: a manual address is only updated when it exists and changed', () async {
      await loadSync(null);
      settings.sync.updateManualServerAddress('s', '1');
      expect(settings.sync.manualServerAddresses.value, isEmpty);
      settings.sync.manualServerAddresses.update((addresses) => addresses['s'] = '1');
      settings.sync.updateManualServerAddress('s', '1');
      settings.sync.updateManualServerAddress('s', '2');
      expect(settings.sync.manualServerAddresses.value, {'s': '2'});
    });
  });
}
