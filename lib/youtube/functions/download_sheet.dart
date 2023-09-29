import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/ffmpeg_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/main.dart';
import 'package:namida/packages/three_arched_circle.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/functions/video_download_options.dart';
import 'package:namida/youtube/widgets/yt_shimmer.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';

Future<void> showDownloadVideoBottomSheet({
  BuildContext? ctx,
  required String videoId,
  Color? colorScheme,
}) async {
  colorScheme ??= CurrentColor.inst.color;
  final context = ctx ?? rootContext;

  final showAudioWebm = false.obs;
  final showVideoWebm = false.obs;
  final video = Rxn<YoutubeVideo>();
  final selectedAudioOnlyStream = Rxn<AudioOnlyStream>();
  final selectedVideoOnlyStream = Rxn<VideoOnlyStream>();
  final videoInfo = ValueNotifier<VideoInfo?>(null);
  final videoOutputFilenameController = TextEditingController();
  final videoThumbnail = Rxn<File>();
  DateTime? videoDateTime;

  final formKey = GlobalKey<FormState>();
  final filenameExists = false.obs;

  final tagsMap = <FFMPEGTagField, String?>{};
  void updateTagsMap(Map<FFMPEGTagField, String?> values) {
    for (final e in values.entries) {
      tagsMap[e.key] = e.value;
    }
  }

  void updatefilenameOutput() {
    final videoTitle = videoInfo.value?.name ?? videoId;
    if (selectedAudioOnlyStream.value == null && selectedVideoOnlyStream.value == null) {
      videoOutputFilenameController.text = videoTitle;
    } else {
      final audioOnly = selectedAudioOnlyStream.value != null && selectedVideoOnlyStream.value == null;
      if (audioOnly) {
        final filenameRealAudio = "$videoTitle.${selectedAudioOnlyStream.value?.formatSuffix}";
        videoOutputFilenameController.text = filenameRealAudio;
      } else {
        final filenameRealVideo = "${videoTitle}_${selectedVideoOnlyStream.value?.resolution}.${selectedVideoOnlyStream.value?.formatSuffix}";
        videoOutputFilenameController.text = filenameRealVideo;
      }
    }
  }

  YoutubeController.inst.getAvailableStreams(videoId).then((v) {
    video.value = v;
    videoInfo.value ??= v.videoInfo;

    selectedAudioOnlyStream.value = video.value?.audioOnlyStreams?.firstWhereEff((e) => e.formatSuffix != 'webm') ?? video.value?.audioOnlyStreams?.firstOrNull;

    selectedVideoOnlyStream.value = video.value?.videoOnlyStreams?.firstWhereEff(
          (e) =>
              e.formatSuffix != 'webm' &&
              settings.youtubeVideoQualities.contains(
                e.resolution?.videoLabelToSettingLabel(),
              ),
        ) ??
        video.value?.videoOnlyStreams?.firstWhereEff((e) => e.formatSuffix != 'webm');

    updatefilenameOutput();
    videoDateTime = videoInfo.value?.date;
    final d = videoDateTime;
    updateTagsMap(
      {
        FFMPEGTagField.title: videoInfo.value?.name,
        FFMPEGTagField.artist: videoInfo.value?.uploaderName,
        FFMPEGTagField.comment: YoutubeController.inst.getYoutubeLink(videoId),
        FFMPEGTagField.year: d == null ? null : DateFormat('yyyyMMdd').format(d),
        FFMPEGTagField.synopsis: videoInfo.value?.description == null ? null : HtmlParser.parseHTML(videoInfo.value!.description!).text,
      },
    );
  });

  Widget getQualityButton({
    required final String title,
    final String subtitle = '',
    required final bool cacheExists,
    required final bool selected,
    final double horizontalPadding = 8.0,
    final double verticalPadding = 8.0,
    required void Function() onTap,
  }) {
    final selectedColor = colorScheme!;
    return NamidaInkWell(
      decoration: selected
          ? BoxDecoration(
              border: Border.all(
                color: selectedColor,
              ),
            )
          : const BoxDecoration(),
      animationDurationMS: 100,
      margin: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 4.0),
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      onTap: () {
        onTap();
        updatefilenameOutput();
      },
      borderRadius: 8.0,
      bgColor: selected ? Color.alphaBlend(selectedColor.withAlpha(40), context.theme.cardTheme.color!) : context.theme.cardTheme.color,
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
                style: context.textTheme.displayMedium?.copyWith(
                  fontSize: 12.0.multipliedFontScale,
                ),
              ),
              if (subtitle != '')
                Text(
                  subtitle,
                  style: context.textTheme.displaySmall?.copyWith(
                    fontSize: 12.0.multipliedFontScale,
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
            Text(
              '• $subtitle',
              style: style ?? context.textTheme.displaySmall,
            ),
          ],
          const Spacer(),
          NamidaIconButton(
            tooltip: lang.SHOW_WEBM,
            horizontalPadding: 0.0,
            iconSize: 20.0,
            icon: Broken.video_octagon,
            onPressed: onSussyIconTap,
          ),
          const SizedBox(width: 12.0),
          NamidaIconButton(
            horizontalPadding: 0.0,
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

  Widget getPopupItem<T>({
    required List<T> items,
    required Widget Function(T item) itemBuilder,
  }) {
    return Wrap(
      children: [
        ...items.map((element) => itemBuilder(element)).toList(),
      ],
    );
  }

  await Future.delayed(Duration.zero); // delay bcz sometimes doesnt show
  // ignore: use_build_context_synchronously
  showModalBottomSheet(
    isScrollControlled: true,
    context: context,
    builder: (context) {
      final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
      return SizedBox(
        height: context.height * 0.65 + bottomPadding,
        width: context.width,
        child: Padding(
          padding: const EdgeInsets.all(18.0).add(EdgeInsets.only(bottom: bottomPadding)),
          child: ValueListenableBuilder(
            valueListenable: videoInfo,
            builder: (context, value, child) {
              return videoInfo.value == null
                  ? Center(
                      child: ThreeArchedCircle(
                        color: colorScheme!,
                        size: context.width * 0.4,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Obx(
                            () => Row(
                              children: [
                                YoutubeThumbnail(
                                  borderRadius: 10.0,
                                  videoId: videoId,
                                  width: context.width * 0.2,
                                  height: context.width * 0.2 * 9 / 16,
                                  onImageReady: (imageFile) {
                                    videoThumbnail.value = imageFile;
                                  },
                                ),
                                const SizedBox(width: 12.0),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      NamidaBasicShimmer(
                                        borderRadius: 6.0,
                                        width: context.width,
                                        height: 18.0,
                                        shimmerEnabled: videoInfo.value == null,
                                        child: Text(
                                          videoInfo.value?.name ?? videoId,
                                          style: context.textTheme.displayMedium,
                                        ),
                                      ),
                                      const SizedBox(height: 2.0),
                                      NamidaBasicShimmer(
                                        borderRadius: 4.0,
                                        width: context.width - 24.0,
                                        height: 12.0,
                                        shimmerEnabled: videoInfo.value == null,
                                        child: () {
                                          final dateFormatted = videoInfo.value?.date?.millisecondsSinceEpoch.dateFormattedOriginal;
                                          return Text(
                                            [
                                              videoInfo.value?.duration?.inSeconds.secondsLabel ?? "00:00",
                                              if (dateFormatted != null) dateFormatted,
                                            ].join(' - '),
                                            style: context.textTheme.displaySmall,
                                          );
                                        }(),
                                      ),
                                    ],
                                  ),
                                ),
                                Obx(
                                  () {
                                    final isWEBM = selectedAudioOnlyStream.value?.formatSuffix == 'webm';
                                    return Stack(
                                      alignment: Alignment.bottomRight,
                                      children: [
                                        NamidaIconButton(
                                          horizontalPadding: 0.0,
                                          icon: Broken.edit,
                                          onPressed: () {
                                            // webm doesnt support tag editing
                                            if (isWEBM) {
                                              Get.snackbar(
                                                lang.ERROR,
                                                lang.WEBM_NO_EDIT_TAGS_SUPPORT,
                                                snackPosition: SnackPosition.BOTTOM,
                                                snackStyle: SnackStyle.FLOATING,
                                                animationDuration: const Duration(milliseconds: 300),
                                                duration: const Duration(seconds: 2),
                                                leftBarIndicatorColor: Colors.red,
                                                margin: const EdgeInsets.all(0.0),
                                                borderRadius: 0,
                                              );
                                            }

                                            showVideoDownloadOptionsSheet(
                                              context: context,
                                              videoInfo: videoInfo.value!,
                                              videoTitle: videoInfo.value!.name ?? '',
                                              tagMaps: tagsMap,
                                              supportTagging: !isWEBM,
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
                                                    color: context.theme.scaffoldBackgroundColor,
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
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            shrinkWrap: true,
                            children: [
                              Obx(
                                () {
                                  final e = selectedAudioOnlyStream.value;
                                  final subtitle = e == null ? null : "${e.bitrateText} • ${e.formatSuffix} • ${e.sizeInBytes?.fileSizeFormatted}";
                                  return getTextWidget(
                                    title: lang.AUDIO,
                                    subtitle: subtitle,
                                    icon: Broken.audio_square,
                                    onCloseIconTap: () => selectedAudioOnlyStream.value = null,
                                    onSussyIconTap: () {
                                      showAudioWebm.value = !showAudioWebm.value;
                                      if (showAudioWebm.value == false && selectedAudioOnlyStream.value?.formatSuffix == 'webm') {
                                        selectedAudioOnlyStream.value = video.value?.audioOnlyStreams?.firstOrNull;
                                      }
                                    },
                                  );
                                },
                              ),
                              if (video.value!.audioOnlyStreams != null)
                                Obx(
                                  () => getPopupItem(
                                    items: showAudioWebm.value
                                        ? video.value!.audioOnlyStreams!
                                        : video.value!.audioOnlyStreams!.where((element) => element.formatSuffix != 'webm').toList(),
                                    itemBuilder: (element) {
                                      return Obx(
                                        () {
                                          final cacheFile = element.getCachedFile(videoId);
                                          return getQualityButton(
                                            selected: selectedAudioOnlyStream.value == element,
                                            cacheExists: cacheFile != null,
                                            title: "${element.codec} • ${element.sizeInBytes?.fileSizeFormatted}",
                                            subtitle: "${element.formatSuffix} • ${element.bitrateText}",
                                            onTap: () => selectedAudioOnlyStream.value = element,
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              getDivider(),
                              Obx(
                                () {
                                  final e = selectedVideoOnlyStream.value;
                                  final subtitle = e == null ? null : "${e.resolution} • ${e.sizeInBytes?.fileSizeFormatted}";
                                  return getTextWidget(
                                    title: lang.VIDEO,
                                    subtitle: subtitle,
                                    icon: Broken.video_square,
                                    onCloseIconTap: () => selectedVideoOnlyStream.value = null,
                                    onSussyIconTap: () {
                                      showVideoWebm.value = !showVideoWebm.value;
                                      if (showVideoWebm.value == false && selectedVideoOnlyStream.value?.formatSuffix == 'webm') {
                                        selectedVideoOnlyStream.value = video.value?.videoOnlyStreams?.firstOrNull;
                                      }
                                    },
                                  );
                                },
                              ),
                              if (video.value!.videoOnlyStreams != null)
                                Obx(
                                  () {
                                    return getPopupItem(
                                      items: showVideoWebm.value
                                          ? video.value!.videoOnlyStreams!
                                          : video.value!.videoOnlyStreams!.where((element) => element.formatSuffix != 'webm').toList(),
                                      itemBuilder: (element) {
                                        return Obx(
                                          () {
                                            final cacheFile = element.getCachedFile(videoId);
                                            return getQualityButton(
                                              selected: selectedVideoOnlyStream.value == element,
                                              cacheExists: cacheFile != null,
                                              title: "${element.resolution} • ${element.sizeInBytes?.fileSizeFormatted}",
                                              subtitle: "${element.formatSuffix} • ${element.bitrateText}",
                                              onTap: () => selectedVideoOnlyStream.value = element,
                                            );
                                          },
                                        );
                                      },
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12.0),
                        Obx(() {
                          final videoOnly = selectedVideoOnlyStream.value != null && selectedAudioOnlyStream.value == null ? lang.VIDEO_ONLY : null;
                          final audioOnly = selectedVideoOnlyStream.value == null && selectedAudioOnlyStream.value != null ? lang.AUDIO_ONLY : null;
                          final audioAndVideo = selectedVideoOnlyStream.value != null && selectedAudioOnlyStream.value != null ? "${lang.VIDEO} + ${lang.AUDIO}" : null;

                          return RichText(
                            text: TextSpan(
                              text: "${lang.OUTPUT}: ",
                              style: context.textTheme.displaySmall,
                              children: [
                                TextSpan(
                                  text: videoOnly ?? audioOnly ?? audioAndVideo ?? lang.NONE,
                                  style: context.textTheme.displayMedium?.copyWith(color: videoOnly != null ? Colors.red : null),
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
                            validatorMode: AutovalidateMode.always,
                            validator: (value) {
                              if (value == null) return lang.PLEASE_ENTER_A_NAME;
                              final file = File("${AppDirs.INTERNAL_STORAGE}/$value");
                              void updateVal(bool exist) => WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                                    filenameExists.value = exist;
                                  });
                              if (file.existsSync()) {
                                updateVal(true);
                                return "${lang.FILE_ALREADY_EXISTS}, ${lang.DOWNLOADING_WILL_OVERRIDE_IT} (${file.sizeInBytesSync().fileSizeFormatted})";
                              } else {
                                updateVal(false);
                              }

                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 12.0),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              flex: 1,
                              child: TextButton(
                                child: Text(lang.CANCEL),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                            const SizedBox(width: 12.0),
                            Expanded(
                              flex: 2,
                              child: Obx(
                                () {
                                  final sizeSum = (selectedVideoOnlyStream.value?.sizeInBytes ?? 0) + (selectedAudioOnlyStream.value?.sizeInBytes ?? 0);
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
                                        decoration: filenameExists.value
                                            ? BoxDecoration(
                                                border: Border.all(
                                                  width: 3.0,
                                                  color: Colors.red.withAlpha(80),
                                                ),
                                              )
                                            : const BoxDecoration(),
                                        child: Center(
                                          child: Text(
                                            '${lang.DOWNLOAD} $sizeText',
                                            style: context.textTheme.displayMedium?.copyWith(color: Colors.white.withOpacity(0.9)),
                                          ),
                                        ),
                                        onTap: () async {
                                          if (!await requestManageStoragePermission()) return;
                                          // ignore: use_build_context_synchronously
                                          Navigator.pop(context);
                                          final downloadedFile = await YoutubeController.inst.downloadYoutubeVideoRaw(
                                            id: videoId,
                                            useCachedVersionsIfAvailable: true,
                                            saveDirectory: Directory(AppDirs.INTERNAL_STORAGE),
                                            filename: videoOutputFilenameController.text,
                                            videoStream: selectedVideoOnlyStream.value,
                                            audioStream: selectedAudioOnlyStream.value,
                                            merge: true,
                                            keepCachedVersionsIfDownloaded: settings.downloadFilesKeepCachedVersions.value,
                                            onInitialVideoFileSize: (initialFileSize) {},
                                            onInitialAudioFileSize: (initialFileSize) {},
                                            videoDownloadingStream: (downloadedBytes) {},
                                            audioDownloadingStream: (downloadedBytes) {},
                                            onAudioFileReady: (audioFile) async {
                                              if (videoThumbnail.value != null) {
                                                await NamidaFFMPEG.inst.editAudioThumbnail(audioPath: audioFile.path, thumbnailPath: videoThumbnail.value!.path);
                                              }
                                              await NamidaFFMPEG.inst.editMetadata(
                                                path: audioFile.path,
                                                tagsMap: tagsMap,
                                              );
                                            },
                                            onVideoFileReady: (videoFile) async {
                                              await NamidaFFMPEG.inst.editMetadata(
                                                path: videoFile.path,
                                                tagsMap: tagsMap,
                                              );
                                            },
                                          );
                                          if (settings.downloadFilesWriteUploadDate.value) {
                                            final d = videoDateTime;
                                            if (d != null) {
                                              await downloadedFile?.setLastAccessed(d);
                                              await downloadedFile?.setLastModified(d);
                                            }
                                          }
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        )
                      ],
                    );
            },
          ),
        ),
      );
    },
  );
}
