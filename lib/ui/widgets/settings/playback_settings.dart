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
          value: settings.enableVideoPlayback.value,
          onChanged: (p0) async => await VideoController.inst.toggleVideoPlayback(),
        ),
      ),
      Obx(
        () => CustomListTile(
          enabled: settings.enableVideoPlayback.value,
          title: lang.VIDEO_PLAYBACK_SOURCE,
          icon: Broken.scroll,
          trailingText: settings.videoPlaybackSource.value.toText(),
          onTap: () {
            bool isEnabled(VideoPlaybackSource val) {
              return settings.videoPlaybackSource.value == val;
            }

            void tileOnTap(VideoPlaybackSource val) {
              settings.save(videoPlaybackSource: val);
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
                            subtitle: e.toSubtitle() ?? '',
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
          enabled: settings.enableVideoPlayback.value,
          title: lang.VIDEO_QUALITY,
          icon: Broken.story,
          trailingText: settings.youtubeVideoQualities.first,
          onTap: () {
            bool isEnabled(String val) => settings.youtubeVideoQualities.contains(val);

            void tileOnTap(String val, int index) {
              if (isEnabled(val)) {
                if (settings.youtubeVideoQualities.length == 1) {
                  showMinimumItemsSnack(1);
                } else {
                  settings.removeFromList(youtubeVideoQualities1: val);
                }
              } else {
                settings.save(youtubeVideoQualities: [val]);
              }
              // sorts and saves dec
              settings.youtubeVideoQualities.sortByReverse((e) => kStockVideoQualities.indexOf(e));
              settings.save(youtubeVideoQualities: settings.youtubeVideoQualities);
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
          enabled: settings.enableVideoPlayback.value,
          icon: Broken.video_tick,
          title: lang.LOCAL_VIDEO_MATCHING,
          trailingText: settings.localVideoMatchingType.value.toText(),
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
                        trailingText: settings.localVideoMatchingType.value.toText(),
                        onTap: () {
                          final e = settings.localVideoMatchingType.value.nextElement(LocalVideoMatchingType.values);
                          settings.save(localVideoMatchingType: e);
                        },
                      ),
                    ),
                    Obx(
                      () => CustomSwitchListTile(
                        icon: Broken.folder,
                        title: lang.SAME_DIRECTORY_ONLY,
                        value: settings.localVideoMatchingCheckSameDir.value,
                        onChanged: (isTrue) => settings.save(localVideoMatchingCheckSameDir: !isTrue),
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
          subtitle: settings.wakelockMode.value.toText(),
          icon: Broken.external_drive,
          onTap: () {
            final e = settings.wakelockMode.value.nextElement(WakelockMode.values);
            settings.save(wakelockMode: e);
          },
        ),
      ),
      Obx(
        () => CustomSwitchListTile(
          title: lang.DISPLAY_FAV_BUTTON_IN_NOTIFICATION,
          icon: Broken.heart_tick,
          value: settings.displayFavouriteButtonInNotification.value,
          onChanged: (val) {
            settings.save(displayFavouriteButtonInNotification: !val);
            Player.inst.refreshNotification();
            if (!val && kSdkVersion < 31) {
              Get.snackbar(lang.NOTE, lang.DISPLAY_FAV_BUTTON_IN_NOTIFICATION_SUBTITLE);
            }
          },
        ),
      ),
      Obx(
        () => CustomListTile(
          title: lang.ON_NOTIFICATION_TAP,
          trailingText: settings.onNotificationTapAction.value.toText(),
          icon: Broken.card,
          onTap: () {
            final element = settings.onNotificationTapAction.value.nextElement(NotificationTapAction.values);
            settings.save(onNotificationTapAction: element);
          },
        ),
      ),
      Obx(
        () => CustomSwitchListTile(
          icon: Broken.forward,
          title: lang.SKIP_SILENCE,
          onChanged: (value) async {
            final willBeTrue = !value;
            settings.save(playerSkipSilenceEnabled: willBeTrue);
            await Player.inst.setSkipSilenceEnabled(willBeTrue);
          },
          value: settings.playerSkipSilenceEnabled.value,
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
            settings.save(enableVolumeFadeOnPlayPause: !value);
            Player.inst.setVolume(settings.playerVolume.value);
          },
          value: settings.enableVolumeFadeOnPlayPause.value,
        ),
      ),
      Obx(
        () => CustomListTile(
          enabled: settings.enableVolumeFadeOnPlayPause.value,
          icon: Broken.play,
          title: lang.PLAY_FADE_DURATION,
          trailing: NamidaWheelSlider(
            totalCount: 1900 ~/ 50,
            initValue: settings.playerPlayFadeDurInMilli.value ~/ 50,
            itemSize: 2,
            squeeze: 0.4,
            onValueChanged: (val) {
              final v = (val * 50 + 100) as int;
              settings.save(playerPlayFadeDurInMilli: v);
            },
            text: "${settings.playerPlayFadeDurInMilli.value}ms",
          ),
        ),
      ),
      Obx(
        () => CustomListTile(
          enabled: settings.enableVolumeFadeOnPlayPause.value,
          icon: Broken.pause,
          title: lang.PAUSE_FADE_DURATION,
          trailing: NamidaWheelSlider(
            totalCount: 1900 ~/ 50,
            initValue: settings.playerPauseFadeDurInMilli.value ~/ 50,
            itemSize: 2,
            squeeze: 0.4,
            onValueChanged: (val) {
              final v = (val * 50 + 100) as int;
              settings.save(playerPauseFadeDurInMilli: v);
            },
            text: "${settings.playerPauseFadeDurInMilli.value}ms",
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
          onChanged: (value) => settings.save(playerPlayOnNextPrev: !value),
          value: settings.playerPlayOnNextPrev.value,
        ),
      ),
      Obx(
        () => CustomSwitchListTile(
          icon: Broken.repeat,
          title: lang.INFINITY_QUEUE_ON_NEXT_PREV,
          subtitle: lang.INFINITY_QUEUE_ON_NEXT_PREV_SUBTITLE,
          onChanged: (value) => settings.save(playerInfiniyQueueOnNextPrevious: !value),
          value: settings.playerInfiniyQueueOnNextPrevious.value,
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
              onChanged: (value) => settings.save(playerPauseOnVolume0: !value),
              value: settings.playerPauseOnVolume0.value,
            ),
          ),
          Obx(
            () => CustomSwitchListTile(
              icon: Broken.play_circle,
              title: lang.RESUME_IF_WAS_PAUSED_BY_VOLUME,
              onChanged: (value) => settings.save(playerResumeAfterOnVolume0Pause: !value),
              value: settings.playerResumeAfterOnVolume0Pause.value,
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
                    final actionInSetting = settings.playerOnInterrupted[type] ?? InterruptionAction.pause;
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
                                final actionInSetting = settings.playerOnInterrupted[type] ?? InterruptionAction.pause;
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
                  onSelected: (action) => settings.updatePlayerInterruption(type, action),
                ),
              );
            },
          ),
          const NamidaContainerDivider(margin: EdgeInsets.symmetric(horizontal: 16.0)),
          Obx(
            () => CustomSwitchListTile(
              icon: Broken.play_circle,
              value: settings.playerResumeAfterWasInterrupted.value,
              onChanged: (isTrue) => settings.save(playerResumeAfterWasInterrupted: !isTrue),
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
          onChanged: (value) => settings.save(jumpToFirstTrackAfterFinishingQueue: !value),
          value: settings.jumpToFirstTrackAfterFinishingQueue.value,
        ),
      ),
      Obx(
        () => CustomListTile(
          icon: Broken.forward_5_seconds,
          title: "${lang.SEEK_DURATION} (${settings.isSeekDurationPercentage.value ? lang.PERCENTAGE : lang.SECONDS})",
          subtitle: lang.SEEK_DURATION_INFO,
          onTap: () => settings.save(isSeekDurationPercentage: !settings.isSeekDurationPercentage.value),
          trailing: settings.isSeekDurationPercentage.value
              ? NamidaWheelSlider(
                  totalCount: 50,
                  initValue: settings.seekDurationInPercentage.value,
                  itemSize: 2,
                  squeeze: 0.4,
                  onValueChanged: (val) {
                    final v = (val) as int;
                    settings.save(seekDurationInPercentage: v);
                  },
                  text: "${settings.seekDurationInPercentage.value}%",
                )
              : NamidaWheelSlider(
                  totalCount: 120,
                  initValue: settings.seekDurationInSeconds.value,
                  itemSize: 2,
                  squeeze: 0.4,
                  onValueChanged: (val) {
                    final v = (val) as int;
                    settings.save(seekDurationInSeconds: v);
                  },
                  text: "${settings.seekDurationInSeconds.value}s",
                ),
        ),
      ),
      Obx(
        () {
          final valInSet = settings.minTrackDurationToRestoreLastPosInMinutes.value;
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
                settings.save(minTrackDurationToRestoreLastPosInMinutes: v);
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
                          initValue: settings.isTrackPlayedSecondsCount.value - 20,
                          itemSize: 6,
                          onValueChanged: (val) {
                            final v = (val + 20) as int;
                            settings.save(isTrackPlayedSecondsCount: v);
                          },
                          text: "${settings.isTrackPlayedSecondsCount.value}s",
                          topText: lang.SECONDS.capitalizeFirst,
                          textPadding: 8.0,
                        ),
                        Text(
                          lang.OR,
                          style: context.textTheme.displayMedium,
                        ),
                        NamidaWheelSlider(
                          totalCount: 80,
                          initValue: settings.isTrackPlayedPercentageCount.value - 20,
                          itemSize: 6,
                          onValueChanged: (val) {
                            final v = (val + 20) as int;
                            settings.save(isTrackPlayedPercentageCount: v);
                          },
                          text: "${settings.isTrackPlayedPercentageCount.value}%",
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
          trailingText: "${settings.isTrackPlayedSecondsCount.value}s | ${settings.isTrackPlayedPercentageCount.value}%",
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
