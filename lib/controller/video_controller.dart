// ignore_for_file: library_private_types_in_public_api, depend_on_referenced_packages

import 'dart:async';
import 'dart:io';

import 'package:cached_video_player/cached_video_player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;
import 'package:http/http.dart' as http;
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:newpipeextractor_dart/models/streams.dart';
import 'package:picture_in_picture/picture_in_picture.dart';

import 'package:namida/class/media_info.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/ffmpeg_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/ui/widgets/video_widget.dart';

class VideoController {
  static VideoController get inst => _instance;
  static final VideoController _instance = VideoController._internal();
  VideoController._internal();

  /// Used mainly to determine wether to pause playback whenever video buffers or not.
  bool isCurrentlyInBackground = false;

  final videoZoomAdditionalScale = 0.0.obs;

  void updateShouldShowControls(double value) {
    final shouldShowControls = value == 1.0;
    if (!shouldShowControls) {
      for (final c in _videoControlsKeys.values) {
        c.currentState?.setControlsVisibily(false);
      }
    }
  }

  final _videoControlsKeys = <String, GlobalKey<NamidaVideoControlsState>>{};

  Widget? videoWidget;
  String? _lastKey;

  Widget getVideoWidget(
    String? key,
    bool enableControls,
    VoidCallback? onMinimizeTap, {
    Widget? fallbackChild,
    bool fullscreen = false,
    List<NamidaPopupItem> qualityItems = const [],
  }) {
    final finalKey = 'video_widget$key$enableControls';
    _videoControlsKeys[finalKey] ??= GlobalKey<NamidaVideoControlsState>();
    if (videoWidget == null || _lastKey != finalKey) {
      _lastKey = finalKey;
      videoWidget = GestureDetector(
        key: Key(finalKey),
        behavior: HitTestBehavior.opaque,
        onScaleUpdate: (details) {
          videoZoomAdditionalScale.value = details.scale;
        },
        onScaleEnd: (details) {
          if (videoZoomAdditionalScale.value > 1.1) {
            NamidaNavigator.inst.enterFullScreen(
              getVideoWidget(
                finalKey,
                true,
                onMinimizeTap,
                fullscreen: true,
                fallbackChild: fallbackChild,
                qualityItems: qualityItems,
              ),
            );
          }
        },
        child: Obx(
          () => AspectRatio(
            aspectRatio: aspectRatio,
            child: NamidaVideoControls(
              key: _videoControlsKeys[finalKey],
              onMinimizeTap: onMinimizeTap,
              showControls: enableControls,
              controller: playerController,
              fallbackChild: fallbackChild,
              isFullScreen: fullscreen,
              qualityItems: qualityItems,
              child: vcontroller.videoWidget?.value,
            ),
          ),
        ),
      );
    }

    return videoWidget!;
  }

  bool get shouldShowVideo => currentVideo.value != null && _videoController.isInitialized;

  double get aspectRatio => _videoController.aspectRatio;

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

  /// `id`: `<NamidaVideo>[]`
  final _videoCacheIDMap = <String, List<NamidaVideo>>{};

  List<NamidaVideo> get videosInCache => _videoCacheIDMap.values.reduce((value, element) => [...value, ...element]);
  bool doesVideoExistsInCache(String youtubeId) => _videoCacheIDMap[youtubeId]?.isNotEmpty ?? false;

  List<NamidaVideo> getNVFromID(String youtubeId) => _videoCacheIDMap[youtubeId] ?? [];
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

  CachedVideoPlayerController? get playerController => _videoController.videoController;
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

    final possibleVideos = _getPossibleVideosFromTrack(track);
    currentPossibleVideos
      ..clear()
      ..addAll(possibleVideos);

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
          if (e.width != 0) return e.width;
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
      await Future.wait([
        _videoController.setVolume(volume),
        Player.inst.updateVideoPlayingState(),
        Player.inst.refreshVideoSeekPosition(),
      ]);
    });
  }

  Future<void> toggleVideoPlayback() async {
    final currentValue = settings.enableVideoPlayback.value;
    settings.save(enableVideoPlayback: !currentValue);

    // only modify if not playing yt video, since [enableVideoPlayback] is
    // limited to local music.
    if (Player.inst.currentQueueYoutube.isNotEmpty) return;

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
          if (e.width != 0) return e.width;
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

  List<NamidaVideo> _getPossibleVideosFromTrack(Track track) {
    final link = track.youtubeLink;
    final id = link.getYoutubeID;

    final possibleCached = _videoCacheIDMap[id] ?? [];
    possibleCached.sortByReverseAlt(
      (e) => e.width,
      (e) => e.frameratePrecise,
    );

    final possibleLocal = <NamidaVideo>[];
    final trExt = track.toTrackExt();

    final valInSett = settings.localVideoMatchingType.value;
    final shouldCheckSameDir = settings.localVideoMatchingCheckSameDir.value;

    void matchFileName(String videoName, MapEntry<String, NamidaVideo> vf, bool ensureSameDir) {
      if (ensureSameDir) {
        if (vf.key.getDirectoryPath != track.path.getDirectoryPath) return;
      }

      final videoNameContainsMusicFileName = _checkFileNameAudioVideo(videoName, track.filenameWOExt);
      if (videoNameContainsMusicFileName) possibleLocal.add(vf.value);
    }

    void matchTitleAndArtist(String videoName, MapEntry<String, NamidaVideo> vf, bool ensureSameDir) {
      if (ensureSameDir) {
        if (vf.key.getDirectoryPath != track.path.getDirectoryPath) return;
      }
      final videoContainsTitle = videoName.contains(trExt.title.cleanUpForComparison);
      final videoNameContainsTitleAndArtist = videoContainsTitle && trExt.artistsList.isNotEmpty && videoName.contains(trExt.artistsList.first.cleanUpForComparison);
      // useful for [Nightcore - title]
      // track must contain Nightcore as the first Genre
      final videoNameContainsTitleAndGenre = videoContainsTitle && trExt.genresList.isNotEmpty && videoName.contains(trExt.genresList.first.cleanUpForComparison);
      if (videoNameContainsTitleAndArtist || videoNameContainsTitleAndGenre) possibleLocal.add(vf.value);
    }

    switch (valInSett) {
      case LocalVideoMatchingType.auto:
        for (final vf in _videoPathsMap.entries) {
          final videoName = vf.key.getFilenameWOExt;
          matchFileName(videoName, vf, shouldCheckSameDir);
          matchTitleAndArtist(videoName, vf, shouldCheckSameDir);
        }
        break;

      case LocalVideoMatchingType.filename:
        for (final vf in _videoPathsMap.entries) {
          final videoName = vf.key.getFilenameWOExt;
          matchFileName(videoName, vf, shouldCheckSameDir);
        }

        break;
      case LocalVideoMatchingType.titleAndArtist:
        for (final vf in _videoPathsMap.entries) {
          final videoName = vf.key.getFilenameWOExt;
          matchTitleAndArtist(videoName, vf, shouldCheckSameDir);
        }
        break;

      default:
        null;
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
      fetchCachedVideos(),
      scanLocalVideos(),
    ]);
    _isInitializing = false;
    await updateCurrentVideo(Player.inst.nowPlayingTrack);
  }

  Future<void> scanLocalVideos({bool strictNoMedia = true, bool forceReScan = false}) async {
    void resetCounters() {
      localVideoExtractCurrent.value = 0;
      localVideoExtractTotal.value = 0;
    }

    resetCounters();
    final localVideos = await _getLocalVideos(
      strictNoMedia: strictNoMedia,
      forceReScan: forceReScan,
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
    final newIdsMap = <String, List<NamidaVideo>>{};

    final videosInMap = idsMap.entries.toList();
    await videosInMap.loopFuture((ve, _) async {
      final id = ve.key;
      final vl = ve.value;
      await vl.loopFuture((v, _) async {
        final file = File(v.path);
        // --- File Exists, will be added either instantly, or by fetching new metadata.
        if (await file.exists()) {
          final stats = await file.stat();
          // -- Video Exists, and already updated.
          if (v.sizeInBytes == stats.size) {
            newIdsMap.addForce(id, v);
          }
          // -- Video exists but needs to be updated.
          else {
            final nv = await _extractNVFromFFMPEG(
              stats: stats,
              id: id,
              path: v.path,
            );
            newIdsMap.addForce(id, nv);
          }
        }

        // else {
        // -- File doesnt exist, ie. has been removed
        // }
      });
    });
    return newIdsMap;
  }

  /// - Loops the currently existing files
  /// - Detects: `new files`.
  /// - DOES NOT handle: `deleted` & `needs-to-be-updated` files.
  /// - Returns a map with new videos only.
  Future<Map<String, List<NamidaVideo>>> _checkForNewVideosInCache(Map<String, List<NamidaVideo>> idsMap) async {
    final dir = Directory(AppDirs.VIDEOS_CACHE);
    final newIdsMap = <String, List<NamidaVideo>>{};

    await for (final df in dir.list()) {
      if (df is File) {
        final id = df.path.getFilename.substring(0, 11);
        final videosInMap = idsMap[id];
        final stats = await df.stat();
        final sizeInBytes = stats.size;
        if (videosInMap != null) {
          // if file exists in map and is valid
          if (videosInMap.firstWhereEff((element) => element.sizeInBytes == sizeInBytes) != null) {
            continue; // skipping since the map will contain only new entries
          }
        }
        // -- hmmm looks like a new video, extract metadata
        try {
          final nv = await _extractNVFromFFMPEG(
            stats: stats,
            id: id,
            path: df.path,
          );

          newIdsMap.addForce(id, nv);
        } catch (e) {
          printy(e, isError: true);
          continue;
        }
      }
    }
    return newIdsMap;
  }

  Future<List<NamidaVideo>> _getLocalVideos({
    bool strictNoMedia = true,
    bool forceReScan = false,
    required void Function(bool didExtract, int total) onProgress,
  }) async {
    final videosFile = File(AppPaths.VIDEOS_LOCAL);
    final namidaVideos = <NamidaVideo>[];

    if (await videosFile.existsAndValid() && !forceReScan) {
      final videosJson = await videosFile.readAsJson() as List?;
      final vl = videosJson?.map((e) => NamidaVideo.fromJson(e)) ?? [];
      namidaVideos.addAll(vl);
    } else {
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

  Future<Uint8List?> getYoutubeThumbnailAsBytes({String? youtubeId, String? url}) async {
    if (youtubeId == null && url == null) return null;

    final links = url != null ? [url] : YTThumbnail(youtubeId!).allQualitiesByHighest;

    for (final link in links) {
      try {
        final res = await http.get(Uri.parse(link));
        final data = res.bodyBytes;
        if (data.isNotEmpty && res.statusCode != 404) {
          return data;
        }
      } catch (e) {
        printy('Error getting thumbnail at $link, trying again with lower quality.\n$e', isError: true);
      }
    }

    return null;
  }

  Future<File?> getYoutubeThumbnailAndCache({String? id, String? channelUrl}) async {
    if (id == null && channelUrl == null) return null;

    final file = id != null ? File("${AppDirs.YT_THUMBNAILS}$id.png") : File("${AppDirs.YT_THUMBNAILS_CHANNELS}${channelUrl?.split('/').last}.png");
    if (await file.exists()) {
      printy('Downloading Thumbnail Already Exists');
      return file;
    }

    printy('Downloading Thumbnail Started');

    final bytes = await getYoutubeThumbnailAsBytes(youtubeId: id, url: channelUrl);
    printy('Downloading Thumbnail Finished');

    return id != null
        ? await _saveThumbnailToStorage(
            videoPath: null,
            bytes: bytes,
            isLocal: false,
            idOrFileNameWOExt: id,
            isExtracted: false,
          )
        : await _saveChannelThumbnailToStorage(
            file: file,
            bytes: bytes,
          );
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
    assert(bytes != null || videoPath != null);

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
    final videoStream = mediaInfo?.streams?.firstWhere((element) => element.streamType == StreamType.video);

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
      creationTimeMS: stats.changed.millisecondsSinceEpoch,
      frameratePrecise: frameratePrecise ?? 0.0,
      durationMS: videoStream?.duration?.inMilliseconds ?? mediaInfo?.format?.duration?.inMilliseconds ?? 0,
      bitrate: int.tryParse(videoStream?.bitRate ?? '') ?? 0,
    );
  }

  Future<List<String>> _fetchVideoPathsFromStorage({bool strictNoMedia = true, bool forceReCheckDir = false}) async {
    final allAvailableDirectories = await Indexer.inst.getAvailableDirectories(forceReCheck: forceReCheckDir);
    final allVideoPaths = <String>[];

    final dirToExclude = settings.directoriesToExclude;
    final dirToLoop = allAvailableDirectories.keys.toList();
    dirToLoop.removeWhere((element) => allAvailableDirectories[element] ?? false);

    await dirToLoop.loopFuture((d, index) async {
      await for (final systemEntity in d.list()) {
        if (systemEntity is File) {
          final path = systemEntity.path;
          if (!kVideoFilesExtensions.any((ext) => path.endsWith(ext))) {
            continue;
          }
          if (dirToExclude.any((excludedDir) => path.startsWith(excludedDir))) {
            continue;
          }

          allVideoPaths.add(path);
        }
      }
    });
    return allVideoPaths;
  }
}

class _NamidaVideoPlayer {
  static _NamidaVideoPlayer get inst => _instance;
  static final _NamidaVideoPlayer _instance = _NamidaVideoPlayer._internal();
  _NamidaVideoPlayer._internal();

  Rxn<Widget>? get videoWidget => _videoWidget;
  CachedVideoPlayerController? get videoController => _videoController;
  bool get isInitialized => _initializedVideo.value;
  bool get isBuffering => _isBuffering.value;
  double get aspectRatio => _videoController?.value.aspectRatio ?? 1.0;
  Future<bool>? get waitTillBufferingComplete => _bufferingCompleter?.future;

  final _initializedVideo = false.obs;
  final _isBuffering = true.obs;
  Completer<bool>? _bufferingCompleter;

  CachedVideoPlayerController? _videoController;
  final _videoWidget = Rxn<Widget>();

  void _updateWidget(CachedVideoPlayerController controller) {
    _videoWidget.value = null;
    _videoWidget.value = CachedVideoPlayer(controller);
  }

  Future<void> setNetworkSource(String url, bool Function(Duration videoDuration) looping, {bool disposePrevious = true}) async {
    _initializedVideo.value = false;
    await _execute(() async {
      if (disposePrevious) await dispose();

      await _initializeController(
        CachedVideoPlayerController.network(
          url,
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: true,
            allowBackgroundPlayback: true,
          ),
        ),
      );
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
        CachedVideoPlayerController.file(
          File(path),
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: true,
            allowBackgroundPlayback: true,
          ),
        ),
      );
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

  Future<bool> enablePictureInPicture() async {
    final res = await PictureInPicture.enterPip(
      width: _videoController?.value.size.width.toInt(),
      height: _videoController?.value.size.height.toInt(),
    );
    return res;
  }

  Future<void> _initializeController(CachedVideoPlayerController c) async {
    _videoController?.removeListener(_updateBufferingStatus);
    _videoController = c;
    await _videoController!.initialize();
    _videoController?.addListener(_updateBufferingStatus);
  }

  bool _didPauseInternally = false;
  Future<void> _updateBufferingStatus() async {
    _isBuffering.value = _videoController?.value.isBuffering ?? true;

    if (_isBuffering.value) {
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
      if (_bufferingCompleter?.isCompleted == false) _bufferingCompleter?.complete(false);
    }
  }

  Future<void> dispose() async {
    if (_initializedVideo.value && (videoController?.value.isInitialized ?? false)) {
      await _execute(() async {
        _videoWidget.value = null;
        await _videoController?.dispose();

        _videoController = null;
        _initializedVideo.value = false;
      });
    }
  }
}
