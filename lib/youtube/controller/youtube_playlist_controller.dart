// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'dart:io';

import 'package:playlist_manager/module/playlist_id.dart';
import 'package:playlist_manager/playlist_manager.dart';

import 'package:namida/class/video.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/youtube/class/youtube_id.dart';

typedef YoutubePlaylist = GeneralPlaylist<YoutubeID>;

class YoutubePlaylistController extends PlaylistManager<YoutubeID, String> {
  static YoutubePlaylistController get inst => _instance;
  static final YoutubePlaylistController _instance = YoutubePlaylistController._internal();
  YoutubePlaylistController._internal();

  @override
  String identifyBy(YoutubeID item) => item.id;

  final canReorderVideos = false.obs;
  void resetCanReorder() => canReorderVideos.value = false;

  void addNewPlaylist(
    String name, {
    Iterable<String>? videoIds,
    int? creationDate,
    String comment = '',
    List<String> moods = const [],
    PlaylistID? playlistID,
  }) async {
    final videoIdsList = videoIds?.toList() ?? [];
    super.addNewPlaylistRaw(
      name,
      tracks: videoIdsList,
      convertItem: (id, dateAdded, playlistID) {
        return YoutubeID(
          id: id,
          watchNull: YTWatch(dateMSNull: dateAdded, isYTMusic: false),
          playlistID: playlistID,
        );
      },
      creationDate: creationDate,
      comment: comment,
      moods: moods,
      playlistID: playlistID,
      actionIfAlreadyExists: () => NamidaOnTaps.inst.showDuplicatedDialogAction(PlaylistAddDuplicateAction.valuesForAdd),
    );
  }

  Future<void> addTracksToPlaylist(YoutubePlaylist playlist, Iterable<String> videoIds) async {
    final originalModifyDate = playlist.modifiedDate;
    final oldVideosList = List<YoutubeID>.from(playlist.tracks); // for undo

    final videoIdsList = videoIds.toList();
    final addedVideosLength = await super.addTracksToPlaylistRaw(
      playlist,
      videoIdsList,
      () => NamidaOnTaps.inst.showDuplicatedDialogAction(PlaylistAddDuplicateAction.valuesForAdd),
      (id, dateAdded) {
        return YoutubeID(
          id: id,
          watchNull: YTWatch(dateMSNull: dateAdded, isYTMusic: false),
          playlistID: playlist.playlistID,
        );
      },
    );

    if (addedVideosLength == null) return;

    snackyy(
      message: "${lang.ADDED} ${addedVideosLength.displayVideoKeyword}",
      button: addedVideosLength > 0
          ? (
              lang.UNDO,
              () async => await updatePropertyInPlaylist(playlist.name, tracks: oldVideosList, modifiedDate: originalModifyDate),
            )
          : null,
    );
  }

  bool favouriteButtonOnPressed(String videoId, {bool refreshNotification = true}) {
    final res = super.toggleTrackFavourite(
      YoutubeID(
        id: videoId,
        watchNull: YTWatch(dateMSNull: DateTime.now().millisecondsSinceEpoch, isYTMusic: false),
        playlistID: favouritesPlaylist.value.playlistID,
      ),
    );
    if (refreshNotification) {
      final currentItem = Player.inst.currentItem.value;
      if (currentItem is YoutubeID && currentItem.id == videoId) {
        Player.inst.refreshNotification();
      }
    }
    return res;
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

    playlistsMap.assignAllEntries(playlistList);

    settings.save(ytPlaylistSort: sortBy, ytPlaylistSortReversed: reverse);
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
    // -- note: popping page is managed internally inside [YTNormalPlaylistSubpage]
    return true;
  }

  @override
  void onPlaylistRemovedFromMap(YoutubePlaylist playlist) {
    // -- the ui uses the playlist map directly. this can be used to remove from other lists if required.
  }

  @override
  Map<String, dynamic> itemToJson(YoutubeID item) => item.toJson();

  @override
  String get favouritePlaylistPath => AppPaths.YT_LIKES_PLAYLIST;

  @override
  String get playlistsDirectory => AppDirs.YT_PLAYLISTS;

  @override
  String get playlistsArtworksDirectory => AppDirs.YT_PLAYLISTS_ARTWORKS;

  @override
  Future<Map<String, YoutubePlaylist>> prepareAllPlaylistsFunction() async {
    return await _readPlaylistFilesCompute.thready(playlistsDirectory);
  }

  @override
  Future<YoutubePlaylist?> prepareFavouritePlaylistFunction() {
    return _prepareFavouritesFile.thready(favouritePlaylistPath);
  }

  static YoutubePlaylist? _prepareFavouritesFile(String path) {
    try {
      final response = File(path).readAsJsonSync();
      return YoutubePlaylist.fromJson(response, (itemJson) => YoutubeID.fromJson(itemJson));
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, YoutubePlaylist>> _readPlaylistFilesCompute(String path) async {
    final map = <String, YoutubePlaylist>{};
    final files = Directory(path).listSyncSafe();
    final filesL = files.length;
    for (int i = 0; i < filesL; i++) {
      var f = files[i];
      if (f is File) {
        try {
          final response = f.readAsJsonSync();
          final pl = YoutubePlaylist.fromJson(response, (itemJson) => YoutubeID.fromJson(itemJson));
          map[pl.name] = pl;
        } catch (_) {}
      }
    }
    return map;
  }

  @override
  void sortPlaylists() => sortYTPlaylists();
}
