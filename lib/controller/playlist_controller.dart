import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';

import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:namida/class/playlist.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/translations/strings.dart';

class PlaylistController extends GetxController {
  static PlaylistController inst = PlaylistController();

  final RxList<Playlist> playlistList = <Playlist>[].obs;
  final RxList<Playlist> playlistSearchList = <Playlist>[].obs;
  final RxList<Playlist> defaultPlaylists = <Playlist>[].obs;

  final TextEditingController playlistSearchController = TextEditingController();

  final RxMap<Track, int> topTracksMap = <Track, int>{}.obs;

  final RxInt currentListenedSeconds = 0.obs;

  void addToHistory(Track track) {
    currentListenedSeconds.value = 0;

    final sec = SettingsController.inst.isTrackPlayedSecondsCount.value;
    final perSett = SettingsController.inst.isTrackPlayedPercentageCount.value;
    final trDurInSec = Player.inst.nowPlayingTrack.value.duration / 1000;
    Timer.periodic(const Duration(seconds: 1), (timer) {
      final per = currentListenedSeconds.value / trDurInSec * 100;

      debugPrint("Current percentage $per");
      if (Player.inst.isPlaying.value) {
        currentListenedSeconds.value++;
      }

      Player.inst.nowPlayingTrack.listen((p0) {
        if (track != p0) {
          timer.cancel();
          return;
        }
      });
      // TODO(MSOB7YY): bug possibilty, the percentage may be higher or lower by 1
      if ((currentListenedSeconds.value == sec || per.toInt() == perSett)) {
        addTrackToHistory([TrackWithDate(DateTime.now().millisecondsSinceEpoch, track, TrackSource.local)]);
        timer.cancel();
        return;
      }
    });
  }

  void searchPlaylists(String text) {
    if (text == '') {
      playlistSearchController.clear();
      playlistSearchList.assignAll(playlistList);
      return;
    }
    // TODO(MSOB7YY): expose in settings
    final psf = SettingsController.inst.playlistSearchFilter.toList();
    final sTitle = psf.contains('name');
    final sDate = psf.contains('date');
    final sComment = psf.contains('comment');
    final sModes = psf.contains('modes');
    final formatDate = DateFormat('yyyyMMdd');

    playlistSearchList.clear();
    for (final item in playlistList) {
      final lctext = textCleanedForSearch(text);
      final dateFormatted = formatDate.format(DateTime.fromMillisecondsSinceEpoch(item.date));

      if ((sTitle && textCleanedForSearch(item.name.translatePlaylistName).contains(lctext)) ||
          (sDate && textCleanedForSearch(dateFormatted.toString()).contains(lctext)) ||
          (sComment && textCleanedForSearch(item.comment).contains(lctext)) ||
          (sModes && item.modes.any((element) => textCleanedForSearch(element).contains(lctext)))) {
        playlistSearchList.add(item);
      }
    }
  }

  /// Sorts Playlists and Saves automatically to settings
  void sortPlaylists({GroupSortType? sortBy, bool? reverse}) {
    sortBy ??= SettingsController.inst.playlistSort.value;
    reverse ??= SettingsController.inst.playlistSortReversed.value;
    switch (sortBy) {
      case GroupSortType.title:
        playlistList.sort((a, b) => a.name.translatePlaylistName.compareTo(b.name.translatePlaylistName));
        break;
      case GroupSortType.year:
        playlistList.sort((a, b) => a.date.compareTo(b.date));
        break;
      case GroupSortType.duration:
        playlistList.sort((a, b) => a.tracks.map((e) => e.track).toList().totalDuration.compareTo(b.tracks.map((e) => e.track).toList().totalDuration));
        break;
      case GroupSortType.numberOfTracks:
        playlistList.sort((a, b) => a.tracks.length.compareTo(b.tracks.length));
        break;

      default:
        null;
    }

    if (reverse) {
      playlistList.assignAll(playlistList.toList().reversed);
    }

    SettingsController.inst.save(playlistSort: sortBy, playlistSortReversed: reverse);

    searchPlaylists(playlistSearchController.value.text);
  }

  void addNewPlaylist(
    String name, {
    List<Track> tracks = const <Track>[],
    List<Track> tracksToAdd = const <Track>[],
    int? date,
    String comment = '',
    List<String> modes = const [],
  }) async {
    date ??= DateTime.now().millisecondsSinceEpoch;
    final pl = Playlist(name, tracks.map((e) => TrackWithDate(DateTime.now().millisecondsSinceEpoch, e, TrackSource.local)).toList(), date, comment, modes);
    playlistList.add(pl);

    await _savePlaylistToStorageAndRefresh(pl);
  }

  void insertPlaylist(Playlist playlist, int index) async {
    playlistList.insert(index, playlist);

    await _savePlaylistToStorageAndRefresh(playlist);
  }

  void removePlaylist(Playlist playlist) async {
    playlistList.remove(playlist);

    await _deletePlaylistFromStorageAndRefresh(playlist);
  }

  // void removePlaylists(List<Playlist> playlists) {
  //   for (final pl in playlists) {
  //     playlistList.remove(pl);
  //   }

  //   _refreshStuff();
  // }

  // Not used
  void updatePlaylist(Playlist oldPlaylist, Playlist newPlaylist) async {
    final plIndex = playlistList.indexOf(oldPlaylist);
    playlistList.remove(oldPlaylist);
    playlistList.insert(plIndex, newPlaylist);

    await _savePlaylistToStorageAndRefresh(newPlaylist);
  }

  void updatePropertyInPlaylist(
    Playlist oldPlaylist, {
    String? name,
    List<TrackWithDate>? tracks,
    List<Track>? tracksToAdd,
    int? date,
    String? comment,
    List<String>? modes,
  }) async {
    name ??= oldPlaylist.name;
    tracks ??= oldPlaylist.tracks;
    date ??= oldPlaylist.date;
    comment ??= oldPlaylist.comment;
    modes ??= oldPlaylist.modes;

    final plIndex = playlistList.indexOf(oldPlaylist);
    final newpl = Playlist(name, tracks, date, comment, modes);
    playlistList.remove(oldPlaylist);
    playlistList.insert(plIndex, newpl);

    await _savePlaylistToStorageAndRefresh(newpl);
  }

  void addTracksToPlaylist(String name, List<Track> tracks, {TrackSource source = TrackSource.local}) async {
    final pl = _getPlaylistByName(name);
    final newtracks = tracks.map((e) => TrackWithDate(DateTime.now().millisecondsSinceEpoch, e, source)).toList();

    final finaltracks = [...pl.tracks, ...newtracks];
    pl.tracks.assignAll(finaltracks);

    await _savePlaylistToStorageAndRefresh(pl);
  }

  void insertTracksInPlaylist(String name, List<TrackWithDate> tracks, int index) async {
    final pl = _getPlaylistByName(name);
    pl.tracks.insertAll(index, tracks.map((e) => e).toList());

    await _savePlaylistToStorageAndRefresh(pl);
  }

  void removeTrackFromPlaylist(String name, int index) async {
    final pl = _getPlaylistByName(name);
    pl.tracks.removeAt(index);

    await _savePlaylistToStorageAndRefresh(pl);
  }

  void removeWhereFromPlaylist(String name, bool Function(TrackWithDate) test) async {
    final pl = _getPlaylistByName(name);
    pl.tracks.removeWhere(test);

    await _savePlaylistToStorageAndRefresh(pl);
  }

  void generateRandomPlaylist() {
    final rt = getRandomTracks();
    if (rt.isEmpty) {
      Get.snackbar(Language.inst.ERROR, Language.inst.NO_ENOUGH_TRACKS);
      return;
    }
    final l = playlistList.where((pl) => pl.name.startsWith(k_PLAYLIST_NAME_AUTO_GENERATED)).length;
    addNewPlaylist('$k_PLAYLIST_NAME_AUTO_GENERATED ${l + 1}', tracks: rt);
  }

  /// Default Playlist specific methods.
  void addTrackToHistory(List<TrackWithDate> tracks, {bool sortAndSave = true}) async {
    namidaHistoryPlaylist.tracks.addAll(tracks);

    if (sortAndSave) sortHistoryAndSave();
  }

  void sortHistoryAndSave() {
    namidaHistoryPlaylist.tracks.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    _saveHistoryToStorage();
  }

  void removeSourceTracksFromHistory(TrackSource source) async {
    namidaHistoryPlaylist.tracks.removeWhere((element) => element.source == source);
    _saveHistoryToStorage();
  }

  void favouriteButtonOnPressed(Track track) async {
    final fvPlaylist = namidaFavouritePlaylist;

    final trfv = fvPlaylist.tracks.firstWhereOrNull((element) => element.track == track);
    if (trfv != null) {
      fvPlaylist.tracks.remove(trfv);
    } else {
      addTracksToPlaylist(fvPlaylist.name, [track]);
    }
    _saveFavouritesToStorage();
  }

  /// Most Played Playlist, relies totally on History Playlist.
  void updateMostPlayedPlaylist() {
    final historytracks = namidaHistoryPlaylist.tracks;

    final Map<String, int> topTracksPathMap = <String, int>{};
    for (final t in historytracks.map((e) => e.track).toList()) {
      if (topTracksPathMap.containsKey(t.path)) {
        topTracksPathMap.update(t.path, (value) => value + 1);
      } else {
        topTracksPathMap.addIf(true, t.path, 1);
      }
    }
    topTracksPathMap.forEach((key, value) {
      topTracksMap.addIf(true, namidaHistoryPlaylist.tracks.firstWhere((element) => element.track.path == key).track, value);
    });

    final sortedEntries = topTracksMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    topTracksMap
      ..clear()
      ..addEntries(sortedEntries);
    namidaMostPlayedPlaylist.tracks.clear();
    namidaMostPlayedPlaylist.tracks.addAll(topTracksMap.keys.map((e) => TrackWithDate(0, e, TrackSource.local)));
  }

  Playlist _getPlaylistByName(String name) => defaultPlaylists.firstWhereOrNull((p0) => p0.name == name) ?? playlistList.firstWhere((p0) => p0.name == name);

  /// saves only [k_PLAYLIST_NAME_FAV] and [k_PLAYLIST_NAME_HISTORY].
  /// most played is generated from history bothways.
  void _refreshStuff() async {
    updateMostPlayedPlaylist();
    searchPlaylists('');
    playlistList.refresh();
    defaultPlaylists.refresh();
  }

  // File Related
  ///
  Future<void> prepareAllPlaylistsFile() async {
    await for (final p in Directory(k_DIR_PLAYLISTS).list()) {
      // prevents freezing the ui. cheap alternative for Isolate/compute.
      await Future.delayed(Duration.zero);
      final string = await File(p.path).readAsString();
      if (string.isNotEmpty) {
        final content = jsonDecode(string) as Map<String, dynamic>;
        playlistList.add(Playlist.fromJson(content));
      }
    }
    searchPlaylists('');
  }

  Future<void> prepareDefaultPlaylistsFile() async {
    await _prepareHistoryFile();
    await _prepareFavouritesFile();

    /// Creates default playlists
    if (!defaultPlaylists.any((pl) => pl.name == k_PLAYLIST_NAME_FAV)) {
      defaultPlaylists.add(Playlist(k_PLAYLIST_NAME_FAV, [], DateTime.now().millisecondsSinceEpoch, '', []));
    }
    if (!defaultPlaylists.any((pl) => pl.name == k_PLAYLIST_NAME_HISTORY)) {
      defaultPlaylists.add(Playlist(k_PLAYLIST_NAME_HISTORY, [], DateTime.now().millisecondsSinceEpoch, '', []));
    }
    if (!defaultPlaylists.any((pl) => pl.name == k_PLAYLIST_NAME_MOST_PLAYED)) {
      defaultPlaylists.add(Playlist(k_PLAYLIST_NAME_MOST_PLAYED, [], DateTime.now().millisecondsSinceEpoch, '', []));
    }

    namidaHistoryPlaylist = defaultPlaylists.firstWhere((element) => element.name == k_PLAYLIST_NAME_HISTORY);
    namidaFavouritePlaylist = defaultPlaylists.firstWhere((element) => element.name == k_PLAYLIST_NAME_FAV);
    namidaMostPlayedPlaylist = defaultPlaylists.firstWhere((element) => element.name == k_PLAYLIST_NAME_MOST_PLAYED);

    updateMostPlayedPlaylist();
  }

  Future<void> _prepareHistoryFile() async {
    final file = File(k_PLAYLIST_PATH_HISTORY);
    await file.create();
    final String content = await file.readAsString();

    /// only read if we think there is a history backup file
    /// otherwise the function will be called with [didntFindHistoryBackup==true]
    /// stating to continue bcz no backup was found.

    if (content.isEmpty || file.statSync().size < 2) {
      final didRestore = await tryRestoringHistory();
      if (!didRestore) return;
    }

    if (content.isNotEmpty) {
      defaultPlaylists.add(Playlist.fromJson(jsonDecode(content)));
    }
  }

  Future<void> _prepareFavouritesFile() async {
    final file = File(k_PLAYLIST_PATH_FAVOURITES);
    await file.create();
    final String content = await file.readAsString();
    if (content.isNotEmpty) {
      defaultPlaylists.add(Playlist.fromJson(jsonDecode(content)));
    }
  }

  Future<void> backupHistoryPlaylist() async {
    final defaultfile = File(k_PLAYLIST_PATH_HISTORY);
    if (defaultfile.statSync().size > 2) {
      await defaultfile.copy(k_PLAYLIST_PATH_HISTORY_BACKUP);
    }
  }

  /// If a history backup was found, copies it and returns [true].
  Future<bool> tryRestoringHistory() async {
    final backupfile = File(k_PLAYLIST_PATH_HISTORY_BACKUP);
    if (await backupfile.exists()) {
      await backupfile.copy(k_PLAYLIST_PATH_HISTORY);
      return true;
    }
    return false;
  }

  Future<void> _saveHistoryToStorage() async {
    await _saveDefaultPlaylistToStorageAndRefresh(k_PLAYLIST_PATH_HISTORY, namidaHistoryPlaylist);
  }

  Future<void> _saveFavouritesToStorage() async {
    await _saveDefaultPlaylistToStorageAndRefresh(k_PLAYLIST_PATH_FAVOURITES, namidaFavouritePlaylist);
  }

  Future<void> _saveDefaultPlaylistToStorageAndRefresh(String path, Playlist playlist) async {
    _refreshStuff();
    await File(path).writeAsString(jsonEncode(playlist.toJson()));
  }

  Future<void> _savePlaylistToStorageAndRefresh(Playlist playlist) async {
    _refreshStuff();
    await File('$k_DIR_PLAYLISTS${playlist.date}.json').writeAsString(jsonEncode(playlist.toJson()));
  }

  Future<void> _deletePlaylistFromStorageAndRefresh(Playlist playlist) async {
    _refreshStuff();
    await File('$k_DIR_PLAYLISTS${playlist.date}.json').delete();
  }
}
