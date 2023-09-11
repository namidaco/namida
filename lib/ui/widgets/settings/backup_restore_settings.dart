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
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/circular_percentages.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/ui/widgets/settings_card.dart';

class BackupAndRestore extends StatelessWidget {
  const BackupAndRestore({super.key});

  bool _canDoImport() {
    if (JsonToHistoryParser.inst.isParsing.value || HistoryController.inst.isLoadingHistory) {
      Get.snackbar(lang.NOTE, lang.ANOTHER_PROCESS_IS_RUNNING);
      return false;
    }
    return true;
  }

  Widget getDivider() => const NamidaContainerDivider(margin: EdgeInsets.symmetric(vertical: 8.0));

  Widget matchAllTracksListTile({required bool active, required void Function() onTap, required bool displayPerfWarning}) {
    return ListTileWithCheckMark(
      title: lang.MATCH_ALL_TRACKS,
      subtitle: displayPerfWarning ? '${lang.NOTE}: ${lang.MATCH_ALL_TRACKS_NOTE}' : '',
      active: active,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: lang.BACKUP_AND_RESTORE,
      subtitle: lang.BACKUP_AND_RESTORE_SUBTITLE,
      icon: Broken.refresh_circle,
      child: Column(
        children: [
          // TODO(feat): option inside namida to move track in android.

          // -- Create Backup
          CustomListTile(
            title: lang.CREATE_BACKUP,
            icon: Broken.box_add,
            trailingRaw: ObxShow(
              showIf: BackupController.inst.isCreatingBackup,
              child: const LoadingIndicator(),
            ),
            onTap: () {
              bool isActive(List<String> items) => items.every((element) => settings.backupItemslist.contains(element));

              void onItemTap(List<String> items) {
                if (isActive(items)) {
                  settings.removeFromList(backupItemslistAll: items);
                } else {
                  settings.save(backupItemslist: items);
                }
              }

              Widget getItemWidget({required String title, required IconData icon, required List<String> items}) {
                return ListTileWithCheckMark(
                  active: isActive(items),
                  title: title,
                  icon: icon,
                  onTap: () => onItemTap(items),
                );
              }

              NamidaNavigator.inst.navigateDialog(
                dialog: Obx(
                  () => CustomBlurryDialog(
                    title: lang.CREATE_BACKUP,
                    actions: [
                      const CancelButton(),
                      NamidaButton(
                        text: lang.CREATE_BACKUP,
                        onPressed: () {
                          if (settings.backupItemslist.isNotEmpty) {
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
                            getItemWidget(title: lang.DATABASE, icon: Broken.box_1, items: [
                              AppPaths.TRACKS,
                              AppPaths.TRACKS_STATS,
                              AppPaths.TOTAL_LISTEN_TIME,
                              AppPaths.VIDEOS_CACHE,
                              AppPaths.VIDEOS_LOCAL,
                            ]),
                            const SizedBox(height: 12.0),
                            getItemWidget(
                              title: lang.PLAYLISTS,
                              icon: Broken.music_library_2,
                              items: [
                                AppDirs.PLAYLISTS,
                                AppPaths.FAVOURITES_PLAYLIST,
                                AppDirs.YOUTUBE_PLAYLISTS,
                                AppPaths.YT_FAVOURITES_PLAYLIST,
                              ],
                            ),
                            const SizedBox(height: 12.0),
                            getItemWidget(
                              title: lang.HISTORY,
                              icon: Broken.refresh,
                              items: [AppDirs.HISTORY_PLAYLIST],
                            ),
                            const SizedBox(height: 12.0),
                            getItemWidget(
                              title: lang.SETTINGS,
                              icon: Broken.setting,
                              items: [AppPaths.SETTINGS],
                            ),
                            const SizedBox(height: 12.0),
                            getItemWidget(
                              title: lang.LYRICS,
                              icon: Broken.document,
                              items: [AppDirs.LYRICS],
                            ),
                            const SizedBox(height: 12.0),
                            getItemWidget(
                              title: lang.QUEUES,
                              icon: Broken.driver,
                              items: [AppDirs.QUEUES, AppPaths.LATEST_QUEUE],
                            ),
                            const SizedBox(height: 12.0),
                            getItemWidget(
                              title: lang.COLOR_PALETTES,
                              icon: Broken.colorfilter,
                              items: [AppDirs.PALETTES],
                            ),
                            const SizedBox(height: 12.0),
                            getItemWidget(
                              title: lang.VIDEO_CACHE,
                              icon: Broken.video,
                              items: [AppDirs.VIDEOS_CACHE],
                            ),
                            const SizedBox(height: 12.0),
                            getItemWidget(
                              title: lang.ARTWORKS,
                              icon: Broken.image,
                              items: [AppDirs.ARTWORKS],
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
            title: lang.RESTORE_BACKUP,
            icon: Broken.back_square,
            trailingRaw: ObxShow(
              showIf: BackupController.inst.isRestoringBackup,
              child: const LoadingIndicator(),
            ),
            onTap: () async {
              NamidaNavigator.inst.navigateDialog(
                dialog: CustomBlurryDialog(
                  normalTitleStyle: true,
                  title: lang.RESTORE_BACKUP,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        CustomListTile(
                          title: lang.AUTOMATIC_BACKUP,
                          subtitle: lang.AUTOMATIC_BACKUP_SUBTITLE,
                          icon: Broken.autobrightness,
                          maxSubtitleLines: 22,
                          onTap: () => BackupController.inst.restoreBackupOnTap(true),
                        ),
                        CustomListTile(
                          title: lang.MANUAL_BACKUP,
                          subtitle: lang.MANUAL_BACKUP_SUBTITLE,
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
              title: lang.DEFAULT_BACKUP_LOCATION,
              icon: Broken.direct_inbox,
              subtitle: settings.defaultBackupLocation.value,
              onTap: () async {
                final path = await FilePicker.platform.getDirectoryPath();

                if (path != null) {
                  settings.save(defaultBackupLocation: path);
                }
              },
            ),
          ),

          // -- Import Youtube History
          CustomListTile(
            title: lang.IMPORT_YOUTUBE_HISTORY,
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
                  title: lang.GUIDE,
                  actions: [
                    NamidaButton(
                      text: lang.CONFIRM,
                      onPressed: () async {
                        NamidaNavigator.inst.closeDialog();

                        Widget getTitleText(String text) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0).add(const EdgeInsets.only(bottom: 10.0)),
                              child: Text("- $text", style: Get.textTheme.displayLarge),
                            );

                        final jsonfile = await FilePicker.platform.pickFiles(allowedExtensions: ['json'], type: FileType.custom);
                        if (jsonfile != null) {
                          final RxBool isMatchingTypeLink = true.obs;
                          final RxBool isMatchingTypeTitleAndArtist = false.obs;
                          final RxBool matchYT = true.obs;
                          final RxBool matchYTMusic = true.obs;
                          final RxBool matchAll = false.obs;
                          final oldestDate = Rxn<DateTime>();
                          DateTime? newestDate;
                          NamidaNavigator.inst.navigateDialog(
                            dialog: CustomBlurryDialog(
                              title: lang.CONFIGURE,
                              actions: [
                                Obx(
                                  () => NamidaButton(
                                    enabled: isMatchingTypeLink.value || isMatchingTypeTitleAndArtist.value,
                                    textWidget: Obx(() => Text(oldestDate.value != null ? lang.IMPORT_TIME_RANGE : lang.IMPORT_ALL)),
                                    onPressed: () async {
                                      NamidaNavigator.inst.closeDialog();
                                      await JsonToHistoryParser.inst.addFileSourceToNamidaHistory(
                                        file: File(jsonfile.files.first.path!),
                                        source: TrackSource.youtube,
                                        ytIsMatchingTypeLink: isMatchingTypeLink.value,
                                        isMatchingTypeTitleAndArtist: isMatchingTypeTitleAndArtist.value,
                                        ytMatchYT: matchYT.value,
                                        ytMatchYTMusic: matchYTMusic.value,
                                        oldestDate: oldestDate.value,
                                        newestDate: newestDate,
                                        matchAll: matchAll.value,
                                      );
                                    },
                                  ),
                                )
                              ],
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  getTitleText(lang.SOURCE),
                                  Obx(
                                    () => ListTileWithCheckMark(
                                      active: matchYT.value,
                                      title: lang.YOUTUBE,
                                      onTap: () => matchYT.value = !matchYT.value,
                                    ),
                                  ),
                                  const SizedBox(height: 8.0),
                                  Obx(
                                    () => ListTileWithCheckMark(
                                      active: matchYTMusic.value,
                                      title: lang.YOUTUBE_MUSIC,
                                      onTap: () => matchYTMusic.value = !matchYTMusic.value,
                                    ),
                                  ),
                                  getDivider(),
                                  getTitleText(lang.MATCHING_TYPE),
                                  Obx(
                                    () => ListTileWithCheckMark(
                                      active: isMatchingTypeLink.value,
                                      title: lang.LINK,
                                      onTap: () => isMatchingTypeLink.value = !isMatchingTypeLink.value,
                                    ),
                                  ),
                                  const SizedBox(height: 8.0),
                                  Obx(
                                    () => ListTileWithCheckMark(
                                      active: isMatchingTypeTitleAndArtist.value,
                                      title: [lang.TITLE, lang.ARTIST].join(' & '),
                                      onTap: () => isMatchingTypeTitleAndArtist.value = !isMatchingTypeTitleAndArtist.value,
                                    ),
                                  ),
                                  getDivider(),
                                  Obx(
                                    () => matchAllTracksListTile(
                                      active: matchAll.value,
                                      onTap: () => matchAll.value = !matchAll.value,
                                      displayPerfWarning: isMatchingTypeTitleAndArtist.value, // link matching wont result in perf issue
                                    ),
                                  ),
                                  getDivider(),
                                  BetweenDatesTextButton(
                                    useHistoryDates: false,
                                    maxToday: true,
                                    onConfirm: (dates) {
                                      oldestDate.value = dates.firstOrNull;
                                      newestDate = dates.lastOrNull;
                                      NamidaNavigator.inst.closeDialog();
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
                    text: lang.IMPORT_YOUTUBE_HISTORY_GUIDE.replaceFirst('_TAKEOUT_LINK_', 'https://takeout.google.com/takeout/custom/youtube'),
                  ),
                ),
              );
            },
          ),

          // -- Import last.fm History
          CustomListTile(
            title: lang.IMPORT_LAST_FM_HISTORY,
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
                  title: lang.GUIDE,
                  actions: [
                    NamidaButton(
                      text: lang.CONFIRM,
                      onPressed: () async {
                        NamidaNavigator.inst.closeDialog();

                        final csvFiles = await FilePicker.platform.pickFiles(allowedExtensions: ['csv'], type: FileType.custom);
                        final csvFilePath = csvFiles?.files.first.path;
                        if (csvFiles != null && csvFilePath != null) {
                          final oldestDate = Rxn<DateTime>();
                          DateTime? newestDate;
                          final matchAll = false.obs;
                          NamidaNavigator.inst.navigateDialog(
                            dialog: CustomBlurryDialog(
                              insetPadding: const EdgeInsets.all(38.0),
                              title: lang.CONFIGURE,
                              actions: [
                                const CancelButton(),
                                NamidaButton(
                                  textWidget: Obx(() => Text(oldestDate.value != null ? lang.IMPORT_TIME_RANGE : lang.IMPORT_ALL)),
                                  onPressed: () async {
                                    NamidaNavigator.inst.closeDialog();
                                    await JsonToHistoryParser.inst.addFileSourceToNamidaHistory(
                                      file: File(csvFilePath),
                                      source: TrackSource.lastfm,
                                      oldestDate: oldestDate.value,
                                      newestDate: newestDate,
                                      matchAll: matchAll.value,
                                    );
                                  },
                                )
                              ],
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Obx(
                                    () => matchAllTracksListTile(
                                      active: matchAll.value,
                                      onTap: () => matchAll.value = !matchAll.value,
                                      displayPerfWarning: true,
                                    ),
                                  ),
                                  getDivider(),
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
                    text: lang.IMPORT_LAST_FM_HISTORY_GUIDE.replaceFirst('_LASTFM_CSV_LINK_', 'https://benjaminbenben.com/lastfm-to-csv/'),
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
