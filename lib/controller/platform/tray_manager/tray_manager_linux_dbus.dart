part of 'tray_manager.dart';

class _TrayManagerLinuxDBus extends NamidaTrayManager {
  _TrayManagerLinuxDBus(super.iconPath);

  Future<StatusNotifierItemClient>? _clientFuture;

  static const _iconName = 'namida';

  @override
  Future<void> init() async {}

  Future<StatusNotifierItemClient> _createClient(DBusMenuItem menu, String playingItemTitle) async {
    final c = StatusNotifierItemClient(
      id: 'com.msob7y.namida',
      iconName: _iconName,
      title: NamidaTrayManager._trayTitle,
      menu: menu,
      toolTip: _createToolTip(playingItemTitle),
      category: StatusNotifierItemCategory.applicationStatus,
      status: StatusNotifierItemStatus.active,
      onContextMenu: (x, y) async {
        NamidaTrayManager.toggleWindow();
      },
      onScroll: (delta, orientation) async {
        if (delta.isNegative) {
          final newVol = Player.inst.volumeDown();
          snackyy(message: "${lang.volume} ↓: ${newVol.roundDecimals(2)}");
        } else {
          final newVol = Player.inst.volumeUp();
          snackyy(message: "${lang.volume} ↑: ${newVol.roundDecimals(2)}");
        }
      },
      onActivate: (x, y) async {
        NamidaTrayManager.toggleWindow();
      },
      onSecondaryActivate: (x, y) async {
        NamidaTrayManager.executeKey(TrayMenuKey.playPause);
      },
    );

    await c.connect();
    return c;
  }

  StatusNotifierToolTip _createToolTip(String playingItemTitle) {
    return StatusNotifierToolTip(
      iconName: _iconName,
      iconPixmap: [],
      title: NamidaTrayManager._trayTitle,
      body: playingItemTitle,
    );
  }

  @override
  Future<void> update(TrayMenu menu, String playingItemTitle) async {
    try {
      final dbusMenu = menu.toDBusMenu(onTrayTap: NamidaTrayManager.toggleWindow);
      if (_clientFuture == null) {
        _clientFuture = _createClient(dbusMenu, playingItemTitle);
      } else {
        final c = await _clientFuture!;
        await c.updateMenu(dbusMenu);
        c.toolTip = _createToolTip(playingItemTitle);
      }
    } on DBusClosedException catch (_) {}
  }

  @override
  Future<void> dispose() async {
    await (await _clientFuture)?.close();
  }
}
