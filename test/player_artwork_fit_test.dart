// by claude
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/lang.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/packages/miniplayer.dart';
import 'package:namida/ui/widgets/artwork.dart';

void main() {
  const imageSizes = [
    Size(331, 522), Size(230, 358), Size(476, 771), //
    Size(100, 400), Size(300, 300), Size(640, 360), Size(400, 100),
  ];
  const boxSizes = [Size(200, 320), Size(320, 180), Size(250, 250)];

  Future<Uint8List> pngOf(Size size) async {
    final width = size.width.round();
    final height = size.height.round();
    final recorder = ui.PictureRecorder();
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()..color = const Color(0xFF3366CC);
    Canvas(recorder).drawRect(rect, paint);
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  Future<Size> pumpAndMeasure(WidgetTester tester, Size boxSize, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: boxSize.width,
            height: boxSize.height,
            child: Stack(
              alignment: Alignment.center,
              children: [child],
            ),
          ),
        ),
      ),
    );
    final rawImage = find.byType(RawImage);
    for (int i = 0; i < 50; i++) {
      final hasImage = tester.widgetList<RawImage>(rawImage).any((w) => w.image != null);
      if (hasImage) break;
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(tester.widget<RawImage>(rawImage).image, isNotNull);
    return tester.getSize(rawImage);
  }

  void expectSize(Size actual, Size expected, String reason) {
    expect(actual.width, closeTo(expected.width, 0.01), reason: reason);
    expect(actual.height, closeTo(expected.height, 0.01), reason: reason);
  }

  Size containSize(Size imageSize, Size boxSize) => applyBoxFit(BoxFit.contain, imageSize, boxSize).destination;

  late Directory root;

  setUpAll(() {
    root = Directory.systemTemp.createTempSync('namida_player_artwork_fit');
    AppDirs.USER_DATA = '${root.path}${Platform.pathSeparator}';
    Directory(AppDirs.ARTWORKS).createSync(recursive: true);
  });
  tearDownAll(() {
    try {
      root.deleteSync(recursive: true);
    } catch (_) {} // -- the player can still hold the files
  });

  group('ArtworkWidget given its box', () {
    for (final imageSize in imageSizes) {
      for (final boxSize in boxSizes) {
        testWidgets('${imageSize.width.round()}x${imageSize.height.round()} image in ${boxSize.width.round()}x${boxSize.height.round()} box is contained', (tester) async {
          final bytes = (await tester.runAsync(() => pngOf(imageSize)))!;
          final painted = await pumpAndMeasure(
            tester,
            boxSize,
            ArtworkWidget(
              key: UniqueKey(),
              bytes: bytes,
              extractInternally: false,
              compressed: false,
              fadeMilliSeconds: 0,
              thumbnailSize: boxSize.width,
              width: boxSize.width,
              height: boxSize.height,
            ),
          );
          expectSize(painted, containSize(imageSize, boxSize), 'painted size');
        });
      }
    }

    testWidgets('forceSquared fills a square box', (tester) async {
      const imageSize = Size(331, 522);
      const boxSize = Size(250, 250);
      final bytes = (await tester.runAsync(() => pngOf(imageSize)))!;
      final painted = await pumpAndMeasure(
        tester,
        boxSize,
        ArtworkWidget(
          key: UniqueKey(),
          bytes: bytes,
          extractInternally: false,
          compressed: false,
          fadeMilliSeconds: 0,
          forceSquared: true,
          thumbnailSize: boxSize.width,
          width: boxSize.width,
          height: boxSize.height,
        ),
      );
      expectSize(painted, boxSize, 'painted size');
    });
  });

  group('player artwork', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      Language.inst.update(language: NamidaLanguage.fromCode('en'));
      await Player.inst.initializePlayer();
      final animation = MiniPlayerController.inst.initialize(const TestVSync());
      animation.value = 1.0;
    });

    Future<Track> trackWithArtwork(WidgetTester tester, Size imageSize, String name) async {
      final track = Track.explicit('${AppDirs.USER_DATA}$name.m4a');
      final bytes = (await tester.runAsync(() => pngOf(imageSize)))!;
      File(track.pathToImage).writeAsBytesSync(bytes);
      return track;
    }

    for (final imageSize in imageSizes) {
      final name = 'player_${imageSize.width.round()}x${imageSize.height.round()}';
      testWidgets('$name fills the box shaped by its own ratio', (tester) async {
        final track = await trackWithArtwork(tester, imageSize, name);
        const maxSide = 300.0;
        final ratio = imageSize.width / imageSize.height;
        final boxSize = ratio < 1 ? Size(maxSide * ratio, maxSide) : Size(maxSide, maxSide / ratio);
        final painted = await pumpAndMeasure(
          tester,
          boxSize,
          MiniplayerArtwork(
            item: track,
            lyricsMaxSize: ValueNotifier(boxSize),
            showLyricsOverlay: false,
          ),
        );
        expectSize(painted, boxSize, 'painted size');
      });

      for (final boxSize in boxSizes) {
        testWidgets('$name in a ${boxSize.width.round()}x${boxSize.height.round()} box of another item is contained', (tester) async {
          final track = await trackWithArtwork(tester, imageSize, name);
          final painted = await pumpAndMeasure(
            tester,
            boxSize,
            MiniplayerArtwork(
              item: track,
              lyricsMaxSize: ValueNotifier(boxSize),
              showLyricsOverlay: false,
            ),
          );
          expectSize(painted, containSize(imageSize, boxSize), 'painted size');
        });
      }
    }
  });
}
