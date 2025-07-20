import 'dart:io';

import 'package:intl/intl.dart';

import 'package:namida/class/file_parts.dart';
import 'package:namida/controller/file_browser.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/zip_manager/zip_manager.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/settings_controller.dart';
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

  Future<String?> _getBackupDirectoryPathEnsured(String? operationName) async {
    final path = settings.defaultBackupLocation.value ?? AppDirs.BACKUPS;
    Directory? dir;
    String? error;
    try {
      dir = await Directory(path).create(recursive: true);
    } catch (e) {
      error = e.toString();
    }
    if (dir == null || !await dir.exists()) {
      snackyy(
        title: "${lang.ERROR}: ${operationName ?? lang.BACKUP_AND_RESTORE}",
        message: '${error ?? lang.DIRECTORY_DOESNT_EXIST}: "$path"',
        isError: true,
      );
      return null;
    }
    return path;
  }

  int get _defaultAutoBackupInterval => settings.autoBackupIntervalDays.value;

  Future<void> checkForAutoBackup() async {
    final interval = _defaultAutoBackupInterval;
    if (interval <= 0) return;

    if (!await requestManageStoragePermission(request: false, showError: false)) {
      snackyy(title: "${lang.ERROR}: ${lang.BACKUP_AND_RESTORE} - ${lang.AUTOMATIC_BACKUP}", message: lang.STORAGE_PERMISSION_DENIED, isError: true);
      return;
    }

    final backupDirectoryPath = await _getBackupDirectoryPathEnsured(lang.AUTOMATIC_BACKUP);
    if (backupDirectoryPath == null) return;

    final latestBackupDate = await _getLatestBackupFileDateSync.thready(backupDirectoryPath);
    if (latestBackupDate != null) {
      final diff = DateTime.now().difference(latestBackupDate).abs().inDays;
      if (diff > interval) {
        final itemsToBackup = [
          AppPaths.TRACKS_OLD,
          AppPaths.TRACKS_DB_INFO.file.path,
          AppPaths.TRACKS_STATS_OLD,
          AppPaths.TRACKS_STATS_DB_INFO.file.path,
          AppPaths.TOTAL_LISTEN_TIME,
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
          AppPaths.SETTINGS_TUTORIAL,
          AppPaths.LATEST_QUEUE,
          AppPaths.YT_LIKES_PLAYLIST,
          AppPaths.YT_SUBSCRIPTIONS,
          AppPaths.YT_SUBSCRIPTIONS_GROUPS_ALL,
          AppPaths.VIDEO_ID_STATS_DB_INFO.file.path,
          AppPaths.CACHE_VIDEOS_PRIORITY.file.path,
          AppDirs.PLAYLISTS,
          AppDirs.PLAYLISTS_ARTWORKS,
          AppDirs.HISTORY_PLAYLIST,
          AppDirs.QUEUES,
          AppDirs.YT_DOWNLOAD_TASKS,
          AppDirs.YT_STATS,
          AppDirs.YT_PLAYLISTS,
          AppDirs.YT_PLAYLISTS_ARTWORKS,
          AppDirs.YT_HISTORY_PLAYLIST,
        ];
        await createBackupFile(itemsToBackup, fileSuffix: " - auto");
        _trimExtraBackupFiles.thready(backupDirectoryPath);
      }
    }
  }

  Future<void> createBackupFile(List<String> backupItemsPaths, {String fileSuffix = ''}) async {
    if (isCreatingBackup.value) {
      snackyy(title: lang.NOTE, message: lang.ANOTHER_PROCESS_IS_RUNNING);
      return;
    }

    if (!await requestManageStoragePermission()) return;

    isCreatingBackup.value = true;

    // formats date
    final format = DateFormat('yyyy-MM-dd hh.mm.ss');
    final date = format.format(DateTime.now().toLocal());

    final backupDirPath = await _getBackupDirectoryPathEnsured(lang.CREATE_BACKUP);
    if (backupDirPath == null) return;

    // creates directories and file
    final dir = await Directory(backupDirPath).create();
    final backupFile = await FileParts.join(dir.path, "Namida Backup - $date$fileSuffix.zip").create();
    final sourceDir = Directory(AppDirs.USER_DATA);

    // prepares files

    final List<File> localFilesOnly = [];
    final List<File> youtubeFilesOnly = [];
    final List<File> compressedDirectories = [];
    final List<Directory> dirsOnly = [];
    File? tempAllLocal;
    File? tempAllYoutube;

    /// ensures auto created db files are included, to prevent locked/corrupted databases.
    Future<List<File>> getPossibleDbJournalFiles(String path) async {
      final possibleFiles = <File>[
        File('$path-journal'),
        File('$path-wal'),
        File('$path-shm'),
      ];

      return await possibleFiles.whereAsync((f) => f.exists()).toList();
    }

    for (final p in backupItemsPaths) {
      if (await FileSystemEntity.type(p) == FileSystemEntityType.file) {
        if (p.startsWith(AppDirs.YOUTUBE_MAIN_DIRECTORY)) {
          youtubeFilesOnly.add(File(p));
          if (p.endsWith('.db')) {
            youtubeFilesOnly.addAll(await getPossibleDbJournalFiles(p));
          }
        } else {
          localFilesOnly.add(File(p));
          if (p.endsWith('.db')) {
            localFilesOnly.addAll(await getPossibleDbJournalFiles(p));
          }
        }
      }
      if (await FileSystemEntity.type(p) == FileSystemEntityType.directory) {
        dirsOnly.add(Directory(p));
      }
    }

    try {
      for (final d in dirsOnly) {
        try {
          final prefix = d.path.startsWith(AppDirs.YOUTUBE_MAIN_DIRECTORY) ? 'YOUTUBE_' : '';
          final dirZipFile = FileParts.join(AppDirs.USER_DATA, "${prefix}TEMPDIR_${d.path.getFilename}.zip");
          await _zipManager.createZipFromDirectory(sourceDir: d, zipFile: dirZipFile);
          compressedDirectories.add(dirZipFile);
        } catch (e) {
          continue;
        }
      }

      if (localFilesOnly.isNotEmpty) {
        tempAllLocal = await FileParts.join(AppDirs.USER_DATA, "LOCAL_FILES.zip").create();
        await _zipManager.createZip(sourceDir: sourceDir, files: localFilesOnly, zipFile: tempAllLocal);
      }

      if (youtubeFilesOnly.isNotEmpty) {
        tempAllYoutube = await FileParts.join(AppDirs.USER_DATA, "YOUTUBE_FILES.zip").create();
        await _zipManager.createZip(sourceDir: sourceDir, files: youtubeFilesOnly, zipFile: tempAllYoutube);
      }

      final allFiles = [
        if (tempAllLocal != null) tempAllLocal,
        if (tempAllYoutube != null) tempAllYoutube,
        ...compressedDirectories,
      ];
      await _zipManager.createZip(sourceDir: sourceDir, files: allFiles, zipFile: backupFile);

      snackyy(title: lang.CREATED_BACKUP_SUCCESSFULLY, message: lang.CREATED_BACKUP_SUCCESSFULLY_SUB);
    } catch (e) {
      printy(e, isError: true);
      snackyy(title: lang.ERROR, message: e.toString());
    }

    // Cleaning up
    tempAllLocal?.tryDeleting();
    tempAllYoutube?.tryDeleting();
    for (final d in compressedDirectories) {
      d.tryDeleting();
    }

    isCreatingBackup.value = false;
  }

  static List<File> _getBackupFilesSortedSync(String dirPath) {
    final dir = Directory(dirPath);
    final possibleFiles = dir.listSyncSafe();

    final List<File> matchingBackups = [];
    possibleFiles.loop((pf) {
      if (pf is File) {
        if (pf.path.getFilename.startsWith('Namida Backup - ')) {
          matchingBackups.add(pf);
        }
      }
    });

    // seems like the files are already sorted but anyways
    matchingBackups.sortByReverse((e) => e.lastModifiedSync());

    return matchingBackups;
  }

  static DateTime? _getLatestBackupFileDateSync(String dirPath) {
    DateTime latestDate = DateTime(0);
    final dir = Directory(dirPath);
    final possibleFiles = dir.listSyncSafe();
    for (final pf in possibleFiles) {
      if (pf is File) {
        if (pf.path.getFilename.startsWith('Namida Backup - ')) {
          final modifiedDate = pf.lastModifiedSync();

          if (modifiedDate.isAfter(latestDate)) {
            latestDate = modifiedDate;
          }
        }
      }
    }
    return latestDate;
  }

  static void _trimExtraBackupFiles(String dirPath) {
    final dir = Directory(dirPath);
    final possibleFiles = dir.listSyncSafe();

    final statsLookup = <String, FileStat>{};
    possibleFiles.loop((pf) {
      if (pf is File) {
        final filename = pf.path.getFilename;
        if (filename.startsWith('Namida Backup - ') && filename.endsWith(" - auto.zip")) {
          try {
            statsLookup[pf.path] = pf.statSync();
          } catch (_) {}
        }
      }
    });

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
      for (int i = 0; i < extra; i++) {
        try {
          remainingBackups[i].deleteSync();
        } catch (_) {}
      }
    }
  }

  Future<void> restoreBackupOnTap(bool auto) async {
    if (isRestoringBackup.value) {
      snackyy(title: lang.NOTE, message: lang.ANOTHER_PROCESS_IS_RUNNING);
      return;
    }

    try {
      File? backupzip;
      if (auto) {
        final backupDirectoryPath = await _getBackupDirectoryPathEnsured(lang.RESTORE_BACKUP);
        if (backupDirectoryPath != null) {
          final sortedFiles = await _getBackupFilesSortedSync.thready(backupDirectoryPath);
          backupzip = sortedFiles.firstOrNull;
        }
      } else {
        final filePicked = await NamidaFileBrowser.pickFile(note: lang.RESTORE_BACKUP, allowedExtensions: NamidaFileExtensionsWrapper.zip);
        final path = filePicked?.path;
        if (path != null) {
          backupzip = File(path);
        }
      }

      if (backupzip == null) return;

      isRestoringBackup.value = true;

      await _zipManager.extractZip(zipFile: backupzip, destinationDir: Directory(AppDirs.USER_DATA));

      // after finishing, extracts zip files inside the main zip
      await for (final backupItem in Directory(AppDirs.USER_DATA).list()) {
        if (backupItem is File) {
          final filename = backupItem.path.getFilename;
          if (filename == 'LOCAL_FILES.zip') {
            await _zipManager.extractZip(
              zipFile: backupItem,
              destinationDir: Directory(AppDirs.USER_DATA),
            );
            await backupItem.tryDeleting();
          } else if (filename == 'YOUTUBE_FILES.zip') {
            await _zipManager.extractZip(
              zipFile: backupItem,
              destinationDir: Directory(AppDirs.USER_DATA), // since the zipped file has the directory 'AppDirs.YOUTUBE_MAIN_DIRECTORY/'
            );
            await backupItem.tryDeleting();
          } else {
            final isLocalTemp = filename.startsWith('TEMPDIR_');
            final isYoutubeTemp = filename.startsWith('YOUTUBE_TEMPDIR_');
            if (isLocalTemp || isYoutubeTemp) {
              final dir = isYoutubeTemp ? AppDirs.YOUTUBE_MAIN_DIRECTORY : AppDirs.USER_DATA;
              final prefixToReplace = isYoutubeTemp ? 'YOUTUBE_TEMPDIR_' : 'TEMPDIR_';

              await _zipManager.extractZip(
                zipFile: backupItem,
                destinationDir: Directory(FileParts.joinPath(dir, filename.replaceFirst(prefixToReplace, '').replaceFirst('.zip', ''))),
              );
              await backupItem.tryDeleting();
            }
          }
        }
      }

      Indexer.inst.calculateAllImageSizesInStorage();
      // Indexer.inst.updateColorPalettesSizeInStorage();
      await _readNewFiles();
      snackyy(title: lang.RESTORED_BACKUP_SUCCESSFULLY, message: lang.RESTORED_BACKUP_SUCCESSFULLY_SUB);
    } catch (e) {
      snackyy(title: "${lang.ERROR}: ${lang.RESTORE_BACKUP}", message: e.toString());
    } finally {
      isRestoringBackup.value = false;
    }
  }

  Future<void> _readNewFiles() async {
    settings.equalizer.prepareSettingsFile();
    settings.player.prepareSettingsFile();
    settings.youtube.prepareSettingsFile();
    settings.prepareSettingsFile();

    Indexer.inst.prepareTracksFile();

    QueueController.inst.prepareAllQueuesFile();

    VideoController.inst.initialize();

    PlaylistController.inst.prepareAllPlaylists();
    HistoryController.inst.prepareHistoryFile().then((_) => Indexer.inst.sortMediaTracksAndSubListsAfterHistoryPrepared());
    await PlaylistController.inst.prepareDefaultPlaylistsFileAsync();
    // await QueueController.inst.prepareLatestQueueSync();

    YoutubePlaylistController.inst.prepareAllPlaylists();
    YoutubeHistoryController.inst.prepareHistoryFile();
    await YoutubePlaylistController.inst.prepareDefaultPlaylistsFileAsync();
    YoutubeInfoController.utils.fillBackupInfoMap(); // for history videos info.
  }
}
