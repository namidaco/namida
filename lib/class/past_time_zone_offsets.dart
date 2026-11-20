import 'dart:typed_data';

/// system timezone offsets of past times, read once per week, and per day only in weeks with a dst switch.
///
/// by claude
class PastTimeZoneOffsets {
  static const _kUnknown = -0x80000000;
  static const _kSwitching = 0x7FFFFFFF;
  static const _kMSPerWeek = Duration.millisecondsPerDay * 7;

  final int _untilMSSE;
  final Int32List _offsetMSPerWeekStart;
  final Int32List _offsetMSPerWeek;
  final Int32List _offsetMSPerDay;

  PastTimeZoneOffsets(int untilMSSE)
    : _untilMSSE = untilMSSE,
      _offsetMSPerWeekStart = _newUnknownList(untilMSSE ~/ _kMSPerWeek + 2),
      _offsetMSPerWeek = _newUnknownList(untilMSSE ~/ _kMSPerWeek + 1),
      _offsetMSPerDay = _newUnknownList(untilMSSE ~/ Duration.millisecondsPerDay + 1);

  static Int32List _newUnknownList(int length) => Int32List(length)..fillRange(0, length, _kUnknown);

  static int _systemOffsetMSOf(int msse) => DateTime.fromMillisecondsSinceEpoch(msse).timeZoneOffset.inMilliseconds;

  int offsetMSOf(int msse) {
    if (msse < 0 || msse >= _untilMSSE) return _systemOffsetMSOf(msse);

    final week = msse ~/ _kMSPerWeek;
    final weekOffsetMS = _weekOffsetMSOf(week);
    if (weekOffsetMS != _kSwitching) return weekOffsetMS;

    final day = msse ~/ Duration.millisecondsPerDay;
    final dayOffsetMS = _dayOffsetMSOf(day);
    if (dayOffsetMS != _kSwitching) return dayOffsetMS;

    return _systemOffsetMSOf(msse);
  }

  int _dayOffsetMSOf(int day) {
    final cachedDayOffsetMS = _offsetMSPerDay[day];
    if (cachedDayOffsetMS != _kUnknown) return cachedDayOffsetMS;
    final startOffsetMS = _systemOffsetMSOf(day * Duration.millisecondsPerDay);
    final endOffsetMS = _systemOffsetMSOf((day + 1) * Duration.millisecondsPerDay);
    final dayOffsetMS = startOffsetMS == endOffsetMS ? startOffsetMS : _kSwitching;
    _offsetMSPerDay[day] = dayOffsetMS;
    return dayOffsetMS;
  }

  int _weekOffsetMSOf(int week) {
    final cachedWeekOffsetMS = _offsetMSPerWeek[week];
    if (cachedWeekOffsetMS != _kUnknown) return cachedWeekOffsetMS;
    final startOffsetMS = _weekStartOffsetMSOf(week);
    final endOffsetMS = _weekStartOffsetMSOf(week + 1);
    final weekOffsetMS = startOffsetMS == endOffsetMS ? startOffsetMS : _kSwitching;
    _offsetMSPerWeek[week] = weekOffsetMS;
    return weekOffsetMS;
  }

  int _weekStartOffsetMSOf(int week) {
    final cachedOffsetMS = _offsetMSPerWeekStart[week];
    if (cachedOffsetMS != _kUnknown) return cachedOffsetMS;
    final offsetMS = _systemOffsetMSOf(week * _kMSPerWeek);
    _offsetMSPerWeekStart[week] = offsetMS;
    return offsetMS;
  }
}
