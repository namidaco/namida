// by claude
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/lang.dart';
import 'package:namida/class/sort_chain.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/smart_playlists/smart_playlists_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/language.dart';

void main() {
  late Directory dir;
  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('namida_smart_playlists_date_time_test');
    AppDirs.USER_DATA = '${dir.path}${Platform.pathSeparator}';
    Language.inst.update(language: NamidaLanguage.fromCode('en'));
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  Track trackAt(String name, DateTime date) {
    final path = '/music/$name.m4a';
    final track = Track.explicit(path);
    Indexer.inst.allTracksMappedByPath[path] = kDummyExtendedTrack.copyWith(
      path: path,
      title: name,
      dateAdded: date.millisecondsSinceEpoch,
      generatePathHash: false,
    );
    return track;
  }

  const fullDateParts = [SmartPlaylistDatePart.year, SmartPlaylistDatePart.month, SmartPlaylistDatePart.day, SmartPlaylistDatePart.time];

  SmartPlaylistDateValue legacyDateValueOf(DateTime date, {required bool clockOnly}) {
    if (clockOnly) return SmartPlaylistDatePartsValue.ofLegacyClock(date);
    return SmartPlaylistDate.legacy(date);
  }

  SmartPlaylistRuleDateTime partsRuleOf(
    SmartPlaylistRuleFilterDateTime filter,
    List<SmartPlaylistDatePart> parts,
    SmartPlaylistDateValue? data, {
    SmartPlaylistDateValue? data2,
    SmartPlaylistRuleFilterDateTimeSource source = SmartPlaylistRuleFilterDateTimeSource.dateAdded,
  }) => SmartPlaylistRuleDateTime(
    data: data,
    data2: data2,
    filter: filter,
    source: source,
    enableCleanup: false,
    parts: SmartPlaylistDateParts.of(parts),
    relativeDuration: null,
  );

  SmartPlaylistDatePartsValue clockValue(String text) {
    final clock = SmartPlaylistDatePartsValue.tryParseClock(text)!;
    return SmartPlaylistDatePartsValue(secondOfDay: clock.secondOfDay, hasSeconds: clock.hasSeconds);
  }

  SmartPlaylistRuleDateTime ruleOf(
    SmartPlaylistRuleFilterDateTime filter,
    DateTime? data, {
    DateTime? data2,
    SmartPlaylistRuleFilterDateTimeSource source = SmartPlaylistRuleFilterDateTimeSource.dateAdded,
    bool clockOnly = false,
  }) => partsRuleOf(
    filter,
    clockOnly ? const [.time] : fullDateParts,
    data == null ? null : legacyDateValueOf(data, clockOnly: clockOnly),
    data2: data2 == null ? null : legacyDateValueOf(data2, clockOnly: clockOnly),
    source: source,
  );

  SmartPlaylistRuleDateTime typedRuleOf(
    SmartPlaylistRuleFilterDateTime filter,
    String text, {
    String? text2,
    SmartPlaylistRuleFilterDateTimeSource source = SmartPlaylistRuleFilterDateTimeSource.dateAdded,
  }) {
    final rule = ruleOf(filter, null, source: source);
    final data = rule.textToData(text);
    final data2 = rule.textToData2(text2);
    expect(data, isNotNull, reason: text);
    return rule.copyWith(datas: (data, data2));
  }

  Track trackWithYear(String name, int year) {
    final path = '/music/$name.m4a';
    final track = Track.explicit(path);
    Indexer.inst.allTracksMappedByPath[path] = kDummyExtendedTrack.copyWith(
      path: path,
      title: name,
      year: year,
      generatePathHash: false,
    );
    return track;
  }

  Set<String> matchedNames(SmartPlaylistRuleDateTime rule, List<Track> tracks) {
    final playlist = SmartPlaylist(
      name: 'test',
      creationDate: DateTime(2026),
      joiner: SmartJoiner.and,
      sorting: const SortChain([]),
      moods: const [],
      ruleGroups: [
        SmartPlaylistRuleGroup.create(rules: [rule]),
      ],
      limit: null,
    );
    return playlist.resolveIterableUnSorted(tracks).map((e) => e.title).toSet();
  }

  group('whole day values', () {
    final day = DateTime(2026, 10, 22);
    final nextDay = DateTime(2026, 10, 23);
    late final tracks = [
      trackAt('dayBeforeLastSecond', DateTime(2026, 10, 21, 23, 59, 59)),
      trackAt('dayMidnight', DateTime(2026, 10, 22)),
      trackAt('dayNoon', DateTime(2026, 10, 22, 12)),
      trackAt('dayLastMS', DateTime(2026, 10, 22, 23, 59, 59, 999)),
      trackAt('nextDayMidnight', DateTime(2026, 10, 23)),
      trackAt('nextDayEvening', DateTime(2026, 10, 23, 20)),
      trackAt('twoDaysAfter', DateTime(2026, 10, 24, 10)),
    ];

    test('isSame covers the whole day', () {
      expect(matchedNames(ruleOf(SmartPlaylistRuleFilterDateTime.isSame, day), tracks), {'dayMidnight', 'dayNoon', 'dayLastMS'});
    });

    test('isNotSame is the opposite of isSame', () {
      expect(matchedNames(ruleOf(SmartPlaylistRuleFilterDateTime.isNotSame, day), tracks), {'dayBeforeLastSecond', 'nextDayMidnight', 'nextDayEvening', 'twoDaysAfter'});
    });

    test('isBefore includes the day itself', () {
      expect(matchedNames(ruleOf(SmartPlaylistRuleFilterDateTime.isBefore, day), tracks), {'dayBeforeLastSecond', 'dayMidnight', 'dayNoon', 'dayLastMS'});
    });

    test('isAfter starts at the day start', () {
      expect(
        matchedNames(ruleOf(SmartPlaylistRuleFilterDateTime.isAfter, day), tracks),
        {'dayMidnight', 'dayNoon', 'dayLastMS', 'nextDayMidnight', 'nextDayEvening', 'twoDaysAfter'},
      );
    });

    test('isInBetween includes both whole days, in any order', () {
      const expected = {'dayMidnight', 'dayNoon', 'dayLastMS', 'nextDayMidnight', 'nextDayEvening'};
      expect(matchedNames(ruleOf(SmartPlaylistRuleFilterDateTime.isInBetween, day, data2: nextDay), tracks), expected);
      expect(matchedNames(ruleOf(SmartPlaylistRuleFilterDateTime.isInBetween, nextDay, data2: day), tracks), expected);
    });

    test('isInBetween the same day equals isSame', () {
      expect(matchedNames(ruleOf(SmartPlaylistRuleFilterDateTime.isInBetween, day, data2: day), tracks), {'dayMidnight', 'dayNoon', 'dayLastMS'});
    });

    test('isOutside is the opposite of isInBetween', () {
      expect(matchedNames(ruleOf(SmartPlaylistRuleFilterDateTime.isOutside, day, data2: nextDay), tracks), {'dayBeforeLastSecond', 'twoDaysAfter'});
    });

    test('rule text shows the date only', () {
      final rule = ruleOf(SmartPlaylistRuleFilterDateTime.isSame, day);
      expect(rule.datasDisplayText(), '= ${day.dateFormattedOriginal}');
      expect(rule.dataToText(rule.data), '2026-10-22');
    });
  });

  group('values with a clock', () {
    final noon = DateTime(2026, 10, 22, 12);
    late final tracks = [
      trackAt('beforeNoon', DateTime(2026, 10, 22, 11, 59, 59)),
      trackAt('noon', DateTime(2026, 10, 22, 12)),
      trackAt('noonHalfSecond', DateTime(2026, 10, 22, 12, 0, 0, 500)),
      trackAt('noonOneSecond', DateTime(2026, 10, 22, 12, 0, 1)),
      trackAt('evening', DateTime(2026, 10, 22, 20)),
    ];

    test('isSame covers that second only', () {
      expect(matchedNames(ruleOf(SmartPlaylistRuleFilterDateTime.isSame, noon), tracks), {'noon', 'noonHalfSecond'});
    });

    test('isBefore includes that second', () {
      expect(matchedNames(ruleOf(SmartPlaylistRuleFilterDateTime.isBefore, noon), tracks), {'beforeNoon', 'noon', 'noonHalfSecond'});
    });

    test('isAfter starts at that second', () {
      expect(matchedNames(ruleOf(SmartPlaylistRuleFilterDateTime.isAfter, noon), tracks), {'noon', 'noonHalfSecond', 'noonOneSecond', 'evening'});
    });

    test('rule text keeps the clock', () {
      final rule = ruleOf(SmartPlaylistRuleFilterDateTime.isSame, noon);
      expect(rule.datasDisplayText(), '= ${noon.dateAndClockFormattedOriginal}');
      expect(rule.dataToText(rule.data), '2026-10-22 12:00:00');
    });
  });

  group('clock only', () {
    DateTime clock(int h, int m, [int s = 0]) => DateTime(0, 1, 1, h, m, s);
    late final tracks = [
      trackAt('c_142959', DateTime(2026, 3, 1, 14, 29, 59)),
      trackAt('c_143000', DateTime(2026, 3, 2, 14, 30)),
      trackAt('c_143030', DateTime(2026, 3, 3, 14, 30, 30)),
      trackAt('c_143059', DateTime(2026, 3, 4, 14, 30, 59)),
      trackAt('c_143100', DateTime(2026, 3, 5, 14, 31)),
      trackAt('c_233000', DateTime(2026, 3, 6, 23, 30)),
      trackAt('c_010000', DateTime(2026, 3, 7, 1)),
      trackAt('c_020030', DateTime(2026, 3, 8, 2, 0, 30)),
      trackAt('c_020100', DateTime(2026, 3, 9, 2, 1)),
    ];

    test('isSame with zero seconds covers the whole minute', () {
      expect(matchedNames(ruleOf(SmartPlaylistRuleFilterDateTime.isSame, clock(14, 30), clockOnly: true), tracks), {'c_143000', 'c_143030', 'c_143059'});
    });

    test('isSame with seconds covers that second only', () {
      expect(matchedNames(ruleOf(SmartPlaylistRuleFilterDateTime.isSame, clock(14, 30, 30), clockOnly: true), tracks), {'c_143030'});
    });

    test('isBefore includes the minute', () {
      expect(
        matchedNames(ruleOf(SmartPlaylistRuleFilterDateTime.isBefore, clock(14, 30), clockOnly: true), tracks),
        {'c_142959', 'c_143000', 'c_143030', 'c_143059', 'c_010000', 'c_020030', 'c_020100'},
      );
    });

    test('isInBetween crossing midnight includes the end minute', () {
      final rule = ruleOf(SmartPlaylistRuleFilterDateTime.isInBetween, clock(23, 0), data2: clock(2, 0), clockOnly: true);
      expect(matchedNames(rule, tracks), {'c_233000', 'c_010000', 'c_020030'});
    });

    test('isOutside crossing midnight is the opposite', () {
      final rule = ruleOf(SmartPlaylistRuleFilterDateTime.isOutside, clock(23, 0), data2: clock(2, 0), clockOnly: true);
      expect(matchedNames(rule, tracks), {'c_142959', 'c_143000', 'c_143030', 'c_143059', 'c_143100', 'c_020100'});
    });
  });

  test('any listen isSame matches a listen on that day', () {
    final listenedThatDay = trackAt('listenedThatDay', DateTime(2020));
    final listenedNextMidnight = trackAt('listenedNextMidnight', DateTime(2020));
    final listens = {
      listenedThatDay: [DateTime(2026, 10, 21, 10).millisecondsSinceEpoch, DateTime(2026, 10, 22, 15, 30).millisecondsSinceEpoch],
      listenedNextMidnight: [DateTime(2026, 10, 21, 10).millisecondsSinceEpoch, DateTime(2026, 10, 23).millisecondsSinceEpoch],
    };
    HistoryController.inst.topTracksMapListens.value.assignAll(listens);
    final rule = ruleOf(SmartPlaylistRuleFilterDateTime.isSame, DateTime(2026, 10, 22), source: SmartPlaylistRuleFilterDateTimeSource.anyListen);
    expect(matchedNames(rule, [listenedThatDay, listenedNextMidnight]), {'listenedThatDay'});
  });

  group('typed text', () {
    late final rule = ruleOf(SmartPlaylistRuleFilterDateTime.isSame, null);

    test('keeps the precision that was typed', () {
      const expected = {
        '2019': SmartPlaylistDatePrecision.year,
        '2019-05': SmartPlaylistDatePrecision.month,
        '2019-05-14': SmartPlaylistDatePrecision.day,
        '2019-05-14 12:30': SmartPlaylistDatePrecision.minute,
        '2019-05-14 12:30:15': SmartPlaylistDatePrecision.second,
        '2019-01-01 00:00:00': SmartPlaylistDatePrecision.second,
      };
      for (final e in expected.entries) {
        final date = rule.textToData(e.key);
        expect(date?.precision, e.value, reason: e.key);
        expect(rule.dataToText(date), e.key);
      }
      expect(rule.dataToText(rule.textToData('2019-5-4')), '2019-05-04');
    });

    test('clock text keeps minutes or seconds', () {
      expect(SmartPlaylistDatePartsValue.tryParseClock('14:30'), (secondOfDay: 52200, hasSeconds: false));
      expect(SmartPlaylistDatePartsValue.tryParseClock('14:30:15'), (secondOfDay: 52215, hasSeconds: true));
      expect(SmartPlaylistDatePartsValue.clockToText(52200, hasSeconds: false), '14:30');
      expect(SmartPlaylistDatePartsValue.clockToText(52215, hasSeconds: true), '14:30:15');
    });

    test('a time needs the clock part', () {
      final dateOnly = partsRuleOf(.isSame, const [.year, .month, .day], null);
      expect(dateOnly.textToData('2019-05-14')?.precision, SmartPlaylistDatePrecision.day);
      expect(dateOnly.textToData('2019-05-14 12:30'), isNull);
      expect(dateOnly.dataValidator('2019-05-14 12:30'), isNotNull);
      expect(dateOnly.toHintText(), 'YYYY-MM-DD');
    });

    test('other iso formats read like before', () {
      expect(rule.textToData('20190514'), SmartPlaylistDate(DateTime(2019, 5, 14), SmartPlaylistDatePrecision.day));
    });

    test('invalid text is rejected', () {
      for (final text in ['19', '2019-13', '2019-02-30', '2019-05-14 24:00', 'abc']) {
        expect(rule.textToData(text), isNull, reason: text);
        expect(rule.dataValidator(text), isNotNull, reason: text);
      }
      for (final text in ['24:00', '12', '12:60']) {
        expect(SmartPlaylistDatePartsValue.tryParseClock(text), isNull, reason: text);
      }
    });

    test('rule text shows the year or the month', () {
      expect(typedRuleOf(SmartPlaylistRuleFilterDateTime.isSame, '2019').datasDisplayText(), '= 2019');
      expect(typedRuleOf(SmartPlaylistRuleFilterDateTime.isSame, '2019-05').datasDisplayText(), '= May 2019');
    });

    test('saved rules without a precision keep their old meaning', () {
      final midnight = DateTime(2019);
      final dateRule = SmartPlaylistRuleBase.fromMap({'type': 'dateTime', 'filter': 'isSame', 'source': 'year', 'data': midnight.millisecondsSinceEpoch});
      expect(dateRule?.data, SmartPlaylistDate(midnight, SmartPlaylistDatePrecision.day));
      expect(dateRule?.toMap()['dataPrecision'], 'day');

      final clock = DateTime(0, 1, 1, 14, 30);
      final clockMap = {'type': 'dateTime', 'filter': 'isSame', 'source': 'dateAdded', 'data': clock.millisecondsSinceEpoch, 'clockOnly': true};
      expect((dateRule as SmartPlaylistRuleDateTime?)?.parts, SmartPlaylistDateParts.dateAndClock);
      final clockRule = SmartPlaylistRuleBase.fromMap(clockMap) as SmartPlaylistRuleDateTime?;
      expect(clockRule?.data, const SmartPlaylistDatePartsValue(secondOfDay: 52200));
      expect(clockRule?.parts, SmartPlaylistDateParts.timeOnly);
    });

    test('typed rules survive a round trip', () {
      final typedRule = typedRuleOf(SmartPlaylistRuleFilterDateTime.isInBetween, '2019', text2: '2020-05-14 12:30');
      expect(SmartPlaylistRuleBase.fromMap(typedRule.toMap()), typedRule);
    });
  });

  group('typed precisions on timestamps', () {
    late final tracks = [
      trackAt('lastOf2018', DateTime(2018, 12, 31, 23, 59, 59)),
      trackAt('newYear2019', DateTime(2019)),
      trackAt('newYear2019Noon', DateTime(2019, 1, 1, 12)),
      trackAt('may14At1230', DateTime(2019, 5, 14, 12, 30)),
      trackAt('may14At123059', DateTime(2019, 5, 14, 12, 30, 59)),
      trackAt('may14At1231', DateTime(2019, 5, 14, 12, 31)),
      trackAt('lastOf2019', DateTime(2019, 12, 31, 23, 59, 59)),
      trackAt('newYear2020', DateTime(2020)),
    ];
    const in2019 = {'newYear2019', 'newYear2019Noon', 'may14At1230', 'may14At123059', 'may14At1231', 'lastOf2019'};
    const inMay2019 = {'may14At1230', 'may14At123059', 'may14At1231'};

    Set<String> matched(SmartPlaylistRuleFilterDateTime filter, String text, [String? text2]) => matchedNames(typedRuleOf(filter, text, text2: text2), tracks);

    test('isSame covers what was typed', () {
      expect(matched(.isSame, '2019'), in2019);
      expect(matched(.isSame, '2019-05'), inMay2019);
      expect(matched(.isSame, '2019-01-01'), {'newYear2019', 'newYear2019Noon'});
      expect(matched(.isSame, '2019-05-14 12:30'), {'may14At1230', 'may14At123059'});
      expect(matched(.isSame, '2019-05-14 12:30:00'), {'may14At1230'});
      expect(matched(.isSame, '2019-01-01 00:00:00'), {'newYear2019'});
    });

    test('isNotSame is the opposite of isSame', () {
      expect(matched(.isNotSame, '2019'), {'lastOf2018', 'newYear2020'});
    });

    test('isBefore and isAfter include the whole value', () {
      expect(matched(.isBefore, '2019'), {'lastOf2018', ...in2019});
      expect(matched(.isBefore, '2019-04'), {'lastOf2018', 'newYear2019', 'newYear2019Noon'});
      expect(matched(.isAfter, '2019-05'), {...inMay2019, 'lastOf2019', 'newYear2020'});
    });

    test('isInBetween includes both values whole, in any order', () {
      expect(matched(.isInBetween, '2019', '2019-05'), in2019);
      expect(matched(.isInBetween, '2019-12', '2019-05'), {...inMay2019, 'lastOf2019'});
    });

    test('isOutside is the opposite of isInBetween', () {
      expect(matched(.isOutside, '2019-02', '2019-11'), {'lastOf2018', 'newYear2019', 'newYear2019Noon', 'lastOf2019', 'newYear2020'});
    });

    test('clock only minutes and seconds', () {
      final clockTracks = [
        trackAt('t_143000', DateTime(2026, 3, 2, 14, 30)),
        trackAt('t_143030', DateTime(2026, 3, 3, 14, 30, 30)),
        trackAt('t_143100', DateTime(2026, 3, 5, 14, 31)),
      ];
      expect(matchedNames(partsRuleOf(.isSame, const [.time], clockValue('14:30')), clockTracks), {'t_143000', 't_143030'});
      expect(matchedNames(partsRuleOf(.isSame, const [.time], clockValue('14:30:00')), clockTracks), {'t_143000'});
    });
  });

  group('year tags', () {
    late final tracks = [
      trackWithYear('yearOnly2019', 2019),
      trackWithYear('may14of2019', 20190514),
      trackWithYear('yearOnly2020', 2020),
      trackWithYear('unknownYear', 0),
    ];
    const source = SmartPlaylistRuleFilterDateTimeSource.year;

    Set<String> matched(SmartPlaylistRuleFilterDateTime filter, String text) => matchedNames(typedRuleOf(filter, text, source: source), tracks);

    test('a year matches year-only tags and full dates', () {
      expect(matched(.isSame, '2019'), {'yearOnly2019', 'may14of2019'});
      expect(matched(.isSame, '2019-05'), {'may14of2019'});
    });

    test('a year-only tag matches only when its whole year fits', () {
      expect(matched(.isSame, '2019-01-01'), <String>{});
      expect(matched(.isNotSame, '2019-05'), {'yearOnly2020'});
      expect(matched(.isBefore, '2019'), {'yearOnly2019', 'may14of2019'});
      expect(matched(.isBefore, '2019-03'), <String>{});
      expect(matched(.isAfter, '2019'), {'yearOnly2019', 'may14of2019', 'yearOnly2020'});
      expect(matched(.isAfter, '2019-03'), {'may14of2019', 'yearOnly2020'});
      expect(matchedNames(typedRuleOf(.isInBetween, '2018', text2: '2019', source: source), tracks), {'yearOnly2019', 'may14of2019'});
      expect(matchedNames(typedRuleOf(.isOutside, '2019-03', text2: '2019-06', source: source), tracks), {'yearOnly2020'});
    });

    test('unknown years are missing', () {
      expect(matchedNames(ruleOf(.missing, null, source: source), tracks), {'unknownYear'});
      expect(matchedNames(ruleOf(.exists, null, source: source), tracks), {'yearOnly2019', 'may14of2019', 'yearOnly2020'});
    });

    test('compared parts read full date tags, year-only tags only know the year', () {
      final month = partsRuleOf(.isSame, const [.month], const SmartPlaylistDatePartsValue(month: 5), source: source);
      expect(matchedNames(month, tracks), {'may14of2019'});
      final year = partsRuleOf(.isSame, const [.year], const SmartPlaylistDatePartsValue(year: 2019), source: source);
      expect(matchedNames(year, tracks), {'yearOnly2019', 'may14of2019'});
      final missingMonth = partsRuleOf(.missing, const [.month], null, source: source);
      expect(matchedNames(missingMonth, tracks), {'unknownYear'});
    });
  });

  group('compared parts', () {
    late final tracks = [
      trackAt('tue_2019_12_10_2000', DateTime(2019, 12, 10, 20)),
      trackAt('fri_2019_05_10_0900', DateTime(2019, 5, 10, 9)),
      trackAt('mon_2021_05_10_0900', DateTime(2021, 5, 10, 9)),
      trackAt('fri_2020_12_25_2330', DateTime(2020, 12, 25, 23, 30)),
      trackAt('sat_2021_01_02_0130', DateTime(2021, 1, 2, 1, 30)),
      trackAt('sat_2019_06_15_1800', DateTime(2019, 6, 15, 18)),
    ];

    Set<String> matched(SmartPlaylistRuleFilterDateTime filter, List<SmartPlaylistDatePart> parts, SmartPlaylistDatePartsValue data, [SmartPlaylistDatePartsValue? data2]) =>
        matchedNames(partsRuleOf(filter, parts, data, data2: data2), tracks);

    test('a single part of any date', () {
      expect(matched(.isSame, const [.month], const SmartPlaylistDatePartsValue(month: 12)), {'tue_2019_12_10_2000', 'fri_2020_12_25_2330'});
      expect(matched(.isSame, const [.day], const SmartPlaylistDatePartsValue(day: 10)), {'tue_2019_12_10_2000', 'fri_2019_05_10_0900', 'mon_2021_05_10_0900'});
      expect(matched(.isSame, const [.weekday], const SmartPlaylistDatePartsValue(weekday: DateTime.friday)), {'fri_2019_05_10_0900', 'fri_2020_12_25_2330'});
      expect(matched(.isNotSame, const [.month], const SmartPlaylistDatePartsValue(month: 12)), {
        'fri_2019_05_10_0900',
        'mon_2021_05_10_0900',
        'sat_2021_01_02_0130',
        'sat_2019_06_15_1800',
      });
    });

    test('parts combine, ex: the 10th of any month in 2019', () {
      expect(matched(.isSame, const [.year, .day], const SmartPlaylistDatePartsValue(year: 2019, day: 10)), {'tue_2019_12_10_2000', 'fri_2019_05_10_0900'});
      expect(matched(.isSame, const [.month, .weekday], const SmartPlaylistDatePartsValue(month: 12, weekday: DateTime.friday)), {'fri_2020_12_25_2330'});
      final fridayEvenings = matched(
        .isInBetween,
        const [.weekday, .time],
        SmartPlaylistDatePartsValue(weekday: DateTime.friday, secondOfDay: clockValue('18:00').secondOfDay),
        SmartPlaylistDatePartsValue(weekday: DateTime.friday, secondOfDay: clockValue('23:59').secondOfDay),
      );
      expect(fridayEvenings, {'fri_2020_12_25_2330'});
    });

    test('ranges without the year wrap around', () {
      const saturday = SmartPlaylistDatePartsValue(weekday: DateTime.saturday);
      const sunday = SmartPlaylistDatePartsValue(weekday: DateTime.sunday);
      expect(matched(.isInBetween, const [.weekday], saturday, sunday), {'sat_2021_01_02_0130', 'sat_2019_06_15_1800'});
      const friday = SmartPlaylistDatePartsValue(weekday: DateTime.friday);
      const monday = SmartPlaylistDatePartsValue(weekday: DateTime.monday);
      expect(matched(.isInBetween, const [.weekday], friday, monday), {
        'fri_2019_05_10_0900',
        'mon_2021_05_10_0900',
        'fri_2020_12_25_2330',
        'sat_2021_01_02_0130',
        'sat_2019_06_15_1800',
      });
      expect(matched(.isInBetween, const [.month], const SmartPlaylistDatePartsValue(month: 12), const SmartPlaylistDatePartsValue(month: 1)), {
        'tue_2019_12_10_2000',
        'fri_2020_12_25_2330',
        'sat_2021_01_02_0130',
      });
      expect(matched(.isInBetween, const [.time], clockValue('23:00'), clockValue('02:00')), {'fri_2020_12_25_2330', 'sat_2021_01_02_0130'});
      expect(matched(.isOutside, const [.time], clockValue('23:00'), clockValue('02:00')), {
        'tue_2019_12_10_2000',
        'fri_2019_05_10_0900',
        'mon_2021_05_10_0900',
        'sat_2019_06_15_1800',
      });
    });

    test('before and after start at the cycle start', () {
      expect(matched(.isBefore, const [.month], const SmartPlaylistDatePartsValue(month: 6)), {
        'fri_2019_05_10_0900',
        'mon_2021_05_10_0900',
        'sat_2021_01_02_0130',
        'sat_2019_06_15_1800',
      });
      expect(matched(.isAfter, const [.month], const SmartPlaylistDatePartsValue(month: 6)), {'tue_2019_12_10_2000', 'fri_2020_12_25_2330', 'sat_2019_06_15_1800'});
    });

    test('a single listen has to hold all parts', () {
      final splitListens = trackAt('splitListens', DateTime(2020));
      final sameListen = trackAt('sameListen', DateTime(2020));
      HistoryController.inst.topTracksMapListens.value.assignAll({
        splitListens: [DateTime(2019, 5, 3).millisecondsSinceEpoch, DateTime(2021, 6, 10).millisecondsSinceEpoch],
        sameListen: [DateTime(2019, 7, 10).millisecondsSinceEpoch],
      });
      final rule = partsRuleOf(.isSame, const [.year, .day], const SmartPlaylistDatePartsValue(year: 2019, day: 10), source: .anyListen);
      expect(matchedNames(rule, [splitListens, sameListen]), {'sameListen'});
    });

    test('a value missing a compared part is not complete', () {
      expect(partsRuleOf(.isSame, const [.year, .day], const SmartPlaylistDatePartsValue(year: 2019)).validate(), lang.emptyValue);
      expect(partsRuleOf(.isSame, const [.year, .day], const SmartPlaylistDatePartsValue(year: 2019, day: 10)).validate(), isNull);
      expect(partsRuleOf(.isSame, const [.month], SmartPlaylistDate(DateTime(2019), .year)).validate(), lang.emptyValue);
    });

    test('rule text and json', () {
      final rule = partsRuleOf(.isSame, const [.year, .day, .time], SmartPlaylistDatePartsValue(year: 2019, day: 10, secondOfDay: clockValue('18:30').secondOfDay));
      expect(rule.datasDisplayText(), '= 2019 · ${lang.day} 10 · 18:30');
      expect(SmartPlaylistRuleBase.fromMap(rule.toMap()), rule);
    });

    test('day and weekday replace each other, the last part stays', () {
      final parts = SmartPlaylistDateParts.of(const [.month, .day]);
      final withWeekday = parts.toggled(.weekday);
      expect(withWeekday.has(.weekday), isTrue);
      expect(withWeekday.has(.day), isFalse);
      final timeOnly = SmartPlaylistDateParts.timeOnly;
      expect(timeOnly.toggled(.time), timeOnly);
    });
  });

  group('known parts', () {
    final clock = clockValue('18:30:15');
    final fullParts = SmartPlaylistDatePartsValue(year: 2019, month: 5, day: 14, secondOfDay: clock.secondOfDay, hasSeconds: true);

    test('a typed date gives the parts its precision covers', () {
      expect(SmartPlaylistDatePartsValue.knownIn(SmartPlaylistDate(DateTime(2024, 11), .month)), const SmartPlaylistDatePartsValue(year: 2024, month: 11));
      const tuesday = SmartPlaylistDatePartsValue(year: 2024, month: 11, day: 5, weekday: DateTime.tuesday);
      expect(SmartPlaylistDatePartsValue.knownIn(SmartPlaylistDate(DateTime(2024, 11, 5), .day)), tuesday);
      final minute = SmartPlaylistDatePartsValue.knownIn(SmartPlaylistDate(DateTime(2024, 11, 5, 18, 30), .minute));
      expect(minute.secondOfDay, clockValue('18:30').secondOfDay);
      expect(minute.hasSeconds, isFalse);
      expect(SmartPlaylistDatePartsValue.knownIn(const SmartPlaylistNowDate(offsetAmount: 0, offsetUnit: .days)), const SmartPlaylistDatePartsValue());
    });

    test('shown parts replace, hidden ones stay', () {
      final yearAndMonth = SmartPlaylistDateParts.of(const [.year, .month]);
      final merged = fullParts.mergedWith(const SmartPlaylistDatePartsValue(year: 2020), yearAndMonth);
      expect(merged, SmartPlaylistDatePartsValue(year: 2020, day: 14, secondOfDay: clock.secondOfDay, hasSeconds: true));
      final withWeekday = fullParts.mergedWith(const SmartPlaylistDatePartsValue(year: 2024, weekday: DateTime.friday), SmartPlaylistDateParts.of(const [.year]));
      expect(withWeekday.weekday, DateTime.friday);
      expect(withWeekday.month, 5);
    });

    test('back to a full date as far as the parts go', () {
      expect(fullParts.toDate(withClock: true), SmartPlaylistDate(DateTime(2019, 5, 14, 18, 30, 15), .second));
      expect(fullParts.toDate(withClock: false), SmartPlaylistDate(DateTime(2019, 5, 14), .day));
      expect(const SmartPlaylistDatePartsValue(year: 2019, month: 2, day: 31).toDate(withClock: false), SmartPlaylistDate(DateTime(2019, 2), .month));
      expect(const SmartPlaylistDatePartsValue(year: 2019, month: 13, day: 1).toDate(withClock: false), SmartPlaylistDate(DateTime(2019), .year));
      expect(const SmartPlaylistDatePartsValue(month: 5, day: 14).toDate(withClock: false), isNull);
    });

    test('only the compared parts are saved', () {
      final monthAndTime = SmartPlaylistDateParts.of(const [.month, .time]);
      expect(fullParts.onlyParts(monthAndTime), SmartPlaylistDatePartsValue(month: 5, secondOfDay: clock.secondOfDay, hasSeconds: true));
    });
  });

  group('now values', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dates = {
      'todayNoon': DateTime(today.year, today.month, today.day, 12),
      'yesterdayNoon': DateTime(today.year, today.month, today.day - 1, 12),
      'weekAgoNoon': DateTime(today.year, today.month, today.day - 7, 12),
      'monthAgoNoon': DateTime(today.year, today.month - 1, 15, 12),
      'yearAgoNoon': DateTime(today.year - 1, today.month, 15, 12),
    };
    late final tracks = dates.entries.map((e) => trackAt(e.key, e.value)).toList();

    Set<String> namesWhere(bool Function(DateTime date) test) => dates.entries.where((e) => test(e.value)).map((e) => e.key).toSet();

    SmartPlaylistNowDate nowValue(int amount, SmartPlaylistRelativeUnit unit) => SmartPlaylistNowDate(offsetAmount: amount, offsetUnit: unit);

    test('full dates cover the whole unit', () {
      expect(matchedNames(partsRuleOf(.isSame, fullDateParts, nowValue(0, .days)), tracks), {'todayNoon'});
      expect(matchedNames(partsRuleOf(.isSame, fullDateParts, nowValue(-1, .days)), tracks), {'yesterdayNoon'});
      final thisMonth = namesWhere((date) => date.year == now.year && date.month == now.month);
      expect(matchedNames(partsRuleOf(.isSame, fullDateParts, nowValue(0, .months)), tracks), thisMonth);
      final sinceLastYear = namesWhere((date) => date.year >= now.year - 1);
      expect(matchedNames(partsRuleOf(.isInBetween, fullDateParts, nowValue(-1, .years), data2: nowValue(0, .years)), tracks), sinceLastYear);
    });

    test('compared parts follow now', () {
      expect(matchedNames(partsRuleOf(.isSame, const [.weekday], nowValue(0, .days)), tracks), namesWhere((date) => date.weekday == now.weekday));
      expect(matchedNames(partsRuleOf(.isSame, const [.month], nowValue(0, .days)), tracks), namesWhere((date) => date.month == now.month));
    });

    test('a clock range around now, also across midnight', () {
      final clockTracks = [
        trackAt('halfHourAgo', now.subtract(const Duration(minutes: 30))),
        trackAt('inHalfHour', now.add(const Duration(minutes: 30))),
        trackAt('twoHoursAgo', now.subtract(const Duration(hours: 2))),
        trackAt('inTwoHours', now.add(const Duration(hours: 2))),
      ];
      final rule = partsRuleOf(.isInBetween, const [.time], nowValue(-1, .hours), data2: nowValue(1, .hours));
      expect(matchedNames(rule, clockTracks), {'halfHourAgo', 'inHalfHour'});
    });

    test('rule text and json', () {
      final rule = partsRuleOf(.isInBetween, fullDateParts, nowValue(0, .months), data2: nowValue(-2, .days));
      expect(rule.datasDisplayText(), '${lang.now} (${lang.months}) -> • <- ${lang.now} − 2 ${lang.days}');
      expect(rule.validate(), isNull);
      expect(SmartPlaylistRuleBase.fromMap(rule.toMap()), rule);
    });
  });
}
