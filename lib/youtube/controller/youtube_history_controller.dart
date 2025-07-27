// ignore_for_file: non_constant_identifier_names
import 'dart:collection';
import 'dart:io';

import 'package:history_manager/history_manager.dart';

import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/youtube/class/youtube_id.dart';

class YoutubeHistoryController with HistoryManager<YoutubeID, String> {
  static YoutubeHistoryController get inst => _instance;
  static final YoutubeHistoryController _instance = YoutubeHistoryController._internal();
  YoutubeHistoryController._internal();

  @override
  double daysToSectionExtent(List<int> days) {
    const trackTileExtent = Dimensions.youtubeCardItemExtent;
    const dayHeaderExtent = kHistoryDayHeaderHeightWithPadding;
    double total = 0;
    days.loop((day) => total += dayToSectionExtent(day, trackTileExtent, dayHeaderExtent));
    return total;
  }

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
  String get HISTORY_DIRECTORY => AppDirs.YT_HISTORY_PLAYLIST;

  @override
  Map<String, dynamic> itemToJson(YoutubeID item) => item.toJson();

  @override
  String mainItemToSubItem(YoutubeID item) => item.id;

  @override
  Future<HistoryPrepareInfo<YoutubeID, String>> prepareAllHistoryFilesFunction(String directoryPath) async {
    return await _readHistoryFilesCompute.thready(directoryPath);
  }

  static HistoryPrepareInfo<YoutubeID, String> _readHistoryFilesCompute(String path) {
    final map = SplayTreeMap<int, List<YoutubeID>>((date1, date2) => date2.compareTo(date1));
    final tempMapTopItems = <String, List<int>>{};
    int totalCount = 0;
    final files = Directory(path).listSyncSafe();
    final filesL = files.length;
    for (int i = 0; i < filesL; i++) {
      var f = files[i];
      if (f is File) {
        try {
          final response = f.readAsJsonSync(ensureExists: false) as List?;
          final dayOfVideo = int.parse(f.path.getFilenameWOExt);

          final listVideos = <YoutubeID>[];
          if (response != null) {
            for (int i = 0; i < response.length; i++) {
              var vid = YoutubeID.fromJson(response[i]);
              listVideos.add(vid);
              tempMapTopItems.addForce(vid.id, vid.dateAddedMS);
            }
          }

          map[dayOfVideo] = listVideos;
          totalCount += listVideos.length;
        } catch (_) {}
      }
    }

    final topItems = ListensSortedMap<String>();
    topItems.assignAll(tempMapTopItems);
    topItems.sortAllInternalLists();

    return HistoryPrepareInfo(
      historyMap: map,
      topItems: topItems,
      totalItemsCount: totalCount,
    );
  }

  @override
  Rx<MostPlayedTimeRange> get currentMostPlayedTimeRange => settings.ytMostPlayedTimeRange;

  @override
  Rx<DateRange> get mostPlayedCustomDateRange => settings.ytMostPlayedCustomDateRange;

  @override
  Rx<bool> get mostPlayedCustomIsStartOfDay => settings.ytMostPlayedCustomisStartOfDay;
}
