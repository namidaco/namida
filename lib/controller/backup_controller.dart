import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/main.dart';

class BackupController {
  static BackupController get inst => _instance;
  static final BackupController _instance = BackupController._internal();
  BackupController._internal();

  final RxBool isCreatingBackup = false.obs;
  final RxBool isRestoringBackup = false.obs;

  Future<void> createBackupFile() async {
    if (!await requestManageStoragePermission()) {
      return;
    }
    isCreatingBackup.value = true;

    // formats date
    final format = DateFormat('yyyy-MM-dd hh.mm.ss');
    final date = format.format(DateTime.now().toLocal());

    // creates directories and file
    final dir = await Directory(AppDirs.BACKUPS).create();
    await File("${dir.path}/Namida Backup - $date.zip").create();
    final sourceDir = Directory(AppDirs.USER_DATA);

    // prepares files

    final List<File> filesOnly = [];
    final List<Directory> dirsOnly = [];

    await SettingsController.inst.backupItemslist.loopFuture((f, index) async {
      if (await FileSystemEntity.type(f) == FileSystemEntityType.file) {
        filesOnly.add(File(f));
      }
      if (await FileSystemEntity.type(f) == FileSystemEntityType.directory) {
        dirsOnly.add(Directory(f));
      }
    });

    try {
      for (final d in dirsOnly) {
        try {
          final dirZipFile = File("${AppDirs.USER_DATA}/TEMPDIR_${d.path.getFilename}.zip");
          await ZipFile.createFromDirectory(sourceDir: d, zipFile: dirZipFile);
          filesOnly.add(dirZipFile);
        } catch (e) {
          continue;
        }
      }

      final zipFile = File("${AppDirs.BACKUPS}Namida Backup - $date.zip");
      await ZipFile.createFromFiles(sourceDir: sourceDir, files: filesOnly, zipFile: zipFile);

      // after finishing
      final all = sourceDir.listSync();
      await all.loopFuture((one, index) async {
        if (one.path.getFilename.startsWith('TEMPDIR_')) {
          await one.delete();
        }
      });
    } catch (e) {
      printy(e, isError: true);
    }
    Get.snackbar(Language.inst.CREATED_BACKUP_SUCCESSFULLY, Language.inst.CREATED_BACKUP_SUCCESSFULLY_SUB);
    isCreatingBackup.value = false;
  }

  Future<void> restoreBackupOnTap(bool auto) async {
    if (!await requestManageStoragePermission()) {
      return;
    }
    NamidaNavigator.inst.closeDialog();
    File? backupzip;
    if (auto) {
      final dir = Directory(AppDirs.BACKUPS);
      final possibleFiles = dir.listSync();

      final List<File> filessss = [];
      possibleFiles.loop((pf, index) {
        if (pf.path.getFilename.startsWith('Namida Backup - ')) {
          if (pf is File) {
            filessss.add(pf);
          }
        }
      });

      // seems like the files are already sorted but anyways
      filessss.sortByReverse((e) => e.lastModifiedSync());
      backupzip = filessss.firstOrNull;
    } else {
      final filePicked = await FilePicker.platform.pickFiles(allowedExtensions: ['zip'], type: FileType.custom);
      final path = filePicked?.files.first.path;
      if (path != null) {
        backupzip = File(path);
      }
    }

    if (backupzip == null) return;

    isRestoringBackup.value = true;

    await ZipFile.extractToDirectory(zipFile: backupzip, destinationDir: Directory(AppDirs.USER_DATA));

    // after finishing, extracts zip files inside the main zip
    final all = Directory(AppDirs.USER_DATA).listSync();
    await all.loopFuture((one, index) async {
      if (one.path.getFilename.startsWith('TEMPDIR_')) {
        if (one is File) {
          await ZipFile.extractToDirectory(
              zipFile: one, destinationDir: Directory("${AppDirs.USER_DATA}/${one.path.getFilename.replaceFirst('TEMPDIR_', '').replaceFirst('.zip', '')}"));
          await one.delete();
        }
      }
    });

    Indexer.inst.refreshLibraryAndCheckForDiff();
    Indexer.inst.updateImageSizeInStorage();
    Indexer.inst.updateVideosSizeInStorage();
    Get.snackbar(Language.inst.RESTORED_BACKUP_SUCCESSFULLY, Language.inst.RESTORED_BACKUP_SUCCESSFULLY_SUB);
    isRestoringBackup.value = false;
  }
}
