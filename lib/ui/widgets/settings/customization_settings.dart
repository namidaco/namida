
import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/dialogs/setting_dialog_with_text_field.dart';
import 'package:namida/ui/widgets/settings/album_tile_customization.dart';
import 'package:namida/ui/widgets/settings/miniplayer_customization.dart';
import 'package:namida/ui/widgets/settings/track_tile_customization.dart';
import 'package:namida/ui/widgets/settings_card.dart';

class CustomizationSettings extends StatelessWidget {
  CustomizationSettings({super.key});

  final SettingsController stg = SettingsController.inst;
  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: Language.inst.CUSTOMIZATIONS,
      subtitle: Language.inst.CUSTOMIZATIONS_SUBTITLE,
      icon: Broken.brush_1,
      child: Obx(
        () => Column(
          children: [
            CustomSwitchListTile(
              icon: Broken.drop,
              title: Language.inst.ENABLE_BLUR_EFFECT,
              subtitle: Language.inst.PERFORMANCE_NOTE,
              onChanged: (p0) {
                stg.save(enableBlurEffect: !p0);
              },
              value: stg.enableBlurEffect.value,
            ),
            CustomSwitchListTile(
              icon: Broken.sun_1,
              title: Language.inst.ENABLE_GLOW_EFFECT,
              subtitle: Language.inst.PERFORMANCE_NOTE,
              onChanged: (p0) {
                stg.save(enableGlowEffect: !p0);
              },
              value: stg.enableGlowEffect.value,
            ),
            CustomListTile(
              icon: Broken.rotate_left_1,
              title: Language.inst.BORDER_RADIUS_MULTIPLIER,
              trailingText: "${stg.borderRadiusMultiplier.value}",
              onTap: () {
                showSettingDialogWithTextField(
                  title: Language.inst.BORDER_RADIUS_MULTIPLIER,
                  borderRadiusMultiplier: true,
                  iconWidget: const Icon(Broken.rotate_left_1),
                );
              },
            ),
            CustomListTile(
              icon: Broken.text,
              title: Language.inst.FONT_SCALE,
              trailingText: "${(stg.fontScaleFactor.value * 100).toInt()}%",
              onTap: () {
                showSettingDialogWithTextField(
                  title: Language.inst.FONT_SCALE,
                  fontScaleFactor: true,
                  iconWidget: const Icon(Broken.text),
                );
              },
            ),
            CustomSwitchListTile(
              icon: Broken.clock,
              title: Language.inst.HOUR_FORMAT_12,
              onChanged: (p0) {
                stg.save(hourFormat12: !p0);
              },
              value: stg.hourFormat12.value,
            ),
            CustomListTile(
              icon: Broken.calendar_edit,
              title: Language.inst.DATE_TIME_FORMAT,
              trailingText: "${stg.dateTimeFormat}",
              onTap: () {
                showSettingDialogWithTextField(
                    title: Language.inst.DATE_TIME_FORMAT,
                    iconWidget: const Icon(Broken.calendar_edit),
                    dateTimeFormat: true,
                    topWidget: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: kDefaultDateTimeStrings.entries
                          .map(
                            (e) => RadioListTile<String>(
                              activeColor: context.theme.colorScheme.secondary,
                              groupValue: stg.dateTimeFormat.string,
                              value: e.key,
                              onChanged: (e) async {
                                if (e != null) {
                                  stg.dateTimeFormat.value = e;
                                  stg.save(dateTimeFormat: e);

                                  Get.close(1);
                                }
                              },
                              title: Text(
                                e.value,
                              ),
                            ),
                          )
                          .toList(),
                    ));
              },
            ),
            AlbumTileCustomization(),
            TrackTileCustomization(),
            const MiniplayerCustomization(),
          ],
        ),
      ),
    );
  }
}
