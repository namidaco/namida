part of 'settings_controller.dart';

class _TutorialSettings extends _SettingsKeysWriter {
  _TutorialSettings._internal();

  late final lyricsFullscreenTipSeen = _key('llpfsSeen', false);
  late final snackbarDismissHintCount = _key('snackDismissHints', 0);

  @override
  void _migrateLegacy() {
    _migrateKey('llpfs', 'llpfsSeen', (json) => json == false ? true : null);
  }

  @override
  String get filePath => AppPaths.SETTINGS_TUTORIAL;
}
