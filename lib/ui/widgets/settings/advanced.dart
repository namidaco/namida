import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings_card.dart';

class AdvancedSettings extends StatelessWidget {
  AdvancedSettings({super.key});

  final SettingsController stg = SettingsController.inst;
  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: Language.inst.ADVANCED_SETTINGS,
      subtitle: Language.inst.ADVANCED_SETTINGS_SUBTITLE,
      icon: Broken.hierarchy_3,
      // icon: Broken.danger,
      child: Column(
        children: [
          Obx(
            () => CustomListTile(
              leading: const StackedIcon(
                baseIcon: Broken.image,
                secondaryIcon: Broken.close_circle,
              ),
              title: Language.inst.CLEAR_IMAGE_CACHE,
              trailingText: Indexer.inst.artworksSizeInStorage.value.fileSizeFormatted,
              // trailing: Obx(
              //   () => Text(
              //     Indexer.inst.getImageCacheSize().fileSizeFormatted,
              //     style: Get.textTheme.displayMedium?.copyWith(color: context.theme.colorScheme.onBackground.withAlpha(200)),
              //   ),
              // ),
              onTap: () {
                Get.dialog(
                  CustomBlurryDialog(
                    isWarning: true,
                    normalTitleStyle: true,
                    bodyText: Language.inst.CLEAR_IMAGE_CACHE_WARNING,
                    actions: [
                      const CancelButton(),
                      ElevatedButton(
                        onPressed: () async {
                          Get.close(1);
                          await Indexer.inst.clearImageCache();
                        },
                        child: Text(Language.inst.CLEAR.toUpperCase()),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Obx(
            () => CustomListTile(
              leading: const StackedIcon(
                baseIcon: Broken.sound,
                secondaryIcon: Broken.close_circle,
              ),
              title: Language.inst.CLEAR_WAVEFORM_DATA,
              trailingText: Indexer.inst.waveformsSizeInStorage.value.fileSizeFormatted,
              onTap: () {
                Get.dialog(
                  CustomBlurryDialog(
                    isWarning: true,
                    normalTitleStyle: true,
                    title: Language.inst.CLEAR_WAVEFORM_DATA,
                    bodyText: Language.inst.CLEAR_WAVEFORM_DATA_WARNING,
                    actions: [
                      const CancelButton(),
                      ElevatedButton(
                        onPressed: () {
                          Get.close(1);
                          Indexer.inst.clearWaveformData();
                        },
                        child: Text(Language.inst.CLEAR.toUpperCase()),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Obx(
            () => CustomListTile(
              leading: const StackedIcon(
                baseIcon: Broken.video,
                secondaryIcon: Broken.close_circle,
              ),
              title: Language.inst.CLEAR_VIDEO_CACHE,
              trailingText: Indexer.inst.videosSizeInStorage.value.fileSizeFormatted,
              onTap: () {
                Get.dialog(
                  CustomBlurryDialog(
                    isWarning: true,
                    normalTitleStyle: true,
                    title: Language.inst.CLEAR_VIDEO_CACHE,
                    bodyText: Language.inst.CONFIRM,
                    actions: [
                      const CancelButton(),
                      ElevatedButton(
                        onPressed: () async {
                          Get.close(1);
                          await Indexer.inst.clearVideoCache();
                        },
                        child: Text(Language.inst.CLEAR.toUpperCase()),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
