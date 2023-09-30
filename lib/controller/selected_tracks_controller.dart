import 'dart:io';

import 'package:get/get.dart';

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

  List<Selectable> get selectedTracks => _tracksOrTwdList;

  final selectedPlaylistsNames = <Track, String>{};

  final _tracksOrTwdList = <Selectable>[].obs;
  final _allTracksHashCodes = <Track, bool>{}.obs;

  List<Selectable> get currentAllTracks {
    if (MiniPlayerController.inst.isInQueue) {
      return Player.inst.currentQueue;
    } else if (ScrollSearchController.inst.isGlobalSearchMenuShown.value) {
      return SearchSortController.inst.trackSearchTemp;
    }

    return NamidaNavigator.inst.currentRoute?.tracksInside ?? [];
  }

  final RxBool isMenuMinimized = true.obs;
  final RxBool isExpanded = false.obs;

  final RxBool didInsertTracks = false.obs;

  final RxDouble bottomPadding = 0.0.obs;

  // bool isTrackSelected(Selectable twd) => _tracksOrTwdList.contains(twd);
  bool isTrackSelected(Selectable twd) => _allTracksHashCodes[twd.track] != null;

  void selectOrUnselect(Selectable track, QueueSource queueSource, String? playlistName) {
    playlistName ??= '';
    final rawTrack = track.track;
    final didRemove = _allTracksHashCodes.remove(rawTrack) ?? false;
    if (didRemove) {
      _tracksOrTwdList.remove(track);
      selectedPlaylistsNames.remove(track);
    } else {
      _tracksOrTwdList.add(track);
      _allTracksHashCodes[rawTrack] = true;
      selectedPlaylistsNames[track.track] = playlistName;
    }

    bottomPadding.value = _tracksOrTwdList.isEmpty ? 0.0 : 102.0;
  }

  void reorderTracks(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = _tracksOrTwdList.removeAt(oldIndex);

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
    final tracks = currentAllTracks;
    _tracksOrTwdList.addAll(tracks);
    _tracksOrTwdList.removeDuplicates((element) => element.track);
    tracks.loop((e, index) => _allTracksHashCodes[e.track] = true);

    // -- Adding playlist name if the current route is referring to a playlist
    final cr = NamidaNavigator.inst.currentRoute;
    if (cr?.route != null) {
      if (cr!.route == RouteType.SUBPAGE_playlistTracks || cr.route == RouteType.SUBPAGE_historyTracks) {
        cr.tracksInside.loop((e, index) {
          selectedPlaylistsNames[e.track] = cr.name;
        });
      }
    }
    // ----------
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
    _tracksOrTwdList.loop((e, index) {
      _allTracksHashCodes[e.track] = true;
    });
  }
}
