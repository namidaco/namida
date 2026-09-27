part of 'settings_controller.dart';

class _ShortcutsSettings extends _SettingsKeysWriter {
  _ShortcutsSettings._internal();

  late final shortcuts = _keyMap<HotkeyAction, ShortcutKeyData?>(
    'shortcuts',
    const {},
    key: HotkeyAction.values.asCodec(),
    value: _ObjectCodec(ShortcutKeyData.fromMap, (v) => v?.toMap()),
  );

  @override
  String get filePath => AppPaths.SETTINGS_SHORTCUTS;
}
