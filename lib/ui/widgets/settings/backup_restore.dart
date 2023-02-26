// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extras.dart';
import 'package:namida/ui/widgets/settings_card.dart';

import 'package:namida/main.dart';

final RxBool isCreatingBackup = false.obs;
final RxBool isRestoringBackup = false.obs;

class BackupAndRestore extends StatelessWidget {
  const BackupAndRestore({super.key});
  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: Language.inst.BACKUP_AND_RESTORE,
      subtitle: Language.inst.BACKUP_AND_RESTORE_SUBTITLE,
      icon: Broken.refresh_circle,
      child: Column(
        children: [
          Obx(
            () => CustomListTile(
              title: Language.inst.CREATE_BACKUP,
              icon: Broken.back_square,
              trailing: isCreatingBackup.value ? const LoadingIndicator() : null,
              onTap: () {
                void onItemTap(String item) {
                  if (SettingsController.inst.backupItemslist.contains(item)) {
                    SettingsController.inst.removeFromList(backupItemslist1: item);
                  } else {
                    SettingsController.inst.save(backupItemslist: [item]);
                  }
                }

                bool isActive(String item) => SettingsController.inst.backupItemslist.contains(item);

                Get.dialog(
                  Obx(
                    () => CustomBlurryDialog(
                      title: Language.inst.CREATE_BACKUP,
                      actions: [
                        const CancelButton(),
                        ElevatedButton(
                          onPressed: () {
                            Get.close(1);
                            createBackupFile();
                          },
                          child: Text(Language.inst.CREATE_BACKUP),
                        ),
                      ],
                      child: SizedBox(
                        height: Get.height / 2,
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              ListTileWithCheckMark(
                                active: isActive(kTracksFilePath),
                                title: Language.inst.DATABASE,
                                icon: Broken.box_1,
                                onTap: () => onItemTap(kTracksFilePath),
                              ),
                              const SizedBox(
                                height: 12.0,
                              ),
                              ListTileWithCheckMark(
                                active: isActive(kPlaylistsFilePath),
                                title: Language.inst.PLAYLISTS,
                                icon: Broken.music_library_2,
                                onTap: () => onItemTap(kPlaylistsFilePath),
                              ),
                              const SizedBox(
                                height: 12.0,
                              ),
                              ListTileWithCheckMark(
                                active: isActive(kSettingsFilePath),
                                title: Language.inst.SETTINGS,
                                icon: Broken.setting,
                                onTap: () => onItemTap(kSettingsFilePath),
                              ),
                              const SizedBox(
                                height: 12.0,
                              ),
                              ListTileWithCheckMark(
                                active: isActive(kWaveformDirPath),
                                title: Language.inst.WAVEFORMS,
                                icon: Broken.sound,
                                onTap: () => onItemTap(kWaveformDirPath),
                              ),
                              const SizedBox(
                                height: 12.0,
                              ),
                              ListTileWithCheckMark(
                                active: isActive(kQueueFilePath),
                                title: Language.inst.QUEUE,
                                icon: Broken.quote_up,
                                onTap: () => onItemTap(kQueueFilePath),
                              ),
                              const SizedBox(
                                height: 12.0,
                              ),
                              ListTileWithCheckMark(
                                active: isActive(kVideosCachePath),
                                title: Language.inst.VIDEO_CACHE,
                                icon: Broken.video,
                                onTap: () => onItemTap(kVideosCachePath),
                              ),
                              const SizedBox(
                                height: 12.0,
                              ),
                              ListTileWithCheckMark(
                                active: isActive(kArtworksDirPath),
                                title: Language.inst.ARTWORKS,
                                icon: Broken.image,
                                onTap: () => onItemTap(kArtworksDirPath),
                              ),
                              const SizedBox(
                                height: 12.0,
                              ),
                              ListTileWithCheckMark(
                                active: isActive(kArtworksCompDirPath),
                                title: Language.inst.ARTWORKS_COMPRESSED,
                                icon: Broken.gallery,
                                onTap: () => onItemTap(kArtworksCompDirPath),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Obx(
            () => CustomListTile(
              title: Language.inst.RESTORE_BACKUP,
              icon: Broken.direct_inbox,
              trailing: isRestoringBackup.value ? const LoadingIndicator() : null,
              onTap: () async {
                await Get.dialog(
                  CustomBlurryDialog(
                    normalTitleStyle: true,
                    title: Language.inst.RESTORE_BACKUP,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          CustomListTile(
                            title: Language.inst.AUTOMATIC_BACKUP,
                            subtitle: Language.inst.AUTOMATIC_BACKUP_SUBTITLE,
                            icon: Broken.autobrightness,
                            maxSubtitleLines: 22,
                            onTap: () => restoreBackupOnTap(true),
                          ),
                          CustomListTile(
                            title: Language.inst.MANUAL_BACKUP,
                            subtitle: Language.inst.MANUAL_BACKUP_SUBTITLE,
                            maxSubtitleLines: 22,
                            icon: Broken.hashtag,
                            onTap: () => restoreBackupOnTap(false),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Obx(
            () => CustomListTile(
              title: Language.inst.DEFAULT_BACKUP_LOCATION,
              icon: Broken.direct_inbox,
              subtitle: SettingsController.inst.defaultBackupLocation.value,
              onTap: () async {
                final path = await FilePicker.platform.getDirectoryPath();

                /// resets SAF in case folder was changed
                if (path != SettingsController.inst.defaultBackupLocation.value) {
                  await resetSAFPermision();
                }
                if (path != null) {
                  SettingsController.inst.save(defaultBackupLocation: path);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> createBackupFile() async {
  if (!await requestManageStoragePermission()) {
    return;
  }
  isCreatingBackup.value = true;

  // formats date
  final format = DateFormat('yyyy-MM-dd hh.mm.ss');
  final date = format.format(DateTime.now().toLocal());

  // creates directories and file
  await Directory(kInternalAppDirectoryPath).create();
  await File("$kInternalAppDirectoryPath/Namida Backup - $date.zip").create();
  final sourceDir = Directory(kAppDirectoryPath);

  // prepares files

  List<File> filesOnly = [];
  List<Directory> dirsOnly = [];
  for (var f in SettingsController.inst.backupItemslist.toList()) {
    if (FileSystemEntity.typeSync(f) == FileSystemEntityType.file) {
      filesOnly.add(File(f));
    }
    if (FileSystemEntity.typeSync(f) == FileSystemEntityType.directory) {
      dirsOnly.add(Directory(f));
    }
  }
  try {
    for (var d in dirsOnly) {
      try {
        final dirZipFile = File("$kAppDirectoryPath/TEMPDIR_${p.basename(d.path)}.zip");
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
    for (var one in all) {
      if (p.basename(one.path).startsWith('TEMPDIR_')) {
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
  Get.close(1);
  File? backupzip;
  if (auto) {
    final dir = Directory(SettingsController.inst.defaultBackupLocation.value);
    final possibleFiles = dir.listSync();

    List<File> filessss = [];
    for (var pf in possibleFiles) {
      if (p.basename(pf.path).startsWith('Namida Backup - ')) {
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

  await ZipFile.extractToDirectory(zipFile: backupzip, destinationDir: Directory(kAppDirectoryPath));

  // after finishing, extracts zip files inside the main zip
  final all = Directory(kAppDirectoryPath).listSync();
  for (var one in all) {
    if (p.basename(one.path).startsWith('TEMPDIR_')) {
      if (one is File) {
        await ZipFile.extractToDirectory(
            zipFile: one, destinationDir: Directory("$kAppDirectoryPath/${p.basename(one.path).replaceFirst('TEMPDIR_', '').replaceFirst('.zip', '')}"));
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
