import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
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

class NamidaAudioVideoHandler extends BaseAudioHandler with SeekHandler, QueueHandler {
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

  bool get isLastTrack => currentIndex.value == currentQueue.length - 1;

  NamidaAudioVideoHandler(this.namidaPlayer) {
    _player.playbackEventStream.listen((event) {
      playbackState.add(_transformEvent(event));
    });

    _player.playbackEventStream.listen((event) {
      QueueController.inst.updateLatestQueue(currentQueue.toList());
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
          await skipToNext(!isLastTrack);
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
    Timer.periodic(const Duration(seconds: 1), (timer) {
      nowPlayingTrack.listen((p0) {
        if (track != p0) {
          timer.cancel();
          return;
        }
      });
      if (isPlaying.value) {
        SettingsController.inst.save(totalListenedTimeInSec: SettingsController.inst.totalListenedTimeInSec.value + 1);
      }
    });
  }

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
  Future<void> setAudioSource(int index, {bool preload = true, bool startPlaying = true}) async {
    final tr = currentQueue.elementAt(index);
    nowPlayingTrack.value = tr;
    currentIndex.value = index;

    CurrentColor.inst.updatePlayerColor(tr, index);
    VideoController.inst.updateLocalVidPath(tr);
    updateVideoPlayingState();
    updateCurrentMediaItem(tr);

    /// Te whole idea of pausing and playing is due to the bug where [headset buttons/android next gesture] don't get detected.
    try {
      if (startPlaying && !isPlaying.value) {
        _player.play();
      }
      await _player.setAudioSource(tr.toAudioSource(), preload: preload);
      _player.pause();
      if (startPlaying) {
        _player.play();
        setVolume(SettingsController.inst.playerVolume.value);
      }
      // await stop();
      // await _player.setAudioSource(tr.toAudioSource(), preload: preload);
      // if (startPlaying) {
      //   _player.play();
      //   setVolume(SettingsController.inst.playerVolume.value);
      // }
      startSleepAfterMinCount(tr);
      WaveformController.inst.generateWaveform(tr);
      PlaylistController.inst.addToHistory(nowPlayingTrack.value);
      increaseListenTime(tr);
      SettingsController.inst.save(lastPlayedTrackPath: tr.path);
      Lyrics.inst.updateLyrics(tr);
      tryResettingLatestInsertedIndex();
    } catch (e) {
      /// if track doesnt exist
      NamidaDialogs.inst.showTrackDialog(tr, isFromPlayerQueue: true, errorPlayingTrack: true);
      return;
    }
  }

  Future<void> updateTrackLastPosition(Track track, int lastPosition) async {
    /// Saves a starting position in case the remaining was less than 30 seconds.
    final remaining = track.duration - lastPosition;
    final positionToSave = remaining <= 30000 ? 0 : lastPosition;

    Indexer.inst.trackStatsMap[track.path] = TrackStats(track.path, track.stats.rating, track.stats.tags, track.stats.moods, positionToSave);
    track.stats.lastPositionInMs = positionToSave;
    await Indexer.inst.saveTrackStatsFileToStorage();
  }

  Future<void> tryRestoringLastPosition(Track track) async {
    final minValueInSet = Duration(minutes: SettingsController.inst.minTrackDurationToRestoreLastPosInMinutes.value).inMilliseconds;

    if (minValueInSet > 0) {
      final lastPos = track.stats.lastPositionInMs;
      if (lastPos != 0 && track.duration >= minValueInSet) {
        await seek(lastPos.milliseconds);
      }
    }
  }

  void startSleepAfterMinCount(Track track) async {
    Timer.periodic(const Duration(minutes: 1), (timer) async {
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
      nowPlayingTrack.listen((p0) {
        if (track != p0) {
          timer.cancel();
          return;
        }
      });
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
    Timer.periodic(Duration(milliseconds: interval), (timer) {
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
    Timer.periodic(Duration(milliseconds: interval), (timer) {
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
    final q = currentQueue.toSet().toList();
    final ct = nowPlayingTrack.value;
    final diff = currentQueue.length - q.length;
    q.remove(nowPlayingTrack.value);
    q.insert((currentIndex.value - diff).clamp(0, currentQueue.length - diff), ct);
    currentQueue.assignAll(q);
    final index = currentQueue.indexOf(ct);
    currentIndex.value = index;
    CurrentColor.inst.updatePlayerColor(ct, index);
  }

  void addToQueue(List<Track> tracks, {bool insertNext = false, bool insertAfterLatest = false}) {
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

  void removeRangeFromQueue(int start, int end) {
    currentQueue.removeRange(start, end);
    afterQueueChange();
  }

  void afterQueueChange() {
    tryResettingLatestInsertedIndex();
    updateCurrentMediaItem();
    QueueController.inst.updateLatestQueue(currentQueue.toList());
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
    await _player.seek(p.milliseconds);
    await VideoController.inst.seek(p.milliseconds);
  }

  @override
  Future<void> stop() async => await _player.stop();

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

extension MediaItemsListToAudioSources on List<MediaItem> {
  List<AudioSource> get toAudioSources => map((e) => e.toAudioSource).toList();
}

extension TrackToAudioSourceMediaItem on Track {
  UriAudioSource toAudioSource() {
    return AudioSource.uri(
      Uri.parse(path),
      tag: toMediaItem,
    );
  }

  MediaItem toMediaItem() => MediaItem(
        id: path,
        title: title,
        displayTitle: title,
        displaySubtitle: hasUnknownAlbum ? originalArtist : "$originalArtist - $album",
        displayDescription: "${Player.inst.currentIndex.value + 1}/${Player.inst.currentQueue.length}",
        artist: originalArtist,
        album: album,
        genre: genresList.take(3).join(', '),
        duration: Duration(milliseconds: duration),
        artUri: Uri.file(File(pathToImage).existsSync() ? pathToImage : k_FILE_PATH_NAMIDA_LOGO),
      );
}

extension TracksListToAudioSourcesMediaItems on List<Track> {
  List<AudioSource> toAudioSources() => map((e) => e.toAudioSource()).toList();
  List<MediaItem> toMediaItems() => map((e) => e.toMediaItem()).toList();
  ConcatenatingAudioSource get toConcatenatingAudioSource => ConcatenatingAudioSource(
        useLazyPreparation: true,
        shuffleOrder: DefaultShuffleOrder(),
        children: map((e) => e.toAudioSource()).toList(),
      );
}
