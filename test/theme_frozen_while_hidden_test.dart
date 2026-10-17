import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:namida/core/themes.dart';

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
          builder: (context, theme, child) => AppThemeProvider(
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
                child: AppThemeFrozenWhileHidden(
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
}
