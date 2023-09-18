import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/date_range.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/generators_controller.dart';
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
  List<TrackWithDate> get historyTracks => historyMap.value.values.fold([], (mainList, newEntry) => mainList..addAll(newEntry));
  TrackWithDate? get oldestTrack => historyMap.value[historyDays.lastOrNull]?.lastOrNull;
  TrackWithDate? get newestTrack => historyMap.value[historyDays.firstOrNull]?.firstOrNull;
  Iterable<int> get historyDays => historyMap.value.keys;

  /// History tracks mapped by [daysSinceEpoch].
  ///
  /// Sorted by newest date, i.e. newest list would be the first.
  ///
  /// For each List, the tracks are added to the first index, i.e. newest track would be the first.
  final Rx<SplayTreeMap<int, List<TrackWithDate>>> historyMap = SplayTreeMap<int, List<TrackWithDate>>((date1, date2) => date2.compareTo(date1)).obs;

  final RxMap<Track, List<int>> topTracksMapListens = <Track, List<int>>{}.obs;
  final RxMap<Track, List<int>> topTracksMapListensTemp = <Track, List<int>>{}.obs;
  Iterable<Track> get currentMostPlayedTracks => currentTopTracksMapListens.keys;
  RxMap<Track, List<int>> get currentTopTracksMapListens {
    final isAll = settings.mostPlayedTimeRange.value == MostPlayedTimeRange.allTime;
    return isAll ? topTracksMapListens : topTracksMapListensTemp;
  }

  DateRange? get latestDateRange => _latestDateRange.value;
  final _latestDateRange = Rxn<DateRange>();

  final ScrollController scrollController = ScrollController();
  final Rxn<int> indexToHighlight = Rxn<int>();
  final Rxn<int> dayOfHighLight = Rxn<int>();

  Future<void> addTracksToHistory(List<TrackWithDate> tracks) async {
    if (_isLoadingHistory) {
      // after history full load, [addTracksToHistory] will be called to add tracks inside [_tracksToAddAfterHistoryLoad].
      _tracksToAddAfterHistoryLoad.addAll(tracks);
      return;
    }
    final daysToSave = addTracksToHistoryOnly(tracks);
    updateMostPlayedPlaylist(tracks);
    await saveHistoryToStorage(daysToSave);
  }

  /// adds [tracks] to [historyMap] and returns [daysToSave], to be used by [saveHistoryToStorage].
  ///
  /// By using this instead of [addTracksToHistory], you gurantee that you WILL call [updateMostPlayedPlaylist], [sortHistoryTracks] and [saveHistoryToStorage].
  /// Use this ONLY when adding large number of tracks at once, such as adding from youtube or lastfm history.
  List<int> addTracksToHistoryOnly(List<TrackWithDate> tracks) {
    final daysToSave = <int>[];
    tracks.loop((e, i) {
      final trackday = e.dateAdded.toDaysSinceEpoch();
      daysToSave.add(trackday);
      historyMap.value.insertForce(0, trackday, e);
    });
    Dimensions.inst.calculateAllItemsExtentsInHistory();

    return daysToSave;
  }

  /// Sorts each [historyMap]'s value by newest.
  ///
  /// Providing [daysToSort] will sort these entries only.
  void sortHistoryTracks([List<int>? daysToSort]) {
    void sortTheseTracks(List<TrackWithDate> tracks) => tracks.sortByReverse((e) => e.dateAdded);

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

  Future<void> removeTracksFromHistory(List<TrackWithDate> tracksWithDates) async {
    final dayAndTracksToDeleteMap = <int, List<TrackWithDate>>{};
    tracksWithDates.loop((twd, index) {
      dayAndTracksToDeleteMap.addForce(twd.dateAdded.toDaysSinceEpoch(), twd);
    });
    final days = dayAndTracksToDeleteMap.keys.toList();
    days.loop((d, index) {
      final tracksInMap = historyMap.value[d] ?? [];
      final tracksToDelete = dayAndTracksToDeleteMap[d] ?? [];
      tracksToDelete.loop((ttd, index) {
        tracksInMap.remove(ttd);
        topTracksMapListens[ttd.track]?.remove(ttd.dateAdded);
      });
    });

    await saveHistoryToStorage(days);
    Dimensions.inst.calculateAllItemsExtentsInHistory();
  }

  Future<int> removeSourcesTracksFromHistory(List<TrackSource> sources, {DateTime? oldestDate, DateTime? newestDate, bool andSave = true}) async {
    if (sources.isEmpty) return 0;

    int totalRemoved = 0;

    Future<void> saveHistory([List<int>? daysToSave]) async {
      if (andSave) {
        await saveHistoryToStorage(daysToSave);
      }
    }

    // -- remove all sources (i.e all history)
    if (oldestDate == null && newestDate == null && sources.isEqualTo(TrackSource.values)) {
      totalRemoved = historyTracksLength;
      historyMap.value.clear();
      await saveHistory();
    } else {
      final daysToRemoveFrom = historyDays.toList();

      final oldestDay = oldestDate?.millisecondsSinceEpoch.toDaysSinceEpoch();
      final newestDay = newestDate?.millisecondsSinceEpoch.toDaysSinceEpoch();

      if (oldestDay != null && newestDay == null) {
        daysToRemoveFrom.retainWhere((day) => day >= oldestDay);
      }
      if (oldestDay == null && newestDay != null) {
        daysToRemoveFrom.retainWhere((day) => day <= newestDay);
      }

      if (oldestDay != null && newestDay != null) {
        daysToRemoveFrom.retainWhere((day) => day >= oldestDay && day <= newestDay);
      }

      // -- will loop the whole days.
      /* if (oldestDay == null && newestDay == null) {} */

      daysToRemoveFrom.loop((d, index) {
        totalRemoved += historyMap.value[d]?.removeWhereWithDifference((twd) => sources.contains(twd.source)) ?? 0;
      });
      await saveHistory(daysToRemoveFrom);
    }

    updateMostPlayedPlaylist();
    Dimensions.inst.calculateAllItemsExtentsInHistory();
    return totalRemoved;
  }

  Future<void> _replaceTheseTracksInHistory(
    bool Function(TrackWithDate e) test,
    TrackWithDate Function(TrackWithDate old) newElement,
  ) async {
    final daysToSave = <int>[];
    historyMap.value.entries.toList().loop((entry, index) {
      final day = entry.key;
      final trs = entry.value;
      trs.replaceWhere(
        test,
        newElement,
        onMatch: () => daysToSave.add(day),
      );
    });
    await saveHistoryToStorage(daysToSave);
    updateMostPlayedPlaylist();
  }

  Future<void> replaceTracksDirectoryInHistory(String oldDir, String newDir, {Iterable<String>? forThesePathsOnly, bool ensureNewFileExists = false}) async {
    String getNewPath(String old) => old.replaceFirst(oldDir, newDir);
    await _replaceTheseTracksInHistory(
      (e) {
        final trackPath = e.track.path;
        if (ensureNewFileExists) {
          if (!File(getNewPath(trackPath)).existsSync()) return false;
        }
        final firstC = forThesePathsOnly != null ? forThesePathsOnly.contains(e.track.path) : true;
        final secondC = trackPath.startsWith(oldDir);
        return firstC && secondC;
      },
      (old) => TrackWithDate(
        dateAdded: old.dateAdded,
        track: Track(getNewPath(old.track.path)),
        source: old.source,
      ),
    );
  }

  Future<void> replaceAllTracksInsideHistory(Selectable oldTrack, Track newTrack) async {
    await _replaceTheseTracksInHistory(
      (e) => e.track == oldTrack.track,
      (old) => TrackWithDate(
        dateAdded: old.dateAdded,
        track: newTrack,
        source: old.source,
      ),
    );
  }

  /// Most Played Playlist, relies totally on History Playlist.
  /// Sending [track && dateAdded] just adds it to the map and sort, it won't perform a re-lookup from history.
  void updateMostPlayedPlaylist([List<TrackWithDate>? tracksWithDate]) {
    void sortAndUpdateMap(Map<Track, List<int>> unsortedMap, {Map<Track, List<int>>? mapToUpdate}) {
      final sortedEntries = unsortedMap.entries.toList()
        ..sort((a, b) {
          final compare = b.value.length.compareTo(a.value.length);
          if (compare == 0) {
            final lastListenB = b.value.lastOrNull ?? 0;
            final lastListenA = a.value.lastOrNull ?? 0;
            return lastListenB.compareTo(lastListenA);
          }
          return compare;
        });
      final fmap = mapToUpdate ?? unsortedMap;
      fmap
        ..clear()
        ..addEntries(sortedEntries);
      updateTempMostPlayedPlaylist();
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

      for (final entry in tempMap.values) {
        entry.sort();
      }

      sortAndUpdateMap(tempMap, mapToUpdate: topTracksMapListens);
    }
  }

  void updateTempMostPlayedPlaylist({
    DateRange? customDateRange,
    MostPlayedTimeRange? mptr,
    bool? isStartOfDay,
  }) {
    mptr ??= settings.mostPlayedTimeRange.value;
    customDateRange ??= settings.mostPlayedCustomDateRange.value;
    isStartOfDay ??= settings.mostPlayedCustomisStartOfDay.value;

    if (mptr == MostPlayedTimeRange.allTime) {
      topTracksMapListensTemp.clear();
      return;
    }

    _latestDateRange.value = customDateRange;

    final sortedEntries = getMostListensInTimeRange(
      mptr: mptr,
      isStartOfDay: isStartOfDay,
      customDate: customDateRange,
    );

    topTracksMapListensTemp
      ..clear()
      ..addEntries(sortedEntries);
  }

  List<MapEntry<Track, List<int>>> getMostListensInTimeRange({
    required MostPlayedTimeRange mptr,
    required bool isStartOfDay,
    DateRange? customDate,
  }) {
    final timeNow = DateTime.now();

    final varMapOldestDate = isStartOfDay
        ? {
            MostPlayedTimeRange.allTime: null,
            MostPlayedTimeRange.day: DateTime(timeNow.year, timeNow.month, timeNow.day),
            MostPlayedTimeRange.day3: DateTime(timeNow.year, timeNow.month, timeNow.day - 2),
            MostPlayedTimeRange.week: DateTime(timeNow.year, timeNow.month, timeNow.day - 6),
            MostPlayedTimeRange.month: DateTime(timeNow.year, timeNow.month),
            MostPlayedTimeRange.month3: DateTime(timeNow.year, timeNow.month - 2),
            MostPlayedTimeRange.month6: DateTime(timeNow.year, timeNow.month - 5),
            MostPlayedTimeRange.year: DateTime(timeNow.year),
            MostPlayedTimeRange.custom: customDate?.oldest,
          }
        : {
            MostPlayedTimeRange.allTime: null,
            MostPlayedTimeRange.day: DateTime.now(),
            MostPlayedTimeRange.day3: timeNow.subtract(const Duration(days: 3)),
            MostPlayedTimeRange.week: timeNow.subtract(const Duration(days: 7)),
            MostPlayedTimeRange.month: timeNow.subtract(const Duration(days: 30)),
            MostPlayedTimeRange.month3: timeNow.subtract(const Duration(days: 30 * 3)),
            MostPlayedTimeRange.month6: timeNow.subtract(const Duration(days: 30 * 6)),
            MostPlayedTimeRange.year: timeNow.subtract(const Duration(days: 365)),
            MostPlayedTimeRange.custom: customDate?.oldest,
          };

    final map = {for (final e in MostPlayedTimeRange.values) e: varMapOldestDate[e]};

    final newDate = mptr == MostPlayedTimeRange.custom ? customDate?.newest : timeNow;
    final oldDate = map[mptr];

    final betweenDates = NamidaGenerator.inst.generateTracksFromHistoryDates(
      oldDate,
      newDate,
      removeDuplicates: false,
    );

    final Map<Track, List<int>> tempMap = <Track, List<int>>{};

    betweenDates.loop((t, index) {
      tempMap.addForce(t.track, t.dateAdded);
    });

    for (final entry in tempMap.values) {
      entry.sort();
    }

    final sortedEntries = tempMap.entries.toList()
      ..sort((a, b) {
        final compare = b.value.length.compareTo(a.value.length);
        if (compare == 0) {
          final lastListenB = b.value.lastOrNull ?? 0;
          final lastListenA = a.value.lastOrNull ?? 0;
          return lastListenB.compareTo(lastListenA);
        }
        return compare;
      });
    return sortedEntries;
  }

  Future<void> saveHistoryToStorage([List<int>? daysToSave]) async {
    Future<void> saveThisDay(int key, List<TrackWithDate> tracks) async {
      await File('${AppDirs.HISTORY_PLAYLIST}$key.json').writeAsJson(tracks.mapped((e) => e.toJson()));
    }

    Future<void> deleteThisDay(int key) async {
      historyMap.value.remove(key);
      await File('${AppDirs.HISTORY_PLAYLIST}$key.json').delete();
    }

    if (daysToSave != null) {
      daysToSave.removeDuplicates();
      for (int i = 0; i < daysToSave.length; i++) {
        final day = daysToSave[i];
        final trs = historyMap.value[day];
        if (trs == null) {
          printy('couldn\'t find [dayToSave] inside [historyMap]', isError: true);
          await deleteThisDay(day);
          continue;
        }
        if (trs.isEmpty) {
          await deleteThisDay(day);
        } else {
          await saveThisDay(day, trs);
        }
      }
    } else {
      historyMap.value.forEach((key, value) async {
        await saveThisDay(key, value);
      });
    }
    historyMap.refresh();
  }

  Future<void> prepareHistoryFile() async {
    final map = await _readHistoryFilesCompute.thready(AppDirs.HISTORY_PLAYLIST);
    historyMap.value
      ..clear()
      ..addAll(map);

    historyMap.refresh();
    _isLoadingHistory = false;
    // Adding tracks that were rejected by [addToHistory] since history wasn't fully loaded.
    if (_tracksToAddAfterHistoryLoad.isNotEmpty) {
      await addTracksToHistory(_tracksToAddAfterHistoryLoad);
      _tracksToAddAfterHistoryLoad.clear();
    }
    Dimensions.inst.calculateAllItemsExtentsInHistory();
    updateMostPlayedPlaylist();
    _historyAndMostPlayedLoad.complete(true);
  }

  static Future<Map<int, List<TrackWithDate>>> _readHistoryFilesCompute(String path) async {
    final map = <int, List<TrackWithDate>>{};
    for (final f in Directory(path).listSync()) {
      if (f is File) {
        try {
          final response = f.readAsJsonSync();
          final dayOfTrack = int.parse(f.path.getFilenameWOExt);
          final listTracks = (response as List?)?.mapped((e) => TrackWithDate.fromJson(e)) ?? <TrackWithDate>[];
          map[dayOfTrack] = listTracks;
        } catch (e) {
          continue;
        }
      }
    }
    return map;
  }

  /// Used to add tracks that were rejected by [addToHistory] after full loading of history.
  ///
  /// This is an extremely rare case, would happen only if history loading took more than 20s. (min seconds to count a listen)
  final List<TrackWithDate> _tracksToAddAfterHistoryLoad = <TrackWithDate>[];
  bool _isLoadingHistory = true;
  bool get isLoadingHistory => _isLoadingHistory;

  final _historyAndMostPlayedLoad = Completer<bool>();
  Future<bool> get waitForHistoryAndMostPlayedLoad => _historyAndMostPlayedLoad.future;
}
