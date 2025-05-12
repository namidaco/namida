// ignore_for_file: unused_element_parameter

part of 'shortcuts_manager.dart';

class _ShortcutsManagerDesktop extends ShortcutsManager {
  @override
  Future<void> init() async {
    if (kDebugMode) await hotKeyManager.unregisterAll();

    final keysToRegister = <_ShortcutKeyData>[
      _ShortcutKeyData(
        key: PhysicalKeyboardKey.escape,
        callback: () {
          if (NamidaNavigator.inst.isInFullScreen) {
            NamidaNavigator.inst.exitFullScreen();
          } else {
            NamidaNavigator.inst.popPage();
          }
        },
      ),
      _ShortcutKeyData(
        key: PhysicalKeyboardKey.f11,
        callback: () async {
          final isFullscreen = await windowManager.isFullScreen();
          windowManager.setFullScreen(!isFullscreen);
        },
      ),
    ];

    for (final k in keysToRegister) {
      _register(data: k);
    }
  }

  void _register({required _ShortcutKeyData data}) {
    hotKeyManager.register(
      HotKey(
        key: data.key,
        scope: data.scope,
        modifiers: data.modifiers,
      ),
      keyDownHandler: (_) {
        data.callback();
      },
    );
  }
}

class _ShortcutKeyData {
  final KeyboardKey key;
  final List<HotKeyModifier>? modifiers;
  final HotKeyScope scope;
  final VoidCallback callback;

  _ShortcutKeyData({
    required this.key,
    this.modifiers,
    this.scope = HotKeyScope.inapp,
    required this.callback,
  });
}
