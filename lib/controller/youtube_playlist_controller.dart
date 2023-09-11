// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'dart:io';

import 'package:newpipeextractor_dart/models/videoInfo.dart';
import 'package:playlist_manager/playlist_manager.dart';

import 'package:namida/controller/youtube_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/language.dart';

typedef YoutubePlaylist = GeneralPlaylist<YoutubeID>;

class YoutubeID {
  final String id;
  final DateTime addedDate;

  const YoutubeID({
    required this.id,
    required this.addedDate,
  });

  factory YoutubeID.fromJson(Map<String, dynamic> json) {
    return YoutubeID(
      id: json['id'] ?? '',
      addedDate: DateTime.fromMillisecondsSinceEpoch(json['addedDate'] ?? 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "addedDate": addedDate.millisecondsSinceEpoch,
    };
  }

  @override
  bool operator ==(other) {
    if (other is YoutubeID) {
      return id == other.id && addedDate.millisecondsSinceEpoch == other.addedDate.millisecondsSinceEpoch;
    }
    return false;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => "YoutubeID(id: $id, addedDate: $addedDate)";
}

extension YoutubeIDUtils on YoutubeID {
  Future<VideoInfo?> toVideoInfo() async {
    return await YoutubeController.inst.fetchVideoDetails(id);
  }
}

class YoutubePlaylistController extends PlaylistManager<YoutubeID> {
  static YoutubePlaylistController get inst => _instance;
  static final YoutubePlaylistController _instance = YoutubePlaylistController._internal();
  YoutubePlaylistController._internal();

  void addNewPlaylist(
    String name, {
    Iterable<String> videoIds = const <String>[],
    int? creationDate,
    String comment = '',
    List<String> moods = const [],
  }) async {
    final newTracks = videoIds
        .map(
          (id) => YoutubeID(
            id: id,
            addedDate: DateTime.now(),
          ),
        )
        .toList();
    super.addNewPlaylistRaw(
      name,
      tracks: newTracks,
      creationDate: creationDate,
      comment: comment,
      moods: moods,
    );
  }

  void addTracksToPlaylist(YoutubePlaylist playlist, Iterable<String> videoIds) async {
    final newtracks = videoIds
        .map(
          (id) => YoutubeID(
            id: id,
            addedDate: DateTime.now(),
          ),
        )
        .toList();
    super.addTracksToPlaylistRaw(playlist, newtracks);
  }

  Future<void> favouriteButtonOnPressed(String id) async {
    await super.toggleTrackFavourite(
      newTrack: YoutubeID(id: id, addedDate: DateTime.now()),
      identifyBy: (ytid) => ytid.id == id,
    );
  }

  Future<void> prepareAllPlaylists() async => await super.prepareAllPlaylistsFile();

  @override
  String get EMPTY_NAME => lang.PLEASE_ENTER_A_NAME;

  @override
  String get NAME_CONTAINS_BAD_CHARACTER => lang.NAME_CONTAINS_BAD_CHARACTER;

  @override
  String get SAME_NAME_EXISTS => lang.PLEASE_ENTER_A_DIFFERENT_NAME;

  @override
  String get NAME_IS_NOT_ALLOWED => lang.PLEASE_ENTER_A_DIFFERENT_NAME;

  @override
  String get PLAYLIST_NAME_FAV => k_PLAYLIST_NAME_FAV;

  @override
  String get PLAYLIST_NAME_HISTORY => k_PLAYLIST_NAME_HISTORY;

  @override
  String get PLAYLIST_NAME_MOST_PLAYED => k_PLAYLIST_NAME_MOST_PLAYED;

  @override
  FutureOr<bool> canRemovePlaylist(YoutubePlaylist playlist) {
    return true; // TODO: navigate back
  }

  @override
  Map<String, dynamic> itemToJson(YoutubeID item) => item.toJson();

  @override
  String get favouritePlaylistPath => AppPaths.YT_FAVOURITES_PLAYLIST;

  @override
  String get playlistsDirectory => AppDirs.YOUTUBE_PLAYLISTS;

  @override
  Future<Map<String, YoutubePlaylist>> prepareAllPlaylistsFunction() async {
    return await _readPlaylistFilesCompute.thready(playlistsDirectory);
  }

  @override
  Future<YoutubePlaylist?> prepareFavouritePlaylistFunction() async {
    return await _prepareFavouritesFile.thready(favouritePlaylistPath);
  }

  static Future<YoutubePlaylist?> _prepareFavouritesFile(String path) async {
    try {
      final response = File(path).readAsJsonSync();
      return YoutubePlaylist.fromJson(response, (itemJson) => YoutubeID.fromJson(itemJson));
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, YoutubePlaylist>> _readPlaylistFilesCompute(String path) async {
    final map = <String, YoutubePlaylist>{};
    for (final f in Directory(path).listSync()) {
      if (f is File) {
        try {
          final response = f.readAsJsonSync();
          final pl = YoutubePlaylist.fromJson(response, (itemJson) => YoutubeID.fromJson(itemJson));
          map[pl.name] = pl;
        } catch (e) {
          continue;
        }
      }
    }
    return map;
  }

  @override
  void sortPlaylists() {}
}
