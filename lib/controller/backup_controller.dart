import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:intl/intl.dart';
import 'package:namico_db_wrapper/namico_db_wrapper.dart';

import 'package:namida/class/file_parts.dart';
import 'package:namida/controller/audio_cache_controller.dart';
import 'package:namida/controller/file_browser.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/zip_manager/zip_manager.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/smart_playlists/smart_playlists_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/main.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart';

class BackupController {
  static BackupController get inst => _instance;
  static final BackupController _instance = BackupController._internal();
  BackupController._internal();

  final _zipManager = ZipManager.platform();

  final isCreatingBackup = false.obso;
  final isRestoringBackup = false.obso;

  static String get _backupDirectoryPath => settings.defaultBackupLocation.value ?? AppDirs.BACKUPS;

  Future<String?> _getBackupDirectoryPathEnsured(String? operationName) async {
    final path = _backupDirectoryPath;
    try {
      if (await requestManageStoragePermission(directoryToCreate: path)) return path;
    } catch (e) {
      snackyy(
        title: "${lang.error}: ${operationName ?? lang.backupAndRestore}",
        message: '$e: "$path"',
        isError: true,
      );
    }
    return null;
  }

  int get _defaultAutoBackupInterval => settings.autoBackupIntervalDays.value;

  Future<void> checkForAutoBackup() async {
    final interval = _defaultAutoBackupInterval;
    if (interval <= 0) return;

    Completer<bool>? permissionCompleter;
    if (!await requestManageStoragePermission(request: false, showError: false)) {
      permissionCompleter = Completer<bool>();
      Completer<void>? reqCompleter;
      final sc = snackyy(
        title: "${lang.error}: ${lang.backupAndRestore} - ${lang.automaticBackup}",
        message: lang.storagePermissionDenied,
        isError: true,
        button: SnackbarButton(
          text: lang.manage,
          function: () async {
            reqCompleter = Completer<void>();
            final granted = await requestManageStoragePermission();
            permissionCompleter?.completeIfWasnt(granted);
            reqCompleter?.completeIfWasnt();
          },
        ),
      );
      sc.future.whenComplete(
        () async {
          await reqCompleter?.future;
          permissionCompleter?.completeIfWasnt(false);
        },
      );
    }

    if (permissionCompleter != null && await permissionCompleter.future != true) {
      return;
    }

    final backupDirectoryPath = await _getBackupDirectoryPathEnsured(lang.automaticBackup);
    if (backupDirectoryPath == null) return;

    final intervalDays = Duration(days: interval);
    final hasBackupWithinInterval = await _hasBackupFileWithinIntervalSync.thready((dirPath: backupDirectoryPath, interval: intervalDays));
    if (!hasBackupWithinInterval) {
      final itemsToBackup = [
        AppPaths.TRACKS_OLD,
        AppPaths.TRACKS_DB_INFO.file.path,
        AppPaths.TRACKS_STATS_OLD,
        AppPaths.TRACKS_STATS_DB_INFO.file.path,
        AppPaths.LATEST_PLAYED_FOR_SOURCE.file.path,
        AppPaths.AUDIO_CONFIGS.file.path,
        AppPaths.SMART_PLAYLISTS.file.path,
        AppPaths.TOTAL_LISTEN_TIME,
        AppPaths.LISTEN_TIME_DAILY_DB_INFO.file.path,
        AppPaths.VIDEOS_CACHE_OLD,
        AppPaths.VIDEOS_CACHE_DB_INFO.file.path,
        AppPaths.VIDEOS_LOCAL_OLD,
        AppPaths.VIDEOS_LOCAL_DB_INFO.file.path,
        AppPaths.FAVOURITES_PLAYLIST,
        AppPaths.SETTINGS,
        AppPaths.SETTINGS_EQUALIZER,
        AppPaths.SETTINGS_PLAYER,
        AppPaths.SETTINGS_YOUTUBE,
        AppPaths.SETTINGS_EXTRA,
        AppPaths.SETTINGS_SYNC,
        AppPaths.SETTINGS_PARTY,
        AppPaths.SETTINGS_TUTORIAL,
        AppPaths.SETTINGS_SHORTCUTS,
        AppPaths.LATEST_QUEUE,
        AppPaths.YT_LIKES_PLAYLIST,
        AppPaths.YT_SUBSCRIPTIONS,
        AppPaths.YT_SUBSCRIPTIONS_GROUPS_ALL,
        AppPaths.VIDEO_ID_STATS_DB_INFO.file.path,
        AppPaths.CACHE_VIDEOS_PRIORITY.file.path,
        AppDirs.PLAYLISTS,
        AppDirs.PLAYLISTS_ARTWORKS,
        AppDirs.SMART_PLAYLISTS_ARTWORKS,
        AppDirs.PLAYLISTS_METADATA,
        AppDirs.HISTORY_PLAYLIST,
        AppDirs.QUEUES,
        AppDirs.YT_DOWNLOAD_TASKS,
        AppDirs.YT_STATS,
        AppDirs.YT_PLAYLISTS,
        AppDirs.YT_PLAYLISTS_ARTWORKS,
        AppDirs.YT_PLAYLISTS_METADATA,
        AppDirs.YT_HISTORY_PLAYLIST,
      ];
      await createBackupFile(itemsToBackup, fileSuffix: " - auto");
      _trimExtraBackupFiles.thready(backupDirectoryPath);
    }
  }

  /// [filenamePrefix] other than the default keeps the file out of auto backup/restore lookups.
  Future<File?> createBackupFile(List<String> backupItemsPaths, {String filenamePrefix = 'Namida Backup', String fileSuffix = ''}) async {
    if (isCreatingBackup.value || isRestoringBackup.value) {
      snackyy(title: lang.note, message: lang.anotherProcessIsRunning);
      return null;
    }

    final backupDirPath = await _getBackupDirectoryPathEnsured(lang.createBackup);
    if (backupDirPath == null) return null;

    isCreatingBackup.value = true;

    // formats date
    final format = DateFormat('yyyy-MM-dd HH.mm.ss');
    final date = format.format(DateTime.now().toLocal());

    final backupFilePath = FileParts.joinPath(backupDirPath, "$filenamePrefix - $date$fileSuffix.zip");
    final backupFile = File(backupFilePath);
    final partialBackupFile = await File('$backupFilePath$_kPartialBackupSuffix').create();
    final sourceDir = Directory(AppDirs.USER_DATA);
    final stagingDirPath = FileParts.joinPath(AppDirs.USER_DATA, _kStagingDirName);
    final stagingDir = await Directory(stagingDirPath).create();

    // prepares files

    final List<File> localFilesOnly = [];
    final List<File> youtubeFilesOnly = [];
    final List<File> compressedDirectories = [];
    final List<Directory> dirsOnly = [];
    final syncSettingsPath = settings.sync.filePath;
    File? stagedSyncSettings;
    File? tempAllLocal;
    File? tempAllYoutube;
    var succeeded = false;

    final backupItemsTypes = await backupItemsPaths.mapConcurrent(FileSystemEntity.type);
    for (int i = 0; i < backupItemsPaths.length; i++) {
      final p = backupItemsPaths[i];
      final type = backupItemsTypes[i];
      if (type == FileSystemEntityType.file) {
        if (p == syncSettingsPath) {
          // -- without this device's sync identity, as a main zip entry that restore extracts in place
          final stagedSyncSettingsPath = FileParts.joinPath(stagingDirPath, p.getFilename);
          final syncBackupJson = settings.sync.buildBackupJson();
          stagedSyncSettings = await File(stagedSyncSettingsPath).writeAsJson(syncBackupJson);
          continue;
        }

        final file = File(p);
        if (p.startsWith(AppDirs.YOUTUBE_MAIN_DIRECTORY)) {
          youtubeFilesOnly.add(file);
        } else {
          localFilesOnly.add(file);
        }

        if (p.endsWith('.db')) {
          await _ensureDbCheckpointed(file);
        }
      } else if (type == FileSystemEntityType.directory) {
        dirsOnly.add(Directory(p));
      }
    }

    try {
      for (final d in dirsOnly) {
        final prefix = d.path.startsWith(AppDirs.YOUTUBE_MAIN_DIRECTORY) ? 'YOUTUBE_' : '';
        final dirZipFile = FileParts.join(stagingDirPath, "${prefix}TEMPDIR_${d.path.getFilename}.zip");
        try {
          await _zipManager.createZipFromDirectory(sourceDir: d, zipFile: dirZipFile);
          compressedDirectories.add(dirZipFile);
        } catch (_) {
          await dirZipFile.tryDeleting();
        }
      }

      if (localFilesOnly.isNotEmpty) {
        tempAllLocal = await FileParts.join(stagingDirPath, "LOCAL_FILES.zip").create();
        await _zipManager.createZip(sourceDir: sourceDir, files: localFilesOnly, zipFile: tempAllLocal);
      }

      if (youtubeFilesOnly.isNotEmpty) {
        tempAllYoutube = await FileParts.join(stagingDirPath, "YOUTUBE_FILES.zip").create();
        await _zipManager.createZip(sourceDir: sourceDir, files: youtubeFilesOnly, zipFile: tempAllYoutube);
      }

      final allFiles = [
        ?tempAllLocal,
        ?tempAllYoutube,
        ...compressedDirectories,
        ?stagedSyncSettings,
      ];
      await _zipManager.createZip(sourceDir: stagingDir, files: allFiles, zipFile: partialBackupFile);
      await partialBackupFile.rename(backupFilePath);

      succeeded = true;
      snackyy(title: lang.createdBackupSuccessfully, message: lang.createdBackupSuccessfullySub);
    } catch (e) {
      printy(e, isError: true);
      snackyy(title: lang.error, message: e.toString());
    }

    // Cleaning up
    if (!succeeded) partialBackupFile.tryDeleting();
    await stagingDir.delete(recursive: true).ignoreError();

    isCreatingBackup.value = false;
    return succeeded ? backupFile : null;
  }

  Future<void> _ensureDbCheckpointed(File file) async {
    try {
      final db = DBWrapper.openFromFile(
        file,
        config: const DBConfig(autoDisposeTimerDuration: null),
      );
      await db.claimFreeSpaceAndCheckpoint();
      await db.close();
    } catch (_) {}
  }

  static const _kBackupFilenamePrefix = 'Namida Backup - ';
  static const _kPartialBackupSuffix = '.part';
  static const _kStagingDirName = 'TEMP_BACKUP';

  static bool _isBackupFilename(String filename) => filename.startsWith(_kBackupFilenamePrefix) && filename.endsWith('.zip');

  static List<File> _getBackupFilesSortedSync(String dirPath) {
    final dir = Directory(dirPath);
    final possibleFiles = dir.listSyncSafe();

    final List<File> matchingBackups = [];
    final statsLookup = <File, FileStat>{};
    for (var pf in possibleFiles) {
      if (pf is File) {
        if (_isBackupFilename(pf.path.getFilename)) {
          final stat = pf.statSync();
          if (stat.size > 0) {
            matchingBackups.add(pf);
            statsLookup[pf] = stat;
          }
        }
      }
    }

    // seems like the files are already sorted but anyways
    matchingBackups.sortByReverse((e) => statsLookup[e]!.modified);

    return matchingBackups;
  }

  static bool _hasBackupFileWithinIntervalSync(({String dirPath, Duration interval}) params) {
    final interval = params.interval;
    final now = DateTime.now();
    final oldestAllowed = now.subtract(interval);
    final newestAllowed = now.add(interval);
    final dir = Directory(params.dirPath);
    final possibleFiles = dir.listSyncSafe();
    for (final pf in possibleFiles) {
      if (pf is File) {
        if (_isBackupFilename(pf.path.getFilename)) {
          final modifiedDate = pf.lastModifiedSync();
          if (modifiedDate.isAfter(oldestAllowed) && modifiedDate.isBefore(newestAllowed)) return true;
        }
      }
    }
    return false;
  }

  static void _trimExtraBackupFiles(String dirPath) {
    final dir = Directory(dirPath);
    final possibleFiles = dir.listSyncSafe();

    final statsLookup = <String, FileStat>{};
    for (var pf in possibleFiles) {
      if (pf is File) {
        final filename = pf.path.getFilename;
        if (filename.startsWith(_kBackupFilenamePrefix) && filename.endsWith(" - auto.zip")) {
          try {
            statsLookup[pf.path] = pf.statSync();
          } catch (_) {}
        }
      }
    }

    final remainingBackups = <File>[];
    for (final s in statsLookup.entries) {
      if (s.value.size == 0) {
        try {
          File(s.key).deleteSync();
        } catch (_) {}
      } else {
        remainingBackups.add(File(s.key));
      }
    }

    const maxAutoBackups = 10;
    final extra = remainingBackups.length - maxAutoBackups;
    if (extra > 0) {
      remainingBackups.sortBy((e) => e.lastModifiedSync()); // sorting by oldest
      for (final item in remainingBackups.take(extra)) {
        try {
          item.deleteSync();
        } catch (_) {}
      }
    }
  }

  Future<void> restoreBackupOnTap(bool auto) async {
    if (isRestoringBackup.value || isCreatingBackup.value) {
      snackyy(title: lang.note, message: lang.anotherProcessIsRunning);
      return;
    }

    try {
      File? backupzip;
      if (auto) {
        final backupDirectoryPath = await _getBackupDirectoryPathEnsured(lang.restoreBackup);
        if (backupDirectoryPath != null) {
          final sortedFiles = await _getBackupFilesSortedSync.thready(backupDirectoryPath);
          backupzip = sortedFiles.firstOrNull;
        }
      } else {
        final filePicked = await NamidaFileBrowser.pickFile(note: lang.restoreBackup, allowedExtensions: NamidaFileExtensionsWrapper.zip);
        final path = filePicked?.path;
        if (path != null) {
          backupzip = File(path);
        }
      }

      if (backupzip == null) return;

      isRestoringBackup.value = true;

      await extractBackup(backupzip);

      Indexer.inst.calculateAllImageSizesInStorage();
      // Indexer.inst.updateColorPalettesSizeInStorage();
      await _readNewFiles();
      snackyy(title: lang.restoredBackupSuccessfully, message: lang.restoredBackupSuccessfullySub);
    } catch (e) {
      snackyy(title: "${lang.error}: ${lang.restoreBackup}", message: e.toString());
    } finally {
      isRestoringBackup.value = false;
    }
  }

  @visibleForTesting
  Future<void> extractBackup(File backupzip) {
    return NamicoDBWrapper.suspend(() async {
      // -- leftover wal files would otherwise be applied onto the restored dbs
      await _checkpointDbFilesInDirsSync.thready([
        AppDirs.USER_DATA,
        AppDirs.YOUTUBE_MAIN_DIRECTORY,
        AppDirs.YOUTIPIE_CACHE,
        AppDirs.YT_DOWNLOAD_TASKS,
      ]);

      await _zipManager.extractZip(zipFile: backupzip, destinationDir: Directory(AppDirs.USER_DATA));
      await extractBackupInnerZips();
      await _keepSyncIdentity();
    });
  }

  Future<void> _keepSyncIdentity() async {
    final syncSettingsFile = File(settings.sync.filePath);
    final restored = await syncSettingsFile.readAsJson();
    if (restored is! Map<String, dynamic>) return;
    settings.sync.keepIdentityIn(restored);
    await syncSettingsFile.writeAsJson(restored);
  }

  /// extracts the zips that the main backup zip placed in [AppDirs.USER_DATA].
  @visibleForTesting
  Future<void> extractBackupInnerZips() async {
    // -- leftovers of older restores would be moved over this backup's youtube files
    for (final path in _flatYoutubeFilesPaths) {
      final flatFile = FileParts.join(AppDirs.USER_DATA, path.getFilename);
      try {
        await flatFile.delete();
      } catch (_) {}
    }

    await for (final backupItem in Directory(AppDirs.USER_DATA).list()) {
      if (backupItem is! File) continue;

      final filename = backupItem.path.getFilename;
      final Directory destinationDir;
      if (filename == 'LOCAL_FILES.zip') {
        destinationDir = Directory(AppDirs.USER_DATA);
      } else if (filename == 'YOUTUBE_FILES.zip') {
        destinationDir = Directory(AppDirs.USER_DATA); // since the zipped file has the directory 'AppDirs.YOUTUBE_MAIN_DIRECTORY/'
      } else if (filename.startsWith('YOUTUBE_TEMPDIR_')) {
        final dirName = filename.replaceFirst('YOUTUBE_TEMPDIR_', '').replaceFirst('.zip', '');
        destinationDir = Directory(FileParts.joinPath(AppDirs.YOUTUBE_MAIN_DIRECTORY, dirName));
      } else if (filename.startsWith('TEMPDIR_')) {
        final dirName = filename.replaceFirst('TEMPDIR_', '').replaceFirst('.zip', '');
        destinationDir = Directory(FileParts.joinPath(AppDirs.USER_DATA, dirName));
      } else {
        continue;
      }

      final size = await backupItem.fileSize();
      final isEmptyLeftover = size == null || size == 0;
      if (!isEmptyLeftover) await _zipManager.extractZip(zipFile: backupItem, destinationDir: destinationDir);
      await backupItem.tryDeleting();
    }

    for (final path in _flatYoutubeFilesPaths) {
      final flatFile = FileParts.join(AppDirs.USER_DATA, path.getFilename);
      try {
        await flatFile.rename(path);
      } catch (_) {} // -- not a flat youtube files zip
    }
  }

  /// windows/linux backups made before zip entries kept their relative paths hold these without their youtube folder.
  static final _flatYoutubeFilesPaths = [
    AppPaths.YT_LIKES_PLAYLIST,
    AppPaths.YT_SUBSCRIPTIONS,
    AppPaths.YT_SUBSCRIPTIONS_GROUPS_ALL,
    AppPaths.VIDEO_ID_STATS_DB_INFO.file.path,
  ];

  static void _checkpointDbFilesInDirsSync(List<String> dirsPaths) {
    for (final dirPath in dirsPaths) {
      final dir = Directory(dirPath);
      for (final f in dir.listSyncSafe()) {
        if (f is! File || !f.path.endsWith('.db')) continue;
        final dbInfo = DbWrapperFileInfo.fromFile(dbFile: f);
        try {
          DBWrapper.checkpointFilesSync(dbInfo);
        } catch (_) {}
      }
    }
  }

  Future<void> _readNewFiles() async {
    settings.prepareAllSettings();

    Indexer.inst.prepareTracksFile();

    QueueController.inst.prepareAllQueuesFile();

    VideoController.inst.initialize();
    AudioCacheController.inst.updateAudioCacheMap();

    PlaylistController.inst.prepareAllPlaylists();
    HistoryController.inst.prepareHistoryFile().then((_) => Indexer.inst.sortMediaTracksAndSubListsAfterHistoryPrepared());
    await PlaylistController.inst.prepareDefaultPlaylistsFileAsync();
    await SmartPlaylistsController.inst.reloadFromStorage();
    // await QueueController.inst.prepareLatestQueueSync();

    YoutubePlaylistController.inst.prepareAllPlaylists();
    YoutubeHistoryController.inst.prepareHistoryFile();
    await YoutubePlaylistController.inst.prepareDefaultPlaylistsFileAsync();
    YoutubeInfoController.utils.fillBackupInfoMap(); // for history videos info.
  }
}
