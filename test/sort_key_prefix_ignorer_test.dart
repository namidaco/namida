import 'package:flutter_test/flutter_test.dart';

import 'package:namida/core/sort_key.dart';

void main() {
  SortKeyPrefixIgnorer create(List<String> prefixes, {bool ignoreSymbols = true}) => SortKeyPrefixIgnorer(prefixes, ignoreSymbols: ignoreSymbols, normalize: SortKey.of);
  String keyOf(SortKeyPrefixIgnorer ignorer, String text) => ignorer.ignorePrefixes(SortKey.of(text));

  final english = create(const ['the ', 'a ', 'an ']);

  test('word prefixes', () {
    expect(keyOf(english, 'The Beatles'), 'beatles');
    expect(keyOf(english, 'A Perfect Circle'), 'perfect circle');
    expect(keyOf(english, 'The The'), 'the');
    expect(keyOf(english, 'The The Band'), 'band');
    expect(keyOf(english, 'Theory'), 'theory');
    expect(keyOf(english, 'A-ha'), 'a-ha');
    expect(keyOf(english, 'Anathema'), 'anathema');
  });

  test('leading symbols', () {
    expect(keyOf(english, '"Heroes"'), 'heroes"');
    expect(keyOf(english, "'Til Tuesday"), 'til tuesday');
    expect(keyOf(english, '...And Justice for All'), 'and justice for all');
    expect(keyOf(english, '... Baby One More Time'), 'baby one more time');
    expect(keyOf(english, '¿Dónde Están?'), 'donde estan?');
    expect(keyOf(english, '(What\'s the Story) Morning Glory?'), 'what\'s the story) morning glory?');
    expect(keyOf(english, '“The Quote”'), 'quote”');
    expect(keyOf(english, '「夜に駆ける」'), '夜に駆ける」');
    expect(keyOf(english, '♪ Song'), 'song');
    expect(keyOf(english, '🔥 Fire'), 'fire');
    expect(keyOf(english, '#1 Crush'), '11 crush');
    expect(keyOf(english, ' Leading Space'), 'leading space');
  });

  test('symbols mixed with prefixes', () {
    expect(keyOf(english, '"The Beatles"'), 'beatles"');
    expect(keyOf(english, 'The (Beatles)'), 'beatles)');
    expect(keyOf(english, '- The - A - Song'), 'song');
  });

  test('only symbols or prefixes keep their key', () {
    expect(keyOf(english, '!!!'), '!!!');
    expect(keyOf(english, '...'), '...');
    expect(keyOf(english, 'The '), 'the ');
    expect(keyOf(english, ''), '');
  });

  test('letters, digits & numbers stay', () {
    expect(keyOf(english, '1999'), '41999');
    expect(keyOf(english, '② Two'), '② two');
    expect(keyOf(english, '½ Half'), '½ half');
    expect(keyOf(english, 'Ángel'), 'angel');
    expect(keyOf(english, 'Кино'), 'кино');
  });

  test('long digit runs keep their count prefix', () {
    final timestampKey = SortKey.of('1683891234567.mp3');
    expect(english.ignorePrefixes(timestampKey), timestampKey);
    final fifteenPlusKey = SortKey.of('12345678901234567890');
    expect(english.ignorePrefixes(fifteenPlusKey), fifteenPlusKey);
    expect(keyOf(english, '?123'), '3123');
    expect(keyOf(english, ':1234567890'), SortKey.of('1234567890'));
  });

  test('sort order across digit lengths stays right', () {
    final names = ['9 Song', '#10 Song', '1234567890 Song', '"2" Song'];
    final keys = names.map((e) => keyOf(english, e)).toList()..sort();
    expect(keys, [SortKey.of('2" song'), SortKey.of('9 song'), SortKey.of('10 song'), SortKey.of('1234567890 song')]);
  });

  test('symbols off only trims spaces', () {
    final ignorer = create(const ['the '], ignoreSymbols: false);
    expect(keyOf(ignorer, '"The Beatles"'), '"the beatles"');
    expect(keyOf(ignorer, ' The Beatles'), 'beatles');
    expect(keyOf(ignorer, 'The  Beatles'), 'beatles');
  });

  test('symbol prefixes work with symbols off, longest first', () {
    final ignorer = create(const ['...', '... ', 'the '], ignoreSymbols: false);
    expect(keyOf(ignorer, '... Baby'), 'baby');
    expect(keyOf(ignorer, '...The Song'), 'song');
    expect(keyOf(ignorer, '"Quote'), '"quote');
  });

  test('prefixes are normalized like keys', () {
    final ignorer = create(const ['Él ', '  la ', '']);
    expect(keyOf(ignorer, 'El Último'), 'ultimo');
    expect(keyOf(ignorer, 'La Bamba'), 'bamba');
  });

  test('non ascii prefixes', () {
    final ignorer = create(const ['дж ']);
    expect(keyOf(ignorer, 'Дж Song'), 'song');
    expect(keyOf(ignorer, 'Джаз'), 'джаз');
  });

  test('ignored length maps back to plain ascii text', () {
    int ignoredLengthOf(String text) => english.ignoredLengthOf(SortKey.of(text));
    expect(ignoredLengthOf('The Beatles'), 4);
    expect(ignoredLengthOf('...And Justice for All'), 3);
    expect(ignoredLengthOf('"A Perfect Circle"'), 3);
    expect(ignoredLengthOf('Beatles'), 0);
    expect(ignoredLengthOf('!!!'), 0);
    expect(create(const ['the '], ignoreSymbols: false).ignoredLengthOf(SortKey.of('...And')), 0);
  });

  test('lone surrogate at the end does not throw', () {
    expect(english.ignorePrefixes('\uD83D'), '\uD83D');
    expect(english.ignorePrefixes('\uD83C'), '\uD83C');
  });
}
