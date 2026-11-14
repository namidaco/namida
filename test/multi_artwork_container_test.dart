// by claude
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:namida/core/constants.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/library/multi_artwork_container.dart';

void main() {
  late Directory dir;
  final sep = Platform.pathSeparator;
  final pngBytes = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('namida_multi_artwork_container_test');
    AppDirs.USER_DATA = '${dir.path}$sep';
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  Future<void> pumpContainer(WidgetTester tester, File artworkFile) async {
    final theme = AppThemes.inst.getAppTheme(null, true);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: NTheme(
          data: theme,
          child: Center(
            child: MultiArtworkContainer(
              heroTag: 'multi_artwork_container_test',
              size: 60.0,
              tracks: const [],
              artworkFile: artworkFile,
              fadeMilliSeconds: 0,
            ),
          ),
        ),
      ),
    );
  }

  Finder customArtworkOf(File artworkFile) => find.byKey(ValueKey(artworkFile.path));

  Future<void> disposeAndFlushTimers(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('switches between the custom artwork and the collage when the file is set or removed', (tester) async {
    final artworkFile = File('${dir.path}${sep}custom.png');
    await pumpContainer(tester, artworkFile);
    expect(customArtworkOf(artworkFile), findsNothing);

    artworkFile.writeAsBytesSync(pngBytes);
    ArtworkWidget.refreshImageFiles([artworkFile.path]);
    await tester.pump();
    expect(customArtworkOf(artworkFile), findsOneWidget);

    artworkFile.deleteSync();
    ArtworkWidget.refreshImageFiles([artworkFile.path]);
    await tester.pump();
    expect(customArtworkOf(artworkFile), findsNothing);

    await disposeAndFlushTimers(tester);
    artworkFile.writeAsBytesSync(pngBytes);
    ArtworkWidget.refreshImageFiles([artworkFile.path]);
    await tester.pump();
    artworkFile.deleteSync();
  });

  testWidgets('a bulk refresh picks up files written without a per path refresh', (tester) async {
    final artworkFile = File('${dir.path}${sep}bulk.png');
    await pumpContainer(tester, artworkFile);
    artworkFile.writeAsBytesSync(pngBytes);
    await pumpContainer(tester, artworkFile);
    expect(customArtworkOf(artworkFile), findsNothing);

    ArtworkWidget.refreshAllImageFiles();
    await tester.pump();
    expect(customArtworkOf(artworkFile), findsOneWidget);

    artworkFile.deleteSync();
    ArtworkWidget.refreshAllImageFiles();
    await tester.pump();
    expect(customArtworkOf(artworkFile), findsNothing);
    await disposeAndFlushTimers(tester);
  });

  testWidgets('every refresh gives the image a key no earlier one had', (tester) async {
    final path = '${dir.path}${sep}keys.png';
    final otherPath = '${dir.path}${sep}other_keys.png';
    final keys = <ImageProvider>[ArtworkWidget.fileImageOf(path)];

    ArtworkWidget.refreshImageFiles([path]);
    keys.add(ArtworkWidget.fileImageOf(path));
    ArtworkWidget.refreshAllImageFiles();
    keys.add(ArtworkWidget.fileImageOf(path));
    ArtworkWidget.refreshImageFiles([path]);
    keys.add(ArtworkWidget.fileImageOf(path));
    ArtworkWidget.refreshImageFiles([otherPath]);
    keys.add(ArtworkWidget.fileImageOf(path));

    expect(keys[4], keys[3]);
    final distinctKeys = keys.take(4).toSet();
    expect(distinctKeys.length, 4);
  });

  testWidgets('follows a new artwork file after a rebuild with another path', (tester) async {
    final firstFile = File('${dir.path}${sep}first.png');
    final secondFile = File('${dir.path}${sep}second.png');
    secondFile.writeAsBytesSync(pngBytes);
    await pumpContainer(tester, firstFile);
    expect(customArtworkOf(firstFile), findsNothing);

    await pumpContainer(tester, secondFile);
    expect(customArtworkOf(secondFile), findsOneWidget);

    secondFile.deleteSync();
    ArtworkWidget.refreshImageFiles([secondFile.path]);
    await tester.pump();
    expect(customArtworkOf(secondFile), findsNothing);
    await disposeAndFlushTimers(tester);
  });
}
