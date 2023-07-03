import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:namida/class/playlist.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/pages/subpages/playlist_tracks_subpage.dart';

class PlaylistController {
  static PlaylistController get inst => _instance;
  static final PlaylistController _instance = PlaylistController._internal();
  PlaylistController._internal();

  Playlist? getPlaylist(String name) => name == k_PLAYLIST_NAME_FAV ? favouritesPlaylist.value : playlistsMap[name];

  final RxMap<String, Playlist> playlistsMap = <String, Playlist>{}.obs;
  final RxList<String> playlistSearchList = <String>[].obs;

  late final Rx<Playlist> favouritesPlaylist;

  void searchPlaylists(String text) {
    playlistSearchList.clear();

    if (text == '') {
      LibraryTab.playlists.textSearchController?.clear();
      playlistSearchList.addAll(playlistsMap.keys);
      return;
    }
    // TODO(MSOB7YY): expose in settings
    final psf = SettingsController.inst.playlistSearchFilter.toList();
    final sTitle = psf.contains('name');
    final sCreationDate = psf.contains('creationDate');
    final sModifiedDate = psf.contains('modifiedDate');
    final sComment = psf.contains('comment');
    final sMoods = psf.contains('moods');
    final formatDate = DateFormat('yyyyMMdd');

    final results = playlistsMap.entries.where((e) {
      final playlistName = e.key;
      final item = e.value;

      final lctext = textCleanedForSearch(text);
      final dateCreatedFormatted = formatDate.format(DateTime.fromMillisecondsSinceEpoch(item.creationDate));
      final dateModifiedFormatted = formatDate.format(DateTime.fromMillisecondsSinceEpoch(item.modifiedDate));

      return (sTitle && textCleanedForSearch(playlistName.translatePlaylistName()).contains(lctext)) ||
          (sCreationDate && textCleanedForSearch(dateCreatedFormatted.toString()).contains(lctext)) ||
          (sModifiedDate && textCleanedForSearch(dateModifiedFormatted.toString()).contains(lctext)) ||
          (sComment && textCleanedForSearch(item.comment).contains(lctext)) ||
          (sMoods && item.moods.any((element) => textCleanedForSearch(element).contains(lctext)));
    });
    playlistSearchList.addAll(results.map((e) => e.key));
  }

  /// Sorts Playlists and Saves automatically to settings
  void sortPlaylists({GroupSortType? sortBy, bool? reverse}) {
    sortBy ??= SettingsController.inst.playlistSort.value;
    reverse ??= SettingsController.inst.playlistSortReversed.value;

    final playlistList = playlistsMap.entries.toList();
    switch (sortBy) {
      case GroupSortType.title:
        playlistList.sort((a, b) => a.key.translatePlaylistName().compareTo(b.key.translatePlaylistName()));
        break;
      case GroupSortType.creationDate:
        playlistList.sort((a, b) => a.value.creationDate.compareTo(b.value.creationDate));
        break;
      case GroupSortType.modifiedDate:
        playlistList.sort((a, b) => a.value.modifiedDate.compareTo(b.value.modifiedDate));
        break;
      case GroupSortType.duration:
        playlistList.sort((a, b) => a.value.tracks.map((e) => e.track).toList().totalDurationInS.compareTo(b.value.tracks.map((e) => e.track).toList().totalDurationInS));
        break;
      case GroupSortType.numberOfTracks:
        playlistList.sort((a, b) => a.value.tracks.length.compareTo(b.value.tracks.length));
        break;

      default:
        null;
    }

    playlistsMap
      ..clear()
      ..addEntries(reverse ? playlistList.reversed : playlistList);

    SettingsController.inst.save(playlistSort: sortBy, playlistSortReversed: reverse);

    searchPlaylists(LibraryTab.playlists.textSearchController?.text ?? '');
  }

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
      tracks.map((e) => TrackWithDate(currentTimeMS, e, TrackSource.local)).toList(),
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
    sortPlaylists();
    await _savePlaylistToStorage(playlist);
  }

  void removePlaylist(Playlist playlist) async {
    // navigate back in case the current route is this playlist
    final lastPage = NamidaNavigator.inst.currentWidgetStack.lastOrNull;
    if (lastPage is NormalPlaylistTracksPage) {
      if (lastPage.playlistName == playlist.name) {
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
    _updateMap(newPlaylist);

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
    final newtracks = tracks.map((e) => TrackWithDate(currentTimeMS, e, source)).toList();
    playlist.tracks.addAll(newtracks);

    await _savePlaylistToStorage(playlist);
  }

  Future<void> insertTracksInPlaylist(Playlist playlist, List<TrackWithDate> tracks, int index) async {
    playlist.tracks.insertAllSafe(index, tracks);

    await _savePlaylistToStorage(playlist);
  }

  Future<void> removeTrackFromPlaylist(Playlist playlist, int index) async {
    playlist.tracks.removeAt(index);

    await _savePlaylistToStorage(playlist);
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

    /// Sorting since [await for] doesnt maintain order
    sortPlaylists();
  }

  Future<void> prepareDefaultPlaylistsFile() async {
    HistoryController.inst.prepareHistoryFile();
    await _prepareFavouritesFile();
  }

  Future<void> _prepareFavouritesFile() async {
    final file = File(k_PLAYLIST_PATH_FAVOURITES);
    await file.readAsJsonAnd((response) async {
      favouritesPlaylist = Playlist.fromJson(response).obs;
    });
  }

  Future<bool> _saveFavouritesToStorage() async {
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
    sortPlaylists();
  }

  void _removeFromMap(Playlist playlist) {
    playlistsMap.remove(playlist.name);
    sortPlaylists();
  }

  final String kUnsupportedOperationMessage = 'Operation not supported for this type of playlist';
  UnsupportedError get unsupportedOperation => UnsupportedError(kUnsupportedOperationMessage);
}
