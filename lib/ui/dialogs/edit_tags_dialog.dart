import 'package:checkmark/checkmark.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/class/faudiomodel.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/tagger_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/main.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/multi_artwork_container.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/youtube/pages/yt_search_results_page.dart';

final _editingInProgress = <String, bool>{}.obs;

/// Tested And Working on:
/// - Android 9 (API 29): Internal ✓, External X `Needs SAF`
/// - Android 11 (API 31): Internal ✓, External ✓
/// - Android 13 (API 33): Internal ✓, External ✓
///
/// TODO: Implement [Android <= 9] SD Card Editing Using SAF (Storage Access Framework).
Future<void> showEditTracksTagsDialog(List<Track> tracks, Color? colorScheme) async {
  if (tracks.length == 1) {
    _editSingleTrackTagsDialog(tracks.first, colorScheme);
  } else {
    _editMultipleTracksTags(tracks.uniqued());
  }
}

Future<void> showSetYTLinkCommentDialog(List<Track> tracks, Color colorScheme) async {
  final singleTrack = tracks.first;
  final formKey = GlobalKey<FormState>();
  final controller = TextEditingController();
  final ytSearchController = TextEditingController();
  final ytSearchPageController = GlobalKey<YoutubeSearchResultsPageState>();
  final ytlink = singleTrack.youtubeLink;
  controller.text = ytlink;

  final canEditComment = false.obs;

  NamidaNavigator.inst.navigateDialog(
    onDisposing: () {
      controller.dispose();
      ytSearchController.dispose();
      canEditComment.close();
    },
    colorScheme: colorScheme,
    dialogBuilder: (theme) => Form(
      key: formKey,
      child: CustomBlurryDialog(
        theme: theme,
        title: lang.SET_YOUTUBE_LINK,
        contentPadding: const EdgeInsets.all(12.0).add(const EdgeInsets.only(top: 12.0)),
        leftAction: NamidaButton(
          text: lang.SEARCH,
          onPressed: () {
            final trExt = singleTrack.toTrackExt();
            final title = trExt.title == UnknownTags.TITLE ? null : trExt.title;
            final album = trExt.album == UnknownTags.ALBUM ? null : trExt.album;
            final artist = trExt.originalArtist == UnknownTags.ARTIST ? null : trExt.originalArtist;
            final searchText = [
              if (title != null) title,
              if (album != null) album,
              if (artist != null) artist,
            ].join(' ');
            ytSearchController.text = searchText;
            NamidaNavigator.inst.navigateDialog(
              colorScheme: colorScheme,
              dialogBuilder: (theme) => CustomBlurryDialog(
                theme: theme,
                title: lang.SEARCH_YOUTUBE,
                contentPadding: EdgeInsets.zero,
                insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                child: SizedBox(
                  width: Get.width,
                  height: Get.height * 0.7,
                  child: Column(
                    children: [
                      const SizedBox(height: 8.0),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: CustomTagTextField(
                          controller: ytSearchController,
                          keyboardType: TextInputType.text,
                          hintText: searchText,
                          labelText: lang.SEARCH,
                          onFieldSubmitted: (value) {
                            ytSearchPageController.currentState?.fetchSearch(customText: ytSearchController.text);
                          },
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      Expanded(
                        child: YoutubeSearchResultsPage(
                          key: ytSearchPageController,
                          searchText: searchText,
                          onVideoTap: (video) {
                            NamidaNavigator.inst.closeDialog();
                            final url = video.url;
                            if (url != null) {
                              controller.text = url;
                              canEditComment.value = true;

                              snackyy(
                                message: 'Set to "${video.name ?? ''}" by "${video.uploaderName ?? ''}"',
                                top: false,
                                borderRadius: 0,
                                margin: EdgeInsets.zero,
                                leftBarIndicatorColor: colorScheme,
                                animationDurationMS: 500,
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        actions: [
          const CancelButton(),
          Obx(
            () => NamidaButton(
              enabled: canEditComment.value && _editingInProgress[singleTrack.path] != true,
              textWidget: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_editingInProgress[singleTrack.path] == true) ...[
                    const LoadingIndicator(),
                    const SizedBox(width: 8.0),
                  ],
                  Text(
                    lang.SAVE,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  _editingInProgress[singleTrack.path] = true;
                  await FAudioTaggerController.inst.updateTracksMetadata(
                    tracks: [singleTrack],
                    editedTags: {},
                    commentToInsert: controller.text,
                    trimWhiteSpaces: false,
                  );
                  _editingInProgress[singleTrack.path] = false;
                  NamidaNavigator.inst.closeDialog();
                }
              },
            ),
          ),
        ],
        child: CustomTagTextField(
          controller: controller,
          hintText: ytlink.overflow,
          labelText: lang.LINK,
          keyboardType: TextInputType.url,
          onChanged: (value) {
            canEditComment.value = true;
          },
          validator: (value) {
            if (value!.isEmpty) {
              return lang.PLEASE_ENTER_A_NAME;
            }
            if ((NamidaLinkRegex.youtubeLinkRegex.firstMatch(value) ?? '') == '') {
              return lang.PLEASE_ENTER_A_LINK_SUBTITLE;
            }
            return null;
          },
        ),
      ),
    ),
  );
}

Widget get _getKeepDatesWidget => NamidaIconButton(
      tooltip: lang.KEEP_FILE_DATES,
      icon: settings.editTagsKeepFileDates.value ? Broken.document_code_2 : Broken.calendar_edit,
      onPressed: () {
        settings.save(editTagsKeepFileDates: !settings.editTagsKeepFileDates.value);
      },
      child: Obx(
        () => StackedIcon(
          disableColor: true,
          baseIcon: Broken.document_code_2,
          secondaryIcon: settings.editTagsKeepFileDates.value ? Broken.tick_circle : Broken.close_circle,
        ),
      ),
    );

Future<void> _editSingleTrackTagsDialog(Track track, Color? colorScheme) async {
  if (!await requestManageStoragePermission()) return;

  final color = (colorScheme ?? CurrentColor.inst.color).obs;
  if (colorScheme == null) {
    CurrentColor.inst.getTrackDelightnedColor(track, useIsolate: true).executeWithMinDelay().then((c) {
      if (c == color.value) return;
      color.value = c;
    });
  }

  FTags? tags;
  FArtwork? artwork;

  final infoFull = await FAudioTaggerController.inst.extractMetadata(trackPath: track.path, saveArtworkToCache: false);
  tags = infoFull.tags;
  artwork = tags.artwork;
  if (infoFull.hasError) {
    snackyy(
      title: lang.ERROR,
      message: "${lang.METADATA_READ_FAILED}\n${infoFull.errorsMap}",
      isError: true,
    );
  } else if (infoFull.errorsMap.isNotEmpty) {
    snackyy(title: lang.NOTE, message: "${infoFull.errorsMap}");
  }

  final trimWhiteSpaces = true.obs;
  final canEditTags = false.obs;
  final didAutoExtractFromFilename = false.obs;
  final currentImagePath = ''.obs;

  final tagsControllers = <TagField, TextEditingController>{};
  final editedTags = <TagField, String>{};

  // filling fields
  tagsControllers[TagField.title] = TextEditingController(text: tags.title ?? '');
  tagsControllers[TagField.album] = TextEditingController(text: tags.album ?? '');
  tagsControllers[TagField.artist] = TextEditingController(text: tags.artist ?? '');
  tagsControllers[TagField.albumArtist] = TextEditingController(text: tags.albumArtist ?? '');
  tagsControllers[TagField.genre] = TextEditingController(text: tags.genre ?? '');
  tagsControllers[TagField.mood] = TextEditingController(text: tags.mood ?? '');
  tagsControllers[TagField.composer] = TextEditingController(text: tags.composer ?? '');
  tagsControllers[TagField.comment] = TextEditingController(text: tags.comment ?? '');
  tagsControllers[TagField.lyrics] = TextEditingController(text: tags.lyrics ?? '');
  tagsControllers[TagField.trackNumber] = TextEditingController(text: tags.trackNumber.toIf('', '0'));
  tagsControllers[TagField.discNumber] = TextEditingController(text: tags.discNumber.toIf('', '0'));
  tagsControllers[TagField.year] = TextEditingController(text: tags.year.toIf('', '0'));
  tagsControllers[TagField.remixer] = TextEditingController(text: tags.remixer);
  tagsControllers[TagField.trackTotal] = TextEditingController(text: tags.trackTotal.toIf('', '0'));
  tagsControllers[TagField.discTotal] = TextEditingController(text: tags.discTotal ?? '');
  tagsControllers[TagField.lyricist] = TextEditingController(text: tags.lyricist ?? '');
  tagsControllers[TagField.language] = TextEditingController(text: tags.language ?? '');
  tagsControllers[TagField.recordLabel] = TextEditingController(text: tags.recordLabel ?? '');
  tagsControllers[TagField.country] = TextEditingController(text: tags.country ?? '');

  Widget getTagTextField(TagField tag) {
    return CustomTagTextField(
      controller: tagsControllers[tag]!,
      labelText: tag.toText(),
      hintText: tagsControllers[tag]!.text,
      icon: tag.toIcon(),
      onChanged: (value) {
        editedTags[tag] = value;
        canEditTags.value = true;
      },
      isNumeric: tag.isNumeric,
      maxLines: tag == TagField.comment ? 4 : null,
    );
  }

  await NamidaNavigator.inst.navigateDialog(
    onDisposing: () {
      color.close();
      trimWhiteSpaces.close();
      canEditTags.close();
      didAutoExtractFromFilename.close();
      currentImagePath.close();
      for (final c in tagsControllers.values) {
        c.dispose();
      }
    },
    scale: 0.94,
    lighterDialogColor: false,
    dialog: StreamBuilder(
        initialData: color.value,
        stream: color.stream,
        builder: (context, snapshot) {
          final theme = AppThemes.inst.getAppTheme(snapshot.data, null, false);
          return AnimatedTheme(
            data: theme,
            child: CustomBlurryDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
              normalTitleStyle: true,
              scrollable: false,
              icon: Broken.edit,
              title: lang.EDIT_TAGS,
              trailingWidgets: [
                _getKeepDatesWidget,
                NamidaIconButton(
                  icon: Broken.edit_2,
                  onPressed: () async {
                    final subList = List<TagField>.from(TagField.values).obs;
                    subList.removeWhere((element) => settings.tagFieldsToEdit.contains(element));

                    await NamidaNavigator.inst.navigateDialog(
                      onDisposing: () {
                        subList.close();
                      },
                      scale: 0.94,
                      dialog: CustomBlurryDialog(
                        title: lang.TAG_FIELDS,
                        child: SizedBox(
                          width: Get.width,
                          height: Get.height * 0.7,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6.0),
                              Text('${lang.ACTIVE} (${lang.REORDERABLE})', style: Get.textTheme.displayMedium),
                              const SizedBox(height: 6.0),
                              Expanded(
                                child: Obx(
                                  () {
                                    final tagFields = settings.tagFieldsToEdit;
                                    return ReorderableListView.builder(
                                      proxyDecorator: (child, index, animation) => child,
                                      padding: const EdgeInsets.only(bottom: 24.0),
                                      itemCount: settings.tagFieldsToEdit.length,
                                      onReorder: (oldIndex, newIndex) {
                                        if (newIndex > oldIndex) {
                                          newIndex -= 1;
                                        }
                                        final tfOld = tagFields[oldIndex];
                                        settings.removeFromList(tagFieldsToEdit1: tfOld);
                                        settings.insertInList(newIndex, tagFieldsToEdit1: tfOld);
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
                                              if (settings.tagFieldsToEdit.length <= 3) {
                                                showMinimumItemsSnack(3);
                                                return;
                                              }
                                              settings.removeFromList(tagFieldsToEdit1: tf);
                                              subList.add(tf);
                                            },
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 12.0),
                              Text(lang.NON_ACTIVE, style: Get.textTheme.displayMedium),
                              const SizedBox(height: 6.0),
                              Expanded(
                                child: Obx(
                                  () => ListView.builder(
                                    padding: const EdgeInsets.only(bottom: 24.0),
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
                                            settings.save(tagFieldsToEdit: [tf]);
                                            subList.remove(tf);
                                          },
                                        ),
                                      );
                                    },
                                    itemCount: subList.length,
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
                      lang.REMOVE_WHITESPACES,
                      style: Get.textTheme.displaySmall,
                    ),
                  ],
                ),
              ),
              actions: [
                Obx(
                  () => NamidaButton(
                    enabled: canEditTags.value && _editingInProgress[track.path] != true,
                    icon: Broken.pen_add,
                    textWidget: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_editingInProgress[track.path] == true) ...[
                          const LoadingIndicator(),
                          const SizedBox(width: 8.0),
                        ],
                        Text(
                          lang.SAVE,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    onPressed: () async {
                      _editingInProgress[track.path] = true;
                      await FAudioTaggerController.inst.updateTracksMetadata(
                        tracks: [track],
                        editedTags: editedTags,
                        imagePath: currentImagePath.value,
                        trimWhiteSpaces: trimWhiteSpaces.value,
                        onEdit: (didUpdate, error, track) {
                          if (!didUpdate) {
                            snackyy(title: lang.METADATA_EDIT_FAILED, message: error ?? '', isError: true);
                          }
                        },
                      );
                      _editingInProgress[track.path] = false;

                      NamidaNavigator.inst.closeDialog();
                    },
                  ),
                )
              ],
              child: Obx(
                () {
                  settings.tagFieldsToEdit;
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
                                        bytes: currentImagePath.value != '' ? null : artwork?.bytes,
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
                                      ...settings.tagFieldsToEdit.take(2).map(
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
                            ...settings.tagFieldsToEdit.sublist(2).map(
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
                          final titleAndArtist = Indexer.getTitleAndArtistFromFilename(track.path.getFilenameWOExt);
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
                              "${lang.AUTO_EXTRACT_TAGS_FROM_FILENAME} ${didAutoExtractFromFilename.value ? '✓' : ''}",
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
        }),
  );
}

Future<void> _editMultipleTracksTags(List<Track> tracksPre) async {
  if (!await requestManageStoragePermission()) return;

  final RxList<Track> tracks = List<Track>.from(tracksPre).obs;

  final toBeEditedTracksColumn = Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 12.0),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Text(
          lang.MULTIPLE_TRACKS_TAGS_EDIT_NOTE,
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
    TagField.mood,
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

  await NamidaNavigator.inst.navigateDialog(
    onDisposing: () {
      tracks.close();
      trimWhiteSpaces.close();
      canEditTags.close();
      currentImagePath.close();
      for (final c in tagsControllers.values) {
        c.dispose();
      }
      hasEmptyDumbValues.close();
    },
    scale: 0.94,
    dialog: CustomBlurryDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      normalTitleStyle: true,
      scrollable: false,
      icon: Broken.edit,
      title: lang.EDIT_TAGS,
      trailingWidgets: [
        _getKeepDatesWidget,
      ],
      actions: [
        Obx(
          () {
            final isEditing = tracks.any((track) => _editingInProgress[track.path] == true);
            return NamidaButton(
              enabled: canEditTags.value && !isEditing,
              icon: Broken.pen_add,
              textWidget: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isEditing) ...[
                    const LoadingIndicator(),
                    const SizedBox(width: 8.0),
                  ],
                  Text(
                    lang.SAVE,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              onPressed: () {
                tracks.loop((track, _) => _editingInProgress[track.path] = true);
                NamidaNavigator.inst.navigateDialog(
                  dialog: CustomBlurryDialog(
                    title: lang.NOTE,
                    insetPadding: const EdgeInsets.all(42.0),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
                    isWarning: true,
                    normalTitleStyle: true,
                    actions: [
                      NamidaButton(
                        text: lang.CANCEL,
                        onPressed: () => NamidaNavigator.inst.closeDialog(),
                      ),
                      NamidaButton(
                        text: lang.CONFIRM,
                        onPressed: () async {
                          NamidaNavigator.inst.closeDialog();
                          if (trimWhiteSpaces.value) {
                            editedTags.updateAll((key, value) => value.trimAll());
                          }

                          final RxInt successfullEdits = 0.obs;
                          final RxList<Track> failedEditsTracks = <Track>[].obs;
                          final RxBool finishedEditing = false.obs;
                          final RxString updatingLibrary = '?'.obs;

                          void showFailedTracksDialogs() {
                            NamidaNavigator.inst.navigateDialog(
                              dialog: CustomBlurryDialog(
                                contentPadding: EdgeInsets.zero,
                                title: lang.FAILED_EDITS,
                                actions: [
                                  NamidaButton(
                                    onPressed: NamidaNavigator.inst.closeDialog,
                                    text: lang.CONFIRM,
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
                            onDisposing: () {
                              successfullEdits.close();
                              failedEditsTracks.close();
                              finishedEditing.close();
                              updatingLibrary.close();
                            },
                            tapToDismiss: false,
                            dialog: Obx(
                              () => CustomBlurryDialog(
                                title: lang.PROGRESS,
                                normalTitleStyle: true,
                                trailingWidgets: [
                                  NamidaIconButton(
                                    icon: Broken.activity,
                                    onPressed: showFailedTracksDialogs,
                                  ),
                                ],
                                actions: [
                                  Obx(
                                    () => NamidaButton(
                                      enabled: finishedEditing.value,
                                      text: lang.DONE,
                                      onPressed: () => NamidaNavigator.inst.closeDialog(),
                                    ),
                                  )
                                ],
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      getText('${lang.SUCCEEDED}: ${successfullEdits.value}'),
                                      const SizedBox(height: 8.0),
                                      Obx(
                                        () => Row(
                                          children: [
                                            getText('${lang.FAILED}: ${failedEditsTracks.length}'),
                                            const SizedBox(width: 4.0),
                                            if (failedEditsTracks.isNotEmpty)
                                              TapDetector(
                                                onTap: showFailedTracksDialogs,
                                                child: getText(
                                                  lang.CHECK_LIST,
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
                                      getText('${lang.UPDATING} ${updatingLibrary.value}'),
                                      const SizedBox(height: 8.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                          String? errorMsg;
                          await FAudioTaggerController.inst.updateTracksMetadata(
                            tracks: tracks,
                            editedTags: editedTags,
                            trimWhiteSpaces: trimWhiteSpaces.value,
                            imagePath: currentImagePath.value,
                            onEdit: (didUpdate, error, track) {
                              if (didUpdate) {
                                successfullEdits.value++;
                              } else {
                                failedEditsTracks.add(track);
                                errorMsg = error;
                              }
                            },
                            onUpdatingTracksStart: () {
                              updatingLibrary.value = '...';
                            },
                          );

                          if (failedEditsTracks.isNotEmpty) {
                            snackyy(
                              title: '${lang.METADATA_EDIT_FAILED} (${failedEditsTracks.length})',
                              message: errorMsg ?? '',
                              isError: true,
                            );
                          }
                          updatingLibrary.value = '✓';
                          finishedEditing.value = true;
                          canEditTags.value = false;
                          tracks.loop((track, _) => _editingInProgress[track.path] = false);
                        },
                      ),
                    ],
                    child: toBeEditedTracksColumn,
                  ),
                );
              },
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
              lang.REMOVE_WHITESPACES,
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
                        title: lang.NOTE,
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
                                          tracks: tracks.toImageTracks(),
                                          fallbackToFolderCover: false,
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
                                            title: lang.NOTE,
                                            insetPadding: const EdgeInsets.all(42.0),
                                            contentPadding: EdgeInsets.zero,
                                            actions: [
                                              NamidaButton(
                                                text: lang.CONFIRM,
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
                                      text: lang.EDIT_ARTWORK,
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
                                TextSpan(text: "${lang.WARNING}: ", style: Get.textTheme.displayMedium),
                                TextSpan(
                                  text: lang.EMPTY_NON_MEANINGFUL_TAG_FIELDS,
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

class CustomTagTextField extends StatefulWidget {
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
  final AutovalidateMode? validatorMode;
  final void Function(String value)? onFieldSubmitted;
  final double borderRadius;
  final FocusNode? focusNode;

  const CustomTagTextField({
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
    this.validatorMode,
    this.onFieldSubmitted,
    this.borderRadius = 16.0,
    this.focusNode,
  });

  @override
  State<CustomTagTextField> createState() => _CustomTagTextFieldState();
}

class _CustomTagTextFieldState extends State<CustomTagTextField> {
  String initialText = '';
  bool didChange = false;

  @override
  void initState() {
    super.initState();
    initialText = widget.controller.text;
  }

  @override
  Widget build(BuildContext context) {
    final borderR = widget.borderRadius.multipliedRadius;
    final borderRS = (widget.borderRadius - 2.0).withMinimum(0).multipliedRadius;
    return TextFormField(
      focusNode: widget.focusNode,
      validator: widget.validator,
      maxLength: widget.maxLength,
      controller: widget.controller,
      textAlign: TextAlign.left,
      maxLines: widget.maxLines,
      autovalidateMode: widget.validatorMode,
      keyboardType: widget.keyboardType ?? (widget.isNumeric ? TextInputType.number : null),
      style: context.textTheme.displaySmall?.copyWith(fontSize: 14.5.multipliedFontScale, fontWeight: FontWeight.w600),
      onTapOutside: (event) {
        FocusScope.of(context).unfocus();
      },
      onChanged: (value) {
        if (widget.onChanged != null) widget.onChanged!(value);
        final isDifferent = initialText != value;
        if (isDifferent != didChange) {
          setState(() => didChange = isDifferent);
        }
      },
      onFieldSubmitted: widget.onFieldSubmitted,
      decoration: InputDecoration(
        label: widget.labelText != '' ? Text('${widget.labelText} ${didChange ? '(${lang.CHANGED})' : ''}') : null,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintMaxLines: widget.hintMaxLines,
        contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        errorMaxLines: 3,
        suffixIcon: Icon(widget.icon, size: 18.0),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRS),
          borderSide: BorderSide(color: Get.theme.colorScheme.onBackground.withAlpha(100), width: 2.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderR),
          borderSide: BorderSide(color: Get.theme.colorScheme.onBackground.withAlpha(100), width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderR),
          borderSide: BorderSide(color: Colors.brown.withAlpha(200), width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderR),
          borderSide: BorderSide(color: Colors.brown.withAlpha(200), width: 2.0),
        ),
        hintText: widget.hintText,
        hintStyle: context.textTheme.displaySmall?.copyWith(fontSize: 14.5.multipliedFontScale, color: context.textTheme.displaySmall?.color?.withAlpha(120)),
      ),
    );
  }
}
