import 'package:flutter/material.dart';

import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'package:namida/class/route.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings_card.dart';
import 'package:namida/youtube/class/sponsorblock.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/sponsorblock_controller.dart';

class SponsorBlockSettingsPage extends StatelessWidget with NamidaRouteWidget {
  const SponsorBlockSettingsPage({super.key});

  @override
  RouteType get route => RouteType.YOUTUBE_SPONSORBLOCK_SUBPAGE;

  SponsorBlockSettings get _currentConfigValue => settings.youtube.sponsorBlockSettings.value;
  RxBaseCore<SponsorBlockSettings> get _currentConfig => settings.youtube.sponsorBlockSettings;

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: lang.SPONSORBLOCK,
      subtitle: lang.SKIP_SPONSOR_SEGMENTS_IN_VIDEOS,
      icon: Broken.shield_slash,
      child: Column(
        children: [
          Obx(
            (context) => CustomSwitchListTile(
              icon: Broken.shield_slash,
              title: lang.ENABLE_SPONSORBLOCK,
              value: _currentConfig.valueR.enabled,
              onChanged: (isTrue) {
                final newConfigs = _currentConfigValue.copyWith(enabled: !isTrue);
                settings.youtube.save(sponsorBlockSettings: newConfigs);

                if (newConfigs.enabled) {
                  final currentItem = Player.inst.currentItem.value;
                  if (currentItem is YoutubeID) {
                    SponsorBlockController.inst.updateSegments(currentItem.id);
                    return;
                  }
                }
                SponsorBlockController.inst.clearSegments();
              },
            ),
          ),
          CustomListTile(
            leading: StackedIcon(
              baseIcon: Broken.forward,
              secondaryIcon: Broken.close_circle,
              secondaryIconSize: 12.0,
            ),
            title: lang.HIDE_SKIP_BUTTON_AFTER,
            trailing: Obx(
              (context) {
                final hideMS = _currentConfig.valueR.hideSkipButtonAfterMS;
                return NamidaWheelSlider(
                  min: 1000,
                  max: 15000,
                  stepper: 100,
                  initValue: hideMS,
                  onValueChanged: (val) => settings.youtube.save(
                    sponsorBlockSettings: _currentConfigValue.copyWith(
                      hideSkipButtonAfterMS: val,
                    ),
                  ),
                  text: hideMS >= 1000 ? "${hideMS / 1000}s" : "${hideMS}ms",
                );
              },
            ),
          ),
          CustomListTile(
            icon: Broken.weight_1,
            title: lang.MINIMUM_SEGMENT_DURATION,
            trailing: Obx(
              (context) {
                final minDur = _currentConfig.valueR.minimumSegmentDurationMS;
                return NamidaWheelSlider(
                  min: 0,
                  max: 60000,
                  stepper: 100,
                  initValue: minDur,
                  onValueChanged: (val) => settings.youtube.save(
                    sponsorBlockSettings: _currentConfigValue.copyWith(
                      minimumSegmentDurationMS: val,
                    ),
                  ),
                  text: minDur >= 1000 ? "${minDur / 1000}s" : "${minDur}ms",
                );
              },
            ),
          ),
          NamidaContainerDivider(
            margin: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          ),
          ...SponsorBlockCategory.values.map((category) {
            return Obx(
              (context) {
                final categoryConfig = _currentConfig.valueR.configs[category] ?? category.defaultConfig;
                return _SponsorBlockCategoryTile(
                  category: category,
                  config: categoryConfig,
                  onChanged: (newConfigs) {
                    final configMap = _currentConfigValue.configs;
                    configMap[category] = newConfigs;
                    final newSponsorBlockSettings = _currentConfigValue.copyWith(configs: configMap);
                    settings.youtube.save(sponsorBlockSettings: newSponsorBlockSettings);
                  },
                );
              },
            );
          }),
          NamidaContainerDivider(
            margin: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          ),
          Obx(
            (context) => CustomSwitchListTile(
              icon: Broken.status_up,
              title: lang.SKIP_COUNT_TRACKING,
              subtitle: '⤷ ${lang.SPONSORBLOCK_LEADERBOARD}',
              value: _currentConfig.valueR.trackSkipCount,
              onChanged: (isTrue) {
                final newConfigs = _currentConfigValue.copyWith(trackSkipCount: !isTrue);
                settings.youtube.save(sponsorBlockSettings: newConfigs);
              },
            ),
          ),
          Obx(
            (context) => CustomListTile(
              icon: Broken.global,
              title: lang.SERVER_ADDRESS,
              subtitle: _currentConfig.valueR.serverAddress ?? _currentConfig.valueR.defaultServerAddress,
              onTap: () {
                final controller = TextEditingController(text: _currentConfigValue.serverAddress);
                NamidaNavigator.inst.navigateDialog(
                  dialog: CustomBlurryDialog(
                    title: lang.SERVER_ADDRESS,
                    normalTitleStyle: true,
                    actions: [
                      const CancelButton(),
                      NamidaButton(
                        text: lang.SAVE,
                        onPressed: () {
                          final newConfigs = _currentConfigValue.copyWith(serverAddress: controller.text);
                          settings.youtube.save(sponsorBlockSettings: newConfigs);
                          NamidaNavigator.inst.closeDialog();
                        },
                      ),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: CustomTagTextField(
                        controller: controller,
                        hintText: _currentConfigValue.defaultServerAddress,
                        labelText: lang.SERVER_ADDRESS,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          CustomListTile(
            icon: Broken.info_circle,
            title: lang.ABOUT,
            subtitle: _currentConfigValue.defaultServerAddress.replaceFirst('https://', ''),
            onTap: () => NamidaLinkUtils.openLink(_currentConfigValue.defaultServerAddress),
          ),
        ],
      ),
    );
  }
}

class _SponsorBlockCategoryTile extends StatelessWidget {
  final SponsorBlockCategory category;
  final SponsorBlockCategoryConfig config;
  final void Function(SponsorBlockCategoryConfig) onChanged;

  const _SponsorBlockCategoryTile({
    required this.category,
    required this.config,
    required this.onChanged,
  });

  void _showActionPicker(BuildContext context) {
    final isPOI = category == SponsorBlockCategory.poi_highlight;
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        title: category.toText(),
        normalTitleStyle: true,
        trailingWidgets: [
          Obx(
            (context) {
              final categoryConfig = settings.youtube.sponsorBlockSettings.valueR.configs[category] ?? category.defaultConfig;
              return _ColorCircle(
                color: categoryConfig.color,
                onTap: () => _showColorPicker(context),
              );
            },
          ),
          SizedBox(width: 4.0),
        ],
        actions: const [
          DoneButton(),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: SponsorBlockAction.values.map((action) {
            if (isPOI && action == SponsorBlockAction.autoSkipOnce) return const SizedBox();
            final icon = action.toIcon();
            final text = action.toText();
            final leading = action == SponsorBlockAction.autoSkipOnce
                ? StackedIcon(
                    baseIcon: icon,
                    secondaryText: '①',
                    disableColor: true,
                    secondaryIconSize: 12.0,
                  )
                : null;
            return Padding(
              padding: const EdgeInsets.all(4.0),
              child: ListTileWithCheckMark(
                leading: leading,
                icon: icon,
                title: text,
                active: config.action == action,
                onTap: () {
                  onChanged(config.copyWith(action: action));
                  NamidaNavigator.inst.closeDialog();
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showColorPicker(BuildContext context) {
    var currentColor = config.color;

    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        title: lang.DEFAULT_COLOR,
        normalTitleStyle: true,
        actions: [
          NamidaIconButton(
            tooltip: () => lang.RESTORE_DEFAULTS,
            onPressed: () {
              onChanged(config.copyWith(color: category.defaultConfig.color));
              NamidaNavigator.inst.closeDialog();
            },
            icon: Broken.refresh,
          ),
          DoneButton(
            additional: () {
              onChanged(config.copyWith(color: currentColor));
            },
          ),
        ],
        child: ColorPicker(
          pickerColor: currentColor,
          onColorChanged: (color) => currentColor = color,
          hexInputBar: true,
          pickerAreaHeightPercent: 0.8,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomListTile(
      title: category.toText(),
      subtitle: config.action.toText(),
      leading: _ColorCircle(
        color: config.color,
        onTap: () => _showColorPicker(context),
      ),
      onTap: () => _showActionPicker(context),
    );
  }
}

class _ColorCircle extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;
  const _ColorCircle({required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TapDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 29.0,
            height: 29.0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
          SizedBox(
            width: 26.0,
            height: 26.0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
