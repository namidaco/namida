import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';

import 'package:namida/class/queue.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/functions.dart';

class QueueController extends GetxController {
  static QueueController inst = QueueController();

  RxList<Queue> queueList = <Queue>[].obs;

  RxList<Track> latestQueue = <Track>[].obs;

  void addNewQueue({
    String name = '',
    List<Track> tracks = const <Track>[],
    int? date,
    String comment = '',
    List<String> modes = const [],
  }) {
    /// if the queue is the same, it will skip instead of saving the same queue.
    if (checkIfQueueSameAsCurrent(tracks)) {
      printInfo(info: "Didnt Save Queue: Similar as Current");
      return;
    }
    printInfo(info: "Added New Queue");
    date ??= DateTime.now().millisecondsSinceEpoch;
    queueList.add(Queue(name, tracks, date, comment, modes));
    _writeToStorage();
  }

  void removeQueue(Queue queue) {
    queueList.remove(queue);
    _writeToStorage();
  }

  void removeQueues(List<Queue> queues) {
    for (var pl in queues) {
      queueList.remove(pl);
    }

    _writeToStorage();
  }

  void updateQueue(Queue oldQueue, Queue newQueue) {
    final plIndex = queueList.indexOf(oldQueue);
    queueList.remove(oldQueue);
    queueList.insert(plIndex, newQueue);
    _writeToStorage();
  }

  void updateLatestQueue(List<Track> tracks) {
    latestQueue.assignAll(tracks);
    if (queueList.isNotEmpty) {
      queueList.last.tracks.assignAll(tracks);
      _writeToStorage();
    }
  }

  ///
  Future<void> prepareQueuesFile({File? file}) async {
    file ??= await File(kQueuesFilePath).create();

    if (await file.stat().then((value) => value.size <= 2)) {
      return;
    }

    String contents = await file.readAsString();
    if (contents.isNotEmpty) {
      var jsonResponse = jsonDecode(contents);

      for (var p in jsonResponse) {
        queueList.add(Queue.fromJson(p));
      }
      printInfo(info: "All Queues: ${queueList.length}");
    }
    await prepareLatestQueueFile();
  }

  ///
  Future<void> prepareLatestQueueFile() async {
    latestQueue.assignAll(queueList.last.tracks);

    // Assign the last queue to the [Player]
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

  void _writeToStorage() {
    File(kQueuesFilePath).writeAsStringSync(json.encode(queueList.map((pl) => pl.toJson()).toList()));
  }
}
