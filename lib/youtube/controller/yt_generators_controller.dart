import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:history_manager/history_manager.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';
import 'package:newpipeextractor_dart/utils/stringChecker.dart';

import 'package:namida/base/generator_base.dart';
import 'package:namida/base/ports_provider.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart';

class NamidaYTGenerator extends NamidaGeneratorBase<YoutubeID, String> with PortsProvider {
  static final NamidaYTGenerator inst = NamidaYTGenerator._internal();
  NamidaYTGenerator._internal();

  late final isPreparingResources = false.obs;
  Completer<void>? fillingCompleter;

  late final _operationsCompleter = <_GenerateOperation, Completer<Iterable<String>>>{};

  @override
  HistoryManager<YoutubeID, String> get historyController => YoutubeHistoryController.inst;

  Iterable<YoutubeID> generateRecommendedVideos(YoutubeID video) {
    final strings = super.generateRecommendedItemsFor(video.id, (current) => current.id);
    return strings.map((e) => YoutubeID(id: e, playlistID: null));
  }

  Future<Iterable<YoutubeID>> getRandomVideos({String? exclude, int? min, int? max}) async {
    const type = _GenerateOperation.randomItems;
    final p = {'type': type, 'exclude': exclude, 'min': min, 'max': max};
    final ids = await _onOperationExecution(type: type, parameters: p);
    return ids.map((e) => YoutubeID(id: e, playlistID: null));
  }

  Future<Iterable<YoutubeID>> generateVideoFromSameEra(String videoId, {int daysRange = 30, String? videoToRemove}) async {
    const type = _GenerateOperation.sameReleaseDate;
    final date = YoutubeController.inst.getVideoReleaseDate(videoId, checkFromStorage: true) ??
        await NewPipeExtractorDart.videos.getInfo('https://www.youtube.com/watch?v=$videoId').then((value) => value?.date);
    final p = {'type': type, 'id': videoId, 'date': date, 'daysRange': daysRange, 'videoToRemove': videoToRemove};
    final ids = await _onOperationExecution(type: type, parameters: p);
    return ids.map((e) => YoutubeID(id: e, playlistID: null));
  }

  Future<Iterable<String>> _onOperationExecution({required _GenerateOperation type, required Map parameters}) async {
    _operationsCompleter[type]?.completeIfWasnt([]);
    _operationsCompleter[type] = Completer();

    (await port?.search.future)?.send(parameters);

    return await _operationsCompleter[type]?.future ?? [];
  }

  Timer? _disposingTimer;

  void _cancelDisposingTimer() {
    _disposingTimer?.cancel();
    _disposingTimer = null;
  }

  void cleanResources({int afterSeconds = 5}) {
    _cancelDisposingTimer();
    _disposingTimer = Timer(Duration(seconds: afterSeconds), () async {
      fillingCompleter.completeIfWasnt();
      fillingCompleter = null;
      await disposePort();
      isPreparingResources.value = false;
    });
  }

  Future<void> prepareResources() async {
    _cancelDisposingTimer();
    if (isPreparingResources.value || fillingCompleter?.isCompleted == true) return;

    isPreparingResources.value = true;
    fillingCompleter = Completer();
    await preparePortRaw(
      onResult: (result) {
        if (result is bool) {
          fillingCompleter.completeIfWasnt();
          return;
        }
        if (result is Exception) {
          snackyy(message: result.toString(), isError: true);
          return;
        }
        result as Map;
        final type = result['type'] as _GenerateOperation;
        final videos = result['videos'] as Iterable<String>;
        _operationsCompleter[type]?.completeIfWasnt(videos);
      },
      isolateFunction: (itemsSendPort) async {
        final playlists = {for (final pl in YoutubePlaylistController.inst.playlistsMap.values) pl.name: pl.tracks};
        final params = {
          'tempStreamInfo': YoutubeController.inst.tempVideoInfosFromStreams,
          'dirStreamInfo': AppDirs.YT_METADATA_TEMP,
          'dirVideoInfo': AppDirs.YT_METADATA,
          'tempBackupYTVH': YoutubeController.inst.tempBackupVideoInfo,
          'mostplayedPlaylist': YoutubeHistoryController.inst.topTracksMapListens.keys,
          'favouritesPlaylist': YoutubePlaylistController.inst.favouritesPlaylist.value.tracks,
          'playlists': playlists,
          'sendPort': itemsSendPort,
          'token': RootIsolateToken.instance!,
        };
        await Isolate.spawn(_prepareResourcesAndListen, params);
      },
    );
    await fillingCompleter?.future;
    isPreparingResources.value = false;
  }

  static void _prepareResourcesAndListen(Map params) async {
    final tempStreamInfo = params['tempStreamInfo'] as Map<String, StreamInfoItem>;
    final dirStreamInfo = params['dirStreamInfo'] as String;
    final dirVideoInfo = params['dirVideoInfo'] as String;
    final tempBackupYTVH = params['tempBackupYTVH'] as Map<String, YoutubeVideoHistory>;
    final mostplayedPlaylist = params['mostplayedPlaylist'] as Iterable<String>;
    final favouritesPlaylist = params['favouritesPlaylist'] as List<YoutubeID>;
    final playlists = params['playlists'] as Map<String, List<YoutubeID>>;
    final sendPort = params['sendPort'] as SendPort;
    final token = params['token'] as RootIsolateToken;
    final recievePort = ReceivePort();

    BackgroundIsolateBinaryMessenger.ensureInitialized(token);

    sendPort.send(recievePort.sendPort);

    final releaseDateMap = <String, DateTime?>{};
    final allIds = <String>[];
    final allIdsAdded = <String, bool>{};

    // -- start listening
    StreamSubscription? streamSub;
    streamSub = recievePort.listen((p) async {
      if (p is String && p == 'dispose') {
        recievePort.close();
        releaseDateMap.clear();
        allIds.clear();
        allIdsAdded.clear();
        streamSub?.cancel();
        return;
      }
      p as Map;
      final type = p['type'] as _GenerateOperation;

      switch (type) {
        case _GenerateOperation.sameReleaseDate:
          final id = p['id'] as String;
          final date = p['date'] as DateTime?;
          final dateReleased = date ?? releaseDateMap[id];
          if (dateReleased == null) {
            sendPort.send(Exception('Unknown video release date'));
            return;
          }
          final results = <String>[];
          final daysRange = p['daysRange'] as int;
          final videoToRemove = p['videoToRemove'] as String?;
          allIds.loop((id, _) {
            final dt = releaseDateMap[id];
            if (dt != null && (dt.difference(dateReleased).inDays).abs() <= daysRange) {
              results.add(id);
            }
          });
          if (videoToRemove != null) results.remove(videoToRemove);
          sendPort.send({'videos': results, 'type': type});
          break;

        case _GenerateOperation.randomItems:
          final exclude = p['exclude'] as String?;
          final min = p['min'] as int?;
          final max = p['max'] as int?;
          final randomItems = NamidaGeneratorBase.getRandomItems(allIds, exclude: exclude, min: min, max: max);
          sendPort.send({'videos': randomItems, 'type': type});
          break;
      }
    });
    // -- end listening

    // -- start filling info
    final start = DateTime.now();

    for (final id in tempStreamInfo.keys) {
      allIds.add(id);
      allIdsAdded[id] = true;
      releaseDateMap[id] = tempStreamInfo[id]?.date;
    }

    final completer1 = Completer<void>();
    final completer2 = Completer<void>();

    Directory(dirStreamInfo).listAllIsolate().then((value) {
      value.loop((file, _) {
        try {
          final res = (file as File).readAsJsonSync();
          if (res != null) {
            final id = res['id'];
            if (id != null && releaseDateMap[id] == null) {
              allIds.add(id);
              allIdsAdded[id] = true;
              releaseDateMap[id] = (res['date'] as String?)?.getDateTimeFromMSSEString();
            }
          }
        } catch (_) {}
      });
      completer1.complete();
    });
    Directory(dirVideoInfo).listAllIsolate().then((value) {
      value.loop((file, _) {
        try {
          final res = (file as File).readAsJsonSync();
          if (res != null) {
            final id = res['id'];
            if (id != null && releaseDateMap[id] == null) {
              allIds.add(id);
              allIdsAdded[id] = true;
              releaseDateMap[id] = (res['date'] as String?)?.getDateTimeFromMSSEString();
            }
          }
        } catch (_) {}
      });
      completer2.complete();
    });

    await completer1.future;
    await completer2.future;

    for (final id in tempBackupYTVH.keys) {
      if (releaseDateMap[id] == null) {
        allIds.add(id);
        allIdsAdded[id] = true;
        // releaseDateMap[id] = null;
      }
    }
    // -- filling from playlists
    for (final id in mostplayedPlaylist) {
      if (allIdsAdded[id] == null) {
        allIds.add(id);
      }
    }
    favouritesPlaylist.loop((v, _) {
      final id = v.id;
      if (allIdsAdded[id] == null) {
        allIds.add(id);
      }
    });

    for (final pl in playlists.values) {
      pl.loop((v, index) {
        final id = v.id;
        if (allIdsAdded[id] == null) {
          allIds.add(id);
        }
      });
    }
    // -- end filling from playlists
    sendPort.send(true); // finished filling

    final durationTaken = start.difference(DateTime.now());
    printo('Initialized 4 Lists in $durationTaken');
    printo('''NamidaYTGenerators: ids from cached data ${allIds.length}
    ids from playlists ${allIds.length}
    ''');
    // -- end filling info
  }
}

enum _GenerateOperation {
  randomItems,
  sameReleaseDate,
}
