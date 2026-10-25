import 'dart:async';

import 'package:flutter/material.dart';

import 'package:namida/base/setting_subpage_provider.dart';
import 'package:namida/class/lang.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/arb/app_localizations.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/color_picker_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/jellyfish.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/ui/widgets/settings_card.dart';
import 'package:namida/youtube/controller/yt_miniplayer_ui_controller.dart';

class ThemeSetting extends SettingSubpageProvider {
  const ThemeSetting({super.key, super.initialItem});

  @override
  SettingSubpageEnum get settingPage => SettingSubpageEnum.theme;

  @override
  List<List<SettingEntry>> get sections => _sections;

  @override
  List<SettingEntry> get headerEntries => _headerEntries;

  static final themeMode = SettingCustom(
    title: () => lang.themeMode,
    keys: [settings.themeMode],
    onReset: () => ToggleThemeModeContainer.onThemeChangeTap(settings.themeMode.value),
    tile: (args) => _ThemeModeTile(
      bgColor: args.bgColor,
    ),
  );

  static final autoColoring = SettingCustom(
    title: () => lang.autoColoring,
    aliases: () => [lang.autoColoringSubtitle],
    keys: [settings.autoColor],
    onReset: () => _AutoColoringTile._applyAutoColor(settings.autoColor.value),
    tile: (args) => _AutoColoringTile(
      bgColor: args.bgColor,
    ),
  );

  static final language = SettingCustom(
    title: () => lang.language,
    tile: (args) => _LanguageTile(
      bgColor: args.bgColor,
    ),
  );

  static final _headerEntries = <SettingEntry>[_jellysInvasion];

  static final _jellysInvasion = SettingCustom(
    visibleWhen: () => kAllowJellysInvasion,
    title: () => 'jellys_invasion'.toUpperCase(),
    aliases: () => ['jellys_color_palette'.toUpperCase()],
    keys: [settings.extra.jellysInvasion, settings.extra.jellysPalette],
    tile: (args) => const _JellysInvasionButton(),
  );

  static final _sections = <List<SettingEntry>>[
    [
      themeMode,
    ],
    [
      autoColoring,
      SettingToggle(
        settings.pickColorsFromDeviceWallpaper,
        availability: NamidaFeaturesAvailablity.android12and_plus,
        icon: Broken.gallery_import,
        title: () => lang.pickColorsFromDeviceWallpaper,
        enabledWhen: _isAutoColorEnabled,
        onChanged: _refreshColors,
      ),
      SettingToggle(
        settings.forceMiniplayerTrackColor,
        icon: Broken.slider_horizontal,
        title: () => lang.forceMiniplayerFollowTrackColors,
        subtitle: () => '${lang.ignores}: ${lang.autoColoring}, ${lang.pickColorsFromDeviceWallpaper} & ${lang.defaultColor}',
        onChanged: _refreshColors,
      ),
    ],
    [
      SettingToggle(
        settings.pitchBlack,
        icon: Broken.mirror,
        title: () => lang.usePitchBlack,
        subtitle: () => lang.usePitchBlackSubtitle,
        onChanged: _onPitchBlackChanged,
      ),
      // SettingCustom(
      //   title: () => lang.usePitchBlack,
      //   keys: [settings.pitchBlackAdv],
      //   onReset: () => _onPitchBlackChanged(false),
      //   tile: (args) => _PitchBlackLevelTile(
      //     bgColor: args.bgColor,
      //   ),
      // ),
      SettingCustom(
        title: () => lang.defaultColor,
        aliases: () => [lang.defaultColorSubtitle],
        keys: [settings.staticColor],
        onReset: () => _DefaultColorTile._applyStoredColor(isDark: false),
        tile: (args) => _DefaultColorTile(
          bgColor: args.bgColor,
          isDark: false,
        ),
      ),
      SettingCustom(
        title: () => "${lang.defaultColor} (${lang.themeModeDark})",
        aliases: () => [lang.defaultColorSubtitle],
        keys: [settings.staticColorDark],
        onReset: () => _DefaultColorTile._applyStoredColor(isDark: true),
        tile: (args) => _DefaultColorTile(
          bgColor: args.bgColor,
          isDark: true,
        ),
      ),
    ],
    [
      language,
    ],
  ];

  static bool _isAutoColorEnabled() => settings.autoColor.valueR;

  static void _refreshColors(bool _) => CurrentColor.inst.refreshColorsOfCurrentItem();

  static void _onPitchBlackChanged(bool _) {
    if (namida.isDarkMode) CurrentColor.inst.updateColorAfterThemeModeChange();
  }

  @override
  Widget build(BuildContext context) {
    final jellysButton = kAllowJellysInvasion
        ? SettingEntryTile(
            entry: _jellysInvasion,
            page: this,
          )
        : null;
    return SettingsCard(
      title: lang.themeSettings,
      subtitle: lang.themeSettingsSubtitle,
      icon: Broken.brush_2,
      trailing: jellysButton,
      child: SizedBox(
        width: context.width,
        child: SettingSectionsColumn(
          page: this,
        ),
      ),
    );
  }
}

class ToggleThemeModeContainer extends StatefulWidget {
  final double maxWidth;
  final double blurRadius;
  const ToggleThemeModeContainer({super.key, required this.maxWidth, this.blurRadius = 6.0});

  static void onThemeChangeTap(ThemeMode themeMode) async {
    settings.themeMode.save(themeMode);
    await Future.delayed(const Duration(milliseconds: kThemeAnimationDurationMS));
    CurrentColor.inst.updateColorAfterThemeModeChange();
    YoutubeMiniplayerUiController.inst.startDimTimer();
  }

  @override
  State<ToggleThemeModeContainer> createState() => _ToggleThemeModeContainerState();
}

class _ToggleThemeModeContainerState extends State<ToggleThemeModeContainer> {
  Widget? _cachedWidget;

  @override
  void didUpdateWidget(ToggleThemeModeContainer old) {
    super.didUpdateWidget(old);
    if (old.maxWidth != widget.maxWidth) {
      _cachedWidget = null;
    }
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
    // -- better fully isolate this widget, so that animations work smoothly outside theme animation hell
    if (_cachedWidget != null) return _cachedWidget!;
    const brConst = 8.0;
    const horizontalPaddingConst = 8.0;
    final itemsCount = ThemeMode.values.length;
    final bgSlideWidth = (widget.maxWidth / itemsCount) - horizontalPaddingConst;
    return _cachedWidget = RepaintBoundary(
      child: ObxO(
        rx: settings.themeMode,
        builder: (context, currentTheme) => Obx(
          (context) {
            final theme = AppThemes.inst.getAppTheme(CurrentColor.inst.color, !context.isDarkMode);
            return Container(
              decoration: BoxDecoration(
                color: Color.alphaBlend(theme.listTileTheme.textColor!.withOpacityExt(0.78), Colors.white.withOpacityExt(0.63)),
                borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                boxShadow: [
                  BoxShadow(color: theme.listTileTheme.iconColor!.withOpacityExt(0.31), spreadRadius: 1.0, blurRadius: widget.blurRadius, offset: const Offset(0, 2)),
                ],
              ),
              width: widget.maxWidth,
              padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: horizontalPaddingConst),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.fastLinearToSlowEaseIn,
                      alignment: _themeModeToAlignment(currentTheme),
                      child: Container(
                        width: bgSlideWidth,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withOpacityExt(0.71),
                          borderRadius: BorderRadius.circular(brConst.multipliedRadius),
                          // boxShadow: [
                          //   BoxShadow(color: Colors.black.withOpacityExt(0.39), spreadRadius: 1, blurRadius: 4, offset: Offset(0, 2)),
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
                              onTap: () => ToggleThemeModeContainer.onThemeChangeTap(e),
                              child: Icon(
                                e.toIcon(),
                                color: currentTheme == e ? theme.listTileTheme.iconColor : theme.colorScheme.surface.withOpacityExt(0.71),
                              ),
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
        ),
      ),
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  final Color? bgColor;

  const _ThemeModeTile({required this.bgColor});

  @override
  Widget build(BuildContext context) {
    final maxWidth = (Dimensions.inst.availableAppContentWidth * 0.4).withMaximum(248.0);
    return CustomListTile(
      bgColor: bgColor,
      icon: Broken.brush_4,
      title: lang.themeMode,
      trailingRaw: ToggleThemeModeContainer(
        maxWidth: maxWidth,
      ),
    );
  }
}

class _AutoColoringTile extends StatelessWidget {
  final Color? bgColor;

  const _AutoColoringTile({required this.bgColor});

  static void _applyAutoColor(bool isEnabled) {
    if (isEnabled) {
      CurrentColor.inst.refreshColorsOfCurrentItem();
    } else {
      CurrentColor.inst.updatePlayerColorFromColor(playerStaticColor);
      CurrentColor.inst.updateCurrentColorSchemeOfSubPages(playerStaticColor);
    }
  }

  void _onChanged(bool wasEnabled) {
    final isEnabled = !wasEnabled;
    settings.transaction(() {
      settings.autoColor.save(isEnabled);
      settings.performanceMode.save(PerformanceMode.custom);
    });
    _applyAutoColor(isEnabled);
  }

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: settings.autoColor,
      builder: (context, autoColor) => CustomSwitchListTile(
        bgColor: bgColor,
        icon: Broken.colorfilter,
        title: lang.autoColoring,
        subtitle: "${lang.autoColoringSubtitle}. ${lang.performanceNote}",
        value: autoColor,
        onChanged: _onChanged,
      ),
    );
  }
}

// class _PitchBlackLevelTile extends StatelessWidget {
//   final Color? bgColor;
//
//   const _PitchBlackLevelTile({required this.bgColor});
//
//   void _onChanged(int level) {
//     settings.pitchBlackAdv.save(level);
//     ThemeSetting._onPitchBlackChanged(true);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Obx(
//       (context) {
//         final level = settings.pitchBlackAdv.valueR ?? (settings.pitchBlack.valueR ? AppThemes.pitchBlackMaxLevel : 0);
//         return CustomListTile(
//           bgColor: bgColor,
//           icon: Broken.mirror,
//           title: lang.usePitchBlack,
//           subtitle: lang.usePitchBlackSubtitle,
//           trailing: NamidaWheelSlider(
//             max: AppThemes.pitchBlackMaxLevel,
//             initValue: level,
//             onValueChanged: _onChanged,
//             text: '$level/${AppThemes.pitchBlackMaxLevel}',
//           ),
//         );
//       },
//     );
//   }
// }

class _DefaultColorTile extends StatelessWidget {
  final Color? bgColor;
  final bool isDark;

  const _DefaultColorTile({required this.bgColor, required this.isDark});

  static void _applyStoredColor({required bool isDark}) {
    if (namida.isDarkMode != isDark) return;
    final color = isDark ? playerStaticColorDark : playerStaticColorLight;
    CurrentColor.inst.updatePlayerColorFromColor(color, false);
  }

  void _updateColor(Color color) {
    final setting = isDark ? settings.staticColorDark : settings.staticColor;
    setting.save(color.intValue);
    if (namida.isDarkMode == isDark) {
      CurrentColor.inst.updatePlayerColorFromColor(color, false);
    }
  }

  void _onDone(Color color) {
    _updateColor(color);
    NamidaNavigator.inst.closeDialog();
  }

  void _onRestoreDefault() {
    final defaultColor = isDark ? kMainColorDark : kMainColorLight;
    _onDone(defaultColor);
  }

  void _showPicker() {
    final initialColor = isDark ? playerStaticColorDark : playerStaticColorLight;
    final suggestedColors = CurrentColor.inst.getSuggestedColors();
    NamidaNavigator.inst.navigateDialog(
      dialog: NamidaColorPickerDialog(
        initialColor: initialColor,
        doneText: lang.done,
        onColorChangeEnd: _updateColor,
        themeFollowsColor: true,
        isAlphaAllowed: false,
        suggestedColors: suggestedColors,
        onDonePressed: _onDone,
        onRefreshButtonPressed: _onRestoreDefault,
        cancelButton: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = isDark ? "${lang.defaultColor} (${lang.themeModeDark})" : lang.defaultColor;
    final leading = isDark
        ? const StackedIcon(
            baseIcon: Broken.bucket,
            secondaryIcon: Broken.moon,
          )
        : null;
    final colorCircle = FittedBox(
      child: Obx(
        (context) {
          final color = isDark ? playerStaticColorDarkR : playerStaticColorLightR;
          return CircleAvatar(
            minRadius: 12.0,
            backgroundColor: color,
          );
        },
      ),
    );
    return ObxO(
      rx: settings.autoColor,
      builder: (context, autoColor) => CustomListTile(
        bgColor: bgColor,
        enabled: !autoColor,
        icon: isDark ? null : Broken.bucket,
        leading: leading,
        title: title,
        subtitle: lang.defaultColorSubtitle,
        trailingRaw: colorCircle,
        onTap: _showPicker,
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  final Color? bgColor;

  const _LanguageTile({required this.bgColor});

  void _showDialog(ThemeData theme) {
    const allLocalesPre = AppLocalizations.supportedLocales;
    final allLanguages = allLocalesPre.map(NamidaLanguage.fromLocale).toFixedList();
    allLanguages.sortBy((e) => e.name);

    final selectedLangRx = Language.inst.getCurrentLanguageOrDevice().obs;

    NamidaNavigator.inst.navigateDialog(
      onDisposing: selectedLangRx.close,
      dialog: CustomBlurryDialog(
        title: lang.language,
        normalTitleStyle: true,
        actions: [
          // NamidaButton(
          //   onTap: () async {
          //     final files = await NamidaFileBrowser.pickFile(note: lang.addLanguage, allowedExtensions: NamidaFileExtensionsWrapper.json);
          //     final path = files?.path;
          //     if (path != null) {
          //       try {
          //         final st = await File(path).readAsString();
          //         final map = jsonDecode(st);
          //         final didUpdate = await Language.inst.loadLanguage(path.getFilenameWOExt, map);
          //         if (didUpdate) {
          //           NamidaNavigator.inst.closeDialog();
          //         } else {
          //           snackyy(title: lang.error, message: 'Unknown Error', isError: true);
          //         }
          //       } catch (e) {
          //         snackyy(title: lang.error, message: e.toString(), isError: true);
          //       }
          //     }
          //   },
          //   text: lang.local,
          // ),
          const CancelButton(),
          NamidaButton(
            onTap: () => Language.inst.update(language: selectedLangRx.value).closeDialog(),
            text: lang.confirm,
          ),
        ],
        child: SizedBox(
          height: namida.height * 0.5,
          width: namida.width,
          child: SmoothSingleChildScrollView(
            child: Column(
              children: [
                ...allLanguages.map(
                  (e) => Padding(
                    padding: const EdgeInsets.all(3.0),
                    child: ObxO(
                      rx: selectedLangRx,
                      builder: (context, selectedLang) => ListTileWithCheckMark(
                        leading: Container(
                          padding: const EdgeInsets.all(4.0),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              width: 1.5,
                              color: theme.colorScheme.onSurface.withOpacityExt(0.39),
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
                            style: NText.medium.of(context),
                            children: e.country.isEmpty
                                ? null
                                : [
                                    TextSpan(
                                      text: " (${e.country})",
                                      style: NText.small.of(context),
                                    ),
                                  ],
                          ),
                        ),
                        active: e == selectedLang,
                        onTap: () => selectedLangRx.value = e,
                      ),
                    ),
                  ),
                ),
                CustomListTile(
                  icon: Broken.add_circle,
                  title: lang.addLanguage,
                  subtitle: lang.addLanguageSubtitle,
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
  }

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: Language.inst.currentLanguageRx,
      builder: (context, currentLanguage) => CustomListTile(
        bgColor: bgColor,
        icon: Broken.language_square,
        title: lang.language,
        subtitle: currentLanguage!.name,
        onTap: () => _showDialog(context.theme),
      ),
    );
  }
}

/// The flag lives in the extra settings, offered here too because this is where colors are looked for.
class _JellysInvasionButton extends StatelessWidget {
  const _JellysInvasionButton();

  static void _openOptionsDialog() {
    NamidaNavigator.inst.navigateDialog(
      dialog: const CustomBlurryDialog(
        title: 'Jellys Invasion',
        normalTitleStyle: true,
        actions: [
          DoneButton(),
        ],
        child: JellysFlagsTiles(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NamidaTooltip(
      message: () => 'Jellys Invasion',
      child: ObxO(
        rx: NamidaJellys.enabledRx,
        builder: (context, enabled) => NamidaInkWell(
          borderRadius: 8.0,
          padding: const EdgeInsets.all(4.0),
          onTap: () => NamidaJellys.setInvasion(!enabled),
          onLongPress: _openOptionsDialog,
          child: JellyMascot(
            height: 38.0,
            opacity: enabled ? 0.9 : 0.35,
          ),
        ),
      ),
    );
  }
}
