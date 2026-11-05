import 'dart:typed_data';

import 'package:dart_extensions/dart_extensions.dart';

import 'package:namida/controller/romanizer/romanizer_engine.dart';

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
  static const _digitsCountPrefixSymbolsStart = 0x3A;
  static const _digitsCountPrefixEnd = _digitZero + _maxDigitsCountPrefix;

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

  static var _seenScripts = 0;
  static int get seenScripts => _seenScripts;

  /// lower case base letter of a latin letter with diacritics, [codeUnit] itself otherwise.
  static int baseLetterOf(int codeUnit) {
    if (codeUnit >= _latinExtendedStart && codeUnit <= _latinExtendedEnd) return _baseLettersOfLatinExtended.codeUnitAt(codeUnit - _latinExtendedStart);
    if (codeUnit >= _latinExtendedAdditionalStart && codeUnit <= _latinExtendedAdditionalEnd) {
      return _baseLettersOfLatinExtendedAdditional.codeUnitAt(codeUnit - _latinExtendedAdditionalStart);
    }
    return codeUnit;
  }

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
    var scripts = 0;
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
        scripts |= RomanizerEngine.scriptOf(codeUnit);
        buffer[outputLength++] = codeUnit;
      }
    }
    _seenScripts |= scripts;
    return String.fromCharCodes(buffer, 0, outputLength).toLowerCase();
  }

  /// code units taken by the symbol (punctuation, space, emoji..) at [index] of a key made by [of], 0 for letters & digits.
  static int _symbolLengthAt(String key, int index) {
    final codeUnit = key.codeUnitAt(index);
    return switch (codeUnit) {
      >= 0x61 && <= 0x7A || >= 0x30 && <= 0x39 || >= 0x41 && <= 0x5A => 0,
      >= _digitsCountPrefixSymbolsStart && <= _digitsCountPrefixEnd => _isDigitsCountPrefixAt(key, index, codeUnit) ? 0 : 1,
      < 0x80 => 1,
      0xAA || 0xB2 || 0xB3 || 0xB5 || 0xB9 || 0xBA || 0xBC || 0xBD || 0xBE => 0, // -- ª ² ³ µ ¹ º ¼ ½ ¾
      <= 0xBF => 1, // -- nbsp, ¡ ¿ « »
      >= 0x2000 && <= 0x206F => 1, // -- general punctuation, “ ” ‘ ’ …
      >= 0x20A0 && <= 0x20FF => 1, // -- currency, keycaps
      >= 0x2190 && <= 0x245F || >= 0x2500 && <= 0x2775 || >= 0x2794 && <= 0x2BFF => 1, // -- arrows, shapes, ♪ ★, without circled numbers
      >= 0x2E00 && <= 0x2E7F => 1,
      >= 0x3000 && <= 0x3004 || >= 0x3008 && <= 0x3020 || 0x3030 || 0x303D => 1, // -- 「」【】〜
      >= 0xFE00 && <= 0xFE6F => 1, // -- variation selectors, vertical & small forms
      >= 0xFF01 && <= 0xFF0F || >= 0xFF1A && <= 0xFF20 || >= 0xFF3B && <= 0xFF40 || >= 0xFF5B && <= 0xFF65 => 1, // -- fullwidth punctuation
      >= 0xD83C && <= 0xD83E => 2, // -- emoji
      _ => 0,
    };
  }

  /// digit runs of 10+ get a count prefix in `:;<=>?`, told apart from those symbols by the digits after it.
  static bool _isDigitsCountPrefixAt(String key, int index, int codeUnit) {
    final digitsCount = codeUnit - _digitZero;
    final length = key.length;
    var end = index + 1;
    while (end < length) {
      final digit = key.codeUnitAt(end);
      if (digit < _digitZero || digit > _digitNine) break;
      end++;
    }
    final followingDigitsCount = end - index - 1;
    if (digitsCount == _maxDigitsCountPrefix) return followingDigitsCount >= digitsCount;
    return followingDigitsCount == digitsCount;
  }
}

/// Skips [prefixes] & spaces at the start of a [SortKey], and symbols too when [ignoreSymbols].
/// Prefixes are bucketed by their first code unit, so keys that match none cost the same no matter how many prefixes there are.
///
/// by claude
class SortKeyPrefixIgnorer {
  static const _asciiEnd = 0x80;
  static const _space = 0x20;

  final bool ignoreSymbols;
  final List<List<String>?> _asciiPrefixesByFirstCodeUnit;
  final Map<int, List<String>>? _otherPrefixesByFirstCodeUnit;

  const SortKeyPrefixIgnorer._(this.ignoreSymbols, this._asciiPrefixesByFirstCodeUnit, this._otherPrefixesByFirstCodeUnit);

  factory SortKeyPrefixIgnorer(List<String> prefixes, {required bool ignoreSymbols, required String Function(String text) normalize}) {
    final asciiPrefixes = List<List<String>?>.filled(_asciiEnd, null);
    final otherPrefixes = <int, List<String>>{};
    for (final prefix in prefixes) {
      final prefixKey = normalize(prefix).trimLeft();
      if (prefixKey.isEmpty) continue;
      final firstCodeUnit = prefixKey.codeUnitAt(0);
      if (firstCodeUnit < _asciiEnd) {
        (asciiPrefixes[firstCodeUnit] ??= []).add(prefixKey);
      } else {
        (otherPrefixes[firstCodeUnit] ??= []).add(prefixKey);
      }
    }
    for (final bucket in asciiPrefixes) {
      bucket?.sortByReverse((e) => e.length);
    }
    for (final bucket in otherPrefixes.values) {
      bucket.sortByReverse((e) => e.length);
    }
    return SortKeyPrefixIgnorer._(ignoreSymbols, asciiPrefixes, otherPrefixes.isEmpty ? null : otherPrefixes);
  }

  String ignorePrefixes(String key) {
    final ignoredLength = ignoredLengthOf(key);
    if (ignoredLength == 0) return key;
    return key.substring(ignoredLength);
  }

  int ignoredLengthOf(String key) {
    final length = key.length;
    var start = 0;
    while (start < length) {
      final codeUnit = key.codeUnitAt(start);
      if (codeUnit == _space) {
        start++;
        continue;
      }
      if (ignoreSymbols) {
        final symbolLength = SortKey._symbolLengthAt(key, start);
        if (symbolLength > 0) {
          start += symbolLength;
          continue;
        }
      }
      final prefixLength = _prefixLengthAt(key, start, codeUnit);
      if (prefixLength == 0) break;
      start += prefixLength;
    }
    // -- keys made of prefixes & symbols only stay as is
    if (start >= length) return 0;
    return start;
  }

  int _prefixLengthAt(String key, int start, int codeUnit) {
    final prefixes = codeUnit < _asciiEnd ? _asciiPrefixesByFirstCodeUnit[codeUnit] : _otherPrefixesByFirstCodeUnit?[codeUnit];
    if (prefixes == null) return 0;
    for (int i = 0; i < prefixes.length; i++) {
      final prefix = prefixes[i];
      if (key.startsWith(prefix, start)) return prefix.length;
    }
    return 0;
  }
}
