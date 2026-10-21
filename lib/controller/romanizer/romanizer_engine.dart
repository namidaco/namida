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
  static const _greek = 8;
  static const _cyrillic = 16;
  static const _armenian = 32;
  static const _georgian = 64;
  static const _alphabetic = _greek | _cyrillic | _armenian | _georgian;
  static const _allScripts = _kana | _han | _hangul | _alphabetic;

  _JapaneseRomanizer? _japanese;
  _PinyinRomanizer? _pinyin;

  var _enabledScripts = _allScripts;

  bool get hasDictionary => _japanese != null;

  /// returns the scripts whose romanization changed, han follows japanese too.
  int setDisabledScripts(List<RomanizationScript> scripts) {
    var disabledScripts = 0;
    for (final script in scripts) {
      disabledScripts |= script._flag;
    }
    final enabledScripts = _allScripts & ~disabledScripts;
    var changedScripts = enabledScripts ^ _enabledScripts;
    if (changedScripts & _kana != 0) changedScripts |= _han;
    _enabledScripts = enabledScripts;
    return changedScripts;
  }

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
  static bool hasAnyScript(String text, int scripts) => _scan(text) & scripts != 0;

  static bool scriptsNeedDictionary(int scripts) => scripts & _han != 0;

  static int _scan(String text) {
    var flags = 0;
    final length = text.length;
    for (var i = 0; i < length; i++) {
      final c = text.codeUnitAt(i);
      if (c < 0x0370) continue;
      flags |= scriptOf(c);
    }
    return flags;
  }

  static int scriptOf(int c) {
    if (c < 0x0370) return 0;
    if (c < 0x3005) return _alphabeticScriptOf(c);
    if (c >= 0x3041 && c <= 0x30FF) return _kana;
    if ((c >= 0x3400 && c <= 0x9FFF) || c == 0x3005) return _han;
    if (c >= 0xAC00 && c <= 0xD7A3) return _hangul;
    return 0;
  }

  /// Returns the same instance if there is nothing to romanize.
  ///
  /// [chinese] treats han characters as chinese when the text has no kana, otherwise japanese is tried first.
  String romanize(String text, {bool chinese = false, bool plain = false}) {
    final flags = _scan(text);
    if (flags == 0) return text;

    var result = text;
    if (flags & (_kana | _han) != 0) result = _romanizeKanaHan(text, flags, chinese, plain);
    final enabledFlags = flags & _enabledScripts;
    if (enabledFlags & _hangul != 0) result = _romanizeHangul(result);
    final alphabeticFlags = enabledFlags & _alphabetic;
    if (alphabeticFlags != 0) result = _romanizeAlphabetic(result, alphabeticFlags);
    return result;
  }

  /// text with kana is japanese, han alone is chinese with [chinese] or when japanese is disabled.
  String _romanizeKanaHan(String text, int flags, bool chinese, bool plain) {
    final hasKana = flags & _kana != 0;
    final isJapaneseEnabled = _enabledScripts & _kana != 0;
    final isChineseEnabled = _enabledScripts & _han != 0;
    final isChinese = !hasKana && (chinese || !isJapaneseEnabled);
    if (isChinese && !isChineseEnabled) return text;
    final pinyin = hasKana || !isChineseEnabled ? null : _pinyin;
    if (isChinese && pinyin != null) return pinyin.romanize(text, plain);
    if (!isJapaneseEnabled) return text;
    final japanese = _japanese ?? _JapaneseRomanizer.kanaOnly;
    final romanized = japanese.romanize(text);
    // -- han unknown to the japanese dictionary is most likely chinese
    if (pinyin != null && _scan(romanized) & _han != 0) return pinyin.romanize(text, plain);
    return romanized;
  }
}

/// japanese covers kana & the han read along with it, chinese the han read as pinyin.
enum RomanizationScript {
  japanese(RomanizerEngine._kana),
  chinese(RomanizerEngine._han),
  korean(RomanizerEngine._hangul),
  greek(RomanizerEngine._greek),
  cyrillic(RomanizerEngine._cyrillic),
  armenian(RomanizerEngine._armenian),
  georgian(RomanizerEngine._georgian),
  ;

  final int _flag;
  const RomanizationScript(this._flag);
}
