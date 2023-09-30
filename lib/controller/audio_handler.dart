import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:basic_audio_handler/basic_audio_handler.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_utils/src/extensions/num_extensions.dart';
import 'package:just_audio/just_audio.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';
import 'package:playlist_manager/module/playlist_id.dart';

import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/lyrics_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/controller/waveform_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';
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
    audioCacheMap
      ..clear()
      ..addAll(map);
  }

  final audioCacheMap = <String, List<MapEntry<File, int?>>>{};

  Selectable get currentTrack => (currentItem is Selectable ? currentItem as Selectable : null) ?? kDummyTrack;
  YoutubeID? get currentVideo => currentItem is YoutubeID ? currentItem as YoutubeID : null;
  List<Selectable> get currentQueueSelectable => currentQueue.firstOrNull is Selectable ? currentQueue.cast<Selectable>() : [];
  List<YoutubeID> get currentQueueYoutubeID => currentQueue.firstOrNull is YoutubeID ? currentQueue.cast<YoutubeID>() : [];

  final currentVideoInfo = Rxn<VideoInfo>();
  final currentChannelInfo = Rxn<YoutubeChannel>();
  final currentVideoStream = Rxn<VideoOnlyStream>();
  final currentAudioStream = Rxn<AudioOnlyStream>();
  int? _currentAudioBitrate;
  final currentVideoThumbnail = Rxn<File>();
  final currentCachedVideo = Rxn<NamidaVideo>();

  bool get isFetchingInfo => _isFetchingInfo.value;
  final _isFetchingInfo = false.obs;

  bool get isAudioOnlyPlayback => _isAudioOnlyPlayback;
  bool _isAudioOnlyPlayback = false;

  bool get isCurrentAudioFromCache => _isCurrentAudioFromCache;
  bool _isCurrentAudioFromCache = false;

  /// Milliseconds should be awaited before playing video.
  int get _videoPositionSeekDelayMS => 400;

  Future<void> setAudioOnlyPlayback(bool audioOnly) async {
    _isAudioOnlyPlayback = audioOnly;
    if (_isAudioOnlyPlayback) {
      currentVideoStream.value = null;
      currentAudioStream.value = null;
      currentCachedVideo.value = null;
      _currentAudioBitrate = null;
      await VideoController.vcontroller.dispose();
    }
  }

  Future<void> _waitForAllBuffers() async {
    await Future.wait([
      if (waitTillAudioLoaded != null) waitTillAudioLoaded!,
      if (VideoController.vcontroller.waitTillBufferingComplete != null) VideoController.vcontroller.waitTillBufferingComplete!,
      if (bufferingCompleter != null) bufferingCompleter!.future,
    ]);
  }

  Future<void> prepareTotalListenTime() async {
    final file = await File(AppPaths.TOTAL_LISTEN_TIME).create();
    final text = await file.readAsString();
    final listenTime = int.tryParse(text);
    super.initializeTotalListenTime(listenTime);
  }

  Future<void> _updateTrackLastPosition(Track track, int lastPositionMS) async {
    /// Saves a starting position in case the remaining was less than 30 seconds.
    final remaining = (track.duration * 1000) - lastPositionMS;
    final positionToSave = remaining <= 30000 ? 0 : lastPositionMS;

    await Indexer.inst.updateTrackStats(track, lastPositionInMs: positionToSave);
  }

  Future<void> tryRestoringLastPosition(Track trackPre) async {
    final minValueInSet = settings.minTrackDurationToRestoreLastPosInMinutes.value * 60;

    if (minValueInSet > 0) {
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

  Future<void> refreshVideoPosition() async {
    await VideoController.vcontroller.seek(Duration(milliseconds: currentPositionMS));
  }

  Future<void> _playAudioThenVideo() async {
    onPlayRaw();
    await Future.delayed(Duration(milliseconds: _videoPositionSeekDelayMS.abs()));
    await VideoController.vcontroller.play();
  }
  // =================================================================================
  //

  //
  // =================================================================================
  // ================================ Player methods =================================
  // =================================================================================

  void refreshNotification([Q? item, VideoInfo? videoInfo]) {
    item ?? currentItem;
    item?._execute(
      selectable: (finalItem) async {
        _notificationUpdateItem(item: item, isItemFavourite: finalItem.track.isFavourite, itemIndex: currentIndex);
      },
      youtubeID: (finalItem) async {
        _notificationUpdateItem(item: item, isItemFavourite: false, itemIndex: currentIndex, videoInfo: videoInfo);
      },
    );
  }

  void _notificationUpdateItem({required Q item, required bool isItemFavourite, required int itemIndex, VideoInfo? videoInfo}) {
    item._execute(
      selectable: (finalItem) async {
        mediaItem.add(finalItem.toMediaItem(currentIndex, currentQueue.length));
        playbackState.add(transformEvent(PlaybackEvent(), isItemFavourite, itemIndex));
      },
      youtubeID: (finalItem) async {
        final info = videoInfo ?? finalItem.toVideoInfoSync() ?? YoutubeController.inst.getTemporarelyVideoInfo(finalItem.id);
        final thumbnail = finalItem.getThumbnailSync();
        mediaItem.add(finalItem.toMediaItem(info, thumbnail, currentIndex, currentQueue.length));
        playbackState.add(transformEvent(PlaybackEvent(), isItemFavourite, itemIndex));
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
    await newItem._execute(
      selectable: (finalItem) async {
        await CurrentColor.inst.updatePlayerColorFromTrack(finalItem, newIndex);
      },
      youtubeID: (finalItem) async {
        final image = await VideoController.inst.getYoutubeThumbnailAndCache(id: finalItem.id);
        if (image != null && finalItem == currentItem) {
          // -- only extract if same item is still playing, i.e. user didn't skip.
          final color = await CurrentColor.inst.extractPaletteFromImage(image.path);
          if (color != null && finalItem == currentItem) {
            // -- only update if same item is still playing, i.e. user didn't skip.
            CurrentColor.inst.updatePlayerColorFromColor(color.color);
          }
        }
      },
    );
  }

  @override
  void onQueueChanged() async {
    super.onQueueChanged();
    refreshNotification(currentItem);
    await currentQueue._execute(
      selectable: (finalItems) async {
        await QueueController.inst.updateLatestQueue(finalItems.tracks.toList());
      },
      youtubeID: (finalItems) {},
    );
  }

  @override
  void onReorderItems(int currentIndex, Q itemDragged) {
    super.onReorderItems(currentIndex, itemDragged);

    itemDragged._execute(
      selectable: (finalItem) {
        CurrentColor.inst.updatePlayerColorFromTrack(null, currentIndex, updateIndexOnly: true);
      },
      youtubeID: (finalItem) {},
    );

    currentQueue._execute(
      selectable: (finalItems) {
        QueueController.inst.updateLatestQueue(finalItems.tracks.toList());
      },
      youtubeID: (finalItems) {},
    );
  }

  @override
  FutureOr<void> beforeQueueAddOrInsert(Iterable<Q> items) async {
    await items._execute(
      selectable: (finalItems) async {
        if (currentQueue.firstOrNull is! Selectable) {
          await clearQueue();
          await onDispose();
        }
      },
      youtubeID: (finalItem) async {
        if (currentQueue.firstOrNull is! YoutubeID) {
          await clearQueue();
          await onDispose();
          CurrentColor.inst.resetCurrentPlayingTrack();
        }
      },
    );
  }

  @override
  FutureOr<void> beforePlaying() async {
    super.beforePlaying(); // saving last position.
    NamidaNavigator.inst.popAllMenus();

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
  }) async {
    await beforeQueueAddOrInsert(queue);
    await super.assignNewQueue(
      playAtIndex: playAtIndex,
      queue: queue,
      maximumItems: maximumItems,
      onIndexAndQueueSame: onIndexAndQueueSame,
      onQueueDifferent: onQueueDifferent,
      onQueueEmpty: onQueueEmpty,
      startPlaying: startPlaying,
      shuffle: shuffle,
    );
  }

  // ==============================================================================================
  //

  //
  // ==============================================================================================
  // ==============================================================================================
  // ================================== NamidaBasicAudioHandler Overriden ====================================
  @override
  Future<void> setPlayerSpeed(double value) async {
    await Future.wait([
      VideoController.vcontroller.setSpeed(value),
      super.setPlayerSpeed(value),
    ]);
  }

  @override
  Future<void> setPlayerVolume(double value) async {
    await Future.wait([
      VideoController.vcontroller.setVolume(value),
      super.setVolume(value),
    ]);
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
              final d = await ap.setFilePath(finalItem.track.path).then((value) => value);
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
        final newListen = YoutubeID(id: finalItem.id, addedDate: DateTime.now(), playlistID: const PlaylistID(id: k_PLAYLIST_NAME_HISTORY));
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
  }

  Future<void> onItemPlaySelectable(Q pi, Selectable item, int index, bool startPlaying) async {
    final tr = item.track;
    VideoController.inst.updateCurrentVideo(tr);
    WaveformController.inst.generateWaveform(tr);

    /// The whole idea of pausing and playing is due to the bug where [headset buttons/android next gesture] don't get detected.
    try {
      final dur = await setAudioSource(tr.toAudioSource(currentIndex, currentQueue.length));
      if (tr.duration == 0) tr.duration = dur?.inSeconds ?? 0;
    } catch (e) {
      SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
        if (item.track == currentTrack.track) {
          NamidaDialogs.inst.showTrackDialog(tr, isFromPlayerQueue: true, errorPlayingTrack: true, source: QueueSource.playerQueue);
        }
      });
      printy(e, isError: true);
      return;
    }
    await Future.wait([
      onPauseRaw(),
      tryRestoringLastPosition(tr),
    ]);

    if (startPlaying) {
      setVolume(settings.playerVolume.value);
      await _waitForAllBuffers();
      _playAudioThenVideo();
    }

    startSleepAfterMinCount();
    startCounterToAListen(pi);
    increaseListenTime();
    settings.save(lastPlayedTrackPath: tr.path);
    Lyrics.inst.updateLyrics(tr);
  }

  Future<void> onItemPlayYoutubeIDSetQuality({
    required VideoOnlyStream? stream,
    required File? cachedFile,
    required bool useCache,
    required String videoId,
    required NamidaVideo? videoItem,
  }) async {
    final position = currentPositionMS;
    final wasPlaying = isPlaying;
    setAudioOnlyPlayback(false);

    currentVideoStream.value = stream;

    if (cachedFile != null && useCache) {
      currentCachedVideo.value = videoItem;
      await VideoController.vcontroller.setFile(cachedFile.path, (videoDuration) => false);
      await refreshVideoPosition();
    } else if (stream != null && stream.url != null) {
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

        YoutubeController.inst.currentYTQualities
          ..clear()
          ..addAll(newStreams);

        if (sameStreamUrl != null) {
          await VideoController.vcontroller.setNetworkSource(
            url: sameStreamUrl,
            looping: (videoDuration) => false,
            cacheKey: stream.cacheKey(videoId),
          );
        }
      }
      await _waitForAllBuffers();
      await seek(position.milliseconds);
      if (wasPlaying) {
        await _playAudioThenVideo();
      }
    }
  }

  /// Adds Cached File to [audioCacheMap] & writes metadata.
  Future<void> _onAudioCacheDone(String videoId, File? audioCacheFile) async {
    // -- Audio handling
    final prevAudioStream = currentAudioStream.value;
    final prevAudioBitrate = prevAudioStream?.bitrate ?? _currentAudioBitrate;
    final videoInfo = currentVideoInfo.value;
    if (videoInfo?.id == videoId) {
      if (audioCacheFile != null) {
        // -- Adding recently cached audio to cache map, for being displayed on cards.
        audioCacheMap.addNoDuplicatesForce(videoId, MapEntry(audioCacheFile, prevAudioBitrate));

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
    YoutubeController.inst.currentCachedQualities.clear();
    YoutubeController.inst.updateVideoDetails(item.id);

    currentVideoInfo.value = item.toVideoInfoSync() ?? YoutubeController.inst.getTemporarelyVideoInfo(item.id);
    currentChannelInfo.value = YoutubeController.inst.fetchChannelDetailsFromCacheSync(currentVideoInfo.value?.uploaderUrl);
    currentVideoStream.value = null;
    currentAudioStream.value = null;
    currentVideoThumbnail.value = null;
    currentCachedVideo.value = null;
    _currentAudioBitrate = null;
    _isFetchingInfo.value = false;

    refreshNotification(pi, currentVideoInfo.value);

    Future<void> plsplsplsPlay(bool waitForBuffer, bool wasPlayingFromCache) async {
      if (startPlaying) {
        setVolume(settings.playerVolume.value);
        if (waitForBuffer) await _waitForAllBuffers();
        await _playAudioThenVideo();
      }
      if (!wasPlayingFromCache) {
        startSleepAfterMinCount();
        startCounterToAListen(pi);
        increaseListenTime();
      }
    }

    final playerStoppingSeikoo = Completer<bool>(); // to prevent accidental stopping if getAvailableStreams was faster than fade effect
    pause().then((_) async {
      await onDispose();
      playerStoppingSeikoo.complete(true);
    });

    await VideoController.vcontroller.dispose();

    (File?, NamidaVideo?, int?) playedFromCacheDetails = (null, null, null);
    bool okaySetFromCache() => playedFromCacheDetails.$1 != null && (canPlayAudioOnlyFromCache! || playedFromCacheDetails.$2 != null);

    await playerStoppingSeikoo.future;

    /// try playing cache always for faster playback initialization, if the quality should be
    /// different then it will be set later after fetching.
    playedFromCacheDetails = await _trySetYTVideoWithoutConnection(item: item, index: index, canPlayAudioOnly: canPlayAudioOnlyFromCache);

    currentCachedVideo.value = playedFromCacheDetails.$2;
    _currentAudioBitrate = playedFromCacheDetails.$3;

    bool heyIhandledAudioPlaying = false;
    if (okaySetFromCache()) {
      heyIhandledAudioPlaying = true;
      await plsplsplsPlay(false, false);
    } else {
      heyIhandledAudioPlaying = false;
    }

    if (ConnectivityController.inst.hasConnection) {
      try {
        _isFetchingInfo.value = true;
        final streams = await YoutubeController.inst.getAvailableStreams(item.id);
        _isFetchingInfo.value = false;
        if (item != currentVideo) return; // race avoidance when playing multiple videos

        YoutubeController.inst.currentYTQualities
          ..clear()
          ..addAll(streams.videoOnlyStreams ?? []);
        currentVideoInfo.value = streams.videoInfo;

        final vos = streams.videoOnlyStreams;
        final allVideoStream = isAudioOnlyPlayback || vos == null || vos.isEmpty ? null : YoutubeController.inst.getPreferredStreamQuality(vos, preferIncludeWebm: false);
        final prefferedVideoStream = allVideoStream;
        final prefferedAudioStream = streams.audioOnlyStreams?.firstWhereEff((e) => e.formatSuffix != 'webm') ?? streams.audioOnlyStreams?.firstOrNull;
        if (prefferedAudioStream?.url != null || prefferedVideoStream?.url != null) {
          currentVideoStream.value = prefferedVideoStream;
          currentAudioStream.value = prefferedAudioStream;
          _currentAudioBitrate = prefferedAudioStream?.bitrate;
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
              playedFromCacheDetails.$2 != null &&
              playedFromCacheDetails.$2?.path == cachedVideo.path; // only if not the same cache path (i.e. diff resolution)
          final isAudioCacheSameAsPrevSet =
              cachedAudio != null && playedFromCacheDetails.$1 != null && playedFromCacheDetails.$1?.path == cachedAudio.path; // only if not the same cache path

          final shouldResetVideoSource = !isAudioOnlyPlayback && !isVideoCacheSameAsPrevSet;
          final shouldResetAudioSource = !isAudioCacheSameAsPrevSet;

          // -- updating wether the source has changed, so that play should be triggered again.
          if (heyIhandledAudioPlaying) {
            heyIhandledAudioPlaying = shouldResetVideoSource || shouldResetAudioSource;
          }

          await Future.wait([
            if (shouldResetVideoSource)
              cachedVideo != null
                  ? VideoController.vcontroller.setFile(cachedVideo.path, (videoDuration) => false)
                  : VideoController.vcontroller.setNetworkSource(
                      url: prefferedVideoStream!.url!,
                      looping: (videoDuration) => false,
                      cacheKey: prefferedVideoStream.cacheKey(item.id),
                    ),
            if (shouldResetAudioSource)
              cachedAudio != null
                  ? setAudioSource(AudioSource.file(cachedAudio.path, tag: mediaItem))
                  : setAudioSource(
                      LockCachingAudioSource(
                        Uri.parse(prefferedAudioStream!.url!),
                        cacheFile: File(prefferedAudioStream.cachePath(item.id)),
                        tag: mediaItem,
                        onCacheDone: (cacheFile) async {
                          await _onAudioCacheDone(item.id, cacheFile);
                        },
                      ),
                    ),
          ]);
        }
      } catch (e) {
        if (item != currentVideo) return; // race avoidance when playing multiple videos
        SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
          if (item == currentItem) {
            // show error dialog
          }
        });
        printy(e, isError: true);
        playedFromCacheDetails = await _trySetYTVideoWithoutConnection(item: item, index: index, canPlayAudioOnly: canPlayAudioOnlyFromCache);
        if (!okaySetFromCache()) return;
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
      VideoController.inst.getYoutubeThumbnailAndCache(id: item.id).then((thumbFile) {
        if (currentItem == item) {
          currentVideoThumbnail.value = thumbFile;
          refreshNotification(currentItem);
        }
      });
    }

    if (!heyIhandledAudioPlaying) {
      await plsplsplsPlay(!okaySetFromCache(), okaySetFromCache());
    }
  }

  /// Returns Audio File and Video File.
  Future<(File?, NamidaVideo?, int?)> _trySetYTVideoWithoutConnection({required YoutubeID item, required int index, required bool canPlayAudioOnly}) async {
    // ------ Getting Video ------
    final allCachedVideos = VideoController.inst.getNVFromID(item.id);
    allCachedVideos.sortByReverseAlt(
      (e) {
        if (e.width != 0) return e.width;
        if (e.height != 0) return e.height;
        return 0;
      },
      (e) => e.frameratePrecise,
    );

    YoutubeController.inst.currentCachedQualities
      ..clear()
      ..addAll(allCachedVideos);

    final cachedVideo = allCachedVideos.firstOrNull;
    final mediaItem = item.toMediaItem(currentVideoInfo.value, currentVideoThumbnail.value, index, currentQueue.length);

    // ------ Getting Audio ------
    final audioFiles = await _getCachedAudiosForID.thready({
      "dirPath": AppDirs.AUDIOS_CACHE,
      "id": item.id,
    });
    final finalAudioFiles = audioFiles..sortByReverseAlt((e) => e.value ?? 0, (e) => e.key.sizeInBytesSync());
    final cachedAudio = finalAudioFiles.firstOrNull;

    // ------ Playing ------
    if (cachedVideo != null && cachedAudio != null) {
      // -- play audio & video
      await Future.wait([
        setAudioSource(AudioSource.file(cachedAudio.key.path, tag: mediaItem)),
        VideoController.vcontroller.setFile(cachedVideo.path, (videoDuration) => false),
      ]);
      return (cachedAudio.key, cachedVideo, cachedAudio.value);
    } else if (cachedAudio != null && canPlayAudioOnly) {
      // -- play audio only
      await setAudioSource(AudioSource.file(cachedAudio.key.path, tag: mediaItem));
      return (cachedAudio.key, null, cachedAudio.value);
    }
    return (null, null, null);
  }

  static List<MapEntry<File, int?>> _getCachedAudiosForID(Map map) {
    final dirPath = map["dirPath"] as String;
    final id = map["id"] as String;

    final newFiles = <MapEntry<File, int?>>[];

    for (final fe in Directory(dirPath).listSync()) {
      final filename = fe.path.getFilename;
      final goodID = filename.startsWith(id);
      final isGood = fe is File && goodID && !filename.endsWith('.part') && !filename.endsWith('.mime');

      if (isGood) {
        final bitrateText = fe.path.getFilenameWOExt.split('_').last;
        newFiles.add(MapEntry(fe, int.tryParse(bitrateText)));
      }
    }
    return newFiles;
  }

  static Map<String, List<MapEntry<File, int?>>> _getAllAudiosInCache(String dirPath) {
    final newFiles = <String, List<MapEntry<File, int?>>>{};

    for (final fe in Directory(dirPath).listSync()) {
      final filename = fe.path.getFilename;
      final isGood = fe is File && !filename.endsWith('.part') && !filename.endsWith('.mime');

      if (isGood) {
        final parts = fe.path.getFilenameWOExt.split('_');
        final id = parts.first;
        final bitrateText = parts.last;
        newFiles.addForce(id, MapEntry(fe, int.tryParse(bitrateText)));
      }
    }
    return newFiles;
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

  /// TODO: separate yt total listens
  @override
  FutureOr<void> onTotalListenTimeIncrease(int totalTimeInSeconds) async {
    // saves the file each 20 seconds.
    if (totalTimeInSeconds % 20 == 0) {
      _updateTrackLastPosition(currentTrack.track, currentPositionMS);
      await File(AppPaths.TOTAL_LISTEN_TIME).writeAsString(totalTimeInSeconds.toString());
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
  double get userPlayerVolume => settings.playerVolume.value;

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
  @override
  Future<void> onSeek(Duration position) async {
    await Future.wait([
      super.onSeek(position),
      VideoController.vcontroller.seek(position),
    ]);
  }

  @override
  Future<void> play() async {
    await onPlay();
  }

  @override
  Future<void> pause() async {
    await onPause();
  }

  Future<void> togglePlayPause() async {
    if (isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    final wasPlaying = isPlaying;

    Future<void> plsSeek() async => await onSeek(position);

    Future<void> plsPause() async {
      await Future.wait([
        super.onPauseRaw(),
        VideoController.vcontroller.pause(),
      ]);
    }

    await currentItem?._execute(
      selectable: (finalItem) async {
        await plsPause();
        await plsSeek();
      },
      youtubeID: (finalItem) async {
        await plsPause();
        await plsSeek();
      },
    );

    await _waitForAllBuffers();
    if (wasPlaying) await _playAudioThenVideo();
  }

  @override
  Future<void> skipToNext([bool? andPlay]) async => await onSkipToNext(andPlay);

  @override
  Future<void> skipToPrevious() async => await onSkipToPrevious();

  @override
  Future<void> skipToQueueItem(int index, [bool? andPlay]) async => await onSkipToQueueItem(index, andPlay);

  @override
  Future<void> stop() async => await onStop();

  @override
  Future<void> fastForward() async => await onFastForward();

  @override
  Future<void> rewind() async => await onRewind();

  @override
  void onBufferOrLoadStart() {
    if (isPlaying) {
      VideoController.vcontroller.pause();
    }
  }

  @override
  void onBufferOrLoadEnd() {
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
    final del = _videoPositionSeekDelayMS.abs();
    final vcp = VideoController.vcontroller.videoController?.value.position.inMilliseconds ?? 0;
    final diff = (vcp - currentPositionMS).abs();
    if (diff <= del) {
      await Future.delayed(Duration(milliseconds: del));
    }
    await VideoController.vcontroller.play();
  }
}

// ----------------------- Extensions --------------------------
extension TrackToAudioSourceMediaItem on Selectable {
  UriAudioSource toAudioSource(int currentIndex, int queueLength) {
    return AudioSource.uri(
      Uri.parse(track.path),
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
