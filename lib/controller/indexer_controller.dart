import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_edit/on_audio_edit.dart' as audioedit;
import 'package:on_audio_query/on_audio_query.dart';

import 'package:namida/class/folder.dart';
import 'package:namida/class/group.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/edit_delete_controller.dart';
import 'package:namida/controller/folders_controller.dart';
import 'package:namida/controller/json_to_history_parser.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/translations/strings.dart';

class Indexer {
  static final Indexer inst = Indexer();

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
  final TextEditingController tracksSearchController = TextEditingController();
  final TextEditingController albumsSearchController = TextEditingController();
  final TextEditingController artistsSearchController = TextEditingController();
  final TextEditingController genresSearchController = TextEditingController();

  final RxList<Track> tracksInfoList = <Track>[].obs;
  final RxList<Group> albumsList = <Group>[].obs;
  final RxList<Group> groupedArtistsList = <Group>[].obs;
  final RxList<Group> groupedGenresList = <Group>[].obs;
  final RxList<Folder> groupedFoldersList = <Folder>[].obs;
  // final RxMap<String, List<Track>> groupedFoldersMap = <String, List<Track>>{}.obs;

  final RxList<Track> trackSearchList = <Track>[].obs;
  final RxList<Group> albumSearchList = <Group>[].obs;
  final RxList<Group> artistSearchList = <Group>[].obs;
  final RxList<Group> genreSearchList = <Group>[].obs;

  /// Temporary lists.
  final RxList<Track> trackSearchTemp = <Track>[].obs;
  final RxList<Group> albumSearchTemp = <Group>[].obs;
  final RxList<Group> artistSearchTemp = <Group>[].obs;

  /// tracks map used for lookup
  final Map<String, Track> allTracksMappedByPath = {};
  final Map<String, TrackStats> trackStatsMap = {};

  final OnAudioQuery _query = OnAudioQuery();
  final onAudioEdit = audioedit.OnAudioEdit();

  Future<void> prepareTracksFile() async {
    /// Only awaits if the track file exists, otherwise it will get into normally and start indexing.
    if (await File(k_FILE_PATH_TRACKS).exists() && await File(k_FILE_PATH_TRACKS).stat().then((value) => value.size >= 2)) {
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
    albumsList.clear();
    groupedArtistsList.clear();
    groupedGenresList.clear();
    groupedFoldersList.clear();

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
    //TODO(MSOB7YY): make the check optional, its only really needed when updating tracks (like after editing metadata)
    for (final tr in tracks) {
      /// Assigning Albums
      final album = albumsList.firstWhereOrNull((element) => element.name.toLowerCase() == tr.album.toLowerCase());
      if (album == null) {
        albumsList.add(Group(tr.album, [tr]));
      } else {
        album.tracks.addNoDuplicates(tr, preventDuplicates: preventDuplicates);
      }
      album?.tracks.sort((a, b) => a.title.compareTo(b.title));

      /// Assigning Artist
      for (final artist in tr.artistsList) {
        final art = groupedArtistsList.firstWhereOrNull((element) => element.name.toLowerCase() == artist.toLowerCase());
        if (art == null) {
          groupedArtistsList.add(Group(artist, [tr]));
        } else {
          art.tracks.addNoDuplicates(tr, preventDuplicates: preventDuplicates);
        }
        art?.tracks.sort((a, b) => a.title.compareTo(b.title));
      }

      /// Assigning Genres
      for (final genre in tr.genresList) {
        final gen = groupedGenresList.firstWhereOrNull((element) => element.name.toLowerCase() == genre.toLowerCase());
        if (gen == null) {
          groupedGenresList.add(Group(genre, [tr]));
        } else {
          gen.tracks.addNoDuplicates(tr, preventDuplicates: preventDuplicates);
        }
        gen?.tracks.sort((a, b) => a.title.compareTo(b.title));
      }

      /// Assigning Folders
      final folder = groupedFoldersList.firstWhereOrNull((element) => element.path == tr.folderPath);
      if (folder == null) {
        groupedFoldersList.add(Folder(tr.folderPath, [tr]));
      } else {
        folder.tracks.addNoDuplicates(tr, preventDuplicates: preventDuplicates);
      }
      // final folder = groupedFoldersMap[tr.folderPath];
      // if (folder == null) {
      //   groupedFoldersMap[tr.folderPath] = [tr];
      // } else {
      //   groupedFoldersMap[tr.folderPath]!.add(tr);
      // }
      Folders.inst.sortFolderTracks();
    }
    _sortAll();
  }

  /// extracts artwork from [bytes] or [path] and save to file.
  /// path is needed bothways for making the file name.
  /// using path for extracting will call [onAudioEdit.readAudio] so it will be slower.
  Future<void> extractOneArtwork(String path, {Uint8List? bytes, bool forceReExtract = false}) async {
    final fileOfFull = File("$k_DIR_ARTWORKS${path.getFilename}.png");

    if (forceReExtract) {
      await fileOfFull.delete();
    }

    /// prevent redundent re-creation of image file
    if (!await fileOfFull.exists()) {
      final art = bytes ?? await onAudioEdit.readAudio(path).then((value) => value.firstArtwork);
      if (art != null) {
        final imgFile = await fileOfFull.create(recursive: true);
        imgFile.writeAsBytesSync(art);
      }
    }

    updateImageSizeInStorage();
  }

  Future<void> updateTracks(List<Track> tracks, {bool updateArtwork = false}) async {
    final paths = tracks.map((e) => e.path).toSet();
    await fetchAllSongsAndWriteToFile(audioFiles: {}, deletedPaths: paths, forceReIndex: false);
    await fetchAllSongsAndWriteToFile(audioFiles: paths, deletedPaths: {}, forceReIndex: false);
    await _saveTrackFileToStorage();

    if (updateArtwork) {
      for (final track in tracks) {
        await EditDeleteController.inst.deleteArtwork(tracks);
        await extractOneArtwork(track.path, forceReExtract: true);
      }
    }
    final newtracks = paths.map((e) => e.toTrackOrNull());
    _addTheseTracksToAlbumGenreArtistEtc(newtracks.whereType<Track>().toList(), preventDuplicates: true);
  }

  Map<String?, Set<Track>> getAlbumsForArtist(String artist) {
    Map<String?, Set<Track>> trackAlbumsMap = {};
    for (final track in tracksInfoList) {
      if (track.artistsList.contains(artist)) {
        final k = track.album;
        if (trackAlbumsMap.containsKey(k)) {
          trackAlbumsMap[k]!.add(track);
        } else {
          trackAlbumsMap[k] = {track};
        }
      }
    }
    return trackAlbumsMap;
  }

  Future<Track?> convertPathToTrack(String trackPath) async {
    final trako = trackPath.toTrackOrNull();
    if (trako != null) return trako;

    await fetchAllSongsAndWriteToFile(audioFiles: {trackPath}, deletedPaths: {}, forceReIndex: false, bypassAllChecks: true);

    final t = trackPath.toTrackOrNull();
    if (t != null) {
      _addTheseTracksToAlbumGenreArtistEtc([t], preventDuplicates: true);
      _sortAll();
      return trackPath.toTrackOrNull();
    }

    return null;
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
          if (!bypassAllChecks && SettingsController.inst.preventDuplicatedTracks.value && listOfCurrentFileNames.contains(trackPath.getFilename)) {
            duplicatedTracksLength.value++;
            continue;
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

          /// adding cummy track that couldnt be read by [onAudioEdit]
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
        Set<String> listOfCurrentFileNames = <String>{};
        final listOfTracksWithoutDuplicates = <Track>[];
        for (final tr in tracksInfoList) {
          if (!listOfCurrentFileNames.contains(tr.filename)) {
            listOfTracksWithoutDuplicates.add(tr);
            listOfCurrentFileNames.add(tr.filename);
          } else {
            duplicatedTracksLength.value++;
          }
        }
        tracksInfoList.assignAll(listOfTracksWithoutDuplicates);
      }
    }

    if (forceReIndex) _afterIndexing();

    printInfo(info: "FINAL: ${tracksInfoList.length}");

    await _saveTrackFileToStorage();

    /// Creating Default Artwork
    if (!await File(k_FILE_PATH_NAMIDA_LOGO).exists()) {
      ByteData byteData = await rootBundle.load('assets/namida_icon.png');
      File file = await File(k_FILE_PATH_NAMIDA_LOGO).create(recursive: true);
      await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    }
  }

  Future<void> _saveTrackFileToStorage() async {
    await File(k_FILE_PATH_TRACKS).writeAsString(json.encode(tracksInfoList));
  }

  Future<void> saveTrackStatsFileToStorage() async {
    await File(k_FILE_PATH_TRACKS_STATS).writeAsString(json.encode(trackStatsMap.values.toList()));
  }

  Future<void> readTrackData() async {
    /// reading stats file containing track rating etc.
    try {
      final jsonResponse = await JsonToHistoryParser.inst.readJSONFile(k_FILE_PATH_TRACKS_STATS);

      if (jsonResponse != null) {
        for (final p in jsonResponse) {
          final trst = TrackStats.fromJson(p);
          if (trst.path != null) {
            trackStatsMap[trst.path!] = trst;
          }
        }
      }
    } catch (e) {
      printError(info: e.toString());
    }

    // clearing for cases which refreshing library is required (like after changing separators)
    tracksInfoList.clear();

    /// reading actual track file.
    try {
      final jsonResponse = await JsonToHistoryParser.inst.readJSONFile(k_FILE_PATH_TRACKS);

      if (jsonResponse != null) {
        for (final p in jsonResponse) {
          final tr = Track.fromJson(p);
          tr.stats = trackStatsMap[tr.path] ?? TrackStats('', 0, [], [], 0);
          tracksInfoList.add(tr);
          allTracksMappedByPath[tr.path] = tr;
        }
      }
      debugPrint("Tracks Info List Length From File: ${tracksInfoList.length}");
    } catch (e) {
      printError(info: e.toString());
    }
  }

  List<String> splitBySeparators(String? string, Iterable<String> separators, String fallback, List<String> blacklist) {
    final List<String> finalStrings = <String>[];
    final List<String> pre = string?.trim().multiSplit(separators, blacklist) ?? [fallback];
    for (final element in pre) {
      finalStrings.addIf(element != '', element.trim());
    }
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
  /// then subdirectories [/storage/0/Music/folder1],[/storage/0/Music/folder2] will be excluded too.
  Future<Set<String>> getAudioFiles({bool strictNoMedia = true}) async {
    tracksExcludedByNoMedia.value = 0;
    final allPaths = <String>{};
    final allAvailableDirectories = <Directory, bool>{};

    for (final dirPath in SettingsController.inst.directoriesToScan.toList()) {
      final directory = Directory(dirPath);

      if (await directory.exists()) {
        allAvailableDirectories[directory] = false;

        await for (final file in directory.list(recursive: true, followLinks: true)) {
          if (file is Directory) {
            allAvailableDirectories[file] = false;
          }
        }
      }
    }

    /// Assigning directories and sub-subdirectories that has .nomedia.
    if (SettingsController.inst.respectNoMedia.value) {
      for (final d in allAvailableDirectories.keys) {
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
      }
    }

    for (final d in allAvailableDirectories.keys) {
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
    }
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
        tracksSearchController.clear();
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

    for (final item in tracksInfoList) {
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
    }
    printInfo(info: "Tracks Found: ${trackSearchList.length}");
  }

  void searchAlbums(String text, {bool temp = false}) {
    if (text == '') {
      if (temp) {
        albumSearchTemp.clear();
      } else {
        albumsSearchController.clear();
        albumSearchList.assignAll(albumsList);
      }
      return;
    }
    if (temp) {
      albumSearchTemp.assignAll(albumsList.where((al) => textCleanedForSearch(al.name).contains(textCleanedForSearch(text))));
    } else {
      albumSearchList.assignAll(albumsList.where((al) => textCleanedForSearch(al.name).contains(textCleanedForSearch(text))));
    }
  }

  void searchArtists(String text, {bool temp = false}) {
    if (text == '') {
      if (temp) {
        artistSearchTemp.clear();
      } else {
        artistsSearchController.clear();
        artistSearchList.assignAll(groupedArtistsList);
      }

      return;
    }
    if (temp) {
      artistSearchTemp.assignAll(groupedArtistsList.where((ar) => textCleanedForSearch(ar.name).contains(textCleanedForSearch(text))));
    } else {
      artistSearchList.assignAll(groupedArtistsList.where((ar) => textCleanedForSearch(ar.name).contains(textCleanedForSearch(text))));
    }
  }

  void searchGenres(String text) {
    if (text == '') {
      genresSearchController.clear();
      genreSearchList.assignAll(groupedGenresList);
      return;
    }
    genreSearchList.assignAll(groupedGenresList.where((gen) => textCleanedForSearch(gen.name).contains(textCleanedForSearch(text))));
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
    searchTracks(tracksSearchController.value.text);
  }

  /// Sorts Albums and Saves automatically to settings
  void sortAlbums({GroupSortType? sortBy, bool? reverse}) {
    sortBy ??= SettingsController.inst.albumSort.value;
    reverse ??= SettingsController.inst.albumSortReversed.value;
    switch (sortBy) {
      case GroupSortType.album:
        albumsList.sort((a, b) => a.name.compareTo(b.name));
        break;
      case GroupSortType.albumArtist:
        albumsList.sort((a, b) => a.tracks.first.albumArtist.compareTo(b.tracks.first.albumArtist));
        break;
      case GroupSortType.year:
        albumsList.sort((a, b) => a.tracks.first.year.compareTo(b.tracks.first.year));
        break;
      case GroupSortType.artistsList:
        albumsList.sort((a, b) => a.tracks.first.artistsList.toString().compareTo(b.tracks.first.artistsList.toString()));
        break;

      case GroupSortType.composer:
        albumsList.sort((a, b) => a.tracks.first.composer.compareTo(b.tracks.first.composer));
        break;
      case GroupSortType.dateModified:
        albumsList.sort((a, b) => a.tracks.first.dateModified.compareTo(b.tracks.first.dateModified));
        break;
      case GroupSortType.duration:
        albumsList.sort((a, b) => a.tracks.toList().totalDuration.compareTo(b.tracks.toList().totalDuration));
        break;
      case GroupSortType.numberOfTracks:
        albumsList.sort((a, b) => a.tracks.length.compareTo(b.tracks.length));
        break;

      default:
        null;
    }

    if (reverse) {
      albumsList.value = albumsList.reversed.toList();
    }

    SettingsController.inst.save(albumSort: sortBy, albumSortReversed: reverse);

    searchAlbums(albumsSearchController.value.text);
  }

  /// Sorts Artists and Saves automatically to settings
  void sortArtists({GroupSortType? sortBy, bool? reverse}) {
    sortBy ??= SettingsController.inst.artistSort.value;
    reverse ??= SettingsController.inst.artistSortReversed.value;
    switch (sortBy) {
      case GroupSortType.album:
        groupedArtistsList.sort((a, b) => a.tracks.elementAt(0).album.compareTo(b.tracks.elementAt(0).album));
        break;
      case GroupSortType.albumArtist:
        groupedArtistsList.sort((a, b) => a.tracks.elementAt(0).albumArtist.compareTo(b.tracks.elementAt(0).albumArtist));
        break;
      case GroupSortType.year:
        groupedArtistsList.sort((a, b) => a.tracks.elementAt(0).year.compareTo(b.tracks.elementAt(0).year));
        break;
      case GroupSortType.artistsList:
        groupedArtistsList.sort(((a, b) => a.name.compareTo(b.name)));
        break;
      case GroupSortType.genresList:
        groupedArtistsList.sort((a, b) => a.tracks.elementAt(0).genresList.toString().compareTo(b.tracks.elementAt(0).genresList.toString()));
        break;
      case GroupSortType.composer:
        groupedArtistsList.sort((a, b) => a.tracks.elementAt(0).composer.compareTo(b.tracks.elementAt(0).composer));
        break;
      case GroupSortType.dateModified:
        groupedArtistsList.sort((a, b) => a.tracks.elementAt(0).dateModified.compareTo(b.tracks.elementAt(0).dateModified));
        break;
      case GroupSortType.duration:
        groupedArtistsList.sort((a, b) => a.tracks.toList().totalDuration.compareTo(b.tracks.toList().totalDuration));
        break;
      case GroupSortType.numberOfTracks:
        groupedArtistsList.sort((a, b) => a.tracks.length.compareTo(b.tracks.length));
        break;
      case GroupSortType.albumsCount:
        groupedArtistsList.sort((a, b) => a.tracks.map((e) => e.album).toSet().length.compareTo(b.tracks.map((e) => e.album).toSet().length));
        break;
      default:
        null;
    }
    if (reverse) {
      groupedArtistsList.value = groupedArtistsList.reversed.toList();
    }

    SettingsController.inst.save(artistSort: sortBy, artistSortReversed: reverse);

    searchArtists(artistsSearchController.value.text);
  }

  /// Sorts Genres and Saves automatically to settings
  void sortGenres({GroupSortType? sortBy, bool? reverse}) {
    sortBy ??= SettingsController.inst.genreSort.value;
    reverse ??= SettingsController.inst.genreSortReversed.value;
    switch (sortBy) {
      case GroupSortType.album:
        groupedGenresList.sort((a, b) => a.tracks.elementAt(0).album.compareTo(b.tracks.elementAt(0).album));
        break;
      case GroupSortType.albumArtist:
        groupedGenresList.sort((a, b) => a.tracks.elementAt(0).albumArtist.compareTo(b.tracks.elementAt(0).albumArtist));
        break;
      case GroupSortType.year:
        groupedGenresList.sort((a, b) => a.tracks.elementAt(0).year.compareTo(b.tracks.elementAt(0).year));
        break;
      case GroupSortType.artistsList:
        groupedGenresList.sort((a, b) => a.tracks.elementAt(0).artistsList.toString().compareTo(b.tracks.elementAt(0).artistsList.toString()));
        break;
      case GroupSortType.genresList:
        groupedGenresList.sort(((a, b) => a.name.compareTo(b.name)));
        break;
      case GroupSortType.composer:
        groupedGenresList.sort((a, b) => a.tracks.elementAt(0).composer.compareTo(b.tracks.elementAt(0).composer));
        break;
      case GroupSortType.dateModified:
        groupedGenresList.sort((a, b) => a.tracks.elementAt(0).dateModified.compareTo(b.tracks.elementAt(0).dateModified));
        break;
      case GroupSortType.duration:
        groupedGenresList.sort((a, b) => a.tracks.toList().totalDuration.compareTo(b.tracks.toList().totalDuration));
        break;
      case GroupSortType.numberOfTracks:
        groupedGenresList.sort((a, b) => a.tracks.length.compareTo(b.tracks.length));
        break;

      default:
        null;
    }
    if (reverse) {
      groupedGenresList.value = groupedGenresList.reversed.toList();
    }

    SettingsController.inst.save(genreSort: sortBy, genreSortReversed: reverse);
    searchGenres(genresSearchController.value.text);
  }

  void updateImageSizeInStorage() {
    // resets values
    artworksInStorage.value = 0;
    artworksSizeInStorage.value = 0;

    Directory(k_DIR_ARTWORKS).listSync(recursive: true, followLinks: false).forEach((FileSystemEntity entity) {
      if (entity is File) {
        artworksInStorage.value++;
        artworksSizeInStorage.value += entity.lengthSync();
      }
    });
  }

  void updateWaveformSizeInStorage() {
    // resets values
    waveformsInStorage.value = 0;
    waveformsSizeInStorage.value = 0;

    Directory(k_DIR_WAVEFORMS).listSync(recursive: true, followLinks: false).forEach((FileSystemEntity entity) {
      if (entity is File) {
        waveformsInStorage.value++;
        waveformsSizeInStorage.value += entity.lengthSync();
      }
    });
  }

  void updateColorPalettesSizeInStorage() {
    // resets values
    colorPalettesInStorage.value = 0;

    Directory(k_DIR_PALETTES).listSync(recursive: true, followLinks: false).forEach((FileSystemEntity entity) {
      if (entity is File) {
        colorPalettesInStorage.value++;
      }
    });
  }

  void updateVideosSizeInStorage() {
    // resets values
    videosInStorage.value = 0;
    videosSizeInStorage.value = 0;

    Directory(k_DIR_VIDEOS_CACHE).listSync(recursive: true, followLinks: false).forEach((FileSystemEntity entity) {
      if (entity is File) {
        videosInStorage.value++;
        videosSizeInStorage.value += entity.lengthSync();
      }
    });
  }

  Future<void> clearImageCache() async {
    await Directory(k_DIR_ARTWORKS).delete(recursive: true);
    await Directory(k_DIR_ARTWORKS).create();
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
      for (final v in videosToDelete) {
        await v.delete();
      }
    } else {
      await Directory(k_DIR_VIDEOS_CACHE).delete(recursive: true);
      await Directory(k_DIR_VIDEOS_CACHE).create();
    }

    updateVideosSizeInStorage();
  }
}
