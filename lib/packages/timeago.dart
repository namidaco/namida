// ignore_for_file: implementation_imports

import 'package:namida/core/translations/language.dart';
import 'package:timeago/src/messages/lookupmessages.dart';

/// English Messages
class NamidaEnMessages implements LookupMessages {
  @override
  String prefixAgo() => '';
  @override
  String prefixFromNow() => '';
  @override
  String suffixAgo() => 'ago';
  @override
  String suffixFromNow() => Language.inst.FROM_NOW;
  @override
  String lessThanOneMinute(int seconds) => Language.inst.A_MOMENT;
  @override
  String aboutAMinute(int minutes) => Language.inst.A_MINUTE;
  @override
  String minutes(int minutes) => '$minutes ${Language.inst.MINUTES}';
  @override
  String aboutAnHour(int minutes) => 'about an hour';
  @override
  String hours(int hours) => '$hours hours';
  @override
  String aDay(int hours) => 'a day';
  @override
  String days(int days) => '$days days';
  @override
  String aboutAMonth(int days) => 'about a month';
  @override
  String months(int months) => '$months months';
  @override
  String aboutAYear(int year) => 'about a year';
  @override
  String years(int years) => '$years years';
  @override
  String wordSeparator() => ' ';
}

/// English short Messages
class EnShortMessages implements LookupMessages {
  @override
  String prefixAgo() => '';
  @override
  String prefixFromNow() => '';
  @override
  String suffixAgo() => '';
  @override
  String suffixFromNow() => '';
  @override
  String lessThanOneMinute(int seconds) => 'now';
  @override
  String aboutAMinute(int minutes) => '1m';
  @override
  String minutes(int minutes) => '${minutes}m';
  @override
  String aboutAnHour(int minutes) => '~1h';
  @override
  String hours(int hours) => '${hours}h';
  @override
  String aDay(int hours) => '~1d';
  @override
  String days(int days) => '${days}d';
  @override
  String aboutAMonth(int days) => '~1mo';
  @override
  String months(int months) => '${months}mo';
  @override
  String aboutAYear(int year) => '~1y';
  @override
  String years(int years) => '${years}y';
  @override
  String wordSeparator() => ' ';
}
