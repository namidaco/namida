// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:playlist_manager/module/playlist_id.dart';
import 'package:playlist_manager/playlist_manager.dart';

import 'package:namida/class/video.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';

typedef YoutubePlaylist = GeneralPlaylist<YoutubeID>;

class YoutubePlaylistController extends PlaylistManager<YoutubeID> {
  static YoutubePlaylistController get inst => _instance;
  static final YoutubePlaylistController _instance = YoutubePlaylistController._internal();
  YoutubePlaylistController._internal();

  final canReorderVideos = false.obs;

  void addNewPlaylist(
    String name, {
    Iterable<String> videoIds = const <String>[],
    int? creationDate,
    String comment = '',
    List<String> moods = const [],
    PlaylistID? playlistID,
  }) async {
    super.addNewPlaylistRaw(
      name,
      tracks: (playlistID) {
        final newTracks = videoIds
            .map(
              (id) => YoutubeID(
                id: id,
                watchNull: YTWatch(dateNull: DateTime.now(), isYTMusic: false),
                playlistID: playlistID,
              ),
            )
            .toList();
        return newTracks;
      },
      creationDate: creationDate,
      comment: comment,
      moods: moods,
      playlistID: playlistID,
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
            watchNull: YTWatch(dateNull: DateTime.now(), isYTMusic: false),
            playlistID: playlist.playlistID,
          ),
        )
        .toList();
    await super.addTracksToPlaylistRaw(playlist, newtracks);
    return newtracks;
  }

  Future<bool> favouriteButtonOnPressed(String id) async {
    return await super.toggleTrackFavourite(
      newTrack: YoutubeID(
        id: id,
        watchNull: YTWatch(dateNull: DateTime.now(), isYTMusic: false),
        playlistID: favouritesPlaylist.value.playlistID,
      ),
      identifyBy: (ytid) => ytid.id == id,
    );
  }

  void sortYTPlaylists({GroupSortType? sortBy, bool? reverse}) {
    sortBy ??= settings.ytPlaylistSort.value;
    reverse ??= settings.ytPlaylistSortReversed.value;

    final playlistList = playlistsMap.entries.toList();
    void sortThis(Comparable Function(MapEntry<String, GeneralPlaylist<YoutubeID>> p) comparable) =>
        reverse! ? playlistList.sortByReverse(comparable) : playlistList.sortBy(comparable);

    switch (sortBy) {
      case GroupSortType.title:
        sortThis((p) => p.key.toLowerCase());
        break;
      case GroupSortType.creationDate:
        sortThis((p) => p.value.creationDate);
        break;
      case GroupSortType.modifiedDate:
        sortThis((p) => p.value.modifiedDate);
        break;
      case GroupSortType.numberOfTracks:
        sortThis((p) => p.value.tracks.length);
        break;
      case GroupSortType.shuffle:
        playlistList.shuffle();
        break;

      default:
        null;
    }

    playlistsMap
      ..clear()
      ..addEntries(playlistList);

    settings.save(ytPlaylistSort: sortBy, ytPlaylistSortReversed: reverse);
  }

  Future<void> prepareAllPlaylists() async => await super.prepareAllPlaylistsFile();

  @override
  Future<void> prepareDefaultPlaylistsFile() async {
    YoutubeHistoryController.inst.prepareHistoryFile();
    await super.prepareDefaultPlaylistsFile();
  }

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
    // -- note: popping page is managed internally inside [YTNormalPlaylistSubpage]
    return true;
  }

  @override
  Map<String, dynamic> itemToJson(YoutubeID item) => item.toJson();

  @override
  String get favouritePlaylistPath => AppPaths.YT_LIKES_PLAYLIST;

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
    for (final f in Directory(path).listSyncSafe()) {
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
  void sortPlaylists() => sortYTPlaylists();
}
