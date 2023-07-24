import 'package:namida/core/constants.dart';

class NamidaLanguage {
  /// ex: en_US
  final String code;

  /// ex: English
  final String name;

  /// ex: United States
  final String country;

  const NamidaLanguage({
    required this.code,
    required this.name,
    required this.country,
  });

  factory NamidaLanguage.fromJson(Map<String, dynamic>? json) {
    if (json == null) return kDefaultLang;
    return NamidaLanguage(
      code: json["code"],
      name: json["name"],
      country: json["country"],
    );
  }
  Map<String, String> toJson() {
    return {
      "code": code,
      "name": name,
      "country": country,
    };
  }

  @override
  bool operator ==(other) {
    if (other is NamidaLanguage) {
      return code == other.code && name == other.name && country == other.country;
    }
    return false;
  }

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => toJson().toString();
}
