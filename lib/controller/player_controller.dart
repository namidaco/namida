// ignore_for_file: avoid_rx_value_getter_outside_obx
import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:basic_audio_handler/basic_audio_handler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:namida/core/utils.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';

import 'package:namida/class/audio_cache_detail.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/base/audio_handler.dart';
import 'package:namida/controller/settings.equalizer.dart';
import 'package:namida/controller/namida_channel.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/controller/wakelock_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';

class Player {
  static Player get inst => _instance;
  static final Player _instance = Player._internal();
  Player._internal();

  late NamidaAudioVideoHandler<Playable> _audioHandler;

  Map<String, List<AudioCacheDetails>> get audioCacheMap => _audioHandler.audioCacheMap;

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

  RxBaseCore<List<Playable>> get currentQueue => _audioHandler.currentQueue;
  Rx<Playable?> get currentItem => _audioHandler.currentItem;

  String get getCurrentVideoIdR => (YoutubeController.inst.currentYoutubeMetadataVideo.valueR ?? currentVideoInfo.valueR)?.id ?? currentVideoR?.id ?? '';
  String get getCurrentVideoId => (YoutubeController.inst.currentYoutubeMetadataVideo.value ?? currentVideoInfo.value)?.id ?? currentVideo?.id ?? '';

  RxBaseCore<VideoInfoData?> get videoPlayerInfo => _audioHandler.videoPlayerInfo;

  AndroidEqualizer get equalizer => _audioHandler.equalizer;
  AndroidLoudnessEnhancer get loudnessEnhancer => _audioHandler.loudnessEnhancer;
  int? get androidSessionId => _audioHandler.androidSessionId;

  RxBaseCore<VideoInfo?> get currentVideoInfo => _audioHandler.currentVideoInfo;
  RxBaseCore<YoutubeChannel?> get currentChannelInfo => _audioHandler.currentChannelInfo;
  RxBaseCore<VideoOnlyStream?> get currentVideoStream => _audioHandler.currentVideoStream;
  RxBaseCore<AudioOnlyStream?> get currentAudioStream => _audioHandler.currentAudioStream;
  RxBaseCore<NamidaVideo?> get currentCachedVideo => _audioHandler.currentCachedVideo;
  RxBaseCore<AudioCacheDetails?> get currentCachedAudio => _audioHandler.currentCachedAudio;

  Duration get getCurrentVideoDurationR {
    Duration? playerDuration = currentItemDuration.valueR;
    if (playerDuration == null || playerDuration == Duration.zero) {
      playerDuration = currentAudioStream.valueR?.durationMS?.milliseconds ??
          currentVideoStream.valueR?.durationMS?.milliseconds ??
          (currentVideo == null ? VideoController.inst.currentVideo.valueR?.durationMS.milliseconds : YoutubeController.inst.currentYoutubeMetadataVideo.valueR?.duration) ??
          Duration.zero;
    }
    return playerDuration;
  }

  Duration get getCurrentVideoDuration {
    Duration? playerDuration = Player.inst.currentItemDuration.value;
    if (playerDuration == null || playerDuration == Duration.zero) {
      playerDuration = currentAudioStream.value?.durationMS?.milliseconds ??
          currentVideoStream.value?.durationMS?.milliseconds ??
          (currentVideo == null ? VideoController.inst.currentVideo.value?.durationMS.milliseconds : YoutubeController.inst.currentYoutubeMetadataVideo.value?.duration) ??
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
  bool get isPlayingR => _audioHandler.isPlaying.valueR;
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

  void setPositionListener(void Function(int ms)? fn) {
    _audioHandler.positionListener = fn;
  }

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
      cacheKeyResolver: (mediaItem) {
        final imagePath = mediaItem.artUri?.path;
        return imagePath != null ? File(imagePath).statSync().toString() : '';
      },
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

    prepareTotalListenTime();
    setSkipSilenceEnabled(settings.player.skipSilenceEnabled.value);
    AudioService.setLockScreenArtwork(settings.player.lockscreenArtwork.value);
    _notificationClickedSub?.cancel();
    _notificationClickedSub = AudioService.notificationClicked.listen((clicked) {
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
    _initializeEqualizer();
  }

  void _initializeEqualizer() async {
    final eq = EqualizerSettings.inst;
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
    _audioHandler.loudnessEnhancer.setTargetGain(eq.loudnessEnhancer);
    _audioHandler.loudnessEnhancer.setEnabled(eq.loudnessEnhancerEnabled);
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
    bool? enableSleepAfterItems,
    bool? enableSleepAfterMins,
    int? sleepAfterMin,
    int? sleepAfterItems,
  }) {
    final oldConfig = sleepTimerConfig.value;
    final newConfig = SleepTimerConfig(
      enableSleepAfterItems: enableSleepAfterItems ?? oldConfig.enableSleepAfterItems,
      enableSleepAfterMins: enableSleepAfterMins ?? oldConfig.enableSleepAfterMins,
      sleepAfterMin: sleepAfterMin ?? oldConfig.sleepAfterMin,
      sleepAfterItems: sleepAfterItems ?? oldConfig.sleepAfterItems,
    );
    _audioHandler.sleepTimerConfig.value = newConfig;
  }

  void resetSleepAfterTimer() {
    _audioHandler.resetSleepTimer();
  }

  Future<void> setVolume(double volume) async {
    await _audioHandler.setVolume(volume);
  }

  void reorderTrack(int oldIndex, int newIndex) {
    _audioHandler.reorderItems(oldIndex, newIndex);
  }

  FutureOr<void> shuffleTracks(bool allTracks) async {
    if (allTracks) {
      if (currentItem is Selectable) {
        _audioHandler.shuffleAllItems((element) => (element as Selectable).track);
      } else {
        _audioHandler.shuffleAllItems((element) => (element as YoutubeID).id);
      }
      MiniPlayerController.inst.animateQueueToCurrentTrack(jump: true, minZero: true);
    } else {
      await _audioHandler.shuffleNextItems();
    }
  }

  int removeDuplicatesFromQueue() {
    if (currentItem is Selectable) {
      return _audioHandler.removeDuplicatesFromQueue((element) => (element as Selectable).track);
    } else {
      return _audioHandler.removeDuplicatesFromQueue((element) => (element as YoutubeID).id);
    }
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
    if (tracks.firstOrNull is Selectable) {
      final finalTracks = List<Selectable>.from(tracks.withLimit(maxCount));
      insertionType?.shuffleOrSort(finalTracks);

      if (showSnackBar && finalTracks.isEmpty) {
        snackyy(title: lang.NOTE, message: emptyTracksMessage ?? lang.NO_TRACKS_FOUND);
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
        );
      }
      return true;
    } else if (tracks.firstOrNull is YoutubeID) {
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
        );
      }
      return true;
    }

    return false;
  }

  Future<void> insertInQueue(Iterable<Playable> tracks, int index) async {
    await _audioHandler.insertInQueue(tracks, index);
  }

  Future<void> removeFromQueue(int index) async {
    // why [isPlaying] ? imagine removing while paused
    await _audioHandler.removeFromQueue(index, isPlaying.value && _audioHandler.defaultShouldStartPlayingWhenPaused);
  }

  Future<void> replaceAllTracksInQueue(Playable oldTrack, Playable newTrack) async {
    await _audioHandler.replaceAllItemsInQueue(oldTrack, newTrack);
  }

  Future<void> replaceAllTracksInQueueBulk(Map<Playable, Playable> oldNewTrack) async {
    await _audioHandler.replaceAllItemsInQueueBulk(oldNewTrack);
  }

  Future<void> replaceTracksDirectoryInQueue(String oldDir, String newDir, {Iterable<String>? forThesePathsOnly, bool ensureNewFileExists = false}) async {
    String getNewPath(String old) => old.replaceFirst(oldDir, newDir);
    if (currentItem is Selectable) {
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
    _audioHandler.skipToQueueItem(index, andPlay: true);
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
    QueueSource source, {
    HomePageItems? homePageItem,
    bool shuffle = false,
    bool startPlaying = true,
    bool updateQueue = true,
    void Function(Playable currentItem)? onAssigningCurrentItem,
  }) async {
    await _audioHandler.assignNewQueue(
      playAtIndex: index,
      queue: queue,
      maximumItems: 1000,
      onIndexAndQueueSame: _audioHandler.togglePlayPause,
      onQueueDifferent: (finalizedQueue) {
        if (updateQueue) {
          if (queue.firstOrNull is Selectable) {
            final trs = finalizedQueue.cast<Selectable>().tracks.toList();
            QueueController.inst.addNewQueue(source: source, homePageItem: homePageItem, tracks: trs);
          }
          QueueController.inst.updateLatestQueue(finalizedQueue);
        }
      },
      onQueueEmpty: _audioHandler.togglePlayPause,
      startPlaying: startPlaying,
      shuffle: shuffle,
      onAssigningCurrentItem: onAssigningCurrentItem,
    );
  }

  // ------- video -------

  Future<void> tryGenerateWaveform(YoutubeID? video) async {
    return _audioHandler.tryGenerateWaveform(video);
  }

  Future<void> setVideo({required String source, String cacheKey = '', bool loopingAnimation = false, required bool isFile}) async {
    await _audioHandler.setVideoSource(source: source, cacheKey: cacheKey, loopingAnimation: loopingAnimation, isFile: isFile);
  }

  Future<void> disposeVideo() async {
    await _audioHandler.setVideo(null);
  }
}

extension QueueListExt on List<Playable> {
  Iterable<T> mapAs<T extends Playable>() {
    if (Player._instance.currentItem is! T) return <T>[];
    return this.map((e) => e as T);
  }
}
