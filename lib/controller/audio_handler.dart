import 'dart:async';

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
import 'package:namida/core/extensions.dart';

class NamidaAudioVideoHandler extends BaseAudioHandler with SeekHandler, QueueHandler {
  final _player = AudioPlayer();
  final _playlist = ConcatenatingAudioSource(children: []);

  final Player namidaPlayer;

  RxList<Track> get currentQueue => namidaPlayer.currentQueue;
  Rx<Track> get nowPlayingTrack => namidaPlayer.nowPlayingTrack;
  RxInt get nowPlayingPosition => namidaPlayer.nowPlayingPosition;
  RxInt get currentIndex => namidaPlayer.currentIndex;
  RxDouble get currentVolume => namidaPlayer.currentVolume;
  RxBool get isPlaying => namidaPlayer.isPlaying;

  NamidaAudioVideoHandler(this.namidaPlayer) {
    _player.playbackEventStream.listen((event) {
      playbackState.add(_transformEvent(event));
    });

    _player.playbackEventStream.listen((event) {
      QueueController.inst.updateLatestQueue(currentQueue.toList());
    });

    _player.processingStateStream.listen((state) async {
      if (state == ProcessingState.completed) {
        await _player.pause();
        await _player.seek(const Duration(microseconds: 0), index: 0);
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

    _player.currentIndexStream.listen((i) async {
      i ??= 0;
      currentIndex.value = i;
    });

    currentIndex.listen((i) {
      if (currentQueue.isNotEmpty && shouldUpdateIndex) {
        final tr = currentQueue.elementAt(i);
        updateCurrentMediaItem(tr);
        nowPlayingTrack.value = tr;
      }
    });

    nowPlayingTrack.listen((tr) {
      updateAllTrackListeners(tr);
    });
  }

  /// for ensuring stabilty when calling [setAudioSource].
  bool shouldUpdateIndex = true;

  /// for ensuring stabilty while fade effect is on.
  bool wantToPause = false;

  void updateAllTrackListeners(Track tr) {
    CurrentColor.inst.updatePlayerColor(tr, currentIndex.value);
    WaveformController.inst.generateWaveform(tr);
    PlaylistController.inst.addToHistory(nowPlayingTrack.value);
    increaseListenTime(tr);
    SettingsController.inst.save(lastPlayedTrackPath: tr.path);
    Lyrics.inst.updateLyrics(tr);

    /// for video
    if (SettingsController.inst.enableVideoPlayback.value) {
      VideoController.inst.updateLocalVidPath(tr);
    }
    updateVideoPlayingState();
  }

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

  ///
  /// Video Methods
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

  /// End of Video Methods.
  ///

  ///
  /// Namida Methods.
  Future<void> setAudioSource(
    List<Track> tracks,
    Track track, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    shouldUpdateIndex = false;
    await _player.setAudioSource(tracks.toConcatenatingAudioSource, preload: preload, initialIndex: initialIndex, initialPosition: initialPosition);

    final children = tracks.toAudioSources;
    currentQueue.assignAll(tracks);
    queue.value.assignAll(tracks.toMediaItems);
    await _playlist.clear();
    await _playlist.addAll(children);
    CurrentColor.inst.updatePlayerColor(track, currentIndex.value);
    updateCurrentMediaItem(track);
    nowPlayingTrack.value = track;
    currentIndex.value = currentQueue.indexOf(track);
    shouldUpdateIndex = true;
  }

  /// if [force] is enabled, [track] will not be used.
  void updateCurrentMediaItem([Track? track, bool force = false]) {
    if (force) {
      playbackState.add(_transformEvent(PlaybackEvent()));
      return;
    }
    track ??= nowPlayingTrack.value;
    mediaItem.add(track.toMediaItem);
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
    final interval = (0.1 * duration).toInt();
    final steps = duration ~/ interval;
    double vol = 0.0;
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
    final interval = (0.1 * duration).toInt();
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
    setVolume(currentVolume.value);
  }

  Future<void> addToQueue(List<Track> tracks, {bool insertNext = false}) async {
    final source = _player.audioSource as ConcatenatingAudioSource;
    final children = tracks.toAudioSources;

    if (insertNext) {
      insertInQueue(tracks, currentIndex.value + 1);
    } else {
      currentQueue.addAll(tracks);
      queue.value.addAll(tracks.toMediaItems);
      await _playlist.addAll(children);
      await source.addAll(children);
    }
    updateCurrentMediaItem();
    QueueController.inst.updateLatestQueue(currentQueue.toList());
  }

  Future<void> insertInQueue(List<Track> tracks, int index) async {
    final source = _player.audioSource as ConcatenatingAudioSource;
    currentQueue.insertAll(index, tracks);
    queue.value.insertAll(index, tracks.toMediaItems);
    await _playlist.insertAll(index, tracks.toAudioSources);
    await source.insertAll(index, tracks.toAudioSources);

    updateCurrentMediaItem();
    QueueController.inst.updateLatestQueue(currentQueue.toList());
  }

  Future<void> removeFromQueue(int index) async {
    final source = _player.audioSource as ConcatenatingAudioSource;
    currentQueue.removeAt(index);
    queue.value.removeAt(index);
    await _playlist.removeAt(index);
    await source.removeAt(index);
    updateCurrentMediaItem();
    QueueController.inst.updateLatestQueue(currentQueue.toList());
  }

  Future<void> removeRangeFromQueue(int start, int end) async {
    final source = _player.audioSource as ConcatenatingAudioSource;
    currentQueue.removeRange(start, end);
    queue.value.removeRange(start, end);
    await _playlist.removeRange(start, end);
    await source.removeRange(start, end);
    updateCurrentMediaItem();
    QueueController.inst.updateLatestQueue(currentQueue.toList());
  }

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
  }

  /// End of Namida Methods.
  ///

  ///
  /// audio_service overriden methods.
  @override
  Future<void> play() async {
    wantToPause = false;
    if (SettingsController.inst.enableVolumeFadeOnPlayPause.value && nowPlayingPosition.value > 10) {
      await playWithFadeEffect();
    } else {
      _player.play();
    }
    setVolume(SettingsController.inst.playerVolume.value);
  }

  @override
  Future<void> pause() async {
    wantToPause = true;
    if (SettingsController.inst.enableVolumeFadeOnPlayPause.value && nowPlayingPosition.value > 10) {
      await pauseWithFadeEffect();
    } else {
      _player.pause();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    VideoController.inst.seek(position);
  }

  @override
  Future<void> stop() async => await _player.stop();

  @override
  Future<void> skipToNext() async {
    if (_player.hasNext) {
      await _player.seekToNext();
    } else {
      skipToQueueItem(0);
    }
    await _player.play();
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.hasPrevious) {
      await _player.seekToPrevious();
    } else {
      skipToQueueItem(currentQueue.length - 1);
    }
    await _player.play();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    await _player.seek(const Duration(microseconds: 0), index: index);
    _player.play();
    currentIndex.value = index;
    setVolume(SettingsController.inst.playerVolume.value);
  }

  /// End of  audio_service overriden methods.
  ///

  ///
  /// Media Control Specific
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
      fmc.insert(0, Player.inst.nowPlayingTrack.value.isFavourite ? MediaControl.fastForward : MediaControl.rewind);
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
  UriAudioSource get toAudioSource {
    return AudioSource.uri(
      Uri.parse(path),
      tag: toMediaItem,
    );
  }

  MediaItem get toMediaItem => MediaItem(
        id: path,
        title: title,
        displayTitle: title,
        displaySubtitle: "${artistsList.take(3).join(', ')} - $album",
        displayDescription: "${Player.inst.currentIndex.value + 1}/${Player.inst.currentQueue.length}",
        artist: artistsList.take(3).join(', '),
        album: album,
        genre: genresList.take(3).join(', '),
        duration: Duration(milliseconds: duration),
        artUri: Uri.file(pathToImage),
      );
}

extension TracksListToAudioSourcesMediaItems on List<Track> {
  List<AudioSource> get toAudioSources => map((e) => e.toAudioSource).toList();
  List<MediaItem> get toMediaItems => map((e) => e.toMediaItem).toList();
  ConcatenatingAudioSource get toConcatenatingAudioSource => ConcatenatingAudioSource(
        useLazyPreparation: true,
        shuffleOrder: DefaultShuffleOrder(),
        children: map((e) => e.toAudioSource).toList(),
      );
}
