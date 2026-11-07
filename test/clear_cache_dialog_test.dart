// by claude
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:namida/class/lang.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/clear_cache_dialog.dart';

void main() {
  late Directory root;
  final sep = Platform.pathSeparator;

  setUpAll(() {
    root = Directory.systemTemp.createTempSync('namida_clear_cache_dialog_test');
    AppDirs.USER_DATA = '${root.path}${sep}data$sep';
    AppDirs.APP_CACHE = '${root.path}${sep}cache$sep';
    Language.inst.update(language: NamidaLanguage.fromCode('en'));
  });
  tearDownAll(() {
    try {
      root.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<void> frames(WidgetTester tester, [int count = 15]) async {
    for (int i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openDialog(WidgetTester tester, String videoId) async {
    tester.view.physicalSize = const Size(600, 1300);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final appTheme = AppThemes.inst.getAppTheme(null, true);
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
    await tester.runAsync(() => showClearCacheDialog(videoIds: [videoId]));
    await frames(tester);
    addTearDown(() async {
      NamidaNavigator.inst.closeAllDialogs();
      await frames(tester);
    });
  }

  Future<void> tapDelete(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.tap(find.textContaining('${lang.delete} ('));
      await Future.delayed(const Duration(seconds: 1));
    });
    await frames(tester);
  }

  File writeSubtitle(String videoId, String vssId) {
    return File('${AppDirs.SUBTITLES}${videoId}_$vssId.vtt')
      ..createSync(recursive: true)
      ..writeAsStringSync('WEBVTT');
  }

  testWidgets('nothing cached opens the clean state', (tester) async {
    await openDialog(tester, 'aaaaaaaaaaa');
    expect(find.text(lang.nothingIsCached), findsOneWidget);
    expect(find.text(lang.done), findsOneWidget);
    expect(find.textContaining('${lang.delete} ('), findsNothing);
  });

  testWidgets('deleting everything shows the broom without text, then closes', (tester) async {
    final file = writeSubtitle('bbbbbbbbbbb', '.en');
    await openDialog(tester, 'bbbbbbbbbbb');
    expect(find.text(lang.subtitles), findsOneWidget);

    await tester.tap(find.text('English'));
    await frames(tester, 2);
    await tester.runAsync(() async {
      await tester.tap(find.textContaining('${lang.delete} ('));
      await Future.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    expect(file.existsSync(), false);
    expect(find.text(lang.clear), findsOneWidget);
    expect(find.text(lang.subtitles), findsNothing);
    expect(find.text(lang.nothingIsCached), findsNothing);

    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 600)));
    await frames(tester);
    expect(find.text(lang.clear), findsNothing);
  });

  testWidgets('deleting a part closes the dialog', (tester) async {
    final english = writeSubtitle('ccccccccccc', '.en');
    final french = writeSubtitle('ccccccccccc', '.fr');
    await openDialog(tester, 'ccccccccccc');

    await tester.tap(find.text('English'));
    await frames(tester, 2);
    await tapDelete(tester);

    expect(english.existsSync(), false);
    expect(french.existsSync(), true);
    expect(find.text(lang.clear), findsNothing);
    expect(find.text(lang.nothingIsCached), findsNothing);
  });
}
