import 'dart:collection';
import 'dart:io';
import 'dart:convert';

import 'package:get/get.dart';

import 'package:namida/class/queue.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';

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
    date ??= DateTime.now().millisecondsSinceEpoch;
    queueList.add(Queue(name, tracks.map((e) => e.path).toList(), date, comment, modes));
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
    queueList.last.tracks.assignAll(tracks.map((e) => e.path).toList());
    _writeToStorage();
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
        printInfo(info: "queue: ${queueList.length}");
      }
    }
  }

  ///
  Future<void> prepareLatestQueueFile({File? file}) async {
    file ??= await File(kLatestQueueFilePath).create();

    String content = await file.readAsString();

    if (content.isEmpty) {
      return;
    }
    final res = List<String>.from(json.decode(content));

    /// Since we are using paths instead of real Track Objects, we need to match all tracks with these paths
    final matchingSet = HashSet<String>.from(res.toList());
    final finalTracks = Indexer.inst.tracksInfoList.where((item) => matchingSet.contains(item.path));
    latestQueue.assignAll(finalTracks);

    printInfo(info: "latestqueue: ${latestQueue.length}");

    // Assign the last queue to the [Player]
    if (latestQueue.isEmpty || await file.stat().then((value) => value.size <= 2)) {
      return;
    }
    final latestTrack = latestQueue.firstWhere(
      (element) => element.path == SettingsController.inst.lastPlayedTrackPath.value,
      orElse: () => latestQueue.first,
    );
    await Player.inst.playOrPause(track: latestTrack, queue: latestQueue.toList(), disablePlay: true);
  }

  void _writeToStorage() {
    /// latest queue file
    File(kLatestQueueFilePath).writeAsStringSync(json.encode(queueList.last.tracks.map((pl) => pl).toList()));

    /// all queues file
    queueList.map((pl) => pl.toJson()).toList();
    File(kQueuesFilePath).writeAsStringSync(json.encode(queueList));
  }
}
