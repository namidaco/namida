import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';

import 'package:namida/class/playlist.dart';
import 'package:namida/class/track.dart';
import 'package:namida/core/constants.dart';

class PlaylistController extends GetxController {
  static PlaylistController inst = PlaylistController();

  RxList<Playlist> playlistList = <Playlist>[].obs;

  // Future<void> preparePlaylistFile() async {
  //   print(playlistList.length);
  //   await readPlaylistData();
  //   print(playlistList.length);
  // }

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
    playlistList.firstWhere(
      (element) => element.id == -1,
    );
    addTracksToPlaylist(-1, [track]);
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
    if (fileStat.size == 0) {
      // Favourites
      addNewPlaylist('Favourites');
    }
    printInfo(info: "playlist: ${playlistList.length}");
  }

  void _writeToStorage() {
    playlistList.map((pl) => pl.toJson()).toList();
    File(kPlaylistsFilePath).writeAsStringSync(json.encode(playlistList));
  }
}
