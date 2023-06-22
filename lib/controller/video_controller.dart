import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/youtube_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/strings.dart';

class VideoController {
  static VideoController get inst => _instance;
  static final VideoController _instance = VideoController._internal();
  VideoController._internal();

  /// Local Video
  final RxList<String> videoFilesPathList = <String>[].obs;
  final RxString localVidPath = ''.obs;

  /// Youtube
  final RxString youtubeLink = ''.obs;
  final RxString youtubeVideoId = ''.obs;
  final RxInt videoCurrentSize = 0.obs;
  final RxString videoCurrentQuality = ''.obs;
  final RxInt videoTotalSize = 0.obs;

  VideoPlayerController? vidcontroller;
  final connectivity = Connectivity();

  YoutubeExplode? _ytexp;
  final RxBool isUpdatingVideoFiles = false.obs;
  Timer? _downloadTimer;

  bool get shouldShowVideo => vidcontroller != null && (localVidPath.value != '' || youtubeLink.value != '') && (vidcontroller?.value.isInitialized ?? false);

  VideoController() {
    /// Listen for connection changes, if a connection was restored, fetch video.
    connectivity.onConnectivityChanged.listen((ConnectivityResult result) async {
      if (result != ConnectivityResult.none && !shouldShowVideo) {
        await updateLocalVidPath(Player.inst.nowPlayingTrack.value);
      }
    });
  }

  /// Always assigns to [VideoController.inst.youtubeLink] and [VideoController.inst.youtubeVideoId]
  void updateYTLink(Track track) {
    resetEverything();
    final link = track.youtubeLink;
    youtubeLink.value = link;
    youtubeVideoId.value = link.getYoutubeID;
  }

  void resetEverything() {
    localVidPath.value = '';
    youtubeLink.value = '';
    videoCurrentSize.value = 0;
    videoCurrentQuality.value = '? ';
    videoTotalSize.value = 0;
  }

  Future<String> downloadYoutubeVideo(String videoId, Track track) async {
    _ytexp?.close();
    _ytexp = YoutubeExplode(YoutubeHttpClient(NamidaClient()));
    final manifest = await _ytexp?.videos.streamsClient.getManifest(videoId);
    if (manifest == null) return '';

    /// Create a list of video qualities in descending order of preference
    final preferredQualities = SettingsController.inst.youtubeVideoQualities.map((element) => element.toVideoQuality());

    final streamInfo = manifest.videoOnly.sortByVideoQuality();

    /// Find the first stream that matches one of the preferred qualities
    final streamToBeUsed = streamInfo.firstWhere(
      (stream) => preferredQualities.contains(stream.videoQuality),
      orElse: () => streamInfo.last,
    );

    /// Get the actual stream
    final stream = _ytexp?.videos.streamsClient.get(streamToBeUsed);

    final file = File("$k_DIR_VIDEOS_CACHE_TEMP${videoId}_${streamToBeUsed.videoQualityLabel}.mp4");

    /// deletes file if it exists, fixes write issues/corrupted video
    if (await file.exists()) {
      await file.delete();
    }

    /// Open a file for writing.
    final fileStream = file.openWrite();

    /// update video size details
    videoTotalSize.value = streamToBeUsed.size.totalBytes;
    videoCurrentQuality.value = streamToBeUsed.videoQualityLabel;

    _downloadTimer?.cancel();
    _downloadTimer = null;
    _downloadTimer = Timer.periodic(
      const Duration(milliseconds: 1000),
      (timer) async {
        final s = await file.stat();
        // only update if the user didnt change the track
        if (s.size > 1000 && Player.inst.nowPlayingTrack.value == track) {
          videoCurrentSize.value = s.size;
        }
      },
    );

    /// Pipe all the content of the stream into the file.
    await stream?.pipe(fileStream);

    /// Close the file.
    await fileStream.flush();
    await fileStream.close();

    final newPath = "$k_DIR_VIDEOS_CACHE${videoId}_${streamToBeUsed.videoQualityLabel}.mp4";
    final newFile = File(newPath);

    await file.copy(newPath);
    await file.delete();
    _ytexp?.close();

    videoCurrentSize.value = 0;
    Indexer.inst.updateVideosSizeInStorage(newFile);
    return newPath;
  }

  Future<void> updateLocalVidPath([Track? track]) async {
    if (!SettingsController.inst.enableVideoPlayback.value) {
      return;
    }
    track ??= Player.inst.nowPlayingTrack.value;

    updateYTLink(track);

    if (SettingsController.inst.useYoutubeMiniplayer.value) {
      YoutubeController.inst.updateCurrentVideoMetadata(track.youtubeID);
    }

    /// Video Found in Local Storage
    for (final vf in videoFilesPathList) {
      final videoName = vf.getFilenameWOExt;
      final videoNameContainsMusicFileName = checkFileNameAudioVideo(videoName, track.filenameWOExt);
      final videoContainsTitle = videoName.contains(track.title.cleanUpForComparison);
      final videoNameContainsTitleAndArtist = videoContainsTitle && videoName.contains(track.artistsList.first.cleanUpForComparison);
      // useful for [Nightcore - title]
      // track must contain Nightcore as the first Genre
      final videoNameContainsTitleAndGenre = videoContainsTitle && videoName.contains(track.genresList.first.cleanUpForComparison);
      if (videoNameContainsMusicFileName || videoNameContainsTitleAndArtist || videoNameContainsTitleAndGenre) {
        await playAndInitializeVideo(vf, track);
        await vidcontroller?.setVolume(0.0);
        videoCurrentQuality.value = Language.inst.LOCAL;
        printInfo(info: 'RETURNED AFTER LOCAL');
        return;
      }
    }

    if (youtubeVideoId.isEmpty) {
      return;
    }

    /// Video Found in Video Cache Directory
    if (SettingsController.inst.videoPlaybackSource.value != 2 /* not youtube */) {
      final videoFiles = Directory(k_DIR_VIDEOS_CACHE).listSync();
      for (final f in videoFiles) {
        if (f.path.getFilename.contains(youtubeVideoId.value)) {
          await playAndInitializeVideo(f.path, track);
          final s = await f.stat();
          videoTotalSize.value = s.size;
          videoCurrentQuality.value = f.path.split('_').last.split('.').first;
          printInfo(info: 'RETURNED AFTER VIDEO CACHE');
          return;
        }
      }
    }

    if (SettingsController.inst.videoPlaybackSource.value != 1 /* not local */) {
      localVidPath.value = '';
      youtubeLink.value = '';

      /// return if no internet
      if (await connectivity.checkConnectivity() == ConnectivityResult.none) {
        printInfo(info: 'NO INTERNET');
        return;
      }
      await playAndInitializeVideo(await downloadYoutubeVideo(youtubeVideoId.value, track), track);
      printInfo(info: 'RETURNED AFTER DOWNLOAD');
    }
  }

  bool checkFileNameAudioVideo(String videoFileName, String audioFileName) {
    return videoFileName.cleanUpForComparison.contains(audioFileName.cleanUpForComparison) || videoFileName.contains(audioFileName);
  }

  /// track is important to initialize the player only if the user didnt skip the song
  /// happens quite often when the video is being downloaded.
  Future<void> playAndInitializeVideo(String path, Track track) async {
    if (path.isEmpty) {
      return;
    }
    if (Player.inst.nowPlayingTrack.value == track) {
      final file = File(path);
      await vidcontroller?.dispose();
      vidcontroller = VideoPlayerController.file(file, videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true, allowBackgroundPlayback: true));
      await vidcontroller?.initialize();
      await vidcontroller?.setVolume(0.0);
      await Player.inst.updateVideoPlayingState();
      localVidPath.value = path;

      /// video info
      // final info = await VideoCompress.getMediaInfo(path);
      // print("VVVVVVV ${info.toJson()}");
    }
  }

  /// Player Utils

  void play() {
    vidcontroller?.play();
  }

  void pause() {
    vidcontroller?.pause();
  }

  Future<void> seek(Duration position, {int? index}) async {
    await vidcontroller?.seekTo(position);
  }

  /// function to get all videos inside [directoriesListToScan], value is assigned to [videoFilesPathList].
  Future<Set<String>> getVideoFiles({bool forceRescan = false}) async {
    isUpdatingVideoFiles.value = true;
    final videoFile = File(k_FILE_PATH_VIDEO_PATHS);
    final videoFileStats = await videoFile.stat();
    final shouldReadFile = !forceRescan && await videoFile.exists() && videoFileStats.size != 0;

    if (shouldReadFile) {
      try {
        final content = await videoFile.readAsString();
        final txt = List<String>.from(json.decode(content));
        videoFilesPathList.assignAll(txt);
      } catch (e) {
        printInfo(info: e.toString());
      }
    } else {
      await videoFile.create();
      final allVideosPaths = <String>{};
      final dirToScan = SettingsController.inst.directoriesToScan.toList();
      final dirToExclude = SettingsController.inst.directoriesToExclude.toList();

      for (final path in dirToScan) {
        final dir = Directory(path);
        if (await dir.exists()) {
          await for (final file in dir.list(recursive: true)) {
            /// skipping if dir should be excluded
            if (file is! File || dirToExclude.any((exc) => file.path.startsWith(exc))) {
              continue;
            }
            try {
              /// matching as video extensions.
              for (final extension in kVideoFilesExtensions) {
                if (file.path.endsWith(extension)) {
                  allVideosPaths.add(file.path);
                  break;
                }
              }
            } catch (e) {
              printError(info: e.toString());
              continue;
            }
          }
        }
        videoFilesPathList.assignAll(allVideosPaths.toList());
        printInfo(info: allVideosPaths.toString());
      }
      final listAsString = videoFilesPathList.map((path) => '"$path"').join(', ');
      await videoFile.writeAsString("[$listAsString]");
    }
    isUpdatingVideoFiles.value = false;
    return videoFilesPathList.toSet();
  }

  Future<void> toggleVideoPlaybackInSetting() async {
    SettingsController.inst.save(enableVideoPlayback: !SettingsController.inst.enableVideoPlayback.value);
    if (!SettingsController.inst.enableVideoPlayback.value) {
      localVidPath.value = '';
      youtubeLink.value = '';
      _ytexp?.close();
    } else {
      await VideoController.inst.updateLocalVidPath();
      await Player.inst.updateVideoPlayingState();
    }
  }
}
