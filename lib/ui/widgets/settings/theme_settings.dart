import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:get/get.dart';

import 'package:namida/base/setting_subpage_provider.dart';
import 'package:namida/class/lang.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings_card.dart';
import 'package:namida/ui/widgets/waveform.dart';

enum _ThemeSettingsKeys {
  themeMode,
  autoColoring,
  wallpaperColors,
  forceMiniplayerColors,
  pitchBlack,
  defaultColor,
  defaultColorDark,
  language,
}

class ThemeSetting extends SettingSubpageProvider {
  const ThemeSetting({super.key, super.initialItem});

  @override
  SettingSubpageEnum get settingPage => SettingSubpageEnum.theme;

  @override
  Map<Enum, List<String>> get lookupMap => {
        _ThemeSettingsKeys.themeMode: [lang.THEME_MODE],
        _ThemeSettingsKeys.autoColoring: [lang.AUTO_COLORING, lang.AUTO_COLORING_SUBTITLE],
        _ThemeSettingsKeys.wallpaperColors: [lang.PICK_COLORS_FROM_DEVICE_WALLPAPER],
        _ThemeSettingsKeys.forceMiniplayerColors: [lang.FORCE_MINIPLAYER_FOLLOW_TRACK_COLORS],
        _ThemeSettingsKeys.pitchBlack: [lang.USE_PITCH_BLACK, lang.USE_PITCH_BLACK_SUBTITLE],
        _ThemeSettingsKeys.defaultColor: [lang.DEFAULT_COLOR, lang.DEFAULT_COLOR_SUBTITLE],
        _ThemeSettingsKeys.defaultColorDark: ["${lang.DEFAULT_COLOR} (${lang.THEME_MODE_DARK})", lang.DEFAULT_COLOR_SUBTITLE],
        _ThemeSettingsKeys.language: [lang.LANGUAGE],
      };

  Future<void> _refreshColorCurrentTrack() async {
    if (Player.inst.currentQueueYoutube.isNotEmpty && Player.inst.latestExtractedColor != null) {
      CurrentColor.inst.updatePlayerColorFromColor(Player.inst.latestExtractedColor!);
    } else {
      await CurrentColor.inst.updatePlayerColorFromTrack(Player.inst.nowPlayingTWD, null);
    }
  }

  Widget getThemeTile() {
    return getItemWrapper(
      key: _ThemeSettingsKeys.themeMode,
      child: CustomListTile(
        bgColor: getBgColor(_ThemeSettingsKeys.themeMode),
        icon: Broken.brush_4,
        title: lang.THEME_MODE,
        trailingRaw: const ToggleThemeModeContainer(),
      ),
    );
  }

  Widget getLanguageTile(BuildContext context) {
    return getItemWrapper(
      key: _ThemeSettingsKeys.language,
      child: Obx(
        () => CustomListTile(
          bgColor: getBgColor(_ThemeSettingsKeys.language),
          icon: Broken.language_square,
          title: lang.LANGUAGE,
          subtitle: lang.currentLanguage.name,
          onTap: () {
            final Rx<NamidaLanguage> selectedLang = lang.currentLanguage.obs;
            NamidaNavigator.inst.navigateDialog(
              onDisposing: () {
                selectedLang.close();
              },
              dialog: CustomBlurryDialog(
                title: lang.LANGUAGE,
                normalTitleStyle: true,
                actions: [
                  NamidaButton(
                    onPressed: () async {
                      final files = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json', 'JSON']);
                      final path = files?.files.firstOrNull?.path;
                      if (path != null) {
                        try {
                          final st = await File(path).readAsString();
                          final map = await jsonDecode(st);
                          final didUpdate = await Language.inst.loadLanguage(path.getFilenameWOExt, map);
                          if (didUpdate) {
                            NamidaNavigator.inst.closeDialog();
                          } else {
                            snackyy(title: lang.ERROR, message: 'Unknown Error', isError: true);
                          }
                        } catch (e) {
                          snackyy(title: lang.ERROR, message: e.toString(), isError: true);
                        }
                      }
                    },
                    text: lang.LOCAL,
                  ),
                  const CancelButton(),
                  NamidaButton(
                    onPressed: () async => (await lang.update(lang: selectedLang.value)).closeDialog(),
                    text: lang.CONFIRM,
                  )
                ],
                child: SizedBox(
                  height: Get.height * 0.5,
                  width: Get.width,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        ...Language.availableLanguages.map(
                          (e) => Padding(
                            key: Key(e.code),
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
                          ),
                        ),
                        CustomListTile(
                          visualDensity: VisualDensity.compact,
                          icon: Broken.add_circle,
                          title: lang.ADD_LANGUAGE,
                          subtitle: lang.ADD_LANGUAGE_SUBTITLE,
                          onTap: () {
                            NamidaLinkUtils.openLink(AppSocial.TRANSLATION_REPO);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
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
            getItemWrapper(
              key: _ThemeSettingsKeys.autoColoring,
              child: Obx(
                () => CustomSwitchListTile(
                  bgColor: getBgColor(_ThemeSettingsKeys.autoColoring),
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
            ),
            // Android S/12+
            if (kSdkVersion >= 31)
              getItemWrapper(
                key: _ThemeSettingsKeys.wallpaperColors,
                child: Obx(
                  () => CustomSwitchListTile(
                    bgColor: getBgColor(_ThemeSettingsKeys.wallpaperColors),
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
              ),
            getItemWrapper(
              key: _ThemeSettingsKeys.forceMiniplayerColors,
              child: Obx(
                () => CustomSwitchListTile(
                  bgColor: getBgColor(_ThemeSettingsKeys.forceMiniplayerColors),
                  icon: Broken.slider_horizontal,
                  title: lang.FORCE_MINIPLAYER_FOLLOW_TRACK_COLORS,
                  subtitle: '${lang.IGNORES}: ${lang.AUTO_COLORING}, ${lang.PICK_COLORS_FROM_DEVICE_WALLPAPER} & ${lang.DEFAULT_COLOR}',
                  value: settings.forceMiniplayerTrackColor.value,
                  onChanged: (isTrue) async {
                    settings.save(forceMiniplayerTrackColor: !isTrue);
                    await _refreshColorCurrentTrack();
                  },
                ),
              ),
            ),
            getItemWrapper(
              key: _ThemeSettingsKeys.pitchBlack,
              child: Obx(
                () => CustomSwitchListTile(
                  bgColor: getBgColor(_ThemeSettingsKeys.pitchBlack),
                  icon: Broken.mirror,
                  title: lang.USE_PITCH_BLACK,
                  subtitle: lang.USE_PITCH_BLACK_SUBTITLE,
                  value: settings.pitchBlack.value,
                  onChanged: (isTrue) async {
                    settings.save(pitchBlack: !isTrue);
                    await _refreshColorCurrentTrack();
                  },
                ),
              ),
            ),
            ...[false, true].map(
              (isDark) {
                final darkText = isDark ? " (${lang.THEME_MODE_DARK})" : '';
                final key = isDark ? _ThemeSettingsKeys.defaultColorDark : _ThemeSettingsKeys.defaultColor;
                return getItemWrapper(
                  key: key,
                  child: Obx(
                    () {
                      final color = isDark ? playerStaticColorDark : playerStaticColorLight;
                      return CustomListTile(
                        bgColor: getBgColor(key),
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
                        trailingRaw: FittedBox(
                          child: CircleAvatar(
                            minRadius: 12,
                            backgroundColor: color,
                          ),
                        ),
                        onTap: () {
                          NamidaNavigator.inst.navigateDialog(
                            dialog: Obx(
                              () => Theme(
                                data: AppThemes.inst.getAppTheme(CurrentColor.inst.color),
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
                );
              },
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
    themeCanRebuildWaveform = true;
    settings.save(themeMode: themeMode);
    await Future.delayed(const Duration(milliseconds: kThemeAnimationDurationMS));
    themeCanRebuildWaveform = false;
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
        hexInputBar: true,
      ),
    );
  }
}
