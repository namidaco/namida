import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/class/folder.dart';
import 'package:namida/class/playlist.dart';
import 'package:namida/class/queue.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/folders_controller.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
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

    NamidaNavigator.inst.navigateTo(
      ArtistTracksPage(
        name: name,
        tracks: tracks,
        albums: albums,
      ),
    );
    Dimensions.inst.updateDimensions(LibraryTab.albums, gridOverride: Dimensions.albumInsideArtistGridCount);
  }

  Future<void> onAlbumTap(String album) async {
    ScrollSearchController.inst.isGlobalSearchMenuShown.value = false;
    final tracks = album.getAlbumTracks();

    NamidaNavigator.inst.navigateTo(
      AlbumTracksPage(
        name: album,
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

  Future<void> onNormalPlaylistTap(
    String playlistName, {
    bool disableAnimation = false,
  }) async {
    NamidaNavigator.inst.navigateTo(
      NormalPlaylistTracksPage(
        playlistName: playlistName,
        disableAnimation: disableAnimation,
      ),
    );
  }

  Future<void> onHistoryPlaylistTap({
    double initialScrollOffset = 0,
    int? indexToHighlight,
    int? dayOfHighLight,
  }) async {
    HistoryController.inst.indexToHighlight.value = indexToHighlight;
    HistoryController.inst.dayOfHighLight.value = dayOfHighLight;

    void jump() => HistoryController.inst.scrollController.jumpTo(initialScrollOffset);

    if (NamidaNavigator.inst.currentRoute?.route == RouteType.SUBPAGE_historyTracks) {
      NamidaNavigator.inst.closeAllDialogs();
      MiniPlayerController.inst.snapToMini();
      jump();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        jump();
      });
      await NamidaNavigator.inst.navigateTo(
        const HistoryTracksPage(),
      );
    }
  }

  Future<void> onMostPlayedPlaylistTap() async {
    NamidaNavigator.inst.navigateTo(const MostPlayedTracksPage());
  }

  Future<void> onFolderTap(Folder folder, {Track? trackToScrollTo}) async {
    Folders.inst.stepIn(folder, trackToScrollTo: trackToScrollTo);
  }

  Future<void> onQueueTap(Queue queue) async {
    NamidaNavigator.inst.navigateTo(
      QueueTracksPage(queue: queue),
    );
  }

  void onRemoveTrackFromPlaylist(String name, int index, TrackWithDate trackWithDate) {
    final bool isHistory = name == k_PLAYLIST_NAME_HISTORY;
    Playlist? playlist;
    if (isHistory) {
      final day = trackWithDate.dateAdded.toDaysSinceEpoch();
      HistoryController.inst.removeFromHistory(day, index);
    } else {
      playlist = PlaylistController.inst.getPlaylist(name);
      if (playlist == null) return;
      trackWithDate = playlist.tracks.elementAt(index);
      PlaylistController.inst.removeTrackFromPlaylist(playlist, index);
    }

    Get.snackbar(
      Language.inst.UNDO_CHANGES,
      Language.inst.UNDO_CHANGES_DELETED_TRACK,
      mainButton: TextButton(
        onPressed: () {
          if (isHistory) {
            HistoryController.inst.addTracksToHistory([trackWithDate]);
            HistoryController.inst.sortHistoryTracks([trackWithDate.dateAdded.toDaysSinceEpoch()]);
          } else {
            PlaylistController.inst.insertTracksInPlaylist(
              playlist!,
              [trackWithDate],
              index,
            );
          }

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
    if (q1.isEmpty && q2.isEmpty) {
      return 1.0;
    }
    final finallength = q1.length > q2.length ? q2.length : q1.length;
    int trueconditions = 0;
    for (int i = 0; i < finallength; i++) {
      if (q1[i] == q2[i]) trueconditions++;
    }
    return trueconditions / finallength;
  }
  return q1.isEqualTo(q2) ? 1.0 : 0.0;
}

bool checkIfQueueSameAsCurrent(List<Track> queue) {
  return checkIfQueuesSimilar(queue, Player.inst.currentQueue) == 1.0;
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
    randomList.add(trackslist[trackslistLength.getRandomNumberBelow()]);
  }
  return randomList;
}

List<Track> generateRecommendedTrack(Track track, {int maxCount = 20}) {
  final historytracks = HistoryController.inst.historyTracks;
  if (historytracks.isEmpty) {
    return [];
  }
  const length = 10;
  final max = historytracks.length;
  int clamped(int range) => range.clamp(0, max);

  final Map<Track, int> numberOfListensMap = {};

  for (int i = 0; i <= historytracks.length - 1; i++) {
    final t = historytracks[i];
    if (t.track == track) {
      final heatTracks = historytracks.getRange(clamped(i - length), clamped(i + length)).toList();
      heatTracks.loop((e, index) {
        numberOfListensMap.update(e.track, (value) => value + 1, ifAbsent: () => 1);
      });
      // skip length since we already took 10 tracks.
      i += length;
    }
  }

  numberOfListensMap.remove(track);

  final sortedByValueMap = numberOfListensMap.entries.toList();
  sortedByValueMap.sortByReverse((e) => e.value);

  return sortedByValueMap.take(maxCount).map((e) => e.key).toList();
}

/// if [maxCount == null], it will return all available tracks
List<Track> generateTracksFromHistoryDates(DateTime? oldestDate, DateTime? newestDate, [int? maxCount]) {
  if (oldestDate == null || newestDate == null) return [];

  final tracksAvailable = <Track>[];
  final entries = HistoryController.inst.historyMap.value.entries.toList();

  entries.loop((entry, index) {
    final day = entry.key;
    if (day >= oldestDate.millisecondsSinceEpoch.toDaysSinceEpoch() && day <= (newestDate.millisecondsSinceEpoch.toDaysSinceEpoch())) {
      tracksAvailable.addAll(entry.value.toTracks());
    }
  });

  tracksAvailable.removeDuplicates((element) => element.path);

  if (maxCount == null) {
    return tracksAvailable;
  } else {
    return _addTheseTracksFromMedia(tracksAvailable, maxCount: maxCount, removeTracksInQueue: false);
  }
}

/// [daysRange] means taking n days before [yearTimeStamp] & n days after [yearTimeStamp].
///
/// For best results, track should have the year tag in [yyyyMMdd] format (or any parseable format),
/// Having a [yyyy] year tag will generate from the same year which is quite a wide range.
List<Track> generateTracksFromSameEra(int yearTimeStamp, {int daysRange = 30, int maxCount = 30, Track? currentTrack}) {
  final tracksAvailable = <Track>[];

  // -- [yyyy] year format.
  if (yearTimeStamp.toString().length == 4) {
    allTracksInLibrary.loop((e, index) {
      if (e.year != 0) {
        // -- if the track also has [yyyy]
        if (e.year.toString().length == 4) {
          if (e.year == yearTimeStamp) {
            tracksAvailable.add(e);
          }

          // -- if the track has parseable format
        } else {
          final dt = DateTime.tryParse(e.year.toString());
          if (dt != null && dt.year == yearTimeStamp) {
            tracksAvailable.add(e);
          }
        }
      }
    });

    // -- parseable year format.
  } else {
    final dateParsed = DateTime.tryParse(yearTimeStamp.toString());
    if (dateParsed == null) return [];

    allTracksInLibrary.loop((e, index) {
      if (e.year != 0) {
        final dt = DateTime.tryParse(e.year.toString());
        if (dt != null && (dt.difference(dateParsed).inDays).abs() <= daysRange) {
          tracksAvailable.add(e);
        }
      }
    });
  }
  tracksAvailable.remove(currentTrack);

  return _addTheseTracksFromMedia(tracksAvailable, maxCount: maxCount, removeTracksInQueue: false);
}

List<Track> generateTracksFromMoods(Iterable<String> moods, [int maxCount = 20]) {
  final finalTracks = <Track>[];
  final moodsSet = moods.toSet();

  /// Generating from Playlists.
  final matchingPlEntries = PlaylistController.inst.playlistsMap.entries.where(
    (plEntry) => plEntry.value.moods.any((e) => moodsSet.contains(e)),
  );
  final playlistsTracks = matchingPlEntries.expand((pl) => pl.value.tracks.toTracks());
  finalTracks.addAll(playlistsTracks);

  /// Generating from all Tracks.
  Indexer.inst.trackStatsMap.forEach((key, value) {
    if (value.moods.any((element) => moodsSet.contains(element))) {
      finalTracks.add(key);
    }
  });

  return _addTheseTracksFromMedia(finalTracks, maxCount: maxCount, removeTracksInQueue: false);
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
      finalTracks.add(key);
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

List<Track> _addTheseTracksFromMedia(Iterable<Track> tracks, {int maxCount = 10, bool removeTracksInQueue = true}) {
  final trs = List<Track>.from(tracks);
  trs.shuffle();
  if (removeTracksInQueue) {
    trs.removeWhere((element) => Player.inst.currentQueue.contains(element));
  }
  return trs.take(maxCount).toList();
}
