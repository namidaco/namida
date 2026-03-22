// ignore_for_file: implementation_imports, non_constant_identifier_names

import 'dart:io';

import 'package:intl/intl.dart';
import 'package:intl/number_symbols_data.dart' as intl_data;
import 'package:intl/src/plural_rules.dart' as plural_rules;

import 'package:namida/class/lang.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/time_ago_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/arb/app_localizations.dart';
import 'package:namida/core/translations/arb/app_localizations_en.dart';
import 'package:namida/core/utils.dart';

AppLocalizations get lang => _lang!;

AppLocalizations? _lang;

class Language {
  static final Language inst = Language._internal();
  Language._internal();

  /// Currently Selected & Set Language.
  RxBaseCore<NamidaLanguage?> get currentLanguageRx => _currentLanguage;
  NamidaLanguage? getCurrentLanguageOrDevice() => _currentLanguage.value ?? getDeviceLanguage();
  static NamidaLanguage? getDeviceLanguage() {
    try {
      Intl.systemLocale = Intl.canonicalizedLocale(Platform.localeName);
      return NamidaLanguage.fromCode(Intl.systemLocale);
    } catch (_) {}
    return null;
  }

  static final _currentLanguage = Rxn<NamidaLanguage>();

  static void initialize() {
    final language = settings.language.value;
    inst.update(language: language);
  }

  /// Returns false if there was a problem setting the language, for ex: lang file doesnt exist.
  bool update({required NamidaLanguage? language}) {
    try {
      language ??= getDeviceLanguage() ?? NamidaLanguage.fromCode('en');

      _ensureLocaleHasIntlSupport(language.code);

      try {
        _lang = lookupAppLocalizations(language.locale);
      } catch (_) {}

      _lang ??= AppLocalizationsEn();

      _currentLanguage.value = language;

      if (language != settings.language.value) {
        settings.save(language: language);
      }

      // -- mainly to refresh tray/taskbar language
      Player.inst.refreshNotification();

      return true;
    } catch (e) {
      printy(e, isError: true);
      return false;
    }
  }

  void _ensureLocaleHasIntlSupport(String code) {
    String localeForInternal;
    String? verifiedLocale;
    try {
      verifiedLocale = Intl.verifiedLocale(code, plural_rules.localeHasPluralRules)!;
      verifiedLocale = Intl.verifiedLocale(code, NumberFormat.localeExists, onFailure: null)!;
      localeForInternal = verifiedLocale;
      Intl.defaultLocale = verifiedLocale;
    } catch (_) {
      // -- add `en` data as a fallback, otherwise intl plural logic & number format would throw.
      localeForInternal = 'en';
      Intl.defaultLocale = localeForInternal;

      final verifiedLocaleCode = verifiedLocale ?? code;
      intl_data.numberFormatSymbols[verifiedLocaleCode] ??= intl_data.numberFormatSymbols[localeForInternal]!;
      intl_data.compactNumberSymbols[verifiedLocaleCode] ??= intl_data.compactNumberSymbols[localeForInternal]!;
    }

    TimeAgoController.setLocale(localeForInternal);
  }
}
