import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:mecab_for_dart/mecab_ffi_native.dart' as mecab;

part 'romanizer_alphabetic.dart';
part 'romanizer_hangul.dart';
part 'romanizer_japanese.dart';
part 'romanizer_kana.dart';
part 'romanizer_pinyin.dart';

// by claude
class RomanizerEngine {
  static const _kana = 1;
  static const _han = 2;
  static const _hangul = 4;
  static const _alphabetic = 8;

  _JapaneseRomanizer? _japanese;
  _PinyinRomanizer? _pinyin;

  bool get hasDictionary => _japanese != null;

  /// [dir] should contain `ipadic/` & `pinyin.bin`.
  bool load(String dir) {
    unload();
    final sep = Platform.pathSeparator;
    final japanese = _JapaneseRomanizer.open('$dir${sep}ipadic');
    if (japanese == null) return false;
    _japanese = japanese;
    _pinyin = _PinyinRomanizer.open(File('$dir${sep}pinyin.bin'));
    return true;
  }

  void unload() {
    _japanese?.dispose();
    _japanese = null;
    _pinyin = null;
  }

  static bool containsKana(String text) => _scan(text) & _kana != 0;
  static bool needsRomanization(String text) => _scan(text) != 0;

  static int _scan(String text) {
    var flags = 0;
    final length = text.length;
    for (var i = 0; i < length; i++) {
      final c = text.codeUnitAt(i);
      if (c < 0x0370) continue;
      if (c < 0x3005) {
        if (_isAlphabeticScript(c)) flags |= _alphabetic;
        continue;
      }
      if (c >= 0x3041 && c <= 0x30FF) {
        flags |= _kana;
      } else if ((c >= 0x3400 && c <= 0x9FFF) || c == 0x3005) {
        flags |= _han;
      } else if (c >= 0xAC00 && c <= 0xD7A3) {
        flags |= _hangul;
      }
    }
    return flags;
  }

  /// Returns the same instance if there is nothing to romanize.
  ///
  /// [chinese] treats han characters as chinese when the text has no kana, otherwise japanese is tried first.
  String romanize(String text, {bool chinese = false, bool plain = false}) {
    final flags = _scan(text);
    if (flags == 0) return text;

    var result = text;
    if (flags & (_kana | _han) != 0) {
      final pinyin = flags & _kana == 0 ? _pinyin : null;
      if (chinese && pinyin != null) {
        result = pinyin.romanize(result, plain);
      } else {
        result = (_japanese ?? _JapaneseRomanizer.kanaOnly).romanize(result);
        // -- han unknown to the japanese dictionary is most likely chinese
        if (pinyin != null && _scan(result) & _han != 0) result = pinyin.romanize(text, plain);
      }
    }
    if (flags & _hangul != 0) result = _romanizeHangul(result);
    if (flags & _alphabetic != 0) result = _romanizeAlphabetic(result);
    return result;
  }
}
