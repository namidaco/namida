// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ignore: depend_on_referenced_packages
import 'package:collection/collection.dart' show DeepCollectionEquality;
import 'package:namico_db_wrapper/namico_db_wrapper.dart';
import 'package:path/path.dart' as p;
import 'package:playlist_manager/playlist_manager.dart';

import 'package:namida/class/file_parts.dart';
import 'package:namida/class/http_manager.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/directory_index.dart';
import 'package:namida/controller/generators_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/music_web_server/music_web_server_base.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/smart_playlists/smart_playlists_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dirs_file_filter.dart';
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

  Future<GeneralPlaylist<TrackWithDate, SortType>?> addNewPlaylist(
    String name, {
    List<Track> tracks = const <Track>[],
    int? creationDate,
    int? modifiedDate,
    String comment = '',
    List<String> moods = const [],
    List<String> tags = const [],
    bool isPinned = false,
    String? m3uPath,
    PlaylistAddDuplicateAction? actionIfAlreadyExists,
  }) => super.addNewPlaylistRaw(
    name,
    tracks: tracks,
    convertItem: (e, dateAdded, playlistID) => TrackWithDate(
      dateAdded: dateAdded,
      track: e,
    ),
    creationDate: creationDate,
    modifiedDate: modifiedDate,
    comment: comment,
    moods: moods,
    tags: tags,
    isPinned: isPinned,
    m3uPath: m3uPath,
    actionIfAlreadyExists: () => actionIfAlreadyExists ?? NamidaOnTaps.inst.showDuplicatedDialogAction(PlaylistAddDuplicateAction.valuesForAdd),
  );

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

    String toMessage(int total) => "${lang.added}: ${total.displayTrackKeyword}";
    final didAddTracks = addedTracksLength > 0;
    snackyy(
      message: toMessage(addedTracksLength),
      button: didAddTracks
          ? SnackbarButton(
              text: lang.undo,
              function: () async {
                await updatePropertyInPlaylist(playlist.name, tracks: oldTracksList, modifiedDate: originalModifyDate);
                final restoredPlaylist = getPlaylist(playlist.name);
                if (restoredPlaylist != null) await onPlaylistTracksChanged(restoredPlaylist); // -- rewrites the m3u, its pending write still holds the added tracks
              },
            )
          : null,
      merge: didAddTracks
          ? SnackbarMerge(
              group: .playlistAddTracks,
              id: playlist.name,
              count: addedTracksLength,
              toMessage: toMessage,
            )
          : null,
    );
  }

  @override
  int? getMetadataEditDate(LocalPlaylist playlist) {
    if (playlist.m3uPath != null) return _m3uDateCeil(currentTimeMS);
    return super.getMetadataEditDate(playlist);
  }

  /// the tracks are kept as they are, the tags are combined.
  Future<LocalPlaylist?> mergePlaylists(List<String> playlistsNames, String newName, {required bool removeMerged, required bool deleteM3UFiles}) async {
    final tracks = <Track>[];
    final tags = <String>[];
    for (final name in playlistsNames) {
      final pl = playlistsMap.value[name];
      if (pl == null) continue;
      for (final twd in pl.tracks) {
        tracks.add(twd.track);
      }
      for (final tag in pl.tags) {
        if (!tags.contains(tag)) tags.add(tag);
      }
    }
    if (tracks.isEmpty) return null;
    final merged = await addNewPlaylist(newName, tracks: tracks, tags: tags);
    if (removeMerged) await removePlaylists(playlistsNames, deleteM3UFiles: deleteM3UFiles);
    return merged;
  }

  Future<int> exportPlaylistsToM3UFiles(List<String> playlistsNames, String directoryPath) async {
    int exportedCount = 0;
    final exportedPaths = <String>{};
    for (final name in playlistsNames) {
      final pl = playlistsMap.value[name];
      if (pl == null) continue;
      final filePath = getUniqueM3UFilePath(name, directoryPath, p.context, shouldReplaceReservedChars: _shouldReplaceReservedChars, isTaken: exportedPaths.contains);
      exportedPaths.add(filePath);
      try {
        await exportPlaylistToM3UFile(pl, filePath, inDisplayedOrder: true);
        exportedCount++;
      } catch (_) {}
    }
    return exportedCount;
  }

  List<Track> getUniqueTracksOf(Iterable<String> playlistsNames) {
    final tracks = <Track>[];
    final added = <Track>{};
    for (final name in playlistsNames) {
      final pl = playlistsMap.value[name];
      if (pl == null) continue;
      for (final twd in pl.tracks) {
        final tr = twd.track;
        if (added.add(tr)) tracks.add(tr);
      }
    }
    return tracks;
  }

  /// adds [track] without prompting, or removes it when already inside [playlist].
  Future<void> toggleTrackInPlaylist(LocalPlaylist playlist, Track track) async {
    final index = playlist.tracks.indexWhere((e) => e.track == track);
    if (index >= 0) {
      await removeTracksFromPlaylist(playlist, [index]);
    } else {
      await addTracksToPlaylistRaw(playlist, [track], null, (e, dateAdded) => TrackWithDate(dateAdded: dateAdded, track: e));
    }
  }

  bool favouriteButtonOnPressed(Track track, {bool refreshNotification = true, bool deferListsSorting = false}) {
    if (deferListsSorting) Indexer.inst.deferFavouriteSorting(track);
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

  @override
  Future<bool> setArtworkForPlaylist(String playlistName, {required File? artworkFile, required Uint8List? artworkBytes}) async {
    final didSet = await super.setArtworkForPlaylist(
      playlistName,
      artworkFile: artworkFile,
      artworkBytes: artworkBytes,
    );
    if (didSet) {
      try {
        final imgPath = getArtworkFileForPlaylist(playlistName).path;
        await CurrentColor.inst.deletePaletteForImage(imgPath, paletteSaveDirectory: Directory(AppDirs.PALETTES));
      } catch (_) {}
    }
    return didSet;
  }

  Future<void> replaceTracksDirectory(String normalizedOldDir, String normalizedNewDir, {Iterable<String>? forThesePathsOnly, bool ensureNewFileExists = false}) async {
    final pathsOnlySet = forThesePathsOnly?.toSet();
    final existenceCache = <String, bool>{};
    final normalizedPathCache = <String, String>{};
    await replaceTheseTracksInPlaylists(
      (e) {
        final tr = e.track;
        normalizedPathCache[tr.path] ??= replaceFunctionNormalizePath(tr.path);
        return replaceFunctionForUpdatedPaths(tr.path, normalizedOldDir, normalizedNewDir, pathsOnlySet, ensureNewFileExists, existenceCache);
      },
      (old) {
        final normalized = normalizedPathCache[old.track.path] ?? replaceFunctionNormalizePath(old.track.path);
        return TrackWithDate(
          dateAdded: old.dateAdded,
          track: Track.fromTypeParameter(old.track.runtimeType, replaceFunctionGetNewPath(normalized, normalizedOldDir, normalizedNewDir)),
          source: old.source,
        );
      },
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
    if (didRename) {
      _popPageIfCurrent(() => playlistName);
      QueueController.latestPlayedForSourceManager.move(QueueSource.playlist(playlistName), QueueSource.playlist(newName));
    }
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

  /// [inDisplayedOrder] writes the sorted order instead of the custom one that linked files hold.
  Future<void> exportPlaylistToM3UFile(LocalPlaylist playlist, String path, {bool inDisplayedOrder = false}) async {
    final tracks = inDisplayedOrder ? playlist.tracks : _getLinkedM3UTracks(playlist);
    await _saveM3UPlaylistToFile.thready((
      path: path,
      entries: _buildM3UEntries(tracks),
      artworkUrl: _artworkUrlForM3uInfoMap[playlist.m3uPath ?? ''],
      relative: true,
    ));
  }

  /// sorters are re-applied when the file is read, see [ensureNewSourceItemsSorted].
  List<TrackWithDate> _getLinkedM3UTracks(LocalPlaylist playlist) => computeCustomOrder(playlist) ?? playlist.tracks;

  List<_M3UEntry> _buildM3UEntries(List<TrackWithDate> tracks) {
    final infoMap = _pathsM3ULookup;
    return List.generate(
      tracks.length,
      (i) {
        final tr = tracks[i].track;
        final path = tr.path;
        final info = infoMap[path];
        if (info != null) return (path: path, info: info);
        final trext = tr.toTrackExt();
        return (path: path, info: '#EXTINF:${trext.durationMS / 1000},${trext.originalArtist} - ${trext.title}');
      },
      growable: false,
    );
  }

  Future<void> prepareAllPlaylists() async {
    await Future.wait([
      super.prepareAllPlaylistsFile(),
      _m3uProperties.load(),
    ]);
    // -- preparing all playlist is awaited, for cases where
    // -- similar name exists, so m3u overrides it
    // -- this can produce in an outdated playlist version in cache
    // -- which will be seen if the m3u file got deleted/renamed
    await prepareM3UPlaylists();
    if (!_m3uPlaylistsCompleter.isCompleted) _m3uPlaylistsCompleter.complete(true);
    unawaited(Indexer.inst.refreshServerPlaylists());
  }

  /// the m3u file of [name] when it's already in [AppDirs.M3UPlaylists], otherwise a new one there that no other playlist or file uses.
  static String getUnusedM3uFilePathInStorage(String name) => _instance._getUnusedM3uFilePathInStorage(name, const {});

  /// [reservedPaths] are taken by playlists that aren't saved yet.
  String _getUnusedM3uFilePathInStorage(String name, Set<String> reservedPaths) {
    final ownPath = playlistsMap.value[name]?.m3uPath;
    if (ownPath != null && p.isWithin(AppDirs.M3UPlaylists, ownPath)) return ownPath;
    bool isTaken(String path) => reservedPaths.contains(path) || _m3uProperties.isPathSavedByAnother(path, name) || File(path).existsSync();
    return getUniqueM3UFilePath(name, AppDirs.M3UPlaylists, p.context, shouldReplaceReservedChars: _shouldReplaceReservedChars, isTaken: isTaken);
  }

  @visibleForTesting
  static String getUniqueM3UFilePath(
    String playlistName,
    String directory,
    p.Context context, {
    required bool shouldReplaceReservedChars,
    required bool Function(String path) isTaken,
  }) {
    final filename = _toSafeFilename(playlistName, shouldReplaceReservedChars);
    var path = context.join(directory, '$filename.m3u');
    int i = 2;
    while (isTaken(path)) {
      path = context.join(directory, '$filename ($i).m3u');
      i++;
    }
    return path;
  }

  static final _shouldReplaceReservedChars = Platform.isWindows || Platform.isAndroid; // -- android shared storage rejects them too
  static final _reservedFilenameCharsRegex = RegExp(r'[<>:"/\\|?*\x00-\x1F\x7F]');
  static final _posixUnsafeFilenameCharsRegex = RegExp(r'[/\x00]');

  static String _toSafeFilename(String playlistName, bool shouldReplaceReservedChars) {
    final unsafeCharsRegex = shouldReplaceReservedChars ? _reservedFilenameCharsRegex : _posixUnsafeFilenameCharsRegex;
    return playlistName.replaceAll(unsafeCharsRegex, '_');
  }

  Future<List<Track>> readM3UFiles(Set<String> filesPaths) async {
    if (filesPaths.isEmpty) return [];
    final params = _ParseM3UPlaylistFilesParams(
      allm3uPaths: filesPaths,
      boundNamesByPath: _getM3UPlaylistsNamesByPath(),
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
      listy.addAll(p.value.tracks);
      _ensureM3UArtUrlObtained(p.key, p.value.path, p.value.artUrl);
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
      super.removePlaylists(namesToRemove); // -- keeps their metadata, the file could come back
    }
  }

  final _m3uPlaylistsCompleter = Completer<bool>();
  Future<bool> get waitForM3UPlaylistsLoad => _m3uPlaylistsCompleter.future;

  Future<int?> prepareM3UPlaylists({Set<String> forPaths = const {}, bool addAsM3U = true, Map<String, List<String>> tagsForPaths = const {}}) async {
    try {
      final allm3uPaths = forPaths.isEmpty ? await _listAllM3UFiles() : forPaths;

      _ParseM3UPlaylistFilesResult? resBoth;
      if (allm3uPaths.isNotEmpty) {
        final Map<String, String> boundNamesByPath;
        if (forPaths.isEmpty) {
          boundNamesByPath = _m3uProperties.getNamesByPath(allm3uPaths);
        } else if (addAsM3U) {
          boundNamesByPath = _getM3UPlaylistsNamesByPath();
        } else {
          boundNamesByPath = const {};
        }
        final params = _ParseM3UPlaylistFilesParams(
          allm3uPaths: allm3uPaths,
          boundNamesByPath: boundNamesByPath,
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

      bool didRestoreAny = false;
      for (final e in paths.entries) {
        try {
          final plName = e.key;
          final m3uPath = e.value.path;
          final trs = e.value.tracks;
          final stat = await File(m3uPath).stat();
          final creationDate = stat.creationDate.millisecondsSinceEpoch;
          final fileModifiedMS = stat.modified.millisecondsSinceEpoch;
          final properties = addAsM3U ? _m3uProperties.propertiesOf(plName) : null;
          final tagsToAdd = tagsForPaths[m3uPath];
          int? modifiedDate;
          if (addAsM3U) {
            final fileModifiedDate = _m3uDateFloor(fileModifiedMS);
            final propertiesModifiedDate = properties?.modifiedDate ?? 0;
            modifiedDate = fileModifiedDate.withMinimum(propertiesModifiedDate);
          }
          final plAlreadyExisting = playlistsMap.value[plName];
          if (plAlreadyExisting != null) {
            this.updatePropertyInPlaylist(
              plName,
              tracksRaw: trs,
              convertItem: (e, dateAdded) => TrackWithDate(dateAdded: dateAdded, track: e),
              tags: tagsToAdd == null ? null : _combineTags(plAlreadyExisting.tags, tagsToAdd),
              m3uPath: addAsM3U ? m3uPath : null,
              creationDate: creationDate,
              modifiedDate: modifiedDate,
              tracksFromNewSource: true,
            );
          } else if (properties != null) {
            int dateAdded = currentTimeMS;
            final tracks = trs.map((tr) => TrackWithDate(dateAdded: dateAdded++, track: tr)).toList();
            final restored = properties.copyWith(
              name: plName,
              tracks: tracks,
              m3uPath: m3uPath,
              creationDate: creationDate,
              modifiedDate: modifiedDate,
            );
            importPlaylistForce(restored, sortPlaylists: false, tracksFromNewSource: true);
            didRestoreAny = true;
          } else {
            this.addNewPlaylist(
              plName,
              tracks: trs,
              tags: tagsToAdd ?? const [],
              m3uPath: addAsM3U ? m3uPath : null,
              creationDate: creationDate,
              modifiedDate: modifiedDate,
              actionIfAlreadyExists: PlaylistAddDuplicateAction.deleteAndCreateNewPlaylist, // we already check here tho
            );
          }

          _ensureM3UArtUrlObtained(plName, e.value.path, e.value.artUrl);
        } catch (_) {}
      }
      if (didRestoreAny) sortPlaylists();

      if (_pathsM3ULookup.isEmpty) {
        _pathsM3ULookup = infoMap;
      } else {
        _pathsM3ULookup.addAll(infoMap);
      }

      return paths.length;
    } catch (_) {}
    return null;
  }

  Map<String, String> _getM3UPlaylistsNamesByPath() {
    final namesByPath = <String, String>{};
    for (final pl in playlistsMap.value.values) {
      final m3uPath = pl.m3uPath;
      if (m3uPath != null && m3uPath.isNotEmpty) namesByPath[m3uPath] = pl.name;
    }
    return namesByPath;
  }

  /// {m3uPath: playlistName} of [m3uPaths] in [m3uProperties], a path saved under several names keeps the last one.
  @visibleForTesting
  static Map<String, String> getSavedM3UNamesByPath(Map<String, Map<String, dynamic>> m3uProperties, Set<String> m3uPaths) {
    final namesByPath = <String, String>{};
    for (final e in m3uProperties.entries) {
      final m3uPath = e.value['m3uPath'];
      if (m3uPaths.contains(m3uPath)) namesByPath[m3uPath] = e.key;
    }
    return namesByPath;
  }

  /// returns [tags] itself when there is nothing new.
  static List<String> _combineTags(List<String> tags, List<String>? tagsToAdd) {
    if (tagsToAdd == null) return tags;
    List<String>? combined;
    for (final tag in tagsToAdd) {
      if (tags.contains(tag)) continue;
      combined ??= [...tags];
      combined.add(tag);
    }
    return combined ?? tags;
  }

  Future<Set<String>> _listAllM3UFiles() async {
    final ownDir = AppDirs.M3UPlaylists;
    final allPaths = <String>{};
    if (settings.enableM3USyncStartup.value) {
      final dirsFilterer = DirsFileFilterSimple(
        extensions: NamidaFileExtensionsWrapper.m3u,
      );
      final result = await dirsFilterer.filter();
      for (final path in result.allPaths) {
        if (!p.isWithin(ownDir, path)) allPaths.add(path);
      }
    }
    // -- m3u playlists have no json copy, own folder must load regardless of indexer folders/setting
    try {
      await for (final entity in Directory(ownDir).list(recursive: true)) {
        final path = entity.path;
        if (entity is File && NamidaFileExtensionsWrapper.m3u.isPathValid(path)) allPaths.add(path);
      }
    } catch (_) {}
    return allPaths;
  }

  /// [playlists] tracks must be already resolved for this device, their m3uPath is only checked for existence.
  Future<void> importSyncedPlaylists(Iterable<LocalPlaylist> playlists) async {
    final newM3UPaths = <String>{};
    final preparing = playlists.map((pl) => _prepareSyncedPlaylist(pl, newM3UPaths));
    final prepared = await Future.wait(preparing);
    final toImport = prepared.nonNulls;
    if (toImport.isNotEmpty) await importPlaylistsIfNewer(toImport);
  }

  Future<LocalPlaylist?> _prepareSyncedPlaylist(LocalPlaylist incoming, Set<String> newM3UPaths) async {
    final existing = playlistsMap.value[incoming.name];
    if (existing != null && existing.modifiedDate > incoming.modifiedDate) return null;

    final m3uPath = _resolveSyncedM3UPath(incoming, existing, newM3UPaths);
    if (m3uPath == null) return null;
    if (m3uPath.isEmpty) return incoming.copyWith(m3uPath: '');

    final m3uModifiedDate = _m3uDateCeil(incoming.modifiedDate);
    final m3uPlaylist = incoming.copyWith(m3uPath: m3uPath, modifiedDate: m3uModifiedDate);
    final didWrite = await _writeSyncedM3UFile(m3uPlaylist, m3uPath);
    return didWrite ? m3uPlaylist : null;
  }

  /// null when it can't be stored, empty for a json playlist.
  String? _resolveSyncedM3UPath(LocalPlaylist incoming, LocalPlaylist? existing, Set<String> newM3UPaths) {
    if (existing != null) {
      final existingM3UPath = existing.m3uPath;
      if (existingM3UPath == null || existingM3UPath.isEmpty) return '';
      final canOverwrite = settings.enableM3USync.value || p.isWithin(AppDirs.M3UPlaylists, existingM3UPath);
      return canOverwrite ? existingM3UPath : null;
    }
    if (incoming.m3uPath?.isNotEmpty != true) return '';
    final m3uPath = _getUnusedM3uFilePathInStorage(incoming.name, newM3UPaths);
    newM3UPaths.add(m3uPath);
    return m3uPath;
  }

  Future<bool> _writeSyncedM3UFile(LocalPlaylist playlist, String m3uPath) async {
    _m3uWriteTimers.remove(m3uPath)?.cancel();
    final tracks = _getLinkedM3UTracks(playlist);
    final entries = _buildM3UEntries(tracks);
    try {
      await _saveM3UPlaylistToFile.thready((
        path: m3uPath,
        entries: entries,
        artworkUrl: _artworkUrlForM3uInfoMap[m3uPath],
        relative: true,
      ));
    } catch (_) {
      return false;
    }
    final modifiedDate = DateTime.fromMillisecondsSinceEpoch(playlist.modifiedDate);
    try {
      await File(m3uPath).setLastModified(modifiedDate);
    } catch (_) {}
    return true;
  }

  // -- m3u modified date is the file date, which is only second-precise
  static int _m3uDateFloor(int ms) => ms ~/ 1000 * 1000;
  static int _m3uDateCeil(int ms) => (ms + 999) ~/ 1000 * 1000;

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
          final pathNormalized = p.normalize(p.join(fileParentDirectory, artUrl));
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

  // ==================== Server Playlists ====================

  Map<String, int> getServerPlaylistsModifiedDates(String serverKey) {
    final map = <String, int>{};
    for (final pl in playlistsMap.value.values) {
      final rs = pl.remoteSource;
      if (rs != null && rs.sourceKey == serverKey) map[rs.remoteId] = pl.modifiedDate;
    }
    return map;
  }

  Future<void> updateServerPlaylists(
    String serverKey,
    List<WebServerPlaylist> serverPlaylists, {
    MusicWebServer? server,
    Track Function(TrackExtended trExt)? resolveTrack,
  }) async {
    await waitForPlaylistsLoad;

    final existingByRemoteId = <String, LocalPlaylist>{};
    for (final pl in playlistsMap.value.values) {
      final rs = pl.remoteSource;
      if (rs != null && rs.sourceKey == serverKey) existingByRemoteId[rs.remoteId] = pl;
    }

    bool anyChanged = false;
    final seenRemoteIds = <String>{};

    for (final spl in serverPlaylists) {
      seenRemoteIds.add(spl.id);
      final existing = existingByRemoteId[spl.id];
      final tracksExt = spl.tracks;

      if (tracksExt == null) {
        // -- unchanged or error, keep it and just ensure artwork exists
        if (existing != null) _ensureServerPlaylistArtworkExists(existing.name, spl, server);
        continue;
      }

      final nameBase = spl.name.replaceAll(cleanupFilenameRegex, '_').trimAll();
      final name = _resolveServerPlaylistName(nameBase.isEmpty ? spl.id : nameBase, existing);

      // -- keep old dates for tracks that were already there
      Map<Track, int>? oldDates;
      if (existing != null) {
        oldDates = {};
        for (final twd in existing.tracks) {
          oldDates[twd.track] ??= twd.dateAdded;
        }
      }
      int dateCounter = spl.changedMS ?? spl.createdMS ?? currentTimeMS;
      final newTracks = <TrackWithDate>[];
      for (final trExt in tracksExt) {
        final tr = resolveTrack != null ? resolveTrack(trExt) : trExt.asTrack();
        newTracks.add(
          TrackWithDate(
            dateAdded: oldDates?[tr] ?? dateCounter++,
            track: tr,
          ),
        );
      }

      if (existing != null && //
          existing.name == name &&
          existing.comment == (spl.comment ?? '') &&
          (spl.changedMS == null || existing.modifiedDate == spl.changedMS)) {
        if (_serverPlaylistTracksEqual(existing, newTracks)) {
          _ensureServerPlaylistArtworkExists(name, spl, server);
          continue; // -- after review, nothing really changed. keep it and just ensure artwork exists
        }
      }

      if (existing != null && existing.name != name) {
        // -- renamed on server, remove and re add (cuz cant edit)
        await removePlaylist(existing);
      }

      var newPl = LocalPlaylist(
        name: name,
        tracks: newTracks,
        creationDate: spl.createdMS ?? existing?.creationDate ?? currentTimeMS,
        modifiedDate: spl.changedMS ?? currentTimeMS,
        comment: spl.comment ?? '',
        moods: existing?.moods ?? [],
        tags: existing?.tags ?? [],
        isFav: false,
        isPinned: existing?.isPinned ?? false,
        m3uPath: null,
        sortsType: existing?.sortsType,
        sortReverse: existing?.sortReverse ?? false,
        remoteSource: PlaylistRemoteSource(sourceKey: serverKey, remoteId: spl.id),
      );

      newPl = await ensureNewSourceItemsSorted(newPl);
      await importPlaylistForce(newPl, sortPlaylists: false);

      anyChanged = true;

      _ensureServerPlaylistArtworkExists(name, spl, server);
    }

    // -- remove playlists that no longer exist on the server
    final namesToRemove = <String>[];
    for (final e in existingByRemoteId.entries) {
      if (!seenRemoteIds.contains(e.key)) namesToRemove.add(e.value.name);
    }
    if (namesToRemove.isNotEmpty) {
      await removePlaylists(namesToRemove); // -- sorts internally
    } else if (anyChanged) {
      sortPlaylists();
    }
  }

  Future<void> removeServerPlaylists({bool Function(String sourceKey)? keepTest}) async {
    await waitForPlaylistsLoad;
    final namesToRemove = <String>[];
    for (final e in playlistsMap.value.entries) {
      final rs = e.value.remoteSource;
      if (rs != null) {
        if (keepTest == null || !keepTest(rs.sourceKey)) namesToRemove.add(e.key);
      }
    }
    if (namesToRemove.isNotEmpty) await removePlaylists(namesToRemove);
  }

  String _resolveServerPlaylistName(String base, LocalPlaylist? existing) {
    if (existing != null) {
      // -- keep current name if matches the server name
      final currentName = existing.name;
      if (currentName == base || (currentName.startsWith('$base (') && currentName.endsWith(')'))) return currentName;
    }
    var name = base;
    int i = 2;
    while (isOneOfDefaultPlaylists(name) || playlistsMap.value.containsKey(name)) {
      name = '$base ($i)';
      i++;
    }
    return name;
  }

  bool _serverPlaylistTracksEqual(LocalPlaylist existing, List<TrackWithDate> newTracks) {
    final hasSorters = existing.sortsType?.isNotEmpty == true;
    final oldTracks = hasSorters ? existing.customOrder : existing.tracks;
    if (oldTracks == null) return false; // -- sorted before the server order was kept, re-importing keeps it

    if (oldTracks.length != newTracks.length) return false;

    for (int i = 0; i < newTracks.length; i++) {
      if (oldTracks[i].track != newTracks[i].track) return false;
    }

    return true;
  }

  void _ensureServerPlaylistArtworkExists(String playlistName, WebServerPlaylist spl, MusicWebServer? server) async {
    final coverArtId = spl.coverArtId;
    if (server == null || coverArtId == null || coverArtId.isEmpty) return;
    try {
      final file = getArtworkFileForPlaylist(playlistName);
      if (await file.exists()) return;
      final bytes = await server.getImage(coverArtId);
      if (bytes != null && bytes.isNotEmpty) {
        await setArtworkForPlaylist(playlistName, artworkFile: null, artworkBytes: bytes);
      }
    } catch (_) {}
  }

  // ======================================================================

  /// saves each track m3u info for writing back
  var _pathsM3ULookup = <String, String?>{}; // {trackPath: EXTINFO}

  final _artworkUrlForM3uInfoMap = <String, String?>{}; // {m3uPath: artUrl}

  static Future<_ParseM3UPlaylistFilesResult> _parseM3UPlaylistFiles(_ParseM3UPlaylistFilesParams params) async {
    final allm3uPaths = params.allm3uPaths;

    final backupDirPath = params.backupDirPath;

    final libraryTracksPaths = <String>[];

    bool didLoadTracksDb = false;
    Future<void> loadTracksDb() async {
      didLoadTracksDb = true;
      DBWrapperSync? tracksDBManager;
      try {
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

    String closestPathBySuffix(List<String> candidates, String lowerPath) {
      if (candidates.length == 1) return candidates[0];
      var best = candidates[0];
      var bestMatchedLength = -1;
      for (final candidate in candidates) {
        final candidateLower = candidate.toLowerCase();
        var i = candidateLower.length;
        var j = lowerPath.length;
        while (i > 0 && j > 0 && candidateLower.codeUnitAt(i - 1) == lowerPath.codeUnitAt(j - 1)) {
          i--;
          j--;
        }
        final matchedLength = lowerPath.length - j;
        if (matchedLength > bestMatchedLength) {
          bestMatchedLength = matchedLength;
          best = candidate;
        }
      }
      return best;
    }

    late final libraryPathsByLowerFilename = () {
      final index = <String, List<String>>{};
      for (final trackPath in libraryTracksPaths) {
        (index[trackPath.getFilename.toLowerCase()] ??= []).add(trackPath);
      }
      return index;
    }();

    final context = p.context;
    late final albumartUrlRegex = RegExp(r'(?<=#EXTALBUMARTURL:\s*).+');

    final namesByPath = allocateM3UPlaylistNames(allm3uPaths, params.boundNamesByPath, context);
    final all = <String, _M3UPlaylistTempInfo>{};
    final infoMap = <String, String?>{};
    for (final path in allm3uPaths) {
      final file = File(path);
      final fileParentDirectory = file.path.getDirectoryPath;
      final fullTracks = <Track>[];
      String? latestInfo;
      String? artUrl;
      for (final line in file.readAsLinesSync()) {
        if (line.startsWith("#")) {
          if (artUrl == null && line.startsWith('#EXTALBUMARTURL')) {
            artUrl = albumartUrlRegex.firstMatch(line)?[0];
          }

          latestInfo = line; // could be a comment, would get overriden by the next #EXTINF anyways
        } else if (line.isNotEmpty) {
          final entry = resolveM3UEntryLine(line, fileParentDirectory, context, pathExists);
          var fullPath = entry.path;
          if (!entry.isResolved) {
            // no idea, trying to get from library
            if (!didLoadTracksDb) await loadTracksDb();
            final lowerPath = fullPath.toLowerCase();
            final candidates = libraryPathsByLowerFilename[lowerPath.getFilename];
            if (candidates != null) fullPath = closestPathBySuffix(candidates, lowerPath);
          }
          fullTracks.add(Track.orVideo(fullPath));
          infoMap[fullPath] = latestInfo;
          latestInfo = null; // resetting info between each line loop
        }
      }
      final name = namesByPath[path]!;
      all[name] = _M3UPlaylistTempInfo(path: path, artUrl: artUrl, tracks: fullTracks);

      latestInfo = null; // resetting info between each file looping
    }

    // -- copying newly found m3u files as a backup
    for (final m3u in all.entries) {
      final backupFilename = _toSafeFilename(m3u.key, _shouldReplaceReservedChars);
      final backupFile = FileParts.join(backupDirPath, "$backupFilename.m3u");
      if (!backupFile.existsSync()) {
        File(m3u.value.path).copySync(backupFile.path);
      }
    }

    return _ParseM3UPlaylistFilesResult(
      paths: all,
      infoMap: infoMap,
    );
  }

  static final _urlRegex = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]+://');
  static final _pathSeparatorsRegex = RegExp(r'[\\/]');

  /// [line] resolved against [m3uDirectory], or against the root for posix lines that lost their leading slash.
  /// unresolved ones should be looked up in the library.
  @visibleForTesting
  static ({String path, bool isResolved}) resolveM3UEntryLine(String line, String m3uDirectory, p.Context context, bool Function(String path) exists) {
    final localPath = _m3uLineToLocalPath(line, context);
    if (localPath == null) return (path: line, isResolved: true);
    final joinedPath = context.join(m3uDirectory, localPath);
    final path = context.normalize(joinedPath);
    if (exists(path)) return (path: path, isResolved: true);
    final canBeRooted = context.style == p.Style.posix && context.isRelative(localPath);
    if (canBeRooted) {
      final rootedPath = context.normalize('/$localPath');
      if (exists(rootedPath)) return (path: rootedPath, isResolved: true);
    }
    return (path: path, isResolved: false);
  }

  /// null for urls other than file ones, they are kept as they are.
  static String? _m3uLineToLocalPath(String line, p.Context context) {
    if (!_urlRegex.hasMatch(line)) {
      final unprefixedLine = line.startsWith('primary/') ? line.replaceFirst('primary/', '') : line;
      return unprefixedLine.replaceAll(_pathSeparatorsRegex, context.separator);
    }
    if (!line.startsWith('file:')) return null;
    try {
      final fileUri = Uri.parse(line);
      return context.fromUri(fileUri);
    } catch (_) {
      return null;
    }
  }

  /// same-named files get their folder name as a prefix, files in [boundNamesByPath] keep their names.
  @visibleForTesting
  static Map<String, String> allocateM3UPlaylistNames(Set<String> m3uPaths, Map<String, String> boundNamesByPath, p.Context context) {
    final filenamesCounts = <String, int>{};
    void countFilename(String path) {
      final filename = context.basenameWithoutExtension(path);
      filenamesCounts.update(filename, (count) => count + 1, ifAbsent: () => 1);
    }

    for (final path in m3uPaths) {
      countFilename(path);
    }
    for (final path in boundNamesByPath.keys) {
      if (!m3uPaths.contains(path)) countFilename(path);
    }

    final takenNames = boundNamesByPath.values.toSet();
    final namesByPath = <String, String>{};
    for (final path in m3uPaths) {
      final boundName = boundNamesByPath[path];
      if (boundName != null) {
        namesByPath[path] = boundName;
        continue;
      }
      final filename = context.basenameWithoutExtension(path);
      var name = filename;
      if (filenamesCounts[filename]! > 1 || takenNames.contains(name)) {
        final parentDirectory = context.dirname(path);
        final parent = context.basename(parentDirectory);
        name = '$parent - $filename';
        var i = 2;
        while (takenNames.contains(name)) {
          name = '$parent - $filename ($i)';
          i++;
        }
      }
      takenNames.add(name);
      namesByPath[path] = name;
    }
    return namesByPath;
  }

  static Future<void> _saveM3UPlaylistToFile(
    ({String path, List<_M3UEntry> entries, String? artworkUrl, bool relative}) params,
  ) async {
    final mainPath = params.path;
    final entries = params.entries;
    final artworkUrl = params.artworkUrl;
    final relative = params.relative;

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
    final commonParentIsGood = commonParent.trim().isNotEmpty;
    final context = p.context;

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
    for (final entry in entries) {
      final path = entry.path;
      final pathLine = commonParentIsGood ? m3uEntryLine(path, commonParent, context) : path;
      sink.writeln(entry.info);
      sink.writeln(pathLine);
    }

    await sink.flush();
    await sink.close();
  }

  /// relative to [m3uDirectory] when possible, urls and paths on other roots stay as they are.
  @visibleForTesting
  static String m3uEntryLine(String path, String m3uDirectory, p.Context context) {
    if (_urlRegex.hasMatch(path)) return path;
    return context.relative(path, from: m3uDirectory);
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
          ObxO(
            rx: didRead,
            builder: (context, didRead) => NamidaButton(
              enabled: didRead,
              text: lang.confirm,
              onTap: () {
                settings.enableM3USync.save(true);
                NamidaNavigator.inst.closeDialog();
              },
            ),
          ),
        ],
        title: lang.note,
        child: Column(
          children: [
            Text(
              '${lang.enableM3uSync}?\n\n${lang.enableM3uSyncNote1}\n\n${lang.enableM3uSyncNote2(playlistsBackupPath: AppDirs.M3UBackup)}\n\n${lang.warning.toUpperCase()}: ${lang.enableM3uSyncSubtitle}',
              style: namida.textTheme.displayMedium,
            ),
            const SizedBox(height: 12.0),
            ListTileWithCheckMark(
              activeRx: didRead,
              icon: Broken.info_circle,
              title: lang.iReadAndAgree,
              burst: true,
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
          final tracks = _getLinkedM3UTracks(playlist);
          await _saveM3UPlaylistToFile.thready((
            path: m3uPath,
            entries: _buildM3UEntries(tracks),
            artworkUrl: _artworkUrlForM3uInfoMap[playlist.m3uPath ?? ''],
            relative: true,
          ));
          _m3uWriteTimers[m3uPath]?.cancel();
          _m3uWriteTimers.remove(m3uPath);
        });
      }
    }
  }

  late final _m3uPropertiesFile = FileParts.join(playlistsMetadataDirectory, 'm3u_metadata.json');
  late final _m3uProperties = _M3UPlaylistsProperties(_m3uPropertiesFile);

  @override
  Future<bool> writePlaylistToStorage(LocalPlaylist playlist) async {
    final m3uPath = playlist.m3uPath;
    final isM3U = m3uPath != null && m3uPath.isNotEmpty;
    if (isM3U) {
      final properties = playlist.toJson(itemToJson, sortToJson, includeTracks: false); // -- tracks live in the m3u file
      _m3uProperties.update(playlist.name, properties);
      return true;
    }
    _m3uProperties.remove(playlist.name);
    return await super.writePlaylistToStorage(playlist);
  }

  @override
  Future<void> removePlaylist(LocalPlaylist playlist) async {
    await super.removePlaylist(playlist);
    _m3uProperties.remove(playlist.name);
  }

  @override
  Future<void> removePlaylists(List<String> names, {bool deleteM3UFiles = false}) async {
    final m3uPaths = <String>[];
    if (deleteM3UFiles) {
      for (final name in names) {
        final m3uPath = playlistsMap.value[name]?.m3uPath;
        if (m3uPath != null) m3uPaths.add(m3uPath);
      }
    }
    await super.removePlaylists(names);
    names.loop(_m3uProperties.remove);
    for (final m3uPath in m3uPaths) {
      await File(m3uPath).deleteIfExists();
    }
  }

  @override
  void onTagsFilterChanged() => SearchSortController.inst.refreshPlaylistsTagsFilter();

  @override
  void onReadOnlyPlaylistError() {
    snackyy(message: lang.notSupportedForNetworkFiles, isError: true);
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
  String get EMPTY_NAME => lang.pleaseEnterAName;

  @override
  String get NAME_CONTAINS_BAD_CHARACTER => lang.nameContainsBadCharacter;

  @override
  String get SAME_NAME_EXISTS => lang.pleaseEnterADifferentName;

  @override
  String get NAME_IS_NOT_ALLOWED => lang.pleaseEnterADifferentName;

  @override
  String get PLAYLIST_NAME_FAV => k_PLAYLIST_NAME_FAV;

  @override
  String get PLAYLIST_NAME_HISTORY => k_PLAYLIST_NAME_HISTORY;

  @override
  String get PLAYLIST_NAME_MOST_PLAYED => k_PLAYLIST_NAME_MOST_PLAYED;

  @override
  Map<String, dynamic> itemToJson(TrackWithDate item) => item.toJson();

  @override
  dynamic sortToJson(List<SortType> items) => SortType.sortsToJson(items);

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

    QueueController.latestPlayedForSourceManager.deleteMultiple(names.map(QueueSource.playlist));
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
  void onFavouritesChanged(Iterable<Track>? items) => Indexer.inst.onFavouritesChanged(items);

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
  Future<void> prepareDefaultPlaylistsFileAsync() async {
    await [
      super.prepareDefaultPlaylistsFileAsync(),
      SmartPlaylistsController.inst.prepareAll(),
    ].executeAllAndSilentReportErrors();
  }

  @override
  Future<LocalPlaylist?> prepareFavouritePlaylistFunction() {
    return _prepareFavouritesFile.thready(favouritePlaylistPath);
  }

  static LocalPlaylist? _prepareFavouritesFile(String path) {
    try {
      final response = File(path).readAsJsonSync();
      return LocalPlaylist.fromJson(response, TrackWithDate.fromJson, SortType.sortListFromJsonList);
    } catch (_) {}
    return null;
  }

  static Map<String, LocalPlaylist> _readPlaylistFilesCompute(String path) {
    final map = <String, LocalPlaylist>{};
    final files = Directory(path).listSyncSafe();
    for (final f in files) {
      if (f is File) {
        try {
          final response = f.readAsJsonSync(ensureExists: false);
          final pl = LocalPlaylist.fromJson(response, TrackWithDate.fromJson, SortType.sortListFromJsonList);
          map[pl.name] = pl;
        } catch (_) {}
      }
    }

    return map;
  }
}

// by claude
class _M3UPlaylistsProperties {
  final File _file;
  _M3UPlaylistsProperties(this._file);

  /// {playlistName: playlist json without the tracks}
  var _entries = <String, Map<String, dynamic>>{};

  /// the returned playlist has no tracks.
  LocalPlaylist? propertiesOf(String playlistName) {
    final json = _entries[playlistName];
    if (json == null) return null;
    try {
      return LocalPlaylist.fromJson(json, TrackWithDate.fromJson, SortType.sortListFromJsonList);
    } catch (_) {
      return null;
    }
  }

  bool isPathSavedByAnother(String m3uPath, String playlistName) {
    for (final e in _entries.entries) {
      if (e.key != playlistName && e.value['m3uPath'] == m3uPath) return true;
    }
    return false;
  }

  Map<String, String> getNamesByPath(Set<String> m3uPaths) => PlaylistController.getSavedM3UNamesByPath(_entries, m3uPaths);

  Future<void> load() async {
    final json = await _file.readAsJson();
    if (json is! Map) return;
    final entries = <String, Map<String, dynamic>>{};
    for (final e in json.entries) {
      final properties = e.value;
      if (properties is Map<String, dynamic>) entries[e.key] = properties;
    }
    _entries = entries;
  }

  void update(String playlistName, Map<String, dynamic> properties) {
    final oldProperties = _entries[playlistName];
    if (oldProperties != null && const DeepCollectionEquality().equals(oldProperties, properties)) return;
    _entries[playlistName] = properties;
    _save();
  }

  void remove(String playlistName) {
    final removed = _entries.remove(playlistName);
    if (removed != null) _save();
  }

  bool _isSaving = false;
  bool _hasNewerEntries = false;

  Future<void> _save() async {
    if (_isSaving) {
      _hasNewerEntries = true;
      return;
    }
    _isSaving = true;
    do {
      _hasNewerEntries = false;
      await _file.writeAsJson(_entries);
    } while (_hasNewerEntries);
    _isSaving = false;
  }
}

class _ParseM3UPlaylistFilesParams {
  final Set<String> allm3uPaths;
  final Map<String, String> boundNamesByPath;
  final DbWrapperFileInfo tracksDbInfo; // used as a fallback lookup
  final String backupDirPath; // used as a backup for newly found m3u files.

  const _ParseM3UPlaylistFilesParams({
    required this.allm3uPaths,
    required this.boundNamesByPath,
    required this.tracksDbInfo,
    required this.backupDirPath,
  });
}

class _ParseM3UPlaylistFilesResult {
  final Map<String, _M3UPlaylistTempInfo> paths;
  final Map<String, String?> infoMap;

  const _ParseM3UPlaylistFilesResult({
    required this.paths,
    required this.infoMap,
  });
}

class _M3UPlaylistTempInfo {
  final String path;
  final String? artUrl;
  final List<Track> tracks;

  const _M3UPlaylistTempInfo({
    required this.path,
    this.artUrl,
    required this.tracks,
  });
}

extension LocalPlaylistUtils on LocalPlaylist {
  (String, String?)? getRemoteInfo() {
    final remoteSource = this.remoteSource;
    if (remoteSource == null) return null;

    final server = DirectoryIndexServer.parseFromEncodedUrlPath(remoteSource.sourceKey);
    final title = [
      server.toSourceInfo(),
      [
        server.type.toText(),
        server.username,
      ].join(' - '),
    ].join('\n');
    final assetImagePath = server.type.toAssetImage();
    return (title, assetImagePath);
  }
}

typedef _M3UEntry = ({String path, String info});
