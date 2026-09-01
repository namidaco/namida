part of 'window_manager.dart';

abstract class NamidaWindowManager {
  static const appId = "94dba250-1e0f-11f0-846e-a101934a6b13"; // same as the one for inno setup in pubspec.yaml

  bool get usingCustomWindowTitleBar;
  double get windowTitleBarHeightIfActive => usingCustomWindowTitleBar ? kWindowTitleBarHeight : 0.0;
  double kWindowTitleBarHeight = 32.0;

  final bool customRoundedCorners;
  NamidaWindowManager({this.customRoundedCorners = false});

  static NamidaWindowManager? platform() {
    return NamidaPlatformBuilder.init(
      android: () => null,
      ios: () => null,
      windows: () => _WindowManagerDesktop(customRoundedCorners: false),
      linux: () => _WindowManagerDesktop(),
      macos: () => _WindowManagerDesktop(),
    );
  }

  Future<void> init();
  Future<void> restorePosition();
  Future<void> ensurePositionRestored({bool isStartup = true});

  // ================== Mini Lyrics Window ==================

  static final isMiniLyricsMode = false.obs;

  bool get inMiniLyricsMode => isMiniLyricsMode.value;

  static const kMiniLyricsDefaultSize = Size(620.0, 92.0);
  static const kMiniLyricsMinSize = Size(120.0, 48.0);

  Future<void> enterMiniLyricsMode();
  Future<void> exitMiniLyricsMode();

  Future<void> toggleMiniLyricsMode() async {
    if (isMiniLyricsMode.value) {
      await exitMiniLyricsMode();
    } else {
      await enterMiniLyricsMode();
    }
  }
}
