import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/class/youtube_item_download_config.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/functions/download_sheet.dart';
import 'package:namida/youtube/functions/video_download_options.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';

import 'package:namida/main.dart';

class YTPlaylistDownloadPage extends StatefulWidget {
  final List<YoutubeID> ids;
  final String playlistName;
  final Map<String, StreamInfoItem> infoLookup;

  const YTPlaylistDownloadPage({
    super.key,
    required this.ids,
    required this.playlistName,
    required this.infoLookup,
  });

  @override
  State<YTPlaylistDownloadPage> createState() => _YTPlaylistDownloadPageState();
}

class _YTPlaylistDownloadPageState extends State<YTPlaylistDownloadPage> {
  final _selectedList = <String>[].obs; // sometimes a yt playlist can have duplicates (yt bug) so a Set wont be useful.
  final _configMap = <String, YoutubeItemDownloadConfig>{}.obs;
  final _groupName = ''.obs;

  final _folderController = GlobalKey<YTDownloadOptionFolderListTileState>();

  bool useCachedVersionsIfAvailable = true;
  bool autoExtractTitleAndArtist = settings.ytAutoExtractVideoTagsFromInfo.value;
  bool keepCachedVersionsIfDownloaded = false;
  bool downloadFilesWriteUploadDate = settings.downloadFilesWriteUploadDate.value;
  bool addAudioToLocalLibrary = true;
  bool overrideOldFiles = false;
  final preferredQuality = (settings.youtubeVideoQualities.firstOrNull ?? kStockVideoQualities.first).obs;
  final downloadAudioOnly = false.obs;

  void _onItemTap(String id) => _selectedList.addOrRemove(id);

  @override
  void initState() {
    _groupName.value = widget.playlistName;
    _addAllYTIDsToSelected();
    _fillConfigMap();
    super.initState();
  }

  @override
  void dispose() {
    _selectedList.close();
    _configMap.close();
    _groupName.close();
    preferredQuality.close();
    downloadAudioOnly.close();
    super.dispose();
  }

  void _fillConfigMap() {
    widget.ids.loop((e, index) {
      final id = e.id;
      _configMap[id] = _getDummyDownloadConfig(id);
    });
  }

  YoutubeItemDownloadConfig _getDummyDownloadConfig(String id) {
    final videoTitle = widget.infoLookup[id]?.name ?? YoutubeController.inst.getVideoName(id);
    final filename = videoTitle ?? id;
    return YoutubeItemDownloadConfig(
      id: id,
      filename: filename,
      ffmpegTags: {},
      fileDate: null,
      videoStream: null,
      audioStream: null,
      prefferedVideoQualityID: null,
      prefferedAudioQualityID: null,
      fetchMissingStreams: true,
    );
  }

  void _addAllYTIDsToSelected() {
    _selectedList.addAll(widget.ids.map((e) => e.id));
  }

  Future<void> _onEditIconTap({
    required String id,
    required VideoInfo? info,
  }) async {
    await showDownloadVideoBottomSheet(
      showSpecificFileOptionsInEditTagDialog: false,
      videoId: id,
      info: info,
      confirmButtonText: lang.CONFIRM,
      onConfirmButtonTap: (groupName, config) {
        _configMap[id] = config;
        return true;
      },
    );
  }

  void _showAllConfigDialog(BuildContext context) {
    final st = StreamController<int>();
    void rebuildy() => st.add(0);

    const visualDensity = null;

    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        title: lang.CONFIGURE,
        titleWidgetInPadding: Row(
          children: [
            const Icon(Broken.setting_3, size: 28.0),
            const SizedBox(width: 8.0),
            Expanded(
              child: Text(
                lang.CONFIGURE,
                style: context.textTheme.displayLarge,
              ),
            ),
          ],
        ),
        normalTitleStyle: true,
        actions: [
          NamidaButton(
            text: lang.CONFIRM,
            onPressed: NamidaNavigator.inst.closeDialog,
          ),
        ],
        child: StreamBuilder(
            stream: st.stream,
            builder: (context, snapshot) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12.0),
                  YTDownloadOptionFolderListTile(
                    maxTrailingWidth: context.width * 0.2,
                    visualDensity: visualDensity,
                    playlistName: widget.playlistName,
                    initialFolder: _groupName.value,
                    onDownloadGroupNameChanged: (newGroupName) {
                      _groupName.value = newGroupName;
                      _folderController.currentState?.onGroupNameChanged(newGroupName);
                    },
                    onDownloadFolderAdded: (newFolderName) {
                      _folderController.currentState?.onFolderAdd(newFolderName);
                    },
                  ),
                  CustomSwitchListTile(
                    visualDensity: visualDensity,
                    icon: Broken.magicpen,
                    title: lang.AUTO_EXTRACT_TITLE_AND_ARTIST_FROM_VIDEO_TITLE,
                    value: autoExtractTitleAndArtist,
                    onChanged: (isTrue) {
                      autoExtractTitleAndArtist = !autoExtractTitleAndArtist;
                      rebuildy();
                    },
                  ),
                  CustomSwitchListTile(
                    visualDensity: visualDensity,
                    icon: Broken.copy,
                    title: lang.KEEP_CACHED_VERSIONS,
                    value: keepCachedVersionsIfDownloaded,
                    onChanged: (isTrue) {
                      keepCachedVersionsIfDownloaded = !keepCachedVersionsIfDownloaded;
                      rebuildy();
                    },
                  ),
                  CustomSwitchListTile(
                    visualDensity: visualDensity,
                    icon: Broken.document_code,
                    title: lang.SET_FILE_LAST_MODIFIED_AS_VIDEO_UPLOAD_DATE,
                    value: downloadFilesWriteUploadDate,
                    onChanged: (isTrue) {
                      downloadFilesWriteUploadDate = !downloadFilesWriteUploadDate;
                      rebuildy();
                    },
                  ),
                  Obx(
                    () => CustomSwitchListTile(
                      visualDensity: visualDensity,
                      enabled: downloadAudioOnly.value,
                      icon: Broken.music_library_2,
                      title: lang.ADD_AUDIO_TO_LOCAL_LIBRARY,
                      value: downloadAudioOnly.value && addAudioToLocalLibrary,
                      onChanged: (isTrue) {
                        addAudioToLocalLibrary = !addAudioToLocalLibrary;
                        rebuildy();
                      },
                    ),
                  ),
                  CustomSwitchListTile(
                    visualDensity: visualDensity,
                    icon: Broken.danger,
                    title: lang.OVERRIDE_OLD_FILES_IN_THE_SAME_FOLDER,
                    value: overrideOldFiles,
                    onChanged: (isTrue) {
                      overrideOldFiles = !overrideOldFiles;
                      rebuildy();
                    },
                  ),
                  CustomListTile(
                    visualDensity: visualDensity,
                    icon: Broken.story,
                    title: lang.VIDEO_QUALITY,
                    trailing: NamidaPopupWrapper(
                      childrenDefault: () => [
                        NamidaPopupItem(
                          icon: Broken.musicnote,
                          title: lang.AUDIO,
                          onTap: () {
                            downloadAudioOnly.value = true;
                          },
                        ),
                        ...kStockVideoQualities.map(
                          (e) => NamidaPopupItem(
                            icon: Broken.story,
                            title: e,
                            onTap: () {
                              downloadAudioOnly.value = false;
                              preferredQuality.value = e;
                            },
                          ),
                        )
                      ],
                      child: Obx(() => Text(downloadAudioOnly.value ? lang.AUDIO_ONLY : preferredQuality.value)),
                    ),
                  ),
                ],
              );
            }),
      ),
    );
  }

  double get _bottomPaddingEffective => Dimensions.inst.globalBottomPaddingEffective;

  double _hmultiplier = 0.9;
  double _previousScale = 0.9;

  @override
  Widget build(BuildContext context) {
    final thumWidth = context.width * 0.3 * _hmultiplier;
    final thumHeight = thumWidth * 9 / 16;
    return BackgroundWrapper(
      child: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 12.0),
              Obx(
                () => CustomListTile(
                  icon: Broken.music_playlist,
                  title: widget.playlistName,
                  subtitle: "${_selectedList.length.formatDecimal()}/${widget.ids.length.formatDecimal()}",
                  visualDensity: VisualDensity.compact,
                  trailingRaw: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      NamidaIconButton(
                        tooltip: lang.INVERT_SELECTION,
                        icon: Broken.recovery_convert,
                        onPressed: () {
                          widget.ids.loop((e, index) {
                            _selectedList.addOrRemove(e.id);
                          });
                        },
                      ),
                      Obx(
                        () => Checkbox.adaptive(
                          splashRadius: 28.0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4.0.multipliedRadius),
                          ),
                          tristate: true,
                          value: _selectedList.isEmpty
                              ? false
                              : _selectedList.length != widget.ids.length
                                  ? null
                                  : true,
                          onChanged: (value) {
                            if (_selectedList.length != widget.ids.length) {
                              _selectedList.clear();
                              _addAllYTIDsToSelected();
                            } else {
                              _selectedList.clear();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Obx(
                () => YTDownloadOptionFolderListTile(
                  key: _folderController,
                  visualDensity: VisualDensity.compact,
                  trailingPadding: 12.0,
                  playlistName: widget.playlistName,
                  initialFolder: _groupName.value,
                  subtitle: (value) => "${AppDirs.YOUTUBE_DOWNLOADS}$value",
                  onDownloadGroupNameChanged: (newGroupName) {
                    _groupName.value = newGroupName;
                  },
                ),
              ),
              Expanded(
                child: NamidaScrollbar(
                  child: CustomScrollView(
                    slivers: [
                      const SliverPadding(padding: EdgeInsets.only(bottom: 12.0)),
                      SliverFixedExtentList.builder(
                        itemExtent: Dimensions.youtubeCardItemExtent * _hmultiplier,
                        itemCount: widget.ids.length,
                        itemBuilder: (context, index) {
                          final id = widget.ids[index].id;
                          final info = widget.infoLookup[id]?.toVideoInfo() ?? YoutubeController.inst.getVideoInfo(id);
                          final duration = info?.duration?.inSeconds.secondsLabel;

                          return Obx(
                            () {
                              final isSelected = _selectedList.contains(id);
                              final filename = _configMap[id]?.filename;
                              final fileExists = File("${AppDirs.YOUTUBE_DOWNLOADS}${_groupName.value}/$filename").existsSync();
                              return NamidaInkWell(
                                animationDurationMS: 200,
                                height: Dimensions.youtubeCardItemHeight * _hmultiplier,
                                margin: EdgeInsets.symmetric(horizontal: 12.0, vertical: Dimensions.youtubeCardItemVerticalPadding * _hmultiplier),
                                borderRadius: 12.0,
                                bgColor: context.theme.cardColor.withOpacity(0.3),
                                decoration: isSelected
                                    ? BoxDecoration(
                                        border: Border.all(
                                        color: context.theme.colorScheme.secondary.withOpacity(0.5),
                                        width: 2.0,
                                      ))
                                    : const BoxDecoration(),
                                onTap: () => _onItemTap(id),
                                onLongPress: () {
                                  if (_selectedList.isEmpty) return;
                                  int? latestIndex;
                                  for (int i = widget.ids.length - 1; i >= 0; i--) {
                                    final item = widget.ids[i];
                                    if (_selectedList.contains(item.id)) {
                                      latestIndex = i;
                                      break;
                                    }
                                  }
                                  if (latestIndex != null && index > latestIndex) {
                                    final selectedRange = widget.ids.getRange(latestIndex + 1, index + 1);
                                    selectedRange.toList().loop((e, index) {
                                      if (!_selectedList.contains(e.id)) _selectedList.add(e.id);
                                    });
                                  } else {
                                    _onItemTap(id);
                                  }
                                },
                                child: Stack(
                                  children: [
                                    Row(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(4.0),
                                          child: YoutubeThumbnail(
                                            key: Key(id),
                                            borderRadius: 8.0,
                                            width: thumWidth - 4.0,
                                            height: thumHeight - 4.0,
                                            isImportantInCache: false,
                                            videoId: id,
                                            smallBoxText: duration,
                                          ),
                                        ),
                                        const SizedBox(width: 4.0),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const SizedBox(height: 6.0),
                                              Text(
                                                info?.name ?? id,
                                                style: context.textTheme.displayMedium?.copyWith(fontSize: 15.0.multipliedFontScale * _hmultiplier),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4.0),
                                              Row(
                                                children: [
                                                  NamidaIconButton(
                                                    horizontalPadding: 0.0,
                                                    icon: fileExists ? Broken.tick_circle : Broken.import_2,
                                                    iconSize: 15.0,
                                                  ),
                                                  const SizedBox(width: 2.0),
                                                  Text(
                                                    info?.uploaderName ?? YoutubeController.inst.getVideoChannelName(id) ?? '',
                                                    style: context.textTheme.displaySmall?.copyWith(fontSize: 14.0.multipliedFontScale * _hmultiplier),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6.0),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 4.0),
                                        NamidaIconButton(
                                          horizontalPadding: 0.0,
                                          icon: Broken.edit_2,
                                          iconSize: 20.0,
                                          onPressed: () => _onEditIconTap(id: id, info: info),
                                        ),
                                        Checkbox.adaptive(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(4.0.multipliedRadius),
                                          ),
                                          value: isSelected,
                                          onChanged: (value) => _onItemTap(id),
                                        ),
                                        const SizedBox(width: 4.0),
                                      ],
                                    ),
                                    Positioned(
                                      right: 0,
                                      child: NamidaBlurryContainer(
                                        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(6.0.multipliedRadius)),
                                        padding: const EdgeInsets.only(top: 2.0, right: 8.0, left: 6.0, bottom: 2.0),
                                        child: Text(
                                          '${index + 1}',
                                          style: context.textTheme.displaySmall,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                      Obx(() => SliverPadding(padding: EdgeInsets.only(bottom: _bottomPaddingEffective + 56.0 + 4.0))),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Obx(
            () => AnimatedPositioned(
              curve: Curves.fastEaseInToSlowEaseOut,
              duration: const Duration(milliseconds: 400),
              bottom: _bottomPaddingEffective,
              right: 12.0,
              child: Row(
                children: [
                  FloatingActionButton.small(
                    backgroundColor: context.theme.disabledColor.withOpacity(1.0),
                    heroTag: 'config_fab',
                    child: Icon(Broken.setting_3, color: Colors.white.withOpacity(0.8)),
                    onPressed: () {
                      _showAllConfigDialog(context);
                    },
                  ),
                  const SizedBox(width: 8.0),
                  Obx(
                    () => AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: _selectedList.isEmpty ? 1 : 1.0,
                      child: FloatingActionButton.extended(
                        heroTag: 'download_fab',
                        backgroundColor: (_selectedList.isEmpty ? context.theme.disabledColor : CurrentColor.inst.color).withOpacity(1.0),
                        isExtended: true,
                        icon: Icon(
                          Broken.import_2,
                          size: 28.0,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        label: Text(
                          lang.DOWNLOAD,
                          style: context.textTheme.displayMedium?.copyWith(
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                        onPressed: () async {
                          if (_selectedList.isEmpty) return;
                          if (!await requestManageStoragePermission()) return;
                          NamidaNavigator.inst.popPage();
                          YoutubeController.inst.downloadYoutubeVideos(
                            groupName: widget.playlistName,
                            itemsConfig: _selectedList.map((id) => _configMap[id] ?? _getDummyDownloadConfig(id)).toList(),
                            useCachedVersionsIfAvailable: true,
                            autoExtractTitleAndArtist: autoExtractTitleAndArtist,
                            keepCachedVersionsIfDownloaded: keepCachedVersionsIfDownloaded,
                            downloadFilesWriteUploadDate: downloadFilesWriteUploadDate,
                            addAudioToLocalLibrary: true,
                            deleteOldFile: overrideOldFiles,
                            audioOnly: downloadAudioOnly.value,
                            preferredQualities: () {
                              final list = <String>[];
                              for (final q in kStockVideoQualities) {
                                list.add(q);
                                if (q == preferredQuality.value) break;
                              }
                              return list;
                            }(),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: ScaleDetector(
              onScaleStart: (details) => _previousScale = _hmultiplier,
              onScaleUpdate: (details) => setState(() => _hmultiplier = (details.scale * _previousScale).clamp(0.5, 2.0)),
            ),
          ),
        ],
      ),
    );
  }
}
