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

  SmartPlaylistRuleDateTime ruleOf(
    SmartPlaylistRuleFilterDateTime filter,
    DateTime? data, {
    DateTime? data2,
    SmartPlaylistRuleFilterDateTimeSource source = SmartPlaylistRuleFilterDateTimeSource.dateAdded,
    bool clockOnly = false,
  }) => SmartPlaylistRuleDateTime(
    data: data == null ? null : SmartPlaylistDate.legacy(data, clockOnly: clockOnly),
    data2: data2 == null ? null : SmartPlaylistDate.legacy(data2, clockOnly: clockOnly),
    filter: filter,
    source: source,
    enableCleanup: false,
    clockOnly: clockOnly,
    relativeDuration: null,
  );

  SmartPlaylistRuleDateTime typedRuleOf(
    SmartPlaylistRuleFilterDateTime filter,
    String text, {
    String? text2,
    SmartPlaylistRuleFilterDateTimeSource source = SmartPlaylistRuleFilterDateTimeSource.dateAdded,
    bool clockOnly = false,
  }) {
    final rule = ruleOf(filter, null, source: source, clockOnly: clockOnly);
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
    late final clockRule = ruleOf(SmartPlaylistRuleFilterDateTime.isSame, null, clockOnly: true);

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

    test('clock only keeps minutes or seconds', () {
      expect(clockRule.textToData('14:30')?.precision, SmartPlaylistDatePrecision.minute);
      expect(clockRule.textToData('14:30:15')?.precision, SmartPlaylistDatePrecision.second);
      expect(clockRule.dataToText(clockRule.textToData('14:30')), '14:30');
      expect(clockRule.dataToText(clockRule.textToData('14:30:15')), '14:30:15');
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
        expect(clockRule.textToData(text), isNull, reason: text);
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
      expect(SmartPlaylistRuleBase.fromMap(clockMap)?.data, SmartPlaylistDate(clock, SmartPlaylistDatePrecision.minute));
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
      expect(matchedNames(typedRuleOf(.isSame, '14:30', clockOnly: true), clockTracks), {'t_143000', 't_143030'});
      expect(matchedNames(typedRuleOf(.isSame, '14:30:00', clockOnly: true), clockTracks), {'t_143000'});
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
  });
}
