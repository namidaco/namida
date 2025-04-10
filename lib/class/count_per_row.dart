// ignore_for_file: unused_field

import 'package:namida/core/dimensions.dart';

class CountPerRow {
  int get rawValue => _recommended;

  final int _recommended;
  final bool _hardCoded;

  const CountPerRow(this._recommended) : _hardCoded = false;
  const CountPerRow._hardCoded(this._recommended) : _hardCoded = true;

  static CountPerRow? fromJsonValue(dynamic jsonValue) {
    if (jsonValue is! int) return null;
    return CountPerRow(jsonValue);
  }

  CountPerRow getNext({int minimum = 1}) {
    final current = this;
    final maximum = CountPerRow.getRecommendedMaximum(minimum: minimum);
    final toAdd = 1;
    final n = current._recommended;
    return CountPerRow._hardCoded(n < maximum ? n + toAdd : minimum);
  }

  static Iterable<CountPerRow> getAvailableOptions() sync* {
    final start = 1;
    final end = getRecommendedMaximum(minimum: start);
    for (int i = start; i <= end; i++) {
      yield CountPerRow._hardCoded(i);
    }
  }

  // -- currently we just use hardcoded +1 incremental values
  int resolve() {
    return _recommended;
  }

  // -- automatically adapts based on screen width (skips numbers)
  // int resolveOld() {
  //   if (_hardCoded) return _recommended;
  //   final availableWidth = Dimensions.inst.availableAppContentWidth;
  //   final p = availableWidth / 700;
  //   final newCount = _recommended + p.round();
  //   return newCount;
  // }

  static int getRecommendedMaximum({int minimum = 1}) {
    final availableWidth = Dimensions.inst.availableAppContentWidth;
    final maxy = (availableWidth * 0.015).round();
    return maxy.clamp(4, 11);
  }

  // doesnt count margin or padding
  double getRecommendedThumbnailSize() {
    final availableWidth = Dimensions.inst.availableAppContentWidth;
    final thumbnailSize = (availableWidth / _recommended);
    return thumbnailSize;
  }
}
