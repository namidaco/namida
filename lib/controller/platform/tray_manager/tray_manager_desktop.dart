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
  Future<void> update(Menu menu) async {
    await trayManager.setContextMenu(menu);
  }

  @override
  Future<void> destroy() async {
    trayManager.removeListener(this);
    await trayManager.destroy();
  }

  @override
  void onTrayIconMouseDown() => _showWindow();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case TrayMenuKey.playPause:
        Player.inst.togglePlayPause();
      case TrayMenuKey.previous:
        Player.inst.previous();
      case TrayMenuKey.next:
        Player.inst.next();
      case TrayMenuKey.showWindow:
        _showWindow();
      case TrayMenuKey.exit:
        await Namida.disposeAllResources().ignoreError();
        await windowManager.destroy().ignoreError();
    }
  }

  // Future<void> _toggleWindow() async {
  //   if (await windowManager.isVisible()) {
  //     await windowManager.hide();
  //   } else {
  //     await _showWindow();
  //   }
  // }

  Future<void> _showWindow() async {
    if (Platform.isLinux) {
      // trigger refresh, otherwise won't show mostly
      await windowManager.hide();
    }

    WindowController.instance?.ensurePositionRestored();
  }
}

class TrayMenuKey {
  TrayMenuKey._();

  static const String nowPlaying = 'now_playing';
  static const String previous = 'previous';
  static const String playPause = 'play_pause';
  static const String next = 'next';
  static const String showWindow = 'show_window';
  static const String exit = 'exit';
}
