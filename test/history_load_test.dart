// by claude
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:history_manager/history_manager.dart';

import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';

void main() {
  late Directory dir;
  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('namida_history_load_test');
    AppDirs.USER_DATA = dir.path;
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  final day = DateTime(2026, 3, 15);
  final dayKey = day.toDaysSince1970();
  int at(int hour) => DateTime(day.year, day.month, day.day, hour).millisecondsSinceEpoch;
  final unsortedListens = [at(9), at(15), at(12)];
  final newestFirstListens = [at(15), at(12), at(9)];

  Track writeUnsortedDay() {
    final track = Track.explicit('${dir.path}${Platform.pathSeparator}a.m4a');
    Directory(AppDirs.HISTORY_PLAYLIST).createSync(recursive: true);
    final listens = unsortedListens.map((ms) => TrackWithDate(dateAdded: ms, track: track).toJson()).toList();
    File('${AppDirs.HISTORY_PLAYLIST}$dayKey.json').writeAsJsonSync(listens);
    return track;
  }

  group('day files saved out of order load newest first', () {
    test('local history', () async {
      writeUnsortedDay();
      final info = await HistoryController.inst.prepareAllHistoryFilesFunction(AppDirs.HISTORY_PLAYLIST);
      expect(info.historyMap[dayKey]!.map((e) => e.dateAdded), newestFirstListens);
    });

    test('youtube history', () async {
      Directory(AppDirs.YT_HISTORY_PLAYLIST).createSync(recursive: true);
      YoutubeID watchAt(int ms) => YoutubeID(
        id: 'aaaaaaaaaaa',
        watchNull: YTWatch(dateMSNull: ms, isYTMusic: false),
        playlistID: null,
      );
      final watches = unsortedListens.map((ms) => watchAt(ms).toJson()).toList();
      File('${AppDirs.YT_HISTORY_PLAYLIST}$dayKey.json').writeAsJsonSync(watches);
      final info = await YoutubeHistoryController.inst.prepareAllHistoryFilesFunction(AppDirs.YT_HISTORY_PLAYLIST);
      expect(info.historyMap[dayKey]!.map((e) => e.dateAddedMS), newestFirstListens);
    });
  });

  test('a range cutting inside an old unsorted day counts its listens', () async {
    final track = writeUnsortedDay();
    final history = HistoryController.inst;
    await history.prepareHistoryFile();
    final listens = history.getMostListensInTimeRange(
      mptr: MostPlayedTimeRange.custom,
      isStartOfDay: false,
      customDate: DateRange(oldest: DateTime(2026, 3, 15, 10), newest: DateTime(2026, 3, 15, 16)),
      mainItemToSubItem: history.mainItemToSubItem,
    );
    expect(listens[track], unorderedEquals([at(15), at(12)]));
  });

  test('youtube stats readers skip a bucket write left behind', () async {
    final statsDir = Directory(AppDirs.YT_STATS)..createSync(recursive: true);
    YoutubeVideoHistory video(String id) => YoutubeVideoHistory(id: id, title: id, channel: '', channelUrl: '', watches: const []);
    File('${statsDir.path}a.json').writeAsJsonSync([video('aaaaaaaaaaa').toJson()]);
    File('${statsDir.path}a.json.tmp').writeAsJsonSync([video('abbbbbbbbbb').toJson()]);
    await YoutubeInfoController.utils.fillBackupInfoMap();
    expect(YoutubeInfoController.utils.tempBackupVideoInfo.keys, ['aaaaaaaaaaa']);
  });
}
