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

  RxInt currentListenedSeconds = 0.obs;

  void addToHistory(Track track) {
    currentListenedSeconds.value = 0;
    // if (playlistList.firstWhere((element) => element.id == -1).tracks.first == Player.inst.nowPlayingTrack.value) {
    //   return;
    // }
    final sec = SettingsController.inst.isTrackPlayedSecondsCount.value;
    final perSett = SettingsController.inst.isTrackPlayedPercentageCount.value;
    final trDurInSec = Player.inst.nowPlayingTrack.value.duration / 1000;
    Timer.periodic(const Duration(seconds: 1), (timer) {
      final per = currentListenedSeconds.value / trDurInSec * 100;

      debugPrint("Current percentage $per");
      if (Player.inst.isPlaying.value) {
        currentListenedSeconds++;
      }
      // TODO: bug possibilty, the percentage may be higher or lower by 1
      if ((track != Player.inst.nowPlayingTrack.value || currentListenedSeconds.value == sec || per.toInt() == perSett)) {
        addTracksToPlaylist(-2, [Player.inst.nowPlayingTrack.value], addAtFirst: true);
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
        playlistList.sort((a, b) => a.tracks.totalDuration.compareTo(b.tracks.totalDuration));
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
    playlistList.add(Playlist(id, name, tracks, date, comment, modes));
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

  void updatePropertyInPlaylist(Playlist oldPlaylist, {String? name, List<Track>? tracks, List<Track>? tracksToAdd, int? date, String? comment, List<String>? modes}) {
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
    if (addAtFirst) {
      pl.tracks.insertAll(0, tracks);
    } else {
      pl.tracks.addAll(tracks);
    }
    _writeToStorage();
  }

  void removeTracksFromPlaylist(int id, List<Track> tracks) {
    final pl = playlistList.firstWhere((p0) => p0.id == id);
    for (final t in tracks) {
      pl.tracks.remove(t);
    }
    _writeToStorage();
  }

  void favouriteButtonOnPressed(Track track) {
    final fvPlaylist = PlaylistController.inst.playlistList.firstWhere(
      (element) => element.id == -1,
    );

    if (fvPlaylist.tracks.contains(track)) {
      fvPlaylist.tracks.remove(track);
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
    PlaylistController.inst.addNewPlaylist(
      '${Language.inst.AUTO_GENERATED} ${PlaylistController.inst.playlistList.length + 1}',
      tracks: randomList,
    );
  }

  ///
  Future<void> preparePlaylistFile({File? file}) async {
    file ??= await File(kPlaylistsFilePath).create();
    final fileStat = await file.stat();

    String contents = await file.readAsString();
    if (contents.isNotEmpty) {
      var jsonResponse = jsonDecode(contents);

      for (var p in jsonResponse) {
        Playlist playlist = Playlist(
          p['id'],
          p['name'],
          List<Track>.from(p['tracks'].map((i) => Track.fromJson(i))),
          p['date'],
          p['comment'],
          List<String>.from(p['modes']),
        );
        playlistList.add(playlist);
        printInfo(info: "playlist: ${playlistList.length}");
      }
    }

    /// Creates default playlists
    if (!playlistList.any((pl) => pl.id == -1)) {
      addNewPlaylist('Favourites', id: -1);
    }
    if (!playlistList.any((pl) => pl.id == -2)) {
      addNewPlaylist('History', id: -2);
    }

    searchPlaylists('');
  }

  void _writeToStorage() {
    playlistList.refresh();
    searchPlaylists('');
    playlistList.map((pl) => pl.toJson()).toList();
    File(kPlaylistsFilePath).writeAsStringSync(json.encode(playlistList));
  }
}
