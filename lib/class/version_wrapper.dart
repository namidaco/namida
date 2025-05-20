import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';

class VersionWrapper {
  final String name;
  final String prettyVersion;
  final int? buildNumber;
  final DateTime? buildDate;
  final bool isBeta;

  const VersionWrapper._({
    required this.name,
    required this.prettyVersion,
    required this.buildNumber,
    required this.buildDate,
    required this.isBeta,
  });

  static VersionWrapper? get current => NamidaDeviceInfo.version;
  static Future<void> get waitForCurrentVersionFetch => NamidaDeviceInfo.packageInfoCompleter.future;

  factory VersionWrapper(String name, [String? buildNumber]) {
    final parts = name.split('+'); // 5.0.1-beta 250223230
    name = parts.first;
    final betaParts = name.split('-beta');
    bool isBeta = false;
    if (betaParts.length > 1) {
      isBeta = true;
      name = betaParts.first;
    }
    String prettyVersion = name;
    if (!prettyVersion.startsWith('v')) prettyVersion = "v${prettyVersion.splitFirst('+')}";
    if (name.startsWith('v')) name = name.substring(1);
    buildNumber ??= parts.last;
    return VersionWrapper._(
      name: name,
      prettyVersion: prettyVersion,
      buildNumber: int.tryParse(buildNumber),
      buildDate: _parseBuildNumber(buildNumber),
      isBeta: isBeta,
    );
  }

  static DateTime? _parseBuildNumber(String buildNumber) {
    try {
      int hours = 0;
      int minutes = 0;
      final yyMMddHHP = buildNumber;
      final year = 2000 + int.parse("${yyMMddHHP[0]}${yyMMddHHP[1]}");
      final month = int.parse("${yyMMddHHP[2]}${yyMMddHHP[3]}");
      final day = int.parse("${yyMMddHHP[4]}${yyMMddHHP[5]}");
      try {
        hours = int.parse("${yyMMddHHP[6]}${yyMMddHHP[7]}");
        minutes = (60 * double.parse("0.${yyMMddHHP[8]}")).round(); // 0.5, 0.8, 1.0, etc.
      } catch (_) {}
      return DateTime.utc(year, month, day, hours, minutes);
    } catch (_) {}
    return null;
  }

  bool? isAfter(VersionWrapper other) {
    final buildThis = buildNumber;
    final buildOther = other.buildNumber;
    if (buildThis == null || buildOther == null || buildThis == buildOther) {
      try {
        final vPartsThis = name.split('.');
        final vPartsOther = other.name.split('.');
        final length = vPartsThis.length.withMaximum(vPartsOther.length);
        for (int i = 0; i < length; i++) {
          // -- pad right to ensure 5.1.7 > 5.1.68 (not following rules ik heh)
          final v = int.parse((vPartsThis[i].padRight(2, '0')));
          final vOther = int.parse(vPartsOther[i].padRight(2, '0'));
          if (v > vOther) {
            return true;
          } else if (v < vOther) {
            return false;
          }
        }
        // all equal, this should tell (3.3.2 > 3.3)
        return vPartsThis.length > vPartsOther.length;
      } catch (_) {
        return null;
      }
    }
    return buildThis > buildOther;
  }

  bool? isUpdate() {
    return current == null ? null : isAfter(current!);
  }

  @override
  int get hashCode => name.hashCode ^ isBeta.hashCode;

  @override
  bool operator ==(Object other) {
    return other is VersionWrapper && name == other.name && isBeta == other.isBeta;
  }
}
