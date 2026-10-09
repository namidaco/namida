// by claude
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:namida/class/lang.dart';
import 'package:namida/controller/backup_controller.dart';
import 'package:namida/controller/platform/zip_manager/zip_manager.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/translations/language.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late Directory userData;
  late Directory work;

  List<int> bytesOf(int seed, [int size = 64]) => List.generate(size, (i) => (i * 7 + seed) % 256);

  File writeFile(String path, List<int> bytes) {
    final file = File(path)..createSync(recursive: true);
    file.writeAsBytesSync(bytes);
    return file;
  }

  File userDataFile(String name) => File(p.join(userData.path, name));
  Directory workDir(String name) => Directory(p.join(work.path, name));

  /// writes [contents] under [dir], keyed by relative path.
  List<File> writeAll(Directory dir, Map<String, List<int>> contents) => contents.entries.map((e) => writeFile(p.join(dir.path, e.key), e.value)).toList();

  void expectAll(Directory dir, Map<String, List<int>> contents) {
    for (final e in contents.entries) {
      final file = File(p.join(dir.path, e.key));
      expect(file.readAsBytesSync(), e.value, reason: e.key);
    }
  }

  setUpAll(() {
    root = Directory.systemTemp.createTempSync('namida_backup_zip_test');
    userData = Directory(p.join(root.path, 'user_data'));
    AppDirs.USER_DATA = '${userData.path}${Platform.pathSeparator}';
    AppDirs.INTERNAL_STORAGE = root.path;
    Language.inst.update(language: NamidaLanguage.fromCode('en')); // -- for the snackbars of creating a backup
  });
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    Directory(AppDirs.YOUTUBE_MAIN_DIRECTORY).createSync(recursive: true);
    work = Directory(p.join(root.path, 'work'))..createSync();
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    userData.deleteSync(recursive: true);
    work.deleteSync(recursive: true);
  });
  tearDownAll(() => root.deleteSync(recursive: true));

  test('zipped files keep their paths relative to the source dir', () async {
    final source = workDir('source');
    final contents = {
      'a.json': bytesOf(1),
      p.join('Youtube', 'yt_likes.json'): bytesOf(2),
      p.join('Youtube', 'Youtube Playlists', 'my list.json'): bytesOf(3),
      'empty.bin': <int>[],
    };
    final files = writeAll(source, contents);
    final zipFile = File(p.join(work.path, 'out.zip'));
    final destination = workDir('extracted');
    final zipManager = ZipManager.platform();
    await zipManager.createZip(sourceDir: source, files: files, zipFile: zipFile);
    await zipManager.extractZip(zipFile: zipFile, destinationDir: destination);
    expectAll(destination, contents);
  });

  test('files sharing a name in different folders all survive a round trip', () async {
    final source = workDir('source');
    final contents = {
      p.join('x', 'data.json'): bytesOf(4),
      p.join('y', 'data.json'): bytesOf(5),
    };
    final files = writeAll(source, contents);
    final zipFile = File(p.join(work.path, 'out.zip'));
    final destination = workDir('extracted');
    final zipManager = ZipManager.platform();
    await zipManager.createZip(sourceDir: source, files: files, zipFile: zipFile);
    await zipManager.extractZip(zipFile: zipFile, destinationDir: destination);
    expectAll(destination, contents);
  });

  test('a zipped directory keeps its nested and empty files', () async {
    final source = workDir('source');
    final contents = {
      'pl 1.json': bytesOf(6),
      p.join('sub', 'deep', 'x.m3u'): bytesOf(7),
      'empty.txt': <int>[],
    };
    writeAll(source, contents);
    final zipFile = File(p.join(work.path, 'out.zip'));
    final destination = workDir('extracted');
    final zipManager = ZipManager.platform();
    await zipManager.createZipFromDirectory(sourceDir: source, zipFile: zipFile);
    await zipManager.extractZip(zipFile: zipFile, destinationDir: destination);
    expectAll(destination, contents);
  });

  test('entries escaping the destination are skipped', () async {
    final zipFile = File(p.join(work.path, 'slip.zip'));
    final outsideAbsolutePath = p.join(work.path, 'outside_absolute.txt');
    final encoder = ZipFileEncoder()..create(zipFile.path);
    encoder.addArchiveFile(ArchiveFile.bytes('ok.txt', bytesOf(8)));
    encoder.addArchiveFile(ArchiveFile.bytes('../evil.txt', bytesOf(9)));
    encoder.addArchiveFile(ArchiveFile.bytes('sub/../../evil_nested.txt', bytesOf(10)));
    encoder.addArchiveFile(ArchiveFile.bytes(outsideAbsolutePath, bytesOf(11)));
    encoder.closeSync();

    final destinationParent = workDir('nested');
    final destination = Directory(p.join(destinationParent.path, 'extracted'));
    await ZipManager.platform().extractZip(zipFile: zipFile, destinationDir: destination);
    expectAll(destination, {'ok.txt': bytesOf(8)});
    expect(File(p.join(destinationParent.path, 'evil.txt')).existsSync(), false);
    expect(File(p.join(destinationParent.path, 'evil_nested.txt')).existsSync(), false);
    expect(File(outsideAbsolutePath).existsSync(), false);
  });

  test('inner zips of a backup extract into their own folders', () async {
    final staging = workDir('staging');
    final settingsFile = writeFile(p.join(staging.path, 'namida_settings.json'), bytesOf(12));
    final likes = writeFile(p.join(staging.path, 'Youtube', 'yt_likes.json'), bytesOf(13));
    final playlists = Directory(p.join(staging.path, 'Playlists'));
    final ytPlaylists = Directory(p.join(staging.path, 'Youtube', 'Youtube Playlists'));
    writeAll(playlists, {'pl.json': bytesOf(14)});
    writeAll(ytPlaylists, {'ytpl.json': bytesOf(15)});

    final zipManager = ZipManager.platform();
    await zipManager.createZip(sourceDir: staging, files: [settingsFile], zipFile: userDataFile('LOCAL_FILES.zip'));
    await zipManager.createZip(sourceDir: staging, files: [likes], zipFile: userDataFile('YOUTUBE_FILES.zip'));
    await zipManager.createZipFromDirectory(sourceDir: playlists, zipFile: userDataFile('TEMPDIR_Playlists.zip'));
    await zipManager.createZipFromDirectory(sourceDir: ytPlaylists, zipFile: userDataFile('YOUTUBE_TEMPDIR_Youtube Playlists.zip'));

    await BackupController.inst.extractBackupInnerZips();

    expect(File(AppPaths.SETTINGS).readAsBytesSync(), bytesOf(12));
    expect(File(AppPaths.YT_LIKES_PLAYLIST).readAsBytesSync(), bytesOf(13));
    expectAll(Directory(AppDirs.PLAYLISTS), {'pl.json': bytesOf(14)});
    expectAll(Directory(AppDirs.YT_PLAYLISTS), {'ytpl.json': bytesOf(15)});
    final leftoverZips = userData.listSync().where((e) => e.path.endsWith('.zip'));
    expect(leftoverZips, isEmpty);
  });

  test('a flat youtube files zip of older windows/linux backups restores into the youtube folder', () async {
    writeFile(AppPaths.YT_LIKES_PLAYLIST, bytesOf(16));
    final staging = workDir('staging');
    final files = writeAll(staging, {'yt_likes.json': bytesOf(17), 'ytid_stats.db': bytesOf(18)});
    final encoder = ZipFileEncoder()..create(userDataFile('YOUTUBE_FILES.zip').path);
    for (final file in files) {
      encoder.addFileSync(file);
    }
    encoder.closeSync();

    await BackupController.inst.extractBackupInnerZips();

    expect(File(AppPaths.YT_LIKES_PLAYLIST).readAsBytesSync(), bytesOf(17));
    expect(File(AppPaths.VIDEO_ID_STATS_DB_INFO.file.path).readAsBytesSync(), bytesOf(18));
    expect(userDataFile('yt_likes.json').existsSync(), false);
    expect(userDataFile('ytid_stats.db').existsSync(), false);
  });

  test('flat leftovers of older restores never replace the restored youtube files', () async {
    writeFile(userDataFile('yt_subs.json').path, bytesOf(19));
    final staging = workDir('staging');
    final subs = writeFile(p.join(staging.path, 'Youtube', 'yt_subs.json'), bytesOf(20));
    await ZipManager.platform().createZip(sourceDir: staging, files: [subs], zipFile: userDataFile('YOUTUBE_FILES.zip'));

    await BackupController.inst.extractBackupInnerZips();

    expect(File(AppPaths.YT_SUBSCRIPTIONS).readAsBytesSync(), bytesOf(20));
  });

  test('empty leftover inner zips are skipped and deleted', () async {
    for (final name in ['LOCAL_FILES.zip', 'YOUTUBE_FILES.zip', 'TEMPDIR_Playlists.zip', 'YOUTUBE_TEMPDIR_Youtube Stats.zip']) {
      userDataFile(name).createSync();
    }

    await BackupController.inst.extractBackupInnerZips();

    final leftoverFiles = userData.listSync().whereType<File>();
    expect(leftoverFiles, isEmpty);
  });

  test('a restored backup keeps the sync id and pair secrets of this device, its other sync settings restore', () async {
    final ownSyncSettings = {
      '_v': 2,
      'id': 'this-device',
      'issuedPairSecrets': {'paired-here': 'aGVyZQ=='},
    };
    File(AppPaths.SETTINGS_SYNC).writeAsStringSync(jsonEncode(ownSyncSettings));
    await settings.sync.prepareSettingsFile();

    final backedUpSyncSettings = {
      '_v': 2,
      'id': 'backed-up-device',
      'customDeviceName': 'Old Phone',
      'allowedDeviceIds': ['paired-there'],
      'issuedPairSecrets': {'paired-there': 'dGhlcmU='},
      'receivedPairSecrets': {'paired-there': 'dGhlcmUy'},
    };
    final staging = workDir('staging');
    final backedUpFile = writeFile(p.join(staging.path, 'namida_settings_sync.json'), utf8.encode(jsonEncode(backedUpSyncSettings)));
    final localFilesZip = File(p.join(work.path, 'LOCAL_FILES.zip'));
    final backupZip = File(p.join(work.path, 'backup.zip'));
    final zipManager = ZipManager.platform();
    await zipManager.createZip(sourceDir: staging, files: [backedUpFile], zipFile: localFilesZip);
    await zipManager.createZip(sourceDir: work, files: [localFilesZip], zipFile: backupZip);

    await BackupController.inst.extractBackup(backupZip);
    await settings.sync.prepareSettingsFile();

    final sync = settings.sync;
    expect(sync.uniqueId.value, 'this-device');
    expect(sync.issuedPairSecrets.value, {'paired-here': 'aGVyZQ=='});
    expect(sync.receivedPairSecrets.value, isEmpty);
    expect(sync.allowedDeviceIds.value, {'paired-there'});
    expect(sync.customDeviceName.value, 'Old Phone');
  });

  test('a backup of the sync settings leaves out the sync id and pair secrets, the live file keeps them and restores into itself', () async {
    final liveSyncSettings = {
      '_v': 2,
      'id': 'this-device',
      'customDeviceName': 'My Phone',
      'allowedDeviceIds': ['paired-device'],
      'issuedPairSecrets': {'paired-device': 'aXNzdWVk'},
      'receivedPairSecrets': {'paired-device': 'cmVjZWl2ZWQ='},
    };
    final liveSyncSettingsFile = writeFile(AppPaths.SETTINGS_SYNC, utf8.encode(jsonEncode(liveSyncSettings)));
    await settings.sync.prepareSettingsFile();
    final liveSyncSettingsBytes = liveSyncSettingsFile.readAsBytesSync();
    writeFile(AppPaths.SETTINGS, bytesOf(21));

    final backupFile = await BackupController.inst.createBackupFile([AppPaths.SETTINGS_SYNC, AppPaths.SETTINGS]);

    expect(liveSyncSettingsFile.readAsBytesSync(), liveSyncSettingsBytes);
    final leftovers = userData.listSync().where((e) => e is Directory ? p.basename(e.path) != 'Youtube' : e.path.endsWith('.zip'));
    expect(leftovers, isEmpty);

    final zipManager = ZipManager.platform();
    final mainEntries = workDir('main');
    final localEntries = workDir('local');
    await zipManager.extractZip(zipFile: backupFile!, destinationDir: mainEntries);
    await zipManager.extractZip(zipFile: File(p.join(mainEntries.path, 'LOCAL_FILES.zip')), destinationDir: localEntries);
    expect(File(p.join(localEntries.path, 'namida_settings.json')).readAsBytesSync(), bytesOf(21));
    expect(File(p.join(localEntries.path, 'namida_settings_sync.json')).existsSync(), false);
    final backedUpSyncSettings = jsonDecode(File(p.join(mainEntries.path, 'namida_settings_sync.json')).readAsStringSync());
    expect(backedUpSyncSettings, {
      '_v': 2,
      'customDeviceName': 'My Phone',
      'allowedDeviceIds': ['paired-device'],
    });

    await BackupController.inst.extractBackup(backupFile);
    await settings.sync.prepareSettingsFile();
    final sync = settings.sync;
    expect(sync.uniqueId.value, 'this-device');
    expect(sync.issuedPairSecrets.value, {'paired-device': 'aXNzdWVk'});
    expect(sync.receivedPairSecrets.value, {'paired-device': 'cmVjZWl2ZWQ='});
    expect(sync.allowedDeviceIds.value, {'paired-device'});
  });
}
