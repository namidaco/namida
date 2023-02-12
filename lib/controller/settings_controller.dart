import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';

class SettingsController extends GetxController {
  static SettingsController inst = SettingsController();

  Rx<ThemeMode> themeMode = ThemeMode.system.obs;
  Rx<LibraryTab> selectedLibraryTab = LibraryTab.tracks.obs;
  RxInt searchResultsPlayMode = 1.obs;
  RxDouble borderRadiusMultiplier = 1.0.obs;
  RxDouble fontScaleFactor = 1.0.obs;
  RxDouble trackThumbnailSizeinList = 70.0.obs;
  RxDouble trackListTileHeight = 70.0.obs;
  RxDouble albumThumbnailSizeinList = 90.0.obs;
  RxDouble albumListTileHeight = 90.0.obs;
  RxDouble queueSheetMinHeight = 25.0.obs;
  RxDouble queueSheetMaxHeight = 500.0.obs;
  RxDouble nowPlayingImageContainerHeight = 400.0.obs;

  RxBool enableVolumeFadeOnPlayPause = true.obs;
  RxBool displayTrackNumberinAlbumPage = true.obs;
  RxBool albumCardTopRightDate = true.obs;
  RxBool forceSquaredTrackThumbnail = false.obs;
  RxBool forceSquaredAlbumThumbnail = false.obs;
  RxBool useAlbumStaggeredGridView = false.obs;
  RxInt albumGridCount = 2.obs;
  RxBool enableBlurEffect = true.obs;
  RxBool enableGlowEffect = true.obs;
  RxBool hourFormat12 = true.obs;
  RxString dateTimeFormat = 'MMM yyyy'.obs;
  RxList<String> trackArtistsSeparators = <String>['&', ',', ';', '//'].obs;
  RxList<String> trackGenresSeparators = <String>['&', ',', ';', '//'].obs;
  Rx<SortType> tracksSort = SortType.title.obs;
  RxBool tracksSortReversed = false.obs;
  Rx<GroupSortType> albumSort = GroupSortType.album.obs;
  RxBool albumSortReversed = false.obs;
  Rx<GroupSortType> artistSort = GroupSortType.artistsList.obs;
  RxBool artistSortReversed = false.obs;
  Rx<GroupSortType> genreSort = GroupSortType.genresList.obs;
  RxBool genreSortReversed = false.obs;
  RxInt indexMinDurationInSec = 5.obs;
  RxInt indexMinFileSizeInB = (100 * 1024).obs;
  RxList<String> trackSearchFilter = ['title', 'artist', 'album'].obs;
  RxList<String> directoriesToScan = kDirectoriesPaths.toList().obs;
  RxList<String> directoriesToExclude = <String>[].obs;
  RxBool preventDuplicatedTracks = false.obs;

  /// Track Items
  RxBool displayThirdRow = true.obs;
  RxBool displayThirdItemInEachRow = false.obs;
  RxString trackTileSeparator = '•'.obs;

  Rx<TrackTileItem> row1Item1 = TrackTileItem.title.obs;
  Rx<TrackTileItem> row1Item2 = TrackTileItem.none.obs;
  Rx<TrackTileItem> row1Item3 = TrackTileItem.none.obs;
  Rx<TrackTileItem> row2Item1 = TrackTileItem.artists.obs;
  Rx<TrackTileItem> row2Item2 = TrackTileItem.none.obs;
  Rx<TrackTileItem> row2Item3 = TrackTileItem.none.obs;
  Rx<TrackTileItem> row3Item1 = TrackTileItem.album.obs;
  Rx<TrackTileItem> row3Item2 = TrackTileItem.year.obs;
  Rx<TrackTileItem> row3Item3 = TrackTileItem.none.obs;
  Rx<TrackTileItem> rightItem1 = TrackTileItem.duration.obs;
  Rx<TrackTileItem> rightItem2 = TrackTileItem.none.obs;
  Rx<TrackTileItem> rightItem3 = TrackTileItem.none.obs;

  SettingsController() {
    themeMode.value = EnumToString.fromString(ThemeMode.values, getString('themeMode') ?? EnumToString.convertToString(themeMode.value))!;
    selectedLibraryTab.value = EnumToString.fromString(LibraryTab.values, getString('selectedLibraryTab') ?? EnumToString.convertToString(selectedLibraryTab.value))!;
    borderRadiusMultiplier.value = getDouble('borderRadiusMultiplier') ?? borderRadiusMultiplier.value;
    fontScaleFactor.value = getDouble('fontScaleFactor') ?? fontScaleFactor.value;
    trackThumbnailSizeinList.value = getDouble('trackThumbnailSizeinList') ?? trackThumbnailSizeinList.value;
    trackListTileHeight.value = getDouble('trackListTileHeight') ?? trackListTileHeight.value;
    albumThumbnailSizeinList.value = getDouble('albumThumbnailSizeinList') ?? albumThumbnailSizeinList.value;
    albumListTileHeight.value = getDouble('albumListTileHeight') ?? albumListTileHeight.value;
    queueSheetMinHeight.value = getDouble('queueSheetMinHeight') ?? queueSheetMinHeight.value;
    queueSheetMaxHeight.value = getDouble('queueSheetMaxHeight') ?? queueSheetMaxHeight.value;
    nowPlayingImageContainerHeight.value = getDouble('nowPlayingImageContainerHeight') ?? nowPlayingImageContainerHeight.value;
    enableVolumeFadeOnPlayPause.value = getBool('enableVolumeFadeOnPlayPause') ?? enableVolumeFadeOnPlayPause.value;
    displayTrackNumberinAlbumPage.value = getBool('displayTrackNumberinAlbumPage') ?? displayTrackNumberinAlbumPage.value;
    albumCardTopRightDate.value = getBool('albumCardTopRightDate') ?? albumCardTopRightDate.value;
    forceSquaredTrackThumbnail.value = getBool('forceSquaredTrackThumbnail') ?? forceSquaredTrackThumbnail.value;
    forceSquaredAlbumThumbnail.value = getBool('forceSquaredAlbumThumbnail') ?? forceSquaredAlbumThumbnail.value;
    useAlbumStaggeredGridView.value = getBool('useAlbumStaggeredGridView') ?? useAlbumStaggeredGridView.value;
    albumGridCount.value = getInt('albumGridCount') ?? albumGridCount.value;
    enableBlurEffect.value = getBool('enableBlurEffect') ?? enableBlurEffect.value;
    enableGlowEffect.value = getBool('enableGlowEffect') ?? enableGlowEffect.value;
    hourFormat12.value = getBool('hourFormat12') ?? hourFormat12.value;
    dateTimeFormat.value = getString('dateTimeFormat') ?? dateTimeFormat.value;
    trackArtistsSeparators.value = getListString('trackArtistsSeparators', ifNull: trackArtistsSeparators.value);
    trackGenresSeparators.value = getListString('trackGenresSeparators', ifNull: trackGenresSeparators.value);
    tracksSort.value = EnumToString.fromString(SortType.values, getString('tracksSort') ?? EnumToString.convertToString(tracksSort.value))!;
    tracksSortReversed.value = getBool('tracksSortReversed') ?? tracksSortReversed.value;
    albumSort.value = EnumToString.fromString(GroupSortType.values, getString('albumSort') ?? EnumToString.convertToString(albumSort.value))!;
    albumSortReversed.value = getBool('albumSortReversed') ?? albumSortReversed.value;
    artistSort.value = EnumToString.fromString(GroupSortType.values, getString('artistSort') ?? EnumToString.convertToString(artistSort.value))!;
    artistSortReversed.value = getBool('artistSortReversed') ?? artistSortReversed.value;
    genreSort.value = EnumToString.fromString(GroupSortType.values, getString('genreSort') ?? EnumToString.convertToString(genreSort.value))!;
    genreSortReversed.value = getBool('genreSortReversed') ?? genreSortReversed.value;
    trackTileSeparator.value = getString('trackTileSeparator') ?? trackTileSeparator.value;
    indexMinDurationInSec.value = getInt('indexMinDurationInSec') ?? indexMinDurationInSec.value;
    indexMinFileSizeInB.value = getInt('indexMinFileSizeInB') ?? indexMinFileSizeInB.value;
    trackSearchFilter.value = getListString('trackSearchFilter', ifNull: trackSearchFilter.value);
    directoriesToScan.value = getListString('directoriesToScan', ifNull: directoriesToScan.value);
    directoriesToExclude.value = getListString('directoriesToExclude', ifNull: directoriesToExclude.value);
    preventDuplicatedTracks.value = getBool('preventDuplicatedTracks') ?? preventDuplicatedTracks.value;

    /// Track Items
    displayThirdRow.value = getBool('displayThirdRow') ?? displayThirdRow.value;
    displayThirdItemInEachRow.value = getBool('displayThirdItemInEachRow') ?? displayThirdItemInEachRow.value;

    row1Item1.value = EnumToString.fromString(TrackTileItem.values, getString('row1Item1') ?? EnumToString.convertToString(row1Item1.value))!;
    row1Item2.value = EnumToString.fromString(TrackTileItem.values, getString('row1Item2') ?? EnumToString.convertToString(row1Item2.value))!;
    row1Item3.value = EnumToString.fromString(TrackTileItem.values, getString('row1Item3') ?? EnumToString.convertToString(row1Item3.value))!;
    row2Item1.value = EnumToString.fromString(TrackTileItem.values, getString('row2Item1') ?? EnumToString.convertToString(row2Item1.value))!;
    row2Item2.value = EnumToString.fromString(TrackTileItem.values, getString('row2Item2') ?? EnumToString.convertToString(row2Item2.value))!;
    row2Item3.value = EnumToString.fromString(TrackTileItem.values, getString('row2Item3') ?? EnumToString.convertToString(row2Item3.value))!;
    row3Item1.value = EnumToString.fromString(TrackTileItem.values, getString('row3Item1') ?? EnumToString.convertToString(row3Item1.value))!;
    row3Item2.value = EnumToString.fromString(TrackTileItem.values, getString('row3Item2') ?? EnumToString.convertToString(row3Item2.value))!;
    row3Item3.value = EnumToString.fromString(TrackTileItem.values, getString('row3Item3') ?? EnumToString.convertToString(row3Item3.value))!;
    rightItem1.value = EnumToString.fromString(TrackTileItem.values, getString('rightItem1') ?? EnumToString.convertToString(rightItem1.value))!;
    rightItem2.value = EnumToString.fromString(TrackTileItem.values, getString('rightItem2') ?? EnumToString.convertToString(rightItem2.value))!;
    rightItem3.value = EnumToString.fromString(TrackTileItem.values, getString('rightItem3') ?? EnumToString.convertToString(rightItem3.value))!;

    update();
  }

  /// Saves a value to the key, if [List]or [Set], then it will add to it.
  void save({
    ThemeMode? themeMode,
    int? searchResultsPlayMode,
    // int? selectedLibraryPageIndex,
    LibraryTab? selectedLibraryTab,
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
    int? albumGridCount,
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
    bool? displayThirdRow,
    bool? displayThirdItemInEachRow,
    String? trackTileSeparator,
    int? indexMinDurationInSec,
    int? indexMinFileSizeInB,
    List<String>? trackSearchFilter,
    List<String>? directoriesToScan,
    List<String>? directoriesToExclude,
    bool? preventDuplicatedTracks,
  }) {
    if (themeMode != null) {
      this.themeMode.value = themeMode;
      setData('themeMode', EnumToString.convertToString(themeMode));
    }
    if (selectedLibraryTab != null) {
      this.selectedLibraryTab.value = selectedLibraryTab;
      setData('selectedLibraryTab', EnumToString.convertToString(selectedLibraryTab));
    }
    if (searchResultsPlayMode != null) {
      this.searchResultsPlayMode.value = searchResultsPlayMode;
      setData('searchResultsPlayMode', searchResultsPlayMode);
    }
    if (borderRadiusMultiplier != null) {
      this.borderRadiusMultiplier.value = borderRadiusMultiplier;
      setData('borderRadiusMultiplier', borderRadiusMultiplier);
    }
    if (fontScaleFactor != null) {
      this.fontScaleFactor.value = fontScaleFactor;
      setData('fontScaleFactor', fontScaleFactor);
    }
    if (trackThumbnailSizeinList != null) {
      this.trackThumbnailSizeinList.value = trackThumbnailSizeinList;
      setData('trackThumbnailSizeinList', trackThumbnailSizeinList);
    }
    if (trackListTileHeight != null) {
      this.trackListTileHeight.value = trackListTileHeight;
      setData('trackListTileHeight', trackListTileHeight);
    }

    if (albumThumbnailSizeinList != null) {
      this.albumThumbnailSizeinList.value = albumThumbnailSizeinList;
      setData('albumThumbnailSizeinList', albumThumbnailSizeinList);
    }
    if (albumListTileHeight != null) {
      this.albumListTileHeight.value = albumListTileHeight;
      setData('albumListTileHeight', albumListTileHeight);
    }
    if (queueSheetMinHeight != null) {
      this.queueSheetMinHeight.value = queueSheetMinHeight;
      setData('queueSheetMinHeight', queueSheetMinHeight);
    }
    if (queueSheetMaxHeight != null) {
      this.queueSheetMaxHeight.value = queueSheetMaxHeight;
      setData('queueSheetMaxHeight', queueSheetMaxHeight);
    }
    if (nowPlayingImageContainerHeight != null) {
      this.nowPlayingImageContainerHeight.value = nowPlayingImageContainerHeight;
      setData('nowPlayingImageContainerHeight', nowPlayingImageContainerHeight);
    }
    if (enableVolumeFadeOnPlayPause != null) {
      this.enableVolumeFadeOnPlayPause.value = enableVolumeFadeOnPlayPause;
      setData('enableVolumeFadeOnPlayPause', enableVolumeFadeOnPlayPause);
    }
    if (displayTrackNumberinAlbumPage != null) {
      this.displayTrackNumberinAlbumPage.value = displayTrackNumberinAlbumPage;
      setData('displayTrackNumberinAlbumPage', displayTrackNumberinAlbumPage);
    }
    if (albumCardTopRightDate != null) {
      this.albumCardTopRightDate.value = albumCardTopRightDate;
      setData('albumCardTopRightDate', albumCardTopRightDate);
    }
    if (forceSquaredTrackThumbnail != null) {
      this.forceSquaredTrackThumbnail.value = forceSquaredTrackThumbnail;
      setData('forceSquaredTrackThumbnail', forceSquaredTrackThumbnail);
    }
    if (forceSquaredAlbumThumbnail != null) {
      this.forceSquaredAlbumThumbnail.value = forceSquaredAlbumThumbnail;
      setData('forceSquaredAlbumThumbnail', forceSquaredAlbumThumbnail);
    }
    if (useAlbumStaggeredGridView != null) {
      this.useAlbumStaggeredGridView.value = useAlbumStaggeredGridView;
      setData('useAlbumStaggeredGridView', useAlbumStaggeredGridView);
    }
    if (albumGridCount != null) {
      this.albumGridCount.value = albumGridCount;
      setData('albumGridCount', albumGridCount);
    }
    if (enableBlurEffect != null) {
      this.enableBlurEffect.value = enableBlurEffect;
      setData('enableBlurEffect', enableBlurEffect);
    }
    if (enableGlowEffect != null) {
      this.enableGlowEffect.value = enableGlowEffect;
      setData('enableGlowEffect', enableGlowEffect);
    }
    if (hourFormat12 != null) {
      this.hourFormat12.value = hourFormat12;
      setData('hourFormat12', hourFormat12);
    }
    if (dateTimeFormat != null) {
      this.dateTimeFormat.value = dateTimeFormat;
      setData('dateTimeFormat', dateTimeFormat);
    }
    if (trackArtistsSeparators != null && !this.trackArtistsSeparators.contains(trackArtistsSeparators[0])) {
      this.trackArtistsSeparators.addAll(trackArtistsSeparators);
      setData('trackArtistsSeparators', List<String>.from(this.trackArtistsSeparators));
    }
    if (trackGenresSeparators != null && !this.trackGenresSeparators.contains(trackGenresSeparators[0])) {
      this.trackGenresSeparators.addAll(trackGenresSeparators);
      setData('trackGenresSeparators', List<String>.from(this.trackGenresSeparators));
    }
    if (tracksSort != null) {
      this.tracksSort.value = tracksSort;
      setData('tracksSort', EnumToString.convertToString(tracksSort));
    }
    if (tracksSortReversed != null) {
      this.tracksSortReversed.value = tracksSortReversed;
      setData('tracksSortReversed', tracksSortReversed);
    }
    if (albumSort != null) {
      this.albumSort.value = albumSort;
      setData('albumSort', EnumToString.convertToString(albumSort));
    }
    if (albumSortReversed != null) {
      this.albumSortReversed.value = albumSortReversed;
      setData('albumSortReversed', albumSortReversed);
    }
    if (artistSort != null) {
      this.artistSort.value = artistSort;
      setData('artistSort', EnumToString.convertToString(artistSort));
    }
    if (artistSortReversed != null) {
      this.artistSortReversed.value = artistSortReversed;
      setData('artistSortReversed', artistSortReversed);
    }
    if (genreSort != null) {
      this.genreSort.value = genreSort;
      setData('genreSort', EnumToString.convertToString(genreSort));
    }
    if (genreSortReversed != null) {
      this.genreSortReversed.value = genreSortReversed;
      setData('genreSortReversed', genreSortReversed);
    }
    if (displayThirdRow != null) {
      this.displayThirdRow.value = displayThirdRow;
      setData('displayThirdRow', displayThirdRow);
    }
    if (displayThirdItemInEachRow != null) {
      this.displayThirdItemInEachRow.value = displayThirdItemInEachRow;
      setData('displayThirdItemInEachRow', displayThirdItemInEachRow);
    }
    if (trackTileSeparator != null) {
      this.trackTileSeparator.value = trackTileSeparator;
      setData('trackTileSeparator', trackTileSeparator);
    }
    if (indexMinDurationInSec != null) {
      this.indexMinDurationInSec.value = indexMinDurationInSec;
      setData('indexMinDurationInSec', indexMinDurationInSec);
    }
    if (indexMinFileSizeInB != null) {
      this.indexMinFileSizeInB.value = indexMinFileSizeInB;
      setData('indexMinFileSizeInB', indexMinFileSizeInB);
    }
    if (trackSearchFilter != null) {
      for (var f in trackSearchFilter) {
        if (!this.trackSearchFilter.contains(f)) {
          this.trackSearchFilter.add(f);
        }
      }

      setData('trackSearchFilter', List<String>.from(this.trackSearchFilter));
    }
    if (directoriesToScan != null) {
      for (var d in directoriesToScan) {
        if (!this.directoriesToScan.contains(d)) {
          this.directoriesToScan.add(d);
        }
      }
      setData('directoriesToScan', List<String>.from(this.directoriesToScan));
    }
    if (directoriesToExclude != null) {
      for (var d in directoriesToExclude) {
        if (!this.directoriesToExclude.contains(d)) {
          this.directoriesToExclude.add(d);
        }
      }
      setData('directoriesToExclude', List<String>.from(this.directoriesToExclude));
    }
    if (preventDuplicatedTracks != null) {
      this.preventDuplicatedTracks.value = preventDuplicatedTracks;
      setData('preventDuplicatedTracks', preventDuplicatedTracks);
    }

    update();
  }

  void removeFromList({
    String? trackArtistsSeparator,
    String? trackGenresSeparator,
    String? trackSearchFilter1,
    List<String>? trackSearchFilterAll,
    String? directoriesToScan1,
    List<String>? directoriesToScanAll,
    String? directoriesToExclude1,
    List<String>? directoriesToExcludeAll,
  }) {
    if (trackArtistsSeparator != null) {
      trackArtistsSeparators.remove(trackArtistsSeparator);
      setData('trackArtistsSeparators', List<String>.from(trackArtistsSeparators));
    }
    if (trackGenresSeparator != null) {
      trackGenresSeparators.remove(trackGenresSeparator);
      setData('trackGenresSeparators', List<String>.from(trackGenresSeparators));
    }
    if (trackSearchFilter1 != null) {
      trackSearchFilter.remove(trackSearchFilter1);
      setData('trackSearchFilter', List<String>.from(trackSearchFilter));
    }
    if (trackSearchFilterAll != null) {
      for (var f in trackSearchFilterAll) {
        if (trackSearchFilter.contains(f)) {
          trackSearchFilter.remove(f);
        }
      }
      setData('trackSearchFilter', List<String>.from(trackSearchFilter));
    }
    if (directoriesToScan1 != null) {
      directoriesToScan.remove(directoriesToScan1);
      setData('directoriesToScan', List<String>.from(directoriesToScan));
    }
    if (directoriesToScanAll != null) {
      for (var f in directoriesToScanAll) {
        if (directoriesToScan.contains(f)) {
          directoriesToScan.remove(f);
        }
      }
      setData('directoriesToScan', List<String>.from(directoriesToScan));
    }
    if (directoriesToExclude1 != null) {
      directoriesToExclude.remove(directoriesToExclude1);
      setData('directoriesToExclude', List<String>.from(directoriesToExclude));
    }
    if (directoriesToExcludeAll != null) {
      for (var f in directoriesToExcludeAll) {
        if (directoriesToExclude.contains(f)) {
          directoriesToExclude.remove(f);
        }
      }
      setData('directoriesToExclude', List<String>.from(directoriesToExclude));
    }
    update();
  }

  void updateTrackItemList(TrackTilePosition p, TrackTileItem i) {
    saveFinal(String key) {
      setData(key, EnumToString.convertToString(i));
    }

    switch (p) {
      case TrackTilePosition.row1Item1:
        row1Item1.value = i;
        saveFinal('row1Item1');
        break;
      case TrackTilePosition.row1Item2:
        row1Item2.value = i;
        saveFinal('row1Item2');
        break;
      case TrackTilePosition.row1Item3:
        row1Item3.value = i;
        saveFinal('row1Item3');
        break;
      case TrackTilePosition.row2Item1:
        row2Item1.value = i;
        saveFinal('row2Item1');
        break;
      case TrackTilePosition.row2Item2:
        row2Item2.value = i;
        saveFinal('row2Item2');
        break;
      case TrackTilePosition.row2Item3:
        row2Item3.value = i;
        saveFinal('row2Item3');
        break;
      case TrackTilePosition.row3Item1:
        row3Item1.value = i;
        saveFinal('row3Item1');
        break;
      case TrackTilePosition.row3Item2:
        row3Item2.value = i;
        saveFinal('row3Item2');
        break;
      case TrackTilePosition.row3Item3:
        row3Item3.value = i;
        saveFinal('row3Item3');
        break;
      case TrackTilePosition.rightItem1:
        rightItem1.value = i;
        saveFinal('rightItem1');
        break;
      case TrackTilePosition.rightItem2:
        rightItem2.value = i;
        saveFinal('rightItem2');
        break;
      case TrackTilePosition.rightItem3:
        rightItem3.value = i;
        saveFinal('rightItem3');
        break;
      default:
        null;
    }
  }

  /// GetStorage functions
  final GetStorage storage = GetStorage();

  void setData(String key, dynamic value) => storage.write(key, value);
  int? getInt(String key) => storage.read(key);
  String? getString(String key) => storage.read(key);
  List<String> getListString(String key, {List<String> ifNull = const []}) => List<String>.from(storage.read(key) ?? ifNull);
  bool? getBool(String key) => storage.read(key);
  double? getDouble(String key) => storage.read(key);
  dynamic getData(String key) => storage.read(key);
  void clearData() async => storage.erase();

  @override
  void onClose() {
    Get.delete();
    super.onClose();
  }
}
