import 'dart:io';

import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:history_manager/history_manager.dart';

import 'package:namida/class/lang.dart';
import 'package:namida/class/queue_insertion.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';

SettingsController get settings => SettingsController.inst;

class SettingsController {
  static SettingsController get inst => _instance;
  static final SettingsController _instance = SettingsController._internal();
  SettingsController._internal();

  final Rx<NamidaLanguage> selectedLanguage = kDefaultLang.obs;
  final Rx<ThemeMode> themeMode = ThemeMode.system.obs;
  final RxBool pitchBlack = false.obs;
  final RxBool autoColor = true.obs;
  final RxInt staticColor = kMainColorLight.value.obs;
  final RxInt staticColorDark = kMainColorDark.value.obs;
  final Rx<LibraryTab> selectedLibraryTab = LibraryTab.tracks.obs;
  final Rx<LibraryTab> staticLibraryTab = LibraryTab.tracks.obs;
  final RxBool autoLibraryTab = true.obs;
  final RxList<LibraryTab> libraryTabs = [
    LibraryTab.home,
    LibraryTab.tracks,
    LibraryTab.playlists,
    LibraryTab.folders,
    LibraryTab.youtube,
  ].obs;
  final RxInt searchResultsPlayMode = 1.obs;
  final RxDouble borderRadiusMultiplier = 1.0.obs;
  final RxDouble fontScaleFactor = 0.9.obs;
  final RxDouble artworkCacheHeightMultiplier = 0.8.obs;
  final RxDouble trackThumbnailSizeinList = 70.0.obs;
  final RxDouble trackListTileHeight = 70.0.obs;
  final RxDouble albumThumbnailSizeinList = 90.0.obs;
  final RxDouble albumListTileHeight = 90.0.obs;
  final RxDouble nowPlayingImageContainerHeight = 400.0.obs;

  final RxBool enableVolumeFadeOnPlayPause = true.obs;
  final RxBool displayTrackNumberinAlbumPage = true.obs;
  final RxBool albumCardTopRightDate = true.obs;
  final RxBool forceSquaredTrackThumbnail = false.obs;
  final RxBool forceSquaredAlbumThumbnail = false.obs;
  final RxBool useAlbumStaggeredGridView = false.obs;
  final RxBool useSettingCollapsedTiles = true.obs;
  final RxInt albumGridCount = 2.obs;
  final RxInt artistGridCount = 3.obs;
  final RxInt genreGridCount = 2.obs;
  final RxInt playlistGridCount = 1.obs;
  final RxBool enableBlurEffect = false.obs;
  final RxBool enableGlowEffect = false.obs;
  final RxBool hourFormat12 = true.obs;
  final RxString dateTimeFormat = 'MMM yyyy'.obs;
  final RxList<String> trackArtistsSeparators = <String>['&', ',', ';', '//', ' ft. ', ' x '].obs;
  final RxList<String> trackGenresSeparators = <String>['&', ',', ';', '//', ' x '].obs;
  final RxList<String> trackArtistsSeparatorsBlacklist = <String>[].obs;
  final RxList<String> trackGenresSeparatorsBlacklist = <String>[].obs;
  final Rx<SortType> tracksSort = SortType.title.obs;
  final RxBool tracksSortReversed = false.obs;
  final Rx<GroupSortType> albumSort = GroupSortType.album.obs;
  final RxBool albumSortReversed = false.obs;
  final Rx<GroupSortType> artistSort = GroupSortType.artistsList.obs;
  final RxBool artistSortReversed = false.obs;
  final Rx<GroupSortType> genreSort = GroupSortType.genresList.obs;
  final RxBool genreSortReversed = false.obs;
  final Rx<GroupSortType> playlistSort = GroupSortType.dateModified.obs;
  final RxBool playlistSortReversed = false.obs;
  final RxInt indexMinDurationInSec = 5.obs;
  final RxInt indexMinFileSizeInB = (100 * 1024).obs;
  final RxList<String> trackSearchFilter = ['title', 'artist', 'album'].obs;
  final RxList<String> playlistSearchFilter = ['name', 'creationDate', 'modifiedDate', 'moods', 'comment'].obs;
  final RxList<String> directoriesToScan = kDirectoriesPaths.toList().obs;
  final RxList<String> directoriesToExclude = <String>[].obs;
  final RxBool preventDuplicatedTracks = false.obs;
  final RxBool respectNoMedia = false.obs;
  final RxString defaultBackupLocation = AppDirs.BACKUPS.obs;
  final RxString defaultFolderStartupLocation = kStoragePaths.first.obs;
  final RxBool enableFoldersHierarchy = true.obs;
  final RxBool displayArtistBeforeTitle = true.obs;
  final RxList<String> backupItemslist = [
    AppPaths.TRACKS,
    AppPaths.TRACKS_STATS,
    AppPaths.TOTAL_LISTEN_TIME,
    AppPaths.VIDEOS_CACHE,
    AppPaths.VIDEOS_LOCAL,
    AppPaths.SETTINGS,
    AppDirs.PALETTES,
    AppDirs.LYRICS,
    AppDirs.PLAYLISTS,
    AppDirs.HISTORY_PLAYLIST,
    AppPaths.FAVOURITES_PLAYLIST,
    AppDirs.QUEUES,
    AppPaths.LATEST_QUEUE,
    AppDirs.YT_PLAYLISTS,
    AppDirs.YT_HISTORY_PLAYLIST,
    AppPaths.YT_FAVOURITES_PLAYLIST,
  ].obs;
  final RxBool enableVideoPlayback = true.obs;
  final RxBool enableLyrics = false.obs;
  final Rx<VideoPlaybackSource> videoPlaybackSource = VideoPlaybackSource.auto.obs;
  final RxList<String> youtubeVideoQualities = ['480p', '360p', '240p', '144p'].obs;
  final RxInt animatingThumbnailIntensity = 25.obs;
  final RxBool animatingThumbnailInversed = false.obs;
  final RxBool enablePartyModeInMiniplayer = false.obs;
  final RxBool enablePartyModeColorSwap = true.obs;
  final RxBool enableMiniplayerParticles = true.obs;
  final RxBool enableMiniplayerParallaxEffect = true.obs;
  final RxBool forceMiniplayerTrackColor = false.obs;
  final RxInt isTrackPlayedSecondsCount = 40.obs;
  final RxInt isTrackPlayedPercentageCount = 40.obs;
  final RxInt waveformTotalBars = 140.obs;
  final RxInt videosMaxCacheInMB = (2 * 1024).obs; // 2GB
  final RxInt imagesMaxCacheInMB = (8 * 32).obs; // 256 MB
  final RxInt ytMiniplayerDimAfterSeconds = 15.obs;
  final RxDouble ytMiniplayerDimOpacity = 0.5.obs;
  final RxDouble playerVolume = 1.0.obs;
  final RxDouble playerSpeed = 1.0.obs;
  final RxDouble playerPitch = 1.0.obs;
  final RxInt seekDurationInSeconds = 5.obs;
  final RxInt seekDurationInPercentage = 2.obs;
  final RxBool isSeekDurationPercentage = false.obs;
  final RxInt playerPlayFadeDurInMilli = 300.obs;
  final RxInt playerPauseFadeDurInMilli = 300.obs;
  final RxInt minTrackDurationToRestoreLastPosInMinutes = 5.obs;
  final RxString lastPlayedTrackPath = ''.obs;
  final RxBool displayFavouriteButtonInNotification = false.obs;
  final RxBool enableSearchCleanup = true.obs;
  final RxBool enableBottomNavBar = true.obs;
  final RxBool ytPreferNewComments = false.obs;
  final RxBool ytAutoExtractVideoTagsFromInfo = true.obs;
  final RxBool playerPlayOnNextPrev = true.obs;
  final RxBool playerSkipSilenceEnabled = false.obs;
  final RxBool playerShuffleAllTracks = false.obs;
  final RxBool playerPauseOnVolume0 = true.obs;
  final RxBool playerResumeAfterOnVolume0Pause = true.obs;
  final RxBool playerResumeAfterWasInterrupted = true.obs;
  final RxBool jumpToFirstTrackAfterFinishingQueue = true.obs;
  final RxBool displayAudioInfoMiniplayer = false.obs;
  final RxBool showUnknownFieldsInTrackInfoDialog = true.obs;
  final RxBool extractFeatArtistFromTitle = true.obs;
  final RxBool groupArtworksByAlbum = false.obs;
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
    TagField.lyrics,
  ].obs;

  final Rx<WakelockMode> wakelockMode = WakelockMode.expandedAndVideo.obs;

  final Rx<LocalVideoMatchingType> localVideoMatchingType = LocalVideoMatchingType.auto.obs;
  final RxBool localVideoMatchingCheckSameDir = false.obs;

  final Rx<RepeatMode> playerRepeatMode = RepeatMode.none.obs;

  final Rx<TrackPlayMode> trackPlayMode = TrackPlayMode.searchResults.obs;

  final Rx<MostPlayedTimeRange> mostPlayedTimeRange = MostPlayedTimeRange.allTime.obs;
  final mostPlayedCustomDateRange = DateRange.dummy().obs;
  final mostPlayedCustomisStartOfDay = true.obs;

  /// Track Items
  final RxBool displayThirdRow = true.obs;
  final RxBool displayThirdItemInEachRow = false.obs;
  final RxString trackTileSeparator = '•'.obs;
  final RxBool displayFavouriteIconInListTile = true.obs;
  final RxBool editTagsKeepFileDates = true.obs;
  final RxBool downloadFilesWriteUploadDate = true.obs;
  final RxBool downloadFilesKeepCachedVersions = true.obs;
  final RxBool enablePip = true.obs;
  final RxBool playerInfiniyQueueOnNextPrevious = true.obs;
  final RxBool displayRemainingDurInsteadOfTotal = false.obs;
  final RxBool pickColorsFromDeviceWallpaper = false.obs;
  final onNotificationTapAction = NotificationTapAction.openApp.obs;
  final onYoutubeLinkOpen = OnYoutubeLinkOpenAction.alwaysAsk.obs;
  final performanceMode = PerformanceMode.balanced.obs;

  final RxMap<TrackTilePosition, TrackTileItem> trackItem = {
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

  final playerOnInterrupted = <InterruptionType, InterruptionAction>{
    InterruptionType.shouldPause: InterruptionAction.pause,
    InterruptionType.shouldDuck: InterruptionAction.duckAudio,
    InterruptionType.unknown: InterruptionAction.pause,
  }.obs;

  final queueInsertion = <QueueInsertionType, QueueInsertion>{
    QueueInsertionType.moreAlbum: const QueueInsertion(numberOfTracks: 10, insertNext: false, sortBy: InsertionSortingType.random),
    QueueInsertionType.moreArtist: const QueueInsertion(numberOfTracks: 10, insertNext: false, sortBy: InsertionSortingType.random),
    QueueInsertionType.moreFolder: const QueueInsertion(numberOfTracks: 10, insertNext: false, sortBy: InsertionSortingType.random),
    QueueInsertionType.random: const QueueInsertion(numberOfTracks: 10, insertNext: false, sortBy: InsertionSortingType.random),
    QueueInsertionType.listenTimeRange: const QueueInsertion(numberOfTracks: 0, insertNext: true, sortBy: InsertionSortingType.listenCount),
    QueueInsertionType.mood: const QueueInsertion(numberOfTracks: 20, insertNext: true, sortBy: InsertionSortingType.listenCount),
    QueueInsertionType.rating: const QueueInsertion(numberOfTracks: 20, insertNext: false, sortBy: InsertionSortingType.rating),
    QueueInsertionType.sameReleaseDate: const QueueInsertion(numberOfTracks: 30, insertNext: true, sortBy: InsertionSortingType.listenCount),
    QueueInsertionType.algorithm: const QueueInsertion(numberOfTracks: 20, insertNext: true, sortBy: InsertionSortingType.listenCount),
  }.obs;

  final homePageItems = <HomePageItems>[
    HomePageItems.mixes,
    HomePageItems.recentListens,
    HomePageItems.topRecentListens,
    HomePageItems.lostMemories,
    HomePageItems.recentlyAdded,
    HomePageItems.recentAlbums,
    HomePageItems.recentArtists,
  ].obs;

  final activeSearchMediaTypes = <MediaType>[
    MediaType.track,
    MediaType.album,
    MediaType.artist,
  ].obs;

  final albumIdentifiers = <AlbumIdentifier>[
    AlbumIdentifier.albumName,
  ].obs;

  bool didSupportNamida = false;

  Future<void> prepareSettingsFile() async {
    final file = await File(AppPaths.SETTINGS).create(recursive: true);
    try {
      final json = await file.readAsJson();
      if (json == null) return;

      /// Assigning Values
      selectedLanguage.value = NamidaLanguage.fromJson(json['selectedLanguage']);
      themeMode.value = ThemeMode.values.getEnum(json['themeMode']) ?? themeMode.value;
      pitchBlack.value = json['pitchBlack'] ?? pitchBlack.value;
      autoColor.value = json['autoColor'] ?? autoColor.value;
      staticColor.value = json['staticColor'] ?? staticColor.value;
      staticColorDark.value = json['staticColorDark'] ?? staticColorDark.value;
      selectedLibraryTab.value = json['autoLibraryTab'] ?? autoLibraryTab.value
          ? LibraryTab.values.getEnum(json['selectedLibraryTab']) ?? selectedLibraryTab.value
          : LibraryTab.values.getEnum(json['staticLibraryTab']) ?? staticLibraryTab.value;
      staticLibraryTab.value = LibraryTab.values.getEnum(json['staticLibraryTab']) ?? staticLibraryTab.value;
      autoLibraryTab.value = json['autoLibraryTab'] ?? autoLibraryTab.value;
      final libraryListFromStorage = List<String>.from(json['libraryTabs'] ?? []);
      libraryTabs.value = libraryListFromStorage.isNotEmpty ? List<LibraryTab>.from(libraryListFromStorage.map((e) => LibraryTab.values.getEnum(e))) : libraryTabs.toList();

      final homePageItemsFromStorage = List<String>.from(json['homePageItems'] ?? []);
      homePageItems.value =
          homePageItemsFromStorage.isNotEmpty ? List<HomePageItems>.from(homePageItemsFromStorage.map((e) => HomePageItems.values.getEnum(e))) : homePageItems.toList();

      final activeSearchMediaTypesFromStorage = List<String>.from(json['activeSearchMediaTypes'] ?? []);
      activeSearchMediaTypes.value = activeSearchMediaTypesFromStorage.isNotEmpty
          ? List<MediaType>.from(activeSearchMediaTypesFromStorage.map((e) => MediaType.values.getEnum(e)))
          : activeSearchMediaTypes.toList();

      final albumIdentifiersFromStorage = List<String>.from(json['albumIdentifiers'] ?? []);
      albumIdentifiers.value = albumIdentifiersFromStorage.isNotEmpty
          ? List<AlbumIdentifier>.from(albumIdentifiersFromStorage.map((e) => AlbumIdentifier.values.getEnum(e)))
          : albumIdentifiers.toList();

      searchResultsPlayMode.value = json['searchResultsPlayMode'] ?? searchResultsPlayMode.value;
      borderRadiusMultiplier.value = json['borderRadiusMultiplier'] ?? borderRadiusMultiplier.value;
      fontScaleFactor.value = json['fontScaleFactor'] ?? fontScaleFactor.value;
      artworkCacheHeightMultiplier.value = json['artworkCacheHeightMultiplier'] ?? artworkCacheHeightMultiplier.value;
      trackThumbnailSizeinList.value = json['trackThumbnailSizeinList'] ?? trackThumbnailSizeinList.value;
      trackListTileHeight.value = json['trackListTileHeight'] ?? trackListTileHeight.value;
      albumThumbnailSizeinList.value = json['albumThumbnailSizeinList'] ?? albumThumbnailSizeinList.value;
      albumListTileHeight.value = json['albumListTileHeight'] ?? albumListTileHeight.value;
      nowPlayingImageContainerHeight.value = json['nowPlayingImageContainerHeight'] ?? nowPlayingImageContainerHeight.value;

      enableVolumeFadeOnPlayPause.value = json['enableVolumeFadeOnPlayPause'] ?? enableVolumeFadeOnPlayPause.value;
      displayTrackNumberinAlbumPage.value = json['displayTrackNumberinAlbumPage'] ?? displayTrackNumberinAlbumPage.value;
      albumCardTopRightDate.value = json['albumCardTopRightDate'] ?? albumCardTopRightDate.value;
      forceSquaredTrackThumbnail.value = json['forceSquaredTrackThumbnail'] ?? forceSquaredTrackThumbnail.value;
      forceSquaredAlbumThumbnail.value = json['forceSquaredAlbumThumbnail'] ?? forceSquaredAlbumThumbnail.value;
      useAlbumStaggeredGridView.value = json['useAlbumStaggeredGridView'] ?? useAlbumStaggeredGridView.value;
      useSettingCollapsedTiles.value = json['useSettingCollapsedTiles'] ?? useSettingCollapsedTiles.value;
      albumGridCount.value = json['albumGridCount'] ?? albumGridCount.value;
      artistGridCount.value = json['artistGridCount'] ?? artistGridCount.value;
      genreGridCount.value = json['genreGridCount'] ?? genreGridCount.value;
      playlistGridCount.value = json['playlistGridCount'] ?? playlistGridCount.value;
      enableBlurEffect.value = json['enableBlurEffect'] ?? enableBlurEffect.value;
      enableGlowEffect.value = json['enableGlowEffect'] ?? enableGlowEffect.value;
      hourFormat12.value = json['hourFormat12'] ?? hourFormat12.value;
      dateTimeFormat.value = json['dateTimeFormat'] ?? dateTimeFormat.value;

      trackArtistsSeparators.value = List<String>.from(json['trackArtistsSeparators'] ?? trackArtistsSeparators);
      trackGenresSeparators.value = List<String>.from(json['trackGenresSeparators'] ?? trackGenresSeparators);
      trackArtistsSeparatorsBlacklist.value = List<String>.from(json['trackArtistsSeparatorsBlacklist'] ?? trackArtistsSeparatorsBlacklist);
      trackGenresSeparatorsBlacklist.value = List<String>.from(json['trackGenresSeparatorsBlacklist'] ?? trackGenresSeparatorsBlacklist);
      tracksSort.value = SortType.values.getEnum(json['tracksSort']) ?? tracksSort.value;
      tracksSortReversed.value = json['tracksSortReversed'] ?? tracksSortReversed.value;
      albumSort.value = GroupSortType.values.getEnum(json['albumSort']) ?? albumSort.value;
      albumSortReversed.value = json['albumSortReversed'] ?? albumSortReversed.value;
      artistSort.value = GroupSortType.values.getEnum(json['artistSort']) ?? artistSort.value;
      artistSortReversed.value = json['artistSortReversed'] ?? artistSortReversed.value;
      genreSort.value = GroupSortType.values.getEnum(json['genreSort']) ?? genreSort.value;
      genreSortReversed.value = json['genreSortReversed'] ?? genreSortReversed.value;
      playlistSort.value = GroupSortType.values.getEnum(json['playlistSort']) ?? playlistSort.value;
      playlistSortReversed.value = json['playlistSortReversed'] ?? playlistSortReversed.value;
      indexMinDurationInSec.value = json['indexMinDurationInSec'] ?? indexMinDurationInSec.value;
      indexMinFileSizeInB.value = json['indexMinFileSizeInB'] ?? indexMinFileSizeInB.value;

      trackSearchFilter.value = List<String>.from(json['trackSearchFilter'] ?? trackSearchFilter);
      playlistSearchFilter.value = List<String>.from(json['playlistSearchFilter'] ?? playlistSearchFilter);
      directoriesToScan.value = List<String>.from(json['directoriesToScan'] ?? directoriesToScan);
      directoriesToExclude.value = List<String>.from(json['directoriesToExclude'] ?? directoriesToExclude);
      preventDuplicatedTracks.value = json['preventDuplicatedTracks'] ?? preventDuplicatedTracks.value;
      respectNoMedia.value = json['respectNoMedia'] ?? respectNoMedia.value;
      defaultBackupLocation.value = json['defaultBackupLocation'] ?? defaultBackupLocation.value;
      defaultFolderStartupLocation.value = json['defaultFolderStartupLocation'] ?? defaultFolderStartupLocation.value;
      enableFoldersHierarchy.value = json['enableFoldersHierarchy'] ?? enableFoldersHierarchy.value;
      displayArtistBeforeTitle.value = json['displayArtistBeforeTitle'] ?? displayArtistBeforeTitle.value;
      backupItemslist.value = List<String>.from(json['backupItemslist'] ?? backupItemslist);
      enableVideoPlayback.value = json['enableVideoPlayback'] ?? enableVideoPlayback.value;
      enableLyrics.value = json['enableLyrics'] ?? enableLyrics.value;
      videoPlaybackSource.value = VideoPlaybackSource.values.getEnum(json['VideoPlaybackSource']) ?? videoPlaybackSource.value;
      youtubeVideoQualities.value = List<String>.from(json['youtubeVideoQualities'] ?? youtubeVideoQualities);

      animatingThumbnailIntensity.value = json['animatingThumbnailIntensity'] ?? animatingThumbnailIntensity.value;
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
      imagesMaxCacheInMB.value = json['imagesMaxCacheInMB'] ?? imagesMaxCacheInMB.value;
      ytMiniplayerDimAfterSeconds.value = json['ytMiniplayerDimAfterSeconds'] ?? ytMiniplayerDimAfterSeconds.value;
      ytMiniplayerDimOpacity.value = json['ytMiniplayerDimOpacity'] ?? ytMiniplayerDimOpacity.value;
      playerVolume.value = json['playerVolume'] ?? playerVolume.value;
      playerSpeed.value = json['playerSpeed'] ?? playerSpeed.value;
      playerPitch.value = json['playerPitch'] ?? playerPitch.value;
      seekDurationInSeconds.value = json['seekDurationInSeconds'] ?? seekDurationInSeconds.value;
      seekDurationInPercentage.value = json['seekDurationInPercentage'] ?? seekDurationInPercentage.value;
      isSeekDurationPercentage.value = json['isSeekDurationPercentage'] ?? isSeekDurationPercentage.value;
      playerPlayFadeDurInMilli.value = json['playerPlayFadeDurInMilli'] ?? playerPlayFadeDurInMilli.value;
      playerPauseFadeDurInMilli.value = json['playerPauseFadeDurInMilli'] as int? ?? playerPauseFadeDurInMilli.value;
      minTrackDurationToRestoreLastPosInMinutes.value = json['minTrackDurationToRestoreLastPosInMinutes'] ?? minTrackDurationToRestoreLastPosInMinutes.value;
      lastPlayedTrackPath.value = json['lastPlayedTrackPath'] ?? lastPlayedTrackPath.value;
      displayFavouriteButtonInNotification.value = json['displayFavouriteButtonInNotification'] ?? displayFavouriteButtonInNotification.value;
      enableSearchCleanup.value = json['enableSearchCleanup'] ?? enableSearchCleanup.value;
      enableBottomNavBar.value = json['enableBottomNavBar'] ?? enableBottomNavBar.value;
      ytPreferNewComments.value = json['ytPreferNewComments'] ?? ytPreferNewComments.value;
      ytAutoExtractVideoTagsFromInfo.value = json['ytAutoExtractVideoTagsFromInfo'] ?? ytAutoExtractVideoTagsFromInfo.value;
      playerPlayOnNextPrev.value = json['playerPlayOnNextPrev'] ?? playerPlayOnNextPrev.value;
      playerSkipSilenceEnabled.value = json['playerSkipSilenceEnabled'] ?? playerSkipSilenceEnabled.value;
      playerShuffleAllTracks.value = json['playerShuffleAllTracks'] ?? playerShuffleAllTracks.value;
      playerPauseOnVolume0.value = json['playerPauseOnVolume0'] ?? playerPauseOnVolume0.value;
      playerResumeAfterOnVolume0Pause.value = json['playerResumeAfterOnVolume0Pause'] ?? playerResumeAfterOnVolume0Pause.value;
      playerResumeAfterWasInterrupted.value = json['playerResumeAfterWasInterrupted'] ?? playerResumeAfterWasInterrupted.value;
      jumpToFirstTrackAfterFinishingQueue.value = json['jumpToFirstTrackAfterFinishingQueue'] ?? jumpToFirstTrackAfterFinishingQueue.value;
      displayAudioInfoMiniplayer.value = json['displayAudioInfoMiniplayer'] ?? displayAudioInfoMiniplayer.value;
      showUnknownFieldsInTrackInfoDialog.value = json['showUnknownFieldsInTrackInfoDialog'] ?? showUnknownFieldsInTrackInfoDialog.value;
      extractFeatArtistFromTitle.value = json['extractFeatArtistFromTitle'] ?? extractFeatArtistFromTitle.value;
      groupArtworksByAlbum.value = json['groupArtworksByAlbum'] ?? groupArtworksByAlbum.value;

      final listFromStorage = List<String>.from(json['tagFieldsToEdit'] ?? []);
      tagFieldsToEdit.value = listFromStorage.isNotEmpty ? List<TagField>.from(listFromStorage.map((e) => TagField.values.getEnum(e))) : tagFieldsToEdit;

      wakelockMode.value = WakelockMode.values.getEnum(json['wakelockMode']) ?? wakelockMode.value;

      localVideoMatchingType.value = LocalVideoMatchingType.values.getEnum(json['localVideoMatchingType']) ?? localVideoMatchingType.value;
      localVideoMatchingCheckSameDir.value = json['localVideoMatchingCheckSameDir'] ?? localVideoMatchingCheckSameDir.value;

      playerRepeatMode.value = RepeatMode.values.getEnum(json['playerRepeatMode']) ?? playerRepeatMode.value;
      trackPlayMode.value = TrackPlayMode.values.getEnum(json['trackPlayMode']) ?? trackPlayMode.value;

      mostPlayedTimeRange.value = MostPlayedTimeRange.values.getEnum(json['mostPlayedTimeRange']) ?? mostPlayedTimeRange.value;
      mostPlayedCustomDateRange.value = json['mostPlayedCustomDateRange'] != null ? DateRange.fromJson(json['mostPlayedCustomDateRange']) : mostPlayedCustomDateRange.value;
      mostPlayedCustomisStartOfDay.value = json['mostPlayedCustomisStartOfDay'] ?? mostPlayedCustomisStartOfDay.value;

      /// Track Items
      displayThirdRow.value = json['displayThirdRow'] ?? displayThirdRow.value;
      displayThirdItemInEachRow.value = json['displayThirdItemInEachRow'] ?? displayThirdItemInEachRow.value;
      trackTileSeparator.value = json['trackTileSeparator'] ?? trackTileSeparator.value;
      displayFavouriteIconInListTile.value = json['displayFavouriteIconInListTile'] ?? displayFavouriteIconInListTile.value;
      editTagsKeepFileDates.value = json['editTagsKeepFileDates'] ?? editTagsKeepFileDates.value;
      downloadFilesWriteUploadDate.value = json['downloadFilesWriteUploadDate'] ?? downloadFilesWriteUploadDate.value;
      downloadFilesKeepCachedVersions.value = json['downloadFilesKeepCachedVersions'] ?? downloadFilesKeepCachedVersions.value;
      enablePip.value = json['enablePip'] ?? enablePip.value;
      playerInfiniyQueueOnNextPrevious.value = json['playerInfiniyQueueOnNextPrevious'] ?? playerInfiniyQueueOnNextPrevious.value;
      displayRemainingDurInsteadOfTotal.value = json['displayRemainingDurInsteadOfTotal'] ?? displayRemainingDurInsteadOfTotal.value;
      pickColorsFromDeviceWallpaper.value = json['pickColorsFromDeviceWallpaper'] ?? pickColorsFromDeviceWallpaper.value;
      onNotificationTapAction.value = NotificationTapAction.values.getEnum(json['onNotificationTapAction']) ?? onNotificationTapAction.value;
      onYoutubeLinkOpen.value = OnYoutubeLinkOpenAction.values.getEnum(json['onYoutubeLinkOpen']) ?? onYoutubeLinkOpen.value;
      performanceMode.value = PerformanceMode.values.getEnum(json['performanceMode']) ?? performanceMode.value;

      trackItem.value = _getEnumMap(
            json['trackItem'],
            TrackTilePosition.values,
            TrackTilePosition.rightItem3,
            TrackTileItem.values,
            TrackTileItem.none,
          ) ??
          trackItem.map((key, value) => MapEntry(key, value));

      playerOnInterrupted.value = _getEnumMap(
            json['playerOnInterrupted'],
            InterruptionType.values,
            InterruptionType.unknown,
            InterruptionAction.values,
            InterruptionAction.doNothing,
          ) ??
          playerOnInterrupted.map((key, value) => MapEntry(key, value));

      queueInsertion.value = ((json["queueInsertion"] as Map?)?.map(
            (key, value) => MapEntry(QueueInsertionType.values.getEnum(key) ?? QueueInsertionType.moreAlbum, QueueInsertion.fromJson(value)),
          )) ??
          queueInsertion.map((key, value) => MapEntry(key, value));

      ///
    } catch (e) {
      printy(e, isError: true);
      await file.delete();
    }
  }

  Map<K, V>? _getEnumMap<K, V>(dynamic jsonMap, List<K> enumKeys, K defaultKey, List<V> enumValues, V defaultValue) {
    return ((jsonMap as Map?)?.map(
      (key, value) => MapEntry(enumKeys.getEnum(key) ?? defaultKey, enumValues.getEnum(value) ?? defaultValue),
    ));
  }

  bool _canWriteSettings = true;

  /// Writes the values of this  class to a json file, with a minimum interval of [2 seconds]
  /// to prevent rediculous numbers of successive writes, especially for widgets like [NamidaWheelSlider]
  Future<void> _writeToStorage({bool justSaveWithoutWaiting = false}) async {
    if (!_canWriteSettings) {
      return;
    }
    _canWriteSettings = false;

    final file = File(AppPaths.SETTINGS);
    final res = {
      'selectedLanguage': selectedLanguage.toJson(),
      'themeMode': themeMode.value.convertToString,
      'pitchBlack': pitchBlack.value,
      'autoColor': autoColor.value,
      'staticColor': staticColor.value,
      'staticColorDark': staticColorDark.value,
      'selectedLibraryTab': selectedLibraryTab.value.convertToString,
      'staticLibraryTab': staticLibraryTab.value.convertToString,
      'autoLibraryTab': autoLibraryTab.value,
      'libraryTabs': libraryTabs.mapped((element) => element.convertToString),
      'homePageItems': homePageItems.mapped((element) => element.convertToString),
      'activeSearchMediaTypes': activeSearchMediaTypes.mapped((element) => element.convertToString),
      'albumIdentifiers': albumIdentifiers.mapped((element) => element.convertToString),
      'searchResultsPlayMode': searchResultsPlayMode.value,
      'borderRadiusMultiplier': borderRadiusMultiplier.value,
      'fontScaleFactor': fontScaleFactor.value,
      'artworkCacheHeightMultiplier': artworkCacheHeightMultiplier.value,
      'trackThumbnailSizeinList': trackThumbnailSizeinList.value,
      'trackListTileHeight': trackListTileHeight.value,
      'albumThumbnailSizeinList': albumThumbnailSizeinList.value,
      'albumListTileHeight': albumListTileHeight.value,
      'nowPlayingImageContainerHeight': nowPlayingImageContainerHeight.value,

      'enableVolumeFadeOnPlayPause': enableVolumeFadeOnPlayPause.value,
      'displayTrackNumberinAlbumPage': displayTrackNumberinAlbumPage.value,
      'albumCardTopRightDate': albumCardTopRightDate.value,
      'forceSquaredTrackThumbnail': forceSquaredTrackThumbnail.value,
      'forceSquaredAlbumThumbnail': forceSquaredAlbumThumbnail.value,
      'useAlbumStaggeredGridView': useAlbumStaggeredGridView.value,
      'useSettingCollapsedTiles': useSettingCollapsedTiles.value,
      'albumGridCount': albumGridCount.value,
      'artistGridCount': artistGridCount.value,
      'genreGridCount': genreGridCount.value,
      'playlistGridCount': playlistGridCount.value,
      'enableBlurEffect': enableBlurEffect.value,
      'enableGlowEffect': enableGlowEffect.value,
      'hourFormat12': hourFormat12.value,
      'dateTimeFormat': dateTimeFormat.value,
      'trackArtistsSeparators': trackArtistsSeparators.toList(),
      'trackGenresSeparators': trackGenresSeparators.toList(),
      'trackArtistsSeparatorsBlacklist': trackArtistsSeparatorsBlacklist.toList(),
      'trackGenresSeparatorsBlacklist': trackGenresSeparatorsBlacklist.toList(),
      'tracksSort': tracksSort.value.convertToString,
      'tracksSortReversed': tracksSortReversed.value,
      'albumSort': albumSort.value.convertToString,
      'albumSortReversed': albumSortReversed.value,
      'artistSort': artistSort.value.convertToString,
      'artistSortReversed': artistSortReversed.value,
      'genreSort': genreSort.value.convertToString,
      'genreSortReversed': genreSortReversed.value,
      'playlistSort': playlistSort.value.convertToString,
      'playlistSortReversed': playlistSortReversed.value,
      'indexMinDurationInSec': indexMinDurationInSec.value,
      'indexMinFileSizeInB': indexMinFileSizeInB.value,
      'trackSearchFilter': trackSearchFilter.toList(),
      'playlistSearchFilter': playlistSearchFilter.toList(),
      'directoriesToScan': directoriesToScan.toList(),
      'directoriesToExclude': directoriesToExclude.toList(),
      'preventDuplicatedTracks': preventDuplicatedTracks.value,
      'respectNoMedia': respectNoMedia.value,
      'defaultBackupLocation': defaultBackupLocation.value,
      'defaultFolderStartupLocation': defaultFolderStartupLocation.value,
      'enableFoldersHierarchy': enableFoldersHierarchy.value,
      'displayArtistBeforeTitle': displayArtistBeforeTitle.value,
      'backupItemslist': backupItemslist.toList(),
      'enableVideoPlayback': enableVideoPlayback.value,
      'enableLyrics': enableLyrics.value,
      'videoPlaybackSource': videoPlaybackSource.value.convertToString,
      'youtubeVideoQualities': youtubeVideoQualities.toList(),
      'animatingThumbnailIntensity': animatingThumbnailIntensity.value,
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
      'imagesMaxCacheInMB': imagesMaxCacheInMB.value,
      'ytMiniplayerDimAfterSeconds': ytMiniplayerDimAfterSeconds.value,
      'ytMiniplayerDimOpacity': ytMiniplayerDimOpacity.value,
      'playerVolume': playerVolume.value,
      'playerSpeed': playerSpeed.value,
      'playerPitch': playerPitch.value,
      'seekDurationInSeconds': seekDurationInSeconds.value,
      'seekDurationInPercentage': seekDurationInPercentage.value,
      'isSeekDurationPercentage': isSeekDurationPercentage.value,
      'playerPlayFadeDurInMilli': playerPlayFadeDurInMilli.value,
      'playerPauseFadeDurInMilli': playerPauseFadeDurInMilli.value,
      'minTrackDurationToRestoreLastPosInMinutes': minTrackDurationToRestoreLastPosInMinutes.value,
      'lastPlayedTrackPath': lastPlayedTrackPath.value,
      'displayFavouriteButtonInNotification': displayFavouriteButtonInNotification.value,
      'enableSearchCleanup': enableSearchCleanup.value,
      'enableBottomNavBar': enableBottomNavBar.value,
      'ytPreferNewComments': ytPreferNewComments.value,
      'ytAutoExtractVideoTagsFromInfo': ytAutoExtractVideoTagsFromInfo.value,
      'playerPlayOnNextPrev': playerPlayOnNextPrev.value,
      'playerSkipSilenceEnabled': playerSkipSilenceEnabled.value,
      'playerShuffleAllTracks': playerShuffleAllTracks.value,
      'playerPauseOnVolume0': playerPauseOnVolume0.value,
      'playerResumeAfterOnVolume0Pause': playerResumeAfterOnVolume0Pause.value,
      'playerResumeAfterWasInterrupted': playerResumeAfterWasInterrupted.value,
      'jumpToFirstTrackAfterFinishingQueue': jumpToFirstTrackAfterFinishingQueue.value,
      'displayAudioInfoMiniplayer': displayAudioInfoMiniplayer.value,
      'showUnknownFieldsInTrackInfoDialog': showUnknownFieldsInTrackInfoDialog.value,
      'extractFeatArtistFromTitle': extractFeatArtistFromTitle.value,
      'groupArtworksByAlbum': groupArtworksByAlbum.value,
      'tagFieldsToEdit': tagFieldsToEdit.mapped((element) => element.convertToString),
      'wakelockMode': wakelockMode.value.convertToString,
      'localVideoMatchingType': localVideoMatchingType.value.convertToString,
      'localVideoMatchingCheckSameDir': localVideoMatchingCheckSameDir.value,
      'playerRepeatMode': playerRepeatMode.value.convertToString,
      'trackPlayMode': trackPlayMode.value.convertToString,
      'mostPlayedTimeRange': mostPlayedTimeRange.value.convertToString,
      'onNotificationTapAction': onNotificationTapAction.value.convertToString,
      'onYoutubeLinkOpen': onYoutubeLinkOpen.value.convertToString,
      'performanceMode': performanceMode.value.convertToString,
      'mostPlayedCustomDateRange': mostPlayedCustomDateRange.value.toJson(),
      'mostPlayedCustomisStartOfDay': mostPlayedCustomisStartOfDay.value,

      /// Track Items
      'displayThirdRow': displayThirdRow.value,
      'displayThirdItemInEachRow': displayThirdItemInEachRow.value,
      'trackTileSeparator': trackTileSeparator.value,
      'displayFavouriteIconInListTile': displayFavouriteIconInListTile.value,
      'editTagsKeepFileDates': editTagsKeepFileDates.value,
      'downloadFilesWriteUploadDate': downloadFilesWriteUploadDate.value,
      'downloadFilesKeepCachedVersions': downloadFilesKeepCachedVersions.value,
      'enablePip': enablePip.value,
      'playerInfiniyQueueOnNextPrevious': playerInfiniyQueueOnNextPrevious.value,
      'displayRemainingDurInsteadOfTotal': displayRemainingDurInsteadOfTotal.value,
      'pickColorsFromDeviceWallpaper': pickColorsFromDeviceWallpaper.value,
      'trackItem': trackItem.map((key, value) => MapEntry(key.convertToString, value.convertToString)),
      'playerOnInterrupted': playerOnInterrupted.map((key, value) => MapEntry(key.convertToString, value.convertToString)),
      'queueInsertion': queueInsertion.map((key, value) => MapEntry(key.convertToString, value.toJson())),
    };
    await file.writeAsJson(res);

    printy("Setting File Write");

    if (justSaveWithoutWaiting) {
      _canWriteSettings = true;
    } else {
      await Future.delayed(const Duration(seconds: 2));
      _canWriteSettings = true;
      _writeToStorage(justSaveWithoutWaiting: true);
    }
  }

  /// Saves a value to the key, if [List] or [Set], then it will add to it.
  void save({
    NamidaLanguage? selectedLanguage,
    ThemeMode? themeMode,
    bool? pitchBlack,
    bool? autoColor,
    int? staticColor,
    int? staticColorDark,
    int? searchResultsPlayMode,
    LibraryTab? selectedLibraryTab,
    LibraryTab? staticLibraryTab,
    bool? autoLibraryTab,
    List<LibraryTab>? libraryTabs,
    List<HomePageItems>? homePageItems,
    List<MediaType>? activeSearchMediaTypes,
    List<AlbumIdentifier>? albumIdentifiers,
    double? borderRadiusMultiplier,
    double? fontScaleFactor,
    double? artworkCacheHeightMultiplier,
    double? trackThumbnailSizeinList,
    double? trackListTileHeight,
    double? albumThumbnailSizeinList,
    double? albumListTileHeight,
    double? nowPlayingImageContainerHeight,
    bool? enableVolumeFadeOnPlayPause,
    bool? displayTrackNumberinAlbumPage,
    bool? albumCardTopRightDate,
    bool? forceSquaredTrackThumbnail,
    bool? forceSquaredAlbumThumbnail,
    bool? useAlbumStaggeredGridView,
    bool? useSettingCollapsedTiles,
    int? albumGridCount,
    int? artistGridCount,
    int? genreGridCount,
    int? playlistGridCount,
    bool? enableBlurEffect,
    bool? enableGlowEffect,
    bool? hourFormat12,
    String? dateTimeFormat,
    List<String>? trackArtistsSeparators,
    List<String>? trackGenresSeparators,
    List<String>? trackArtistsSeparatorsBlacklist,
    List<String>? trackGenresSeparatorsBlacklist,
    SortType? tracksSort,
    bool? tracksSortReversed,
    GroupSortType? albumSort,
    bool? albumSortReversed,
    GroupSortType? artistSort,
    bool? artistSortReversed,
    GroupSortType? genreSort,
    bool? genreSortReversed,
    GroupSortType? playlistSort,
    bool? playlistSortReversed,
    bool? displayThirdRow,
    bool? displayThirdItemInEachRow,
    String? trackTileSeparator,
    int? indexMinDurationInSec,
    int? indexMinFileSizeInB,
    List<String>? trackSearchFilter,
    List<String>? playlistSearchFilter,
    List<String>? directoriesToScan,
    List<String>? directoriesToExclude,
    bool? preventDuplicatedTracks,
    bool? respectNoMedia,
    String? defaultBackupLocation,
    String? defaultFolderStartupLocation,
    bool? enableFoldersHierarchy,
    bool? displayArtistBeforeTitle,
    List<String>? backupItemslist,
    bool? enableVideoPlayback,
    bool? enableLyrics,
    VideoPlaybackSource? videoPlaybackSource,
    List<String>? youtubeVideoQualities,
    int? animatingThumbnailIntensity,
    bool? animatingThumbnailInversed,
    bool? enablePartyModeInMiniplayer,
    bool? enablePartyModeColorSwap,
    bool? enableMiniplayerParticles,
    bool? enableMiniplayerParallaxEffect,
    bool? forceMiniplayerTrackColor,
    int? isTrackPlayedSecondsCount,
    int? isTrackPlayedPercentageCount,
    bool? displayFavouriteIconInListTile,
    bool? editTagsKeepFileDates,
    bool? downloadFilesWriteUploadDate,
    bool? downloadFilesKeepCachedVersions,
    bool? enablePip,
    bool? playerInfiniyQueueOnNextPrevious,
    bool? displayRemainingDurInsteadOfTotal,
    bool? pickColorsFromDeviceWallpaper,
    int? waveformTotalBars,
    int? videosMaxCacheInMB,
    int? imagesMaxCacheInMB,
    int? ytMiniplayerDimAfterSeconds,
    double? ytMiniplayerDimOpacity,
    double? playerVolume,
    double? playerSpeed,
    double? playerPitch,
    int? seekDurationInSeconds,
    int? seekDurationInPercentage,
    bool? isSeekDurationPercentage,
    int? playerPlayFadeDurInMilli,
    int? playerPauseFadeDurInMilli,
    int? minTrackDurationToRestoreLastPosInMinutes,
    String? lastPlayedTrackPath,
    bool? displayFavouriteButtonInNotification,
    bool? enableSearchCleanup,
    bool? enableBottomNavBar,
    bool? ytPreferNewComments,
    bool? ytAutoExtractVideoTagsFromInfo,
    bool? playerPlayOnNextPrev,
    bool? playerSkipSilenceEnabled,
    bool? playerShuffleAllTracks,
    bool? playerPauseOnVolume0,
    bool? playerResumeAfterOnVolume0Pause,
    bool? playerResumeAfterWasInterrupted,
    bool? jumpToFirstTrackAfterFinishingQueue,
    bool? displayAudioInfoMiniplayer,
    bool? showUnknownFieldsInTrackInfoDialog,
    bool? extractFeatArtistFromTitle,
    bool? groupArtworksByAlbum,
    List<TagField>? tagFieldsToEdit,
    WakelockMode? wakelockMode,
    LocalVideoMatchingType? localVideoMatchingType,
    bool? localVideoMatchingCheckSameDir,
    RepeatMode? playerRepeatMode,
    TrackPlayMode? trackPlayMode,
    MostPlayedTimeRange? mostPlayedTimeRange,
    NotificationTapAction? onNotificationTapAction,
    OnYoutubeLinkOpenAction? onYoutubeLinkOpen,
    PerformanceMode? performanceMode,
    DateRange? mostPlayedCustomDateRange,
    bool? mostPlayedCustomisStartOfDay,
    bool? didSupportNamida,
  }) {
    if (selectedLanguage != null) {
      this.selectedLanguage.value = selectedLanguage;
    }
    if (themeMode != null) {
      this.themeMode.value = themeMode;
    }
    if (pitchBlack != null) {
      this.pitchBlack.value = pitchBlack;
    }
    if (autoColor != null) {
      this.autoColor.value = autoColor;
    }
    if (staticColor != null) {
      this.staticColor.value = staticColor;
    }
    if (staticColorDark != null) {
      this.staticColorDark.value = staticColorDark;
    }
    if (selectedLibraryTab != null) {
      this.selectedLibraryTab.value = selectedLibraryTab;
    }
    if (staticLibraryTab != null) {
      this.staticLibraryTab.value = staticLibraryTab;
    }
    if (autoLibraryTab != null) {
      this.autoLibraryTab.value = autoLibraryTab;
    }
    if (libraryTabs != null) {
      libraryTabs.loop((t, index) {
        if (!this.libraryTabs.contains(t)) {
          this.libraryTabs.add(t);
        }
      });
    }
    if (homePageItems != null) {
      homePageItems.loop((t, index) {
        if (!this.homePageItems.contains(t)) {
          this.homePageItems.add(t);
        }
      });
    }
    if (activeSearchMediaTypes != null) {
      activeSearchMediaTypes.loop((t, index) {
        if (!this.activeSearchMediaTypes.contains(t)) {
          this.activeSearchMediaTypes.add(t);
        }
      });
    }
    if (albumIdentifiers != null) {
      albumIdentifiers.loop((t, index) {
        if (!this.albumIdentifiers.contains(t)) {
          this.albumIdentifiers.add(t);
        }
      });
    }

    if (searchResultsPlayMode != null) {
      this.searchResultsPlayMode.value = searchResultsPlayMode;
    }
    if (borderRadiusMultiplier != null) {
      this.borderRadiusMultiplier.value = borderRadiusMultiplier;
    }
    if (fontScaleFactor != null) {
      this.fontScaleFactor.value = fontScaleFactor;
    }
    if (artworkCacheHeightMultiplier != null) {
      this.artworkCacheHeightMultiplier.value = artworkCacheHeightMultiplier;
    }
    if (trackThumbnailSizeinList != null) {
      this.trackThumbnailSizeinList.value = trackThumbnailSizeinList;
    }
    if (trackListTileHeight != null) {
      this.trackListTileHeight.value = trackListTileHeight;
    }

    if (albumThumbnailSizeinList != null) {
      this.albumThumbnailSizeinList.value = albumThumbnailSizeinList;
    }
    if (albumListTileHeight != null) {
      this.albumListTileHeight.value = albumListTileHeight;
    }

    if (nowPlayingImageContainerHeight != null) {
      this.nowPlayingImageContainerHeight.value = nowPlayingImageContainerHeight;
    }
    if (enableVolumeFadeOnPlayPause != null) {
      this.enableVolumeFadeOnPlayPause.value = enableVolumeFadeOnPlayPause;
    }
    if (displayTrackNumberinAlbumPage != null) {
      this.displayTrackNumberinAlbumPage.value = displayTrackNumberinAlbumPage;
    }
    if (albumCardTopRightDate != null) {
      this.albumCardTopRightDate.value = albumCardTopRightDate;
    }
    if (forceSquaredTrackThumbnail != null) {
      this.forceSquaredTrackThumbnail.value = forceSquaredTrackThumbnail;
    }
    if (forceSquaredAlbumThumbnail != null) {
      this.forceSquaredAlbumThumbnail.value = forceSquaredAlbumThumbnail;
    }
    if (useAlbumStaggeredGridView != null) {
      this.useAlbumStaggeredGridView.value = useAlbumStaggeredGridView;
    }
    if (useSettingCollapsedTiles != null) {
      this.useSettingCollapsedTiles.value = useSettingCollapsedTiles;
    }
    if (albumGridCount != null) {
      this.albumGridCount.value = albumGridCount;
    }
    if (artistGridCount != null) {
      this.artistGridCount.value = artistGridCount;
    }
    if (genreGridCount != null) {
      this.genreGridCount.value = genreGridCount;
    }
    if (playlistGridCount != null) {
      this.playlistGridCount.value = playlistGridCount;
    }
    if (enableBlurEffect != null) {
      this.enableBlurEffect.value = enableBlurEffect;
    }
    if (enableGlowEffect != null) {
      this.enableGlowEffect.value = enableGlowEffect;
    }
    if (hourFormat12 != null) {
      this.hourFormat12.value = hourFormat12;
    }
    if (dateTimeFormat != null) {
      this.dateTimeFormat.value = dateTimeFormat;
    }

    ///
    if (trackArtistsSeparators != null && !this.trackArtistsSeparators.contains(trackArtistsSeparators[0])) {
      this.trackArtistsSeparators.addAll(trackArtistsSeparators);
    }
    if (trackGenresSeparators != null && !this.trackGenresSeparators.contains(trackGenresSeparators[0])) {
      this.trackGenresSeparators.addAll(trackGenresSeparators);
    }
    if (trackArtistsSeparatorsBlacklist != null && !this.trackArtistsSeparatorsBlacklist.contains(trackArtistsSeparatorsBlacklist[0])) {
      this.trackArtistsSeparatorsBlacklist.addAll(trackArtistsSeparatorsBlacklist);
    }
    if (trackGenresSeparatorsBlacklist != null && !this.trackGenresSeparatorsBlacklist.contains(trackGenresSeparatorsBlacklist[0])) {
      this.trackGenresSeparatorsBlacklist.addAll(trackGenresSeparatorsBlacklist);
    }
    if (tracksSort != null) {
      this.tracksSort.value = tracksSort;
    }
    if (tracksSortReversed != null) {
      this.tracksSortReversed.value = tracksSortReversed;
    }
    if (albumSort != null) {
      this.albumSort.value = albumSort;
    }
    if (albumSortReversed != null) {
      this.albumSortReversed.value = albumSortReversed;
    }
    if (artistSort != null) {
      this.artistSort.value = artistSort;
    }
    if (artistSortReversed != null) {
      this.artistSortReversed.value = artistSortReversed;
    }
    if (genreSort != null) {
      this.genreSort.value = genreSort;
    }
    if (genreSortReversed != null) {
      this.genreSortReversed.value = genreSortReversed;
    }
    if (playlistSort != null) {
      this.playlistSort.value = playlistSort;
    }
    if (playlistSortReversed != null) {
      this.playlistSortReversed.value = playlistSortReversed;
    }
    if (displayThirdRow != null) {
      this.displayThirdRow.value = displayThirdRow;
    }
    if (displayThirdItemInEachRow != null) {
      this.displayThirdItemInEachRow.value = displayThirdItemInEachRow;
    }
    if (trackTileSeparator != null) {
      this.trackTileSeparator.value = trackTileSeparator;
    }
    if (indexMinDurationInSec != null) {
      this.indexMinDurationInSec.value = indexMinDurationInSec;
    }
    if (indexMinFileSizeInB != null) {
      this.indexMinFileSizeInB.value = indexMinFileSizeInB;
    }
    if (trackSearchFilter != null) {
      trackSearchFilter.loop((f, index) {
        if (!this.trackSearchFilter.contains(f)) {
          this.trackSearchFilter.add(f);
        }
      });
    }
    if (playlistSearchFilter != null) {
      playlistSearchFilter.loop((f, index) {
        if (!this.playlistSearchFilter.contains(f)) {
          this.playlistSearchFilter.add(f);
        }
      });
    }
    if (directoriesToScan != null) {
      directoriesToScan.loop((d, index) {
        if (!this.directoriesToScan.contains(d)) {
          this.directoriesToScan.add(d);
        }
      });
    }
    if (directoriesToExclude != null) {
      directoriesToExclude.loop((d, index) {
        if (!this.directoriesToExclude.contains(d)) {
          this.directoriesToExclude.add(d);
        }
      });
    }
    if (preventDuplicatedTracks != null) {
      this.preventDuplicatedTracks.value = preventDuplicatedTracks;
    }
    if (respectNoMedia != null) {
      this.respectNoMedia.value = respectNoMedia;
    }
    if (defaultBackupLocation != null) {
      this.defaultBackupLocation.value = defaultBackupLocation;
    }
    if (defaultFolderStartupLocation != null) {
      this.defaultFolderStartupLocation.value = defaultFolderStartupLocation;
    }
    if (enableFoldersHierarchy != null) {
      this.enableFoldersHierarchy.value = enableFoldersHierarchy;
    }
    if (displayArtistBeforeTitle != null) {
      this.displayArtistBeforeTitle.value = displayArtistBeforeTitle;
    }
    if (backupItemslist != null) {
      backupItemslist.loop((d, index) {
        if (!this.backupItemslist.contains(d)) {
          this.backupItemslist.add(d);
        }
      });
    }
    if (youtubeVideoQualities != null) {
      youtubeVideoQualities.loop((q, index) {
        if (!this.youtubeVideoQualities.contains(q)) {
          this.youtubeVideoQualities.add(q);
        }
      });
    }
    if (enableVideoPlayback != null) {
      this.enableVideoPlayback.value = enableVideoPlayback;
    }
    if (enableLyrics != null) {
      this.enableLyrics.value = enableLyrics;
    }
    if (videoPlaybackSource != null) {
      this.videoPlaybackSource.value = videoPlaybackSource;
    }
    if (animatingThumbnailIntensity != null) {
      this.animatingThumbnailIntensity.value = animatingThumbnailIntensity;
    }
    if (animatingThumbnailInversed != null) {
      this.animatingThumbnailInversed.value = animatingThumbnailInversed;
    }
    if (enablePartyModeInMiniplayer != null) {
      this.enablePartyModeInMiniplayer.value = enablePartyModeInMiniplayer;
    }
    if (enablePartyModeColorSwap != null) {
      this.enablePartyModeColorSwap.value = enablePartyModeColorSwap;
    }
    if (enableMiniplayerParticles != null) {
      this.enableMiniplayerParticles.value = enableMiniplayerParticles;
    }
    if (enableMiniplayerParallaxEffect != null) {
      this.enableMiniplayerParallaxEffect.value = enableMiniplayerParallaxEffect;
    }
    if (forceMiniplayerTrackColor != null) {
      this.forceMiniplayerTrackColor.value = forceMiniplayerTrackColor;
    }
    if (isTrackPlayedSecondsCount != null) {
      this.isTrackPlayedSecondsCount.value = isTrackPlayedSecondsCount;
    }
    if (isTrackPlayedPercentageCount != null) {
      this.isTrackPlayedPercentageCount.value = isTrackPlayedPercentageCount;
    }
    if (displayFavouriteIconInListTile != null) {
      this.displayFavouriteIconInListTile.value = displayFavouriteIconInListTile;
    }
    if (editTagsKeepFileDates != null) {
      this.editTagsKeepFileDates.value = editTagsKeepFileDates;
    }
    if (downloadFilesWriteUploadDate != null) {
      this.downloadFilesWriteUploadDate.value = downloadFilesWriteUploadDate;
    }
    if (downloadFilesKeepCachedVersions != null) {
      this.downloadFilesKeepCachedVersions.value = downloadFilesKeepCachedVersions;
    }
    if (enablePip != null) {
      this.enablePip.value = enablePip;
    }
    if (playerInfiniyQueueOnNextPrevious != null) {
      this.playerInfiniyQueueOnNextPrevious.value = playerInfiniyQueueOnNextPrevious;
    }
    if (displayRemainingDurInsteadOfTotal != null) {
      this.displayRemainingDurInsteadOfTotal.value = displayRemainingDurInsteadOfTotal;
    }
    if (pickColorsFromDeviceWallpaper != null) {
      this.pickColorsFromDeviceWallpaper.value = pickColorsFromDeviceWallpaper;
    }
    if (waveformTotalBars != null) {
      this.waveformTotalBars.value = waveformTotalBars;
    }
    if (videosMaxCacheInMB != null) {
      this.videosMaxCacheInMB.value = videosMaxCacheInMB;
    }
    if (imagesMaxCacheInMB != null) {
      this.imagesMaxCacheInMB.value = imagesMaxCacheInMB;
    }
    if (ytMiniplayerDimAfterSeconds != null) {
      this.ytMiniplayerDimAfterSeconds.value = ytMiniplayerDimAfterSeconds;
    }
    if (ytMiniplayerDimOpacity != null) {
      this.ytMiniplayerDimOpacity.value = ytMiniplayerDimOpacity;
    }
    if (playerVolume != null) {
      this.playerVolume.value = playerVolume;
    }
    if (playerSpeed != null) {
      this.playerSpeed.value = playerSpeed;
    }
    if (playerPitch != null) {
      this.playerPitch.value = playerPitch;
    }
    if (seekDurationInSeconds != null) {
      this.seekDurationInSeconds.value = seekDurationInSeconds;
    }
    if (seekDurationInPercentage != null) {
      this.seekDurationInPercentage.value = seekDurationInPercentage;
    }
    if (isSeekDurationPercentage != null) {
      this.isSeekDurationPercentage.value = isSeekDurationPercentage;
    }
    if (playerPlayFadeDurInMilli != null) {
      this.playerPlayFadeDurInMilli.value = playerPlayFadeDurInMilli;
    }
    if (playerPauseFadeDurInMilli != null) {
      this.playerPauseFadeDurInMilli.value = playerPauseFadeDurInMilli;
    }
    if (minTrackDurationToRestoreLastPosInMinutes != null) {
      this.minTrackDurationToRestoreLastPosInMinutes.value = minTrackDurationToRestoreLastPosInMinutes;
    }
    if (lastPlayedTrackPath != null) {
      this.lastPlayedTrackPath.value = lastPlayedTrackPath;
    }
    if (displayFavouriteButtonInNotification != null) {
      this.displayFavouriteButtonInNotification.value = displayFavouriteButtonInNotification;
    }
    if (enableSearchCleanup != null) {
      this.enableSearchCleanup.value = enableSearchCleanup;
    }
    if (enableBottomNavBar != null) {
      this.enableBottomNavBar.value = enableBottomNavBar;
    }
    if (ytPreferNewComments != null) {
      this.ytPreferNewComments.value = ytPreferNewComments;
    }
    if (ytAutoExtractVideoTagsFromInfo != null) {
      this.ytAutoExtractVideoTagsFromInfo.value = ytAutoExtractVideoTagsFromInfo;
    }
    if (playerPlayOnNextPrev != null) {
      this.playerPlayOnNextPrev.value = playerPlayOnNextPrev;
    }
    if (playerSkipSilenceEnabled != null) {
      this.playerSkipSilenceEnabled.value = playerSkipSilenceEnabled;
    }
    if (playerShuffleAllTracks != null) {
      this.playerShuffleAllTracks.value = playerShuffleAllTracks;
    }
    if (playerPauseOnVolume0 != null) {
      this.playerPauseOnVolume0.value = playerPauseOnVolume0;
    }
    if (playerResumeAfterOnVolume0Pause != null) {
      this.playerResumeAfterOnVolume0Pause.value = playerResumeAfterOnVolume0Pause;
    }
    if (playerResumeAfterWasInterrupted != null) {
      this.playerResumeAfterWasInterrupted.value = playerResumeAfterWasInterrupted;
    }
    if (jumpToFirstTrackAfterFinishingQueue != null) {
      this.jumpToFirstTrackAfterFinishingQueue.value = jumpToFirstTrackAfterFinishingQueue;
    }
    if (displayAudioInfoMiniplayer != null) {
      this.displayAudioInfoMiniplayer.value = displayAudioInfoMiniplayer;
    }
    if (showUnknownFieldsInTrackInfoDialog != null) {
      this.showUnknownFieldsInTrackInfoDialog.value = showUnknownFieldsInTrackInfoDialog;
    }
    if (extractFeatArtistFromTitle != null) {
      this.extractFeatArtistFromTitle.value = extractFeatArtistFromTitle;
    }
    if (groupArtworksByAlbum != null) {
      this.groupArtworksByAlbum.value = groupArtworksByAlbum;
    }
    if (tagFieldsToEdit != null) {
      tagFieldsToEdit.loop((d, index) {
        if (!this.tagFieldsToEdit.contains(d)) {
          this.tagFieldsToEdit.add(d);
        }
      });
    }
    if (wakelockMode != null) {
      this.wakelockMode.value = wakelockMode;
    }
    if (localVideoMatchingType != null) {
      this.localVideoMatchingType.value = localVideoMatchingType;
    }
    if (localVideoMatchingCheckSameDir != null) {
      this.localVideoMatchingCheckSameDir.value = localVideoMatchingCheckSameDir;
    }
    if (playerRepeatMode != null) {
      this.playerRepeatMode.value = playerRepeatMode;
    }
    if (trackPlayMode != null) {
      this.trackPlayMode.value = trackPlayMode;
    }
    if (mostPlayedTimeRange != null) {
      this.mostPlayedTimeRange.value = mostPlayedTimeRange;
    }
    if (onNotificationTapAction != null) {
      this.onNotificationTapAction.value = onNotificationTapAction;
    }
    if (onYoutubeLinkOpen != null) {
      this.onYoutubeLinkOpen.value = onYoutubeLinkOpen;
    }
    if (performanceMode != null) {
      this.performanceMode.value = performanceMode;
    }
    if (mostPlayedCustomDateRange != null) {
      this.mostPlayedCustomDateRange.value = mostPlayedCustomDateRange;
    }
    if (mostPlayedCustomisStartOfDay != null) {
      this.mostPlayedCustomisStartOfDay.value = mostPlayedCustomisStartOfDay;
    }
    if (didSupportNamida != null) {
      this.didSupportNamida = didSupportNamida;
    }
    _writeToStorage();
  }

  void insertInList(
    index, {
    LibraryTab? libraryTab1,
    String? youtubeVideoQualities1,
    TagField? tagFieldsToEdit1,
    HomePageItems? homePageItem1,
  }) {
    if (libraryTab1 != null) {
      libraryTabs.insert(index, libraryTab1);
    }
    if (homePageItem1 != null) {
      homePageItems.insert(index, homePageItem1);
    }
    if (youtubeVideoQualities1 != null) {
      youtubeVideoQualities.insertSafe(index, youtubeVideoQualities1);
    }
    if (tagFieldsToEdit1 != null) {
      tagFieldsToEdit.insertSafe(index, tagFieldsToEdit1);
    }
    _writeToStorage();
  }

  void removeFromList({
    String? trackArtistsSeparator,
    String? trackGenresSeparator,
    String? trackArtistsSeparatorsBlacklist1,
    String? trackGenresSeparatorsBlacklist1,
    String? trackSearchFilter1,
    List<String>? trackSearchFilterAll,
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
    String? backupItemslist1,
    List<String>? backupItemslistAll,
    String? youtubeVideoQualities1,
    List<String>? youtubeVideoQualitiesAll,
    TagField? tagFieldsToEdit1,
    List<TagField>? tagFieldsToEditAll,
  }) {
    if (trackArtistsSeparator != null) {
      trackArtistsSeparators.remove(trackArtistsSeparator);
    }
    if (trackGenresSeparator != null) {
      trackGenresSeparators.remove(trackGenresSeparator);
    }
    if (trackArtistsSeparatorsBlacklist1 != null) {
      trackArtistsSeparatorsBlacklist.remove(trackArtistsSeparatorsBlacklist1);
    }
    if (trackGenresSeparatorsBlacklist1 != null) {
      trackGenresSeparatorsBlacklist.remove(trackGenresSeparatorsBlacklist1);
    }
    if (trackSearchFilter1 != null) {
      trackSearchFilter.remove(trackSearchFilter1);
    }
    if (trackSearchFilterAll != null) {
      trackSearchFilterAll.loop((f, index) {
        trackSearchFilter.remove(f);
      });
    }
    if (playlistSearchFilter1 != null) {
      playlistSearchFilter.remove(playlistSearchFilter1);
    }
    if (playlistSearchFilterAll != null) {
      playlistSearchFilterAll.loop((f, index) {
        playlistSearchFilter.remove(f);
      });
    }
    if (directoriesToScan1 != null) {
      directoriesToScan.remove(directoriesToScan1);
    }
    if (directoriesToScanAll != null) {
      directoriesToScanAll.loop((f, index) {
        directoriesToScan.remove(f);
      });
    }
    if (directoriesToExclude1 != null) {
      directoriesToExclude.remove(directoriesToExclude1);
    }
    if (directoriesToExcludeAll != null) {
      directoriesToExcludeAll.loop((f, index) {
        directoriesToExclude.remove(f);
      });
    }
    if (libraryTab1 != null) {
      libraryTabs.remove(libraryTab1);
    }
    if (libraryTabsAll != null) {
      libraryTabsAll.loop((t, index) {
        libraryTabs.remove(t);
      });
    }
    if (homePageItem1 != null) {
      homePageItems.remove(homePageItem1);
    }
    if (homePageItemsAll != null) {
      homePageItemsAll.loop((t, index) {
        homePageItems.remove(t);
      });
    }
    if (activeSearchMediaTypes1 != null) {
      activeSearchMediaTypes.remove(activeSearchMediaTypes1);
    }
    if (albumIdentifiers1 != null) {
      albumIdentifiers.remove(albumIdentifiers1);
    }
    if (albumIdentifiersAll != null) {
      albumIdentifiersAll.loop((t, index) {
        albumIdentifiers.remove(t);
      });
    }
    if (backupItemslist1 != null) {
      backupItemslist.remove(backupItemslist1);
    }
    if (backupItemslistAll != null) {
      backupItemslistAll.loop((t, index) {
        backupItemslist.remove(t);
      });
    }
    if (youtubeVideoQualities1 != null) {
      youtubeVideoQualities.remove(youtubeVideoQualities1);
    }
    if (youtubeVideoQualitiesAll != null) {
      youtubeVideoQualitiesAll.loop((t, index) {
        youtubeVideoQualities.remove(t);
      });
    }
    if (tagFieldsToEdit1 != null) {
      tagFieldsToEdit.remove(tagFieldsToEdit1);
    }
    if (tagFieldsToEditAll != null) {
      tagFieldsToEditAll.loop((t, index) {
        tagFieldsToEdit.remove(t);
      });
    }
    _writeToStorage();
  }

  void updateTrackItemList(TrackTilePosition p, TrackTileItem i) {
    trackItem[p] = i;
    _writeToStorage();
  }

  void updatePlayerInterruption(InterruptionType type, InterruptionAction action) {
    playerOnInterrupted[type] = action;
    _writeToStorage();
  }

  void updateQueueInsertion(QueueInsertionType type, QueueInsertion qi) {
    queueInsertion[type] = qi;
    _writeToStorage();
  }
}
