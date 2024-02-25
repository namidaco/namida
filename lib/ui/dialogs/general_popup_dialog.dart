import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import 'package:namida/class/folder.dart';
import 'package:namida/class/queue.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/edit_delete_controller.dart';
import 'package:namida/controller/generators_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/lyrics_controller.dart';
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
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/dialogs/add_to_playlist_dialog.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/dialogs/set_lrc_dialog.dart';
import 'package:namida/ui/dialogs/track_advanced_dialog.dart';
import 'package:namida/ui/dialogs/track_info_dialog.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/multi_artwork_container.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/youtube/class/youtube_id.dart';

import 'package:namida/main.dart';

Future<void> showGeneralPopupDialog(
  List<Track> tracks,
  String title,
  String subtitle,
  QueueSource source, {
  void Function()? onTopBarTap,
  String? playlistName,
  List<TrackWithDate> tracksWithDates = const <TrackWithDate>[],
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
  Exception? errorPlayingTrack,
  String? artistToAddFrom,
  (String, String)? albumToAddFrom,
  String? heroTag,
  String? additionalHero,
}) async {
  final tracksExisting = <Track>[];
  if (errorPlayingTrack != null) {
    // -- fill using real-time checks if there was an error.
    tracks.loop((t, index) {
      if (File(t.path).existsSync()) tracksExisting.add(t);
    });
  } else {
    tracks.loop((t, index) {
      final existingTrack = t.path.toTrackOrNull();
      if (existingTrack != null) tracksExisting.add(existingTrack);
    });
  }

  final isSingle = tracks.length == 1;
  forceSingleArtwork ??= isSingle;

  final trackToExtractColorFrom = tracks.isEmpty
      ? null
      : forceSingleArtwork
          ? tracks[tracks.indexOfImage]
          : tracks.first;

  final colorDelightened = CurrentColor.inst.color.obs;
  final iconColor = Color.alphaBlend(colorDelightened.value.withAlpha(120), Get.textTheme.displayMedium!.color!).obs;
  if (extractColor && trackToExtractColorFrom != null) {
    CurrentColor.inst.getTrackDelightnedColor(trackToExtractColorFrom, useIsolate: true).executeWithMinDelay().then((c) {
      if (c == colorDelightened.value) return;
      colorDelightened.value = c;
      iconColor.value = Color.alphaBlend(c.withAlpha(120), Get.textTheme.displayMedium!.color!);
    });
  }

  /// name, identifier
  final List<(String, String)> availableAlbums = tracks.mappedUniqued((e) {
    final ext = e.toTrackExt();
    return (ext.album, ext.albumIdentifier);
  });
  final List<String> availableArtists = tracks.mappedUniquedList((e) => e.toTrackExt().artistsList);
  final List<Folder> availableFolders = tracks.mappedUniqued((e) => e.folder);

  final Iterable<YoutubeID> availableYoutubeIDs = tracks.map((e) => YoutubeID(id: e.youtubeID, playlistID: null)).where((element) => element.id != '');

  final numberOfRepeats = 1.obs;
  final isLoadingFilesToShare = false.obs;

  bool shoulShowPlaylistUtils() => tracksWithDates.length > 1 && playlistName != null && !PlaylistController.inst.isOneOfDefaultPlaylists(playlistName);
  bool shoulShowRemoveFromPlaylist() => tracksWithDates.isNotEmpty && playlistName != null && playlistName != k_PLAYLIST_NAME_MOST_PLAYED;

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
                  StreamBuilder(
                    initialData: iconColor.value,
                    stream: iconColor.stream,
                    builder: (context, snapshot) => Icon(
                      icon,
                      color: snapshot.data,
                    ),
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

  Future<void> openDialog(Widget widget, {void Function()? onDisposing}) async {
    await NamidaNavigator.inst.navigateDialog(
      onDisposing: onDisposing,
      dialog: StreamBuilder(
        initialData: colorDelightened.value,
        stream: colorDelightened.stream,
        builder: (context, snapshot) => AnimatedTheme(
          data: AppThemes.inst.getAppTheme(snapshot.data, null, true),
          child: widget,
        ),
      ),
    );
  }

  void cancelSkipTimer() => Player.inst.cancelPlayErrorSkipTimer();

  void setMoodsOrTags(List<String> initialMoods, void Function(List<String> moodsFinal) saveFunction, {bool isTags = false}) async {
    final controller = TextEditingController();
    final currentMoods = initialMoods.join(', ');
    controller.text = currentMoods;

    final title = isTags ? lang.SET_TAGS : lang.SET_MOODS;
    final subtitle = lang.SET_MOODS_SUBTITLE;
    await openDialog(
      onDisposing: () {
        controller.dispose();
      },
      CustomBlurryDialog(
        title: title,
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.SAVE,
            onPressed: () async {
              List<String> moodsPre = controller.text.split(',');
              List<String> moodsFinal = [];
              moodsPre.loop((m, index) {
                if (!m.contains(',') && m != ' ' && m.isNotEmpty) {
                  moodsFinal.add(m.trimAll());
                }
              });

              saveFunction(moodsFinal.uniqued());

              NamidaNavigator.inst.closeDialog();
            },
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
    cancelSkipTimer();

    final pl = PlaylistController.inst.getPlaylist(playlistName!);
    if (pl == null) return;
    setMoodsOrTags(
      pl.moods,
      (moodsFinal) => PlaylistController.inst.updatePropertyInPlaylist(playlistName, moods: moodsFinal.uniqued()),
    );
  }

  final stats = tracks.firstOrNull?.stats.obs;

  void setTrackMoods() {
    if (stats == null) return;
    setMoodsOrTags(
      stats.value.moods,
      (moodsFinal) async {
        stats.value = await Indexer.inst.updateTrackStats(tracks.first, moods: moodsFinal);
      },
    );
  }

  void setTrackTags() {
    if (stats == null) return;
    cancelSkipTimer();
    setMoodsOrTags(
      stats.value.tags,
      (tagsFinal) async {
        stats.value = await Indexer.inst.updateTrackStats(tracks.first, tags: tagsFinal);
      },
      isTags: true,
    );
  }

  void setTrackRating() async {
    if (stats == null) return;
    final c = TextEditingController();
    await openDialog(
      onDisposing: () {
        c.dispose();
      },
      CustomBlurryDialog(
        title: lang.SET_RATING,
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.SAVE,
            onPressed: () async {
              NamidaNavigator.inst.closeDialog();
              final val = int.tryParse(c.text) ?? 0;
              stats.value = await Indexer.inst.updateTrackStats(tracks.first, rating: val);
            },
          ),
        ],
        child: CustomTagTextField(
          controller: c,
          hintText: stats.value.rating.toString(),
          labelText: lang.SET_RATING,
          keyboardType: TextInputType.number,
        ),
      ),
    );
  }

  void renamePlaylist() async {
    // function button won't be visible if playlistName == null.
    if (!shoulShowPlaylistUtils()) return;
    cancelSkipTimer();

    final controller = TextEditingController(text: playlistName);
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    await openDialog(
      onDisposing: () {
        controller.dispose();
      },
      Form(
        key: formKey,
        child: CustomBlurryDialog(
          title: lang.RENAME_PLAYLIST,
          actions: [
            const CancelButton(),
            NamidaButton(
              text: lang.SAVE,
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final didRename = await PlaylistController.inst.renamePlaylist(playlistName!, controller.text);
                  if (didRename) {
                    NamidaNavigator.inst.closeDialog();
                  } else {
                    snackyy(title: lang.ERROR, message: lang.COULDNT_RENAME_PLAYLIST);
                  }
                }
              },
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
                labelText: lang.NAME,
                validator: (value) => PlaylistController.inst.validatePlaylistName(value),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> deletePlaylist() async {
    // function button won't be visible if playlistName == null.
    if (!shoulShowPlaylistUtils()) return;
    cancelSkipTimer();

    NamidaNavigator.inst.closeDialog();
    final pl = PlaylistController.inst.getPlaylist(playlistName!);
    if (pl == null) return;

    await PlaylistController.inst.removePlaylist(pl);
    snackyy(
      title: lang.UNDO_CHANGES,
      message: lang.UNDO_CHANGES_DELETED_PLAYLIST,
      displaySeconds: 3,
      button: TextButton(
        onPressed: () async {
          await PlaylistController.inst.reAddPlaylist(pl, pl.modifiedDate);
          Get.closeAllSnackbars();
        },
        child: Text(lang.UNDO),
      ),
    );
  }

  Future<void> removePlaylistDuplicates() async {
    if (!shoulShowPlaylistUtils()) return;
    final pl = PlaylistController.inst.getPlaylist(playlistName!);
    if (pl == null) return;
    final removed = pl.tracks.removeDuplicates((element) => element.track);
    await PlaylistController.inst.updatePropertyInPlaylist(pl.name, modifiedDate: currentTimeMS);
    await PlaylistController.inst.onPlaylistTracksChanged(pl); // to write m3u
    snackyy(
      icon: Broken.filter_remove,
      message: "${lang.REMOVED} ${removed.displayTrackKeyword}",
    );
  }

  Future<void> exportPlaylist() async {
    // function button won't be visible if playlistName == null.
    if (!shoulShowPlaylistUtils()) return;
    cancelSkipTimer();

    NamidaNavigator.inst.closeDialog();
    final pl = PlaylistController.inst.getPlaylist(playlistName!);
    if (pl == null) return;

    if (!await requestManageStoragePermission()) return;

    final savePath = "${AppDirs.M3UPlaylists}${pl.name}.m3u";
    await PlaylistController.inst.exportPlaylistToM3UFile(pl, savePath);
    snackyy(
      message: "${lang.SAVED_IN}: $savePath",
      leftBarIndicatorColor: colorDelightened.value,
      margin: EdgeInsets.zero,
      top: false,
      borderRadius: 0,
    );
  }

  void updatePathDialog(String newPath) async {
    await openDialog(
      CustomBlurryDialog(
        isWarning: true,
        normalTitleStyle: true,
        bodyText: lang.TRACK_PATH_OLD_NEW.replaceFirst('_OLD_NAME_', tracks.first.filenameWOExt).replaceFirst('_NEW_NAME_', newPath.getFilenameWOExt),
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.CONFIRM,
            onPressed: () {
              NamidaNavigator.inst.closeDialog(2);
              EditDeleteController.inst.updateTrackPathInEveryPartOfNamida(tracks.first, newPath);
            },
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
          lang.HIGH_MATCHES,
          style: Get.textTheme.displayMedium,
        ),
        const SizedBox(height: 8.0),
        ...highMatchesFiles.map(
          (e) => SmallListTile(
            borderRadius: 12.0,
            title: showFullPath ? e : e.getFilename,
            subtitle: File(e).statSync().size.fileSizeFormatted,
            onTap: () => updatePathDialog(e),
            color: colorDelightened.value, // not worth refreshing
            icon: Broken.medal_star,
          ),
        ),
        const SizedBox(height: 8.0),
        const NamidaContainerDivider(),
        const SizedBox(height: 8.0),
      ],
    );
  }

  Future<void> pickDirectoryToUpdateTrack() async {
    final dirPath = await FilePicker.platform.getDirectoryPath();
    if (dirPath == null) return;

    final files = await Directory(dirPath).listAllIsolate();
    files.removeWhere((element) => element is! File);
    if (files.isEmpty) {
      snackyy(title: lang.ERROR, message: lang.NO_TRACKS_FOUND_IN_DIRECTORY);
      return;
    }

    final paths = files.mapped((e) => e.path);
    paths.sortBy((e) => e);

    final highMatchesFiles = NamidaGenerator.inst.getHighMatcheFilesFromFilename(paths, tracks.first.path.getFilename);

    /// Searching
    final txtc = TextEditingController();
    final RxList<String> filteredPaths = <String>[].obs;
    filteredPaths.addAll(paths);
    final RxBool shouldCleanUp = true.obs;

    await openDialog(
      onDisposing: () {
        filteredPaths.close();
        shouldCleanUp.close();
        txtc.dispose();
      },
      CustomBlurryDialog(
        title: lang.CHOOSE,
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.PICK_FROM_STORAGE,
            onPressed: () {
              NamidaNavigator.inst.closeDialog();
              pickDirectoryToUpdateTrack();
            },
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
                      hintText: lang.SEARCH,
                      labelText: '',
                      onChanged: (value) {
                        final matches = value == ''
                            ? paths
                            : paths.where((element) => shouldCleanUp.value ? element.cleanUpForComparison.contains(value.cleanUpForComparison) : element.contains(value)).toList();
                        filteredPaths.value = matches;
                      },
                    ),
                  ),
                  Obx(
                    () => NamidaIconButton(
                      tooltip: shouldCleanUp.value ? lang.DISABLE_SEARCH_CLEANUP : lang.ENABLE_SEARCH_CLEANUP,
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
                        subtitle: File(p).statSync().size.fileSizeFormatted,
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

  void openYoutubeLink() {
    final link = tracks.first.youtubeLink;
    if (link == '') {
      snackyy(title: lang.COULDNT_OPEN, message: lang.COULDNT_OPEN_YT_LINK);
      return;
    }
    NamidaLinkUtils.openLink(link);
  }

  final advancedStuffListTile = Obx(
    () => SmallListTile(
      color: colorDelightened.value,
      compact: false,
      title: lang.ADVANCED,
      icon: Broken.code_circle,
      onTap: () {
        cancelSkipTimer();
        showTrackAdvancedDialog(
          tracks: tracksWithDates.isNotEmpty ? tracksWithDates : tracks,
          colorScheme: colorDelightened.value,
          source: source,
          albumsUniqued: availableAlbums,
        );
      },
    ),
  );

  final Widget? removeFromPlaylistListTile = shoulShowRemoveFromPlaylist()
      ? Obx(
          () => SmallListTile(
            color: colorDelightened.value,
            compact: true,
            title: lang.REMOVE_FROM_PLAYLIST,
            subtitle: playlistName!.translatePlaylistName(),
            icon: Broken.box_remove,
            onTap: () async {
              cancelSkipTimer();
              NamidaNavigator.inst.closeDialog();
              await NamidaOnTaps.inst.onRemoveTracksFromPlaylist(playlistName, tracksWithDates);
            },
          ),
        )
      : null;

  final Widget? playlistUtilsRow = shoulShowPlaylistUtils()
      ? SizedBox(
          height: 48.0,
          child: Row(
            children: [
              const SizedBox(width: 24.0),
              Expanded(child: bigIcon(Broken.smileys, lang.SET_MOODS, setPlaylistMoods)),
              const SizedBox(width: 8.0),
              Expanded(child: bigIcon(Broken.edit_2, lang.RENAME_PLAYLIST, renamePlaylist)),
              const SizedBox(width: 8.0),
              Expanded(
                child: bigIcon(
                  Broken.edit_2,
                  lang.REMOVE_DUPLICATES,
                  removePlaylistDuplicates,
                  iconWidget: const StackedIcon(
                    baseIcon: Broken.copy,
                    secondaryIcon: Broken.broom,
                  ),
                ),
              ),
              const SizedBox(width: 8.0),
              Expanded(child: bigIcon(Broken.pen_remove, lang.DELETE_PLAYLIST, deletePlaylist)),
              if (PlaylistController.inst.getPlaylist(playlistName ?? '')?.m3uPath == null) ...[
                const SizedBox(width: 8.0),
                Expanded(child: bigIcon(Broken.directbox_send, lang.EXPORT_AS_M3U, exportPlaylist)),
              ],
              const SizedBox(width: 24.0),
            ],
          ),
        )
      : null;
  final Widget? removeQueueTile = queue != null
      ? Obx(
          () => SmallListTile(
            color: colorDelightened.value,
            compact: false,
            title: lang.REMOVE_QUEUE,
            icon: Broken.pen_remove,
            onTap: () {
              cancelSkipTimer();
              NamidaOnTaps.inst.onQueueDelete(queue);
              NamidaNavigator.inst.closeDialog();
            },
          ),
        )
      : null;

  NamidaNavigator.inst.navigateDialog(
    onDisposing: () {
      numberOfRepeats.close();
      isLoadingFilesToShare.close();
      stats?.close();
      colorDelightened.close();
    },
    lighterDialogColor: false,
    durationInMs: 400,
    scale: 0.92,
    onDismissing: cancelSkipTimer,
    dialog: StreamBuilder(
      initialData: colorDelightened.value,
      stream: colorDelightened.stream,
      builder: (context, snapshot) {
        final theme = AppThemes.inst.getAppTheme(snapshot.data, null, false);
        final iconColor = Color.alphaBlend(colorDelightened.value.withAlpha(120), theme.textTheme.displayMedium!.color!);
        return AnimatedTheme(
          data: theme,
          child: Dialog(
            backgroundColor: theme.dialogBackgroundColor,
            insetPadding: const EdgeInsets.symmetric(horizontal: 34.0, vertical: 24.0),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  /// Top Widget
                  NamidaInkWell(
                    borderRadius: 0.0,
                    onTap: () => isSingle
                        ? showTrackInfoDialog(
                            tracks.first,
                            false,
                            comingFromQueue: comingFromQueue,
                            index: index,
                            colorScheme: colorDelightened.value,
                            queueSource: source,
                            additionalHero: additionalHero,
                          )
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(width: 16.0),
                          if (forceSingleArtwork!)
                            NamidaHero(
                              tag: heroTag ?? '$comingFromQueue${index}_sussydialogs_${tracks.firstOrNull?.path}$additionalHero',
                              child: ArtworkWidget(
                                key: Key(tracks.pathToImage),
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
                              tracks: tracks.toImageTracks(),
                              fallbackToFolderCover: false,
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
                                    style: theme.textTheme.displayLarge?.copyWith(
                                      fontSize: 17.0.multipliedFontScale,
                                      color: Color.alphaBlend(colorDelightened.value.withAlpha(40), theme.textTheme.displayMedium!.color!),
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
                                    style: theme.textTheme.displayMedium?.copyWith(
                                      fontSize: 14.0.multipliedFontScale,
                                      color: Color.alphaBlend(colorDelightened.value.withAlpha(80), theme.textTheme.displayMedium!.color!),
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
                                    style: theme.textTheme.displaySmall?.copyWith(
                                      fontSize: 12.5.multipliedFontScale,
                                      color: Color.alphaBlend(colorDelightened.value.withAlpha(40), theme.textTheme.displayMedium!.color!),
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
                    color: theme.dividerColor,
                    thickness: 0.5,
                    height: 0,
                  ),

                  /// if the track doesnt exist
                  errorPlayingTrack != null || tracksExisting.isEmpty
                      ? Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.red.withOpacity(0.3),
                                  ),
                                  borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    tracksExisting.isEmpty
                                        ? "${lang.TRACK_NOT_FOUND}.\n${lang.PROMPT_TO_CHANGE_TRACK_PATH}"
                                        : "${lang.ERROR_PLAYING_TRACK}.\n${errorPlayingTrack.toString()}",
                                    style: theme.textTheme.displayMedium,
                                  ),
                                ),
                              ),
                            ),
                            if (isSingle) ...[
                              SmallListTile(
                                title: lang.UPDATE,
                                subtitle: tracks.first.path,
                                color: colorDelightened.value,
                                compact: true,
                                icon: Broken.document_upload,
                                onTap: () async {
                                  cancelSkipTimer();
                                  NamidaNavigator.inst.closeDialog();
                                  if (Indexer.inst.allAudioFiles.isEmpty) {
                                    await Indexer.inst.getAudioFiles();
                                  }

                                  /// firstly checks if a file exists in current library
                                  final firstHighMatchesFiles = NamidaGenerator.inst.getHighMatcheFilesFromFilename(Indexer.inst.allAudioFiles, tracks.first.path.getFilename);
                                  if (firstHighMatchesFiles.isNotEmpty) {
                                    await openDialog(
                                      CustomBlurryDialog(
                                        title: lang.CHOOSE,
                                        actions: [
                                          const CancelButton(),
                                          NamidaButton(
                                            text: lang.PICK_FROM_STORAGE,
                                            onPressed: () {
                                              NamidaNavigator.inst.closeDialog();
                                              pickDirectoryToUpdateTrack();
                                            },
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
                              if (errorPlayingTrack != null)
                                Obx(
                                  () {
                                    final remainingSecondsToSkip = Player.inst.playErrorRemainingSecondsToSkip;
                                    return SmallListTile(
                                      title: lang.SKIP,
                                      subtitle: remainingSecondsToSkip <= 0 ? null : '$remainingSecondsToSkip ${lang.SECONDS}',
                                      color: colorDelightened.value,
                                      compact: true,
                                      icon: Broken.next,
                                      trailing: remainingSecondsToSkip <= 0
                                          ? null
                                          : NamidaIconButton(
                                              icon: Broken.close_circle,
                                              iconColor: Get.context?.defaultIconColor(colorDelightened.value, theme.textTheme.displayMedium?.color),
                                              onPressed: cancelSkipTimer,
                                            ),
                                      onTap: () {
                                        cancelSkipTimer();
                                        NamidaNavigator.inst.closeDialog();
                                        Player.inst.next();
                                      },
                                    );
                                  },
                                ),
                            ],
                            advancedStuffListTile,
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
                                color: colorDelightened.value,
                                compact: true,
                                title: lang.GO_TO_ALBUM,
                                subtitle: availableAlbums.first.$1,
                                icon: Broken.music_dashboard,
                                onTap: () => NamidaOnTaps.inst.onAlbumTap(availableAlbums.first.$2),
                                trailing: IconButton(
                                  tooltip: lang.ADD_MORE_FROM_THIS_ALBUM,
                                  onPressed: () {
                                    NamidaNavigator.inst.closeDialog();
                                    final tracks = availableAlbums.first.$2.getAlbumTracks();
                                    Player.inst.addToQueue(tracks, insertNext: true, insertionType: QueueInsertionType.moreAlbum);
                                  },
                                  icon: const Icon(Broken.add),
                                ),
                              ),
                            if (availableAlbums.length == 1 && albumToAddFrom != null)
                              SmallListTile(
                                color: colorDelightened.value,
                                compact: true,
                                title: lang.ADD_MORE_FROM_TO_QUEUE.replaceFirst('_MEDIA_', '"${albumToAddFrom.$1}"'),
                                icon: Broken.music_dashboard,
                                onTap: () {
                                  final tracks = albumToAddFrom.$2.getAlbumTracks();
                                  Player.inst.addToQueue(tracks, insertNext: true, insertionType: QueueInsertionType.moreAlbum);
                                },
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
                                titleText: lang.GO_TO_ALBUM,
                                textColorScheme: colorDelightened.value,
                                childrenPadding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 12.0, top: 0),
                                children: [
                                  Wrap(
                                    alignment: WrapAlignment.start,
                                    children: [
                                      ...availableAlbums.map(
                                        (e) => Padding(
                                          padding: const EdgeInsets.all(2.0).add(const EdgeInsets.only(right: 2.0)),
                                          child: NamidaInkWell(
                                              borderRadius: 0.0,
                                              onTap: () => NamidaOnTaps.inst.onAlbumTap(e.$2),
                                              child: Text(
                                                e.$1,
                                                style: theme.textTheme.displaySmall?.copyWith(decoration: TextDecoration.underline),
                                              )),
                                        ),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            if (artistToAddFrom != null)
                              SmallListTile(
                                color: colorDelightened.value,
                                compact: true,
                                title: lang.ADD_MORE_FROM_TO_QUEUE.replaceFirst('_MEDIA_', '"$artistToAddFrom"'),
                                icon: Broken.microphone,
                                onTap: () {
                                  NamidaNavigator.inst.closeDialog();
                                  final tracks = artistToAddFrom.getArtistTracks();
                                  Player.inst.addToQueue(tracks, insertNext: true, insertionType: QueueInsertionType.moreArtist);
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
                                color: colorDelightened.value,
                                compact: true,
                                title: lang.GO_TO_ARTIST,
                                subtitle: availableArtists.first,
                                icon: Broken.microphone,
                                onTap: () => NamidaOnTaps.inst.onArtistTap(availableArtists.first),
                                trailing: IconButton(
                                  tooltip: lang.ADD_MORE_FROM_THIS_ARTIST,
                                  onPressed: () {
                                    final tracks = availableArtists.first.getArtistTracks();
                                    Player.inst.addToQueue(tracks, insertNext: true, insertionType: QueueInsertionType.moreArtist);
                                  },
                                  icon: const Icon(Broken.add),
                                ),
                              ),

                            if (artistToAddFrom == null && availableArtists.length > 1)
                              NamidaExpansionTile(
                                icon: Broken.profile_2user,
                                iconColor: iconColor,
                                titleText: lang.GO_TO_ARTIST,
                                textColorScheme: colorDelightened.value,
                                childrenPadding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 12.0, top: 0),
                                children: [
                                  Wrap(
                                    alignment: WrapAlignment.start,
                                    children: [
                                      ...availableArtists.map(
                                        (e) => Padding(
                                          padding: const EdgeInsets.all(2.0).add(const EdgeInsets.only(right: 2.0)),
                                          child: NamidaInkWell(
                                            borderRadius: 0.0,
                                            onTap: () => NamidaOnTaps.inst.onArtistTap(e),
                                            child: Text(
                                              e,
                                              style: theme.textTheme.displaySmall?.copyWith(
                                                decoration: TextDecoration.underline,
                                                color: Color.alphaBlend(colorDelightened.value.withAlpha(40), theme.textTheme.displayMedium!.color!),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                ],
                              ),

                            /// Folders
                            if (availableFolders.length == 1)
                              SmallListTile(
                                color: colorDelightened.value,
                                compact: true,
                                title: lang.GO_TO_FOLDER,
                                subtitle: availableFolders.first.folderName,
                                icon: Broken.folder,
                                onTap: () {
                                  NamidaNavigator.inst.closeDialog();
                                  ScrollSearchController.inst.animatePageController(LibraryTab.folders);
                                  NamidaOnTaps.inst.onFolderTap(availableFolders.first, trackToScrollTo: tracks.first);
                                },
                                trailing: IconButton(
                                  tooltip: lang.ADD_MORE_FROM_THIS_FOLDER,
                                  onPressed: () {
                                    final tracks = availableFolders.first.tracks;
                                    Player.inst.addToQueue(tracks, insertNext: true, insertionType: QueueInsertionType.moreFolder);
                                  },
                                  icon: const Icon(Broken.add),
                                ),
                              ),

                            SmallListTile(
                              color: colorDelightened.value,
                              compact: false,
                              title: lang.SHARE,
                              icon: Broken.share,
                              trailing: Obx(() => isLoadingFilesToShare.value ? const LoadingIndicator() : const SizedBox()),
                              onTap: () async {
                                isLoadingFilesToShare.value = true;
                                await Share.shareXFiles(tracksExisting.mapped((e) => XFile(e.path)));
                                isLoadingFilesToShare.value = false;
                                NamidaNavigator.inst.closeDialog();
                              },
                            ),

                            isSingle && tracks.first == Player.inst.nowPlayingTrack
                                ? NamidaOpacity(
                                    opacity: Player.inst.sleepAfterTracks == 1 ? 0.6 : 1.0,
                                    child: IgnorePointer(
                                      ignoring: Player.inst.sleepAfterTracks == 1,
                                      child: SmallListTile(
                                        color: colorDelightened.value,
                                        compact: false,
                                        title: lang.STOP_AFTER_THIS_TRACK,
                                        icon: Broken.pause,
                                        onTap: () {
                                          NamidaNavigator.inst.closeDialog();
                                          Player.inst.updateSleepTimerValues(enableSleepAfterTracks: true, sleepAfterTracks: 1);
                                        },
                                      ),
                                    ),
                                  )
                                : SmallListTile(
                                    color: colorDelightened.value,
                                    compact: false,
                                    title: isSingle ? lang.PLAY : lang.PLAY_ALL,
                                    icon: Broken.play,
                                    onTap: () {
                                      NamidaNavigator.inst.closeDialog();
                                      Player.inst.playOrPause(0, tracks, source);
                                    },
                                  ),

                            if (!isSingle)
                              SmallListTile(
                                color: colorDelightened.value,
                                compact: false,
                                title: lang.SHUFFLE,
                                icon: Broken.shuffle,
                                onTap: () {
                                  NamidaNavigator.inst.closeDialog();
                                  Player.inst.playOrPause(0, tracks, source, shuffle: true);
                                },
                              ),

                            SmallListTile(
                              color: colorDelightened.value,
                              compact: false,
                              title: lang.ADD_TO_PLAYLIST,
                              icon: Broken.music_library_2,
                              onTap: () {
                                NamidaNavigator.inst.closeDialog();
                                showAddToPlaylistDialog(tracks);
                              },
                            ),
                            SmallListTile(
                              color: colorDelightened.value,
                              compact: false,
                              title: lang.EDIT_TAGS,
                              icon: Broken.edit,
                              onTap: () {
                                NamidaNavigator.inst.closeDialog();
                                showEditTracksTagsDialog(tracks, colorDelightened.value);
                              },
                              trailing: isSingle
                                  ? IconButton(
                                      tooltip: lang.LYRICS,
                                      icon: Lyrics.inst.hasLyrics(tracks.first)
                                          ? StackedIcon(
                                              baseIcon: Broken.document,
                                              secondaryIcon: Broken.tick_circle,
                                              iconSize: 20.0,
                                              secondaryIconSize: 10.0,
                                              baseIconColor: iconColor,
                                            )
                                          : Icon(
                                              Broken.document,
                                              size: 20.0,
                                              color: iconColor,
                                            ),
                                      iconSize: 20.0,
                                      onPressed: () => showLRCSetDialog(tracks.first, colorDelightened.value),
                                    )
                                  : null,
                            ),
                            // --- Advanced dialog
                            advancedStuffListTile,

                            if (availableYoutubeIDs.isNotEmpty)
                              SmallListTile(
                                color: colorDelightened.value,
                                compact: true,
                                title: lang.OPEN_IN_YOUTUBE_VIEW,
                                icon: Broken.video,
                                onTap: () {
                                  NamidaNavigator.inst.closeDialog();
                                  Player.inst.playOrPause(0, availableYoutubeIDs, QueueSource.others);
                                },
                              ),

                            if (removeQueueTile != null) removeQueueTile,

                            if (Player.inst.currentQueue.isNotEmpty && Player.inst.latestInsertedIndex != Player.inst.currentIndex)
                              () {
                                final playAfterTrack = Player.inst.currentQueue.elementAt(Player.inst.latestInsertedIndex).track;
                                return SmallListTile(
                                  color: colorDelightened.value,
                                  compact: true,
                                  title: '${lang.PLAY_AFTER}: ${(Player.inst.latestInsertedIndex - Player.inst.currentIndex).displayTrackKeyword}',
                                  subtitle: [playAfterTrack.artistsList.firstOrNull, playAfterTrack.title].joinText(separator: ' - '),
                                  icon: Broken.hierarchy_square,
                                  onTap: () {
                                    NamidaNavigator.inst.closeDialog();
                                    Player.inst.addToQueue(tracks, insertAfterLatest: true, showSnackBar: !isSingle);
                                  },
                                );
                              }(),

                            if (isSingle && tracks.first == Player.inst.nowPlayingTrack)
                              Obx(
                                () => SmallListTile(
                                  color: colorDelightened.value,
                                  compact: true,
                                  title: lang.REPEAT_FOR_N_TIMES.replaceFirst('_NUM_', numberOfRepeats.value.toString()),
                                  icon: Broken.cd,
                                  onTap: () {
                                    NamidaNavigator.inst.closeDialog();
                                    settings.player.save(repeatMode: RepeatMode.forNtimes);
                                    Player.inst.updateNumberOfRepeats(numberOfRepeats.value);
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

                            if (removeFromPlaylistListTile != null) removeFromPlaylistListTile,

                            if (playlistUtilsRow != null) playlistUtilsRow,

                            /// Track Utils
                            /// todo: support for multiple tracks editing
                            if (isSingle && (playlistName == null || tracksWithDates.firstOrNull != null))
                              Row(
                                children: [
                                  const SizedBox(width: 24.0),
                                  Expanded(child: bigIcon(Broken.smileys, lang.SET_MOODS, setTrackMoods)),
                                  const SizedBox(width: 8.0),
                                  Expanded(child: bigIcon(Broken.ticket_discount, lang.SET_TAGS, setTrackTags)),
                                  const SizedBox(width: 8.0),
                                  Expanded(
                                    child: Obx(
                                      () => bigIcon(
                                        Broken.grammerly,
                                        lang.SET_RATING,
                                        setTrackRating,
                                        subtitle: stats == null || stats.value.rating == 0 ? '' : ' ${stats.value.rating}%',
                                      ),
                                    ),
                                  ),
                                  if (isSingle) ...[
                                    const SizedBox(width: 8.0),
                                    Expanded(
                                      child: bigIcon(
                                        Broken.edit_2,
                                        lang.SET_YOUTUBE_LINK,
                                        () => showSetYTLinkCommentDialog(tracks, colorDelightened.value),
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
                                        lang.OPEN_YOUTUBE_LINK,
                                        openYoutubeLink,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 24.0),
                                ],
                              ),
                            const SizedBox(height: 4.0),

                            Divider(
                              color: theme.dividerColor,
                              thickness: 0.5,
                              height: 0,
                            ),

                            /// bottom 2 tiles
                            Row(
                              children: [
                                Expanded(
                                  child: SmallListTile(
                                    color: colorDelightened.value,
                                    compact: false,
                                    title: lang.PLAY_NEXT,
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
                                  color: theme.dividerColor,
                                ),
                                Expanded(
                                  child: SmallListTile(
                                    color: colorDelightened.value,
                                    compact: false,
                                    title: lang.PLAY_LAST,
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
        );
      },
    ),
  );
}
