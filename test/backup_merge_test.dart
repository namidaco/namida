// by claude
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namico_db_wrapper/namico_db_wrapper.dart';
import 'package:path/path.dart' as p;

import 'package:namida/base/settings_file_writer.dart';
import 'package:namida/class/lang.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/backup_controller.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/listen_time_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/language.dart';
import 'package:youtipie/class/map_serializable.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('namida_backup_merge_test');
    AppDirs.USER_DATA = '${p.join(root.path, 'user_data')}${Platform.pathSeparator}';
    AppDirs.INTERNAL_STORAGE = root.path;
    Directory(AppDirs.YOUTUBE_MAIN_DIRECTORY).createSync(recursive: true);
    Language.inst.update(language: NamidaLanguage.fromCode('en')); // -- for the snackbars of creating a backup
    await HistoryController.inst.prepareHistoryFile();
  });
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.windows);
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  tearDownAll(() {
    try {
      root.deleteSync(recursive: true);
    } catch (_) {} // -- the controllers' dbs can still be open
  });

  Future<File> createBackup(List<String> paths) async {
    final backupFile = await BackupController.inst.createBackupFile(paths);
    return backupFile!;
  }

  void writeJson(String path, Object json) {
    File(path)
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(json));
  }

  DBWrapperSync openDb(String directory, String dbName) {
    final dbInfo = DbWrapperFileInfo(directory: directory, dbName: dbName);
    return DBWrapper.openFromInfoSync(fileInfo: dbInfo, config: const DBConfig(createIfNotExist: true, autoDisposeTimerDuration: null));
  }

  void writeDbRows(String directory, String dbName, Map<String, Map<String, dynamic>> rows) {
    final db = openDb(directory, dbName);
    db.deleteEverything();
    for (final e in rows.entries) {
      db.put(e.key, e.value);
    }
    db.close();
  }

  Map<String, Map<String, dynamic>> readDbRows(String directory, String dbName) {
    final rows = <String, Map<String, dynamic>>{};
    final db = openDb(directory, dbName);
    db.loadEverythingKeyed((key, value) => rows[key] = value);
    db.close();
    return rows;
  }

  Track trackOf(String name) => Track.explicit(p.join(root.path, 'music', '$name.m4a'));

  group('settings', () {
    Future<void> load(SettingsFileWriter writer, Map<String, dynamic> fileContent) async {
      writeJson(writer.filePath, fileContent);
      await writer.prepareSettingsFile();
    }

    test('backup values win even over newer ones, keys the backup never touched keep ours', () async {
      await load(settings.player, {
        '_v': 2,
        'speed': 1.25,
        'pitch': 0.9,
        'linkSpeedPitch': true,
        'volume': 0.5,
        '_m': {'speed': 2000, 'pitch': 1000, 'linkSpeedPitch': 1000},
      });
      settings.player.applyBackupJson({
        '_v': 2,
        'speed': 1.5,
        'pitch': 1.1,
        'volume': 0.8,
        'useSemitones': true,
        '_m': {'speed': 1500, 'pitch': 3000, 'useSemitones': 3000},
      });
      expect(settings.player.speed.value, 1.5);
      expect(settings.player.pitch.value, 1.1);
      expect(settings.player.linkSpeedPitch.value, true);
      expect(settings.player.volume.value, 0.8);
      expect(settings.player.useSemitones.value, true);
      final modified = settings.player.buildJson()['_m'] as Map;
      expect(modified['speed'], greaterThan(3000));
      expect(modified['linkSpeedPitch'], 1000);
    });

    test('a reset in the backup brings the default back', () async {
      await load(settings.player, {
        '_v': 2,
        'speed': 1.25,
        '_m': {'speed': 3000},
      });
      settings.player.applyBackupJson({
        '_v': 2,
        '_m': {'speed': 2000},
      });
      expect(settings.player.speed.value, settings.player.speed.fallback);
      expect(settings.player.buildJson().containsKey('speed'), false);
    });

    test('an old full-dump backup applies only its non default values, renamed keys migrate', () async {
      await load(settings.equalizer, {
        '_v': 2,
        'equalizerEnabled': true,
        'loudnessEnhancer': 0.5,
      });
      settings.equalizer.applyBackupJson({
        'equalizerEnabled': false, // -- the dump's default, not a choice
        'loudnessEnhancer': 0.7,
        'loudnessEnhancerEnabled': true,
      });
      expect(settings.equalizer.equalizerEnabled.value, true);
      expect(settings.equalizer.loudnessEnhancer.value, 0.7);
      expect(settings.equalizer.loudnessEnhancerEnabled.value, true);

      await load(settings.tutorial, {'_v': 2});
      settings.tutorial.applyBackupJson({'llpfs': false});
      expect(settings.tutorial.lyricsFullscreenTipSeen.value, true);
    });

    test('sync identity stays local, known devices of both sides are kept', () async {
      await load(settings.sync, {
        '_v': 2,
        'id': 'local-id',
        'allowedDeviceIds': ['a'],
        'deviceIdNames': {'a': 'A'},
        'issuedPairSecrets': {'a': 's1'},
        'autoReconnect': false,
      });
      settings.sync.applyBackupJson({
        '_v': 2,
        'id': 'backup-id',
        'allowedDeviceIds': ['b'],
        'deviceIdNames': {'a': 'A2', 'b': 'B'},
        'issuedPairSecrets': {'b': 's2'},
        'autoSyncIntervalMinutes': 30,
      });
      expect(settings.sync.uniqueId.value, 'local-id');
      expect(settings.sync.issuedPairSecrets.value, {'a': 's1'});
      expect(settings.sync.allowedDeviceIds.value, {'a', 'b'});
      expect(settings.sync.deviceIdNames.value, {'a': 'A2', 'b': 'B'});
      expect(settings.sync.autoReconnect.value, false);
      expect(settings.sync.autoSyncIntervalMinutes.value, 30);
    });
  });

  test('importing listens adds only missing ones and leaves days without new listens untouched', () async {
    final history = HistoryController.inst;
    final dayMS = DateTime(2026, 1, 10, 9).millisecondsSinceEpoch;
    final otherDayMS = DateTime(2026, 1, 12, 9).millisecondsSinceEpoch;
    final a = TrackWithDate(dateAdded: dayMS, track: trackOf('a'));
    final b = TrackWithDate(dateAdded: dayMS + 60000, track: trackOf('b'));
    await history.addTracksToHistory([a, b]);
    final countBefore = history.totalHistoryItemsCount.value;

    final dayFile = File('${AppDirs.HISTORY_PLAYLIST}${dayMS.toDaysSince1970()}.json');
    final oldDate = DateTime(2020);
    dayFile.setLastModifiedSync(oldDate);

    await history.addTracksToHistoryImportPreventDuplicates([b, a]);
    expect(history.totalHistoryItemsCount.value, countBefore);
    expect(dayFile.lastModifiedSync(), oldDate);

    final c = TrackWithDate(dateAdded: otherDayMS, track: trackOf('c'));
    await history.addTracksToHistoryImportPreventDuplicates([a, c, c]);
    expect(history.totalHistoryItemsCount.value, countBefore + 1);
    expect(dayFile.lastModifiedSync(), oldDate);
  });

  test('restoring keeps listens added after the backup and brings back lost ones', () async {
    final history = HistoryController.inst;
    final dayMS = DateTime(2026, 2, 1, 9).millisecondsSinceEpoch;
    final day = dayMS.toDaysSince1970();
    final lost = TrackWithDate(dateAdded: dayMS, track: trackOf('lost'));
    await history.addTracksToHistory([lost]);
    final backupFile = await createBackup([AppDirs.HISTORY_PLAYLIST]);

    File('${AppDirs.HISTORY_PLAYLIST}$day.json').deleteSync();
    await history.prepareHistoryFile();
    final newer = TrackWithDate(dateAdded: dayMS + 3600000, track: trackOf('newer'));
    await history.addTracksToHistory([newer]);

    final failed = await BackupController.inst.mergeBackup(backupFile);
    expect(failed, isEmpty);
    expect(history.historyMap.value[day], [newer, lost]);
    final saved = File('${AppDirs.HISTORY_PLAYLIST}$day.json').readAsJsonSync() as List;
    expect(saved.map((e) => e['track']).toList(), [newer.track.path, lost.track.path]);
  });

  test('listens of a backup from another device land on the matching tracks here', () async {
    final history = HistoryController.inst;
    final localPath = p.join(root.path, 'music', 'here', 'song.m4a');
    const otherPath = '/storage/other/song.flac';
    final tagged = kDummyExtendedTrack.copyWith(
      title: 'Song',
      originalArtist: 'Artist',
      originalAlbum: 'Album',
      durationMS: 200000,
      generatePathHash: false,
    );
    Indexer.inst.allTracksMappedByPath[localPath] = tagged.copyWith(path: localPath, generatePathHash: false);
    writeDbRows(AppPaths.TRACKS_DB_INFO.directory, AppPaths.TRACKS_DB_INFO.dbName, {otherPath: tagged.toJsonWithoutPath()});

    final dayMS = DateTime(2026, 3, 1, 9).millisecondsSinceEpoch;
    final day = dayMS.toDaysSince1970();
    final dayFilePath = '${AppDirs.HISTORY_PLAYLIST}$day.json';
    final otherListen = TrackWithDate(dateAdded: dayMS, track: Track.explicit(otherPath));
    writeJson(dayFilePath, [otherListen.toJson()]);
    final backupFile = await createBackup([AppPaths.TRACKS_DB_INFO.file.path, AppDirs.HISTORY_PLAYLIST]);
    File(dayFilePath).deleteSync();
    await history.prepareHistoryFile();

    final failed = await BackupController.inst.mergeBackup(backupFile);
    expect(failed, isEmpty);
    expect(history.historyMap.value[day]?.map((e) => e.track.path).toList(), [localPath]);
  });

  test('the tracks db of the backup is restored, except paths matched to tracks here', () async {
    final indexer = Indexer.inst;
    final tracksDbInfo = AppPaths.TRACKS_DB_INFO;
    final hereSong = kDummyExtendedTrack.copyWith(title: 'Here', originalArtist: 'A', durationMS: 100000, generatePathHash: false);
    final removedSong = kDummyExtendedTrack.copyWith(title: 'Removed', originalArtist: 'B', durationMS: 200000, generatePathHash: false);
    final localPath = p.join(root.path, 'music', 'here', 'here.m4a');
    const otherHerePath = '/storage/other/here.m4a';
    const removedPath = '/storage/sdcard/removed.m4a';
    indexer.allTracksMappedByPath[localPath] = hereSong.copyWith(path: localPath, generatePathHash: false);
    writeDbRows(tracksDbInfo.directory, tracksDbInfo.dbName, {
      otherHerePath: hereSong.toJsonWithoutPath(),
      removedPath: removedSong.toJsonWithoutPath(),
    });
    final backupFile = await createBackup([tracksDbInfo.file.path]);
    writeDbRows(tracksDbInfo.directory, tracksDbInfo.dbName, {
      localPath: hereSong.toJsonWithoutPath(),
    });

    await BackupController.inst.mergeBackup(backupFile);
    final rows = readDbRows(tracksDbInfo.directory, tracksDbInfo.dbName);
    expect(rows.keys.toSet(), {localPath, removedPath});
    expect(rows[removedPath]?['title'], 'Removed');
  });

  test('restoring merges db rows: metadata cache keeps the newest good one, other dbs take the backup', () async {
    final youtipieDir = AppDirs.YOUTIPIE_CACHE;
    final tasksDir = AppDirs.YT_DOWNLOAD_TASKS;
    const dummyKey = MapSerializable.dummyKey;
    writeDbRows(youtipieDir, 'videoPage', {
      'a': {'_ts_': 100, 'v': 'backup-a'},
      'b': {'_ts_': 300, 'v': 'backup-b'},
      'c': {'_ts_': 100, 'v': 'backup-c'},
      'e': {'_ts_': 300, dummyKey: true, 'v': 'backup-e'},
      'f': {'_ts_': 100, 'v': 'backup-f'},
    });
    writeDbRows(tasksDir, '', {
      'x': {'v': 'backup-x'},
      'y': {'v': 'backup-y'},
    });
    final backupFile = await createBackup([youtipieDir, tasksDir]);

    writeDbRows(youtipieDir, 'videoPage', {
      'a': {'_ts_': 200, 'v': 'local-a'},
      'b': {'_ts_': 200, 'v': 'local-b'},
      'd': {'_ts_': 100, 'v': 'local-d'},
      'e': {'_ts_': 100, 'v': 'local-e'},
      'f': {'_ts_': 300, dummyKey: true, 'v': 'local-f'},
    });
    writeDbRows(tasksDir, '', {
      'x': {'v': 'local-x'},
      'z': {'v': 'local-z'},
    });

    final failed = await BackupController.inst.mergeBackup(backupFile);
    expect(failed, isEmpty);

    final pages = readDbRows(youtipieDir, 'videoPage');
    expect(pages.map((key, value) => MapEntry(key, value['v'])), {
      'a': 'local-a',
      'b': 'backup-b',
      'c': 'backup-c',
      'd': 'local-d',
      'e': 'local-e',
      'f': 'backup-f',
    });
    final tasks = readDbRows(tasksDir, '');
    expect(tasks.map((key, value) => MapEntry(key, value['v'])), {'x': 'backup-x', 'y': 'backup-y', 'z': 'local-z'});
  });

  test('playlists keep the tracks of both, the backup properties win even when older', () async {
    final controller = PlaylistController.inst;
    LocalPlaylist playlistOf(List<TrackWithDate> tracks, {required List<String> tags, required int modifiedDate}) {
      return LocalPlaylist(
        name: 'mix',
        tracks: tracks,
        creationDate: 1,
        modifiedDate: modifiedDate,
        comment: '',
        moods: const [],
        tags: tags,
        isFav: false,
        sortsType: null,
        sortReverse: false,
      );
    }

    void writePlaylist(LocalPlaylist pl) => writeJson(p.join(AppDirs.PLAYLISTS, '${pl.name}.json'), pl.toJson((e) => e.toJson(), SortType.sortsToJson));

    final shared = TrackWithDate(dateAdded: 1000, track: trackOf('shared'));
    final backupOnly = TrackWithDate(dateAdded: 2000, track: trackOf('backup_only'));
    final localOnly = TrackWithDate(dateAdded: 3000, track: trackOf('local_only'));
    writePlaylist(playlistOf([shared, backupOnly], tags: ['backup'], modifiedDate: 100));
    final backupFile = await createBackup([AppDirs.PLAYLISTS]);
    final local = playlistOf([localOnly, shared], tags: ['local'], modifiedDate: 200);
    writePlaylist(local);
    controller.playlistsMap.value[local.name] = local;

    final failed = await BackupController.inst.mergeBackup(backupFile);
    expect(failed, isEmpty);
    final merged = controller.playlistsMap.value[local.name]!;
    expect(merged.tags, ['backup']);
    expect(merged.tracks.map((e) => e.track).toSet(), {localOnly.track, shared.track, backupOnly.track});
  });

  test('restoring files dirs replaces same named files and keeps local only ones', () async {
    final lyricsDir = AppDirs.LYRICS;
    writeJson(p.join(lyricsDir, 'shared.lrc'), 'backup');
    writeJson(p.join(lyricsDir, 'backup_only.lrc'), 'backup');
    final backupFile = await createBackup([lyricsDir]);

    Directory(lyricsDir).deleteSync(recursive: true);
    writeJson(p.join(lyricsDir, 'shared.lrc'), 'local');
    writeJson(p.join(lyricsDir, 'local_only.lrc'), 'local');

    final failed = await BackupController.inst.mergeBackup(backupFile);
    expect(failed, isEmpty);
    String read(String name) => jsonDecode(File(p.join(lyricsDir, name)).readAsStringSync()) as String;
    expect(read('shared.lrc'), 'backup');
    expect(read('backup_only.lrc'), 'backup');
    expect(read('local_only.lrc'), 'local');
  });

  test('listen time keeps the bigger count per day', () async {
    final listenTime = ListenTimeController.inst;
    await listenTime.importDbRows({
      '100': {'tr': 50, 'yt': 10},
    });
    await listenTime.importDbRows({
      '100': {'tr': 40, 'yt': 30},
      '101': {'tr': 5},
    });
    final all = await listenTime.loadAll();
    expect(all[100], {'tr': 50, 'yt': 30});
    expect(all[101], {'tr': 5});
  });

  test('queues are added with their tracks resolved, the backup replaces ours of the same date', () async {
    final sourceDir = Directory(p.join(root.path, 'queues_source'));
    String queueJson(int date, List<String> paths) {
      final json = {
        'source': 'others',
        'date': date,
        'isFav': false,
        'tracks': paths,
      };
      return jsonEncode(json);
    }

    File(p.join(sourceDir.path, '1.json'))
      ..createSync(recursive: true)
      ..writeAsStringSync(queueJson(1, ['/other/device/a.m4a', '/other/device/b.m4a']));
    File(p.join(sourceDir.path, '2.json')).writeAsStringSync(queueJson(2, ['/other/device/c.m4a']));
    File('${AppDirs.QUEUES}2.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(queueJson(2, ['/local/replaced.m4a']));

    final localA = trackOf('a');
    await QueueController.inst.importQueuesDirectory('${sourceDir.path}${Platform.pathSeparator}', {'/other/device/a.m4a': localA});

    final queues = QueueController.inst.queuesMap.value;
    expect(queues[1]?.tracks.map((e) => e.path).toList(), [localA.path, '/other/device/b.m4a']);
    expect(queues[2]?.tracks.map((e) => e.path).toList(), ['/other/device/c.m4a']);
  });
}
