// ignore_for_file: avoid_rx_value_getter_outside_obx
import 'dart:collection';

import 'package:namida/class/track.dart';
import 'package:namida/core/utils.dart';

class LibraryItemMap {
  LibraryItemMap()
      : _rxMap = LinkedHashMap<String, List<Track>>(equals: (item1, item2) => item1.toLowerCase() == item2.toLowerCase(), hashCode: (p0) => p0.toLowerCase().hashCode).obs;

  RxBaseCore<LinkedHashMap<String, List<Track>>> get rx => _rxMap;

  // -- never use `HashMap`, its unsorted nature messes up lists sorting.
  final Rx<LinkedHashMap<String, List<Track>>> _rxMap;
  LinkedHashMap<String, List<Track>> get value => _rxMap.value;
  LinkedHashMap<String, List<Track>> get valueR => _rxMap.valueR;
  void refresh() => _rxMap.refresh();
  void clear() {
    _rxMap.value.clear();
    refresh();
  }

  void update(LibraryItemMap other) {
    _rxMap.value = other.value;
  }
}
