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
import 'package:namida/youtube/class/download_task_base.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';

typedef YoutubePlaylist = GeneralPlaylist<YoutubeID, YTSortType>;

class YoutubePlaylistController extends PlaylistManager<YoutubeID, String, YTSortType> {
  static YoutubePlaylistController get inst => _instance;
  static final YoutubePlaylistController _instance = YoutubePlaylistController._internal();
  YoutubePlaylistController._internal();

  @override
  RegExp get cleanupFilenameRegex => DownloadTaskFilename.cleanupFilenameRegex;

  @override
  String identifyBy(YoutubeID item) => item.id;

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

  Future<void> addTracksToPlaylist(
    YoutubePlaylist playlist,
    Iterable<String> videoIds, {
    List<PlaylistAddDuplicateAction> duplicationActions = PlaylistAddDuplicateAction.valuesForAdd,
  }) async {
    final originalModifyDate = playlist.modifiedDate;
    final oldVideosList = List<YoutubeID>.from(playlist.tracks); // for undo

    final videoIdsList = videoIds.toList();
    final addedVideosLength = await super.addTracksToPlaylistRaw(
      playlist,
      videoIdsList,
      () => NamidaOnTaps.inst.showDuplicatedDialogAction(duplicationActions),
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
    _performSortYTPlaylists(playlistList, sortBy: sortBy, reverse: reverse, customIndicesOrder: customIndicesOrderRx.value);
    playlistsMap.assignAllEntries(playlistList);

    settings.save(ytPlaylistSort: sortBy, ytPlaylistSortReversed: reverse);
  }

  static void _performSortYTPlaylists(List<MapEntry<String, YoutubePlaylist>> playlistList,
      {required GroupSortType sortBy, required bool reverse, required List<String>? customIndicesOrder}) {
    void sortThis(Comparable Function(MapEntry<String, YoutubePlaylist> p) comparable) => reverse ? playlistList.sortByReverse(comparable) : playlistList.sortBy(comparable);

    if (sortBy == GroupSortType.custom && customIndicesOrder == null) {
      sortBy = GroupSortType.title;
    }

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
        sortThis((p) => -p.value.tracks.length);
        break;
      case GroupSortType.playCount:
        sortThis((e) => -e.value.tracks.getTotalListenCount());
        break;
      case GroupSortType.firstListen:
        sortThis((e) => e.value.tracks.getFirstListen() ?? DateTime(99999).millisecondsSinceEpoch);
        break;
      case GroupSortType.latestPlayed:
        sortThis((e) => -(e.value.tracks.getLatestListen() ?? 0));
        break;
      case GroupSortType.shuffle:
        playlistList.shuffle();
        break;
      case GroupSortType.custom:
        final indices = <String, int>{};
        for (int i = 0; i < customIndicesOrder!.length; i++) {
          indices[customIndicesOrder[i]] = i;
        }
        sortThis((p) => indices[p.key] ?? (playlistList.length - 1));
        break;

      default:
        null;
    }
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
  void onPlaylistRemovedFromMap(List<String> names) {
    // -- the ui uses the playlist map directly. this can be used to remove from other lists if required.
  }

  @override
  Map<String, dynamic> itemToJson(YoutubeID item) => item.toJson();

  @override
  dynamic sortToJson(List<YTSortType> items) => items.map((e) => e.name).toList();

  @override
  String get favouritePlaylistPath => AppPaths.YT_LIKES_PLAYLIST;

  @override
  String get playlistsDirectory => AppDirs.YT_PLAYLISTS;

  @override
  String get playlistsArtworksDirectory => AppDirs.YT_PLAYLISTS_ARTWORKS;

  @override
  String get playlistsMetadataDirectory => AppDirs.YT_PLAYLISTS_METADATA;

  @override
  bool get sortAfterPreparing => false;

  @override
  bool get addTracksAtBeginning => settings.playlistAddTracksAtBeginningYT.value;

  @override
  Future<Map<String, YoutubePlaylist>> prepareAllPlaylistsFunction() async {
    final params = _ReadPlaylistFilesParams(
      path: playlistsDirectory,
      sortBy: settings.ytPlaylistSort.value,
      reverse: settings.ytPlaylistSortReversed.value,
      customIndicesOrder: customIndicesOrderRx.value,
    );

    return await _readPlaylistFilesCompute.thready(params);
  }

  @override
  Future<YoutubePlaylist?> prepareFavouritePlaylistFunction() {
    return _prepareFavouritesFile.thready(favouritePlaylistPath);
  }

  static YoutubePlaylist? _prepareFavouritesFile(String path) {
    try {
      final response = File(path).readAsJsonSync();
      return YoutubePlaylist.fromJson(response, (itemJson) => YoutubeID.fromJson(itemJson), _sortFromJson);
    } catch (_) {
      return null;
    }
  }

  static Map<String, YoutubePlaylist> _readPlaylistFilesCompute(_ReadPlaylistFilesParams params) {
    final entries = <MapEntry<String, YoutubePlaylist>>[];
    final files = Directory(params.path).listSyncSafe();
    final filesL = files.length;
    for (int i = 0; i < filesL; i++) {
      var f = files[i];
      if (f is File) {
        try {
          final response = f.readAsJsonSync(ensureExists: false);
          final pl = YoutubePlaylist.fromJson(response, (itemJson) => YoutubeID.fromJson(itemJson), _sortFromJson);
          entries.add(MapEntry(pl.name, pl));
        } catch (_) {}
      }
    }

    _performSortYTPlaylists(entries, sortBy: params.sortBy, reverse: params.reverse, customIndicesOrder: params.customIndicesOrder);
    return Map<String, YoutubePlaylist>.fromEntries(entries);
  }

  @override
  void sortPlaylists() => sortYTPlaylists();

  static List<YTSortType>? _sortFromJson(dynamic value) {
    try {
      return (value as List).map((e) => YTSortType.values.getEnum(e)!).toList();
    } catch (_) {}
    return null;
  }

  @override
  Future<void> onPlaylistItemsSort(List<YTSortType> sorts, bool reverse, List<YoutubeID> items) async {
    await _ensureItemsHasDataForSorting(sorts, items);
    final comparables = <Comparable<dynamic> Function(YoutubeID vid)>[];
    for (final s in sorts) {
      final comparable = _mediaTracksSortingComparables(s);
      if (comparable != null) comparables.add(comparable);
    }

    if (reverse) {
      items.sortByReverseAlts(comparables);
    } else {
      items.sortByAlts(comparables);
    }
  }

  String Function(YoutubePlaylist playlist)? getGroupSortExtraTextResolverPlaylist(GroupSortType sort) => switch (sort) {
        GroupSortType.title => (playlist) => playlist.name,
        GroupSortType.creationDate => (playlist) => playlist.creationDate.dateFormatted,
        GroupSortType.modifiedDate => (playlist) => playlist.modifiedDate.dateFormatted,
        GroupSortType.numberOfTracks => (p) => p.tracks.length.toString(),
        GroupSortType.playCount => (p) => p.tracks.getTotalListenCount().toString(),
        GroupSortType.firstListen => (p) => p.tracks.getFirstListen()?.dateFormattedOriginal ?? '',
        GroupSortType.latestPlayed => (p) => p.tracks.getLatestListen()?.dateFormattedOriginal ?? '',
        GroupSortType.duration => null,
        GroupSortType.shuffle => null,
        GroupSortType.custom => null,

        // -- local tracks
        GroupSortType.album => null,
        GroupSortType.artistsList => null,
        GroupSortType.composer => null,
        GroupSortType.albumArtist => null,
        GroupSortType.label => null,
        GroupSortType.genresList => null,
        GroupSortType.albumsCount => null,
        GroupSortType.year => null,
        GroupSortType.dateModified => null,
        // ----
      };

  Future<void> _ensureItemsHasDataForSorting(List<YTSortType> sorts, List<YoutubeID> items) async {
    if (sorts.contains(YTSortType.title)) await Future.wait(items.map((e) => YoutubeInfoController.utils.getVideoName(e.id)));
    if (sorts.contains(YTSortType.channelTitle)) await Future.wait(items.map((e) => YoutubeInfoController.utils.getVideoChannelName(e.id)));
    if (sorts.contains(YTSortType.duration)) await Future.wait(items.map((e) => YoutubeInfoController.utils.getVideoDurationSeconds(e.id)));
    if (sorts.contains(YTSortType.date)) await Future.wait(items.map((e) => YoutubeInfoController.utils.getVideoReleaseDate(e.id)));
  }

  Comparable Function(YoutubeID e)? _mediaTracksSortingComparables(YTSortType type) {
    return switch (type) {
      YTSortType.title => (e) => YoutubeInfoController.utils.getVideoNameSync(e.id, checkFromStorage: false) ?? '',
      YTSortType.channelTitle => (e) => YoutubeInfoController.utils.getVideoChannelNameSync(e.id, checkFromStorage: false) ?? '',
      YTSortType.duration => (e) => YoutubeInfoController.utils.getVideoDurationSecondsSyncTemp(e.id) ?? 0,
      YTSortType.date => (e) => YoutubeInfoController.utils.getVideoReleaseDateSyncTemp(e.id) ?? DateTime(0),
      YTSortType.dateAdded => (e) => e.dateAddedMS,
      YTSortType.shuffle => null,
      YTSortType.mostPlayed => (e) => YoutubeHistoryController.inst.topTracksMapListens.value[e.id]?.length ?? 0,
      YTSortType.latestPlayed => (e) => YoutubeHistoryController.inst.topTracksMapListens.value[e.id]?.lastOrNull ?? 0,
      YTSortType.firstListen => (e) => YoutubeHistoryController.inst.topTracksMapListens.value[e.id]?.firstOrNull ?? 0,
    };
  }
}

class _ReadPlaylistFilesParams {
  final String path;
  final GroupSortType sortBy;
  final bool reverse;
  final List<String>? customIndicesOrder;

  const _ReadPlaylistFilesParams({
    required this.path,
    required this.sortBy,
    required this.reverse,
    required this.customIndicesOrder,
  });
}
