import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings_card.dart';

class PlaybackSettings extends StatelessWidget {
  final bool isInDialog;
  const PlaybackSettings({super.key, this.isInDialog = false});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      Obx(
        () => CustomSwitchListTile(
          title: Language.inst.ENABLE_VIDEO_PLAYBACK,
          icon: Broken.video,
          value: SettingsController.inst.enableVideoPlayback.value,
          onChanged: (p0) async => await VideoController.inst.toggleVideoPlaybackInSetting(),
        ),
      ),
      Obx(
        () => CustomListTile(
          title: Language.inst.VIDEO_PLAYBACK_SOURCE,
          icon: Broken.scroll,
          trailingText: SettingsController.inst.videoPlaybackSource.value.toText(),
          onTap: () {
            bool isEnabled(int val) {
              return SettingsController.inst.videoPlaybackSource.value == val;
            }

            void tileOnTap(int val) {
              SettingsController.inst.save(videoPlaybackSource: val);
            }

            NamidaNavigator.inst.navigateDialog(
              CustomBlurryDialog(
                title: Language.inst.VIDEO_PLAYBACK_SOURCE,
                actions: [
                  IconButton(
                    onPressed: () => tileOnTap(0),
                    icon: const Icon(Broken.refresh),
                  ),
                  ElevatedButton(
                    onPressed: () => NamidaNavigator.inst.closeDialog(),
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
                            style: context.textTheme.displaySmall?.copyWith(fontSize: 10.0.multipliedFontScale, fontWeight: FontWeight.w600),
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
      ),
      Obx(
        () => CustomListTile(
          title: Language.inst.VIDEO_QUALITY,
          icon: Broken.story,
          trailingText: SettingsController.inst.youtubeVideoQualities.first,
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

            NamidaNavigator.inst.navigateDialog(
              CustomBlurryDialog(
                title: Language.inst.VIDEO_QUALITY,
                actions: [
                  // IconButton(
                  //   onPressed: () => tileOnTap(0),
                  //   icon: const Icon(Broken.refresh),
                  // ),
                  ElevatedButton(
                    onPressed: () => NamidaNavigator.inst.closeDialog(),
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
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      Obx(
        () => CustomListTile(
          title: '${Language.inst.KEEP_SCREEN_AWAKE_WHEN}:',
          subtitle: SettingsController.inst.wakelockMode.value.toText(),
          icon: Broken.external_drive,
          onTap: () => SettingsController.inst.wakelockMode.value.toggleSetting(),
        ),
      ),
      Obx(
        () => CustomSwitchListTile(
          title: Language.inst.DISPLAY_FAV_BUTTON_IN_NOTIFICATION,
          icon: Broken.heart_tick,
          value: SettingsController.inst.displayFavouriteButtonInNotification.value,
          onChanged: (val) {
            SettingsController.inst.save(displayFavouriteButtonInNotification: !val);
            Player.inst.updateMediaItemForce();
            if (!val && kSdkVersion < 31) {
              Get.snackbar(Language.inst.NOTE, Language.inst.DISPLAY_FAV_BUTTON_IN_NOTIFICATION_SUBTITLE);
            }
          },
        ),
      ),
      Obx(
        () => CustomSwitchListTile(
          leading: const StackedIcon(
            baseIcon: Broken.play,
            secondaryIcon: Broken.record,
          ),
          title: Language.inst.PLAY_AFTER_NEXT_PREV,
          onChanged: (value) => SettingsController.inst.save(playerPlayOnNextPrev: !value),
          value: SettingsController.inst.playerPlayOnNextPrev.value,
        ),
      ),
      Obx(
        () => CustomSwitchListTile(
          leading: const StackedIcon(
            baseIcon: Broken.play,
            secondaryIcon: Broken.pause,
          ),
          title: Language.inst.ENABLE_FADE_EFFECT_ON_PLAY_PAUSE,
          onChanged: (value) {
            SettingsController.inst.save(enableVolumeFadeOnPlayPause: !value);
            Player.inst.setVolume(SettingsController.inst.playerVolume.value);
          },
          value: SettingsController.inst.enableVolumeFadeOnPlayPause.value,
        ),
      ),
      Obx(
        () => CustomListTile(
          enabled: SettingsController.inst.enableVolumeFadeOnPlayPause.value,
          icon: Broken.play,
          title: Language.inst.PLAY_FADE_DURATION,
          trailing: NamidaWheelSlider(
            totalCount: 1900 ~/ 50,
            initValue: SettingsController.inst.playerPlayFadeDurInMilli.value ~/ 50,
            itemSize: 2,
            squeeze: 0.4,
            onValueChanged: (val) {
              final v = (val * 50 + 100) as int;
              SettingsController.inst.save(playerPlayFadeDurInMilli: v);
            },
            text: "${SettingsController.inst.playerPlayFadeDurInMilli.value}ms",
          ),
        ),
      ),
      Obx(
        () => CustomListTile(
          enabled: SettingsController.inst.enableVolumeFadeOnPlayPause.value,
          icon: Broken.pause,
          title: Language.inst.PAUSE_FADE_DURATION,
          trailing: NamidaWheelSlider(
            totalCount: 1900 ~/ 50,
            initValue: SettingsController.inst.playerPauseFadeDurInMilli.value ~/ 50,
            itemSize: 2,
            squeeze: 0.4,
            onValueChanged: (val) {
              final v = (val * 50 + 100) as int;
              SettingsController.inst.save(playerPauseFadeDurInMilli: v);
            },
            text: "${SettingsController.inst.playerPauseFadeDurInMilli.value}ms",
          ),
        ),
      ),
      Obx(
        () => CustomListTile(
          icon: Broken.forward_5_seconds,
          title: "${Language.inst.SEEK_DURATION} (${SettingsController.inst.isSeekDurationPercentage.value ? Language.inst.PERCENTAGE : Language.inst.SECONDS})",
          subtitle: Language.inst.SEEK_DURATION_INFO,
          onTap: () => SettingsController.inst.save(isSeekDurationPercentage: !SettingsController.inst.isSeekDurationPercentage.value),
          trailing: SettingsController.inst.isSeekDurationPercentage.value
              ? NamidaWheelSlider(
                  totalCount: 50,
                  initValue: SettingsController.inst.seekDurationInPercentage.value,
                  itemSize: 2,
                  squeeze: 0.4,
                  onValueChanged: (val) {
                    final v = (val) as int;
                    SettingsController.inst.save(seekDurationInPercentage: v);
                  },
                  text: "${SettingsController.inst.seekDurationInPercentage.value}%",
                )
              : NamidaWheelSlider(
                  totalCount: 120,
                  initValue: SettingsController.inst.seekDurationInSeconds.value,
                  itemSize: 2,
                  squeeze: 0.4,
                  onValueChanged: (val) {
                    final v = (val) as int;
                    SettingsController.inst.save(seekDurationInSeconds: v);
                  },
                  text: "${SettingsController.inst.seekDurationInSeconds.value}s",
                ),
        ),
      ),
      Obx(
        () {
          final valInSet = SettingsController.inst.minTrackDurationToRestoreLastPosInMinutes.value;
          return CustomListTile(
            icon: Broken.refresh_left_square,
            title: Language.inst.MIN_TRACK_DURATION_TO_RESTORE_LAST_POSITION,
            trailing: NamidaWheelSlider(
              totalCount: 120,
              initValue: valInSet,
              itemSize: 2,
              squeeze: 0.4,
              onValueChanged: (val) {
                final v = (val) as int;
                SettingsController.inst.save(minTrackDurationToRestoreLastPosInMinutes: v);
              },
              text: valInSet == 0 ? Language.inst.DONT_RESTORE_POSITION : "${valInSet}m",
            ),
          );
        },
      ),
      Obx(
        () => CustomListTile(
          icon: Broken.timer,
          title: Language.inst.MIN_VALUE_TO_COUNT_TRACK_LISTEN,
          onTap: () => NamidaNavigator.inst.navigateDialog(
            CustomBlurryDialog(
              title: Language.inst.CHOOSE,
              child: Column(
                children: [
                  Text(
                    Language.inst.MIN_VALUE_TO_COUNT_TRACK_LISTEN,
                    style: context.textTheme.displayLarge,
                  ),
                  const SizedBox(
                    height: 32.0,
                  ),
                  Obx(
                    () => Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        NamidaWheelSlider(
                          totalCount: 160,
                          initValue: SettingsController.inst.isTrackPlayedSecondsCount.value - 20,
                          itemSize: 6,
                          onValueChanged: (val) {
                            final v = (val + 20) as int;
                            SettingsController.inst.save(isTrackPlayedSecondsCount: v);
                          },
                          text: "${SettingsController.inst.isTrackPlayedSecondsCount.value}s",
                          topText: Language.inst.SECONDS.capitalizeFirst,
                          textPadding: 8.0,
                        ),
                        Text(
                          Language.inst.OR,
                          style: context.textTheme.displayMedium,
                        ),
                        NamidaWheelSlider(
                          totalCount: 80,
                          initValue: SettingsController.inst.isTrackPlayedPercentageCount.value - 20,
                          itemSize: 6,
                          onValueChanged: (val) {
                            final v = (val + 20) as int;
                            SettingsController.inst.save(isTrackPlayedPercentageCount: v);
                          },
                          text: "${SettingsController.inst.isTrackPlayedPercentageCount.value}%",
                          topText: Language.inst.PERCENTAGE,
                          textPadding: 8.0,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          trailingText: "${SettingsController.inst.isTrackPlayedSecondsCount.value}s | ${SettingsController.inst.isTrackPlayedPercentageCount.value}%",
        ),
      ),
    ];
    return SettingsCard(
      title: Language.inst.PLAYBACK_SETTING,
      subtitle: isInDialog ? null : Language.inst.PLAYBACK_SETTING_SUBTITLE,
      icon: Broken.play_cricle,
      child: isInDialog
          ? SizedBox(
              height: context.height * 0.7,
              width: context.width,
              child: ListView(
                padding: EdgeInsets.zero,
                children: children,
              ),
            )
          : Column(
              children: children,
            ),
    );
  }
}
