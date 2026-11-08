// by claude
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:namida/core/extensions.dart';

void main() {
  test('matches only at the end of a long list are still picked', () {
    final list = List.generate(202, (i) => i);
    final result = list.getRandomSampleWhere(100, (item) => item >= 192, math.Random(1));
    expect(result.toSet(), {for (int i = 192; i < 202; i++) i});
  });

  test('stops at the sample count, without repeats', () {
    final list = List.generate(500, (i) => i);
    final result = list.getRandomSampleWhere(40, (item) => item.isEven, math.Random(2));
    expect(result.length, 40);
    expect(result.toSet().length, 40);
    expect(result.every((item) => item.isEven), isTrue);
  });

  test('the same seed gives the same sample', () {
    final list = List.generate(300, (i) => i);
    final first = list.getRandomSampleWhere(50, (item) => item % 3 == 0, math.Random(7));
    final second = list.getRandomSampleWhere(50, (item) => item % 3 == 0, math.Random(7));
    expect(first, second);
  });

  test('no match gives an empty sample', () {
    final list = List.generate(300, (i) => i);
    expect(list.getRandomSampleWhere(50, (item) => item < 0, math.Random(3)), isEmpty);
  });
}
