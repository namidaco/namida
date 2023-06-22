import 'dart:io';

import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/strings.dart';
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
    await Directory(SettingsController.inst.defaultBackupLocation.value).create();
    await File("${SettingsController.inst.defaultBackupLocation.value}/Namida Backup - $date.zip").create();
    final sourceDir = Directory(k_DIR_USER_DATA);

    // prepares files

    List<File> filesOnly = [];
    List<Directory> dirsOnly = [];
    for (final f in SettingsController.inst.backupItemslist.toList()) {
      if (FileSystemEntity.typeSync(f) == FileSystemEntityType.file) {
        filesOnly.add(File(f));
      }
      if (FileSystemEntity.typeSync(f) == FileSystemEntityType.directory) {
        dirsOnly.add(Directory(f));
      }
    }
    try {
      for (final d in dirsOnly) {
        try {
          final dirZipFile = File("$k_DIR_USER_DATA/TEMPDIR_${d.path.getFilename}.zip");
          await ZipFile.createFromDirectory(sourceDir: d, zipFile: dirZipFile);
          filesOnly.add(dirZipFile);
        } catch (e) {
          continue;
        }
      }

      final zipFile = File("${SettingsController.inst.defaultBackupLocation.value}/Namida Backup - $date.zip");
      await ZipFile.createFromFiles(sourceDir: sourceDir, files: filesOnly, zipFile: zipFile);

      // after finishing
      final all = sourceDir.listSync();
      for (final one in all) {
        if (one.path.getFilename.startsWith('TEMPDIR_')) {
          await one.delete();
        }
      }
    } catch (e) {
      debugPrint(e.toString());
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
      final dir = Directory(SettingsController.inst.defaultBackupLocation.value);
      final possibleFiles = dir.listSync();

      List<File> filessss = [];
      for (final pf in possibleFiles) {
        if (pf.path.getFilename.startsWith('Namida Backup - ')) {
          if (pf is File) {
            filessss.add(pf);
          }
        }
      }
      // seems like the files are already sorted but anyways
      filessss.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      backupzip = filessss.first;
    } else {
      final filePicked = await FilePicker.platform.pickFiles(allowedExtensions: ['zip'], type: FileType.custom);
      if (filePicked != null) {
        backupzip = File(filePicked.files.first.path!);
      } else {
        return;
      }
    }

    isRestoringBackup.value = true;

    await ZipFile.extractToDirectory(zipFile: backupzip, destinationDir: Directory(k_DIR_USER_DATA));

    // after finishing, extracts zip files inside the main zip
    final all = Directory(k_DIR_USER_DATA).listSync();
    for (final one in all) {
      if (one.path.getFilename.startsWith('TEMPDIR_')) {
        if (one is File) {
          await ZipFile.extractToDirectory(
              zipFile: one, destinationDir: Directory("$k_DIR_USER_DATA/${one.path.getFilename.replaceFirst('TEMPDIR_', '').replaceFirst('.zip', '')}"));
          await one.delete();
        }
      }
    }

    Indexer.inst.refreshLibraryAndCheckForDiff();
    Indexer.inst.updateImageSizeInStorage();
    Indexer.inst.updateVideosSizeInStorage();
    Indexer.inst.updateWaveformSizeInStorage();
    Get.snackbar(Language.inst.RESTORED_BACKUP_SUCCESSFULLY, Language.inst.RESTORED_BACKUP_SUCCESSFULLY_SUB);
    isRestoringBackup.value = false;
  }
}
