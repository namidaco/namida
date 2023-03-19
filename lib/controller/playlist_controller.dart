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

class PlaylistController extends GetxController {
  static PlaylistController inst = PlaylistController();

  RxList<Playlist> playlistList = <Playlist>[].obs;

  RxList<Playlist> playlistSearchList = <Playlist>[].obs;
  Rx<TextEditingController> playlistSearchController = TextEditingController().obs;

  final RxMap<Track, int> topTracksMap = <Track, int>{}.obs;

  RxInt currentListenedSeconds = 0.obs;

  void addToHistory(Track track) {
    currentListenedSeconds.value = 0;

    final sec = SettingsController.inst.isTrackPlayedSecondsCount.value;
    final perSett = SettingsController.inst.isTrackPlayedPercentageCount.value;
    final trDurInSec = Player.inst.nowPlayingTrack.value.duration / 1000;
    Timer.periodic(const Duration(seconds: 1), (timer) {
      final per = currentListenedSeconds.value / trDurInSec * 100;

      debugPrint("Current percentage $per");
      if (Player.inst.isPlaying.value) {
        currentListenedSeconds++;
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
      playlistSearchController.value.clear();
      playlistSearchList.assignAll(playlistList);
      return;
    }
    final psf = SettingsController.inst.playlistSearchFilter.toList();
    final sTitle = psf.contains('name');
    final sDate = psf.contains('date');
    final sComment = psf.contains('comment');
    final sModes = psf.contains('modes');
    final formatDate = DateFormat('yyyMMdd');

    playlistSearchList.clear();
    for (var item in playlistList) {
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
  }) {
    id ??= playlistList.length + 1;
    date ??= DateTime.now().millisecondsSinceEpoch;

    playlistList.add(Playlist(id, name, tracks.map((e) => TrackWithDate(DateTime.now().millisecondsSinceEpoch, e)).toList(), date, comment, modes));

    _writeToStorage();
  }

  void insertPlaylist(Playlist playlist, int index) {
    playlistList.insert(index, playlist);
    _writeToStorage();
  }

  void removePlaylist(Playlist playlist) {
    playlistList.remove(playlist);
    _writeToStorage();
  }

  void removePlaylists(List<Playlist> playlists) {
    for (var pl in playlists) {
      playlistList.remove(pl);
    }

    _writeToStorage();
  }

  void updatePlaylist(Playlist oldPlaylist, Playlist newPlaylist) {
    final plIndex = playlistList.indexOf(oldPlaylist);
    playlistList.remove(oldPlaylist);
    playlistList.insert(plIndex, newPlaylist);
    _writeToStorage();
  }

  void updatePropertyInPlaylist(Playlist oldPlaylist, {String? name, List<TrackWithDate>? tracks, List<Track>? tracksToAdd, int? date, String? comment, List<String>? modes}) {
    name ??= oldPlaylist.name;
    tracks ??= oldPlaylist.tracks;
    date ??= oldPlaylist.date;
    comment ??= oldPlaylist.comment;
    modes ??= oldPlaylist.modes;

    final plIndex = playlistList.indexOf(oldPlaylist);
    playlistList.remove(oldPlaylist);
    playlistList.insert(plIndex, Playlist(oldPlaylist.id, name, tracks, date, comment, modes));
    _writeToStorage();
  }

  void addTracksToPlaylist(int id, List<Track> tracks, {bool addAtFirst = false}) {
    final pl = playlistList.firstWhere((p0) => p0.id == id);
    final newtracks = tracks.map((e) => TrackWithDate(DateTime.now().millisecondsSinceEpoch, e)).toList();
    if (addAtFirst) {
      final finaltracks = [...newtracks, ...pl.tracks];
      pl.tracks.assignAll(finaltracks);
    } else {
      final finaltracks = [...pl.tracks, ...newtracks];
      pl.tracks.assignAll(finaltracks);
    }
    _writeToStorage();
  }

  void insertTracksInPlaylist(int id, List<TrackWithDate> tracks, int index) {
    final pl = playlistList.firstWhere((p0) => p0.id == id);
    pl.tracks.insertAll(index, tracks.map((e) => e).toList());
    _writeToStorage();
  }

  void removeTracksFromPlaylist(int id, List<TrackWithDate> tracks) {
    final pl = playlistList.firstWhere((p0) => p0.id == id);
    for (final t in tracks) {
      pl.tracks.remove(t);
    }
    _writeToStorage();
  }

  void favouriteButtonOnPressed(Track track) {
    final fvPlaylist = PlaylistController.inst.playlistList.firstWhere(
      (element) => element.id == kPlaylistFavourites,
    );

    if (fvPlaylist.tracks.any((element) => element.track == track)) {
      fvPlaylist.tracks.removeWhere((element) => element.track == track);
    } else {
      addTracksToPlaylist(fvPlaylist.id, [track]);
    }
    _writeToStorage();
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
    plmp.tracks.assignAll(topTracksMap.keys.map((e) => TrackWithDate(0, e)));
  }

  ///
  Future<void> preparePlaylistFile({File? file}) async {
    file ??= await File(kPlaylistsFilePath).create();
    try {
      String contents = await file.readAsString();
      if (contents.isNotEmpty) {
        var jsonResponse = jsonDecode(contents);
        for (var p in jsonResponse) {
          playlistList.add(Playlist.fromJson(p));
          printInfo(info: "playlist: ${playlistList.length}");
        }
      }
    } catch (e) {
      printError(info: e.toString());
      await file.delete();
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

  void _writeToStorage() {
    updateMostPlayedPlaylist();
    playlistList.refresh();
    searchPlaylists('');
    playlistList.map((pl) => pl.toJson()).toList();
    File(kPlaylistsFilePath).writeAsStringSync(json.encode(playlistList));
  }
}
