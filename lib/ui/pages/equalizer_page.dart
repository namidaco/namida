import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:basic_audio_handler/basic_audio_handler.dart';
import 'package:just_audio/just_audio.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/platform/namida_channel/namida_channel.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/vibrator_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/animated_widgets.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/playback_settings.dart';
import 'package:namida/youtube/class/youtube_id.dart';

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
    var initialIndex = settings.extra.audioConfigPageIndex ?? 0;
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
      onIndexChanged: (index) => settings.extra.save(audioConfigPageIndex: index),
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
  final Rx<bool> skipSilenceEnabledRx;
  final Rx<bool> loudnessEnhancerEnabledRx;
  final Rx<double> loudnessEnhancerRx;
  final Rx<bool> equalizerEnabledRx;
  final RxMap<double, double> equalizerRx;
  final Rxn<EqualizerPreset> presetRx;
  final Rx<double> volumeRx;
  final Rx<double> speedRx;
  final Rx<double> pitchRx;
  final Future<void> Function(double val) setVolume;
  final Future<void> Function(double val) setSpeed;
  final Future<void> Function(double val) setPitch;
  final Future<void> Function(bool enabled) setSkipSilenceEnabled;
  final Future<void> Function(AndroidLoudnessEnhancerExtended? loudnessEnhancer, bool enabled) setLoudnessEnhancerEnabled;
  final Future<void> Function(AndroidLoudnessEnhancerExtended? loudnessEnhancer, double val) setLoudnessEnhancer;
  final Future<void> Function(AndroidEqualizerExtended? equalizer, bool enabled) setEqualizerEnabled;
  final Future<void> Function(AndroidEqualizerExtended? equalizer, AndroidEqualizerBand band, MapEntry<double, double> entry) setEqualizer;
  final Future<void> Function(AndroidEqualizerExtended? equalizer, EqualizerPreset? preset) setPreset;

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
    required this.setPreset,
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
        settings.player.save(skipSilenceEnabled: enabled);

        if (canApplyGlobalConfig()) {
          await Player.inst.setSkipSilenceEnabled(enabled);
        }
      },
      setLoudnessEnhancerEnabled: (loudnessEnhancer, enabled) async {
        settings.equalizer.save(loudnessEnhancerEnabled: enabled);

        if (canApplyGlobalConfig()) {
          loudnessEnhancer?.setEnabledUser(enabled);
        }
      },
      setLoudnessEnhancer: (loudnessEnhancer, val) async {
        settings.equalizer.save(loudnessEnhancer: val);

        if (canApplyGlobalConfig()) {
          loudnessEnhancer?.setTargetGainUser(val);
        }
      },
      setEqualizerEnabled: (equalizer, enabled) async {
        settings.equalizer.save(equalizerEnabled: enabled);

        if (canApplyGlobalConfig()) {
          equalizer?.setEnabled(enabled).ignoreError();
        }
      },
      setEqualizer: (equalizer, band, entry) async {
        settings.equalizer.save(equalizerValue: entry);

        if (canApplyGlobalConfig()) {
          band.setGain(entry.value).ignoreError();
        }
      },
      setPreset: (equalizer, preset) async {
        settings.equalizer.save(preset: preset, resetPreset: true);

        if (canApplyGlobalConfig()) {
          final newPreset = await equalizer?.setPreset(preset, settings.equalizer.equalizer.value);
          settings.equalizer.equalizer.refresh();
          settings.equalizer.save();
          if (newPreset != preset) snackyy(message: lang.error, top: false, isError: true);
        }
      },
      setVolume: (val) async {
        settings.player.save(volume: val);
        if (canApplyGlobalConfig()) {
          Player.inst.setVolume(val);
        }
      },
      setSpeed: (val) async {
        settings.player.save(speed: val);

        if (canApplyGlobalConfig()) {
          Player.inst.setSpeed(val);
        }
      },
      setPitch: (val) async {
        settings.player.save(pitch: val);

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
    required final RxMap<double, double> equalizerRx,
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
      loudnessEnhancer?.setEnabledUser(enabled);
      if (saveToDb()) await Player.audioConfigs.updateProperty(item.key, (current) => current.copyWith(loudnessEnhancerEnabled: enabled));
    },
    setLoudnessEnhancer: (loudnessEnhancer, val) async {
      loudnessEnhancerRx.value = val;
      loudnessEnhancer?.setTargetGainUser(val);
      if (saveToDb()) await Player.audioConfigs.updateProperty(item.key, (current) => current.copyWith(loudnessEnhancer: val));
    },
    setEqualizerEnabled: (equalizer, enabled) async {
      equalizerEnabledRx.value = enabled;
      equalizer?.setEnabled(enabled);
      if (saveToDb()) await Player.audioConfigs.updateProperty(item.key, (current) => current.copyWith(equalizerEnabled: enabled));
    },
    setEqualizer: (equalizer, band, entry) async {
      equalizerRx[entry.key] = entry.value;
      band.setGain(entry.value).ignoreError();
      if (saveToDb()) {
        await Player.audioConfigs.updateProperty(item.key, (current) {
          final eqMap = current.equalizer;
          eqMap[entry.key] = entry.value;
          return current.copyWith(equalizer: eqMap);
        });
      }
    },
    setPreset: (equalizer, preset) async {
      presetRx.value = preset;
      final newPreset = await equalizer?.setPreset(preset, equalizerRx.value);
      equalizerRx.refresh();
      if (newPreset != preset) snackyy(message: lang.error, top: false, isError: true);
      if (saveToDb()) await Player.audioConfigs.updateProperty(item.key, (current) => current.copyWith(preset: preset, equalizer: equalizerRx.value));
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
  AndroidLoudnessEnhancerExtended? get _loudnessEnhancerExtended => Player.inst.loudnessEnhancerExtended;
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

    await _setEqualizerEnabled(config.equalizerEnabledRx.value);
    if (config.presetRx.value == null) {
      final parameters = await _equalizer?.parameters;
      if (parameters != null) {
        for (final band in parameters.bands) {
          final gain = config.equalizerRx.value[band.centerFrequency];
          if (gain != null) await _setEqualizerNoClamp(band, parameters, gain);
        }
      }
    }
    await _setPreset(config.presetRx.value);
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

  Future<void> _setPreset(EqualizerPreset? preset) async {
    if (widget.updateConfig.presetRx.value == preset) return;
    await widget.updateConfig.setPreset(_equalizer, preset);
  }

  Future<void> _setEqualizerEnabled(bool enabled) async {
    await widget.updateConfig.setEqualizerEnabled(_equalizer, enabled);
  }

  Future<void> _setEqualizer(AndroidEqualizerBand band, AndroidEqualizerParameters parameters, double newValue) async {
    final newVal = newValue.clampDouble(parameters.minDecibels, parameters.maxDecibels).roundDecimals(4);
    await widget.updateConfig.setEqualizer(_equalizer, band, MapEntry(band.centerFrequency, newVal));
    _resetPreset();
  }

  Future<void> _setEqualizerNoClamp(AndroidEqualizerBand band, AndroidEqualizerParameters parameters, double newValue) async {
    final newVal = newValue.roundDecimals(4);
    await widget.updateConfig.setEqualizer(_equalizer, band, MapEntry(band.centerFrequency, newVal));
    _resetPreset();
  }

  AndroidEqualizerExtended? get _equalizer => Player.inst.equalizerExtended;

  final _equalizerParameters = Rxn<AndroidEqualizerParameters>();
  StreamSubscription? _equalizerParamsSub;

  @override
  void initState() {
    _initEqualizerParameters();
    super.initState();
  }

  @override
  void dispose() {
    _equalizerParameters.close();
    _equalizerParamsSub?.cancel();
    super.dispose();
  }

  Future<void> _initEqualizerParameters() async {
    final params = await _equalizer?.parameters;
    if (!mounted) return;
    _equalizerParameters.value = params;

    _equalizerParamsSub = _equalizer?.parametersStream.listen((params) {
      _equalizerParameters.value = params;
    });
  }

  void _resetPreset() {
    _setPreset(null);
  }

  void _onGainSet(AndroidEqualizerBand band, AndroidEqualizerParameters parameters, double newValue) {
    _setEqualizer(band, parameters, newValue);
  }

  void _onGainSetNoClamp(AndroidEqualizerBand band, AndroidEqualizerParameters parameters, double newValue) {
    _setEqualizerNoClamp(band, parameters, newValue);
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
                settings.player.save(isPerTrackAudioConfigOverriden: !settings.player.isPerTrackAudioConfigOverriden.value);
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
                        size: 16.0,
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
                if (NamidaFeaturesVisibility.skipSilenceAvailable) ...[
                  ObxO(
                    rx: widget.updateConfig.skipSilenceEnabledRx,
                    builder: (context, skipSilence) => Padding(
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
                  ),
                  verticalPadding,
                ],

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
                            min: isSemitones ? -12.0 : 0.0,
                            max: isSemitones ? 12.0 : 2.0,
                            title: lang.pitch,
                            subtitle: isSemitones ? '(${lang.semitones})' : '(${lang.percentage})',
                            onTap: () {
                              settings.player.save(useSemitones: !settings.player.useSemitones.value);
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
                              divisions: 24, // 24 steps = 0.5 semitone steps from -12 to +12
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
                              valueListenable: widget.updateConfig.pitchRx,
                              onChanged: (value) {
                                widget.updateConfig.setPitch(value);
                              },
                              tapToUpdate: widget.tapToUpdate,
                            ),
                    ),
                  ),
                ),
                verticalPadding,
                Obx(
                  (context) => _SliderTextWidget(
                    icon: Broken.forward,
                    title: lang.speed,
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
                          settings.player.save(linkSpeedPitch: newLinkValue);
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
                  valueListenable: widget.updateConfig.speedRx,
                  onChanged: (value) async {
                    await widget.updateConfig.setSpeed(value);

                    if (settings.player.linkSpeedPitch.value) {
                      await widget.updateConfig.setPitch(value);
                    }
                  },
                  tapToUpdate: widget.tapToUpdate,
                ),
                verticalPadding,
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

                verticalPadding,
                if (NamidaFeaturesVisibility.loudnessEnhancerAvailable)
                  ObxO(
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
                                    min: AndroidLoudnessEnhancerExtended.kMinGain,
                                    max: AndroidLoudnessEnhancerExtended.kMaxGain,
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
                                  min: AndroidLoudnessEnhancerExtended.kMinGain,
                                  max: AndroidLoudnessEnhancerExtended.kMaxGain,
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

                if (NamidaFeaturesVisibility.equalizerAvailable && !widget.isInDialog) ...[
                  ObxO(
                    rx: widget.updateConfig.equalizerEnabledRx,
                    builder: (context, enabled) => NamidaInkWell(
                      onTap: () => _setEqualizerEnabled(!enabled),
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: _SliderTextWidget(
                        icon: Broken.chart_3,
                        title: lang.equalizer,
                        value: 0,
                        displayValue: false,
                        trailing: Row(
                          children: [
                            if (NamidaFeaturesVisibility.methodSetMonoAudio) ...[
                              IconButton(
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                tooltip: lang.setMonoAudio,
                                icon: Icon(
                                  Broken.airpods,
                                  size: 20.0,
                                  color: context.defaultIconColor(),
                                ),
                                iconSize: 20.0,
                                onPressed: () => NamidaChannel.inst.setMonoAudio(null),
                              ),
                              const SizedBox(width: 2.0),
                            ],

                            if (NamidaFeaturesVisibility.methodOpenSystemEqualizer && widget.isGlobal)
                              IconButton(
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                tooltip: lang.openApp,
                                icon: Icon(
                                  Broken.export_2,
                                  size: 20.0,
                                  color: context.defaultIconColor(),
                                ),
                                iconSize: 20.0,
                                onPressed: () => NamidaChannel.inst.openSystemEqualizer(
                                  Player.inst.androidSessionId,
                                  package: settings.customEQPackage.value,
                                ),
                              ),
                            const SizedBox(width: 8.0),
                            CustomSwitch(
                              active: enabled,
                              passedColor: null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6.0),
                  ObxO(
                    rx: _equalizerParameters,
                    builder: (context, parameters) {
                      if (parameters == null) return const SizedBox();
                      final allBands = parameters.bands;
                      return SizedBox(
                        width: context.width,
                        height: context.height * 0.5,
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          children: allBands
                              .map(
                                (band) => Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: ObxO(
                                            rx: widget.updateConfig.equalizerRx,
                                            builder: (context, eqMap) {
                                              final gain = eqMap[band.centerFrequency] ?? band.gain;
                                              return Column(
                                                children: [
                                                  _getArrowIcon(
                                                    icon: Broken.arrow_up_3,
                                                    callback: () => _onGainSet(band, parameters, gain + 0.01),
                                                  ),
                                                  const SizedBox(height: 4.0),
                                                  Expanded(
                                                    child: VerticalSlider(
                                                      min: parameters.minDecibels,
                                                      max: parameters.maxDecibels,
                                                      value: gain,
                                                      onChanged: (value) => _onGainSetNoClamp(band, parameters, value),
                                                      circleWidth: (context.width / allBands.length * 0.7).clampDouble(8.0, 24.0),
                                                      tapToUpdate: () => settings.equalizer.uiTapToUpdate.value,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4.0),
                                                  _getArrowIcon(
                                                    icon: Broken.arrow_down_2,
                                                    callback: () => _onGainSet(band, parameters, band.gain - 0.01),
                                                  ),
                                                  const SizedBox(height: 8.0),
                                                  FittedBox(
                                                    child: Text(
                                                      "${band.gain > 0 ? '+' : ''}${(band.gain).toStringAsFixed(2)}",
                                                      style: textTheme.displayMedium,
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 12.0),
                                        FittedBox(
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(4.0.multipliedRadius),
                                              color: theme.scaffoldBackgroundColor,
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 4.0),
                                              child: Text(
                                                band.centerFrequency >= 1000 ? '${(band.centerFrequency / 1000).round()} kHz' : '${band.centerFrequency.round()} hz',
                                                style: textTheme.displaySmall,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      );
                    },
                  ),
                  verticalPadding,
                  ObxO(
                    rx: settings.equalizer.eqPresets,
                    builder: (context, eqPresets) => eqPresets.isEmpty
                        ? const SizedBox()
                        : Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: SmoothSingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ObxO(
                                rx: widget.updateConfig.presetRx,
                                builder: (context, activePreset) {
                                  return Row(
                                    children: [
                                      const SizedBox(width: 8.0),
                                      NamidaInkWell(
                                        animationDurationMS: 200,
                                        borderRadius: 5.0,
                                        margin: const EdgeInsets.symmetric(horizontal: 4.0),
                                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                        bgColor: activePreset == null
                                            ? Color.alphaBlend(CurrentColor.inst.color.withOpacityExt(0.9), theme.scaffoldBackgroundColor)
                                            : theme.colorScheme.secondary.withOpacityExt(0.15),
                                        onTap: _resetPreset,
                                        child: Text(
                                          lang.custom,
                                          style: textTheme.displaySmall?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13.5,
                                            color: activePreset == null ? Colors.white.withOpacityExt(0.7) : null,
                                          ),
                                        ),
                                      ),
                                      ...eqPresets.map(
                                        (preset) => NamidaInkWell(
                                          animationDurationMS: 200,
                                          borderRadius: 5.0,
                                          margin: const EdgeInsets.symmetric(horizontal: 4.0),
                                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                          bgColor: activePreset == preset
                                              ? Color.alphaBlend(CurrentColor.inst.color.withOpacityExt(0.9), theme.scaffoldBackgroundColor)
                                              : theme.colorScheme.secondary.withOpacityExt(0.15),
                                          onTap: () => _setPreset(preset),
                                          child: Text(
                                            preset.name,
                                            style: textTheme.displaySmall?.copyWith(
                                              color: activePreset == preset ? Colors.white.withOpacityExt(0.7) : null,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8.0),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                  ),
                ],

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
              child: SmoothSingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
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
                          onPressed: () => settings.equalizer.save(uiTapToUpdate: !settings.equalizer.uiTapToUpdate.value),
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
                    verticalInBetweenPadding,
                  ],
                ),
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
            value: _currentVal.withMaximum(widget.max), // cuz it can be more
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
    RxMap<double, double> equalizerRx,
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
  final equalizerRx = RxMap<double, double>({});
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
