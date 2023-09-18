// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'dart:io';

import 'package:playlist_manager/playlist_manager.dart';

import 'package:namida/class/youtube_id.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/language.dart';

typedef YoutubePlaylist = GeneralPlaylist<YoutubeID>;

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

  /// Returns added ids, when [preventDuplicates] is true;
  Future<Iterable<YoutubeID>> addTracksToPlaylist(YoutubePlaylist playlist, Iterable<String> videoIds, {bool preventDuplicates = true}) async {
    late Iterable<String> idsToAdd;

    if (preventDuplicates) {
      final existingIds = <String, bool>{};
      playlist.tracks.loop((e, index) {
        existingIds[e.id] = true;
      });
      // only add ids that doesnt exist inside playlist.
      idsToAdd = videoIds.where((element) => existingIds[element] == null);
    } else {
      idsToAdd = videoIds;
    }
    final newtracks = idsToAdd
        .map(
          (id) => YoutubeID(
            id: id,
            addedDate: DateTime.now(),
          ),
        )
        .toList();
    await super.addTracksToPlaylistRaw(playlist, newtracks);
    return newtracks;
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
  String get playlistsDirectory => AppDirs.YT_PLAYLISTS;

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
