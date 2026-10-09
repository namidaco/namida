// by claude
import 'package:flutter_test/flutter_test.dart';

import 'package:namida/base/generator_base.dart';

void main() {
  /// every count the default `length ~/ 12` to `length ~/ 8` range can give, a count of 0 means the whole list.
  Set<int> defaultCounts(int length) {
    if (length <= 2) return {0};
    final min = length ~/ 12;
    final max = length ~/ 8;
    final counts = <int>{};
    final end = max > min ? max : min + 1;
    for (int count = min; count < end; count++) {
      counts.add(count <= 0 ? length : count);
    }
    return counts;
  }

  void expectLibraryItems(List<int> result, int length, {int? exclude}) {
    expect(result.every((e) => e >= 0 && e < length), isTrue, reason: '$result');
    expect(result.toSet().length, result.length, reason: 'repeated items in $result');
    if (exclude != null) expect(result, isNot(contains(exclude)));
  }

  test('default counts work for every library size up to 30', () {
    for (int length = 0; length <= 30; length++) {
      final list = List.generate(length, (i) => i);
      final allowedCounts = defaultCounts(length);
      for (int attempt = 0; attempt < 30; attempt++) {
        final result = NamidaGeneratorBase.getRandomItems(list).toList();
        expectLibraryItems(result, length);
        expect(allowedCounts, contains(result.length), reason: 'length $length gave ${result.length} items');
      }
    }
  });

  test('min equal to max gives exactly that many items', () {
    final list = List.generate(30, (i) => i);
    final result = NamidaGeneratorBase.getRandomItems(list, min: 5, max: 5).toList();
    expectLibraryItems(result, 30);
    expect(result.length, 5);
  });

  test('the count stays between min and max', () {
    final list = List.generate(30, (i) => i);
    for (int attempt = 0; attempt < 30; attempt++) {
      final result = NamidaGeneratorBase.getRandomItems(list, min: 5, max: 8).toList();
      expectLibraryItems(result, 30);
      expect(result.length, inInclusiveRange(5, 7));
    }
  });

  test('an unlimited count gives the whole list except the excluded item', () {
    final list = List.generate(30, (i) => i);
    final result = NamidaGeneratorBase.getRandomItems(list, exclude: 3, min: 0, max: 1).toList();
    expectLibraryItems(result, 30, exclude: 3);
    expect(result.length, 29);
  });

  test('a max above the library size falls back to the default counts', () {
    for (final length in [5, 13, 20]) {
      final list = List.generate(length, (i) => i);
      final result = NamidaGeneratorBase.getRandomItems(list, min: 25, max: 26).toList();
      expectLibraryItems(result, length);
      expect(defaultCounts(length), contains(result.length), reason: 'length $length');
    }
  });

  test('the excluded item is never returned', () {
    final list = List.generate(20, (i) => i);
    for (int attempt = 0; attempt < 30; attempt++) {
      final result = NamidaGeneratorBase.getRandomItems(list, exclude: 7, min: 10, max: 15).toList();
      expectLibraryItems(result, 20, exclude: 7);
    }
  });
}
