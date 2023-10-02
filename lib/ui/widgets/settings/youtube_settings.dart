import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings_card.dart';

class YoutubeSettings extends StatelessWidget {
  const YoutubeSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
        title: lang.YOUTUBE,
        subtitle: lang.YOUTUBE_SETTINGS_SUBTITLE,
        icon: Broken.video,
        child: Column(
          children: [
            Obx(
              () => CustomSwitchListTile(
                leading: const StackedIcon(
                  baseIcon: Broken.document,
                  secondaryIcon: Broken.global_refresh,
                  secondaryIconSize: 12.0,
                ),
                title: lang.YT_PREFER_NEW_COMMENTS,
                subtitle: lang.YT_PREFER_NEW_COMMENTS_SUBTITLE,
                value: settings.ytPreferNewComments.value,
                onChanged: (isTrue) => settings.save(ytPreferNewComments: !isTrue),
              ),
            ),
            Obx(
              () => CustomListTile(
                leading: const StackedIcon(
                  baseIcon: Broken.moon,
                  secondaryIcon: Broken.clock,
                  secondaryIconSize: 12.0,
                ),
                title: lang.DIM_MINIPLAYER_AFTER_SECONDS.replaceFirst(
                  '_SECONDS_',
                  "${settings.ytMiniplayerDimAfterSeconds.value}",
                ),
                trailing: NamidaWheelSlider<int>(
                  totalCount: 120,
                  initValue: settings.ytMiniplayerDimAfterSeconds.value,
                  itemSize: 4,
                  text: "${settings.ytMiniplayerDimAfterSeconds.value}s",
                  onValueChanged: (val) {
                    settings.save(ytMiniplayerDimAfterSeconds: val);
                  },
                ),
              ),
            ),
            Obx(
              () => CustomListTile(
                enabled: settings.ytMiniplayerDimAfterSeconds.value > 0,
                leading: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Broken.devices,
                      size: 24.0,
                      color: context.defaultIconColor(),
                    ),
                    // -- hide middle part
                    Container(
                      width: 7.0,
                      height: 7.0,
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: context.theme.scaffoldBackgroundColor,
                            blurRadius: 1.0,
                            offset: const Offset(0, 2.0),
                          ),
                        ],
                      ),
                    ),
                    // -- needle
                    Obx(
                      () {
                        const multiplier = 4.5;
                        const minus = multiplier / 2;
                        const height = 7.0;
                        const origin = height / 2;
                        return Transform.rotate(
                          origin: const Offset(0, origin),
                          angle: (settings.ytMiniplayerDimOpacity.value * multiplier) - minus,
                          child: Container(
                            width: 2.0,
                            height: height,
                            decoration: BoxDecoration(
                              color: context.defaultIconColor(),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                        );
                      },
                    )
                  ],
                ),
                title: lang.DIM_INTENSITY,
                trailing: NamidaWheelSlider<int>(
                  totalCount: 100,
                  initValue: (settings.ytMiniplayerDimOpacity.value * 100).round(),
                  itemSize: 4,
                  text: "${(settings.ytMiniplayerDimOpacity.value * 100).round()}%",
                  onValueChanged: (val) {
                    settings.save(ytMiniplayerDimOpacity: val / 100);
                  },
                ),
              ),
            ),
            Obx(
              () => CustomSwitchListTile(
                leading: const StackedIcon(
                  baseIcon: Broken.import,
                  secondaryIcon: Broken.tick_circle,
                  secondaryIconSize: 12.0,
                ),
                title: lang.DOWNLOADS_METADATA_TAGS,
                subtitle: lang.DOWNLOADS_METADATA_TAGS_SUBTITLE,
                value: settings.ytAutoExtractVideoTagsFromInfo.value,
                onChanged: (isTrue) => settings.save(ytAutoExtractVideoTagsFromInfo: !isTrue),
              ),
            ),
          ],
        ));
  }
}
