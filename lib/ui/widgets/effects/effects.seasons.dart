part of 'effects.dart';

abstract class _Seasons {
  static EffectTheme? themeAt(DateTime date) {
    if (_isNewYear(date) || _isEid(date)) return EffectTheme.fireworks;
    if (_isRamadan(date)) return EffectTheme.ramadan;
    if (_isHalloween(date)) return EffectTheme.halloween;
    if (_isChristmas(date)) return EffectTheme.christmas;
    return null;
  }

  static String? idAt(DateTime date) {
    final theme = themeAt(date);
    if (theme == null) return null;
    if (theme == EffectTheme.fireworks) {
      if (_isNewYear(date)) return date.month == DateTime.december ? 'newyear_${date.year + 1}' : 'newyear_${date.year}';
      final hijri = _hijriOf(date);
      return 'eid_${hijri.year}_${hijri.month}';
    }
    final year = switch (theme) {
      EffectTheme.ramadan => _hijriOf(date.add(const Duration(days: 1))).year,
      EffectTheme.christmas => date.month == DateTime.january ? date.year - 1 : date.year,
      _ => date.year,
    };
    return '${theme.name}_$year';
  }

  static bool _isNewYear(DateTime date) {
    if (date.month == DateTime.december) return date.day == 31;
    return date.month == DateTime.january && date.day == 1;
  }

  static bool _isEid(DateTime date) {
    const shawwal = 10;
    const dhuAlHijjah = 12;
    final hijri = _hijriOf(date);
    if (hijri.month == shawwal) return hijri.day <= 3;
    return hijri.month == dhuAlHijjah && hijri.day >= 10 && hijri.day <= 13;
  }

  static bool _isHalloween(DateTime date) {
    if (date.month == DateTime.october) return date.day >= 25;
    return date.month == DateTime.november && date.day == 1;
  }

  static bool _isChristmas(DateTime date) {
    if (date.month == DateTime.december) return date.day >= 15;
    return date.month == DateTime.january && date.day <= 5;
  }

  // -- the month starts on a sighting, a calculated one can be a day off either way
  static bool _isRamadan(DateTime date) {
    const ramadan = 9;
    if (_hijriOf(date).month == ramadan) return true;
    final dayAfter = date.add(const Duration(days: 1));
    if (_hijriOf(dayAfter).month == ramadan) return true;
    final dayBefore = date.subtract(const Duration(days: 1));
    return _hijriOf(dayBefore).month == ramadan;
  }

  // -- tabular islamic calendar
  static ({int year, int month, int day}) _hijriOf(DateTime date) {
    final julianDay = _julianDayOf(date.year, date.month, date.day);
    int l = julianDay - 1948440 + 10632;
    final n = (l - 1) ~/ 10631;
    l = l - 10631 * n + 354;
    final j = ((10985 - l) ~/ 5316) * ((50 * l) ~/ 17719) + (l ~/ 5670) * ((43 * l) ~/ 15238);
    l = l - ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) - (j ~/ 16) * ((15238 * j) ~/ 43) + 29;
    final month = (24 * l) ~/ 709;
    final day = l - (709 * month) ~/ 24;
    final year = 30 * n + j - 30;
    return (year: year, month: month, day: day);
  }

  static int _julianDayOf(int year, int month, int day) {
    final a = (14 - month) ~/ 12;
    final y = year + 4800 - a;
    final m = month + 12 * a - 3;
    return day + (153 * m + 2) ~/ 5 + 365 * y + y ~/ 4 - y ~/ 100 + y ~/ 400 - 32045;
  }
}
