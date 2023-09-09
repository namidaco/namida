import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
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
          title: lang.ENABLE_VIDEO_PLAYBACK,
          icon: Broken.video,
          value: SettingsController.inst.enableVideoPlayback.value,
          onChanged: (p0) async => await VideoController.inst.toggleVideoPlayback(),
        ),
      ),
      Obx(
        () => CustomListTile(
          enabled: SettingsController.inst.enableVideoPlayback.value,
          title: lang.VIDEO_PLAYBACK_SOURCE,
          icon: Broken.scroll,
          trailingText: SettingsController.inst.videoPlaybackSource.value.toText(),
          onTap: () {
            bool isEnabled(VideoPlaybackSource val) {
              return SettingsController.inst.videoPlaybackSource.value == val;
            }

            void tileOnTap(VideoPlaybackSource val) {
              SettingsController.inst.save(videoPlaybackSource: val);
            }

            NamidaNavigator.inst.navigateDialog(
              dialog: CustomBlurryDialog(
                title: lang.VIDEO_PLAYBACK_SOURCE,
                actions: [
                  IconButton(
                    onPressed: () => tileOnTap(VideoPlaybackSource.auto),
                    icon: const Icon(Broken.refresh),
                  ),
                  NamidaButton(
                    text: lang.DONE,
                    onPressed: NamidaNavigator.inst.closeDialog,
                  ),
                ],
                child: Obx(
                  () => ListView(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    children: [
                      ...VideoPlaybackSource.values.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: ListTileWithCheckMark(
                            active: isEnabled(e),
                            title: e.toText(),
                            subtitle: e.toSubtitle(),
                            onTap: () => tileOnTap(e),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      Obx(
        () => CustomListTile(
          enabled: SettingsController.inst.enableVideoPlayback.value,
          title: lang.VIDEO_QUALITY,
          icon: Broken.story,
          trailingText: SettingsController.inst.youtubeVideoQualities.first,
          onTap: () {
            bool isEnabled(String val) => SettingsController.inst.youtubeVideoQualities.contains(val);

            void tileOnTap(String val, int index) {
              if (isEnabled(val)) {
                if (SettingsController.inst.youtubeVideoQualities.length == 1) {
                  showMinimumItemsSnack(1);
                } else {
                  SettingsController.inst.removeFromList(youtubeVideoQualities1: val);
                }
              } else {
                SettingsController.inst.save(youtubeVideoQualities: [val]);
              }
              // sorts and saves dec
              SettingsController.inst.youtubeVideoQualities.sortByReverse((e) => kStockVideoQualities.indexOf(e));
              SettingsController.inst.save(youtubeVideoQualities: SettingsController.inst.youtubeVideoQualities);
            }

            NamidaNavigator.inst.navigateDialog(
              dialog: CustomBlurryDialog(
                title: lang.VIDEO_QUALITY,
                actions: [
                  // IconButton(
                  //   onPressed: () => tileOnTap(0),
                  //   icon: const Icon(Broken.refresh),
                  // ),
                  NamidaButton(
                    text: lang.DONE,
                    onPressed: NamidaNavigator.inst.closeDialog,
                  ),
                ],
                child: DefaultTextStyle(
                  style: context.textTheme.displaySmall!,
                  child: Obx(
                    () => Column(
                      children: [
                        Text(lang.VIDEO_QUALITY_SUBTITLE),
                        const SizedBox(
                          height: 12.0,
                        ),
                        Text("${lang.NOTE}: ${lang.VIDEO_QUALITY_SUBTITLE_NOTE}"),
                        const SizedBox(height: 18.0),
                        SizedBox(
                          width: Get.width,
                          height: Get.height * 0.4,
                          child: ListView(
                            padding: EdgeInsets.zero,
                            children: [
                              ...kStockVideoQualities.asMap().entries.map(
                                    (e) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                                      child: ListTileWithCheckMark(
                                        active: isEnabled(e.value),
                                        title: e.value,
                                        onTap: () => tileOnTap(e.value, e.key),
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      ],
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
          enabled: SettingsController.inst.enableVideoPlayback.value,
          icon: Broken.video_tick,
          title: lang.LOCAL_VIDEO_MATCHING,
          trailingText: SettingsController.inst.localVideoMatchingType.value.toText(),
          onTap: () {
            NamidaNavigator.inst.navigateDialog(
              dialog: CustomBlurryDialog(
                title: lang.LOCAL_VIDEO_MATCHING,
                actions: [
                  NamidaButton(
                    text: lang.DONE,
                    onPressed: NamidaNavigator.inst.closeDialog,
                  ),
                ],
                child: Column(
                  children: [
                    Obx(
                      () => CustomListTile(
                        icon: Broken.video_tick,
                        title: lang.MATCHING_TYPE,
                        trailingText: SettingsController.inst.localVideoMatchingType.value.toText(),
                        onTap: SettingsController.inst.localVideoMatchingType.value.toggleSetting,
                      ),
                    ),
                    Obx(
                      () => CustomSwitchListTile(
                        icon: Broken.folder,
                        title: lang.SAME_DIRECTORY_ONLY,
                        value: SettingsController.inst.localVideoMatchingCheckSameDir.value,
                        onChanged: (isTrue) => SettingsController.inst.save(localVideoMatchingCheckSameDir: !isTrue),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      Obx(
        () => CustomListTile(
          title: '${lang.KEEP_SCREEN_AWAKE_WHEN}:',
          subtitle: SettingsController.inst.wakelockMode.value.toText(),
          icon: Broken.external_drive,
          onTap: () => SettingsController.inst.wakelockMode.value.toggleSetting(),
        ),
      ),
      Obx(
        () => CustomSwitchListTile(
          title: lang.DISPLAY_FAV_BUTTON_IN_NOTIFICATION,
          icon: Broken.heart_tick,
          value: SettingsController.inst.displayFavouriteButtonInNotification.value,
          onChanged: (val) {
            SettingsController.inst.save(displayFavouriteButtonInNotification: !val);
            Player.inst.refreshNotification();
            if (!val && kSdkVersion < 31) {
              Get.snackbar(lang.NOTE, lang.DISPLAY_FAV_BUTTON_IN_NOTIFICATION_SUBTITLE);
            }
          },
        ),
      ),
      Obx(
        () => CustomSwitchListTile(
          icon: Broken.forward,
          title: lang.SKIP_SILENCE,
          onChanged: (value) async {
            final willBeTrue = !value;
            SettingsController.inst.save(playerSkipSilenceEnabled: willBeTrue);
            await Player.inst.setSkipSilenceEnabled(willBeTrue);
          },
          value: SettingsController.inst.playerSkipSilenceEnabled.value,
        ),
      ),
      Obx(
        () => CustomSwitchListTile(
          leading: const StackedIcon(
            baseIcon: Broken.play,
            secondaryIcon: Broken.pause,
          ),
          title: lang.ENABLE_FADE_EFFECT_ON_PLAY_PAUSE,
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
          title: lang.PLAY_FADE_DURATION,
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
          title: lang.PAUSE_FADE_DURATION,
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
        () => CustomSwitchListTile(
          leading: const StackedIcon(
            baseIcon: Broken.play,
            secondaryIcon: Broken.record,
          ),
          title: lang.PLAY_AFTER_NEXT_PREV,
          onChanged: (value) => SettingsController.inst.save(playerPlayOnNextPrev: !value),
          value: SettingsController.inst.playerPlayOnNextPrev.value,
        ),
      ),
      NamidaExpansionTile(
        childrenPadding: const EdgeInsets.symmetric(horizontal: 12.0),
        iconColor: context.defaultIconColor(),
        icon: Broken.volume_slash,
        titleText: lang.ON_VOLUME_ZERO,
        children: [
          Obx(
            () => CustomSwitchListTile(
              icon: Broken.pause_circle,
              title: lang.PAUSE_PLAYBACK,
              onChanged: (value) => SettingsController.inst.save(playerPauseOnVolume0: !value),
              value: SettingsController.inst.playerPauseOnVolume0.value,
            ),
          ),
          Obx(
            () => CustomSwitchListTile(
              icon: Broken.play_circle,
              title: lang.RESUME_IF_WAS_PAUSED_BY_VOLUME,
              onChanged: (value) => SettingsController.inst.save(playerResumeAfterOnVolume0Pause: !value),
              value: SettingsController.inst.playerResumeAfterOnVolume0Pause.value,
            ),
          ),
        ],
      ),
      NamidaExpansionTile(
        childrenPadding: const EdgeInsets.symmetric(horizontal: 12.0),
        iconColor: context.defaultIconColor(),
        icon: Broken.notification_bing,
        titleText: lang.ON_INTERRUPTION,
        children: [
          ...InterruptionType.values.map(
            (type) {
              return CustomListTile(
                icon: type.toIcon(),
                title: type.toText(),
                subtitle: type.toSubtitle(),
                trailingRaw: PopupMenuButton<InterruptionAction>(
                  child: Obx(() {
                    final actionInSetting = SettingsController.inst.playerOnInterrupted[type] ?? InterruptionAction.pause;
                    return Text(actionInSetting.toText());
                  }),
                  itemBuilder: (context) => <PopupMenuItem<InterruptionAction>>[
                    ...InterruptionAction.values.map(
                      (action) => PopupMenuItem(
                        value: action,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Icon(action.toIcon(), size: 22.0),
                            const SizedBox(width: 6.0),
                            Text(action.toText()),
                            const Spacer(),
                            Obx(
                              () {
                                final actionInSetting = SettingsController.inst.playerOnInterrupted[type] ?? InterruptionAction.pause;
                                return NamidaCheckMark(
                                  size: 16.0,
                                  active: actionInSetting == action,
                                );
                              },
                            ),
                            const SizedBox(width: 6.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                  onSelected: (action) => SettingsController.inst.updatePlayerInterruption(type, action),
                ),
              );
            },
          ),
          const NamidaContainerDivider(margin: EdgeInsets.symmetric(horizontal: 16.0)),
          Obx(
            () => CustomSwitchListTile(
              icon: Broken.play_circle,
              value: SettingsController.inst.playerResumeAfterWasInterrupted.value,
              onChanged: (isTrue) => SettingsController.inst.save(playerResumeAfterWasInterrupted: !isTrue),
              title: lang.RESUME_IF_WAS_INTERRUPTED,
            ),
          ),
          const SizedBox(height: 6.0),
        ],
      ),
      Obx(
        () => CustomSwitchListTile(
          icon: Broken.rotate_left,
          title: lang.JUMP_TO_FIRST_TRACK_AFTER_QUEUE_FINISH,
          onChanged: (value) => SettingsController.inst.save(jumpToFirstTrackAfterFinishingQueue: !value),
          value: SettingsController.inst.jumpToFirstTrackAfterFinishingQueue.value,
        ),
      ),
      Obx(
        () => CustomListTile(
          icon: Broken.forward_5_seconds,
          title: "${lang.SEEK_DURATION} (${SettingsController.inst.isSeekDurationPercentage.value ? lang.PERCENTAGE : lang.SECONDS})",
          subtitle: lang.SEEK_DURATION_INFO,
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
            title: lang.MIN_TRACK_DURATION_TO_RESTORE_LAST_POSITION,
            trailing: NamidaWheelSlider(
              totalCount: 120,
              initValue: valInSet,
              itemSize: 2,
              squeeze: 0.4,
              onValueChanged: (val) {
                final v = (val) as int;
                SettingsController.inst.save(minTrackDurationToRestoreLastPosInMinutes: v);
              },
              text: valInSet == 0 ? lang.DONT_RESTORE_POSITION : "${valInSet}m",
            ),
          );
        },
      ),
      Obx(
        () => CustomListTile(
          icon: Broken.timer,
          title: lang.MIN_VALUE_TO_COUNT_TRACK_LISTEN,
          onTap: () => NamidaNavigator.inst.navigateDialog(
            dialog: CustomBlurryDialog(
              title: lang.CHOOSE,
              child: Column(
                children: [
                  Text(
                    lang.MIN_VALUE_TO_COUNT_TRACK_LISTEN,
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
                          topText: lang.SECONDS.capitalizeFirst,
                          textPadding: 8.0,
                        ),
                        Text(
                          lang.OR,
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
                          topText: lang.PERCENTAGE,
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
      title: lang.PLAYBACK_SETTING,
      subtitle: isInDialog ? null : lang.PLAYBACK_SETTING_SUBTITLE,
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
