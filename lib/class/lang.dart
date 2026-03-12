import 'dart:ui' show Locale;

import 'package:namida/core/translations/arb/app_localizations.dart';
import 'package:namida/core/utils.dart';

part 'package:namida/core/translations/localized_language_names.dart';

class NamidaLanguage {
  /// ex: en_US
  final String code;

  /// ex: English
  final String name;

  /// ex: United States
  final String country;

  final String codeOnly;

  final String? countryCodeOnly;

  final Locale locale;

  const NamidaLanguage._({
    required this.code,
    required this.name,
    required this.country,
    required this.codeOnly,
    required this.countryCodeOnly,
    required this.locale,
  });

  static (String, String?) _splitCode(String code) {
    final codeSplits = code.split('_');
    final codeOnly = codeSplits.first;
    final countryCodeOnly = codeSplits.length > 1 ? codeSplits[1] : null;
    return (codeOnly, countryCodeOnly);
  }

  static String? _tryGetDefaultNameForCodeOnly(String codeOnly) {
    final withCountryCode = _allLocalizedLanguagePrefferredNamesWithCountryMap[codeOnly];
    return _allLocalizedLanguageNamesMap[withCountryCode];
  }

  factory NamidaLanguage.fromCode(String code) {
    final langSplits = _splitCode(code);
    final localeWithCountry = Locale(langSplits.$1, langSplits.$2);

    if (localeWithCountry.countryCode != null) {
      final localeWithCountrySupported = AppLocalizations.supportedLocales.contains(localeWithCountry);
      if (localeWithCountrySupported) {
        // -- only if country included, for example `en_US` will fallback to `en` to align with available locales
        return NamidaLanguage.fromLocale(localeWithCountry);
      }
    }

    return NamidaLanguage.fromLocale(Locale(langSplits.$1));
  }

  factory NamidaLanguage.fromLocale(Locale locale) {
    final codeOnly = locale.languageCode;
    final countryCodeOnly = locale.countryCode;
    final code = [codeOnly, ?countryCodeOnly].join('_');

    String? nameAndCountry;
    if (countryCodeOnly != null) {
      // only get name if code has country
      nameAndCountry = _allLocalizedLanguageNamesMap[code];
    }
    nameAndCountry ??= _tryGetDefaultNameForCodeOnly(codeOnly) ?? _allLocalizedLanguageNamesMap[codeOnly];

    String? name;
    String? country;

    if (nameAndCountry != null) {
      final match = RegExp(r'^(.+?)\s*\((.+)\)$').firstMatch(nameAndCountry);
      if (match != null) {
        name = match.group(1);
        country = match.group(2);
      } else {
        name = nameAndCountry;
      }
    }
    return NamidaLanguage._(
      code: code,
      name: name?.capitalizeFirst() ?? nameAndCountry?.capitalizeFirst() ?? '?',
      country: country ?? '',
      codeOnly: codeOnly,
      countryCodeOnly: countryCodeOnly,
      locale: Locale(codeOnly, countryCodeOnly),
    );
  }

  factory NamidaLanguage.fromJson(Map<String, dynamic> json) {
    final code = json["code"] as String;
    final name = json["name"];
    if (name is! String || name.isEmpty) {
      return NamidaLanguage.fromCode(code);
    }
    final langSplits = _splitCode(code);
    final codeOnly = langSplits.$1;
    final countryCodeOnly = langSplits.$2;

    return NamidaLanguage._(
      code: json["code"],
      name: name,
      country: json["country"],
      codeOnly: codeOnly,
      countryCodeOnly: countryCodeOnly,
      locale: Locale(codeOnly, countryCodeOnly),
    );
  }

  Map<String, String?> toJson() {
    return {
      "code": code,
      "name": name,
      "country": country,
    };
  }

  @override
  bool operator ==(covariant NamidaLanguage other) {
    return code == other.code;
  }

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => toJson().toString();
}
