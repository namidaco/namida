import 'dart:io';

import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';

import 'package:namida/controller/backup_controller.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/json_to_history_parser.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/main.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/circular_percentages.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/ui/widgets/settings_card.dart';

class BackupAndRestore extends StatelessWidget {
  const BackupAndRestore({super.key});

  bool _canDoImport() {
    if (JsonToHistoryParser.inst.isParsing.value || HistoryController.inst.isLoadingHistory) {
      Get.snackbar(Language.inst.NOTE, Language.inst.ANOTHER_PROCESS_IS_RUNNING);
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: Language.inst.BACKUP_AND_RESTORE,
      subtitle: Language.inst.BACKUP_AND_RESTORE_SUBTITLE,
      icon: Broken.refresh_circle,
      child: Column(
        children: [
          // TODO(feat): change specific file/folder new path.
          // TODO(feat): option inside namida to move track in android.

          // -- Create Backup
          CustomListTile(
            title: Language.inst.CREATE_BACKUP,
            icon: Broken.box_add,
            trailingRaw: ObxShow(
              showIf: BackupController.inst.isCreatingBackup,
              child: const LoadingIndicator(),
            ),
            onTap: () {
              void onItemTap(String item) {
                if (SettingsController.inst.backupItemslist.contains(item)) {
                  SettingsController.inst.removeFromList(backupItemslist1: item);
                } else {
                  SettingsController.inst.save(backupItemslist: [item]);
                }
              }

              bool isActive(String item) => SettingsController.inst.backupItemslist.contains(item);

              NamidaNavigator.inst.navigateDialog(
                dialog: Obx(
                  () => CustomBlurryDialog(
                    title: Language.inst.CREATE_BACKUP,
                    actions: [
                      const CancelButton(),
                      NamidaButton(
                        text: Language.inst.CREATE_BACKUP,
                        onPressed: () {
                          if (SettingsController.inst.backupItemslist.isNotEmpty) {
                            NamidaNavigator.inst.closeDialog();
                            BackupController.inst.createBackupFile();
                          }
                        },
                      ),
                    ],
                    child: SizedBox(
                      height: Get.height / 2,
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            ListTileWithCheckMark(
                              active: isActive(k_FILE_PATH_TRACKS) && isActive(k_FILE_PATH_TRACKS_STATS) && isActive(k_FILE_PATH_TOTAL_LISTEN_TIME),
                              title: Language.inst.DATABASE,
                              icon: Broken.box_1,
                              onTap: () {
                                onItemTap(k_FILE_PATH_TRACKS);
                                onItemTap(k_FILE_PATH_TRACKS_STATS);
                                onItemTap(k_FILE_PATH_TOTAL_LISTEN_TIME);
                              },
                            ),
                            const SizedBox(
                              height: 12.0,
                            ),
                            ListTileWithCheckMark(
                              active: isActive(k_DIR_PLAYLISTS) && isActive(k_PLAYLIST_PATH_FAVOURITES),
                              title: Language.inst.PLAYLISTS,
                              icon: Broken.music_library_2,
                              onTap: () {
                                onItemTap(k_DIR_PLAYLISTS);
                                onItemTap(k_PLAYLIST_PATH_FAVOURITES);
                              },
                            ),
                            const SizedBox(
                              height: 12.0,
                            ),
                            ListTileWithCheckMark(
                              active: isActive(k_PLAYLIST_DIR_PATH_HISTORY),
                              title: Language.inst.HISTORY,
                              icon: Broken.refresh,
                              onTap: () => onItemTap(k_PLAYLIST_DIR_PATH_HISTORY),
                            ),
                            const SizedBox(
                              height: 12.0,
                            ),
                            ListTileWithCheckMark(
                              active: isActive(k_FILE_PATH_SETTINGS),
                              title: Language.inst.SETTINGS,
                              icon: Broken.setting,
                              onTap: () => onItemTap(k_FILE_PATH_SETTINGS),
                            ),
                            const SizedBox(
                              height: 12.0,
                            ),
                            ListTileWithCheckMark(
                              active: isActive(k_DIR_WAVEFORMS),
                              title: Language.inst.WAVEFORMS,
                              icon: Broken.sound,
                              onTap: () => onItemTap(k_DIR_WAVEFORMS),
                            ),
                            const SizedBox(
                              height: 12.0,
                            ),
                            ListTileWithCheckMark(
                              active: isActive(k_DIR_LYRICS),
                              title: Language.inst.LYRICS,
                              icon: Broken.document,
                              onTap: () => onItemTap(k_DIR_LYRICS),
                            ),
                            const SizedBox(
                              height: 12.0,
                            ),
                            ListTileWithCheckMark(
                              active: isActive(k_DIR_QUEUES) && isActive(k_FILE_PATH_LATEST_QUEUE),
                              title: Language.inst.QUEUES,
                              icon: Broken.driver,
                              onTap: () {
                                onItemTap(k_DIR_QUEUES);
                                onItemTap(k_FILE_PATH_LATEST_QUEUE);
                              },
                            ),
                            const SizedBox(
                              height: 12.0,
                            ),
                            ListTileWithCheckMark(
                              active: isActive(k_DIR_PALETTES),
                              title: Language.inst.COLOR_PALETTES,
                              icon: Broken.colorfilter,
                              onTap: () => onItemTap(k_DIR_PALETTES),
                            ),
                            const SizedBox(
                              height: 12.0,
                            ),
                            ListTileWithCheckMark(
                              active: isActive(k_DIR_VIDEOS_CACHE),
                              title: Language.inst.VIDEO_CACHE,
                              icon: Broken.video,
                              onTap: () => onItemTap(k_DIR_VIDEOS_CACHE),
                            ),
                            const SizedBox(
                              height: 12.0,
                            ),
                            ListTileWithCheckMark(
                              active: isActive(k_DIR_ARTWORKS),
                              title: Language.inst.ARTWORKS,
                              icon: Broken.image,
                              onTap: () => onItemTap(k_DIR_ARTWORKS),
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

          // -- Restore Backup
          CustomListTile(
            title: Language.inst.RESTORE_BACKUP,
            icon: Broken.back_square,
            trailingRaw: ObxShow(
              showIf: BackupController.inst.isRestoringBackup,
              child: const LoadingIndicator(),
            ),
            onTap: () async {
              NamidaNavigator.inst.navigateDialog(
                dialog: CustomBlurryDialog(
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
                          onTap: () => BackupController.inst.restoreBackupOnTap(true),
                        ),
                        CustomListTile(
                          title: Language.inst.MANUAL_BACKUP,
                          subtitle: Language.inst.MANUAL_BACKUP_SUBTITLE,
                          maxSubtitleLines: 22,
                          icon: Broken.hashtag,
                          onTap: () => BackupController.inst.restoreBackupOnTap(false),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // -- Default Backup Location
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

          // -- Import Youtube History
          CustomListTile(
            title: Language.inst.IMPORT_YOUTUBE_HISTORY,
            leading: StackedIcon(
              baseIcon: Broken.import_2,
              smallChild: ClipRRect(
                borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                child: Image.asset(
                  'assets/icons/youtube.png',
                  width: 12,
                  height: 12,
                ),
              ),
            ),
            trailing: const SizedBox(
              height: 32.0,
              width: 32.0,
              child: ParsingJsonPercentage(
                size: 32.0,
                source: TrackSource.youtube,
                forceDisplay: false,
              ),
            ),
            onTap: () {
              if (!_canDoImport()) return;

              NamidaNavigator.inst.navigateDialog(
                dialog: CustomBlurryDialog(
                  title: Language.inst.GUIDE,
                  actions: [
                    NamidaButton(
                      text: Language.inst.CONFIRM,
                      onPressed: () async {
                        NamidaNavigator.inst.closeDialog();
                        final jsonfile = await FilePicker.platform.pickFiles(allowedExtensions: ['json'], type: FileType.custom);

                        if (jsonfile != null) {
                          final RxBool isMatchingTypeLink = true.obs;
                          final RxBool matchYT = true.obs;
                          final RxBool matchYTMusic = true.obs;
                          DateTime? oldestDate;
                          DateTime? newestDate;
                          NamidaNavigator.inst.navigateDialog(
                            dialog: CustomBlurryDialog(
                              title: Language.inst.CONFIGURE,
                              actions: [
                                NamidaButton(
                                  text: Language.inst.CONFIRM,
                                  onPressed: () async {
                                    NamidaNavigator.inst.closeDialog();
                                    await JsonToHistoryParser.inst.addFileSourceToNamidaHistory(
                                      File(jsonfile.files.first.path!),
                                      TrackSource.youtube,
                                      isMatchingTypeLink: isMatchingTypeLink.value,
                                      matchYT: matchYT.value,
                                      matchYTMusic: matchYTMusic.value,
                                      oldestDate: oldestDate,
                                      newestDate: newestDate,
                                    );
                                  },
                                )
                              ],
                              child: Obx(
                                () => Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CustomListTile(
                                      title: Language.inst.SOURCE,
                                      largeTitle: true,
                                    ),
                                    ListTileWithCheckMark(
                                      active: matchYT.value,
                                      title: Language.inst.YOUTUBE,
                                      onTap: () => matchYT.value = !matchYT.value,
                                    ),
                                    const SizedBox(height: 12.0),
                                    ListTileWithCheckMark(
                                      active: matchYTMusic.value,
                                      title: Language.inst.YOUTUBE_MUSIC,
                                      onTap: () => matchYTMusic.value = !matchYTMusic.value,
                                    ),
                                    CustomListTile(
                                      title: Language.inst.MATCHING_TYPE,
                                      largeTitle: true,
                                    ),
                                    ListTileWithCheckMark(
                                      active: !isMatchingTypeLink.value,
                                      title: [Language.inst.TITLE, Language.inst.ARTIST].join(' & '),
                                      onTap: () => isMatchingTypeLink.value = !isMatchingTypeLink.value,
                                    ),
                                    const SizedBox(height: 12.0),
                                    ListTileWithCheckMark(
                                      active: isMatchingTypeLink.value,
                                      title: Language.inst.LINK,
                                      onTap: () => isMatchingTypeLink.value = !isMatchingTypeLink.value,
                                    ),
                                    const SizedBox(height: 18.0),
                                    BetweenDatesTextButton(
                                      useHistoryDates: false,
                                      maxToday: true,
                                      onConfirm: (dates) {
                                        oldestDate = dates.firstOrNull;
                                        newestDate = dates.lastOrNull;
                                        NamidaNavigator.inst.closeDialog();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                  child: NamidaSelectableAutoLinkText(
                    text: Language.inst.IMPORT_YOUTUBE_HISTORY_GUIDE.replaceFirst('_TAKEOUT_LINK_', 'https://takeout.google.com'),
                  ),
                ),
              );
            },
          ),

          // -- Import last.fm History
          CustomListTile(
            title: Language.inst.IMPORT_LAST_FM_HISTORY,
            leading: StackedIcon(
              baseIcon: Broken.import_2,
              smallChild: ClipRRect(
                borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                child: Image.asset(
                  'assets/icons/lastfm.png',
                  width: 12,
                  height: 12,
                ),
              ),
            ),
            trailing: const SizedBox(
              height: 32.0,
              width: 32.0,
              child: ParsingJsonPercentage(
                size: 32.0,
                source: TrackSource.lastfm,
                forceDisplay: false,
              ),
            ),
            onTap: () {
              if (!_canDoImport()) return;

              NamidaNavigator.inst.navigateDialog(
                dialog: CustomBlurryDialog(
                  title: Language.inst.GUIDE,
                  actions: [
                    NamidaButton(
                      text: Language.inst.CONFIRM,
                      onPressed: () async {
                        NamidaNavigator.inst.closeDialog();
                        final csvFiles = await FilePicker.platform.pickFiles(allowedExtensions: ['csv'], type: FileType.custom);
                        final csvFilePath = csvFiles?.files.first.path;
                        if (csvFiles != null && csvFilePath != null) {
                          final oldestDate = Rxn<DateTime>();
                          DateTime? newestDate;
                          NamidaNavigator.inst.navigateDialog(
                            dialog: CustomBlurryDialog(
                              insetPadding: const EdgeInsets.all(38.0),
                              title: Language.inst.CHOOSE,
                              actions: [
                                const CancelButton(),
                                NamidaButton(
                                  textWidget: Obx(() => Text(oldestDate.value != null ? Language.inst.IMPORT_TIME_RANGE : Language.inst.IMPORT_ALL)),
                                  onPressed: () async {
                                    NamidaNavigator.inst.closeDialog();
                                    await JsonToHistoryParser.inst.addFileSourceToNamidaHistory(
                                      File(csvFilePath),
                                      TrackSource.lastfm,
                                      oldestDate: oldestDate.value,
                                      newestDate: newestDate,
                                    );
                                  },
                                )
                              ],
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    Language.inst.IMPORT_TIME_RANGE_PROMPT,
                                    style: Get.textTheme.displayMedium,
                                  ),
                                  const SizedBox(height: 12.0),
                                  BetweenDatesTextButton(
                                    useHistoryDates: false,
                                    maxToday: true,
                                    onConfirm: (dates) {
                                      NamidaNavigator.inst.closeDialog();
                                      oldestDate.value = dates.firstOrNull;
                                      newestDate = dates.lastOrNull;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                  child: NamidaSelectableAutoLinkText(
                    text: Language.inst.IMPORT_LAST_FM_HISTORY_GUIDE.replaceFirst('_LASTFM_CSV_LINK_', 'https://benjaminbenben.com/lastfm-to-csv/'),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
