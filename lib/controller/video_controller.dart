// ignore_for_file: library_private_types_in_public_api, depend_on_referenced_packages

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Response;
import 'package:namida/core/functions.dart';
import 'package:newpipeextractor_dart/models/streams.dart';
import 'package:picture_in_picture/picture_in_picture.dart';
import 'package:queue/queue.dart';
import 'package:video_player/video_player.dart';

import 'package:namida/class/media_info.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/ffmpeg_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/video_widget.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';

class NamidaVideoWidget extends StatelessWidget {
  final bool enableControls;
  final VoidCallback? onMinimizeTap;
  final Widget? fallbackChild;
  final bool fullscreen;
  final bool isPip;
  final List<NamidaPopupItem> qualityItems;
  final bool zoomInToFullscreen;
  final bool swipeUpToFullscreen;

  const NamidaVideoWidget({
    super.key,
    required this.enableControls,
    this.onMinimizeTap,
    this.fallbackChild,
    this.fullscreen = false,
    this.qualityItems = const [],
    this.isPip = false,
    this.zoomInToFullscreen = true,
    this.swipeUpToFullscreen = false,
  });

  Future<void> _verifyAndEnterFullScreen() async {
    if (VideoController.inst.videoZoomAdditionalScale.value > 1.1) {
      await VideoController.inst.toggleFullScreenVideoView(
        fallbackChild: fallbackChild,
        qualityItems: qualityItems,
      );
    }

    // else if (videoZoomAdditionalScale.value < 0.7) {
    // NamidaNavigator.inst.exitFullScreen();
    // }

    _cancelZoom();
  }

  void _cancelZoom() {
    VideoController.inst.videoZoomAdditionalScale.value = 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerMove: !swipeUpToFullscreen
          ? null
          : (details) {
              final drag = details.delta.dy;
              if (VideoController.inst.videoZoomAdditionalScale.value >= 0) {
                VideoController.inst.videoZoomAdditionalScale.value -= drag * 0.02;
              }
            },
      onPointerUp: !swipeUpToFullscreen
          ? null
          : (details) async {
              if (NamidaNavigator.inst.isInFullScreen) return;
              await _verifyAndEnterFullScreen();
            },
      onPointerCancel: !swipeUpToFullscreen ? null : (event) => _cancelZoom(),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onScaleUpdate: !zoomInToFullscreen ? null : (details) => VideoController.inst.videoZoomAdditionalScale.value = details.scale,
        onScaleEnd: !zoomInToFullscreen
            ? null
            : (details) async {
                if (NamidaNavigator.inst.isInFullScreen) return;
                await _verifyAndEnterFullScreen();
              },
        child: Obx(
          () => NamidaVideoControls(
            widgetKey: fullscreen ? VideoController.inst.fullScreenControlskey : VideoController.inst.normalControlskey,
            onMinimizeTap: () {
              if (fullscreen) {
                NamidaNavigator.inst.exitFullScreen();
                VideoController.inst.fullScreenVideoWidget = null;
              } else {
                onMinimizeTap?.call();
              }
            },
            showControls: isPip
                ? false
                : fullscreen
                    ? true
                    : enableControls,
            fallbackChild: fallbackChild,
            isFullScreen: fullscreen,
            qualityItems: qualityItems,
            child: VideoController.vcontroller.videoWidget?.value,
          ),
        ),
      ),
    );
  }
}

class VideoController {
  static VideoController get inst => _instance;
  static final VideoController _instance = VideoController._internal();
  VideoController._internal() {
    _trimExcessImageCache();
  }

  /// Used mainly to determine wether to pause playback whenever video buffers or not.
  bool isCurrentlyInBackground = false;

  final videoZoomAdditionalScale = 0.0.obs;

  void updateShouldShowControls(double animationValue) {
    final isExpanded = animationValue == 1.0;
    if (isExpanded) {
      YoutubeController.inst.startDimTimer();
    } else {
      YoutubeController.inst.cancelDimTimer();
      normalControlskey.currentState?.setControlsVisibily(false);
    }
  }

  Future<void> toggleFullScreenVideoView({
    Widget? fallbackChild,
    List<NamidaPopupItem> qualityItems = const [],
  }) async {
    final aspect = VideoController.vcontroller.aspectRatio;
    VideoController.inst.fullScreenVideoWidget ??= Obx(
      () => NamidaVideoControls(
        widgetKey: VideoController.inst.fullScreenControlskey,
        onMinimizeTap: () {
          VideoController.inst.fullScreenVideoWidget = null;
          NamidaNavigator.inst.exitFullScreen();
        },
        showControls: true,
        fallbackChild: fallbackChild,
        isFullScreen: true,
        qualityItems: qualityItems,
        child: VideoController.vcontroller.videoWidget?.value,
      ),
    );
    await NamidaNavigator.inst.toggleFullScreen(
      VideoController.inst.fullScreenVideoWidget!,
      setOrientations: aspect == null ? true : aspect > 1,
      onWillPop: () async => VideoController.inst.fullScreenVideoWidget = null,
    );
  }

  // final videoControlsKeys = <String, GlobalKey<NamidaVideoControlsState>>{};

  final currentBrigthnessDim = 1.0.obs;

  final normalControlskey = GlobalKey<NamidaVideoControlsState>();
  final fullScreenControlskey = GlobalKey<NamidaVideoControlsState>();
  Widget? fullScreenVideoWidget;

  bool get shouldShowVideo => currentVideo.value != null && _videoController.isInitialized;
  int get localVideosTotalCount => _allVideoPaths.length;

  final localVideoExtractCurrent = Rxn<int>();
  final localVideoExtractTotal = 0.obs;

  final currentVideo = Rxn<NamidaVideo>();
  final currentPossibleVideos = <NamidaVideo>[].obs;
  final currentYTQualities = <VideoOnlyStream>[].obs;
  final currentDownloadedBytes = Rxn<int>();

  /// Indicates that [updateCurrentVideo] didn't find any matching video.
  final isNoVideosAvailable = false.obs;

  /// `path`: `NamidaVideo`
  final _videoPathsMap = <String, NamidaVideo>{};

  var _allVideoPaths = <String>{};

  /// `id`: `<NamidaVideo>[]`
  final _videoCacheIDMap = <String, List<NamidaVideo>>{};

  Iterable<NamidaVideo> get videosInCache sync* {
    for (final vids in _videoCacheIDMap.values) {
      yield* vids;
    }
  }

  Future<void> addYTVideoToCacheMap(String id, NamidaVideo nv) async {
    _videoCacheIDMap.addNoDuplicatesForce(id, nv);
    // well, no matter what happens, sometimes the info coming has extra info
    _videoCacheIDMap[id]?.removeDuplicates((element) => "${element.height}_${element.resolution}_${element.path}");
  }

  Future<void> addVideoFileToCacheMap(String id, File file) async {
    final mi = await NamidaFFMPEG.inst.extractMetadata(file.path);
    final nv = _getNVFromFFMPEGMap(
      mediaInfo: mi,
      ytID: id,
      path: file.path,
      stats: await file.stat(),
    );
    _videoCacheIDMap.addNoDuplicatesForce(id, nv);
  }

  bool doesVideoExistsInCache(String youtubeId) {
    _videoCacheIDMap.remove('');
    return _videoCacheIDMap[youtubeId]?.isNotEmpty ?? false;
  }

  List<NamidaVideo> getNVFromID(String youtubeId, {bool checkForFileIRT = true}) {
    _videoCacheIDMap.remove('');
    return _videoCacheIDMap[youtubeId]?.where((element) => File(element.path).existsSync()).toList() ?? [];
  }

  List<NamidaVideo> getCurrentVideosInCache() {
    final videos = <NamidaVideo>[];
    for (final vl in _videoCacheIDMap.values) {
      vl.loop((v, _) {
        if (File(v.path).existsSync()) {
          videos.add(v);
        }
      });
    }
    return videos;
  }

  static _NamidaVideoPlayer get vcontroller => inst._videoController;
  _NamidaVideoPlayer _videoController = _NamidaVideoPlayer.inst;

  bool _isInitializing = true;

  Future<void> updateCurrentVideo(Track track) async {
    isNoVideosAvailable.value = false;
    currentDownloadedBytes.value = null;
    currentVideo.value = null;
    currentYTQualities.clear();
    await vcontroller.dispose();
    if (_isInitializing) return;
    if (track == kDummyTrack) return;
    if (!settings.enableVideoPlayback.value) return;

    final possibleVideos = await _getPossibleVideosFromTrack(track);
    currentPossibleVideos.value = possibleVideos;

    final trackYTID = track.youtubeID;
    if (possibleVideos.isEmpty && trackYTID == '') isNoVideosAvailable.value = true;

    final vpsInSettings = settings.videoPlaybackSource.value;
    switch (vpsInSettings) {
      case VideoPlaybackSource.local:
        possibleVideos.retainWhere((element) => element.ytID != null); // leave all videos that doesnt have youtube id, i.e: local
        break;
      case VideoPlaybackSource.youtube:
        possibleVideos.retainWhere((element) => element.ytID == null); // leave all videos having youtube id
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
      erabaretaVideo = possibleVideos.firstWhereEff((element) => File(element.path).existsSync());
    }

    currentVideo.value = erabaretaVideo;

    if (erabaretaVideo == null && vpsInSettings != VideoPlaybackSource.local) {
      if (ConnectivityController.inst.hasConnection) {
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
      await getYoutubeThumbnailAndCache(id: id);
    }
  }

  Future<void> playVideoCurrent({
    required NamidaVideo? video,
    (String, String)? cacheIdAndPath,
    required Track track,
    bool mute = true,
  }) async {
    assert(video != null || cacheIdAndPath != null);

    await _executeForCurrentTrackOnly(track, () async {
      const allowance = 5; // seconds
      final v = cacheIdAndPath != null ? _videoCacheIDMap[cacheIdAndPath.$1]?.firstWhereEff((e) => e.path == cacheIdAndPath.$2) : video;
      if (v != null) {
        await _videoController.setFile(v.path,
            (videoDuration) => videoDuration.inSeconds > allowance && videoDuration.inSeconds < track.duration - allowance); // loop only if video duration is less than audio.
      }
      currentVideo.value = v;
      final volume = mute ? 0.0 : settings.playerVolume.value;
      await vcontroller.waitTillBufferingComplete;
      await Future.wait([
        _videoController.setVolume(volume),
        Player.inst.toggleVideoPlay(),
      ]);
      await Player.inst.refreshVideoSeekPosition();

      settings.wakelockMode.value.toggleOn(shouldShowVideo);
    });
  }

  Future<void> toggleVideoPlayback() async {
    final currentValue = settings.enableVideoPlayback.value;
    settings.save(enableVideoPlayback: !currentValue);

    // only modify if not playing yt/local video, since [enableVideoPlayback] is
    // limited to local music.
    if (Player.inst.currentQueue.isEmpty) return;

    if (currentValue) {
      // should close/hide
      currentVideo.value = null;
      _videoController.dispose();
      YoutubeController.inst.dispose();
    } else {
      _videoController = _NamidaVideoPlayer.inst;
      await updateCurrentVideo(Player.inst.nowPlayingTrack);
    }
  }

  Timer? _downloadTimer;
  void _downloadTimerCancel() {
    _downloadTimer?.cancel();
    _downloadTimer = null;
  }

  FutureOr<void> _executeForCurrentTrackOnly(Track initialTrack, FutureOr<void> Function() execute) async {
    if (initialTrack.path != Player.inst.nowPlayingTrack.path) return;
    try {
      await execute();
    } catch (e) {
      printy(e, isError: true);
    }
  }

  Future<void> fetchYTQualities(Track track) async {
    final available = await YoutubeController.inst.getAvailableVideoStreamsOnly(track.youtubeID);
    _executeForCurrentTrackOnly(track, () {
      currentYTQualities.clear();
      currentYTQualities.addAll(available);
    });
  }

  Future<NamidaVideo?> getVideoFromYoutubeAndUpdate(
    String? id, {
    VideoStream? stream,
  }) async {
    final tr = Player.inst.nowPlayingTrack;
    final dv = await fetchVideoFromYoutube(id, stream: stream);
    _executeForCurrentTrackOnly(tr, () {
      currentVideo.value = dv;
      currentYTQualities.refresh();
      if (dv != null) currentPossibleVideos.addNoDuplicates(dv);
      currentPossibleVideos.sortByReverseAlt(
        (e) {
          if (e.resolution != 0) return e.resolution;
          if (e.height != 0) return e.height;
          return 0;
        },
        (e) => e.frameratePrecise,
      );
    });
    return dv;
  }

  Future<NamidaVideo?> fetchVideoFromYoutube(
    String? id, {
    VideoStream? stream,
  }) async {
    if (id == null || id == '') return null;

    int downloaded = 0;
    _downloadTimerCancel();
    void updateCurrentBytes() {
      currentDownloadedBytes.value = downloaded == 0 ? null : downloaded;
      printy('Video Download: ${currentDownloadedBytes.value?.fileSizeFormatted}');
    }

    _downloadTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      updateCurrentBytes();
    });

    final initialTrack = Player.inst.nowPlayingTrack;
    void updateValuesCT(void Function() execute) => _executeForCurrentTrackOnly(initialTrack, execute);

    final downloadedVideo = await YoutubeController.inst.downloadYoutubeVideo(
      id: id,
      stream: stream,
      onAvailableQualities: (availableStreams) {},
      onChoosingQuality: (choosenStream) {
        updateValuesCT(() {
          currentVideo.value = NamidaVideo(
            path: '',
            ytID: id,
            height: choosenStream.height ?? 0,
            width: choosenStream.width ?? 0,
            sizeInBytes: choosenStream.sizeInBytes ?? 0,
            frameratePrecise: choosenStream.fps?.toDouble() ?? 0.0,
            creationTimeMS: 0,
            durationMS: choosenStream.durationMS ?? 0,
            bitrate: choosenStream.bitrate ?? 0,
          );
        });
      },
      onInitialFileSize: (initialFileSize) {
        updateValuesCT(() {
          downloaded = initialFileSize;
          currentDownloadedBytes.value = initialFileSize;
        });
      },
      downloadingStream: (downloadedBytes) {
        updateValuesCT(() {
          downloaded += downloadedBytes.length;
        });
      },
    );
    updateCurrentBytes();
    if (downloadedVideo != null) {
      _videoCacheIDMap.addNoDuplicatesForce(downloadedVideo.ytID ?? '', downloadedVideo);
      await _saveCachedVideosFile();
    }
    currentDownloadedBytes.value = null;
    _downloadTimerCancel();
    return downloadedVideo;
  }

  List<String> _getPossibleVideosPathsFromAudioFile(String path) {
    final possibleLocal = <String>[];
    final trExt = path.toTrackExt();

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

      default:
        null;
    }
    return possibleLocal;
  }

  Future<List<NamidaVideo>> _getPossibleVideosFromTrack(Track track) async {
    final link = track.youtubeLink;
    final id = link.getYoutubeID;

    final possibleCached = getNVFromID(id);
    possibleCached.sortByReverseAlt(
      (e) => e.resolution,
      (e) => e.frameratePrecise,
    );

    final videosFile = File(AppPaths.VIDEOS_LOCAL);
    final local = _getPossibleVideosPathsFromAudioFile(track.path);
    final possibleLocal = <NamidaVideo>[];
    for (final l in local) {
      NamidaVideo? nv = _videoPathsMap[l];
      if (nv == null) {
        try {
          final v = await NamidaFFMPEG.inst.extractMetadata(l);
          if (v != null) {
            _saveThumbnailToStorage(
              videoPath: l,
              bytes: null,
              isLocal: true,
              idOrFileNameWOExt: l.getFilenameWOExt,
              isExtracted: true,
            );
            final stats = await File(l).stat();
            final vid = _getNVFromFFMPEGMap(
              path: l,
              mediaInfo: v,
              stats: stats,
              ytID: null,
            );
            // -- saving extracted info before continuing.
            _videoPathsMap[l] = vid;
            await videosFile.writeAsJson(_videoPathsMap.values.map((e) => e.toJson()).toList());
            nv = vid;
          }
        } catch (e) {
          printy(e, isError: true);
          continue;
        }
      }
      if (nv != null) possibleLocal.add(nv);
    }
    return [...possibleCached, ...possibleLocal];
  }

  bool _checkFileNameAudioVideo(String videoFileName, String audioFileName) {
    return videoFileName.cleanUpForComparison.contains(audioFileName.cleanUpForComparison) || videoFileName.contains(audioFileName);
  }

  Future<void> initialize() async {
    // -- Fetching Cached Videos Info.
    final file = File(AppPaths.VIDEOS_CACHE);
    final cacheVideosInfoFile = await file.readAsJson() as List?;
    final vl = cacheVideosInfoFile?.mapped((e) => NamidaVideo.fromJson(e));
    _videoCacheIDMap.clear();
    vl?.loop((e, index) => _videoCacheIDMap.addForce(e.ytID ?? '', e));

    Future<void> fetchCachedVideos() async {
      final cachedVideos = await _checkIfVideosInMapValid(_videoCacheIDMap);
      printy('videos cached: ${cachedVideos.length}');
      _videoCacheIDMap.clear();
      cachedVideos.entries.toList().loop((videoEntry, _) {
        videoEntry.value.loop((e, _) {
          _videoCacheIDMap.addForce(videoEntry.key, e);
        });
      });

      final newCachedVideos = await _checkForNewVideosInCache(cachedVideos);
      printy('videos cached new: ${newCachedVideos.length}');
      newCachedVideos.entries.toList().loop((videoEntry, _) {
        videoEntry.value.loop((e, _) {
          _videoCacheIDMap.addForce(videoEntry.key, e);
        });
      });

      // -- saving files
      await _saveCachedVideosFile();
    }

    await Future.wait([
      fetchCachedVideos(), // --> should think about a way to flank around scanning lots of cache videos if info not found (ex: after backup)
      scanLocalVideos(fillPathsOnly: true, extractIfFileNotFound: false), // this will get paths only and disables extracting whole local videos on startup
    ]);
    _isInitializing = false;
    await updateCurrentVideo(Player.inst.nowPlayingTrack);
  }

  Future<void> scanLocalVideos({
    bool strictNoMedia = true,
    bool forceReScan = false,
    bool extractIfFileNotFound = false,
    required bool fillPathsOnly,
  }) async {
    if (fillPathsOnly) {
      localVideoExtractCurrent.value = 0;
      final videos = await _fetchVideoPathsFromStorage(strictNoMedia: strictNoMedia, forceReCheckDir: forceReScan);
      _allVideoPaths = videos;
      localVideoExtractCurrent.value = null;
      return;
    }

    void resetCounters() {
      localVideoExtractCurrent.value = 0;
      localVideoExtractTotal.value = 0;
    }

    resetCounters();
    final localVideos = await _getLocalVideos(
      strictNoMedia: strictNoMedia,
      forceReScan: forceReScan,
      extractIfFileNotFound: extractIfFileNotFound,
      onProgress: (didExtract, total) {
        if (didExtract) localVideoExtractCurrent.value = (localVideoExtractCurrent.value ?? 0) + 1;
        localVideoExtractTotal.value = total;
      },
    );
    printy('videos local: ${localVideos.length}');
    localVideos.loop((e, index) {
      _videoPathsMap[e.path] = e;
    });
    resetCounters();
    localVideoExtractCurrent.value = null;
  }

  Future<bool> _saveCachedVideosFile() async {
    final file = File(AppPaths.VIDEOS_CACHE);
    final mapValuesTotal = <Map<String, dynamic>>[];
    _videoCacheIDMap.values.toList().loop((e, index) {
      mapValuesTotal.addAll(e.map((e) => e.toJson()));
    });
    final resultFile = await file.writeAsJson(mapValuesTotal);
    return resultFile != null;
  }

  /// - Loops the map sent, makes sure that everything exists & valid.
  /// - Detects: `deleted` & `needs-to-be-updated` files
  /// - DOES NOT handle: `new files`.
  /// - Returns a copy of the map but with valid videos only.
  Future<Map<String, List<NamidaVideo>>> _checkIfVideosInMapValid(Map<String, List<NamidaVideo>> idsMap) async {
    final res = await _checkIfVideosInMapValidIsolate.thready(idsMap);

    final validMap = res['validMap'] as Map<String, List<NamidaVideo>>;
    final shouldBeReExtracted = res['newIdsMap'] as Map<String, List<(FileStat, String)>>;

    for (final newId in shouldBeReExtracted.entries) {
      for (final statAndPath in newId.value) {
        final nv = await _extractNVFromFFMPEG(
          stats: statAndPath.$1,
          id: newId.key,
          path: statAndPath.$2,
        );
        validMap.addForce(newId.key, nv);
      }
    }

    return validMap;
  }

  static Future<Map> _checkIfVideosInMapValidIsolate(Map<String, List<NamidaVideo>> idsMap) async {
    final validMap = <String, List<NamidaVideo>>{};
    final newIdsMap = <String, List<(FileStat, String)>>{};

    final videosInMap = idsMap.entries.toList();

    videosInMap.loop((ve, _) {
      final id = ve.key;
      final vl = ve.value;
      vl.loop((v, _) {
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
        }

        // else {
        // -- File doesnt exist, ie. has been removed
        // }
      });
    });
    return {
      "validMap": validMap,
      "newIdsMap": newIdsMap,
    };
  }

  /// - Loops the currently existing files
  /// - Detects: `new files`.
  /// - DOES NOT handle: `deleted` & `needs-to-be-updated` files.
  /// - Returns a map with **new videos only**.
  /// - **New**: excludes files ending with `.download`
  Future<Map<String, List<NamidaVideo>>> _checkForNewVideosInCache(Map<String, List<NamidaVideo>> idsMap) async {
    final newIds = await _checkForNewVideosInCacheIsolate.thready({
      'dirPath': AppDirs.VIDEOS_CACHE,
      'idsMap': idsMap,
    });

    final newIdsMap = <String, List<NamidaVideo>>{};

    for (final newId in newIds.entries) {
      for (final statAndPath in newId.value) {
        final nv = await _extractNVFromFFMPEG(
          stats: statAndPath.$1,
          id: newId.key,
          path: statAndPath.$2,
        );
        newIdsMap.addForce(newId.key, nv);
      }
    }

    return newIdsMap;
  }

  static Future<Map<String, List<(FileStat, String)>>> _checkForNewVideosInCacheIsolate(Map params) async {
    final dirPath = params['dirPath'] as String;
    final idsMap = params['idsMap'] as Map<String, List<NamidaVideo>>;
    final dir = Directory(dirPath);
    final newIdsMap = <String, List<(FileStat, String)>>{};

    for (final df in dir.listSyncSafe()) {
      if (df is File) {
        final filename = df.path.getFilename;
        if (filename.endsWith('.download')) continue; // first thing first

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
        try {
          newIdsMap.addForce(id, (stats, df.path));
        } catch (e) {
          continue;
        }
      }
    }
    return newIdsMap;
  }

  Future<List<NamidaVideo>> _getLocalVideos({
    bool strictNoMedia = true,
    bool forceReScan = false,
    bool extractIfFileNotFound = true,
    required void Function(bool didExtract, int total) onProgress,
  }) async {
    final videosFile = File(AppPaths.VIDEOS_LOCAL);
    final namidaVideos = <NamidaVideo>[];

    if (await videosFile.existsAndValid() && !forceReScan) {
      final videosJson = await videosFile.readAsJson() as List?;
      final vl = videosJson?.map((e) => NamidaVideo.fromJson(e)) ?? [];
      namidaVideos.addAll(vl);
    } else {
      if (!extractIfFileNotFound) return [];
      final videos = await _fetchVideoPathsFromStorage(strictNoMedia: strictNoMedia, forceReCheckDir: forceReScan);

      for (final path in videos) {
        try {
          final v = await NamidaFFMPEG.inst.extractMetadata(path);
          if (v != null) {
            _saveThumbnailToStorage(
              videoPath: path,
              bytes: null,
              isLocal: true,
              idOrFileNameWOExt: path.getFilenameWOExt,
              isExtracted: true,
            );
            final stats = await File(path).stat();
            final nv = _getNVFromFFMPEGMap(
              path: path,
              mediaInfo: v,
              stats: stats,
              ytID: null,
            );
            namidaVideos.add(nv);
          }
        } catch (e) {
          printy(e, isError: true);
          continue;
        }

        onProgress(true, videos.length);
      }
      await videosFile.writeAsJson(namidaVideos.mapped((e) => e.toJson()));
    }

    return namidaVideos;
  }

  Future<NamidaVideo> _extractNVFromFFMPEG({
    required FileStat stats,
    required String? id,
    required String path,
  }) async {
    _saveThumbnailToStorage(
      bytes: null,
      videoPath: path,
      isLocal: id == null,
      idOrFileNameWOExt: id ?? path.getFilenameWOExt,
      isExtracted: true,
    );
    final info = await NamidaFFMPEG.inst.extractMetadata(path);
    return _getNVFromFFMPEGMap(
      mediaInfo: info,
      stats: stats,
      ytID: id,
      path: path,
    );
  }

  void closeThumbnailClients(List<String?> links) {
    links.loop((link, _) {
      _runningRequestsClients[link]?.close(force: true);
      _runningRequestsClients.remove(link);
    });
  }

  /// This prevents re-requesting the same url.
  static final _runningRequestsClients = <String, Dio>{};
  static final _runningRequestsMap = <String, Completer<Uint8List?>?>{};

  final _thumbQueue = Queue(parallel: 4);
  Future<Uint8List?> getYoutubeThumbnailAsBytes({
    String? youtubeId,
    String? url,
    bool lowerResYTID = false,
    required bool keepInMemory,
  }) async {
    if (youtubeId == null && url == null) return null;

    final links = url != null
        ? [url]
        : lowerResYTID
            ? [YTThumbnail(youtubeId!).mqdefault]
            : YTThumbnail(youtubeId!).allQualitiesByHighest;

    for (final link in links) {
      if (_runningRequestsMap[link] != null) {
        printy('getYoutubeThumbnailAsBytes: Same link is being requested right now, ignoring');
        return await _runningRequestsMap[link]!.future; // return and not continue, cuz if requesting hq image, continue will make it request lower one
      }

      _runningRequestsClients[link] = Dio();
      (Uint8List, int)? requestRes;

      // _runningRequestsMap.optimizedAdd([MapEntry(link, Completer<Uint8List?>())], 600); // most images are <~20kb so =12MB
      _runningRequestsMap[link] ??= Completer<Uint8List?>(); // 600 - most images are <~20kb so =12MB

      await _thumbQueue.add(() async {
        try {
          final client = _runningRequestsClients[link];
          if (client != null) {
            final res = await client.get<Uint8List?>(
              link,
              options: Options(responseType: ResponseType.bytes, validateStatus: (status) => true),
            );
            requestRes = (res.data ?? Uint8List.fromList([]), res.statusCode ?? 404);
          }
        } catch (e) {
          printy('getYoutubeThumbnailAsBytes: Error getting thumbnail at $link, trying again with lower quality.\n$e', isError: true);
        }
      });

      // -- validation --
      final req = requestRes;
      if (req != null) {
        final data = req.$1;
        if (data.isNotEmpty && req.$2 != 404) {
          _runningRequestsMap[link]?.completeIfWasnt(data);
          if (!keepInMemory) _runningRequestsMap.remove(link);
          closeThumbnailClients([link]);
          return data;
        } else {
          _runningRequestsMap[link]?.completeIfWasnt(null);
          _runningRequestsMap.remove(link); // removing since it failed
          closeThumbnailClients([link]);
          continue;
        }
      }
    }
    return null;
  }

  // static Future<(Uint8List, int)> _httpGetIsolate(String link) async {
  //   final requestRes = await http.get(Uri.parse(link));
  //   return (requestRes.bodyBytes, requestRes.statusCode);
  // }

  Future<void> _trimExcessImageCache() async {
    final totalMaxBytes = settings.imagesMaxCacheInMB.value * 1024 * 1024;
    final paramters = {
      'maxBytes': totalMaxBytes,
      'dirPath': AppDirs.YT_THUMBNAILS,
      'dirPathChannel': AppDirs.YT_THUMBNAILS_CHANNELS,
    };
    await _trimExcessImageCacheIsolate.thready(paramters);
  }

  /// Returns total deleted bytes.
  static Future<int> _trimExcessImageCacheIsolate(Map map) async {
    final maxBytes = map['maxBytes'] as int;
    final dirPath = map['dirPath'] as String;
    final dirPathChannel = map['dirPathChannel'] as String;

    int totalDeletedBytes = 0;

    final imagesVideos = Directory(dirPath).listSyncSafe();
    final imagesChannels = Directory(dirPathChannel).listSyncSafe();
    final images = [...imagesVideos, ...imagesChannels];

    images.sortBy((e) => e.statSync().accessed);
    int totalBytes = images.fold(0, (previousValue, element) => previousValue + element.statSync().size);

    // -- deleting
    for (final image in images) {
      if (totalBytes <= maxBytes) break; // better than checking with each loop
      final deletedSize = image.statSync().size;
      try {
        image.deleteSync();
        totalBytes -= deletedSize;
        totalDeletedBytes += deletedSize;
      } catch (_) {}
    }

    return totalDeletedBytes;
  }

  Future<File?> getYoutubeThumbnailAndCache({
    String? id,
    String? channelUrl,
    bool isImportantInCache = true,
    FutureOr<void> Function()? beforeFetchingFromInternet,
  }) async {
    if (id == null && channelUrl == null) return null;

    void trySavingLastAccessed(File? file) {
      final time = isImportantInCache ? DateTime.now() : DateTime(1970);
      file?.setLastAccessed(time);
    }

    final file = id != null ? File("${AppDirs.YT_THUMBNAILS}$id.png") : File("${AppDirs.YT_THUMBNAILS_CHANNELS}${channelUrl?.split('/').last}.png");
    if (file.existsSync()) {
      printy('Downloading Thumbnail Already Exists');
      trySavingLastAccessed(file);
      return file;
    }

    printy('Downloading Thumbnail Started');
    await beforeFetchingFromInternet?.call();

    final bytes = await getYoutubeThumbnailAsBytes(youtubeId: id, url: channelUrl, keepInMemory: false);
    printy('Downloading Thumbnail Finished with ${bytes?.length} bytes');

    final savedFile = (id != null
            ? _saveThumbnailToStorage(
                videoPath: null,
                bytes: bytes,
                isLocal: false,
                idOrFileNameWOExt: id,
                isExtracted: false,
              )
            : _saveChannelThumbnailToStorage(
                file: file,
                bytes: bytes,
              ))
        .then((savedFile) {
      trySavingLastAccessed(savedFile);
    });

    return savedFile;
  }

  File? getYoutubeThumbnailFromCacheSync({String? id, String? channelUrl}) {
    if (id == null && channelUrl == null) return null;

    final file = id != null ? File("${AppDirs.YT_THUMBNAILS}$id.png") : File("${AppDirs.YT_THUMBNAILS_CHANNELS}${channelUrl?.split('/').last}.png");
    if (file.existsSync()) {
      return file;
    }
    return null;
  }

  Future<File?> _saveChannelThumbnailToStorage({
    required File file,
    required Uint8List? bytes,
  }) async {
    if (bytes != null) await file.writeAsBytes(bytes);
    return file;
  }

  Future<File?> _saveThumbnailToStorage({
    required Uint8List? bytes,
    required String? videoPath,
    required bool isLocal,
    required String idOrFileNameWOExt,
    required bool isExtracted, // set to false if its a youtube thumbnail.
  }) async {
    if (bytes == null && videoPath == null) return null;

    final prefix = !isLocal && isExtracted ? 'EXT_' : '';
    final dir = isLocal ? AppDirs.THUMBNAILS : AppDirs.YT_THUMBNAILS;
    final file = File("$dir$prefix$idOrFileNameWOExt.png");
    if (bytes != null) {
      // if pure yt thumbnail delete the extracted version
      if (!isExtracted) {
        await File("${AppDirs.YT_THUMBNAILS}EXT_$idOrFileNameWOExt.png").deleteIfExists();
      }
      return await file.writeAsBytes(bytes);
    } else if (videoPath != null) {
      await NamidaFFMPEG.inst.extractVideoThumbnail(videoPath: videoPath, thumbnailSavePath: file.path);
      final fileExists = await file.exists();
      return fileExists ? file : null;
    }
    return null;
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
      nameInCache: ytID != null ? path.getFilenameWOExt : null,
      height: videoStream?.height ?? 0,
      width: videoStream?.width ?? 0,
      sizeInBytes: stats.size,
      creationTimeMS: stats.creationDate.millisecondsSinceEpoch,
      frameratePrecise: frameratePrecise ?? 0.0,
      durationMS: videoStream?.duration?.inMilliseconds ?? mediaInfo?.format?.duration?.inMilliseconds ?? 0,
      bitrate: int.tryParse(videoStream?.bitRate ?? '') ?? 0,
    );
  }

  Future<Set<String>> _fetchVideoPathsFromStorage({bool strictNoMedia = true, bool forceReCheckDir = false}) async {
    final allAvailableDirectories = await Indexer.inst.getAvailableDirectories(forceReCheck: forceReCheckDir, strictNoMedia: strictNoMedia);

    final parameters = {
      'allAvailableDirectories': allAvailableDirectories,
      'directoriesToExclude': settings.directoriesToExclude.toList(),
      'extensions': kVideoFilesExtensions,
    };

    final mapResult = await getFilesTypeIsolate.thready(parameters);

    final allVideoPaths = mapResult['allPaths'] as Set<String>;
    // final excludedByNoMedia = mapResult['pathsExcludedByNoMedia'] as Set<String>;
    return allVideoPaths;
  }
}

class _NamidaVideoPlayer {
  static _NamidaVideoPlayer get inst => _instance;
  static final _NamidaVideoPlayer _instance = _NamidaVideoPlayer._internal();
  _NamidaVideoPlayer._internal() {
    PictureInPicture.onPipChanged = (isInPip) {
      _isInPip.value = isInPip;
      if (isInPip) {
        NamidaNavigator.inst.closeAllDialogs();
        NamidaNavigator.inst.popAllMenus();
      }
    };
  }

  Rxn<Widget>? get videoWidget => _videoWidget;
  VideoPlayerController? get videoController => _videoController;
  bool get isInitialized => _initializedVideo.value;
  bool get isBuffering => _isBuffering.value;
  Duration? get buffered => _buffered.value;
  bool get isCurrentVideoFromCache => _isCurrentVideoFromCache.value;
  double? get aspectRatio => _aspectRatio.value;
  Future<bool>? get waitTillBufferingComplete => _bufferingCompleter?.future;
  bool get isInPip => _isInPip.value;

  final _initializedVideo = false.obs;
  final _isBuffering = true.obs;
  final _buffered = Rxn<Duration>();
  final _aspectRatio = Rxn<double>();
  final _isCurrentVideoFromCache = false.obs;
  Completer<bool>? _bufferingCompleter;
  final _isInPip = false.obs;

  VideoPlayerController? _videoController;
  final _videoWidget = Rxn<Widget>();

  void _updateWidget(VideoPlayerController controller) {
    _videoWidget.value = null;
    _videoWidget.value = VideoPlayer(controller);
  }

  BufferOptions get _defaultBufferOptions => const BufferOptions(
        minBuffer: Duration(minutes: 1),
        maxBuffer: Duration(minutes: 3),
      );

  ByteSize get _defaultMaxCache => ByteSize(mb: settings.videosMaxCacheInMB.value);
  Directory get _defaultCacheDirectory => Directory(AppDirs.VIDEOS_CACHE);

  Future<void> setNetworkSource({
    required String url,
    required bool Function(Duration videoDuration) looping,
    required String? cacheKey,
  }) async {
    _initializedVideo.value = false;
    await _execute(() async {
      await dispose();

      await _initializeController(
        VideoPlayerController.networkUrl(
          Uri.parse(url),
          cacheKey: cacheKey,
          enableCaching: true,
          maxTotalCacheSize: _defaultMaxCache,
          cacheDirectory: _defaultCacheDirectory,
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: true,
            allowBackgroundPlayback: true,
          ),
          bufferOptions: _defaultBufferOptions,
        ),
      );
      _isCurrentVideoFromCache.value = false;
      _updateWidget(_videoController!);
      _initializedVideo.value = true;
      _videoController?.setLooping(looping(_videoController?.value.duration ?? Duration.zero));
    });
  }

  Future<void> setFile(String path, bool Function(Duration videoDuration) looping) async {
    _initializedVideo.value = false;
    await _execute(() async {
      await dispose();
      await _initializeController(
        VideoPlayerController.file(
          File(path),
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: true,
            allowBackgroundPlayback: true,
          ),
          bufferOptions: _defaultBufferOptions,
        ),
      );
      _isCurrentVideoFromCache.value = true;
      _updateWidget(_videoController!);
      _initializedVideo.value = true;
      _videoController?.setLooping(looping(_videoController?.value.duration ?? Duration.zero));
    });

    try {
      File(path).setLastAccessedSync(DateTime.now());
    } catch (e) {
      printy(e, isError: true);
    }
  }

  Future<void> _execute(FutureOr<void> Function() fun) async {
    try {
      await fun();
    } catch (e) {
      printy(e, isError: true);
    }
  }

  Future<void> togglePlayPause(bool play) async => play ? await this.play() : await pause();

  Future<void> play() async => await _execute(() async => await _videoController?.play());

  Future<void> pause() async => await _execute(() async => await _videoController?.pause());

  Future<void> seek(Duration duration) async => await _execute(() async {
        final wasPlaying = _videoController?.value.isPlaying ?? false;
        await _videoController?.seekTo(duration);
        if (!wasPlaying) {
          await _videoController?.pause();
        }
      });

  Future<void> setVolume(double volume) async => await _execute(() async => await _videoController?.setVolume(volume));

  Future<void> setSpeed(double volume) async => await _execute(() async => await _videoController?.setPlaybackSpeed(volume));

  Future<bool> enablePictureInPicture({bool updateRatioOnly = false}) async {
    VideoController.inst.normalControlskey.currentState?.setControlsVisibily(false);
    VideoController.inst.fullScreenControlskey.currentState?.setControlsVisibily(false);
    final size = _videoController?.value.size;
    final w = size?.width.toInt();
    final h = size?.height.toInt();
    if (updateRatioOnly) {
      return await PictureInPicture.setAspectRatio(width: w, height: h);
    } else {
      // final videoCtx = VideoController.inst.normalControlskey.currentContext ?? VideoController.inst.fullScreenControlskey.currentContext;
      // final rect = videoCtx?.globalPaintBounds;
      return await PictureInPicture.enterPip(width: w, height: h /*, rectHint: rect */);
    }
  }

  Future<void> _initializeController(VideoPlayerController c) async {
    _videoController?.removeListener(_updateBufferingStatus);
    _videoController = c;
    await _videoController!.initialize();
    _aspectRatio.value = _videoController?.value.aspectRatio;
    _videoController?.addListener(_updateBufferingStatus);
    if (isInPip) enablePictureInPicture(updateRatioOnly: true); // rebuild aspect ratio
  }

  bool _didPauseInternally = false;
  Future<void> _updateBufferingStatus() async {
    _buffered.value = _videoController?.value.buffered.lastOrNull?.end;
    _isBuffering.value = _videoController?.value.isBuffering ?? false;

    if (_isBuffering.value) {
      _bufferingCompleter?.completeIfWasnt(false);
      _bufferingCompleter = null;
      _bufferingCompleter = Completer<bool>();
      if (!VideoController.inst.isCurrentlyInBackground && Player.inst.isPlaying && Player.inst.shouldCareAboutAVSync) {
        _didPauseInternally = true;
        await Player.inst.pauseRaw();
      }
    } else {
      if (_didPauseInternally && Player.inst.shouldCareAboutAVSync) {
        _didPauseInternally = false;
        await Player.inst.playRaw();
      }
      _bufferingCompleter?.completeIfWasnt(false);
    }
  }

  Future<void> dispose() async {
    await _execute(() async {
      _videoWidget.value = null;
      _aspectRatio.value = null;
      _isBuffering.value = false;
      _buffered.value = null;
      _bufferingCompleter?.completeIfWasnt(false);
      _isCurrentVideoFromCache.value = false;
      await _videoController?.dispose();

      _videoController = null;
      _initializedVideo.value = false;
    });
  }
}

extension _GlobalPaintBounds on BuildContext {
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
