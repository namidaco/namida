import 'dart:typed_data';

/// Lower case key that ignores diacritics & orders digit runs by value, comparable using [String.compareTo].
///
/// by claude
class SortKey {
  static const _latinExtendedStart = 0xC0;
  static const _latinExtendedEnd = 0x24F;
  static const _latinExtendedAdditionalStart = 0x1E00;
  static const _latinExtendedAdditionalEnd = 0x1EFF;
  static const _maxDigitsCountPrefix = 15;
  static const _combiningMarksStart = 0x300;
  static const _combiningMarksEnd = 0x36F;
  static const _digitZero = 0x30;
  static const _digitNine = 0x39;

  /// char at `codeUnit - start` is the base letter of that code unit, `ÀÁÂÃÄÅ` => `aaaaaa`. generated from unicode decompositions.
  static const _baseLettersOfLatinExtended =
      'aaaaaa\u00C6ceeeeiiiidnooooo\u00D7ouuuuy\u00DE\u00DFaaaaaa\u00E6ceeeeiiiidnooooo\u00F7ouuuuy\u00FEyaaaaaaccccccccddddeeeeeeeeeegggggggghhhhiiiiiiiiii'
      '\u0132\u0133jjkkkllllllllllnnnnnn\u0149nnoooooo\u0152\u0153rrrrrrssssssssttttttuuuuuuuuuuuuwwyyyzzzzzz\u017Fb\u0181\u0182\u0183\u0184\u0185\u0186'
      '\u0187\u0188\u0189\u018A\u018B\u018C\u018D\u018E\u018F\u0190\u0191\u0192\u0193\u0194\u0195\u0196i\u0198\u0199l\u019B\u019C\u019D\u019E\u019Foo\u01A2'
      '\u01A3\u01A4\u01A5\u01A6\u01A7\u01A8\u01A9\u01AA\u01AB\u01AC\u01AD\u01AEuu\u01B1\u01B2\u01B3\u01B4\u01B5z\u01B7\u01B8\u01B9\u01BA\u01BB\u01BC\u01BD'
      '\u01BE\u01BF\u01C0\u01C1\u01C2\u01C3\u01C4\u01C5\u01C6\u01C7\u01C8\u01C9\u01CA\u01CB\u01CCaaiioouuuuuuuuuu\u01DDaaaa\u01E2\u01E3ggggkkoooo\u01EE\u01EF'
      'j\u01F1\u01F2\u01F3gg\u01F6\u01F7nnaa\u01FC\u01FD\u01FE\u01FFaaaaeeeeiiiioooorrrruuuusstt\u021C\u021Dhh\u0220\u0221\u0222\u0223\u0224\u0225aaeeooooooo'
      'oyy\u0234\u0235\u0236\u0237\u0238\u0239acc\u023Dt\u023F\u0240\u0241\u0242bu\u0245eejj\u024A\u024Brryy';

  static const _baseLettersOfLatinExtendedAdditional =
      'aabbbbbbccddddddddddeeeeeeeeeeffgghhhhhhhhhhiiiikkkkkkllllllllmmmmmmnnnnnnnnoooooooopppprrrrrrrrssssssssssttttttttuuuuuuuuuuvvvvwwwwwwwwwwxxxxyyzzzzzz'
      'htwy\u1E9A\u1E9B\u1E9C\u1E9D\u1E9E\u1E9Faaaaaaaaaaaaaaaaaaaaaaaaeeeeeeeeeeeeeeeeiiiioooooooooooooooooooooooouuuuuuuuuuuuuuyyyyyyyy\u1EFA\u1EFB\u1EFC'
      '\u1EFD\u1EFE\u1EFF';

  static var _buffer = Uint16List(256);

  static String of(String text) {
    final length = text.length;
    var i = 0;
    for (; i < length; i++) {
      final codeUnit = text.codeUnitAt(i);
      if (codeUnit >= _latinExtendedStart || (codeUnit >= _digitZero && codeUnit <= _digitNine)) break;
    }
    // -- plain ascii without digits, which is most texts, only needs the native lower casing
    if (i == length) return text.toLowerCase();

    if (_buffer.length < length * 2 + 2) _buffer = Uint16List(length * 4 + 2);
    final buffer = _buffer;
    var outputLength = 0;
    for (var k = 0; k < i; k++) {
      buffer[outputLength++] = text.codeUnitAt(k);
    }

    while (i < length) {
      final codeUnit = text.codeUnitAt(i);
      if (codeUnit >= _digitZero && codeUnit <= _digitNine) {
        var digitsStart = i;
        i++;
        while (i < length) {
          final digit = text.codeUnitAt(i);
          if (digit < _digitZero || digit > _digitNine) break;
          i++;
        }
        while (digitsStart < i - 1 && text.codeUnitAt(digitsStart) == _digitZero) {
          digitsStart++;
        }
        // -- digits count goes first so that longer numbers compare bigger, `2` => `12` & `10` => `210`
        final digitsCount = i - digitsStart;
        buffer[outputLength++] = _digitZero + (digitsCount > _maxDigitsCountPrefix ? _maxDigitsCountPrefix : digitsCount);
        for (var k = digitsStart; k < i; k++) {
          buffer[outputLength++] = text.codeUnitAt(k);
        }
        continue;
      }
      i++;
      if (codeUnit < _latinExtendedStart) {
        buffer[outputLength++] = codeUnit;
      } else if (codeUnit <= _latinExtendedEnd) {
        switch (codeUnit) {
          case 0xDF:
            buffer[outputLength++] = 0x73;
            buffer[outputLength++] = 0x73;
          case 0xC6 || 0xE6:
            buffer[outputLength++] = 0x61;
            buffer[outputLength++] = 0x65;
          case 0x152 || 0x153:
            buffer[outputLength++] = 0x6F;
            buffer[outputLength++] = 0x65;
          case 0xDE || 0xFE:
            buffer[outputLength++] = 0x74;
            buffer[outputLength++] = 0x68;
          default:
            buffer[outputLength++] = _baseLettersOfLatinExtended.codeUnitAt(codeUnit - _latinExtendedStart);
        }
      } else if (codeUnit >= _combiningMarksStart && codeUnit <= _combiningMarksEnd) {
        continue;
      } else if (codeUnit >= _latinExtendedAdditionalStart && codeUnit <= _latinExtendedAdditionalEnd) {
        buffer[outputLength++] = _baseLettersOfLatinExtendedAdditional.codeUnitAt(codeUnit - _latinExtendedAdditionalStart);
      } else {
        buffer[outputLength++] = codeUnit;
      }
    }
    return String.fromCharCodes(buffer, 0, outputLength).toLowerCase();
  }
}
