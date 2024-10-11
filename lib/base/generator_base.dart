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

    /// ignore min and max if the value is more than the alltrackslist.
    if (max != null && max > itemslist.length) {
      max = null;
      min = null;
    }
    min ??= itemslistLength ~/ 12;
    max ??= itemslistLength ~/ 8;

    // number of resulting tracks.
    final int randomNumber = (max - min).getRandomNumberBelow(min);

    final randomListMap = <R, bool>{};
    for (int i = 0; i <= randomNumber; i++) {
      final item = list[itemslistLength.getRandomNumberBelow()];
      randomListMap[item] = true;
    }

    if (exclude != null) randomListMap.remove(exclude);

    return randomListMap.keys;
  }

  Iterable<E2> generateRecommendedItemsFor<E2>(E item, E2 Function(T current) itemToSub) {
    final historytracks = historyController.historyTracks.toList();
    if (historytracks.isEmpty) return [];

    const length = 10;
    final max = historytracks.length;
    int clamped(int range) => range.clamp(0, max);

    final Map<E2, int> numberOfListensMap = {};

    for (int i = 0; i <= historytracks.length - 1;) {
      final t = historytracks[i];
      final subItem = itemToSub(t);
      if (subItem == item) {
        final heatTracks = historytracks.getRange(clamped(i - length), clamped(i + length)).toList();
        heatTracks.loop((e) {
          numberOfListensMap.update(itemToSub(e), (value) => value + 1, ifAbsent: () => 1);
        });
        // skip length since we already took 10 tracks.
        i += length;
      } else {
        i++;
      }
    }

    numberOfListensMap.remove(item);

    final sortedByValueMap = numberOfListensMap.entries.toList();
    sortedByValueMap.sortByReverse((e) => e.value);

    return sortedByValueMap.map((e) => e.key);
  }
}
