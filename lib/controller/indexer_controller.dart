import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:on_audio_edit/on_audio_edit.dart' as audioedit;
import 'package:on_audio_query/on_audio_query.dart';

import 'package:namida/class/folder.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/edit_delete_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
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

  RxBool get isSearching => (trackSearchTemp.isNotEmpty || albumSearchTemp.isNotEmpty || artistSearchTemp.isNotEmpty).obs;

  final Rx<Map<String, List<Track>>> mainMapAlbums = LinkedHashMap<String, List<Track>>(equals: (p0, p1) => p0.toLowerCase() == p1.toLowerCase()).obs;
  final Rx<Map<String, List<Track>>> mainMapArtists = LinkedHashMap<String, List<Track>>(equals: (p0, p1) => p0.toLowerCase() == p1.toLowerCase()).obs;
  final Rx<Map<String, List<Track>>> mainMapGenres = LinkedHashMap<String, List<Track>>(equals: (p0, p1) => p0.toLowerCase() == p1.toLowerCase()).obs;
  final RxMap<Folder, List<Track>> mainMapFolders = <Folder, List<Track>>{}.obs;

  final RxList<Track> tracksInfoList = <Track>[].obs;

  final RxList<Track> trackSearchList = <Track>[].obs;
  final RxList<String> albumSearchList = <String>[].obs;
  final RxList<String> artistSearchList = <String>[].obs;
  final RxList<String> genreSearchList = <String>[].obs;

  /// Temporary lists.
  final RxList<Track> trackSearchTemp = <Track>[].obs;
  final RxList<String> albumSearchTemp = <String>[].obs;
  final RxList<String> artistSearchTemp = <String>[].obs;

  /// tracks map used for lookup
  final Map<String, Track> allTracksMappedByPath = {};
  final Map<String, TrackStats> trackStatsMap = {};

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

    _addTheseTracksToAlbumGenreArtistEtc(tracksInfoList);

    _sortAll();
  }

  void _sortAll() {
    sortTracks();
    sortAlbums();
    sortArtists();
    sortGenres();
  }

  void _addTheseTracksToAlbumGenreArtistEtc(List<Track> tracks, {bool preventDuplicates = false}) {
    // TODO sort after adding
    tracks.loop((tr, i) {
      /// Assigning Albums
      mainMapAlbums.value.addNoDuplicatesForce(tr.album, tr, preventDuplicates: preventDuplicates);

      /// Assigning Artists
      tr.artistsList.loop((artist, i) {
        mainMapArtists.value.addNoDuplicatesForce(artist, tr, preventDuplicates: preventDuplicates);
      });

      /// Assigning Genres
      tr.genresList.loop((genre, i) {
        mainMapGenres.value.addNoDuplicatesForce(genre, tr, preventDuplicates: preventDuplicates);
      });

      /// Assigning Folders
      mainMapFolders.addNoDuplicatesForce(tr.folder, tr, preventDuplicates: preventDuplicates);
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
    final paths = tracks.map((e) => e.path).toSet();
    await fetchAllSongsAndWriteToFile(audioFiles: {}, deletedPaths: paths, forceReIndex: false);
    await fetchAllSongsAndWriteToFile(audioFiles: paths, deletedPaths: {}, forceReIndex: false);

    if (updateArtwork) {
      await EditDeleteController.inst.deleteArtwork(tracks);
      await tracks.loopFuture((track, index) async {
        await extractOneArtwork(track.path, forceReExtract: true);
      });
    }
    final newtracks = paths.map((e) => e.toTrackOrNull());
    _addTheseTracksToAlbumGenreArtistEtc(newtracks.whereType<Track>().toList(), preventDuplicates: true);
  }

  Future<List<Track>> convertPathToTrack(List<String> tracksPath) async {
    final List<Track> finalTracks = <Track>[];
    final List<String> pathsToExtract = <String>[];
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
          _addTheseTracksToAlbumGenreArtistEtc([t], preventDuplicates: true);
          _sortAll();
          final trako = tp.toTrackOrNull();
          if (trako != null) finalTracks.add(trako);
        }
      });
    }

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

          int? getIntFromString(String? text) => int.tryParse((text ?? '').cleanUpForComparison);

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

          final tr = Track(
            finalTitle ?? k_UNKNOWN_TRACK_TITLE,
            finalArtist ?? k_UNKNOWN_TRACK_ARTIST,
            artists,
            finalAlbum ?? k_UNKNOWN_TRACK_ALBUM,
            finalAlbumArtist ?? k_UNKNOWN_TRACK_ALBUMARTIST,
            finalGenre ?? k_UNKNOWN_TRACK_GENRE,
            genres,
            finalComposer ?? k_UNKNOWN_TRACK_COMPOSER,
            getIntFromString(trackInfo.track) ?? 0,
            duration ?? 0,
            getIntFromString(trackInfo.year) ?? 0,
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
            getIntFromString(trackInfo.discNo) ?? 0,
            trackInfo.language ?? '',
            trackInfo.lyrics ?? '',
            TrackStats('', 0, [], [], 0),
          );

          tracksInfoList.add(tr);
          allTracksMappedByPath[trackPath] = tr;

          debugPrint(tracksInfoList.length.toString());

          extractOneArtwork(trackPath, bytes: trackInfo.firstArtwork);
        } catch (e) {
          printError(info: e.toString());

          /// adding dummy track that couldnt be read by [onAudioEdit]
          final file = File(trackPath);
          final fileStat = await file.stat();

          final titleAndArtist = getTitleAndArtistFromFilename(trackPath.getFilenameWOExt);
          final title = titleAndArtist.first;
          final artist = titleAndArtist.last;

          final tr = Track(
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
            TrackStats('', 0, [], [], 0),
          );
          tracksInfoList.add(tr);
          allTracksMappedByPath[tr.path] = tr;
        }
        listOfCurrentFileNames.add(trackPath.getFilename);
        searchTracks('');
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
        final lengthBefore = tracksInfoList.length;
        tracksInfoList.removeDuplicates((element) => element.filename);
        final lengthAfter = tracksInfoList.length;
        duplicatedTracksLength.value = (lengthBefore - lengthAfter).withMinimum(0);
      }
    }

    if (forceReIndex) _afterIndexing();

    printInfo(info: "FINAL: ${tracksInfoList.length}");

    await _saveTrackFileToStorage();

    /// Creating Default Artwork
    await _createDefaultNamidaArtwork();
  }

  Future<void> _saveTrackFileToStorage() async {
    await File(k_FILE_PATH_TRACKS).writeAsJson(tracksInfoList);
  }

  Future<void> saveTrackStatsFileToStorage() async {
    await File(k_FILE_PATH_TRACKS_STATS).writeAsJson(trackStatsMap.values.toList());
  }

  Future<void> readTrackData() async {
    /// reading stats file containing track rating etc.

    await File(k_FILE_PATH_TRACKS_STATS).readAsJsonAndLoop((item, i) {
      final trst = TrackStats.fromJson(item);
      trackStatsMap[trst.path] = trst;
    });
    // clearing for cases which refreshing library is required (like after changing separators)
    tracksInfoList.clear();

    /// Reading actual track file.
    await File(k_FILE_PATH_TRACKS).readAsJsonAndLoop((item, i) {
      final tr = Track.fromJson(item);
      tr.stats = trackStatsMap[tr.path] ?? TrackStats('', 0, [], [], 0);
      tracksInfoList.add(tr);
      allTracksMappedByPath[tr.path] = tr;
    });

    debugPrint("Tracks Info List Length From File: ${tracksInfoList.length}");
  }

  List<String> splitBySeparators(String? string, Iterable<String> separators, String fallback, List<String> blacklist) {
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
      SettingsController.inst.trackArtistsSeparators.toList(),
      k_UNKNOWN_TRACK_ARTIST,
      SettingsController.inst.trackArtistsSeparatorsBlacklist.toList(),
    );
    allArtists.addAll(artistsOrg);

    if (addArtistsFromTitle) {
      final List<String>? moreArtists = title?.split(RegExp(r'\(ft\. |\[ft\. |\(feat\. |\[feat\. \]', caseSensitive: false));
      if (moreArtists != null && moreArtists.length > 1) {
        final extractedFeatArtists = moreArtists[1].split(RegExp(r'\)|\]')).first;
        allArtists.addAll(
          splitBySeparators(
            extractedFeatArtists,
            SettingsController.inst.trackArtistsSeparators.toList(),
            '',
            SettingsController.inst.trackArtistsSeparatorsBlacklist.toList(),
          ),
        );
      }
    }
    return allArtists;
  }

  List<String> splitGenre(String? originalGenre) {
    return splitBySeparators(
      originalGenre,
      SettingsController.inst.trackGenresSeparators.toList(),
      k_UNKNOWN_TRACK_GENRE,
      SettingsController.inst.trackGenresSeparatorsBlacklist.toList(),
    );
  }

  /// list.first = title
  ///
  /// list.last = artist
  /// TODO: refactor
  List<String> getTitleAndArtistFromFilename(String filename) {
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

    return [cleanedUpTitle, cleanedUpArtist];
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

    await SettingsController.inst.directoriesToScan.toList().loopFuture((dirPath, index) async {
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
          if (SettingsController.inst.directoriesToExclude.toList().any((exc) => file.path.startsWith(exc))) {
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

  void searchAll(String text) {
    searchTracks(text, temp: true);
    searchAlbums(text, temp: true);
    searchArtists(text, temp: true);
  }

  void searchTracks(String text, {bool temp = false}) {
    final finalList = temp ? trackSearchTemp : trackSearchList;
    finalList.clear();
    if (text == '') {
      if (temp) {
        trackSearchTemp.clear();
      } else {
        LibraryTab.tracks.textSearchController?.clear();
        trackSearchList.assignAll(tracksInfoList);
      }

      return;
    }

    final tsf = SettingsController.inst.trackSearchFilter;
    final sTitle = tsf.contains('title');
    final sAlbum = tsf.contains('album');
    final sAlbumArtist = tsf.contains('albumartist');
    final sArtist = tsf.contains('artist');
    final sGenre = tsf.contains('genre');
    final sComposer = tsf.contains('composer');
    final sYear = tsf.contains('year');

    tracksInfoList.loop((item, index) {
      final lctext = textCleanedForSearch(text);

      if ((sTitle && textCleanedForSearch(item.title).contains(lctext)) ||
          (sAlbum && textCleanedForSearch(item.album).contains(lctext)) ||
          (sAlbumArtist && textCleanedForSearch(item.albumArtist).contains(lctext)) ||
          (sArtist && item.artistsList.any((element) => textCleanedForSearch(element).contains(lctext))) ||
          (sGenre && item.genresList.any((element) => textCleanedForSearch(element).contains(lctext))) ||
          (sComposer && textCleanedForSearch(item.composer).contains(lctext)) ||
          (sYear && textCleanedForSearch(item.year.toString()).contains(lctext))) {
        finalList.add(item);
      }
    });

    printInfo(info: "Tracks Found: ${trackSearchList.length}");
  }

  void searchAlbums(String text, {bool temp = false}) {
    if (text == '') {
      if (temp) {
        albumSearchTemp.clear();
      } else {
        LibraryTab.albums.textSearchController?.clear();
        albumSearchList
          ..clear()
          ..addAll(mainMapAlbums.value.keys);
      }
      return;
    }
    final results = mainMapAlbums.value.keys.where((albumName) => textCleanedForSearch(albumName).contains(textCleanedForSearch(text)));

    if (temp) {
      albumSearchTemp
        ..clear()
        ..addAll(results);
    } else {
      albumSearchList
        ..clear()
        ..addAll(results);
    }
  }

  void searchArtists(String text, {bool temp = false}) {
    if (text == '') {
      if (temp) {
        artistSearchTemp.clear();
      } else {
        LibraryTab.artists.textSearchController?.clear();
        artistSearchList
          ..clear()
          ..addAll(mainMapArtists.value.keys);
      }
      return;
    }
    final results = mainMapArtists.value.keys.where((artistName) => textCleanedForSearch(artistName).contains(textCleanedForSearch(text)));

    if (temp) {
      artistSearchTemp
        ..clear()
        ..addAll(results);
    } else {
      artistSearchList
        ..clear()
        ..addAll(results);
    }
  }

  void searchGenres(String text) {
    if (text == '') {
      LibraryTab.genres.textSearchController?.clear();
      genreSearchList.assignAll(mainMapGenres.value.keys);
      return;
    }
    final results = mainMapGenres.value.keys.where((genreName) => textCleanedForSearch(genreName).contains(textCleanedForSearch(text)));

    genreSearchList
      ..clear()
      ..addAll(results);
  }

  /// Sorts Tracks and Saves automatically to settings
  void sortTracks({SortType? sortBy, bool? reverse}) {
    sortBy ??= SettingsController.inst.tracksSort.value;
    reverse ??= SettingsController.inst.tracksSortReversed.value;
    switch (sortBy) {
      case SortType.title:
        tracksInfoList.sort((a, b) => (a.title).compareTo(b.title));
        break;
      case SortType.album:
        tracksInfoList.sort((a, b) => (a.album).compareTo(b.album));
        break;
      case SortType.albumArtist:
        tracksInfoList.sort((a, b) => (a.albumArtist).compareTo(b.albumArtist));
        break;
      case SortType.year:
        tracksInfoList.sort((a, b) => (a.year).compareTo(b.year));
        break;
      case SortType.artistsList:
        tracksInfoList.sort((a, b) => (a.artistsList.toString()).compareTo(b.artistsList.toString()));
        break;
      case SortType.genresList:
        tracksInfoList.sort((a, b) => (a.genresList.toString()).compareTo(b.genresList.toString()));
        break;
      case SortType.dateAdded:
        tracksInfoList.sort((a, b) => (a.dateAdded).compareTo(b.dateAdded));
        break;
      case SortType.dateModified:
        tracksInfoList.sort((a, b) => (a.dateModified).compareTo(b.dateModified));
        break;
      case SortType.bitrate:
        tracksInfoList.sort((a, b) => (a.bitrate).compareTo(b.bitrate));
        break;
      case SortType.composer:
        tracksInfoList.sort((a, b) => (a.composer).compareTo(b.composer));
        break;
      case SortType.discNo:
        tracksInfoList.sort((a, b) => (a.discNo).compareTo(b.discNo));
        break;
      case SortType.filename:
        tracksInfoList.sort((a, b) => (a.filename.toLowerCase()).compareTo(b.filename.toLowerCase()));
        break;
      case SortType.duration:
        tracksInfoList.sort((a, b) => (a.duration).compareTo(b.duration));
        break;
      case SortType.sampleRate:
        tracksInfoList.sort((a, b) => (a.sampleRate).compareTo(b.sampleRate));
        break;
      case SortType.size:
        tracksInfoList.sort((a, b) => (a.size).compareTo(b.size));
        break;
      case SortType.rating:
        tracksInfoList.sort((a, b) => (a.stats.rating).compareTo(b.stats.rating));
        break;

      default:
        null;
    }

    if (reverse) {
      tracksInfoList.value = tracksInfoList.reversed.toList();
    }
    SettingsController.inst.save(tracksSort: sortBy, tracksSortReversed: reverse);
    searchTracks(LibraryTab.tracks.textSearchController?.text ?? '');
  }

  /// Sorts Albums and Saves automatically to settings
  void sortAlbums({GroupSortType? sortBy, bool? reverse}) {
    sortBy ??= SettingsController.inst.albumSort.value;
    reverse ??= SettingsController.inst.albumSortReversed.value;

    final albumsList = mainMapAlbums.value.entries.toList();
    switch (sortBy) {
      case GroupSortType.album:
        albumsList.sort((a, b) => a.key.compareTo(b.key));
        break;
      case GroupSortType.albumArtist:
        albumsList.sort((a, b) => a.value.first.albumArtist.compareTo(b.value.first.albumArtist));
        break;
      case GroupSortType.year:
        albumsList.sort((a, b) => a.value.first.year.compareTo(b.value.first.year));
        break;
      case GroupSortType.artistsList:
        albumsList.sort((a, b) => a.value.first.artistsList.toString().compareTo(b.value.first.artistsList.toString()));
        break;

      case GroupSortType.composer:
        albumsList.sort((a, b) => a.value.first.composer.compareTo(b.value.first.composer));
        break;
      case GroupSortType.dateModified:
        albumsList.sort((a, b) => a.value.first.dateModified.compareTo(b.value.first.dateModified));
        break;
      case GroupSortType.duration:
        albumsList.sort((a, b) => a.value.toList().totalDurationInS.compareTo(b.value.toList().totalDurationInS));
        break;
      case GroupSortType.numberOfTracks:
        albumsList.sort((a, b) => a.value.length.compareTo(b.value.length));
        break;

      default:
        null;
    }

    mainMapAlbums.value
      ..clear()
      ..addEntries(reverse ? albumsList.reversed : albumsList);

    SettingsController.inst.save(albumSort: sortBy, albumSortReversed: reverse);

    searchAlbums(LibraryTab.albums.textSearchController?.text ?? '');
  }

  /// Sorts Artists and Saves automatically to settings
  void sortArtists({GroupSortType? sortBy, bool? reverse}) {
    sortBy ??= SettingsController.inst.artistSort.value;
    reverse ??= SettingsController.inst.artistSortReversed.value;

    final artistsList = mainMapArtists.value.entries.toList();
    switch (sortBy) {
      case GroupSortType.album:
        artistsList.sort((a, b) => a.value.elementAt(0).album.compareTo(b.value.elementAt(0).album));
        break;
      case GroupSortType.albumArtist:
        artistsList.sort((a, b) => a.value.elementAt(0).albumArtist.compareTo(b.value.elementAt(0).albumArtist));
        break;
      case GroupSortType.year:
        artistsList.sort((a, b) => a.value.elementAt(0).year.compareTo(b.value.elementAt(0).year));
        break;
      case GroupSortType.artistsList:
        artistsList.sort(((a, b) => a.key.compareTo(b.key)));
        break;
      case GroupSortType.genresList:
        artistsList.sort((a, b) => a.value.elementAt(0).genresList.toString().compareTo(b.value.elementAt(0).genresList.toString()));
        break;
      case GroupSortType.composer:
        artistsList.sort((a, b) => a.value.elementAt(0).composer.compareTo(b.value.elementAt(0).composer));
        break;
      case GroupSortType.dateModified:
        artistsList.sort((a, b) => a.value.elementAt(0).dateModified.compareTo(b.value.elementAt(0).dateModified));
        break;
      case GroupSortType.duration:
        artistsList.sort((a, b) => a.value.toList().totalDurationInS.compareTo(b.value.toList().totalDurationInS));
        break;
      case GroupSortType.numberOfTracks:
        artistsList.sort((a, b) => a.value.length.compareTo(b.value.length));
        break;
      case GroupSortType.albumsCount:
        artistsList.sort((a, b) => a.value.map((e) => e.album).toSet().length.compareTo(b.value.map((e) => e.album).toSet().length));
        break;
      default:
        null;
    }
    mainMapArtists.value
      ..clear()
      ..addEntries(reverse ? artistsList.reversed : artistsList);

    SettingsController.inst.save(artistSort: sortBy, artistSortReversed: reverse);

    searchArtists(LibraryTab.artists.textSearchController?.text ?? '');
  }

  /// Sorts Genres and Saves automatically to settings
  void sortGenres({GroupSortType? sortBy, bool? reverse}) {
    sortBy ??= SettingsController.inst.genreSort.value;
    reverse ??= SettingsController.inst.genreSortReversed.value;

    final genresList = mainMapGenres.value.entries.toList();
    switch (sortBy) {
      case GroupSortType.album:
        genresList.sort((a, b) => a.value.elementAt(0).album.compareTo(b.value.elementAt(0).album));
        break;
      case GroupSortType.albumArtist:
        genresList.sort((a, b) => a.value.elementAt(0).albumArtist.compareTo(b.value.elementAt(0).albumArtist));
        break;
      case GroupSortType.year:
        genresList.sort((a, b) => a.value.elementAt(0).year.compareTo(b.value.elementAt(0).year));
        break;
      case GroupSortType.artistsList:
        genresList.sort((a, b) => a.value.elementAt(0).artistsList.toString().compareTo(b.value.elementAt(0).artistsList.toString()));
        break;
      case GroupSortType.genresList:
        genresList.sort(((a, b) => a.key.compareTo(b.key)));
        break;
      case GroupSortType.composer:
        genresList.sort((a, b) => a.value.elementAt(0).composer.compareTo(b.value.elementAt(0).composer));
        break;
      case GroupSortType.dateModified:
        genresList.sort((a, b) => a.value.elementAt(0).dateModified.compareTo(b.value.elementAt(0).dateModified));
        break;
      case GroupSortType.duration:
        genresList.sort((a, b) => a.value.toList().totalDurationInS.compareTo(b.value.toList().totalDurationInS));
        break;
      case GroupSortType.numberOfTracks:
        genresList.sort((a, b) => a.value.length.compareTo(b.value.length));
        break;

      default:
        null;
    }

    mainMapGenres.value
      ..clear()
      ..addEntries(reverse ? genresList.reversed : genresList);

    SettingsController.inst.save(genreSort: sortBy, genreSortReversed: reverse);
    searchGenres(LibraryTab.genres.textSearchController?.text ?? '');
  }

  Future<void> updateImageSizeInStorage([File? newImgFile]) async {
    if (newImgFile != null) {
      artworksInStorage.value++;
      artworksSizeInStorage.value += await newImgFile.stat().then((value) => value.size);
      return;
    }
    await _updateDirectoryStats(k_DIR_ARTWORKS, artworksInStorage, artworksSizeInStorage);
  }

  Future<void> updateWaveformSizeInStorage([File? newWaveFile]) async {
    if (newWaveFile != null) {
      waveformsInStorage.value++;
      waveformsSizeInStorage.value += await newWaveFile.stat().then((value) => value.size);
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

  Future<void> updateVideosSizeInStorage([File? newVideoFile]) async {
    if (newVideoFile != null) {
      videosInStorage.value++;
      videosSizeInStorage.value += await newVideoFile.stat().then((value) => value.size);
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
