import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:namida/class/lang.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/dialogs/color_picker_dialog.dart';

void main() {
  late Directory root;

  setUpAll(() {
    root = Directory.systemTemp.createTempSync('namida_color_picker_test');
    AppDirs.USER_DATA = '${p.join(root.path, 'user_data')}${Platform.pathSeparator}';
    Language.inst.update(language: NamidaLanguage.fromCode('en'));
  });
  tearDownAll(() {
    try {
      root.deleteSync(recursive: true);
    } catch (_) {} // -- settings writes can still hold the files
  });

  Future<({List<Color> settled, List<Color> done})> pumpPicker(
    WidgetTester tester, {
    Color initialColor = const Color(0xFF3F51B5),
    bool isAlphaAllowed = true,
    bool themeFollowsColor = false,
    List<Color> suggestedColors = const [],
  }) async {
    final settled = <Color>[];
    final done = <Color>[];
    tester.view.physicalSize = const Size(400.0, 1000.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final theme = AppThemes.inst.getAppTheme(initialColor, true);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: NTheme(
          data: theme,
          child: Material(
            child: NamidaColorPickerDialog(
              initialColor: initialColor,
              doneText: 'Done',
              cancelButton: false,
              isAlphaAllowed: isAlphaAllowed,
              themeFollowsColor: themeFollowsColor,
              suggestedColors: suggestedColors,
              onColorChangeEnd: settled.add,
              onDonePressed: done.add,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return (settled: settled, done: done);
  }

  testWidgets('dragging the plane settles once at the end', (tester) async {
    final res = await pumpPicker(tester);
    final plane = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_SaturationValuePlane');
    expect(plane, findsOneWidget);
    final rect = tester.getRect(plane);
    final gesture = await tester.startGesture(rect.topLeft + const Offset(5.0, 5.0));
    await tester.pump();
    await gesture.moveTo(rect.center);
    await tester.pump();
    await gesture.moveTo(rect.bottomRight - const Offset(2.0, 2.0));
    await tester.pump();
    expect(res.settled, isEmpty);
    await gesture.up();
    await tester.pump();
    expect(res.settled.length, 1);
    final hsv = HSVColor.fromColor(res.settled.single);
    expect(hsv.value, lessThan(0.05));
  });

  testWidgets('hue survives dragging through black', (tester) async {
    final res = await pumpPicker(tester, initialColor: const Color(0xFF00FF00));
    final plane = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_SaturationValuePlane');
    final rect = tester.getRect(plane);
    await tester.dragFrom(rect.topRight - const Offset(2.0, -2.0), Offset(0.0, rect.height));
    await tester.pump();
    final gesture = await tester.startGesture(rect.topRight + const Offset(-2.0, 2.0));
    await gesture.up();
    await tester.pump();
    final hsv = HSVColor.fromColor(res.settled.last);
    expect(hsv.hue, closeTo(120.0, 2.0));
  });

  testWidgets('hex field accepts short, long and rgb() input', (tester) async {
    final res = await pumpPicker(tester);
    final field = find.byType(EditableText).first;
    await tester.enterText(field, '#f80');
    await tester.pump();
    expect(res.settled.last, const Color(0xFFFF8800));
    await tester.enterText(field, '80112233');
    await tester.pump();
    expect(res.settled.last, const Color(0x80112233));
    await tester.enterText(field, 'rgb(10, 20, 30)');
    await tester.pump();
    expect(res.settled.last, const Color(0x800A141E));
    await tester.enterText(field, 'rgba(10, 20, 30, 1)');
    await tester.pump();
    expect(res.settled.last, const Color(0xFF0A141E));
    await tester.enterText(field, 'zzz');
    await tester.pump();
    expect(res.settled.last, const Color(0xFF0A141E));
    final alphaField = find.byType(EditableText).at(1);
    await tester.enterText(alphaField, '50');
    await tester.pump();
    expect(res.settled.last.a, closeTo(0.5, 0.01));
    expect(tester.widget<EditableText>(field).controller.text, '0A141E');
  });

  testWidgets('no alpha forces opaque colors', (tester) async {
    final res = await pumpPicker(tester, initialColor: const Color(0x803F51B5), isAlphaAllowed: false);
    final field = find.byType(EditableText).first;
    await tester.enterText(field, '80112233');
    await tester.pump();
    expect(res.settled.last, const Color(0xFF112233));
    expect(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_ColorSlider'), findsOneWidget);
  });

  testWidgets('dialog theme follows drags, throttled', (tester) async {
    await pumpPicker(tester, themeFollowsColor: true);
    ThemeData dialogTheme() => tester.widget<NTheme>(find.byType(NTheme).last).data;
    final initialTheme = dialogTheme();
    final plane = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_SaturationValuePlane');
    final rect = tester.getRect(plane);
    final gesture = await tester.startGesture(rect.center);
    await tester.pump();
    final firstDragTheme = dialogTheme();
    expect(identical(firstDragTheme, initialTheme), false);
    await gesture.moveTo(rect.topRight + const Offset(-4.0, 4.0));
    await tester.pump(const Duration(milliseconds: 10));
    expect(identical(dialogTheme(), firstDragTheme), true);
    await tester.pump(const Duration(milliseconds: 100));
    final trailingTheme = dialogTheme();
    expect(identical(trailingTheme, firstDragTheme), false);
    await gesture.up();
    await tester.pump();
    expect(identical(dialogTheme(), trailingTheme), true);
  });

  testWidgets('tapping a suggested swatch picks it, done passes it on', (tester) async {
    const suggested = Color(0xFF123456);
    final res = await pumpPicker(tester, suggestedColors: const [suggested, suggested]);
    final grids = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_SwatchGrid');
    expect(grids, findsNWidgets(3));
    final suggestedGrid = grids.at(1);
    final rect = tester.getRect(suggestedGrid);
    await tester.tapAt(rect.topLeft + const Offset(4.0, 4.0));
    await tester.pump();
    expect(res.settled.last, suggested);
    await tester.tap(find.text('Done'));
    await tester.pump();
    expect(res.done.single, suggested);
  });
}
