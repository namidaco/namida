import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:basic_audio_handler/basic_audio_handler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:playlist_manager/module/playlist_id.dart';
import 'package:youtipie/class/streams/audio_stream.dart';
import 'package:youtipie/class/streams/video_stream.dart';
import 'package:youtipie/class/streams/video_stream_info.dart';
import 'package:youtipie/class/streams/video_streams_result.dart';
import 'package:youtipie/core/extensions.dart' show StreamFilterUtils;

import 'package:namida/class/audio_cache_detail.dart';
import 'package:namida/class/func_execute_limiter.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/lyrics_controller.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/thumbnail_manager.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/controller/wakelock_controller.dart';
import 'package:namida/controller/waveform_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/main.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:namida/youtube/yt_utils.dart';

class NamidaAudioVideoHandler<Q extends Playable> extends BasicAudioHandler<Q> {
  @override
  AudioPipeline? get audioPipeline => AudioPipeline(
        androidAudioEffects: [
          equalizer,
          loudnessEnhancer,
        ],
      );

  late final equalizer = AndroidEqualizer();
  late final loudnessEnhancer = AndroidLoudnessEnhancer();

  RxBaseCore<Duration?> get currentItemDuration => _currentItemDuration;
  final _currentItemDuration = Rxn<Duration>();

  Timer? _resourcesDisposeTimer;

  @override
  AudioLoadConfiguration? get defaultAndroidLoadConfig {
    return AudioLoadConfiguration(
      androidLoadControl: AndroidLoadControl(
        minBufferDuration: const Duration(seconds: 50),
        maxBufferDuration: const Duration(minutes: 3),
      ),
    );
  }

  NamidaAudioVideoHandler() {
    updateAudioCacheMap();
  }

  Future<void> updateAudioCacheMap() async {
    final map = await _getAllAudiosInCache.thready(AppDirs.AUDIOS_CACHE);
    audioCacheMap = map;
  }

  var audioCacheMap = <String, List<AudioCacheDetails>>{};

  final currentVideoStream = Rxn<VideoStream>();
  final currentAudioStream = Rxn<AudioStream>();
  // final currentVideoThumbnail = Rxn<File>();
  final currentCachedVideo = Rxn<NamidaVideo>();
  final currentCachedAudio = Rxn<AudioCacheDetails>();

  final _allowSwitchingVideoStreamIfCachedPlaying = false;

  final isFetchingInfo = false.obs;

  bool get _isAudioOnlyPlayback => settings.ytIsAudioOnlyMode.value;

  bool get isCurrentAudioFromCache => _isCurrentAudioFromCache;
  bool _isCurrentAudioFromCache = false;

  VideoSourceOptions? _latestVideoOptions;
  Future<void> setAudioOnlyPlayback(bool audioOnly) async {
    settings.save(ytIsAudioOnlyMode: audioOnly);
    if (audioOnly) {
      await super.setVideo(null);
    } else {
      if (_latestVideoOptions != null) await super.setVideo(_latestVideoOptions);
    }
  }

  @override
  Future<Map<String, int>> prepareTotalListenTime() async {
    try {
      final file = await File(AppPaths.TOTAL_LISTEN_TIME).create();
      final map = await file.readAsJson();
      return (map as Map<String, dynamic>).cast();
    } catch (_) {
      return {};
    }
  }

  Future<void> _updateTrackLastPosition(Track track, int lastPositionMS) async {
    /// Saves a starting position in case the remaining was less than 30 seconds.
    final remaining = (track.duration * 1000) - lastPositionMS;
    final positionToSave = remaining <= 30000 ? 0 : lastPositionMS;

    await Indexer.inst.updateTrackStats(track, lastPositionInMs: positionToSave);
  }

  @override
  Future<void> tryRestoringLastPosition(Q item) async {
    if (item is Selectable) {
      final minValueInSet = settings.player.minTrackDurationToRestoreLastPosInMinutes.value * 60;

      if (minValueInSet >= 0) {
        final seekValueInMS = settings.player.seekDurationInSeconds.value * 1000;
        final track = item.track.toTrackExt();
        final lastPos = track.stats.lastPositionInMs;
        // -- only seek if not at the start of track.
        if (lastPos >= seekValueInMS && track.duration >= minValueInSet) {
          await seek(lastPos.milliseconds);
        }
      }
    }
  }

  // =================================================================================
  //

  //
  // =================================================================================
  // ================================ Player methods =================================
  // =================================================================================

  void refreshNotification([Q? item, YoutubeIDToMediaItemCallback? youtubeIdMediaItem]) {
    Q? exectuteOn = item ?? currentItem.value;
    Duration? knownDur;
    if (item != null) {
      exectuteOn = item;
    } else {
      exectuteOn = currentItem.value;
      knownDur = currentItemDuration.value;
    }
    exectuteOn?._execute(
      selectable: (finalItem) {
        _notificationUpdateItemSelectable(
          item: finalItem,
          isItemFavourite: finalItem.track.isFavourite,
          itemIndex: currentIndex.value,
          duration: knownDur,
        );
      },
      youtubeID: (finalItem) {
        _notificationUpdateItemYoutubeID(
          item: finalItem,
          isItemFavourite: finalItem.isFavourite,
          itemIndex: currentIndex.value,
          youtubeIdMediaItem: youtubeIdMediaItem,
        );
      },
    );
  }

  void _notificationUpdateItemSelectable({
    required Selectable item,
    required bool isItemFavourite,
    required int itemIndex,
    required Duration? duration,
  }) {
    mediaItem.add(item.toMediaItem(currentIndex.value, currentQueue.value.length, duration));
    playbackState.add(transformEvent(PlaybackEvent(currentIndex: currentIndex.value), isItemFavourite, itemIndex));
  }

  void _notificationUpdateItemYoutubeID({
    required YoutubeID item,
    required bool isItemFavourite,
    required int itemIndex,
    required YoutubeIDToMediaItemCallback? youtubeIdMediaItem,
  }) {
    youtubeIdMediaItem ??= (index, ql) {
      return item.toMediaItem(item.id, _ytNotificationVideoInfo, _ytNotificationVideoThumbnail, index, ql, currentItemDuration.value);
    };
    final index = currentIndex.value;
    final ql = currentQueue.value.length;
    mediaItem.add(youtubeIdMediaItem(index, ql));
    playbackState.add(transformEvent(PlaybackEvent(currentIndex: index), isItemFavourite, itemIndex));
  }

  // =================================================================================
  //

  //
  // ==============================================================================================
  // ==============================================================================================
  // ================================== QueueManager Overriden ====================================

  @override
  void onIndexChanged(int newIndex, Q newItem) {
    refreshNotification(newItem);
    newItem._execute(
      selectable: (finalItem) {
        settings.player.save(lastPlayedIndices: {LibraryCategory.localTracks: newIndex});
        CurrentColor.inst.updatePlayerColorFromTrack(finalItem, newIndex);
      },
      youtubeID: (finalItem) {
        settings.player.save(lastPlayedIndices: {LibraryCategory.youtube: newIndex});
        CurrentColor.inst.updatePlayerColorFromYoutubeID(finalItem);
      },
    );
  }

  @override
  Future<void> onQueueChanged() async {
    await super.onQueueChanged();
    if (currentQueue.value.isEmpty) {
      CurrentColor.inst.resetCurrentPlayingTrack();
      if (MiniPlayerController.inst.isInQueue) MiniPlayerController.inst.snapToMini();
      // await pause();
      await [
        onDispose(),
        QueueController.inst.emptyLatestQueue(),
      ].execute();
    } else {
      refreshNotification(currentItem.value);
      await QueueController.inst.updateLatestQueue(currentQueue.value);
    }
  }

  @override
  Future<void> onReorderItems(int currentIndex, Q itemDragged) async {
    await super.onReorderItems(currentIndex, itemDragged);

    refreshNotification();

    await itemDragged._execute(
      selectable: (finalItem) {
        CurrentColor.inst.updatePlayerColorFromTrack(null, currentIndex, updateIndexOnly: true);
      },
      youtubeID: (finalItem) {},
    );

    await QueueController.inst.updateLatestQueue(currentQueue.value);
  }

  @override
  FutureOr<void> beforeQueueAddOrInsert(Iterable<Q> items) async {
    if (currentQueue.value.isEmpty) return;

    // this is what keeps local & youtube separated. this shall be removed if mixed playback ever got supported.
    final current = currentItem.value;
    final newItem = items.firstOrNull;
    if (newItem is Selectable && current is! Selectable) {
      await clearQueue();
    } else if (newItem is YoutubeID && current is! YoutubeID) {
      await clearQueue();
    }
  }

  @override
  FutureOr<void> clearQueue() async {
    videoPlayerInfo.value = null;
    Lyrics.inst.resetLyrics();
    WaveformController.inst.resetWaveform();
    CurrentColor.inst.resetCurrentPlayingTrack();

    VideoController.inst.currentVideo.value = null;
    VideoController.inst.currentYTStreams.value = null;
    VideoController.inst.currentPossibleLocalVideos.clear();

    YoutubeInfoController.current.resetAll();

    currentVideoStream.value = null;
    currentAudioStream.value = null;
    currentCachedVideo.value = null;
    currentCachedAudio.value = null;
    _isCurrentAudioFromCache = false;
    isFetchingInfo.value = false;
    _nextSeekSetAudioCache = null;
    await super.clearQueue();
  }

  @override
  Future<void> beforeSkippingToItem() async {
    await super.beforeSkippingToItem(); // saving last position & waiting for reorder/removing.
    NamidaNavigator.inst.popAllMenus();
  }

  @override
  Future<void> assignNewQueue({
    required int playAtIndex,
    required Iterable<Q> queue,
    bool shuffle = false,
    bool startPlaying = true,
    int? maximumItems,
    void Function()? onQueueEmpty,
    void Function()? onIndexAndQueueSame,
    void Function(List<Q> finalizedQueue)? onQueueDifferent,
    void Function(Q currentItem)? onAssigningCurrentItem,
    bool Function(Q? currentItem, Q itemToPlay)? canRestructureQueueOnly,
  }) async {
    await beforeQueueAddOrInsert(queue);
    if (startPlaying) setPlayWhenReady(true);
    await super.assignNewQueue(
      playAtIndex: playAtIndex,
      queue: queue,
      maximumItems: maximumItems,
      startPlaying: startPlaying,
      shuffle: shuffle,
      onIndexAndQueueSame: onIndexAndQueueSame,
      onQueueDifferent: onQueueDifferent,
      onQueueEmpty: onQueueEmpty,
      onAssigningCurrentItem: onAssigningCurrentItem,
      canRestructureQueueOnly: canRestructureQueueOnly ??
          (currentItem, itemToPlay) {
            if (itemToPlay is Selectable && currentItem is Selectable) {
              return itemToPlay.track.path == currentItem.track.path;
            } else if (itemToPlay is YoutubeID && currentItem is YoutubeID) {
              return itemToPlay.id == currentItem.id;
            }
            return false;
          },
    );
  }

  // ==============================================================================================
  //

  //
  // ==============================================================================================
  // ==============================================================================================
  // ================================== NamidaBasicAudioHandler Overriden ====================================

  @override
  InterruptionAction defaultOnInterruption(InterruptionType type) => settings.player.onInterrupted.value[type] ?? InterruptionAction.pause;

  @override
  FutureOr<int> itemToDurationInSeconds(Q item) async {
    return (await item._execute(
          selectable: (finalItem) async {
            final dur = finalItem.track.duration;
            if (dur > 0) {
              return dur;
            } else {
              final ap = AudioPlayer();
              final d = await ap.setFilePath(finalItem.track.path);
              ap.stop();
              ap.dispose();
              return d?.inSeconds ?? 0;
            }
          },
          youtubeID: (finalItem) async {
            final durSecCache = YoutubeInfoController.utils.getVideoDurationSeconds(finalItem.id);
            return durSecCache;
          },
        )) ??
        0;
  }

  @override
  FutureOr<void> onItemMarkedListened(Q item, int listenedSeconds, double listenedPercentage) async {
    await item._execute(
      selectable: (finalItem) async {
        final newTrackWithDate = TrackWithDate(
          dateAdded: currentTimeMS,
          track: finalItem.track,
          source: TrackSource.local,
        );
        await HistoryController.inst.addTracksToHistory([newTrackWithDate]);
      },
      youtubeID: (finalItem) async {
        final newListen = YoutubeID(
          id: finalItem.id,
          watchNull: YTWatch(dateNull: DateTime.now(), isYTMusic: false),
          playlistID: const PlaylistID(id: k_PLAYLIST_NAME_HISTORY),
        );
        await YoutubeHistoryController.inst.addTracksToHistory([newListen]);
      },
    );
  }

  final _fnLimiter = FunctionExecuteLimiter(
    considerRapid: const Duration(milliseconds: 500),
    executeAfter: const Duration(milliseconds: 300),
    considerRapidAfterNExecutions: 3,
  );
  bool? _pausedTemporarily;

  @override
  Future<void> onItemPlay(Q item, int index, bool Function() startPlaying, Function skipItem) async {
    _currentItemDuration.value = null;
    await _fnLimiter.executeFuture(
      () async {
        return await item._execute(
          selectable: (finalItem) async {
            await onItemPlaySelectable(item, finalItem, index, startPlaying, skipItem);
          },
          youtubeID: (finalItem) async {
            await onItemPlayYoutubeID(item, finalItem, index, startPlaying, skipItem);
          },
        );
      },
      onRapidDetected: () {
        if (isPlaying.value) {
          _pausedTemporarily = true;
          pause();
        }
      },
      onReExecute: () {
        if (_pausedTemporarily == true) {
          _pausedTemporarily = null;
          play();
        }
      },
    );
  }

  Timer? _playErrorSkipTimer;
  final playErrorRemainingSecondsToSkip = 0.obs;
  void cancelPlayErrorSkipTimer() {
    _playErrorSkipTimer?.cancel();
    _playErrorSkipTimer = null;
    playErrorRemainingSecondsToSkip.value = 0;
  }

  Future<void> onItemPlaySelectable(Q pi, Selectable item, int index, bool Function() startPlaying, Function skipItem) async {
    final tr = item.track;
    videoPlayerInfo.value = null;
    Lyrics.inst.resetLyrics();
    WaveformController.inst.resetWaveform();
    WaveformController.inst.generateWaveform(
      path: tr.path,
      duration: Duration(seconds: tr.duration),
      stillPlaying: (path) {
        final current = currentItem.value;
        return current is Selectable && path == current.track.path;
      },
    );
    final initialVideo = await VideoController.inst.updateCurrentVideo(tr, returnEarly: true);

    // -- generating artwork in case it wasnt, to be displayed in notification
    File(tr.pathToImage).exists().then((exists) {
      // -- we check if it exists to avoid refreshing notification redundently.
      // -- otherwise `getArtwork` already handles duplications.
      if (!exists) {
        Indexer.inst.getArtwork(imagePath: tr.pathToImage, compressed: false, checkFileFirst: false).then((value) => refreshNotification());
      }
    });

    // -- hmm marking local tracks as yt-watched..?
    // final trackYoutubeId = tr.youtubeID;
    // if (trackYoutubeId.isNotEmpty) {
    //   YoutubeInfoController.history.markVideoWatched(videoId: trackYoutubeId, streamResult: null, errorOnMissingParam: false);
    // }

    Duration? duration;

    Future<Duration?> setPls() async {
      if (!File(tr.path).existsSync()) throw PathNotFoundException(tr.path, const OSError(), 'Track file not found or couldn\'t be accessed.');
      final dur = await setSource(
        tr.toAudioSource(currentIndex.value, currentQueue.value.length, duration),
        item: pi,
        startPlaying: startPlaying,
        videoOptions: initialVideo == null
            ? null
            : VideoSourceOptions(
                source: AudioVideoSource.file(initialVideo.path),
                loop: VideoController.inst.canLoopVideo(initialVideo, duration?.inSeconds ?? tr.duration),
                videoOnly: false,
              ),
        isVideoFile: true,
      );
      Indexer.inst.updateTrackDuration(tr, dur);

      refreshNotification(currentItem.value);
      return dur;
    }

    bool checkInterrupted() {
      if (item.track != currentItem.value) {
        return true;
      } else {
        if (duration != null) _currentItemDuration.value = duration;
        return false;
      }
    }

    if (tr.path.startsWith('/namida_dummy/')) return;

    try {
      duration = await setPls();
    } on Exception catch (e) {
      if (checkInterrupted()) return;
      final reallyError = !(duration != null && currentPositionMS.value > 0);
      if (reallyError) {
        printy(e, isError: true);
        // -- playing music from root folders still require `all_file_access`
        // -- this is a fix for not playing some external files reported by some users.
        final hadPermissionBefore = await Permission.manageExternalStorage.isGranted;
        if (hadPermissionBefore) {
          pause();
          cancelPlayErrorSkipTimer();
          playErrorRemainingSecondsToSkip.value = 7;

          _playErrorSkipTimer = Timer.periodic(
            const Duration(seconds: 1),
            (timer) {
              playErrorRemainingSecondsToSkip.value--;
              if (playErrorRemainingSecondsToSkip.value <= 0) {
                NamidaNavigator.inst.closeDialog();
                if (currentQueue.value.length > 1) skipItem();
                timer.cancel();
              }
            },
          );
          NamidaDialogs.inst.showTrackDialog(
            tr,
            isFromPlayerQueue: true,
            errorPlayingTrack: e,
            source: QueueSource.playerQueue,
          );
          return;
        } else {
          final hasPermission = await requestManageStoragePermission();
          if (!hasPermission) return;
          try {
            duration = await setPls();
          } catch (_) {}
        }
      }
    }

    if (checkInterrupted()) return;

    if (initialVideo == null) VideoController.inst.updateCurrentVideo(tr, returnEarly: false);

    // -- to fix a bug where [headset buttons/android next gesture] sometimes don't get detected.
    if (startPlaying()) onPlayRaw();

    startSleepAfterMinCount();
    startCounterToAListen(pi);
    increaseListenTime(LibraryCategory.localTracks);
    Lyrics.inst.updateLyrics(tr);
  }

  Future<void> onItemPlayYoutubeIDSetQuality({
    required VideoStreamsResult? mainStreams,
    required VideoStream? stream,
    required File? cachedFile,
    required bool useCache,
    required String videoId,
    required NamidaVideo? videoItem,
  }) async {
    final wasPlaying = isPlaying.value;
    setAudioOnlyPlayback(false);

    currentVideoStream.value = stream;
    currentCachedVideo.value = null;

    if (useCache && cachedFile != null && cachedFile.existsSync()) {
      currentCachedVideo.value = videoItem;
      await setVideoSource(source: AudioVideoSource.file(cachedFile.path), isFile: true);
    } else if (stream != null) {
      if (wasPlaying) await onPauseRaw();

      final bool expired = mainStreams?.hasExpired() ?? true;

      bool checkInterrupted() {
        final curr = currentItem.value;
        return !(curr is YoutubeID && curr.id == videoId);
      }

      Future<void> setVideoLockCache(VideoStream stream) async {
        final url = stream.buildUrl();
        if (url == null) throw Exception('null url');
        await setVideoSource(
          source: LockCachingVideoSource(
            url,
            cacheFile: File(stream.cachePath(videoId)),
            onCacheDone: (cacheFile) async => await _onVideoCacheDone(videoId, cacheFile),
          ),
          cacheKey: stream.cacheKey(videoId),
        );
        refreshNotification();
      }

      if (!YoutubeInfoController.video.jsPreparedIfRequired) await YoutubeInfoController.video.ensureJSPlayerInitialized();

      try {
        if (expired) throw Exception('expired streams');
        await setVideoLockCache(stream);
      } catch (e) {
        // ==== if the url got outdated.
        isFetchingInfo.value = true;
        final newStreams = await YoutubeInfoController.video.fetchVideoStreams(videoId);
        isFetchingInfo.value = false;

        if (checkInterrupted()) return;
        if (newStreams != null) YoutubeInfoController.current.currentYTStreams.value = newStreams;
        VideoStream? sameStream = newStreams?.videoStreams.firstWhereEff((e) => e.itag == stream.itag);
        if (sameStream == null && newStreams != null) {
          sameStream = YoutubeController.inst.getPreferredStreamQuality(newStreams.videoStreams, preferIncludeWebm: false);
        }

        if (sameStream != null) {
          try {
            await setVideoLockCache(sameStream);
          } catch (_) {}
        }
      }

      if (wasPlaying) onPlayRaw();
    }
  }

  Future<void> onItemPlayYoutubeIDSetAudio({
    required VideoStreamsResult? mainStreams,
    required AudioStream? stream,
    required File? cachedFile,
    required bool useCache,
    required String videoId,
  }) async {
    final wasPlaying = isPlaying.value;

    currentAudioStream.value = stream;

    final cachedAudio = stream?.getCachedFile(videoId);

    if (useCache && cachedAudio != null && cachedAudio.existsSync()) {
      await setSource(
        AudioVideoSource.file(cachedAudio.path, tag: mediaItem),
        item: currentItem.value,
        startPlaying: () => wasPlaying,
        keepOldVideoSource: true,
        cachedAudioPath: cachedAudio.path,
      );
      refreshNotification();
    } else if (stream != null) {
      if (wasPlaying) await super.onPauseRaw();

      final bool expired = mainStreams?.hasExpired() ?? true;

      Future<void> setAudioLockCache(AudioStream stream) async {
        final url = stream.buildUrl();
        if (url == null) throw Exception('null url');
        await setSource(
          LockCachingAudioSource(
            url,
            cacheFile: File(stream.cachePath(videoId)),
            tag: mediaItem,
            onCacheDone: (cacheFile) async => await _onAudioCacheDone(videoId, cacheFile),
          ),
          item: currentItem.value,
          startPlaying: () => wasPlaying,
          keepOldVideoSource: true,
        );
        refreshNotification();
      }

      bool checkInterrupted() {
        final curr = currentItem.value;
        return !(curr is YoutubeID && curr.id == videoId);
      }

      if (!YoutubeInfoController.video.jsPreparedIfRequired) await YoutubeInfoController.video.ensureJSPlayerInitialized();

      try {
        if (expired) throw Exception('expired streams');
        await setAudioLockCache(stream);
      } catch (_) {
        // ==== if the url got outdated.
        isFetchingInfo.value = true;
        final newStreams = await YoutubeInfoController.video.fetchVideoStreams(videoId);
        isFetchingInfo.value = false;

        if (checkInterrupted()) return;
        if (newStreams != null) YoutubeInfoController.current.currentYTStreams.value = newStreams;
        final sameStream = newStreams?.audioStreams.firstWhereEff((e) => e.itag == stream.itag) ?? newStreams?.audioStreams.firstNonWebm();

        if (sameStream != null) {
          try {
            await setAudioLockCache(sameStream);
          } catch (_) {}
        }
      }

      if (wasPlaying) onPlayRaw();
    }
  }

  _NextSeekCachedFileData? _nextSeekSetAudioCache;
  _NextSeekCachedFileData? _nextSeekSetVideoCache;

  Future<void> tryGenerateWaveform(YoutubeID? video) async {
    if (video != null && WaveformController.inst.isDummy && !settings.youtubeStyleMiniplayer.value) {
      final audioPath = currentCachedAudio.value?.file.path ?? _nextSeekSetAudioCache?.getFileIfPlaying(video.id)?.path;
      final dur = currentItemDuration.value;
      if (audioPath != null && dur != null) {
        return WaveformController.inst.generateWaveform(
          path: audioPath,
          duration: dur,
          stillPlaying: (path) => video == currentItem.value,
        );
      }
    }
  }

  /// Sets [_nextSeekSetVideoCache] to properly update video source on next seek and calls [_onAudioCacheAddPendingInfo] to add info.
  Future<void> _onVideoCacheDone(String videoId, File videoCacheFile) async {
    final curr = currentItem.value;
    if (curr is! YoutubeID) return;
    if (curr.id != videoId) return;

    _nextSeekSetVideoCache = _NextSeekCachedFileData(videoId: videoId, cacheFile: videoCacheFile);
    return _onVideoCacheAddPendingInfo(videoId); // this requires same item being played, cuz it needs its info
  }

  /// Adds video info of the recently cached video.
  /// Usually videos are added automatically on restart but this keeps things up-to-date.
  Future<void> _onVideoCacheAddPendingInfo(String videoId) async {
    final prevVideoStream = currentVideoStream.value;
    if (prevVideoStream != null) {
      final maybeCached = prevVideoStream.getCachedFile(videoId);
      if (maybeCached != null) {
        final prevVideoInfo = YoutubeInfoController.current.currentYTStreams.value?.info;
        VideoController.inst.addYTVideoToCacheMap(
          videoId,
          NamidaVideo(
            path: maybeCached.path,
            ytID: videoId,
            height: prevVideoStream.height,
            width: prevVideoStream.width,
            sizeInBytes: prevVideoStream.sizeInBytes,
            frameratePrecise: prevVideoStream.fps.toDouble(),
            creationTimeMS: (prevVideoInfo?.publishedAt.date ?? prevVideoInfo?.publishDate.date)?.millisecondsSinceEpoch ?? 0,
            durationMS: prevVideoStream.duration.inMilliseconds,
            bitrate: prevVideoStream.bitrate,
          ),
        );
      }
    }
  }

  /// Sets [_nextSeekSetAudioCache] to properly update audio source on next seek and calls [_onVideoCacheAddPendingInfo] to add info.
  Future<void> _onAudioCacheDone(String videoId, File audioCacheFile) async {
    final curr = currentItem.value;
    if (curr is! YoutubeID) return;
    if (curr.id != videoId) return;

    _nextSeekSetAudioCache = _NextSeekCachedFileData(videoId: videoId, cacheFile: audioCacheFile);
    return _onAudioCacheAddPendingInfo(videoId, audioCacheFile);
  }

  /// Adds audio info of the recently cached audio.
  /// Usually audios are obtained when needed but this keeps things up-to-date.
  Future<void> _onAudioCacheAddPendingInfo(String videoId, File audioCacheFile) async {
    // -- generating waveform if needed & if still playing
    final curr = currentItem.value;
    if (curr is YoutubeID && curr.id == videoId && WaveformController.inst.isDummy && !settings.youtubeStyleMiniplayer.value) {
      final dur = currentItemDuration.value;
      if (dur != null) {
        WaveformController.inst.generateWaveform(
          path: audioCacheFile.path,
          duration: dur,
          stillPlaying: (path) {
            final curr = currentItem.value;
            return curr is YoutubeID && curr.id == videoId;
          },
        );
      }
    }

    final prevAudioStream = currentAudioStream.value;
    final prevAudioBitrate = prevAudioStream?.bitrate ?? currentCachedAudio.value?.bitrate;
    final prevAudioLangCode = prevAudioStream?.audioTrack?.langCode ?? currentCachedAudio.value?.langaugeCode;
    final prevAudioLangName = prevAudioStream?.audioTrack?.displayName ?? currentCachedAudio.value?.langaugeName;
    final prevVideoInfo = YoutubeInfoController.current.currentYTStreams.value?.info;

    // -- Adding recently cached audio to cache map, for being displayed on cards.
    audioCacheMap.addNoDuplicatesForce(
        videoId,
        AudioCacheDetails(
          youtubeId: videoId,
          file: audioCacheFile,
          bitrate: prevAudioBitrate,
          langaugeCode: prevAudioLangCode,
          langaugeName: prevAudioLangName,
        ));

    // -- Writing metadata too
    final meta = YTUtils.getMetadataInitialMap(videoId, prevVideoInfo);
    await YTUtils.writeAudioMetadata(
      videoId: videoId,
      audioFile: audioCacheFile,
      thumbnailFile: null,
      tagsMap: meta,
    );
  }

  VideoStreamInfo? _ytNotificationVideoInfo;
  File? _ytNotificationVideoThumbnail;

  /// Shows error if [marked] failed & saved as pending.
  void _onVideoMarkWatchResultError(YTMarkVideoWatchedResult marked) {
    if (marked == YTMarkVideoWatchedResult.addedAsPending) {
      snackyy(message: 'Failed to mark video as watched, saved as pending.', top: false, isError: true);
    }
  }

  Future<void> onItemPlayYoutubeID(
    Q pi,
    YoutubeID item,
    int index,
    bool Function() startPlaying,
    Function skipItem, {
    bool? canPlayAudioOnlyFromCache,
  }) async {
    canPlayAudioOnlyFromCache ??= (_isAudioOnlyPlayback || !ConnectivityController.inst.hasConnection);

    WaveformController.inst.resetWaveform();
    Lyrics.inst.resetLyrics();

    currentVideoStream.value = null;
    currentAudioStream.value = null;
    currentCachedVideo.value = null;
    currentCachedAudio.value = null;
    _isCurrentAudioFromCache = false;
    isFetchingInfo.value = false;
    _nextSeekSetAudioCache = null;
    YoutubeInfoController.current.onVideoPageReset?.call();

    if (item.id == '' || item.id == 'null') {
      if (currentQueue.value.length > 1) skipItem();
      return;
    }

    VideoStreamsResult? streamsResult = YoutubeInfoController.video.fetchVideoStreamsSync(item.id);

    YoutubeInfoController.current.currentYTStreams.value = streamsResult;
    final hadCachedVideoPage = YoutubeInfoController.current.updateVideoPageSync(item.id);
    final hadCachedComments = YoutubeInfoController.current.updateCurrentCommentsSync(item.id);

    Duration? duration = streamsResult?.audioStreams.firstOrNull?.duration;
    _ytNotificationVideoInfo = streamsResult?.info;
    _ytNotificationVideoThumbnail = item.getThumbnailSync(temp: false, type: ThumbnailType.video);

    bool checkInterrupted({bool refreshNoti = true}) {
      final curr = currentItem.value;
      if (curr is YoutubeID && item.id == curr.id) {
        if (duration != null) {
          final refresh = _currentItemDuration.value == null && refreshNoti;
          _currentItemDuration.value = duration;
          if (refresh) {
            refreshNotification(pi, (index, ql) => item.toMediaItem(item.id, _ytNotificationVideoInfo, _ytNotificationVideoThumbnail, index, ql, duration));
          }
        }
        return false;
      } else {
        return true;
      }
    }

    Future<void> fetchFullVideoPage() async {
      final requestComments = settings.ytPreferNewComments.value ? true : !hadCachedComments;
      await YoutubeInfoController.current.updateVideoPage(
        item.id,
        requestPage: !hadCachedVideoPage,
        requestComments: requestComments,
      );
    }

    void onInfoOrThumbObtained({VideoStreamInfo? info, File? thumbnail}) {
      if (checkInterrupted(refreshNoti: false)) return;
      if (info != null) _ytNotificationVideoInfo = info; // we assign cuz later some functions can depend on this
      if (thumbnail != null) _ytNotificationVideoThumbnail = thumbnail;
      refreshNotification(pi, (index, ql) => item.toMediaItem(item.id, _ytNotificationVideoInfo, _ytNotificationVideoThumbnail, index, ql, duration));
    }

    // -- we no longer check if any of these 2 is not null, cuz info like index & queue length needs to be updated asap
    onInfoOrThumbObtained(info: _ytNotificationVideoInfo, thumbnail: _ytNotificationVideoThumbnail);

    if (_ytNotificationVideoThumbnail == null) {
      ThumbnailManager.inst.getYoutubeThumbnailAndCache(id: item.id, type: ThumbnailType.video).then((thumbFile) {
        thumbFile ??= item.getThumbnailSync(temp: true, type: ThumbnailType.video);
        if (thumbFile != null) onInfoOrThumbObtained(thumbnail: thumbFile);
      });
    }

    Future<void> plsplsplsPlay(bool wasPlayingFromCache, bool sourceChanged) async {
      if (sourceChanged) {
        await seek(currentPositionMS.value.milliseconds);
      }
      if (startPlaying()) {
        onPlayRaw();
      }
      if (!wasPlayingFromCache) {
        startSleepAfterMinCount();
        startCounterToAListen(pi);
        increaseListenTime(LibraryCategory.youtube);
        Lyrics.inst.updateLyrics(item);
      }
    }

    Completer<bool>? playerStoppingSeikoo; // to prevent accidental stopping if getAvailableStreams was faster than fade effect
    if (enableCrossFade) {
      // -- do nothing
    } else {
      playerStoppingSeikoo = Completer<bool>();
      if (isPlaying.value) {
        // wait for pausing only if playing.
        pauseAndStop(fadeMS: 100, stillSameItem: () => item == currentItem.value).then((_) {
          playerStoppingSeikoo?.complete(true);
        });
      } else {
        if (item == currentItem.value) await stop();
        playerStoppingSeikoo.complete(true);
      }
    }

    videoPlayerInfo.value = null;

    ({AudioCacheDetails? audio, NamidaVideo? video, Duration? duration}) playedFromCacheDetails = (audio: null, video: null, duration: null);
    bool okaySetFromCache() => playedFromCacheDetails.audio != null && (canPlayAudioOnlyFromCache! || playedFromCacheDetails.video != null);

    bool generatedWaveform = false;
    void generateWaveform() {
      if (!generatedWaveform && !settings.youtubeStyleMiniplayer.value) {
        final audioDetails = playedFromCacheDetails.audio;
        final dur = playedFromCacheDetails.duration;
        if (audioDetails != null && dur != null) {
          generatedWaveform = true;
          WaveformController.inst.generateWaveform(
            path: audioDetails.file.path,
            duration: dur,
            stillPlaying: (path) {
              final curr = currentItem.value;
              return curr is YoutubeID && curr.id == item.id;
            },
          );
        }
      }
    }

    /// try playing cache always for faster playback initialization, if the quality should be
    /// different then it will be set later after fetching.
    playedFromCacheDetails = await _trySetYTVideoWithoutConnection(
      item: item,
      mediaItemFn: () => item.toMediaItem(item.id, _ytNotificationVideoInfo, _ytNotificationVideoThumbnail, index, currentQueue.value.length, duration),
      checkInterrupted: checkInterrupted,
      index: index,
      canPlayAudioOnly: canPlayAudioOnlyFromCache,
      disableVideo: _isAudioOnlyPlayback,
      whatToAwait: playerStoppingSeikoo?.future,
      startPlaying: startPlaying,
      possibleAudioFiles: audioCacheMap[item.id] ?? [],
      possibleLocalFiles: Indexer.inst.allTracksMappedByYTID[item.id] ?? [],
    );

    duration ??= playedFromCacheDetails.duration;
    if (checkInterrupted()) return; // this also refreshes currentDuration

    if (!ConnectivityController.inst.hasConnection && playedFromCacheDetails.audio == null) {
      // -- if no connection and couldnt play from cache, we skip
      if (currentQueue.value.length > 1) skipItem();
      return;
    }

    currentCachedAudio.value = playedFromCacheDetails.audio;
    currentCachedVideo.value = playedFromCacheDetails.video;

    generateWaveform();

    bool heyIhandledAudioPlaying = false;
    if (okaySetFromCache()) {
      heyIhandledAudioPlaying = true;
      await plsplsplsPlay(false, false);
    } else {
      heyIhandledAudioPlaying = false;
    }

    if (checkInterrupted()) return;

    Completer<YTMarkVideoWatchedResult>? markedAsWatched;

    // only if was playing
    if (okaySetFromCache() && (streamsResult != null || !ConnectivityController.inst.hasConnection)) {
      // -- allow when no connection bcz this function won't try again with no connection,
      // -- so we force call here and let `markVideoWatched` do the job when there is proper connection.
      markedAsWatched = Completer<YTMarkVideoWatchedResult>();
      markedAsWatched.complete(YoutubeInfoController.history.markVideoWatched(videoId: item.id, streamResult: streamsResult));
    }

    if (ConnectivityController.inst.hasConnection) {
      try {
        isFetchingInfo.value = true;

        bool forceRequest = false;
        if (streamsResult == null) {
          forceRequest = true;
        } else {
          forceRequest = streamsResult.hasExpired();
        }

        if (forceRequest) {
          streamsResult = await YoutubeInfoController.video.fetchVideoStreams(item.id).catchError((_) {
            snackyy(message: 'Error getting streams', top: false, isError: true);
            return null;
          });
          if (streamsResult != null) {
            if (markedAsWatched != null) {
              // -- older request was initiated, wait to see the value.
              markedAsWatched.future.then(
                (marked) {
                  if ((marked == YTMarkVideoWatchedResult.noAccount || marked == YTMarkVideoWatchedResult.userDenied) && streamsResult != null) {
                    YoutubeInfoController.history.markVideoWatched(videoId: item.id, streamResult: streamsResult).then(_onVideoMarkWatchResultError);
                  }
                },
              );
            } else {
              // -- no old requests, force mark
              YoutubeInfoController.history.markVideoWatched(videoId: item.id, streamResult: streamsResult).then(_onVideoMarkWatchResultError);
            }
          }
          duration ??= streamsResult?.audioStreams.firstOrNull?.duration;
          onInfoOrThumbObtained(info: streamsResult?.info);
          if (checkInterrupted(refreshNoti: false)) return; // -- onInfoOrThumbObtained refreshes notification.
          YoutubeInfoController.current.currentYTStreams.value = streamsResult;
        } else {
          YoutubeInfoController.current.currentYTStreams.value = streamsResult;
        }

        if (checkInterrupted()) return;
        isFetchingInfo.value = false;

        fetchFullVideoPage();

        final audiostreams = streamsResult?.audioStreams ?? [];
        final videoStreams = streamsResult?.videoStreams ?? [];

        if (audiostreams.isEmpty) {
          if (!okaySetFromCache()) snackyy(message: 'Error playing video, empty audio streams', top: false, isError: true);
          return;
        }

        if (!YoutubeInfoController.video.jsPreparedIfRequired) await YoutubeInfoController.video.ensureJSPlayerInitialized();

        if (checkInterrupted()) return;
        final prefferedVideoStream = _isAudioOnlyPlayback || videoStreams.isEmpty ? null : YoutubeController.inst.getPreferredStreamQuality(videoStreams, preferIncludeWebm: false);
        final prefferedAudioStream =
            audiostreams.firstWhereEff((e) => !e.isWebm && e.audioTrack?.langCode == 'en') ?? audiostreams.firstWhereEff((e) => !e.isWebm) ?? audiostreams.firstOrNull;
        final prefferedAudioStreamUrl = prefferedAudioStream?.buildUrl();
        final prefferedVideoStreamUrl = prefferedVideoStream?.buildUrl();
        if (prefferedAudioStreamUrl != null || prefferedVideoStreamUrl != null) {
          final cachedVideoSet = playedFromCacheDetails.video;
          bool isStreamRequiredBetterThanCachedSet = cachedVideoSet == null
              ? true
              : _allowSwitchingVideoStreamIfCachedPlaying
                  ? (prefferedVideoStream?.width ?? 0) > (cachedVideoSet.width)
                  : false;

          currentVideoStream.value = _isAudioOnlyPlayback
              ? null
              : isStreamRequiredBetterThanCachedSet
                  ? prefferedVideoStream
                  : videoStreams.firstWhereEff((e) => e.width == (playedFromCacheDetails.video?.resolution));

          currentAudioStream.value = prefferedAudioStream;
          _isCurrentAudioFromCache = playedFromCacheDetails.audio != null;

          if (checkInterrupted()) return;

          // final cachedVideo = prefferedVideoStream?.getCachedFile(item.id);
          // final cachedAudio = prefferedAudioStream?.getCachedFile(item.id);

          // -- since we disabled auto switching video streams once played from cache, [isVideoCacheSameAsPrevSet] is dropped.
          // -- with the new possibility of playing local tracks as audio source, [isAudioCacheSameAsPrevSet] also is dropped.
          final shouldResetVideoSource = _isAudioOnlyPlayback ? false : playedFromCacheDetails.video == null;
          final shouldResetAudioSource = playedFromCacheDetails.audio == null;

          // -- updating wether the source has changed, so that play should be triggered again.
          if (heyIhandledAudioPlaying) {
            heyIhandledAudioPlaying = !((shouldResetVideoSource && isStreamRequiredBetterThanCachedSet) || shouldResetAudioSource);
          }

          VideoSourceOptions? videoOptions;
          if (shouldResetVideoSource && isStreamRequiredBetterThanCachedSet && prefferedVideoStreamUrl != null) {
            videoOptions = VideoSourceOptions(
              source: playedFromCacheDetails.video != null
                  ? AudioVideoSource.file(
                      playedFromCacheDetails.video!.path,
                    )
                  : LockCachingVideoSource(
                      prefferedVideoStreamUrl,
                      cacheFile: prefferedVideoStream == null ? null : File(prefferedVideoStream.cachePath(item.id)),
                      onCacheDone: (cacheFile) async => await _onVideoCacheDone(item.id, cacheFile),
                    ),
              loop: false,
              videoOnly: false,
            );
            _latestVideoOptions = videoOptions;
          }
          await playerStoppingSeikoo?.future;
          if (checkInterrupted()) return;

          if (shouldResetAudioSource && prefferedAudioStream != null && prefferedAudioStreamUrl != null) {
            duration = await setSource(
              LockCachingAudioSource(
                prefferedAudioStreamUrl,
                cacheFile: File(prefferedAudioStream.cachePath(item.id)),
                tag: mediaItem,
                onCacheDone: (cacheFile) async => await _onAudioCacheDone(item.id, cacheFile),
              ),
              item: pi,
              startPlaying: startPlaying,
              videoOptions: videoOptions,
              keepOldVideoSource: false,
              isVideoFile: false,
            );
            if (checkInterrupted()) return;
          } else if (videoOptions != null) {
            await setVideo(videoOptions);
          }
        }
      } catch (e) {
        if (checkInterrupted()) return;
        void showSnackError(String nextAction) {
          if (item == currentItem.value) {
            snackyy(message: 'Error playing video, $nextAction: $e', top: false, isError: true);
          }
        }

        showSnackError('trying again');

        printy(e, isError: true);
        playedFromCacheDetails = await _trySetYTVideoWithoutConnection(
          item: item,
          mediaItemFn: () => item.toMediaItem(item.id, _ytNotificationVideoInfo, _ytNotificationVideoThumbnail, index, currentQueue.value.length, duration),
          checkInterrupted: checkInterrupted,
          index: index,
          canPlayAudioOnly: canPlayAudioOnlyFromCache,
          disableVideo: _isAudioOnlyPlayback,
          whatToAwait: playerStoppingSeikoo?.future,
          startPlaying: startPlaying,
          possibleAudioFiles: audioCacheMap[item.id] ?? [],
          possibleLocalFiles: Indexer.inst.allTracksMappedByYTID[item.id] ?? [],
        );
        duration ??= playedFromCacheDetails.duration;
        if (checkInterrupted()) return; // this also refreshes currentDuration
        generateWaveform();
        if (!okaySetFromCache()) {
          showSnackError('skipping');
          skipToNext();
        }
      }
    }

    if (!heyIhandledAudioPlaying) {
      final didplayfromcache = okaySetFromCache();
      await plsplsplsPlay(didplayfromcache, !didplayfromcache);
    }
  }

  /// Returns Audio File and Video File.
  Future<({AudioCacheDetails? audio, NamidaVideo? video, Duration? duration})> _trySetYTVideoWithoutConnection({
    required YoutubeID item,
    required MediaItem Function() mediaItemFn,
    required bool Function() checkInterrupted,
    required int index,
    required bool canPlayAudioOnly,
    required bool disableVideo,
    required Future<void>? whatToAwait,
    required bool Function() startPlaying,
    required List<AudioCacheDetails> possibleAudioFiles,
    required List<Track> possibleLocalFiles,
  }) async {
    // ------ Getting Video ------
    final allCachedVideos = VideoController.inst.getNVFromID(item.id);
    allCachedVideos.sortByReverseAlt(
      (e) {
        if (e.resolution != 0) return e.resolution;
        if (e.height != 0) return e.height;
        return 0;
      },
      (e) => e.frameratePrecise,
    );

    YoutubeInfoController.current.currentCachedQualities.value = allCachedVideos;

    final cachedVideo = allCachedVideos.firstWhereEff((e) => File(e.path).existsSync());

    // ------ Getting Audio ------
    final audioFiles = possibleAudioFiles.isNotEmpty
        ? possibleAudioFiles
        : await _getCachedAudiosForID.thready({
            "dirPath": AppDirs.AUDIOS_CACHE,
            "id": item.id,
          });
    final finalAudioFiles = audioFiles..sortByReverseAlt((e) => e.bitrate ?? 0, (e) => e.file.fileSizeSync() ?? 0);
    AudioCacheDetails? cachedAudio = finalAudioFiles.firstWhereEff((e) => e.file.existsSync());

    if (cachedAudio == null) {
      final localTrack = possibleLocalFiles.firstWhereEff((e) => File(e.path).existsSync());
      if (localTrack != null) {
        cachedAudio = AudioCacheDetails(
          youtubeId: item.id,
          bitrate: localTrack.bitrate,
          langaugeCode: null,
          langaugeName: null,
          file: File(localTrack.path),
        );
      }
    }

    const nullResult = (audio: null, video: null, duration: null);

    // ------ Playing ------
    if (cachedVideo != null && cachedAudio != null && !disableVideo) {
      // -- play audio & video
      await whatToAwait;
      try {
        if (checkInterrupted()) return nullResult;
        final dur = await setSource(
          AudioVideoSource.file(cachedAudio.file.path, tag: mediaItemFn()),
          item: item as Q?,
          startPlaying: startPlaying,
          videoOptions: VideoSourceOptions(
            source: AudioVideoSource.file(cachedVideo.path),
            loop: false,
            videoOnly: false,
          ),
          isVideoFile: true,
          cachedAudioPath: cachedAudio.file.path,
        );
        if (checkInterrupted()) return nullResult;
        final audioDetails = AudioCacheDetails(
          youtubeId: item.id,
          bitrate: cachedAudio.bitrate,
          langaugeCode: cachedAudio.langaugeCode,
          langaugeName: cachedAudio.langaugeName,
          file: cachedAudio.file,
        );
        return (audio: audioDetails, video: cachedVideo, duration: dur);
      } catch (_) {
        // error in video is handled internally
        // while error in audio means the cached file is probably faulty.
        return (audio: null, video: cachedVideo, duration: null);
      }
    } else if (cachedAudio != null && canPlayAudioOnly) {
      // -- play audio only
      await whatToAwait;
      if (checkInterrupted()) return nullResult;
      final dur = await setSource(
        AudioVideoSource.file(cachedAudio.file.path, tag: mediaItemFn()),
        item: item as Q?,
        startPlaying: startPlaying,
        cachedAudioPath: cachedAudio.file.path,
      );
      final audioDetails = AudioCacheDetails(
        youtubeId: item.id,
        bitrate: cachedAudio.bitrate,
        langaugeCode: cachedAudio.langaugeCode,
        langaugeName: cachedAudio.langaugeName,
        file: cachedAudio.file,
      );
      return (audio: audioDetails, video: null, duration: dur);
    } else if (cachedVideo != null && !disableVideo) {
      return (audio: null, video: cachedVideo, duration: null);
    }
    return nullResult;
  }

  /// TODO: improve using PortsProvider
  static List<AudioCacheDetails> _getCachedAudiosForID(Map map) {
    final dirPath = map["dirPath"] as String;
    final id = map["id"] as String;

    final newFiles = <AudioCacheDetails>[];

    for (final fe in Directory(dirPath).listSyncSafe()) {
      final filename = fe.path.getFilename;
      final goodID = filename.startsWith(id);
      final isGood = fe is File && goodID && !filename.endsWith('.part') && !filename.endsWith('.mime');

      if (isGood) {
        final details = _parseAudioCacheDetailsFromFile(fe);
        newFiles.add(details);
      }
    }
    return newFiles;
  }

  static Map<String, List<AudioCacheDetails>> _getAllAudiosInCache(String dirPath) {
    final newFiles = <String, List<AudioCacheDetails>>{};

    for (final fe in Directory(dirPath).listSyncSafe()) {
      final filename = fe.path.getFilename;
      final isGood = fe is File && !filename.endsWith('.part') && !filename.endsWith('.mime');

      if (isGood) {
        final details = _parseAudioCacheDetailsFromFile(fe);
        newFiles.addForce(details.youtubeId, details);
      }
    }
    return newFiles;
  }

  static AudioCacheDetails _parseAudioCacheDetailsFromFile(File file) {
    final filenamewe = file.path.getFilenameWOExt;
    final id = filenamewe.substring(0, 11); // 'Wd_gr91dgDa_23393.m4a' -> 'Wd_gr91dgDa'
    final languagesAndBitrate = filenamewe.substring(12, filenamewe.length - 1).split('_');
    final languageCode = languagesAndBitrate.length >= 2 ? languagesAndBitrate[0] : null;
    final languageName = languagesAndBitrate.length >= 3 ? languagesAndBitrate[1] : null;
    final bitrateText = filenamewe.splitLast('_');
    return AudioCacheDetails(
      file: file,
      bitrate: int.tryParse(bitrateText),
      langaugeCode: languageCode,
      langaugeName: languageName,
      youtubeId: id,
    );
  }

  @override
  void onNotificationFavouriteButtonPressed(Q item) {
    item._execute(
      selectable: (finalItem) {
        final newStat = PlaylistController.inst.favouriteButtonOnPressed(finalItem.track);
        _notificationUpdateItemSelectable(
          item: finalItem,
          itemIndex: currentIndex.value,
          isItemFavourite: newStat,
          duration: currentItemDuration.value,
        );
      },
      youtubeID: (finalItem) {
        final newStat = YoutubePlaylistController.inst.favouriteButtonOnPressed(finalItem.id);
        _notificationUpdateItemYoutubeID(
          item: finalItem,
          itemIndex: currentIndex.value,
          isItemFavourite: newStat,
          youtubeIdMediaItem: null,
        );
      },
    );
  }

  @override
  void onPlayingStateChange(bool isPlaying) {
    CurrentColor.inst.switchColorPalettes(isPlaying);
    WakelockController.inst.updatePlayPauseStatus(isPlaying);
    if (isPlaying) {
      _resourcesDisposeTimer?.cancel();
      _resourcesDisposeTimer = null;
    } else {
      _resourcesDisposeTimer ??= Timer(const Duration(minutes: 5), () {
        if (!this.isPlaying.value) stop();
      });
    }
  }

  @override
  void onRepeatForNtimesFinish() {
    settings.player.save(repeatMode: RepeatMode.none);
  }

  @override
  void onTotalListenTimeIncrease(Map<String, int> totalTimeInSeconds, String key) async {
    final newSeconds = totalTimeInSeconds[key] ?? 0;

    // saves the file each 20 seconds.
    if (newSeconds % 20 == 0) {
      final ci = currentItem.value;
      if (ci is Selectable) {
        _updateTrackLastPosition(ci.track, currentPositionMS.value);
        await File(AppPaths.TOTAL_LISTEN_TIME).writeAsJson(totalTimeInSeconds);
      }
    }
  }

  @override
  void onItemLastPositionReport(Q? currentItem, int currentPositionMs) async {
    await currentItem?._execute(
      selectable: (finalItem) async {
        await _updateTrackLastPosition(finalItem.track, currentPositionMS.value);
      },
      youtubeID: (finalItem) async {},
    );
  }

  @override
  void onPlaybackEventStream(PlaybackEvent event) {
    final item = currentItem.value;
    item?._execute(
      selectable: (finalItem) async {
        final isFav = finalItem.track.isFavourite;
        playbackState.add(transformEvent(event, isFav, currentIndex.value));
      },
      youtubeID: (finalItem) async {
        playbackState.add(transformEvent(event, false, currentIndex.value));
      },
    );
  }

  @override
  void onPlaybackCompleted() {
    VideoController.inst.videoControlsKey.currentState?.showControlsBriefly();
    VideoController.inst.videoControlsKeyFullScreen.currentState?.showControlsBriefly();
  }

  @override
  Future<void> setSkipSilenceEnabled(bool enabled) async {
    if (defaultPlayerConfig.skipSilence) await super.setSkipSilenceEnabled(enabled);
  }

  @override
  PlayerConfig get defaultPlayerConfig => PlayerConfig(
        skipSilence: settings.player.skipSilenceEnabled.value && currentItem.value is! YoutubeID,
        speed: settings.player.speed.value,
        volume: _userPlayerVolume,
        pitch: settings.player.pitch.value,
      );

  double get _userPlayerVolume => settings.player.volume.value;

  @override
  bool get enableCrossFade => settings.player.enableCrossFade.value && currentItem.value is! YoutubeID;

  @override
  int get defaultCrossFadeMilliseconds => settings.player.crossFadeDurationMS.value;

  @override
  int get defaultCrossFadeTriggerStartOffsetSeconds => settings.player.crossFadeAutoTriggerSeconds.value;

  @override
  bool get displayFavouriteButtonInNotification => settings.displayFavouriteButtonInNotification.value;

  @override
  bool get defaultShouldStartPlayingWhenPaused => settings.player.playOnNextPrev.value;

  @override
  bool get enableVolumeFadeOnPlayPause => settings.player.enableVolumeFadeOnPlayPause.value;

  @override
  bool get playerInfiniyQueueOnNextPrevious => settings.player.infiniyQueueOnNextPrevious.value;

  @override
  int get playerPauseFadeDurInMilli => settings.player.pauseFadeDurInMilli.value;

  @override
  int get playerPlayFadeDurInMilli => settings.player.playFadeDurInMilli.value;

  @override
  bool get playerPauseOnVolume0 => settings.player.pauseOnVolume0.value;

  @override
  RepeatMode get playerRepeatMode => settings.player.repeatMode.value;

  @override
  bool get playerResumeAfterOnVolume0Pause => settings.player.resumeAfterOnVolume0Pause.value;

  @override
  bool get jumpToFirstItemAfterFinishingQueue => settings.player.jumpToFirstTrackAfterFinishingQueue.value;

  @override
  int get listenCounterMarkPlayedPercentage => settings.isTrackPlayedPercentageCount.value;

  @override
  int get listenCounterMarkPlayedSeconds => settings.isTrackPlayedSecondsCount.value;

  @override
  int get maximumSleepTimerMins => kMaximumSleepTimerMins;

  @override
  int get maximumSleepTimerItems => kMaximumSleepTimerTracks;

  @override
  InterruptionAction get onBecomingNoisyEventStream => InterruptionAction.pause;

  @override
  Duration get defaultInterruptionResumeThreshold => Duration(minutes: settings.player.interruptionResumeThresholdMin.value);

  @override
  Duration get defaultVolume0ResumeThreshold => Duration(minutes: settings.player.volume0ResumeThresholdMin.value);

  bool get previousButtonReplays => settings.previousButtonReplays.value;

  // ------------------------------------------------------------

  Future<void> togglePlayPause() async {
    if (isPlaying.value) {
      await pause();
    } else {
      await play();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    Future<void> plsSeek() async => await super.seek(position);

    await currentItem.value?._execute(
      selectable: (finalItem) async {
        await plsSeek();
      },
      youtubeID: (finalItem) async {
        final wasPlaying = isPlaying.value;
        File? cachedAudioFile = _nextSeekSetAudioCache?.getFileIfPlaying(finalItem.id);
        File? cachedVideoFile = _nextSeekSetVideoCache?.getFileIfPlaying(finalItem.id);
        if (cachedAudioFile != null || cachedVideoFile != null) {
          await onPauseRaw();

          // <=======>
          if (cachedVideoFile != null && !await cachedVideoFile.exists()) {
            _nextSeekSetVideoCache = null;
            cachedVideoFile = null;
          }
          if (cachedAudioFile != null && !await cachedAudioFile.exists()) {
            _nextSeekSetAudioCache = null;
            cachedAudioFile = null;
          }

          // -- try putting cache version if it was cached
          if (cachedVideoFile != null && cachedAudioFile != null) {
            // -- both need to be set
            _nextSeekSetAudioCache = null;
            _nextSeekSetVideoCache = null;

            await setSource(
              AudioVideoSource.file(cachedAudioFile.path, tag: mediaItem),
              item: currentItem.value,
              keepOldVideoSource: true,
              cachedAudioPath: cachedAudioFile.path,
              startPlaying: () => wasPlaying,
              videoOptions: VideoSourceOptions(
                source: AudioVideoSource.file(cachedVideoFile.path),
                videoOnly: false,
                loop: false,
              ),
            );

            _isCurrentAudioFromCache = true;
          } else if (cachedVideoFile != null) {
            // -- only video needs to be set
            _nextSeekSetVideoCache = null;
            await setVideo(
              VideoSourceOptions(
                source: AudioVideoSource.file(cachedVideoFile.path),
                videoOnly: false,
                loop: false,
              ),
            );
          } else if (cachedAudioFile != null) {
            // -- only audio needs to be set
            _nextSeekSetAudioCache = null;
            await setSource(
              AudioVideoSource.file(cachedAudioFile.path, tag: mediaItem),
              item: currentItem.value,
              keepOldVideoSource: true,
              cachedAudioPath: cachedAudioFile.path,
              startPlaying: () => wasPlaying,
            );

            _isCurrentAudioFromCache = true;
          }
          // <=======>

          await plsSeek();
          if (wasPlaying) onPlayRaw();
        } else {
          await plsSeek();
        }
      },
    );
  }

  @override
  Future<void> skipToPrevious() async {
    if (previousButtonReplays) {
      final int secondsToReplay;
      if (settings.player.isSeekDurationPercentage.value) {
        final sFromP = (currentItemDuration.value?.inSeconds ?? 0) * (settings.player.seekDurationInPercentage.value / 100);
        secondsToReplay = sFromP.toInt();
      } else {
        secondsToReplay = settings.player.seekDurationInSeconds.value;
      }

      if (secondsToReplay > 0 && currentPositionMS.value > secondsToReplay * 1000) {
        await seek(Duration.zero);
        return;
      }
    }

    await super.skipToPrevious();
  }

  @override
  Future<void> onDispose() async {
    await [
      super.onDispose(),
      AudioService.forceStop(),
    ].execute();
  }

  @override
  Future<void> fastForward() async => await onFastForward();

  @override
  Future<void> rewind() async => await onRewind();

  Future<Duration?> setSource(
    AudioVideoSource source, {
    required Q? item,
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
    required bool Function() startPlaying,
    VideoSourceOptions? videoOptions,
    bool isVideoFile = false,
    String? cachedAudioPath,
    bool keepOldVideoSource = false,
  }) async {
    if (isVideoFile && videoOptions != null) {
      final source = videoOptions.source;
      if (source is UriSource) File.fromUri(source.uri).setLastAccessedTry(DateTime.now());
    }
    if (cachedAudioPath != null) {
      File(cachedAudioPath).setLastAccessedTry(DateTime.now());
    }
    if (videoOptions != null && !keepOldVideoSource) _latestVideoOptions = videoOptions;
    return setAudioSource(
      source,
      item: item,
      preload: preload,
      initialIndex: initialIndex,
      initialPosition: initialPosition,
      startPlaying: startPlaying,
      videoOptions: videoOptions,
      keepOldVideoSource: keepOldVideoSource,
    );
  }

  // ------- video -------

  Future<void> setVideoSource({required AudioVideoSource source, String cacheKey = '', bool loopingAnimation = false, bool isFile = false}) async {
    if (isFile && source is UriSource) File.fromUri(source.uri).setLastAccessedTry(DateTime.now());
    final videoOptions = VideoSourceOptions(
      source: source,
      loop: loopingAnimation,
      videoOnly: false,
    );
    _latestVideoOptions = videoOptions;
    await super.setVideo(videoOptions);
  }

  @override
  MediaControlsProvider get mediaControls => _mediaControls;

  static const _mediaControls = MediaControlsProvider(
    skipToPrevious: MediaControl.skipToPrevious,
    pause: MediaControl.pause,
    play: MediaControl.play,
    skipToNext: MediaControl.skipToNext,
    stop: MediaControl.stop,
    fastForward: MediaControl.fastForward,
    rewind: MediaControl.rewind,
  );
}

// ----------------------- Extensions --------------------------
extension TrackToAudioSourceMediaItem on Selectable {
  UriSource toAudioSource(int currentIndex, int queueLength, Duration? duration) {
    return AudioVideoSource.file(
      track.path,
      tag: toMediaItem(currentIndex, queueLength, duration),
    );
  }

  MediaItem toMediaItem(int currentIndex, int queueLength, Duration? duration) {
    final tr = track.toTrackExt();
    final artist = tr.originalArtist == '' ? UnknownTags.ARTIST : tr.originalArtist;
    final imagePage = tr.pathToImage;
    return MediaItem(
      id: tr.path,
      title: tr.title,
      displayTitle: tr.title,
      displaySubtitle: tr.hasUnknownAlbum ? artist : "$artist - ${tr.album}",
      displayDescription: "${currentIndex + 1}/$queueLength",
      artist: artist,
      album: tr.hasUnknownAlbum ? '' : tr.album,
      genre: tr.originalGenre,
      duration: duration ?? Duration(seconds: tr.duration),
      artUri: Uri.file(File(imagePage).existsSync() ? imagePage : AppPaths.NAMIDA_LOGO),
    );
  }
}

extension YoutubeIDToMediaItem on YoutubeID {
  MediaItem toMediaItem(String videoId, VideoStreamInfo? videoInfo, File? thumbnail, int currentIndex, int queueLength, Duration? duration) {
    final id = videoInfo?.id ?? videoId;
    final videoTitle = videoInfo?.title ?? YoutubeInfoController.utils.getVideoName(videoId);
    final artistAndTitle = videoInfo?.title.splitArtistAndTitle();
    final videoChannelTitle = videoInfo?.channelName ?? YoutubeInfoController.utils.getVideoChannelName(videoId);
    final videoDuration = duration ?? videoInfo?.durSeconds?.seconds ?? YoutubeInfoController.utils.getVideoDurationSeconds(videoId)?.seconds;

    final title = artistAndTitle?.$2?.keepFeatKeywordsOnly() ?? videoTitle ?? '';
    String? artistName = artistAndTitle?.$1;
    if ((artistName == null || artistName.isEmpty) && videoChannelTitle != null) {
      const topic = '- Topic';
      if (videoChannelTitle.endsWith(topic)) {
        artistName = videoChannelTitle.substring(0, videoChannelTitle.length - topic.length);
      }
    }

    return MediaItem(
      id: id,
      title: title,
      artist: artistName ?? videoChannelTitle ?? UnknownTags.ARTIST,
      album: '',
      genre: '',
      displayTitle: videoTitle,
      displaySubtitle: videoChannelTitle,
      displayDescription: "${currentIndex + 1}/$queueLength",
      duration: videoDuration ?? Duration.zero,
      artUri: Uri.file((thumbnail != null && thumbnail.existsSync()) ? thumbnail.path : AppPaths.NAMIDA_LOGO),
    );
  }
}

extension _PlayableExecuter on Playable {
  FutureOr<T?> _execute<T>({
    required FutureOr<T> Function(Selectable finalItem) selectable,
    required FutureOr<T> Function(YoutubeID finalItem) youtubeID,
  }) async {
    final item = this;
    if (item is Selectable) {
      return selectable(item);
    } else if (item is YoutubeID) {
      return youtubeID(item);
    }
    return null;
  }
}

typedef YoutubeIDToMediaItemCallback = MediaItem Function(int index, int queueLength);

/// Used to indicate that a file has been cached and should be set as a source.
class _NextSeekCachedFileData {
  final String videoId;
  final File? cacheFile;

  const _NextSeekCachedFileData({
    required this.videoId,
    required this.cacheFile,
  });

  File? getFileIfPlaying(String currentVideoId) {
    if (currentVideoId == videoId) return cacheFile;
    return null;
  }
}
