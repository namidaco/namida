import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:rhttp/rhttp.dart';

import 'package:namida/class/file_parts.dart';
import 'package:namida/class/folder.dart';
import 'package:namida/class/queue.dart';
import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/edit_delete_controller.dart';
import 'package:namida/controller/file_browser.dart';
import 'package:namida/controller/generators_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/lyrics_search_utils/lrc_search_utils_selectable.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/namida_channel/namida_channel.dart';
import 'package:namida/controller/platform/namida_storage/namida_storage.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/tagger_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/main.dart';
import 'package:namida/packages/three_arched_circle.dart';
import 'package:namida/ui/dialogs/add_to_playlist_dialog.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/dialogs/set_lrc_dialog.dart';
import 'package:namida/ui/dialogs/track_advanced_dialog.dart';
import 'package:namida/ui/dialogs/track_info_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/multi_artwork_container.dart';
import 'package:namida/ui/widgets/network_artwork.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/pages/yt_channel_subpage.dart';

Future<void> showGeneralPopupDialog(
  List<Track> tracks,
  String title,
  String subtitle,
  QueueSource source, {
  NetworkArtworkInfo? networkArtworkInfo,
  CustomArtworkManager? customArtworkManager,
  void Function()? onTopBarTap,
  String? playlistName,
  List<TrackWithDate> tracksWithDates = const <TrackWithDate>[],
  Queue? queue,
  int? index,
  String thirdLineText = '',
  bool forceSquared = false,
  bool? forceSingleArtwork,
  bool extractColor = true,
  bool isCircle = false,
  bool isFromPlayerQueue = false,
  Object? errorPlayingTrack,
  String? artistToAddFrom,
  (String, String)? albumToAddFrom,
  String? heroTag,
  IconData? trailingIcon,
  bool comingFromPlaylistMenu = false,
  bool showPlayAllReverse = false,
}) async {
  final isSingle = tracks.length == 1;
  forceSingleArtwork ??= isSingle;

  final tracksExisting = <Track>[];
  if (isSingle || errorPlayingTrack != null) {
    // -- fill using real-time checks if there was an error.
    final int length = tracks.length;
    for (int i = 0; i < length; i++) {
      final t = tracks[i];
      if (t.existsSync()) tracksExisting.add(t);
    }
  } else {
    tracks.loop((t) {
      if (t.hasInfoInLibrary()) tracksExisting.add(t);
    });
  }

  final trackToExtractColorFrom = tracks.isEmpty
      ? null
      : forceSingleArtwork
          ? tracks[tracks.indexOfImage]
          : tracks.first;

  final colorDelightened = Colors.transparent.obso;
  final iconColor = Colors.transparent.obso;

  void onColorsObtained(Color color) {
    if (colorDelightened.value == color) return;
    colorDelightened.value = color;
    iconColor.value = Color.alphaBlend(color.withAlpha(120), namida.textTheme.displayMedium!.color!);
  }

  onColorsObtained(CurrentColor.inst.color);

  if (extractColor && trackToExtractColorFrom != null) {
    final colorSync = CurrentColor.inst.getTrackDelightnedColorSync(trackToExtractColorFrom, networkArtworkInfo);
    if (colorSync != null) {
      onColorsObtained(colorSync);
    } else {
      CurrentColor.inst
          .getTrackDelightnedColor(trackToExtractColorFrom, networkArtworkInfo, useIsolate: true)
          .executeWithMinDelay(
            delayMS: NamidaNavigator.kDefaultDialogDurationMS,
          )
          .then(onColorsObtained);
    }
  }

  /// name, identifier
  final List<(String, String)> availableAlbums = tracks.mappedUniqued((e) {
    final ext = e.toTrackExt();
    return (ext.album, ext.albumIdentifier);
  });
  final List<String> availableArtists = tracks.mappedUniquedList((e) => e.toTrackExt().artistsList);
  final List<Folder> availableFolders = tracks.mapAsPhysical().mappedUniqued((e) => e.folder);

  final Iterable<YoutubeID> availableYoutubeIDs = tracks.map((e) => YoutubeID(id: e.youtubeID, playlistID: null)).where((element) => element.id.isNotEmpty);
  final String? firstVideolId = availableYoutubeIDs.firstOrNull?.id;

  final numberOfRepeats = 1.obso;
  final isLoadingFilesToShare = false.obso;

  bool shoulShowPlaylistUtils() => comingFromPlaylistMenu && playlistName != null && !PlaylistController.inst.isOneOfDefaultPlaylists(playlistName);
  bool shoulShowRemoveFromPlaylist() => !comingFromPlaylistMenu && tracksWithDates.isNotEmpty && playlistName != null && playlistName != k_PLAYLIST_NAME_MOST_PLAYED;

  if (networkArtworkInfo != null) {
    // -- nullify if network not allowed
    final isNetworkAllowed = networkArtworkInfo.settingsKey.value.any((element) => element.isNetwork);
    if (!isNetworkAllowed) networkArtworkInfo = null;
  }

  customArtworkManager ??= networkArtworkInfo?.toManager();
  if (customArtworkManager == null && playlistName != null && shoulShowPlaylistUtils()) {
    customArtworkManager = CustomArtworkManager.playlist(playlistName);
  }

  Widget bigIcon(IconData icon, String Function() tooltipMessage, void Function()? onTap, {String subtitle = '', Widget? iconWidget}) {
    return NamidaInkWell(
      onTap: onTap,
      borderRadius: 8.0,
      child: NamidaTooltip(
        message: tooltipMessage,
        preferBelow: false,
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            children: [
              iconWidget ??
                  ObxO(
                    rx: iconColor,
                    builder: (context, color) => Icon(
                      icon,
                      color: color,
                    ),
                  ),
              if (subtitle != '') ...[
                const SizedBox(height: 2.0),
                Text(
                  subtitle,
                  style: namida.textTheme.displaySmall?.copyWith(fontSize: 12.0),
                  maxLines: 1,
                )
              ]
            ],
          ),
        ),
      ),
    );
  }

  Future<void> openDialog(Widget Function(ThemeData theme) widgetBuilder, {void Function()? onDisposing, bool Function()? tapToDismiss}) async {
    final color = colorDelightened.value; // we dont react cz main dialog can close and dispose this.
    await NamidaNavigator.inst.navigateDialog(
      colorScheme: color,
      lighterDialogColor: true,
      onDisposing: onDisposing,
      tapToDismiss: tapToDismiss,
      dialogBuilder: widgetBuilder,
    );
  }

  void cancelSkipTimer() => Player.inst.cancelPlayErrorSkipTimer();

  Rx<TrackStats>? statsWrapper;
  final firstTrack = tracks.firstOrNull;
  if (firstTrack != null) {
    statsWrapper = TrackStats.buildEffective(firstTrack).obs;
  }

  void setTrackStatsDialog() {
    showSetTrackStatsDialog(
      firstTrack: firstTrack,
      stats: statsWrapper!.value,
      onEdit: (newStat) => statsWrapper!.value = newStat,
      colorScheme: colorDelightened.value,
      iconColor: iconColor.value,
    );
  }

  void setPlaylistMoods() async {
    // function button won't be visible if playlistName == null.
    if (!shoulShowPlaylistUtils()) return;
    cancelSkipTimer();

    final pl = PlaylistController.inst.getPlaylist(playlistName!);
    if (pl == null) return;

    final initialMoods = pl.moods.join(', ');

    final playlistMoodsController = TextEditingController(text: initialMoods);
    await openDialog(
      onDisposing: () {
        playlistMoodsController.dispose();
      },
      (theme) => CustomBlurryDialog(
        title: lang.MOODS,
        actions: [
          const CancelButton(),
          NamidaButton(
            text: lang.SAVE,
            onPressed: () async {
              final newMoods = Indexer.splitByCommaList(playlistMoodsController.text);
              PlaylistController.inst.updatePropertyInPlaylist(playlistName, moods: newMoods);
              NamidaNavigator.inst.closeDialog();
            },
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12.0),
            CustomTagTextField(
              controller: playlistMoodsController,
              hintText: initialMoods,
              labelText: lang.SET_MOODS,
            ),
            const SizedBox(height: 8.0),
            Text(
              lang.SET_MOODS_SUBTITLE,
              style: theme.textTheme.displaySmall,
            ),
          ],
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
      (theme) => Form(
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
    await NamidaDialogs.inst.showDeletePlaylistDialog(pl, withUndo: true);
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

    final savePath = FileParts.joinPath(AppDirs.M3UPlaylists, "${pl.name}.m3u");
    await PlaylistController.inst.exportPlaylistToM3UFile(pl, savePath);
    snackyy(
      message: "${lang.SAVED_IN}: $savePath",
      leftBarIndicatorColor: colorDelightened.value,
      altDesign: true,
      top: false,
    );
  }

  void updatePathDialog(String newPath) async {
    final isUpdating = false.obs;
    await openDialog(
      onDisposing: () {
        isUpdating.close();
      },
      tapToDismiss: () => !isUpdating.value,
      (theme) => CustomBlurryDialog(
        isWarning: true,
        normalTitleStyle: true,
        bodyText: lang.TRACK_PATH_OLD_NEW.replaceFirst('_OLD_NAME_', tracks.first.filenameWOExt).replaceFirst('_NEW_NAME_', newPath.getFilenameWOExt),
        actions: [
          const CancelButton(),
          ObxO(
            rx: isUpdating,
            builder: (context, updating) => AnimatedEnabled(
              enabled: !updating,
              child: NamidaButton(
                text: lang.CONFIRM,
                onPressed: () async {
                  isUpdating.value = true;
                  await EditDeleteController.inst.updateTrackPathInEveryPartOfNamida(tracks.first, newPath);
                  isUpdating.value = false;
                  NamidaNavigator.inst.closeDialog(2);
                },
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget highMatchesWidget(Iterable<String> highMatchesFiles, {bool showFullPath = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lang.HIGH_MATCHES,
          style: namida.textTheme.displayMedium,
        ),
        const SizedBox(height: 8.0),
        ...highMatchesFiles.map(
          (e) => SmallListTile(
            borderRadius: 12.0,
            title: showFullPath ? e : e.getFilename,
            subtitle: File(e).fileSizeFormatted(),
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
    final dirPath = await NamidaFileBrowser.getDirectory(note: lang.PICK_FROM_STORAGE);
    if (dirPath == null) return;

    final files = await Directory(dirPath).listAllIsolate();
    files.removeWhere((element) => element is! File);
    if (files.isEmpty) {
      snackyy(title: lang.ERROR, message: lang.NO_TRACKS_FOUND_IN_DIRECTORY);
      return;
    }

    final paths = files.mapped((e) => e.path);
    paths.sortBy((e) => e);

    final highMatchesFiles = NamidaGenerator.getHighMatcheFilesFromFilename(paths, tracks.first.path);

    /// Searching
    final txtc = TextEditingController();
    final filteredPaths = List<String>.from(paths).obso;
    final shouldCleanUp = true.obso;

    await openDialog(
      onDisposing: () {
        filteredPaths.close();
        shouldCleanUp.close();
        txtc.dispose();
      },
      (theme) => CustomBlurryDialog(
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
          width: namida.width,
          height: namida.height * 0.5,
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
                  ObxO(
                    rx: shouldCleanUp,
                    builder: (context, cleanup) => NamidaIconButton(
                      tooltip: () => shouldCleanUp.value ? lang.DISABLE_SEARCH_CLEANUP : lang.ENABLE_SEARCH_CLEANUP,
                      icon: cleanup ? Broken.shield_cross : Broken.shield_search,
                      onPressed: () => shouldCleanUp.value = !shouldCleanUp.value,
                    ),
                  )
                ],
              ),
              const SizedBox(height: 8.0),
              Expanded(
                child: ObxO(
                  rx: filteredPaths,
                  builder: (context, filtered) => NamidaListView(
                    header: highMatchesFiles.isNotEmpty ? highMatchesWidget(highMatchesFiles) : null,
                    itemBuilder: (context, i) {
                      final p = filtered[i];
                      return SmallListTile(
                        key: ValueKey(i),
                        borderRadius: 12.0,
                        title: p.getFilename,
                        subtitle: File(p).fileSizeFormatted(),
                        onTap: () => updatePathDialog(p),
                      );
                    },
                    itemCount: filtered.length,
                    itemExtent: null,
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

  final advancedStuffListTile = tracksWithDates.isEmpty && tracks.isEmpty
      ? null
      : ObxO(
          rx: colorDelightened,
          builder: (context, colorDelightened) => SmallListTile(
            color: colorDelightened,
            compact: false,
            title: lang.ADVANCED,
            icon: Broken.code_circle,
            onTap: () {
              cancelSkipTimer();
              showTrackAdvancedDialog(
                tracks: tracksWithDates.isNotEmpty ? tracksWithDates : tracks,
                networkArtworkInfo: networkArtworkInfo,
                colorScheme: colorDelightened,
                source: source,
                albumsUniqued: availableAlbums,
              );
            },
          ),
        );

  final Widget? removeFromPlaylistListTile = shoulShowRemoveFromPlaylist()
      ? ObxO(
          rx: colorDelightened,
          builder: (context, colorDelightened) => SmallListTile(
            color: colorDelightened,
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
              Expanded(child: bigIcon(Broken.smileys, () => lang.SET_MOODS, setPlaylistMoods)),
              const SizedBox(width: 8.0),
              Expanded(child: bigIcon(Broken.edit_2, () => lang.RENAME_PLAYLIST, renamePlaylist)),
              const SizedBox(width: 8.0),
              Expanded(
                child: bigIcon(
                  Broken.edit_2,
                  () => lang.REMOVE_DUPLICATES,
                  removePlaylistDuplicates,
                  iconWidget: ObxO(
                    rx: iconColor,
                    builder: (context, iconColor) => StackedIcon(
                      baseIcon: Broken.copy,
                      secondaryIcon: Broken.broom,
                      baseIconColor: iconColor,
                      secondaryIconColor: iconColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8.0),
              Expanded(child: bigIcon(Broken.trash, () => lang.DELETE_PLAYLIST, deletePlaylist)),
              if (PlaylistController.inst.getPlaylist(playlistName ?? '')?.m3uPath == null) ...[
                const SizedBox(width: 8.0),
                Expanded(child: bigIcon(Broken.directbox_send, () => lang.EXPORT_AS_M3U, exportPlaylist)),
              ],
              const SizedBox(width: 24.0),
            ],
          ),
        )
      : null;

  final Widget? removeQueueTile = queue != null
      ? ObxO(
          rx: colorDelightened,
          builder: (context, colorDelightened) => SmallListTile(
            color: colorDelightened,
            compact: false,
            title: lang.REMOVE_QUEUE,
            icon: Broken.trash,
            onTap: () {
              cancelSkipTimer();
              NamidaOnTaps.inst.onQueueDelete(queue);
              NamidaNavigator.inst.closeDialog();
            },
          ),
        )
      : null;

  final hasHeaderTap = isSingle;

  if (hasHeaderTap && trailingIcon == null) trailingIcon = Broken.arrow_right_3;

  final artworkFile = customArtworkManager?.getArtworkFile();
  final artworkFileGood = artworkFile != null && artworkFile.existsSync() && (artworkFile.fileSizeSync() ?? 0) > 0;

  NamidaNavigator.inst.navigateDialog(
    onDisposing: () {
      numberOfRepeats.close();
      isLoadingFilesToShare.close();
      statsWrapper?.close();
      colorDelightened.close();
      iconColor.close();
    },
    lighterDialogColor: false,
    durationInMs: 400,
    scale: 0.92,
    onDismissing: cancelSkipTimer,
    dialog: ObxO(
      rx: colorDelightened,
      builder: (context, colorDelightened) {
        final theme = AppThemes.inst.getAppTheme(colorDelightened, null, false);
        final iconColor = Color.alphaBlend(colorDelightened.withAlpha(120), theme.textTheme.displayMedium!.color!);
        double horizontalMargin = Dimensions.calculateDialogHorizontalMargin(context, 34.0);

        final openInYtViewWidget = availableYoutubeIDs.isNotEmpty
            ? SmallListTile(
                color: colorDelightened,
                compact: true,
                title: lang.OPEN_IN_YOUTUBE_VIEW,
                icon: Broken.video,
                onTap: () {
                  NamidaNavigator.inst.closeDialog();
                  Player.inst.playOrPause(0, availableYoutubeIDs, QueueSource.others, gentlePlay: true);
                },
                trailing: isSingle && firstVideolId != null
                    ? FutureBuilder(
                        future: YoutubeInfoController.utils.getVideoChannelID(firstVideolId),
                        builder: (context, snapshot) {
                          final firstVideoChannelId = snapshot.data;
                          return firstVideoChannelId != null
                              ? IconButton(
                                  tooltip: lang.GO_TO_CHANNEL,
                                  icon: Icon(
                                    Broken.user,
                                    size: 20.0,
                                    color: iconColor,
                                  ),
                                  iconSize: 20.0,
                                  onPressed: YTChannelSubpage(channelID: firstVideoChannelId).navigate,
                                )
                              : const SizedBox();
                        },
                      )
                    : null,
              )
            : null;

        return AnimatedThemeOrTheme(
          data: theme,
          child: Dialog(
            backgroundColor: theme.dialogTheme.backgroundColor,
            insetPadding: EdgeInsets.symmetric(horizontal: horizontalMargin, vertical: 24.0),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: kDialogMaxWidth),
              child: SmoothSingleChildScrollView(
                child: Column(
                  children: [
                    /// Top Widget
                    NamidaInkWell(
                      borderRadius: 0.0,
                      onTap: () => isSingle
                          ? showTrackInfoDialog(
                              tracks.first,
                              false,
                              networkArtworkInfo: networkArtworkInfo,
                              colorScheme: colorDelightened,
                              heroTag: heroTag,
                            )
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(width: 16.0),
                            if (forceSingleArtwork! || artworkFileGood)
                              NamidaHero(
                                tag: heroTag,
                                child: NetworkArtwork.orLocal(
                                  key: Key(tracks.pathToImage),
                                  fadeMilliSeconds: 0,
                                  track: tracks.trackOfImage,
                                  path: artworkFileGood ? artworkFile.path : tracks.pathToImage,
                                  info: artworkFileGood ? networkArtworkInfo : null,
                                  thumbnailSize: 60,
                                  forceSquared: forceSquared,
                                  borderRadius: isCircle ? 200 : 8.0,
                                  isCircle: isCircle,
                                ),
                              )
                            else
                              MultiArtworkContainer(
                                heroTag: heroTag ?? 'edittags_artwork',
                                fadeMilliSeconds: 0,
                                size: 60,
                                tracks: tracks.toImageTracks(),
                                fallbackToFolderCover: false,
                                margin: EdgeInsets.zero,
                                artworkFile: artworkFile,
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
                                        fontSize: 17.0,
                                        height: 1.2,
                                        color: Color.alphaBlend(colorDelightened.withAlpha(40), theme.textTheme.displayMedium!.color!),
                                      ),
                                    ),
                                  if (subtitle.isNotEmpty)
                                    Text(
                                      subtitle.overflow,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: theme.textTheme.displayMedium?.copyWith(
                                        fontSize: 14.0,
                                        height: 1.1,
                                        color: Color.alphaBlend(colorDelightened.withAlpha(80), theme.textTheme.displayMedium!.color!),
                                      ),
                                    ),
                                  if (thirdLineText.isNotEmpty) ...[
                                    Text(
                                      thirdLineText.overflow,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: theme.textTheme.displaySmall?.copyWith(
                                        fontSize: 12.5,
                                        height: 1.0,
                                        color: Color.alphaBlend(colorDelightened.withAlpha(40), theme.textTheme.displayMedium!.color!),
                                      ),
                                    ),
                                  ]
                                ],
                              ),
                            ),
                            const SizedBox(width: 16.0),
                            if (customArtworkManager != null) ...[
                              _ArtworkManager(
                                customArtworkManager: customArtworkManager,
                              ),
                              const SizedBox(width: 16.0),
                            ] else ...[
                              Icon(trailingIcon),
                              const SizedBox(width: 16.0),
                            ],
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
                                      color: Colors.red.withValues(alpha: 0.3),
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
                                  color: colorDelightened,
                                  compact: true,
                                  icon: Broken.document_upload,
                                  onTap: () async {
                                    cancelSkipTimer();
                                    NamidaNavigator.inst.closeDialog();
                                    if (Indexer.inst.allAudioFiles.value.isEmpty) {
                                      await Indexer.inst.getAudioFiles();
                                    }

                                    /// firstly checks if a file exists in current library
                                    final firstHighMatchesFiles = NamidaGenerator.getHighMatcheFilesFromFilename(Indexer.inst.allAudioFiles.value, tracks.first.path);
                                    if (firstHighMatchesFiles.isNotEmpty) {
                                      await openDialog(
                                        (theme) => CustomBlurryDialog(
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
                                  ObxO(
                                    rx: Player.inst.playErrorRemainingSecondsToSkip,
                                    builder: (context, remainingSecondsToSkip) => SmallListTile(
                                      title: lang.SKIP,
                                      subtitle: remainingSecondsToSkip <= 0 ? null : '$remainingSecondsToSkip ${lang.SECONDS}',
                                      color: colorDelightened,
                                      compact: true,
                                      icon: Broken.next,
                                      trailing: remainingSecondsToSkip <= 0
                                          ? null
                                          : NamidaIconButton(
                                              icon: Broken.close_circle,
                                              iconColor: namida.context?.defaultIconColor(colorDelightened, theme.textTheme.displayMedium?.color),
                                              onPressed: cancelSkipTimer,
                                            ),
                                      onTap: () {
                                        cancelSkipTimer();
                                        NamidaNavigator.inst.closeDialog();
                                        Player.inst.next();
                                      },
                                    ),
                                  ),
                              ],
                              if (openInYtViewWidget != null) openInYtViewWidget,
                              if (removeFromPlaylistListTile != null) removeFromPlaylistListTile,
                              if (playlistUtilsRow != null) playlistUtilsRow,
                              if (removeQueueTile != null) removeQueueTile,
                              if (advancedStuffListTile != null) advancedStuffListTile,
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
                                  color: colorDelightened,
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
                                  textColorScheme: colorDelightened,
                                  childrenPadding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 12.0, top: 0),
                                  children: [
                                    Wrap(
                                      alignment: WrapAlignment.start,
                                      children: [
                                        ...availableAlbums.map(
                                          (e) => _SmallUnderlinedChip(
                                            text: e.$1,
                                            textTheme: theme.textTheme,
                                            onTap: () => NamidaOnTaps.inst.onAlbumTap(e.$2),
                                          ),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              if (artistToAddFrom != null)
                                SmallListTile(
                                  color: colorDelightened,
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
                                  color: colorDelightened,
                                  compact: true,
                                  title: lang.GO_TO_ARTIST,
                                  subtitle: availableArtists.first,
                                  icon: Broken.microphone,
                                  onTap: () => NamidaOnTaps.inst.onArtistTap(availableArtists.first, MediaType.artist),
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
                                  textColorScheme: colorDelightened,
                                  childrenPadding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 12.0, top: 0),
                                  children: [
                                    Wrap(
                                      alignment: WrapAlignment.start,
                                      children: [
                                        ...availableArtists.map(
                                          (e) => _SmallUnderlinedChip(
                                            text: e,
                                            textTheme: theme.textTheme,
                                            onTap: () => NamidaOnTaps.inst.onArtistTap(e, MediaType.artist),
                                          ),
                                        ),
                                      ],
                                    )
                                  ],
                                ),

                              /// Folders
                              if (availableFolders.length == 1)
                                SmallListTile(
                                  color: colorDelightened,
                                  compact: true,
                                  title: lang.GO_TO_FOLDER,
                                  subtitle: availableFolders.first.folderNameAvoidingConflicts(),
                                  icon: availableFolders.first is VideoFolder ? Broken.video_play : Broken.folder,
                                  onTap: () {
                                    NamidaNavigator.inst.closeDialog();
                                    NamidaOnTaps.inst.onFolderTapNavigate(availableFolders.first, null, trackToScrollTo: tracks.first);
                                  },
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (NamidaChannel.inst.canOpenFileInExplorer && tracksExisting.isNotEmpty)
                                        IconButton(
                                          tooltip: lang.OPEN_IN_FILE_EXPLORER,
                                          onPressed: () {
                                            final path = tracksExisting.firstOrNull?.asPhysical()?.path ?? availableFolders.first.path;
                                            NamidaChannel.inst.openFileInExplorer(path);
                                          },
                                          icon: const Icon(
                                            Broken.export_1,
                                            size: 20.0,
                                          ),
                                        ),
                                      IconButton(
                                        tooltip: lang.ADD_MORE_FROM_THIS_FOLDER,
                                        onPressed: () {
                                          final tracks = availableFolders.first.tracksDedicated();
                                          Player.inst.addToQueue(tracks, insertNext: true, insertionType: QueueInsertionType.moreFolder);
                                        },
                                        icon: const Icon(
                                          Broken.add,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              if (!isSingle)
                                SmallListTile(
                                  color: colorDelightened,
                                  compact: false,
                                  title: lang.SHARE,
                                  icon: Broken.share,
                                  trailing: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                    child: ObxO(
                                      rx: isLoadingFilesToShare,
                                      builder: (context, loading) => loading ? const LoadingIndicator() : const SizedBox(),
                                    ),
                                  ),
                                  onTap: () async {
                                    final trs = tracksExisting.mapPhysicalOrError((tr) => tr.path);
                                    if (trs.isEmpty) return;
                                    isLoadingFilesToShare.value = true;
                                    await NamidaUtils.shareFiles(trs);
                                    isLoadingFilesToShare.value = false;
                                    NamidaNavigator.inst.closeDialog();
                                  },
                                ),

                              if (!isSingle)
                                SmallListTile(
                                  color: colorDelightened,
                                  compact: false,
                                  title: lang.PLAY_ALL,
                                  icon: Broken.play_circle,
                                  onTap: () {
                                    NamidaNavigator.inst.closeDialog();
                                    Player.inst.playOrPause(0, tracks, source);
                                  },
                                  trailing: showPlayAllReverse
                                      ? IconButton(
                                          tooltip: "${lang.PLAY_ALL} (${lang.REVERSE_ORDER})",
                                          icon: StackedIcon(
                                            baseIcon: Broken.play_cricle,
                                            secondaryIcon: Broken.arrow_swap,
                                            iconSize: 20.0,
                                            secondaryIconSize: 10.0,
                                            baseIconColor: iconColor,
                                          ),
                                          iconSize: 20.0,
                                          onPressed: () {
                                            NamidaNavigator.inst.closeDialog();
                                            Player.inst.playOrPause(0, tracks.reversed, source);
                                          },
                                        )
                                      : null,
                                ),

                              if (!isSingle)
                                SmallListTile(
                                  color: colorDelightened,
                                  compact: false,
                                  title: lang.SHUFFLE,
                                  icon: Broken.shuffle,
                                  onTap: () {
                                    NamidaNavigator.inst.closeDialog();
                                    Player.inst.playOrPause(0, tracks, source, shuffle: true);
                                  },
                                ),

                              SmallListTile(
                                color: colorDelightened,
                                compact: false,
                                title: lang.ADD_TO_PLAYLIST,
                                icon: Broken.music_library_2,
                                onTap: () {
                                  NamidaNavigator.inst.closeDialog();
                                  showAddToPlaylistDialog(tracks);
                                },
                              ),
                              SmallListTile(
                                color: colorDelightened,
                                compact: false,
                                title: lang.EDIT_TAGS,
                                icon: Broken.edit,
                                onTap: () {
                                  final trs = tracks.asPhysicalOrError();
                                  if (trs.isEmpty) return;
                                  NamidaNavigator.inst.closeDialog();
                                  showEditTracksTagsDialog(trs, colorDelightened);
                                },
                                trailing: isSingle
                                    ? IconButton(
                                        tooltip: lang.LYRICS,
                                        icon: FutureBuilder(
                                          future: LrcSearchUtilsSelectable(tracks.first.toTrackExt(), tracks.first).hasLyrics(),
                                          builder: (context, snapshot) {
                                            return snapshot.data == true
                                                ? StackedIcon(
                                                    baseIcon: Broken.document,
                                                    secondaryIcon: Broken.tick_circle,
                                                    iconSize: 20.0,
                                                    secondaryIconSize: 10.0,
                                                    baseIconColor: iconColor,
                                                    secondaryIconColor: iconColor,
                                                  )
                                                : Icon(
                                                    Broken.document,
                                                    size: 20.0,
                                                    color: iconColor,
                                                  );
                                          },
                                        ),
                                        iconSize: 20.0,
                                        onPressed: () => showLRCSetDialog(tracks.first, colorDelightened),
                                      )
                                    : null,
                              ),
                              // --- Advanced dialog
                              if (advancedStuffListTile != null) advancedStuffListTile,

                              if (openInYtViewWidget != null) openInYtViewWidget,

                              if (removeQueueTile != null) removeQueueTile,

                              if (Player.inst.currentItem.value is Selectable && Player.inst.latestInsertedIndex > Player.inst.currentIndex.value)
                                () {
                                  final playAfterTrack = (Player.inst.currentQueue.value[Player.inst.latestInsertedIndex] as Selectable).track;
                                  return SmallListTile(
                                    color: colorDelightened,
                                    compact: true,
                                    title: '${lang.PLAY_AFTER}: ${(Player.inst.latestInsertedIndex - Player.inst.currentIndex.value).displayTrackKeyword}',
                                    subtitle: [playAfterTrack.artistsList.firstOrNull, playAfterTrack.title].joinText(separator: ' - '),
                                    icon: Broken.hierarchy_square,
                                    onTap: () {
                                      NamidaNavigator.inst.closeDialog();
                                      Player.inst.addToQueue(tracks, insertAfterLatest: true, showSnackBar: !isSingle);
                                    },
                                  );
                                }(),

                              if (isSingle && tracks.first == Player.inst.currentTrack?.track)
                                ObxO(
                                  rx: numberOfRepeats,
                                  builder: (context, repeats) => SmallListTile(
                                    color: colorDelightened,
                                    compact: true,
                                    title: lang.REPEAT_FOR_N_TIMES.replaceFirst('_NUM_', repeats.toString()),
                                    icon: Broken.cd,
                                    onTap: () {
                                      NamidaNavigator.inst.closeDialog();
                                      settings.player.save(repeatMode: PlayerRepeatMode.forNtimes);
                                      Player.inst.updateNumberOfRepeats(repeats);
                                    },
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        NamidaIconButton(
                                          icon: Broken.minus_cirlce,
                                          onPressed: () => numberOfRepeats.value = (numberOfRepeats.value - 1).clampInt(1, 20),
                                          iconSize: 20.0,
                                          iconColor: iconColor,
                                        ),
                                        NamidaIconButton(
                                          icon: Broken.add_circle,
                                          onPressed: () => numberOfRepeats.value = (numberOfRepeats.value + 1).clampInt(1, 20),
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
                              if (isSingle /*  && playlistUtilsRow == null */)
                                Row(
                                  children: [
                                    const SizedBox(width: 24.0),
                                    Expanded(
                                      child: bigIcon(
                                        Broken.share,
                                        iconWidget: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Broken.share,
                                              color: iconColor,
                                            ),
                                            ObxO(
                                              rx: isLoadingFilesToShare,
                                              builder: (context, loading) => Padding(
                                                padding: const EdgeInsets.only(top: 2.0),
                                                child: const LoadingIndicator().animateEntrance(
                                                  showWhen: loading,
                                                  allCurves: Curves.fastEaseInToSlowEaseOut,
                                                  durationMS: 200,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        () => lang.SHARE,
                                        () async {
                                          final trs = tracksExisting.mapPhysicalOrError((tr) => tr.path);
                                          if (trs.isEmpty) return;
                                          isLoadingFilesToShare.value = true;
                                          await NamidaUtils.shareFiles(trs);
                                          isLoadingFilesToShare.value = false;
                                          NamidaNavigator.inst.closeDialog();
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8.0),
                                    Expanded(
                                      child: isSingle && tracks.first == Player.inst.currentTrack?.track
                                          ? bigIcon(
                                              Broken.pause_circle,
                                              iconWidget: Opacity(
                                                opacity: Player.inst.sleepTimerConfig.value.sleepAfterItems == 1 ? 0.6 : 1.0,
                                                child: IgnorePointer(
                                                  ignoring: Player.inst.sleepTimerConfig.value.sleepAfterItems == 1,
                                                  child: Icon(
                                                    Broken.pause_circle,
                                                    color: iconColor,
                                                  ),
                                                ),
                                              ),
                                              () => lang.STOP_AFTER_THIS_TRACK,
                                              () {
                                                if (Player.inst.sleepTimerConfig.value.sleepAfterItems == 1) return;
                                                NamidaNavigator.inst.closeDialog();
                                                Player.inst.updateSleepTimerValues(enableSleepAfterItems: true, sleepAfterItems: 1);
                                              },
                                            )
                                          : bigIcon(
                                              Broken.play_circle,
                                              () => isSingle ? lang.PLAY : lang.PLAY_ALL,
                                              () {
                                                NamidaNavigator.inst.closeDialog();
                                                Player.inst.playOrPause(0, tracks, source);
                                              },
                                            ),
                                    ),
                                    const SizedBox(width: 8.0),
                                    Expanded(
                                      child: statsWrapper == null
                                          ? bigIcon(
                                              Broken.grammerly,
                                              () => lang.SET_RATING,
                                              setTrackStatsDialog,
                                            )
                                          : ObxO(
                                              rx: statsWrapper,
                                              builder: (context, stats) => bigIcon(
                                                Broken.grammerly,
                                                () => lang.SET_RATING,
                                                setTrackStatsDialog,
                                                subtitle: stats.rating == 0 ? '' : ' ${stats.rating}%',
                                              ),
                                            ),
                                    ),
                                    if (isSingle) ...[
                                      const SizedBox(width: 8.0),
                                      Expanded(
                                        child: bigIcon(
                                          Broken.edit_2,
                                          () => lang.SET_YOUTUBE_LINK,
                                          () => showSetYTLinkCommentDialog(tracks.first, colorDelightened),
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
                                          () => lang.OPEN_YOUTUBE_LINK,
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
                                      color: colorDelightened,
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
                                      color: colorDelightened,
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
          ),
        );
      },
    ),
  );
}

class _SmallUnderlinedChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final TextTheme textTheme;

  const _SmallUnderlinedChip({
    required this.text,
    required this.onTap,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1.0),
      child: NamidaInkWell(
        borderRadius: 6.0,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 3.0),
          child: Text(
            text,
            style: textTheme.displaySmall?.copyWith(
              decoration: TextDecoration.underline,
              fontSize: 13.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtworkManager extends StatelessWidget {
  final CustomArtworkManager customArtworkManager;
  const _ArtworkManager({required this.customArtworkManager});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    return NamidaIconButton(
      icon: Broken.gallery_edit,
      onPressed: () async {
        final alreadySetArtworkPossible = customArtworkManager.getArtworkFile();
        final alreadySetArtworkGood = await alreadySetArtworkPossible.exists() && ((await alreadySetArtworkPossible.fileSize() ?? 0) > 0);
        final alreadySetArtworkExisting = alreadySetArtworkGood ? alreadySetArtworkPossible : null;

        void showSnackInfo([dynamic error]) {
          if (error == null) {
            snackyy(icon: Broken.gallery_edit, message: lang.SUCCEEDED, borderColor: Colors.green);
          } else {
            snackyy(icon: Broken.gallery_edit, message: "${lang.FAILED}:$error", borderColor: Colors.red);
          }
        }

        Future<void> onEdit() async {
          final artworkFile = await NamidaFileBrowser.pickFile(memeType: NamidaStorageFileMemeType.image);
          if (artworkFile != null) {
            try {
              await customArtworkManager.setArtworkFile(artworkFile, null);
              showSnackInfo();
            } catch (e) {
              showSnackInfo(e);
            }
          }
        }

        Future<void> onDelete() async {
          try {
            await customArtworkManager.setArtworkFile(null, null);
            showSnackInfo();
          } catch (e) {
            showSnackInfo(e);
          }
        }

        final fetchPossibleArtworksFn = customArtworkManager.fetchPossibleArtworks;
        if (alreadySetArtworkExisting != null || fetchPossibleArtworksFn != null) {
          final possibleArtworks = Rxn<List<String>>();
          CancelToken? cancelToken;
          final possibleArtworksLoading = false.obs;

          if (fetchPossibleArtworksFn != null) {
            possibleArtworksLoading.value = true;
            cancelToken = CancelToken();
            fetchPossibleArtworksFn(cancelToken).catchError((_) => null).then(
              (value) {
                possibleArtworks.value = value;
                possibleArtworksLoading.value = false;
              },
            );
          }

          NamidaNavigator.inst.navigateDialog(
            onDisposing: () {
              cancelToken?.cancel();
              possibleArtworks.close();
              possibleArtworksLoading.close();
            },
            dialog: CustomBlurryDialog(
              title: lang.CONFIGURE,
              actions: [
                NamidaButton(
                  text: lang.DELETE.toUpperCase(),
                  style: ButtonStyle(
                    foregroundColor: WidgetStatePropertyAll(Colors.red),
                  ),
                  onPressed: () async {
                    await onDelete();
                    NamidaNavigator.inst.closeDialog();
                  },
                ),
                NamidaButton(
                  text: lang.PICK_FROM_STORAGE.toUpperCase(),
                  onPressed: () async {
                    await onEdit();
                    NamidaNavigator.inst.closeDialog();
                  },
                ),
              ],
              child: ObxO(
                rx: possibleArtworks,
                builder: (context, urls) {
                  final extraCountText = fetchPossibleArtworksFn == null ? '' : " (${urls?.length ?? 0})";
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text(
                          lang.CHOOSE + extraCountText,
                          style: textTheme.displayMedium,
                        ),
                      ),
                      ObxO(
                        rx: possibleArtworksLoading,
                        builder: (context, loading) => SizedBox(
                          height: fetchPossibleArtworksFn == null ? null : context.height * 0.4,
                          width: context.width,
                          child: loading
                              ? Center(
                                  child: ThreeArchedCircle(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                    size: 32.0,
                                  ),
                                )
                              : fetchPossibleArtworksFn == null
                                  ? null
                                  : urls == null || urls.isEmpty
                                      ? Icon(
                                          Broken.emoji_sad,
                                          size: 48.0,
                                        )
                                      : SmoothGridView.builder(
                                          padding: EdgeInsets.zero,
                                          shrinkWrap: true,
                                          cacheExtent: context.height * 3,
                                          itemCount: urls.length,
                                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 3,
                                            mainAxisSpacing: 6.0,
                                            crossAxisSpacing: 4.0,
                                          ),
                                          itemBuilder: (context, index) {
                                            final url = urls[index];
                                            return BorderRadiusClip(
                                              borderRadius: BorderRadius.circular(8.0.multipliedRadius),
                                              child: FutureBuilder(
                                                future: Rhttp.getBytes(url),
                                                builder: (context, snapshot) {
                                                  final bytes = snapshot.data?.body;
                                                  return AnimatedSwitcher(
                                                    layoutBuilder: (currentChild, previousChildren) {
                                                      return Stack(
                                                        alignment: Alignment.center,
                                                        children: <Widget>[
                                                          ...previousChildren,
                                                          if (currentChild != null) Positioned.fill(child: currentChild),
                                                        ],
                                                      );
                                                    },
                                                    duration: const Duration(milliseconds: 200),
                                                    child: bytes == null
                                                        ? ColoredBox(
                                                            color: theme.cardColor,
                                                          )
                                                        : TapDetector(
                                                            onTap: () async {
                                                              NamidaNavigator.inst.closeDialog();
                                                              Uint8List? fullResbytes;
                                                              try {
                                                                final fullResUrl = url.replaceAll(RegExp(r'\/i\/u\/(.+)\/'), '/i/u/ar0/');
                                                                final res = await Rhttp.getBytes(fullResUrl);
                                                                fullResbytes = res.body;
                                                              } catch (_) {}

                                                              try {
                                                                await customArtworkManager.setArtworkFile(null, fullResbytes ?? bytes);
                                                                showSnackInfo();
                                                              } catch (e) {
                                                                showSnackInfo(e);
                                                              }
                                                            },
                                                            child: Image.memory(bytes),
                                                          ),
                                                  );
                                                },
                                              ),
                                            );
                                          },
                                        ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        } else {
          await onEdit();
        }
      },
    );
  }
}

void showSetTrackStatsDialog({
  required Track? firstTrack,
  required TrackStats stats,
  void Function(TrackStats newStat)? onEdit,
  Color? iconColor,
  Color? colorScheme,
}) async {
  if (firstTrack == null) return;

  final initialRating = stats.rating;
  final initialMoods = stats.moods?.join(', ');
  final initialTags = stats.tags?.join(', ');

  final ratingController = TextEditingController(text: initialRating == 0 ? null : initialRating.toString());
  final moodsController = TextEditingController(text: initialMoods);
  final tagsController = TextEditingController(text: initialTags);

  final isEditing = false.obs;

  Widget getItemChip({
    required ThemeData theme,
    required TextEditingController controller,
    String? subtitle,
    required String hintText,
    required String labelText,
    required IconData icon,
    bool number = false,
  }) {
    const iconSize = 24.0;
    const iconRightPadding = 8.0;
    Widget fieldWidget = Row(
      children: [
        Icon(
          icon,
          size: iconSize,
          color: iconColor,
        ),
        const SizedBox(width: iconRightPadding),
        Expanded(
          child: CustomTagTextField(
            controller: controller,
            hintText: hintText,
            labelText: labelText,
            keyboardType: number ? TextInputType.number : null,
          ),
        ),
      ],
    );
    if (subtitle != null) {
      fieldWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          fieldWidget,
          const SizedBox(height: 4.0),
          Padding(
            padding: const EdgeInsets.only(left: iconSize + iconRightPadding),
            child: Text(
              subtitle,
              style: theme.textTheme.displaySmall,
            ),
          ),
        ],
      );
    }
    return fieldWidget;
  }

  await NamidaNavigator.inst.navigateDialog(
    colorScheme: colorScheme,
    lighterDialogColor: true,
    onDisposing: () {
      ratingController.dispose();
      moodsController.dispose();
      tagsController.dispose();
      isEditing.close();
    },
    dialogBuilder: (theme) => CustomBlurryDialog(
      title: lang.CONFIGURE,
      actions: [
        const CancelButton(),
        ObxO(
          rx: isEditing,
          builder: (context, editing) => AnimatedEnabled(
            enabled: !editing,
            child: NamidaButton(
              text: lang.SAVE,
              onPressed: () async {
                isEditing.value = true;
                await NamidaTaggerController.inst.updateTracksMetadata(
                  tracks: [firstTrack],
                  editedTags: {
                    TagField.rating: ratingController.text,
                    TagField.mood: moodsController.text,
                    TagField.tags: tagsController.text,
                  },
                  onStatsEdit: onEdit,
                  onEdit: (didUpdate, error, _) {
                    if (!didUpdate) {
                      var msg = lang.METADATA_EDIT_FAILED;
                      if (error != null) msg += '\n$error';
                      snackyy(title: lang.WARNING, message: msg, isError: true);
                    }
                  },
                  keepFileDates: true,
                  trimWhiteSpaces: false, // we did here
                ).ignoreError();
                isEditing.value = false;
                NamidaNavigator.inst.closeDialog();
              },
            ),
          ),
        ),
      ],
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: namida.height * 0.6),
        child: SuperSmoothListView(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          shrinkWrap: true,
          children: [
            // -- moods
            const SizedBox(height: 12.0),
            getItemChip(
              theme: theme,
              controller: moodsController,
              hintText: initialMoods ?? '',
              labelText: lang.SET_MOODS,
              icon: Broken.smileys,
              subtitle: lang.SET_MOODS_SUBTITLE,
            ),

            // -- tags
            const SizedBox(height: 24.0),
            getItemChip(
              theme: theme,
              controller: tagsController,
              hintText: initialTags ?? '',
              labelText: lang.SET_TAGS,
              icon: Broken.ticket_discount,
              subtitle: lang.SET_MOODS_SUBTITLE,
            ),

            // -- rating
            const SizedBox(height: 24.0),
            getItemChip(
              theme: theme,
              controller: ratingController,
              hintText: initialRating.toString(),
              labelText: lang.SET_RATING,
              icon: Broken.grammerly,
              number: true,
            ),

            const SizedBox(height: 4.0),
          ],
        ),
      ),
    ),
  );
}
