// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:faudiotagger/faudiotagger.dart';
import 'package:faudiotagger/models/faudiomodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path/path.dart' as p;
import 'package:system_info2/system_info2.dart';

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
import 'package:namida/core/functions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';

class Indexer {
  static Indexer get inst => _instance;
  static final Indexer _instance = Indexer._internal();
  Indexer._internal();

  bool get _defaultUseMediaStore => settings.useMediaStore.value;
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

  var allFolderCovers = <String, String>{}; // {directoryPath, imagePath}

  /// Used to prevent duplicated track (by filename).
  final Map<String, bool> _currentFileNamesMap = {};

  static final _faudiotagger = FAudioTagger();
  late final _audioQuery = OnAudioQuery();

  List<Track> get recentlyAddedTracks {
    final alltracks = List<Track>.from(tracksInfoList);
    alltracks.sortByReverseAlt((e) => e.dateModified, (e) => e.dateAdded);
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
    required String imagePath,
    bool checkFileFirst = true,
    required bool compressed,
    int? size,
  }) async {
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
          file = await extractTracksArtworks(
            [info.$1.path],
            albumIdendifiers: {info.$1.path: info.$1.albumIdentifier},
          ).then((value) => value.firstOrNull);
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

  Future<void> prepareTracksFile() async {
    _fetchMediaStoreTracks(); // to fill ids map

    /// Only awaits if the track file exists, otherwise it will get into normally and start indexing.
    if (await File(AppPaths.TRACKS).existsAndValid()) {
      await readTrackData();
      _afterIndexing();
    }

    /// doesnt exists
    else {
      await File(AppPaths.TRACKS).create();
      refreshLibraryAndCheckForDiff(forceReIndex: true, useMediaStore: _defaultUseMediaStore);
    }
  }

  Future<void> refreshLibraryAndCheckForDiff({
    Set<String>? currentFiles,
    bool forceReIndex = false,
    bool? useMediaStore,
    bool allowDeletion = true,
    bool showFinishedSnackbar = true,
  }) async {
    if (isIndexing.value) return snackyy(title: lang.NOTE, message: lang.ANOTHER_PROCESS_IS_RUNNING);

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

    sortMediaTracksSubLists(MediaType.values);
    _sortAll();
  }

  void sortMediaTracksSubLists(List<MediaType> medias) {
    medias.loop((e, index) {
      final sorters = SearchSortController.inst.getMediaTracksSortingComparables(e);
      void sortPls(Iterable<List<Track>> trs, MediaType type) {
        final reverse = settings.mediaItemsTrackSortingReverse[type] ?? false;
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
        case MediaType.genre:
          sortPls(mainMapGenres.value.values, MediaType.genre);
          mainMapGenres.refresh();
          break;
        case MediaType.folder:
          sortPls(mainMapFolders.values, MediaType.folder);
          mainMapFolders.refresh();
          break;
        default:
          null;
      }
    });
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

    final albumSorters = SearchSortController.inst.getMediaTracksSortingComparables(MediaType.album);
    final artistSorters = SearchSortController.inst.getMediaTracksSortingComparables(MediaType.artist);
    final genreSorters = SearchSortController.inst.getMediaTracksSortingComparables(MediaType.genre);
    final folderSorters = SearchSortController.inst.getMediaTracksSortingComparables(MediaType.folder);
    addedAlbums
      ..removeDuplicates()
      ..loop((e, index) {
        mainMapAlbums.value[e]?.sortByAlts(albumSorters);
      });
    addedArtists
      ..removeDuplicates()
      ..loop((e, index) {
        mainMapArtists.value[e]?.sortByAlts(artistSorters);
      });
    addedGenres
      ..removeDuplicates()
      ..loop((e, index) {
        mainMapGenres.value[e]?.sortByAlts(genreSorters);
      });
    addedFolders
      ..removeDuplicates()
      ..loop((e, index) {
        mainMapFolders[e]?.sortByAlts(folderSorters);
      });

    _sortAll();
  }

  Future<(TrackExtended?, Uint8List?)> _extracty({
    required String trackPath,
    required void Function(String err) onError,
    FAudioModel? faudiomodelSent,
    Uint8List? artworkSent,
    int minDur = 0,
    int minSize = 0,
    void Function()? onMinDurTrigger,
    void Function()? onMinSizeTrigger,
    required bool tryExtractingFromFilename,
  }) async {
    // -- most methods dont throw, except for timeout
    try {
      const timeoutDuration = Duration(seconds: 8);

      // -- returns null early depending on size [byte] or duration [seconds]
      FileStat? fileStat;
      try {
        fileStat = File(trackPath).statSync();
        if (minSize > 0 && fileStat.size < minSize) {
          if (onMinSizeTrigger != null) onMinSizeTrigger();
          return (null, null);
        }
      } catch (_) {}

      late TrackExtended finalTrackExtended;

      FAudioModel? trackInfo = faudiomodelSent;
      Uint8List? artwork = artworkSent;

      // if one of them wasnt sent, we extract using tagger
      if (trackInfo == null || artwork == null) {
        try {
          final infoAndArtwork = await _faudiotagger.readAllData(path: trackPath, onError: onError).timeout(timeoutDuration);
          trackInfo ??= infoAndArtwork;
          artwork ??= infoAndArtwork?.firstArtwork;
        } catch (e) {
          printo(e, isError: true);
        }
      }

      if (trackInfo == null && !tryExtractingFromFilename) {
        return (null, artwork);
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
        dateAdded: fileStat?.creationDate.millisecondsSinceEpoch ?? 0,
        dateModified: fileStat?.modified.millisecondsSinceEpoch ?? 0,
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
        if (durationInSeconds == 0) {
          final ap = AudioPlayer();
          final dur = await ap.setFilePath(trackPath).timeout(timeoutDuration);
          durationInSeconds = dur?.inSeconds ?? 0;
          ap.dispose();
        }
        if (minDur != 0 && durationInSeconds != 0 && durationInSeconds < minDur) {
          if (onMinDurTrigger != null) onMinDurTrigger();
          return (null, artwork);
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

        // -- Split Moods (using same genre splitters)
        final moods = splitGenre(
          trackInfo.mood,
          config: GenresSplitConfig.settings(),
        );

        String? trimOrNull(String? value) => value == null ? value : value.trimAll();
        String? nullifyEmpty(String? value) => value == '' ? null : value;
        String? doMagic(String? value) => nullifyEmpty(trimOrNull(value));

        finalTrackExtended = initialTrack.copyWith(
          title: doMagic(trackInfo.title),
          originalArtist: doMagic(trackInfo.artist),
          artistsList: artists,
          album: doMagic(trackInfo.album),
          albumArtist: doMagic(trackInfo.albumArtist),
          originalGenre: doMagic(trackInfo.genre),
          genresList: genres,
          originalMood: doMagic(trackInfo.mood),
          moodList: moods,
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

        // extractTracksArtworks(
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
        // extractTracksArtworks(
        //   trackPath,
        //   forceReExtract: deleteOldArtwork,
        //   extractColor: extractColor,
        //   albumIdendifier: finalTrackExtended.albumIdentifier,
        // );
      }

      return (finalTrackExtended, artwork);
    } catch (e) {
      onError(e.toString());
      return (null, null);
    }
  }

  Future<List<(String, TrackExtended?, Uint8List?)>> _extractySomeTracks({
    required List<String> paths,
    Map<String, FAudioModel?> audiomodels = const {},
    Map<String, Uint8List?> artworks = const {},
    int minDur = 0,
    int minSize = 0,
    void Function()? onMinDurTrigger,
    void Function()? onMinSizeTrigger,
    required bool tryExtractingFromFilename,
  }) async {
    final all = <(String, TrackExtended?, Uint8List?)>[];
    if (paths.isNotEmpty) {
      final logsFile = File(AppPaths.LOGS_TAGGER);
      await logsFile.create();
      final sink = logsFile.openWrite(mode: FileMode.append);

      final completer = Completer<void>();
      int extractedNumber = 0;
      for (final trackPath in paths) {
        _extracty(
          trackPath: trackPath,
          onError: (err) => sink.write('Error Extracting ["$trackPath"]: $err\n\n\n'),
          faudiomodelSent: audiomodels[trackPath],
          artworkSent: artworks[trackPath],
          tryExtractingFromFilename: tryExtractingFromFilename,
          minDur: minDur,
          minSize: minSize,
          onMinDurTrigger: onMinDurTrigger,
          onMinSizeTrigger: onMinSizeTrigger,
        ).then((r) {
          currentTrackPathBeingExtracted.value = trackPath;
          all.add((trackPath, r.$1, r.$2));
          extractedNumber++;
          if (extractedNumber == paths.length) completer.completeIfWasnt();
        });
      }
      await completer.future;
      await sink.flush();
      await sink.close();
    }
    return all;
  }

  /// - Extracts Metadata for given track path
  /// - Nullable only if [minDur] or [minSize] is used, or if extraction fails.
  Future<Map<String, TrackExtended>> extractTracksInfo({
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
    final success = <String, TrackExtended>{};
    final failed = <String>[];
    final artworks = <String, Uint8List?>{};
    final results = await _extractySomeTracks(
      paths: tracksPath,
      tryExtractingFromFilename: tryExtractingFromFilename,
      minDur: minDur,
      minSize: minSize,
      onMinDurTrigger: onMinDurTrigger,
      onMinSizeTrigger: onMinSizeTrigger,
    );
    for (final r in results) {
      final trext = r.$2;
      if (trext != null && trext.duration >= 0) {
        success[r.$1] = trext;
      } else {
        failed.add(r.$1);
      }
      artworks[r.$1] = r.$3;
    }

    final logsFile = File(AppPaths.LOGS_TAGGER);
    await logsFile.create();
    final sink = logsFile.openWrite(mode: FileMode.append);
    final ffmpegModel = <String, FAudioModel?>{};
    for (final f in failed) {
      final r = await _faudiotagger.extractMetadata(
        trackPath: f,
        forceExtractByFFmpeg: true,
        onError: (err) => sink.write("Error Extracting [$f]: $err\n\n\n"),
        onArtworkError: (err) => sink.write("Error Extracting Artwork [$f]: $err\n\n\n"),
      );
      ffmpegModel[f] = r.$1;
      artworks[f] = r.$2;
    }

    await sink.flush();
    await sink.close();
    final resultsFFMPEG = await _extractySomeTracks(
      paths: failed,
      audiomodels: ffmpegModel,
      artworks: artworks,
      tryExtractingFromFilename: tryExtractingFromFilename,
      minDur: minDur,
      minSize: minSize,
      onMinDurTrigger: onMinDurTrigger,
      onMinSizeTrigger: onMinSizeTrigger,
    );
    for (final r in resultsFFMPEG) {
      if (r.$2 != null) {
        success[r.$1] = r.$2!;
      }
      if (r.$3 != null) {
        artworks[r.$1] = r.$3;
      }
    }

    _addTracksToLists(success.values, checkForDuplicates);

    extractTracksArtworks(
      tracksPath,
      artworks: artworks,
      forceReExtract: deleteOldArtwork,
      extractColor: extractColor,
      albumIdendifiers: {for (final r in success.entries) r.key: r.value.albumIdentifier},
    );
    return success;
  }

  void _addTracksToLists(Iterable<TrackExtended> tracks, bool checkForDuplicates) {
    for (final trext in tracks) {
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
  }

  /// - Extracts artwork from [bytes] or [pathOfAudio] and save to file.
  /// - Path is needed bothways for making the file name.
  /// - Using path for extracting will call [_faudiotagger.readArtwork] so it will be slower.
  /// - `final art = bytes ?? await _faudiotagger.readArtwork(path: pathOfAudio);`
  /// - Sending [artworkPath] that points towards an image file will just copy it to [AppDirs.ARTWORKS]
  /// - Returns the Artwork Files created.
  Future<List<File?>> extractTracksArtworks(
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
    final resAndStats = await extractTracksArtworksIsolate.thready(parameters);
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

  static Future<(List<(String, File?)>, (int, int))> extractTracksArtworksIsolate(Map parameters) async {
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
          initialSize -= oldDeletedFile.fileSizeSync() ?? 0;
        }
      }
      if (newImagePath != null) {
        initialCount++;
        initialSize += File(newImagePath).fileSizeSync() ?? 0;
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
        final tr = await extractTracksInfo(
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
    AudioService.evictArtworkCache();

    for (final e in tracksMap.entries) {
      final ot = e.key;
      final nt = e.value.toTrack();
      oldTracks.add(ot);
      newTracks.add(nt);
      allTracksMappedByPath[ot] = e.value;
      _currentFileNamesMap.remove(ot.filename);
      _currentFileNamesMap[nt.filename] = true;

      if (newArtworkPath != '') {
        await extractTracksArtworks(
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

  void _clearLists() {
    tracksInfoList.clear();
    allTracksMappedByPath.clear();
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
      _currentFileNamesMap.clear();
      _addTracksToLists(trs.map((e) => e.$1), false);
    } else {
      currentTrackPathBeingExtracted.value = '';
      final chunkExtractList = <String>[];
      final freeMemory = SysInfo.getFreePhysicalMemory();
      final chunkSize = (freeMemory ~/ 6).clamp(8, 156);
      if (audioFiles.isNotEmpty) {
        // -- Extracting All Metadata
        for (final trackPath in audioFiles) {
          /// skip duplicated tracks according to filename
          if (prevDuplicated) {
            if (_currentFileNamesMap.keyExists(trackPath.getFilename)) {
              duplicatedTracksLength.value++;
              continue;
            }
          }

          if (chunkExtractList.isNotEmpty && chunkExtractList.length % chunkSize == 0) {
            await extractTracksInfo(
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
        // -- if there were any items left (length < chunkSize)
        await extractTracksInfo(
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
    TrackTileManager.onTrackItemPropChange();
    await File(AppPaths.TRACKS).writeAsJson(tracksInfoList.map((key) => allTracksMappedByPath[key]?.toJson()).toList());
  }

  Future<void> updateTrackDuration(Track track, Duration? dur) async {
    final durInSeconds = dur?.inSeconds ?? 0;
    if (durInSeconds > 0 && track.duration != durInSeconds) {
      track.duration = durInSeconds;
      await _saveTrackFileToStorage();
    }
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
    TrackTileManager.onTrackItemPropChange();
    await File(AppPaths.TRACKS_STATS).writeAsJson(trackStatsMap.values.map((e) => e.toJson()).toList());
  }

  Future<void> readTrackData() async {
    // reading stats file containing track rating etc.
    final statsResult = await _readTracksStatsCompute.thready(AppPaths.TRACKS_STATS);
    trackStatsMap.value = statsResult;

    tracksInfoList.clear(); // clearing for cases which refreshing library is required (like after changing separators)

    /// Reading actual track file.
    final splitconfig = _SplitArtistGenreConfig(
      path: AppPaths.TRACKS,
      artistsConfig: ArtistsSplitConfig.settings(),
      genresConfig: GenresSplitConfig.settings(),
    );
    final tracksResult = await _readTracksFileCompute.thready(splitconfig);
    allTracksMappedByPath.value = tracksResult;
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
  Future<Set<String>> getAudioFiles({bool strictNoMedia = true}) async {
    tracksExcludedByNoMedia.value = 0;
    final allAvailableDirectories = await getAvailableDirectories(forceReCheck: true, strictNoMedia: strictNoMedia);

    final parameters = {
      'allAvailableDirectories': allAvailableDirectories,
      'directoriesToExclude': settings.directoriesToExclude.toList(),
      'extensions': kAudioFileExtensions,
      'imageExtensions': kImageFilesExtensions,
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

    _lastAvailableDirectories = null; // for when forceReCheck enabled.
    _lastAvailableDirectories = Completer<Map<Directory, bool>>();
    final parameters = {
      'directoriesToScan': settings.directoriesToScan.toList(),
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

    for (final dirPath in directoriesToScan) {
      final directory = Directory(dirPath);

      if (directory.existsSync()) {
        allAvailableDirectories[directory] = false;
        for (final file in directory.listSyncSafe(recursive: true, followLinks: true)) {
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

  Future<List<(TrackExtended, int)>> _fetchMediaStoreTracks() async {
    final allMusic = await _audioQuery.querySongs();
    // -- folders selected will be ignored when [settings.useMediaStore.value] is enabled.
    allMusic.retainWhere(
        (element) => settings.directoriesToExclude.every((dir) => !element.data.startsWith(dir)) /* && settings.directoriesToScan.any((dir) => element.data.startsWith(dir)) */);
    final tracks = <(TrackExtended, int)>[];
    allMusic.loop((e, _) {
      final map = e.getMap;
      final artist = e.artist;
      final artists = artist == null
          ? <String>[]
          : Indexer.splitArtist(
              title: e.title,
              originalArtist: artist,
              config: ArtistsSplitConfig.settings(),
            );
      final genre = e.genre;
      final genres = genre == null
          ? <String>[]
          : Indexer.splitGenre(
              genre,
              config: GenresSplitConfig.settings(),
            );
      final mood = map['mood'];
      final moods = mood == null
          ? <String>[]
          : Indexer.splitGenre(
              mood,
              config: GenresSplitConfig.settings(),
            );
      final bitrate = map['bitrate'] as int?;
      final disc = map['disc_number'] as int?;
      final year = (map['year'] as String?).getIntValue();
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
        duration: e.duration == null ? 0 : e.duration! ~/ 1000,
        year: year ?? 0,
        size: e.size,
        dateAdded: e.dateAdded ?? 0,
        dateModified: e.dateModified ?? 0,
        path: e.data,
        comment: '',
        bitrate: bitrate == null ? 0 : bitrate ~/ 1000,
        sampleRate: 0,
        format: '',
        channels: '',
        discNo: disc ?? 0,
        language: '',
        lyrics: '',
      );
      tracks.add((trext, e.id));
      _backupMediaStoreIDS[trext.pathToImage] = (trext.toTrack(), e.id);
    });
    return tracks;
  }

  Future<void> updateImageSizeInStorage({String? newImagePath, File? oldDeletedFile}) async {
    if (newImagePath != null || oldDeletedFile != null) {
      if (oldDeletedFile != null) {
        if (oldDeletedFile.existsSync()) {
          artworksInStorage.value--;
          artworksSizeInStorage.value -= oldDeletedFile.fileSizeSync() ?? 0;
        }
      }
      if (newImagePath != null) {
        artworksInStorage.value++;
        artworksSizeInStorage.value += File(newImagePath).fileSizeSync() ?? 0;
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
          initialSize -= oldDeletedFile.fileSizeSync() ?? 0;
        }
      }
      if (newImagePath != null) {
        initialCount++;
        initialSize += File(newImagePath).fileSizeSync() ?? 0;
      }
    } else {
      final dir = Directory(dirPath);

      for (final f in dir.listSyncSafe()) {
        if (f is File) {
          initialCount++;
          initialSize += f.fileSizeSync() ?? 0;
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

  Future<void> updateVideosSizeInStorage() async {
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
      for (final v in videosToDelete) {
        final deleted = await File(v.path).tryDeleting();
        if (deleted) {
          videosInStorage.value--;
          videosSizeInStorage.value -= v.sizeInBytes;
        }
      }
    } else {
      await Directory(AppDirs.VIDEOS_CACHE).delete(recursive: true);
      await Directory(AppDirs.VIDEOS_CACHE).create();
      videosInStorage.value = 0;
      videosSizeInStorage.value = 0;
    }
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
