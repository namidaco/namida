// by claude
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_taglib/flutter_taglib.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/core/constants.dart';

void main() {
  late Directory dir;
  final sep = Platform.pathSeparator;
  final cover = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, ...List.filled(64, 7)]);
  final customCover = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, ...List.filled(64, 9)]);

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('namida_artwork_custom_path_test');
    AppDirs.USER_DATA = '${dir.path}$sep';
    Directory(AppDirs.ARTWORKS).createSync(recursive: true);
    Directory(AppDirs.SMART_PLAYLISTS_ARTWORKS).createSync(recursive: true);
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  Track trackWithCover(String name) {
    final path = '${dir.path}$sep$name.mp3';
    File('test/fixtures/audio/rating.mp3').copySync(path);
    final file = TagLibFile.open(path)!;
    try {
      final didSet = file.setPictures([Picture(bytes: cover, mimeType: 'image/jpeg', pictureType: 'Front Cover')]);
      expect(didSet, isTrue);
      expect(file.save(), isTrue);
    } finally {
      file.close();
    }
    return Track.explicit(path);
  }

  String customPathOf(String name) => '${AppDirs.SMART_PLAYLISTS_ARTWORKS}$name.png';

  test('extracting into the track own cache still writes it', () async {
    final tr = trackWithCover('own');
    final res = await Indexer.inst.getArtwork(
      imagePath: tr.pathToImage,
      track: tr,
      compressed: false,
      checkFileFirst: false,
    );
    expect(res.bytes, cover);
    final cachedBytes = File(tr.pathToImage).readAsBytesSync();
    expect(cachedBytes, cover);
  });

  for (final compressed in [false, true]) {
    test('a missing custom path never gets the track art (compressed: $compressed)', () async {
      final tr = trackWithCover('missing_$compressed');
      final customPath = customPathOf('missing_$compressed');
      final res = await Indexer.inst.getArtwork(
        imagePath: customPath,
        track: tr,
        compressed: compressed,
        checkFileFirst: false,
      );
      expect(res.hasArtwork, isFalse);
      final didWriteCustom = File(customPath).existsSync();
      expect(didWriteCustom, isFalse);
    });
  }

  test('an existing custom path is still read and kept as is', () async {
    final tr = trackWithCover('existing');
    final customPath = customPathOf('existing');
    File(customPath).writeAsBytesSync(customCover);
    final res = await Indexer.inst.getArtwork(imagePath: customPath, track: tr, compressed: false);
    expect(res.file?.path, customPath);
    final customBytes = File(customPath).readAsBytesSync();
    expect(customBytes, customCover);
  });
}
