import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:basic_audio_handler/basic_audio_handler.dart';
import 'package:http_cache_stream/http_cache_stream.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:playlist_manager/module/playlist_id.dart';
import 'package:windows_taskbar/windows_taskbar.dart';
import 'package:youtipie/class/execute_details.dart';
import 'package:youtipie/class/streams/audio_stream.dart';
import 'package:youtipie/class/streams/video_stream.dart';
import 'package:youtipie/class/streams/video_stream_info.dart';
import 'package:youtipie/class/streams/video_streams_result.dart';
import 'package:youtipie/core/extensions.dart' show StreamFilterUtils;

import 'package:namida/class/audio_cache_detail.dart';
import 'package:namida/class/custom_mpv_player.dart';
import 'package:namida/class/func_execute_limiter.dart';
import 'package:namida/class/replay_gain_data.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/audio_cache_controller.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/home_widget_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/lyrics_controller.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/smtc_controller.dart';
import 'package:namida/controller/thumbnail_manager.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/controller/wakelock_controller.dart';
import 'package:namida/controller/waveform_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/main.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';

class NamidaAudioVideoHandler<Q extends Playable> extends BasicAudioHandler<Q> {
  @override
  AudioPipeline? get audioPipeline => AudioPipeline(
        androidAudioEffects: [
          equalizer,
          loudnessEnhancer._loudnessEnhancer,
        ],
      );

  late final equalizer = AndroidEqualizer();
  late final loudnessEnhancer = AndroidLoudnessEnhancerExtended();

  bool get _willPlayWhenReady => playWhenReady.value;

  RxBaseCore<Duration?> get currentItemDuration => _currentItemDuration;
  final _currentItemDuration = Rxn<Duration>();

  Timer? _resourcesDisposeTimer;

  @override
  AudioLoadConfiguration? get defaultAndroidLoadConfig {
    return AudioLoadConfiguration(
      androidLoadControl: AndroidLoadControl(
        minBufferDuration: const Duration(seconds: 5),
        maxBufferDuration: const Duration(minutes: 3),
        bufferForPlaybackAfterRebufferDuration: const Duration(seconds: 5),
        prioritizeTimeOverSizeThresholds: true,
      ),
    );
  }

  NamidaAudioVideoHandler() {
    AudioCacheController.inst.updateAudioCacheMap();
    playWhenReady.addListener(() {
      final ye = playWhenReady.value;
      CurrentColor.inst.switchColorPalettes(playWhenReady: ye);
      WakelockController.inst.updatePlayPauseStatus(ye);
      _refreshPlatformStatusDependersIsPlaying(ye);
    });

    final smtc = SMTCController.instance;
    if (smtc != null) {
      void listener() {
        final positionMS = currentPositionMS.value;
        final durationMS = currentItemDuration.value?.inMilliseconds;
        smtc.updateTimeline(positionMS, durationMS);
      }

      currentPositionMS.addListener(listener);
      currentItemDuration.addListener(listener);
    }

    if (Platform.isWindows) {
      void taskbarListener() {
        final durationMS = currentItemDuration.value?.inMilliseconds;
        if (durationMS != null && durationMS > 0) {
          final positionMS = currentPositionMS.value;
          WindowsTaskbar.setProgress(positionMS, durationMS);
        } else {
          WindowsTaskbar.setProgressMode(TaskbarProgressMode.normal);
        }
      }

      currentPositionMS.addListener(taskbarListener);
      currentItemDuration.addListener(taskbarListener);
    }
  }

  final currentVideoStream = Rxn<VideoStream>();
  final currentAudioStream = Rxn<AudioStream>();
  // final currentVideoThumbnail = Rxn<File>();
  final currentCachedVideo = Rxn<NamidaVideo>();
  final currentCachedAudio = Rxn<AudioCacheDetails>();

  final _allowSwitchingVideoStreamIfCachedPlaying = false;

  final isFetchingInfo = false.obs;

  bool get _isAudioOnlyPlayback => settings.youtube.isAudioOnlyMode.value;

  bool get isCurrentAudioFromCache => _isCurrentAudioFromCache;
  bool _isCurrentAudioFromCache = false;

  VideoSourceOptions? _latestVideoOptions;
  Future<void> setAudioOnlyPlayback(bool audioOnly) async {
    settings.youtube.save(isAudioOnlyMode: audioOnly);
    if (audioOnly) {
      await super.setVideo(null);
    } else {
      if (_latestVideoOptions != null) await super.setVideo(_latestVideoOptions);
    }
    if (_willPlayWhenReady) onPlayRaw();
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
    final remaining = track.durationMS - lastPositionMS;
    lastPositionMS = remaining <= 30000 ? 0 : lastPositionMS;

    await Indexer.inst.updateTrackStats(track, lastPositionInMs: lastPositionMS);
  }

  Future<void> _updateYoutubeIDLastPosition(YoutubeID item, int lastPositionMS) async {
    final duration = await YoutubeInfoController.utils.getVideoDuration(item.id) ?? _currentItemDuration.value;

    if (duration != null) {
      // Saves a starting position in case the remaining was less than 30 seconds.
      final remaining = duration.inMilliseconds - lastPositionMS;
      lastPositionMS = remaining <= 30000 ? 0 : lastPositionMS;
    }

    await YoutubeController.inst.statsManager.updateStats(item, lastPositionInMs: lastPositionMS);
  }

  FutureOr<Duration?> _getItemInitialPosition(Q item, Duration? itemDuration) async {
    final minValueInSetMinutes = settings.player.minTrackDurationToRestoreLastPosInMinutes.value;

    if (minValueInSetMinutes >= 0) {
      final minValueInSetMS = minValueInSetMinutes * 60 * 1000;
      final seekValueInMS = settings.player.seekDurationInSeconds.value * 1000;

      final lastPosAndDurationMSFn = item._executeAsync(
        selectable: (finalItem) {
          final track = finalItem.track.toTrackExt();
          final duration = itemDuration?.inMilliseconds ?? track.durationMS;
          return (track.stats?.lastPositionInMs, duration);
        },
        youtubeID: (finalItem) async {
          final duration = itemDuration ?? await YoutubeInfoController.utils.getVideoDuration(finalItem.id);
          final stats = await YoutubeController.inst.statsManager.getStats(finalItem);
          return (stats?.lastPositionInMs, duration?.inMilliseconds);
        },
      );

      final lastPosAndDurationMS = lastPosAndDurationMSFn is Future ? await lastPosAndDurationMSFn : lastPosAndDurationMSFn;
      if (lastPosAndDurationMS != null) {
        final lastPosMS = lastPosAndDurationMS.$1;
        final durationMS = lastPosAndDurationMS.$2;
        // -- only seek if not at the start of track.
        if (lastPosMS != null && durationMS != null && lastPosMS >= seekValueInMS) {
          if (durationMS >= minValueInSetMS) {
            return lastPosMS.milliseconds;
          }
        }
      }
    }
    return null;
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
  }) async {
    final media = await item.toMediaItem(currentIndex.value, currentQueue.value.length, duration);
    mediaItem.add(media);
    playbackState.add(transformEvent(PlaybackEvent(currentIndex: currentIndex.value), isItemFavourite, itemIndex));

    _refreshPlatformStatusDependers(media, playWhenReady.value, isItemFavourite);
  }

  void _notificationUpdateItemYoutubeID({
    required YoutubeID item,
    required bool isItemFavourite,
    required int itemIndex,
    required YoutubeIDToMediaItemCallback? youtubeIdMediaItem,
  }) async {
    youtubeIdMediaItem ??= (index, ql) {
      return item.toMediaItem(item.id, _ytNotificationVideoInfo, _ytNotificationVideoThumbnail, index, ql, currentItemDuration.value);
    };
    final index = currentIndex.value;
    final ql = currentQueue.value.length;
    final media = await youtubeIdMediaItem(index, ql);
    mediaItem.add(media);
    playbackState.add(transformEvent(PlaybackEvent(currentIndex: index), isItemFavourite, itemIndex));
    _refreshPlatformStatusDependers(media, playWhenReady.value, isItemFavourite);
  }

  void _refreshPlatformStatusDependersIsPlaying(bool isPlaying) {
    SMTCController.instance?.onPlayPause(isPlaying);
    HomeWidgetController.instance?.updateIsPlaying(isPlaying);
    _refreshWindowsTaskbar(isPlaying, null);
  }

  void _refreshPlatformStatusDependers(MediaItem media, bool isPlaying, bool isFavourite) {
    SMTCController.instance?.updateMetadata(media);
    HomeWidgetController.instance?.updateAll(
      media.displayTitle ?? media.title,
      media.displaySubtitle ?? media.artist ?? media.album,
      media.artUri,
      isPlaying,
      isFavourite,
    );
    _refreshWindowsTaskbar(isPlaying, isFavourite);
  }

  void _refreshWindowsTaskbar(bool isPlaying, bool? isFavourite) async {
    if (Platform.isWindows) {
      ThumbnailToolbarAssetIcon getIco(String name) => ThumbnailToolbarAssetIcon('assets\\icons\\media_ico\\$name.ico');

      isFavourite ??= currentItem.value?._execute(selectable: (finalItem) => finalItem.track.isFavourite, youtubeID: (finalItem) => finalItem.isFavourite);
      void onFavOrUnfavPress() {
        final current = currentItem.value;
        if (current != null) {
          onNotificationFavouriteButtonPressed(current);
        }
      }

      final repeat = settings.player.repeatMode.value;
      final repeatText = repeat.buildText();
      final repeatIcoName = switch (repeat) {
        RepeatMode.none => 'repeate-music',
        RepeatMode.one => 'repeate-one',
        RepeatMode.forNtimes => 'status',
        RepeatMode.all => 'repeat',
      };
      void onRepeatPress() {
        final e = settings.player.repeatMode.value.nextElement(RepeatMode.values);
        settings.player.save(repeatMode: e);
        _refreshWindowsTaskbar(_willPlayWhenReady, null);
      }

      try {
        String? title = mediaItem.value?.displayTitle ?? mediaItem.value?.title;
        if (title == null || title.isEmpty) {
          title = 'Namida';
        } else {
          title = '$title • Namida';
        }
        await Future.wait(
          [
            WindowsTaskbar.setWindowTitle(title),
            if (currentItem.value != null) // idk it just breaks if set after disposing
              WindowsTaskbar.setThumbnailToolbar(
                [
                  if (isFavourite == true)
                    ThumbnailToolbarButton(
                      getIco('favorited'),
                      lang.REMOVE_FROM_FAVOURITES,
                      onFavOrUnfavPress,
                    )
                  else if (isFavourite == false)
                    ThumbnailToolbarButton(
                      getIco('favorite'),
                      lang.ADD_TO_FAVOURITES,
                      onFavOrUnfavPress,
                    ),
                  ThumbnailToolbarButton(
                    getIco(repeatIcoName),
                    repeatText,
                    onRepeatPress,
                  ),
                  ThumbnailToolbarButton(
                    getIco('previous'),
                    lang.PREVIOUS,
                    Player.inst.previous,
                  ),
                  isPlaying
                      ? ThumbnailToolbarButton(
                          getIco('pause'),
                          lang.PAUSE,
                          Player.inst.pause,
                        )
                      : ThumbnailToolbarButton(
                          getIco('play'),
                          lang.PLAY,
                          Player.inst.play,
                        ),
                  ThumbnailToolbarButton(
                    getIco('next'),
                    lang.NEXT,
                    Player.inst.next,
                  ),
                  ThumbnailToolbarButton(
                    getIco('stop'),
                    lang.STOP,
                    () => Player.inst.pause().whenComplete(Player.inst.dispose),
                    mode: ThumbnailToolbarButtonMode.dismissionClick,
                  ),
                ],
              ),
          ],
        );
      } catch (_) {}
    }
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
    settings.extra.save(lastPlayedIndex: newIndex);
    newItem._execute(
      selectable: (finalItem) {
        CurrentColor.inst.updatePlayerColorFromTrack(finalItem, newIndex);
      },
      youtubeID: (finalItem) {
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

    itemDragged._execute(
      selectable: (finalItem) => CurrentColor.inst.updatePlayerColorFromTrack(null, currentIndex, updateIndexOnly: true),
      youtubeID: (finalItem) {},
    );

    await QueueController.inst.updateLatestQueue(currentQueue.value);
  }

  @override
  FutureOr<void> beforeQueueAddOrInsert(Iterable<Q> items) async {
    if (settings.mixedQueue.value) return;
    if (currentQueue.value.isEmpty) return;

    // this is what keeps local & youtube separated. this shall be removed if mixed playback ever got supported.
    final current = currentItem.value;
    final newItem = items.firstOrNull;

    final wasPlayWhenReady = playWhenReady.value;
    if (newItem is Selectable && current is! Selectable) {
      await clearQueue();
      await onDispose();
    } else if (newItem is YoutubeID && current is! YoutubeID) {
      await clearQueue();
      await onDispose();
    }
    setPlayWhenReady(wasPlayWhenReady);
  }

  @override
  FutureOr<void> clearQueue() async {
    videoPlayerInfo.value = null;
    Lyrics.inst.resetLyrics();
    WaveformController.inst.resetWaveform();
    CurrentColor.inst.resetCurrentPlayingTrack();

    VideoController.inst.currentVideo.value = null;
    VideoController.inst.currentVideoConfig.currentYTStreams.value = null;
    VideoController.inst.currentVideoConfig.currentPossibleLocalVideos.clear();

    YoutubeInfoController.current.resetAll();

    currentPositionMS.value = 0;
    _currentItemDuration.value = null;

    currentVideoStream.value = null;
    currentAudioStream.value = null;
    currentCachedVideo.value = null;
    currentCachedAudio.value = null;
    _isCurrentAudioFromCache = false;
    isFetchingInfo.value = false;
    _nextSeekSetAudioCache = null;
    _nextSeekSetVideoCache = null;
    await super.clearQueue();
  }

  @override
  Future<void>? beforeSkippingToItem() {
    NamidaNavigator.inst.popAllMenus();
    return super.beforeSkippingToItem(); // saving last position & waiting for reorder/removing.
  }

  @override
  Future<void> assignNewQueue<Id>({
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
    void Function()? onRestructuringQueue,
    Id Function(Q currentItem)? duplicateRemover,
  }) async {
    await beforeQueueAddOrInsert(queue);
    setPlayWhenReady(startPlaying);
    await super.assignNewQueue(
      playAtIndex: playAtIndex,
      queue: queue,
      maximumItems: maximumItems,
      shuffle: shuffle,
      onIndexAndQueueSame: onIndexAndQueueSame,
      onQueueDifferent: onQueueDifferent,
      onQueueEmpty: onQueueEmpty,
      onAssigningCurrentItem: onAssigningCurrentItem,
      onRestructuringQueue: () {
        if (playWhenReady.value && !isPlaying.value) play();
      },
      canRestructureQueueOnly: canRestructureQueueOnly ??
          (currentItem, itemToPlay) {
            if (itemToPlay is Selectable && currentItem is Selectable) {
              return itemToPlay.track.path == currentItem.track.path;
            } else if (itemToPlay is YoutubeID && currentItem is YoutubeID) {
              return itemToPlay.id == currentItem.id;
            }
            return false;
          },
      duplicateRemover: duplicateRemover,
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
    return (await item._execute<Future<int?>>(
          selectable: (finalItem) async {
            final dur = finalItem.track.durationMS;
            if (dur > 0) {
              return dur ~/ 1000;
            } else {
              final ap = AudioPlayer();
              final d = await ap.setFilePath(finalItem.track.path);
              ap.stop();
              ap.dispose();
              return d?.inSeconds ?? 0;
            }
          },
          youtubeID: (finalItem) async {
            final durSecCache = await YoutubeInfoController.utils.getVideoDurationSeconds(finalItem.id);
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
        final dateAddedMS = DateTime.now().millisecondsSinceEpoch;
        final newListen = YoutubeID(
          id: finalItem.id,
          watchNull: YTWatch(dateMSNull: dateAddedMS, isYTMusic: false),
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

  Future<void> _freePlayerTemporarily() async {
    // -- can cause issues, disabled currently.
    // return super.freePlayer();
  }

  @override
  FutureOr<ItemPrepareConfig<Q, UriSource>?> prepareItem(Q item, int index) async {
    return await item._executeAsync(
      selectable: (finalItem) async {
        return _itemToPrepareConfigSelectable(item, finalItem, index, null);
      },
      youtubeID: (finalItem) async {
        // TOOD: gapless for yt ?
        return null;
      },
    );
  }

  @override
  Future<void> onItemPlay(Q item, int index, Function skipItem, ItemPreparedPlayerInfo<Q>? preparedItemInfo) {
    _currentItemDuration.value = null;
    currentState.value = null;
    if (settings.enablePartyModeColorSwap.value) CurrentColor.inst.switchColorPalettes(item: item);
    return _fnLimiter.executeFuture(
      () async {
        return await item._execute(
          selectable: (finalItem) async {
            await onItemPlaySelectable(item, finalItem, index, skipItem, preparedItemInfo);
          },
          youtubeID: (finalItem) async {
            await onItemPlayYoutubeID(item, finalItem, index, skipItem);
            _tryAddingMixPlaylist(finalItem.id);
          },
        );
      },
      onRapidDetected: () {
        if (playWhenReady.value) {
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

  Future<ItemPrepareConfigSelectable<Q, UriSource>> _itemToPrepareConfigSelectable(Q pi, Selectable item, int index, Duration? duration,
      {CurrentVideoConfig? configToUpdate}) async {
    final isVideo = item is Video;
    final tr = item.track;
    duration ??= Duration(milliseconds: tr.durationMS);
    final configToUpdate = CurrentVideoConfig();
    final initialVideo = await VideoController.inst.updateCurrentVideo(tr, returnEarly: true, configToUpdate: configToUpdate);
    final videoOptions = !settings.enableVideoPlayback.value
        ? null
        : initialVideo == null
            ? isVideo
                ? VideoSourceOptions(
                    source: AudioVideoSource.file(item.path),
                    loop: false,
                    videoOnly: true,
                  )
                : null
            : VideoSourceOptions(
                source: AudioVideoSource.file(initialVideo.path),
                loop: VideoController.inst.canLoopVideo(initialVideo, duration.inMilliseconds),
                videoOnly: false,
              );
    return ItemPrepareConfigSelectable(
      tr.toAudioSource(currentIndex.value, currentQueue.value.length, duration),
      itemExists: await File(tr.path).exists(),
      item: pi,
      videoOptions: videoOptions,
      index: index,
      initialPosition: await _getItemInitialPosition(pi, duration),
      videoUpdateConfig: configToUpdate,
    );
  }

  Future<void> onItemPlaySelectable(Q pi, Selectable item, int index, Function skipItem, ItemPreparedPlayerInfo<Q>? preparedItemInfo) async {
    final tr = item.track;
    videoPlayerInfo.value = null;
    Lyrics.inst.resetLyrics();
    WaveformController.inst.resetWaveform();
    WaveformController.inst.generateWaveform(
      path: tr.path,
      duration: Duration(milliseconds: tr.durationMS),
      stillPlaying: (path) {
        final current = currentItem.value;
        return current is Selectable && path == current.track.path;
      },
    );

    Duration? duration;
    bool checkInterrupted() {
      if (item != currentItem.value) {
        return true;
      } else {
        if (duration != null) _currentItemDuration.value = duration;
        return false;
      }
    }

    if (tr.path.startsWith('/namida_dummy/')) return;

    // -- generating artwork in case it wasnt, to be displayed in notification
    File(tr.pathToImage).exists().then((exists) {
      // -- we check if it exists to avoid refreshing notification redundently.
      // -- otherwise `getArtwork` already handles duplications.
      if (!exists) {
        Indexer.inst.getArtwork(imagePath: tr.pathToImage, trackPath: tr.path, compressed: false, checkFileFirst: false).then((value) => refreshNotification());
      }
    });

    // -- hmm marking local tracks as yt-watched..?
    // final trackYoutubeId = tr.youtubeID;
    // if (trackYoutubeId.isNotEmpty) {
    //   YoutubeInfoController.history.markVideoWatched(videoId: trackYoutubeId, streamResult: null, errorOnMissingParam: false);
    // }

    ItemPrepareConfig<Q, UriSource>? preparedConfig = preparedItemInfo?.config;

    if (preparedConfig is ItemPrepareConfigSelectable<Q, UriSource>) {
      VideoController.inst.currentVideoConfig.updateFrom(preparedConfig.videoUpdateConfig);
    }
    Future<Duration?> setPls() async {
      bool itemReallyExists = preparedConfig?.itemExists == true ? true : File(tr.path).existsSync();
      if (!itemReallyExists) throw PathNotFoundException(tr.path, const OSError(), 'Track file not found or couldn\'t be accessed.');

      if (preparedConfig == null || preparedConfig!.item != item) {
        // -- creating new config
        preparedConfig = await _itemToPrepareConfigSelectable(pi, item, index, duration, configToUpdate: VideoController.inst.currentVideoConfig);
      } else {
        // -- using already prepared config
      }
      final config = preparedConfig!;
      final dur = await setSource(
        config.source,
        index: index,
        item: config.item,
        videoOptions: config.videoOptions,
        initialPosition: config.initialPosition,
        initialPositionFallback: (duration) => _getItemInitialPosition(pi, duration),
        isVideoFile: true,
      );

      if (dur != null) Indexer.inst.updateTrackDuration(tr, dur);

      refreshNotification(currentItem.value);
      return dur;
    }

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
        if (checkInterrupted()) return;
        if (hadPermissionBefore) {
          onPauseRaw();
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
          if (checkInterrupted()) return;
          try {
            duration = await setPls();
          } catch (_) {}
        }
      }
    }

    if (checkInterrupted()) return;

    final replayGainType = settings.player.replayGainType.value;
    if (replayGainType.isAnyEnabled) {
      final gainData = item.track.toTrackExt().gainData;
      if (replayGainType.isLoudnessEnhancerEnabled) {
        final gainToUse = gainData?.gainToUse;
        if (gainToUse != null) await loudnessEnhancer.setTargetGainTrack(gainToUse);
      } else if (replayGainType.isVolumeEnabled) {
        final vol = gainData?.calculateGainAsVolume();
        replayGainLinearVolume.value = vol ?? ReplayGainData.kDefaultFallbackVolume; // save in memory only
      }
    }

    if (preparedConfig?.videoOptions == null) VideoController.inst.updateCurrentVideo(tr, returnEarly: false);

    // -- to fix a bug where [headset buttons/android next gesture] sometimes don't get detected.
    if (playWhenReady.value) onPlayRaw(attemptFixVolume: false);

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
    _nextSeekSetAudioCache = null;
    _nextSeekSetVideoCache = null;
    _freePlayerTemporarily();

    setAudioOnlyPlayback(false);

    currentVideoStream.value = stream;
    currentCachedVideo.value = null;

    mainStreams ??= await YoutubeInfoController.video.fetchVideoStreams(videoId, forceRequest: false) ?? YoutubeInfoController.current.currentYTStreams.value;

    if (useCache && cachedFile != null && await cachedFile.exists()) {
      currentCachedVideo.value = videoItem;
      await setVideoSource(source: AudioVideoSource.file(cachedFile.path), isFile: true);
    } else if (stream != null) {
      if (!_willPlayWhenReady) await onPauseRaw();

      final bool expired = mainStreams?.hasExpired() ?? true;

      bool checkInterrupted() {
        final curr = currentItem.value;
        return !(curr is YoutubeID && curr.id == videoId);
      }

      Future<void> setVideoLockCache(VideoStream stream, Duration positionToRestore) async {
        final url = stream.buildUrl();
        if (url == null) throw Exception('null url');

        final cachedAudioPath = currentCachedAudio.value?.file.path;
        final curritem = currentItem.value;

        UriSource? activeAudioSource;
        if (cachedAudioPath != null) {
          activeAudioSource = AudioVideoSource.file(
            cachedAudioPath,
            // tag: curritem is YoutubeID
            //     ? curritem.toMediaItem(
            //         videoId,
            //         _ytNotificationVideoInfo,
            //         _ytNotificationVideoThumbnail,
            //         currentIndex.value,
            //         currentQueue.value.length,
            //         currentItemDuration.value,
            //       )
            //     : null,
          );
        } else {
          AudioStream? audioStream = currentAudioStream.value;
          if (audioStream == null) {
            final streamRes = mainStreams?.audioStreams;
            if (streamRes != null) audioStream = YoutubeController.inst.getPreferredAudioStream(streamRes);
          }
          if (audioStream != null) {
            final url = audioStream.buildUrl();
            if (url != null) {
              activeAudioSource = _buildLockCachingAudioSource(
                url,
                stream: audioStream,
                videoId: videoId,
                streamsResult: mainStreams,
              );
            }
          }
        }
        final videoOptions = VideoSourceOptions(
          source: _buildLockCachingVideoSource(
            url,
            stream: stream,
            videoId: videoId,
            streamsResult: mainStreams,
          ),
          loop: false,
          videoOnly: false,
        );
        // -- setting completely new source is needed as a workaround to internal source error
        //    where settings LockCachingVideoSource only throws source_not_found exception.
        // -- its not likely for activeAudioSource to be null but just in case
        activeAudioSource != null
            ? await setSource(
                activeAudioSource,
                index: currentIndex.value,
                item: curritem,
                initialPosition: positionToRestore,
                videoOptions: videoOptions,
                keepOldVideoSource: false,
                cachedAudioPath: cachedAudioPath,
              )
            : await setVideoSource(
                source: videoOptions.source,
              ).then((value) => positionToRestore > Duration.zero ? seek(positionToRestore) : null);

        refreshNotification();
      }

      if (!YoutubeInfoController.video.jsPreparedIfRequired) await YoutubeInfoController.video.ensureJSPlayerInitialized();

      final positionToRestore = currentPositionMS.value.milliseconds;

      try {
        if (expired) throw Exception('expired streams');
        await setVideoLockCache(stream, positionToRestore);
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
            await setVideoLockCache(sameStream, positionToRestore);
          } catch (_) {}
        }
      }
    }

    if (_willPlayWhenReady) onPlayRaw();
  }

  Future<void> onItemPlayYoutubeIDSetAudio({
    required VideoStreamsResult? mainStreams,
    required AudioStream? stream,
    required File? cachedFile,
    required bool useCache,
    required String videoId,
  }) async {
    _nextSeekSetAudioCache = null;
    _nextSeekSetVideoCache = null;
    _freePlayerTemporarily();

    currentAudioStream.value = stream;
    mainStreams ??= await YoutubeInfoController.video.fetchVideoStreams(videoId, forceRequest: false) ?? YoutubeInfoController.current.currentYTStreams.value;

    final cachedAudio = await stream?.getCachedFile(videoId);

    if (useCache && cachedAudio != null && await cachedAudio.exists()) {
      final positionToRestore = currentPositionMS.value.milliseconds;
      await setSource(
        AudioVideoSource.file(cachedAudio.path),
        index: currentIndex.value,
        item: currentItem.value,
        keepOldVideoSource: true,
        initialPosition: positionToRestore,
        cachedAudioPath: cachedAudio.path,
      );
      refreshNotification();
    } else if (stream != null) {
      if (!_willPlayWhenReady) await super.onPauseRaw();

      final bool expired = mainStreams?.hasExpired() ?? true;

      Future<void> setAudioLockCache(AudioStream stream, Duration positionToRestore) async {
        final url = stream.buildUrl();
        if (url == null) throw Exception('null url');
        await setSource(
          _buildLockCachingAudioSource(
            url,
            stream: stream,
            videoId: videoId,
            streamsResult: mainStreams,
          ),
          index: currentIndex.value,
          initialPosition: positionToRestore,
          item: currentItem.value,
          keepOldVideoSource: true,
        );
        refreshNotification();
      }

      bool checkInterrupted() {
        final curr = currentItem.value;
        return !(curr is YoutubeID && curr.id == videoId);
      }

      if (!YoutubeInfoController.video.jsPreparedIfRequired) await YoutubeInfoController.video.ensureJSPlayerInitialized();

      final positionToRestore = currentPositionMS.value.milliseconds;

      try {
        if (expired) throw Exception('expired streams');
        await setAudioLockCache(stream, positionToRestore);
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
            await setAudioLockCache(sameStream, positionToRestore);
          } catch (_) {}
        }
      }
    }

    if (_willPlayWhenReady) onPlayRaw();
  }

  _NextSeekCachedFileData? _nextSeekSetAudioCache;
  _NextSeekCachedFileData? _nextSeekSetVideoCache;

  Future<void> tryGenerateWaveform(YoutubeID? video) async {
    if (video != null && !settings.youtube.youtubeStyleMiniplayer.value) {
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
      final maybeCached = await prevVideoStream.getCachedFile(videoId);
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
            creationTimeMS: (prevVideoInfo?.publishedAt.accurateDate ?? prevVideoInfo?.publishDate.accurateDate)?.millisecondsSinceEpoch ?? 0,
            durationMS: prevVideoStream.duration?.inMilliseconds ?? 0,
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
    if (curr is YoutubeID && curr.id == videoId && !settings.youtube.youtubeStyleMiniplayer.value) {
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

    // -- Adding recently cached audio to cache map, to be displayed on cards.
    AudioCacheController.inst.removeFromCacheMap(videoId, audioCacheFile.path); // removing previous same entries
    AudioCacheController.inst.addToCacheMap(
        videoId,
        AudioCacheDetails(
          youtubeId: videoId,
          file: audioCacheFile,
          bitrate: prevAudioBitrate,
          langaugeCode: prevAudioLangCode,
          langaugeName: prevAudioLangName,
        ));

    // -- Writing metadata too
    // -- x (currently disabled, no need as to avoid issues, and downloading will already write tags)
    // final meta = await YTUtils.getMetadataInitialMap(videoId, null, null, prevAudioStream, prevVideoInfo, null, null, null, null);
    // await YTUtils.writeAudioMetadata(
    //   videoId: videoId,
    //   audioFile: audioCacheFile,
    //   thumbnailFile: null,
    //   tagsMap: meta,
    // );
  }

  VideoStreamInfo? _ytNotificationVideoInfo;
  File? _ytNotificationVideoThumbnail;

  /// Shows error if [marked] failed & saved as pending.
  void _onVideoMarkWatchResultError(YTMarkVideoWatchedResult marked) {
    if (marked == YTMarkVideoWatchedResult.addedAsPending) {
      snackyy(message: 'Failed to mark video as watched, saved as pending.', top: false, isError: true);
    }
  }

  Future<void> _tryAddingMixPlaylist(String videoId) async {
    if (!settings.youtube.autoStartRadio.value) return;

    if (currentQueue.length == 1) {
      bool checkInterrupted() {
        final currItem = currentItem.value;
        return currItem is! YoutubeID || currItem.id != videoId;
      }

      if (checkInterrupted()) return;

      final mixPlaylist = await YoutubeInfoController.playlist.getMixPlaylist(
        videoId: videoId,
        details: ExecuteDetails.forceRequest(),
      );

      if (checkInterrupted()) return;

      final playlistId = mixPlaylist?.mixId;
      final playlistIdWrapper = playlistId == null ? null : PlaylistID(id: playlistId);
      final items = mixPlaylist?.items;
      if (items != null && items.isNotEmpty) {
        final itemsMapped = (items.firstOrNull?.id == videoId ? items.skip(1) : items).map(
          (e) => YoutubeID(id: e.id, playlistID: playlistIdWrapper) as Q,
        );
        addToQueue(itemsMapped);
      }
    }
  }

  Future<void> onItemPlayYoutubeID(
    Q pi,
    YoutubeID item,
    int index,
    Function skipItem, {
    bool canPlayAudioOnlyFromCache = true, // dont link this to other stuff, if video is needed it will be taken care of.
  }) async {
    WaveformController.inst.resetWaveform();
    Lyrics.inst.resetLyrics();

    currentVideoStream.value = null;
    currentAudioStream.value = null;
    currentCachedVideo.value = null;
    currentCachedAudio.value = null;
    _isCurrentAudioFromCache = false;
    isFetchingInfo.value = false;
    _nextSeekSetAudioCache = null;
    _nextSeekSetVideoCache = null;
    YoutubeInfoController.current.onVideoPageReset?.call();

    if (item.id == '' || item.id == 'null') {
      if (_willPlayWhenReady && currentQueue.value.length > 1) skipItem();
      return;
    }

    VideoStreamsResult? streamsResult = await YoutubeInfoController.video.fetchVideoStreamsCache(item.id);

    YoutubeInfoController.current.currentYTStreams.value = streamsResult;
    final hadCachedVideoPageCompleter = Completer<bool>()..complete(YoutubeInfoController.current.updateVideoPageCache(item.id));
    final hadCachedCommentsCompleter = Completer<bool>()..complete(YoutubeInfoController.current.updateCurrentCommentsCache(item.id));

    Duration? duration = streamsResult?.audioStreams.firstOrNull?.duration;
    _ytNotificationVideoInfo = streamsResult?.info;
    _ytNotificationVideoThumbnail = await item.getThumbnail(temp: false);

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
      final hadCachedVideoPage = await hadCachedVideoPageCompleter.future;
      final hadCachedComments = await hadCachedCommentsCompleter.future;
      if (checkInterrupted(refreshNoti: false)) return;
      final requestPage = !hadCachedVideoPage;
      final requestComments = settings.youtube.preferNewComments.value ? true : !hadCachedComments;
      await YoutubeInfoController.current.updateVideoPage(
        item.id,
        requestPage: requestPage,
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
      // -- assign low res thumbnail temporarily until full res is fetched
      final tempThumb = await item.getThumbnail(temp: true);
      if (tempThumb != null) onInfoOrThumbObtained(thumbnail: tempThumb);

      ThumbnailManager.inst.getYoutubeThumbnailAndCache(id: item.id, type: ThumbnailType.video).then((thumbFile) async {
        thumbFile ??= await item.getThumbnail(temp: true);
        if (thumbFile != null) onInfoOrThumbObtained(thumbnail: thumbFile);
      });
    }

    bool heyIhandledPlaying = false;
    Future<void> plsplsplsPlay({required bool wasPlayingFromCache}) async {
      playWhenReady.value ? onPlayRaw(attemptFixVolume: false) : onPauseRaw();
      heyIhandledPlaying = true;

      if (!wasPlayingFromCache) {
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
      if (isPlaying.value && currentQueue.value.isNotEmpty) {
        // wait for pausing only if playing.
        pauseWithFadeEffect(
          enableFade: true,
          pauseFadeMillis: 100,
        ).then(
          (_) async {
            _freePlayerTemporarily(); // prevents playing previous item
            playerStoppingSeikoo?.complete(true);
          },
        );
      } else {
        _freePlayerTemporarily();
        playerStoppingSeikoo.complete(true);
      }
    }

    videoPlayerInfo.value = null;

    ({AudioCacheDetails? audio, NamidaVideo? video, Duration? duration}) playedFromCacheDetails = (audio: null, video: null, duration: null);
    bool okaySetFromCache() => playedFromCacheDetails.audio != null && (canPlayAudioOnlyFromCache || playedFromCacheDetails.video != null);

    bool generatedWaveform = false;
    void generateWaveform() {
      if (!generatedWaveform && !settings.youtube.youtubeStyleMiniplayer.value) {
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

    Duration? initialPosition = await _getItemInitialPosition(pi, duration);

    /// try playing cache always for faster playback initialization, if the quality should be
    /// different then it will be set later after fetching.
    playedFromCacheDetails = await _trySetYTVideoWithoutConnection(
      item: item,
      // mediaItemFn: () => item.toMediaItem(item.id, _ytNotificationVideoInfo, _ytNotificationVideoThumbnail, index, currentQueue.value.length, duration),
      checkInterrupted: checkInterrupted,
      index: index,
      canPlayAudioOnly: canPlayAudioOnlyFromCache,
      disableVideo: _isAudioOnlyPlayback,
      whatToAwait: playerStoppingSeikoo?.future,
      positionToRestore: initialPosition,
      initialPositionFallback: (duration) async => initialPosition = await _getItemInitialPosition(pi, duration),
    );

    duration ??= playedFromCacheDetails.duration;
    if (checkInterrupted()) return; // this also refreshes currentDuration

    if (!ConnectivityController.inst.hasConnection && playedFromCacheDetails.audio == null) {
      // -- if no connection and couldnt play from cache, we skip
      if (_willPlayWhenReady && currentQueue.value.length > 1) skipItem();
      return;
    }

    currentCachedAudio.value = playedFromCacheDetails.audio;
    currentCachedVideo.value = playedFromCacheDetails.video;

    void setReplayGainIfRequired() {
      final replayGainType = settings.player.replayGainType.value;
      if (replayGainType.isAnyEnabled && streamsResult != null) {
        final loudnessDb = streamsResult.loudnessDBData?.loudnessDb;

        if (replayGainType.isLoudnessEnhancerEnabled) {
          if (loudnessDb != null) loudnessEnhancer.setTargetGainTrack(-loudnessDb.toDouble());
        } else if (replayGainType.isVolumeEnabled) {
          final vol = loudnessDb == null ? null : ReplayGainData.convertGainToVolume(gain: -loudnessDb.toDouble());
          replayGainLinearVolume.value = vol ?? ReplayGainData.kDefaultFallbackVolume; // save in memory only
        }
      }
    }

    setReplayGainIfRequired();

    generateWaveform();

    if (okaySetFromCache()) {
      await plsplsplsPlay(wasPlayingFromCache: false);
    }

    if (checkInterrupted()) return;

    Duration? positionToRestore = heyIhandledPlaying && playedFromCacheDetails.audio != null ? currentPositionMS.value.milliseconds : initialPosition;

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
          streamsResult = await YoutubeInfoController.video.fetchVideoStreams(item.id).catchError((e) {
            snackyy(message: 'Error getting streams: $e', top: false, isError: true);
            return null;
          });
          setReplayGainIfRequired();
          if (streamsResult != null && (streamsResult.audioStreams.isNotEmpty || streamsResult.mixedStreams.isNotEmpty)) {
            // only when video has actual streams. otherwise its deleted/privated/etc
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

        if (streamsResult == null) {
          if (!okaySetFromCache()) snackyy(title: lang.ERROR, message: 'Failed to fetch streams', top: false, isError: true);
          return;
        }

        final audiostreams = streamsResult.audioStreams;
        final videoStreams = streamsResult.videoStreams;
        final mixedStreams = streamsResult.mixedStreams;

        bool useMixedStream = false;

        if (audiostreams.isEmpty) {
          if (mixedStreams.isEmpty) {
            // -- live videos has only mixedStreams
            if (!okaySetFromCache()) {
              final playabilty = streamsResult.playability;
              final extraReasons = [playabilty.reason, ...?playabilty.messages].whereType<String>();
              final extraReasonsText = extraReasons.isEmpty ? '' : ' | ${extraReasons.join(' | ')}';
              snackyy(title: lang.ERROR, message: 'Empty audio streams. playabilty: `${playabilty.status.name}`$extraReasonsText', top: false, isError: true);
              if (_willPlayWhenReady) skipItem();
            }
            return;
          } else {
            useMixedStream = true;
          }
        }

        // -----------------------
        UriSource? finalAudioSource;
        VideoSourceOptions? videoSourceOptions;

        if (useMixedStream) {
          UriSource? finalMixedSource;
          final prefferedMixedStream = YoutubeController.inst.getPreferredStreamQuality(mixedStreams, preferIncludeWebm: false);

          currentVideoStream.value = prefferedMixedStream;
          if (prefferedMixedStream != null) {
            final mixedUri = prefferedMixedStream.buildUrl();
            if (mixedUri != null) {
              finalMixedSource = HlsSource(mixedUri);
              finalAudioSource = AudioVideoSource.file('');
            }
          }
          if (finalMixedSource != null) {
            videoSourceOptions = VideoSourceOptions(
              source: finalMixedSource,
              loop: false,
              videoOnly: true,
            );
          } else {
            if (!okaySetFromCache()) snackyy(title: lang.ERROR, message: 'Failed to get mixed source', top: false, isError: true);
            return;
          }
        } else if (streamsResult.info?.isLive == true) {
          UriSource? finalLiveSource;
          if (streamsResult.hlsManifestUrl != null) {
            finalLiveSource = HlsSource(Uri.parse(streamsResult.hlsManifestUrl!));
          } else if (streamsResult.dashManifestUrl != null) {
            finalLiveSource = DashSource(Uri.parse(streamsResult.dashManifestUrl!));
          }

          if (finalLiveSource != null) {
            finalAudioSource = AudioVideoSource.file('');
            videoSourceOptions = VideoSourceOptions(
              source: finalLiveSource,
              loop: false,
              videoOnly: true,
            );
          } else {
            if (!okaySetFromCache()) snackyy(title: lang.ERROR, message: 'Failed to set hls or dash source for live stream', top: false, isError: true);
          }
        } else {
          AudioVideoSource? finalVideoSource;

          final cachedAudioSet = playedFromCacheDetails.audio;
          final cachedVideoSet = playedFromCacheDetails.video;

          _isCurrentAudioFromCache = cachedAudioSet != null;

          // -- setting audio
          final prefferedAudioStream = YoutubeController.inst.getPreferredAudioStream(audiostreams);
          bool isAudioStreamRequiredBetterThanCachedSet = cachedAudioSet == null
              ? true
              : prefferedAudioStream == null
                  ? false
                  : _allowSwitchingVideoStreamIfCachedPlaying
                      ? prefferedAudioStream.bitrate > prefferedAudioStream.bitrate
                      : false;
          if (isAudioStreamRequiredBetterThanCachedSet) {
            currentAudioStream.value = prefferedAudioStream;
            if (prefferedAudioStream != null) {
              final audioUri = prefferedAudioStream.buildUrl();
              if (audioUri != null) {
                finalAudioSource = _buildLockCachingAudioSource(
                  audioUri,
                  stream: prefferedAudioStream,
                  videoId: item.id,
                  streamsResult: streamsResult,
                );
              }
            }
          }

          // -- setting video
          if (!_isAudioOnlyPlayback &&
              videoStreams.isNotEmpty &&
              ConnectivityController.inst.dataSaverMode.canFetchNetworkVideoStreamShortContent(await YoutubeInfoController.utils.isShortContent(item.id))) {
            if (cachedVideoSet != null ? _allowSwitchingVideoStreamIfCachedPlaying : true) {
              final prefferedVideoStream = YoutubeController.inst.getPreferredStreamQuality(videoStreams, preferIncludeWebm: false);
              bool isVideoStreamRequiredBetterThanCachedSet = cachedVideoSet == null
                  ? true
                  : prefferedVideoStream == null
                      ? false
                      : _allowSwitchingVideoStreamIfCachedPlaying
                          ? prefferedVideoStream.width > cachedVideoSet.width
                          : false;

              if (isVideoStreamRequiredBetterThanCachedSet) {
                currentVideoStream.value = prefferedVideoStream;
                if (prefferedVideoStream != null) {
                  final videoUri = prefferedVideoStream.buildUrl();
                  if (videoUri != null) {
                    finalVideoSource = _buildLockCachingVideoSource(
                      videoUri,
                      stream: prefferedVideoStream,
                      videoId: item.id,
                      streamsResult: streamsResult,
                    );
                  }
                }
              }
            }
          }

          if (finalAudioSource == null && finalVideoSource == null) {
            if (!okaySetFromCache()) snackyy(title: lang.ERROR, message: 'Failed to get audio/video source', top: false, isError: true);
            return;
          }

          if (finalAudioSource != null || finalVideoSource != null) {
            heyIhandledPlaying = false;

            finalAudioSource ??= cachedAudioSet != null ? AudioVideoSource.file(cachedAudioSet.file.path) : null;
            finalVideoSource ??= cachedVideoSet != null && !_isAudioOnlyPlayback ? AudioVideoSource.file(cachedVideoSet.path) : null;

            if (finalVideoSource != null) {
              videoSourceOptions = VideoSourceOptions(
                source: finalVideoSource,
                loop: false,
                videoOnly: false,
              );
            }
          }
        }

        if (finalAudioSource == null) {
          if (!okaySetFromCache()) snackyy(title: lang.ERROR, message: 'Failed to get audio source', top: false, isError: true);
          return;
        }

        await playerStoppingSeikoo?.future;
        if (checkInterrupted()) return;
        if (!YoutubeInfoController.video.jsPreparedIfRequired) await YoutubeInfoController.video.ensureJSPlayerInitialized();
        if (checkInterrupted()) return;

        duration = await setSource(
          finalAudioSource,
          item: pi,
          index: index,
          initialPosition: positionToRestore,
          initialPositionFallback: (duration) => _getItemInitialPosition(pi, duration),
          videoOptions: videoSourceOptions,
          keepOldVideoSource: false,
          isVideoFile: false,
        );
        if (checkInterrupted()) return;

        // -----------------------
      } catch (e) {
        if (checkInterrupted()) return;
        if (!okaySetFromCache()) {
          void showSnackError(String nextAction) {
            if (item == currentItem.value) {
              snackyy(title: lang.ERROR, message: 'Error playing video, $nextAction: $e', top: false, isError: true);
            }
          }

          showSnackError('trying again');

          printy(e, isError: true);
          playedFromCacheDetails = await _trySetYTVideoWithoutConnection(
            item: item,
            // mediaItemFn: () => item.toMediaItem(item.id, _ytNotificationVideoInfo, _ytNotificationVideoThumbnail, index, currentQueue.value.length, duration),
            checkInterrupted: checkInterrupted,
            index: index,
            canPlayAudioOnly: canPlayAudioOnlyFromCache,
            disableVideo: _isAudioOnlyPlayback,
            whatToAwait: playerStoppingSeikoo?.future,
            positionToRestore: positionToRestore,
            initialPositionFallback: (duration) => _getItemInitialPosition(pi, duration),
          );
          _isCurrentAudioFromCache = playedFromCacheDetails.audio != null;
          duration ??= playedFromCacheDetails.duration;
          if (checkInterrupted()) return; // this also refreshes currentDuration
          generateWaveform();
          if (!okaySetFromCache()) {
            showSnackError('skipping');
            if (_willPlayWhenReady) skipItem();
          }
        }
      }
    }

    if (checkInterrupted()) return;

    if (!heyIhandledPlaying) {
      final didplayfromcache = okaySetFromCache();
      await plsplsplsPlay(wasPlayingFromCache: didplayfromcache);
    }
  }

  Future<void> recheckCachedVideos(String videoId) async {
    final current = currentItem.value;
    if (current is! YoutubeID || current.id != videoId) return;

    final allCachedVideos = await VideoController.inst.getNVFromIDSorted(videoId);
    YoutubeInfoController.current.currentCachedQualities.value = allCachedVideos;

    final currCachedV = currentCachedVideo.value;
    if (currCachedV != null && videoId == currCachedV.ytID) {
      if (!allCachedVideos.contains(currCachedV)) {
        currentCachedVideo.value = null;
      }
    }
  }

  /// Returns Audio File and Video File.
  Future<({AudioCacheDetails? audio, NamidaVideo? video, Duration? duration})> _trySetYTVideoWithoutConnection({
    required YoutubeID item,
    required bool Function() checkInterrupted,
    required int index,
    required bool canPlayAudioOnly,
    required bool disableVideo,
    required Future<void>? whatToAwait,
    required Duration? positionToRestore,
    required FutureOr<Duration?> Function(Duration duration) initialPositionFallback,
  }) async {
    // ------ Getting Video ------
    final allCachedVideos = await VideoController.inst.getNVFromIDSorted(item.id);
    YoutubeInfoController.current.currentCachedQualities.value = allCachedVideos;

    final cachedVideo = await allCachedVideos.firstWhereEffAsync((e) => File(e.path).exists());

    // ------ Getting Audio ------
    final cachedAudio = await AudioCacheController.inst.getCachedAudioForId(item.id);

    const nullResult = (audio: null, video: null, duration: null);

    // ------ Playing ------
    if (cachedVideo != null && cachedAudio != null && !disableVideo) {
      // -- play audio & video
      await whatToAwait;
      try {
        if (checkInterrupted()) return nullResult;
        final dur = await setSource(
          AudioVideoSource.file(cachedAudio.file.path),
          item: item as Q?,
          index: index,
          initialPosition: positionToRestore,
          initialPositionFallback: initialPositionFallback,
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
        AudioVideoSource.file(cachedAudio.file.path),
        item: item as Q?,
        index: index,
        initialPosition: positionToRestore,
        initialPositionFallback: initialPositionFallback,
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

  @override
  void onNotificationFavouriteButtonPressed(Q item) {
    item._execute(
      selectable: (finalItem) {
        final newStat = PlaylistController.inst.favouriteButtonOnPressed(finalItem.track, refreshNotification: false);
        _notificationUpdateItemSelectable(
          item: finalItem,
          itemIndex: currentIndex.value,
          isItemFavourite: newStat,
          duration: currentItemDuration.value,
        );
      },
      youtubeID: (finalItem) {
        final newStat = YoutubePlaylistController.inst.favouriteButtonOnPressed(finalItem.id, refreshNotification: false);
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
  void onRepeatModeChange(RepeatMode repeatMode) {
    settings.player.save(repeatMode: repeatMode);
  }

  @override
  void onTotalListenTimeIncrease(Map<String, int> totalTimeInSeconds, String key) async {
    final newSeconds = totalTimeInSeconds[key] ?? 0;

    // saves the file each 20 seconds.
    if (newSeconds % 20 == 0) {
      final ci = currentItem.value;
      if (ci is Selectable) {
        await File(AppPaths.TOTAL_LISTEN_TIME).writeAsJson(totalTimeInSeconds);
      }
    }
  }

  @override
  void onItemLastPositionReport(Q? currentItem, int currentPositionMs) async {
    await currentItem?._execute(
      selectable: (finalItem) => _updateTrackLastPosition(finalItem.track, currentPositionMS.value),
      youtubeID: (finalItem) => _updateYoutubeIDLastPosition(finalItem, currentPositionMS.value),
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
  Future<void> onPlaybackCompleted() {
    VideoController.inst.videoControlsKey.currentState?.showControlsBriefly();
    VideoController.inst.videoControlsKeyFullScreen.currentState?.showControlsBriefly();
    return super.onPlaybackCompleted();
  }

  @override
  Future<void> setSkipSilenceEnabled(bool enabled) async {
    if (defaultPlayerConfig.skipSilence) await super.setSkipSilenceEnabled(enabled);
  }

  @override
  PlayerConfig get defaultPlayerConfig => PlayerConfig(
        skipSilence: settings.player.skipSilenceEnabled.value && currentItem.value is! YoutubeID,
        speed: settings.player.speed.value,
        volume: _userPlayerVolume * replayGainLinearVolume.value,
        pitch: settings.player.pitch.value,
      );

  final replayGainLinearVolume = 1.0.obs;

  double get _userPlayerVolume => settings.player.volume.value;

  @override
  bool get enableCrossFade => settings.player.enableCrossFade.value && currentItem.value is! YoutubeID;

  @override
  bool get defaultGapelessEnabled => settings.player.enableGaplessPlayback.value && currentItem.value is! YoutubeID;

  @override
  int get defaultCrossFadeMilliseconds => settings.player.crossFadeDurationMS.value;

  @override
  int get defaultCrossFadeTriggerStartOffsetSeconds => settings.player.crossFadeAutoTriggerSeconds.value;

  @override
  bool get displayFavouriteButtonInNotification => settings.displayFavouriteButtonInNotification.value;

  @override
  bool get defaultShouldStartPlayingOnNextPrev => settings.player.playOnNextPrev.value;

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

  Future<void> togglePlayPause() {
    if (playWhenReady.value) {
      return pause();
    } else {
      return play();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    Future<void> plsSeek() => super.seek(position);

    await currentItem.value?._execute(
      selectable: (finalItem) => plsSeek(),
      youtubeID: (finalItem) async {
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
              AudioVideoSource.file(cachedAudioFile.path),
              index: currentIndex.value,
              item: currentItem.value,
              keepOldVideoSource: true,
              initialPosition: position,
              cachedAudioPath: cachedAudioFile.path,
              videoOptions: _isAudioOnlyPlayback
                  ? null
                  : VideoSourceOptions(
                      source: AudioVideoSource.file(cachedVideoFile.path),
                      videoOnly: false,
                      loop: false,
                    ),
            );

            _isCurrentAudioFromCache = true;
          } else if (cachedVideoFile != null && !_isAudioOnlyPlayback) {
            // -- only video needs to be set
            _nextSeekSetVideoCache = null;
            await setVideoSource(
              source: AudioVideoSource.file(cachedVideoFile.path),
              loopingAnimation: false,
            );
          } else if (cachedAudioFile != null) {
            // -- only audio needs to be set
            _nextSeekSetAudioCache = null;
            await setSource(
              AudioVideoSource.file(cachedAudioFile.path),
              index: currentIndex.value,
              item: currentItem.value,
              keepOldVideoSource: true,
              initialPosition: position,
              cachedAudioPath: cachedAudioFile.path,
            );

            _isCurrentAudioFromCache = true;
          }
          // <=======>

          await plsSeek();
          if (_willPlayWhenReady) onPlayRaw(attemptFixVolume: false);
        } else {
          await plsSeek();
        }
      },
    );
  }

  @override
  Future<void> skipToPrevious({bool isManualSkip = true}) async {
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
    mediaItem.add(null);
    await [
      super.onDispose(),
      if (Platform.isAndroid) AudioService.forceStop(),
    ].execute();
    SMTCController.instance?.onStop();
    _refreshWindowsTaskbar(false, null);
  }

  Timer? _headsetButtonClickTimer;
  int _headsetClicksCount = 0;

  Timer _createHeadsetClicksTimer(void Function() callback) {
    return Timer(Duration(milliseconds: 250), () {
      callback();

      // -- reset timer
      _headsetButtonClickTimer?.cancel();
      _headsetButtonClickTimer = null;
      _headsetClicksCount = 0;
    });
  }

  @override
  Future<void> click([MediaButton button = MediaButton.media]) async {
    if (button == MediaButton.next) {
      skipToNext();
      return;
    } else if (button == MediaButton.previous) {
      skipToPrevious();
      return;
    }

    _headsetClicksCount++;

    _headsetButtonClickTimer?.cancel();

    if (_headsetClicksCount == 1) {
      _headsetButtonClickTimer = _createHeadsetClicksTimer(_willPlayWhenReady ? pause : play);
    } else if (_headsetClicksCount == 2) {
      _headsetButtonClickTimer = _createHeadsetClicksTimer(skipToNext);
    } else if (_headsetClicksCount == 3) {
      _headsetButtonClickTimer = _createHeadsetClicksTimer(skipToPrevious);
    }
  }

  @override
  Future<void> fastForward() async => await onFastForward();

  @override
  Future<void> rewind() async => await onRewind();

  Future<Duration?> setSource(
    UriSource source, {
    required Q? item,
    required int index,
    Duration? initialPosition,
    FutureOr<Duration?> Function(Duration duration)? initialPositionFallback,
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
    if (!keepOldVideoSource) _latestVideoOptions = videoOptions;
    final duration = await setAudioSource(
      ItemPrepareConfig<Q, UriSource>(
        source,
        item: item,
        index: index,
        initialPosition: initialPosition,
        videoOptions: videoOptions,
        keepOldVideoSource: keepOldVideoSource,
      ),
    );
    if (initialPosition == null && initialPositionFallback != null && duration != null) {
      final p = await initialPositionFallback(duration);
      if (p != null && p > Duration.zero && p != initialPosition) seek(p);
    }
    return duration;
  }

  @override
  Future<MediaItem> itemToMediaItem(Q item) {
    return item._execute(
      selectable: (finalItem) {
        int durMS = finalItem.track.durationMS;
        return finalItem.toMediaItem(currentIndex.value, currentQueue.value.length, durMS > 0 ? durMS.milliseconds : currentItemDuration.value);
      },
      youtubeID: (finalItem) =>
          finalItem.toMediaItem(finalItem.id, _ytNotificationVideoInfo, _ytNotificationVideoThumbnail, currentIndex.value, currentQueue.value.length, currentItemDuration.value),
    )!;
  }

  @override
  String itemToMediaItemId(Q item) {
    return item._execute(
      selectable: (finalItem) => finalItem.toMediaItemId(),
      youtubeID: (finalItem) => finalItem.toMediaItemId(),
    )!;
  }

  // ------- video -------

  Future<void> setVideoSource({required AudioVideoSource source, bool loopingAnimation = false, bool isFile = false, bool videoOnly = false}) async {
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
  static const _mediaControls = MediaControlsProvider.main();

  // -- builders

  UriSource _buildAVSource(
    Uri uriDDL, {
    required File cacheFile,
    required String videoId,
    required VideoStreamsResult? streamsResult,
    required void Function(File cachedFile) onCacheDone,
  }) {
    // -- this part might not be used, live streams are built different early
    final isLive = streamsResult != null && (streamsResult.info?.isLive == true || streamsResult.audioStreams.isEmpty && streamsResult.mixedStreams.isNotEmpty);
    if (isLive) {
      if (streamsResult.hlsManifestUrl != null) {
        return HlsSource(Uri.parse(streamsResult.hlsManifestUrl!));
      } else if (streamsResult.dashManifestUrl != null) {
        return DashSource(Uri.parse(streamsResult.dashManifestUrl!));
      } else {
        return AudioVideoSource.file('');
      }
    }

    final cacheConfig = HttpCacheManager.instance.createStreamConfig();

    cacheConfig.onCacheDone = onCacheDone;
    final cacheStream = HttpCacheManager.instance.createStream(
      uriDDL,
      file: cacheFile,
      config: cacheConfig,
    );
    cacheStream.download();
    final cacheUrl = cacheStream.cacheUrl;
    void disposeStream() => cacheStream.dispose(force: true);
    return AudioVideoSource.uri(cacheUrl, onDispose: disposeStream);
  }

  UriSource _buildLockCachingAudioSource(Uri uriDDL, {required AudioStream stream, required String videoId, required VideoStreamsResult? streamsResult}) {
    return _buildAVSource(
      uriDDL,
      cacheFile: File(stream.cachePath(videoId)),
      videoId: videoId,
      streamsResult: streamsResult,
      onCacheDone: (cachedFile) => _onAudioCacheDone(videoId, cachedFile),
    );
  }

  UriSource _buildLockCachingVideoSource(Uri uriDDL, {required VideoStream stream, required String videoId, required VideoStreamsResult? streamsResult}) {
    return _buildAVSource(
      uriDDL,
      cacheFile: File(stream.cachePath(videoId)),
      videoId: videoId,
      streamsResult: streamsResult,
      onCacheDone: (cachedFile) => _onVideoCacheDone(videoId, cachedFile),
    );
  }

  @override
  AVPlayer createPlayerInstance() {
    return switch (InternalPlayerType.platformDefault) {
      InternalPlayerType.exoplayer => CustomAudioPlayer(
          AudioPlayer(
            androidApplyAudioAttributes: false,
            handleInterruptions: false,
            handleAudioSessionActivation: true,
            audioLoadConfiguration: defaultAndroidLoadConfig,
            audioPipeline: audioPipeline,
          ),
        ),
      InternalPlayerType.mpv => CustomMPVPlayer(),
    };
  }
}

// ----------------------- Extensions --------------------------
extension TrackToAudioSourceMediaItem on Selectable {
  UriSource toAudioSource(int currentIndex, int queueLength, Duration? duration) {
    return AudioVideoSource.file(
      track.path,
      // tag: toMediaItem(currentIndex, queueLength, duration),
    );
  }

  String toMediaItemId() => track.path;

  Future<MediaItem> toMediaItem(int currentIndex, int queueLength, Duration? duration) async {
    final tr = track.toTrackExt();
    final artist = tr.originalArtist == '' ? UnknownTags.ARTIST : tr.originalArtist;
    final imagePath = tr.pathToImage;
    String? imagePathToUse = await File(imagePath).exists() ? imagePath : null;
    imagePathToUse ??= Indexer.inst.getFallbackFolderArtworkPath(folderPath: tr.folderPath);
    return MediaItem(
      id: this.toMediaItemId(),
      title: tr.title,
      displayTitle: tr.title,
      displaySubtitle: tr.hasUnknownAlbum ? artist : "$artist - ${tr.album}",
      displayDescription: "${currentIndex + 1}/$queueLength",
      artist: artist,
      album: tr.hasUnknownAlbum ? '' : tr.album,
      genre: tr.originalGenre,
      duration: duration ?? Duration(milliseconds: tr.durationMS),
      artUri: Uri.file(imagePathToUse ?? AppPaths.NAMIDA_LOGO_MONET),
    );
  }
}

extension YoutubeIDToMediaItem on YoutubeID {
  String toMediaItemId() => id;

  Future<MediaItem> toMediaItem(String videoId, VideoStreamInfo? videoInfo, File? thumbnail, int currentIndex, int queueLength, Duration? duration) async {
    final id = this.id.isNotEmpty ? this.id : videoInfo?.id ?? videoId;
    final videoTitle = videoInfo?.title ?? await YoutubeInfoController.utils.getVideoName(videoId);
    final artistAndTitle = videoTitle?.splitArtistAndTitle();
    final videoChannelTitle = videoInfo?.channelName ?? await YoutubeInfoController.utils.getVideoChannelName(videoId);
    final videoDuration = duration ?? videoInfo?.durSeconds?.seconds ?? await YoutubeInfoController.utils.getVideoDurationSeconds(videoId).then((value) => value?.seconds);

    final title = artistAndTitle?.$2?.keepFeatKeywordsOnly() ?? videoTitle ?? '';
    String? artistName = artistAndTitle?.$1;
    if ((artistName == null || artistName.isEmpty) && videoChannelTitle != null) {
      const topic = '- Topic';
      if (videoChannelTitle.endsWith(topic)) {
        artistName = videoChannelTitle.substring(0, videoChannelTitle.length - topic.length);
      }
    }

    final imagePath = thumbnail?.path;
    String? imagePathToUse = imagePath != null && await File(imagePath).exists() ? imagePath : null;

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
      artUri: Uri.file(imagePathToUse ?? AppPaths.NAMIDA_LOGO_MONET),
    );
  }
}

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

  FutureOr<T?> _executeAsync<T>({
    required FutureOr<T?> Function(Selectable finalItem) selectable,
    required FutureOr<T?> Function(YoutubeID finalItem) youtubeID,
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

typedef YoutubeIDToMediaItemCallback = Future<MediaItem> Function(int index, int queueLength);

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

class AndroidLoudnessEnhancerExtended {
  final _loudnessEnhancer = AndroidLoudnessEnhancer();

  static const kMaxGain = 12.0;
  static const kMinGain = -12.0;

  final targetGainUser = 0.0.obs;
  final targetGainTrack = 0.0.obs;

  final enabledUser = false.obs;
  bool get _enabledTrackValue => settings.player.replayGainType.value.isLoudnessEnhancerEnabled;

  double get getActualGain => (enabledUser.value ? targetGainUser.value : 0) + (_enabledTrackValue ? targetGainTrack.value : 0.0);
  bool get getActualEnabled => enabledUser.value || _enabledTrackValue;

  Future<void> setTargetGainUser(double gain) {
    targetGainUser.value = gain;
    return _refreshGain();
  }

  Future<void> setTargetGainTrack(double gain) {
    targetGainTrack.value = gain;
    return _refreshGain();
  }

  Future<void> setEnabledUser(bool enabled) {
    enabledUser.value = enabled;
    refreshEnabled();
    return _refreshGain();
  }

  Future<void> _refreshGain() {
    return _loudnessEnhancer.setTargetGain(getActualGain);
  }

  Future<void> refreshEnabled() {
    return _loudnessEnhancer.setEnabled(getActualEnabled);
  }
}

class ItemPrepareConfigSelectable<Q, S extends UriSource> extends ItemPrepareConfig<Q, S> {
  final CurrentVideoConfig videoUpdateConfig;
  const ItemPrepareConfigSelectable(
    super.source, {
    required super.index,
    required super.initialPosition,
    required super.videoOptions,
    required this.videoUpdateConfig,
    super.item,
    super.itemExists,
    super.keepOldVideoSource = false,
  });
}
