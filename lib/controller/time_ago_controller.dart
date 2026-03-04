import 'package:jiffy/jiffy.dart';

import 'package:namida/core/extensions.dart';

class TimeAgoController {
  static final instance = TimeAgoController._();
  TimeAgoController._();

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
    return Jiffy.parseFromDateTime(date).fromNow(withPrefixAndSuffix: long);
  }

  static String dateMSSEFromNow(int millisecondsSinceEpoch, {bool long = true}) {
    return Jiffy.parseFromMillisecondsSinceEpoch(millisecondsSinceEpoch).fromNow(withPrefixAndSuffix: long);
  }
}
