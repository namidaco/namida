import 'package:flutter/material.dart';
import 'package:history_manager/history_manager.dart';

mixin HistoryDaysRebuilderMixin<T extends StatefulWidget, E extends ItemWithDate, S> on State<T> {
  HistoryManager<E, S> get historyManager;

  Iterable<E> getHistoryTracks(Map<int, List<E>> history) sync* {
    final map = history;
    for (final trs in map.values) {
      yield* trs;
    }
  }

  int dayToMillis(int day) => day * 24 * 60 * 60 * 1000;

  List<int> _listifyHistoryDays() => historyManager.historyMap.value.keys.toList();

  late List<int> historyDays = _listifyHistoryDays();

  void _updateDays() {
    if (mounted) {
      historyDays = _listifyHistoryDays();
    }
  }

  @override
  void initState() {
    historyManager.modifiedDays.addListener(_updateDays);
    super.initState();
  }

  @override
  void dispose() {
    historyManager.modifiedDays.removeListener(_updateDays);
    super.dispose();
  }
}
