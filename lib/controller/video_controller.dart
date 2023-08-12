// ignore_for_file: library_private_types_in_public_api

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:better_player/better_player.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get_rx/get_rx.dart';
import 'package:media_metadata_retriever/media_metadata_retriever.dart';
import 'package:media_metadata_retriever/models/media_info.dart';

import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/youtube_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';

class VideoController {
  static VideoController get inst => _instance;
  static final VideoController _instance = VideoController._internal();
  VideoController._internal();

  final RxDouble videoZoomAdditionalScale = 0.0.obs;

  Widget getVideoWidget(bool enableControls) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onScaleUpdate: (details) {
          videoZoomAdditionalScale.value = details.scale;
        },
        onScaleEnd: (details) {
          if (videoZoomAdditionalScale.value > 1.1) {
            vcontroller.enterFullScreen(getVideoWidget(true));
          } else {
            vcontroller.exitFullScreen();
          }
        },
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: BetterPlayer(
            controller: playerController!,
          ),
        ),
      );
  bool get shouldShowVideo => currentVideo.value != null && _videoController.isInitialized;

  double get aspectRatio => _videoController.aspectRatio;

  final localVideoExtractCurrent = Rxn<int>();
  final localVideoExtractTotal = 0.obs;

  final currentVideo = Rxn<NamidaVideo>();
  final currentPossibleVideos = <NamidaVideo>[].obs;
  final currentDownloadedBytes = 0.obs;

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

  BetterPlayerController? get playerController => _videoController.videoController;
  static _NamidaVideoPlayer get vcontroller => inst._videoController;
  _NamidaVideoPlayer _videoController = _NamidaVideoPlayer.inst;

  bool _isInitializing = true;

  Future<void> updateCurrentVideo(Track track) async {
    isNoVideosAvailable.value = false;
    currentDownloadedBytes.value = 0;
    currentVideo.value = null;
    await vcontroller.dispose();
    if (_isInitializing) return;
    if (!SettingsController.inst.enableVideoPlayback.value) return;

    final possibleVideos = _getPossibleVideosFromTrack(track);
    currentPossibleVideos
      ..clear()
      ..addAll(possibleVideos);

    final trackYTID = track.youtubeID;
    if (possibleVideos.isEmpty && trackYTID == '') isNoVideosAvailable.value = true;

    final vpsInSettings = SettingsController.inst.videoPlaybackSource.value;
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
          if (e.width == 0 || e.height == 0) {
            return 0;
          }
          return e.height / e.width;
        },
        (e) => e.sizeInBytes,
      );
      erabaretaVideo = possibleVideos.firstWhereEff((element) => File(element.path).existsSync());
    }
    currentVideo.value = erabaretaVideo;

    if (erabaretaVideo == null && vpsInSettings != VideoPlaybackSource.local) {
      final downloadedVideo = await fetchVideoFromYoutube(trackYTID);
      erabaretaVideo = downloadedVideo;
    }

    if (erabaretaVideo != null) {
      await playVideoCurrent(path: erabaretaVideo.path, track: track);
    }
    // saving video thumbnail
    final id = erabaretaVideo?.ytID;
    if (id != null) {
      await saveYoutubeThumbnail(id: id);
    }
  }

  Future<void> playVideoCurrent({
    required String path,
    required Track track,
  }) async {
    await _executeForCurrentTrackOnly(track, () async {
      const allowance = 5; // seconds
      await _videoController.setFile(
          path, (videoDuration) => videoDuration.inSeconds > allowance && videoDuration.inSeconds < track.duration - allowance); // loop only if video duration is less than audio.
      await _videoController.setVolume(0);
      await Player.inst.updateVideoPlayingState();
      currentVideo.refresh();
    });
  }

  Future<void> toggleVideoPlayback() async {
    final currentValue = SettingsController.inst.enableVideoPlayback.value;
    SettingsController.inst.save(enableVideoPlayback: !currentValue);
    if (currentValue) {
      // should close/hide
      currentVideo.value = null;
      _videoController.dispose();
      YoutubeController.inst.dispose(downloadClientOnly: true);
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

  Future<NamidaVideo?> fetchVideoFromYoutube(String id) async {
    if (id == '') return null;
    int downloaded = 0;
    _downloadTimerCancel();
    _downloadTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      currentDownloadedBytes.value = downloaded;
      printy('Video Download: ${currentDownloadedBytes.value.fileSizeFormatted}');
    });
    final initialTrack = Player.inst.nowPlayingTrack;
    void updateValuesCT(void Function() execute) => _executeForCurrentTrackOnly(initialTrack, execute);

    final downloadedVideo = await YoutubeController.inst.downloadYoutubeVideo(
      id: id,
      onAvailableQualities: (availableStreams) {},
      onChoosingQuality: (choosenStream) {
        updateValuesCT(() {
          currentVideo.value = NamidaVideo(
            path: '',
            height: choosenStream.videoResolution.height,
            width: choosenStream.videoResolution.width,
            sizeInBytes: choosenStream.size.totalBytes,
            frameratePrecise: choosenStream.framerate.framesPerSecond.toDouble(),
            creationTimeMS: 0,
            durationMS: 0,
            bitrate: choosenStream.bitrate.bitsPerSecond,
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
    if (downloadedVideo != null) {
      _videoCacheIDMap.addForce(downloadedVideo.ytID ?? '', downloadedVideo);
      await _saveCachedVideosFile();
    }
    currentDownloadedBytes.value = 0;
    _downloadTimerCancel();
    return downloadedVideo;
  }

  List<NamidaVideo> _getPossibleVideosFromTrack(Track track) {
    final link = track.youtubeLink;
    final id = link.getYoutubeID;

    final possibleCached = _videoCacheIDMap[id] ?? [];

    final possibleLocal = <NamidaVideo>[];
    final trExt = track.toTrackExt();
    _videoPathsMap.entries.toList().loop((vf, index) {
      final videoName = vf.key.getFilenameWOExt;
      final videoNameContainsMusicFileName = _checkFileNameAudioVideo(videoName, track.filenameWOExt);
      final videoContainsTitle = videoName.contains(trExt.title.cleanUpForComparison);
      final videoNameContainsTitleAndArtist = videoContainsTitle && trExt.artistsList.isNotEmpty && videoName.contains(trExt.artistsList.first.cleanUpForComparison);
      // useful for [Nightcore - title]
      // track must contain Nightcore as the first Genre
      final videoNameContainsTitleAndGenre = videoContainsTitle && trExt.genresList.isNotEmpty && videoName.contains(trExt.genresList.first.cleanUpForComparison);
      if (videoNameContainsMusicFileName || videoNameContainsTitleAndArtist || videoNameContainsTitleAndGenre) {
        possibleLocal.add(vf.value);
      }
    });
    return [...possibleCached, ...possibleLocal];
  }

  bool _checkFileNameAudioVideo(String videoFileName, String audioFileName) {
    return videoFileName.cleanUpForComparison.contains(audioFileName.cleanUpForComparison) || videoFileName.contains(audioFileName);
  }

  Future<void> initialize() async {
    // -- Fetching Cached Videos Info.
    final file = File(k_FILE_PATH_VIDEOS_CACHE);
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
    final file = File(k_FILE_PATH_VIDEOS_CACHE);
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
    final mmr = MediaMetadataRetriever();

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
              mmr: mmr,
              sizeInBytes: stats.size,
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
    final dir = Directory(k_DIR_VIDEOS_CACHE);
    final newIdsMap = <String, List<NamidaVideo>>{};
    final mmr = MediaMetadataRetriever();

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
            mmr: mmr,
            sizeInBytes: sizeInBytes,
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
    final videosFile = File(k_FILE_PATH_VIDEOS_LOCAL);
    final namidaVideos = <NamidaVideo>[];

    if (await videosFile.existsAndValid() && !forceReScan) {
      final videosJson = await videosFile.readAsJson() as List?;
      final vl = videosJson?.map((e) => NamidaVideo.fromJson(e)) ?? [];
      namidaVideos.addAll(vl);
    } else {
      final videos = await _fetchVideoPathsFromStorage(strictNoMedia: strictNoMedia, forceReCheckDir: forceReScan);
      final mmr = MediaMetadataRetriever();

      for (final path in videos) {
        final v = await mmr.getAllMediaInfo(path);
        if (v != null) {
          final filePath = v.path;
          _saveThumbnailToStorage(
            bytes: v.artwork ?? v.thumbnail,
            isLocal: true,
            idOrFileNameWOExt: filePath.getFilenameWOExt,
            isExtracted: true,
          );
          final stats = await File(filePath).stat();
          final nv = _getNVFromFFMPEGMap(
            mediaInfo: v,
            size: stats.size,
            ytID: null,
          );
          namidaVideos.add(nv);
        }
        onProgress(true, videos.length);
      }
      await videosFile.writeAsJson(namidaVideos.mapped((e) => e.toJson()));
    }

    return namidaVideos;
  }

  Future<NamidaVideo> _extractNVFromFFMPEG({
    required MediaMetadataRetriever mmr,
    required int sizeInBytes,
    required String? id,
    required String path,
  }) async {
    final info = await mmr.getAllMediaInfo(path);

    _saveThumbnailToStorage(
      bytes: info?.artwork ?? info?.thumbnail,
      isLocal: id == null,
      idOrFileNameWOExt: id ?? path.getFilenameWOExt,
      isExtracted: true,
    );
    return _getNVFromFFMPEGMap(
      mediaInfo: info,
      size: sizeInBytes,
      ytID: id,
      path: path,
    );
  }

  Future<File?> saveYoutubeThumbnail({
    required String id,
  }) async {
    final file = File("$k_DIR_YT_THUMBNAILS$id.png");
    if (await file.exists()) {
      printy('Downloading Thumbnail Already Exists');
      return file;
    }
    printy('Downloading Thumbnail Start');
    final dio = Dio();
    final link = YTThumbnail(id).maxResUrl;
    final link2 = YTThumbnail(id).highResUrl;

    Response<List<int>>? response;
    Future<Response<List<int>>> getImageBytes(String link) async {
      return await dio.get<List<int>>(
        link,
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: (count, total) => printy('Downloading Thumbnail ${count.fileSizeFormatted}/${total.fileSizeFormatted}'),
      );
    }

    try {
      response = await getImageBytes(link);
    } catch (e) {
      printy('Error getting maxResUrl, trying again with highRes Image.\n$e', isError: true);
      try {
        response = await getImageBytes(link2);
      } catch (e) {
        printy('Error getting highResUrl.\n$e', isError: true);
      }
    }
    dio.close();

    final bytes = response?.data != null ? Uint8List.fromList(response?.data ?? []) : null;

    printy('Downloaded Thumbnail bytes: ${bytes?.length}');
    return await _saveThumbnailToStorage(
      bytes: bytes,
      isLocal: false,
      idOrFileNameWOExt: id,
      isExtracted: false,
    );
  }

  Future<File?> _saveThumbnailToStorage({
    required Uint8List? bytes,
    required bool isLocal,
    required String idOrFileNameWOExt,
    required bool isExtracted, // set to false if its a youtube thumbnail.
  }) async {
    if (bytes != null) {
      final prefix = !isLocal && isExtracted ? 'EXT_' : '';
      final dir = isLocal ? k_DIR_THUMBNAILS : k_DIR_YT_THUMBNAILS;
      final file = File("$dir$prefix$idOrFileNameWOExt.png");
      // if pure yt thumbnail delete the extracted version
      if (!isExtracted) {
        await File("${k_DIR_YT_THUMBNAILS}EXT_$idOrFileNameWOExt.png").deleteIfExists();
      }

      return await file.writeAsBytes(bytes);
    }
    return null;
  }

  NamidaVideo _getNVFromFFMPEGMap({MediaInfo? mediaInfo, required int size, String? ytID, String? path}) {
    final finalPath = mediaInfo?.path ?? path ?? '';
    return NamidaVideo(
      path: finalPath,
      ytID: ytID,
      nameInCache: ytID != null ? finalPath.getFilenameWOExt : null,
      height: mediaInfo?.videoHeight ?? 0,
      width: mediaInfo?.videoWidth ?? 0,
      sizeInBytes: size,
      creationTimeMS: DateTime.tryParse(mediaInfo?.creationTime ?? mediaInfo?.creationDate ?? '')?.millisecondsSinceEpoch ?? 0,
      frameratePrecise: mediaInfo?.framerate ?? 0.0,
      durationMS: mediaInfo?.durationMS ?? int.tryParse(mediaInfo?.durationAlt ?? '') ?? 0,
      bitrate: mediaInfo?.bitrate ?? 0,
    );
  }

  Future<List<String>> _fetchVideoPathsFromStorage({bool strictNoMedia = true, bool forceReCheckDir = false}) async {
    final allAvailableDirectories = await Indexer.inst.getAvailableDirectories(forceReCheck: forceReCheckDir);
    final allVideoPaths = <String>[];

    final dirToExclude = SettingsController.inst.directoriesToExclude;
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

  BetterPlayerController? get videoController => _videoController;
  bool get isInitialized => _initializedVideo;
  double get aspectRatio => _videoController.videoPlayerController?.value.aspectRatio ?? 1.0;
  bool _initializedVideo = false;

  final BetterPlayerController _videoController = BetterPlayerController(
    const BetterPlayerConfiguration(
        autoDispose: false,
        handleLifecycle: false,
        autoDetectFullscreenAspectRatio: false,
        autoDetectFullscreenDeviceOrientation: false,
        useRootNavigator: true,
        fit: BoxFit.contain,
        controlsConfiguration: BetterPlayerControlsConfiguration(
          showControls: false,
        )),
  );

  Future<void> playFile(String path, bool Function(Duration videoDuration) looping) async {
    await setFile(path, looping);
    await play();
  }

  Future<void> setFile(String path, bool Function(Duration videoDuration) looping) async {
    _initializedVideo = false;
    try {
      await dispose();
      await _videoController.setupDataSource(BetterPlayerDataSource.file(path));
      _initializedVideo = true;
      _videoController.setLooping(looping(_videoController.videoPlayerController?.value.duration ?? Duration.zero));
    } catch (e) {
      printy(e, isError: true);
    }
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

  Future<void> play() async => _execute(() async => await _videoController.play());

  Future<void> pause() async => _execute(() async => await _videoController.pause());

  Future<void> seek(Duration duration) async => _execute(() async => await _videoController.seekTo(duration));

  Future<void> setVolume(double volume) async => _execute(() async => await _videoController.setVolume(volume));

  Future<void> enablePictureInPicture() async {}
  Future<void> disablePictureInPicture() async {}

  void enterFullScreen(Widget widget) => NamidaNavigator.inst.enterFullScreen(widget);

  void exitFullScreen() => NamidaNavigator.inst.exitFullScreen();

  Future<void> dispose() async {
    if (_initializedVideo && (videoController?.isVideoInitialized() ?? false)) {
      await _execute(() {
        // _videoController.dispose(forceDispose: true);
        _initializedVideo = false;
      });
    }
  }
}
