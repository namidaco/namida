import 'package:flutter/material.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/dialogs/general_popup_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class NamidaDialogs {
  static NamidaDialogs get inst => _instance;
  static final NamidaDialogs _instance = NamidaDialogs._internal();
  NamidaDialogs._internal();

  Future<void> showTrackDialog(
    Track track, {
    Widget? leading,
    String? playlistName,
    TrackWithDate? trackWithDate,
    int? index,
    bool comingFromQueue = false,
    bool isFromPlayerQueue = false,
    bool errorPlayingTrack = false,
  }) async {
    final trExt = track.toTrackExt();
    await showGeneralPopupDialog(
      [track],
      trExt.originalArtist,
      trExt.title.overflow,
      QueueSource.selectedTracks,
      thirdLineText: trExt.album.overflow,
      forceSquared: SettingsController.inst.forceSquaredTrackThumbnail.value,
      trackWithDate: trackWithDate,
      playlistName: playlistName,
      index: index,
      comingFromQueue: comingFromQueue,
      useTrackTileCacheHeight: true,
      isFromPlayerQueue: isFromPlayerQueue,
      errorPlayingTrack: errorPlayingTrack,
    );
  }

  Future<void> showAlbumDialog(String albumName) async {
    final tracks = albumName.getAlbumTracks();
    final artists = tracks.mappedUniquedList((e) => e.artistsList);
    await showGeneralPopupDialog(
      tracks,
      tracks.album.overflow,
      "${tracks.displayTrackKeyword} & ${artists.length.displayArtistKeyword}",
      QueueSource.album,
      thirdLineText: artists.join(', ').overflow,
      forceSquared: shouldAlbumBeSquared,
      forceSingleArtwork: true,
      heroTag: 'album_$albumName',
      albumToAddFrom: tracks.album,
    );
  }

  Future<void> showArtistDialog(String name) async {
    final tracks = name.getArtistTracks();
    final albums = tracks.mappedUniqued((e) => e.album);
    await showGeneralPopupDialog(
      tracks,
      name.overflow,
      "${tracks.displayTrackKeyword} & ${albums.length.displayAlbumKeyword}",
      QueueSource.artist,
      thirdLineText: albums.take(5).join(', ').overflow,
      forceSquared: true,
      forceSingleArtwork: true,
      heroTag: 'artist_$name',
      isCircle: true,
      artistToAddFrom: name,
    );
  }

  Future<void> showGenreDialog(String name) async {
    final tracks = name.getGenresTracks();
    await showGeneralPopupDialog(
      tracks,
      name,
      [tracks.displayTrackKeyword, tracks.totalDurationFormatted].join(' - '),
      QueueSource.genre,
      extractColor: false,
      heroTag: 'genre_$name',
    );
  }

  /// Supports all playlists, (History, Most Played, Favourites & others).
  Future<void> showPlaylistDialog(String playlistName) async {
    if (playlistName == k_PLAYLIST_NAME_HISTORY) {
      final trs = HistoryController.inst.historyTracks.toTracks();
      await showGeneralPopupDialog(
        trs,
        k_PLAYLIST_NAME_HISTORY.translatePlaylistName(),
        trs.length.displayTrackKeyword,
        QueueSource.history,
        thirdLineText: HistoryController.inst.newestTrack?.dateAdded.dateAndClockFormattedOriginal ?? '',
        playlistName: k_PLAYLIST_NAME_HISTORY,
        extractColor: false,
        heroTag: 'playlist_$k_PLAYLIST_NAME_HISTORY',
      );
      return;
    }
    if (playlistName == k_PLAYLIST_NAME_MOST_PLAYED) {
      final trs = HistoryController.inst.mostPlayedTracks.toList();
      await showGeneralPopupDialog(
        trs,
        k_PLAYLIST_NAME_MOST_PLAYED.translatePlaylistName(),
        trs.length.displayTrackKeyword,
        QueueSource.mostPlayed,
        thirdLineText: "↑ ${HistoryController.inst.topTracksMapListens[trs.firstOrNull]?.length.toString()} • ${trs.firstOrNull?.title}",
        playlistName: k_PLAYLIST_NAME_MOST_PLAYED,
        extractColor: false,
        heroTag: 'playlist_$k_PLAYLIST_NAME_MOST_PLAYED',
      );
      return;
    }

    final playlist = PlaylistController.inst.getPlaylist(playlistName);
    if (playlist == null) return;
    // -- Delete Empty Playlists --
    if (playlist.tracks.isEmpty) {
      NamidaNavigator.inst.navigateDialog(
        dialog: CustomBlurryDialog(
          title: Language.inst.WARNING,
          bodyText: '${Language.inst.DELETE_PLAYLIST}: "${playlist.name}"?',
          actions: [
            const CancelButton(),
            ElevatedButton(
              onPressed: () {
                PlaylistController.inst.removePlaylist(playlist);
                NamidaNavigator.inst.closeDialog();
              },
              child: Text(Language.inst.DELETE.toUpperCase()),
            )
          ],
        ),
      );
    } else {
      final trackss = playlist.tracks.toTracks();
      await showGeneralPopupDialog(
        trackss,
        playlist.name.translatePlaylistName(),
        [trackss.displayTrackKeyword, playlist.creationDate.dateFormatted].join(' • '),
        playlist.toQueueSource(),
        thirdLineText: playlist.moods.join(', ').overflow,
        playlistName: playlist.name,
        extractColor: false,
        heroTag: 'playlist_${playlist.name}',
      );
    }
  }

  Future<void> showQueueDialog(int date) async {
    final queue = date.getQueue()!;
    await showGeneralPopupDialog(
      queue.tracks,
      queue.date.dateFormatted,
      queue.date.clockFormatted,
      QueueSource.queuePage,
      thirdLineText: [
        queue.tracks.displayTrackKeyword,
        queue.tracks.totalDurationFormatted,
      ].join(' - '),
      extractColor: false,
      queue: queue,
      forceSquared: true,
      heroTag: 'queue_${queue.date}',
    );
  }
}
