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

  late final Map<ShortcutKeyData, VoidCallback> bindings = Map.fromEntries(_keysToRegister.map(
    (e) => MapEntry(
      e,
      e.callback,
    ),
  ));

  @protected
  List<ShortcutKeyData> get _keysToRegister;
  void init();
  void dispose();

  void openPlayerQueue();
}

class ShortcutKeyData extends SingleActivator {
  final String title;
  final LogicalKeyboardKey key;
  final void Function() callback;

  const ShortcutKeyData({
    required this.title,
    required this.key,
    super.control = false,
    super.shift = false,
    super.includeRepeats = false,
    required this.callback,
  }) : super(key);
}
