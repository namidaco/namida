import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/core/extensions.dart';

class AppThemes extends GetxController {
  static final AppThemes inst = AppThemes();

  ThemeData getAppTheme([Color? color, bool? light]) {
    color ??= CurrentColor.inst.color.value;
    light ??= Get.theme.brightness == Brightness.light;
    final cardTheme = CardTheme(
      elevation: 12.0,
      color: light
          ? Color.alphaBlend(
              color.withAlpha(35),
              const Color.fromARGB(255, 255, 255, 255),
            )
          : Color.alphaBlend(
              color.withAlpha(40),
              const Color.fromARGB(255, 35, 35, 35),
            ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14.0),
      ),
    );
    final cardColor = light
        ? Color.alphaBlend(
            color.withAlpha(25),
            const Color.fromARGB(255, 255, 255, 255),
          )
        : Color.alphaBlend(
            color.withAlpha(30),
            const Color.fromARGB(255, 35, 35, 35),
          );
    return ThemeData(
      brightness: light ? Brightness.light : Brightness.dark,
      useMaterial3: true,
      colorSchemeSeed: color,
      fontFamily: "LexendDeca",
      scaffoldBackgroundColor: light ? Color.alphaBlend(color.withAlpha(50), Colors.white) : null,
      backgroundColor: light ? const Color.fromARGB(255, 235, 235, 235) : const Color.fromARGB(255, 20, 20, 20),
      splashColor: Colors.transparent,
      splashFactory: InkRipple.splashFactory,
      highlightColor: Colors.white.withAlpha(10),
      disabledColor: light ? const Color.fromARGB(0, 160, 160, 160) : const Color.fromARGB(200, 60, 60, 60),
      appBarTheme: AppBarTheme(
        backgroundColor: light
            ? Color.alphaBlend(
                color.withAlpha(80),
                Colors.white,
              )
            : null,
        actionsIconTheme: IconThemeData(
          color: light ? const Color.fromARGB(200, 40, 40, 40) : const Color.fromARGB(200, 233, 233, 233),
        ),
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
      selectedRowColor: light ? const Color.fromARGB(200, 190, 190, 190) : const Color.fromARGB(150, 80, 80, 80),
      dialogTheme: DialogTheme(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0.multipliedRadius))),
      listTileTheme: ListTileThemeData(
        horizontalTitleGap: 4.0,
        selectedColor:
            light ? Color.alphaBlend(color.withAlpha(40), const Color.fromARGB(255, 182, 182, 182)) : Color.alphaBlend(color.withAlpha(40), const Color.fromARGB(255, 55, 55, 55)),
        iconColor: Color.alphaBlend(
          color.withAlpha(80),
          light ? const Color.fromARGB(200, 55, 55, 55) : const Color.fromARGB(255, 228, 228, 228),
        ),
        textColor: Color.alphaBlend(
          color.withAlpha(80),
          light ? const Color.fromARGB(200, 55, 55, 55) : const Color.fromARGB(255, 228, 228, 228),
        ),
      ),
      // this is for the expansion tile
      // dividerColor: Colors.transparent,
      dividerColor: light ? const Color.fromARGB(100, 100, 100, 100) : const Color.fromARGB(200, 50, 50, 50),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: Get.theme.colorScheme.background,
          borderRadius: BorderRadius.circular(10.0.multipliedRadius),
          boxShadow: [
            BoxShadow(
              color: Get.theme.shadowColor,
              blurRadius: 6.0,
              offset: const Offset(0, 2),
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
          elevation: 12.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0.multipliedRadius),
          ),
          color: Color.alphaBlend(cardColor.withAlpha(180), Colors.black)),
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
        ),
        displayMedium: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15.0.multipliedFontScale,
        ),
        displaySmall: TextStyle(
          fontWeight: FontWeight.w400,
          fontSize: 13.0.multipliedFontScale,
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
