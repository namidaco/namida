import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'package:namida/base/setting_subpage_provider.dart';
import 'package:namida/class/lang.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/file_browser.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/settings_search_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings_card.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/yt_miniplayer_ui_controller.dart';

enum _ThemeSettingsKeys with SettingKeysBase {
  themeMode,
  autoColoring,
  wallpaperColors(NamidaFeaturesAvailablity.android12and_plus),
  forceMiniplayerColors,
  pitchBlack,
  defaultColor,
  defaultColorDark,
  language,
  ;

  @override
  final NamidaFeaturesAvailablityBase? availability;
  const _ThemeSettingsKeys([this.availability]);
}

class ThemeSetting extends SettingSubpageProvider {
  const ThemeSetting({super.key, super.initialItem});

  @override
  SettingSubpageEnum get settingPage => SettingSubpageEnum.theme;

  @override
  Map<SettingKeysBase, List<String>> get lookupMap => {
        _ThemeSettingsKeys.themeMode: [lang.THEME_MODE],
        _ThemeSettingsKeys.autoColoring: [lang.AUTO_COLORING, lang.AUTO_COLORING_SUBTITLE],
        _ThemeSettingsKeys.wallpaperColors: [lang.PICK_COLORS_FROM_DEVICE_WALLPAPER],
        _ThemeSettingsKeys.forceMiniplayerColors: [lang.FORCE_MINIPLAYER_FOLLOW_TRACK_COLORS],
        _ThemeSettingsKeys.pitchBlack: [lang.USE_PITCH_BLACK, lang.USE_PITCH_BLACK_SUBTITLE],
        _ThemeSettingsKeys.defaultColor: [lang.DEFAULT_COLOR, lang.DEFAULT_COLOR_SUBTITLE],
        _ThemeSettingsKeys.defaultColorDark: ["${lang.DEFAULT_COLOR} (${lang.THEME_MODE_DARK})", lang.DEFAULT_COLOR_SUBTITLE],
        _ThemeSettingsKeys.language: [lang.LANGUAGE],
      };

  void _refreshColorCurrentPlayingItem() {
    final currentItem = Player.inst.currentItem.value;
    if (currentItem is YoutubeID) {
      CurrentColor.inst.updatePlayerColorFromYoutubeID(currentItem);
    } else if (currentItem is Selectable) {
      CurrentColor.inst.updatePlayerColorFromTrack(currentItem, null);
    }
  }

  Widget getThemeTile({double? maxWidth}) {
    return getItemWrapper(
      key: _ThemeSettingsKeys.themeMode,
      child: CustomListTile(
        bgColor: getBgColor(_ThemeSettingsKeys.themeMode),
        icon: Broken.brush_4,
        title: lang.THEME_MODE,
        trailingRaw: ToggleThemeModeContainer(
          maxWidth: ((maxWidth ?? Dimensions.inst.availableAppContentWidth) * 0.4).withMaximum(248.0),
        ),
      ),
    );
  }

  Widget getAutoColoringTile() {
    return getItemWrapper(
      key: _ThemeSettingsKeys.autoColoring,
      child: ObxO(
        rx: settings.autoColor,
        builder: (context, autoColor) => CustomSwitchListTile(
          bgColor: getBgColor(_ThemeSettingsKeys.autoColoring),
          icon: Broken.colorfilter,
          title: lang.AUTO_COLORING,
          subtitle: "${lang.AUTO_COLORING_SUBTITLE}. ${lang.PERFORMANCE_NOTE}",
          value: autoColor,
          onChanged: (isTrue) {
            settings.save(
              autoColor: !isTrue,
              performanceMode: PerformanceMode.custom,
            );
            if (isTrue) {
              CurrentColor.inst.updatePlayerColorFromColor(playerStaticColor);
              CurrentColor.inst.updateCurrentColorSchemeOfSubPages(playerStaticColor);
            } else {
              _refreshColorCurrentPlayingItem();
            }
          },
        ),
      ),
    );
  }

  Widget getLanguageTile(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    return getItemWrapper(
      key: _ThemeSettingsKeys.language,
      child: ObxO(
        rx: lang.currentLanguage,
        builder: (context, currentLanguage) => CustomListTile(
          bgColor: getBgColor(_ThemeSettingsKeys.language),
          icon: Broken.language_square,
          title: lang.LANGUAGE,
          subtitle: currentLanguage.name,
          onTap: () {
            final Rx<NamidaLanguage> selectedLang = lang.currentLanguage.value.obs;
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
                      final files = await NamidaFileBrowser.pickFile(note: lang.ADD_LANGUAGE, allowedExtensions: NamidaFileExtensionsWrapper.json);
                      final path = files?.path;
                      if (path != null) {
                        try {
                          final st = await File(path).readAsString();
                          final map = jsonDecode(st);
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
                  height: namida.height * 0.5,
                  width: namida.width,
                  child: SmoothSingleChildScrollView(
                    child: Column(
                      children: [
                        ...Language.availableLanguages.map(
                          (e) => Padding(
                            key: Key(e.code),
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Obx(
                              (context) => ListTileWithCheckMark(
                                leading: Container(
                                  padding: const EdgeInsets.all(4.0),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      width: 1.5,
                                      color: theme.colorScheme.onSurface.withAlpha(100),
                                    ),
                                  ),
                                  child: Text(
                                    e.name[0],
                                    style: const TextStyle(fontSize: 13.0),
                                  ),
                                ),
                                titleWidget: Text.rich(
                                  TextSpan(
                                    text: e.name,
                                    style: textTheme.displayMedium,
                                    children: [
                                      TextSpan(
                                        text: " (${e.country})",
                                        style: textTheme.displaySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                active: e == selectedLang.valueR,
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
            getAutoColoringTile(),
            getItemWrapper(
              key: _ThemeSettingsKeys.wallpaperColors,
              child: Obx(
                (context) => CustomSwitchListTile(
                  bgColor: getBgColor(_ThemeSettingsKeys.wallpaperColors),
                  enabled: settings.autoColor.valueR,
                  icon: Broken.gallery_import,
                  title: lang.PICK_COLORS_FROM_DEVICE_WALLPAPER,
                  value: settings.pickColorsFromDeviceWallpaper.valueR,
                  onChanged: (isTrue) {
                    settings.save(pickColorsFromDeviceWallpaper: !isTrue);
                    _refreshColorCurrentPlayingItem();
                  },
                ),
              ),
            ),
            getItemWrapper(
              key: _ThemeSettingsKeys.forceMiniplayerColors,
              child: Obx(
                (context) => CustomSwitchListTile(
                  bgColor: getBgColor(_ThemeSettingsKeys.forceMiniplayerColors),
                  icon: Broken.slider_horizontal,
                  title: lang.FORCE_MINIPLAYER_FOLLOW_TRACK_COLORS,
                  subtitle: '${lang.IGNORES}: ${lang.AUTO_COLORING}, ${lang.PICK_COLORS_FROM_DEVICE_WALLPAPER} & ${lang.DEFAULT_COLOR}',
                  value: settings.forceMiniplayerTrackColor.valueR,
                  onChanged: (isTrue) {
                    settings.save(forceMiniplayerTrackColor: !isTrue);
                    _refreshColorCurrentPlayingItem();
                  },
                ),
              ),
            ),
            getItemWrapper(
              key: _ThemeSettingsKeys.pitchBlack,
              child: ObxO(
                rx: settings.pitchBlack,
                builder: (context, pitchBlack) => CustomSwitchListTile(
                  bgColor: getBgColor(_ThemeSettingsKeys.pitchBlack),
                  icon: Broken.mirror,
                  title: lang.USE_PITCH_BLACK,
                  subtitle: lang.USE_PITCH_BLACK_SUBTITLE,
                  value: pitchBlack,
                  onChanged: (isTrue) {
                    settings.save(pitchBlack: !isTrue);
                    if (context.isDarkMode) CurrentColor.inst.updateColorAfterThemeModeChange();
                  },
                ),
              ),
            ),
            getItemWrapper(
              key: _ThemeSettingsKeys.defaultColor,
              child: ObxO(
                rx: settings.autoColor,
                builder: (context, autoColor) => CustomListTile(
                  bgColor: getBgColor(_ThemeSettingsKeys.defaultColor),
                  enabled: !autoColor,
                  icon: Broken.bucket,
                  title: lang.DEFAULT_COLOR,
                  subtitle: lang.DEFAULT_COLOR_SUBTITLE,
                  trailingRaw: FittedBox(
                    child: Obx(
                      (context) => CircleAvatar(
                        minRadius: 12,
                        backgroundColor: playerStaticColorLight,
                      ),
                    ),
                  ),
                  onTap: () {
                    NamidaNavigator.inst.navigateDialog(
                      dialog: Obx(
                        (context) => Theme(
                          data: AppThemes.inst.getAppTheme(playerStaticColorLight),
                          child: NamidaColorPickerDialog(
                            initialColor: playerStaticColorLight,
                            doneText: lang.DONE,
                            onColorChanged: (value) => _updateColorLight(value),
                            onDonePressed: NamidaNavigator.inst.closeDialog,
                            onRefreshButtonPressed: () {
                              _updateColorLight(kMainColorLight);
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
            ),
            getItemWrapper(
              key: _ThemeSettingsKeys.defaultColorDark,
              child: ObxO(
                rx: settings.autoColor,
                builder: (context, autoColor) => CustomListTile(
                  bgColor: getBgColor(_ThemeSettingsKeys.defaultColorDark),
                  enabled: !autoColor,
                  leading: const StackedIcon(
                    baseIcon: Broken.bucket,
                    secondaryIcon: Broken.moon,
                  ),
                  title: "${lang.DEFAULT_COLOR} (${lang.THEME_MODE_DARK})",
                  subtitle: lang.DEFAULT_COLOR_SUBTITLE,
                  trailingRaw: FittedBox(
                    child: Obx(
                      (context) => CircleAvatar(
                        minRadius: 12,
                        backgroundColor: playerStaticColorDark,
                      ),
                    ),
                  ),
                  onTap: () {
                    NamidaNavigator.inst.navigateDialog(
                      dialog: Obx(
                        (context) => Theme(
                          data: AppThemes.inst.getAppTheme(playerStaticColorDark),
                          child: NamidaColorPickerDialog(
                            initialColor: playerStaticColorDark,
                            doneText: lang.DONE,
                            onColorChanged: (value) => _updateColorDark(value),
                            onDonePressed: NamidaNavigator.inst.closeDialog,
                            onRefreshButtonPressed: () {
                              _updateColorDark(kMainColorDark);
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
            ),
            getLanguageTile(context),
          ],
        ),
      ),
    );
  }

  void _updateColorLight(Color color) {
    settings.save(staticColor: color.intValue);
    if (!namida.isDarkMode) {
      CurrentColor.inst.updatePlayerColorFromColor(color, false);
    }
  }

  void _updateColorDark(Color color) {
    settings.save(staticColorDark: color.intValue);
    if (namida.isDarkMode) {
      CurrentColor.inst.updatePlayerColorFromColor(color, false);
    }
  }
}

class ToggleThemeModeContainer extends StatelessWidget {
  final double maxWidth;
  final double blurRadius;
  const ToggleThemeModeContainer({super.key, required this.maxWidth, this.blurRadius = 6.0});

  static void onThemeChangeTap(ThemeMode themeMode) async {
    settings.save(themeMode: themeMode);
    await Future.delayed(const Duration(milliseconds: kThemeAnimationDurationMS));
    CurrentColor.inst.updateColorAfterThemeModeChange();
    YoutubeMiniplayerUiController.inst.startDimTimer();
  }

  Alignment _themeModeToAlignment(ThemeMode theme) {
    return theme == ThemeMode.light
        ? Alignment.center
        : theme == ThemeMode.dark
            ? Alignment.centerRight
            : Alignment.centerLeft;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    const brConst = 8.0;
    const horizontalPaddingConst = 8.0;
    final itemsCount = ThemeMode.values.length;
    final bgSlideWidth = (maxWidth / itemsCount) - horizontalPaddingConst;
    return ObxO(
      rx: settings.themeMode,
      builder: (context, currentTheme) => Container(
        decoration: BoxDecoration(
          color: Color.alphaBlend(theme.listTileTheme.textColor!.withAlpha(200), Colors.white.withAlpha(160)),
          borderRadius: BorderRadius.circular(12.0.multipliedRadius),
          boxShadow: [
            BoxShadow(color: theme.listTileTheme.iconColor!.withAlpha(80), spreadRadius: 1.0, blurRadius: blurRadius, offset: const Offset(0, 2)),
          ],
        ),
        width: maxWidth,
        padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: horizontalPaddingConst),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 400),
                alignment: _themeModeToAlignment(currentTheme),
                child: Container(
                  width: bgSlideWidth,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withAlpha(180),
                    borderRadius: BorderRadius.circular(brConst.multipliedRadius),
                    // boxShadow: [
                    //   BoxShadow(color: Colors.black.withAlpha(100), spreadRadius: 1, blurRadius: 4, offset: Offset(0, 2)),
                    // ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ...ThemeMode.values.map(
                    (e) => SizedBox(
                      width: bgSlideWidth,
                      child: NamidaInkWell(
                        borderRadius: brConst,
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        onTap: () => onThemeChangeTap(e),
                        child: Icon(
                          e.toIcon(),
                          color: currentTheme == e ? theme.listTileTheme.iconColor : theme.colorScheme.surface.withAlpha(180),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
