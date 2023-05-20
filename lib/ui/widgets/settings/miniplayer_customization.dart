import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class MiniplayerCustomization extends StatelessWidget {
  const MiniplayerCustomization({super.key});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: SettingsController.inst.useSettingCollapsedTiles.value,
      leading: const StackedIcon(
        baseIcon: Broken.brush,
        secondaryIcon: Broken.external_drive,
      ),
      title: Text(
        Language.inst.MINIPLAYER_CUSTOMIZATION,
        style: context.textTheme.displayMedium,
      ),
      trailing: const Icon(
        Broken.arrow_down_2,
      ),
      children: [
        Obx(
          () => CustomSwitchListTile(
            icon: Broken.slider_horizontal_1,
            title: Language.inst.ENABLE_PARTY_MODE,
            subtitle: Language.inst.ENABLE_PARTY_MODE_SUBTITLE,
            onChanged: (value) {
              // disable
              if (value) {
                SettingsController.inst.save(enablePartyModeInMiniplayer: false);
              }
              // pls lemme enable
              if (!value) {
                if (SettingsController.inst.didSupportNamida) {
                  SettingsController.inst.save(enablePartyModeInMiniplayer: true);
                } else {
                  Get.dialog(
                    CustomBlurryDialog(
                      normalTitleStyle: true,
                      title: 'uwu',
                      actions: [
                        NamidaSupportButton(
                          onPressed: () => Get.close(1),
                        ),
                      ],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onDoubleTap: () {
                              SettingsController.inst.save(didSupportNamida: true);
                            },
                            child: const Text('a- ano...'),
                          ),
                          const Text(
                            'this one is actually supposed to be for supporters, if you don\'t mind u can support namida and get the power to unleash this cool feature',
                          ),
                          GestureDetector(
                            onTap: () {
                              Get.close(1);
                              Get.dialog(
                                CustomBlurryDialog(
                                  normalTitleStyle: true,
                                  title: '!!',
                                  bodyText: "EH? YOU DON'T WANT TO SUPPORT?",
                                  actions: [
                                    NamidaSupportButton(
                                      title: Language.inst.YES,
                                      onPressed: () => Get.close(1),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        Get.close(1);
                                        Get.dialog(
                                          CustomBlurryDialog(
                                            title: 'kechi',
                                            bodyText: 'hidoii ಥ_ಥ here use it as much as u can, dw im not upset or anything ^^, or am i?',
                                            actions: [
                                              ElevatedButton(
                                                child: Text(Language.inst.UNLOCK.toUpperCase()),
                                                onPressed: () {
                                                  Get.close(1);
                                                  SettingsController.inst.save(enablePartyModeInMiniplayer: true);
                                                },
                                              ),
                                              ElevatedButton(
                                                child: Text(Language.inst.SUPPORT.toUpperCase()),
                                                onPressed: () {
                                                  Get.close(1);
                                                  launchUrlString(k_NAMIDA_SUPPORT_LINK);
                                                },
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      child: Text(Language.inst.NO),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: const Text('or you just wanna use it like that? mattaku'),
                          )
                        ],
                      ),
                    ),
                  );
                }
              }
            },
            value: SettingsController.inst.enablePartyModeInMiniplayer.value,
          ),
        ),
        Obx(
          () => CustomSwitchListTile(
            enabled: SettingsController.inst.enablePartyModeInMiniplayer.value,
            icon: Broken.colors_square,
            title: Language.inst.EDGE_COLORS_SWITCHING,
            onChanged: (value) {
              SettingsController.inst.save(enablePartyModeColorSwap: !value);
            },
            value: SettingsController.inst.enablePartyModeColorSwap.value,
          ),
        ),
        Obx(
          () => CustomSwitchListTile(
            icon: Broken.buy_crypto,
            title: Language.inst.ENABLE_MINIPLAYER_PARTICLES,
            onChanged: (value) => SettingsController.inst.save(enableMiniplayerParticles: !value),
            value: SettingsController.inst.enableMiniplayerParticles.value,
          ),
        ),
        Obx(
          () => CustomListTile(
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
        ),
        Obx(
          () => CustomSwitchListTile(
            icon: Broken.arrange_circle_2,
            title: Language.inst.ANIMATING_THUMBNAIL_INVERSED,
            subtitle: Language.inst.ANIMATING_THUMBNAIL_INVERSED_SUBTITLE,
            onChanged: (value) {
              SettingsController.inst.save(animatingThumbnailInversed: !value);
            },
            value: SettingsController.inst.animatingThumbnailInversed.value,
          ),
        ),
        Obx(
          () => CustomListTile(
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
        ),
        Obx(
          () => CustomSwitchListTile(
            icon: Broken.text_block,
            title: Language.inst.DISPLAY_AUDIO_INFO_IN_MINIPLAYER,
            onChanged: (value) => SettingsController.inst.save(displayAudioInfoMiniplayer: !value),
            value: SettingsController.inst.displayAudioInfoMiniplayer.value,
          ),
        ),
      ],
    );
  }
}
