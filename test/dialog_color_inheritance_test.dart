import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:namida/class/lang.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';

void main() {
  late Directory root;

  setUpAll(() {
    root = Directory.systemTemp.createTempSync('namida_dialog_color_test');
    AppDirs.USER_DATA = '${p.join(root.path, 'user_data')}${Platform.pathSeparator}';
    Language.inst.update(language: NamidaLanguage.fromCode('en'));
  });
  tearDownAll(() {
    try {
      root.deleteSync(recursive: true);
    } catch (_) {} // -- settings writes can still hold the files
  });

  const red = Color(0xFFE53935);
  const blue = Color(0xFF1E88E5);

  Future<BuildContext> pumpApp(WidgetTester tester) async {
    late BuildContext pageContext;
    final theme = AppThemes.inst.getAppTheme(null, true);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: namida.rootNavigatorKey,
        theme: theme,
        home: NTheme(
          data: theme,
          child: Builder(
            builder: (context) {
              pageContext = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    return pageContext;
  }

  Future<BuildContext> openDialog(WidgetTester tester, {Color? colorScheme, Color? ownThemeColor}) async {
    late BuildContext dialogContext;
    final content = Builder(
      builder: (context) {
        dialogContext = context;
        return const SizedBox();
      },
    );
    NamidaNavigator.inst.navigateDialog(
      colorScheme: colorScheme,
      dialog: ownThemeColor == null
          ? content
          : NamidaDialogTheme(
              data: AppThemes.inst.getAppTheme(ownThemeColor, null, false),
              child: content,
            ),
    );
    await tester.pumpAndSettle();
    return dialogContext;
  }

  Future<BuildContext> openSheet(WidgetTester tester) async {
    late BuildContext sheetContext;
    NamidaNavigator.inst.showSheet(
      builder: (context, bottomPadding, maxWidth, maxHeight) => Builder(
        builder: (context) {
          sheetContext = context;
          return const SizedBox(height: 50.0);
        },
      ),
    );
    await tester.pumpAndSettle();
    return sheetContext;
  }

  Future<void> closeAll(WidgetTester tester) async {
    NamidaNavigator.inst.closeAllDialogs();
    await tester.pumpAndSettle();
  }

  testWidgets('pages and plain dialogs follow the app color', (tester) async {
    final pageContext = await pumpApp(tester);
    expect(NamidaNavigator.dialogColorOf(pageContext), isNull);
    expect(NamidaNavigator.inheritedColorOf(pageContext), CurrentColor.inst.color);

    final plainContext = await openDialog(tester);
    expect(NamidaNavigator.dialogColorOf(plainContext), isNull);
    expect(NamidaNavigator.inst.inheritedColor, CurrentColor.inst.color);

    final nestedPlainContext = await openDialog(tester);
    expect(NamidaNavigator.dialogColorOf(nestedPlainContext), isNull);

    final sheetContext = await openSheet(tester);
    expect(NamidaNavigator.dialogColorOf(sheetContext), isNull);
    expect(Theme.of(sheetContext).extension<NThemeAccent>()?.color, Theme.of(pageContext).extension<NThemeAccent>()?.color);

    namida.rootNavigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    await closeAll(tester);
    expect(NamidaNavigator.inst.openedDialogsCount, 0);
  });

  testWidgets('nested dialogs and sheets inherit a colored dialog', (tester) async {
    await pumpApp(tester);

    final redContext = await openDialog(tester, colorScheme: red);
    expect(NamidaNavigator.dialogColorOf(redContext), red);

    final nestedContext = await openDialog(tester);
    expect(NamidaNavigator.dialogColorOf(nestedContext), red);
    expect(Theme.of(nestedContext).extension<NThemeAccent>()?.color, red);

    final sheetContext = await openSheet(tester);
    expect(NamidaNavigator.dialogColorOf(sheetContext), red);
    expect(Theme.of(sheetContext).extension<NThemeAccent>()?.color, red);
    namida.rootNavigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    NamidaNavigator.inst.closeDialog();
    await tester.pumpAndSettle();
    expect(NamidaNavigator.inst.inheritedColor, red);

    NamidaNavigator.inst.closeDialog();
    expect(NamidaNavigator.inst.inheritedColor, CurrentColor.inst.color, reason: 'closing removes the color right away');
    await tester.pumpAndSettle();
  });

  testWidgets('a dialog with its own theme passes its color on', (tester) async {
    await pumpApp(tester);

    final ownContext = await openDialog(tester, ownThemeColor: blue);
    expect(NamidaNavigator.dialogColorOf(ownContext), blue);
    expect(NamidaNavigator.inst.inheritedColor, blue);

    final nestedContext = await openDialog(tester);
    expect(NamidaNavigator.dialogColorOf(nestedContext), blue);

    final explicitContext = await openDialog(tester, colorScheme: red);
    expect(NamidaNavigator.dialogColorOf(explicitContext), red);

    await closeAll(tester);
    expect(NamidaNavigator.inst.inheritedColor, CurrentColor.inst.color);
  });

  testWidgets('menus carry the colored dialog scope', (tester) async {
    final pageContext = await pumpApp(tester);
    final child = Container();
    expect(NamidaNavigator.inst.captureDialogTheme(pageContext, child), same(child));

    final plainContext = await openDialog(tester);
    expect(NamidaNavigator.inst.captureDialogTheme(plainContext, child), same(child));

    final redContext = await openDialog(tester, colorScheme: red);
    late BuildContext menuContext;
    final menu = NamidaNavigator.inst.captureDialogTheme(
      redContext,
      Builder(
        builder: (context) {
          menuContext = context;
          return const SizedBox();
        },
      ),
    );
    namida.rootNavigatorKey.currentState!.push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) => menu,
      ),
    );
    await tester.pumpAndSettle();
    expect(NamidaNavigator.dialogColorOf(menuContext), red);
    expect(Theme.of(menuContext).extension<NThemeAccent>()?.color, red);
    namida.rootNavigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    await closeAll(tester);
  });
}
