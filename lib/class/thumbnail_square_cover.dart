// by claude
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// thumbnails of static cover uploads (yt "- Topic" art tracks, cover-only releases on normal channels) hold a square cover
/// between solid side bars. decoding runs on the engine threads, the dart side only checks a small copy.
class ThumbnailSquareCover {
  static const _kAnalysisWidth = 128;
  static const _kMinBarWidthFraction = 0.08;
  static const _kMaxColorDifference = 16;
  static const _kMinBarPixelsFraction = 0.95;
  static const _kMinContentToSideRatio = 0.85;
  static const _kMaxContentOverSidePixels = 2;
  static const _kMaxOffCenterPixels = 2;
  static const _kMaxLetterboxLuma = 30;
  static const _kMinLetterboxedAspectRatio = 1.7;

  /// the square cover as fractions of the image size, null when [rgbaPixels] isn't a square cover between solid bars.
  static ({double top, double bottom})? findSquareCoverRows(Uint8List rgbaPixels, int width, int height) {
    int pixelOffset(int x, int y) => (y * width + x) * 4;

    bool isLetterboxRow(int y) {
      for (int x = 0; x < width; x++) {
        final offset = pixelOffset(x, y);
        final luma = (rgbaPixels[offset] * 299 + rgbaPixels[offset + 1] * 587 + rgbaPixels[offset + 2] * 114) ~/ 1000;
        if (luma > _kMaxLetterboxLuma) return false;
      }
      return true;
    }

    int top = 0;
    int bottom = height;
    final isLetterboxed = width / height < _kMinLetterboxedAspectRatio;
    if (isLetterboxed) {
      final maxTrimmedRows = height ~/ 4;
      while (top < maxTrimmedRows && isLetterboxRow(top)) {
        top++;
      }
      while (bottom > height - maxTrimmedRows && isLetterboxRow(bottom - 1)) {
        bottom--;
      }
    }
    final rowsCount = bottom - top;

    final barColor = Int32List(3);
    for (int y = top; y < bottom; y++) {
      final leftOffset = pixelOffset(0, y);
      final rightOffset = pixelOffset(width - 1, y);
      for (int c = 0; c < 3; c++) {
        barColor[c] += rgbaPixels[leftOffset + c] + rgbaPixels[rightOffset + c];
      }
    }
    for (int c = 0; c < 3; c++) {
      barColor[c] = barColor[c] ~/ (rowsCount * 2);
    }

    final minBarPixels = (rowsCount * _kMinBarPixelsFraction).ceil();
    bool isBarColumn(int x) {
      int barPixels = 0;
      for (int y = top; y < bottom; y++) {
        final offset = pixelOffset(x, y);
        final isBarPixel =
            (rgbaPixels[offset] - barColor[0]).abs() <= _kMaxColorDifference && //
            (rgbaPixels[offset + 1] - barColor[1]).abs() <= _kMaxColorDifference &&
            (rgbaPixels[offset + 2] - barColor[2]).abs() <= _kMaxColorDifference;
        if (isBarPixel) barPixels++;
      }
      return barPixels >= minBarPixels;
    }

    final minBarWidth = (width * _kMinBarWidthFraction).ceil();
    int contentLeft = 0;
    while (contentLeft < width && isBarColumn(contentLeft)) {
      contentLeft++;
    }
    if (contentLeft < minBarWidth) return null;
    int contentRight = width - 1;
    while (contentRight > contentLeft && isBarColumn(contentRight)) {
      contentRight--;
    }
    if (width - 1 - contentRight < minBarWidth) return null;

    final contentWidth = contentRight - contentLeft + 1;
    if (contentWidth > rowsCount + _kMaxContentOverSidePixels) return null;
    if (contentWidth < rowsCount * _kMinContentToSideRatio) return null;
    final offCenterDoubled = (contentLeft + contentRight + 1 - width).abs();
    if (offCenterDoubled > _kMaxOffCenterPixels * 2) return null;

    return (top: top / height, bottom: bottom / height);
  }

  /// [findSquareCoverRows] of a small copy of [thumbnailFile].
  static Future<({double top, double bottom})?> findSquareCoverRowsInFile(File thumbnailFile) async {
    final bytes = await thumbnailFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: _kAnalysisWidth);
    final frame = await codec.getNextFrame();
    codec.dispose();
    final image = frame.image;
    final width = image.width;
    final height = image.height;
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (byteData == null) return null;
    final rgbaPixels = byteData.buffer.asUint8List();
    return findSquareCoverRows(rgbaPixels, width, height);
  }
}
