// by claude
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:namida/class/lang.dart';
import 'package:namida/class/sort_chain.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/smart_playlists/smart_playlists_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/create_smart_playlist_dialog.dart';

void main() {
  late Directory root;
  ThemeData? theme;

  setUpAll(() {
    root = Directory.systemTemp.createTempSync('namida_sp_dialog_test');
    AppDirs.USER_DATA = '${p.join(root.path, 'user_data')}${Platform.pathSeparator}';
    Language.inst.update(language: NamidaLanguage.fromCode('en'));
  });
  tearDownAll(() {
    try {
      root.deleteSync(recursive: true);
    } catch (_) {} // -- settings writes can still hold the files
  });

  Future<void> frames(WidgetTester tester, [int count = 12]) async {
    for (int i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openDialog(WidgetTester tester, {List<SmartPlaylistRuleBase>? rules}) async {
    tester.view.physicalSize = const Size(600, 1300);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // -- built once, later tests would read it from the previous test's context
    final appTheme = theme ??= AppThemes.inst.getAppTheme(null, true);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: namida.rootNavigatorKey,
        theme: appTheme,
        home: NTheme(
          data: appTheme,
          child: const SizedBox(),
        ),
      ),
    );
    final wrapper = rules == null
        ? null
        : SmartPlaylistWrapper(
            SmartPlaylist(
              name: '',
              creationDate: DateTime(2020),
              joiner: SmartJoiner.defaultForGroups,
              sorting: const SortChain([]),
              moods: [],
              ruleGroups: [SmartPlaylistRuleGroup.create(rules: rules)],
              limit: null,
            ),
          );
    NamidaNavigator.inst.navigateDialog(
      dialog: CreateSmartPlaylistDialog.forTempSmartSearch(
        initialSmartPlaylistWrapper: wrapper,
        completer: Completer(),
      ),
    );
    await frames(tester);
    addTearDown(() async {
      NamidaNavigator.inst.closeAllDialogs();
      await frames(tester, 40);
    });
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text).last;
    await tester.ensureVisible(finder);
    await frames(tester, 3);
    await tester.tap(finder);
    await frames(tester);
  }

  Future<void> addRule(WidgetTester tester, SmartPlaylistRuleFilterSource source) async {
    await tapText(tester, lang.addRule);
    await tapText(tester, source.toText());
  }

  Future<void> changeSource(WidgetTester tester, SmartPlaylistRuleFilterSource source) async {
    await tapText(tester, lang.source);
    await tapText(tester, source.toText());
  }

  Future<void> pickFilter(WidgetTester tester, SmartPlaylistRuleFilter filter) async {
    await tapText(tester, lang.filterType);
    await tapText(tester, filter.toText());
  }

  Finder valueField() => find.byType(TextField).first;

  Future<String> typeKeys(WidgetTester tester, String text) async {
    for (int i = 0; i <= text.length; i++) {
      await tester.enterText(valueField(), text.substring(0, i));
      await frames(tester, 2);
    }
    return tester.widget<TextField>(valueField()).controller!.text;
  }

  Future<void> addLiteral(WidgetTester tester, String text) async {
    await tester.enterText(valueField(), text);
    await frames(tester, 2);
    await tester.tap(find.byIcon(Broken.add_square).last);
    await frames(tester, 2);
  }

  bool isRuleDialogOpen() => find.text(lang.rule).evaluate().isNotEmpty;

  group('number slider', () {
    testWidgets('typed values stay as typed', (tester) async {
      await openDialog(tester);
      await addRule(tester, SmartPlaylistRuleFilterNumberSource.sampleRate);
      expect(await typeKeys(tester, '22050'), '22050');
      expect(await typeKeys(tester, '11025'), '11025');
      await changeSource(tester, SmartPlaylistRuleFilterNumberSource.durationMS);
      expect(await typeKeys(tester, '4000'), '4000');
    });

    testWidgets('clearing the field keeps it empty', (tester) async {
      await openDialog(tester);
      await addRule(tester, SmartPlaylistRuleFilterNumberSource.rating);
      expect(await typeKeys(tester, '50'), '50');
      await tester.enterText(valueField(), '');
      await frames(tester, 2);
      expect(tester.widget<TextField>(valueField()).controller!.text, '');
    });
  });

  group('text tokens', () {
    testWidgets('switching to exists saves without the old tokens', (tester) async {
      await openDialog(tester);
      await addRule(tester, SmartPlaylistRuleFilterTextSource.title);
      await addLiteral(tester, 'foo');
      await tester.enterText(valueField(), 'bar');
      await pickFilter(tester, SmartPlaylistRuleFilterText.exists);
      await tapText(tester, lang.add);
      expect(isRuleDialogOpen(), isFalse);
      expect(find.text(SmartPlaylistRuleFilterText.exists.toText()), findsOneWidget);
    });

    testWidgets('tokens survive a filter round trip but not a source change', (tester) async {
      await openDialog(tester);
      await addRule(tester, SmartPlaylistRuleFilterTextSource.title);
      await addLiteral(tester, 'foo');
      await pickFilter(tester, SmartPlaylistRuleFilterText.exists);
      await pickFilter(tester, SmartPlaylistRuleFilterText.contains);
      expect(find.text('"foo"'), findsOneWidget);
      await changeSource(tester, SmartPlaylistRuleFilterTextSource.artist);
      expect(find.text('"foo"'), findsNothing);
    });
  });

  testWidgets('a year can be typed alone', (tester) async {
    await openDialog(tester);
    await addRule(tester, SmartPlaylistRuleFilterDateTimeSource.year);
    await pickFilter(tester, SmartPlaylistRuleFilterDateTime.isSame);
    await tester.enterText(valueField(), '2019');
    await tapText(tester, lang.add);
    expect(isRuleDialogOpen(), isFalse);
    expect(find.text('${SmartPlaylistRuleFilterDateTime.isSame.toText()}: = 2019'), findsOneWidget);
  });

  group('date parts', () {
    Future<void> toggleParts(WidgetTester tester, List<SmartPlaylistDatePart> parts) async {
      await tapText(tester, lang.compareBy);
      for (final part in parts) {
        await tester.tap(find.text(part.toText()).last);
        await frames(tester, 3);
      }
      NamidaNavigator.inst.popMenu();
      await frames(tester);
    }

    Future<void> addSameDateRule(WidgetTester tester) async {
      await addRule(tester, SmartPlaylistRuleFilterDateTimeSource.dateAdded);
      await pickFilter(tester, SmartPlaylistRuleFilterDateTime.isSame);
    }

    String sameText(String value) => '${SmartPlaylistRuleFilterDateTime.isSame.toText()}: = $value';

    testWidgets('a month of any year', (tester) async {
      await openDialog(tester);
      await addSameDateRule(tester);
      await toggleParts(tester, const [.year, .day]);
      await tester.enterText(valueField(), '12');
      await tapText(tester, lang.add);
      expect(isRuleDialogOpen(), isFalse);
      expect(find.text(sameText(SmartPlaylistDatePartsValue.monthToText(12))), findsOneWidget);
    });

    testWidgets('a weekday replaces the day', (tester) async {
      await openDialog(tester);
      await addSameDateRule(tester);
      await toggleParts(tester, const [.weekday, .year, .month]);
      await tester.tap(valueField());
      await frames(tester);
      await tapText(tester, SmartPlaylistDatePartsValue.weekdayToText(DateTime.friday));
      await tapText(tester, lang.add);
      expect(isRuleDialogOpen(), isFalse);
      expect(find.text(sameText(SmartPlaylistDatePartsValue.weekdayToText(DateTime.friday))), findsOneWidget);
    });

    testWidgets('turning the clock on keeps the typed date', (tester) async {
      await openDialog(tester);
      await addSameDateRule(tester);
      await tester.enterText(valueField(), '2019-05-14');
      await frames(tester, 2);
      await toggleParts(tester, const [.time]);
      expect(tester.widget<TextField>(valueField()).controller!.text, '2019-05-14');
      await tapText(tester, lang.add);
      expect(isRuleDialogOpen(), isFalse);
    });

    testWidgets('now instead of a typed date', (tester) async {
      await openDialog(tester);
      await addSameDateRule(tester);
      await tester.tap(find.byIcon(Broken.timer_1).first);
      await frames(tester, 3);
      await tapText(tester, lang.add);
      expect(isRuleDialogOpen(), isFalse);
      expect(find.text(sameText('${lang.now} (${lang.days})')), findsOneWidget);
    });
  });

  testWidgets('editing a rule without changes closes quietly', (tester) async {
    final rule = SmartPlaylistRuleNumber(
      data: 50,
      data2: null,
      filter: SmartPlaylistRuleFilterNumber.isGreaterThan,
      source: SmartPlaylistRuleFilterNumberSource.rating,
      enableCleanup: false,
    );
    await openDialog(tester, rules: [rule]);
    await tapText(tester, rule.sourceDisplayText());
    await tapText(tester, lang.edit);
    expect(isRuleDialogOpen(), isFalse);
    expect(find.textContaining(lang.ruleAlreadyExists), findsNothing);
  });

  testWidgets('editing a rule keeps its filter when changing the source', (tester) async {
    final rule = SmartPlaylistRuleNumber(
      data: 20,
      data2: 80,
      filter: SmartPlaylistRuleFilterNumber.isBetween,
      source: SmartPlaylistRuleFilterNumberSource.rating,
      enableCleanup: false,
    );
    await openDialog(tester, rules: [rule]);
    await tapText(tester, rule.sourceDisplayText());
    await changeSource(tester, SmartPlaylistRuleFilterNumberSource.totalListens);
    expect(find.text(SmartPlaylistRuleFilterNumber.isBetween.toText()), findsOneWidget);
  });
}
