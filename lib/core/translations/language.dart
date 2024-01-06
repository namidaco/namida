import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:namida/class/lang.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/keys.dart';
import 'package:namida/main.dart';

Language get lang => Language.inst;

class Language extends LanguageKeys {
  static Language get inst => _instance;
  static final Language _instance = Language._internal();
  Language._internal();

  static final Rx<NamidaLanguage> _currentLanguage = kDefaultLang.obs;

  /// Currently Selected & Set Language.
  NamidaLanguage get currentLanguage => _currentLanguage.value;

  /// All Available Languages fetched from `'/assets/language/translations/'`
  static var availableLanguages = <NamidaLanguage>[];

  /// Used as a backup in case a key wasn't found in the desired language.
  static late final Map<String, String> _defaultMap;

  static late Map<String, String> _currentMap;

  static Future<void> initialize() async {
    final lang = settings.selectedLanguage.value;

    Future<void> updateAllAvailable() async {
      availableLanguages = await getAllLanguages();
    }

    // -- Assigning default map, used as a backup in case a key doesnt exist in [lang].
    final path = inst._getAssetPath(kDefaultLang);
    final map = await jsonDecode(await rootBundle.loadString(path)) as Map<String, dynamic>;
    _defaultMap = map.cast();
    // ---------

    await Future.wait([
      inst.update(
        lang: lang,
        trMap: lang.code == kDefaultLang.code ? _defaultMap : null,
      ),
      updateAllAvailable(),
    ]);
  }

  final _backupLocalMaps = <NamidaLanguage, Map<String, dynamic>>{};
  Future<bool> loadLanguage(String fullCode, Map<String, dynamic> trMap) async {
    final splitted = fullCode.split('_');
    final nl = NamidaLanguage(code: splitted.first, name: fullCode, country: 'local');
    availableLanguages
      ..remove(nl)
      ..add(nl);
    _backupLocalMaps[nl] = trMap;
    return await update(lang: nl, trMap: trMap);
  }

  static Future<List<NamidaLanguage>> getAllLanguages() async {
    const path = 'assets/language/langs.json';
    final available = await rootBundle.loadString(path);
    final availableLangs = await jsonDecode(available) as List?;
    return availableLangs?.mapped((e) => NamidaLanguage.fromJson(e)) ?? [];
  }

  String _getAssetPath(NamidaLanguage lang) => 'assets/language/translations/${lang.code}.json';

  /// Returns false if there was a problem setting the language, for ex: lang file doesnt exist.
  Future<bool> update({required NamidaLanguage lang, Map<String, dynamic>? trMap}) async {
    // -- loading file from asset
    final path = _getAssetPath(lang);
    try {
      late Map<String, dynamic> map;
      try {
        map = trMap ?? await jsonDecode(await rootBundle.loadString(path)) as Map<String, dynamic>;
      } catch (e) {
        final backupLocal = _backupLocalMaps[lang];
        if (backupLocal != null) {
          map = backupLocal;
        } else {
          lang = kDefaultLang;
          map = _defaultMap;
        }
      }

      _currentMap = map.cast();

      _currentLanguage.value = lang;
      settings.save(selectedLanguage: lang);
      setJiffyLocale(lang.code);
      lang.refreshConverterMaps();

      return true;
    } catch (e) {
      printy(e, isError: true);
      return false;
    }
  }

  @override
  Map<String, String> get languageMap => _currentMap;

  @override
  Map<String, String> get languageMapDefault => _defaultMap;
}
