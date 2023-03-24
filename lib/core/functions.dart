// ignore_for_file: depend_on_referenced_packages

import 'dart:math';

import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:collection/collection.dart';

import 'dart:async';

import 'package:namida/class/playlist.dart';
import 'package:namida/class/queue.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/selected_tracks_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/pages/subpages/album_tracks_subpage.dart';
import 'package:namida/ui/pages/subpages/artist_tracks_subpage.dart';
import 'package:namida/ui/pages/subpages/genre_tracks_subpage.dart';
import 'package:namida/ui/pages/subpages/playlist_tracks_subpage.dart';
import 'package:namida/ui/pages/subpages/queue_tracks_subpage.dart';

class NamidaOnTaps {
  static final NamidaOnTaps inst = NamidaOnTaps();

  Future<void> onArtistTap(String name) async {
    ScrollSearchController.inst.isGlobalSearchMenuShown.value = false;
    final tracks = Indexer.inst.artistSearchList.firstWhere((element) => element.name == name).tracks;
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
    SelectedTracksController.inst.currentAllTracks.assignAll(tracks);
  }

  Future<void> onAlbumTap(String name) async {
    ScrollSearchController.inst.isGlobalSearchMenuShown.value = false;
    final tracks = Indexer.inst.albumSearchList.firstWhere((element) => element.name == name).tracks;
    final color = await CurrentColor.inst.generateDelightnedColor(tracks[0].pathToImage);

    Get.to(
      () => AlbumTracksPage(
        name: name,
        colorScheme: color,
        tracks: tracks,
      ),
      preventDuplicates: false,
    );
    SelectedTracksController.inst.currentAllTracks.assignAll(tracks);
  }

  Future<void> onGenreTap(String name) async {
    final tracks = Indexer.inst.groupedGenresList.firstWhere((element) => element.name == name).tracks;

    Get.to(
      () => GenreTracksPage(
        name: name,
        tracks: tracks,
      ),
      preventDuplicates: false,
    );
    SelectedTracksController.inst.currentAllTracks.assignAll(tracks);
  }

  Future<void> onPlaylistTap(Playlist playlist) async {
    Get.to(() => PlaylisTracksPage(playlist: playlist));
    SelectedTracksController.inst.currentAllTracks.assignAll(playlist.tracks.map((e) => e.track).toList());
  }

  Future<void> onQueueTap(Queue queue) async {
    Get.to(
      () => QueueTracksPage(queue: queue),
      preventDuplicates: false,
    );
    SelectedTracksController.inst.currentAllTracks.assignAll(queue.tracks);
  }

  void onRemoveTrackFromPlaylist(int index, Playlist playlist) {
    final track = playlist.tracks.elementAt(index);
    PlaylistController.inst.removeTrackFromPlaylist(playlist.id, index);
    Get.snackbar(
      Language.inst.UNDO_CHANGES,
      Language.inst.UNDO_CHANGES_DELETED_TRACK,
      mainButton: TextButton(
        onPressed: () {
          PlaylistController.inst.insertTracksInPlaylist(
            playlist.id,
            [track],
            index,
          );

          Get.closeAllSnackbars();
        },
        child: Text(Language.inst.UNDO),
      ),
    );
  }
}

bool checkIfQueuesSimilar(List<Track> q1, List<Track> q2) {
  return const IterableEquality().equals(q1.map((e) => e.path).toList(), q2.map((element) => element.path).toList());
}

bool checkIfQueueSameAsCurrent(List<Track> queue) {
  return checkIfQueuesSimilar(queue, Player.inst.currentQueue.toList());
}

bool checkIfQueueSameAsAllTracks(List<Track> queue) {
  return checkIfQueuesSimilar(queue, Indexer.inst.tracksInfoList.toList());
}

String textCleanedForSearch(String textToClean) {
  return SettingsController.inst.enableSearchCleanup.value ? textToClean.cleanUpForComparison : textToClean.toLowerCase();
}

List<Track> getRandomTracks([int? min, int? max]) {
  final List<Track> randomList = [];
  final trackslist = Indexer.inst.tracksInfoList;
  final trackslistLength = trackslist.length;

  /// ignore min and max if the value is more than the alltrackslist.
  if (max != null && max > Indexer.inst.tracksInfoList.length) {
    max = null;
    min = null;
  }
  min ??= trackslistLength ~/ 6;
  max ??= trackslistLength ~/ 3;
  final int randomNumber = min + Random().nextInt(max - min);
  for (int i = 0; i < randomNumber; i++) {
    randomList.add(trackslist.toList()[Random().nextInt(trackslistLength)]);
  }
  return randomList;
}

List<Track> generateRecommendedTrack(Track track) {
  final gentracks = <Track>[];
  final historytracks = PlaylistController.inst.playlistList.firstWhere((element) => element.id == kPlaylistHistory).tracks.map((e) => e.track).toList();
  if (historytracks.isEmpty) {
    return [];
  }
  for (int i = 0; i < historytracks.length; i++) {
    final t = historytracks[i];
    if (t == track) {
      final length = (historytracks.length).clamp(0, 10);
      gentracks.addAll(historytracks.getRange((i - length).clamp(0, 10), i + length));
      // skip length since we already took 10 tracks.
      i += length;
    }
  }
  gentracks.removeWhere((element) => element.path == track.path);

  Map<Track, int> numberOf = {for (final x in gentracks.toSet()) x: gentracks.where((item) => item == x).length};
  final sortedByValueMap = Map.fromEntries(numberOf.entries.toList()..sort((b, a) => a.value.compareTo(b.value)));

  return sortedByValueMap.keys.take(20).toList();
}

List<Track> generateTracksFromDates(int oldestDate, int newestDate) {
  final historytracks = PlaylistController.inst.playlistList.firstWhere((element) => element.id == kPlaylistHistory).tracks;
  return historytracks.where((element) => element.dateAdded >= oldestDate && element.dateAdded <= (newestDate + 1.days.inMilliseconds)).map((e) => e.track).toSet().toList();
}
