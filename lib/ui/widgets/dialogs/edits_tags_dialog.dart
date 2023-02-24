import 'dart:io';

import 'package:flutter/material.dart';
import 'package:checkmark/checkmark.dart';
import 'package:file_picker/file_picker.dart';
import 'package:on_audio_edit/on_audio_edit.dart';
import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/main.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

Future<void> showEditTrackTagsDialog(Track track) async {
  await requestManageStoragePermission();

  final audioedit = OnAudioEdit();
  final titleController = TextEditingController();
  final albumController = TextEditingController();
  final artistController = TextEditingController();
  final composerController = TextEditingController();
  final genreController = TextEditingController();
  final trackNumberController = TextEditingController();
  // final discNumberController = TextEditingController();
  final commentController = TextEditingController();
  final yearController = TextEditingController();

  final info = await audioedit.readAudio(track.path);

  titleController.text = info.title ?? '';
  albumController.text = info.album ?? '';
  artistController.text = info.artist ?? '';
  composerController.text = info.composer ?? '';
  genreController.text = info.genre ?? '';
  trackNumberController.text = info.track != null ? info.track.toString() : '';
  // discNumberController.text = info.discNo != null ? info.discNo.toString() : '';
  commentController.text = info.comment ?? '';
  yearController.text = info.year != null ? info.year.toString() : '';

  RxBool trimWhiteSpaces = true.obs;
  // Rx<Uint8List> currentImage = Uint8List.fromList([]).obs;
  RxString currentImagePath = ''.obs;
  Get.dialog(
    CustomBlurryDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      normalTitleStyle: true,
      scrollable: false,
      icon: Broken.edit,
      title: Language.inst.EDIT_TAGS,
      actions: [
        Material(
          color: Get.theme.cardColor,
          borderRadius: BorderRadius.circular(12.0.multipliedRadius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => trimWhiteSpaces.value = !trimWhiteSpaces.value,
            hoverColor: Get.theme.colorScheme.onSecondary,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Obx(
                    () => SizedBox(
                      height: 18,
                      width: 18,
                      child: CheckMark(
                        strokeWidth: 2,
                        activeColor: Get.theme.listTileTheme.iconColor!,
                        inactiveColor: Get.theme.listTileTheme.iconColor!,
                        duration: const Duration(milliseconds: 400),
                        active: trimWhiteSpaces.value,
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 8.0,
                  ),
                  Text(
                    Language.inst.REMOVE_WHITESPACES,
                    style: Get.textTheme.displaySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            final copiedFile = await File(track.path).copy("${SettingsController.inst.defaultBackupLocation.value}/${track.displayName}");

            String ftitle = titleController.text;
            String falbum = albumController.text;
            String fartist = artistController.text;
            String fcomposer = composerController.text;
            String fgenre = genreController.text;
            String ftrnum = trackNumberController.text;
            String fcomment = commentController.text;
            String fyear = yearController.text;

            if (trimWhiteSpaces.value) {
              ftitle = ftitle.trim();
              falbum = falbum.trim();
              fartist = fartist.trim();
              fcomposer = fcomposer.trim();
              fgenre = fgenre.trim();
              ftrnum = ftrnum.trim();
              fcomment = fcomment.trim();
              ftitle = ftitle.trim();
              fyear = fyear.trim();
            }
            final didUpdate = await audioedit.editAudio(
              copiedFile.path,
              {
                TagType.TITLE: ftitle,
                TagType.ALBUM: falbum,
                TagType.ARTIST: fartist,
                TagType.COMPOSER: fcomposer,
                TagType.GENRE: fgenre,
                TagType.TRACK: ftrnum,
                TagType.COMMENT: fcomment,
                TagType.YEAR: ftitle,
              },
              searchInsideFolders: true,
            );
            debugPrint(currentImagePath.value.toString());

            // if user actually picked a pic
            if (currentImagePath.value != '') {
              final didUpdateImg = await audioedit.editArtwork(
                copiedFile.path,
                // imagePath: currentImagePath.value,
                searchInsideFolders: true,
                openFilePicker: true,
              );
            }

            // await File(track.path).delete();
            await copiedFile.copy(track.path);
            await copiedFile.delete();
            debugPrint(didUpdate.toString());
            Indexer.inst.updateTracks([track], updateArtwork: currentImagePath.value != '');
            Get.close(1);
          },
          icon: const Icon(Broken.pen_add),
          label: Text(Language.inst.SAVE),
        )
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Obx(
                          () => ArtworkWidget(
                            track: track,
                            thumnailSize: Get.width / 3,
                            bytes: currentImagePath.value != '' ? null : info.firstArtwork,
                            path: currentImagePath.value != '' ? currentImagePath.value : null,
                            onTopWidget: Positioned(
                              bottom: 0,
                              right: 0,
                              child: NamidaBlurryContainer(
                                onTap: () async {
                                  String path = '';
                                  final pickedFile = await FilePicker.platform.pickFiles(type: FileType.image);
                                  path = pickedFile?.files.first.path ?? '';
                                  if (pickedFile != null && path != '') {
                                    final copiedImage = await File(path).copy("${SettingsController.inst.defaultBackupLocation.value}/${path.split('/').last}");
                                    currentImagePath.value = copiedImage.path;
                                  }
                                },
                                borderRadius: BorderRadius.only(topLeft: Radius.circular(12.0.multipliedRadius)),
                                child: const Icon(Broken.edit_2),
                              ),
                            ),
                            // onTopWidget: IconButton(onPressed: () {}, icon: Icon(Broken.edit_2)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      width: 12.0,
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CustomTagTextField(
                            controller: trackNumberController,
                            hintText: Language.inst.TRACK_NUMBER,
                            icon: Broken.repeate_one,
                          ),
                          const SizedBox(
                            height: 8.0,
                          ),
                          CustomTagTextField(
                            controller: yearController,
                            hintText: Language.inst.YEAR,
                            icon: Broken.calendar,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 12.0,
                ),
                CustomTagTextField(
                  controller: titleController,
                  hintText: Language.inst.TITLE,
                  icon: Broken.music,
                ),
                const SizedBox(
                  height: 8.0,
                ),
                CustomTagTextField(
                  controller: artistController,
                  hintText: Language.inst.ARTIST,
                  icon: Broken.microphone,
                ),
                const SizedBox(
                  height: 12.0,
                ),
                CustomTagTextField(
                  controller: albumController,
                  hintText: Language.inst.ALBUM,
                  icon: Broken.music_dashboard,
                ),
                const SizedBox(
                  height: 12.0,
                ),
                CustomTagTextField(
                  controller: genreController,
                  hintText: Language.inst.GENRE,
                  icon: Broken.smileys,
                ),
                const SizedBox(
                  height: 12.0,
                ),
                CustomTagTextField(
                  controller: commentController,
                  hintText: Language.inst.COMMENT,
                  icon: Broken.text_block,
                  maxLines: 4,
                ),
                const SizedBox(
                  height: 12.0,
                ),
              ],
            ),
          ),
          const SizedBox(
            height: 12.0,
          ),
          Text(
            track.path,
            style: Get.textTheme.displaySmall,
          ),
          const SizedBox(
            height: 4.0,
          ),
          Text(
            [
              track.duration.milliseconds.label,
              track.size.fileSizeFormatted,
              "${track.bitrate} kps",
              "${track.sampleRate} hz",
            ].join(' • '),
            style: Get.textTheme.displaySmall,
          ),
        ],
      ),
    ),
  );
}

class CustomTagTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData? icon;
  final int hintMaxLines;
  final int? maxLines;
  const CustomTagTextField({super.key, required this.controller, required this.hintText, this.icon, this.hintMaxLines = 3, this.maxLines});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: null,
      child: TextField(
        controller: controller,
        textAlign: TextAlign.left,
        maxLines: maxLines,
        style: context.textTheme.displaySmall?.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintMaxLines: hintMaxLines,
          contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          errorMaxLines: 3,
          suffixIcon: Icon(icon, size: 18.0),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14.0.multipliedRadius),
            borderSide: BorderSide(color: Get.theme.colorScheme.onBackground.withAlpha(100), width: 2.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18.0.multipliedRadius),
            borderSide: BorderSide(color: Get.theme.colorScheme.onBackground.withAlpha(100), width: 1.0),
          ),
          hintText: hintText,
          hintStyle: context.textTheme.displaySmall?.copyWith(fontSize: 14.5),
        ),
      ),
    );
  }
}

Future<void> editTrackMetadata(Track track, {Map<TagType, dynamic>? tags, String insertComment = ''}) async {
  final audioedit = OnAudioEdit();
  final info = await audioedit.readAudio(track.path);
  final copiedFile = await File(track.path).copy("${SettingsController.inst.defaultBackupLocation.value}/${track.displayName}");
  if (insertComment != '') {
    await audioedit.editAudio(
      copiedFile.path,
      {TagType.COMMENT: "$insertComment ${info.comment}"},
      searchInsideFolders: true,
    );
  }
  if (tags != null) {
    await audioedit.editAudio(
      copiedFile.path,
      tags,
      searchInsideFolders: true,
    );
  }

  await copiedFile.copy(track.path);
  await copiedFile.delete();
  Indexer.inst.updateTracks([track]);
}
