import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';

import 'package:namida/class/audio_cache_detail.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/audio_handler.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/youtube/class/youtube_id.dart';

class Player {
  static Player get inst => _instance;
  static final Player _instance = Player._internal();
  Player._internal();

  late NamidaAudioVideoHandler<Playable> _audioHandler;

  Map<String, List<AudioCacheDetails>> get audioCacheMap => _audioHandler.audioCacheMap;

  Track get nowPlayingTrack => _audioHandler.currentTrack.track;
  Selectable get nowPlayingTWD => _audioHandler.currentTrack;
  List<Selectable> get currentQueue => _audioHandler.currentQueueSelectable;

  YoutubeID? get nowPlayingVideoID => _audioHandler.currentVideo;
  List<YoutubeID> get currentQueueYoutube => _audioHandler.currentQueueYoutubeID;

  /// This should be used by [VideoController] to pause playback whenever the video is buffering.
  ///
  /// As for audio side, the [NamidaAudioVideoHandler] internally handles pauses/resumes.
  bool get shouldCareAboutAVSync => currentQueueYoutube.isNotEmpty;

  VideoInfo? get currentVideoInfo => _audioHandler.currentVideoInfo.value;
  YoutubeChannel? get currentChannelInfo => _audioHandler.currentChannelInfo.value;
  VideoOnlyStream? get currentVideoStream => _audioHandler.currentVideoStream.value;
  AudioOnlyStream? get currentAudioStream => _audioHandler.currentAudioStream.value;
  File? get currentVideoThumbnail => _audioHandler.currentVideoThumbnail.value;
  NamidaVideo? get currentCachedVideo => _audioHandler.currentCachedVideo.value;
  AudioCacheDetails? get currentCachedAudio => _audioHandler.currentCachedAudio.value;

  bool get isAudioOnlyPlayback => _audioHandler.isAudioOnlyPlayback;
  bool get isCurrentAudioFromCache => _audioHandler.isCurrentAudioFromCache;

  Stream<int> get positionStream => _audioHandler.positionStream;
  int get currentIndex => _audioHandler.currentIndex;
  int get nowPlayingPosition => _audioHandler.currentPositionMS;
  double get currentSpeed => _audioHandler.currentSpeed;
  Duration? get currentItemDuration => _audioHandler.currentItemDuration;
  bool get isPlaying => _audioHandler.isPlaying;
  bool get isBuffering => _audioHandler.isBuffering;
  bool get isLoading => _audioHandler.isLoading;
  bool get isFetchingInfo => _audioHandler.isFetchingInfo;
  bool get shouldShowLoadingIndicator => (isFetchingInfo && _audioHandler.currentCachedVideo.value == null) || isBuffering || isLoading;
  Duration get buffered => _audioHandler.buffered;
  int get numberOfRepeats => _audioHandler.numberOfRepeats;
  int get latestInsertedIndex => _audioHandler.latestInsertedIndex;

  bool get enableSleepAfterTracks => _audioHandler.enableSleepAfterItems;
  bool get enableSleepAfterMins => _audioHandler.enableSleepAfterMins;
  int get sleepAfterMin => _audioHandler.sleepAfterMin;
  int get sleepAfterTracks => _audioHandler.sleepAfterItems;
  bool get isLastItem => _audioHandler.isLastItem;
  bool get canJumpToNext => !isLastItem || settings.playerInfiniyQueueOnNextPrevious.value;
  bool get canJumpToPrevious => currentIndex != 0 || settings.playerInfiniyQueueOnNextPrevious.value;

  int get totalListenedTimeInSec => _audioHandler.totalListenedTimeInSec;

  int get sleepingTrackIndex => sleepAfterTracks + currentIndex - 1;

  Color? get latestExtractedColor => _audioHandler.latestExtractedColor;

  // -- error playing track
  void cancelPlayErrorSkipTimer() => _audioHandler.cancelPlayErrorSkipTimer();
  int get playErrorRemainingSecondsToSkip => _audioHandler.playErrorRemainingSecondsToSkip;

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
    AudioService.notificationClicked.listen((clicked) {
      if (clicked) {
        switch (settings.onNotificationTapAction.value) {
          case NotificationTapAction.openApp:
            break;
          case NotificationTapAction.openMiniplayer:
            MiniPlayerController.inst.snapToExpanded();
            break;
          case NotificationTapAction.openQueue:
            MiniPlayerController.inst.snapToQueue();
            break;
          default:
            null;
        }
      }
    });
  }

  void onVolumeChangeAddListener(String key, void Function(double musicVolume) fn) {
    _audioHandler.onVolumeChangeAddListener(key, fn);
  }

  void onVolumeChangeRemoveListener(String key) {
    _audioHandler.onVolumeChangeRemoveListener(key);
  }

  Future<void> prepareTotalListenTime() async {
    _audioHandler.prepareTotalListenTime();
  }

  void refreshNotification() {
    _audioHandler.refreshNotification();
  }

  Future<void> setAudioOnlyPlayback(bool audioOnly) async {
    await _audioHandler.setAudioOnlyPlayback(audioOnly);
  }

  Future<void> setSkipSilenceEnabled(bool enabled) async {
    await _audioHandler.setSkipSilenceEnabled(enabled);
  }

  Future<void> setPlayerPitch(double value) async {
    await _audioHandler.setPlayerPitch(value);
  }

  Future<void> setPlayerSpeed(double value) async {
    await _audioHandler.setPlayerSpeed(value);
  }

  Future<void> setPlayerVolume(double value) async {
    await _audioHandler.setPlayerVolume(value);
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
      enableSleepAfterItems: enableSleepAfterTracks,
      enableSleepAfterMins: enableSleepAfterMins,
      sleepAfterMin: sleepAfterMin,
      sleepAfterItems: sleepAfterTracks,
    );
  }

  void resetSleepAfterTimer() {
    _audioHandler.resetSleepAfterTimer();
  }

  Future<void> toggleVideoPlay() async {
    await _audioHandler.toggleVideoPlay();
  }

  Future<void> refreshVideoSeekPosition({bool delayed = false}) async {
    await _audioHandler.refreshVideoPosition(delayed);
  }

  Future<void> setVolume(double volume) async {
    await _audioHandler.setVolume(volume);
  }

  void reorderTrack(int oldIndex, int newIndex) {
    _audioHandler.reorderItems(oldIndex, newIndex);
  }

  FutureOr<void> shuffleTracks(bool allTracks) async {
    if (allTracks) {
      if (currentQueue.isNotEmpty) {
        _audioHandler.shuffleAllItems((element) => (element as Selectable).track);
      } else {
        _audioHandler.shuffleAllItems((element) => (element as YoutubeID).id);
      }
      MiniPlayerController.inst.animateQueueToCurrentTrack(jump: true);
    } else {
      await _audioHandler.shuffleNextItems();
    }
  }

  int removeDuplicatesFromQueue() {
    if (currentQueue.isNotEmpty) {
      return _audioHandler.removeDuplicatesFromQueue((element) => (element as Selectable).track);
    } else {
      return _audioHandler.removeDuplicatesFromQueue((element) => (element as YoutubeID).id);
    }
  }

  /// returns true if tracks aren't empty.
  bool addToQueue(
    Iterable<Playable> tracks, {
    QueueInsertionType? insertionType,
    bool insertNext = false,
    bool insertAfterLatest = false,
    bool showSnackBar = true,
    String? emptyTracksMessage,
  }) {
    if (tracks.firstOrNull is Selectable) {
      final insertionDetails = insertionType?.toQueueInsertion();
      final shouldInsertNext = insertionDetails?.insertNext ?? insertNext;
      final maxCount = insertionDetails?.numberOfTracks == 0 ? null : insertionDetails?.numberOfTracks;
      final finalTracks = List<Selectable>.from(tracks.withLimit(maxCount));
      insertionType?.shuffleOrSort(finalTracks);

      if (showSnackBar && finalTracks.isEmpty) {
        snackyy(title: lang.NOTE, message: emptyTracksMessage ?? lang.NO_TRACKS_FOUND);
        return false;
      }
      _audioHandler.addToQueue(
        finalTracks,
        insertNext: shouldInsertNext,
        insertAfterLatest: insertAfterLatest,
      );
      if (showSnackBar) {
        final addins = shouldInsertNext ? lang.INSERTED : lang.ADDED;
        snackyy(
          icon: shouldInsertNext ? Broken.redo : Broken.add_circle,
          message: '${addins.capitalizeFirst} ${finalTracks.displayTrackKeyword}',
        );
      }
      return true;
    } else if (tracks.firstOrNull is YoutubeID) {
      _audioHandler.addToQueue(
        tracks,
        insertNext: insertNext,
        insertAfterLatest: insertAfterLatest,
      );
      return true;
    }

    return false;
  }

  void insertInQueue(List<Playable> tracks, int index) {
    _audioHandler.insertInQueue(tracks, index);
  }

  Future<void> removeFromQueue(int index) async {
    // why [isPlaying] ? imagine removing while paused
    await _audioHandler.removeFromQueue(index, isPlaying && _audioHandler.defaultShouldStartPlaying);
  }

  Future<void> replaceAllTracksInQueue(Playable oldTrack, Playable newTrack) async {
    await _audioHandler.replaceAllItemsInQueue(oldTrack, newTrack);
  }

  Future<void> replaceTracksDirectoryInQueue(String oldDir, String newDir, {Iterable<String>? forThesePathsOnly, bool ensureNewFileExists = false}) async {
    String getNewPath(String old) => old.replaceFirst(oldDir, newDir);
    if (currentQueue.isNotEmpty) {
      await _audioHandler.replaceWhereInQueue(
        (e) {
          final trackPath = (e as Selectable).track.path;
          if (ensureNewFileExists) {
            if (!File(getNewPath(trackPath)).existsSync()) return false;
          }
          final firstC = forThesePathsOnly != null ? forThesePathsOnly.contains(e.track.path) : true;
          final secondC = trackPath.startsWith(oldDir);
          return firstC && secondC;
        },
        (old) {
          final newtr = Track(getNewPath((old as Selectable).track.path));
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
  }

  void removeRangeFromQueue(int start, int end) {
    _audioHandler.removeRangeFromQueue(start, end);
  }

  Future<void> onItemPlayYoutubeIDSetQuality({
    required VideoStream? stream,
    required File? cachedFile,
    required bool useCache,
    required String videoId,
    NamidaVideo? videoItem,
  }) async {
    await _audioHandler.onItemPlayYoutubeIDSetQuality(
      stream: stream,
      cachedFile: cachedFile,
      useCache: useCache,
      videoId: videoId,
      videoItem: videoItem,
    );
  }

  Future<void> onItemPlayYoutubeIDSetAudio({
    required AudioOnlyStream? stream,
    required File? cachedFile,
    bool useCache = true,
    required String videoId,
  }) async {
    await _audioHandler.onItemPlayYoutubeIDSetAudio(
      stream: stream,
      cachedFile: cachedFile,
      useCache: useCache,
      videoId: videoId,
    );
  }

  Future<void> play() async {
    await _audioHandler.play();
  }

  Future<void> playRaw() async {
    await _audioHandler.onPlayRaw();
  }

  Future<void> pause() async {
    await _audioHandler.pause();
  }

  Future<void> dispose() async {
    await _audioHandler.onDispose();
  }

  Future<void> clearQueue() async {
    await _audioHandler.clearQueue();
  }

  Future<void> pauseRaw() async {
    await _audioHandler.onPauseRaw();
  }

  Future<void> togglePlayPause() async {
    await _audioHandler.togglePlayPause();
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
  Future<void> seekSecondsForward({int? seconds, void Function(int finalSeconds)? onSecondsReady}) async {
    final newSeconds = _secondsToSeek(seconds);
    onSecondsReady?.call(newSeconds);
    await _audioHandler.seek(Duration(milliseconds: nowPlayingPosition + newSeconds * 1000));
  }

  /// Default value is set to user preference [seekDurationInSeconds]
  Future<void> seekSecondsBackward({int? seconds, void Function(int finalSeconds)? onSecondsReady}) async {
    final newSeconds = _secondsToSeek(seconds);
    onSecondsReady?.call(newSeconds);
    await _audioHandler.seek(Duration(milliseconds: nowPlayingPosition - newSeconds * 1000));
  }

  int _secondsToSeek([int? seconds]) {
    int? newSeconds = seconds;
    if (newSeconds == null) {
      if (settings.isSeekDurationPercentage.value) {
        final sFromP = (currentItemDuration?.inSeconds ?? 0) * (settings.seekDurationInPercentage.value / 100);
        newSeconds = sFromP.toInt();
      } else {
        newSeconds = settings.seekDurationInSeconds.value;
      }
    }
    return newSeconds == 0 ? 5 : newSeconds;
  }

  Future<void> playOrPause<Q extends Playable>(
    int index,
    Iterable<Q> queue,
    QueueSource source, {
    HomePageItems? homePageItem,
    bool shuffle = false,
    bool startPlaying = true,
    bool addAsNewQueue = true,
  }) async {
    await _audioHandler.assignNewQueue(
      playAtIndex: index,
      queue: queue,
      maximumItems: 1000,
      onIndexAndQueueSame: _audioHandler.togglePlayPause,
      onQueueDifferent: (finalizedQueue) {
        if (queue.firstOrNull is Selectable) {
          if (addAsNewQueue) {
            final trs = finalizedQueue.cast<Selectable>().tracks.toList();
            QueueController.inst.addNewQueue(source: source, homePageItem: homePageItem, tracks: trs);
            QueueController.inst.updateLatestQueue(trs);
          }
        }
      },
      onQueueEmpty: _audioHandler.togglePlayPause,
      startPlaying: startPlaying,
      shuffle: shuffle,
    );
  }
}
