import 'dart:async';
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

class PlaylistController extends GetxController {
  static PlaylistController inst = PlaylistController();

  final RxList<Playlist> playlistList = <Playlist>[].obs;

  final RxList<Playlist> playlistSearchList = <Playlist>[].obs;
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
        addTracksToPlaylist(kPlaylistHistory, [Player.inst.nowPlayingTrack.value], addAtFirst: true);
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
      case GroupSortType.defaultSort:
        playlistList.sort((a, b) => a.id.compareTo(b.id));
        break;
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
    int? id,
    List<Track> tracks = const <Track>[],
    List<Track> tracksToAdd = const <Track>[],
    int? date,
    String comment = '',
    List<String> modes = const [],
  }) async {
    id ??= playlistList.length + 1;
    date ??= DateTime.now().millisecondsSinceEpoch;
    final pl = Playlist(id, name, tracks.map((e) => TrackWithDate(DateTime.now().millisecondsSinceEpoch, e, false)).toList(), date, comment, modes);
    playlistList.add(pl);

    _writeToStorage();

    await _dbstore.record(id).put(_db, pl.toJson());
  }

  void insertPlaylist(Playlist playlist, int index) async {
    playlistList.insert(index, playlist);
    _writeToStorage();
    await _dbstore.record(playlist.id).put(_db, playlist.toJson());
  }

  void removePlaylist(Playlist playlist) async {
    playlistList.remove(playlist);
    _writeToStorage();

    await _dbstore.record(playlist.id).delete(_db);
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

    await _dbstore.record(oldPlaylist.id).update(_db, newPlaylist.toJson());
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
    final newpl = Playlist(oldPlaylist.id, name, tracks, date, comment, modes);
    playlistList.remove(oldPlaylist);
    playlistList.insert(plIndex, newpl);
    _writeToStorage();

    await _dbstore.record(oldPlaylist.id).update(_db, newpl.toJson());
  }

  void addTracksToPlaylist(int id, List<Track> tracks, {bool addAtFirst = false}) async {
    final pl = playlistList.firstWhere((p0) => p0.id == id);
    final newtracks = tracks.map((e) => TrackWithDate(DateTime.now().millisecondsSinceEpoch, e, false)).toList();
    if (addAtFirst) {
      final finaltracks = [...newtracks, ...pl.tracks];
      pl.tracks.assignAll(finaltracks);
    } else {
      final finaltracks = [...pl.tracks, ...newtracks];
      pl.tracks.assignAll(finaltracks);
    }
    _writeToStorage();

    await _dbstore.record(id).update(_db, pl.toJson());
  }

  void addTrackToHistory(List<TrackWithDate> tracks) async {
    final pl = playlistList.firstWhere((p0) => p0.id == kPlaylistHistory);
    final finaltracks = [...pl.tracks, ...tracks];
    pl.tracks.assignAll(finaltracks);
    _writeToStorage();

    await _dbstore.record(kPlaylistHistory).update(_db, pl.toJson());
  }

  void insertTracksInPlaylist(int id, List<TrackWithDate> tracks, int index) async {
    final pl = playlistList.firstWhere((p0) => p0.id == id);
    pl.tracks.insertAll(index, tracks.map((e) => e).toList());
    _writeToStorage();

    await _dbstore.record(pl.id).update(_db, pl.toJson());
  }

  void removeTrackFromPlaylist(int id, int index) async {
    final pl = playlistList.firstWhere((p0) => p0.id == id);
    pl.tracks.removeAt(index);

    _writeToStorage();

    await _dbstore.record(id).update(_db, pl.toJson());
  }

  void removeWhereFromPlaylist(int id, bool Function(TrackWithDate) test) async {
    final pl = playlistList.firstWhere((p0) => p0.id == id);
    pl.tracks.removeWhere(test);

    _writeToStorage();

    await _dbstore.record(id).update(_db, pl.toJson());
  }

  void favouriteButtonOnPressed(Track track) async {
    final fvPlaylist = PlaylistController.inst.playlistList.firstWhere(
      (element) => element.id == kPlaylistFavourites,
    );

    if (fvPlaylist.tracks.any((element) => element.track == track)) {
      fvPlaylist.tracks.removeWhere((element) => element.track == track);
    } else {
      addTracksToPlaylist(fvPlaylist.id, [track]);
    }
    _writeToStorage();

    await _dbstore.record(fvPlaylist.id).update(_db, fvPlaylist.toJson());
  }

  void generateRandomPlaylist() {
    final l = playlistList.where((pl) => pl.name.startsWith('_AUTO_GENERATED_')).length;
    PlaylistController.inst.addNewPlaylist(
      '_AUTO_GENERATED_ ${l + 1}',
      tracks: getRandomTracks(),
    );
  }

  /// Most Played Playlist, relies totally on History Playlist.
  void updateMostPlayedPlaylist() {
    final plmp = playlistList.firstWhereOrNull((p0) => p0.id == kPlaylistMostPlayed);
    if (plmp == null) {
      return;
    }
    final historytracks = playlistList.firstWhere((element) => element.id == kPlaylistHistory).tracks;

    final Map<String, int> topTracksPathMap = <String, int>{};
    for (final t in historytracks.map((e) => e.track).toList()) {
      if (topTracksPathMap.containsKey(t.path)) {
        topTracksPathMap.update(t.path, (value) => value + 1);
      } else {
        topTracksPathMap.addIf(true, t.path, 1);
      }
    }
    topTracksPathMap.forEach((key, value) {
      topTracksMap.addIf(true, playlistList.firstWhere((element) => element.id == kPlaylistHistory).tracks.firstWhere((element) => element.track.path == key).track, value);
    });

    final sortedEntries = topTracksMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    topTracksMap
      ..clear()
      ..addEntries(sortedEntries);
    plmp.tracks.clear();
    plmp.tracks.assignAll(topTracksMap.keys.map((e) => TrackWithDate(0, e, false)));
  }

  ///
  Future<void> preparePlaylistFile({File? file}) async {
    _db = await databaseFactoryIo.openDatabase(kPlaylistsDBPath);
    _dbstore = StoreRef.main();
    final plys = await _dbstore.find(_db);

    for (final p in plys) {
      playlistList.add(Playlist.fromJson(p.value as Map<String, dynamic>));
      print(p.key);
    }

    /// Creates default playlists
    if (!playlistList.any((pl) => pl.id == kPlaylistFavourites)) {
      addNewPlaylist('_FAVOURITES_', id: kPlaylistFavourites);
    }
    if (!playlistList.any((pl) => pl.id == kPlaylistHistory)) {
      addNewPlaylist('_HISTORY_', id: kPlaylistHistory);
    }
    if (!playlistList.any((pl) => pl.id == kPlaylistMostPlayed)) {
      addNewPlaylist('_MOST_PLAYED_', id: kPlaylistMostPlayed);
    }

    searchPlaylists('');
    updateMostPlayedPlaylist();
  }

  void _writeToStorage() async {
    updateMostPlayedPlaylist();
    playlistList.refresh();
    searchPlaylists('');
  }
}
