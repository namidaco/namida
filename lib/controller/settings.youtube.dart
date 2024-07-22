part of 'settings_controller.dart';

class _YoutubeSettings with SettingsFileWriter {
  _YoutubeSettings._internal();

  final ytVisibleShorts = <YTVisibleShortPlaces, bool>{}.obs;
  final ytVisibleMixes = <YTVisibleMixesPlaces, bool>{}.obs;

  bool markVideoWatched = true;
  int addToPlaylistsTabIndex = 0;

  void save({
    int? addToPlaylistsTabIndex,
    bool? markVideoWatched,
  }) {
    if (addToPlaylistsTabIndex != null) this.addToPlaylistsTabIndex = addToPlaylistsTabIndex;
    if (markVideoWatched != null) this.markVideoWatched = markVideoWatched;
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
      ytVisibleShorts.value = (json['ytVisibleShorts'] as Map?)?.map((key, value) => MapEntry(YTVisibleShortPlaces.values.getEnum(key)!, value)) ?? ytVisibleShorts.value;
      ytVisibleMixes.value = (json['ytVisibleMixes'] as Map?)?.map((key, value) => MapEntry(YTVisibleMixesPlaces.values.getEnum(key)!, value)) ?? ytVisibleMixes.value;
      addToPlaylistsTabIndex = json['addToPlaylistsTabIndex'] ?? addToPlaylistsTabIndex;
      markVideoWatched = json['markVideoWatched'] ?? markVideoWatched;
    } catch (e) {
      printy(e, isError: true);
    }
  }

  @override
  Object get jsonToWrite => <String, dynamic>{
        'ytVisibleShorts': ytVisibleShorts.map((key, value) => MapEntry(key.convertToString, value)),
        'ytVisibleMixes': ytVisibleMixes.map((key, value) => MapEntry(key.convertToString, value)),
        'addToPlaylistsTabIndex ': addToPlaylistsTabIndex,
        'markVideoWatched ': markVideoWatched,
      };

  Future<void> _writeToStorage() async => await writeToStorage();

  @override
  String get filePath => AppPaths.SETTINGS_YOUTUBE;
}
