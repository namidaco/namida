import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/playlist.dart';
import 'package:namida/class/queue.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/pages/subpages/album_tracks_subpage.dart';
import 'package:namida/ui/pages/subpages/artist_tracks_subpage.dart';
import 'package:namida/ui/pages/subpages/genre_tracks_subpage.dart';
import 'package:namida/ui/pages/subpages/queue_tracks_subpage.dart';

class NamidaOnTaps {
  static final NamidaOnTaps inst = NamidaOnTaps();

  Future<void> onArtistTap(String name) async {
    final tracks = Indexer.inst.artistSearchList[name]!.toList();
    final albums = name.artistAlbums;
    final color = await CurrentColor.inst.generateDelightnedColor(tracks[0].pathToImage);
    Get.to(
      () => ArtistTracksPage(
        name: name,
        colorScheme: color,
        tracks: tracks,
        albums: albums,
      ),
      preventDuplicates: false,
    );
  }

  Future<void> onAlbumTap(String name) async {
    final tracks = Indexer.inst.albumSearchList[name]!.toList();
    final color = await CurrentColor.inst.generateDelightnedColor(tracks[0].pathToImage);

    Get.to(
      () => AlbumTracksPage(
        name: name,
        colorScheme: color,
        tracks: tracks,
      ),
      preventDuplicates: false,
    );
  }

  Future<void> onGenreTap(String name) async {
    final tracks = Indexer.inst.groupedGenresMap[name]!.toList();

    Get.to(
      () => GenreTracksPage(
        name: name,
        tracks: tracks,
      ),
      preventDuplicates: false,
    );
  }

  Future<void> onQueueTap(Queue queue) async {
    Get.to(
      () => QueueTracksPage(queue: queue),
      preventDuplicates: false,
    );
  }

  void onRemoveTrackFromPlaylist(List<Track> tracks, Playlist playlist) {
    Map<int, TrackWithDate> playlisttracks = {};
    for (final t in tracks) {
      final pltr = playlist.tracks.firstWhere((element) => element.track == t);
      playlisttracks.addAll({playlist.tracks.indexOf(pltr): pltr});
    }
    for (final t in tracks) {
      PlaylistController.inst.removeTracksFromPlaylist(playlist.id, playlist.tracks.where((element) => element.track == t).toList());
    }
    Get.snackbar(
      Language.inst.UNDO_CHANGES,
      Language.inst.UNDO_CHANGES_DELETED_TRACK,
      mainButton: TextButton(
        onPressed: () {
          playlisttracks.forEach((key, value) {
            PlaylistController.inst.insertTracksInPlaylist(
              playlist.id,
              [value],
              key,
            );
          });
          Get.closeAllSnackbars();
        },
        child: Text(Language.inst.UNDO),
      ),
    );
  }
}
