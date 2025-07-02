import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';

import 'package:youtipie/class/cache_details.dart';
import 'package:youtipie/class/publish_time.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/class/streams/video_stream_info.dart';
import 'package:youtipie/class/videos/missing_video_info.dart';
import 'package:youtipie/class/youtipie_feed/channel_info_item.dart';
import 'package:youtipie/core/enum.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/base/ports_provider.dart';
import 'package:namida/class/video.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';

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

  String _latestSearch = '';

  YTLocalSearchSortType _sortType = YTLocalSearchSortType.mostPlayed;
  YTLocalSearchSortType get sortType => _sortType;
  set sortType(YTLocalSearchSortType t) {
    _sortType = t;
    final searchList = searchResults.value;
    if (searchList != null) {
      _sortStreams(searchList);
      searchResults.refresh();
    }
  }

  void _sortStreams(List<StreamInfoItem> streams) {
    switch (_sortType) {
      case YTLocalSearchSortType.mostPlayed:
        streams.sortByReverse((e) => YoutubeHistoryController.inst.topTracksMapListens[e.id]?.length ?? 0);
      case YTLocalSearchSortType.latestPlayed:
        streams.sortByReverse((e) => YoutubeHistoryController.inst.topTracksMapListens[e.id]?.lastOrNull ?? 0);
    }
  }

  /// null means a search is on-going
  /// empty means no search request or empty search results.
  final searchResults = Rxn<List<StreamInfoItem>>(const []);

  void search(String text) async {
    if (text == _latestSearch) {
      if (searchResults.value == null) searchResults.value = const [];
      return;
    }

    _latestSearch = text;
    if (scrollController?.hasClients ?? false) scrollController?.jumpTo(0);
    if (text == '') {
      if (searchResults.value == null) searchResults.value = const [];
      return;
    }

    if (isInitialized) searchResults.value = null; // display as loading only if initialized

    final possibleID = text.length == 11 ? text : null;
    final p = {'text': text, 'possibleID': possibleID};
    await sendPort(p);
  }

  @override
  void onResult(dynamic result) {
    result as List<StreamInfoItem>;
    _sortStreams(result);
    searchResults.value = result;
  }

  @override
  IsolateFunctionReturnBuild<Map> isolateFunction(SendPort port) {
    final params = {
      'databasesDir': AppDirs.YOUTIPIE_CACHE,
      'sensitiveDataDir': AppDirs.YOUTIPIE_DATA,
      'statsDir': AppDirs.YT_STATS,
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
    final statsDir = params['statsDir'] as String;
    final enableFuzzySearch = params['enableFuzzySearch'] as bool;
    final sendPort = params['sendPort'] as SendPort;

    final recievePort = ReceivePort();
    sendPort.send(recievePort.sendPort);

    final lookupItemAvailable = <String, ({int list, int index})>{};

    final lookupListStreamInfoMap = <_StreamResultInfoWrapper>[]; // StreamInfoItem
    final lookupListVideoStreamsMap = <_StreamResultInfoWrapper>[]; // VideoStreamInfo
    final lookupListVideoMissingInfo = <_StreamResultInfoWrapper>[]; // MissingVideoInfo
    final lookupListYTVH = <_StreamResultInfoWrapper>[];

    var lookupListStreamInfoMapCacheDetails = <CacheDetailsBase>[];
    var lookupListVideoStreamsMapCacheDetails = <CacheDetailsBase>[];
    var lookupListVideoMissingVideoCacheDetails = <CacheDetailsBase>[];

    // -- start listening
    StreamSubscription? streamSub;
    streamSub = recievePort.listen((p) {
      if (PortsProvider.isDisposeMessage(p)) {
        recievePort.close();
        lookupListStreamInfoMapCacheDetails.loop((item) => item.close());
        lookupListVideoStreamsMapCacheDetails.loop((item) => item.close());
        lookupListVideoMissingVideoCacheDetails.loop((item) => item.close());
        lookupListVideoMissingInfo.clear();
        lookupListYTVH.clear();
        lookupListStreamInfoMap.clear();
        lookupListVideoStreamsMap.clear();
        lookupItemAvailable.clear();
        streamSub?.cancel();
        return;
      }
      p as Map;
      final textPre = p['text'] as String;
      final possibleID = p['possibleID'] as String?;

      final searchResults = <StreamInfoItem>[];

      if (possibleID != null && possibleID != '') {
        try {
          final res = lookupItemAvailable[possibleID];
          if (res != null) {
            switch (res.list) {
              case 2:
                final wrapper = lookupListStreamInfoMap[res.index];
                searchResults.add(wrapper.info);
                break;
              case 3:
                final wrapper = lookupListVideoStreamsMap[res.index];
                searchResults.add(wrapper.info);
                break;
              case 4:
                final wrapper = lookupListVideoMissingInfo[res.index];
                searchResults.add(wrapper.info);
                break;
              case 5:
                final wrapper = lookupListYTVH[res.index];
                searchResults.add(wrapper.info);
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

      bool isMatch(_StreamResultInfoWrapper wrapper) {
        return enableFuzzySearch ? _isMatchFuzzy(textPre.split(' ').map((e) => e.cleanUpForComparison), wrapper) : _isMatchStrict(textCleaned, wrapper);
      }

      void addToResultsIfMatch(_StreamResultInfoWrapper wrapper) {
        if (isMatch(wrapper)) {
          searchResults.add(wrapper.info);
        }
      }

      // -----------------------------------
      final list2 = lookupListStreamInfoMap;
      final l2 = list2.length;
      for (int i = 0; i < l2; i++) {
        addToResultsIfMatch(list2[i]);
      }

      // -----------------------------------
      final list3 = lookupListVideoStreamsMap;
      final l3 = list3.length;
      for (int i = 0; i < l3; i++) {
        addToResultsIfMatch(list3[i]);
      }

      // -----------------------------------
      final list4 = lookupListVideoMissingInfo;
      final l4 = list4.length;
      for (int i = 0; i < l4; i++) {
        addToResultsIfMatch(list4[i]);
      }

      // -----------------------------------
      final list5 = lookupListYTVH;
      final l5 = list5.length;
      for (int i = 0; i < l5; i++) {
        addToResultsIfMatch(list5[i]);
      }

      sendPort.send(searchResults);
    });
    // -- end listening

    // -- start filling info
    final start = DateTime.now();

    YoutiPie.cacheManager.init(databasesDir);
    YoutiPie.cacheManagerSync.init(databasesDir);
    final activeChannel = await YoutiPie.getActiveAccountChannelIsolate(sensitiveDataDir);
    final activeChannelId = activeChannel?.id;

    if (activeChannelId != null && activeChannelId.isNotEmpty) {
      lookupListStreamInfoMapCacheDetails.add(CacheDetailsBase(YoutiPieSection.streamInfoItem, null, () => activeChannelId));
      lookupListVideoStreamsMapCacheDetails.add(CacheDetailsBase(YoutiPieSection.videoStreams, null, () => activeChannelId));
      lookupListVideoMissingVideoCacheDetails.add(CacheDetailsBase(YoutiPieSection.missingInfo, null, () => activeChannelId));
    }
    // -- damn the annonymous acc videos look saxy
    lookupListStreamInfoMapCacheDetails.add(CacheDetailsBase(YoutiPieSection.streamInfoItem, null, () => null));
    lookupListVideoStreamsMapCacheDetails.add(CacheDetailsBase(YoutiPieSection.videoStreams, null, () => null));
    lookupListVideoMissingVideoCacheDetails.add(CacheDetailsBase(YoutiPieSection.missingInfo, null, () => null));

    final faultyTitlesBackupList = <String, void Function()>{}; // a list of items with faulty title to add later if no other list added it.
    bool onAddItem(_StreamResultInfoWrapper info, List<_StreamResultInfoWrapper> listToAdd, int listNumber) {
      final id = info.id;
      final title = info.titleCleaned;
      if (id.isEmpty) return false;
      if (title.isEmpty) return false;
      if (lookupItemAvailable[id] != null) return false;
      if (title.isYTTitleFaulty()) {
        // null aware ??= bcz usually first lists have better details.
        faultyTitlesBackupList[id] ??= () {
          listToAdd.add(info);
          lookupItemAvailable[id] = (list: listNumber, index: listToAdd.length - 1);
        };
        return false;
      }
      listToAdd.add(info);
      lookupItemAvailable[id] = (list: listNumber, index: listToAdd.length - 1);
      return true;
    }

    lookupListStreamInfoMapCacheDetails.loop(
      (db) {
        db.loadEverythingSync((map) {
          try {
            final info = StreamInfoItem.fromMap(map);
            final wrapper = _StreamResultInfoWrapper.fromInfo(info);
            onAddItem(wrapper, lookupListStreamInfoMap, 2);
          } catch (_) {}
        });
        db.close();
      },
    );
    lookupListVideoStreamsMapCacheDetails.loop(
      (db) {
        db.loadEverythingSync((wholeStreamsResultMap) {
          try {
            final map = wholeStreamsResultMap['info'] as Map; // VideoStreamInfo
            final info = VideoStreamInfo.fromMap(map).toStreamInfo();
            final wrapper = _StreamResultInfoWrapper.fromInfo(info);
            onAddItem(wrapper, lookupListVideoStreamsMap, 3);
          } catch (_) {}
        });
        db.close();
      },
    );

    lookupListVideoMissingVideoCacheDetails.loop(
      (db) {
        db.loadEverythingSync((map) {
          try {
            final info = MissingVideoInfo.fromMap(map).toStreamInfo();
            final wrapper = _StreamResultInfoWrapper.fromInfo(info);
            onAddItem(wrapper, lookupListVideoMissingInfo, 4);
          } catch (_) {}
        });
        db.close();
      },
    );

    Directory(statsDir).listSyncSafe().loop((f) {
      if (f is File) {
        try {
          final response = f.readAsJsonSync(ensureExists: false);
          if (response is List) {
            response.loop(
              (map) {
                final info = YoutubeVideoHistory.fromJson(map).toStreamInfo();
                final wrapper = _StreamResultInfoWrapper.fromInfo(info);
                onAddItem(wrapper, lookupListYTVH, 5);
              },
            );
          }
        } catch (_) {}
      }
    });

    for (final item in faultyTitlesBackupList.entries) {
      final alreadyAdded = lookupItemAvailable[item.key] != null;
      if (!alreadyAdded) item.value(); // add function
    }

    sendPort.send(null); // finished filling

    YoutiPie.cacheManager.closeAll();
    YoutiPie.cacheManagerSync.closeAll();

    final durationTaken = start.difference(DateTime.now());

    printo('Initialized 4 Lists in $durationTaken');
    printo('''Initialized lookupListStreamInfoMap: ${lookupListStreamInfoMap.length} | 
        lookupListVideoStreamsMap: ${lookupListVideoStreamsMap.length} |
        lookupListVideoMissingInfo: ${lookupListVideoMissingInfo.length} |
        lookupListYTVH: ${lookupListYTVH.length}''');
    // -- end filling info
  }

  // List<int> _getTotalListensForID(String? id) {
  //   final finalListens = <int>[];
  //   final correspondingTrack = _localIdTrackMap![id];
  //   if (correspondingTrack != null) {
  //     final l = HistoryController.inst.topTracksMapListens.value[correspondingTrack];
  //     if (l != null) finalListens.addAll(l);
  //   }

  //   final yt = YoutubeHistoryController.inst.topTracksMapListens.value[id] ?? [];

  //   finalListens.addAll(yt);
  //   return finalListens;
  // }

  static bool _isMatchStrict(String textCleaned, _StreamResultInfoWrapper wrapper) {
    return wrapper.titleCleaned.contains(textCleaned) || (wrapper.channelCleaned?.contains(textCleaned) ?? false);
  }

  static bool _isMatchFuzzy(Iterable<String> splittedText, _StreamResultInfoWrapper wrapper) {
    return splittedText.every((element) =>
            wrapper.titleCleaned.contains(element) || //
            (wrapper.channelCleaned?.contains(element) ?? false) //
        );
  }

  Timer? _disposingTimer;

  void _cancelDisposingTimer() {
    _disposingTimer?.cancel();
    _disposingTimer = null;
  }

  void cleanResources() {
    _cancelDisposingTimer();
    searchResults.value = const [];
    _disposingTimer = Timer(Duration(minutes: 1), () {
      fillingCompleter?.completeIfWasnt();
      fillingCompleter = null;
      disposePort();
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
      isActuallyShortContent: null,
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
      isActuallyShortContent: null,
    );
  }
}

extension _MissingVideoInfoExt on MissingVideoInfo {
  StreamInfoItem toStreamInfo() {
    return StreamInfoItem(
      id: videoId,
      title: title ?? videoPage?.videoInfo?.title ?? '',
      channel: ChannelInfoItem(
        id: channelId ?? videoPage?.channelInfo?.id ?? '',
        handler: videoPage?.channelInfo?.handler ?? '',
        title: channelName ?? videoPage?.channelInfo?.title ?? '',
        thumbnails: videoPage?.channelInfo?.thumbnails ?? const [],
      ),
      shortDescription: description ?? videoPage?.videoInfo?.description?.rawText,
      thumbnailGifUrl: null,
      publishedFromText: '',
      publishedAt: date,
      indexInPlaylist: null,
      durSeconds: durSeconds,
      durText: null,
      viewsText: videoPage?.videoInfo?.viewsText,
      viewsCount: videoPage?.videoInfo?.viewsCount,
      percentageWatched: null,
      liveThumbs: [],
      isUploaderVerified: videoPage?.channelInfo?.isVerified,
      badges: [],
      isActuallyShortContent: null,
    );
  }
}

class _StreamResultInfoWrapper {
  final String titleCleaned;
  final String? channelCleaned;
  final StreamInfoItem info;

  String get id => info.id;

  const _StreamResultInfoWrapper({
    required this.titleCleaned,
    required this.channelCleaned,
    required this.info,
  });

  factory _StreamResultInfoWrapper.fromInfo(StreamInfoItem info) {
    String? channelTitle = info.channel?.title;
    if (channelTitle?.isEmpty ?? true) channelTitle = null;

    return _StreamResultInfoWrapper(
      titleCleaned: info.title.cleanUpForComparison,
      channelCleaned: channelTitle?.cleanUpForComparison,
      info: info,
    );
  }
}
