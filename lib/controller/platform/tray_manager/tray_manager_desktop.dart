part of 'tray_manager.dart';

class _TrayManagerDesktop extends NamidaTrayManager with TrayListener {
  const _TrayManagerDesktop(super.iconPath);

  @override
  Future<void> init() async {
    trayManager.addListener(this);
    await trayManager.setIcon(iconPath);
    try {
      await trayManager.setTitle('Namida');
    } on MissingPluginException catch (_) {}
    try {
      await trayManager.setToolTip('Namida');
    } on MissingPluginException catch (_) {}
  }

  @override
  Future<void> update(TrayMenu menu, String playingItemTitle) async {
    await trayManager.setContextMenu(menu.toDefaultMenu());
  }

  @override
  Future<void> destroy() async {
    trayManager.removeListener(this);
    await trayManager.destroy();
  }

  @override
  void onTrayIconMouseDown() => NamidaTrayManager.showWindow();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    NamidaTrayManager.executeKey(menuItem.key);
  }
}
