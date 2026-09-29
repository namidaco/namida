part of 'settings_controller.dart';

class _ExtraSettings extends _SettingsKeysWriter {
  _ExtraSettings._internal();

  static const _kDefaultLibraryTab = isKuru ? LibraryTab.playlists : LibraryTab.tracks;

  int getPreferredTabIndexIfLoggedInYT() {
    final activeChannel = YoutubeAccountController.current.activeAccountChannel.value;
    if (activeChannel != null) return 1;
    return 0;
  }

  late final selectedLibraryTab = _keyEnum('selectedLibraryTab', _kDefaultLibraryTab, LibraryTab.values);
  late final staticLibraryTab = _keyEnum('staticLibraryTab', _kDefaultLibraryTab, LibraryTab.values);
  late final autoLibraryTab = _key('autoLibraryTab', true);
  late final libraryTabGroupVariants = _keyMap<LibraryTab, LibraryTab>(
    'libraryTabGroupVariants',
    const {},
    key: LibraryTab.values.asCodec(),
    value: LibraryTab.values.asCodec(),
  );
  late final ytInitialHomePage = _keyEnum('ytInitialHomePage', YTHomePages.playlists, YTHomePages.values);
  late final preferredSearchType = _keyEnum('preferredSearchType', SearchType.auto, SearchType.values);
  late final resumeUIEnabled = _key('resumeUIEnabled', true);

  late final recentSearchesEnabled = _key<bool?>('recentSearchesEnabled', null);
  late final recentSearches = _keyList<String>('recentSearches', const []);

  static const _maxRecentSearches = 20;

  late final scrollbarThumbLabel = _key<bool?>('scrollbarThumbLabel', null);
  late final tapToScroll = _key<bool?>('tapToScroll', null);
  late final enhancedDragToScroll = _key<bool?>('enhancedDragToScroll', null);
  late final smoothScrolling = _key<bool?>('smoothScrolling', null);
  late final floatingArtworkEffect = _key<bool?>('floatingArtworkEffect', null);
  late final tiltingCardsEffect = _key<bool?>('tiltingCardsEffect', null);
  late final jellysInvasion = _key<bool?>('jellysInvasion', null);
  late final jellysPalette = _key<bool?>('jellysPalette', null);
  late final effectsSeasonAnnounced = _key<String?>('effectsSeasonAnnounced', null);
  late final mediaWaveHaptic = _key<bool?>('mediaWaveHaptic', null);
  late final keepVideoFrameOnSwitch = _key<bool?>('keepVideoFrameOnSwitch', null);
  late final artistAlbumsExpanded = _key<bool?>('artistAlbumsExpanded', null);
  late final artistSinglesExpanded = _key<bool?>('artistSinglesExpanded', null);
  late final artistsMapGraphLayout = _key<bool?>('artistsMapGraphLayout', null);
  late final ytStyleButtonSwitcher = _key<bool?>('ytStyleButtonSwitcher', null);

  late final lastPlayedIndex = _key('lastPlayedIndex', 0);

  late final ytAddToPlaylistsTabIndex = _key<int?>('ytAddToPlaylistsTabIndex', null);
  late final ytPlaylistsPageIndex = _key<int?>('ytPlaylistsPageIndex', null);
  late final ytChannelsPageIndex = _key<int?>('ytChannelsPageIndex', null);
  late final ytHomePageIndex = _key<int?>('ytHomePageIndex', null);
  late final audioConfigPageIndex = _key<int?>('audioConfigPageIndex', null);
  late final widePlayerPageIndex = _key<int?>('widePlayerPageIndex', null);

  late final windowMaximized = _key('windowMaximized', false);
  late final windowBounds = _key<Rect?>('windowBounds', null, codec: const _RectCodec());
  late final miniLyricsWindowBounds = _key<Rect?>('miniLyricsWindowBounds', null, codec: const _RectCodec());

  void setSelectedLibraryTab(LibraryTab tab) {
    transaction(() {
      selectedLibraryTab.save(tab);
      if (tab.groupVariants.isNotEmpty) libraryTabGroupVariants.update((variants) => variants[tab.group] = tab);
    });
  }

  void setRecentSearchesEnabled(bool enabled) {
    transaction(() {
      recentSearchesEnabled.save(enabled);
      if (!enabled) recentSearches.reset();
    });
  }

  void addRecentSearch(String text) {
    if (recentSearchesEnabled.value != true) return;
    if (recentSearches.value.firstOrNull == text) return;
    recentSearches.update(
      (list) {
        list.remove(text);
        list.insert(0, text);
        if (list.length > _maxRecentSearches) list.length = _maxRecentSearches;
      },
    );
  }

  void removeRecentSearch(String text) {
    recentSearches.update((list) => list.remove(text));
  }

  void clearRecentSearches() {
    recentSearches.reset();
  }

  @override
  void _onLoaded() {
    if (!autoLibraryTab.value) selectedLibraryTab._setValue(staticLibraryTab.value);
  }

  @override
  String get filePath => AppPaths.SETTINGS_EXTRA;
}

class _RectCodec extends _SettingsCodec<Rect?> {
  const _RectCodec();

  @override
  Rect? decode(dynamic json) {
    if (json is! Map) return null;
    final l = json['l'];
    final t = json['t'];
    final r = json['r'];
    final b = json['b'];
    if (l is! num || t is! num || r is! num || b is! num) return null;
    return Rect.fromLTRB(
      l.toDouble(),
      t.toDouble(),
      r.toDouble(),
      b.toDouble(),
    );
  }

  @override
  Object? encode(Rect? value) {
    if (value == null) return null;
    return {
      'l': value.left,
      't': value.top,
      'r': value.right,
      'b': value.bottom,
    };
  }
}
