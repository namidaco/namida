import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/audio_handler.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/translations/language.dart';

class Player {
  static Player get inst => _instance;
  static final Player _instance = Player._internal();
  Player._internal();

  NamidaAudioVideoHandler? _audioHandler;

  final Rx<Track> nowPlayingTrack = kDummyTrack.obs;
  final RxList<Selectable> currentQueue = <Selectable>[].obs;
  final RxInt currentIndex = 0.obs;
  final RxDouble currentVolume = SettingsController.inst.playerVolume.value.obs;
  final RxBool isPlaying = false.obs;
  final RxInt nowPlayingPosition = 0.obs;
  final RxInt numberOfRepeats = 1.obs;
  int latestInsertedIndex = 0;

  final RxBool enableSleepAfterTracks = false.obs;
  final RxBool enableSleepAfterMins = false.obs;
  final RxInt sleepAfterMin = 0.obs;
  final RxInt sleepAfterTracks = 0.obs;

  final RxInt totalListenedTimeInSec = 0.obs;

  bool isSleepingTrack(int queueIndex) => enableSleepAfterTracks.value && sleepAfterTracks.value + currentIndex.value - 1 == queueIndex;

  Future<void> initializePlayer() async {
    _audioHandler = await AudioService.init(
      builder: () => NamidaAudioVideoHandler(this),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.msob7y.namida',
        androidNotificationChannelName: 'Namida',
        androidNotificationChannelDescription: 'Namida Media Notification',
        androidNotificationIcon: 'drawable/ic_stat_musicnote',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: false,
      ),
    );
    prepareTotalListenTime();
    setSkipSilenceEnabled(SettingsController.inst.playerSkipSilenceEnabled.value);
  }

  void updateMediaItemForce() {
    _audioHandler?.updateCurrentMediaItem(null, true);
  }

  Future<void> setSkipSilenceEnabled(bool enabled) async {
    await _audioHandler?.setSkipSilenceEnabled(enabled);
  }

  void resetSleepAfterTimer() {
    enableSleepAfterMins.value = false;
    enableSleepAfterTracks.value = false;
    sleepAfterMin.value = 0;
    sleepAfterTracks.value = 0;
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

  // void shuffleAllQueue() {
  //   _audioHandler?.shuffleAllQueue();
  // }

  void removeDuplicatesFromQueue() {
    _audioHandler?.removeDuplicatesFromQueue();
  }

  /// returns true if tracks aren't empty.
  bool addToQueue(
    List<Selectable> tracks, {
    bool insertNext = false,
    bool insertAfterLatest = false,
    bool showSnackBar = true,
    String? emptyTracksMessage,
  }) {
    if (showSnackBar && tracks.isEmpty) {
      Get.snackbar(Language.inst.NOTE, emptyTracksMessage ?? Language.inst.NO_TRACKS_FOUND_BETWEEN_DATES);
      return false;
    }
    _audioHandler?.addToQueue(
      tracks,
      insertNext: insertNext,
      insertAfterLatest: insertAfterLatest,
    );
    if (showSnackBar) {
      final addins = insertNext ? Language.inst.INSERTED : Language.inst.ADDED;
      Get.snackbar(Language.inst.NOTE, '${addins.capitalizeFirst} ${tracks.displayTrackKeyword}');
    }
    return true;
  }

  void insertInQueue(List<Track> tracks, int index) {
    _audioHandler?.insertInQueue(tracks, index);
  }

  Future<void> removeFromQueue(int index) async {
    await _audioHandler?.removeFromQueue(index);
  }

  Future<void> replaceAllTracksInQueue(Track oldTrack, Track newTrack) async {
    await _audioHandler?.replaceAllTracksInQueue(oldTrack, newTrack);
  }

  void removeRangeFromQueue(int start, int end) {
    _audioHandler?.removeRangeFromQueue(start, end);
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

  /// Default value is set to user preference [seekDurationInSeconds]
  Future<void> seekSecondsForward([int? seconds]) async {
    final newSeconds = _secondsToSeek(seconds);
    await _audioHandler?.seek(Duration(milliseconds: nowPlayingPosition.value + newSeconds * 1000));
  }

  /// Default value is set to user preference [seekDurationInSeconds]
  Future<void> seekSecondsBackward([int? seconds]) async {
    final newSeconds = _secondsToSeek(seconds);
    await _audioHandler?.seek(Duration(milliseconds: nowPlayingPosition.value - newSeconds * 1000));
  }

  int _secondsToSeek([int? seconds]) {
    int? newSeconds = seconds;
    if (newSeconds == null) {
      if (SettingsController.inst.isSeekDurationPercentage.value) {
        final sFromP = nowPlayingTrack.value.duration * (SettingsController.inst.seekDurationInPercentage.value / 100);
        newSeconds = sFromP.toInt();
      } else {
        newSeconds = SettingsController.inst.seekDurationInSeconds.value;
      }
    }
    return newSeconds;
  }

  Future<void> playOrPause(
    int index,
    List<Selectable> queue,
    QueueSource source, {
    bool shuffle = false,
    bool startPlaying = true,
    bool addAsNewQueue = true,
  }) async {
    final finalQueue = <Selectable>[];

    /// maximum 1000 track for performance.
    if (queue.length > 1000 && !shuffle) {
      const trimCount = 500;

      // adding tracks after current index.
      final end = (index + trimCount).clamp(0, queue.length - 1);
      finalQueue.addAll(queue.sublist(index, end + 1));

      // inserting tracks before current index.
      final firstIndex = (index - trimCount).clamp(0, index);
      final initialTracks = queue.sublist(firstIndex, index);
      finalQueue.insertAll(0, initialTracks);

      // fixing index
      index = index - firstIndex;
    } else {
      finalQueue.addAll(queue);
    }

    if (finalQueue.isEmpty) {
      _audioHandler?.togglePlayPause();
      return;
    }

    final isQueueSame = checkIfQueueSameAsCurrent(finalQueue);

    if (index == currentIndex.value && isQueueSame) {
      _audioHandler?.togglePlayPause();
      return;
    }
    if (!isQueueSame) {
      latestInsertedIndex = index;
    }

    if (shuffle) {
      finalQueue.shuffle();
      final trimmedQueue = List<Selectable>.from(finalQueue.take(1000));
      finalQueue
        ..clear()
        ..addAll(trimmedQueue);
      index = 0;
    }

    /// if the queue is the same, it will skip instead of saving the same queue.
    if (addAsNewQueue && !isQueueSame) {
      final trs = finalQueue.tracks.toList();
      QueueController.inst.addNewQueue(source: source, tracks: trs);
      QueueController.inst.updateLatestQueue(trs);
    }

    currentQueue
      ..clear()
      ..addAll(finalQueue);

    await _audioHandler?.setAudioSource(index, startPlaying: startPlaying);
  }

  Future<void> prepareTotalListenTime() async {
    await _audioHandler?.prepareTotalListenTime();
  }
}
