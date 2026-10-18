import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:namida/core/ntheme.dart';
import 'package:namida/core/themes.dart';

void main() {
  final themeRed = AppThemes.inst.getAppTheme(const Color(0xFFFF0000), true);
  final themeBlue = AppThemes.inst.getAppTheme(const Color(0xFF0000FF), true);
  final themeDark = AppThemes.inst.getAppTheme(const Color(0xFF0000FF), false);

  Widget app(ValueNotifier<ThemeData> theme, Widget child) {
    return MaterialApp(
      home: ValueListenableBuilder(
        valueListenable: theme,
        builder: (context, data, child) => NTheme(
          data: data,
          child: child!,
        ),
        child: Material(
          child: child,
        ),
      ),
    );
  }

  testWidgets('colors interpolate to the new theme and settle on its exact values', (tester) async {
    final theme = ValueNotifier(themeRed);
    late BuildContext leafContext;
    await tester.pumpWidget(
      app(
        theme,
        Builder(
          builder: (context) {
            leafContext = context;
            NColorsData.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(NColorsData.of(leafContext).get(.card), themeRed.cardColor);

    theme.value = themeBlue;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 125));
    final midway = NColorsData.of(leafContext).get(.card);
    expect(midway, isNot(themeRed.cardColor));
    expect(midway, isNot(themeBlue.cardColor));

    await tester.pumpAndSettle();
    expect(NColorsData.of(leafContext).get(.card), themeBlue.cardColor);
    expect(NColorsData.of(leafContext).get(.primary), themeBlue.colorScheme.primary);
  });

  testWidgets('NamidaText color interpolates on dark/light switch and ends on the theme style', (tester) async {
    final theme = ValueNotifier(themeBlue);
    await tester.pumpWidget(app(theme, const NamidaText('a', style: NText.medium)));
    Color? textColor() => tester.widget<Text>(find.byType(Text)).style?.color;
    expect(textColor(), themeBlue.textTheme.displayMedium!.color);

    theme.value = themeDark;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 125));
    expect(textColor(), isNot(themeBlue.textTheme.displayMedium!.color));
    expect(textColor(), isNot(themeDark.textTheme.displayMedium!.color));

    await tester.pumpAndSettle();
    final resolved = tester.widget<Text>(find.byType(Text)).style;
    expect(resolved, Theme.of(tester.element(find.byType(Text))).textTheme.displayMedium);
  });

  testWidgets('hidden subtrees keep their colors until shown again', (tester) async {
    final theme = ValueNotifier(themeRed);
    final isHiddenVisible = ValueNotifier(false);
    var hiddenBuilds = 0;
    Color? hiddenCard;
    await tester.pumpWidget(
      app(
        theme,
        ValueListenableBuilder(
          valueListenable: isHiddenVisible,
          builder: (context, visible, child) => TickerMode(
            enabled: visible,
            child: child!,
          ),
          child: NThemeFrozenWhileHidden(
            child: Builder(
              builder: (context) {
                hiddenBuilds++;
                hiddenCard = NColorsData.of(context).get(.card);
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    final buildsBefore = hiddenBuilds;
    theme.value = themeBlue;
    await tester.pumpAndSettle();
    expect(hiddenBuilds, buildsBefore);
    expect(hiddenCard, themeRed.cardColor);

    isHiddenVisible.value = true;
    await tester.pumpAndSettle();
    expect(hiddenCard, themeBlue.cardColor);
  });

  test('every theme override goes through NTheme', () {
    final rawTheme = RegExp(r'(^|[^a-zA-Z.])Theme\(');
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final path = file.path.replaceAll('\\', '/');
      if (path.endsWith('lib/core/ntheme.dart')) continue;
      final count = rawTheme.allMatches(file.readAsStringSync()).length;
      // -- the compiled out legacy theme lerp
      final allowed = path.endsWith('lib/ui/pages/main_page.dart') ? 2 : 0;
      if (count != allowed) offenders.add('$path: $count');
    }
    expect(offenders, isEmpty);
  });
}
