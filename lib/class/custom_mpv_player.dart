import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:audio_session/audio_session.dart';
import 'package:basic_audio_handler/basic_audio_handler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart';

import 'package:namida/controller/audio_output_controller.dart';
import 'package:namida/controller/platform/namida_channel/namida_channel.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';

// Missing features: quick settings tile, picture in picture
// `isPlaying()`, `hasVideo()`, `getVideoRational()`.
class CustomMPVPlayer implements AVPlayer {
  // features: skip silence, looping animations, equalizer, equalizer presets, loudness enhancer
  // by claude
  static const _enableExperimentalFeatures = true;

  factory CustomMPVPlayer({bool disableVideo = false}) {
    if (Platform.isIOS) return _CustomMPVPlayerIOS(disableVideo: disableVideo);
    return CustomMPVPlayer._(disableVideo: disableVideo);
  }

  CustomMPVPlayer._({bool disableVideo = false}) {
    if (!disableVideo) _videoController;
    // -- subtitles are only ever selected through [setTextTrack]/[setExternalSubtitle],
    // -- sidecar files are discovered by us so mpv must not auto load them.
    _setMpvProperty('sid', 'no');
    _setMpvProperty('sub-auto', 'no');
    // -- a busy device keeps the file loaded, mpv would otherwise fail it and jump to the queued next item.
    _setMpvProperty('audio-fallback-to-null', 'yes');
    final nativePlayer = _player.platform as mk.NativePlayer;
    nativePlayer.observeProperty('current-ao', _onAudioDriverChanged).ignoreError();
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
        // -- mpv can flag eof for an instant while moving to the queued item, [_onPlaylistChanged] reports that move
        if (_queuedNextMedia != null) return;
        _processingState = ProcessingState.completed;
        _updateProcessingState();
      } else if (_processingState == ProcessingState.completed) {
        _processingState = _player.state.buffering ? ProcessingState.buffering : ProcessingState.ready;
        _updateProcessingState();
      }
    });

    _playerBufferingStreamSub = _player.stream.buffering.listen((event) {
      // -- mpv reports buffering off right after eof, only the completed stream ends that state
      if (_processingState == ProcessingState.completed) return;
      if (event) {
        _processingState = ProcessingState.buffering;
      } else {
        _processingState = ProcessingState.ready;
      }
      _updateProcessingState();
    });

    _playerPlayingStreamSub = _player.stream.playing.listen((_) => _reportPlaybackEvent());

    _playerPositionStreamSub = _player.stream.position.listen((p) {
      if (_processingState != ProcessingState.completed) {
        if (p < Duration.zero) p = Duration.zero;
        _position = p;
        _sincePositionReport.reset();
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

    _playerAudioDevicesStreamSub = _player.stream.audioDevices.listen((devices) => outputDevices.value = devices);

    _playerPlaylistStreamSub = _player.stream.playlist.listen(_onPlaylistChanged);

    _playerBufferStreamSub = _player.stream.buffer.listen((buffer) {
      final isAdvancing = _player.state.playing && _processingState == ProcessingState.ready;
      _liveWindowTracker.onBuffer(buffer, position, isAdvancing: isAdvancing);
    });
  }

  /// mpv moving to this item is the only reliable sign of a gapless transition.
  mk.Media? _queuedNextMedia;

  void _onPlaylistChanged(mk.Playlist playlist) {
    final queued = _queuedNextMedia;
    if (queued == null) return;
    final index = playlist.index;
    if (index < 0 || index >= playlist.medias.length) return;
    if (!identical(playlist.medias[index], queued)) return;
    _queuedNextMedia = null;
    final transitionEvent = PlaybackEvent(processingState: _processingState, currentIndex: index, autoTransition: true);
    _playbackEventStreamController.add(transitionEvent);
  }

  /// every mpv instance sees the same devices, the latest report wins.
  static final outputDevices = Rx<List<mk.AudioDevice>>(const []);

  static Set<EqualizerBandType> getSupportedEqualizerBandTypes() => {
    for (final type in EqualizerBandType.values)
      if (_MPVAudioFilters.isFilterAvailable(_MPVAudioFilters.filterNameOf(type))) type,
  };

  static bool supportsEqualizerLimiter() => _MPVAudioFilters.isFilterAvailable(_MPVAudioFilters._kLimiterFilterName);

  ProcessingState _processingState = ProcessingState.idle;
  Duration _position = Duration.zero;

  final _sincePositionReport = Stopwatch()..start();

  // -- ios: namida owns the audio session, mpv would deactivate the shared one whenever any of its players closes (crossfade, temp players)
  final _player = mk.Player(configuration: const mk.PlayerConfiguration(pitch: true, libass: true, bufferSize: 64 * 1024 * 1024, iosManageAudioSession: false));
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
  StreamSubscription? _playerPlayingStreamSub;
  StreamSubscription? _playerPositionStreamSub;
  StreamSubscription? _playerAudioTracksStreamSub;
  StreamSubscription? _playerLogStreamSub;
  StreamSubscription? _playerAudioDevicesStreamSub;
  StreamSubscription? _playerPlaylistStreamSub;
  StreamSubscription? _playerBufferStreamSub;
  late final _liveWindowTracker = _MPVLiveWindowTracker(_player);
  final _playbackEventStreamController = StreamController<PlaybackEvent>();
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
    _reportPlaybackEvent();
  }

  /// media sessions (now playing on apple) only refresh on these, like with just_audio's events.
  void _reportPlaybackEvent() {
    final event = PlaybackEvent(processingState: _processingState, updatePosition: position, bufferedPosition: bufferedPosition, duration: duration);
    _playbackEventStreamController.add(event);
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
  Stream<PlaybackEvent> get playbackEventStream => _playbackEventStreamController.stream;

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
  Stream<double> get volumeStream => _player.stream.volume.map((_) => _volume);
  @override
  Stream<double> get speedStream => _player.stream.rate;
  @override
  Stream<double> get pitchStream => _player.stream.pitch;
  @override
  Stream<bool> get playingStream => _player.stream.playing;
  @override
  Stream<LiveWindow?> get liveWindowStream => _liveWindowTracker.stream;

  @override
  int? get androidAudioSessionId => null;
  @override
  ProcessingState get processingState => _processingState;
  @override
  Duration get bufferedPosition => _player.state.buffer;
  @override
  Duration get position {
    if (!_player.state.playing || _processingState != ProcessingState.ready) return _position;
    final rate = _bitPerfect ? 1.0 : _speed;
    final movedOnMicroseconds = (_sincePositionReport.elapsedMicroseconds * rate).round();
    return _position + Duration(microseconds: movedOnMicroseconds);
  }

  @override
  Duration? get duration => _player.state.duration;
  @override
  double get volume => _volume;
  @override
  double get speed => _speed;
  @override
  double get pitch => _pitch;
  @override
  bool get playing => _player.state.playing;
  @override
  LiveWindow? get liveWindow => _liveWindowTracker.window;

  /// media_kit rebuilds the whole filter chain on every rate change.
  @override
  bool get supportsSeamlessSpeedChange => false;

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
    _queuedNextMedia = null;

    _processingState = ProcessingState.loading;
    _updateProcessingState();

    final isLive = _checkIsSourceLive(config.source) || _checkIsSourceLive(config.videoOptions?.source);
    _liveWindowTracker.reset(isLive: isLive);

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
      await _applyVideoSelection(videoOptions);

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

        await _tryOpen(mainMedia);
        final videoTrackSource = await _resolveVideoTrackSource(videoOptions, durationCompleter.future);
        final videoTrack = mk.VideoTrack(videoTrackSource, null, null);
        await _setVideoTrack(videoTrack);
        _updateAudioTracks();
      }

      // -- `open` always loads paused, undoing a play requested meanwhile (crossfade)
      if (_playRequested) await _startPlayback();
    } catch (_) {
      completeDuration(null);
      rethrow;
    }

    _restoreExternalSubtitle();

    if (isLive) {
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
  // -- timeline that repeats it up to the audio's exact length, mpv only ends the file once every track is done.
  // -- it stays a normal track, so seeking still works.
  bool _loopingVideoApplied = false;

  static const _kMaxLoopingVideoRepeats = 3000;

  /// Returns the source to add as a video track, an `edl://` looping timeline when the animation asks for it,
  /// or an `edl://` segment starting at [VideoSourceOptions.startOffsetMS].
  Future<String> _resolveVideoTrackSource(VideoSourceOptions videoOptions, Future<Duration?> audioDurationFuture) async {
    final source = videoOptions.source as UriSource;
    final sourceDurationMS = videoOptions.durationMS;
    String? loopingSource;
    if (_enableExperimentalFeatures && videoOptions.loop && sourceDurationMS != null && sourceDurationMS > 0) {
      // -- `open` resets the duration, the new one only comes once the file is loaded
      final audioDuration = await audioDurationFuture.timeout(_durationWaitTimeout, onTimeout: () => null);
      if (audioDuration != null) loopingSource = _buildLoopingVideoSource(source, sourceDurationMS, audioDuration.inMilliseconds);
    }
    _loopingVideoApplied = loopingSource != null;
    if (loopingSource != null) return loopingSource;

    final startOffsetMS = videoOptions.startOffsetMS;
    if (!videoOptions.loop && startOffsetMS != null && startOffsetMS > 0) {
      final segmentPath = _edlSegmentPath(source);
      final startSeconds = _edlSeconds(startOffsetMS);
      return 'edl://$segmentPath,start=$startSeconds';
    }

    return source.uri.toString();
  }

  String? _buildLoopingVideoSource(UriSource source, int sourceDurationMS, int targetMS) {
    if (targetMS <= sourceDurationMS) return null;

    final neededRepeats = targetMS ~/ sourceDurationMS;
    final isCapped = neededRepeats > _kMaxLoopingVideoRepeats;
    final fullRepeats = isCapped ? _kMaxLoopingVideoRepeats : neededRepeats;
    final remainderMS = isCapped ? 0 : targetMS - fullRepeats * sourceDurationMS;

    // -- explicit lengths keep the total exact even if the file's own duration differs slightly.
    final segmentPath = _edlSegmentPath(source);
    final segmentSeconds = _edlSeconds(sourceDurationMS);
    final segment = '$segmentPath,length=$segmentSeconds;';
    final buffer = StringBuffer('edl://');
    for (int i = 0; i < fullRepeats; i++) {
      buffer.write(segment);
    }
    if (remainderMS > 0) {
      final remainderSeconds = _edlSeconds(remainderMS);
      buffer.write('$segmentPath,length=$remainderSeconds;');
    }
    return buffer.toString();
  }

  /// byte length prefixed, that way the path needs no escaping at all.
  static String _edlSegmentPath(UriSource source) {
    final path = source.uri.isScheme('file') ? source.uri.toFilePath() : source.uri.toString();
    return '%${utf8.encode(path).length}%$path';
  }

  static String _edlSeconds(int ms) => (ms / 1000).toStringAsFixed(3);

  /// set before opening, mpv keeps it for every file after. a video played as audio only would otherwise still get decoded.
  Future<void> _applyVideoSelection(VideoSourceOptions? videoOptions) async {
    final player = _player.platform as mk.NativePlayer;
    await player.waitForVideoControllerInitializationIfAttached; // -- attaching selects `auto` itself
    final vid = _getVideoSelection(videoOptions);
    await _setMpvProperty('vid', vid);
  }

  String _getVideoSelection(VideoSourceOptions? videoOptions) => videoOptions == null ? 'no' : 'auto';

  /// `auto` adds the track without selecting it.
  String get _videoTrackAddFlag => 'select';

  /// the add only completes once the track is opened.
  Future<void> _onVideoTrackAdded(String addFlag) async {}

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

      final addFlag = _videoTrackAddFlag;
      await player.command(
        [
          'video-add',
          videoTrack.id,
          addFlag,
          videoTrack.title ?? 'external',
          videoTrack.language ?? 'auto',
        ],
      );
      await _onVideoTrackAdded(addFlag);
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

  bool _playRequested = false;

  @override
  Future<void> play() async {
    _playRequested = true;
    await _syncAudioDeviceRelease();
    await _retryUnavailableAudioDevice();
    return _startPlayback();
  }

  Future<void> _startPlayback() => _player.play();

  @override
  Future<void> pause() async {
    _playRequested = false;
    await _player.pause();
    await _syncAudioDeviceRelease();
  }

  // -- when the video is a non-looped external track, seeking past its end leaves a frozen frame,
  // -- but skipping the seek entirely blocks audio seeking, so its disabled.
  static const _kSkipSeekWhenLoopNotApplied = false;

  @override
  Future<void> seek(Duration? position) async {
    if (_kSkipSeekWhenLoopNotApplied && !_loopingVideoApplied && _videoOptions?.loop == true) return;
    if (position != null) _liveWindowTracker.onSeek();
    final target = position ?? _liveWindowTracker.window?.edge ?? Duration.zero;
    _position = target;
    _sincePositionReport.reset();
    await _player.seek(target);
    _reportPlaybackEvent();
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    return pause(); // _player.stop too powerful
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
      _playerPlayingStreamSub?.cancel(),
      _playerPositionStreamSub?.cancel(),
      _playerAudioTracksStreamSub?.cancel(),
      _playerLogStreamSub?.cancel(),
      _playerAudioDevicesStreamSub?.cancel(),
      _playerPlaylistStreamSub?.cancel(),
      _playerBufferStreamSub?.cancel(),
    ].execute();

    // -- not awaited, closing a controller that was never listened to never completes (temp players).
    _playbackEventStreamController.close();
    _videoInfoStreamController.close();
    _playerProcessingStateStreamController.close();
    _playerPositionStreamController.close();
    _audioTracksStreamController.close();
    _textTracksStreamController.close();
    _liveWindowTracker.dispose();

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
  Future<void> setEqualizer(ParametricEqualizer? equalizer) async {
    _audioFilters.setEqualizer(equalizer);
    final preampDb = equalizer?.computeEffectivePreamp() ?? 0.0;
    if (_preampDb == preampDb) return;
    _preampDb = preampDb;
    await _applyVolume();
  }

  String? _audioDevice;
  bool _bitPerfect = false;
  bool _exclusive = false;
  bool _mono = false;

  static const _kSignalPathProperties = [
    'audio-codec-name', 'audio-bitrate', 'current-ao', //
    'audio-params/samplerate', 'audio-params/channel-count', 'audio-params/format', //
    'audio-out-params/samplerate', 'audio-out-params/channel-count', 'audio-out-params/format', //
  ];

  /// what mpv decodes and hands to its audio output, namida's own filters (equalizer, speed, volume) aren't part of it.
  Future<AudioSignalPath> getSignalPath() async {
    final player = _player.platform as mk.NativePlayer;
    final propertyFutures = _kSignalPathProperties.map((name) => player.getProperty(name).catchError((_) => ''));
    final values = await Future.wait(propertyFutures);
    final codecName = values[0];
    final bitrate = double.tryParse(values[1]) ?? 0.0;
    final driver = values[2];
    final decoded = _signalFormatOf(values[3], values[4], values[5]);
    final output = _signalFormatOf(values[6], values[7], values[8]);
    final isUntouched = !decoded.isFloat && !output.isFloat && decoded.sampleRate == output.sampleRate && decoded.channels == output.channels;
    final isBitPerfect = _bitPerfect && isUntouched && output.bitDepth >= decoded.bitDepth;
    final deviceDescription = _player.state.audioDevice.description;
    return AudioSignalPath(
      codec: _codecOf(codecName),
      source: AudioSignalFormat(sampleRate: decoded.sampleRate, bitDepth: 0, isFloat: false, channels: decoded.channels),
      sourceBitrate: bitrate.round(),
      decoderName: codecName.isEmpty ? null : 'FFmpeg $codecName',
      decoded: decoded,
      isBitPerfect: isBitPerfect,
      outputType: _exclusive ? AudioSignalOutputType.desktopExclusive : AudioSignalOutputType.desktopShared,
      outputDriver: driver.isEmpty ? null : driver,
      outputDeviceName: deviceDescription.isEmpty ? null : deviceDescription,
      output: output,
      isOutputDithered: false,
      hasOutputHardwareVolume: false,
      mixerSampleRate: 0,
    );
  }

  static String? _codecOf(String codecName) {
    if (codecName.isEmpty) return null;
    if (codecName.startsWith('mp3')) return 'MP3';
    if (codecName.startsWith('pcm_')) return 'PCM';
    return codecName.toUpperCase();
  }

  /// mpv sample formats: u8, s16, s32, s64, float, double, with a `p` suffix when planar.
  static AudioSignalFormat _signalFormatOf(String sampleRate, String channels, String format) {
    final packedFormat = format.endsWith('p') ? format.substring(0, format.length - 1) : format;
    final (bitDepth, isFloat) = switch (packedFormat) {
      'u8' => (8, false),
      's16' => (16, false),
      's24' => (24, false),
      's32' => (32, false),
      's64' => (64, false),
      'float' => (32, true),
      'double' => (64, true),
      _ => (0, false),
    };
    return AudioSignalFormat(
      sampleRate: int.tryParse(sampleRate) ?? 0,
      bitDepth: bitDepth,
      isFloat: isFloat,
      channels: int.tryParse(channels) ?? 0,
    );
  }

  @override
  Future<void> setAudioOutput(String? device, {required bool bitPerfect, required bool exclusive, required bool mono}) async {
    if (device != _audioDevice) {
      _audioDevice = device;
      final mpvDevice = device ?? 'auto';
      await _setMpvProperty('audio-device', mpvDevice);
    }
    // -- mpv's own downmix, lavfi's `pan` is missing from the bundled builds
    final isMonoApplied = mono && !bitPerfect;
    if (isMonoApplied != _mono) {
      _mono = isMonoApplied;
      await _setMpvProperty('audio-channels', isMonoApplied ? 'mono' : 'auto-safe');
    }
    final isExclusiveApplied = exclusive || bitPerfect;
    if (isExclusiveApplied != _exclusive) {
      _exclusive = isExclusiveApplied;
      await _setMpvProperty('audio-exclusive', isExclusiveApplied ? 'yes' : 'no');
      await _syncAudioDeviceRelease();
    }
    if (bitPerfect == _bitPerfect) return;
    _bitPerfect = bitPerfect;
    _audioFilters.setBitPerfect(bitPerfect);
    await [
      _player.setRate(bitPerfect ? 1.0 : _speed),
      _player.setPitch(bitPerfect ? 1.0 : _pitch),
      _applyVolume(),
    ].execute();
    if (!bitPerfect) _audioFilters.refresh();
  }

  static const _kNullAudioDriver = 'null';
  static const _kAutoAudioDriver = '';

  bool get _canReleaseAudioDevice => true;

  bool _isAudioDeviceReleased = false;
  bool _isAudioDeviceUnavailable = false;

  /// async command, closing an exclusive stream blocks the caller for up to a few hundred ms.
  Future<void> _syncAudioDeviceRelease() async {
    final shouldRelease = _exclusive && !_playRequested && _canReleaseAudioDevice;
    if (shouldRelease == _isAudioDeviceReleased) return;
    _isAudioDeviceReleased = shouldRelease;
    _isAudioDeviceUnavailable = false;
    final driver = shouldRelease ? _kNullAudioDriver : _kAutoAudioDriver;
    final player = _player.platform as mk.NativePlayer;
    await player.command(['set', 'ao', driver]).catchError((_) {});
  }

  Future<void> _retryUnavailableAudioDevice() async {
    if (!_isAudioDeviceUnavailable) return;
    _isAudioDeviceUnavailable = false;
    final player = _player.platform as mk.NativePlayer;
    await player.command(['ao-reload']).catchError((_) {});
  }

  Future<void> _onAudioDriverChanged(String driver) async {
    if (_disposed) return;
    final isUnavailable = driver == _kNullAudioDriver && !_isAudioDeviceReleased;
    _isAudioDeviceUnavailable = isUnavailable;
    if (isUnavailable && _playRequested) {
      _playbackEventStreamController.addError(const AudioOutputUnavailableException());
    }
  }

  // -- the `volume` filter is absent from most mpv builds, mpv's own volume can go past 100% instead.
  bool _loudnessEnhancerEnabled = false;
  double _loudnessEnhancerGain = 0.0;
  double _preampDb = 0.0;
  double _volume = 1.0;
  double _speed = 1.0;
  double _pitch = 1.0;
  String? _originalVolumeMax;

  @override
  Future<void> setLoudnessEnhancerEnabled(bool enabled) async {
    if (_loudnessEnhancerEnabled == enabled) return;
    _loudnessEnhancerEnabled = enabled;
    await _applyVolume();
  }

  @override
  Future<void> setLoudnessEnhancerGain(double gainDb) async {
    if (_loudnessEnhancerGain == gainDb) return;
    _loudnessEnhancerGain = gainDb;
    if (_loudnessEnhancerEnabled) await _applyVolume();
  }

  static const _kVolumeMaxProperty = 'volume-max';
  static const _kBoostedVolumeMaxPercentage = 1000;

  @override
  Future<void> setVolume(double volume) {
    _volume = volume;
    return _applyVolume();
  }

  /// [_volume] is a linear gain like on every other player, mpv applies its `volume` cubed.
  Future<void> _applyVolume() async {
    if (_bitPerfect) {
      await _setVolumeMaxBoosted(false);
      return _player.setVolume(100);
    }
    final loudnessDb = _loudnessEnhancerEnabled ? _loudnessEnhancerGain : 0.0;
    final gainDb = _preampDb + loudnessDb;
    final gain = _volume * math.pow(10, gainDb / 20);
    final cubicRoot = math.pow(gain, 1 / 3).toDouble();
    final mpvVolume = (cubicRoot * 100).withMaximum(_kBoostedVolumeMaxPercentage.toDouble());
    await _setVolumeMaxBoosted(mpvVolume > 100);
    return _player.setVolume(mpvVolume);
  }

  /// mpv refuses anything above 130% by default, the original cap has to come back with us,
  /// otherwise it would keep uncapping volumes that aren't ours.
  Future<void> _setVolumeMaxBoosted(bool boosted) async {
    final player = _player.platform as mk.NativePlayer;
    if (boosted) {
      if (_originalVolumeMax != null) return;
      final currentMax = await player.getProperty(_kVolumeMaxProperty);
      _originalVolumeMax = currentMax.isNotEmpty ? currentMax : '130';
      await player.setProperty(_kVolumeMaxProperty, '$_kBoostedVolumeMaxPercentage');
    } else if (_originalVolumeMax != null) {
      await player.setProperty(_kVolumeMaxProperty, _originalVolumeMax!);
      _originalVolumeMax = null;
    }
  }

  @override
  Future<void> setPitch(double pitch) async {
    _pitch = pitch;
    if (_bitPerfect) return;
    await _player.setPitch(pitch);
    _audioFilters.refresh(); // -- media_kit overwrites the whole filter chain when pitch changes
  }

  @override
  Future<void> setSpeed(double speed) async {
    _speed = speed;
    if (_bitPerfect) return;
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
    _queuedNextMedia = media;
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
    _queuedNextMedia = null;
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

/// ios specifics: namida owns the audio session, the gpu is off limits in the background
/// and the session's rate decides whether the output gets resampled.
// by claude
class _CustomMPVPlayerIOS extends CustomMPVPlayer {
  _CustomMPVPlayerIOS({bool disableVideo = false}) : _isAppActive = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed, super._(disableVideo: disableVideo) {
    if (!disableVideo) {
      _lifecycleListener = AppLifecycleListener(onStateChange: _onLifecycleStateChange);
      if (!_isAppActive) _syncVideoSuspension();
    }
    _audioParamsSub = _player.stream.audioParams.listen(_onAudioParams);
  }

  AppLifecycleListener? _lifecycleListener;
  late final StreamSubscription<mk.AudioParams> _audioParamsSub;
  final _audioSessionFuture = AudioSession.instance;

  /// set synchronously on every lifecycle change, [_syncVideoSuspension] catches up with it one step at a time.
  bool _isAppActive;
  bool _isVideoSuspended = false;
  bool _isSyncingVideoSuspension = false;

  int? _sourceSampleRate;

  /// the audio unit is never exclusive, bit-perfect only matches the session rate.
  @override
  bool get _canReleaseAudioDevice => false;

  /// a video added while away waits for the app to be active again to be selected.
  @override
  String get _videoTrackAddFlag => _isAppActive ? 'select' : 'auto';

  @override
  String _getVideoSelection(VideoSourceOptions? videoOptions) => _isAppActive ? super._getVideoSelection(videoOptions) : 'no';

  /// the app left or came back while the track was opening, its selection follows where the app is now.
  @override
  Future<void> _onVideoTrackAdded(String addFlag) async {
    final wasSelected = addFlag == 'select';
    if (wasSelected == _isAppActive) return;
    final vid = _isAppActive ? await _fetchExternalVideoTrackId() : 'no';
    await _setMpvProperty('vid', vid);
  }

  /// activated on every play, an interruption, another app or a route change can leave it inactive without a reliable event.
  /// a failed activation (ex: during a call) still plays, the state stays what the user asked for.
  @override
  Future<void> _startPlayback() async {
    final session = await _audioSessionFuture;
    await session.setActive(true).catchError((_) => false);
    if (!_playRequested) return;
    await _player.play();
  }

  /// inactive is the earliest sign of leaving, hidden only comes once ios already took the gpu away.
  /// so a glance at control center reloads the video too, rendering it in the background gets the app killed.
  void _onLifecycleStateChange(AppLifecycleState state) {
    _isAppActive = state == AppLifecycleState.resumed;
    if (!_isSyncingVideoSuspension) _syncVideoSuspension();
  }

  Future<void> _syncVideoSuspension() async {
    _isSyncingVideoSuspension = true;
    while (_isVideoSuspended == _isAppActive && !_disposed) {
      if (_isAppActive) {
        await _resumeVideo();
      } else {
        await _suspendVideo();
      }
    }
    _isSyncingVideoSuspension = false;
  }

  /// mpv keeps playing the audio alone meanwhile.
  Future<void> _suspendVideo() async {
    await _setMpvProperty('vid', 'no');
    _isVideoSuspended = true;
  }

  /// nothing to bring back without video options, selecting the video of a file played as audio only stalls the audio while it reloads.
  Future<void> _resumeVideo() async {
    final videoOptions = _videoOptions;
    if (videoOptions != null) {
      final vid = videoOptions.videoOnly ? 'auto' : await _fetchExternalVideoTrackId();
      await _setMpvProperty('vid', vid);
    }
    _isVideoSuspended = false;
  }

  /// the external track namida adds is the last one, covers aren't videos. one still being added is selected once it's there.
  /// read from mpv itself, the player state lags behind a track that was just added.
  Future<String> _fetchExternalVideoTrackId() async {
    final player = _player.platform as mk.NativePlayer;
    final countText = await player.getProperty('track-list/count').catchError((_) => '0');
    final count = int.tryParse(countText) ?? 0;
    for (int i = count - 1; i >= 0; i--) {
      final type = await player.getProperty('track-list/$i/type').catchError((_) => '');
      if (type != 'video') continue;
      final isAlbumArt = await player.getProperty('track-list/$i/albumart').catchError((_) => 'no');
      final isImage = await player.getProperty('track-list/$i/image').catchError((_) => 'no');
      if (isAlbumArt == 'yes' || isImage == 'yes') continue;
      return player.getProperty('track-list/$i/id').catchError((_) => 'auto');
    }
    return 'auto';
  }

  void _onAudioParams(mk.AudioParams params) {
    final sampleRate = params.sampleRate;
    if (sampleRate == null || sampleRate <= 0 || sampleRate == _sourceSampleRate) return;
    _sourceSampleRate = sampleRate;
    if (_bitPerfect) _matchSessionSampleRate(sampleRate);
  }

  Future<void> _matchSessionSampleRate(int sampleRate) async {
    await NamidaChannel.inst.setPreferredSampleRate(sampleRate);
    // -- the audio unit keeps the rate it was opened at until reloaded
    final player = _player.platform as mk.NativePlayer;
    await player.command(['ao-reload']).catchError((_) {});
  }

  @override
  Future<void> setAudioOutput(String? device, {required bool bitPerfect, required bool exclusive, required bool mono}) async {
    final wasBitPerfect = _bitPerfect;
    await super.setAudioOutput(device, bitPerfect: bitPerfect, exclusive: exclusive, mono: mono);
    final sampleRate = _sourceSampleRate;
    if (_bitPerfect && !wasBitPerfect && sampleRate != null) await _matchSessionSampleRate(sampleRate);
  }

  @override
  Future<void> dispose() {
    if (_disposed) return Future.value();
    _lifecycleListener?.dispose();
    _audioParamsSub.cancel();
    return super.dispose();
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

  static const _kLavfiInputFormatFilter = 'format=format=floatp';
  static const _kLimiterFilterName = 'alimiter';
  static const _kSkipSilenceFilterName = 'silenceremove';
  static const _kSkipSilenceParams =
      'start_periods=1:start_duration=0.15:start_threshold=-50dB:start_silence=0.05'
      ':stop_periods=-1:stop_duration=2:stop_threshold=-50dB:stop_silence=2:detection=peak';

  /// media_kit's windows & macos libmpv ship a stripped ffmpeg whose only equalizing filter is `equalizer`,
  /// linux uses the system's libmpv.
  static final _kFullFilterSet = Platform.isLinux;

  static bool isFilterAvailable(String name) => !_MPVMissingFilters.contains(name) && (_kFullFilterSet || name == 'equalizer');

  static String filterNameOf(EqualizerBandType type) => switch (type) {
    EqualizerBandType.peak => 'equalizer',
    EqualizerBandType.lowShelf => 'lowshelf',
    EqualizerBandType.highShelf => 'highshelf',
    EqualizerBandType.lowPass => 'lowpass',
    EqualizerBandType.highPass => 'highpass',
    EqualizerBandType.bandPass => 'bandpass',
    EqualizerBandType.notch => 'bandreject',
    EqualizerBandType.allPass => 'allpass',
  };

  /// Rebuilding the chain reinitializes the filters, dragging a slider would do it on every frame.
  static const _kApplyThrottleMS = 100;

  bool _skipSilenceEnabled = false;
  ParametricEqualizer? _equalizer;
  bool _bitPerfect = false;

  Timer? _throttleTimer;
  final _sinceLastApply = Stopwatch();

  bool get _hasCustomFilters => _equalizer != null || _skipSilenceEnabled;

  /// media_kit already wrote a chain holding nothing but its own scaletempo filter, only ours need to be restored.
  void refresh() {
    if (_hasCustomFilters && !_bitPerfect) _requestApply();
  }

  void setSkipSilenceEnabled(bool enabled) {
    if (_skipSilenceEnabled == enabled) return;
    _skipSilenceEnabled = enabled;
    _requestApply();
  }

  void setEqualizer(ParametricEqualizer? equalizer) {
    if (_equalizer == equalizer) return;
    _equalizer = equalizer;
    _requestApply();
  }

  void setBitPerfect(bool bitPerfect) {
    if (_bitPerfect == bitPerfect) return;
    _bitPerfect = bitPerfect;
    _requestApply();
  }

  void onMissingFilter(String filter) {
    if (_hasCustomFilters && !_bitPerfect) _applyChain(); // -- the chain is down, restoring it without the missing filter
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

    if (_bitPerfect) {
      _setProperty('af', '');
      return;
    }

    final filters = <String>[];

    // -- lavfi filters go first, a stripped ffmpeg can't convert the format scaletempo hands them and gets disabled.
    final equalizer = _equalizer;
    if (equalizer != null) {
      final sections = <String>[];
      for (final band in equalizer.getActiveBands()) {
        final name = filterNameOf(band.type);
        if (!isFilterAvailable(name)) continue;
        for (int s = 0; s < band.sectionCount; s++) {
          sections.add(_bandFilter(name, band, band.sectionQ(s)));
        }
      }
      if (equalizer.limiter && sections.isNotEmpty && isFilterAvailable(_kLimiterFilterName)) {
        sections.add('$_kLimiterFilterName=limit=0.999:level=0');
      }
      if (sections.isNotEmpty) filters.add('@$_kEqualizerLabel:lavfi=[${sections.join(',')}]');
    }

    if (_skipSilenceEnabled && !_MPVMissingFilters.contains(_kSkipSilenceFilterName)) {
      filters.add('@$_kSkipSilenceLabel:lavfi=[$_kSkipSilenceFilterName=$_kSkipSilenceParams]');
    }

    // -- without `aresample` lavfi can't convert packed sources (wav, flac) and fails, mpv's own converter does it ahead.
    if (filters.isNotEmpty) filters.insert(0, _kLavfiInputFormatFilter);

    // -- the filter media_kit sets on its own for rate & pitch, rebuilt since we own the property now.
    final rate = _player.state.rate;
    final pitch = _player.state.pitch;
    if (rate != 1.0 || pitch != 1.0) filters.add('scaletempo:scale=${(rate / pitch).toStringAsFixed(8)}');

    _setProperty('af', filters.join(','));
  }

  /// every one of these filters is an RBJ cookbook biquad, same design as [ParametricEqualizer.responseDb].
  static String _bandFilter(String name, EqualizerBand band, double q) {
    final frequencyText = _formatDouble(band.frequency);
    final qText = _formatDouble(q);
    final buffer = StringBuffer('$name=f=$frequencyText:t=q:w=$qText');
    if (band.type.hasGain) {
      final gainText = _formatDouble(band.gain);
      buffer.write(':g=$gainText');
    }
    if (band.type.hasOrder) buffer.write(':p=2');
    switch (band.channel) {
      case EqualizerChannel.all:
        break;
      case EqualizerChannel.left:
        buffer.write(':c=FL');
      case EqualizerChannel.right:
        buffer.write(':c=FR');
    }
    return buffer.toString();
  }

  static String _formatDouble(double value) => value.toStringAsFixed(4);

  Future<void> _setProperty(String name, String value) async {
    try {
      await (_player.platform as mk.NativePlayer).setProperty(name, value);
    } catch (_) {}
  }
}

// by claude
/// ffmpeg can't seek live playlists, so the window is whatever mpv keeps in its demuxer cache.
class _MPVLiveWindowTracker {
  final mk.Player _player;
  _MPVLiveWindowTracker(this._player);

  static const _kSeekableStartRefreshIntervalMS = 5000;
  static const _kJoinOffsetSamplingMS = 20000;

  final _streamController = StreamController<LiveWindow?>();
  Stream<LiveWindow?> get stream => _streamController.stream;

  LiveWindow? _window;
  LiveWindow? get window => _window;

  bool _isLive = false;

  /// how far behind the newest cached data playback settles after joining, the edge keeps that distance.
  /// the distance shrinks between segments, so the largest one seen while sampling is kept.
  Duration? _joinOffset;
  bool _isSamplingJoinOffset = false;
  final _sinceJoin = Stopwatch();
  Duration? _seekableStart;
  final _sinceSeekableStartRefresh = Stopwatch();
  bool _isRefreshingSeekableStart = false;

  void reset({required bool isLive}) {
    _isLive = isLive;
    _joinOffset = null;
    _isSamplingJoinOffset = isLive;
    _sinceJoin
      ..stop()
      ..reset();
    _seekableStart = null;
    _sinceSeekableStartRefresh
      ..stop()
      ..reset();
    _setWindow(null);
  }

  void onBuffer(Duration buffer, Duration position, {required bool isAdvancing}) {
    if (!_isLive || buffer <= Duration.zero) return;

    if (_isSamplingJoinOffset && isAdvancing && position > Duration.zero) {
      _sampleJoinOffset(buffer - position);
    }
    _refreshSeekableStartIfDue();

    // -- whole seconds, so the window reports once a second at most while data keeps coming
    final edgeExact = buffer - (_joinOffset ?? Duration.zero);
    final edge = Duration(seconds: edgeExact.inSeconds);
    final startRaw = _seekableStart ?? position;
    final start = startRaw > edge ? edge : startRaw;
    _setWindow(LiveWindow(start: start, edge: edge, offset: Duration.zero));
  }

  void _sampleJoinOffset(Duration ahead) {
    if (!_sinceJoin.isRunning) _sinceJoin.start();
    final joinOffset = _joinOffset;
    if (joinOffset == null || ahead > joinOffset) _joinOffset = ahead > Duration.zero ? ahead : Duration.zero;
    if (_sinceJoin.elapsedMilliseconds >= _kJoinOffsetSamplingMS) _isSamplingJoinOffset = false;
  }

  /// a seek away from the edge makes the distance to it say nothing about the join.
  void onSeek() => _isSamplingJoinOffset = false;

  void _refreshSeekableStartIfDue() {
    if (_isRefreshingSeekableStart) return;
    final isDue = !_sinceSeekableStartRefresh.isRunning || _sinceSeekableStartRefresh.elapsedMilliseconds >= _kSeekableStartRefreshIntervalMS;
    if (!isDue) return;
    _sinceSeekableStartRefresh
      ..reset()
      ..start();
    _isRefreshingSeekableStart = true;
    _readSeekableStart().then((start) {
      _isRefreshingSeekableStart = false;
      if (start != null && _isLive) _seekableStart = start;
    });
  }

  Future<Duration?> _readSeekableStart() async {
    try {
      final stateText = await (_player.platform as mk.NativePlayer).getProperty('demuxer-cache-state');
      final state = jsonDecode(stateText) as Map;
      final ranges = state['seekable-ranges'] as List;
      final firstRange = ranges.first as Map;
      final startSeconds = firstRange['start'] as num;
      return Duration(microseconds: (startSeconds * 1000000).round());
    } catch (_) {
      return null;
    }
  }

  void _setWindow(LiveWindow? window) {
    if (window == _window) return;
    _window = window;
    _streamController.add(window);
  }

  void dispose() {
    _streamController.close();
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
  int get hashCode => Object.hash(width, height, textureId);

  @override
  bool operator ==(Object other) {
    return other is _VideoDetails && height == other.height && width == other.width && textureId == other.textureId;
  }

  @override
  String toString() => '_VideoDetails(width: $width, height: $height, textureId: $textureId)';
}
