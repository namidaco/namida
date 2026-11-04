// by claude
import 'package:flutter/foundation.dart';

import 'package:namida/core/extensions.dart';

/// a [SortChain] resolved into comparables, what the precomputed sorts take.
class SortChainComparables<E> {
  final List<Comparable Function(E e)> keys;
  final List<bool> keysReverse;
  final bool reverse;

  const SortChainComparables(this.keys, this.keysReverse, {required this.reverse});

  /// entries [comparableOf] has no comparable for are skipped, [fallbacks] not in [chain] are added after it as tie breakers.
  static SortChainComparables<E> of<E, S extends Enum>(
    SortChain<S> chain,
    Comparable Function(E e)? Function(S type) comparableOf, {
    List<S> fallbacks = const [],
  }) {
    final keys = <Comparable Function(E e)>[];
    final keysReverse = <bool>[];
    for (final entry in chain.entries) {
      final key = comparableOf(entry.type);
      if (key == null) continue;
      keys.add(key);
      keysReverse.add(entry.reverse);
    }
    for (final type in fallbacks) {
      if (chain.hasType(type)) continue;
      final key = comparableOf(type);
      if (key == null) continue;
      keys.add(key);
      keysReverse.add(false);
    }
    return SortChainComparables(keys, keysReverse, reverse: chain.reverse);
  }

  SortChainComparables<E> withLeading(Comparable Function(E e) comparable, {required bool isLeadingReversed, required bool reverse}) {
    return SortChainComparables(
      [comparable, ...keys],
      [isLeadingReversed, ...keysReverse],
      reverse: reverse,
    );
  }

  SortChainComparables<T> mapKeys<T>(E Function(T item) itemOf) {
    final mappedKeys = keys.map((key) => (T item) => key(itemOf(item))).toFixedList();
    return SortChainComparables(mappedKeys, keysReverse, reverse: reverse);
  }
}

extension SortChainListUtils<E> on List<E> {
  void sortByChain(SortChainComparables<E> comparables) {
    sortByAltsPrecomputed(comparables.keys, reverse: comparables.reverse, alternativesReverse: comparables.keysReverse);
  }

  Iterable<E> lazySortedByChain(SortChainComparables<E> comparables) {
    return lazySortedByAltsPrecomputed(comparables.keys, reverse: comparables.reverse, alternativesReverse: comparables.keysReverse);
  }

  /// inserts [item] where [comparables] place it in this already sorted list, after the items equal to it.
  void insertByChain(E item, SortChainComparables<E> comparables) {
    final keys = comparables.keys;
    final keysReverse = comparables.keysReverse;
    final reverse = comparables.reverse;
    final keysLength = keys.length;
    final itemKeys = List<Comparable>.generate(keysLength, (i) => keys[i](item), growable: false);

    int compareWithItem(E other) {
      for (int i = 0; i < keysLength; i++) {
        final compare = keys[i](other).compareTo(itemKeys[i]);
        if (compare != 0) return keysReverse[i] != reverse ? -compare : compare;
      }
      return 0;
    }

    int low = 0;
    int high = length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (compareWithItem(this[mid]) > 0) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }
    insert(low, item);
  }
}

/// sorters applied in order, each can be reversed on its own, [reverse] flips the whole order on top.
class SortChain<S extends Enum> {
  final List<SortEntry<S>> entries;
  final bool reverse;

  const SortChain(this.entries, {this.reverse = false});

  SortChain.of(List<S> types, {this.reverse = false}) : entries = types.map((e) => SortEntry(e)).toFixedList();

  factory SortChain.fromMap(Map json, List<S> values) {
    final entries = SortEntry.listFromJson(json['sorts'], values);
    return SortChain(entries, reverse: json['reverse'] == true);
  }

  bool get isEmpty => entries.isEmpty;
  bool get isNotEmpty => entries.isNotEmpty;
  S? get firstType => entries.firstOrNull?.type;

  bool hasType(S type) => entries.any((e) => e.type == type);

  Iterable<S> types() => entries.map((e) => e.type);

  /// [type] alone, keeping [reverse].
  SortChain<S> withSingle(S type) => SortChain([SortEntry(type)], reverse: reverse);

  SortChain<S> copyWith({List<SortEntry<S>>? entries, bool? reverse}) {
    return SortChain(
      entries ?? this.entries,
      reverse: reverse ?? this.reverse,
    );
  }

  Map<String, dynamic> toJson() => {
    'sorts': SortEntry.listToJson(entries),
    if (reverse) 'reverse': reverse,
  };

  @override
  bool operator ==(Object other) => other is SortChain<S> && other.reverse == reverse && listEquals(other.entries, entries);

  @override
  int get hashCode => Object.hash(reverse, Object.hashAll(entries));
}

/// stored as the sort name, prefixed with [_kReversePrefix] when reversed.
class SortEntry<S extends Enum> {
  static const _kReversePrefix = '-';

  final S type;
  final bool reverse;

  const SortEntry(this.type, {this.reverse = false});

  SortEntry<S> toggled() => SortEntry(type, reverse: !reverse);

  static SortEntry<S>? fromJson<S extends Enum>(dynamic json, List<S> values) {
    if (json is! String) return null;
    final isReversed = json.startsWith(_kReversePrefix);
    final name = isReversed ? json.substring(_kReversePrefix.length) : json;
    final type = values.getEnum(name);
    if (type == null) return null;
    return SortEntry(type, reverse: isReversed);
  }

  String toJson() => reverse ? '$_kReversePrefix${type.name}' : type.name;

  /// plain sort names from older formats load as non-reversed entries, repeated types are dropped.
  static List<SortEntry<S>> listFromJson<S extends Enum>(dynamic json, List<S> values) {
    final entries = <SortEntry<S>>[];
    if (json is! List) return entries;
    for (final item in json) {
      final entry = fromJson(item, values);
      if (entry == null) continue;
      final type = entry.type;
      if (entries.any((e) => e.type == type)) continue;
      entries.add(entry);
    }
    return entries;
  }

  static List<String> listToJson<S extends Enum>(List<SortEntry<S>> entries) => entries.map((e) => e.toJson()).toFixedList();

  @override
  bool operator ==(Object other) => other is SortEntry<S> && other.type == type && other.reverse == reverse;

  @override
  int get hashCode => Object.hash(type, reverse);
}
