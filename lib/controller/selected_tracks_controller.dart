// ignore_for_file: avoid_rx_value_getter_outside_obx
import 'dart:io';

import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/utils.dart';

class SelectedTracksController {
  static SelectedTracksController get inst => _instance;
  static final SelectedTracksController _instance = SelectedTracksController._internal();
  SelectedTracksController._internal();

  RxBaseCore<List<Selectable>> get selectedTracks => _tracksOrTwdList;
  RxBaseCore<Map<Track, bool>> get existingTracksMap => _allTracksHashCodes;

  final selectedPlaylistsNames = <Track, String>{};

  final _tracksOrTwdList = <Selectable>[].obs;
  final _allTracksHashCodes = <Track, bool>{}.obs;

  NamidaRoute? get _currentRoute => NamidaNavigator.inst.currentRoute;

  Iterable<Selectable> getCurrentAllTracks({bool fallbackToQueue = true}) {
    if (ScrollSearchController.inst.isGlobalSearchMenuShown.value) {
      return SearchSortController.inst.trackSearchTemp.value;
    }

    final tracks = this._currentRoute?.tracksInside();
    if (tracks != null) return tracks;

    if (fallbackToQueue && MiniPlayerController.inst.isInQueue) {
      return Player.inst.currentQueue.value.whereType<Selectable>();
    }

    return [];
  }

  final isMenuMinimized = true.obs;
  final isPressed = false.obs;

  final didInsertTracks = false.obs;

  final bottomPadding = 0.0.obs;

  // bool isTrackSelected(Selectable twd) => _tracksOrTwdList.contains(twd);
  bool isTrackSelected(Selectable twd) => _allTracksHashCodes[twd.track] != null;

  void selectOrUnselect(Selectable track, int index, QueueSource source, String? playlistName, {bool ranged = false}) {
    playlistName ??= '';
    final rawTrack = track.track;
    if (isTrackSelected(track)) {
      _allTracksHashCodes.remove(rawTrack);
      final indexInList = _tracksOrTwdList.value.indexWhere((element) => element.track == rawTrack);
      if (indexInList != -1) _tracksOrTwdList.removeAt(indexInList);
      selectedPlaylistsNames.remove(rawTrack);
    } else {
      void selectSingle() {
        _allTracksHashCodes[rawTrack] = true;
        _tracksOrTwdList.add(track);
        selectedPlaylistsNames[rawTrack] = playlistName!;
      }

      if (ranged && _tracksOrTwdList.value.isNotEmpty) {
        int largestSelectedIndex = -1;
        final currentInfo = _getCurrentActiveTracksList(queueSource: source);
        final tracks = currentInfo.$1 ?? [];
        final queueSource = currentInfo.$2;
        // -- find the largest selected index by reverse looping tracks list and breaking on first match
        final startIndex = index.withMaximum(tracks.length - 1);
        for (int i = startIndex; i >= 0; i--) {
          final tr = tracks[i].track;
          final isSelected = _allTracksHashCodes[tr] != null;
          if (isSelected && i > largestSelectedIndex) {
            largestSelectedIndex = i;
            break;
          }
        }
        if (largestSelectedIndex > -1 && index > largestSelectedIndex) {
          selectAllTracks(range: (largestSelectedIndex, index), source: queueSource);
        } else {
          selectSingle();
        }
      } else {
        selectSingle();
      }
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

  (List<Selectable>?, QueueSource?, NamidaRoute?) _getCurrentActiveTracksList({QueueSource? queueSource}) {
    List<Selectable>? tracks;

    NamidaRoute? routeTracks; // if the tracks are obtained from route
    if (queueSource == QueueSource.playerQueue || (MiniPlayerController.inst.isInQueue && !Dimensions.inst.miniplayerIsWideScreen)) {
      tracks = Player.inst.currentQueue.value.whereType<Selectable>().toList();
      queueSource ??= QueueSource.playerQueue;
    } else if (ScrollSearchController.inst.isGlobalSearchMenuShown.value) {
      tracks = SearchSortController.inst.trackSearchTemp.value;
      queueSource ??= QueueSource.search;
    } else {
      final currentRoute = this._currentRoute;
      tracks = currentRoute?.tracksListInside();
      routeTracks = currentRoute;
      queueSource ??= currentRoute?.toQueueSource();
    }
    queueSource ??= QueueSource.others;
    return (tracks, queueSource, routeTracks);
  }

  void selectAllTracks({(int, int)? range, QueueSource? source}) {
    final currentInfo = _getCurrentActiveTracksList(queueSource: source);
    final tracks = currentInfo.$1;
    final routeTracks = currentInfo.$3;

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
    List<Selectable> finalTracks;
    if (range != null) {
      finalTracks = tracks.sublist(range.$1, range.$2 + 1);
    } else {
      finalTracks = tracks;
    }
    if (pln != null && pln != '') {
      finalTracks.loop((twd) {
        final tr = twd.track;
        if (hashMap[tr] == null) {
          trMainList.add(twd);
          hashMap[tr] = true;
          selectedPlaylistsNames[tr] = pln; // <-- difference here
        }
      });
    } else {
      finalTracks.loop((twd) {
        final tr = twd.track;
        if (hashMap[tr] == null) {
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
        final newtr = Track.fromTypeParameter(old.track.runtimeType, getNewPath(old.track.path));
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
    // -- either dont update stuff, or clear everything
    // _allTracksHashCodes.clear();
    // _tracksOrTwdList.value.loop((e) {
    //   _allTracksHashCodes[e.track] = true;
    // });
  }
}
