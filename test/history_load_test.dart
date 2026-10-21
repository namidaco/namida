// by claude
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:history_manager/history_manager.dart';

import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/settings_controller.dart';
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

  group('listens saved under another day move back to their own day', () {
    final listenDate = DateTime(2026, 4, 9, 0, 24);
    final listenMS = listenDate.millisecondsSinceEpoch;
    final correctDay = listenDate.toDaysSince1970();
    final oldDay = correctDay - 1;
    int msAt(int day, int hour) {
      final date = HistoryManager.daysSince1970ToDate(day);
      return DateTime(date.year, date.month, date.day, hour).millisecondsSinceEpoch;
    }

    var dirsCount = 0;
    String newHistoryDir() {
      final dirPath = '${dir.path}${Platform.pathSeparator}repair_${dirsCount++}${Platform.pathSeparator}';
      Directory(dirPath).createSync(recursive: true);
      return dirPath;
    }

    Track newTrack() => Track.explicit('${dir.path}${Platform.pathSeparator}a.m4a');
    void writeDay(String dirPath, int day, List<TrackWithDate> listens) {
      final listensJson = listens.map((e) => e.toJson()).toList();
      File('$dirPath$day.json').writeAsJsonSync(listensJson);
    }

    List<int> readDayDates(String dirPath, int day) {
      final listensJson = File('$dirPath$day.json').readAsJsonSync() as List;
      return listensJson.map((e) => TrackWithDate.fromJson(e).dateAdded).toList();
    }

    test('a copy already in the right day drops the misplaced one, other days stay unwritten', () async {
      final dirPath = newHistoryDir();
      final track = newTrack();
      final misplaced = TrackWithDate(dateAdded: listenMS, track: track);
      final olderListen = TrackWithDate(dateAdded: msAt(oldDay, 22), track: track);
      final newerListen = TrackWithDate(dateAdded: msAt(correctDay, 10), track: track);
      final otherDay = oldDay - 5;
      writeDay(dirPath, oldDay, [misplaced, olderListen]);
      writeDay(dirPath, correctDay, [newerListen, misplaced]);
      writeDay(dirPath, otherDay, [TrackWithDate(dateAdded: msAt(otherDay, 12), track: track)]);
      final correctDayModified = File('$dirPath$correctDay.json').lastModifiedSync();
      final otherDayModified = File('$dirPath$otherDay.json').lastModifiedSync();

      final info = await HistoryController.inst.prepareAllHistoryFilesFunction(dirPath, repairDays: true);

      expect(info.historyMap[oldDay], [olderListen]);
      expect(info.historyMap[correctDay], [newerListen, misplaced]);
      expect(info.totalItemsCount, 4);
      expect(info.topItems[track]?.length, 4);
      expect(readDayDates(dirPath, oldDay), [olderListen.dateAdded]);
      expect(File('$dirPath$correctDay.json').lastModifiedSync(), correctDayModified);
      expect(File('$dirPath$otherDay.json').lastModifiedSync(), otherDayModified);
    });

    test('listens at both ends move to their days, an emptied day gets deleted', () async {
      final dirPath = newHistoryDir();
      final track = newTrack();
      final misplaced = TrackWithDate(dateAdded: listenMS, track: track);
      final earlierDayListen = TrackWithDate(dateAdded: msAt(oldDay - 1, 23), track: track);
      writeDay(dirPath, oldDay, [misplaced, earlierDayListen]);

      final info = await HistoryController.inst.prepareAllHistoryFilesFunction(dirPath, repairDays: true);

      expect(info.historyMap.keys, [correctDay, oldDay - 1]);
      expect(info.historyMap[correctDay], [misplaced]);
      expect(info.historyMap[oldDay - 1], [earlierDayListen]);
      expect(info.totalItemsCount, 2);
      expect(File('$dirPath$oldDay.json').existsSync(), isFalse);
      expect(readDayDates(dirPath, correctDay), [listenMS]);
      expect(readDayDates(dirPath, oldDay - 1), [earlierDayListen.dateAdded]);
    });

    test('youtube history', () async {
      final dirPath = newHistoryDir();
      YoutubeID watchAt(int ms) => YoutubeID(
        id: 'aaaaaaaaaaa',
        watchNull: YTWatch(dateMSNull: ms, isYTMusic: false),
        playlistID: null,
      );
      void writeWatchesDay(int day, List<int> watchesMS) {
        final watchesJson = watchesMS.map((ms) => watchAt(ms).toJson()).toList();
        File('$dirPath$day.json').writeAsJsonSync(watchesJson);
      }

      final olderWatchMS = msAt(oldDay, 22);
      final newerWatchMS = msAt(correctDay, 10);
      writeWatchesDay(oldDay, [listenMS, olderWatchMS]);
      writeWatchesDay(correctDay, [newerWatchMS, listenMS]);

      final info = await YoutubeHistoryController.inst.prepareAllHistoryFilesFunction(dirPath, repairDays: true);

      expect(info.historyMap[oldDay]!.map((e) => e.dateAddedMS), [olderWatchMS]);
      expect(info.historyMap[correctDay]!.map((e) => e.dateAddedMS), [newerWatchMS, listenMS]);
      expect(info.totalItemsCount, 3);
      expect(info.topItems['aaaaaaaaaaa']?.length, 3);
    });

    test('loading without repairDays leaves the days as saved', () async {
      final dirPath = newHistoryDir();
      final misplaced = TrackWithDate(dateAdded: listenMS, track: newTrack());
      writeDay(dirPath, oldDay, [misplaced]);

      final info = await HistoryController.inst.prepareAllHistoryFilesFunction(dirPath);

      expect(info.historyMap.keys, [oldDay]);
      expect(readDayDates(dirPath, oldDay), [listenMS]);
    });

    test('the first history load repairs the days once, a synced copy is not added again', () async {
      final track = newTrack();
      final misplaced = TrackWithDate(dateAdded: listenMS, track: track);
      Directory(AppDirs.HISTORY_PLAYLIST).createSync(recursive: true);
      writeDay(AppDirs.HISTORY_PLAYLIST, oldDay, [misplaced]);
      settings.didRepairHistoryDays.save(false);
      final history = HistoryController.inst;
      await history.prepareHistoryFile();

      expect(history.historyMap.value[oldDay], isNull);
      expect(history.historyMap.value[correctDay], [misplaced]);
      expect(settings.didRepairHistoryDays.value, isTrue);

      final countBefore = history.totalHistoryItemsCount.value;
      await history.addTracksToHistoryImportPreventDuplicates([TrackWithDate(dateAdded: listenMS, track: track)]);
      expect(history.totalHistoryItemsCount.value, countBefore);
    });

    test('once repaired, an import still finds a copy saved under the adjacent day', () async {
      final track = newTrack();
      final otherListenDate = DateTime(2026, 5, 3, 0, 10);
      final otherListenMS = otherListenDate.millisecondsSinceEpoch;
      final otherOldDay = otherListenDate.toDaysSince1970() - 1;
      final misplaced = TrackWithDate(dateAdded: otherListenMS, track: track);
      writeDay(AppDirs.HISTORY_PLAYLIST, otherOldDay, [misplaced]);
      settings.didRepairHistoryDays.save(true);
      final history = HistoryController.inst;
      await history.prepareHistoryFile();
      expect(history.historyMap.value[otherOldDay], [misplaced]);

      final countBefore = history.totalHistoryItemsCount.value;
      await history.addTracksToHistoryImportPreventDuplicates([TrackWithDate(dateAdded: otherListenMS, track: track)]);

      expect(history.totalHistoryItemsCount.value, countBefore);
      expect(history.historyMap.value[otherOldDay + 1], isNull);
    });
  });
}
