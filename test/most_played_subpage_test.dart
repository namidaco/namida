// by claude
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:history_manager/history_manager.dart';

import 'package:namida/class/lang.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/pages/subpages/most_played_subpage.dart';

void main() {
  late Directory root;
  ThemeData? theme;

  setUpAll(() {
    root = Directory.systemTemp.createTempSync('namida_most_played_test');
    AppDirs.USER_DATA = '${p.join(root.path, 'user_data')}${Platform.pathSeparator}';
    Language.inst.update(language: NamidaLanguage.fromCode('en'));
  });
  tearDownAll(() {
    try {
      root.deleteSync(recursive: true);
    } catch (_) {} // -- settings writes can still hold the files
  });

  test('a days radius pick covers whole days around the picked day, 2 * radius + 1 days', () {
    final range = MostPlayedItemsPage.debugRangeCenteredOnDay(DateTime(2026, 1, 12, 15), 2);
    expect(range, DateRange.wholeDays(oldest: DateTime(2026, 1, 10), newest: DateTime(2026, 1, 14)));
    expect(range.toDaysSafe(), 5);

    final acrossMonths = MostPlayedItemsPage.debugRangeCenteredOnDay(DateTime(2026, 3, 30), 3);
    expect(acrossMonths, DateRange.wholeDays(oldest: DateTime(2026, 3, 27), newest: DateTime(2026, 4, 2)));
    expect(acrossMonths.toDaysSafe(), 7);
  });

  group('header chips', () {
    const historyDaysCount = 400;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime daysAgo(int days) => DateTime(today.year, today.month, today.day - days);
    int calendarDaysSince(DateTime oldest) {
      final todayUtc = DateTime.utc(today.year, today.month, today.day);
      final oldestUtc = DateTime.utc(oldest.year, oldest.month, oldest.day);
      return todayUtc.difference(oldestUtc).inDays + 1;
    }

    Future<void> frames(WidgetTester tester, [int count = 8]) async {
      for (int i = 0; i < count; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<List<_SavedTimeRange>> pumpPage(WidgetTester tester, _FakeHistory history) async {
      tester.view.physicalSize = const Size(600, 1300);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final appTheme = theme ??= AppThemes.inst.getAppTheme(null, true);
      final saves = <_SavedTimeRange>[];
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: namida.rootNavigatorKey,
          theme: appTheme,
          home: NTheme(
            data: appTheme,
            child: Material(
              child: MostPlayedItemsPage<_Listen, int>(
                historyController: history,
                isInFullPage: true,
                itemExtent: 50.0,
                itemsCount: 0,
                itemBuilder: (context, i) => const SizedBox(),
                header: (timeRangeChips, bottomPadding) => timeRangeChips,
                infoBox: null,
                // -- same as the real pages, null means keep
                onSavingTimeRange: ({required mptr, dateCustom, isStartOfDay}) {
                  saves.add((mptr: mptr, dateCustom: dateCustom, isStartOfDay: isStartOfDay));
                  if (mptr != null) history.currentMostPlayedTimeRange.value = mptr;
                  if (dateCustom != null) history.mostPlayedCustomDateRange.value = dateCustom;
                  if (isStartOfDay != null) history.mostPlayedCustomIsStartOfDay.value = isStartOfDay;
                },
              ),
            ),
          ),
        ),
      );
      await frames(tester);
      return saves;
    }

    _FakeHistory createHistory({required MostPlayedTimeRange mptr, required DateRange storedRange, bool isStartOfDay = true}) {
      final history = _FakeHistory(mptr, storedRange, isStartOfDay);
      final map = history.historyMap.value;
      for (int i = 0; i < historyDaysCount; i++) {
        final listenMS = daysAgo(i).add(const Duration(minutes: 1)).millisecondsSinceEpoch;
        map[listenMS.toDaysSince1970()] = [_Listen(listenMS)];
      }
      return history;
    }

    Slider slider(WidgetTester tester) => tester.widget<Slider>(find.byType(Slider));

    testWidgets('a stale stored range from an old pick does not leak into the days pill', (tester) async {
      // -- the bug: "Month" picked on a 1st saved 1st 00:00 → 1st 10:00, shown as "1 Day" days later
      final stalePick = DateRange(oldest: DateTime(2026, 1, 1), newest: DateTime(2026, 1, 1, 10));
      final history = createHistory(mptr: MostPlayedTimeRange.month, storedRange: stalePick);
      await pumpPage(tester, history);

      expect(find.text(now.day.displayDayKeyword), findsOneWidget);
      expect(find.text(DateTime(now.year, now.month).dateFormattedOriginal), findsWidgets);
      expect(find.text(now.dateFormattedOriginal), findsWidgets);
      if (now.day != 1) expect(find.text(1.displayDayKeyword), findsNothing);

      // -- non custom ranges are never a slider step, thumb stays parked at the end
      expect(slider(tester).value, 0.0);
    });

    testWidgets('days pill and oldest date follow each range, today counts whole in day mode', (tester) async {
      final history = createHistory(mptr: MostPlayedTimeRange.day, storedRange: DateRange.dummy());
      await pumpPage(tester, history);

      final startOfDayCases = <(MostPlayedTimeRange, DateTime)>[
        (MostPlayedTimeRange.day, today),
        (MostPlayedTimeRange.day3, daysAgo(2)),
        (MostPlayedTimeRange.week, daysAgo(6)),
        (MostPlayedTimeRange.month, DateTime(now.year, now.month)),
        (MostPlayedTimeRange.month3, DateTime(now.year, now.month - 2)),
        (MostPlayedTimeRange.month6, DateTime(now.year, now.month - 5)),
        (MostPlayedTimeRange.year, DateTime(now.year)),
        (MostPlayedTimeRange.allTime, daysAgo(historyDaysCount - 1)),
      ];
      for (final (mptr, oldest) in startOfDayCases) {
        history.currentMostPlayedTimeRange.value = mptr;
        await tester.pump();
        final pillText = calendarDaysSince(oldest).displayDayKeyword;
        expect(find.text(pillText), findsNWidgets(pillText == mptr.toText() ? 2 : 1), reason: '$mptr, start of day');
        expect(find.text(oldest.dateFormattedOriginal), findsWidgets, reason: '$mptr, start of day');
      }

      history.mostPlayedCustomIsStartOfDay.value = false;
      final clockCases = <(MostPlayedTimeRange, int)>[
        (MostPlayedTimeRange.day, 1),
        (MostPlayedTimeRange.day3, 3),
        (MostPlayedTimeRange.week, 7),
        (MostPlayedTimeRange.month, 30),
        (MostPlayedTimeRange.month3, 90),
        (MostPlayedTimeRange.month6, 180),
        (MostPlayedTimeRange.year, 365),
      ];
      for (final (mptr, days) in clockCases) {
        history.currentMostPlayedTimeRange.value = mptr;
        await tester.pump();
        final oldest = now.subtract(Duration(days: days));
        final pillText = days.displayDayKeyword;
        expect(find.text(pillText), findsNWidgets(pillText == mptr.toText() ? 2 : 1), reason: '$mptr, clock');
        expect(find.text(oldest.dateFormattedOriginal), findsWidgets, reason: '$mptr, clock');
      }
    });

    testWidgets('switching day/clock refreshes the chips without saving a range', (tester) async {
      final history = createHistory(mptr: MostPlayedTimeRange.week, storedRange: DateRange.dummy());
      final saves = await pumpPage(tester, history);
      expect(find.text(daysAgo(6).dateFormattedOriginal), findsOneWidget);

      await tester.tap(find.byIcon(Broken.setting_4));
      await frames(tester);
      await tester.tap(find.text(lang.clock));
      await frames(tester);

      expect(saves.single, (mptr: MostPlayedTimeRange.week, dateCustom: null, isStartOfDay: false));
      expect(history.mostPlayedCustomDateRange.value, DateRange.dummy());
      final clockOldest = now.subtract(const Duration(days: 7));
      expect(find.text(clockOldest.dateFormattedOriginal), findsOneWidget);
      expect(find.text(daysAgo(6).dateFormattedOriginal), findsNothing);
      expect(find.text(7.displayDayKeyword), findsOneWidget);
    });

    testWidgets('picking a non custom range keeps the stored custom range', (tester) async {
      final customRange = DateRange.wholeDays(oldest: daysAgo(9), newest: daysAgo(5));
      final history = createHistory(mptr: MostPlayedTimeRange.custom, storedRange: customRange);
      final saves = await pumpPage(tester, history);
      expect(find.text(5.displayDayKeyword), findsOneWidget);
      expect(find.text(daysAgo(9).dateFormattedOriginal), findsOneWidget);
      expect(find.text(daysAgo(5).dateFormattedOriginal), findsOneWidget);

      await tester.tap(find.text(MostPlayedTimeRange.custom.toText()));
      await frames(tester);
      await tester.tap(find.text(MostPlayedTimeRange.week.toText()).last);
      await frames(tester);

      expect(saves.single, (mptr: MostPlayedTimeRange.week, dateCustom: null, isStartOfDay: null));
      expect(history.mostPlayedCustomDateRange.value, customRange);
      expect(find.text(7.displayDayKeyword), findsOneWidget);
      expect(find.text(daysAgo(6).dateFormattedOriginal), findsOneWidget);

      history.currentMostPlayedTimeRange.value = MostPlayedTimeRange.custom;
      await tester.pump();
      expect(find.text(5.displayDayKeyword), findsOneWidget);
      expect(find.text(daysAgo(9).dateFormattedOriginal), findsOneWidget);
    });

    testWidgets('a custom range on a slider step keeps the thumb on that step', (tester) async {
      const stepDays = 5;
      const stepIndex = 10;
      const rangesCount = historyDaysCount ~/ stepDays;
      final oldestHistoryDay = daysAgo(historyDaysCount - 1);
      DateTime historyDay(int index) => DateTime(oldestHistoryDay.year, oldestHistoryDay.month, oldestHistoryDay.day + index);

      final onStep = DateRange.wholeDays(oldest: historyDay(stepIndex * stepDays), newest: historyDay(stepIndex * stepDays + stepDays - 1));
      final history = createHistory(mptr: MostPlayedTimeRange.custom, storedRange: onStep);
      await pumpPage(tester, history);
      expect(find.text(stepDays.displayDayKeyword), findsOneWidget);
      expect(slider(tester).max, rangesCount - 1);
      expect(slider(tester).value, rangesCount - 1 - stepIndex);

      final offStep = DateRange.wholeDays(oldest: historyDay(stepIndex * stepDays + 1), newest: historyDay(stepIndex * stepDays + stepDays));
      history.mostPlayedCustomDateRange.value = offStep;
      await tester.pump();
      expect(find.text(stepDays.displayDayKeyword), findsOneWidget);
      expect(slider(tester).max, rangesCount);
      expect(slider(tester).value, 0.0);
    });
  });
}

class _FakeHistory with HistoryManager<_Listen, int> {
  @override
  final Rx<MostPlayedTimeRange> currentMostPlayedTimeRange;
  @override
  final Rx<DateRange> mostPlayedCustomDateRange;
  @override
  final Rx<bool> mostPlayedCustomIsStartOfDay;

  _FakeHistory(MostPlayedTimeRange mptr, DateRange storedRange, bool isStartOfDay)
    : currentMostPlayedTimeRange = mptr.obs,
      mostPlayedCustomDateRange = storedRange.obs,
      mostPlayedCustomIsStartOfDay = isStartOfDay.obs;

  @override
  // ignore: non_constant_identifier_names
  String get HISTORY_DIRECTORY => '';

  @override
  int mainItemToSubItem(_Listen item) => item.dateAddedMS;

  @override
  Map<String, dynamic> itemToJson(_Listen item) => {'dateAddedMS': item.dateAddedMS};

  @override
  double daysToSectionExtent(List<int> days) => 0.0;

  @override
  bool get didRepairHistoryDays => true;

  @override
  void onHistoryDaysRepaired() {}

  @override
  Future<HistoryPrepareInfo<_Listen, int>> prepareAllHistoryFilesFunction(String directoryPath, {bool repairDays = false}) => throw UnimplementedError();
}

class _Listen with ItemWithDate {
  @override
  final int dateAddedMS;

  const _Listen(this.dateAddedMS);

  @override
  TrackSource? get sourceNull => null;
}

typedef _SavedTimeRange = ({MostPlayedTimeRange? mptr, DateRange? dateCustom, bool? isStartOfDay});
