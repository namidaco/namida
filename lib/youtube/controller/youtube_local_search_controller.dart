import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';

import 'package:youtipie/class/cache_details.dart';
import 'package:youtipie/class/publish_time.dart';
import 'package:youtipie/class/search_filters.dart';
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
  firstListen,
}

class YTLocalSearchController with PortsProvider<Map> {
  static final YTLocalSearchController inst = YTLocalSearchController._internal();
  YTLocalSearchController._internal();

  final didLoadLookupLists = false.obs;
  Completer<void>? fillingCompleter;

  bool enableFuzzySearch = true;

  ScrollController? scrollController;

  String _latestSearch = '';
  YoutiPieSearchDate? _latestAfter;
  YoutiPieSearchDate? _latestBefore;

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
    if (streams.isEmpty) return; // cuz empty might be const
    switch (_sortType) {
      case YTLocalSearchSortType.mostPlayed:
        streams.sortBy((e) => -(YoutubeHistoryController.inst.topTracksMapListens.value[e.id]?.length ?? 0));
      case YTLocalSearchSortType.latestPlayed:
        streams.sortBy((e) => -(YoutubeHistoryController.inst.topTracksMapListens.value[e.id]?.lastOrNull ?? 0));
      case YTLocalSearchSortType.firstListen:
        streams.sortBy((e) => YoutubeHistoryController.inst.topTracksMapListens.value[e.id]?.firstOrNull ?? DateTime(99999).millisecondsSinceEpoch);
    }
  }

  /// null means a search is on-going
  /// empty means no search request or empty search results.
  final searchResults = Rxn<List<StreamInfoItem>>(const []);

  void search(String text, {YoutiPieSearchDate? after, YoutiPieSearchDate? before}) async {
    final parsedDates = YoutiPieSearchFilters.parseDateOperators(text);
    if (parsedDates != null) {
      text = YoutiPieSearchFilters.stripDateOperators(text);
      after ??= parsedDates.after;
      before ??= parsedDates.before;
    }

    if (text == _latestSearch && after == _latestAfter && before == _latestBefore) {
      if (searchResults.value == null) searchResults.value = const [];
      return;
    }

    _latestSearch = text;
    _latestAfter = after;
    _latestBefore = before;
    if (scrollController?.hasClients ?? false) scrollController?.jumpTo(0);
    if (text == '') {
      if (searchResults.value == null) searchResults.value = const [];
      return;
    }

    if (isInitialized) {
      searchResults.value = null; // display as loading only if initialized
    } else {
      // -- the port may not exist yet, & the isolate can't answer before filling anyway.
      await initialize();
      if (text != _latestSearch || after != _latestAfter || before != _latestBefore) return; // -- a newer search took over
      searchResults.value = null;
    }

    final possibleID = text.length == 11 ? text : null;
    final p = {
      'text': text,
      'possibleID': possibleID,
      'afterMs': ?after?.toDateTimeUtc().millisecondsSinceEpoch,
      'beforeMs': ?before?.toDateTimeUtc().millisecondsSinceEpoch,
    };
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

    final lookupItemAvailable = <String, _LookupEntry>{};
    final lookupList = <_LookupEntry>[];
    final sources = <_LookupSource>[];

    List<StreamInfoItem> resolveInfos(List<_LookupEntry> entries) {
      final infos = <StreamInfoItem>[];
      final keysPerSource = List.generate(sources.length, (_) => <String>[], growable: false);
      for (final entry in entries) {
        final info = entry.info;
        if (info != null) {
          infos.add(info);
        } else {
          keysPerSource[entry.sourceIndex].add(entry.id);
        }
      }
      for (int i = 0; i < sources.length; i++) {
        final keys = keysPerSource[i];
        if (keys.isEmpty) continue;
        final source = sources[i];
        final List<Map<String, dynamic>> maps;
        try {
          maps = source.db.readAllMapsSync(keys);
        } catch (_) {
          continue;
        }
        for (final map in maps) {
          try {
            infos.add(source.toInfo(map));
          } catch (_) {}
        }
      }
      return infos;
    }

    // -- start listening
    StreamSubscription? streamSub;
    streamSub = recievePort.listen((p) {
      if (PortsProvider.isDisposeMessage(p)) {
        recievePort.close();
        for (final source in sources) {
          source.db.close();
        }
        sources.clear();
        lookupList.clear();
        lookupItemAvailable.clear();
        streamSub?.cancel();
        return;
      }
      p as Map;
      final textPre = p['text'] as String;
      final possibleID = p['possibleID'] as String?;
      final afterMs = p['afterMs'] as int?;
      final beforeMs = p['beforeMs'] as int?;

      if (possibleID != null && possibleID != '') {
        final entry = lookupItemAvailable[possibleID];
        if (entry != null) {
          final infos = resolveInfos([entry]);
          if (infos.isNotEmpty) {
            sendPort.send(infos);
            return;
          }
        }
      }

      final textCleaned = textPre.cleanUpForComparison;
      final splittedText = enableFuzzySearch ? textPre.split(' ').map((e) => e.cleanUpForComparison).toList() : const <String>[];

      bool isMatchText(_LookupEntry entry) {
        return enableFuzzySearch ? _isMatchFuzzy(splittedText, entry) : _isMatchStrict(textCleaned, entry);
      }

      bool isMatchDate(_LookupEntry entry) {
        final publishedMs = entry.publishedMs;
        if (publishedMs == null) return false;
        if (afterMs != null && publishedMs < afterMs) return false;
        if (beforeMs != null && publishedMs >= beforeMs) return false;
        return true;
      }

      final isMatch = afterMs == null && beforeMs == null ? isMatchText : (entry) => isMatchDate(entry) && isMatchText(entry);

      final matched = <_LookupEntry>[];
      for (final entry in lookupList) {
        if (isMatch(entry)) matched.add(entry);
      }

      sendPort.send(resolveInfos(matched));
    });
    // -- end listening

    // -- start filling info
    final start = DateTime.now();

    try {
      YoutiPie.cacheManager.init(databasesDir);
      YoutiPie.cacheManagerSync.init(databasesDir);
      final activeChannel = await YoutiPie.getActiveAccountChannelIsolate(sensitiveDataDir);
      final activeChannelId = activeChannel?.id;

      final accountIds = <String?>[
        if (activeChannelId != null && activeChannelId.isNotEmpty) activeChannelId,
        null, // -- damn the annonymous acc videos look saxy
      ];
      for (final accId in accountIds) {
        sources.add(_LookupSource.streamInfoItem(accId));
      }
      for (final accId in accountIds) {
        sources.add(_LookupSource.videoStreams(accId));
      }
      for (final accId in accountIds) {
        sources.add(_LookupSource.missingInfo(accId));
      }

      final faultyTitlesBackupList = <String, _LookupEntry>{}; // a list of items with faulty title to add later if no other list added it.
      void onAddEntry(_LookupEntry entry) {
        final id = entry.id;
        final title = entry.titleCleaned;
        if (id.isEmpty) return;
        if (title.isEmpty) return;
        if (lookupItemAvailable[id] != null) return;
        if (title.isYTTitleFaulty()) {
          // null aware ??= bcz usually first lists have better details.
          faultyTitlesBackupList[id] ??= entry;
          return;
        }
        lookupList.add(entry);
        lookupItemAvailable[id] = entry;
      }

      for (int i = 0; i < sources.length; i++) {
        final source = sources[i];
        try {
          source.db.loadEverythingExtractedSync(source.jsonPaths, (key, values) {
            final entry = source.toEntry(key, values, i);
            if (entry != null) onAddEntry(entry);
          });
        } catch (e, st) {
          printo('$e\n$st', isError: true);
        }
      }

      final files = Directory(statsDir).listSyncSafe();
      for (var f in files) {
        if (f is File) {
          try {
            final response = f.readAsJsonSync(ensureExists: false);
            if (response is List) {
              for (var map in response) {
                final info = YoutubeVideoHistory.fromJson(map).toStreamInfo();
                onAddEntry(_LookupEntry.inMemory(info));
              }
            }
          } catch (_) {}
        }
      }

      for (final item in faultyTitlesBackupList.entries) {
        final alreadyAdded = lookupItemAvailable[item.key] != null;
        if (!alreadyAdded) {
          lookupList.add(item.value);
          lookupItemAvailable[item.key] = item.value;
        }
      }
    } catch (e, st) {
      printo('$e\n$st', isError: true);
    } finally {
      sendPort.send(null); // finished filling
    }

    final durationTaken = start.difference(DateTime.now());
    printo('Initialized ${lookupList.length} items from ${sources.length} sources in $durationTaken');
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

  static bool _isMatchStrict(String textCleaned, _LookupEntry entry) {
    return entry.titleCleaned.contains(textCleaned) || (entry.channelCleaned?.contains(textCleaned) ?? false);
  }

  static bool _isMatchFuzzy(List<String> splittedText, _LookupEntry entry) {
    final titleCleaned = entry.titleCleaned;
    final channelCleaned = entry.channelCleaned;
    for (int i = 0; i < splittedText.length; i++) {
      final element = splittedText[i];
      if (titleCleaned.contains(element)) continue;
      if (channelCleaned != null && channelCleaned.contains(element)) continue;
      return false;
    }
    return true;
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

class _LookupEntry {
  final String id;
  final String titleCleaned;
  final String? channelCleaned;
  final int? publishedMs;

  /// index inside sources list, -1 when [info] is held in memory.
  final int sourceIndex;
  final StreamInfoItem? info;

  const _LookupEntry({
    required this.id,
    required this.titleCleaned,
    required this.channelCleaned,
    required this.publishedMs,
    required this.sourceIndex,
    this.info,
  });

  factory _LookupEntry.inMemory(StreamInfoItem info) {
    return _LookupEntry(
      id: info.id,
      titleCleaned: info.title.cleanUpForComparison,
      channelCleaned: _cleanChannel(info.channel?.title),
      publishedMs: info.publishedAt.date?.millisecondsSinceEpoch,
      sourceIndex: -1,
      info: info,
    );
  }

  static String? _cleanChannel(Object? channelTitle) {
    if (channelTitle is! String || channelTitle.isEmpty) return null;
    return channelTitle.cleanUpForComparison;
  }
}

/// A db of cached video infos, indexed by sqlite-extracted json fields & decoded fully only on match.
// by claude, good shi
class _LookupSource {
  final CacheDetailsBase db;
  final List<String> jsonPaths;
  final StreamInfoItem Function(Map<String, dynamic> map) toInfo;

  const _LookupSource({required this.db, required this.jsonPaths, required this.toInfo});

  _LookupSource.streamInfoItem(String? accId)
    : db = CacheDetailsBase(YoutiPieSection.streamInfoItem, null, () => accId),
      jsonPaths = const [r'$.title', r'$.channel.title', r'$.publishedAt.date'],
      toInfo = StreamInfoItem.fromMap;

  _LookupSource.videoStreams(String? accId)
    : db = CacheDetailsBase(YoutiPieSection.videoStreams, null, () => accId),
      jsonPaths = const [r'$.info.title', r'$.info.channelName', r'$.info.publishDate.date'],
      toInfo = _videoStreamsToInfo;

  _LookupSource.missingInfo(String? accId)
    : db = CacheDetailsBase(YoutiPieSection.missingInfo, null, () => accId),
      jsonPaths = const [r'$.title', r'$.channelName', r'$.date.date', r'$.videoPage.videoInfo.title', r'$.videoPage.channelInfo.title'],
      toInfo = _missingInfoToInfo;

  static StreamInfoItem _videoStreamsToInfo(Map<String, dynamic> map) => VideoStreamInfo.fromMap(map['info'] as Map).toStreamInfo();
  static StreamInfoItem _missingInfoToInfo(Map<String, dynamic> map) => MissingVideoInfo.fromMap(map).toStreamInfo();

  /// [values] follow [jsonPaths] order, the first 3 are always title, channel, publish date ms.
  /// extra paths are fallbacks for title & channel respectively.
  _LookupEntry? toEntry(String key, List<Object?> values, int sourceIndex) {
    Object? title = values[0];
    Object? channel = values[1];
    if (title is! String && values.length > 3) title = values[3];
    if (channel is! String && values.length > 4) channel = values[4];
    if (title is! String) return null;
    final publishedMs = values[2];
    return _LookupEntry(
      id: key,
      titleCleaned: title.cleanUpForComparison,
      channelCleaned: _LookupEntry._cleanChannel(channel),
      publishedMs: publishedMs is int ? publishedMs : null,
      sourceIndex: sourceIndex,
    );
  }
}
