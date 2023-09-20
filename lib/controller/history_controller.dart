// ignore_for_file: non_constant_identifier_names

import 'dart:io';

import 'package:history_manager/history_manager.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';

class HistoryController with HistoryManager<TrackWithDate, Track> {
  static HistoryController get inst => _instance;
  static final HistoryController _instance = HistoryController._internal();
  HistoryController._internal();

  Future<void> replaceTracksDirectoryInHistory(String oldDir, String newDir, {Iterable<String>? forThesePathsOnly, bool ensureNewFileExists = false}) async {
    String getNewPath(String old) => old.replaceFirst(oldDir, newDir);
    await replaceTheseTracksInHistory(
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
    await replaceTheseTracksInHistory(
      (e) => e.track == oldTrack.track,
      (old) => TrackWithDate(
        dateAdded: old.dateAdded,
        track: newTrack,
        source: old.source,
      ),
    );
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

      final oldestDay = oldestDate?.toDaysSince1970();
      final newestDay = newestDate?.toDaysSince1970();

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
    calculateAllItemsExtentsInHistory();
    return totalRemoved;
  }

  @override
  double get DAY_HEADER_HEIGHT_WITH_PADDING => kHistoryDayHeaderHeightWithPadding;

  @override
  String get HISTORY_DIRECTORY => AppDirs.HISTORY_PLAYLIST;

  @override
  Map<String, dynamic> itemToJson(TrackWithDate item) => item.toJson();

  @override
  Track mainItemToSubItem(TrackWithDate item) => item.track;

  @override
  Future<Map<int, List<TrackWithDate>>> prepareAllHistoryFilesFunction(String directoryPath) async {
    final map = await _readHistoryFilesCompute.thready(directoryPath);
    return map;
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

  @override
  MostPlayedTimeRange get currentMostPlayedTimeRange => settings.mostPlayedTimeRange.value;

  @override
  DateRange get mostPlayedCustomDateRange => settings.mostPlayedCustomDateRange.value;

  @override
  bool get mostPlayedCustomIsStartOfDay => settings.mostPlayedCustomisStartOfDay.value;

  @override
  double get trackTileItemExtent => Dimensions.inst.trackTileItemExtent;
}
