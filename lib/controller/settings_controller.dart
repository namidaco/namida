import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:history_manager/history_manager.dart';
import 'package:youtipie/core/http.dart';

import 'package:namida/base/settings_file_writer.dart';
import 'package:namida/class/count_per_row.dart';
import 'package:namida/class/lang.dart';
import 'package:namida/class/queue_insertion.dart';
import 'package:namida/class/shortcut_data.dart';
import 'package:namida/controller/file_browser.dart';
import 'package:namida/controller/logs_controller.dart';
import 'package:namida/controller/platform/shortcuts_manager/shortcuts_manager.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/youtube/class/return_youtube_dislike.dart';
import 'package:namida/youtube/class/sponsorblock.dart';
import 'package:namida/youtube/controller/youtube_account_controller.dart';

part 'settings.equalizer.dart';
part 'settings.extra.dart';
part 'settings.player.dart';
part 'settings.tutorial.dart';
part 'settings.youtube.dart';
part 'settings.shortcuts.dart';

final settings = _SettingsController._internal();

class _SettingsController with SettingsFileWriter {
  _SettingsController._internal();

  Future<void> prepareAllSettings() async {
    await Future.wait([
      this.prepareSettingsFile(),
      this.equalizer.prepareSettingsFile(),
      this.player.prepareSettingsFile(),
      this.youtube.prepareSettingsFile(),
      this.extra.prepareSettingsFile(),
      this.tutorial.prepareSettingsFile(),
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) this.shortcuts.prepareSettingsFile(),
    ]);
  }

  final equalizer = EqualizerSettings._internal();
  final player = _PlayerSettings._internal();
  final youtube = _YoutubeSettings._internal();
  final extra = _ExtraSettings._internal();
  final tutorial = _TutorialSettings._internal();
  final shortcuts = _ShortcutsSettings._internal();

  final selectedLanguage = kDefaultLang.obs;
  final themeMode = ThemeMode.system.obs;
  final pitchBlack = false.obs;
  final autoColor = true.obs;
  final animatedTheme = true.obs;
  final staticColor = kMainColorLight.intValue.obs;
  final staticColorDark = kMainColorDark.intValue.obs;
  final RxList<LibraryTab> libraryTabs = [
    LibraryTab.home,
    LibraryTab.tracks,
    LibraryTab.artists,
    LibraryTab.playlists,
    LibraryTab.folders,
    LibraryTab.youtube,
  ].obs;

  final borderRadiusMultiplier = 1.0.obs;
  final fontScaleFactor = 0.9.obs;
  final artworkCacheHeightMultiplier = 0.9.obs;
  final trackThumbnailSizeinList = 70.0.obs;
  final trackListTileHeight = 70.0.obs;
  final albumThumbnailSizeinList = 90.0.obs;
  final albumListTileHeight = 90.0.obs;

  final useMediaStore = false.obs;
  final includeVideos = true.obs;
  final displayTrackNumberinAlbumPage = true.obs;
  final albumCardTopRightDate = true.obs;
  final forceSquaredTrackThumbnail = false.obs;
  final forceSquaredAlbumThumbnail = false.obs;
  final useAlbumStaggeredGridView = false.obs;
  final useSettingCollapsedTiles = true.obs;
  final mediaGridCounts = <LibraryTab, CountPerRow?>{
    LibraryTab.albums: null,
    LibraryTab.artists: null,
    LibraryTab.genres: null,
    LibraryTab.playlists: CountPerRow(1),
  }.obs;
  final activeAlbumTypes = <AlbumType, bool>{
    AlbumType.single: true,
    AlbumType.normal: true,
  }.obs;
  final enableBlurEffect = false.obs;
  final enableGlowEffect = false.obs;
  final enableGlowBehindVideo = false.obs;
  final hourFormat12 = true.obs;
  final dateTimeFormat = 'MMM yyyy'.obs;
  final RxList<String> trackArtistsSeparators = <String>['&', ',', ';', '//', ' ft. ', ' x '].obs;
  final RxList<String> trackGenresSeparators = <String>['&', ',', ';', '//', ' x '].obs;
  final RxList<String> trackArtistsSeparatorsBlacklist = <String>[].obs;
  final RxList<String> trackGenresSeparatorsBlacklist = <String>[].obs;
  final fileBrowserSort = FileBrowserSortType.name.obs;
  final fileBrowserSortReversed = false.obs;
  final tracksSortSearch = SortType.title.obs;
  final tracksSortSearchReversed = false.obs;
  final tracksSortSearchIsAuto = true.obs;
  final albumSort = GroupSortType.album.obs;
  final albumSortReversed = false.obs;
  final artistSort = GroupSortType.artistsList.obs;
  final artistSortReversed = false.obs;
  final genreSort = GroupSortType.genresList.obs;
  final genreSortReversed = false.obs;
  final playlistSort = GroupSortType.dateModified.obs;
  final playlistSortReversed = false.obs;
  final ytPlaylistSort = GroupSortType.dateModified.obs;
  final ytPlaylistSortReversed = true.obs;
  final indexMinDurationInSec = 5.obs;
  final indexMinFileSizeInB = (100 * 1024).obs;
  final RxList<TrackSearchFilter> trackSearchFilter = [
    TrackSearchFilter.filename,
    TrackSearchFilter.title,
    TrackSearchFilter.artist,
    TrackSearchFilter.album,
  ].obs;
  final playlistSearchFilter = ['name', 'creationDate', 'modifiedDate', 'moods', 'comment'].obs;
  final directoriesToScan = <String>[].obs;
  final directoriesToExclude = <String>[].obs;
  final preventDuplicatedTracks = false.obs;
  final respectNoMedia = false.obs;
  final defaultBackupLocation = Rxn<String?>();
  final autoBackupIntervalDays = 2.obs;
  final defaultFolderStartupLocation = kStoragePaths.firstOrNull.obs;
  final defaultFolderStartupLocationVideos = kStoragePaths.firstOrNull.obs;
  final enableFoldersHierarchy = true.obs;
  final enableFoldersHierarchyVideos = true.obs;
  final displayArtistBeforeTitle = true.obs;
  final heatmapListensView = false.obs;
  final reverseListensView = true.obs;
  final backupItemslist = Rxn<List<AppPathsBackupEnum>>();
  final enableVideoPlayback = true.obs;
  final enableLyrics = false.obs;
  final lyricsSource = LyricsSource.auto.obs;
  final videoPlaybackSource = VideoPlaybackSource.auto.obs;
  final RxList<String> youtubeVideoQualities = ['480p', '360p', '240p', '144p'].obs;
  final animatingThumbnailScaleMultiplier = 1.0.obs;
  final animatingThumbnailIntensity = 25.obs;
  final animatingThumbnailIntensityLyrics = 10.obs;
  final animatingThumbnailIntensityMinimized = 10.obs;
  final animatingThumbnailInversed = false.obs;
  final enablePartyModeInMiniplayer = false.obs;
  final enablePartyModeColorSwap = true.obs;
  final enableMiniplayerParticles = true.obs;
  final enableMiniplayerParallaxEffect = true.obs;
  final forceMiniplayerTrackColor = false.obs;
  final isTrackPlayedSecondsCount = 40.obs;
  final isTrackPlayedPercentageCount = 40.obs;
  final waveformTotalBars = 140.obs;
  final videosMaxCacheInMB = (8 * 1024).obs; // 8GB
  final audiosMaxCacheInMB = (4 * 1024).obs; // 4GB
  final imagesMaxCacheInMB = (8 * 32).obs; // 256 MB
  final hideStatusBarInExpandedMiniplayer = false.obs;
  final displayFavouriteButtonInNotification = false.obs;
  final displayStopButtonInNotification = true.obs;
  final enableSearchCleanup = true.obs;
  final enableBottomNavBar = true.obs;
  final displayAudioInfoMiniplayer = false.obs;
  final showUnknownFieldsInTrackInfoDialog = true.obs;
  final extractFeatArtistFromTitle = true.obs;
  final groupArtworksByAlbum = false.obs;
  final uniqueArtworkHash = false.obs;
  final enableM3USync = false.obs;
  final enableM3USyncStartup = true.obs;
  final prioritizeEmbeddedLyrics = true.obs;
  final swipeableDrawer = true.obs;
  final dismissibleMiniplayer = false.obs;
  final enableClipboardMonitoring = false.obs;
  final artworkGestureDoubleTapLRC = true.obs;
  final previousButtonReplays = false.obs;
  final refreshOnStartup = false.obs;
  final alwaysExpandedSearchbar = false.obs;
  final mixedQueue = false.obs;
  final RxList<TagField> tagFieldsToEdit = <TagField>[
    TagField.trackNumber,
    TagField.year,
    TagField.title,
    TagField.artist,
    TagField.album,
    TagField.genre,
    TagField.albumArtist,
    TagField.composer,
    TagField.comment,
    TagField.description,
    TagField.lyrics,
  ].obs;

  final stretchLyricsDuration = true.obs;

  final playlistAddTracksAtBeginning = false.obs;
  final playlistAddTracksAtBeginningYT = false.obs;

  final wakelockMode = WakelockMode.expandedAndVideo.obs;

  final localVideoMatchingType = LocalVideoMatchingType.auto.obs;
  final localVideoMatchingCheckSameDir = false.obs;

  final trackPlayMode = TrackPlayMode.searchResults.obs;

  final mostPlayedTimeRange = MostPlayedTimeRange.allTime.obs;
  final mostPlayedCustomDateRange = DateRange.dummy().obs;
  final mostPlayedCustomisStartOfDay = true.obs;

  final ytMostPlayedTimeRange = MostPlayedTimeRange.allTime.obs;
  final ytMostPlayedCustomDateRange = DateRange.dummy().obs;
  final ytMostPlayedCustomisStartOfDay = true.obs;

  final onTrackSwipeLeft = TrackExecuteActions.playafter.obs;
  final onTrackSwipeRight = TrackExecuteActions.openinfo.obs;
  final artworkTapAction = TrackExecuteActions.none.obs;
  final artworkLongPressAction = TrackExecuteActions.none.obs;

  /// Track Items
  final displayThirdRow = true.obs;
  final displayThirdItemInEachRow = false.obs;
  final trackTileSeparator = '•'.obs;
  final displayFavouriteIconInListTile = true.obs;
  final gradientTiles = true.obs;

  final editTagsKeepFileDates = true.obs;
  final downloadFilesWriteUploadDate = false.obs;
  final downloadFilesKeepCachedVersions = true.obs;
  final downloadAddAudioToLocalLibrary = true.obs;
  final downloadAudioOnly = false.obs;
  final downloadOverrideOldFiles = false.obs;
  final enablePip = true.obs;
  final pickColorsFromDeviceWallpaper = false.obs;
  final onNotificationTapAction = NotificationTapAction.openApp.obs;
  final performanceMode = PerformanceMode.balanced.obs;
  final floatingActionButton = FABType.none.obs;
  final vibrationType = VibrationType.vibration.obs;

  final trackItem = {
    TrackTilePosition.row1Item1: TrackTileItem.title,
    TrackTilePosition.row1Item2: TrackTileItem.none,
    TrackTilePosition.row1Item3: TrackTileItem.none,
    TrackTilePosition.row2Item1: TrackTileItem.artists,
    TrackTilePosition.row2Item2: TrackTileItem.none,
    TrackTilePosition.row2Item3: TrackTileItem.none,
    TrackTilePosition.row3Item1: TrackTileItem.album,
    TrackTilePosition.row3Item2: TrackTileItem.year,
    TrackTilePosition.row3Item3: TrackTileItem.none,
    TrackTilePosition.rightItem1: TrackTileItem.duration,
    TrackTilePosition.rightItem2: TrackTileItem.none,
  }.obs;

  final queueInsertion = <QueueInsertionType, QueueInsertion>{
    QueueInsertionType.moreAlbum: const QueueInsertion(numberOfTracks: 10, insertNext: false, sortBy: InsertionSortingType.random),
    QueueInsertionType.moreArtist: const QueueInsertion(numberOfTracks: 10, insertNext: false, sortBy: InsertionSortingType.random),
    QueueInsertionType.moreFolder: const QueueInsertion(numberOfTracks: 10, insertNext: false, sortBy: InsertionSortingType.random),
    QueueInsertionType.random: const QueueInsertion(numberOfTracks: 10, insertNext: false, sortBy: InsertionSortingType.none),
    QueueInsertionType.listenTimeRange: const QueueInsertion(numberOfTracks: 0, insertNext: true, sortBy: InsertionSortingType.none),
    QueueInsertionType.mood: const QueueInsertion(numberOfTracks: 20, insertNext: true, sortBy: InsertionSortingType.listenCount),
    QueueInsertionType.rating: const QueueInsertion(numberOfTracks: 20, insertNext: false, sortBy: InsertionSortingType.rating),
    QueueInsertionType.sameReleaseDate: const QueueInsertion(numberOfTracks: 30, insertNext: true, sortBy: InsertionSortingType.listenCount),
    QueueInsertionType.algorithm: const QueueInsertion(numberOfTracks: 20, insertNext: true, sortBy: InsertionSortingType.none),
    QueueInsertionType.algorithmDiscoverDate: const QueueInsertion(numberOfTracks: 20, insertNext: true, sortBy: InsertionSortingType.listenCount),
    QueueInsertionType.algorithmTimeRange: const QueueInsertion(numberOfTracks: 20, insertNext: true, sortBy: InsertionSortingType.none),
    QueueInsertionType.mix: const QueueInsertion(numberOfTracks: 0, insertNext: true, sortBy: InsertionSortingType.none),
  }.obs;

  final homePageItems = <HomePageItems>[
    HomePageItems.mixes,
    HomePageItems.recentListens,
    HomePageItems.topRecentListens,
    HomePageItems.lostMemories,
    HomePageItems.recentlyAdded,
    HomePageItems.recentAlbums,
    HomePageItems.recentArtists,
  ].obso;

  final activeArtistType = MediaType.artist.obs;

  final activeSearchMediaTypes = <MediaType>[
    MediaType.track,
    MediaType.album,
    MediaType.artist,
  ].obs;

  final albumIdentifiers = <AlbumIdentifier>[
    AlbumIdentifier.albumName,
  ].obs;

  final mediaItemsTrackSorting = <MediaType, List<SortType>>{
    MediaType.track: [SortType.title, SortType.year, SortType.album],
    MediaType.album: [SortType.discNo, SortType.trackNo, SortType.year, SortType.title],
    MediaType.artist: [SortType.year, SortType.title],
    MediaType.albumArtist: [SortType.year, SortType.title],
    MediaType.composer: [SortType.year, SortType.title],
    MediaType.genre: [SortType.year, SortType.title],
    MediaType.folder: [SortType.filename],
    MediaType.folderMusic: [SortType.filename],
    MediaType.folderVideo: [SortType.filename],
  }.obs;

  final mediaItemsTrackSortingReverse = <MediaType, bool>{
    MediaType.track: false,
    MediaType.album: false,
    MediaType.artist: false,
    MediaType.genre: false,
    MediaType.folder: false,
    MediaType.folderMusic: false,
    MediaType.folderVideo: false,
  }.obs;

  final imageSourceAlbum = <LibraryImageSource>[
    LibraryImageSource.lastfm,
    LibraryImageSource.local,
  ].obs;

  final imageSourceArtist = <LibraryImageSource>[
    LibraryImageSource.lastfm,
    LibraryImageSource.local,
  ].obs;

  final ignoreCommonPrefixForTypes = <TrackSearchFilter>[].obs;
  final commonPrefixes = <String>['the ', 'a ', 'an '].obs;

  double fontScaleLRC = 1.0;
  double fontScaleLRCFull = 1.0;

  Rect? windowBounds;

  bool canAskForBatteryOptimizations = true;
  bool didSupportNamida = false;

  @override
  void applyKuruSettings() {
    floatingActionButton.value = FABType.search;
    borderRadiusMultiplier.value = 0.9;
    fontScaleFactor.value = 0.85;
    artworkCacheHeightMultiplier.value = 1.0;
    trackThumbnailSizeinList.value = 90.0;
    trackListTileHeight.value = 60.0;
    forceSquaredTrackThumbnail.value = false;
    dateTimeFormat.value = '[dd.MM.yyyy] EEE';
    trackArtistsSeparatorsBlacklist.value = <String>['T & Sugah', 'Miles & Miles'];
    tracksSortSearch.value = SortType.mostPlayed;
    tracksSortSearchReversed.value = false;
    tracksSortSearchIsAuto.value = false;
    albumSort.value = GroupSortType.numberOfTracks;
    albumSortReversed.value = true;
    artistSort.value = GroupSortType.numberOfTracks;
    artistSortReversed.value = true;
    trackSearchFilter.value = [
      TrackSearchFilter.filename,
      TrackSearchFilter.title,
      TrackSearchFilter.artist,
      TrackSearchFilter.album,
      TrackSearchFilter.comment,
      TrackSearchFilter.year,
    ];
    autoBackupIntervalDays.value = 1;
    isTrackPlayedSecondsCount.value = 25;
    isTrackPlayedPercentageCount.value = 25;
    waveformTotalBars.value = 111;
    videosMaxCacheInMB.value = -1;
    audiosMaxCacheInMB.value = -1;
    imagesMaxCacheInMB.value = (2 * 1024); // 2GB
    showUnknownFieldsInTrackInfoDialog.value = false;
    dismissibleMiniplayer.value = true;
    alwaysExpandedSearchbar.value = true;
    tagFieldsToEdit.value = <TagField>[
      TagField.trackNumber,
      TagField.year,
      TagField.title,
      TagField.artist,
      TagField.album,
      TagField.genre,
      TagField.comment,
      TagField.description,
      TagField.lyrics,
    ];
    mediaItemsTrackSorting.value[MediaType.track] = [SortType.firstListen, SortType.title];
    trackPlayMode.value = TrackPlayMode.selectedTrack;
    onTrackSwipeLeft.value = TrackExecuteActions.playafter;
    downloadFilesKeepCachedVersions.value = false;
    downloadAudioOnly.value = true;
    trackItem.value = {
      TrackTilePosition.row1Item1: TrackTileItem.title,
      TrackTilePosition.row1Item2: TrackTileItem.none,
      TrackTilePosition.row1Item3: TrackTileItem.none,
      TrackTilePosition.row2Item1: TrackTileItem.artists,
      TrackTilePosition.row2Item2: TrackTileItem.none,
      TrackTilePosition.row2Item3: TrackTileItem.none,
      TrackTilePosition.row3Item1: TrackTileItem.album,
      TrackTilePosition.row3Item2: TrackTileItem.firstListenDate,
      TrackTilePosition.row3Item3: TrackTileItem.none,
      TrackTilePosition.rightItem1: TrackTileItem.duration,
      TrackTilePosition.rightItem2: TrackTileItem.none,
    };
    activeSearchMediaTypes.value = <MediaType>[
      MediaType.track,
      MediaType.album,
      MediaType.artist,
      MediaType.folder,
    ];
  }

  void _applyDefaultDesktopSettings() {
    artworkCacheHeightMultiplier.value = 1.0;
    enableBlurEffect.value = true;
    enableGlowEffect.value = true;
    enableMiniplayerParallaxEffect.value = true;
    animatedTheme.value = true;
    performanceMode.value = PerformanceMode.goodLooking;

    waveformTotalBars.value = 100;
    videosMaxCacheInMB.value = (24 * 1024); // 8GB
    audiosMaxCacheInMB.value = (12 * 1024); // 4GB
    imagesMaxCacheInMB.value = (2 * 1024); // 256 MB
  }

  Future<void> prepareSettingsFile() async {
    final json = await prepareSettingsFile_();
    if (json is! Map) return;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      _applyDefaultDesktopSettings();
    }

    try {
      /// Assigning Values
      selectedLanguage.value = NamidaLanguage.fromJson(json['selectedLanguage']);
      themeMode.value = ThemeMode.values.getEnum(json['themeMode']) ?? themeMode.value;
      pitchBlack.value = json['pitchBlack'] ?? pitchBlack.value;
      autoColor.value = json['autoColor'] ?? autoColor.value;
      animatedTheme.value = json['animatedTheme'] ?? animatedTheme.value;
      staticColor.value = json['staticColor'] ?? staticColor.value;
      staticColorDark.value = json['staticColorDark'] ?? staticColorDark.value;
      final libraryListFromStorage = json['libraryTabs'];
      if (libraryListFromStorage is List) libraryTabs.value = libraryListFromStorage.map((e) => LibraryTab.values.getEnum(e)).toListy();

      final homePageItemsFromStorage = json['homePageItems'];
      if (homePageItemsFromStorage is List) homePageItems.value = homePageItemsFromStorage.map((e) => HomePageItems.values.getEnum(e)).toListy();

      activeArtistType.value = MediaType.values.getEnum(json['activeArtistType']) ?? activeArtistType.value;

      final activeSearchMediaTypesFromStorage = json['activeSearchMediaTypes'];
      if (activeSearchMediaTypesFromStorage is List) activeSearchMediaTypes.value = activeSearchMediaTypesFromStorage.map((e) => MediaType.values.getEnum(e)).toListy();

      final albumIdentifiersFromStorage = json['albumIdentifiers'];
      if (albumIdentifiersFromStorage is List) albumIdentifiers.value = albumIdentifiersFromStorage.map((e) => AlbumIdentifier.values.getEnum(e)).toListy();

      borderRadiusMultiplier.value = json['borderRadiusMultiplier'] ?? borderRadiusMultiplier.value;
      fontScaleFactor.value = json['fontScaleFactor'] ?? fontScaleFactor.value;
      artworkCacheHeightMultiplier.value = json['artworkCacheHeightMultiplier'] ?? artworkCacheHeightMultiplier.value;
      trackThumbnailSizeinList.value = json['trackThumbnailSizeinList'] ?? trackThumbnailSizeinList.value;
      trackListTileHeight.value = json['trackListTileHeight'] ?? trackListTileHeight.value;
      albumThumbnailSizeinList.value = json['albumThumbnailSizeinList'] ?? albumThumbnailSizeinList.value;
      albumListTileHeight.value = json['albumListTileHeight'] ?? albumListTileHeight.value;

      useMediaStore.value = json['useMediaStore'] ?? useMediaStore.value;
      includeVideos.value = json['includeVideos'] ?? includeVideos.value;
      displayTrackNumberinAlbumPage.value = json['displayTrackNumberinAlbumPage'] ?? displayTrackNumberinAlbumPage.value;
      albumCardTopRightDate.value = json['albumCardTopRightDate'] ?? albumCardTopRightDate.value;
      forceSquaredTrackThumbnail.value = json['forceSquaredTrackThumbnail'] ?? forceSquaredTrackThumbnail.value;
      forceSquaredAlbumThumbnail.value = json['forceSquaredAlbumThumbnail'] ?? forceSquaredAlbumThumbnail.value;
      useAlbumStaggeredGridView.value = json['useAlbumStaggeredGridView'] ?? useAlbumStaggeredGridView.value;
      useSettingCollapsedTiles.value = json['useSettingCollapsedTiles'] ?? useSettingCollapsedTiles.value;

      final mediaGridCountsInStorage = json["mediaGridCounts"];
      if (mediaGridCountsInStorage is Map && mediaGridCountsInStorage.isNotEmpty) {
        final map = {
          for (final e in mediaGridCountsInStorage.entries) LibraryTab.values.getEnum(e.key) ?? LibraryTab.tracks: CountPerRow.fromJsonValue(e.value),
        };
        mediaGridCounts
          ..addAll(map)
          ..refresh();
      }
      final activeAlbumTypesInStorage = json["activeAlbumTypes"];
      if (activeAlbumTypesInStorage is Map && activeAlbumTypesInStorage.isNotEmpty) {
        final map = <AlbumType, bool>{
          for (final e in activeAlbumTypesInStorage.entries) AlbumType.values.getEnum(e.key) ?? AlbumType.normal: e.value ?? true,
        };
        activeAlbumTypes
          ..addAll(map)
          ..refresh();
      }
      enableBlurEffect.value = json['enableBlurEffect'] ?? enableBlurEffect.value;
      enableGlowEffect.value = json['enableGlowEffect'] ?? enableGlowEffect.value;
      enableGlowBehindVideo.value = json['enableGlowBehindVideo'] ?? enableGlowBehindVideo.value;
      hourFormat12.value = json['hourFormat12'] ?? hourFormat12.value;
      dateTimeFormat.value = json['dateTimeFormat'] ?? dateTimeFormat.value;

      if (json['trackArtistsSeparators'] is List) trackArtistsSeparators.value = (json['trackArtistsSeparators'] as List).cast<String>();
      if (json['trackGenresSeparators'] is List) trackGenresSeparators.value = (json['trackGenresSeparators'] as List).cast<String>();
      if (json['trackArtistsSeparatorsBlacklist'] is List) trackArtistsSeparatorsBlacklist.value = (json['trackArtistsSeparatorsBlacklist'] as List).cast<String>();
      if (json['trackGenresSeparatorsBlacklist'] is List) trackGenresSeparatorsBlacklist.value = (json['trackGenresSeparatorsBlacklist'] as List).cast<String>();
      fileBrowserSort.value = FileBrowserSortType.values.getEnum(json['fileBrowserSort']) ?? fileBrowserSort.value;
      fileBrowserSortReversed.value = json['fileBrowserSortReversed'] ?? fileBrowserSortReversed.value;
      tracksSortSearch.value = SortType.values.getEnum(json['tracksSortSearch']) ?? tracksSortSearch.value;
      tracksSortSearchReversed.value = json['tracksSortSearchReversed'] ?? tracksSortSearchReversed.value;
      tracksSortSearchIsAuto.value = json['tracksSortSearchIsAuto'] ?? tracksSortSearchIsAuto.value;
      albumSort.value = GroupSortType.values.getEnum(json['albumSort']) ?? albumSort.value;
      albumSortReversed.value = json['albumSortReversed'] ?? albumSortReversed.value;
      artistSort.value = GroupSortType.values.getEnum(json['artistSort']) ?? artistSort.value;
      artistSortReversed.value = json['artistSortReversed'] ?? artistSortReversed.value;
      genreSort.value = GroupSortType.values.getEnum(json['genreSort']) ?? genreSort.value;
      genreSortReversed.value = json['genreSortReversed'] ?? genreSortReversed.value;
      playlistSort.value = GroupSortType.values.getEnum(json['playlistSort']) ?? playlistSort.value;
      playlistSortReversed.value = json['playlistSortReversed'] ?? playlistSortReversed.value;
      ytPlaylistSort.value = GroupSortType.values.getEnum(json['ytPlaylistSort']) ?? ytPlaylistSort.value;
      ytPlaylistSortReversed.value = json['ytPlaylistSortReversed'] ?? ytPlaylistSortReversed.value;
      indexMinDurationInSec.value = json['indexMinDurationInSec'] ?? indexMinDurationInSec.value;
      indexMinFileSizeInB.value = json['indexMinFileSizeInB'] ?? indexMinFileSizeInB.value;

      try {
        // -- backward compability, since the previous type was String
        final trackSearchFilterInStorage = json['trackSearchFilter'];
        if (trackSearchFilterInStorage is List) {
          trackSearchFilter.value = trackSearchFilterInStorage.map((e) => TrackSearchFilter.values.getEnum(e)).toListy();
        }
      } catch (_) {}

      try {
        final ignoreCommonPrefixForTypesInStorage = json['ignoreCommonPrefixForTypes'];
        if (ignoreCommonPrefixForTypesInStorage is List) {
          ignoreCommonPrefixForTypes.value = ignoreCommonPrefixForTypesInStorage.map((e) => TrackSearchFilter.values.getEnum(e)).toListy();
        }
      } catch (_) {}
      if (json['commonPrefixes'] is List) commonPrefixes.value = (json['commonPrefixes'] as List).cast<String>();

      if (json['playlistSearchFilter'] is List) playlistSearchFilter.value = (json['playlistSearchFilter'] as List).cast<String>();
      if (json['directoriesToScan'] is List) directoriesToScan.value = (json['directoriesToScan'] as List).cast<String>();
      if (json['directoriesToExclude'] is List) directoriesToExclude.value = (json['directoriesToExclude'] as List).cast<String>();
      preventDuplicatedTracks.value = json['preventDuplicatedTracks'] ?? preventDuplicatedTracks.value;
      respectNoMedia.value = json['respectNoMedia'] ?? respectNoMedia.value;
      defaultBackupLocation.value = json['defaultBackupLocation_v2'] ?? defaultBackupLocation.value;
      autoBackupIntervalDays.value = json['autoBackupIntervalDays'] ?? autoBackupIntervalDays.value;
      defaultFolderStartupLocation.value = json['defaultFolderStartupLocation'] ?? defaultFolderStartupLocation.value;
      defaultFolderStartupLocationVideos.value = json['defaultFolderStartupLocationVideos'] ?? defaultFolderStartupLocationVideos.value;

      enableFoldersHierarchy.value = json['enableFoldersHierarchy'] ?? enableFoldersHierarchy.value;
      enableFoldersHierarchyVideos.value = json['enableFoldersHierarchyVideos'] ?? enableFoldersHierarchyVideos.value;
      displayArtistBeforeTitle.value = json['displayArtistBeforeTitle'] ?? displayArtistBeforeTitle.value;
      heatmapListensView.value = json['heatmapListensView'] ?? heatmapListensView.value;
      reverseListensView.value = json['reverseListensView'] ?? reverseListensView.value;
      if (json['backupItemslist_v2'] is List) {
        backupItemslist.value = (json['backupItemslist_v2'] as List).map((v) => AppPathsBackupEnum.values.getEnum(v)).whereType<AppPathsBackupEnum>().toList();
      }
      enableVideoPlayback.value = json['enableVideoPlayback'] ?? enableVideoPlayback.value;
      enableLyrics.value = json['enableLyrics'] ?? enableLyrics.value;
      lyricsSource.value = LyricsSource.values.getEnum(json['lyricsSource']) ?? lyricsSource.value;
      videoPlaybackSource.value = VideoPlaybackSource.values.getEnum(json['videoPlaybackSource']) ?? videoPlaybackSource.value;
      if (json['youtubeVideoQualities'] is List) youtubeVideoQualities.value = (json['youtubeVideoQualities'] as List).cast<String>();

      animatingThumbnailScaleMultiplier.value = json['animatingThumbnailScaleMultiplier'] ?? animatingThumbnailScaleMultiplier.value;
      animatingThumbnailIntensity.value = json['animatingThumbnailIntensity'] ?? animatingThumbnailIntensity.value;
      animatingThumbnailIntensityLyrics.value = json['animatingThumbnailIntensityLyrics'] ?? animatingThumbnailIntensityLyrics.value;
      animatingThumbnailIntensityMinimized.value = json['animatingThumbnailIntensityMinimized'] ?? animatingThumbnailIntensityMinimized.value;
      animatingThumbnailInversed.value = json['animatingThumbnailInversed'] ?? animatingThumbnailInversed.value;
      enablePartyModeInMiniplayer.value = json['enablePartyModeInMiniplayer'] ?? enablePartyModeInMiniplayer.value;
      enablePartyModeColorSwap.value = json['enablePartyModeColorSwap'] ?? enablePartyModeColorSwap.value;
      enableMiniplayerParticles.value = json['enableMiniplayerParticles'] ?? enableMiniplayerParticles.value;
      enableMiniplayerParallaxEffect.value = json['enableMiniplayerParallaxEffect'] ?? enableMiniplayerParallaxEffect.value;
      forceMiniplayerTrackColor.value = json['forceMiniplayerTrackColor'] ?? forceMiniplayerTrackColor.value;
      isTrackPlayedSecondsCount.value = json['isTrackPlayedSecondsCount'] ?? isTrackPlayedSecondsCount.value;
      isTrackPlayedPercentageCount.value = json['isTrackPlayedPercentageCount'] ?? isTrackPlayedPercentageCount.value;
      waveformTotalBars.value = json['waveformTotalBars'] ?? waveformTotalBars.value;
      videosMaxCacheInMB.value = json['videosMaxCacheInMB'] ?? videosMaxCacheInMB.value;
      audiosMaxCacheInMB.value = json['audiosMaxCacheInMB'] ?? audiosMaxCacheInMB.value;
      imagesMaxCacheInMB.value = json['imagesMaxCacheInMB'] ?? imagesMaxCacheInMB.value;
      hideStatusBarInExpandedMiniplayer.value = json['hideStatusBarInExpandedMiniplayer'] ?? hideStatusBarInExpandedMiniplayer.value;
      displayFavouriteButtonInNotification.value = json['displayFavouriteButtonInNotification'] ?? displayFavouriteButtonInNotification.value;
      displayStopButtonInNotification.value = json['displayStopButtonInNotification'] ?? displayStopButtonInNotification.value;
      enableSearchCleanup.value = json['enableSearchCleanup'] ?? enableSearchCleanup.value;
      enableBottomNavBar.value = json['enableBottomNavBar'] ?? enableBottomNavBar.value;
      displayAudioInfoMiniplayer.value = json['displayAudioInfoMiniplayer'] ?? displayAudioInfoMiniplayer.value;
      showUnknownFieldsInTrackInfoDialog.value = json['showUnknownFieldsInTrackInfoDialog'] ?? showUnknownFieldsInTrackInfoDialog.value;
      extractFeatArtistFromTitle.value = json['extractFeatArtistFromTitle'] ?? extractFeatArtistFromTitle.value;
      groupArtworksByAlbum.value = json['groupArtworksByAlbum'] ?? groupArtworksByAlbum.value;
      uniqueArtworkHash.value = json['uniqueArtworkHash'] ?? uniqueArtworkHash.value;
      enableM3USync.value = json['enableM3USync'] ?? enableM3USync.value;
      enableM3USyncStartup.value = json['enableM3USyncStartup'] ?? enableM3USyncStartup.value;
      prioritizeEmbeddedLyrics.value = json['prioritizeEmbeddedLyrics'] ?? prioritizeEmbeddedLyrics.value;
      swipeableDrawer.value = json['swipeableDrawer'] ?? swipeableDrawer.value;
      dismissibleMiniplayer.value = json['dismissibleMiniplayer'] ?? dismissibleMiniplayer.value;
      enableClipboardMonitoring.value = json['enableClipboardMonitoring'] ?? enableClipboardMonitoring.value;
      artworkGestureDoubleTapLRC.value = json['artworkGestureDoubleTapLRC'] ?? artworkGestureDoubleTapLRC.value;
      previousButtonReplays.value = json['previousButtonReplays'] ?? previousButtonReplays.value;
      refreshOnStartup.value = json['refreshOnStartup'] ?? refreshOnStartup.value;
      alwaysExpandedSearchbar.value = json['alwaysExpandedSearchbar'] ?? alwaysExpandedSearchbar.value;
      mixedQueue.value = json['mixedQueue'] ?? mixedQueue.value;

      final tagFieldsToEditStorage = json['tagFieldsToEdit'];
      if (tagFieldsToEditStorage is List) {
        tagFieldsToEdit.value = tagFieldsToEditStorage.map((e) => TagField.values.getEnum(e as String)).toListy<TagField>();
      }

      stretchLyricsDuration.value = json['stretchLyricsDuration'] ?? stretchLyricsDuration.value;
      playlistAddTracksAtBeginning.value = json['playlistAddTracksAtBeginning'] ?? playlistAddTracksAtBeginning.value;
      playlistAddTracksAtBeginningYT.value = json['playlistAddTracksAtBeginningYT'] ?? playlistAddTracksAtBeginningYT.value;
      wakelockMode.value = WakelockMode.values.getEnum(json['wakelockMode']) ?? wakelockMode.value;

      localVideoMatchingType.value = LocalVideoMatchingType.values.getEnum(json['localVideoMatchingType']) ?? localVideoMatchingType.value;
      localVideoMatchingCheckSameDir.value = json['localVideoMatchingCheckSameDir'] ?? localVideoMatchingCheckSameDir.value;

      trackPlayMode.value = TrackPlayMode.values.getEnum(json['trackPlayMode']) ?? trackPlayMode.value;

      mostPlayedTimeRange.value = MostPlayedTimeRange.values.getEnum(json['mostPlayedTimeRange']) ?? mostPlayedTimeRange.value;
      mostPlayedCustomDateRange.value = json['mostPlayedCustomDateRange'] != null ? DateRange.fromJson(json['mostPlayedCustomDateRange']) : mostPlayedCustomDateRange.value;
      mostPlayedCustomisStartOfDay.value = json['mostPlayedCustomisStartOfDay'] ?? mostPlayedCustomisStartOfDay.value;

      ytMostPlayedTimeRange.value = MostPlayedTimeRange.values.getEnum(json['ytMostPlayedTimeRange']) ?? ytMostPlayedTimeRange.value;
      ytMostPlayedCustomDateRange.value = json['ytMostPlayedCustomDateRange'] != null ? DateRange.fromJson(json['ytMostPlayedCustomDateRange']) : ytMostPlayedCustomDateRange.value;
      ytMostPlayedCustomisStartOfDay.value = json['ytMostPlayedCustomisStartOfDay'] ?? ytMostPlayedCustomisStartOfDay.value;

      onTrackSwipeLeft.value = TrackExecuteActions.values.getEnum(json['onTrackSwipeLeft']) ?? onTrackSwipeLeft.value;
      onTrackSwipeRight.value = TrackExecuteActions.values.getEnum(json['onTrackSwipeRight']) ?? onTrackSwipeRight.value;
      artworkTapAction.value = TrackExecuteActions.values.getEnum(json['artworkTapAction']) ?? artworkTapAction.value;
      artworkLongPressAction.value = TrackExecuteActions.values.getEnum(json['artworkLongPressAction']) ?? artworkLongPressAction.value;

      /// Track Items
      displayThirdRow.value = json['displayThirdRow'] ?? displayThirdRow.value;
      displayThirdItemInEachRow.value = json['displayThirdItemInEachRow'] ?? displayThirdItemInEachRow.value;
      trackTileSeparator.value = json['trackTileSeparator'] ?? trackTileSeparator.value;
      displayFavouriteIconInListTile.value = json['displayFavouriteIconInListTile'] ?? displayFavouriteIconInListTile.value;
      gradientTiles.value = json['gradientTiles'] ?? gradientTiles.value;
      editTagsKeepFileDates.value = json['editTagsKeepFileDates'] ?? editTagsKeepFileDates.value;
      downloadFilesWriteUploadDate.value = json['downloadFilesWriteUploadDate'] ?? downloadFilesWriteUploadDate.value;
      downloadFilesKeepCachedVersions.value = json['downloadFilesKeepCachedVersions'] ?? downloadFilesKeepCachedVersions.value;
      downloadAddAudioToLocalLibrary.value = json['downloadAddAudioToLocalLibrary'] ?? downloadAddAudioToLocalLibrary.value;
      downloadAudioOnly.value = json['downloadAudioOnly'] ?? downloadAudioOnly.value;
      downloadOverrideOldFiles.value = json['downloadOverrideOldFiles'] ?? downloadOverrideOldFiles.value;
      enablePip.value = json['enablePip'] ?? enablePip.value;
      pickColorsFromDeviceWallpaper.value = json['pickColorsFromDeviceWallpaper'] ?? pickColorsFromDeviceWallpaper.value;
      onNotificationTapAction.value = NotificationTapAction.values.getEnum(json['onNotificationTapAction']) ?? onNotificationTapAction.value;
      performanceMode.value = PerformanceMode.values.getEnum(json['performanceMode']) ?? performanceMode.value;
      floatingActionButton.value = FABType.values.getEnum(json['floatingActionButton']) ?? floatingActionButton.value;
      vibrationType.value = VibrationType.values.getEnum(json['vibrationType']) ?? vibrationType.value;

      trackItem
        ..value.addAll(getEnumMap_(
              json['trackItem'],
              TrackTilePosition.values,
              TrackTilePosition.rightItem3,
              TrackTileItem.values,
              TrackTileItem.none,
            ) ??
            trackItem.value.map((key, value) => MapEntry(key, value)))
        ..refresh();

      queueInsertion
        ..value.addAll(((json["queueInsertion"] as Map?)?.map(
              (key, value) => MapEntry(QueueInsertionType.values.getEnum(key) ?? QueueInsertionType.moreAlbum, QueueInsertion.fromJson(value)),
            )) ??
            queueInsertion.value.map((key, value) => MapEntry(key, value)))
        ..refresh();

      final mediaItemsTrackSortingInStorage = json["mediaItemsTrackSorting"] as Map? ?? {};
      mediaItemsTrackSorting
        ..addAll({
          for (final e in mediaItemsTrackSortingInStorage.entries)
            MediaType.values.getEnum(e.key) ?? MediaType.track: (e.value as List?)?.map((v) => SortType.values.getEnum(v) ?? SortType.title).toList() ?? <SortType>[SortType.year]
        })
        ..refresh();
      final mediaItemsTrackSortingReverseInStorage = json["mediaItemsTrackSortingReverse"] as Map? ?? {};

      mediaItemsTrackSortingReverse
        ..addAll({for (final e in mediaItemsTrackSortingReverseInStorage.entries) MediaType.values.getEnum(e.key) ?? MediaType.track: e.value})
        ..refresh();

      final imageSourceAlbumFromStorage = json['imageSourceAlbum'];
      if (imageSourceAlbumFromStorage is List) imageSourceAlbum.value = imageSourceAlbumFromStorage.map((e) => LibraryImageSource.values.getEnum(e)).toListy();

      final imageSourceArtistFromStorage = json['imageSourceArtist'];
      if (imageSourceArtistFromStorage is List) imageSourceArtist.value = imageSourceArtistFromStorage.map((e) => LibraryImageSource.values.getEnum(e)).toListy();

      // -- backward compatability
      if (json['tracksSort'] != null) {
        final value = SortType.values.getEnum(json['tracksSort']);
        if (value != null) mediaItemsTrackSorting.value.insertForce(0, MediaType.track, value);
      }
      if (json['tracksSortReversed'] != null) {
        final value = json['tracksSortReversed'] as bool;
        mediaItemsTrackSortingReverse.value[MediaType.track] = value;
      }
      // ------------------

      fontScaleLRC = json['fontScaleLRC'] ?? fontScaleLRC;
      fontScaleLRCFull = json['fontScaleLRCFull'] ?? fontScaleLRC; // fallback to normal

      final windowBoundsJson = json['windowBounds'];
      if (windowBoundsJson is Map) {
        this.windowBounds = Rect.fromLTRB(
          windowBoundsJson['l'],
          windowBoundsJson['t'],
          windowBoundsJson['r'],
          windowBoundsJson['b'],
        );
      }

      canAskForBatteryOptimizations = json['canAskForBatteryOptimizations'] ?? canAskForBatteryOptimizations;
    } catch (e, st) {
      printy(e, isError: true);
      logger.report(e, st);
    }
  }

  @override
  Object get jsonToWrite => {
        'selectedLanguage': selectedLanguage.value.toJson(),
        'themeMode': themeMode.value.name,
        'pitchBlack': pitchBlack.value,
        'autoColor': autoColor.value,
        'animatedTheme': animatedTheme.value,
        'staticColor': staticColor.value,
        'staticColorDark': staticColorDark.value,
        'libraryTabs': libraryTabs.mapped((element) => element.name),
        'homePageItems': homePageItems.mapped((element) => element.name),
        'activeArtistType': activeArtistType.value.name,
        'activeSearchMediaTypes': activeSearchMediaTypes.mapped((element) => element.name),
        'albumIdentifiers': albumIdentifiers.mapped((element) => element.name),
        'borderRadiusMultiplier': borderRadiusMultiplier.value,
        'fontScaleFactor': fontScaleFactor.value,
        'artworkCacheHeightMultiplier': artworkCacheHeightMultiplier.value,
        'trackThumbnailSizeinList': trackThumbnailSizeinList.value,
        'trackListTileHeight': trackListTileHeight.value,
        'albumThumbnailSizeinList': albumThumbnailSizeinList.value,
        'albumListTileHeight': albumListTileHeight.value,

        'useMediaStore': useMediaStore.value,
        'includeVideos': includeVideos.value,
        'displayTrackNumberinAlbumPage': displayTrackNumberinAlbumPage.value,
        'albumCardTopRightDate': albumCardTopRightDate.value,
        'forceSquaredTrackThumbnail': forceSquaredTrackThumbnail.value,
        'forceSquaredAlbumThumbnail': forceSquaredAlbumThumbnail.value,
        'useAlbumStaggeredGridView': useAlbumStaggeredGridView.value,
        'useSettingCollapsedTiles': useSettingCollapsedTiles.value,
        'mediaGridCounts': mediaGridCounts.value.map((key, value) => MapEntry(key.name, value?.rawValue)),
        'activeAlbumTypes': activeAlbumTypes.value.map((key, value) => MapEntry(key.name, value)),
        'enableBlurEffect': enableBlurEffect.value,
        'enableGlowEffect': enableGlowEffect.value,
        'enableGlowBehindVideo': enableGlowBehindVideo.value,
        'hourFormat12': hourFormat12.value,
        'dateTimeFormat': dateTimeFormat.value,
        'trackArtistsSeparators': trackArtistsSeparators.value,
        'trackGenresSeparators': trackGenresSeparators.value,
        'trackArtistsSeparatorsBlacklist': trackArtistsSeparatorsBlacklist.value,
        'trackGenresSeparatorsBlacklist': trackGenresSeparatorsBlacklist.value,
        'fileBrowserSort': fileBrowserSort.value.name,
        'fileBrowserSortReversed': fileBrowserSortReversed.value,
        'tracksSortSearch': tracksSortSearch.value.name,
        'tracksSortSearchReversed': tracksSortSearchReversed.value,
        'tracksSortSearchIsAuto': tracksSortSearchIsAuto.value,
        'albumSort': albumSort.value.name,
        'albumSortReversed': albumSortReversed.value,
        'artistSort': artistSort.value.name,
        'artistSortReversed': artistSortReversed.value,
        'genreSort': genreSort.value.name,
        'genreSortReversed': genreSortReversed.value,
        'playlistSort': playlistSort.value.name,
        'playlistSortReversed': playlistSortReversed.value,
        'ytPlaylistSort': ytPlaylistSort.value.name,
        'ytPlaylistSortReversed': ytPlaylistSortReversed.value,
        'indexMinDurationInSec': indexMinDurationInSec.value,
        'indexMinFileSizeInB': indexMinFileSizeInB.value,
        'trackSearchFilter': trackSearchFilter.value.mapped((e) => e.name),
        'ignoreCommonPrefixForTypes': ignoreCommonPrefixForTypes.value.mapped((e) => e.name),
        'commonPrefixes': commonPrefixes.value,
        'playlistSearchFilter': playlistSearchFilter.value,
        'directoriesToScan': directoriesToScan.value,
        'directoriesToExclude': directoriesToExclude.value,
        'preventDuplicatedTracks': preventDuplicatedTracks.value,
        'respectNoMedia': respectNoMedia.value,
        'defaultBackupLocation_v2': defaultBackupLocation.value,
        'autoBackupIntervalDays': autoBackupIntervalDays.value,
        'defaultFolderStartupLocation': defaultFolderStartupLocation.value,
        'defaultFolderStartupLocationVideos': defaultFolderStartupLocationVideos.value,
        'enableFoldersHierarchy': enableFoldersHierarchy.value,
        'enableFoldersHierarchyVideos': enableFoldersHierarchyVideos.value,
        'displayArtistBeforeTitle': displayArtistBeforeTitle.value,
        'heatmapListensView': heatmapListensView.value,
        'reverseListensView': reverseListensView.value,
        'backupItemslist_v2': backupItemslist.value?.map((e) => e.name).toList(),
        'enableVideoPlayback': enableVideoPlayback.value,
        'enableLyrics': enableLyrics.value,
        'lyricsSource': lyricsSource.value.name,
        'videoPlaybackSource': videoPlaybackSource.value.name,
        'youtubeVideoQualities': youtubeVideoQualities.value,
        'animatingThumbnailScaleMultiplier': animatingThumbnailScaleMultiplier.value,
        'animatingThumbnailIntensity': animatingThumbnailIntensity.value,
        'animatingThumbnailIntensityLyrics': animatingThumbnailIntensityLyrics.value,
        'animatingThumbnailIntensityMinimized': animatingThumbnailIntensityMinimized.value,
        'animatingThumbnailInversed': animatingThumbnailInversed.value,
        'enablePartyModeInMiniplayer': enablePartyModeInMiniplayer.value,
        'enablePartyModeColorSwap': enablePartyModeColorSwap.value,
        'enableMiniplayerParticles': enableMiniplayerParticles.value,
        'enableMiniplayerParallaxEffect': enableMiniplayerParallaxEffect.value,
        'forceMiniplayerTrackColor': forceMiniplayerTrackColor.value,
        'isTrackPlayedSecondsCount': isTrackPlayedSecondsCount.value,
        'isTrackPlayedPercentageCount': isTrackPlayedPercentageCount.value,
        'waveformTotalBars': waveformTotalBars.value,
        'videosMaxCacheInMB': videosMaxCacheInMB.value,
        'audiosMaxCacheInMB': audiosMaxCacheInMB.value,
        'imagesMaxCacheInMB': imagesMaxCacheInMB.value,
        'hideStatusBarInExpandedMiniplayer': hideStatusBarInExpandedMiniplayer.value,
        'displayFavouriteButtonInNotification': displayFavouriteButtonInNotification.value,
        'displayStopButtonInNotification': displayStopButtonInNotification.value,
        'enableSearchCleanup': enableSearchCleanup.value,
        'enableBottomNavBar': enableBottomNavBar.value,
        'displayAudioInfoMiniplayer': displayAudioInfoMiniplayer.value,
        'showUnknownFieldsInTrackInfoDialog': showUnknownFieldsInTrackInfoDialog.value,
        'extractFeatArtistFromTitle': extractFeatArtistFromTitle.value,
        'groupArtworksByAlbum': groupArtworksByAlbum.value,
        'uniqueArtworkHash': uniqueArtworkHash.value,
        'enableM3USync': enableM3USync.value,
        'enableM3USyncStartup': enableM3USyncStartup.value,
        'prioritizeEmbeddedLyrics': prioritizeEmbeddedLyrics.value,
        'swipeableDrawer': swipeableDrawer.value,
        'dismissibleMiniplayer': dismissibleMiniplayer.value,
        'enableClipboardMonitoring': enableClipboardMonitoring.value,
        'artworkGestureDoubleTapLRC': artworkGestureDoubleTapLRC.value,
        'previousButtonReplays': previousButtonReplays.value,
        'refreshOnStartup': refreshOnStartup.value,
        'alwaysExpandedSearchbar': alwaysExpandedSearchbar.value,
        'mixedQueue': mixedQueue.value,
        'tagFieldsToEdit': tagFieldsToEdit.mapped((element) => element.name),
        'stretchLyricsDuration': stretchLyricsDuration.value,
        'playlistAddTracksAtBeginning': playlistAddTracksAtBeginning.value,
        'playlistAddTracksAtBeginningYT': playlistAddTracksAtBeginningYT.value,
        'wakelockMode': wakelockMode.value.name,
        'localVideoMatchingType': localVideoMatchingType.value.name,
        'localVideoMatchingCheckSameDir': localVideoMatchingCheckSameDir.value,
        'trackPlayMode': trackPlayMode.value.name,
        'onNotificationTapAction': onNotificationTapAction.value.name,
        'performanceMode': performanceMode.value.name,
        'floatingActionButton': floatingActionButton.value.name,
        'vibrationType': vibrationType.value.name,
        'mostPlayedTimeRange': mostPlayedTimeRange.value.name,
        'mostPlayedCustomDateRange': mostPlayedCustomDateRange.value.toJson(),
        'mostPlayedCustomisStartOfDay': mostPlayedCustomisStartOfDay.value,
        'ytMostPlayedTimeRange': ytMostPlayedTimeRange.value.name,
        'ytMostPlayedCustomDateRange': ytMostPlayedCustomDateRange.value.toJson(),
        'ytMostPlayedCustomisStartOfDay': ytMostPlayedCustomisStartOfDay.value,

        'onTrackSwipeLeft': onTrackSwipeLeft.value.name,
        'onTrackSwipeRight': onTrackSwipeRight.value.name,
        'artworkTapAction': artworkTapAction.value.name,
        'artworkLongPressAction': artworkLongPressAction.value.name,

        /// Track Items
        'displayThirdRow': displayThirdRow.value,
        'displayThirdItemInEachRow': displayThirdItemInEachRow.value,
        'trackTileSeparator': trackTileSeparator.value,
        'displayFavouriteIconInListTile': displayFavouriteIconInListTile.value,
        'gradientTiles': gradientTiles.value,
        'editTagsKeepFileDates': editTagsKeepFileDates.value,
        'downloadFilesWriteUploadDate': downloadFilesWriteUploadDate.value,
        'downloadFilesKeepCachedVersions': downloadFilesKeepCachedVersions.value,
        'downloadAddAudioToLocalLibrary': downloadAddAudioToLocalLibrary.value,
        'downloadAudioOnly': downloadAudioOnly.value,
        'downloadOverrideOldFiles': downloadOverrideOldFiles.value,
        'enablePip': enablePip.value,
        'pickColorsFromDeviceWallpaper': pickColorsFromDeviceWallpaper.value,
        'trackItem': trackItem.value.map((key, value) => MapEntry(key.name, value.name)),
        'queueInsertion': queueInsertion.value.map((key, value) => MapEntry(key.name, value.toJson())),
        'mediaItemsTrackSorting': mediaItemsTrackSorting.value.map((key, value) => MapEntry(key.name, value.map((e) => e.name).toList())),
        'mediaItemsTrackSortingReverse': mediaItemsTrackSortingReverse.value.map((key, value) => MapEntry(key.name, value)),
        'imageSourceAlbum': imageSourceAlbum.value.map((e) => e.name).toList(),
        'imageSourceArtist': imageSourceArtist.value.map((e) => e.name).toList(),

        'fontScaleLRC': fontScaleLRC,
        'fontScaleLRCFull': fontScaleLRCFull,
        if (windowBounds != null)
          'windowBounds': {
            'l': windowBounds!.left,
            't': windowBounds!.top,
            'r': windowBounds!.right,
            'b': windowBounds!.bottom,
          },

        'canAskForBatteryOptimizations': canAskForBatteryOptimizations,
      };

  /// Writes the values of this  class to a json file, with a minimum interval of [2 seconds]
  /// to prevent rediculous numbers of successive writes, especially for widgets like [NamidaWheelSlider]
  Future<void> _writeToStorage() async => await writeToStorage();

  /// Saves a value to the key, if [List] or [Set], then it will add to it.
  void save({
    NamidaLanguage? selectedLanguage,
    ThemeMode? themeMode,
    bool? pitchBlack,
    bool? autoColor,
    bool? animatedTheme,
    int? staticColor,
    int? staticColorDark,
    List<LibraryTab>? libraryTabs,
    List<HomePageItems>? homePageItems,
    MediaType? activeArtistType,
    List<MediaType>? activeSearchMediaTypes,
    List<AlbumIdentifier>? albumIdentifiers,
    double? borderRadiusMultiplier,
    double? fontScaleFactor,
    double? artworkCacheHeightMultiplier,
    double? trackThumbnailSizeinList,
    double? trackListTileHeight,
    double? albumThumbnailSizeinList,
    double? albumListTileHeight,
    bool? useMediaStore,
    bool? includeVideos,
    bool? displayTrackNumberinAlbumPage,
    bool? albumCardTopRightDate,
    bool? forceSquaredTrackThumbnail,
    bool? forceSquaredAlbumThumbnail,
    bool? useAlbumStaggeredGridView,
    bool? useSettingCollapsedTiles,
    bool? enableBlurEffect,
    bool? enableGlowEffect,
    bool? enableGlowBehindVideo,
    bool? hourFormat12,
    String? dateTimeFormat,
    List<String>? trackArtistsSeparators,
    List<String>? trackGenresSeparators,
    List<String>? trackArtistsSeparatorsBlacklist,
    List<String>? trackGenresSeparatorsBlacklist,
    FileBrowserSortType? fileBrowserSort,
    bool? fileBrowserSortReversed,
    SortType? tracksSortSearch,
    bool? tracksSortSearchReversed,
    bool? tracksSortSearchIsAuto,
    GroupSortType? albumSort,
    bool? albumSortReversed,
    GroupSortType? artistSort,
    bool? artistSortReversed,
    GroupSortType? genreSort,
    bool? genreSortReversed,
    GroupSortType? playlistSort,
    bool? playlistSortReversed,
    GroupSortType? ytPlaylistSort,
    bool? ytPlaylistSortReversed,
    TrackExecuteActions? onTrackSwipeLeft,
    TrackExecuteActions? onTrackSwipeRight,
    TrackExecuteActions? artworkTapAction,
    TrackExecuteActions? artworkLongPressAction,
    bool? displayThirdRow,
    bool? displayThirdItemInEachRow,
    String? trackTileSeparator,
    int? indexMinDurationInSec,
    int? indexMinFileSizeInB,
    List<TrackSearchFilter>? trackSearchFilter,
    List<TrackSearchFilter>? ignoreCommonPrefixForTypes,
    List<String>? commonPrefixes,
    List<String>? playlistSearchFilter,
    List<String>? directoriesToScan,
    List<String>? directoriesToExclude,
    bool? preventDuplicatedTracks,
    bool? respectNoMedia,
    String? defaultBackupLocation,
    int? autoBackupIntervalDays,
    String? defaultFolderStartupLocation,
    String? defaultFolderStartupLocationVideos,
    bool? enableFoldersHierarchy,
    bool? enableFoldersHierarchyVideos,
    bool? displayArtistBeforeTitle,
    bool? heatmapListensView,
    bool? reverseListensView,
    List<AppPathsBackupEnum>? backupItemslist,
    bool? enableVideoPlayback,
    bool? enableLyrics,
    LyricsSource? lyricsSource,
    VideoPlaybackSource? videoPlaybackSource,
    List<String>? youtubeVideoQualities,
    double? animatingThumbnailScaleMultiplier,
    int? animatingThumbnailIntensity,
    int? animatingThumbnailIntensityLyrics,
    int? animatingThumbnailIntensityMinimized,
    bool? animatingThumbnailInversed,
    bool? enablePartyModeInMiniplayer,
    bool? enablePartyModeColorSwap,
    bool? enableMiniplayerParticles,
    bool? enableMiniplayerParallaxEffect,
    bool? forceMiniplayerTrackColor,
    int? isTrackPlayedSecondsCount,
    int? isTrackPlayedPercentageCount,
    bool? displayFavouriteIconInListTile,
    bool? gradientTiles,
    bool? editTagsKeepFileDates,
    bool? downloadFilesWriteUploadDate,
    bool? downloadFilesKeepCachedVersions,
    bool? downloadAddAudioToLocalLibrary,
    bool? downloadAudioOnly,
    bool? downloadOverrideOldFiles,
    bool? enablePip,
    bool? pickColorsFromDeviceWallpaper,
    int? waveformTotalBars,
    int? videosMaxCacheInMB,
    int? audiosMaxCacheInMB,
    int? imagesMaxCacheInMB,
    bool? hideStatusBarInExpandedMiniplayer,
    bool? displayFavouriteButtonInNotification,
    bool? displayStopButtonInNotification,
    bool? enableSearchCleanup,
    bool? enableBottomNavBar,
    bool? displayAudioInfoMiniplayer,
    bool? showUnknownFieldsInTrackInfoDialog,
    bool? extractFeatArtistFromTitle,
    bool? groupArtworksByAlbum,
    bool? uniqueArtworkHash,
    bool? enableM3USync,
    bool? enableM3USyncStartup,
    bool? prioritizeEmbeddedLyrics,
    bool? swipeableDrawer,
    bool? dismissibleMiniplayer,
    bool? enableClipboardMonitoring,
    bool? artworkGestureDoubleTapLRC,
    bool? previousButtonReplays,
    bool? refreshOnStartup,
    bool? alwaysExpandedSearchbar,
    bool? mixedQueue,
    List<TagField>? tagFieldsToEdit,
    bool? stretchLyricsDuration,
    bool? playlistAddTracksAtBeginning,
    bool? playlistAddTracksAtBeginningYT,
    WakelockMode? wakelockMode,
    LocalVideoMatchingType? localVideoMatchingType,
    bool? localVideoMatchingCheckSameDir,
    TrackPlayMode? trackPlayMode,
    NotificationTapAction? onNotificationTapAction,
    PerformanceMode? performanceMode,
    FABType? floatingActionButton,
    VibrationType? vibrationType,
    MostPlayedTimeRange? mostPlayedTimeRange,
    DateRange? mostPlayedCustomDateRange,
    bool? mostPlayedCustomisStartOfDay,
    MostPlayedTimeRange? ytMostPlayedTimeRange,
    DateRange? ytMostPlayedCustomDateRange,
    bool? ytMostPlayedCustomisStartOfDay,
    double? fontScaleLRC,
    double? fontScaleLRCFull,
    Rect? windowBounds,
    bool? didSupportNamida,
    bool? canAskForBatteryOptimizations,
  }) {
    if (selectedLanguage != null) this.selectedLanguage.value = selectedLanguage;
    if (themeMode != null) this.themeMode.value = themeMode;
    if (pitchBlack != null) this.pitchBlack.value = pitchBlack;
    if (autoColor != null) this.autoColor.value = autoColor;
    if (animatedTheme != null) this.animatedTheme.value = animatedTheme;
    if (staticColor != null) this.staticColor.value = staticColor;
    if (staticColorDark != null) this.staticColorDark.value = staticColorDark;
    if (libraryTabs != null) {
      libraryTabs.loop((t) {
        if (!this.libraryTabs.contains(t)) {
          this.libraryTabs.add(t);
        }
      });
    }
    if (homePageItems != null) {
      homePageItems.loop((t) {
        if (!this.homePageItems.contains(t)) {
          this.homePageItems.add(t);
        }
      });
    }
    if (activeArtistType != null) this.activeArtistType.value = activeArtistType;
    if (activeSearchMediaTypes != null) {
      activeSearchMediaTypes.loop((t) {
        if (!this.activeSearchMediaTypes.contains(t)) {
          this.activeSearchMediaTypes.add(t);
        }
      });
    }
    if (albumIdentifiers != null) {
      albumIdentifiers.loop((t) {
        if (!this.albumIdentifiers.contains(t)) {
          this.albumIdentifiers.add(t);
        }
      });
    }

    if (borderRadiusMultiplier != null) this.borderRadiusMultiplier.value = borderRadiusMultiplier;
    if (fontScaleFactor != null) this.fontScaleFactor.value = fontScaleFactor;
    if (artworkCacheHeightMultiplier != null) this.artworkCacheHeightMultiplier.value = artworkCacheHeightMultiplier;
    if (trackThumbnailSizeinList != null) this.trackThumbnailSizeinList.value = trackThumbnailSizeinList;
    if (trackListTileHeight != null) this.trackListTileHeight.value = trackListTileHeight;

    if (albumThumbnailSizeinList != null) this.albumThumbnailSizeinList.value = albumThumbnailSizeinList;
    if (albumListTileHeight != null) this.albumListTileHeight.value = albumListTileHeight;

    if (useMediaStore != null) this.useMediaStore.value = useMediaStore;
    if (includeVideos != null) this.includeVideos.value = includeVideos;

    if (displayTrackNumberinAlbumPage != null) this.displayTrackNumberinAlbumPage.value = displayTrackNumberinAlbumPage;
    if (albumCardTopRightDate != null) this.albumCardTopRightDate.value = albumCardTopRightDate;
    if (forceSquaredTrackThumbnail != null) this.forceSquaredTrackThumbnail.value = forceSquaredTrackThumbnail;
    if (forceSquaredAlbumThumbnail != null) this.forceSquaredAlbumThumbnail.value = forceSquaredAlbumThumbnail;
    if (useAlbumStaggeredGridView != null) this.useAlbumStaggeredGridView.value = useAlbumStaggeredGridView;
    if (useSettingCollapsedTiles != null) this.useSettingCollapsedTiles.value = useSettingCollapsedTiles;
    if (enableBlurEffect != null) this.enableBlurEffect.value = enableBlurEffect;
    if (enableGlowEffect != null) this.enableGlowEffect.value = enableGlowEffect;
    if (enableGlowBehindVideo != null) this.enableGlowBehindVideo.value = enableGlowBehindVideo;
    if (hourFormat12 != null) this.hourFormat12.value = hourFormat12;
    if (dateTimeFormat != null) this.dateTimeFormat.value = dateTimeFormat;

    ///
    if (trackArtistsSeparators != null && !this.trackArtistsSeparators.contains(trackArtistsSeparators[0])) this.trackArtistsSeparators.addAll(trackArtistsSeparators);
    if (trackGenresSeparators != null && !this.trackGenresSeparators.contains(trackGenresSeparators[0])) this.trackGenresSeparators.addAll(trackGenresSeparators);
    if (trackArtistsSeparatorsBlacklist != null && !this.trackArtistsSeparatorsBlacklist.contains(trackArtistsSeparatorsBlacklist[0])) {
      this.trackArtistsSeparatorsBlacklist.addAll(trackArtistsSeparatorsBlacklist);
    }
    if (trackGenresSeparatorsBlacklist != null && !this.trackGenresSeparatorsBlacklist.contains(trackGenresSeparatorsBlacklist[0])) {
      this.trackGenresSeparatorsBlacklist.addAll(trackGenresSeparatorsBlacklist);
    }
    if (fileBrowserSort != null) this.fileBrowserSort.value = fileBrowserSort;
    if (fileBrowserSortReversed != null) this.fileBrowserSortReversed.value = fileBrowserSortReversed;
    if (tracksSortSearch != null) this.tracksSortSearch.value = tracksSortSearch;
    if (tracksSortSearchReversed != null) this.tracksSortSearchReversed.value = tracksSortSearchReversed;
    if (tracksSortSearchIsAuto != null) this.tracksSortSearchIsAuto.value = tracksSortSearchIsAuto;
    if (albumSort != null) this.albumSort.value = albumSort;
    if (albumSortReversed != null) this.albumSortReversed.value = albumSortReversed;
    if (artistSort != null) this.artistSort.value = artistSort;
    if (artistSortReversed != null) this.artistSortReversed.value = artistSortReversed;
    if (genreSort != null) this.genreSort.value = genreSort;
    if (genreSortReversed != null) this.genreSortReversed.value = genreSortReversed;
    if (playlistSort != null) this.playlistSort.value = playlistSort;
    if (playlistSortReversed != null) this.playlistSortReversed.value = playlistSortReversed;
    if (ytPlaylistSort != null) this.ytPlaylistSort.value = ytPlaylistSort;
    if (ytPlaylistSortReversed != null) this.ytPlaylistSortReversed.value = ytPlaylistSortReversed;
    if (onTrackSwipeLeft != null) this.onTrackSwipeLeft.value = onTrackSwipeLeft;
    if (onTrackSwipeRight != null) this.onTrackSwipeRight.value = onTrackSwipeRight;
    if (artworkTapAction != null) this.artworkTapAction.value = artworkTapAction;
    if (artworkLongPressAction != null) this.artworkLongPressAction.value = artworkLongPressAction;
    if (displayThirdRow != null) this.displayThirdRow.value = displayThirdRow;
    if (displayThirdItemInEachRow != null) this.displayThirdItemInEachRow.value = displayThirdItemInEachRow;
    if (trackTileSeparator != null) this.trackTileSeparator.value = trackTileSeparator;
    if (indexMinDurationInSec != null) this.indexMinDurationInSec.value = indexMinDurationInSec;
    if (indexMinFileSizeInB != null) this.indexMinFileSizeInB.value = indexMinFileSizeInB;
    if (trackSearchFilter != null) {
      trackSearchFilter.loop((f) {
        if (!this.trackSearchFilter.contains(f)) {
          this.trackSearchFilter.add(f);
        }
      });
    }
    if (ignoreCommonPrefixForTypes != null) {
      ignoreCommonPrefixForTypes.loop((f) {
        if (!this.ignoreCommonPrefixForTypes.contains(f)) {
          this.ignoreCommonPrefixForTypes.add(f);
        }
      });
    }
    if (commonPrefixes != null) {
      commonPrefixes.loop((f) {
        if (!this.commonPrefixes.contains(f)) {
          this.commonPrefixes.add(f);
        }
      });
    }
    if (playlistSearchFilter != null) {
      playlistSearchFilter.loop((f) {
        if (!this.playlistSearchFilter.contains(f)) {
          this.playlistSearchFilter.add(f);
        }
      });
    }
    if (directoriesToScan != null) {
      directoriesToScan.loop((d) {
        if (!this.directoriesToScan.contains(d)) {
          this.directoriesToScan.add(d);
        }
      });
    }
    if (directoriesToExclude != null) {
      directoriesToExclude.loop((d) {
        if (!this.directoriesToExclude.contains(d)) {
          this.directoriesToExclude.add(d);
        }
      });
    }
    if (preventDuplicatedTracks != null) this.preventDuplicatedTracks.value = preventDuplicatedTracks;
    if (respectNoMedia != null) this.respectNoMedia.value = respectNoMedia;
    if (defaultBackupLocation != null) this.defaultBackupLocation.value = defaultBackupLocation;
    if (autoBackupIntervalDays != null) this.autoBackupIntervalDays.value = autoBackupIntervalDays;
    if (defaultFolderStartupLocation != null) this.defaultFolderStartupLocation.value = defaultFolderStartupLocation;
    if (defaultFolderStartupLocationVideos != null) this.defaultFolderStartupLocationVideos.value = defaultFolderStartupLocationVideos;
    if (enableFoldersHierarchy != null) this.enableFoldersHierarchy.value = enableFoldersHierarchy;
    if (enableFoldersHierarchyVideos != null) this.enableFoldersHierarchyVideos.value = enableFoldersHierarchyVideos;
    if (displayArtistBeforeTitle != null) this.displayArtistBeforeTitle.value = displayArtistBeforeTitle;
    if (heatmapListensView != null) this.heatmapListensView.value = heatmapListensView;
    if (reverseListensView != null) this.reverseListensView.value = reverseListensView;
    if (backupItemslist != null) {
      this.backupItemslist.value ??= AppPathsBackupEnumCategories.everything;
      backupItemslist.loop((d) {
        if (!this.backupItemslist.value!.contains(d)) {
          this.backupItemslist.value!.add(d);
        }
      });
      this.backupItemslist.refresh();
    }
    if (youtubeVideoQualities != null) {
      youtubeVideoQualities.loop((q) {
        if (!this.youtubeVideoQualities.contains(q)) {
          this.youtubeVideoQualities.add(q);
        }
      });
    }
    if (enableVideoPlayback != null) this.enableVideoPlayback.value = enableVideoPlayback;
    if (enableLyrics != null) this.enableLyrics.value = enableLyrics;
    if (lyricsSource != null) this.lyricsSource.value = lyricsSource;
    if (videoPlaybackSource != null) this.videoPlaybackSource.value = videoPlaybackSource;
    if (animatingThumbnailScaleMultiplier != null) this.animatingThumbnailScaleMultiplier.value = animatingThumbnailScaleMultiplier;
    if (animatingThumbnailIntensity != null) this.animatingThumbnailIntensity.value = animatingThumbnailIntensity;
    if (animatingThumbnailIntensityLyrics != null) this.animatingThumbnailIntensityLyrics.value = animatingThumbnailIntensityLyrics;
    if (animatingThumbnailIntensityMinimized != null) this.animatingThumbnailIntensityMinimized.value = animatingThumbnailIntensityMinimized;
    if (animatingThumbnailInversed != null) this.animatingThumbnailInversed.value = animatingThumbnailInversed;
    if (enablePartyModeInMiniplayer != null) this.enablePartyModeInMiniplayer.value = enablePartyModeInMiniplayer;
    if (enablePartyModeColorSwap != null) this.enablePartyModeColorSwap.value = enablePartyModeColorSwap;
    if (enableMiniplayerParticles != null) this.enableMiniplayerParticles.value = enableMiniplayerParticles;
    if (enableMiniplayerParallaxEffect != null) this.enableMiniplayerParallaxEffect.value = enableMiniplayerParallaxEffect;
    if (forceMiniplayerTrackColor != null) this.forceMiniplayerTrackColor.value = forceMiniplayerTrackColor;
    if (isTrackPlayedSecondsCount != null) this.isTrackPlayedSecondsCount.value = isTrackPlayedSecondsCount;
    if (isTrackPlayedPercentageCount != null) this.isTrackPlayedPercentageCount.value = isTrackPlayedPercentageCount;
    if (displayFavouriteIconInListTile != null) this.displayFavouriteIconInListTile.value = displayFavouriteIconInListTile;
    if (gradientTiles != null) this.gradientTiles.value = gradientTiles;
    if (editTagsKeepFileDates != null) this.editTagsKeepFileDates.value = editTagsKeepFileDates;
    if (downloadFilesWriteUploadDate != null) this.downloadFilesWriteUploadDate.value = downloadFilesWriteUploadDate;
    if (downloadFilesKeepCachedVersions != null) this.downloadFilesKeepCachedVersions.value = downloadFilesKeepCachedVersions;
    if (downloadAddAudioToLocalLibrary != null) this.downloadAddAudioToLocalLibrary.value = downloadAddAudioToLocalLibrary;
    if (downloadAudioOnly != null) this.downloadAudioOnly.value = downloadAudioOnly;
    if (downloadOverrideOldFiles != null) this.downloadOverrideOldFiles.value = downloadOverrideOldFiles;
    if (enablePip != null) this.enablePip.value = enablePip;
    if (pickColorsFromDeviceWallpaper != null) this.pickColorsFromDeviceWallpaper.value = pickColorsFromDeviceWallpaper;
    if (waveformTotalBars != null) this.waveformTotalBars.value = waveformTotalBars;
    if (videosMaxCacheInMB != null) this.videosMaxCacheInMB.value = videosMaxCacheInMB;
    if (audiosMaxCacheInMB != null) this.audiosMaxCacheInMB.value = audiosMaxCacheInMB;
    if (imagesMaxCacheInMB != null) this.imagesMaxCacheInMB.value = imagesMaxCacheInMB;

    if (hideStatusBarInExpandedMiniplayer != null) this.hideStatusBarInExpandedMiniplayer.value = hideStatusBarInExpandedMiniplayer;

    if (displayFavouriteButtonInNotification != null) this.displayFavouriteButtonInNotification.value = displayFavouriteButtonInNotification;
    if (displayStopButtonInNotification != null) this.displayStopButtonInNotification.value = displayStopButtonInNotification;
    if (enableSearchCleanup != null) this.enableSearchCleanup.value = enableSearchCleanup;
    if (enableBottomNavBar != null) this.enableBottomNavBar.value = enableBottomNavBar;

    if (displayAudioInfoMiniplayer != null) this.displayAudioInfoMiniplayer.value = displayAudioInfoMiniplayer;
    if (showUnknownFieldsInTrackInfoDialog != null) this.showUnknownFieldsInTrackInfoDialog.value = showUnknownFieldsInTrackInfoDialog;
    if (extractFeatArtistFromTitle != null) this.extractFeatArtistFromTitle.value = extractFeatArtistFromTitle;
    if (groupArtworksByAlbum != null) this.groupArtworksByAlbum.value = groupArtworksByAlbum;
    if (uniqueArtworkHash != null) this.uniqueArtworkHash.value = uniqueArtworkHash;
    if (enableM3USync != null) this.enableM3USync.value = enableM3USync;
    if (enableM3USyncStartup != null) this.enableM3USyncStartup.value = enableM3USyncStartup;
    if (prioritizeEmbeddedLyrics != null) this.prioritizeEmbeddedLyrics.value = prioritizeEmbeddedLyrics;
    if (swipeableDrawer != null) this.swipeableDrawer.value = swipeableDrawer;
    if (dismissibleMiniplayer != null) this.dismissibleMiniplayer.value = dismissibleMiniplayer;
    if (enableClipboardMonitoring != null) this.enableClipboardMonitoring.value = enableClipboardMonitoring;
    if (artworkGestureDoubleTapLRC != null) this.artworkGestureDoubleTapLRC.value = artworkGestureDoubleTapLRC;
    if (previousButtonReplays != null) this.previousButtonReplays.value = previousButtonReplays;
    if (refreshOnStartup != null) this.refreshOnStartup.value = refreshOnStartup;
    if (alwaysExpandedSearchbar != null) this.alwaysExpandedSearchbar.value = alwaysExpandedSearchbar;
    if (mixedQueue != null) this.mixedQueue.value = mixedQueue;
    if (tagFieldsToEdit != null) {
      tagFieldsToEdit.loop((d) {
        if (!this.tagFieldsToEdit.contains(d)) {
          this.tagFieldsToEdit.add(d);
        }
      });
    }
    if (stretchLyricsDuration != null) this.stretchLyricsDuration.value = stretchLyricsDuration;
    if (playlistAddTracksAtBeginning != null) this.playlistAddTracksAtBeginning.value = playlistAddTracksAtBeginning;
    if (playlistAddTracksAtBeginningYT != null) this.playlistAddTracksAtBeginningYT.value = playlistAddTracksAtBeginningYT;
    if (wakelockMode != null) this.wakelockMode.value = wakelockMode;
    if (localVideoMatchingType != null) this.localVideoMatchingType.value = localVideoMatchingType;
    if (localVideoMatchingCheckSameDir != null) this.localVideoMatchingCheckSameDir.value = localVideoMatchingCheckSameDir;

    if (trackPlayMode != null) this.trackPlayMode.value = trackPlayMode;
    if (onNotificationTapAction != null) this.onNotificationTapAction.value = onNotificationTapAction;
    if (performanceMode != null) this.performanceMode.value = performanceMode;

    if (floatingActionButton != null) this.floatingActionButton.value = floatingActionButton;
    if (vibrationType != null) this.vibrationType.value = vibrationType;
    if (mostPlayedTimeRange != null) this.mostPlayedTimeRange.value = mostPlayedTimeRange;
    if (mostPlayedCustomDateRange != null) this.mostPlayedCustomDateRange.value = mostPlayedCustomDateRange;
    if (mostPlayedCustomisStartOfDay != null) this.mostPlayedCustomisStartOfDay.value = mostPlayedCustomisStartOfDay;
    if (ytMostPlayedTimeRange != null) this.ytMostPlayedTimeRange.value = ytMostPlayedTimeRange;
    if (ytMostPlayedCustomDateRange != null) this.ytMostPlayedCustomDateRange.value = ytMostPlayedCustomDateRange;
    if (ytMostPlayedCustomisStartOfDay != null) this.ytMostPlayedCustomisStartOfDay.value = ytMostPlayedCustomisStartOfDay;

    if (fontScaleLRC != null) this.fontScaleLRC = fontScaleLRC;
    if (fontScaleLRCFull != null) this.fontScaleLRCFull = fontScaleLRCFull;
    if (windowBounds != null) this.windowBounds = windowBounds;

    if (didSupportNamida != null) this.didSupportNamida = didSupportNamida;
    if (canAskForBatteryOptimizations != null) this.canAskForBatteryOptimizations = canAskForBatteryOptimizations;
    _writeToStorage();
  }

  void insertInList(
    int index, {
    LibraryTab? libraryTab1,
    String? youtubeVideoQualities1,
    TagField? tagFieldsToEdit1,
    HomePageItems? homePageItem1,
    LibraryImageSource? imageSourceAlbum1,
    LibraryImageSource? imageSourceArtist1,
  }) {
    if (libraryTab1 != null) libraryTabs.insert(index, libraryTab1);
    if (homePageItem1 != null) homePageItems.insert(index, homePageItem1);
    if (youtubeVideoQualities1 != null) youtubeVideoQualities.insertSafe(index, youtubeVideoQualities1);
    if (tagFieldsToEdit1 != null) tagFieldsToEdit.insertSafe(index, tagFieldsToEdit1);
    if (imageSourceAlbum1 != null) imageSourceAlbum.insertSafe(index, imageSourceAlbum1);
    if (imageSourceArtist1 != null) imageSourceArtist.insertSafe(index, imageSourceArtist1);

    _writeToStorage();
  }

  void removeFromList({
    String? trackArtistsSeparator,
    String? trackGenresSeparator,
    String? trackArtistsSeparatorsBlacklist1,
    String? trackGenresSeparatorsBlacklist1,
    TrackSearchFilter? trackSearchFilter1,
    List<TrackSearchFilter>? trackSearchFilterAll,
    TrackSearchFilter? ignoreCommonPrefixForTypes1,
    List<TrackSearchFilter>? ignoreCommonPrefixForTypesAll,
    String? playlistSearchFilter1,
    List<String>? playlistSearchFilterAll,
    String? directoriesToScan1,
    List<String>? directoriesToScanAll,
    String? directoriesToExclude1,
    List<String>? directoriesToExcludeAll,
    LibraryTab? libraryTab1,
    List<LibraryTab>? libraryTabsAll,
    HomePageItems? homePageItem1,
    List<HomePageItems>? homePageItemsAll,
    MediaType? activeSearchMediaTypes1,
    AlbumIdentifier? albumIdentifiers1,
    List<AlbumIdentifier>? albumIdentifiersAll,
    AppPathsBackupEnum? backupItemslist1,
    List<AppPathsBackupEnum>? backupItemslistAll,
    String? youtubeVideoQualities1,
    List<AppPathsBackupEnum>? youtubeVideoQualitiesAll,
    TagField? tagFieldsToEdit1,
    List<TagField>? tagFieldsToEditAll,
    LibraryImageSource? imageSourceAlbum1,
    LibraryImageSource? imageSourceArtist1,
  }) {
    if (trackArtistsSeparator != null) trackArtistsSeparators.remove(trackArtistsSeparator);
    if (trackGenresSeparator != null) trackGenresSeparators.remove(trackGenresSeparator);
    if (trackArtistsSeparatorsBlacklist1 != null) trackArtistsSeparatorsBlacklist.remove(trackArtistsSeparatorsBlacklist1);
    if (trackGenresSeparatorsBlacklist1 != null) trackGenresSeparatorsBlacklist.remove(trackGenresSeparatorsBlacklist1);
    if (trackSearchFilter1 != null) trackSearchFilter.remove(trackSearchFilter1);
    if (trackSearchFilterAll != null) trackSearchFilterAll.loop((f) => trackSearchFilter.remove(f));
    if (ignoreCommonPrefixForTypes1 != null) ignoreCommonPrefixForTypes.remove(ignoreCommonPrefixForTypes1);
    if (ignoreCommonPrefixForTypesAll != null) ignoreCommonPrefixForTypesAll.loop((f) => ignoreCommonPrefixForTypes.remove(f));
    if (playlistSearchFilter1 != null) playlistSearchFilter.remove(playlistSearchFilter1);
    if (playlistSearchFilterAll != null) {
      playlistSearchFilterAll.loop((f) => playlistSearchFilter.remove(f));
    }
    if (directoriesToScan1 != null) directoriesToScan.remove(directoriesToScan1);
    if (directoriesToScanAll != null) directoriesToScanAll.loop((f) => directoriesToScan.remove(f));
    if (directoriesToExclude1 != null) directoriesToExclude.remove(directoriesToExclude1);
    if (directoriesToExcludeAll != null) directoriesToExcludeAll.loop((f) => directoriesToExclude.remove(f));
    if (libraryTab1 != null) libraryTabs.remove(libraryTab1);
    if (libraryTabsAll != null) libraryTabsAll.loop((t) => libraryTabs.remove(t));
    if (homePageItem1 != null) homePageItems.remove(homePageItem1);
    if (homePageItemsAll != null) homePageItemsAll.loop((t) => homePageItems.remove(t));
    if (activeSearchMediaTypes1 != null) activeSearchMediaTypes.remove(activeSearchMediaTypes1);
    if (albumIdentifiers1 != null) albumIdentifiers.remove(albumIdentifiers1);
    if (albumIdentifiersAll != null) albumIdentifiersAll.loop((t) => albumIdentifiers.remove(t));
    if (backupItemslist1 != null) {
      backupItemslist.value?.remove(backupItemslist1);
      backupItemslist.refresh();
    }
    if (backupItemslistAll != null) {
      backupItemslistAll.loop((t) => backupItemslist.value?.remove(t));
      backupItemslist.refresh();
    }
    if (youtubeVideoQualities1 != null) youtubeVideoQualities.remove(youtubeVideoQualities1);
    if (youtubeVideoQualitiesAll != null) youtubeVideoQualitiesAll.loop((t) => youtubeVideoQualities.remove(t));
    if (tagFieldsToEdit1 != null) tagFieldsToEdit.remove(tagFieldsToEdit1);
    if (tagFieldsToEditAll != null) tagFieldsToEditAll.loop((t) => tagFieldsToEdit.remove(t));

    if (imageSourceAlbum1 != null) imageSourceAlbum.remove(imageSourceAlbum1);
    if (imageSourceArtist1 != null) imageSourceArtist.remove(imageSourceArtist1);

    _writeToStorage();
  }

  void updateTrackItemList(TrackTilePosition p, TrackTileItem i) {
    trackItem[p] = i;
    _writeToStorage();
  }

  void updateQueueInsertion(QueueInsertionType type, QueueInsertion qi) {
    queueInsertion[type] = qi;
    _writeToStorage();
  }

  void updateMediaItemsTrackSortingAll(MediaType media, List<SortType>? allsorts, bool? isReverse) {
    if (allsorts == null && isReverse == null) return;
    if (allsorts != null) mediaItemsTrackSorting[media] = allsorts;
    if (isReverse != null) mediaItemsTrackSortingReverse[media] = isReverse;
    _writeToStorage();
  }

  void updateMediaItemsTrackSorting(MediaType media, List<SortType> allsorts) {
    mediaItemsTrackSorting[media] = allsorts;
    _writeToStorage();
  }

  void updateMediaItemsTrackSortingReverse(MediaType media, bool isReverse) {
    mediaItemsTrackSortingReverse[media] = isReverse;
    _writeToStorage();
  }

  void updateMediaGridCounts(LibraryTab tab, CountPerRow? countPerRow) {
    mediaGridCounts[tab] = countPerRow;
    _writeToStorage();
  }

  void updateActiveAlbumTypes(AlbumType type, bool active) {
    activeAlbumTypes[type] = active;
    _writeToStorage();
  }

  @override
  String get filePath => AppPaths.SETTINGS;
}

extension _ListieMapper on Iterable<dynamic> {
  List<T> toListy<T>() => whereType<T>().toList();
}

extension CountPerRowMapUtils on Map<LibraryTab, CountPerRow?> {
  CountPerRow get(LibraryTab tab) {
    final val = this[tab];
    if (val == null || val.rawValue < 1) return CountPerRow.autoForTab(tab);
    return val;
  }
}
