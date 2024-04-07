import 'dart:collection';

import 'package:get/get_rx/src/rx_types/rx_types.dart';

import 'package:namida/class/track.dart';

class LibraryItemMap {
  LibraryItemMap() : _value = LinkedHashMap<String, List<Track>>(equals: (item1, item2) => item1.toLowerCase() == item2.toLowerCase()).obs;
  final Rx<LinkedHashMap<String, List<Track>>> _value;
  LinkedHashMap<String, List<Track>> get value => _value.value;
  void refresh() => _value.refresh();
}
