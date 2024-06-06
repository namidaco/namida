// ignore_for_file: avoid_rx_value_getter_outside_obx
import 'dart:io';

import 'package:namida/class/route.dart';
import 'package:namida/core/utils.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';

class SelectedTracksController {
  static SelectedTracksController get inst => _instance;
  static final SelectedTracksController _instance = SelectedTracksController._internal();
  SelectedTracksController._internal();

  RxBaseCore<List<Selectable>> get selectedTracks => _tracksOrTwdList;

  final selectedPlaylistsNames = <Track, String>{};

  final _tracksOrTwdList = <Selectable>[].obs;
  final _allTracksHashCodes = <Track, bool>{}.obs;

  Iterable<Selectable> getCurrentAllTracks() {
    if (MiniPlayerController.inst.isInQueue) {
      return Player.inst.currentQueue.value.mapAs<Selectable>();
    } else if (ScrollSearchController.inst.isGlobalSearchMenuShown.value) {
      return SearchSortController.inst.trackSearchTemp.value;
    }

    return NamidaNavigator.inst.currentRoute?.tracksInside() ?? [];
  }

  final isMenuMinimized = true.obs;
  final isExpanded = false.obs;

  final didInsertTracks = false.obs;

  final bottomPadding = 0.0.obs;

  // bool isTrackSelected(Selectable twd) => _tracksOrTwdList.contains(twd);
  bool isTrackSelected(Selectable twd) => _allTracksHashCodes[twd.track] != null;

  void selectOrUnselect(Selectable track, QueueSource queueSource, String? playlistName) {
    playlistName ??= '';
    final rawTrack = track.track;
    if (isTrackSelected(track)) {
      _allTracksHashCodes.remove(rawTrack);
      final indexInList = _tracksOrTwdList.value.indexWhere((element) => element.track == rawTrack);
      if (indexInList != -1) _tracksOrTwdList.removeAt(indexInList);
      selectedPlaylistsNames.remove(rawTrack);
    } else {
      _allTracksHashCodes[rawTrack] = true;
      _tracksOrTwdList.add(track);
      selectedPlaylistsNames[rawTrack] = playlistName;
    }

    bottomPadding.value = _tracksOrTwdList.isEmpty ? 0.0 : 102.0;
  }

  void reorderTracks(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;

    final item = _tracksOrTwdList.value.removeAt(oldIndex);
    _tracksOrTwdList.insertSafe(newIndex, item);
  }

  void removeTrack(int index) {
    final removed = _tracksOrTwdList.removeAt(index);
    _allTracksHashCodes.remove(removed.track);
  }

  void clearEverything() {
    _tracksOrTwdList.clear();
    _allTracksHashCodes.clear();
    selectedPlaylistsNames.clear();
    isMenuMinimized.value = true;
    didInsertTracks.value = false;
    bottomPadding.value = 0.0;
  }

  void selectAllTracks() {
    List<Selectable>? tracks;
    NamidaRoute? routeTracks; // if the tracks are obtained from route
    if (MiniPlayerController.inst.isInQueue) {
      tracks = Player.inst.currentQueue.value.mapAs<Selectable>().toList();
    } else if (ScrollSearchController.inst.isGlobalSearchMenuShown.value) {
      tracks = SearchSortController.inst.trackSearchTemp.value;
    } else {
      final currentRoute = NamidaNavigator.inst.currentRoute;
      tracks = currentRoute?.tracksListInside();
      routeTracks = currentRoute;
    }

    if (tracks == null || tracks.isEmpty) return;

    String? playlistNameToAdd;

    // -- Adding playlist name if the current route is referring to a playlist
    final cr = routeTracks;
    if (cr != null) {
      if (cr.route == RouteType.SUBPAGE_playlistTracks || cr.route == RouteType.SUBPAGE_historyTracks) {
        playlistNameToAdd = cr.name;
      }
    }
    // ----------

    final pln = playlistNameToAdd;
    final hashMap = _allTracksHashCodes.value;
    final trMainList = _tracksOrTwdList.value;
    if (pln != null && pln != '') {
      tracks.loop((twd) {
        final tr = twd.track;
        if (hashMap[tr] != true) {
          trMainList.add(twd);
          hashMap[tr] = true;
          selectedPlaylistsNames[tr] = pln; // <-- difference here
        }
      });
    } else {
      tracks.loop((twd) {
        final tr = twd.track;
        if (hashMap[tr] != true) {
          trMainList.add(twd);
          hashMap[tr] = true;
        }
      });
    }

    _allTracksHashCodes.refresh();
    _tracksOrTwdList.refresh();
  }

  void replaceThisTrack(Track oldTrack, Track newTrack) {
    _tracksOrTwdList.replaceItem(oldTrack, newTrack);
    _allTracksHashCodes.remove(oldTrack);
    _allTracksHashCodes[newTrack] = true;
  }

  void replaceTrackDirectory(String oldDir, String newDir, {Iterable<String>? forThesePathsOnly, bool ensureNewFileExists = false}) {
    String getNewPath(String old) => old.replaceFirst(oldDir, newDir);

    _tracksOrTwdList.replaceWhere(
      (e) {
        final trackPath = e.track.path;
        if (ensureNewFileExists) {
          if (!File(getNewPath(trackPath)).existsSync()) return false;
        }
        final firstC = forThesePathsOnly != null ? forThesePathsOnly.contains(e.track.path) : true;
        final secondC = trackPath.startsWith(oldDir);
        return firstC && secondC;
      },
      (old) {
        final newtr = Track(getNewPath(old.track.path));
        if (old is TrackWithDate) {
          return TrackWithDate(
            dateAdded: old.dateAdded,
            track: newtr,
            source: old.source,
          );
        } else {
          return newtr;
        }
      },
    );
    _allTracksHashCodes.clear();
    _tracksOrTwdList.value.loop((e) {
      _allTracksHashCodes[e.track] = true;
    });
  }
}
