part of 'shortcuts_manager.dart';

abstract class ShortcutsManager {
  static ShortcutsManager? platform() {
    return NamidaPlatformBuilder.init(
      android: () => null,
      ios: () => null,
      windows: () => _ShortcutsManagerDesktop(),
      linux: () => _ShortcutsManagerDesktop(),
      macos: () => _ShortcutsManagerDesktop(),
    );
  }

  Future<void> init();
}
