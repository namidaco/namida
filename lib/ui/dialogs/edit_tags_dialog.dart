import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:namida/class/faudiomodel.dart';
import 'package:namida/class/file_matcher.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/file_browser.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/namida_storage/namida_storage.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/smart_playlists/smart_playlists_controller.dart';
import 'package:namida/controller/tagger_controller.dart';
import 'package:namida/controller/text_suggestions_provider.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/main.dart';
import 'package:namida/ui/dialogs/create_smart_playlist_dialog.dart';
import 'package:namida/ui/dialogs/track_stats_dialog.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/multi_artwork_container.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';
import 'package:namida/ui/widgets/text_suggestions.dart';
import 'package:namida/youtube/pages/yt_search_results_page.dart';

final _editingInProgress = <String, bool>{}.obs;

/// Tested And Working on:
/// - Android 9 (API 29): Internal ✓, External ✓ `Via SAF`
/// - Android 11 (API 31): Internal ✓, External ✓
/// - Android 13 (API 33): Internal ✓, External ✓
///
/// SD Card editing on [Android <= 10] requires SAF (Storage Access Framework),
/// supported in `TagsExtractor.executeWriteWithSafFallback`.
Future<void> showEditTracksTagsDialog(List<PhysicalMedia> tracks, Color? colorScheme, {bool instantEditArtwork = false, bool isAlbum = false}) async {
  if (tracks.isEmpty) return;
  if (tracks.length == 1) {
    _editSingleTrackTagsDialog(tracks.first, colorScheme, instantEditArtwork: instantEditArtwork);
  } else {
    _editMultipleTracksTags(tracks.uniqued(), instantEditArtwork: instantEditArtwork, isAlbum: isAlbum);
  }
}

Future<void> showSetYTLinkCommentDialog(Track singleTrackPre, Color colorScheme, {bool autoOpenSearch = false}) async {
  if (!await requestManageStoragePermission(directoryToCreate: AppDirs.INTERNAL_STORAGE)) return;

  // -- even tho we can modify the link in comment (app only), the next refresh would nuke it instantly, so better prevent it alltogether.
  final singleTrack = singleTrackPre.asPhysicalOrError();
  if (singleTrack == null) return;

  if (singleTrack is Video) {
    // -- video matching is currently skipped for video files
    snackyy(
      message: lang.notSupportedForVideoFiles,
      isError: true,
    );
    return;
  }

  final formKey = GlobalKey<FormState>();
  final controller = TextEditingController();
  final ytSearchController = TextEditingController();
  final ytSearchPageController = GlobalKey<YoutubeSearchResultsPageState>();
  final ytlink = singleTrack.youtubeLink;
  controller.text = ytlink;

  final canEditComment = false.obs;

  Future<void> confirmEdit() async {
    if (formKey.currentState!.validate()) {
      _editingInProgress[singleTrack.path] = true;
      if (singleTrack.isPhysical) {
        await NamidaTaggerController.inst
            .updateTracksMetadata(
              tracks: [singleTrack],
              editedTags: {},
              commentToInsert: controller.text,
            )
            .ignoreError();
      } else {
        final trExt = singleTrack.toTrackExt();
        final oldComment = trExt.comment;
        final commentToInsert = controller.text;
        await Indexer.inst.updateTrackMetadata(
          tracksMap: {
            singleTrack: trExt.copyWith(
              comment: oldComment.isEmpty ? commentToInsert : '$commentToInsert\n$oldComment',
              generatePathHash: false,
            ),
          },
        );
      }

      _editingInProgress[singleTrack.path] = false;
      NamidaNavigator.inst.closeDialog();

      final currentItem = Player.inst.currentItem.value;
      if (currentItem is Selectable && singleTrackPre == currentItem.track) {
        VideoController.inst.updateCurrentVideo(singleTrackPre);
      }
    }
  }

  void openSearchDialog() {
    final trExt = singleTrack.toTrackExt();
    final title = trExt.title == UnknownTags.TITLE ? null : trExt.title;
    final album = trExt.originalAlbum == UnknownTags.ALBUM ? null : trExt.originalAlbum;
    final artist = trExt.originalArtist == UnknownTags.ARTIST ? null : trExt.originalArtist;
    final searchText = [
      ?title,
      ?album,
      ?artist,
    ].join(' ');
    ytSearchController.text = searchText;
    NamidaNavigator.inst.navigateDialog(
      colorScheme: colorScheme,
      dialogBuilder: (theme) => CustomBlurryDialog(
        theme: theme,
        title: lang.searchYoutube,
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
                  labelText: lang.search,
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
                      title: lang.changed,
                      message: '"${video.channelName ?? video.channel?.title}" -> "${video.title}"',
                      top: false,
                      altDesign: true,
                      leftBarIndicatorColor: colorScheme,
                      animationDurationMS: 500,
                    );

                    // -- auto edit once a video is chosen
                    confirmEdit();
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
        title: lang.setYoutubeLink,
        contentPadding: const EdgeInsets.all(12.0).add(const EdgeInsets.only(top: 12.0)),
        leftAction: NamidaButton(
          text: lang.search,
          onTap: openSearchDialog,
        ),
        actions: [
          Obx(
            (context) => CancelButtonDisabledRaw(
              disabled: _editingInProgress[singleTrack.path] == true,
            ),
          ),
          Obx(
            (context) => NamidaButton(
              enabled: canEditComment.valueR && _editingInProgress[singleTrack.path] != true,
              text: lang.save,
              isLoading: _editingInProgress[singleTrack.path] == true,
              onTap: confirmEdit,
            ),
          ),
        ],
        child: CustomTagTextField(
          controller: controller,
          hintText: ytlink,
          labelText: lang.link,
          keyboardType: TextInputType.url,
          onChanged: (value) {
            canEditComment.value = true;
          },
          validator: (value) {
            if (value!.isEmpty) {
              return lang.pleaseEnterAName;
            }
            if ((NamidaLinkRegex.youtubeLinkRegex.firstMatch(value) ?? '') == '') {
              return lang.pleaseEnterALinkSubtitle;
            }
            return null;
          },
        ),
      ),
    ),
  );

  if (autoOpenSearch) openSearchDialog();
}

Future<void> _editSingleTrackTagsDialog(PhysicalMedia track, Color? colorScheme, {bool instantEditArtwork = false}) async {
  if (!await requestManageStoragePermission(directoryToCreate: AppDirs.INTERNAL_STORAGE)) return;

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
          .getTrackDelightnedColor(track, null)
          .executeWithMinDelay(
            delayMS: NamidaNavigator.kDefaultDialogDurationMS,
          )
          .then(onColorsObtained);
    }
  }

  FTags? tags;
  Uint8List? artworkBytes = Uint8List.fromList([]);

  final infoFull = await NamidaTaggerController.inst.extractMetadata(
    trackPath: track.path,
    isVideo: track is Video,
    extractArtwork: true,
    saveArtworkToCache: false,
    isNetwork: false,
  );
  tags = infoFull.tags;
  artworkBytes = tags.artwork.bytes;
  if (infoFull.hasError) {
    final errorsMapLine = infoFull.errorsMap.isEmpty ? '' : "\n${infoFull.errorsMap}";
    snackyy(
      title: lang.error,
      message: "${lang.metadataReadFailed}$errorsMapLine",
      isError: true,
    );
  } else if (infoFull.errorsMap.isNotEmpty) {
    snackyy(title: lang.note, message: "${infoFull.errorsMap}");
  }

  final audioInfoFormatted = TrackExtended.buildAudioInfoFormatted(
    infoFull.durationMS ?? 0,
    await File(track.path).fileSize() ?? 0,
    infoFull.bitRate ?? 0,
    infoFull.sampleRate ?? 0,
    tags.gainData,
  );

  final canEditTags = false.obs;
  final didAutoExtractFromFilename = false.obs;
  final currentImagePath = ''.obs;

  TextEditingController? fieldToController(FTags tags, TagField f) {
    return switch (f) {
      TagField.title => TextEditingController(text: tags.title ?? ''),
      TagField.album => TextEditingController(text: tags.album ?? ''),
      TagField.artist => TextEditingController(text: tags.artist ?? ''),
      TagField.albumArtist => TextEditingController(text: tags.albumArtist ?? ''),
      TagField.genre => TextEditingController(text: tags.genre ?? ''),
      TagField.style => TextEditingController(text: tags.style ?? ''),
      TagField.composer => TextEditingController(text: tags.composer ?? ''),
      TagField.comment => TextEditingController(text: tags.comment ?? ''),
      TagField.description => TextEditingController(text: tags.description ?? ''),
      TagField.synopsis => TextEditingController(text: tags.synopsis ?? ''),
      TagField.lyrics => TextEditingController(text: tags.lyrics ?? ''),
      TagField.trackNumber => TextEditingController(text: tags.trackNumber.toIf('', '0')),
      TagField.discNumber => TextEditingController(text: tags.discNumber.toIf('', '0')),
      TagField.year => TextEditingController(text: tags.year.toIf('', '0')),
      TagField.remixer => TextEditingController(text: tags.remixer),
      TagField.trackTotal => TextEditingController(text: tags.trackTotal.toIf('', '0')),
      TagField.discTotal => TextEditingController(text: tags.discTotal ?? ''),
      TagField.lyricist => TextEditingController(text: tags.lyricist ?? ''),
      TagField.language => TextEditingController(text: tags.language ?? ''),
      TagField.recordLabel => TextEditingController(text: tags.recordLabel ?? ''),
      TagField.releaseType => TextEditingController(text: tags.releaseType ?? ''),
      TagField.country => TextEditingController(text: tags.country ?? ''),

      // -- in tag editor we aint knowing local db shi
      TagField.mood => TextEditingController(text: tags.mood ?? ''),
      TagField.tags => TextEditingController(text: tags.tags ?? ''),
      TagField.rating => TextEditingController(text: tags.ratingPercentage == null ? null : (tags.ratingPercentage! * 100).round().toString()),

      TagField.titleSort => TextEditingController(text: tags.sortInfo?.title ?? ''),
      TagField.albumSort => TextEditingController(text: tags.sortInfo?.album ?? ''),
      TagField.artistSort => TextEditingController(text: tags.sortInfo?.artist ?? ''),
      TagField.albumArtistSort => TextEditingController(text: tags.sortInfo?.albumArtist ?? ''),
      TagField.composerSort => TextEditingController(text: tags.sortInfo?.composer ?? ''),
    };
  }

  // -- filling fields
  final tagsControllers = <TagField, TextEditingController?>{for (final f in TagField.values) f: fieldToController(tags, f)};

  final editedTags = <TagField, String>{};

  final suggestionsProvider = TextSuggestionsProvider();

  Widget getTagTextField(TagField tag) {
    return _TagTextField(
      tag: tag,
      controller: tagsControllers[tag]!,
      suggestionsProvider: suggestionsProvider,
      onChanged: (value) {
        editedTags[tag] = value;
        canEditTags.value = true;
      },
    );
  }

  final formKey = GlobalKey<FormState>();

  Future<void> onArtworkEditTap() async {
    final pickedFile = await NamidaFileBrowser.pickFile(note: lang.editArtwork, memeType: NamidaStorageFileMemeType.image);
    final path = pickedFile?.path ?? '';
    if (pickedFile != null && path != '') {
      currentImagePath.value = path;
      canEditTags.value = true;
    }
  }

  if (instantEditArtwork) {
    // -- ensure dialog opened first
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => onArtworkEditTap(),
    );
  }

  await NamidaNavigator.inst.navigateDialog(
    onDisposing: () {
      color.close();
      canEditTags.close();
      didAutoExtractFromFilename.close();
      currentImagePath.close();
      for (final c in tagsControllers.values) {
        c?.dispose();
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
              title: lang.editTags,
              trailingWidgets: [
                _KeepDatesToggleWidget(
                  colorScheme: theme.colorScheme.secondary,
                ),
                NamidaIconButton(
                  icon: Broken.edit_2,
                  onPressed: () => NamidaNavigator.inst.navigateDialog(
                    scale: 1.0,
                    dialog: Theme(
                      data: theme,
                      child: CustomBlurryDialog(
                        theme: theme,
                        title: "${lang.tagFields} (${lang.reorderable})",
                        actions: const [
                          DoneButton(),
                        ],
                        child: SizedBox(
                          width: namida.width,
                          height: namida.height * 0.6,
                          child: NamidaReorderableActiveListView(
                            enumValues: TagField.values,
                            activeItems: settings.tagFieldsToEdit.value,
                            toText: (item) => item.toText(),
                            toIcon: (item) => item.toIcon(),
                            minimumItems: 3,
                            onSave: (activeItems) {
                              settings.tagFieldsToEdit.value = activeItems;
                              settings.save(tagFieldsToEdit: null);
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              actions: [
                Obx(
                  (context) => CancelButtonDisabledRaw(
                    disabled: _editingInProgress[track.path] == true,
                  ),
                ),
                Obx(
                  (context) => NamidaButton(
                    enabled: canEditTags.valueR && _editingInProgress[track.path] != true,
                    icon: Broken.pen_add,
                    text: lang.save,
                    isLoading: _editingInProgress[track.path] == true,
                    onTap: () async {
                      if (formKey.currentState!.validate() == false) return;

                      _editingInProgress[track.path] = true;
                      await NamidaTaggerController.inst
                          .updateTracksMetadata(
                            tracks: [track],
                            editedTags: editedTags,
                            imagePath: currentImagePath.value,
                            onEdit: (didUpdate, error, track) {
                              if (!didUpdate) {
                                snackyy(title: lang.metadataEditFailed, message: error ?? 'Unknown Error', isError: true);
                              }
                            },
                          )
                          .ignoreError();
                      _editingInProgress[track.path] = false;

                      NamidaNavigator.inst.closeDialog();
                    },
                  ),
                ),
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
                        child: SuperSmoothListView(
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
                                        extractInternally: false,
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
                                              onTap: onArtworkEditTap,
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
                                      ...tagFieldsToEdit
                                          .take(2)
                                          .map(
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
                            ...tagFieldsToEdit
                                .skip(2)
                                .map(
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
                        final titleAndArtist = FileMatcher.getTitleAndArtistFromFilename(track.filenameWOExt);
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
                              "${lang.autoExtractTagsFromFilename} ${didAutoExtractFromFilenameValue ? '✓' : ''}",
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
      },
    ),
  );
}

Future<void> _editMultipleTracksTags(List<PhysicalMedia> tracksPre, {required bool instantEditArtwork, required bool isAlbum}) async {
  if (!await requestManageStoragePermission(directoryToCreate: AppDirs.INTERNAL_STORAGE)) return;

  final tracksGoingToBeEditedRx = <PhysicalMedia, bool>{for (final t in tracksPre) t: true}.obs;

  final toBeEditedTracksColumn = Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 12.0),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Text(
          lang.multipleTracksTagsEditNote,
          style: namida.textTheme.displayMedium,
        ),
      ),
      const SizedBox(height: 12.0),
      SizedBox(
        width: namida.width,
        height: namida.height * 0.5,
        child: TrackTilePropertiesProvider(
          configs: TrackTilePropertiesConfigs(
            queueSource: QueueSource.others(null),
          ),
          builder: (properties) => ObxO(
            rx: tracksGoingToBeEditedRx,
            builder: (context, tracksGoingToBeEdited) {
              final list = tracksGoingToBeEdited.keys.toList();

              return SuperSmoothListView.builder(
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final tr = list[index];
                  final isSelected = tracksGoingToBeEdited[tr] == true;
                  return TrackTile(
                    properties: properties,
                    index: index,
                    trackOrTwd: tr,
                    tracks: list,
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

  List<PhysicalMedia> getSelectedTracks() => [
    for (final e in tracksGoingToBeEditedRx.value.entries)
      if (e.value) e.key,
  ];

  final canEditTags = false.obs;
  final currentImagePath = ''.obs;
  final autoTrackNumbersRx = false.obs;
  final showMoreFieldsRx = false.obs;

  final editedTags = <TagField, String>{};
  final hasEmptyDumbValues = false.obs;

  void onFieldEdit(TagField tag, String? value) {
    value == null ? editedTags.remove(tag) : editedTags[tag] = value;
    hasEmptyDumbValues.value = editedTags.values.any((element) => element.cleanUpForComparison == '');
    canEditTags.value = true;
  }

  final tracksExtended = tracksPre.map((e) => e.toTrackExt()).toList();
  final fieldsToEdit = <TagField>{
    ...settings.tagFieldsToEdit.value.where((f) => f.multiEditVisibility != _MultiEditFieldVisibility.hidden),
    ...TagField.values.where((f) => f.multiEditVisibility != _MultiEditFieldVisibility.hidden),
  };
  final multiFields = fieldsToEdit.map((f) => _MultiTagField.compute(f, tracksExtended, onFieldEdit)).toList();
  final visibleFields = <_MultiTagField>[];
  final collapsedFields = <_MultiTagField>[];
  for (final f in multiFields) {
    (f.isEmptyForAll && f.tag.multiEditVisibility == _MultiEditFieldVisibility.whenHasValues ? collapsedFields : visibleFields).add(f);
  }

  final statsEditor = TrackStatsEditController(tracksPre);
  statsEditor.addChangesListener(() => canEditTags.value = true);

  _MultiTracksEditPlan buildPlan() => _MultiTracksEditPlan.build(
    selectedTracks: getSelectedTracks(),
    editedTags: editedTags,
    fields: multiFields,
    statsEditor: statsEditor,
    autoTrackNumbers: autoTrackNumbersRx.value,
    imagePath: currentImagePath.value,
  );

  final suggestionsProvider = TextSuggestionsProvider();

  final formKey = GlobalKey<FormState>();

  Future<void> onArtworkEditTap() async {
    final pickedFile = await NamidaFileBrowser.pickFile(note: lang.editArtwork, memeType: NamidaStorageFileMemeType.image);
    final path = pickedFile?.path ?? '';
    if (pickedFile != null && path != '') {
      currentImagePath.value = path;
      canEditTags.value = true;
    }
  }

  if (instantEditArtwork) {
    // -- ensure dialog opened first
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => onArtworkEditTap(),
    );
  }

  await NamidaNavigator.inst.navigateDialog(
    onDisposing: () {
      tracksGoingToBeEditedRx.close();
      canEditTags.close();
      currentImagePath.close();
      autoTrackNumbersRx.close();
      showMoreFieldsRx.close();
      for (final f in multiFields) {
        f.dispose();
      }
      statsEditor.dispose();
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
        title: lang.editTags,
        trailingWidgets: [
          const _KeepDatesToggleWidget(),
        ],
        actions: [
          Obx(
            (context) => CancelButtonDisabledRaw(
              disabled: tracksGoingToBeEditedRx.valueR.keys.any((track) => _editingInProgress[track.path] == true),
            ),
          ),
          Obx(
            (context) {
              final isEditing = tracksGoingToBeEditedRx.valueR.keys.any((track) => _editingInProgress[track.path] == true);
              return NamidaButton(
                enabled: canEditTags.valueR && !isEditing,
                icon: Broken.pen_add,
                text: lang.save,
                isLoading: isEditing,
                onTap: () {
                  if (formKey.currentState!.validate() == false) return;

                  NamidaNavigator.inst.navigateDialog(
                    dialog: CustomBlurryDialog(
                      title: lang.note,
                      horizontalInset: 42.0,
                      verticalInset: 42.0,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
                      isWarning: true,
                      normalTitleStyle: true,
                      actions: [
                        NamidaButton(
                          text: lang.cancel,
                          onTap: () => NamidaNavigator.inst.closeDialog(),
                        ),
                        NamidaButton(
                          text: lang.confirm,
                          onTap: () async {
                            NamidaNavigator.inst.closeDialog();

                            final plan = buildPlan();
                            final tracksToEdit = plan.tracksToEdit;
                            for (final tr in tracksToEdit) {
                              _editingInProgress[tr.path] = true;
                            }

                            final successfullEdits = 0.obs;
                            final RxList<Track> failedEditsTracks = <Track>[].obs;
                            final finishedEditing = false.obs;
                            final updatingLibrary = '?'.obs;

                            void showFailedTracksDialogs() {
                              NamidaNavigator.inst.navigateDialog(
                                dialog: CustomBlurryDialog(
                                  contentPadding: EdgeInsets.zero,
                                  title: lang.failedEdits,
                                  actions: [
                                    NamidaButton(
                                      onTap: NamidaNavigator.inst.closeDialog,
                                      text: lang.confirm,
                                    ),
                                  ],
                                  child: SizedBox(
                                    height: namida.height * 0.5,
                                    width: namida.width,
                                    child: NamidaTracksList(
                                      infoBox: null,
                                      listBottomPadding: 0,
                                      queue: failedEditsTracks.value,
                                      queueLength: failedEditsTracks.length,
                                      queueSource: QueueSource.others(null),
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
                                  title: lang.progress,
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
                                        getText('${lang.succeeded}: ${successfullEdits.valueR}'),
                                        const SizedBox(height: 8.0),
                                        Obx(
                                          (context) => Row(
                                            children: [
                                              getText('${lang.failed}: ${failedEditsTracks.length}'),
                                              const SizedBox(width: 4.0),
                                              if (failedEditsTracks.isNotEmpty)
                                                TapDetector(
                                                  onTap: showFailedTracksDialogs,
                                                  child: getText(
                                                    lang.checkList,
                                                    style: namida.textTheme.displaySmall?.copyWith(
                                                      color: namida.theme.colorScheme.secondary,
                                                      decoration: TextDecoration.underline,
                                                      decorationStyle: TextDecorationStyle.solid,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 8.0),
                                        getText('${lang.updating} ${updatingLibrary.valueR}'),
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
                                  tracks: tracksToEdit,
                                  editedTags: plan.editedTags,
                                  editedTagsPerTrack: plan.editedTagsPerTrack,
                                  imagePath: plan.imagePath,
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
                                title: '${lang.metadataEditFailed} (${failedEditsTracks.length})',
                                message: errorMsg ?? '',
                                isError: true,
                              );
                            }
                            updatingLibrary.value = '✓';
                            finishedEditing.value = true;
                            canEditTags.value = false;

                            for (final tr in tracksToEdit) {
                              _editingInProgress[tr.path] = false;
                            }
                          },
                        ),
                      ],
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ObxO(
                            rx: tracksGoingToBeEditedRx,
                            builder: (context, _) => _MultiTracksEditSummary(
                              entries: buildPlan().summary,
                            ),
                          ),
                          toBeEditedTracksColumn,
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
        child: ObxO(
          rx: tracksGoingToBeEditedRx,
          builder: (context, tracksGoingToBeEditedAll) {
            final tracksGoingToBeEdited = tracksGoingToBeEditedAll.entries.where((element) => element.value).map((e) => e.key).toList();
            return tracksGoingToBeEdited.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: NamidaButton(
                      onTap: () {
                        NamidaNavigator.inst.navigateDialog(
                          dialog: CustomBlurryDialog(
                            title: lang.note,
                            horizontalInset: 42.0,
                            verticalInset: 42.0,
                            contentPadding: EdgeInsets.zero,
                            child: toBeEditedTracksColumn,
                          ),
                        );
                      },
                      text: tracksGoingToBeEdited.length.displayTrackKeyword,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutWidthProvider(
                        builder: (context, maxWidth) {
                          final imageWidth = maxWidth * 0.36;
                          final innerImageWidth = (imageWidth / 2) - 3.0;
                          return SizedBox(
                            height: namida.height * 0.7,
                            width: maxWidth,
                            child: SuperSmoothListView(
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
                                                  extractInternally: false,
                                                  fadeMilliSeconds: 0,
                                                  thumbnailSize: imageWidth,
                                                  path: currentImagePath.valueR,
                                                )
                                              : MultiArtworkContainer(
                                                  heroTag: 'edittags_artwork',
                                                  fadeMilliSeconds: 0,
                                                  size: imageWidth,
                                                  tracks: tracksGoingToBeEdited.toImageTracks(),
                                                  fallbackToFolderCover: false,
                                                  onTopWidget: tracksGoingToBeEdited.length > 3
                                                      ? Positioned(
                                                          right: 0,
                                                          bottom: 0,
                                                          child: NamidaBlurryContainer(
                                                            width: innerImageWidth,
                                                            height: innerImageWidth,
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
                                              onTap: () {
                                                NamidaNavigator.inst.navigateDialog(
                                                  dialog: CustomBlurryDialog(
                                                    title: lang.note,
                                                    horizontalInset: 42.0,
                                                    verticalInset: 42.0,
                                                    contentPadding: EdgeInsets.zero,
                                                    actions: [
                                                      NamidaButton(
                                                        text: lang.confirm,
                                                        onTap: NamidaNavigator.inst.closeDialog,
                                                      ),
                                                    ],
                                                    child: toBeEditedTracksColumn,
                                                  ),
                                                );
                                              },
                                              text: tracksGoingToBeEdited.length.displayTrackKeyword,
                                            ),
                                          ),
                                          const SizedBox(
                                            height: 8.0,
                                          ),
                                          SizedBox(
                                            width: namida.width,
                                            child: NamidaButton(
                                              text: lang.editArtwork,
                                              onTap: onArtworkEditTap,
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
                                if (isAlbum)
                                  ObxO(
                                    rx: autoTrackNumbersRx,
                                    builder: (context, autoTrackNumbers) => CustomSwitchListTile(
                                      icon: TagField.trackNumber.toIcon(),
                                      title: lang.autoTrackNumbers,
                                      subtitle: lang.autoTrackNumbersSubtitle,
                                      value: autoTrackNumbers,
                                      onChanged: (isTrue) {
                                        autoTrackNumbersRx.value = !isTrue;
                                        canEditTags.value = true;
                                      },
                                    ),
                                  ),
                                const SizedBox(
                                  height: 8.0,
                                ),
                                ...visibleFields.map(
                                  (f) => Padding(
                                    padding: const EdgeInsets.only(top: 10.0),
                                    child: _MultiTagTextField(
                                      field: f,
                                      suggestionsProvider: suggestionsProvider,
                                    ),
                                  ),
                                ),
                                if (collapsedFields.isNotEmpty)
                                  _MultiTagMoreFields(
                                    fields: collapsedFields,
                                    suggestionsProvider: suggestionsProvider,
                                    expandedRx: showMoreFieldsRx,
                                  ),
                                const SizedBox(
                                  height: 12.0,
                                ),
                                TrackStatsEditSections(
                                  controller: statsEditor,
                                ),
                                const SizedBox(
                                  height: 12.0,
                                ),
                              ],
                            ),
                          );
                        },
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
                                    TextSpan(text: "${lang.warning}: ", style: namida.textTheme.displayMedium),
                                    TextSpan(
                                      text: lang.emptyNonMeaningfulTagFields,
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

class _MultiTagField {
  final TagField tag;
  final String? commonValue;
  final bool hasMultipleValues;
  final List<TrackExtended> _tracks;
  final void Function(TagField tag, String? value) _onEdit;
  final TextEditingController controller;
  final clearForAllRx = false.obs;
  final replaceRuleRx = Rxn<_FindReplaceRule>();

  _MultiTagField._(this.tag, this.commonValue, this.hasMultipleValues, this._tracks, this._onEdit) : controller = TextEditingController(text: commonValue);

  factory _MultiTagField.compute(TagField tag, List<TrackExtended> tracks, void Function(TagField tag, String? value) onEdit) {
    String? commonValue;
    bool hasMultipleValues = false;
    for (final trExt in tracks) {
      final value = tag.libraryValueOf(trExt);
      if (value == null) break;
      if (commonValue == null) {
        commonValue = value;
      } else if (value != commonValue) {
        commonValue = null;
        hasMultipleValues = true;
        break;
      }
    }
    return _MultiTagField._(tag, commonValue, hasMultipleValues, tracks, onEdit);
  }

  bool get isUnknown => commonValue == null && !hasMultipleValues;

  bool get isEmptyForAll => !hasMultipleValues && (commonValue?.isEmpty ?? true);

  bool get isChanged => controller.text != (commonValue ?? '') || clearForAllRx.value || replaceRuleRx.value != null;

  bool get isClearing => clearForAllRx.value || (controller.text.isEmpty && commonValue?.isNotEmpty == true);

  String? get originalValueText {
    if (hasMultipleValues) return '<${lang.multipleValues}>';
    final value = commonValue;
    if (value == null) return null;
    return value.isEmpty ? '<${lang.emptyValue}>' : value;
  }

  String hintTextFor({required bool clearForAll, required _FindReplaceRule? replaceRule}) {
    if (replaceRule != null) return replaceRule.description;
    if (clearForAll) return '<${lang.emptyValue}>';
    if (hasMultipleValues) return '<${lang.multipleValues}>';
    return commonValue?.isNotEmpty == true ? '<${lang.emptyValue}>' : '';
  }

  String describeEdit(String newValue) {
    final newText = newValue.isEmpty ? '<${lang.emptyValue}>' : newValue;
    final oldText = originalValueText;
    return oldText == null ? newText : '$oldText → $newText';
  }

  late final Map<String, int> valuesCounts = _computeValuesCounts();

  late final List<MapEntry<String, int>> nonEmptyValuesByCount = valuesCounts.entries.where((e) => e.key.isNotEmpty).toList()..sort((a, b) => b.value.compareTo(a.value));

  Map<String, int> _computeValuesCounts() {
    final counts = <String, int>{};
    for (final trExt in _tracks) {
      final value = tag.libraryValueOf(trExt);
      if (value != null) counts.update(value, (c) => c + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  void onChanged(String text) {
    clearForAllRx.value = false;
    replaceRuleRx.value = null;
    final initialText = commonValue ?? '';
    _onEdit(tag, text == initialText ? null : text);
  }

  void apply(String value) {
    controller.text = value;
    onChanged(value);
  }

  void clearForAll() {
    controller.clear();
    clearForAllRx.value = commonValue == null;
    replaceRuleRx.value = null;
    _onEdit(tag, commonValue == '' ? null : '');
  }

  void setReplaceRule(_FindReplaceRule rule) {
    controller.clear();
    clearForAllRx.value = false;
    replaceRuleRx.value = rule;
    _onEdit(tag, null);
  }

  void undo() {
    controller.text = commonValue ?? '';
    clearForAllRx.value = false;
    replaceRuleRx.value = null;
    _onEdit(tag, null);
  }

  void dispose() {
    controller.dispose();
    clearForAllRx.close();
    replaceRuleRx.close();
  }
}

class _MultiTracksEditPlan {
  final List<PhysicalMedia> tracksToEdit;
  final Map<TagField, String> editedTags;
  final Map<Track, Map<TagField, String>> editedTagsPerTrack;
  final String imagePath;
  final List<_MultiTracksEditSummaryEntry> summary;

  const _MultiTracksEditPlan._({
    required this.tracksToEdit,
    required this.editedTags,
    required this.editedTagsPerTrack,
    required this.imagePath,
    required this.summary,
  });

  factory _MultiTracksEditPlan.build({
    required List<PhysicalMedia> selectedTracks,
    required Map<TagField, String> editedTags,
    required List<_MultiTagField> fields,
    required TrackStatsEditController statsEditor,
    required bool autoTrackNumbers,
    required String imagePath,
  }) {
    final summary = <_MultiTracksEditSummaryEntry>[];
    final editedTagsPerTrack = statsEditor.buildEditedTagsPerTrack(selectedTracks);
    late final selectedTracksExt = selectedTracks.map((e) => e.toTrackExt()).toList();

    if (imagePath.isNotEmpty) {
      summary.add(_MultiTracksEditSummaryEntry(icon: Broken.gallery_edit, title: lang.artwork, subtitle: lang.changed));
    }

    for (final field in fields) {
      final tag = field.tag;
      final editedValue = editedTags[tag];
      if (editedValue != null) {
        summary.add(_MultiTracksEditSummaryEntry(icon: tag.toIcon(), title: tag.toText(), subtitle: field.describeEdit(editedValue)));
        continue;
      }
      final replaceRule = field.replaceRuleRx.value;
      if (replaceRule == null) continue;
      int changedCount = 0;
      for (int i = 0; i < selectedTracks.length; i++) {
        final oldValue = tag.libraryValueOf(selectedTracksExt[i]);
        if (oldValue == null) continue;
        final newValue = replaceRule.apply(oldValue);
        if (newValue == oldValue) continue;
        (editedTagsPerTrack[selectedTracks[i]] ??= {})[tag] = newValue;
        changedCount++;
      }
      summary.add(_MultiTracksEditSummaryEntry(icon: tag.toIcon(), title: tag.toText(), subtitle: replaceRule.description, tracksCount: changedCount));
    }

    if (autoTrackNumbers) {
      final groupByDisc = !editedTags.containsKey(TagField.discNumber);
      final discTotals = <int, int>{};
      for (final trExt in selectedTracksExt) {
        discTotals.update(groupByDisc ? trExt.discNo : 0, (c) => c + 1, ifAbsent: () => 1);
      }
      final discCounters = <int, int>{};
      int changedCount = 0;
      for (int i = 0; i < selectedTracks.length; i++) {
        final trExt = selectedTracksExt[i];
        final disc = groupByDisc ? trExt.discNo : 0;
        final number = discCounters.update(disc, (c) => c + 1, ifAbsent: () => 1);
        final total = discTotals[disc]!;
        if (trExt.trackNo == number && trExt.trackTo == total) continue;
        final trackEditedTags = editedTagsPerTrack[selectedTracks[i]] ??= {};
        trackEditedTags[TagField.trackNumber] = number.toString();
        trackEditedTags[TagField.trackTotal] = total.toString();
        changedCount++;
      }
      summary.add(
        _MultiTracksEditSummaryEntry(
          icon: TagField.trackNumber.toIcon(),
          title: lang.autoTrackNumbers,
          subtitle: discTotals.values.map((total) => '1 → $total').join(', '),
          tracksCount: changedCount,
        ),
      );
    }

    for (final (tag, changesText) in [
      (TagField.mood, statsEditor.moodsChangesText),
      (TagField.tags, statsEditor.tagsChangesText),
      (TagField.rating, statsEditor.ratingChangesText),
    ]) {
      if (changesText == null) continue;
      final changedCount = editedTagsPerTrack.values.where((e) => e.containsKey(tag)).length;
      summary.add(_MultiTracksEditSummaryEntry(icon: tag.toIcon(), title: tag.toText(), subtitle: changesText, tracksCount: changedCount));
    }

    final hasEditsForAll = editedTags.isNotEmpty || imagePath.isNotEmpty;
    return _MultiTracksEditPlan._(
      tracksToEdit: hasEditsForAll ? selectedTracks : selectedTracks.where(editedTagsPerTrack.containsKey).toList(),
      editedTags: editedTags,
      editedTagsPerTrack: editedTagsPerTrack,
      imagePath: imagePath,
      summary: summary,
    );
  }
}

void _showFindReplaceDialog(_MultiTagField field) {
  final currentRule = field.replaceRuleRx.value;
  final filterRx = (currentRule?.filter ?? SmartPlaylistRuleFilterText.contains).obs;
  final findController = TextEditingController(text: currentRule?.find);
  final replaceController = TextEditingController(text: currentRule?.replaceWith);
  final matchCaseRx = (currentRule?.matchCase ?? false).obs;
  final inputsListenable = Listenable.merge([filterRx, findController, replaceController, matchCaseRx]);

  _FindReplaceRule buildRule() => _FindReplaceRule(
    filter: filterRx.value,
    find: findController.text,
    replaceWith: replaceController.text,
    matchCase: matchCaseRx.value,
  );

  void onConfirm() {
    final rule = buildRule();
    if (!rule.isValid) return;
    field.setReplaceRule(rule);
    NamidaNavigator.inst.closeDialog();
  }

  NamidaNavigator.inst.navigateDialog(
    onDisposing: () {
      filterRx.close();
      findController.dispose();
      replaceController.dispose();
      matchCaseRx.close();
    },
    dialog: CustomBlurryDialog(
      icon: Broken.convert,
      title: '${lang.findAndReplace} (${field.tag.toText()})',
      normalTitleStyle: true,
      actions: [
        const CancelButton(),
        NamidaButton(
          text: lang.confirm,
          onTap: onConfirm,
        ),
      ],
      child: ObxO(
        rx: filterRx,
        builder: (context, filter) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NamidaPopupWrapper(
              children: () => SmartPlaylistRuleFilterText.values.map(
                (f) => _FindReplaceFilterItem(
                  filter: f,
                  selected: f == filter,
                  onTap: () {
                    filterRx.value = f;
                    NamidaNavigator.inst.popMenu();
                  },
                ),
              ),
              child: CustomListTile(
                icon: Broken.filter_square,
                title: lang.filterType,
                trailing: SmartPlaylistFilterInfoRow(
                  filter: filter,
                ),
              ),
            ),
            if (filter.requiresDataField) ...[
              const SizedBox(
                height: 12.0,
              ),
              CustomTagTextField(
                key: const ValueKey('find'),
                controller: findController,
                hintText: filter.isRegex() ? '(.*)' : '',
                labelText: lang.find,
                icon: Broken.search_normal,
                autofocus: true,
              ),
            ],
            const SizedBox(
              height: 12.0,
            ),
            CustomTagTextField(
              key: const ValueKey('replace'),
              controller: replaceController,
              hintText: filter.isRegex() ? r'$1' : '',
              labelText: lang.replaceWith,
              icon: field.tag.toIcon(),
            ),
            if (filter.requiresDataField) ...[
              const SizedBox(
                height: 6.0,
              ),
              ObxO(
                rx: matchCaseRx,
                builder: (context, matchCase) => CustomSwitchListTile(
                  icon: Broken.text,
                  title: lang.matchCase,
                  value: matchCase,
                  onChanged: (isTrue) => matchCaseRx.value = !isTrue,
                ),
              ),
            ],
            const SizedBox(
              height: 6.0,
            ),
            _FindReplacePreview(
              field: field,
              listenable: inputsListenable,
              buildRule: buildRule,
            ),
          ],
        ),
      ),
    ),
  );
}

class _FindReplaceRule {
  final SmartPlaylistRuleFilterText filter;
  final String find;
  final String replaceWith;
  final bool matchCase;

  _FindReplaceRule({
    required this.filter,
    required this.find,
    required this.replaceWith,
    required this.matchCase,
  });

  static final _groupReferenceRegex = RegExp(r'\$(\d+)');

  late final RegExp? _regex = _buildRegex();

  bool get isValid => !filter.requiresDataField || _regex != null;

  RegExp? _buildRegex() {
    if (find.isEmpty) return null;
    final escaped = RegExp.escape(find);
    final pattern = switch (filter) {
      SmartPlaylistRuleFilterText.isSame || SmartPlaylistRuleFilterText.isNotSame => '^$escaped\$',
      SmartPlaylistRuleFilterText.contains || SmartPlaylistRuleFilterText.notContains => escaped,
      SmartPlaylistRuleFilterText.startsWith => '^$escaped',
      SmartPlaylistRuleFilterText.endsWith => '$escaped\$',
      SmartPlaylistRuleFilterText.regexMatch || SmartPlaylistRuleFilterText.regexNotMatch => find,
      SmartPlaylistRuleFilterText.exists || SmartPlaylistRuleFilterText.missing => null,
    };
    if (pattern == null) return null;
    try {
      return RegExp(pattern, caseSensitive: matchCase);
    } on FormatException {
      return null;
    }
  }

  String apply(String value) {
    final regex = _regex;
    return switch (filter) {
      SmartPlaylistRuleFilterText.isSame ||
      SmartPlaylistRuleFilterText.contains ||
      SmartPlaylistRuleFilterText.startsWith ||
      SmartPlaylistRuleFilterText.endsWith => regex == null ? value : value.replaceAll(regex, replaceWith),
      SmartPlaylistRuleFilterText.regexMatch => regex == null ? value : value.replaceAllMapped(regex, _expandGroupReferences),
      SmartPlaylistRuleFilterText.isNotSame ||
      SmartPlaylistRuleFilterText.notContains ||
      SmartPlaylistRuleFilterText.regexNotMatch => regex == null || regex.hasMatch(value) ? value : replaceWith,
      SmartPlaylistRuleFilterText.exists => value.isEmpty ? value : replaceWith,
      SmartPlaylistRuleFilterText.missing => value.isEmpty ? replaceWith : value,
    };
  }

  String _expandGroupReferences(Match match) => replaceWith.replaceAllMapped(
    _groupReferenceRegex,
    (reference) {
      final groupIndex = int.parse(reference[1]!);
      return groupIndex <= match.groupCount ? match[groupIndex] ?? '' : reference[0]!;
    },
  );

  String get description => filter.requiresDataField ? '${filter.toText()} "$find" → "$replaceWith"' : '${filter.toText()} → "$replaceWith"';
}

class _MultiTracksEditSummaryEntry {
  final IconData icon;
  final String title;
  final String subtitle;
  final int? tracksCount;

  const _MultiTracksEditSummaryEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.tracksCount,
  });
}

class _KeepDatesToggleWidget extends StatelessWidget {
  final Color? colorScheme;
  const _KeepDatesToggleWidget({this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: settings.editTagsKeepFileDates,
      builder: (context, editTagsKeepFileDates) => NamidaIconButton(
        tooltip: () => lang.keepFileDates,
        icon: editTagsKeepFileDates ? Broken.document_code_2 : Broken.calendar_edit,
        onPressed: () {
          settings.save(editTagsKeepFileDates: !settings.editTagsKeepFileDates.value);
        },
        child: StackedIcon(
          baseIcon: Broken.document_code_2,
          secondaryIcon: editTagsKeepFileDates ? Broken.tick_circle : Broken.close_circle,
          baseIconColor: colorScheme,
          secondaryIconColor: colorScheme,
        ),
      ),
    );
  }
}

class _TagTextField extends StatelessWidget {
  final TagField tag;
  final TextEditingController controller;
  final TextSuggestionsProvider suggestionsProvider;
  final void Function(String value) onChanged;
  final String? hintText;
  final Widget? suffixIcon;
  final bool markChanged;

  const _TagTextField({
    required this.tag,
    required this.controller,
    required this.suggestionsProvider,
    required this.onChanged,
    this.hintText,
    this.suffixIcon,
    this.markChanged = false,
  });

  Widget _buildField(FocusNode? focusNode) {
    return CustomTagTextField(
      controller: controller,
      focusNode: focusNode,
      labelText: tag.toText(),
      hintText: hintText ?? controller.text,
      icon: tag.toIcon(),
      suffixIcon: suffixIcon,
      markChanged: markChanged,
      onChanged: onChanged,
      validator: tag == TagField.rating ? _ratingsValidator : null,
      isNumeric: tag.isNumeric,
      maxLines: tag == TagField.comment || tag == TagField.description || tag == TagField.synopsis ? 4 : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final suggestionsSource = tag.toSuggestionsSource();
    if (suggestionsSource == null) return _buildField(null);
    return TextFieldSuggestionsDropdown(
      provider: suggestionsProvider,
      source: suggestionsSource,
      controller: controller,
      onChanged: onChanged,
      builder: (context, focusNode) => _buildField(focusNode),
    );
  }
}

class _MultiTagTextField extends StatelessWidget {
  final _MultiTagField field;
  final TextSuggestionsProvider suggestionsProvider;

  const _MultiTagTextField({
    required this.field,
    required this.suggestionsProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) {
        final clearForAll = field.clearForAllRx.valueR;
        final replaceRule = field.replaceRuleRx.valueR;
        return _TagTextField(
          tag: field.tag,
          controller: field.controller,
          suggestionsProvider: suggestionsProvider,
          onChanged: field.onChanged,
          hintText: field.hintTextFor(
            clearForAll: clearForAll,
            replaceRule: replaceRule,
          ),
          suffixIcon: _MultiTagFieldMenuButton(
            field: field,
          ),
          markChanged: clearForAll || replaceRule != null,
        );
      },
    );
  }
}

class _MultiTagMoreFields extends StatelessWidget {
  final List<_MultiTagField> fields;
  final TextSuggestionsProvider suggestionsProvider;
  final Rx<bool> expandedRx;

  const _MultiTagMoreFields({
    required this.fields,
    required this.suggestionsProvider,
    required this.expandedRx,
  });

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: expandedRx,
      builder: (context, expanded) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NamidaInkWell(
            margin: const EdgeInsets.only(top: 10.0),
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
            borderRadius: 12.0,
            onTap: () => expandedRx.value = !expanded,
            child: Row(
              children: [
                Icon(
                  expanded ? Broken.arrow_up_3 : Broken.arrow_down_2,
                  size: 18.0,
                ),
                const SizedBox(
                  width: 8.0,
                ),
                Expanded(
                  child: Text(
                    '${lang.more} (${fields.length})',
                    style: context.textTheme.displayMedium,
                  ),
                ),
              ],
            ),
          ),
          if (expanded)
            ...fields.map(
              (f) => Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: _MultiTagTextField(
                  field: f,
                  suggestionsProvider: suggestionsProvider,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FindReplacePreview extends StatelessWidget {
  final _MultiTagField field;
  final Listenable listenable;
  final _FindReplaceRule Function() buildRule;

  const _FindReplacePreview({
    required this.field,
    required this.listenable,
    required this.buildRule,
  });

  static const _maxExamples = 3;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) {
        final rule = buildRule();
        if (!rule.isValid) {
          if (rule.find.isEmpty) return const SizedBox();
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(
              '${lang.error}: Regex',
              style: textTheme.displayMedium,
            ),
          );
        }
        int changedCount = 0;
        final examples = <String>[];
        for (final e in field.valuesCounts.entries) {
          final value = e.key;
          final newValue = rule.apply(value);
          if (newValue == value) continue;
          changedCount += e.value;
          if (examples.length < _maxExamples) examples.add('${value.isEmpty ? '<${lang.emptyValue}>' : value} → $newValue');
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                changedCount.displayTrackKeyword,
                style: textTheme.displayMedium,
              ),
              ...examples.map(
                (e) => Text(
                  e,
                  style: textTheme.displaySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FindReplaceFilterItem extends StatelessWidget {
  final SmartPlaylistRuleFilterText filter;
  final bool selected;
  final VoidCallback onTap;

  const _FindReplaceFilterItem({
    required this.filter,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 1.0),
      child: NamidaInkWell(
        borderRadius: 8.0,
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        bgColor: selected ? context.theme.colorScheme.secondary.withOpacityExt(0.1) : null,
        onTap: onTap,
        child: SmartPlaylistFilterInfoRow(
          filter: filter,
        ),
      ),
    );
  }
}

class _MultiTracksEditSummary extends StatelessWidget {
  final List<_MultiTracksEditSummaryEntry> entries;

  const _MultiTracksEditSummary({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox();
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: namida.height * 0.3),
      child: SuperSmoothListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 6.0),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          final tracksCount = entry.tracksCount;
          return CustomListTile(
            icon: entry.icon,
            title: entry.title,
            subtitle: entry.subtitle,
            maxSubtitleLines: 3,
            trailingText: tracksCount?.displayTrackKeyword,
          );
        },
      ),
    );
  }
}

class _MultiTagFieldMenuButton extends StatelessWidget {
  final _MultiTagField field;

  const _MultiTagFieldMenuButton({required this.field});

  static const _maxValuesShown = 50;

  @override
  Widget build(BuildContext context) {
    return NamidaPopupWrapper(
      openOnLongPress: false,
      childrenDefault: () {
        final currentText = field.controller.text;
        final countStyle = context.textTheme.displaySmall;
        final values = field.hasMultipleValues ? field.nonEmptyValuesByCount : const <MapEntry<String, int>>[];
        return [
          NamidaPopupItem(
            icon: Broken.undo,
            title: lang.undo,
            subtitle: field.originalValueText ?? '',
            enabled: field.isChanged,
            onTap: field.undo,
          ),
          NamidaPopupItem(
            icon: Broken.eraser,
            title: lang.clear,
            subtitle: '<${lang.emptyValue}>',
            enabled: field.commonValue != '',
            selected: field.isClearing,
            onTap: field.clearForAll,
          ),
          if (!field.isUnknown)
            NamidaPopupItem(
              icon: Broken.convert,
              title: lang.findAndReplace,
              subtitle: field.replaceRuleRx.value?.description ?? '',
              selected: field.replaceRuleRx.value != null,
              onTap: () => _showFindReplaceDialog(field),
            ),
          ...values
              .take(_maxValuesShown)
              .map(
                (e) => NamidaPopupItem(
                  icon: field.tag.toIcon(),
                  title: e.key,
                  titleBuilder: (style) => Text(
                    e.key,
                    style: style,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    '${e.value}',
                    style: countStyle,
                  ),
                  selected: e.key == currentText,
                  onTap: () => field.apply(e.key),
                ),
              ),
          if (values.length > _maxValuesShown)
            NamidaPopupItem(
              icon: Broken.more,
              title: '+${values.length - _maxValuesShown}',
              enabled: false,
              onTap: () {},
            ),
        ];
      },
      child: Container(
        color: Colors.transparent,
        height: 42.0,
        padding: const EdgeInsets.only(left: 6.0, right: 14.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Broken.arrow_down_2,
              size: 16.0,
            ),
            const SizedBox(
              width: 8.0,
            ),
            Icon(
              field.tag.toIcon(),
              size: 18.0,
            ),
          ],
        ),
      ),
    );
  }
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
  final bool autofocus;
  final bool obscureText;
  final Widget? suffixIcon;
  final bool markChanged;

  const CustomTagTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.icon,
    this.suffixIcon,
    this.markChanged = false,
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
    this.autofocus = false,
    this.obscureText = false,
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
    widget.controller.addListener(_onControllerTextChanged);
  }

  @override
  void didUpdateWidget(covariant CustomTagTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerTextChanged);
      widget.controller.addListener(_onControllerTextChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerTextChanged);
    super.dispose();
  }

  /// listening to the controller instead of `onChanged` to catch programmatic changes too.
  void _onControllerTextChanged() {
    final isDifferent = initialText != widget.controller.text;
    if (isDifferent != didChange) {
      setState(() => didChange = isDifferent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final borderR = widget.borderRadius.multipliedRadius;
    final borderRS = (widget.borderRadius - 2.0).withMinimum(0).multipliedRadius;
    return TextFormField(
      obscureText: widget.obscureText,
      onTap: widget.onTap,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      validator: widget.validator,
      maxLength: widget.maxLength,
      controller: widget.controller,
      textAlign: TextAlign.left,
      maxLines: widget.maxLines,
      autovalidateMode: widget.validatorMode,
      keyboardType: widget.keyboardType ?? (widget.isNumeric ? TextInputType.number : null),
      style: textTheme.displaySmall?.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600),
      // onTapOutside: (event) => FocusScope.of(context).unfocus(), // inconvenient
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      decoration: InputDecoration(
        label: widget.labelText != '' ? Text('${widget.labelText} ${didChange || widget.markChanged ? '(${lang.changed})' : ''}') : null,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintMaxLines: widget.hintMaxLines,
        contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        errorMaxLines: 3,
        suffixIcon: widget.suffixIcon ?? Icon(widget.icon, size: 18.0),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRS),
          borderSide: BorderSide(color: theme.colorScheme.onSurface.withAlpha(100), width: 2.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderR),
          borderSide: BorderSide(color: theme.colorScheme.onSurface.withAlpha(100), width: 1.0),
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
        hintStyle: textTheme.displaySmall?.copyWith(fontSize: 14.5, color: textTheme.displaySmall?.color?.withAlpha(120)),
      ),
    );
  }
}

String? _ratingsValidator(String? value) {
  if (value == null || value.isEmpty) return null;
  final intval = int.tryParse(value);
  if (intval == null) return lang.nameContainsBadCharacter;
  if (intval < 0 || intval > 100) return '0-100';
  return null;
}

extension _TagFieldMultiEdit on TagField {
  _MultiEditFieldVisibility get multiEditVisibility => switch (this) {
    TagField.artist ||
    TagField.album ||
    TagField.albumArtist ||
    TagField.composer ||
    TagField.genre ||
    TagField.style ||
    TagField.year ||
    TagField.discNumber ||
    TagField.comment ||
    TagField.description ||
    TagField.synopsis ||
    TagField.trackTotal ||
    TagField.discTotal => _MultiEditFieldVisibility.always,
    TagField.remixer ||
    TagField.lyricist ||
    TagField.language ||
    TagField.recordLabel ||
    TagField.releaseType ||
    TagField.country ||
    TagField.albumSort ||
    TagField.albumArtistSort ||
    TagField.artistSort ||
    TagField.composerSort => _MultiEditFieldVisibility.whenHasValues,
    TagField.title || TagField.trackNumber || TagField.lyrics || TagField.titleSort => _MultiEditFieldVisibility.hidden,
    TagField.mood || TagField.tags || TagField.rating => _MultiEditFieldVisibility.hidden, // -- edited by TrackStatsEditSections
  };

  String? libraryValueOf(TrackExtended trExt) => switch (this) {
    TagField.title => trExt.title,
    TagField.artist => _emptyIfUnknown(trExt.originalArtist, UnknownTags.ARTIST),
    TagField.album => _emptyIfUnknown(trExt.originalAlbum, UnknownTags.ALBUM),
    TagField.albumArtist => _emptyIfUnknown(trExt.albumArtist, UnknownTags.ALBUMARTIST),
    TagField.composer => _emptyIfUnknown(trExt.composer, UnknownTags.COMPOSER),
    TagField.genre => _emptyIfUnknown(trExt.originalGenre, UnknownTags.GENRE),
    TagField.style => _emptyIfUnknown(trExt.originalStyle, UnknownTags.STYLE),
    TagField.mood => _emptyIfUnknown(trExt.originalMood, UnknownTags.MOOD),
    TagField.year => trExt.yearText.isNotEmpty && trExt.yearText != '0' ? trExt.yearText : _emptyIfZero(trExt.year),
    TagField.trackNumber => _emptyIfZero(trExt.trackNo),
    TagField.discNumber => _emptyIfZero(trExt.discNo),
    TagField.comment => trExt.comment,
    TagField.description => trExt.description,
    TagField.synopsis => trExt.synopsis,
    TagField.lyrics => trExt.lyrics,
    TagField.trackTotal => _emptyIfZero(trExt.trackTo),
    TagField.discTotal => _emptyIfZero(trExt.discTo),
    TagField.language => trExt.language,
    TagField.recordLabel => trExt.label,
    TagField.releaseType => trExt.releaseType,
    TagField.rating => _emptyIfZero(trExt.effectiveRating),
    TagField.tags => trExt.originalTags ?? '',
    TagField.titleSort => trExt.sortInfo?.title ?? '',
    TagField.albumSort => trExt.sortInfo?.album ?? '',
    TagField.albumArtistSort => trExt.sortInfo?.albumArtist ?? '',
    TagField.artistSort => trExt.sortInfo?.artist ?? '',
    TagField.composerSort => trExt.sortInfo?.composer ?? '',
    TagField.remixer || TagField.lyricist || TagField.country => null,
  };

  static String _emptyIfUnknown(String value, String unknown) => value == unknown ? '' : value;
  static String _emptyIfZero(int value) => value == 0 ? '' : value.toString();
}

enum _MultiEditFieldVisibility {
  always,
  whenHasValues,
  hidden,
}
