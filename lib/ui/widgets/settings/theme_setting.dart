import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings_card.dart';
import 'package:namida/core/extensions.dart';

class ThemeSetting extends StatelessWidget {
  const ThemeSetting({super.key});

  @override
  Widget build(BuildContext context) {
    final double containerWidth = Get.width / 2.8;
    return SettingsCard(
      title: Language.inst.THEME_SETTINGS,
      subtitle: Language.inst.THEME_SETTINGS_SUBTITLE,
      icon: Broken.brush_1,
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: Column(
          children: [
            Obx(
              () {
                final currentTheme = SettingsController.inst.themeMode.value;
                return CustomListTile(
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
                  icon: Broken.bucket,
                  title: Language.inst.THEME_MODE,
                  trailing: Container(
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(context.theme.listTileTheme.textColor!.withAlpha(200), Colors.white.withAlpha(160)),
                      borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                      boxShadow: [
                        BoxShadow(color: context.theme.listTileTheme.iconColor!.withAlpha(80), spreadRadius: 1, blurRadius: 10, offset: const Offset(0, 2)),
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
                                onTap: () {
                                  SettingsController.inst.save(themeMode: ThemeMode.system);
                                },
                                child: Icon(
                                  Broken.autobrightness,
                                  color: currentTheme == ThemeMode.system ? context.theme.listTileTheme.iconColor : context.theme.colorScheme.background,
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  SettingsController.inst.save(themeMode: ThemeMode.light);
                                },
                                child: Icon(
                                  Broken.sun_1,
                                  color: currentTheme == ThemeMode.light ? context.theme.listTileTheme.iconColor : context.theme.colorScheme.background,
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  SettingsController.inst.save(themeMode: ThemeMode.dark);
                                },
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
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
