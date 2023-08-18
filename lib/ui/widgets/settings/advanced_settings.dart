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
import 'package:namida/controller/settings_controller.dart';
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
            title: Language.inst.RESCAN_VIDEOS,
            onTap: () async {
              await VideoController.inst.scanLocalVideos(forceReScan: true);
              Get.snackbar(Language.inst.DONE, Language.inst.FINISHED_UPDATING_LIBRARY);
            },
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
          const UpdateDirectoryPathListTile(),
          const _CompressImagesListTile(),
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
                baseIcon: Broken.video,
                secondaryIcon: Broken.close_circle,
              ),
              title: Language.inst.CLEAR_VIDEO_CACHE,
              trailingText: Indexer.inst.videosSizeInStorage.value.fileSizeFormatted,
              onTap: () async {
                final allvideo = VideoController.inst.getCurrentVideosInCache();

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
                        text: Language.inst.DELETE.toUpperCase(),
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
    return Language.inst.CLEAR_VIDEO_CACHE_SUBTITLE
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
          Obx(
            () => NamidaButton(
              enabled: videosToDelete.isNotEmpty,
              text: Language.inst.DELETE.toUpperCase(),
              onPressed: () async {
                NamidaNavigator.inst.navigateDialog(
                  dialog: CustomBlurryDialog(
                    isWarning: true,
                    normalTitleStyle: true,
                    actions: [
                      const CancelButton(),

                      /// final clear confirm
                      NamidaButton(
                        text: Language.inst.DELETE.toUpperCase(),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Obx(
                      () => NamidaButton(
                        icon: Broken.sort,
                        text: isSortTypeSize.value ? Language.inst.SIZE : Language.inst.OLDEST_WATCH,
                        onPressed: toggleSort,
                      ),
                    ),
                    const SizedBox(width: 24.0)
                  ],
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
      leading: const StackedIcon(
        baseIcon: Broken.folder,
        secondaryIcon: Broken.music,
      ),
      title: Language.inst.UPDATE_DIRECTORY_PATH,
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
                    title: Language.inst.UPDATE_DIRECTORY_PATH,
                    actions: [
                      const CancelButton(),
                      NamidaButton(
                        text: Language.inst.UPDATE,
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
                                      text: Language.inst.CONFIRM,
                                      onPressed: () async {
                                        NamidaNavigator.inst.closeDialog();
                                        await okUpdate();
                                      },
                                    )
                                  ],
                                  bodyText: Language.inst.OLD_DIRECTORY_STILL_HAS_TRACKS,
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
                          labelText: Language.inst.OLD_DIRECTORY,
                          validator: (value) {
                            value ??= '';
                            if (value.isEmpty) {
                              return Language.inst.PLEASE_ENTER_A_NAME;
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
                                labelText: Language.inst.NEW_DIRECTORY,
                                validator: (value) {
                                  value ??= '';
                                  if (value.isEmpty) {
                                    return Language.inst.PLEASE_ENTER_A_NAME;
                                  }
                                  if (!Directory(value).existsSync()) {
                                    return Language.inst.DIRECTORY_DOESNT_EXIST;
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
                            title: Language.inst.UPDATE_MISSING_TRACKS_ONLY,
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

class _CompressImagesListTile extends StatefulWidget {
  const _CompressImagesListTile();

  @override
  State<_CompressImagesListTile> createState() => __CompressImagesListTileState();
}

class __CompressImagesListTileState extends State<_CompressImagesListTile> {
  int _totalImagesToCompress = 0;
  int _currentProgress = 0;
  String? _currentImagePath;
  int _currentFailed = 0;

  Future<void> _onCompressImagePress() async {
    if (_currentImagePath != null) return; // return if currently compressing.
    _totalImagesToCompress = 0;
    _currentProgress = 0;
    final compPerc = 50.obs;
    final keepOriginalFileDates = true.obs;
    final initialDirectories = [k_DIR_ARTWORKS, k_DIR_THUMBNAILS, k_DIR_YT_THUMBNAILS].obs;
    final dirsToCompress = <String>[].obs;

    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        title: Language.inst.CONFIGURE,
        actions: [
          const CancelButton(),
          NamidaButton(
            text: Language.inst.COMPRESS,
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
              title: Language.inst.COMPRESSION_PERCENTAGE,
              trailing: Obx(
                () => NamidaWheelSlider(
                  totalCount: 100 - 10,
                  initValue: 50,
                  itemSize: 2,
                  squeeze: 0.4,
                  text: "${compPerc.value}%",
                  onValueChanged: (val) {
                    compPerc.value = (val as int) + 10;
                  },
                ),
              ),
            ),
            CustomListTile(
              icon: Broken.folder_add,
              title: Language.inst.PICK_FROM_STORAGE,
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
                title: Language.inst.KEEP_FILE_DATES,
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
    if (!await requestManageStoragePermission()) return;

    setState(() {});

    final saveDir = "$k_DIR_APP_INTERNAL_STORAGE/Compressed/";
    final dir = await Directory(saveDir).create();

    final dirFiles = <FileSystemEntity>[];

    for (final d in dirs) {
      dirFiles.addAll(Directory(d).listSync(recursive: true));
    }

    _totalImagesToCompress = dirFiles.length;
    setState(() {});
    for (final f in dirFiles) {
      _currentProgress++;
      _currentImagePath = f.path;
      setState(() {});
      if (f is File) {
        final didUpdate = await NamidaFFMPEG.inst.compressImage(
          path: f.path,
          saveDir: dir.path,
          percentage: compressionPerc,
          keepOriginalFileStats: keepOriginalFileStats,
        );
        if (!didUpdate) setState(() => _currentFailed++);
      }
    }
    _currentImagePath = null;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return CustomListTile(
      leading: const StackedIcon(
        baseIcon: Broken.gallery,
        secondaryIcon: Broken.magicpen,
      ),
      title: Language.inst.COMPRESS_IMAGES,
      subtitle: _currentImagePath?.getFilename ?? (_currentFailed > 0 ? "${Language.inst.FAILED}: $_currentFailed" : null),
      trailingText: "$_currentProgress/$_totalImagesToCompress",
      onTap: _onCompressImagePress,
    );
  }
}
