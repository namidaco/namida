// ignore_for_file: avoid_rx_value_getter_outside_obx
import 'dart:collection';

import 'package:namida/class/track.dart';
import 'package:namida/core/utils.dart';

class LibraryItemMap {
  LibraryItemMap() : _value = HashMap<String, List<Track>>(equals: (item1, item2) => item1.toLowerCase() == item2.toLowerCase(), hashCode: (p0) => p0.toLowerCase().hashCode).obs;
  final Rx<HashMap<String, List<Track>>> _value;
  HashMap<String, List<Track>> get value => _value.value;
  HashMap<String, List<Track>> get valueR => _value.valueR;
  void refresh() => _value.refresh();
  void clear() {
    _value.value.clear();
    refresh();
  }
}
