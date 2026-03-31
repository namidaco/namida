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
        NamidaTrayManager.showWindow();
      },
      onScroll: (delta, orientation) async {
        if (delta.isNegative) {
          Player.inst.volumeDown();
        } else {
          Player.inst.volumeUp();
        }
      },
      onActivate: (x, y) async {
        NamidaTrayManager.showWindow();
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
    final dbusMenu = menu.toDBusMenu(onTrayTap: NamidaTrayManager.showWindow);
    if (_clientFuture == null) {
      _clientFuture = _createClient(dbusMenu, playingItemTitle);
    } else {
      final c = await _clientFuture!;
      await c.updateMenu(dbusMenu);
      c.toolTip = _createToolTip(playingItemTitle);
    }
  }

  @override
  Future<void> destroy() async {
    await (await _clientFuture)?.close();
  }
}
