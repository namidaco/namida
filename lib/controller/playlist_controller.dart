import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:namida/class/playlist.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/translations/strings.dart';

class PlaylistController {
  static PlaylistController get inst => _instance;
  static final PlaylistController _instance = PlaylistController._internal();
  PlaylistController._internal();

  final RxList<Playlist> playlistList = <Playlist>[].obs;
  final RxList<Playlist> playlistSearchList = <Playlist>[].obs;
  final RxList<Playlist> defaultPlaylists = <Playlist>[].obs;

  final RxMap<Track, List<int>> topTracksMapListens = <Track, List<int>>{}.obs;

  Timer? _historyTimer;

  /// Starts counting seconds listened, counter only increases when [isPlaying] is true.
  /// When the user seeks backwards by percentage >= 20%, a new counter starts.
  void startCounterToAListen(Track track) {
    debugPrint("Started a new counter");

    int currentListenedSeconds = 0;

    final sec = SettingsController.inst.isTrackPlayedSecondsCount.value;
    final perSett = SettingsController.inst.isTrackPlayedPercentageCount.value;
    final trDurInSec = Player.inst.nowPlayingTrack.value.duration / 1000;

    _historyTimer?.cancel();
    _historyTimer = null;
    _historyTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final per = currentListenedSeconds / trDurInSec * 100;

      debugPrint("Current percentage $per");
      if (Player.inst.isPlaying.value) {
        currentListenedSeconds++;
      }

      if (!per.isNaN && (currentListenedSeconds >= sec || per.toInt() >= perSett)) {
        timer.cancel();
        final date = DateTime.now().millisecondsSinceEpoch;
        addTrackToHistory([TrackWithDate(date, track, TrackSource.local)]);
        updateMostPlayedPlaylist(track: track, dateAdded: date);
        return;
      }
    });
  }

  void searchPlaylists(String text) {
    if (text == '') {
      LibraryTab.playlists.textSearchController?.clear();
      playlistSearchList.assignAll(playlistList);
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

    playlistSearchList.clear();
    playlistList.loop((item, index) {
      final lctext = textCleanedForSearch(text);
      final dateCreatedFormatted = formatDate.format(DateTime.fromMillisecondsSinceEpoch(item.creationDate));
      final dateModifiedFormatted = formatDate.format(DateTime.fromMillisecondsSinceEpoch(item.modifiedDate));

      if ((sTitle && textCleanedForSearch(item.name.translatePlaylistName()).contains(lctext)) ||
          (sCreationDate && textCleanedForSearch(dateCreatedFormatted.toString()).contains(lctext)) ||
          (sModifiedDate && textCleanedForSearch(dateModifiedFormatted.toString()).contains(lctext)) ||
          (sComment && textCleanedForSearch(item.comment).contains(lctext)) ||
          (sMoods && item.moods.any((element) => textCleanedForSearch(element).contains(lctext)))) {
        playlistSearchList.add(item);
      }
    });
  }

  /// Sorts Playlists and Saves automatically to settings
  void sortPlaylists({GroupSortType? sortBy, bool? reverse}) {
    sortBy ??= SettingsController.inst.playlistSort.value;
    reverse ??= SettingsController.inst.playlistSortReversed.value;
    switch (sortBy) {
      case GroupSortType.title:
        playlistList.sort((a, b) => a.name.translatePlaylistName().compareTo(b.name.translatePlaylistName()));
        break;
      case GroupSortType.creationDate:
        playlistList.sort((a, b) => a.creationDate.compareTo(b.creationDate));
        break;
      case GroupSortType.modifiedDate:
        playlistList.sort((a, b) => a.modifiedDate.compareTo(b.modifiedDate));
        break;
      case GroupSortType.duration:
        playlistList.sort((a, b) => a.tracks.map((e) => e.track).toList().totalDurationInS.compareTo(b.tracks.map((e) => e.track).toList().totalDurationInS));
        break;
      case GroupSortType.numberOfTracks:
        playlistList.sort((a, b) => a.tracks.length.compareTo(b.tracks.length));
        break;

      default:
        null;
    }

    if (reverse) {
      playlistList.assignAll(playlistList.reversed);
    }

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
    creationDate ??= DateTime.now().millisecondsSinceEpoch;
    final modifiedDate = DateTime.now().millisecondsSinceEpoch;
    final pl = Playlist(
      name,
      tracks.map((e) => TrackWithDate(DateTime.now().millisecondsSinceEpoch, e, TrackSource.local)).toList(),
      creationDate,
      modifiedDate,
      comment,
      moods,
      false,
    );
    playlistList.add(pl);

    await _savePlaylistToStorageAndRefresh(pl);
  }

  void insertPlaylist(Playlist playlist, int index) async {
    playlistList.insertSafe(index, playlist);

    await _savePlaylistToStorageAndRefresh(playlist);
  }

  void removePlaylist(Playlist playlist) async {
    playlistList.remove(playlist);

    await _deletePlaylistFromStorageAndRefresh(playlist);
  }

  void _updatePlaylistInsideList(Playlist oldPlaylist, Playlist newPlaylist) {
    final plIndex = playlistList.indexOf(oldPlaylist);
    playlistList.removeAt(plIndex);
    playlistList.insertSafe(plIndex, newPlaylist);
  }

  void updatePropertyInPlaylist(
    Playlist oldPlaylist, {
    List<TrackWithDate>? tracks,
    List<Track>? tracksToAdd,
    int? creationDate,
    String? comment,
    bool? isFav,
    List<String>? moods,
  }) async {
    final name = oldPlaylist.name;
    tracks ??= oldPlaylist.tracks;
    creationDate ??= oldPlaylist.creationDate;
    comment ??= oldPlaylist.comment;
    moods ??= oldPlaylist.moods;
    isFav ??= oldPlaylist.isFav;
    final modifiedDate = DateTime.now().millisecondsSinceEpoch;

    final newpl = Playlist(name, tracks, creationDate, modifiedDate, comment, moods, isFav);
    _updatePlaylistInsideList(oldPlaylist, newpl);

    await _savePlaylistToStorageAndRefresh(newpl);
  }

  Future<void> renamePlaylist(Playlist playlist, String newName) async {
    final modifiedDate = DateTime.now().millisecondsSinceEpoch;

    await File('$k_DIR_PLAYLISTS/${playlist.name}.json').rename('$k_DIR_PLAYLISTS/$newName.json');
    playlist.name = newName;
    playlist.modifiedDate = modifiedDate;
    await _savePlaylistToStorageAndRefresh(playlist);
  }

  String? validatePlaylistName(String? value) {
    value ??= '';

    if (value.isEmpty) {
      return Language.inst.PLEASE_ENTER_A_NAME;
    }
    final illegalChar = Platform.pathSeparator;
    if (value.contains(illegalChar)) {
      return "${Language.inst.NAME_CONTAINS_BAD_CHARACTER} $illegalChar";
    }
    if (File('$k_DIR_PLAYLISTS/$value.json').existsSync()) {
      return Language.inst.PLEASE_ENTER_A_DIFFERENT_NAME;
    }
    return null;
  }

  void addTracksToPlaylist(Playlist playlist, List<Track> tracks, {TrackSource source = TrackSource.local}) async {
    final newtracks = tracks.map((e) => TrackWithDate(DateTime.now().millisecondsSinceEpoch, e, source)).toList();

    final finaltracks = [...playlist.tracks, ...newtracks];
    playlist.tracks.assignAll(finaltracks);

    await _savePlaylistToStorageAndRefresh(playlist);
  }

  void insertTracksInPlaylist(Playlist playlist, List<TrackWithDate> tracks, int index) async {
    playlist.tracks.insertAllSafe(index, tracks.map((e) => e).toList());

    await _savePlaylistToStorageAndRefresh(playlist);
  }

  void removeTrackFromPlaylist(Playlist playlist, int index) async {
    playlist.tracks.removeAt(index);

    await _savePlaylistToStorageAndRefresh(playlist);
  }

  void reorderTrack(Playlist playlist, int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = playlist.tracks.elementAt(oldIndex);
    removeTrackFromPlaylist(playlist, oldIndex);
    insertTracksInPlaylist(playlist, [item], newIndex);
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

  Future<void> removeFromHistory(int index) async {
    namidaHistoryPlaylist.tracks.removeAt(index);
    await sortHistoryAndSave();
  }

  Future<void> sortHistoryAndSave() async {
    namidaHistoryPlaylist.tracks.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    await _saveHistoryToStorage();
  }

  Future<void> removeSourceTracksFromHistory(TrackSource source) async {
    namidaHistoryPlaylist.tracks.removeWhere((element) => element.source == source);
    await _saveHistoryToStorage();
  }

  Future<void> favouriteButtonOnPressed(Track track, {Track? updatedTrack}) async {
    final fvPlaylist = namidaFavouritePlaylist;

    final trfv = fvPlaylist.tracks.firstWhereOrNull((element) => element.track == track);
    if (trfv == null) {
      fvPlaylist.tracks.add(TrackWithDate(DateTime.now().millisecondsSinceEpoch, track, TrackSource.local));
    } else {
      final index = fvPlaylist.tracks.indexOf(trfv);
      fvPlaylist.tracks.removeAt(index);
      if (updatedTrack != null) {
        fvPlaylist.tracks.insert(index, TrackWithDate(trfv.dateAdded, updatedTrack, trfv.source));
      }
    }

    await _saveFavouritesToStorage();
  }

  /// Most Played Playlist, relies totally on History Playlist.
  /// Sending [track && dateAdded] just adds it to the map and sort, it won't perform a re-lookup from history.
  void updateMostPlayedPlaylist({Track? track, int? dateAdded}) {
    void sortAndUpdateMap(Map<Track, List<int>> unsortedMap, {Map<Track, List<int>>? mapToUpdate}) {
      final sortedEntries = unsortedMap.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length));
      final fmap = mapToUpdate ?? unsortedMap;
      fmap
        ..clear()
        ..addEntries(sortedEntries);
      namidaMostPlayedPlaylist.tracks.clear();
      namidaMostPlayedPlaylist.tracks.addAll(fmap.keys.map((e) => TrackWithDate(0, e, TrackSource.local)));
    }

    if (track != null && dateAdded != null) {
      if (topTracksMapListens.keyExists(track)) {
        topTracksMapListens[track]!.add(dateAdded);
      } else {
        topTracksMapListens[track] = [dateAdded];
      }
      sortAndUpdateMap(topTracksMapListens);
      return;
    }

    final HashMap<Track, List<int>> tempMap = HashMap<Track, List<int>>(equals: (p0, p1) => p0.path == p1.path);

    for (final t in namidaHistoryPlaylist.tracks) {
      if (tempMap.keyExists(t.track)) {
        tempMap[t.track]!.add(t.dateAdded);
      } else {
        tempMap[t.track] = [t.dateAdded];
      }
    }
    sortAndUpdateMap(tempMap, mapToUpdate: topTracksMapListens);
  }

  void _refreshStuff() async {
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

      await File(p.path).readAsJsonAnd((response) async {
        playlistList.add(Playlist.fromJson(response));
      });
    }

    /// Sorting accensingly by date since [await for] doesnt maintain order
    sortPlaylists();
  }

  Future<void> prepareDefaultPlaylistsFile() async {
    await _prepareHistoryFile();
    await _prepareFavouritesFile();

    /// Creates default playlists
    if (!defaultPlaylists.any((pl) => pl.name == k_PLAYLIST_NAME_FAV)) {
      defaultPlaylists.add(Playlist(k_PLAYLIST_NAME_FAV, [], DateTime.now().millisecondsSinceEpoch, DateTime.now().millisecondsSinceEpoch, '', [], false));
    }
    if (!defaultPlaylists.any((pl) => pl.name == k_PLAYLIST_NAME_HISTORY)) {
      defaultPlaylists.add(Playlist(k_PLAYLIST_NAME_HISTORY, [], DateTime.now().millisecondsSinceEpoch, DateTime.now().millisecondsSinceEpoch, '', [], false));
    }
    if (!defaultPlaylists.any((pl) => pl.name == k_PLAYLIST_NAME_MOST_PLAYED)) {
      defaultPlaylists.add(Playlist(k_PLAYLIST_NAME_MOST_PLAYED, [], DateTime.now().millisecondsSinceEpoch, DateTime.now().millisecondsSinceEpoch, '', [], false));
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
      try {
        defaultPlaylists.add(Playlist.fromJson(jsonDecode(content)));
      } catch (e) {
        debugPrint(e.toString());
      }
    }
  }

  Future<void> _prepareFavouritesFile() async {
    final file = File(k_PLAYLIST_PATH_FAVOURITES);

    await file.readAsJsonAnd((response) async {
      defaultPlaylists.add(Playlist.fromJson(response));
    });
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
    if (await backupfile.existsAndValid()) {
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
    await File(path).writeAsJson(playlist.toJson());
  }

  Future<void> _savePlaylistToStorageAndRefresh(Playlist playlist) async {
    /// TODO(MSOB7YY): separate playlist methods above.
    if (playlist.isOneOfTheMainPlaylists) return;
    _refreshStuff();
    await File('$k_DIR_PLAYLISTS/${playlist.name}.json').writeAsJson(playlist.toJson());
  }

  Future<void> _deletePlaylistFromStorageAndRefresh(Playlist playlist) async {
    _refreshStuff();
    await File('$k_DIR_PLAYLISTS/${playlist.name}.json').delete();
  }
}
