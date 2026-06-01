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

    if (filter.requiresDataField && (data == null || data.isAtSameMomentAs(DateTime(0)))) return lang.emptyValue;
    if (!filter.requiresDataField && (data != null && !data.isAtSameMomentAs(DateTime(0)))) return lang.nameContainsBadCharacter;
    if (filter.requiresData2Field && (data2 == null || data2.isAtSameMomentAs(DateTime(0)))) return lang.emptyValue;
    if (!filter.requiresData2Field && (data2 != null && !data2.isAtSameMomentAs(DateTime(0)))) return lang.nameContainsBadCharacter;
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

  bool matchesTimestamp(int? msse) => _dateFn(msse);

  static DateTime _timeOnly(DateTime dt) => DateTime(0, 1, 1, dt.hour, dt.minute, dt.second);
  DateTime? _normalize(DateTime? dt) => dt == null ? null : (clockOnly ? _timeOnly(dt) : dt);

  late final _normalizedData = _normalize(data);
  late final _normalizedData2 = _normalize(data2);

  late final (DateTime?, DateTime?) _sortedDates = _normalizedData == null || _normalizedData2 == null
      ? (_normalizedData, _normalizedData2)
      : _normalizedData.isBefore(_normalizedData2)
      ? (_normalizedData, _normalizedData2)
      : (_normalizedData2, _normalizedData);

  late final _startDate = _sortedDates.$1;
  late final _endDate = _sortedDates.$2;

  late final _crossesMidnight = clockOnly && _normalizedData != null && _normalizedData2 != null && _normalizedData2.isBefore(_normalizedData);

  late final bool Function(DateTime? trackDate) _dateFnRaw = switch (filter) {
    SmartPlaylistRuleFilterDateTime.isSame => (trackDate) => _normalizedData != null && trackDate?.isAtSameMomentAs(_normalizedData) == true,
    SmartPlaylistRuleFilterDateTime.isNotSame => (trackDate) => _normalizedData != null && trackDate?.isAtSameMomentAs(_normalizedData) == false,
    SmartPlaylistRuleFilterDateTime.isBefore => (trackDate) => _normalizedData != null && trackDate?.isBefore(_normalizedData) == true,
    SmartPlaylistRuleFilterDateTime.isAfter => (trackDate) => _normalizedData != null && trackDate?.isAfter(_normalizedData) == true,
    SmartPlaylistRuleFilterDateTime.isInBetween => (trackDate) {
      if (trackDate == null) return false;
      if (_crossesMidnight) {
        return trackDate.isAfter(_normalizedData!) || trackDate.isBefore(_normalizedData2!);
      }
      return (_startDate != null && trackDate.isAfter(_startDate)) && trackDate.isBefore(_endDate ?? DateTime.now());
    },
    SmartPlaylistRuleFilterDateTime.isOutside => (trackDate) {
      if (trackDate == null) return false;
      if (_crossesMidnight) {
        return trackDate.isBefore(_normalizedData!) && trackDate.isAfter(_normalizedData2!);
      }
      return (_startDate != null && trackDate.isBefore(_startDate)) || trackDate.isAfter(_endDate ?? DateTime.now());
    },
    SmartPlaylistRuleFilterDateTime.isWithinLast => (trackDate) {
      if (trackDate == null) return false; // -- never listened, definetly not here
      final boundary = relativeDuration?.getBoundary();
      return boundary != null && trackDate.isAfter(boundary) == true;
    },
    SmartPlaylistRuleFilterDateTime.isNotWithinLast => (trackDate) {
      if (trackDate == null) return true; // -- never listened, ofc not within any range
      final boundary = relativeDuration?.getBoundary();
      return boundary != null && trackDate.isBefore(boundary) == true;
    },
    SmartPlaylistRuleFilterDateTime.exists => (trackDate) => trackDate != null,
    SmartPlaylistRuleFilterDateTime.missing => (trackDate) => trackDate == null,
  };

  bool _dateFnDateTime(DateTime? trackDate) {
    final normalized = _normalize(trackDate);
    return normalized == null || normalized.isAtSameMomentAs(DateTime(0)) ? _dateFnRaw(null) : _dateFnRaw(normalized);
  }

  bool _dateFn(int? trackDateMSSE) {
    if (trackDateMSSE == null || trackDateMSSE == 0) return _dateFnRaw(null);
    return _dateFnRaw(_normalize(DateTime.fromMillisecondsSinceEpoch(trackDateMSSE)));
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
  bool isMatch(Track track) {
    return switch (source) {
      SmartPlaylistRuleFilterDateTimeSource.dateAdded => _dateFn(track.dateAdded),
      SmartPlaylistRuleFilterDateTimeSource.dateModified => _dateFn(track.dateModified),
      SmartPlaylistRuleFilterDateTimeSource.year => _dateFnDateTime(track.yearAsDateTime()),
      SmartPlaylistRuleFilterDateTimeSource.anyListen => SmartPlaylistRuleBase.topTracksMapListens[track]?.any((listenMSSE) => _dateFn(listenMSSE)) ?? _dateFn(null),
      SmartPlaylistRuleFilterDateTimeSource.allListens => SmartPlaylistRuleBase.topTracksMapListens[track]?.every((listenMSSE) => _dateFn(listenMSSE)) ?? _dateFn(null),
      SmartPlaylistRuleFilterDateTimeSource.firstListen => _dateFn(SmartPlaylistRuleBase.topTracksMapListens[track]?.firstOrNull),
      SmartPlaylistRuleFilterDateTimeSource.lastListen => _dateFn(SmartPlaylistRuleBase.topTracksMapListens[track]?.lastOrNull),
      SmartPlaylistRuleFilterDateTimeSource.favouriteDate => _dateFn(_getFavouriteDate(track)),
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
  years
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

  DateTime getBoundary() {
    final now = DateTime.now();
    return switch (unit) {
      SmartPlaylistRelativeUnit.seconds => now.subtract(Duration(seconds: amount)),
      SmartPlaylistRelativeUnit.minutes => now.subtract(Duration(minutes: amount)),
      SmartPlaylistRelativeUnit.hours => now.subtract(Duration(hours: amount)),
      SmartPlaylistRelativeUnit.days => now.subtract(Duration(days: amount)),
      SmartPlaylistRelativeUnit.weeks => now.subtract(Duration(days: amount * 7)),
      SmartPlaylistRelativeUnit.months => DateTime(now.year, now.month - amount, now.day),
      SmartPlaylistRelativeUnit.years => DateTime(now.year - amount, now.month, now.day),
    };
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
