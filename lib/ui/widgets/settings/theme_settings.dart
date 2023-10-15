import 'package:flutter/material.dart';

import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:get/get.dart';

import 'package:namida/class/lang.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings_card.dart';

class ThemeSetting extends StatelessWidget {
  const ThemeSetting({super.key});

  Future<void> _refreshColorCurrentTrack() async {
    await CurrentColor.inst.updatePlayerColorFromTrack(Player.inst.nowPlayingTWD, null);
  }

  Widget getThemeTile() {
    return CustomListTile(
      icon: Broken.brush_4,
      title: lang.THEME_MODE,
      trailing: const ToggleThemeModeContainer(),
    );
  }

  Widget getLanguageTile(BuildContext context) {
    return Obx(
      () => CustomListTile(
        icon: Broken.language_square,
        title: lang.LANGUAGE,
        subtitle: lang.currentLanguage.name,
        onTap: () {
          final Rx<NamidaLanguage> selectedLang = lang.currentLanguage.obs;
          NamidaNavigator.inst.navigateDialog(
            dialog: CustomBlurryDialog(
              title: lang.LANGUAGE,
              normalTitleStyle: true,
              actions: [
                const CancelButton(),
                NamidaButton(
                  onPressed: () async => (await lang.update(lang: selectedLang.value)).closeDialog(),
                  text: lang.CONFIRM,
                )
              ],
              child: SizedBox(
                height: (Language.availableLanguages.length * context.height * 0.08).withMaximum(context.height * 0.5),
                width: context.width,
                child: NamidaListView(
                  padding: EdgeInsets.zero,
                  itemExtents: null,
                  itemCount: Language.availableLanguages.length,
                  itemBuilder: (context, i) {
                    final e = Language.availableLanguages[i];
                    return Padding(
                      key: Key(i.toString()),
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Obx(
                        () => ListTileWithCheckMark(
                          leading: Container(
                            padding: const EdgeInsets.all(4.0),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                width: 1.5,
                                color: context.theme.colorScheme.onBackground.withAlpha(100),
                              ),
                            ),
                            child: Text(
                              e.name[0],
                              style: const TextStyle(fontSize: 13.0),
                            ),
                          ),
                          titleWidget: RichText(
                            text: TextSpan(
                              text: e.name,
                              style: context.textTheme.displayMedium,
                              children: [
                                TextSpan(
                                  text: " (${e.country})",
                                  style: context.textTheme.displaySmall,
                                ),
                              ],
                            ),
                          ),
                          active: e == selectedLang.value,
                          onTap: () => selectedLang.value = e,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: lang.THEME_SETTINGS,
      subtitle: lang.THEME_SETTINGS_SUBTITLE,
      icon: Broken.brush_2,
      child: SizedBox(
        width: context.width,
        child: Column(
          children: [
            getThemeTile(),
            Obx(
              () => CustomSwitchListTile(
                icon: Broken.colorfilter,
                title: lang.AUTO_COLORING,
                subtitle: lang.AUTO_COLORING_SUBTITLE,
                value: settings.autoColor.value,
                onChanged: (isTrue) async {
                  settings.save(autoColor: !isTrue);
                  if (isTrue) {
                    CurrentColor.inst.updatePlayerColorFromColor(playerStaticColor);
                  } else {
                    await _refreshColorCurrentTrack();
                  }
                },
              ),
            ),
            // Android S/12+
            if (kSdkVersion >= 31)
              Obx(
                () => CustomSwitchListTile(
                  enabled: settings.autoColor.value,
                  icon: Broken.gallery_import,
                  title: lang.PICK_COLORS_FROM_DEVICE_WALLPAPER,
                  value: settings.pickColorsFromDeviceWallpaper.value,
                  onChanged: (isTrue) async {
                    settings.save(pickColorsFromDeviceWallpaper: !isTrue);

                    await _refreshColorCurrentTrack();
                  },
                ),
              ),
            ...[false, true].map(
              (isDark) => Obx(
                () {
                  final darkText = isDark ? " (${lang.THEME_MODE_DARK})" : '';
                  final color = isDark ? playerStaticColorDark : playerStaticColorLight;
                  return CustomListTile(
                    enabled: !settings.autoColor.value,
                    icon: !isDark ? Broken.bucket : null,
                    leading: isDark
                        ? const StackedIcon(
                            baseIcon: Broken.bucket,
                            secondaryIcon: Broken.moon,
                          )
                        : null,
                    title: "${lang.DEFAULT_COLOR}$darkText",
                    subtitle: lang.DEFAULT_COLOR_SUBTITLE,
                    trailing: CircleAvatar(
                      minRadius: 12,
                      backgroundColor: color,
                    ),
                    onTap: () {
                      NamidaNavigator.inst.navigateDialog(
                        dialog: Obx(
                          () => Theme(
                            data: AppThemes.inst.getAppTheme(color),
                            child: NamidaColorPickerDialog(
                              initialColor: color,
                              doneText: lang.DONE,
                              onColorChanged: (value) => _updateColor(value, isDark),
                              onDonePressed: NamidaNavigator.inst.closeDialog,
                              onRefreshButtonPressed: () {
                                if (isDark) {
                                  _updateColor(kMainColorDark, true);
                                } else {
                                  _updateColor(kMainColorLight, false);
                                }
                                NamidaNavigator.inst.closeDialog();
                              },
                              cancelButton: false,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            getLanguageTile(context),
          ],
        ),
      ),
    );
  }

  void _updateColor(Color color, bool darkMode) {
    if (darkMode) {
      settings.save(staticColorDark: color.value);
      if (Get.isDarkMode) {
        CurrentColor.inst.updatePlayerColorFromColor(color, false);
      }
    } else {
      settings.save(staticColor: color.value);
      if (!Get.isDarkMode) {
        CurrentColor.inst.updatePlayerColorFromColor(color, false);
      }
    }
  }
}

class ToggleThemeModeContainer extends StatelessWidget {
  final double? width;
  final double blurRadius;
  const ToggleThemeModeContainer({super.key, this.width, this.blurRadius = 6.0});

  void onThemeChangeTap(ThemeMode themeMode) async {
    settings.save(themeMode: themeMode);
    await Future.delayed(const Duration(milliseconds: kThemeAnimationDurationMS));
    CurrentColor.inst.updateColorAfterThemeModeChange();
  }

  @override
  Widget build(BuildContext context) {
    final double containerWidth = width ?? context.width / 2.8;
    return Obx(
      () {
        final currentTheme = settings.themeMode.value;
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

class NamidaColorPickerDialog extends StatelessWidget {
  final String doneText;
  final VoidCallback? onRefreshButtonPressed;
  final ValueChanged<Color> onColorChanged;
  final VoidCallback onDonePressed;
  final bool cancelButton;
  final Color initialColor;

  const NamidaColorPickerDialog({
    super.key,
    required this.doneText,
    this.onRefreshButtonPressed,
    required this.onColorChanged,
    required this.onDonePressed,
    required this.cancelButton,
    required this.initialColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomBlurryDialog(
      actions: [
        if (onRefreshButtonPressed != null)
          IconButton(
            icon: const Icon(Broken.refresh),
            tooltip: lang.RESTORE_DEFAULTS,
            onPressed: onRefreshButtonPressed,
          ),
        if (cancelButton) const CancelButton(),
        NamidaButton(
          text: doneText,
          onPressed: onDonePressed,
        ),
      ],
      child: ColorPicker(
        pickerColor: initialColor,
        onColorChanged: onColorChanged,
      ),
    );
  }
}
