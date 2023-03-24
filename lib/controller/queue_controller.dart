import 'dart:io';

import 'package:get/get.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';

import 'package:namida/class/queue.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/functions.dart';

class QueueController extends GetxController {
  static QueueController inst = QueueController();

  final RxList<Queue> queueList = <Queue>[].obs;

  final RxList<Track> latestQueue = <Track>[].obs;

  late final Database _db;
  late final StoreRef<Object?, Object?> _dbstore;

  void addNewQueue({
    int? date,
    List<Track> tracks = const <Track>[],
  }) async {
    /// if the queue is the same, it will skip instead of saving the same queue.
    if (checkIfQueueSameAsCurrent(tracks)) {
      printInfo(info: "Didnt Save Queue: Similar as Current");
      return;
    }
    printInfo(info: "Added New Queue");
    date ??= DateTime.now().millisecondsSinceEpoch;
    final q = Queue(date, tracks);
    queueList.add(q);
    await _dbstore.record(q.date).put(_db, q.toJson());
  }

  void removeQueue(Queue queue) async {
    queueList.remove(queue);
    await _dbstore.record(queue.date).delete(_db);
  }

  // void removeQueues(List<Queue> queues) async {
  //   for (final pl in queues) {
  //     queueList.remove(pl);
  //   }
  //   await _dbstore.delete(_db);
  // }

  void updateQueue(Queue oldQueue, Queue newQueue) async {
    final plIndex = queueList.indexOf(oldQueue);
    queueList.remove(oldQueue);
    queueList.insert(plIndex, newQueue);

    await _dbstore.record(oldQueue.date).update(_db, newQueue.toJson());
  }

  void updateLatestQueue(List<Track> tracks) async {
    latestQueue.assignAll(tracks);
    if (queueList.isNotEmpty) {
      queueList.last.tracks.assignAll(tracks);
      await _dbstore.record(queueList.last.date).update(_db, queueList.last.toJson());
    }
  }

  ///
  Future<void> prepareQueuesFile({File? file}) async {
    _db = await databaseFactoryIo.openDatabase(kQueuesDBPath);
    _dbstore = StoreRef.main();
    final trwt = await _dbstore.find(_db);
    if (trwt.isNotEmpty) {
      for (final t in trwt) {
        queueList.add(Queue.fromJson(t.value as Map<String, dynamic>));
      }
    }

    await prepareLatestQueueFile();
  }

  ///
  Future<void> prepareLatestQueueFile() async {
    if (queueList.isEmpty || queueList.last.tracks.isEmpty) {
      return;
    }
    latestQueue.assignAll(queueList.last.tracks);

    // Assign the last queue to the [Player]

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
}
