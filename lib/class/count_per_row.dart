import 'package:namida/core/dimensions.dart';

class CountPerRow {
  int get rawValue => _recommended;

  final int _recommended;

  const CountPerRow(this._recommended);

  static CountPerRow? fromJsonValue(dynamic jsonValue) {
    if (jsonValue is! int) return null;
    return CountPerRow(jsonValue);
  }

  int resolve() {
    if (_recommended == 1) return _recommended;
    final availableWidth = Dimensions.inst.availableAppContentWidth;
    final p = availableWidth / 700;
    final newCount = _recommended + p.round();
    return newCount;
  }

  int getRecommendedMaximum({int minimum = 1}) {
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
