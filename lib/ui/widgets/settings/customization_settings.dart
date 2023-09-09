import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/dialogs/setting_dialog_with_text_field.dart';
import 'package:namida/ui/widgets/settings/album_tile_customization.dart';
import 'package:namida/ui/widgets/settings/miniplayer_customization.dart';
import 'package:namida/ui/widgets/settings/track_tile_customization.dart';
import 'package:namida/ui/widgets/settings_card.dart';

class CustomizationSettings extends StatelessWidget {
  const CustomizationSettings({super.key});

  SettingsController get stg => SettingsController.inst;

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: lang.CUSTOMIZATIONS,
      subtitle: lang.CUSTOMIZATIONS_SUBTITLE,
      icon: Broken.brush_1,
      child: Obx(
        () => Column(
          children: [
            CustomSwitchListTile(
              icon: Broken.drop,
              title: lang.ENABLE_BLUR_EFFECT,
              subtitle: lang.PERFORMANCE_NOTE,
              onChanged: (p0) {
                stg.save(enableBlurEffect: !p0);
              },
              value: stg.enableBlurEffect.value,
            ),
            CustomSwitchListTile(
              icon: Broken.sun_1,
              title: lang.ENABLE_GLOW_EFFECT,
              subtitle: lang.PERFORMANCE_NOTE,
              onChanged: (p0) {
                stg.save(enableGlowEffect: !p0);
              },
              value: stg.enableGlowEffect.value,
            ),
            CustomListTile(
              icon: Broken.rotate_left_1,
              title: lang.BORDER_RADIUS_MULTIPLIER,
              trailingText: "${stg.borderRadiusMultiplier.value}",
              onTap: () {
                showSettingDialogWithTextField(
                  title: lang.BORDER_RADIUS_MULTIPLIER,
                  borderRadiusMultiplier: true,
                  iconWidget: const Icon(Broken.rotate_left_1),
                );
              },
            ),
            CustomListTile(
              icon: Broken.text,
              title: lang.FONT_SCALE,
              trailingText: "${(stg.fontScaleFactor.value * 100).toInt()}%",
              onTap: () {
                showSettingDialogWithTextField(
                  title: lang.FONT_SCALE,
                  fontScaleFactor: true,
                  iconWidget: const Icon(Broken.text),
                );
              },
            ),
            CustomSwitchListTile(
              icon: Broken.clock,
              title: lang.HOUR_FORMAT_12,
              onChanged: (p0) {
                stg.save(hourFormat12: !p0);
              },
              value: stg.hourFormat12.value,
            ),
            CustomListTile(
              icon: Broken.calendar_edit,
              title: lang.DATE_TIME_FORMAT,
              trailingText: "${stg.dateTimeFormat}",
              onTap: () {
                final ScrollController scrollController = ScrollController();

                showSettingDialogWithTextField(
                    title: lang.DATE_TIME_FORMAT,
                    iconWidget: const Icon(Broken.calendar_edit),
                    dateTimeFormat: true,
                    topWidget: SizedBox(
                      height: Get.height * 0.4,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 58.0),
                        child: Stack(
                          children: [
                            SingleChildScrollView(
                              controller: scrollController,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ...kDefaultDateTimeStrings.entries.map(
                                    (e) => SmallListTile(
                                      title: e.value,
                                      active: stg.dateTimeFormat.value == e.key,
                                      onTap: () {
                                        stg.save(dateTimeFormat: e.key);
                                        NamidaNavigator.inst.closeDialog();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              bottom: 20,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8.0),
                                decoration: BoxDecoration(color: Get.theme.cardTheme.color, shape: BoxShape.circle),
                                child: NamidaIconButton(
                                  icon: Broken.arrow_circle_down,
                                  onPressed: () {
                                    scrollController.animateTo(
                                      scrollController.position.maxScrollExtent,
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
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
