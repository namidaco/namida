import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';

class HistoryController {
  static HistoryController get inst => _instance;
  static final HistoryController _instance = HistoryController._internal();
  HistoryController._internal();

  int get historyTracksLength => historyMap.value.entries.fold(0, (sum, obj) => sum + obj.value.length);
  List<TrackWithDate> get historyTracks => historyMap.value.entries.fold([], (mainList, newEntry) => [...mainList, ...newEntry.value]);
  TrackWithDate? get oldestTrack => historyMap.value[historyDays.lastOrNull]?.firstOrNull;
  TrackWithDate? get newestTrack => historyMap.value[historyDays.firstOrNull]?.lastOrNull;
  Iterable<int> get historyDays => historyMap.value.keys;

  /// History tracks, key = dayInMSSE && value = <TrackWithDate>[]
  ///
  /// Sorted by newest date, i.e. newest list would be the first.
  ///
  /// for List<TrackWithDate>, the tracks are added to the last index, i.e. newest track will be the last in the list.
  final Rx<SplayTreeMap<int, List<TrackWithDate>>> historyMap = SplayTreeMap<int, List<TrackWithDate>>((date1, date2) => date2.compareTo(date1)).obs;

  final RxMap<Track, List<int>> topTracksMapListens = <Track, List<int>>{}.obs;
  Iterable<Track> get mostPlayedTracks => topTracksMapListens.keys;

  final ScrollController scrollController = ScrollController();
  Timer? _historyTimer;

  /// Starts counting seconds listened, counter only increases when [isPlaying] is true.
  /// When the user seeks backwards by percentage >= 20%, a new counter starts.
  void startCounterToAListen(Track track) {
    debugPrint("Started a new counter");

    int currentListenedSeconds = 0;

    final sec = SettingsController.inst.isTrackPlayedSecondsCount.value;
    final perSett = SettingsController.inst.isTrackPlayedPercentageCount.value;
    final trDurInSec = Player.inst.nowPlayingTrack.value.duration / 1000;

    _historyTimer?.cancel();
    _historyTimer = null;
    _historyTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final per = currentListenedSeconds / trDurInSec * 100;

      debugPrint("Current percentage $per");
      if (Player.inst.isPlaying.value) {
        currentListenedSeconds++;
      }

      if (!per.isNaN && (currentListenedSeconds >= sec || per.toInt() >= perSett)) {
        timer.cancel();
        final newTrackWithDate = TrackWithDate(currentTimeMS, track, TrackSource.local);
        addTracksToHistory([newTrackWithDate]);
        return;
      }
    });
  }

  void addTracksToHistory(List<TrackWithDate> tracks) async {
    final daysToSave = addTracksToHistoryOnly(tracks);
    updateMostPlayedPlaylist(tracks);
    await saveHistoryToStorage(daysToSave);
  }

  /// adds [tracks] to [historyMap] and returns [daysToSave], to be used by [saveHistoryToStorage].
  ///
  /// By using this instead of [addTracksToHistory], you gurantee that you WILL call [updateMostPlayedPlaylist], [sortHistoryTracks] and [saveHistoryToStorage].
  /// Use this ONLY when adding large number of tracks at once, such as adding from youtube or lastfm history.
  List<int> addTracksToHistoryOnly(List<TrackWithDate> tracks) {
    const msinday = 86400000;
    final daysToSave = <int>[];
    tracks.loop((e, i) {
      final trackday = (e.dateAdded / msinday).floor();
      daysToSave.add(trackday);
      historyMap.value.addForce(trackday, e);
    });
    Dimensions.inst.calculateAllItemsExtentsInHistory();

    return daysToSave;
  }

  /// Sorts each [historyMap]'s value chronologically.
  ///
  /// Providing [daysToSort] will sort these entries only.
  void sortHistoryTracks([List<int>? daysToSort]) {
    void sortTheseTracks(List<TrackWithDate> tracks) => tracks.sort((a, b) => a.dateAdded.compareTo(b.dateAdded));

    if (daysToSort != null) {
      for (int i = 0; i < daysToSort.length; i++) {
        final day = daysToSort[i];
        final trs = historyMap.value[day];
        if (trs != null) {
          sortTheseTracks(trs);
        }
      }
    }
    historyMap.value.forEach((key, value) {
      sortTheseTracks(value);
    });
  }

  Future<void> removeFromHistory(int dayOfTrack, int index) async {
    final trs = historyMap.value[dayOfTrack]!;
    trs.removeAt(trs.length - 1 - index);
    Dimensions.inst.calculateAllItemsExtentsInHistory();
    await saveHistoryToStorage([dayOfTrack]);
  }

  Future<int> removeSourcesTracksFromHistory(List<TrackSource> sources) async {
    if (sources.isEmpty) return 0;
    int totalRemoved = 0;
    historyMap.value.forEach((key, value) {
      totalRemoved += value.removeWhereWithDifference((element) => sources.contains(element.source));
    });
    await saveHistoryToStorage();
    return totalRemoved;
  }

  Future<void> replaceAllTracksInsideHistory(Track oldTrack, Track newTrack) async {
    final daysToSave = <int>[];
    historyMap.value.entries.toList().loop((entry, index) {
      final day = entry.key;
      final trs = entry.value;
      trs.replaceWhere(
        (e) => e.track == oldTrack,
        (old) => TrackWithDate(old.dateAdded, newTrack, old.source),
        onMatch: () => daysToSave.add(day),
      );
    });
    await saveHistoryToStorage(daysToSave);
    updateMostPlayedPlaylist();
  }

  /// Most Played Playlist, relies totally on History Playlist.
  /// Sending [track && dateAdded] just adds it to the map and sort, it won't perform a re-lookup from history.
  void updateMostPlayedPlaylist([List<TrackWithDate>? tracksWithDate]) {
    void sortAndUpdateMap(Map<Track, List<int>> unsortedMap, {Map<Track, List<int>>? mapToUpdate}) {
      final sortedEntries = unsortedMap.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length));
      final fmap = mapToUpdate ?? unsortedMap;
      fmap
        ..clear()
        ..addEntries(sortedEntries);
    }

    if (tracksWithDate != null) {
      tracksWithDate.loop((twd, index) {
        topTracksMapListens.addForce(twd.track, twd.dateAdded);
      });

      sortAndUpdateMap(topTracksMapListens);
    } else {
      final Map<Track, List<int>> tempMap = <Track, List<int>>{};

      historyTracks.loop((t, index) {
        tempMap.addForce(t.track, t.dateAdded);
      });

      tempMap.forEach((key, value) {
        value.sort((a, b) => a.compareTo(b));
      });

      sortAndUpdateMap(tempMap, mapToUpdate: topTracksMapListens);
    }
  }

  Future<void> saveHistoryToStorage([List<int>? daysToSave]) async {
    Future<void> saveThisDay(int key, List<TrackWithDate> tracks) async {
      await File('$k_PLAYLIST_DIR_PATH_HISTORY$key.json').writeAsJson(tracks.map((e) => e.toJson()).toList());
    }

    if (daysToSave != null) {
      daysToSave.removeDuplicates();
      for (int i = 0; i < daysToSave.length; i++) {
        final day = daysToSave[i];
        final trs = historyMap.value[day];
        if (trs == null) {
          debugPrint('couldn\'t find [dayToSave] inside [historyMap]');
          continue;
        }
        // todo: should await or not?
        await saveThisDay(day, trs);
      }
    } else {
      historyMap.value.forEach((key, value) async {
        await saveThisDay(key, value);
      });
    }
    historyMap.refresh();
  }

  Future<void> prepareHistoryFile() async {
    await for (final f in Directory(k_PLAYLIST_DIR_PATH_HISTORY).list()) {
      if (f is File) {
        await f.readAsJsonAnd((response) async {
          final dayOfTrack = int.parse(f.path.getFilenameWOExt);
          final listTracks = (response as List?)?.map((e) => TrackWithDate.fromJson(e)) ?? [];
          historyMap.value[dayOfTrack] = List<TrackWithDate>.from(listTracks);
        });
        await Future.delayed(Duration.zero);
        historyMap.refresh();
      }
    }
    Dimensions.inst.calculateAllItemsExtentsInHistory();
    updateMostPlayedPlaylist();
  }
}
