// by claude
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lrc/lrc.dart';

import 'package:namida/class/lang.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/simple_lyrics_line.dart';

void main() {
  const primaryText = "Don't tell me, are you after her too?";
  const translationText = 'もしや貴様もこの子を狙っているのか';
  const romajiText = 'moshiya kisamamo konokowo nerratteiru no ka';
  final lrc = LrcParser.parse('[00:00.00]$primaryText\n[00:00.00]$translationText\n[00:00.00]$romajiText\n[00:10.00]next\n');
  final source = Rxn<Lrc>(lrc);

  late Directory root;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    root = Directory.systemTemp.createTempSync('namida_simple_lyrics_line');
    AppDirs.USER_DATA = '${root.path}${Platform.pathSeparator}';
    Language.inst.update(language: NamidaLanguage.fromCode('en'));
    await Player.inst.initializePlayer();
  });
  tearDownAll(() {
    try {
      root.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<void> pumpInBox(WidgetTester tester, Size boxSize, {required bool wrapSecondaryLines}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: boxSize.width,
            height: boxSize.height,
            child: Center(
              child: SimpleLyricsLineWidget(
                customSourceRx: source,
                stretchToItemDuration: false,
                karaoke: false,
                maxLines: 3,
                softWrap: true,
                fitToWidth: true,
                maxSecondaryLines: 2,
                wrapSecondaryLines: wrapSecondaryLines,
                style: const TextStyle(fontSize: 20.0),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Iterable<Text> secondaryTexts(WidgetTester tester) {
    return tester.widgetList<Text>(find.byType(Text)).where((e) => e.data == translationText || e.data == romajiText);
  }

  bool secondaryOverflows(WidgetTester tester, String text) {
    final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
    return paragraph.didExceedMaxLines;
  }

  double blockHeight(WidgetTester tester) => tester.getSize(find.byType(Column)).height;

  testWidgets('tall box lets secondary lines wrap fully', (tester) async {
    const boxSize = Size(300.0, 400.0);
    await pumpInBox(tester, boxSize, wrapSecondaryLines: true);
    final texts = secondaryTexts(tester).toList();
    expect(texts, hasLength(2));
    expect(texts.any((e) => e.maxLines! > 1), isTrue);
    expect(secondaryOverflows(tester, translationText), isFalse);
    expect(secondaryOverflows(tester, romajiText), isFalse);
    expect(blockHeight(tester), lessThanOrEqualTo(boxSize.height));
  });

  testWidgets('short box keeps one line each', (tester) async {
    const boxSize = Size(300.0, 130.0);
    await pumpInBox(tester, boxSize, wrapSecondaryLines: true);
    final texts = secondaryTexts(tester).toList();
    expect(texts, hasLength(2));
    expect(texts.every((e) => e.maxLines == 1 && e.softWrap == false), isTrue);
  });

  for (final height in [160.0, 200.0, 240.0, 280.0]) {
    testWidgets('block never grows past a ${height.round()} box', (tester) async {
      final boxSize = Size(300.0, height);
      await pumpInBox(tester, boxSize, wrapSecondaryLines: true);
      expect(blockHeight(tester), lessThanOrEqualTo(boxSize.height));
    });
  }

  testWidgets('without the flag secondary lines stay one line', (tester) async {
    const boxSize = Size(300.0, 400.0);
    await pumpInBox(tester, boxSize, wrapSecondaryLines: false);
    final texts = secondaryTexts(tester).toList();
    expect(texts, hasLength(2));
    expect(texts.every((e) => e.maxLines == 1 && e.softWrap == false), isTrue);
  });
}
