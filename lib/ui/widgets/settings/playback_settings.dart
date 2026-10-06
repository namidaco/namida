import 'package:flutter/material.dart';

import 'package:audio_service/audio_service.dart';

import 'package:namida/base/setting_subpage_provider.dart';
import 'package:namida/class/eggs_data.dart';
import 'package:namida/class/replay_gain_data.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/audio_output_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/rhythm_controller.dart';
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
import 'package:namida/ui/widgets/disabled_by_pill.dart';
import 'package:namida/ui/widgets/settings_card.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart';

enum _PlaybackSettingsKeys with SettingKeysBase {
  enableVideoPlayback,
  videoSource,
  videoQuality,
  localVideoMatching,
  keepScreenAwake,
  notificationButtons(NamidaFeaturesAvailablity.android),
  displayArtworkOnLockscreen(NamidaFeaturesAvailablity.android12and_below),
  killPlayerAfterDismissing(NamidaFeaturesAvailablityGroup(items: [NamidaFeaturesAvailablity.android, NamidaFeaturesAvailablity.windows, NamidaFeaturesAvailablity.linux])),
  onNotificationTap(NamidaFeaturesAvailablity.android),
  dismissibleMiniplayer,
  soundControl,
  replayGain,
  skipSilence(NamidaFeaturesAvailablityGroup(items: [NamidaFeaturesAvailablity.android, NamidaFeaturesAvailablity.linux])),
  gaplessPlayback,
  crossfade,
  fadeEffectOnPlayPause,
  autoPlayOnNextPrev,
  infinityQueue,
  onVolume0,
  longPressSpeed,
  onInterruption(NamidaFeaturesAvailablity.android),
  onConnect(NamidaFeaturesAvailablity.android),
  jumpToFirstTrackAfterFinishing,
  previousButtonReplays,
  skipButtonsJumpChapters,
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
  Map<SettingKeysBase, List<String>> buildLookupMap() => {
    _PlaybackSettingsKeys.enableVideoPlayback: [lang.enableVideoPlayback],
    _PlaybackSettingsKeys.videoSource: [lang.videoPlaybackSource],
    _PlaybackSettingsKeys.videoQuality: [lang.videoQuality],
    _PlaybackSettingsKeys.localVideoMatching: [lang.localVideoMatching],
    _PlaybackSettingsKeys.keepScreenAwake: [lang.keepScreenAwakeWhen],
    _PlaybackSettingsKeys.notificationButtons: [lang.notificationButtons],
    _PlaybackSettingsKeys.displayArtworkOnLockscreen: [lang.displayArtworkOnLockscreen],
    _PlaybackSettingsKeys.killPlayerAfterDismissing: [lang.killPlayerAfterDismissingApp],
    _PlaybackSettingsKeys.onNotificationTap: [lang.onNotificationTap],
    _PlaybackSettingsKeys.dismissibleMiniplayer: [lang.dismissibleMiniplayer],
    _PlaybackSettingsKeys.soundControl: [
      lang.soundControl, lang.outputDevice, lang.bitPerfect, lang.usbDirect, lang.exclusiveMode, lang.signalPath, lang.equalizer, lang.preamp, //
      lang.speed, lang.pitch, lang.volume, lang.loudnessEnhancer, lang.monoAudio, //
    ],
    _PlaybackSettingsKeys.replayGain: [lang.normalizeAudio, lang.normalizeAudioSubtitle],
    _PlaybackSettingsKeys.skipSilence: [lang.skipSilence],
    _PlaybackSettingsKeys.gaplessPlayback: [lang.gaplessPlayback],
    _PlaybackSettingsKeys.crossfade: [lang.enableCrossfadeEffect, lang.crossfadeDuration, lang.crossfadeTriggerSeconds(seconds: 0), lang.style, lang.smart, lang.beatMatching],
    _PlaybackSettingsKeys.fadeEffectOnPlayPause: [lang.enableFadeEffectOnPlayPause, lang.playFadeDuration, lang.pauseFadeDuration],
    _PlaybackSettingsKeys.autoPlayOnNextPrev: [lang.playAfterNextPrev],
    _PlaybackSettingsKeys.infinityQueue: [lang.infinityQueueOnNextPrev, lang.infinityQueueOnNextPrevSubtitle],
    _PlaybackSettingsKeys.onVolume0: [lang.onVolumeZero],
    _PlaybackSettingsKeys.longPressSpeed: [lang.longPressAction, lang.speed],
    _PlaybackSettingsKeys.onInterruption: [lang.onInterruption, lang.duckAudio],
    _PlaybackSettingsKeys.onConnect: [lang.onDeviceConnect],
    _PlaybackSettingsKeys.jumpToFirstTrackAfterFinishing: [lang.jumpToFirstTrackAfterQueueFinish],
    _PlaybackSettingsKeys.previousButtonReplays: [lang.previousButtonReplays, lang.previousButtonReplaysSubtitle],
    _PlaybackSettingsKeys.skipButtonsJumpChapters: [lang.skipButtonsJumpChapters, lang.chapters],
    _PlaybackSettingsKeys.seekDuration: [lang.seekDuration, lang.seekDurationInfo],
    _PlaybackSettingsKeys.minimumTrackDurToRestoreLastPosition: [lang.minTrackDurationToRestoreLastPosition],
    _PlaybackSettingsKeys.countListenAfter: [lang.minValueToCountTrackListen],
  };

  Widget getNormalizeAudioWidget({bool isInEQPage = false}) {
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
        trailing: Padding(
          padding: isInEQPage ? const EdgeInsetsGeometry.only(right: 12.0) : EdgeInsetsGeometry.zero,
          child: NamidaPopupWrapper(
            childrenDefault: () => ReplayGainType.valuesForPlatform.map(
              (e) {
                void onTap() async {
                  NamidaNavigator.inst.popMenu();

                  settings.player.replayGainType.save(e);

                  // -- safer to disable all first
                  Player.inst.loudnessEnhancerExtended?.setTargetGainTrack(0);
                  Player.inst.loudnessEnhancerExtended?.refreshEnabled();
                  Player.inst.setReplayGainLinearVolume(1.0);

                  if (e.isAnyEnabled) {
                    double? vol;
                    final currentItem = Player.inst.currentItem.value;
                    if (currentItem is Track) {
                      final gainData = currentItem.toTrackExt().gainData;
                      if (e.isLoudnessEnhancerEnabled) {
                        final gainToUse = gainData?.gainToUse;
                        if (gainToUse != null) Player.inst.loudnessEnhancerExtended?.setTargetGainTrack(gainToUse);
                      } else if (e.isVolumeEnabled) {
                        vol = gainData?.calculateGainAsVolume();
                      }
                    } else if (currentItem is YoutubeID) {
                      final streamsResult = await YoutubeInfoController.video.fetchVideoStreamsCache(currentItem.id);
                      final loudnessDb = streamsResult?.loudnessDBData?.loudnessDb;
                      if (loudnessDb != null) {
                        if (e.isLoudnessEnhancerEnabled) {
                          Player.inst.loudnessEnhancerExtended?.setTargetGainTrack(-loudnessDb.toDouble());
                        } else if (e.isVolumeEnabled) {
                          vol = ReplayGainData.convertGainToVolume(gain: -loudnessDb.toDouble());
                        }
                      }
                    }
                    vol ??= ReplayGainData.kDefaultFallbackVolume;
                    Player.inst.setReplayGainLinearVolume(vol);
                  }
                }

                return NamidaPopupItem(
                  icon: Broken.airpods,
                  secondaryIcon: Broken.voice_cricle,
                  selected: e == settings.player.replayGainType.value,
                  title: e.toText(),
                  onTap: onTap,
                );
              },
            ),
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
  //               settings.player.internalPlayer.save(val);
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
          onChanged: (value) => settings.player.playOnNextPrev.save(!value),
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
          onChanged: (value) => settings.player.infiniyQueueOnNextPrevious.save(!value),
          value: settings.player.infiniyQueueOnNextPrevious.valueR,
        ),
      ),
    );
  }

  Widget getJumpToFirstTrackAfterFinishingWidget() {
    return getItemWrapper(
      key: _PlaybackSettingsKeys.jumpToFirstTrackAfterFinishing,
      child: Obx(
        (context) => CustomSwitchListTile(
          bgColor: getBgColor(_PlaybackSettingsKeys.jumpToFirstTrackAfterFinishing),
          icon: Broken.rotate_left,
          title: lang.jumpToFirstTrackAfterQueueFinish,
          onChanged: (value) => settings.player.jumpToFirstTrackAfterFinishingQueue.save(!value),
          value: settings.player.jumpToFirstTrackAfterFinishingQueue.valueR,
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
          onChanged: (value) => settings.previousButtonReplays.save(!value),
          value: settings.previousButtonReplays.valueR,
        ),
      ),
    );
  }

  Widget getSkipButtonsJumpChaptersWidget() {
    return getItemWrapper(
      key: _PlaybackSettingsKeys.skipButtonsJumpChapters,
      child: Obx(
        (context) => CustomSwitchListTile(
          bgColor: getBgColor(_PlaybackSettingsKeys.skipButtonsJumpChapters),
          icon: Broken.arrow_square_right,
          title: lang.skipButtonsJumpChapters,
          onChanged: (value) => settings.skipButtonsJumpChapters.save(!value),
          value: settings.skipButtonsJumpChapters.valueR,
        ),
      ),
    );
  }

  static String _getSoundControlSubtitle() => [lang.outputDevice, lang.bitPerfect, lang.equalizer, lang.speed, lang.pitch].join(', ');

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
              void tileOnTap(VideoPlaybackSource val) => settings.videoPlaybackSource.save(val);
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
                            padding: const EdgeInsets.all(3.0),
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
                  if (settings.youtubeVideoQualities.value.length == 1) {
                    showMinimumItemsSnack(1);
                  } else {
                    settings.youtubeVideoQualities.update((list) => list.remove(val));
                  }
                } else {
                  settings.youtubeVideoQualities.update((list) => list.addNoDuplicates(val));
                }
                // sorts and saves dec
                settings.youtubeVideoQualities.update((list) => list.sortByReverse((e) => kStockVideoQualities.indexOf(e)));
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
                                ...kStockVideoQualities.mapIndexed(
                                  (q, index) => Padding(
                                    padding: const EdgeInsets.all(3.0),
                                    child: ListTileWithCheckMark(
                                      icon: Broken.story,
                                      active: youtubeVideoQualities.contains(q),
                                      title: q,
                                      onTap: () => tileOnTap(q, index),
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
                            final menu = NamidaPopupWrapper(
                              childrenDefault: () => LocalVideoMatchingType.values.map(
                                (e) => NamidaPopupItem(
                                  icon: Broken.video_tick,
                                  title: e.toText(),
                                  selected: e == settings.localVideoMatchingType.value,
                                  onTap: () {
                                    settings.localVideoMatchingType.save(e);
                                    NamidaNavigator.inst.popMenu();
                                  },
                                ),
                              ),
                            );
                            menu.showPopupMenu(context);
                          },
                        ),
                      ),
                      Obx(
                        (context) => CustomSwitchListTile(
                          icon: Broken.folder,
                          title: lang.sameDirectoryOnly,
                          value: settings.localVideoMatchingCheckSameDir.valueR,
                          onChanged: (isTrue) => settings.localVideoMatchingCheckSameDir.save(!isTrue),
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
              final menu = NamidaPopupWrapper(
                childrenDefault: () => WakelockMode.values.map(
                  (e) => NamidaPopupItem(
                    icon: Broken.external_drive,
                    title: e.toText(),
                    selected: e == settings.wakelockMode.value,
                    onTap: () {
                      settings.wakelockMode.save(e);
                      WakelockController.inst.onSettingChanged();
                      NamidaNavigator.inst.popMenu();
                    },
                  ),
                ),
              );
              menu.showPopupMenu(context);
            },
          ),
        ),
      ),
      getItemWrapper(
        key: _PlaybackSettingsKeys.notificationButtons,
        child: ObxO(
          rx: settings.notificationButtons,
          builder: (context, notificationButtons) => CustomListTile(
            bgColor: getBgColor(_PlaybackSettingsKeys.notificationButtons),
            icon: Broken.notification_bing,
            title: lang.notificationButtons,
            subtitle: notificationButtons.map((e) => e.toText()).join(', '),
            trailing: const Icon(
              Broken.arrow_right_3,
              size: 18.0,
            ),
            onTap: () => NamidaNavigator.inst.navigateDialog(
              scale: 1.0,
              dialog: CustomBlurryDialog(
                title: "${lang.notificationButtons} (${lang.reorderable})",
                actions: const [
                  DoneButton(),
                ],
                child: SizedBox(
                  width: namida.width,
                  height: namida.height * 0.5,
                  child: const _NotificationButtonsEditor(),
                ),
              ),
            ),
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
              settings.player.lockscreenArtwork.save(!val);
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
              final menu = NamidaPopupWrapper(
                childrenDefault: () => KillAppMode.values.map(
                  (e) => NamidaPopupItem(
                    icon: Broken.forbidden_2,
                    title: e.toText(),
                    selected: e == settings.player.killAfterDismissingApp.value,
                    onTap: () {
                      settings.player.killAfterDismissingApp.save(e);
                      NamidaNavigator.inst.popMenu();
                    },
                  ),
                ),
              );
              menu.showPopupMenu(context);
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
              final menu = NamidaPopupWrapper(
                childrenDefault: () => NotificationTapAction.values.map(
                  (e) => NamidaPopupItem(
                    icon: Broken.card,
                    title: e.toText(),
                    selected: e == settings.onNotificationTapAction.value,
                    onTap: () {
                      settings.onNotificationTapAction.save(e);
                      NamidaNavigator.inst.popMenu();
                    },
                  ),
                ),
              );
              menu.showPopupMenu(context);
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
            onChanged: (value) => settings.dismissibleMiniplayer.save(!value),
            value: settings.dismissibleMiniplayer.valueR,
          ),
        ),
      ),
      getItemWrapper(
        key: _PlaybackSettingsKeys.soundControl,
        child: CustomListTile(
          bgColor: getBgColor(_PlaybackSettingsKeys.soundControl),
          icon: Broken.sound,
          title: lang.soundControl,
          subtitle: _getSoundControlSubtitle(),
          trailing: const Icon(
            Broken.arrow_right_3,
            size: 18.0,
          ),
          onTap: NamidaOnTaps.inst.openSoundControl,
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
              settings.player.skipSilenceEnabled.save(willBeTrue);
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
              settings.player.enableGaplessPlayback.save(!value);
              Player.inst.resetGaplessPlaybackData();
            },
            value: settings.player.enableGaplessPlayback.valueR,
          ),
        ),
      ),

      // -- Crossfade
      getItemWrapper(
        key: _PlaybackSettingsKeys.crossfade,
        child: _ForcedOffWrapper(
          option: AudioOutputForcedOff.crossfade,
          builder: (causePill) => NamidaExpansionTile(
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
            subtitle: causePill,
            onExpansionChanged: (wasCollapsed) {
              if (wasCollapsed) {
                SussyBaka.monetize(unlockable: EggUnlockable.crossfade, onEnable: () => settings.player.enableCrossFade.save(true));
              } else {
                settings.player.enableCrossFade.save(false);
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
                      onValueChanged: (val) => settings.player.crossFadeDurationMS.save(val),
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
                        subtitleWidget: gaplessEnabled
                            ? DisabledByPill(
                                icon: Broken.blend_2,
                                title: lang.gaplessPlayback,
                              )
                            : null,
                        trailing: NamidaWheelSlider(
                          max: 30,
                          initValue: crossFadeAutoTriggerSeconds,
                          onValueChanged: (val) => settings.player.crossFadeAutoTriggerSeconds.save(val),
                          text: "${crossFadeAutoTriggerSeconds}s",
                        ),
                      ),
                    );
                  },
                ),
              ),
              const _CrossfadeModeTile(),
            ],
          ),
        ),
      ),
      // -- Play/Pause Fade
      getItemWrapper(
        key: _PlaybackSettingsKeys.fadeEffectOnPlayPause,
        child: _ForcedOffWrapper(
          option: AudioOutputForcedOff.fadeOnPlayPause,
          builder: (causePill) => NamidaExpansionTile(
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
            subtitle: causePill,
            onExpansionChanged: (value) {
              settings.player.enableVolumeFadeOnPlayPause.save(value);
              Player.inst.setVolume(Player.inst.userPlayerVolumeForItem);
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
                    onValueChanged: (val) => settings.player.playFadeDurInMilli.save(val),
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
                    onValueChanged: (val) => settings.player.pauseFadeDurInMilli.save(val),
                    text: "${settings.player.pauseFadeDurInMilli.valueR}ms",
                  ),
                ),
              ),
            ],
          ),
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
                onChanged: (value) => settings.player.pauseOnVolume0.save(!value),
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
                      settings.player.volume0ResumeThresholdMin.save(val);
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
        key: _PlaybackSettingsKeys.longPressSpeed,
        child: ObxO(
          rx: settings.player.longPressSpeed,
          builder: (context, longPressSpeed) => CustomListTile(
            bgColor: getBgColor(_PlaybackSettingsKeys.longPressSpeed),
            icon: Broken.forward,
            title: '${lang.longPressAction}: ${lang.speed}',
            trailing: NamidaWheelSlider(
              initValue: (longPressSpeed * 100).round(),
              max: 2 * 100,
              onValueChanged: (val) {
                settings.player.longPressSpeed.save(val / 100);
              },
              text: "${longPressSpeed}x",
            ),
          ),
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
                  trailing: NamidaPopupWrapper(
                    childrenDefault: () => InterruptionAction.values.map(
                      (action) => NamidaPopupItem(
                        icon: action.toIcon(),
                        title: action.toText(),
                        selected: action == settings.player.onInterrupted.value[type],
                        onTap: () => settings.player.onInterrupted.update((actions) => actions[type] = action),
                      ),
                    ),
                    child: Obx(
                      (context) {
                        final actionInSetting = settings.player.onInterrupted.valueR[type] ?? InterruptionAction.pause;
                        return Text(
                          actionInSetting.toText(),
                          style: context.textTheme.displayMedium,
                        );
                      },
                    ),
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
                    settings.player.interruptionResumeThresholdMin.save(val);
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
                    settings.player.connectWiredResumeThresholdMin.save(val);
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
                    settings.player.connectWirelessResumeThresholdMin.save(val);
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
      getSkipButtonsJumpChaptersWidget(),
      getItemWrapper(
        key: _PlaybackSettingsKeys.seekDuration,
        child: Obx(
          (context) => CustomListTile(
            bgColor: getBgColor(_PlaybackSettingsKeys.seekDuration),
            icon: Broken.forward_5_seconds,
            title: "${lang.seekDuration} (${settings.player.isSeekDurationPercentage.valueR ? lang.percentage : lang.seconds})",
            subtitle: lang.seekDurationInfo,
            onTap: () => settings.player.isSeekDurationPercentage.save(!settings.player.isSeekDurationPercentage.value),
            trailing: settings.player.isSeekDurationPercentage.valueR
                ? NamidaWheelSlider(
                    max: 50,
                    initValue: settings.player.seekDurationInPercentage.valueR,
                    onValueChanged: (val) => settings.player.seekDurationInPercentage.save(val),
                    text: "${settings.player.seekDurationInPercentage.valueR}%",
                  )
                : NamidaWheelSlider(
                    max: 120,
                    initValue: settings.player.seekDurationInSeconds.valueR,
                    onValueChanged: (val) => settings.player.seekDurationInSeconds.save(val),
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
                onValueChanged: (val) => settings.player.minTrackDurationToRestoreLastPosInMinutes.save(val),
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
                            onValueChanged: (val) => settings.isTrackPlayedSecondsCount.save(val),
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
                            onValueChanged: (val) => settings.isTrackPlayedPercentageCount.save(val),
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

class _ForcedOffWrapper extends StatelessWidget {
  final AudioOutputForcedOff option;
  final Widget Function(Widget? causePill) builder;

  const _ForcedOffWrapper({
    required this.option,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) {
        final cause = AudioOutputController.inst.getForcedOffCauseR(option);
        final causePill = cause == null
            ? null
            : Align(
                alignment: AlignmentDirectional.centerStart,
                child: DisabledByPill(
                  icon: cause.toIcon(),
                  title: cause.toText(),
                ),
              );
        return AnimatedEnabled(
          enabled: cause == null,
          child: builder(causePill),
        );
      },
    );
  }
}

class _NotificationButtonsEditor extends StatefulWidget {
  const _NotificationButtonsEditor();

  @override
  State<_NotificationButtonsEditor> createState() => _NotificationButtonsEditorState();
}

class _NotificationButtonsEditorState extends State<_NotificationButtonsEditor> {
  /// android 13+ always shows previous, play/pause & next first, only the rest can be changed.
  static final _isSystemLayout = NamidaFeaturesAvailablity.android13and_plus.resolve();
  static const _kMaxButtons = 5;
  static const _kLockedOpacity = 0.5;

  late final RxList<_NotificationButtonItem> _itemsRx;

  @override
  void initState() {
    super.initState();
    final activeButtons = settings.notificationButtons.value.ensurePlayPause();
    final activeItems = activeButtons.where(_isEditable).map((button) => (button: button, active: true));
    final inactiveItems = NotificationButton.values.where((button) => _isEditable(button) && !activeButtons.contains(button)).map((button) => (button: button, active: false));
    _itemsRx = <_NotificationButtonItem>[...activeItems, ...inactiveItems].obs;
  }

  @override
  void dispose() {
    _itemsRx.close();
    super.dispose();
  }

  static bool _isEditable(NotificationButton button) => !_isSystemLayout || !button.isTransport;

  static bool _isLocked(NotificationButton button) => _isSystemLayout ? button.isTransport : button == NotificationButton.playPause;

  static List<NotificationButton> _getActiveButtons(List<_NotificationButtonItem> items) {
    return [
      if (_isSystemLayout) ...NotificationButton.transportButtons,
      ...items.where((item) => item.active).map((item) => item.button),
    ];
  }

  void _save() {
    final buttons = _getActiveButtons(_itemsRx.value);
    settings.notificationButtons.replace(buttons);
  }

  /// shows why when the limit is reached.
  bool _canActivateOneMore() {
    final maxActive = _isSystemLayout ? _kMaxButtons - NotificationButton.transportButtons.length : _kMaxButtons;
    final activeCount = _itemsRx.value.where((e) => e.active).length;
    if (activeCount >= maxActive) {
      snackyy(title: lang.note, message: '${lang.maximum}: $maxActive');
      return false;
    }
    if (activeCount + 1 == _kMaxButtons && NamidaFeaturesVisibility.notificationButtonsMightDisplaceArtwork) {
      snackyy(title: lang.note, message: lang.displayFavButtonInNotificationSubtitle);
    }
    return true;
  }

  void _setActive(int index, bool active) {
    if (active && !_canActivateOneMore()) return;
    final button = _itemsRx.value[index].button;
    _itemsRx[index] = (button: button, active: active);
    _save();
  }

  void _onTap(int index) {
    final (:button, :active) = _itemsRx.value[index];
    if (button == NotificationButton.playPause) return;
    if (button == NotificationButton.addToPlaylist) {
      _pickPlaylists(index, active);
      return;
    }
    _setActive(index, !active);
  }

  void _pickPlaylists(int index, bool isActive) {
    if (!isActive && !_canActivateOneMore()) return;
    NamidaNavigator.inst.navigateDialog(
      dialog: _NotificationPlaylistsDialog(
        onConfirm: (hasPlaylist) {
          if (hasPlaylist != isActive) _setActive(index, hasPlaylist);
        },
      ),
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = _itemsRx.value.removeAt(oldIndex);
    _itemsRx.value.insert(newIndex, item);
    _itemsRx.refresh();
    _save();
  }

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: _itemsRx,
      builder: (context, items) => Column(
        children: [
          _NotificationButtonsPreview(
            buttons: _getActiveButtons(items),
            isLocked: _isLocked,
          ),
          const SizedBox(height: 8.0),
          Expanded(
            child: NamidaListView(
              showScrollbarOnStart: true,
              itemExtent: null,
              listBottomPadding: 0,
              itemCount: items.length,
              onReorder: _onReorder,
              itemBuilder: (context, i) {
                final (:button, :active) = items[i];
                final title = "${i + 1}. ${button.toText()}";
                void onTap() => _onTap(i);
                final tile = button == NotificationButton.addToPlaylist
                    ? _NotificationPlaylistsTile(
                        title: title,
                        active: active,
                        onTap: onTap,
                      )
                    : ListTileWithCheckMark(
                        title: title,
                        icon: button.toIcon(),
                        active: active,
                        onTap: onTap,
                      );
                final isLocked = _isLocked(button);
                final shownTile = isLocked
                    ? Opacity(
                        opacity: _kLockedOpacity,
                        child: tile,
                      )
                    : tile;
                return Padding(
                  key: ValueKey(button),
                  padding: const EdgeInsets.all(3.0),
                  child: shownTile,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationPlaylistsTile extends StatelessWidget {
  final String title;
  final bool active;
  final void Function() onTap;

  const _NotificationPlaylistsTile({
    required this.title,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) {
        final playlistNames = [settings.notificationButtonsPlaylist.valueR, settings.notificationButtonsYTPlaylist.valueR].nonNulls.join(', ');
        return ListTileWithCheckMark(
          title: title,
          subtitle: playlistNames,
          icon: NotificationButton.addToPlaylist.toIcon(),
          active: active,
          onTap: onTap,
        );
      },
    );
  }
}

class _NotificationButtonsPreview extends StatelessWidget {
  final List<NotificationButton> buttons;
  final bool Function(NotificationButton button) isLocked;

  const _NotificationButtonsPreview({
    required this.buttons,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final iconColor = theme.iconTheme.color;
    final lockedIconColor = iconColor?.withOpacityExt(_NotificationButtonsEditorState._kLockedOpacity);
    final icons = buttons
        .map(
          (button) => Icon(
            button.toIcon(),
            size: 20.0,
            color: isLocked(button) ? lockedIconColor : iconColor,
          ),
        )
        .toFixedList();
    return NamidaInkWell(
      bgColor: theme.cardColor,
      borderRadius: 12.0,
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: icons,
      ),
    );
  }
}

class _NotificationPlaylistsDialog extends StatefulWidget {
  final void Function(bool hasPlaylist) onConfirm;

  const _NotificationPlaylistsDialog({
    required this.onConfirm,
  });

  @override
  State<_NotificationPlaylistsDialog> createState() => _NotificationPlaylistsDialogState();
}

class _NotificationPlaylistsDialogState extends State<_NotificationPlaylistsDialog> {
  final _localPlaylistRx = Rxn<String>(settings.notificationButtonsPlaylist.value);
  final _ytPlaylistRx = Rxn<String>(settings.notificationButtonsYTPlaylist.value);
  final _localNames = PlaylistController.inst.playlistsMap.value.keys.toFixedList();
  final _ytNames = YoutubePlaylistController.inst.playlistsMap.value.keys.toFixedList();

  @override
  void dispose() {
    _localPlaylistRx.close();
    _ytPlaylistRx.close();
    super.dispose();
  }

  void _confirm() {
    final localName = _localPlaylistRx.value;
    final ytName = _ytPlaylistRx.value;
    settings.notificationButtonsPlaylist.save(localName);
    settings.notificationButtonsYTPlaylist.save(ytName);
    NamidaNavigator.inst.closeDialog();
    widget.onConfirm(localName != null || ytName != null);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final localCount = _localNames.length;
    return CustomBlurryDialog(
      title: lang.addToPlaylist,
      icon: Broken.music_library_2,
      normalTitleStyle: true,
      actions: [
        const CancelButton(),
        NamidaButton(
          text: lang.confirm,
          onTap: _confirm,
        ),
      ],
      child: SizedBox(
        width: namida.width,
        height: namida.height * 0.5,
        child: SuperSmoothListView.builder(
          padding: EdgeInsets.zero,
          itemCount: localCount + _ytNames.length + 2,
          itemBuilder: (context, index) {
            if (index == 0 || index == localCount + 1) {
              final source = index == 0 ? lang.local : lang.youtube;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8.0),
                child: Text(
                  "${lang.playlists} ($source)",
                  style: textTheme.displayMedium,
                ),
              );
            }
            final isLocal = index <= localCount;
            final name = isLocal ? _localNames[index - 1] : _ytNames[index - localCount - 2];
            final selectedRx = isLocal ? _localPlaylistRx : _ytPlaylistRx;
            return Padding(
              padding: const EdgeInsets.all(3.0),
              child: ObxO(
                rx: selectedRx,
                builder: (context, selected) => ListTileWithCheckMark(
                  icon: Broken.music_library_2,
                  title: name.translatePlaylistName(),
                  active: name == selected,
                  onTap: () => selectedRx.value = name == selected ? null : name,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CrossfadeModeTile extends StatelessWidget {
  const _CrossfadeModeTile();

  void _showModes(BuildContext context) {
    final menu = NamidaPopupWrapper(
      childrenDefault: () => CrossfadeMode.values.map(
        (e) => NamidaPopupItem(
          icon: e.toIcon(),
          title: e.toText(),
          selected: e == settings.player.crossfadeMode.value,
          onTap: () {
            RhythmController.inst.setMode(e);
            NamidaNavigator.inst.popMenu();
          },
        ),
      ),
    );
    menu.showPopupMenu(context);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) {
        final mode = settings.player.crossfadeMode.valueR;
        return CustomListTile(
          enabled: RhythmController.inst.hasAutoTransitionsR,
          icon: Broken.brush_3,
          title: lang.style,
          trailingText: mode.toText(),
          onTap: () => _showModes(context),
        );
      },
    );
  }
}

typedef _NotificationButtonItem = ({NotificationButton button, bool active});
