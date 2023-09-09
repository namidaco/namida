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
import 'package:namida/core/namida_converter_ext.dart';
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

  int get totalListenedTimeInSec => _audioHandler.totalListenedTimeInSec;

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
    setSkipSilenceEnabled(settings.playerSkipSilenceEnabled.value);
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
    Iterable<Selectable> tracks, {
    QueueInsertionType? insertionType,
    bool insertNext = false,
    bool insertAfterLatest = false,
    bool showSnackBar = true,
    String? emptyTracksMessage,
  }) {
    final insertionDetails = insertionType?.toQueueInsertion();
    final shouldInsertNext = insertionDetails?.insertNext ?? insertNext;
    final maxCount = insertionDetails?.numberOfTracks == 0 ? null : insertionDetails?.numberOfTracks;
    final finalTracks = List<Selectable>.from(tracks.withLimit(maxCount));
    insertionType?.shuffleOrSort(finalTracks);

    if (showSnackBar && finalTracks.isEmpty) {
      Get.snackbar(lang.NOTE, emptyTracksMessage ?? lang.NO_TRACKS_FOUND);
      return false;
    }
    _audioHandler.addToQueue(
      finalTracks,
      insertNext: shouldInsertNext,
      insertAfterLatest: insertAfterLatest,
    );
    if (showSnackBar) {
      final addins = shouldInsertNext ? lang.INSERTED : lang.ADDED;
      Get.snackbar(lang.NOTE, '${addins.capitalizeFirst} ${finalTracks.displayTrackKeyword}');
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

  Future<void> replaceTracksDirectoryInQueue(String oldDir, String newDir, {Iterable<String>? forThesePathsOnly, bool ensureNewFileExists = false}) async {
    String getNewPath(String old) => old.replaceFirst(oldDir, newDir);
    await _audioHandler.replaceWhereInQueue(
      (e) {
        final trackPath = e.track.path;
        if (ensureNewFileExists) {
          if (!File(getNewPath(trackPath)).existsSync()) return false;
        }
        final firstC = forThesePathsOnly != null ? forThesePathsOnly.contains(e.track.path) : true;
        final secondC = trackPath.startsWith(oldDir);
        return firstC && secondC;
      },
      (old) {
        final newtr = Track(getNewPath(old.track.path));
        if (old is TrackWithDate) {
          return TrackWithDate(
            dateAdded: old.dateAdded,
            track: newtr,
            source: old.source,
          );
        } else {
          return newtr;
        }
      },
    );
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
      if (settings.isSeekDurationPercentage.value) {
        final sFromP = nowPlayingTrack.track.duration * (settings.seekDurationInPercentage.value / 100);
        newSeconds = sFromP.toInt();
      } else {
        newSeconds = settings.seekDurationInSeconds.value;
      }
    }
    return newSeconds;
  }

  Future<void> playOrPause(
    int index,
    Iterable<Selectable> queue,
    QueueSource source, {
    HomePageItems? homePageItem,
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
          QueueController.inst.addNewQueue(source: source, homePageItem: homePageItem, tracks: trs);
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
