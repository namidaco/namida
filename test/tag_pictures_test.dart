// by claude
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_taglib/flutter_taglib.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/faudiomodel.dart';
import 'package:namida/class/taglib_res.dart';

void main() {
  const frontCover = 'Front Cover';
  const backCover = 'Back Cover';
  const other = 'Other';
  const artist = 'Artist';

  const typedFormats = ['mp3', 'wav', 'aiff', 'tta', 'flac', 'ogg', 'opus', 'wma'];
  const apeFormats = ['ape', 'wv', 'mpc'];
  const untypedFormats = ['m4a', 'mka'];
  const unorderedFormats = {'wma'}; // -- taglib's asf writer moves the first picture last

  const signatures = {
    'image/jpeg': [0xFF, 0xD8, 0xFF, 0xE0],
    'image/png': [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
    'image/webp': [0x52, 0x49, 0x46, 0x46, 0x10, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50],
    'image/gif': [0x47, 0x49, 0x46, 0x38, 0x39, 0x61],
    'image/bmp': [0x42, 0x4D],
  };

  Uint8List image(String mimeType, int fill) => Uint8List.fromList([...signatures[mimeType]!, ...List.filled(64, fill)]);

  final oldFront = image('image/jpeg', 1);
  final back = image('image/jpeg', 2);
  final otherPicture = image('image/jpeg', 3);
  final artistPicture = image('image/jpeg', 4);
  final newFront = image('image/png', 5);

  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('namida_tag_pictures'));
  tearDown(() => dir.deleteSync(recursive: true));

  String copyFixture(String ext) {
    final path = '${dir.path}/pictures.$ext';
    File('test/fixtures/audio/rating.$ext').copySync(path);
    return path;
  }

  void seed(String path, List<(String, Uint8List)> pictures) {
    final file = TagLibFile.open(path)!;
    try {
      final didSet = file.setPictures([for (final (type, bytes) in pictures) Picture(bytes: bytes, mimeType: 'image/jpeg', pictureType: type)]);
      expect(didSet, isTrue);
      expect(file.save(), isTrue);
    } finally {
      file.close();
    }
  }

  List<Picture> readPictures(String path) {
    final file = TagLibFile.open(path)!;
    try {
      return file.pictures;
    } finally {
      file.close();
    }
  }

  void writeCover(String path, Uint8List coverBytes) {
    final error = TagLibRes.writeSync(
      path,
      newPropertiesMap: {},
      ratingPercentage: null,
      artwork: FArtwork(bytes: coverBytes),
      chapters: null,
    );
    expect(error, isNull);
  }

  void expectPictures(String path, List<(String, Uint8List)> expected, {bool checkTypes = true}) {
    final pictures = readPictures(path);
    final entries = pictures.map((e) => [if (checkTypes) e.pictureType, e.bytes]).toList();
    final expectedEntries = expected.map((e) => [if (checkTypes) e.$1, e.$2]).toList();
    final ext = path.split('.').last;
    final isOrderKept = !unorderedFormats.contains(ext);
    expect(entries, isOrderKept ? expectedEntries : unorderedEquals(expectedEntries));
  }

  for (final ext in [...typedFormats, ...apeFormats]) {
    group(ext, () {
      test('a new cover replaces the front cover only', () async {
        final path = copyFixture(ext);
        seed(path, [(frontCover, oldFront), (backCover, back)]);
        writeCover(path, newFront);
        expectPictures(path, [(frontCover, newFront), (backCover, back)]);

        final front = readPictures(path).first;
        if (!apeFormats.contains(ext)) expect(front.mimeType, 'image/png');

        final res = await TagLibRes.read(path, extractArtwork: true);
        expect(res!.properties.artwork!.bytes, newFront);
        expect(TagLibRes.readPictureOfTypeSync(path, backCover), back);
      });

      test('removing the cover keeps the back cover, which is not read as the cover', () async {
        final path = copyFixture(ext);
        seed(path, [(frontCover, oldFront), (backCover, back)]);
        writeCover(path, Uint8List(0));
        expectPictures(path, [(backCover, back)]);

        final res = await TagLibRes.read(path, extractArtwork: true);
        expect(res!.properties.artwork?.bytes, isNull);
      });

      test('a file with no pictures gets the cover', () {
        final path = copyFixture(ext);
        writeCover(path, newFront);
        expectPictures(path, [(frontCover, newFront)]);
      });
    });
  }

  for (final ext in typedFormats) {
    group(ext, () {
      test('with no front cover, the Other picture is the cover', () {
        final path = copyFixture(ext);
        seed(path, [(backCover, back), (other, otherPicture)]);
        writeCover(path, newFront);
        expectPictures(path, [(backCover, back), (frontCover, newFront)]);

        seed(path, [(backCover, back), (other, otherPicture)]);
        writeCover(path, Uint8List(0));
        expectPictures(path, [(backCover, back)]);
      });

      test('with no front cover, the first picture that is not a back cover is the cover', () {
        final path = copyFixture(ext);
        seed(path, [(backCover, back), (artist, artistPicture)]);
        writeCover(path, newFront);
        expectPictures(path, [(backCover, back), (frontCover, newFront)]);

        seed(path, [(backCover, back), (artist, artistPicture)]);
        writeCover(path, Uint8List(0));
        expectPictures(path, [(backCover, back)]);
      });

      test('with only a back cover, the new one goes first and the back cover stays', () {
        final path = copyFixture(ext);
        seed(path, [(backCover, back)]);
        writeCover(path, newFront);
        expectPictures(path, [(frontCover, newFront), (backCover, back)]);

        seed(path, [(backCover, back)]);
        writeCover(path, Uint8List(0));
        expectPictures(path, [(backCover, back)]);
      });

      test('the front cover is replaced in place', () {
        final path = copyFixture(ext);
        seed(path, [(backCover, back), (frontCover, oldFront), (artist, artistPicture)]);
        writeCover(path, newFront);
        expectPictures(path, [(backCover, back), (frontCover, newFront), (artist, artistPicture)]);
      });

      test('mime type follows the image bytes', () {
        final path = copyFixture(ext);
        for (final mimeType in signatures.keys) {
          writeCover(path, image(mimeType, 6));
          expect(readPictures(path).single.mimeType, mimeType, reason: mimeType);
        }
      });
    });
  }

  for (final ext in untypedFormats) {
    group(ext, () {
      test('a new cover replaces the first picture only', () async {
        final path = copyFixture(ext);
        seed(path, [(frontCover, oldFront), (backCover, back)]);
        writeCover(path, newFront);
        expectPictures(path, [(frontCover, newFront), (frontCover, back)], checkTypes: false);
        expect(readPictures(path).first.mimeType, 'image/png');

        final res = await TagLibRes.read(path, extractArtwork: true);
        expect(res!.properties.artwork!.bytes, newFront);
      });

      test('removing the cover keeps the other pictures', () {
        final path = copyFixture(ext);
        seed(path, [(frontCover, oldFront), (backCover, back)]);
        writeCover(path, Uint8List(0));
        expectPictures(path, [(frontCover, back)], checkTypes: false);
      });
    });
  }
}
