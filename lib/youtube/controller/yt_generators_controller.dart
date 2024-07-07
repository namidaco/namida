import 'dart:async';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:history_manager/history_manager.dart';
import 'package:youtipie/class/cache_details.dart';
import 'package:youtipie/class/publish_time.dart';
import 'package:youtipie/core/enum.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/base/generator_base.dart';
import 'package:namida/base/ports_provider.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart';

class NamidaYTGenerator extends NamidaGeneratorBase<YoutubeID, String> with PortsProvider<Map> {
  static final NamidaYTGenerator inst = NamidaYTGenerator._internal();
  NamidaYTGenerator._internal();

  late final didPrepareResources = false.obs;

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

  Future<Iterable<YoutubeID>> generateVideoFromSameEra(String videoId, DateTime date, {int daysRange = 30, String? videoToRemove}) async {
    const type = _GenerateOperation.sameReleaseDate;
    final p = {'type': type, 'id': videoId, 'date': date, 'daysRange': daysRange, 'videoToRemove': videoToRemove};
    final ids = await _onOperationExecution(type: type, parameters: p);
    return ids.map((e) => YoutubeID(id: e, playlistID: null));
  }

  Future<Iterable<String>> _onOperationExecution({required _GenerateOperation type, required Map parameters}) async {
    _operationsCompleter[type]?.completeIfWasnt([]);
    _operationsCompleter[type] = Completer();
    await sendPort(parameters);

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
      await disposePort();
    });
  }

  @override
  void onPreparing(bool prepared) {
    didPrepareResources.value = prepared;
  }

  @override
  Future<void> initialize() async {
    _cancelDisposingTimer();
    return super.initialize();
  }

  @override
  void onResult(dynamic result) {
    if (result is Exception) {
      snackyy(message: result.toString(), isError: true);
      return;
    }
    result as Map;
    final type = result['type'] as _GenerateOperation;
    final videos = result['videos'] as Iterable<String>;
    _operationsCompleter[type]?.completeIfWasnt(videos);
  }

  @override
  IsolateFunctionReturnBuild<Map> isolateFunction(SendPort port) {
    final playlists = {for (final pl in YoutubePlaylistController.inst.playlistsMap.value.values) pl.name: pl.tracks};
    final params = {
      'databasesDir': AppDirs.YOUTIPIE_CACHE,
      'sensitiveDataDir': AppDirs.YOUTIPIE_DATA,
      'tempBackupYTVH': YoutubeInfoController.utils.tempBackupVideoInfo,
      'mostplayedPlaylist': YoutubeHistoryController.inst.topTracksMapListens.keys,
      'favouritesPlaylist': YoutubePlaylistController.inst.favouritesPlaylist.value.tracks,
      'playlists': playlists,
      'sendPort': port,
      'token': RootIsolateToken.instance!,
    };
    return IsolateFunctionReturnBuild(_prepareResourcesAndListen, params);
  }

  static void _prepareResourcesAndListen(Map params) async {
    final databasesDir = params['databasesDir'] as String;
    final sensitiveDataDir = params['sensitiveDataDir'] as String;
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

    var lookupListStreamInfoMapCacheDetails = <CacheDetailsBase>[];
    var lookupListVideoStreamsMapCacheDetails = <CacheDetailsBase>[];

    // -- start listening
    StreamSubscription? streamSub;
    streamSub = recievePort.listen((p) async {
      if (PortsProvider.isDisposeMessage(p)) {
        recievePort.close();
        lookupListStreamInfoMapCacheDetails.loop((item) => item.close());
        lookupListVideoStreamsMapCacheDetails.loop((item) => item.close());
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
          final dateReleased = date?.toLocal() ?? releaseDateMap[id];
          if (dateReleased == null) {
            sendPort.send(Exception('Unknown video release date'));
            return;
          }
          final results = <String>[];
          final daysRange = p['daysRange'] as int;
          final videoToRemove = p['videoToRemove'] as String?;
          allIds.loop((id) {
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

    YoutiPie.cacheManager.init(databasesDir);
    final activeChannel = YoutiPie.getActiveAccountChannelIsolate(sensitiveDataDir);
    final activeChannelId = activeChannel?.id;

    if (activeChannelId != null && activeChannelId.isNotEmpty) {
      lookupListStreamInfoMapCacheDetails.add(CacheDetailsBase(YoutiPieSection.streamInfoItem, null, () => activeChannelId));
      lookupListVideoStreamsMapCacheDetails.add(CacheDetailsBase(YoutiPieSection.videoStreams, null, () => activeChannelId));
    }
    // -- damn the annonymous acc videos look saxy
    lookupListStreamInfoMapCacheDetails.add(CacheDetailsBase(YoutiPieSection.streamInfoItem, null, () => null));
    lookupListVideoStreamsMapCacheDetails.add(CacheDetailsBase(YoutiPieSection.videoStreams, null, () => null));

    lookupListStreamInfoMapCacheDetails.loop(
      (db) {
        db.loadEverything(
          (map) {
            try {
              final id = map['id'];
              if (id != null && releaseDateMap[id] == null) {
                DateTime? date;
                try {
                  date = PublishTime.fromMap(map['publishedAt']).date?.toLocal();
                } catch (_) {}
                allIds.add(id);
                allIdsAdded[id] = true;
                releaseDateMap[id] = date;
              }
            } catch (_) {}
          },
        );
      },
    );
    lookupListVideoStreamsMapCacheDetails.loop((db) {
      db.loadEverything(
        (map) {
          try {
            final info = map['info'] as Map;
            final id = info['id'];
            if (id != null && releaseDateMap[id] == null) {
              DateTime? date;
              try {
                date = PublishTime.fromMap(info['publishDate']).date?.toLocal();
              } catch (_) {}
              if (date == null) {
                try {
                  date = PublishTime.fromMap(info['uploadDate']).date?.toLocal();
                } catch (_) {}
              }
              allIds.add(id);
              allIdsAdded[id] = true;
              releaseDateMap[id] = date;
            }
          } catch (_) {}
        },
      );
    });

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
    favouritesPlaylist.loop((v) {
      final id = v.id;
      if (allIdsAdded[id] == null) {
        allIds.add(id);
      }
    });

    for (final pl in playlists.values) {
      pl.loop((v) {
        final id = v.id;
        if (allIdsAdded[id] == null) {
          allIds.add(id);
        }
      });
    }
    // -- end filling from playlists
    sendPort.send(null); // finished filling

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
