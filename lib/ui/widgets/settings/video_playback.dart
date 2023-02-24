import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings_card.dart';

class VideoPlaybackSettings extends StatelessWidget {
  final bool disableSubtitle;
  const VideoPlaybackSettings({super.key, this.disableSubtitle = false});

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: Language.inst.VIDEO_PLAYBACK_SETTING,
      subtitle: disableSubtitle ? null : Language.inst.VIDEO_PLAYBACK_SETTING_SUBTITLE,
      icon: Broken.video,
      child: Column(
        children: [
          Obx(
            () => CustomSwitchListTile(
              title: Language.inst.ENABLE_VIDEO_PLAYBACK,
              icon: Broken.video,
              value: SettingsController.inst.enableVideoPlayback.value,
              onChanged: (p0) async => await VideoController.inst.toggleVideoPlaybackInSetting(),
            ),
          ),
          CustomListTile(
            title: Language.inst.VIDEO_PLAYBACK_SOURCE,
            onTap: () {
              bool isEnabled(int val) {
                return SettingsController.inst.videoPlaybackSource.value == val;
              }

              void tileOnTap(int val) {
                SettingsController.inst.save(videoPlaybackSource: val);
              }

              Get.dialog(
                CustomBlurryDialog(
                  title: Language.inst.VIDEO_PLAYBACK_SOURCE,
                  actions: [
                    IconButton(
                      onPressed: () => tileOnTap(0),
                      icon: const Icon(Broken.refresh),
                    ),
                    ElevatedButton(
                      onPressed: () => Get.close(1),
                      child: Text(Language.inst.DONE),
                    ),
                  ],
                  child: SizedBox(
                    width: Get.width,
                    height: Get.height / 2,
                    child: DefaultTextStyle(
                      style: context.textTheme.displaySmall!,
                      child: Obx(
                        () => ListView(
                          shrinkWrap: true,
                          children: [
                            Text.rich(
                              TextSpan(
                                text: "${Language.inst.AUTO}: ",
                                style: context.textTheme.displayMedium,
                                children: [
                                  TextSpan(
                                    text: Language.inst.VIDEO_PLAYBACK_SOURCE_AUTO_SUBTITLE,
                                    style: context.textTheme.displaySmall,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(
                              height: 12.0,
                            ),
                            Text.rich(
                              TextSpan(
                                text: "${Language.inst.VIDEO_PLAYBACK_SOURCE_LOCAL}: ",
                                style: context.textTheme.displayMedium,
                                children: [
                                  TextSpan(
                                    text: "${Language.inst.VIDEO_PLAYBACK_SOURCE_LOCAL_SUBTITLE}, ${Language.inst.VIDEO_PLAYBACK_SOURCE_LOCAL_EXAMPLE}: ",
                                    style: context.textTheme.displaySmall,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              Language.inst.VIDEO_PLAYBACK_SOURCE_LOCAL_EXAMPLE_SUBTITLE,
                              style: context.textTheme.displaySmall?.copyWith(fontSize: 10.0, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(
                              height: 12.0,
                            ),
                            Text.rich(
                              TextSpan(
                                text: "${Language.inst.VIDEO_PLAYBACK_SOURCE_YOUTUBE}: ",
                                style: context.textTheme.displayMedium,
                                children: [
                                  TextSpan(
                                    text: Language.inst.VIDEO_PLAYBACK_SOURCE_YOUTUBE_SUBTITLE,
                                    style: context.textTheme.displaySmall,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(
                              height: 18.0,
                            ),
                            ListTileWithCheckMark(
                              active: isEnabled(0),
                              title: Language.inst.AUTO,
                              onTap: () => tileOnTap(0),
                            ),
                            const SizedBox(
                              height: 12.0,
                            ),
                            ListTileWithCheckMark(
                              active: isEnabled(1),
                              title: Language.inst.VIDEO_PLAYBACK_SOURCE_LOCAL,
                              onTap: () => tileOnTap(1),
                            ),
                            const SizedBox(
                              height: 12.0,
                            ),
                            ListTileWithCheckMark(
                              active: isEnabled(2),
                              title: Language.inst.VIDEO_PLAYBACK_SOURCE_YOUTUBE,
                              onTap: () => tileOnTap(2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          CustomListTile(
            title: Language.inst.VIDEO_QUALITY,
            onTap: () {
              bool isEnabled(String val) {
                return SettingsController.inst.youtubeVideoQualities.toList().contains(val);
              }

              void tileOnTap(String val, int index) {
                if (isEnabled(val)) {
                  if (SettingsController.inst.youtubeVideoQualities.length == 1) {
                    Get.snackbar(Language.inst.MINIMUM_ONE_QUALITY, Language.inst.MINIMUM_ONE_QUALITY_SUBTITLE);
                  } else {
                    SettingsController.inst.removeFromList(youtubeVideoQualities1: val);
                  }
                } else {
                  SettingsController.inst.save(youtubeVideoQualities: [val]);
                }
                // sorts and saves dec
                SettingsController.inst.youtubeVideoQualities.sort((b, a) => kStockVideoQualities.indexOf(a).compareTo(kStockVideoQualities.indexOf(b)));
                SettingsController.inst.save(youtubeVideoQualities: SettingsController.inst.youtubeVideoQualities.toList());
              }

              Get.dialog(
                CustomBlurryDialog(
                  title: Language.inst.VIDEO_QUALITY,
                  actions: [
                    // IconButton(
                    //   onPressed: () => tileOnTap(0),
                    //   icon: const Icon(Broken.refresh),
                    // ),
                    ElevatedButton(
                      onPressed: () => Get.close(1),
                      child: Text(Language.inst.DONE),
                    ),
                  ],
                  child: SizedBox(
                    width: Get.width,
                    height: Get.height / 2,
                    child: DefaultTextStyle(
                      style: context.textTheme.displaySmall!,
                      child: Obx(
                        () => ListView(
                          shrinkWrap: true,
                          children: [
                            Text(Language.inst.VIDEO_QUALITY_SUBTITLE),
                            const SizedBox(
                              height: 12.0,
                            ),
                            Text("${Language.inst.NOTE}: ${Language.inst.VIDEO_QUALITY_SUBTITLE_NOTE}"),
                            const SizedBox(
                              height: 18.0,
                            ),
                            ...kStockVideoQualities
                                .asMap()
                                .entries
                                .map(
                                  (e) => Column(
                                    children: [
                                      const SizedBox(
                                        height: 12.0,
                                      ),
                                      ListTileWithCheckMark(
                                        tileColor: Colors.transparent,
                                        active: isEnabled(e.value),
                                        title: e.value,
                                        onTap: () => tileOnTap(e.value, e.key),
                                      ),
                                    ],
                                  ),
                                )
                                .toList(),
                            // ListTileWithCheckMark(
                            //   active: isEnabled('4k'),
                            //   title: Language.inst.AUTO,
                            //   onTap: () => tileOnTap('4k'),
                            // ),
                            // const SizedBox(
                            //   height: 12.0,
                            // ),
                            // ListTileWithCheckMark(
                            //   active: isEnabled(1),
                            //   title: Language.inst.VIDEO_PLAYBACK_SOURCE_LOCAL,
                            //   onTap: () => tileOnTap(1),
                            // ),
                            // const SizedBox(
                            //   height: 12.0,
                            // ),
                            // ListTileWithCheckMark(
                            //   active: isEnabled(2),
                            //   title: Language.inst.VIDEO_PLAYBACK_SOURCE_YOUTUBE,
                            //   onTap: () => tileOnTap(2),
                            // ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
