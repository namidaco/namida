import 'dart:async';
import 'dart:collection';
import 'dart:math' show Random;

import 'package:flutter/material.dart';

import 'package:basic_audio_handler/basic_audio_handler.dart';
import 'package:history_manager/history_manager.dart';
import 'package:youtipie/core/http.dart';

import 'package:namida/base/settings_file_writer.dart';
import 'package:namida/class/count_per_row.dart';
import 'package:namida/class/eggs_data.dart';
import 'package:namida/class/lang.dart';
import 'package:namida/class/queue_insertion.dart';
import 'package:namida/class/shortcut_data.dart';
import 'package:namida/controller/directory_index.dart';
import 'package:namida/controller/file_browser.dart';
import 'package:namida/controller/platform/shortcuts_manager/shortcuts_manager.dart';
import 'package:namida/controller/sync_manager/sync_manager.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/youtube/class/return_youtube_dislike.dart';
import 'package:namida/youtube/class/sponsorblock.dart';
import 'package:namida/youtube/controller/youtube_account_controller.dart';

part 'settings.debug_keys.dart';
part 'settings.equalizer.dart';
part 'settings.extra.dart';
part 'settings.keys.dart';
part 'settings.player.dart';
part 'settings.shortcuts.dart';
part 'settings.party.dart';
part 'settings.sync.dart';
part 'settings.tutorial.dart';
part 'settings.youtube.dart';

final settings = _SettingsController._internal();

class _SettingsController extends _SettingsKeysWriter {
  _SettingsController._internal();

  Future<void> prepareAllSettings() async {
    await Future.wait([
      this.prepareSettingsFile(),
      this.equalizer.prepareSettingsFile(),
      this.player.prepareSettingsFile(),
      this.youtube.prepareSettingsFile(),
      this.extra.prepareSettingsFile(),
      this.sync.prepareSettingsFile(),
      this.party.prepareSettingsFile(),
      this.tutorial.prepareSettingsFile(),
      if (isDesktop) this.shortcuts.prepareSettingsFile(),
    ]);
    final legacyWindowBounds = _legacyWindowBounds;
    if (legacyWindowBounds != null) {
      _legacyWindowBounds = null;
      if (extra.windowBounds.userValue == null) extra.windowBounds.save(legacyWindowBounds);
    }
  }

  /// the main file stored the window bounds before `extra` existed, applied once both files loaded.
  Rect? _legacyWindowBounds;

  SettingsFileWriter syncWriterOf(SyncDataItem item) => switch (item) {
    SyncDataItem.settingsGeneral => this,
    SyncDataItem.settingsPlayer => player,
    SyncDataItem.settingsYoutube => youtube,
    _ => throw ArgumentError.value(item, 'item', 'not a settings item'),
  };

  @override
  bool get syncable => true;

  final equalizer = _EqualizerSettings._internal();
  final player = _PlayerSettings._internal();
  final youtube = _YoutubeSettings._internal();
  final extra = _ExtraSettings._internal();
  final tutorial = _TutorialSettings._internal();
  final sync = _SyncSettings._internal();
  final party = _PartySettings._internal();
  final shortcuts = _ShortcutsSettings._internal();

  late final language = _keyObject<NamidaLanguage?>('language', null, NamidaLanguage.fromJson, (v) => v?.toJson(), sync: false);
  late final themeMode = _keyEnum('themeMode', ThemeMode.system, ThemeMode.values);
  late final pitchBlack = _key('pitchBlack', false);
  late final autoColor = _key('autoColor', true, sync: false);
  late final animatedTheme = _key('animatedTheme', true, sync: false);
  late final staticColor = _key<int?>('staticColor_v2', null);
  late final staticColorDark = _key<int?>('staticColorDark_v2', null);
  late final libraryTabs = _keyEnumList(
    'libraryTabs',
    const [LibraryTab.home, LibraryTab.tracks, LibraryTab.artists, LibraryTab.playlists, LibraryTab.folders, LibraryTab.youtube],
    LibraryTab.values,
    item: const _LibraryTabGroupCodec(),
  );

  late final borderRadiusMultiplier = _key('borderRadiusMultiplier', isKuru ? 0.9 : 1.0);
  late final fontScaleFactor = _key('fontScaleFactor', 0.85);
  late final artworkCacheHeightMultiplier = _key('artworkCacheHeightMultiplier', isDesktop || isKuru ? 1.0 : 0.9, sync: false);
  late final trackThumbnailSizeinList = _key('trackThumbnailSizeinList', isKuru ? 90.0 : 70.0);
  late final trackListTileHeight = _key('trackListTileHeight', isKuru ? 60.0 : 70.0);
  late final albumThumbnailSizeinList = _key('albumThumbnailSizeinList', 90.0);
  late final albumListTileHeight = _key('albumListTileHeight', 90.0);

  late final useMediaStore = _key('useMediaStore_v2', false, sync: false);
  late final includeVideos = _key('includeVideos', true, sync: false);
  late final cacheArtworks = _key('cacheArtworks', true, sync: false);
  late final displayTrackNumberinAlbumPage = _key('displayTrackNumberinAlbumPage', true);
  late final albumCardTopRightDate = _key('albumCardTopRightDate', true);
  late final forceSquaredTrackThumbnail = _key('forceSquaredTrackThumbnail', false);
  late final forceSquaredAlbumThumbnail = _key('forceSquaredAlbumThumbnail', false);
  late final useAlbumStaggeredGridView = _key('useAlbumStaggeredGridView', false);
  late final useSettingCollapsedTiles = _key('useSettingCollapsedTiles', true);
  late final mediaGridCounts = _keyMap<LibraryTab, CountPerRow?>(
    'mediaGridCounts',
    const {LibraryTab.albums: null, LibraryTab.artists: null, LibraryTab.genres: null, LibraryTab.playlists: CountPerRow(1)},
    key: LibraryTab.values.asCodec(),
    value: const _CountPerRowCodec(),
  );
  late final subpageInfoStyles = _keyMap<MediaType, SubpageInfoStyle>(
    'subpageInfoStyles',
    const {
      MediaType.album: SubpageInfoStyle.heroBanner,
      MediaType.genre: SubpageInfoStyle.blurBackdrop,
      MediaType.playlist: SubpageInfoStyle.banner,
    },
    key: MediaType.values.asCodec(),
    value: SubpageInfoStyle.values.asCodec(),
  );
  late final artworkCollageStyle = _keyEnum('artworkCollageStyle', ArtworkCollageStyle.grid, ArtworkCollageStyle.values);
  late final activeAlbumTypes = _keyMap<AlbumType, bool>(
    'activeAlbumTypes',
    const {AlbumType.single: true, AlbumType.normal: true},
    key: AlbumType.values.asCodec(),
  );
  late final activeTrSearch = _keyMap<TrackTypeSearch, bool>(
    'activeTrSearch',
    const {TrackTypeSearch.tr: true, TrackTypeSearch.v: true},
    key: TrackTypeSearch.values.asCodec(),
  );
  late final enableBlurEffect = _key('enableBlurEffect', isDesktop, sync: false);
  late final enableGlowEffect = _key('enableGlowEffect', isDesktop, sync: false);
  late final enableGlowBehindVideo = _key('enableGlowBehindVideo', false, sync: false);
  late final hourFormat12 = _key('hourFormat12', true);
  late final dateTimeFormat = _key('dateTimeFormat', isKuru ? '[dd.MM.yyyy] EEE' : 'MMM yyyy');
  late final trackArtistsSeparators = _keyList<String>('trackArtistsSeparators', const ['&', ',', ';', '//', ' ft. ', ' x ']);
  late final trackGenresSeparators = _keyList<String>('trackGenresSeparators', const ['&', ',', ';', '//', ' x ']);
  late final trackArtistsSeparatorsBlacklist = _keyList<String>('trackArtistsSeparatorsBlacklist', isKuru ? const ['T & Sugah', 'Miles & Miles'] : const []);
  late final trackGenresSeparatorsBlacklist = _keyList<String>('trackGenresSeparatorsBlacklist', const []);
  late final extensionsBlacklist = _keyList<String>('extensionsBlacklist', const [], sync: false);
  late final fileBrowserSort = _keyEnum('fileBrowserSort', FileBrowserSortType.name, FileBrowserSortType.values);
  late final fileBrowserSortReversed = _key('fileBrowserSortReversed', false);
  late final tracksSortSearch = _keyEnum('tracksSortSearch', isKuru ? SortType.mostPlayed : SortType.title, SortType.values);
  late final tracksSortSearchReversed = _key('tracksSortSearchReversed', false);
  late final tracksSortSearchIsAuto = _key('tracksSortSearchIsAuto_v2', true);
  late final tracksSearchShowLessRelevant = _key('tracksSearchShowLessRelevant', false);
  late final albumSorts = _keyList(
    'albumSorts',
    isKuru ? const [GroupSortType.numberOfTracks] : const [GroupSortType.album],
    item: GroupSortType.values.asCodec(),
    isUnique: true,
    isNonEmpty: true,
  );
  late final albumSortReversed = _key('albumSortReversed', isKuru ? true : false);
  late final artistSorts = _keyList(
    'artistSorts',
    isKuru ? const [GroupSortType.numberOfTracks] : const [GroupSortType.artistsList],
    item: GroupSortType.values.asCodec(),
    isUnique: true,
    isNonEmpty: true,
  );
  late final artistSortReversed = _key('artistSortReversed', isKuru ? true : false);
  late final genreSorts = _keyList('genreSorts', const [GroupSortType.genresList], item: GroupSortType.values.asCodec(), isUnique: true, isNonEmpty: true);
  late final genreSortReversed = _key('genreSortReversed', false);
  late final languageSorts = _keyList('languageSorts', const [GroupSortType.title], item: GroupSortType.values.asCodec(), isUnique: true, isNonEmpty: true);
  late final languageSortReversed = _key('languageSortReversed', false);
  late final moodSorts = _keyList('moodSorts', const [GroupSortType.title], item: GroupSortType.values.asCodec(), isUnique: true, isNonEmpty: true);
  late final moodSortReversed = _key('moodSortReversed', false);
  late final tagSorts = _keyList('tagSorts', const [GroupSortType.title], item: GroupSortType.values.asCodec(), isUnique: true, isNonEmpty: true);
  late final tagSortReversed = _key('tagSortReversed', false);
  late final playlistSorts = _keyList('playlistSorts', const [GroupSortType.dateModified], item: GroupSortType.values.asCodec(), isUnique: true, isNonEmpty: true);
  late final playlistSortReversed = _key('playlistSortReversed', false);
  late final playlistsGroupByTags = _key('playlistsGroupByTags', false);
  late final ytPlaylistSort = _keyEnum('ytPlaylistSort', GroupSortType.dateModified, GroupSortType.values);
  late final ytPlaylistSortReversed = _key('ytPlaylistSortReversed', true);
  late final indexMinDurationInSec = _key('indexMinDurationInSec', 5, sync: false);
  late final indexMinFileSizeInB = _key('indexMinFileSizeInB', 100 * 1024, sync: false);
  late final trackSearchFilter = _keyList(
    'trackSearchFilter',
    isKuru
        ? const [TrackSearchFilter.filename, TrackSearchFilter.title, TrackSearchFilter.artist, TrackSearchFilter.album, TrackSearchFilter.comment, TrackSearchFilter.year]
        : const [TrackSearchFilter.filename, TrackSearchFilter.title, TrackSearchFilter.artist, TrackSearchFilter.album],
    item: TrackSearchFilter.values.asCodec(),
  );
  late final playlistSearchFilter = _keyEnumList('playlistSearchFilter_v2', PlaylistSearchFilter.values, PlaylistSearchFilter.values);
  late final directoriesToScan = _keyList<DirectoryIndex>('directoriesToScan', const [], item: const _DirectoryIndexCodec(), sync: false);
  late final directoriesToExclude = _keyList<DirectoryIndex>('directoriesToExclude', const [], item: const _DirectoryIndexCodec(), sync: false);
  late final preventDuplicatedTracks = _key('preventDuplicatedTracks', false, sync: false);
  late final respectNoMedia = _key('respectNoMedia', false, sync: false);
  late final defaultBackupLocation = _key<String?>('defaultBackupLocation_v2', null, sync: false);
  late final autoBackupIntervalDays = _key('autoBackupIntervalDays', isKuru ? 1 : 2);
  late final defaultFolderStartupLocation = _key<String?>('defaultFolderStartupLocation', kStoragePaths.firstOrNull, sync: false);
  late final defaultFolderStartupLocationVideos = _key<String?>('defaultFolderStartupLocationVideos', kStoragePaths.firstOrNull, sync: false);
  late final enableFoldersHierarchy = _key('enableFoldersHierarchy', true);
  late final enableFoldersHierarchyTracks = _key('enableFoldersHierarchyTracks', true);
  late final enableFoldersHierarchyVideos = _key('enableFoldersHierarchyVideos', true);
  late final foldersSkipSingleSubfolder = _key('foldersSkipSingleSubfolder', true);
  late final displayArtistBeforeTitle = _key('displayArtistBeforeTitle', true);
  late final heatmapListensView = _key('heatmapListensView', false);
  late final reverseListensView = _key('reverseListensView', true);
  late final backupItemslist = _keyEnumList('backupItemslist_v2', AppPathsBackupEnumCategories.everything, AppPathsBackupEnum.values);
  late final enableVideoPlayback = _key('enableVideoPlayback', true);
  late final enableLyrics = _key('enableLyrics', false);
  late final enableSimpleLyricsLine = _key('enableSimpleLyricsLine', false);
  late final enableSubtitles = _key('enableSubtitles', false);
  late final subtitlesLanguages = _keyList<String>('subtitlesLanguages', const []);
  late final lyricsSource = _keyEnum('lyricsSource', LyricsSource.auto, LyricsSource.values);
  late final lyricsSaveLocation = _keyEnum('lyricsSaveLocation', LyricsSaveLocation.cache, LyricsSaveLocation.values, sync: false);
  late final lyricsFolders = _keyList<String>('lyricsFolders', const [], sync: false);
  late final lyricsDeleteWithTrackIn = _keySet<LyricsSaveLocation>('lyricsDeleteWithTrackIn', const {}, item: LyricsSaveLocation.values.asCodec(), sync: false);
  late final videoPlaybackSource = _keyEnum('videoPlaybackSource', VideoPlaybackSource.auto, VideoPlaybackSource.values);
  late final youtubeVideoQualities = _keyList<String>('youtubeVideoQualities', const ['480p', '360p', '240p', '144p']);
  late final animatingThumbnailScaleMultiplier = _key('animatingThumbnailScaleMultiplier', 1.0);
  late final animatingThumbnailIntensity = _key('animatingThumbnailIntensity', 25);
  late final animatingThumbnailIntensityLyrics = _key('animatingThumbnailIntensityLyrics', 10);
  late final animatingThumbnailIntensityMinimized = _key('animatingThumbnailIntensityMinimized', 10);
  late final animatingThumbnailInversed = _key('animatingThumbnailInversed', false);
  late final enablePartyModeInMiniplayer = _key('enablePartyModeInMiniplayer', false);
  late final enablePartyModeColorSwap = _key('enablePartyModeColorSwap', true);
  late final enableMiniplayerParticles = _key('enableMiniplayerParticles', true);
  late final miniplayerVisualizers = _keySet<MiniplayerVisualizer>(
    'miniplayerVisualizers',
    const {
      MiniplayerVisualizer.beatRings,
      MiniplayerVisualizer.reactiveParticles,
    },
    item: MiniplayerVisualizer.values.asCodec(),
  );
  late final visualizerArtworkColors = _key('visualizerArtworkColors', false);
  late final effectsBackground = _keyEnum('effectsBackground', EffectTheme.auto, EffectTheme.values, sync: false);
  late final effectsOverlay = _keyEnum('effectsOverlay', EffectTheme.none, EffectTheme.values, sync: false);
  late final playerBackground = _keyEnum('playerBackground', PlayerBackground.none, PlayerBackground.values, sync: false);
  late final playerBackgroundImage = _key<String?>('playerBackgroundImage', null, sync: false);
  late final playerBackgroundBlur = _key('playerBackgroundBlur_v2', 4, sync: false);
  late final playerBackgroundDim = _key('playerBackgroundDim_v2', 5, sync: false);
  late final playerBackgroundVignette = _key('playerBackgroundVignette', true, sync: false);
  late final playerBackgroundAnimated = _key('playerBackgroundAnimated', true, sync: false);
  late final playerColorWhenExpanded = _key('playerColorWhenExpanded', true, sync: false);
  late final appWallpaper = _key<String?>('appWallpaper', null, sync: false);
  late final appWallpaperBlur = _key('appWallpaperBlur_v2', 4, sync: false);
  late final appWallpaperDim = _key('appWallpaperDim_v2', 5, sync: false);
  late final enableMiniplayerParallaxEffect = _key('enableMiniplayerParallaxEffect', true, sync: false);
  late final forceMiniplayerTrackColor = _key('forceMiniplayerTrackColor', false);
  late final isTrackPlayedSecondsCount = _key('isTrackPlayedSecondsCount', isKuru ? 25 : 40);
  late final isTrackPlayedPercentageCount = _key('isTrackPlayedPercentageCount', isKuru ? 25 : 40);
  late final waveformTotalBars = _key('waveformTotalBars', isDesktop ? 100 : (isKuru ? 111 : 80), sync: false);
  late final videosMaxCacheInMB = _key('videosMaxCacheInMB', isDesktop ? 24 * 1024 : (isKuru ? -1 : 8 * 1024), sync: false);
  late final audiosMaxCacheInMB = _key('audiosMaxCacheInMB', isDesktop ? 12 * 1024 : (isKuru ? -1 : 4 * 1024), sync: false);
  late final serversMaxCacheInMB = _key('serversMaxCacheInMB', isDesktop ? 12 * 1024 : (isKuru ? -1 : 4 * 1024), sync: false);
  late final imagesMaxCacheInMB = _key('imagesMaxCacheInMB', isDesktop || isKuru ? 2 * 1024 : 8 * 32, sync: false);
  late final hideStatusBarInExpandedMiniplayer = _key('hideStatusBarInExpandedMiniplayer', false);
  static const _kDefaultNotificationButtons = [NotificationButton.previous, NotificationButton.playPause, NotificationButton.next, NotificationButton.stop];
  late final notificationButtons = _keyList('notificationButtons', _kDefaultNotificationButtons, item: NotificationButton.values.asCodec(), isUnique: true, isNonEmpty: true);
  late final notificationButtonsPlaylist = _key<String?>('notificationButtonsPlaylist', null);
  late final notificationButtonsYTPlaylist = _key<String?>('notificationButtonsYTPlaylist', null);
  late final enableSearchCleanup = _key('enableSearchCleanup', true);
  late final enableBottomNavBar = _key('enableBottomNavBar', true);
  late final displayAudioInfoMiniplayer = _key('displayAudioInfoMiniplayer', false);
  late final showUnknownFieldsInTrackInfoDialog = _key('showUnknownFieldsInTrackInfoDialog_v2', false);
  late final extractFeatArtistFromTitle = _key('extractFeatArtistFromTitle', true);
  late final groupArtworksByAlbum = _key('groupArtworksByAlbum', false, sync: false);
  late final uniqueArtworkHash = _key('uniqueArtworkHash', false, sync: false);
  late final enableM3USync = _key('enableM3USync', false, sync: false);
  late final enableM3USyncStartup = _key('enableM3USyncStartup', true, sync: false);
  late final importServerPlaylists = _key('importServerPlaylists', true, sync: false);
  late final prioritizeEmbeddedLyrics = _key('prioritizeEmbeddedLyrics', true);
  late final romanizeLyrics = _key('romanizeLyrics', false);
  late final romanizeSorting = _key('romanizeSorting', false);
  late final swipeableDrawer = _key('swipeableDrawer', true);
  late final dismissibleMiniplayer = _key('dismissibleMiniplayer', true);
  late final enableClipboardMonitoring = _key('enableClipboardMonitoring', false, sync: false);
  late final artworkGestureDoubleTapLRC = _key('artworkGestureDoubleTapLRC', true);
  late final previousButtonReplays = _key('previousButtonReplays', false);
  late final refreshOnStartup = _key('refreshOnStartup', false, sync: false);
  late final alwaysExpandedSearchbar = _key('alwaysExpandedSearchbar', isKuru ? true : false);
  late final mixedQueue = _key('mixedQueue', false);
  late final bypassRefreshPrompt = _key('bypassRefreshPrompt_v2', false);
  late final desktopTitlebar = _key('desktopTitlebar', true, sync: false);
  late final desktopTitlebarType = _keyEnum('desktopTitlebarType', DesktopTitlebarIconsType.auto, DesktopTitlebarIconsType.values, sync: false);
  late final tagFieldsToEdit = _keyEnumList(
    'tagFieldsToEdit',
    isKuru
        ? const [TagField.trackNumber, TagField.year, TagField.title, TagField.artist, TagField.album, TagField.genre, TagField.comment, TagField.description, TagField.lyrics]
        : const [
            TagField.trackNumber, TagField.year, TagField.title, TagField.artist, TagField.album, TagField.genre, //
            TagField.albumArtist, TagField.composer, TagField.comment, TagField.description, TagField.lyrics, //
          ],
    TagField.values,
  );

  late final customEQPackage = _key<String?>('customEQPackage', null, sync: false);
  late final stretchLyricsDuration = _key('stretchLyricsDuration', true);
  late final visualDelayMS = _key('visualDelayMS', 0);
  late final lyricsEditorLatencyMS = _key('lyricsEditorLatencyMS', 0, sync: false);
  late final timeCapsuleYears = _key<int?>('timeCapsuleYears', null);

  late final playlistAddTracksAtBeginning = _key('playlistAddTracksAtBeginning', false);
  late final playlistAddTracksAtBeginningYT = _key('playlistAddTracksAtBeginningYT', false);

  late final wakelockMode = _keyEnum('wakelockMode', WakelockMode.expandedAndVideo, WakelockMode.values);

  late final localVideoMatchingType = _keyEnum('localVideoMatchingType', LocalVideoMatchingType.auto, LocalVideoMatchingType.values);
  late final localVideoMatchingCheckSameDir = _key('localVideoMatchingCheckSameDir', false);

  late final trackPlayMode = _keyEnum('trackPlayMode', isKuru ? TrackPlayMode.selectedTrack : TrackPlayMode.searchResults, TrackPlayMode.values);

  late final shuffleExcludeCount = _key('shuffleExcludeCount', 0);
  late final shuffleExcludeSort = _keyEnum('shuffleExcludeSort', SortType.latestPlayed, SortType.values);
  late final shuffleExcludeSortReverse = _key('shuffleExcludeSortReverse', false);

  late final mostPlayedTimeRange = _keyEnum('mostPlayedTimeRange', MostPlayedTimeRange.allTime, MostPlayedTimeRange.values);
  late final mostPlayedCustomDateRange = _keyObject('mostPlayedCustomDateRange', DateRange.dummy(), DateRange.fromJson, (v) => v.toJson());
  late final mostPlayedCustomisStartOfDay = _key('mostPlayedCustomisStartOfDay', true);

  late final ytMostPlayedTimeRange = _keyEnum('ytMostPlayedTimeRange', MostPlayedTimeRange.allTime, MostPlayedTimeRange.values);
  late final ytMostPlayedCustomDateRange = _keyObject('ytMostPlayedCustomDateRange', DateRange.dummy(), DateRange.fromJson, (v) => v.toJson());
  late final ytMostPlayedCustomisStartOfDay = _key('ytMostPlayedCustomisStartOfDay', true);

  late final onTrackSwipeLeft = _keyEnum('onTrackSwipeLeft', TrackExecuteActions.playafter, TrackExecuteActions.values);
  late final onTrackSwipeRight = _keyEnum('onTrackSwipeRight', TrackExecuteActions.openinfo, TrackExecuteActions.values);
  late final artworkTapAction = _keyEnum('artworkTapAction', TrackExecuteActions.none, TrackExecuteActions.values);
  late final artworkLongPressAction = _keyEnum('artworkLongPressAction', TrackExecuteActions.none, TrackExecuteActions.values);
  late final thumbnailTapAction = _keyEnum('thumbnailTapAction', TrackExecuteActions.none, TrackExecuteActions.values);
  late final thumbnailLongPressAction = _keyEnum('thumbnailLongPressAction', TrackExecuteActions.none, TrackExecuteActions.values);

  /// Track Items
  late final displayThirdRow = _key('displayThirdRow', true);
  late final displayThirdItemInEachRow = _key('displayThirdItemInEachRow', false);
  late final trackTileSeparator = _key('trackTileSeparator', '•');
  late final displayFavouriteIconInListTile = _key('displayFavouriteIconInListTile', true);
  late final gradientTiles = _key('gradientTiles', true);
  late final preferredSearchType = _keyEnum('preferredSearchType', SearchType.auto, SearchType.values);
  late final resumeUIEnabled = _key('resumeUIEnabled', true);
  late final ytStyleButtonSwitcher = _key<bool?>('ytStyleButtonSwitcher', null);
  late final keepVideoFrameOnSwitch = _key<bool?>('keepVideoFrameOnSwitch', null, sync: false);
  late final scrollbarThumbLabel = _key<bool?>('scrollbarThumbLabel', null, sync: false);
  late final tapToScroll = _key<bool?>('tapToScroll', null, sync: false);
  late final enhancedDragToScroll = _key<bool?>('enhancedDragToScroll', null, sync: false);
  late final smoothScrolling = _key<bool?>('smoothScrolling', null, sync: false);
  late final mediaWaveHaptic = _key<bool?>('mediaWaveHaptic', null, sync: false);
  late final backgroundImages = _key<bool?>('backgroundImages', null, sync: false);

  late final editTagsKeepFileDates = _key('editTagsKeepFileDates', true);
  late final downloadFilesWriteUploadDate = _key('downloadFilesWriteUploadDate', false);
  late final downloadFilesKeepCachedVersions = _key('downloadFilesKeepCachedVersions', isKuru ? false : true);
  late final downloadAddAudioToLocalLibrary = _key('downloadAddAudioToLocalLibrary', true);
  late final downloadAddToLocalPlaylist = _key('downloadAddToLocalPlaylist', false);
  late final downloadAudioOnly = _key('downloadAudioOnly', isKuru ? true : false);
  late final downloadOverrideOldFiles = _key('downloadOverrideOldFiles', false);
  late final enablePip = _key('enablePip', true, sync: false);
  late final pickColorsFromDeviceWallpaper = _key('pickColorsFromDeviceWallpaper', false, sync: false);
  late final onNotificationTapAction = _keyEnum('onNotificationTapAction', NotificationTapAction.openApp, NotificationTapAction.values);
  late final performanceMode = _keyEnum('performanceMode', isDesktop ? PerformanceMode.goodLooking : PerformanceMode.balanced, PerformanceMode.values, sync: false);
  late final floatingActionButton = _keyEnum('floatingActionButton', isKuru ? FABType.search : FABType.none, FABType.values);
  late final vibrationType = _keyEnum('vibrationType', VibrationType.vibration, VibrationType.values);

  late final trackItem = _keyMap<TrackTilePosition, TrackTileItem>(
    'trackItem',
    const {
      TrackTilePosition.row1Item1: TrackTileItem.title,
      TrackTilePosition.row1Item2: TrackTileItem.none,
      TrackTilePosition.row1Item3: TrackTileItem.none,
      TrackTilePosition.row2Item1: TrackTileItem.artists,
      TrackTilePosition.row2Item2: TrackTileItem.none,
      TrackTilePosition.row2Item3: TrackTileItem.none,
      TrackTilePosition.row3Item1: TrackTileItem.album,
      TrackTilePosition.row3Item2: isKuru ? TrackTileItem.firstListenDate : TrackTileItem.year,
      TrackTilePosition.row3Item3: TrackTileItem.none,
      TrackTilePosition.rightItem1: TrackTileItem.duration,
      TrackTilePosition.rightItem2: TrackTileItem.none,
    },
    key: TrackTilePosition.values.asCodec(),
    value: TrackTileItem.values.asCodec(),
  );

  late final queueInsertion = _keyMap<QueueInsertionType, QueueInsertion>(
    'queueInsertion',
    const {
      QueueInsertionType.moreAlbum: QueueInsertion(numberOfTracks: 10, insertNext: false, shuffle: true),
      QueueInsertionType.moreArtist: QueueInsertion(numberOfTracks: 10, insertNext: false, shuffle: true),
      QueueInsertionType.moreFolder: QueueInsertion(numberOfTracks: 10, insertNext: false, shuffle: true),
      QueueInsertionType.random: QueueInsertion(numberOfTracks: 10, insertNext: false),
      QueueInsertionType.listenTimeRange: QueueInsertion(numberOfTracks: 0, insertNext: true),
      QueueInsertionType.mood: QueueInsertion(numberOfTracks: 20, insertNext: true, sorts: [SortType.mostPlayed]),
      QueueInsertionType.rating: QueueInsertion(numberOfTracks: 20, insertNext: false, sorts: [SortType.rating], sortReverse: true),
      QueueInsertionType.sameReleaseDate: QueueInsertion(numberOfTracks: 30, insertNext: true, sorts: [SortType.mostPlayed]),
      QueueInsertionType.algorithm: QueueInsertion(numberOfTracks: 20, insertNext: true),
      QueueInsertionType.algorithmDiscoverDate: QueueInsertion(numberOfTracks: 20, insertNext: true),
      QueueInsertionType.algorithmTimeRange: QueueInsertion(numberOfTracks: 20, insertNext: true),
      QueueInsertionType.mix: QueueInsertion(numberOfTracks: 0, insertNext: true),
      QueueInsertionType.advancedPlay: QueueInsertion(numberOfTracks: 0, insertNext: false),
      QueueInsertionType.advancedShuffle: QueueInsertion(numberOfTracks: 0, insertNext: false, shuffle: true),
    },
    key: QueueInsertionType.values.asCodec(),
    value: _ObjectCodec(QueueInsertion.fromJson, (v) => v.toJson()),
  );

  late final homePageItems = _keyEnumList(
    'homePageItems',
    const [
      HomePageItems.mixes, HomePageItems.recentListens, HomePageItems.topRecentListens, HomePageItems.lostMemories, //
      HomePageItems.recentQueues, HomePageItems.recentlyAdded, HomePageItems.recentAlbums, HomePageItems.recentArtists, //
    ],
    HomePageItems.values,
  );

  late final activeArtistType = _keyEnum('activeArtistType', MediaType.artist, MediaType.values);

  late final activeGenreType = _keyEnum('activeGenreType', MediaType.genre, MediaType.values);

  late final activeSearchMediaTypes = _keyList(
    'activeSearchMediaTypes',
    isKuru ? const [MediaType.track, MediaType.album, MediaType.artist, MediaType.folder] : const [MediaType.track, MediaType.album, MediaType.artist],
    item: MediaType.values.asCodec(),
  );

  late final albumIdentifiers = _keyList(
    'albumIdentifiers',
    const [AlbumIdentifier.albumName, AlbumIdentifier.albumArtist],
    item: AlbumIdentifier.values.asCodec(),
  );

  static const _kDefaultTracksSorting = isKuru ? [SortType.firstListen, SortType.title] : [SortType.title, SortType.year, SortType.album];

  late final mediaItemsTrackSorting = _keyMap<MediaType, List<SortType>>(
    'mediaItemsTrackSorting',
    const {
      MediaType.track: _kDefaultTracksSorting,
      MediaType.album: [SortType.discNo, SortType.trackNo, SortType.year, SortType.title],
      MediaType.artist: [SortType.year, SortType.title],
      MediaType.albumArtist: [SortType.year, SortType.title],
      MediaType.composer: [SortType.year, SortType.title],
      MediaType.genre: [SortType.year, SortType.title],
      MediaType.style: [SortType.year, SortType.title],
      MediaType.language: [SortType.year, SortType.title],
      MediaType.mood: [SortType.title],
      MediaType.tag: [SortType.title],
      MediaType.rating: [SortType.title],
      MediaType.folder: [SortType.filename],
      MediaType.folderMusic: [SortType.filename],
      MediaType.folderVideo: [SortType.filename],
    },
    key: MediaType.values.asCodec(),
    value: _PlainListCodec(SortType.values.asCodec()),
  );

  late final mediaItemsTrackSortingReverse = _keyMap<MediaType, bool>(
    'mediaItemsTrackSortingReverse',
    const {
      MediaType.track: false,
      MediaType.album: false,
      MediaType.artist: false,
      MediaType.genre: false,
      MediaType.style: false,
      MediaType.language: false,
      MediaType.mood: false,
      MediaType.tag: false,
      MediaType.rating: false,
      MediaType.folder: false,
      MediaType.folderMusic: false,
      MediaType.folderVideo: false,
    },
    key: MediaType.values.asCodec(),
  );

  late final imageSourceAlbum = _keyList('imageSourceAlbum', const [LibraryImageSource.lastfm, LibraryImageSource.local], item: LibraryImageSource.values.asCodec());
  late final imageSourceArtist = _keyList('imageSourceArtist', const [LibraryImageSource.lastfm, LibraryImageSource.local], item: LibraryImageSource.values.asCodec());

  late final ignoreCommonPrefixForTypes = _keyList('ignoreCommonPrefixForTypes', const <TrackSearchFilter>[], item: TrackSearchFilter.values.asCodec());
  late final commonPrefixes = _keyList<String>('commonPrefixes', const ['the ', 'a ', 'an ']);

  late final fontScaleLRC = _key('fontScaleLRC', 1.0);
  late final fontScaleLRCFull = _key<double?>('fontScaleLRCFull', null);

  late final canAskForBatteryOptimizations = _key('canAskForBatteryOptimizations', true, sync: false);

  /// queue published to media browser clients (android auto, wear).
  late final mediaBrowserQueue = _key('mediaBrowserQueue', true, sync: false);
  late final nowPlayingBroadcast = _key('nowPlayingBroadcast', false, sync: false);
  late final scrobblerBroadcast = _key('scrobblerBroadcast', false, sync: false);
  late final webhookUrl = _key('webhookUrl', '', sync: false);
  late final webhookEvents = _keySet<WebhookEvent>('webhookEvents', _kDefaultWebhookEvents, item: WebhookEvent.values.asCodec(), sync: false);
  late final lyricsIntegrations = _keySet<LyricsIntegration>('lyricsIntegrations', const {}, item: LyricsIntegration.values.asCodec(), sync: false);

  static const _kDefaultWebhookEvents = {WebhookEvent.trackChanged, WebhookEvent.play, WebhookEvent.pause};

  bool didSupportNamida = false;
  late final eggs = _keyObject<EggsData>('eggs', const EggsData(), EggsData.fromJson, (v) => v.toJson());

  @override
  void _migrateLegacy() {
    _migrateKey('selectedLanguage', 'language', (json) {
      if (_raw['language'] != null || json is! Map<String, dynamic>) return null;
      // -- apply previous language only if it wasn't english, since this was the default
      // -- cuz null just falls back to device language or english now
      try {
        return NamidaLanguage.fromJson(json).codeOnly == 'en' ? null : json;
      } catch (_) {
        return null;
      }
    });
    _migrateKey('staticColor', 'staticColor_v2', (json) => _raw['staticColor_v2'] == null && json != kMainColorLightOldValue ? json : null);
    _migrateKey('staticColorDark', 'staticColorDark_v2', (json) => _raw['staticColorDark_v2'] == null && json != kMainColorDarkOldValue ? json : null);
    // -- keys the old loader had already reset by only reading their `_v2` twin
    _dropKey('useMediaStore');
    _dropKey('tracksSortSearchIsAuto');
    _dropKey('showUnknownFieldsInTrackInfoDialog');
    _dropKey('defaultBackupLocation');
    _dropKey('backupItemslist');
    _legacyWindowBounds = const _RectCodec().decode(_dropKey('windowBounds'));
    _dropKey('advancedPlaySorts');
    _dropKey('advancedPlaySortReverse');
    _dropKey('advancedPlayMinimums');

    final tracksSort = _dropKey('tracksSort');
    if (tracksSort is String) {
      final Map sorting = _raw['mediaItemsTrackSorting'] ??= <String, dynamic>{
        MediaType.track.name: <dynamic>[for (final sort in _kDefaultTracksSorting) sort.name],
      };
      final List trackSorts = sorting[MediaType.track.name] ??= <dynamic>[];
      trackSorts.remove(tracksSort);
      trackSorts.insert(0, tracksSort);
    }
    final tracksSortReversed = _dropKey('tracksSortReversed');
    if (tracksSortReversed is bool) {
      final Map reverse = _raw['mediaItemsTrackSortingReverse'] ??= <String, dynamic>{};
      reverse[MediaType.track.name] = tracksSortReversed;
    }
  }

  @override
  void _migrateKeys() {
    for (final name in const ['albumSort', 'artistSort', 'genreSort', 'playlistSort']) {
      final listName = '${name}s';
      _migrateKey(name, listName, (json) => json is String && _raw[listName] == null ? [json] : null);
    }

    final isFavouriteInNotification = _dropKey('displayFavouriteButtonInNotification') == true;
    final isStopInNotification = _dropKey('displayStopButtonInNotification') != false;
    final didCustomizeNotification = isFavouriteInNotification || !isStopInNotification;
    if (didCustomizeNotification && _raw['notificationButtons'] == null) {
      _raw['notificationButtons'] = <String>[
        if (isFavouriteInNotification) NotificationButton.favourite.name,
        ..._kDefaultNotificationButtons.where((button) => button != NotificationButton.stop || isStopInNotification).map((button) => button.name),
      ];
    }
  }

  void updateMediaItemsTrackSortingAll(MediaType media, List<SortType>? allsorts, bool? isReverse) {
    if (allsorts == null && isReverse == null) return;
    final didChangeSorts = allsorts.didChangeFrom(mediaItemsTrackSorting.value[media], ordered: true);
    final didChangeReverse = isReverse != mediaItemsTrackSortingReverse.value[media];
    if (!didChangeSorts && !didChangeReverse) return;

    transaction(() {
      if (allsorts != null) mediaItemsTrackSorting.update((sorting) => sorting[media] = allsorts);
      if (isReverse != null) mediaItemsTrackSortingReverse.update((reverse) => reverse[media] = isReverse);
    });
  }

  void updateGroupSortingAll(MediaType media, List<GroupSortType> allSorts, bool isReverse) {
    final keys = _groupSortingKeysOf(media);
    if (keys == null) return;
    final (sortsKey, reverseKey) = keys;
    final didChangeSorts = allSorts.didChangeFrom(sortsKey.value, ordered: true);
    final didChangeReverse = isReverse != reverseKey.value;
    if (!didChangeSorts && !didChangeReverse) return;

    transaction(() {
      if (didChangeSorts) sortsKey.replace(allSorts);
      if (didChangeReverse) reverseKey.save(isReverse);
    });
  }

  ({List<GroupSortType> sorts, bool isReverse})? groupSortingOf(MediaType media) {
    final keys = _groupSortingKeysOf(media);
    if (keys == null) return null;
    final (sortsKey, reverseKey) = keys;
    return (sorts: sortsKey.value, isReverse: reverseKey.value);
  }

  (Rx<List<GroupSortType>>, Rx<bool>)? groupSortingRxOf(MediaType media) => _groupSortingKeysOf(media);

  (_SettingsListKey<GroupSortType>, _SettingsKey<bool>)? _groupSortingKeysOf(MediaType media) => switch (media) {
    MediaType.album => (albumSorts, albumSortReversed),
    MediaType.artist || MediaType.albumArtist || MediaType.composer => (artistSorts, artistSortReversed),
    MediaType.genre || MediaType.style => (genreSorts, genreSortReversed),
    MediaType.language => (languageSorts, languageSortReversed),
    MediaType.playlist => (playlistSorts, playlistSortReversed),
    MediaType.mood => (moodSorts, moodSortReversed),
    MediaType.tag => (tagSorts, tagSortReversed),
    MediaType.track || MediaType.folder || MediaType.folderMusic || MediaType.folderVideo || MediaType.rating => null,
  };

  void updateActiveTrSearch({required bool tracks, required bool videos}) {
    activeTrSearch.update(
      (map) {
        map[TrackTypeSearch.tr] = tracks;
        map[TrackTypeSearch.v] = videos;
      },
    );
  }

  @override
  Set<String> get sensitiveKeys => const {'webhookUrl'};

  @override
  String get filePath => AppPaths.SETTINGS;
}

/// stored tabs are collapsed to their group, so variants never produce duplicate tabs.
class _LibraryTabGroupCodec extends _SettingsCodec<LibraryTab> {
  const _LibraryTabGroupCodec();

  @override
  LibraryTab? decode(dynamic json) {
    final tab = json is String ? LibraryTab.values.getEnum(json) : null;
    return tab?.group;
  }

  @override
  Object? encode(LibraryTab value) => value.name;
}

class _CountPerRowCodec extends _SettingsCodec<CountPerRow?> {
  const _CountPerRowCodec();

  @override
  CountPerRow? decode(dynamic json) => CountPerRow.fromJsonValue(json);

  @override
  Object? encode(CountPerRow? value) => value?.rawValue;
}

class _DirectoryIndexCodec extends _SettingsCodec<DirectoryIndex> {
  const _DirectoryIndexCodec();

  @override
  DirectoryIndex? decode(dynamic json) {
    try {
      return DirectoryIndex.fromMap(json);
    } catch (_) {
      return null;
    }
  }

  @override
  Object? encode(DirectoryIndex value) => value.toMap();
}

extension CountPerRowMapUtils on Map<LibraryTab, CountPerRow?> {
  CountPerRow get(LibraryTab tab) {
    final val = this[tab];
    if (val == null || val.rawValue < 1) return CountPerRow.autoForTab(tab);
    return val;
  }
}
