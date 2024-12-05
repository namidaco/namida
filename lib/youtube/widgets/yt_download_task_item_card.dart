import 'dart:io';

import 'package:flutter/material.dart';

import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/class/file_parts.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/youtube/class/download_task_base.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/class/youtube_item_download_config.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/youtube_ongoing_finished_downloads.dart';
import 'package:namida/youtube/functions/download_sheet.dart';
import 'package:namida/youtube/widgets/video_info_dialog.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:namida/youtube/yt_utils.dart';

class YTDownloadTaskItemCard extends StatelessWidget {
  final List<YoutubeItemDownloadConfig> videos;
  final int index;
  final DownloadTaskGroupName groupName;

  const YTDownloadTaskItemCard({
    super.key,
    required this.videos,
    required this.index,
    required this.groupName,
  });

  Widget _getChip({
    required BuildContext context,
    required IconData icon,
    Color? iconColor,
    required String title,
    String betweenBrackets = '',
    bool displayTitle = false,
    void Function()? onTap,
    Widget? Function(double size)? iconWidget,
  }) {
    final textWidget = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: title, style: context.textTheme.displayMedium?.copyWith(fontSize: 13.0)),
          if (betweenBrackets != '')
            TextSpan(
              text: " ($betweenBrackets)",
              style: namida.textTheme.displaySmall?.copyWith(fontSize: 11.0),
            ),
        ],
      ),
    );
    final iconSize = (displayTitle ? 16.0 : 17.0);
    return NamidaInkWell(
      borderRadius: 6.0,
      padding: const EdgeInsets.only(left: 6.0, right: 6.0, top: 6.0, bottom: 6.0),
      onTap: onTap,
      child: Tooltip(
        message: title,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget?.call(iconSize) ?? Icon(icon, size: iconSize, color: iconColor),
            if (displayTitle) ...[
              const SizedBox(width: 4.0),
              textWidget,
            ],
          ],
        ),
      ),
    );
  }

  void _onPauseDownloadTap(List<YoutubeItemDownloadConfig> itemsConfig) {
    YoutubeController.inst.pauseDownloadTask(
      itemsConfig: itemsConfig,
      groupName: groupName,
    );
  }

  void _onResumeDownloadTap(List<YoutubeItemDownloadConfig> itemsConfig, BuildContext context) {
    YoutubeController.inst.downloadYoutubeVideos(
      useCachedVersionsIfAvailable: true,
      addAudioToLocalLibrary: settings.downloadAddAudioToLocalLibrary.value,
      autoExtractTitleAndArtist: settings.youtube.autoExtractVideoTagsFromInfo.value,
      keepCachedVersionsIfDownloaded: settings.downloadFilesKeepCachedVersions.value,
      downloadFilesWriteUploadDate: settings.downloadFilesWriteUploadDate.value,
      itemsConfig: itemsConfig,
      groupName: groupName,
      onFileDownloaded: (downloadedFile) async {
        if (downloadedFile != null) {
          build(context);
        }
      },
      onOldFileDeleted: (deletedFile) async {
        build(context);
      },
    );
  }

  void _onCancelDeleteDownloadTap(List<YoutubeItemDownloadConfig> itemsConfig, {bool keepInList = false, required bool delete}) {
    YoutubeController.inst.cancelDownloadTask(itemsConfig: itemsConfig, groupName: groupName, keepInList: keepInList, delete: delete);
  }

  void _showInfoDialog(
    final BuildContext context,
    final YoutubeItemDownloadConfig item,
    final StreamInfoItem? info,
    final DownloadTaskGroupName groupName,
  ) {
    NamidaNavigator.inst.navigateDialog(
      dialog: VideoInfoDialog(
        videoId: item.id.videoId,
        info: info,
        saveLocation: FileParts.joinPath(AppDirs.YOUTUBE_DOWNLOADS, groupName.groupName, item.filename.filename),
        tags: item.ffmpegTags,
        extraColumnChildren: _getItemLocalInfoWidgets(context: context),
      ),
    );
  }

  List<Widget> _getItemLocalInfoWidgets({
    required BuildContext context,
  }) {
    final item = videos[index];
    final itemDirectoryPath = FileParts.joinPath(AppDirs.YOUTUBE_DOWNLOADS, groupName.groupName);
    final file = FileParts.join(itemDirectoryPath, item.filename.filename);

    final videoStream = item.videoStream;
    final audioStream = item.audioStream;

    Widget getRow({required IconData icon, required List<String> texts}) {
      return Row(
        children: [
          Icon(icon, size: 18.0),
          const SizedBox(width: 6.0),
          Expanded(
            child: Text(
              texts.joinText(),
              style: context.textTheme.displaySmall?.copyWith(fontSize: 12.0),
            ),
          ),
        ],
      );
    }

    return [
      getRow(icon: Broken.location, texts: [itemDirectoryPath]),
      if (file.existsSync()) ...[
        const SizedBox(height: 6.0),
        getRow(
          icon: Broken.document_code,
          texts: [
            file.fileSizeFormatted() ?? '',
            (item.fileDate ?? file.statSync().creationDate).millisecondsSinceEpoch.dateAndClockFormattedOriginal,
          ],
        ),
      ],
      if (videoStream != null) ...[
        const SizedBox(height: 6.0),
        getRow(
          icon: Broken.video_square,
          texts: [
            videoStream.sizeInBytes.fileSizeFormatted,
            videoStream.bitrateText(),
            videoStream.qualityLabel,
          ],
        ),
      ],
      if (audioStream != null) ...[
        const SizedBox(height: 6.0),
        getRow(
          icon: Broken.audio_square,
          texts: [
            audioStream.sizeInBytes.fileSizeFormatted,
            audioStream.bitrateText(),
          ],
        ),
      ],
    ];
  }

  Future<({bool confirmed, bool delete})> _confirmOperation({
    required BuildContext context,
    required String operationTitle,
    String confirmMessage = '',
    bool deleteButton = false,
  }) async {
    final item = videos[index];
    bool confirmed = false;
    bool delete = false;
    await NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        title: lang.WARNING,
        normalTitleStyle: true,
        isWarning: true,
        actions: [
          if (deleteButton) ...[
            NamidaButton(
              text: lang.DELETE.toUpperCase(),
              style: ButtonStyle(
                foregroundColor: WidgetStatePropertyAll(Colors.red),
              ),
              onPressed: () {
                confirmed = true;
                delete = true;
                NamidaNavigator.inst.closeDialog();
              },
            ),
            const SizedBox(width: 4.0),
          ],
          const CancelButton(),
          const SizedBox(width: 4.0),
          NamidaButton(
            text: (confirmMessage != '' ? confirmMessage : operationTitle).toUpperCase(),
            onPressed: () {
              confirmed = true;
              NamidaNavigator.inst.closeDialog();
            },
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12.0),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: "$operationTitle: ", style: context.textTheme.displayLarge),
                    TextSpan(
                      text: item.filename.filename,
                      style: context.textTheme.displayMedium,
                    ),
                    TextSpan(text: " ?", style: context.textTheme.displayLarge),
                  ],
                ),
              ),
              const SizedBox(height: 24.0),
              ..._getItemLocalInfoWidgets(context: context),
            ],
          ),
        ),
      ),
    );
    return (confirmed: confirmed, delete: delete);
  }

  void _onEditIconTap({required YoutubeItemDownloadConfig config, required BuildContext context}) async {
    await showDownloadVideoBottomSheet(
      originalIndex: config.originalIndex,
      totalLength: config.totalLength,
      streamInfoItem: config.streamInfoItem,
      playlistId: config.playlistId,
      initialGroupName: config.groupName.groupName,
      showSpecificFileOptionsInEditTagDialog: false,
      videoId: config.id.videoId,
      initialItemConfig: config,
      confirmButtonText: lang.RESTART,
      onConfirmButtonTap: (groupName, newConfig) {
        _onCancelDeleteDownloadTap([config], keepInList: true, delete: true);
        _onResumeDownloadTap([newConfig], context);
        YTOnGoingFinishedDownloads.inst.refreshList();
        return true;
      },
    );
  }

  Future<void> _onRenameIconTap({
    required BuildContext context,
    required YoutubeItemDownloadConfig config,
    required DownloadTaskGroupName groupName,
  }) async {
    await showNamidaBottomSheetWithTextField(
      context: context,
      title: lang.RENAME,
      textfieldConfig: BottomSheetTextFieldConfig(
        initalControllerText: config.filename.filename,
        hintText: config.filename.filename,
        labelText: lang.FILE_NAME,
        validator: (value) {
          if (value == null || value.isEmpty) return lang.EMPTY_VALUE;

          if (value.startsWith('.')) return "${lang.FILENAME_SHOULDNT_START_WITH} .";

          final filenameClean = YoutubeController.inst.cleanupFilename(value);
          if (value != filenameClean) {
            const baddiesAll = YoutubeController.cleanupFilenameRegex; // should remove \ but whatever
            final baddies = baddiesAll.split('').where((element) => value.contains(element)).join();
            return "${lang.NAME_CONTAINS_BAD_CHARACTER} $baddies";
          }

          return null;
        },
      ),
      buttonText: lang.SAVE,
      onButtonTap: (text) async {
        final wasDownloading = YoutubeController.inst.isDownloading[config.id]?[config.filename] ?? false;
        if (wasDownloading) _onPauseDownloadTap([config]);
        await YoutubeController.inst.renameConfigFilename(
          config: config,
          videoID: config.id,
          newFilename: text,
          groupName: groupName,
          renameCacheFiles: true,
        );
        // ignore: use_build_context_synchronously
        if (wasDownloading) _onResumeDownloadTap([config], context);
        return true;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final directory = Directory(FileParts.joinPath(AppDirs.YOUTUBE_DOWNLOADS, groupName.groupName));
    final item = videos[index];
    final downloadedFile = FileParts.join(directory.path, item.filename.filename);

    const thumbHeight = 24.0 * 2.6;
    const thumbWidth = thumbHeight * 16 / 9;

    final videoIdWrapper = item.id;
    final videoId = videoIdWrapper.videoId;

    final itemIcon = item.videoStream != null
        ? Broken.video
        : item.audioStream != null
            ? Broken.musicnote
            : null;
    final infoFinal = videos[index].streamInfoItem ?? YoutubeInfoController.utils.getStreamInfoSync(videoId);
    final duration = (infoFinal?.durSeconds ?? YoutubeInfoController.utils.getVideoDurationSeconds(videoId))?.secondsLabel;
    return NamidaPopupWrapper(
      openOnTap: true,
      openOnLongPress: true,
      childrenDefault: () => YTUtils.getVideoCardMenuItems(
        downloadIndex: item.originalIndex,
        totalLength: item.totalLength,
        playlistId: item.playlistId,
        streamInfoItem: infoFinal,
        videoId: videoId,
        channelID: infoFinal?.channelId ?? infoFinal?.channel.id,
        playlistID: null,
        idsNamesLookup: {videoId: infoFinal?.title},
        playlistName: '',
        videoYTID: null,
        videosToPlayAll: videos.map((e) => YoutubeID(id: e.id.videoId, playlistID: null)),
      ),
      child: NamidaInkWell(
        borderRadius: 10.0,
        onTap: null,
        margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        bgColor: context.theme.cardColor,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.0.multipliedRadius),
        ),
        child: Row(
          children: [
            const SizedBox(width: 4.0),
            YoutubeThumbnail(
              type: ThumbnailType.video,
              key: Key(videoId),
              borderRadius: 8.0,
              isImportantInCache: true,
              width: thumbWidth,
              height: thumbHeight,
              videoId: videoId,
              customUrl: infoFinal?.liveThumbs.pick()?.url,
              smallBoxText: duration,
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: Obx((context) {
                final filename = item.filenameR;
                final isDownloading = YoutubeController.inst.isDownloading[videoIdWrapper]?[filename] ?? false;
                final isFetchingData = YoutubeController.inst.isFetchingData[videoIdWrapper]?[filename] ?? false;
                final audioP = YoutubeController.inst.downloadsAudioProgressMap[videoIdWrapper]?[filename];
                final audioPerc = audioP == null ? null : audioP.progress / audioP.totalProgress;
                final videoP = YoutubeController.inst.downloadsVideoProgressMap[videoIdWrapper]?[filename];
                final videoPerc = videoP == null ? null : videoP.progress / videoP.totalProgress;
                final canDisplayPercentage = audioPerc != null || videoPerc != null;

                final speedB = YoutubeController.inst.currentSpeedsInByte[videoIdWrapper]?[filename];
                final cp = videoP?.progress ?? audioP?.progress ?? 0;
                final ctp = videoP?.totalProgress ?? audioP?.totalProgress ?? 0;
                final speedText = speedB == null ? '' : ' (${speedB.fileSizeFormatted}/s)';
                final downloadInfoText = "${cp.fileSizeFormatted}/${ctp == 0 ? '?' : ctp.fileSizeFormatted}$speedText";

                final fileExists = YoutubeController.inst.downloadedFilesMap[groupName]?[filename] != null;

                double finalPercentage = 0.0;
                if (fileExists) {
                  finalPercentage = 1.0;
                } else {
                  if (audioPerc != null && !audioPerc.isNaN) {
                    finalPercentage = audioPerc;
                  } else if (videoPerc != null && !videoPerc.isNaN) {
                    finalPercentage = videoPerc;
                  }
                }
                final percentageText = finalPercentage.isInfinite ? '' : "${(finalPercentage * 100).toStringAsFixed(0)}%";
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6.0),
                    Text(
                      item.filename.filename,
                      style: context.textTheme.displaySmall,
                    ),
                    const SizedBox(height: 6.0),
                    Row(
                      children: [
                        if (canDisplayPercentage || isFetchingData || isDownloading) ...[
                          canDisplayPercentage
                              ? Text(
                                  audioPerc != null
                                      ? lang.AUDIO
                                      : videoPerc != null
                                          ? lang.VIDEO
                                          : '',
                                  style: context.textTheme.displaySmall,
                                )
                              : const LoadingIndicator(),
                          const SizedBox(width: 6.0),
                        ],
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Stack(
                                children: [
                                  if (finalPercentage.isFinite && finalPercentage > 0)
                                    Container(
                                      alignment: Alignment.centerLeft,
                                      height: 2.0,
                                      decoration: BoxDecoration(
                                        color: CurrentColor.inst.color.withOpacity(0.6),
                                        borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                                      ),
                                      width: finalPercentage * constraints.maxWidth,
                                    ),
                                  Container(
                                    alignment: Alignment.centerLeft,
                                    height: 2.0,
                                    decoration: BoxDecoration(
                                      color: CurrentColor.inst.color.withOpacity(0.25),
                                      borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                                    ),
                                    width: 1.0 * constraints.maxWidth,
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    if (canDisplayPercentage) ...[
                      const SizedBox(height: 4.0),
                      Text(
                        [percentageText, downloadInfoText].joinText(),
                        style: context.textTheme.displaySmall?.copyWith(fontSize: 11.0),
                      ),
                    ],
                    const SizedBox(height: 4.0),
                    // -- ItemActionsRow
                    Row(
                      children: [
                        Expanded(
                          child: ColoredBox(
                            color: Colors.transparent,
                            child: Wrap(
                              runAlignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Obx(
                                  (context) {
                                    final isDownloading = YoutubeController.inst.isDownloading[videoId]?[item.filename] ?? false;
                                    final isFetching = YoutubeController.inst.isFetchingData[videoId]?[item.filename] ?? false;
                                    final willBeDownloaded = YoutubeController.inst.youtubeDownloadTasksInQueueMap[groupName]?[item.filename] == true;
                                    final fileExists = YoutubeController.inst.downloadedFilesMap[groupName]?[item.filename] != null;

                                    return fileExists
                                        ? _getChip(
                                            context: context,
                                            title: lang.RESTART,
                                            icon: Broken.refresh,
                                            onTap: () async {
                                              final confirmation = await _confirmOperation(
                                                context: context,
                                                operationTitle: lang.RESTART,
                                              );
                                              if (confirmation.confirmed) {
                                                _onCancelDeleteDownloadTap([item], keepInList: true, delete: true);
                                                // ignore: use_build_context_synchronously
                                                _onResumeDownloadTap([item], context);
                                              }
                                            })
                                        : willBeDownloaded || isDownloading || isFetching
                                            ? _getChip(
                                                context: context,
                                                title: lang.PAUSE,
                                                icon: Broken.pause,
                                                iconColor: context.defaultIconColor(),
                                                iconWidget: isDownloading
                                                    ? null
                                                    : (size) => StackedIcon(
                                                          baseIcon: Broken.pause,
                                                          secondaryIcon: Broken.timer,
                                                          iconSize: size,
                                                          secondaryIconSize: 10.0,
                                                        ),
                                                onTap: () => _onPauseDownloadTap([item]),
                                              )
                                            : _getChip(
                                                context: context,
                                                title: lang.RESUME,
                                                icon: Broken.play,
                                                onTap: () => _onResumeDownloadTap([item], context),
                                              );
                                  },
                                ),
                                fileExists
                                    ? _getChip(
                                        context: context,
                                        title: lang.DELETE,
                                        icon: Broken.trash,
                                        betweenBrackets: downloadedFile.fileSizeFormatted() ?? '',
                                        onTap: () async {
                                          final confirmation = await _confirmOperation(
                                            context: context,
                                            operationTitle: lang.REMOVE,
                                            deleteButton: true,
                                          );
                                          if (confirmation.confirmed) _onCancelDeleteDownloadTap([item], delete: confirmation.delete);
                                        },
                                      )
                                    : _getChip(
                                        context: context,
                                        title: lang.CANCEL,
                                        icon: Broken.close_circle,
                                        onTap: () async {
                                          final confirmation = await _confirmOperation(
                                            context: context,
                                            operationTitle: lang.CANCEL,
                                            confirmMessage: lang.REMOVE,
                                          );
                                          if (confirmation.confirmed) {
                                            _onCancelDeleteDownloadTap(
                                              [item],
                                              delete: true, // even tho we want to cancel, we delete to clean up unfinished downloads.
                                            );
                                          }
                                        },
                                      ),
                                _getChip(
                                  context: context,
                                  title: lang.RENAME,
                                  icon: Broken.text,
                                  onTap: () => _onRenameIconTap(
                                    context: context,
                                    config: item,
                                    groupName: groupName,
                                  ),
                                ),
                                _getChip(
                                  context: context,
                                  title: lang.EDIT,
                                  icon: Broken.edit_2,
                                  onTap: () => _onEditIconTap(config: item, context: context),
                                ),
                                _getChip(
                                  context: context,
                                  title: lang.INFO,
                                  icon: Broken.info_circle,
                                  onTap: () => _showInfoDialog(context, item, infoFinal, groupName),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              [
                                item.videoStream?.qualityLabel,
                                downloadedFile.fileSizeFormatted(),
                              ].joinText(),
                              style: context.textTheme.displaySmall?.copyWith(fontSize: 11.0),
                            ),
                            const SizedBox(width: 4.0),
                            if (itemIcon != null)
                              Icon(
                                itemIcon,
                                size: 16.0,
                                color: context.defaultIconColor(),
                              ),
                            const SizedBox(width: 4.0),
                            fileExists
                                ? Icon(
                                    Broken.tick_circle,
                                    size: 16.0,
                                    color: context.defaultIconColor(),
                                  )
                                : Icon(
                                    Broken.import,
                                    size: 16.0,
                                    color: context.defaultIconColor(),
                                  ),
                          ],
                        )
                      ],
                    ),
                  ],
                );
              }),
            ),
            const SizedBox(width: 8.0),
          ],
        ),
      ),
    );
  }
}
