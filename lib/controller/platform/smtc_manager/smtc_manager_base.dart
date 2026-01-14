part of 'smtc_manager.dart';

abstract class NamidaSMTCManager {
  static NamidaSMTCManager? platform() {
    return NamidaPlatformBuilder.init(
      android: () => null,
      ios: () => null,
      windows: () => _SMTCManagerWindows(),
      linux: () => _SMTCManagerLinux(),
    );
  }

  Future<void> init();

  void onPlayPause(bool playing) => playing ? onPlay() : onPause();
  void onPlay();
  void onPause();
  void onStop();
  Future<void> dispose();

  void updateMetadata(MediaItem mediaItem);
  void updateTimeline(int positionMS, int? durationMS);
}
