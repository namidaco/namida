// by claude
import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/sort_chain.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/core/enums.dart';

void main() {
  group('genres page name sort', () {
    test('each type lists its own name sort first and never the other one', () {
      final genreSorts = GroupSortType.forGenres(MediaType.genre);
      final styleSorts = GroupSortType.forGenres(MediaType.style);
      expect(genreSorts.first, GroupSortType.genresList);
      expect(styleSorts.first, GroupSortType.stylesList);
      expect(genreSorts, isNot(contains(GroupSortType.stylesList)));
      expect(styleSorts, isNot(contains(GroupSortType.genresList)));
    });

    test('switching type swaps the name entry, keeping its direction and the other entries', () {
      const genreSorting = SortChain<GroupSortType>([SortEntry(GroupSortType.genresList, reverse: true), SortEntry(GroupSortType.year)], reverse: true);
      final styleSorting = SearchSortController.withGenresNameSort(MediaType.style, genreSorting);
      expect(styleSorting.entries, const [SortEntry(GroupSortType.stylesList, reverse: true), SortEntry(GroupSortType.year)]);
      expect(styleSorting.reverse, isTrue);

      final backSorting = SearchSortController.withGenresNameSort(MediaType.genre, styleSorting);
      expect(backSorting.entries, genreSorting.entries);
    });

    test('the name entry is swapped wherever it is in the chain', () {
      const sorting = SortChain<GroupSortType>([SortEntry(GroupSortType.numberOfTracks), SortEntry(GroupSortType.genresList)]);
      final styleSorting = SearchSortController.withGenresNameSort(MediaType.style, sorting);
      expect(styleSorting.entries, const [SortEntry(GroupSortType.numberOfTracks), SortEntry(GroupSortType.stylesList)]);
    });

    test('a chain without the other name entry is returned as is', () {
      const sorting = SortChain<GroupSortType>([SortEntry(GroupSortType.duration)]);
      expect(identical(SearchSortController.withGenresNameSort(MediaType.style, sorting), sorting), isTrue);
      expect(identical(SearchSortController.withGenresNameSort(MediaType.genre, sorting), sorting), isTrue);
    });
  });

  group('style and genre sorts', () {
    test('tracks, albums and artists can sort by style, albums by genre too', () {
      expect(SortType.forTracks(), contains(SortType.stylesList));
      expect(GroupSortType.forAlbums(), containsAll(const [GroupSortType.genresList, GroupSortType.stylesList]));
      for (final artistType in const [MediaType.artist, MediaType.albumArtist, MediaType.composer]) {
        expect(GroupSortType.forArtists(artistType), containsAll(const [GroupSortType.genresList, GroupSortType.stylesList]));
      }
    });

    test('saved style sorts load back by name', () {
      expect(SortType.sortListFromJsonList(['-stylesList', 'title']), const [SortEntry(SortType.stylesList, reverse: true), SortEntry(SortType.title)]);
      final groupSorting = SortChain<GroupSortType>.fromMap({
        'sorts': ['stylesList'],
      }, GroupSortType.values);
      expect(groupSorting.firstType, GroupSortType.stylesList);
    });
  });
}
