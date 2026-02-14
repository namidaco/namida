part of 'settings_controller.dart';

class _TutorialSettings with SettingsFileWriter {
  _TutorialSettings._internal();

  bool lyricsLongPressFullScreen = true;

  void save({
    bool? lyricsLongPressFullScreen,
  }) {
    if (lyricsLongPressFullScreen != null) this.lyricsLongPressFullScreen = lyricsLongPressFullScreen;
    _writeToStorage();
  }

  @override
  void applyKuruSettings() {}

  Future<void> prepareSettingsFile() async {
    final json = await prepareSettingsFile_();
    if (json is! Map) return;

    try {
      lyricsLongPressFullScreen = json['llpfs'] ?? lyricsLongPressFullScreen;
    } catch (e, st) {
      printy(e, isError: true);
      logger.report(e, st);
    }
  }

  @override
  Object get jsonToWrite => <String, dynamic>{
    'llpfs': lyricsLongPressFullScreen,
  };

  Future<void> _writeToStorage() async => await writeToStorage();

  @override
  String get filePath => AppPaths.SETTINGS_TUTORIAL;
}
