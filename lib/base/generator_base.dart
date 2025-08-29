import 'package:history_manager/history_manager.dart';

import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';

abstract class NamidaGeneratorBase<T extends ItemWithDate, E> {
  final HistoryManager<T, E> historyController;
  const NamidaGeneratorBase(this.historyController);

  /// Generated items listened to in a time range.
  List<T> generateItemsFromHistoryDates(DateTime? oldestDate, DateTime? newestDate, {bool sortByListensInRangeIfRequired = true}) {
    final items = historyController.generateTracksFromHistoryDates(oldestDate, newestDate, removeDuplicates: false);

    final shouldDefaultSort = sortByListensInRangeIfRequired && QueueInsertionType.listenTimeRange.toQueueInsertion().sortBy == InsertionSortingType.none;
    if (shouldDefaultSort) {
      final listensCountInThisRange = <E, int>{};
      items.loop((item) => listensCountInThisRange.update(historyController.mainItemToSubItem(item), (value) => value + 1, ifAbsent: () => 1));
      items.removeDuplicates(historyController.mainItemToSubItem);
      items.sortByReverse((item) => listensCountInThisRange[historyController.mainItemToSubItem(item)] ?? 0);
      return items;
    } else {
      items.removeDuplicates(historyController.mainItemToSubItem);
    }
    return items;
  }

  static Iterable<R> getRandomItems<R>(List<R> list, {R? exclude, int? min, int? max}) {
    final itemslist = list;
    final itemslistLength = itemslist.length;

    if (itemslistLength <= 2) return [];

    /// ignore min and max if the value is more than the list.
    if (max != null && max > itemslist.length) {
      max = null;
      min = null;
    }
    min ??= itemslistLength ~/ 12;
    max ??= itemslistLength ~/ 8;

    // number of resulting tracks.
    final int randomNumber = (max - min).getRandomNumberBelow(min);

    final randomList = list.getRandomSample(randomNumber);
    if (exclude != null) randomList.remove(exclude);
    return randomList;
  }

  Iterable<E> generateRecommendedSimilarDiscoverDateFor(E item, E Function(T current) itemToSub) {
    final qit = QueueInsertionType.algorithmDiscoverDate;
    final q = qit.toQueueInsertion();
    final listensSampleCount = q.sample ?? 2;
    final firstListens = historyController.topTracksMapListens.value[item]?.take(listensSampleCount).toList();
    if (firstListens == null) return [];
    final daysCount = q.sampleDays ?? qit.recommendedSampleDaysCount ?? 18;
    return _getDaysTracksByListens(
      item,
      firstListens,
      itemToSub,
      daysCount: daysCount,
      filterTracks: (tracks) => tracks.where(
        (element) {
          final totalListens = historyController.topTracksMapListens.value[itemToSub(element)] ?? [];
          return totalListens.take(listensSampleCount).contains(element.dateAddedMS); // only allow tracks with first few listens
        },
      ).toList(),
      sorter: (e) => historyController.topTracksMapListens.value[e.key]?.length ?? e.value, // prefer sort by total listens
    );
  }

  Iterable<E> generateRecommendedSimilarTimeRangeFor(E item, E Function(T current) itemToSub) {
    final qit = QueueInsertionType.algorithmTimeRange;
    final listens = historyController.topTracksMapListens.value[item];
    final q = qit.toQueueInsertion();
    final daysCount = q.sampleDays ?? qit.recommendedSampleDaysCount ?? 7;
    return _getDaysTracksByListens(
      item,
      listens,
      itemToSub,
      daysCount: daysCount,
    );
  }

  Iterable<E> _getDaysTracksByListens(
    E item,
    List<int>? listens,
    E Function(T current) itemToSub, {
    required int daysCount,
    List<T> Function(List<T> tracks)? filterTracks,
    Comparable<dynamic> Function(MapEntry<E, int>)? sorter,
  }) {
    if (listens == null || listens.isEmpty) return [];

    final daysToInclude = <int>{};
    void addFewDays({required int day, required int count}) {
      daysToInclude.add(day);
      for (int i = 1; i <= count; i++) {
        daysToInclude.add(day - i);
        daysToInclude.add(day + i);
      }
    }

    for (final l in listens) {
      final day = l.toDaysSince1970();
      addFewDays(day: day, count: daysCount);
    }

    final numberOfListensMap = _TracksWithNumberOfListensMap<E>();
    for (final d in daysToInclude) {
      var tracks = historyController.historyMap.value[d];
      if (tracks == null) continue;
      if (filterTracks != null) tracks = filterTracks(tracks);
      for (final t in tracks) {
        numberOfListensMap.addListen(itemToSub(t));
      }
    }

    return numberOfListensMap.finalize(item, sorter: sorter);
  }

  Iterable<E> generateRecommendedItemsFor(E item, E Function(T current) itemToSub) {
    final historytracks = historyController.historyTracks.toList();
    if (historytracks.isEmpty) return [];

    final q = QueueInsertionType.algorithmDiscoverDate.toQueueInsertion();
    final sampleCount = q.sample ?? 10;

    final max = historytracks.length;
    int clamped(int range) => range.clampInt(0, max);

    final numberOfListensMap = _TracksWithNumberOfListensMap<E>();

    for (int i = 0; i <= historytracks.length - 1;) {
      final t = historytracks[i];
      final subItem = itemToSub(t);
      if (subItem == item) {
        final heatTracks = historytracks.getRange(clamped(i - sampleCount), clamped(i + sampleCount)).toList();
        heatTracks.loop((e) {
          numberOfListensMap.addListen(itemToSub(e));
        });
        // skip sampleCount since we already took 10 tracks.
        i += sampleCount;
      } else {
        i++;
      }
    }
    return numberOfListensMap.finalize(item);
  }
}

class _TracksWithNumberOfListensMap<E> {
  final numberOfListensMap = <E, int>{};

  void addListen(E e) {
    numberOfListensMap.update(e, (value) => value + 1, ifAbsent: () => 1);
  }

  Iterable<E> finalize(E originalItem, {Comparable<dynamic> Function(MapEntry<E, int>)? sorter}) {
    numberOfListensMap.remove(originalItem);

    final sortedByValueMap = numberOfListensMap.entries.toList();
    sortedByValueMap.sortByReverse(sorter ?? (e) => e.value);
    return sortedByValueMap.map((e) => e.key);
  }
}
