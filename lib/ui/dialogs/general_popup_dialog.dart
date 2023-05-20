import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:namida/class/queue.dart';
import 'package:namida/class/playlist.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/folders_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/edit_delete_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/dialogs/add_to_playlist_dialog.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/dialogs/track_clear_dialog.dart';
import 'package:namida/ui/dialogs/track_info_dialog.dart';
import 'package:namida/ui/widgets/library/multi_artwork_container.dart';

import 'package:namida/main_page.dart';

Future<void> showGeneralPopupDialog(
  List<Track> tracks,
  String title,
  String subtitle,
  QueueSource source, {
  void Function()? onTopBarTap,
  Playlist? playlist,
  Queue? queue,
  int? index,
  String thirdLineText = '',
  bool forceSquared = false,
  bool? forceSingleArtwork,
  bool isTrackInPlaylist = false,
  bool extractColor = true,
  bool comingFromQueue = false,
  bool useTrackTileCacheHeight = false,
  bool isCircle = false,
  bool isFromPlayerQueue = false,
  bool errorPlayingTrack = false,
  String? artistToAddFrom,
  Object? heroTag,
}) async {
  final tracksExisting = <Track>[];
  for (final t in tracks) {
    final existingTrack = Indexer.inst.allTracksMappedByPath[t.path];
    if (existingTrack != null) tracksExisting.add(existingTrack);
  }

  forceSingleArtwork ??= tracks.length == 1;
  final isSingle = tracks.length == 1;
  final doesTracksExist = !errorPlayingTrack && tracksExisting.isNotEmpty;
  final colorDelightened = extractColor ? await CurrentColor.inst.generateDelightnedColor(tracks.first.pathToImage) : CurrentColor.inst.color.value;

  final List<String> availableAlbums = tracks.map((e) => e.album).toSet().toList();
  final List<String> availableArtists = tracks.map((e) => e.artistsList).expand((list) => list).toSet().toList();
  final List<String> availableFolders = tracks.map((e) => e.path.getDirectoryPath).toSet().toList();
  final bool oneOfTheMainPlaylists = playlist?.name == k_PLAYLIST_NAME_FAV || playlist?.name == k_PLAYLIST_NAME_HISTORY || playlist?.name == k_PLAYLIST_NAME_MOST_PLAYED;
  RxInt numberOfRepeats = 1.obs;

  Widget bigIcon(IconData icon, String tooltipMessage, void Function()? onTap) {
    return InkWell(
      highlightColor: Get.theme.highlightColor,
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.0.multipliedRadius),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Tooltip(
          message: tooltipMessage,
          child: Icon(
            icon,
            color: Color.alphaBlend(colorDelightened.withAlpha(120), Get.textTheme.displayMedium!.color!),
          ),
        ),
      ),
    );
  }

  void setPlaylistMoods() {
    Get.close(1);
    TextEditingController controller = TextEditingController();
    final currentMoods = playlist!.moods.join(', ');
    controller.text = currentMoods;
    Get.dialog(
      CustomBlurryDialog(
        title: Language.inst.SET_MOODS,
        actions: [
          const CancelButton(),
          ElevatedButton(
            onPressed: () async {
              List<String> moodsPre = controller.text.split(',');
              List<String> moodsFinal = [];
              for (final m in moodsPre) {
                if (m.contains(',') || m == ' ' || m.isEmpty) {
                  continue;
                }
                moodsFinal.add(m.trim());
              }
              PlaylistController.inst.updatePropertyInPlaylist(playlist, moods: moodsFinal.toSet().toList());

              Get.close(1);
            },
            child: Text(Language.inst.SAVE),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Language.inst.SET_MOODS_SUBTITLE,
              style: Get.textTheme.displaySmall,
            ),
            const SizedBox(
              height: 20.0,
            ),
            CustomTagTextField(
              controller: controller,
              hintText: currentMoods.overflow,
              labelText: Language.inst.MOODS,
            ),
          ],
        ),
      ),
    );
  }

  void renamePlaylist() {
    Get.close(1);
    TextEditingController controller = TextEditingController(text: playlist!.name);
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    Get.dialog(
      Form(
        key: formKey,
        child: CustomBlurryDialog(
          title: Language.inst.RENAME_PLAYLIST,
          actions: [
            const CancelButton(),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  PlaylistController.inst.updatePropertyInPlaylist(playlist, name: controller.text);
                  Get.close(1);
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
                hintText: playlist.name,
                labelText: Language.inst.NAME,
                validator: (value) {
                  if (value!.isEmpty) {
                    return Language.inst.PLEASE_ENTER_A_NAME;
                  }
                  if (File('$k_DIR_PLAYLISTS/$value.json').existsSync()) {
                    return Language.inst.PLEASE_ENTER_A_DIFFERENT_NAME;
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void deletePlaylist() {
    Get.close(1);
    final pl = playlist;
    final plindex = PlaylistController.inst.playlistList.indexOf(pl);
    PlaylistController.inst.removePlaylist(playlist!);
    Get.snackbar(
      Language.inst.UNDO_CHANGES,
      Language.inst.UNDO_CHANGES_DELETED_PLAYLIST,
      mainButton: TextButton(
        onPressed: () {
          PlaylistController.inst.insertPlaylist(playlist, plindex);
          Get.closeAllSnackbars();
        },
        child: Text(Language.inst.UNDO),
      ),
    );
  }

  void updatePathDialog(String newPath) {
    Get.dialog(
      CustomBlurryDialog(
        isWarning: true,
        normalTitleStyle: true,
        bodyText: Language.inst.TRACK_PATH_OLD_NEW.replaceFirst('_OLD_NAME_', tracks.first.filenameWOExt).replaceFirst('_NEW_NAME_', newPath.getFilenameWOExt),
        actions: [
          const CancelButton(),
          ElevatedButton(
            onPressed: () {
              Get.close(2);
              EditDeleteController.inst.updateTrackPathInEveryPartOfNamida(tracks.first, newPath);
            },
            child: Text(Language.inst.CONFIRM),
          )
        ],
      ),
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
  final Widget? removeFromPlaylistListTile = (playlist != null && index != null && isTrackInPlaylist && playlist.name != k_PLAYLIST_NAME_MOST_PLAYED)
      ? SmallListTile(
          color: colorDelightened,
          compact: true,
          title: Language.inst.REMOVE_FROM_PLAYLIST,
          subtitle: playlist.name.translatePlaylistName(),
          icon: Broken.box_remove,
          onTap: () {
            NamidaOnTaps.inst.onRemoveTrackFromPlaylist(index, playlist);
            Get.close(1);
          },
        )
      : null;
  final Widget? playlistUtilsRow = (playlist != null && !isTrackInPlaylist && !oneOfTheMainPlaylists)
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
  await Get.to(
    () => NamidaBgBlur(
      blur: 5.0,
      child: GestureDetector(
        onTap: () => Get.close(1),
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
                      InkWell(
                        highlightColor: Color.fromARGB(Get.isDarkMode ? 60 : 20, 0, 0, 0),
                        splashColor: Colors.transparent,
                        onTap: () => isSingle ? showTrackInfoDialog(tracks.first, false, comingFromQueue: comingFromQueue, index: index) : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(width: 16.0),
                              if (forceSingleArtwork!)
                                Hero(
                                  tag: heroTag ?? '$comingFromQueue${index}_sussydialogs_${tracks.first.path}',
                                  child: ArtworkWidget(
                                    path: tracks.first.pathToImage,
                                    thumnailSize: 60,
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
                                      Get.close(1);
                                      final dirPath = await FilePicker.platform.getDirectoryPath();
                                      if (dirPath == null) return;

                                      final files = Directory(dirPath).listSync();
                                      files.removeWhere((element) => element is! File);
                                      final highMatchesFiles = files
                                          .where(
                                            (element) => element.path.getFilename.cleanUpForComparison.contains(tracks.first.path.getFilename.cleanUpForComparison),
                                          )
                                          .toList();
                                      Get.dialog(
                                        CustomBlurryDialog(
                                          title: Language.inst.CHOOSE,
                                          child: SizedBox(
                                            width: Get.width,
                                            height: Get.height * 0.5,
                                            child: NamidaListView(
                                              header: highMatchesFiles.isNotEmpty
                                                  ? Column(
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
                                                                title: e.path.getFilename,
                                                                onTap: () => updatePathDialog(e.path),
                                                                color: colorDelightened,
                                                                icon: Broken.medal_star,
                                                              ),
                                                            )
                                                            .toList(),
                                                        const SizedBox(height: 8.0),
                                                        const NamidaContainerDivider(),
                                                      ],
                                                    )
                                                  : null,
                                              itemBuilder: (context, i) {
                                                final f = files[i];
                                                return SmallListTile(
                                                  key: ValueKey(i),
                                                  borderRadius: 12.0,
                                                  title: f.path.getFilename,
                                                  onTap: () => updatePathDialog(f.path),
                                                );
                                              },
                                              itemCount: files.length,
                                              itemExtents: null,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  if (errorPlayingTrack)
                                    SmallListTile(
                                      title: Language.inst.SKIP,
                                      color: colorDelightened,
                                      compact: true,
                                      icon: Broken.next,
                                      onTap: () async {
                                        Get.close(1);
                                        Player.inst.next();
                                      },
                                    ),
                                ],
                                if (clearStuffListTile != null) clearStuffListTile,
                                if (removeFromPlaylistListTile != null) removeFromPlaylistListTile,
                                if (playlistUtilsRow != null) playlistUtilsRow,
                                const SizedBox(height: 8.0),
                              ],
                            )
                          :

                          /// List Items
                          Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (availableAlbums.length == 1)
                                  SmallListTile(
                                    color: colorDelightened,
                                    compact: true,
                                    title: Language.inst.GO_TO_ALBUM,
                                    subtitle: availableAlbums.first,
                                    icon: Broken.music_dashboard,
                                    onTap: () {
                                      Get.close(1);
                                      NamidaOnTaps.inst.onAlbumTap(availableAlbums.first);
                                    },
                                    trailing: IconButton(
                                      tooltip: Language.inst.ADD_MORE_FROM_THIS_ALBUM,
                                      onPressed: () {
                                        Get.close(1);
                                        Player.inst.addToQueue(generateTracksFromAlbum(availableAlbums.first), insertNext: true);
                                      },
                                      icon: const Icon(Broken.add),
                                    ),
                                  ),

                                if (availableAlbums.length > 1)
                                  ExpansionTile(
                                    expandedAlignment: Alignment.centerLeft,
                                    leading: Icon(
                                      Broken.music_dashboard,
                                      color: Color.alphaBlend(colorDelightened.withAlpha(120), Get.textTheme.displayMedium!.color!),
                                    ),
                                    trailing: IconButton(
                                      onPressed: () {},
                                      icon: const Icon(Broken.arrow_down_2, size: 20.0),
                                    ),
                                    title: Text(
                                      Language.inst.GO_TO_ALBUM,
                                      style: Get.textTheme.displayMedium?.copyWith(
                                        color: Color.alphaBlend(colorDelightened.withAlpha(40), Get.textTheme.displayMedium!.color!),
                                      ),
                                    ),
                                    childrenPadding: const EdgeInsets.symmetric(horizontal: 20.0).add(const EdgeInsets.only(bottom: 12.0)),
                                    children: [
                                      Wrap(
                                        alignment: WrapAlignment.start,
                                        children: [
                                          ...availableAlbums
                                              .map(
                                                (e) => Padding(
                                                  padding: const EdgeInsets.all(2.0),
                                                  child: InkWell(
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
                                      Get.close(1);
                                      Player.inst.addToQueue(generateTracksFromArtist(artistToAddFrom), insertNext: true);
                                    },
                                    trailing: IconButton(
                                      tooltip: Language.inst.ADD_MORE_FROM_THIS_ARTIST,
                                      onPressed: () {
                                        Get.close(1);
                                        Player.inst.addToQueue(generateTracksFromArtist(artistToAddFrom), insertNext: true);
                                      },
                                      icon: const Icon(Broken.add),
                                    ),
                                  ),
                                if (artistToAddFrom == null && availableArtists.length == 1)
                                  SmallListTile(
                                    color: colorDelightened,
                                    compact: true,
                                    title: Language.inst.GO_TO_ARTIST,
                                    subtitle: availableArtists.first,
                                    icon: Broken.microphone,
                                    onTap: () {
                                      Get.close(1);
                                      NamidaOnTaps.inst.onArtistTap(availableArtists.first);
                                    },
                                    trailing: IconButton(
                                      tooltip: Language.inst.ADD_MORE_FROM_THIS_ARTIST,
                                      onPressed: () => Player.inst.addToQueue(generateTracksFromArtist(availableArtists.first), insertNext: true),
                                      icon: const Icon(Broken.add),
                                    ),
                                  ),

                                if (artistToAddFrom == null && availableArtists.length > 1)
                                  ExpansionTile(
                                    expandedAlignment: Alignment.centerLeft,
                                    leading: Icon(
                                      Broken.profile_2user,
                                      color: Color.alphaBlend(colorDelightened.withAlpha(120), Get.textTheme.displayMedium!.color!),
                                    ),
                                    trailing: IconButton(
                                      onPressed: () {},
                                      icon: const Icon(Broken.arrow_down_2, size: 20.0),
                                    ),
                                    title: Text(
                                      Language.inst.GO_TO_ARTIST,
                                      style: Get.textTheme.displayMedium?.copyWith(
                                        color: Color.alphaBlend(colorDelightened.withAlpha(40), Get.textTheme.displayMedium!.color!),
                                      ),
                                    ),
                                    childrenPadding: const EdgeInsets.symmetric(horizontal: 20.0).add(const EdgeInsets.only(bottom: 12.0)),
                                    children: [
                                      Wrap(
                                        alignment: WrapAlignment.start,
                                        children: [
                                          ...availableArtists
                                              .map(
                                                (e) => Padding(
                                                  padding: const EdgeInsets.all(2.0),
                                                  child: InkWell(
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
                                    subtitle: availableFolders.first.split('/').last,
                                    icon: Broken.folder,
                                    onTap: () {
                                      Get.close(1);
                                      Get.offAll(MainPageWrapper());
                                      ScrollSearchController.inst.animatePageController(LibraryTab.folders.toInt);
                                      NamidaOnTaps.inst.onFolderOpen(Folders.inst.folderslist.firstWhere((element) => element.path == availableFolders.first), false);
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
                                  onTap: () {
                                    Get.close(1);
                                    Share.shareXFiles(tracksExisting.map((e) => XFile(e.path)).toList());
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
                                              Get.close(1);
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
                                          Get.close(1);
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
                                      Get.close(1);
                                      Player.inst.playOrPause(0, tracks, source, shuffle: true);
                                    },
                                  ),

                                SmallListTile(
                                  color: colorDelightened,
                                  compact: false,
                                  title: Language.inst.ADD_TO_PLAYLIST,
                                  icon: Broken.music_library_2,
                                  onTap: () {
                                    Get.close(1);
                                    showAddToPlaylistDialog(tracks);
                                  },
                                ),
                                SmallListTile(
                                  color: colorDelightened,
                                  compact: false,
                                  title: Language.inst.EDIT_TAGS,
                                  icon: Broken.edit,
                                  onTap: () {
                                    Get.close(1);
                                    if (isSingle) {
                                      showEditTrackTagsDialog(tracks.first);
                                    } else {
                                      editMultipleTracksTags(tracks);
                                    }
                                  },
                                ),
                                if (clearStuffListTile != null) clearStuffListTile,
                                if (isSingle)
                                  SmallListTile(
                                    color: colorDelightened,
                                    compact: false,
                                    title: Language.inst.SET_YOUTUBE_LINK,
                                    icon: Broken.edit_2,
                                    trailing: NamidaIconButton(
                                      icon: Broken.login_1,
                                      iconColor: Color.alphaBlend(colorDelightened.withAlpha(120), Get.textTheme.displayMedium!.color!),
                                      onPressed: () {
                                        final link = tracks.first.youtubeLink;
                                        if (link == '') {
                                          Get.snackbar(Language.inst.COULDNT_OPEN, Language.inst.COULDNT_OPEN_YT_LINK);
                                          return;
                                        }
                                        launchUrlString(
                                          link,
                                          mode: LaunchMode.externalNonBrowserApplication,
                                        );
                                      },
                                    ),
                                    onTap: () async {
                                      Get.close(1);

                                      final GlobalKey<FormState> formKey = GlobalKey<FormState>();
                                      TextEditingController controller = TextEditingController();
                                      final ytlink = tracks.first.youtubeLink;
                                      controller.text = ytlink;
                                      Get.dialog(
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
                                                    Get.close(1);
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
                                    },
                                  ),
                                if (queue != null)
                                  SmallListTile(
                                    color: colorDelightened,
                                    compact: false,
                                    title: Language.inst.REMOVE_QUEUE,
                                    icon: Broken.pen_remove,
                                    onTap: () {
                                      final q = queue;
                                      final qindex = QueueController.inst.queueList.indexOf(q);
                                      QueueController.inst.removeQueue(queue);
                                      Get.snackbar(
                                        Language.inst.UNDO_CHANGES,
                                        Language.inst.UNDO_CHANGES_DELETED_QUEUE,
                                        mainButton: TextButton(
                                          onPressed: () {
                                            QueueController.inst.insertQueue(q, qindex);
                                            Get.closeAllSnackbars();
                                          },
                                          child: Text(Language.inst.UNDO),
                                        ),
                                      );
                                      Get.close(1);
                                    },
                                  ),
                                if (playlistUtilsRow != null) playlistUtilsRow,

                                if (removeFromPlaylistListTile != null) removeFromPlaylistListTile,

                                if (Player.inst.latestInsertedIndex != Player.inst.currentIndex.value)
                                  SmallListTile(
                                    color: colorDelightened,
                                    compact: true,
                                    title: '${Language.inst.PLAY_AFTER} "${Player.inst.currentQueue.elementAt(Player.inst.latestInsertedIndex).title}"',
                                    icon: Broken.hierarchy_square,
                                    onTap: () {
                                      Get.close(1);
                                      Player.inst.addToQueue(tracks, insertAfterLatest: true);
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
                                        Get.close(1);
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
                                            iconColor: Color.alphaBlend(colorDelightened.withAlpha(120), Get.textTheme.displayMedium!.color!),
                                          ),
                                          NamidaIconButton(
                                            icon: Broken.add_circle,
                                            onPressed: () => numberOfRepeats.value = (numberOfRepeats.value + 1).clamp(1, 20),
                                            iconSize: 20.0,
                                            iconColor: Color.alphaBlend(colorDelightened.withAlpha(120), Get.textTheme.displayMedium!.color!),
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
                                          Get.close(1);
                                          Player.inst.addToQueue(tracks, insertNext: true);
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
                                          Get.close(1);
                                          Player.inst.addToQueue(tracks);
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
    opaque: false,
    transition: Transition.fade,
    fullscreenDialog: true,
  );
}
