import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:namida/core/enums.dart';
import 'package:on_audio_edit/on_audio_edit.dart' as audioedit;
import 'package:on_audio_query/on_audio_query.dart';

import 'package:namida/class/folder.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/edit_delete_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/strings.dart';

class Indexer {
  static Indexer get inst => _instance;
  static final Indexer _instance = Indexer._internal();
  Indexer._internal();

  final RxBool isIndexing = false.obs;

  final RxSet<String> allAudioFiles = <String>{}.obs;
  final RxInt filteredForSizeDurationTracks = 0.obs;
  final RxInt duplicatedTracksLength = 0.obs;
  final RxInt tracksExcludedByNoMedia = 0.obs;
  final Set<String> filteredPathsToBeDeleted = {};

  final RxInt artworksInStorage = 0.obs;
  final RxInt waveformsInStorage = 0.obs;
  final RxInt colorPalettesInStorage = 0.obs;
  final RxInt videosInStorage = 0.obs;

  final RxInt artworksSizeInStorage = 0.obs;
  final RxInt waveformsSizeInStorage = 0.obs;
  final RxInt videosSizeInStorage = 0.obs;

  final TextEditingController globalSearchController = TextEditingController();

  final Rx<Map<String, List<Track>>> mainMapAlbums = LinkedHashMap<String, List<Track>>(equals: (p0, p1) => p0.toLowerCase() == p1.toLowerCase()).obs;
  final Rx<Map<String, List<Track>>> mainMapArtists = LinkedHashMap<String, List<Track>>(equals: (p0, p1) => p0.toLowerCase() == p1.toLowerCase()).obs;
  final Rx<Map<String, List<Track>>> mainMapGenres = LinkedHashMap<String, List<Track>>(equals: (p0, p1) => p0.toLowerCase() == p1.toLowerCase()).obs;
  final RxMap<Folder, List<Track>> mainMapFolders = <Folder, List<Track>>{}.obs;

  final RxList<Track> tracksInfoList = <Track>[].obs;

  /// tracks map used for lookup
  final Map<Track, TrackExtended> allTracksMappedByPath = {};
  final Map<Track, TrackStats> trackStatsMap = {};

  final OnAudioQuery _query = OnAudioQuery();
  final onAudioEdit = audioedit.OnAudioEdit();

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
    currentFiles ??= await getAudioFiles();
    await fetchAllSongsAndWriteToFile(
        audioFiles: getNewFoundPaths(currentFiles), deletedPaths: getDeletedPaths(currentFiles), forceReIndex: forceReIndex || tracksInfoList.isEmpty);
    _afterIndexing();
    isIndexing.value = false;
    Get.snackbar(Language.inst.DONE, Language.inst.FINISHED_UPDATING_LIBRARY);
  }

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

  void _addTheseTracksToAlbumGenreArtistEtc(List<Track> tracks) {
    final List<String> addedAlbums = [];
    final List<String> addedArtists = [];
    final List<String> addedGenres = [];
    final List<Folder> addedFolders = [];

    tracks.loop((tr, i) {
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

  /// extracts artwork from [bytes] or [path] of an audio file and save to file.
  /// path is needed bothways for making the file name.
  /// using path for extracting will call [onAudioEdit.readAudio] so it will be slower.
  Future<Uint8List?> extractOneArtwork(String pathOfAudio, {Uint8List? bytes, bool forceReExtract = false}) async {
    final fileOfFull = File("$k_DIR_ARTWORKS${pathOfAudio.getFilename}.png");

    if (forceReExtract) {
      await fileOfFull.tryDeleting();
    }

    /// prevent redundent re-creation of image file
    if (!await fileOfFull.existsAndValid()) {
      final art = bytes ?? await onAudioEdit.readAudio(pathOfAudio).then((value) => value.firstArtwork);

      if (art != null) {
        final imgFile = await fileOfFull.create(recursive: true);
        await imgFile.writeAsBytes(art);
        updateImageSizeInStorage(imgFile);
      }
    }
    return null;
  }

  Future<void> updateTracks(List<Track> tracks, {bool updateArtwork = false}) async {
    final paths = tracks.mapped((e) => e.path).toSet();
    await fetchAllSongsAndWriteToFile(audioFiles: {}, deletedPaths: paths, forceReIndex: false);
    await fetchAllSongsAndWriteToFile(audioFiles: paths, deletedPaths: {}, forceReIndex: false);

    if (updateArtwork) {
      await EditDeleteController.inst.deleteArtwork(tracks);
      await tracks.loopFuture((track, index) async {
        await extractOneArtwork(track.path, forceReExtract: true);
      });
    }
    final newtracks = paths.map((e) => e.toTrackOrNull());
    _addTheseTracksToAlbumGenreArtistEtc(newtracks.whereType<Track>().toList());
  }

  Future<List<Track>> convertPathToTrack(Iterable<String> tracksPathPre) async {
    final List<Track> finalTracks = <Track>[];
    final List<String> pathsToExtract = <String>[];
    final tracksPath = tracksPathPre.toList();
    tracksPath.loop((tp, index) {
      final trako = tp.toTrackOrNull();
      if (trako != null) {
        finalTracks.add(trako);
      } else {
        pathsToExtract.add(tp);
      }
    });

    if (pathsToExtract.isNotEmpty) {
      await fetchAllSongsAndWriteToFile(audioFiles: pathsToExtract.toSet(), deletedPaths: {}, forceReIndex: false, bypassAllChecks: true);
      await pathsToExtract.loopFuture((tp, index) async {
        final t = tp.toTrackOrNull();
        if (t != null) {
          _addTheseTracksToAlbumGenreArtistEtc([t]);
          _sortAll();
          final trako = tp.toTrackOrNull();
          if (trako != null) finalTracks.add(trako);
        }
      });
    }
    finalTracks.sortBy((e) => tracksPath.indexOf(e.path));
    return finalTracks;
  }

  Future<void> fetchAllSongsAndWriteToFile({
    required Set<String> audioFiles,
    required Set<String> deletedPaths,
    bool forceReIndex = true,
    bool bypassAllChecks = false,
  }) async {
    if (forceReIndex) {
      debugPrint(tracksInfoList.length.toString());
      tracksInfoList.clear();
      audioFiles = await getAudioFiles();
    }

    debugPrint("New Audio Files: ${audioFiles.length}");
    debugPrint("Deleted Audio Files: ${deletedPaths.length}");

    filteredForSizeDurationTracks.value = 0;
    duplicatedTracksLength.value = 0;

    final minDur = SettingsController.inst.indexMinDurationInSec.value; // Seconds
    final minSize = SettingsController.inst.indexMinFileSizeInB.value; // bytes

    Future<void> extractAllMetadata() async {
      final ap = AudioPlayer();
      final List<AudioModel> tracksOld = await _query.querySongs();
      final Map<String, AudioModel> tracksInMediaStorage = tracksOld.groupByToSingleValue((tms) => tms.data);

      Set<String> listOfCurrentFileNames = <String>{};
      for (final trackPath in audioFiles) {
        printInfo(info: trackPath);
        try {
          /// skip duplicated tracks according to filename
          if (SettingsController.inst.preventDuplicatedTracks.value) {
            if (!bypassAllChecks && listOfCurrentFileNames.contains(trackPath.getFilename)) {
              duplicatedTracksLength.value++;
              continue;
            }
          }

          final trackInfo = await onAudioEdit.readAudio(trackPath);

          /// Since duration & dateAdded can't be accessed using [onAudioEdit] (jaudiotagger), im using [onAudioQuery] to access it
          /// its faster but sometimes not found (mostly when the folder has .nomedia), in this case, AudioPlayer() is used to retrieve duration.
          int? duration;
          duration = tracksInMediaStorage[trackPath]?.duration;
          if (duration == null || duration == 0) {
            try {
              await ap.setFilePath(trackPath);
              duration = ap.duration?.inMilliseconds;
            } catch (e) {
              debugPrint(e.toString());
            }
          }

          final fileStat = await File(trackPath).stat();

          // breaks the loop early depending on size [byte] or duration [seconds]
          if (!bypassAllChecks && duration != null && (duration < minDur * 1000 || fileStat.size < minSize)) {
            filteredForSizeDurationTracks.value++;
            filteredPathsToBeDeleted.add(trackPath);
            continue;
          }

          /// Split Artists
          final artists = splitArtist(trackInfo.title, trackInfo.artist);

          /// Split Genres
          final genres = splitGenre(trackInfo.genre);

          final finalTitle = trackInfo.title;
          final finalArtist = trackInfo.artist;
          final finalAlbum = trackInfo.album;
          final finalAlbumArtist = trackInfo.albumArtist;
          final finalComposer = trackInfo.composer;
          final finalGenre = trackInfo.genre;

          finalTitle?.trim();
          finalArtist?.trim();
          finalAlbum?.trim();
          finalAlbumArtist?.trim();
          finalComposer?.trim();

          final trExt = TrackExtended(
            finalTitle ?? k_UNKNOWN_TRACK_TITLE,
            finalArtist ?? k_UNKNOWN_TRACK_ARTIST,
            artists,
            finalAlbum ?? k_UNKNOWN_TRACK_ALBUM,
            finalAlbumArtist ?? k_UNKNOWN_TRACK_ALBUMARTIST,
            finalGenre ?? k_UNKNOWN_TRACK_GENRE,
            genres,
            finalComposer ?? k_UNKNOWN_TRACK_COMPOSER,
            trackInfo.track ?? 0,
            duration ?? 0,
            trackInfo.year ?? 0,
            fileStat.size,
            //TODO(MSOB7YY): REMOVE CREATION DATE
            fileStat.accessed.millisecondsSinceEpoch,
            fileStat.changed.millisecondsSinceEpoch,
            trackPath,
            trackInfo.comment ?? '',
            trackInfo.bitrate ?? 0,
            trackInfo.sampleRate ?? 0,
            trackInfo.format ?? '',
            trackInfo.channels ?? '',
            trackInfo.discNo ?? 0,
            trackInfo.language ?? '',
            trackInfo.lyrics ?? '',
          );
          final tr = trExt.toTrack();
          allTracksMappedByPath[tr] = trExt;
          tracksInfoList.add(tr);
          SearchSortController.inst.trackSearchList.add(tr);

          debugPrint(tracksInfoList.length.toString());

          extractOneArtwork(trackPath, bytes: trackInfo.firstArtwork);
        } catch (e) {
          printError(info: e.toString());

          /// adding dummy track that couldnt be read by [onAudioEdit]
          final file = File(trackPath);
          final fileStat = await file.stat();

          final titleAndArtist = getTitleAndArtistFromFilename(trackPath.getFilenameWOExt);
          final title = titleAndArtist.$1;
          final artist = titleAndArtist.$2;

          final trExt = TrackExtended(
            title,
            artist,
            [artist],
            k_UNKNOWN_TRACK_ALBUM,
            k_UNKNOWN_TRACK_ALBUMARTIST,
            k_UNKNOWN_TRACK_GENRE,
            [k_UNKNOWN_TRACK_GENRE],
            k_UNKNOWN_TRACK_COMPOSER,
            0,
            0,
            0,
            fileStat.size,
            //TODO(MSOB7YY): REMOVE CREATION DATE
            fileStat.accessed.millisecondsSinceEpoch,
            fileStat.changed.millisecondsSinceEpoch,
            trackPath,
            '',
            0,
            0,
            '',
            '',
            0,
            '',
            '',
          );
          final tr = trExt.toTrack();
          allTracksMappedByPath[tr] = trExt;
          tracksInfoList.add(tr);
          SearchSortController.inst.trackSearchList.add(tr);
        }
        listOfCurrentFileNames.add(trackPath.getFilename);
      }
      debugPrint('Extracted All Metadata');
    }

    if (audioFiles.isNotEmpty) {
      await extractAllMetadata();
    }

    /// doing some checks to remove unqualified tracks.
    if (!bypassAllChecks) {
      if (deletedPaths.isNotEmpty) {
        tracksInfoList.removeWhere((tr) => deletedPaths.contains(tr.path));
      }

      /// removes tracks after increasing duration
      tracksInfoList.removeWhere((tr) => tr.duration < minDur * 1000 || tr.size < minSize);

      /// removes duplicated tracks after a refresh
      if (SettingsController.inst.preventDuplicatedTracks.value) {
        final removedNumber = tracksInfoList.removeDuplicates((element) => element.filename);
        duplicatedTracksLength.value = removedNumber;
      }
    }
    SearchSortController.inst.sortMedia(MediaType.track);

    if (forceReIndex) _afterIndexing();

    printInfo(info: "FINAL: ${tracksInfoList.length}");

    await _saveTrackFileToStorage();

    /// Creating Default Artwork
    await _createDefaultNamidaArtwork();
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

    debugPrint("Tracks Info List Length From File: ${tracksInfoList.length}");
  }

  List<String> splitBySeparators(String? string, Iterable<String> separators, String fallback, Iterable<String> blacklist) {
    final List<String> finalStrings = <String>[];
    final List<String> pre = string?.trim().multiSplit(separators, blacklist) ?? [fallback];
    pre.loop((e, index) {
      finalStrings.addIf(e != '', e.trim());
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
    final title = titleAndArtist.length >= 2 ? titleAndArtist[1].trim() : filenameWOEx;
    final artist = titleAndArtist.length >= 2 ? titleAndArtist[0].trim() : k_UNKNOWN_TRACK_ARTIST;

    // TODO: split by ( and ) too, but retain Remixes and feat.
    final cleanedUpTitle = title.split('[').first.trim();
    final cleanedUpArtist = artist.split(']').last.trim();

    return (cleanedUpTitle, cleanedUpArtist);
  }

  Set<String> getNewFoundPaths(Set<String> currentFiles) => currentFiles.difference(Set.of(tracksInfoList.map((t) => t.path)));
  Set<String> getDeletedPaths(Set<String> currentFiles) => Set.of(tracksInfoList.map((t) => t.path)).difference(currentFiles);

  /// [strictNoMedia] forces all subdirectories to follow the same result of the parent
  /// ex: if (.nomedia) was found in [/storage/0/Music/],
  /// then subdirectories [/storage/0/Music/folder1/], [/storage/0/Music/folder2/] & [/storage/0/Music/folder2/subfolder/] will be excluded too.
  Future<Set<String>> getAudioFiles({bool strictNoMedia = true}) async {
    tracksExcludedByNoMedia.value = 0;
    final allPaths = <String>{};
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
    await allAvailableDirectories.keys.toList().loopFuture((d, index) async {
      final hasNoMedia = allAvailableDirectories[d] ?? false;

      await for (final file in d.list()) {
        if (file is File) {
          if (!kFileExtensions.any((ext) => file.path.endsWith(ext))) {
            continue;
          }
          if (hasNoMedia) {
            tracksExcludedByNoMedia.value++;
            continue;
          }

          // Skips if the file is included in one of the excluded folders.
          if (SettingsController.inst.directoriesToExclude.any((exc) => file.path.startsWith(exc))) {
            continue;
          }
          allPaths.add(file.path);
        }
      }
    });

    allAudioFiles
      ..clear()
      ..addAll(allPaths);

    debugPrint(allPaths.length.toString());
    return allPaths;
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
  Future<void> clearVideoCache([List<FileSystemEntity>? videosToDelete]) async {
    if (videosToDelete != null) {
      await videosToDelete.loopFuture((v, index) async => await v.delete());
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
