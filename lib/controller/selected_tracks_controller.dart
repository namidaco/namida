// ignore_for_file: avoid_rx_value_getter_outside_obx
import 'package:namida/base/tracks_search_widget_mixin.dart';
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
import 'package:namida/core/functions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/utils.dart';

class SelectedTracksController {
  static SelectedTracksController get inst => _instance;
  static final SelectedTracksController _instance = SelectedTracksController._internal();
  SelectedTracksController._internal();

  RxBaseCore<List<Selectable>> get selectedTracks => _tracksOrTwdList;
  RxBaseCore<Map<Track, bool>> get existingTracksMap => _allTracksHashCodes;

  final selectedPlaylistsNames = <Track, String>{};

  QueueSourceBase? _selectionSource;
  bool _hasMixedSelectionSources = false;

  bool get isSelectedFromPlayerQueue => !_hasMixedSelectionSources && _selectionSource == QueueSource.playerQueue;

  void _onSelectingFrom(QueueSourceBase? source) {
    if (_tracksOrTwdList.value.isEmpty) {
      _selectionSource = source;
      _hasMixedSelectionSources = false;
    } else if (source != _selectionSource) {
      _hasMixedSelectionSources = true;
    }
  }

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

  void selectOrUnselect(Selectable track, QueueSourceBase source, String? playlistName) {
    final rawTrack = track.track;
    if (isTrackSelected(track)) {
      _allTracksHashCodes.remove(rawTrack);
      final indexInList = _tracksOrTwdList.value.indexWhere((element) => element.track == rawTrack);
      if (indexInList != -1) _tracksOrTwdList.removeAt(indexInList);
      selectedPlaylistsNames.remove(rawTrack);
    } else {
      _onSelectingFrom(source);
      _allTracksHashCodes[rawTrack] = true;
      _tracksOrTwdList.add(track);
      selectedPlaylistsNames[rawTrack] = playlistName ?? '';
    }

    bottomPadding.value = _tracksOrTwdList.isEmpty ? 0.0 : 102.0;
  }

  /// ranges up to the nearest selected item above, or down to the nearest one below when none is above.
  /// [index] points into [tracks], and [rangeOrder] is their shown order when it's not the list order.
  void selectOrUnselectRanged(Selectable track, int index, List<Playable> tracks, SelectionRangeOrder? rangeOrder, QueueSourceBase source, String? playlistName) {
    final isSelected = isTrackSelected(track);
    final hasSelection = _tracksOrTwdList.value.isNotEmpty;
    if (isSelected || !hasSelection) return selectOrUnselect(track, source, playlistName);

    final order = rangeOrder ?? const _ListRangeOrder();
    final hashMap = _allTracksHashCodes.value;
    final distanceAbove = _distanceToSelected(order.itemsAbove(tracks, index), hashMap);
    final distanceBelow = distanceAbove == -1 ? _distanceToSelected(order.itemsBelow(tracks, index), hashMap) : -1;
    if (distanceAbove == -1 && distanceBelow == -1) return selectOrUnselect(track, source, playlistName);

    _onSelectingFrom(source);
    final pln = playlistName ?? '';
    final trMainList = _tracksOrTwdList.value;
    void addItem(Playable item) {
      if (item is! Selectable) return;
      final tr = item.track;
      if (hashMap[tr] != null) return;
      trMainList.add(item);
      hashMap[tr] = true;
      selectedPlaylistsNames[tr] = pln;
    }

    if (distanceAbove != -1) {
      final itemsAbove = order.itemsAbove(tracks, index).take(distanceAbove).toFixedList();
      for (int i = itemsAbove.length - 1; i >= 0; i--) {
        addItem(itemsAbove[i]);
      }
      addItem(track);
    } else {
      addItem(track);
      final itemsBelow = order.itemsBelow(tracks, index).take(distanceBelow);
      for (final item in itemsBelow) {
        addItem(item);
      }
    }

    _allTracksHashCodes.refresh();
    _tracksOrTwdList.refresh();
  }

  /// items before the nearest selected one, -1 when none is selected.
  static int _distanceToSelected(Iterable<Playable> items, Map<Track, bool> hashMap) {
    int distance = 0;
    for (final item in items) {
      if (item is Selectable && hashMap[item.track] != null) return distance;
      distance++;
    }
    return -1;
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
    _selectionSource = null;
    _hasMixedSelectionSources = false;
    _tracksOrTwdList.clear();
    _allTracksHashCodes.clear();
    selectedPlaylistsNames.clear();
    isMenuMinimized.value = true;
    didInsertTracks.value = false;
    bottomPadding.value = 0.0;
  }

  (List<Selectable>?, QueueSourceBase?, NamidaRoute?) _getCurrentActiveTracksList() {
    if (MiniPlayerController.inst.isInQueue && !Dimensions.inst.miniplayerIsWideScreen) {
      final queue = Player.inst.currentQueue.value;
      final searchResults = MiniPlayerController.inst.queueSearch.results.value;
      final shownQueue = searchResults == null ? queue : searchResults.map((i) => queue[i]);
      final tracks = shownQueue.whereType<Selectable>().toFixedList();
      return (tracks, QueueSource.playerQueue, null);
    }

    if (ScrollSearchController.inst.isGlobalSearchMenuShown.value) {
      return (SearchSortController.inst.trackSearchTemp.value, QueueSource.search, null);
    }

    final currentRoute = this._currentRoute;
    if (currentRoute == null) return (null, null, null);
    final filteredTracks = TracksSearchWidgetMixin.filteredTracksOfRoute(currentRoute);
    final tracks = filteredTracks?.toFixedList() ?? currentRoute.tracksListInside();
    return (tracks, currentRoute.toQueueSource(), currentRoute);
  }

  void selectAllTracks({(int, int)? range}) {
    final currentInfo = _getCurrentActiveTracksList();
    final tracks = currentInfo.$1;
    final routeTracks = currentInfo.$3;

    if (tracks == null || tracks.isEmpty) return;

    String? playlistNameToAdd;

    // -- Adding playlist name if the current route is referring to a playlist
    final cr = routeTracks;
    if (cr != null) {
      if (cr.route == RouteType.SUBPAGE_playlistTracks || cr.route == RouteType.SUBPAGE_favPlaylistTracks || cr.route == RouteType.SUBPAGE_historyTracks) {
        playlistNameToAdd = cr.name;
      }
    }
    // ----------

    _onSelectingFrom(currentInfo.$2);
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
      for (var twd in finalTracks) {
        final tr = twd.track;
        if (hashMap[tr] == null) {
          trMainList.add(twd);
          hashMap[tr] = true;
          selectedPlaylistsNames[tr] = pln; // <-- difference here
        }
      }
    } else {
      for (var twd in finalTracks) {
        final tr = twd.track;
        if (hashMap[tr] == null) {
          trMainList.add(twd);
          hashMap[tr] = true;
        }
      }
    }

    _allTracksHashCodes.refresh();
    _tracksOrTwdList.refresh();
  }

  void replaceThisTrack(Track oldTrack, Track newTrack) {
    _tracksOrTwdList.replaceItem(oldTrack, newTrack);
    _allTracksHashCodes.remove(oldTrack);
    _allTracksHashCodes[newTrack] = true;
  }

  void replaceTrackDirectory(String normalizedOldDir, String normalizedNewDir, {Iterable<String>? forThesePathsOnly, bool ensureNewFileExists = false}) {
    final pathsOnlySet = forThesePathsOnly?.toSet();
    final existenceCache = <String, bool>{};
    _tracksOrTwdList.replaceWhere(
      (e) {
        final tr = e.track;
        return replaceFunctionForUpdatedPaths(
          tr.path,
          normalizedOldDir,
          normalizedNewDir,
          pathsOnlySet,
          ensureNewFileExists,
          existenceCache,
        );
      },
      (old) {
        final newtr = Track.fromTypeParameter(old.track.runtimeType, replaceFunctionGetNewPath(old.track.path, normalizedOldDir, normalizedNewDir));
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
    // for (var e in _tracksOrTwdList.value) {
    //   _allTracksHashCodes[e.track] = true;
    // }
  }
}

// by claude
abstract class SelectionRangeOrder {
  const SelectionRangeOrder();

  /// shown items above [index] of [tracks], nearest first.
  Iterable<Playable> itemsAbove(List<Playable> tracks, int index);

  /// shown items below [index] of [tracks], nearest first.
  Iterable<Playable> itemsBelow(List<Playable> tracks, int index);
}

class FilteredRangeOrder extends SelectionRangeOrder {
  final List<int> shownIndices;

  const FilteredRangeOrder(this.shownIndices);

  @override
  Iterable<Playable> itemsAbove(List<Playable> tracks, int index) sync* {
    final position = shownIndices.indexOf(index);
    for (int p = position - 1; p >= 0; p--) {
      final i = shownIndices[p];
      yield tracks[i];
    }
  }

  @override
  Iterable<Playable> itemsBelow(List<Playable> tracks, int index) sync* {
    final position = shownIndices.indexOf(index);
    if (position == -1) return;
    for (int p = position + 1; p < shownIndices.length; p++) {
      final i = shownIndices[p];
      yield tracks[i];
    }
  }
}

/// for lists split into consecutive sections, each tile list being one section (ex: history days).
class SectionedRangeOrder extends SelectionRangeOrder {
  final int sectionPosition;
  final int sectionsCount;
  final List<Playable>? Function(int sectionPosition) sectionAt;

  const SectionedRangeOrder(this.sectionPosition, this.sectionsCount, this.sectionAt);

  @override
  Iterable<Playable> itemsAbove(List<Playable> tracks, int index) sync* {
    yield* const _ListRangeOrder().itemsAbove(tracks, index);
    for (int s = sectionPosition - 1; s >= 0; s--) {
      final section = sectionAt(s);
      if (section == null) continue;
      for (int i = section.length - 1; i >= 0; i--) {
        yield section[i];
      }
    }
  }

  @override
  Iterable<Playable> itemsBelow(List<Playable> tracks, int index) sync* {
    yield* const _ListRangeOrder().itemsBelow(tracks, index);
    for (int s = sectionPosition + 1; s < sectionsCount; s++) {
      final section = sectionAt(s);
      if (section == null) continue;
      yield* section;
    }
  }
}

class _ListRangeOrder extends SelectionRangeOrder {
  const _ListRangeOrder();

  @override
  Iterable<Playable> itemsAbove(List<Playable> tracks, int index) sync* {
    for (int i = index - 1; i >= 0; i--) {
      yield tracks[i];
    }
  }

  @override
  Iterable<Playable> itemsBelow(List<Playable> tracks, int index) => tracks.skip(index + 1);
}
