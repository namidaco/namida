import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:basic_audio_handler/basic_audio_handler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart';

import 'package:namida/core/extensions.dart';

// Missing features: quick settings tile, picture in picture
// `isPlaying()`, `hasVideo()`, `getVideoRational()`.
class CustomMPVPlayer implements AVPlayer {
  // features: skip silence, looping animations, equalizer, equalizer presets, loudness enhancer
  // by claude
  static const _enableExperimentalFeatures = true;

  CustomMPVPlayer({bool disableVideo = false}) {
    if (!disableVideo) _videoController;
    // -- subtitles are only ever selected through [setTextTrack]/[setExternalSubtitle],
    // -- sidecar files are discovered by us so mpv must not auto load them.
    _setMpvProperty('sid', 'no');
    _setMpvProperty('sub-auto', 'no');
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
      } else if (_processingState == ProcessingState.completed) {
        _processingState = _player.state.buffering ? ProcessingState.buffering : ProcessingState.ready;
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
      _updateTextTracks(_toTextTracks(tracks.subtitle));
    });

    _playerLogStreamSub = _player.stream.log.listen((log) {
      final missingFilter = _MPVMissingFilters.register(log.text);
      if (missingFilter == null) return;
      _audioFilters.onMissingFilter(missingFilter);
    });
  }

  ProcessingState _processingState = ProcessingState.idle;
  Duration _position = Duration.zero;

  final _player = mk.Player(configuration: mk.PlayerConfiguration(pitch: true, libass: true, bufferSize: 64 * 1024 * 1024));
  late final _audioFilters = _MPVAudioFilters(_player);
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
  StreamSubscription? _playerLogStreamSub;
  final _playerProcessingStateStreamController = StreamController<ProcessingState>();
  final _playerPositionStreamController = StreamController<Duration>();

  final _audioTracksStreamController = StreamController<List<AudioTrack>>();
  final _textTracksStreamController = StreamController<List<TextTrack>?>();

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

  void _updateTextTracks([List<TextTrack>? tracks]) {
    _textTracksStreamController.add(tracks ?? _toTextTracks(_player.state.tracks.subtitle));
  }

  @override
  Stream<PlaybackEvent> get playbackEventStream => Stream.empty();

  @override
  Stream<List<AudioTrack>?> get audioTracksStream => _audioTracksStreamController.stream;

  @override
  Stream<List<TextTrack>?> get textTracksStream => _textTracksStreamController.stream;

  /// mpv draws the subtitles itself, so their text is never reported back.
  @override
  Stream<String?> get subtitleTextStream => const Stream.empty();

  @override
  bool get rendersSubtitlesInternally => true;

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
  Stream<double> get volumeStream => _player.stream.volume.map((event) => event / 100 / _loudnessMultiplier);
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
  double get volume => _volume;
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
  bool get hasVideoOptions => _videoOptions != null;

  static const _durationWaitTimeout = Duration(seconds: 10);

  @override
  Future<Duration?> setSource<T>(ItemPrepareConfig<T, UriSource> config) async {
    _audioSource = config.source;
    if (config.keepOldVideoSource == false) _videoOptions = config.videoOptions;

    _processingState = ProcessingState.loading;
    _updateProcessingState();

    await _prepareSubtitlesForNewSource();

    final durationCompleter = Completer<Duration?>();
    StreamSubscription? durationSub;
    Timer? durationTimer;
    void completeDuration(Duration? duration) {
      if (durationCompleter.isCompleted) return;
      durationTimer?.cancel();
      durationSub?.cancel();
      durationCompleter.complete(duration);
    }

    durationSub = _player.stream.duration.listen(
      (e) {
        if (e > Duration.zero) completeDuration(e);
      },
      onError: (_) => completeDuration(null),
    );

    try {
      final videoOptions = _videoOptions;
      _loopingVideoApplied = false;

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
          final videoTrack = mk.VideoTrack(_resolveVideoTrackSource(videoOptions), null, null);
          await _setVideoTrack(videoTrack);
          _updateAudioTracks();
        });
      }
    } catch (_) {
      completeDuration(null);
      rethrow;
    }

    _restoreExternalSubtitle();

    if (_checkIsSourceLive(config.source) || _checkIsSourceLive(config.videoOptions?.source)) {
      // -- not waiting for duration
      completeDuration(null);
      return null;
    }

    final audioTrackId = config.audioTrackId;
    if (audioTrackId != null) {
      setAudioTrack(audioTrackId);
    }

    durationTimer = Timer(_durationWaitTimeout, () {
      final dur = _player.state.duration;
      completeDuration(dur > Duration.zero ? dur : null);
    });
    return await durationCompleter.future;
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

  // -- mpv can't loop a single external video track, so the animation is turned into an `edl://`
  // -- timeline that repeats it enough times to outlast the audio. it stays a normal track, so seeking still works.
  bool _loopingVideoApplied = false;

  static const _kMaxLoopingVideoRepeats = 1000;
  static const _kFallbackLoopingVideoDuration = Duration(minutes: 30);

  /// Returns the source to add as a video track, an `edl://` looping timeline when the animation asks for it.
  String _resolveVideoTrackSource(VideoSourceOptions videoOptions) {
    final source = videoOptions.source as UriSource;
    final loopingSource = _enableExperimentalFeatures && videoOptions.loop ? _buildLoopingVideoSource(source, videoOptions.durationMS) : null;
    _loopingVideoApplied = loopingSource != null;
    return loopingSource ?? source.uri.toString();
  }

  String? _buildLoopingVideoSource(UriSource source, int? sourceDurationMS) {
    if (sourceDurationMS == null || sourceDurationMS <= 0) return null;

    final audioDuration = _player.state.duration;
    final targetMS = (audioDuration > Duration.zero ? audioDuration : _kFallbackLoopingVideoDuration).inMilliseconds;

    final repeats = (targetMS / sourceDurationMS).ceil() + 1;
    if (repeats <= 1) return null;

    // -- byte length prefixed, that way the path needs no escaping at all
    final path = source.uri.isScheme('file') ? source.uri.toFilePath() : source.uri.toString();
    final segment = '%${utf8.encode(path).length}%$path';
    final repeatsClamped = repeats.clampInt(2, _kMaxLoopingVideoRepeats);
    final buffer = StringBuffer();
    buffer.write('edl://');
    for (int i = 0; i < repeatsClamped; i++) {
      buffer.write(segment);
      buffer.write(';');
    }
    return buffer.toString();
  }

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
    int index = 0;
    for (final track in tracks) {
      if (_isAudioTrackDummy(track)) continue;
      final selected = _isAudioTrackDummy(playerAudioTrack) ? track.isDefault : playerAudioTrack.id == track.id;
      audioTracks.add(
        AudioTrack(
          groupIndex: 0,
          trackIndex: index,
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
      index++;
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

  bool _isSubtitleTrackDummy(mk.SubtitleTrack track) => track == mk.SubtitleTrack.auto() || track == mk.SubtitleTrack.no();

  /// the embedded track wanted by the app.
  String? _wantedSubtitleTrackId;

  /// the external file wanted by the app, mpv drops external tracks on file change so it is re-added after opening.
  String? _wantedExternalSubtitle;

  /// mpv id of the external track added for [_wantedExternalSubtitle], hidden from the reported list.
  String? _externalSubtitleId;

  /// mpv keeps `sid` across files, a stale numeric id would select a random track of the next file.
  bool _sidIsNo = true;

  List<TextTrack> _toTextTracks(List<mk.SubtitleTrack> tracks) {
    final textTracks = <TextTrack>[];
    final selectedId = _wantedExternalSubtitle == null ? _wantedSubtitleTrackId : null;
    final externalId = _externalSubtitleId;
    int index = 0;
    for (final track in tracks) {
      if (_isSubtitleTrackDummy(track)) continue;
      if (track.id == externalId) continue;
      textTracks.add(
        TextTrack(
          groupIndex: 0,
          trackIndex: index,
          isSelected: track.id == selectedId,
          id: track.id,
          label: track.title,
          language: track.language,
          mimeType: track.codec,
        ),
      );
      index++;
    }
    return textTracks;
  }

  Future<void> _setMpvProperty(String name, String value) async {
    try {
      await (_player.platform as mk.NativePlayer).setProperty(name, value);
    } catch (_) {}
  }

  /// embedded selections never survive a new file, the external one is re-added after opening.
  Future<void> _prepareSubtitlesForNewSource() async {
    _wantedSubtitleTrackId = null;
    _externalSubtitleId = null;
    _textTracksStreamController.add(null);
    if (!_sidIsNo) await _setSubtitleNo();
  }

  Future<void> _setSubtitleNo() async {
    _sidIsNo = true;
    await _player.setSubtitleTrack(mk.SubtitleTrack.no());
  }

  Future<void> _removeExternalSubtitle() async {
    final id = _externalSubtitleId;
    if (id == null) return;
    _externalSubtitleId = null;
    try {
      await (_player.platform as mk.NativePlayer).command(['sub-remove', id]);
    } catch (_) {}
  }

  /// mpv reports nothing back for `sub-add`, but a loaded file always ends up as the selected
  /// external track. anything else means it couldn't be loaded, which is the case for srt/ass on
  /// builds with a stripped ffmpeg (windows), the embedded selection is dropped then so the caller
  /// can draw the file itself.
  Future<bool> _addExternalSubtitle(String uri) async {
    final player = _player.platform as mk.NativePlayer;
    _sidIsNo = false;
    await _player.setSubtitleTrack(mk.SubtitleTrack.uri(uri));

    String external = '';
    String sid = '';
    try {
      external = await player.getProperty('current-tracks/sub/external');
      sid = await player.getProperty('current-tracks/sub/id');
    } catch (_) {}

    if (external == 'yes' && sid.isNotEmpty) {
      _externalSubtitleId = sid;
      return true;
    }

    _wantedExternalSubtitle = null;
    await _setSubtitleNo();
    return false;
  }

  void _restoreExternalSubtitle() {
    final uri = _wantedExternalSubtitle;
    if (uri == null) return;
    _addExternalSubtitle(uri).then((_) => _updateTextTracks()).ignoreError();
  }

  @override
  Future<void> setTextTrack(String? trackId) async {
    _wantedSubtitleTrackId = trackId;
    _wantedExternalSubtitle = null;
    await _removeExternalSubtitle();

    if (trackId == null) {
      await _setSubtitleNo();
    } else {
      _sidIsNo = false;
      await _player.setSubtitleTrack(mk.SubtitleTrack(trackId, null, null));
    }
    _updateTextTracks();
  }

  @override
  Future<bool> setExternalSubtitle(String? uri) async {
    _wantedSubtitleTrackId = null;
    _wantedExternalSubtitle = uri;
    await _removeExternalSubtitle();

    bool loaded = false;
    if (uri == null) {
      await _setSubtitleNo();
    } else {
      loaded = await _addExternalSubtitle(uri);
    }
    _updateTextTracks();
    return loaded;
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
    // -- when the video is a non-looped external track, seeking past its end leaves a frozen frame.
    if (!_loopingVideoApplied && _videoOptions?.loop == true) return;
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
      _playerLogStreamSub?.cancel(),
      _videoInfoStreamController.close(),
      _playerProcessingStateStreamController.close(),
      _playerPositionStreamController.close(),
      _audioTracksStreamController.close(),
      _textTracksStreamController.close(),
    ].execute();

    _videoControllerRaw?.id.removeListener(_videoControllerListener);
    _videoControllerRaw?.rect.removeListener(_videoControllerListener);
    _audioFilters.dispose();

    return _player.dispose();
  }

  @override
  Future<void> setSkipSilenceEnabled(bool enabled) async {
    if (!_enableExperimentalFeatures) return;
    _audioFilters.setSkipSilenceEnabled(enabled);
  }

  @override
  Future<void> setEqualizerEnabled(bool enabled) async {
    _audioFilters.setEqualizerEnabled(enabled);
  }

  @override
  Future<void> setEqualizerBandGains(Map<double, double> gains) async {
    _audioFilters.setEqualizerBandGains(gains);
  }

  // -- the `volume` filter is absent from most mpv builds, mpv's own volume can go past 100% instead.
  bool _loudnessEnhancerEnabled = false;
  double _loudnessEnhancerGain = 0.0;
  double _loudnessMultiplier = 1.0;
  double _volume = 1.0;
  String? _originalVolumeMax;

  @override
  Future<void> setLoudnessEnhancerEnabled(bool enabled) async {
    if (_loudnessEnhancerEnabled == enabled) return;
    _loudnessEnhancerEnabled = enabled;
    await _refreshLoudnessMultiplier();
  }

  @override
  Future<void> setLoudnessEnhancerGain(double gainDb) async {
    if (_loudnessEnhancerGain == gainDb) return;
    _loudnessEnhancerGain = gainDb;
    if (_loudnessEnhancerEnabled) await _refreshLoudnessMultiplier();
  }

  Future<void> _refreshLoudnessMultiplier() async {
    final multiplier = _loudnessEnhancerEnabled && _loudnessEnhancerGain != 0.0 ? math.pow(10, _loudnessEnhancerGain / 20).toDouble() : 1.0;
    if (_loudnessMultiplier == multiplier) return;
    _loudnessMultiplier = multiplier;

    final player = _player.platform as mk.NativePlayer;
    if (multiplier > 1.0) {
      // -- mpv refuses anything above 130% by default, the original cap has to come back with us
      // -- otherwise it would keep uncapping volumes that aren't ours, like replay gain.
      if (_originalVolumeMax == null) {
        final currentMax = await player.getProperty(_kVolumeMaxProperty);
        if (currentMax.isNotEmpty) _originalVolumeMax = currentMax;
      }
      await player.setProperty(_kVolumeMaxProperty, '$_kBoostedVolumeMaxPercentage');
    } else if (_originalVolumeMax != null) {
      await player.setProperty(_kVolumeMaxProperty, _originalVolumeMax!);
      _originalVolumeMax = null;
    }
    await _applyVolume();
  }

  static const _kVolumeMaxProperty = 'volume-max';
  static const _kBoostedVolumeMaxPercentage = 1000;

  @override
  Future<void> setVolume(double volume) {
    _volume = volume;
    return _applyVolume();
  }

  Future<void> _applyVolume() {
    return _player.setVolume((_volume * _loudnessMultiplier * 100).clampDouble(0, _kBoostedVolumeMaxPercentage.toDouble()));
  }

  @override
  Future<void> setPitch(double pitch) async {
    await _player.setPitch(pitch);
    _audioFilters.refresh(); // -- media_kit overwrites the whole filter chain when pitch changes
  }

  @override
  Future<void> setSpeed(double speed) async {
    await _player.setRate(speed);
    _audioFilters.refresh(); // -- media_kit overwrites the whole filter chain when rate changes
  }

  @override
  Future<bool> addMediaNext<T>(ItemPrepareConfig<T, UriSource> config) async {
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
    return true;
  }

  @override
  Future<void> removeAllMediaNext() async {
    final pl = _player;
    final length = pl.state.playlist.medias.length;

    // -- only remove items strictly after the currently playing one,
    // -- otherwise we'd nuke playback if the player has already advanced to the queued next item.
    final removeFrom = pl.state.playlist.index + 1;
    for (int i = length - 1; i >= removeFrom; i--) {
      await pl.remove(i);
    }
  }
}

/// Filters missing from the mpv build in use, a single unknown filter takes the whole graph down with it.
/// media_kit ships a stripped ffmpeg, so what exists is only known once mpv complains about it.
// by claude
abstract class _MPVMissingFilters {
  static final _names = <String>{};
  static final _regex = RegExp("No such filter: '([^']+)'");

  static bool contains(String filter) => _names.contains(filter);

  /// Returns the filter name if this log reported one that wasn't known to be missing yet.
  static String? register(String logText) {
    final match = _regex.firstMatch(logText);
    if (match == null) return null;
    final name = match.group(1)!;
    return _names.add(name) ? name : null;
  }
}

/// Owns mpv's `af` chain entirely, media_kit overwrites the property whenever rate or pitch change,
/// so the scaletempo filter it relies on is rebuilt here along with our own filters.
class _MPVAudioFilters {
  _MPVAudioFilters(this._player);

  final mk.Player _player;

  static const _kEqualizerLabel = 'nmeq';
  static const _kSkipSilenceLabel = 'nmss';

  static const _kEqualizerFilterName = 'equalizer';
  static const _kSkipSilenceFilterName = 'silenceremove';
  static const _kSkipSilenceParams =
      'start_periods=1:start_duration=0.15:start_threshold=-50dB:start_silence=0.05'
      ':stop_periods=-1:stop_duration=0.15:stop_threshold=-50dB:stop_silence=0.05:detection=peak';

  /// Rebuilding the chain reinitializes the filters, dragging a slider would do it on every frame.
  static const _kApplyThrottleMS = 100;

  bool _skipSilenceEnabled = false;
  bool _equalizerEnabled = false;
  var _equalizerGains = <double, double>{}; // -- sorted by frequency

  Timer? _throttleTimer;
  final _sinceLastApply = Stopwatch();

  bool get _hasCustomFilters => _equalizerEnabled || _skipSilenceEnabled;

  /// media_kit already wrote a chain holding nothing but its own scaletempo filter, only ours need to be restored.
  void refresh() {
    if (_hasCustomFilters) _requestApply();
  }

  void setSkipSilenceEnabled(bool enabled) {
    if (_skipSilenceEnabled == enabled) return;
    _skipSilenceEnabled = enabled;
    _requestApply();
  }

  void setEqualizerEnabled(bool enabled) {
    if (_equalizerEnabled == enabled) return;
    _equalizerEnabled = enabled;
    _requestApply();
  }

  void setEqualizerBandGains(Map<double, double> gains) {
    final entries = gains.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    _equalizerGains = Map.fromEntries(entries);
    if (_equalizerEnabled) _requestApply();
  }

  void onMissingFilter(String filter) {
    if (filter != _kEqualizerFilterName && filter != _kSkipSilenceFilterName) return;
    if (_hasCustomFilters) _applyChain(); // -- the chain is down, restoring it without the missing filter
  }

  void dispose() {
    _throttleTimer?.cancel();
    _throttleTimer = null;
  }

  void _requestApply() {
    if (_throttleTimer != null) return; // -- a trailing apply is already scheduled

    final remaining = _sinceLastApply.isRunning ? _kApplyThrottleMS - _sinceLastApply.elapsedMilliseconds : 0;
    if (remaining <= 0) {
      _applyChain();
    } else {
      _throttleTimer = Timer(Duration(milliseconds: remaining), () {
        _throttleTimer = null;
        _applyChain();
      });
    }
  }

  void _applyChain() {
    _sinceLastApply
      ..reset()
      ..start();

    final filters = <String>[];

    // -- lavfi filters go first, a stripped ffmpeg can't convert the format scaletempo hands them and gets disabled.
    if (_equalizerEnabled && _equalizerGains.isNotEmpty && !_MPVMissingFilters.contains(_kEqualizerFilterName)) {
      final frequencies = _equalizerGains.keys.toList();
      final bands = <String>[];
      for (int i = 0; i < frequencies.length; i++) {
        final frequency = frequencies[i];
        final gain = _equalizerGains[frequency]!;
        if (gain == 0.0) continue; // -- a flat band is a biquad computed for nothing
        final width = _bandWidthInOctaves(frequencies, i);
        bands.add('$_kEqualizerFilterName=f=${_formatDouble(frequency)}:t=o:w=${_formatDouble(width)}:g=${_formatDouble(gain)}');
      }
      if (bands.isNotEmpty) filters.add('@$_kEqualizerLabel:lavfi=[${bands.join(',')}]');
    }

    if (_skipSilenceEnabled && !_MPVMissingFilters.contains(_kSkipSilenceFilterName)) {
      filters.add('@$_kSkipSilenceLabel:lavfi=[$_kSkipSilenceFilterName=$_kSkipSilenceParams]');
    }

    // -- the filter media_kit sets on its own for rate & pitch, rebuilt since we own the property now.
    final rate = _player.state.rate;
    final pitch = _player.state.pitch;
    if (rate != 1.0 || pitch != 1.0) filters.add('scaletempo:scale=${(rate / pitch).toStringAsFixed(8)}');

    _setProperty('af', filters.join(','));
  }

  /// Width that covers the gap to the closest neighbour band, so bands blend instead of leaving holes.
  static double _bandWidthInOctaves(List<double> frequencies, int index) {
    const fallback = 2.0;
    if (frequencies.length < 2) return fallback;
    final current = frequencies[index];
    final neighbour = index == 0 ? frequencies[1] : frequencies[index - 1];
    final ratio = index == 0 ? neighbour / current : current / neighbour;
    if (!(ratio > 1)) return fallback;
    return math.log(ratio) / math.ln2;
  }

  static String _formatDouble(double value) => value.toStringAsFixed(4);

  Future<void> _setProperty(String name, String value) async {
    try {
      await (_player.platform as mk.NativePlayer).setProperty(name, value);
    } catch (_) {}
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
