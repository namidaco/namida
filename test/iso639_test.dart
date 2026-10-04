// by claude
import 'package:flutter_test/flutter_test.dart';

import 'package:namida/core/iso639.dart';

void main() {
  group('resolve', () {
    test('639-1, 639-2/B, 639-2/T and 639-3 codes', () {
      expect(Iso639.resolve('en'), 'eng');
      expect(Iso639.resolve('eng'), 'eng');
      expect(Iso639.resolve('ger'), 'deu');
      expect(Iso639.resolve('deu'), 'deu');
      expect(Iso639.resolve('chi'), 'zho');
      expect(Iso639.resolve('cmn'), 'cmn');
    });

    test('case, spaces and regions are ignored', () {
      expect(Iso639.resolve(' EN '), 'eng');
      expect(Iso639.resolve('en-US'), 'eng');
      expect(Iso639.resolve('pt_BR'), 'por');
      expect(Iso639.resolve('zh-Hans'), 'zho');
    });

    test('names, aliases and labels', () {
      expect(Iso639.resolve('English'), 'eng');
      expect(Iso639.resolve('japanese'), 'jpn');
      expect(Iso639.resolve('Instrumental'), 'zxx');
      expect(Iso639.resolve('not applicable'), 'zxx');
      expect(Iso639.resolve('multiple'), 'mul');
      expect(Iso639.resolve('missing'), 'mis');
      expect(Iso639.resolve('unknown'), 'und');
      expect(Iso639.resolve('English (eng)'), 'eng');
    });

    test('unknown values', () {
      expect(Iso639.resolve(''), null);
      expect(Iso639.resolve('klingon-ish'), null);
      expect(Iso639.resolve('xxxx'), null);
    });
  });

  group('splitToLabels', () {
    test('empty tag costs nothing', () {
      expect(Iso639.splitToLabels(null), const []);
      expect(Iso639.splitToLabels(''), const []);
    });

    test('multi value, duplicates merge into one label', () {
      expect(Iso639.splitToLabels('eng; spa'), ['English (eng)', 'Spanish (spa)']);
      expect(Iso639.splitToLabels('en/English,eng'), ['English (eng)']);
      expect(Iso639.splitToLabels('jpn|kor'), ['Japanese (jpn)', 'Korean (kor)']);
    });

    test('unknown values are kept as they are', () {
      expect(Iso639.splitToLabels('eng, Elvish'), ['English (eng)', 'Elvish']);
    });

    test('special codes get music friendly names', () {
      expect(Iso639.labelOf('zxx'), 'Instrumental (zxx)');
      expect(Iso639.labelOf('ell'), 'Greek (ell)');
    });
  });

  test('part1Of', () {
    expect(Iso639.part1Of('eng'), 'en');
    expect(Iso639.part1Of('cmn'), null);
  });
}
