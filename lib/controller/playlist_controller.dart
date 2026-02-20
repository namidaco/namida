// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:namico_db_wrapper/namico_db_wrapper.dart';
import 'package:path/path.dart' as p;
import 'package:playlist_manager/playlist_manager.dart';

import 'package:namida/class/http_manager.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/generators_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/download_task_base.dart';

typedef LocalPlaylist = GeneralPlaylist<TrackWithDate, SortType>;

class PlaylistController extends PlaylistManager<TrackWithDate, Track, SortType> {
  static PlaylistController get inst => _instance;
  static final PlaylistController _instance = PlaylistController._internal();
  PlaylistController._internal();

  @override
  RegExp get cleanupFilenameRegex => DownloadTaskFilename.cleanupFilenameRegex;

  @override
  Track identifyBy(TrackWithDate item) => item.track;

  void addNewPlaylist(
    String name, {
    List<Track> tracks = const <Track>[],
    int? creationDate,
    String comment = '',
    List<String> moods = const [],
    String? m3uPath,
    PlaylistAddDuplicateAction? actionIfAlreadyExists,
  }) async {
    super.addNewPlaylistRaw(
      name,
      tracks: tracks,
      convertItem: (e, dateAdded, playlistID) => TrackWithDate(
        dateAdded: dateAdded,
        track: e,
      ),
      creationDate: creationDate,
      comment: comment,
      moods: moods,
      m3uPath: m3uPath,
      actionIfAlreadyExists: () => actionIfAlreadyExists ?? NamidaOnTaps.inst.showDuplicatedDialogAction(PlaylistAddDuplicateAction.valuesForAdd),
    );
  }

  void addTracksToPlaylist(
    LocalPlaylist playlist,
    List<Track> tracks, {
    TrackSource? source,
    List<PlaylistAddDuplicateAction> duplicationActions = PlaylistAddDuplicateAction.valuesForAdd,
  }) async {
    final originalModifyDate = playlist.modifiedDate;
    final oldTracksList = List<TrackWithDate>.from(playlist.tracks); // for undo

    final addedTracksLength = await super.addTracksToPlaylistRaw(
      playlist,
      tracks,
      () => NamidaOnTaps.inst.showDuplicatedDialogAction(duplicationActions),
      (e, dateAdded) {
        return TrackWithDate(
          dateAdded: dateAdded,
          track: e,
          source: source,
        );
      },
    );

    if (addedTracksLength == null) return;

    snackyy(
      message: "${lang.ADDED} ${addedTracksLength.displayTrackKeyword}",
      button: addedTracksLength > 0
          ? (
              lang.UNDO,
              () async => await updatePropertyInPlaylist(playlist.name, tracks: oldTracksList, modifiedDate: originalModifyDate),
            )
          : null,
    );
  }

  bool favouriteButtonOnPressed(Track track, {bool refreshNotification = true}) {
    final res = super.toggleTrackFavourite(
      TrackWithDate(dateAdded: currentTimeMS, track: track),
    );
    if (refreshNotification) {
      final currentItem = Player.inst.currentItem.value;
      if (currentItem is Selectable && currentItem.track == track) {
        Player.inst.refreshNotification();
      }
    }
    return res;
  }

  Future<void> replaceTracksDirectory(String oldDir, String newDir, {Iterable<String>? forThesePathsOnly, bool ensureNewFileExists = false}) async {
    String getNewPath(String old) => old.replaceFirst(oldDir, newDir);
    final pathsOnlySet = forThesePathsOnly?.toSet();
    final existenceCache = <String, bool>{};
    await replaceTheseTracksInPlaylists(
      (e) {
        final tr = e.track;
        return replaceFunctionForUpdatedPaths(
          tr,
          oldDir,
          newDir,
          pathsOnlySet,
          ensureNewFileExists,
          existenceCache,
        );
      },
      (old) => TrackWithDate(
        dateAdded: old.dateAdded,
        track: Track.fromTypeParameter(old.track.runtimeType, getNewPath(old.track.path)),
        source: old.source,
      ),
    );
  }

  Future<void> replaceTrackInAllPlaylists(Track oldTrack, Track newTrack) async {
    await replaceTheseTracksInPlaylists(
      (e) => e.track == oldTrack,
      (old) => TrackWithDate(
        dateAdded: old.dateAdded,
        track: newTrack,
        source: old.source,
      ),
    );
  }

  Future<void> replaceTrackInAllPlaylistsBulk(Map<Track, Track> oldNewTrack) async {
    final fnList = <MapEntry<bool Function(TrackWithDate e), TrackWithDate Function(TrackWithDate old)>>[];
    for (final entry in oldNewTrack.entries) {
      fnList.add(
        MapEntry(
          (e) => e.track == entry.key,
          (old) => TrackWithDate(
            dateAdded: old.dateAdded,
            track: entry.value,
            source: old.source,
          ),
        ),
      );
    }
    await replaceTheseTracksInPlaylistsBulk(fnList);
  }

  @override
  Future<bool> renamePlaylist(String playlistName, String newName) async {
    final didRename = await super.renamePlaylist(playlistName, newName);
    if (didRename) _popPageIfCurrent(() => playlistName);
    return didRename;
  }

  /// Returns number of generated tracks.
  int generateRandomPlaylist() {
    final rt = NamidaGenerator.inst.getRandomTracks();
    if (rt.isEmpty) return 0;

    final l = playlistsMap.keys.where((name) => name.startsWith(k_PLAYLIST_NAME_AUTO_GENERATED)).length;
    addNewPlaylist('$k_PLAYLIST_NAME_AUTO_GENERATED ${l + 1}', tracks: rt.toList());

    return rt.length;
  }

  Future<void> exportPlaylistToM3UFile(LocalPlaylist playlist, String path) async {
    await _saveM3UPlaylistToFile.thready({
      'path': path,
      'tracks': playlist.tracks,
      'infoMap': _pathsM3ULookup,
      'artworkUrl': _artworkUrlForM3uInfoMap[playlist.m3uPath ?? ''],
    });
  }

  Future<void> prepareAllPlaylists() async {
    await super.prepareAllPlaylistsFile();
    // -- preparing all playlist is awaited, for cases where
    // -- similar name exists, so m3u overrides it
    // -- this can produce in an outdated playlist version in cache
    // -- which will be seen if the m3u file got deleted/renamed
    await prepareM3UPlaylists();
    if (!_m3uPlaylistsCompleter.isCompleted) _m3uPlaylistsCompleter.complete(true);
  }

  Future<List<Track>> readM3UFiles(Set<String> filesPaths) async {
    if (filesPaths.isEmpty) return [];
    final params = _ParseM3UPlaylistFilesParams(
      allm3uPaths: filesPaths,
      tracksDbInfo: AppPaths.TRACKS_DB_INFO,
      backupDirPath: AppDirs.M3UBackup,
    );
    final resBoth = await _parseM3UPlaylistFiles.thready(params);
    final infoMap = resBoth.infoMap;
    if (_pathsM3ULookup.isEmpty) {
      _pathsM3ULookup = infoMap;
    } else {
      _pathsM3ULookup.addAll(infoMap);
    }

    final paths = resBoth.paths;
    final listy = <Track>[];
    for (final p in paths.entries) {
      listy.addAll(p.value.$3);
      _ensureM3UArtUrlObtained(p.key, p.value.$1, p.value.$2);
    }

    return listy;
  }

  void removeM3UPlaylists([bool Function(String name)? additionalTest]) {
    final namesToRemove = <String>[];
    for (final e in playlistsMap.value.entries) {
      final isM3U = e.value.m3uPath?.isNotEmpty == true;
      if (isM3U) {
        if (additionalTest == null || additionalTest(e.key)) {
          namesToRemove.add(e.key);
        }
      }
    }
    if (namesToRemove.isNotEmpty) {
      removePlaylists(namesToRemove);
    }
  }

  final _m3uPlaylistsCompleter = Completer<bool>();
  Future<bool> get waitForM3UPlaylistsLoad => _m3uPlaylistsCompleter.future;

  bool _addedM3UPlaylists = false;
  Future<int?> prepareM3UPlaylists({Set<String> forPaths = const {}, bool addAsM3U = true}) async {
    if (forPaths.isEmpty && addAsM3U && !settings.enableM3USyncStartup.value) {
      if (_addedM3UPlaylists) removeM3UPlaylists();

      _addedM3UPlaylists = false;
      return null;
    }

    if (addAsM3U) _addedM3UPlaylists = true;

    try {
      var allm3uPaths = <String>{};
      if (forPaths.isEmpty) {
        final dirsFilterer = DirsFileFilter(
          directoriesToExclude: null,
          extensions: NamidaFileExtensionsWrapper.m3u,
          strictNoMedia: false,
        );
        final result = await dirsFilterer.filter();
        allm3uPaths = result.allPaths;
      } else {
        allm3uPaths.addAll(forPaths);
      }

      _ParseM3UPlaylistFilesResult? resBoth;
      if (allm3uPaths.isNotEmpty) {
        final params = _ParseM3UPlaylistFilesParams(
          allm3uPaths: allm3uPaths,
          tracksDbInfo: AppPaths.TRACKS_DB_INFO,
          backupDirPath: AppDirs.M3UBackup,
        );
        resBoth = await _parseM3UPlaylistFiles.thready(params);
      }
      final paths = resBoth?.paths ?? {};
      final infoMap = resBoth?.infoMap ?? {};

      // -- removing old m3u playlists (only if preparing all)
      if (forPaths.isEmpty) {
        removeM3UPlaylists((name) => !paths.containsKey(name));
      }

      for (final e in paths.entries) {
        try {
          final plName = e.key;
          final m3uPath = e.value.$1;
          final trs = e.value.$3;
          final creationDate = (await File(m3uPath).stat()).creationDate.millisecondsSinceEpoch;
          final plAlreadyExisting = playlistsMap.value[plName];
          if (plAlreadyExisting != null) {
            this.updatePropertyInPlaylist(
              plName,
              tracksRaw: trs,
              convertItem: (e, dateAdded) => TrackWithDate(dateAdded: dateAdded, track: e),
              m3uPath: addAsM3U ? m3uPath : null,
              creationDate: creationDate,
            );
          } else {
            this.addNewPlaylist(
              plName,
              tracks: trs,
              m3uPath: addAsM3U ? m3uPath : null,
              creationDate: creationDate,
              actionIfAlreadyExists: PlaylistAddDuplicateAction.deleteAndCreateNewPlaylist, // we already check here tho
            );
          }

          _ensureM3UArtUrlObtained(plName, e.value.$1, e.value.$2);
        } catch (_) {}
      }

      if (_pathsM3ULookup.isEmpty) {
        _pathsM3ULookup = infoMap;
      } else {
        _pathsM3ULookup.addAll(infoMap);
      }

      return paths.length;
    } catch (_) {}
    return null;
  }

  void _ensureM3UArtUrlObtained(String playlistName, String m3uPath, String? artUrl) async {
    if (artUrl == null) return;
    _artworkUrlForM3uInfoMap[m3uPath] = artUrl;

    final artworkThatAlrExists = getArtworkFileForPlaylist(playlistName);
    if (await artworkThatAlrExists.exists()) return;

    HttpMultiRequestManager? httpManager;
    try {
      if (artUrl.startsWith('http')) {
        httpManager ??= await HttpMultiRequestManager.create();
        await httpManager.execute(
          (requester) async {
            try {
              final response = await requester.getBytes(artUrl);
              final responseBytes = response.body;
              if (responseBytes.isNotEmpty) {
                await setArtworkForPlaylist(
                  playlistName,
                  artworkFile: null,
                  artworkBytes: responseBytes,
                );
              }
            } catch (_) {}
          },
        );
      } else {
        File? imageFileToCopy;
        if (await File(artUrl).exists()) {
          imageFileToCopy = File(artUrl);
        } else {
          final fileParentDirectory = File(m3uPath).parent.path;
          final pathNormalized = p.relative(p.join(fileParentDirectory, p.normalize(artUrl)));
          if (await File(pathNormalized).exists()) {
            imageFileToCopy = File(pathNormalized);
          }
        }
        if (imageFileToCopy != null) {
          await setArtworkForPlaylist(
            playlistName,
            artworkFile: imageFileToCopy,
            artworkBytes: null,
          );
        }
      }
    } catch (_) {}

    httpManager?.closeClients();
  }

  /// saves each track m3u info for writing back
  var _pathsM3ULookup = <String, String?>{}; // {trackPath: EXTINFO}

  final _artworkUrlForM3uInfoMap = <String, String?>{}; // {m3uPath: artUrl}

  static Future<_ParseM3UPlaylistFilesResult> _parseM3UPlaylistFiles(_ParseM3UPlaylistFilesParams params) async {
    final allm3uPaths = params.allm3uPaths;

    final backupDirPath = params.backupDirPath;

    DBWrapperSync? tracksDBManager;
    final libraryTracksPaths = <String>[];

    Future<void> loadTracksDb() async {
      try {
        NamicoDBWrapper.initialize();
        tracksDBManager = await DBWrapper.openFromInfoSyncTry(
          fileInfo: params.tracksDbInfo,
          config: DBConfig(
            createIfNotExist: true,
            autoDisposeTimerDuration: null, // we close manually
          ),
        );
        tracksDBManager?.loadAllKeys(libraryTracksPaths.add);
      } finally {
        tracksDBManager?.close();
      }
    }

    bool pathExists(String path) => File(path).existsSync();

    final pathSep = Platform.pathSeparator;
    late final albumartUrlRegex = RegExp(r'(?<=#EXTALBUMARTURL:\s*).+');
    final pathSepRegex = RegExp(r'[\\/]');

    final all = <String, (String, String?, List<Track>)>{};
    final infoMap = <String, String?>{};
    for (final path in allm3uPaths) {
      final file = File(path);
      final filename = file.path.getFilenameWOExt;
      final fileParentDirectory = file.path.getDirectoryPath;
      final fullTracks = <Track>[];
      String? latestInfo;
      String? artUrl;
      for (String line in file.readAsLinesSync()) {
        if (line.startsWith("#")) {
          if (artUrl == null && line.startsWith('#EXTALBUMARTURL')) {
            artUrl = albumartUrlRegex.firstMatch(line)?[0];
          }

          latestInfo = line; // could be a comment, would get overriden by the next #EXTINF anyways
        } else if (line.isNotEmpty) {
          if (line.startsWith('primary/')) {
            line = line.replaceFirst('primary/', '');
          }
          line = line.replaceAll(pathSepRegex, pathSep);

          String fullPath = line; // maybe is absolute path
          bool fileExists = false;

          if (pathExists(fullPath)) fileExists = true;

          if (!fileExists) {
            fullPath = p.relative(p.join(fileParentDirectory, p.normalize(fullPath))); // maybe was relative
            if (pathExists(fullPath)) fileExists = true;
          }

          if (!fileExists) {
            if (tracksDBManager == null) await loadTracksDb();
            final normalizedPath = p.normalize(line);
            final maybePath = libraryTracksPaths.firstWhereEff((path) => path.endsWith(normalizedPath)); // no idea, trying to get from library
            if (maybePath != null) {
              fullPath = maybePath;
              // if (pathExists(fullPath)) fileExists = true; // no further checks
            }
          }
          if (Platform.isWindows) {
            if (fullPath.startsWith(pathSep)) {
              fullPath = fullPath.substring(1);
            }
          } else {
            if (!fullPath.startsWith(pathSep)) {
              fullPath = '$pathSep$fullPath';
            }
          }
          fullTracks.add(Track.orVideo(fullPath));
          infoMap[fullPath] = latestInfo;
          latestInfo = null; // resetting info between each line loop
        }
      }
      if (all[filename] == null) {
        all[filename] = (path, artUrl, fullTracks);
      } else {
        // -- filename already exists
        all[file.path.formatPath()] = (path, artUrl, fullTracks);
      }

      latestInfo = null; // resetting info between each file looping
    }

    // -- copying newly found m3u files as a backup
    for (final m3u in all.entries) {
      final backupFile = File("$backupDirPath${m3u.key}.m3u");
      if (!backupFile.existsSync()) {
        File(m3u.value.$1).copySync(backupFile.path);
      }
    }

    return _ParseM3UPlaylistFilesResult(
      paths: all,
      infoMap: infoMap,
    );
  }

  static Future<void> _saveM3UPlaylistToFile(Map params) async {
    final mainPath = params['path'] as String;
    final tracks = params['tracks'] as List<TrackWithDate>;
    final infoMap = params['infoMap'] as Map<String, String?>;
    final artworkUrl = params['artworkUrl'] as String?;
    final relative = params['relative'] as bool? ?? true;

    // String findCommonPath(List<TrackWithDate> tracks) {
    //   if (tracks.isEmpty) return '';

    //   // use absolute paths if playlist has network tracks
    //   if (tracks[0].track.isNetwork) return '';

    //   String res = "";
    //   final firstPath = tracks[0].track.path;
    //   for (int i = 0; i < firstPath.length; i++) {
    //     for (var twd in tracks) {
    //       var tr = twd.track;
    //       if (tr.isNetwork) return '';
    //       var s = tr.path;
    //       if (i >= s.length || firstPath[i] != s[i]) {
    //         return res;
    //       }
    //     }
    //     res += firstPath[i];
    //   }
    //   return res;
    // }

    final commonParent = relative ? p.dirname(mainPath) : '';
    final commonParentIsGood = commonParent.isNotEmpty && RegExp(r'[^\s]').hasMatch(commonParent); // ensure has any char

    final file = File(mainPath);

    file.deleteIfExistsSync();
    file.createSync(recursive: true);
    final sink = file.openWrite(mode: FileMode.writeOnlyAppend);
    sink.writeln('#EXTM3U');
    sink.writeln();
    if (artworkUrl != null) {
      sink.writeln('#EXTALBUMARTURL:$artworkUrl');
      sink.writeln();
    }
    if (commonParentIsGood) {
      sink.writeln('# resolved against `$commonParent`');
      sink.writeln('# this file should be put in `$commonParent` or a folder with similar structure');
      sink.writeln();
    }
    for (int i = 0; i < tracks.length; i++) {
      var trwd = tracks[i];
      final tr = trwd.track;
      final trext = tr.track.toTrackExt();
      final infoLine = infoMap[tr.path] ?? '#EXTINF:${trext.durationMS / 1000},${trext.originalArtist} - ${trext.title}';
      final pathLine = commonParentIsGood ? p.relative(tr.path, from: commonParent) : tr.path;
      sink.writeln(infoLine);
      sink.writeln(pathLine);
    }

    await sink.flush();
    await sink.close();
  }

  Future<bool> _requestM3USyncPermission() async {
    if (settings.enableM3USync.value) return true;

    final didRead = false.obs;

    await NamidaNavigator.inst.navigateDialog(
      onDisposing: () {
        didRead.close();
      },
      dialog: CustomBlurryDialog(
        actions: [
          const CancelButton(),
          const SizedBox(width: 8.0),
          ObxO(
            rx: didRead,
            builder: (context, didRead) => NamidaButton(
              enabled: didRead,
              text: lang.CONFIRM,
              onPressed: () {
                settings.save(enableM3USync: true);
                NamidaNavigator.inst.closeDialog();
              },
            ),
          ),
        ],
        title: lang.NOTE,
        child: Column(
          children: [
            Text(
              '${lang.ENABLE_M3U_SYNC}?\n\n${lang.ENABLE_M3U_SYNC_NOTE_1}\n\n${lang.ENABLE_M3U_SYNC_NOTE_2.replaceFirst('_PLAYLISTS_BACKUP_PATH_', AppDirs.M3UBackup)}\n\n${lang.WARNING.toUpperCase()}: ${lang.ENABLE_M3U_SYNC_SUBTITLE}',
              style: namida.textTheme.displayMedium,
            ),
            const SizedBox(height: 12.0),
            ListTileWithCheckMark(
              activeRx: didRead,
              icon: Broken.info_circle,
              title: lang.I_READ_AND_AGREE,
              onTap: didRead.toggle,
            ),
          ],
        ),
      ),
    );
    return settings.enableM3USync.value;
  }

  final _m3uWriteTimers = <String, Timer>{};

  @override
  FutureOr<void> onPlaylistTracksChanged(LocalPlaylist playlist) async {
    final m3uPath = playlist.m3uPath;
    if (m3uPath != null && await File(m3uPath).exists()) {
      final didAgree = await _requestM3USyncPermission();

      if (didAgree) {
        // -- using IOSink sometimes produces errors when succesively opened/closed
        // -- not ideal for cases where u constantly add/remove tracks
        // -- so we save with only 2 seconds limit.

        final writeTimer = _m3uWriteTimers[m3uPath];
        writeTimer?.cancel();
        _m3uWriteTimers[m3uPath] = Timer(const Duration(seconds: 2), () async {
          await _saveM3UPlaylistToFile.thready({
            'path': m3uPath,
            'tracks': playlist.tracks,
            'infoMap': _pathsM3ULookup,
            'artworkUrl': _artworkUrlForM3uInfoMap[playlist.m3uPath ?? ''],
          });
          _m3uWriteTimers[m3uPath]?.cancel();
          _m3uWriteTimers.remove(m3uPath);
        });
      }
    }
  }

  @override
  FutureOr<bool> canSavePlaylist(LocalPlaylist playlist) {
    final m3uPath = playlist.m3uPath;
    return m3uPath == null || m3uPath.isEmpty; // dont save m3u-based playlists;
  }

  @override
  void sortPlaylists() => SearchSortController.inst.sortMedia(MediaType.playlist);

  @override
  String get playlistsDirectory => AppDirs.PLAYLISTS;

  @override
  String get playlistsArtworksDirectory => AppDirs.PLAYLISTS_ARTWORKS;

  @override
  String get playlistsMetadataDirectory => AppDirs.PLAYLISTS_METADATA;

  @override
  String get favouritePlaylistPath => AppPaths.FAVOURITES_PLAYLIST;

  @override
  bool get sortAfterPreparing => true;

  @override
  bool get addTracksAtBeginning => settings.playlistAddTracksAtBeginning.value;

  @override
  String get EMPTY_NAME => lang.PLEASE_ENTER_A_NAME;

  @override
  String get NAME_CONTAINS_BAD_CHARACTER => lang.NAME_CONTAINS_BAD_CHARACTER;

  @override
  String get SAME_NAME_EXISTS => lang.PLEASE_ENTER_A_DIFFERENT_NAME;

  @override
  String get NAME_IS_NOT_ALLOWED => lang.PLEASE_ENTER_A_DIFFERENT_NAME;

  @override
  String get PLAYLIST_NAME_FAV => k_PLAYLIST_NAME_FAV;

  @override
  String get PLAYLIST_NAME_HISTORY => k_PLAYLIST_NAME_HISTORY;

  @override
  String get PLAYLIST_NAME_MOST_PLAYED => k_PLAYLIST_NAME_MOST_PLAYED;

  @override
  Map<String, dynamic> itemToJson(TrackWithDate item) => item.toJson();

  @override
  dynamic sortToJson(List<SortType> items) => items.map((e) => e.name).toList();

  @override
  bool canRemovePlaylist(LocalPlaylist playlist) {
    _popPageIfCurrent(() => playlist.name);
    return true;
  }

  @override
  void onPlaylistRemovedFromMap(List<String> names) {
    final searchList = SearchSortController.inst.playlistSearchList;
    for (final nameToRemove in names) {
      final plIndex = searchList.value.indexWhere((element) => nameToRemove == element);
      if (plIndex > -1) searchList.value.removeAt(plIndex);
    }
    searchList.refresh();
  }

  /// Navigate back in case the current route is this playlist.
  void _popPageIfCurrent(String Function() playlistName) {
    final lastPage = NamidaNavigator.inst.currentRoute;
    if (lastPage?.route == RouteType.SUBPAGE_playlistTracks) {
      if (lastPage?.name == playlistName()) {
        NamidaNavigator.inst.popPage();
      }
    }
  }

  @override
  void onPlaylistItemsSort(List<SortType> sorts, bool reverse, List<TrackWithDate> items) {
    final comparables = <Comparable<dynamic> Function(TrackWithDate tr)>[];
    for (final s in sorts) {
      if (s == SortType.dateAdded) {
        Comparable<dynamic> comparable(TrackWithDate e) => e.dateAddedMS;
        comparables.add(comparable);
      } else {
        final comparable = SearchSortController.inst.getTracksSortingComparables(s);
        Comparable<dynamic> comparabletwd(TrackWithDate twd) => comparable(twd.track);
        comparables.add(comparabletwd);
      }
    }

    if (reverse) {
      items.sortByReverseAlts(comparables);
    } else {
      items.sortByAlts(comparables);
    }
  }

  @override
  Future<Map<String, LocalPlaylist>> prepareAllPlaylistsFunction() async {
    return await _readPlaylistFilesCompute.thready(playlistsDirectory);
  }

  @override
  Future<LocalPlaylist?> prepareFavouritePlaylistFunction() {
    return _prepareFavouritesFile.thready(favouritePlaylistPath);
  }

  static LocalPlaylist? _prepareFavouritesFile(String path) {
    try {
      final response = File(path).readAsJsonSync();
      return LocalPlaylist.fromJson(response, TrackWithDate.fromJson, sortFromJson);
    } catch (_) {}
    return null;
  }

  static Map<String, LocalPlaylist> _readPlaylistFilesCompute(String path) {
    final map = <String, LocalPlaylist>{};
    final files = Directory(path).listSyncSafe();
    final filesL = files.length;
    for (int i = 0; i < filesL; i++) {
      var f = files[i];
      if (f is File) {
        try {
          final response = f.readAsJsonSync(ensureExists: false);
          final pl = LocalPlaylist.fromJson(response, TrackWithDate.fromJson, sortFromJson);
          map[pl.name] = pl;
        } catch (_) {}
      }
    }

    return map;
  }

  static List<SortType>? sortFromJson(dynamic value) {
    try {
      return (value as List).map((e) => SortType.values.getEnum(e)!).toList();
    } catch (_) {}
    return null;
  }
}

class _ParseM3UPlaylistFilesParams {
  final Set<String> allm3uPaths;
  final DbWrapperFileInfo tracksDbInfo; // used as a fallback lookup
  final String backupDirPath; // used as a backup for newly found m3u files.

  const _ParseM3UPlaylistFilesParams({
    required this.allm3uPaths,
    required this.tracksDbInfo,
    required this.backupDirPath,
  });
}

class _ParseM3UPlaylistFilesResult {
  final Map<String, (String, String?, List<Track>)> paths;
  final Map<String, String?> infoMap;

  const _ParseM3UPlaylistFilesResult({
    required this.paths,
    required this.infoMap,
  });
}
