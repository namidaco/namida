import 'package:flutter/material.dart';

import 'package:audio_service/audio_service.dart';

import 'package:namida/base/setting_subpage_provider.dart';
import 'package:namida/class/replay_gain_data.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/settings_search_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/controller/wakelock_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/circular_percentages.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings_card.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';

enum _PlaybackSettingsKeys with SettingKeysBase {
  enableVideoPlayback,
  videoSource,
  videoQuality,
  localVideoMatching,
  keepScreenAwake,
  displayFavButtonInNotif(NamidaFeaturesAvailablity.android),
  displayStopButtonInNotif(NamidaFeaturesAvailablity.android),
  displayArtworkOnLockscreen(NamidaFeaturesAvailablity.android12and_below),
  killPlayerAfterDismissing(NamidaFeaturesAvailablityGroup(items: [NamidaFeaturesAvailablity.android, NamidaFeaturesAvailablity.windows, NamidaFeaturesAvailablity.linux])),
  onNotificationTap(NamidaFeaturesAvailablity.android),
  dismissibleMiniplayer,
  replayGain,
  skipSilence(NamidaFeaturesAvailablity.android),
  gaplessPlayback,
  crossfade,
  fadeEffectOnPlayPause,
  autoPlayOnNextPrev,
  infinityQueue,
  onVolume0,
  onInterruption(NamidaFeaturesAvailablity.android),
  onConnect(NamidaFeaturesAvailablity.android),
  jumpToFirstTrackAfterFinishing,
  previousButtonReplays,
  seekDuration,
  minimumTrackDurToRestoreLastPosition,
  countListenAfter,
  ;

  @override
  final NamidaFeaturesAvailablityBase? availability;
  const _PlaybackSettingsKeys([this.availability]);
}

class PlaybackSettings extends SettingSubpageProvider {
  final bool isInDialog;
  const PlaybackSettings({super.key, super.initialItem, this.isInDialog = false});

  @override
  SettingSubpageEnum get settingPage => SettingSubpageEnum.playback;

  @override
  Map<SettingKeysBase, List<String>> get lookupMap => {
    _PlaybackSettingsKeys.enableVideoPlayback: [lang.enableVideoPlayback],
    _PlaybackSettingsKeys.videoSource: [lang.videoPlaybackSource],
    _PlaybackSettingsKeys.videoQuality: [lang.videoQuality],
    _PlaybackSettingsKeys.localVideoMatching: [lang.localVideoMatching],
    _PlaybackSettingsKeys.keepScreenAwake: [lang.keepScreenAwakeWhen],
    _PlaybackSettingsKeys.displayFavButtonInNotif: [lang.displayFavButtonInNotification],
    _PlaybackSettingsKeys.displayStopButtonInNotif: [lang.displayStopButtonInNotification],
    _PlaybackSettingsKeys.displayArtworkOnLockscreen: [lang.displayArtworkOnLockscreen],
    _PlaybackSettingsKeys.killPlayerAfterDismissing: [lang.killPlayerAfterDismissingApp],
    _PlaybackSettingsKeys.onNotificationTap: [lang.onNotificationTap],
    _PlaybackSettingsKeys.dismissibleMiniplayer: [lang.dismissibleMiniplayer],
    _PlaybackSettingsKeys.replayGain: [lang.normalizeAudio, lang.normalizeAudioSubtitle],
    _PlaybackSettingsKeys.skipSilence: [lang.skipSilence],
    _PlaybackSettingsKeys.gaplessPlayback: [lang.gaplessPlayback],
    _PlaybackSettingsKeys.crossfade: [lang.enableCrossfadeEffect, lang.crossfadeDuration, lang.crossfadeTriggerSeconds(seconds: 0)],
    _PlaybackSettingsKeys.fadeEffectOnPlayPause: [lang.enableFadeEffectOnPlayPause, lang.playFadeDuration, lang.pauseFadeDuration],
    _PlaybackSettingsKeys.autoPlayOnNextPrev: [lang.playAfterNextPrev],
    _PlaybackSettingsKeys.infinityQueue: [lang.infinityQueueOnNextPrev, lang.infinityQueueOnNextPrevSubtitle],
    _PlaybackSettingsKeys.onVolume0: [lang.onVolumeZero],
    _PlaybackSettingsKeys.onInterruption: [lang.onInterruption],
    _PlaybackSettingsKeys.onConnect: [lang.onDeviceConnect],
    _PlaybackSettingsKeys.jumpToFirstTrackAfterFinishing: [lang.jumpToFirstTrackAfterQueueFinish],
    _PlaybackSettingsKeys.previousButtonReplays: [lang.previousButtonReplays, lang.previousButtonReplaysSubtitle],
    _PlaybackSettingsKeys.seekDuration: [lang.seekDuration, lang.seekDurationInfo],
    _PlaybackSettingsKeys.minimumTrackDurToRestoreLastPosition: [lang.minTrackDurationToRestoreLastPosition],
    _PlaybackSettingsKeys.countListenAfter: [lang.minValueToCountTrackListen],
  };

  Widget getNormalizeAudioWidget() {
    return getItemWrapper(
      key: _PlaybackSettingsKeys.replayGain,
      child: CustomListTile(
        bgColor: getBgColor(_PlaybackSettingsKeys.replayGain),
        leading: const StackedIcon(
          baseIcon: Broken.airpods,
          secondaryIcon: Broken.voice_cricle,
        ),
        title: lang.normalizeAudio,
        subtitle: lang.normalizeAudioSubtitle,
        trailing: NamidaPopupWrapper(
          children: () => [
            ...ReplayGainType.valuesForPlatform.map(
              (e) {
                void onTap() async {
                  NamidaNavigator.inst.popMenu();

                  settings.player.save(replayGainType: e);

                  // -- safer to disable all first
                  Player.inst.loudnessEnhancer.setTargetGainTrack(0);
                  Player.inst.loudnessEnhancer.refreshEnabled();
                  Player.inst.setReplayGainLinearVolume(1.0);

                  if (e.isAnyEnabled) {
                    double? vol;
                    final currentItem = Player.inst.currentItem.value;
                    if (currentItem is Track) {
                      final gainData = currentItem.toTrackExt().gainData;
                      if (e.isLoudnessEnhancerEnabled) {
                        final gainToUse = gainData?.gainToUse;
                        if (gainToUse != null) Player.inst.loudnessEnhancer.setTargetGainTrack(gainToUse);
                      } else if (e.isVolumeEnabled) {
                        vol = gainData?.calculateGainAsVolume();
                      }
                    } else if (currentItem is YoutubeID) {
                      final streamsResult = await YoutubeInfoController.video.fetchVideoStreamsCache(currentItem.id);
                      final loudnessDb = streamsResult?.loudnessDBData?.loudnessDb;
                      if (loudnessDb != null) {
                        if (e.isLoudnessEnhancerEnabled) {
                          Player.inst.loudnessEnhancer.setTargetGainTrack(-loudnessDb.toDouble());
                        } else if (e.isVolumeEnabled) {
                          vol = ReplayGainData.convertGainToVolume(gain: -loudnessDb.toDouble());
                        }
                      }
                    }
                    vol ??= ReplayGainData.kDefaultFallbackVolume;
                    Player.inst.setReplayGainLinearVolume(vol);
                  }
                }

                return ObxO(
                  rx: settings.player.replayGainType,
                  builder: (context, replayGainType) => NamidaInkWell(
                    margin: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                    padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
                    borderRadius: 6.0,
                    bgColor: replayGainType == e ? context.theme.cardColor : null,
                    onTap: onTap,
                    child: Text(
                      e.toText(),
                      style: context.textTheme.displayMedium?.copyWith(fontSize: 14.0),
                    ),
                  ),
                );
              },
            ),
          ],
          child: ObxO(
            rx: settings.player.replayGainType,
            builder: (context, replayGainType) => Text(
              "${replayGainType.toText()}${replayGainType == ReplayGainType.platform_default ? '\n(${ReplayGainType.getPlatformDefault().toText()})' : ''}",
              style: context.textTheme.displayMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  // Widget _getInternalPlayerWidget() {
  //   return getItemWrapper(
  //     key: _PlaybackSettingsKeys.internalPlayer,
  //     child: ObxO(
  //       rx: settings.player.internalPlayer,
  //       builder: (context, pl) {
  //         String playerTitle = pl.name;
  //         if (pl == InternalPlayerType.auto) {
  //           final platformDefaultPlayer = InternalPlayerType.platformDefault;
  //           playerTitle = '$playerTitle (${platformDefaultPlayer.name})';
  //         }

  //         return CustomListTile(
  //           bgColor: getBgColor(_PlaybackSettingsKeys.internalPlayer),
  //           title: 'Internal Player: $playerTitle',
  //           // subtitle: pl.getInfoForAndroid(),
  //           icon: Broken.cpu,
  //           onTap: () {
  //             void tileOnTap(InternalPlayerType val) async {
  //               if (val == settings.player.internalPlayer.value) return;
  //               settings.player.save(internalPlayer: val);
  //             }

  //             NamidaNavigator.inst.navigateDialog(
  //               dialog: CustomBlurryDialog(
  //                 title: "Internal Player",
  //                 actions: [
  //                   IconButton(
  //                     onPressed: () => tileOnTap(InternalPlayerType.auto),
  //                     icon: const Icon(Broken.refresh),
  //                   ),
  //                   const DoneButton(),
  //                 ],
  //                 child: ObxO(
  //                   rx: settings.player.internalPlayer,
  //                   builder: (context, pl) {
  //                     return SuperSmoothListView(
  //                       padding: EdgeInsets.zero,
  //                       shrinkWrap: true,
  //                       children: [
  //                         ...InternalPlayerType.getAvailableForCurrentPlatform().map(
  //                           (e) => Padding(
  //                             padding: const EdgeInsets.only(bottom: 12.0),
  //                             child: ListTileWithCheckMark(
  //                               active: pl == e,
  //                               title: e.name,
  //                               subtitle: e.getInfoForAndroid(),
  //                               onTap: () => tileOnTap(e),
  //                             ),
  //                           ),
  //                         ),
  //                       ],
  //                     );
  //                   },
  //                 ),
  //               ),
  //             );
  //           },
  //         );
  //       },
  //     ),
  //   );
  // }

  Widget getAutoPlayOnNextPrevWidget() {
    return getItemWrapper(
      key: _PlaybackSettingsKeys.autoPlayOnNextPrev,
      child: Obx(
        (context) => CustomSwitchListTile(
          bgColor: getBgColor(_PlaybackSettingsKeys.autoPlayOnNextPrev),
          leading: const StackedIcon(
            baseIcon: Broken.play,
            secondaryIcon: Broken.record,
          ),
          title: lang.playAfterNextPrev,
          onChanged: (value) => settings.player.save(playOnNextPrev: !value),
          value: settings.player.playOnNextPrev.valueR,
        ),
      ),
    );
  }

  Widget getInfinityQueueOnNextPrevWidget() {
    return getItemWrapper(
      key: _PlaybackSettingsKeys.infinityQueue,
      child: Obx(
        (context) => CustomSwitchListTile(
          bgColor: getBgColor(_PlaybackSettingsKeys.infinityQueue),
          icon: Broken.repeat,
          title: lang.infinityQueueOnNextPrev,
          subtitle: lang.infinityQueueOnNextPrevSubtitle,
          onChanged: (value) => settings.player.save(infiniyQueueOnNextPrevious: !value),
          value: settings.player.infiniyQueueOnNextPrevious.valueR,
        ),
      ),
    );
  }

  Widget getJumpToFirstTrackAfterFinishingWidget() {
    return getItemWrapper(
      key: _PlaybackSettingsKeys.jumpToFirstTrackAfterFinishing,
      child: ObxO(
        rx: settings.player.enableGaplessPlayback,
        builder: (context, gaplessEnabled) => AnimatedEnabled(
          enabled: !gaplessEnabled,
          child: Obx(
            (context) => CustomSwitchListTile(
              bgColor: getBgColor(_PlaybackSettingsKeys.jumpToFirstTrackAfterFinishing),
              icon: Broken.rotate_left,
              title: lang.jumpToFirstTrackAfterQueueFinish + (gaplessEnabled ? '\n✓ ${lang.gaplessPlayback}' : ''),
              onChanged: (value) => settings.player.save(jumpToFirstTrackAfterFinishingQueue: !value),
              value: settings.player.jumpToFirstTrackAfterFinishingQueue.valueR || gaplessEnabled,
            ),
          ),
        ),
      ),
    );
  }

  Widget getPreviousButtonReplaysWidget() {
    return getItemWrapper(
      key: _PlaybackSettingsKeys.previousButtonReplays,
      child: Obx(
        (context) => CustomSwitchListTile(
          bgColor: getBgColor(_PlaybackSettingsKeys.previousButtonReplays),
          leading: const StackedIcon(
            baseIcon: Broken.previous,
            secondaryIcon: Broken.rotate_left,
            secondaryIconSize: 12.0,
          ),
          title: lang.previousButtonReplays,
          subtitle: lang.previousButtonReplaysSubtitle,
          onChanged: (value) => settings.save(previousButtonReplays: !value),
          value: settings.previousButtonReplays.valueR,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final children = <Widget>[
      getItemWrapper(
        key: _PlaybackSettingsKeys.enableVideoPlayback,
        child: Obx(
          (context) => CustomSwitchListTile(
            bgColor: getBgColor(_PlaybackSettingsKeys.enableVideoPlayback),
            title: lang.enableVideoPlayback,
            icon: Broken.video,
            value: settings.enableVideoPlayback.valueR,
            onChanged: (p0) async => await VideoController.inst.toggleVideoPlayback(),
          ),
        ),
      ),
      getItemWrapper(
        key: _PlaybackSettingsKeys.videoSource,
        child: Obx(
          (context) => CustomListTile(
            bgColor: getBgColor(_PlaybackSettingsKeys.videoSource),
            enabled: settings.enableVideoPlayback.valueR,
            title: lang.videoPlaybackSource,
            icon: Broken.scroll,
            trailingText: settings.videoPlaybackSource.valueR.toText(),
            onTap: () {
              void tileOnTap(VideoPlaybackSource val) => settings.save(videoPlaybackSource: val);
              NamidaNavigator.inst.navigateDialog(
                dialog: CustomBlurryDialog(
                  title: lang.videoPlaybackSource,
                  actions: [
                    IconButton(
                      onPressed: () => tileOnTap(VideoPlaybackSource.auto),
                      icon: const Icon(Broken.refresh),
                    ),
                    const DoneButton(),
                  ],
                  child: ObxO(
                    rx: settings.videoPlaybackSource,
                    builder: (context, videoPlaybackSource) => SuperSmoothListView(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      children: [
                        ...VideoPlaybackSource.values.map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: ListTileWithCheckMark(
                              active: videoPlaybackSource == e,
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
      ),
      getItemWrapper(
        key: _PlaybackSettingsKeys.videoQuality,
        child: Obx(
          (context) => CustomListTile(
            bgColor: getBgColor(_PlaybackSettingsKeys.videoQuality),
            enabled: settings.enableVideoPlayback.valueR,
            title: lang.videoQuality,
            icon: Broken.story,
            trailingText: settings.youtubeVideoQualities.valueR.first,
            onTap: () {
              void tileOnTap(String val, int index) {
                if (settings.youtubeVideoQualities.value.contains(val)) {
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
                settings.save(youtubeVideoQualities: settings.youtubeVideoQualities.value);
              }

              NamidaNavigator.inst.navigateDialog(
                dialog: CustomBlurryDialog(
                  title: lang.videoQuality,
                  actions: const [
                    // IconButton(
                    //   onPressed: () => tileOnTap(0),
                    //   icon: const Icon(Broken.refresh),
                    // ),
                    DoneButton(),
                  ],
                  child: DefaultTextStyle(
                    style: textTheme.displaySmall!,
                    child: Column(
                      children: [
                        Text(lang.videoQualitySubtitle),
                        const SizedBox(
                          height: 12.0,
                        ),
                        Text("${lang.note}: ${lang.videoQualitySubtitleNote}"),
                        const SizedBox(height: 18.0),
                        SizedBox(
                          width: namida.width,
                          height: namida.height * 0.4,
                          child: ObxO(
                            rx: settings.youtubeVideoQualities,
                            builder: (context, youtubeVideoQualities) => SuperSmoothListView(
                              padding: EdgeInsets.zero,
                              children: [
                                ...kStockVideoQualities.asMap().entries.map(
                                  (e) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: ListTileWithCheckMark(
                                      icon: Broken.story,
                                      active: youtubeVideoQualities.contains(e.value),
                                      title: e.value,
                                      onTap: () => tileOnTap(e.value, e.key),
                                    ),
                                  ),
                                ),
                              ],
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
      ),
      getItemWrapper(
        key: _PlaybackSettingsKeys.localVideoMatching,
        child: Obx(
          (context) => CustomListTile(
            bgColor: getBgColor(_PlaybackSettingsKeys.localVideoMatching),
            enabled: settings.enableVideoPlayback.valueR,
            icon: Broken.video_tick,
            title: lang.localVideoMatching,
            trailingText: settings.localVideoMatchingType.valueR.toText(),
            onTap: () {
              NamidaNavigator.inst.navigateDialog(
                dialog: CustomBlurryDialog(
                  title: lang.localVideoMatching,
                  actions: const [
                    DoneButton(),
                  ],
                  child: Column(
                    children: [
                      Obx(
                        (context) => CustomListTile(
                          icon: Broken.video_tick,
                          title: lang.matchingType,
                          trailingText: settings.localVideoMatchingType.valueR.toText(),
                          onTap: () {
                            final e = settings.localVideoMatchingType.value.nextElement(LocalVideoMatchingType.values);
                            settings.save(localVideoMatchingType: e);
                          },
                        ),
                      ),
                      Obx(
                        (context) => CustomSwitchListTile(
                          icon: Broken.folder,
                          title: lang.sameDirectoryOnly,
                          value: settings.localVideoMatchingCheckSameDir.valueR,
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
      ),
      getItemWrapper(
        key: _PlaybackSettingsKeys.keepScreenAwake,
        child: Obx(
          (context) => CustomListTile(
            bgColor: getBgColor(_PlaybackSettingsKeys.keepScreenAwake),
            title: '${lang.keepScreenAwakeWhen}:',
            subtitle: settings.wakelockMode.valueR.toText(),
            icon: Broken.external_drive,
            onTap: () {
              final e = settings.wakelockMode.value.nextElement(WakelockMode.values);
              settings.save(wakelockMode: e);
              WakelockController.inst.onSettingChanged();
            },
          ),
        ),
      ),
      getItemWrapper(
        key: _PlaybackSettingsKeys.displayFavButtonInNotif,
        child: Obx(
          (context) => CustomSwitchListTile(
            bgColor: getBgColor(_PlaybackSettingsKeys.displayFavButtonInNotif),
            title: lang.displayFavButtonInNotification,
            icon: Broken.heart_tick,
            value: settings.displayFavouriteButtonInNotification.valueR,
            onChanged: (val) {
              settings.save(displayFavouriteButtonInNotification: !val);
              Player.inst.refreshNotification();
              if (!val && NamidaFeaturesVisibility.displayFavButtonInNotifMightCauseIssue) {
                snackyy(title: lang.note, message: lang.displayFavButtonInNotificationSubtitle);
              }
            },
          ),
        ),
      ),
      getItemWrapper(
        key: _PlaybackSettingsKeys.displayStopButtonInNotif,
        child: Obx(
          (context) => CustomSwitchListTile(
            bgColor: getBgColor(_PlaybackSettingsKeys.displayStopButtonInNotif),
            title: lang.displayStopButtonInNotification,
            icon: Broken.close_circle,
            value: settings.displayStopButtonInNotification.valueR,
            onChanged: (val) {
              settings.save(displayStopButtonInNotification: !val);
              Player.inst.refreshNotification();
            },
          ),
        ),
      ),
      getItemWrapper(
        key: _PlaybackSettingsKeys.displayArtworkOnLockscreen,
        child: Obx(
          (context) => CustomSwitchListTile(
            bgColor: getBgColor(_PlaybackSettingsKeys.displayArtworkOnLockscreen),
            title: lang.displayArtworkOnLockscreen,
            leading: const StackedIcon(
              baseIcon: Broken.gallery,
              secondaryIcon: Broken.lock_circle,
            ),
            value: settings.player.lockscreenArtwork.valueR,
            onChanged: (val) {
              settings.player.save(lockscreenArtwork: !val);
              AudioService.setLockScreenArtwork(!val).then((_) => Player.inst.refreshNotification());
            },
          ),
        ),
      ),
      getItemWrapper(
        key: _PlaybackSettingsKeys.killPlayerAfterDismissing,
        child: Obx(
          (context) => CustomListTile(
            bgColor: getBgColor(_PlaybackSettingsKeys.killPlayerAfterDismissing),
            title: lang.killPlayerAfterDismissingApp,
            icon: Broken.forbidden_2,
            onTap: () {
              final element = settings.player.killAfterDismissingApp.value.nextElement(KillAppMode.values);
              settings.player.save(killAfterDismissingApp: element);
            },
            trailingText: settings.player.killAfterDismissingApp.valueR.toText(),
          ),
        ),
      ),
      getItemWrapper(
        key: _PlaybackSettingsKeys.onNotificationTap,
        child: Obx(
          (context) => CustomListTile(
            bgColor: getBgColor(_PlaybackSettingsKeys.onNotificationTap),
            title: lang.onNotificationTap,
            trailingText: settings.onNotificationTapAction.valueR.toText(),
            icon: Broken.card,
            onTap: () {
              final element = settings.onNotificationTapAction.value.nextElement(NotificationTapAction.values);
              settings.save(onNotificationTapAction: element);
            },
          ),
        ),
      ),

      getItemWrapper(
        key: _PlaybackSettingsKeys.dismissibleMiniplayer,
        child: Obx(
          (context) => CustomSwitchListTile(
            enabled: !Dimensions.inst.miniplayerIsWideScreen,
            bgColor: getBgColor(_PlaybackSettingsKeys.dismissibleMiniplayer),
            icon: Broken.sidebar_bottom,
            title: lang.dismissibleMiniplayer,
            onChanged: (value) => settings.save(dismissibleMiniplayer: !value),
            value: settings.dismissibleMiniplayer.valueR,
          ),
        ),
      ),
      getNormalizeAudioWidget(),
      getItemWrapper(
        key: _PlaybackSettingsKeys.skipSilence,
        child: ObxO(
          rx: settings.player.skipSilenceEnabled,
          builder: (context, skipSilenceEnabled) => CustomSwitchListTile(
            bgColor: getBgColor(_PlaybackSettingsKeys.skipSilence),
            icon: Broken.forward,
            title: lang.skipSilence,
            onChanged: (value) async {
              final willBeTrue = !value;
              settings.player.save(skipSilenceEnabled: willBeTrue);
              await Player.inst.setSkipSilenceEnabled(willBeTrue);
            },
            value: skipSilenceEnabled,
          ),
        ),
      ),
      getItemWrapper(
        key: _PlaybackSettingsKeys.gaplessPlayback,
        child: Obx(
          (context) => CustomSwitchListTile(
            bgColor: getBgColor(_PlaybackSettingsKeys.gaplessPlayback),
            icon: Broken.blend_2,
            title: "${lang.gaplessPlayback} (${lang.beta})",
            onChanged: (value) {
              settings.player.save(enableGaplessPlayback: !value);
              Player.inst.resetGaplessPlaybackData();
            },
            value: settings.player.enableGaplessPlayback.valueR,
          ),
        ),
      ),

      // -- Crossfade
      getItemWrapper(
        key: _PlaybackSettingsKeys.crossfade,
        child: NamidaExpansionTile(
          bgColor: getBgColor(_PlaybackSettingsKeys.crossfade),
          bigahh: true,
          normalRightPadding: true,
          borderless: true,
          initiallyExpanded: settings.player.enableCrossFade.value || initialItem == _PlaybackSettingsKeys.crossfade,
          leading: const StackedIcon(
            baseIcon: Broken.play,
            secondaryIcon: Broken.recovery_convert,
          ),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 12.0),
          iconColor: context.defaultIconColor(),
          titleText: lang.enableCrossfadeEffect,
          onExpansionChanged: (wasCollapsed) {
            if (wasCollapsed) {
              SussyBaka.monetize(onEnable: () => settings.player.save(enableCrossFade: true));
            } else {
              settings.player.save(enableCrossFade: false);
            }
          },
          trailingBuilder: (_) => Obx((context) {
            return CustomSwitch(active: settings.player.enableCrossFade.valueR);
          }),
          children: [
            Obx(
              (context) {
                final enableCrossFade = settings.player.enableCrossFade.valueR;
                final crossFadeDurationMS = settings.player.crossFadeDurationMS.valueR;
                return CustomListTile(
                  enabled: enableCrossFade,
                  icon: Broken.blend_2,
                  title: lang.crossfadeDuration,
                  trailing: NamidaWheelSlider(
                    min: 100,
                    max: 10000,
                    stepper: 100,
                    initValue: crossFadeDurationMS,
                    onValueChanged: (val) => settings.player.save(crossFadeDurationMS: val),
                    text: crossFadeDurationMS >= 1000 ? "${crossFadeDurationMS / 1000}s" : "${crossFadeDurationMS}ms",
                  ),
                );
              },
            ),
            ObxO(
              rx: settings.player.enableGaplessPlayback,
              builder: (context, gaplessEnabled) => Obx(
                (context) {
                  final crossFadeAutoTriggerSeconds = settings.player.crossFadeAutoTriggerSeconds.valueR;
                  return AnimatedEnabled(
                    enabled: !gaplessEnabled,
                    child: CustomListTile(
                      enabled: settings.player.enableCrossFade.valueR,
                      icon: Broken.blend,
                      title: crossFadeAutoTriggerSeconds == 0 ? lang.crossfadeTriggerSecondsDisabled : lang.crossfadeTriggerSeconds(seconds: crossFadeAutoTriggerSeconds),
                      subtitle: gaplessEnabled ? 'x ${lang.gaplessPlayback}' : null,
                      trailing: NamidaWheelSlider(
                        max: 30,
                        initValue: crossFadeAutoTriggerSeconds,
                        onValueChanged: (val) => settings.player.save(crossFadeAutoTriggerSeconds: val),
                        text: "${crossFadeAutoTriggerSeconds}s",
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      // -- Play/Pause Fade
      getItemWrapper(
        key: _PlaybackSettingsKeys.fadeEffectOnPlayPause,
        child: NamidaExpansionTile(
          bgColor: getBgColor(_PlaybackSettingsKeys.fadeEffectOnPlayPause),
          bigahh: true,
          normalRightPadding: true,
          borderless: true,
          initiallyExpanded: settings.player.enableVolumeFadeOnPlayPause.value || initialItem == _PlaybackSettingsKeys.fadeEffectOnPlayPause,
          leading: const StackedIcon(
            baseIcon: Broken.play,
            secondaryIcon: Broken.pause,
          ),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 12.0),
          iconColor: context.defaultIconColor(),
          titleText: lang.enableFadeEffectOnPlayPause,
          onExpansionChanged: (value) {
            settings.player.save(enableVolumeFadeOnPlayPause: value);
            Player.inst.setVolume(settings.player.volume.value);
          },
          trailingBuilder: (_) => Obx((context) => CustomSwitch(active: settings.player.enableVolumeFadeOnPlayPause.valueR)),
          children: [
            Obx(
              (context) => CustomListTile(
                enabled: settings.player.enableVolumeFadeOnPlayPause.valueR,
                icon: Broken.play,
                title: lang.playFadeDuration,
                trailing: NamidaWheelSlider(
                  min: 100,
                  max: 2000,
                  stepper: 50,
                  initValue: settings.player.playFadeDurInMilli.valueR,
                  onValueChanged: (val) => settings.player.save(playFadeDurInMilli: val),
                  text: "${settings.player.playFadeDurInMilli.valueR}ms",
                ),
              ),
            ),
            Obx(
              (context) => CustomListTile(
                enabled: settings.player.enableVolumeFadeOnPlayPause.valueR,
                icon: Broken.pause,
                title: lang.pauseFadeDuration,
                trailing: NamidaWheelSlider(
                  min: 100,
                  max: 2000,
                  stepper: 50,
                  initValue: settings.player.pauseFadeDurInMilli.valueR,
                  onValueChanged: (val) => settings.player.save(pauseFadeDurInMilli: val),
                  text: "${settings.player.pauseFadeDurInMilli.valueR}ms",
                ),
              ),
            ),
          ],
        ),
      ),
      getAutoPlayOnNextPrevWidget(),
      getInfinityQueueOnNextPrevWidget(),
      getItemWrapper(
        key: _PlaybackSettingsKeys.onVolume0,
        child: NamidaExpansionTile(
          bgColor: getBgColor(_PlaybackSettingsKeys.onVolume0),
          bigahh: true,
          childrenPadding: const EdgeInsets.symmetric(horizontal: 12.0),
          iconColor: context.defaultIconColor(),
          icon: Broken.volume_slash,
          titleText: lang.onVolumeZero,
          initiallyExpanded: initialItem == _PlaybackSettingsKeys.onVolume0,
          children: [
            Obx(
              (context) => CustomSwitchListTile(
                icon: Broken.pause_circle,
                title: lang.pausePlayback,
                onChanged: (value) => settings.player.save(pauseOnVolume0: !value),
                value: settings.player.pauseOnVolume0.valueR,
              ),
            ),
            Obx(
              (context) {
                final valInSet = settings.player.volume0ResumeThresholdMin.valueR;
                return CustomListTile(
                  icon: Broken.play_circle,
                  title: valInSet == 0
                      ? lang.resumeIfWasPausedByVolume
                      : valInSet <= -1
                      ? lang.dontResume
                      : lang.resumeIfWasPausedForLessThanNMin(number: settings.player.volume0ResumeThresholdMin.valueR),
                  trailing: NamidaWheelSlider(
                    max: 60,
                    extraValue: true,
                    initValue: valInSet,
                    onValueChanged: (val) {
                      settings.player.save(volume0ResumeThresholdMin: val);
                    },
                    text: valInSet == 0
                        ? lang.always
                        : valInSet <= -1
                        ? lang.never
                        : "${valInSet}m",
                  ),
                );
              },
            ),
          ],
        ),
      ),
      getItemWrapper(
        key: _PlaybackSettingsKeys.onInterruption,
        child: NamidaExpansionTile(
          bgColor: getBgColor(_PlaybackSettingsKeys.onInterruption),
          bigahh: true,
          childrenPadding: const EdgeInsets.symmetric(horizontal: 12.0),
          iconColor: context.defaultIconColor(),
          icon: Broken.notification_bing,
          titleText: lang.onInterruption,
          initiallyExpanded: initialItem == _PlaybackSettingsKeys.onInterruption,
          children: [
            ...InterruptionType.values.map(
              (type) {
                return CustomListTile(
                  icon: type.toIcon(),
                  title: type.toText(),
                  subtitle: type.toSubtitle(),
                  trailing: PopupMenuButton<InterruptionAction>(
                    child: Obx((context) {
                      final actionInSetting = settings.player.onInterrupted[type] ?? InterruptionAction.pause;
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
                                (context) {
                                  final actionInSetting = settings.player.onInterrupted[type] ?? InterruptionAction.pause;
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
                    onSelected: (action) => settings.player.updatePlayerInterruption(type, action),
                  ),
                );
              },
            ),
            const NamidaContainerDivider(margin: EdgeInsets.symmetric(horizontal: 16.0)),
            const SizedBox(height: 6.0),
            ObxO(
              rx: settings.player.interruptionResumeThresholdMin,
              builder: (context, valInSet) => CustomListTile(
                icon: Broken.play_circle,
                title: valInSet == 0
                    ? lang.resumeIfWasInterrupted
                    : valInSet <= -1
                    ? lang.dontResume
                    : lang.resumeIfWasPausedForLessThanNMin(number: valInSet),
                trailing: NamidaWheelSlider(
                  max: 60,
                  extraValue: true,
                  initValue: valInSet,
                  onValueChanged: (val) {
                    settings.player.save(interruptionResumeThresholdMin: val);
                  },
                  text: valInSet == 0
                      ? lang.always
                      : valInSet <= -1
                      ? lang.never
                      : "${valInSet}m",
                ),
              ),
            ),
            const SizedBox(height: 6.0),
          ],
        ),
      ),
      getItemWrapper(
        key: _PlaybackSettingsKeys.onConnect,
        child: NamidaExpansionTile(
          bgColor: getBgColor(_PlaybackSettingsKeys.onConnect),
          bigahh: true,
          childrenPadding: const EdgeInsets.symmetric(horizontal: 12.0),
          iconColor: context.defaultIconColor(),
          icon: Broken.electricity,
          titleText: lang.onDeviceConnect,
          initiallyExpanded: initialItem == _PlaybackSettingsKeys.onConnect,
          children: [
            ObxO(
              rx: settings.player.connectWiredResumeThresholdMin,
              builder: (context, valInSet) => CustomListTile(
                leading: const StackedIcon(
                  baseIcon: Broken.headphones,
                  secondaryIcon: Broken.play_circle,
                  secondaryIconSize: 13.0,
                ),
                title: lang.wiredDevice,
                subtitle: valInSet == 0
                    ? lang.resumeIfWasPausedByDeviceDisconnect
                    : valInSet <= -1
                    ? lang.dontResume
                    : lang.resumeIfWasPausedForLessThanNMin(number: valInSet),
                trailing: NamidaWheelSlider(
                  max: 120,
                  extraValue: true,
                  initValue: valInSet,
                  onValueChanged: (val) {
                    settings.player.save(connectWiredResumeThresholdMin: val);
                  },
                  text: valInSet == 0
                      ? lang.always
                      : valInSet <= -1
                      ? lang.never
                      : "${valInSet}m",
                ),
              ),
            ),
            ObxO(
              rx: settings.player.connectWirelessResumeThresholdMin,
              builder: (context, valInSet) => CustomListTile(
                leading: const StackedIcon(
                  baseIcon: Broken.airpods,
                  secondaryIcon: Broken.play_circle,
                  secondaryIconSize: 13.0,
                ),
                title: lang.wirelessDevice,
                subtitle: valInSet == 0
                    ? lang.resumeIfWasPausedByDeviceDisconnect
                    : valInSet <= -1
                    ? lang.dontResume
                    : lang.resumeIfWasPausedForLessThanNMin(number: valInSet),
                trailing: NamidaWheelSlider(
                  max: 120,
                  extraValue: true,
                  initValue: valInSet,
                  onValueChanged: (val) {
                    settings.player.save(connectWirelessResumeThresholdMin: val);
                  },
                  text: valInSet == 0
                      ? lang.always
                      : valInSet <= -1
                      ? lang.never
                      : "${valInSet}m",
                ),
              ),
            ),
          ],
        ),
      ),
      getJumpToFirstTrackAfterFinishingWidget(),
      getPreviousButtonReplaysWidget(),
      getItemWrapper(
        key: _PlaybackSettingsKeys.seekDuration,
        child: Obx(
          (context) => CustomListTile(
            bgColor: getBgColor(_PlaybackSettingsKeys.seekDuration),
            icon: Broken.forward_5_seconds,
            title: "${lang.seekDuration} (${settings.player.isSeekDurationPercentage.valueR ? lang.percentage : lang.seconds})",
            subtitle: lang.seekDurationInfo,
            onTap: () => settings.player.save(isSeekDurationPercentage: !settings.player.isSeekDurationPercentage.value),
            trailing: settings.player.isSeekDurationPercentage.valueR
                ? NamidaWheelSlider(
                    max: 50,
                    initValue: settings.player.seekDurationInPercentage.valueR,
                    onValueChanged: (val) => settings.player.save(seekDurationInPercentage: val),
                    text: "${settings.player.seekDurationInPercentage.valueR}%",
                  )
                : NamidaWheelSlider(
                    max: 120,
                    initValue: settings.player.seekDurationInSeconds.valueR,
                    onValueChanged: (val) => settings.player.save(seekDurationInSeconds: val),
                    text: "${settings.player.seekDurationInSeconds.valueR}s",
                  ),
          ),
        ),
      ),
      getItemWrapper(
        key: _PlaybackSettingsKeys.minimumTrackDurToRestoreLastPosition,
        child: Obx(
          (context) {
            final valInSet = settings.player.minTrackDurationToRestoreLastPosInMinutes.valueR;
            return CustomListTile(
              bgColor: getBgColor(_PlaybackSettingsKeys.minimumTrackDurToRestoreLastPosition),
              icon: Broken.refresh_left_square,
              title: lang.minTrackDurationToRestoreLastPosition,
              trailing: NamidaWheelSlider(
                max: 120,
                initValue: valInSet,
                onValueChanged: (val) => settings.player.save(minTrackDurationToRestoreLastPosInMinutes: val),
                extraValue: true,
                text: valInSet == 0
                    ? lang.alwaysRestore
                    : valInSet <= -1
                    ? lang.dontRestorePosition
                    : "${valInSet}m",
              ),
            );
          },
        ),
      ),
      getItemWrapper(
        key: _PlaybackSettingsKeys.countListenAfter,
        child: Obx(
          (context) => CustomListTile(
            bgColor: getBgColor(_PlaybackSettingsKeys.countListenAfter),
            icon: Broken.timer,
            title: lang.minValueToCountTrackListen,
            onTap: () => NamidaNavigator.inst.navigateDialog(
              dialog: CustomBlurryDialog(
                title: lang.choose,
                actions: const [
                  DoneButton(),
                ],
                child: Column(
                  children: [
                    Text(
                      lang.minValueToCountTrackListen,
                      style: textTheme.displayLarge,
                    ),
                    const SizedBox(
                      height: 32.0,
                    ),
                    Obx(
                      (context) => Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          NamidaWheelSlider(
                            min: 20,
                            max: 180,
                            initValue: settings.isTrackPlayedSecondsCount.valueR,
                            onValueChanged: (val) => settings.save(isTrackPlayedSecondsCount: val),
                            text: "${settings.isTrackPlayedSecondsCount.valueR}s",
                            topText: lang.seconds.capitalizeFirst(),
                            textPadding: 8.0,
                          ),
                          Text(
                            lang.or,
                            style: textTheme.displayMedium,
                          ),
                          NamidaWheelSlider(
                            min: 20,
                            max: 100,
                            initValue: settings.isTrackPlayedPercentageCount.valueR,
                            onValueChanged: (val) => settings.save(isTrackPlayedPercentageCount: val),
                            text: "${settings.isTrackPlayedPercentageCount.valueR}%",
                            topText: lang.percentage,
                            textPadding: 8.0,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            trailingText: "${settings.isTrackPlayedSecondsCount.valueR}s | ${settings.isTrackPlayedPercentageCount.valueR}%",
          ),
        ),
      ),
    ];
    return SettingsCard(
      title: lang.playbackSetting,
      subtitle: isInDialog ? null : lang.playbackSettingSubtitle,
      icon: Broken.play_cricle,
      trailing: const SizedBox(
        height: 48.0,
        child: VideosExtractingPercentage(),
      ),
      child: isInDialog
          ? SizedBox(
              height: context.height * 0.7,
              width: context.width,
              child: SuperSmoothListView(
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
