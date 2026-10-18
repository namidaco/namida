import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:namida/core/extensions.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

void main() {
  const seeds = [
    Color(0xFF000000), Color(0xFFFFFFFF), Color(0xFF808080), Color(0xFFFF0000), Color(0xFF00FF00), //
    Color(0xFF0000FF), Color(0xFF9C27B0), Color(0xFFFFC107), Color(0x40E91E63), Color(0xC8795548), //
    Color(0xFF263238), Color(0xFFB3E5FC), Color(0x00123456), Color(0xFF7F00FF), Color(0xFF3D5AFE), //
  ];
  const locales = [Locale('en'), Locale('ja'), Locale('th')];

  Future<void> pumpThemed(WidgetTester tester, ThemeData theme, Locale locale, WidgetBuilder builder) {
    return tester.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: locales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Theme(
          data: theme,
          child: Material(
            child: Builder(builder: builder),
          ),
        ),
      ),
    );
  }

  Map<NColorRole, Color> legacyColorsOf(ThemeData theme) => {
    NColorRole.card: theme.cardColor,
    NColorRole.cardTheme: theme.cardTheme.color!,
    NColorRole.scaffold: theme.scaffoldBackgroundColor,
    NColorRole.surface: theme.colorScheme.surface,
    NColorRole.surfaceContainer: theme.colorScheme.surfaceContainer,
    NColorRole.onSurface: theme.colorScheme.onSurface,
    NColorRole.primary: theme.colorScheme.primary,
    NColorRole.onPrimary: theme.colorScheme.onPrimary,
    NColorRole.primaryContainer: theme.colorScheme.primaryContainer,
    NColorRole.secondary: theme.colorScheme.secondary,
    NColorRole.onSecondary: theme.colorScheme.onSecondary,
    NColorRole.secondaryContainer: theme.colorScheme.secondaryContainer,
    NColorRole.onSecondaryContainer: theme.colorScheme.onSecondaryContainer,
    NColorRole.tertiary: theme.colorScheme.tertiary,
    NColorRole.error: theme.colorScheme.error,
    NColorRole.shadow: theme.shadowColor,
    NColorRole.highlight: theme.highlightColor,
    NColorRole.focus: theme.focusColor,
    NColorRole.divider: theme.dividerColor,
    NColorRole.disabled: theme.disabledColor,
    NColorRole.secondaryHeader: theme.secondaryHeaderColor,
    NColorRole.dialogBackground: theme.dialogTheme.backgroundColor!,
    NColorRole.listTileIcon: theme.listTileTheme.iconColor!,
    NColorRole.listTileText: theme.listTileTheme.textColor!,
    NColorRole.icon: theme.iconTheme.color!,
    NColorRole.textLarge: theme.textTheme.displayLarge!.color!,
    NColorRole.textMedium: theme.textTheme.displayMedium!.color!,
    NColorRole.textSmall: theme.textTheme.displaySmall!.color!,
  };

  testWidgets('every color role equals the theme field it replaces', (tester) async {
    for (final seed in seeds) {
      for (final light in [true, false]) {
        final appTheme = AppThemes.inst.getAppTheme(seed, light);
        await pumpThemed(tester, appTheme, locales.first, (context) {
          final theme = Theme.of(context);
          final colors = NColorsData.of(context);
          final legacy = legacyColorsOf(theme);
          expect(legacy.length, NColorRole.values.length);
          for (final role in NColorRole.values) {
            expect(colors.get(role), legacy[role], reason: '$role, seed $seed, light $light');
            expect(NColors(role, opacity: 0.35).resolve(colors), legacy[role]!.withOpacityExt(0.35));
          }
          return const SizedBox();
        });
      }
    }
  });

  testWidgets('text styles equal the theme styles they replace, per script and brightness', (tester) async {
    const sizes = [null, NTextSize.s11, NTextSize.s13p5];
    const weights = [null, FontWeight.w500, FontWeight.w700];
    for (final locale in locales) {
      for (final light in [true, false]) {
        final appTheme = AppThemes.inst.getAppTheme(seeds[6], light);
        await pumpThemed(tester, appTheme, locale, (context) {
          final textTheme = Theme.of(context).textTheme;
          final bases = {
            NTextRole.large: textTheme.displayLarge!,
            NTextRole.medium: textTheme.displayMedium!,
            NTextRole.small: textTheme.displaySmall!,
          };
          for (final role in NTextRole.values) {
            for (final size in sizes) {
              for (final weight in weights) {
                final expected = size == null && weight == null ? bases[role]! : bases[role]!.copyWith(fontSize: size?.value, fontWeight: weight);
                expect(
                  NText(role, size: size, weight: weight).of(context),
                  expected,
                  reason: '$role $size $weight $locale $light',
                );
              }
            }
          }
          return const SizedBox();
        });
      }
    }
  });

  testWidgets('NamidaText renders the same paragraph as Text', (tester) async {
    final appTheme = AppThemes.inst.getAppTheme(seeds[3], true);
    await pumpThemed(tester, appTheme, locales.first, (context) {
      final textTheme = Theme.of(context).textTheme;
      return Column(
        children: [
          Text(
            'a',
            key: const Key('old'),
            style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
          const NamidaText(
            'a',
            key: Key('new'),
            style: NText(.small, weight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    });
    final oldP = tester.renderObject<RenderParagraph>(find.descendant(of: find.byKey(const Key('old')), matching: find.byType(RichText)));
    final newP = tester.renderObject<RenderParagraph>(find.descendant(of: find.byKey(const Key('new')), matching: find.byType(RichText)));
    expect(newP.text, oldP.text);
    expect(newP.textAlign, oldP.textAlign);
    expect(newP.overflow, oldP.overflow);
    expect(newP.softWrap, oldP.softWrap);
    expect(newP.maxLines, oldP.maxLines);
    expect(newP.textScaler, oldP.textScaler);
    expect(newP.locale, oldP.locale);
    expect(newP.strutStyle, oldP.strutStyle);
    expect(newP.textWidthBasis, oldP.textWidthBasis);
    expect(newP.textHeightBehavior, oldP.textHeightBehavior);
    expect(newP.selectionColor, oldP.selectionColor);
  });

  testWidgets('NamidaInkWell with a color role paints the same as with the theme color', (tester) async {
    for (final light in [true, false]) {
      final appTheme = AppThemes.inst.getAppTheme(seeds[7], light);
      await pumpThemed(tester, appTheme, locales.first, (context) {
        final theme = Theme.of(context);
        return Column(
          children: [
            NamidaInkWell(
              key: const Key('old'),
              bgColor: NColors.fixed(theme.cardColor),
              onTap: () {},
              child: const SizedBox(height: 10.0),
            ),
            NamidaInkWell(
              key: const Key('new'),
              bgColor: NColors.card,
              onTap: () {},
              child: const SizedBox(height: 10.0),
            ),
          ],
        );
      });
      List<Decoration> decorationsOf(String key) => tester
          .renderObjectList<RenderDecoratedBox>(find.descendant(of: find.byKey(Key(key)), matching: find.byWidgetPredicate((w) => w is DecoratedBox)))
          .map((e) => e.decoration)
          .toList();
      InkWell inkWellOf(String key) => tester.widget<InkWell>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(InkWell)));
      expect(decorationsOf('new'), decorationsOf('old'));
      expect(decorationsOf('new'), isNotEmpty);
      expect(inkWellOf('new').highlightColor, inkWellOf('old').highlightColor);
      expect(inkWellOf('new').hoverColor, inkWellOf('old').hoverColor);
    }
  });

  testWidgets('NDecoratedBox paints the decoration built from the theme', (tester) async {
    final appTheme = AppThemes.inst.getAppTheme(seeds[1], false);
    late BoxDecoration legacy;
    await pumpThemed(tester, appTheme, locales.first, (context) {
      legacy = BoxDecoration(color: Theme.of(context).shadowColor.withOpacityExt(0.08));
      return NDecoratedBox(
        decoration: (colors) => BoxDecoration(color: colors.shadow.withOpacityExt(0.08)),
        child: const SizedBox(height: 10.0),
      );
    });
    expect(tester.renderObject<RenderDecoratedBox>(find.byType(DecoratedBox)).decoration, legacy);
  });
}
