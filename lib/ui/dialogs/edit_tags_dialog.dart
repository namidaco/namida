import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:checkmark/checkmark.dart';

import 'package:namida/class/faudiomodel.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/file_browser.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/namida_storage/namida_storage.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/tagger_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
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

Future<void> showSetYTLinkCommentDialog(List<Track> tracks, Color colorScheme, {bool autoOpenSearch = false}) async {
  final singleTrack = tracks.first;
  final formKey = GlobalKey<FormState>();
  final controller = TextEditingController();
  final ytSearchController = TextEditingController();
  final ytSearchPageController = GlobalKey<YoutubeSearchResultsPageState>();
  final ytlink = singleTrack.youtubeLink;
  controller.text = ytlink;

  final canEditComment = false.obs;

  void openSearchDialog() {
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
        horizontalInset: 24.0,
        child: SizedBox(
          width: namida.width,
          height: namida.height * 0.7,
          child: Column(
            children: [
              const SizedBox(height: 16.0),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
                  searchTextCallback: () => ytSearchController.text,
                  onVideoTap: (video) {
                    NamidaNavigator.inst.closeDialog();
                    final url = video.buildUrl();
                    controller.text = url;
                    canEditComment.value = true;

                    snackyy(
                      message: 'Set to "${video.title}" by "${video.channelName ?? video.channel?.title}"',
                      top: false,
                      altDesign: true,
                      leftBarIndicatorColor: colorScheme,
                      animationDurationMS: 500,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
          onPressed: openSearchDialog,
        ),
        actions: [
          const CancelButton(),
          Obx(
            (context) => NamidaButton(
              enabled: canEditComment.valueR && _editingInProgress[singleTrack.path] != true,
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
                  await NamidaTaggerController.inst.updateTracksMetadata(
                    tracks: [singleTrack],
                    editedTags: {},
                    commentToInsert: controller.text,
                    trimWhiteSpaces: false,
                  ).ignoreError();
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

  if (autoOpenSearch) openSearchDialog();
}

Widget get _getKeepDatesWidget => ObxO(
      rx: settings.editTagsKeepFileDates,
      builder: (context, editTagsKeepFileDates) => NamidaIconButton(
        tooltip: () => lang.KEEP_FILE_DATES,
        icon: editTagsKeepFileDates ? Broken.document_code_2 : Broken.calendar_edit,
        onPressed: () {
          settings.save(editTagsKeepFileDates: !settings.editTagsKeepFileDates.value);
        },
        child: StackedIcon(
          disableColor: true,
          baseIcon: Broken.document_code_2,
          secondaryIcon: editTagsKeepFileDates ? Broken.tick_circle : Broken.close_circle,
        ),
      ),
    );

Future<void> _editSingleTrackTagsDialog(Track track, Color? colorScheme) async {
  if (!await requestManageStoragePermission()) return;

  final color = Colors.transparent.obso;

  void onColorsObtained(Color newColor) {
    color.value = newColor;
  }

  onColorsObtained(colorScheme ?? CurrentColor.inst.color);

  if (colorScheme == null) {
    final colorSync = CurrentColor.inst.getTrackDelightnedColorSync(track, null);
    if (colorSync != null) {
      onColorsObtained(colorSync);
    } else {
      CurrentColor.inst
          .getTrackDelightnedColor(track, null, useIsolate: true)
          .executeWithMinDelay(
            delayMS: NamidaNavigator.kDefaultDialogDurationMS,
          )
          .then(onColorsObtained);
    }
  }

  FTags? tags;
  Uint8List? artworkBytes = Uint8List.fromList([]);

  final infoFull = await NamidaTaggerController.inst.extractMetadata(trackPath: track.path, isVideo: track is Video, saveArtworkToCache: false);
  tags = infoFull.tags;
  artworkBytes = tags.artwork.bytes;
  if (infoFull.hasError) {
    final errorsMapLine = infoFull.errorsMap.isEmpty ? '' : "\n${infoFull.errorsMap}";
    snackyy(
      title: lang.ERROR,
      message: "${lang.METADATA_READ_FAILED}$errorsMapLine",
      isError: true,
    );
  } else if (infoFull.errorsMap.isNotEmpty) {
    snackyy(title: lang.NOTE, message: "${infoFull.errorsMap}");
  }

  final audioInfoFormatted = TrackExtended.buildAudioInfoFormatted(
    infoFull.durationMS ?? 0,
    await File(track.path).fileSize() ?? 0,
    infoFull.bitRate ?? 0,
    infoFull.sampleRate ?? 0,
    tags.gainData,
  );

  final trimWhiteSpaces = true.obs;
  final canEditTags = false.obs;
  final didAutoExtractFromFilename = false.obs;
  final currentImagePath = ''.obs;

  final editedTags = <TagField, String>{};

  // filling fields
  final tagsControllers = <TagField, TextEditingController>{
    TagField.title: TextEditingController(text: tags.title ?? ''),
    TagField.album: TextEditingController(text: tags.album ?? ''),
    TagField.artist: TextEditingController(text: tags.artist ?? ''),
    TagField.albumArtist: TextEditingController(text: tags.albumArtist ?? ''),
    TagField.genre: TextEditingController(text: tags.genre ?? ''),
    TagField.composer: TextEditingController(text: tags.composer ?? ''),
    TagField.comment: TextEditingController(text: tags.comment ?? ''),
    TagField.description: TextEditingController(text: tags.description ?? ''),
    TagField.synopsis: TextEditingController(text: tags.synopsis ?? ''),
    TagField.lyrics: TextEditingController(text: tags.lyrics ?? ''),
    TagField.trackNumber: TextEditingController(text: tags.trackNumber.toIf('', '0')),
    TagField.discNumber: TextEditingController(text: tags.discNumber.toIf('', '0')),
    TagField.year: TextEditingController(text: tags.year.toIf('', '0')),
    TagField.remixer: TextEditingController(text: tags.remixer),
    TagField.trackTotal: TextEditingController(text: tags.trackTotal.toIf('', '0')),
    TagField.discTotal: TextEditingController(text: tags.discTotal ?? ''),
    TagField.lyricist: TextEditingController(text: tags.lyricist ?? ''),
    TagField.language: TextEditingController(text: tags.language ?? ''),
    TagField.recordLabel: TextEditingController(text: tags.recordLabel ?? ''),
    TagField.country: TextEditingController(text: tags.country ?? ''),

    // -- in tag editor we aint knowing local db shi
    TagField.mood: TextEditingController(text: tags.mood ?? ''),
    TagField.tags: TextEditingController(text: tags.tags ?? ''),
    TagField.rating: TextEditingController(text: tags.ratingPercentage == null ? null : (tags.ratingPercentage! * 100).round().toString()),
  };

  Widget getTagTextField(TagField tag, {FormFieldValidator? validator}) {
    return CustomTagTextField(
      controller: tagsControllers[tag]!,
      labelText: tag.toText(),
      hintText: tagsControllers[tag]!.text,
      icon: tag.toIcon(),
      onChanged: (value) {
        editedTags[tag] = value;
        canEditTags.value = true;
      },
      validator: tag == TagField.rating ? _ratingsValidator : null,
      isNumeric: tag.isNumeric,
      maxLines: tag == TagField.comment || tag == TagField.description || tag == TagField.synopsis ? 4 : null,
    );
  }

  final formKey = GlobalKey<FormState>();

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
    dialog: ObxO(
        rx: color,
        builder: (context, color) {
          final theme = AppThemes.inst.getAppTheme(color, null, false);
          return AnimatedThemeOrTheme(
            data: theme,
            child: Form(
              key: formKey,
              child: CustomBlurryDialog(
                horizontalInset: 20.0,
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
                      subList.removeWhere((element) => settings.tagFieldsToEdit.value.contains(element));

                      await NamidaNavigator.inst.navigateDialog(
                        scale: 1.0,
                        onDisposing: () {
                          subList.close();
                        },
                        dialog: CustomBlurryDialog(
                          title: lang.TAG_FIELDS,
                          child: SizedBox(
                            width: namida.width,
                            height: namida.height * 0.6,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 6.0),
                                Text('${lang.ACTIVE} (${lang.REORDERABLE})', style: namida.textTheme.displayMedium),
                                const SizedBox(height: 6.0),
                                Expanded(
                                  child: ObxO(
                                    rx: settings.tagFieldsToEdit,
                                    builder: (context, tagFieldsToEdit) => NamidaListView(
                                      itemExtent: null,
                                      listBottomPadding: 24.0,
                                      itemCount: tagFieldsToEdit.length,
                                      onReorder: (oldIndex, newIndex) {
                                        if (newIndex > oldIndex) {
                                          newIndex -= 1;
                                        }
                                        final tfOld = tagFieldsToEdit[oldIndex];
                                        settings.removeFromList(tagFieldsToEdit1: tfOld);
                                        settings.insertInList(newIndex, tagFieldsToEdit1: tfOld);
                                      },
                                      itemBuilder: (context, i) {
                                        final tf = tagFieldsToEdit[i];
                                        return Padding(
                                          key: ValueKey(i),
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: ListTileWithCheckMark(
                                            active: true,
                                            title: tf.toText(),
                                            icon: tf.toIcon(),
                                            onTap: () {
                                              if (tagFieldsToEdit.length <= 3) {
                                                showMinimumItemsSnack(3);
                                                return;
                                              }
                                              settings.removeFromList(tagFieldsToEdit1: tf);
                                              subList.add(tf);
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12.0),
                                Text(lang.NON_ACTIVE, style: namida.textTheme.displayMedium),
                                const SizedBox(height: 6.0),
                                Expanded(
                                  child: Obx(
                                    (context) => ListView.builder(
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
                  onTap: trimWhiteSpaces.toggle,
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Obx(
                        (context) => SizedBox(
                          height: 18,
                          width: 18,
                          child: CheckMark(
                            strokeWidth: 2,
                            activeColor: theme.listTileTheme.iconColor!,
                            inactiveColor: theme.listTileTheme.iconColor!,
                            duration: const Duration(milliseconds: 400),
                            active: trimWhiteSpaces.valueR,
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 8.0,
                      ),
                      Text(
                        lang.REMOVE_WHITESPACES,
                        style: namida.textTheme.displaySmall,
                      ),
                    ],
                  ),
                ),
                actions: [
                  Obx(
                    (context) => NamidaButton(
                      enabled: canEditTags.valueR && _editingInProgress[track.path] != true,
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
                        if (formKey.currentState!.validate() == false) return;

                        _editingInProgress[track.path] = true;
                        await NamidaTaggerController.inst.updateTracksMetadata(
                          tracks: [track],
                          editedTags: editedTags,
                          imagePath: currentImagePath.value,
                          trimWhiteSpaces: trimWhiteSpaces.value,
                          onEdit: (didUpdate, error, track) {
                            if (!didUpdate) {
                              snackyy(title: lang.METADATA_EDIT_FAILED, message: error ?? '', isError: true);
                            }
                          },
                        ).ignoreError();
                        _editingInProgress[track.path] = false;

                        NamidaNavigator.inst.closeDialog();
                      },
                    ),
                  )
                ],
                child: ObxO(
                  rx: settings.tagFieldsToEdit,
                  builder: (context, tagFieldsToEdit) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutWidthProvider(
                        builder: (context, maxWidth) => SizedBox(
                          height: namida.height * 0.61,
                          width: maxWidth,
                          child: ListView(
                            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom * 0.6),
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      Obx(
                                        (context) => ArtworkWidget(
                                          key: Key(currentImagePath.valueR),
                                          fadeMilliSeconds: 0,
                                          icon: track is Video ? Broken.video : Broken.musicnote,
                                          thumbnailSize: maxWidth * 0.36,
                                          bytes: currentImagePath.valueR != '' ? null : artworkBytes,
                                          path: currentImagePath.valueR != '' ? currentImagePath.valueR : null,
                                          onTopWidgets: [
                                            Positioned(
                                              bottom: 0,
                                              right: 0,
                                              child: NamidaBlurryContainer(
                                                onTap: () async {
                                                  final pickedFile = await NamidaFileBrowser.pickFile(note: lang.EDIT_ARTWORK, memeType: NamidaStorageFileMemeType.image);
                                                  final path = pickedFile?.path ?? '';
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
                                        ...tagFieldsToEdit.take(2).map(
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
                              ...tagFieldsToEdit.sublist(2).map(
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
                      ),
                      const SizedBox(
                        height: 12.0,
                      ),
                      Text(
                        track.path,
                        style: namida.textTheme.displaySmall,
                      ),
                      const SizedBox(
                        height: 4.0,
                      ),
                      Text(
                        audioInfoFormatted,
                        style: namida.textTheme.displaySmall,
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
                        child: ObxO(
                          rx: didAutoExtractFromFilename,
                          builder: (context, didAutoExtractFromFilenameValue) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Broken.magicpen, size: 14.0),
                              const SizedBox(width: 4.0),
                              Text(
                                "${lang.AUTO_EXTRACT_TAGS_FROM_FILENAME} ${didAutoExtractFromFilenameValue ? '✓' : ''}",
                                style: namida.textTheme.displaySmall?.copyWith(
                                  decoration: TextDecoration.underline,
                                  decorationStyle: TextDecorationStyle.dashed,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
  );
}

Future<void> _editMultipleTracksTags(List<Track> tracksPre) async {
  if (!await requestManageStoragePermission()) return;

  final tracksGoingToBeEditedRx = <Track, bool>{for (final t in tracksPre) t: true}.obs;

  final toBeEditedTracksColumn = Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 12.0),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Text(
          lang.MULTIPLE_TRACKS_TAGS_EDIT_NOTE,
          style: namida.textTheme.displayMedium,
        ),
      ),
      const SizedBox(height: 12.0),
      SizedBox(
        width: namida.width,
        height: namida.height * 0.5,
        child: TrackTilePropertiesProvider(
          configs: const TrackTilePropertiesConfigs(
            queueSource: QueueSource.others,
          ),
          builder: (properties) => ObxO(
            rx: tracksGoingToBeEditedRx,
            builder: (context, tracksGoingToBeEdited) {
              final list = tracksGoingToBeEdited.keys.toList();

              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final tr = list[index];
                  final isSelected = tracksGoingToBeEdited[tr] == true;
                  return TrackTile(
                    properties: properties,
                    index: index,
                    trackOrTwd: tr,
                    onTap: () => tracksGoingToBeEditedRx[tr] = !isSelected,
                    bgColor: isSelected ? null : Colors.black.withAlpha(0),
                    trailingWidget: IconButton(
                      icon: const Icon(Broken.close_circle),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => tracksGoingToBeEditedRx[tr] = false,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    ],
  );

  final trimWhiteSpaces = true.obs;
  final canEditTags = false.obs;
  final currentImagePath = ''.obs;

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
    TagField.description,
    TagField.synopsis,
    TagField.albumArtist,
    TagField.composer,
    TagField.trackTotal,
    TagField.discTotal,
    TagField.tags,
    TagField.rating,
    TagField.mood,
  ];

  /// creating controllers
  availableTagsToEdit.loop((at) {
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
      validator: tag == TagField.rating ? _ratingsValidator : null,
      isNumeric: tag.isNumeric,
      maxLines: tag == TagField.comment || tag == TagField.description || tag == TagField.synopsis ? 4 : null,
    );
  }

  final formKey = GlobalKey<FormState>();

  await NamidaNavigator.inst.navigateDialog(
    onDisposing: () {
      tracksGoingToBeEditedRx.close();
      trimWhiteSpaces.close();
      canEditTags.close();
      currentImagePath.close();
      for (final c in tagsControllers.values) {
        c.dispose();
      }
      hasEmptyDumbValues.close();
    },
    scale: 0.94,
    dialog: Form(
      key: formKey,
      child: CustomBlurryDialog(
        horizontalInset: 20.0,
        normalTitleStyle: true,
        scrollable: false,
        icon: Broken.edit,
        title: lang.EDIT_TAGS,
        trailingWidgets: [
          _getKeepDatesWidget,
        ],
        actions: [
          Obx(
            (context) {
              final isEditing = tracksGoingToBeEditedRx.valueR.keys.any((track) => _editingInProgress[track.path] == true);
              return NamidaButton(
                enabled: canEditTags.valueR && !isEditing,
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
                  if (formKey.currentState!.validate() == false) return;

                  for (final k in tracksGoingToBeEditedRx.value.keys) {
                    _editingInProgress[k.path] = true;
                  }
                  NamidaNavigator.inst.navigateDialog(
                    dialog: CustomBlurryDialog(
                      title: lang.NOTE,
                      horizontalInset: 42.0,
                      verticalInset: 42.0,
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

                            final successfullEdits = 0.obs;
                            final RxList<Track> failedEditsTracks = <Track>[].obs;
                            final finishedEditing = false.obs;
                            final updatingLibrary = '?'.obs;

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
                                    height: namida.height * 0.5,
                                    width: namida.width,
                                    child: NamidaTracksList(
                                      infoBox: null,
                                      listBottomPadding: 0,
                                      queue: failedEditsTracks.value,
                                      queueLength: failedEditsTracks.length,
                                      queueSource: QueueSource.others,
                                      onTap: () {},
                                    ),
                                  ),
                                ),
                              );
                            }

                            Widget getText(String text, {TextStyle? style}) {
                              return Text(
                                text,
                                style: style ?? namida.textTheme.displayMedium,
                              );
                            }

                            NamidaNavigator.inst.navigateDialog(
                              onDisposing: () {
                                successfullEdits.close();
                                failedEditsTracks.close();
                                finishedEditing.close();
                                updatingLibrary.close();
                              },
                              tapToDismiss: () => false,
                              dialog: Obx(
                                (context) => CustomBlurryDialog(
                                  title: lang.PROGRESS,
                                  normalTitleStyle: true,
                                  trailingWidgets: [
                                    NamidaIconButton(
                                      icon: Broken.activity,
                                      onPressed: showFailedTracksDialogs,
                                    ),
                                  ],
                                  actions: [
                                    ObxO(
                                      rx: finishedEditing,
                                      builder: (context, finished) => DoneButton(
                                        enabled: finished,
                                      ),
                                    ),
                                  ],
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        getText('${lang.SUCCEEDED}: ${successfullEdits.valueR}'),
                                        const SizedBox(height: 8.0),
                                        Obx(
                                          (context) => Row(
                                            children: [
                                              getText('${lang.FAILED}: ${failedEditsTracks.length}'),
                                              const SizedBox(width: 4.0),
                                              if (failedEditsTracks.isNotEmpty)
                                                TapDetector(
                                                  onTap: showFailedTracksDialogs,
                                                  child: getText(
                                                    lang.CHECK_LIST,
                                                    style: namida.textTheme.displaySmall?.copyWith(
                                                      color: namida.theme.colorScheme.secondary,
                                                      decoration: TextDecoration.underline,
                                                      decorationStyle: TextDecorationStyle.solid,
                                                    ),
                                                  ),
                                                )
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 8.0),
                                        getText('${lang.UPDATING} ${updatingLibrary.valueR}'),
                                        const SizedBox(height: 8.0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                            String? errorMsg;
                            await NamidaTaggerController.inst
                                .updateTracksMetadata(
                                  tracks: tracksGoingToBeEditedRx.value.keys.toList(),
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
                                )
                                .ignoreError();

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

                            for (final k in tracksGoingToBeEditedRx.value.keys) {
                              _editingInProgress[k.path] = false;
                            }
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
          bgColor: namida.theme.cardColor,
          onTap: trimWhiteSpaces.toggle,
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Obx(
                (context) => SizedBox(
                  height: 18,
                  width: 18,
                  child: CheckMark(
                    strokeWidth: 2,
                    activeColor: namida.theme.listTileTheme.iconColor!,
                    inactiveColor: namida.theme.listTileTheme.iconColor!,
                    duration: const Duration(milliseconds: 400),
                    active: trimWhiteSpaces.valueR,
                  ),
                ),
              ),
              const SizedBox(
                width: 8.0,
              ),
              Text(
                lang.REMOVE_WHITESPACES,
                style: namida.textTheme.displaySmall,
              ),
            ],
          ),
        ),
        child: ObxO(
          rx: tracksGoingToBeEditedRx,
          builder: (context, tracksGoingToBeEditedAll) {
            final tracksGoingToBeEdited = tracksGoingToBeEditedAll.entries.where((element) => element.value).map((e) => e.key).toList();
            return tracksGoingToBeEdited.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: NamidaButton(
                      onPressed: () {
                        NamidaNavigator.inst.navigateDialog(
                          dialog: CustomBlurryDialog(
                            title: lang.NOTE,
                            horizontalInset: 42.0,
                            verticalInset: 42.0,
                            contentPadding: EdgeInsets.zero,
                            child: toBeEditedTracksColumn,
                          ),
                        );
                      },
                      textWidget: Text(
                        tracksGoingToBeEdited.length.displayTrackKeyword,
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutWidthProvider(
                        builder: (context, maxWidth) => SizedBox(
                          height: namida.height * 0.7,
                          width: maxWidth,
                          child: ListView(
                            padding: EdgeInsets.only(bottom: (namida.viewInsets?.bottom ?? 0) * 0.6),
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      Obx(
                                        (context) => currentImagePath.valueR != ''
                                            ? ArtworkWidget(
                                                key: Key(currentImagePath.valueR),
                                                fadeMilliSeconds: 0,
                                                thumbnailSize: maxWidth * 0.36,
                                                path: currentImagePath.valueR,
                                              )
                                            : MultiArtworkContainer(
                                                heroTag: 'edittags_artwork',
                                                fadeMilliSeconds: 0,
                                                size: maxWidth * 0.36,
                                                tracks: tracksGoingToBeEdited.toImageTracks(),
                                                fallbackToFolderCover: false,
                                                onTopWidget: tracksGoingToBeEdited.length > 3
                                                    ? Positioned(
                                                        right: 0,
                                                        bottom: 0,
                                                        child: NamidaBlurryContainer(
                                                          width: maxWidth / 6.2,
                                                          height: maxWidth / 6.2,
                                                          borderRadius: BorderRadius.zero,
                                                          child: Center(
                                                            child: Text(
                                                              "+${tracksGoingToBeEdited.length - 3}",
                                                              style: namida.textTheme.displayLarge,
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
                                          width: namida.width,
                                          child: NamidaButton(
                                            onPressed: () {
                                              NamidaNavigator.inst.navigateDialog(
                                                dialog: CustomBlurryDialog(
                                                  title: lang.NOTE,
                                                  horizontalInset: 42.0,
                                                  verticalInset: 42.0,
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
                                            textWidget: Text(
                                              tracksGoingToBeEdited.length.displayTrackKeyword,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(
                                          height: 8.0,
                                        ),
                                        SizedBox(
                                          width: namida.width,
                                          child: NamidaButton(
                                            text: lang.EDIT_ARTWORK,
                                            onPressed: () async {
                                              final pickedFile = await NamidaFileBrowser.pickFile(note: lang.EDIT_ARTWORK, memeType: NamidaStorageFileMemeType.image);
                                              final path = pickedFile?.path ?? '';
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
                      ),
                      const SizedBox(
                        height: 12.0,
                      ),
                      Text(
                        [
                          tracksGoingToBeEdited.displayTrackKeyword,
                          tracksGoingToBeEdited.totalSizeFormatted,
                          tracksGoingToBeEdited.totalDurationFormatted,
                        ].join(' • '),
                        style: namida.textTheme.displaySmall,
                      ),
                      const SizedBox(
                        height: 8.0,
                      ),
                      Obx(
                        (context) => hasEmptyDumbValues.valueR
                            ? Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(text: "${lang.WARNING}: ", style: namida.textTheme.displayMedium),
                                    TextSpan(
                                      text: lang.EMPTY_NON_MEANINGFUL_TAG_FIELDS,
                                      style: namida.textTheme.displaySmall,
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox(),
                      ),
                    ],
                  );
          },
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
  final void Function()? onTap;
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
    this.onTap,
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
      onTap: widget.onTap,
      focusNode: widget.focusNode,
      validator: widget.validator,
      maxLength: widget.maxLength,
      controller: widget.controller,
      textAlign: TextAlign.left,
      maxLines: widget.maxLines,
      autovalidateMode: widget.validatorMode,
      keyboardType: widget.keyboardType ?? (widget.isNumeric ? TextInputType.number : null),
      style: context.textTheme.displaySmall?.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600),
      // onTapOutside: (event) => FocusScope.of(context).unfocus(), // inconvenient
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
          borderSide: BorderSide(color: context.theme.colorScheme.onSurface.withAlpha(100), width: 2.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderR),
          borderSide: BorderSide(color: context.theme.colorScheme.onSurface.withAlpha(100), width: 1.0),
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
        hintStyle: context.textTheme.displaySmall?.copyWith(fontSize: 14.5, color: context.textTheme.displaySmall?.color?.withAlpha(120)),
      ),
    );
  }
}

String? _ratingsValidator(String? value) {
  if (value == null || value.isEmpty) return null;
  final intval = int.tryParse(value);
  if (intval == null) return lang.NAME_CONTAINS_BAD_CHARACTER;
  if (intval < 0 || intval > 100) return '0-100';
  return null;
}
