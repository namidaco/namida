import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:faudiotagger/models/faudiomodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:faudiotagger/faudiotagger.dart';
import 'package:get/get.dart';

import 'package:namida/class/folder.dart';
import 'package:namida/class/split_config.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/edit_delete_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/language.dart';

class Indexer {
  static Indexer get inst => _instance;
  static final Indexer _instance = Indexer._internal();
  Indexer._internal();

  final RxBool isIndexing = false.obs;

  final RxSet<String> allAudioFiles = <String>{}.obs;
  final RxInt filteredForSizeDurationTracks = 0.obs;
  final RxInt duplicatedTracksLength = 0.obs;
  final RxInt tracksExcludedByNoMedia = 0.obs;

  final RxInt artworksInStorage = 0.obs;
  final RxInt colorPalettesInStorage = 0.obs;
  final RxInt videosInStorage = 0.obs;

  final RxInt artworksSizeInStorage = 0.obs;
  final RxInt videosSizeInStorage = 0.obs;

  final Rx<Map<String, List<Track>>> mainMapAlbums = LinkedHashMap<String, List<Track>>(equals: (p0, p1) => p0.toLowerCase() == p1.toLowerCase()).obs;
  final Rx<Map<String, List<Track>>> mainMapArtists = LinkedHashMap<String, List<Track>>(equals: (p0, p1) => p0.toLowerCase() == p1.toLowerCase()).obs;
  final Rx<Map<String, List<Track>>> mainMapGenres = LinkedHashMap<String, List<Track>>(equals: (p0, p1) => p0.toLowerCase() == p1.toLowerCase()).obs;
  final RxMap<Folder, List<Track>> mainMapFolders = <Folder, List<Track>>{}.obs;

  final RxList<Track> tracksInfoList = <Track>[].obs;

  /// tracks map used for lookup
  final allTracksMappedByPath = <Track, TrackExtended>{}.obs;
  final trackStatsMap = <Track, TrackStats>{}.obs;

  /// Used to prevent duplicated track (by filename).
  final Map<String, bool> currentFileNamesMap = {};

  final faudiotagger = FAudioTagger();

  Future<void> prepareTracksFile() async {
    /// Only awaits if the track file exists, otherwise it will get into normally and start indexing.
    if (await File(AppPaths.TRACKS).existsAndValid()) {
      await readTrackData();
      _afterIndexing();
    }

    /// doesnt exists
    else {
      await File(AppPaths.TRACKS).create();
      refreshLibraryAndCheckForDiff(forceReIndex: true);
    }
  }

  Future<void> refreshLibraryAndCheckForDiff({Set<String>? currentFiles, bool forceReIndex = false}) async {
    isIndexing.value = true;
    if (forceReIndex || tracksInfoList.isEmpty) {
      await _fetchAllSongsAndWriteToFile(
        audioFiles: {},
        deletedPaths: {},
        forceReIndex: true,
      );
    } else {
      currentFiles ??= await getAudioFiles();
      await _fetchAllSongsAndWriteToFile(
        audioFiles: getNewFoundPaths(currentFiles),
        deletedPaths: getDeletedPaths(currentFiles),
        forceReIndex: false,
      );
    }

    _afterIndexing();
    isIndexing.value = false;
    Get.snackbar(Language.inst.DONE, Language.inst.FINISHED_UPDATING_LIBRARY);
  }

  /// Adds all tracks inside [tracksInfoList] to their respective album, artist, etc..
  /// & sorts all media.
  void _afterIndexing() {
    mainMapAlbums.value.clear();
    mainMapArtists.value.clear();
    mainMapGenres.value.clear();
    mainMapFolders.clear();

    // --- Sorting All Sublists ---
    tracksInfoList.loop((tr, i) {
      final trExt = tr.toTrackExt();

      // -- Assigning Albums
      mainMapAlbums.value.addForce(trExt.album, tr);

      // -- Assigning Artists
      trExt.artistsList.loop((artist, i) {
        mainMapArtists.value.addForce(artist, tr);
      });

      // -- Assigning Genres
      trExt.genresList.loop((genre, i) {
        mainMapGenres.value.addForce(genre, tr);
      });

      // -- Assigning Folders
      mainMapFolders.addForce(tr.folder, tr);
    });

    mainMapAlbums.value.updateAll((key, value) => value..sortByAlt((e) => e.year, (e) => e.title));
    mainMapArtists.value.updateAll((key, value) => value..sortByAlt((e) => e.year, (e) => e.title));
    mainMapGenres.value.updateAll((key, value) => value..sortByAlt((e) => e.year, (e) => e.title));
    mainMapFolders.updateAll((key, value) => value..sortBy((e) => e.filename.toLowerCase()));

    _sortAll();
  }

  void _sortAll() => SearchSortController.inst.sortAll();

  /// Removes Specific tracks from their corresponding media, useful when updating track metadata or reindexing a track.
  void _removeTheseTracksToAlbumGenreArtistEtc(List<Track> tracks) {
    tracks.loop((tr, _) {
      final trExt = tr.toTrackExt();
      mainMapAlbums.value[trExt.album]?.remove(tr);

      trExt.artistsList.loop((artist, i) {
        mainMapArtists.value[artist]?.remove(tr);
      });
      trExt.genresList.loop((genre, i) {
        mainMapGenres.value[genre]?.remove(tr);
      });
      mainMapFolders[tr.folder]?.remove(tr);

      currentFileNamesMap.remove(tr.filename);
    });
  }

  void _addTheseTracksToAlbumGenreArtistEtc(List<Track> tracks) {
    final List<String> addedAlbums = [];
    final List<String> addedArtists = [];
    final List<String> addedGenres = [];
    final List<Folder> addedFolders = [];

    tracks.loop((tr, _) {
      final trExt = tr.toTrackExt();

      // -- Assigning Albums
      mainMapAlbums.value.addNoDuplicatesForce(trExt.album, tr);

      // -- Assigning Artists
      trExt.artistsList.loop((artist, i) {
        mainMapArtists.value.addNoDuplicatesForce(artist, tr);
      });

      // -- Assigning Genres
      trExt.genresList.loop((genre, i) {
        mainMapGenres.value.addNoDuplicatesForce(genre, tr);
      });

      // -- Assigning Folders
      mainMapFolders.addNoDuplicatesForce(tr.folder, tr);

      // --- Adding media that was affected
      addedAlbums.add(trExt.album);
      addedArtists.addAll(trExt.artistsList);
      addedGenres.addAll(trExt.artistsList);
      addedFolders.add(tr.folder);
    });

    addedAlbums
      ..removeDuplicates()
      ..loop((e, index) {
        mainMapAlbums.value[e]?.sortByAlt((e) => e.year, (e) => e.title);
      });
    addedArtists
      ..removeDuplicates()
      ..loop((e, index) {
        mainMapArtists.value[e]?.sortByAlt((e) => e.year, (e) => e.title);
      });
    addedGenres
      ..removeDuplicates()
      ..loop((e, index) {
        mainMapGenres.value[e]?.sortByAlt((e) => e.year, (e) => e.title);
      });
    addedFolders
      ..removeDuplicates()
      ..loop((e, index) {
        mainMapFolders[e]?.sortBy((e) => e.filename.toLowerCase());
      });

    _sortAll();
  }

  /// - Extracts Metadata for given track path
  /// - Nullable only if [minDur] or [minSize] is used.
  Future<TrackExtended?> extractOneTrack({
    required String trackPath,
    int minDur = 0,
    int minSize = 0,
    void Function()? onMinDurTrigger,
    void Function()? onMinSizeTrigger,
    bool deleteOldArtwork = false,
    bool checkForDuplicates = true,
    bool tryExtractingFromFilename = true,
    bool extractColor = false,
  }) async {
    // -- returns null early depending on size [byte] or duration [seconds]
    final fileStat = await File(trackPath).stat();
    if (minSize != 0 && fileStat.size < minSize) {
      if (onMinSizeTrigger != null) onMinSizeTrigger();
      return null;
    }

    late TrackExtended finalTrackExtended;

    FAudioModel? trackInfo;
    try {
      trackInfo = await faudiotagger.readAllData(path: trackPath);
    } catch (e) {
      printy(e, isError: true);
    }
    if (trackInfo == null && !tryExtractingFromFilename) {
      return null;
    }
    final initialTrack = TrackExtended(
      title: k_UNKNOWN_TRACK_TITLE,
      originalArtist: k_UNKNOWN_TRACK_ARTIST,
      artistsList: [k_UNKNOWN_TRACK_ARTIST],
      album: k_UNKNOWN_TRACK_ALBUM,
      albumArtist: k_UNKNOWN_TRACK_ALBUMARTIST,
      originalGenre: k_UNKNOWN_TRACK_GENRE,
      genresList: [k_UNKNOWN_TRACK_GENRE],
      composer: k_UNKNOWN_TRACK_COMPOSER,
      trackNo: 0,
      duration: 0,
      year: 0,
      size: fileStat.size,
      dateAdded: fileStat.accessed.millisecondsSinceEpoch,
      dateModified: fileStat.changed.millisecondsSinceEpoch,
      path: trackPath,
      comment: '',
      bitrate: 0,
      sampleRate: 0,
      format: '',
      channels: '',
      discNo: 0,
      language: '',
      lyrics: '',
    );
    if (trackInfo != null) {
      final duration = trackInfo.length ?? 0;
      if (minDur != 0 && duration < minDur) {
        if (onMinDurTrigger != null) onMinDurTrigger();
        return null;
      }

      // -- Split Artists
      final artists = splitArtist(
        title: trackInfo.title,
        originalArtist: trackInfo.artist,
        config: ArtistsSplitConfig.settings(),
      );

      // -- Split Genres
      final genres = splitGenre(
        trackInfo.genre,
        config: GenresSplitConfig.settings(),
      );

      String? trimOrNull(String? value) => value == null ? value : value.trimAll();

      finalTrackExtended = initialTrack.copyWith(
        title: trimOrNull(trackInfo.title),
        originalArtist: trimOrNull(trackInfo.artist),
        artistsList: artists,
        album: trimOrNull(trackInfo.album),
        albumArtist: trimOrNull(trackInfo.albumArtist),
        originalGenre: trimOrNull(trackInfo.genre),
        genresList: genres,
        composer: trimOrNull(trackInfo.composer),
        trackNo: trackInfo.trackNumber.getIntValue(),
        duration: duration,
        year: trackInfo.year.getIntValue(),
        comment: trackInfo.comment,
        bitrate: trackInfo.bitRate,
        sampleRate: trackInfo.sampleRate,
        format: trackInfo.format,
        channels: trackInfo.channels,
        discNo: trackInfo.discNumber.getIntValue(),
        language: trackInfo.language,
        lyrics: trackInfo.lyrics,
      );

      // ----- if the title || artist weren't found in the tag fields
      final isTitleEmpty = finalTrackExtended.title == k_UNKNOWN_TRACK_TITLE;
      final isArtistEmpty = finalTrackExtended.originalArtist == k_UNKNOWN_TRACK_ARTIST;
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
      // ------------------------------------------------------------

      extractOneArtwork(trackPath, bytes: trackInfo.firstArtwork, forceReExtract: deleteOldArtwork, extractColor: extractColor);
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
      extractOneArtwork(trackPath, forceReExtract: deleteOldArtwork, extractColor: extractColor);
    }

    final tr = finalTrackExtended.toTrack();
    allTracksMappedByPath[tr] = finalTrackExtended;
    currentFileNamesMap[trackPath.getFilename] = true;
    if (checkForDuplicates) {
      tracksInfoList.addNoDuplicates(tr);
      SearchSortController.inst.trackSearchList.addNoDuplicates(tr);
    } else {
      tracksInfoList.add(tr);
      SearchSortController.inst.trackSearchList.add(tr);
    }

    printy("tracksInfoList length: ${tracksInfoList.length}");
    return finalTrackExtended;
  }

  /// - Extracts artwork from [bytes] or [pathOfAudio] and save to file.
  /// - Path is needed bothways for making the file name.
  /// - Using path for extracting will call [faudiotagger.readArtwork] so it will be slower.
  /// - `final art = bytes ?? await faudiotagger.readArtwork(path: pathOfAudio);`
  /// - Sending [artworkPath] that points towards an image file will just copy it to [AppDirs.ARTWORKS]
  /// - Returns the Artwork File created.
  Future<File?> extractOneArtwork(
    String pathOfAudio, {
    Uint8List? bytes,
    bool forceReExtract = false,
    bool extractColor = false,
    String? artworkPath,
  }) async {
    Future<void> extractColorPlsss(File imageFile) async {
      if (extractColor) {
        final tr = Track(pathOfAudio);
        await CurrentColor.inst.reExtractTrackColorPalette(track: tr, newNC: null, imagePath: imageFile.path);
      }
    }

    final fileOfFull = File("${AppDirs.ARTWORKS}${pathOfAudio.getFilename}.png");

    if (artworkPath != null) {
      await updateImageSizeInStorage(oldDeletedFile: fileOfFull); // removing old file stats
      final newFile = await File(artworkPath).copy(fileOfFull.path);
      updateImageSizeInStorage(newImagePath: artworkPath); // adding new file stats
      extractColorPlsss(File(artworkPath));
      return newFile;
    }

    if (!forceReExtract && await fileOfFull.existsAndValid()) {
      extractColorPlsss(fileOfFull);
      return fileOfFull;
    }

    if (forceReExtract) {
      await fileOfFull.deleteIfExists();
    }

    final art = bytes ?? await faudiotagger.readArtwork(path: pathOfAudio);

    if (art != null) {
      try {
        final imgFile = await fileOfFull.create(recursive: true);
        await updateImageSizeInStorage(oldDeletedFile: fileOfFull); // removing old file stats
        await imgFile.writeAsBytes(art);
        updateImageSizeInStorage(newImagePath: imgFile.path); // adding new file stats
        extractColorPlsss(imgFile);
        return imgFile;
      } catch (e) {
        printy(e, isError: true);
        return null;
      }
    }

    return null;
  }

  Future<void> reindexTracks({
    required List<Track> tracks,
    bool updateArtwork = false,
    required void Function(bool didExtract) onProgress,
    required void Function(int tracksLength) onFinish,
    bool tryExtractingFromFilename = true,
  }) async {
    final tracksExisting = <Track, bool>{};
    await tracks.loopFuture((tr, index) async {
      try {
        tracksExisting[tr] = await File(tr.path).exists();
      } catch (e) {
        tracksExisting[tr] = false;
      }
    });
    final tracksReal = tracksExisting.keys.toList();
    _removeTheseTracksToAlbumGenreArtistEtc(tracksReal);
    if (updateArtwork) {
      imageCache.clear();
      imageCache.clearLiveImages();
      await EditDeleteController.inst.deleteArtwork(tracks);
    }

    await tracksReal.loopFuture((track, index) async {
      if (tracksExisting[track] == false) {
        onProgress(false);
      } else {
        final tr = await extractOneTrack(
          trackPath: track.path,
          tryExtractingFromFilename: tryExtractingFromFilename,
          extractColor: true,
        );
        onProgress(tr != null);
      }
    });

    final newtracks = tracksReal.map((e) => e.path.toTrackOrNull());
    _addTheseTracksToAlbumGenreArtistEtc(newtracks.whereType<Track>().toList());
    await _sortAndSaveTracks();
    onFinish(newtracks.length);
  }

  Future<void> updateTrackMetadata({
    required Map<Track, TrackExtended> tracksMap,
    String newArtworkPath = '',
  }) async {
    final oldTracks = <Track>[];
    final newTracks = <Track>[];

    imageCache.clear();
    imageCache.clearLiveImages();

    for (final e in tracksMap.entries) {
      final ot = e.key;
      final nt = e.value.toTrack();
      oldTracks.add(ot);
      newTracks.add(nt);
      allTracksMappedByPath[ot] = e.value;
      currentFileNamesMap.remove(ot.filename);
      currentFileNamesMap[nt.filename] = true;

      if (newArtworkPath != '') {
        await extractOneArtwork(
          ot.path,
          forceReExtract: true,
          artworkPath: newArtworkPath,
        );
        CurrentColor.inst.reExtractTrackColorPalette(track: ot, newNC: null, imagePath: ot.pathToImage);
      }
    }

    _removeTheseTracksToAlbumGenreArtistEtc(oldTracks);
    _addTheseTracksToAlbumGenreArtistEtc(newTracks);
    await _sortAndSaveTracks();
  }

  Future<List<Track>> convertPathToTrack(Iterable<String> tracksPathPre) async {
    final List<Track> finalTracks = <Track>[];
    final tracksPath = tracksPathPre.toList();

    tracksPath.loopFuture((tp, index) async {
      final trako = await tp.toTrackExtOrExtract();
      if (trako != null) finalTracks.add(trako.toTrack());
    });

    _addTheseTracksToAlbumGenreArtistEtc(finalTracks);
    await _sortAndSaveTracks();

    finalTracks.sortBy((e) => tracksPath.indexOf(e.path));
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

  void _clearListsAndResetCounters() {
    tracksInfoList.clear();
    allTracksMappedByPath.clear();
    SearchSortController.inst.sortMedia(MediaType.track);
    filteredForSizeDurationTracks.value = 0;
    duplicatedTracksLength.value = 0;
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
  }) async {
    if (forceReIndex) {
      _clearListsAndResetCounters();
      audioFiles = await getAudioFiles(forceReCheckDirs: true);
    }

    printy("Audio Files New: ${audioFiles.length}");
    printy("Audio Files Deleted: ${deletedPaths.length}");

    if (deletedPaths.isNotEmpty) {
      tracksInfoList.removeWhere((tr) => deletedPaths.contains(tr.path));
    }

    final minDur = SettingsController.inst.indexMinDurationInSec.value; // Seconds
    final minSize = SettingsController.inst.indexMinFileSizeInB.value; // bytes
    final prevDuplicated = SettingsController.inst.preventDuplicatedTracks.value;

    if (audioFiles.isNotEmpty) {
      // -- Extracting All Metadata
      for (final trackPath in audioFiles) {
        printy(trackPath);

        /// skip duplicated tracks according to filename
        if (prevDuplicated) {
          if (currentFileNamesMap.keyExists(trackPath.getFilename)) {
            duplicatedTracksLength.value++;
            continue;
          }
        }
        await extractOneTrack(
          trackPath: trackPath,
          minDur: minDur,
          minSize: minSize,
          onMinDurTrigger: () => filteredForSizeDurationTracks.value++,
          onMinSizeTrigger: () => filteredForSizeDurationTracks.value++,
          checkForDuplicates: false,
        );
      }

      printy('Extracted All Metadata');
    }

    /// doing some checks to remove unqualified tracks.
    /// removes tracks after changing `duration` or `size`.
    tracksInfoList.removeWhere((tr) => (tr.duration != 0 && tr.duration < minDur) || tr.size < minSize);

    /// removes duplicated tracks after a refresh
    if (prevDuplicated) {
      final removedNumber = tracksInfoList.removeDuplicates((element) => element.filename);
      duplicatedTracksLength.value = removedNumber;
    }

    printy("FINAL: ${tracksInfoList.length}");

    await _sortAndSaveTracks();
  }

  Future<void> _saveTrackFileToStorage() async {
    await File(AppPaths.TRACKS).writeAsJson(tracksInfoList.map((key) => allTracksMappedByPath[key]?.toJson()).toList());
  }

  /// Returns new [TrackStats].
  Future<TrackStats> updateTrackStats(
    Track track, {
    int? rating,
    List<String>? tags,
    List<String>? moods,
    int? lastPositionInMs,
  }) async {
    rating ??= track.stats.rating;
    tags ??= track.stats.tags;
    moods ??= track.stats.moods;
    lastPositionInMs ??= track.stats.lastPositionInMs;
    final newStats = TrackStats(track, rating.clamp(0, 100), tags, moods, lastPositionInMs);
    trackStatsMap[track] = newStats;

    await _saveTrackStatsFileToStorage();
    return newStats;
  }

  Future<void> _saveTrackStatsFileToStorage() async {
    await File(AppPaths.TRACKS_STATS).writeAsJson(trackStatsMap.values.map((e) => e.toJson()).toList());
  }

  Future<void> readTrackData() async {
    // reading stats file containing track rating etc.
    final statsResult = await _readTracksStatsCompute.thready(AppPaths.TRACKS_STATS);
    trackStatsMap
      ..clear()
      ..addAll(statsResult);

    tracksInfoList.clear(); // clearing for cases which refreshing library is required (like after changing separators)

    /// Reading actual track file.
    final splitconfig = _SplitArtistGenreConfig(
      path: AppPaths.TRACKS,
      artistsConfig: ArtistsSplitConfig.settings(),
      genresConfig: GenresSplitConfig.settings(),
    );
    final tracksResult = await _readTracksFileCompute.thready(splitconfig);
    allTracksMappedByPath
      ..clear()
      ..addAll(tracksResult);
    tracksInfoList.addAll(tracksResult.keys);

    printy("All Tracks Length From File: ${tracksInfoList.length}");
  }

  static Future<Map<Track, TrackStats>> _readTracksStatsCompute(String path) async {
    final map = <Track, TrackStats>{};
    final list = File(path).readAsJsonSync() as List?;
    if (list != null) {
      for (int i = 0; i <= list.length - 1; i++) {
        try {
          final item = list[i];
          final trst = TrackStats.fromJson(item);
          map[trst.track] = trst;
        } catch (e) {
          continue;
        }
      }
    }
    return map;
  }

  static Future<Map<Track, TrackExtended>> _readTracksFileCompute(_SplitArtistGenreConfig config) async {
    final map = <Track, TrackExtended>{};
    final list = File(config.path).readAsJsonSync() as List?;
    if (list != null) {
      for (int i = 0; i <= list.length - 1; i++) {
        try {
          final item = list[i];
          final trExt = TrackExtended.fromJson(
            item,
            artistsSplitConfig: config.artistsConfig,
            genresSplitConfig: config.genresConfig,
          );
          final track = trExt.toTrack();
          map[track] = trExt;
        } catch (e) {
          continue;
        }
      }
    }
    return map;
  }

  List<String> splitBySeparators(String? string, Iterable<String> separators, String fallback, Iterable<String> blacklist) {
    final List<String> finalStrings = <String>[];
    final List<String> pre = string?.trimAll().multiSplit(separators, blacklist) ?? [fallback];
    pre.loop((e, index) {
      finalStrings.addIf(e != '', e.trimAll());
    });
    return finalStrings;
  }

  /// [addArtistsFromTitle] extracts feat artists.
  /// Defaults to [SettingsController.inst.extractFeatArtistFromTitle]
  List<String> splitArtist({
    required String? title,
    required String? originalArtist,
    required ArtistsSplitConfig config,
  }) {
    final allArtists = <String>[];

    final artistsOrg = splitBySeparators(
      originalArtist,
      config.separators,
      k_UNKNOWN_TRACK_ARTIST,
      config.separatorsBlacklist,
    );
    allArtists.addAll(artistsOrg);

    if (config.addFeatArtist) {
      final List<String>? moreArtists = title?.split(RegExp(r'\(ft\. |\[ft\. |\(feat\. |\[feat\. \]', caseSensitive: false));
      if (moreArtists != null && moreArtists.length > 1) {
        final extractedFeatArtists = moreArtists[1].split(RegExp(r'\)|\]')).first;
        allArtists.addAll(
          splitBySeparators(
            extractedFeatArtists,
            config.separators,
            '',
            config.separatorsBlacklist,
          ),
        );
      }
    }
    return allArtists;
  }

  List<String> splitGenre(
    String? originalGenre, {
    required GenresSplitConfig config,
  }) {
    return splitBySeparators(
      originalGenre,
      config.separators,
      k_UNKNOWN_TRACK_GENRE,
      config.separatorsBlacklist,
    );
  }

  /// $1 = title
  ///
  /// $2 = artist
  (String, String) getTitleAndArtistFromFilename(String filename) {
    final filenameWOEx = filename.replaceAll('_', ' ');
    final titleAndArtist = <String>[];

    /// preferring to split by [' - '], since there are artists that has '-' in their name.
    titleAndArtist.addAll(filenameWOEx.split(' - '));
    if (titleAndArtist.length == 1) {
      titleAndArtist.addAll(filenameWOEx.split('-'));
    }

    /// in case splitting produced 2 entries or more, it means its high likely to be [artist - title]
    /// otherwise [title] will be the [filename] and [artist] will be [Unknown]
    final title = titleAndArtist.length >= 2 ? titleAndArtist[1].trimAll() : filenameWOEx;
    final artist = titleAndArtist.length >= 2 ? titleAndArtist[0].trimAll() : k_UNKNOWN_TRACK_ARTIST;

    // TODO: split by ( and ) too, but retain Remixes and feat.
    final cleanedUpTitle = title.split('[').first.trimAll();
    final cleanedUpArtist = artist.split(']').last.trimAll();

    return (cleanedUpTitle, cleanedUpArtist);
  }

  Set<String> getNewFoundPaths(Set<String> currentFiles) => currentFiles.difference(Set.of(tracksInfoList.map((t) => t.path)));
  Set<String> getDeletedPaths(Set<String> currentFiles) => Set.of(tracksInfoList.map((t) => t.path)).difference(currentFiles);

  /// [strictNoMedia] forces all subdirectories to follow the same result of the parent.
  ///
  /// ex: if (.nomedia) was found in [/storage/0/Music/],
  /// then subdirectories [/storage/0/Music/folder1/], [/storage/0/Music/folder2/] & [/storage/0/Music/folder2/subfolder/] will be excluded too.
  Future<Set<String>> getAudioFiles({bool strictNoMedia = true, bool forceReCheckDirs = false}) async {
    tracksExcludedByNoMedia.value = 0;
    final allAvailableDirectories = await getAvailableDirectories(forceReCheck: forceReCheckDirs, strictNoMedia: strictNoMedia);

    final parameters = {
      'allAvailableDirectories': allAvailableDirectories,
      'directoriesToExclude': SettingsController.inst.directoriesToExclude.toList(),
    };

    final mapResult = await _getAudioFilesIsolate.thready(parameters);

    final allPaths = mapResult['allPaths']!;
    final excludedByNoMedia = mapResult['pathsExcludedByNoMedia']!;

    tracksExcludedByNoMedia.value += excludedByNoMedia.length;

    allAudioFiles
      ..clear()
      ..addAll(allPaths);

    printy("Paths Found: ${allPaths.length}");
    return allPaths;
  }

  /// ```
  /// {
  /// 'allPaths': <String>{},
  /// 'pathsExcludedByNoMedia': <String>{},
  /// }
  /// ```
  static Map<String, Set<String>> _getAudioFilesIsolate(Map parameters) {
    final allAvailableDirectories = parameters['allAvailableDirectories'] as Map<Directory, bool>;
    final directoriesToExclude = parameters['directoriesToExclude'] as List<String>;

    final allPaths = <String>{};
    final excludedByNoMedia = <String>{};

    allAvailableDirectories.keys.toList().loop((d, index) {
      final hasNoMedia = allAvailableDirectories[d] ?? false;

      for (final systemEntity in d.listSync()) {
        if (systemEntity is File) {
          final path = systemEntity.path;
          if (!kAudioFileExtensions.any((ext) => path.endsWith(ext))) {
            continue;
          }
          if (hasNoMedia) {
            excludedByNoMedia.add(path);
            continue;
          }

          // Skips if the file is included in one of the excluded folders.
          if (directoriesToExclude.any((exc) => path.startsWith(exc))) {
            continue;
          }
          allPaths.add(path);
        }
      }
    });
    return {
      'allPaths': allPaths,
      'pathsExcludedByNoMedia': excludedByNoMedia,
    };
  }

  bool? _latestRespectNoMedia;
  Completer<Map<Directory, bool>>? _availableDirs;
  Future<Map<Directory, bool>> getAvailableDirectories({bool strictNoMedia = true, bool forceReCheck = false}) async {
    if (_availableDirs != null && !forceReCheck && _latestRespectNoMedia == SettingsController.inst.respectNoMedia.value) {
      return await _availableDirs!.future;
    } else {
      _availableDirs = null; // for when forceReCheck enabled.
      _availableDirs = Completer<Map<Directory, bool>>();

      _latestRespectNoMedia = SettingsController.inst.respectNoMedia.value;

      final parameters = {
        'directoriesToScan': SettingsController.inst.directoriesToScan.toList(),
        'respectNoMedia': SettingsController.inst.respectNoMedia.value,
        'strictNoMedia': strictNoMedia, // TODO: expose [strictNoMedia] in settings?
      };
      final allAvailableDirectories = await _getAvailableDirectoriesIsolate.thready(parameters);

      _availableDirs?.complete(allAvailableDirectories);

      return allAvailableDirectories;
    }
  }

  static Map<Directory, bool> _getAvailableDirectoriesIsolate(Map parameters) {
    final directoriesToScan = parameters['directoriesToScan'] as List<String>;
    final respectNoMedia = parameters['respectNoMedia'] as bool;
    final strictNoMedia = parameters['strictNoMedia'] as bool;

    final allAvailableDirectories = <Directory, bool>{};

    for (final dirPath in directoriesToScan) {
      final directory = Directory(dirPath);

      if (directory.existsSync()) {
        allAvailableDirectories[directory] = false;
        for (final file in directory.listSync(recursive: true, followLinks: true)) {
          if (file is Directory) {
            allAvailableDirectories[file] = false;
          }
        }
      }
    }

    /// Assigning directories and sub-subdirectories that has .nomedia.
    if (respectNoMedia) {
      for (final d in allAvailableDirectories.keys) {
        final hasNoMedia = File("${d.path}/.nomedia").existsSync();
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

  Future<void> updateImageSizeInStorage({String? newImagePath, File? oldDeletedFile}) async {
    if (newImagePath != null || oldDeletedFile != null) {
      if (oldDeletedFile != null) {
        artworksInStorage.value--;
        artworksSizeInStorage.value -= await oldDeletedFile.sizeInBytes();
      }
      if (newImagePath != null) {
        artworksInStorage.value++;
        artworksSizeInStorage.value += await File(newImagePath).sizeInBytes();
      }

      return;
    }

    await _updateDirectoryStats(AppDirs.ARTWORKS, artworksInStorage, artworksSizeInStorage);
  }

  Future<void> updateColorPalettesSizeInStorage({String? newPalettePath}) async {
    if (newPalettePath != null) {
      colorPalettesInStorage.value++;
      return;
    }
    await _updateDirectoryStats(AppDirs.PALETTES, colorPalettesInStorage, null);
  }

  Future<void> updateVideosSizeInStorage({String? newVideoPath, File? oldDeletedFile}) async {
    if (newVideoPath != null || oldDeletedFile != null) {
      if (oldDeletedFile != null) {
        videosInStorage.value--;
        videosInStorage.value -= await oldDeletedFile.sizeInBytes();
      }
      if (newVideoPath != null) {
        videosInStorage.value++;
        videosInStorage.value += await File(newVideoPath).sizeInBytes();
      }

      return;
    }
    await _updateDirectoryStats(AppDirs.VIDEOS_CACHE, videosInStorage, videosSizeInStorage);
  }

  Future<void> _updateDirectoryStats(String dirPath, RxInt? filesCountVariable, RxInt? filesSizeVariable) async {
    // resets values
    filesCountVariable?.value = 0;
    filesSizeVariable?.value = 0;

    final dir = Directory(dirPath);

    await for (final f in dir.list()) {
      if (f is File) {
        filesCountVariable?.value++;
        final st = await f.stat();
        filesSizeVariable?.value += st.size;
      }
    }
  }

  Future<void> clearImageCache() async {
    await Directory(AppDirs.ARTWORKS).delete(recursive: true);
    await Directory(AppDirs.ARTWORKS).create();
    await _createDefaultNamidaArtwork();
    updateImageSizeInStorage();
  }

  /// Deletes specific videos or the whole cache.
  Future<void> clearVideoCache([List<NamidaVideo>? videosToDelete]) async {
    if (videosToDelete != null) {
      await videosToDelete.loopFuture((v, index) async => await File(v.path).delete());
    } else {
      await Directory(AppDirs.VIDEOS_CACHE).delete(recursive: true);
      await Directory(AppDirs.VIDEOS_CACHE).create();
    }

    updateVideosSizeInStorage();
  }

  Future<void> _createDefaultNamidaArtwork() async {
    if (!await File(AppPaths.NAMIDA_LOGO).exists()) {
      final byteData = await rootBundle.load('assets/namida_icon.png');
      final file = await File(AppPaths.NAMIDA_LOGO).create(recursive: true);
      await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    }
  }
}

class _SplitArtistGenreConfig {
  final String path;
  final ArtistsSplitConfig artistsConfig;
  final GenresSplitConfig genresConfig;

  const _SplitArtistGenreConfig({
    required this.path,
    required this.artistsConfig,
    required this.genresConfig,
  });
}
