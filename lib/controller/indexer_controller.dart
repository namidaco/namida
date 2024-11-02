import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:audio_service/audio_service.dart';
import 'package:intl/intl.dart';
import 'package:namico_db_wrapper/namico_db_wrapper.dart';
import 'package:on_audio_query/on_audio_query.dart';

import 'package:namida/class/faudiomodel.dart';
import 'package:namida/class/file_parts.dart';
import 'package:namida/class/folder.dart';
import 'package:namida/class/library_item_map.dart';
import 'package:namida/class/split_config.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/folders_controller.dart';
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
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';

class Indexer<T extends Track> {
  static Indexer get inst => _instance;
  static final Indexer _instance = Indexer._internal();
  Indexer._internal();

  bool get _defaultUseMediaStore => settings.useMediaStore.value;
  bool get _includeVideosAsTracks => true; // TODO: settings.includeVideosAsTracks.value

  late final _trackStatsDBManager = DBWrapper.openFromInfo(fileInfo: AppPaths.TRACKS_STATS_DB_INFO, createIfNotExist: true);

  final isIndexing = false.obs;

  final allAudioFiles = <String>{}.obs;
  final filteredForSizeDurationTracks = 0.obs;
  final duplicatedTracksLength = 0.obs;
  final tracksExcludedByNoMedia = 0.obs;

  final artworksInStorage = 0.obs;
  final colorPalettesInStorage = 0.obs;

  final artworksSizeInStorage = 0.obs;

  final mainMapAlbums = LibraryItemMap();
  final mainMapArtists = LibraryItemMap();
  final mainMapAlbumArtists = LibraryItemMap();
  final mainMapComposer = LibraryItemMap();
  final mainMapGenres = LibraryItemMap();
  final mainMapFolders = <Folder, List<T>>{}.obs;
  final mainMapFoldersVideos = <VideoFolder, List<Video>>{}.obs;

  final RxList<T> tracksInfoList = <T>[].obs;

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

  Map<String, (Track, int)> get backupMediaStoreIDS => _backupMediaStoreIDS;

  bool imageObtainedBefore(String imagePath) => _artworksMap[imagePath] != null || _artworksMapFullRes[imagePath] != null;

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
        filename = TagsExtractor.getArtworkIdentifier(albumName: trExt?.album, albumArtist: trExt?.albumArtist, year: trExt?.year.toString(), identifiers: identifiersSet);
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
            size: size?.clamp(48, 360) ?? 360,
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

  void prepareTracksFile() {
    _fetchMediaStoreTracks(); // to fill ids map

    /// Only awaits if the track file exists, otherwise it will get into normally and start indexing.
    if (File(AppPaths.TRACKS).existsAndValidSync()) {
      _readTrackData();
      _afterIndexing();
    }

    /// doesnt exists
    else {
      File(AppPaths.TRACKS).createSync();
      refreshLibraryAndCheckForDiff(forceReIndex: true, useMediaStore: _defaultUseMediaStore);
    }
  }

  void rebuildTracksAfterSplitConfigChanges() {
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
      );
    }
    _afterIndexing();
    tracksInfoList.refresh();
  }

  void rebuildTracksAfterExtractFeatArtistChanges() {
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
      );
    }
    _afterIndexing();
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

    _afterIndexing();
    isIndexing.value = false;
    if (showFinishedSnackbar) snackyy(title: lang.DONE, message: lang.FINISHED_UPDATING_LIBRARY);
  }

  /// Adds all tracks inside [tracksInfoList] to their respective album, artist, etc..
  /// & sorts all media.
  void _afterIndexing() {
    this.mainMapAlbums.clear();
    this.mainMapArtists.clear();
    this.mainMapAlbumArtists.clear();
    this.mainMapComposer.clear();
    this.mainMapGenres.clear();
    this.mainMapFolders.clear();
    this.mainMapFoldersVideos.clear();

    final mainMapAlbums = this.mainMapAlbums.value;
    final mainMapArtists = this.mainMapArtists.value;
    final mainMapAlbumArtists = this.mainMapAlbumArtists.value;
    final mainMapComposer = this.mainMapComposer.value;
    final mainMapGenres = this.mainMapGenres.value;
    final mainMapFolders = this.mainMapFolders.value;
    final mainMapFoldersVideos = this.mainMapFoldersVideos.value;

    // --- Sorting All Sublists ---
    tracksInfoList.loop((tr) {
      final trExt = tr.toTrackExt();

      // -- Assigning Albums
      mainMapAlbums.addForce(trExt.albumIdentifier, tr);

      // -- Assigning Artists
      trExt.artistsList.loop((artist) {
        mainMapArtists.addForce(artist, tr);
      });

      // -- Assigning Album Artist
      mainMapAlbumArtists.addForce(trExt.albumArtist, tr);

      // -- Assigning Composer
      mainMapComposer.addForce(trExt.composer, tr);

      // -- Assigning Genres
      trExt.genresList.loop((genre) {
        mainMapGenres.addForce(genre, tr);
      });

      // -- Assigning Folders
      tr is Video ? mainMapFoldersVideos.addForce(tr.folder, tr) : mainMapFolders.addForce(tr.folder, tr);
    });

    this.mainMapAlbums.refresh();
    this.mainMapArtists.refresh();
    this.mainMapAlbumArtists.refresh();
    this.mainMapComposer.refresh();
    this.mainMapGenres.refresh();
    this.mainMapFolders.refresh();
    this.mainMapFoldersVideos.refresh();

    Folders.tracks.onMapChanged(mainMapFolders);
    Folders.videos.onMapChanged(mainMapFoldersVideos);
    _sortAll();
    sortMediaTracksSubLists(MediaType.values);
  }

  void sortMediaTracksSubLists(List<MediaType> medias) {
    medias.loop((e) {
      final sorters = SearchSortController.inst.getMediaTracksSortingComparables(e);
      void sortPls<Tr extends Track>(Iterable<List<Tr>> trs, MediaType type) {
        final reverse = settings.mediaItemsTrackSortingReverse.value[type] ?? false;
        if (reverse) {
          for (final e in trs) {
            e.sortByReverseAlts(sorters);
          }
        } else {
          for (final e in trs) {
            e.sortByAlts(sorters);
          }
        }
      }

      switch (e) {
        case MediaType.album:
          sortPls(mainMapAlbums.value.values, MediaType.album);
          mainMapAlbums.refresh();
          break;
        case MediaType.artist:
          sortPls(mainMapArtists.value.values, MediaType.artist);
          mainMapArtists.refresh();
          break;
        case MediaType.albumArtist:
          sortPls(mainMapAlbumArtists.value.values, MediaType.albumArtist);
          mainMapAlbumArtists.refresh();
          break;
        case MediaType.composer:
          sortPls(mainMapComposer.value.values, MediaType.composer);
          mainMapComposer.refresh();
          break;
        case MediaType.genre:
          sortPls(mainMapGenres.value.values, MediaType.genre);
          mainMapGenres.refresh();
          break;
        case MediaType.folder:
          sortPls(mainMapFolders.values, MediaType.folder);
          mainMapFolders.refresh();
          Folders.tracks.refreshLists();
          break;
        case MediaType.folderVideo:
          sortPls(mainMapFoldersVideos.values, MediaType.folderVideo);
          mainMapFoldersVideos.refresh();
          Folders.videos.refreshLists();
          break;
        default:
          null;
      }
    });
  }

  /// re-sorts media subtracks that depend on history.
  void sortMediaTracksAndSubListsAfterHistoryPrepared() {
    bool dependsOnHistory(SortType type) => type == SortType.mostPlayed || type == SortType.latestPlayed || type == SortType.firstListen;

    final tracksSort = settings.tracksSort.value;
    if (dependsOnHistory(tracksSort)) {
      SearchSortController.inst.sortMedia(MediaType.track);
    }

    final requiredToSort = <MediaType>[];
    for (final e in settings.mediaItemsTrackSorting.entries) {
      for (final sort in e.value) {
        if (dependsOnHistory(sort)) {
          requiredToSort.add(e.key);
          break;
        }
      }
    }
    sortMediaTracksSubLists(requiredToSort);
  }

  void _sortAll() => SearchSortController.inst.sortAll();

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
    tr is Video ? mainMapFoldersVideos[tr.folder]?.remove(tr) : mainMapFolders[tr.folder]?.remove(tr);

    _currentFileNamesMap.remove(tr.filename);
  }

  void _addTheseTracksToAlbumGenreArtistEtc(List<T> tracks) {
    final mainMapAlbums = this.mainMapAlbums.value;
    final mainMapArtists = this.mainMapArtists.value;
    final mainMapAlbumArtists = this.mainMapAlbumArtists.value;
    final mainMapComposer = this.mainMapComposer.value;
    final mainMapGenres = this.mainMapGenres.value;
    final mainMapFolders = this.mainMapFolders.value;
    final mainMapFoldersVideos = this.mainMapFoldersVideos.value;

    final List<String> addedAlbums = [];
    final List<String> addedArtists = [];
    final List<String> addedAlbumArtists = [];
    final List<String> addedComposers = [];
    final List<String> addedGenres = [];
    final List<Folder> addedFolders = [];
    final List<VideoFolder> addedFoldersVideos = [];

    tracks.loop((tr) {
      final trExt = tr.toTrackExt();

      // -- Assigning Albums
      mainMapAlbums.addNoDuplicatesForce(trExt.albumIdentifier, tr);

      // -- Assigning Artists
      trExt.artistsList.loop((artist) {
        mainMapArtists.addNoDuplicatesForce(artist, tr);
      });
      mainMapAlbumArtists.addNoDuplicatesForce(trExt.albumArtist, tr);
      mainMapComposer.addNoDuplicatesForce(trExt.composer, tr);

      // -- Assigning Genres
      trExt.genresList.loop((genre) {
        mainMapGenres.addNoDuplicatesForce(genre, tr);
      });

      // -- Assigning Folders
      tr is Video ? mainMapFoldersVideos.addNoDuplicatesForce(tr.folder, tr) : mainMapFolders.addNoDuplicatesForce(tr.folder, tr);

      // --- Adding media that was affected
      addedAlbums.add(trExt.albumIdentifier);
      addedArtists.addAll(trExt.artistsList);
      addedAlbumArtists.add(trExt.albumArtist);
      addedComposers.add(trExt.composer);
      addedGenres.addAll(trExt.artistsList);
      tr is Video ? addedFoldersVideos.add(tr.folder) : addedFolders.add(tr.folder);
    });

    final albumSorters = SearchSortController.inst.getMediaTracksSortingComparables(MediaType.album);
    final artistSorters = SearchSortController.inst.getMediaTracksSortingComparables(MediaType.artist);
    final genreSorters = SearchSortController.inst.getMediaTracksSortingComparables(MediaType.genre);
    final folderSorters = SearchSortController.inst.getMediaTracksSortingComparables(MediaType.folder);
    final folderVideosSorters = SearchSortController.inst.getMediaTracksSortingComparables(MediaType.folderVideo);

    void cleanyLoopy<A, E>(MediaType type, List<E> added, Map<E, List<A>> map, List<Comparable<dynamic> Function(A tr)> sorters) {
      if (added.isEmpty) return;
      added.removeDuplicates();

      final reverse = settings.mediaItemsTrackSortingReverse.value[type] ?? false;
      if (reverse) {
        added.loop((e) => map[e]?.sortByReverseAlts(sorters));
      } else {
        added.loop((e) => map[e]?.sortByAlts(sorters));
      }
    }

    cleanyLoopy(MediaType.album, addedAlbums, mainMapAlbums, albumSorters);
    cleanyLoopy(MediaType.artist, addedArtists, mainMapArtists, artistSorters);
    cleanyLoopy(MediaType.albumArtist, addedAlbumArtists, mainMapAlbumArtists, artistSorters);
    cleanyLoopy(MediaType.composer, addedComposers, mainMapComposer, artistSorters);
    cleanyLoopy(MediaType.genre, addedGenres, mainMapGenres, genreSorters);
    cleanyLoopy(MediaType.folder, addedFolders, mainMapFolders, folderSorters);
    cleanyLoopy(MediaType.folderVideo, addedFoldersVideos, mainMapFoldersVideos, folderVideosSorters);

    Folders.tracks.onMapChanged(mainMapFolders);
    Folders.videos.onMapChanged(mainMapFoldersVideos);
    _sortAll();
  }

  TrackExtended? _convertTagToTrack({
    required String trackPath,
    required FAudioModel trackInfo,
    required bool tryExtractingFromFilename,
    int minDur = 0,
    int minSize = 0,
    required TrackExtended? Function() onMinDurTrigger,
    required TrackExtended? Function() onMinSizeTrigger,
    required TrackExtended? Function(String err) onError,
    SplitArtistGenreConfigsWrapper? splittersConfigs,
  }) {
    // -- most methods dont throw, except for timeout
    try {
      // -- returns null early depending on size [byte] or duration [seconds]
      FileStat? fileStat;
      try {
        fileStat = File(trackPath).statSync();
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
        isVideo: trackPath.isVideo(),
      );
      if (!trackInfo.hasError) {
        int durationInMS = trackInfo.durationMS ?? 0;
        if (minDur != 0 && durationInMS != 0 && durationInMS < minDur * 1000) {
          return onMinDurTrigger();
        }

        final tags = trackInfo.tags;

        splittersConfigs ??= _createSplitConfig();

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
          year: TrackExtended.enforceYearFormat(tags.year),
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
          gainData: tags.gainData,
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

  void _addTrackToLists(TrackExtended trackExt, bool checkForDuplicates, FArtwork? artwork) {
    final tr = trackExt.asTrack() as T;
    allTracksMappedByPath[tr.path] = trackExt;
    allTracksMappedByYTID.addForce(trackExt.youtubeID, tr);
    _currentFileNamesMap[trackExt.path.getFilename] = true;
    if (checkForDuplicates) {
      tracksInfoList.addNoDuplicates(tr);
      SearchSortController.inst.trackSearchList.addNoDuplicates(tr);
    } else {
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
    final recentlyDeltedFileWrite = recentlyDeltedFile.openWrite(mode: FileMode.append);
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
      },
    );
    SearchSortController.inst.trackSearchList.refresh();
    SearchSortController.inst.trackSearchTemp.refresh();
    Folders.tracks.currentFolder.refresh();
    Folders.videos.currentFolder.refresh();
    await _saveTrackFileToStorage();
    recentlyDeltedFileWrite.flush().then((_) => recentlyDeltedFileWrite.close());
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
    tracks.loop((tr) {
      bool exists = false;
      try {
        exists = File(tr.path).existsSync();
      } catch (_) {}
      if (exists) {
        tracksReal.add(tr);
        tracksRealPaths.add(tr.path);
      } else {
        tracksMissing.add(tr);
      }
    });

    if (updateArtwork) {
      imageCache.clear();
      imageCache.clearLiveImages();
      AudioService.evictArtworkCache();
    }

    tracksMissing.loop((e) => onProgress(false));

    final stream = await NamidaTaggerController.inst.extractMetadataAsStream(
      paths: tracksRealPaths,
      overrideArtwork: updateArtwork,
    );
    final splitConfigs = _createSplitConfig();
    await for (final item in stream) {
      final path = item.tags.path;
      final trext = _convertTagToTrack(
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
        allTracksMappedByYTID.remove(tr.youtubeID);
        _currentFileNamesMap.remove(path.getFilename);
        _removeThisTrackFromAlbumGenreArtistEtc(tr);
        if (trext != null) _addTrackToLists(trext, true, item.tags.artwork);
        onProgress(true);
      }
    }

    final finalTrack = <T>[];
    tracksReal.loop((p) {
      if (p.hasInfoInLibrary()) finalTrack.add(p);
    });
    _addTheseTracksToAlbumGenreArtistEtc(finalTrack);
    Player.inst.refreshNotification();
    await _sortAndSaveTracks();
    onFinish(finalTrack.length);
  }

  Future<void> updateTrackMetadata({
    required Map<T, TrackExtended> tracksMap,
    bool artworkWasEdited = true,
  }) async {
    final oldTracks = <T>[];
    final newTracks = <T>[];

    if (artworkWasEdited) {
      imageCache.clear();
      imageCache.clearLiveImages();
      AudioService.evictArtworkCache();
    }

    for (final e in tracksMap.entries) {
      final ot = e.key;
      final nt = e.value.asTrack() as T;
      oldTracks.add(ot);
      newTracks.add(nt);
      allTracksMappedByPath[ot.path] = e.value;
      allTracksMappedByYTID.addForce(e.value.youtubeID, ot);
      _currentFileNamesMap.remove(ot.filename);
      _currentFileNamesMap[nt.filename] = true;

      if (artworkWasEdited) {
        // artwork extraction is not our business
        CurrentColor.inst.reExtractTrackColorPalette(track: ot, newNC: null, imagePath: ot.pathToImage);
      }
    }
    oldTracks.loop((tr) => _removeThisTrackFromAlbumGenreArtistEtc(tr));
    _addTheseTracksToAlbumGenreArtistEtc(newTracks);
    await _sortAndSaveTracks();
  }

  Future<List<T>> convertPathsToTracksAndAddToLists(Iterable<String> tracksPathPre) async {
    final finalTracks = <T>[];
    final tracksToExtract = <String>[];

    final orderLookup = <String, int>{};
    int index = 0;
    for (final path in tracksPathPre) {
      final infoInLib = allTracksMappedByPath[path];
      if (infoInLib != null) {
        finalTracks.add(infoInLib.asTrack() as T);
      } else {
        tracksToExtract.add(path);
      }
      orderLookup[path] = index;
      index++;
    }

    bool saveToFile = false;

    if (tracksToExtract.isNotEmpty) {
      saveToFile = true;

      final splitConfig = _createSplitConfig();

      TrackExtended? extractFunction(FAudioModel item) => _convertTagToTrack(
            trackPath: item.tags.path,
            trackInfo: item,
            tryExtractingFromFilename: true,
            onMinDurTrigger: () => null,
            onMinSizeTrigger: () => null,
            onError: (_) => null,
            splittersConfigs: splitConfig,
          );

      final stream = await NamidaTaggerController.inst.extractMetadataAsStream(paths: tracksToExtract);
      await for (final item in stream) {
        final p = item.tags.path;
        final obj = Track.orVideo(p);
        finalTracks.add(obj as T);
        final trext = extractFunction(item);
        if (trext != null) _addTrackToLists(trext, true, item.tags.artwork);
      }
    }

    _addTheseTracksToAlbumGenreArtistEtc(finalTracks);
    if (saveToFile) await _sortAndSaveTracks();

    finalTracks.sortBy((e) => orderLookup[e.path] ?? 0);
    return finalTracks;
  }

  Future<void> _sortAndSaveTracks() async {
    Player.inst.refreshRxVariables();
    Player.inst.refreshNotification();
    SearchSortController.inst.searchAll(ScrollSearchController.inst.searchTextEditingController.text);
    SearchSortController.inst.sortMedia(MediaType.track);
    await _saveTrackFileToStorage();
    await _createDefaultNamidaArtwork();
  }

  void _clearLists() {
    artworksInStorage.value = 0;
    artworksSizeInStorage.value = 0;
    tracksInfoList.clear();
    allTracksMappedByPath.clear();
    allTracksMappedByYTID.clear();
    _currentFileNamesMap.clear();
    SearchSortController.inst.sortMedia(MediaType.track);
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
      tracksInfoList.removeWhere((tr) => deletedPaths.contains(tr.path));
    }

    final minDur = settings.indexMinDurationInSec.value; // Seconds
    final minSize = settings.indexMinFileSizeInB.value; // bytes
    final prevDuplicated = settings.preventDuplicatedTracks.value;
    if (useMediaStore) {
      final trs = await _fetchMediaStoreTracks();
      tracksInfoList.clear();
      allTracksMappedByPath.clear();
      allTracksMappedByYTID.clear();
      _currentFileNamesMap.clear();
      trs.loop((e) => _addTrackToLists(e.$1, false, null));
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

      Future<void> extractAll(List<String> chunkList) async {
        if (chunkList.isEmpty) return;

        final splittersConfigs = _createSplitConfig();
        TrackExtended? extractFunction(FAudioModel item) => _convertTagToTrack(
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
          overrideArtwork: false,
        );

        await for (final item in stream) {
          final trext = extractFunction(item);
          if (trext != null) _addTrackToLists(trext, false, item.tags.artwork);
        }
      }

      audioFilesParts.loopAdv((part, partIndex) {
        extractAll(part).then((value) => audioFilesCompleters[partIndex].complete());
      });
      await Future.wait(audioFilesCompleters.map((e) => e.future).toList());
    }

    /// doing some checks to remove unqualified tracks.
    /// removes tracks after changing `duration` or `size`.
    tracksInfoList.removeWhere((tr) => (tr.durationMS != 0 && tr.durationMS < minDur * 1000) || tr.size < minSize);

    /// removes duplicated tracks after a refresh
    if (prevDuplicated) {
      final removedNumber = tracksInfoList.removeDuplicates((element) => element.filename);
      duplicatedTracksLength.value = removedNumber;
    }

    printy("FINAL: ${tracksInfoList.length}");

    await _sortAndSaveTracks();
  }

  Future<void> _saveTrackFileToStorage() async {
    TrackTileManager.onTrackItemPropChange();
    await File(AppPaths.TRACKS).writeAsJson(tracksInfoList.value.map((tr) => allTracksMappedByPath[tr.path]?.toJson()).toList());
  }

  Future<void> updateTrackDuration(Track track, Duration dur) async {
    final durInMS = dur.inMilliseconds;
    if (durInMS > 0 && track.durationMS != durInMS) {
      final trx = allTracksMappedByPath[track.path];
      if (trx != null) {
        allTracksMappedByPath[track.path] = trx.copyWith(durationMS: durInMS);
        tracksInfoList.refresh();
        SearchSortController.inst.trackSearchList.refresh();
        SearchSortController.inst.trackSearchTemp.refresh();
      }
      await _saveTrackFileToStorage();
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
      TrackTileManager.onTrackItemPropChange();
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
      rating: rating.clamp(0, 100),
      tags: tags,
      moods: moods,
      lastPositionInMs: lastPositionInMs,
    );
    trackStatsMap[track] = newStats;
    _trackStatsDBManager.putAsync(track.path, newStats.toJsonWithoutTrack());
    return newStats;
  }

  void _readTrackData() {
    // reading stats file containing track rating etc.
    try {
      _trackStatsDBManager.loadEverythingKeyed(
        (key, value) {
          final track = Track.fromJson(key, isVideo: value['v'] == true);
          final stats = TrackStats.fromJsonWithoutTrack(track, value);
          trackStatsMap.value[stats.track] = stats;
        },
      );

      // -- migrating json to db
      final statsJsonFile = File(AppPaths.TRACKS_STATS_OLD);
      if (statsJsonFile.existsSync()) {
        final list = statsJsonFile.readAsJsonSync() as List?;
        if (list != null) {
          for (int i = 0; i < list.length; i++) {
            try {
              final item = list[i];
              final trst = TrackStats.fromJson(item);
              if (trackStatsMap.value[trst.track] == null) {
                final jsonDetails = trst.toJsonWithoutTrack();
                if (jsonDetails != null) {
                  trackStatsMap.value[trst.track] = trst;
                  _trackStatsDBManager.put(trst.track.path, trst.toJsonWithoutTrack());
                }
              }
            } catch (_) {}
          }
        }
        statsJsonFile.deleteSync();
      }
    } catch (_) {}

    tracksInfoList.clear(); // clearing for cases which refreshing library is required (like after changing separators)

    /// Reading actual track file.
    final splitconfig = _createSplitConfig();

    final tracksResult = _readTracksFileCompute(splitconfig);
    allTracksMappedByPath = tracksResult.$1;
    allTracksMappedByYTID = tracksResult.$2 as Map<String, List<T>>;
    tracksInfoList.value = tracksResult.$3 as List<T>;

    printy("All Tracks Length From File: ${tracksInfoList.length}");
  }

  static (Map<String, TrackExtended>, Map<String, List<Track>>, List<Track>) _readTracksFileCompute(SplitArtistGenreConfigsWrapper config) {
    final map = <String, TrackExtended>{};
    final idsMap = <String, List<Track>>{};
    final allTracks = <Track>[];
    final list = File(config.path).readAsJsonSync() as List?;
    if (list != null) {
      for (int i = 0; i < list.length; i++) {
        try {
          final item = list[i];
          final trExt = TrackExtended.fromJson(
            item,
            artistsSplitConfig: config.artistsConfig,
            genresSplitConfig: config.genresConfig,
            generalSplitConfig: config.generalConfig,
          );
          final track = trExt.asTrack();
          map[track.path] = trExt;
          allTracks.add(track);
          idsMap.addForce(trExt.youtubeID, track);
        } catch (e) {
          continue;
        }
      }
    }
    return (map, idsMap, allTracks);
  }

  static List<String> splitArtist({
    required String? title,
    required String? originalArtist,
    required ArtistsSplitConfig config,
  }) {
    final allArtists = <String>[];

    final artistsOrg = config.splitText(originalArtist, fallback: UnknownTags.ARTIST);
    allArtists.addAll(artistsOrg);

    if (config.addFeatArtist) {
      final List<String>? moreArtists = title?.split(RegExp(r'\(ft\. |\[ft\. |\(feat\. |\[feat\. \]', caseSensitive: false));
      if (moreArtists != null && moreArtists.length > 1) {
        final extractedFeatArtists = moreArtists[1].split(RegExp(r'\)|\]')).first;
        allArtists.addAll(
          config.splitText(extractedFeatArtists, fallback: ''),
        );
      }
    }
    return allArtists;
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
      fallback: '',
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
    final allAvailableDirectories = await getAvailableDirectories(forceReCheck: true, strictNoMedia: strictNoMedia);

    final extensions = _includeVideosAsTracks ? NamidaFileExtensionsWrapper.audioAndVideo : NamidaFileExtensionsWrapper.audio;
    final parameters = {
      'allAvailableDirectories': allAvailableDirectories,
      'directoriesToExclude': settings.directoriesToExclude.value,
      'extensions': extensions,
      'imageExtensions': NamidaFileExtensionsWrapper.image,
    };

    final mapResult = await getFilesTypeIsolate.thready(parameters);

    final allPaths = mapResult['allPaths'] as Set<String>;
    final excludedByNoMedia = mapResult['pathsExcludedByNoMedia'] as Set<String>;
    final folderCovers = mapResult['folderCovers'] as Map<String, String>;

    tracksExcludedByNoMedia.value += excludedByNoMedia.length;

    // ignore: invalid_use_of_protected_member
    allAudioFiles.value = allPaths;
    allFolderCovers = folderCovers;

    printy("Paths Found: ${allPaths.length}");
    return allPaths;
  }

  Completer<Map<Directory, bool>>? _lastAvailableDirectories;
  Future<Map<Directory, bool>> getAvailableDirectories({bool forceReCheck = true, bool strictNoMedia = true}) async {
    if (forceReCheck == false && _lastAvailableDirectories != null) {
      return await _lastAvailableDirectories!.future;
    }

    _lastAvailableDirectories?.completeIfWasnt({});
    _lastAvailableDirectories = null; // for when forceReCheck enabled.
    _lastAvailableDirectories = Completer<Map<Directory, bool>>();
    final parameters = {
      'directoriesToScan': settings.directoriesToScan.value,
      'respectNoMedia': settings.respectNoMedia.value,
      'strictNoMedia': strictNoMedia, // TODO: expose [strictNoMedia] in settings?
    };
    final dirs = await _getAvailableDirectoriesIsolate.thready(parameters);
    _lastAvailableDirectories?.completeIfWasnt(dirs);
    return dirs;
  }

  static Map<Directory, bool> _getAvailableDirectoriesIsolate(Map parameters) {
    final directoriesToScan = parameters['directoriesToScan'] as List<String>;
    final respectNoMedia = parameters['respectNoMedia'] as bool;
    final strictNoMedia = parameters['strictNoMedia'] as bool;

    final allAvailableDirectories = <Directory, bool>{};

    directoriesToScan.loop((dirPath) {
      final directory = Directory(dirPath);

      if (directory.existsSync()) {
        allAvailableDirectories[directory] = false;
        directory.listSyncSafe(recursive: true, followLinks: true).loop((file) {
          if (file is Directory) {
            allAvailableDirectories[file] = false;
          }
        });
      }
    });

    /// Assigning directories and sub-subdirectories that has .nomedia.
    if (respectNoMedia) {
      for (final d in allAvailableDirectories.keys) {
        final hasNoMedia = FileParts.join(d.path, ".nomedia").existsSync();
        if (hasNoMedia) {
          if (strictNoMedia) {
            // strictly applies bool to all subdirectories.
            allAvailableDirectories.forEach((key, value) {
              if (key.path.startsWith(d.path)) {
                allAvailableDirectories[key] = true;
              }
            });
          } else {
            allAvailableDirectories[d] = true;
          }
        }
      }
    }
    return allAvailableDirectories;
  }

  Future<List<(TrackExtended, int)>> _fetchMediaStoreTracks() async {
    if (!NamidaFeaturesVisibility.onAudioQueryAvailable) return [];
    final allMusic = await _audioQuery.querySongs();
    // -- folders selected will be ignored when [settings.useMediaStore.value] is enabled.
    allMusic.retainWhere((element) =>
        settings.directoriesToExclude.value.every((dir) => !element.data.startsWith(dir)) /* && settings.directoriesToScan.any((dir) => element.data.startsWith(dir)) */);
    final tracks = <(TrackExtended, int)>[];
    final artistsSplitConfig = ArtistsSplitConfig.settings();
    final genresSplitConfig = GenresSplitConfig.settings();
    final generalSplitConfig = GeneralSplitConfig();
    allMusic.loop((e) {
      final map = e.getMap;
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
      final trext = TrackExtended(
        title: e.title,
        originalArtist: e.artist ?? UnknownTags.ARTIST,
        artistsList: artists,
        album: e.album ?? UnknownTags.ALBUM,
        albumArtist: map['album_artist'] ?? UnknownTags.ALBUMARTIST,
        originalGenre: e.genre ?? UnknownTags.GENRE,
        genresList: genres,
        originalMood: mood ?? '',
        moodList: moods,
        composer: e.composer ?? '',
        trackNo: e.track ?? 0,
        durationMS: e.duration ?? 0, // `e.duration` => milliseconds
        year: TrackExtended.enforceYearFormat(yearString) ?? 0,
        size: e.size,
        dateAdded: e.dateAdded ?? 0,
        dateModified: e.dateModified ?? 0,
        path: e.data,
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
        isVideo: e.data.isVideo(),
      );
      tracks.add((trext, e.id));
      _backupMediaStoreIDS[trext.pathToImage] = (trext.asTrack(), e.id);
    });
    return tracks;
  }

  void updateImageSizesInStorage({required int removedCount, required int removedSize}) {
    artworksInStorage.value -= removedCount;
    artworksSizeInStorage.value -= removedSize;
  }

  Future<void> calculateAllImageSizesInStorage() async {
    final stats = await updateImageSizeInStorageIsolate.thready({
      "dirPath": AppDirs.ARTWORKS,
      "token": RootIsolateToken.instance,
    });
    artworksInStorage.value = stats.$1;
    artworksSizeInStorage.value = stats.$2;
  }

  static (int, int) updateImageSizeInStorageIsolate(Map p) {
    final dirPath = p["dirPath"] as String;
    final token = p["token"] as RootIsolateToken;
    BackgroundIsolateBinaryMessenger.ensureInitialized(token);

    int totalCount = 0;
    int totalSize = 0;
    final dir = Directory(dirPath);

    dir.listSyncSafe().loop((f) {
      try {
        totalSize += (f as File).lengthSync();
        totalCount++;
      } catch (_) {}
    });

    return (totalCount, totalSize);
  }

  Future<void> updateColorPalettesSizeInStorage({String? newPalettePath}) async {
    if (newPalettePath != null) {
      colorPalettesInStorage.value++;
      return;
    }
    await _updateDirectoryStats(AppDirs.PALETTES, colorPalettesInStorage, null);
  }

  Future<void> _updateDirectoryStats(String dirPath, Rx<int>? filesCountVariable, Rx<int>? filesSizeVariable) async {
    // resets values
    filesCountVariable?.value = 0;
    filesSizeVariable?.value = 0;

    final dir = Directory(dirPath);

    await for (final f in dir.list()) {
      if (f is File) {
        filesCountVariable?.value++;
        final fs = await f.fileSize();
        filesSizeVariable?.value += fs ?? 0;
      }
    }
  }

  Future<void> clearImageCache() async {
    await Directory(AppDirs.ARTWORKS).delete(recursive: true);
    await Directory(AppDirs.ARTWORKS).create();
    await _createDefaultNamidaArtwork();
    calculateAllImageSizesInStorage();
  }

  Future<void> _createDefaultNamidaArtwork() async {
    if (!await File(AppPaths.NAMIDA_LOGO_MONET).exists()) {
      final byteData = await rootBundle.load('assets/namida_icon_monet.png');
      final file = await File(AppPaths.NAMIDA_LOGO_MONET).create(recursive: true);
      await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    }
  }

  static SplitArtistGenreConfigsWrapper _createSplitConfig() {
    return SplitArtistGenreConfigsWrapper.settings();
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
