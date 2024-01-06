import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:basic_audio_handler/basic_audio_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_utils/src/extensions/num_extensions.dart';
import 'package:just_audio/just_audio.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:playlist_manager/module/playlist_id.dart';

import 'package:namida/class/audio_cache_detail.dart';
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
  AudioLoadConfiguration? get defaultAndroidLoadConfig {
    return AudioLoadConfiguration(
      androidLoadControl: AndroidLoadControl(
        minBufferDuration: const Duration(minutes: 2),
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

  bool get isFetchingInfo => _isFetchingInfo.value;
  final _isFetchingInfo = false.obs;

  bool get isAudioOnlyPlayback => settings.ytIsAudioOnlyMode.value;

  bool get isCurrentAudioFromCache => _isCurrentAudioFromCache;
  bool _isCurrentAudioFromCache = false;

  /// Milliseconds should be awaited before playing video.
  int get _videoPositionSeekDelayMS => 500;

  // Completer<void>? _audioShouldBeLoading;

  Future<void> setAudioOnlyPlayback(bool audioOnly) async {
    settings.save(ytIsAudioOnlyMode: audioOnly);
    if (audioOnly) {
      currentVideoStream.value = null;
      currentAudioStream.value = null;
      currentCachedVideo.value = null;
      await VideoController.vcontroller.dispose();
    }
  }

  Future<void> _waitForAllBuffers() async {
    await waitTillAudioLoaded;
    // await _audioShouldBeLoading?.future;
    await VideoController.vcontroller.waitTillBufferingComplete;
    await bufferingCompleter?.future;
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

  Future<void> tryRestoringLastPosition(Track trackPre) async {
    final minValueInSet = settings.minTrackDurationToRestoreLastPosInMinutes.value * 60;

    if (minValueInSet >= 0) {
      final seekValueInMS = settings.seekDurationInSeconds.value * 1000;
      final track = trackPre.toTrackExt();
      final lastPos = track.stats.lastPositionInMs;
      // -- only seek if not at the start of track.
      if (lastPos >= seekValueInMS && track.duration >= minValueInSet) {
        await seek(lastPos.milliseconds);
      }
    }
  }

  //
  // =================================================================================
  // ================================ Video Methods ==================================
  // =================================================================================

  Future<void> toggleVideoPlay() async {
    await _waitForAllBuffers();
    // await _audioShouldBeLoading?.future;
    await VideoController.vcontroller.seek(currentPositionMS.milliseconds);
    if (isPlaying) {
      await VideoController.vcontroller.play();
    } else {
      await VideoController.vcontroller.pause();
    }
  }

  Future<void> refreshVideoPosition(bool delayed) async {
    if (delayed) await Future.delayed(Duration(milliseconds: _videoPositionSeekDelayMS.abs()));
    await VideoController.vcontroller.seek(Duration(milliseconds: currentPositionMS));
  }

  Future<void> _playAudioThenVideo() async {
    onPlayRaw();
    // await _audioShouldBeLoading?.future;
    await Future.delayed(Duration(milliseconds: _videoPositionSeekDelayMS.abs()));
    if (isPlaying) await VideoController.vcontroller.play();
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

  Color? latestExtractedColor;

  @override
  void onIndexChanged(int newIndex, Q newItem) async {
    settings.save(lastPlayedTrackIndex: newIndex);
    refreshNotification(newItem);
    await newItem._execute(
      selectable: (finalItem) async {
        await CurrentColor.inst.updatePlayerColorFromTrack(finalItem, newIndex);
      },
      youtubeID: (finalItem) async {
        final image = await ThumbnailManager.inst.getYoutubeThumbnailAndCache(id: finalItem.id);
        if (image != null && finalItem == currentItem) {
          // -- only extract if same item is still playing, i.e. user didn't skip.
          final color = await CurrentColor.inst.extractPaletteFromImage(image.path, paletteSaveDirectory: Directory(AppDirs.YT_PALETTES), useIsolate: true);
          if (color != null && finalItem == currentItem) {
            // -- only update if same item is still playing, i.e. user didn't skip.
            CurrentColor.inst.updatePlayerColorFromColor(color.color);
            latestExtractedColor = color.color;
          }
        }
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
        VideoController.vcontroller.dispose(),
        QueueController.inst.emptyLatestQueue(),
      ].execute();
    } else {
      refreshNotification(currentItem);
      await currentQueue._execute(
        selectable: (finalItems) async {
          await QueueController.inst.updateLatestQueue(finalItems.tracks.toList());
        },
        youtubeID: (finalItems) {},
      );
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

    await currentQueue._execute(
      selectable: (finalItems) {
        QueueController.inst.updateLatestQueue(finalItems.tracks.toList());
      },
      youtubeID: (finalItems) {},
    );
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
          VideoController.inst.currentYTQualities.clear();
          VideoController.inst.currentPossibleVideos.clear();
          await clearQueue();
        }
      },
      youtubeID: (finalItem) async {
        if (currentQueue.firstOrNull is! YoutubeID) {
          YoutubeController.inst.currentYTQualities.clear();
          YoutubeController.inst.currentYTAudioStreams.clear();
          YoutubeController.inst.currentCachedQualities.clear();
          YoutubeController.inst.currentComments.clear();
          YoutubeController.inst.currentRelatedVideos.clear();
          await clearQueue();
        }
      },
    );
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
  Future<void> setPlayerSpeed(double value, AudioPlayer? ap) async {
    await Future.wait([
      VideoController.vcontroller.setSpeed(value),
      super.setPlayerSpeed(value, ap),
    ]);
  }

  @override
  Future<void> setPlayerVolume(double value, AudioPlayer? ap) async {
    await Future.wait([
      VideoController.vcontroller.setVolume(value),
      super.setPlayerVolume(value, ap),
    ]);
  }

  @override
  Future<void> setPlayerPitch(double value, AudioPlayer? ap) async {
    await super.setPlayerPitch(value, ap);
  }

  @override
  InterruptionAction defaultOnInterruption(InterruptionType type) => settings.playerOnInterrupted[type] ?? InterruptionAction.pause;

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

  @override
  Future<void> onItemPlay(Q item, int index, bool startPlaying) async {
    await item._execute(
      selectable: (finalItem) async {
        await onItemPlaySelectable(item, finalItem, index, startPlaying);
      },
      youtubeID: (finalItem) async {
        await onItemPlayYoutubeID(item, finalItem, index, startPlaying);
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

  Future<void> onItemPlaySelectable(Q pi, Selectable item, int index, bool startPlaying) async {
    final tr = item.track;
    VideoController.inst.updateCurrentVideo(tr);
    WaveformController.inst.generateWaveform(tr);

    // -- generating artwork in case it wasnt, to be displayed in notification
    Indexer.inst.getArtwork(imagePath: tr.pathToImage, compressed: false).then((value) => refreshNotification());

    Future<Duration?> setPls() async {
      final dur = await setAudioSource(
        tr.toAudioSource(currentIndex, currentQueue.length),
        startPlaying: startPlaying,
      );
      Indexer.inst.updateTrackDuration(tr, dur);

      refreshNotification(currentItem);
      return dur;
    }

    Duration? duration;

    try {
      duration = await setPls();
    } catch (e) {
      if (duration != null && currentPositionMS > 0) return;
      if (item.track == currentTrack.track) {
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
                skipToNext();
                timer.cancel();
              }
            },
          );
          NamidaDialogs.inst.showTrackDialog(
            tr,
            isFromPlayerQueue: true,
            errorPlayingTrack: true,
            source: QueueSource.playerQueue,
          );
        } else {
          final hasPermission = await requestManageStoragePermission();
          if (hasPermission) await setPls();
        }
      }

      printy(e, isError: true);
      return;
    }

    // -- The whole idea of pausing and playing is due to the bug where [headset buttons/android next gesture]
    // -- sometimes don't get detected.
    await Future.wait([
      // onPauseRaw(),
      tryRestoringLastPosition(tr),
    ]);

    if (startPlaying) {
      setVolume(_userPlayerVolume);
      await _waitForAllBuffers();
      await _playAudioThenVideo();
    }

    startSleepAfterMinCount();
    startCounterToAListen(pi);
    increaseListenTime(ListenTimeKeys.localTracks);
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

    if (cachedFile != null && useCache) {
      currentCachedVideo.value = videoItem;
      await VideoController.vcontroller.setFile(cachedFile.path, (videoDuration) => false);
      await refreshVideoPosition(true);
      if (wasPlaying) VideoController.vcontroller.play();
    } else if (stream != null && stream.url != null) {
      final position = currentPositionMS;
      if (wasPlaying) await onPauseRaw();
      try {
        await VideoController.vcontroller.setNetworkSource(
          url: stream.url!,
          looping: (videoDuration) => false,
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
          await VideoController.vcontroller.setNetworkSource(
            url: sameStreamUrl,
            looping: (videoDuration) => false,
            cacheKey: stream.cacheKey(videoId),
          );
        }
      }
      await VideoController.vcontroller.seek(position.milliseconds);
      await _waitForAllBuffers();
      if (wasPlaying) await _playAudioThenVideo();
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
      await setAudioSource(AudioSource.file(cachedAudio.path, tag: mediaItem), startPlaying: wasPlaying);
      refreshNotification();
    } else if (stream != null && stream.url != null) {
      if (wasPlaying) {
        await Future.wait([
          super.onPauseRaw(),
          VideoController.vcontroller.pause(),
        ]);
      }

      Future<void> setAudioLockCache() async {
        await setAudioSource(
          LockCachingAudioSource(
            Uri.parse(stream.url!),
            cacheFile: File(stream.cachePath(videoId)),
            tag: mediaItem,
            onCacheDone: (cacheFile) async {
              await _onAudioCacheDone(videoId, cacheFile);
            },
          ),
          startPlaying: wasPlaying,
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
      await _waitForAllBuffers();
      await seek(position.milliseconds);
      if (wasPlaying) {
        await _playAudioThenVideo();
      }
    }
  }

  bool _nextSeekCanSetAudioCache = false;

  /// Adds Cached File to [audioCacheMap] & writes metadata.
  Future<void> _onAudioCacheDone(String videoId, File? audioCacheFile) async {
    _nextSeekCanSetAudioCache = true;
    // -- Audio handling
    final prevAudioStream = currentAudioStream.value;
    final prevAudioBitrate = prevAudioStream?.bitrate ?? currentCachedAudio.value?.bitrate;
    final prevAudioLangCode = prevAudioStream?.language ?? currentCachedAudio.value?.langaugeCode;
    final prevAudioLangName = prevAudioStream?.displayLanguage ?? currentCachedAudio.value?.langaugeName;
    final videoInfo = currentVideoInfo.value;
    if (videoInfo?.id == videoId) {
      if (audioCacheFile != null) {
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
    bool startPlaying, {
    bool? canPlayAudioOnlyFromCache,
  }) async {
    canPlayAudioOnlyFromCache ??= isAudioOnlyPlayback;

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
    _nextSeekCanSetAudioCache = false;

    refreshNotification(pi, currentVideoInfo.value);

    Future<void> plsplsplsPlay(bool waitForBuffer, bool wasPlayingFromCache, bool sourceChanged) async {
      if (startPlaying) {
        setVolume(_userPlayerVolume);
        if (waitForBuffer) await _waitForAllBuffers();
        await _playAudioThenVideo();
        settings.wakelockMode.value.toggleOn(currentVideoStream.value != null || currentCachedVideo.value != null);
      }
      if (sourceChanged) {
        await seek(currentPositionMS.milliseconds);
      }
      if (!wasPlayingFromCache) {
        startSleepAfterMinCount();
        startCounterToAListen(pi);
        increaseListenTime(ListenTimeKeys.youtube);
      }
    }

    final playerStoppingSeikoo = Completer<bool>(); // to prevent accidental stopping if getAvailableStreams was faster than fade effect
    if (enableCrossFade) {
      playerStoppingSeikoo.complete(true);
    } else {
      if (isPlaying) {
        // wait for pausing only if playing.
        pause().then((_) async {
          await super.onDispose();
          playerStoppingSeikoo.complete(true);
        });
      } else {
        await super.onDispose();
        playerStoppingSeikoo.complete(true);
      }
    }

    await VideoController.vcontroller.dispose();

    ({AudioCacheDetails? audio, NamidaVideo? video}) playedFromCacheDetails = (audio: null, video: null);
    bool okaySetFromCache() => playedFromCacheDetails.audio != null && (canPlayAudioOnlyFromCache! || playedFromCacheDetails.video != null);

    /// try playing cache always for faster playback initialization, if the quality should be
    /// different then it will be set later after fetching.
    playedFromCacheDetails = await _trySetYTVideoWithoutConnection(
      item: item,
      index: index,
      canPlayAudioOnly: canPlayAudioOnlyFromCache,
      disableVideo: isAudioOnlyPlayback,
      whatToAwait: () async => await playerStoppingSeikoo.future,
      startPlaying: startPlaying,
    );

    currentCachedAudio.value = playedFromCacheDetails.audio;
    currentCachedVideo.value = playedFromCacheDetails.video;

    bool heyIhandledAudioPlaying = false;
    if (okaySetFromCache()) {
      heyIhandledAudioPlaying = true;
      await plsplsplsPlay(false, false, false);
    } else {
      heyIhandledAudioPlaying = false;
    }

    if (ConnectivityController.inst.hasConnection) {
      try {
        YoutubeVideo? streams;
        _isFetchingInfo.value = true;
        try {
          streams = await YoutubeController.inst.getAvailableStreams(item.id);
        } catch (e) {
          snackyy(message: 'Error getting streams', top: false, isError: true);
        }
        _isFetchingInfo.value = false;
        if (streams == null) return;
        if (item != currentVideo) return; // race avoidance when playing multiple videos
        YoutubeController.inst.currentYTQualities.value = streams.videoOnlyStreams ?? [];
        YoutubeController.inst.currentYTAudioStreams.value = streams.audioOnlyStreams ?? [];
        currentVideoInfo.value = streams.videoInfo;
        final vos = streams.videoOnlyStreams;
        final allVideoStream = isAudioOnlyPlayback || vos == null || vos.isEmpty ? null : YoutubeController.inst.getPreferredStreamQuality(vos, preferIncludeWebm: false);
        final prefferedVideoStream = allVideoStream;
        final prefferedAudioStream = streams.audioOnlyStreams?.firstWhereEff((e) => e.formatSuffix != 'webm' && e.language == 'en') ??
            streams.audioOnlyStreams?.firstWhereEff((e) => e.formatSuffix != 'webm') ??
            streams.audioOnlyStreams?.firstOrNull;
        if (prefferedAudioStream?.url != null || prefferedVideoStream?.url != null) {
          final isStreamRequiredBetterThanCachedSet = playedFromCacheDetails.video == null
              ? true
              : playedFromCacheDetails.video != null && (prefferedVideoStream?.width ?? 0) > (playedFromCacheDetails.video?.resolution ?? 0);

          currentVideoStream.value = isAudioOnlyPlayback
              ? null
              : isStreamRequiredBetterThanCachedSet
                  ? prefferedVideoStream
                  : vos?.firstWhereEff((e) => e.width == (playedFromCacheDetails.video?.resolution));

          currentAudioStream.value = prefferedAudioStream;
          currentVideoInfo.value = streams.videoInfo;
          currentVideoThumbnail.value = item.getThumbnailSync();

          refreshNotification(pi, currentVideoInfo.value);

          final cachedVideo = prefferedVideoStream?.getCachedFile(item.id);
          final cachedAudio = prefferedAudioStream?.getCachedFile(item.id);
          final mediaItem = item.toMediaItem(currentVideoInfo.value, currentVideoThumbnail.value, index, currentQueue.length);
          _isCurrentAudioFromCache = cachedAudio != null;
          await playerStoppingSeikoo.future;
          if (item != currentVideo) return; // race avoidance when playing multiple videos
          final isVideoCacheSameAsPrevSet = cachedVideo != null &&
              playedFromCacheDetails.video != null &&
              playedFromCacheDetails.video?.path == cachedVideo.path; // only if not the same cache path (i.e. diff resolution)
          final isAudioCacheSameAsPrevSet =
              cachedAudio != null && playedFromCacheDetails.audio != null && playedFromCacheDetails.audio?.file.path == cachedAudio.path; // only if not the same cache path
          final shouldResetVideoSource = isAudioOnlyPlayback ? false : !isAudioOnlyPlayback && !isVideoCacheSameAsPrevSet;
          final shouldResetAudioSource = !isAudioCacheSameAsPrevSet;

          // -- updating wether the source has changed, so that play should be triggered again.
          if (heyIhandledAudioPlaying) {
            heyIhandledAudioPlaying = !((shouldResetVideoSource && isStreamRequiredBetterThanCachedSet) || shouldResetAudioSource);
          }

          await playerStoppingSeikoo.future;
          await Future.wait([
            if (shouldResetVideoSource && isStreamRequiredBetterThanCachedSet)
              cachedVideo != null
                  ? VideoController.vcontroller.setFile(cachedVideo.path, (videoDuration) => false)
                  : VideoController.vcontroller.setNetworkSource(
                      url: prefferedVideoStream!.url!,
                      looping: (videoDuration) => false,
                      cacheKey: prefferedVideoStream.cacheKey(item.id),
                    ),
            if (shouldResetAudioSource)
              cachedAudio != null
                  ? setAudioSource(
                      AudioSource.file(cachedAudio.path, tag: mediaItem),
                      startPlaying: startPlaying,
                    )
                  : setAudioSource(
                      LockCachingAudioSource(
                        Uri.parse(prefferedAudioStream!.url!),
                        cacheFile: File(prefferedAudioStream.cachePath(item.id)),
                        tag: mediaItem,
                        onCacheDone: (cacheFile) async {
                          await _onAudioCacheDone(item.id, cacheFile);
                        },
                      ),
                      startPlaying: startPlaying,
                    ),
          ]);
          refreshNotification();
        }
      } catch (e) {
        if (item != currentVideo) return; // race avoidance when playing multiple videos
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
        );
        if (!okaySetFromCache()) {
          showSnackError('skipping');
          skipToNext();
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
      await plsplsplsPlay(!didplayfromcache, didplayfromcache, !didplayfromcache);
    }
  }

  /// Returns Audio File and Video File.
  Future<({AudioCacheDetails? audio, NamidaVideo? video})> _trySetYTVideoWithoutConnection({
    required YoutubeID item,
    required int index,
    required bool canPlayAudioOnly,
    required bool disableVideo,
    required Future<void> Function() whatToAwait,
    required bool startPlaying,
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

    final cachedVideo = allCachedVideos.firstOrNull;
    final mediaItem = item.toMediaItem(currentVideoInfo.value, currentVideoThumbnail.value, index, currentQueue.length);

    // ------ Getting Audio ------
    final audioFiles = await _getCachedAudiosForID.thready({
      "dirPath": AppDirs.AUDIOS_CACHE,
      "id": item.id,
    });
    final finalAudioFiles = audioFiles..sortByReverseAlt((e) => e.bitrate ?? 0, (e) => e.file.fileSizeSync() ?? 0);
    final cachedAudio = finalAudioFiles.firstOrNull;

    // ------ Playing ------
    if (cachedVideo != null && cachedAudio != null && !disableVideo) {
      // -- play audio & video
      await whatToAwait();
      await Future.wait([
        setAudioSource(
          AudioSource.file(cachedAudio.file.path, tag: mediaItem),
          startPlaying: startPlaying,
        ),
        VideoController.vcontroller.setFile(cachedVideo.path, (videoDuration) => false),
      ]);
      final audioDetails = AudioCacheDetails(
        youtubeId: item.id,
        bitrate: cachedAudio.bitrate,
        langaugeCode: cachedAudio.langaugeCode,
        langaugeName: cachedAudio.langaugeName,
        file: cachedAudio.file,
      );
      refreshNotification();
      return (audio: audioDetails, video: cachedVideo);
    } else if (cachedAudio != null && canPlayAudioOnly) {
      // -- play audio only
      await whatToAwait();
      await setAudioSource(
        AudioSource.file(cachedAudio.file.path, tag: mediaItem),
        startPlaying: startPlaying,
      );
      final audioDetails = AudioCacheDetails(
        youtubeId: item.id,
        bitrate: cachedAudio.bitrate,
        langaugeCode: cachedAudio.langaugeCode,
        langaugeName: cachedAudio.langaugeName,
        file: cachedAudio.file,
      );
      refreshNotification();
      return (audio: audioDetails, video: null);
    }
    return (audio: null, video: null);
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
  }

  @override
  FutureOr<void> onRepeatForNtimesFinish() {
    settings.save(playerRepeatMode: RepeatMode.none);
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
  Future<void> setSkipSilenceEnabled(bool enabled) async {
    if (defaultPlayerConfig.skipSilence) await super.setSkipSilenceEnabled(enabled);
  }

  @override
  PlayerConfig get defaultPlayerConfig => PlayerConfig(
        skipSilence: settings.playerSkipSilenceEnabled.value && currentVideo == null,
        speed: settings.playerSpeed.value,
        volume: _userPlayerVolume,
        pitch: settings.playerPitch.value,
      );

  double get _userPlayerVolume => settings.playerVolume.value;

  @override
  bool get enableCrossFade => settings.enableCrossFade.value && currentQueueYoutubeID.isEmpty;

  @override
  int get defaultCrossFadeMilliseconds => settings.crossFadeDurationMS.value;

  @override
  int get defaultCrossFadeTriggerStartOffsetSeconds => settings.crossFadeAutoTriggerSeconds.value;

  @override
  bool get displayFavouriteButtonInNotification => settings.displayFavouriteButtonInNotification.value;

  @override
  bool get defaultShouldStartPlaying => (settings.playerPlayOnNextPrev.value || isPlaying);

  @override
  bool get enableVolumeFadeOnPlayPause => settings.enableVolumeFadeOnPlayPause.value;

  @override
  bool get playerInfiniyQueueOnNextPrevious => settings.playerInfiniyQueueOnNextPrevious.value;

  @override
  int get playerPauseFadeDurInMilli => settings.playerPauseFadeDurInMilli.value;

  @override
  int get playerPlayFadeDurInMilli => settings.playerPlayFadeDurInMilli.value;

  @override
  bool get playerPauseOnVolume0 => settings.playerPauseOnVolume0.value;

  @override
  RepeatMode get playerRepeatMode => settings.playerRepeatMode.value;

  @override
  bool get playerResumeAfterOnVolume0Pause => settings.playerResumeAfterOnVolume0Pause.value;

  @override
  bool get jumpToFirstItemAfterFinishingQueue => settings.jumpToFirstTrackAfterFinishingQueue.value;

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
    Future<void> plsSeek() async {
      await Future.wait([
        super.seek(position),
        VideoController.vcontroller.seek(position),
      ]);
    }

    Future<void> plsPause() async {
      await Future.wait([
        super.onPauseRaw(),
        VideoController.vcontroller.pause(),
      ]);
    }

    await currentItem?._execute(
      selectable: (finalItem) async {
        // await plsPause();
        await plsSeek();
        refreshVideoPosition(false);
      },
      youtubeID: (finalItem) async {
        final wasPlaying = isPlaying;
        await plsPause();
        if (_nextSeekCanSetAudioCache) {
          // -- try putting cache version if it was cached
          _nextSeekCanSetAudioCache = false;
          final cached = currentAudioStream.value?.getCachedFile(finalItem.id);
          if (cached != null) await setAudioSource(AudioSource.file(cached.path, tag: mediaItem));
          _isCurrentAudioFromCache = true;
        }
        await plsSeek();
        await _waitForAllBuffers();
        if (wasPlaying) await _playAudioThenVideo();
      },
    );
  }

  @override
  Future<void> skipToNext([bool? andPlay]) async => await onSkipToNext(andPlay);

  @override
  Future<void> skipToPrevious() async => await onSkipToPrevious();

  @override
  Future<void> skipToQueueItem(int index, [bool? andPlay]) async => await onSkipToQueueItem(index, andPlay);

  @override
  Future<void> stop() async {
    await [
      super.stop(),
      VideoController.vcontroller.pause(),
    ].execute();
  }

  @override
  Future<void> onDispose() async {
    await [
      super.onDispose(),
      VideoController.vcontroller.dispose(),
      AudioService.forceStop(),
    ].execute();
  }

  @override
  Future<void> fastForward() async => await onFastForward();

  @override
  Future<void> rewind() async => await onRewind();

  @override
  void onBufferOrLoadStart() {
    // _audioShouldBeLoading ??= Completer<void>();
    if (isPlaying) {
      VideoController.vcontroller.pause();
    }
  }

  @override
  void onBufferOrLoadEnd() async {
    await waitTillAudioLoaded;
    // _audioShouldBeLoading?.completeIfWasnt();
    if (isPlaying) {
      VideoController.vcontroller.play();
    }
  }

  @override
  Future<void> onRealPause() async {
    await VideoController.vcontroller.pause();
  }

  @override
  Future<void> onRealPlay() async {
    await VideoController.vcontroller.pause(); // pausing for cases like: seeking to 0, which will trigger play fast
    final vcp = VideoController.vcontroller.videoController?.value.position.inMilliseconds ?? 0;
    final diff = vcp - currentPositionMS;
    if (diff > 0) await Future.delayed(Duration(milliseconds: diff));
    await VideoController.vcontroller.play();
  }
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
    return MediaItem(
      id: vi?.id ?? '',
      title: artistAndTitle?.$2?.keepFeatKeywordsOnly() ?? videoName ?? '',
      artist: artistAndTitle?.$1 ?? channelName?.replaceFirst('- Topic', '').trimAll(),
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
