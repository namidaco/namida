// by claude
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:namida/base/generator_base.dart';

void main() {
  /// local clock times on different days, so each one is a separate listen.
  List<int> listensAt(List<(int hour, int minute)> times, {int year = 2026, int month = 3}) {
    return [
      for (int i = 0; i < times.length; i++) DateTime(year, month, 1 + i, times[i].$1, times[i].$2).millisecondsSinceEpoch,
    ];
  }

  List<String> pick(Map<String, List<int>> listensMap, DateTime now, {int count = 100, int seed = 1}) {
    final entries = listensMap.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length));
    return NamidaGeneratorBase.getItemsAroundTimeOfDay(entries, now, count: count, random: math.Random(seed));
  }

  final morning = DateTime(2026, 11, 5, 8, 30);

  test('picks tracks played around the current hour only', () {
    final listensMap = {
      'morning': listensAt([(8, 0), (8, 40), (9, 10), (7, 50)]),
      'night': listensAt([(23, 0), (22, 30), (0, 15), (23, 45)]),
      'afternoon': listensAt([(15, 0), (16, 0), (14, 30)]),
    };
    expect(pick(listensMap, morning), ['morning']);
    expect(pick(listensMap, DateTime(2026, 11, 5, 23, 0)), ['night']);
    expect(pick(listensMap, DateTime(2026, 11, 5, 15, 30)), ['afternoon']);
  });

  test('the window wraps around midnight', () {
    final listensMap = {
      'lateNight': listensAt([(23, 30), (23, 50), (0, 10), (23, 40)]),
    };
    expect(pick(listensMap, DateTime(2026, 11, 5, 0, 45)), ['lateNight']);
    expect(pick(listensMap, DateTime(2026, 11, 5, 22, 0)), ['lateNight']);
    expect(pick(listensMap, DateTime(2026, 11, 5, 3, 0)), isEmpty);
  });

  test('window edges are two hours each side', () {
    final listensMap = {
      'atEdge': listensAt([(10, 30), (10, 30), (10, 30)]),
      'pastEdge': listensAt([(10, 31), (10, 31), (10, 31)]),
    };
    expect(pick(listensMap, morning), ['atEdge']);
  });

  test('few listens or a small share in the window are skipped', () {
    final listensMap = {
      'twoListens': listensAt([(8, 0), (8, 30)]),
      'oneInWindow': listensAt([(8, 0), (15, 0), (20, 0)]),
      'spreadOut': listensAt([(8, 0), (8, 10), (13, 0), (15, 0), (18, 0), (20, 0), (22, 0)]),
      'thirdInWindow': listensAt([(8, 0), (8, 10), (13, 0), (15, 0), (18, 0), (20, 0)]),
    };
    expect(pick(listensMap, morning), ['thirdInWindow']);
  });

  test('clock time is read per day, across summer and winter time', () {
    final listensMap = {
      'winterAndSummer': [
        ...listensAt([(10, 0), (10, 0)], month: 1),
        ...listensAt([(10, 0), (10, 0)], month: 7),
      ],
    };
    expect(pick(listensMap, DateTime(2026, 11, 5, 8, 0)), ['winterAndSummer']);
    expect(pick(listensMap, DateTime(2026, 11, 5, 12, 0)), ['winterAndSummer']);
    expect(pick(listensMap, DateTime(2026, 11, 5, 7, 59)), isEmpty);
  });

  test('count limits the result, no repeats, stronger habits come first more often', () {
    final listensMap = {
      for (int i = 0; i < 10; i++) 'weak$i': listensAt([(8, 0), (8, 0), (15, 0), (16, 0)]),
      'strong': listensAt(List.filled(20, (8, 15))),
    };
    int strongFirstCount = 0;
    for (int seed = 0; seed < 50; seed++) {
      final result = pick(listensMap, morning, count: 5, seed: seed);
      expect(result.length, 5);
      expect(result.toSet().length, 5);
      if (result.first == 'strong') strongFirstCount++;
    }
    // -- 1 in 11 if it was even, ~2 in 3 with its weight
    expect(strongFirstCount, greaterThan(20));
  });

  test('result can be edited, home removes invalid items from it', () {
    final listensMap = {
      'a': listensAt([(8, 0), (8, 10), (8, 20)]),
      'b': listensAt([(8, 30), (8, 40), (8, 50)]),
    };
    final result = pick(listensMap, morning);
    result.removeWhere((e) => e == 'a');
    expect(result, ['b']);
  });

  test('empty history gives nothing', () {
    expect(pick({}, morning), isEmpty);
  });
}
