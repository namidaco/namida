// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:playlist_manager/playlist_manager.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/generators_controller.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/language.dart';

typedef Playlist = GeneralPlaylist<TrackWithDate>;

class PlaylistController extends PlaylistManager<TrackWithDate> {
  static PlaylistController get inst => _instance;
  static final PlaylistController _instance = PlaylistController._internal();
  PlaylistController._internal();

  final RxBool canReorderTracks = false.obs;

  void addNewPlaylist(
    String name, {
    List<Track> tracks = const <Track>[],
    int? creationDate,
    String comment = '',
    List<String> moods = const [],
  }) async {
    final newTracks = tracks.mapped((e) => TrackWithDate(
          dateAdded: currentTimeMS,
          track: e,
          source: TrackSource.local,
        ));
    super.addNewPlaylistRaw(
      name,
      tracks: newTracks,
      creationDate: creationDate,
      comment: comment,
      moods: moods,
    );
  }

  void addTracksToPlaylist(Playlist playlist, List<Track> tracks, {TrackSource source = TrackSource.local}) async {
    final newtracks = tracks.mapped((e) => TrackWithDate(
          dateAdded: currentTimeMS,
          track: e,
          source: source,
        ));
    super.addTracksToPlaylistRaw(playlist, newtracks);
  }

  Future<bool> favouriteButtonOnPressed(Track track) async {
    return await super.toggleTrackFavourite(
      newTrack: TrackWithDate(dateAdded: currentTimeMS, track: track, source: TrackSource.local),
      identifyBy: (tr) => tr.track == track,
    );
  }

  Future<void> replaceTracksDirectory(String oldDir, String newDir, {Iterable<String>? forThesePathsOnly, bool ensureNewFileExists = false}) async {
    String getNewPath(String old) => old.replaceFirst(oldDir, newDir);

    await replaceTheseTracksInPlaylists(
      (e) {
        final trackPath = e.track.path;
        if (ensureNewFileExists) {
          if (!File(getNewPath(trackPath)).existsSync()) return false;
        }
        final firstC = forThesePathsOnly != null ? forThesePathsOnly.contains(e.track.path) : true;
        final secondC = trackPath.startsWith(oldDir);
        return firstC && secondC;
      },
      (old) => TrackWithDate(
        dateAdded: old.dateAdded,
        track: Track(getNewPath(old.track.path)),
        source: old.source,
      ),
    );
  }

  Future<void> replaceTrackInAllPlaylists(Track oldTrack, Track newTrack) async {
    await replaceTheseTracksInPlaylists(
      (e) => e.track == oldTrack,
      (old) => TrackWithDate(
        dateAdded: old.dateAdded,
        track: newTrack,
        source: old.source,
      ),
    );
  }

  /// Returns number of generated tracks.
  int generateRandomPlaylist() {
    final rt = NamidaGenerator.inst.getRandomTracks();
    if (rt.isEmpty) return 0;

    final l = playlistsMap.keys.where((name) => name.startsWith(k_PLAYLIST_NAME_AUTO_GENERATED)).length;
    addNewPlaylist('$k_PLAYLIST_NAME_AUTO_GENERATED ${l + 1}', tracks: rt);

    return rt.length;
  }

  Future<void> prepareAllPlaylists() async => await super.prepareAllPlaylistsFile();

  @override
  void sortPlaylists() => SearchSortController.inst.sortMedia(MediaType.playlist);

  @override
  String get playlistsDirectory => AppDirs.PLAYLISTS;

  @override
  String get favouritePlaylistPath => AppPaths.FAVOURITES_PLAYLIST;

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
  Map<String, dynamic> itemToJson(TrackWithDate item) => item.toJson();

  @override
  FutureOr<bool> canRemovePlaylist(GeneralPlaylist<TrackWithDate> playlist) {
    // navigate back in case the current route is this playlist
    final lastPage = NamidaNavigator.inst.currentRoute;
    if (lastPage?.route == RouteType.SUBPAGE_playlistTracks) {
      if (lastPage?.name == playlist.name) {
        NamidaNavigator.inst.popPage();
      }
    }
    return true;
  }

  @override
  Future<Map<String, GeneralPlaylist<TrackWithDate>>> prepareAllPlaylistsFunction() async {
    return await _readPlaylistFilesCompute.thready(playlistsDirectory);
  }

  @override
  Future<GeneralPlaylist<TrackWithDate>?> prepareFavouritePlaylistFunction() async {
    return await _prepareFavouritesFile.thready(favouritePlaylistPath);
  }

  @override
  Future<void> prepareDefaultPlaylistsFile() async {
    HistoryController.inst.prepareHistoryFile();
    await super.prepareDefaultPlaylistsFile();
  }

  static Future<Playlist?> _prepareFavouritesFile(String path) async {
    try {
      final response = File(path).readAsJsonSync();
      return Playlist.fromJson(response, (itemJson) => TrackWithDate.fromJson(itemJson));
    } catch (_) {}
    return null;
  }

  static Future<Map<String, Playlist>> _readPlaylistFilesCompute(String path) async {
    final map = <String, Playlist>{};
    for (final f in Directory(path).listSync()) {
      if (f is File) {
        try {
          final response = f.readAsJsonSync();
          final pl = Playlist.fromJson(response, (itemJson) => TrackWithDate.fromJson(itemJson));
          map[pl.name] = pl;
        } catch (e) {
          continue;
        }
      }
    }
    return map;
  }
}
