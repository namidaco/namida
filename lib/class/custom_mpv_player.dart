import 'dart:async';

import 'package:basic_audio_handler/basic_audio_handler.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:just_audio/just_audio.dart';
import 'package:namida/core/extensions.dart';

class CustomMPVPlayer implements AVPlayer {
  static final currentVideoController = ValueNotifier<VideoController?>(null);

  CustomMPVPlayer() {
    currentVideoController.value = _videoController;

    _playerHeightStreamSub = _player.stream.height.listen((event) {
      final resolved = _dimensionResolver(event, null);
      if (resolved != null) _videoControllerListener(height: resolved);
    });
    _playerWidthStreamSub = _player.stream.width.listen((event) {
      final resolved = _dimensionResolver(event, null);
      if (resolved != null) _videoControllerListener(width: resolved);
    });

    _videoController.id.addListener(_videoControllerListener);
    _videoController.rect.addListener(_videoControllerListener);
  }

  final _player = Player();
  late final _videoController = VideoController(_player);

  UriSource? _audioSource;
  VideoSourceOptions? _videoOptions;
  bool _disposed = false;

  StreamSubscription? _playerHeightStreamSub;
  StreamSubscription? _playerWidthStreamSub;

  final _videoInfoStreamController = StreamController<_VideoDetails>();
  _VideoDetails? _videoInfo;

  int? _dimensionResolver(num? v1, num? v2) {
    if (v1 != null && v1 > 0) return v1.toInt();
    if (v2 != null && v2 > 0) return v2.toInt();
    return null;
  }

  void _updateVideoInfo(_VideoDetails newInfo) {
    if (_videoInfo == newInfo) return;
    _videoInfo = newInfo;
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
  Stream<ProcessingState> get processingStateStream => Stream.value(ProcessingState.ready);

  @override
  Stream<Duration> get positionStream => _player.stream.position;
  @override
  Stream<Duration?> get durationStream => _player.stream.duration;
  @override
  Stream<double> get volumeStream => _player.stream.volume;

  @override
  Stream<double> get speedStream => _player.stream.rate;

  @override
  Stream<double> get pitchStream => _player.stream.pitch;

  @override
  Stream<bool> get playingStream => _player.stream.playing;

  @override
  int? get androidAudioSessionId => null;
  @override
  ProcessingState get processingState => ProcessingState.ready;
  @override
  Duration get bufferedPosition => _player.state.buffer;
  @override
  Duration get position => _player.state.position;
  @override
  Duration? get duration => _player.state.duration;
  @override
  double get volume => _player.state.volume;
  @override
  double get speed => _player.state.rate;
  @override
  double get pitch => _player.state.pitch;

  @override
  AudioVideoSource? get audioSource => _audioSource;
  @override
  bool get isDisposed => _disposed;

  @override
  Future<Duration?> setSource(
    UriSource source, {
    bool preload = true,
    Duration? initialPosition,
    VideoSourceOptions? videoOptions,
    bool keepOldVideoSource = false,
  }) async {
    _audioSource = source;
    if (keepOldVideoSource == false) _videoOptions = videoOptions;

    if (_videoOptions == null) {
      _player.open(
        Media(
          source.uri.toString(),
          start: initialPosition,
        ),
        play: false,
      );
    } else {
      final mainMedia = Media(
        (_videoOptions!.source as UriSource).uri.toString(),
        start: initialPosition,
      );
      final audioTrack = AudioTrack.uri(source.uri.toString());
      _player.open(mainMedia, play: false).then((_) {
        _player.setAudioTrack(audioTrack);
      });
    }

    final duration = _player.stream.duration.firstWhere((element) => element > Duration.zero);
    return duration;
  }

  @override
  Future<void> setVideo(VideoSourceOptions? video) async {
    if (_audioSource != null) {
      await setSource(
        _audioSource!,
        videoOptions: video,
        initialPosition: position,
        keepOldVideoSource: false,
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
  Future<void> seek(Duration? position) {
    return _player.seek(position ?? Duration.zero);
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    return _player.stop();
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
      _videoInfoStreamController.close(),
    ].execute();

    _videoController.id.removeListener(_videoControllerListener);
    _videoController.rect.removeListener(_videoControllerListener);

    return _player.dispose();
  }

  @override
  Future<void> setSkipSilenceEnabled(bool enabled) async {
    // await (_player.platform as dynamic).setProperty();
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
}
