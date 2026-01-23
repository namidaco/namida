import 'dart:async';

import 'package:basic_audio_handler/basic_audio_handler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:media_kit/media_kit.dart';
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

    _playerCompletedStreamSub = _player.stream.completed.listen((event) => _updateProcessingState(completed: event));
    _playerBufferingStreamSub = _player.stream.buffering.listen((event) => _updateProcessingState(buffering: event));
  }

  final _player = Player(configuration: PlayerConfiguration(pitch: true));
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
  final _playerProcessingStateStreamController = StreamController<ProcessingState>();

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

  void _updateProcessingState({
    bool? completed,
    bool? buffering,
    bool? loading,
  }) {
    final newProcessingState = _getProcessingState(
      completed: completed,
      buffering: buffering,
      loading: loading,
    );
    _playerProcessingStateStreamController.add(newProcessingState);
  }

  ProcessingState _getProcessingState({
    bool? completed,
    bool? buffering,
    bool? loading,
  }) {
    ProcessingState processingState;
    if (buffering ?? _player.state.buffering) {
      processingState = ProcessingState.buffering;
    } else if (completed ?? _player.state.completed) {
      processingState = ProcessingState.completed;
    } else if (loading == true) {
      processingState = ProcessingState.loading;
    } else {
      processingState = ProcessingState.ready;
    }
    return processingState;
  }

  @override
  Stream<PlaybackEvent> get playbackEventStream => Stream.empty();

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
  Stream<Duration> get positionStream => _player.stream.position;
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
  ProcessingState get processingState => _getProcessingState();
  @override
  Duration get bufferedPosition => _player.state.buffer;
  @override
  Duration get position => _player.state.position;
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

    if (_videoOptions == null) {
      _player.open(
        Media(
          config.source.uri.toString(),
          start: config.initialPosition,
        ),
        play: false,
      );
    } else {
      final mainMedia = Media(
        (_videoOptions!.source as UriSource).uri.toString(),
        start: config.initialPosition,
      );
      final audioTrack = AudioTrack.uri(config.source.uri.toString());
      _player.open(mainMedia, play: false).then((_) {
        _player.setAudioTrack(audioTrack);
      });
    }

    if (_checkIsSourceLive(config.source) || _checkIsSourceLive(config.videoOptions?.source)) {
      // -- not waiting for duration
      return null;
    }

    final duration = _player.stream.duration.firstWhere((element) => element > Duration.zero);
    return duration;
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
          keepOldVideoSource: false,
        ),
      );
    } else {
      _videoOptions = video;
    }
    _videoControllerListener();
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
      _videoInfoStreamController.close(),
      _playerProcessingStateStreamController.close(),
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
  Future<void> addMediaNext<T>(ItemPrepareConfig<T, UriSource> config) async {}
  @override
  Future<void> removeAllMediaNext() async {}

  // Features missing: skip silence, looping animations, gapless, equalizer, equalizer presets, loudness enhancer
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

  const _VideoDetails.dummy()
      : width = -1,
        height = -1,
        textureId = -1;

  @override
  int get hashCode => width ^ height ^ textureId;

  @override
  bool operator ==(Object other) {
    return other is _VideoDetails && height == other.height && width == other.width && textureId == other.textureId;
  }

  @override
  String toString() => '_VideoDetails(width: $width, height: $height, textureId: $textureId)';
}
