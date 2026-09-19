// by claude
// unused: `package:nativeapi` tray port (rewrite of `package:tray_manager`), worse on every platform:
//
// - windows: worse menu/icon rendering, no tray theme event, raster-only item icons.
// - linux: click/middle-click/scroll emit no events, hardcoded SNI id, no tooltip or item icons.
// - `MenuItem.addListener` leaks NativeCallables, hence the item pool below.
//
// to re-enable: add `nativeapi` to pubspec, uncomment, re-add the part + `na`/widgets imports in
// tray_manager.dart, then point `NamidaTrayManager.platform()` at `_TrayManagerNativeApi`.

// part of 'tray_manager.dart';
//
// class _TrayManagerNativeApi extends NamidaTrayManager {
//   _TrayManagerNativeApi(super.iconPath);
//
//   /// linux menu items don't support icons, we use text icons instead.
//   static final _useTextIcons = Platform.isLinux;
//
//   static final _imagesCache = <String, na.Image?>{};
//
//   na.TrayIcon? _trayIcon;
//   na.Menu? _menu;
//   List<TrayMenuItem>? _lastItems;
//   String? _lastTooltip;
//
//   final _itemsPool = <String, na.MenuItem>{};
//   final _nativeItems = <na.MenuItem>[];
//
//   _TrayThemeObserver? _themeObserver;
//
//   @override
//   Future<void> init() async {
//     final trayIcon = na.TrayIcon.create();
//     if (trayIcon == null) return;
//     _trayIcon = trayIcon;
//
//     String iconPath = this.iconPath;
//     if (iconPath.isEmpty && Platform.isLinux) iconPath = await Indexer.createDefaultNamidaArtworkIfRequired();
//     if (iconPath.isNotEmpty) trayIcon.icon = _imageFor(iconPath);
//
//     trayIcon.isIconTemplate = Platform.isMacOS;
//     trayIcon.setTitle(NamidaTrayManager._trayTitle);
//     trayIcon.setTooltip(NamidaTrayManager._trayTitle);
//     trayIcon.setContextMenuTrigger(na.ContextMenuTrigger.rightClicked);
//     trayIcon.addListener(_onTrayEvent);
//     trayIcon.setVisible(true);
//
//     if (Platform.isWindows) {
//       final observer = _TrayThemeObserver();
//       _themeObserver = observer;
//       WidgetsBinding.instance.addObserver(observer);
//     }
//   }
//
//   @override
//   Future<void> update(TrayMenu menu, String playingItemTitle) async {
//     final trayIcon = _trayIcon;
//     if (trayIcon == null) return;
//
//     final tooltip = playingItemTitle.isEmpty ? NamidaTrayManager._trayTitle : playingItemTitle;
//     if (_lastTooltip != tooltip) {
//       _lastTooltip = tooltip;
//       trayIcon.setTooltip(tooltip);
//     }
//
//     final items = menu.items;
//     final lastItems = _lastItems;
//     if (lastItems == null || !_sameStructure(lastItems, items)) {
//       _buildMenu(items);
//     } else {
//       for (int i = 0; i < items.length; i++) {
//         _applyItem(_nativeItems[i], lastItems[i], items[i]);
//       }
//     }
//     _lastItems = items;
//   }
//
//   @override
//   Future<void> dispose() async {
//     final observer = _themeObserver;
//     if (observer != null) {
//       WidgetsBinding.instance.removeObserver(observer);
//       _themeObserver = null;
//     }
//
//     _trayIcon
//       ?..setVisible(false)
//       ..dispose();
//     _trayIcon = null;
//
//     _menu?.dispose();
//     _menu = null;
//
//     for (final item in _itemsPool.values) {
//       item.dispose();
//     }
//     _itemsPool.clear();
//     _nativeItems.clear();
//     _lastItems = null;
//   }
//
//   void _onTrayEvent(na.TrayIconEvent event) {
//     if (event is na.TrayIconClickedEvent) NamidaTrayManager.toggleWindow();
//   }
//
//   /// rebuilding reuses pooled items, so their native click listeners are never re-registered.
//   void _buildMenu(List<TrayMenuItem> items) {
//     var menu = _menu;
//     if (menu == null) {
//       menu = na.Menu.create();
//       if (menu == null) return;
//       if (na.Menu.isBackendSupported(na.MenuBackend.winUi3)) menu.setBackend(na.MenuBackend.winUi3);
//       _menu = menu;
//     } else {
//       menu.clear();
//     }
//
//     _nativeItems.clear();
//
//     int separatorIndex = 0;
//     for (final item in items) {
//       final isSeparator = item._isSeparator;
//       final poolKey = isSeparator ? '@sep${separatorIndex++}' : item.key;
//       var nativeItem = _itemsPool[poolKey];
//       if (nativeItem == null) {
//         nativeItem = na.MenuItem.createWithLabelAndType(
//           _labelFor(item),
//           isSeparator ? na.MenuItemType.separator : na.MenuItemType.normal,
//         );
//         if (nativeItem == null) continue;
//         if (!isSeparator) {
//           final key = item.key;
//           nativeItem.addListener((event) {
//             if (event is na.MenuItemClickedEvent) NamidaTrayManager.executeKey(key);
//           });
//         }
//         _itemsPool[poolKey] = nativeItem;
//       }
//       _applyItem(nativeItem, null, item);
//       menu.addItem(nativeItem);
//       _nativeItems.add(nativeItem);
//     }
//
//     _trayIcon?.setContextMenu(menu);
//   }
//
//   static void _applyItem(na.MenuItem target, TrayMenuItem? old, TrayMenuItem item) {
//     if (item._isSeparator) return;
//
//     final iconChanged = old == null || old.icon != item.icon;
//
//     if (old == null || old.label != item.label || (iconChanged && _useTextIcons)) target.label = _labelFor(item);
//
//     if (iconChanged && !_useTextIcons) {
//       final icon = item.icon;
//       target.icon = icon == null ? null : _imageFor(icon);
//     }
//
//     if (old == null || old.disabled != item.disabled) target.isEnabled = !item.disabled;
//   }
//
//   static String _labelFor(TrayMenuItem item) {
//     final icon = item.icon;
//     if (_useTextIcons && icon != null) return '$icon  ${item.label}';
//     return item.label;
//   }
//
//   static na.Image? _imageFor(String path) {
//     return _imagesCache.putIfAbsent(path, () => na.Image.fromFile(path));
//   }
//
//   static bool _sameStructure(List<TrayMenuItem> a, List<TrayMenuItem> b) {
//     if (a.length != b.length) return false;
//     for (int i = 0; i < a.length; i++) {
//       if (a[i].key != b[i].key) return false;
//     }
//     return true;
//   }
// }
//
// /// nativeapi has no tray theme event, flutter's brightness change is used as a trigger,
// /// the actual value is then re-read from the registry.
// class _TrayThemeObserver with WidgetsBindingObserver {
//   @override
//   void didChangePlatformBrightness() {
//     TrayIcons.refreshIsWindowsSystemThemeLight();
//     Player.inst.refreshPlatformIcons();
//   }
// }
