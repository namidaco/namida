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

  RxList<Queue> queueList = <Queue>[].obs;

  RxList<Track> latestQueue = <Track>[].obs;

  void addNewQueue({
    String name = '',
    List<Track> tracks = const <Track>[],
    int? date,
    String comment = '',
    List<String> modes = const [],
  }) {
    /// if the queue is the same, it will skip instead of saving the same queue, certainly more performant.
    if (checkIfQueueSameAsCurrent(tracks)) {
      printInfo(info: "Didnt Save Queue: Similar as Current");
      return;
    }
    printInfo(info: "Added New Queue");
    date ??= DateTime.now().millisecondsSinceEpoch;
    queueList.add(Queue(name, tracks, date, comment, modes));
    _writeToStorage();
    sortQueues();
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

  // void updatePropertyInQueue(Queue oldQueue, {String? name, List<Track>? tracks, List<Track>? tracksToAdd, int? date, String? comment, List<String>? modes}) {
  //   name ??= oldQueue.name;
  //   tracks ??= oldQueue.tracks;
  //   date ??= oldQueue.date;
  //   comment ??= oldQueue.comment;
  //   modes ??= oldQueue.modes;

  //   final plIndex = queueList.indexOf(oldQueue);
  //   queueList.remove(oldQueue);
  //   queueList.insert(plIndex, Queue(oldQueue.id, name, tracks, date, comment, modes));
  //   _writeToStorage();
  // }

  // void addTracksToQueue(int id, List<Track> tracks) {
  //   final pl = queueList.firstWhere((p0) => p0.id == id);
  //   final plIndex = queueList.indexOf(pl);

  //   final newQueue = Queue(pl.id, pl.name, [...pl.tracks, ...tracks], pl.date, pl.comment, pl.modes);

  //   queueList.remove(pl);
  //   queueList.insert(plIndex, newQueue);
  //   _writeToStorage();
  // }

  ///
  Future<void> prepareQueuesFile({File? file}) async {
    file ??= await File(kQueuesFilePath).create();

    String contents = await file.readAsString();
    if (contents.isNotEmpty) {
      var jsonResponse = jsonDecode(contents);

      for (var p in jsonResponse) {
        queueList.add(Queue.fromJson(p));
      }
      sortQueues();
      printInfo(info: "All Queues: ${queueList.length}");
    }
    await prepareLatestQueueFile();
  }

  void sortQueues() {
    queueList.sort((a, b) => b.date.compareTo(a.date));
  }

  ///
  Future<void> prepareLatestQueueFile({File? file}) async {
    file ??= await File(kLatestQueueFilePath).create();

    List<String> res = [];
    try {
      String content = await file.readAsString();

      if (content.isEmpty) {
        return;
      }
      res = List<String>.from(json.decode(content));
    } catch (e) {
      await file.delete();
      return;
    }

    /// Since we are using paths instead of real Track Objects, we need to match all tracks with these paths
    latestQueue.assignAll(res.toTracks);

    // Assign the last queue to the [Player]
    if (latestQueue.isEmpty || await file.stat().then((value) => value.size <= 2)) {
      return;
    }
    final latestTrack = latestQueue.firstWhere(
      (element) => element.path == SettingsController.inst.lastPlayedTrackPath.value,
      orElse: () => latestQueue.first,
    );

    await Player.inst.playOrPause(
      latestQueue.indexOf(latestTrack),
      latestTrack,
      queue: latestQueue.toList(),
      startPlaying: false,
      dontAddQueue: true,
    );
  }

  void _writeToStorage() {
    /// latest queue file
    File(kLatestQueueFilePath).writeAsStringSync(json.encode(queueList.last.tracks.map((pl) => pl.path).toList()));

    /// all queues file
    File(kQueuesFilePath).writeAsStringSync(json.encode(queueList.map((pl) => pl.toJson()).toList()));
  }
}
