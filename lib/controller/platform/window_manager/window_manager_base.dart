part of 'window_manager.dart';

abstract class NamidaWindowManager {
  static NamidaWindowManager? platform() {
    return NamidaPlatformBuilder.init(
      android: () => null,
      ios: () => null,
      windows: () => _WindowManagerDesktop(),
      linux: () => _WindowManagerDesktop(),
      macos: () => _WindowManagerDesktop(),
    );
  }

  Future<void> init();
  Future<void> restorePosition();
}
