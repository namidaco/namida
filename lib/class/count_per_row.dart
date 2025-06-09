// ignore_for_file: unused_field

import 'package:flutter/material.dart';

import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';

class CountPerRow {
  static const _autoSmall = _CountPerRowAuto(86.0);
  static const _auto = _CountPerRowAuto(128.0);
  static const _autoLarge = _CountPerRowAuto(164.0);
  static CountPerRow autoForTab(LibraryTab tab) => switch (tab) {
        LibraryTab.albums || LibraryTab.genres || LibraryTab.playlists => CountPerRow._autoLarge,
        LibraryTab.artists => CountPerRow._auto,
        _ => CountPerRow._auto,
      };

  bool get isAuto => rawValue < 1;
  int get rawValue => _recommended;

  final int _recommended;
  final bool _hardCoded;

  const CountPerRow(this._recommended) : _hardCoded = false;
  const CountPerRow._hardCoded(this._recommended) : _hardCoded = true;

  static CountPerRow? fromJsonValue(dynamic jsonValue) {
    if (jsonValue is! int) return null;
    return CountPerRow(jsonValue);
  }

  CountPerRow? getNext({int minimum = 1}) {
    if (this.isAuto) return null;
    final current = this;
    final maximum = CountPerRow.getRecommendedMaximum(minimum: minimum);
    final toAdd = 1;
    final n = current._recommended;
    return CountPerRow._hardCoded(n < maximum ? (n + toAdd).withMinimum(minimum) : minimum);
  }

  static Iterable<CountPerRow> getAvailableOptions() sync* {
    final start = 1;
    final end = getRecommendedMaximum(minimum: start);
    for (int i = start; i <= end; i++) {
      yield CountPerRow._hardCoded(i);
    }
  }

  // -- currently we just use hardcoded +1 incremental values
  int resolve(BuildContext context) {
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

  factory CountPerRow.getRecommended(BuildContext context, {required double comfortableWidth}) {
    double availableWidth = Dimensions.inst.availableAppContentWidthContext(context);
    double availableHeight = context.height;
    int count = (availableWidth ~/ comfortableWidth);
    count += (432.0 / availableHeight).round().withMinimum(0); // so that smaller heights get more counts per row
    return CountPerRow._hardCoded(count.clampInt(1, 11));
  }

  static int getRecommendedMaximum({int minimum = 1}) {
    final availableWidth = Dimensions.inst.availableAppContentWidth;
    final maxy = (availableWidth * 0.015).round();
    return maxy.clampInt(4, 11);
  }

  // doesnt count margin or padding
  double getRecommendedThumbnailSize() {
    final availableWidth = Dimensions.inst.availableAppContentWidth;
    final thumbnailSize = (availableWidth / _recommended);
    return thumbnailSize;
  }
}

class _CountPerRowAuto extends CountPerRow {
  final double comfortableWidth;
  const _CountPerRowAuto(this.comfortableWidth) : super(-1);

  @override
  int resolve(BuildContext context) {
    final recommended = CountPerRow.getRecommended(context, comfortableWidth: comfortableWidth);
    return recommended.resolve(context);
  }
}
