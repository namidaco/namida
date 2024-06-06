// ignore_for_file: avoid_rx_value_getter_outside_obx
import 'dart:collection';

import 'package:namida/class/track.dart';
import 'package:namida/core/utils.dart';

class LibraryItemMap {
  LibraryItemMap() : _value = LinkedHashMap<String, List<Track>>(equals: (item1, item2) => item1.toLowerCase() == item2.toLowerCase()).obs;
  final Rx<LinkedHashMap<String, List<Track>>> _value;
  LinkedHashMap<String, List<Track>> get value => _value.value;
  LinkedHashMap<String, List<Track>> get valueR => _value.valueR;
  void refresh() => _value.refresh();
  void clear() {
    _value.value.clear();
    refresh();
  }
}
