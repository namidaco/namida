import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/trackitem.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';

class SettingsController extends GetxController {
  static SettingsController inst = SettingsController();

  final Rx<ThemeMode> themeMode = ThemeMode.system.obs;
  final RxBool autoColor = true.obs;
  final RxInt staticColor = kMainColor.value.obs;
  final Rx<LibraryTab> selectedLibraryTab = LibraryTab.tracks.obs;
  final RxBool autoLibraryTab = true.obs;
  final RxList<String> libraryTabs = kLibraryTabsStock.obs;
  final RxInt searchResultsPlayMode = 1.obs;
  final RxDouble borderRadiusMultiplier = 1.0.obs;
  final RxDouble fontScaleFactor = 1.0.obs;
  final RxDouble trackThumbnailSizeinList = 70.0.obs;
  final RxDouble trackListTileHeight = 70.0.obs;
  final RxDouble albumThumbnailSizeinList = 90.0.obs;
  final RxDouble albumListTileHeight = 90.0.obs;
  final RxDouble queueSheetMinHeight = 25.0.obs;
  final RxDouble queueSheetMaxHeight = 500.0.obs;
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
  final RxBool enableBlurEffect = true.obs;
  final RxBool enableGlowEffect = true.obs;
  final RxBool hourFormat12 = true.obs;
  final RxString dateTimeFormat = 'MMM yyyy'.obs;
  final RxList<String> trackArtistsSeparators = <String>['&', ',', ';', '//'].obs;
  final RxList<String> trackGenresSeparators = <String>['&', ',', ';', '//'].obs;
  final Rx<SortType> tracksSort = SortType.title.obs;
  final RxBool tracksSortReversed = false.obs;
  final Rx<GroupSortType> albumSort = GroupSortType.album.obs;
  final RxBool albumSortReversed = false.obs;
  final Rx<GroupSortType> artistSort = GroupSortType.artistsList.obs;
  final RxBool artistSortReversed = false.obs;
  final Rx<GroupSortType> genreSort = GroupSortType.genresList.obs;
  final RxBool genreSortReversed = false.obs;
  final Rx<GroupSortType> playlistSort = GroupSortType.year.obs;
  final RxBool playlistSortReversed = false.obs;
  final RxInt indexMinDurationInSec = 5.obs;
  final RxInt indexMinFileSizeInB = (100 * 1024).obs;
  final RxList<String> trackSearchFilter = ['title', 'artist', 'album'].obs;
  final RxList<String> playlistSearchFilter = ['name', 'date', 'modes', 'comment'].obs;
  final RxList<String> directoriesToScan = kDirectoriesPaths.toList().obs;
  final RxList<String> directoriesToExclude = <String>[].obs;
  final RxBool preventDuplicatedTracks = false.obs;
  final RxBool respectNoMedia = false.obs;
  final RxString defaultBackupLocation = kInternalAppDirectoryPath.obs;
  final RxString defaultFolderStartupLocation = kStoragePaths.first.obs;
  final RxBool enableFoldersHierarchy = true.obs;
  final RxList<String> backupItemslist =
      [kTracksFilePath, kQueuesFilePath, kLatestQueueFilePath, kPaletteDirPath, kLyricsDirPath, kPlaylistsFilePath, kSettingsFilePath, kWaveformDirPath].obs;
  final RxBool enableVideoPlayback = true.obs;
  final RxBool enableLyrics = false.obs;
  final RxInt videoPlaybackSource = 0.obs;
  final RxList<String> youtubeVideoQualities = ['480p', '360p', '240p', '144p'].obs;
  final RxInt animatingThumbnailIntensity = 25.obs;
  final RxBool animatingThumbnailInversed = false.obs;
  final RxBool enablePartyModeInMiniplayer = false.obs;
  final RxBool enablePartyModeColorSwap = true.obs;
  final RxInt isTrackPlayedSecondsCount = 40.obs;
  final RxInt isTrackPlayedPercentageCount = 40.obs;
  final RxInt waveformTotalBars = 140.obs;
  final RxDouble playerVolume = 1.0.obs;
  final RxInt playerPlayFadeDurInMilli = 300.obs;
  final RxInt playerPauseFadeDurInMilli = 300.obs;
  final RxInt totalListenedTimeInSec = 0.obs;
  final RxString lastPlayedTrackPath = ''.obs;
  final RxBool displayFavouriteButtonInNotification = false.obs;

  final Rx<TrackPlayMode> trackPlayMode = TrackPlayMode.searchResults.obs;

  /// Track Items
  final RxBool displayThirdRow = true.obs;
  final RxBool displayThirdItemInEachRow = false.obs;
  final RxString trackTileSeparator = '•'.obs;
  final RxBool displayFavouriteIconInListTile = true.obs;
  final Rx<TrackItem> trackItem = TrackItem(
    TrackTileItem.title,
    TrackTileItem.none,
    TrackTileItem.none,
    TrackTileItem.artists,
    TrackTileItem.none,
    TrackTileItem.none,
    TrackTileItem.album,
    TrackTileItem.year,
    TrackTileItem.none,
    TrackTileItem.duration,
    TrackTileItem.none,
  ).obs;

  Future<void> prepareSettingsFile({File? file}) async {
    file ??= await File(kSettingsFilePath).create(recursive: true);
    try {
      final String contents = await file.readAsString();
      if (contents.isEmpty) {
        return;
      }
      final json = jsonDecode(contents);

      /// Assigning Values
      themeMode.value = ThemeMode.values.getEnum(json['themeMode']) ?? themeMode.value;
      autoColor.value = json['autoColor'] ?? autoColor.value;
      staticColor.value = json['staticColor'] ?? staticColor.value;
      selectedLibraryTab.value = LibraryTab.values.getEnum(json['selectedLibraryTab']) ?? selectedLibraryTab.value;
      autoLibraryTab.value = json['autoLibraryTab'] ?? autoLibraryTab.value;
      libraryTabs.value = List<String>.from(json['libraryTabs'] ?? libraryTabs.toList());
      searchResultsPlayMode.value = json['searchResultsPlayMode'] ?? searchResultsPlayMode.value;
      borderRadiusMultiplier.value = json['borderRadiusMultiplier'] ?? borderRadiusMultiplier.value;
      fontScaleFactor.value = json['fontScaleFactor'] ?? fontScaleFactor.value;
      trackThumbnailSizeinList.value = json['trackThumbnailSizeinList'] ?? trackThumbnailSizeinList.value;
      trackListTileHeight.value = json['trackListTileHeight'] ?? trackListTileHeight.value;
      albumThumbnailSizeinList.value = json['albumThumbnailSizeinList'] ?? albumThumbnailSizeinList.value;
      albumListTileHeight.value = json['albumListTileHeight'] ?? albumListTileHeight.value;
      queueSheetMinHeight.value = json['queueSheetMinHeight'] ?? queueSheetMinHeight.value;
      queueSheetMaxHeight.value = json['queueSheetMaxHeight'] ?? queueSheetMaxHeight.value;
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

      trackArtistsSeparators.value = List<String>.from(json['trackArtistsSeparators'] ?? trackArtistsSeparators.toList());
      trackGenresSeparators.value = List<String>.from(json['trackGenresSeparators'] ?? trackGenresSeparators.toList());
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

      trackSearchFilter.value = List<String>.from(json['trackSearchFilter'] ?? trackSearchFilter.toList());
      playlistSearchFilter.value = List<String>.from(json['playlistSearchFilter'] ?? playlistSearchFilter.toList());
      directoriesToScan.value = List<String>.from(json['directoriesToScan'] ?? directoriesToScan.toList());
      directoriesToExclude.value = List<String>.from(json['directoriesToExclude'] ?? directoriesToExclude.toList());
      preventDuplicatedTracks.value = json['preventDuplicatedTracks'] ?? preventDuplicatedTracks.value;
      respectNoMedia.value = json['respectNoMedia'] ?? respectNoMedia.value;
      defaultBackupLocation.value = json['defaultBackupLocation'] ?? defaultBackupLocation.value;
      defaultFolderStartupLocation.value = json['defaultFolderStartupLocation'] ?? defaultFolderStartupLocation.value;
      enableFoldersHierarchy.value = json['enableFoldersHierarchy'] ?? enableFoldersHierarchy.value;
      backupItemslist.value = List<String>.from(json['backupItemslist'] ?? backupItemslist.toList());
      enableVideoPlayback.value = json['enableVideoPlayback'] ?? enableVideoPlayback.value;
      enableLyrics.value = json['enableLyrics'] ?? enableLyrics.value;
      videoPlaybackSource.value = json['videoPlaybackSource'] ?? videoPlaybackSource.value;
      youtubeVideoQualities.value = List<String>.from(json['youtubeVideoQualities'] ?? youtubeVideoQualities.toList());

      animatingThumbnailIntensity.value = json['animatingThumbnailIntensity'] ?? animatingThumbnailIntensity.value;
      animatingThumbnailInversed.value = json['animatingThumbnailInversed'] ?? animatingThumbnailInversed.value;
      enablePartyModeInMiniplayer.value = json['enablePartyModeInMiniplayer'] ?? enablePartyModeInMiniplayer.value;
      enablePartyModeColorSwap.value = json['enablePartyModeColorSwap'] ?? enablePartyModeColorSwap.value;
      isTrackPlayedSecondsCount.value = json['isTrackPlayedSecondsCount'] ?? isTrackPlayedSecondsCount.value;
      isTrackPlayedPercentageCount.value = json['isTrackPlayedPercentageCount'] ?? isTrackPlayedPercentageCount.value;
      waveformTotalBars.value = json['waveformTotalBars'] ?? waveformTotalBars.value;
      playerVolume.value = json['playerVolume'] ?? playerVolume.value;
      playerPlayFadeDurInMilli.value = json['playerPlayFadeDurInMilli'] ?? playerPlayFadeDurInMilli.value;
      playerPauseFadeDurInMilli.value = json['playerPauseFadeDurInMilli'] as int? ?? playerPauseFadeDurInMilli.value;
      totalListenedTimeInSec.value = json['totalListenedTimeInSec'] ?? totalListenedTimeInSec.value;
      lastPlayedTrackPath.value = json['lastPlayedTrackPath'] ?? lastPlayedTrackPath.value;
      displayFavouriteButtonInNotification.value = json['displayFavouriteButtonInNotification'] ?? displayFavouriteButtonInNotification.value;

      trackPlayMode.value = TrackPlayMode.values.getEnum(json['trackPlayMode']) ?? trackPlayMode.value;

      /// Track Items
      displayThirdRow.value = json['displayThirdRow'] ?? displayThirdRow.value;
      displayThirdItemInEachRow.value = json['displayThirdItemInEachRow'] ?? displayThirdItemInEachRow.value;
      trackTileSeparator.value = json['trackTileSeparator'] ?? trackTileSeparator.value;
      displayFavouriteIconInListTile.value = json['displayFavouriteIconInListTile'] ?? displayFavouriteIconInListTile.value;
      trackItem.value = TrackItem.fromJson(json['trackItem']);

      ///
    } catch (e) {
      printError(info: e.toString());
      await file.delete();
    }
  }

  Future<void> _writeToStorage({File? file}) async {
    file ??= File(kSettingsFilePath);
    final res = {
      'themeMode': themeMode.value.convertToString,
      'autoColor': autoColor.value,
      'staticColor': staticColor.value,
      'selectedLibraryTab': selectedLibraryTab.value.convertToString,
      'autoLibraryTab': autoLibraryTab.value,
      'libraryTabs': libraryTabs.toList(),
      'searchResultsPlayMode': searchResultsPlayMode.value,
      'borderRadiusMultiplier': borderRadiusMultiplier.value,
      'fontScaleFactor': fontScaleFactor.value,
      'trackThumbnailSizeinList': trackThumbnailSizeinList.value,
      'trackListTileHeight': trackListTileHeight.value,
      'albumThumbnailSizeinList': albumThumbnailSizeinList.value,
      'albumListTileHeight': albumListTileHeight.value,
      'queueSheetMinHeight': queueSheetMinHeight.value,
      'queueSheetMaxHeight': queueSheetMaxHeight.value,
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
      'backupItemslist': backupItemslist.toList(),
      'enableVideoPlayback': enableVideoPlayback.value,
      'enableLyrics': enableLyrics.value,
      'videoPlaybackSource': videoPlaybackSource.value,
      'youtubeVideoQualities': youtubeVideoQualities.toList(),
      'animatingThumbnailIntensity': animatingThumbnailIntensity.value,
      'animatingThumbnailInversed': animatingThumbnailInversed.value,
      'enablePartyModeInMiniplayer': enablePartyModeInMiniplayer.value,
      'enablePartyModeColorSwap': enablePartyModeColorSwap.value,
      'isTrackPlayedSecondsCount': isTrackPlayedSecondsCount.value,
      'isTrackPlayedPercentageCount': isTrackPlayedPercentageCount.value,
      'waveformTotalBars': waveformTotalBars.value,
      'playerVolume': playerVolume.value,
      'playerPlayFadeDurInMilli': playerPlayFadeDurInMilli.value,
      'playerPauseFadeDurInMilli': playerPauseFadeDurInMilli.value,
      'totalListenedTimeInSec': totalListenedTimeInSec.value,
      'lastPlayedTrackPath': lastPlayedTrackPath.value,
      'displayFavouriteButtonInNotification': displayFavouriteButtonInNotification.value,
      'trackPlayMode': trackPlayMode.value.convertToString,

      /// Track Items
      'displayThirdRow': displayThirdRow.value,
      'displayThirdItemInEachRow': displayThirdItemInEachRow.value,
      'trackTileSeparator': trackTileSeparator.value, 'displayFavouriteIconInListTile': displayFavouriteIconInListTile.value,
      'trackItem': trackItem.value.toJson(),
    };
    file.writeAsStringSync(json.encode(res));
  }

  /// Saves a value to the key, if [List] or [Set], then it will add to it.
  void save({
    ThemeMode? themeMode,
    bool? autoColor,
    int? staticColor,
    int? searchResultsPlayMode,
    LibraryTab? selectedLibraryTab,
    bool? autoLibraryTab,
    List<String>? libraryTabs,
    double? borderRadiusMultiplier,
    double? fontScaleFactor,
    double? trackThumbnailSizeinList,
    double? trackListTileHeight,
    double? albumThumbnailSizeinList,
    double? albumListTileHeight,
    double? queueSheetMinHeight,
    double? queueSheetMaxHeight,
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
    List<String>? backupItemslist,
    bool? enableVideoPlayback,
    bool? enableLyrics,
    int? videoPlaybackSource,
    List<String>? youtubeVideoQualities,
    int? animatingThumbnailIntensity,
    bool? animatingThumbnailInversed,
    bool? enablePartyModeInMiniplayer,
    bool? enablePartyModeColorSwap,
    int? isTrackPlayedSecondsCount,
    int? isTrackPlayedPercentageCount,
    bool? displayFavouriteIconInListTile,
    int? waveformTotalBars,
    double? playerVolume,
    int? playerPlayFadeDurInMilli,
    int? playerPauseFadeDurInMilli,
    int? totalListenedTimeInSec,
    String? lastPlayedTrackPath,
    bool? displayFavouriteButtonInNotification,
    TrackPlayMode? trackPlayMode,
  }) {
    if (themeMode != null) {
      this.themeMode.value = themeMode;
    }
    if (autoColor != null) {
      this.autoColor.value = autoColor;
    }
    if (staticColor != null) {
      this.staticColor.value = staticColor;
    }
    if (selectedLibraryTab != null) {
      this.selectedLibraryTab.value = selectedLibraryTab;
    }
    if (autoLibraryTab != null) {
      this.autoLibraryTab.value = autoLibraryTab;
    }
    if (libraryTabs != null) {
      for (var t in libraryTabs) {
        if (!this.libraryTabs.contains(t)) {
          this.libraryTabs.add(t);
        }
      }
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
    if (queueSheetMinHeight != null) {
      this.queueSheetMinHeight.value = queueSheetMinHeight;
    }
    if (queueSheetMaxHeight != null) {
      this.queueSheetMaxHeight.value = queueSheetMaxHeight;
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
      for (var f in trackSearchFilter) {
        if (!this.trackSearchFilter.contains(f)) {
          this.trackSearchFilter.add(f);
        }
      }
    }
    if (playlistSearchFilter != null) {
      for (var f in playlistSearchFilter) {
        if (!this.playlistSearchFilter.contains(f)) {
          this.playlistSearchFilter.add(f);
        }
      }
    }
    if (directoriesToScan != null) {
      for (var d in directoriesToScan) {
        if (!this.directoriesToScan.contains(d)) {
          this.directoriesToScan.add(d);
        }
      }
    }
    if (directoriesToExclude != null) {
      for (var d in directoriesToExclude) {
        if (!this.directoriesToExclude.contains(d)) {
          this.directoriesToExclude.add(d);
        }
      }
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
    if (backupItemslist != null) {
      for (var d in backupItemslist) {
        if (!this.backupItemslist.contains(d)) {
          this.backupItemslist.add(d);
        }
      }
    }
    if (youtubeVideoQualities != null) {
      for (var q in youtubeVideoQualities) {
        if (!this.youtubeVideoQualities.contains(q)) {
          this.youtubeVideoQualities.add(q);
        }
      }
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
    if (isTrackPlayedSecondsCount != null) {
      this.isTrackPlayedSecondsCount.value = isTrackPlayedSecondsCount;
    }
    if (isTrackPlayedPercentageCount != null) {
      this.isTrackPlayedPercentageCount.value = isTrackPlayedPercentageCount;
    }
    if (displayFavouriteIconInListTile != null) {
      this.displayFavouriteIconInListTile.value = displayFavouriteIconInListTile;
    }
    if (waveformTotalBars != null) {
      this.waveformTotalBars.value = waveformTotalBars;
    }
    if (playerVolume != null) {
      this.playerVolume.value = playerVolume;
    }
    if (playerPlayFadeDurInMilli != null) {
      this.playerPlayFadeDurInMilli.value = playerPlayFadeDurInMilli;
    }
    if (playerPauseFadeDurInMilli != null) {
      this.playerPauseFadeDurInMilli.value = playerPauseFadeDurInMilli;
    }
    if (totalListenedTimeInSec != null) {
      this.totalListenedTimeInSec.value = totalListenedTimeInSec;
    }
    if (lastPlayedTrackPath != null) {
      this.lastPlayedTrackPath.value = lastPlayedTrackPath;
    }
    if (displayFavouriteButtonInNotification != null) {
      this.displayFavouriteButtonInNotification.value = displayFavouriteButtonInNotification;
    }
    if (trackPlayMode != null) {
      this.trackPlayMode.value = trackPlayMode;
    }
    _writeToStorage();
    update();
  }

  void insertInList(
    index, {
    String? libraryTab1,
    String? youtubeVideoQualities1,
  }) {
    if (libraryTab1 != null) {
      libraryTabs.insert(index, libraryTab1);
    }
    if (youtubeVideoQualities1 != null) {
      youtubeVideoQualities.insert(index, youtubeVideoQualities1);
    }
    _writeToStorage();
  }

  void removeFromList({
    String? trackArtistsSeparator,
    String? trackGenresSeparator,
    String? trackSearchFilter1,
    List<String>? trackSearchFilterAll,
    String? playlistSearchFilter1,
    List<String>? playlistSearchFilterAll,
    String? directoriesToScan1,
    List<String>? directoriesToScanAll,
    String? directoriesToExclude1,
    List<String>? directoriesToExcludeAll,
    String? libraryTab1,
    List<String>? libraryTabsAll,
    String? backupItemslist1,
    List<String>? backupItemslistAll,
    String? youtubeVideoQualities1,
    List<String>? youtubeVideoQualitiesAll,
  }) {
    if (trackArtistsSeparator != null) {
      trackArtistsSeparators.remove(trackArtistsSeparator);
    }
    if (trackGenresSeparator != null) {
      trackGenresSeparators.remove(trackGenresSeparator);
    }
    if (trackSearchFilter1 != null) {
      trackSearchFilter.remove(trackSearchFilter1);
    }
    if (trackSearchFilterAll != null) {
      for (var f in trackSearchFilterAll) {
        if (trackSearchFilter.contains(f)) {
          trackSearchFilter.remove(f);
        }
      }
    }
    if (playlistSearchFilter1 != null) {
      playlistSearchFilter.remove(playlistSearchFilter1);
    }
    if (playlistSearchFilterAll != null) {
      for (var f in playlistSearchFilterAll) {
        if (playlistSearchFilter.contains(f)) {
          playlistSearchFilter.remove(f);
        }
      }
    }
    if (directoriesToScan1 != null) {
      directoriesToScan.remove(directoriesToScan1);
    }
    if (directoriesToScanAll != null) {
      for (var f in directoriesToScanAll) {
        if (directoriesToScan.contains(f)) {
          directoriesToScan.remove(f);
        }
      }
    }
    if (directoriesToExclude1 != null) {
      directoriesToExclude.remove(directoriesToExclude1);
    }
    if (directoriesToExcludeAll != null) {
      for (var f in directoriesToExcludeAll) {
        if (directoriesToExclude.contains(f)) {
          directoriesToExclude.remove(f);
        }
      }
    }
    if (libraryTab1 != null) {
      libraryTabs.remove(libraryTab1);
    }
    if (libraryTabsAll != null) {
      for (var t in libraryTabsAll) {
        if (libraryTabs.contains(t)) {
          libraryTabs.remove(t);
        }
      }
    }
    if (backupItemslist1 != null) {
      backupItemslist.remove(backupItemslist1);
    }
    if (backupItemslistAll != null) {
      for (var t in backupItemslistAll) {
        if (backupItemslist.contains(t)) {
          backupItemslist.remove(t);
        }
      }
    }
    if (youtubeVideoQualities1 != null) {
      youtubeVideoQualities.remove(youtubeVideoQualities1);
    }
    if (youtubeVideoQualitiesAll != null) {
      for (var t in youtubeVideoQualitiesAll) {
        if (youtubeVideoQualities.contains(t)) {
          youtubeVideoQualities.remove(t);
        }
      }
    }
    _writeToStorage();
    update();
  }

  void updateTrackItemList(TrackTilePosition p, TrackTileItem i) {
    switch (p) {
      case TrackTilePosition.row1Item1:
        trackItem.value.row1Item1 = i;
        break;
      case TrackTilePosition.row1Item2:
        trackItem.value.row1Item2 = i;
        break;
      case TrackTilePosition.row1Item3:
        trackItem.value.row1Item3 = i;
        break;
      case TrackTilePosition.row2Item1:
        trackItem.value.row2Item1 = i;
        break;
      case TrackTilePosition.row2Item2:
        trackItem.value.row2Item2 = i;
        break;
      case TrackTilePosition.row2Item3:
        trackItem.value.row2Item3 = i;
        break;
      case TrackTilePosition.row3Item1:
        trackItem.value.row3Item1 = i;
        break;
      case TrackTilePosition.row3Item2:
        trackItem.value.row3Item2 = i;
        break;
      case TrackTilePosition.row3Item3:
        trackItem.value.row3Item3 = i;
        break;
      case TrackTilePosition.rightItem1:
        trackItem.value.rightItem1 = i;
        break;
      case TrackTilePosition.rightItem2:
        trackItem.value.rightItem2 = i;
        break;
      default:
        null;
    }
    trackItem.refresh();
    _writeToStorage();
  }

  @override
  void onClose() {
    Get.delete();
    super.onClose();
  }
}
