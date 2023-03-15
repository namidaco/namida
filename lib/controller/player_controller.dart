import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/audio_handler.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';

class Player {
  static Player inst = Player();

  NamidaAudioVideoHandler? _audioHandler;

  Rx<Track> nowPlayingTrack = kDummyTrack.obs;
  RxList<Track> currentQueue = <Track>[].obs;
  RxInt currentIndex = 0.obs;
  RxDouble currentVolume = SettingsController.inst.playerVolume.value.obs;
  RxBool isPlaying = false.obs;
  RxInt nowPlayingPosition = 0.obs;

  Future<void> initializePlayer() async {
    _audioHandler = await AudioService.init(
      builder: () => NamidaAudioVideoHandler(this),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.msob7y.namida',
        androidNotificationChannelName: 'Namida',
        androidNotificationChannelDescription: 'Namida Media Notification',
        androidNotificationIcon: 'drawable/ic_stat_musicnote',
        androidStopForegroundOnPause: false,
      ),
    );
  }

  void updateMediaItemForce() {
    _audioHandler?.updateCurrentMediaItem(null, true);
  }

  Future<void> updateVideoPlayingState() async {
    await _audioHandler?.updateVideoPlayingState();
  }

  Future<void> setVolume(double volume) async {
    await _audioHandler?.setVolume(volume);
  }

  void reorderTrack(int oldIndex, int newIndex) {
    _audioHandler?.reorderTrack(oldIndex, newIndex);
  }

  void shuffleNextTracks() {
    _audioHandler?.shuffleNextTracks();
  }

  Future<void> addToQueue(List<Track> tracks, {bool insertNext = false}) async {
    await _audioHandler?.addToQueue(tracks, insertNext: insertNext);
  }

  Future<void> insertInQueue(List<Track> tracks, int index) async {
    await _audioHandler?.insertInQueue(tracks, index);
  }

  Future<void> removeFromQueue(int index) async {
    await _audioHandler?.removeFromQueue(index);
  }

  Future<void> removeRangeFromQueue(int start, int end) async {
    await _audioHandler?.removeRangeFromQueue(start, end);
  }

  Future<void> play() async {
    await _audioHandler?.play();
  }

  Future<void> pause() async {
    await _audioHandler?.pause();
  }

  Future<void> next() async {
    await _audioHandler?.skipToNext();
  }

  Future<void> previous() async {
    await _audioHandler?.skipToPrevious();
  }

  Future<void> skipToQueueItem(int index) async {
    _audioHandler?.skipToQueueItem(index);
  }

  Future<void> seek(Duration position) async {
    await _audioHandler?.seek(position);
  }

  Future<void> seekSecondsForward([int seconds = 5]) async {
    await _audioHandler?.seek(Duration(milliseconds: nowPlayingPosition.value + seconds * 1000));
  }

  Future<void> seekSecondsBackward([int seconds = 5]) async {
    await _audioHandler?.seek(Duration(milliseconds: nowPlayingPosition.value - seconds * 1000));
  }

  Future<void> playOrPause(
    int index,
    List<Track> queue, {
    bool shuffle = false,
    bool startPlaying = true,
    bool dontAddQueue = false,
  }) async {
    if (queue.isEmpty || index == currentIndex.value) {
      _audioHandler?.togglePlayPause();
      return;
    }

    List<Track> finalQueue = <Track>[];
    finalQueue.assignAll(queue);

    if (shuffle) {
      finalQueue.shuffle();
      index = 0;
    }

    if (!dontAddQueue) {
      QueueController.inst.addNewQueue(tracks: finalQueue.toList());
    }

    currentQueue.assignAll(finalQueue);
    await _audioHandler?.setAudioSource(index, startPlaying: startPlaying);
  }
}
