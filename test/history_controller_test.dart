// by claude
import 'dart:collection';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';

void main() {
  late Directory dir;
  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('namida_history_controller_test');
    AppDirs.USER_DATA = dir.path;
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  test('a bulk track replace made while an import runs lands on the imported history and its day file', () async {
    final history = HistoryController.inst;
    await history.prepareHistoryFile();
    final oldTrack = Track.explicit('${dir.path}${Platform.pathSeparator}old.m4a');
    final newTrack = Track.explicit('${dir.path}${Platform.pathSeparator}new.m4a');
    final dateMS = DateTime(2026, 3, 15, 9).millisecondsSinceEpoch;
    final day = dateMS.toDaysSince1970();
    final local = TrackWithDate(dateAdded: dateMS, track: oldTrack);
    await history.addTracksToHistory([local]);

    await history.setIdleStatus(true);
    final imported = TrackWithDate(dateAdded: dateMS + 60000, track: oldTrack, source: TrackSource.youtube);
    final importedHistory = SplayTreeMap<int, List<TrackWithDate>>((date1, date2) => date2.compareTo(date1));
    importedHistory[day] = [imported, local];

    final pendingReplace = history.replaceTheseTracksInHistoryBulk({oldTrack: newTrack});
    await pumpEventQueue();
    history.historyMap.value = importedHistory;
    await history.setIdleStatus(false);
    await pendingReplace;

    expect(history.historyTracks.map((e) => e.track).toList(), [newTrack, newTrack]);
    final saved = File('${AppDirs.HISTORY_PLAYLIST}$day.json').readAsJsonSync() as List;
    expect(saved.map((e) => e['track']).toList(), [newTrack.path, newTrack.path]);
  });

  test('a path replace keeps the source and queue source, and drops a listen that became equal to another one', () async {
    final history = HistoryController.inst;
    await history.prepareHistoryFile();
    final missingTrack = Track.explicit('/storage/emulated/0/Music/song.flac');
    final localTrack = Track.explicit('${dir.path}${Platform.pathSeparator}song.flac');
    final dateMS = DateTime(2026, 4, 2, 18).millisecondsSinceEpoch;
    final otherDateMS = dateMS + 60000;
    const queueSource = QueueSource.allTracks;
    await history.addTracksToHistory([
      TrackWithDate(dateAdded: dateMS, track: missingTrack),
      TrackWithDate(dateAdded: dateMS, track: localTrack),
      TrackWithDate(dateAdded: otherDateMS, track: missingTrack, queueSource: queueSource),
    ]);
    final countBefore = history.totalHistoryItemsCount.value;

    await history.replaceTheseTracksInHistoryBulk({missingTrack: localTrack});

    final listens = history.historyTracks.where((e) => e.dateAdded == dateMS || e.dateAdded == otherDateMS).toList();
    expect(listens.map((e) => (e.dateAdded, e.track, e.sourceNull, e.queueSource)), [
      (otherDateMS, localTrack, null, queueSource),
      (dateMS, localTrack, null, null),
    ]);
    expect(history.totalHistoryItemsCount.value, countBefore - 1);
  });
}
