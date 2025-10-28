// ignore_for_file: avoid_rx_value_getter_outside_obx
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:audio_service/audio_service.dart';
import 'package:basic_audio_handler/basic_audio_handler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtipie/class/streams/audio_stream.dart';
import 'package:youtipie/class/streams/video_stream.dart';
import 'package:youtipie/class/streams/video_streams_result.dart';

import 'package:namida/base/audio_handler.dart';
import 'package:namida/class/audio_cache_detail.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/namida_channel/namida_channel.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/controller/wakelock_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/yt_utils.dart';

class Player {
  static Player get inst => _instance;
  static final Player _instance = Player._internal();
  Player._internal();

  late NamidaAudioVideoHandler<Playable> _audioHandler;

  RxBaseCore<bool> get playWhenReady => _audioHandler.playWhenReady;

  Selectable? get currentTrack {
    final item = _audioHandler.currentItem.value;
    return item is Selectable ? item : null;
  }

  Selectable? get currentTrackR {
    final item = _audioHandler.currentItem.valueR;
    return item is Selectable ? item : null;
  }

  YoutubeID? get currentVideo {
    final item = _audioHandler.currentItem.value;
    return item is YoutubeID ? item : null;
  }

  YoutubeID? get currentVideoR {
    final item = _audioHandler.currentItem.valueR;
    return item is YoutubeID ? item : null;
  }

  RxBaseCore<List<Playable>> get currentQueue => _audioHandler.currentQueue.queueRx;
  RxBaseCore<Playable?> get currentItem => _audioHandler.currentItem;

  RxBaseCore<VideoInfoData?> get videoPlayerInfo => _audioHandler.videoPlayerInfo;

  AndroidEqualizer get equalizer => _audioHandler.equalizer;
  AndroidLoudnessEnhancerExtended get loudnessEnhancer => _audioHandler.loudnessEnhancer;
  int? get androidSessionId => _audioHandler.androidSessionId;
  Rx<double> get replayGainLinearVolume => _audioHandler.replayGainLinearVolume;

  // RxBaseCore<VideoInfo?> get currentVideoInfo => _audioHandler.currentVideoInfo;
  // RxBaseCore<YoutubeChannel?> get currentChannelInfo => _audioHandler.currentChannelInfo;
  RxBaseCore<VideoStream?> get currentVideoStream => _audioHandler.currentVideoStream;
  RxBaseCore<AudioStream?> get currentAudioStream => _audioHandler.currentAudioStream;
  RxBaseCore<NamidaVideo?> get currentCachedVideo => _audioHandler.currentCachedVideo;
  RxBaseCore<AudioCacheDetails?> get currentCachedAudio => _audioHandler.currentCachedAudio;

  Duration get getCurrentVideoDurationR {
    Duration? playerDuration = currentItemDuration.valueR;
    if (playerDuration == null || playerDuration == Duration.zero) {
      playerDuration = currentAudioStream.valueR?.duration ??
          currentVideoStream.valueR?.duration ??
          (currentVideo == null
              ? VideoController.inst.currentVideo.valueR?.durationMS.milliseconds
              : YoutubeInfoController.current.currentYTStreams.valueR?.videoStreams.firstOrNull?.duration) ??
          Duration.zero;
    }
    return playerDuration;
  }

  Duration get getCurrentVideoDuration {
    Duration? playerDuration = currentItemDuration.value;
    if (playerDuration == null || playerDuration == Duration.zero) {
      playerDuration = currentAudioStream.value?.duration ??
          currentVideoStream.value?.duration ??
          (currentVideo == null
              ? VideoController.inst.currentVideo.value?.durationMS.milliseconds //
              : YoutubeInfoController.current.currentYTStreams.valueR?.videoStreams.firstOrNull?.duration) ??
          Duration.zero;
    }
    return playerDuration;
  }

  bool get isCurrentAudioFromCache => _audioHandler.isCurrentAudioFromCache;

  RxBaseCore<int> get currentIndex => _audioHandler.currentIndex;
  RxBaseCore<int> get nowPlayingPosition => _audioHandler.currentPositionMS;
  int get nowPlayingPositionR => _audioHandler.currentPositionMS.valueR;
  RxBaseCore<double> get currentSpeed => _audioHandler.currentSpeed;
  RxBaseCore<Duration?> get currentItemDuration => _audioHandler.currentItemDuration;
  RxBaseCore<bool> get isPlaying => _audioHandler.isPlaying;
  bool get isBufferingR => _audioHandler.currentState.valueR == ProcessingState.buffering;
  bool get isLoadingR => _audioHandler.currentState.valueR == ProcessingState.loading;
  RxBaseCore<bool> get isFetchingInfo => _audioHandler.isFetchingInfo;
  bool get shouldShowLoadingIndicatorR {
    if (isBufferingR || isLoadingR) return true;
    if (isFetchingInfo.valueR && _audioHandler.currentState.valueR != ProcessingState.ready) return true;
    return false;
  }

  RxBaseCore<Duration> get buffered => _audioHandler.buffered;
  RxBaseCore<int> get numberOfRepeats => _audioHandler.numberOfRepeats;
  int get latestInsertedIndex => _audioHandler.latestInsertedIndex;

  RxBaseCore<SleepTimerConfig> get sleepTimerConfig => _audioHandler.sleepTimerConfig;

  bool get canJumpToNext => !_audioHandler.isLastItem || settings.player.infiniyQueueOnNextPrevious.value;
  bool get canJumpToPrevious => currentIndex.value != 0 || settings.player.infiniyQueueOnNextPrevious.value;

  RxMap<String, int>? get totalListenedTimeInSec => _audioHandler.totalListenedTimeInSec;

  int sleepingItemIndex(int sleepAfterItems, int currentIndex) => sleepAfterItems + currentIndex - 1;

  bool get isModifyingQueue => _audioHandler.isModifyingQueue;

  // -- error playing track
  void cancelPlayErrorSkipTimer() => _audioHandler.cancelPlayErrorSkipTimer();
  RxBaseCore<int> get playErrorRemainingSecondsToSkip => _audioHandler.playErrorRemainingSecondsToSkip;

  StreamSubscription? _notificationClickedSub;

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
    );

    void videoInfoListener() {
      final info = _audioHandler.videoPlayerInfo.value;
      if (info == null || info.width == -1 || info.height == -1) {
        WakelockController.inst.updateVideoStatus(false);
      } else {
        WakelockController.inst.updateVideoStatus(true);
        NamidaChannel.inst.updatePipRatio(width: info.width, height: info.height);
      }
    }

    _audioHandler.videoPlayerInfo.removeListener(videoInfoListener);
    _audioHandler.videoPlayerInfo.addListener(videoInfoListener);
    _audioHandler.onVideoError = (e, _) {
      if (e is PlatformException) {
        final itemId = currentVideo?.id ?? currentTrack?.track.youtubeID;
        final button = itemId != null ? (lang.CLEAR_VIDEO_CACHE, () => const YTUtils().showVideoClearDialog(itemId)) : null;
        snackyy(message: e.details.toString().substring(0, 164), title: '${lang.ERROR}: ${e.message}', isError: true, top: false, button: button);
      }
    };

    prepareTotalListenTime();
    setSkipSilenceEnabled(settings.player.skipSilenceEnabled.value);
    if (NamidaFeaturesVisibility.displayArtworkOnLockscreen) AudioService.setLockScreenArtwork(settings.player.lockscreenArtwork.value);
    _notificationClickedSub?.cancel();
    _notificationClickedSub = AudioService.notificationClicked.listen((clicked) {
      if (clicked) {
        switch (settings.onNotificationTapAction.value) {
          case NotificationTapAction.openApp:
            break;
          case NotificationTapAction.openMiniplayer:
            MiniPlayerController.inst.snapToExpanded();
            final ytMiniplayer = MiniPlayerController.inst.ytMiniplayerKey.currentState;
            if (ytMiniplayer != null && ytMiniplayer.isExpanded == false) ytMiniplayer.animateToState(true);
            break;
          case NotificationTapAction.openQueue:
            MiniPlayerController.inst.snapToQueue();
            final ytMiniplayer = MiniPlayerController.inst.ytMiniplayerKey.currentState;
            if (ytMiniplayer != null && ytMiniplayer.isExpanded == false) ytMiniplayer.animateToState(true);
            Future.delayed(const Duration(milliseconds: 100), () {
              final ytQueue = NamidaNavigator.inst.ytQueueSheetKey.currentState;
              if (ytQueue != null && ytQueue.isOpened == false) ytQueue.openSheet();
            });

            break;
        }
      }
    });
    if (Platform.isAndroid || Platform.isIOS) _initializeEqualizer();
  }

  void _initializeEqualizer() async {
    final eq = settings.equalizer;
    _audioHandler.equalizer.setEnabled(eq.equalizerEnabled);
    if (eq.preset != null) {
      _audioHandler.equalizer.setPreset(eq.preset!);
    } else {
      if (eq.equalizer.isNotEmpty) {
        _audioHandler.equalizer.parameters.then((parameters) {
          parameters.bands.loop((b) {
            final userGain = eq.equalizer[b.centerFrequency];
            if (userGain != null) b.setGain(userGain);
          });
        });
      }
    }
    _audioHandler.loudnessEnhancer.setTargetGainUser(eq.loudnessEnhancer);
    _audioHandler.loudnessEnhancer.setEnabledUser(eq.loudnessEnhancerEnabled);
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
    await _audioHandler.setPlayerVolume(replayGainLinearVolume.value * value);
  }

  Future<void> setReplayGainLinearVolume(double vol) async {
    this.replayGainLinearVolume.value = vol;
    await this.setVolume(settings.player.volume.value); // refresh volume
  }

  double volumeUp() {
    final val = settings.player.volume.value;
    final newVal = (val + 0.05).withMaximum(1.0);
    setPlayerVolume(newVal);
    settings.player.save(volume: newVal);
    return newVal;
  }

  double volumeDown() {
    final val = settings.player.volume.value;
    final newVal = (val - 0.05).withMinimum(0.0);
    setPlayerVolume(newVal);
    settings.player.save(volume: newVal);
    return newVal;
  }

  void refreshRxVariables() {
    _audioHandler.refreshRxVariables();
  }

  void updateNumberOfRepeats(int newNumber) {
    _audioHandler.updateNumberOfRepeats(newNumber);
  }

  void updateSleepTimerValues({
    bool? enableSleepAfterItems,
    bool? enableSleepAfterMins,
    int? sleepAfterMin,
    int? sleepAfterItems,
  }) {
    _audioHandler.updateSleepTimerValues(
      enableSleepAfterItems: enableSleepAfterItems,
      enableSleepAfterMins: enableSleepAfterMins,
      sleepAfterMin: sleepAfterMin,
      sleepAfterItems: sleepAfterItems,
    );
  }

  void resetSleepAfterTimer() {
    _audioHandler.resetSleepTimer();
  }

  Future<void> setVolume(double volume) async {
    await _audioHandler.setVolume(replayGainLinearVolume.value * volume);
  }

  void invokeQueueModifyLock() {
    _audioHandler.invokeQueueModifyLock();
  }

  void invokeQueueModifyLockRelease() {
    _audioHandler.invokeQueueModifyLockRelease();
  }

  void invokeQueueModifyOnModifyCancel() {
    _audioHandler.invokeQueueModifyLockRelease(isCanceled: true);
  }

  void reorderTrack(int oldIndex, int newIndex) {
    _audioHandler.reorderItems(oldIndex, newIndex);
  }

  FutureOr<void> shuffleTracks(bool allTracks) async {
    if (allTracks) {
      currentItem.value?._execute(
        selectable: (_) {
          return _audioHandler.shuffleAllItems((element) => (element as Selectable).track);
        },
        youtubeID: (_) {
          return _audioHandler.shuffleAllItems((element) => (element as YoutubeID).id);
        },
      );

      MiniPlayerController.inst.animateQueueToCurrentTrack(jump: true, minZero: true);
    } else {
      await _audioHandler.shuffleNextItems();
    }
  }

  int removeDuplicatesFromQueue() {
    return currentItem.value?._execute<int>(
          selectable: (_) {
            return _audioHandler.removeDuplicatesFromQueue((element) => (element as Selectable).track);
          },
          youtubeID: (_) {
            return _audioHandler.removeDuplicatesFromQueue((element) => (element as YoutubeID).id);
          },
        ) ??
        0;
  }

  /// returns true if tracks aren't empty.
  Future<bool> addToQueue(
    Iterable<Playable> tracks, {
    QueueInsertionType? insertionType,
    bool insertNext = false,
    bool insertAfterLatest = false,
    bool showSnackBar = true,
    String? emptyTracksMessage,
  }) async {
    final insertionDetails = insertionType?.toQueueInsertion();
    final shouldInsertNext = insertionDetails?.insertNext ?? insertNext;
    final maxCount = insertionDetails?.numberOfTracks == 0 ? null : insertionDetails?.numberOfTracks;
    final newItem = tracks.firstOrNull;
    return await newItem?._execute(
          selectable: (_) async {
            final finalTracks = List<Selectable>.from(tracks.withLimit(maxCount));
            insertionType?.shuffleOrSort(finalTracks);

            if (showSnackBar && finalTracks.isEmpty) {
              snackyy(title: lang.NOTE, message: emptyTracksMessage ?? lang.NO_TRACKS_FOUND, top: false);
              return false;
            }
            await _audioHandler.addToQueue(
              finalTracks,
              insertNext: shouldInsertNext,
              insertAfterLatest: insertAfterLatest,
            );
            if (showSnackBar) {
              final addins = shouldInsertNext ? lang.INSERTED : lang.ADDED;
              snackyy(
                icon: shouldInsertNext ? Broken.redo : Broken.add_circle,
                message: '${addins.capitalizeFirst()} ${finalTracks.displayTrackKeyword}',
                top: false,
                displayDuration: SnackDisplayDuration.mediumLow,
                animationDurationMS: 400,
              );
            }
            return true;
          },
          youtubeID: (_) async {
            final finalVideos = List<YoutubeID>.from(tracks.withLimit(maxCount));
            insertionType?.shuffleOrSortYT(finalVideos);

            if (showSnackBar && finalVideos.isEmpty) {
              snackyy(title: lang.NOTE, message: emptyTracksMessage ?? lang.NO_TRACKS_FOUND, top: false);
              return false;
            }
            await _audioHandler.addToQueue(
              finalVideos,
              insertNext: shouldInsertNext,
              insertAfterLatest: insertAfterLatest,
            );
            if (showSnackBar) {
              final addins = shouldInsertNext ? lang.INSERTED : lang.ADDED;
              snackyy(
                icon: shouldInsertNext ? Broken.redo : Broken.add_circle,
                message: '${addins.capitalizeFirst()} ${finalVideos.length.displayVideoKeyword}',
                top: false,
                displayDuration: SnackDisplayDuration.mediumLow,
                animationDurationMS: 400,
              );
            }
            return true;
          },
        ) ??
        false;
  }

  Future<void> insertInQueue(Iterable<Playable> tracks, int index) async {
    await _audioHandler.insertInQueue(tracks, index);
  }

  SnackbarController? _latestSnacky;
  Future<void> removeFromQueueWithUndo(int index) async {
    _latestSnacky?.close();
    final item = this.currentQueue.value[index];
    this.removeFromQueue(index);
    _latestSnacky = snackyy(
      icon: Broken.rotate_left,
      title: lang.UNDO_CHANGES,
      message: lang.UNDO_CHANGES_DELETED_TRACK,
      top: false,
      button: (
        lang.UNDO,
        () => this.insertInQueue([item], index),
      ),
    );
  }

  Future<void> removeFromQueue(int index) async {
    // do not modify playWhenReady here, its useless
    await _audioHandler.removeFromQueue(index);
  }

  Future<void> replaceAllTracksInQueue(Playable oldTrack, Playable newTrack) async {
    await _audioHandler.replaceAllItemsInQueue(oldTrack, newTrack);
  }

  Future<void> replaceAllTracksInQueueBulk(Map<Playable, Playable> oldNewTrack) async {
    await _audioHandler.replaceAllItemsInQueueBulk(oldNewTrack);
  }

  Future<void> replaceTracksDirectoryInQueue(String oldDir, String newDir, {Iterable<String>? forThesePathsOnly, bool ensureNewFileExists = false}) async {
    String getNewPath(String old) => old.replaceFirst(oldDir, newDir);
    if (currentItem.value is Selectable) {
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
          old as Selectable;
          final newtr = Track.fromTypeParameter(old.track.runtimeType, getNewPath(old.track.path));
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
    required VideoStreamsResult? mainStreams,
    required VideoStream? stream,
    required File? cachedFile,
    required bool useCache,
    required String videoId,
    NamidaVideo? videoItem,
  }) async {
    await _audioHandler.onItemPlayYoutubeIDSetQuality(
      mainStreams: mainStreams,
      stream: stream,
      cachedFile: cachedFile,
      useCache: useCache,
      videoId: videoId,
      videoItem: videoItem,
    );
  }

  Future<void> onItemPlayYoutubeIDSetAudio({
    required VideoStreamsResult? mainStreams,
    required AudioStream? stream,
    required File? cachedFile,
    bool useCache = true,
    required String videoId,
  }) async {
    await _audioHandler.onItemPlayYoutubeIDSetAudio(
      mainStreams: mainStreams,
      stream: stream,
      cachedFile: cachedFile,
      useCache: useCache,
      videoId: videoId,
    );
  }

  Future<void> recheckCachedVideos(String videoId) {
    return _audioHandler.recheckCachedVideos(videoId);
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
    await _audioHandler.onDispose().ignoreError();
    await _audioHandler.clearQueue();
  }

  Future<void> resetGaplessPlaybackData() async {
    await _audioHandler.resetGaplessPlaybackData();
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
    _audioHandler.setPlayWhenReady(true);
    await _audioHandler.skipToQueueItem(index);
  }

  Future<void> seek(Duration position) async {
    await _audioHandler.seek(position);
  }

  /// Default value is set to user preference [seekDurationInSeconds]
  Future<void> seekSecondsForward({int? seconds, void Function(int finalSeconds)? onSecondsReady}) async {
    final newSeconds = _secondsToSeek(seconds);
    onSecondsReady?.call(newSeconds);
    await _audioHandler.seek(Duration(milliseconds: nowPlayingPosition.value + newSeconds * 1000));
  }

  /// Default value is set to user preference [seekDurationInSeconds]
  Future<void> seekSecondsBackward({int? seconds, void Function(int finalSeconds)? onSecondsReady}) async {
    final newSeconds = _secondsToSeek(seconds);
    onSecondsReady?.call(newSeconds);
    await _audioHandler.seek(Duration(milliseconds: nowPlayingPosition.value - newSeconds * 1000));
  }

  int _secondsToSeek([int? seconds]) {
    int? newSeconds = seconds;
    if (newSeconds == null) {
      if (settings.player.isSeekDurationPercentage.value) {
        final sFromP = (currentItemDuration.value?.inSeconds ?? 0) * (settings.player.seekDurationInPercentage.value / 100);
        newSeconds = sFromP.toInt();
      } else {
        newSeconds = settings.player.seekDurationInSeconds.value;
      }
    }
    return newSeconds == 0 ? 5 : newSeconds;
  }

  Future<void> playOrPause<Q extends Playable>(
    int index,
    Iterable<Q> queue,
    QueueSourceBase source, {
    HomePageItems? homePageItem,
    bool shuffle = false,
    bool startPlaying = true,
    bool updateQueue = true,
    int? maximumItems,
    void Function(Playable currentItem)? onAssigningCurrentItem,

    /// add items next and play them instead of assigning them as a new queue
    bool gentlePlay = false,
  }) async {
    if (gentlePlay) {
      _audioHandler.setPlayWhenReady(startPlaying);
      await addToQueue(
        queue,
        insertNext: true,
        showSnackBar: false,
      );
      await next();
      return;
    }
    await _audioHandler.assignNewQueue(
      playAtIndex: index,
      queue: queue,
      maximumItems: maximumItems,
      onIndexAndQueueSame: _audioHandler.togglePlayPause,
      onQueueDifferent: (finalizedQueue) {
        if (updateQueue) {
          if (queue.firstOrNull is Selectable) {
            try {
              final trs = finalizedQueue.cast<Selectable>().tracks.toList();
              QueueController.inst.addNewQueue(source: source, homePageItem: homePageItem, tracks: trs);
            } catch (_) {
              // -- is mixed queue
            }
          }
          QueueController.inst.updateLatestQueue(finalizedQueue);
        }
      },
      onQueueEmpty: _audioHandler.togglePlayPause,
      startPlaying: startPlaying,
      shuffle: shuffle,
      onAssigningCurrentItem: onAssigningCurrentItem,
      duplicateRemover: source == QueueSource.history || source == QueueSourceYoutubeID.history
          ? (item) {
              return item._execute(
                selectable: (finalItem) => finalItem.track.path,
                youtubeID: (finalItem) => finalItem.id,
              );
            }
          : null,
    );
  }

  // ------- video -------

  Future<void> tryGenerateWaveform(YoutubeID? video) async {
    return _audioHandler.tryGenerateWaveform(video);
  }

  Future<void> setVideo({required AudioVideoSource source, bool loopingAnimation = false, required bool isFile, bool videoOnly = false}) async {
    await _audioHandler.setVideoSource(source: source, loopingAnimation: loopingAnimation, isFile: isFile, videoOnly: videoOnly);
  }

  Future<void> disposeVideo() async {
    await _audioHandler.setVideo(null);
  }
}

// -- duplicated from audio_handler.dart but not a FutureOr<T>
extension _PlayableExecuter on Playable {
  T? _execute<T>({
    required T Function(Selectable finalItem) selectable,
    required T Function(YoutubeID finalItem) youtubeID,
  }) {
    final item = this;
    if (item is Selectable) {
      return selectable(item);
    } else if (item is YoutubeID) {
      return youtubeID(item);
    }
    return null;
  }
}
