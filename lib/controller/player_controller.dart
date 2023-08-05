import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/audio_handler.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/language.dart';

class Player {
  static Player get inst => _instance;
  static final Player _instance = Player._internal();
  Player._internal();

  late NamidaAudioVideoHandler _audioHandler;

  Track get nowPlayingTrack => _audioHandler.currentTrack.track;
  Selectable get nowPlayingTWD => _audioHandler.currentTrack;
  UnmodifiableListView<Selectable> get currentQueue => _audioHandler.currentQueue;
  int get currentIndex => _audioHandler.currentIndex;
  int get nowPlayingPosition => _audioHandler.currentPositionMS;
  bool get isPlaying => _audioHandler.isPlaying;
  int get numberOfRepeats => _audioHandler.numberOfRepeats;
  int get latestInsertedIndex => _audioHandler.latestInsertedIndex;

  bool get enableSleepAfterTracks => _audioHandler.enableSleepAfterTracks;
  bool get enableSleepAfterMins => _audioHandler.enableSleepAfterMins;
  int get sleepAfterMin => _audioHandler.sleepAfterMin;
  int get sleepAfterTracks => _audioHandler.sleepAfterTracks;

  final RxInt totalListenedTimeInSec = 0.obs;

  bool isSleepingTrack(int queueIndex) => enableSleepAfterTracks && sleepAfterTracks + currentIndex - 1 == queueIndex;

  Future<void> initializePlayer() async {
    _audioHandler = await AudioService.init(
      builder: () => NamidaAudioVideoHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.msob7y.namida',
        androidNotificationChannelName: 'Namida',
        androidNotificationChannelDescription: 'Namida Media Notification',
        androidNotificationIcon: 'drawable/ic_stat_musicnote',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: false,
      ),
      cacheKeyResolver: (mediaItem) {
        final imagePath = mediaItem.artUri?.path;
        return imagePath != null ? File(imagePath).statSync().toString() : '';
      },
    );
    prepareTotalListenTime();
    setSkipSilenceEnabled(SettingsController.inst.playerSkipSilenceEnabled.value);
  }

  void refreshNotification() {
    _audioHandler.notificationUpdateItem();
  }

  Future<void> setSkipSilenceEnabled(bool enabled) async {
    await _audioHandler.setSkipSilenceEnabled(enabled);
  }

  void refreshRxVariables() {
    _audioHandler.refreshRxVariables();
  }

  void updateNumberOfRepeats(int newNumber) {
    _audioHandler.updateNumberOfRepeats(newNumber);
  }

  void updateSleepTimerValues({
    bool? enableSleepAfterTracks,
    bool? enableSleepAfterMins,
    int? sleepAfterMin,
    int? sleepAfterTracks,
  }) {
    _audioHandler.updateSleepTimerValues(
      enableSleepAfterTracks: enableSleepAfterTracks,
      enableSleepAfterMins: enableSleepAfterMins,
      sleepAfterMin: sleepAfterMin,
      sleepAfterTracks: sleepAfterTracks,
    );
  }

  void resetSleepAfterTimer() {
    _audioHandler.resetSleepAfterTimer();
  }

  Future<void> updateVideoPlayingState() async {
    await _audioHandler.updateVideoPlayingState();
  }

  Future<void> setVolume(double volume) async {
    await _audioHandler.setVolume(volume);
  }

  void reorderTrack(int oldIndex, int newIndex) {
    _audioHandler.reorderItems(oldIndex, newIndex);
  }

  FutureOr<void> shuffleTracks(bool allTracks) async {
    if (allTracks) {
      await _audioHandler.shuffleAllItems((element) => element.track);
      MiniPlayerController.inst.animateQueueToCurrentTrack(jump: true);
    } else {
      await _audioHandler.shuffleNextItems();
    }
  }

  // void shuffleAllQueue() {
  //   _audioHandler?.shuffleAllQueue();
  // }

  int removeDuplicatesFromQueue() {
    return _audioHandler.removeDuplicatesFromQueue((element) => element.track);
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
    _audioHandler.addToQueue(
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
    _audioHandler.insertInQueue(tracks, index);
  }

  Future<void> removeFromQueue(int index) async {
    await _audioHandler.removeFromQueue(index, _audioHandler.defaultShouldStartPlaying);
  }

  Future<void> replaceAllTracksInQueue(Track oldTrack, Track newTrack) async {
    await _audioHandler.replaceAllItemsInQueue(oldTrack, newTrack);
  }

  void removeRangeFromQueue(int start, int end) {
    _audioHandler.removeRangeFromQueue(start, end);
  }

  Future<void> play() async {
    await _audioHandler.play();
  }

  Future<void> pause() async {
    await _audioHandler.pause();
  }

  Future<void> next() async {
    await _audioHandler.skipToNext();
  }

  Future<void> previous() async {
    await _audioHandler.skipToPrevious();
  }

  Future<void> skipToQueueItem(int index) async {
    _audioHandler.skipToQueueItem(index);
  }

  Future<void> seek(Duration position) async {
    await _audioHandler.seek(position);
  }

  /// Default value is set to user preference [seekDurationInSeconds]
  Future<void> seekSecondsForward([int? seconds]) async {
    final newSeconds = _secondsToSeek(seconds);
    await _audioHandler.seek(Duration(milliseconds: nowPlayingPosition + newSeconds * 1000));
  }

  /// Default value is set to user preference [seekDurationInSeconds]
  Future<void> seekSecondsBackward([int? seconds]) async {
    final newSeconds = _secondsToSeek(seconds);
    await _audioHandler.seek(Duration(milliseconds: nowPlayingPosition - newSeconds * 1000));
  }

  int _secondsToSeek([int? seconds]) {
    int? newSeconds = seconds;
    if (newSeconds == null) {
      if (SettingsController.inst.isSeekDurationPercentage.value) {
        final sFromP = nowPlayingTrack.track.duration * (SettingsController.inst.seekDurationInPercentage.value / 100);
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
    _audioHandler.assignNewQueue(
      playAtIndex: index,
      queue: queue,
      maximumItems: 1000,
      onIndexAndQueueSame: _audioHandler.togglePlayPause,
      onQueueDifferent: (finalizedQueue) {
        if (addAsNewQueue) {
          final trs = finalizedQueue.tracks.toList();
          QueueController.inst.addNewQueue(source: source, tracks: trs);
          QueueController.inst.updateLatestQueue(trs);
        }
      },
      onQueueEmpty: _audioHandler.togglePlayPause,
      startPlaying: startPlaying,
      shuffle: shuffle,
    );
  }

  Future<void> prepareTotalListenTime() async {
    await _audioHandler.prepareTotalListenTime();
  }
}
