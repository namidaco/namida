import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:faudiotagger/models/faudiomodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:faudiotagger/faudiotagger.dart';
import 'package:get/get.dart';

import 'package:namida/class/folder.dart';
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
  final RxInt waveformsInStorage = 0.obs;
  final RxInt colorPalettesInStorage = 0.obs;
  final RxInt videosInStorage = 0.obs;

  final RxInt artworksSizeInStorage = 0.obs;
  final RxInt waveformsSizeInStorage = 0.obs;
  final RxInt videosSizeInStorage = 0.obs;

  final Rx<Map<String, List<Track>>> mainMapAlbums = LinkedHashMap<String, List<Track>>(equals: (p0, p1) => p0.toLowerCase() == p1.toLowerCase()).obs;
  final Rx<Map<String, List<Track>>> mainMapArtists = LinkedHashMap<String, List<Track>>(equals: (p0, p1) => p0.toLowerCase() == p1.toLowerCase()).obs;
  final Rx<Map<String, List<Track>>> mainMapGenres = LinkedHashMap<String, List<Track>>(equals: (p0, p1) => p0.toLowerCase() == p1.toLowerCase()).obs;
  final RxMap<Folder, List<Track>> mainMapFolders = <Folder, List<Track>>{}.obs;

  final RxList<Track> tracksInfoList = <Track>[].obs;

  /// tracks map used for lookup
  final Map<Track, TrackExtended> allTracksMappedByPath = {};
  final Map<Track, TrackStats> trackStatsMap = {};

  /// Used to prevent duplicated track (by filename).
  final Map<String, bool> currentFileNamesMap = {};

  final faudiotagger = FAudioTagger();

  Future<void> prepareTracksFile() async {
    /// Only awaits if the track file exists, otherwise it will get into normally and start indexing.
    if (await File(k_FILE_PATH_TRACKS).existsAndValid()) {
      await readTrackData();
      _afterIndexing();
    }

    /// doesnt exists
    else {
      await File(k_FILE_PATH_TRACKS).create();
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
      final artists = splitArtist(trackInfo.title, trackInfo.artist);

      // -- Split Genres
      final genres = splitGenre(trackInfo.genre);

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

      extractOneArtwork(trackPath, bytes: trackInfo.firstArtwork, forceReExtract: deleteOldArtwork);
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
      extractOneArtwork(trackPath, forceReExtract: deleteOldArtwork);
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
  /// - Sending [artworkPath] that points towards an image file will just copy it to [k_DIR_ARTWORKS]
  /// - Returns the Artwork File created.
  Future<File?> extractOneArtwork(
    String pathOfAudio, {
    Uint8List? bytes,
    bool forceReExtract = false,
    String? artworkPath,
  }) async {
    final fileOfFull = File("$k_DIR_ARTWORKS${pathOfAudio.getFilename}.png");

    if (artworkPath != null) {
      final newFile = await File(artworkPath).copy(fileOfFull.path);
      return newFile;
    }

    if (!forceReExtract && await fileOfFull.existsAndValid()) {
      return fileOfFull;
    }

    if (forceReExtract) {
      await fileOfFull.tryDeleting();
    }

    final art = bytes ?? await faudiotagger.readArtwork(path: pathOfAudio);

    if (art != null) {
      try {
        final imgFile = await fileOfFull.create(recursive: true);
        await imgFile.writeAsBytes(art);
        updateImageSizeInStorage(imgFile);
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
        final tr = await extractOneTrack(trackPath: track.path, tryExtractingFromFilename: tryExtractingFromFilename);
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
      final trako = await tp.toTrackOrExtract();
      finalTracks.add(trako);
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
    final prevDuplicated = SettingsController.inst.preventDuplicatedTracks.value; // bytes

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
    await File(k_FILE_PATH_TRACKS).writeAsJson(allTracksMappedByPath.values.map((e) => e.toJson()).toList());
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
    await File(k_FILE_PATH_TRACKS_STATS).writeAsJson(trackStatsMap.values.map((e) => e.toJson()).toList());
  }

  Future<void> readTrackData() async {
    /// reading stats file containing track rating etc.

    await File(k_FILE_PATH_TRACKS_STATS).readAsJsonAndLoop((item, i) async {
      final trst = TrackStats.fromJson(item);
      trackStatsMap[trst.track] = trst;
    });
    // clearing for cases which refreshing library is required (like after changing separators)
    tracksInfoList.clear();

    /// Reading actual track file.
    await File(k_FILE_PATH_TRACKS).readAsJsonAndLoop((item, i) async {
      final trExt = TrackExtended.fromJson(item);
      final track = trExt.toTrack();

      tracksInfoList.add(track);
      allTracksMappedByPath[track] = trExt;
    });

    printy("All Tracks Length From File: ${tracksInfoList.length}");
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
  List<String> splitArtist(String? title, String? originalArtist, {bool? addArtistsFromTitle}) {
    final allArtists = <String>[];
    addArtistsFromTitle ??= SettingsController.inst.extractFeatArtistFromTitle.value;

    final artistsOrg = splitBySeparators(
      originalArtist,
      SettingsController.inst.trackArtistsSeparators,
      k_UNKNOWN_TRACK_ARTIST,
      SettingsController.inst.trackArtistsSeparatorsBlacklist,
    );
    allArtists.addAll(artistsOrg);

    if (addArtistsFromTitle) {
      final List<String>? moreArtists = title?.split(RegExp(r'\(ft\. |\[ft\. |\(feat\. |\[feat\. \]', caseSensitive: false));
      if (moreArtists != null && moreArtists.length > 1) {
        final extractedFeatArtists = moreArtists[1].split(RegExp(r'\)|\]')).first;
        allArtists.addAll(
          splitBySeparators(
            extractedFeatArtists,
            SettingsController.inst.trackArtistsSeparators,
            '',
            SettingsController.inst.trackArtistsSeparatorsBlacklist,
          ),
        );
      }
    }
    return allArtists;
  }

  List<String> splitGenre(String? originalGenre) {
    return splitBySeparators(
      originalGenre,
      SettingsController.inst.trackGenresSeparators,
      k_UNKNOWN_TRACK_GENRE,
      SettingsController.inst.trackGenresSeparatorsBlacklist,
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

    final allPaths = <String>{};

    await allAvailableDirectories.keys.toList().loopFuture((d, index) async {
      final hasNoMedia = allAvailableDirectories[d] ?? false;

      await for (final systemEntity in d.list()) {
        if (systemEntity is File) {
          final path = systemEntity.path;
          if (!kAudioFileExtensions.any((ext) => path.endsWith(ext))) {
            continue;
          }
          if (hasNoMedia) {
            tracksExcludedByNoMedia.value++;
            continue;
          }

          // Skips if the file is included in one of the excluded folders.
          if (SettingsController.inst.directoriesToExclude.any((exc) => path.startsWith(exc))) {
            continue;
          }
          allPaths.add(path);
        }
      }
    });

    allAudioFiles
      ..clear()
      ..addAll(allPaths);

    printy("Paths Found: ${allPaths.length}");
    return allPaths;
  }

  Completer<Map<Directory, bool>>? availableDirs;
  Future<Map<Directory, bool>> getAvailableDirectories({bool strictNoMedia = true, bool forceReCheck = false}) async {
    if (availableDirs != null && !forceReCheck) {
      return await availableDirs!.future;
    } else {
      availableDirs = null; // for when forceReCheck enabled.
      availableDirs = Completer<Map<Directory, bool>>();

      final allAvailableDirectories = <Directory, bool>{};

      await SettingsController.inst.directoriesToScan.loopFuture((dirPath, index) async {
        final directory = Directory(dirPath);

        if (await directory.exists()) {
          allAvailableDirectories[directory] = false;
          await for (final file in directory.list(recursive: true, followLinks: true)) {
            if (file is Directory) {
              allAvailableDirectories[file] = false;
            }
          }
        }
      });

      /// Assigning directories and sub-subdirectories that has .nomedia.
      if (SettingsController.inst.respectNoMedia.value) {
        await allAvailableDirectories.keys.toList().loopFuture((d, index) async {
          final hasNoMedia = await File("${d.path}/.nomedia").exists();
          if (hasNoMedia) {
            // TODO: expose [strictNoMedia] in settings?
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
        });
      }
      availableDirs?.complete(allAvailableDirectories);
      return allAvailableDirectories;
    }
  }

  Future<void> updateImageSizeInStorage([File? newImgFile, bool decreaseStats = false]) async {
    if (newImgFile != null) {
      final size = await newImgFile.stat().then((value) => value.size);
      if (decreaseStats) {
        artworksInStorage.value--;
        artworksSizeInStorage.value -= size;
      } else {
        artworksInStorage.value++;
        artworksSizeInStorage.value += size;
      }

      return;
    }
    await _updateDirectoryStats(k_DIR_ARTWORKS, artworksInStorage, artworksSizeInStorage);
  }

  Future<void> updateWaveformSizeInStorage([File? newWaveFile, bool decreaseStats = false]) async {
    if (newWaveFile != null) {
      final size = await newWaveFile.stat().then((value) => value.size);
      if (decreaseStats) {
        waveformsInStorage.value--;
        waveformsInStorage.value -= size;
      } else {
        waveformsInStorage.value++;
        waveformsInStorage.value += size;
      }

      return;
    }
    await _updateDirectoryStats(k_DIR_WAVEFORMS, waveformsInStorage, waveformsSizeInStorage);
  }

  Future<void> updateColorPalettesSizeInStorage([File? newPaletteFile]) async {
    if (newPaletteFile != null) {
      colorPalettesInStorage.value++;
      return;
    }
    await _updateDirectoryStats(k_DIR_PALETTES, colorPalettesInStorage, null);
  }

  Future<void> updateVideosSizeInStorage([File? newVideoFile, bool decreaseStats = false]) async {
    if (newVideoFile != null) {
      final size = await newVideoFile.stat().then((value) => value.size);
      if (decreaseStats) {
        videosInStorage.value--;
        videosInStorage.value -= size;
      } else {
        videosInStorage.value++;
        videosInStorage.value += size;
      }

      return;
    }
    await _updateDirectoryStats(k_DIR_VIDEOS_CACHE, videosInStorage, videosSizeInStorage);
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
    await Directory(k_DIR_ARTWORKS).delete(recursive: true);
    await Directory(k_DIR_ARTWORKS).create();
    await _createDefaultNamidaArtwork();
    updateImageSizeInStorage();
  }

  Future<void> clearWaveformData() async {
    await Directory(k_DIR_WAVEFORMS).delete(recursive: true);
    await Directory(k_DIR_WAVEFORMS).create();
    updateWaveformSizeInStorage();
  }

  /// Deletes specific videos or the whole cache.
  Future<void> clearVideoCache([List<NamidaVideo>? videosToDelete]) async {
    if (videosToDelete != null) {
      await videosToDelete.loopFuture((v, index) async => await File(v.path).delete());
    } else {
      await Directory(k_DIR_VIDEOS_CACHE).delete(recursive: true);
      await Directory(k_DIR_VIDEOS_CACHE).create();
    }

    updateVideosSizeInStorage();
  }

  Future<void> _createDefaultNamidaArtwork() async {
    if (!await File(k_FILE_PATH_NAMIDA_LOGO).exists()) {
      final byteData = await rootBundle.load('assets/namida_icon.png');
      final file = await File(k_FILE_PATH_NAMIDA_LOGO).create(recursive: true);
      await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    }
  }
}
