// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:get/get.dart';
import 'package:collection/collection.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/controller/waveform_controller.dart';
import 'package:namida/core/constants.dart';

class Player extends GetxController {
  static Player inst = Player();
  final player = AudioPlayer();

  Rx<Track> nowPlayingTrack = kDummyTrack.obs;
  RxList<Track> currentQueue = <Track>[].obs;
  RxInt currentIndex = 0.obs;
  RxBool isPlaying = false.obs;
  RxInt nowPlayingPosition = 0.obs;
  Rx<ConcatenatingAudioSource>? playlist;

  Player() {
    playlist?.value = ConcatenatingAudioSource(
      useLazyPreparation: true,
      shuffleOrder: DefaultShuffleOrder(),
      children: currentQueue
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
    player.playbackEventStream.listen((event) {
      QueueController.inst.updateLatestQueue(currentQueue.toList());
    });

    player.processingStateStream.listen((state) async {
      if (state == ProcessingState.completed) {
        await player.seek(const Duration(microseconds: 0), index: 0);
        await player.pause();
      }
    });

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
    });
    currentIndex.listen((i) async {
      // await updateAllAudioDependantListeners(i);
      nowPlayingTrack.value = currentQueue.elementAt(i);
      // PlaylistController.inst.addToHistory(nowPlayingTrack.value);
      // SettingsController.inst.setData('lastPlayedTrackPath', nowPlayingTrack.value.path);
    });
    nowPlayingTrack.listen((tr) async {
      await CurrentColor.inst.updatePlayerColor(tr);
      updateAllAudioDependantListeners(null, tr);
      PlaylistController.inst.addToHistory(nowPlayingTrack.value);
      SettingsController.inst.setData('lastPlayedTrackPath', tr.path);
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
  Future<void> updateAllAudioDependantListeners([int? i, Track? track]) async {
    i ??= player.currentIndex ?? 0;
    track ??= currentQueue.elementAt(i);
    // i ??= currentQueue.indexOf(nowPlayingTrack.value);
    // track ??= nowPlayingTrack.value;

    nowPlayingTrack.value = track;
    WaveformController.inst.generateWaveform(track);
    // await CurrentColor.inst.updatePlayerColor(track);

    /// for video
    if (SettingsController.inst.enableVideoPlayback.value) {
      VideoController.inst.updateLocalVidPath(track);
    }
    await updateVideoPlayingState();
  }

  Future<void> updateVideoPlayingState() async {
    await refreshVideoPosition();
    if (isPlaying.value) {
      VideoController.inst.play();
    } else {
      VideoController.inst.pause();
    }
    await refreshVideoPosition();
    // await VideoController.inst.vidcontroller?.setVolume(0.0);
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

  /// TODO: Improve
  Future<void> addToQueue(List<Track> tracks, {bool insertNext = false}) async {
    List<Track> finalQueue = [];
    if (insertNext) {
      // finalQueue.insertAll(currentIndex.value + 1, tracks);
      finalQueue = [...currentQueue.getRange(0, currentIndex.value + 1), ...tracks, ...currentQueue.getRange(currentIndex.value + tracks.length, currentQueue.length)];
      currentQueue.assignAll(finalQueue);
      await playlist?.value.insertAll(currentIndex.value + 1, tracks.map((e) => e.toAudioSource).toList());
      printInfo(info: finalQueue.map((e) => e.title).toString());
    } else {
      // finalQueue.addAll(tracks);
      finalQueue = [...currentQueue, ...tracks];
      currentQueue.assignAll(finalQueue);
      await playlist?.value.addAll(tracks.map((e) => e.toAudioSource).toList());
    }

    // await player.setAudioSource(_getAudioSourcePlaylist(finalQueue),
    //     initialIndex: currentQueue.indexOf(nowPlayingTrack.value), initialPosition: Duration(milliseconds: nowPlayingPosition.value));

    QueueController.inst.updateLatestQueue(currentQueue.toList());
  }

  Future<void> setVolume(double volume) async {
    await player.setVolume(volume);
  }

  bool wantToPause = false;
  Future<void> play() async {
    wantToPause = false;
    if (!SettingsController.inst.enableVolumeFadeOnPlayPause.value) {
      player.play();
      return;
    }
    final duration = SettingsController.inst.playerPlayFadeDurInMilli.value;
    final interval = (0.1 * duration).toInt();
    final steps = duration ~/ interval;
    double vol = 0.0;
    player.play();
    Timer.periodic(Duration(milliseconds: interval), (timer) {
      vol += 1 / steps;
      printInfo(info: "VOLLLLLLLL PLAY ${vol.toString()}");
      setVolume(vol);
      if (vol >= SettingsController.inst.playerVolume.value || wantToPause) {
        timer.cancel();
      }
    });
  }

  Future<void> pause() async {
    wantToPause = true;
    if (!SettingsController.inst.enableVolumeFadeOnPlayPause.value) {
      player.pause();
      return;
    }
    // final AudioPlayer _player2 = AudioPlayer();
    // try {
    //   final track = nowPlayingTrack.value;
    //   player.stop();
    //   await _player2.setAudioSource(_getAudioSourcePlaylist([track]), initialPosition: nowPlayingPosition.value.milliseconds);

    //   _player2.play();
    // } catch (e) {
    //   printError(info: e.toString());
    // }
    // player.pause();
    // print('VOLLLLLLLL${_player2.audioSource?.sequence.first.tag}');

    final duration = SettingsController.inst.playerPauseFadeDurInMilli.value;
    final interval = (0.1 * duration).toInt();
    final steps = duration ~/ interval;
    double vol = player.volume;
    Timer.periodic(Duration(milliseconds: interval), (timer) {
      vol -= 1 / steps;
      printInfo(info: "VOLLLLLLLL PAUSE ${vol.toString()}");
      setVolume(vol);
      if (vol <= 0.0) {
        timer.cancel();
        player.pause();
      }
    });
    setVolume(player.volume);
  }

  Future<void> next() async {
    if (player.hasNext) {
      await player.seekToNext();
    } else {
      skipToQueueItem(index: 0);
    }
  }

  Future<void> previous() async {
    if (player.hasPrevious) {
      await player.seekToPrevious();
    } else {
      skipToQueueItem(index: currentQueue.length - 1);
    }
  }

  /// Either index or track has to be assigned, otherwise falls back to index 0
  Future<void> skipToQueueItem({Track? track, int? index}) async {
    if (index == null && track == null) {
      index = 0;
    }
    await player.seek(const Duration(microseconds: 0), index: index ?? currentQueue.indexOf(track));
    player.play();
    player.setVolume(SettingsController.inst.playerVolume.value);
  }

  Future<void> seek(Duration position, {int? index}) async {
    await player.seek(position, index: index);
    VideoController.inst.seek(position, index: index);
  }

  Future<void> playOrPause({Track? track, List<Track> queue = const [], bool playSingle = false, bool shuffle = false, bool disablePlay = false}) async {
    track ??= nowPlayingTrack.value;

    if (queue.isEmpty) {
      if (player.playerState.playing) {
        nowPlayingPosition.value = player.position.inMilliseconds;

        await pause();
      } else {
        await play();
        await seek(Duration(milliseconds: nowPlayingPosition.value));
      }
      return;
    }
    List<Track> finalQueue = <Track>[];

    if (playSingle) {
      finalQueue.assign(track);
    } else {
      finalQueue.assignAll(queue);
    }
    if (shuffle) {
      finalQueue.shuffle();
      track = finalQueue.first;
    }

    /// if the queue is the same, it will skip instead of rebuilding the queue, certainly more performant
    if (const IterableEquality().equals(finalQueue, currentQueue.toList())) {
      await skipToQueueItem(track: track);
      printInfo(info: "Skipped");
      return;
    }
    nowPlayingTrack.value = track;

    /// saves queue to storage before changing it
    QueueController.inst.addNewQueue(tracks: currentQueue.toList());

    currentQueue.assignAll(finalQueue);

    player.setAudioSource(_getAudioSourcePlaylist(finalQueue), initialIndex: finalQueue.indexOf(track), initialPosition: Duration.zero);
    if (!disablePlay) {
      player.play();
      player.setVolume(SettingsController.inst.playerVolume.value);
    }
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

extension AUDIOSOURCEPLAYLIST on Track {
  AudioSource get toAudioSource {
    return AudioSource.uri(
      Uri.parse(path),
      tag: MediaItem(
        id: path,
        title: title,
        displayTitle: title,
        displaySubtitle: "${artistsList.take(3).join(', ')} - $album",
        displayDescription: "${Player.inst.currentQueue.indexOf(this) + 1}/${Player.inst.currentQueue.length}",
        artist: artistsList.take(3).join(', '),
        album: album,
        genre: genresList.take(3).join(', '),
        duration: Duration(milliseconds: duration),
        artUri: Uri.file(pathToImage),
      ),
    );
  }
}
