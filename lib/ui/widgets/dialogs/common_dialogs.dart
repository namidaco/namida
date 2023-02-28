import 'package:flutter/material.dart';

import 'package:namida/class/playlist.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/ui/widgets/dialogs/general_popup_dialog.dart';

class NamidaDialogs {
  static final NamidaDialogs inst = NamidaDialogs();

  Future<void> showTrackDialog(Track track, [Widget? leading, Playlist? playlist]) async {
    await showGeneralPopupDialog(
      [track],
      track.artistsList.join(', ').overflow,
      track.title.overflow,
      thirdLineText: track.album.overflow,
      forceSquared: SettingsController.inst.forceSquaredTrackThumbnail.value,
      isTrackInPlaylist: playlist != null,
      playlist: playlist,
    );
  }

  Future<void> showAlbumDialog(List<Track> tracks, [Widget? leading]) async {
    final artists = tracks.map((e) => e.artistsList).expand((list) => list).toSet();
    await showGeneralPopupDialog(
      tracks,
      tracks.first.album.overflow,
      "${tracks.displayTrackKeyword} & ${artists.length.displayArtistKeyword}",
      thirdLineText: artists.join(', ').overflow,
      forceSquared: SettingsController.inst.forceSquaredAlbumThumbnail.value,
      forceSingleArtwork: true,
    );
  }

  Future<void> showArtistDialog(String name, List<Track> tracks, [Widget? leading]) async {
    // final albumss = Indexer.inst.getAlbumsForArtist(name).keys;
    var albums = tracks.map((e) => e.album).toList();
    await showGeneralPopupDialog(
      tracks,
      name.overflow,
      "${tracks.displayTrackKeyword} & ${albums.length.displayAlbumKeyword}",
      thirdLineText: albums.toSet().take(5).join(', ').overflow,
      forceSquared: true,
      forceSingleArtwork: true,
    );
  }

  Future<void> showGenreDialog(String name, List<Track> tracks, [Widget? leading]) async {
    await showGeneralPopupDialog(
      tracks,
      name,
      [tracks.displayTrackKeyword, tracks.totalDurationFormatted].join(' - '),
    );
  }

  Future<void> showPlaylistDialog(Playlist playlist, [Widget? leading]) async {
    await showGeneralPopupDialog(
      playlist.tracks,
      playlist.name,
      playlist.modes.join(', ').overflow,
      thirdLineText: playlist.date.dateFormatted,
      playlist: playlist,
    );
  }
}
