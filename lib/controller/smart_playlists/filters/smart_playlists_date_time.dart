part of '../smart_playlists_controller.dart';

// rewritten by claude, new one compares only the chosen date parts (ex: weekday and clock of any date) and takes values relative to now
final class SmartPlaylistRuleDateTime
    extends SmartPlaylistRuleBase<SmartPlaylistDateValue, SmartPlaylistDateValue, SmartPlaylistRuleFilterDateTime, SmartPlaylistRuleFilterDateTimeSource> {
  SmartPlaylistRuleDateTime({
    required super.data,
    required super.data2,
    required super.filter,
    required super.source,
    required super.enableCleanup,
    required SmartPlaylistDateParts parts,
    required super.relativeDuration,
  }) : parts = filter.isRelativeDate || !filter.requiresDataField ? SmartPlaylistDateParts.date : parts,
       super(type: SmartPlaylistFilterType.dateTime);

  /// filters without a value (relative ones, exists...) always compare the date.
  final SmartPlaylistDateParts parts;

  @override
  SmartPlaylistRuleDateTime copyWith({
    (SmartPlaylistDateValue? data, SmartPlaylistDateValue? data2)? datas,
    SmartPlaylistRuleFilterDateTime? filter,
    bool? enableCleanup,
    SmartPlaylistDateParts? parts,
    SmartPlaylistRelativeDuration? relativeDuration,
  }) => SmartPlaylistRuleDateTime(
    data: datas != null ? datas.$1 : this.data,
    data2: datas != null ? datas.$2 : this.data2,
    filter: filter ?? this.filter,
    source: this.source,
    enableCleanup: enableCleanup ?? this.enableCleanup,
    parts: parts ?? this.parts,
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
    if (filter.isRelativeDate && (relativeDuration == null || relativeDuration!.amount <= 0)) return lang.emptyValue;
    if (filter.requiresDataField && !_isComplete(data)) return lang.emptyValue;
    if (filter.requiresData2Field && !_isComplete(data2)) return lang.emptyValue;
    return null;
  }

  bool _isComplete(SmartPlaylistDateValue? value) => switch (value) {
    null => false,
    SmartPlaylistNowDate() => true,
    SmartPlaylistDate() => parts.isCalendarDate,
    SmartPlaylistDatePartsValue partsValue => !parts.isCalendarDate && partsValue.hasAll(parts),
  };

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

  String? _displayTextOf(SmartPlaylistDateValue? value) => switch (value) {
    null => null,
    SmartPlaylistDate date => _fixedDateDisplayTextOf(date),
    SmartPlaylistDatePartsValue partsValue => _partsDisplayTextOf(partsValue),
    SmartPlaylistNowDate nowDate => _nowDisplayTextOf(nowDate),
  };

  static String _fixedDateDisplayTextOf(SmartPlaylistDate value) {
    final date = value.date;
    return switch (value.precision) {
      SmartPlaylistDatePrecision.year => '${date.year}',
      SmartPlaylistDatePrecision.month => DateFormat('MMMM yyyy').format(date),
      SmartPlaylistDatePrecision.week || SmartPlaylistDatePrecision.day => date.dateFormattedOriginal,
      SmartPlaylistDatePrecision.hour || SmartPlaylistDatePrecision.minute || SmartPlaylistDatePrecision.second => date.dateAndClockFormattedOriginal,
    };
  }

  String _partsDisplayTextOf(SmartPlaylistDatePartsValue value) {
    final month = value.month;
    final weekday = value.weekday;
    final secondOfDay = value.secondOfDay;
    return [
      if (_hasYear) '${value.year ?? '?'}',
      if (_hasMonth) month == null ? '?' : SmartPlaylistDatePartsValue.monthToText(month),
      if (_hasDay) '${lang.day} ${value.day ?? '?'}',
      if (_hasWeekday) weekday == null ? '?' : SmartPlaylistDatePartsValue.weekdayToText(weekday),
      if (_hasTime) secondOfDay == null ? '?' : SmartPlaylistDatePartsValue.clockToText(secondOfDay, hasSeconds: value.hasSeconds),
    ].join(' · ');
  }

  String _nowDisplayTextOf(SmartPlaylistNowDate value) {
    final amount = value.offsetAmount;
    final unitText = value.offsetUnit.toText();
    if (amount == 0) return parts.isCalendarDate ? '${lang.now} ($unitText)' : lang.now;
    final sign = amount > 0 ? '+' : '−';
    return '${lang.now} $sign ${amount.abs()} $unitText';
  }

  static final _dateTextRegex = RegExp(r'^(\d{4})(?:-(\d{1,2})(?:-(\d{1,2})(?:[ T](\d{1,2}):(\d{1,2})(?::(\d{1,2}))?)?)?)?$');

  @override
  SmartPlaylistDate? textToData(String? value) {
    if (value == null || value.isEmpty) return null;
    final date = _parseDateText(value.trim());
    if (date == null) return null;
    if (!_hasTime && date.precision.hasClock) return null;
    return date;
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
    return SmartPlaylistDate.legacy(date);
  }

  @override
  SmartPlaylistDate? textToData2(String? value) => textToData(value);

  @override
  String? dataToText(SmartPlaylistDateValue? data) {
    if (data is! SmartPlaylistDate) return null;
    final pattern = switch (data.precision) {
      SmartPlaylistDatePrecision.year => 'yyyy',
      SmartPlaylistDatePrecision.month => 'yyyy-MM',
      SmartPlaylistDatePrecision.week || SmartPlaylistDatePrecision.day => 'yyyy-MM-dd',
      SmartPlaylistDatePrecision.hour || SmartPlaylistDatePrecision.minute => 'yyyy-MM-dd HH:mm',
      SmartPlaylistDatePrecision.second => 'yyyy-MM-dd HH:mm:ss',
    };
    return DateFormat(pattern).format(data.date);
  }

  @override
  String? data2ToText(SmartPlaylistDateValue? data2) => data2 == null ? null : dataToText(data2);

  @override
  String? toHintText() => _hasTime ? 'YYYY-MM-DD HH:mm' : 'YYYY-MM-DD';

  late final _comparesParts = !parts.isCalendarDate && !filter.isRelativeDate;
  late final _hasYear = parts.has(SmartPlaylistDatePart.year);
  late final _hasMonth = parts.has(SmartPlaylistDatePart.month);
  late final _hasDay = parts.has(SmartPlaylistDatePart.day);
  late final _hasWeekday = parts.has(SmartPlaylistDatePart.weekday);
  late final _hasTime = parts.has(SmartPlaylistDatePart.time);

  /// without the year, parts repeat (months every year, weekdays every week), so a range can wrap around their end.
  late final _isCyclic = _comparesParts && !_hasYear;

  /// microseconds since epoch for full dates, a key of the compared parts otherwise, ints since each local date costs a timezone lookup.
  int _valueOfTimestamp(int msse) {
    if (!_comparesParts) return msse * Duration.microsecondsPerMillisecond;
    final date = DateTime.fromMillisecondsSinceEpoch(msse);
    return _partsKeyOf(date);
  }

  /// the compared parts in a mixed radix, so keys sort like the parts do.
  int _partsKey(int year, int month, int day, int weekday, int secondOfDay) {
    var key = 0;
    if (_hasYear) key = year;
    if (_hasMonth) key = key * SmartPlaylistDatePart.month.keyRadix + month;
    if (_hasDay) key = key * SmartPlaylistDatePart.day.keyRadix + day;
    if (_hasWeekday) key = key * SmartPlaylistDatePart.weekday.keyRadix + weekday;
    if (_hasTime) key = key * SmartPlaylistDatePart.time.keyRadix + secondOfDay;
    return key;
  }

  int _partsKeyOf(DateTime date) => _partsKey(date.year, date.month, date.day, date.weekday, SmartPlaylistDatePartsValue.secondOfDayOf(date));

  static const _kPartsNoEnd = 1 << 62;

  late final _hasNowValue = data is SmartPlaylistNowDate || data2 is SmartPlaylistNowDate;
  late final _fixedSpans = _computeSpans(null);

  _DateSpans _spansOf(_SmartPlaylistResolveContext context) {
    if (!_hasNowValue) return _fixedSpans;
    return context.dateSpansOf(this);
  }

  _DateSpans _computeSpans(DateTime? now) {
    final span = _spanOf(data, now);
    final span2 = _spanOf(data2, now);
    return _DateSpans(span, span2, isCyclic: _isCyclic);
  }

  _KeySpan? _spanOf(SmartPlaylistDateValue? value, DateTime? now) => switch (value) {
    null => null,
    SmartPlaylistDate date => _comparesParts ? null : _fullSpanOf(date.date, date.precision),
    SmartPlaylistDatePartsValue partsValue => _comparesParts ? _partsSpanOf(partsValue) : null,
    SmartPlaylistNowDate nowDate => now == null ? null : _nowSpanOf(nowDate, now),
  };

  static _KeySpan _fullSpanOf(DateTime start, SmartPlaylistDatePrecision precision) {
    final startMicros = start.microsecondsSinceEpoch;
    final endMicros = switch (precision) {
      SmartPlaylistDatePrecision.year => DateTime(start.year + 1).microsecondsSinceEpoch,
      SmartPlaylistDatePrecision.month => DateTime(start.year, start.month + 1).microsecondsSinceEpoch,
      SmartPlaylistDatePrecision.week => DateTime(start.year, start.month, start.day + DateTime.daysPerWeek).microsecondsSinceEpoch,
      SmartPlaylistDatePrecision.day => DateTime(start.year, start.month, start.day + 1).microsecondsSinceEpoch,
      SmartPlaylistDatePrecision.hour => startMicros + Duration.microsecondsPerHour,
      SmartPlaylistDatePrecision.minute => startMicros + Duration.microsecondsPerMinute,
      SmartPlaylistDatePrecision.second => startMicros + Duration.microsecondsPerSecond,
    };
    return (start: startMicros, end: endMicros);
  }

  _KeySpan? _partsSpanOf(SmartPlaylistDatePartsValue value) {
    if (!value.hasAll(parts)) return null;
    final key = _partsKey(value.year ?? 0, value.month ?? 0, value.day ?? 0, value.weekday ?? 0, value.secondOfDay ?? 0);
    final coveredKeys = _hasTime && !value.hasSeconds ? Duration.secondsPerMinute : 1;
    return (start: key, end: key + coveredKeys);
  }

  /// full dates cover the whole offset unit (now + 0 months is this month), compared parts cover the shifted minute.
  _KeySpan _nowSpanOf(SmartPlaylistNowDate value, DateTime now) {
    final shifted = value.shiftedFrom(now);
    if (!_comparesParts) {
      final precision = value.offsetUnit.precision;
      final start = _startOf(shifted, precision);
      return _fullSpanOf(start, precision);
    }
    final secondOfMinuteStart = SmartPlaylistDatePartsValue.secondOfDayOf(shifted) ~/ Duration.secondsPerMinute * Duration.secondsPerMinute;
    final key = _partsKey(shifted.year, shifted.month, shifted.day, shifted.weekday, secondOfMinuteStart);
    final coveredKeys = _hasTime ? Duration.secondsPerMinute : 1;
    return (start: key, end: key + coveredKeys);
  }

  static DateTime _startOf(DateTime date, SmartPlaylistDatePrecision precision) => switch (precision) {
    SmartPlaylistDatePrecision.year => DateTime(date.year),
    SmartPlaylistDatePrecision.month => DateTime(date.year, date.month),
    SmartPlaylistDatePrecision.week => DateTime(date.year, date.month, date.day - (date.weekday - DateTime.monday)),
    SmartPlaylistDatePrecision.day => DateTime(date.year, date.month, date.day),
    SmartPlaylistDatePrecision.hour => DateTime(date.year, date.month, date.day, date.hour),
    SmartPlaylistDatePrecision.minute => DateTime(date.year, date.month, date.day, date.hour, date.minute),
    SmartPlaylistDatePrecision.second => DateTime(date.year, date.month, date.day, date.hour, date.minute, date.second),
  };

  /// in dates world, one usually means an inclusive date.
  /// ex: in between 2015-2016, so both exact dates should be included as well.
  /// usually useful for types like: `isBefore`, `isAfter`, `isInBetween`.
  /// but not for types like: `isOutside`.
  ///
  /// a track date covers `[start, end)`, a timestamp only its own microsecond and a year-only tag its whole year,
  /// it matches only when all of it is on the filter's side, a `2019` tag isn't the same as `2019-01-01`.
  late final bool Function(int start, int end, _DateSpans spans, _SmartPlaylistResolveContext context) _rangeFn = switch (filter) {
    SmartPlaylistRuleFilterDateTime.isSame => (start, end, spans, _) => spans.isWithin(start, end),
    SmartPlaylistRuleFilterDateTime.isNotSame => (start, end, spans, _) => spans.isOutside(start, end),
    SmartPlaylistRuleFilterDateTime.isBefore => (start, end, spans, _) {
      final dataEnd = spans.end;
      return dataEnd != null && end <= dataEnd;
    },
    SmartPlaylistRuleFilterDateTime.isAfter => (start, end, spans, _) {
      final dataStart = spans.start;
      return dataStart != null && start >= dataStart;
    },
    SmartPlaylistRuleFilterDateTime.isInBetween => (start, end, spans, context) {
      final rangeStart = spans.rangeStart;
      if (rangeStart == null) return false;
      final rangeEnd = _rangeEndOf(spans, context);
      if (spans.wrapsAround) return start >= rangeStart || end <= rangeEnd;
      return start >= rangeStart && end <= rangeEnd;
    },
    SmartPlaylistRuleFilterDateTime.isOutside => (start, end, spans, context) {
      final rangeStart = spans.rangeStart;
      final rangeEnd = _rangeEndOf(spans, context);
      if (spans.wrapsAround && rangeStart != null) return start < rangeStart && start >= rangeEnd;
      return (rangeStart != null && end <= rangeStart) || start >= rangeEnd;
    },
    SmartPlaylistRuleFilterDateTime.isWithinLast => (start, end, spans, context) {
      final boundary = _relativeBoundaryOf(context);
      return boundary != null && start > boundary;
    },
    SmartPlaylistRuleFilterDateTime.isNotWithinLast => (start, end, spans, context) {
      final boundary = _relativeBoundaryOf(context);
      return boundary != null && end <= boundary;
    },
    SmartPlaylistRuleFilterDateTime.exists => (start, end, spans, _) => true,
    SmartPlaylistRuleFilterDateTime.missing => (start, end, spans, _) => false,
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

  int _rangeEndOf(_DateSpans spans, _SmartPlaylistResolveContext context) {
    final rangeEnd = spans.rangeEnd;
    if (rangeEnd != null) return rangeEnd;
    return _comparesParts ? _kPartsNoEnd : context.nowMicros;
  }

  int? _relativeBoundaryOf(_SmartPlaylistResolveContext context) {
    final relativeDuration = this.relativeDuration;
    if (relativeDuration == null) return null;
    return context.relativeBoundaryMicrosOf(relativeDuration);
  }

  bool _yearFn(Track track, _DateSpans spans, _SmartPlaylistResolveContext context) {
    final yearRange = context.yearRangeOf(track);
    if (yearRange == null) return _matchesUnknownDate;
    if (!_comparesParts) return _rangeFn(yearRange.startMicros, yearRange.endMicros, spans, context);
    final key = _yearPartsKeyOf(yearRange);
    if (key == null) return _matchesUnknownDate;
    return _rangeFn(key, key + 1, spans, context);
  }

  /// year tags have no clock, and year-only ones know nothing below the year.
  int? _yearPartsKeyOf(_YearTagRange yearRange) {
    if (_hasTime) return null;
    if (yearRange.isYearOnly && (_hasMonth || _hasDay || _hasWeekday)) return null;
    final date = DateTime.fromMicrosecondsSinceEpoch(yearRange.startMicros);
    return _partsKeyOf(date);
  }

  bool _dateFn(int? trackDateMSSE, _DateSpans spans, _SmartPlaylistResolveContext context) {
    if (trackDateMSSE == null || trackDateMSSE == 0) return _matchesUnknownDate;
    final value = _valueOfTimestamp(trackDateMSSE);
    return _rangeFn(value, value + 1, spans, context);
  }

  bool _matchesTimestamp(int? msse, _SmartPlaylistResolveContext context) => _dateFn(msse, _spansOf(context), context);

  /// later dates only ever match more (rising) or less (falling), so sorted listens can be decided by their oldest or newest one.
  late final _DateTrend? _listensTrend = switch (filter) {
    SmartPlaylistRuleFilterDateTime.isAfter => _comparesParts ? null : _DateTrend.rising,
    SmartPlaylistRuleFilterDateTime.isBefore => _comparesParts ? null : _DateTrend.falling,
    SmartPlaylistRuleFilterDateTime.isWithinLast => _DateTrend.rising,
    SmartPlaylistRuleFilterDateTime.isNotWithinLast => _DateTrend.falling,
    SmartPlaylistRuleFilterDateTime.isSame ||
    SmartPlaylistRuleFilterDateTime.isNotSame ||
    SmartPlaylistRuleFilterDateTime.isInBetween ||
    SmartPlaylistRuleFilterDateTime.isOutside ||
    SmartPlaylistRuleFilterDateTime.exists ||
    SmartPlaylistRuleFilterDateTime.missing => null,
  };

  bool _listensFn(Track track, _DateSpans spans, _SmartPlaylistResolveContext context, {required bool every}) {
    final listens = SmartPlaylistRuleBase.topTracksMapListens[track];
    if (listens == null) return _dateFn(null, spans, context);
    final trend = _listensTrend;
    // -- sorted, an oldest listen after 1970 means none of them is unknown (0)
    if (trend != null && listens.first > 0) {
      final decidingListen = switch (trend) {
        _DateTrend.rising => every ? listens.first : listens.last,
        _DateTrend.falling => every ? listens.last : listens.first,
      };
      return _dateFn(decidingListen, spans, context);
    }
    if (every) return listens.every((msse) => _dateFn(msse, spans, context));
    return listens.any((msse) => _dateFn(msse, spans, context));
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
    final spans = _spansOf(context);
    return switch (source) {
      SmartPlaylistRuleFilterDateTimeSource.dateAdded => _dateFn(track.dateAdded, spans, context),
      SmartPlaylistRuleFilterDateTimeSource.dateModified => _dateFn(track.dateModified, spans, context),
      SmartPlaylistRuleFilterDateTimeSource.year => _yearFn(track, spans, context),
      SmartPlaylistRuleFilterDateTimeSource.anyListen => _listensFn(track, spans, context, every: false),
      SmartPlaylistRuleFilterDateTimeSource.allListens => _listensFn(track, spans, context, every: true),
      SmartPlaylistRuleFilterDateTimeSource.firstListen => _dateFn(SmartPlaylistRuleBase.topTracksMapListens[track]?.firstOrNull, spans, context),
      SmartPlaylistRuleFilterDateTimeSource.lastListen => _dateFn(SmartPlaylistRuleBase.topTracksMapListens[track]?.lastOrNull, spans, context),
      SmartPlaylistRuleFilterDateTimeSource.favouriteDate => _dateFn(_getFavouriteDate(track), spans, context),
      SmartPlaylistRuleFilterDateTimeSource.rangeOnly => true,
    };
  }

  factory SmartPlaylistRuleDateTime.fromMap(Map map) {
    final isLegacyClockOnly = map['clockOnly'] == true;
    return SmartPlaylistRuleDateTime(
      data: SmartPlaylistDateValue.fromJson(map['data'], map['dataPrecision'], isLegacyClockOnly: isLegacyClockOnly),
      data2: SmartPlaylistDateValue.fromJson(map['data2'], map['data2Precision'], isLegacyClockOnly: isLegacyClockOnly),
      filter: SmartPlaylistRuleFilterDateTime.values.getEnum(map['filter'])!,
      source: SmartPlaylistRuleFilterDateTimeSource.values.getEnum(map['source'])!,
      enableCleanup: map['enableCleanup'] == true,
      parts: isLegacyClockOnly ? SmartPlaylistDateParts.timeOnly : SmartPlaylistDateParts.fromNames(map['parts']),
      relativeDuration: map['relativeDuration'] != null ? SmartPlaylistRelativeDuration.fromMap(map['relativeDuration']) : null,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    final data = this.data;
    final data2 = this.data2;
    return <String, dynamic>{
      'type': type.name,
      'filter': filter.name,
      'source': source.name,
      'data': ?data?.toJson(),
      if (data is SmartPlaylistDate) 'dataPrecision': data.precision.name,
      'data2': ?data2?.toJson(),
      if (data2 is SmartPlaylistDate) 'data2Precision': data2.precision.name,
      if (enableCleanup) 'enableCleanup': enableCleanup,
      if (parts != SmartPlaylistDateParts.dateAndClock) 'parts': parts.toNames(),
      'relativeDuration': ?relativeDuration?.toMap(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SmartPlaylistRuleDateTime) return false;
    return super == other && other.parts == parts;
  }

  @override
  int get hashCode => super.hashCode ^ parts.hashCode;
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
  seconds(SmartPlaylistDatePrecision.second),
  minutes(SmartPlaylistDatePrecision.minute),
  hours(SmartPlaylistDatePrecision.hour),
  days(SmartPlaylistDatePrecision.day),
  weeks(SmartPlaylistDatePrecision.week),
  months(SmartPlaylistDatePrecision.month),
  years(SmartPlaylistDatePrecision.year),
  ;

  /// how much a "now" full date covers when moved in this unit, now + 0 months is this month.
  final SmartPlaylistDatePrecision precision;

  const SmartPlaylistRelativeUnit(this.precision);

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
      SmartPlaylistRelativeUnit.months => _shiftedMonths(now, -amount),
      SmartPlaylistRelativeUnit.years => _shiftedMonths(now, -amount * DateTime.monthsPerYear),
    };
  }

  /// the day only, clamped to the target month's length.
  static DateTime _shiftedMonths(DateTime now, int months) {
    final targetMonthIndex = now.year * 12 + now.month - 1 + months;
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
  week,
  day,
  hour(hasClock: true),
  minute(hasClock: true),
  second(hasClock: true),
  ;

  final bool hasClock;

  const SmartPlaylistDatePrecision({this.hasClock = false});
}

enum SmartPlaylistDatePart {
  year(keyRadix: 1),
  month(keyRadix: 13),
  day(keyRadix: 32, isDaySlot: true),
  weekday(keyRadix: 8, isDaySlot: true),
  time(keyRadix: Duration.secondsPerDay),
  ;

  /// one above the highest value, so a key of the lower parts never spills into this one.
  final int keyRadix;

  /// day of the month and weekday both pick the day, only one of them is compared.
  final bool isDaySlot;

  const SmartPlaylistDatePart({required this.keyRadix, this.isDaySlot = false});

  int get _bit => 1 << index;

  String toText() => switch (this) {
    SmartPlaylistDatePart.year => lang.year,
    SmartPlaylistDatePart.month => lang.month,
    SmartPlaylistDatePart.day => lang.day,
    SmartPlaylistDatePart.weekday => lang.weekday,
    SmartPlaylistDatePart.time => lang.clock,
  };

  IconData toIcon() => switch (this) {
    SmartPlaylistDatePart.year => Broken.calendar,
    SmartPlaylistDatePart.month => Broken.calendar_1,
    SmartPlaylistDatePart.day => Broken.calendar_2,
    SmartPlaylistDatePart.weekday => Broken.calendar_tick,
    SmartPlaylistDatePart.time => Broken.clock,
  };
}

/// the date parts a rule compares, as bits of [SmartPlaylistDatePart].
///
/// by claude
extension type const SmartPlaylistDateParts._(int _mask) {
  static final date = SmartPlaylistDateParts.of(const [SmartPlaylistDatePart.year, SmartPlaylistDatePart.month, SmartPlaylistDatePart.day]);

  /// rules saved before parts existed compared the clock too.
  static final dateAndClock = SmartPlaylistDateParts.of(const [SmartPlaylistDatePart.year, SmartPlaylistDatePart.month, SmartPlaylistDatePart.day, SmartPlaylistDatePart.time]);
  static final timeOnly = SmartPlaylistDateParts.of(const [SmartPlaylistDatePart.time]);

  factory SmartPlaylistDateParts.of(Iterable<SmartPlaylistDatePart> parts) {
    var mask = 0;
    for (final part in parts) {
      mask |= part._bit;
    }
    return SmartPlaylistDateParts._(mask);
  }

  factory SmartPlaylistDateParts.fromNames(dynamic names) {
    if (names is! List) return dateAndClock;
    var mask = 0;
    for (final name in names) {
      final part = SmartPlaylistDatePart.values.getEnum(name);
      if (part != null) mask |= part._bit;
    }
    return mask == 0 ? dateAndClock : SmartPlaylistDateParts._(mask);
  }

  bool has(SmartPlaylistDatePart part) => (_mask & part._bit) != 0;

  /// a whole date, with or without the clock, compared as one point in time.
  bool get isCalendarDate => (_mask & date._mask) == date._mask && !has(SmartPlaylistDatePart.weekday);

  /// keeps at least one part, and turning a day slot part on turns the other one off.
  SmartPlaylistDateParts toggled(SmartPlaylistDatePart part) {
    if (has(part)) {
      final remaining = _mask & ~part._bit;
      return remaining == 0 ? this : SmartPlaylistDateParts._(remaining);
    }
    var mask = _mask | part._bit;
    if (part.isDaySlot) {
      for (final other in SmartPlaylistDatePart.values) {
        if (other != part && other.isDaySlot) mask &= ~other._bit;
      }
    }
    return SmartPlaylistDateParts._(mask);
  }

  List<String> toNames() => SmartPlaylistDatePart.values.where(has).map((e) => e.name).toFixedList();

  String toText() {
    if (this == date) return lang.date;
    if (this == dateAndClock) return '${lang.date}, ${lang.clock}';
    return SmartPlaylistDatePart.values.where(has).map((e) => e.toText()).join(', ');
  }

  IconData toIcon() {
    if (isCalendarDate) return Broken.calendar;
    final single = SmartPlaylistDatePart.values.where(has).singleOrNull;
    return single?.toIcon() ?? Broken.calendar_search;
  }
}

/// a value of a date rule, fixed or relative to now.
///
/// by claude
sealed class SmartPlaylistDateValue {
  const SmartPlaylistDateValue();

  Object toJson();

  static SmartPlaylistDateValue? fromJson(dynamic json, dynamic precisionName, {required bool isLegacyClockOnly}) => switch (json) {
    int msse when isLegacyClockOnly => SmartPlaylistDatePartsValue.ofLegacyClock(DateTime.fromMillisecondsSinceEpoch(msse)),
    int msse => SmartPlaylistDate._fromJson(msse, precisionName),
    Map map when map.containsKey(SmartPlaylistNowDate._kOffsetKey) => SmartPlaylistNowDate._fromJson(map),
    Map map => SmartPlaylistDatePartsValue._fromJson(map),
    _ => null,
  };
}

/// a full date and how much of time it covers, starting at [date].
final class SmartPlaylistDate extends SmartPlaylistDateValue {
  final DateTime date;
  final SmartPlaylistDatePrecision precision;

  const SmartPlaylistDate(this.date, this.precision);

  /// rules saved before precisions existed, midnight meant the whole day.
  factory SmartPlaylistDate.legacy(DateTime date) {
    final precision = _isMidnight(date) ? SmartPlaylistDatePrecision.day : SmartPlaylistDatePrecision.second;
    return SmartPlaylistDate(date, precision);
  }

  factory SmartPlaylistDate._fromJson(int msse, dynamic precisionName) {
    final date = DateTime.fromMillisecondsSinceEpoch(msse);
    final precision = SmartPlaylistDatePrecision.values.getEnum(precisionName);
    if (precision == null) return SmartPlaylistDate.legacy(date);
    return SmartPlaylistDate(date, precision);
  }

  static bool _isMidnight(DateTime date) => date.hour == 0 && date.minute == 0 && date.second == 0 && date.millisecond == 0 && date.microsecond == 0;

  @override
  int toJson() => date.millisecondsSinceEpoch;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SmartPlaylistDate) return false;

    return other.date == date && other.precision == precision;
  }

  @override
  int get hashCode => date.hashCode ^ precision.hashCode;
}

/// fixed values of the compared parts, ex: day 10 of any month in 2019.
final class SmartPlaylistDatePartsValue extends SmartPlaylistDateValue {
  final int? year;
  final int? month;
  final int? day;
  final int? weekday;
  final int? secondOfDay;

  /// without seconds the clock covers the whole minute.
  final bool hasSeconds;

  const SmartPlaylistDatePartsValue({
    this.year,
    this.month,
    this.day,
    this.weekday,
    this.secondOfDay,
    this.hasSeconds = false,
  });

  /// rules saved with "clock only", zero seconds meant the whole minute.
  factory SmartPlaylistDatePartsValue.ofLegacyClock(DateTime date) => SmartPlaylistDatePartsValue(
    secondOfDay: secondOfDayOf(date),
    hasSeconds: date.second != 0,
  );

  /// the parts [value] gives, a full date gives as many as its precision covers.
  factory SmartPlaylistDatePartsValue.knownIn(SmartPlaylistDateValue? value) => switch (value) {
    SmartPlaylistDatePartsValue partsValue => partsValue,
    SmartPlaylistDate date => SmartPlaylistDatePartsValue._ofDate(date),
    SmartPlaylistNowDate() || null => const SmartPlaylistDatePartsValue(),
  };

  factory SmartPlaylistDatePartsValue._ofDate(SmartPlaylistDate value) {
    final date = value.date;
    final precision = value.precision;
    final hasMonth = precision != SmartPlaylistDatePrecision.year;
    final hasDay = hasMonth && precision != SmartPlaylistDatePrecision.month;
    return SmartPlaylistDatePartsValue(
      year: date.year,
      month: hasMonth ? date.month : null,
      day: hasDay ? date.day : null,
      weekday: hasDay ? date.weekday : null,
      secondOfDay: precision.hasClock ? secondOfDayOf(date) : null,
      hasSeconds: precision == SmartPlaylistDatePrecision.second,
    );
  }

  factory SmartPlaylistDatePartsValue._fromJson(Map map) => SmartPlaylistDatePartsValue(
    year: map['year'] as int?,
    month: map['month'] as int?,
    day: map['day'] as int?,
    weekday: map['weekday'] as int?,
    secondOfDay: map['secondOfDay'] as int?,
    hasSeconds: map['hasSeconds'] == true,
  );

  bool hasAll(SmartPlaylistDateParts parts) =>
      (year != null || !parts.has(SmartPlaylistDatePart.year)) &&
      (month != null || !parts.has(SmartPlaylistDatePart.month)) &&
      (day != null || !parts.has(SmartPlaylistDatePart.day)) &&
      (weekday != null || !parts.has(SmartPlaylistDatePart.weekday)) &&
      (secondOfDay != null || !parts.has(SmartPlaylistDatePart.time));

  SmartPlaylistDatePartsValue onlyParts(SmartPlaylistDateParts parts) {
    final hasTime = parts.has(SmartPlaylistDatePart.time);
    return SmartPlaylistDatePartsValue(
      year: parts.has(SmartPlaylistDatePart.year) ? year : null,
      month: parts.has(SmartPlaylistDatePart.month) ? month : null,
      day: parts.has(SmartPlaylistDatePart.day) ? day : null,
      weekday: parts.has(SmartPlaylistDatePart.weekday) ? weekday : null,
      secondOfDay: hasTime ? secondOfDay : null,
      hasSeconds: hasTime && hasSeconds,
    );
  }

  /// [shown] replaces the values of [parts], and fills the other parts it knows.
  SmartPlaylistDatePartsValue mergedWith(SmartPlaylistDatePartsValue shown, SmartPlaylistDateParts parts) {
    int? valueOf(SmartPlaylistDatePart part, int? shownValue, int? knownValue) => parts.has(part) ? shownValue : shownValue ?? knownValue;
    final takesShownClock = parts.has(SmartPlaylistDatePart.time) || shown.secondOfDay != null;
    return SmartPlaylistDatePartsValue(
      year: valueOf(SmartPlaylistDatePart.year, shown.year, year),
      month: valueOf(SmartPlaylistDatePart.month, shown.month, month),
      day: valueOf(SmartPlaylistDatePart.day, shown.day, day),
      weekday: valueOf(SmartPlaylistDatePart.weekday, shown.weekday, weekday),
      secondOfDay: takesShownClock ? shown.secondOfDay : secondOfDay,
      hasSeconds: takesShownClock ? shown.hasSeconds : hasSeconds,
    );
  }

  /// the full date these give, as precise as the known parts go.
  SmartPlaylistDate? toDate({required bool withClock}) {
    final year = this.year;
    final month = this.month;
    final day = this.day;
    final secondOfDay = this.secondOfDay;
    if (year == null) return null;
    if (month == null || month < 1 || month > 12) return SmartPlaylistDate(DateTime(year), SmartPlaylistDatePrecision.year);
    if (day == null || day < 1 || day > DateUtils.getDaysInMonth(year, month)) return SmartPlaylistDate(DateTime(year, month), SmartPlaylistDatePrecision.month);
    if (!withClock || secondOfDay == null) return SmartPlaylistDate(DateTime(year, month, day), SmartPlaylistDatePrecision.day);
    final hour = secondOfDay ~/ Duration.secondsPerHour;
    final minute = secondOfDay % Duration.secondsPerHour ~/ Duration.secondsPerMinute;
    final second = secondOfDay % Duration.secondsPerMinute;
    final precision = hasSeconds ? SmartPlaylistDatePrecision.second : SmartPlaylistDatePrecision.minute;
    return SmartPlaylistDate(DateTime(year, month, day, hour, minute, second), precision);
  }

  static int secondOfDayOf(DateTime date) => date.hour * Duration.secondsPerHour + date.minute * Duration.secondsPerMinute + date.second;

  static final _clockTextRegex = RegExp(r'^(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?$');

  static ({int secondOfDay, bool hasSeconds})? tryParseClock(String text) {
    final match = _clockTextRegex.firstMatch(text.trim());
    if (match == null) return null;
    final secondText = match[3];
    final hour = int.parse(match[1]!);
    final minute = int.parse(match[2]!);
    final second = secondText == null ? 0 : int.parse(secondText);
    if (hour > 23 || minute > 59 || second > 59) return null;
    final secondOfDay = hour * Duration.secondsPerHour + minute * Duration.secondsPerMinute + second;
    return (secondOfDay: secondOfDay, hasSeconds: secondText != null);
  }

  static String clockToText(int secondOfDay, {required bool hasSeconds}) {
    final hours = secondOfDay ~/ Duration.secondsPerHour;
    final minutes = secondOfDay % Duration.secondsPerHour ~/ Duration.secondsPerMinute;
    final hoursAndMinutes = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
    if (!hasSeconds) return hoursAndMinutes;
    final seconds = secondOfDay % Duration.secondsPerMinute;
    return '$hoursAndMinutes:${seconds.toString().padLeft(2, '0')}';
  }

  static String monthToText(int month) => DateFormat.MMMM().format(DateTime(2000, month));

  /// 2024 started on a monday, so its first week gives every weekday.
  static String weekdayToText(int weekday, {bool short = false}) {
    final format = short ? DateFormat.E() : DateFormat.EEEE();
    return format.format(DateTime(2024, 1, weekday));
  }

  @override
  Map<String, Object> toJson() => {
    'year': ?year,
    'month': ?month,
    'day': ?day,
    'weekday': ?weekday,
    'secondOfDay': ?secondOfDay,
    if (hasSeconds) 'hasSeconds': true,
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SmartPlaylistDatePartsValue) return false;

    return other.year == year && //
        other.month == month &&
        other.day == day &&
        other.weekday == weekday &&
        other.secondOfDay == secondOfDay &&
        other.hasSeconds == hasSeconds;
  }

  @override
  int get hashCode =>
      year.hashCode ^ //
      month.hashCode ^
      day.hashCode ^
      weekday.hashCode ^
      secondOfDay.hashCode ^
      hasSeconds.hashCode;
}

/// now moved by an offset, worked out each time the playlist is built.
final class SmartPlaylistNowDate extends SmartPlaylistDateValue {
  final int offsetAmount;
  final SmartPlaylistRelativeUnit offsetUnit;

  const SmartPlaylistNowDate({
    required this.offsetAmount,
    required this.offsetUnit,
  });

  static const _kOffsetKey = 'nowOffset';

  factory SmartPlaylistNowDate._fromJson(Map map) => SmartPlaylistNowDate(
    offsetAmount: map[_kOffsetKey] as int? ?? 0,
    offsetUnit: SmartPlaylistRelativeUnit.values.getEnum(map['unit']) ?? SmartPlaylistRelativeUnit.days,
  );

  DateTime shiftedFrom(DateTime now) {
    final amount = offsetAmount;
    return switch (offsetUnit) {
      SmartPlaylistRelativeUnit.seconds => now.add(Duration(seconds: amount)),
      SmartPlaylistRelativeUnit.minutes => now.add(Duration(minutes: amount)),
      SmartPlaylistRelativeUnit.hours => now.add(Duration(hours: amount)),
      SmartPlaylistRelativeUnit.days => DateTime(now.year, now.month, now.day + amount, now.hour, now.minute, now.second),
      SmartPlaylistRelativeUnit.weeks => DateTime(now.year, now.month, now.day + amount * DateTime.daysPerWeek, now.hour, now.minute, now.second),
      SmartPlaylistRelativeUnit.months => _shiftedMonthsKeepingClock(now, amount),
      SmartPlaylistRelativeUnit.years => _shiftedMonthsKeepingClock(now, amount * DateTime.monthsPerYear),
    };
  }

  static DateTime _shiftedMonthsKeepingClock(DateTime now, int months) {
    final day = SmartPlaylistRelativeDuration._shiftedMonths(now, months);
    return DateTime(day.year, day.month, day.day, now.hour, now.minute, now.second);
  }

  @override
  Map<String, Object> toJson() => {
    _kOffsetKey: offsetAmount,
    'unit': offsetUnit.name,
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SmartPlaylistNowDate) return false;

    return other.offsetAmount == offsetAmount && other.offsetUnit == offsetUnit;
  }

  @override
  int get hashCode => offsetAmount.hashCode ^ offsetUnit.hashCode;
}

/// the values of a rule as keys, worked out once for fixed values and once per resolve for values relative to now.
///
/// by claude
class _DateSpans {
  final int? start;
  final int? end;
  final int? rangeStart;
  final int? rangeEnd;
  final bool wrapsAround;

  const _DateSpans._({
    required this.start,
    required this.end,
    required this.rangeStart,
    required this.rangeEnd,
    required this.wrapsAround,
  });

  /// both values are included whole, so `2019` to `2019-06` still covers all of 2019.
  /// without the year the written order matters, 23:00 to 02:00 crosses midnight.
  factory _DateSpans(_KeySpan? span, _KeySpan? span2, {required bool isCyclic}) {
    final start = span?.start;
    final end = span?.end;
    final start2 = span2?.start;
    final end2 = span2?.end;
    if (start == null || end == null || start2 == null || end2 == null) {
      return _DateSpans._(start: start, end: end, rangeStart: start, rangeEnd: end2, wrapsAround: false);
    }
    if (isCyclic && start2 < start) {
      return _DateSpans._(start: start, end: end, rangeStart: start, rangeEnd: end2, wrapsAround: true);
    }
    return _DateSpans._(start: start, end: end, rangeStart: start.withMaximum(start2), rangeEnd: end.withMinimum(end2), wrapsAround: false);
  }

  bool isWithin(int valueStart, int valueEnd) {
    final start = this.start;
    final end = this.end;
    return start != null && end != null && valueStart >= start && valueEnd <= end;
  }

  bool isOutside(int valueStart, int valueEnd) {
    final start = this.start;
    final end = this.end;
    return start != null && end != null && (valueEnd <= start || valueStart >= end);
  }
}

enum _DateTrend {
  rising,
  falling,
}

/// [end] is exclusive.
typedef _KeySpan = ({int start, int end});
