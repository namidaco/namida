import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'package:namida/class/queue.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/namida_converter_ext.dart';

class QueueController {
  static QueueController get inst => _instance;
  static final QueueController _instance = QueueController._internal();
  QueueController._internal();

  /// holds all queues mapped & sorted by [date] chronologically.
  final Rx<SplayTreeMap<int, Queue>> queuesMap = SplayTreeMap<int, Queue>((date1, date2) => date1.compareTo(date2)).obs;

  /// doesnt save queues with more than 2000 tracks.
  void addNewQueue(
    QueueSource source, {
    int? date,
    List<Track> tracks = const <Track>[],
  }) async {
    /// if there are more than 2000 tracks.
    if (tracks.length > 2000) {
      debugPrint("UWAH QUEUE DEKKA");
      return;
    }

    /// if the queue is the same, it will skip instead of saving the same queue.
    if (checkIfQueueSameAsCurrent(tracks)) {
      debugPrint("Didnt Save Queue: Similar as Current");
      return;
    }
    printInfo(info: "Added New Queue");
    date ??= DateTime.now().millisecondsSinceEpoch;
    final q = Queue(source.toText(), date, false, tracks);
    _updateMap(q);
    await _saveQueueToStorage(q);
  }

  Future<void> removeQueue(Queue queue) async {
    queuesMap.value.remove(queue.date);
    queuesMap.refresh();
    await _deleteQueueFromStorage(queue);
  }

  Future<void> reAddQueue(Queue queue) async {
    _updateMap(queue);
    await _saveQueueToStorage(queue);
  }

  void _updateMap(Queue queue, [int? date]) {
    date ??= queue.date;
    queuesMap.value[date] = queue;
    queuesMap.refresh();
  }

  // void removeQueues(List<Queue> queues) async {
  //   queues.loop((q) => removeQueue(q));
  // }

  Future<void> toggleFavButton(Queue queue) async {
    queue.isFav = !queue.isFav;
    _updateMap(queue);
    await _saveQueueToStorage(queue);
  }

  Future<void> updateQueue(Queue oldQueue, Queue newQueue) async {
    _updateMap(newQueue, oldQueue.date);
    await _saveQueueToStorage(newQueue);
  }

  Future<void> updateLatestQueue(List<Track> tracks) async {
    await _saveLatestQueueToStorage(tracks);

    // updating last queue inside queuesMap.
    final latestQueueInsideMap = queuesMap.value[queuesMap.value.keys.lastOrNull];
    if (latestQueueInsideMap != null) {
      updateQueue(latestQueueInsideMap, latestQueueInsideMap.copyWith(tracks: tracks));
    }
  }

  Future<void> insertTracksQueue(Queue queue, List<Track> tracks, int index) async {
    queue.tracks.insertAllSafe(index, tracks);
    _updateMap(queue);
    await _saveQueueToStorage(queue);
  }

  Future<void> removeTrackFromQueue(Queue queue, int index) async {
    queue.tracks.removeAt(index);
    _updateMap(queue);
    await _saveQueueToStorage(queue);
  }

  /// Only use when updating missing track.
  Future<void> replaceTrackInAllQueues(Track oldTrack, Track newTrack) async {
    final queuesToSave = <Queue>[];
    queuesMap.value.entries.toList().loop((entry, index) {
      final q = entry.value;
      q.tracks.replaceItems(
        oldTrack,
        newTrack,
        onMatch: () => queuesToSave.add(q),
      );
    });
    await queuesToSave.loopFuture((q, index) async {
      _updateMap(q);
      await _saveQueueToStorage(q);
    });
  }

  ///
  Future<void> prepareAllQueuesFile() async {
    await for (final p in Directory(k_DIR_QUEUES).list()) {
      // prevents freezing the ui. cheap alternative for Isolate/compute.
      await Future.delayed(Duration.zero);

      await File(p.path).readAsJsonAnd((response) async {
        final q = Queue.fromJson(response);
        _updateMap(q);
      });
    }
  }

  /// Assigns the last queue to the [Player]
  Future<void> prepareLatestQueue() async {
    final latestQueue = <Track>[];

    // -- Reading file.
    await File(k_FILE_PATH_LATEST_QUEUE).readAsJsonAndLoop((item, index) async {
      latestQueue.add(Track(item));
    });

    if (latestQueue.isEmpty) return;

    final latestTrack = SettingsController.inst.lastPlayedTrackPath.value.toTrack();

    final index = latestQueue.indexOf(latestTrack).toIf(0, -1);

    await Player.inst.playOrPause(
      index,
      latestQueue.toList(),
      QueueSource.playerQueue,
      startPlaying: false,
      dontAddQueue: true,
    );
  }

  Future<void> _saveQueueToStorage(Queue queue) async {
    await File('$k_DIR_QUEUES${queue.date}.json').writeAsJson(queue.toJson());
  }

  Future<void> _saveLatestQueueToStorage(List<Track> tracks) async {
    await File(k_FILE_PATH_LATEST_QUEUE).writeAsJson(tracks.map((e) => e.path).toList());
  }

  Future<void> _deleteQueueFromStorage(Queue queue) async {
    await File('$k_DIR_QUEUES${queue.date}.json').delete();
  }
}
