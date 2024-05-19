import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:basic_audio_handler/basic_audio_handler.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_utils/src/extensions/num_extensions.dart';
import 'package:just_audio/just_audio.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:playlist_manager/module/playlist_id.dart';

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
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/thumbnail_manager.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/controller/wakelock_controller.dart';
import 'package:namida/controller/waveform_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/main.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
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

  Duration? get currentItemDuration => _currentItemDuration.value;
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

  Selectable get currentTrack => (currentItem is Selectable ? currentItem as Selectable : null) ?? kDummyTrack;
  YoutubeID? get currentVideo => currentItem is YoutubeID ? currentItem as YoutubeID : null;
  List<Selectable> get currentQueueSelectable => currentQueue.firstOrNull is Selectable ? currentQueue.cast<Selectable>() : [];
  List<YoutubeID> get currentQueueYoutubeID => currentQueue.firstOrNull is YoutubeID ? currentQueue.cast<YoutubeID>() : [];

  final currentVideoInfo = Rxn<VideoInfo>();
  final currentChannelInfo = Rxn<YoutubeChannel>();
  final currentVideoStream = Rxn<VideoOnlyStream>();
  final currentAudioStream = Rxn<AudioOnlyStream>();
  final currentVideoThumbnail = Rxn<File>();
  final currentCachedVideo = Rxn<NamidaVideo>();
  final currentCachedAudio = Rxn<AudioCacheDetails>();

  final _allowSwitchingVideoStreamIfCachedPlaying = false;

  bool get isFetchingInfo => _isFetchingInfo.value;
  final _isFetchingInfo = false.obs;

  bool get isAudioOnlyPlayback => settings.ytIsAudioOnlyMode.value;

  bool get isCurrentAudioFromCache => _isCurrentAudioFromCache;
  bool _isCurrentAudioFromCache = false;

  VideoOptions? _latestVideoOptions;
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

  void refreshNotification([Q? item, VideoInfo? videoInfo]) {
    final exectuteOn = item ?? currentItem;
    exectuteOn?._execute(
      selectable: (finalItem) {
        _notificationUpdateItem(item: exectuteOn, isItemFavourite: finalItem.track.isFavourite, itemIndex: currentIndex);
      },
      youtubeID: (finalItem) {
        _notificationUpdateItem(item: exectuteOn, isItemFavourite: false, itemIndex: currentIndex, videoInfo: videoInfo);
      },
    );
  }

  void _notificationUpdateItem({required Q item, required bool isItemFavourite, required int itemIndex, VideoInfo? videoInfo}) {
    item._execute(
      selectable: (finalItem) async {
        mediaItem.add(finalItem.toMediaItem(currentIndex, currentQueue.length));
        playbackState.add(transformEvent(PlaybackEvent(currentIndex: currentIndex), isItemFavourite, itemIndex));
      },
      youtubeID: (finalItem) async {
        final info = videoInfo ?? YoutubeController.inst.getVideoInfo(finalItem.id);
        final thumbnail = finalItem.getThumbnailSync();
        mediaItem.add(finalItem.toMediaItem(info, thumbnail, currentIndex, currentQueue.length));
        playbackState.add(transformEvent(PlaybackEvent(currentIndex: currentIndex), isItemFavourite, itemIndex));
      },
    );
  }

  // =================================================================================
  //

  //
  // ==============================================================================================
  // ==============================================================================================
  // ================================== QueueManager Overriden ====================================

  @override
  void onIndexChanged(int newIndex, Q newItem) async {
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
  void onQueueChanged() async {
    super.onQueueChanged();
    if (currentQueue.isEmpty) {
      CurrentColor.inst.resetCurrentPlayingTrack();
      if (MiniPlayerController.inst.isInQueue) MiniPlayerController.inst.snapToMini();
      // await pause();
      await [
        onDispose(),
        QueueController.inst.emptyLatestQueue(),
      ].execute();
    } else {
      refreshNotification(currentItem);
      await QueueController.inst.updateLatestQueue(currentQueue, source: QueueSource.playerQueue);
    }
  }

  @override
  void onReorderItems(int currentIndex, Q itemDragged) async {
    // usually not needed, since [beforePlaying] already assign if miniplayer is reordering.
    MiniPlayerController.inst.reorderingQueueCompleterPlayer ??= Completer<void>();

    await super.onReorderItems(currentIndex, itemDragged);
    refreshNotification();
    MiniPlayerController.inst.reorderingQueueCompleterPlayer?.completeIfWasnt();
    MiniPlayerController.inst.reorderingQueueCompleterPlayer = null;

    await itemDragged._execute(
      selectable: (finalItem) {
        CurrentColor.inst.updatePlayerColorFromTrack(null, currentIndex, updateIndexOnly: true);
      },
      youtubeID: (finalItem) {},
    );

    await QueueController.inst.updateLatestQueue(currentQueue, source: QueueSource.playerQueue);
  }

  @override
  FutureOr<void> beforeRemovingPlayingItemFromQueue(bool wasLatest) async {
    MiniPlayerController.inst.reorderingQueueCompleter?.completeIfWasnt();
    MiniPlayerController.inst.reorderingQueueCompleterPlayer?.completeIfWasnt();
  }

  @override
  FutureOr<void> removeFromQueue(int index, bool startPlayingIfRemovedCurrent) async {
    await super.removeFromQueue(index, startPlayingIfRemovedCurrent);
    MiniPlayerController.inst.reorderingQueueCompleter?.completeIfWasnt();
    MiniPlayerController.inst.reorderingQueueCompleterPlayer?.completeIfWasnt();
  }

  @override
  FutureOr<void> beforeQueueAddOrInsert(Iterable<Q> items) async {
    if (currentQueue.isEmpty) return;
    await items._execute(
      selectable: (finalItems) async {
        if (currentQueue.firstOrNull is! Selectable) {
          await clearQueue();
        }
      },
      youtubeID: (finalItem) async {
        if (currentQueue.firstOrNull is! YoutubeID) {
          await clearQueue();
        }
      },
    );
  }

  @override
  FutureOr<void> clearQueue() async {
    CurrentColor.inst.resetCurrentPlayingTrack();

    VideoController.inst.currentVideo.value = null;
    VideoController.inst.currentYTQualities.clear();
    VideoController.inst.currentPossibleVideos.clear();

    YoutubeController.inst.currentYTQualities.clear();
    YoutubeController.inst.currentYTAudioStreams.clear();
    YoutubeController.inst.currentCachedQualities.clear();
    YoutubeController.inst.currentComments.clear();
    YoutubeController.inst.currentRelatedVideos.clear();

    currentVideoInfo.value = null;
    currentChannelInfo.value = null;
    currentVideoStream.value = null;
    currentAudioStream.value = null;
    currentVideoThumbnail.value = null;
    currentCachedVideo.value = null;
    currentCachedAudio.value = null;
    _isCurrentAudioFromCache = false;
    _isFetchingInfo.value = false;
    _nextSeekSetAudioCache = null;
    await super.clearQueue();
  }

  @override
  FutureOr<void> beforePlaying() async {
    super.beforePlaying(); // saving last position.
    // _audioShouldBeLoading ??= Completer<void>();
    NamidaNavigator.inst.popAllMenus();
    ScrollSearchController.inst.unfocusKeyboard();

    if (MiniPlayerController.inst.isReorderingQueue) {
      MiniPlayerController.inst.reorderingQueueCompleterPlayer ??= Completer<void>();
    }

    /// -- Adding videos that may have been cached to VideoController cache map,
    /// for the sake of playing videos without connection, usually videos are added automatically
    /// on restart but this keeps things up-to-date.
    ///
    /// also adds newly cached audios.
    void fn() async {
      final prevVideo = currentVideoInfo.value;
      final prevStream = currentVideoStream.value;
      final vId = prevVideo?.id;
      if (vId != null) {
        // -- Video handling
        if (prevVideo != null && prevStream != null) {
          final maybeCached = prevStream.getCachedFile(vId);
          if (maybeCached != null) {
            int? parsy(String? s) => s == null ? null : DateTime.tryParse(s)?.millisecondsSinceEpoch;

            VideoController.inst.addYTVideoToCacheMap(
              vId,
              NamidaVideo(
                path: maybeCached.path,
                ytID: vId,
                height: prevStream.height ?? 0,
                width: prevStream.width ?? 0,
                sizeInBytes: prevStream.sizeInBytes ?? 0,
                frameratePrecise: prevStream.fps?.toDouble() ?? 0.0,
                creationTimeMS: prevVideo.date?.millisecondsSinceEpoch ?? parsy(prevVideo.textualUploadDate) ?? 0,
                durationMS: prevStream.durationMS ?? 0,
                bitrate: prevStream.bitrate ?? 0,
              ),
            );
          }
        }
      }
    }

    currentItem?._execute(
      selectable: (finalItems) async => fn(),
      youtubeID: (finalItem) async => fn(),
    );

    await MiniPlayerController.inst.reorderingQueueCompleter?.future; // wait if reordering
    await MiniPlayerController.inst.reorderingQueueCompleterPlayer?.future; // wait if updating lists after reordering
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
  InterruptionAction defaultOnInterruption(InterruptionType type) => settings.player.onInterrupted[type] ?? InterruptionAction.pause;

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
            final dur = await finalItem.getDuration();
            return dur?.inSeconds ?? 0;
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
        HistoryController.inst.addTracksToHistory([newTrackWithDate]);
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
        if (isPlaying) {
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

    MiniPlayerController.inst.reorderingQueueCompleterPlayer?.completeIfWasnt();
  }

  int get playErrorRemainingSecondsToSkip => _playErrorRemainingSecondsToSkip.value;
  Timer? _playErrorSkipTimer;
  final _playErrorRemainingSecondsToSkip = 0.obs;
  void cancelPlayErrorSkipTimer() {
    _playErrorSkipTimer?.cancel();
    _playErrorSkipTimer = null;
    _playErrorRemainingSecondsToSkip.value = 0;
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
        final current = currentItem;
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

    Future<Duration?> setPls() async {
      final dur = await setSource(
        tr.toAudioSource(currentIndex, currentQueue.length),
        item: pi,
        startPlaying: startPlaying,
        videoOptions: initialVideo == null
            ? null
            : VideoOptions(
                source: initialVideo.path,
                enableCaching: true,
                cacheKey: '',
                cacheDirectory: _defaultCacheDirectory,
                maxTotalCacheSize: _defaultMaxCache,
              ),
        isVideoFile: true,
      );
      Indexer.inst.updateTrackDuration(tr, dur);

      refreshNotification(currentItem);
      return dur;
    }

    Duration? duration;

    bool checkInterrupted() {
      if (item.track != currentTrack.track) {
        return true;
      } else {
        if (duration != null) _currentItemDuration.value = duration;
        return false;
      }
    }

    try {
      duration = await setPls();
      if (checkInterrupted()) return;
    } on Exception catch (e) {
      if (checkInterrupted()) return;
      final reallyError = !(duration != null && currentPositionMS > 0);
      if (reallyError) {
        printy(e, isError: true);
        // -- playing music from root folders still require `all_file_access`
        // -- this is a fix for not playing some external files reported by some users.
        final hadPermissionBefore = await Permission.manageExternalStorage.isGranted;
        if (hadPermissionBefore) {
          pause();
          cancelPlayErrorSkipTimer();
          _playErrorRemainingSecondsToSkip.value = 7;

          _playErrorSkipTimer = Timer.periodic(
            const Duration(seconds: 1),
            (timer) {
              _playErrorRemainingSecondsToSkip.value--;
              if (_playErrorRemainingSecondsToSkip.value <= 0) {
                NamidaNavigator.inst.closeDialog();
                if (currentQueue.length > 1) skipItem();
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

    if (initialVideo == null) VideoController.inst.updateCurrentVideo(tr, returnEarly: false);

    // -- to fix a bug where [headset buttons/android next gesture] sometimes don't get detected.
    if (startPlaying()) onPlayRaw();

    startSleepAfterMinCount();
    startCounterToAListen(pi);
    increaseListenTime(LibraryCategory.localTracks);
    Lyrics.inst.updateLyrics(tr);
  }

  Future<void> onItemPlayYoutubeIDSetQuality({
    required VideoOnlyStream? stream,
    required File? cachedFile,
    required bool useCache,
    required String videoId,
    required NamidaVideo? videoItem,
  }) async {
    final wasPlaying = isPlaying;
    setAudioOnlyPlayback(false);

    currentVideoStream.value = stream;
    currentCachedVideo.value = null;

    if (cachedFile != null && useCache) {
      currentCachedVideo.value = videoItem;
      await setVideoSource(source: cachedFile.path, isFile: true);
    } else if (stream != null && stream.url != null) {
      if (wasPlaying) await onPauseRaw();
      try {
        await setVideoSource(
          source: stream.url!,
          cacheKey: stream.cacheKey(videoId),
        );
      } catch (e) {
        // ==== if the url got outdated.
        _isFetchingInfo.value = true;
        final newStreams = await YoutubeController.inst.getAvailableVideoStreamsOnly(videoId);
        _isFetchingInfo.value = false;
        final sameStream = newStreams.firstWhereEff((e) => e.resolution == stream.resolution && e.formatSuffix == stream.formatSuffix);
        final sameStreamUrl = sameStream?.url;

        if (currentItem is YoutubeID && videoId != (currentItem as YoutubeID).id) return;

        YoutubeController.inst.currentYTQualities.value = newStreams;

        if (sameStreamUrl != null) {
          await setVideoSource(
            source: sameStreamUrl,
            cacheKey: stream.cacheKey(videoId),
          );
        }
      }
      if (wasPlaying) await onPlayRaw();
    }
  }

  Future<void> onItemPlayYoutubeIDSetAudio({
    required AudioOnlyStream? stream,
    required File? cachedFile,
    required bool useCache,
    required String videoId,
  }) async {
    final position = currentPositionMS;
    final wasPlaying = isPlaying;

    currentAudioStream.value = stream;

    final cachedAudio = stream?.getCachedFile(videoId);
    if (cachedAudio != null && useCache) {
      await setSource(
        AudioSource.file(cachedAudio.path, tag: mediaItem),
        item: currentItem,
        startPlaying: () => wasPlaying,
        keepOldVideoSource: true,
        cachedAudioPath: cachedAudio.path,
      );
      refreshNotification();
    } else if (stream != null && stream.url != null) {
      if (wasPlaying) await super.onPauseRaw();

      Future<void> setAudioLockCache() async {
        await setSource(
          LockCachingAudioSource(
            Uri.parse(stream.url!),
            cacheFile: File(stream.cachePath(videoId)),
            tag: mediaItem,
            onCacheDone: (cacheFile) async {
              await _onAudioCacheDone(videoId, cacheFile);
            },
          ),
          item: currentItem,
          startPlaying: () => wasPlaying,
          keepOldVideoSource: true,
        );
        refreshNotification();
      }

      try {
        await setAudioLockCache();
      } catch (e) {
        // ==== if the url got outdated.
        _isFetchingInfo.value = true;
        final newStreams = await YoutubeController.inst.getAvailableAudioOnlyStreams(videoId);
        _isFetchingInfo.value = false;
        final sameStream = newStreams.firstWhereEff((e) => e.bitrate == stream.bitrate && e.formatSuffix == stream.formatSuffix);
        final sameStreamUrl = sameStream?.url;

        if (currentItem is YoutubeID && videoId != (currentItem as YoutubeID).id) return;

        YoutubeController.inst.currentYTAudioStreams.value = newStreams;

        if (sameStreamUrl != null) {
          await setAudioLockCache();
        }
      }
      await seek(position.milliseconds);
      if (wasPlaying) {
        await onPlayRaw();
      }
    }
  }

  File? _nextSeekSetAudioCache;

  Future<void> tryGenerateWaveform(YoutubeID? video) async {
    if (video != null && WaveformController.inst.isDummy && !settings.youtubeStyleMiniplayer.value) {
      final audioPath = currentCachedAudio.value?.file.path ?? _nextSeekSetAudioCache?.path;
      final dur = currentItemDuration;
      if (audioPath != null && dur != null) {
        return WaveformController.inst.generateWaveform(
          path: audioPath,
          duration: dur,
          stillPlaying: (path) =>
              currentItem is YoutubeID && currentItem == video && (_nextSeekSetAudioCache != null && path == _nextSeekSetAudioCache?.path) ||
              (currentCachedAudio.value != null && path == currentCachedAudio.value?.file.path),
        );
      }
    }
  }

  /// Adds Cached File to [audioCacheMap] & writes metadata.
  Future<void> _onAudioCacheDone(String videoId, File? audioCacheFile) async {
    _nextSeekSetAudioCache = audioCacheFile;
    // -- Audio handling
    final prevAudioStream = currentAudioStream.value;
    final prevAudioBitrate = prevAudioStream?.bitrate ?? currentCachedAudio.value?.bitrate;
    final prevAudioLangCode = prevAudioStream?.language ?? currentCachedAudio.value?.langaugeCode;
    final prevAudioLangName = prevAudioStream?.displayLanguage ?? currentCachedAudio.value?.langaugeName;
    final videoInfo = currentVideoInfo.value;
    if (videoInfo?.id == videoId) {
      if (audioCacheFile != null) {
        // -- generating waveform if needed
        if (WaveformController.inst.isDummy && !settings.youtubeStyleMiniplayer.value) {
          final dur = currentItemDuration;
          if (dur != null) {
            WaveformController.inst.generateWaveform(
              path: audioCacheFile.path,
              duration: dur,
              stillPlaying: (path) => currentItem is YoutubeID && _nextSeekSetAudioCache != null && path == _nextSeekSetAudioCache?.path,
            );
          }
        }

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
        final meta = YTUtils.getMetadataInitialMap(videoId, currentVideoInfo.value);
        await YTUtils.writeAudioMetadata(
          videoId: videoId,
          audioFile: audioCacheFile,
          thumbnailFile: null,
          tagsMap: meta,
        );
      }
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
    canPlayAudioOnlyFromCache ??= (isAudioOnlyPlayback || !ConnectivityController.inst.hasConnection);

    WaveformController.inst.resetWaveform();

    YoutubeController.inst.currentYTQualities.clear();
    YoutubeController.inst.currentYTAudioStreams.clear();
    YoutubeController.inst.currentCachedQualities.clear();
    YoutubeController.inst.updateVideoDetails(item.id);

    currentVideoInfo.value = YoutubeController.inst.getVideoInfo(item.id);
    currentChannelInfo.value = YoutubeController.inst.fetchChannelDetailsFromCacheSync(currentVideoInfo.value?.uploaderUrl, checkFromStorage: true);
    currentVideoStream.value = null;
    currentAudioStream.value = null;
    currentVideoThumbnail.value = null;
    currentCachedVideo.value = null;
    currentCachedAudio.value = null;
    _isCurrentAudioFromCache = false;
    _isFetchingInfo.value = false;
    _nextSeekSetAudioCache = null;

    if (item.id == '' || item.id == 'null') {
      if (currentQueue.length > 1) skipItem();
      return;
    }

    refreshNotification(pi, currentVideoInfo.value);

    Future<void> plsplsplsPlay(bool wasPlayingFromCache, bool sourceChanged) async {
      if (startPlaying()) {
        setVolume(_userPlayerVolume);
        await onPlayRaw();
      }
      if (sourceChanged) {
        await seek(currentPositionMS.milliseconds);
      }
      if (!wasPlayingFromCache) {
        startSleepAfterMinCount();
        startCounterToAListen(pi);
        increaseListenTime(LibraryCategory.youtube);
      }
    }

    final playerStoppingSeikoo = Completer<bool>(); // to prevent accidental stopping if getAvailableStreams was faster than fade effect
    if (enableCrossFade) {
      playerStoppingSeikoo.complete(true);
    } else {
      if (isPlaying) {
        // wait for pausing only if playing.
        pauseAndDispose(fadeMS: 100, stillSameItem: () => item == currentVideo).then((_) {
          playerStoppingSeikoo.complete(true);
        });
      } else {
        if (item == currentVideo) await super.onDispose();
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
            stillPlaying: (path) => currentItem is YoutubeID && path == currentCachedAudio.value?.file.path,
          );
        }
      }
    }

    /// try playing cache always for faster playback initialization, if the quality should be
    /// different then it will be set later after fetching.
    playedFromCacheDetails = await _trySetYTVideoWithoutConnection(
      item: item,
      index: index,
      canPlayAudioOnly: canPlayAudioOnlyFromCache,
      disableVideo: isAudioOnlyPlayback,
      whatToAwait: () async => await playerStoppingSeikoo.future,
      startPlaying: startPlaying,
      possibleAudioFiles: audioCacheMap[item.id] ?? [],
      possibleLocalFiles: Indexer.inst.allTracksMappedByYTID[item.id] ?? [],
    );

    Duration? duration = playedFromCacheDetails.duration;

    // race avoidance when playing multiple videos
    bool checkInterrupted() {
      if (item != currentVideo) {
        return true;
      } else {
        if (duration != null) _currentItemDuration.value = duration;
        return false;
      }
    }

    if (checkInterrupted()) return;

    if (!ConnectivityController.inst.hasConnection && playedFromCacheDetails.audio == null) {
      // -- if no connection and couldnt play from cache, we skip
      if (currentQueue.length > 1) skipItem();
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

    if (ConnectivityController.inst.hasConnection) {
      try {
        VideoInfo? info;
        var videoStreams = <VideoOnlyStream>[];
        var audiostreams = <AudioOnlyStream>[];
        _isFetchingInfo.value = true;
        try {
          info = await YoutubeController.inst.fetchVideoDetails(item.id);
          audiostreams = await YoutubeController.inst.getAvailableAudioOnlyStreams(item.id);
          if (isAudioOnlyPlayback) {
            // -- await video streams only if not audio playback
            YoutubeController.inst.getAvailableVideoStreamsOnly(item.id).then((value) => videoStreams = value);
          } else {
            videoStreams = await YoutubeController.inst.getAvailableVideoStreamsOnly(item.id);
          }
        } catch (e) {
          snackyy(message: 'Error getting streams', top: false, isError: true);
        }
        _isFetchingInfo.value = false;
        if (info == null && audiostreams.isEmpty && videoStreams.isEmpty) return;
        if (checkInterrupted()) return;
        YoutubeController.inst.currentYTQualities.value = videoStreams;
        YoutubeController.inst.currentYTAudioStreams.value = audiostreams;
        currentVideoInfo.value = info;
        if (checkInterrupted()) return;
        final prefferedVideoStream = isAudioOnlyPlayback || videoStreams.isEmpty ? null : YoutubeController.inst.getPreferredStreamQuality(videoStreams, preferIncludeWebm: false);
        final prefferedAudioStream = audiostreams.firstWhereEff((e) => e.formatSuffix != 'webm' && e.language == 'en') ??
            audiostreams.firstWhereEff((e) => e.formatSuffix != 'webm') ??
            audiostreams.firstOrNull;
        if (prefferedAudioStream?.url != null || prefferedVideoStream?.url != null) {
          final cachedVideoSet = playedFromCacheDetails.video;
          bool isStreamRequiredBetterThanCachedSet = cachedVideoSet == null
              ? true
              : _allowSwitchingVideoStreamIfCachedPlaying
                  ? (prefferedVideoStream?.width ?? 0) > (cachedVideoSet.width)
                  : false;

          currentVideoStream.value = isAudioOnlyPlayback
              ? null
              : isStreamRequiredBetterThanCachedSet
                  ? prefferedVideoStream
                  : videoStreams.firstWhereEff((e) => e.width == (playedFromCacheDetails.video?.resolution));

          currentAudioStream.value = prefferedAudioStream;
          _isCurrentAudioFromCache = playedFromCacheDetails.audio != null;
          currentVideoThumbnail.value = item.getThumbnailSync();

          refreshNotification(pi, currentVideoInfo.value);

          // final cachedVideo = prefferedVideoStream?.getCachedFile(item.id);
          // final cachedAudio = prefferedAudioStream?.getCachedFile(item.id);
          final mediaItem = item.toMediaItem(currentVideoInfo.value, currentVideoThumbnail.value, index, currentQueue.length);

          if (checkInterrupted()) return;
          // -- since we disabled auto switching video streams once played from cache, [isVideoCacheSameAsPrevSet] is dropped.
          // -- with the new possibility of playing local tracks as audio source, [isAudioCacheSameAsPrevSet] also is dropped.
          final shouldResetVideoSource = isAudioOnlyPlayback ? false : playedFromCacheDetails.video == null;
          final shouldResetAudioSource = playedFromCacheDetails.audio == null;

          // -- updating wether the source has changed, so that play should be triggered again.
          if (heyIhandledAudioPlaying) {
            heyIhandledAudioPlaying = !((shouldResetVideoSource && isStreamRequiredBetterThanCachedSet) || shouldResetAudioSource);
          }

          VideoOptions? videoOptions;
          if (shouldResetVideoSource && isStreamRequiredBetterThanCachedSet) {
            videoOptions = VideoOptions(
              source: prefferedVideoStream?.url ?? '',
              enableCaching: true,
              cacheKey: prefferedVideoStream?.cacheKey(item.id) ?? '',
              cacheDirectory: _defaultCacheDirectory,
              maxTotalCacheSize: _defaultMaxCache,
            );
          }
          await playerStoppingSeikoo.future;
          if (checkInterrupted()) return;

          if (shouldResetAudioSource) {
            duration = await setSource(
              LockCachingAudioSource(
                Uri.parse(prefferedAudioStream!.url!),
                cacheFile: File(prefferedAudioStream.cachePath(item.id)),
                tag: mediaItem,
                onCacheDone: (cacheFile) async {
                  await _onAudioCacheDone(item.id, cacheFile);
                },
              ),
              item: pi,
              startPlaying: startPlaying,
              videoOptions: videoOptions,
              isVideoFile: false,
            );
          } else if (videoOptions != null) {
            _latestVideoOptions = videoOptions;
            await setVideo(videoOptions);
          }

          refreshNotification();
        }
      } catch (e) {
        if (checkInterrupted()) return;
        void showSnackError(String nextAction) {
          SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
            if (item == currentItem) {
              snackyy(message: 'Error playing video, $nextAction: $e', top: false, isError: true);
            }
          });
        }

        showSnackError('trying again');

        printy(e, isError: true);
        playedFromCacheDetails = await _trySetYTVideoWithoutConnection(
          item: item,
          index: index,
          canPlayAudioOnly: canPlayAudioOnlyFromCache,
          disableVideo: isAudioOnlyPlayback,
          whatToAwait: () async => await playerStoppingSeikoo.future,
          startPlaying: startPlaying,
          possibleAudioFiles: audioCacheMap[item.id] ?? [],
          possibleLocalFiles: Indexer.inst.allTracksMappedByYTID[item.id] ?? [],
        );
        if (!checkInterrupted()) {
          generateWaveform();
          if (!okaySetFromCache()) {
            showSnackError('skipping');
            skipToNext();
          }
        }
      }
    }

    if (currentVideoInfo.value == null) {
      YoutubeController.inst.fetchVideoDetails(item.id).then((details) {
        if (currentItem == item) {
          currentVideoInfo.value = details;
          refreshNotification(currentItem, currentVideoInfo.value);
        }
      });
    }
    if (currentVideoThumbnail.value == null) {
      ThumbnailManager.inst.getYoutubeThumbnailAndCache(id: item.id).then((thumbFile) {
        if (currentItem == item) {
          currentVideoThumbnail.value = thumbFile;
          refreshNotification(currentItem);
        }
      });
    }

    if (!heyIhandledAudioPlaying) {
      final didplayfromcache = okaySetFromCache();
      await plsplsplsPlay(didplayfromcache, !didplayfromcache);
    }
  }

  /// Returns Audio File and Video File.
  Future<({AudioCacheDetails? audio, NamidaVideo? video, Duration? duration})> _trySetYTVideoWithoutConnection({
    required YoutubeID item,
    required int index,
    required bool canPlayAudioOnly,
    required bool disableVideo,
    required Future<void> Function() whatToAwait,
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

    YoutubeController.inst.currentCachedQualities.value = allCachedVideos;

    final cachedVideo = allCachedVideos.firstWhereEff((e) => File(e.path).existsSync());
    final mediaItem = item.toMediaItem(currentVideoInfo.value, currentVideoThumbnail.value, index, currentQueue.length);

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

    // ------ Playing ------
    if (cachedVideo != null && cachedAudio != null && !disableVideo) {
      // -- play audio & video
      await whatToAwait();
      try {
        final dur = await setSource(
          AudioSource.file(cachedAudio.file.path, tag: mediaItem),
          item: item as Q?,
          startPlaying: startPlaying,
          videoOptions: VideoOptions(
            source: cachedVideo.path,
            enableCaching: true,
            cacheKey: '',
            cacheDirectory: _defaultCacheDirectory,
            maxTotalCacheSize: _defaultMaxCache,
          ),
          isVideoFile: true,
          cachedAudioPath: cachedAudio.file.path,
        );
        final audioDetails = AudioCacheDetails(
          youtubeId: item.id,
          bitrate: cachedAudio.bitrate,
          langaugeCode: cachedAudio.langaugeCode,
          langaugeName: cachedAudio.langaugeName,
          file: cachedAudio.file,
        );
        refreshNotification();
        return (audio: audioDetails, video: cachedVideo, duration: dur);
      } catch (_) {
        // error in video is handled internally
        // while error in audio means the cached file is probably faulty.
        return (audio: null, video: cachedVideo, duration: null);
      }
    } else if (cachedAudio != null && canPlayAudioOnly) {
      // -- play audio only
      await whatToAwait();
      final dur = await setSource(
        AudioSource.file(cachedAudio.file.path, tag: mediaItem),
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
      refreshNotification();
      return (audio: audioDetails, video: null, duration: dur);
    }
    return (audio: null, video: null, duration: null);
  }

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
    final bitrateText = filenamewe.split('_').last;
    return AudioCacheDetails(
      file: file,
      bitrate: int.tryParse(bitrateText),
      langaugeCode: languageCode,
      langaugeName: languageName,
      youtubeId: id,
    );
  }

  @override
  FutureOr<void> onNotificationFavouriteButtonPressed(Q item) async {
    await item._execute(
      selectable: (finalItem) async {
        final newStat = await PlaylistController.inst.favouriteButtonOnPressed(Player.inst.nowPlayingTrack);
        _notificationUpdateItem(
          item: item,
          itemIndex: currentIndex,
          isItemFavourite: newStat,
        );
      },
      youtubeID: (finalItem) {},
    );
  }

  @override
  FutureOr<void> onPlayingStateChange(bool isPlaying) {
    CurrentColor.inst.switchColorPalettes(isPlaying);
    WakelockController.inst.updatePlayPauseStatus(isPlaying);
    if (isPlaying) {
      _resourcesDisposeTimer?.cancel();
      _resourcesDisposeTimer = null;
    } else {
      _resourcesDisposeTimer ??= Timer(const Duration(minutes: 5), () {
        if (!this.isPlaying) stop();
      });
    }
  }

  @override
  FutureOr<void> onRepeatForNtimesFinish() {
    settings.player.save(repeatMode: RepeatMode.none);
  }

  @override
  FutureOr<void> onTotalListenTimeIncrease(Map<String, int> totalTimeInSeconds, String key) async {
    final newSeconds = totalTimeInSeconds[key] ?? 0;

    // saves the file each 20 seconds.
    if (newSeconds % 20 == 0) {
      _updateTrackLastPosition(currentTrack.track, currentPositionMS);
      await File(AppPaths.TOTAL_LISTEN_TIME).writeAsJson(totalTimeInSeconds);
    }
  }

  @override
  FutureOr<void> onItemLastPositionReport(Q? currentItem, int currentPositionMs) async {
    await currentItem?._execute(
      selectable: (finalItem) async {
        await _updateTrackLastPosition(finalItem.track, currentPositionMS);
      },
      youtubeID: (finalItem) async {},
    );
  }

  @override
  void onPlaybackEventStream(PlaybackEvent event) {
    final item = currentItem;
    item?._execute(
      selectable: (finalItem) async {
        final isFav = finalItem.track.isFavourite;
        playbackState.add(transformEvent(event, isFav, currentIndex));
      },
      youtubeID: (finalItem) async {
        playbackState.add(transformEvent(event, false, currentIndex));
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
        skipSilence: settings.player.skipSilenceEnabled.value && currentVideo == null,
        speed: settings.player.speed.value,
        volume: _userPlayerVolume,
        pitch: settings.player.pitch.value,
      );

  double get _userPlayerVolume => settings.player.volume.value;

  @override
  bool get enableCrossFade => settings.player.enableCrossFade.value && currentQueueYoutubeID.isEmpty;

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
    if (isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    Future<void> plsSeek() async => await super.seek(position);

    await currentItem?._execute(
      selectable: (finalItem) async {
        await plsSeek();
      },
      youtubeID: (finalItem) async {
        final wasPlaying = isPlaying;
        final cachedAudioFile = _nextSeekSetAudioCache;
        if (cachedAudioFile != null) {
          await onPauseRaw();
          // -- try putting cache version if it was cached
          _nextSeekSetAudioCache = null;
          if (await cachedAudioFile.exists()) {
            await setSource(
              AudioSource.file(cachedAudioFile.path, tag: mediaItem),
              item: currentItem,
              keepOldVideoSource: true,
              cachedAudioPath: cachedAudioFile.path,
              startPlaying: () => wasPlaying,
            );
          }
          _isCurrentAudioFromCache = true;
          await plsSeek();
          if (wasPlaying) await onPlayRaw();
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
        final sFromP = (currentItemDuration?.inSeconds ?? 0) * (settings.player.seekDurationInPercentage.value / 100);
        secondsToReplay = sFromP.toInt();
      } else {
        secondsToReplay = settings.player.seekDurationInSeconds.value;
      }

      if (secondsToReplay > 0 && currentPositionMS > secondsToReplay * 1000) {
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
    AudioSource source, {
    required Q? item,
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
    required bool Function() startPlaying,
    VideoOptions? videoOptions,
    bool keepOldVideoSource = false,
    bool isVideoFile = false,
    String? cachedAudioPath,
  }) async {
    if (isVideoFile && videoOptions != null) {
      File(videoOptions.source).setLastAccessedTry(DateTime.now());
    }
    if (cachedAudioPath != null) {
      File(cachedAudioPath).setLastAccessedTry(DateTime.now());
    }
    if (!(videoOptions == null && keepOldVideoSource)) _latestVideoOptions = videoOptions;
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

  ByteSize get _defaultMaxCache => ByteSize(mb: settings.videosMaxCacheInMB.value);
  Directory get _defaultCacheDirectory => Directory(AppDirs.VIDEOS_CACHE);

  Future<void> setVideoSource({required String source, String cacheKey = '', bool loopingAnimation = false, bool isFile = false}) async {
    if (isFile) File(source).setLastAccessedTry(DateTime.now());
    final videoOptions = VideoOptions(
      source: source,
      loopingAnimation: loopingAnimation,
      enableCaching: true,
      cacheKey: cacheKey,
      cacheDirectory: _defaultCacheDirectory,
      maxTotalCacheSize: _defaultMaxCache,
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
  UriAudioSource toAudioSource(int currentIndex, int queueLength) {
    return AudioSource.uri(
      Uri.file(track.path),
      tag: toMediaItem(currentIndex, queueLength),
    );
  }

  MediaItem toMediaItem(int currentIndex, int queueLength) {
    final tr = track.toTrackExt();
    final artist = tr.originalArtist == '' ? UnknownTags.ARTIST : tr.originalArtist;
    return MediaItem(
      id: tr.path,
      title: tr.title,
      displayTitle: tr.title,
      displaySubtitle: tr.hasUnknownAlbum ? artist : "$artist - ${tr.album}",
      displayDescription: "${currentIndex + 1}/$queueLength",
      artist: artist,
      album: tr.hasUnknownAlbum ? '' : tr.album,
      genre: tr.originalGenre,
      duration: Duration(seconds: tr.duration),
      artUri: Uri.file(File(tr.pathToImage).existsSync() ? tr.pathToImage : AppPaths.NAMIDA_LOGO),
    );
  }
}

extension YoutubeIDToMediaItem on YoutubeID {
  MediaItem toMediaItem(VideoInfo? videoInfo, File? thumbnail, int currentIndex, int queueLength) {
    final vi = videoInfo;
    final artistAndTitle = vi?.name?.splitArtistAndTitle();
    final videoName = vi?.name;
    final channelName = vi?.uploaderName;

    final title = artistAndTitle?.$2?.keepFeatKeywordsOnly() ?? videoName ?? '';
    String? artistName = artistAndTitle?.$1;
    if ((artistName == null || artistName == '') && channelName != null) {
      const topic = '- Topic';
      final startIndex = (channelName.length - topic.length).withMinimum(0);
      artistName = channelName.replaceFirst(topic, '', startIndex).trimAll();
    }
    return MediaItem(
      id: vi?.id ?? '',
      title: title,
      artist: artistName,
      album: '',
      genre: '',
      displayTitle: videoName,
      displaySubtitle: channelName,
      displayDescription: "${currentIndex + 1}/$queueLength",
      duration: vi?.duration ?? Duration.zero,
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
      return await selectable(item);
    } else if (item is YoutubeID) {
      return await youtubeID(item);
    }
    return null;
  }
}

extension _PlayableExecuterList on Iterable<Playable> {
  FutureOr<T?> _execute<T>({
    required FutureOr<T> Function(Iterable<Selectable> finalItems) selectable,
    required FutureOr<T> Function(Iterable<YoutubeID> finalItem) youtubeID,
  }) async {
    final item = firstOrNull;
    if (item is Selectable) {
      return await selectable(cast<Selectable>());
    } else if (item is YoutubeID) {
      return await youtubeID(cast<YoutubeID>());
    }
    return null;
  }
}
