import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:audio_service/audio_service.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';

import 'package:namida/class/track.dart';
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
import 'package:namida/ui/dialogs/common_dialogs.dart';

class NamidaAudioVideoHandler extends BaseAudioHandler {
  final _player = AudioPlayer();

  final Player namidaPlayer;

  RxList<Track> get currentQueue => namidaPlayer.currentQueue;
  Rx<Track> get nowPlayingTrack => namidaPlayer.nowPlayingTrack;
  RxInt get nowPlayingPosition => namidaPlayer.nowPlayingPosition;
  RxInt get currentIndex => namidaPlayer.currentIndex;
  RxDouble get currentVolume => namidaPlayer.currentVolume;
  RxBool get isPlaying => namidaPlayer.isPlaying;
  RxInt get numberOfRepeats => namidaPlayer.numberOfRepeats;
  RxBool get enableSleepAfterTracks => namidaPlayer.enableSleepAfterTracks;
  RxBool get enableSleepAfterMins => namidaPlayer.enableSleepAfterMins;
  RxInt get sleepAfterTracks => namidaPlayer.sleepAfterTracks;
  RxInt get sleepAfterMin => namidaPlayer.sleepAfterMin;

  RxInt get totalListenedTimeInSec => namidaPlayer.totalListenedTimeInSec;

  bool get isLastTrack => currentIndex.value == currentQueue.length - 1;

  /// Timers
  Timer? _playFadeTimer;
  Timer? _pauseFadeTimer;
  Timer? _increaseListenTimer;
  Timer? _startsleepAfterMinTimer;

  NamidaAudioVideoHandler(this.namidaPlayer) {
    _player.playbackEventStream.listen((event) {
      playbackState.add(_transformEvent(event));
    });

    _player.processingStateStream.listen((state) async {
      if (state == ProcessingState.completed) {
        /// Sleep timer after n tracks
        if (enableSleepAfterTracks.value) {
          sleepAfterTracks.value = (sleepAfterTracks.value - 1).clamp(0, 40);
          if (sleepAfterTracks.value == 0) {
            Player.inst.resetSleepAfterTimer();
            await pause();
            return;
          }
        }

        /// repeat moods
        final repeat = SettingsController.inst.playerRepeatMode.value;
        if (repeat == RepeatMode.none) {
          if (SettingsController.inst.jumpToFirstTrackAfterFinishingQueue.value) {
            await skipToNext(!isLastTrack);
          } else {
            await pause();
          }
        }
        if (repeat == RepeatMode.one) {
          await skipToQueueItem(currentIndex.value);
        }
        if (repeat == RepeatMode.forNtimes) {
          if (numberOfRepeats.value == 1) {
            SettingsController.inst.save(playerRepeatMode: RepeatMode.none);
          } else {
            numberOfRepeats.value--;
          }
          await skipToQueueItem(currentIndex.value);
        }
        if (repeat == RepeatMode.all) {
          await skipToNext();
        }
      }
    });

    _player.volumeStream.listen((event) {
      currentVolume.value = event;
    });

    _player.positionStream.listen((event) {
      nowPlayingPosition.value = event.inMilliseconds;
    });

    _player.playingStream.listen((event) async {
      isPlaying.value = event;
      await updateVideoPlayingState();
      CurrentColor.inst.switchColorPalettes(event);
    });

    _player.positionStream.listen((event) {
      nowPlayingPosition.value = event.inMilliseconds;
    });

    // Attempt to fix video position after switching to bg or turning off screen
    _player.positionDiscontinuityStream.listen((event) async {
      await updateVideoPlayingState();
    });
  }

  /// For ensuring stabilty while fade effect is on.
  /// Typically stops ongoing [playWithFadeEffect] to prevent multiple [setVolume] interferring.
  bool wantToPause = false;

  void increaseListenTime(Track track) {
    _increaseListenTimer?.cancel();
    _increaseListenTimer = null;
    _increaseListenTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (isPlaying.value) {
        totalListenedTimeInSec.value++;

        /// saves the file each 20 seconds.
        if (totalListenedTimeInSec.value % 20 == 0) {
          await File(k_FILE_PATH_TOTAL_LISTEN_TIME).writeAsString(totalListenedTimeInSec.value.toString());
        }
      }
    });
  }

  Future<void> prepareTotalListenTime() async {
    final file = await File(k_FILE_PATH_TOTAL_LISTEN_TIME).create();
    final text = await file.readAsString();
    final listenTime = int.tryParse(text);
    totalListenedTimeInSec.value = listenTime ?? 0;
  }

  Future<void> setSkipSilenceEnabled(bool enabled) async => await _player.setSkipSilenceEnabled(enabled);

  //
  // Video Methods
  Future<void> updateVideoPlayingState() async {
    await refreshVideoPosition();
    if (isPlaying.value) {
      VideoController.inst.play();
    } else {
      VideoController.inst.pause();
    }
    await refreshVideoPosition();
  }

  Future<void> refreshVideoPosition() async {
    await VideoController.inst.seek(Duration(milliseconds: nowPlayingPosition.value));
  }

  // End of Video Methods.
  //

  //
  // Namida Methods.
  Future<void> setAudioSource(int index, {bool preload = true, bool startPlaying = true, int? dateAdded}) async {
    updateTrackLastPosition(nowPlayingTrack.value, nowPlayingPosition.value);

    final tr = currentQueue.elementAt(index);
    nowPlayingTrack.value = tr;
    currentIndex.value = index;
    updateCurrentMediaItem(tr);

    CurrentColor.inst.updatePlayerColorFromTrack(tr, index, dateAdded: dateAdded);
    VideoController.inst.updateLocalVidPath(tr);
    updateVideoPlayingState();

    /// The whole idea of pausing and playing is due to the bug where [headset buttons/android next gesture] don't get detected.
    try {
      final dur = await _player.setAudioSource(tr.toAudioSource());
      if (tr.duration == 0) tr.duration = dur?.inMilliseconds ?? 0;
    } catch (e) {
      SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
        NamidaDialogs.inst.showTrackDialog(tr, isFromPlayerQueue: true, errorPlayingTrack: true);
      });
      debugPrint(e.toString());
      return;
    }

    await Future.wait([
      _player.pause(),
      tryRestoringLastPosition(tr),
    ]);

    if (startPlaying) {
      _player.play();
      setVolume(SettingsController.inst.playerVolume.value);
    }

    startSleepAfterMinCount(tr);
    WaveformController.inst.generateWaveform(tr);
    HistoryController.inst.startCounterToAListen(nowPlayingTrack.value);
    increaseListenTime(tr);
    SettingsController.inst.save(lastPlayedTrackPath: tr.path);
    Lyrics.inst.updateLyrics(tr);
    tryResettingLatestInsertedIndex();
  }

  Future<void> updateTrackLastPosition(Track trackPre, int lastPosition) async {
    final track = trackPre.toTrackExt();

    /// Saves a starting position in case the remaining was less than 30 seconds.
    final remaining = track.duration - lastPosition;
    final positionToSave = remaining <= 30000 ? 0 : lastPosition;

    await Indexer.inst.updateTrackStats(trackPre, lastPositionInMs: positionToSave);
  }

  Future<void> tryRestoringLastPosition(Track trackPre) async {
    final minValueInSet = Duration(minutes: SettingsController.inst.minTrackDurationToRestoreLastPosInMinutes.value).inMilliseconds;
    final track = trackPre.toTrackExt();
    if (minValueInSet > 0) {
      final lastPos = track.stats.lastPositionInMs;
      if (lastPos != 0 && track.duration >= minValueInSet) {
        await seek(lastPos.milliseconds);
      }
    }
  }

  void startSleepAfterMinCount(Track track) async {
    _startsleepAfterMinTimer?.cancel();
    _startsleepAfterMinTimer = null;
    _startsleepAfterMinTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (enableSleepAfterMins.value) {
        if (isPlaying.value) {
          sleepAfterMin.value = (sleepAfterMin.value - 1).clamp(0, 180);
          if (sleepAfterMin.value == 0) {
            Player.inst.resetSleepAfterTimer();
            await pause();
            timer.cancel();
            return;
          }
        }
      }
    });
  }

  /// if [force] is enabled, [track] will not be used.
  void updateCurrentMediaItem([Track? track, bool force = false]) {
    if (force) {
      playbackState.add(_transformEvent(PlaybackEvent()));
      return;
    }
    track ??= nowPlayingTrack.value;
    mediaItem.add(track.toMediaItem());
  }

  Future<void> togglePlayPause() async {
    if (isPlaying.value) {
      await pause();
    } else {
      await play();
      await seek(Duration(milliseconds: nowPlayingPosition.value));
    }
  }

  Future<void> playWithFadeEffect() async {
    final duration = SettingsController.inst.playerPlayFadeDurInMilli.value;
    final interval = (0.05 * duration).toInt();
    final steps = duration ~/ interval;
    double vol = 0.0;
    await setVolume(0.0);
    _player.play();

    _playFadeTimer?.cancel();
    _playFadeTimer = null;
    _playFadeTimer = Timer.periodic(Duration(milliseconds: interval), (timer) {
      vol += 1 / steps;
      printInfo(info: "Fade Volume Play: ${vol.toString()}");
      setVolume(vol);
      if (vol >= SettingsController.inst.playerVolume.value || wantToPause) {
        timer.cancel();
      }
    });
  }

  Future<void> pauseWithFadeEffect() async {
    final duration = SettingsController.inst.playerPauseFadeDurInMilli.value;
    final interval = (0.05 * duration).toInt();
    final steps = duration ~/ interval;
    double vol = currentVolume.value;

    _pauseFadeTimer?.cancel();
    _pauseFadeTimer = null;
    _pauseFadeTimer = Timer.periodic(Duration(milliseconds: interval), (timer) {
      vol -= 1 / steps;
      printInfo(info: "Fade Volume Pause ${vol.toString()}");
      setVolume(vol);
      if (vol <= 0.0) {
        timer.cancel();
        _player.pause();
      }
    });
  }

  void reorderTrack(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) {
      return;
    }
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    int i = currentIndex.value;
    if (oldIndex == currentIndex.value) {
      i = newIndex;
    }

    /// Track is dragged from after the currentTrack to before the currentTrack.
    if (oldIndex < currentIndex.value && newIndex >= currentIndex.value) {
      i = currentIndex.value - 1;
    }

    /// Track is dragged from before the currentTrack to after the currentTrack.
    if (oldIndex > currentIndex.value && newIndex <= currentIndex.value) {
      i = currentIndex.value + 1;
    }

    currentIndex.value = i;
    CurrentColor.inst.currentPlayingIndex.value = i;
    final item = currentQueue.elementAt(oldIndex);
    currentQueue.removeAt(oldIndex);
    insertInQueue([item], newIndex);
  }

  void shuffleNextTracks() {
    if (isLastTrack) {
      return;
    }
    final List<Track> newTracks = [];
    final first = currentIndex.value + 1;
    final last = currentQueue.length;
    newTracks
      ..assignAll(currentQueue.getRange(first, last))
      ..shuffle();
    removeRangeFromQueue(first, last);
    insertInQueue(newTracks, first);
  }

  /// Buggy
  // void shuffleAllQueue() {
  //   currentQueue.shuffle();
  //   currentIndex.value == currentQueue.indexOf(nowPlayingTrack.value);
  // }

  void removeDuplicatesFromQueue() {
    final ct = nowPlayingTrack.value;
    currentQueue.removeDuplicates((element) => element.path);
    final newIndex = currentQueue.indexOf(ct);
    currentIndex.value = newIndex;
    CurrentColor.inst.updatePlayerColorFromTrack(ct, newIndex);
  }

  void addToQueue(List<Track> tracks, {bool insertNext = false, bool insertAfterLatest = false}) {
    if (currentQueue.isEmpty) {
      currentQueue.addAll(tracks);
      nowPlayingTrack.value = tracks.first;
    } else {
      if (insertNext) {
        insertInQueue(tracks, currentIndex.value + 1);
        namidaPlayer.latestInsertedIndex = currentIndex.value + 1;
      } else if (insertAfterLatest) {
        insertInQueue(tracks, namidaPlayer.latestInsertedIndex + 1);
        namidaPlayer.latestInsertedIndex += tracks.length;
      } else {
        currentQueue.addAll(tracks);
        namidaPlayer.latestInsertedIndex = currentQueue.length - 1;
      }
    }

    afterQueueChange();
  }

  void insertInQueue(List<Track> tracks, int index) {
    currentQueue.insertAllSafe(index, tracks);
    afterQueueChange();
  }

  Future<void> removeFromQueue(int index) async {
    if (index == currentIndex.value) {
      if (currentQueue.isNotEmpty) {
        if (isLastTrack) {
          await setAudioSource(index - 1);
        } else {
          await setAudioSource(index);
        }
      }
    }
    currentQueue.removeAt(index);
    final ci = currentIndex.value;
    if (index < ci) {
      currentIndex.value = ci - 1;
      CurrentColor.inst.currentPlayingIndex.value = ci - 1;
    }

    afterQueueChange();
  }

  Future<void> removeRangeFromQueue(int start, int end) async {
    currentQueue.removeRange(start, end);
    await afterQueueChange();
  }

  /// Only use when updating missing track.
  Future<void> replaceAllTracksInQueue(Track oldTrack, Track newTrack) async {
    currentQueue.replaceItems(oldTrack, newTrack);
    afterQueueChange();
  }

  Future<void> afterQueueChange() async {
    tryResettingLatestInsertedIndex();
    updateCurrentMediaItem();
    await QueueController.inst.updateLatestQueue(currentQueue);
  }

  void tryResettingLatestInsertedIndex() {
    if (currentIndex.value >= namidaPlayer.latestInsertedIndex || currentQueue.length <= namidaPlayer.latestInsertedIndex) {
      namidaPlayer.latestInsertedIndex = currentIndex.value;
    }
  }

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
  }

  // End of Namida Methods.
  //

  //
  // audio_service overriden methods.
  @override
  Future<void> play() async {
    wantToPause = false;

    if (SettingsController.inst.enableVolumeFadeOnPlayPause.value && nowPlayingPosition.value > 200) {
      await playWithFadeEffect();
    } else {
      _player.play();
      setVolume(SettingsController.inst.playerVolume.value);
    }
  }

  @override
  Future<void> pause() async {
    wantToPause = true;
    if (SettingsController.inst.enableVolumeFadeOnPlayPause.value && nowPlayingPosition.value > 200) {
      await pauseWithFadeEffect();
    } else {
      _player.pause();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    int p = position.inMilliseconds;
    if (p < 0) {
      p = 0;
    }

    /// Starts a new listen counter in case seeking was backwards and was >= 20% of the track
    if (position.inMilliseconds < nowPlayingPosition.value) {
      final diffInSeek = nowPlayingPosition.value - position.inMilliseconds;
      final percentage = diffInSeek / (_player.duration?.inMilliseconds ?? 1);
      if (percentage >= 0.2) {
        HistoryController.inst.startCounterToAListen(nowPlayingTrack.value);
      }
    }
    await _player.seek(p.milliseconds);
    await VideoController.inst.seek(p.milliseconds);
  }

  @override
  Future<void> stop() async {
    // await _player.pause();
    // await Player.inst.closePlayerNotification();
    // await _player.pause();
    await _player.stop();
  }

  @override
  Future<void> skipToNext([bool? andPlay]) async {
    if (isLastTrack) {
      await skipToQueueItem(0, andPlay);
    } else {
      await skipToQueueItem(currentIndex.value + 1);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (currentIndex.value == 0) {
      await skipToQueueItem(currentQueue.length - 1);
    } else {
      await skipToQueueItem(currentIndex.value - 1);
    }
  }

  @override
  Future<void> skipToQueueItem(int index, [bool? andPlay]) async {
    await setAudioSource(index, startPlaying: andPlay ?? (SettingsController.inst.playerPlayOnNextPrev.value || isPlaying.value));
  }

  // End of  audio_service overriden methods.
  //

  //
  // Media Control Specific
  @override
  Future<void> fastForward() async {
    PlaylistController.inst.favouriteButtonOnPressed(Player.inst.nowPlayingTrack.value);
    updateCurrentMediaItem(null, true);
  }

  @override
  Future<void> rewind() async {
    PlaylistController.inst.favouriteButtonOnPressed(Player.inst.nowPlayingTrack.value);
    updateCurrentMediaItem(null, true);
  }

  /// [fastForward] is favourite track.
  /// [rewind] is unfavourite track.
  PlaybackState _transformEvent(PlaybackEvent event) {
    final List<int> iconsIndexes = [0, 1, 2];
    final List<MediaControl> fmc = [
      MediaControl.skipToPrevious,
      if (_player.playing) MediaControl.pause else MediaControl.play,
      MediaControl.skipToNext,
      MediaControl.stop,
    ];
    if (SettingsController.inst.displayFavouriteButtonInNotification.value) {
      fmc.insertSafe(0, Player.inst.nowPlayingTrack.value.isFavourite ? MediaControl.fastForward : MediaControl.rewind);
      iconsIndexes.assignAll(const [1, 2, 3]);
    }
    return PlaybackState(
      controls: fmc,
      systemActions: const {
        MediaAction.seek,
        MediaAction.skipToPrevious,
        MediaAction.skipToNext,
      },
      androidCompactActionIndices: iconsIndexes,
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }
}

extension MediaItemToAudioSource on MediaItem {
  AudioSource get toAudioSource => AudioSource.uri(Uri.parse(id));
}

extension MediaItemsListToAudioSources on Iterable<MediaItem> {
  Iterable<AudioSource> get toAudioSources => map((e) => e.toAudioSource);
}

extension TrackToAudioSourceMediaItem on Track {
  UriAudioSource toAudioSource() {
    return AudioSource.uri(
      Uri.parse(path),
      tag: toMediaItem,
    );
  }

  MediaItem toMediaItem() {
    final track = toTrackExt();
    return MediaItem(
      id: path,
      title: track.title,
      displayTitle: track.title,
      displaySubtitle: track.hasUnknownAlbum ? track.originalArtist : "${track.originalArtist} - ${track.album}",
      displayDescription: "${Player.inst.currentIndex.value + 1}/${Player.inst.currentQueue.length}",
      artist: track.originalArtist,
      album: track.hasUnknownAlbum ? '' : track.album,
      genre: track.genresList.take(3).join(', '),
      duration: Duration(milliseconds: track.duration),
      artUri: Uri.file(File(pathToImage).existsSync() ? pathToImage : k_FILE_PATH_NAMIDA_LOGO),
    );
  }
}

extension TracksListToAudioSourcesMediaItems on List<Track> {
  Iterable<AudioSource> toAudioSources() => map((e) => e.toAudioSource());
  Iterable<MediaItem> toMediaItems() => map((e) => e.toMediaItem());
  ConcatenatingAudioSource get toConcatenatingAudioSource => ConcatenatingAudioSource(
        useLazyPreparation: true,
        shuffleOrder: DefaultShuffleOrder(),
        children: map((e) => e.toAudioSource()).toList(),
      );
}
