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
import 'package:namida/controller/video_controller.dart';
import 'package:namida/controller/wakelock_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/circular_percentages.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/disabled_by_pill.dart';
import 'package:namida/ui/widgets/reorderable_active_items_list.dart';
import 'package:namida/ui/widgets/settings_card.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart';

class PlaybackSettings extends SettingSubpageProvider {
  final bool isInDialog;
  const PlaybackSettings({super.key, super.initialItem, this.isInDialog = false});

  @override
  SettingSubpageEnum get settingPage => SettingSubpageEnum.playback;

  @override
  List<List<SettingEntry>> get sections => _sections;

  static final replayGain = SettingCustom(
    title: () => lang.normalizeAudio,
    aliases: () => [lang.normalizeAudioSubtitle],
    keys: [settings.player.replayGainType],
    onReset: _applyReplayGainType,
    tile: (args) => _ReplayGainTile(
      bgColor: args.bgColor,
    ),
  );

  static final autoPlayOnNextPrev = SettingToggle(
    settings.player.playOnNextPrev,
    leading: const StackedIcon(
      baseIcon: Broken.play,
      secondaryIcon: Broken.record,
    ),
    title: () => lang.playAfterNextPrev,
  );

  static final infinityQueueOnNextPrev = SettingToggle(
    settings.player.infiniyQueueOnNextPrevious,
    icon: Broken.repeat,
    title: () => lang.infinityQueueOnNextPrev,
    subtitle: () => lang.infinityQueueOnNextPrevSubtitle,
  );

  static final jumpToFirstTrackAfterFinishing = SettingToggle(
    settings.player.jumpToFirstTrackAfterFinishingQueue,
    icon: Broken.rotate_left,
    title: () => lang.jumpToFirstTrackAfterQueueFinish,
  );

  static final previousButtonReplays = SettingToggle(
    settings.previousButtonReplays,
    leading: const StackedIcon(
      baseIcon: Broken.previous,
      secondaryIcon: Broken.rotate_left,
      secondaryIconSize: 12.0,
    ),
    title: () => lang.previousButtonReplays,
    subtitle: () => lang.previousButtonReplaysSubtitle,
  );

  static final _sections = <List<SettingEntry>>[
    [
      SettingToggle(
        settings.enableVideoPlayback,
        icon: Broken.video,
        title: () => lang.enableVideoPlayback,
        onChanged: (isEnabled) => VideoController.inst.onVideoPlaybackToggled(isEnabled),
      ),
      SettingChoice(
        settings.videoPlaybackSource,
        values: VideoPlaybackSource.values,
        valueToText: (e) => e.toText(),
        valueToSubtitle: (e) => e.toSubtitle(),
        icon: Broken.scroll,
        title: () => lang.videoPlaybackSource,
        enabledWhen: _isVideoPlaybackEnabled,
      ),
      SettingCustom(
        title: () => lang.videoQuality,
        keys: [settings.youtubeVideoQualities],
        tile: (args) => _VideoQualityTile(
          bgColor: args.bgColor,
        ),
      ),
      SettingCustom(
        title: () => lang.localVideoMatching,
        aliases: () => [lang.matchingType, lang.sameDirectoryOnly],
        keys: [settings.localVideoMatchingType, settings.localVideoMatchingCheckSameDir],
        tile: (args) => _LocalVideoMatchingTile(
          bgColor: args.bgColor,
        ),
      ),
    ],
    [
      SettingChoice(
        settings.wakelockMode,
        values: WakelockMode.values,
        valueToText: (e) => e.toText(),
        icon: Broken.external_drive,
        title: () => lang.keepScreenAwakeWhen,
        isValueInSubtitle: true,
        onChanged: (_) => WakelockController.inst.onSettingChanged(),
      ),
      SettingCustom(
        availability: const NamidaFeaturesAvailablityGroup(items: [NamidaFeaturesAvailablity.android, NamidaFeaturesAvailablity.ios, NamidaFeaturesAvailablity.macos]),
        title: () => lang.notificationButtons,
        keys: [
          settings.notificationButtons, settings.notificationButtonsPlaylist, settings.notificationButtonsYTPlaylist, //
          settings.nowPlayingSeekBackward, settings.nowPlayingSeekForward, //
        ],
        tile: (args) {
          if (NamidaFeaturesVisibility.nowPlayingSeekButtons) return _NowPlayingButtonsTile(bgColor: args.bgColor);
          return _NotificationButtonsTile(bgColor: args.bgColor);
        },
      ),
      SettingToggle(
        settings.player.lockscreenArtwork,
        availability: NamidaFeaturesAvailablity.android12and_below,
        leading: const StackedIcon(
          baseIcon: Broken.gallery,
          secondaryIcon: Broken.lock_circle,
        ),
        title: () => lang.displayArtworkOnLockscreen,
        onChanged: (isEnabled) => AudioService.setLockScreenArtwork(isEnabled).then((_) => Player.inst.refreshNotification()),
      ),
      SettingChoice(
        settings.player.killAfterDismissingApp,
        availability: const NamidaFeaturesAvailablityGroup(
          items: [NamidaFeaturesAvailablity.android, NamidaFeaturesAvailablity.windows, NamidaFeaturesAvailablity.linux, NamidaFeaturesAvailablity.macos],
        ),
        values: KillAppMode.values,
        valueToText: (e) => e.toText(),
        icon: Broken.forbidden_2,
        title: () => lang.killPlayerAfterDismissingApp,
      ),
      SettingChoice(
        settings.onNotificationTapAction,
        availability: NamidaFeaturesAvailablity.android,
        values: NotificationTapAction.values,
        valueToText: (e) => e.toText(),
        icon: Broken.card,
        title: () => lang.onNotificationTap,
      ),
      SettingToggle(
        settings.dismissibleMiniplayer,
        icon: Broken.sidebar_bottom,
        title: () => lang.dismissibleMiniplayer,
        enabledWhen: () => !Dimensions.inst.miniplayerIsWideScreen,
      ),
    ],
    [
      SettingCustom(
        title: () => lang.soundControl,
        aliases: () => [
          lang.outputDevice, lang.bitPerfect, lang.usbDirect, lang.exclusiveMode, lang.signalPath, lang.equalizer, lang.preamp, //
          lang.speed, lang.pitch, lang.volume, lang.loudnessEnhancer, lang.monoAudio, //
        ],
        tile: (args) => _SoundControlTile(
          bgColor: args.bgColor,
        ),
      ),
      replayGain,
      SettingToggle(
        settings.player.skipSilenceEnabled,
        availability: const NamidaFeaturesAvailablityGroup(items: [NamidaFeaturesAvailablity.android, NamidaFeaturesAvailablity.linux]),
        icon: Broken.forward,
        title: () => lang.skipSilence,
        onChanged: (isEnabled) => Player.inst.setSkipSilenceEnabled(isEnabled),
      ),
      SettingToggle(
        settings.player.enableGaplessPlayback,
        icon: Broken.blend_2,
        title: () => "${lang.gaplessPlayback} (${lang.beta})",
        onChanged: (_) => Player.inst.resetGaplessPlaybackData(),
      ),
      SettingCustom(
        title: () => lang.enableCrossfadeEffect,
        keys: [settings.player.enableCrossFade],
        tile: (args) => _ForcedOffToggleGroupTile(
          args: args,
          option: AudioOutputForcedOff.crossfade,
          setting: settings.player.enableCrossFade,
          leading: const StackedIcon(
            baseIcon: Broken.play,
            secondaryIcon: Broken.recovery_convert,
          ),
          title: lang.enableCrossfadeEffect,
          onToggle: _onCrossfadeToggle,
        ),
        children: [
          SettingWheel(
            settings.player.crossFadeDurationMS,
            icon: Broken.blend_2,
            title: () => lang.crossfadeDuration,
            min: 100,
            max: 10000,
            stepper: 100,
            valueToText: (ms) => ms >= 1000 ? "${ms / 1000}s" : "${ms}ms",
            enabledWhen: _isCrossfadeEnabled,
          ),
          SettingCustom(
            title: () => lang.crossfadeTriggerSeconds(seconds: settings.player.crossFadeAutoTriggerSeconds.value),
            keys: [settings.player.crossFadeAutoTriggerSeconds],
            tile: (args) => _CrossfadeTriggerTile(
              bgColor: args.bgColor,
            ),
          ),
          SettingCustom(
            title: () => lang.style,
            aliases: () => [lang.smart, lang.beatMatching],
            keys: [settings.player.crossfadeMode],
            onReset: () => Player.inst.refreshCrossfadeTransition(),
            tile: (args) => _CrossfadeModeTile(
              bgColor: args.bgColor,
            ),
          ),
        ],
      ),
      SettingCustom(
        title: () => lang.enableFadeEffectOnPlayPause,
        keys: [settings.player.enableVolumeFadeOnPlayPause],
        onReset: _applyPlayerVolume,
        tile: (args) => _ForcedOffToggleGroupTile(
          args: args,
          option: AudioOutputForcedOff.fadeOnPlayPause,
          setting: settings.player.enableVolumeFadeOnPlayPause,
          leading: const StackedIcon(
            baseIcon: Broken.play,
            secondaryIcon: Broken.pause,
          ),
          title: lang.enableFadeEffectOnPlayPause,
          onToggle: _onFadeOnPlayPauseToggle,
        ),
        children: [
          SettingWheel(
            settings.player.playFadeDurInMilli,
            icon: Broken.play,
            title: () => lang.playFadeDuration,
            min: 100,
            max: 2000,
            stepper: 50,
            valueToText: (ms) => "${ms}ms",
            enabledWhen: _isFadeOnPlayPauseEnabled,
          ),
          SettingWheel(
            settings.player.pauseFadeDurInMilli,
            icon: Broken.pause,
            title: () => lang.pauseFadeDuration,
            min: 100,
            max: 2000,
            stepper: 50,
            valueToText: (ms) => "${ms}ms",
            enabledWhen: _isFadeOnPlayPauseEnabled,
          ),
        ],
      ),
    ],
    [
      autoPlayOnNextPrev,
      infinityQueueOnNextPrev,
      SettingExpansion(
        icon: Broken.volume_slash,
        title: () => lang.onVolumeZero,
        children: [
          SettingToggle(
            settings.player.pauseOnVolume0,
            icon: Broken.pause_circle,
            title: () => lang.pausePlayback,
          ),
          SettingCustom(
            title: () => lang.resumeIfWasPausedByVolume,
            keys: [settings.player.volume0ResumeThresholdMin],
            tile: (args) => _ResumeThresholdTile(
              bgColor: args.bgColor,
              setting: settings.player.volume0ResumeThresholdMin,
              max: 60,
              icon: Broken.play_circle,
              alwaysText: lang.resumeIfWasPausedByVolume,
            ),
          ),
        ],
      ),
      SettingCustom(
        title: () => lang.longPressAction,
        aliases: () => [lang.speed],
        keys: [settings.player.longPressSpeed],
        tile: (args) => _LongPressSpeedTile(
          bgColor: args.bgColor,
        ),
      ),
      SettingExpansion(
        availability: NamidaFeaturesAvailablityGroup.mobile,
        icon: Broken.notification_bing,
        title: () => lang.onInterruption,
        children: [
          ...InterruptionType.values.map(
            (type) => SettingCustom(
              title: () => type.toText(),
              aliases: () => [lang.duckAudio],
              keys: [settings.player.onInterrupted],
              tile: (args) => _InterruptionActionTile(
                type: type,
                bgColor: args.bgColor,
              ),
            ),
          ),
          SettingCustom(
            title: () => lang.resumeIfWasInterrupted,
            keys: [settings.player.interruptionResumeThresholdMin],
            tile: (args) => _InterruptionResumeTile(
              bgColor: args.bgColor,
            ),
          ),
        ],
      ),
      SettingExpansion(
        availability: NamidaFeaturesAvailablityGroup.mobile,
        icon: Broken.electricity,
        title: () => lang.onDeviceConnect,
        children: [
          SettingCustom(
            title: () => lang.wiredDevice,
            keys: [settings.player.connectWiredResumeThresholdMin],
            tile: (args) => _ResumeThresholdTile(
              bgColor: args.bgColor,
              setting: settings.player.connectWiredResumeThresholdMin,
              max: 120,
              leading: const StackedIcon(
                baseIcon: Broken.headphones,
                secondaryIcon: Broken.play_circle,
                secondaryIconSize: 13.0,
              ),
              title: lang.wiredDevice,
              alwaysText: lang.resumeIfWasPausedByDeviceDisconnect,
            ),
          ),
          SettingCustom(
            title: () => lang.wirelessDevice,
            keys: [settings.player.connectWirelessResumeThresholdMin],
            tile: (args) => _ResumeThresholdTile(
              bgColor: args.bgColor,
              setting: settings.player.connectWirelessResumeThresholdMin,
              max: 120,
              leading: const StackedIcon(
                baseIcon: Broken.airpods,
                secondaryIcon: Broken.play_circle,
                secondaryIconSize: 13.0,
              ),
              title: lang.wirelessDevice,
              alwaysText: lang.resumeIfWasPausedByDeviceDisconnect,
            ),
          ),
        ],
      ),
    ],
    [
      jumpToFirstTrackAfterFinishing,
      previousButtonReplays,
      SettingToggle(
        settings.skipButtonsJumpChapters,
        icon: Broken.arrow_square_right,
        title: () => lang.skipButtonsJumpChapters,
        aliases: () => [lang.chapters],
      ),
      SettingCustom(
        title: () => lang.seekDuration,
        aliases: () => [lang.seekDurationInfo],
        keys: [settings.player.isSeekDurationPercentage, settings.player.seekDurationInPercentage, settings.player.seekDurationInSeconds],
        tile: (args) => _SeekDurationTile(
          bgColor: args.bgColor,
        ),
      ),
    ],
    [
      SettingWheel(
        settings.player.minTrackDurationToRestoreLastPosInMinutes,
        icon: Broken.refresh_left_square,
        title: () => lang.minTrackDurationToRestoreLastPosition,
        max: 120,
        extraValue: true,
        valueToText: (minutes) => minutes == 0
            ? lang.alwaysRestore
            : minutes <= -1
            ? lang.dontRestorePosition
            : "${minutes}m",
      ),
      SettingCustom(
        title: () => lang.minValueToCountTrackListen,
        keys: [settings.isTrackPlayedSecondsCount, settings.isTrackPlayedPercentageCount],
        tile: (args) => _CountListenAfterTile(
          bgColor: args.bgColor,
        ),
      ),
    ],
  ];

  static bool _isVideoPlaybackEnabled() => settings.enableVideoPlayback.valueR;

  static bool _isCrossfadeEnabled() => settings.player.enableCrossFade.valueR;

  static bool _isFadeOnPlayPauseEnabled() => settings.player.enableVolumeFadeOnPlayPause.valueR;

  static void _onCrossfadeToggle(bool isEnabled) {
    if (isEnabled) {
      SussyBaka.monetize(unlockable: EggUnlockable.crossfade, onEnable: () => settings.player.enableCrossFade.save(true));
    } else {
      settings.player.enableCrossFade.save(false);
    }
  }

  static void _onFadeOnPlayPauseToggle(bool isEnabled) {
    settings.player.enableVolumeFadeOnPlayPause.save(isEnabled);
    _applyPlayerVolume();
  }

  static void _applyPlayerVolume() => Player.inst.setVolume(Player.inst.userPlayerVolumeForItem);

  static Future<void> _applyReplayGainType() async {
    final type = settings.player.replayGainType.value;

    // -- safer to disable all first
    Player.inst.loudnessEnhancerExtended?.setTargetGainTrack(0);
    Player.inst.loudnessEnhancerExtended?.refreshEnabled();
    Player.inst.setReplayGainLinearVolume(1.0);

    if (!type.isAnyEnabled) return;

    double? vol;
    final currentItem = Player.inst.currentItem.value;
    if (currentItem is Track) {
      final gainData = currentItem.toTrackExt().gainData;
      if (type.isLoudnessEnhancerEnabled) {
        final gainToUse = gainData?.gainToUse;
        if (gainToUse != null) Player.inst.loudnessEnhancerExtended?.setTargetGainTrack(gainToUse);
      } else if (type.isVolumeEnabled) {
        vol = gainData?.calculateGainAsVolume();
      }
    } else if (currentItem is YoutubeID) {
      final streamsResult = await YoutubeInfoController.video.fetchVideoStreamsCache(currentItem.id);
      final loudnessDb = streamsResult?.loudnessDBData?.loudnessDb;
      if (loudnessDb != null) {
        if (type.isLoudnessEnhancerEnabled) {
          Player.inst.loudnessEnhancerExtended?.setTargetGainTrack(-loudnessDb.toDouble());
        } else if (type.isVolumeEnabled) {
          vol = ReplayGainData.convertGainToVolume(gain: -loudnessDb.toDouble());
        }
      }
    }
    vol ??= ReplayGainData.kDefaultFallbackVolume;
    Player.inst.setReplayGainLinearVolume(vol);
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

  @override
  Widget build(BuildContext context) {
    final sectionsColumn = SettingSectionsColumn(
      page: this,
    );
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
              child: SmoothSingleChildScrollView(
                child: sectionsColumn,
              ),
            )
          : sectionsColumn,
    );
  }
}

class _VideoQualityTile extends StatelessWidget {
  final Color? bgColor;

  const _VideoQualityTile({required this.bgColor});

  void _onQualityTap(String quality) {
    if (settings.youtubeVideoQualities.value.contains(quality)) {
      if (settings.youtubeVideoQualities.value.length == 1) {
        showMinimumItemsSnack(1);
      } else {
        settings.youtubeVideoQualities.update((list) => list.remove(quality));
      }
    } else {
      settings.youtubeVideoQualities.update((list) => list.addNoDuplicates(quality));
    }
    // sorts and saves dec
    settings.youtubeVideoQualities.update((list) => list.sortByReverse((e) => kStockVideoQualities.indexOf(e)));
  }

  void _showDialog(TextStyle textStyle) {
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
          style: textStyle,
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
                      ...kStockVideoQualities.map(
                        (q) => Padding(
                          padding: const EdgeInsets.all(3.0),
                          child: ListTileWithCheckMark(
                            icon: Broken.story,
                            active: youtubeVideoQualities.contains(q),
                            title: q,
                            onTap: () => _onQualityTap(q),
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
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = NText.small.of(context);
    return Obx(
      (context) => CustomListTile(
        bgColor: bgColor,
        enabled: settings.enableVideoPlayback.valueR,
        title: lang.videoQuality,
        icon: Broken.story,
        trailingText: settings.youtubeVideoQualities.valueR.first,
        onTap: () => _showDialog(textStyle),
      ),
    );
  }
}

class _LocalVideoMatchingTile extends StatelessWidget {
  final Color? bgColor;

  const _LocalVideoMatchingTile({required this.bgColor});

  static Iterable<NamidaPopupItem> _getMatchingTypeItems() => LocalVideoMatchingType.values.map(
    (e) => NamidaPopupItem(
      icon: Broken.video_tick,
      title: e.toText(),
      selected: e == settings.localVideoMatchingType.value,
      onTap: () {
        settings.localVideoMatchingType.save(e);
        NamidaNavigator.inst.popMenu();
      },
    ),
  );

  void _showDialog() {
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        title: lang.localVideoMatching,
        actions: const [
          DoneButton(),
        ],
        child: Column(
          children: [
            NamidaPopupWrapper(
              childrenDefault: _getMatchingTypeItems,
              childBuilder: (openMenu) => CustomListTile(
                icon: Broken.video_tick,
                title: lang.matchingType,
                trailing: NamidaPopupWrapper(
                  childrenDefault: _getMatchingTypeItems,
                  child: Obx(
                    (context) => NamidaText(
                      settings.localVideoMatchingType.valueR.toText(),
                      style: NText.medium,
                      color: const NColors(.onSurface, opacity: 0.78),
                      maxLines: 1,
                    ),
                  ),
                ),
                onTap: openMenu,
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
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) {
        final videosCountText = VideoController.inst.getLocalVideosCountTextR();
        return CustomListTile(
          bgColor: bgColor,
          enabled: settings.enableVideoPlayback.valueR,
          icon: Broken.video_tick,
          title: lang.localVideoMatching,
          subtitle: '${lang.videos}: $videosCountText',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LocalVideosRescanButton(),
              const SizedBox(width: 8.0),
              NamidaText(
                settings.localVideoMatchingType.valueR.toText(),
                style: NText.medium,
                color: const NColors(.onSurface, opacity: 0.78),
                maxLines: 1,
              ),
            ],
          ),
          onTap: _showDialog,
        );
      },
    );
  }
}

class LocalVideosRescanButton extends StatelessWidget {
  final EdgeInsetsGeometry? padding;

  const LocalVideosRescanButton({super.key, this.padding});

  static Future<void> _rescan() async {
    await VideoController.inst.rescanLocalVideosPaths();
    snackyy(title: lang.done, message: lang.finishedUpdatingLibrary);
  }

  @override
  Widget build(BuildContext context) {
    return NamidaIconButton(
      icon: Broken.refresh,
      iconSize: 20.0,
      padding: padding,
      tooltip: () => lang.rescanVideos,
      onPressed: _rescan,
    );
  }
}

class _NotificationButtonsTile extends StatelessWidget {
  final Color? bgColor;

  const _NotificationButtonsTile({required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: settings.notificationButtons,
      builder: (context, notificationButtons) => CustomListTile(
        bgColor: bgColor,
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
    );
  }
}

class _SoundControlTile extends StatelessWidget {
  final Color? bgColor;

  const _SoundControlTile({required this.bgColor});

  @override
  Widget build(BuildContext context) {
    final subtitle = [lang.outputDevice, lang.bitPerfect, lang.equalizer, lang.speed, lang.pitch].join(', ');
    return CustomListTile(
      bgColor: bgColor,
      icon: Broken.sound,
      title: lang.soundControl,
      subtitle: subtitle,
      trailing: const Icon(
        Broken.arrow_right_3,
        size: 18.0,
      ),
      onTap: NamidaOnTaps.inst.openSoundControl,
    );
  }
}

class _ReplayGainTile extends StatelessWidget {
  final Color? bgColor;

  const _ReplayGainTile({required this.bgColor});

  static void _onTypeTap(ReplayGainType e) {
    NamidaNavigator.inst.popMenu();
    settings.player.replayGainType.save(e);
    PlaybackSettings._applyReplayGainType();
  }

  static Iterable<NamidaPopupItem> _getTypeItems() => ReplayGainType.valuesForPlatform.map(
    (e) => NamidaPopupItem(
      icon: Broken.airpods,
      secondaryIcon: Broken.voice_cricle,
      selected: e == settings.player.replayGainType.value,
      title: e.toText(),
      onTap: () => _onTypeTap(e),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return NamidaPopupWrapper(
      childrenDefault: _getTypeItems,
      childBuilder: (openMenu) => CustomListTile(
        bgColor: bgColor,
        leading: const StackedIcon(
          baseIcon: Broken.airpods,
          secondaryIcon: Broken.voice_cricle,
        ),
        title: lang.normalizeAudio,
        subtitle: lang.normalizeAudioSubtitle,
        trailing: NamidaPopupWrapper(
          childrenDefault: _getTypeItems,
          child: ObxO(
            rx: settings.player.replayGainType,
            builder: (context, replayGainType) => NamidaText(
              "${replayGainType.toText()}${replayGainType == ReplayGainType.platform_default ? '\n(${ReplayGainType.getPlatformDefault().toText()})' : ''}",
              style: NText.medium,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        onTap: openMenu,
      ),
    );
  }
}

class _ForcedOffToggleGroupTile extends StatelessWidget {
  final SettingTileArgs args;
  final AudioOutputForcedOff option;
  final SettingsKey<bool> setting;
  final Widget leading;
  final String title;
  final void Function(bool isEnabled) onToggle;

  const _ForcedOffToggleGroupTile({
    required this.args,
    required this.option,
    required this.setting,
    required this.leading,
    required this.title,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final page = args.page;
    final isTargetWithin = page?.isTargetWithin(args.entry) == true;
    final initiallyExpanded = setting.value || isTargetWithin;
    final children = args.entry.children
        .map(
          (e) => SettingEntryTile(
            entry: e,
            page: page,
          ),
        )
        .toFixedList();
    return _ForcedOffWrapper(
      option: option,
      builder: (causePill) => NamidaExpansionTile(
        bgColor: args.bgColor,
        initiallyExpanded: initiallyExpanded,
        expandedRx: setting,
        onTap: () => onToggle(!setting.value),
        leading: leading,
        titleText: title,
        subtitle: causePill,
        trailingBuilder: (_) => ObxO(
          rx: setting,
          builder: (context, isEnabled) => CustomSwitch(
            active: isEnabled,
          ),
        ),
        children: children,
      ),
    );
  }
}

class _CrossfadeTriggerTile extends StatelessWidget {
  final Color? bgColor;

  const _CrossfadeTriggerTile({required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) {
        final gaplessEnabled = settings.player.enableGaplessPlayback.valueR;
        final triggerSeconds = settings.player.crossFadeAutoTriggerSeconds.valueR;
        final title = triggerSeconds == 0 ? lang.crossfadeTriggerSecondsDisabled : lang.crossfadeTriggerSeconds(seconds: triggerSeconds);
        return AnimatedEnabled(
          enabled: !gaplessEnabled,
          child: CustomListTile(
            bgColor: bgColor,
            enabled: settings.player.enableCrossFade.valueR,
            icon: Broken.blend,
            title: title,
            subtitleWidget: gaplessEnabled
                ? DisabledByPill(
                    icon: Broken.blend_2,
                    title: lang.gaplessPlayback,
                  )
                : null,
            trailing: NamidaWheelSlider(
              max: 30,
              initValue: triggerSeconds,
              onValueChanged: settings.player.crossFadeAutoTriggerSeconds.save,
              text: "${triggerSeconds}s",
            ),
          ),
        );
      },
    );
  }
}

/// 0 always resumes, -1 never, otherwise only when paused for less than that many minutes.
class _ResumeThresholdTile extends StatelessWidget {
  final Color? bgColor;
  final SettingsKey<int> setting;
  final int max;
  final IconData? icon;
  final Widget? leading;

  /// the threshold goes in the subtitle when set, otherwise it's the title.
  final String? title;
  final String alwaysText;

  const _ResumeThresholdTile({
    required this.bgColor,
    required this.setting,
    required this.max,
    this.icon,
    this.leading,
    this.title,
    required this.alwaysText,
  });

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: setting,
      builder: (context, minutes) {
        final thresholdText = minutes == 0
            ? alwaysText
            : minutes <= -1
            ? lang.dontResume
            : lang.resumeIfWasPausedForLessThanNMin(number: minutes);
        final valueText = minutes == 0
            ? lang.always
            : minutes <= -1
            ? lang.never
            : "${minutes}m";
        final title = this.title;
        return CustomListTile(
          bgColor: bgColor,
          icon: icon,
          leading: leading,
          title: title ?? thresholdText,
          subtitle: title == null ? null : thresholdText,
          trailing: NamidaWheelSlider(
            max: max,
            extraValue: true,
            initValue: minutes,
            onValueChanged: setting.save,
            text: valueText,
          ),
        );
      },
    );
  }
}

class _LongPressSpeedTile extends StatelessWidget {
  final Color? bgColor;

  const _LongPressSpeedTile({required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: settings.player.longPressSpeed,
      builder: (context, longPressSpeed) {
        final speedPercentage = (longPressSpeed * 100).round();
        return CustomListTile(
          bgColor: bgColor,
          icon: Broken.forward,
          title: '${lang.longPressAction}: ${lang.speed}',
          trailing: NamidaWheelSlider(
            initValue: speedPercentage,
            max: 2 * 100,
            onValueChanged: (val) => settings.player.longPressSpeed.save(val / 100),
            text: "${longPressSpeed}x",
          ),
        );
      },
    );
  }
}

class _InterruptionActionTile extends StatelessWidget {
  final InterruptionType type;
  final Color? bgColor;

  const _InterruptionActionTile({required this.type, required this.bgColor});

  Iterable<NamidaPopupItem> _getActionItems() => InterruptionAction.values.map(
    (action) => NamidaPopupItem(
      icon: action.toIcon(),
      title: action.toText(),
      selected: action == settings.player.onInterrupted.value[type],
      onTap: () => settings.player.onInterrupted.update((actions) => actions[type] = action),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return NamidaPopupWrapper(
      childrenDefault: _getActionItems,
      childBuilder: (openMenu) => CustomListTile(
        bgColor: bgColor,
        icon: type.toIcon(),
        title: type.toText(),
        subtitle: type.toSubtitle(),
        trailing: NamidaPopupWrapper(
          childrenDefault: _getActionItems,
          child: Obx(
            (context) {
              final actionInSetting = settings.player.onInterrupted.valueR[type] ?? InterruptionAction.pause;
              return NamidaText(
                actionInSetting.toText(),
                style: NText.medium,
              );
            },
          ),
        ),
        onTap: openMenu,
      ),
    );
  }
}

class _InterruptionResumeTile extends StatelessWidget {
  final Color? bgColor;

  const _InterruptionResumeTile({required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const NamidaContainerDivider(
          margin: EdgeInsets.symmetric(horizontal: 16.0),
        ),
        const SizedBox(height: 6.0),
        _ResumeThresholdTile(
          bgColor: bgColor,
          setting: settings.player.interruptionResumeThresholdMin,
          max: 60,
          icon: Broken.play_circle,
          alwaysText: lang.resumeIfWasInterrupted,
        ),
      ],
    );
  }
}

class _SeekDurationTile extends StatelessWidget {
  final Color? bgColor;

  const _SeekDurationTile({required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) {
        final isPercentage = settings.player.isSeekDurationPercentage.valueR;
        final unitText = isPercentage ? lang.percentage : lang.seconds;
        final slider = isPercentage
            ? NamidaWheelSlider(
                max: 50,
                initValue: settings.player.seekDurationInPercentage.valueR,
                onValueChanged: settings.player.seekDurationInPercentage.save,
                text: "${settings.player.seekDurationInPercentage.valueR}%",
              )
            : NamidaWheelSlider(
                max: 120,
                initValue: settings.player.seekDurationInSeconds.valueR,
                onValueChanged: settings.player.seekDurationInSeconds.save,
                text: "${settings.player.seekDurationInSeconds.valueR}s",
              );
        return CustomListTile(
          bgColor: bgColor,
          icon: Broken.forward_5_seconds,
          title: "${lang.seekDuration} ($unitText)",
          subtitle: lang.seekDurationInfo,
          onTap: () => settings.player.isSeekDurationPercentage.save(!isPercentage),
          trailing: slider,
        );
      },
    );
  }
}

class _CountListenAfterTile extends StatelessWidget {
  final Color? bgColor;

  const _CountListenAfterTile({required this.bgColor});

  void _showDialog() {
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        title: lang.choose,
        actions: const [
          DoneButton(),
        ],
        child: Column(
          children: [
            NamidaText(
              lang.minValueToCountTrackListen,
              style: NText.large,
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
                    onValueChanged: settings.isTrackPlayedSecondsCount.save,
                    text: "${settings.isTrackPlayedSecondsCount.valueR}s",
                    topText: lang.seconds.capitalizeFirst(),
                    textPadding: 8.0,
                  ),
                  NamidaText(
                    lang.or,
                    style: NText.medium,
                  ),
                  NamidaWheelSlider(
                    min: 20,
                    max: 100,
                    initValue: settings.isTrackPlayedPercentageCount.valueR,
                    onValueChanged: settings.isTrackPlayedPercentageCount.save,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) => CustomListTile(
        bgColor: bgColor,
        icon: Broken.timer,
        title: lang.minValueToCountTrackListen,
        onTap: _showDialog,
        trailingText: "${settings.isTrackPlayedSecondsCount.valueR}s | ${settings.isTrackPlayedPercentageCount.valueR}%",
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
  static final _editableButtons = NotificationButton.values.where(_isEditable).toFixedList();

  final _activeButtonsRx = settings.notificationButtons.value.ensurePlayPause().where(_isEditable).toList().obs;

  @override
  void dispose() {
    _activeButtonsRx.close();
    super.dispose();
  }

  static bool _isEditable(NotificationButton button) => !_isSystemLayout || !button.isTransport;

  static bool _isLocked(NotificationButton button) => _isSystemLayout ? button.isTransport : button == NotificationButton.playPause;

  static List<NotificationButton> _getActiveButtons(List<NotificationButton> editableActiveButtons) {
    return [
      if (_isSystemLayout) ...NotificationButton.transportButtons,
      ...editableActiveButtons,
    ];
  }

  static bool _hasPlaylist() => settings.notificationButtonsPlaylist.value != null || settings.notificationButtonsYTPlaylist.value != null;

  void _onChanged(List<NotificationButton> editableActiveButtons) {
    _activeButtonsRx.value = editableActiveButtons;
    final buttons = _getActiveButtons(editableActiveButtons);
    settings.notificationButtons.replace(buttons);
  }

  /// shows why when the limit is reached.
  bool _canActivateOneMore() {
    final maxActive = _isSystemLayout ? _kMaxButtons - NotificationButton.transportButtons.length : _kMaxButtons;
    final activeCount = _activeButtonsRx.value.length;
    if (activeCount >= maxActive) {
      snackyy(title: lang.note, message: '${lang.maximum}: $maxActive');
      return false;
    }
    if (NamidaFeaturesVisibility.notificationButtonsMightDisplaceArtwork) {
      if (activeCount + 1 == _kMaxButtons) {
        snackyy(title: lang.note, message: lang.displayFavButtonInNotificationSubtitle);
      }
    }
    return true;
  }

  bool _canActivate(NotificationButton button) {
    if (!_canActivateOneMore()) return false;
    if (button != NotificationButton.addToPlaylist || _hasPlaylist()) return true;
    _pickPlaylists(false);
    return false;
  }

  bool _interceptTap(NotificationButton button, bool isActive) {
    if (button != NotificationButton.addToPlaylist) return false;
    if (isActive || _canActivateOneMore()) _pickPlaylists(isActive);
    return true;
  }

  void _pickPlaylists(bool isActive) {
    NamidaNavigator.inst.navigateDialog(
      dialog: _NotificationPlaylistsDialog(
        onConfirm: (hasPlaylist) {
          if (hasPlaylist != isActive) _setPlaylistButtonActive(hasPlaylist);
        },
      ),
    );
  }

  void _setPlaylistButtonActive(bool active) {
    if (active && !_canActivateOneMore()) return;
    const button = NotificationButton.addToPlaylist;
    final currentButtons = _activeButtonsRx.value;
    final buttons = active ? [...currentButtons, button] : currentButtons.where((e) => e != button).toList();
    _onChanged(buttons);
  }

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: _activeButtonsRx,
      builder: (context, activeButtons) => Column(
        children: [
          _NotificationButtonsPreview(
            buttons: _getActiveButtons(activeButtons),
            isLocked: _isLocked,
          ),
          const SizedBox(height: 8.0),
          Expanded(
            child: Obx(
              (context) {
                final playlistNames = [settings.notificationButtonsPlaylist.valueR, settings.notificationButtonsYTPlaylist.valueR].nonNulls.join(', ');
                return NamidaReorderableActiveItemsList(
                  items: _editableButtons,
                  activeItems: activeButtons,
                  toText: (button) => button.toText(),
                  toIcon: (button) => button.toIcon(),
                  toSubtitle: (button) => button == NotificationButton.addToPlaylist ? playlistNames : '',
                  isLocked: _isLocked,
                  canActivate: _canActivate,
                  interceptTap: _interceptTap,
                  onChanged: _onChanged,
                );
              },
            ),
          ),
        ],
      ),
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
    const lockedIconColor = NColors(.icon, opacity: NamidaReorderableActiveItemsList.kLockedOpacity);
    final icons = buttons
        .map(
          (button) => NIcon(
            button.toIcon(),
            size: 20.0,
            color: isLocked(button) ? lockedIconColor : NColors.icon,
          ),
        )
        .toFixedList();
    return NamidaInkWell(
      bgColor: NColors.card,
      borderRadius: 12.0,
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: icons,
      ),
    );
  }
}

class _NowPlayingButtonsTile extends StatelessWidget {
  final Color? bgColor;

  const _NowPlayingButtonsTile({required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) {
        final buttons = NotificationButton.getNowPlayingButtons(
          isSeekBackward: settings.nowPlayingSeekBackward.valueR,
          isSeekForward: settings.nowPlayingSeekForward.valueR,
        );
        return CustomListTile(
          bgColor: bgColor,
          icon: Broken.notification_bing,
          title: lang.notificationButtons,
          subtitle: buttons.map((e) => e.toText()).join(', '),
          trailing: const Icon(
            Broken.arrow_right_3,
            size: 18.0,
          ),
          onTap: () => NamidaNavigator.inst.navigateDialog(
            dialog: CustomBlurryDialog(
              title: lang.notificationButtons,
              actions: const [
                DoneButton(),
              ],
              child: const _NowPlayingButtonsEditor(),
            ),
          ),
        );
      },
    );
  }
}

class _NowPlayingButtonsEditor extends StatelessWidget {
  const _NowPlayingButtonsEditor();

  static bool _isLocked(NotificationButton button) => button == NotificationButton.playPause;

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) {
        final isSeekBackward = settings.nowPlayingSeekBackward.valueR;
        final isSeekForward = settings.nowPlayingSeekForward.valueR;
        final buttons = NotificationButton.getNowPlayingButtons(isSeekBackward: isSeekBackward, isSeekForward: isSeekForward);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _NotificationButtonsPreview(
              buttons: buttons,
              isLocked: _isLocked,
            ),
            const SizedBox(height: 8.0),
            CustomSwitchListTile(
              icon: NotificationButton.seekBackward.toIcon(),
              title: lang.seekBackward,
              value: isSeekBackward,
              onChanged: (isTrue) => settings.nowPlayingSeekBackward.save(!isTrue),
            ),
            CustomSwitchListTile(
              icon: NotificationButton.seekForward.toIcon(),
              title: lang.seekForward,
              value: isSeekForward,
              onChanged: (isTrue) => settings.nowPlayingSeekForward.save(!isTrue),
            ),
          ],
        );
      },
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
                child: NamidaText(
                  "${lang.playlists} ($source)",
                  style: NText.medium,
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
  final Color? bgColor;

  const _CrossfadeModeTile({required this.bgColor});

  static Iterable<NamidaPopupItem> _getModeItems() => CrossfadeMode.values.map(
    (e) => NamidaPopupItem(
      icon: e.toIcon(),
      title: e.toText(),
      selected: e == settings.player.crossfadeMode.value,
      onTap: () {
        RhythmController.inst.setMode(e);
        NamidaNavigator.inst.popMenu();
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) {
        final mode = settings.player.crossfadeMode.valueR;
        final isEnabled = RhythmController.inst.hasAutoTransitionsR;
        return NamidaPopupWrapper(
          childrenDefault: _getModeItems,
          openOnTap: isEnabled,
          openOnLongPress: isEnabled,
          childBuilder: (openMenu) => CustomListTile(
            bgColor: bgColor,
            enabled: isEnabled,
            icon: Broken.brush_3,
            title: lang.style,
            trailing: NamidaPopupWrapper(
              childrenDefault: _getModeItems,
              child: NamidaText(
                mode.toText(),
                style: NText.medium,
                color: const NColors(.onSurface, opacity: 0.78),
                maxLines: 1,
              ),
            ),
            onTap: openMenu,
          ),
        );
      },
    );
  }
}
