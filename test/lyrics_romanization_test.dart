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

  test('a romanization with extra text still counts', () {
    const romaji = 'Akaku tokekonda jouzai (Tu-ru-ru, tu-ru-ru-ru, tu)';
    expect(displayedLines('[00:01.00]あかくとけこんだじょうざい\n[00:01.00]$romaji'), ['あかくとけこんだじょうざい', romaji]);
  });

  test('latin words of the line itself can be left out of its romanization', () {
    expect(displayedLines('[00:01.00]ひいろにそまって (of destiny)\n[00:01.00]Hi-iro ni somatte'), ['ひいろにそまって (of destiny)', 'Hi-iro ni somatte']);
  });

  test('one romanization can cover several lines', () {
    const romaji = 'yokou shimamatou shujin famu-fataru';
    expect(displayedLines('[00:01.00]よこじままとう\n[00:01.00]しゅうじんファム・ファタール\n[00:01.00]$romaji'), ['よこじままとう', 'しゅうじんファム・ファタール', romaji]);
  });

  test('characters left unromanized match any reading', () {
    expect(displayedLines('[00:01.00]いわかんが殘業している\n[00:01.00]miagan ga zangyo shiteiru'), ['いわかんが殘業している', 'miagan ga zangyo shiteiru']);
  });

  test('a long translation keeps the generated romanization', () {
    const translation = 'I was calling your name, over and over again';
    expect(displayedLines('[00:01.00]きみのなまえをよんでいた\n[00:01.00]$translation'), ['きみのなまえをよんでいた', 'kiminonamaewoyondeita', translation]);
  });

  test('lyrics romanizing most lines get no generated copy on lines that failed to match', () {
    const lrc = '[00:01.00]さくら\n[00:01.00]sakura\n[00:02.00]きみのなは\n[00:02.00]kimi no na wa\n[00:03.00]あした\n[00:03.00]asu';
    expect(displayedLines(lrc), ['さくら', 'sakura', 'きみのなは', 'kimi no na wa', 'あした', 'asu']);
  });

  test('lyrics translating most lines keep the generated romanization', () {
    const lrc = '[00:01.00]さくら\n[00:01.00]sakura\n[00:02.00]あした\n[00:02.00]tomorrow\n[00:03.00]そら\n[00:03.00]sky';
    expect(displayedLines(lrc), ['さくら', 'sakura', 'あした', 'ashita', 'tomorrow', 'そら', 'sora', 'sky']);
  });

  test('a romanization written inside the line itself counts', () {
    expect(displayedLines('[00:01.00]かたくさいかいを (kataku saikai o)\n[00:05.00]さくら'), ['かたくさいかいを (kataku saikai o)', 'さくら', 'sakura']);
  });

  test('latin words of a line never count as its own romanization', () {
    expect(displayedLines('[00:01.00]oh yeah ぼくは'), ['oh yeah ぼくは', 'oh yeah bokuha']);
  });

  test('a sibling mixing japanese with the romanization still counts', () {
    const sibling = 'いturururu (kataku saikai o)';
    expect(displayedLines('[00:01.00]かたくさいかいを\n[00:01.00]$sibling\n[00:05.00]さくら'), ['かたくさいかいを', sibling, 'iturururu (kataku saikai o)', 'さくら', 'sakura']);
  });
}
