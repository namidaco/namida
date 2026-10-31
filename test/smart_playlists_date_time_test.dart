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
    data: data,
    data2: data2,
    filter: filter,
    source: source,
    enableCleanup: false,
    clockOnly: clockOnly,
    relativeDuration: null,
  );

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
      expect(rule.dataToText(day), '2026-10-22');
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
      expect(rule.dataToText(noon), '2026-10-22 12:00:00');
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
}
