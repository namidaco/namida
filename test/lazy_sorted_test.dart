// by claude
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:namida/core/extensions.dart';

void main() {
  List<(int, int)> expectedOrder(List<(int, int)> items, {required bool reverse}) {
    final indexed = List.generate(items.length, (i) => (items[i], i));
    indexed.sort((a, b) {
      int compare = a.$1.$1.compareTo(b.$1.$1);
      if (compare == 0) compare = a.$1.$2.compareTo(b.$1.$2);
      if (compare == 0) compare = a.$2.compareTo(b.$2);
      return reverse ? -compare : compare;
    });
    return indexed.map((e) => e.$1).toList();
  }

  test('matches a full stable sort, both directions, ties keep original order', () {
    final random = math.Random(7);
    for (final length in [0, 1, 2, 3, 15, 16, 17, 100, 1000]) {
      final items = List.generate(length, (_) => (random.nextInt(10), random.nextInt(3)));
      for (final reverse in [false, true]) {
        final lazy = items.lazySortedByAltsPrecomputed([(e) => e.$1, (e) => e.$2], reverse: reverse).toList();
        expect(lazy, expectedOrder(items, reverse: reverse), reason: 'length $length, reverse $reverse');
      }
    }
  });

  test('no alternatives keeps the list order, reversed when asked', () {
    final items = List.generate(50, (i) => (i, 0));
    expect(items.lazySortedByAltsPrecomputed([]).toList(), items);
    expect(items.lazySortedByAltsPrecomputed([], reverse: true).toList(), items.reversed.toList());
  });

  test('taking the first items matches the full sort', () {
    final random = math.Random(3);
    final items = List.generate(5000, (_) => (random.nextInt(100000), 0));
    final top = items.lazySortedByAltsPrecomputed([(e) => e.$1]).take(12).toList();
    expect(top, expectedOrder(items, reverse: false).take(12).toList());
  });
}
