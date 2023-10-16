// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';

import 'package:namida/class/video.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/ffmpeg_controller.dart';
import 'package:namida/controller/notification_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';

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
  final currentTotalCommentsCount = Rxn<int>();
  final isLoadingComments = false.obs;
  final currentYTQualities = <VideoOnlyStream>[].obs;
  final currentYTAudioStreams = <AudioOnlyStream>[].obs;

  /// Used as a backup in case of no connection.
  final currentCachedQualities = <NamidaVideo>[].obs;

  /// {id: <filename, DownloadProgress>{}}
  final downloadsVideoProgressMap = <String, RxMap<String, DownloadProgress>>{}.obs;

  /// {id: <filename, DownloadProgress>{}}
  final downloadsAudioProgressMap = <String, RxMap<String, DownloadProgress>>{}.obs;

  final _downloadClientsMap = <String, Dio>{}; // {nameIdentifier: Dio()}

  final isDownloading = <String, bool>{}.obs;

  /// Temporarely saves StreamInfoItem info for flawless experience while waiting for real info.
  final _tempVideoInfosFromStreams = <String, StreamInfoItem>{}; // {id: StreamInfoItem()}

  /// Used for easily displaying title & channel inside history directly without needing to fetch or rely on cache.
  /// This comes mainly after a youtube history import
  final _tempBackupVideoInfo = <String, YoutubeVideoHistory>{}; // {id: YoutubeVideoHistory()}

  YoutubeVideoHistory? getBackupVideoInfo(String id) {
    _tempVideoInfosFromStreams.remove('');
    return _tempBackupVideoInfo[id];
  }

  Future<void> fillBackupInfoMap() async {
    final map = await _fillBackupInfoMapIsolate.thready(AppDirs.YT_STATS);
    _tempBackupVideoInfo
      ..clear()
      ..addAll(map);
  }

  static Map<String, YoutubeVideoHistory> _fillBackupInfoMapIsolate(String dirPath) {
    final map = <String, YoutubeVideoHistory>{};
    for (final f in Directory(dirPath).listSync()) {
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

  VideoInfo? getTemporarelyVideoInfo(String id) {
    _tempVideoInfosFromStreams.remove('');
    final si = _tempVideoInfosFromStreams[id];
    return si == null ? null : VideoInfo.fromStreamInfoItem(si);
  }

  /// Keeps the map at max 2000 items. maintained by least recently used.
  void _fillTempVideoInfoMap(Iterable<StreamInfoItem>? items) {
    if (items != null) {
      final entries = items.map((e) => MapEntry(e.id ?? '', e));
      _tempVideoInfosFromStreams.optimizedAdd(entries, 2000);
    }
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
    currentRelatedVideos
      ..clear()
      ..addAll(List.filled(20, null));
    final items = await NewPipeExtractorDart.videos.getRelatedStreams(id.toYTUrl());
    _fillTempVideoInfoMap(items.whereType<StreamInfoItem>());
    if (_canSafelyModifyMetadata(id)) {
      currentRelatedVideos
        ..clear()
        ..addAll([
          ...items,
        ]);
    }
  }

  /// For full list of items, use [streams] getter in [playlist].
  Future<List<StreamInfoItem>> getPlaylistStreams(YoutubePlaylist? playlist) async {
    if (playlist == null) return [];
    final streams = await playlist.getStreamsNextPage();
    _fillTempVideoInfoMap(streams);
    return streams;
  }

  Future<void> _fetchComments(String id, {bool forceRequest = false}) async {
    currentTotalCommentsCount.value = null;
    currentComments.clear();
    currentComments.addAll(List.filled(20, null));

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
      currentComments.addAll(fetchedComments);
      currentTotalCommentsCount.value = fetchedComments.firstOrNull?.totalCommentsCount;
    }
  }

  Future<void> _fetchNextComments(String id) async {
    if (_isCurrentCommentsFromCache) return;
    final comments = await NewPipeExtractorDart.comments.getNextComments();
    if (_canSafelyModifyMetadata(id)) {
      currentComments.addAll(comments);

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

  VideoStream getPreferredStreamQuality(List<VideoStream> streams, {bool preferIncludeWebm = true}) {
    final preferredQualities = settings.youtubeVideoQualities.map((element) => element.settingLabeltoVideoLabel());
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
    if (scrollController.hasClients) scrollController.jumpTo(0);
    startDimTimer();

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

    final channelUrl = _tempVideoInfosFromStreams[id]?.uploaderUrl;

    if (channelUrl != null) {
      await Future.wait([
        fetchVideoDetails(id).then((info) {
          updateForCurrentID(() {
            currentYoutubeMetadataVideo.value = info;
          });
        }),
        _fetchChannelDetails(channelUrl).then((channel) {
          updateForCurrentID(() {
            currentYoutubeMetadataChannel.value = channel;
          });
        }),
      ]);
    } else {
      final info = await fetchVideoDetails(id, forceRequest: forceRequest);
      final channel = await _fetchChannelDetails(info?.uploaderUrl, forceRequest: forceRequest);
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
    if (info != null) await File("${AppDirs.YT_METADATA}$id.txt").writeAsJson(info.toMap());
  }

  /// fetches cache version only.
  VideoInfo? fetchVideoDetailsFromCacheSync(String id) {
    final cachedFile = File("${AppDirs.YT_METADATA}$id.txt");
    if (cachedFile.existsSync()) {
      final res = cachedFile.readAsJsonSync();
      return VideoInfo.fromMap(res);
    }
    return null;
  }

  YoutubeChannel? fetchChannelDetailsFromCacheSync(String? channelUrl) {
    final channelId = channelUrl?.split('/').last;
    final cachedFile = File("${AppDirs.YT_METADATA_CHANNELS}$channelId.txt");
    if (cachedFile.existsSync()) {
      final res = cachedFile.readAsJsonSync();
      return YoutubeChannel.fromMap(res);
    }
    return null;
  }

  Future<YoutubeChannel> _fetchChannelDetails(String? channelUrl, {bool forceRequest = false}) async {
    final channelId = channelUrl?.split('/').last;
    final cachedFile = File("${AppDirs.YT_METADATA_CHANNELS}$channelId.txt");
    YoutubeChannel? vi;
    if (!forceRequest && await cachedFile.exists()) {
      final res = await cachedFile.readAsJson();
      vi = YoutubeChannel.fromMap(res);
    } else {
      final info = await NewPipeExtractorDart.channels.channelInfo(channelUrl);
      vi = info;
      cachedFile.writeAsJson(info.toMap());
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
    audios.sortByReverseAlt(
      (e) => e.bitrate ?? 0,
      (e) => e.sizeInBytes ?? 0,
    );
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
        final title = getTemporarelyVideoInfo(videoId)?.name ?? fetchVideoDetailsFromCacheSync(videoId)?.name ?? videoId;
        final speedB = speedInBytes(videoId, entry.value.progress);
        if (p / tp >= 1) {
          map.remove(entry.key);
        } else {
          NotificationService.inst.downloadYoutubeNotification(
            notificationID: entry.key,
            title: "Downloading $downloadingText: $title",
            progress: p,
            total: tp,
            subtitle: (progressText) => "$progressText (${speedB.fileSizeFormatted}/s)",
            imagePath: VideoController.inst.getYoutubeThumbnailFromCacheSync(id: videoId)?.path,
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
  }) {
    if (downloadedFile == null) {
      NotificationService.inst.doneDownloadingYoutubeNotification(
        notificationID: nameIdentifier,
        videoTitle: videoTitle,
        subtitle: 'Download Failed',
        imagePath: VideoController.inst.getYoutubeThumbnailFromCacheSync(id: videoId)?.path,
        failed: true,
      );
    } else {
      NotificationService.inst.doneDownloadingYoutubeNotification(
        notificationID: nameIdentifier,
        videoTitle: downloadedFile.path.getFilenameWOExt,
        subtitle: 'Downloaded ${downloadedFile.lengthSync().fileSizeFormatted}',
        imagePath: VideoController.inst.getYoutubeThumbnailFromCacheSync(id: videoId)?.path,
        failed: false,
      );
    }
    _tryCancelDownloadNotificationTimer();
    downloadsVideoProgressMap.remove(videoId);
    downloadsAudioProgressMap.remove(videoId);
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

  Future<File?> downloadYoutubeVideoRaw({
    required String id,
    required bool useCachedVersionsIfAvailable,
    required Directory saveDirectory,
    required String filename,
    required VideoStream? videoStream,
    required AudioOnlyStream? audioStream,
    required bool merge,
    required bool keepCachedVersionsIfDownloaded,
    required void Function(List<int> downloadedBytes) videoDownloadingStream,
    required void Function(List<int> downloadedBytes) audioDownloadingStream,
    required void Function(int initialFileSize) onInitialVideoFileSize,
    required void Function(int initialFileSize) onInitialAudioFileSize,
    required Future<void> Function(File videoFile) onVideoFileReady,
    required Future<void> Function(File audioFile) onAudioFileReady,
  }) async {
    if (id == '') return null;

    isDownloading[id] = true;

    _startNotificationTimer();

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

    final filenameClean = filename.replaceAll(RegExp(r'[#\$|/\\!^]', caseSensitive: false), '_');
    try {
      // --------- Downloading Choosen Video.
      if (videoStream != null) {
        final filecache = videoStream.getCachedFile(id);
        if (useCachedVersionsIfAvailable && filecache != null) {
          videoFile = filecache;
          isVideoFileCached = true;
        } else {
          String getVPath(bool isTemp) {
            final prefix = isTemp ? '.tempv_' : '';
            return "${saveDirectory.path}/$prefix$filenameClean";
          }

          if (videoStream.sizeInBytes == null || videoStream.sizeInBytes == 0) {
            videoStream.sizeInBytes = await _getContentSize(videoStream.url ?? '');
          }

          int bytesLength = 0;

          final downloadedFile = await _checkFileAndDownload(
            url: videoStream.url ?? '',
            targetSize: videoStream.sizeInBytes ?? 0,
            filename: filenameClean,
            destinationFilePath: getVPath(true),
            onInitialFileSize: (initialFileSize) {
              onInitialVideoFileSize(initialFileSize);
              bytesLength = initialFileSize;
            },
            downloadingStream: (downloadedBytes) {
              videoDownloadingStream(downloadedBytes);
              bytesLength += downloadedBytes.length;
              downloadsVideoProgressMap[id] ??= <String, DownloadProgress>{}.obs;
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
        if (useCachedVersionsIfAvailable && filecache != null) {
          audioFile = filecache;
          isAudioFileCached = true;
        } else {
          String getAPath(bool isTemp) {
            final prefix = isTemp ? '.tempa_' : '';
            return "${saveDirectory.path}/$prefix$filenameClean";
          }

          if (audioStream.sizeInBytes == null || audioStream.sizeInBytes == 0) {
            audioStream.sizeInBytes = await _getContentSize(audioStream.url ?? '');
          }
          int bytesLength = 0;

          final downloadedFile = await _checkFileAndDownload(
            url: audioStream.url ?? '',
            targetSize: audioStream.sizeInBytes ?? 0,
            filename: filenameClean,
            destinationFilePath: getAPath(true),
            onInitialFileSize: (initialFileSize) {
              onInitialAudioFileSize(initialFileSize);
              bytesLength = initialFileSize;
            },
            downloadingStream: (downloadedBytes) {
              audioDownloadingStream(downloadedBytes);
              bytesLength += downloadedBytes.length;
              downloadsAudioProgressMap[id] ??= <String, DownloadProgress>{}.obs;
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
        final didMerge = await NamidaFFMPEG.inst.mergeAudioAndVideo(
          videoPath: videoFile.path,
          audioPath: audioFile.path,
          outputPath: output,
        );
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

    isDownloading[id] = false;
    _doneDownloadingNotification(
      videoId: id,
      videoTitle: filename,
      nameIdentifier: filename,
      downloadedFile: df,
    );
    return df;
  }

  /// the file returned may not be complete if the client was closed.
  Future<File> _checkFileAndDownload({
    required String url,
    required int targetSize,
    required String filename,
    required String destinationFilePath,
    required void Function(int initialFileSize) onInitialFileSize,
    required void Function(List<int> downloadedBytes) downloadingStream,
  }) async {
    int downloadStartRange = 0;

    final file = await File(destinationFilePath).create(); // retrieving the temp file (or creating a new one).
    final initialFileSizeOnDisk = await file.length(); // fetching current size to be used as a range bytes for download request
    onInitialFileSize(initialFileSizeOnDisk);
    // only download if the download is incomplete, useful sometimes when file 'moving' fails.
    if (initialFileSizeOnDisk < targetSize) {
      downloadStartRange = initialFileSizeOnDisk;

      _downloadClientsMap[filename] = Dio(BaseOptions(headers: {HttpHeaders.rangeHeader: 'bytes=$downloadStartRange-'}));
      final downloadStream = await _downloadClientsMap[filename]!
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
    _downloadClientsMap[filename]?.close();
    _downloadClientsMap.remove(filename);
    return File(destinationFilePath);
  }

  Dio? downloadClient;
  Future<NamidaVideo?> downloadYoutubeVideo({
    required String id,
    VideoStream? stream,
    required void Function(List<VideoOnlyStream> availableStreams) onAvailableQualities,
    required void Function(VideoOnlyStream choosenStream) onChoosingQuality,
    required void Function(List<int> downloadedBytes) downloadingStream,
    required void Function(int initialFileSize) onInitialFileSize,
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
      int downloadStartRange = 0;

      final file = await File(getVPath(true)).create(); // retrieving the temp file (or creating a new one).
      final initialFileSizeOnDisk = await file.length(); // fetching current size to be used as a range bytes for download request
      onInitialFileSize(initialFileSizeOnDisk);
      // only download if the download is incomplete, useful sometimes when file 'moving' fails.
      if (initialFileSizeOnDisk < erabaretaStreamSizeInBytes) {
        downloadStartRange = initialFileSizeOnDisk;

        downloadClient = Dio(BaseOptions(headers: {HttpHeaders.rangeHeader: 'bytes=$downloadStartRange-'}));
        final downloadStream = await downloadClient!
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
      downloadClient?.close(force: true);
      downloadClient = null;
    }

    if (closeAllClients) {
      for (final c in _downloadClientsMap.values) {
        c.close(force: true);
      }
    }
  }
}

extension _IDToUrlConvert on String {
  String toYTUrl() => 'https://www.youtube.com/watch?v=$this';
}
