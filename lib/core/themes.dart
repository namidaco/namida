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
        color: light ? Colors.black.withOpacityExt(0.63) : Colors.white.withOpacityExt(0.82),
        fontFamilyFallback: fontFamilyFallback,
      ),
      displayMedium: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 15.0,
        color: light ? Colors.black.withOpacityExt(0.59) : Colors.white.withOpacityExt(0.71),
        fontFamilyFallback: fontFamilyFallback,
      ),
      displaySmall: TextStyle(
        fontWeight: FontWeight.w400,
        fontSize: 13.0,
        color: light ? Colors.black.withOpacityExt(0.47) : Colors.white.withOpacityExt(0.67),
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

  static const pitchBlackMaxLevel = 5;

  int get _pitchBlackLevel => settings.pitchBlackAdv.value?.clampInt(0, pitchBlackMaxLevel) ?? (settings.pitchBlack.value ? pitchBlackMaxLevel : 0);

  ThemeData getAppTheme([Color? color, bool? light, bool lighterDialog = true]) {
    color ??= CurrentColor.inst.color;
    light ??= namida.brightness == Brightness.light;

    final pitchBlackLevel = _pitchBlackLevel;
    final key = (color, light, lighterDialog, pitchBlackLevel, settings.borderRadiusMultiplier.value);
    final cached = _cache.remove(key);
    if (cached != null) return _cache[key] = cached; // -- re-insert to keep it as most recently used

    if (_cache.length >= _cacheMaxLength) _cache.remove(_cache.keys.first);
    return _cache[key] = _buildAppTheme(color, light, lighterDialog, pitchBlackLevel);
  }

  ThemeData _buildAppTheme(Color color, bool light, bool lighterDialog, int pitchBlackLevel) {
    const pitchBlack = Color.fromARGB(255, 0, 0, 0);
    final pitchBlend = _PitchBlackBlend(light ? 0.0 : pitchBlackLevel / pitchBlackMaxLevel);
    final mainColorMultiplier = pitchBlend.ofTint(0.8, 0.1); // makes colors that rely on mainColor, a bit darker.
    final pitchGrey = pitchBlend.of(const Color.fromARGB(255, 35, 35, 35), const Color.fromARGB(255, 20, 20, 20));

    final useDesktopDecoration = isDesktop;

    Color getMainColorWithOpacity(double opacity) => color.withOpacityExt(opacity * mainColorMultiplier);

    final cardTheme = CardThemeData(
      elevation: 12.0,
      color: Color.alphaBlend(
        getMainColorWithOpacity(0.18),
        light ? const Color.fromARGB(255, 255, 255, 255) : pitchGrey,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14.0.multipliedRadius),
      ),
    );

    final cardColor = Color.alphaBlend(
      getMainColorWithOpacity(0.14),
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
      scaffoldBackgroundColor: pitchBlend.ofMaterialDefault(light ? Color.alphaBlend(color.withOpacityExt(0.24), Colors.white) : null, colorScheme.surface, pitchBlack),
      splashColor: Colors.transparent,
      splashFactory: InkRipple.splashFactory,
      highlightColor: light ? Colors.black.withOpacityExt(0.08) : Colors.white.withOpacityExt(pitchBlend.ofOpacity(0.04, 0.1)),
      disabledColor: light ? const Color.fromARGB(200, 160, 160, 160) : const Color.fromARGB(200, 60, 60, 60),
      applyElevationOverlayColor: false,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: pitchBlend.ofMaterialDefault(light ? Color.alphaBlend(color.withOpacityExt(0.1), Colors.white) : null, colorScheme.surface, pitchBlack),
        actionsIconTheme: light ? _iconThemeLight : _iconThemeDark,
      ),
      secondaryHeaderColor: light ? const Color.fromARGB(200, 240, 240, 240) : const Color.fromARGB(222, 10, 10, 10),
      navigationBarTheme: pitchBlend.isNone
          ? null
          : NavigationBarThemeData(
              backgroundColor: pitchBlend.of(colorScheme.surfaceContainer, pitchBlack),
              surfaceTintColor: pitchBlend.of(Colors.transparent, pitchBlack),
              indicatorColor: pitchBlend.of(colorScheme.secondaryContainer, Color.alphaBlend(color.withOpacityExt(0.47), pitchBlack)),
            ),
      navigationRailTheme: pitchBlend.isNone
          ? null
          : NavigationRailThemeData(
              backgroundColor: pitchBlend.of(colorScheme.surface, pitchBlack),
              indicatorColor: pitchBlend.of(colorScheme.secondaryContainer, Color.alphaBlend(color.withOpacityExt(0.47), pitchBlack)),
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
          color: light ? Colors.black.withOpacityExt(0.63) : Colors.white.withOpacityExt(0.82),
          fontFamily: fontFamily,
          fontFamilyFallback: fontFamilyFallback,
        ),
        activeTrackColor: colorScheme.primary.withOpacityExt(0.85),
        secondaryActiveTrackColor: colorScheme.primary.withOpacityExt(0.4),
        inactiveTrackColor: colorScheme.secondary.withOpacityExt(0.2),
        thumbColor: colorScheme.primary.withOpacityExt(0.85),
        thumbSize: const WidgetStatePropertyAll(Size(5.0, 24.0)),
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
                ? Color.alphaBlend(color.withOpacityExt(0.12), Colors.white)
                : pitchBlend.ofMaterialDefault(null, colorScheme.surfaceContainerLow, Color.alphaBlend(color.withOpacityExt(0.24), pitchBlack)),
          ),
        ),
      ),
      focusColor: light ? const Color.fromARGB(200, 190, 190, 190) : const Color.fromARGB(150, 80, 80, 80),
      dialogTheme: DialogThemeData(
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0.multipliedRadius)),
        backgroundColor: lighterDialog
            ? light
                  ? Color.alphaBlend(getMainColorWithOpacity(0.24), Colors.white)
                  : Color.alphaBlend(getMainColorWithOpacity(0.08), pitchBlend.of(const Color.fromARGB(255, 12, 12, 12), pitchBlack))
            : light
            ? Color.alphaBlend(getMainColorWithOpacity(0.14), Colors.white)
            : Color.alphaBlend(getMainColorWithOpacity(0.05), pitchBlend.of(const Color.fromARGB(255, 16, 16, 16), pitchBlack)),
      ),
      listTileTheme: ListTileThemeData(
        horizontalTitleGap: 16.0,
        selectedColor: light
            ? Color.alphaBlend(getMainColorWithOpacity(0.16), const Color.fromARGB(255, 182, 182, 182))
            : Color.alphaBlend(getMainColorWithOpacity(0.16), pitchBlend.of(const Color.fromARGB(255, 55, 55, 55), pitchBlack)),
        iconColor: Color.alphaBlend(
          getMainColorWithOpacity(0.31),
          light ? const Color.fromARGB(200, 55, 55, 55) : const Color.fromARGB(255, 228, 228, 228),
        ),
        textColor: Color.alphaBlend(
          getMainColorWithOpacity(0.31),
          light ? const Color.fromARGB(200, 55, 55, 55) : const Color.fromARGB(255, 228, 228, 228),
        ),
      ),
      inputDecorationTheme: useDesktopDecoration ? _inputDecorationThemeDesktop : _inputDecorationThemeMobile,
      textButtonTheme: useDesktopDecoration ? _textButtonThemeDesktop : _textButtonThemeMobile,
      dividerColor: light ? const Color.fromARGB(100, 100, 100, 100) : const Color.fromARGB(200, 50, 50, 50),
      tooltipTheme: TooltipThemeData(
        margin: const EdgeInsets.symmetric(horizontal: 24.0),
        decoration: BoxDecoration(
          color: light
              ? Color.alphaBlend(getMainColorWithOpacity(0.12), const Color.fromARGB(255, 242, 242, 242))
              : Color.alphaBlend(getMainColorWithOpacity(0.31), const Color.fromARGB(255, 12, 12, 12)),
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
        color: light ? Color.alphaBlend(cardColor.withOpacityExt(0.71), Colors.white) : Color.alphaBlend(cardColor.withOpacityExt(0.71), Colors.black),
      ),
      textTheme: light ? _textThemeLight : _textThemeDark,
    );
  }
}

class _PitchBlackBlend {
  final double fraction;

  const _PitchBlackBlend(this.fraction);

  static const _tintCurve = Curves.easeIn;

  bool get isNone => fraction == 0.0;

  Color of(Color dark, Color pitch) => switch (fraction) {
    0.0 => dark,
    1.0 => pitch,
    _ => Color.lerp(dark, pitch, fraction)!,
  };

  Color? ofMaterialDefault(Color? dark, Color darkMaterialDefault, Color pitch) => isNone ? dark : of(dark ?? darkMaterialDefault, pitch);

  double ofOpacity(double dark, double pitch) => switch (fraction) {
    0.0 => dark,
    1.0 => pitch,
    _ => dark + (pitch - dark) * fraction,
  };

  double ofTint(double dark, double pitch) => switch (fraction) {
    0.0 => dark,
    1.0 => pitch,
    _ => dark + (pitch - dark) * _tintCurve.transform(fraction),
  };
}

typedef _ThemeCacheKey = (Color color, bool light, bool lighterDialog, int pitchBlackLevel, double borderRadiusMultiplier);
