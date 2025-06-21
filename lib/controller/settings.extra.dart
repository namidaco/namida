part of 'settings_controller.dart';

class _ExtraSettings with SettingsFileWriter {
  _ExtraSettings._internal();

  final selectedLibraryTab = LibraryTab.tracks.obs;
  final staticLibraryTab = LibraryTab.tracks.obs;
  final autoLibraryTab = true.obs;
  final ytInitialHomePage = YTHomePages.playlists.obs;

  int lastPlayedIndex = 0;

  int ytAddToPlaylistsTabIndex = 0;

  void save({
    LibraryTab? selectedLibraryTab,
    LibraryTab? staticLibraryTab,
    bool? autoLibraryTab,
    YTHomePages? ytInitialHomePage,
    int? lastPlayedIndex,
    int? ytAddToPlaylistsTabIndex,
  }) {
    if (selectedLibraryTab != null) this.selectedLibraryTab.value = selectedLibraryTab;
    if (staticLibraryTab != null) this.staticLibraryTab.value = staticLibraryTab;
    if (autoLibraryTab != null) this.autoLibraryTab.value = autoLibraryTab;
    if (ytInitialHomePage != null) this.ytInitialHomePage.value = ytInitialHomePage;
    if (lastPlayedIndex != null) this.lastPlayedIndex = lastPlayedIndex;
    if (ytAddToPlaylistsTabIndex != null) this.ytAddToPlaylistsTabIndex = ytAddToPlaylistsTabIndex;
    _writeToStorage();
  }

  @override
  void applyKuruSettings() {
    selectedLibraryTab.value = LibraryTab.playlists;
    staticLibraryTab.value = LibraryTab.playlists;
  }

  Future<void> prepareSettingsFile() async {
    final json = await prepareSettingsFile_();
    if (json is! Map) return;

    try {
      final autoLibraryTabFinal = json['autoLibraryTab'] ?? autoLibraryTab.value;
      staticLibraryTab.value = LibraryTab.values.getEnum(json['staticLibraryTab']) ?? staticLibraryTab.value;
      selectedLibraryTab.value = autoLibraryTabFinal
          ? LibraryTab.values.getEnum(json['selectedLibraryTab']) ?? selectedLibraryTab.value
          : LibraryTab.values.getEnum(json['staticLibraryTab']) ?? staticLibraryTab.value;
      autoLibraryTab.value = autoLibraryTabFinal;
      ytInitialHomePage.value = YTHomePages.values.getEnum(json['ytInitialHomePage']) ?? ytInitialHomePage.value;

      lastPlayedIndex = json['lastPlayedIndex'] ?? lastPlayedIndex;
      ytAddToPlaylistsTabIndex = json['ytAddToPlaylistsTabIndex'] ?? ytAddToPlaylistsTabIndex;
    } catch (e) {
      printy(e, isError: true);
    }
  }

  @override
  Object get jsonToWrite => <String, dynamic>{
        'selectedLibraryTab': selectedLibraryTab.value.name,
        'staticLibraryTab': staticLibraryTab.value.name,
        'autoLibraryTab': autoLibraryTab.value,
        'ytInitialHomePage': ytInitialHomePage.value.name,
        'lastPlayedIndex': lastPlayedIndex,
        'ytAddToPlaylistsTabIndex': ytAddToPlaylistsTabIndex,
      };

  Future<void> _writeToStorage() async => await writeToStorage();

  @override
  String get filePath => AppPaths.SETTINGS_EXTRA;
}
