part of 'tray_manager.dart';

class _TrayManagerDesktop extends NamidaTrayManager with TrayListener {
  const _TrayManagerDesktop(super.iconPath);

  /// macos menu bar items are monochrome templates that open their menu on click, and show their title as text.
  static final _isMenuBarItem = Platform.isMacOS;

  @override
  Future<void> init() async {
    trayManager.addListener(this);
    await trayManager.setIcon(iconPath, isTemplate: _isMenuBarItem);
    if (!_isMenuBarItem) {
      try {
        await trayManager.setTitle('Namida');
      } on MissingPluginException catch (_) {}
    }
    try {
      await trayManager.setToolTip('Namida');
    } on MissingPluginException catch (_) {}
  }

  @override
  Future<void> update(TrayMenu menu, String playingItemTitle) async {
    await trayManager.setContextMenu(menu.toDefaultMenu());
  }

  /// a long title pushes other items out of the menu bar.
  static const _kMaxLyricsLineLength = 48;

  @override
  Future<void> setLyricsLine(String? line) async {
    if (!_isMenuBarItem) return;
    final shownLine = line == null ? '' : _fitLyricsLine(line);
    await trayManager.setTitle(shownLine);
  }

  /// cut by characters, so an emoji is never split in half.
  static String _fitLyricsLine(String line) {
    final characters = line.characters;
    if (characters.length <= _kMaxLyricsLineLength) return line;
    final kept = characters.take(_kMaxLyricsLineLength - 1);
    return '$kept…';
  }

  @override
  Future<void> dispose() async {
    trayManager.removeListener(this);
    await trayManager.destroy();
  }

  @override
  void onTrayIconMouseDown() => _isMenuBarItem ? trayManager.popUpContextMenu() : NamidaTrayManager.toggleWindow();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayThemeChanged(bool isSystemThemeLight) {
    TrayIcons.refreshIsWindowsSystemThemeLight(isSystemThemeLight);
    Player.inst.refreshPlatformIcons();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    NamidaTrayManager.executeKey(menuItem.key);
  }
}
