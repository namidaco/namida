import 'dart:io';

import 'package:flutter/material.dart';

import 'package:history_manager/history_manager.dart';

import 'package:namida/base/setting_subpage_provider.dart';
import 'package:namida/class/audio_cache_detail.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/audio_cache_controller.dart';
import 'package:namida/controller/edit_delete_controller.dart';
import 'package:namida/controller/ffmpeg_controller.dart';
import 'package:namida/controller/file_browser.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/settings_search_controller.dart';
import 'package:namida/controller/storage_cache_manager.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/main.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/ui/widgets/settings/theme_settings.dart';
import 'package:namida/ui/widgets/settings_card.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';

enum _AdvancedSettingKeys with SettingKeysBase {
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
  Map<SettingKeysBase, List<String>> get lookupMap => {
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

  void _onPerformanceTileTap(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    const artworkPartsMultiplier = 100;
    bool changedArtworkCacheM = false; // to rebuild wheel slider
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        title: lang.CONFIGURE,
        actions: const [
          DoneButton(),
        ],
        child: SizedBox(
          width: context.width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12.0),
              CustomListTile(
                icon: Broken.cpu_setting,
                title: lang.PERFORMANCE_MODE,
                trailing: NamidaPopupWrapper(
                  children: () => [
                    ...PerformanceMode.values.map(
                      (e) {
                        void onTap() {
                          changedArtworkCacheM = !changedArtworkCacheM;
                          e.executeAndSave();
                          NamidaNavigator.inst.popMenu();
                        }

                        return ObxO(
                          rx: settings.performanceMode,
                          builder: (context, performanceMode) => NamidaInkWell(
                            margin: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
                            borderRadius: 6.0,
                            bgColor: performanceMode == e ? theme.cardColor : null,
                            onTap: onTap,
                            child: Row(
                              children: [
                                Icon(
                                  e.toIcon(),
                                  size: 18.0,
                                ),
                                const SizedBox(width: 6.0),
                                Text(
                                  e.toText(),
                                  style: textTheme.displayMedium?.copyWith(fontSize: 14.0),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  child: ObxO(
                    rx: settings.performanceMode,
                    builder: (context, performanceMode) => Text(
                      performanceMode.toText(),
                      style: textTheme.displaySmall?.copyWith(color: theme.colorScheme.onSurface.withAlpha(200)),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6.0),
              const NamidaContainerDivider(),
              const SizedBox(height: 6.0),
              const ThemeSetting().getAutoColoringTile(),
              ObxO(
                rx: settings.enableBlurEffect,
                builder: (context, enableBlurEffect) => CustomSwitchListTile(
                  icon: Broken.drop,
                  title: lang.ENABLE_BLUR_EFFECT,
                  subtitle: lang.PERFORMANCE_NOTE,
                  onChanged: (p0) {
                    settings.save(
                      enableBlurEffect: !p0,
                      performanceMode: PerformanceMode.custom,
                    );
                  },
                  value: enableBlurEffect,
                ),
              ),
              ObxO(
                rx: settings.enableGlowEffect,
                builder: (context, enableGlowEffect) => CustomSwitchListTile(
                  icon: Broken.sun_1,
                  title: lang.ENABLE_GLOW_EFFECT,
                  subtitle: lang.PERFORMANCE_NOTE,
                  onChanged: (p0) {
                    settings.save(
                      enableGlowEffect: !p0,
                      performanceMode: PerformanceMode.custom,
                    );
                  },
                  value: enableGlowEffect,
                ),
              ),
              ObxO(
                rx: settings.enableMiniplayerParallaxEffect,
                builder: (context, enableMiniplayerParallaxEffect) => CustomSwitchListTile(
                  icon: Broken.maximize,
                  title: lang.ENABLE_PARALLAX_EFFECT,
                  subtitle: lang.PERFORMANCE_NOTE,
                  onChanged: (isTrue) => settings.save(
                    enableMiniplayerParallaxEffect: !isTrue,
                    performanceMode: PerformanceMode.custom,
                  ),
                  value: enableMiniplayerParallaxEffect,
                ),
              ),
              CustomListTile(
                icon: Broken.card_pos,
                title: lang.ARTWORK,
                subtitle: lang.PERFORMANCE_NOTE,
                trailing: ObxO(
                  rx: settings.artworkCacheHeightMultiplier,
                  builder: (context, artworkCacheHeightMultiplier) => NamidaWheelSlider(
                    key: ValueKey(changedArtworkCacheM),
                    min: (0.5 * artworkPartsMultiplier).round(),
                    max: (1.5 * artworkPartsMultiplier).round(), // from 0.5 to 1.5 * 100 part
                    initValue: (artworkCacheHeightMultiplier * artworkPartsMultiplier).round(),
                    text: '${artworkCacheHeightMultiplier}x',
                    onValueChanged: (val) {
                      settings.save(
                        artworkCacheHeightMultiplier: (val / artworkPartsMultiplier).roundDecimals(2),
                        performanceMode: PerformanceMode.custom,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget getPerformanceTile(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    return getItemWrapper(
      key: _AdvancedSettingKeys.performanceMode,
      child: CustomListTile(
        bgColor: getBgColor(_AdvancedSettingKeys.performanceMode),
        icon: Broken.cpu_setting,
        title: lang.PERFORMANCE_MODE,
        trailing: ObxO(
          rx: settings.performanceMode,
          builder: (context, performanceMode) => Text(
            performanceMode.toText(),
            style: textTheme.displaySmall?.copyWith(color: theme.colorScheme.onSurface.withAlpha(200)),
            textAlign: TextAlign.end,
          ),
        ),
        onTap: () => _onPerformanceTileTap(context),
      ),
    );
  }

  Widget _getCacheSliderWidget({
    required int stepper,
    required int maxGB,
    required _AdvancedSettingKeys key,
    required IconData icon,
    required String title,
    required Rx<int> rx,
    required void Function(int val) onSave,
  }) {
    final minimumValue = stepper;
    final maxValue = maxGB * 1024;
    return getItemWrapper(
      key: key,
      child: CustomListTile(
        bgColor: getBgColor(key),
        leading: StackedIcon(
          baseIcon: icon,
          secondaryIcon: Broken.cpu,
        ),
        title: title,
        trailing: ObxO(
          rx: rx,
          builder: (context, valInSettings) {
            return NamidaWheelSlider(
              min: minimumValue,
              max: maxValue,
              stepper: stepper,
              extraValue: true,
              initValue: valInSettings,
              text: valInSettings < 0 ? lang.UNLIMITED : (valInSettings * 1024 * 1024).fileSizeFormatted,
              onValueChanged: onSave,
            );
          },
        ),
      ),
    );
  }

  void _removeSourceFromHistory(HistoryManager manager) {
    final RxList<TrackSource> sourcesToDelete = <TrackSource>[].obs;
    bool isActive(TrackSource e) => sourcesToDelete.contains(e);

    final RxMap<TrackSource, int> sourcesMap = <TrackSource, int>{}.obs;
    void resetSourcesMap() {
      sourcesMap.execute((map) => TrackSource.values.loop((e) => map[e] = 0));
    }

    final totalTracksToBeRemoved = 0.obs;

    final totalTracksBetweenDates = 0.obs;

    void calculateTotalTracks(DateTime? oldest, DateTime? newest) {
      final sussyDays = manager.historyDays.toList();
      final isBetweenDays = oldest != null && newest != null;
      if (isBetweenDays) {
        final oldestDay = oldest.toDaysSince1970();
        final newestDay = newest.toDaysSince1970();

        sussyDays.retainWhere((element) => element >= oldestDay && element <= newestDay);
        printy(sussyDays);
      }
      resetSourcesMap();
      sussyDays.loop((d) {
        final tracks = manager.historyMap.value[d] ?? [];
        tracks.loop((twd) {
          sourcesMap.update(twd.source, (value) => value + 1, ifAbsent: () => 1);
        });
      });
      if (isBetweenDays) {
        totalTracksBetweenDates.value = sourcesMap.values.reduce((value, element) => value + element);
      }
      if (sourcesToDelete.isNotEmpty) {
        totalTracksToBeRemoved.value = 0;
        sourcesToDelete.loop((e) {
          totalTracksToBeRemoved.value += sourcesMap[e] ?? 0;
        });
      }
    }

    // -- filling each source with its tracks number.
    calculateTotalTracks(null, null);

    DateTime? oldestDate;
    DateTime? newestDate;

    final isRemovingRx = false.obs;
    final removeDuplicates = false.obs;

    NamidaNavigator.inst.navigateDialog(
      onDisposing: () {
        sourcesToDelete.close();
        sourcesMap.close();
        totalTracksToBeRemoved.close();
        totalTracksBetweenDates.close();
        removeDuplicates.close();
        isRemovingRx.close();
      },
      dialog: CustomBlurryDialog(
        title: lang.CHOOSE,
        actions: [
          const CancelButton(),
          ObxO(
            rx: isRemovingRx,
            builder: (context, isRemoving) => NamidaButton(
              enabled: !isRemoving,
              text: lang.REMOVE,
              onPressed: () async {
                isRemovingRx.value = true;
                final removedNum = await manager.removeSourcesTracksFromHistory(
                  sourcesToDelete.value,
                  removeMultiSourceDuplicates: removeDuplicates.value,
                  oldestDate: oldestDate,
                  newestDate: newestDate,
                );
                isRemovingRx.value = false;
                NamidaNavigator.inst.closeDialog();
                snackyy(title: lang.NOTE, message: "${lang.REMOVED} ${removedNum.displayTrackKeyword}");
              },
            ),
          )
        ],
        child: Obx(
          (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12.0),
              Row(
                children: [
                  const SizedBox(width: 8.0),
                  const Icon(Broken.danger),
                  const SizedBox(width: 8.0),
                  Obx((context) => Text(
                        '${lang.TOTAL_TRACKS}: ${totalTracksToBeRemoved.valueR}',
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
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Obx(
                      (context) => ListTileWithCheckMark(
                        active: isActive(source),
                        title: '${source.name} (${count.formatDecimal()})',
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
              NamidaContainerDivider(
                margin: EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
              ),
              Obx(
                (context) => ListTileWithCheckMark(
                  icon: Broken.broom,
                  active: removeDuplicates.valueR,
                  title: lang.REMOVE_DUPLICATES,
                  onTap: () => removeDuplicates.value = !removeDuplicates.value,
                ),
              ),
              const SizedBox(height: 12.0),
              ObxO(
                rx: totalTracksBetweenDates,
                builder: (context, total) => BetweenDatesTextButton(
                  useHistoryDates: true,
                  onConfirm: (dates) {
                    oldestDate = dates.firstOrNull;
                    newestDate = dates.lastOrNull;
                    calculateTotalTracks(oldestDate, newestDate);
                    NamidaNavigator.inst.closeDialog();
                  },
                  tracksLength: total,
                ),
              ),
            ],
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
                (context) {
                  final current = VideoController.inst.localVideoExtractCurrent.valueR;
                  final total = VideoController.inst.localVideoExtractTotal.valueR;
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
                await VideoController.inst.rescanLocalVideosPaths();
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
              onTap: () {
                NamidaNavigator.inst.navigateDialog(
                  dialog: CustomBlurryDialog(
                    normalTitleStyle: true,
                    title: lang.CHOOSE,
                    child: SmoothSingleChildScrollView(
                      child: Column(
                        children: [
                          CustomListTile(
                            title: lang.LOCAL,
                            subtitle: '',
                            icon: Broken.music_library_2,
                            onTap: () {
                              NamidaNavigator.inst.closeDialog();
                              _removeSourceFromHistory(HistoryController.inst);
                            },
                          ),
                          CustomListTile(
                            title: lang.YOUTUBE,
                            subtitle: '',
                            icon: Broken.video_square,
                            onTap: () {
                              NamidaNavigator.inst.closeDialog();
                              _removeSourceFromHistory(YoutubeHistoryController.inst);
                            },
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

          _getCacheSliderWidget(
            stepper: 8 * 4,
            maxGB: 4,
            key: _AdvancedSettingKeys.maxImageCache,
            icon: Broken.gallery,
            title: lang.MAX_IMAGE_CACHE_SIZE,
            rx: settings.imagesMaxCacheInMB,
            onSave: (val) => settings.save(imagesMaxCacheInMB: val),
          ),
          _getCacheSliderWidget(
            stepper: 8 * 4,
            maxGB: 12,
            key: _AdvancedSettingKeys.maxAudioCache,
            icon: Broken.audio_square,
            title: lang.MAX_AUDIO_CACHE_SIZE,
            rx: settings.audiosMaxCacheInMB,
            onSave: (val) => settings.save(audiosMaxCacheInMB: val),
          ),
          _getCacheSliderWidget(
            stepper: 8 * 32,
            maxGB: 32,
            key: _AdvancedSettingKeys.maxVideoCache,
            icon: Broken.video,
            title: lang.MAX_VIDEO_CACHE_SIZE,
            rx: settings.videosMaxCacheInMB,
            onSave: (val) => settings.save(videosMaxCacheInMB: val),
          ),

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
            child: _ClearVideoCacheListTile(
              bgColor: getBgColor(_AdvancedSettingKeys.clearVideoCache),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClearVideoCacheListTile extends StatefulWidget {
  final Color? bgColor;
  const _ClearVideoCacheListTile({this.bgColor});

  @override
  State<_ClearVideoCacheListTile> createState() => __ClearVideoCacheListTileState();
}

class __ClearVideoCacheListTileState extends State<_ClearVideoCacheListTile> {
  int totalSize = -1;

  @override
  void initState() {
    super.initState();
    _fillSizes();
  }

  void _fillSizes() async {
    final res = await _getSizeIsolate.thready([AppDirs.VIDEOS_CACHE, AppDirs.VIDEOS_CACHE_TEMP]);
    if (mounted) setState(() => totalSize = res);
  }

  static int _getSizeIsolate(List<String> dirsPath) {
    int size = 0;
    dirsPath.loop(
      (dirPath) {
        Directory(dirPath).listSyncSafe().loop((e) {
          if (e is File) {
            size += e.fileSizeSync() ?? 0;
          }
        });
      },
    );
    return size;
  }

  @override
  Widget build(BuildContext context) {
    return CustomListTile(
      bgColor: widget.bgColor,
      leading: const StackedIcon(
        baseIcon: Broken.video,
        secondaryIcon: Broken.close_circle,
      ),
      title: lang.CLEAR_VIDEO_CACHE,
      trailingText: totalSize.fileSizeFormatted,
      onTap: () {
        final allvideos = VideoController.inst.getCurrentVideosInCache();
        const cacheManager = StorageCacheManager();
        cacheManager.promptCacheDeleteDialog(
          allItems: allvideos,
          deleteStatsNote: (items) => cacheManager.getDeleteSizeSubtitleText(items.length, totalSize),
          chooseNote: lang.CLEAR_VIDEO_CACHE_NOTE,
          onChoosePrompt: () {
            cacheManager.showChooseToDeleteDialog(
              forVideos: true,
              allItems: allvideos,
              itemToPath: (item) => item.path,
              itemToYtId: (item) {
                if (item.ytID != null) return item.ytID;
                var filename = item.path.getFilename;
                if (filename.length >= 11) return filename.substring(0, 11);
                return null;
              },
              itemToSubtitle: (item, itemSize) => "${item.resolution}p • ${item.framerate}fps - ${itemSize.fileSizeFormatted}",
              confirmDialogText: cacheManager.getDeleteSizeSubtitleText,
              onDeleteFiles: (itemsToDelete) async {
                setState(() => totalSize = -1);
                for (final video in itemsToDelete) {
                  await [
                    File(video.path).tryDeleting(),
                    File('${video.path}.metadata').tryDeleting(),
                  ].wait;
                  if (video.ytID != null) VideoController.inst.removeNVFromCacheMap(video.ytID!, video.path);
                }
                _fillSizes();
              },
              includeLocalTracksListens: true,
              tempFilesSize: cacheManager.getTempVideosSize,
              onDeleteTempFiles: () => cacheManager.deleteTempVideos().then((_) => _fillSizes()),
            );
          },
          onDeleteEVERYTHING: () async {
            await cacheManager.deleteAllVideos();
            VideoController.inst.clearCachedVideosMap();
            if (mounted) setState(() => totalSize = 0);
          },
        );
      },
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
    AppDirs.ARTWORKS_ARTISTS,
    AppDirs.ARTWORKS_ALBUMS,
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
      map[d] = Directory(d).listSyncSafe().fold(0, (previousValue, element) => previousValue + (element is File ? element.fileSizeSync() ?? 0 : 0));
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) => CustomListTile(
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
                  (context) {
                    final total = dirsChoosen.valueR.fold(0, (p, element) => p + (dirsMap[element] ?? 0));
                    return NamidaButton(
                      text: "${lang.CLEAR.toUpperCase()} (${total.fileSizeFormatted})",
                      onPressed: () async {
                        NamidaNavigator.inst.closeDialog();

                        for (final d in dirsChoosen.value) {
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
                          (context) => ListTileWithCheckMark(
                            active: dirsChoosen.contains(e),
                            dense: true,
                            icon: Broken.cpu_setting,
                            title: e.splitLastM(
                                  Platform.pathSeparator,
                                  onMatch: (part) {
                                    if (part.isNotEmpty) return part;
                                    return null;
                                  },
                                ) ??
                                e,
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
    Directory(dirPath).listSyncSafe().loop((e) {
      if (e is File) size += e.fileSizeSync() ?? 0;
    });
    return size;
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
        for (final acFiles in AudioCacheController.inst.audioCacheMap.values) {
          acFiles.loop((e) => allaudios.add(e));
        }

        const cacheManager = StorageCacheManager();
        cacheManager.promptCacheDeleteDialog(
          allItems: allaudios,
          deleteStatsNote: (items) => cacheManager.getDeleteSizeSubtitleText(items.length, totalSize),
          chooseNote: lang.CLEAR_VIDEO_CACHE_NOTE,
          onChoosePrompt: () {
            cacheManager.showChooseToDeleteDialog(
              forVideos: false,
              allItems: allaudios,
              itemToPath: (item) => item.file.path,
              itemToYtId: (item) {
                if (item.youtubeId.isNotEmpty) return item.youtubeId;
                var filename = item.file.path.getFilename;
                if (filename.length >= 11) return filename.substring(0, 11);
                return null;
              },
              itemToSubtitle: (item, size) => "${(item.bitrate ?? 0) ~/ 1000}kb/s - ${size.fileSizeFormatted}",
              confirmDialogText: cacheManager.getDeleteSizeSubtitleText,
              onDeleteFiles: (itemsToDelete) async {
                setState(() => totalSize = -1);
                for (final audio in itemsToDelete) {
                  await audio.file.tryDeleting();
                  await [
                    audio.file.tryDeleting(),
                    File('${audio.file.path}.metadata').tryDeleting(),
                  ].wait;
                  AudioCacheController.inst.removeFromCacheMap(audio.youtubeId, audio.file.path);
                }
                _fillSizes();
              },
              includeLocalTracksListens: true,
              tempFilesSize: cacheManager.getTempAudiosSize,
              onDeleteTempFiles: () => cacheManager.deleteTempAudios().then((_) => _fillSizes()),
            );
          },
          onDeleteEVERYTHING: () async {
            await cacheManager.deleteAllAudios();
            AudioCacheController.inst.clearAll();
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
        final isUpdating = false.obs;
        NamidaNavigator.inst.navigateDialog(
          onDisposing: () {
            updateMissingOnly.close();
            isUpdating.close();
            oldDirController.dispose();
            newDirController.dispose();
          },
          tapToDismiss: () => !isUpdating.value,
          colorScheme: colorScheme,
          dialogBuilder: (theme) => Form(
            key: formKey,
            child: CustomBlurryDialog(
              title: lang.UPDATE_DIRECTORY_PATH,
              actions: [
                const CancelButton(),
                ObxO(
                  rx: isUpdating,
                  builder: (context, updating) => AnimatedEnabled(
                    enabled: !updating,
                    child: NamidaButton(
                      text: lang.UPDATE,
                      onPressed: () async {
                        Future<void> okUpdate() async {
                          isUpdating.value = true;
                          await EditDeleteController.inst.updateDirectoryInEveryPartOfNamida(
                            oldDirController.text,
                            newDirController.text,
                            forThesePathsOnly: tracksPaths,
                            ensureNewFileExists: updateMissingOnly.value,
                          );
                          isUpdating.value = false;
                          NamidaNavigator.inst.closeDialog();
                        }

                        if (formKey.currentState?.validate() ?? false) {
                          if (tracksPaths != null && await tracksPaths!.anyAsync((element) => File(element).exists())) {
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
                    ),
                  ),
                ),
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
                            try {
                              if (!Directory(value).existsSync()) {
                                return lang.DIRECTORY_DOESNT_EXIST;
                              }
                            } catch (e) {
                              return e.toString();
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      NamidaIconButton(
                        onPressed: () async {
                          final dir = await NamidaFileBrowser.getDirectory(note: lang.NEW_DIRECTORY);
                          if (dir != null) newDirController.text = dir;
                        },
                        icon: Broken.folder,
                      )
                    ],
                  ),
                  const SizedBox(height: 12.0),
                  Obx(
                    (context) => CustomSwitchListTile(
                      passedColor: colorScheme,
                      title: lang.UPDATE_MISSING_TRACKS_ONLY,
                      value: updateMissingOnly.valueR,
                      onChanged: (isTrue) => updateMissingOnly.toggle(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FixYTDLPThumbnailSizeListTile extends StatelessWidget {
  final Color? bgColor;

  const _FixYTDLPThumbnailSizeListTile({this.bgColor});

  Future<void> _onFixYTDLPPress() async {
    if (!await requestManageStoragePermission(ensureDirectoryCreated: true)) return;

    final dirs = await NamidaFileBrowser.getDirectories(note: lang.FIX_YTDLP_BIG_THUMBNAIL_SIZE);
    if (dirs.isEmpty) return;
    await NamidaFFMPEG.inst.fixYTDLPBigThumbnailSize(directoriesPaths: dirs);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) {
        final p = NamidaFFMPEG.inst.currentOperations[OperationType.ytdlpThumbnailFix]?.valueR;
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
    final initialDirectories = [AppDirs.ARTWORKS, AppDirs.THUMBNAILS, AppDirs.ARTWORKS_ARTISTS, AppDirs.ARTWORKS_ALBUMS, AppDirs.YT_THUMBNAILS].obs;
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
              _startCompressing(dirsToCompress.value, compPerc.value, keepOriginalFileDates.value);
            },
          ),
        ],
        child: Column(
          children: [
            Obx(
              (context) => SuperSmoothListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: [
                  ...initialDirectories.valueR.map(
                    (e) => Obx(
                      (context) {
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
                (context) => NamidaWheelSlider(
                  max: 100,
                  initValue: 50,
                  text: "${compPerc.valueR}%",
                  onValueChanged: (val) => compPerc.value = val,
                ),
              ),
            ),
            CustomListTile(
              icon: Broken.folder_add,
              title: lang.PICK_FROM_STORAGE,
              onTap: () async {
                final dirsPath = await NamidaFileBrowser.getDirectories(note: lang.COMPRESS_IMAGES);
                if (dirsPath.isEmpty) return;
                initialDirectories.addAll(dirsPath);
                dirsToCompress.addAll(dirsPath);
              },
            ),
            Obx(
              (context) => CustomSwitchListTile(
                icon: Broken.document_code_2,
                title: lang.KEEP_FILE_DATES,
                value: keepOriginalFileDates.valueR,
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
      (context) {
        final p = NamidaFFMPEG.inst.currentOperations[OperationType.imageCompress]?.valueR;
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
