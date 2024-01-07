import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/extensions.dart';

class AppThemes {
  static AppThemes get inst => _instance;
  static final AppThemes _instance = AppThemes._internal();
  AppThemes._internal();

  ThemeData getAppTheme([Color? color, bool? light, bool lighterDialog = true]) {
    color ??= CurrentColor.inst.color;
    light ??= Get.theme.brightness == Brightness.light;

    final shouldUseAMOLED = !light && settings.pitchBlack.value;
    final pitchBlack = shouldUseAMOLED ? const Color.fromARGB(255, 0, 0, 0) : null;
    final mainColorMultiplier = pitchBlack == null ? 0.8 : 0.1; // makes colors that rely on mainColor, a bit darker.
    final pitchGrey = pitchBlack == null ? const Color.fromARGB(255, 35, 35, 35) : const Color.fromARGB(255, 20, 20, 20);

    int getColorAlpha(int a) => (a * mainColorMultiplier).round();
    Color getMainColorWithAlpha(int a) => color!.withAlpha(getColorAlpha(a));

    final cardTheme = CardTheme(
      elevation: 12.0,
      color: Color.alphaBlend(
        getMainColorWithAlpha(45),
        light ? const Color.fromARGB(255, 255, 255, 255) : pitchGrey,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14.0.multipliedRadius),
      ),
    );

    final cardColor = Color.alphaBlend(
      getMainColorWithAlpha(35),
      light ? const Color.fromARGB(255, 255, 255, 255) : pitchGrey,
    );

    return ThemeData(
      brightness: light ? Brightness.light : Brightness.dark,
      useMaterial3: true,
      colorSchemeSeed: color,
      fontFamily: "LexendDeca",
      scaffoldBackgroundColor: pitchBlack ?? (light ? Color.alphaBlend(color.withAlpha(60), Colors.white) : null),
      splashColor: Colors.transparent,
      splashFactory: InkRipple.splashFactory,
      highlightColor: light ? Colors.black.withAlpha(20) : Colors.white.withAlpha(pitchBlack == null ? 10 : 25),
      disabledColor: light ? const Color.fromARGB(200, 160, 160, 160) : const Color.fromARGB(200, 60, 60, 60),
      applyElevationOverlayColor: false,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: pitchBlack ?? (light ? Color.alphaBlend(color.withAlpha(25), Colors.white) : null),
        actionsIconTheme: IconThemeData(
          color: light ? const Color.fromARGB(200, 40, 40, 40) : const Color.fromARGB(200, 233, 233, 233),
        ),
      ),
      secondaryHeaderColor: light ? const Color.fromARGB(200, 240, 240, 240) : const Color.fromARGB(222, 10, 10, 10),
      navigationBarTheme: pitchBlack == null
          ? null
          : NavigationBarThemeData(
              backgroundColor: pitchBlack,
              surfaceTintColor: pitchBlack,
              indicatorColor: Color.alphaBlend(color.withAlpha(120), pitchBlack),
            ),
      iconTheme: IconThemeData(
        color: light ? const Color.fromARGB(200, 40, 40, 40) : const Color.fromARGB(200, 233, 233, 233),
      ),
      shadowColor: light ? const Color.fromARGB(180, 100, 100, 100) : const Color.fromARGB(222, 10, 10, 10),
      dividerTheme: const DividerThemeData(
        thickness: 4,
        indent: 0.0,
        endIndent: 0.0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: light
              ? Color.alphaBlend(getMainColorWithAlpha(30), Colors.white)
              : pitchBlack != null
                  ? Color.alphaBlend(getMainColorWithAlpha(40), const Color.fromARGB(222, 10, 10, 10))
                  : null,
        ),
      ),
      dialogBackgroundColor: lighterDialog
          ? light
              ? Color.alphaBlend(getMainColorWithAlpha(60), Colors.white)
              : Color.alphaBlend(getMainColorWithAlpha(20), pitchBlack ?? const Color.fromARGB(255, 12, 12, 12))
          : light
              ? Color.alphaBlend(getMainColorWithAlpha(35), Colors.white)
              : Color.alphaBlend(getMainColorWithAlpha(12), pitchBlack ?? const Color.fromARGB(255, 16, 16, 16)),
      focusColor: light ? const Color.fromARGB(200, 190, 190, 190) : const Color.fromARGB(150, 80, 80, 80),
      dialogTheme: DialogTheme(surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0.multipliedRadius))),
      listTileTheme: ListTileThemeData(
        horizontalTitleGap: 16.0,
        selectedColor: light
            ? Color.alphaBlend(getMainColorWithAlpha(40), const Color.fromARGB(255, 182, 182, 182))
            : Color.alphaBlend(getMainColorWithAlpha(40), pitchBlack ?? const Color.fromARGB(255, 55, 55, 55)),
        iconColor: Color.alphaBlend(
          getMainColorWithAlpha(80),
          light ? const Color.fromARGB(200, 55, 55, 55) : const Color.fromARGB(255, 228, 228, 228),
        ),
        textColor: Color.alphaBlend(
          getMainColorWithAlpha(80),
          light ? const Color.fromARGB(200, 55, 55, 55) : const Color.fromARGB(255, 228, 228, 228),
        ),
      ),
      dividerColor: light ? const Color.fromARGB(100, 100, 100, 100) : const Color.fromARGB(200, 50, 50, 50),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: light
              ? Color.alphaBlend(getMainColorWithAlpha(30), const Color.fromARGB(255, 242, 242, 242))
              : Color.alphaBlend(getMainColorWithAlpha(80), const Color.fromARGB(255, 12, 12, 12)),
          borderRadius: BorderRadius.circular(10.0.multipliedRadius),
          boxShadow: const [
            BoxShadow(
              color: Color.fromARGB(70, 12, 12, 12),
              blurRadius: 6.0,
              offset: Offset(0, 2),
            )
          ],
        ),
        textStyle: TextStyle(
          color: light ? const Color.fromARGB(244, 55, 55, 55) : const Color.fromARGB(255, 228, 228, 228),
        ),
        waitDuration: const Duration(seconds: 1),
      ),
      cardColor: cardColor,
      cardTheme: cardTheme,
      popupMenuTheme: PopupMenuThemeData(
        surfaceTintColor: Colors.transparent,
        elevation: 12.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0.multipliedRadius),
        ),
        color: light ? Color.alphaBlend(cardColor.withAlpha(180), Colors.white) : Color.alphaBlend(cardColor.withAlpha(180), Colors.black),
      ),
      textTheme: TextTheme(
        bodyMedium: TextStyle(
          fontSize: 14.0.multipliedFontScale,
          fontWeight: FontWeight.normal,
        ),
        bodySmall: TextStyle(
          fontSize: 14.0.multipliedFontScale,
          fontWeight: FontWeight.normal,
        ),
        titleSmall: TextStyle(
          fontSize: 14.0.multipliedFontScale,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          fontSize: 20.0.multipliedFontScale,
          fontWeight: FontWeight.w600,
        ),
        displayLarge: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 17.0.multipliedFontScale,
          color: light ? Colors.black.withAlpha(160) : Colors.white.withAlpha(210),
        ),
        displayMedium: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15.0.multipliedFontScale,
          color: light ? Colors.black.withAlpha(150) : Colors.white.withAlpha(180),
        ),
        displaySmall: TextStyle(
          fontWeight: FontWeight.w400,
          fontSize: 13.0.multipliedFontScale,
          color: light ? Colors.black.withAlpha(120) : Colors.white.withAlpha(170),
        ),
        headlineMedium: TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 14.0.multipliedFontScale,
        ),
        headlineSmall: TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 14.0.multipliedFontScale,
        ),
      ),
    );
  }
}
