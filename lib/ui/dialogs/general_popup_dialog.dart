import 'dart:io';

import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:namida/class/folder.dart';
import 'package:namida/class/queue.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/edit_delete_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/dialogs/add_to_playlist_dialog.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/dialogs/track_clear_dialog.dart';
import 'package:namida/ui/dialogs/track_info_dialog.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/multi_artwork_container.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';

Future<void> showGeneralPopupDialog(
  List<Track> tracks,
  String title,
  String subtitle,
  QueueSource source, {
  void Function()? onTopBarTap,
  String? playlistName,
  TrackWithDate? trackWithDate,
  Queue? queue,
  int? index,
  String thirdLineText = '',
  bool forceSquared = false,
  bool? forceSingleArtwork,
  bool extractColor = true,
  bool comingFromQueue = false,
  bool useTrackTileCacheHeight = false,
  bool isCircle = false,
  bool isFromPlayerQueue = false,
  bool errorPlayingTrack = false,
  String? artistToAddFrom,
  String? albumToAddFrom,
  String? heroTag,
}) async {
  final tracksExisting = <Track>[];
  tracks.loop((t, index) {
    final existingTrack = t.path.toTrackOrNull();
    if (existingTrack != null) tracksExisting.add(existingTrack);
  });

  forceSingleArtwork ??= tracks.length == 1;
  final isSingle = tracks.length == 1;
  final doesTracksExist = !errorPlayingTrack && tracksExisting.isNotEmpty;

  final trackToExtractColorFrom = forceSingleArtwork ? tracks[tracks.indexOfImage] : tracks.first;
  final colorDelightened = extractColor ? await CurrentColor.inst.getTrackDelightnedColor(trackToExtractColorFrom) : CurrentColor.inst.color.value;

  final List<String> availableAlbums = tracks.map((e) => e.album).toSet().toList();
  final List<String> availableArtists = tracks.map((e) => e.artistsList).expand((list) => list).toSet().toList();
  final List<Folder> availableFolders = tracks.map((e) => e.folder).toSet().toList();

  RxInt numberOfRepeats = 1.obs;
  RxBool isLoadingFilesToShare = false.obs;

  final iconColor = Color.alphaBlend(colorDelightened.withAlpha(120), Get.textTheme.displayMedium!.color!);

  bool shoulShowPlaylistUtils() => trackWithDate == null && playlistName != null && !PlaylistController.inst.isOneOfDefaultPlaylists(playlistName);
  bool shoulShowRemoveFromPlaylist() => trackWithDate != null && index != null && playlistName != null && playlistName != k_PLAYLIST_NAME_MOST_PLAYED;

  Widget bigIcon(IconData icon, String tooltipMessage, void Function()? onTap, {String subtitle = '', Widget? iconWidget}) {
    return NamidaInkWell(
      onTap: onTap,
      borderRadius: 8.0,
      child: Tooltip(
        message: tooltipMessage,
        preferBelow: false,
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            children: [
              iconWidget ??
                  Icon(
                    icon,
                    color: iconColor,
                  ),
              if (subtitle != '') ...[
                const SizedBox(height: 2.0),
                Text(
                  subtitle,
                  style: Get.textTheme.displaySmall?.copyWith(fontSize: 12.0.multipliedFontScale),
                  maxLines: 1,
                )
              ]
            ],
          ),
        ),
      ),
    );
  }

  void setMoodsOrTags(List<String> initialMoods, void Function(List<String> moodsFinal) saveFunction, {bool isTags = false}) {
    TextEditingController controller = TextEditingController();
    final currentMoods = initialMoods.join(', ');
    controller.text = currentMoods;

    final title = isTags ? Language.inst.SET_TAGS : Language.inst.SET_MOODS;
    final subtitle = Language.inst.SET_MOODS_SUBTITLE;
    NamidaNavigator.inst.navigateDialog(
      CustomBlurryDialog(
        title: title,
        actions: [
          const CancelButton(),
          ElevatedButton(
            onPressed: () async {
              List<String> moodsPre = controller.text.split(',');
              List<String> moodsFinal = [];
              moodsPre.loop((m, index) {
                if (!m.contains(',') && m != ' ' && m.isNotEmpty) {
                  moodsFinal.add(m.trim());
                }
              });

              saveFunction(moodsFinal.toSet().toList());

              NamidaNavigator.inst.closeDialog();
            },
            child: Text(Language.inst.SAVE),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subtitle,
              style: Get.textTheme.displaySmall,
            ),
            const SizedBox(
              height: 20.0,
            ),
            CustomTagTextField(
              controller: controller,
              hintText: currentMoods.overflow,
              labelText: title,
            ),
          ],
        ),
      ),
    );
  }

  void setPlaylistMoods() {
    // function button won't be visible if playlistName == null.
    if (!shoulShowPlaylistUtils()) return;

    final pl = PlaylistController.inst.getPlaylist(playlistName!);
    if (pl == null) return;
    setMoodsOrTags(
      pl.moods,
      (moodsFinal) => PlaylistController.inst.updatePropertyInPlaylist(playlistName, moods: moodsFinal.toSet().toList()),
    );
  }

  Rx<TrackStats> stats = tracks.first.stats.obs;

  Future<void> saveStatsToFile() async {
    stats.refresh();
    Indexer.inst.trackStatsMap[tracks.first.path] = TrackStats(tracks.first.path, stats.value.rating, stats.value.tags, stats.value.moods, stats.value.lastPositionInMs);
    tracks.first.stats = stats.value;
    await Indexer.inst.saveTrackStatsFileToStorage();
  }

  void setTrackMoods() {
    setMoodsOrTags(
      stats.value.moods,
      (moodsFinal) async {
        stats.value.moods.addAll(moodsFinal);
        await saveStatsToFile();
      },
    );
  }

  void setTrackTags() {
    setMoodsOrTags(
      stats.value.tags,
      (moodsFinal) async {
        stats.value.tags.addAll(moodsFinal);
        await saveStatsToFile();
      },
      isTags: true,
    );
  }

  void setTrackRating() {
    final c = TextEditingController();
    NamidaNavigator.inst.navigateDialog(
      CustomBlurryDialog(
        title: Language.inst.SET_RATING,
        actions: [
          const CancelButton(),
          ElevatedButton(
            onPressed: () async {
              NamidaNavigator.inst.closeDialog();
              final val = int.tryParse(c.text) ?? 0;
              stats.value.rating = val.clamp(0, 100);
              await saveStatsToFile();
            },
            child: Text(Language.inst.SAVE),
          ),
        ],
        child: CustomTagTextField(
          controller: c,
          hintText: stats.value.rating.toString(),
          labelText: Language.inst.SET_RATING,
          keyboardType: TextInputType.number,
        ),
      ),
    );
  }

  void renamePlaylist() {
    // function button won't be visible if playlistName == null.
    if (!shoulShowPlaylistUtils()) return;

    TextEditingController controller = TextEditingController(text: playlistName);
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    NamidaNavigator.inst.navigateDialog(
      Form(
        key: formKey,
        child: CustomBlurryDialog(
          title: Language.inst.RENAME_PLAYLIST,
          actions: [
            const CancelButton(),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  await PlaylistController.inst.renamePlaylist(playlistName!, controller.text);
                  NamidaNavigator.inst.closeDialog();
                }
              },
              child: Text(Language.inst.SAVE),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                height: 20.0,
              ),
              CustomTagTextField(
                controller: controller,
                hintText: playlistName!,
                labelText: Language.inst.NAME,
                validator: (value) => PlaylistController.inst.validatePlaylistName(value),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void deletePlaylist() {
    // function button won't be visible if playlistName == null.
    if (!shoulShowPlaylistUtils()) return;

    NamidaNavigator.inst.closeDialog();
    final pl = PlaylistController.inst.getPlaylist(playlistName!);
    if (pl == null) return;

    PlaylistController.inst.removePlaylist(pl);
    Get.snackbar(
      Language.inst.UNDO_CHANGES,
      Language.inst.UNDO_CHANGES_DELETED_PLAYLIST,
      mainButton: TextButton(
        onPressed: () {
          PlaylistController.inst.reAddPlaylist(pl, pl.modifiedDate);
          Get.closeAllSnackbars();
        },
        child: Text(Language.inst.UNDO),
      ),
    );
  }

  void updatePathDialog(String newPath) {
    NamidaNavigator.inst.navigateDialog(
      CustomBlurryDialog(
        isWarning: true,
        normalTitleStyle: true,
        bodyText: Language.inst.TRACK_PATH_OLD_NEW.replaceFirst('_OLD_NAME_', tracks.first.filenameWOExt).replaceFirst('_NEW_NAME_', newPath.getFilenameWOExt),
        actions: [
          const CancelButton(),
          ElevatedButton(
            onPressed: () {
              NamidaNavigator.inst.closeDialog(2);
              EditDeleteController.inst.updateTrackPathInEveryPartOfNamida(tracks.first, newPath);
            },
            child: Text(Language.inst.CONFIRM),
          )
        ],
      ),
    );
  }

  Widget highMatchesWidget(Set<String> highMatchesFiles, {bool showFullPath = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          Language.inst.HIGH_MATCHES,
          style: Get.textTheme.displayMedium,
        ),
        const SizedBox(height: 8.0),
        ...highMatchesFiles
            .map(
              (e) => SmallListTile(
                borderRadius: 12.0,
                title: showFullPath ? e : e.getFilename,
                subtitle: File(e).statSync().size.fileSizeFormatted,
                onTap: () => updatePathDialog(e),
                color: colorDelightened,
                icon: Broken.medal_star,
              ),
            )
            .toList(),
        const SizedBox(height: 8.0),
        const NamidaContainerDivider(),
        const SizedBox(height: 8.0),
      ],
    );
  }

  Future<void> pickDirectoryToUpdateTrack() async {
    final dirPath = await FilePicker.platform.getDirectoryPath();
    if (dirPath == null) return;

    final files = Directory(dirPath).listSync();
    files.removeWhere((element) => element is! File);
    if (files.isEmpty) {
      Get.snackbar(Language.inst.ERROR, Language.inst.NO_TRACKS_FOUND_IN_DIRECTORY);
      return;
    }

    final paths = files.map((e) => e.path).toList();
    paths.sort((a, b) => a.compareTo(b));

    final highMatchesFiles = getHighMatcheFilesFromFilename(paths, tracks.first.path.getFilename);

    /// Searching
    final txtc = TextEditingController();
    final RxList<String> filteredPaths = <String>[].obs;
    filteredPaths.addAll(paths);
    final RxBool shouldCleanUp = true.obs;

    NamidaNavigator.inst.navigateDialog(
      CustomBlurryDialog(
        title: Language.inst.CHOOSE,
        actions: [
          const CancelButton(),
          ElevatedButton(
            onPressed: () {
              NamidaNavigator.inst.closeDialog();
              pickDirectoryToUpdateTrack();
            },
            child: Text(Language.inst.PICK_FROM_STORAGE),
          ),
        ],
        child: SizedBox(
          width: Get.width,
          height: Get.height * 0.5,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: CustomTagTextField(
                      controller: txtc,
                      hintText: Language.inst.SEARCH,
                      labelText: '',
                      onChanged: (value) {
                        final matches = value == ''
                            ? paths
                            : paths.where((element) => shouldCleanUp.value ? element.cleanUpForComparison.contains(value.cleanUpForComparison) : element.contains(value));
                        filteredPaths
                          ..clear()
                          ..addAll(matches);
                      },
                    ),
                  ),
                  Obx(
                    () => NamidaIconButton(
                      tooltip: shouldCleanUp.value ? Language.inst.DISABLE_SEARCH_CLEANUP : Language.inst.ENABLE_SEARCH_CLEANUP,
                      icon: shouldCleanUp.value ? Broken.shield_cross : Broken.shield_search,
                      onPressed: () => shouldCleanUp.value = !shouldCleanUp.value,
                    ),
                  )
                ],
              ),
              const SizedBox(height: 8.0),
              Expanded(
                child: Obx(
                  () => NamidaListView(
                    header: highMatchesFiles.isNotEmpty ? highMatchesWidget(highMatchesFiles) : null,
                    itemBuilder: (context, i) {
                      final p = filteredPaths[i];
                      return SmallListTile(
                        key: ValueKey(i),
                        borderRadius: 12.0,
                        title: p.getFilename,
                        onTap: () => updatePathDialog(p),
                      );
                    },
                    itemCount: filteredPaths.length,
                    itemExtents: null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void setYoutubeLink() {
    NamidaNavigator.inst.closeDialog();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    TextEditingController controller = TextEditingController();
    final ytlink = tracks.first.youtubeLink;
    controller.text = ytlink;
    NamidaNavigator.inst.navigateDialog(
      Form(
        key: formKey,
        child: CustomBlurryDialog(
          title: Language.inst.SET_YOUTUBE_LINK,
          actions: [
            const CancelButton(),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  editTrackMetadata(tracks.first, insertComment: controller.text);
                  NamidaNavigator.inst.closeDialog();
                }
              },
              child: Text(Language.inst.SAVE),
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

  void openYoutubeLink() {
    final link = tracks.first.youtubeLink;
    if (link == '') {
      Get.snackbar(Language.inst.COULDNT_OPEN, Language.inst.COULDNT_OPEN_YT_LINK);
      return;
    }
    launchUrlString(
      link,
      mode: LaunchMode.externalNonBrowserApplication,
    );
  }

  final Widget? clearStuffListTile = tracks.hasAnythingCached
      ? SmallListTile(
          color: colorDelightened,
          compact: true,
          title: Language.inst.CLEAR,
          subtitle: Language.inst.CHOOSE_WHAT_TO_CLEAR,
          icon: Broken.trash,
          onTap: () => showTrackClearDialog(tracks),
        )
      : null;

  final Widget? removeFromPlaylistListTile = shoulShowRemoveFromPlaylist()
      ? SmallListTile(
          color: colorDelightened,
          compact: true,
          title: Language.inst.REMOVE_FROM_PLAYLIST,
          subtitle: playlistName!.translatePlaylistName(),
          icon: Broken.box_remove,
          onTap: () {
            NamidaOnTaps.inst.onRemoveTrackFromPlaylist(playlistName, index!, trackWithDate!);
            NamidaNavigator.inst.closeDialog();
          },
        )
      : null;

  final Widget? playlistUtilsRow = shoulShowPlaylistUtils()
      ? SizedBox(
          height: 48.0,
          child: Row(
            children: [
              const SizedBox(width: 24.0),
              Expanded(child: bigIcon(Broken.smileys, Language.inst.SET_MOODS, setPlaylistMoods)),
              const SizedBox(width: 8.0),
              Expanded(child: bigIcon(Broken.edit_2, Language.inst.RENAME_PLAYLIST, renamePlaylist)),
              const SizedBox(width: 8.0),
              Expanded(child: bigIcon(Broken.pen_remove, Language.inst.DELETE_PLAYLIST, deletePlaylist)),
              const SizedBox(width: 24.0),
            ],
          ),
        )
      : null;
  final Widget? removeQueueTile = queue != null
      ? SmallListTile(
          color: colorDelightened,
          compact: false,
          title: Language.inst.REMOVE_QUEUE,
          icon: Broken.pen_remove,
          onTap: () {
            final oldQueue = queue;
            QueueController.inst.removeQueue(oldQueue);
            Get.snackbar(
              Language.inst.UNDO_CHANGES,
              Language.inst.UNDO_CHANGES_DELETED_QUEUE,
              mainButton: TextButton(
                onPressed: () {
                  QueueController.inst.reAddQueue(oldQueue);
                  Get.closeAllSnackbars();
                },
                child: Text(Language.inst.UNDO),
              ),
            );
            NamidaNavigator.inst.closeDialog();
          },
        )
      : null;

  NamidaNavigator.inst.navigateDialog(
    NamidaBgBlur(
      blur: 5.0,
      child: GestureDetector(
        onTap: () => NamidaNavigator.inst.closeDialog(),
        child: Container(
          color: Colors.black.withAlpha(60),
          child: Theme(
            data: AppThemes.inst.getAppTheme(colorDelightened),
            child: Transform.scale(
              scale: 0.92,
              child: Dialog(
                insetPadding: const EdgeInsets.symmetric(horizontal: 34.0, vertical: 24.0),
                clipBehavior: Clip.antiAlias,
                surfaceTintColor: Colors.transparent,
                backgroundColor: Color.alphaBlend(colorDelightened.withAlpha(10), Get.theme.dialogBackgroundColor),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      /// Top Widget
                      NamidaInkWell(
                        borderRadius: 0.0,
                        onTap: () => isSingle ? showTrackInfoDialog(tracks.first, false, comingFromQueue: comingFromQueue, index: index) : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(width: 16.0),
                              if (forceSingleArtwork)
                                Hero(
                                  tag: heroTag ?? '$comingFromQueue${index}_sussydialogs_${tracks.first.path}',
                                  child: ArtworkWidget(
                                    track: tracks.trackOfImage,
                                    path: tracks.pathToImage,
                                    thumbnailSize: 60,
                                    forceSquared: forceSquared,
                                    borderRadius: isCircle ? 200 : 8.0,
                                    useTrackTileCacheHeight: useTrackTileCacheHeight,
                                  ),
                                ),
                              if (!forceSingleArtwork)
                                MultiArtworkContainer(
                                  heroTag: heroTag ?? 'edittags_artwork',
                                  size: 60,
                                  tracks: tracks,
                                  margin: EdgeInsets.zero,
                                ),
                              const SizedBox(width: 12.0),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (title.isNotEmpty)
                                      Text(
                                        title,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: Get.textTheme.displayLarge?.copyWith(
                                          fontSize: 17.0.multipliedFontScale,
                                          color: Color.alphaBlend(colorDelightened.withAlpha(40), Get.textTheme.displayMedium!.color!),
                                        ),
                                      ),
                                    const SizedBox(
                                      height: 1.0,
                                    ),
                                    if (subtitle.isNotEmpty)
                                      Text(
                                        subtitle.overflow,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: Get.textTheme.displayMedium?.copyWith(
                                          fontSize: 14.0.multipliedFontScale,
                                          color: Color.alphaBlend(colorDelightened.withAlpha(80), Get.textTheme.displayMedium!.color!),
                                        ),
                                      ),
                                    if (thirdLineText.isNotEmpty) ...[
                                      const SizedBox(
                                        height: 1.0,
                                      ),
                                      Text(
                                        thirdLineText.overflow,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: Get.textTheme.displaySmall?.copyWith(
                                          fontSize: 12.5.multipliedFontScale,
                                          color: Color.alphaBlend(colorDelightened.withAlpha(40), Get.textTheme.displayMedium!.color!),
                                        ),
                                      ),
                                    ]
                                  ],
                                ),
                              ),
                              const SizedBox(
                                width: 16.0,
                              ),
                              const Icon(
                                Broken.arrow_right_3,
                              ),
                              const SizedBox(
                                width: 16.0,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Divider(
                        color: Get.theme.dividerColor,
                        thickness: 0.5,
                        height: 0,
                      ),

                      /// if the track doesnt exist
                      !doesTracksExist
                          ? Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    '${errorPlayingTrack ? Language.inst.ERROR_PLAYING_TRACK : Language.inst.TRACK_NOT_FOUND}.\n${Language.inst.PROMPT_TO_CHANGE_TRACK_PATH}',
                                    style: Get.textTheme.displayMedium,
                                  ),
                                ),
                                if (isSingle) ...[
                                  SmallListTile(
                                    title: Language.inst.UPDATE,
                                    subtitle: tracks.first.path.getFilename,
                                    color: colorDelightened,
                                    compact: true,
                                    icon: Broken.document_upload,
                                    onTap: () async {
                                      NamidaNavigator.inst.closeDialog();
                                      if (Indexer.inst.allAudioFiles.isEmpty) {
                                        await Indexer.inst.getAudioFiles();
                                      }

                                      /// firstly checks if a file exists in current library
                                      final firstHighMatchesFiles = getHighMatcheFilesFromFilename(Indexer.inst.allAudioFiles, tracks.first.path.getFilename);
                                      if (firstHighMatchesFiles.isNotEmpty) {
                                        NamidaNavigator.inst.navigateDialog(
                                          CustomBlurryDialog(
                                            title: Language.inst.CHOOSE,
                                            actions: [
                                              const CancelButton(),
                                              ElevatedButton(
                                                onPressed: () {
                                                  NamidaNavigator.inst.closeDialog();
                                                  pickDirectoryToUpdateTrack();
                                                },
                                                child: Text(Language.inst.PICK_FROM_STORAGE),
                                              ),
                                            ],
                                            child: highMatchesWidget(firstHighMatchesFiles, showFullPath: true),
                                          ),
                                        );
                                        return;
                                      }
                                      await pickDirectoryToUpdateTrack();
                                    },
                                  ),
                                  if (errorPlayingTrack)
                                    SmallListTile(
                                      title: Language.inst.SKIP,
                                      color: colorDelightened,
                                      compact: true,
                                      icon: Broken.next,
                                      onTap: () async {
                                        NamidaNavigator.inst.closeDialog();
                                        Player.inst.next();
                                      },
                                    ),
                                ],
                                if (clearStuffListTile != null) clearStuffListTile,
                                if (removeFromPlaylistListTile != null) removeFromPlaylistListTile,
                                if (playlistUtilsRow != null) playlistUtilsRow,
                                if (removeQueueTile != null) removeQueueTile,
                                const SizedBox(height: 8.0),
                              ],
                            )
                          :

                          /// List Items
                          Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (availableAlbums.length == 1 && albumToAddFrom == null)
                                  SmallListTile(
                                    color: colorDelightened,
                                    compact: true,
                                    title: Language.inst.GO_TO_ALBUM,
                                    subtitle: availableAlbums.first,
                                    icon: Broken.music_dashboard,
                                    onTap: () => NamidaOnTaps.inst.onAlbumTap(availableAlbums.first),
                                    trailing: IconButton(
                                      tooltip: Language.inst.ADD_MORE_FROM_THIS_ALBUM,
                                      onPressed: () {
                                        NamidaNavigator.inst.closeDialog();
                                        Player.inst.addToQueue(generateTracksFromAlbum(availableAlbums.first), insertNext: true);
                                      },
                                      icon: const Icon(Broken.add),
                                    ),
                                  ),
                                if (availableAlbums.length == 1 && albumToAddFrom != null)
                                  SmallListTile(
                                    color: colorDelightened,
                                    compact: true,
                                    title: Language.inst.ADD_MORE_FROM_TO_QUEUE.replaceFirst('_MEDIA_', '"$albumToAddFrom"'),
                                    icon: Broken.music_dashboard,
                                    onTap: () => NamidaOnTaps.inst.onAlbumTap(availableAlbums.first),
                                    trailing: IgnorePointer(
                                      child: IconButton(
                                        onPressed: () {},
                                        icon: const Icon(Broken.add),
                                      ),
                                    ),
                                  ),

                                if (availableAlbums.length > 1)
                                  NamidaExpansionTile(
                                    icon: Broken.music_dashboard,
                                    iconColor: iconColor,
                                    titleText: Language.inst.GO_TO_ALBUM,
                                    textColorScheme: colorDelightened,
                                    childrenPadding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 12.0, top: 0),
                                    children: [
                                      Wrap(
                                        alignment: WrapAlignment.start,
                                        children: [
                                          ...availableAlbums
                                              .map(
                                                (e) => Padding(
                                                  padding: const EdgeInsets.all(2.0),
                                                  child: NamidaInkWell(
                                                      onTap: () => NamidaOnTaps.inst.onAlbumTap(e),
                                                      child: Text(
                                                        "$e  ",
                                                        style: Get.textTheme.displaySmall?.copyWith(decoration: TextDecoration.underline),
                                                      )),
                                                ),
                                              )
                                              .toList(),
                                        ],
                                      )
                                    ],
                                  ),
                                if (artistToAddFrom != null)
                                  SmallListTile(
                                    color: colorDelightened,
                                    compact: true,
                                    title: Language.inst.ADD_MORE_FROM_TO_QUEUE.replaceFirst('_MEDIA_', '"$artistToAddFrom"'),
                                    icon: Broken.microphone,
                                    onTap: () {
                                      NamidaNavigator.inst.closeDialog();
                                      Player.inst.addToQueue(generateTracksFromArtist(artistToAddFrom), insertNext: true);
                                    },
                                    trailing: IgnorePointer(
                                      child: IconButton(
                                        onPressed: () {},
                                        icon: const Icon(Broken.add),
                                      ),
                                    ),
                                  ),
                                if (artistToAddFrom == null && availableArtists.length == 1)
                                  SmallListTile(
                                    color: colorDelightened,
                                    compact: true,
                                    title: Language.inst.GO_TO_ARTIST,
                                    subtitle: availableArtists.first,
                                    icon: Broken.microphone,
                                    onTap: () => NamidaOnTaps.inst.onArtistTap(availableArtists.first),
                                    trailing: IconButton(
                                      tooltip: Language.inst.ADD_MORE_FROM_THIS_ARTIST,
                                      onPressed: () => Player.inst.addToQueue(generateTracksFromArtist(availableArtists.first), insertNext: true),
                                      icon: const Icon(Broken.add),
                                    ),
                                  ),

                                if (artistToAddFrom == null && availableArtists.length > 1)
                                  NamidaExpansionTile(
                                    icon: Broken.profile_2user,
                                    iconColor: iconColor,
                                    titleText: Language.inst.GO_TO_ARTIST,
                                    textColorScheme: colorDelightened,
                                    childrenPadding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 12.0, top: 0),
                                    children: [
                                      Wrap(
                                        alignment: WrapAlignment.start,
                                        children: [
                                          ...availableArtists
                                              .map(
                                                (e) => Padding(
                                                  padding: const EdgeInsets.all(2.0),
                                                  child: NamidaInkWell(
                                                    onTap: () => NamidaOnTaps.inst.onArtistTap(e),
                                                    child: Text(
                                                      "$e  ",
                                                      style: Get.textTheme.displaySmall?.copyWith(
                                                        decoration: TextDecoration.underline,
                                                        color: Color.alphaBlend(colorDelightened.withAlpha(40), Get.textTheme.displayMedium!.color!),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        ],
                                      )
                                    ],
                                  ),

                                /// Folders
                                if (availableFolders.length == 1)
                                  SmallListTile(
                                    color: colorDelightened,
                                    compact: true,
                                    title: Language.inst.GO_TO_FOLDER,
                                    subtitle: availableFolders.first.folderName,
                                    icon: Broken.folder,
                                    onTap: () {
                                      NamidaNavigator.inst.closeDialog();
                                      ScrollSearchController.inst.animatePageController(LibraryTab.folders);
                                      NamidaOnTaps.inst.onFolderTap(availableFolders.first, false, trackToScrollTo: tracks.first);
                                    },
                                    trailing: IconButton(
                                      tooltip: Language.inst.ADD_MORE_FROM_THIS_FOLDER,
                                      onPressed: () => Player.inst.addToQueue(generateTracksFromFolder(availableFolders.first), insertNext: true),
                                      icon: const Icon(Broken.add),
                                    ),
                                  ),

                                SmallListTile(
                                  color: colorDelightened,
                                  compact: false,
                                  title: Language.inst.SHARE,
                                  icon: Broken.share,
                                  trailing: Obx(() => isLoadingFilesToShare.value ? const LoadingIndicator() : const SizedBox()),
                                  onTap: () async {
                                    isLoadingFilesToShare.value = true;
                                    await Share.shareXFiles(tracksExisting.map((e) => XFile(e.path)).toList());
                                    isLoadingFilesToShare.value = false;
                                    NamidaNavigator.inst.closeDialog();
                                  },
                                ),

                                isSingle && tracks.first == Player.inst.nowPlayingTrack.value
                                    ? Opacity(
                                        opacity: Player.inst.sleepAfterTracks.value == 1 ? 0.6 : 1.0,
                                        child: IgnorePointer(
                                          ignoring: Player.inst.sleepAfterTracks.value == 1,
                                          child: SmallListTile(
                                            color: colorDelightened,
                                            compact: false,
                                            title: Language.inst.STOP_AFTER_THIS_TRACK,
                                            icon: Broken.pause,
                                            onTap: () {
                                              NamidaNavigator.inst.closeDialog();
                                              Player.inst.enableSleepAfterTracks.value = true;
                                              Player.inst.sleepAfterTracks.value = 1;
                                            },
                                          ),
                                        ),
                                      )
                                    : SmallListTile(
                                        color: colorDelightened,
                                        compact: false,
                                        title: isSingle ? Language.inst.PLAY : Language.inst.PLAY_ALL,
                                        icon: Broken.play,
                                        onTap: () {
                                          NamidaNavigator.inst.closeDialog();
                                          Player.inst.playOrPause(0, tracks, source);
                                        },
                                      ),

                                if (!isSingle)
                                  SmallListTile(
                                    color: colorDelightened,
                                    compact: false,
                                    title: Language.inst.SHUFFLE,
                                    icon: Broken.shuffle,
                                    onTap: () {
                                      NamidaNavigator.inst.closeDialog();
                                      Player.inst.playOrPause(0, tracks, source, shuffle: true);
                                    },
                                  ),

                                SmallListTile(
                                  color: colorDelightened,
                                  compact: false,
                                  title: Language.inst.ADD_TO_PLAYLIST,
                                  icon: Broken.music_library_2,
                                  onTap: () {
                                    NamidaNavigator.inst.closeDialog();
                                    showAddToPlaylistDialog(tracks);
                                  },
                                ),
                                SmallListTile(
                                  color: colorDelightened,
                                  compact: false,
                                  title: Language.inst.EDIT_TAGS,
                                  icon: Broken.edit,
                                  onTap: () {
                                    NamidaNavigator.inst.closeDialog();
                                    if (isSingle) {
                                      showEditTrackTagsDialog(tracks.first);
                                    } else {
                                      editMultipleTracksTags(tracks);
                                    }
                                  },
                                ),
                                if (clearStuffListTile != null) clearStuffListTile,

                                if (removeQueueTile != null) removeQueueTile,

                                if (Player.inst.latestInsertedIndex != Player.inst.currentIndex.value)
                                  SmallListTile(
                                    color: colorDelightened,
                                    compact: true,
                                    title: '${Language.inst.PLAY_AFTER} "${Player.inst.currentQueue.elementAt(Player.inst.latestInsertedIndex).title}"',
                                    subtitle: (Player.inst.latestInsertedIndex - Player.inst.currentIndex.value).displayTrackKeyword,
                                    icon: Broken.hierarchy_square,
                                    onTap: () {
                                      NamidaNavigator.inst.closeDialog();
                                      Player.inst.addToQueue(tracks, insertAfterLatest: true, showSnackBar: !isSingle);
                                    },
                                  ),
                                if (isSingle && tracks.first == Player.inst.nowPlayingTrack.value)
                                  Obx(
                                    () => SmallListTile(
                                      color: colorDelightened,
                                      compact: true,
                                      title: Language.inst.REPEAT_FOR_N_TIMES.replaceFirst('_NUM_', numberOfRepeats.value.toString()),
                                      icon: Broken.cd,
                                      onTap: () {
                                        NamidaNavigator.inst.closeDialog();
                                        SettingsController.inst.save(playerRepeatMode: RepeatMode.forNtimes);
                                        Player.inst.numberOfRepeats.value = numberOfRepeats.value;
                                      },
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          NamidaIconButton(
                                            icon: Broken.minus_cirlce,
                                            onPressed: () => numberOfRepeats.value = (numberOfRepeats.value - 1).clamp(1, 20),
                                            iconSize: 20.0,
                                            iconColor: iconColor,
                                          ),
                                          NamidaIconButton(
                                            icon: Broken.add_circle,
                                            onPressed: () => numberOfRepeats.value = (numberOfRepeats.value + 1).clamp(1, 20),
                                            iconSize: 20.0,
                                            iconColor: iconColor,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                if (playlistUtilsRow != null) playlistUtilsRow,

                                if (removeFromPlaylistListTile != null) removeFromPlaylistListTile,

                                /// Track Utils
                                /// todo: support for multiple tracks editing
                                if (isSingle && (playlistName == null || trackWithDate != null))
                                  Row(
                                    children: [
                                      const SizedBox(width: 24.0),
                                      Expanded(child: bigIcon(Broken.smileys, Language.inst.SET_MOODS, setTrackMoods)),
                                      const SizedBox(width: 8.0),
                                      Expanded(child: bigIcon(Broken.ticket_discount, Language.inst.SET_TAGS, setTrackTags)),
                                      const SizedBox(width: 8.0),
                                      Expanded(
                                        child: Obx(
                                          () => bigIcon(
                                            Broken.grammerly,
                                            Language.inst.SET_RATING,
                                            setTrackRating,
                                            subtitle: stats.value.rating == 0 ? '' : ' ${stats.value.rating}%',
                                          ),
                                        ),
                                      ),
                                      if (isSingle) ...[
                                        const SizedBox(width: 8.0),
                                        Expanded(
                                          child: bigIcon(
                                            Broken.edit_2,
                                            Language.inst.SET_YOUTUBE_LINK,
                                            setYoutubeLink,
                                            iconWidget: StackedIcon(
                                              baseIcon: Broken.edit_2,
                                              secondaryIcon: Broken.video_square,
                                              baseIconColor: iconColor,
                                              secondaryIconColor: iconColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8.0),
                                        Expanded(
                                          child: bigIcon(
                                            Broken.login_1,
                                            Language.inst.OPEN_YOUTUBE_LINK,
                                            openYoutubeLink,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(width: 24.0),
                                    ],
                                  ),
                                const SizedBox(height: 4.0),

                                Divider(
                                  color: Get.theme.dividerColor,
                                  thickness: 0.5,
                                  height: 0,
                                ),

                                /// bottom 2 tiles
                                Row(
                                  children: [
                                    Expanded(
                                      child: SmallListTile(
                                        color: colorDelightened,
                                        compact: false,
                                        title: Language.inst.PLAY_NEXT,
                                        icon: Broken.next,
                                        onTap: () {
                                          NamidaNavigator.inst.closeDialog();
                                          Player.inst.addToQueue(tracks, insertNext: true, showSnackBar: !isSingle);
                                        },
                                      ),
                                    ),
                                    Container(
                                      width: 0.5,
                                      height: 30,
                                      color: Get.theme.dividerColor,
                                    ),
                                    Expanded(
                                      child: SmallListTile(
                                        color: colorDelightened,
                                        compact: false,
                                        title: Language.inst.PLAY_LAST,
                                        icon: Broken.play_cricle,
                                        onTap: () {
                                          NamidaNavigator.inst.closeDialog();
                                          Player.inst.addToQueue(tracks, showSnackBar: !isSingle);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
