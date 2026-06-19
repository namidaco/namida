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
      for (var item in items) {
        listensCountInThisRange.update(historyController.mainItemToSubItem(item), (value) => value + 1, ifAbsent: () => 1);
      }
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
    int randomNumber = (max - min).getRandomNumberBelow(min);
    if (randomNumber <= 0) randomNumber = list.length;

    final randomList = list.getRandomSample(randomNumber);
    if (exclude != null) randomList.remove(exclude);
    return randomList;
  }

  Iterable<E> generateRecommendedSimilarDiscoverDateFor(E item, E Function(T current) itemToSub) {
    final qit = QueueInsertionType.algorithmDiscoverDate;
    final q = qit.toQueueInsertion();
    final listensSampleCount = q.sample ?? 2;
    final firstListens = historyController.topTracksMapListens.value[item]?.take(listensSampleCount);
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
      ),
      sorter: (track, localListensCount) => historyController.topTracksMapListens.value[track]?.length ?? localListensCount, // prefer sort by total listens
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
    Iterable<int>? listens,
    E Function(T current) itemToSub, {
    required int daysCount,
    Iterable<T> Function(Iterable<T> tracks)? filterTracks,
    Comparable<dynamic> Function(E item, int localListensCount)? sorter,
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
      Iterable<T>? tracks = historyController.historyMap.value[d];
      if (tracks == null) continue;
      if (filterTracks != null) tracks = filterTracks(tracks);
      for (final t in tracks) {
        numberOfListensMap.addListen(itemToSub(t));
      }
    }

    return numberOfListensMap.finalize(item, sorter: sorter);
  }

  Iterable<E> generateRecommendedItemsFor(E item, E Function(T current) itemToSub, {int? sampleCount}) {
    final historytracks = historyController.historyTracks.toFixedList();
    if (historytracks.isEmpty) return [];

    if (sampleCount == null) {
      final q = QueueInsertionType.algorithm.toQueueInsertion();
      sampleCount = q.sample ?? 10;
    }

    final max = historytracks.length;
    int clamped(int range) => range.clampInt(0, max);

    final numberOfListensMap = _TracksWithNumberOfListensMap<E>();

    Iterable<T>? tempHeatTracks;

    for (int i = 0; i <= historytracks.length - 1;) {
      final t = historytracks[i];
      final subItem = itemToSub(t);

      if (subItem == item) {
        final heatTracks = historytracks.getRange(clamped(i - sampleCount), clamped(i + sampleCount));
        if (numberOfListensMap.isEmpty) {
          // -- first occurence, we want to skip the first listen if it's too recent
          final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(t.dateAddedMS));
          if (diff < const Duration(hours: 2)) {
            tempHeatTracks = heatTracks;
            i++;
            continue;
          }
        }
        for (final e in heatTracks) {
          numberOfListensMap.addListen(itemToSub(e));
        }
        // skip sampleCount since we already took 10 tracks.
        i += sampleCount;
      } else {
        i++;
      }
    }

    // -- yes we skip first listen if too recent, but if this results in nothing then nah go back
    if (numberOfListensMap.isEmpty && tempHeatTracks != null) {
      for (final e in tempHeatTracks) {
        numberOfListensMap.addListen(itemToSub(e));
      }
    }

    return numberOfListensMap.finalize(item);
  }
}

class _TracksWithNumberOfListensMap<E> {
  final numberOfListensMap = <E, int>{};

  bool get isEmpty => numberOfListensMap.isEmpty;

  void addListen(E e) {
    numberOfListensMap.update(e, (value) => value + 1, ifAbsent: () => 1);
  }

  List<E> finalize(E originalItem, {Comparable<dynamic> Function(E item, int localListensCount)? sorter}) {
    numberOfListensMap.remove(originalItem);

    final effectiveSorter = sorter != null ? (e) => sorter(e, numberOfListensMap[e] ?? 0) : (e) => numberOfListensMap[e] ?? 0;
    final sortedByValueMap = numberOfListensMap.keys.toList();
    sortedByValueMap.sortByReverse(effectiveSorter);
    return sortedByValueMap;
  }
}
