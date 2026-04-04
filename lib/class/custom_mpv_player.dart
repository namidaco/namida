import 'dart:async';

import 'package:basic_audio_handler/basic_audio_handler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart';

import 'package:namida/core/extensions.dart';

class CustomMPVPlayer implements AVPlayer {
  CustomMPVPlayer({bool disableVideo = false}) {
    if (!disableVideo) _videoController;
    _playerHeightStreamSub = _player.stream.height.listen((event) {
      final resolved = _dimensionResolver(event, null);
      if (resolved != null) _videoControllerListener(height: resolved);
    });
    _playerWidthStreamSub = _player.stream.width.listen((event) {
      final resolved = _dimensionResolver(event, null);
      if (resolved != null) _videoControllerListener(width: resolved);
    });

    _playerCompletedStreamSub = _player.stream.completed.listen((event) {
      if (event) {
        _processingState = ProcessingState.completed;
        _updateProcessingState();
      }
    });

    _playerBufferingStreamSub = _player.stream.buffering.listen((event) {
      if (event) {
        _processingState = ProcessingState.buffering;
      } else {
        _processingState = ProcessingState.ready;
      }
      _updateProcessingState();
    });

    _playerPositionStreamSub = _player.stream.position.listen((p) {
      if (_processingState != ProcessingState.completed) {
        if (p < Duration.zero) p = Duration.zero;
        _position = p;
        _updatePosition();
      }
    });

    _playerAudioTracksStreamSub = _player.stream.tracks.listen((tracks) {
      _updateAudioTracks(_toAudioTracks(tracks.audio));
    });
  }

  ProcessingState _processingState = ProcessingState.idle;
  Duration _position = Duration.zero;

  final _player = mk.Player(configuration: mk.PlayerConfiguration(pitch: true, bufferSize: 64 * 1024 * 1024));
  VideoController? _videoControllerRaw;
  VideoController get _videoController {
    return _videoControllerRaw ??= _createVideoControllerAndListen();
  }

  VideoController _createVideoControllerAndListen() {
    final c = VideoController(_player);
    c.id.addListener(_videoControllerListener);
    c.rect.addListener(_videoControllerListener);
    return c;
  }

  UriSource? _audioSource;
  VideoSourceOptions? _videoOptions;
  bool _disposed = false;

  StreamSubscription? _playerHeightStreamSub;
  StreamSubscription? _playerWidthStreamSub;

  StreamSubscription? _playerCompletedStreamSub;
  StreamSubscription? _playerBufferingStreamSub;
  StreamSubscription? _playerPositionStreamSub;
  StreamSubscription? _playerAudioTracksStreamSub;
  final _playerProcessingStateStreamController = StreamController<ProcessingState>();
  final _playerPositionStreamController = StreamController<Duration>();

  final _audioTracksStreamController = StreamController<List<AudioTrack>>();

  final _videoInfoStreamController = StreamController<_VideoDetails>();
  // _VideoDetails? _videoInfo;

  int? _dimensionResolver(num? v1, num? v2) {
    if (v1 != null && v1 > 0) return v1.toInt();
    if (v2 != null && v2 > 0) return v2.toInt();
    return null;
  }

  void _updateVideoInfo(_VideoDetails newInfo) {
    // -- we are not the one to decide not to tell about new data,
    // -- the main info can be set to null, and not broadcasting (even the same previous info) can cause the main info
    // -- to stay in null state. it's a common scenario as usually the texture id is reused.
    // if (_videoInfo == newInfo) return; // ALWAYS BROADCAST
    // _videoInfo = newInfo;

    _videoInfoStreamController.add(newInfo);
  }

  void _videoControllerListener({int? width, int? height}) {
    if (_videoOptions == null) {
      _updateVideoInfo(const _VideoDetails.dummy());
      return;
    }

    final data = _videoController.notifier.value;

    int? textureId = _videoController.id.value ?? data?.id.value;

    width ??= _player.state.width ?? _dimensionResolver(_videoController.rect.value?.width, data?.rect.value?.width);
    height ??= _player.state.height ?? _dimensionResolver(_videoController.rect.value?.height, data?.rect.value?.height);

    if (!(width != null && width > 0 && height != null && height > 0)) {
      // both should be there, otherwise the player will start tweaking

      height = null;
      width = null;
      textureId = null; // we aint ready fr
    }

    final newInfo = _VideoDetails(
      textureId: textureId ?? -1,
      width: width ?? -1,
      height: height ?? -1,
    );

    _updateVideoInfo(newInfo);
  }

  void _updateProcessingState() {
    _playerProcessingStateStreamController.add(_processingState);
  }

  void _updatePosition() {
    _playerPositionStreamController.add(_position);
  }

  void _updateAudioTracks([List<AudioTrack>? tracks]) {
    _audioTracksStreamController.add(tracks ?? _getPlayerCurrentAudioTracksConverted());
  }

  @override
  Stream<PlaybackEvent> get playbackEventStream => Stream.empty();

  @override
  Stream<List<AudioTrack>?> get audioTracksStream => _audioTracksStreamController.stream;

  @override
  Stream<VideoInfoData> get videoInfoStream => _videoInfoStreamController.stream.map(
    (event) => VideoInfoData(
      id: '',
      textureId: event.textureId,
      width: event.width,
      height: event.height,
      frameRate: -1,
      bitrate: -1,
      sampleRate: -1,
      encoderDelay: -1,
      rotationDegrees: -1,
      containerMimeType: '',
      label: '',
      language: '',
    ),
  );

  @override
  Stream<Duration> get bufferedPositionStream => _player.stream.buffer;
  @override
  Stream<ProcessingState> get processingStateStream => _playerProcessingStateStreamController.stream.distinct();

  @override
  Stream<Duration> get positionStream => _playerPositionStreamController.stream;
  @override
  Stream<Duration?> get durationStream => _player.stream.duration;
  @override
  Stream<double> get volumeStream => _player.stream.volume.map((event) => event / 100);
  @override
  Stream<double> get speedStream => _player.stream.rate;
  @override
  Stream<double> get pitchStream => _player.stream.pitch;
  @override
  Stream<bool> get playingStream => _player.stream.playing;

  @override
  int? get androidAudioSessionId => null;
  @override
  ProcessingState get processingState => _processingState;
  @override
  Duration get bufferedPosition => _player.state.buffer;
  @override
  Duration get position => _position;
  @override
  Duration? get duration => _player.state.duration;
  @override
  double get volume => _player.state.volume / 100;
  @override
  double get speed => _player.state.rate;
  @override
  double get pitch => _player.state.pitch;
  @override
  bool get playing => _player.state.playing;

  @override
  UriSource? get audioSource => _audioSource;
  @override
  bool get isDisposed => _disposed;

  @override
  Future<Duration?> setSource<T>(ItemPrepareConfig<T, UriSource> config) async {
    _audioSource = config.source;
    if (config.keepOldVideoSource == false) _videoOptions = config.videoOptions;

    final durationFuture = _player.stream.duration.firstWhere(
      (e) => e > Duration.zero,
      orElse: () => Duration.zero,
    );

    final videoOptions = _videoOptions;
    if (videoOptions == null) {
      await _tryOpen(
        mk.Media(
          config.source.uri.toString(),
          start: config.initialPosition,
        ),
      );
    } else if (videoOptions.videoOnly) {
      await _tryOpen(
        mk.Media(
          (videoOptions.source as UriSource).uri.toString(),
          start: config.initialPosition,
        ),
      );
    } else {
      final mainMedia = mk.Media(
        config.source.uri.toString(),
        start: config.initialPosition,
      );

      await _tryOpen(mainMedia).then((_) async {
        final videoTrack = mk.VideoTrack((videoOptions.source as UriSource).uri.toString(), null, null);
        await _setVideoTrack(videoTrack);
        _updateAudioTracks();
      });
    }

    if (_checkIsSourceLive(config.source) || _checkIsSourceLive(config.videoOptions?.source)) {
      // -- not waiting for duration
      return null;
    }

    final audioTrackId = config.audioTrackId;
    if (audioTrackId != null) {
      setAudioTrack(audioTrackId);
    }

    return await durationFuture;
  }

  mk.Playable? _playableOpening;
  Future<void> _tryOpen(mk.Playable playable, {bool play = false}) async {
    _playableOpening = playable;

    try {
      await _player.open(playable, play: play);
    } catch (_) {
      await Future.delayed(const Duration(seconds: 3));
      if (identical(playable, _playableOpening)) {
        await _player.open(playable, play: play);
      }
    }
  }

  bool _checkIsSourceLive(AudioVideoSource? source) => source is HlsSource || source is DashSource;

  @override
  Future<void> setVideo(VideoSourceOptions? video) async {
    if (_audioSource != null) {
      await setSource(
        ItemPrepareConfig(
          _audioSource!,
          index: 0, // -- not used
          videoOptions: video,
          initialPosition: position,
          audioTrackId: null,
          keepOldVideoSource: false,
        ),
      );
    } else {
      _videoOptions = video;
    }
    _videoControllerListener();
  }

  // -- attempts to avoid flashing of previous video, but doesn't work.
  // mk.VideoTrack? _latestSetVideoTrack;
  // Future<void> _disposePreviouslySetVideoTrack() async {
  //   if (_latestSetVideoTrack != null) {
  //     try {
  //       final player = _player.platform as mk.NativePlayer;
  //       await player.command(['video-remove', '1']);
  //       await player.command(['set', 'vid', 'no']);
  //     } catch (_) {}
  //     _latestSetVideoTrack = null;
  //   }
  // }

  // modified version of setAudioTrack
  // source: package:media_kit/src/player/native/player/real.dart
  Future<void> _setVideoTrack(mk.VideoTrack videoTrack, {bool synchronized = true}) async {
    final player = _player.platform as mk.NativePlayer;
    Future<void> function() async {
      if (player.disposed) {
        throw AssertionError('[Player] has been disposed');
      }

      await player.waitForPlayerInitialization;
      await player.waitForVideoControllerInitializationIfAttached;

      await player.command(
        [
          'video-add',
          videoTrack.id,
          'select',
          videoTrack.title ?? 'external',
          videoTrack.language ?? 'auto',
        ],
      );
      player.state = player.state.copyWith(
        track: player.state.track.copyWith(
          video: videoTrack,
        ),
        // -- not really needed
        // tracks: mk.Tracks(
        //   video: [
        //     ...player.state.tracks.video,
        //     videoTrack,
        //   ],
        // ),
      );
      // ignore: invalid_use_of_protected_member
      if (!player.trackController.isClosed) player.trackController.add(player.state.track);
      // ignore: invalid_use_of_protected_member
      // if (!player.tracksController.isClosed) player.tracksController.add(player.state.tracks);
    }

    if (synchronized) {
      return lock.synchronized(function);
    } else {
      return function();
    }
  }

  List<mk.AudioTrack> _getPlayerCurrentAudioTracks() => _player.state.tracks.audio;
  List<AudioTrack> _getPlayerCurrentAudioTracksConverted() => _toAudioTracks(_getPlayerCurrentAudioTracks());
  bool _isAudioTrackDummy(mk.AudioTrack track) => track == mk.AudioTrack.auto() || track == mk.AudioTrack.no();
  List<AudioTrack> _toAudioTracks(List<mk.AudioTrack> tracks) {
    final audioTracks = <AudioTrack>[];
    final playerAudioTrack = _player.state.track.audio;
    for (var i = 0; i < tracks.length; i++) {
      final track = tracks[i];
      if (_isAudioTrackDummy(track)) continue;
      final selected = _isAudioTrackDummy(playerAudioTrack) ? track.isDefault : playerAudioTrack.id == track.id;
      audioTracks.add(
        AudioTrack(
          groupIndex: 0,
          trackIndex: i,
          isSelected: selected ?? false,
          id: track.id,
          label: track.title,
          language: track.language,
          bitrate: track.bitrate,
          channelCount: track.channelscount,
          mimeType: track.codec,
          sampleRate: track.samplerate,
        ),
      );
    }
    return audioTracks;
  }

  @override
  Future<void> setAudioTrack(String? trackId) async {
    if (trackId == null) {
      await _player.setAudioTrack(mk.AudioTrack.auto());
      _updateAudioTracks();
      return;
    }
    final track = _getPlayerCurrentAudioTracks().firstWhereEff((t) => t.id == trackId);
    await _player.setAudioTrack(track ?? mk.AudioTrack.auto());
    _updateAudioTracks();
  }

  @override
  Future<void> play() {
    return _player.play();
  }

  @override
  Future<void> pause() {
    return _player.pause();
  }

  @override
  Future<void> seek(Duration? position) async {
    if (_videoOptions?.loop == true) return;
    return _player.seek(position ?? Duration.zero);
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    return _player.pause(); // _player.stop too powerful
  }

  @override
  Future<void> freePlayer() async {
    return stop();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    await [
      _playerHeightStreamSub?.cancel(),
      _playerWidthStreamSub?.cancel(),
      _playerCompletedStreamSub?.cancel(),
      _playerBufferingStreamSub?.cancel(),
      _playerPositionStreamSub?.cancel(),
      _playerAudioTracksStreamSub?.cancel(),
      _videoInfoStreamController.close(),
      _playerProcessingStateStreamController.close(),
      _playerPositionStreamController.close(),
      _audioTracksStreamController.close(),
    ].execute();

    _videoControllerRaw?.id.removeListener(_videoControllerListener);
    _videoControllerRaw?.rect.removeListener(_videoControllerListener);

    return _player.dispose();
  }

  @override
  Future<void> setSkipSilenceEnabled(bool enabled) async {
    // await (_player.platform as NativePlayer).setProperty();
  }

  @override
  Future<void> setVolume(double volume) {
    return _player.setVolume(volume * 100);
  }

  @override
  Future<void> setPitch(double pitch) {
    return _player.setPitch(pitch);
  }

  @override
  Future<void> setSpeed(double speed) {
    return _player.setRate(speed);
  }

  @override
  Future<void> addMediaNext<T>(ItemPrepareConfig<T, UriSource> config) async {
    final pl = _player;
    final currentIndex = pl.state.playlist.index;
    final insertIndex = currentIndex + 1;

    final media = mk.Media(
      config.source.uri.toString(),
      start: config.initialPosition,
    );

    // -- no `insert`, so we add and move
    await pl.add(media);
    final addedIndex = pl.state.playlist.medias.length - 1;
    if (addedIndex != insertIndex) {
      await pl.move(addedIndex, insertIndex);
    }

    // -- removing tail
    final length = pl.state.playlist.medias.length;
    if (length > insertIndex + 1) {
      for (int i = length - 1; i > insertIndex; i--) {
        await pl.remove(i);
      }
    }

    // -- removing head after tail
    if (insertIndex > 1) {
      for (int i = insertIndex - 2; i >= 0; i--) {
        await pl.remove(i);
      }
    }
  }

  @override
  Future<void> removeAllMediaNext() async {}

  // Features missing: skip silence, looping animations, equalizer, equalizer presets, loudness enhancer
  // quick settings tile, picture in picture
  // `isPlaying()`, `hasVideo()`, `getVideoRational()`.
}

class _VideoDetails {
  final int width, height;
  final int textureId;

  const _VideoDetails({
    required this.width,
    required this.height,
    required this.textureId,
  });

  const _VideoDetails.dummy() : width = -1, height = -1, textureId = -1;

  @override
  int get hashCode => width ^ height ^ textureId;

  @override
  bool operator ==(Object other) {
    return other is _VideoDetails && height == other.height && width == other.width && textureId == other.textureId;
  }

  @override
  String toString() => '_VideoDetails(width: $width, height: $height, textureId: $textureId)';
}
