part of 'romanizer_engine.dart';

/// hiragana U+3041..U+3096, katakana is shifted by 0x60.
const _kanaTable = [
  'a', 'a', 'i', 'i', 'u', 'u', 'e', 'e', 'o', 'o', //
  'ka', 'ga', 'ki', 'gi', 'ku', 'gu', 'ke', 'ge', 'ko', 'go', //
  'sa', 'za', 'shi', 'ji', 'su', 'zu', 'se', 'ze', 'so', 'zo', //
  'ta', 'da', 'chi', 'ji', '', 'tsu', 'zu', 'te', 'de', 'to', 'do', //
  'na', 'ni', 'nu', 'ne', 'no', //
  'ha', 'ba', 'pa', 'hi', 'bi', 'pi', 'fu', 'bu', 'pu', 'he', 'be', 'pe', 'ho', 'bo', 'po', //
  'ma', 'mi', 'mu', 'me', 'mo', //
  'ya', 'ya', 'yu', 'yu', 'yo', 'yo', //
  'ra', 'ri', 'ru', 're', 'ro', //
  'wa', 'wa', 'i', 'e', 'wo', 'n', //
  'vu', 'ka', 'ke',
];

const _kanaStart = 0x3041;
const _kanaEnd = 0x3096;
const _kanaSokuon = 0x3063;
const _kanaN = 0x3093;
const _kanaLongVowel = 0x30FC;

int _normalizeKana(int c) => c >= 0x30A1 && c <= 0x30F6 ? c - 0x60 : c;

String? _kanaSmallY(int c) => switch (c) {
  0x3083 => 'a',
  0x3085 => 'u',
  0x3087 => 'o',
  _ => null,
};

String? _kanaSmallVowel(int c) => switch (c) {
  0x3041 => 'a',
  0x3043 => 'i',
  0x3045 => 'u',
  0x3047 => 'e',
  0x3049 => 'o',
  _ => null,
};

String? _kanaStemY(int c) => switch (c) {
  0x304D => 'ky',
  0x304E => 'gy',
  0x3057 => 'sh',
  0x3058 => 'j',
  0x3061 => 'ch',
  0x3062 => 'j',
  0x306B => 'ny',
  0x3072 => 'hy',
  0x3073 => 'by',
  0x3074 => 'py',
  0x307F => 'my',
  0x308A => 'ry',
  _ => null,
};

String? _kanaStemVowel(int c) => switch (c) {
  0x3075 => 'f',
  0x3094 => 'v',
  0x3046 => 'w',
  0x3066 => 't',
  0x3067 => 'd',
  0x3068 => 't',
  0x3069 => 'd',
  0x3057 => 'sh',
  0x3058 => 'j',
  0x3061 => 'ch',
  0x3064 => 'ts',
  _ => null,
};

String? _kanaPunctuation(int c) => switch (c) {
  0x3001 => ',',
  0x3002 => '.',
  0x3000 => ' ',
  0x30FB => ' ',
  0x300C || 0x300D || 0x300E || 0x300F => '"',
  0x301C || 0xFF5E => '~',
  0xFF01 => '!',
  0xFF1F => '?',
  0xFF08 => '(',
  0xFF09 => ')',
  _ => null,
};

bool _isVowel(int c) => c == 0x61 || c == 0x69 || c == 0x75 || c == 0x65 || c == 0x6F;

/// katakana is written in upper case.
String _kanaToRomaji(String text) {
  final buffer = StringBuffer();
  final length = text.length;
  var sokuon = false;
  var lastVowel = 0;

  for (var i = 0; i < length; i++) {
    final original = text.codeUnitAt(i);
    final c = _normalizeKana(original);

    if (c < _kanaStart || c > _kanaEnd) {
      if (c == _kanaLongVowel && lastVowel != 0) {
        buffer.writeCharCode(lastVowel);
        continue;
      }
      final punctuation = _kanaPunctuation(c);
      punctuation == null ? buffer.writeCharCode(c) : buffer.write(punctuation);
      sokuon = false;
      lastVowel = 0;
      continue;
    }

    if (c == _kanaSokuon) {
      sokuon = true;
      continue;
    }

    var romaji = _kanaTable[c - _kanaStart];
    final next = i + 1 < length ? _normalizeKana(text.codeUnitAt(i + 1)) : 0;

    if (c == _kanaN) {
      if (next >= _kanaStart && next <= _kanaEnd && next != _kanaSokuon) {
        final nextFirst = _kanaTable[next - _kanaStart].codeUnitAt(0);
        if (_isVowel(nextFirst) || nextFirst == 0x79) romaji = "n'";
      }
    } else if (next != 0) {
      final smallY = _kanaSmallY(next);
      final stem = smallY != null ? _kanaStemY(c) : _kanaStemVowel(c);
      final small = smallY ?? _kanaSmallVowel(next);
      if (stem != null && small != null) {
        romaji = stem + small;
        i++;
      }
    }

    if (sokuon) {
      sokuon = false;
      final first = romaji.codeUnitAt(0);
      if (!_isVowel(first)) romaji = (first == 0x63 ? 't' : romaji[0]) + romaji;
    }

    final isKatakana = original != c;
    buffer.write(isKatakana ? romaji.toUpperCase() : romaji);

    final last = romaji.codeUnitAt(romaji.length - 1);
    lastVowel = _isVowel(last) ? (isKatakana ? last - 0x20 : last) : 0;
  }
  return buffer.toString();
}
