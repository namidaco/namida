import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/class/folder.dart';
import 'package:namida/class/playlist.dart';
import 'package:namida/class/queue.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/folders_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/pages/subpages/album_tracks_subpage.dart';
import 'package:namida/ui/pages/subpages/artist_tracks_subpage.dart';
import 'package:namida/ui/pages/subpages/genre_tracks_subpage.dart';
import 'package:namida/ui/pages/subpages/playlist_tracks_subpage.dart';
import 'package:namida/ui/pages/subpages/queue_tracks_subpage.dart';

class NamidaOnTaps {
  static NamidaOnTaps get inst => _instance;
  static final NamidaOnTaps _instance = NamidaOnTaps._internal();
  NamidaOnTaps._internal();

  Future<void> onArtistTap(String name, [List<Track>? tracksPre]) async {
    final tracks = tracksPre ?? name.getArtistTracks();

    final albums = name.getArtistAlbums();
    final color = await CurrentColor.inst.getTrackDelightnedColor(tracks[tracks.indexOfImage]);

    NamidaNavigator.inst.navigateTo(
      ArtistTracksPage(
        name: name,
        colorScheme: color,
        tracks: tracks,
        albums: albums,
      ),
    );
  }

  Future<void> onAlbumTap(String album) async {
    ScrollSearchController.inst.isGlobalSearchMenuShown.value = false;
    final tracks = album.getAlbumTracks();
    final color = await CurrentColor.inst.getTrackDelightnedColor(tracks[tracks.indexOfImage]);

    NamidaNavigator.inst.navigateTo(
      AlbumTracksPage(
        name: album,
        colorScheme: color,
        tracks: tracks,
      ),
    );
  }

  Future<void> onGenreTap(String name) async {
    NamidaNavigator.inst.navigateTo(
      GenreTracksPage(
        name: name,
        tracks: name.getGenresTracks(),
      ),
    );
  }

  Future<void> onPlaylistTap(
    Playlist playlist, {
    bool disableAnimation = false,
    ScrollController? scrollController,
    int? indexToHighlight,
  }) async {
    NamidaNavigator.inst.navigateTo(
      PlaylisTracksPage(
        playlist: playlist,
        disableAnimation: disableAnimation,
        indexToHighlight: indexToHighlight,
        scrollController: scrollController,
      ),
    );
  }

  Future<void> onFolderTap(Folder folder, bool isMainStoragePath, {Track? trackToScrollTo}) async {
    Folders.inst.stepIn(folder, isMainStoragePath: isMainStoragePath, trackToScrollTo: trackToScrollTo);
  }

  Future<void> onQueueTap(Queue queue) async {
    NamidaNavigator.inst.navigateTo(
      QueueTracksPage(queue: queue),
    );
  }

  void onRemoveTrackFromPlaylist(int index, Playlist playlist) {
    final track = playlist.tracks.elementAt(index);
    PlaylistController.inst.removeTrackFromPlaylist(playlist, index);
    Get.snackbar(
      Language.inst.UNDO_CHANGES,
      Language.inst.UNDO_CHANGES_DELETED_TRACK,
      mainButton: TextButton(
        onPressed: () {
          PlaylistController.inst.insertTracksInPlaylist(
            playlist,
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
double checkIfQueuesSimilar(List<Track> q1, List<Track> q2, {bool fullyFunctional = false}) {
  if (fullyFunctional) {
    if (q1.isEmpty || q2.isEmpty) {
      return 1.0;
    }
    final finallength = q1.length > q2.length ? q2.length : q1.length;
    int trueconditions = 0;
    for (int i = 0; i < finallength; i++) {
      if (q1[i].path == q2[i].path) trueconditions++;
    }
    return trueconditions / finallength;
  }
  return q1.isEqualTo(q2) ? 1.0 : 0.0;
}

bool checkIfQueueSameAsCurrent(List<Track> queue) {
  return checkIfQueuesSimilar(queue, Player.inst.currentQueue.toList()) == 1.0;
}

bool checkIfQueueSameAsAllTracks(List<Track> queue) {
  return checkIfQueuesSimilar(queue, allTracksInLibrary) == 1.0;
}

String textCleanedForSearch(String textToClean) {
  return SettingsController.inst.enableSearchCleanup.value ? textToClean.cleanUpForComparison : textToClean.toLowerCase();
}

Set<String> getHighMatcheFilesFromFilename(Iterable<String> files, String filename) {
  return files.where(
    (element) {
      final trackFilename = filename;
      final fileSystemFilenameCleaned = element.getFilename.cleanUpForComparison;
      final l = Indexer.inst.getTitleAndArtistFromFilename(trackFilename);
      final trackTitle = l.$1;
      final trackArtist = l.$2;
      final matching1 = fileSystemFilenameCleaned.contains(trackFilename.cleanUpForComparison);
      final matching2 = fileSystemFilenameCleaned.contains(trackTitle.split('(').first) && fileSystemFilenameCleaned.contains(trackArtist);
      return matching1 || matching2;
    },
  ).toSet();
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

  // number of resulting tracks.
  final int randomNumber = (max - min).getRandomNumberBelow(min);

  for (int i = 0; i < randomNumber; i++) {
    randomList.add(trackslist.toList()[trackslistLength.getRandomNumberBelow()]);
  }
  return randomList;
}

List<Track> generateRecommendedTrack(Track track) {
  final historytracks = namidaHistoryPlaylist.tracks;
  if (historytracks.isEmpty) {
    return [];
  }

  final Map<Track, int> numberOfListensMap = {};
  final max = historytracks.length;
  const length = 10;

  historytracks.loop((t, i) {
    if (t.track == track) {
      final heatTracks = historytracks.getRange((i - length).clamp(0, max), (i + length).clamp(0, max)).toList();
      heatTracks.loop((e, index) {
        numberOfListensMap.update(e.track, (value) => value + 1, ifAbsent: () => 1);
      });
      // skip length since we already took 10 tracks.
      i += length;
    }
  });

  numberOfListensMap.remove(track);

  final sortedByValueMap = numberOfListensMap.entries.toList()..sort((b, a) => a.value.compareTo(b.value));

  return sortedByValueMap.take(20).map((e) => e.key).toList();
}

/// if [maxCount == null], it will generate all available tracks
List<Track> generateTracksFromDates(int oldestDate, int newestDate, [int? maxCount]) {
  final historytracks = namidaHistoryPlaylist.tracks;
  final tracksAvailable =
      historytracks.where((element) => element.dateAdded >= oldestDate && element.dateAdded <= (newestDate + 1.days.inMilliseconds)).map((e) => e.track).toSet().toList();

  if (maxCount == null) {
    return tracksAvailable;
  } else {
    return tracksAvailable
      ..shuffle()
      ..take(maxCount)
      ..toList();
  }
}

List<Track> generateTracksFromMoods(List<String> moods, [int maxCount = 20]) {
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
      final trackInsideMainList = key.toTrackOrNull();
      if (trackInsideMainList != null) {
        finalTracks.add(trackInsideMainList);
      }
    }
  });
  return finalTracks
    ..shuffle()
    ..take(maxCount)
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
    if (value.rating >= min && value.rating <= max) {
      final trackInsideMainList = key.toTrackOrNull();
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
  return _addTheseTracksFromMedia(album.getAlbumTracks());
}

List<Track> generateTracksFromArtist(String artist) {
  return _addTheseTracksFromMedia(artist.getArtistTracks());
}

List<Track> generateTracksFromFolder(Folder folder) {
  return _addTheseTracksFromMedia(folder.tracks);
}

List<Track> _addTheseTracksFromMedia(Iterable<Track> tracks, [int maxCount = 10]) {
  final trs = List<Track>.from(tracks);
  trs.shuffle();
  trs.removeWhere((element) => Player.inst.currentQueue.contains(element));
  return trs.take(maxCount).toList();
}
