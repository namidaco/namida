part of 'tray_manager.dart';

abstract class NamidaTrayManager {
  static const String _trayTitle = 'Namida';

  final String iconPath;
  const NamidaTrayManager(this.iconPath);

  static NamidaTrayManager? platform() {
    return NamidaPlatformBuilder.init(
      android: () => null,
      ios: () => null,
      windows: () => _TrayManagerDesktop(TrayIcons.windows.appIcon),
      linux: () => _TrayManagerLinuxDBus(),
      macos: () => _TrayManagerDesktop(''),
    );
  }

  static Future<void> toggleWindow() async {
    if (await windowManager.isVisible()) {
      await NamidaTrayManager.hideWindow();
    } else {
      await NamidaTrayManager.showWindow();
    }
  }

  static bool wasMaximized = false;

  static Future<void> showWindow() async {
    if (Platform.isLinux) {
      // trigger refresh, otherwise won't show mostly
      await windowManager.hide();
    }

    WindowController.instance?.ensurePositionRestored();
  }

  static Future<void> hideWindow() async {
    wasMaximized = await windowManager.isMaximized();
    await windowManager.hide();
  }

  static void executeKey(String? key) async {
    switch (key) {
      case TrayMenuKey.playPause:
        Player.inst.togglePlayPause().ignoreError();
      case TrayMenuKey.previous:
        Player.inst.previous().ignoreError();
      case TrayMenuKey.next:
        Player.inst.next().ignoreError();
      case TrayMenuKey.showWindow:
        await showWindow();
      case TrayMenuKey.exit:
        await Namida.disposeAllResourcesAndExit();
      case null:
    }
  }

  Future<void> init();
  Future<void> update(TrayMenu menu, String playingItemTitle);
  Future<void> dispose();
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

class TrayMenu {
  final List<TrayMenuItem> items;

  const TrayMenu({required this.items});

  Menu toDefaultMenu() {
    return Menu(
      items: items
          .map(
            (e) => e._isSeparator
                ? MenuItem.separator()
                : MenuItem(
                    key: e.key,
                    icon: e.icon,
                    label: e.label,
                    disabled: e.disabled,
                  ),
          )
          .toList(),
    );
  }

  DBusMenuItem toDBusMenu({required Future<void> Function() onTrayTap}) {
    return DBusMenuItem(
      label: NamidaTrayManager._trayTitle,
      onClicked: onTrayTap,
      children: items.map(
        (e) {
          if (e._isSeparator) {
            return DBusMenuItem.separator();
          }
          String label = e.label;
          String? icon = e.icon;
          if (icon != null) {
            // -- linux tray menu items don't support icons
            // -- we use text icons
            label = '$icon  $label';
          }
          return DBusMenuItem(
            label: label,
            enabled: !e.disabled,
            onClicked: () async => NamidaTrayManager.executeKey(e.key),
          );
        },
      ).toList(),
    );
  }
}

class TrayMenuItem {
  final String key;
  final String label;
  final String? icon;
  final bool disabled;
  final bool _isSeparator;

  const TrayMenuItem({
    required this.key,
    required this.label,
    required this.icon,
    this.disabled = false,
  }) : _isSeparator = false;

  const TrayMenuItem.separator() : key = '', label = '', icon = null, disabled = true, _isSeparator = true;
}
