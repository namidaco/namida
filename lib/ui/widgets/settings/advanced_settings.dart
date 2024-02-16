import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;

import 'package:namida/base/setting_subpage_provider.dart';
import 'package:namida/class/audio_cache_detail.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/edit_delete_controller.dart';
import 'package:namida/controller/ffmpeg_controller.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/storage_cache_manager.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/main.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/ui/widgets/settings_card.dart';

enum _AdvancedSettingKeys {
  performanceMode,
  rescanVideos,
  removeSourceHistory,
  updateDirPath,
  fixYTDLPBigThumbnail,
  compressImages,
  maxImageCache,
  maxAudioCache,
  maxVideoCache,
  clearImageCache,
  clearAudioCache,
  clearVideoCache,
}

class AdvancedSettings extends SettingSubpageProvider {
  const AdvancedSettings({super.key, super.initialItem});

  @override
  SettingSubpageEnum get settingPage => SettingSubpageEnum.advanced;

  @override
  Map<Enum, List<String>> get lookupMap => {
        _AdvancedSettingKeys.performanceMode: [lang.PERFORMANCE_MODE],
        _AdvancedSettingKeys.rescanVideos: [lang.RESCAN_VIDEOS],
        _AdvancedSettingKeys.removeSourceHistory: [lang.REMOVE_SOURCE_FROM_HISTORY],
        _AdvancedSettingKeys.updateDirPath: [lang.UPDATE_DIRECTORY_PATH],
        _AdvancedSettingKeys.fixYTDLPBigThumbnail: [lang.FIX_YTDLP_BIG_THUMBNAIL_SIZE],
        _AdvancedSettingKeys.compressImages: [lang.COMPRESS_IMAGES],
        _AdvancedSettingKeys.maxImageCache: [lang.MAX_IMAGE_CACHE_SIZE],
        _AdvancedSettingKeys.maxAudioCache: [lang.MAX_AUDIO_CACHE_SIZE],
        _AdvancedSettingKeys.maxVideoCache: [lang.MAX_VIDEO_CACHE_SIZE],
        _AdvancedSettingKeys.clearImageCache: [lang.CLEAR_IMAGE_CACHE],
        _AdvancedSettingKeys.clearAudioCache: [lang.CLEAR_AUDIO_CACHE],
        _AdvancedSettingKeys.clearVideoCache: [lang.CLEAR_VIDEO_CACHE],
      };

  Widget getPerformanceTile(BuildContext context) {
    return getItemWrapper(
      key: _AdvancedSettingKeys.performanceMode,
      child: CustomListTile(
        bgColor: getBgColor(_AdvancedSettingKeys.performanceMode),
        icon: Broken.cpu_setting,
        title: lang.PERFORMANCE_MODE,
        trailing: NamidaPopupWrapper(
          children: () => [
            ...PerformanceMode.values.map(
              (e) => Obx(
                () => NamidaInkWell(
                  margin: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
                  borderRadius: 6.0,
                  bgColor: settings.performanceMode.value == e ? context.theme.cardColor : null,
                  child: Row(
                    children: [
                      Icon(
                        e.toIcon(),
                        size: 18.0,
                      ),
                      const SizedBox(width: 6.0),
                      Text(
                        e.toText(),
                        style: context.textTheme.displayMedium?.copyWith(fontSize: 14.0.multipliedFontScale),
                      ),
                    ],
                  ),
                  onTap: () {
                    e.execute();
                    settings.save(performanceMode: e);
                    NamidaNavigator.inst.popMenu();
                  },
                ),
              ),
            ),
          ],
          child: Obx(
            () => Text(
              settings.performanceMode.value.toText(),
              style: context.textTheme.displaySmall?.copyWith(color: context.theme.colorScheme.onBackground.withAlpha(200)),
              textAlign: TextAlign.end,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: lang.ADVANCED_SETTINGS,
      subtitle: lang.ADVANCED_SETTINGS_SUBTITLE,
      icon: Broken.hierarchy_3,
      // icon: Broken.danger,
      child: Column(
        children: [
          getPerformanceTile(context),
          getItemWrapper(
            key: _AdvancedSettingKeys.rescanVideos,
            child: CustomListTile(
              bgColor: getBgColor(_AdvancedSettingKeys.rescanVideos),
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

                  if (!isCounterVisible && !isLoadingVisible) return Text("${VideoController.inst.localVideosTotalCount}");

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
                await VideoController.inst.scanLocalVideos(forceReScan: true, fillPathsOnly: true);
                snackyy(title: lang.DONE, message: lang.FINISHED_UPDATING_LIBRARY);
              },
            ),
          ),
          getItemWrapper(
            key: _AdvancedSettingKeys.removeSourceHistory,
            child: CustomListTile(
              bgColor: getBgColor(_AdvancedSettingKeys.removeSourceHistory),
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
                  onDisposing: () {
                    sourcesToDelete.close();
                    sourcesMap.close();
                    totalTracksToBeRemoved.close();
                    totalTracksBetweenDates.close();
                  },
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
                          snackyy(title: lang.NOTE, message: "${lang.REMOVED} ${removedNum.displayTrackKeyword}");
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
          ),
          getItemWrapper(
            key: _AdvancedSettingKeys.updateDirPath,
            child: UpdateDirectoryPathListTile(
              bgColor: getBgColor(_AdvancedSettingKeys.updateDirPath),
            ),
          ),
          // -- this will loop all choosen files, get yt thumbnail (download or cache), edit tags, without affecting file modified time.
          getItemWrapper(
            key: _AdvancedSettingKeys.fixYTDLPBigThumbnail,
            child: _FixYTDLPThumbnailSizeListTile(
              bgColor: getBgColor(_AdvancedSettingKeys.fixYTDLPBigThumbnail),
            ),
          ),
          getItemWrapper(
            key: _AdvancedSettingKeys.compressImages,
            child: _CompressImagesListTile(
              bgColor: getBgColor(_AdvancedSettingKeys.compressImages),
            ),
          ),

          () {
            const stepper = 8 * 4;
            const minimumValue = stepper;
            int getValue(int mb) => (mb - minimumValue) ~/ stepper;
            return getItemWrapper(
              key: _AdvancedSettingKeys.maxImageCache,
              child: CustomListTile(
                bgColor: getBgColor(_AdvancedSettingKeys.maxImageCache),
                leading: const StackedIcon(
                  baseIcon: Broken.gallery,
                  secondaryIcon: Broken.cpu,
                ),
                title: lang.MAX_IMAGE_CACHE_SIZE,
                trailing: Obx(
                  () => NamidaWheelSlider<int>(
                    totalCount: getValue(4 * 1024), // 4 GB
                    initValue: getValue(settings.imagesMaxCacheInMB.value),
                    itemSize: 5,
                    text: (settings.imagesMaxCacheInMB.value * 1024 * 1024).fileSizeFormatted,
                    onValueChanged: (val) {
                      settings.save(imagesMaxCacheInMB: minimumValue + (val * stepper));
                    },
                  ),
                ),
              ),
            );
          }(),

          () {
            const stepper = 8 * 4;
            const minimumValue = stepper;
            int getValue(int mb) => (mb - minimumValue) ~/ stepper;
            return getItemWrapper(
              key: _AdvancedSettingKeys.maxAudioCache,
              child: CustomListTile(
                bgColor: getBgColor(_AdvancedSettingKeys.maxAudioCache),
                leading: const StackedIcon(
                  baseIcon: Broken.audio_square,
                  secondaryIcon: Broken.cpu,
                ),
                title: lang.MAX_AUDIO_CACHE_SIZE,
                trailing: Obx(
                  () => NamidaWheelSlider<int>(
                    totalCount: getValue(4 * 1024), // 4 GB
                    initValue: getValue(settings.audiosMaxCacheInMB.value),
                    itemSize: 5,
                    text: (settings.audiosMaxCacheInMB.value * 1024 * 1024).fileSizeFormatted,
                    onValueChanged: (val) {
                      settings.save(audiosMaxCacheInMB: minimumValue + (val * stepper));
                    },
                  ),
                ),
              ),
            );
          }(),

          () {
            const stepper = 8 * 32;
            const minimumValue = stepper;
            int getValue(int mb) => (mb - minimumValue) ~/ stepper;
            return getItemWrapper(
              key: _AdvancedSettingKeys.maxVideoCache,
              child: CustomListTile(
                bgColor: getBgColor(_AdvancedSettingKeys.maxVideoCache),
                leading: const StackedIcon(
                  baseIcon: Broken.video,
                  secondaryIcon: Broken.cpu,
                ),
                title: lang.MAX_VIDEO_CACHE_SIZE,
                trailing: Obx(
                  () => NamidaWheelSlider<int>(
                    totalCount: getValue(10 * 1024), // 10 GB
                    initValue: getValue(settings.videosMaxCacheInMB.value),
                    itemSize: 5,
                    text: (settings.videosMaxCacheInMB.value * 1024 * 1024).fileSizeFormatted,
                    onValueChanged: (val) {
                      settings.save(videosMaxCacheInMB: minimumValue + (val * stepper));
                    },
                  ),
                ),
              ),
            );
          }(),

          getItemWrapper(
            key: _AdvancedSettingKeys.clearImageCache,
            child: _ClearImageCacheListTile(
              bgColor: getBgColor(_AdvancedSettingKeys.clearImageCache),
            ),
          ),
          getItemWrapper(
            key: _AdvancedSettingKeys.clearAudioCache,
            child: _ClearAudioCacheListTile(
              bgColor: getBgColor(_AdvancedSettingKeys.clearImageCache),
            ),
          ),

          getItemWrapper(
            key: _AdvancedSettingKeys.clearVideoCache,
            child: Obx(
              () => CustomListTile(
                bgColor: getBgColor(_AdvancedSettingKeys.clearVideoCache),
                leading: const StackedIcon(
                  baseIcon: Broken.video,
                  secondaryIcon: Broken.close_circle,
                ),
                title: lang.CLEAR_VIDEO_CACHE,
                trailingText: Indexer.inst.videosSizeInStorage.value.fileSizeFormatted,
                onTap: () {
                  final allvideos = VideoController.inst.getCurrentVideosInCache();
                  const cacheManager = StorageCacheManager();
                  cacheManager.promptCacheDeleteDialog(
                    allItems: allvideos,
                    deleteStatsNote: (items) => cacheManager.getDeleteSizeSubtitleText(items.length, Indexer.inst.videosSizeInStorage.value),
                    chooseNote: lang.CLEAR_VIDEO_CACHE_NOTE,
                    onChoosePrompt: () {
                      cacheManager.showChooseToDeleteDialog(
                        allItems: allvideos,
                        itemToPath: (item) => item.path,
                        itemToYtId: (item) => item.ytID,
                        itemToSubtitle: (item, itemSize) => "${item.resolution}p • ${item.framerate}fps - ${itemSize.fileSizeFormatted}",
                        confirmDialogText: cacheManager.getDeleteSizeSubtitleText,
                        onConfirm: (itemsToDelete) async {
                          await Indexer.inst.clearVideoCache(itemsToDelete);
                        },
                        includeLocalTracksListens: true,
                        tempFilesSize: () async => await cacheManager.getTempVideosSize(),
                        onDeleteTempFiles: () async => await cacheManager.deleteTempVideos(),
                      );
                    },
                    onDeleteAll: () async => await Indexer.inst.clearVideoCache(),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClearImageCacheListTile extends StatefulWidget {
  final Color? bgColor;

  const _ClearImageCacheListTile({this.bgColor});

  @override
  State<_ClearImageCacheListTile> createState() => __ClearImageCacheListTileState();
}

class __ClearImageCacheListTileState extends State<_ClearImageCacheListTile> {
  final mainDirs = {
    AppDirs.ARTWORKS,
    AppDirs.THUMBNAILS,
    AppDirs.YT_THUMBNAILS,
    AppDirs.YT_THUMBNAILS_CHANNELS,
  };

  final dirsMap = <String, int>{}.obs;

  final dirsChoosen = <String>[].obs;

  int get totalBytes => dirsMap.values.fold(0, (previousValue, element) => previousValue + element);

  @override
  void initState() {
    super.initState();
    dirsChoosen.addAll([
      AppDirs.YT_THUMBNAILS,
      AppDirs.YT_THUMBNAILS_CHANNELS,
    ]);
    _fillSizes();
  }

  @override
  void dispose() {
    dirsMap.close();
    dirsChoosen.close();
    super.dispose();
  }

  void _fillSizes() async {
    final res = await _fillSizesIsolate.thready(mainDirs);
    dirsMap.value = res;
  }

  static Map<String, int> _fillSizesIsolate(Set<String> dirs) {
    final map = <String, int>{};
    for (final d in dirs) {
      map[d] = Directory(d).listSyncSafe().fold(0, (previousValue, element) => previousValue + element.statSync().size);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => CustomListTile(
        bgColor: widget.bgColor,
        leading: const StackedIcon(
          baseIcon: Broken.image,
          secondaryIcon: Broken.close_circle,
        ),
        title: lang.CLEAR_IMAGE_CACHE,
        trailingText: dirsMap.isEmpty ? '?' : totalBytes.fileSizeFormatted,
        onTap: () {
          NamidaNavigator.inst.navigateDialog(
            dialog: CustomBlurryDialog(
              title: lang.CONFIGURE,
              normalTitleStyle: true,
              actions: [
                const CancelButton(),
                Obx(
                  () {
                    final total = dirsChoosen.fold(0, (p, element) => p + (dirsMap[element] ?? 0));
                    return NamidaButton(
                      text: "${lang.CLEAR.toUpperCase()} (${total.fileSizeFormatted})",
                      onPressed: () async {
                        NamidaNavigator.inst.closeDialog();

                        for (final d in dirsChoosen) {
                          await Directory(d).delete(recursive: true);
                          await Directory(d).create();
                        }

                        if (dirsChoosen.contains(AppDirs.ARTWORKS)) {
                          await Indexer.inst.clearImageCache();
                        }

                        _fillSizes();
                      },
                    );
                  },
                ),
              ],
              child: Column(
                children: [
                  ...mainDirs.map(
                    (e) {
                      final bytes = dirsMap[e] ?? 0;
                      final warningText = e == AppDirs.ARTWORKS || e == AppDirs.THUMBNAILS ? lang.CLEAR_IMAGE_CACHE_WARNING : '';
                      final subtitle = warningText == '' ? bytes.fileSizeFormatted : "${bytes.fileSizeFormatted}\n$warningText";
                      return Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Obx(
                          () => ListTileWithCheckMark(
                            active: dirsChoosen.contains(e),
                            dense: true,
                            icon: Broken.cpu_setting,
                            title: e.split(Platform.pathSeparator).lastWhereEff((e) => e != '') ?? e,
                            subtitle: subtitle,
                            onTap: () => dirsChoosen.addOrRemove(e),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ClearAudioCacheListTile extends StatefulWidget {
  final Color? bgColor;
  const _ClearAudioCacheListTile({this.bgColor});

  @override
  State<_ClearAudioCacheListTile> createState() => __ClearAudioCacheListTileState();
}

class __ClearAudioCacheListTileState extends State<_ClearAudioCacheListTile> {
  int totalSize = -1;

  @override
  void initState() {
    super.initState();
    _fillSizes();
  }

  void _fillSizes() async {
    final res = await _fillSizeIsolate.thready(AppDirs.AUDIOS_CACHE);
    if (mounted) setState(() => totalSize = res);
  }

  static int _fillSizeIsolate(String dirPath) {
    int size = 0;
    Directory(dirPath).listSyncSafe().loop((e, _) {
      size += e.statSync().size;
    });
    return size;
  }

  static int _tempFilesSizeIsolate(String dirPath) {
    int size = 0;
    Directory(dirPath).listSyncSafe().loop((e, _) {
      if (e.path.endsWith('.part')) size += e.statSync().size;
    });
    return size;
  }

  static void _tempFilesDeleteIsolate(String dirPath) {
    Directory(dirPath).listSyncSafe().loop((e, _) {
      if (e.path.endsWith('.part')) {
        if (e is File) {
          try {
            e.deleteSync();
          } catch (_) {}
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomListTile(
      bgColor: widget.bgColor,
      leading: const StackedIcon(
        baseIcon: Broken.musicnote,
        secondaryIcon: Broken.close_circle,
      ),
      title: lang.CLEAR_AUDIO_CACHE,
      trailingText: totalSize == -1 ? '?' : totalSize.fileSizeFormatted,
      onTap: () {
        final allaudios = <AudioCacheDetails>[];
        for (final acFiles in Player.inst.audioCacheMap.values) {
          acFiles.loop((e, index) => allaudios.add(e));
        }

        const cacheManager = StorageCacheManager();
        cacheManager.promptCacheDeleteDialog(
          allItems: allaudios,
          deleteStatsNote: (items) => cacheManager.getDeleteSizeSubtitleText(items.length, totalSize),
          chooseNote: lang.CLEAR_VIDEO_CACHE_NOTE,
          onChoosePrompt: () {
            cacheManager.showChooseToDeleteDialog(
              allItems: allaudios,
              itemToPath: (item) => item.file.path,
              itemToYtId: (item) => item.youtubeId,
              itemToSubtitle: (item, size) => "${(item.bitrate ?? 0) ~/ 1000}kb/s - ${size.fileSizeFormatted}",
              confirmDialogText: cacheManager.getDeleteSizeSubtitleText,
              onConfirm: (itemsToDelete) async {
                setState(() => totalSize = -1);

                for (final audio in itemsToDelete) {
                  await audio.file.tryDeleting();
                }

                _fillSizes();
              },
              includeLocalTracksListens: true,
              tempFilesSize: () async => await _tempFilesSizeIsolate.thready(AppDirs.AUDIOS_CACHE),
              onDeleteTempFiles: () async => await _tempFilesDeleteIsolate.thready(AppDirs.AUDIOS_CACHE),
            );
          },
          onDeleteAll: () async {
            final dir = Directory(AppDirs.AUDIOS_CACHE);
            await dir.delete(recursive: true);
            await dir.create();
            if (mounted) setState(() => totalSize = 0);
          },
        );
      },
    );
  }
}

class UpdateDirectoryPathListTile extends StatelessWidget {
  final Color? colorScheme;
  final String? oldPath;
  final Iterable<String>? tracksPaths;
  final Color? bgColor;

  const UpdateDirectoryPathListTile({
    super.key,
    this.colorScheme,
    this.oldPath,
    this.tracksPaths,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomListTile(
      bgColor: bgColor,
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
            onDisposing: () {
              updateMissingOnly.close();
              oldDirController.dispose();
              newDirController.dispose();
            },
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
  final Color? bgColor;

  const _FixYTDLPThumbnailSizeListTile({this.bgColor});

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
          bgColor: bgColor,
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
  final Color? bgColor;

  const _CompressImagesListTile({this.bgColor});

  Future<void> _onCompressImagePress() async {
    if (NamidaFFMPEG.inst.currentOperations[OperationType.imageCompress]?.value.currentFilePath != null) return; // return if currently compressing.
    final compPerc = 50.obs;
    final keepOriginalFileDates = true.obs;
    final initialDirectories = [AppDirs.ARTWORKS, AppDirs.THUMBNAILS, AppDirs.YT_THUMBNAILS].obs;
    final dirsToCompress = <String>[].obs;

    NamidaNavigator.inst.navigateDialog(
      onDisposing: () {
        compPerc.close();
        keepOriginalFileDates.close();
        initialDirectories.close();
        dirsToCompress.close();
      },
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
          bgColor: bgColor,
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
