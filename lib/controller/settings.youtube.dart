part of 'settings_controller.dart';

class _YoutubeSettings with SettingsFileWriter {
  _YoutubeSettings._internal();

  final ytVisibleShorts = <YTVisibleShortPlaces, bool>{}.obs;
  final ytVisibleMixes = <YTVisibleMixesPlaces, bool>{}.obs;

  int addToPlaylistsTabIndex = 0;

  void save({int? addToPlaylistsTabIndex}) {
    if (addToPlaylistsTabIndex != null) this.addToPlaylistsTabIndex = addToPlaylistsTabIndex;
    _writeToStorage();
  }

  void updateShortsVisible(YTVisibleShortPlaces place, bool show) {
    ytVisibleShorts[place] = show;
    _writeToStorage();
  }

  void updateMixesVisible(YTVisibleMixesPlaces place, bool show) {
    ytVisibleMixes[place] = show;
    _writeToStorage();
  }

  Future<void> prepareSettingsFile() async {
    final json = await prepareSettingsFile_();
    if (json == null) return;
    try {
      ytVisibleShorts.value = (json['ytVisibleShorts'] as Map?)?.map((key, value) => MapEntry(YTVisibleShortPlaces.values.getEnum(key)!, value)) ?? {};
      ytVisibleMixes.value = (json['ytVisibleMixes'] as Map?)?.map((key, value) => MapEntry(YTVisibleMixesPlaces.values.getEnum(key)!, value)) ?? {};
      addToPlaylistsTabIndex = json['addToPlaylistsTabIndex'] ?? 0;
    } catch (e) {
      printy(e, isError: true);
    }
  }

  @override
  Object get jsonToWrite => <String, dynamic>{
        'ytVisibleShorts': ytVisibleShorts.map((key, value) => MapEntry(key.convertToString, value)),
        'ytVisibleMixes': ytVisibleMixes.map((key, value) => MapEntry(key.convertToString, value)),
        'addToPlaylistsTabIndex ': addToPlaylistsTabIndex,
      };

  Future<void> _writeToStorage() async => await writeToStorage();

  @override
  String get filePath => AppPaths.SETTINGS_YOUTUBE;
}
