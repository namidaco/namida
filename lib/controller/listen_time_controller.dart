import 'package:namico_db_wrapper/namico_db_wrapper.dart';

import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';

// by claude
class ListenTimeController {
  static ListenTimeController get inst => _instance;
  static final ListenTimeController _instance = ListenTimeController._internal();
  ListenTimeController._internal();

  late final _db = DBWrapper.openFromInfo(
    fileInfo: AppPaths.LISTEN_TIME_DAILY_DB_INFO,
    config: const DBConfig(
      createIfNotExist: true,
    ),
  );

  Map<int, Map<String, int>>? _all;
  Future<Map<int, Map<String, int>>>? _loading;

  int _todayDay = -1;
  Map<String, int> _today = {};
  bool _dirty = false;

  /// first day that has recorded time, null if nothing recorded yet.
  int? get firstDay {
    final all = _all;
    if (all == null || all.isEmpty) return null;
    int min = all.keys.first;
    for (final k in all.keys) {
      if (k < min) min = k;
    }
    return min;
  }

  void onSecond(String key) {
    final day = DateTime.now().toDaysSince1970();
    if (day != _todayDay) {
      flush();
      _todayDay = day;
      final all = _all;
      if (all != null) {
        _today = all[day] ??= {};
      } else {
        _today = {};
        loadAll();
      }
    }
    _today[key] = (_today[key] ?? 0) + 1;
    _dirty = true;
  }

  void flush() {
    if (!_dirty || _todayDay < 0) return;
    _dirty = false;
    _db.put('$_todayDay', Map<String, dynamic>.of(_today));
  }

  Future<Map<int, Map<String, int>>> loadAll() {
    final all = _all;
    if (all != null) return Future.value(all);
    return _loading ??= _loadAll();
  }

  Future<Map<int, Map<String, int>>> _loadAll() async {
    final all = <int, Map<String, int>>{};
    try {
      final rows = await _db.loadEverythingKeyedResult();
      for (final e in rows.entries) {
        final day = int.tryParse(e.key);
        if (day == null) continue;
        all[day] = e.value.map((k, v) => MapEntry(k, v is int ? v : 0));
      }
    } catch (_) {}

    // -- merge whatever got counted while loading.
    if (_todayDay >= 0) {
      final loadedToday = all[_todayDay];
      if (loadedToday != null) {
        for (final e in _today.entries) {
          loadedToday[e.key] = (loadedToday[e.key] ?? 0) + e.value;
        }
        _today = loadedToday;
      } else {
        all[_todayDay] = _today;
      }
    }
    _all = all;
    _loading = null;
    return all;
  }

  /// sums seconds of [keys] between [firstDay] and [lastDay] inclusive.
  int sumSeconds(Map<int, Map<String, int>> all, int firstDay, int lastDay, List<String> keys) {
    int total = 0;
    if (all.length < lastDay - firstDay) {
      for (final e in all.entries) {
        if (e.key < firstDay || e.key > lastDay) continue;
        for (final k in keys) {
          total += e.value[k] ?? 0;
        }
      }
    } else {
      for (int d = firstDay; d <= lastDay; d++) {
        final row = all[d];
        if (row == null) continue;
        for (final k in keys) {
          total += row[k] ?? 0;
        }
      }
    }
    return total;
  }
}
