import 'package:flutter/material.dart';

import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:get/get.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
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
                onChanged: (isTrue) async {
                  SettingsController.inst.save(autoColor: !isTrue);
                  if (isTrue) {
                    CurrentColor.inst.updatePlayerColorFromColor(playerStaticColor);
                  } else {
                    await CurrentColor.inst.setPlayerColor(Player.inst.nowPlayingTrack.value);
                  }
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
                onTap: () {
                  NamidaNavigator.inst.navigateDialog(
                    dialog: Obx(
                      () => Theme(
                        data: AppThemes.inst.getAppTheme(),
                        child: CustomBlurryDialog(
                          actions: [
                            IconButton(
                              icon: const Icon(Broken.refresh),
                              tooltip: Language.inst.RESTORE_DEFAULTS,
                              onPressed: () {
                                _updateColor(kMainColor);
                                NamidaNavigator.inst.closeDialog();
                              },
                            ),
                            NamidaButton(
                              text: Language.inst.DONE,
                              onPressed: NamidaNavigator.inst.closeDialog,
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateColor(Color color) {
    SettingsController.inst.save(staticColor: color.value);
    CurrentColor.inst.updatePlayerColorFromColor(color, false);
  }
}

class ToggleThemeModeContainer extends StatelessWidget {
  final double? width;
  final double blurRadius;
  const ToggleThemeModeContainer({super.key, this.width, this.blurRadius = 6.0});

  void onThemeChangeTap(ThemeMode themeMode) async {
    SettingsController.inst.save(themeMode: themeMode);
    await Future.delayed(const Duration(milliseconds: kThemeAnimationDurationMS));
    CurrentColor.inst.updateColorAfterThemeModeChange();
  }

  @override
  Widget build(BuildContext context) {
    final double containerWidth = width ?? context.width / 2.8;
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
                    ...ThemeMode.values.map(
                      (e) => NamidaInkWell(
                        onTap: () => onThemeChangeTap(e),
                        child: Icon(
                          e.toIcon(),
                          color: currentTheme == e ? context.theme.listTileTheme.iconColor : context.theme.colorScheme.background.withAlpha(180),
                        ),
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
