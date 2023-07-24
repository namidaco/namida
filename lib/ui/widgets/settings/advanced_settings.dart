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
import 'package:namida/core/translations/language.dart';
import 'package:namida/packages/youtube_miniplayer.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/ui/widgets/settings_card.dart';

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

              final RxMap<TrackSource, int> sourcesMap = <TrackSource, int>{}.obs;
              void resetSourcesMap() {
                TrackSource.values.loop((e, index) {
                  sourcesMap[e] = 0;
                });
              }

              final RxInt totalTracksToBeRemoved = 0.obs;

              final RxInt totalTracksBetweenDates = 0.obs;

              void calculateTotalTracks(DateTime? oldest, DateTime? newest) {
                final sussyDays = HistoryController.inst.historyDays.toList();
                final isBetweenDays = oldest != null && newest != null;
                if (isBetweenDays) {
                  final oldestDay = oldest.millisecondsSinceEpoch.toDaysSinceEpoch();
                  final newestDay = newest.millisecondsSinceEpoch.toDaysSinceEpoch();

                  sussyDays.retainWhere((element) => element >= oldestDay && element <= newestDay);
                  printy(sussyDays);
                }
                resetSourcesMap();
                sussyDays.loop((d, index) {
                  final tracks = HistoryController.inst.historyMap.value[d] ?? [];
                  tracks.loop((twd, index) {
                    sourcesMap.update(twd.source, (value) => value + 1, ifAbsent: () => 1);
                  });
                });
                if (isBetweenDays) {
                  totalTracksBetweenDates.value = sourcesMap.values.reduce((value, element) => value + element);
                }
                if (sourcesToDelete.isNotEmpty) {
                  totalTracksToBeRemoved.value = 0;
                  sourcesToDelete.loop((e, index) {
                    totalTracksToBeRemoved.value += sourcesMap[e] ?? 0;
                  });
                }
              }

              // -- filling each source with its tracks number.
              calculateTotalTracks(null, null);

              DateTime? oldestDate;
              DateTime? newestDate;

              NamidaNavigator.inst.navigateDialog(
                dialog: CustomBlurryDialog(
                  title: Language.inst.CHOOSE,
                  actions: [
                    const CancelButton(),
                    NamidaButton(
                      text: Language.inst.REMOVE,
                      onPressed: () async {
                        final removedNum = await HistoryController.inst.removeSourcesTracksFromHistory(
                          sourcesToDelete,
                          oldestDate: oldestDate,
                          newestDate: newestDate,
                        );
                        NamidaNavigator.inst.closeDialog();
                        Get.snackbar(Language.inst.NOTE, "${Language.inst.REMOVED} ${removedNum.displayTrackKeyword}");
                      },
                    )
                  ],
                  child: Obx(
                    () => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12.0),
                        Row(
                          children: [
                            const SizedBox(width: 8.0),
                            const Icon(Broken.danger),
                            const SizedBox(width: 8.0),
                            Obx(() => Text(
                                  '${Language.inst.TOTAL_TRACKS}: ${totalTracksToBeRemoved.value}',
                                  style: context.textTheme.displayMedium,
                                )),
                          ],
                        ),
                        const SizedBox(height: 12.0),
                        ...sourcesMap.entries.map(
                          (e) {
                            final source = e.key;
                            final count = e.value;
                            return Padding(
                              padding: const EdgeInsets.only(top: 10.0),
                              child: Obx(
                                () => ListTileWithCheckMark(
                                  active: isActive(source),
                                  title: '${source.convertToString} (${count.formatDecimal()})',
                                  onTap: () {
                                    if (isActive(source)) {
                                      sourcesToDelete.remove(source);
                                      totalTracksToBeRemoved.value -= count;
                                    } else {
                                      sourcesToDelete.add(source);
                                      totalTracksToBeRemoved.value += count;
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12.0),
                        BetweenDatesTextButton(
                          useHistoryDates: true,
                          onConfirm: (dates) {
                            oldestDate = dates.firstOrNull;
                            newestDate = dates.lastOrNull;
                            calculateTotalTracks(oldestDate, newestDate);
                            NamidaNavigator.inst.closeDialog();
                          },
                          tracksLength: totalTracksBetweenDates.value,
                        ),
                      ],
                    ),
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
                      NamidaButton(
                        text: Language.inst.CLEAR.toUpperCase(),
                        onPressed: () async {
                          NamidaNavigator.inst.closeDialog();
                          await Indexer.inst.clearImageCache();
                        },
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
                      NamidaButton(
                        text: Language.inst.CLEAR.toUpperCase(),
                        onPressed: () {
                          NamidaNavigator.inst.closeDialog();
                          Indexer.inst.clearWaveformData();
                        },
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
                      NamidaButton(
                        text: Language.inst.CHOOSE,
                        onPressed: () {
                          NamidaNavigator.inst.closeDialog();
                          _showChooseVideosToDeleteDialog(allvideo);
                        },
                      ),
                      const CancelButton(),
                      NamidaButton(
                        text: Language.inst.CLEAR.toUpperCase(),
                        onPressed: () async {
                          NamidaNavigator.inst.closeDialog();
                          await Indexer.inst.clearVideoCache();
                        },
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
          NamidaButton(
            text: Language.inst.CLEAR.toUpperCase(),
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
                    NamidaButton(
                      text: Language.inst.CLEAR.toUpperCase(),
                      onPressed: () async {
                        NamidaNavigator.inst.closeDialog(2);
                        await Indexer.inst.clearVideoCache(videosToDelete);
                      },
                    ),
                  ],
                  bodyText: _getVideoSubtitleText(videosToDelete),
                ),
              );
            },
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
