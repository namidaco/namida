// by claude
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/thumbnail_square_cover.dart';

void main() {
  /// [width]x[height] filled with [barColor], with a busy pattern inside the content box.
  Uint8List buildImage({
    required int width,
    required int height,
    required List<int> barColor,
    required int contentLeft,
    required int contentWidth,
    int contentTop = 0,
    int? contentHeight,
    int barNoise = 0,
    int letterboxRows = 0,
  }) {
    final pixels = Uint8List(width * height * 4);
    final contentBottom = contentTop + (contentHeight ?? height - contentTop);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final offset = (y * width + x) * 4;
        final isLetterbox = y < letterboxRows || y >= height - letterboxRows;
        final isContent = !isLetterbox && x >= contentLeft && x < contentLeft + contentWidth && y >= contentTop && y < contentBottom;
        for (int c = 0; c < 3; c++) {
          final int value;
          if (isLetterbox) {
            value = 0;
          } else if (isContent) {
            value = (x * 37 + y * 91 + c * 53) % 256;
          } else {
            final noise = barNoise == 0 ? 0 : ((x * 7 + y * 13 + c) % (barNoise * 2 + 1)) - barNoise;
            value = (barColor[c] + noise).clamp(0, 255);
          }
          pixels[offset + c] = value;
        }
        pixels[offset + 3] = 255;
      }
    }
    return pixels;
  }

  test('square cover between black bars', () {
    final pixels = buildImage(
      width: 128,
      height: 72,
      barColor: const [0, 0, 0],
      contentLeft: 28,
      contentWidth: 72,
    );
    expect(ThumbnailSquareCover.findSquareCoverRows(pixels, 128, 72), (top: 0.0, bottom: 1.0));
  });

  test('colored and noisy bars', () {
    final pixels = buildImage(
      width: 128,
      height: 72,
      barColor: const [40, 90, 30],
      contentLeft: 28,
      contentWidth: 72,
      barNoise: 8,
    );
    expect(ThumbnailSquareCover.findSquareCoverRows(pixels, 128, 72), (top: 0.0, bottom: 1.0));
  });

  test('round cover a bit narrower than the square', () {
    final pixels = buildImage(
      width: 128,
      height: 72,
      barColor: const [0, 0, 0],
      contentLeft: 32,
      contentWidth: 64,
    );
    expect(ThumbnailSquareCover.findSquareCoverRows(pixels, 128, 72), (top: 0.0, bottom: 1.0));
  });

  test('letterboxed 4:3 thumbnail', () {
    final pixels = buildImage(
      width: 128,
      height: 96,
      barColor: const [0, 0, 0],
      contentLeft: 28,
      contentWidth: 72,
      letterboxRows: 12,
    );
    expect(ThumbnailSquareCover.findSquareCoverRows(pixels, 128, 96), (top: 12 / 96, bottom: 84 / 96));
  });

  test('portrait videos, full frames, plain images and off center covers are not square covers', () {
    final portrait = buildImage(width: 128, height: 72, barColor: const [0, 0, 0], contentLeft: 44, contentWidth: 40);
    final fullFrame = buildImage(width: 128, height: 72, barColor: const [0, 0, 0], contentLeft: 0, contentWidth: 128);
    final plain = buildImage(width: 128, height: 72, barColor: const [200, 120, 120], contentLeft: 0, contentWidth: 0);
    final offCenter = buildImage(width: 128, height: 72, barColor: const [0, 0, 0], contentLeft: 16, contentWidth: 72);
    final wide = buildImage(width: 128, height: 72, barColor: const [0, 0, 0], contentLeft: 20, contentWidth: 88);
    for (final pixels in [portrait, fullFrame, plain, offCenter, wide]) {
      expect(ThumbnailSquareCover.findSquareCoverRows(pixels, 128, 72), null);
    }
  });
}
