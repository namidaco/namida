import 'package:jiffy/jiffy.dart';

import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/extensions.dart';

class TimeAgoController {
  const TimeAgoController._();

  static Jiffy _getCurrentDateTime() {
    final years = settings.timeCapsuleYears.value;
    if (years == 0) return Jiffy.now();
    // -- years can be +ve or -ve so always add
    return Jiffy.now().add(years: years);
  }

  static Future<void> setLocale(String code) async {
    await _trySetLocale(code) ||
        await _trySetLocale(code.splitFirst('_')) || //
        await _trySetLocale('en');
  }

  static Future<bool> _trySetLocale(String code) async {
    try {
      await Jiffy.setLocale(code);
      return true;
    } catch (_) {
      return false;
    }
  }

  static String dateFromNow(DateTime date, {bool long = true}) {
    return Jiffy.parseFromDateTime(date).from(_getCurrentDateTime(), withPrefixAndSuffix: long);
  }

  static String dateMSSEFromNow(int millisecondsSinceEpoch, {bool long = true}) {
    return Jiffy.parseFromMillisecondsSinceEpoch(millisecondsSinceEpoch).from(_getCurrentDateTime(), withPrefixAndSuffix: long);
  }
}
