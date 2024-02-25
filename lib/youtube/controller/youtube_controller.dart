// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart' hide EnumUtils;

import 'package:namida/class/video.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/ffmpeg_controller.dart';
import 'package:namida/controller/notification_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/thumbnail_manager.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/youtube/class/youtube_item_download_config.dart';
import 'package:namida/youtube/controller/parallel_downloads_controller.dart';
import 'package:namida/youtube/controller/youtube_ongoing_finished_downloads.dart';
import 'package:namida/youtube/yt_utils.dart';

class YTThumbnail {
  final String id;
  const YTThumbnail(this.id);
  String get maxResUrl => StreamThumbnail(id).maxresdefault;
  String get hqdefault => StreamThumbnail(id).hqdefault;
  String get mqdefault => StreamThumbnail(id).mqdefault;
  String get sddefault => StreamThumbnail(id).sddefault;
  String get lowres => StreamThumbnail(id).lowres;
  List<String> get allQualitiesByHighest => [maxResUrl, hqdefault, mqdefault, sddefault, lowres];
}

class DownloadProgress {
  final int progress;
  final int totalProgress;

  const DownloadProgress({
    required this.progress,
    required this.totalProgress,
  });
}

class YoutubeController {
  static YoutubeController get inst => _instance;
  static final YoutubeController _instance = YoutubeController._internal();
  YoutubeController._internal() {
    scrollController.addListener(() {
      final pixels = scrollController.positions.lastOrNull?.pixels;
      final hasScrolledEnough = pixels != null && pixels > 40;
      _shouldShowGlowUnderVideo.value = hasScrolledEnough;
    });
  }
  void resetGlowUnderVideo() => _shouldShowGlowUnderVideo.value = false;

  int get _defaultMiniplayerDimSeconds => settings.ytMiniplayerDimAfterSeconds.value;
  double get _defaultMiniplayerOpacity => settings.ytMiniplayerDimOpacity.value;
  bool get canDimMiniplayer => _canDimMiniplayer.value;
  final _canDimMiniplayer = false.obs;
  Timer? _dimTimer;
  void cancelDimTimer() {
    _dimTimer?.cancel();
    _dimTimer = null;
    _canDimMiniplayer.value = false;
  }

  void startDimTimer() {
    cancelDimTimer();
    if (_defaultMiniplayerDimSeconds > 0 && _defaultMiniplayerOpacity > 0) {
      _dimTimer = Timer(Duration(seconds: _defaultMiniplayerDimSeconds), () {
        _canDimMiniplayer.value = true;
      });
    }
  }

  final scrollController = ScrollController();
  bool get shouldShowGlowUnderVideo => _shouldShowGlowUnderVideo.value;
  final _shouldShowGlowUnderVideo = false.obs;

  final homepageFeed = <YoutubeFeed>[].obs;

  final currentYoutubeMetadataVideo = Rxn<VideoInfo>();
  final currentYoutubeMetadataChannel = Rxn<YoutubeChannel>();
  final currentRelatedVideos = <YoutubeFeed?>[].obs;
  final currentComments = <YoutubeComment?>[].obs;
  final commentToParsedHtml = <String, String?>{};
  final currentTotalCommentsCount = Rxn<int>();
  final isLoadingComments = false.obs;
  final isTitleExpanded = false.obs;
  final currentYTQualities = <VideoOnlyStream>[].obs;
  final currentYTAudioStreams = <AudioOnlyStream>[].obs;

  /// Used as a backup in case of no connection.
  final currentCachedQualities = <NamidaVideo>[].obs;

  /// {id: <filename, DownloadProgress>{}}
  final downloadsVideoProgressMap = <String, RxMap<String, DownloadProgress>>{}.obs;

  /// {id: <filename, DownloadProgress>{}}
  final downloadsAudioProgressMap = <String, RxMap<String, DownloadProgress>>{}.obs;

  /// {id: <filename, int>{}}
  final currentSpeedsInByte = <String, RxMap<String, int>>{}.obs;

  /// {id: <filename, bool>{}}
  final isDownloading = <String, RxMap<String, bool>>{}.obs;

  /// {id: <filename, bool>{}}
  final isFetchingData = <String, RxMap<String, bool>>{}.obs;

  /// {groupName: <filename, Dio>{}}
  final _downloadClientsMap = <String, Map<String, Dio>>{};

  /// {groupName: {filename: YoutubeItemDownloadConfig}}
  final youtubeDownloadTasksMap = <String, Map<String, YoutubeItemDownloadConfig>>{}.obs;

  /// {groupName: {filename: bool}}
  /// - `true` -> is in queue, will be downloaded when reached.
  /// - `false` -> is paused. will be skipped when reached.
  /// - `null` -> not specified.
  final youtubeDownloadTasksInQueueMap = <String, Map<String, bool?>>{}.obs;

  /// {groupName: dateMS}
  ///
  /// used to sort group names by latest edited.
  final latestEditedGroupDownloadTask = <String, int>{};

  /// Used to keep track of existing downloaded files, more performant than real-time checking.
  ///
  /// {groupName: {filename: File}}
  final downloadedFilesMap = <String, Map<String, File?>>{}.obs;

  /// Temporarely saves StreamInfoItem info for flawless experience while waiting for real info.
  final tempVideoInfosFromStreams = <String, StreamInfoItem>{}; // {id: StreamInfoItem()}

  /// Used for easily displaying title & channel inside history directly without needing to fetch or rely on cache.
  /// This comes mainly after a youtube history import
  var tempBackupVideoInfo = <String, YoutubeVideoHistory>{}; // {id: YoutubeVideoHistory()}

  late var tempVideoInfo = <String, VideoInfo?>{};
  late var tempChannelInfo = <String, YoutubeChannel?>{};

  Future<void> loadInfoToMemory() async {
    final res = await _loadInfoToMemoryIsolate.thready((AppDirs.YT_METADATA, AppDirs.YT_METADATA_CHANNELS));
    if (res.$1.isNotEmpty) tempVideoInfo = res.$1;
    if (res.$2.isNotEmpty) tempChannelInfo = res.$2;
  }

  static Future<(Map<String, VideoInfo?>, Map<String, YoutubeChannel?>)> _loadInfoToMemoryIsolate((String pv, String pc) paths) async {
    final mv = <String, VideoInfo?>{};
    final mc = <String, YoutubeChannel?>{};

    final completer1 = Completer<void>();
    final completer2 = Completer<void>();

    Directory(paths.$1).listAllIsolate().then((value) {
      value.loop((e, index) {
        if (e is File) {
          try {
            final map = e.readAsJsonSync();
            mv[e.path.getFilenameWOExt] = VideoInfo.fromMap(map);
          } catch (_) {}
        }
      });
      completer1.complete();
    });
    Directory(paths.$2).listAllIsolate().then((value) {
      value.loop((e, index) {
        if (e is File) {
          try {
            final map = e.readAsJsonSync();
            mc[e.path.getFilenameWOExt] = YoutubeChannel.fromMap(map);
          } catch (_) {}
        }
      });
      completer2.complete();
    });
    await completer1.future;
    await completer2.future;
    return (mv, mc);
  }

  /// [renameCacheFiles] requires you to stop the download first, otherwise it might result in corrupted files.
  Future<void> renameConfigFilename({
    required YoutubeItemDownloadConfig config,
    required String videoID,
    required String newFilename,
    required String groupName,
    required bool renameCacheFiles,
  }) async {
    final oldFilename = config.filename;

    config.filename = newFilename;

    downloadsVideoProgressMap[videoID]?.reAssign(oldFilename, newFilename);
    downloadsAudioProgressMap[videoID]?.reAssign(oldFilename, newFilename);
    currentSpeedsInByte[videoID]?.reAssign(oldFilename, newFilename);
    isDownloading[videoID]?.reAssign(oldFilename, newFilename);
    isFetchingData[videoID]?.reAssign(oldFilename, newFilename);

    downloadsVideoProgressMap.refresh();
    downloadsAudioProgressMap.refresh();
    currentSpeedsInByte.refresh();
    isDownloading.refresh();
    isFetchingData.refresh();

    // =============

    _downloadClientsMap[groupName]?.reAssign(oldFilename, newFilename);
    youtubeDownloadTasksMap[groupName]?.reAssign(oldFilename, newFilename);
    youtubeDownloadTasksInQueueMap[groupName]?.reAssignNullable(oldFilename, newFilename);
    downloadedFilesMap[groupName]?.reAssignNullable(oldFilename, newFilename);

    youtubeDownloadTasksMap.refresh();
    youtubeDownloadTasksInQueueMap.refresh();
    downloadedFilesMap.refresh();

    final directory = Directory("${AppDirs.YOUTUBE_DOWNLOADS}$groupName");
    final existingFile = File("${directory.path}/${config.filename}");
    if (existingFile.existsSync()) {
      try {
        existingFile.renameSync("${directory.path}/$newFilename");
      } catch (_) {}
    }
    if (renameCacheFiles) {
      final aFile = File(_getTempAudioPath(groupName: groupName, fullFilename: oldFilename));
      final vFile = File(_getTempVideoPath(groupName: groupName, fullFilename: oldFilename));

      if (aFile.existsSync()) {
        final newPath = _getTempAudioPath(groupName: groupName, fullFilename: newFilename);
        aFile.renameSync(newPath);
      }
      if (vFile.existsSync()) {
        final newPath = _getTempVideoPath(groupName: groupName, fullFilename: newFilename);
        vFile.renameSync(newPath);
      }
    }

    YTOnGoingFinishedDownloads.inst.refreshList();

    await _writeTaskGroupToStorage(groupName: groupName);
  }

  YoutubeVideoHistory? _getBackupVideoInfo(String id) => tempBackupVideoInfo[id];

  Future<void> fillBackupInfoMap() async {
    final map = await _fillBackupInfoMapIsolate.thready(AppDirs.YT_STATS);
    tempBackupVideoInfo = map;
    tempBackupVideoInfo.remove('');
  }

  static Map<String, YoutubeVideoHistory> _fillBackupInfoMapIsolate(String dirPath) {
    final map = <String, YoutubeVideoHistory>{};
    for (final f in Directory(dirPath).listSyncSafe()) {
      if (f is File) {
        try {
          final response = f.readAsJsonSync();
          if (response != null) {
            for (final r in response as List) {
              final yvh = YoutubeVideoHistory.fromJson(r);
              map[yvh.id] = yvh;
            }
          }
        } catch (e) {
          continue;
        }
      }
    }
    return map;
  }

  String getYoutubeLink(String id) => id.toYTUrl();

  VideoInfo? getVideoInfo(String id, {bool checkFromStorage = false}) {
    final info = _getTemporarelyVideoInfo(id, checkFromStorage: checkFromStorage) ?? _fetchVideoDetailsFromCacheSync(id, checkFromStorage: checkFromStorage);
    if (info != null) return info;
    final bk = _getBackupVideoInfo(id);
    if (bk != null) return VideoInfo(id: id, name: bk.title, uploaderName: bk.channel, uploaderUrl: bk.channelUrl);
    return null;
  }

  String? getVideoName(String id, {bool checkFromStorage = false}) {
    return getTemporarelyStreamInfo(id)?.name ??
        _getBackupVideoInfo(id)?.title ?? //
        _fetchVideoDetailsFromCacheSync(id, checkFromStorage: checkFromStorage)?.name;
  }

  String? getVideoChannelName(String id, {bool checkFromStorage = false}) {
    return getTemporarelyStreamInfo(id)?.uploaderName ??
        _getBackupVideoInfo(id)?.channel ?? //
        _fetchVideoDetailsFromCacheSync(id, checkFromStorage: checkFromStorage)?.uploaderName;
  }

  DateTime? getVideoReleaseDate(String id, {bool checkFromStorage = false}) {
    return getTemporarelyStreamInfo(id)?.date ?? //
        _fetchVideoDetailsFromCacheSync(id, checkFromStorage: checkFromStorage)?.date;
  }

  VideoInfo? _getTemporarelyVideoInfo(String id, {bool checkFromStorage = false}) {
    final r = getTemporarelyStreamInfo(id, checkFromStorage: checkFromStorage);
    return r == null ? null : VideoInfo.fromStreamInfoItem(r);
  }

  StreamInfoItem? getTemporarelyStreamInfo(String id, {bool checkFromStorage = false}) {
    final si = tempVideoInfosFromStreams[id];
    if (si != null) return si;
    if (checkFromStorage) {
      final file = File('${AppDirs.YT_METADATA_TEMP}$id.txt');
      final res = file.readAsJsonSync();
      if (res != null) {
        try {
          final strInfo = StreamInfoItem.fromMap(res);
          return strInfo;
        } catch (_) {}
      }
    }
    return null;
  }

  /// Keeps the map at max 2000 items. maintained by least recently used.
  void _fillTempVideoInfoMap(Iterable<StreamInfoItem>? items) async {
    if (items != null) {
      final map = tempVideoInfosFromStreams;

      final entriesForStorage = <MapEntry<String, Map<String, String?>>>[];
      for (final e in items) {
        final id = e.id;
        if (id != null) {
          // -- adding to storage (later)
          // -- we only add if it didnt exist in map before, to minimize writes
          if (map[id] == null) entriesForStorage.add(MapEntry(id, e.toMap()));

          // -- adding to memory (directly)
          map.remove(id);
          map[id] = e;
        }
      }
      // -- clearing excess from map to keep it at 2000
      final excess = map.length - 2000;
      if (excess > 0) {
        final excessKeys = map.keys.take(excess).toList();
        excessKeys.loop((k, _) => map.remove(k));
      }

      await _saveTemporarelyVideoInfoIsolate.thready({
        'dirPath': AppDirs.YT_METADATA_TEMP,
        'entries': entriesForStorage,
      });
    }
  }

  static void _saveTemporarelyVideoInfoIsolate(Map p) {
    final dirPath = p['dirPath'] as String;
    final entries = p['entries'] as List<MapEntry<String, Map<String, String?>>>;

    entries.loop((e, index) {
      final file = File('$dirPath${e.key}.txt');
      file.writeAsJsonSync(e.value);
    });
  }

  /// Checks if the requested id is still playing, since most functions are async and will often
  /// take time to fetch from internet, and user may have played other vids, this covers such cases.
  bool _canSafelyModifyMetadata(String id) => Player.inst.nowPlayingVideoID?.id == id;

  Future<void> prepareHomeFeed() async {
    homepageFeed.clear();
    final videos = await NewPipeExtractorDart.trending.getTrendingVideos();
    _fillTempVideoInfoMap(videos);
    homepageFeed.addAll([
      ...videos,
    ]);
  }

  Future<List> searchForItems(String text) async {
    final videos = await NewPipeExtractorDart.search.searchYoutube(text, []);
    _fillTempVideoInfoMap(videos.searchVideos);
    return videos.dynamicSearchResultsList;
  }

  Future<List> searchNextPage() async {
    final parsedList = await NewPipeExtractorDart.search.getNextPage();
    final v = YoutubeSearch(
      query: '',
      searchVideos: parsedList[0],
      searchPlaylists: parsedList[1],
      searchChannels: parsedList[2],
    );
    _fillTempVideoInfoMap(v.searchVideos);
    return v.dynamicSearchResultsList;
  }

  Future<void> fetchRelatedVideos(String id) async {
    currentRelatedVideos.value = List.filled(20, null, growable: true);
    final items = await NewPipeExtractorDart.videos.getRelatedStreams(id.toYTUrl());
    _fillTempVideoInfoMap(items.whereType<StreamInfoItem>());
    items.loop((p, index) {
      if (p is YoutubePlaylist) {
        YoutubeController.inst.getPlaylistStreams(p, forceInitial: true);
      }
    });
    if (_canSafelyModifyMetadata(id)) {
      currentRelatedVideos.value = [
        ...items,
      ];
    }
  }

  /// For full list of items, use [streams] getter in [playlist].
  Future<List<StreamInfoItem>> getPlaylistStreams(YoutubePlaylist? playlist, {bool forceInitial = false}) async {
    if (playlist == null) return [];
    final streams = forceInitial ? await playlist.getStreams() : await playlist.getStreamsNextPage();
    _fillTempVideoInfoMap(streams);
    return streams;
  }

  Future<YoutubePlaylist?> getPlaylistInfo(String playlistUrl, {bool forceInitial = false}) async {
    return await NewPipeExtractorDart.playlists.getPlaylistDetails(playlistUrl);
  }

  Future<List<StreamInfoItem>> getChannelStreams(String channelID) async {
    if (channelID == '') return [];
    final url = 'https://www.youtube.com/channel/$channelID';
    final streams = await NewPipeExtractorDart.channels.getChannelUploads(url);
    _fillTempVideoInfoMap(streams);
    return streams;
  }

  Future<List<StreamInfoItem>> getChannelStreamsNextPage() async {
    final streams = await NewPipeExtractorDart.channels.getChannelNextUploads();
    _fillTempVideoInfoMap(streams);
    return streams;
  }

  Future<void> _fetchComments(String id, {bool forceRequest = false}) async {
    currentTotalCommentsCount.value = null;
    currentComments
      ..clear()
      ..addAll(List.filled(20, null));

    // -- Fetching Comments.
    final fetchedComments = <YoutubeComment>[];
    final cachedFile = File("${AppDirs.YT_METADATA_COMMENTS}$id.txt");

    // fetching cache
    final userForceNewRequest = ConnectivityController.inst.hasConnection && settings.ytPreferNewComments.value;
    if (!forceRequest && !userForceNewRequest && await cachedFile.exists()) {
      final res = await cachedFile.readAsJson();
      final commList = (res as List?)?.map((e) => YoutubeComment.fromMap(e));
      if (commList != null && commList.isNotEmpty) {
        fetchedComments.addAll(commList);
      }
      _isCurrentCommentsFromCache = true;
    }
    // fetching from yt, in case no comments were added, i.e: no cache.
    if (fetchedComments.isEmpty) {
      final comments = await NewPipeExtractorDart.comments.getComments(id.toYTUrl());
      fetchedComments.addAll(comments);
      _isCurrentCommentsFromCache = false;

      if (comments.isNotEmpty) _saveCommentsToStorage(cachedFile, comments);
    }
    // -- Fetching Comments End.
    if (_canSafelyModifyMetadata(id)) {
      currentComments.clear();
      _fillCommentsLists(fetchedComments);
      currentTotalCommentsCount.value = fetchedComments.firstOrNull?.totalCommentsCount;
    }
  }

  void _fillCommentsLists(List<YoutubeComment?> comments) {
    for (final c in comments) {
      final cid = c?.commentId;
      final ctxt = c?.commentText;
      if (cid != null && ctxt != null) {
        commentToParsedHtml[cid] = HtmlParser.parseHTML(ctxt.replaceAll('<br>', '\n')).text;
      }
    }

    currentComments.addAll(comments);
  }

  Future<void> _fetchNextComments(String id) async {
    if (_isCurrentCommentsFromCache) return;
    final comments = await NewPipeExtractorDart.comments.getNextComments();
    if (_canSafelyModifyMetadata(id)) {
      _fillCommentsLists(comments);

      // -- saving to cache
      final cachedFile = File("${AppDirs.YT_METADATA_COMMENTS}$id.txt");
      _saveCommentsToStorage(cachedFile, currentComments);
    }
  }

  Future<void> _saveCommentsToStorage(File file, Iterable<YoutubeComment?> commListy) async {
    await file.writeAsJson(commListy.map((e) => e?.toMap()).toList());
  }

  /// Used to keep track of current comments sources, mainly to
  /// prevent fetching next comments when cached version is loaded.
  bool get isCurrentCommentsFromCache => _isCurrentCommentsFromCache;
  bool _isCurrentCommentsFromCache = false;

  Future<void> updateCurrentComments(String id, {bool fetchNextOnly = false, bool forceRequest = false}) async {
    isLoadingComments.value = true;
    if (currentComments.isNotEmpty && fetchNextOnly && !forceRequest) {
      await _fetchNextComments(id);
    } else {
      await _fetchComments(id, forceRequest: forceRequest);
    }
    isLoadingComments.value = false;
  }

  VideoStream getPreferredStreamQuality(List<VideoStream> streams, {List<String> qualities = const [], bool preferIncludeWebm = false}) {
    final preferredQualities = (qualities.isNotEmpty ? qualities : settings.youtubeVideoQualities).map((element) => element.settingLabeltoVideoLabel());
    VideoStream? plsLoop(bool webm) {
      for (int i = 0; i < streams.length; i++) {
        final q = streams[i];
        final webmCondition = webm ? true : q.formatSuffix != 'webm';
        if (webmCondition && preferredQualities.contains(q.resolution?.split('p').first)) {
          return q;
        }
      }
      return null;
    }

    if (preferIncludeWebm) {
      return plsLoop(true) ?? streams.last;
    } else {
      return plsLoop(false) ?? plsLoop(true) ?? streams.last;
    }
  }

  Future<void> updateVideoDetails(String id, {bool forceRequest = false}) async {
    if (scrollController.hasClients) {
      scrollController.jumpTo(0);
      resetGlowUnderVideo();
    }
    startDimTimer();
    isTitleExpanded.value = false;

    updateCurrentVideoMetadata(id, forceRequest: forceRequest);
    updateCurrentComments(id);
    fetchRelatedVideos(id);
  }

  Future<void> updateCurrentVideoMetadata(String id, {bool forceRequest = false}) async {
    currentYoutubeMetadataVideo.value = null;
    currentYoutubeMetadataChannel.value = null;

    void updateForCurrentID(void Function() fn) {
      if (_canSafelyModifyMetadata(id)) {
        fn();
      }
    }

    final channelUrl = tempVideoInfosFromStreams[id]?.uploaderUrl;

    if (channelUrl != null) {
      await Future.wait([
        fetchVideoDetails(id).then((info) {
          updateForCurrentID(() {
            currentYoutubeMetadataVideo.value = info;
          });
        }),
        fetchChannelDetails(channelUrl).then((channel) {
          updateForCurrentID(() {
            currentYoutubeMetadataChannel.value = channel;
          });
        }),
      ]);
    } else {
      final info = await fetchVideoDetails(id, forceRequest: forceRequest);
      final channel = await fetchChannelDetails(info?.uploaderUrl, forceRequest: forceRequest);
      updateForCurrentID(() {
        currentYoutubeMetadataVideo.value = info;
        currentYoutubeMetadataChannel.value = channel;
      });
    }
  }

  Future<VideoInfo?> fetchVideoDetails(String id, {bool forceRequest = false}) async {
    final cachedFile = File("${AppDirs.YT_METADATA}$id.txt");
    VideoInfo? vi;
    if (forceRequest == false && await cachedFile.exists()) {
      final res = await cachedFile.readAsJson();
      vi = VideoInfo.fromMap(res);
    } else {
      final info = await NewPipeExtractorDart.videos.getInfo(id.toYTUrl());
      vi = info;
      _cacheVideoInfo(id, info);
    }
    return vi;
  }

  Future<void> _cacheVideoInfo(String id, VideoInfo? info) async {
    if (info != null) {
      tempVideoInfo[id] = info;
      await File("${AppDirs.YT_METADATA}$id.txt").writeAsJson(info.toMap());
    }
  }

  /// fetches cache version only.
  VideoInfo? _fetchVideoDetailsFromCacheSync(String id, {bool checkFromStorage = false}) {
    if (tempVideoInfo[id] != null) return tempVideoInfo[id]!;
    if (checkFromStorage) {
      final cachedFile = File("${AppDirs.YT_METADATA}$id.txt");
      if (cachedFile.existsSync()) {
        final res = cachedFile.readAsJsonSync();
        if (res != null) {
          try {
            return VideoInfo.fromMap(res);
          } catch (_) {}
        }
      }
    }
    return null;
  }

  YoutubeChannel? fetchChannelDetailsFromCacheSync(String? channelUrl, {bool checkFromStorage = false}) {
    final channelId = channelUrl?.split('/').last;
    if (tempChannelInfo[channelId] != null) return tempChannelInfo[channelId]!;
    if (checkFromStorage) {
      final cachedFile = File("${AppDirs.YT_METADATA_CHANNELS}$channelId.txt");
      if (cachedFile.existsSync()) {
        try {
          final res = cachedFile.readAsJsonSync();
          return YoutubeChannel.fromMap(res);
        } catch (_) {}
      }
    }
    return null;
  }

  Future<YoutubeChannel?> fetchChannelDetails(String? channelUrl, {bool forceRequest = false}) async {
    final channelId = channelUrl?.split('/').last;
    if (channelId == null) return null;
    final cachedFile = File("${AppDirs.YT_METADATA_CHANNELS}$channelId.txt");
    YoutubeChannel? vi;
    if (!forceRequest && await cachedFile.exists()) {
      final res = await cachedFile.readAsJson();
      vi = YoutubeChannel.fromMap(res);
    } else {
      try {
        final info = await NewPipeExtractorDart.channels.channelInfo(channelUrl);
        vi = info;
        tempChannelInfo[channelId] = info; // saves in memory
        cachedFile.writeAsJson(info.toMap());
      } catch (e) {
        printy(e, isError: true);
      }
    }
    return vi;
  }

  Future<List<VideoOnlyStream>> getAvailableVideoStreamsOnly(String id) async {
    final videos = await NewPipeExtractorDart.videos.getVideoOnlyStreams(id.toYTUrl());
    _sortVideoStreams(videos);
    return videos;
  }

  Future<List<AudioOnlyStream>> getAvailableAudioOnlyStreams(String id) async {
    final audios = await NewPipeExtractorDart.videos.getAudioOnlyStreams(id.toYTUrl());
    _sortAudioStreams(audios);
    return audios;
  }

  Future<YoutubeVideo> getAvailableStreams(String id) async {
    final url = id.toYTUrl();
    final video = await NewPipeExtractorDart.videos.getStream(url);
    _cacheVideoInfo(id, video.videoInfo);

    _sortVideoStreams(video.videoOnlyStreams);
    _sortVideoStreams(video.videoStreams);
    _sortAudioStreams(video.audioOnlyStreams);

    return video;
  }

  void _sortVideoStreams(List<VideoStream>? streams) {
    streams?.sortByReverseAlt(
      (e) => e.width ?? (int.tryParse(e.resolution?.split('p').firstOrNull ?? '') ?? 0),
      (e) => e.fps ?? 0,
    );
  }

  void _sortAudioStreams(List<AudioOnlyStream>? streams) {
    streams?.sortByReverseAlt(
      (e) => e.bitrate ?? 0,
      (e) => e.sizeInBytes ?? 0,
    );
  }

  void _loopMapAndPostNotification({
    required Map<String, Map<String, DownloadProgress>> bigMap,
    required int Function(String key, int progress) speedInBytes,
    required DateTime startTime,
    required bool isAudio,
  }) {
    final downloadingText = isAudio ? "Audio" : "Video";
    for (final bigEntry in bigMap.entries.toList()) {
      final map = bigEntry.value;
      final videoId = bigEntry.key;
      for (final entry in map.entries.toList()) {
        final p = entry.value.progress;
        final tp = entry.value.totalProgress;
        final title = getVideoName(videoId) ?? videoId;
        final speedB = speedInBytes(videoId, entry.value.progress);
        currentSpeedsInByte[videoId] ??= <String, int>{}.obs;
        currentSpeedsInByte[videoId]![entry.key] = speedB;
        if (p / tp >= 1) {
          map.remove(entry.key);
        } else {
          NotificationService.inst.downloadYoutubeNotification(
            notificationID: entry.key,
            title: "Downloading $downloadingText: $title",
            progress: p,
            total: tp,
            subtitle: (progressText) => "$progressText (${speedB.fileSizeFormatted}/s)",
            imagePath: ThumbnailManager.inst.getYoutubeThumbnailFromCacheSync(id: videoId)?.path,
            displayTime: startTime,
          );
        }
      }
    }
  }

  void _doneDownloadingNotification({
    required String videoId,
    required String videoTitle,
    required String nameIdentifier,
    required File? downloadedFile,
    required String filename,
    required bool canceledByUser,
  }) {
    if (downloadedFile == null) {
      if (!canceledByUser) {
        NotificationService.inst.doneDownloadingYoutubeNotification(
          notificationID: nameIdentifier,
          videoTitle: videoTitle,
          subtitle: 'Download Failed',
          imagePath: ThumbnailManager.inst.getYoutubeThumbnailFromCacheSync(id: videoId)?.path,
          failed: true,
        );
      }
    } else {
      final size = downloadedFile.fileSizeFormatted();
      NotificationService.inst.doneDownloadingYoutubeNotification(
        notificationID: nameIdentifier,
        videoTitle: downloadedFile.path.getFilenameWOExt,
        subtitle: size == null ? '' : 'Downloaded: $size',
        imagePath: ThumbnailManager.inst.getYoutubeThumbnailFromCacheSync(id: videoId)?.path,
        failed: false,
      );
    }
    _tryCancelDownloadNotificationTimer();

    // this removes progress when pausing.
    // downloadsVideoProgressMap[videoId]?.remove(filename);
    // downloadsAudioProgressMap[videoId]?.remove(filename);
  }

  final _speedMapVideo = <String, int>{};
  final _speedMapAudio = <String, int>{};

  Timer? _downloadNotificationTimer;
  void _tryCancelDownloadNotificationTimer() {
    if (downloadsVideoProgressMap.isEmpty && downloadsAudioProgressMap.isEmpty) {
      _downloadNotificationTimer?.cancel();
      _downloadNotificationTimer = null;
    }
  }

  void _startNotificationTimer() {
    if (_downloadNotificationTimer == null) {
      final startTime = DateTime.now();
      _downloadNotificationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _loopMapAndPostNotification(
          startTime: startTime,
          isAudio: false,
          bigMap: downloadsVideoProgressMap,
          speedInBytes: (key, newProgress) {
            final previousProgress = _speedMapVideo[key] ?? 0;
            final speed = newProgress - previousProgress;
            _speedMapVideo[key] = newProgress;
            return speed;
          },
        );
        _loopMapAndPostNotification(
          startTime: startTime,
          isAudio: true,
          bigMap: downloadsAudioProgressMap,
          speedInBytes: (key, newProgress) {
            final previousProgress = _speedMapAudio[key] ?? 0;
            final speed = newProgress - previousProgress;
            _speedMapAudio[key] = newProgress;
            return speed;
          },
        );
      });
    }
  }

  Future<int?> _getContentSize(String url) async => await NewPipeExtractorDart.httpClient.getContentLength(url);

  String cleanupFilename(String filename) => filename.replaceAll(RegExp(r'[#\$|/\\!^:"]', caseSensitive: false), '_');

  Future<void> loadDownloadTasksInfoFile() async {
    await for (final f in Directory(AppDirs.YT_DOWNLOAD_TASKS).list()) {
      if (f is File) {
        final groupName = f.path.getFilename.split('.').first;
        final res = await f.readAsJson() as Map<String, dynamic>?;
        if (res != null) {
          final fileModified = f.statSync().modified;
          youtubeDownloadTasksMap[groupName] ??= {};
          downloadedFilesMap[groupName] ??= {};
          if (fileModified != DateTime(1970)) {
            latestEditedGroupDownloadTask[groupName] ??= fileModified.millisecondsSinceEpoch;
          }
          for (final v in res.entries) {
            final ytitem = YoutubeItemDownloadConfig.fromJson(v.value as Map<String, dynamic>);
            final saveDirPath = "${AppDirs.YOUTUBE_DOWNLOADS}$groupName";
            final file = File("$saveDirPath/${ytitem.filename}");
            final fileExists = file.existsSync();
            youtubeDownloadTasksMap[groupName]![v.key] = ytitem;
            downloadedFilesMap[groupName]![v.key] = fileExists ? file : null;
            if (!fileExists) {
              final aFile = File("$saveDirPath/.tempa_${ytitem.filename}");
              final vFile = File("$saveDirPath/.tempv_${ytitem.filename}");
              if (aFile.existsSync()) {
                downloadsAudioProgressMap[ytitem.id] ??= <String, DownloadProgress>{}.obs;
                downloadsAudioProgressMap[ytitem.id]![ytitem.filename] = DownloadProgress(
                  progress: aFile.fileSizeSync() ?? 0,
                  totalProgress: 0,
                );
              }
              if (vFile.existsSync()) {
                downloadsVideoProgressMap[ytitem.id] ??= <String, DownloadProgress>{}.obs;
                downloadsVideoProgressMap[ytitem.id]![ytitem.filename] = DownloadProgress(
                  progress: vFile.fileSizeSync() ?? 0,
                  totalProgress: 0,
                );
              }
            }
          }
        }
      }
    }
    youtubeDownloadTasksMap.refresh();
    downloadedFilesMap.refresh();
  }

  File? doesIDHasFileDownloaded(String id) {
    for (final e in youtubeDownloadTasksMap.entries) {
      for (final config in e.value.values) {
        final groupName = e.key;
        if (config.id == id) {
          final file = downloadedFilesMap[groupName]?[config.filename];
          if (file != null) {
            return file;
          }
        }
      }
    }
    return null;
  }

  void _matchIDsForItemConfig({
    required List<String> videosIds,
    required void Function(String groupName, YoutubeItemDownloadConfig config) onMatch,
  }) {
    for (final e in youtubeDownloadTasksMap.entries) {
      for (final config in e.value.values) {
        final groupName = e.key;
        videosIds.loop((e, index) {
          if (e == config.id) {
            onMatch(groupName, config);
          }
        });
      }
    }
  }

  void resumeDownloadTaskForIDs({
    required String groupName,
    List<String> videosIds = const [],
  }) {
    _matchIDsForItemConfig(
      videosIds: videosIds,
      onMatch: (groupName, config) {
        downloadYoutubeVideos(
          useCachedVersionsIfAvailable: true,
          autoExtractTitleAndArtist: settings.ytAutoExtractVideoTagsFromInfo.value,
          keepCachedVersionsIfDownloaded: settings.downloadFilesKeepCachedVersions.value,
          downloadFilesWriteUploadDate: settings.downloadFilesWriteUploadDate.value,
          itemsConfig: [config],
          groupName: groupName,
        );
      },
    );
  }

  Future<void> resumeDownloadTasks({
    required String groupName,
    List<YoutubeItemDownloadConfig> itemsConfig = const [],
    bool skipExistingFiles = true,
  }) async {
    final finalItems = itemsConfig.isNotEmpty ? itemsConfig : youtubeDownloadTasksMap[groupName]?.values.toList() ?? [];
    if (skipExistingFiles) {
      finalItems.removeWhere((element) => YoutubeController.inst.downloadedFilesMap[groupName]?[element.filename] != null);
    }
    if (finalItems.isNotEmpty) {
      await downloadYoutubeVideos(
        useCachedVersionsIfAvailable: true,
        autoExtractTitleAndArtist: settings.ytAutoExtractVideoTagsFromInfo.value,
        keepCachedVersionsIfDownloaded: settings.downloadFilesKeepCachedVersions.value,
        downloadFilesWriteUploadDate: settings.downloadFilesWriteUploadDate.value,
        itemsConfig: finalItems,
        groupName: groupName,
      );
    }
  }

  void pauseDownloadTask({
    required List<YoutubeItemDownloadConfig> itemsConfig,
    required String groupName,
    List<String> videosIds = const [],
    bool allInGroupName = false,
  }) {
    youtubeDownloadTasksInQueueMap[groupName] ??= {};
    void onMatch(String groupName, YoutubeItemDownloadConfig config) {
      youtubeDownloadTasksInQueueMap[groupName]![config.filename] = false;
      _downloadClientsMap[groupName]?[config.filename]?.close(force: true);
      _downloadClientsMap[groupName]?.remove(config.filename);
      _breakRetrievingInfoRequest(config);
    }

    if (allInGroupName) {
      final groupClients = _downloadClientsMap[groupName];
      if (groupClients != null) {
        for (final e in groupClients.values) {
          e.close(force: true);
        }
        _downloadClientsMap.remove(groupName);
      }
      final groupConfigs = youtubeDownloadTasksMap[groupName];
      if (groupConfigs != null) {
        for (final c in groupConfigs.values) {
          onMatch(groupName, c);
        }
      }
    } else if (videosIds.isNotEmpty) {
      _matchIDsForItemConfig(
        videosIds: videosIds,
        onMatch: onMatch,
      );
    } else {
      itemsConfig.loop((c, _) => onMatch(groupName, c));
    }
    youtubeDownloadTasksInQueueMap.refresh();
  }

  void _breakRetrievingInfoRequest(YoutubeItemDownloadConfig c) {
    final err = Exception('Download was canceled by the user');
    _completersVAI[c]?.$1.completeErrorIfWasnt(err);
    _completersVAI[c]?.$2.completeErrorIfWasnt(err);
    _completersVAI[c]?.$3.completeErrorIfWasnt(err);
  }

  Future<void> cancelDownloadTask({
    required List<YoutubeItemDownloadConfig> itemsConfig,
    required String groupName,
    bool allInGroupName = false,
  }) async {
    await _updateDownloadTask(
      itemsConfig: itemsConfig,
      groupName: groupName,
      remove: true,
      allInGroupName: allInGroupName,
    );
  }

  Future<void> _updateDownloadTask({
    required List<YoutubeItemDownloadConfig> itemsConfig,
    required String groupName,
    bool remove = false,
    bool allInGroupName = false,
  }) async {
    youtubeDownloadTasksMap[groupName] ??= {};
    youtubeDownloadTasksInQueueMap[groupName] ??= {};
    if (remove) {
      final directory = Directory("${AppDirs.YOUTUBE_DOWNLOADS}$groupName");
      final itemsToCancel = allInGroupName ? youtubeDownloadTasksMap[groupName]!.values.toList() : itemsConfig;
      await itemsToCancel.loopFuture((c, _) async {
        _downloadClientsMap[groupName]?[c.filename]?.close(force: true);
        _downloadClientsMap[groupName]?.remove(c.filename);
        youtubeDownloadTasksMap[groupName]?.remove(c.filename);
        youtubeDownloadTasksInQueueMap[groupName]?.remove(c.filename);
        _breakRetrievingInfoRequest(c);
        YTOnGoingFinishedDownloads.inst.youtubeDownloadTasksTempList.remove((groupName, c));
        await File("$directory/${c.filename}").deleteIfExists();
        downloadedFilesMap[groupName]?[c.filename] = null;
      });

      // -- remove groups if emptied.
      if (youtubeDownloadTasksMap[groupName]?.isEmpty == true) {
        youtubeDownloadTasksMap.remove(groupName);
      }
    } else {
      itemsConfig.loop((c, _) {
        youtubeDownloadTasksMap[groupName]![c.filename] = c;
        youtubeDownloadTasksInQueueMap[groupName]![c.filename] = true;
      });
    }

    youtubeDownloadTasksMap.refresh();
    downloadedFilesMap.refresh();

    latestEditedGroupDownloadTask[groupName] = DateTime.now().millisecondsSinceEpoch;

    await _writeTaskGroupToStorage(groupName: groupName);
  }

  Future<void> _writeTaskGroupToStorage({required String groupName}) async {
    final mapToWrite = youtubeDownloadTasksMap[groupName];
    final file = File("${AppDirs.YT_DOWNLOAD_TASKS}$groupName.json");
    if (mapToWrite?.isNotEmpty == true) {
      await file.writeAsJson(mapToWrite);
    } else {
      await file.tryDeleting();
    }
  }

  final _completersVAI = <YoutubeItemDownloadConfig, (Completer<void>, Completer<void>, Completer<void>)>{};

  Future<void> downloadYoutubeVideos({
    required List<YoutubeItemDownloadConfig> itemsConfig,
    String groupName = '',
    int parallelDownloads = 1,
    required bool useCachedVersionsIfAvailable,
    required bool downloadFilesWriteUploadDate,
    required bool keepCachedVersionsIfDownloaded,
    required bool autoExtractTitleAndArtist,
    bool deleteOldFile = true,
    bool addAudioToLocalLibrary = true,
    bool audioOnly = false,
    List<String> preferredQualities = const [],
    Future<void> Function(File? downloadedFile)? onOldFileDeleted,
    Future<void> Function(File? deletedFile)? onFileDownloaded,
    Directory? saveDirectory,
  }) async {
    _updateDownloadTask(groupName: groupName, itemsConfig: itemsConfig);
    YoutubeParallelDownloadsHandler.inst.setMaxParalellDownloads(parallelDownloads);

    Future<void> downloady(YoutubeItemDownloadConfig config) async {
      final videoID = config.id;

      _completersVAI[config] = (Completer<void>(), Completer<void>(), Completer<void>());

      final completerV = _completersVAI[config]!.$1;
      final completerA = _completersVAI[config]!.$2;
      final completerI = _completersVAI[config]!.$3;

      isFetchingData[videoID] ??= <String, bool>{}.obs;
      isFetchingData[videoID]![config.filename] = true;

      try {
        final dummyVideoUrl = (config.videoStream?.url == null || config.videoStream?.url == '');
        final dummyAudioUrl = (config.audioStream?.url == null || config.audioStream?.url == '');
        final fetchMissing = config.fetchMissingStreams || (dummyVideoUrl && dummyAudioUrl);
        // -- we are using url cuz we remove it when reading from json
        if (!audioOnly && (fetchMissing || config.prefferedVideoQualityID != null) && dummyVideoUrl) {
          getAvailableVideoStreamsOnly(videoID).then((availableVideos) {
            _sortVideoStreams(availableVideos);
            if (config.prefferedVideoQualityID != null) {
              config.videoStream = availableVideos.firstWhereEff((e) => e.id == config.prefferedVideoQualityID);
            }
            if (config.videoStream == null || config.videoStream?.url == null || config.videoStream?.url == '') {
              config.videoStream = getPreferredStreamQuality(availableVideos, qualities: preferredQualities);
            }
            completerV.completeIfWasnt();
          });
        } else {
          completerV.completeIfWasnt();
        }
        if ((fetchMissing || config.prefferedAudioQualityID != null) && dummyAudioUrl) {
          getAvailableAudioOnlyStreams(videoID).then((audios) {
            _sortAudioStreams(audios);
            if (config.prefferedAudioQualityID != null) {
              config.audioStream = audios.firstWhereEff((e) => e.id == config.prefferedAudioQualityID);
            }
            if (config.audioStream == null || config.audioStream?.url == null || config.audioStream?.url == '') {
              config.audioStream = audios.firstWhereEff((e) => e.formatSuffix != 'webm') ?? audios.firstOrNull;
            }
            completerA.completeIfWasnt();
          });
        } else {
          completerA.completeIfWasnt();
        }

        if (config.ffmpegTags.isEmpty) {
          fetchVideoDetails(videoID).then((info) {
            final meta = YTUtils.getMetadataInitialMap(videoID, info, autoExtract: autoExtractTitleAndArtist);

            config.ffmpegTags.addAll(meta);
            config.fileDate = info?.date;
            completerI.completeIfWasnt();
          });
        } else {
          completerI.completeIfWasnt();
        }

        await completerV.future;
        await completerA.future;
        await completerI.future;
      } catch (e) {
        isFetchingData[videoID]?[config.filename] = false;
        return;
      }

      isFetchingData[videoID]?[config.filename] = false;
      _updateDownloadTask(groupName: groupName, itemsConfig: [config]); // to refresh with new data

      final downloadedFile = await _downloadYoutubeVideoRaw(
        groupName: groupName,
        id: videoID,
        config: config,
        useCachedVersionsIfAvailable: useCachedVersionsIfAvailable,
        saveDirectory: saveDirectory,
        filename: config.filename,
        fileExtension: config.videoStream?.formatSuffix ?? config.audioStream?.formatSuffix ?? '',
        videoStream: config.videoStream,
        audioStream: config.audioStream,
        merge: true,
        deleteOldFile: deleteOldFile,
        onOldFileDeleted: onOldFileDeleted,
        keepCachedVersionsIfDownloaded: keepCachedVersionsIfDownloaded,
        videoDownloadingStream: (downloadedBytes) {},
        audioDownloadingStream: (downloadedBytes) {},
        onInitialVideoFileSize: (initialFileSize) {},
        onInitialAudioFileSize: (initialFileSize) {},
        ffmpegTags: config.ffmpegTags,
        onAudioFileReady: (audioFile) async {
          final thumbnailFile = await ThumbnailManager.inst.getYoutubeThumbnailAndCache(
            id: videoID,
            channelUrlOrID: null,
            isImportantInCache: true,
          );
          await YTUtils.writeAudioMetadata(
            videoId: videoID,
            audioFile: audioFile,
            thumbnailFile: thumbnailFile,
            tagsMap: config.ffmpegTags,
          );
        },
        onVideoFileReady: (videoFile) async {
          await NamidaFFMPEG.inst.editMetadata(
            path: videoFile.path,
            tagsMap: config.ffmpegTags,
          );
        },
      );

      if (downloadFilesWriteUploadDate) {
        final d = config.fileDate;
        if (d != null && d != DateTime(0)) {
          try {
            await downloadedFile?.setLastAccessed(d);
            await downloadedFile?.setLastModified(d);
          } catch (_) {}
        }
      }

      // -- adding to library, only if audio downloaded
      if (addAudioToLocalLibrary && config.audioStream != null && config.videoStream == null) {
        downloadedFile?.path.removeTrackThenExtract();
      }

      downloadedFilesMap[groupName]?[config.filename] = downloadedFile;
      downloadedFilesMap.refresh();
      YTOnGoingFinishedDownloads.inst.refreshList();
      await onFileDownloaded?.call(downloadedFile);
    }

    bool checkIfCanSkip(YoutubeItemDownloadConfig config) {
      final isCanceled = youtubeDownloadTasksMap[groupName]?[config.filename] == null;
      final isPaused = youtubeDownloadTasksInQueueMap[groupName]?[config.filename] == false;
      if (isCanceled || isPaused) {
        printy('Download Skipped for "${config.filename}" bcz: canceled? $isCanceled, paused? $isPaused');
        return true;
      }
      return false;
    }

    for (final config in itemsConfig) {
      // if paused, or removed (canceled), we skip it
      if (checkIfCanSkip(config)) continue;

      await YoutubeParallelDownloadsHandler.inst.waitForParallelCompleter;

      // we check again bcz we been waiting...
      if (checkIfCanSkip(config)) continue;

      YoutubeParallelDownloadsHandler.inst.inc();
      await downloady(config).then((value) {
        YoutubeParallelDownloadsHandler.inst.dec();
      });
    }
  }

  String _getTempAudioPath({
    required String groupName,
    required String fullFilename,
    Directory? saveDir,
  }) {
    return _getTempDownloadPath(
      groupName: groupName,
      fullFilename: fullFilename,
      prefix: '.tempa_',
      saveDir: saveDir,
    );
  }

  String _getTempVideoPath({
    required String groupName,
    required String fullFilename,
    Directory? saveDir,
  }) {
    return _getTempDownloadPath(
      groupName: groupName,
      fullFilename: fullFilename,
      prefix: '.tempv_',
      saveDir: saveDir,
    );
  }

  /// [directoryPath] must NOT end with `/`
  String _getTempDownloadPath({
    required String groupName,
    required String fullFilename,
    required String prefix,
    Directory? saveDir,
  }) {
    final saveDirPath = saveDir?.path ?? "${AppDirs.YOUTUBE_DOWNLOADS}$groupName";
    return "$saveDirPath/$prefix$fullFilename";
  }

  Future<File?> _downloadYoutubeVideoRaw({
    required String id,
    required String groupName,
    required YoutubeItemDownloadConfig config,
    required bool useCachedVersionsIfAvailable,
    required Directory? saveDirectory,
    required String filename,
    required String fileExtension,
    required VideoStream? videoStream,
    required AudioOnlyStream? audioStream,
    required Map<String, String?> ffmpegTags,
    required bool merge,
    required bool keepCachedVersionsIfDownloaded,
    required bool deleteOldFile,
    required void Function(List<int> downloadedBytes) videoDownloadingStream,
    required void Function(List<int> downloadedBytes) audioDownloadingStream,
    required void Function(int initialFileSize) onInitialVideoFileSize,
    required void Function(int initialFileSize) onInitialAudioFileSize,
    required Future<void> Function(File videoFile) onVideoFileReady,
    required Future<void> Function(File audioFile) onAudioFileReady,
    required Future<void> Function(File? deletedFile)? onOldFileDeleted,
  }) async {
    if (id == '') return null;

    if (filename.split('.').last != fileExtension) filename = "$filename.$fileExtension";

    final filenameClean = cleanupFilename(filename);
    renameConfigFilename(
      videoID: id,
      groupName: groupName,
      config: config,
      newFilename: filenameClean,
      renameCacheFiles: false, // no worries we still gonna do the job.
    );

    isDownloading[id] ??= <String, bool>{}.obs;
    isDownloading[id]![filenameClean] = true;

    _startNotificationTimer();

    saveDirectory ??= Directory("${AppDirs.YOUTUBE_DOWNLOADS}$groupName");
    await saveDirectory.create(recursive: true);

    if (deleteOldFile) {
      final file = File("${saveDirectory.path}/$filenameClean");
      try {
        if (await file.exists()) {
          await file.delete();
          onOldFileDeleted?.call(file);
        }
      } catch (_) {}
    }

    File? df;
    Future<bool> fileSizeQualified({
      required File file,
      required int targetSize,
      int allowanceBytes = 1024,
    }) async {
      final fileStats = await file.stat();
      final ok = fileStats.size >= targetSize - allowanceBytes; // it can be bigger cuz metadata and artwork may be added later
      return ok;
    }

    File? videoFile;
    File? audioFile;

    bool isVideoFileCached = false;
    bool isAudioFileCached = false;

    try {
      // --------- Downloading Choosen Video.
      if (videoStream != null) {
        final filecache = videoStream.getCachedFile(id);
        if (useCachedVersionsIfAvailable && filecache != null && await fileSizeQualified(file: filecache, targetSize: videoStream.sizeInBytes ?? 0)) {
          videoFile = filecache;
          isVideoFileCached = true;
        } else {
          if (videoStream.sizeInBytes == null || videoStream.sizeInBytes == 0) {
            videoStream.sizeInBytes = await _getContentSize(videoStream.url ?? '');
          }

          int bytesLength = 0;

          downloadsVideoProgressMap[id] ??= <String, DownloadProgress>{}.obs;
          final downloadedFile = await _checkFileAndDownload(
            groupName: groupName,
            url: videoStream.url ?? '',
            targetSize: videoStream.sizeInBytes ?? 0,
            filename: filenameClean,
            destinationFilePath: _getTempVideoPath(
              groupName: groupName,
              fullFilename: filenameClean,
              saveDir: saveDirectory,
            ),
            onInitialFileSize: (initialFileSize) {
              onInitialVideoFileSize(initialFileSize);
              bytesLength = initialFileSize;
            },
            downloadingStream: (downloadedBytes) {
              videoDownloadingStream(downloadedBytes);
              bytesLength += downloadedBytes.length;
              downloadsVideoProgressMap[id]![filename] = DownloadProgress(
                progress: bytesLength,
                totalProgress: videoStream.sizeInBytes ?? 0,
              );
            },
          );
          videoFile = downloadedFile;
        }

        final qualified = await fileSizeQualified(file: videoFile, targetSize: videoStream.sizeInBytes ?? 0);
        if (qualified) {
          await onVideoFileReady(videoFile);

          // if we should keep as a cache, we copy the downloaded file to cache dir
          // -- [!isVideoFileCached] is very important, otherwise it will copy to itself (0 bytes result).
          if (isVideoFileCached == false && keepCachedVersionsIfDownloaded) {
            await videoFile.copy(videoStream.cachePath(id));
          }
        } else {
          videoFile = null;
        }
      }
      // -----------------------------------

      // --------- Downloading Choosen Audio.
      if (audioStream != null) {
        final filecache = audioStream.getCachedFile(id);
        if (useCachedVersionsIfAvailable && filecache != null && await fileSizeQualified(file: filecache, targetSize: audioStream.sizeInBytes ?? 0)) {
          audioFile = filecache;
          isAudioFileCached = true;
        } else {
          if (audioStream.sizeInBytes == null || audioStream.sizeInBytes == 0) {
            audioStream.sizeInBytes = await _getContentSize(audioStream.url ?? '');
          }
          int bytesLength = 0;

          downloadsAudioProgressMap[id] ??= <String, DownloadProgress>{}.obs;
          final downloadedFile = await _checkFileAndDownload(
            groupName: groupName,
            url: audioStream.url ?? '',
            targetSize: audioStream.sizeInBytes ?? 0,
            filename: filenameClean,
            destinationFilePath: _getTempAudioPath(
              groupName: groupName,
              fullFilename: filenameClean,
              saveDir: saveDirectory,
            ),
            onInitialFileSize: (initialFileSize) {
              onInitialAudioFileSize(initialFileSize);
              bytesLength = initialFileSize;
            },
            downloadingStream: (downloadedBytes) {
              audioDownloadingStream(downloadedBytes);
              bytesLength += downloadedBytes.length;
              downloadsAudioProgressMap[id]![filename] = DownloadProgress(
                progress: bytesLength,
                totalProgress: audioStream.sizeInBytes ?? 0,
              );
            },
          );
          audioFile = downloadedFile;
        }
        final qualified = await fileSizeQualified(file: audioFile, targetSize: audioStream.sizeInBytes ?? 0);

        if (qualified) {
          await onAudioFileReady(audioFile);

          // if we should keep as a cache, we copy the downloaded file to cache dir
          // -- [!isAudioFileCached] is very important, otherwise it will copy to itself (0 bytes result).
          if (isAudioFileCached == false && keepCachedVersionsIfDownloaded) {
            await audioFile.copy(audioStream.cachePath(id));
          }
        } else {
          audioFile = null;
        }
      }
      // -----------------------------------

      // ----- merging if both video & audio were downloaded
      final output = "${saveDirectory.path}/$filenameClean";
      if (merge && videoFile != null && audioFile != null) {
        bool didMerge = await NamidaFFMPEG.inst.mergeAudioAndVideo(
          videoPath: videoFile.path,
          audioPath: audioFile.path,
          outputPath: output,
        );
        if (!didMerge) {
          // -- sometimes, no extension is specified, which causes failure
          didMerge = await NamidaFFMPEG.inst.mergeAudioAndVideo(
            videoPath: videoFile.path,
            audioPath: audioFile.path,
            outputPath: "$output.mp4",
          );
        }
        if (didMerge) {
          Future.wait([
            if (isVideoFileCached == false) videoFile.tryDeleting(),
            if (isAudioFileCached == false) audioFile.tryDeleting(),
          ]); // deleting temp files since they got merged
        }
        df = File(output);
      } else {
        // -- renaming files, or copying if cached
        Future<void> renameOrCopy({required File file, required String path, required bool isCachedVersion}) async {
          if (isCachedVersion) {
            await file.copy(path);
          } else {
            await file.rename(path);
          }
        }

        await Future.wait([
          if (videoFile != null && videoStream != null)
            renameOrCopy(
              file: videoFile,
              path: output,
              isCachedVersion: isVideoFileCached,
            ),
          if (audioFile != null && audioStream != null)
            renameOrCopy(
              file: audioFile,
              path: output,
              isCachedVersion: isAudioFileCached,
            ),
        ]);
        df = File(output);
      }
    } catch (e) {
      printy('Error Downloading YT Video: $e', isError: true);
    }

    isDownloading[id]![filenameClean] = false;

    final wasPaused = youtubeDownloadTasksInQueueMap[groupName]?[filenameClean] == false;
    _doneDownloadingNotification(
      videoId: id,
      videoTitle: filename,
      nameIdentifier: filenameClean,
      filename: filenameClean,
      downloadedFile: df,
      canceledByUser: wasPaused,
    );
    return df;
  }

  /// the file returned may not be complete if the client was closed.
  Future<File> _checkFileAndDownload({
    required String url,
    required int targetSize,
    required String groupName,
    required String filename,
    required String destinationFilePath,
    required void Function(int initialFileSize) onInitialFileSize,
    required void Function(List<int> downloadedBytes) downloadingStream,
  }) async {
    int downloadStartRange = 0;

    final file = await File(destinationFilePath).create(); // retrieving the temp file (or creating a new one).
    int initialFileSizeOnDisk = 0;
    try {
      initialFileSizeOnDisk = await file.length(); // fetching current size to be used as a range bytes for download request
    } catch (_) {}
    onInitialFileSize(initialFileSizeOnDisk);
    // only download if the download is incomplete, useful sometimes when file 'moving' fails.
    if (initialFileSizeOnDisk < targetSize) {
      downloadStartRange = initialFileSizeOnDisk;
      _downloadClientsMap[groupName] ??= {};
      _downloadClientsMap[groupName]?[filename]?.close(force: true);
      _downloadClientsMap[groupName]?[filename] = Dio(BaseOptions(headers: {HttpHeaders.rangeHeader: 'bytes=$downloadStartRange-'}));
      final downloadStream = await _downloadClientsMap[groupName]![filename]!
          .get<ResponseBody>(
            url,
            options: Options(responseType: ResponseType.stream),
          )
          .then((value) => value.data);

      if (downloadStream != null) {
        final fileStream = file.openWrite(mode: FileMode.append);
        await for (final data in downloadStream.stream) {
          fileStream.add(data);
          downloadingStream(data);
        }
        await fileStream.flush();
        await fileStream.close(); // closing file.
      }
    }
    _downloadClientsMap[groupName]?[filename]?.close(force: true);
    _downloadClientsMap[groupName]?.remove(filename);
    return File(destinationFilePath);
  }

  Dio? _downloadClient;
  Future<NamidaVideo?> downloadYoutubeVideo({
    required String id,
    VideoStream? stream,
    required void Function(List<VideoOnlyStream> availableStreams) onAvailableQualities,
    required void Function(VideoOnlyStream choosenStream) onChoosingQuality,
    required void Function(List<int> downloadedBytes) downloadingStream,
    required void Function(int initialFileSize) onInitialFileSize,
    required bool Function() canStartDownloading,
  }) async {
    if (id == '') return null;
    NamidaVideo? dv;
    try {
      // --------- Getting Video to Download.
      late VideoOnlyStream erabaretaStream;
      if (stream != null) {
        erabaretaStream = stream;
      } else {
        final availableVideos = await getAvailableVideoStreamsOnly(id);

        _sortVideoStreams(availableVideos);

        onAvailableQualities(availableVideos);

        erabaretaStream = availableVideos.last; // worst quality

        if (stream == null) {
          erabaretaStream = getPreferredStreamQuality(availableVideos);
        }
      }

      onChoosingQuality(erabaretaStream);
      // ------------------------------------

      // --------- Downloading Choosen Video.
      String getVPath(bool isTemp) {
        final dir = isTemp ? AppDirs.VIDEOS_CACHE_TEMP : null;
        return erabaretaStream.cachePath(id, directory: dir);
      }

      final erabaretaStreamSizeInBytes = erabaretaStream.sizeInBytes ?? 0;

      final file = await File(getVPath(true)).create(); // retrieving the temp file (or creating a new one).
      int initialFileSizeOnDisk = 0;
      try {
        initialFileSizeOnDisk = await file.length(); // fetching current size to be used as a range bytes for download request
      } catch (_) {}
      onInitialFileSize(initialFileSizeOnDisk);
      // only download if the download is incomplete, useful sometimes when file 'moving' fails.
      if (initialFileSizeOnDisk < erabaretaStreamSizeInBytes) {
        if (!canStartDownloading()) return null;
        final downloadStartRange = initialFileSizeOnDisk;

        _downloadClient = Dio(BaseOptions(headers: {HttpHeaders.rangeHeader: 'bytes=$downloadStartRange-'}));
        final downloadStream = await _downloadClient!
            .get<ResponseBody>(
              erabaretaStream.url ?? '',
              options: Options(responseType: ResponseType.stream),
            )
            .then((value) => value.data);

        if (downloadStream != null) {
          final fileStream = file.openWrite(mode: FileMode.append);
          await for (final data in downloadStream.stream) {
            fileStream.add(data);
            downloadingStream(data);
          }
          await fileStream.flush();
          await fileStream.close(); // closing file.
        }
      }

      // ------------------------------------

      // -- ensuring the file is downloaded completely before moving.
      final fileStats = await file.stat();
      const allowance = 1024; // 1KB allowance
      if (fileStats.size >= erabaretaStreamSizeInBytes - allowance) {
        final newfile = await file.rename(getVPath(false));
        dv = NamidaVideo(
          path: newfile.path,
          ytID: id,
          nameInCache: newfile.path.getFilenameWOExt,
          height: erabaretaStream.height ?? 0,
          width: erabaretaStream.width ?? 0,
          sizeInBytes: erabaretaStreamSizeInBytes,
          frameratePrecise: erabaretaStream.fps?.toDouble() ?? 0.0,
          creationTimeMS: 0, // TODO: get using metadata
          durationMS: erabaretaStream.durationMS ?? 0,
          bitrate: erabaretaStream.bitrate ?? 0,
        );
      }
    } catch (e) {
      printy('Error Downloading YT Video: $e', isError: true);
    }

    return dv;
  }

  void dispose({bool closeCurrentDownloadClient = true, bool closeAllClients = false}) {
    if (closeCurrentDownloadClient) {
      _downloadClient?.close(force: true);
      _downloadClient = null;
    }

    if (closeAllClients) {
      for (final c in _downloadClientsMap.values) {
        for (final client in c.values) {
          client.close(force: true);
        }
      }
    }
  }
}

extension _IDToUrlConvert on String {
  String toYTUrl() => 'https://www.youtube.com/watch?v=$this';
}
