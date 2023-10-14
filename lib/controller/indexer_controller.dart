// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:faudiotagger/faudiotagger.dart';
import 'package:faudiotagger/models/faudiomodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import 'package:namida/class/folder.dart';
import 'package:namida/class/split_config.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/ffmpeg_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';

class Indexer {
  static Indexer get inst => _instance;
  static final Indexer _instance = Indexer._internal();
  Indexer._internal();

  bool get _defaultGroupArtworksByAlbum => settings.groupArtworksByAlbum.value;

  final RxBool isIndexing = false.obs;

  final currentTrackPathBeingExtracted = ''.obs;
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
  final Map<String, bool> _currentFileNamesMap = {};

  static final _faudiotagger = FAudioTagger();

  List<Track> get recentlyAddedTracks {
    final alltracks = List<Track>.from(tracksInfoList);
    alltracks.sortByReverseAlt((e) => e.dateModified, (e) => e.dateAdded);
    return alltracks;
  }

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

  final _cancelableIndexingCompleter = <DateTime, Completer<void>>{};

  Future<void> refreshLibraryAndCheckForDiff({Set<String>? currentFiles, bool forceReIndex = false}) async {
    _cancelableIndexingCompleter.entries.lastOrNull?.value.complete(); // canceling previous indexing sessions

    isIndexing.value = true;

    final indexingTokenTime = DateTime.now();
    _cancelableIndexingCompleter[indexingTokenTime] = Completer<void>();

    if (forceReIndex || tracksInfoList.isEmpty) {
      await _fetchAllSongsAndWriteToFile(
        audioFiles: {},
        deletedPaths: {},
        forceReIndex: true,
        cancelTokenTime: indexingTokenTime,
      );
    } else {
      currentFiles ??= await getAudioFiles();
      await _fetchAllSongsAndWriteToFile(
        audioFiles: getNewFoundPaths(currentFiles),
        deletedPaths: getDeletedPaths(currentFiles),
        forceReIndex: false,
        cancelTokenTime: indexingTokenTime,
      );
    }

    _afterIndexing();
    isIndexing.value = false;
    snackyy(title: lang.DONE, message: lang.FINISHED_UPDATING_LIBRARY);
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
      mainMapAlbums.value.addForce(trExt.albumIdentifier, tr);

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

    mainMapAlbums.value.updateAll((key, value) => value..sortByAlts((e) => e.year, [(e) => e.trackNo, (e) => e.title]));
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
      mainMapAlbums.value[trExt.albumIdentifier]?.remove(tr);

      trExt.artistsList.loop((artist, i) {
        mainMapArtists.value[artist]?.remove(tr);
      });
      trExt.genresList.loop((genre, i) {
        mainMapGenres.value[genre]?.remove(tr);
      });
      mainMapFolders[tr.folder]?.remove(tr);

      _currentFileNamesMap.remove(tr.filename);
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
      mainMapAlbums.value.addNoDuplicatesForce(trExt.albumIdentifier, tr);

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
      addedAlbums.add(trExt.albumIdentifier);
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
  /// - Nullable only if [minDur] or [minSize] is used, or if extraction fails.
  static Future<List<Map<String, dynamic>>> extractOneTrackIsolate(Map parameters) async {
    final trackPaths = parameters["trackPaths"] as List<String>;
    final minDur = parameters["minDur"] as int;
    final minSize = parameters["minSize"] as int;
    final tryExtractingFromFilename = parameters["tryExtractingFromFilename"] as bool;
    final faudiomodelsSent = parameters["faudiomodels"] as Map;
    final artworksSent = parameters["artworks"] as Map;

    final token = parameters["token"] as RootIsolateToken;
    BackgroundIsolateBinaryMessenger.ensureInitialized(token);

    Future<Map<String, dynamic>> extracty(String trackPath) async {
      // -- most methods dont throw, except for timeout
      try {
        const timeoutDuration = Duration(seconds: 10); // 10s for each method, 2 more fallback methods so totalDuration is upto 30s

        // -- returns null early depending on size [byte] or duration [seconds]
        FileStat? fileStat;
        try {
          fileStat = File(trackPath).statSync();
          if (minSize != 0 && fileStat.size < minSize) {
            return {
              'path': _ExtractionErrorMessage.sizeLimit.name,
              'errorMessage': _ExtractionErrorMessage.sizeLimit.name,
            };
          }
        } catch (_) {}

        late TrackExtended finalTrackExtended;

        FAudioModel? trackInfo;
        Uint8List? artwork;

        // -- try filling from sent model & artwork
        final faudiomodelSent = faudiomodelsSent[trackPath];
        if (faudiomodelSent != null) {
          try {
            trackInfo = FAudioModel.fromMap(faudiomodelSent);
          } catch (_) {}
        }

        artwork = artworksSent[trackPath];
        // ----

        // if one of them wasnt sent, we extract using tagger
        if (trackInfo == null && artwork == null) {
          final infoAndArtwork = await _faudiotagger.readAllData(path: trackPath).timeout(timeoutDuration);
          trackInfo ??= infoAndArtwork;
          artwork ??= infoAndArtwork?.firstArtwork;
        }

        if (trackInfo == null && !tryExtractingFromFilename) {
          return {
            'errorMessage': _ExtractionErrorMessage.failed.name,
            'artwork': artwork,
          };
        }

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
          duration: 0,
          year: 0,
          size: fileStat?.size ?? 0,
          dateAdded: fileStat?.accessed.millisecondsSinceEpoch ?? 0,
          dateModified: fileStat?.changed.millisecondsSinceEpoch ?? 0,
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
          int durationInSeconds = trackInfo.length ?? 0;
          // if (durationInSeconds == 0) {
          //   final ap = AudioPlayer();
          //   final dur = await ap.setFilePath(trackPath).timeout(timeoutDuration);
          //   durationInSeconds = dur?.inSeconds ?? 0;
          //   ap.dispose();
          // }
          if (minDur != 0 && durationInSeconds != 0 && durationInSeconds < minDur) {
            return {
              'errorMessage': _ExtractionErrorMessage.durationLimit.name,
              'artwork': artwork,
            };
          }
          // ===== Separation is now done from source =====
          // ===== since settings are not accessible from isolate =====
          // // -- Split Artists
          // final artists = splitArtist(
          //   title: trackInfo.title,
          //   originalArtist: trackInfo.artist,
          //   config: ArtistsSplitConfig.settings(),
          // );

          // // -- Split Genres
          // final genres = splitGenre(
          //   trackInfo.genre,
          //   config: GenresSplitConfig.settings(),
          // );

          // // -- Split Moods (using same genre splitters)
          // final moods = splitGenre(
          //   trackInfo.mood,
          //   config: GenresSplitConfig.settings(),
          // );

          String? trimOrNull(String? value) => value == null ? value : value.trimAll();
          String? nullifyEmpty(String? value) => value == '' ? null : value;
          String? doMagic(String? value) => nullifyEmpty(trimOrNull(value));

          finalTrackExtended = initialTrack.copyWith(
            title: doMagic(trackInfo.title),
            originalArtist: doMagic(trackInfo.artist),
            // artistsList: artists,
            album: doMagic(trackInfo.album),
            albumArtist: doMagic(trackInfo.albumArtist),
            originalGenre: doMagic(trackInfo.genre),
            // genresList: genres,
            originalMood: doMagic(trackInfo.mood),
            // moodList: moods,
            composer: doMagic(trackInfo.composer),
            trackNo: trackInfo.trackNumber.getIntValue(),
            duration: durationInSeconds,
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
          // ------------------------------------------------------------

          // extractOneArtwork(
          //   trackPath,
          //   bytes: artwork,
          //   forceReExtract: deleteOldArtwork,
          //   extractColor: extractColor,
          //   albumIdendifier: finalTrackExtended.albumIdentifier,
          // );
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
          // extractOneArtwork(
          //   trackPath,
          //   forceReExtract: deleteOldArtwork,
          //   extractColor: extractColor,
          //   albumIdendifier: finalTrackExtended.albumIdentifier,
          // );
        }

        final m = finalTrackExtended.toJson();
        m['errorMessage'] = _ExtractionErrorMessage.success.name;
        m['artwork'] = artwork;
        return m;
      } catch (e) {
        return {'errorMessage': _ExtractionErrorMessage.timeout.name};
      }
    }

    if (trackPaths.isNotEmpty) {
      final all = <Map<String, dynamic>>[];
      final completer = Completer<void>();
      for (final trackPath in trackPaths) {
        extracty(trackPath).then((r) {
          r['path'] = trackPath;
          all.add(r);
          if (all.length == trackPaths.length) completer.completeIfWasnt();
        });
      }
      await completer.future;
      return all;
    }
    return [];
  }

  /// - Extracts Metadata for given track path
  /// - Nullable only if [minDur] or [minSize] is used, or if extraction fails.
  Future<Map<String, TrackExtended>> extractOneTrack({
    required List<String> tracksPath,
    int minDur = 0,
    int minSize = 0,
    void Function()? onMinDurTrigger,
    void Function()? onMinSizeTrigger,
    bool deleteOldArtwork = false,
    bool checkForDuplicates = true,
    bool tryExtractingFromFilename = true,
    bool extractColor = false,
  }) async {
    Future<List<(String, TrackExtended?, Uint8List?)>> executeOnThread({
      required List<String> paths,
      Map<String, FAudioModel?> audiomodels = const {},
      Map<String, Uint8List?> artworks = const {},
    }) async {
      final results = await extractOneTrackIsolate.thready({
        "token": RootIsolateToken.instance,
        "trackPaths": paths,
        "minDur": minDur,
        "minSize": minSize,
        "tryExtractingFromFilename": tryExtractingFromFilename,
        "faudiomodels": audiomodels.isEmpty ? {} : {for (final m in audiomodels.entries) m.key: m.value?.toMap()},
        "artworks": artworks,
      });
      final all = <(String, TrackExtended?, Uint8List?)>[];
      for (final res in results) {
        final path = res['path'] as String;
        final artwork = res["artwork"] as Uint8List?;
        final code = _ExtractionErrorMessage.values.getEnum(res['errorMessage'] as String);
        TrackExtended? finalTrackExtended;
        switch (code) {
          case _ExtractionErrorMessage.durationLimit:
            if (onMinDurTrigger != null) onMinDurTrigger();
            break;
          case _ExtractionErrorMessage.sizeLimit:
            if (onMinSizeTrigger != null) onMinSizeTrigger();
            break;
          case _ExtractionErrorMessage.timeout || _ExtractionErrorMessage.failed:
            printy('Error or timeout occured while extracting $path');
            all.add((path, null, artwork));

            break;
          case _ExtractionErrorMessage.success:
            {
              try {
                finalTrackExtended = TrackExtended.fromJson(
                  res,
                  artistsSplitConfig: ArtistsSplitConfig.settings(),
                  genresSplitConfig: GenresSplitConfig.settings(),
                );
              } catch (_) {}
            }
            break;

          default:
            null;
        }
        all.add((path, finalTrackExtended, artwork));
      }
      return all;
    }

    final success = <String, TrackExtended>{};
    final failed = <String>[];
    final artworks = <String, Uint8List?>{};
    final results = await executeOnThread(paths: tracksPath);
    for (final r in results) {
      final trext = r.$2;
      if (trext != null && trext.duration > 0) {
        success[r.$1] = trext;
      } else {
        failed.add(r.$1);
      }
      artworks[r.$1] = r.$3;
    }
    final ffmpegModel = <String, FAudioModel?>{};
    for (final f in failed) {
      final r = await _faudiotagger.extractMetadata(trackPath: f, forceExtractByFFmpeg: true);
      ffmpegModel[f] = r.$1;
      artworks[f] = r.$2;
    }
    final resultsFFMPEG = await executeOnThread(
      paths: failed,
      audiomodels: ffmpegModel,
      artworks: artworks,
    );
    for (final r in resultsFFMPEG) {
      if (r.$2 != null) {
        success[r.$1] = r.$2!;
      }
      if (r.$3 != null) {
        artworks[r.$1] = r.$3;
      }
    }
    for (final trext in success.values) {
      final tr = trext.toTrack();
      allTracksMappedByPath[tr] = trext;
      _currentFileNamesMap[trext.path.getFilename] = true;
      if (checkForDuplicates) {
        tracksInfoList.addNoDuplicates(tr);
        SearchSortController.inst.trackSearchList.addNoDuplicates(tr);
      } else {
        tracksInfoList.add(tr);
        SearchSortController.inst.trackSearchList.add(tr);
      }
    }

    extractOneArtwork(
      tracksPath,
      artworks: artworks,
      forceReExtract: deleteOldArtwork,
      extractColor: extractColor,
      albumIdendifiers: {for (final r in success.entries) r.key: r.value.albumIdentifier},
    );
    return success;
  }

  /// - Extracts artwork from [bytes] or [pathOfAudio] and save to file.
  /// - Path is needed bothways for making the file name.
  /// - Using path for extracting will call [_faudiotagger.readArtwork] so it will be slower.
  /// - `final art = bytes ?? await _faudiotagger.readArtwork(path: pathOfAudio);`
  /// - Sending [artworkPath] that points towards an image file will just copy it to [AppDirs.ARTWORKS]
  /// - Returns the Artwork Files created.
  Future<List<File?>> extractOneArtwork(
    List<String> pathOfAudios, {
    Map<String, Uint8List?> artworks = const {},
    Map<String, String> artworkPaths = const {},
    bool forceReExtract = false,
    bool extractColor = false,
    required Map<String, String> albumIdendifiers,
  }) async {
    final parameters = {
      "dirPath": AppDirs.ARTWORKS,
      "pathOfAudios": pathOfAudios,
      "artworks": artworks,
      "forceReExtract": forceReExtract,
      "groupArtworksByAlbum": _defaultGroupArtworksByAlbum,
      "artworkPaths": artworkPaths,
      "albumIdendifiers": albumIdendifiers,
      "initialCount": artworksInStorage.value,
      "initialSize": artworksSizeInStorage.value,
      "token": RootIsolateToken.instance,
    };
    final resAndStats = await extractOneArtworkIsolate.thready(parameters);
    final artworkFiles = <File?>[];

    final res = resAndStats.$1;
    final stats = resAndStats.$2;
    artworksInStorage.value = stats.$1;
    artworksSizeInStorage.value = stats.$2;
    for (final r in res) {
      final audioPath = r.$1;
      File? artworkFile = r.$2;
      if (artworkFile == null) {
        final nameInCache = _defaultGroupArtworksByAlbum ? albumIdendifiers[audioPath] : audioPath.getFilename;
        final thumbnailSavePath = p.join(AppDirs.ARTWORKS, "$nameInCache.png");
        final f = await NamidaFFMPEG.inst.extractAudioThumbnail(
          audioPath: r.$1,
          thumbnailSavePath: thumbnailSavePath,
        );
        artworkFiles.add(f);
      }
      artworkFiles.add(artworkFile);
    }

    if (extractColor) {
      for (final r in artworkFiles) {
        final p = r?.path;
        if (p != null) {
          final tr = Track(p);
          await CurrentColor.inst.reExtractTrackColorPalette(track: tr, newNC: null, imagePath: p, useIsolate: true);
        }
      }
    }

    return artworkFiles;
  }

  static Future<(List<(String, File?)>, (int, int))> extractOneArtworkIsolate(Map parameters) async {
    final dirPath = parameters["dirPath"] as String;
    final pathOfAudios = parameters["pathOfAudios"] as List<String>;
    final artworks = parameters["artworks"] as Map<String, Uint8List?>;
    final forceReExtract = parameters["forceReExtract"] as bool;
    final groupArtworksByAlbum = parameters["groupArtworksByAlbum"] as bool;
    final artworkPaths = parameters["artworkPaths"] as Map<String, String>;
    final albumIdendifiers = parameters["albumIdendifiers"] as Map<String, String>;
    int initialCount = parameters["initialCount"] as int? ?? 0;
    int initialSize = parameters["initialSize"] as int? ?? 0;

    final token = parameters["token"] as RootIsolateToken;
    BackgroundIsolateBinaryMessenger.ensureInitialized(token);

    void updateImageSize({String? newImagePath, File? oldDeletedFile}) {
      if (oldDeletedFile != null) {
        if (oldDeletedFile.existsSync()) {
          initialCount--;
          initialSize -= oldDeletedFile.sizeInBytesSync();
        }
      }
      if (newImagePath != null) {
        initialCount++;
        initialSize += File(newImagePath).sizeInBytesSync();
      }
    }

    Future<(String, File?)> extractyArtworky({required String pathOfAudio}) async {
      final nameInCache = groupArtworksByAlbum ? albumIdendifiers[pathOfAudio] : pathOfAudio.getFilename;
      final fileOfFull = File(p.join(dirPath, "$nameInCache.png"));
      final artworkPath = artworkPaths[pathOfAudio];
      if (artworkPath != null) {
        updateImageSize(oldDeletedFile: fileOfFull); // removing old file stats
        final newFile = File(artworkPath).copySync(fileOfFull.path);
        updateImageSize(newImagePath: artworkPath); // adding new file stats
        return (pathOfAudio, newFile);
      }

      if (!forceReExtract && fileOfFull.existsAndValidSync()) {
        return (pathOfAudio, fileOfFull);
      }

      final art = artworks[pathOfAudio] ?? await _faudiotagger.readArtwork(path: pathOfAudio);

      if (art != null) {
        try {
          updateImageSize(oldDeletedFile: fileOfFull); // removing old file stats
          if (forceReExtract) {
            fileOfFull.deleteIfExistsSync();
          }
          fileOfFull.createSync(recursive: true);
          fileOfFull.writeAsBytesSync(art);
          updateImageSize(newImagePath: fileOfFull.path); // adding new file stats
          return (pathOfAudio, fileOfFull);
        } catch (e) {
          printo(e, isError: true);
          return (pathOfAudio, null);
        }
      }
      return (pathOfAudio, null);
    }

    if (pathOfAudios.isNotEmpty) {
      final extractedArtworks = <(String, File?)>[];
      final completer = Completer<void>();
      for (final pathOfAudio in pathOfAudios) {
        extractyArtworky(pathOfAudio: pathOfAudio).then((value) {
          extractedArtworks.add(value);
          if (extractedArtworks.length == pathOfAudios.length) completer.completeIfWasnt();
        });
      }
      await completer.future;
      return (extractedArtworks, (initialCount, initialSize));
    }
    return (<(String, File?)>[], (initialCount, initialSize));
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
    }

    await tracksReal.loopFuture((track, index) async {
      if (tracksExisting[track] == false) {
        onProgress(false);
      } else {
        final tr = await extractOneTrack(
          tracksPath: [track.path],
          tryExtractingFromFilename: tryExtractingFromFilename,
          extractColor: true,
          deleteOldArtwork: true,
        );
        onProgress(tr[track.path] != null);
      }
    });

    final newtracks = tracksReal.map((e) => e.path.toTrackOrNull());
    _addTheseTracksToAlbumGenreArtistEtc(newtracks.whereType<Track>().toList());
    Player.inst.refreshNotification();
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
      _currentFileNamesMap.remove(ot.filename);
      _currentFileNamesMap[nt.filename] = true;

      if (newArtworkPath != '') {
        await extractOneArtwork(
          [ot.path],
          forceReExtract: true,
          artworkPaths: {ot.path: newArtworkPath},
          albumIdendifiers: {ot.path: e.value.albumIdentifier},
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

    await tracksPath.loopFuture((tp, index) async {
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
    required DateTime cancelTokenTime,
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

    final minDur = settings.indexMinDurationInSec.value; // Seconds
    final minSize = settings.indexMinFileSizeInB.value; // bytes
    final prevDuplicated = settings.preventDuplicatedTracks.value;

    currentTrackPathBeingExtracted.value = '';
    final chunkExtractList = <String>[];
    if (audioFiles.isNotEmpty) {
      // -- Extracting All Metadata
      for (final trackPath in audioFiles) {
        // breaks the loop if another indexing session has been started
        if (_cancelableIndexingCompleter[cancelTokenTime]?.isCompleted == true) break;

        printy(trackPath);
        currentTrackPathBeingExtracted.value = trackPath;

        /// skip duplicated tracks according to filename
        if (prevDuplicated) {
          if (_currentFileNamesMap.keyExists(trackPath.getFilename)) {
            duplicatedTracksLength.value++;
            continue;
          }
        }

        if (chunkExtractList.isNotEmpty && chunkExtractList.length % 24 == 0) {
          await extractOneTrack(
            tracksPath: chunkExtractList,
            minDur: minDur,
            minSize: minSize,
            onMinDurTrigger: () => filteredForSizeDurationTracks.value++,
            onMinSizeTrigger: () => filteredForSizeDurationTracks.value++,
            checkForDuplicates: false,
          );
          chunkExtractList.clear();
        }

        chunkExtractList.add(trackPath);
      }
      // -- if there were any items left (length < 24)
      await extractOneTrack(
        tracksPath: chunkExtractList,
        minDur: minDur,
        minSize: minSize,
        onMinDurTrigger: () => filteredForSizeDurationTracks.value++,
        onMinSizeTrigger: () => filteredForSizeDurationTracks.value++,
        checkForDuplicates: false,
      );
      printy('Extracted All Metadata');
    }
    currentTrackPathBeingExtracted.value = '';

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

  static List<String> splitBySeparators(String? string, Iterable<String> separators, String fallback, Iterable<String> blacklist) {
    final List<String> finalStrings = <String>[];
    final List<String> pre = string?.trimAll().multiSplit(separators, blacklist) ?? [fallback];
    pre.loop((e, index) {
      finalStrings.addIf(e != '', e.trimAll());
    });
    return finalStrings;
  }

  /// [addArtistsFromTitle] extracts feat artists.
  /// Defaults to [settings.extractFeatArtistFromTitle]
  static List<String> splitArtist({
    required String? title,
    required String? originalArtist,
    required ArtistsSplitConfig config,
  }) {
    final allArtists = <String>[];

    final artistsOrg = splitBySeparators(
      originalArtist,
      config.separators,
      UnknownTags.ARTIST,
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

  static List<String> splitGenre(
    String? originalGenre, {
    required GenresSplitConfig config,
  }) {
    return splitBySeparators(
      originalGenre,
      config.separators,
      UnknownTags.GENRE,
      config.separatorsBlacklist,
    );
  }

  /// (title, artist)
  static (String, String) getTitleAndArtistFromFilename(String filename) {
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
    final artist = titleAndArtist.length >= 2 ? titleAndArtist[0].trimAll() : UnknownTags.ARTIST;

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
      'directoriesToExclude': settings.directoriesToExclude.toList(),
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
    if (_availableDirs != null && !forceReCheck && _latestRespectNoMedia == settings.respectNoMedia.value) {
      return await _availableDirs!.future;
    } else {
      _availableDirs = null; // for when forceReCheck enabled.
      _availableDirs = Completer<Map<Directory, bool>>();

      _latestRespectNoMedia = settings.respectNoMedia.value;

      final parameters = {
        'directoriesToScan': settings.directoriesToScan.toList(),
        'respectNoMedia': settings.respectNoMedia.value,
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
        if (oldDeletedFile.existsSync()) {
          artworksInStorage.value--;
          artworksSizeInStorage.value -= oldDeletedFile.sizeInBytesSync();
        }
      }
      if (newImagePath != null) {
        artworksInStorage.value++;
        artworksSizeInStorage.value += File(newImagePath).sizeInBytesSync();
      }

      return;
    }

    final stats = await updateImageSizeInStorageIsolate.thready({
      "dirPath": AppDirs.ARTWORKS,
      "token": RootIsolateToken.instance,
    });
    artworksInStorage.value = stats.$1;
    artworksSizeInStorage.value = stats.$2;
  }

  static (int, int) updateImageSizeInStorageIsolate(Map p) {
    final dirPath = p["dirPath"] as String;
    final newImagePath = p["newImagePath"] as String?;
    final oldDeletedFile = p["oldDeletedFile"] as File?;
    final token = p["token"] as RootIsolateToken;
    BackgroundIsolateBinaryMessenger.ensureInitialized(token);

    int initialCount = p["initialCount"] as int? ?? 0;
    int initialSize = p["initialSize"] as int? ?? 0;

    if (newImagePath != null || oldDeletedFile != null) {
      if (oldDeletedFile != null) {
        if (oldDeletedFile.existsSync()) {
          initialCount--;
          initialSize -= oldDeletedFile.sizeInBytesSync();
        }
      }
      if (newImagePath != null) {
        initialCount++;
        initialSize += File(newImagePath).sizeInBytesSync();
      }
    } else {
      final dir = Directory(dirPath);

      for (final f in dir.listSync()) {
        if (f is File) {
          initialCount++;
          initialSize += f.sizeInBytesSync();
        }
      }
    }

    return (initialCount, initialSize);
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
        if (await oldDeletedFile.exists()) {
          videosInStorage.value--;
          videosInStorage.value -= await oldDeletedFile.sizeInBytes();
        }
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

enum _ExtractionErrorMessage {
  sizeLimit,
  durationLimit,
  timeout,
  failed,
  success,
}
