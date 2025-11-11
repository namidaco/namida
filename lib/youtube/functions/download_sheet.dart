import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/class/streams/audio_stream.dart';
import 'package:youtipie/class/streams/video_stream.dart';
import 'package:youtipie/class/streams/video_stream_info.dart';
import 'package:youtipie/class/streams/video_streams_result.dart';
import 'package:youtipie/class/youtipie_feed/playlist_basic_info.dart';
import 'package:youtipie/core/extensions.dart' hide ListUtils;

import 'package:namida/class/file_parts.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/main.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/download_task_base.dart';
import 'package:namida/youtube/class/youtube_item_download_config.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/functions/video_download_options.dart';
import 'package:namida/youtube/pages/yt_playlist_download_subpage.dart';
import 'package:namida/youtube/widgets/yt_shimmer.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:namida/youtube/yt_utils.dart';

/// [onConfirmButtonTap] should return wether to pop sheet or not.
Future<void> showDownloadVideoBottomSheet({
  BuildContext? ctx,
  required String videoId,
  Color? colorScheme,
  String confirmButtonText = '',
  bool Function(String groupName, YoutubeItemDownloadConfig config)? onConfirmButtonTap,
  bool showSpecificFileOptionsInEditTagDialog = true,
  YoutubeItemDownloadConfig? initialItemConfig,
  PlaylistBasicInfo? playlistInfo,
  required String? playlistId,
  required int? originalIndex,
  required int? totalLength,
  required StreamInfoItem? streamInfoItem,
  String? initialGroupName,
}) async {
  colorScheme ??= CurrentColor.inst.color;
  final context = ctx ?? rootContext;
  final theme = context.theme;
  final textTheme = theme.textTheme;

  originalIndex ??= initialItemConfig?.originalIndex;
  totalLength ??= initialItemConfig?.totalLength;
  streamInfoItem ??= initialItemConfig?.streamInfoItem;

  final showAudioWebm = false.obs;
  final showVideoWebm = false.obs;
  final isLoadingInfoRx = Rx<bool>(true);
  final isLoadingStreamsRx = Rx<bool>(true);
  final streamResultRx = Rxn<VideoStreamsResult>();
  final selectedAudioOnlyStream = Rxn<AudioStream>();
  final selectedVideoOnlyStream = Rxn<VideoStream>();
  final videoInfo = Rxn<VideoStreamInfo>();
  final videoOutputFilenameController = TextEditingController();
  final videoThumbnail = Rxn<File>();
  DateTime? videoDateTime;

  final formKey = GlobalKey<FormState>();
  final filenameExists = false.obs;

  String groupName = initialGroupName ?? '';

  final tagsMap = <String, String?>{};
  void updateTagsMap(Map<String, String?> map) {
    for (final e in map.entries) {
      tagsMap[e.key] = e.value;
    }
  }

  final defaultInitialTags = YTUtils.getDefaultTagsFieldsBuilders(settings.youtube.autoExtractVideoTagsFromInfo.value);
  updateTagsMap(defaultInitialTags);
  updateTagsMap(settings.youtube.initialDefaultMetadataTags);

  bool videoOutputFilenameWasUserEdited = false;
  void updatefilenameOutput({String customName = ''}) async {
    if (videoOutputFilenameWasUserEdited) return;

    if (customName != '') {
      videoOutputFilenameController.text = customName;
      return;
    }

    final filenameBuilderInSetting = settings.youtube.downloadFilenameBuilder.value;
    if (filenameBuilderInSetting.isNotEmpty) {
      final streamInfo = await YoutubeInfoController.utils.buildOrUseVideoStreamInfo(videoId, streamResultRx.value);
      final finalFilenameTempRebuilt = YoutubeController.filenameBuilder.rebuildFilenameWithDecodedParams(
        filenameBuilderInSetting,
        videoId,
        streamInfo,
        null,
        streamInfoItem,
        playlistInfo,
        selectedVideoOnlyStream.value,
        selectedAudioOnlyStream.value,
        originalIndex,
        totalLength,
      );
      if (finalFilenameTempRebuilt != null && finalFilenameTempRebuilt.isNotEmpty) {
        videoOutputFilenameController.text = finalFilenameTempRebuilt;
        return;
      }
    }

    final videoTitle = videoInfo.value?.title ?? videoId;
    if (selectedAudioOnlyStream.value == null && selectedVideoOnlyStream.value == null) {
      videoOutputFilenameController.text = videoTitle;
    } else {
      final audioOnly = selectedAudioOnlyStream.value != null && selectedVideoOnlyStream.value == null;
      if (audioOnly) {
        final filenameRealAudio = videoTitle;
        videoOutputFilenameController.text = filenameRealAudio;
      } else {
        final ql = selectedVideoOnlyStream.value?.qualityLabel;
        final filenameRealVideo = ql == null ? videoTitle : "${videoTitle}_$ql";
        videoOutputFilenameController.text = filenameRealVideo;
      }
    }
  }

  if (initialItemConfig != null) {
    // -- yeah filename can stay encoded, but thats good as to not make confusion with other playlist items
    updatefilenameOutput(customName: initialItemConfig.filename.filename);
    updateTagsMap(initialItemConfig.ffmpegTags);
    videoOutputFilenameWasUserEdited = true;
  } else {
    updatefilenameOutput(customName: settings.youtube.downloadFilenameBuilder.value);
  }

  void showWebmWarning() {
    snackyy(
      title: lang.WARNING,
      message: lang.WEBM_NO_EDIT_TAGS_SUPPORT,
      leftBarIndicatorColor: Colors.red,
      altDesign: true,
      top: false,
    );
  }

  void onAudioSelectionChanged() {
    if (selectedAudioOnlyStream.value?.isWebm == true) showWebmWarning(); // webm doesnt support tag editing
  }

  void onVideoSelectionChanged() {
    if (selectedVideoOnlyStream.value?.isWebm == true) showWebmWarning(); // webm doesnt support tag editing

    if (selectedVideoOnlyStream.value == null) {
      if (!settings.downloadAudioOnly.value) settings.save(downloadAudioOnly: true);
    } else {
      if (settings.downloadAudioOnly.value) settings.save(downloadAudioOnly: false);
    }
  }

  void onStreamsObtained(VideoStreamsResult? streams) async {
    streamResultRx.value = streams;
    isLoadingStreamsRx.value = false;
    isLoadingInfoRx.value = false;

    final sInfo = streams?.info;
    if (sInfo != null) videoInfo.value = sInfo;

    selectedAudioOnlyStream.value = streamResultRx.value?.audioStreams.firstNonWebm();
    if (selectedAudioOnlyStream.value == null) {
      selectedAudioOnlyStream.value = streams?.audioStreams.firstOrNull;
      if (selectedAudioOnlyStream.value?.isWebm == true) {
        showAudioWebm.value = true;
      }
    }
    if (settings.downloadAudioOnly.value == false) {
      selectedVideoOnlyStream.value = await streams?.videoStreams.firstWhereEffAsync(
            (e) async {
              final cached = await e.getCachedFile(videoId);
              if (cached != null) return true;
              final strQualityLabel = e.qualityLabel.videoLabelToSettingLabel();
              return !e.isWebm && settings.youtubeVideoQualities.contains(strQualityLabel);
            },
          ) ??
          streams?.videoStreams.firstWhereEff((e) => !e.isWebm);
    }

    onAudioSelectionChanged();
    onVideoSelectionChanged();
    updatefilenameOutput();
    videoDateTime = videoInfo.value?.publishDate.accurateDate ?? videoInfo.value?.uploadDate.accurateDate ?? streamInfoItem?.publishedAt.accurateDate;

    if (initialItemConfig == null ||
        initialItemConfig.ffmpegTags.isEmpty ||
        initialItemConfig.ffmpegTags.values.any((element) => element != null && YoutubeController.filenameBuilder.paramRegex.hasMatch(element))) {
      YTUtils.getMetadataInitialMap(
        videoId,
        streamInfoItem,
        null,
        null,
        streamResultRx.value,
        playlistInfo ?? initialItemConfig?.playlistInfo,
        playlistId ?? initialItemConfig?.playlistId,
        originalIndex,
        totalLength,
        autoExtract: settings.youtube.autoExtractVideoTagsFromInfo.value,
        initialBuilding: initialItemConfig?.ffmpegTags,
      ).then(updateTagsMap);
    }
  }

  final streamsInCache = await YoutubeInfoController.video.fetchVideoStreamsCache(videoId, infoOnly: false);
  if (streamsInCache != null) {
    if (streamsInCache.hasExpired() || streamsInCache.audioStreams.isEmpty) {
      YoutubeInfoController.video.fetchVideoStreams(videoId).catchError((_) => null).then(onStreamsObtained);
    } else {
      onStreamsObtained(streamsInCache);
    }
  } else {
    YoutubeInfoController.video.fetchVideoStreams(videoId).catchError((_) => null).then(onStreamsObtained);
  }

  Widget getQualityChipBase({
    final double? height,
    final double? width,
    final Color? bgColor,
    required final Color? selectedColor,
    final double verticalPadding = 8.0,
    required void Function() onTap,
    required Widget? child,
  }) {
    return NamidaInkWell(
      decoration: selectedColor != null
          ? BoxDecoration(
              border: Border.all(
                color: selectedColor,
              ),
            )
          : const BoxDecoration(),
      height: height,
      width: width,
      animationDurationMS: 100,
      margin: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 4.0),
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      onTap: onTap,
      borderRadius: 8.0,
      bgColor: bgColor ?? (selectedColor != null ? Color.alphaBlend(selectedColor.withAlpha(40), theme.cardTheme.color!) : theme.cardTheme.color),
      child: child,
    );
  }

  Widget getDummyQualityChip({double width = 112.0}) {
    return getQualityChipBase(
      verticalPadding: 0.0,
      selectedColor: null,
      onTap: () {},
      width: width,
      height: 38.0,
      bgColor: theme.colorScheme.surface,
      child: null,
    );
  }

  Widget getQualityButton({
    required final String title,
    final String subtitle = '',
    required final bool cacheExists,
    required final bool selected,
    final double horizontalPadding = 8.0,
    final double verticalPadding = 8.0,
    required void Function() onTap,
  }) {
    final textTheme = context.textTheme;
    final selectedColor = colorScheme!;
    return getQualityChipBase(
      selectedColor: selected ? selectedColor : null,
      verticalPadding: verticalPadding,
      onTap: () {
        onTap();
        updatefilenameOutput();
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: horizontalPadding),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.displayMedium?.copyWith(
                  fontSize: 12.0,
                ),
              ),
              if (subtitle != '')
                Text(
                  subtitle,
                  style: textTheme.displaySmall?.copyWith(
                    fontSize: 12.0,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 6.0),
          Icon(cacheExists ? Broken.tick_circle : Broken.import, size: 18.0),
          SizedBox(width: horizontalPadding),
        ],
      ),
    );
  }

  Widget getTextWidget({
    required final String title,
    required final String? subtitle,
    final IconData? icon,
    final Widget? leading,
    final TextStyle? style,
    required final bool hasWebm,
    required final void Function()? onSussyIconTap,
    required final void Function() onCloseIconTap,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          leading ?? Icon(icon),
          const SizedBox(width: 8.0),
          Text(
            title,
            style: style ?? context.textTheme.displayMedium,
          ),
          if (subtitle != null) ...[
            const SizedBox(width: 8.0),
            Expanded(
              child: Text(
                '• $subtitle',
                style: style ?? context.textTheme.displaySmall,
              ),
            ),
            const SizedBox(width: 8.0),
          ] else
            const Spacer(),
          if (hasWebm)
            NamidaIconButton(
              tooltip: () => lang.SHOW_WEBM,
              verticalPadding: 6.0,
              horizontalPadding: 6.0,
              iconSize: 20.0,
              icon: Broken.video_octagon,
              onPressed: onSussyIconTap,
            ),
          NamidaIconButton(
            verticalPadding: 6.0,
            horizontalPadding: 6.0,
            iconSize: 20.0,
            icon: Broken.close_circle,
            onPressed: () {
              onCloseIconTap();
              updatefilenameOutput();
            },
          ),
          const SizedBox(width: 12.0),
        ],
      ),
    );
  }

  Widget getDivider() => const NamidaContainerDivider(margin: EdgeInsets.symmetric(vertical: 8.0));

  Widget getPopupItem<T>({required List<T> items, required Widget Function(T item) itemBuilder}) {
    return Wrap(
      alignment: WrapAlignment.start,
      runAlignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: items.map((element) => itemBuilder(element)).toList(),
    );
  }

  // --- i tried every single possibility, this is the only way logical.
  const verticalPadding = 18.0;
  final headerKey = GlobalKey();
  final footerKey = GlobalKey();
  final bodyHeightRx = Rxn<double>();
  void updateBodyHeight(double maxHeight) {
    final headerHeight = headerKey.calulateSize()?.height ?? 0;
    final footerHeight = footerKey.calulateSize()?.height ?? 0;
    bodyHeightRx.value = (maxHeight - headerHeight - footerHeight - verticalPadding * 2).withMinimum(128.0);
  }
  // ---------------------------

  await NamidaNavigator.inst.showSheet(
    isScrollControlled: true,
    heightPercentage: 0.7,
    builder: (context, bottomPadding, maxWidth, maxHeight) {
      WidgetsBinding.instance.addPostFrameCallback((_) => updateBodyHeight(maxHeight - bottomPadding)); // has to be always updated
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18.0),
        child: ObxO(
          rx: streamResultRx,
          builder: (context, streamResult) {
            final hasAudioWebm = streamResult?.audioStreams.firstWhereEff((e) => e.isWebm) != null;
            final hasVideoWebm = streamResult?.videoStreams.firstWhereEff((e) => e.isWebm) != null;

            return ObxO(
              rx: videoInfo,
              builder: (context, videoInfo) {
                return SizedBox(
                  height: maxHeight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: verticalPadding),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Padding(
                            key: headerKey,
                            padding: const EdgeInsets.all(8.0),
                            child: ObxO(
                              rx: isLoadingInfoRx,
                              builder: (context, isLoadingInfo) {
                                final infoShimmerEnabled = streamResult == null && videoInfo == null;

                                return Row(
                                  children: [
                                    YoutubeThumbnail(
                                      type: ThumbnailType.video,
                                      key: Key(videoId),
                                      isImportantInCache: true,
                                      borderRadius: 10.0,
                                      videoId: videoId,
                                      customUrl: videoInfo?.thumbnails.pick()?.url,
                                      width: maxWidth * 0.2,
                                      height: maxWidth * 0.2 * 9 / 16,
                                      onImageReady: (imageFile) {
                                        if (imageFile != null) videoThumbnail.value = imageFile;
                                      },
                                    ),
                                    const SizedBox(width: 12.0),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          ShimmerWrapper(
                                            shimmerEnabled: isLoadingInfo,
                                            child: NamidaDummyContainer(
                                              borderRadius: 6.0,
                                              width: maxWidth,
                                              height: 18.0,
                                              shimmerEnabled: infoShimmerEnabled,
                                              child: Text(
                                                videoInfo?.title ?? videoId,
                                                style: textTheme.displayMedium,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 2.0),
                                          ShimmerWrapper(
                                            shimmerEnabled: isLoadingInfo,
                                            child: NamidaDummyContainer(
                                              borderRadius: 4.0,
                                              width: maxWidth - 24.0,
                                              height: 12.0,
                                              shimmerEnabled: infoShimmerEnabled,
                                              child: () {
                                                final date =
                                                    streamResultRx.value?.info?.uploadDate.date ?? streamResultRx.value?.info?.publishDate.date ?? videoInfo?.publishedAt.date;
                                                final dateFormatted = date?.millisecondsSinceEpoch.dateFormattedOriginal;
                                                return Text(
                                                  [
                                                    videoInfo?.durSeconds?.secondsLabel ?? "00:00",
                                                    if (dateFormatted != null) dateFormatted,
                                                  ].join(' - '),
                                                  style: textTheme.displaySmall,
                                                );
                                              }(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6.0),
                                    ObxO(
                                      rx: selectedVideoOnlyStream,
                                      builder: (context, selectedVideo) => ObxO(
                                        rx: selectedAudioOnlyStream,
                                        builder: (context, selectedAudio) {
                                          // -- we allow cuz now we using parameter builders
                                          // if (selectedAudio == null && selectedVideo == null) return const SizedBox();
                                          final isWEBM = (selectedAudio?.isWebm == true || selectedVideo?.isWebm == true);
                                          return Stack(
                                            alignment: Alignment.bottomRight,
                                            children: [
                                              NamidaIconButton(
                                                verticalPadding: 4.0,
                                                horizontalPadding: 8.0,
                                                icon: Broken.edit,
                                                onPressed: () {
                                                  if (videoInfo == null && tagsMap.isEmpty) return;

                                                  showVideoDownloadOptionsSheet(
                                                    videoTitle: videoInfo?.title,
                                                    videoUploader: videoInfo?.channelName,
                                                    tagMaps: tagsMap,
                                                    supportTagging: !isWEBM,
                                                    showSpecificFileOptions: showSpecificFileOptionsInEditTagDialog,
                                                    onDownloadFilenameChanged: (filename) {
                                                      updatefilenameOutput(customName: filename);
                                                      formKey.currentState?.validate();
                                                    },
                                                    onDownloadGroupNameChanged: (newGroupName) {
                                                      groupName = newGroupName;
                                                      formKey.currentState?.validate();
                                                    },
                                                    initialGroupName: initialGroupName,
                                                  );
                                                },
                                              ),
                                              if (isWEBM)
                                                IgnorePointer(
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(6),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: theme.scaffoldBackgroundColor,
                                                          spreadRadius: 0,
                                                          blurRadius: 3.0,
                                                        ),
                                                      ],
                                                    ),
                                                    child: const Icon(
                                                      Broken.info_circle,
                                                      color: Colors.red,
                                                      size: 16.0,
                                                    ),
                                                  ),
                                                )
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          ObxO(
                            rx: isLoadingStreamsRx,
                            builder: (context, isLoadingStreams) => ObxO(
                              rx: bodyHeightRx,
                              builder: (context, bodyHeight) => SizedBox(
                                height: bodyHeight,
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Obx(
                                        (context) {
                                          final e = selectedAudioOnlyStream.valueR;
                                          final subtitle = e == null ? null : "${e.bitrateText()} • ${e.codecInfo.container} • ${e.sizeInBytes.fileSizeFormatted}";
                                          return getTextWidget(
                                            hasWebm: hasAudioWebm,
                                            title: lang.AUDIO,
                                            subtitle: subtitle,
                                            icon: Broken.audio_square,
                                            onCloseIconTap: () {
                                              selectedAudioOnlyStream.value = null;
                                              onAudioSelectionChanged();
                                            },
                                            onSussyIconTap: () {
                                              showAudioWebm.toggle();
                                              if (showAudioWebm.value == false && selectedAudioOnlyStream.value?.isWebm == true) {
                                                selectedAudioOnlyStream.value = streamResult?.audioStreams.firstOrNull;
                                                onAudioSelectionChanged();
                                              }
                                            },
                                          );
                                        },
                                      ),
                                      SizedBox(
                                        width: maxWidth,
                                        child: streamResult?.audioStreams == null
                                            ? Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: ShimmerWrapper(
                                                  shimmerEnabled: isLoadingStreams,
                                                  child: getPopupItem(
                                                    items: List.filled(2, null),
                                                    itemBuilder: (item) => getDummyQualityChip(width: 164.0),
                                                  ),
                                                ),
                                              )
                                            : ObxO(
                                                rx: showAudioWebm,
                                                builder: (context, showAudioWebm) => getPopupItem(
                                                  items: showAudioWebm ? streamResult!.audioStreams : streamResult!.audioStreams.where((element) => !element.isWebm).toList(),
                                                  itemBuilder: (element) {
                                                    return Obx(
                                                      (context) {
                                                        final cacheFile = element.getCachedFileSync(videoId);
                                                        return getQualityButton(
                                                          selected: selectedAudioOnlyStream.valueR == element,
                                                          cacheExists: cacheFile != null,
                                                          title: "${element.codecInfo.codec} • ${element.sizeInBytes.fileSizeFormatted}",
                                                          subtitle: "${element.codecInfo.container} • ${element.bitrateText()}",
                                                          onTap: () {
                                                            selectedAudioOnlyStream.value = element;
                                                            onAudioSelectionChanged();
                                                          },
                                                        );
                                                      },
                                                    );
                                                  },
                                                ),
                                              ),
                                      ),
                                      getDivider(),
                                      ObxO(
                                        rx: selectedVideoOnlyStream,
                                        builder: (context, vostream) {
                                          final subtitle = vostream == null ? null : "${vostream.qualityLabel} • ${vostream.sizeInBytes.fileSizeFormatted}";
                                          return getTextWidget(
                                            hasWebm: hasVideoWebm,
                                            title: lang.VIDEO,
                                            subtitle: subtitle,
                                            icon: Broken.video_square,
                                            onCloseIconTap: () {
                                              selectedVideoOnlyStream.value = null;
                                              onVideoSelectionChanged();
                                            },
                                            onSussyIconTap: () {
                                              showVideoWebm.toggle();
                                              if (showVideoWebm.value == false && selectedVideoOnlyStream.value?.isWebm == true) {
                                                selectedVideoOnlyStream.value = streamResult?.videoStreams.firstOrNull;
                                                onVideoSelectionChanged();
                                              }
                                            },
                                          );
                                        },
                                      ),
                                      SizedBox(
                                        width: maxWidth,
                                        child: streamResult?.videoStreams == null
                                            ? Padding(
                                                padding: const EdgeInsets.all(8.0),
                                                child: ShimmerWrapper(
                                                  shimmerEnabled: isLoadingStreams,
                                                  child: getPopupItem(
                                                    items: List.filled(8, null),
                                                    itemBuilder: (item) => getDummyQualityChip(),
                                                  ),
                                                ),
                                              )
                                            : ObxO(
                                                rx: showVideoWebm,
                                                builder: (context, showVideoWebm) => getPopupItem(
                                                  items: showVideoWebm ? streamResult!.videoStreams : streamResult!.videoStreams.where((element) => !element.isWebm).toList(),
                                                  itemBuilder: (element) {
                                                    return Obx(
                                                      (context) {
                                                        final cacheFile = element.getCachedFileSync(videoId);

                                                        var codecIdentifier = element.codecInfo.codecIdentifierIfCustom();
                                                        var codecIdentifierText = codecIdentifier != null ? ' (${codecIdentifier.toUpperCase()})' : '';

                                                        return getQualityButton(
                                                          selected: selectedVideoOnlyStream.valueR == element,
                                                          cacheExists: cacheFile != null,
                                                          title: "${element.qualityLabel} • ${element.sizeInBytes.fileSizeFormatted}",
                                                          subtitle: "${element.codecInfo.container} • ${element.bitrateText()}$codecIdentifierText",
                                                          onTap: () {
                                                            selectedVideoOnlyStream.value = element;
                                                            onVideoSelectionChanged();
                                                          },
                                                        );
                                                      },
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
                          ),
                          Padding(
                            key: footerKey,
                            padding: EdgeInsets.only(top: 8.0, bottom: bottomPadding + verticalPadding),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Obx((context) {
                                  final videoOnly = selectedVideoOnlyStream.valueR != null && selectedAudioOnlyStream.valueR == null ? lang.VIDEO_ONLY : null;
                                  final audioOnly = selectedVideoOnlyStream.valueR == null && selectedAudioOnlyStream.valueR != null ? lang.AUDIO_ONLY : null;
                                  final audioAndVideo = selectedVideoOnlyStream.valueR != null && selectedAudioOnlyStream.valueR != null ? "${lang.VIDEO} + ${lang.AUDIO}" : null;

                                  return Text.rich(
                                    TextSpan(
                                      text: "${lang.OUTPUT}: ",
                                      style: textTheme.displaySmall,
                                      children: [
                                        TextSpan(
                                          text: videoOnly ?? audioOnly ?? audioAndVideo ?? lang.NONE,
                                          style: textTheme.displayMedium?.copyWith(color: videoOnly != null ? Colors.red : null),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                const SizedBox(height: 18.0),
                                Form(
                                  key: formKey,
                                  child: CustomTagTextField(
                                    controller: videoOutputFilenameController,
                                    hintText: videoOutputFilenameController.text,
                                    labelText: lang.FILE_NAME,
                                    onChanged: (_) => videoOutputFilenameWasUserEdited = true,
                                    validatorMode: AutovalidateMode.always,
                                    validator: (value) {
                                      if (value == null) return lang.PLEASE_ENTER_A_NAME;
                                      final file = FileParts.join(AppDirs.YOUTUBE_DOWNLOADS, groupName, value);
                                      void updateVal(bool exist) => WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                                            filenameExists.value = exist;
                                          });
                                      if (file.existsSync()) {
                                        updateVal(true);
                                        return "${lang.FILE_ALREADY_EXISTS}, ${lang.DOWNLOADING_WILL_OVERRIDE_IT} (${file.fileSizeFormatted() ?? 0})";
                                      } else {
                                        updateVal(false);
                                      }

                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(height: 6.0),
                                YTDownloadFilenameBuilderRow(
                                  controller: videoOutputFilenameController,
                                ),
                                const SizedBox(height: 12.0),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: TextButton(
                                        child: NamidaButtonText(lang.CANCEL),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                    ),
                                    const SizedBox(width: 12.0),
                                    Expanded(
                                      flex: 2,
                                      child: Obx(
                                        (context) {
                                          final sizeSum = (selectedVideoOnlyStream.valueR?.sizeInBytes ?? 0) + (selectedAudioOnlyStream.valueR?.sizeInBytes ?? 0);
                                          final enabled = sizeSum > 0;
                                          final sizeText = enabled ? "(${sizeSum.fileSizeFormatted})" : '';
                                          return IgnorePointer(
                                            ignoring: !enabled,
                                            child: AnimatedOpacity(
                                              duration: const Duration(milliseconds: 200),
                                              opacity: enabled ? 1.0 : 0.6,
                                              child: NamidaInkWell(
                                                borderRadius: 12.0,
                                                padding: const EdgeInsets.all(12.0),
                                                height: 48.0,
                                                bgColor: colorScheme,
                                                decoration: filenameExists.valueR
                                                    ? BoxDecoration(
                                                        border: Border.all(
                                                          width: 3.0,
                                                          color: Colors.red.withAlpha(80),
                                                        ),
                                                      )
                                                    : const BoxDecoration(),
                                                onTap: () async {
                                                  final group = DownloadTaskGroupName(groupName: groupName);
                                                  final itemConfig = YoutubeItemDownloadConfig(
                                                    originalIndex: originalIndex,
                                                    totalLength: totalLength,
                                                    playlistId: playlistId,
                                                    playlistInfo: playlistInfo,
                                                    id: DownloadTaskVideoId(videoId: videoId),
                                                    groupName: group,
                                                    filename: DownloadTaskFilename.create(initialFilename: videoOutputFilenameController.text),
                                                    ffmpegTags: tagsMap,
                                                    fileDate: videoDateTime,
                                                    videoStream: selectedVideoOnlyStream.value,
                                                    audioStream: selectedAudioOnlyStream.value,
                                                    streamInfoItem: streamInfoItem,
                                                    prefferedVideoQualityID: selectedVideoOnlyStream.value?.itag.toString(),
                                                    prefferedAudioQualityID: selectedAudioOnlyStream.value?.itag.toString(),
                                                    fetchMissingAudio: selectedAudioOnlyStream.value != null,
                                                    fetchMissingVideo: selectedVideoOnlyStream.value != null,
                                                    addedAt: DateTime.now(),
                                                  );
                                                  if (onConfirmButtonTap != null) {
                                                    final accept = onConfirmButtonTap(groupName, itemConfig);
                                                    if (accept) context.safePop();
                                                  } else {
                                                    if (!await requestManageStoragePermission()) return;
                                                    requestIgnoreBatteryOptimizations();
                                                    if (context.mounted) context.safePop();
                                                    YoutubeController.inst.downloadYoutubeVideos(
                                                      useCachedVersionsIfAvailable: true,
                                                      autoExtractTitleAndArtist: settings.youtube.autoExtractVideoTagsFromInfo.value,
                                                      keepCachedVersionsIfDownloaded: settings.downloadFilesKeepCachedVersions.value,
                                                      downloadFilesWriteUploadDate: settings.downloadFilesWriteUploadDate.value,
                                                      addAudioToLocalLibrary: settings.downloadAddAudioToLocalLibrary.value,
                                                      groupName: group,
                                                      itemsConfig: [itemConfig],
                                                    );
                                                  }
                                                },
                                                child: Center(
                                                  child: Text(
                                                    '${confirmButtonText == '' ? lang.DOWNLOAD : confirmButtonText} $sizeText',
                                                    style: textTheme.displayMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
    },
  );

  void closeStreams() {
    showAudioWebm.close();
    showVideoWebm.close();
    streamResultRx.close();
    isLoadingStreamsRx.close();
    isLoadingInfoRx.close();
    selectedAudioOnlyStream.close();
    selectedVideoOnlyStream.close();
    videoInfo.close();
    videoOutputFilenameController.dispose();
    videoThumbnail.close();
    filenameExists.close();
    bodyHeightRx.close();
  }

  closeStreams.executeAfterDelay();
}
