import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:get/get.dart';

import 'package:namida/class/playlist.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/translations/strings.dart';

class PlaylistController {
  static PlaylistController get inst => _instance;
  static final PlaylistController _instance = PlaylistController._internal();
  PlaylistController._internal();

  Playlist? getPlaylist(String name) => name == k_PLAYLIST_NAME_FAV ? favouritesPlaylist.value : playlistsMap[name];

  final RxMap<String, Playlist> playlistsMap = <String, Playlist>{}.obs;

  final Rx<Playlist> favouritesPlaylist = Playlist(k_PLAYLIST_NAME_FAV, [], currentTimeMS, currentTimeMS, '', [], true).obs;

  final RxBool canReorderTracks = false.obs;

  void addNewPlaylist(
    String name, {
    List<Track> tracks = const <Track>[],
    List<Track> tracksToAdd = const <Track>[],
    int? creationDate,
    String comment = '',
    List<String> moods = const [],
  }) async {
    assert(!isOneOfDefaultPlaylists(name), kUnsupportedOperationMessage);

    creationDate ??= currentTimeMS;

    final pl = Playlist(
      name,
      tracks.mapped((e) => TrackWithDate(currentTimeMS, e, TrackSource.local)),
      creationDate,
      currentTimeMS,
      comment,
      moods,
      false,
    );
    _updateMap(pl);

    await _savePlaylistToStorage(pl);
  }

  Future<void> reAddPlaylist(Playlist playlist, int modifiedDate) async {
    final newPlaylist = playlist.copyWith(modifiedDate: modifiedDate);
    _updateMap(newPlaylist);
    _sortPlaylists();
    await _savePlaylistToStorage(playlist);
  }

  void removePlaylist(Playlist playlist) async {
    // navigate back in case the current route is this playlist
    final lastPage = NamidaNavigator.inst.currentRoute;
    if (lastPage?.route == RouteType.SUBPAGE_playlistTracks) {
      if (lastPage?.name == playlist.name) {
        NamidaNavigator.inst.popPage();
      }
    }
    _removeFromMap(playlist);

    await _deletePlaylistFromStorage(playlist);
  }

  /// returns true if succeeded.
  Future<bool> updatePropertyInPlaylist(
    String oldPlaylistName, {
    int? creationDate,
    String? comment,
    bool? isFav,
    List<String>? moods,
  }) async {
    assert(!isOneOfDefaultPlaylists(oldPlaylistName), kUnsupportedOperationMessage);

    final oldPlaylist = getPlaylist(oldPlaylistName);
    if (oldPlaylist == null) return false;

    final newpl = oldPlaylist.copyWith(creationDate: creationDate, comment: comment, isFav: isFav, moods: moods);
    _updateMap(newpl, oldPlaylistName);
    await _savePlaylistToStorage(newpl);
    return true;
  }

  /// returns true if succeeded.
  Future<bool> renamePlaylist(String playlistName, String newName) async {
    try {
      await File('$k_DIR_PLAYLISTS/$playlistName.json').rename('$k_DIR_PLAYLISTS/$newName.json');
    } catch (e) {
      debugPrint(e.toString());
      return false;
    }
    final playlist = getPlaylist(playlistName);
    if (playlist == null) return false;

    final newPlaylist = playlist.copyWith(name: newName, modifiedDate: currentTimeMS);
    _updateMap(newPlaylist, playlistName);

    return (await _savePlaylistToStorage(newPlaylist));
  }

  String? validatePlaylistName(String? value) {
    value ??= '';

    if (value.isEmpty) {
      return Language.inst.PLEASE_ENTER_A_NAME;
    }
    if (isOneOfDefaultPlaylists(value)) {
      return Language.inst.PLEASE_ENTER_A_NAME;
    }

    final illegalChar = Platform.pathSeparator;
    if (value.contains(illegalChar)) {
      return "${Language.inst.NAME_CONTAINS_BAD_CHARACTER} $illegalChar";
    }

    if (playlistsMap.keyExists(value) || File('$k_DIR_PLAYLISTS/$value.json').existsSync()) {
      return Language.inst.PLEASE_ENTER_A_DIFFERENT_NAME;
    }
    return null;
  }

  void addTracksToPlaylist(Playlist playlist, List<Track> tracks, {TrackSource source = TrackSource.local}) async {
    final newtracks = tracks.mapped((e) => TrackWithDate(currentTimeMS, e, source));
    playlist.tracks.addAll(newtracks);
    _updateMap(playlist);

    await _savePlaylistToStorage(playlist);
  }

  Future<void> insertTracksInPlaylist(Playlist playlist, List<TrackWithDate> tracks, int index) async {
    playlist.tracks.insertAllSafe(index, tracks);
    _updateMap(playlist);

    await _savePlaylistToStorage(playlist);
  }

  Future<void> removeTrackFromPlaylist(Playlist playlist, int index) async {
    playlist.tracks.removeAt(index);
    _updateMap(playlist);
    await _savePlaylistToStorage(playlist);
  }

  Future<void> replaceTrackInAllPlaylists(Track oldTrack, Track newTrack) async {
    // -- normal
    final playlistsToSave = <Playlist>[];
    playlistsMap.entries.toList().loop((entry, index) {
      final p = entry.value;
      p.tracks.replaceWhere(
        (e) => e.track == oldTrack,
        (old) => TrackWithDate(old.dateAdded, newTrack, old.source),
        onMatch: () => playlistsToSave.add(p),
      );
    });
    await playlistsToSave.loopFuture((p, index) async {
      _updateMap(p);
      await _savePlaylistToStorage(p);
    });

    // -- favourite
    favouritesPlaylist.value.tracks.replaceSingleWhere(
      (e) => e.track == oldTrack,
      (old) => TrackWithDate(old.dateAdded, newTrack, old.source),
    );
    await _saveFavouritesToStorage();
  }

  void reorderTrack(Playlist playlist, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = playlist.tracks.removeAt(oldIndex);
    await insertTracksInPlaylist(playlist, [item], newIndex);
  }

  /// Returns number of generated tracks.
  int generateRandomPlaylist() {
    final rt = getRandomTracks();
    if (rt.isEmpty) return 0;

    final l = playlistsMap.keys.where((name) => name.startsWith(k_PLAYLIST_NAME_AUTO_GENERATED)).length;
    addNewPlaylist('$k_PLAYLIST_NAME_AUTO_GENERATED ${l + 1}', tracks: rt);

    return rt.length;
  }

  Future<void> favouriteButtonOnPressed(Track track, {Track? updatedTrack}) async {
    final fvPlaylist = favouritesPlaylist.value;

    final trfv = fvPlaylist.tracks.firstWhereOrNull((element) => element.track == track);
    if (trfv == null) {
      fvPlaylist.tracks.add(TrackWithDate(currentTimeMS, track, TrackSource.local));
    } else {
      final index = fvPlaylist.tracks.indexOf(trfv);
      fvPlaylist.tracks.removeAt(index);
      if (updatedTrack != null) {
        fvPlaylist.tracks.insert(index, TrackWithDate(trfv.dateAdded, updatedTrack, trfv.source));
      }
    }

    await _saveFavouritesToStorage();
  }

  // File Related
  ///
  Future<void> prepareAllPlaylistsFile() async {
    await for (final p in Directory(k_DIR_PLAYLISTS).list()) {
      // prevents freezing the ui. cheap alternative for Isolate/compute.
      await Future.delayed(Duration.zero);

      await File(p.path).readAsJsonAnd((response) async {
        final pl = Playlist.fromJson(response);
        _updateMap(pl);
      });
    }

    /// Sorting since [dir.list()]] doesnt maintain order
    _sortPlaylists();
  }

  Future<void> prepareDefaultPlaylistsFile() async {
    HistoryController.inst.prepareHistoryFile();
    await _prepareFavouritesFile();
  }

  Future<void> _prepareFavouritesFile() async {
    final file = File(k_PLAYLIST_PATH_FAVOURITES);
    await file.readAsJsonAnd((response) async {
      favouritesPlaylist.value = Playlist.fromJson(response);
    });
  }

  Future<bool> _saveFavouritesToStorage() async {
    favouritesPlaylist.refresh();
    final f = await File(k_PLAYLIST_PATH_FAVOURITES).writeAsJson(favouritesPlaylist.value.toJson());
    return f != null;
  }

  /// returns true if succeeded.
  Future<bool> _savePlaylistToStorage(Playlist playlist) async {
    final f = await File('$k_DIR_PLAYLISTS/${playlist.name}.json').writeAsJson(playlist.toJson());
    return f != null;
  }

  Future<bool> _deletePlaylistFromStorage(Playlist playlist) async {
    return (await File('$k_DIR_PLAYLISTS/${playlist.name}.json').deleteIfExists());
  }

  bool isOneOfDefaultPlaylists(String name) {
    return name == k_PLAYLIST_NAME_FAV || name == k_PLAYLIST_NAME_HISTORY || name == k_PLAYLIST_NAME_MOST_PLAYED;
  }

  void _updateMap(Playlist playlist, [String? name]) {
    name ??= playlist.name;
    playlistsMap[name] = playlist;
    _sortPlaylists();
  }

  void _removeFromMap(Playlist playlist) {
    playlistsMap.remove(playlist.name);
    playlistsMap.refresh();
  }

  void _sortPlaylists() => SearchSortController.inst.sortMedia(MediaType.playlist);

  final String kUnsupportedOperationMessage = 'Operation not supported for this type of playlist';
  UnsupportedError get unsupportedOperation => UnsupportedError(kUnsupportedOperationMessage);
}
