import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';

class WakelockController {
  static final WakelockController inst = WakelockController._internal();
  WakelockController._internal();

  bool _isMiniplayerExpanded = false;
  bool _isFullScreen = false;
  bool _isVideoAvailable = false;
  bool _isPlaying = false;
  bool _isLRCAvailable = false;

  /// An LRC is automatically considered to be a video (tehe).
  bool get _isVideoAvailableAndPlaying => (_isVideoAvailable || _isLRCAvailable) && _isPlaying;

  WakelockMode get _userWakelockMode => settings.wakelockMode.value;

  void updateMiniplayerStatus(bool expanded) {
    _isMiniplayerExpanded = expanded;
    _reEvaluate();
  }

  void updateFullscreenStatus(bool fullscreen) {
    _isFullScreen = fullscreen;
    _reEvaluate();
  }

  /// Should be called whenever a video is loaded/unloaded.
  void updateVideoStatus(bool videoAvailable) {
    _isVideoAvailable = videoAvailable;
    _reEvaluate();
  }

  void updatePlayPauseStatus(bool playing) {
    _isPlaying = playing;
    _reEvaluate();
  }

  void updateLRCStatus(bool hasLRC) {
    _isLRCAvailable = hasLRC;
    _reEvaluate();
  }

  void _reEvaluate() {
    if (_isFullScreen) {
      // -- user pref is ignored in fullscreen.
      if (_isVideoAvailableAndPlaying) {
        _enable();
      } else {
        _disable();
      }
      return;
    }
    if (_userWakelockMode == WakelockMode.expandedAndVideo && _isMiniplayerExpanded && _isVideoAvailableAndPlaying) {
      _enable();
    } else if (_userWakelockMode == WakelockMode.expanded && _isMiniplayerExpanded) {
      _enable();
    } else {
      // -- if none was evaluated, or user pref == WakelockMode.none, we disable wakelock
      _disable();
    }
  }

  void _enable() {
    WakelockPlus.enable();
  }

  void _disable() {
    WakelockPlus.disable();
  }
}
