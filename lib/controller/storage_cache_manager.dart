import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:checkmark/checkmark.dart';
import 'package:jiffy/jiffy.dart';

import 'package:namida/class/file_parts.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/thumbnail_manager.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';

enum _CacheSorting { recommended, size, listenCount, accessTime }

class StorageCacheManager {
  const StorageCacheManager();

  Future<void> trimExtraFiles() async {
    await Future.wait([
      _VideoTrimmer()._trimExcessVideoCache(),
      _ImageTrimmer()._trimExcessImageCache(),
      _ImageTrimmer()._trimExcessImageCacheTemp(),
      _AudioTrimmer()._trimExcessAudioCache(),
    ]);
  }

  Future<int> getTempVideosSize() async {
    return _AudioVideoTrimmer._getTempFilesSizeIsolate.thready({'temp': AppDirs.VIDEOS_CACHE_TEMP, 'normal': AppDirs.VIDEOS_CACHE});
  }

  Future<void> deleteTempVideos() async {
    return _AudioVideoTrimmer._deleteTempFilesIsolate.thready({'temp': AppDirs.VIDEOS_CACHE_TEMP, 'normal': AppDirs.VIDEOS_CACHE});
  }

  Future<void> deleteAllVideos() async {
    await Directory(AppDirs.VIDEOS_CACHE).delete(recursive: true).catchError((_) => Directory(''));
    await Directory(AppDirs.VIDEOS_CACHE_TEMP).delete(recursive: true).catchError((_) => Directory(''));

    await Directory(AppDirs.VIDEOS_CACHE).create(recursive: true);
    await Directory(AppDirs.VIDEOS_CACHE_TEMP).create(recursive: true);
  }

  Future<int> getTempAudiosSize() async {
    return _AudioVideoTrimmer._getTempFilesSizeIsolate.thready({'normal': AppDirs.AUDIOS_CACHE});
  }

  Future<void> deleteTempAudios() async {
    return _AudioVideoTrimmer._deleteTempFilesIsolate.thready({'normal': AppDirs.AUDIOS_CACHE});
  }

  Future<void> deleteAllAudios() async {
    await Directory(AppDirs.AUDIOS_CACHE).delete(recursive: true).catchError((_) => Directory(''));
    await Directory(AppDirs.AUDIOS_CACHE).create(recursive: true);
  }

  Future<Map<File, int>> getTempVideosForID(String videoId) async {
    return _VideoTrimmer._getTempVideosForID.thready({'id': videoId, 'temp': AppDirs.VIDEOS_CACHE_TEMP, 'normal': AppDirs.VIDEOS_CACHE});
  }

  Future<Map<File, int>> getTempAudiosForID(String videoId) async {
    return _AudioTrimmer._getTempAudiosForID.thready({'id': videoId, 'dirPath': AppDirs.AUDIOS_CACHE});
  }

  String getDeleteSizeSubtitleText(int length, int totalSize) {
    return lang.DELETE_FILE_CACHE_SUBTITLE.replaceFirst('_FILES_COUNT_', length.formatDecimal()).replaceFirst('_TOTAL_SIZE_', totalSize.fileSizeFormatted);
  }

  void promptCacheDeleteDialog<T>({
    required List<T> allItems,
    required String Function(List<T> items) deleteStatsNote,
    required String chooseNote,
    required void Function() onChoosePrompt,
    required Future<void> Function() onDeleteEVERYTHING,
  }) {
    /// First Dialog
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        isWarning: true,
        normalTitleStyle: true,
        bodyText: "${deleteStatsNote(allItems)}\n$chooseNote",
        actions: [
          /// Pressing Choose
          NamidaButton(
            text: lang.CHOOSE,
            onPressed: () {
              NamidaNavigator.inst.closeDialog();
              onChoosePrompt();
            },
          ),
          const CancelButton(),
          NamidaButton(
            text: lang.DELETE.toUpperCase(),
            onPressed: () async {
              NamidaNavigator.inst.closeDialog();
              await onDeleteEVERYTHING();
            },
          ),
        ],
      ),
    );
  }

  void showChooseToDeleteDialog<T>({
    required List<T> allItems,
    required String Function(T item) itemToPath,
    required String? Function(T item) itemToYtId,
    required String Function(T item, int itemSize) itemToSubtitle,
    required String Function(int length, int totalSize) confirmDialogText,
    required Future<void> Function(List<T> itemsToDelete) onDeleteFiles,
    required Future<int> Function() tempFilesSize,
    required Future<void> Function() onDeleteTempFiles,
    bool includeLocalTracksListens = true,
  }) {
    final itemsToDelete = <T>[].obs;
    final itemsToDeleteSize = 0.obs;
    final allFiles = allItems.obs;

    final deleteTempFiles = false.obs;
    final tempFilesSizeFinal = 0.obs;
    tempFilesSize().then((value) => tempFilesSizeFinal.value = value);

    final currentSort = _CacheSorting.recommended.obs;

    final localIdTrackMap = <String, Track>{};
    if (includeLocalTracksListens) {
      allTracksInLibrary.loop((tr) => localIdTrackMap[tr.youtubeID] = tr);
    }

    int getTotalListensForIDLength(String id) {
      final correspondingTrack = localIdTrackMap[id];
      final local = correspondingTrack == null ? [] : HistoryController.inst.topTracksMapListens.value[correspondingTrack] ?? [];
      final yt = YoutubeHistoryController.inst.topTracksMapListens[id] ?? [];
      return local.length + yt.length;
    }

    final listensMap = <String?, int>{};
    final sizesMap = <String, int>{};
    final accessTimeMap = <String, int>{};
    int maxListenCount = 0;

    allFiles.value.loop((e) {
      final path = itemToPath(e);
      final stats = File(path).statSync();
      final accessed = stats.accessed.millisecondsSinceEpoch;
      final modified = stats.modified.millisecondsSinceEpoch;
      final finalMS = modified > accessed ? modified : accessed;
      sizesMap[path] = stats.size;
      accessTimeMap[path] = finalMS;

      final videoId = itemToYtId(e);
      if (videoId != null) {
        final listensCount = getTotalListensForIDLength(videoId);
        listensMap[videoId] = listensCount;
        if (maxListenCount < listensCount) maxListenCount = listensCount;
      }
    });

    void sortBy(_CacheSorting type) {
      currentSort.value = type;
      switch (type) {
        case _CacheSorting.recommended:
          final maxLastAccess = DateTime.now().millisecondsSinceEpoch;
          allFiles.sortBy((e) {
            final accessTime = accessTimeMap[itemToPath(e)] ?? 0;
            final listenCount = listensMap[itemToYtId(e)] ?? 0;
            final normalizedAccessTime = (accessTime / maxLastAccess);
            final normalizedListenCount = (listenCount / maxListenCount);
            return normalizedAccessTime * 0.3 + normalizedListenCount * 0.7;
          });
        case _CacheSorting.size:
          allFiles.sortByReverse((e) => sizesMap[itemToPath(e)] ?? 0);
        case _CacheSorting.accessTime:
          allFiles.sortBy((e) => accessTimeMap[itemToPath(e)] ?? 0);
        case _CacheSorting.listenCount:
          allFiles.sortBy((e) => listensMap[itemToYtId(e)] ?? 0);
        default:
          null;
      }
    }

    Widget getChipButton({
      required _CacheSorting sort,
      required String title,
      required IconData icon,
      required bool Function(_CacheSorting sort) enabled,
    }) {
      return NamidaInkWell(
        animationDurationMS: 100,
        borderRadius: 8.0,
        bgColor: namida.theme.cardTheme.color,
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          border: enabled(sort) ? Border.all(color: namida.theme.colorScheme.primary) : null,
          borderRadius: BorderRadius.circular(8.0.multipliedRadius),
        ),
        onTap: () => sortBy(sort),
        child: Row(
          children: [
            Icon(icon, size: 18.0),
            const SizedBox(width: 4.0),
            Text(
              title,
              style: namida.textTheme.displayMedium,
            ),
            const SizedBox(width: 4.0),
            const Icon(Broken.arrow_down_2, size: 14.0),
          ],
        ),
      );
    }

    sortBy(currentSort.value);

    NamidaNavigator.inst.navigateDialog(
      onDisposing: () {
        itemsToDelete.close();
        deleteTempFiles.close();
        tempFilesSizeFinal.close();
        allFiles.close();
        currentSort.close();
      },
      dialog: CustomBlurryDialog(
        horizontalInset: 24.0,
        contentPadding: const EdgeInsets.symmetric(horizontal: 0.0),
        isWarning: true,
        normalTitleStyle: true,
        title: lang.CHOOSE,
        actions: [
          const CancelButton(),

          /// Clear after choosing
          Obx(
            (context) => NamidaButton(
              enabled: itemsToDeleteSize.valueR > 0 || itemsToDelete.valueR.isNotEmpty,
              text: "${lang.DELETE.toUpperCase()} (${itemsToDeleteSize.valueR.fileSizeFormatted})",
              onPressed: () async {
                final hasTemp = deleteTempFiles.value && tempFilesSizeFinal.value > 0;
                final finalItemsToDeleteOnlySize = itemsToDeleteSize.value - (hasTemp ? tempFilesSizeFinal.value : 0);
                final firstLine = itemsToDelete.value.isNotEmpty || finalItemsToDeleteOnlySize > 0 ? confirmDialogText(itemsToDelete.value.length, finalItemsToDeleteOnlySize) : '';
                final tempFilesLine = hasTemp ? "${lang.DELETE_TEMP_FILES} (${tempFilesSizeFinal.value.fileSizeFormatted})?" : '';
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
                          onDeleteFiles(itemsToDelete.value);
                          if (hasTemp) onDeleteTempFiles();
                        },
                      ),
                    ],
                    bodyText: [firstLine, tempFilesLine].joinText(separator: '\n'),
                  ),
                );
              },
            ),
          ),
        ],
        child: SizedBox(
          width: namida.width,
          height: namida.height * 0.65,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12.0),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ObxO(
                  rx: currentSort,
                  builder: (context, currentSort) => Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const SizedBox(width: 24.0),
                      getChipButton(
                        sort: _CacheSorting.recommended,
                        title: lang.AUTO,
                        icon: Broken.magic_star,
                        enabled: (sort) => sort == currentSort,
                      ),
                      const SizedBox(width: 12.0),
                      getChipButton(
                        sort: _CacheSorting.size,
                        title: lang.SIZE,
                        icon: Broken.size,
                        enabled: (sort) => sort == currentSort,
                      ),
                      const SizedBox(width: 12.0),
                      getChipButton(
                        sort: _CacheSorting.accessTime,
                        title: lang.OLDEST_WATCH,
                        icon: Broken.sort,
                        enabled: (sort) => sort == currentSort,
                      ),
                      const SizedBox(width: 12.0),
                      getChipButton(
                        sort: _CacheSorting.listenCount,
                        title: lang.TOTAL_LISTENS,
                        icon: Broken.math,
                        enabled: (sort) => sort == currentSort,
                      ),
                      const SizedBox(width: 24.0),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6.0),
              Expanded(
                child: NamidaScrollbarWithController(
                  child: (sc) => Obx(
                    (context) => ListView.builder(
                      controller: sc,
                      padding: EdgeInsets.zero,
                      itemCount: allFiles.valueR.length,
                      itemBuilder: (context, index) {
                        final item = allFiles.value[index];
                        final id = itemToYtId(item);
                        final title = id == null ? null : YoutubeInfoController.utils.getVideoName(id);
                        final listens = id == null ? null : listensMap[id];
                        final itemSize = sizesMap[itemToPath(item)] ?? 0;
                        String? lastPlayedTimeText;
                        if (currentSort.value == _CacheSorting.accessTime || currentSort.value == _CacheSorting.recommended) {
                          final accessTime = accessTimeMap[itemToPath(item)];
                          if (accessTime != null) lastPlayedTimeText = Jiffy.parseFromMillisecondsSinceEpoch(accessTime).fromNow();
                        }
                        return NamidaInkWell(
                          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                          onTap: () {
                            final didRemove = itemsToDelete.remove(item);
                            if (didRemove) {
                              itemsToDeleteSize.value -= itemSize;
                            } else {
                              itemsToDelete.add(item);
                              itemsToDeleteSize.value += itemSize;
                            }
                          },
                          child: Row(
                            children: [
                              ArtworkWidget(
                                key: Key(id ?? ''),
                                thumbnailSize: 92.0,
                                iconSize: 24.0,
                                width: 92,
                                height: 92 * 9 / 16,
                                path: ThumbnailManager.getPathToYTImage(id),
                                forceSquared: true,
                              ),
                              const SizedBox(width: 8.0),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title ?? id ?? '',
                                      style: context.textTheme.displayMedium,
                                    ),
                                    Text(
                                      itemToSubtitle(item, itemSize),
                                      style: context.textTheme.displaySmall,
                                    ),
                                    if (lastPlayedTimeText != null)
                                      Text(
                                        lastPlayedTimeText,
                                        style: context.textTheme.displaySmall,
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8.0),
                              if (listens != null && listens > 0) ...[
                                Text(
                                  listens.toString(),
                                  style: context.textTheme.displaySmall,
                                ),
                                const SizedBox(width: 8.0),
                              ],
                              IgnorePointer(
                                child: SizedBox(
                                  height: 16.0,
                                  width: 16.0,
                                  child: ObxO(
                                    rx: itemsToDelete,
                                    builder: (context, toDelete) => CheckMark(
                                      strokeWidth: 2,
                                      activeColor: context.theme.listTileTheme.iconColor!,
                                      inactiveColor: context.theme.listTileTheme.iconColor!,
                                      duration: const Duration(milliseconds: 400),
                                      active: toDelete.contains(item),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              ObxO(
                rx: tempFilesSizeFinal,
                builder: (context, tempfs) => tempfs > 0
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8.0, top: 8.0, right: 8.0),
                        child: ObxO(
                          rx: deleteTempFiles,
                          builder: (context, deleteTempf) => AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: deleteTempFiles.value ? 1.0 : 0.6,
                            child: NamidaInkWell(
                              borderRadius: 6.0,
                              bgColor: namida.theme.cardColor,
                              padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 6.0),
                              onTap: () {
                                deleteTempFiles.toggle();
                                if (deleteTempFiles.value) {
                                  itemsToDeleteSize.value += tempFilesSizeFinal.value;
                                } else {
                                  itemsToDeleteSize.value -= tempFilesSizeFinal.value;
                                }
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  NamidaCheckMark(
                                    size: 12.0,
                                    active: deleteTempf,
                                  ),
                                  const SizedBox(width: 8.0),
                                  ObxO(
                                    rx: tempFilesSizeFinal,
                                    builder: (context, tempf) => Text(
                                      '${lang.DELETE_TEMP_FILES} (${tempf.fileSizeFormatted})',
                                      style: namida.textTheme.displaySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoTrimmer {
  int get _videosMaxCacheInMB => settings.videosMaxCacheInMB.value;

  Future<int> _trimExcessVideoCache() async {
    final totalMaxBytes = _videosMaxCacheInMB * 1024 * 1024;
    final paramters = {
      'maxBytes': totalMaxBytes,
      'dirPath': AppDirs.VIDEOS_CACHE,
      'dirPathTemp': AppDirs.VIDEOS_CACHE_TEMP,
    };
    return await _trimExcessVideoCacheIsolate.thready(paramters);
  }

  static int _trimExcessVideoCacheIsolate(Map map) {
    final maxBytes = map['maxBytes'] as int;
    final dirPath = map['dirPath'] as String;
    final dirPathTemp = map['dirPathTemp'] as String;

    final videos = Directory(dirPath).listSyncSafe();
    final videosTemp = Directory(dirPathTemp).listSyncSafe();
    videos.sortBy((e) {
      try {
        return e.statSync().accessed;
      } catch (_) {
        return 0;
      }
    });
    final videosFinal = [...videosTemp, ...videos];
    return _Trimmer._trimExcessCache(videosFinal, maxBytes);
  }

  static Map<File, int> _getTempVideosForID(Map params) {
    final id = params['id'] as String;
    final tempDir = params['temp'] as String;
    final normalDir = params['normal'] as String;

    final sep = Platform.pathSeparator;

    final filesMap = <File, int>{};
    void checkFileAndAdd(FileSystemEntity e) {
      if (e is File) {
        final filename = e.path.splitLast(sep);
        if (filename.startsWith(id)) {
          filesMap[e] = e.fileSizeSync() ?? 0;
        }
      }
    }

    Directory(tempDir).listSyncSafe().loop(checkFileAndAdd);
    Directory(normalDir).listSyncSafe().loop((e) {
      if (e.path.endsWith('.part')) {
        checkFileAndAdd(e);
      }
    });
    return filesMap;
  }
}

class _AudioTrimmer {
  int get _audiosMaxCacheInMB => settings.audiosMaxCacheInMB.value;

  /// Returns total deleted bytes.
  Future<int> _trimExcessAudioCache() async {
    final totalMaxBytes = _audiosMaxCacheInMB * 1024 * 1024;
    final paramters = {
      'maxBytes': totalMaxBytes,
      'dirPath': AppDirs.AUDIOS_CACHE,
    };
    return await _trimExcessAudioCacheIsolate.thready(paramters);
  }

  static int _trimExcessAudioCacheIsolate(Map map) {
    final maxBytes = map['maxBytes'] as int;
    final dirPath = map['dirPath'] as String;

    final audios = Directory(dirPath).listSyncSafe();
    audios.sortBy((e) {
      try {
        return e.statSync().accessed;
      } catch (_) {
        return 0;
      }
    });
    return _Trimmer._trimExcessCache(audios, maxBytes);
  }

  static Map<File, int> _getTempAudiosForID(Map params) {
    final id = params['id'] as String;
    final dirPath = params['dirPath'] as String;

    final sep = Platform.pathSeparator;

    final filesMap = <File, int>{};

    Directory(dirPath).listSyncSafe().loop((e) {
      if (e.path.endsWith('.part')) {
        if (e is File) {
          final filename = e.path.splitLast(sep);
          if (filename.startsWith(id)) {
            filesMap[e] = e.fileSizeSync() ?? 0;
          }
        }
      }
    });
    return filesMap;
  }
}

class _ImageTrimmer {
  int get _imagesMaxCacheInMB => settings.imagesMaxCacheInMB.value;

  /// Returns total deleted bytes.
  Future<int> _trimExcessImageCache() async {
    final totalMaxBytes = _imagesMaxCacheInMB * 1024 * 1024;
    final paramters = {
      'maxBytes': totalMaxBytes,
      'dirPath': AppDirs.YT_THUMBNAILS,
      'dirPathChannel': AppDirs.YT_THUMBNAILS_CHANNELS,
    };
    return await _trimExcessImageCacheIsolate.thready(paramters);
  }

  static int _trimExcessImageCacheIsolate(Map map) {
    final maxBytes = map['maxBytes'] as int;
    final dirPath = map['dirPath'] as String;
    final dirPathChannel = map['dirPathChannel'] as String;

    final imagesVideos = Directory(dirPath).listSyncSafe();
    final imagesChannels = Directory(dirPathChannel).listSyncSafe();
    final images = [...imagesVideos, ...imagesChannels];

    images.sortBy((e) {
      try {
        return e.statSync().accessed;
      } catch (_) {
        return 0;
      }
    });
    return _Trimmer._trimExcessCache(images, maxBytes);
  }

  Future<void> _trimExcessImageCacheTemp() async {
    final dirPath = FileParts.joinPath(AppDirs.YT_THUMBNAILS, 'temp');
    if (!await Directory(dirPath).exists()) return;
    return await _trimExcessImageCacheTempIsolate.thready(dirPath);
  }

  static void _trimExcessImageCacheTempIsolate(String dirPath) {
    final images = Directory(dirPath).listSyncSafe();
    int excess = images.length - 2000; // keeping it at max 2000 good files.
    if (excess <= 0) return;

    final partialFiles = <File>[];
    final maxAccessed = DateTime.now();
    final zDateTime = DateTime(0);
    images.sortBy((e) {
      if (e is File) {
        if (e.path.endsWith('.temp')) {
          partialFiles.add(e);
          return maxAccessed; // to put at the end
        } else {
          try {
            return e.statSync().accessed;
          } catch (_) {}
        }
      }
      return zDateTime;
    });
    for (int i = 0; i < partialFiles.length; i++) {
      try {
        partialFiles[i].deleteSync();
      } catch (_) {}
    }

    // -- since we deleted partial files, we recalculate the excess
    excess -= partialFiles.length;
    if (excess <= 0) return;

    int imagesLength = images.length;
    for (int i = 0; i < excess;) {
      final element = images[i];
      if (element is File) {
        try {
          element.deleteSync();
          i++;
        } catch (_) {}
      }
      // i--; // this made things non-safe
      imagesLength--;
      if (imagesLength <= 0) break; // to be safe that i++ wasnt called enough.
    }
  }
}

class _Trimmer {
  static int _trimExcessCache(List<FileSystemEntity> files, int maxBytes) {
    int totalDeletedBytes = 0;
    int totalBytes = 0;
    final sizesMap = <String, int>{};
    files.loop((f) {
      if (f is File) {
        final size = f.fileSizeSync() ?? 0;
        sizesMap[f.path] = size;
        totalBytes += size;
      }
    });
    for (int i = 0; i < files.length; i++) {
      var file = files[i];
      if (totalBytes <= maxBytes) break; // better than checking with each loop
      if (file is File) {
        final deletedSize = sizesMap[file.path] ?? file.fileSizeSync() ?? 0;
        try {
          file.deleteSync();
          totalBytes -= deletedSize;
          totalDeletedBytes += deletedSize;
        } catch (_) {}
      }
    }

    return totalDeletedBytes;
  }
}

class _AudioVideoTrimmer {
  static int _getTempFilesSizeIsolate(Map dirsPath) {
    int size = 0;
    final tempDir = dirsPath['temp'] as String?;
    final normalDir = dirsPath['normal'] as String;
    if (tempDir != null) {
      Directory(tempDir).listSyncSafe().loop((e) {
        if (e is File) {
          size += e.fileSizeSync() ?? 0;
        }
      });
    }
    Directory(normalDir).listSyncSafe().loop((e) {
      if (e is File && e.path.endsWith('.part')) {
        size += e.fileSizeSync() ?? 0;
      }
    });
    return size;
  }

  static void _deleteTempFilesIsolate(Map dirsPath) {
    final tempDir = dirsPath['temp'] as String?;
    final normalDir = dirsPath['normal'] as String;
    if (tempDir != null) {
      Directory(tempDir).listSyncSafe().loop((e) {
        if (e is File) {
          try {
            e.deleteSync();
          } catch (_) {}
        }
      });
    }
    Directory(normalDir).listSyncSafe().loop((e) {
      if (e.path.endsWith('.part')) {
        if (e is File) {
          try {
            e.deleteSync();
          } catch (_) {}
        }
      }
    });
  }
}
