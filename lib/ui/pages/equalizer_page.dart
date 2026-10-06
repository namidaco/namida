import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:basic_audio_handler/basic_audio_handler.dart';
import 'package:just_audio/just_audio.dart' show BitPerfectStatusMessage, BitPerfectReasonMessage, UsbDirectStatusMessage, UsbDirectStateMessage;

import 'package:namida/class/custom_mpv_player.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/audio_output_controller.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/file_browser.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/namida_channel/namida_channel.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/vibrator_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/widgets/animated_widgets.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/disabled_by_pill.dart';
import 'package:namida/ui/widgets/settings/playback_settings.dart';
import 'package:namida/youtube/class/youtube_id.dart';

part 'equalizer_page.parametric.dart';
part 'equalizer_page.signal_path.dart';
part 'equalizer_page.sound_effects.dart';

class SoundControlMainSlidersColumn extends StatefulWidget {
  final double verticalInBetweenPadding;
  final bool tapToUpdate;
  final bool isInDialog;

  const SoundControlMainSlidersColumn({
    super.key,
    required this.verticalInBetweenPadding,
    required this.tapToUpdate,
    required this.isInDialog,
  });

  @override
  State<SoundControlMainSlidersColumn> createState() => _SoundControlMainSlidersColumnState();
}

class _SoundControlMainSlidersColumnState extends State<SoundControlMainSlidersColumn> {
  final _slidersWidgetGlobalKey = GlobalKey<_SoundControlMainSlidersColumnBaseState>();
  final _slidersWidgetPerItemKey = GlobalKey<_SoundControlMainSlidersColumnBaseState>();

  // -- sort of a hack to prevent saving to db while restoring defaults
  bool _saveToDbForCurrentItemConfig = true;

  @override
  Widget build(BuildContext context) {
    var initialIndex = settings.extra.audioConfigPageIndex.value ?? 0;
    if (!settings.player.isPerTrackAudioConfigOverriden.value) {
      final initialCurrentItemConfig = Player.audioConfigs.getSyncOrNull(Player.inst.currentItem.value?.key ?? '');
      final isCurrentItemModified = initialCurrentItemConfig != null && initialCurrentItemConfig != PlayerConfig.initial;
      if (isCurrentItemModified) {
        initialIndex = 1;
      }
    }

    return SplitPage(
      expanded: false,
      joinHeaderChips: true,
      showDivider: false,
      initialIndex: initialIndex,
      onIndexChanged: (index) => settings.extra.audioConfigPageIndex.save(index),
      pages: [
        SplitPageInfo(
          title: lang.global,
          page: _SoundControlMainSlidersColumnBase(
            currentItem: null,
            isInDialog: widget.isInDialog,
            isGlobal: true,
            key: _slidersWidgetGlobalKey,
            verticalInBetweenPadding: widget.verticalInBetweenPadding,
            tapToUpdate: widget.tapToUpdate,
            updateConfig: _SoundControlMainSlidersColumnUpdateConfig.global(),
          ),
        ),
        SplitPageInfo(
          title: lang.item,
          titleIconWidget: Obx(
            (context) {
              final currentConfig = Player.audioConfigs.map.valueR[Player.inst.currentItem.valueR?.key ?? ''];
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: const Icon(
                  Broken.magicpen,
                  size: 16.0,
                ),
              ).animateEntrance(
                showWhen: currentConfig != null,
                durationMS: 300,
              );
            },
          ),
          page: ObxO(
            rx: Player.inst.currentItem,
            builder: (context, currentItem) => currentItem == null
                ? const SizedBox()
                : _TempConfigRxProviders(
                    currentItem: currentItem,
                    key: ValueKey(currentItem),
                    getConfig: () => Player.audioConfigs.get(currentItem.key),
                    getConfigOrNullSync: () => Player.audioConfigs.getSyncOrNull(currentItem.key),
                    builder: (skipSilenceEnabledRx, loudnessEnhancerEnabledRx, loudnessEnhancerRx, equalizerEnabledRx, equalizerRx, presetRx, volumeRx, speedRx, pitchRx) =>
                        _SoundControlMainSlidersColumnBase(
                          key: _slidersWidgetPerItemKey,
                          currentItem: currentItem,
                          isInDialog: widget.isInDialog,
                          isGlobal: false,
                          verticalInBetweenPadding: widget.verticalInBetweenPadding,
                          tapToUpdate: widget.tapToUpdate,
                          updateConfig: _SoundControlMainSlidersColumnUpdateConfig.forCurrentItem(
                            currentItem,
                            saveToDb: () => _saveToDbForCurrentItemConfig,
                            skipSilenceEnabledRx: skipSilenceEnabledRx,
                            loudnessEnhancerEnabledRx: loudnessEnhancerEnabledRx,
                            loudnessEnhancerRx: loudnessEnhancerRx,
                            equalizerEnabledRx: equalizerEnabledRx,
                            equalizerRx: equalizerRx,
                            presetRx: presetRx,
                            volumeRx: volumeRx,
                            speedRx: speedRx,
                            pitchRx: pitchRx,
                          ),
                          forceUseGlobalConfigResetWidget: Obx((context) {
                            final currentConfig = Player.audioConfigs.map.valueR[currentItem.key];
                            final canReset = currentConfig != null;
                            return AnimatedShow(
                              isHorizontal: true,
                              show: canReset,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                tooltip: lang.restoreDefaults,
                                icon: Icon(
                                  Broken.refresh,
                                  size: 20.0,
                                ),
                                onPressed: () async {
                                  _saveToDbForCurrentItemConfig = false;
                                  await _slidersWidgetPerItemKey.currentState?.updateFromConfig(
                                    _SoundControlMainSlidersColumnUpdateConfig.global(),
                                  );
                                  await Player.audioConfigs.delete(currentItem.key);
                                  _saveToDbForCurrentItemConfig = true;
                                },
                              ),
                            );
                          }),
                        ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _SoundControlMainSlidersColumnUpdateConfig {
  final RxBaseCore<bool> skipSilenceEnabledRx;
  final RxBaseCore<bool> loudnessEnhancerEnabledRx;
  final RxBaseCore<double> loudnessEnhancerRx;
  final RxBaseCore<bool> equalizerEnabledRx;
  final RxBaseCore<ParametricEqualizer> equalizerRx;
  final RxBaseCore<EqualizerPreset?> presetRx;
  final RxBaseCore<double> volumeRx;
  final RxBaseCore<double> speedRx;
  final RxBaseCore<double> pitchRx;
  final Future<void> Function(double val) setVolume;
  final Future<void> Function(double val) setSpeed;
  final Future<void> Function(double val) setPitch;
  final Future<void> Function(bool enabled) setSkipSilenceEnabled;
  final Future<void> Function(LoudnessEnhancerExtended? loudnessEnhancer, bool enabled) setLoudnessEnhancerEnabled;
  final Future<void> Function(LoudnessEnhancerExtended? loudnessEnhancer, double val) setLoudnessEnhancer;
  final Future<void> Function(bool enabled) setEqualizerEnabled;

  /// [preset] is the preset [equalizer] came from, null once edited.
  final Future<void> Function(ParametricEqualizer equalizer, EqualizerPreset? preset) setEqualizer;

  const _SoundControlMainSlidersColumnUpdateConfig._({
    required this.skipSilenceEnabledRx,
    required this.loudnessEnhancerEnabledRx,
    required this.loudnessEnhancerRx,
    required this.equalizerEnabledRx,
    required this.equalizerRx,
    required this.presetRx,
    required this.volumeRx,
    required this.speedRx,
    required this.pitchRx,
    required this.setSkipSilenceEnabled,
    required this.setLoudnessEnhancerEnabled,
    required this.setLoudnessEnhancer,
    required this.setEqualizerEnabled,
    required this.setEqualizer,
    required this.setVolume,
    required this.setSpeed,
    required this.setPitch,
  });

  factory _SoundControlMainSlidersColumnUpdateConfig.global() {
    bool canApplyGlobalConfig() => !Player.audioConfigs.itemHasCustomConfig(Player.inst.currentItem.value?.key);
    return _SoundControlMainSlidersColumnUpdateConfig._(
      skipSilenceEnabledRx: settings.player.skipSilenceEnabled,
      loudnessEnhancerEnabledRx: settings.equalizer.loudnessEnhancerEnabled,
      loudnessEnhancerRx: settings.equalizer.loudnessEnhancer,
      equalizerEnabledRx: settings.equalizer.equalizerEnabled,
      equalizerRx: settings.equalizer.equalizer,
      presetRx: settings.equalizer.preset,
      volumeRx: settings.player.volume,
      speedRx: settings.player.speed,
      pitchRx: settings.player.pitch,
      setSkipSilenceEnabled: (enabled) async {
        settings.player.skipSilenceEnabled.save(enabled);

        if (canApplyGlobalConfig()) {
          await Player.inst.setSkipSilenceEnabled(enabled);
        }
      },
      setLoudnessEnhancerEnabled: (loudnessEnhancer, enabled) async {
        settings.equalizer.loudnessEnhancerEnabled.save(enabled);

        if (canApplyGlobalConfig()) {
          if (loudnessEnhancer != null) Player.inst.executeWithPausedOutput(() => loudnessEnhancer.setEnabledUser(enabled));
        }
      },
      setLoudnessEnhancer: (loudnessEnhancer, val) async {
        settings.equalizer.loudnessEnhancer.save(val);

        if (canApplyGlobalConfig()) {
          loudnessEnhancer?.setTargetGainUser(val);
        }
      },
      setEqualizerEnabled: (enabled) async {
        settings.equalizer.equalizerEnabled.save(enabled);

        if (canApplyGlobalConfig()) {
          await Player.inst.equalizerExtended?.apply(enabled, settings.equalizer.equalizer.value);
        }
      },
      setEqualizer: (equalizer, preset) => Player.inst.setGlobalEqualizer(equalizer, preset: preset),
      setVolume: (val) async {
        settings.player.volume.save(val);
        if (canApplyGlobalConfig()) {
          Player.inst.setVolume(val);
        }
      },
      setSpeed: (val) async {
        settings.player.speed.save(val);

        if (canApplyGlobalConfig()) {
          Player.inst.setSpeed(val);
        }
      },
      setPitch: (val) async {
        settings.player.pitch.save(val);

        if (canApplyGlobalConfig()) {
          Player.inst.setPitch(val);
        }
      },
    );
  }

  factory _SoundControlMainSlidersColumnUpdateConfig.forCurrentItem(
    Playable item, {
    required bool Function() saveToDb,
    required final Rx<bool> skipSilenceEnabledRx,
    required final Rx<bool> loudnessEnhancerEnabledRx,
    required final Rx<double> loudnessEnhancerRx,
    required final Rx<bool> equalizerEnabledRx,
    required final Rx<ParametricEqualizer> equalizerRx,
    required final Rxn<EqualizerPreset> presetRx,
    required final Rx<double> volumeRx,
    required final Rx<double> speedRx,
    required final Rx<double> pitchRx,
  }) => _SoundControlMainSlidersColumnUpdateConfig._(
    skipSilenceEnabledRx: skipSilenceEnabledRx,
    loudnessEnhancerEnabledRx: loudnessEnhancerEnabledRx,
    loudnessEnhancerRx: loudnessEnhancerRx,
    equalizerEnabledRx: equalizerEnabledRx,
    equalizerRx: equalizerRx,
    presetRx: presetRx,
    volumeRx: volumeRx,
    speedRx: speedRx,
    pitchRx: pitchRx,
    setSkipSilenceEnabled: (enabled) async {
      skipSilenceEnabledRx.value = enabled;
      Player.inst.setSkipSilenceEnabled(enabled);
      if (saveToDb()) await Player.audioConfigs.updateProperty(item.key, (current) => current.copyWith(skipSilence: enabled));
    },
    setLoudnessEnhancerEnabled: (loudnessEnhancer, enabled) async {
      loudnessEnhancerEnabledRx.value = enabled;
      if (loudnessEnhancer != null) Player.inst.executeWithPausedOutput(() => loudnessEnhancer.setEnabledUser(enabled));
      if (saveToDb()) await Player.audioConfigs.updateProperty(item.key, (current) => current.copyWith(loudnessEnhancerEnabled: enabled));
    },
    setLoudnessEnhancer: (loudnessEnhancer, val) async {
      loudnessEnhancerRx.value = val;
      loudnessEnhancer?.setTargetGainUser(val);
      if (saveToDb()) await Player.audioConfigs.updateProperty(item.key, (current) => current.copyWith(loudnessEnhancer: val));
    },
    setEqualizerEnabled: (enabled) async {
      equalizerEnabledRx.value = enabled;
      await Player.inst.equalizerExtended?.apply(enabled, equalizerRx.value);
      if (saveToDb()) await Player.audioConfigs.updateProperty(item.key, (current) => current.copyWith(equalizerEnabled: enabled));
    },
    setEqualizer: (equalizer, preset) async {
      equalizerRx.value = equalizer;
      presetRx.value = preset;
      await Player.inst.equalizerExtended?.apply(equalizerEnabledRx.value, equalizer);
      if (saveToDb()) await Player.audioConfigs.updateProperty(item.key, (current) => current.copyWithEqualizer(equalizer, preset));
    },
    setVolume: (val) async {
      volumeRx.value = val;
      Player.inst.setVolume(val);
      if (saveToDb()) await Player.audioConfigs.updateProperty(item.key, (current) => current.copyWith(volume: val));
    },
    setSpeed: (val) async {
      speedRx.value = val;
      Player.inst.setSpeed(val);
      if (saveToDb()) await Player.audioConfigs.updateProperty(item.key, (current) => current.copyWith(speed: val));
    },
    setPitch: (val) async {
      pitchRx.value = val;
      Player.inst.setPitch(val);
      if (saveToDb()) await Player.audioConfigs.updateProperty(item.key, (current) => current.copyWith(pitch: val));
    },
  );
}

class _SoundControlMainSlidersColumnBase extends StatefulWidget {
  final Playable? currentItem;
  final bool isInDialog;
  final bool isGlobal;
  final Widget? forceUseGlobalConfigResetWidget;
  final double verticalInBetweenPadding;
  final bool tapToUpdate;
  final _SoundControlMainSlidersColumnUpdateConfig updateConfig;

  const _SoundControlMainSlidersColumnBase({
    required super.key,
    required this.currentItem,
    required this.isInDialog,
    required this.isGlobal,
    this.forceUseGlobalConfigResetWidget,
    required this.verticalInBetweenPadding,
    required this.tapToUpdate,
    required this.updateConfig,
  });

  @override
  State<_SoundControlMainSlidersColumnBase> createState() => _SoundControlMainSlidersColumnBaseState();
}

class _SoundControlMainSlidersColumnBaseState extends State<_SoundControlMainSlidersColumnBase> {
  LoudnessEnhancerExtended? get _loudnessEnhancerExtended => Player.inst.loudnessEnhancerExtended;
  final _loudnessKey = GlobalKey<_CuteSliderState>();

  final pitchKey = GlobalKey<_CuteSliderState>();
  final speedKey = GlobalKey<_CuteSliderState>();
  final volumeKey = GlobalKey<_CuteSliderState>();

  Future<void> updateFromConfig(_SoundControlMainSlidersColumnUpdateConfig config) async {
    await _setSpeed(config.speedRx.value);
    if (settings.player.linkSpeedPitch.value) {
      // -- apply speed to pitch if they were linked
      await _setPitch(config.speedRx.value);
    } else {
      await _setPitch(config.pitchRx.value);
    }
    await _setVolume(config.volumeRx.value);

    await _setSkipSilence(config.skipSilenceEnabledRx.value);
    await _setLoudnessEnhancerEnabled(config.loudnessEnhancerEnabledRx.value);
    await _setLoudnessEnhancer(config.loudnessEnhancerRx.value);

    await widget.updateConfig.setEqualizerEnabled(config.equalizerEnabledRx.value);
    await widget.updateConfig.setEqualizer(config.equalizerRx.value, config.presetRx.value);
  }

  Future<void> _setSpeed(double value) async {
    speedKey.currentState?.updateValExternal(value);
    await widget.updateConfig.setSpeed(value);

    if (settings.player.linkSpeedPitch.value) {
      pitchKey.currentState?.updateValExternal(value);
      await widget.updateConfig.setPitch(value);
    }
  }

  Future<void> _setPitch(double value) async {
    pitchKey.currentState?.updateValExternal(value);
    await widget.updateConfig.setPitch(value);
  }

  Future<void> _setVolume(double value) async {
    volumeKey.currentState?.updateValExternal(value);
    await widget.updateConfig.setVolume(value);
  }

  Future<void> _setSkipSilence(bool enabled) async {
    await widget.updateConfig.setSkipSilenceEnabled(enabled);
  }

  Future<void> _setLoudnessEnhancerEnabled(bool enabled) async {
    await widget.updateConfig.setLoudnessEnhancerEnabled(_loudnessEnhancerExtended, enabled);
  }

  Future<void> _setLoudnessEnhancer(double val) async {
    _loudnessKey.currentState?.updateValExternal(val);
    await widget.updateConfig.setLoudnessEnhancer(_loudnessEnhancerExtended, val);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final verticalPadding = SizedBox(height: widget.verticalInBetweenPadding);
    final currentItem = widget.currentItem;
    return Column(
      mainAxisSize: .min,
      children: [
        if (currentItem != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: SizedBox(
              width: context.width,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 38.0),
                child: PlayableTitleSubtitleWidget(
                  isYTID: currentItem is YoutubeID,
                  builder: (title, artist) => NamidaCoolBox(
                    extraVPadding: true,
                    colorScheme: theme.colorScheme.secondary,
                    builder: (context) => Row(
                      children: [
                        const Icon(
                          Broken.music_square,
                          size: 20.0,
                        ),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: Text(
                            [
                              artist,
                              title,
                            ].joinText(separator: ' - '),
                            style: textTheme.displayMedium?.copyWith(fontSize: 14.0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: widget.verticalInBetweenPadding * 0.5),
        ],

        if (!widget.isGlobal)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: NamidaInkWell(
              borderRadius: 8.0,
              onTap: () {
                settings.player.isPerTrackAudioConfigOverriden.save(!settings.player.isPerTrackAudioConfigOverriden.value);
                Player.inst.refreshCurrentItemPlayerConfig();
              },
              child: NamidaCoolBox(
                borderRadius: BorderRadius.circular(8.0.multipliedRadius),
                colorScheme: theme.colorScheme.secondary,
                builder: (context) => Row(
                  mainAxisSize: .min,
                  children: [
                    const Icon(
                      Broken.autobrightness,
                      size: 20.0,
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: Text(
                        lang.forceUseGlobalConfig,
                        style: textTheme.displayMedium?.copyWith(fontSize: 14.0),
                      ),
                    ),
                    if (widget.forceUseGlobalConfigResetWidget != null) ...[
                      widget.forceUseGlobalConfigResetWidget!,
                      const SizedBox(width: 8.0),
                    ],
                    ObxO(
                      rx: settings.player.isPerTrackAudioConfigOverriden,
                      builder: (context, overriden) => NamidaCheckMark(
                        size: 18.0,
                        active: overriden,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                  ],
                ),
              ),
            ),
          ),
        SizedBox(height: widget.verticalInBetweenPadding * 0.5),

        NamidaContainerDivider(
          margin: const EdgeInsets.symmetric(horizontal: 14.0),
        ),

        SizedBox(height: widget.verticalInBetweenPadding * 0.5),
        ObxPrefer(
          enabled: !widget.isGlobal,
          rx: settings.player.isPerTrackAudioConfigOverriden,
          builder: (context, overriden) => AnimatedEnabled(
            enabled: overriden == null ? true : !overriden,
            child: Column(
              mainAxisSize: .min,
              children: [
                const _ForcedOffBanner(),
                if (NamidaFeaturesVisibility.skipSilenceAvailable) ...[
                  Obx(
                    (context) {
                      final skipSilence = widget.updateConfig.skipSilenceEnabledRx.valueR;
                      final currentItem = Player.inst.currentItem.valueR;
                      final isSupported = Player.inst.supportsSkipSilence(currentItem);
                      final isForcedOff = AudioOutputController.inst.isForcedOffR(AudioOutputForcedOff.skipSilence);
                      return AnimatedEnabled(
                        enabled: isSupported && !isForcedOff,
                        child: Padding(
                          padding: const EdgeInsetsGeometry.symmetric(vertical: 2.0, horizontal: 8.0),
                          child: NamidaInkWell(
                            borderRadius: 12.0,
                            padding: const EdgeInsetsGeometry.symmetric(vertical: 10.0),
                            onTap: () => _setSkipSilence(!skipSilence),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: Row(
                                children: [
                                  NamidaIconButton(
                                    horizontalPadding: 6.0,
                                    icon: Broken.forward,
                                  ),
                                  const SizedBox(width: 6.0),
                                  Expanded(
                                    child: Text(
                                      lang.skipSilence,
                                      style: textTheme.displayLarge?.copyWith(fontSize: 16.0),
                                    ),
                                  ),
                                  const SizedBox(width: 8.0),
                                  CustomSwitch(
                                    active: skipSilence,
                                  ),
                                  const SizedBox(width: 8.0),
                                  const SizedBox(width: 6.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  verticalPadding,
                ],

                _ForcedOffEnabled(
                  option: AudioOutputForcedOff.pitch,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ObxO(
                        rx: settings.player.useSemitones,
                        builder: (context, isSemitones) => ObxO(
                          rx: settings.player.linkSpeedPitch,
                          builder: (context, enabled) => AnimatedEnabled(
                            enabled: !enabled,
                            child: Obx(
                              (context) {
                                final pitch = widget.updateConfig.pitchRx.valueR;
                                const hz432Value = 432.0 / 440.0;
                                final is432HzEnabled = pitch == hz432Value;
                                return _SliderTextWidget(
                                  icon: Broken.airpods,
                                  min: isSemitones ? -12.0 : 0.5,
                                  max: isSemitones ? 12.0 : 2.0,
                                  title: lang.pitch,
                                  subtitle: isSemitones ? '(${lang.semitones})' : '(${lang.percentage})',
                                  onTap: () {
                                    settings.player.useSemitones.save(!settings.player.useSemitones.value);
                                  },
                                  value: pitch,
                                  valToText: isSemitones ? _SliderTextWidget.toSemitones : _SliderTextWidget.toPercentage,
                                  valueModifier: isSemitones ? _SliderTextWidget.ratioToSemitonesRound : null,
                                  restoreDefault: () => _setPitch(1.0),
                                  onManualChange: (convertedValue) {
                                    pitchKey.currentState?._updateValNoRound(convertedValue); // no conversion
                                  },
                                  featuredButton: NamidaInkWellButton(
                                    icon: null,
                                    text: '',
                                    borderRadius: 8.0,
                                    sizeMultiplier: 0.9,
                                    paddingMultiplier: 0.7,
                                    bgColor: theme.colorScheme.secondaryContainer.withOpacityExt(is432HzEnabled ? 0.5 : 0.2),
                                    onTap: () {
                                      final newValue = is432HzEnabled ? 1.0 : hz432Value;
                                      widget.updateConfig.setPitch(newValue);
                                      pitchKey.currentState?.updateValNoRoundExternal(newValue);
                                    },
                                    leading: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '✓ ',
                                          style: textTheme.displaySmall,
                                        ).animateEntrance(
                                          showWhen: is432HzEnabled,
                                          allCurves: Curves.fastLinearToSlowEaseIn,
                                          durationMS: 300,
                                        ),
                                        Text(
                                          '432Hz',
                                          style: textTheme.displaySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      ObxO(
                        rx: settings.player.useSemitones,
                        builder: (context, isSemitones) => ObxO(
                          rx: settings.player.linkSpeedPitch,
                          builder: (context, enabled) => AnimatedEnabled(
                            enabled: !enabled,
                            child: isSemitones
                                ? _CuteSlider<double>(
                                    key: pitchKey,
                                    min: -12.0,
                                    max: 12.0,
                                    divisions: 48, // 48 steps = 0.5 semitone steps from -12 to +12
                                    incremental: 0.5,
                                    valueListenable: widget.updateConfig.pitchRx,
                                    valueModifier: _SliderTextWidget.ratioToSemitones,
                                    onChanged: (semitones) {
                                      final ratio = _SliderTextWidget.semitonesToRatio(semitones);
                                      widget.updateConfig.setPitch(ratio);
                                    },
                                    tapToUpdate: widget.tapToUpdate,
                                    valToText: _SliderTextWidget.toSemitones,
                                  )
                                : _CuteSlider(
                                    key: pitchKey,
                                    min: 0.5,
                                    divisions: 150,
                                    valueListenable: widget.updateConfig.pitchRx,
                                    onChanged: (value) {
                                      widget.updateConfig.setPitch(value);
                                    },
                                    tapToUpdate: widget.tapToUpdate,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                verticalPadding,
                _ForcedOffEnabled(
                  option: AudioOutputForcedOff.speed,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Obx(
                        (context) => _SliderTextWidget(
                          icon: Broken.forward,
                          title: lang.speed,
                          min: 0.1,
                          value: widget.updateConfig.speedRx.valueR,
                          onManualChange: (value) {
                            speedKey.currentState?.updateValNoRoundExternal(value);
                            if (settings.player.linkSpeedPitch.value) {
                              pitchKey.currentState?.updateValNoRoundExternal(value);
                            }
                          },
                          restoreDefault: () => _setSpeed(1.0),
                          useMaxToLimitPreciseValue: false,
                          valToText: _SliderTextWidget.toXMultiplier,
                          featuredButton: ObxO(
                            rx: settings.player.linkSpeedPitch,
                            builder: (context, enabled) => NamidaInkWellButton(
                              icon: null,
                              text: '',
                              borderRadius: 8.0,
                              sizeMultiplier: 0.9,
                              paddingMultiplier: 0.7,
                              bgColor: theme.colorScheme.secondaryContainer.withOpacityExt(enabled ? 0.5 : 0.2),
                              onTap: () {
                                final newLinkValue = !settings.player.linkSpeedPitch.value;
                                final newValue = newLinkValue ? widget.updateConfig.speedRx.value : widget.updateConfig.pitchRx.value;
                                widget.updateConfig.setPitch(newValue);
                                settings.player.linkSpeedPitch.save(newLinkValue);
                                pitchKey.currentState?.updateValNoRoundExternal(newValue);
                              },
                              leading: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 4.0),
                                    child: Icon(
                                      Broken.link_21,
                                      size: 12.0,
                                    ),
                                  ).animateEntrance(
                                    showWhen: enabled,
                                    allCurves: Curves.fastLinearToSlowEaseIn,
                                    durationMS: 300,
                                  ),
                                  Text(
                                    lang.pitch,
                                    style: textTheme.displaySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      _CuteSlider(
                        key: speedKey,
                        min: 0.1,
                        divisions: 190,
                        valueListenable: widget.updateConfig.speedRx,
                        onChanged: (value) async {
                          await widget.updateConfig.setSpeed(value);

                          if (settings.player.linkSpeedPitch.value) {
                            await widget.updateConfig.setPitch(value);
                          }
                        },
                        tapToUpdate: widget.tapToUpdate,
                      ),
                    ],
                  ),
                ),
                verticalPadding,
                _ForcedOffEnabled(
                  option: AudioOutputForcedOff.volume,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Obx(
                        (context) {
                          final normalVolume = widget.updateConfig.volumeRx.valueR;
                          final replayGainLinear = Player.inst.replayGainLinearVolumeMultiplierRx.valueR;
                          final replayGainText = replayGainLinear == 1.0 ? '' : ' (N: ${_SliderTextWidget.toPercentage(normalVolume * replayGainLinear)})';
                          return _SliderTextWidget(
                            icon: normalVolume > 0 ? Broken.volume_up : Broken.volume_slash,
                            title: lang.volume,
                            value: normalVolume,
                            max: 1.0,
                            valToText: (val) => '${_SliderTextWidget.toPercentage(val)}$replayGainText',
                            onManualChange: (value) {
                              volumeKey.currentState?.updateValNoRoundExternal(value);
                            },
                            restoreDefault: () => _setVolume(1.0),
                          );
                        },
                      ),
                      _CuteSlider(
                        key: volumeKey,
                        max: 1.0,
                        valueListenable: widget.updateConfig.volumeRx,
                        onChanged: (value) {
                          widget.updateConfig.setVolume(value);
                        },
                        tapToUpdate: widget.tapToUpdate,
                      ),
                    ],
                  ),
                ),

                verticalPadding,
                if (NamidaFeaturesVisibility.loudnessEnhancerAvailable)
                  _ForcedOffEnabled(
                    option: AudioOutputForcedOff.loudnessEnhancer,
                    child: ObxO(
                      rx: widget.updateConfig.loudnessEnhancerEnabledRx,
                      builder: (context, enabled) => ObxO(
                        rx: widget.updateConfig.loudnessEnhancerRx,
                        builder: (context, targetGainUser) => ObxOrNull(
                          rx: _loudnessEnhancerExtended?.targetGainTrack,
                          builder: (context, targetGainTrack) {
                            final replayGainText = targetGainTrack == 0.0
                                ? ''
                                : ' (N: ${_SliderTextWidget.toDecibelMultiplier(_loudnessEnhancerExtended?.getActualGainFromUser(enabled, targetGainUser) ?? 0)})';
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                NamidaInkWell(
                                  onTap: () => _setLoudnessEnhancerEnabled(!enabled),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                                    child: _SliderTextWidget(
                                      icon: targetGainUser > 0 ? Broken.volume_high : Broken.volume_low_1,
                                      title: '${lang.loudnessEnhancer} (PreAmp)',
                                      value: targetGainUser,
                                      min: LoudnessEnhancerExtended.kMinGain,
                                      max: LoudnessEnhancerExtended.kMaxGain,
                                      valToText: (val) => '${_SliderTextWidget.toDecibelMultiplier(val)}$replayGainText',
                                      onManualChange: (newVal) {
                                        _loudnessKey.currentState?.updateValNoRoundExternal(newVal);
                                      },
                                      restoreDefault: () => _setLoudnessEnhancer(0.0),
                                      trailing: CustomSwitch(
                                        active: enabled,
                                        passedColor: null,
                                      ),
                                    ),
                                  ),
                                ),
                                ObxO(
                                  rx: settings.equalizer.uiTapToUpdate,
                                  builder: (context, uiTapToUpdate) => _CuteSlider(
                                    key: _loudnessKey,
                                    valueListenable: widget.updateConfig.loudnessEnhancerRx,
                                    min: LoudnessEnhancerExtended.kMinGain,
                                    max: LoudnessEnhancerExtended.kMaxGain,
                                    valToText: _SliderTextWidget.toDecibelMultiplier,
                                    onChanged: (newVal) {
                                      widget.updateConfig.setLoudnessEnhancer(_loudnessEnhancerExtended, newVal);
                                    },
                                    tapToUpdate: uiTapToUpdate,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                if (NamidaFeaturesVisibility.equalizerAvailable && !widget.isInDialog)
                  _ForcedOffEnabled(
                    option: AudioOutputForcedOff.equalizer,
                    child: _ParametricEqualizerSection(
                      updateConfig: widget.updateConfig,
                      isGlobal: widget.isGlobal,
                    ),
                  ),

                verticalPadding,

                NamidaContainerDivider(
                  margin: EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: widget.verticalInBetweenPadding / 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class SoundControlPage extends StatefulWidget {
  const SoundControlPage({super.key});

  static void showAudioPath() {
    NamidaNavigator.inst.showSheet(
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context, bottomPadding, maxWidth, maxHeight) => _SignalPathSheet(maxHeight: maxHeight),
    );
  }

  @override
  SoundControlPageState createState() => SoundControlPageState();
}

class SoundControlPageState extends State<SoundControlPage> {
  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    const verticalInBetweenPaddingH = 8.0;
    const verticalInBetweenPadding = SizedBox(height: verticalInBetweenPaddingH);
    return AnimatedThemeOrTheme(
      duration: const Duration(milliseconds: kThemeAnimationDurationMS),
      data: theme,
      child: BackgroundWrapper(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                color: theme.cardColor,
              ),
              child: Column(
                children: [
                  verticalInBetweenPadding,
                  verticalInBetweenPadding,
                  Row(
                    children: [
                      const SizedBox(width: 6.0),
                      NamidaIconButton(
                        verticalPadding: 6.0,
                        horizontalPadding: 12.0,
                        icon: Broken.arrow_left_1,
                        iconSize: 24.0,
                        onPressed: NamidaNavigator.inst.popRoot,
                      ),
                      const SizedBox(width: 6.0),
                      const Icon(Broken.sound),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: Text(
                          "${lang.configure} (${lang.beta})",
                          style: textTheme.displayMedium,
                        ),
                      ),
                      NamidaIconButton(
                        horizontalPadding: 8.0,
                        tooltip: () => lang.tapToSeek,
                        icon: null,
                        iconSize: 24.0,
                        onPressed: () => settings.equalizer.uiTapToUpdate.save(!settings.equalizer.uiTapToUpdate.value),
                        child: ObxO(
                          rx: settings.equalizer.uiTapToUpdate,
                          builder: (context, val) => StackedIcon(
                            baseIcon: Broken.mouse_1,
                            secondaryIcon: val ? Broken.tick_circle : Broken.close_circle,
                            secondaryIconSize: 12.0,
                            iconSize: 24.0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12.0),

                      const SizedBox(width: 8.0),
                    ],
                  ),
                  const SizedBox(height: 6.0),
                  Expanded(
                    child: SmoothSingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const _AudioOutputSection(),
                          NamidaContainerDivider(
                            margin: EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: verticalInBetweenPaddingH / 2,
                            ),
                          ),
                          const PlaybackSettings().getNormalizeAudioWidget(isInEQPage: true),
                          NamidaContainerDivider(
                            margin: EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: verticalInBetweenPaddingH / 2,
                            ),
                          ),
                          ObxO(
                            rx: settings.equalizer.uiTapToUpdate,
                            builder: (context, uiTapToUpdate) => SoundControlMainSlidersColumn(
                              verticalInBetweenPadding: verticalInBetweenPaddingH,
                              tapToUpdate: uiTapToUpdate,
                              isInDialog: false,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: const _MonoAudioTile(),
                          ),
                          if (NamidaFeaturesVisibility.soundEffectsAvailable)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: const _SoundEffectsSection(),
                            ),
                          verticalInBetweenPadding,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SliderTextWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final double value;
  final double min;
  final double max;
  final bool useMaxToLimitPreciseValue;
  final Widget? featuredButton;
  final VoidCallback? restoreDefault;
  final Widget? trailing;
  final bool displayValue;
  final String Function(double val) valToText;
  final double Function(double val)? valueModifier;
  final void Function(double convertedValue)? onManualChange;
  final void Function()? onTap;

  const _SliderTextWidget({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    this.min = 0.0,
    this.max = 2.0,
    this.useMaxToLimitPreciseValue = true,
    this.featuredButton,
    this.restoreDefault,
    this.trailing,
    this.displayValue = true,
    this.valToText = toPercentage,
    this.valueModifier,
    this.onManualChange,
    this.onTap,
  });

  static String toPercentageInt(double val) => "${(val * 100).toStringAsFixed(0)}%";
  static String toPercentage(double val) => "${(val * 100).roundDecimals(2)}%";
  static String toXMultiplier(double val) => "${val.toStringAsFixed(2)}x";
  static String toDecibelMultiplier(double val) => "${val.toStringAsFixed(1)}dB";

  static String toSemitones(double semitones) {
    return '${semitones.toStringAsFixed(1)} st';
  }

  static double ratioToSemitonesRound(double ratio) {
    return ratioToSemitones(ratio).roundDecimals(1);
  }

  static double ratioToSemitones(double ratio) {
    if (ratio <= 0) return -12.0;
    return 12.0 * math.log(ratio) / math.log(2);
  }

  static double semitonesToRatio(double semitones) {
    return math.pow(2.0, semitones / 12.0).toDouble();
  }

  void _showPreciseValueConfig({required double initial, required void Function(double val) onChanged}) {
    showNamidaBottomSheetWithTextField(
      title: title,
      textfieldConfig: BottomSheetTextFieldConfig(
        hintText: initial.toString(),
        labelText: title,
        initalControllerText: initial.toString(),
        validator: (text) {
          if (text == null || text.isEmpty) {
            return lang.emptyValue;
          }
          final doubleval = double.tryParse(text);
          if (doubleval == null) return lang.nameContainsBadCharacter;
          if (doubleval < min || (useMaxToLimitPreciseValue && doubleval > max)) return '$min | +$max';
          return null;
        },
      ),
      buttonText: lang.save,
      onButtonTap: (text) {
        final doubleval = double.tryParse(text);
        if (doubleval == null) return false;
        onChanged(doubleval);
        return true;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final valueActual = valueModifier?.call(value) ?? value;
    final subtitle = this.subtitle;
    Widget child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        children: [
          NamidaIconButton(
            horizontalPadding: 6.0,
            icon: icon,
            onPressed: onManualChange == null
                ? null
                : () => _showPreciseValueConfig(
                    initial: valueActual,
                    onChanged: onManualChange!,
                  ),
          ),
          const SizedBox(width: 6.0),
          Flexible(
            child: Row(
              children: [
                Flexible(
                  child: Column(
                    mainAxisSize: .min,
                    crossAxisAlignment: .start,
                    children: [
                      Row(
                        mainAxisSize: .min,
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: textTheme.displayLarge?.copyWith(fontSize: 16.0),
                            ),
                          ),

                          if (onTap != null) const SizedBox(width: 4.0),
                          if (onTap != null)
                            Icon(
                              Broken.arrange_circle_2,
                              size: 12.0,
                            ),
                        ],
                      ),

                      if (subtitle != null && subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: textTheme.displaySmall?.copyWith(fontSize: 10.0),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8.0),
                if (displayValue)
                  Text(
                    valToText(valueActual),
                    style: textTheme.displayMedium?.copyWith(fontSize: 13.5),
                  ),
              ],
            ),
          ),
          if (featuredButton != null) const SizedBox(width: 2.0),
          ?featuredButton,
          const SizedBox(width: 6.0),
          if (restoreDefault != null)
            IconButton(
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              tooltip: lang.restoreDefaults,
              icon: Icon(
                Broken.refresh,
                size: 20.0,
              ),
              onPressed: restoreDefault,
            ),
          if (restoreDefault != null) const SizedBox(width: 8.0),
          ?trailing,
          const SizedBox(width: 2.0),
        ],
      ),
    );
    if (onTap != null) {
      child = NamidaInkWell(
        borderRadius: 12.0,
        padding: const EdgeInsetsGeometry.symmetric(vertical: 6.0),
        onTap: onTap,
        child: child,
      );
    }
    return Padding(
      padding: const EdgeInsetsGeometry.symmetric(vertical: 2.0, horizontal: 8.0),
      child: child,
    );
  }
}

class _CuteSlider<T> extends StatefulWidget {
  final double min;
  final double max;
  final RxBaseCore<double> valueListenable;
  final void Function(double newValue) onChanged;
  final String Function(double val) valToText;
  final double Function(double val)? valueModifier;
  final double incremental;
  final int divisions;
  final bool tapToUpdate;

  const _CuteSlider({
    required super.key,
    this.min = 0.0,
    this.max = 2.0,
    this.divisions = 200,
    required this.valueListenable,
    required this.onChanged,
    this.valueModifier,
    this.valToText = _SliderTextWidget.toPercentageInt,
    this.incremental = 0.01,
    required this.tapToUpdate,
  });

  @override
  State<_CuteSlider> createState() => _CuteSliderState();
}

class _CuteSliderState extends State<_CuteSlider> {
  late double _currentVal;

  @override
  void initState() {
    _currentVal = widget.valueModifier?.call(widget.valueListenable.value) ?? widget.valueListenable.value;
    widget.valueListenable.addListener(_valueListener);
    super.initState();
  }

  @override
  void didUpdateWidget(covariant _CuteSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.valueListenable != widget.valueListenable) {
      oldWidget.valueListenable.removeListener(_valueListener);
      widget.valueListenable.addListener(_valueListener);
      final newVal = widget.valueModifier?.call(widget.valueListenable.value) ?? widget.valueListenable.value;
      if (newVal != _currentVal) setState(() => _currentVal = newVal);
    }
  }

  @override
  void dispose() {
    widget.valueListenable.removeListener(_valueListener);
    super.dispose();
  }

  void updateValExternal(double newVal) {
    final requiredValue = widget.valueModifier?.call(newVal) ?? newVal;
    _updateVal(requiredValue);
  }

  void updateValNoRoundExternal(double newVal) {
    final requiredValue = widget.valueModifier?.call(newVal) ?? newVal;
    _updateValNoRound(requiredValue);
  }

  void _valueListener() {
    final ratio = widget.valueListenable.value;
    final requiredValue = widget.valueModifier?.call(ratio) ?? ratio;

    if (requiredValue != _currentVal) {
      setState(() => _currentVal = requiredValue);
    }
  }

  @protected
  void _updateVal(double newVal, {bool callOnChanged = true}) {
    final finalVal = newVal.roundDecimals(4);
    if (finalVal != _currentVal) {
      setState(() {
        _currentVal = finalVal;
        if (callOnChanged) widget.onChanged(finalVal);
      });
    }
  }

  @protected
  void _updateValNoRound(double newVal) {
    final finalVal = newVal;
    if (finalVal != _currentVal) {
      setState(() {
        _currentVal = finalVal;
        widget.onChanged(finalVal);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final incremental = widget.incremental;
    final interaction = widget.tapToUpdate ? SliderInteraction.tapAndSlide : SliderInteraction.slideOnly;
    final sliderValue = _currentVal.withMinimum(widget.min).withMaximum(widget.max); // -- can be outside, ex: pitch linked to speed
    return Row(
      children: [
        const SizedBox(width: 12.0),
        _getArrowIcon(
          icon: Broken.arrow_left_2,
          callback: () {
            final newVal = (_currentVal - incremental).withMinimum(widget.min);
            _updateVal(newVal);
          },
        ),
        Expanded(
          child: Slider.adaptive(
            min: widget.min,
            max: widget.max,
            value: sliderValue,
            onChanged: _updateVal,
            divisions: widget.divisions,
            label: widget.valToText(_currentVal),
            allowedInteraction: interaction,
          ),
        ),
        if (_currentVal > widget.max)
          Icon(
            Broken.flash,
            size: 16.0,
          ),
        _getArrowIcon(
          icon: Broken.arrow_right_3,
          callback: () {
            final newVal = (_currentVal + incremental).withMaximum(widget.max);
            _updateVal(newVal);
          },
        ),
        const SizedBox(width: 12.0),
      ],
    );
  }
}

Timer? _longPressTimer;

Widget _getArrowIcon({required IconData icon, required VoidCallback callback}) {
  return NamidaIconButton(
    verticalPadding: 4.0,
    horizontalPadding: 4.0,
    icon: icon,
    iconSize: 20.0,
    onPressed: () {
      callback();
    },
    onLongPressStart: (_) {
      callback();
      _longPressTimer?.cancel();
      _longPressTimer = Timer.periodic(const Duration(milliseconds: 100), (ticker) {
        callback();
      });
    },
    onLongPressFinish: () {
      _longPressTimer?.cancel();
    },
  );
}

class VerticalSlider extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final double circleWidth;
  final ValueChanged<double> onChanged;
  final bool Function() tapToUpdate;

  const VerticalSlider({
    super.key,
    required this.value,
    this.min = 0.0,
    this.max = 1.0,
    required this.circleWidth,
    required this.onChanged,
    required this.tapToUpdate,
  });

  @override
  State<VerticalSlider> createState() => _VerticalSliderState();
}

class _VerticalSliderState extends State<VerticalSlider> {
  final _isPointerDown = false.obs;

  @override
  void dispose() {
    _isPointerDown.close();
    super.dispose();
  }

  void updateValExternalue(BoxConstraints constraints, double total, double dy) {
    final inversePosition = constraints.maxHeight - dy;
    final heightPerc = inversePosition / constraints.maxHeight;
    final finalValue = (heightPerc * total + widget.min).clampDouble(widget.min, widget.max);
    widget.onChanged(finalValue);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    const circleHeight = 32.0;
    final circleWidth = widget.circleWidth;
    final total = widget.min.abs() + widget.max;

    final topButton = Positioned(
      bottom: 0,
      top: 0,
      child: SizedBox(
        width: 6.0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.secondary.withOpacityExt(0.2),
            borderRadius: const BorderRadius.all(
              Radius.circular(12.0),
            ),
          ),
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final finalVal = (widget.value - widget.min) / (widget.max - widget.min);
        final height = constraints.maxHeight * finalVal;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: (details) {
            if (widget.tapToUpdate()) updateValExternalue(constraints, total, details.localPosition.dy);
            _isPointerDown.value = true;
          },
          onTapUp: (details) => _isPointerDown.value = false,
          onVerticalDragEnd: (_) {
            _isPointerDown.value = false;
            if (widget.value.abs() <= 0.4) {
              // -- clamp if near center
              widget.onChanged(0);
              VibratorController.high();
            }
          },
          onVerticalDragCancel: () => _isPointerDown.value = false,
          onVerticalDragStart: (details) {
            updateValExternalue(constraints, total, details.localPosition.dy);
          },
          onVerticalDragUpdate: (details) {
            updateValExternalue(constraints, total, details.localPosition.dy);
          },
          child: SizedBox(
            width: circleWidth * 2,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                topButton,
                Positioned(
                  bottom: 0,
                  child: AnimatedSizedBox(
                    duration: const Duration(milliseconds: 50),
                    height: height,
                    width: 8.0,
                    animateWidth: false,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacityExt(0.5),
                      borderRadius: const BorderRadius.all(
                        Radius.circular(12.0),
                      ),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 50),
                  bottom: height - circleHeight / 2,
                  child: Obx(
                    (context) => AnimatedScale(
                      duration: const Duration(milliseconds: 200),
                      scale: _isPointerDown.valueR ? 1.2 : 1.0,
                      child: Container(
                        width: circleWidth,
                        height: circleHeight,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(12.0),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TempConfigRxProviders extends StatefulWidget {
  final Playable currentItem;
  final FutureOr<PlayerConfig?> Function() getConfig;
  final PlayerConfig? Function() getConfigOrNullSync;
  final Widget Function(
    Rx<bool> skipSilenceEnabledRx,
    Rx<bool> loudnessEnhancerEnabledRx,
    Rx<double> loudnessEnhancerRx,
    Rx<bool> equalizerEnabledRx,
    Rx<ParametricEqualizer> equalizerRx,
    Rxn<EqualizerPreset> preset,
    Rx<double> volumeRx,
    Rx<double> speedRx,
    Rx<double> pitchRx,
  )
  builder;
  const _TempConfigRxProviders({required super.key, required this.currentItem, required this.getConfig, required this.getConfigOrNullSync, required this.builder});

  @override
  State<_TempConfigRxProviders> createState() => __TempConfigRxProvidersState();
}

class __TempConfigRxProvidersState extends State<_TempConfigRxProviders> {
  final skipSilenceEnabledRx = Rx<bool>(false);
  final loudnessEnhancerEnabledRx = Rx<bool>(false);
  final loudnessEnhancerRx = Rx<double>(0.0);
  final equalizerEnabledRx = Rx<bool>(false);
  final equalizerRx = Rx<ParametricEqualizer>(ParametricEqualizer.flat);
  final presetRx = Rxn<EqualizerPreset>();
  final volumeRx = Rx<double>(1.0);
  final speedRx = Rx<double>(1.0);
  final pitchRx = Rx<double>(1.0);

  @override
  void initState() {
    _fillData();
    super.initState();
  }

  @override
  void dispose() {
    skipSilenceEnabledRx.close();
    loudnessEnhancerEnabledRx.close();
    loudnessEnhancerRx.close();
    equalizerEnabledRx.close();
    equalizerRx.close();
    presetRx.close();
    volumeRx.close();
    speedRx.close();
    pitchRx.close();
    super.dispose();
  }

  Future<void> _fillData() async {
    var config = widget.getConfigOrNullSync() ?? await widget.getConfig();
    config ??= Player.inst.getDefaultPlayerConfig(widget.currentItem);
    skipSilenceEnabledRx.value = config.skipSilence;
    loudnessEnhancerEnabledRx.value = config.loudnessEnhancerEnabled;
    loudnessEnhancerRx.value = config.loudnessEnhancer;
    equalizerEnabledRx.value = config.equalizerEnabled;
    equalizerRx.value = config.equalizer;
    presetRx.value = config.preset;
    volumeRx.value = config.volume;
    speedRx.value = config.speed;
    pitchRx.value = config.pitch;
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      skipSilenceEnabledRx,
      loudnessEnhancerEnabledRx,
      loudnessEnhancerRx,
      equalizerEnabledRx,
      equalizerRx,
      presetRx,
      volumeRx,
      speedRx,
      pitchRx,
    );
  }
}
