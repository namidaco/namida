import 'dart:async';
import 'dart:io';

import 'package:flutter/scheduler.dart';

import 'package:audio_service/audio_service.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_utils/src/extensions/num_extensions.dart';
import 'package:just_audio/just_audio.dart';
import 'package:queue_manager/queue_manager.dart';

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

class NamidaAudioVideoHandler extends BaseAudioHandler with QueueManager<Selectable> {
  Selectable get currentTrack => currentItem ?? kDummyTrack;
  int get currentPositionMS => _currentPositionMS.value;
  bool get isPlaying => _isPlaying.value;
  int get numberOfRepeats => _numberOfRepeats.value;

  final _currentPositionMS = 0.obs;
  final _totalListenedTimeInSec = 0.obs;
  final _isPlaying = false.obs;
  final _numberOfRepeats = 1.obs;

  final currentVolume = SettingsController.inst.playerVolume.value.obs;

  // Sleep Timer related
  final _enableSleepAfterTracks = false.obs;
  final _enableSleepAfterMins = false.obs;
  final _sleepAfterMin = 0.obs;
  final _sleepAfterTracks = 0.obs;
  bool get enableSleepAfterTracks => _enableSleepAfterTracks.value;
  bool get enableSleepAfterMins => _enableSleepAfterMins.value;
  int get sleepAfterMin => _sleepAfterMin.value;
  int get sleepAfterTracks => _sleepAfterTracks.value;

  void updateSleepTimerValues({
    bool? enableSleepAfterTracks,
    bool? enableSleepAfterMins,
    int? sleepAfterMin,
    int? sleepAfterTracks,
  }) {
    if (enableSleepAfterTracks != null) _enableSleepAfterMins.value = enableSleepAfterTracks;
    if (enableSleepAfterMins != null) _enableSleepAfterMins.value = enableSleepAfterMins;
    if (sleepAfterMin != null) _sleepAfterMin.value = sleepAfterMin;
    if (sleepAfterTracks != null) _sleepAfterTracks.value = sleepAfterTracks;
  }

  void resetSleepAfterTimer() {
    _enableSleepAfterMins.value = false;
    _enableSleepAfterTracks.value = false;
    _sleepAfterMin.value = 0;
    _sleepAfterTracks.value = 0;
  }

  void updateNumberOfRepeats(int newNumber) {
    _numberOfRepeats.value = newNumber;
  }

  // ============== CONSTRUCTOR ==============
  NamidaAudioVideoHandler() {
    _player.playbackEventStream.listen((event) {
      playbackState.add(_transformEvent(event));
    });

    _player.processingStateStream.listen((state) async {
      if (state == ProcessingState.completed) {
        /// Sleep timer after n tracks
        if (_enableSleepAfterTracks.value) {
          _sleepAfterTracks.value = (sleepAfterTracks - 1).clamp(0, kMaximumSleepTimerTracks);
          if (sleepAfterTracks == 0) {
            Player.inst.resetSleepAfterTimer();
            await pause();
            return;
          }
        }

        /// repeat moods
        final repeat = SettingsController.inst.playerRepeatMode.value;
        switch (repeat) {
          case RepeatMode.none:
            if (SettingsController.inst.jumpToFirstTrackAfterFinishingQueue.value) {
              await skipToNext(!isLastItem);
            } else {
              await pause();
            }
            break;

          case RepeatMode.one:
            await skipToQueueItem(currentIndex);
            break;

          case RepeatMode.forNtimes:
            if (numberOfRepeats == 1) {
              SettingsController.inst.save(playerRepeatMode: RepeatMode.none);
            } else {
              _numberOfRepeats.value--;
            }
            await skipToQueueItem(currentIndex);
            break;

          case RepeatMode.all:
            await skipToNext();
            break;

          default:
            null;
        }
      }
    });

    _player.volumeStream.listen((event) {
      currentVolume.value = event;
    });

    _player.positionStream.listen((event) {
      _currentPositionMS.value = event.inMilliseconds;
    });

    _player.playingStream.listen((event) async {
      _isPlaying.value = event;
      CurrentColor.inst.switchColorPalettes(event);
    });
  }

  /// For ensuring stabilty while fade effect is on.
  /// Typically stops ongoing [playWithFadeEffect] to prevent multiple [setVolume] interferring.
  bool _wantToPause = false;

  /// Timers
  Timer? _playFadeTimer;
  Timer? _pauseFadeTimer;
  Timer? _increaseListenTimer;
  Timer? _startsleepAfterMinTimer;

  void increaseListenTime(Track track) {
    _increaseListenTimer?.cancel();
    _increaseListenTimer = null;
    _increaseListenTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (isPlaying) {
        _totalListenedTimeInSec.value++;

        /// saves the file each 20 seconds.
        final sec = _totalListenedTimeInSec.value;
        if (sec % 20 == 0) {
          await File(k_FILE_PATH_TOTAL_LISTEN_TIME).writeAsString(sec.toString());
        }
      }
    });
  }

  void startSleepAfterMinCount(Track track) async {
    _startsleepAfterMinTimer?.cancel();
    _startsleepAfterMinTimer = null;
    _startsleepAfterMinTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      if (enableSleepAfterMins) {
        if (isPlaying) {
          _sleepAfterMin.value = (sleepAfterMin - 1).clamp(0, kMaximumSleepTimerMins);
          if (_sleepAfterMin.value == 0) {
            Player.inst.resetSleepAfterTimer();
            await pause();
            timer.cancel();
            return;
          }
        }
      }
    });
  }

  Future<void> updateTrackLastPosition(Track track, int lastPositionMS) async {
    /// Saves a starting position in case the remaining was less than 30 seconds.
    final remaining = (track.duration * 1000) - lastPositionMS;
    final positionToSave = remaining <= 30000 ? 0 : lastPositionMS;

    await Indexer.inst.updateTrackStats(track, lastPositionInMs: positionToSave);
  }

  Future<void> prepareTotalListenTime() async {
    final file = await File(k_FILE_PATH_TOTAL_LISTEN_TIME).create();
    final text = await file.readAsString();
    final listenTime = int.tryParse(text);
    _totalListenedTimeInSec.value = listenTime ?? 0;
  }

  Future<void> setSkipSilenceEnabled(bool enabled) async => await _player.setSkipSilenceEnabled(enabled);

  Future<void> tryRestoringLastPosition(Track trackPre) async {
    final minValueInSet = SettingsController.inst.minTrackDurationToRestoreLastPosInMinutes.value * 60;
    final track = trackPre.toTrackExt();
    if (minValueInSet > 0) {
      final lastPos = track.stats.lastPositionInMs;
      if (lastPos != 0 && track.duration >= minValueInSet) {
        await seek(lastPos.milliseconds);
      }
    }
  }

  //
  // =================================================================================
  // ================================ Video Methods ==================================
  // =================================================================================
  Future<void> updateVideoPlayingState() async {
    if (isPlaying) {
      VideoController.vcontroller.play();
    } else {
      VideoController.vcontroller.pause();
    }
    refreshVideoPosition();
  }

  Future<void> refreshVideoPosition() async {
    await VideoController.vcontroller.seek(Duration(milliseconds: currentPositionMS));
  }
  // =================================================================================
  //

  //
  // =================================================================================
  // ================================ Player methods =================================
  // =================================================================================
  void notificationUpdateItem([Track? track]) {
    track ??= currentTrack.track;
    mediaItem.add(track.toMediaItem(currentIndex, currentQueue.length));
    playbackState.add(_transformEvent(PlaybackEvent()));
  }

  Future<void> togglePlayPause() async {
    if (isPlaying) {
      await pause();
    } else {
      await play();
      await seek(Duration(milliseconds: currentPositionMS));
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
      printy("Fade Volume Play: ${vol.toString()}");
      setVolume(vol);
      if (vol >= SettingsController.inst.playerVolume.value || _wantToPause) {
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
      printy("Fade Volume Pause ${vol.toString()}");
      setVolume(vol);
      if (vol <= 0.0) {
        timer.cancel();
        _player.pause();
      }
    });
  }

  @override
  Future<void> play() async {
    _wantToPause = false;

    if (SettingsController.inst.enableVolumeFadeOnPlayPause.value && currentPositionMS > 200) {
      await playWithFadeEffect();
    } else {
      _player.play();
      setVolume(SettingsController.inst.playerVolume.value);
    }
    VideoController.vcontroller.play();
  }

  @override
  Future<void> pause() async {
    _wantToPause = true;
    if (SettingsController.inst.enableVolumeFadeOnPlayPause.value && currentPositionMS > 200) {
      await pauseWithFadeEffect();
    } else {
      _player.pause();
    }
    VideoController.vcontroller.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    int p = position.inMilliseconds;
    if (p < 0) {
      p = 0;
    }

    /// Starts a new listen counter in case seeking was backwards and was >= 20% of the track
    if (position.inMilliseconds < currentPositionMS) {
      final diffInSeek = currentPositionMS - position.inMilliseconds;
      final percentage = diffInSeek / (_player.duration?.inMilliseconds ?? 1);
      if (percentage >= 0.2) {
        HistoryController.inst.startCounterToAListen(currentTrack.track);
      }
    }
    final msd = p.milliseconds;
    await Future.wait([
      _player.seek(msd),
      VideoController.vcontroller.seek(msd),
    ]);
  }

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
  }

  @override
  Future<void> skipToNext([bool? andPlay]) async {
    if (isLastItem) {
      await skipToQueueItem(0, andPlay);
    } else {
      await skipToQueueItem(currentIndex + 1);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (currentIndex == 0) {
      await skipToQueueItem(currentQueue.length - 1);
    } else {
      await skipToQueueItem(currentIndex - 1);
    }
  }

  @override
  Future<void> skipToQueueItem(int index, [bool? andPlay]) async {
    await skipToItem(index, andPlay ?? defaultShouldStartPlaying);
  }

  @override
  Future<void> stop() async => await _player.stop();

  @override
  Future<void> fastForward() async {
    _toggleFavTrack();
  }

  @override
  Future<void> rewind() async {
    _toggleFavTrack();
  }

  Future<void> _toggleFavTrack() async {
    PlaylistController.inst.favouriteButtonOnPressed(Player.inst.nowPlayingTrack);
    notificationUpdateItem();
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
      fmc.insertSafe(0, Player.inst.nowPlayingTrack.isFavourite ? MediaControl.fastForward : MediaControl.rewind);
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
  // =================================================================================
  //

  //
  // ==============================================================================================
  // ==============================================================================================
  // ================================== QueueManager Overriden ====================================
  @override
  void beforePlaying() async {
    updateTrackLastPosition(currentTrack.track, currentPositionMS);
  }

  @override
  Future<void> playFunction(Selectable item, bool startPlaying) async {
    final tr = item.track;
    VideoController.inst.updateCurrentVideo(tr);

    /// The whole idea of pausing and playing is due to the bug where [headset buttons/android next gesture] don't get detected.
    try {
      final dur = await _player.setAudioSource(tr.toAudioSource(currentIndex, currentQueue.length));
      if (tr.duration == 0) tr.duration = dur?.inSeconds ?? 0;
    } catch (e) {
      SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
        NamidaDialogs.inst.showTrackDialog(tr, isFromPlayerQueue: true, errorPlayingTrack: true);
      });
      printy(e, isError: true);
      return;
    }
    await Future.wait([
      _player.pause(),
      tryRestoringLastPosition(tr),
    ]);

    if (startPlaying) {
      _player.play();
      VideoController.vcontroller.play();
      setVolume(SettingsController.inst.playerVolume.value);
    }

    startSleepAfterMinCount(tr);
    WaveformController.inst.generateWaveform(tr);
    HistoryController.inst.startCounterToAListen(tr);
    increaseListenTime(tr);
    SettingsController.inst.save(lastPlayedTrackPath: tr.path);
    Lyrics.inst.updateLyrics(tr);
  }

  @override
  void onIndexChanged(int newIndex, Selectable newItem) {
    notificationUpdateItem(newItem.track);
    CurrentColor.inst.updatePlayerColorFromTrack(newItem, newIndex);
  }

  @override
  void onQueueChanged() async {
    super.onQueueChanged();
    notificationUpdateItem();
    await QueueController.inst.updateLatestQueue(currentQueue.tracks.toList());
  }

  @override
  void onReorderItems(int currentIndex) {
    super.onReorderItems(currentIndex);
    QueueController.inst.updateLatestQueue(currentQueue.tracks.toList());
  }
  // ==============================================================================================
  //

  bool get defaultShouldStartPlaying => (SettingsController.inst.playerPlayOnNextPrev.value || isPlaying);

  final _player = AudioPlayer();
}

// ----------------------- Extensions --------------------------
extension _MediaItemToAudioSource on MediaItem {
  AudioSource toAudioSource() => AudioSource.uri(Uri.parse(id));
}

extension _MediaItemsListToAudioSources on Iterable<MediaItem> {
  Iterable<AudioSource> toAudioSources() => map((e) => e.toAudioSource());
}

extension TrackToAudioSourceMediaItem on Selectable {
  UriAudioSource toAudioSource(int currentIndex, int queueLength) {
    return AudioSource.uri(
      Uri.parse(track.path),
      tag: toMediaItem(currentIndex, queueLength),
    );
  }

  MediaItem toMediaItem(int currentIndex, int queueLength) {
    final tr = track.toTrackExt();
    return MediaItem(
      id: tr.path,
      title: tr.title,
      displayTitle: tr.title,
      displaySubtitle: tr.hasUnknownAlbum ? tr.originalArtist : "${tr.originalArtist} - ${tr.album}",
      displayDescription: "${currentIndex + 1}/$queueLength",
      artist: tr.originalArtist,
      album: tr.hasUnknownAlbum ? '' : tr.album,
      genre: tr.originalGenre,
      duration: Duration(seconds: tr.duration),
      artUri: Uri.file(File(tr.pathToImage).existsSync() ? tr.pathToImage : k_FILE_PATH_NAMIDA_LOGO),
    );
  }
}
