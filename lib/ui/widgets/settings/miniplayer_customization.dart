import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class MiniplayerCustomization extends StatelessWidget {
  const MiniplayerCustomization({super.key});

  @override
  Widget build(BuildContext context) {
    return NamidaExpansionTile(
      initiallyExpanded: settings.useSettingCollapsedTiles.value,
      leading: const StackedIcon(
        baseIcon: Broken.brush,
        secondaryIcon: Broken.external_drive,
      ),
      titleText: lang.MINIPLAYER_CUSTOMIZATION,
      children: [
        Obx(
          () => CustomSwitchListTile(
            icon: Broken.slider_horizontal_1,
            title: lang.ENABLE_PARTY_MODE,
            subtitle: lang.ENABLE_PARTY_MODE_SUBTITLE,
            onChanged: (value) {
              // disable
              if (value) {
                settings.save(enablePartyModeInMiniplayer: false);
              }
              // pls lemme enable
              if (!value) {
                if (settings.didSupportNamida) {
                  settings.save(enablePartyModeInMiniplayer: true);
                } else {
                  NamidaNavigator.inst.navigateDialog(
                    dialog: CustomBlurryDialog(
                      normalTitleStyle: true,
                      title: 'uwu',
                      actions: const [NamidaSupportButton()],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onDoubleTap: () {
                              settings.save(didSupportNamida: true);
                            },
                            child: const Text('a- ano...'),
                          ),
                          const Text(
                            'this one is actually supposed to be for supporters, if you don\'t mind u can support namida and get the power to unleash this cool feature',
                          ),
                          GestureDetector(
                            onTap: () {
                              NamidaNavigator.inst.closeDialog();
                              NamidaNavigator.inst.navigateDialog(
                                dialog: CustomBlurryDialog(
                                  normalTitleStyle: true,
                                  title: '!!',
                                  bodyText: "EH? YOU DON'T WANT TO SUPPORT?",
                                  actions: [
                                    NamidaSupportButton(title: lang.YES),
                                    NamidaButton(
                                      text: lang.NO,
                                      onPressed: () {
                                        NamidaNavigator.inst.closeDialog();
                                        NamidaNavigator.inst.navigateDialog(
                                          dialog: CustomBlurryDialog(
                                            title: 'kechi',
                                            bodyText: 'hidoii ಥ_ಥ here use it as much as u can, dw im not upset or anything ^^, or am i?',
                                            actions: [
                                              NamidaButton(
                                                text: lang.UNLOCK.toUpperCase(),
                                                onPressed: () {
                                                  NamidaNavigator.inst.closeDialog();
                                                  settings.save(enablePartyModeInMiniplayer: true);
                                                },
                                              ),
                                              NamidaButton(
                                                text: lang.SUPPORT.toUpperCase(),
                                                onPressed: () {
                                                  NamidaNavigator.inst.closeDialog();
                                                  launchUrlString(AppSocial.DONATE_BUY_ME_A_COFFEE);
                                                },
                                              ),
                                            ],
                                          ),
                                        );
                                      },
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
            value: settings.enablePartyModeInMiniplayer.value,
          ),
        ),
        Obx(
          () => CustomSwitchListTile(
            enabled: settings.enablePartyModeInMiniplayer.value,
            icon: Broken.colors_square,
            title: lang.EDGE_COLORS_SWITCHING,
            onChanged: (value) {
              settings.save(enablePartyModeColorSwap: !value);
            },
            value: settings.enablePartyModeColorSwap.value,
          ),
        ),
        Obx(
          () => CustomSwitchListTile(
            icon: Broken.buy_crypto,
            title: lang.ENABLE_MINIPLAYER_PARTICLES,
            onChanged: (value) => settings.save(enableMiniplayerParticles: !value),
            value: settings.enableMiniplayerParticles.value,
          ),
        ),
        Obx(
          () => CustomListTile(
            icon: Broken.flash,
            title: lang.ANIMATING_THUMBNAIL_INTENSITY,
            trailing: NamidaWheelSlider(
              totalCount: 25,
              initValue: settings.animatingThumbnailIntensity.value,
              itemSize: 6,
              onValueChanged: (val) {
                settings.save(animatingThumbnailIntensity: val as int);
              },
              text: "${(settings.animatingThumbnailIntensity.value * 4).toStringAsFixed(0)}%",
            ),
          ),
        ),
        Obx(
          () => CustomSwitchListTile(
            icon: Broken.arrange_circle_2,
            title: lang.ANIMATING_THUMBNAIL_INVERSED,
            subtitle: lang.ANIMATING_THUMBNAIL_INVERSED_SUBTITLE,
            onChanged: (value) {
              settings.save(animatingThumbnailInversed: !value);
            },
            value: settings.animatingThumbnailInversed.value,
          ),
        ),
        Obx(
          () => CustomListTile(
            icon: Broken.sound,
            title: lang.WAVEFORM_BARS_COUNT,
            trailing: SizedBox(
              width: 80,
              child: Column(
                children: [
                  NamidaWheelSlider(
                    totalCount: 360,
                    initValue: settings.waveformTotalBars.value - 40,
                    itemSize: 6,
                    onValueChanged: (val) {
                      final v = (val + 40) as int;
                      settings.save(waveformTotalBars: v);
                    },
                    text: settings.waveformTotalBars.value.toString(),
                  ),
                ],
              ),
            ),
          ),
        ),
        Obx(
          () => CustomSwitchListTile(
            icon: Broken.text_block,
            title: lang.DISPLAY_AUDIO_INFO_IN_MINIPLAYER,
            onChanged: (value) => settings.save(displayAudioInfoMiniplayer: !value),
            value: settings.displayAudioInfoMiniplayer.value,
          ),
        ),
      ],
    );
  }
}
