import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:audio_service/audio_service.dart';
import 'package:intl/intl.dart';
import 'package:namico_db_wrapper/namico_db_wrapper.dart';
import 'package:on_audio_query/on_audio_query.dart';

import 'package:namida/class/faudiomodel.dart';
import 'package:namida/class/folder.dart';
import 'package:namida/class/library_group.dart';
import 'package:namida/class/library_item_map.dart';
import 'package:namida/class/progress_percentage.dart';
import 'package:namida/class/split_config.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/directory_index.dart';
import 'package:namida/controller/folders_controller.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/music_web_server/music_web_server_base.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/namida_channel/namida_channel.dart';
import 'package:namida/controller/platform/tags_extractor/tags_extractor.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/settings_search_controller.dart';
import 'package:namida/controller/sync_manager/sync_manager.dart';
import 'package:namida/controller/tagger_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dirs_file_filter.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';
import 'package:namida/ui/widgets/settings/indexer_settings.dart';

part 'indexer_artwork_extract_strategies.dart';
part 'indexer_favourites_sorting.dart';

class Indexer<T extends Track> {
  static Indexer get inst => _instance;
  static final Indexer _instance = Indexer._internal();
  Indexer._internal();

  bool get _defaultUseMediaStore => NamidaFeaturesVisibility.onAudioQueryAvailable && settings.useMediaStore.value;
  bool get _includeVideosAsTracks => settings.includeVideos.value;
  bool get _isArtworkCachingEnabled => settings.cacheArtworks.value;
  bool get isNetworkArtworkCachingEnabled => true;

  Future<void> _clearTracksDBAndReOpen() async {
    await _tracksDBManager.deleteEverything();
  }

  late final _tracksDBManager = DBWrapper.openFromInfo(
    fileInfo: AppPaths.TRACKS_DB_INFO,
    config: const DBConfig(
      createIfNotExist: true,
    ),
  );
  late final _trackStatsDBManager = DBWrapper.openFromInfo(
    fileInfo: AppPaths.TRACKS_STATS_DB_INFO,
    config: const DBConfig(
      createIfNotExist: true,
      // -- somehow the only db having issues with being closed in the important times
      autoDisposeTimerDuration: null,
    ),
  );

  final isIndexing = false.obs;

  late final indexingProgress = ProgressPercentage(_indexingDoneCount, _indexingTotalCount);
  final _indexingDoneCount = 0.obs;
  final _indexingTotalCount = 0.obs;

  final allAudioFiles = <String>{}.obs;
  final networkTracksCount = 0.obs;
  final filteredForSizeDurationTracks = 0.obs;
  final duplicatedTracksLength = 0.obs;
  final tracksExcludedByNoMedia = 0.obs;

  final artworksInStorage = 0.obs;
  // final colorPalettesInStorage = 0.obs;

  final artworksSizeInStorage = 0.obs;

  final mainMapsGroup = LibraryGroup<T>();
  LibraryItemMapRaw<AlbumIdentifierWrapper> get mainMapAlbums => mainMapsGroup.mainMapAlbums;
  LibraryItemMap get mainMapArtists => mainMapsGroup.mainMapArtists;
  LibraryItemMap get mainMapAlbumArtists => mainMapsGroup.mainMapAlbumArtists;
  LibraryItemMap get mainMapComposer => mainMapsGroup.mainMapComposer;
  LibraryItemMap get mainMapGenres => mainMapsGroup.mainMapGenres;
  LibraryItemMap get mainMapStyles => mainMapsGroup.mainMapStyles;
  LibraryItemMap get mainMapLanguages => mainMapsGroup.mainMapLanguages;
  RxMap<Folder, List<T>> get mainMapFoldersTracksAndVideos => mainMapsGroup.mainMapFoldersTracksAndVideos;
  RxMap<Folder, List<T>> get mainMapFoldersTracks => mainMapsGroup.mainMapFoldersTracks;
  RxMap<VideoFolder, List<Video>> get mainMapFoldersVideos => mainMapsGroup.mainMapFoldersVideos;

  LibraryItemMap getArtistMapFor(MediaType type) {
    return switch (type) {
      MediaType.artist => Indexer.inst.mainMapArtists,
      MediaType.albumArtist => Indexer.inst.mainMapAlbumArtists,
      MediaType.composer => Indexer.inst.mainMapComposer,
      _ => Indexer.inst.mainMapArtists,
    };
  }

  LibraryItemMap getGenreMapFor(MediaType type) {
    return switch (type) {
      MediaType.genre => Indexer.inst.mainMapGenres,
      MediaType.style => Indexer.inst.mainMapStyles,
      MediaType.language => Indexer.inst.mainMapLanguages,
      _ => Indexer.inst.mainMapGenres,
    };
  }

  final tracksInfoList = <T>[].obs;

  /// tracks map used for lookup
  var allTracksMappedByPath = <String, TrackExtended>{};
  final trackStatsMap = <Track, TrackStats>{}.obs;

  var allFolderCovers = <Folder, String>{}; // {directoryPath, imagePath}
  var allTracksMappedByYTID = <String, List<T>>{};

  /// Used to prevent duplicated track (by filename).
  final Map<String, bool> _currentFileNamesMap = {};

  late final _audioQuery = OnAudioQuery();

  List<T> recentlyAddedTracksSorted() {
    final alltracks = tracksInfoList.value.toList();
    alltracks.sortByAltsPrecomputed(
      [
        (tr) => tr.toTrackExt().dateModified,
        (tr) => tr.toTrackExt().dateAdded,
      ],
      reverse: true,
    );
    return alltracks;
  }

  String? getFallbackFolderArtworkPath({required Folder folder}) {
    return this.allFolderCovers[folder]; // folder hash already resolves extra/removed path separator
  }

  bool imageObtainedBefore(String imagePath) => _pendingArtworksCompressed[imagePath] != null || _pendingArtworksFullRes[imagePath] != null;

  /// {imagePath: (TrackExtended, id)};
  final _backupMediaStoreIDS = <String, (Track, int)>{};
  static const _kArtworksBytesMapMaxEntries = 60;
  final artworksBytesMap = <String, Uint8List?>{};
  final artworksFilesMap = <String, File?>{};

  void _putArtworkBytes(String key, Uint8List? bytes) {
    final map = artworksBytesMap;
    if (map.length >= _kArtworksBytesMapMaxEntries) map.remove(map.keys.first);
    map[key] = bytes;
  }

  final _pendingArtworksCompressed = <String, Completer<void>>{};
  final _pendingArtworksFullRes = <String, Completer<void>>{};

  Future<FArtwork> getArtwork({
    required String? imagePath,
    Track? track,
    bool checkFileFirst = true,
    required bool compressed,
    int? size,
  }) async {
    if (imagePath == null && track == null) return FArtwork.dummy();

    final strategy = _getArtworkStrategy(
      imagePath: imagePath,
      track: track,
    );

    return await strategy.getArtwork(
      imagePath: imagePath,
      track: track,
      checkFileFirst: checkFileFirst,
      size: size,
      compressed: compressed,
    );
  }

  _ArtworkExtractStrategy _getArtworkStrategy({
    required String? imagePath,
    required Track? track,
  }) {
    // -- network tracks
    if (track != null && track.isNetwork) {
      return _NetworkBasedArtworkExtractStrategy(this);
    }

    // -- media store available
    if (_defaultUseMediaStore && imagePath != null) {
      return _MediaStoreArtworkExtractStrategy(this);
    }

    // -- file based
    return _FileBasedArtworkExtractStrategy(this);
  }

  Future<void> prepareTracksFile({bool startupBoost = false}) async {
    if (startupBoost) {
      final completer = Completer<void>();
      unawaited(_prepareTracksFile(completer));
      return await completer.future;
    } else {
      return await _prepareTracksFile();
    }
  }

  Future<void> _prepareTracksFile([Completer<void>? completer]) async {
    _fetchMediaStoreTracks(); // to fill ids map

    final tracksDBPath = AppPaths.TRACKS_DB_INFO.file.path;
    if (await File(tracksDBPath).exists() || await File(AppPaths.TRACKS_OLD).existsAndValid()) {
      isIndexing.value = true;
      // -- only block load if the track file exists..
      await _readTrackData(completer);
      await sortMediaTracksAndSubListsAfterHistoryPrepared();
      await _sortAll();
      isIndexing.value = false;

      if (tracksInfoList.value.isEmpty) {
        refreshLibraryAndCheckForDiff(forceReIndex: true);
      } else if (settings.refreshOnStartup.value) {
        this.refreshLibraryAndCheckForDiff(allowDeletion: false, showFinishedSnackbar: false);
      } else {
        // main reason is to refresh fallback cover
        this.getAudioFiles();
      }
    } else {
      // -- otherwise it get into normally and start indexing.
      await File(tracksDBPath).create();
      completer?.completeIfWasnt();
      refreshLibraryAndCheckForDiff(forceReIndex: true, useMediaStore: _defaultUseMediaStore);
    }
  }

  void rebuildTracksAfterSplitConfigChanges() => _rederiveAllTracks();

  void rebuildTracksAfterExtractFeatArtistChanges() => _rederiveAllTracks();

  Future<void> _rederiveAllTracks() async {
    final splitConfig = _createSplitConfig();
    allTracksMappedByPath.updateAll((_, trExt) => trExt.rederive(splitConfig));
    await _afterIndexing();
    tracksInfoList.refresh();
  }

  void resortAllAfterSortKeysChange() async {
    SearchSortController.inst.disposeMediaResources(MediaType.track);
    await _afterIndexing();
    tracksInfoList.refresh();
  }

  Future<void> refreshLibraryAndCheckForDiff({
    DirsFileFilterResult? currentFiles,
    bool forceReIndex = false,
    bool? useMediaStore,
    bool allowDeletion = true,
    bool showFinishedSnackbar = true,
  }) async {
    if (isIndexing.value) {
      snackyy(title: lang.note, message: lang.anotherProcessIsRunning);
      return;
    }

    _indexingDoneCount.value = 0;
    _indexingTotalCount.value = 0;
    isIndexing.value = true;
    useMediaStore ??= _defaultUseMediaStore;

    IndexerFilesDiff? differenceStats;

    if (forceReIndex || tracksInfoList.isEmpty) {
      await _fetchAllSongsAndWriteToFile(
        filesDiff: null,
        forceReIndex: true,
        useMediaStore: useMediaStore,
      );
    } else {
      currentFiles ??= await getAudioFilesForRefresh();
      final difference = getPathsDifference(currentFiles);
      differenceStats = allowDeletion ? difference : difference.withoutDeletedPaths();

      await _fetchAllSongsAndWriteToFile(
        filesDiff: differenceStats,
        forceReIndex: false,
        useMediaStore: useMediaStore,
      );
    }

    await _afterIndexing();
    await _tracksDBManager.checkpoint().ignoreError();
    isIndexing.value = false;

    final isEmpty = tracksInfoList.value.isEmpty;
    if (showFinishedSnackbar || isEmpty) {
      if (isEmpty) {
        snackyy(
          title: lang.done,
          message: lang.noTracksFound,
          button: SnackbarButton(
            text: lang.addFolder,
            function: () {
              SettingsSearchController.inst
                  .onResultTap(
                    settingPage: SettingSubpageEnum.indexer,
                    key: IndexerSettingsKeysGlobal.addFolder,
                    context: namida.context!,
                  )
                  .ignoreError();
              const IndexerSettings().promptAddFolderType();
            },
          ),
        );
      } else {
        final msgParts = [lang.finishedUpdatingLibrary];
        if (differenceStats != null) {
          int newFilesLength = 0;
          int deletedFilesLength = 0;
          // -- only show actual stats since filtering can apply to new paths
          // -- eg: there could be 10 new files, but were filtered so it's false to say 10 new files were added

          for (final n in differenceStats.newPaths) {
            if (allTracksMappedByPath.containsKey(n)) {
              newFilesLength++;
            }
          }
          for (final n in differenceStats.deletedPaths) {
            if (!allTracksMappedByPath.containsKey(n)) {
              deletedFilesLength++;
            }
          }
          final modifiedFilesLength = differenceStats.modifiedPaths.length;

          if (newFilesLength == 0 && deletedFilesLength == 0 && modifiedFilesLength == 0) {
            msgParts.add('${lang.local}: ${lang.noChangesFound}');
          } else {
            msgParts.add('${lang.newLabel}: ${newFilesLength.displayFilesKeyword}');
            msgParts.add('${lang.changed}: ${modifiedFilesLength.displayFilesKeyword}');
            msgParts.add('${lang.deleted}/${lang.filtered}: ${deletedFilesLength.displayFilesKeyword}');
          }
          void addIfNonZero(String text, int value) {
            if (value > 0) {
              msgParts.add('$text: $value');
            }
          }

          addIfNonZero(lang.duplicatedTracks, this.duplicatedTracksLength.value);
          addIfNonZero(lang.tracksExcludedByNomedia, this.tracksExcludedByNoMedia.value);
          addIfNonZero(lang.filteredBySizeAndDuration, this.filteredForSizeDurationTracks.value);
        }
        snackyy(title: lang.done, message: msgParts.join('\n'));
      }
    }
  }

  /// Adds all tracks inside [tracksInfoList] to their respective album, artist, etc..
  /// & sorts all media.
  Future<void> _afterIndexing() async {
    final mediaSorters = {for (final e in MediaType.values) e: SearchSortController.inst.getMediaTracksSortingComparables(e)};
    this.mainMapsGroup.fillAll(tracksInfoList.value, (tr) => tr.toTrackExt(), settings.albumIdentifiers.value);
    QueueController.latestPlayedForSourceManager.migrateLegacyAlbumSources();
    this.mainMapsGroup.sortAllSync(mediaSorters, settings.mediaItemsTrackSortingReverse.value, tracksInfoList.value);
    this.mainMapsGroup.refreshAll();
    FoldersController.tracksAndVideos.onMapChanged(mainMapFoldersTracksAndVideos.value);
    FoldersController.tracks.onMapChanged(mainMapFoldersTracks.value);
    FoldersController.videos.onMapChanged(mainMapFoldersVideos.value);
    _refreshMediaTracksSubListsAfterSort(mediaSorters.keys);

    await _sortAll();
  }

  Future<void> sortMediaTracksSubLists(List<MediaType> medias) async {
    final sorters = {for (final e in medias) e: SearchSortController.inst.getMediaTracksSortingComparables(e)};
    final mediaItemsTrackSortingReverse = settings.mediaItemsTrackSortingReverse.value;
    this.mainMapsGroup.sortAllSync(sorters, mediaItemsTrackSortingReverse, tracksInfoList.value);
    _refreshMediaTracksSubListsAfterSort(sorters.keys); // -- vip vro
    this.mainMapsGroup.refreshAll(); // to refresh sublists as well
  }

  void _refreshMediaTracksSubListsAfterSort(Iterable<MediaType> sortedMedias) {
    for (final e in sortedMedias) {
      final fn = switch (e) {
        MediaType.track => SearchSortController.inst.refreshTrackSearchList,
        MediaType.album ||
        MediaType.artist ||
        MediaType.albumArtist ||
        MediaType.composer ||
        MediaType.genre ||
        MediaType.style ||
        MediaType.language => () => SearchSortController.inst.searchMedia(e.toLibraryTab().textSearchController?.text ?? '', e),
        MediaType.folder => FoldersController.tracksAndVideos.refreshAfterSorting,
        MediaType.folderMusic => FoldersController.tracks.refreshAfterSorting,
        MediaType.folderVideo => FoldersController.videos.refreshAfterSorting,
        _ => null,
      };
      fn?.call();
    }
  }

  List<MediaType> _getMediaTypeSortThatDependOnHistory() {
    final requiredToSort = <MediaType>[];
    for (final e in settings.mediaItemsTrackSorting.value.entries) {
      for (final sort in e.value) {
        if (sort.requiresHistory) {
          requiredToSort.add(e.key);
          break;
        }
      }
    }
    return requiredToSort;
  }

  late final _favouritesSorting = _FavouritesSorting<T>(this);

  /// null [tracks] means the favourites were replaced as a whole.
  void onFavouritesChanged(Iterable<T>? tracks) => _favouritesSorting.onChanged(tracks);

  /// [track] keeps its position in lists sorted by favourites until the current page changes.
  void deferFavouriteSorting(T track) => _favouritesSorting.defer(track);

  /// re-sorts media subtracks that depend on history.
  Future<void> sortMediaTracksAndSubListsAfterHistoryPrepared() async {
    if (HistoryController.inst.isHistoryLoaded && this.mainMapsGroup.didFill) {
      final requiredToSort = _getMediaTypeSortThatDependOnHistory();
      await sortMediaTracksSubLists(requiredToSort);

      for (final e in MediaType.values) {
        final sortRequiresHistory = switch (e) {
          MediaType.track => settings.mediaItemsTrackSorting.value[MediaType.track]?.firstOrNull?.requiresHistory ?? false,
          MediaType.album => settings.albumSorts.value.any((e) => e.requiresHistory),
          MediaType.artist || MediaType.albumArtist || MediaType.composer => settings.artistSorts.value.any((e) => e.requiresHistory),
          MediaType.genre || MediaType.style => settings.genreSorts.value.any((e) => e.requiresHistory),
          MediaType.language => settings.languageSorts.value.any((e) => e.requiresHistory),
          MediaType.playlist => settings.playlistSorts.value.any((e) => e.requiresHistory),
          MediaType.folder => settings.mediaItemsTrackSorting.value[MediaType.folder]?.firstOrNull?.requiresHistory ?? false,
          MediaType.folderMusic => settings.mediaItemsTrackSorting.value[MediaType.folderMusic]?.firstOrNull?.requiresHistory ?? false,
          MediaType.folderVideo => settings.mediaItemsTrackSorting.value[MediaType.folderVideo]?.firstOrNull?.requiresHistory ?? false,
          MediaType.mood => false,
          MediaType.tag => false,
          MediaType.rating => false,
        };
        if (sortRequiresHistory) SearchSortController.inst.sortMedia(e);
      }
    }
  }

  Future<void> _sortAll() => SearchSortController.inst.sortAll();

  /// Removes Specific tracks from their corresponding media, useful when updating track metadata or reindexing a track.
  void _removeThisTrackFromAlbumGenreArtistEtc(Track tr) {
    final trExt = tr.toTrackExt();
    void removeAndDeleteEmpty<K>(Map<K, List<Track>> map, K key) {
      final list = map[key];
      if (list != null) {
        list.remove(tr);
        if (list.isEmpty) {
          map.remove(key);
        }
      }
    }

    for (var identifier in trExt.albumsIdentifiersModified) {
      removeAndDeleteEmpty(mainMapAlbums.value, identifier);
    }
    for (var artist in trExt.artistsList) {
      removeAndDeleteEmpty(mainMapArtists.value, artist);
    }
    for (var albumArtist in trExt.albumArtistsList) {
      removeAndDeleteEmpty(mainMapAlbumArtists.value, albumArtist);
    }
    for (var composer in trExt.composersList) {
      removeAndDeleteEmpty(mainMapComposer.value, composer);
    }
    for (var genre in trExt.genresList) {
      removeAndDeleteEmpty(mainMapGenres.value, genre);
    }
    for (var style in trExt.stylesList) {
      removeAndDeleteEmpty(mainMapStyles.value, style);
    }
    for (var language in trExt.languagesList) {
      removeAndDeleteEmpty(mainMapLanguages.value, language);
    }

    tr is Video ? removeAndDeleteEmpty(mainMapFoldersVideos.value, tr.folder) : removeAndDeleteEmpty(mainMapFoldersTracks.value, tr.folder);
    removeAndDeleteEmpty(mainMapFoldersTracksAndVideos.value, tr.folder);

    _currentFileNamesMap.remove(tr.filename);
  }

  void _addTheseTracksToAlbumGenreArtistEtc(Map<TrackExtended, TrackExtended?> tracksMap) {
    final changes = mainMapsGroup.updateTracksSync(tracksMap, settings.albumIdentifiers.value);
    final changedMedias = changes.changedMedias;
    final mediaSorters = {for (final e in changedMedias) e: SearchSortController.inst.getMediaTracksSortingComparables(e)};
    mainMapsGroup.sortChangedSync(changes, mediaSorters, settings.mediaItemsTrackSortingReverse.value);
    for (final e in changedMedias) {
      SearchSortController.inst.sortMedia(e); // main list sorting
    }

    if (changes.hasNewKeys(MediaType.folder)) FoldersController.tracksAndVideos.onMapChanged(mainMapFoldersTracksAndVideos.value);
    if (changes.hasNewKeys(MediaType.folderMusic)) FoldersController.tracks.onMapChanged(mainMapFoldersTracks.value);
    if (changes.hasNewKeys(MediaType.folderVideo)) FoldersController.videos.onMapChanged(mainMapFoldersVideos.value);
  }

  static Future<TrackExtended?> convertServerTagToTrack({
    required String path,
    required String server,
    required FileStatsAdv stats,
    required FAudioModel trackInfo,
    required bool tryExtractingFromFilename,
    int minDur = 0,
    int minSize = 0,
    required TrackExtended? Function() onMinDurTrigger,
    required TrackExtended? Function() onMinSizeTrigger,
    required TrackExtended? Function(String err) onError,
    SplitArtistGenreConfigsWrapper? splittersConfigs,
  }) {
    return Indexer.convertTagToTrack(
      trackPath: path,
      server: server,
      stats: stats,
      trackInfo: trackInfo,
      tryExtractingFromFilename: tryExtractingFromFilename,
      minDur: minDur,
      minSize: minSize,
      onMinDurTrigger: onMinDurTrigger,
      onMinSizeTrigger: onMinSizeTrigger,
      onError: onError,
      splittersConfigs: splittersConfigs,
    );
  }

  static Future<TrackExtended?> convertTagToTrack({
    required String trackPath,
    String? server,
    FileStatsAdv? stats,
    required FAudioModel trackInfo,
    required bool tryExtractingFromFilename,
    int minDur = 0,
    int minSize = 0,
    required TrackExtended? Function() onMinDurTrigger,
    required TrackExtended? Function() onMinSizeTrigger,
    required TrackExtended? Function(String err) onError,
    SplitArtistGenreConfigsWrapper? splittersConfigs,
  }) async {
    // -- most methods dont throw, except for timeout
    try {
      // -- returns null early depending on size [byte] or duration [seconds]
      FileStatsAdv? fileStat;
      try {
        fileStat = stats ?? FileStatsAdv.fromFileStat(await File(trackPath).stat());
        if (minSize > 0 && (fileStat.size ?? 0) < minSize) {
          return onMinSizeTrigger();
        }
      } catch (_) {}

      if (trackInfo.hasError && !tryExtractingFromFilename) return null;

      final info = trackInfo.hasError ? null : trackInfo;
      final durationInMS = info?.durationMS ?? 0;
      if (minDur != 0 && durationInMS != 0 && durationInMS < minDur * 1000) {
        return onMinDurTrigger();
      }

      final initialTrack = TrackExtended(
        title: UnknownTags.TITLE,
        originalArtist: UnknownTags.ARTIST,
        artistsList: const [],
        originalAlbum: UnknownTags.ALBUM,
        albumsList: const [],
        albumArtist: UnknownTags.ALBUMARTIST,
        albumArtistsList: const [],
        originalGenre: UnknownTags.GENRE,
        genresList: const [],
        originalStyle: UnknownTags.STYLE,
        stylesList: const [],
        composer: UnknownTags.COMPOSER,
        composersList: const [],
        originalMood: UnknownTags.MOOD,
        moodList: const [],
        trackNo: 0,
        trackTo: 0,
        durationMS: durationInMS,
        chapters: null,
        year: 0,
        yearText: '',
        size: fileStat?.size ?? 0,
        dateAdded: fileStat?.creationDateMS ?? 0,
        dateModified: fileStat?.modifiedMS ?? 0,
        path: trackPath,
        comment: '',
        description: '',
        synopsis: '',
        bitrate: info?.bitRate ?? 0,
        sampleRate: info?.sampleRate ?? 0,
        bits: info?.bits ?? 0,
        isLossless: info?.isLossless,
        format: info?.format ?? '',
        channels: info?.channels ?? '',
        discNo: 0,
        discTo: 0,
        language: '',
        languagesList: const [],
        lyrics: '',
        label: '',
        releaseType: '',
        bpm: 0,
        musicalKey: '',
        rating: 0.0,
        originalTags: null,
        tagsList: const [],
        gainData: null,
        sortInfo: null,
        extraTags: null,
        albumsIdentifiersWrappers: const [],
        isVideo: trackPath.isVideo(),
        hashKey: null,
        server: server,
      );

      final tags = info?.tags ?? _emptyTags;
      final splitConfig = splittersConfigs ?? _createSplitConfig();
      return initialTrack.copyWithTag(
        tag: tags,
        splittersConfigs: splitConfig,
        generatePathHash: TagsExtractor.defaultUniqueArtworkHash,
      );
    } catch (e) {
      return onError(e.toString());
    }
  }

  static final _emptyTags = FTags.edit(path: '', artwork: FArtwork.dummy());

  Future<TrackExtended?> getTrackInfo({
    required String trackPath,
    int minDur = 0,
    int minSize = 0,
    required TrackExtended? Function() onMinDurTrigger,
    required TrackExtended? Function() onMinSizeTrigger,
    bool tryExtractingFromFilename = true,
    required bool isNetwork,
    String? networkId,
  }) async {
    final res = await NamidaTaggerController.inst.extractMetadata(
      trackPath: trackPath,
      extractArtwork: false,
      overrideArtwork: false,
      isVideo: trackPath.isVideo(),
      isNetwork: isNetwork,
      networkId: networkId,
    );
    if (res.hasError) return null;
    return convertTagToTrack(
      trackPath: trackPath,
      trackInfo: res,
      tryExtractingFromFilename: tryExtractingFromFilename,
      minDur: minDur,
      minSize: minSize,
      onMinDurTrigger: onMinDurTrigger,
      onMinSizeTrigger: onMinSizeTrigger,
      onError: (_) => null,
    );
  }

  void _addTrackToLists(TrackExtended trackExt, FArtwork? artwork) {
    final tr = trackExt.asTrack() as T;
    final alreadyExists = allTracksMappedByPath.containsKey(tr.path);
    allTracksMappedByPath[tr.path] = trackExt;
    unawaited(_tracksDBManager.put(tr.path, trackExt.toJsonWithoutPath()));
    _currentFileNamesMap[trackExt.path.getFilename] = true;

    if (!alreadyExists) {
      tracksInfoList.value.add(tr);
      if (tr.isNetwork) networkTracksCount.value++;
      SearchSortController.inst.onTrackIndexed(tr);
      allTracksMappedByYTID.addForce(trackExt.youtubeID, tr);
      _scheduleTracksListsRefresh();
    } else {
      final list = allTracksMappedByYTID[trackExt.youtubeID] ??= [];
      if (!list.contains(tr)) {
        list.add(tr);
      }
    }

    if (artwork != null && artwork.file != null) {
      artworksInStorage.value++;
      if (artwork.size != null) artworksSizeInStorage.value += artwork.size!;
    }
  }

  Timer? _tracksListsRefreshTimer;

  // -- each refresh rebuilds every visible tracks list, so rapid adds (indexing) share one
  void _scheduleTracksListsRefresh() {
    _tracksListsRefreshTimer ??= Timer(
      const Duration(milliseconds: 300),
      () {
        _tracksListsRefreshTimer = null;
        tracksInfoList.refresh();
        SearchSortController.inst.trackSearchList.refresh();
      },
    );
  }

  /// Removes track entries from related lists, this doesNOT delete tracks from system or remove stats entries
  Future<void> removeTracksFromLibrary(Iterable<Selectable> tracksToRemove, {required bool isFromDelete}) async {
    if (tracksToRemove.isEmpty) return;
    IOSink? recentlyDeletedFileWrite;
    if (isFromDelete) {
      final recentlyDeletedFile = File("${AppDirs.RECENTLY_DELETED}${DateFormat('yyyy_MM_dd HH_mm_ss').format(DateTime.now())} - (${tracksToRemove.length}).txt");
      recentlyDeletedFileWrite = recentlyDeletedFile.openWrite(mode: FileMode.writeOnlyAppend);
    }
    final tracksToRemoveCopy = tracksToRemove.toFixedList();
    int networkTracksRemoved = 0;
    for (final trS in tracksToRemoveCopy) {
      final tr = trS.track;
      recentlyDeletedFileWrite?.writeln(tr.path);
      _removeThisTrackFromAlbumGenreArtistEtc(tr);
      allTracksMappedByYTID.remove(tr.youtubeID);
      final didRemove = tracksInfoList.value.remove(tr);
      if (didRemove && tr.isNetwork) networkTracksRemoved++;
      SearchSortController.inst.trackSearchList.value.remove(tr);
      SearchSortController.inst.trackSearchTemp.value.remove(tr);
      SearchSortController.inst.trackSearchTempLessRelevant.value.remove(tr);
      allTracksMappedByPath.remove(tr.path);
      unawaited(_tracksDBManager.delete(tr.path));
      TrackTileManager.rebuildTrackInfo(tr);
      if (tr.isPhysical) this.scanMediaStore(tr.path);
    }

    this.networkTracksCount.value -= networkTracksRemoved;
    this.tracksInfoList.refresh();
    this.mainMapsGroup.refreshAll();
    SearchSortController.inst.trackSearchList.refresh();
    SearchSortController.inst.trackSearchTemp.refresh();
    SearchSortController.inst.trackSearchTempLessRelevant.refresh();
    FoldersController.tracksAndVideos.currentFolder.refresh();
    FoldersController.tracks.currentFolder.refresh();
    FoldersController.videos.currentFolder.refresh();
    recentlyDeletedFileWrite?.flush().then((_) => recentlyDeletedFileWrite?.close());

    SearchSortController.inst.refreshPortsIfNecessary();
  }

  Future<void> reindexTracks({
    required List<PhysicalMedia> tracks,
    bool updateArtwork = false,
    required void Function(bool didExtract) onProgress,
    required void Function(int tracksLength) onFinish,
    bool tryExtractingFromFilename = true,
  }) async {
    final tracksReal = <Track>[];
    final tracksRealPaths = <String>[];
    final tracksMissing = <Track>[];
    final finalNewOldTracks = <TrackExtended, TrackExtended?>{};
    final tracksExistence = await tracks.mapConcurrent((s) async {
      try {
        return await s.track.exists();
      } catch (_) {
        return false;
      }
    });
    for (int i = 0; i < tracks.length; i++) {
      final tr = tracks[i].track;
      if (tracksExistence[i]) {
        tracksReal.add(tr);
        tracksRealPaths.add(tr.path);
      } else {
        tracksMissing.add(tr);
      }
      TrackTileManager.rebuildTrackInfo(tr);
    }

    if (updateArtwork) {
      Indexer.clearMemoryImageCache();
    }

    for (var _ in tracksMissing) {
      onProgress(false);
    }

    final keyWrapper = ExtractingPathKey.create();
    final stream = await NamidaTaggerController.inst.extractMetadataAsStream(
      paths: tracksRealPaths,
      keyWrapper: keyWrapper,
      extractArtwork: updateArtwork,
      overrideArtwork: updateArtwork,
      isNetwork: false,
    );
    final splitConfigs = _createSplitConfig();
    final extracted = <(TrackExtended, FArtwork)>[];
    await for (final item in stream) {
      if (item.hasError) {
        onProgress(false);
        continue;
      }
      final trext = await convertTagToTrack(
        trackPath: item.tags.path,
        trackInfo: item,
        tryExtractingFromFilename: tryExtractingFromFilename,
        onMinDurTrigger: () => null,
        onMinSizeTrigger: () => null,
        onError: (_) => null,
        splittersConfigs: splitConfigs,
      );
      if (trext != null) extracted.add((trext, item.tags.artwork));
      onProgress(true);
    }
    // -- after the last await, so a track listed meanwhile by a library refresh updates as an edit
    for (final (trext, artwork) in extracted) {
      final oldTr = allTracksMappedByPath[trext.path];
      if (oldTr != null) allTracksMappedByYTID.remove(oldTr.youtubeID);
      // _removeThisTrackFromAlbumGenreArtistEtc(tr);
      finalNewOldTracks[trext] = oldTr;
      _addTrackToLists(trext, artwork);
    }

    _addTheseTracksToAlbumGenreArtistEtc(finalNewOldTracks);
    Player.inst.refreshNotification();
    _sortAndRefreshTracks();
    onFinish(finalNewOldTracks.length);

    SearchSortController.inst.refreshPortsIfNecessary();
  }

  Future<void> updateTrackMetadata({
    required Map<T, TrackExtended> tracksMap,
    bool artworkWasEdited = true,
  }) async {
    final newTracks = <T>[];

    if (artworkWasEdited) {
      Indexer.clearMemoryImageCache();
    }

    final finalNewOldTracks = <TrackExtended, TrackExtended?>{};

    for (final e in tracksMap.entries) {
      final ot = e.key;
      finalNewOldTracks[e.value] = ot.toTrackExtOrNull();
      final nt = e.value.asTrack() as T;
      newTracks.add(nt);
      allTracksMappedByPath[ot.path] = e.value;
      unawaited(_tracksDBManager.put(ot.path, e.value.toJsonWithoutPath()));
      allTracksMappedByYTID.addForce(e.value.youtubeID, ot);
      // _currentFileNamesMap.remove(ot.filename); // same path alr
      // _currentFileNamesMap[nt.filename] = true; // --^
      TrackTileManager.rebuildTrackInfo(ot);

      if (artworkWasEdited) {
        // artwork extraction is not our business
        CurrentColor.inst.reExtractTrackColorPalette(track: ot, newNC: null, imagePath: ot.pathToImage);
      }
    }
    _addTheseTracksToAlbumGenreArtistEtc(finalNewOldTracks);
    _sortAndRefreshTracks();
    tracksInfoList.refresh();

    SearchSortController.inst.refreshPortsIfNecessary();
    final globalSearchText = ScrollSearchController.inst.searchTextEditingController.text;
    if (globalSearchText.isNotEmpty) SearchSortController.inst.searchAll(globalSearchText);
  }

  Future<T?> convertPathToTracksAndAddToListsSingle(String trackPath) async {
    final infoInLib = allTracksMappedByPath[trackPath];
    if (infoInLib != null) {
      return infoInLib.asTrack() as T;
    }

    final splitConfig = _createSplitConfig();

    Future<TrackExtended?> extractFunction(FAudioModel item) => convertTagToTrack(
      trackPath: item.tags.path,
      trackInfo: item,
      tryExtractingFromFilename: true,
      onMinDurTrigger: () => null,
      onMinSizeTrigger: () => null,
      onError: (_) => null,
      splittersConfigs: splitConfig,
    );

    final model = await NamidaTaggerController.inst.extractMetadata(
      trackPath: trackPath,
      extractArtwork: null,
      isVideo: trackPath.isVideo(),
      isNetwork: false,
    );
    final trext = await extractFunction(model);
    if (trext != null) {
      final addedMeanwhile = allTracksMappedByPath[trext.path];
      _addTrackToLists(trext, model.tags.artwork);
      _addTheseTracksToAlbumGenreArtistEtc({trext: addedMeanwhile});
      // _sortAndRefreshTracks();
      SearchSortController.inst.refreshPortsIfNecessary();
      return trext.asTrack() as T;
    }

    return null;
  }

  Future<List<T>> convertPathsToTracksAndAddToLists(Iterable<String> tracksPathPre) async {
    final finalTracks = <T>[];
    final tracksToExtract = <String>[];
    final finalNewOldTracks = <TrackExtended, TrackExtended?>{};

    final orderLookup = <String, int>{};
    void onPath(String path) {
      if (orderLookup.containsKey(path)) return;
      orderLookup[path] = orderLookup.length;
      final infoInLib = allTracksMappedByPath[path];
      if (infoInLib != null) {
        finalTracks.add(infoInLib.asTrack() as T);
      } else {
        tracksToExtract.add(path);
      }
    }

    final resolvedPaths = await tracksPathPre.mapConcurrent(
      (path) async {
        final isDir = await Directory(path).exists().ignoreError() ?? false;
        if (!isDir) return <String>[path];
        final files = await Directory(path).listAllIsolate(recursive: true).ignoreError() ?? [];
        return files.whereType<File>().map((f) => f.path).where(NamidaFileExtensionsWrapper.audioAndVideo.isPathValid).toFixedList();
      },
      concurrency: 4, // -- each directory listing spawns an isolate
    );
    for (final paths in resolvedPaths) {
      for (final path in paths) {
        onPath(path);
      }
    }

    if (tracksToExtract.isNotEmpty) {
      final splitConfig = _createSplitConfig();

      Future<TrackExtended?> extractFunction(FAudioModel item) => convertTagToTrack(
        trackPath: item.tags.path,
        trackInfo: item,
        tryExtractingFromFilename: true,
        onMinDurTrigger: () => null,
        onMinSizeTrigger: () => null,
        onError: (_) => null,
        splittersConfigs: splitConfig,
      );

      final keyWrapper = ExtractingPathKey.create();
      final stream = await NamidaTaggerController.inst.extractMetadataAsStream(
        paths: tracksToExtract,
        extractArtwork: null,
        keyWrapper: keyWrapper,
        isNetwork: false,
      );
      final extracted = <(TrackExtended, FArtwork)>[];
      await for (final item in stream) {
        final p = item.tags.path;
        final obj = Track.orVideo(p);
        finalTracks.add(obj as T);
        final trext = await extractFunction(item);
        if (trext != null) extracted.add((trext, item.tags.artwork));
      }
      // -- after the last await, so a path added meanwhile by another call or the library load updates as an edit
      for (final (trext, artwork) in extracted) {
        finalNewOldTracks[trext] = allTracksMappedByPath[trext.path];
        _addTrackToLists(trext, artwork);
      }
    }

    _addTheseTracksToAlbumGenreArtistEtc(finalNewOldTracks);
    _sortAndRefreshTracks();

    finalTracks.sortBy((e) => orderLookup[e.path] ?? 0);

    SearchSortController.inst.refreshPortsIfNecessary();

    return finalTracks;
  }

  void _sortAndRefreshTracks() {
    Player.inst.refreshRxVariables();
    Player.inst.refreshNotification();
    SearchSortController.inst.searchAll(ScrollSearchController.inst.searchTextEditingController.text);
    SearchSortController.inst.sortMedia(MediaType.track);
    this.mainMapsGroup.refreshAll();
  }

  Future<void> _clearLists() async {
    artworksInStorage.value = 0;
    artworksSizeInStorage.value = 0;
    tracksInfoList.clear();
    networkTracksCount.value = 0;
    allTracksMappedByPath.clear();
    allTracksMappedByYTID.clear();
    _currentFileNamesMap.clear();
    await _clearTracksDBAndReOpen();

    SearchSortController.inst.sortMedia(MediaType.track);
    SearchSortController.inst.refreshPortsIfNecessary();
  }

  void _resetCounters() {
    filteredForSizeDurationTracks.value = 0;
    duplicatedTracksLength.value = 0;
    tracksExcludedByNoMedia.value = 0;
  }

  /// Removes deleted paths of [filesDiff], fetches its new paths and re-fetches the modified ones.
  ///
  /// [bypassAllChecks] will bypass `duration`, `size` & similar filenames checks.
  ///
  /// Setting [forceReIndex] to `true` will require u to call [_afterIndexing],
  /// otherwise use [_addTheseTracksToAlbumGenreArtistEtc] with changed tracks only.
  Future<void> _fetchAllSongsAndWriteToFile({
    required IndexerFilesDiff? filesDiff,
    required bool forceReIndex,
    required bool useMediaStore,
  }) async {
    _resetCounters();
    final serversFetchQueue = _startServersTracksCountFetch();

    if (forceReIndex) {
      await _clearLists();
      if (!useMediaStore) {
        final currentFiles = await _listAudioFiles(withStats: true);
        filesDiff = getPathsDifference(currentFiles);
      }
    }

    final audioFiles = filesDiff?.newPaths ?? const <String>{};
    final modifiedFiles = filesDiff?.modifiedPaths ?? const <String>{};
    final deletedPaths = filesDiff?.deletedPaths ?? const <String>{};
    final filesStats = filesDiff?.stats;

    printy("Audio Files New: ${audioFiles.length}");
    printy("Audio Files Modified: ${modifiedFiles.length}");
    printy("Audio Files Deleted: ${deletedPaths.length}");

    if (deletedPaths.isNotEmpty) {
      tracksInfoList.removeWhere((tr) {
        final remove = deletedPaths.contains(tr.path);
        if (remove) unawaited(_tracksDBManager.delete(tr.path));
        return remove;
      });
    }

    final minDur = settings.indexMinDurationInSec.value; // Seconds
    final minSize = settings.indexMinFileSizeInB.value; // bytes
    final prevDuplicated = settings.preventDuplicatedTracks.value;
    if (useMediaStore) {
      final trs = await _fetchMediaStoreTracks();
      tracksInfoList.clear();
      networkTracksCount.value = 0;
      allTracksMappedByPath.clear();
      _clearTracksDBAndReOpen();
      allTracksMappedByYTID.clear();
      _currentFileNamesMap.clear();
      for (var e in trs) {
        _addTrackToLists(e, null);
      }
    } else {
      // NamidaTaggerController.inst.currentPathsBeingExtracted.clear();
      final audioFilesWithoutDuplicates = <String>[];
      if (prevDuplicated) {
        /// skip duplicated tracks according to filename
        for (final trackPath in audioFiles) {
          if (_currentFileNamesMap.containsKey(trackPath.getFilename)) {
            duplicatedTracksLength.value++;
          } else {
            audioFilesWithoutDuplicates.add(trackPath);
          }
        }
      }

      final finalAudios = prevDuplicated ? audioFilesWithoutDuplicates : audioFiles.toList();
      final filesToExtractCount = finalAudios.length + modifiedFiles.length;
      _indexingTotalCount.value += filesToExtractCount;
      final keyWrapper = ExtractingPathKey.create();

      // -- the extractor reads on its own pool of native threads
      Future<void> extractAll(List<String> paths, {required bool isModified}) async {
        if (paths.isEmpty) return;

        final splittersConfigs = _createSplitConfig();
        Future<TrackExtended?> extractFunction(FAudioModel item) => convertTagToTrack(
          trackPath: item.tags.path,
          stats: filesStats?[item.tags.path],
          trackInfo: item,
          tryExtractingFromFilename: true,
          minDur: minDur,
          minSize: minSize,
          onMinDurTrigger: () {
            filteredForSizeDurationTracks.value++;
            return null;
          },
          onMinSizeTrigger: () {
            filteredForSizeDurationTracks.value++;
            return null;
          },
          onError: (_) => null,
          splittersConfigs: splittersConfigs,
        );

        final stream = await NamidaTaggerController.inst.extractMetadataAsStream(
          paths: paths,
          keyWrapper: keyWrapper,
          extractArtwork: null,
          overrideArtwork: isModified,
          isNetwork: false,
        );

        await for (final item in stream) {
          final trext = await extractFunction(item);
          _indexingDoneCount.value++;
          if (trext == null) continue;
          if (isModified) {
            final tr = trext.asTrack();
            allTracksMappedByYTID[tr.youtubeID]?.remove(tr);
          }
          _addTrackToLists(trext, item.tags.artwork);
        }
      }

      await extractAll(finalAudios, isModified: false);
      if (modifiedFiles.isNotEmpty) {
        Indexer.clearMemoryImageCache();
        final modifiedAudios = modifiedFiles.toList();
        await extractAll(modifiedAudios, isModified: true);
      }
    }

    final networkTrackMapsToRemove = await _addServerTracksIfAvailable(serversFetchQueue, forceReIndex: forceReIndex).toList();

    /// doing some checks to remove unqualified tracks.
    /// removes tracks after changing `duration` or `size`.
    int networkTracksRemoved = 0;
    tracksInfoList.removeWhere((tr) {
      final remove = networkTrackMapsToRemove.any((map) => map.containsKey(tr.path)) || (tr.durationMS != 0 && tr.durationMS < minDur * 1000) || tr.size < minSize;
      if (remove) {
        if (tr.isNetwork) networkTracksRemoved++;
        allTracksMappedByPath.remove(tr.path);
        allTracksMappedByYTID.remove(tr.youtubeID);
        _currentFileNamesMap.remove(tr.path.getFilename);
        unawaited(_tracksDBManager.delete(tr.path));
      }
      return remove;
    });

    /// removes duplicated tracks after a refresh
    if (prevDuplicated) {
      final uniquedSet = <String>{};
      final lengthBefore = tracksInfoList.value.length;
      tracksInfoList.value.retainWhere((e) {
        final keep = uniquedSet.add(e.filename);
        if (!keep) {
          if (e.isNetwork) networkTracksRemoved++;
          unawaited(_tracksDBManager.delete(e.path));
        }
        return keep;
      });
      final lengthAfter = tracksInfoList.value.length;
      final removedNumber = lengthBefore - lengthAfter;
      duplicatedTracksLength.value = removedNumber;
    }

    networkTracksCount.value -= networkTracksRemoved;

    printy("FINAL: ${tracksInfoList.length}");

    _sortAndRefreshTracks();
    Indexer.createDefaultNamidaArtworkIfRequired();
    TrackTileManager.onTrackItemPropChange();
    SearchSortController.inst.refreshPortsIfNecessary();
  }

  List<_ServerTracksFetchInfo> _startServersTracksCountFetch() {
    final serversFetchQueue = <_ServerTracksFetchInfo>[];
    for (final dir in settings.directoriesToScan.value) {
      if (dir is! DirectoryIndexServer) continue;
      final server = dir.toWebServer();
      if (server == null) continue;
      final tracksCountFuture = _fetchServerTracksCount(server);
      final fetchInfo = _ServerTracksFetchInfo(
        dir: dir,
        server: server,
        tracksCount: tracksCountFuture,
      );
      serversFetchQueue.add(fetchInfo);
    }
    return serversFetchQueue;
  }

  Future<int> _fetchServerTracksCount(MusicWebServer server) async {
    int? tracksCount;
    try {
      tracksCount = await server.prepareTracksCount();
    } catch (_) {}
    if (tracksCount == null) return 0;
    _indexingTotalCount.value += tracksCount;
    return tracksCount;
  }

  /// Streams Maps of tracks that should be deleted, cuz they no longer exist on the server
  Stream<Map<String, int>> _addServerTracksIfAvailable(List<_ServerTracksFetchInfo> serversFetchQueue, {required bool forceReIndex}) async* {
    bool didRefreshSearchList = false;

    final tracksByServer = _getTracksGroupedByServer();
    final configuredServers = <String>{};
    final importServerPlaylists = settings.importServerPlaylists.value;
    final playlistsImportQueue = <_RemotePlaylistImportInfo>[];

    for (final fetchInfo in serversFetchQueue) {
      final server = fetchInfo.server;
      final dbKey = fetchInfo.dir.toDbKey();
      configuredServers.add(dbKey);

      if (!didRefreshSearchList) {
        didRefreshSearchList = true;
        _refreshMediaTracksSubListsAfterSort([MediaType.track]);
      }

      final serverTracksInLibrary = tracksByServer[dbKey] ??= <String, int>{};

      final tracksCount = await fetchInfo.tracksCount;
      int tracksCounted = 0;

      await server.fetchAllMusicAndProcess(
        serverTracksInLibrary,
        (trExt) {
          _addTrackToLists(trExt, null);
          serverTracksInLibrary.remove(trExt.path); // still exists
          if (tracksCounted < tracksCount) {
            tracksCounted++;
            _indexingDoneCount.value++;
          }
        },
        forceReIndex: forceReIndex,
      );

      final tracksUncounted = tracksCount - tracksCounted;
      _indexingDoneCount.value += tracksUncounted;

      if (importServerPlaylists) {
        final dbKeyCleaned = DirectoryIndexServer.parseWithoutLibraryIdAndCleanTry(dbKey);
        playlistsImportQueue.add(
          _RemotePlaylistImportInfo(
            server: server,
            dbKey: dbKey,
            serverKey: dbKeyCleaned ?? dbKey,
          ),
        );
      }

      // -- now without the tracks that was seen again on server
      yield serverTracksInLibrary;
    }

    // -- remove tracks from servers that no longer exist
    for (final entry in tracksByServer.entries) {
      if (!configuredServers.contains(entry.key)) {
        yield entry.value;
      }
    }

    // -- import playlists after all music is fetched
    _processServerPlaylistsImportQueue(
      playlistsImportQueue: playlistsImportQueue,
      configuredServers: configuredServers,
      tracksByServer: tracksByServer,
    ).whenComplete(
      () {
        // -- remove imported playlists of servers that no longer exist (or all if disabled)
        final configuredServersIdentities = importServerPlaylists ? configuredServers.map(DirectoryIndexServer.parseWithoutLibraryIdAndCleanTry).toSet() : null;
        PlaylistController.inst.removeServerPlaylists(
          keepTest: configuredServersIdentities?.contains,
        );
      },
    );
  }

  // -- same logic of what's in _addServerTracksIfAvailable,
  // -- but there its a lil more performant (reuses some values & has tracksByServer)
  Future<void> refreshServerPlaylists({String? forThisServerKey}) async {
    if (!settings.importServerPlaylists.value) return;

    final playlistsImportQueue = <_RemotePlaylistImportInfo>[];
    final configuredServers = <String>{};
    for (final dir in settings.directoriesToScan.value) {
      if (dir is DirectoryIndexServer) {
        final dbKey = dir.toDbKey();
        final serverKey = DirectoryIndexServer.parseWithoutLibraryIdAndCleanTry(dbKey);
        if (forThisServerKey != null && serverKey != forThisServerKey) continue;
        final server = dir.toWebServer();
        if (server != null) {
          configuredServers.add(dbKey);
          playlistsImportQueue.add(
            _RemotePlaylistImportInfo(
              server: server,
              dbKey: dbKey,
              serverKey: serverKey ?? dbKey,
            ),
          );
        }
      }
    }
    return _processServerPlaylistsImportQueue(
      playlistsImportQueue: playlistsImportQueue,
      configuredServers: configuredServers,
      tracksByServer: const {},
    );
  }

  var _serverPlaylistsImportLock = Future<void>.value();

  Future<void> _processServerPlaylistsImportQueue({
    required List<_RemotePlaylistImportInfo> playlistsImportQueue,
    required Set<String> configuredServers,
    required Map<String, Map<String, int>> tracksByServer,
  }) async {
    if (playlistsImportQueue.isEmpty) return;

    Future<void> execute() async {
      Map<String, Map<String, String>>? mediaIdsToPathsPerServer;
      if (playlistsImportQueue.any((item) => item.dbKey != item.serverKey)) {
        mediaIdsToPathsPerServer = _getServerTracksPathsGroupedByMediaId(configuredServers);
      }
      // -- to prevent fetching from same server with different library id
      final processedServers = <String>{};
      for (final item in playlistsImportQueue) {
        final serverKey = item.serverKey;
        if (!processedServers.contains(serverKey)) {
          final success = await _importServerPlaylists(
            item.server,
            serverKey,
            mediaIdsToPaths: mediaIdsToPathsPerServer?[serverKey],
            tracksByServer: tracksByServer,
          );
          if (success) processedServers.add(serverKey);
        }
      }
    }

    final future = _serverPlaylistsImportLock.then((_) => execute());
    _serverPlaylistsImportLock = future.catchError((_) {});
    return future;
  }

  Future<bool> _importServerPlaylists(
    MusicWebServer server,
    String serverKey, {
    required Map<String, String>? mediaIdsToPaths,
    required Map<String, Map<String, int>> tracksByServer,
  }) async {
    await PlaylistController.inst.waitForPlaylistsLoad;
    final knownModifiedDates = PlaylistController.inst.getServerPlaylistsModifiedDates(serverKey);
    final serverPlaylists = await server.fetchPlaylists(
      knownChangedMS: (remoteId) => knownModifiedDates[remoteId],
    );
    if (serverPlaylists == null) return false;

    Track resolveTrack(TrackExtended trExt) {
      // -- prefer already indexed track, cuz this one coming from playlist request, might be missing anything idk
      final existingPath = mediaIdsToPaths?[trExt.hashKey];
      if (existingPath != null && existingPath != trExt.path) {
        final existingTrExt = allTracksMappedByPath[existingPath];
        if (existingTrExt != null) return existingTrExt.asTrack();
      }
      return trExt.asTrack();
    }

    for (final spl in serverPlaylists) {
      final plTracks = spl.tracks;
      if (plTracks != null) {
        for (final trExt in plTracks) {
          final path = resolveTrack(trExt).path;
          if (path == trExt.path && !allTracksMappedByPath.containsKey(path)) {
            _addTrackToLists(trExt, null);
          }
          // -- remove from tracksByServer means keep in library, see _addServerTracksIfAvailable it returns paths to remove
          final trackServer = allTracksMappedByPath[path]?.server ?? trExt.server;
          if (trackServer != null) tracksByServer[trackServer]?.remove(path);
        }
      }
    }

    await PlaylistController.inst.updateServerPlaylists(
      serverKey,
      serverPlaylists,
      server: server,
      resolveTrack: resolveTrack,
    );

    return true;
  }

  Map<String, Map<String, String>> _getServerTracksPathsGroupedByMediaId(Set<String> configuredServers) {
    final map = <String, Map<String, String>>{};
    final identityKeysCache = <String, String?>{};
    for (final trExt in allTracksMappedByPath.values) {
      final server = trExt.server;
      final mediaId = trExt.hashKey;
      if (server != null && server.isNotEmpty && mediaId != null && mediaId.isNotEmpty && configuredServers.contains(server)) {
        final identityKey = identityKeysCache[server] ??= DirectoryIndexServer.parseWithoutLibraryIdAndCleanTry(server);
        if (identityKey != null) {
          (map[identityKey] ??= <String, String>{})[mediaId] = trExt.path;
        }
      }
    }
    return map;
  }

  Map<String, Map<String, int>> _getTracksGroupedByServer() {
    final map = <String, Map<String, int>>{};
    for (final trExt in allTracksMappedByPath.values) {
      final server = trExt.server;
      if (server != null && server.isNotEmpty) {
        (map[server] ??= <String, int>{})[trExt.path] = trExt.dateModified;
      }
    }
    return map;
  }

  Future<void> updateTrackDuration(Track track, Duration dur) async {
    final durInMS = dur.inMilliseconds;
    if (durInMS > 0 && track.durationMS != durInMS) {
      final trx = allTracksMappedByPath[track.path];
      if (trx != null) {
        final newTrExt = trx.copyWith(durationMS: durInMS, generatePathHash: TagsExtractor.defaultUniqueArtworkHash);
        allTracksMappedByPath[track.path] = newTrExt;
        unawaited(_tracksDBManager.put(track.path, newTrExt.toJsonWithoutPath()));
        tracksInfoList.refresh();
        SearchSortController.inst.trackSearchList.refresh();
        SearchSortController.inst.trackSearchTemp.refresh();
      }
      TrackTileManager.rebuildTrackInfo(track);
    }
  }

  static List<String> splitByCommaList(String listText) {
    final moodsFinalLookup = <String, bool>{};
    final moodsFinal = <String>[];
    final moodsPre = listText.split(',');
    for (final m in moodsPre) {
      final cleaned = m.trimAll();
      if (cleaned.isEmpty) continue;
      if (moodsFinalLookup[cleaned] == null) {
        moodsFinalLookup[cleaned] = true;
        moodsFinal.add(cleaned);
      }
    }
    return moodsFinal;
  }

  /// Returns new [TrackStats].
  Future<TrackStats> updateTrackStats(
    Track track, {
    String? ratingString,
    String? tagsString,
    String? moodsString,
    int? lastPositionInMs,
    List<PlayableBookmark>? bookmarks,
  }) async {
    if (ratingString != null || tagsString != null || moodsString != null) {
      TrackTileManager.rebuildTrackInfo(track);
    }

    final statsRaw = track.statsRaw;

    // fallbacks should not access tags rating/moods/tags (effectiveRating etc), otherwise they would stick and reindexing won't solve it
    final rating = ratingString != null
        ? ratingString.isEmpty
              ? null
              : int.tryParse(ratingString) ?? statsRaw?.rating
        : statsRaw?.rating;
    final tags = tagsString != null ? splitByCommaList(tagsString) : statsRaw?.tags;
    final moods = moodsString != null ? splitByCommaList(moodsString) : statsRaw?.moods;
    lastPositionInMs ??= track.lastPlayedPositionInMs ?? 0;
    bookmarks ??= statsRaw?.bookmarks;
    final newStats = TrackStats(
      track: track,
      rating: rating?.clampInt(0, 100) ?? 0,
      tags: tags,
      moods: moods,
      lastPositionInMs: lastPositionInMs,
      audioTrackId: statsRaw?.audioTrackId,
      bookmarks: bookmarks,
      modifiedDate: currentTimeMS,
    );
    trackStatsMap[track] = newStats;
    unawaited(_trackStatsDBManager.put(track.path, newStats.toJsonWithoutTrack()));
    return newStats;
  }

  Future<void> updateTrackAudioTrackId(
    Track track, {
    required String? audioTrackId,
  }) async {
    final stats = track.statsRaw;
    final newStats = TrackStats(
      track: track,
      rating: stats?.rating ?? 0,
      tags: stats?.tags,
      moods: stats?.moods,
      lastPositionInMs: stats?.lastPositionInMs ?? 0,
      audioTrackId: audioTrackId,
      bookmarks: stats?.bookmarks,
      modifiedDate: currentTimeMS,
    );
    trackStatsMap[track] = newStats;
    unawaited(_trackStatsDBManager.put(track.path, newStats.toJsonWithoutTrack()));
  }

  Future<void> importTrackStats(Iterable<TrackStats> incomingStats, String senderDeviceId) async {
    bool anyChanged = false;
    for (final incoming in incomingStats) {
      final resolvedTrack = SyncPathResolver.resolveTrackByPath(senderDeviceId, incoming.track.path);
      final effective = resolvedTrack == null
          ? incoming
          : TrackStats(
              track: resolvedTrack,
              rating: incoming.rating,
              tags: incoming.tags,
              moods: incoming.moods,
              lastPositionInMs: incoming.lastPositionInMs,
              audioTrackId: incoming.audioTrackId,
              bookmarks: incoming.bookmarks,
              modifiedDate: incoming.modifiedDate,
            );
      final track = effective.track;
      final local = trackStatsMap.value[track];
      if (local != null && local.modifiedDate >= effective.modifiedDate) continue;
      final json = effective.toJsonWithoutTrack();
      if (json == null) continue;
      trackStatsMap.value[track] = effective;
      anyChanged = true;
      if (track is Video) json['v'] = true;
      await _trackStatsDBManager.put(track.path, json);
    }
    if (anyChanged) trackStatsMap.refresh();
  }

  Future<void> moveStatsPath(Map<Track, Track> oldNewTrack) async {
    for (final oldNew in oldNewTrack.entries) {
      final oldValue = trackStatsMap[oldNew.key];
      if (oldValue != null) {
        trackStatsMap.value[oldNew.value] = oldValue;
        trackStatsMap.refresh();
      }
      final oldValueDB = await _trackStatsDBManager.get(oldNew.key.path);
      await _trackStatsDBManager.put(oldNew.value.path, oldValueDB);
      // await _trackStatsDBManager.delete(oldNew.key.path); // not so important ig, preserve just in case
    }
  }

  Future<void> moveStatsDirectory(
    String normalizedOldDir,
    String normalizedNewDir, {
    Iterable<String>? forThesePathsOnly,
    bool ensureNewFileExists = false,
  }) async {
    final pathsOnlySet = forThesePathsOnly?.toSet();
    final existenceCache = <String, bool>{};
    final toUpdate = <Track, Track>{};

    for (final track in trackStatsMap.value.keys.toFixedList()) {
      final normalizedPath = replaceFunctionNormalizePath(track.path);
      final shouldUpdate = replaceFunctionForUpdatedPaths(
        track.path,
        normalizedOldDir,
        normalizedNewDir,
        pathsOnlySet,
        ensureNewFileExists,
        existenceCache,
      );
      if (shouldUpdate) {
        final newPath = replaceFunctionGetNewPath(normalizedPath, normalizedOldDir, normalizedNewDir);
        toUpdate[track] = Track.fromTypeParameter(track.runtimeType, newPath);
      }
    }

    if (toUpdate.isEmpty) return;

    for (final entry in toUpdate.entries) {
      final stats = trackStatsMap.value.remove(entry.key);
      if (stats != null) trackStatsMap.value[entry.value] = stats;
    }
    trackStatsMap.refresh();

    for (final oldNew in toUpdate.entries) {
      final oldValueDB = await _trackStatsDBManager.get(oldNew.key.path);
      await _trackStatsDBManager.put(oldNew.value.path, oldValueDB);
      // await _trackStatsDBManager.delete(oldNew.key.path); // not so important ig, preserve just in case
    }
  }

  Map<String, int> getLibraryMoodsCounts() {
    final counts = <String, int>{};
    _loopLibraryMoods((name, tr) => counts[name] = (counts[name] ?? 0) + 1);
    return counts;
  }

  Map<String, int> getLibraryTagsCounts() {
    final counts = <String, int>{};
    _loopLibraryTags((name, tr) => counts[name] = (counts[name] ?? 0) + 1);
    return counts;
  }

  List<Track>? getTracksForMood(String? name) {
    if (name == null) return null;
    final trs = <Track>[];
    _loopLibraryMoods((currentName, tr) {
      if (currentName == name) {
        trs.add(tr);
      }
    });
    return trs;
  }

  List<Track>? getTracksForTag(String? name) {
    if (name == null) return null;
    final trs = <Track>[];
    _loopLibraryTags((currentName, tr) {
      if (currentName == name) {
        trs.add(tr);
      }
    });
    return trs;
  }

  List<Track>? getTracksForRating(String? name) {
    if (name == null) return null;
    final trs = <Track>[];
    _loopLibraryRatings((currentName, tr) {
      if (currentName == name) {
        trs.add(tr);
      }
    });
    return trs;
  }

  Map<String, List<Track>> getTracksGroupedByMoods({bool sort = true}) {
    final allAvailableMap = <String, List<Track>>{};
    _loopLibraryMoods((mood, tr) => allAvailableMap.addForce(mood, tr));
    if (sort) allAvailableMap.sortByReverse((e) => e.value.length);
    return allAvailableMap;
  }

  void _loopLibraryMoods(void Function(String name, Track tr) callback) {
    final tempSet = <(Track, String)>{};

    // -- from stats map
    for (final e in Indexer.inst.trackStatsMap.value.entries) {
      final tr = e.key;
      if (tr.hasInfoInLibrary()) {
        final moods = e.value.moods;
        if (moods != null) {
          for (var mood in moods) {
            if (tempSet.add((tr, mood))) {
              callback(mood, tr);
            }
          }
        }
      }
    }

    // -- from track embedded tag
    for (var tr in allTracksInLibrary) {
      for (var mood in tr.moodList) {
        if (tempSet.add((tr, mood))) {
          callback(mood, tr);
        }
      }
    }
  }

  Map<String, List<Track>> getTracksGroupedByTags({bool sort = true}) {
    final allAvailableMap = <String, List<Track>>{};
    _loopLibraryTags((tag, tr) => allAvailableMap.addForce(tag, tr));
    if (sort) allAvailableMap.sortByReverse((e) => e.value.length);
    return allAvailableMap;
  }

  void _loopLibraryTags(void Function(String name, Track tr) callback) {
    final tempSet = <(Track, String)>{};

    // -- from stats map
    for (final e in Indexer.inst.trackStatsMap.value.entries) {
      final tr = e.key;
      if (tr.hasInfoInLibrary()) {
        final tags = e.value.tags;
        if (tags != null) {
          for (var tag in tags) {
            if (tempSet.add((tr, tag))) {
              callback(tag, tr);
            }
          }
        }
      }
    }

    // -- from track embedded tag
    for (var tr in allTracksInLibrary) {
      for (var tag in tr.tagsList) {
        if (tempSet.add((tr, tag))) {
          callback(tag, tr);
        }
      }
    }
  }

  Map<String, List<Track>> getTracksGroupedByRatings({bool sort = true}) {
    final allAvailableMap = <String, List<Track>>{};
    _loopLibraryRatings((rating, tr) => allAvailableMap.addForce(rating, tr));
    if (sort) allAvailableMap.sortByReverse((e) => int.tryParse(e.key) ?? 0);
    return allAvailableMap;
  }

  void _loopLibraryRatings(void Function(String name, Track tr) callback) {
    for (var tr in allTracksInLibrary) {
      callback(tr.effectiveRating.toString(), tr);
    }
  }

  Future<void> _readTrackData([Completer<void>? completer]) async {
    tracksInfoList.clear(); // clearing for cases which refreshing library is required (like after changing separators)
    networkTracksCount.value = 0;

    final mediaSorters = <MediaType, List<Comparable<dynamic> Function(Track)>>{};
    final mediaSortersReverse = settings.mediaItemsTrackSortingReverse.value;

    for (final e in MediaType.values) {
      mediaSorters[e] = SearchSortController.inst.getMediaTracksSortingComparables(e);
    }

    await [
      _IndexerIsolateExecuter._readTrackStatsDataSync.thready((dbInfo: AppPaths.TRACKS_STATS_DB_INFO, oldJsonFilePath: AppPaths.TRACKS_STATS_OLD)).then(
        (res) {
          trackStatsMap.value = res;
        },
      ),
      _IndexerIsolateExecuter._readTracksDataSync
          .thready((
            dbInfo: AppPaths.TRACKS_DB_INFO,
            oldJsonFilePath: AppPaths.TRACKS_OLD,
            splitConfig: _createSplitConfig(),
          ))
          .then(
            (value) async {
              allTracksMappedByPath = value.allTracksMappedByPath;
              allTracksMappedByYTID = value.allTracksMappedByYTID as Map<String, List<T>>;
              tracksInfoList.value = value.tracksInfoList as List<T>;
              networkTracksCount.value = value.networkTracksCount;

              mainMapsGroup.fillAll(
                tracksInfoList.value,
                (tr) =>
                    allTracksMappedByPath[tr.path] ??
                    kDummyExtendedTrack.copyWith(
                      title: tr.path.getFilenameWOExt,
                      path: tr.path,
                      generatePathHash: TagsExtractor.defaultUniqueArtworkHash,
                    ),
                settings.albumIdentifiers.value,
              );
              QueueController.latestPlayedForSourceManager.migrateLegacyAlbumSources();

              mainMapsGroup.sortAllSync(
                mediaSorters,
                mediaSortersReverse,
                tracksInfoList.value,
              );

              FoldersController.tracksAndVideos.onMapChanged(mainMapFoldersTracksAndVideos.value);
              FoldersController.tracksAndVideos.onFirstLoad();

              FoldersController.tracks.onMapChanged(mainMapFoldersTracks.value);
              FoldersController.tracks.onFirstLoad();
              FoldersController.videos.onMapChanged(mainMapFoldersVideos.value);
              FoldersController.videos.onFirstLoad();

              completer?.completeIfWasnt();

              SearchSortController.inst.refreshPortsIfNecessary(); // -- vip to refresh filtering
            },
          ),
    ].executeAllAndSilentReportErrors();

    printy("All Tracks Length From File: ${tracksInfoList.length}");
  }

  /// Same as [_readTrackData] but sorting happens on the spawned isolate, means everything needs to be copied instead of just tracks
  // Future<void> _readTrackDataWithOffloadSorting([Completer<void>? completer]) async {
  //   tracksInfoList.clear(); // clearing for cases which refreshing library is required (like after changing separators)

  //   final mediaSorters = <MediaType, List<Comparable<dynamic> Function(Track)>>{};
  //   final mediaSortersNOTSafeInIsolate = _getMediaTypeSortThatDependOnHistory();
  //   final mediaSortersReverse = settings.mediaItemsTrackSortingReverse.value;

  //   for (final e in MediaType.values) {
  //     if (!mediaSortersNOTSafeInIsolate.contains(e)) {
  //       mediaSorters[e] = SearchSortController.inst.getMediaTracksSortingComparables(e);
  //     }
  //   }

  //   final tracksRecievePort = ReceivePort();

  //   Future<void> handleRecieveTracks() async {
  //     try {
  //       final value = await tracksRecievePort.first;
  //       value as _TracksLoadResult;
  //       allTracksMappedByPath = value.allTracksMappedByPath;
  //       allTracksMappedByYTID = value.allTracksMappedByYTID as Map<String, List<T>>;
  //       tracksInfoList.value = value.tracksInfoList as List<T>;
  //       this.sortMediaTracksSubLists([MediaType.track]);
  //       completer?.completeIfWasnt();
  //     } catch (e, st) {
  //       completer?.completeErrorIfWasnt(e, st);
  //     } finally {
  //       tracksRecievePort.close();
  //     }
  //   }

  //   await [
  //     _IndexerIsolateExecuter._readTrackStatsDataSync.thready([AppPaths.TRACKS_STATS_DB_INFO, AppPaths.TRACKS_STATS_OLD]).then(
  //       (res) {
  //         trackStatsMap.value = res;
  //       },
  //     ),
  //     _IndexerIsolateExecuter._readTracksDataSync
  //         .thready([
  //           AppPaths.TRACKS_DB_INFO,
  //           AppPaths.TRACKS_OLD,
  //           _createSplitConfig(),
  //           mediaSorters,
  //           mediaSortersReverse,
  //           settings.albumIdentifiers.value,
  //           TagsExtractor.defaultUniqueArtworkHash,
  //           tracksRecievePort.sendPort,
  //         ])
  //         .then(
  //           (libraryGroup) async {
  //             mainMapsGroup.updateFrom(libraryGroup);

  //             FoldersController.tracksAndVideos.onMapChanged(mainMapFoldersTracksAndVideos.value);
  //             FoldersController.tracksAndVideos.onFirstLoad();

  //             FoldersController.tracks.onMapChanged(mainMapFoldersTracks.value);
  //             FoldersController.tracks.onFirstLoad();
  //             FoldersController.videos.onMapChanged(mainMapFoldersVideos.value);
  //             FoldersController.videos.onFirstLoad();

  //             _refreshMediaTracksSubListsAfterSort(mediaSorters.keys);

  //             SearchSortController.inst.refreshPortsIfNecessary(); // -- vip to refresh filtering
  //           },
  //         ),
  //     handleRecieveTracks(),
  //   ].executeAllAndSilentReportErrors();

  //   printy("All Tracks Length From File: ${tracksInfoList.length}");
  // }

  static final _featArtistRegex = RegExp(r'\(ft\. |\[ft\. |\(feat\. |\[feat\. ', caseSensitive: false);
  static final _closingBracketRegex = RegExp(r'\)|\]');

  static List<String> splitArtist({
    required String? title,
    required String? originalArtist,
    required ArtistsSplitConfig config,
  }) {
    final artists = originalArtist == UnknownTags.ARTIST ? [UnknownTags.ARTIST] : config.splitText(originalArtist, fallback: UnknownTags.ARTIST);
    if (title != null && config.addFeatArtist) {
      final featArtists = _extractFeatArtists(title);
      if (featArtists != null) config.addSplitTextTo(artists, featArtists);
    }
    return artists;
  }

  static String? _extractFeatArtists(String title) {
    final match = _featArtistRegex.firstMatch(title);
    if (match == null) return null;
    final start = match.end;
    final closingIndex = title.indexOf(_closingBracketRegex, start);
    final nextFeatIndex = title.indexOf(_featArtistRegex, start);
    final isNextFeatFirst = nextFeatIndex != -1 && (closingIndex == -1 || nextFeatIndex < closingIndex);
    final end = isNextFeatFirst ? nextFeatIndex : closingIndex;
    return end == -1 ? title.substring(start) : title.substring(start, end);
  }

  static String removeFeatArtistsFromTitle(String title) {
    final match = _featArtistRegex.firstMatch(title);
    if (match == null) return title;
    final closingIndex = title.indexOf(_closingBracketRegex, match.end);
    var start = match.start;
    var end = closingIndex == -1 ? title.length : closingIndex + 1;
    if (start > 0 && title.codeUnitAt(start - 1) == 0x20) {
      start--;
    } else if (end < title.length && title.codeUnitAt(end) == 0x20) {
      end++;
    }
    return title.replaceRange(start, end, '');
  }

  static List<String> splitComposer(
    String? originalComposer, {
    required ArtistsSplitConfig config,
  }) {
    if (originalComposer == UnknownTags.COMPOSER) return [UnknownTags.COMPOSER];
    return config.splitText(
      originalComposer,
      fallback: UnknownTags.COMPOSER,
    );
  }

  static List<String> splitAlbumArtist(
    String? originalAlbumArtist, {
    required ArtistsSplitConfig config,
  }) {
    return config.splitText(
      originalAlbumArtist,
      fallback: UnknownTags.ALBUMARTIST,
    );
  }

  static List<String> splitGenre(
    String? originalGenre, {
    required GenresSplitConfig config,
  }) {
    if (originalGenre == UnknownTags.GENRE) return [UnknownTags.GENRE];
    return config.splitText(
      originalGenre,
      fallback: UnknownTags.GENRE,
    );
  }

  static List<String> splitStyle(
    String? originalStyle, {
    required GenresSplitConfig config,
  }) {
    return config.splitText(
      originalStyle,
      fallback: UnknownTags.STYLE,
    );
  }

  static List<String> splitGeneral(
    String? originalText, {
    required GeneralSplitConfig config,
  }) {
    return config.splitText(
      originalText,
      fallback: null,
    );
  }

  static List<String> splitAlbum(
    String? originalText, {
    required SimpleSplitConfig config,
  }) {
    if (originalText == UnknownTags.ALBUM) return [UnknownTags.ALBUM];
    return config.splitText(
      originalText,
      fallback: null,
    );
  }

  Set<String> _getPhysicalMediasPaths() {
    final paths = <String>{};
    final tracks = tracksInfoList.value;
    for (int i = 0; i < tracks.length; i++) {
      final tr = tracks[i];
      if (tr.isPhysical) paths.add(tr.path);
    }
    return paths;
  }

  IndexerFilesDiff getPathsDifference(DirsFileFilterResult currentFiles) {
    final newPaths = <String>{};
    final modifiedPaths = <String>{};
    final deletedPaths = _getPhysicalMediasPaths();
    final newAndModifiedStats = <String, FileStatsAdv>{};

    final allTracksMappedByPath = this.allTracksMappedByPath;
    final stats = currentFiles.stats;
    int index = -1;
    for (final path in currentFiles.allPaths) {
      index++;
      final isInLibrary = deletedPaths.remove(path);
      if (isInLibrary) {
        if (stats == null || !stats.isKnownAt(index)) continue;
        final trExt = allTracksMappedByPath[path];
        if (trExt == null) continue;
        // -- seconds, windows tracks indexed before had no milliseconds
        final isSameDate = trExt.dateModified ~/ 1000 == stats.modifiedMSAt(index) ~/ 1000;
        if (isSameDate && trExt.size == stats.sizeAt(index)) continue;
        modifiedPaths.add(path);
      } else {
        newPaths.add(path);
      }
      final fileStats = stats?.toStatsAt(index);
      if (fileStats != null) newAndModifiedStats[path] = fileStats;
    }

    return IndexerFilesDiff(
      newPaths: newPaths,
      modifiedPaths: modifiedPaths,
      deletedPaths: deletedPaths,
      stats: newAndModifiedStats,
    );
  }

  /// [strictNoMedia] forces all subdirectories to follow the same result of the parent.
  ///
  /// ex: if (.nomedia) was found in [/storage/0/Music/],
  /// then subdirectories [/storage/0/Music/folder1/], [/storage/0/Music/folder2/] & [/storage/0/Music/folder2/subfolder/] will be excluded too.
  Future<Set<String>> getAudioFiles({bool strictNoMedia = true}) async {
    final result = await _listAudioFiles(strictNoMedia: strictNoMedia, withStats: false);
    return result.allPaths;
  }

  /// stats are left out with media store, it re-fetches everything anyway.
  Future<DirsFileFilterResult> getAudioFilesForRefresh() {
    return _listAudioFiles(withStats: !_defaultUseMediaStore);
  }

  Future<DirsFileFilterResult> _listAudioFiles({bool strictNoMedia = true, required bool withStats}) async {
    tracksExcludedByNoMedia.value = 0;

    final extensions = _includeVideosAsTracks ? NamidaFileExtensionsWrapper.audioAndVideo : NamidaFileExtensionsWrapper.audio;
    final dirsFilterer = DirsFileFilter(
      extensions: extensions,
      imageExtensions: NamidaFileExtensionsWrapper.image,
      blacklistExtensions: settings.extensionsBlacklist.value,
      strictNoMedia: strictNoMedia,
      withStats: withStats,
    );
    final result = await dirsFilterer.filter();

    final allPaths = result.allPaths;

    allAudioFiles.value = allPaths;
    tracksExcludedByNoMedia.value += result.excludedByNoMedia.length;
    allFolderCovers = result.folderCovers;

    printy("Paths Found: ${allPaths.length}");
    return result;
  }

  Future<void> scanMediaStore(String path) async {
    if (NamidaFeaturesVisibility.onAudioQueryAvailable) {
      try {
        await _audioQuery.scanMedia(path);
      } catch (_) {}
    }
  }

  Future<List<TrackExtended>> _fetchMediaStoreTracks() async {
    if (!_defaultUseMediaStore) return [];
    final allMusic = await _audioQuery.querySongs();
    // -- folders selected will be ignored when [_defaultUseMediaStore] is enabled.
    allMusic.retainWhere(
      (element) => settings.directoriesToExclude.value.every(
        (dir) => !element.data.startsWith(dir.sourceRaw),
      ) /* && settings.directoriesToScan.value.any((dir) => element.data.startsWith(dir)) */,
    );
    final tracks = <TrackExtended>[];

    final splitConfig = SplitArtistGenreConfigsWrapper.settings();

    for (final e in allMusic) {
      final map = e.getMap;
      final albumArtist = map['album_artist'] as String?;
      final mood = map['mood'];
      final tag = map['tag'] ?? map['tags'];
      final bitrate = map['bitrate'] as int?;
      final disc = map['disc_number'] as int?;
      final discTo = map['disc_total'] as int?;
      final trackTo = map['track_total'] as int?;
      final yearString = map['year'] as String?;
      final path = e.data;
      final trext = TrackExtended.derive(
        splitConfig: splitConfig,
        mbAlbumId: '',
        mbAlbumArtistId: '',
        title: e.title,
        originalArtist: e.artist ?? UnknownTags.ARTIST,
        originalAlbum: e.album ?? UnknownTags.ALBUM,
        albumArtist: albumArtist ?? UnknownTags.ALBUMARTIST,
        originalGenre: e.genre ?? UnknownTags.GENRE,
        originalStyle: UnknownTags.STYLE,
        originalMood: mood ?? '',
        composer: e.composer ?? '',
        trackNo: e.track ?? 0,
        trackTo: trackTo ?? 0,
        durationMS: e.duration ?? 0, // `e.duration` => milliseconds
        chapters: null,
        year: TrackExtended.enforceYearFormat(yearString) ?? 0,
        yearText: yearString ?? '',
        size: e.size,
        dateAdded: e.dateAdded ?? 0,
        dateModified: e.dateModified ?? 0,
        path: path,
        comment: '',
        description: '',
        synopsis: '',
        bitrate: bitrate == null ? 0 : bitrate ~/ 1000,
        sampleRate: 0,
        bits: 0,
        isLossless: null,
        format: '',
        channels: '',
        discNo: disc ?? 0,
        discTo: discTo ?? 0,
        language: '',
        lyrics: '',
        label: '',
        releaseType: '',
        bpm: 0,
        musicalKey: '',
        rating: 0.0,
        originalTags: tag,
        gainData: null,
        sortInfo: null,
        extraTags: null,
        isVideo: e.data.isVideo(),
        hashKey: TrackExtended.generateHashKeyIfEnabled(null, path, null),
        server: null,
      );
      tracks.add(trext);
      _backupMediaStoreIDS[trext.pathToImage] = (trext.asTrack(), e.id);
    }
    return tracks;
  }

  void updateImageSizesInStorage({required int removedCount, required int removedSize}) {
    artworksInStorage.value -= removedCount;
    artworksSizeInStorage.value -= removedSize;
  }

  Future<void> calculateAllImageSizesInStorage() async {
    final stats = await _caclulateDirectoryInfoIsolate.thready((dirPath: AppDirs.ARTWORKS, token: RootIsolateToken.instance));
    artworksInStorage.value = stats.$1;
    artworksSizeInStorage.value = stats.$2;
  }

  static (int, int) _caclulateDirectoryInfoIsolate(({String dirPath, RootIsolateToken? token}) p) {
    final dirPath = p.dirPath;
    final token = p.token;
    if (token != null) BackgroundIsolateBinaryMessenger.ensureInitialized(token);

    int totalCount = 0;
    int totalSize = 0;

    void calDirRecursive(Directory dir) {
      final files = dir.listSyncSafe();
      for (var f in files) {
        if (f is File) {
          try {
            totalSize += (f).lengthSync();
            totalCount++;
          } catch (_) {}
        } else {
          try {
            calDirRecursive(f as Directory);
          } catch (_) {}
        }
      }
    }

    calDirRecursive(Directory(dirPath));

    return (totalCount, totalSize);
  }

  // static int _caclulateDirectoryCountIsolate(String dirPath) {
  //   int totalCount = 0;

  // void calDirRecursive(Directory dir) {
  //   final files = dir.listSyncSafe();
  //   for (var f in files) {
  //     if (f is File) {
  //       totalCount++;
  //     } else {
  //       try {
  //         calDirRecursive(f as Directory);
  //       } catch (_) {}
  //     }
  //   }
  // }

  //   calDirRecursive(Directory(dirPath));

  //   return totalCount;
  // }

  // Future<void> updateColorPalettesSizeInStorage({String? newPalettePath}) async {
  //   if (newPalettePath != null) {
  //     colorPalettesInStorage.value++;
  //     return;
  //   }
  //   final count = await _caclulateDirectoryCountIsolate.thready(AppDirs.PALETTES);
  //   colorPalettesInStorage.value = count;
  // }

  Future<void> clearImageCache() async {
    await Directory(AppDirs.ARTWORKS).delete(recursive: true);
    await Directory(AppDirs.ARTWORKS).create();
    Indexer.createDefaultNamidaArtworkIfRequired();
    calculateAllImageSizesInStorage();
  }

  static Future<String> createDefaultNamidaArtworkIfRequired() async {
    if (!await File(AppPaths.NAMIDA_LOGO_LAYER).exists()) {
      final byteData = await rootBundle.load(NamidaChannel.defaultLayerIconForPlatform);
      final file = await File(AppPaths.NAMIDA_LOGO_LAYER).create(recursive: true);
      await file.writeAsBytes(byteData.buffer.asUint8List());
    }
    return AppPaths.NAMIDA_LOGO_LAYER;
  }

  static SplitArtistGenreConfigsWrapper _createSplitConfig() {
    return SplitArtistGenreConfigsWrapper.settings();
  }

  static void clearMemoryImageCache() {
    imageCache.clear();
    imageCache.clearLiveImages();
    if (Platform.isAndroid) AudioService.evictArtworkCache();
  }
}

class _IndexerIsolateExecuter {
  /// reading stats db containing track rating etc.
  static Future<Map<Track, TrackStats>> _readTrackStatsDataSync(({DbWrapperFileInfo dbInfo, String oldJsonFilePath}) params) async {
    final statsDbInfo = params.dbInfo;
    final oldJsonFilePath = params.oldJsonFilePath;

    final statsDBManager = await DBWrapper.openFromInfoSyncTry(
      fileInfo: statsDbInfo,
      config: const DBConfig(
        createIfNotExist: true,
        autoDisposeTimerDuration: null, // we close manually
      ),
    );

    final trackStatsMap = <Track, TrackStats>{};

    try {
      statsDBManager?.loadEverythingKeyed(
        (key, value) {
          final track = Track.fromJson(key, isVideo: value['v'] == true);
          final stats = TrackStats.fromJsonWithoutTrack(track, value);
          trackStatsMap[stats.track] = stats;
        },
      );

      // -- migrating tracks stats json to db
      final statsJsonFile = File(oldJsonFilePath);
      if (statsJsonFile.existsSync()) {
        final list = statsJsonFile.readAsJsonSync() as List?;
        if (list != null) {
          for (final item in list) {
            try {
              final trst = TrackStats.fromJson(item);
              if (trackStatsMap[trst.track] == null) {
                final jsonDetails = trst.toJsonWithoutTrack();
                if (jsonDetails != null) {
                  trackStatsMap[trst.track] = trst;
                  statsDBManager?.put(trst.track.path, trst.toJsonWithoutTrack());
                }
              }
            } catch (_) {}
          }
        }
        statsJsonFile.deleteSync();
      }
    } catch (_) {}
    statsDBManager?.close();
    return trackStatsMap;
  }

  /// Reading actual tracks db.
  static Future<_TracksLoadResult> _readTracksDataSync(({DbWrapperFileInfo dbInfo, String oldJsonFilePath, SplitArtistGenreConfigsWrapper splitConfig}) params) async {
    final tracksDbInfo = params.dbInfo;
    final oldJsonFilePath = params.oldJsonFilePath;
    final splitconfig = params.splitConfig;
    // --------- enable only if sorting will be done here ---------
    // final mediaItemsTrackSorters = paramsList[3] as Map<MediaType, List<Comparable<dynamic> Function(Track)>>;
    // final mediaItemsTrackSortingReverse = paramsList[4] as Map<MediaType, bool>;
    // final albumIdentifiers = paramsList[5] as List<AlbumIdentifier>;
    // final generatePathHash = paramsList[6] as bool? ?? false;
    // final tracksInitPort = paramsList[7] as SendPort;
    // ------------------

    final tracksDBManager = await DBWrapper.openFromInfoSyncTry(
      fileInfo: tracksDbInfo,
      config: DBConfig(
        createIfNotExist: true,
        autoDisposeTimerDuration: null, // we close manually
      ),
    );
    final allTracksMappedByPath = <String, TrackExtended>{};
    final tracksInfoList = <Track>[];
    var allTracksMappedByYTID = <String, List<Track>>{};
    int networkTracksCount = 0;

    try {
      tracksDBManager!.loadEverythingKeyed(
        (path, item) {
          try {
            final trExt = TrackExtended.fromJson(
              path,
              item,
              splitConfig: splitconfig,
            );
            final track = trExt.asTrack();
            allTracksMappedByPath[track.path] = trExt;
            tracksInfoList.add(track);
            if (track.isNetwork) networkTracksCount++;
            allTracksMappedByYTID.addForce(trExt.youtubeID, track);
          } catch (_) {}
        },
      );

      // -- migrating tracks json to db
      final tracksJsonFile = File(oldJsonFilePath);
      if (tracksJsonFile.existsSync()) {
        final list = tracksJsonFile.readAsJsonSync() as List?;
        if (list != null) {
          for (final item in list) {
            try {
              final trExt = TrackExtended.fromJson(
                item['path'] ?? '',
                item,
                splitConfig: splitconfig,
              );
              final track = trExt.asTrack();
              allTracksMappedByPath[track.path] = trExt;
              tracksInfoList.add(track);
              if (track.isNetwork) networkTracksCount++;
              allTracksMappedByYTID.addForce(trExt.youtubeID, track);
              tracksDBManager.put(track.path, trExt.toJsonWithoutPath());
            } catch (_) {}
          }
        }
        tracksJsonFile.deleteSync();
      }
    } catch (_) {}

    if (tracksInfoList.isEmpty && allTracksMappedByPath.isEmpty) {
      // -- in case db disk image was malformed for example,
      // -- clear the db so that it be ready by the next time.
      try {
        tracksDBManager?.deleteEverything();
      } catch (_) {}
    }

    tracksDBManager?.close();

    return _TracksLoadResult(
      tracksInfoList: tracksInfoList,
      allTracksMappedByPath: allTracksMappedByPath,
      allTracksMappedByYTID: allTracksMappedByYTID,
      networkTracksCount: networkTracksCount,
    );

    // --------- enable only if sorting will be done here ---------
    // tracksInitPort.send(
    //   _TracksLoadResult(
    //     tracksInfoList: tracksInfoList,
    //     allTracksMappedByPath: allTracksMappedByPath,
    //     allTracksMappedByYTID: allTracksMappedByYTID,
    //   ),
    // );

    // // -- so that sorting works, the Indexer here is local to this isolate only
    // Indexer.inst.allTracksMappedByPath = allTracksMappedByPath;
    // Indexer.inst.tracksInfoList.value = tracksInfoList;
    // Indexer.inst.allTracksMappedByYTID = allTracksMappedByYTID;

    // final libraryGroup = LibraryGroup();
    // libraryGroup.fillAll(
    //   tracksInfoList,
    //   (tr) =>
    //       allTracksMappedByPath[tr.path] ??
    //       kDummyExtendedTrack.copyWith(
    //         title: tr.path.getFilenameWOExt,
    //         path: tr.path,
    //         generatePathHash: generatePathHash,
    //       ),
    //   albumIdentifiers,
    // );

    // libraryGroup.sortAllSync(
    //   mediaItemsTrackSorters,
    //   mediaItemsTrackSortingReverse,
    //   tracksInfoList,
    // );

    // return libraryGroup;
    // ------------------
  }
}

class _TracksLoadResult {
  final List<Track> tracksInfoList;
  final Map<String, TrackExtended> allTracksMappedByPath;
  final Map<String, List<Track>> allTracksMappedByYTID;
  final int networkTracksCount;

  const _TracksLoadResult({
    required this.tracksInfoList,
    required this.allTracksMappedByPath,
    required this.allTracksMappedByYTID,
    required this.networkTracksCount,
  });
}

class IndexerFilesDiff {
  final Set<String> newPaths;
  final Set<String> modifiedPaths;
  final Set<String> deletedPaths;

  /// of new and modified files.
  final Map<String, FileStatsAdv> stats;

  const IndexerFilesDiff({
    required this.newPaths,
    required this.modifiedPaths,
    required this.deletedPaths,
    required this.stats,
  });

  IndexerFilesDiff withoutDeletedPaths() {
    return IndexerFilesDiff(
      newPaths: newPaths,
      modifiedPaths: modifiedPaths,
      deletedPaths: const {},
      stats: stats,
    );
  }
}

class FileStatsAdv {
  final int? creationDateMS;
  final int? modifiedMS;
  final int? size;

  const FileStatsAdv({
    required this.creationDateMS,
    required this.modifiedMS,
    required this.size,
  });

  factory FileStatsAdv.fromFileStat(FileStat stat) {
    return FileStatsAdv(
      creationDateMS: stat.creationDate.millisecondsSinceEpoch,
      modifiedMS: stat.modified.millisecondsSinceEpoch,
      size: stat.size,
    );
  }
}

class _ServerTracksFetchInfo {
  final DirectoryIndexServer dir;
  final MusicWebServer server;

  /// 0 when unknown.
  final Future<int> tracksCount;

  const _ServerTracksFetchInfo({
    required this.dir,
    required this.server,
    required this.tracksCount,
  });
}

class _RemotePlaylistImportInfo {
  final MusicWebServer server;
  final String dbKey;
  final String serverKey;

  const _RemotePlaylistImportInfo({
    required this.server,
    required this.dbKey,
    required this.serverKey,
  });
}
