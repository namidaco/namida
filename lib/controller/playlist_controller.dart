import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';

import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';

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

  late final Database _db;
  late final StoreRef<Object?, Object?> _dbstore;

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
      // TODO: bug possibilty, the percentage may be higher or lower by 1
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
    // TODO: expose in settings
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

    _writeToStorage();

    await _dbstore.record(name).put(_db, pl.toJson());
  }

  void insertPlaylist(Playlist playlist, int index) async {
    playlistList.insert(index, playlist);
    _writeToStorage();
    await _dbstore.record(playlist.name).put(_db, playlist.toJson());
  }

  void removePlaylist(Playlist playlist) async {
    playlistList.remove(playlist);
    _writeToStorage();

    await _dbstore.record(playlist.name).delete(_db);
  }

  // void removePlaylists(List<Playlist> playlists) {
  //   for (final pl in playlists) {
  //     playlistList.remove(pl);
  //   }

  //   _writeToStorage();
  // }

  // Not used
  void updatePlaylist(Playlist oldPlaylist, Playlist newPlaylist) async {
    final plIndex = playlistList.indexOf(oldPlaylist);
    playlistList.remove(oldPlaylist);
    playlistList.insert(plIndex, newPlaylist);
    _writeToStorage();

    await _dbstore.record(oldPlaylist.name).update(_db, newPlaylist.toJson());
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
    _writeToStorage();

    await _dbstore.record(oldPlaylist.name).update(_db, newpl.toJson());
  }

  void addTracksToPlaylist(String name, List<Track> tracks, {TrackSource source = TrackSource.local}) async {
    final pl = _getPlaylistByName(name);
    final newtracks = tracks.map((e) => TrackWithDate(DateTime.now().millisecondsSinceEpoch, e, source)).toList();

    final finaltracks = [...pl.tracks, ...newtracks];
    pl.tracks.assignAll(finaltracks);

    _writeToStorage();

    await _dbstore.record(name).update(_db, pl.toJson());
  }

  void insertTracksInPlaylist(String name, List<TrackWithDate> tracks, int index) async {
    final pl = _getPlaylistByName(name);
    pl.tracks.insertAll(index, tracks.map((e) => e).toList());
    _writeToStorage();

    await _dbstore.record(pl.name).update(_db, pl.toJson());
  }

  void removeTrackFromPlaylist(String name, int index) async {
    final pl = _getPlaylistByName(name);
    pl.tracks.removeAt(index);

    _writeToStorage();

    await _dbstore.record(name).update(_db, pl.toJson());
  }

  void removeWhereFromPlaylist(String name, bool Function(TrackWithDate) test) async {
    final pl = _getPlaylistByName(name);
    pl.tracks.removeWhere(test);

    _writeToStorage();

    await _dbstore.record(name).update(_db, pl.toJson());
  }

  void generateRandomPlaylist() {
    final rt = getRandomTracks();
    if (rt.isEmpty) {
      Get.snackbar(Language.inst.ERROR, Language.inst.NO_ENOUGH_TRACKS);
      return;
    }
    final l = playlistList.where((pl) => pl.name.startsWith(kPlaylistAutoGenerated)).length;
    PlaylistController.inst.addNewPlaylist(
      '$kPlaylistAutoGenerated ${l + 1}',
      tracks: rt,
    );
  }

  /// Default Playlist specific methods.
  void addTrackToHistory(List<TrackWithDate> tracks, {bool sortAndSave = true}) async {
    namidaHistoryPlaylist.tracks.addAll(tracks);

    if (sortAndSave) sortHistoryAndSave();
  }

  void sortHistoryAndSave() {
    namidaHistoryPlaylist.tracks.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
    _writeToStorage();
  }

  void removeSourceTracksFromHistory(TrackSource source) {
    final pl = namidaHistoryPlaylist;
    pl.tracks.removeWhere((element) => element.source == source);
  }

  void favouriteButtonOnPressed(Track track) async {
    final fvPlaylist = defaultPlaylists.firstWhere((element) => element.name == kPlaylistFavourites);

    if (fvPlaylist.tracks.any((element) => element.track == track)) {
      fvPlaylist.tracks.removeWhere((element) => element.track == track);
    } else {
      addTracksToPlaylist(fvPlaylist.name, [track]);
    }
    _writeToStorage();

    await _dbstore.record(fvPlaylist.name).update(_db, fvPlaylist.toJson());
  }

  /// Most Played Playlist, relies totally on History Playlist.
  void updateMostPlayedPlaylist() {
    final plmp = defaultPlaylists.firstWhereOrNull((p0) => p0.name == kPlaylistMostPlayed);
    if (plmp == null) {
      return;
    }
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
    plmp.tracks.clear();
    plmp.tracks.assignAll(topTracksMap.keys.map((e) => TrackWithDate(0, e, TrackSource.local)));
  }

  ///
  Future<void> preparePlaylistFile() async {
    _db = await databaseFactoryIo.openDatabase(kPlaylistsDBPath);
    _dbstore = StoreRef.main();
    final plys = await _dbstore.find(_db);

    for (final p in plys) {
      // prevents freezing the ui. cheap alternative for Isolate/compute.
      await Future.delayed(Duration.zero);
      playlistList.add(Playlist.fromJson(p.value as Map<String, dynamic>));
    }

    searchPlaylists('');
  }

  Future<void> prepareDefaultPlaylistsFile([bool nobackupfile = false]) async {
    final file = File(kDefaultPlaylistsFilePath);
    await file.create();
    final String content = await file.readAsString();
    if (!nobackupfile) {
      if (content.isEmpty || file.statSync().size < 2) {
        await tryRestoringBackupPlaylists();
        return;
      }
    }

    if (content.isNotEmpty) {
      for (final p in jsonDecode(content)) {
        defaultPlaylists.add(Playlist.fromJson(p as Map<String, dynamic>));
      }
    }

    /// Creates default playlists
    if (!defaultPlaylists.any((pl) => pl.name == kPlaylistFavourites)) {
      defaultPlaylists.add(Playlist(kPlaylistFavourites, [], DateTime.now().millisecondsSinceEpoch, '', []));
    }
    if (!defaultPlaylists.any((pl) => pl.name == kPlaylistHistory)) {
      defaultPlaylists.add(Playlist(kPlaylistHistory, [], DateTime.now().millisecondsSinceEpoch, '', []));
    }
    if (!defaultPlaylists.any((pl) => pl.name == kPlaylistMostPlayed)) {
      defaultPlaylists.add(Playlist(kPlaylistMostPlayed, [], DateTime.now().millisecondsSinceEpoch, '', []));
    }

    namidaHistoryPlaylist = defaultPlaylists.firstWhere((element) => element.name == kPlaylistHistory);
    namidaFavouritePlaylist = defaultPlaylists.firstWhere((element) => element.name == kPlaylistFavourites);
    namidaMostPlayedPlaylist = defaultPlaylists.firstWhere((element) => element.name == kPlaylistMostPlayed);

    updateMostPlayedPlaylist();
  }

  Future<void> backupDefaultPlaylists() async {
    final defaultfile = File(kDefaultPlaylistsFilePath);
    if (defaultfile.statSync().size > 2) {
      await defaultfile.copy(kDefaultPlaylistsBackupFilePath);
    }
  }

  Future<void> tryRestoringBackupPlaylists() async {
    final backupfile = File(kDefaultPlaylistsBackupFilePath);
    if (await backupfile.exists()) {
      await backupfile.copy(kDefaultPlaylistsFilePath);
      await prepareDefaultPlaylistsFile();
    } else {
      await prepareDefaultPlaylistsFile(true);
    }
  }

  Playlist _getPlaylistByName(String name) => defaultPlaylists.firstWhereOrNull((p0) => p0.name == name) ?? playlistList.firstWhere((p0) => p0.name == name);

  /// saves only [kPlaylistFavourites] and [kPlaylistHistory].
  /// most played is generated from history bothways.
  void _writeToStorage() async {
    final pls = defaultPlaylists.where((p0) => p0.name == kPlaylistFavourites || p0.name == kPlaylistHistory);
    await File(kDefaultPlaylistsFilePath).writeAsString(jsonEncode(pls.map((element) => element.toJson()).toList()));
    updateMostPlayedPlaylist();
    playlistList.refresh();
    searchPlaylists('');
  }
}
