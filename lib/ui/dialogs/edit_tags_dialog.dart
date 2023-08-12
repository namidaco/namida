import 'package:flutter/material.dart';

import 'package:checkmark/checkmark.dart';
import 'package:faudiotagger/faudiotagger.dart';
import 'package:faudiotagger/models/tag.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/multi_artwork_container.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';

import 'package:namida/main.dart';

/// Tested And Working on:
/// - Android 9 (API 29): Internal ✓, External X `Needs SAF`
/// - Android 11 (API 31): Internal ✓, External ✓
/// - Android 13 (API 33): Internal ✓, External ✓
///
/// TODO: Implement [Android <= 9] SD Card Editing Using SAF (Storage Access Framework).
Future<void> showEditTracksTagsDialog(List<Track> tracks, Color? colorScheme) async {
  if (tracks.length == 1) {
    colorScheme ??= await CurrentColor.inst.getTrackDelightnedColor(tracks.first);
    _editSingleTrackTagsDialog(tracks.first, colorScheme);
  } else {
    _editMultipleTracksTags(tracks.uniqued());
  }
}

Future<void> showSetYTLinkCommentDialog(List<Track> tracks, Color colorScheme) async {
  final singleTrack = tracks.first;
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController controller = TextEditingController();
  final ytlink = singleTrack.youtubeLink;
  controller.text = ytlink;
  NamidaNavigator.inst.navigateDialog(
    dialog: Form(
      key: formKey,
      child: CustomBlurryDialog(
        title: Language.inst.SET_YOUTUBE_LINK,
        contentPadding: const EdgeInsets.all(12.0).add(const EdgeInsets.only(top: 12.0)),
        actions: [
          const CancelButton(),
          NamidaButton(
            text: Language.inst.SAVE,
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await _updateTracksMetadata(
                  tagger: null,
                  tracks: [singleTrack],
                  editedTags: {},
                  commentToInsert: controller.text,
                  trimWhiteSpaces: false,
                );
                NamidaNavigator.inst.closeDialog();
              }
            },
          ),
        ],
        child: CustomTagTextField(
          controller: controller,
          hintText: ytlink.overflow,
          labelText: Language.inst.LINK,
          keyboardType: TextInputType.url,
          validator: (value) {
            if (value!.isEmpty) {
              return Language.inst.PLEASE_ENTER_A_NAME;
            }
            if ((kYoutubeRegex.firstMatch(value) ?? '') == '') {
              return Language.inst.PLEASE_ENTER_A_LINK_SUBTITLE;
            }
            return null;
          },
        ),
      ),
    ),
  );
}

Future<void> _editSingleTrackTagsDialog(Track track, Color colorScheme) async {
  if (!await requestManageStoragePermission()) {
    return;
  }

  final tagger = FAudioTagger();

  final info = await tagger.readAllData(path: track.path);
  if (info == null) {
    Get.snackbar(Language.inst.ERROR, Language.inst.METADATA_READ_FAILED);
    return;
  }

  final RxBool trimWhiteSpaces = true.obs;
  final RxBool canEditTags = false.obs;
  final RxBool didAutoExtractFromFilename = false.obs;
  final RxString currentImagePath = ''.obs;

  final tagsControllers = <TagField, TextEditingController>{};
  final editedTags = <TagField, String>{};

  // filling fields
  tagsControllers[TagField.title] = TextEditingController(text: info.title ?? '');
  tagsControllers[TagField.album] = TextEditingController(text: info.album ?? '');
  tagsControllers[TagField.artist] = TextEditingController(text: info.artist ?? '');
  tagsControllers[TagField.albumArtist] = TextEditingController(text: info.albumArtist ?? '');
  tagsControllers[TagField.genre] = TextEditingController(text: info.genre ?? '');
  tagsControllers[TagField.composer] = TextEditingController(text: info.composer ?? '');
  tagsControllers[TagField.comment] = TextEditingController(text: info.comment ?? '');
  tagsControllers[TagField.lyrics] = TextEditingController(text: info.lyrics ?? '');
  tagsControllers[TagField.trackNumber] = TextEditingController(text: info.trackNumber.toIf('', '0'));
  tagsControllers[TagField.discNumber] = TextEditingController(text: info.discNumber.toIf('', '0'));
  tagsControllers[TagField.year] = TextEditingController(text: info.year.toIf('', '0'));
  tagsControllers[TagField.remixer] = TextEditingController(text: info.remixer);
  tagsControllers[TagField.trackTotal] = TextEditingController(text: info.trackTotal.toIf('', '0'));
  tagsControllers[TagField.discTotal] = TextEditingController(text: info.discTotal ?? '');
  tagsControllers[TagField.lyricist] = TextEditingController(text: info.lyricist ?? '');
  tagsControllers[TagField.language] = TextEditingController(text: info.language ?? '');
  tagsControllers[TagField.recordLabel] = TextEditingController(text: info.recordLabel ?? '');
  tagsControllers[TagField.country] = TextEditingController(text: info.country ?? '');

  Widget getTagTextField(TagField tag) {
    final changed1 = tag == TagField.title && editedTags[TagField.title] != info.title;
    final changed2 = tag == TagField.artist && editedTags[TagField.artist] != info.artist;
    return CustomTagTextField(
      controller: tagsControllers[tag]!,
      labelText: tag.toText(),
      hintText: tagsControllers[tag]!.text,
      icon: tag.toIcon(),
      didEditField: (didAutoExtractFromFilename.value && (changed1 || changed2)).obs,
      onChanged: (value) {
        editedTags[tag] = value;
        canEditTags.value = true;
      },
      isNumeric: tag.isNumeric,
      maxLines: tag == TagField.comment ? 4 : null,
    );
  }

  NamidaNavigator.inst.navigateDialog(
    scale: 0.94,
    colorScheme: colorScheme,
    lighterDialogColor: false,
    dialogBuilder: (theme) => CustomBlurryDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      normalTitleStyle: true,
      scrollable: false,
      icon: Broken.edit,
      title: Language.inst.EDIT_TAGS,
      trailingWidgets: [
        NamidaIconButton(
          icon: Broken.edit_2,
          onPressed: () {
            final subList = List<TagField>.from(TagField.values).obs;
            subList.removeWhere((element) => SettingsController.inst.tagFieldsToEdit.contains(element));

            NamidaNavigator.inst.navigateDialog(
              scale: 0.94,
              dialog: CustomBlurryDialog(
                title: Language.inst.TAG_FIELDS,
                child: SizedBox(
                  width: Get.width,
                  height: Get.height * 0.7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6.0),
                      Text('${Language.inst.ACTIVE} (${Language.inst.REORDERABLE})', style: Get.textTheme.displayMedium),
                      const SizedBox(height: 6.0),
                      Expanded(
                        child: Obx(
                          () {
                            final tagFields = SettingsController.inst.tagFieldsToEdit;
                            return NamidaListView(
                              onReorder: (oldIndex, newIndex) {
                                if (newIndex > oldIndex) {
                                  newIndex -= 1;
                                }
                                final tfOld = tagFields[oldIndex];
                                SettingsController.inst.removeFromList(tagFieldsToEdit1: tfOld);
                                SettingsController.inst.insertInList(newIndex, tagFieldsToEdit1: tfOld);
                              },
                              itemBuilder: (context, i) {
                                final tf = tagFields[i];
                                return Padding(
                                  key: Key(i.toString()),
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: ListTileWithCheckMark(
                                    active: true,
                                    title: tf.toText(),
                                    icon: tf.toIcon(),
                                    onTap: () {
                                      if (SettingsController.inst.tagFieldsToEdit.length <= 3) {
                                        Get.snackbar(Language.inst.MINIMUM_ONE_FIELD, Language.inst.MINIMUM_ONE_FIELD_SUBTITLE);
                                        return;
                                      }
                                      SettingsController.inst.removeFromList(tagFieldsToEdit1: tf);
                                      subList.add(tf);
                                    },
                                  ),
                                );
                              },
                              itemCount: SettingsController.inst.tagFieldsToEdit.length,
                              itemExtents: null,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 6.0),
                      Text(Language.inst.NON_ACTIVE, style: Get.textTheme.displayMedium),
                      const SizedBox(height: 6.0),
                      Expanded(
                        child: Obx(
                          () => NamidaListView(
                            itemBuilder: (context, i) {
                              final tf = subList[i];
                              return Padding(
                                key: Key(i.toString()),
                                padding: const EdgeInsets.only(top: 8.0),
                                child: ListTileWithCheckMark(
                                  active: false,
                                  title: tf.toText(),
                                  icon: tf.toIcon(),
                                  onTap: () {
                                    SettingsController.inst.save(tagFieldsToEdit: [tf]);
                                    subList.remove(tf);
                                  },
                                ),
                              );
                            },
                            itemCount: subList.length,
                            itemExtents: null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        )
      ],
      leftAction: NamidaInkWell(
        bgColor: theme.cardColor,
        onTap: () => trimWhiteSpaces.value = !trimWhiteSpaces.value,
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
                  activeColor: theme.listTileTheme.iconColor!,
                  inactiveColor: theme.listTileTheme.iconColor!,
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
      actions: [
        Obx(
          () => NamidaButton(
            enabled: canEditTags.value,
            icon: Broken.pen_add,
            text: Language.inst.SAVE,
            onPressed: () async {
              await _updateTracksMetadata(
                tagger: tagger,
                tracks: [track],
                editedTags: editedTags,
                imagePath: currentImagePath.value,
                trimWhiteSpaces: trimWhiteSpaces.value,
                onEdit: (didUpdate, track) {
                  if (!didUpdate) {
                    Get.snackbar(Language.inst.METADATA_EDIT_FAILED, Language.inst.METADATA_EDIT_FAILED_SUBTITLE);
                  }
                },
              );

              NamidaNavigator.inst.closeDialog();
            },
          ),
        )
      ],
      child: Obx(
        () {
          SettingsController.inst.tagFieldsToEdit;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: Get.height * 0.61,
                width: Get.width,
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
                                key: Key(currentImagePath.value),
                                thumbnailSize: Get.width / 3,
                                bytes: currentImagePath.value != '' ? null : info.firstArtwork,
                                path: currentImagePath.value != '' ? currentImagePath.value : track.pathToImage,
                                onTopWidgets: [
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: NamidaBlurryContainer(
                                      onTap: () async {
                                        final pickedFile = await FilePicker.platform.pickFiles(type: FileType.image);
                                        final path = pickedFile?.files.first.path ?? '';
                                        if (pickedFile != null && path != '') {
                                          currentImagePath.value = path;
                                          canEditTags.value = true;
                                        }
                                      },
                                      borderRadius: BorderRadius.only(topLeft: Radius.circular(12.0.multipliedRadius)),
                                      child: const Icon(Broken.edit_2),
                                    ),
                                  ),
                                ],
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
                              ...SettingsController.inst.tagFieldsToEdit.take(2).map(
                                    (e) => Padding(
                                      padding: const EdgeInsets.only(top: 10.0),
                                      child: getTagTextField(e),
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    ...SettingsController.inst.tagFieldsToEdit.sublist(2).map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: getTagTextField(e),
                          ),
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
                track.audioInfoFormatted,
                style: Get.textTheme.displaySmall,
              ),
              const SizedBox(height: 4.0),
              NamidaInkWell(
                borderRadius: 2.0,
                onTap: () {
                  final titleAndArtist = Indexer.inst.getTitleAndArtistFromFilename(track.path.getFilenameWOExt);
                  final title = titleAndArtist.$1;
                  final artist = titleAndArtist.$2;

                  if (tagsControllers[TagField.title]!.text != title || tagsControllers[TagField.artist]!.text != artist) {
                    tagsControllers[TagField.title]!.text = title;
                    tagsControllers[TagField.artist]!.text = artist;

                    editedTags[TagField.title] = title;
                    editedTags[TagField.artist] = artist;

                    canEditTags.value = true;
                  }
                  didAutoExtractFromFilename.value = true;
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Broken.magicpen, size: 14.0),
                    const SizedBox(width: 4.0),
                    Text(
                      "${Language.inst.AUTO_EXTRACT_TAGS_FROM_FILENAME} ${didAutoExtractFromFilename.value ? '✓' : ''}",
                      style: Get.textTheme.displaySmall?.copyWith(
                        decoration: TextDecoration.underline,
                        decorationStyle: TextDecorationStyle.dashed,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

Future<void> _updateTracksMetadata({
  required FAudioTagger? tagger,
  required List<Track> tracks,
  required Map<TagField, String> editedTags,
  required bool trimWhiteSpaces,
  String imagePath = '',
  String commentToInsert = '',
  void Function(bool didUpdate, Track track)? onEdit,
  void Function()? onUpdatingTracksStart,
}) async {
  tagger ??= FAudioTagger();

  if (trimWhiteSpaces) {
    editedTags.updateAll((key, value) => value.trimAll());
  }

  final shouldUpdateArtwork = imagePath != '';

  String oldComment = '';
  if (commentToInsert != '') {
    oldComment = await tagger.readTags(path: tracks.first.path).then((value) => value?.comment ?? '');
  }
  final newTag = commentToInsert != ''
      ? Tag(comment: oldComment == '' ? commentToInsert : '$commentToInsert\n$oldComment')
      : Tag(
          artwork: shouldUpdateArtwork ? imagePath : null,
          title: editedTags[TagField.title],
          album: editedTags[TagField.album],
          artist: editedTags[TagField.artist],
          albumArtist: editedTags[TagField.albumArtist],
          composer: editedTags[TagField.composer],
          genre: editedTags[TagField.genre],
          trackNumber: editedTags[TagField.trackNumber],
          discNumber: editedTags[TagField.discNumber],
          year: editedTags[TagField.year],
          comment: editedTags[TagField.comment],
          lyrics: editedTags[TagField.lyrics],
          remixer: editedTags[TagField.remixer],
          trackTotal: editedTags[TagField.trackTotal],
          discTotal: editedTags[TagField.discTotal],
          lyricist: editedTags[TagField.lyricist],
          language: editedTags[TagField.language],
          recordLabel: editedTags[TagField.recordLabel],
          country: editedTags[TagField.country],
        );

  final tracksMap = <Track, TrackExtended>{};
  await tracks.loopFuture((track, _) async {
    final didUpdate = await tagger!.writeTags(
      path: track.path,
      tag: newTag,
    );
    if (didUpdate) {
      final trExt = track.toTrackExt();
      tracksMap[track] = trExt.copyWithTag(tag: newTag);
    }
    printo('Did Update Metadata: $didUpdate', isError: !didUpdate);
    if (onEdit != null) onEdit(didUpdate, track);
  });

  if (onUpdatingTracksStart != null) onUpdatingTracksStart();

  await Indexer.inst.updateTrackMetadata(
    tracksMap: tracksMap,
    newArtworkPath: imagePath,
  );
}

Future<void> _editMultipleTracksTags(List<Track> tracksPre) async {
  if (!await requestManageStoragePermission()) {
    return;
  }
  final RxList<Track> tracks = List<Track>.from(tracksPre).obs;

  final toBeEditedTracksColumn = Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 12.0),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Text(
          Language.inst.MULTIPLE_TRACKS_TAGS_EDIT_NOTE,
          style: Get.textTheme.displayMedium,
        ),
      ),
      const SizedBox(height: 12.0),
      SizedBox(
        width: Get.width,
        height: Get.height / 2,
        child: ListView.builder(
          itemCount: tracks.length,
          itemBuilder: (context, index) {
            final tr = tracks[index];
            return Obx(
              () => TrackTile(
                index: index,
                trackOrTwd: tr,
                queueSource: QueueSource.allTracks,
                onTap: () => tracks.addIf(() => !tracks.contains(tr), tr),
                bgColor: tracks.contains(tr) ? null : Colors.black.withAlpha(0),
                trailingWidget: IconButton(
                  icon: const Icon(Broken.close_circle),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    tracks.remove(tr);
                  },
                ),
              ),
            );
          },
        ),
      ),
    ],
  );

  final RxBool trimWhiteSpaces = true.obs;
  final RxBool canEditTags = false.obs;
  final RxString currentImagePath = ''.obs;

  final tagsControllers = <TagField, TextEditingController>{};
  final editedTags = <TagField, String>{};
  final hasEmptyDumbValues = false.obs;

  final availableTagsToEdit = <TagField>[
    TagField.album,
    TagField.artist,
    TagField.genre,
    TagField.year,
    TagField.comment,
    TagField.albumArtist,
    TagField.composer,
    TagField.trackTotal,
    TagField.discTotal,
  ];

  /// creating controllers
  availableTagsToEdit.loop((at, index) {
    tagsControllers[at] = TextEditingController();
  });
  void checkEmptyValues() {
    hasEmptyDumbValues.value = editedTags.values.any((element) => element.cleanUpForComparison == '');
  }

  Widget getTagTextField(TagField tag) {
    return CustomTagTextField(
      controller: tagsControllers[tag]!,
      labelText: tag.toText(),
      hintText: tagsControllers[tag]!.text,
      icon: tag.toIcon(),
      onChanged: (value) {
        editedTags[tag] = value;
        checkEmptyValues();
        canEditTags.value = true;
      },
      isNumeric: tag.isNumeric,
      maxLines: tag == TagField.comment ? 4 : null,
    );
  }

  NamidaNavigator.inst.navigateDialog(
    scale: 0.94,
    dialog: CustomBlurryDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      normalTitleStyle: true,
      scrollable: false,
      icon: Broken.edit,
      title: Language.inst.EDIT_TAGS,
      actions: [
        NamidaButton(
          icon: Broken.pen_add,
          text: Language.inst.SAVE,
          onPressed: () {
            NamidaNavigator.inst.navigateDialog(
              dialog: CustomBlurryDialog(
                title: Language.inst.NOTE,
                insetPadding: const EdgeInsets.all(42.0),
                contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
                isWarning: true,
                normalTitleStyle: true,
                actions: [
                  NamidaButton(
                    text: Language.inst.CANCEL,
                    onPressed: () => NamidaNavigator.inst.closeDialog(),
                  ),
                  NamidaButton(
                    text: Language.inst.CONFIRM,
                    onPressed: () async {
                      NamidaNavigator.inst.closeDialog();
                      if (trimWhiteSpaces.value) {
                        editedTags.updateAll((key, value) => value.trimAll());
                      }

                      final RxInt successfullEdits = 0.obs;
                      final RxList<Track> failedEditsTracks = <Track>[].obs;
                      final RxBool finishedEditing = false.obs;
                      final RxString updatingLibrary = '?'.obs;

                      void _showFailedTracksDialogs() {
                        NamidaNavigator.inst.navigateDialog(
                          dialog: CustomBlurryDialog(
                            contentPadding: EdgeInsets.zero,
                            title: Language.inst.FAILED_EDITS,
                            actions: [
                              NamidaButton(
                                onPressed: NamidaNavigator.inst.closeDialog,
                                text: Language.inst.CONFIRM,
                              )
                            ],
                            child: SizedBox(
                              height: Get.height * 0.5,
                              width: Get.width,
                              child: NamidaTracksList(
                                padding: EdgeInsets.zero,
                                queueLength: failedEditsTracks.length,
                                queueSource: QueueSource.others,
                                itemBuilder: (context, i) {
                                  return TrackTile(
                                    key: Key(i.toString()),
                                    trackOrTwd: failedEditsTracks[i],
                                    index: i,
                                    queueSource: QueueSource.others,
                                    onTap: () {},
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      }

                      Widget getText(String text, {TextStyle? style}) {
                        return Text(
                          text,
                          style: style ?? Get.textTheme.displayMedium,
                        );
                      }

                      NamidaNavigator.inst.navigateDialog(
                        tapToDismiss: false,
                        dialog: Obx(
                          () => CustomBlurryDialog(
                            title: Language.inst.PROGRESS,
                            normalTitleStyle: true,
                            trailingWidgets: [
                              NamidaIconButton(
                                icon: Broken.activity,
                                onPressed: _showFailedTracksDialogs,
                              ),
                            ],
                            actions: [
                              Obx(
                                () => NamidaButton(
                                  enabled: finishedEditing.value,
                                  text: Language.inst.DONE,
                                  onPressed: () => NamidaNavigator.inst.closeDialog(),
                                ),
                              )
                            ],
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  getText('${Language.inst.SUCCEEDED}: ${successfullEdits.value}'),
                                  const SizedBox(height: 8.0),
                                  Obx(
                                    () => Row(
                                      children: [
                                        getText('${Language.inst.FAILED}: ${failedEditsTracks.length}'),
                                        const SizedBox(width: 4.0),
                                        if (failedEditsTracks.isNotEmpty)
                                          GestureDetector(
                                            onTap: _showFailedTracksDialogs,
                                            child: getText(
                                              Language.inst.CHECK_LIST,
                                              style: Get.textTheme.displaySmall?.copyWith(
                                                color: Get.theme.colorScheme.secondary,
                                                decoration: TextDecoration.underline,
                                                decorationStyle: TextDecorationStyle.solid,
                                              ),
                                            ),
                                          )
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8.0),
                                  getText('${Language.inst.UPDATING} ${updatingLibrary.value}'),
                                  const SizedBox(height: 8.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                      await _updateTracksMetadata(
                        tagger: null,
                        tracks: tracks,
                        editedTags: editedTags,
                        trimWhiteSpaces: trimWhiteSpaces.value,
                        imagePath: currentImagePath.value,
                        onEdit: (didUpdate, track) {
                          if (didUpdate) {
                            successfullEdits.value++;
                          } else {
                            failedEditsTracks.add(track);
                          }
                        },
                        onUpdatingTracksStart: () {
                          updatingLibrary.value = '...';
                        },
                      );

                      if (failedEditsTracks.isNotEmpty) {
                        Get.snackbar('${Language.inst.METADATA_EDIT_FAILED} (${failedEditsTracks.length})', Language.inst.METADATA_EDIT_FAILED_SUBTITLE);
                      }
                      updatingLibrary.value = '✓';
                      finishedEditing.value = true;
                    },
                  ),
                ],
                child: toBeEditedTracksColumn,
              ),
            );
          },
        )
      ],
      leftAction: NamidaInkWell(
        bgColor: Get.theme.cardColor,
        onTap: () => trimWhiteSpaces.value = !trimWhiteSpaces.value,
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
      child: Obx(
        () => tracks.isEmpty
            ? SizedBox(
                width: Get.width * 0.6,
                child: NamidaButton(
                  onPressed: () {
                    NamidaNavigator.inst.navigateDialog(
                      dialog: CustomBlurryDialog(
                        title: Language.inst.NOTE,
                        insetPadding: const EdgeInsets.all(42.0),
                        contentPadding: EdgeInsets.zero,
                        child: toBeEditedTracksColumn,
                      ),
                    );
                  },
                  textWidget: Obx(
                    () => Text(tracks.displayTrackKeyword),
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: Get.height * 0.7,
                    width: Get.width,
                    child: ListView(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                Obx(
                                  () => currentImagePath.value != ''
                                      ? ArtworkWidget(
                                          key: Key(currentImagePath.value),
                                          thumbnailSize: Get.width / 3,
                                          path: currentImagePath.value,
                                        )
                                      : MultiArtworkContainer(
                                          heroTag: 'edittags_artwork',
                                          size: Get.width / 3,
                                          paths: tracks.toImagePaths(),
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
                                    child: NamidaButton(
                                      onPressed: () {
                                        NamidaNavigator.inst.navigateDialog(
                                          dialog: CustomBlurryDialog(
                                            title: Language.inst.NOTE,
                                            insetPadding: const EdgeInsets.all(42.0),
                                            contentPadding: EdgeInsets.zero,
                                            actions: [
                                              NamidaButton(
                                                text: Language.inst.CONFIRM,
                                                onPressed: NamidaNavigator.inst.closeDialog,
                                              )
                                            ],
                                            child: toBeEditedTracksColumn,
                                          ),
                                        );
                                      },
                                      textWidget: Obx(
                                        () => Text(tracks.displayTrackKeyword),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 8.0,
                                  ),
                                  SizedBox(
                                    width: Get.width,
                                    child: NamidaButton(
                                      text: Language.inst.EDIT_ARTWORK,
                                      onPressed: () async {
                                        final pickedFile = await FilePicker.platform.pickFiles(type: FileType.image);
                                        final path = pickedFile?.files.first.path ?? '';
                                        if (pickedFile != null && path != '') {
                                          currentImagePath.value = path;
                                          canEditTags.value = true;
                                        }
                                      },
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
                        ...availableTagsToEdit.map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(top: 10.0),
                            child: getTagTextField(e),
                          ),
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
                        tracks.totalSizeFormatted,
                        tracks.totalDurationFormatted,
                      ].join(' • '),
                      style: Get.textTheme.displaySmall,
                    ),
                  ),
                  const SizedBox(
                    height: 8.0,
                  ),
                  Obx(
                    () => hasEmptyDumbValues.value
                        ? RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(text: "${Language.inst.WARNING}: ", style: Get.textTheme.displayMedium),
                                TextSpan(
                                  text: Language.inst.EMPTY_NON_MEANINGFUL_TAG_FIELDS,
                                  style: Get.textTheme.displaySmall,
                                ),
                              ],
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

class CustomTagTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData? icon;
  final int hintMaxLines;
  final int? maxLines;
  final int? maxLength;
  final String? Function(String? value)? validator;
  final String labelText;
  final void Function(String value)? onChanged;
  final bool isNumeric;
  final TextInputType? keyboardType;
  final RxBool? didEditField;
  CustomTagTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.icon,
    this.hintMaxLines = 3,
    this.maxLines,
    this.maxLength,
    this.validator,
    this.onChanged,
    required this.labelText,
    this.isNumeric = false,
    this.keyboardType,
    this.didEditField,
  });
  final RxBool didChange = false.obs;
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
        keyboardType: keyboardType ?? (isNumeric ? TextInputType.number : null),
        style: context.textTheme.displaySmall?.copyWith(fontSize: 14.5.multipliedFontScale, fontWeight: FontWeight.w600),
        onChanged: (value) {
          if (onChanged != null) onChanged!(value);
          if (!didChange.value) {
            didChange.value = true;
          }
        },
        decoration: InputDecoration(
          label: labelText != ''
              ? Obx(() {
                  final reallyChanged = (didChange.value || (didEditField?.value ?? false));
                  return Text('$labelText ${reallyChanged ? '(${Language.inst.CHANGED})' : ''}');
                })
              : null,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          hintMaxLines: hintMaxLines,
          contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          errorMaxLines: 3,
          suffixIcon: Icon(icon, size: 18.0),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14.0.multipliedRadius),
            borderSide: BorderSide(color: Get.theme.colorScheme.onBackground.withAlpha(100), width: 2.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.0.multipliedRadius),
            borderSide: BorderSide(color: Get.theme.colorScheme.onBackground.withAlpha(100), width: 1.0),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.0.multipliedRadius),
            borderSide: BorderSide(color: Colors.brown.withAlpha(200), width: 2.0),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.0.multipliedRadius),
            borderSide: BorderSide(color: Colors.brown.withAlpha(200), width: 2.0),
          ),
          hintText: hintText,
          hintStyle: context.textTheme.displaySmall?.copyWith(fontSize: 14.5.multipliedFontScale, color: context.textTheme.displaySmall?.color?.withAlpha(120)),
        ),
      ),
    );
  }
}
