import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:namida/class/playlist.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/strings.dart';

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
      final lctext = text.toLowerCase();
      final dateFormatted = formatDate.format(DateTime.fromMillisecondsSinceEpoch(item.date));
      if ((sTitle && item.name.toLowerCase().toString().contains(lctext)) ||
          (sDate && dateFormatted.toString().contains(lctext)) ||
          (sComment && item.comment.toLowerCase().toString().contains(lctext)) ||
          (sModes && item.modes.any((element) => element.toLowerCase().toString().contains(lctext)))) {
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
        playlistList.sort((a, b) => a.name.compareTo(a.name));
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
    final plIndex = playlistList.indexOf(pl);
    final tracksTobeAdded = tracks.map((e) => TrackWithDate(DateTime.now().millisecondsSinceEpoch, e)).toList();
    final List<TrackWithDate> finalTracks = addAtFirst ? [...tracksTobeAdded, ...pl.tracks] : [...pl.tracks, ...tracksTobeAdded];
    final newPlaylist = Playlist(pl.id, pl.name, finalTracks, pl.date, pl.comment, pl.modes);

    playlistList.remove(pl);
    playlistList.insert(plIndex, newPlaylist);
    _writeToStorage();
  }

  /// Unsupported operation: Cannot add to an unmodifiable list

  // void addTracksToPlaylist(int id, List<Track> tracks, {bool addAtFirst = false}) {
  //   final pl = playlistList.firstWhere((p0) => p0.id == id);
  //   if (addAtFirst) {
  //     pl.tracks.insertAll(0, tracks);
  //   } else {
  //     pl.tracks.addAll(tracks);
  //   }
  //   _writeToStorage();
  // }

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
    final List<Track> randomList = [];
    final trackslist = Indexer.inst.tracksInfoList.length;
    final min = trackslist ~/ 6;
    final max = trackslist ~/ 3;
    final int randomNumber = min + Random().nextInt(max - min);
    for (int i = 0; i < randomNumber; i++) {
      randomList.add(Indexer.inst.tracksInfoList.toList()[Random().nextInt(Indexer.inst.tracksInfoList.length)]);
    }
    final l = playlistList.where((pl) => pl.name.startsWith('AUTO_GENERATED')).length;
    PlaylistController.inst.addNewPlaylist(
      'AUTO_GENERATED ${l + 1}',
      tracks: randomList,
    );
  }

  /// Top Music Playlist, relies totally on History Playlist.
  void updateTopMusicPlaylist() {
    final pltm = playlistList.firstWhere((p0) => p0.id == kPlaylistTopMusic);

    final Map<String, int> topTracksPathMap = <String, int>{};
    for (final t in playlistList.firstWhere((element) => element.id == kPlaylistHistory).tracks.map((e) => e.track).toList()) {
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
    pltm.tracks.clear();
    pltm.tracks.assignAll(topTracksMap.keys.map((e) => TrackWithDate(0, e)));
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
      addNewPlaylist('Favourites', id: kPlaylistFavourites);
    }
    if (!playlistList.any((pl) => pl.id == kPlaylistHistory)) {
      addNewPlaylist('History', id: kPlaylistHistory);
    }
    if (!playlistList.any((pl) => pl.id == kPlaylistTopMusic)) {
      addNewPlaylist('Top Music', id: kPlaylistTopMusic);
    }

    searchPlaylists('');
    updateTopMusicPlaylist();
  }

  void _writeToStorage() {
    updateTopMusicPlaylist();
    playlistList.refresh();
    searchPlaylists('');
    playlistList.map((pl) => pl.toJson()).toList();
    File(kPlaylistsFilePath).writeAsStringSync(json.encode(playlistList));
  }
}
