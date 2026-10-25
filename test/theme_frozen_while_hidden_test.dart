import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:namida/core/ntheme.dart';
import 'package:namida/ui/widgets/animated_widgets.dart';

void main() {
  testWidgets('hidden subtree keeps its theme until visible again', (tester) async {
    final themeA = ThemeData(colorSchemeSeed: Colors.red);
    final themeB = ThemeData(colorSchemeSeed: Colors.blue);
    final appTheme = ValueNotifier(themeA);
    final isHiddenVisible = ValueNotifier(false);
    var visibleBuilds = 0;
    var hiddenBuilds = 0;
    Color? hiddenPrimary;

    // -- the app sits under MaterialApp's static theme, which nested themes take their cupertino theme from.
    await tester.pumpWidget(
      Theme(
        data: ThemeData(),
        child: ValueListenableBuilder(
          valueListenable: appTheme,
          builder: (context, theme, child) => NTheme(
            data: theme,
            child: child!,
          ),
          child: Column(
            children: [
              Builder(
                builder: (context) {
                  visibleBuilds++;
                  Theme.of(context);
                  return const SizedBox();
                },
              ),
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
                      hiddenPrimary = Theme.of(context).colorScheme.primary;
                      return const SizedBox();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(hiddenPrimary, themeA.colorScheme.primary);
    final hiddenBuildsBefore = hiddenBuilds;
    final visibleBuildsBefore = visibleBuilds;

    appTheme.value = themeB;
    await tester.pump();
    expect(visibleBuilds, visibleBuildsBefore + 1);
    expect(hiddenBuilds, hiddenBuildsBefore);
    expect(hiddenPrimary, themeA.colorScheme.primary);

    isHiddenVisible.value = true;
    await tester.pump();
    expect(hiddenBuilds, hiddenBuildsBefore + 1);
    expect(hiddenPrimary, themeB.colorScheme.primary);
  });

  testWidgets('theme colors jump when a hidden subtree is shown again, and animate while visible', (tester) async {
    final themeA = ThemeData(colorSchemeSeed: Colors.red);
    final themeB = ThemeData(colorSchemeSeed: Colors.blue);
    final themeC = ThemeData(colorSchemeSeed: Colors.green);
    final innerThemes = {
      themeA.colorScheme.primary: ThemeData(colorSchemeSeed: Colors.orange),
      themeB.colorScheme.primary: ThemeData(colorSchemeSeed: Colors.purple),
      themeC.colorScheme.primary: ThemeData(colorSchemeSeed: Colors.teal),
    };
    final appTheme = ValueNotifier(themeA);
    final isHiddenVisible = ValueNotifier(true);
    Color? innerPrimary;

    await tester.pumpWidget(
      Theme(
        data: ThemeData(),
        child: ValueListenableBuilder(
          valueListenable: appTheme,
          builder: (context, theme, child) => NTheme(
            data: theme,
            child: child!,
          ),
          child: ValueListenableBuilder(
            valueListenable: isHiddenVisible,
            builder: (context, visible, child) => TickerMode(
              enabled: visible,
              child: child!,
            ),
            child: NThemeFrozenWhileHidden(
              child: Column(
                children: [
                  Builder(
                    builder: (context) {
                      final primary = NColorsData.targetOf(context).primary;
                      return AnimatedDecoration(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(color: primary),
                        child: const SizedBox(
                          height: 10.0,
                        ),
                      );
                    },
                  ),
                  Builder(
                    builder: (context) {
                      final primary = NColorsData.targetOf(context).primary;
                      return AnimatedContainer(
                        duration: NColorsData.targetDurationOf(context, const Duration(milliseconds: 300)),
                        height: 10.0,
                        decoration: BoxDecoration(color: primary),
                      );
                    },
                  ),
                  Builder(
                    builder: (context) {
                      final outerPrimary = Theme.of(context).colorScheme.primary;
                      return NTheme(
                        data: innerThemes[outerPrimary]!,
                        child: Builder(
                          builder: (context) {
                            innerPrimary = NColorsData.of(context).primary;
                            return const SizedBox();
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Color? decorationColorOf(Type type) {
      final finder = find.descendant(of: find.byType(type), matching: find.byType(DecoratedBox));
      final box = tester.widget<DecoratedBox>(finder.first);
      final decoration = box.decoration as BoxDecoration;
      return decoration.color;
    }

    void expectColorsOf(ThemeData theme, {bool isSettled = true}) {
      final primary = theme.colorScheme.primary;
      final innerTheme = innerThemes[primary]!;
      final innerThemePrimary = innerTheme.colorScheme.primary;
      final outerMatcher = isSettled ? equals(primary) : isNot(primary);
      final innerMatcher = isSettled ? equals(innerThemePrimary) : isNot(innerThemePrimary);
      expect(decorationColorOf(AnimatedDecoration), outerMatcher);
      expect(decorationColorOf(AnimatedContainer), outerMatcher);
      expect(innerPrimary, innerMatcher);
    }

    expectColorsOf(themeA);

    isHiddenVisible.value = false;
    await tester.pump();
    appTheme.value = themeB;
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expectColorsOf(themeA);

    isHiddenVisible.value = true;
    await tester.pump();
    expectColorsOf(themeB);
    await tester.pump(const Duration(milliseconds: 100));
    expectColorsOf(themeB);

    appTheme.value = themeC;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expectColorsOf(themeC, isSettled: false);
    await tester.pump(const Duration(seconds: 1));
    expectColorsOf(themeC);
  });
}
