part of '../smart_playlists_controller.dart';

final class SmartPlaylistRuleDateTime extends SmartPlaylistRuleBase<SmartPlaylistDate, SmartPlaylistDate, SmartPlaylistRuleFilterDateTime, SmartPlaylistRuleFilterDateTimeSource> {
  SmartPlaylistRuleDateTime({
    required super.data,
    required super.data2,
    required super.filter,
    required super.source,
    required super.enableCleanup,
    required super.clockOnly,
    required super.relativeDuration,
  }) : super(type: SmartPlaylistFilterType.dateTime);

  @override
  SmartPlaylistRuleDateTime copyWith({
    (SmartPlaylistDate? data, SmartPlaylistDate? data2)? datas,
    SmartPlaylistRuleFilterDateTime? filter,
    bool? enableCleanup,
    bool? clockOnly,
    SmartPlaylistRelativeDuration? relativeDuration,
  }) => SmartPlaylistRuleDateTime(
    data: datas != null ? datas.$1 : this.data,
    data2: datas != null ? datas.$2 : this.data2,
    filter: filter ?? this.filter,
    source: this.source,
    enableCleanup: enableCleanup ?? this.enableCleanup,
    clockOnly: clockOnly ?? this.clockOnly,
    relativeDuration: relativeDuration ?? this.relativeDuration,
  );

  @override
  String? dataValidator(String? value) {
    if (value == null || value.isEmpty) return lang.emptyValue;

    if (filter.isRelativeDate) {
      if (relativeDuration == null || relativeDuration!.amount <= 0) {
        return lang.emptyValue;
      }
    } else {
      final date = textToData(value);
      if (date == null) return lang.nameContainsBadCharacter;
    }

    return null;
  }

  @override
  String? validate() {
    final data = this.data;
    final data2 = this.data2;
    if (filter.isRelativeDate && (relativeDuration == null || relativeDuration!.amount <= 0)) return lang.emptyValue;

    if (filter.requiresDataField && data == null) return lang.emptyValue;
    if (filter.requiresData2Field && data2 == null) return lang.emptyValue;
    return null;
  }

  @override
  String datasDisplayText() {
    late final dataFormatted = _displayTextOf(data);
    late final data2Formatted = _displayTextOf(data2);
    return switch (filter) {
          SmartPlaylistRuleFilterDateTime.isSame => '= ${dataFormatted ?? '?'}',
          SmartPlaylistRuleFilterDateTime.isNotSame => '≠ ${dataFormatted ?? '?'}',
          SmartPlaylistRuleFilterDateTime.isBefore => '<-- ${dataFormatted ?? '?'}',
          SmartPlaylistRuleFilterDateTime.isAfter => '${dataFormatted ?? '?'} --> • ',
          SmartPlaylistRuleFilterDateTime.isInBetween => '${dataFormatted ?? '?'} -> • <- ${data2Formatted ?? '?'}',
          SmartPlaylistRuleFilterDateTime.isOutside => ' • <- ${dataFormatted ?? '?'} - ${data2Formatted ?? '?'} -> • ',
          SmartPlaylistRuleFilterDateTime.exists => null,
          SmartPlaylistRuleFilterDateTime.missing => null,
          SmartPlaylistRuleFilterDateTime.isWithinLast => '⟳ ${relativeDuration?.amount ?? '?'} ${relativeDuration?.unit.toText() ?? ''}',
          SmartPlaylistRuleFilterDateTime.isNotWithinLast => '⟳ > ${relativeDuration?.amount ?? '?'} ${relativeDuration?.unit.toText() ?? ''}',
        } ??
        '';
  }

  String? _displayTextOf(SmartPlaylistDate? value) {
    if (value == null) return null;
    final date = value.date;
    if (clockOnly) return date.clockFormatted;
    return switch (value.precision) {
      SmartPlaylistDatePrecision.year => '${date.year}',
      SmartPlaylistDatePrecision.month => DateFormat('MMMM yyyy').format(date),
      SmartPlaylistDatePrecision.day => date.dateFormattedOriginal,
      SmartPlaylistDatePrecision.minute || SmartPlaylistDatePrecision.second => date.dateAndClockFormattedOriginal,
    };
  }

  static final _dateTextRegex = RegExp(r'^(\d{4})(?:-(\d{1,2})(?:-(\d{1,2})(?:[ T](\d{1,2}):(\d{1,2})(?::(\d{1,2}))?)?)?)?$');
  static final _clockTextRegex = RegExp(r'^(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?$');

  @override
  SmartPlaylistDate? textToData(String? value) {
    if (value == null || value.isEmpty) return null;
    final text = value.trim();
    return clockOnly ? _parseClockText(text) : _parseDateText(text);
  }

  static SmartPlaylistDate? _parseClockText(String text) {
    final match = _clockTextRegex.firstMatch(text);
    if (match == null) return null;
    final secondText = match[3];
    final hour = int.parse(match[1]!);
    final minute = int.parse(match[2]!);
    final second = secondText == null ? 0 : int.parse(secondText);
    if (hour > 23 || minute > 59 || second > 59) return null;
    final precision = secondText == null ? SmartPlaylistDatePrecision.minute : SmartPlaylistDatePrecision.second;
    return SmartPlaylistDate(DateTime(0, 1, 1, hour, minute, second), precision);
  }

  /// the parts given decide how much the value covers, `2019` is the whole year and `2019-05-14 12:30` that minute.
  static SmartPlaylistDate? _parseDateText(String text) {
    final match = _dateTextRegex.firstMatch(text);
    if (match == null) return _parseIsoText(text);
    final monthText = match[2];
    final dayText = match[3];
    final hourText = match[4];
    final secondText = match[6];
    final year = int.parse(match[1]!);
    final month = monthText == null ? 1 : int.parse(monthText);
    final day = dayText == null ? 1 : int.parse(dayText);
    final hour = hourText == null ? 0 : int.parse(hourText);
    final minute = hourText == null ? 0 : int.parse(match[5]!);
    final second = secondText == null ? 0 : int.parse(secondText);
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > DateUtils.getDaysInMonth(year, month)) return null;
    if (hour > 23 || minute > 59 || second > 59) return null;
    final precision = secondText != null
        ? SmartPlaylistDatePrecision.second
        : hourText != null
        ? SmartPlaylistDatePrecision.minute
        : dayText != null
        ? SmartPlaylistDatePrecision.day
        : monthText != null
        ? SmartPlaylistDatePrecision.month
        : SmartPlaylistDatePrecision.year;
    return SmartPlaylistDate(DateTime(year, month, day, hour, minute, second), precision);
  }

  /// other iso formats (ex: `20190514`) keep meaning what they did before precisions existed.
  static SmartPlaylistDate? _parseIsoText(String text) {
    final date = DateTime.tryParse(text);
    if (date == null) return null;
    return SmartPlaylistDate.legacy(date, clockOnly: false);
  }

  @override
  SmartPlaylistDate? textToData2(String? value) => textToData(value);

  @override
  String? dataToText(SmartPlaylistDate? data) {
    if (data == null) return null;
    final pattern = switch (data.precision) {
      SmartPlaylistDatePrecision.year => 'yyyy',
      SmartPlaylistDatePrecision.month => 'yyyy-MM',
      SmartPlaylistDatePrecision.day => 'yyyy-MM-dd',
      SmartPlaylistDatePrecision.minute => clockOnly ? 'HH:mm' : 'yyyy-MM-dd HH:mm',
      SmartPlaylistDatePrecision.second => clockOnly ? 'HH:mm:ss' : 'yyyy-MM-dd HH:mm:ss',
    };
    return DateFormat(pattern).format(data.date);
  }

  @override
  String? data2ToText(SmartPlaylistDate? data2) => data2 == null ? null : dataToText(data2);

  @override
  String? toHintText() => clockOnly ? 'HH:mm[:ss]' : 'YYYY[-MM[-DD]] [HH:mm[:ss]]';

  bool _matchesTimestamp(int? msse, _SmartPlaylistResolveContext context) => _dateFn(msse, context);

  late final _comparesClockOnly = clockOnly && !filter.isRelativeDate;

  /// seconds of the local day for clock only comparisons, microseconds since epoch otherwise, ints since each local date costs a timezone lookup.
  int _valueOfDate(DateTime date) {
    if (_comparesClockOnly) return _secondsOfDay(date);
    return date.microsecondsSinceEpoch;
  }

  int? _valueOf(SmartPlaylistDate? value) {
    if (value == null) return null;
    return _valueOfDate(value.date);
  }

  int _valueOfTimestamp(int msse) {
    if (!_comparesClockOnly) return msse * Duration.microsecondsPerMillisecond;
    final date = DateTime.fromMillisecondsSinceEpoch(msse);
    return _secondsOfDay(date);
  }

  static int _secondsOfDay(DateTime date) => date.hour * Duration.secondsPerHour + date.minute * Duration.secondsPerMinute + date.second;

  static const _kClockNoEnd = Duration.secondsPerDay;

  late final _dataValue = _valueOf(data);
  late final _data2Value = _valueOf(data2);

  int? _exclusiveEndOf(SmartPlaylistDate? value) {
    if (value == null) return null;
    final date = value.date;
    if (_comparesClockOnly) {
      final coveredSeconds = value.precision == SmartPlaylistDatePrecision.second ? 1 : Duration.secondsPerMinute;
      return _secondsOfDay(date) + coveredSeconds;
    }
    return switch (value.precision) {
      SmartPlaylistDatePrecision.year => DateTime(date.year + 1).microsecondsSinceEpoch,
      SmartPlaylistDatePrecision.month => DateTime(date.year, date.month + 1).microsecondsSinceEpoch,
      SmartPlaylistDatePrecision.day => DateTime(date.year, date.month, date.day + 1).microsecondsSinceEpoch,
      SmartPlaylistDatePrecision.minute => date.microsecondsSinceEpoch + Duration.microsecondsPerMinute,
      SmartPlaylistDatePrecision.second => date.microsecondsSinceEpoch + Duration.microsecondsPerSecond,
    };
  }

  late final _dataEndValue = _exclusiveEndOf(data);
  late final _data2EndValue = _exclusiveEndOf(data2);

  /// both values are included whole, so `2019` to `2019-06` still covers all of 2019.
  late final (int?, int?) _rangeValues = _dataValue == null || _data2Value == null || _dataEndValue == null || _data2EndValue == null
      ? (_dataValue, _data2EndValue)
      : (_dataValue.withMaximum(_data2Value), _dataEndValue.withMinimum(_data2EndValue));

  late final _startValue = _rangeValues.$1;
  late final _endValue = _rangeValues.$2;

  late final _crossesMidnight = _comparesClockOnly && _dataValue != null && _data2Value != null && _data2Value < _dataValue;

  bool _isWithinData(int start, int end) {
    final dataValue = _dataValue;
    final dataEndValue = _dataEndValue;
    return dataValue != null && dataEndValue != null && start >= dataValue && end <= dataEndValue;
  }

  bool _isOutsideData(int start, int end) {
    final dataValue = _dataValue;
    final dataEndValue = _dataEndValue;
    return dataValue != null && dataEndValue != null && (end <= dataValue || start >= dataEndValue);
  }

  /// in dates world, one usually means an inclusive date.
  /// ex: in between 2015-2016, so both exact dates should be included as well.
  /// usually useful for types like: `isBefore`, `isAfter`, `isInBetween`.
  /// but not for types like: `isOutside`.
  ///
  /// a track date covers `[start, end)`, a timestamp only its own microsecond and a year-only tag its whole year,
  /// it matches only when all of it is on the filter's side, a `2019` tag isn't the same as `2019-01-01`.
  late final bool Function(int start, int end, _SmartPlaylistResolveContext context) _rangeFn = switch (filter) {
    SmartPlaylistRuleFilterDateTime.isSame => (start, end, _) => _isWithinData(start, end),
    SmartPlaylistRuleFilterDateTime.isNotSame => (start, end, _) => _isOutsideData(start, end),
    SmartPlaylistRuleFilterDateTime.isBefore => (start, end, _) => _dataEndValue != null && end <= _dataEndValue,
    SmartPlaylistRuleFilterDateTime.isAfter => (start, end, _) => _dataValue != null && start >= _dataValue,
    SmartPlaylistRuleFilterDateTime.isInBetween => (start, end, context) {
      if (_crossesMidnight) return start >= _dataValue! || end <= _data2EndValue!;
      return _startValue != null && start >= _startValue && end <= _endValueOf(context);
    },
    SmartPlaylistRuleFilterDateTime.isOutside => (start, end, context) {
      if (_crossesMidnight) return start < _dataValue! && start >= _data2EndValue!;
      return (_startValue != null && end <= _startValue) || start >= _endValueOf(context);
    },
    SmartPlaylistRuleFilterDateTime.isWithinLast => (start, end, context) {
      final boundary = _relativeBoundaryOf(context);
      return boundary != null && start > boundary;
    },
    SmartPlaylistRuleFilterDateTime.isNotWithinLast => (start, end, context) {
      final boundary = _relativeBoundaryOf(context);
      return boundary != null && end <= boundary;
    },
    SmartPlaylistRuleFilterDateTime.exists => (start, end, _) => true,
    SmartPlaylistRuleFilterDateTime.missing => (start, end, _) => false,
  };

  late final bool _matchesUnknownDate = switch (filter) {
    SmartPlaylistRuleFilterDateTime.isNotWithinLast || SmartPlaylistRuleFilterDateTime.missing => true,
    SmartPlaylistRuleFilterDateTime.isSame ||
    SmartPlaylistRuleFilterDateTime.isNotSame ||
    SmartPlaylistRuleFilterDateTime.isBefore ||
    SmartPlaylistRuleFilterDateTime.isAfter ||
    SmartPlaylistRuleFilterDateTime.isInBetween ||
    SmartPlaylistRuleFilterDateTime.isOutside ||
    SmartPlaylistRuleFilterDateTime.isWithinLast ||
    SmartPlaylistRuleFilterDateTime.exists => false,
  };

  int _endValueOf(_SmartPlaylistResolveContext context) {
    final endValue = _endValue;
    if (endValue != null) return endValue;
    return _comparesClockOnly ? _kClockNoEnd : context.nowMicros;
  }

  int? _relativeBoundaryOf(_SmartPlaylistResolveContext context) {
    final relativeDuration = this.relativeDuration;
    if (relativeDuration == null) return null;
    return context.relativeBoundaryMicrosOf(relativeDuration);
  }

  bool _yearFn(Track track, _SmartPlaylistResolveContext context) {
    // -- year tags have no clock
    if (_comparesClockOnly) return _matchesUnknownDate;
    final yearRange = context.yearRangeOf(track);
    if (yearRange == null) return _matchesUnknownDate;
    return _rangeFn(yearRange.startMicros, yearRange.endMicros, context);
  }

  bool _dateFn(int? trackDateMSSE, _SmartPlaylistResolveContext context) {
    if (trackDateMSSE == null || trackDateMSSE == 0) return _matchesUnknownDate;
    final value = _valueOfTimestamp(trackDateMSSE);
    return _rangeFn(value, value + 1, context);
  }

  /// later dates only ever match more (rising) or less (falling), so sorted listens can be decided by their oldest or newest one.
  late final _DateTrend? _listensTrend = switch (filter) {
    SmartPlaylistRuleFilterDateTime.isAfter => _comparesClockOnly ? null : _DateTrend.rising,
    SmartPlaylistRuleFilterDateTime.isBefore => _comparesClockOnly ? null : _DateTrend.falling,
    SmartPlaylistRuleFilterDateTime.isWithinLast => _DateTrend.rising,
    SmartPlaylistRuleFilterDateTime.isNotWithinLast => _DateTrend.falling,
    SmartPlaylistRuleFilterDateTime.isSame ||
    SmartPlaylistRuleFilterDateTime.isNotSame ||
    SmartPlaylistRuleFilterDateTime.isInBetween ||
    SmartPlaylistRuleFilterDateTime.isOutside ||
    SmartPlaylistRuleFilterDateTime.exists ||
    SmartPlaylistRuleFilterDateTime.missing => null,
  };

  bool _listensFn(Track track, _SmartPlaylistResolveContext context, {required bool every}) {
    final listens = SmartPlaylistRuleBase.topTracksMapListens[track];
    if (listens == null) return _dateFn(null, context);
    final trend = _listensTrend;
    // -- sorted, an oldest listen after 1970 means none of them is unknown (0)
    if (trend != null && listens.first > 0) {
      final decidingListen = switch (trend) {
        _DateTrend.rising => every ? listens.first : listens.last,
        _DateTrend.falling => every ? listens.last : listens.first,
      };
      return _dateFn(decidingListen, context);
    }
    if (every) return listens.every((msse) => _dateFn(msse, context));
    return listens.any((msse) => _dateFn(msse, context));
  }

  int? _getFavouriteDate(Track track) {
    final fav = SmartPlaylistRuleBase.favouritesMap;
    if (fav.isSubItemFavourite(track)) {
      final res = fav.firstItemForSubItem(track);
      if (res != null) {
        return res.item.dateAdded;
      }
    }
    return null;
  }

  @override
  bool _matches(Track track, _SmartPlaylistResolveContext context) {
    return switch (source) {
      SmartPlaylistRuleFilterDateTimeSource.dateAdded => _dateFn(track.dateAdded, context),
      SmartPlaylistRuleFilterDateTimeSource.dateModified => _dateFn(track.dateModified, context),
      SmartPlaylistRuleFilterDateTimeSource.year => _yearFn(track, context),
      SmartPlaylistRuleFilterDateTimeSource.anyListen => _listensFn(track, context, every: false),
      SmartPlaylistRuleFilterDateTimeSource.allListens => _listensFn(track, context, every: true),
      SmartPlaylistRuleFilterDateTimeSource.firstListen => _dateFn(SmartPlaylistRuleBase.topTracksMapListens[track]?.firstOrNull, context),
      SmartPlaylistRuleFilterDateTimeSource.lastListen => _dateFn(SmartPlaylistRuleBase.topTracksMapListens[track]?.lastOrNull, context),
      SmartPlaylistRuleFilterDateTimeSource.favouriteDate => _dateFn(_getFavouriteDate(track), context),
      SmartPlaylistRuleFilterDateTimeSource.rangeOnly => true,
    };
  }

  factory SmartPlaylistRuleDateTime.fromMap(Map map) {
    final clockOnly = map['clockOnly'] == true;
    return SmartPlaylistRuleDateTime(
      data: _dateFromMap(map['data'] as int?, map['dataPrecision'], clockOnly: clockOnly),
      data2: _dateFromMap(map['data2'] as int?, map['data2Precision'], clockOnly: clockOnly),
      filter: SmartPlaylistRuleFilterDateTime.values.getEnum(map['filter'])!,
      source: SmartPlaylistRuleFilterDateTimeSource.values.getEnum(map['source'])!,
      enableCleanup: map['enableCleanup'] == true,
      clockOnly: clockOnly,
      relativeDuration: map['relativeDuration'] != null ? SmartPlaylistRelativeDuration.fromMap(map['relativeDuration']) : null,
    );
  }

  static SmartPlaylistDate? _dateFromMap(int? msse, dynamic precisionName, {required bool clockOnly}) {
    if (msse == null) return null;
    final date = DateTime.fromMillisecondsSinceEpoch(msse);
    final precision = SmartPlaylistDatePrecision.values.getEnum(precisionName);
    if (precision == null) return SmartPlaylistDate.legacy(date, clockOnly: clockOnly);
    return SmartPlaylistDate(date, precision);
  }

  @override
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'type': type.name,
      'filter': filter.name,
      'source': source.name,
      'data': ?data?.date.millisecondsSinceEpoch,
      'dataPrecision': ?data?.precision.name,
      'data2': ?data2?.date.millisecondsSinceEpoch,
      'data2Precision': ?data2?.precision.name,
      if (enableCleanup) 'enableCleanup': enableCleanup,
      if (clockOnly) 'clockOnly': clockOnly,
      'relativeDuration': ?relativeDuration?.toMap(),
    };
  }
}

enum SmartPlaylistRuleFilterDateTime with SmartPlaylistRuleFilter {
  isSame,
  isNotSame,
  isBefore,
  isAfter,
  isInBetween(requiresData2Field: true),
  isOutside(requiresData2Field: true),
  isWithinLast(requiresDataField: false),
  isNotWithinLast(requiresDataField: false),
  exists(requiresDataField: false),
  missing(requiresDataField: false),
  ;

  @override
  final bool requiresDataField;
  @override
  final bool requiresData2Field;

  // ignore: unused_element_parameter
  const SmartPlaylistRuleFilterDateTime({this.requiresDataField = true, this.requiresData2Field = false});

  @override
  SmartPlaylistFilterType get type => SmartPlaylistFilterType.dateTime;

  @override
  bool get isRelativeDate => switch (this) {
    isWithinLast || isNotWithinLast => true,
    _ => false,
  };

  @override
  String toText() => switch (this) {
    SmartPlaylistRuleFilterDateTime.isSame => lang.isSame,
    SmartPlaylistRuleFilterDateTime.isNotSame => lang.isNotSame,
    SmartPlaylistRuleFilterDateTime.isBefore => lang.isBefore,
    SmartPlaylistRuleFilterDateTime.isAfter => lang.isAfter,
    SmartPlaylistRuleFilterDateTime.isInBetween => lang.isInBetween,
    SmartPlaylistRuleFilterDateTime.isOutside => lang.isOutside,
    SmartPlaylistRuleFilterDateTime.isWithinLast => lang.isWithinLast,
    SmartPlaylistRuleFilterDateTime.isNotWithinLast => lang.isNotWithinLast,
    SmartPlaylistRuleFilterDateTime.exists => lang.exists,
    SmartPlaylistRuleFilterDateTime.missing => lang.missing,
  };

  @override
  IconData? toIcon() => switch (this) {
    SmartPlaylistRuleFilterDateTime.isSame => null,
    SmartPlaylistRuleFilterDateTime.isNotSame => null,
    SmartPlaylistRuleFilterDateTime.isBefore => null,
    SmartPlaylistRuleFilterDateTime.isAfter => null,
    SmartPlaylistRuleFilterDateTime.isInBetween => null,
    SmartPlaylistRuleFilterDateTime.isOutside => null,
    SmartPlaylistRuleFilterDateTime.isWithinLast => Broken.frame_1,
    SmartPlaylistRuleFilterDateTime.isNotWithinLast => Broken.export_2,
    SmartPlaylistRuleFilterDateTime.exists => Broken.tick_circle,
    SmartPlaylistRuleFilterDateTime.missing => Broken.close_circle,
  };

  @override
  String? toIconText() => switch (this) {
    SmartPlaylistRuleFilterDateTime.isSame => '=',
    SmartPlaylistRuleFilterDateTime.isNotSame => '≠',
    SmartPlaylistRuleFilterDateTime.isBefore => '<--',
    SmartPlaylistRuleFilterDateTime.isAfter => '-->',
    SmartPlaylistRuleFilterDateTime.isInBetween => '-><-',
    SmartPlaylistRuleFilterDateTime.isOutside => '<-->',
    SmartPlaylistRuleFilterDateTime.isWithinLast => '⟳',
    SmartPlaylistRuleFilterDateTime.isNotWithinLast => '⟳ >',
    SmartPlaylistRuleFilterDateTime.exists => null,
    SmartPlaylistRuleFilterDateTime.missing => null,
  };
}

enum SmartPlaylistRuleFilterDateTimeSource with SmartPlaylistRuleFilterSource {
  dateAdded,
  dateModified,
  year,
  anyListen,
  allListens,
  firstListen,
  lastListen,
  favouriteDate,
  rangeOnly,
  ;

  @override
  SmartPlaylistFilterType get type => SmartPlaylistFilterType.dateTime;

  @override
  SmartPlaylistRuleFilter get recommendedFilter => SmartPlaylistRuleFilterDateTime.isAfter;

  @override
  bool get supportsCleanup => false;

  @override
  bool get supportsClockOnly => true;

  @override
  bool get isAutoSource => switch (this) {
    SmartPlaylistRuleFilterDateTimeSource.rangeOnly => true,
    _ => false,
  };

  @override
  String toText() => switch (this) {
    SmartPlaylistRuleFilterDateTimeSource.dateAdded => lang.dateAdded,
    SmartPlaylistRuleFilterDateTimeSource.dateModified => lang.dateModified,
    SmartPlaylistRuleFilterDateTimeSource.year => lang.year,
    SmartPlaylistRuleFilterDateTimeSource.anyListen => lang.anyListen,
    SmartPlaylistRuleFilterDateTimeSource.allListens => lang.allListens,
    SmartPlaylistRuleFilterDateTimeSource.firstListen => lang.firstListen,
    SmartPlaylistRuleFilterDateTimeSource.lastListen => lang.lastListen,
    SmartPlaylistRuleFilterDateTimeSource.favouriteDate => lang.favouritedDate,
    SmartPlaylistRuleFilterDateTimeSource.rangeOnly => lang.betweenDates,
  };

  @override
  IconData? toIcon() => switch (this) {
    SmartPlaylistRuleFilterDateTimeSource.dateAdded => Broken.calendar_add,
    SmartPlaylistRuleFilterDateTimeSource.dateModified => Broken.calendar_edit,
    SmartPlaylistRuleFilterDateTimeSource.year => Broken.calendar,
    SmartPlaylistRuleFilterDateTimeSource.anyListen => Broken.math,
    SmartPlaylistRuleFilterDateTimeSource.allListens => Broken.math,
    SmartPlaylistRuleFilterDateTimeSource.firstListen => Broken.cake,
    SmartPlaylistRuleFilterDateTimeSource.lastListen => Broken.clock,
    SmartPlaylistRuleFilterDateTimeSource.favouriteDate => Broken.heart,
    SmartPlaylistRuleFilterDateTimeSource.rangeOnly => Broken.link_circle,
  };
}

enum SmartPlaylistRelativeUnit {
  seconds,
  minutes,
  hours,
  days,
  weeks,
  months,
  years,
  ;

  String toText() => switch (this) {
    SmartPlaylistRelativeUnit.seconds => lang.seconds,
    SmartPlaylistRelativeUnit.minutes => lang.minutes,
    SmartPlaylistRelativeUnit.hours => lang.hours,
    SmartPlaylistRelativeUnit.days => lang.days,
    SmartPlaylistRelativeUnit.weeks => lang.weeks,
    SmartPlaylistRelativeUnit.months => lang.months,
    SmartPlaylistRelativeUnit.years => lang.years,
  };
}

class SmartPlaylistRelativeDuration {
  final int amount;
  final SmartPlaylistRelativeUnit unit;

  const SmartPlaylistRelativeDuration({
    required this.amount,
    required this.unit,
  });

  const SmartPlaylistRelativeDuration.initial({
    this.amount = 3,
    this.unit = SmartPlaylistRelativeUnit.days,
  });

  DateTime getBoundary(DateTime now) {
    return switch (unit) {
      SmartPlaylistRelativeUnit.seconds => now.subtract(Duration(seconds: amount)),
      SmartPlaylistRelativeUnit.minutes => now.subtract(Duration(minutes: amount)),
      SmartPlaylistRelativeUnit.hours => now.subtract(Duration(hours: amount)),
      SmartPlaylistRelativeUnit.days => now.subtract(Duration(days: amount)),
      SmartPlaylistRelativeUnit.weeks => now.subtract(Duration(days: amount * 7)),
      SmartPlaylistRelativeUnit.months => _monthsBefore(now, amount),
      SmartPlaylistRelativeUnit.years => _monthsBefore(now, amount * 12),
    };
  }

  static DateTime _monthsBefore(DateTime now, int months) {
    final targetMonthIndex = now.year * 12 + now.month - 1 - months;
    final year = targetMonthIndex ~/ 12;
    final month = targetMonthIndex % 12 + 1;
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final day = now.day.withMaximum(daysInMonth);
    return DateTime(year, month, day);
  }

  Map<String, dynamic> toMap() => {
    'amount': amount,
    'unit': unit.name,
  };

  factory SmartPlaylistRelativeDuration.fromMap(Map map) => SmartPlaylistRelativeDuration(
    amount: map['amount'] as int? ?? 1,
    unit: SmartPlaylistRelativeUnit.values.getEnum(map['unit']) ?? SmartPlaylistRelativeUnit.days,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SmartPlaylistRelativeDuration) return false;

    return other.amount == amount && other.unit == unit;
  }

  @override
  int get hashCode => amount.hashCode ^ unit.hashCode;
}

enum SmartPlaylistDatePrecision {
  year,
  month,
  day,
  minute,
  second,
}

/// a rule date and how much of time it covers, starting at [date].
///
/// by claude
class SmartPlaylistDate {
  final DateTime date;
  final SmartPlaylistDatePrecision precision;

  const SmartPlaylistDate(this.date, this.precision);

  /// rules saved before precisions existed, midnight meant the whole day and a clock with zero seconds the whole minute.
  factory SmartPlaylistDate.legacy(DateTime date, {required bool clockOnly}) {
    final SmartPlaylistDatePrecision precision;
    if (clockOnly) {
      precision = date.second == 0 ? .minute : .second;
    } else {
      precision = _isMidnight(date) ? .day : .second;
    }
    return SmartPlaylistDate(date, precision);
  }

  static bool _isMidnight(DateTime date) => date.hour == 0 && date.minute == 0 && date.second == 0 && date.millisecond == 0 && date.microsecond == 0;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SmartPlaylistDate) return false;

    return other.date == date && other.precision == precision;
  }

  @override
  int get hashCode => date.hashCode ^ precision.hashCode;
}

enum _DateTrend {
  rising,
  falling,
}
