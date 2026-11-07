import 'dart:math' as math;
import 'dart:typed_data';

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

    final shouldDefaultSort = sortByListensInRangeIfRequired && QueueInsertionType.listenTimeRange.toQueueInsertion().isUnsorted;
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

  static Iterable<R> getRandomItems<R>(List<R> list, {R? exclude, int? min, int? max, math.Random? random}) {
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
    final range = max - min;
    random ??= math.Random();
    int randomNumber = range > 0 ? min + random.nextInt(range) : min;
    if (randomNumber <= 0) randomNumber = list.length;

    final randomList = list.getRandomSample(randomNumber, random);
    if (exclude != null) randomList.remove(exclude);
    return randomList;
  }

  static const _kTimeOfDayWindowMinutes = 120;
  static const _kTimeOfDayMinListens = 3;
  static const _kTimeOfDayMinListensInWindow = 2;
  static const _kTimeOfDayMinShare = 1 / 3;

  /// items mostly listened to around the clock time of [now], in a weighted random order.
  static List<E> getItemsAroundTimeOfDay<E>(Iterable<MapEntry<E, List<int>>> listensEntriesSortedByCount, DateTime now, {required int count, math.Random? random}) {
    random ??= math.Random();

    final nowMinuteOfDay = now.hour * 60 + now.minute;
    final isMinuteInWindow = Uint8List(Duration.minutesPerDay);
    for (int i = -_kTimeOfDayWindowMinutes; i <= _kTimeOfDayWindowMinutes; i++) {
      final minuteOfDay = (nowMinuteOfDay + i) % Duration.minutesPerDay;
      isMinuteInWindow[minuteOfDay] = 1;
    }

    final timeZoneOffsets = _PastTimeZoneOffsets(now.millisecondsSinceEpoch);
    final picks = <_WeightedPick<E>>[];
    for (final e in listensEntriesSortedByCount) {
      final listens = e.value;
      final listensCount = listens.length;
      if (listensCount < _kTimeOfDayMinListens) break;

      int listensInWindow = 0;
      for (final listenMSSE in listens) {
        final offsetMS = timeZoneOffsets.offsetMSOf(listenMSSE);
        final localMSOfDay = (listenMSSE + offsetMS) % Duration.millisecondsPerDay;
        final minuteOfDay = localMSOfDay ~/ Duration.millisecondsPerMinute;
        listensInWindow += isMinuteInWindow[minuteOfDay];
      }

      if (listensInWindow < _kTimeOfDayMinListensInWindow) continue;
      final share = listensInWindow / listensCount;
      if (share < _kTimeOfDayMinShare) continue;
      final weight = listensInWindow * share;
      final randomValue = random.nextDouble();
      final priority = math.pow(randomValue, 1 / weight).toDouble();
      picks.add((item: e.key, priority: priority));
    }

    picks.sortByReverse((e) => e.priority);
    // -- growable, home removes invalid items from it
    return picks.take(count).map((e) => e.item).toList();
  }

  Iterable<E> generateRecommendedSimilarDiscoverDateFor(E item, E Function(T current) itemToSub) {
    const qit = QueueInsertionType.algorithmDiscoverDate;
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
    const qit = QueueInsertionType.algorithmTimeRange;
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
    final numberOfListensMap = _collectRecommendedListens(item, itemToSub, sampleCount: sampleCount);
    return numberOfListensMap.finalize(item);
  }

  /// [item] itself excluded.
  Map<E, int> getRecommendedListensFor(E item, E Function(T current) itemToSub) {
    final numberOfListensMap = _collectRecommendedListens(item, itemToSub).numberOfListensMap;
    numberOfListensMap.remove(item);
    return numberOfListensMap;
  }

  _TracksWithNumberOfListensMap<E> _collectRecommendedListens(E item, E Function(T current) itemToSub, {int? sampleCount}) {
    final numberOfListensMap = _TracksWithNumberOfListensMap<E>();
    final historytracks = historyController.historyTracks.toFixedList();
    if (historytracks.isEmpty) return numberOfListensMap;

    if (sampleCount == null) {
      final q = QueueInsertionType.algorithm.toQueueInsertion();
      sampleCount = q.sample ?? 10;
    }

    final max = historytracks.length;
    int clamped(int range) => range.clampInt(0, max);

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

    return numberOfListensMap;
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

/// system timezone offsets of past times, read once per week, and per day only in weeks with a dst switch.
///
/// by claude
class _PastTimeZoneOffsets {
  static const _kUnknown = -0x80000000;
  static const _kSwitchingWeek = 0x7FFFFFFF;
  static const _kMSPerWeek = Duration.millisecondsPerDay * 7;

  final int _untilMSSE;
  final Int32List _offsetMSPerWeekStart;
  final Int32List _offsetMSPerWeek;
  final Int32List _offsetMSPerDay;

  _PastTimeZoneOffsets(int untilMSSE)
    : _untilMSSE = untilMSSE,
      _offsetMSPerWeekStart = _newUnknownList(untilMSSE ~/ _kMSPerWeek + 2),
      _offsetMSPerWeek = _newUnknownList(untilMSSE ~/ _kMSPerWeek + 1),
      _offsetMSPerDay = _newUnknownList(untilMSSE ~/ Duration.millisecondsPerDay + 1);

  static Int32List _newUnknownList(int length) => Int32List(length)..fillRange(0, length, _kUnknown);

  static int _systemOffsetMSOf(int msse) => DateTime.fromMillisecondsSinceEpoch(msse).timeZoneOffset.inMilliseconds;

  int offsetMSOf(int msse) {
    if (msse < 0 || msse >= _untilMSSE) return _systemOffsetMSOf(msse);

    final week = msse ~/ _kMSPerWeek;
    final weekOffsetMS = _weekOffsetMSOf(week);
    if (weekOffsetMS != _kSwitchingWeek) return weekOffsetMS;

    final day = msse ~/ Duration.millisecondsPerDay;
    final cachedDayOffsetMS = _offsetMSPerDay[day];
    if (cachedDayOffsetMS != _kUnknown) return cachedDayOffsetMS;
    final dayOffsetMS = _systemOffsetMSOf(msse);
    _offsetMSPerDay[day] = dayOffsetMS;
    return dayOffsetMS;
  }

  int _weekOffsetMSOf(int week) {
    final cachedWeekOffsetMS = _offsetMSPerWeek[week];
    if (cachedWeekOffsetMS != _kUnknown) return cachedWeekOffsetMS;
    final startOffsetMS = _weekStartOffsetMSOf(week);
    final endOffsetMS = _weekStartOffsetMSOf(week + 1);
    final weekOffsetMS = startOffsetMS == endOffsetMS ? startOffsetMS : _kSwitchingWeek;
    _offsetMSPerWeek[week] = weekOffsetMS;
    return weekOffsetMS;
  }

  int _weekStartOffsetMSOf(int week) {
    final cachedOffsetMS = _offsetMSPerWeekStart[week];
    if (cachedOffsetMS != _kUnknown) return cachedOffsetMS;
    final offsetMS = _systemOffsetMSOf(week * _kMSPerWeek);
    _offsetMSPerWeekStart[week] = offsetMS;
    return offsetMS;
  }
}

typedef _WeightedPick<E> = ({E item, double priority});
