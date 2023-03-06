import 'dart:io';

import 'package:flutter/material.dart';
import 'package:checkmark/checkmark.dart';
import 'package:file_picker/file_picker.dart';
import 'package:namida/core/constants.dart';
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
import 'package:namida/ui/widgets/library/multi_artwork_container.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';

Future<void> showEditTrackTagsDialog(Track track) async {
  if (!await requestManageStoragePermission()) {
    return;
  }

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
            // final copiedFile = kSdkVersion < 30 ? File(track.path) : await File(track.path).copy("${SettingsController.inst.defaultBackupLocation.value}/${track.displayName}");

            String ftitle = titleController.text;
            String falbum = albumController.text;
            String fartist = artistController.text;
            String fcomposer = composerController.text;
            String fgenre = genreController.text;
            String _ftrnum = trackNumberController.text;
            String fcomment = commentController.text;
            String _fyear = yearController.text;

            if (trimWhiteSpaces.value) {
              ftitle = ftitle.trim();
              falbum = falbum.trim();
              fartist = fartist.trim();
              fcomposer = fcomposer.trim();
              fgenre = fgenre.trim();
              _ftrnum = _ftrnum.trim();
              fcomment = fcomment.trim();
              _fyear = _fyear.trim();
            }

            /// separately apply int based fields only in case they are not empty.
            /// this prevent crash resulted from assigning empty string to int.
            int? ftrnumInt;

            ftrnumInt = _ftrnum.isNotEmpty ? int.tryParse(_ftrnum) : null;
            // user changed from number to empty
            if (_ftrnum.isEmpty && _ftrnum != (info.track != null ? info.track.toString() : '')) {
              ftrnumInt = 0;
            }

            int? fyearInt;
            fyearInt = _fyear.isNotEmpty ? int.tryParse(_fyear) : null;
            if (_fyear.isEmpty && _fyear != (info.year != null ? info.year.toString() : '')) {
              fyearInt = 0;
            }

            final didUpdate = await editTrackMetadata(
              track,
              tags: {
                TagType.TITLE: ftitle,
                TagType.ALBUM: falbum,
                TagType.ARTIST: fartist,
                TagType.COMPOSER: fcomposer,
                TagType.GENRE: fgenre,
                if (ftrnumInt != null) TagType.TRACK: ftrnumInt,
                TagType.COMMENT: fcomment,
                if (fyearInt != null) TagType.YEAR: fyearInt,
              },
              updateArtwork: currentImagePath.value != '',
            );
            debugPrint(didUpdate.toString());

            if (!didUpdate) {
              Get.snackbar(Language.inst.METADATA_EDIT_FAILED, Language.inst.METADATA_EDIT_FAILED_SUBTITLE);
            }

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
                            maxLength: 8,
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
          const SizedBox(height: 4.0),
          InkWell(
            onTap: () {
              final strings = track.path.getFilenameWOExt.replaceAll('_', ' ').split(' - ');
              if (strings.length == 3) {
                artistController.text = strings[0];
                titleController.text = strings[1];
                albumController.text = strings[2];
              } else {
                artistController.text = strings.first;
                titleController.text = strings.last;
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Broken.magicpen, size: 14.0),
                const SizedBox(width: 4.0),
                Text(
                  Language.inst.AUTO_EXTRACT_TAGS_FROM_FILENAME,
                  style: Get.textTheme.displaySmall?.copyWith(
                    decoration: TextDecoration.underline,
                    decorationStyle: TextDecorationStyle.dashed,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> editMultipleTracksTags(List<Track> tracksPre) async {
  if (!await requestManageStoragePermission()) {
    return;
  }
  RxList<Track> tracks = <Track>[].obs;
  tracks.assignAll(tracksPre);

  final toBeEditedTracksColumn = Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 12.0),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Text(
          Language.inst.MULTIPLE_TRACKS_TAGS_EDIT_NOTE,
          style: Get.textTheme.displayMedium,
        ),
      ),
      const SizedBox(height: 12.0),
      ...tracks.asMap().entries.map((e) {
        return Row(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Obx(
                    () => TrackTile(
                      track: e.value,
                      queue: [e.value],
                      onTap: () => tracks.addIf(() => !tracks.contains(e.value), e.value),
                      bgColor: tracks.contains(e.value) ? null : Colors.black.withAlpha(0),
                      trailingWidget: IconButton(
                        icon: const Icon(Broken.close_circle),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          tracks.remove(e.value);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    ],
  );
  // final info = await audioedit.readAudio(tracks.map((e) => e.path).toList());

  final albumController = TextEditingController();
  final artistController = TextEditingController();
  final composerController = TextEditingController();
  final genreController = TextEditingController();
  final commentController = TextEditingController();
  final yearController = TextEditingController();

  // albumController.text = info.album ?? '';
  // artistController.text = info.artist ?? '';
  // composerController.text = info.composer ?? '';
  // genreController.text = info.genre ?? '';
  // commentController.text = info.comment ?? '';
  // yearController.text = info.year != null ? info.year.toString() : '';

  RxBool trimWhiteSpaces = true.obs;
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
            await Get.dialog(
              CustomBlurryDialog(
                insetPadding: const EdgeInsets.all(42.0),
                contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
                isWarning: true,
                normalTitleStyle: true,
                actions: [
                  ElevatedButton(
                    onPressed: () => Get.close(2),
                    child: Text(Language.inst.CANCEL),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      String falbum = albumController.text;
                      String fartist = artistController.text;
                      String fcomposer = composerController.text;
                      String fgenre = genreController.text;
                      String fcomment = commentController.text;
                      String _fyear = yearController.text;

                      if (trimWhiteSpaces.value) {
                        falbum = falbum.trim();
                        fartist = fartist.trim();
                        fcomposer = fcomposer.trim();
                        fgenre = fgenre.trim();
                        fcomment = fcomment.trim();
                        _fyear = _fyear.trim();
                      }

                      bool didUpdate = false;
                      for (final tr in tracks) {
                        int? fyearInt;
                        fyearInt = _fyear.isNotEmpty ? int.tryParse(_fyear) : null;
                        if (_fyear.isEmpty && _fyear != tr.year.toString()) {
                          fyearInt = 0;
                        }
                        didUpdate = await editTrackMetadata(
                          tr,
                          tags: {
                            if (falbum.isNotEmpty) TagType.ALBUM: falbum,
                            if (fartist.isNotEmpty) TagType.ARTIST: fartist,
                            if (fcomposer.isNotEmpty) TagType.COMPOSER: fcomposer,
                            if (fgenre.isNotEmpty) TagType.GENRE: fgenre,
                            if (fcomment.isNotEmpty) TagType.COMMENT: fcomment,
                            if (fyearInt != null) TagType.YEAR: fyearInt,
                          },
                          updateTracks: false,
                        );
                      }

                      if (!didUpdate) {
                        Get.snackbar(Language.inst.METADATA_EDIT_FAILED, Language.inst.METADATA_EDIT_FAILED_SUBTITLE);
                      } else {
                        // if user actually picked a pic
                        // if (currentImagePath.value != '') {
                        //   final didUpdateImg = await audioedit.editArtwork(
                        //     copiedFile.path,
                        //     // imagePath: currentImagePath.value,
                        //     searchInsideFolders: true,
                        //     openFilePicker: true,
                        //   );
                        // }
                      }
                      Indexer.inst.updateTracks(tracks, updateArtwork: false);

                      Get.close(2);
                    },
                    child: Text(Language.inst.CONFIRM),
                  ),
                ],
                child: toBeEditedTracksColumn,
              ),
            );
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
                          () => MultiArtworkContainer(
                            heroTag: 'edittags_artwork',
                            size: Get.width / 3,
                            tracks: tracks,
                            onTopWidget: tracks.length > 3
                                ? Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: NamidaBlurryContainer(
                                      width: Get.width / 6.2,
                                      height: Get.width / 6.2,
                                      borderRadius: BorderRadius.zero,
                                      child: Center(
                                        child: Text(
                                          "+${tracks.length - 3}",
                                          style: Get.textTheme.displayLarge,
                                        ),
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      width: 12.0,
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          const SizedBox(
                            height: 8.0,
                          ),
                          SizedBox(
                            width: Get.width,
                            child: ElevatedButton(
                              onPressed: () {
                                Get.dialog(
                                  CustomBlurryDialog(
                                    insetPadding: const EdgeInsets.all(42.0),
                                    contentPadding: EdgeInsets.zero,
                                    child: toBeEditedTracksColumn,
                                  ),
                                );
                              },
                              child: Obx(
                                () => Text(
                                  tracks.displayTrackKeyword,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: 8.0,
                          ),
                          SizedBox(
                            width: Get.width,
                            child: ElevatedButton(
                              onPressed: () {},
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  Language.inst.EDIT_ARTWORK,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 12.0,
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
                  controller: yearController,
                  hintText: Language.inst.YEAR,
                  icon: Broken.calendar,
                  maxLength: 8,
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
          Obx(
            () => Text(
              [
                tracks.displayTrackKeyword,
                tracks.map((e) => e.size).reduce((a, b) => a + b).fileSizeFormatted,
                tracks.totalDurationFormatted,
              ].join(' • '),
              style: Get.textTheme.displaySmall,
            ),
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
  final int? maxLength;
  final String? Function(String? value)? validator;
  const CustomTagTextField({super.key, required this.controller, required this.hintText, this.icon, this.hintMaxLines = 3, this.maxLines, this.maxLength, this.validator});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: null,
      child: TextFormField(
        validator: validator,
        maxLength: maxLength,
        controller: controller,
        textAlign: TextAlign.left,
        maxLines: maxLines,
        style: context.textTheme.displaySmall?.copyWith(fontSize: 14.5.multipliedFontScale, fontWeight: FontWeight.w600),
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
          hintStyle: context.textTheme.displaySmall?.copyWith(fontSize: 14.5.multipliedFontScale, color: context.textTheme.displaySmall?.color?.withAlpha(120)),
        ),
      ),
    );
  }
}

Future<bool> editTrackMetadata(Track track, {Map<TagType, dynamic>? tags, String insertComment = '', bool updateArtwork = false, bool updateTracks = true}) async {
  // i tried many other ways to automate this task, nothing worked
  // so yeah ask the user to select the specific folder
  // and provide an option in the setting to reset this premission
  await requestSAFpermission();

  final audioedit = OnAudioEdit();
  final info = await audioedit.readAudio(track.path);
  final copiedFile = kSdkVersion < 30 ? File(track.path) : await File(track.path).copy("${SettingsController.inst.defaultBackupLocation.value}/${track.displayName}");
  if (insertComment != '') {
    await audioedit.editAudio(
      copiedFile.path,
      {TagType.COMMENT: "$insertComment ${info.comment}"},
      searchInsideFolders: true,
    );
  }
  bool didUpdateTags = false;
  if (tags != null) {
    didUpdateTags = await audioedit.editAudio(
      copiedFile.path,
      tags,
      searchInsideFolders: true,
    );
  }
  if (updateArtwork) {
    await audioedit.editArtwork(
      copiedFile.path,
      // imagePath: currentImagePath.value,
      searchInsideFolders: true,
      openFilePicker: true,
    );
  }
  if (kSdkVersion >= 30) {
    await copiedFile.copy(track.path);
  }
  await copiedFile.delete();
  if (updateTracks) {
    Indexer.inst.updateTracks([track], updateArtwork: updateArtwork);
  }
  return didUpdateTags;
}

Future<void> requestSAFpermission() async {
  if (kSdkVersion < 30) {
    return;
  }
  final audioedit = OnAudioEdit();

  if (await audioedit.complexPermissionStatus()) {
    return;
  }

  await Get.dialog(
    CustomBlurryDialog(
      title: Language.inst.NOTE,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Language.inst.CHOOSE_BACKUP_LOCATION_TO_EDIT_METADATA.replaceFirst('_BACKUP_LOCATION_', SettingsController.inst.defaultBackupLocation.value),
            style: Get.textTheme.displayMedium,
          ),
          const SizedBox(
            height: 16.0,
          ),
          Text(
            '${Language.inst.NOTE}:',
            style: Get.textTheme.displayMedium,
          ),
          const SizedBox(
            height: 4.0,
          ),
          Text(
            Language.inst.CHOOSE_BACKUP_LOCATION_TO_EDIT_METADATA_NOTE,
            style: Get.textTheme.displaySmall,
          ),
        ],
      ),
    ),
  );
  await audioedit.requestComplexPermission();
}
