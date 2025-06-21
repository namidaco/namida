import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:just_audio/just_audio.dart';
import 'package:namico_db_wrapper/namico_db_wrapper.dart';
import 'package:youtipie/class/streams/video_stream.dart';
import 'package:youtipie/class/streams/video_streams_result.dart';

import 'package:namida/class/media_info.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/ffmpeg_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/thumbnail_manager.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/video_widget.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';

part 'video_controller.priority.dart';

class NamidaVideoWidget extends StatefulWidget {
  final bool enableControls;
  final double? disableControlsUnderPercentage;
  final VoidCallback? onMinimizeTap;
  final bool fullscreen;
  final bool isPip;
  final bool zoomInToFullscreen;
  final bool swipeUpToFullscreen;
  final bool isLocal;

  const NamidaVideoWidget({
    super.key,
    this.enableControls = true,
    this.disableControlsUnderPercentage,
    this.onMinimizeTap,
    this.fullscreen = false,
    this.isPip = false,
    this.zoomInToFullscreen = true,
    this.swipeUpToFullscreen = false,
    required this.isLocal,
  });

  @override
  State<NamidaVideoWidget> createState() => _NamidaVideoWidgetState();
}

class _NamidaVideoWidgetState extends State<NamidaVideoWidget> {
  void _verifyAndEnterFullScreen() {
    if (NamidaNavigator.inst.isInFullScreen) {
      _cancelZoom();
      return;
    }

    if (VideoController.inst.videoZoomAdditionalScale.value > 1.1) {
      VideoController.inst.toggleFullScreenVideoView(isLocal: widget.isLocal);
    }
    // else if (videoZoomAdditionalScale.value < 0.7) {
    //   NamidaNavigator.inst.exitFullScreen();
    // }

    _cancelZoom();
  }

  void _cancelZoom() {
    VideoController.inst.videoZoomAdditionalScale.value = 0.0;
    _startedZoomSession = null;
    _zoomStartSuccessCount = 0;
  }

  bool? _startedZoomSession;
  int _zoomStartSuccessCount = 0;

  @override
  Widget build(BuildContext context) {
    final showControls = widget.isPip
        ? false
        : widget.fullscreen
            ? true
            : widget.enableControls;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerMove: !widget.swipeUpToFullscreen
          ? null
          : (details) {
              final drag = details.delta.dy;

              if (_startedZoomSession == false) return;
              if (_startedZoomSession == null) {
                if (_zoomStartSuccessCount < 0) {
                  _startedZoomSession = false;
                } else if (_zoomStartSuccessCount < 3) {
                  final success = details.delta.dy <= 1.0 && details.delta.dx.abs() <= 1.0;
                  _zoomStartSuccessCount += (success ? 1 : -1);
                } else {
                  _startedZoomSession = true;
                }
                return;
              }

              if (VideoController.inst.videoZoomAdditionalScale.value >= 0) {
                VideoController.inst.videoZoomAdditionalScale.value -= drag * 0.02;
              }
            },
      onPointerUp: !widget.swipeUpToFullscreen ? null : (details) => _verifyAndEnterFullScreen(),
      onPointerCancel: !widget.swipeUpToFullscreen ? null : (event) => _cancelZoom(),
      child: NamidaVideoControls(
        key: !showControls
            ? null
            : widget.fullscreen
                ? VideoController.inst.videoControlsKeyFullScreen
                : VideoController.inst.videoControlsKey,
        isLocal: widget.isLocal,
        onMinimizeTap: widget.onMinimizeTap,
        showControls: showControls,
        disableControlsUnderPercentage: widget.disableControlsUnderPercentage,
        isFullScreen: widget.fullscreen,
      ),
    );
  }
}

class VideoController {
  static VideoController get inst => _instance;
  static final VideoController _instance = VideoController._internal();
  VideoController._internal();

  final videoZoomAdditionalScale = 0.0.obs;

  void updateShouldShowControls(double animationValue) {
    final ytmini = videoControlsKey.currentState;
    if (ytmini == null) return;
    final isExpanded = animationValue >= 0.95;
    if (isExpanded) {
      // YoutubeMiniplayerUiController.inst.startDimTimer(); // bad experience honestly
    } else {
      // YoutubeMiniplayerUiController.inst.cancelDimTimer();
      ytmini.setControlsVisibily(false);
    }
  }

  Future<void> toggleFullScreenVideoView({
    required bool isLocal,
    bool? setOrientations,
  }) async {
    final aspect = Player.inst.videoPlayerInfo.value?.aspectRatio;
    Widget videoControls = NamidaVideoControls(
      key: VideoController.inst.videoControlsKeyFullScreen,
      isLocal: isLocal,
      onMinimizeTap: NamidaNavigator.inst.exitFullScreen,
      showControls: true,
      isFullScreen: true,
    );

    await NamidaNavigator.inst.toggleFullScreen(
      videoControls,
      setOrientations: setOrientations ?? (aspect == null ? true : aspect > 1),
    );
  }

  final currentBrigthnessDim = 1.0.obs;

  final videoControlsKey = GlobalKey<NamidaVideoControlsState>();
  final videoControlsKeyFullScreen = GlobalKey<NamidaVideoControlsState>();

  int get localVideosTotalCount => _allVideoPaths.length;

  final localVideoExtractCurrent = Rxn<int>();
  final localVideoExtractTotal = 0.obs;

  final currentVideo = Rxn<NamidaVideo>();
  final currentPossibleLocalVideos = <NamidaVideo>[].obs;
  final currentYTStreams = Rxn<VideoStreamsResult>();
  final currentDownloadedBytes = Rxn<int>();

  /// Indicates that [updateCurrentVideo] didn't find any matching video.
  final isNoVideosAvailable = false.obs;
  final videoBlockedByType = Rxn<VideoFetchBlockedBy>();

  /// `path`: `NamidaVideo`
  var _videoPathsInfoMap = <String, NamidaVideo>{};

  var _allVideoPaths = <String>{};

  /// `id`: `<NamidaVideo>[]`
  var _videoCacheIDMap = <String, List<NamidaVideo>>{};

  final videosPriorityManager = VideosPriorityManager();

  late final _videoCacheIDMapDB = DBWrapper.openFromInfo(
    fileInfo: AppPaths.VIDEOS_CACHE_DB_INFO,
    config: const DBConfig(createIfNotExist: true),
  );
  late final _videoLocalMapDB = DBWrapper.openFromInfo(
    fileInfo: AppPaths.VIDEOS_LOCAL_DB_INFO,
    config: const DBConfig(createIfNotExist: true),
  );

  Iterable<NamidaVideo> get videosInCache sync* {
    for (final vids in _videoCacheIDMap.values) {
      yield* vids;
    }
  }

  void addYTVideoToCacheMap(String id, NamidaVideo nv) {
    if (id.isEmpty) return;
    _videoCacheIDMap.addNoDuplicatesForce(id, nv);
    // well, no matter what happens, sometimes the info coming has extra info
    _videoCacheIDMap[id]?.removeDuplicates((element) => "${element.height}_${element.resolution}_${element.path}");
    _saveCachedVideos(id);
  }

  NamidaVideo addLocalVideoFileInfoToCacheMap(String path, MediaInfo info, FileStat fileStats, {String? ytID}) {
    final nv = _getNVFromFFMPEGMap(
      mediaInfo: info,
      ytID: ytID,
      path: path,
      stats: fileStats,
    );
    _videoPathsInfoMap[path] = nv;
    unawaited(_videoLocalMapDB.put(path, nv.toJson()));
    return nv;
  }

  bool doesVideoExistsInCache(String youtubeId) {
    if (youtubeId.isEmpty) return false;
    return _videoCacheIDMap[youtubeId]?.isNotEmpty ?? false;
  }

  bool hasNVCachedFromID(String youtubeId) {
    return _videoCacheIDMap[youtubeId]?.isNotEmpty ?? false;
  }

  Future<List<NamidaVideo>> getNVFromID(String youtubeId) async {
    if (youtubeId.isEmpty) return [];
    return await _videoCacheIDMap[youtubeId]?.whereAsync((element) => File(element.path).exists()).toList() ?? [];
  }

  Future<List<NamidaVideo>> getNVFromIDSorted(String youtubeId) async {
    if (youtubeId.isEmpty) return [];
    final videos = await _videoCacheIDMap[youtubeId]?.whereAsync((element) => File(element.path).exists()).toList() ?? [];
    videos.sortByReverseAlt(
      (e) {
        if (e.resolution != 0) return e.resolution;
        if (e.height != 0) return e.height;
        return 0;
      },
      (e) => e.frameratePrecise,
    );
    return videos;
  }

  List<NamidaVideo> getCurrentVideosInCache() {
    final videos = <NamidaVideo>[];
    for (final vl in _videoCacheIDMap.values) {
      vl.loop((v) {
        if (File(v.path).existsSync()) {
          videos.add(v);
        }
      });
    }
    return videos;
  }

  void removeNVFromCacheMap(String youtubeId, String path) {
    _videoCacheIDMap[youtubeId]?.removeWhere((element) => element.path == path);
    _saveCachedVideos(youtubeId);
  }

  Future<void> deleteAllVideosForVideoId(String youtubeId) async {
    final videos = _videoCacheIDMap[youtubeId];
    _videoCacheIDMap.remove(youtubeId);
    _saveCachedVideos(youtubeId);
    if (videos != null) await Future.wait(videos.map((item) => File(item.path).delete()));
  }

  void clearCachedVideosMap() {
    _videoCacheIDMap.clear();
    _videoCacheIDMapDB.deleteEverything();
  }

  Future<NamidaVideo?> updateCurrentVideo(Track? track, {bool returnEarly = false}) async {
    currentVideo.value = null;
    currentPossibleLocalVideos.value.clear();
    isNoVideosAvailable.value = false;
    videoBlockedByType.value = null;
    currentDownloadedBytes.value = null;
    currentYTStreams.value = null;
    if (track == null || track == kDummyTrack) return null;
    if (!settings.enableVideoPlayback.value) return null;
    if (track is Video) {
      NamidaVideo? nv = _videoPathsInfoMap[track.path];
      if (nv == null) {
        final stats = await File(track.path).stat();
        nv = NamidaVideo(
          path: track.path,
          height: 0,
          width: 0,
          sizeInBytes: stats.size,
          frameratePrecise: 0,
          creationTimeMS: stats.creationDate.millisecondsSinceEpoch,
          durationMS: 0,
          bitrate: 0,
        );
      }

      currentVideo.value = nv;
      currentPossibleLocalVideos.value = [nv];
      return nv;
    }

    final trackYTID = track.youtubeID;
    if (await videosPriorityManager.getVideoPriority(trackYTID) == CacheVideoPriority.GETOUT) {
      isNoVideosAvailable.value = true;
      videoBlockedByType.value = VideoFetchBlockedBy.cachePriority;
      return null;
    }

    final possibleVideos = await _getPossibleVideosFromTrack(track);
    currentPossibleLocalVideos.value = possibleVideos;

    if (possibleVideos.isEmpty && trackYTID == '') isNoVideosAvailable.value = true;

    final vpsInSettings = settings.videoPlaybackSource.value;
    switch (vpsInSettings) {
      case VideoPlaybackSource.local:
        possibleVideos.retainWhere((element) => element.ytID == null); // leave all videos that doesnt have youtube id, i.e: local
        break;
      case VideoPlaybackSource.youtube:
        possibleVideos.retainWhere((element) => element.ytID != null); // leave all videos having youtube id
        break;
      default:
        null; // VideoPlaybackSource.auto
    }

    NamidaVideo? erabaretaVideo;
    if (possibleVideos.isNotEmpty) {
      possibleVideos.sortByReverseAlt(
        (e) {
          if (e.resolution != 0) return e.resolution;
          if (e.height != 0) return e.height;
          return 0;
        },
        (e) => e.frameratePrecise,
      );
      erabaretaVideo = await possibleVideos.firstWhereEffAsync((element) => File(element.path).exists());
    }

    currentVideo.value = erabaretaVideo;

    if (returnEarly) return erabaretaVideo;

    if (erabaretaVideo == null) {
      if (vpsInSettings == VideoPlaybackSource.local) {
        videoBlockedByType.value = VideoFetchBlockedBy.playbackSource;
      } else if (!ConnectivityController.inst.hasConnection) {
        videoBlockedByType.value = VideoFetchBlockedBy.noNetwork;
      } else if (!ConnectivityController.inst.dataSaverMode.canFetchNetworkVideoStream) {
        videoBlockedByType.value = VideoFetchBlockedBy.dataSaver;
      } else {
        final downloadedVideo = await getVideoFromYoutubeAndUpdate(trackYTID);
        erabaretaVideo = downloadedVideo;
      }
    }

    if (erabaretaVideo != null) {
      await playVideoCurrent(video: erabaretaVideo, track: track);
    }
    // saving video thumbnail
    final id = erabaretaVideo?.ytID;
    if (id != null) {
      ThumbnailManager.inst.getYoutubeThumbnailAndCache(id: id, type: ThumbnailType.video);
    }

    return erabaretaVideo;
  }

  Future<void> playVideoCurrent({
    required NamidaVideo? video,
    (String, String)? cacheIdAndPath,
    required Track track,
  }) async {
    assert(video != null || cacheIdAndPath != null);
    if (!_canExecuteForCurrentTrackOnly(track)) return;

    final v = cacheIdAndPath != null ? _videoCacheIDMap[cacheIdAndPath.$1]?.firstWhereEff((e) => e.path == cacheIdAndPath.$2) : video;
    if (v != null) {
      currentVideo.value = v;
      await Player.inst.setVideo(
        source: AudioVideoSource.file(v.path),
        loopingAnimation: canLoopVideo(v, track.durationMS),
        isFile: true,
      );
    }
  }

  /// loop only if video duration is less than [p] of audio.
  bool canLoopVideo(NamidaVideo video, int trackDurationMS, {double p = 0.6}) {
    if (video.durationMS <= 0 || trackDurationMS <= 0) return false;
    return video.durationMS < trackDurationMS * p;
  }

  Future<void> toggleVideoPlayback() async {
    final currentValue = settings.enableVideoPlayback.value;
    settings.save(enableVideoPlayback: !currentValue);

    // only modify if not playing yt/local video, since [enableVideoPlayback] is
    // limited to local music.
    if (Player.inst.currentItem.value is! Selectable) return;

    if (currentValue) {
      // should close/hide
      currentVideo.value = null;
      YoutubeController.inst.dispose();
      await Player.inst.disposeVideo();
    } else {
      await updateCurrentVideo(Player.inst.currentTrack?.track);
    }
  }

  Timer? _downloadTimer;
  void _downloadTimerCancel() {
    _downloadTimer?.cancel();
    _downloadTimer = null;
  }

  bool _canExecuteForCurrentTrackOnly(Track? initialTrack) {
    if (initialTrack == null) return false;
    final current = Player.inst.currentTrack;
    if (current == null) return false;
    return initialTrack.path == current.track.path;
  }

  Future<void> fetchYTQualities(Track track) async {
    final streamsResult = await YoutubeInfoController.video.fetchVideoStreams(track.youtubeID, forceRequest: false);
    if (_canExecuteForCurrentTrackOnly(track)) currentYTStreams.value = streamsResult;
  }

  Future<NamidaVideo?> getVideoFromYoutubeAndUpdate(
    String? id, {
    VideoStreamsResult? mainStreams,
    VideoStream? stream,
  }) async {
    final tr = Player.inst.currentTrack?.track;
    if (tr == null) return null;
    final dv = await fetchVideoFromYoutube(id, stream: stream, mainStreams: mainStreams, canContinue: () => settings.enableVideoPlayback.value);
    if (!settings.enableVideoPlayback.value) return null;
    if (_canExecuteForCurrentTrackOnly(tr)) {
      currentVideo.value = dv;
      currentYTStreams.refresh();
      if (dv != null) currentPossibleLocalVideos.addNoDuplicates(dv);
      currentPossibleLocalVideos.sortByReverseAlt(
        (e) {
          if (e.resolution != 0) return e.resolution;
          if (e.height != 0) return e.height;
          return 0;
        },
        (e) => e.frameratePrecise,
      );
    }
    return dv;
  }

  Future<NamidaVideo?> fetchVideoFromYoutube(
    String? id, {
    VideoStreamsResult? mainStreams,
    VideoStream? stream,
    required bool Function() canContinue,
  }) async {
    _downloadTimerCancel();
    if (id == null || id == '') return null;
    currentDownloadedBytes.value = null;

    final initialTrack = Player.inst.currentTrack?.track;

    int downloaded = 0;
    void updateCurrentBytes() {
      if (!_canExecuteForCurrentTrackOnly(initialTrack)) return;

      if (downloaded > 0) currentDownloadedBytes.value = downloaded;
      printy('Video Download: ${currentDownloadedBytes.value?.fileSizeFormatted}');
    }

    _downloadTimer = Timer.periodic(const Duration(seconds: 1), (_) => updateCurrentBytes());

    VideoStream? streamToUse = stream;
    if (stream == null || (mainStreams?.hasExpired() ?? true)) {
      // expired null or true
      mainStreams = await YoutubeInfoController.video.fetchVideoStreams(id);
      if (mainStreams != null) {
        final newStreamToUse = mainStreams.videoStreams.firstWhereEff((e) => e.itag == stream?.itag) ?? YoutubeController.inst.getPreferredStreamQuality(mainStreams.videoStreams);
        streamToUse = newStreamToUse;
      }
    }

    if (streamToUse == null || !canContinue()) {
      if (_canExecuteForCurrentTrackOnly(initialTrack)) {
        currentDownloadedBytes.value = null;
        _downloadTimerCancel();
      }
      return null;
    }

    final downloadedVideo = await YoutubeController.inst.downloadYoutubeVideo(
      canStartDownloading: () => settings.enableVideoPlayback.value,
      id: id,
      stream: streamToUse,
      creationDate: mainStreams?.info?.uploadDate.date ?? mainStreams?.info?.publishDate.date,
      onAvailableQualities: (availableStreams) {},
      onChoosingQuality: (choosenStream) {
        if (_canExecuteForCurrentTrackOnly(initialTrack)) {
          currentVideo.value = NamidaVideo(
            path: '',
            ytID: id,
            height: choosenStream.height,
            width: choosenStream.width,
            sizeInBytes: choosenStream.sizeInBytes,
            frameratePrecise: choosenStream.fps.toDouble(),
            creationTimeMS: 0,
            durationMS: choosenStream.duration?.inMilliseconds ?? 0,
            bitrate: choosenStream.bitrate,
          );
        }
      },
      onInitialFileSize: (initialFileSize) {
        downloaded = initialFileSize;
        updateCurrentBytes();
      },
      downloadingStream: (downloadedBytesLength) {
        downloaded += downloadedBytesLength;
      },
    );

    updateCurrentBytes();

    if (downloadedVideo != null) {
      final ytId = downloadedVideo.ytID;
      if (ytId != null) {
        _videoCacheIDMap.addNoDuplicatesForce(ytId, downloadedVideo);
        _saveCachedVideos(ytId);
      }
    }
    if (_canExecuteForCurrentTrackOnly(initialTrack)) {
      currentDownloadedBytes.value = null;
      _downloadTimerCancel();
    }
    return downloadedVideo;
  }

  List<String> _getPossibleVideosPathsFromAudioFile(String path) {
    final possibleLocal = <String>[];
    final trExt = Track.explicit(path).toTrackExt();

    final valInSett = settings.localVideoMatchingType.value;
    final shouldCheckSameDir = settings.localVideoMatchingCheckSameDir.value;

    void matchFileName(String videoName, String vpath, bool ensureSameDir) {
      if (ensureSameDir) {
        if (vpath.getDirectoryPath != path.getDirectoryPath) return;
      }

      final videoNameContainsMusicFileName = _checkFileNameAudioVideo(videoName, path.getFilenameWOExt);
      if (videoNameContainsMusicFileName) possibleLocal.add(vpath);
    }

    void matchTitleAndArtist(String videoName, String vpath, bool ensureSameDir) {
      if (ensureSameDir) {
        if (vpath.getDirectoryPath != path.getDirectoryPath) return;
      }
      final videoContainsTitle = videoName.contains(trExt.title.cleanUpForComparison);
      final videoNameContainsTitleAndArtist = videoContainsTitle && trExt.artistsList.isNotEmpty && videoName.contains(trExt.artistsList.first.cleanUpForComparison);
      // useful for [Nightcore - title]
      // track must contain Nightcore as the first Genre
      final videoNameContainsTitleAndGenre = videoContainsTitle && trExt.genresList.isNotEmpty && videoName.contains(trExt.genresList.first.cleanUpForComparison);
      if (videoNameContainsTitleAndArtist || videoNameContainsTitleAndGenre) possibleLocal.add(vpath);
    }

    switch (valInSett) {
      case LocalVideoMatchingType.auto:
        for (final vp in _allVideoPaths) {
          final videoName = vp.getFilenameWOExt;
          matchFileName(videoName, vp, shouldCheckSameDir);
          matchTitleAndArtist(videoName, vp, shouldCheckSameDir);
        }
        break;

      case LocalVideoMatchingType.filename:
        for (final vp in _allVideoPaths) {
          final videoName = vp.getFilenameWOExt;
          matchFileName(videoName, vp, shouldCheckSameDir);
        }

        break;
      case LocalVideoMatchingType.titleAndArtist:
        for (final vp in _allVideoPaths) {
          final videoName = vp.getFilenameWOExt;
          matchTitleAndArtist(videoName, vp, shouldCheckSameDir);
        }
        break;
    }
    return possibleLocal;
  }

  Future<List<NamidaVideo>> _getPossibleVideosFromTrack(Track track) async {
    final link = track.youtubeLink;
    final id = link.getYoutubeID;

    final possibleCached = await getNVFromIDSorted(id);
    final local = _getPossibleVideosPathsFromAudioFile(track.path);
    final possibleLocal = <NamidaVideo>[];
    for (int i = 0; i < local.length; i++) {
      var l = local[i];
      if (_videoPathsInfoMap[l] == null) {
        try {
          final v = await NamidaFFMPEG.inst.extractMetadata(l);
          if (v != null) {
            ThumbnailManager.inst.extractVideoThumbnailAndSave(
              videoPath: l,
              isLocal: true,
              idOrFileNameWithExt: l.getFilename,
              forceExtract: true,
            );
            final newVidInfo = addLocalVideoFileInfoToCacheMap(l, v, await File(l).stat());
            _videoPathsInfoMap[l] = newVidInfo;
          }
        } catch (e) {
          printy(e, isError: true);
          continue;
        }
      }
      final nv = _videoPathsInfoMap[l];
      if (nv != null) possibleLocal.add(nv);
    }
    return [...possibleCached, ...possibleLocal];
  }

  bool _checkFileNameAudioVideo(String videoFileName, String audioFileName) {
    return videoFileName.cleanUpForComparison.contains(audioFileName.cleanUpForComparison) || videoFileName.contains(audioFileName);
  }

  Future<void> initialize() async {
    await Future.wait([
      _fetchAndCheckCacheVideos(), // --> should think about a way to flank around scanning lots of cache videos if info not found (ex: after backup)
      _fetchAndCheckLocalVideos(), // this will get paths only and disables extracting whole local videos on startup
    ]);

    if (Player.inst.videoPlayerInfo.value?.isInitialized != true) await updateCurrentVideo(Player.inst.currentTrack?.track);
  }

  Future<void> rescanLocalVideosPaths({bool strictNoMedia = true}) async {
    localVideoExtractCurrent.value = 0;
    final videos = await _fetchVideoPathsFromStorage(strictNoMedia: strictNoMedia);
    _allVideoPaths = videos;
    localVideoExtractCurrent.value = null;
  }

  Future<void> _fetchAndCheckLocalVideos() async {
    await rescanLocalVideosPaths();

    final localVideos = await _VideoControllerIsolateFunctions._readLocalVideosDb.thready([AppPaths.VIDEOS_LOCAL_OLD, _videoLocalMapDB.fileInfo]);

    _videoPathsInfoMap = localVideos;
    printy('videos local: ${localVideos.length}');
  }

  Future<void> _saveCachedVideos(String id) {
    final videos = _videoCacheIDMap[id];
    if (videos == null || videos.isEmpty) {
      return _videoCacheIDMapDB.delete(id);
    }
    final map = <String, Map<String, dynamic>>{};
    for (int i = 0; i < videos.length; i++) {
      var item = videos[i];
      map['$i'] = item.toJson();
    }
    return _videoCacheIDMapDB.put(id, map);
  }

  /// - Checks videos in cache & makes sure everything exists and valid, plus extracting info for new videos if any.
  /// - Detects: `deleted`, `needs-to-be-updated` & `new` files
  Future<void> _fetchAndCheckCacheVideos() async {
    final params = _VideoControllerIsolateRequest(
      oldJsonFilePath: AppPaths.VIDEOS_CACHE_OLD,
      dbFileInfo: _videoCacheIDMapDB.fileInfo,
      cacheDirPath: AppDirs.VIDEOS_CACHE,
    );
    final res = await _VideoControllerIsolateFunctions._fetchAndCheckCachedVideosMainIsolate.thready(params);

    final validMap = res.validMap;
    final shouldBeReExtracted = res.newIdsMap;
    final removedIdsCount = res.removedCount;

    _videoCacheIDMap = validMap;

    printy('videos details => cached: ${_videoCacheIDMap.length} | new/updated: ${shouldBeReExtracted.length} | removed: $removedIdsCount');

    for (final newEntry in shouldBeReExtracted.entries) {
      final newId = newEntry.key;
      for (final statAndPath in newEntry.value) {
        final nv = await _extractNVFromCacheVideo(
          stats: statAndPath.$1,
          id: newId,
          path: statAndPath.$2,
        );
        _videoCacheIDMap.addForce(newId, nv);
      }
      _saveCachedVideos(newId); // will write the map value and delete if required
    }
  }

  /// - Loops the currently existing files
  /// - Detects: `new files`.
  /// - DOES NOT handle: `deleted` & `needs-to-be-updated` files.
  /// - Returns a map with **new videos only**.
  /// - **New**: excludes files ending with `.part`
  // Future<Map<String, List<NamidaVideo>>> _checkForNewVideosInCache(Map<String, List<int>> idsMap) async {
  //   final newIds = await _VideoControllerIsolateFunctions._checkForNewVideosInCacheIsolate.thready({
  //     'dirPath': AppDirs.VIDEOS_CACHE,
  //     'idsMap': idsMap,
  //   });

  //   final newIdsMap = <String, List<NamidaVideo>>{};

  //   for (final newId in newIds.entries) {
  //     for (final statAndPath in newId.value) {
  //       final nv = await _extractNVFromCacheVideo(
  //         stats: statAndPath.$1,
  //         id: newId.key,
  //         path: statAndPath.$2,
  //       );
  //       newIdsMap.addForce(newId.key, nv);
  //     }
  //   }

  //   return newIdsMap;
  // }

  Future<NamidaVideo> _extractNVFromCacheVideo({
    required FileStat stats,
    required String id,
    required String path,
  }) async {
    ThumbnailManager.inst.extractVideoThumbnailAndSave(
      videoPath: path,
      isLocal: false,
      idOrFileNameWithExt: id,
      forceExtract: false,
    );
    final info = await NamidaFFMPEG.inst.extractMetadata(path);
    return _getNVFromFFMPEGMap(
      mediaInfo: info,
      stats: stats,
      ytID: id,
      path: path,
    );
  }

  NamidaVideo _getNVFromFFMPEGMap({required String path, MediaInfo? mediaInfo, required FileStat stats, String? ytID}) {
    final videoStream = mediaInfo?.streams?.firstWhereEff((element) => element.streamType == StreamType.video);

    double? frameratePrecise;
    final framerateField = videoStream?.rFrameRate?.split('/');
    if (framerateField != null && framerateField.length == 2) {
      final frp1 = int.tryParse(framerateField.first);
      final frp2 = int.tryParse(framerateField.last) ?? 1000;
      if (frp1 != null) frameratePrecise = frp1 / frp2;
    }

    return NamidaVideo(
      path: path,
      ytID: ytID,
      nameInCache: ytID != null ? path.getFilename : null,
      height: videoStream?.height ?? 0,
      width: videoStream?.width ?? 0,
      sizeInBytes: stats.size,
      creationTimeMS: stats.creationDate.millisecondsSinceEpoch,
      frameratePrecise: frameratePrecise ?? 0.0,
      durationMS: videoStream?.duration?.inMilliseconds ?? mediaInfo?.format?.duration?.inMilliseconds ?? 0,
      bitrate: int.tryParse(videoStream?.bitRate ?? mediaInfo?.format?.bitRate ?? '') ?? 0,
    );
  }

  Future<Set<String>> _fetchVideoPathsFromStorage({bool strictNoMedia = true}) async {
    final dirsFilterer = DirsFileFilter(
      directoriesToExclude: settings.directoriesToExclude.value,
      extensions: NamidaFileExtensionsWrapper.video,
      strictNoMedia: strictNoMedia,
    );
    final result = await dirsFilterer.filter();

    final allVideoPaths = result.allPaths;
    // final excludedByNoMedia = result.excludedByNoMedia;
    return allVideoPaths;
  }
}

extension _GlobalPaintBounds on BuildContext {
  // ignore: unused_element
  Rect? get globalPaintBounds {
    final renderObject = findRenderObject();
    final translation = renderObject?.getTransformTo(null).getTranslation();
    if (translation != null && renderObject?.paintBounds != null) {
      final offset = Offset(translation.x, translation.y);
      return renderObject!.paintBounds.shift(offset);
    } else {
      return null;
    }
  }
}

class _VideoControllerIsolateFunctions {
  const _VideoControllerIsolateFunctions();

  static Map<String, NamidaVideo> _readLocalVideosDb(List params) {
    final oldJsonFilePath = params[0] as String;
    final dbFileInfo = params[1] as DbWrapperFileInfo;
    final oldJsonFile = File(oldJsonFilePath);
    NamicoDBWrapper.initialize();
    final db = DBWrapper.openFromInfoSync(
      fileInfo: dbFileInfo,
      config: const DBConfig(
        createIfNotExist: true,
        autoDisposeTimerDuration: null,
      ),
    );

    // -- migrating old json file
    if (oldJsonFile.existsSync()) {
      try {
        final localVideosInfoFile = oldJsonFile.readAsJsonSync() as List?;
        if (localVideosInfoFile != null) {
          for (final map in localVideosInfoFile) {
            final path = map['path'] as String?;
            if (path != null) db.put(path, map);
          }
        }
        oldJsonFile.deleteSync();
      } catch (_) {}
    }

    final localVids = <String, NamidaVideo>{};
    db.loadEverything(
      (e) {
        final nv = NamidaVideo.fromJson(e);
        localVids[nv.path] = nv;
      },
    );
    db.close();
    return localVids;
  }

  static _VideoControllerIsolateResult _fetchAndCheckCachedVideosMainIsolate(_VideoControllerIsolateRequest params) {
    final oldJsonFile = File(params.oldJsonFilePath);
    final dbFileInfo = params.dbFileInfo;
    NamicoDBWrapper.initialize();
    final db = DBWrapper.openFromInfoSync(
      fileInfo: dbFileInfo,
      config: const DBConfig(
        createIfNotExist: true,
        autoDisposeTimerDuration: null,
      ),
    );

    // -- migrating old json file
    if (oldJsonFile.existsSync()) {
      try {
        final cacheVideosInfoFile = oldJsonFile.readAsJsonSync() as List?;
        if (cacheVideosInfoFile != null) {
          final videosInMap = <String, Map<String, Map<String, dynamic>>>{};
          for (final map in cacheVideosInfoFile) {
            final youtubeId = map['ytID'] as String?;
            if (youtubeId != null) {
              videosInMap[youtubeId] ??= {};
              final indexString = '${videosInMap[youtubeId]!.length}';
              videosInMap[youtubeId]![indexString] = map;
            }
          }
          for (final e in videosInMap.entries) {
            db.put(e.key, e.value);
          }
        }
        oldJsonFile.deleteSync();
      } catch (_) {}
    }

    final validMap = <String, List<NamidaVideo>>{};
    final newIdsMap = <String, List<(FileStat, String)>>{};
    final shouldBeRemovedIds = <String>{};

    db.loadEverythingKeyed(
      (id, value) {
        for (final videoJson in value.values) {
          final v = NamidaVideo.fromJson(videoJson);
          final file = File(v.path);
          // --- File Exists, will be added either instantly, or by fetching new metadata.
          if (file.existsSync()) {
            final stats = file.statSync();
            // -- Video Exists, and already updated.
            if (v.sizeInBytes == stats.size) {
              validMap.addForce(id, v);
            }
            // -- Video exists but needs to be updated.
            else {
              newIdsMap.addForce(id, (stats, v.path));
            }
          } else {
            // -- File doesnt exist, ie. has been removed
            shouldBeRemovedIds.add(id);
          }
        }
      },
    );

    final shouldBeRemovedIdsList = shouldBeRemovedIds.toList();
    if (shouldBeRemovedIdsList.isNotEmpty) db.deleteBulk(shouldBeRemovedIdsList);

    db.close();

    final newFiles = _checkForNewVideosInCacheIsolate(params.cacheDirPath, validMap);
    newIdsMap.addAll(newFiles);

    return _VideoControllerIsolateResult(
      validMap: validMap,
      newIdsMap: newIdsMap,
      removedCount: shouldBeRemovedIdsList.length,
    );
  }

  static Map<String, List<(FileStat, String)>> _checkForNewVideosInCacheIsolate(String dirPath, Map<String, List<NamidaVideo>> idsMap) {
    final dir = Directory(dirPath);
    final newIdsMap = <String, List<(FileStat, String)>>{};

    final dirFiles = dir.listSyncSafe();
    for (int i = 0; i < dirFiles.length; i++) {
      var df = dirFiles[i];
      if (df is File) {
        final filename = df.path.getFilename;
        if (filename.endsWith('.part')) continue; // first thing first
        if (filename.endsWith('.mime')) continue; // second thing second
        if (filename.endsWith('.metadata')) continue; // second thing second

        try {
          final id = filename.substring(0, 11);
          final videosInMap = idsMap[id];
          final stats = df.statSync();
          final sizeInBytes = stats.size;
          if (videosInMap != null) {
            // if file exists in map and is valid
            if (videosInMap.firstWhereEff((element) => element.sizeInBytes == sizeInBytes) != null) {
              continue; // skipping since the map will contain only new entries
            }
          }
          // -- hmmm looks like a new video, needs extraction
          newIdsMap.addForce(id, (stats, df.path));
        } catch (e) {
          continue;
        }
      }
    }
    return newIdsMap;
  }
}

enum VideoFetchBlockedBy {
  cachePriority,
  noNetwork,
  dataSaver,
  playbackSource,
}

class _VideoControllerIsolateRequest {
  final String oldJsonFilePath;
  final DbWrapperFileInfo dbFileInfo;
  final String cacheDirPath;

  const _VideoControllerIsolateRequest({
    required this.oldJsonFilePath,
    required this.dbFileInfo,
    required this.cacheDirPath,
  });
}

class _VideoControllerIsolateResult {
  final Map<String, List<NamidaVideo>> validMap;
  final Map<String, List<(FileStat, String)>> newIdsMap;
  final int removedCount;

  const _VideoControllerIsolateResult({
    required this.validMap,
    required this.newIdsMap,
    required this.removedCount,
  });
}
