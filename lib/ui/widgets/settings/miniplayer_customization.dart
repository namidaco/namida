import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class MiniplayerCustomization extends StatelessWidget {
  MiniplayerCustomization({super.key});

  final SettingsController stg = SettingsController.inst;
  @override
  Widget build(BuildContext context) {
    return Obx(
      () => ExpansionTile(
        initiallyExpanded: SettingsController.inst.useSettingCollapsedTiles.value,
        leading: const StackedIcon(
          baseIcon: Broken.brush,
          secondaryIcon: Broken.external_drive,
        ),
        title: Text(
          Language.inst.MINIPLAYER_CUSTOMIZATION,
          style: Get.textTheme.displayMedium,
        ),
        trailing: const Icon(
          Broken.arrow_down_2,
        ),
        children: [
          CustomListTile(
            icon: Broken.flash,
            title: Language.inst.ANIMATING_THUMBNAIL_INTENSITY,
            trailing: NamidaWheelSlider(
              totalCount: 25,
              initValue: SettingsController.inst.animatingThumbnailIntensity.value,
              itemSize: 6,
              onValueChanged: (val) {
                SettingsController.inst.save(animatingThumbnailIntensity: val as int);
              },
              text: "${(SettingsController.inst.animatingThumbnailIntensity.value * 4).toStringAsFixed(0)}%",
            ),
          ),
          CustomSwitchListTile(
            icon: Broken.arrange_circle_2,
            title: Language.inst.ANIMATING_THUMBNAIL_INVERSED,
            subtitle: Language.inst.ANIMATING_THUMBNAIL_INVERSED_SUBTITLE,
            onChanged: (value) {
              SettingsController.inst.save(
                animatingThumbnailInversed: !value,
              );
            },
            value: SettingsController.inst.animatingThumbnailInversed.value,
          ),
          CustomListTile(
            icon: Broken.sound,
            title: Language.inst.WAVEFORM_BARS_COUNT,
            trailing: SizedBox(
              width: 80,
              child: Column(
                children: [
                  NamidaWheelSlider(
                    totalCount: 360,
                    initValue: SettingsController.inst.waveformTotalBars.value - 40,
                    itemSize: 6,
                    onValueChanged: (val) {
                      final v = (val + 40) as int;
                      SettingsController.inst.save(waveformTotalBars: v);
                    },
                    text: SettingsController.inst.waveformTotalBars.value.toString(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
