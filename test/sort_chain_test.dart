// by claude
import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/sort_chain.dart';
import 'package:namida/core/enums.dart';

void main() {
  // -- (rating, listens, track number)
  final items = [(3, 10, 2), (5, 1, 1), (5, 7, 3), (3, 2, 1), (1, 9, 1), (5, 7, 1)];

  SortChainComparables<(int, int, int)> comparablesOf(SortChain<SortType> chain) {
    Comparable Function((int, int, int) e) comparableOf(SortType type) => switch (type) {
      SortType.rating => (e) => e.$1,
      SortType.mostPlayed => (e) => e.$2,
      _ => (e) => e.$3,
    };
    return SortChainComparables.of(chain, comparableOf);
  }

  List<(int, int, int)> sortedBy(SortChain<SortType> chain, {required int length}) {
    final list = items.take(length).toList();
    list.sortByChain(comparablesOf(chain));
    return list;
  }

  test('each sort keeps its own direction, small and precomputed lists alike', () {
    const chain = SortChain([SortEntry(SortType.rating, reverse: true), SortEntry(SortType.mostPlayed, reverse: true), SortEntry(SortType.trackNo)]);
    final expected = [(5, 7, 1), (5, 7, 3), (5, 1, 1), (3, 10, 2), (3, 2, 1), (1, 9, 1)];
    expect(sortedBy(chain, length: items.length), expected);

    final manyItems = [for (int i = 0; i < 4; i++) ...items];
    final manyExpected = [for (final e in expected) ...List.filled(4, e)];
    manyItems.sortByChain(comparablesOf(chain));
    expect(manyItems, manyExpected);
  });

  test('the chain reverse flips every sort on top of their own direction', () {
    const chain = SortChain([SortEntry(SortType.rating, reverse: true), SortEntry(SortType.mostPlayed), SortEntry(SortType.trackNo)]);
    final reversedChain = chain.copyWith(reverse: true);
    final expected = sortedBy(chain, length: items.length).reversed.toList();
    expect(sortedBy(reversedChain, length: items.length), expected);
  });

  test('lazy sorting follows the same directions', () {
    const chain = SortChain([SortEntry(SortType.rating), SortEntry(SortType.mostPlayed, reverse: true), SortEntry(SortType.trackNo)]);
    final lazy = items.lazySortedByChain(comparablesOf(chain)).toList();
    expect(lazy, sortedBy(chain, length: items.length));
  });

  test('json keeps reversed sorts and reads old plain names', () {
    const chain = SortChain([SortEntry(SortType.rating, reverse: true), SortEntry(SortType.title)], reverse: true);
    final json = chain.toJson();
    expect(json, {
      'sorts': ['-rating', 'title'],
      'reverse': true,
    });
    expect(SortChain.fromMap(json, SortType.values), chain);

    final oldJson = {
      'sorts': ['year', 'futureSort'],
      'reverse': false,
    };
    expect(SortChain.fromMap(oldJson, SortType.values), SortChain.of(const [SortType.year]));
  });

  test('fallbacks only add sorts missing from the chain', () {
    const chain = SortChain([SortEntry(SortType.trackNo, reverse: true)]);
    final comparables = SortChainComparables.of(chain, (SortType type) => (int e) => e, fallbacks: const [SortType.trackNo, SortType.title]);
    expect(comparables.keysReverse, [true, false]);
  });
}
