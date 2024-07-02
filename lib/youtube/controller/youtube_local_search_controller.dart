import 'dart:async';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:youtipie/class/cache_details.dart';
import 'package:youtipie/class/publish_time.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/class/streams/video_stream_info.dart';
import 'package:youtipie/class/youtipie_feed/channel_info_item.dart';
import 'package:youtipie/core/enum.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/base/ports_provider.dart';
import 'package:namida/class/video.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';

enum YTLocalSearchSortType {
  mostPlayed,
  latestPlayed,
}

class YTLocalSearchController with PortsProvider<Map> {
  static final YTLocalSearchController inst = YTLocalSearchController._internal();
  YTLocalSearchController._internal();

  final didLoadLookupLists = false.obs;
  Completer<void>? fillingCompleter;

  bool enableFuzzySearch = true;

  ScrollController? scrollController;

  // String _latestSearch = '';

  YTLocalSearchSortType _sortType = YTLocalSearchSortType.mostPlayed;
  YTLocalSearchSortType get sortType => _sortType;
  set sortType(YTLocalSearchSortType t) {
    _sortType = t;
    _sortStreams(searchResults);
  }

  void _sortStreams(List<StreamInfoItem> streams) {
    switch (_sortType) {
      case YTLocalSearchSortType.mostPlayed:
        streams.sortByReverse((e) => YoutubeHistoryController.inst.topTracksMapListens[e.id]?.length ?? 0);
      case YTLocalSearchSortType.latestPlayed:
        streams.sortByReverse((e) => YoutubeHistoryController.inst.topTracksMapListens[e.id]?.lastOrNull ?? 0);
      default:
        null;
    }
  }

  var searchResults = <StreamInfoItem>[];

  void search(String text, {int? maxResults}) async {
    // _latestSearch = text;
    if (scrollController?.hasClients ?? false) scrollController?.jumpTo(0);
    if (text == '') return;

    for (final l in _onSearchStartListeners.entries) {
      l.value();
    }
    final possibleID = text.getYoutubeID;
    final p = {'text': text, 'maxResults': maxResults, 'possibleID': possibleID};
    await sendPort(p);
  }

  final _onSearchDoneListeners = <String, void Function(bool hasItems)>{};
  final _onSearchStartListeners = <String, void Function()>{};

  void addOnSearchDone(String key, void Function(bool hasItems) onDone) {
    _onSearchDoneListeners[key] = onDone;
  }

  void removeOnSearchDone(String key) {
    _onSearchDoneListeners.remove(key);
  }

  void addOnSearchStart(String key, void Function() onStart) {
    _onSearchStartListeners[key] = onStart;
  }

  void removeOnSearchStart(String key) {
    _onSearchStartListeners.remove(key);
  }

  @override
  void onResult(dynamic result) {
    result as List<StreamInfoItem>;
    _sortStreams(result);
    searchResults = result;
    for (final l in _onSearchDoneListeners.entries) {
      l.value(result.isNotEmpty);
    }
  }

  @override
  IsolateFunctionReturnBuild<Map> isolateFunction(SendPort port) {
    final params = {
      'databasesDir': AppDirs.YOUTIPIE_CACHE,
      'sensitiveDataDir': AppDirs.YOUTIPIE_DATA,
      'tempBackupYTVH': YoutubeInfoController.utils.tempBackupVideoInfo,
      'enableFuzzySearch': enableFuzzySearch,
      'sendPort': port,
    };
    return IsolateFunctionReturnBuild(_prepareResourcesAndSearch, params);
  }

  @override
  void onPreparing(bool prepared) {
    didLoadLookupLists.value = prepared;
  }

  @override
  Future<void> initialize() async {
    _cancelDisposingTimer();
    return super.initialize();
  }

  static void _prepareResourcesAndSearch(Map params) async {
    final databasesDir = params['databasesDir'] as String;
    final sensitiveDataDir = params['sensitiveDataDir'] as String;
    final tempBackupYTVH = params['tempBackupYTVH'] as Map<String, YoutubeVideoHistory>;
    final enableFuzzySearch = params['enableFuzzySearch'] as bool;
    final sendPort = params['sendPort'] as SendPort;

    final recievePort = ReceivePort();
    sendPort.send(recievePort.sendPort);

    final lookupItemAvailable = <String, ({int list, int index})>{};

    final lookupListStreamInfoMap = <Map<String, dynamic>>[]; // StreamInfoItem
    final lookupListVideoStreamsMap = <Map<String, dynamic>>[]; // VideoStreamInfo
    final lookupListYTVH = <YoutubeVideoHistory>[];

    var lookupListStreamInfoMapCacheDetails = <CacheDetailsBase>[];
    var lookupListVideoStreamsMapCacheDetails = <CacheDetailsBase>[];

    // -- start listening
    StreamSubscription? streamSub;
    streamSub = recievePort.listen((p) {
      if (PortsProvider.isDisposeMessage(p)) {
        recievePort.close();
        lookupListStreamInfoMapCacheDetails.loop((item) => item.close());
        lookupListVideoStreamsMapCacheDetails.loop((item) => item.close());
        lookupListYTVH.clear();
        lookupListStreamInfoMap.clear();
        lookupListVideoStreamsMap.clear();
        lookupItemAvailable.clear();
        streamSub?.cancel();
        return;
      }
      p as Map;
      final textPre = p['text'] as String;
      final maxResults = p['maxResults'] as int?;
      final possibleID = p['possibleID'] as String;

      final searchResults = <StreamInfoItem>[];

      if (possibleID != '') {
        try {
          final res = lookupItemAvailable[possibleID];
          if (res != null) {
            switch (res.list) {
              case 2:
                final info = lookupListStreamInfoMap[res.index];
                searchResults.add(StreamInfoItem.fromMap(info));
                break;
              case 3:
                final info = lookupListVideoStreamsMap[res.index];
                searchResults.add(VideoStreamInfo.fromMap(info).toStreamInfo());
                break;
              case 4:
                final info = lookupListYTVH[res.index];
                searchResults.add(info.toStreamInfo());
                break;
            }
          }
        } catch (_) {}

        if (searchResults.isNotEmpty) {
          sendPort.send(searchResults);
          return;
        }
      }

      final textCleaned = textPre.cleanUpForComparison;

      bool isMatch(String? title, String? channel) {
        return enableFuzzySearch ? _isMatchFuzzy(textPre.split(' ').map((e) => e.cleanUpForComparison), title, channel) : _isMatchStrict(textCleaned, title, channel);
      }

      bool shouldBreak() => maxResults != null && searchResults.length >= maxResults;

      // -----------------------------------

      if (!shouldBreak()) {
        final list2 = lookupListStreamInfoMap;
        final l2 = list2.length;
        for (int i = 0; i < l2; i++) {
          final info = list2[i];
          if (isMatch(info['title'], info['channel']?['title'] as String?)) {
            searchResults.add(StreamInfoItem.fromMap(info));
            if (shouldBreak()) break;
          }
        }
      }

      // -----------------------------------
      if (!shouldBreak()) {
        final list3 = lookupListVideoStreamsMap;
        final l3 = list3.length;
        for (int i = 0; i < l3; i++) {
          final info = list3[i];
          if (isMatch(info['title'], info['channelName'])) {
            searchResults.add(VideoStreamInfo.fromMap(info).toStreamInfo());
            if (shouldBreak()) break;
          }
        }
      }
      // -----------------------------------

      if (!shouldBreak()) {
        final list4 = lookupListYTVH;
        final l4 = list4.length;
        for (int i = 0; i < l4; i++) {
          final info = list4[i];
          if (isMatch(info.title, info.channel)) {
            searchResults.add(info.toStreamInfo());
            if (shouldBreak()) break;
          }
        }
      }
      sendPort.send(searchResults);
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
        db.loadEverything((map) {
          try {
            final id = map['id'];
            if (id != null && lookupItemAvailable[id] == null) {
              lookupListStreamInfoMap.add(map);
              lookupItemAvailable[id] = (list: 2, index: lookupListStreamInfoMap.length - 1);
            }
          } catch (_) {}
        });
      },
    );
    lookupListVideoStreamsMapCacheDetails.loop(
      (db) {
        db.loadEverything((map) {
          try {
            final info = map['info'] as Map;
            final id = info['id'];
            if (id != null && lookupItemAvailable[id] == null) {
              lookupListVideoStreamsMap.add(info.cast());
              lookupItemAvailable[id] = (list: 3, index: lookupListVideoStreamsMap.length - 1);
            }
          } catch (_) {}
        });
      },
    );

    for (final id in tempBackupYTVH.keys) {
      if (lookupItemAvailable[id] == null) {
        final val = tempBackupYTVH[id]!;
        lookupListYTVH.add(val);
        lookupItemAvailable[id] = (list: 4, index: lookupListYTVH.length - 1);
      }
    }
    sendPort.send(null); // finished filling

    final durationTaken = start.difference(DateTime.now());
    printo('Initialized 3 Lists in $durationTaken');
    printo('''Initialized lookupListStreamInfoMap: ${lookupListStreamInfoMap.length} | 
        lookupListVideoStreamsMap: ${lookupListVideoStreamsMap.length} | lookupListYTVH: ${lookupListYTVH.length}''');
    // -- end filling info
  }

  // List<int> _getTotalListensForID(String? id) {
  //   final finalListens = <int>[];
  //   final correspondingTrack = _localIdTrackMap![id];
  //   if (correspondingTrack != null) {
  //     final l = HistoryController.inst.topTracksMapListens[correspondingTrack];
  //     if (l != null) finalListens.addAll(l);
  //   }

  //   final yt = YoutubeHistoryController.inst.topTracksMapListens[id] ?? [];

  //   finalListens.addAll(yt);
  //   finalListens.sortByReverse((e) => e);
  //   return finalListens;
  // }

  static bool _isMatchStrict(String textCleaned, String? title, String? channel) {
    return (title?.cleanUpForComparison.contains(textCleaned) ?? false) || (channel?.cleanUpForComparison.contains(textCleaned) ?? false);
  }

  static bool _isMatchFuzzy(Iterable<String> splittedText, String? title, String? channel) {
    final titleAndChannel = [
      if (title != null) title.cleanUpForComparison,
      if (channel != null) channel.cleanUpForComparison,
    ];
    return splittedText.every((element) => titleAndChannel.any((p) => p.contains(element)));
  }

  Timer? _disposingTimer;

  void _cancelDisposingTimer() {
    _disposingTimer?.cancel();
    _disposingTimer = null;
  }

  void cleanResources({int afterSeconds = 10}) {
    _cancelDisposingTimer();
    _disposingTimer = Timer(Duration(seconds: afterSeconds), () {
      fillingCompleter?.completeIfWasnt();
      fillingCompleter = null;
      disposePort();
      searchResults.clear();
      scrollController?.dispose();
      scrollController = null;
    });
  }
}

extension _VideoInfoUtils on VideoStreamInfo {
  StreamInfoItem toStreamInfo() {
    final vid = this;
    return StreamInfoItem(
      id: vid.id,
      title: vid.title,
      shortDescription: vid.availableDescription,
      channel: ChannelInfoItem(
        id: vid.channelId ?? '',
        handler: '',
        title: vid.channelName ?? '',
        thumbnails: [],
      ),
      thumbnailGifUrl: null,
      publishedFromText: '', // should never be used, use [publishedAt] instead.
      publishedAt: vid.publishedAt,
      indexInPlaylist: null,
      durSeconds: null,
      durText: null,
      viewsText: vid.viewsCount.toString(),
      viewsCount: vid.viewsCount,
      percentageWatched: null,
      liveThumbs: vid.thumbnails,
      isUploaderVerified: null,
      badges: null,
    );
  }
}

extension _YTVHToVideoInfo on YoutubeVideoHistory {
  StreamInfoItem toStreamInfo() {
    final chId = channelUrl.splitLast('/');
    return StreamInfoItem(
      id: id,
      title: title,
      channel: ChannelInfoItem(
        id: chId,
        handler: '',
        title: channel,
        thumbnails: [],
      ),
      shortDescription: null,
      thumbnailGifUrl: null,
      publishedFromText: '',
      publishedAt: const PublishTime.unknown(),
      indexInPlaylist: null,
      durSeconds: null,
      durText: null,
      viewsText: null,
      viewsCount: null,
      percentageWatched: null,
      liveThumbs: [],
      isUploaderVerified: null,
      badges: [],
    );
  }
}
