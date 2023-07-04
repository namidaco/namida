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
  final List<Track> latestQueue = <Track>[];

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

  void removeQueue(Queue queue) async {
    queuesMap.value.remove(queue.date);
    queuesMap.refresh();
    await _deleteQueueFromStorage(queue);
  }

  void reAddQueue(Queue queue) async {
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

  void updateQueue(Queue oldQueue, Queue newQueue) async {
    _updateMap(newQueue, oldQueue.date);
    await _saveQueueToStorage(newQueue);
  }

  void updateLatestQueue(List<Track> tracks) async {
    // updating current last queue.
    latestQueue
      ..clear()
      ..addAll(tracks);

    // updating last queue inside queuesMap.
    final latestQueueInsideMap = queuesMap.value[queuesMap.value.keys.lastOrNull];
    if (latestQueueInsideMap != null) {
      latestQueueInsideMap.tracks
        ..clear()
        ..addAll(tracks);
      _updateMap(latestQueueInsideMap);
      await _saveLatestQueueToStorage(latestQueueInsideMap);
    }
  }

  void insertTracksQueue(Queue queue, List<Track> tracks, int index) async {
    queue.tracks.insertAllSafe(index, tracks);
    _updateMap(queue);
    await _saveQueueToStorage(queue);
  }

  Future<void> removeTrackFromQueue(Queue queue, int index) async {
    queue.tracks.removeAt(index);
    _updateMap(queue);
    await _saveQueueToStorage(queue);
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

  ///
  Future<void> prepareLatestQueueFile() async {
    await File(k_FILE_PATH_LATEST_QUEUE).readAsJsonAnd((response) async {
      final lq = Queue.fromJson(response);
      latestQueue.assignAll(lq.tracks);
    });
  }

  /// Assigns the last queue to the [Player]
  Future<void> putLatestQueue() async {
    if (latestQueue.isEmpty) {
      return;
    }
    final latestTrack = SettingsController.inst.lastPlayedTrackPath.value.toTrackOrNull();
    if (latestTrack == null) return;

    final ind = latestQueue.indexOf(latestTrack);

    await Player.inst.playOrPause(
      ind == -1 ? 0 : ind,
      latestQueue.toList(),
      QueueSource.playerQueue,
      startPlaying: false,
      dontAddQueue: true,
    );
  }

  Future<void> _saveQueueToStorage(Queue queue) async {
    await File('$k_DIR_QUEUES${queue.date}.json').writeAsJson(queue.toJson());
  }

  Future<void> _saveLatestQueueToStorage(Queue queue) async {
    await File(k_FILE_PATH_LATEST_QUEUE).writeAsJson(queue.toJson());
  }

  Future<void> _deleteQueueFromStorage(Queue queue) async {
    await File('$k_DIR_QUEUES${queue.date}.json').delete();
  }
}
