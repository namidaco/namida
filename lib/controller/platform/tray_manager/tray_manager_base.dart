part of 'tray_manager.dart';

abstract class NamidaTrayManager {
  final String iconPath;
  const NamidaTrayManager(this.iconPath);

  static NamidaTrayManager? platform() {
    return NamidaPlatformBuilder.init(
      android: () => null,
      ios: () => null,
      windows: () => _TrayManagerDesktop(TrayIcons.windows.appIcon),
      linux: () => _TrayManagerDesktop(NamidaAppIcons.mini.assetPath),
      macos: () => _TrayManagerDesktop(NamidaAppIcons.mini.assetPath),
    );
  }

  Future<void> init();
  Future<void> update(Menu menu);
  Future<void> destroy();
}
