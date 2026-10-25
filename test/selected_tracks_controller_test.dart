// by claude
import 'package:flutter_test/flutter_test.dart';

import 'package:namida/base/queue_search.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/selected_tracks_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/youtube/class/youtube_id.dart';

void main() {
  final controller = SelectedTracksController.inst;

  setUp(controller.clearEverything);

  Track track(String name) => Track.explicit('/music/$name.mp3');
  List<Track> list(String prefix, int count) => List.generate(count, (i) => track('$prefix$i'));
  YoutubeID video(String id) => YoutubeID(id: id, playlistID: null);

  List<String> selectedNames() => controller.selectedTracks.value.map((e) => e.track.path.getFilenameWOExt).toList();

  void select(List<Playable> tracks, int index, {QueueSourceBase source = QueueSource.allTracksAll, String? playlistName}) {
    controller.selectOrUnselect(tracks[index] as Selectable, source, playlistName);
  }

  void selectRanged(List<Playable> tracks, int index, {SelectionRangeOrder? rangeOrder, QueueSourceBase source = QueueSource.allTracksAll, String? playlistName}) {
    controller.selectOrUnselectRanged(tracks[index] as Selectable, index, tracks, rangeOrder, source, playlistName);
  }

  group('plain list', () {
    test('selects from the nearest selected item above', () {
      final tracks = list('t', 10);
      select(tracks, 2);
      selectRanged(tracks, 5);
      expect(selectedNames(), ['t2', 't3', 't4', 't5']);
    });

    test('anchors to the nearest selected, not the first', () {
      final tracks = list('t', 10);
      select(tracks, 1);
      select(tracks, 6);
      selectRanged(tracks, 8);
      expect(selectedNames(), ['t1', 't6', 't7', 't8']);
    });

    test('nothing selected above ranges down to the nearest selected below', () {
      final tracks = list('t', 10);
      select(tracks, 5);
      select(tracks, 8);
      selectRanged(tracks, 2);
      expect(selectedNames(), ['t5', 't8', 't2', 't3', 't4']);
    });

    test('selected above wins over selected below', () {
      final tracks = list('t', 10);
      select(tracks, 1);
      select(tracks, 8);
      selectRanged(tracks, 5);
      expect(selectedNames(), ['t1', 't8', 't2', 't3', 't4', 't5']);
    });

    test('nothing selected above or below selects only the item', () {
      final other = list('o', 3);
      final tracks = list('t', 10);
      select(other, 1);
      selectRanged(tracks, 4);
      expect(selectedNames(), ['o1', 't4']);
    });

    test('empty selection selects only the item', () {
      final tracks = list('t', 10);
      selectRanged(tracks, 4);
      expect(selectedNames(), ['t4']);
    });

    test('ranged on a selected item unselects it', () {
      final tracks = list('t', 10);
      select(tracks, 2);
      select(tracks, 4);
      selectRanged(tracks, 4);
      expect(selectedNames(), ['t2']);
    });

    test('repeated tracks are selected once', () {
      final t0 = track('t0');
      final tracks = [t0, track('t1'), t0, track('t2'), track('t3')];
      select(tracks, 1);
      selectRanged(tracks, 4);
      expect(selectedNames(), ['t1', 't0', 't2', 't3']);
    });
  });

  group('filtered list', () {
    test('range covers only the shown items', () {
      final tracks = list('t', 10);
      final shownIndices = [1, 3, 5, 7, 9];
      select(tracks, 3);
      selectRanged(tracks, 7, rangeOrder: FilteredRangeOrder(shownIndices));
      expect(selectedNames(), ['t3', 't5', 't7']);
    });

    test('range follows the shown order, not the list order', () {
      final tracks = list('q', 10);
      final shownIndices = [8, 2, 5, 0];
      select(tracks, 8, source: QueueSource.playerQueue);
      selectRanged(tracks, 5, rangeOrder: FilteredRangeOrder(shownIndices), source: QueueSource.playerQueue);
      expect(selectedNames(), ['q8', 'q2', 'q5']);
    });

    test('ranges down in the shown order', () {
      final tracks = list('t', 10);
      final shownIndices = [9, 4, 0, 7];
      select(tracks, 7);
      selectRanged(tracks, 9, rangeOrder: FilteredRangeOrder(shownIndices));
      expect(selectedNames(), ['t7', 't9', 't4', 't0']);
    });

    test('hidden selected items are not anchors', () {
      final tracks = list('t', 10);
      final shownIndices = [6, 7, 8];
      select(tracks, 2);
      selectRanged(tracks, 8, rangeOrder: FilteredRangeOrder(shownIndices));
      expect(selectedNames(), ['t2', 't8']);
    });

    test('item missing from the shown indices selects only the item', () {
      final tracks = list('t', 10);
      select(tracks, 1);
      selectRanged(tracks, 4, rangeOrder: const FilteredRangeOrder([1, 2, 3]));
      expect(selectedNames(), ['t1', 't4']);
    });
  });

  test('queue search results are a range order', () {
    final queue = list('q', 10);
    final searchResults = QueueSearchResults([8, 2, 5, 0], (_) {});
    select(queue, 8, source: QueueSource.playerQueue);
    selectRanged(queue, 0, rangeOrder: searchResults, source: QueueSource.playerQueue);
    expect(selectedNames(), ['q8', 'q2', 'q5', 'q0']);
  });

  group('sectioned list (history days)', () {
    final days = [list('d0_', 3), list('d1_', 3), list('d2_', 3)];
    List<Playable>? dayAt(int dayPosition) => days[dayPosition];

    test('range continues into the days above', () {
      select(days[0], 1);
      selectRanged(days[2], 1, rangeOrder: SectionedRangeOrder(2, 3, dayAt));
      expect(selectedNames(), ['d0_1', 'd0_2', 'd1_0', 'd1_1', 'd1_2', 'd2_0', 'd2_1']);
    });

    test('anchor in the same day stays inside it', () {
      select(days[0], 0);
      select(days[2], 0);
      selectRanged(days[2], 2, rangeOrder: SectionedRangeOrder(2, 3, dayAt));
      expect(selectedNames(), ['d0_0', 'd2_0', 'd2_1', 'd2_2']);
    });

    test('ranges down into the days below', () {
      select(days[2], 1);
      selectRanged(days[0], 1, rangeOrder: SectionedRangeOrder(0, 3, dayAt));
      expect(selectedNames(), ['d2_1', 'd0_1', 'd0_2', 'd1_0', 'd1_1', 'd1_2', 'd2_0']);
    });

    test('no selected day above or below selects only the item', () {
      select(list('o', 2), 0);
      selectRanged(days[1], 1, rangeOrder: SectionedRangeOrder(1, 3, dayAt));
      expect(selectedNames(), ['o0', 'd1_1']);
    });

    test('filtered days only cover the shown listens', () {
      final shownDays = [
        [days[0][2]],
        [days[1][0], days[1][2]],
        [days[2][1]],
      ];
      List<Playable>? shownDayAt(int dayPosition) => shownDays[dayPosition];
      select(shownDays[0], 0);
      selectRanged(shownDays[2], 0, rangeOrder: SectionedRangeOrder(2, 3, shownDayAt));
      expect(selectedNames(), ['d0_2', 'd1_0', 'd1_2', 'd2_1']);
    });

    test('repeated listens across days are selected once', () {
      final t = track('t');
      final repeatedDays = [
        [track('a'), t],
        [t, track('b')],
        [track('c')],
      ];
      List<Playable>? repeatedDayAt(int dayPosition) => repeatedDays[dayPosition];
      select(repeatedDays[0], 0);
      selectRanged(repeatedDays[2], 0, rangeOrder: SectionedRangeOrder(2, 3, repeatedDayAt));
      expect(selectedNames(), ['a', 't', 'b', 'c']);
    });
  });

  group('mixed queue', () {
    test('videos are skipped and indices stay the queue ones', () {
      final queue = <Playable>[track('a'), video('v1'), track('b'), video('v2'), track('c'), track('d')];
      select(queue, 0, source: QueueSource.playerQueue);
      selectRanged(queue, 4, source: QueueSource.playerQueue);
      expect(selectedNames(), ['a', 'b', 'c']);
    });

    test('videos are skipped while filtered', () {
      final queue = <Playable>[track('a'), video('v1'), track('b'), track('c')];
      select(queue, 3, source: QueueSource.playerQueue);
      selectRanged(queue, 0, rangeOrder: const FilteredRangeOrder([3, 1, 0]), source: QueueSource.playerQueue);
      expect(selectedNames(), ['c', 'a']);
    });
  });

  group('selection from another list', () {
    test('other list selections are not anchors', () {
      final listA = list('a', 5);
      final listB = list('b', 10);
      select(listA, 1);
      selectRanged(listB, 5);
      expect(selectedNames(), ['a1', 'b5']);
      selectRanged(listB, 8);
      expect(selectedNames(), ['a1', 'b5', 'b6', 'b7', 'b8']);
    });

    test('a track shared with the other list is an anchor', () {
      final listA = list('a', 5);
      final listB = [...list('b', 3), listA[1], ...list('c', 5)];
      select(listA, 1);
      selectRanged(listB, 6);
      expect(selectedNames(), ['a1', 'c0', 'c1', 'c2']);
    });

    test('index of a sub list (history day) points into that sub list', () {
      final day1 = list('d1_', 5);
      final day2 = list('d2_', 5);
      select(day1, 3);
      select(day2, 0);
      selectRanged(day2, 3);
      expect(selectedNames(), ['d1_3', 'd2_0', 'd2_1', 'd2_2', 'd2_3']);
    });

    test('mixed sources are tracked', () {
      final queue = list('q', 5);
      final album = list('a', 5);
      select(queue, 0, source: QueueSource.playerQueue);
      selectRanged(queue, 2, source: QueueSource.playerQueue);
      expect(controller.isSelectedFromPlayerQueue, true);
      select(album, 0);
      selectRanged(album, 3);
      expect(controller.isSelectedFromPlayerQueue, false);
    });
  });

  group('playlist names', () {
    test('range stores the playlist name of each item', () {
      final tracks = list('p', 6);
      select(tracks, 1, playlistName: 'pl');
      selectRanged(tracks, 4, playlistName: 'pl');
      expect(controller.selectedPlaylistsNames.length, 4);
      expect(controller.selectedPlaylistsNames.values.toSet(), {'pl'});
    });

    test('range outside a playlist does not keep the anchor playlist name alone', () {
      final playlist = list('p', 3);
      final album = [playlist[0], ...list('a', 3)];
      select(playlist, 0, playlistName: 'pl');
      selectRanged(album, 3);
      expect(controller.selectedPlaylistsNames.values.toSet(), {'pl', ''});
    });
  });

  test('bottom padding follows the selection', () {
    final tracks = list('t', 5);
    selectRanged(tracks, 2);
    expect(controller.bottomPadding.value, greaterThan(0.0));
    selectRanged(tracks, 2);
    expect(controller.bottomPadding.value, 0.0);
  });
}
