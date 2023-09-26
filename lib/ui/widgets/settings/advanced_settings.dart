import 'dart:io';

import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';
import 'package:checkmark/checkmark.dart';
import 'package:flutter_scrollbar_modified/flutter_scrollbar_modified.dart';
import 'package:get/get.dart' hide Response;

import 'package:namida/class/video.dart';
import 'package:namida/controller/edit_delete_controller.dart';
import 'package:namida/controller/ffmpeg_controller.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/main.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/ui/widgets/settings_card.dart';

class AdvancedSettings extends StatelessWidget {
  const AdvancedSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: lang.ADVANCED_SETTINGS,
      subtitle: lang.ADVANCED_SETTINGS_SUBTITLE,
      icon: Broken.hierarchy_3,
      // icon: Broken.danger,
      child: Column(
        children: [
          CustomListTile(
            leading: const StackedIcon(
              baseIcon: Broken.video,
              secondaryIcon: Broken.refresh,
            ),
            trailingRaw: Obx(
              () {
                final current = VideoController.inst.localVideoExtractCurrent.value;
                final total = VideoController.inst.localVideoExtractTotal.value;
                final isCounterVisible = total != 0;
                final isLoadingVisible = current != null;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isCounterVisible) Text("$current/$total"),
                    if (isLoadingVisible) const LoadingIndicator(),
                  ],
                );
              },
            ),
            title: lang.RESCAN_VIDEOS,
            onTap: () async {
              await VideoController.inst.scanLocalVideos(forceReScan: true);
              Get.snackbar(lang.DONE, lang.FINISHED_UPDATING_LIBRARY);
            },
          ),
          CustomListTile(
            leading: const StackedIcon(
              baseIcon: Broken.trash,
              secondaryIcon: Broken.refresh,
            ),
            title: lang.REMOVE_SOURCE_FROM_HISTORY,
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
                  final oldestDay = oldest.toDaysSince1970();
                  final newestDay = newest.toDaysSince1970();

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
                  title: lang.CHOOSE,
                  actions: [
                    const CancelButton(),
                    NamidaButton(
                      text: lang.REMOVE,
                      onPressed: () async {
                        final removedNum = await HistoryController.inst.removeSourcesTracksFromHistory(
                          sourcesToDelete,
                          oldestDate: oldestDate,
                          newestDate: newestDate,
                        );
                        NamidaNavigator.inst.closeDialog();
                        Get.snackbar(lang.NOTE, "${lang.REMOVED} ${removedNum.displayTrackKeyword}");
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
                                  '${lang.TOTAL_TRACKS}: ${totalTracksToBeRemoved.value}',
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
          const UpdateDirectoryPathListTile(),
          // -- this will loop all choosen files, get yt thumbnail (download or cache), edit tags, without affecting file modified time.
          const _FixYTDLPThumbnailSizeListTile(),
          const _CompressImagesListTile(),
          Obx(
            () => CustomListTile(
              leading: const StackedIcon(
                baseIcon: Broken.image,
                secondaryIcon: Broken.close_circle,
              ),
              title: lang.CLEAR_IMAGE_CACHE,
              trailingText: Indexer.inst.artworksSizeInStorage.value.fileSizeFormatted,
              onTap: () {
                NamidaNavigator.inst.navigateDialog(
                  dialog: CustomBlurryDialog(
                    isWarning: true,
                    normalTitleStyle: true,
                    bodyText: lang.CLEAR_IMAGE_CACHE_WARNING,
                    actions: [
                      const CancelButton(),
                      NamidaButton(
                        text: lang.CLEAR.toUpperCase(),
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
                baseIcon: Broken.video,
                secondaryIcon: Broken.close_circle,
              ),
              title: lang.CLEAR_VIDEO_CACHE,
              trailingText: Indexer.inst.videosSizeInStorage.value.fileSizeFormatted,
              onTap: () async {
                final allvideo = VideoController.inst.getCurrentVideosInCache();

                /// First Dialog
                NamidaNavigator.inst.navigateDialog(
                  dialog: CustomBlurryDialog(
                    isWarning: true,
                    normalTitleStyle: true,
                    bodyText: "${_getVideoSubtitleText(allvideo)}\n${lang.CLEAR_VIDEO_CACHE_NOTE}",
                    actions: [
                      /// Pressing Choose
                      NamidaButton(
                        text: lang.CHOOSE,
                        onPressed: () {
                          NamidaNavigator.inst.closeDialog();
                          _showChooseVideosToDeleteDialog(allvideo);
                        },
                      ),
                      const CancelButton(),
                      NamidaButton(
                        text: lang.DELETE.toUpperCase(),
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

  String _getVideoSubtitleText(List<NamidaVideo> videos) {
    return lang.CLEAR_VIDEO_CACHE_SUBTITLE
        .replaceFirst('_CURRENT_VIDEOS_COUNT_', videos.length.formatDecimal())
        .replaceFirst('_TOTAL_SIZE_', videos.fold(0, (previousValue, element) => previousValue + element.sizeInBytes).fileSizeFormatted);
  }

  _showChooseVideosToDeleteDialog(List<NamidaVideo> allVideoFiles) {
    final RxList<NamidaVideo> videosToDelete = <NamidaVideo>[].obs;
    final videoFiles = List<NamidaVideo>.from(allVideoFiles).obs;
    final isSortTypeSize = true.obs;

    sortBySize() {
      videoFiles.sortByReverse((e) => e.sizeInBytes);
      isSortTypeSize.value = true;
    }

    sortByAccessTime() {
      videoFiles.sortByAlt((e) => File(e.path).statSync().accessed, (e) => File(e.path).statSync().modified);
      isSortTypeSize.value = false;
    }

    toggleSort() {
      if (isSortTypeSize.value) {
        sortByAccessTime();
      } else {
        sortBySize();
      }
    }

    sortBySize();

    Widget getChipButton({
      required String title,
      required IconData icon,
      required bool enabled,
    }) {
      return NamidaInkWell(
        animationDurationMS: 100,
        borderRadius: 8.0,
        bgColor: Get.theme.cardTheme.color,
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          border: enabled ? Border.all(color: Get.theme.colorScheme.primary) : null,
          borderRadius: BorderRadius.circular(8.0.multipliedRadius),
        ),
        onTap: toggleSort,
        child: Row(
          children: [
            Icon(icon, size: 18.0),
            const SizedBox(width: 4.0),
            Text(
              title,
              style: Get.textTheme.displayMedium,
            ),
            const SizedBox(width: 4.0),
            const Icon(Broken.arrow_down_2, size: 14.0),
          ],
        ),
      );
    }

    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        contentPadding: const EdgeInsets.symmetric(horizontal: 0.0),
        isWarning: true,
        normalTitleStyle: true,
        title: lang.CHOOSE,
        actions: [
          const CancelButton(),

          /// Clear after choosing
          Obx(
            () => NamidaButton(
              enabled: videosToDelete.isNotEmpty,
              text: lang.DELETE.toUpperCase(),
              onPressed: () async {
                NamidaNavigator.inst.navigateDialog(
                  dialog: CustomBlurryDialog(
                    isWarning: true,
                    normalTitleStyle: true,
                    actions: [
                      const CancelButton(),

                      /// final clear confirm
                      NamidaButton(
                        text: lang.DELETE.toUpperCase(),
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
          ),
        ],
        child: CupertinoScrollbar(
          child: SizedBox(
            width: Get.width,
            height: Get.height * 0.65,
            child: Column(
              children: [
                const SizedBox(height: 6.0),
                Obx(
                  () => Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const SizedBox(width: 24.0),
                      getChipButton(title: lang.SIZE, icon: Broken.size, enabled: isSortTypeSize.value),
                      const SizedBox(width: 12.0),
                      getChipButton(title: lang.OLDEST_WATCH, icon: Broken.sort, enabled: !isSortTypeSize.value),
                      const SizedBox(width: 24.0),
                    ],
                  ),
                ),
                const SizedBox(height: 6.0),
                Expanded(
                  child: Obx(
                    () => ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: videoFiles.length,
                      itemBuilder: (context, index) {
                        final video = videoFiles[index];
                        return Obx(
                          () => ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 24.0),
                            leading: ArtworkWidget(
                              thumbnailSize: 70.0,
                              iconSize: 24.0,
                              width: 70,
                              height: 70 * 9 / 16,
                              path: video.pathToYTImage,
                            ),
                            title: Text(video.ytID ?? ''),
                            subtitle: Text("${video.height}p • ${video.framerate}fps - ${video.sizeInBytes.fileSizeFormatted}"),
                            trailing: IgnorePointer(
                              child: SizedBox(
                                height: 18.0,
                                width: 18.0,
                                child: CheckMark(
                                  strokeWidth: 2,
                                  activeColor: context.theme.listTileTheme.iconColor!,
                                  inactiveColor: context.theme.listTileTheme.iconColor!,
                                  duration: const Duration(milliseconds: 400),
                                  active: videosToDelete.contains(video),
                                ),
                              ),
                            ),
                            onTap: () => videosToDelete.addOrRemove(video),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UpdateDirectoryPathListTile extends StatelessWidget {
  final Color? colorScheme;
  final String? oldPath;
  final Iterable<String>? tracksPaths;
  const UpdateDirectoryPathListTile({super.key, this.colorScheme, this.oldPath, this.tracksPaths});

  @override
  Widget build(BuildContext context) {
    return CustomListTile(
      leading: StackedIcon(
        baseIcon: Broken.folder,
        secondaryIcon: Broken.music,
        baseIconColor: colorScheme,
        secondaryIconColor: colorScheme,
        delightenColors: true,
      ),
      title: lang.UPDATE_DIRECTORY_PATH,
      subtitle: oldPath,
      onTap: () {
        final oldDirController = TextEditingController(text: oldPath);
        final newDirController = TextEditingController();

        final GlobalKey<FormState> formKey = GlobalKey<FormState>();
        final updateMissingOnly = true.obs;
        NamidaNavigator.inst.navigateDialog(
            colorScheme: colorScheme,
            dialogBuilder: (theme) => Form(
                  key: formKey,
                  child: CustomBlurryDialog(
                    title: lang.UPDATE_DIRECTORY_PATH,
                    actions: [
                      const CancelButton(),
                      NamidaButton(
                        text: lang.UPDATE,
                        onPressed: () async {
                          Future<void> okUpdate() async {
                            await EditDeleteController.inst.updateDirectoryInEveryPartOfNamida(
                              oldDirController.text,
                              newDirController.text,
                              forThesePathsOnly: tracksPaths,
                              ensureNewFileExists: updateMissingOnly.value,
                            );
                            NamidaNavigator.inst.closeDialog();
                          }

                          if (formKey.currentState?.validate() ?? false) {
                            if (tracksPaths != null && tracksPaths!.any((element) => File(element).existsSync())) {
                              NamidaNavigator.inst.navigateDialog(
                                colorScheme: colorScheme,
                                dialogBuilder: (theme) => CustomBlurryDialog(
                                  normalTitleStyle: true,
                                  isWarning: true,
                                  actions: [
                                    const CancelButton(),
                                    NamidaButton(
                                      text: lang.CONFIRM,
                                      onPressed: () async {
                                        NamidaNavigator.inst.closeDialog();
                                        await okUpdate();
                                      },
                                    )
                                  ],
                                  bodyText: lang.OLD_DIRECTORY_STILL_HAS_TRACKS,
                                ),
                              );
                            } else {
                              await okUpdate();
                            }
                          }
                        },
                      )
                    ],
                    child: Column(
                      children: [
                        const SizedBox(height: 12.0),
                        CustomTagTextField(
                          controller: oldDirController,
                          hintText: '',
                          labelText: lang.OLD_DIRECTORY,
                          validator: (value) {
                            value ??= '';
                            if (value.isEmpty) {
                              return lang.PLEASE_ENTER_A_NAME;
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 24.0),
                        Row(
                          children: [
                            Expanded(
                              child: CustomTagTextField(
                                controller: newDirController,
                                hintText: '',
                                labelText: lang.NEW_DIRECTORY,
                                validator: (value) {
                                  value ??= '';
                                  if (value.isEmpty) {
                                    return lang.PLEASE_ENTER_A_NAME;
                                  }
                                  if (!Directory(value).existsSync()) {
                                    return lang.DIRECTORY_DOESNT_EXIST;
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12.0),
                            NamidaIconButton(
                              onPressed: () async {
                                final dir = await FilePicker.platform.getDirectoryPath();
                                if (dir != null) newDirController.text = dir;
                              },
                              icon: Broken.folder,
                            )
                          ],
                        ),
                        const SizedBox(height: 12.0),
                        Obx(
                          () => CustomSwitchListTile(
                            passedColor: colorScheme,
                            title: lang.UPDATE_MISSING_TRACKS_ONLY,
                            value: updateMissingOnly.value,
                            onChanged: (isTrue) => updateMissingOnly.value = !updateMissingOnly.value,
                          ),
                        ),
                      ],
                    ),
                  ),
                ));
      },
    );
  }
}

class _FixYTDLPThumbnailSizeListTile extends StatelessWidget {
  const _FixYTDLPThumbnailSizeListTile();

  Future<void> _onFixYTDLPPress() async {
    if (!await requestManageStoragePermission()) return;

    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null) return;
    await NamidaFFMPEG.inst.fixYTDLPBigThumbnailSize(directoryPath: dir);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final p = NamidaFFMPEG.inst.currentOperations[OperationType.ytdlpThumbnailFix]?.value;
        final currentAudioPath = p?.currentFilePath;
        final currentProgress = p?.progress ?? 0;
        final totalAudiosToFix = p?.totalFiles ?? 0;
        final totalFailed = p?.totalFailed ?? 0;
        final failedSubtitle = totalFailed > 0 ? "${lang.FAILED}: $totalFailed" : null;
        return CustomListTile(
          leading: const StackedIcon(
            baseIcon: Broken.document_code_2,
            secondaryIcon: Broken.video_square,
          ),
          title: lang.FIX_YTDLP_BIG_THUMBNAIL_SIZE,
          subtitle: currentAudioPath?.getFilename ?? failedSubtitle,
          trailingText: totalAudiosToFix > 0 ? "$currentProgress/$totalAudiosToFix" : null,
          onTap: _onFixYTDLPPress,
        );
      },
    );
  }
}

class _CompressImagesListTile extends StatelessWidget {
  const _CompressImagesListTile();

  Future<void> _onCompressImagePress() async {
    if (NamidaFFMPEG.inst.currentOperations[OperationType.imageCompress]?.value.currentFilePath != null) return; // return if currently compressing.
    final compPerc = 50.obs;
    final keepOriginalFileDates = true.obs;
    final initialDirectories = [AppDirs.ARTWORKS, AppDirs.THUMBNAILS, AppDirs.YT_THUMBNAILS].obs;
    final dirsToCompress = <String>[].obs;

    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        title: lang.CONFIGURE,
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.COMPRESS,
            onPressed: () {
              NamidaNavigator.inst.closeDialog();
              _startCompressing(dirsToCompress, compPerc.value, keepOriginalFileDates.value);
            },
          ),
        ],
        child: Column(
          children: [
            Obx(
              () => ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: [
                  ...initialDirectories.map(
                    (e) => Obx(
                      () {
                        final dirPath = e.split(Platform.pathSeparator)..removeWhere((element) => element == '');
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: ListTileWithCheckMark(
                            icon: Broken.folder,
                            title: dirPath.last,
                            subtitle: e.overflow,
                            active: dirsToCompress.contains(e),
                            onTap: () => dirsToCompress.addOrRemove(e),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12.0),
            CustomListTile(
              title: lang.COMPRESSION_PERCENTAGE,
              trailing: Obx(
                () => NamidaWheelSlider(
                  totalCount: 100,
                  initValue: 50,
                  itemSize: 2,
                  squeeze: 0.4,
                  text: "${compPerc.value}%",
                  onValueChanged: (val) {
                    compPerc.value = (val as int);
                  },
                ),
              ),
            ),
            CustomListTile(
              icon: Broken.folder_add,
              title: lang.PICK_FROM_STORAGE,
              onTap: () async {
                final dirPath = await FilePicker.platform.getDirectoryPath();
                if (dirPath == null) return;
                initialDirectories.add(dirPath);
                dirsToCompress.add(dirPath);
              },
            ),
            Obx(
              () => CustomSwitchListTile(
                icon: Broken.document_code_2,
                title: lang.KEEP_FILE_DATES,
                value: keepOriginalFileDates.value,
                onChanged: (isTrue) => keepOriginalFileDates.value = !isTrue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startCompressing(Iterable<String> dirs, int compressionPerc, bool keepOriginalFileStats) async {
    await NamidaFFMPEG.inst.compressImageDirectories(
      dirs: dirs,
      compressionPerc: compressionPerc,
      keepOriginalFileStats: keepOriginalFileStats,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final p = NamidaFFMPEG.inst.currentOperations[OperationType.imageCompress]?.value;
        final currentImagePath = p?.currentFilePath;
        final currentProgress = p?.progress ?? 0;
        final totalImagesToCompress = p?.totalFiles ?? 0;
        final totalFailed = p?.totalFailed ?? 0;
        return CustomListTile(
          leading: const StackedIcon(
            baseIcon: Broken.gallery,
            secondaryIcon: Broken.magicpen,
          ),
          title: lang.COMPRESS_IMAGES,
          subtitle: currentImagePath?.getFilename ?? (totalFailed > 0 ? "${lang.FAILED}: $totalFailed" : null),
          trailingText: totalImagesToCompress > 0 ? "$currentProgress/$totalImagesToCompress" : null,
          onTap: _onCompressImagePress,
        );
      },
    );
  }
}
