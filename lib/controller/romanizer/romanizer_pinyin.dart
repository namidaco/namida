part of 'romanizer_engine.dart';

class _PinyinRomanizer {
  static const _rangeStart = 0x3400;
  static const _rangeEnd = 0x9FFF;

  final Uint16List _table;
  final List<String> _syllables;
  final List<String> _syllablesPlain;

  _PinyinRomanizer._(this._table, this._syllables, this._syllablesPlain);

  static _PinyinRomanizer? open(File file) {
    try {
      final bytes = file.readAsBytesSync();
      final syllablesLength = ByteData.sublistView(bytes).getUint32(0, Endian.little);
      final syllables = utf8.decode(Uint8List.sublistView(bytes, 4, 4 + syllablesLength)).trimRight().split('\n');
      final table = Uint16List.sublistView(bytes, 4 + syllablesLength);
      if (table.length != _rangeEnd - _rangeStart + 1) return null;
      return _PinyinRomanizer._(table, syllables, syllables.map(_removeTones).toList(growable: false));
    } catch (_) {
      return null;
    }
  }

  static const _toned = 'āáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜüńňǹḿ';
  static const _untoned = 'aaaaeeeeiiiioooouuuuvvvvvnnnm';

  static String _removeTones(String syllable) {
    final buffer = StringBuffer();
    for (var i = 0; i < syllable.length; i++) {
      final index = _toned.indexOf(syllable[i]);
      buffer.write(index < 0 ? syllable[i] : _untoned[index]);
    }
    return buffer.toString();
  }

  String romanize(String text, bool plain) {
    final syllables = plain ? _syllablesPlain : _syllables;
    final buffer = StringBuffer();
    final length = text.length;
    var previousWasHan = false;
    for (var i = 0; i < length; i++) {
      final c = text.codeUnitAt(i);
      final syllableIndex = c >= _rangeStart && c <= _rangeEnd ? _table[c - _rangeStart] : 0;
      if (syllableIndex == 0) {
        if (previousWasHan && _isAsciiAlphanumeric(c)) buffer.writeCharCode(0x20);
        buffer.writeCharCode(c);
        previousWasHan = false;
        continue;
      }
      if (previousWasHan || (i != 0 && _isAsciiAlphanumeric(text.codeUnitAt(i - 1)))) buffer.writeCharCode(0x20);
      buffer.write(syllables[syllableIndex - 1]);
      previousWasHan = true;
    }
    return buffer.toString();
  }

  static bool _isAsciiAlphanumeric(int c) => (c >= 0x30 && c <= 0x39) || (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A);
}
