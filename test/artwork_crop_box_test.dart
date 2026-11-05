// by claude
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:namida/ui/dialogs/edit_tags_dialog.dart';

void main() {
  const imageSize = Size(1280, 720);

  test('starts as the largest centered square, or the whole image when free', () {
    expect(ArtworkCropBox(imageSize, aspectRatio: 1.0).rect, const Rect.fromLTWH(280, 0, 720, 720));
    expect(ArtworkCropBox(imageSize, aspectRatio: null).rect, const Rect.fromLTWH(0, 0, 1280, 720));
  });

  test('moving stays inside the image', () {
    final box = ArtworkCropBox(imageSize, aspectRatio: 1.0);
    box.move(const Offset(1000, 50));
    expect(box.rect, const Rect.fromLTWH(560, 0, 720, 720));
    box.move(const Offset(-5000, -5000));
    expect(box.rect, const Rect.fromLTWH(0, 0, 720, 720));
  });

  test('a free corner follows the drag while the opposite one stays', () {
    final box = ArtworkCropBox(imageSize, aspectRatio: null);
    box.dragCorner(Alignment.bottomRight, const Offset(640, 360));
    expect(box.rect, const Rect.fromLTWH(0, 0, 640, 360));
    box.dragCorner(Alignment.topLeft, const Offset(100, 50));
    expect(box.rect, const Rect.fromLTWH(100, 50, 540, 310));
  });

  test('a square corner takes the bigger side and stops at the image edge', () {
    final box = ArtworkCropBox(imageSize, aspectRatio: 1.0);
    box.dragCorner(Alignment.topLeft, const Offset(500, 100));
    expect(box.rect, const Rect.fromLTWH(380, 100, 620, 620));
    box.dragCorner(Alignment.topLeft, const Offset(-900, -900));
    expect(box.rect, const Rect.fromLTWH(280, 0, 720, 720));
  });

  test('the box never gets smaller than the minimum side', () {
    final box = ArtworkCropBox(imageSize, aspectRatio: null);
    box.dragCorner(Alignment.bottomRight, Offset.zero);
    expect(box.rect, const Rect.fromLTWH(0, 0, ArtworkCropBox.kMinSide, ArtworkCropBox.kMinSide));
  });

  test('switching the aspect ratio takes the largest box in the image around the current one', () {
    final box = ArtworkCropBox(imageSize, aspectRatio: null);
    box.dragCorner(Alignment.bottomRight, const Offset(600, 400));
    box.setAspectRatio(1.0);
    expect(box.rect, const Rect.fromLTWH(0, 0, 720, 720));
    box.setAspectRatio(9 / 16);
    expect(box.rect, const Rect.fromLTWH(157.5, 0, 405, 720));
    box.setAspectRatio(null);
    expect(box.rect, const Rect.fromLTWH(157.5, 0, 405, 720));
  });

  test('a 16:9 corner keeps the ratio and stops at the image edge', () {
    final box = ArtworkCropBox(imageSize, aspectRatio: 16 / 9);
    expect(box.rect, const Rect.fromLTWH(0, 0, 1280, 720));
    box.dragCorner(Alignment.bottomRight, const Offset(640, 100));
    expect(box.rect, const Rect.fromLTWH(0, 0, 640, 360));
  });

  test('corner touch finds the closest corner within reach only', () {
    final box = ArtworkCropBox(imageSize, aspectRatio: 1.0);
    expect(box.cornerAt(const Offset(285, 5), 20), Alignment.topLeft);
    expect(box.cornerAt(const Offset(995, 715), 20), Alignment.bottomRight);
    expect(box.cornerAt(const Offset(640, 360), 20), null);
  });
}
