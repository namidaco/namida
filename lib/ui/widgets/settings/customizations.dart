import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/setting_dialog.dart';
import 'package:namida/ui/widgets/settings/album_tile_customization.dart';
import 'package:namida/ui/widgets/settings/track_tile_customization.dart';
import 'package:namida/ui/widgets/settings_card.dart';

class CustomizationSettings extends StatelessWidget {
  CustomizationSettings({super.key});

  final SettingsController stg = SettingsController.inst;
  @override
  Widget build(BuildContext context) {
    return Obx(
      () => SettingsCard(
        title: Language.inst.CUSTOMIZATIONS,
        subtitle: Language.inst.CUSTOMIZATIONS_SUBTITLE,
        icon: Broken.brush_1,
        child: Column(
          children: [
            CustomSwitchListTile(
              leading: Stack(
                children: [
                  ShaderMask(
                    shaderCallback: (rect) => LinearGradient(
                      stops: const [0.3, 0.9],
                      begin: Alignment.topLeft,
                      colors: [
                        context.theme.listTileTheme.iconColor!,
                        context.theme.listTileTheme.iconColor!.withAlpha(10),
                      ],
                    ).createShader(rect),
                    child: const Icon(
                      Broken.play,
                      color: Colors.white,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), boxShadow: [BoxShadow(color: context.theme.colorScheme.background, spreadRadius: 1)]),
                      child: Icon(
                        Broken.pause,
                        size: 12,
                        color: context.theme.listTileTheme.iconColor!,
                      ),
                    ),
                  )
                ],
              ),
              title: Language.inst.ENABLE_FADE_EFFECT_ON_PLAY_PAUSE,
              onChanged: (value) {
                SettingsController.inst.save(
                  enableVolumeFadeOnPlayPause: !value,
                );
              },
              value: SettingsController.inst.enableVolumeFadeOnPlayPause.value,
            ),
            CustomSwitchListTile(
              icon: Broken.drop,
              title: Language.inst.ENABLE_BLUR_EFFECT,
              onChanged: (p0) {
                stg.save(enableBlurEffect: !p0);
              },
              value: stg.enableBlurEffect.value,
            ),
            CustomSwitchListTile(
              icon: Broken.sun_1,
              title: Language.inst.ENABLE_GLOW_EFFECT,
              onChanged: (p0) {
                stg.save(enableGlowEffect: !p0);
              },
              value: stg.enableGlowEffect.value,
            ),
            CustomListTile(
              icon: Broken.rotate_left_1,
              title: Language.inst.BORDER_RADIUS_MULTIPLIER,
              trailing: Text(
                "${stg.borderRadiusMultiplier.value}",
                style: Get.textTheme.displayMedium?.copyWith(color: context.theme.colorScheme.onBackground.withAlpha(200)),
              ),
              onTap: () {
                showSettingDialogWithTextField(title: Language.inst.BORDER_RADIUS_MULTIPLIER, borderRadiusMultiplier: true);
              },
            ),
            CustomListTile(
              icon: Broken.text,
              title: Language.inst.FONT_SCALE,
              trailing: Text(
                "${(stg.fontScaleFactor.value * 100).toInt()}%",
                style: Get.textTheme.displayMedium?.copyWith(color: context.theme.colorScheme.onBackground.withAlpha(200)),
              ),
              onTap: () {
                showSettingDialogWithTextField(title: Language.inst.FONT_SCALE, fontScaleFactor: true);
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
              trailing: Text(
                "${stg.dateTimeFormat}",
                style: Get.textTheme.displayMedium?.copyWith(color: context.theme.colorScheme.onBackground.withAlpha(200)),
              ),
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
          ],
        ),
      ),
    );
  }
}
