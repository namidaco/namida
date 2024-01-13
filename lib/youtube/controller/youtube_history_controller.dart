// ignore_for_file: non_constant_identifier_names

import 'dart:collection';
import 'dart:io';

import 'package:history_manager/history_manager.dart';

import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/youtube/class/youtube_id.dart';

class YoutubeHistoryController with HistoryManager<YoutubeID, String> {
  static YoutubeHistoryController get inst => _instance;
  static final YoutubeHistoryController _instance = YoutubeHistoryController._internal();
  YoutubeHistoryController._internal();

  Future<void> replaceAllVideosInsideHistory(YoutubeID oldVideo, YoutubeID newVideo) async {
    await replaceTheseTracksInHistory(
      (e) => e.id == oldVideo.id,
      (old) => YoutubeID(
        id: old.id,
        watchNull: old.watch,
        playlistID: old.playlistID,
      ),
    );
  }

  @override
  double get DAY_HEADER_HEIGHT_WITH_PADDING => kHistoryDayHeaderHeightWithPadding;

  @override
  String get HISTORY_DIRECTORY => AppDirs.YT_HISTORY_PLAYLIST;

  @override
  Map<String, dynamic> itemToJson(YoutubeID item) => item.toJson();

  @override
  String mainItemToSubItem(YoutubeID item) => item.id;

  @override
  Future<({SplayTreeMap<int, List<YoutubeID>> historyMap, Map<String, List<int>> topItems})> prepareAllHistoryFilesFunction(String directoryPath) async {
    return await _readHistoryFilesCompute.thready(directoryPath);
  }

  static Future<({SplayTreeMap<int, List<YoutubeID>> historyMap, Map<String, List<int>> topItems})> _readHistoryFilesCompute(String path) async {
    final map = SplayTreeMap<int, List<YoutubeID>>((date1, date2) => date2.compareTo(date1));
    final tempMapTopItems = <String, List<int>>{};
    for (final f in Directory(path).listSyncSafe()) {
      if (f is File) {
        try {
          final response = f.readAsJsonSync();
          final dayOfVideo = int.parse(f.path.getFilenameWOExt);
          final listVideos = (response as List?)?.mapped((e) => YoutubeID.fromJson(e)) ?? <YoutubeID>[];
          map[dayOfVideo] = listVideos;

          listVideos.loop((e, index) {
            tempMapTopItems.addForce(e.id, e.dateTimeAdded.millisecondsSinceEpoch);
          });
        } catch (e) {
          continue;
        }
      }
    }

    // -- Sorting dates
    for (final entry in tempMapTopItems.values) {
      entry.sort();
    }

    final sortedEntries = tempMapTopItems.entries.toList()
      ..sort((a, b) {
        final compare = b.value.length.compareTo(a.value.length);
        if (compare == 0) {
          final lastListenB = b.value.lastOrNull ?? 0;
          final lastListenA = a.value.lastOrNull ?? 0;
          return lastListenB.compareTo(lastListenA);
        }
        return compare;
      });
    final topItems = Map.fromEntries(sortedEntries);

    return (historyMap: map, topItems: topItems);
  }

  @override
  MostPlayedTimeRange get currentMostPlayedTimeRange => settings.ytMostPlayedTimeRange.value;

  @override
  DateRange get mostPlayedCustomDateRange => settings.ytMostPlayedCustomDateRange.value;

  @override
  bool get mostPlayedCustomIsStartOfDay => settings.ytMostPlayedCustomisStartOfDay.value;

  @override
  double get trackTileItemExtent => Dimensions.youtubeCardItemExtent;
}
