// ignore_for_file: avoid_rx_value_getter_outside_obx
import 'dart:collection';

import 'package:namida/class/track.dart';
import 'package:namida/core/utils.dart';

class LibraryItemMap extends LibraryItemMapRaw<String> {
  LibraryItemMap()
    : super(
        equals: (item1, item2) => item1.toLowerCase() == item2.toLowerCase(),
        hashCode: (p0) => p0.toLowerCase().hashCode,
      );
}

class LibraryItemMapRaw<K> {
  LibraryItemMapRaw({
    required bool Function(K, K) equals,
    required int Function(K)? hashCode,
  }) : _rxMap = LinkedHashMap<K, List<Track>>(
         equals: equals,
         hashCode: hashCode,
       ).obs;

  RxBaseCore<LinkedHashMap<K, List<Track>>> get rx => _rxMap;

  // -- never use `HashMap`, its unsorted nature messes up lists sorting.
  final Rx<LinkedHashMap<K, List<Track>>> _rxMap;
  LinkedHashMap<K, List<Track>> get value => _rxMap.value;
  LinkedHashMap<K, List<Track>> get valueR => _rxMap.valueR;
  void refresh() => _rxMap.refresh();
  void clear() {
    _rxMap.value.clear();
    refresh();
  }

  void update(LibraryItemMapRaw<K> other) {
    _rxMap.value = other.value;
  }
}
