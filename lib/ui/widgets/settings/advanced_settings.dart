import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter_scrollbar_modified/flutter_scrollbar_modified.dart';
import 'package:checkmark/checkmark.dart';
import 'package:get/get.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/packages/youtube_miniplayer.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/ui/widgets/settings_card.dart';

import 'package:namida/main.dart';

class AdvancedSettings extends StatelessWidget {
  const AdvancedSettings({super.key});

  SettingsController get stg => SettingsController.inst;

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: Language.inst.ADVANCED_SETTINGS,
      subtitle: Language.inst.ADVANCED_SETTINGS_SUBTITLE,
      icon: Broken.hierarchy_3,
      // icon: Broken.danger,
      child: Column(
        children: [
          CustomListTile(
            icon: Broken.code_circle,
            title: Language.inst.RESET_SAF_PERMISSION,
            subtitle: Language.inst.RESET_SAF_PERMISSION_SUBTITLE,
            onTap: () async => await resetSAFPermision(),
          ),
          Obx(
            () => CustomListTile(
              leading: const StackedIcon(
                baseIcon: Broken.video,
                secondaryIcon: Broken.refresh,
              ),
              trailing: VideoController.inst.isUpdatingVideoFiles.value ? const LoadingIndicator() : null,
              title: Language.inst.RESCAN_VIDEOS,
              onTap: () async {
                await VideoController.inst.getVideoFiles(forceRescan: true);
                Get.snackbar(Language.inst.DONE, Language.inst.FINISHED_UPDATING_LIBRARY);
              },
            ),
          ),
          CustomListTile(
            leading: const StackedIcon(
              baseIcon: Broken.trash,
              secondaryIcon: Broken.refresh,
            ),
            title: Language.inst.REMOVE_SOURCE_FROM_HISTORY,
            onTap: () async {
              final RxList<TrackSource> sourcesToDelete = <TrackSource>[].obs;
              bool isActive(TrackSource e) => sourcesToDelete.contains(e);

              NamidaNavigator.inst.navigateDialog(
                dialog: CustomBlurryDialog(
                  title: Language.inst.CHOOSE,
                  actions: [
                    const CancelButton(),
                    ElevatedButton(
                      onPressed: () async {
                        final removedNum = await HistoryController.inst.removeSourcesTracksFromHistory(sourcesToDelete);
                        Get.snackbar(Language.inst.NOTE, "${Language.inst.REMOVED} ${removedNum.displayTrackKeyword}");
                        NamidaNavigator.inst.closeDialog();
                      },
                      child: Text(Language.inst.REMOVE),
                    )
                  ],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...TrackSource.values.map((e) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 10.0),
                          child: Obx(
                            () => ListTileWithCheckMark(
                              active: isActive(e),
                              title: e.convertToString,
                              onTap: () {
                                if (isActive(e)) {
                                  sourcesToDelete.remove(e);
                                } else {
                                  sourcesToDelete.add(e);
                                }
                              },
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 8.0),
                      TextButton.icon(
                        // onPressed: _pickDatesRangeDialog,
                        onPressed: () {},
                        icon: const Icon(Broken.calendar_1),
                        label: const Text('Between Dates'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Obx(
            () => CustomListTile(
              leading: const StackedIcon(
                baseIcon: Broken.image,
                secondaryIcon: Broken.close_circle,
              ),
              title: Language.inst.CLEAR_IMAGE_CACHE,
              trailingText: Indexer.inst.artworksSizeInStorage.value.fileSizeFormatted,
              onTap: () {
                NamidaNavigator.inst.navigateDialog(
                  dialog: CustomBlurryDialog(
                    isWarning: true,
                    normalTitleStyle: true,
                    bodyText: Language.inst.CLEAR_IMAGE_CACHE_WARNING,
                    actions: [
                      const CancelButton(),
                      ElevatedButton(
                        onPressed: () async {
                          NamidaNavigator.inst.closeDialog();
                          await Indexer.inst.clearImageCache();
                        },
                        child: Text(Language.inst.CLEAR.toUpperCase()),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Obx(
            () => CustomListTile(
              leading: const StackedIcon(
                baseIcon: Broken.sound,
                secondaryIcon: Broken.close_circle,
              ),
              title: Language.inst.CLEAR_WAVEFORM_DATA,
              trailingText: Indexer.inst.waveformsSizeInStorage.value.fileSizeFormatted,
              onTap: () {
                NamidaNavigator.inst.navigateDialog(
                  dialog: CustomBlurryDialog(
                    isWarning: true,
                    normalTitleStyle: true,
                    title: Language.inst.CLEAR_WAVEFORM_DATA,
                    bodyText: Language.inst.CLEAR_WAVEFORM_DATA_WARNING,
                    actions: [
                      const CancelButton(),
                      ElevatedButton(
                        onPressed: () {
                          NamidaNavigator.inst.closeDialog();
                          Indexer.inst.clearWaveformData();
                        },
                        child: Text(Language.inst.CLEAR.toUpperCase()),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Obx(
            () => CustomListTile(
              leading: const StackedIcon(
                baseIcon: Broken.video,
                secondaryIcon: Broken.close_circle,
              ),
              title: Language.inst.CLEAR_VIDEO_CACHE,
              trailingText: Indexer.inst.videosSizeInStorage.value.fileSizeFormatted,
              onTap: () async {
                final allvideo = Directory(k_DIR_VIDEOS_CACHE).listSync();
                allvideo.sortByReverse((e) => e.statSync().size);
                allvideo.removeWhere((element) => element is Directory);

                /// First Dialog
                NamidaNavigator.inst.navigateDialog(
                  dialog: CustomBlurryDialog(
                    isWarning: true,
                    normalTitleStyle: true,
                    bodyText: "${_getVideoSubtitleText(allvideo)}\n${Language.inst.CLEAR_VIDEO_CACHE_NOTE}",
                    actions: [
                      /// Pressing Choose
                      ElevatedButton(
                        onPressed: () {
                          NamidaNavigator.inst.closeDialog();
                          _showChooseVideosToDeleteDialog(allvideo);
                        },
                        child: Text(Language.inst.CHOOSE),
                      ),
                      const CancelButton(),
                      ElevatedButton(
                        onPressed: () async {
                          NamidaNavigator.inst.closeDialog();
                          await Indexer.inst.clearVideoCache();
                        },
                        child: Text(Language.inst.CLEAR.toUpperCase()),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getVideoSubtitleText(List<FileSystemEntity> videos) {
    return Language.inst.CLEAR_VIDEO_CACHE_SUBTITLE
        .replaceFirst('_CURRENT_VIDEOS_COUNT_', videos.length.toString())
        .replaceFirst('_TOTAL_SIZE_', videos.map((e) => e.statSync().size).reduce((a, b) => a + b).fileSizeFormatted);
  }

  _showChooseVideosToDeleteDialog(List<FileSystemEntity> videoFiles) {
    RxList<FileSystemEntity> videosToDelete = <FileSystemEntity>[].obs;
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        contentPadding: const EdgeInsets.symmetric(horizontal: 0.0),
        isWarning: true,
        normalTitleStyle: true,
        title: Language.inst.CHOOSE,
        actions: [
          const CancelButton(),

          /// Clear after choosing
          ElevatedButton(
            onPressed: () async {
              if (videosToDelete.isEmpty) {
                return;
              }
              NamidaNavigator.inst.navigateDialog(
                dialog: CustomBlurryDialog(
                  isWarning: true,
                  normalTitleStyle: true,
                  actions: [
                    const CancelButton(),

                    /// final clear confirm
                    ElevatedButton(
                      onPressed: () async {
                        NamidaNavigator.inst.closeDialog(2);
                        await Indexer.inst.clearVideoCache(videosToDelete);
                      },
                      child: Text(Language.inst.CLEAR.toUpperCase()),
                    ),
                  ],
                  bodyText: _getVideoSubtitleText(videosToDelete),
                ),
              );
            },
            child: Text(Language.inst.CLEAR.toUpperCase()),
          ),
        ],
        child: CupertinoScrollbar(
          child: SizedBox(
            width: Get.width,
            height: Get.height / 1.5,
            child: ListView.builder(
              itemCount: videoFiles.length,
              itemBuilder: (context, index) {
                final file = videoFiles[index];
                final quality = file.path.getFilename.split('_').last.split('.').first;
                final id = file.path.getFilename.split('').take(11).join();
                return Obx(
                  () => ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24.0),
                    leading: YoutubeThumbnail(
                      borderRadius: 8.0,
                      url: ThumbnailSet(id).mediumResUrl,
                      width: 70,
                      height: 70 * 9 / 16,
                    ),
                    title: Text(id),
                    subtitle: Text([quality, file.statSync().size.fileSizeFormatted].join(' - ')),
                    trailing: IgnorePointer(
                      child: SizedBox(
                        height: 18.0,
                        width: 18.0,
                        child: CheckMark(
                          strokeWidth: 2,
                          activeColor: context.theme.listTileTheme.iconColor!,
                          inactiveColor: context.theme.listTileTheme.iconColor!,
                          duration: const Duration(milliseconds: 400),
                          active: videosToDelete.contains(file),
                        ),
                      ),
                    ),
                    onTap: () {
                      if (videosToDelete.contains(file)) {
                        videosToDelete.remove(file);
                      } else {
                        videosToDelete.add(file);
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
