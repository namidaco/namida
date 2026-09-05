import 'package:flutter/material.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';

class AppThemes {
  static AppThemes get inst => _instance;
  static final AppThemes _instance = AppThemes._internal();
  AppThemes._internal();

  static const selectedNavigationIconColor = Color.fromRGBO(255, 255, 255, 0.75);

  static const fontFamily = "LexendDeca";
  static const fontFamilyFallback = ['sans-serif', 'Roboto'];

  static const _iconThemeLight = IconThemeData(color: Color.fromARGB(200, 40, 40, 40));
  static const _iconThemeDark = IconThemeData(color: Color.fromARGB(200, 233, 233, 233));

  static const _textButtonThemeDesktop = TextButtonThemeData(
    style: ButtonStyle(
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      ),
      visualDensity: VisualDensity.comfortable,
    ),
  );
  static const _textButtonThemeMobile = TextButtonThemeData(
    style: ButtonStyle(
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
      ),
      visualDensity: VisualDensity.compact,
    ),
  );

  static const _inputDecorationThemeDesktop = InputDecorationTheme(contentPadding: EdgeInsetsDirectional.fromSTEB(12.0, 18.0, 12.0, 18.0));
  static const _inputDecorationThemeMobile = InputDecorationTheme();

  static final _textThemeLight = _buildTextTheme(true);
  static final _textThemeDark = _buildTextTheme(false);

  static TextTheme _buildTextTheme(bool light) {
    return TextTheme(
      bodyMedium: const TextStyle(
        fontSize: 14.0,
        fontWeight: FontWeight.normal,
        fontFamilyFallback: fontFamilyFallback,
      ),
      bodySmall: const TextStyle(
        fontSize: 14.0,
        fontWeight: FontWeight.normal,
        fontFamilyFallback: fontFamilyFallback,
      ),
      titleSmall: const TextStyle(
        fontSize: 14.0,
        fontWeight: FontWeight.w600,
        fontFamilyFallback: fontFamilyFallback,
      ),
      titleLarge: const TextStyle(
        fontSize: 20.0,
        fontWeight: FontWeight.w600,
        fontFamilyFallback: fontFamilyFallback,
      ),
      displayLarge: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 17.0,
        color: light ? Colors.black.withAlpha(160) : Colors.white.withAlpha(210),
        fontFamilyFallback: fontFamilyFallback,
      ),
      displayMedium: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 15.0,
        color: light ? Colors.black.withAlpha(150) : Colors.white.withAlpha(180),
        fontFamilyFallback: fontFamilyFallback,
      ),
      displaySmall: TextStyle(
        fontWeight: FontWeight.w400,
        fontSize: 13.0,
        color: light ? Colors.black.withAlpha(120) : Colors.white.withAlpha(170),
        fontFamilyFallback: fontFamilyFallback,
      ),
      headlineMedium: const TextStyle(
        fontWeight: FontWeight.normal,
        fontSize: 14.0,
        fontFamilyFallback: fontFamilyFallback,
      ),
      headlineSmall: const TextStyle(
        fontWeight: FontWeight.normal,
        fontSize: 14.0,
        fontFamilyFallback: fontFamilyFallback,
      ),
    );
  }

  static const _cacheMaxLength = 20;
  final _cache = <_ThemeCacheKey, ThemeData>{};

  ThemeData getAppTheme([Color? color, bool? light, bool lighterDialog = true]) {
    color ??= CurrentColor.inst.color;
    light ??= namida.brightness == Brightness.light;

    final key = (color, light, lighterDialog, settings.pitchBlack.value, settings.borderRadiusMultiplier.value);
    final cached = _cache.remove(key);
    if (cached != null) return _cache[key] = cached; // -- re-insert to keep it as most recently used

    if (_cache.length >= _cacheMaxLength) _cache.remove(_cache.keys.first);
    return _cache[key] = _buildAppTheme(color, light, lighterDialog);
  }

  ThemeData _buildAppTheme(Color color, bool light, bool lighterDialog) {
    final shouldUseAMOLED = !light && settings.pitchBlack.value;
    final pitchBlack = shouldUseAMOLED ? const Color.fromARGB(255, 0, 0, 0) : null;
    final mainColorMultiplier = pitchBlack == null ? 0.8 : 0.1; // makes colors that rely on mainColor, a bit darker.
    final pitchGrey = pitchBlack == null ? const Color.fromARGB(255, 35, 35, 35) : const Color.fromARGB(255, 20, 20, 20);

    final useDesktopDecoration = isDesktop;

    int getColorAlpha(int a) => (a * mainColorMultiplier).round();
    Color getMainColorWithAlpha(int a) => color.withAlpha(getColorAlpha(a));

    final cardTheme = CardThemeData(
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

    final brightness = light ? Brightness.light : Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: color,
      brightness: brightness,
      contrastLevel: 0.05,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity, // ensure monochrome colors are not modified
    );
    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
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
        actionsIconTheme: light ? _iconThemeLight : _iconThemeDark,
      ),
      secondaryHeaderColor: light ? const Color.fromARGB(200, 240, 240, 240) : const Color.fromARGB(222, 10, 10, 10),
      navigationBarTheme: pitchBlack == null
          ? null
          : NavigationBarThemeData(
              backgroundColor: pitchBlack,
              surfaceTintColor: pitchBlack,
              indicatorColor: Color.alphaBlend(color.withAlpha(120), pitchBlack),
            ),
      navigationRailTheme: pitchBlack == null
          ? null
          : NavigationRailThemeData(
              backgroundColor: pitchBlack,
              indicatorColor: Color.alphaBlend(color.withAlpha(120), pitchBlack),
            ),
      iconTheme: light ? _iconThemeLight : _iconThemeDark,
      shadowColor: light ? const Color.fromARGB(180, 100, 100, 100) : const Color.fromARGB(222, 10, 10, 10),
      dividerTheme: const DividerThemeData(
        thickness: 4,
        indent: 0.0,
        endIndent: 0.0,
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 6.0,
        trackGap: 4.0,
        tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 1.5),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 21.0),
        valueIndicatorColor: Color.alphaBlend(
          light ? const Color.fromARGB(255, 255, 255, 255) : pitchGrey,
          cardColor,
        ),
        valueIndicatorTextStyle: TextStyle(
          fontSize: 14.0,
          fontWeight: FontWeight.normal,
          color: light ? Colors.black.withAlpha(160) : Colors.white.withAlpha(210),
          fontFamily: fontFamily,
          fontFamilyFallback: fontFamilyFallback,
        ),
        activeTrackColor: colorScheme.primary.withOpacityExt(0.85),
        secondaryActiveTrackColor: colorScheme.primary.withOpacityExt(0.4),
        inactiveTrackColor: colorScheme.secondary.withOpacityExt(0.2),
        thumbColor: colorScheme.primary.withOpacityExt(0.85),
        thumbSize: WidgetStatePropertyAll(const Size(5.0, 24.0)),
        // thumbSize: WidgetStateProperty.resolveWith((states) {
        //   if (states.contains(WidgetState.focused) || states.contains(WidgetState.pressed)) {
        //     return const Size(3.0, 24.0);
        //   }
        //   return const Size(4.0, 22.0);
        // }),
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        // ignore: deprecated_member_use
        year2023: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          visualDensity: useDesktopDecoration ? const VisualDensity(horizontal: -1.5, vertical: -1.5) : const VisualDensity(horizontal: -2.0, vertical: -2.0),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          ),
          iconSize: const WidgetStatePropertyAll(21.0),
          backgroundColor: WidgetStatePropertyAll(
            light
                ? Color.alphaBlend(color.withAlpha(30), Colors.white)
                : pitchBlack != null
                ? Color.alphaBlend(color.withAlpha(60), pitchBlack)
                : null,
          ),
        ),
      ),
      focusColor: light ? const Color.fromARGB(200, 190, 190, 190) : const Color.fromARGB(150, 80, 80, 80),
      dialogTheme: DialogThemeData(
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0.multipliedRadius)),
        backgroundColor: lighterDialog
            ? light
                  ? Color.alphaBlend(getMainColorWithAlpha(60), Colors.white)
                  : Color.alphaBlend(getMainColorWithAlpha(20), pitchBlack ?? const Color.fromARGB(255, 12, 12, 12))
            : light
            ? Color.alphaBlend(getMainColorWithAlpha(35), Colors.white)
            : Color.alphaBlend(getMainColorWithAlpha(12), pitchBlack ?? const Color.fromARGB(255, 16, 16, 16)),
      ),
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
      inputDecorationTheme: useDesktopDecoration ? _inputDecorationThemeDesktop : _inputDecorationThemeMobile,
      textButtonTheme: useDesktopDecoration ? _textButtonThemeDesktop : _textButtonThemeMobile,
      dividerColor: light ? const Color.fromARGB(100, 100, 100, 100) : const Color.fromARGB(200, 50, 50, 50),
      tooltipTheme: TooltipThemeData(
        margin: EdgeInsets.symmetric(horizontal: 24.0),
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
            ),
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
      textTheme: light ? _textThemeLight : _textThemeDark,
    );
  }
}

typedef _ThemeCacheKey = (Color color, bool light, bool lighterDialog, bool pitchBlack, double borderRadiusMultiplier);
