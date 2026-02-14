part of 'settings_controller.dart';

class _ExtraSettings with SettingsFileWriter {
  _ExtraSettings._internal();

  int getPreferredTabIndexIfLoggedInYT() {
    final activeChannel = YoutubeAccountController.current.activeAccountChannel.value;
    if (activeChannel != null) return 1;
    return 0;
  }

  final selectedLibraryTab = LibraryTab.tracks.obs;
  final staticLibraryTab = LibraryTab.tracks.obs;
  final autoLibraryTab = true.obs;
  final ytInitialHomePage = YTHomePages.playlists.obs;

  bool? tapToScroll;
  bool? enhancedDragToScroll;
  bool? smoothScrolling;
  bool? floatingArtworkEffect;
  bool? tiltingCardsEffect;
  bool? mediaWaveHaptic;
  bool? artistAlbumsExpanded;
  bool? artistSinglesExpanded;

  int lastPlayedIndex = 0;

  int? ytAddToPlaylistsTabIndex;
  int? ytPlaylistsPageIndex;
  int? ytChannelsPageIndex;

  void save({
    LibraryTab? selectedLibraryTab,
    LibraryTab? staticLibraryTab,
    bool? autoLibraryTab,
    YTHomePages? ytInitialHomePage,
    bool? tapToScroll,
    bool? enhancedDragToScroll,
    bool? smoothScrolling,
    bool? floatingArtworkEffect,
    bool? tiltingCardsEffect,
    bool? mediaWaveHaptic,
    bool? artistAlbumsExpanded,
    bool? artistSinglesExpanded,
    int? lastPlayedIndex,
    int? ytAddToPlaylistsTabIndex,
    int? ytPlaylistsPageIndex,
    int? ytChannelsPageIndex,
  }) {
    if (selectedLibraryTab != null) this.selectedLibraryTab.value = selectedLibraryTab;
    if (staticLibraryTab != null) this.staticLibraryTab.value = staticLibraryTab;
    if (autoLibraryTab != null) this.autoLibraryTab.value = autoLibraryTab;
    if (ytInitialHomePage != null) this.ytInitialHomePage.value = ytInitialHomePage;
    if (tapToScroll != null) this.tapToScroll = tapToScroll;
    if (enhancedDragToScroll != null) this.enhancedDragToScroll = enhancedDragToScroll;
    if (smoothScrolling != null) this.smoothScrolling = smoothScrolling;
    if (floatingArtworkEffect != null) this.floatingArtworkEffect = floatingArtworkEffect;
    if (tiltingCardsEffect != null) this.tiltingCardsEffect = tiltingCardsEffect;
    if (mediaWaveHaptic != null) this.mediaWaveHaptic = mediaWaveHaptic;
    if (artistAlbumsExpanded != null) this.artistAlbumsExpanded = artistAlbumsExpanded;
    if (artistSinglesExpanded != null) this.artistSinglesExpanded = artistSinglesExpanded;
    if (lastPlayedIndex != null) this.lastPlayedIndex = lastPlayedIndex;
    if (ytAddToPlaylistsTabIndex != null) this.ytAddToPlaylistsTabIndex = ytAddToPlaylistsTabIndex;
    if (ytPlaylistsPageIndex != null) this.ytPlaylistsPageIndex = ytPlaylistsPageIndex;
    if (ytChannelsPageIndex != null) this.ytChannelsPageIndex = ytChannelsPageIndex;
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

      tapToScroll = json['tapToScroll'] ?? tapToScroll;
      enhancedDragToScroll = json['enhancedDragToScroll'] ?? enhancedDragToScroll;
      smoothScrolling = json['smoothScrolling'] ?? smoothScrolling;
      floatingArtworkEffect = json['floatingArtworkEffect'] ?? floatingArtworkEffect;
      tiltingCardsEffect = json['tiltingCardsEffect'] ?? tiltingCardsEffect;
      mediaWaveHaptic = json['mediaWaveHaptic'] ?? mediaWaveHaptic;
      artistAlbumsExpanded = json['artistAlbumsExpanded'] ?? artistAlbumsExpanded;
      artistSinglesExpanded = json['artistSinglesExpanded'] ?? artistSinglesExpanded;
      lastPlayedIndex = json['lastPlayedIndex'] ?? lastPlayedIndex;
      ytAddToPlaylistsTabIndex = json['ytAddToPlaylistsTabIndex'] ?? ytAddToPlaylistsTabIndex;
      ytPlaylistsPageIndex = json['ytPlaylistsPageIndex'] ?? ytPlaylistsPageIndex;
      ytChannelsPageIndex = json['ytChannelsPageIndex'] ?? ytChannelsPageIndex;
    } catch (e, st) {
      printy(e, isError: true);
      logger.report(e, st);
    }
  }

  @override
  Object get jsonToWrite => <String, dynamic>{
    'selectedLibraryTab': selectedLibraryTab.value.name,
    'staticLibraryTab': staticLibraryTab.value.name,
    'autoLibraryTab': autoLibraryTab.value,
    'ytInitialHomePage': ytInitialHomePage.value.name,
    if (tapToScroll != null) 'tapToScroll': tapToScroll,
    if (enhancedDragToScroll != null) 'enhancedDragToScroll': enhancedDragToScroll,
    if (smoothScrolling != null) 'smoothScrolling': smoothScrolling,
    if (floatingArtworkEffect != null) 'floatingArtworkEffect': floatingArtworkEffect,
    if (tiltingCardsEffect != null) 'tiltingCardsEffect': tiltingCardsEffect,
    if (mediaWaveHaptic != null) 'mediaWaveHaptic': mediaWaveHaptic,
    if (artistAlbumsExpanded != null) 'artistAlbumsExpanded': artistAlbumsExpanded,
    if (artistSinglesExpanded != null) 'artistSinglesExpanded': artistSinglesExpanded,
    'lastPlayedIndex': lastPlayedIndex,
    'ytAddToPlaylistsTabIndex': ytAddToPlaylistsTabIndex,
    'ytPlaylistsPageIndex': ytPlaylistsPageIndex,
    'ytChannelsPageIndex': ytChannelsPageIndex,
  };

  Future<void> _writeToStorage() async => await writeToStorage();

  @override
  String get filePath => AppPaths.SETTINGS_EXTRA;
}
