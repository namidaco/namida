import 'dart:convert';
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
    await _dbstore.record(q.date).put(_db, q.toJson());
  }

  void removeQueue(Queue queue) async {
    queueList.remove(queue);
    await _dbstore.record(queue.date).delete(_db);
  }

  void insertQueue(Queue queue, int index) async {
    queueList.insert(index, queue);
    await _dbstore.record(queue.date).put(_db, queue.toJson());
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

    await File(kLatestQueueFilePath).writeAsString(json.encode(tracks.map((e) => e.toJson()).toList()));
  }

  ///
  Future<void> prepareQueuesFile() async {
    _db = await databaseFactoryIo.openDatabase(kQueuesDBPath);
    _dbstore = StoreRef.main();
    final trwt = await _dbstore.find(_db);
    if (trwt.isNotEmpty) {
      for (final t in trwt) {
        // prevents freezing the ui. cheap alternative for Isolate/compute.
        await Future.delayed(Duration.zero);
        QueueController.inst.queueList.add(Queue.fromJson(t.value as Map<String, dynamic>));
      }
    }
  }

  ///
  Future<void> prepareLatestQueueFile() async {
    final file = await File(kLatestQueueFilePath).create();
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
}
