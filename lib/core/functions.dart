import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/class/folder.dart';
import 'package:namida/class/playlist.dart';
import 'package:namida/class/queue.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/folders_controller.dart';
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
    SelectedTracksController.inst.updateCurrentTracks(tracks);
    final albums = name.artistAlbums;
    final color = await CurrentColor.inst.generateDelightnedColor(tracks.pathToImage);

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
    ScrollSearchController.inst.isGlobalSearchMenuShown.value = false;
    final tracks = Indexer.inst.albumSearchList.firstWhere((element) => element.name == name).tracks;
    final color = await CurrentColor.inst.generateDelightnedColor(tracks.pathToImage);
    SelectedTracksController.inst.updateCurrentTracks(tracks);

    await Get.to(
      () => AlbumTracksPage(
        name: name,
        colorScheme: color,
        tracks: tracks,
      ),
      preventDuplicates: false,
    );
  }

  Future<void> onGenreTap(String name) async {
    final tracks = Indexer.inst.groupedGenresList.firstWhere((element) => element.name == name).tracks;
    SelectedTracksController.inst.updateCurrentTracks(tracks);

    await Get.to(
      () => GenreTracksPage(
        name: name,
        tracks: tracks,
      ),
      preventDuplicates: false,
    );
  }

  Future<void> onPlaylistTap(
    Playlist playlist, {
    bool disableAnimation = false,
    ScrollController? scrollController,
    int? indexToHighlight,
  }) async {
    SelectedTracksController.inst.updateCurrentTracks(playlist.tracks.map((e) => e.track).toList());
    await Get.to(() => PlaylisTracksPage(
          playlist: playlist,
          disableAnimation: disableAnimation,
          indexToHighlight: indexToHighlight,
          scrollController: scrollController,
        ));
  }

  Future<void> onFolderOpen(Folder folder, bool isMainStoragePath) async {
    Folders.inst.stepIn(folder, isMainStoragePath: isMainStoragePath);
  }

  Future<void> onQueueTap(Queue queue) async {
    SelectedTracksController.inst.updateCurrentTracks(queue.tracks);
    await Get.to(() => QueueTracksPage(queue: queue), preventDuplicates: false);
  }

  void onRemoveTrackFromPlaylist(int index, Playlist playlist) {
    final track = playlist.tracks.elementAt(index);
    PlaylistController.inst.removeTrackFromPlaylist(playlist.name, index);
    Get.snackbar(
      Language.inst.UNDO_CHANGES,
      Language.inst.UNDO_CHANGES_DELETED_TRACK,
      mainButton: TextButton(
        onPressed: () {
          PlaylistController.inst.insertTracksInPlaylist(
            playlist.name,
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

// Returns a [0-1] scale representing how much similar both are.
double checkIfQueuesSimilar(List<Track> q1, List<Track> q2) {
  if (q1.isEmpty || q2.isEmpty) {
    return 0.0;
  }
  final finallength = q1.length > q2.length ? q2.length : q1.length;
  int trueconditions = 0;
  for (int i = 0; i < finallength; i++) {
    if (q1[i].path == q2[i].path) trueconditions++;
  }
  return trueconditions / finallength;
}

bool checkIfQueueSameAsCurrent(List<Track> queue) {
  return checkIfQueuesSimilar(queue, Player.inst.currentQueue.toList()) == 1.0;
}

bool checkIfQueueSameAsAllTracks(List<Track> queue) {
  return checkIfQueuesSimilar(queue, allTracksInLibrary.toList()) == 1.0;
}

String textCleanedForSearch(String textToClean) {
  return SettingsController.inst.enableSearchCleanup.value ? textToClean.cleanUpForComparison : textToClean.toLowerCase();
}

List<Track> getRandomTracks([int? min, int? max]) {
  final List<Track> randomList = [];
  final trackslist = allTracksInLibrary;
  final trackslistLength = trackslist.length;

  if (trackslist.length < 3) {
    return [];
  }

  /// ignore min and max if the value is more than the alltrackslist.
  if (max != null && max > allTracksInLibrary.length) {
    max = null;
    min = null;
  }
  min ??= trackslistLength ~/ 12;
  max ??= trackslistLength ~/ 8;
  final int randomNumber = min + Random().nextInt(max - min);
  for (int i = 0; i < randomNumber; i++) {
    randomList.add(trackslist.toList()[Random().nextInt(trackslistLength)]);
  }
  return randomList;
}

List<Track> generateRecommendedTrack(Track track) {
  final gentracks = <Track>[];
  final historytracks = namidaHistoryPlaylist.tracks.map((e) => e.track).toList();
  if (historytracks.isEmpty) {
    return [];
  }
  for (int i = 0; i < historytracks.length; i++) {
    final t = historytracks[i];
    if (t == track) {
      const length = 10;
      final max = historytracks.length;
      gentracks.addAll(historytracks.getRange((i - length).clamp(0, max), (i + length).clamp(0, max)));
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
  final historytracks = namidaHistoryPlaylist.tracks;
  return historytracks.where((element) => element.dateAdded >= oldestDate && element.dateAdded <= (newestDate + 1.days.inMilliseconds)).map((e) => e.track).toSet().toList();
}

List<Track> generateTracksFromMoods(List<String> moods) {
  final finalTracks = <Track>[];

  /// Generating from Playlists.
  finalTracks.addAll(
    PlaylistController.inst.playlistList
        .where((pl) => pl.moods.any((e) => moods.contains(e)))
        .expand(
          (pl) => pl.tracks.map((e) => e.track),
        )
        .toList(),
  );

  /// Generating from all Tracks.
  Indexer.inst.trackStatsMap.forEach((key, value) {
    if (value.moods.toSet().intersection(moods.toSet()).isNotEmpty) {
      final trackInsideMainList = Indexer.inst.allTracksMappedByPath[key];
      if (trackInsideMainList != null) {
        finalTracks.add(trackInsideMainList);
      }
    }
  });
  return finalTracks
    ..shuffle()
    ..take(20)
    ..toList();
}

List<Track> generateTracksFromRatings(
  int min,
  int max,

  /// use 0 for unlimited.
  int maxNumberOfTracks,
) {
  final finalTracks = <Track>[];
  Indexer.inst.trackStatsMap.forEach((key, value) {
    if (value.rating > min && value.rating < max) {
      final trackInsideMainList = Indexer.inst.allTracksMappedByPath[key];
      if (trackInsideMainList != null) {
        finalTracks.add(trackInsideMainList);
      }
    }
  });
  finalTracks.shuffle();
  final l = (maxNumberOfTracks == 0 ? finalTracks : finalTracks.take(maxNumberOfTracks));

  return l.toList();
}

List<Track> generateTracksFromAlbum(String album) {
  final trs = Indexer.inst.albumsList.firstWhere((element) => element.name == album).tracks;
  return _addTheseTracksFromMedia(trs);
}

List<Track> generateTracksFromArtist(String artist) {
  final trs = Indexer.inst.groupedArtistsList.firstWhere((element) => element.name == artist).tracks;
  return _addTheseTracksFromMedia(trs);
}

List<Track> generateTracksFromFolder(String folderPath) {
  final trs = Folders.inst.folderslist.firstWhere((element) => element.path == folderPath).tracks;
  return _addTheseTracksFromMedia(trs);
}

List<Track> _addTheseTracksFromMedia(Iterable<Track> tracks) {
  final trs = <Track>[];
  trs.addAll(tracks);
  trs.shuffle();
  trs.remove(Player.inst.nowPlayingTrack.value);
  return trs.take(10).toList();
}
