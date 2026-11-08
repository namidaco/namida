// by claude
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:namida/core/extensions.dart';

void main() {
  const length = 2000;
  final rnd = Random(1);

  // -- few values each, so lots of equal keys
  List<_Item> generateItems(int count, {int idOffset = 0}) {
    return List.generate(count, (i) => _Item(idOffset + i, rnd.nextInt(10), rnd.nextInt(5)));
  }

  void expectSorted(List<_Item> list, int Function(_Item a, _Item b) compare) {
    for (int i = 1; i < list.length; i++) {
      final isInOrder = compare(list[i - 1], list[i]) <= 0;
      expect(isInOrder, isTrue, reason: 'out of order at $i');
    }
  }

  List<int> idsOf(Iterable<_Item> items) => items.map((e) => e.id).toFixedList();

  void sortSingle(List<_Item> list, {bool reverse = false}) => list.sortByPrecomputed((e) => e.a, reverse: reverse);

  void sortChain(List<_Item> list, {bool reverse = false}) {
    list.sortByAltsPrecomputed([(e) => e.a, (e) => e.b], reverse: reverse, alternativesReverse: const [false, true]);
  }

  int compareChain(_Item a, _Item b, {bool reverse = false}) {
    final compareA = a.a.compareTo(b.a);
    final compare = compareA != 0 ? compareA : b.b.compareTo(a.b);
    return reverse ? -compare : compare;
  }

  final sorters = <String, (void Function(List<_Item> list), int Function(_Item a, _Item b))>{
    'single key': (sortSingle, (a, b) => a.a.compareTo(b.a)),
    'single key reversed': ((list) => sortSingle(list, reverse: true), (a, b) => b.a.compareTo(a.a)),
    'chain with reversed key': (sortChain, compareChain),
    'chain reversed': ((list) => sortChain(list, reverse: true), (a, b) => compareChain(a, b, reverse: true)),
  };

  for (final MapEntry(key: name, value: (sort, compare)) in sorters.entries) {
    group(name, () {
      test('sorting a sorted list again moves nothing', () {
        final list = generateItems(length);
        sort(list);
        expectSorted(list, compare);
        final idsBefore = idsOf(list);
        for (int round = 0; round < 3; round++) {
          sort(list);
          expect(idsOf(list), idsBefore);
        }
      });

      test('short unsorted tail is merged in, existing items keep their order', () {
        final list = generateItems(length);
        sort(list);
        final existingIds = idsOf(list);
        final added = generateItems(length ~/ 10, idOffset: length);
        list.addAll(added);
        sort(list);
        expectSorted(list, compare);
        final existingIdsAfter = idsOf(list.where((e) => e.id < length));
        expect(existingIdsAfter, existingIds);

        // -- added items go after existing ones with equal keys
        for (int i = 1; i < list.length; i++) {
          final previous = list[i - 1];
          final current = list[i];
          if (compare(previous, current) != 0) continue;
          final isAddedBeforeExisting = previous.id >= length && current.id < length;
          expect(isAddedBeforeExisting, isFalse, reason: 'added item before an equal existing one at $i');
        }
      });

      test('long unsorted tail and unsorted lists still sort', () {
        final withLongTail = generateItems(length);
        sort(withLongTail);
        withLongTail.addAll(generateItems(length ~/ 2, idOffset: length));
        sort(withLongTail);
        expectSorted(withLongTail, compare);

        final unsorted = generateItems(length);
        sort(unsorted);
        expectSorted(unsorted, compare);
        final sortedIds = idsOf(unsorted)..sort();
        final allIds = List.generate(length, (i) => i);
        expect(sortedIds, allIds);
      });

      test('tail with a single misplaced item at the start or end', () {
        for (final misplaced in const [_Item(length, -1, -1), _Item(length, 100, 100)]) {
          final list = generateItems(length);
          sort(list);
          list.add(misplaced);
          sort(list);
          expectSorted(list, compare);
          expect(list.length, length + 1);
        }
      });
    });
  }
}

class _Item {
  final int id;
  final int a;
  final int b;

  const _Item(this.id, this.a, this.b);
}
