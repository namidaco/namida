part of 'smtc_manager.dart';

class _SMTCManagerWindows extends NamidaSMTCManager {
  swin.SMTCWindows? smtc;

  @override
  Future<void> init() async {
    try {
      await swin.SMTCWindows.initialize();
      smtc = swin.SMTCWindows(
        appId: NamidaWindowManager.appId,
        enabled: true,
        config: const swin.SMTCConfig(
          fastForwardEnabled: true,
          nextEnabled: true,
          pauseEnabled: true,
          playEnabled: true,
          rewindEnabled: true,
          prevEnabled: true,
          stopEnabled: true,
        ),
      );

      smtc?.buttonPressStream.listen((event) {
        switch (event) {
          case swin.PressedButton.play:
            Player.inst.togglePlayPause();
          case swin.PressedButton.pause:
            Player.inst.pause();
          case swin.PressedButton.next:
            Player.inst.next();
          case swin.PressedButton.previous:
            Player.inst.previous();
          case swin.PressedButton.stop:
            Player.inst.pause().whenComplete(Player.inst.dispose);
          case swin.PressedButton.fastForward:
            Player.inst.seekSecondsForward();
          case swin.PressedButton.rewind:
            Player.inst.seekSecondsBackward();

          // -- none
          case swin.PressedButton.record:
          case swin.PressedButton.channelUp:
          case swin.PressedButton.channelDown:
        }
      });
    } catch (e, st) {
      logger.error('Failed to initialize SMTCWindows', e: e, st: st);
    }
  }

  bool _isEnabled = true;

  void _ensureEnabled() {
    if (_isEnabled) return;
    smtc?.enableSmtc();
  }

  @override
  void onPlay() {
    _ensureEnabled();
    smtc?.setPlaybackStatus(swin.PlaybackStatus.playing);
  }

  @override
  void onPause() {
    _ensureEnabled();
    smtc?.setPlaybackStatus(swin.PlaybackStatus.paused);
  }

  @override
  void onStop() {
    if (_isEnabled == false) return;
    _isEnabled = false;
    smtc?.setPlaybackStatus(swin.PlaybackStatus.stopped);
    smtc?.disableSmtc();
  }

  @override
  Future<void> dispose() async {
    _isEnabled = false;
    smtc?.setPlaybackStatus(swin.PlaybackStatus.stopped);
    await smtc?.dispose();
    smtc = null;
  }

  @override
  void updateMetadata(MediaItem mediaItem) {
    _ensureEnabled();
    final metadata = swin.MusicMetadata(
      title: mediaItem.title,
      artist: mediaItem.artist,
      album: mediaItem.album,
      albumArtist: null,
      thumbnail: mediaItem.artUri?.toFilePathWindows_(),
    );
    smtc?.updateMetadata(metadata);
  }

  @override
  void updateTimeline(int positionMS, int? durationMS) {
    _ensureEnabled();
    smtc?.updateTimeline(
      swin.PlaybackTimeline(
        startTimeMs: 0,
        endTimeMs: durationMS ?? 0,
        positionMs: positionMS,
      ),
    );
  }
}

extension _UriUtils on Uri {
  String toFilePathWindows_() {
    return toFilePath(windows: true);
  }
}
