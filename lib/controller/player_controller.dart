// ignore_for_file: depend_on_referenced_packages

import 'package:get/get.dart';
import 'package:collection/collection.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/controller/waveform_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/controller/indexer_controller.dart';

//
//
//
//
//
//
class Player extends GetxController {
  static Player inst = Player();
  final player = AudioPlayer();

  Rx<Track> nowPlayingTrack = kDummyTrack.obs;
  RxList<Track> currentQueue = <Track>[].obs;
  RxInt currentIndex = 0.obs;
  RxBool isPlaying = false.obs;
  RxInt nowPlayingPosition = 0.obs;

  Player() {
    /// isPlaying Stream
    player.playingStream.listen((event) async {
      isPlaying.value = event;

      /// for video
      await updateVideoPlayingState();
    });

    /// Position Stream
    player.positionStream.listen((event) {
      nowPlayingPosition.value = event.inMilliseconds;
    });

    // Attempt to fix video position after switching to bg or turning off screen
    player.positionDiscontinuityStream.listen((event) async {
      await updateVideoPlayingState();
    });

    /// Current Index Stream
    player.currentIndexStream.listen((event) async {
      currentIndex.value = event ?? 0;
      final track = currentQueue.elementAt(event ?? 0);
      nowPlayingTrack.value = track;
      WaveformController.inst.generateWaveform(track);
      CurrentColor.inst.updatePlayerColor(track);

      /// for video
      if (SettingsController.inst.enableVideoPlayback.value) {
        await VideoController.inst.updateYTLink(track);
        await VideoController.inst.updateLocalVidPath(track);
      }
      await updateVideoPlayingState();
    });
    // currentQueue.listen((q) {
    //   final playlist = ConcatenatingAudioSource(
    //     useLazyPreparation: true,
    //     shuffleOrder: DefaultShuffleOrder(),
    //     children: q
    //         .asMap()
    //         .entries
    //         .map(
    //           (e) => AudioSource.uri(
    //             Uri.parse(e.value.path),
    //             tag: MediaItem(
    //               id: e.key.toString(),
    //               title: e.value.title,
    //               displayTitle: e.value.title,
    //               displaySubtitle: "${e.value.artistsList.take(3).join(', ')} - ${e.value.album}",
    //               displayDescription: "${e.key + 1}/${q.length}",
    //               artist: e.value.artistsList.take(3).join(', '),
    //               album: e.value.album,
    //               genre: e.value.genresList.take(3).join(', '),
    //               duration: Duration(milliseconds: e.value.duration),
    //               artUri: Uri.file(e.value.pathToImage),
    //             ),
    //           ),
    //         )
    //         .toList(),
    //   );
    //   player.setAudioSource(playlist, initialIndex: q.indexOf(nowPlayingTrack.value), initialPosition: Duration.zero);
    //   printInfo(info: q.length.toString());
    // });
  }

  Future<void> updateVideoPlayingState() async {
    await refreshVideoPosition();
    if (isPlaying.value) {
      VideoController.inst.play();
    } else {
      VideoController.inst.pause();
    }
    await refreshVideoPosition();
  }

  /// refreshes video position, usually after a play/pause or after switching video display
  Future<void> refreshVideoPosition() async {
    await VideoController.inst.seek(Duration(milliseconds: nowPlayingPosition.value));
  }

  Future<void> initializePlayer() async {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.msob7y.namida',
      androidNotificationChannelName: 'Namida',
      androidNotificationOngoing: true,
      preloadArtwork: true,
    );
  }

  Future<void> addToQueue(List<Track> tracks, {bool insertNext = false}) async {
    List<Track> finalQueue = [];
    if (insertNext) {
      finalQueue = [...currentQueue.getRange(0, currentIndex.value + 1), ...tracks, ...currentQueue.getRange(currentIndex.value + tracks.length, currentQueue.length)];
      printInfo(info: finalQueue.map((e) => e.title).toString());
    } else {
      finalQueue = [...currentQueue, ...tracks];
    }

    await player.setAudioSource(_getAudioSourcePlaylist(finalQueue),
        initialIndex: currentQueue.indexOf(nowPlayingTrack.value), initialPosition: Duration(milliseconds: nowPlayingPosition.value));
    currentQueue.refresh();
  }

  Future<void> next() async {
    await player.seekToNext();
  }

  Future<void> previous() async {
    await player.seekToPrevious();
  }

  Future<void> skipToQueueItem(Track track) async {
    await player.seek(const Duration(microseconds: 0), index: currentQueue.indexOf(track));
  }

  Future<void> seek(Duration position, {int? index}) async {
    await player.seek(position, index: index);
    VideoController.inst.seek(position, index: index);
  }

  Future<void> playOrPause({Track? track, List<Track>? queue, bool playSingle = false, bool shuffle = false}) async {
    track ??= nowPlayingTrack.value;
    if (nowPlayingTrack.value == track) {
      if (player.playerState.playing) {
        nowPlayingPosition.value = player.position.inMilliseconds;

        player.pause();
      } else {
        await player.play();
        await player.seek(Duration(milliseconds: nowPlayingPosition.value));
      }
      return;
    }

    if (playSingle) {
      queue = [track];
    }

    queue ??= Indexer.inst.trackSearchList.toList();

    /// if the queue is the same, it will skip instead of rebuilding the queue, certainly more performant
    if (const IterableEquality().equals(queue, currentQueue.toList())) {
      await skipToQueueItem(track);
      printInfo(info: "Skipped");
      return;
    }

    if (shuffle) {
      queue.shuffle();
    }
    nowPlayingTrack.value = track;
    currentQueue.assignAll(queue);

    player.setAudioSource(_getAudioSourcePlaylist(queue), initialIndex: queue.indexOf(track), initialPosition: Duration.zero);
    player.play();
  }

  ConcatenatingAudioSource _getAudioSourcePlaylist(List<Track> playlist) {
    return ConcatenatingAudioSource(
      useLazyPreparation: true,
      shuffleOrder: DefaultShuffleOrder(),
      children: playlist
          .asMap()
          .entries
          .map(
            (e) => AudioSource.uri(
              Uri.parse(e.value.path),
              tag: MediaItem(
                id: e.key.toString(),
                title: e.value.title,
                displayTitle: e.value.title,
                displaySubtitle: "${e.value.artistsList.take(3).join(', ')} - ${e.value.album}",
                displayDescription: "${e.key + 1}/${currentQueue.length}",
                artist: e.value.artistsList.take(3).join(', '),
                album: e.value.album,
                genre: e.value.genresList.take(3).join(', '),
                duration: Duration(milliseconds: e.value.duration),
                artUri: Uri.file(e.value.pathToImage),
              ),
            ),
          )
          .toList(),
    );
  }

  @override
  void onClose() {
    Get.delete();
    super.onClose();
  }
}
