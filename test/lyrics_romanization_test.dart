// by claude
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lrc/lrc.dart';

import 'package:namida/controller/romanizer/romanizer.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';

void main() {
  late Directory dir;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('namida_romanization_test');
    AppDirs.USER_DATA = '${dir.path}${Platform.pathSeparator}';
    settings.romanizeLyrics.save(true);
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  List<String> displayedLines(String content) {
    final lrc = Lrc.parse(content);
    final romanizer = Romanizer.inst.lyricsRomanizer(lrc);
    final ui = lrc.forUiDisplay(0, romanizer: romanizer);
    return ui.uiLyricsLines.map((e) => e.readableText).where((e) => e.isNotEmpty).toList();
  }

  test('a line shipping its own romanization gets no generated copy', () {
    expect(displayedLines('[00:01.00]きみのなは\n[00:01.00]kimi no na wa'), ['きみのなは', 'kimi no na wa']);
  });

  test('long vowels written as macrons still count as the same romanization', () {
    expect(displayedLines('[00:01.00]とうきょう\n[00:01.00]Tōkyō'), ['とうきょう', 'Tōkyō']);
  });

  test('a translation sharing the timestamp keeps the generated romanization', () {
    expect(displayedLines('[00:01.00]さくら\n[00:01.00]cherry blossoms'), ['さくら', 'sakura', 'cherry blossoms']);
  });

  test('lines without siblings are romanized', () {
    expect(displayedLines('[00:01.00]さくら\n[00:05.00]hello'), ['さくら', 'sakura', 'hello']);
  });

  test('the same text is skipped only where its romanization ships with it', () {
    expect(displayedLines('[00:01.00]さくら\n[00:01.00]sakura\n[00:05.00]さくら'), ['さくら', 'sakura', 'さくら', 'sakura']);
  });
}
