import 'package:history_manager/history_manager.dart';

import 'package:namida/core/extensions.dart';

abstract class NamidaGeneratorBase<T extends ItemWithDate, E> {
  HistoryManager<T, E> get historyController;

  /// Generated items listened to in a time range.
  List<T> generateItemsFromHistoryDates(DateTime? oldestDate, DateTime? newestDate, {bool removeDuplicates = true}) {
    return historyController.generateTracksFromHistoryDates(oldestDate, newestDate, removeDuplicates: removeDuplicates);
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

  Iterable<E> generateRecommendedItemsFor(E item, E Function(T current) itemToSub) {
    final historytracks = historyController.historyTracks.toList();
    if (historytracks.isEmpty) return [];

    const length = 10;
    final max = historytracks.length;
    int clamped(int range) => range.clamp(0, max);

    final Map<E, int> numberOfListensMap = {};

    for (int i = 0; i <= historytracks.length - 1;) {
      final t = historytracks[i];
      final subItem = itemToSub(t);
      if (subItem == item) {
        final heatTracks = historytracks.getRange(clamped(i - length), clamped(i + length)).toList();
        heatTracks.loop((e, index) {
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
