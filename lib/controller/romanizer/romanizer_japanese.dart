part of 'romanizer_engine.dart';

class _JapaneseRomanizer {
  static final kanaOnly = _JapaneseRomanizer._(nullptr);

  static const _options = r'--node-format=%m\t%f[0]\t%f[1]\t%f[7]\n --unk-format=%m\t%f[0]\t\t\n --eos-format=\n';

  static const _posParticle = '助詞';
  static const _posAuxiliaryVerb = '助動詞';
  static const _posSymbol = '記号';
  static const _posVerb = '動詞';
  static const _posAdjective = '形容詞';
  static const _pos1Conjunctive = '接続助詞';
  static const _pos1Suffix = '接尾';
  static const _pos1BracketOpen = '括弧開';

  final Pointer<Void> _tagger;

  _JapaneseRomanizer._(this._tagger);

  static _JapaneseRomanizer? open(String dictionaryDir) {
    if (!File('$dictionaryDir${Platform.pathSeparator}sys.dic').existsSync()) return null;
    final options = _options.toNativeUtf8();
    final dir = dictionaryDir.toNativeUtf8();
    try {
      final tagger = mecab.initMecab(options, dir, nullptr);
      return tagger == nullptr ? null : _JapaneseRomanizer._(tagger);
    } catch (_) {
      return null;
    } finally {
      malloc.free(options);
      malloc.free(dir);
    }
  }

  void dispose() {
    if (_tagger != nullptr) mecab.destroyMecab(_tagger);
  }

  String romanize(String text) {
    if (_tagger == nullptr) return _kanaToRomaji(text);

    final input = text.toNativeUtf8();
    final String parsed;
    try {
      final output = mecab.parse(_tagger, input);
      if (output == nullptr) return _kanaToRomaji(text);
      parsed = output.toDartString();
    } finally {
      malloc.free(input);
    }
    return _kanaToRomaji(_tokensToKana(text, parsed));
  }

  static String _tokensToKana(String text, String parsed) {
    final buffer = StringBuffer();
    final length = parsed.length;
    var lineStart = 0;
    var cursor = 0;
    var previousWasLatin = false;
    var previousWasBracketOpen = false;
    var previousWasInflectable = false;

    while (lineStart < length) {
      var lineEnd = parsed.indexOf('\n', lineStart);
      if (lineEnd < 0) lineEnd = length;
      final tab1 = parsed.indexOf('\t', lineStart);
      if (tab1 < 0 || tab1 >= lineEnd) {
        lineStart = lineEnd + 1;
        continue;
      }
      final tab2 = parsed.indexOf('\t', tab1 + 1);
      final tab3 = parsed.indexOf('\t', tab2 + 1);
      final surface = parsed.substring(lineStart, tab1);
      final readingStart = tab3 + 1;
      final readingEnd = lineEnd;
      lineStart = lineEnd + 1;
      if (surface.isEmpty) continue;

      var hadSpace = false;
      final at = text.indexOf(surface, cursor);
      if (at >= 0) {
        hadSpace = at > cursor;
        cursor = at + surface.length;
      }

      final isLatin = surface.codeUnitAt(0) < 0x2E80;
      final isSymbol = _fieldEquals(parsed, tab1, tab2, _posSymbol);
      final isAuxiliaryVerb = _fieldEquals(parsed, tab1, tab2, _posAuxiliaryVerb);
      final attach = isSymbol || (isAuxiliaryVerb && previousWasInflectable) || _fieldEquals(parsed, tab2, tab3, _pos1Conjunctive) || _fieldEquals(parsed, tab2, tab3, _pos1Suffix);

      if (buffer.isNotEmpty) {
        if (hadSpace) {
          buffer.writeCharCode(0x20);
        } else if (!attach && !previousWasBracketOpen && !(isLatin && previousWasLatin)) {
          buffer.writeCharCode(0x20);
        }
      }

      if (surface.length == 1 && _fieldEquals(parsed, tab1, tab2, _posParticle)) {
        buffer.write(switch (surface) {
          'は' => 'わ',
          'へ' => 'え',
          'を' => 'お',
          _ => surface,
        });
      } else if (readingEnd == readingStart || (readingEnd - readingStart == 1 && parsed.codeUnitAt(readingStart) == 0x2A)) {
        buffer.write(surface);
      } else {
        _writeReading(buffer, parsed, readingStart, readingEnd, _isKatakana(surface));
      }

      previousWasLatin = isLatin;
      previousWasInflectable = isAuxiliaryVerb || _fieldEquals(parsed, tab1, tab2, _posVerb) || _fieldEquals(parsed, tab1, tab2, _posAdjective);
      previousWasBracketOpen = isSymbol && _fieldEquals(parsed, tab2, tab3, _pos1BracketOpen);
    }
    return buffer.toString();
  }

  static bool _isKatakana(String text) {
    for (var i = 0; i < text.length; i++) {
      final c = text.codeUnitAt(i);
      if (c < 0x30A1 || c > 0x30FF) return false;
    }
    return true;
  }

  /// [previousTab] & [nextTab] are the tabs surrounding the field.
  static bool _fieldEquals(String parsed, int previousTab, int nextTab, String value) {
    return nextTab - previousTab - 1 == value.length && parsed.startsWith(value, previousTab + 1);
  }

  static void _writeReading(StringBuffer buffer, String parsed, int start, int end, bool keepKatakana) {
    for (var i = start; i < end; i++) {
      final c = parsed.codeUnitAt(i);
      buffer.writeCharCode(!keepKatakana && c >= 0x30A1 && c <= 0x30F6 ? c - 0x60 : c);
    }
  }
}
