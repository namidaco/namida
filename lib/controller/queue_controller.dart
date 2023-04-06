import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';

import 'package:namida/class/queue.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';

class QueueController extends GetxController {
  static QueueController inst = QueueController();

  final RxList<Queue> queueList = <Queue>[].obs;

  final RxList<Track> latestQueue = <Track>[].obs;

  /// doesnt save queues with more than 2000 tracks.
  void addNewQueue({
    int? date,
    List<Track> tracks = const <Track>[],
  }) async {
    /// if there are more than 2000 tracks.
    if (tracks.length > 2000) {
      printInfo(info: "UWAH QUEUE DEKKA");
      return;
    }

    /// if the queue is the same, it will skip instead of saving the same queue.
    if (checkIfQueueSameAsCurrent(tracks)) {
      printInfo(info: "Didnt Save Queue: Similar as Current");
      return;
    }
    printInfo(info: "Added New Queue");
    date ??= DateTime.now().millisecondsSinceEpoch;
    final q = Queue(date, tracks);
    queueList.add(q);
    await _saveQueueToStorage(q);
  }

  void removeQueue(Queue queue) async {
    queueList.remove(queue);
    await _deleteQueueToStorage(queue);
  }

  void insertQueue(Queue queue, int index) async {
    queueList.insertSafe(index, queue);
    await _saveQueueToStorage(queue);
  }

  // void removeQueues(List<Queue> queues) async {
  //   for (final q in queues) {
  //     removeQueue(q);
  //   }
  // }

  void updateQueue(Queue oldQueue, Queue newQueue) async {
    final plIndex = queueList.indexOf(oldQueue);
    queueList.remove(oldQueue);
    queueList.insertSafe(plIndex, newQueue);

    await _saveQueueToStorage(newQueue);
  }

  void updateLatestQueue(List<Track> tracks) async {
    latestQueue.assignAll(tracks);
    if (queueList.isNotEmpty) {
      queueList.last.tracks.assignAll(tracks);

      await _saveQueueToStorage(queueList.last);
    }

    await File(k_FILE_PATH_LATEST_QUEUE).writeAsString(json.encode(tracks.map((e) => e.toJson()).toList()));
  }

  ///
  Future<void> prepareAllQueuesFile() async {
    await for (final p in Directory(k_DIR_QUEUES).list()) {
      // prevents freezing the ui. cheap alternative for Isolate/compute.
      await Future.delayed(Duration.zero);
      final string = await File(p.path).readAsString();
      if (string.isNotEmpty) {
        final content = jsonDecode(string) as Map<String, dynamic>;
        queueList.add(Queue.fromJson(content));
      }
    }
  }

  ///
  Future<void> prepareLatestQueueFile() async {
    final file = await File(k_FILE_PATH_LATEST_QUEUE).create();
    final String content = await file.readAsString();
    if (content.isNotEmpty) {
      final txt = List.from(json.decode(content));
      latestQueue.assignAll(txt.map((e) => Track.fromJson(e)).toList());
    }
  }

  /// Assigns the last queue to the [Player]
  Future<void> putLatestQueue() async {
    if (latestQueue.isEmpty) {
      return;
    }
    final latestTrack = latestQueue.firstWhere(
      (element) => element.path == SettingsController.inst.lastPlayedTrackPath.value,
      orElse: () => latestQueue.first,
    );
    await Player.inst.playOrPause(
      latestQueue.indexOf(latestTrack),
      latestQueue.toList(),
      startPlaying: false,
      dontAddQueue: true,
    );
  }

  Future<void> _saveQueueToStorage(Queue queue) async {
    await File('$k_DIR_QUEUES${queue.date}.json').writeAsString(jsonEncode(queue.toJson()));
  }

  Future<void> _deleteQueueToStorage(Queue queue) async {
    await File('$k_DIR_QUEUES${queue.date}.json').writeAsString(jsonEncode(queue.toJson()));
  }
}
