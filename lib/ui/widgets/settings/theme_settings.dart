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
                    await CurrentColor.inst.updatePlayerColorFromTrack(Player.inst.nowPlayingTWD, null);
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
                        child: NamidaColorPickerDialog(
                          doneText: Language.inst.DONE,
                          onColorChanged: _updateColor,
                          onDonePressed: NamidaNavigator.inst.closeDialog,
                          onRefreshButtonPressed: () {
                            _updateColor(kMainColor);
                            NamidaNavigator.inst.closeDialog();
                          },
                          cancelButton: false,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Obx(
              () => CustomListTile(
                icon: Broken.language_square,
                title: Language.inst.LANGUAGE,
                subtitle: Language.inst.currentLanguage.name,
                onTap: () {
                  final Rx<NamidaLanguage> selectedLang = Language.inst.currentLanguage.obs;
                  NamidaNavigator.inst.navigateDialog(
                    dialog: CustomBlurryDialog(
                      title: Language.inst.LANGUAGE,
                      normalTitleStyle: true,
                      actions: [
                        const CancelButton(),
                        NamidaButton(
                          onPressed: () async => (await Language.inst.update(lang: selectedLang.value)).closeDialog(),
                          text: Language.inst.CONFIRM,
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

class NamidaColorPickerDialog extends StatelessWidget {
  final String doneText;
  final VoidCallback? onRefreshButtonPressed;
  final ValueChanged<Color> onColorChanged;
  final VoidCallback onDonePressed;
  final bool cancelButton;

  const NamidaColorPickerDialog({
    super.key,
    required this.doneText,
    this.onRefreshButtonPressed,
    required this.onColorChanged,
    required this.onDonePressed,
    required this.cancelButton,
  });

  @override
  Widget build(BuildContext context) {
    return CustomBlurryDialog(
      actions: [
        if (onRefreshButtonPressed != null)
          IconButton(
            icon: const Icon(Broken.refresh),
            tooltip: Language.inst.RESTORE_DEFAULTS,
            onPressed: onRefreshButtonPressed,
          ),
        if (cancelButton) const CancelButton(),
        NamidaButton(
          text: doneText,
          onPressed: onDonePressed,
        ),
      ],
      child: ColorPicker(
        pickerColor: playerStaticColor,
        onColorChanged: onColorChanged,
      ),
    );
  }
}
