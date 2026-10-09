part of '../smart_playlists_controller.dart';

final class SmartPlaylistRuleDateTime extends SmartPlaylistRuleBase<DateTime, DateTime, SmartPlaylistRuleFilterDateTime, SmartPlaylistRuleFilterDateTimeSource> {
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
    (DateTime? data, DateTime? data2)? datas,
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
      if (clockOnly) {
        final parts = value.split(':');
        if (parts.length != 3 || parts.any((p) => int.tryParse(p) == null)) return lang.nameContainsBadCharacter;
        return null;
      }
      try {
        DateTime.parse(value);
      } catch (e) {
        return e.toString();
      }
    }

    return null;
  }

  @override
  String? validate() {
    final data = this.data;
    final data2 = this.data2;
    if (filter.isRelativeDate && (relativeDuration == null || relativeDuration!.amount <= 0)) return lang.emptyValue;

    if (filter.requiresDataField && data == null) return lang.emptyValue;
    if (!filter.requiresDataField && data != null) return lang.nameContainsBadCharacter;
    if (filter.requiresData2Field && data2 == null) return lang.emptyValue;
    if (!filter.requiresData2Field && data2 != null) return lang.nameContainsBadCharacter;
    return null;
  }

  @override
  String datasDisplayText() {
    late final dataFormatted = clockOnly ? data?.clockFormatted : data?.dateAndClockFormattedOriginal;
    late final data2Formatted = clockOnly ? data2?.clockFormatted : data2?.dateAndClockFormattedOriginal;
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

  @override
  DateTime? textToData(String? value) {
    if (value == null || value.isEmpty) return null;
    if (clockOnly) {
      final parts = value.split(':');
      if (parts.length != 3) return null;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final s = int.tryParse(parts[2]);
      if (h == null || m == null || s == null) return null;
      return DateTime(0, 1, 1, h, m, s);
    }
    return DateTime.tryParse(value);
  }

  @override
  DateTime? textToData2(String? value) => textToData(value);

  @override
  String? dataToText(DateTime? data) {
    if (data == null) return null;
    final dateFormat = clockOnly
        ? DateFormat('HH:mm:ss')
        : data.hour == 0 && data.minute == 0 && data.second == 0
        ? DateFormat('yyyy-MM-dd')
        : DateFormat('yyyy-MM-dd HH:mm:ss');
    return dateFormat.format(data);
  }

  @override
  String? data2ToText(DateTime? data2) => data2 == null ? null : dataToText(data2);

  @override
  String? toHintText() => clockOnly ? 'HH:mm:ss' : 'YYYY-MM-DD HH:mm:ss';

  bool _matchesTimestamp(int? msse, _SmartPlaylistResolveContext context) => _dateFn(msse, context);

  late final _comparesClockOnly = clockOnly && !filter.isRelativeDate;

  /// seconds of the local day for clock only comparisons, microseconds since epoch otherwise, ints since each local date costs a timezone lookup.
  int? _valueOf(DateTime? date) {
    if (date == null) return null;
    if (_comparesClockOnly) return _secondsOfDay(date);
    return date.microsecondsSinceEpoch;
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

  late final (int?, int?) _sortedValues = _dataValue == null || _data2Value == null
      ? (_dataValue, _data2Value)
      : _dataValue < _data2Value
      ? (_dataValue, _data2Value)
      : (_data2Value, _dataValue);

  late final _startValue = _sortedValues.$1;
  late final _endValue = _sortedValues.$2;

  late final _crossesMidnight = _comparesClockOnly && _dataValue != null && _data2Value != null && _data2Value < _dataValue;

  /// in dates world, one usually means an inclusive date.
  /// ex: in between 2015-2016, so both exact dates should be included as well.
  /// usually useful for types like: `isBefore`, `isAfter`, `isInBetween`.
  /// but not for types like: `isOutside`.
  late final bool Function(int? value, _SmartPlaylistResolveContext context) _valueFnRaw = switch (filter) {
    SmartPlaylistRuleFilterDateTime.isSame => (value, _) => value != null && value == _dataValue,
    SmartPlaylistRuleFilterDateTime.isNotSame => (value, _) => value != null && _dataValue != null && value != _dataValue,
    SmartPlaylistRuleFilterDateTime.isBefore => (value, _) => value != null && _dataValue != null && value <= _dataValue,
    SmartPlaylistRuleFilterDateTime.isAfter => (value, _) => value != null && _dataValue != null && value >= _dataValue,
    SmartPlaylistRuleFilterDateTime.isInBetween => (value, context) {
      if (value == null) return false;
      if (_crossesMidnight) return value >= _dataValue! || value <= _data2Value!;
      return _startValue != null && value >= _startValue && value <= _endValueOf(context);
    },
    SmartPlaylistRuleFilterDateTime.isOutside => (value, context) {
      if (value == null) return false;
      if (_crossesMidnight) return value < _dataValue! && value > _data2Value!;
      return (_startValue != null && value < _startValue) || value > _endValueOf(context);
    },
    SmartPlaylistRuleFilterDateTime.isWithinLast => (value, context) {
      if (value == null) return false; // -- never listened, definetly not here
      final boundary = _relativeBoundaryOf(context);
      return boundary != null && value > boundary;
    },
    SmartPlaylistRuleFilterDateTime.isNotWithinLast => (value, context) {
      if (value == null) return true; // -- never listened, ofc not within any range
      final boundary = _relativeBoundaryOf(context);
      return boundary != null && value < boundary;
    },
    SmartPlaylistRuleFilterDateTime.exists => (value, _) => value != null,
    SmartPlaylistRuleFilterDateTime.missing => (value, _) => value == null,
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

  static final _unknownDate = DateTime(0);
  late final _unknownDateValue = _valueOf(_unknownDate);

  bool _yearFn(Track track, _SmartPlaylistResolveContext context) {
    final yearDate = context.yearDateOf(track);
    final value = _valueOf(yearDate);
    final knownValue = value == _unknownDateValue ? null : value;
    return _valueFnRaw(knownValue, context);
  }

  bool _dateFn(int? trackDateMSSE, _SmartPlaylistResolveContext context) {
    if (trackDateMSSE == null || trackDateMSSE == 0) return _valueFnRaw(null, context);
    final value = _valueOfTimestamp(trackDateMSSE);
    return _valueFnRaw(value, context);
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
    final dataJson = map['data'] as int?;
    final data2Json = map['data2'] as int?;
    return SmartPlaylistRuleDateTime(
      data: dataJson == null ? null : DateTime.fromMillisecondsSinceEpoch(dataJson),
      data2: data2Json == null ? null : DateTime.fromMillisecondsSinceEpoch(data2Json),
      filter: SmartPlaylistRuleFilterDateTime.values.getEnum(map['filter'])!,
      source: SmartPlaylistRuleFilterDateTimeSource.values.getEnum(map['source'])!,
      enableCleanup: map['enableCleanup'] == true,
      clockOnly: map['clockOnly'] == true,
      relativeDuration: map['relativeDuration'] != null ? SmartPlaylistRelativeDuration.fromMap(map['relativeDuration']) : null,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'type': type.name,
      'filter': filter.name,
      'source': source.name,
      'data': ?data?.millisecondsSinceEpoch,
      'data2': ?data2?.millisecondsSinceEpoch,
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

enum _DateTrend {
  rising,
  falling,
}
