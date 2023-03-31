import 'package:flutter/material.dart';

import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:get/get.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings_card.dart';

class ThemeSetting extends StatelessWidget {
  const ThemeSetting({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: Language.inst.THEME_SETTINGS,
      subtitle: Language.inst.THEME_SETTINGS_SUBTITLE,
      icon: Broken.brush_2,
      child: SizedBox(
        width: context.width,
        child: Column(
          children: [
            CustomListTile(
              // onTap: () {
              //   Get.dialog(
              //     CustomBlurryDialog(
              //       title: Language.inst.THEME_MODE,
              //       child: Material(
              //         borderRadius: BorderRadius.circular(24),
              //         child: Column(
              //           mainAxisSize: MainAxisSize.min,
              //           children: [
              //             CustomListTile(
              //               icon: Broken.autobrightness,
              //               title: Language.inst.THEME_MODE_SYSTEM,
              //               onTap: () {
              //                 SettingsController.inst.save(themeMode: ThemeMode.system);
              //                 Get.close(1);
              //               },
              //             ),
              //             CustomListTile(
              //               icon: Broken.sun_1,
              //               title: Language.inst.THEME_MODE_LIGHT,
              //               onTap: () {
              //                 SettingsController.inst.save(themeMode: ThemeMode.light);
              //                 Get.close(1);
              //               },
              //             ),
              //             CustomListTile(
              //               icon: Broken.moon,
              //               title: Language.inst.THEME_MODE_DARK,
              //               onTap: () {
              //                 SettingsController.inst.save(themeMode: ThemeMode.dark);
              //                 Get.close(1);
              //               },
              //             ),
              //           ],
              //         ),
              //       ),
              //     ),
              //   );
              // },
              icon: Broken.brush_4,
              title: Language.inst.THEME_MODE,
              trailing: const ToggleThemeModeContainer(),
            ),
            Obx(
              () => CustomSwitchListTile(
                icon: Broken.colorfilter,
                title: Language.inst.AUTO_COLORING,
                subtitle: Language.inst.AUTO_COLORING_SUBTITLE,
                value: SettingsController.inst.autoColor.value,
                onChanged: (p0) async {
                  SettingsController.inst.save(autoColor: !p0);
                  if (p0) {
                    CurrentColor.inst.color.value = playerStaticColor;
                  } else {
                    await CurrentColor.inst.setPlayerColor(Player.inst.nowPlayingTrack.value);
                  }

                  CurrentColor.inst.updateThemeAndRefresh();
                },
              ),
            ),
            Obx(
              () => CustomListTile(
                enabled: !SettingsController.inst.autoColor.value,
                icon: Broken.bucket,
                title: Language.inst.DEFAULT_COLOR,
                subtitle: Language.inst.DEFAULT_COLOR_SUBTITLE,
                trailing: CircleAvatar(
                  minRadius: 12,
                  backgroundColor: playerStaticColor,
                ),
                onTap: () => Get.dialog(
                  CustomBlurryDialog(
                    actions: [
                      IconButton(
                        icon: const Icon(Broken.refresh),
                        tooltip: Language.inst.RESTORE_DEFAULTS,
                        onPressed: () {
                          _updateColor(kMainColor);
                          Get.close(1);
                        },
                      ),
                      ElevatedButton(
                        onPressed: () => Get.close(1),
                        child: Text(Language.inst.DONE),
                      ),
                    ],
                    child: ColorPicker(
                      pickerColor: playerStaticColor,
                      onColorChanged: (value) {
                        _updateColor(value);
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateColor(Color color) {
    SettingsController.inst.save(staticColor: color.value);
    CurrentColor.inst.color.value = color;
    CurrentColor.inst.updateThemeAndRefresh();
  }
}

class ToggleThemeModeContainer extends StatelessWidget {
  final double? width;
  final double blurRadius;
  const ToggleThemeModeContainer({super.key, this.width, this.blurRadius = 6.0});

  onThemeChangeTap(ThemeMode themeMode, bool light) {
    SettingsController.inst.save(themeMode: themeMode);
    Get.changeTheme(AppThemes.inst.getAppTheme(CurrentColor.inst.color.value, light));
    Get.changeThemeMode(themeMode);
  }

  @override
  Widget build(BuildContext context) {
    final double containerWidth = width ?? Get.width / 2.8;
    return Obx(
      () {
        final currentTheme = SettingsController.inst.themeMode.value;
        return Container(
          decoration: BoxDecoration(
            color: Color.alphaBlend(context.theme.listTileTheme.textColor!.withAlpha(200), Colors.white.withAlpha(160)),
            borderRadius: BorderRadius.circular(12.0.multipliedRadius),
            boxShadow: [
              BoxShadow(color: context.theme.listTileTheme.iconColor!.withAlpha(80), spreadRadius: 1.0, blurRadius: blurRadius, offset: const Offset(0, 2)),
            ],
          ),
          width: containerWidth,
          padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 8.0),
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 400),
                  alignment: currentTheme == ThemeMode.light
                      ? Alignment.center
                      : currentTheme == ThemeMode.dark
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                  child: Container(
                    width: containerWidth / 3.3,
                    decoration: BoxDecoration(
                      color: context.theme.colorScheme.background.withAlpha(180),
                      borderRadius: BorderRadius.circular(8.0.multipliedRadius),
                      // boxShadow: [
                      //   BoxShadow(color: Colors.black.withAlpha(100), spreadRadius: 1, blurRadius: 4, offset: Offset(0, 2)),
                      // ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1.2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    InkWell(
                      onTap: () => onThemeChangeTap(ThemeMode.system, !context.isDarkMode),
                      child: Icon(
                        Broken.autobrightness,
                        color: currentTheme == ThemeMode.system ? context.theme.listTileTheme.iconColor : context.theme.colorScheme.background,
                      ),
                    ),
                    InkWell(
                      onTap: () => onThemeChangeTap(ThemeMode.light, true),
                      child: Icon(
                        Broken.sun_1,
                        color: currentTheme == ThemeMode.light ? context.theme.listTileTheme.iconColor : context.theme.colorScheme.background,
                      ),
                    ),
                    InkWell(
                      onTap: () => onThemeChangeTap(ThemeMode.dark, false),
                      child: Icon(
                        Broken.moon,
                        color: currentTheme == ThemeMode.dark ? context.theme.listTileTheme.iconColor : context.theme.colorScheme.background,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
