import 'dart:async';

import 'package:flutter/material.dart';

import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/class/youtipie_feed/playlist_basic_info.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/class/route.dart';
import 'package:namida/controller/audio_cache_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/main.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/download_task_base.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/class/youtube_item_download_config.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/functions/download_sheet.dart';
import 'package:namida/youtube/functions/video_download_options.dart';
import 'package:namida/youtube/widgets/yt_download_sponsorblock_tile.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:namida/youtube/yt_utils.dart';

class YTPlaylistDownloadPage extends StatefulWidget with NamidaRouteWidget {
  @override
  String? get name => playlistName;
  @override
  RouteType get route => RouteType.YOUTUBE_PLAYLIST_DOWNLOAD_SUBPAGE;

  final List<YoutubeID> ids;
  final String playlistName;
  final Map<String, StreamInfoItem> infoLookup;
  final PlaylistBasicInfo? playlistInfo;
  final bool cacheOnly;

  const YTPlaylistDownloadPage({
    super.key,
    required this.ids,
    required this.playlistName,
    required this.infoLookup,
    required this.playlistInfo,
    this.cacheOnly = false,
  });

  @override
  State<YTPlaylistDownloadPage> createState() => _YTPlaylistDownloadPageState();
}

class _YTPlaylistDownloadPageState extends State<YTPlaylistDownloadPage> {
  final _selectedList = <String>[].obs; // sometimes a yt playlist can have duplicates (yt bug) so a Set wont be useful.
  final _configMap = <String, YoutubeItemDownloadConfig>{}.obs;
  late final _groupName = DownloadTaskGroupName(groupName: widget.playlistName.emptyIfHasDefaultPlaylistName()).obs;
  final _downloadedIds = <String>{}.obs;
  final _sponsorSegmentsCategories = Rxn<List<String>>();

  bool useCachedVersionsIfAvailable = true;
  final preferredQuality = (settings.youtubeVideoQualities.value.firstOrNull ?? kStockVideoQualities.first).obs;

  bool _didManuallyEditSelection = false;

  void _onItemTap(String id) => _selectedList.addOrRemove(id);

  void _onGroupNameChanged() {
    _refreshDownloadedState();
    if (!widget.cacheOnly) _validateGroupFiles();
  }

  void _refreshDownloadedState() {
    final videoIds = widget.ids.map((e) => e.id);
    final downloadedIds = widget.cacheOnly
        ? videoIds.where(AudioCacheController.inst.isAvailableOffline).toSet()
        : YoutubeController.inst.getDownloadedVideoIdsInGroup(videoIds, _groupName.value);
    _downloadedIds.value = downloadedIds;
    if (_didManuallyEditSelection) return;
    final notDownloadedIds = videoIds.where((id) => !downloadedIds.contains(id));
    _selectedList.assignAll(notDownloadedIds);
  }

  Future<void> _validateGroupFiles() async {
    final groupName = _groupName.value;
    final didFindMissingFiles = await YoutubeController.inst.validateDownloadedFiles(groupName);
    if (!didFindMissingFiles || !mounted) return;
    if (_groupName.value != groupName) return;
    _refreshDownloadedState();
  }

  @override
  void initState() {
    onRenameAllTasks(settings.youtube.downloadFilenameBuilder.value); // needed to provide initial data specially original indices
    _onGroupNameChanged();
    _groupName.addListener(_onGroupNameChanged);
    super.initState();
  }

  @override
  void dispose() {
    _groupName.removeListener(_onGroupNameChanged);
    _selectedList.close();
    _configMap.close();
    _groupName.close();
    _downloadedIds.close();
    _sponsorSegmentsCategories.close();
    preferredQuality.close();
    super.dispose();
  }

  void onRenameAllTasks(String? defaultFilename) {
    final timeNow = DateTime.now();
    final group = _groupName.value;
    widget.ids
        .mapIndexed((ytid, originalIndex) => _configMap.value[ytid.id] = _getDummyDownloadConfig(ytid.id, originalIndex, group, defaultFilename: defaultFilename, timeNow: timeNow))
        .toList();
  }

  void _updateAudioOnly(bool audioOnly) {
    settings.downloadAudioOnly.save(audioOnly);
    _configMap.value.updateAll((key, value) => value.copyWith(fetchMissingVideo: !audioOnly));
    _configMap.refresh();
  }

  YoutubeItemDownloadConfig _getDummyDownloadConfig(String id, int originalIndex, DownloadTaskGroupName group, {String? defaultFilename, required DateTime timeNow}) {
    final streamInfoItem = widget.infoLookup[id];
    final filenameBuilderSettings = settings.youtube.downloadFilenameBuilder.value;
    final filename = filenameBuilderSettings.isNotEmpty
        ? filenameBuilderSettings
        : (defaultFilename ?? streamInfoItem?.title ?? YoutubeInfoController.utils.getVideoNameSync(id) ?? id);
    return YoutubeItemDownloadConfig(
      originalIndex: originalIndex,
      totalLength: widget.playlistInfo?.videosCount ?? widget.ids.length,
      playlistId: widget.playlistInfo?.id,
      playlistInfo: widget.playlistInfo,
      id: DownloadTaskVideoId(videoId: id),
      groupName: group,
      filename: DownloadTaskFilename.create(initialFilename: filename),
      ffmpegTags: {},
      fileDate: null,
      videoStream: null,
      audioStream: null,
      streamInfoItem: streamInfoItem,
      prefferedVideoQualityID: null,
      prefferedAudioQualityID: null,
      fetchMissingAudio: true,
      fetchMissingVideo: !settings.downloadAudioOnly.value,
      addedAt: timeNow,
      addAudioToLocalLibrary: settings.downloadAddAudioToLocalLibrary.value,
      autoExtractTitleAndArtist: settings.youtube.autoExtractVideoTagsFromInfo.value,
      keepCachedVersionsIfDownloaded: settings.downloadFilesKeepCachedVersions.value,
      downloadFilesWriteUploadDate: settings.downloadFilesWriteUploadDate.value,
      deleteOldFile: settings.downloadOverrideOldFiles.value,
      removeSponsorSegments: settings.youtube.sponsorBlockSettings.value.removeSegmentsFromDownloads,
      splitByChapters: settings.youtube.splitDownloadsByChapters.value,
      chapter: null,
      sponsorSegmentsCategories: _sponsorSegmentsCategories.value,
      localPlaylistName: null,
      cacheOnly: false,
    );
  }

  String _getLocalPlaylistName(DownloadTaskGroupName group) => group.groupName.isNotEmpty ? group.groupName : widget.playlistName.translatePlaylistName();

  List<String> get _preferredQualities {
    final list = <String>[];
    for (final q in kStockVideoQualities) {
      list.add(q);
      if (q == preferredQuality.value) break;
    }
    return list;
  }

  void _addAllYTIDsToSelected() {
    _selectedList.assignAll(widget.ids.map((e) => e.id));
    _didManuallyEditSelection = false;
  }

  void _onInvertSelectionTap() {
    for (final e in widget.ids) {
      _onItemTap(e.id);
    }
    _didManuallyEditSelection = true;
  }

  void _onSelectAllTap() {
    if (_selectedList.length != widget.ids.length) {
      _addAllYTIDsToSelected();
    } else {
      _selectedList.clear();
    }
  }

  String? _getPreviewSampleId(List<String> selectedIds) => selectedIds.firstOrNull ?? widget.ids.firstOrNull?.id;

  String _getPreviewExtension(bool audioOnly, bool preferOpus) {
    if (!audioOnly) return 'mp4';
    return preferOpus ? 'webm' : 'm4a';
  }

  String _buildFilenamePreview(String template, String? sampleId, String extension) {
    if (sampleId == null) return template;
    final config = _configMap.value[sampleId];
    final info = widget.infoLookup[sampleId] ?? YoutubeInfoController.utils.getStreamInfoSync(sampleId);
    final rebuilt = YoutubeController.filenameBuilder.rebuildFilenameWithDecodedParams(
      template,
      sampleId,
      null,
      null,
      info,
      widget.playlistInfo,
      null,
      null,
      config?.originalIndex,
      config?.totalLength,
      fallbackExt: extension,
    );
    final filename = rebuilt ?? template;
    if (filename.endsWith('.$extension')) return filename;
    final filenameWOExt = YoutubeController.removeMediaContainerExtension(filename);
    return '$filenameWOExt.$extension';
  }

  void _onFilenameEditTap() {
    YTUtils.showFilenameBuilderOutputSheet(
      groupName: _groupName.value.groupName,
      previewBuilder: (template) {
        final sampleId = _getPreviewSampleId(_selectedList.value);
        final extension = _getPreviewExtension(settings.downloadAudioOnly.value, settings.youtube.preferOpusFormat.value);
        return _buildFilenamePreview(template, sampleId, extension);
      },
      onChanged: onRenameAllTasks,
    );
  }

  Future<void> _onEditIconTap({
    required String id,
    required int originalIndex,
  }) async {
    await showDownloadVideoBottomSheet(
      originalIndex: _configMap.value[id]?.originalIndex,
      totalLength: _configMap.value[id]?.totalLength,
      streamInfoItem: widget.infoLookup[id],
      playlistInfo: widget.playlistInfo,
      playlistId: widget.playlistInfo?.id,
      initialGroupName: widget.playlistName.emptyIfHasDefaultPlaylistName(),
      showSpecificFileOptionsInEditTagDialog: false,
      videoId: id,
      initialItemConfig: _configMap.value[id],
      confirmButtonText: lang.confirm,
      onConfirmButtonTap: (groupName, config) {
        _configMap.value[id] = config;
        return true;
      },
    );
  }

  List<NamidaPopupItem> _qualityMenuChildren() => [
    NamidaPopupItem(
      icon: Broken.musicnote,
      title: lang.audio,
      selected: settings.downloadAudioOnly.value,
      onTap: () {
        _updateAudioOnly(true);
      },
    ),
    ...kStockVideoQualities.map(
      (e) => NamidaPopupItem(
        icon: Broken.story,
        title: e,
        selected: !settings.downloadAudioOnly.value && preferredQuality.value == e,
        onTap: () {
          _updateAudioOnly(false);
          preferredQuality.value = e;
        },
      ),
    ),
  ];

  void _showAllConfigDialog() {
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        horizontalInset: 32.0,
        title: lang.configure,
        titleWidgetInPadding: Row(
          children: [
            const Icon(Broken.setting_3, size: 28.0),
            const SizedBox(width: 8.0),
            Expanded(
              child: NamidaText(
                lang.configure,
                style: NText.large,
              ),
            ),
          ],
        ),
        normalTitleStyle: true,
        actions: [
          NamidaButton(
            text: lang.done,
            onTap: NamidaNavigator.inst.closeDialog,
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6.0),
            if (!widget.cacheOnly) ...[
              ObxO(
                rx: settings.youtube.autoExtractVideoTagsFromInfo,
                builder: (context, autoExtractVideoTagsFromInfo) => CustomSwitchListTile(
                  icon: Broken.magicpen,
                  title: lang.autoExtractTitleAndArtistFromVideoTitle,
                  value: autoExtractVideoTagsFromInfo,
                  onChanged: (isTrue) => settings.youtube.autoExtractVideoTagsFromInfo.save(!isTrue),
                ),
              ),
              ObxO(
                rx: settings.downloadFilesKeepCachedVersions,
                builder: (context, downloadFilesKeepCachedVersions) => CustomSwitchListTile(
                  icon: Broken.copy,
                  title: lang.keepCachedVersions,
                  value: downloadFilesKeepCachedVersions,
                  onChanged: (isTrue) => settings.downloadFilesKeepCachedVersions.save(!isTrue),
                ),
              ),
              ObxO(
                rx: settings.downloadFilesWriteUploadDate,
                builder: (context, downloadFilesWriteUploadDate) => CustomSwitchListTile(
                  icon: Broken.calendar_edit,
                  title: lang.setFileLastModifiedAsVideoUploadDate,
                  value: downloadFilesWriteUploadDate,
                  onChanged: (isTrue) => settings.downloadFilesWriteUploadDate.save(!isTrue),
                ),
              ),
              ObxO(
                rx: settings.youtube.splitDownloadsByChapters,
                builder: (context, splitDownloadsByChapters) => CustomSwitchListTile(
                  icon: Broken.crop,
                  title: lang.splitByChapters,
                  subtitle: lang.splitByChaptersSubtitle,
                  value: splitDownloadsByChapters,
                  onChanged: (isTrue) => settings.youtube.splitDownloadsByChapters.save(!isTrue),
                ),
              ),
              YTDownloadSponsorBlockTile(
                categoriesOverride: _sponsorSegmentsCategories,
              ),
              ObxO(
                rx: settings.downloadAddAudioToLocalLibrary,
                builder: (context, addAudioToLocalLibrary) => CustomSwitchListTile(
                  enabled: true,
                  icon: Broken.music_library_2,
                  title: lang.addAudioToLocalLibrary,
                  value: addAudioToLocalLibrary,
                  onChanged: (isTrue) => settings.downloadAddAudioToLocalLibrary.save(!isTrue),
                ),
              ),
              Obx(
                (context) {
                  final addAudioToLocalLibrary = settings.downloadAddAudioToLocalLibrary.valueR;
                  return CustomSwitchListTile(
                    enabled: addAudioToLocalLibrary,
                    icon: Broken.music_playlist,
                    title: lang.addToPlaylist,
                    subtitle: _getLocalPlaylistName(_groupName.valueR),
                    value: addAudioToLocalLibrary && settings.downloadAddToLocalPlaylist.valueR,
                    onChanged: (isTrue) => settings.downloadAddToLocalPlaylist.save(!isTrue),
                  );
                },
              ),
              ObxO(
                rx: settings.downloadOverrideOldFiles,
                builder: (context, override) => CustomSwitchListTile(
                  icon: Broken.danger,
                  title: lang.overrideOldFilesInTheSameFolder,
                  value: override,
                  onChanged: (isTrue) => settings.downloadOverrideOldFiles.save(!isTrue),
                ),
              ),
            ],
            NamidaPopupWrapper(
              childrenDefault: _qualityMenuChildren,
              childBuilder: (openMenu) => CustomListTile(
                icon: Broken.story,
                title: lang.videoQuality,
                trailing: NamidaPopupWrapper(
                  childrenDefault: _qualityMenuChildren,
                  child: Obx(
                    (context) => NamidaText(
                      settings.downloadAudioOnly.valueR ? lang.audioOnly : preferredQuality.valueR,
                      style: NText.medium,
                    ),
                  ),
                ),
                onTap: openMenu,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onDownloadTap() async {
    if (_selectedList.isEmpty) return;
    if (!await requestManageStoragePermission(directoryToCreate: AppDirs.YOUTUBE_DOWNLOADS)) return;
    final timeNow = DateTime.now();
    final group = _groupName.value;
    final addToLocalPlaylist = settings.downloadAddAudioToLocalLibrary.value && settings.downloadAddToLocalPlaylist.value;
    final localPlaylistName = addToLocalPlaylist ? _getLocalPlaylistName(group) : null;
    final itemsConfig = _selectedList.value
        .map(
          (id) =>
              // -- dummy is not really used since initState() calls onRenameAllTasks() which fills _configMap
              (_configMap.value[id] ?? _getDummyDownloadConfig(id, widget.ids.indexWhere((element) => element.id == id), group, timeNow: timeNow)).copyWith(
                // -- in case they were changed
                addAudioToLocalLibrary: settings.downloadAddAudioToLocalLibrary.value,
                autoExtractTitleAndArtist: settings.youtube.autoExtractVideoTagsFromInfo.value,
                keepCachedVersionsIfDownloaded: settings.downloadFilesKeepCachedVersions.value,
                downloadFilesWriteUploadDate: settings.downloadFilesWriteUploadDate.value,
                deleteOldFile: settings.downloadOverrideOldFiles.value,
                removeSponsorSegments: settings.youtube.sponsorBlockSettings.value.removeSegmentsFromDownloads,
                splitByChapters: settings.youtube.splitDownloadsByChapters.value,
                sponsorSegmentsCategories: _sponsorSegmentsCategories.value,
                localPlaylistName: localPlaylistName,
              ),
        )
        .toList();
    NamidaNavigator.inst.popPage();
    YoutubeController.inst.downloadYoutubeVideos(
      groupName: group,
      itemsConfig: itemsConfig,
      useCachedVersionsIfAvailable: useCachedVersionsIfAvailable,
      preferredQualities: _preferredQualities,
      playlistInfo: widget.playlistInfo,
    );
  }

  void _onCacheTap() {
    if (_selectedList.isEmpty) return;
    YoutubeController.inst.cacheYoutubeVideos(
      groupName: _groupName.value,
      videoIds: _selectedList.value,
      infoLookup: widget.infoLookup,
      audioOnly: settings.downloadAudioOnly.value,
      preferredQualities: _preferredQualities,
    );
    NamidaNavigator.inst.popPage();
  }

  double get _bottomPaddingEffective => Dimensions.inst.globalBottomPaddingEffectiveR;

  double _hmultiplier = 0.9;
  double _previousScale = 0.9;

  @override
  Widget build(BuildContext context) {
    final thumHeight = _hmultiplier * Dimensions.youtubeThumbnailHeight;
    final thumWidth = thumHeight * 16 / 9;
    const cardBorderRadiusRaw = 12.0;
    final downloadsDirPath = YoutubeController.getDownloadsDirectoryPrefix();
    final outputLabelsWidth = _OutputCardRow.measureLabelsWidth(context, [lang.folder, lang.fileName]);
    return BackgroundWrapper(
      child: Stack(
        children: [
          Column(
            children: [
              if (!widget.cacheOnly) ...[
                const SizedBox(height: 8.0),
                LayoutWidthProvider(
                  builder: (context, maxWidth) => NContainer(
                    margin: const EdgeInsets.symmetric(horizontal: 12.0),
                    padding: const EdgeInsets.all(2.0),
                    decoration: (colors) => BoxDecoration(
                      color: colors.card.withOpacityExt(0.3),
                      borderRadius: BorderRadius.circular(14.0.multipliedRadius),
                    ),
                    child: Column(
                      children: [
                        _OutputCardRow(
                          label: lang.folder,
                          labelWidth: outputLabelsWidth,
                          child: Row(
                            children: [
                              Flexible(
                                child: NamidaText(
                                  downloadsDirPath,
                                  style: NText.small,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4.0),
                              YTDownloadFolderPicker(
                                initialFolder: _groupName.value.groupName,
                                playlistName: widget.playlistName.translatePlaylistName(),
                                maxTextWidth: maxWidth * 0.34,
                                onChanged: (newGroupName) => _groupName.value = DownloadTaskGroupName(groupName: newGroupName),
                              ),
                            ],
                          ),
                        ),
                        const NamidaContainerDivider(
                          height: 1.0,
                          margin: EdgeInsets.symmetric(horizontal: 12.0),
                        ),
                        _OutputCardRow(
                          label: lang.fileName,
                          labelWidth: outputLabelsWidth,
                          onTap: _onFilenameEditTap,
                          trailing: const Icon(
                            Broken.edit_2,
                            size: 18.0,
                          ),
                          child: Obx(
                            (context) {
                              final template = settings.youtube.downloadFilenameBuilder.valueR;
                              final templateFinal = template.isEmpty ? settings.youtube.defaultFilenameBuilder : template;
                              final sampleId = _getPreviewSampleId(_selectedList.valueR);
                              final extension = _getPreviewExtension(settings.downloadAudioOnly.valueR, settings.youtube.preferOpusFormat.valueR);
                              final filenamePreview = _buildFilenamePreview(templateFinal, sampleId, extension);
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  NamidaText(
                                    templateFinal,
                                    style: const NText(.small, size: .s10p5),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2.0),
                                  NamidaText(
                                    filenamePreview,
                                    style: const NText(.medium, size: .s12),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8.0),
              Obx(
                (context) => _PlaylistHeaderCard(
                  title: widget.playlistName.translatePlaylistName(),
                  selectedCount: _selectedList.length,
                  totalCount: widget.ids.length,
                  downloadedCount: _downloadedIds.valueR.length,
                  preferredQuality: preferredQuality,
                  qualityMenuChildren: _qualityMenuChildren,
                  onInvertTap: _onInvertSelectionTap,
                  onSelectAllTap: _onSelectAllTap,
                ),
              ),
              const SizedBox(height: 8.0),
              Expanded(
                child: NamidaScrollbarWithController(
                  child: (sc) => SmoothCustomScrollView(
                    controller: sc,
                    slivers: [
                      const SliverPadding(padding: EdgeInsets.only(bottom: 12.0)),
                      SliverFixedExtentList.builder(
                        itemExtent: Dimensions.youtubeCardItemExtent * _hmultiplier,
                        itemCount: widget.ids.length,
                        itemBuilder: (context, originalIndex) {
                          final id = widget.ids[originalIndex].id;
                          final info = widget.infoLookup[id] ?? YoutubeInfoController.utils.getStreamInfoSync(id);
                          final duration = info?.durSeconds?.secondsLabel;

                          return Obx(
                            (context) {
                              final isSelected = _selectedList.contains(id);
                              final fileExists = _downloadedIds.valueR.contains(id);
                              final cardContent = Stack(
                                children: [
                                  Row(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(4.0),
                                        child: YoutubeThumbnail(
                                          type: ThumbnailType.video,
                                          key: Key(id),
                                          borderRadius: 8.0,
                                          width: thumWidth - 4.0,
                                          height: thumHeight - 4.0,
                                          isImportantInCache: false,
                                          videoId: id,
                                          customUrl: info?.liveThumbs.pick()?.url,
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
                                              info?.title ?? id,
                                              style: NText.medium.of(context).copyWith(fontSize: 15.0 * _hmultiplier),
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
                                                _VideoIdToChannelNameWidget(
                                                  channelName: info?.channelName ?? info?.channel?.title,
                                                  videoId: id,
                                                  style: NText.small.of(context).copyWith(fontSize: 14.0 * _hmultiplier),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6.0),
                                          ],
                                        ),
                                      ),
                                      if (!widget.cacheOnly)
                                        NamidaIconButton(
                                          verticalPadding: 4.0,
                                          horizontalPadding: 4.0,
                                          icon: Broken.edit_2,
                                          iconSize: 20.0,
                                          onPressed: () => _onEditIconTap(id: id, originalIndex: originalIndex),
                                        ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                        child: NamidaCheckMark(
                                          size: 18.0,
                                          active: isSelected,
                                        ),
                                      ),
                                      const SizedBox(width: 8.0),
                                    ],
                                  ),
                                  Positioned(
                                    right: 0,
                                    child: NamidaBlurryContainer(
                                      borderRadius: BorderRadius.only(
                                        bottomLeft: Radius.circular(6.0.multipliedRadius),
                                        topRight: Radius.circular(cardBorderRadiusRaw.multipliedRadius),
                                      ),
                                      padding: const EdgeInsets.only(top: 2.0, right: 8.0, left: 6.0, bottom: 2.0),
                                      child: NamidaText(
                                        '${originalIndex + 1}',
                                        style: NText.small,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                              return NBuilder(
                                selfAnimated: true,
                                builder: (context, colors) => NamidaInkWell(
                                  animationDurationMS: 200,
                                  height: Dimensions.youtubeCardItemHeight * _hmultiplier,
                                  margin: EdgeInsets.symmetric(horizontal: 12.0, vertical: Dimensions.youtubeCardItemVerticalPadding * _hmultiplier),
                                  borderRadius: cardBorderRadiusRaw,
                                  bgColor: const NColors(.card, opacity: 0.3),
                                  decoration: isSelected
                                      ? BoxDecoration(
                                          border: Border.all(
                                            color: colors.secondary.withOpacityExt(0.5),
                                            width: 2.0,
                                          ),
                                        )
                                      : const BoxDecoration(),
                                  onTap: () {
                                    _onItemTap(id);
                                    _didManuallyEditSelection = true;
                                  },
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
                                    if (latestIndex != null && originalIndex > latestIndex) {
                                      final selectedRange = widget.ids.getRange(latestIndex + 1, originalIndex + 1);
                                      for (final e in selectedRange) {
                                        if (!_selectedList.contains(e.id)) _selectedList.add(e.id);
                                      }
                                    } else {
                                      _onItemTap(id);
                                    }
                                    _didManuallyEditSelection = true;
                                  },
                                  child: cardContent,
                                ),
                              );
                            },
                          );
                        },
                      ),
                      Obx((context) => SliverPadding(padding: EdgeInsets.only(bottom: _bottomPaddingEffective + 56.0 + 4.0))),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Obx(
            (context) => AnimatedPositioned(
              curve: Curves.fastEaseInToSlowEaseOut,
              duration: const Duration(milliseconds: 400),
              bottom: _bottomPaddingEffective,
              right: 12.0,
              child: Row(
                children: [
                  NamidaFABButton(
                    dim: true,
                    icon: Broken.setting_3,
                    onTap: _showAllConfigDialog,
                  ),
                  const SizedBox(width: 8.0),
                  Obx(
                    (context) {
                      final selectedCount = _selectedList.length;
                      final title = widget.cacheOnly ? lang.cache : lang.download;
                      final text = selectedCount > 0 ? '$title (${selectedCount.formatDecimal()})' : title;
                      return NamidaFABButton(
                        enabled: selectedCount > 0,
                        icon: widget.cacheOnly ? Broken.document_download : Broken.import_2,
                        text: text,
                        onTap: widget.cacheOnly ? _onCacheTap : _onDownloadTap,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: ScaleDetector(
              onScaleStart: (details) => _previousScale = _hmultiplier,
              onScaleUpdate: (details) => setState(() => _hmultiplier = (details.scale * _previousScale).clampDouble(0.5, 2.0)),
              onScaleReset: () => setState(() => _hmultiplier = 1.0),
            ),
          ),
        ],
      ),
    );
  }
}

class YTDownloadFilenameBuilderRow extends StatelessWidget {
  final TextEditingController? controller;
  final TextEditingController? Function()? controllerCallback;
  final Function(String text)? onChanged;
  const YTDownloadFilenameBuilderRow({super.key, required this.controller, this.controllerCallback, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SmoothSingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: YoutubeController.filenameBuilder.availableEncodedParams
            .map(
              (e) => NamidaInkWell(
                borderRadius: 4.0,
                bgColor: NColors.card,
                margin: const EdgeInsets.symmetric(horizontal: 2.0),
                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
                onTap: () {
                  final controller = this.controller ?? controllerCallback?.call();
                  if (controller == null) return;
                  var cursorPos = controller.selection.base.offset;
                  if (cursorPos < 0) return; // require cursor to be active, avoid accidents and whatever
                  String textAfterCursor = controller.text.substring(cursorPos);
                  String textBeforeCursor = controller.text.substring(0, cursorPos);
                  final toAdd = YoutubeController.filenameBuilder.buildParamForFilename(e);
                  controller.text = "$textBeforeCursor$toAdd$textAfterCursor";
                  controller.selection = TextSelection.collapsed(offset: textBeforeCursor.length + toAdd.length);
                  onChanged?.call(controller.text);
                },
                child: NamidaText(
                  e,
                  style: NText.small,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _VideoIdToChannelNameWidget extends StatefulWidget {
  final String? channelName;
  final String videoId;
  final TextStyle? style;

  const _VideoIdToChannelNameWidget({
    required this.channelName,
    required this.videoId,
    required this.style,
  });

  @override
  State<_VideoIdToChannelNameWidget> createState() => _VideoIdToTitleWidgetState();
}

class _VideoIdToTitleWidgetState extends State<_VideoIdToChannelNameWidget> {
  String? _channelName;

  @override
  void initState() {
    super.initState();
    final channelName = widget.channelName;
    if (channelName == null || channelName.isEmpty) {
      initValues();
    } else {
      _channelName = channelName;
    }
  }

  void initValues() async {
    final id = widget.videoId;
    if (id.isEmpty) return;
    final newChannelName = await YoutubeInfoController.utils.getVideoChannelName(id);
    if (mounted) {
      if (newChannelName != _channelName) {
        setState(() => _channelName = newChannelName);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _channelName ?? '',
      style: widget.style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _PlaylistHeaderCard extends StatelessWidget {
  final String title;
  final int selectedCount;
  final int totalCount;
  final int downloadedCount;
  final Rx<String> preferredQuality;
  final List<NamidaPopupItem> Function() qualityMenuChildren;
  final VoidCallback onInvertTap;
  final VoidCallback onSelectAllTap;

  const _PlaylistHeaderCard({
    required this.title,
    required this.selectedCount,
    required this.totalCount,
    required this.downloadedCount,
    required this.preferredQuality,
    required this.qualityMenuChildren,
    required this.onInvertTap,
    required this.onSelectAllTap,
  });

  @override
  Widget build(BuildContext context) {
    final countText = '${selectedCount.formatDecimal()}/${totalCount.formatDecimal()}';
    final isAllSelected = selectedCount > 0 && selectedCount == totalCount;
    final isPartiallySelected = selectedCount > 0 && !isAllSelected;
    return NContainer(
      margin: const EdgeInsets.symmetric(horizontal: 12.0),
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      decoration: (colors) => BoxDecoration(
        color: colors.card.withOpacityExt(0.3),
        borderRadius: BorderRadius.circular(14.0.multipliedRadius),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12.0),
          const Icon(
            Broken.music_playlist,
            size: 22.0,
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NamidaText(
                  title,
                  style: NText.medium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2.0),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Broken.task_square,
                      size: 12.0,
                    ),
                    const SizedBox(width: 4.0),
                    NamidaText(
                      countText,
                      style: NText.small,
                    ),
                    if (downloadedCount > 0) ...[
                      const SizedBox(width: 8.0),
                      const Icon(
                        Broken.tick_circle,
                        size: 12.0,
                      ),
                      const SizedBox(width: 4.0),
                      NamidaText(
                        downloadedCount.formatDecimal(),
                        style: NText.small,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6.0),
          _DownloadQualityChip(
            preferredQuality: preferredQuality,
            menuChildren: qualityMenuChildren,
          ),
          const SizedBox(width: 2.0),
          NamidaIconButton(
            tooltip: () => lang.invertSelection,
            icon: Broken.recovery_convert,
            onPressed: onInvertTap,
          ),
          NamidaIconButton(
            icon: null,
            onPressed: onSelectAllTap,
            child: NamidaTristateCheckMark(
              size: 20.0,
              active: isAllSelected,
              halfActive: isPartiallySelected,
            ),
          ),
          const SizedBox(width: 8.0),
        ],
      ),
    );
  }
}

class _OutputCardRow extends StatelessWidget {
  final String label;
  final double labelWidth;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _OutputCardRow({
    required this.label,
    required this.labelWidth,
    required this.child,
    this.trailing,
    this.onTap,
  });

  static double measureLabelsWidth(BuildContext context, List<String> labels) {
    final style = NText.small.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    double maxWidth = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: textDirection,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      if (painter.width > maxWidth) maxWidth = painter.width;
      painter.dispose();
    }
    return maxWidth.ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    return NamidaInkWell(
      onTap: onTap,
      borderRadius: 12.0,
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: NamidaText(
              label,
              style: NText.small,
              maxLines: 1,
              softWrap: false,
            ),
          ),
          const SizedBox(width: 10.0),
          Expanded(
            child: child,
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8.0),
            trailing,
          ],
        ],
      ),
    );
  }
}

class _DownloadQualityChip extends StatelessWidget {
  final Rx<String> preferredQuality;
  final List<NamidaPopupItem> Function() menuChildren;

  const _DownloadQualityChip({
    required this.preferredQuality,
    required this.menuChildren,
  });

  @override
  Widget build(BuildContext context) {
    return NamidaPopupWrapper(
      childrenDefault: menuChildren,
      child: NContainer(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        decoration: (colors) => BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(8.0.multipliedRadius),
        ),
        child: Obx(
          (context) {
            final isAudioOnly = settings.downloadAudioOnly.valueR;
            final icon = isAudioOnly ? Broken.musicnote : Broken.story;
            final title = isAudioOnly ? lang.audio : preferredQuality.valueR;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16.0,
                ),
                const SizedBox(width: 4.0),
                NamidaText(
                  title,
                  style: NText.medium,
                ),
                const SizedBox(width: 2.0),
                const Icon(
                  Broken.arrow_down_2,
                  size: 14.0,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
