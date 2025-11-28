part of 'settings_controller.dart';

class _ShortcutsSettings with SettingsFileWriter {
  _ShortcutsSettings._internal();

  final shortcuts = <HotkeyAction, ShortcutKeyData?>{}.obs;

  void save({
    required HotkeyAction action,
    required ShortcutKeyData? data,
  }) {
    shortcuts.value[action] = data;
    shortcuts.refresh();
    _writeToStorage();
  }

  @override
  void applyKuruSettings() {}

  Future<void> prepareSettingsFile() async {
    final json = await prepareSettingsFile_();
    if (json is! Map) return;

    try {
      final shortcutsRaw = json['shortcuts'] as Map<String, dynamic>? ?? {};
      for (final e in shortcutsRaw.entries) {
        final action = HotkeyAction.values.getEnum(e.key);
        if (action == null) continue;
        final data = e.value == null ? null : ShortcutKeyData.fromMap(e.value);
        shortcuts.value[action] = data;
      }
    } catch (e, st) {
      printy(e, isError: true);
      logger.report(e, st);
    }
  }

  @override
  Object get jsonToWrite => <String, dynamic>{
        'shortcuts': shortcuts.value.map((key, value) => MapEntry(key.name, value?.toMap())),
      };

  Future<void> _writeToStorage() async => await writeToStorage();

  @override
  String get filePath => AppPaths.SETTINGS_SHORTCUTS;
}
