import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';

class SelectedTracksController {
  static SelectedTracksController get inst => _instance;
  static final SelectedTracksController _instance = SelectedTracksController._internal();
  SelectedTracksController._internal();

  List<Track> get selectedTracks {
    return _tracksOrTwdList.mapped((t) {
      if (t is TrackWithDate) {
        return t.track;
      }
      return t as Track;
    });
  }

  List<TrackWithDate> get selectedTracksWithDates {
    return _tracksOrTwdList.whereType<TrackWithDate>().toList();
  }

  final Map<Track, String> selectedPlaylistsNames = <Track, String>{};

  final RxList<Object> _tracksOrTwdList = <Object>[].obs;

  List<Track> get currentAllTracks {
    if (ScrollSearchController.inst.isGlobalSearchMenuShown.value) {
      return SearchSortController.inst.trackSearchTemp;
    }

    return NamidaNavigator.inst.currentRoute?.tracksInside ?? [];
  }

  List<TrackWithDate>? get currentAllTracksWithDate {
    return NamidaNavigator.inst.currentRoute?.tracksWithDateInside;
  }

  final RxBool isMenuMinimized = true.obs;
  final RxBool isExpanded = false.obs;

  final RxBool didInsertTracks = false.obs;

  final RxDouble bottomPadding = 0.0.obs;

  bool isTrackSelected(Track tr, TrackWithDate? twd) => _tracksOrTwdList.contains(twd) || _tracksOrTwdList.contains(tr);

  void selectOrUnselect(Track track, QueueSource queueSource, TrackWithDate? twd, String? playlistName) {
    playlistName ??= '';
    final trToAdd = twd ?? track;
    final gonnaRemoveTrack = isTrackSelected(track, twd);
    if (gonnaRemoveTrack) {
      _tracksOrTwdList.remove(trToAdd);
    } else {
      _tracksOrTwdList.add(trToAdd);
    }
    // -- updating playlists

    if (gonnaRemoveTrack) {
      selectedPlaylistsNames.remove(track);
    } else {
      selectedPlaylistsNames[track] = playlistName;
    }
    // -------------

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
    _tracksOrTwdList.removeAt(index);
  }

  void clearEverything() {
    _tracksOrTwdList.clear();
    selectedPlaylistsNames.clear();
    isMenuMinimized.value = true;
    didInsertTracks.value = false;
    bottomPadding.value = 0.0;
  }

  void selectAllTracks() {
    _tracksOrTwdList.addAll(currentAllTracksWithDate ?? currentAllTracks);
    _tracksOrTwdList.removeDuplicates((element) {
      if (element is TrackWithDate) {
        return element.track.path;
      }
      return (element as Track).path;
    });

    // -- Adding playlist name if the current route is referring to a playlist
    final cr = NamidaNavigator.inst.currentRoute;
    if (cr?.route != null) {
      if (cr!.route == RouteType.SUBPAGE_playlistTracks || cr.route == RouteType.SUBPAGE_historyTracks) {
        cr.tracksInside.loop((e, index) {
          selectedPlaylistsNames[e] = cr.name;
        });
      }
    }
    // ----------
  }

  void replaceThisTrack(Track oldTrack, Track newTrack) {
    _tracksOrTwdList.replaceItem(oldTrack, newTrack);
  }
}
