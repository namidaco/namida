part of 'smtc_manager.dart';

class _SMTCManagerLinux extends NamidaSMTCManager {
  _CustomMPRISService? mpris;

  @override
  Future<void> init() async {
    mpris ??= _CustomMPRISService();
    Future.delayed(const Duration(milliseconds: 500), _refreshMPRIS);
  }

  void _refreshMPRIS() {
    final instance = mpris;
    if (instance == null) return;
    final originalStatus = instance.playbackStatus;
    instance.playbackStatus = PlaybackStatus.playing; // to force show
    instance.playbackStatus = switch (originalStatus) {
      PlaybackStatus.playing => PlaybackStatus.playing,
      PlaybackStatus.paused => PlaybackStatus.paused,
      PlaybackStatus.stopped => PlaybackStatus.paused, // paused, to keep it shown
    };
    instance.metadata = instance.metadata;
    instance.canPlay = true;
    instance.canPause = true;
    instance.canGoNext = true;
    instance.canGoPrevious = true;
    instance.canSeek = true;
    instance.canQuit = true;
    instance.canRaise = true;
    instance.canSetFullscreen = true;
  }

  @override
  void onPlay() {
    mpris?.playbackStatus = PlaybackStatus.playing;
  }

  @override
  void onPause() {
    mpris?.playbackStatus = PlaybackStatus.paused;
  }

  @override
  void onStop() {
    mpris?.playbackStatus = PlaybackStatus.stopped;
  }

  @override
  Future<void> dispose() async {
    mpris?.playbackStatus = PlaybackStatus.stopped;
    final mprisLocal = mpris;
    mpris = null;
    await mprisLocal?.dispose();
  }

  @override
  void updateMetadata(MediaItem mediaItem) async {
    final metadata = Metadata(
      // -- id must be in this format
      trackId: '/com/msob7y/namida/track/${mediaItem.id.hashCode.abs()}',
      trackTitle: mediaItem.title,
      trackArtist: [?mediaItem.artist],
      albumName: mediaItem.album,
      albumArtist: null,
      trackLength: mediaItem.duration,
      artUrl: mediaItem.artUri?.toString(),
    );
    mpris?.metadata = metadata;
  }

  @override
  void updateTimeline(int positionMS, int? durationMS) {
    mpris?.updatePosition(Duration(milliseconds: positionMS), forceEmitSeeked: true);
  }
}

class _CustomMPRISService extends MPRISService {
  _CustomMPRISService()
    : super(
        "namida",
        identity: "Namida",
        desktopEntry: "namida",
        emitSeekedSignal: true,
        canControl: true,
        canQuit: true,
        canRaise: true,
        canSetFullscreen: true,
        canPlay: true,
        canPause: true,
        canGoPrevious: true,
        canGoNext: true,
        canSeek: true,
        supportLoopStatus: true,
        supportShuffle: true,
        supportFullscreen: true,
        supportedUriSchemes: _kDefaultSupportedUriSchemes,
        supportedMimeTypes: _kDefaultSupportedMimeTypes,
      );

  @override
  Future<void> onPlayPause() async {
    if (playbackStatus == PlaybackStatus.playing) {
      playbackStatus = PlaybackStatus.paused;
      await Player.inst.pause();
    } else {
      playbackStatus = PlaybackStatus.playing;
      await Player.inst.play();
    }
  }

  @override
  Future<void> onPlay() async {
    playbackStatus = PlaybackStatus.playing;
    await Player.inst.play();
  }

  @override
  Future<void> onPause() async {
    playbackStatus = PlaybackStatus.paused;
    await Player.inst.pause();
  }

  @override
  Future<void> onStop() async {
    await Player.inst.pause().whenComplete(Player.inst.dispose);
  }

  @override
  Future<void> onNext() async {
    await Player.inst.next();
  }

  @override
  Future<void> onPrevious() async {
    await Player.inst.previous();
  }

  @override
  Future<void> onSeek(int offset) async {
    await Player.inst.seek(Duration(microseconds: offset));
  }

  @override
  Future<void> onSetPosition(String trackId, int position) async {
    await Player.inst.seek(Duration(microseconds: position));
  }

  @override
  Future<void> onOpenUri(String uri) async {
    NamidaReceiveIntentManager.executeReceivedItems(
      [Uri.parse(uri).toFilePath()],
      (f) => f,
      (f) => f,
    );
  }

  @override
  Future<void> onLoopStatus(LoopStatus loopStatus) async {
    final e = settings.player.repeatMode.value.nextElement(PlayerRepeatMode.values);
    settings.player.save(repeatMode: e);
    snackyy(
      icon: Broken.flash_1,
      title: '',
      message: "${lang.repeatMode}: ${e.buildText()}",
      borderColor: Colors.green.withOpacityExt(0.6),
      top: false,
    );
  }

  @override
  Future<void> onShuffle(bool shuffle) async {
    await Player.inst.shuffleTracks(true);
    snackyy(message: "${lang.shuffleAll}: ${lang.done}");
  }

  @override
  Future<void> onPlaybackRate(double rate) async {
    await Player.inst.setPlayerSpeed(rate);
    snackyy(message: "${lang.speed}: ${rate.roundDecimals(2)}");
  }

  @override
  Future<void> onVolume(double volume) async {
    await Player.inst.setVolume(volume);
    snackyy(message: "${lang.volume}: ${volume.roundDecimals(2)}");
  }

  @override
  Future<void> onRaise() async {
    NamidaTrayManager.showWindow();
  }

  @override
  Future<void> onFullscreen(bool fullscreen) async {
    if (fullscreen) {
      NamidaTrayManager.showWindow();
    } else {
      NamidaTrayManager.hideWindow();
    }
  }

  @override
  Future<void> onQuit() async {
    await Namida.disposeAllResourcesAndExit();
  }

  static const _kDefaultSupportedUriSchemes = [
    'ftp',
    'file',
    'rtmp',
    // 'rtsp',
    // 'http',
    // 'https',
  ];

  // source: https://github.com/alexmercerind/mpris_service
  static const _kDefaultSupportedMimeTypes = [
    'application/ogg',
    'application/x-ogg',
    'audio/ogg',
    'audio/vorbis',
    'audio/x-vorbis',
    'audio/x-vorbis+ogg',
    'video/ogg',
    'video/x-ogm',
    'video/x-ogm+ogg',
    'video/x-theora+ogg',
    'video/x-theora',
    'audio/x-speex',
    'audio/opus',
    'application/x-flac',
    'audio/flac',
    'audio/x-flac',
    'audio/x-ms-asf',
    'audio/x-ms-asx',
    'audio/x-ms-wax',
    'audio/x-ms-wma',
    'video/x-ms-asf',
    'video/x-ms-asf-plugin',
    'video/x-ms-asx',
    'video/x-ms-wm',
    'video/x-ms-wmv',
    'video/x-ms-wmx',
    'video/x-ms-wvx',
    'video/x-msvideo',
    'audio/x-pn-windows-acm',
    'video/divx',
    'video/msvideo',
    'video/vnd.divx',
    'video/avi',
    'video/x-avi',
    'application/vnd.rn-realmedia',
    'application/vnd.rn-realmedia-vbr',
    'audio/vnd.rn-realaudio',
    'audio/x-pn-realaudio',
    'audio/x-pn-realaudio-plugin',
    'audio/x-real-audio',
    'audio/x-realaudio',
    'video/vnd.rn-realvideo',
    'audio/mpeg',
    'audio/mpg',
    'audio/mp1',
    'audio/mp2',
    'audio/mp3',
    'audio/x-mp1',
    'audio/x-mp2',
    'audio/x-mp3',
    'audio/x-mpeg',
    'audio/x-mpg',
    'video/mp2t',
    'video/mpeg',
    'video/mpeg-system',
    'video/x-mpeg',
    'video/x-mpeg2',
    'video/x-mpeg-system',
    'application/mpeg4-iod',
    'application/mpeg4-muxcodetable',
    'application/x-extension-m4a',
    'application/x-extension-mp4',
    'audio/aac',
    'audio/m4a',
    'audio/mp4',
    'audio/x-m4a',
    'audio/x-aac',
    'video/mp4',
    'video/mp4v-es',
    'video/x-m4v',
    'application/x-quicktime-media-link',
    'application/x-quicktimeplayer',
    'video/quicktime',
    'application/x-matroska',
    'audio/x-matroska',
    'video/x-matroska',
    'video/webm',
    'audio/webm',
    'audio/3gpp',
    'audio/3gpp2',
    'audio/AMR',
    'audio/AMR-WB',
    'video/3gp',
    'video/3gpp',
    'video/3gpp2',
    'x-scheme-handler/mms',
    'x-scheme-handler/mmsh',
    'x-scheme-handler/rtsp',
    'x-scheme-handler/rtp',
    'x-scheme-handler/rtmp',
    'x-scheme-handler/icy',
    'x-scheme-handler/icyx',
    'application/x-cd-image',
    'x-content/video-vcd',
    'x-content/video-svcd',
    'x-content/video-dvd',
    'x-content/audio-cdda',
    'x-content/audio-player',
    'application/ram',
    'application/xspf+xml',
    'audio/mpegurl',
    'audio/x-mpegurl',
    'audio/scpls',
    'audio/x-scpls',
    'text/google-video-pointer',
    'text/x-google-video-pointer',
    'video/vnd.mpegurl',
    'application/vnd.apple.mpegurl',
    'application/vnd.ms-asf',
    'application/vnd.ms-wpl',
    'application/sdp',
    'audio/dv',
    'video/dv',
    'audio/x-aiff',
    'audio/x-pn-aiff',
    'video/x-anim',
    'video/x-nsv',
    'video/fli',
    'video/flv',
    'video/x-flc',
    'video/x-fli',
    'video/x-flv',
    'audio/wav',
    'audio/x-pn-au',
    'audio/x-pn-wav',
    'audio/x-wav',
    'audio/x-adpcm',
    'audio/ac3',
    'audio/eac3',
    'audio/vnd.dts',
    'audio/vnd.dts.hd',
    'audio/vnd.dolby.heaac.1',
    'audio/vnd.dolby.heaac.2',
    'audio/vnd.dolby.mlp',
    'audio/basic',
    'audio/midi',
    'audio/x-ape',
    'audio/x-gsm',
    'audio/x-musepack',
    'audio/x-tta',
    'audio/x-wavpack',
    'audio/x-shorten',
    'application/x-shockwave-flash',
    'application/x-flash-video',
    'misc/ultravox',
    'image/vnd.rn-realpix',
    'audio/x-it',
    'audio/x-mod',
    'audio/x-s3m',
    'audio/x-xm',
    'application/mxf',
  ];
}
