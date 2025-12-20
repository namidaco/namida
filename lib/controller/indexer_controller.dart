import 'dart:async';
import 'dart:io';
import 'dart:isolate';

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
import 'package:namida/class/split_config.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/folders_controller.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/tags_extractor/tags_extractor.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/tagger_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';

class Indexer<T extends Track> {
  static Indexer get inst => _instance;
  static final Indexer _instance = Indexer._internal();
  Indexer._internal();

  bool get _defaultUseMediaStore => NamidaFeaturesVisibility.onAudioQueryAvailable && settings.useMediaStore.value;
  bool get _includeVideosAsTracks => settings.includeVideos.value;

  void _clearTracksDBAndReOpen() {
    _tracksDBManager.deleteEverything();
  }

  late final _tracksDBManager = DBWrapper.openFromInfo(
    fileInfo: AppPaths.TRACKS_DB_INFO,
    config: const DBConfig(createIfNotExist: true),
  );
  late final _trackStatsDBManager = DBWrapper.openFromInfo(
    fileInfo: AppPaths.TRACKS_STATS_DB_INFO,
    config: const DBConfig(createIfNotExist: true),
  );

  final isIndexing = false.obs;

  final allAudioFiles = <String>{}.obs;
  final filteredForSizeDurationTracks = 0.obs;
  final duplicatedTracksLength = 0.obs;
  final tracksExcludedByNoMedia = 0.obs;

  final artworksInStorage = 0.obs;
  // final colorPalettesInStorage = 0.obs;

  final artworksSizeInStorage = 0.obs;

  final mainMapsGroup = LibraryGroup<T>();
  LibraryItemMap get mainMapAlbums => mainMapsGroup.mainMapAlbums;
  LibraryItemMap get mainMapArtists => mainMapsGroup.mainMapArtists;
  LibraryItemMap get mainMapAlbumArtists => mainMapsGroup.mainMapAlbumArtists;
  LibraryItemMap get mainMapComposer => mainMapsGroup.mainMapComposer;
  LibraryItemMap get mainMapGenres => mainMapsGroup.mainMapGenres;
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

  final tracksInfoList = <T>[].obs;

  /// tracks map used for lookup
  var allTracksMappedByPath = <String, TrackExtended>{};
  final trackStatsMap = <Track, TrackStats>{}.obs;

  var allFolderCovers = <String, String>{}; // {directoryPath, imagePath}
  var allTracksMappedByYTID = <String, List<T>>{};

  /// Used to prevent duplicated track (by filename).
  final Map<String, bool> _currentFileNamesMap = {};

  late final _audioQuery = OnAudioQuery();

  List<T> recentlyAddedTracksSorted() {
    final alltracks = <T>[];
    tracksInfoList.value.loop(
      (item) {
        alltracks.insertWithOrder(
          item,
          (a, b) {
            var result = b.dateModified.compareTo(a.dateModified);
            if (result == 0) result = b.dateAdded.compareTo(a.dateAdded);
            return result;
          },
        );
      },
    );
    return alltracks;
  }

  bool imageObtainedBefore(String imagePath) => _artworksMap[imagePath] != null || _artworksMapFullRes[imagePath] != null;

  String? getFallbackFolderArtworkPath({required String folderPath}) {
    String? cover = this.allFolderCovers[folderPath];
    if (cover == null && folderPath.endsWith(Platform.pathSeparator)) {
      try {
        folderPath = folderPath.substring(0, folderPath.length - 1);
        cover = this.allFolderCovers[folderPath];
      } catch (_) {}
    }
    return cover;
  }

  /// {imagePath: (TrackExtended, id)};
  final _backupMediaStoreIDS = <String, (Track, int)>{};
  final artworksMap = <String, Uint8List?>{};
  final _artworksMap = <String, Completer<void>>{};
  final _artworksMapFullRes = <String, Completer<void>>{};
  Future<(File?, Uint8List?)> getArtwork({
    required String? imagePath,
    String? trackPath,
    bool checkFileFirst = true,
    required bool compressed,
    int? size,
  }) async {
    if (!NamidaFeaturesVisibility.onAudioQueryAvailable) {
      if (compressed) return (null, null);
      if (trackPath == null) return (null, null);
      final isVideo = trackPath.isVideo();
      final artworkDirectory = isVideo ? AppDirs.THUMBNAILS : AppDirs.ARTWORKS;
      String filename;
      if (TagsExtractor.defaultGroupArtworksByAlbum) {
        final identifiersSet = TagsExtractor.getAlbumIdentifiersSet();
        final trExt = Track.decide(trackPath, isVideo).toTrackExtOrNull();
        filename = trExt?.albumIdentifierWrapper?.resolved() ??
            TagsExtractor.getArtworkIdentifier(albumName: trExt?.album, albumArtist: trExt?.albumArtist, year: trExt?.year.toString(), identifiers: identifiersSet);
      } else {
        filename = trackPath.getFilename;
      }
      final res = await TagsExtractor.extractThumbnailCustom(
        trackPath: trackPath,
        isVideo: isVideo,
        artworkDirectory: artworkDirectory,
        filename: filename,
      );
      return (res, null);
    }
    if (imagePath == null) return (null, null);
    if (!_defaultUseMediaStore) return (null, null); // bcz it can generate non-accurate artworks (thanks media store)

    if (compressed && _artworksMap[imagePath] != null) {
      await _artworksMap[imagePath]!.future;
      return (null, artworksMap[imagePath]);
    }

    if (checkFileFirst && await File(imagePath).exists()) {
      return (File(imagePath), null);
    } else {
      final info = _backupMediaStoreIDS[imagePath];
      if (info != null) {
        final id = info.$2;
        Uint8List? artwork;
        if (compressed) {
          _artworksMap[imagePath] = Completer<Uint8List?>();

          artwork = await _audioQuery.queryArtwork(
            id,
            ArtworkType.AUDIO,
            format: ArtworkFormat.JPEG,
            quality: null,
            size: size?.clampInt(48, 360) ?? 360,
          );
          artworksMap[imagePath] = artwork;
          _artworksMap[imagePath]!.completeIfWasnt();
          await _artworksMap[imagePath]?.future;
          return (null, artworksMap[imagePath]);
        } else {
          _artworksMapFullRes[imagePath] = Completer<void>();
          // -- try extracting full res using taggers
          File? file;
          final res = await NamidaTaggerController.inst.extractMetadata(trackPath: info.$1.path, isVideo: info.$1 is Video);
          file = res.tags.artwork.file;
          if (file == null) {
            artwork = await _audioQuery.queryArtwork(
              id,
              ArtworkType.AUDIO,
              format: ArtworkFormat.PNG,
              quality: 100,
              size: 720,
            );
            if (artwork != null) {
              final f = File(imagePath);
              await FileImage(f).evict();
              await f.writeAsBytes(artwork);
              file = f;
            }
          }

          _artworksMapFullRes[imagePath]!.completeIfWasnt(); // to notify that the process was done, but we dont store full res bytes
          await _artworksMapFullRes[imagePath]?.future;
          return (file, null);
        }
      }
    }

    return (null, null);
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
    if (await File(tracksDBPath).existsAndValid((4 + 12) * 1024) || await File(AppPaths.TRACKS_OLD).existsAndValid()) {
      isIndexing.value = true;
      // -- only block load if the track file exists..
      await _readTrackData(completer);
      await sortMediaTracksAndSubListsAfterHistoryPrepared();
      await _sortAll();
      isIndexing.value = false;
    } else {
      // -- otherwise it get into normally and start indexing.
      await File(tracksDBPath).create();
      completer?.completeIfWasnt();
      refreshLibraryAndCheckForDiff(forceReIndex: true, useMediaStore: _defaultUseMediaStore);
    }
  }

  void rebuildTracksAfterSplitConfigChanges() async {
    final splitConfig = _createSplitConfig();
    final keysList = allTracksMappedByPath.keys.toList();
    for (int i = 0; i < keysList.length; i++) {
      var trPath = keysList[i];
      final oldtr = allTracksMappedByPath[trPath]!;
      allTracksMappedByPath[trPath] = oldtr.copyWith(
        artistsList: Indexer.splitArtist(
          title: oldtr.title,
          originalArtist: oldtr.originalArtist,
          config: splitConfig.artistsConfig,
        ),
        genresList: Indexer.splitGenre(
          oldtr.originalGenre,
          config: splitConfig.genresConfig,
        ),
        moodList: Indexer.splitGeneral(
          oldtr.originalMood,
          config: splitConfig.generalConfig,
        ),
        tagsList: Indexer.splitGeneral(
          oldtr.originalTags,
          config: splitConfig.generalConfig,
        ),
        generatePathHash: TagsExtractor.defaultUniqueArtworkHash,
      );
    }
    await _afterIndexing();
    tracksInfoList.refresh();
  }

  void rebuildTracksAfterExtractFeatArtistChanges() async {
    final artistsSplitConfig = ArtistsSplitConfig.settings();
    final keysList = allTracksMappedByPath.keys.toList();
    for (int i = 0; i < keysList.length; i++) {
      var trPath = keysList[i];
      final oldtr = allTracksMappedByPath[trPath]!;
      allTracksMappedByPath[trPath] = oldtr.copyWith(
        artistsList: Indexer.splitArtist(
          title: oldtr.title,
          originalArtist: oldtr.originalArtist,
          config: artistsSplitConfig,
        ),
        generatePathHash: TagsExtractor.defaultUniqueArtworkHash,
      );
    }
    await _afterIndexing();
    tracksInfoList.refresh();
  }

  void resortAllAfterIgnoreCommonPrefixChange() async {
    await _afterIndexing();
    tracksInfoList.refresh();
  }

  Future<void> refreshLibraryAndCheckForDiff({
    Set<String>? currentFiles,
    bool forceReIndex = false,
    bool? useMediaStore,
    bool allowDeletion = true,
    bool showFinishedSnackbar = true,
  }) async {
    if (isIndexing.value) {
      snackyy(title: lang.NOTE, message: lang.ANOTHER_PROCESS_IS_RUNNING);
      return;
    }

    isIndexing.value = true;
    useMediaStore ??= _defaultUseMediaStore;

    if (forceReIndex || tracksInfoList.isEmpty) {
      await _fetchAllSongsAndWriteToFile(
        audioFiles: {},
        deletedPaths: {},
        forceReIndex: true,
        useMediaStore: useMediaStore,
      );
    } else {
      currentFiles ??= await getAudioFiles();
      await _fetchAllSongsAndWriteToFile(
        audioFiles: getNewFoundPaths(currentFiles),
        deletedPaths: allowDeletion ? getDeletedPaths(currentFiles) : {},
        forceReIndex: false,
        useMediaStore: useMediaStore,
      );
    }

    await _afterIndexing();
    isIndexing.value = false;
    if (showFinishedSnackbar) snackyy(title: lang.DONE, message: lang.FINISHED_UPDATING_LIBRARY);
  }

  /// Adds all tracks inside [tracksInfoList] to their respective album, artist, etc..
  /// & sorts all media.
  Future<void> _afterIndexing() async {
    final mediaSorters = {for (final e in MediaType.values) e: SearchSortController.inst.getMediaTracksSortingComparables(e)};
    this.mainMapsGroup.fillAll(tracksInfoList.value, (tr) => tr.toTrackExt(), settings.albumIdentifiers.value);
    await this.mainMapsGroup.sortAll(mediaSorters, settings.mediaItemsTrackSortingReverse.value, tracksInfoList.value);
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
    await this.mainMapsGroup.sortAll(sorters, mediaItemsTrackSortingReverse, tracksInfoList.value);
    _refreshMediaTracksSubListsAfterSort(sorters.keys); // -- vip vro
    this.mainMapsGroup.refreshAll(); // to refresh sublists as well
  }

  void _refreshMediaTracksSubListsAfterSort(Iterable<MediaType> sortedMedias) {
    for (final e in sortedMedias) {
      final fn = switch (e) {
        MediaType.track => () => SearchSortController.inst.searchTracks(LibraryTab.tracks.textSearchController?.text ?? ''),
        MediaType.album || MediaType.artist || MediaType.albumArtist || MediaType.composer || MediaType.genre => () =>
            SearchSortController.inst.searchMedia(e.toLibraryTab().textSearchController?.text ?? '', e),
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
    for (final e in settings.mediaItemsTrackSorting.entries) {
      for (final sort in e.value) {
        if (sort.requiresHistory) {
          requiredToSort.add(e.key);
          break;
        }
      }
    }
    return requiredToSort;
  }

  /// re-sorts media subtracks that depend on history.
  Future<void> sortMediaTracksAndSubListsAfterHistoryPrepared() async {
    if (HistoryController.inst.isHistoryLoaded && this.mainMapsGroup.didFill) {
      final requiredToSort = _getMediaTypeSortThatDependOnHistory();
      await sortMediaTracksSubLists(requiredToSort);

      for (final e in MediaType.values) {
        final sortRequiresHistory = switch (e) {
          MediaType.track => settings.mediaItemsTrackSorting.value[MediaType.track]?.firstOrNull?.requiresHistory ?? false,
          MediaType.album => settings.albumSort.value.requiresHistory,
          MediaType.artist => settings.artistSort.value.requiresHistory,
          MediaType.albumArtist => settings.artistSort.value.requiresHistory,
          MediaType.composer => settings.artistSort.value.requiresHistory,
          MediaType.genre => settings.genreSort.value.requiresHistory,
          MediaType.playlist => settings.playlistSort.value.requiresHistory,
          MediaType.folder => settings.mediaItemsTrackSorting.value[MediaType.folder]?.firstOrNull?.requiresHistory ?? false,
          MediaType.folderMusic => settings.mediaItemsTrackSorting.value[MediaType.folderMusic]?.firstOrNull?.requiresHistory ?? false,
          MediaType.folderVideo => settings.mediaItemsTrackSorting.value[MediaType.folderVideo]?.firstOrNull?.requiresHistory ?? false,
        };
        if (sortRequiresHistory) SearchSortController.inst.sortMedia(e);
      }
    }
  }

  Future<void> _sortAll() => SearchSortController.inst.sortAll();

  /// Removes Specific tracks from their corresponding media, useful when updating track metadata or reindexing a track.
  void _removeThisTrackFromAlbumGenreArtistEtc(Track tr) {
    final trExt = tr.toTrackExt();
    mainMapAlbums.value[trExt.albumIdentifier]?.remove(tr);

    trExt.artistsList.loop((artist) {
      mainMapArtists.value[artist]?.remove(tr);
    });
    mainMapAlbumArtists.value[trExt.albumArtist]?.remove(tr);
    mainMapComposer.value[trExt.composer]?.remove(tr);
    trExt.genresList.loop((genre) {
      mainMapGenres.value[genre]?.remove(tr);
    });
    tr is Video ? mainMapFoldersVideos[tr.folder]?.remove(tr) : mainMapFoldersTracks[tr.folder]?.remove(tr);
    mainMapFoldersTracksAndVideos[tr.folder]?.remove(tr);

    _currentFileNamesMap.remove(tr.filename);
  }

  void _addTheseTracksToAlbumGenreArtistEtc(Map<TrackExtended, TrackExtended?> tracksMap) {
    final mainMapAlbums = this.mainMapAlbums.value;
    final mainMapArtists = this.mainMapArtists.value;
    final mainMapAlbumArtists = this.mainMapAlbumArtists.value;
    final mainMapComposer = this.mainMapComposer.value;
    final mainMapGenres = this.mainMapGenres.value;
    final mainMapFoldersTracksAndVideos = this.mainMapFoldersTracksAndVideos.value;
    final mainMapFoldersTracks = this.mainMapFoldersTracks.value;
    final mainMapFoldersVideos = this.mainMapFoldersVideos.value;

    final addedItemsLists = <MediaType, ({Map<dynamic, List<dynamic>> map, List<dynamic> newKeys, Set<dynamic> modifiedKeys})>{
      MediaType.album: (map: mainMapAlbums, newKeys: [], modifiedKeys: {}),
      MediaType.artist: (map: mainMapArtists, newKeys: [], modifiedKeys: {}),
      MediaType.albumArtist: (map: mainMapAlbumArtists, newKeys: [], modifiedKeys: {}),
      MediaType.composer: (map: mainMapComposer, newKeys: [], modifiedKeys: {}),
      MediaType.genre: (map: mainMapGenres, newKeys: [], modifiedKeys: {}),
      MediaType.folder: (map: mainMapFoldersTracksAndVideos, newKeys: [], modifiedKeys: {}),
      MediaType.folderMusic: (map: mainMapFoldersTracks, newKeys: [], modifiedKeys: {}),
      MediaType.folderVideo: (map: mainMapFoldersVideos, newKeys: [], modifiedKeys: {}),
    };

    void removeCustom<K, E>(MediaType type, Map<K, List<E>> map, K key, E item) {
      final list = map[key];
      if (list != null) {
        list.remove(item);
        if (list.isEmpty) {
          map.remove(key);
          addedItemsLists[type]!.modifiedKeys.add(key);
        }
      }
    }

    // -- this gurantees that [newlyAddedList] will not contain duplicates.
    void addCustom<K, E>(MediaType type, Map<K, List<E>> map, K? oldKey, K newKey, E item) {
      if (oldKey == newKey) return;
      if (oldKey != null) removeCustom(type, map, oldKey, item);
      final list = map[newKey];
      if (list == null) {
        map[newKey] = [item];
        addedItemsLists[type]!.newKeys.add(newKey);
        addedItemsLists[type]!.modifiedKeys.add(newKey);
      } else {
        if (!list.contains(item)) {
          list.add(item);
          addedItemsLists[type]!.modifiedKeys.add(newKey);
        }
      }
    }

    (List<String> newOnes, List<String> oldOnes) differenceLists(List<String> newOnes, List<String> oldOnes) {
      final oldOnesCopy = List<String>.from(oldOnes);
      final newOnesFinal = <String>[];
      newOnes.loop(
        (element) {
          final alreadyExistedInOld = oldOnesCopy.remove(element);
          if (!alreadyExistedInOld) newOnesFinal.add(element);
        },
      );
      return (newOnesFinal, oldOnesCopy);
    }

    for (final e in tracksMap.entries) {
      final newtr = e.key;
      final oldtr = e.value;
      final oldTrack = oldtr?.asTrack();
      final newTrack = newtr.asTrack();

      // -- Assigning Albums
      addCustom(MediaType.album, mainMapAlbums, oldtr?.albumIdentifier, newtr.albumIdentifier, newTrack);

      // -- Assigning Artists
      final newOldArtists = oldtr == null ? (newtr.artistsList, const []) : differenceLists(newtr.artistsList, oldtr.artistsList);

      for (final arNew in newOldArtists.$1) {
        addCustom(MediaType.artist, mainMapArtists, null, arNew, newTrack);
      }
      for (final arOld in newOldArtists.$2) {
        removeCustom(MediaType.artist, mainMapArtists, arOld, oldTrack);
      }
      addCustom(MediaType.albumArtist, mainMapAlbumArtists, oldTrack?.albumArtist, newTrack.albumArtist, newTrack);
      addCustom(MediaType.composer, mainMapComposer, oldTrack?.composer, newTrack.composer, newTrack);

      // -- Assigning Genres
      final newOldGenres = oldtr == null ? (newtr.genresList, const []) : differenceLists(newtr.genresList, oldtr.genresList);
      for (final genNew in newOldGenres.$1) {
        addCustom(MediaType.genre, mainMapGenres, null, genNew, newTrack);
      }
      for (final genOld in newOldGenres.$2) {
        removeCustom(MediaType.genre, mainMapGenres, genOld, oldTrack);
      }

      // -- Assigning Folders
      newTrack is Video
          ? addCustom(MediaType.folderVideo, mainMapFoldersVideos, oldTrack?.folder, newTrack.folder, newTrack)
          : addCustom(MediaType.folderMusic, mainMapFoldersTracks, oldTrack?.folder, newTrack.folder, newTrack);

      addCustom(MediaType.folder, mainMapFoldersTracksAndVideos, oldTrack?.folder, newTrack.folder, newTrack);
    }

    for (final sec in addedItemsLists.entries) {
      final type = sec.key;
      final modifiedKeys = sec.value.modifiedKeys;

      if (modifiedKeys.isNotEmpty) SearchSortController.inst.sortMedia(type); // main list sorting
      if (modifiedKeys.isNotEmpty) {
        final map = sec.value.map as Map<dynamic, List<T>>;
        final sorters = type == MediaType.albumArtist || type == MediaType.composer
            ? SearchSortController.inst.getMediaTracksSortingComparables(MediaType.artist)
            : SearchSortController.inst.getMediaTracksSortingComparables(type);
        final reverse = settings.mediaItemsTrackSortingReverse.value[type] ?? false;

        if (reverse) {
          for (final k in modifiedKeys) {
            map[k]?.sortByReverseAlts(sorters); // sub-list sorting
          }
        } else {
          for (final k in modifiedKeys) {
            map[k]?.sortByAlts(sorters); // sub-list sorting
          }
        }
      }
    }

    if (addedItemsLists[MediaType.folder]?.newKeys.isNotEmpty == true) FoldersController.tracksAndVideos.onMapChanged(mainMapFoldersTracksAndVideos);
    if (addedItemsLists[MediaType.folderMusic]?.newKeys.isNotEmpty == true) FoldersController.tracks.onMapChanged(mainMapFoldersTracks);
    if (addedItemsLists[MediaType.folderVideo]?.newKeys.isNotEmpty == true) FoldersController.videos.onMapChanged(mainMapFoldersVideos);
  }

  Future<TrackExtended?> _convertTagToTrack({
    required String trackPath,
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
      FileStat? fileStat;
      try {
        fileStat = await File(trackPath).stat();
        if (minSize > 0 && fileStat.size < minSize) {
          return onMinSizeTrigger();
        }
      } catch (_) {}

      late TrackExtended finalTrackExtended;

      if (trackInfo.hasError && !tryExtractingFromFilename) return null;

      final initialTrack = TrackExtended(
        title: UnknownTags.TITLE,
        originalArtist: UnknownTags.ARTIST,
        artistsList: [UnknownTags.ARTIST],
        album: UnknownTags.ALBUM,
        albumArtist: UnknownTags.ALBUMARTIST,
        originalGenre: UnknownTags.GENRE,
        genresList: [UnknownTags.GENRE],
        composer: UnknownTags.COMPOSER,
        originalMood: UnknownTags.MOOD,
        moodList: [UnknownTags.MOOD],
        trackNo: 0,
        durationMS: 0,
        year: 0,
        yearText: '',
        size: fileStat?.size ?? 0,
        dateAdded: fileStat?.creationDate.millisecondsSinceEpoch ?? 0,
        dateModified: fileStat?.modified.millisecondsSinceEpoch ?? 0,
        path: trackPath,
        comment: '',
        description: '',
        synopsis: '',
        bitrate: 0,
        sampleRate: 0,
        format: '',
        channels: '',
        discNo: 0,
        language: '',
        lyrics: '',
        label: '',
        rating: 0.0,
        originalTags: null,
        tagsList: [],
        gainData: null,
        albumIdentifierWrapper: null,
        isVideo: trackPath.isVideo(),
        hashKey: TrackExtended.generateHashKeyIfEnabled(null, trackPath, null),
      );
      if (!trackInfo.hasError) {
        int durationInMS = trackInfo.durationMS ?? 0;
        if (minDur != 0 && durationInMS != 0 && durationInMS < minDur * 1000) {
          return onMinDurTrigger();
        }

        final tags = trackInfo.tags;

        splittersConfigs ??= _createSplitConfig();

        final album = tags.album;
        final albumArtist = tags.albumArtist;
        final yearText = tags.year;

        // -- Split Artists
        final artists = splitArtist(
          title: tags.title,
          originalArtist: tags.artist,
          config: splittersConfigs.artistsConfig,
        );

        // -- Split Genres
        final genres = splitGenre(
          tags.genre,
          config: splittersConfigs.genresConfig,
        );

        // -- Split Moods
        final moods = splitGeneral(
          tags.mood,
          config: splittersConfigs.generalConfig,
        );

        // -- Split Tags
        final tagsEmbedded = splitGeneral(
          tags.tags,
          config: splittersConfigs.generalConfig,
        );

        String? trimOrNull(String? value) => value == null ? value : value.trimAll();
        String? nullifyEmpty(String? value) => value == '' ? null : value;
        String? doMagic(String? value) => nullifyEmpty(trimOrNull(value));

        finalTrackExtended = initialTrack.copyWith(
          title: doMagic(tags.title),
          originalArtist: doMagic(tags.artist),
          artistsList: artists,
          album: doMagic(tags.album),
          albumArtist: doMagic(tags.albumArtist),
          originalGenre: doMagic(tags.genre),
          genresList: genres,
          originalMood: doMagic(tags.mood),
          moodList: moods,
          composer: doMagic(tags.composer),
          trackNo: TrackExtended.parseTrackNumber(trackInfo.tags.trackNumber)?.$1,
          durationMS: durationInMS,
          year: TrackExtended.enforceYearFormat(yearText),
          yearText: yearText,
          comment: tags.comment,
          description: tags.description,
          synopsis: tags.synopsis,
          bitrate: trackInfo.bitRate,
          sampleRate: trackInfo.sampleRate,
          format: trackInfo.format,
          channels: trackInfo.channels,
          discNo: TrackExtended.parseTrackNumber(tags.discNumber)?.$1,
          language: tags.language,
          lyrics: tags.lyrics,
          label: tags.recordLabel,
          rating: tags.ratingPercentage,
          originalTags: tags.tags,
          tagsList: tagsEmbedded,
          albumIdentifierWrapper: AlbumIdentifierWrapper.normalize(
            album: album ?? '',
            albumArtist: albumArtist ?? '',
            year: yearText ?? '',
          ),
          gainData: tags.gainData,
          generatePathHash: TagsExtractor.defaultUniqueArtworkHash,
        );

        // ----- if the title || artist weren't found in the tag fields
        final isTitleEmpty = finalTrackExtended.title == UnknownTags.TITLE;
        final isArtistEmpty = finalTrackExtended.originalArtist == UnknownTags.ARTIST;
        if (isTitleEmpty || isArtistEmpty) {
          final extractedName = getTitleAndArtistFromFilename(trackPath.getFilenameWOExt);
          final newTitle = isTitleEmpty ? extractedName.$1 : null;
          final newArtists = isArtistEmpty ? [extractedName.$2] : null;
          finalTrackExtended = finalTrackExtended.copyWith(
            title: newTitle,
            originalArtist: newArtists?.first,
            artistsList: newArtists,
            generatePathHash: TagsExtractor.defaultUniqueArtworkHash,
          );
        }
      } else {
        // --- Adding dummy track with info extracted from filename.
        final titleAndArtist = getTitleAndArtistFromFilename(trackPath.getFilenameWOExt);
        final title = titleAndArtist.$1;
        final artist = titleAndArtist.$2;
        finalTrackExtended = initialTrack.copyWith(
          title: title,
          originalArtist: artist,
          artistsList: [artist],
          generatePathHash: TagsExtractor.defaultUniqueArtworkHash,
        );
      }

      return finalTrackExtended;
    } catch (e) {
      return onError(e.toString());
    }
  }

  Future<TrackExtended?> getTrackInfo({
    required String trackPath,
    int minDur = 0,
    int minSize = 0,
    required TrackExtended? Function() onMinDurTrigger,
    required TrackExtended? Function() onMinSizeTrigger,
    bool deleteOldArtwork = false,
    bool checkForDuplicates = true,
    bool tryExtractingFromFilename = true,
  }) async {
    final res = await NamidaTaggerController.inst.extractMetadata(
      trackPath: trackPath,
      overrideArtwork: deleteOldArtwork,
      isVideo: trackPath.isVideo(),
    );
    if (res.hasError) return null;
    return _convertTagToTrack(
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
    final skipAddingToTrackList = allTracksMappedByPath.containsKey(tr.path);
    allTracksMappedByPath[tr.path] = trackExt;
    unawaited(_tracksDBManager.put(tr.path, trackExt.toJsonWithoutPath()));
    allTracksMappedByYTID.addForce(trackExt.youtubeID, tr);
    _currentFileNamesMap[trackExt.path.getFilename] = true;

    if (!skipAddingToTrackList) {
      tracksInfoList.add(tr);
      SearchSortController.inst.trackSearchList.add(tr);
    }

    if (artwork != null && artwork.hasArtwork) {
      artworksInStorage.value++;
      if (artwork.size != null) artworksSizeInStorage.value += artwork.size!;
    }
  }

  /// Removes track entries from related lists, this doesNOT delete tracks from system or remove stats entries
  Future<void> onDeleteTracksFromStoragePermanently(List<Selectable> tracksToDelete) async {
    if (tracksToDelete.isEmpty) return;
    final recentlyDeltedFile = File("${AppDirs.RECENTLY_DELETED}${DateFormat('yyyy_MM_dd HH_mm_ss').format(DateTime.now())} - (${tracksToDelete.length}).txt");
    final recentlyDeltedFileWrite = recentlyDeltedFile.openWrite(mode: FileMode.writeOnlyAppend);
    tracksToDelete.loop(
      (trS) {
        final tr = trS.track;
        recentlyDeltedFileWrite.writeln(tr.path);
        _removeThisTrackFromAlbumGenreArtistEtc(tr);
        allTracksMappedByYTID.remove(tr.youtubeID);
        _currentFileNamesMap.remove(tr.path.getFilename);
        tracksInfoList.value.remove(tr);
        SearchSortController.inst.trackSearchList.value.remove(tr);
        SearchSortController.inst.trackSearchTemp.value.remove(tr);
        allTracksMappedByPath.remove(tr.path);
        unawaited(_tracksDBManager.delete(tr.path));
        TrackTileManager.rebuildTrackInfo(tr);
        this.scanMediaStore(tr.path);
      },
    );
    this.tracksInfoList.refresh();
    this.mainMapAlbums.refresh();
    this.mainMapArtists.refresh();
    this.mainMapAlbumArtists.refresh();
    this.mainMapComposer.refresh();
    this.mainMapGenres.refresh();
    this.mainMapFoldersTracksAndVideos.refresh();
    this.mainMapFoldersTracks.refresh();
    this.mainMapFoldersVideos.refresh();
    SearchSortController.inst.trackSearchList.refresh();
    SearchSortController.inst.trackSearchTemp.refresh();
    FoldersController.tracksAndVideos.currentFolder.refresh();
    FoldersController.tracks.currentFolder.refresh();
    FoldersController.videos.currentFolder.refresh();
    recentlyDeltedFileWrite.flush().then((_) => recentlyDeltedFileWrite.close());

    SearchSortController.inst.refreshPortsIfNecessary();
  }

  Future<void> reindexTracks({
    required List<T> tracks,
    bool updateArtwork = false,
    required void Function(bool didExtract) onProgress,
    required void Function(int tracksLength) onFinish,
    bool tryExtractingFromFilename = true,
  }) async {
    final tracksReal = <T>[];
    final tracksRealPaths = <String>[];
    final tracksMissing = <T>[];
    final finalNewOldTracks = <TrackExtended, TrackExtended?>{};
    await tracks.loopAsync((tr) async {
      bool exists = false;
      try {
        exists = await File(tr.path).exists();
      } catch (_) {}
      if (exists) {
        tracksReal.add(tr);
        tracksRealPaths.add(tr.path);
      } else {
        tracksMissing.add(tr);
      }
      TrackTileManager.rebuildTrackInfo(tr);
    });

    if (updateArtwork) {
      Indexer.clearMemoryImageCache();
    }

    tracksMissing.loop((e) => onProgress(false));

    final keyWrapper = ExtractingPathKey.create();
    final stream = await NamidaTaggerController.inst.extractMetadataAsStream(
      paths: tracksRealPaths,
      keyWrapper: keyWrapper,
      overrideArtwork: updateArtwork,
    );
    final splitConfigs = _createSplitConfig();
    await for (final item in stream) {
      final path = item.tags.path;
      final trext = await _convertTagToTrack(
        trackPath: path,
        trackInfo: item,
        tryExtractingFromFilename: tryExtractingFromFilename,
        onMinDurTrigger: () => null,
        onMinSizeTrigger: () => null,
        onError: (_) => null,
        splittersConfigs: splitConfigs,
      );
      if (item.hasError) {
        onProgress(false);
      } else {
        final tr = Track.orVideo(path);
        final oldTr = tr.toTrackExtOrNull();
        allTracksMappedByYTID.remove(tr.youtubeID);
        _currentFileNamesMap.remove(path.getFilename);
        // _removeThisTrackFromAlbumGenreArtistEtc(tr);
        if (trext != null) {
          finalNewOldTracks[trext] = oldTr;
          _addTrackToLists(trext, item.tags.artwork);
        }
        onProgress(true);
      }
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

    Future<TrackExtended?> extractFunction(FAudioModel item) => _convertTagToTrack(
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
      isVideo: trackPath.isVideo(),
    );
    final trext = await extractFunction(model);
    if (trext != null) {
      _addTrackToLists(trext, model.tags.artwork);
      _addTheseTracksToAlbumGenreArtistEtc({trext: null});
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
    int index = 0;
    void onPath(String path) {
      final infoInLib = allTracksMappedByPath[path];
      if (infoInLib != null) {
        finalTracks.add(infoInLib.asTrack() as T);
      } else {
        tracksToExtract.add(path);
      }
      orderLookup[path] = index;
      index++;
    }

    for (final path in tracksPathPre) {
      final isDir = await Directory(path).exists().ignoreError() ?? false;
      if (isDir) {
        final files = await Directory(path).listAllIsolate(recursive: true).ignoreError() ?? [];
        for (final f in files) {
          onPath(f.path);
        }
      } else {
        onPath(path);
      }
    }

    if (tracksToExtract.isNotEmpty) {
      final splitConfig = _createSplitConfig();

      Future<TrackExtended?> extractFunction(FAudioModel item) => _convertTagToTrack(
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
        keyWrapper: keyWrapper,
      );
      await for (final item in stream) {
        final p = item.tags.path;
        final obj = Track.orVideo(p);
        finalTracks.add(obj as T);
        final trext = await extractFunction(item);
        if (trext != null) {
          _addTrackToLists(trext, item.tags.artwork);
          finalNewOldTracks[trext] = null;
        }
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

  void _clearLists() {
    artworksInStorage.value = 0;
    artworksSizeInStorage.value = 0;
    tracksInfoList.clear();
    allTracksMappedByPath.clear();
    _clearTracksDBAndReOpen();
    allTracksMappedByYTID.clear();
    _currentFileNamesMap.clear();

    SearchSortController.inst.sortMedia(MediaType.track);
    SearchSortController.inst.refreshPortsIfNecessary();
  }

  void _resetCounters() {
    filteredForSizeDurationTracks.value = 0;
    duplicatedTracksLength.value = 0;
    tracksExcludedByNoMedia.value = 0;
  }

  /// Removes [deletedPaths] and fetches [audioFiles].
  ///
  /// [bypassAllChecks] will bypass `duration`, `size` & similar filenames checks.
  ///
  /// Setting [forceReIndex] to `true` will require u to call [_afterIndexing],
  /// otherwise use [_addTheseTracksToAlbumGenreArtistEtc] with changed tracks only.
  Future<void> _fetchAllSongsAndWriteToFile({
    required Set<String> audioFiles,
    required Set<String> deletedPaths,
    required bool forceReIndex,
    required bool useMediaStore,
  }) async {
    _resetCounters();

    if (forceReIndex) {
      _clearLists();
      if (!useMediaStore) audioFiles = await getAudioFiles();
    }

    printy("Audio Files New: ${audioFiles.length}");
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
      allTracksMappedByPath.clear();
      _clearTracksDBAndReOpen();
      allTracksMappedByYTID.clear();
      _currentFileNamesMap.clear();
      trs.loop((e) => _addTrackToLists(e, null));
    } else {
      NamidaTaggerController.inst.currentPathsBeingExtracted.clear();
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
      final listParts = (Platform.numberOfProcessors ~/ 2.5).withMinimum(1);
      final audioFilesParts = finalAudios.split(listParts);
      final audioFilesCompleters = List.generate(audioFilesParts.length, (_) => Completer<void>());
      final keyWrapper = ExtractingPathKey.create();

      Future<void> extractAll(List<String> chunkList) async {
        if (chunkList.isEmpty) return;

        final splittersConfigs = _createSplitConfig();
        Future<TrackExtended?> extractFunction(FAudioModel item) => _convertTagToTrack(
              trackPath: item.tags.path,
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
          paths: chunkList,
          keyWrapper: keyWrapper,
          overrideArtwork: false,
        );

        await for (final item in stream) {
          final trext = await extractFunction(item);
          if (trext != null) _addTrackToLists(trext, item.tags.artwork);
        }
      }

      audioFilesParts.loopAdv((part, partIndex) {
        extractAll(part).then((value) => audioFilesCompleters[partIndex].complete());
      });
      await Future.wait(audioFilesCompleters.map((e) => e.future).toList());
    }

    /// doing some checks to remove unqualified tracks.
    /// removes tracks after changing `duration` or `size`.
    tracksInfoList.removeWhere((tr) {
      final remove = (tr.durationMS != 0 && tr.durationMS < minDur * 1000) || tr.size < minSize;
      if (remove) unawaited(_tracksDBManager.delete(tr.path));
      return remove;
    });

    /// removes duplicated tracks after a refresh
    if (prevDuplicated) {
      final uniquedSet = <String>{};
      final lengthBefore = tracksInfoList.value.length;
      tracksInfoList.value.retainWhere((e) {
        final keep = uniquedSet.add(e.filename);
        if (!keep) unawaited(_tracksDBManager.delete(e.path));
        return keep;
      });
      final lengthAfter = tracksInfoList.value.length;
      final removedNumber = lengthBefore - lengthAfter;
      duplicatedTracksLength.value = removedNumber;
    }

    printy("FINAL: ${tracksInfoList.length}");

    _sortAndRefreshTracks();
    _createDefaultNamidaArtworkIfRequired();
    TrackTileManager.onTrackItemPropChange();
    SearchSortController.inst.refreshPortsIfNecessary();
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
    moodsPre.loop((m) {
      if (m.isNotEmpty && m != ' ') {
        final cleaned = m.trimAll();
        if (moodsFinalLookup[cleaned] == null) {
          moodsFinalLookup[cleaned] = true;
          moodsFinal.add(cleaned);
        }
      }
    });
    return moodsFinal;
  }

  /// Returns new [TrackStats].
  Future<TrackStats> updateTrackStats(
    Track track, {
    String? ratingString,
    String? tagsString,
    String? moodsString,
    int? lastPositionInMs,
  }) async {
    if (ratingString != null || tagsString != null || moodsString != null) {
      TrackTileManager.rebuildTrackInfo(track);
    }

    final rating = ratingString != null
        ? ratingString.isEmpty
            ? 0
            : int.tryParse(ratingString) ?? track.effectiveRating
        : track.effectiveRating;
    final tags = tagsString != null ? splitByCommaList(tagsString) : track.effectiveTags;
    final moods = moodsString != null ? splitByCommaList(moodsString) : track.effectiveMoods;
    lastPositionInMs ??= track.lastPlayedPositionInMs ?? 0;
    final newStats = TrackStats(
      track: track,
      rating: rating.clampInt(0, 100),
      tags: tags,
      moods: moods,
      lastPositionInMs: lastPositionInMs,
    );
    trackStatsMap[track] = newStats;
    unawaited(_trackStatsDBManager.put(track.path, newStats.toJsonWithoutTrack()));
    return newStats;
  }

  Future<void> _readTrackData([Completer<void>? completer]) async {
    tracksInfoList.clear(); // clearing for cases which refreshing library is required (like after changing separators)

    final mediaSorters = <MediaType, List<Comparable<dynamic> Function(Track)>>{};
    final mediaSortersNOTSafeInIsolate = _getMediaTypeSortThatDependOnHistory();
    final mediaSortersReverse = settings.mediaItemsTrackSortingReverse.value;

    for (final e in MediaType.values) {
      if (!mediaSortersNOTSafeInIsolate.contains(e)) {
        mediaSorters[e] = SearchSortController.inst.getMediaTracksSortingComparables(e);
      }
    }

    final tracksRecievePort = ReceivePort();

    Future<void> handleRecieveTracks() async {
      try {
        final value = await tracksRecievePort.first;
        value as _TracksLoadResult;
        allTracksMappedByPath = value.allTracksMappedByPath;
        allTracksMappedByYTID = value.allTracksMappedByYTID as Map<String, List<T>>;
        tracksInfoList.value = value.tracksInfoList as List<T>;
        this.sortMediaTracksSubLists([MediaType.track]);
        completer?.completeIfWasnt();
      } catch (e, st) {
        completer?.completeErrorIfWasnt(e, st);
      } finally {
        tracksRecievePort.close();
      }
    }

    await [
      _IndexerIsolateExecuter._readTrackStatsDataSync.thready([AppPaths.TRACKS_STATS_DB_INFO, AppPaths.TRACKS_STATS_OLD]).then(
        (res) {
          trackStatsMap.value = res;
        },
      ),
      _IndexerIsolateExecuter._readTracksDataSync.thready([
        AppPaths.TRACKS_DB_INFO,
        AppPaths.TRACKS_OLD,
        _createSplitConfig(),
        mediaSorters,
        mediaSortersReverse,
        settings.albumIdentifiers.value,
        TagsExtractor.defaultUniqueArtworkHash,
        tracksRecievePort.sendPort,
      ]).then(
        (libraryGroup) async {
          mainMapsGroup.updateFrom(libraryGroup);

          FoldersController.tracksAndVideos.onMapChanged(mainMapFoldersTracksAndVideos.value);
          FoldersController.tracksAndVideos.onFirstLoad();

          FoldersController.tracks.onMapChanged(mainMapFoldersTracks.value);
          FoldersController.tracks.onFirstLoad();
          FoldersController.videos.onMapChanged(mainMapFoldersVideos.value);
          FoldersController.videos.onFirstLoad();

          _refreshMediaTracksSubListsAfterSort(mediaSorters.keys);

          SearchSortController.inst.refreshPortsIfNecessary(); // -- vip to refresh filtering
        },
      ),
      handleRecieveTracks(),
    ].executeAllAndSilentReportErrors();

    printy("All Tracks Length From File: ${tracksInfoList.length}");
  }

  static List<String> splitArtist({
    required String? title,
    required String? originalArtist,
    required ArtistsSplitConfig config,
  }) {
    final allArtists = <String>{};

    final artistsOrg = config.splitText(originalArtist, fallback: UnknownTags.ARTIST);
    allArtists.addAll(artistsOrg);

    if (config.addFeatArtist) {
      final List<String>? moreArtists = title?.split(RegExp(r'\(ft\. |\[ft\. |\(feat\. |\[feat\. \]', caseSensitive: false));
      if (moreArtists != null && moreArtists.length > 1) {
        final extractedFeatArtists = moreArtists[1].split(RegExp(r'\)|\]')).first;
        final artists = config.splitText(extractedFeatArtists, fallback: null);
        allArtists.addAll(artists);
      }
    }
    return allArtists.toList();
  }

  static List<String> splitGenre(
    String? originalGenre, {
    required GenresSplitConfig config,
  }) {
    return config.splitText(
      originalGenre,
      fallback: UnknownTags.GENRE,
    );
  }

  static List<String> splitGeneral(
    String? originalText, {
    required SplitterConfig config,
  }) {
    return config.splitText(
      originalText,
      fallback: null,
    );
  }

  /// (title, artist)
  static (String, String) getTitleAndArtistFromFilename(String filename) {
    final filenameWOEx = filename.replaceAll('_', ' ');
    List<String> titleAndArtist;

    /// preferring to split by [' - '], since there are artists that has '-' in their name.
    titleAndArtist = filenameWOEx.split(' - ');
    if (titleAndArtist.length == 1) {
      titleAndArtist = filenameWOEx.split('-');
    }

    /// in case splitting produced 2 entries or more, it means its high likely to be [artist - title]
    /// otherwise [title] will be the [filename] and [artist] will be [Unknown]
    final title = titleAndArtist.length >= 2 ? titleAndArtist[1].trimAll() : filenameWOEx;
    final artist = titleAndArtist.length >= 2 ? titleAndArtist[0].trimAll() : UnknownTags.ARTIST;

    // TODO: split by ( and ) too, but retain Remixes and feat.
    final cleanedUpTitle = title.splitFirst('[').trimAll();
    final cleanedUpArtist = artist.splitLast(']').trimAll();

    return (cleanedUpTitle, cleanedUpArtist);
  }

  Set<String> getNewFoundPaths(Set<String> currentFiles) => currentFiles.difference(Set.of(tracksInfoList.value.map((t) => t.path)));
  Set<String> getDeletedPaths(Set<String> currentFiles) => Set.of(tracksInfoList.value.map((t) => t.path)).difference(currentFiles);

  /// [strictNoMedia] forces all subdirectories to follow the same result of the parent.
  ///
  /// ex: if (.nomedia) was found in [/storage/0/Music/],
  /// then subdirectories [/storage/0/Music/folder1/], [/storage/0/Music/folder2/] & [/storage/0/Music/folder2/subfolder/] will be excluded too.
  Future<Set<String>> getAudioFiles({bool strictNoMedia = true}) async {
    tracksExcludedByNoMedia.value = 0;

    final extensions = _includeVideosAsTracks ? NamidaFileExtensionsWrapper.audioAndVideo : NamidaFileExtensionsWrapper.audio;
    final dirsFilterer = DirsFileFilter(
      directoriesToExclude: settings.directoriesToExclude.value,
      extensions: extensions,
      imageExtensions: NamidaFileExtensionsWrapper.image,
      strictNoMedia: strictNoMedia,
    );
    final result = await dirsFilterer.filter();

    final allPaths = result.allPaths;

    allAudioFiles.value = allPaths;
    tracksExcludedByNoMedia.value += result.excludedByNoMedia.length;
    allFolderCovers = result.folderCovers;

    printy("Paths Found: ${allPaths.length}");
    return allPaths;
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
    allMusic.retainWhere((element) =>
        settings.directoriesToExclude.value.every((dir) => !element.data.startsWith(dir)) /* && settings.directoriesToScan.any((dir) => element.data.startsWith(dir)) */);
    final tracks = <TrackExtended>[];
    final artistsSplitConfig = ArtistsSplitConfig.settings();
    final genresSplitConfig = GenresSplitConfig.settings();
    final generalSplitConfig = GeneralSplitConfig();

    final int length = allMusic.length;
    for (int i = 0; i < length; i++) {
      var e = allMusic[i];

      final map = e.getMap;
      final album = e.album;
      final albumArtist = map['album_artist'] as String?;
      final artist = e.artist;
      final artists = artist == null
          ? <String>[]
          : Indexer.splitArtist(
              title: e.title,
              originalArtist: artist,
              config: artistsSplitConfig,
            );
      final genre = e.genre;
      final genres = genre == null
          ? <String>[]
          : Indexer.splitGenre(
              genre,
              config: genresSplitConfig,
            );
      final mood = map['mood'];
      final moods = mood == null
          ? <String>[]
          : Indexer.splitGeneral(
              mood,
              config: generalSplitConfig,
            );
      final tag = map['tag'] ?? map['tags'];
      final tags = tag == null
          ? <String>[]
          : Indexer.splitGeneral(
              tag,
              config: generalSplitConfig,
            );
      final bitrate = map['bitrate'] as int?;
      final disc = map['disc_number'] as int?;
      final yearString = map['year'] as String?;
      final path = e.data;
      final trext = TrackExtended(
        title: e.title,
        originalArtist: e.artist ?? UnknownTags.ARTIST,
        artistsList: artists,
        album: album ?? UnknownTags.ALBUM,
        albumArtist: albumArtist ?? UnknownTags.ALBUMARTIST,
        originalGenre: e.genre ?? UnknownTags.GENRE,
        genresList: genres,
        originalMood: mood ?? '',
        moodList: moods,
        composer: e.composer ?? '',
        trackNo: e.track ?? 0,
        durationMS: e.duration ?? 0, // `e.duration` => milliseconds
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
        format: '',
        channels: '',
        discNo: disc ?? 0,
        language: '',
        lyrics: '',
        label: '',
        rating: 0.0,
        originalTags: tag,
        tagsList: tags,
        gainData: null,
        albumIdentifierWrapper: AlbumIdentifierWrapper.normalize(
          album: album ?? '',
          albumArtist: albumArtist ?? '',
          year: yearString ?? '',
        ),
        isVideo: e.data.isVideo(),
        hashKey: TrackExtended.generateHashKeyIfEnabled(null, path, null),
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
    final stats = await _caclulateDirectoryInfoIsolate.thready({
      "dirPath": AppDirs.ARTWORKS,
      "token": RootIsolateToken.instance,
    });
    artworksInStorage.value = stats.$1;
    artworksSizeInStorage.value = stats.$2;
  }

  static (int, int) _caclulateDirectoryInfoIsolate(Map p) {
    final dirPath = p["dirPath"] as String;
    final token = p["token"] as RootIsolateToken;
    BackgroundIsolateBinaryMessenger.ensureInitialized(token);

    int totalCount = 0;
    int totalSize = 0;

    void calDirRecursive(Directory dir) {
      dir.listSyncSafe().loop((f) {
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
      });
    }

    calDirRecursive(Directory(dirPath));

    return (totalCount, totalSize);
  }

  // static int _caclulateDirectoryCountIsolate(String dirPath) {
  //   int totalCount = 0;

  //   void calDirRecursive(Directory dir) {
  //     dir.listSyncSafe().loop((f) {
  //       if (f is File) {
  //         totalCount++;
  //       } else {
  //         try {
  //           calDirRecursive(f as Directory);
  //         } catch (_) {}
  //       }
  //     });
  //   }

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
    _createDefaultNamidaArtworkIfRequired();
    calculateAllImageSizesInStorage();
  }

  Future<void> _createDefaultNamidaArtworkIfRequired() async {
    if (!await File(AppPaths.NAMIDA_LOGO_MONET).exists()) {
      final byteData = await rootBundle.load('assets/namida_icon_monet.png');
      final file = await File(AppPaths.NAMIDA_LOGO_MONET).create(recursive: true);
      await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    }
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

extension _OrderedInsert<T> on List<T> {
  void insertWithOrder(T item, int Function(T a, T b) compare) {
    int left = 0;
    int right = length - 1;

    while (left <= right) {
      int mid = (left + right) ~/ 2;
      var midItem = this[mid];
      if (midItem == item) {
        // -- If the string is already in the list, dont do anything
        return;
      } else if (compare(midItem, item) < 0) {
        left = mid + 1;
      } else {
        right = mid - 1;
      }
    }

    // If the string is not in the list, insert it at the appropriate position
    insert(left, item);
  }
}

class _IndexerIsolateExecuter {
  /// reading stats db containing track rating etc.
  static Future<Map<Track, TrackStats>> _readTrackStatsDataSync(List paramsList) async {
    final statsDbInfo = paramsList[0] as DbWrapperFileInfo;
    final oldJsonFilePath = paramsList[1] as String;

    NamicoDBWrapper.initialize();
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
          for (int i = 0; i < list.length; i++) {
            try {
              final item = list[i];
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
  static Future<LibraryGroup<Track>> _readTracksDataSync(List paramsList) async {
    final tracksDbInfo = paramsList[0] as DbWrapperFileInfo;
    final oldJsonFilePath = paramsList[1] as String;
    final splitconfig = paramsList[2] as SplitArtistGenreConfigsWrapper;
    final mediaItemsTrackSorters = paramsList[3] as Map<MediaType, List<Comparable<dynamic> Function(Track)>>;
    final mediaItemsTrackSortingReverse = paramsList[4] as Map<MediaType, bool>;
    final albumIdentifiers = paramsList[5] as List<AlbumIdentifier>;
    final generatePathHash = paramsList[6] as bool? ?? false;
    final tracksInitPort = paramsList[7] as SendPort;

    NamicoDBWrapper.initialize();
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

    try {
      tracksDBManager!.loadEverythingKeyed(
        (path, item) {
          final trExt = TrackExtended.fromJson(
            path,
            item,
            artistsSplitConfig: splitconfig.artistsConfig,
            genresSplitConfig: splitconfig.genresConfig,
            generalSplitConfig: splitconfig.generalConfig,
          );
          final track = trExt.asTrack();
          allTracksMappedByPath[track.path] = trExt;
          tracksInfoList.add(track);
          allTracksMappedByYTID.addForce(trExt.youtubeID, track);
        },
      );

      // -- migrating tracks json to db
      final tracksJsonFile = File(oldJsonFilePath);
      if (tracksJsonFile.existsSync()) {
        final list = tracksJsonFile.readAsJsonSync() as List?;
        if (list != null) {
          for (int i = 0; i < list.length; i++) {
            try {
              final item = list[i];
              final trExt = TrackExtended.fromJson(
                item['path'] ?? '',
                item,
                artistsSplitConfig: splitconfig.artistsConfig,
                genresSplitConfig: splitconfig.genresConfig,
                generalSplitConfig: splitconfig.generalConfig,
              );
              final track = trExt.asTrack();
              allTracksMappedByPath[track.path] = trExt;
              tracksInfoList.add(track);
              allTracksMappedByYTID.addForce(trExt.youtubeID, track);
              tracksDBManager.put(track.path, trExt.toJsonWithoutPath());
            } catch (_) {}
          }
        }
        tracksJsonFile.deleteSync();
      }
    } catch (_) {}
    tracksDBManager?.close();

    tracksInitPort.send(
      _TracksLoadResult(
        tracksInfoList: tracksInfoList,
        allTracksMappedByPath: allTracksMappedByPath,
        allTracksMappedByYTID: allTracksMappedByYTID,
      ),
    );

    // -- so that sorting works, the Indexer here is local to this isolate only
    Indexer.inst.allTracksMappedByPath = allTracksMappedByPath;
    Indexer.inst.tracksInfoList.value = tracksInfoList;
    Indexer.inst.allTracksMappedByYTID = allTracksMappedByYTID;

    final libraryGroup = LibraryGroup();
    libraryGroup.fillAll(
      tracksInfoList,
      (tr) =>
          allTracksMappedByPath[tr.path] ??
          kDummyExtendedTrack.copyWith(
            title: tr.path.getFilenameWOExt,
            path: tr.path,
            generatePathHash: generatePathHash,
          ),
      albumIdentifiers,
    );

    libraryGroup.sortAllSync(
      mediaItemsTrackSorters,
      mediaItemsTrackSortingReverse,
      tracksInfoList,
    );

    return libraryGroup;
  }
}

class _TracksLoadResult {
  final List<Track> tracksInfoList;
  final Map<String, TrackExtended> allTracksMappedByPath;
  final Map<String, List<Track>> allTracksMappedByYTID;

  const _TracksLoadResult({
    required this.tracksInfoList,
    required this.allTracksMappedByPath,
    required this.allTracksMappedByYTID,
  });
}
