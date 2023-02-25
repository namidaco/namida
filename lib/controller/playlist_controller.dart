import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:get/get.dart';

import 'package:namida/class/playlist.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/translations/strings.dart';

class PlaylistController extends GetxController {
  static PlaylistController inst = PlaylistController();

  RxList<Playlist> playlistList = <Playlist>[].obs;

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

  void addTracksToPlaylist(int id, List<Track> tracks) {
    final pl = playlistList.firstWhere((p0) => p0.id == id);
    final plIndex = playlistList.indexOf(pl);

    final newPlaylist = Playlist(pl.id, pl.name, [...pl.tracks, ...tracks], pl.date, pl.comment, pl.modes);

    playlistList.remove(pl);
    playlistList.insert(plIndex, newPlaylist);
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
    if (fileStat.size < 80) {
      // Favourites
      addNewPlaylist('Favourites', id: -1);
    }
    printInfo(info: "playlist: ${playlistList.length}");
  }

  void _writeToStorage() {
    playlistList.map((pl) => pl.toJson()).toList();
    File(kPlaylistsFilePath).writeAsStringSync(json.encode(playlistList));
  }
}
