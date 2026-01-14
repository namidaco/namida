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
  Future<void> ensurePositionRestored();
}
