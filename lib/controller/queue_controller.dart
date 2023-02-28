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
  Future<void> prepareQueueFile({File? file}) async {
    file ??= await File(kQueueFilePath).create();

    String contents = await file.readAsString();
    if (contents.isNotEmpty) {
      var jsonResponse = jsonDecode(contents);

      for (var p in jsonResponse) {
        Queue queue = Queue(
          p['name'],
          // List<String>.from(p['tracks'].map((i) => Track.fromJson(i))),
          List<String>.from(p['tracks']),
          p['date'],
          p['comment'],
          List<String>.from(p['modes']),
        );
        queueList.add(queue);
        printInfo(info: "queue: ${queueList.length}");
      }
    }

    // Assign the last queue to the [Player]
    if (queueList.isEmpty || await file.stat().then((value) => value.size < 100)) {
      return;
    }
    final latestTrack = Indexer.inst.tracksInfoList.firstWhere(
      (element) => element.path == SettingsController.inst.getString('lastPlayedTrackPath'),
      orElse: () => Indexer.inst.tracksInfoList.first,
    );

    final matchingSet = HashSet.from(queueList.last.tracks);
    final finalTracks = Indexer.inst.tracksInfoList.where((item) => matchingSet.contains(item.path));

    await Player.inst.playOrPause(track: latestTrack, queue: finalTracks.toList());
    await Player.inst.pause();
  }

  void _writeToStorage() {
    queueList.map((pl) => pl.toJson()).toList();
    File(kQueueFilePath).writeAsStringSync(json.encode(queueList));
  }
}
