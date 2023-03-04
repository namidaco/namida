// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:namida/class/track.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class VideoController extends GetxController {
  static final VideoController inst = VideoController();

  /// Local Video
  RxList<String> videoFilesPathList = <String>[].obs;
  RxString localVidPath = ''.obs;

  /// Youtube
  RxString youtubeLink = ''.obs;
  RxString youtubeVideoId = ''.obs;
  RxInt videoCurrentSize = 0.obs;
  RxString videoCurrentQuality = ''.obs;
  RxInt videoTotalSize = 0.obs;
  RxBool isLocal = false.obs;
  VideoPlayerController? vidcontroller;
  var ytexp = YoutubeExplode();

  /// Always assigns to [VideoController.inst.youtubeLink] and [VideoController.inst.youtubeVideoId]
  void updateYTLink(Track track) {
    localVidPath.value = '';
    youtubeLink.value = '';
    resetEverything();
    final link = extractYTLinkFromTrack(track);
    youtubeLink.value = link;
    youtubeVideoId.value = extractIDFromYTLink(link);
  }

  void resetEverything() {
    // youtubeLink.value = '';
    // youtubeVideoId.value = '';
    // isVideoReady.value = false;
    videoCurrentSize.value = 0;
    videoCurrentQuality.value = ' ? ';
    videoTotalSize.value = 0;
  }

  String extractYTLinkFromTrack(Track track) {
    final regex = RegExp(
      r'\b(?:https?://)?(?:www\.)?(?:youtube\.com/watch\?v=|youtu\.be/)([\w\-]+)(?:\S+)?',
      caseSensitive: false,
    );

    final match = regex.firstMatch(track.comment);
    final match2 = regex.firstMatch(track.displayName);

    final link = match?[0] ?? match2?[0] ?? '';

    return link;
  }

  String extractIDFromYTLink(String ytlink) {
    String videoId = '';
    if (ytlink.length >= 11) {
      videoId = ytlink.substring(ytlink.length - 11);
    }
    return videoId;
  }

  String extractYTIDFromTrack(Track track) {
    final ytlink = extractYTLinkFromTrack(track);
    final id = extractIDFromYTLink(ytlink);
    return id;
  }

  Future<String> downloadYoutubeVideo(String videoId, Track track) async {
    var manifest = await ytexp.videos.streamsClient.getManifest(videoId);

    /// Create a list of video qualities in descending order of preference
    final preferredQualities = SettingsController.inst.youtubeVideoQualities.map((element) => element.toVideoQuality);

    var streamInfo = manifest.videoOnly.sortByVideoQuality();

    /// Find the first stream that matches one of the preferred qualities
    final streamToBeUsed = streamInfo.firstWhere(
      (stream) => preferredQualities.contains(stream.videoQuality),
      orElse: () => streamInfo.last,
    );

    /// Get the actual stream
    var stream = ytexp.videos.streamsClient.get(streamToBeUsed);

    /// Open a file for writing.
    var file = File("$kVideosCacheTempPath${videoId}_${streamToBeUsed.videoQualityLabel}.mp4");
    var fileStream = file.openWrite();

    /// update video size details
    videoTotalSize.value = streamToBeUsed.size.totalBytes;
    videoCurrentQuality.value = streamToBeUsed.videoQualityLabel;

    Timer.periodic(
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
    await stream.pipe(fileStream);

    /// Close the file.
    await fileStream.flush();
    await fileStream.close();

    await file.copy("$kVideosCachePath${videoId}_${streamToBeUsed.videoQualityLabel}.mp4");
    await file.delete();

    videoCurrentSize.value = 0;
    Indexer.inst.updateVideosSizeInStorage();
    return Future.value(File("$kVideosCachePath${videoId}_${streamToBeUsed.qualityLabel}.mp4").path);
  }

  Future<void> updateLocalVidPath([Track? track]) async {
    track ??= Player.inst.nowPlayingTrack.value;
    resetEverything();
    updateYTLink(track);

    /// Video Found in Local Storage
    for (var vf in videoFilesPathList) {
      if (vf.contains(track.displayNameWOExt)) {
        await vidcontroller?.setVolume(0.0);
        await playAndInitializeVideo(vf, track);
        await vidcontroller?.setVolume(0.0);
        videoCurrentQuality.value = Language.inst.LOCAL;
        printInfo(info: 'RETURNED AFTER LOCAL');
        return;
      }
    }

    /// Video Found in Video Cache Directory
    if (SettingsController.inst.videoPlaybackSource.value != 2 /* not youtube */) {
      final videoFiles = Directory(kVideosCachePath).listSync();
      for (var f in videoFiles) {
        if (p.basename(f.path).contains(youtubeVideoId.value)) {
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
      await playAndInitializeVideo(await downloadYoutubeVideo(youtubeVideoId.value, track), track);
      printInfo(info: 'RETURNED AFTER DOWNLOAD');
    }
  }

  void updateThingys() {
    videoCurrentQuality.value = ' ? ';
    videoTotalSize.value = 0;
  }

  /// track is important to initialize the player only if the user didnt skip the song
  Future<void> playAndInitializeVideo(String path, Track track) async {
    if (Player.inst.nowPlayingTrack.value == track) {
      final file = File(path);
      await vidcontroller?.setVolume(0.0);
      vidcontroller = VideoPlayerController.file(file, videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true, allowBackgroundPlayback: true));
      await vidcontroller?.initialize();
      await vidcontroller?.setVolume(0.0);
      localVidPath.value = path;

      await Player.inst.updateVideoPlayingState();
      update();
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
  Future<Set<String>> getVideoFiles() async {
    final videoFile = File(kVideoPathsFilePath);
    final videoFileStats = await videoFile.stat();
    // List<double> waveform = kDefaultWaveFormData;
    if (await videoFile.exists() && videoFileStats.size != 0) {
      try {
        String content = await videoFile.readAsString();
        final txt = List<String>.from(json.decode(content));
        videoFilesPathList.assignAll(txt);
      } catch (e) {
        printInfo(info: e.toString());
      }
      return videoFilesPathList.toSet();
    } else {
      await videoFile.create();
      final allPaths = <String>{};
      for (final path in SettingsController.inst.directoriesToScan.toList()) {
        if (await Directory(path).exists()) {
          final directory = Directory(path);
          final filesPre = directory.listSync(recursive: true);

          for (final file in filesPre) {
            try {
              if (file is File) {
                for (final extension in kVideoFilesExtensions) {
                  if (file.path.endsWith(extension)) {
                    // Checks if the file is not included in one of the excluded folders.
                    if (!SettingsController.inst.directoriesToExclude.toList().any((exc) => file.path.startsWith(exc))) {
                      allPaths.add(file.path);
                    }

                    break;
                  }
                }
              }
              // if (file is Directory) {
              //   if (!SettingsController.inst.directoriesToExclude.toList().any((exc) => file.path.startsWith(exc))) {
              //     videoFilesSystemEntity.add(file);

              //   }
              // }
            } catch (e) {
              printError(info: e.toString());
              continue;
            }
          }
        }
        videoFilesPathList.value = allPaths.toList();
        printInfo(info: allPaths.toString());
      }
      final listAsString = videoFilesPathList.map((path) => '"$path"').join(', ');
      await videoFile.writeAsString("[$listAsString]");

      return allPaths;
    }
  }

  Future<void> toggleVideoPlaybackInSetting() async {
    SettingsController.inst.save(enableVideoPlayback: !SettingsController.inst.enableVideoPlayback.value);
    if (!SettingsController.inst.enableVideoPlayback.value) {
      localVidPath.value = '';
      youtubeLink.value = '';
    } else {
      await VideoController.inst.updateLocalVidPath();
      await Player.inst.updateVideoPlayingState();
    }
  }
}
