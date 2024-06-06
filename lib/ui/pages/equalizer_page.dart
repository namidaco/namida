import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:vibration/vibration.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/namida_channel.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/animated_widgets.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class EqualizerMainSlidersColumn extends StatelessWidget {
  final double verticalInBetweenPadding;
  final bool tapToUpdate;

  const EqualizerMainSlidersColumn({
    super.key,
    required this.verticalInBetweenPadding,
    required this.tapToUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final verticalPadding = SizedBox(height: verticalInBetweenPadding);
    final pitchKey = GlobalKey<_CuteSliderState>();
    final speedKey = GlobalKey<_CuteSliderState>();
    final volumeKey = GlobalKey<_CuteSliderState>();
    return Column(
      children: [
        verticalPadding,
        Obx(
          () => _SliderTextWidget(
            icon: Broken.airpods,
            title: lang.PITCH,
            value: settings.player.pitch.valueR,
            restoreDefault: () {
              Player.inst.setPlayerPitch(1.0);
              settings.player.save(pitch: 1.0);
              pitchKey.currentState?._updateVal(1.0);
            },
          ),
        ),
        _CuteSlider(
          key: pitchKey,
          initialValue: settings.player.pitch.value,
          onChanged: (value) {
            Player.inst.setPlayerPitch(value);
            settings.player.save(pitch: value);
          },
          tapToUpdate: tapToUpdate,
        ),
        verticalPadding,
        Obx(
          () => _SliderTextWidget(
            icon: Broken.forward,
            title: lang.SPEED,
            value: settings.player.speed.valueR,
            restoreDefault: () {
              Player.inst.setPlayerSpeed(1.0);
              settings.player.save(speed: 1.0);
              speedKey.currentState?._updateVal(1.0);
            },
            valToText: _SliderTextWidget.toXMultiplier,
          ),
        ),
        _CuteSlider(
          key: speedKey,
          initialValue: settings.player.speed.value,
          onChanged: (value) {
            Player.inst.setPlayerSpeed(value);
            settings.player.save(speed: value);
          },
          tapToUpdate: tapToUpdate,
        ),
        verticalPadding,
        Obx(
          () => _SliderTextWidget(
            icon: settings.player.volume.valueR > 0 ? Broken.volume_up : Broken.volume_slash,
            title: lang.VOLUME,
            value: settings.player.volume.valueR,
            restoreDefault: () {
              Player.inst.setPlayerVolume(1.0);
              settings.player.save(volume: 1.0);
              volumeKey.currentState?._updateVal(1.0);
            },
          ),
        ),
        _CuteSlider(
          key: volumeKey,
          max: 1.0,
          initialValue: settings.player.volume.value,
          onChanged: (value) {
            Player.inst.setPlayerVolume(value);
            settings.player.save(volume: value);
          },
          tapToUpdate: tapToUpdate,
        ),
      ],
    );
  }
}

class EqualizerPage extends StatefulWidget {
  const EqualizerPage({super.key});

  @override
  EqualizerPageState createState() => EqualizerPageState();
}

class EqualizerPageState extends State<EqualizerPage> {
  AndroidEqualizer get _equalizer => Player.inst.equalizer;
  AndroidLoudnessEnhancer get _loudnessEnhancer => Player.inst.loudnessEnhancer;

  final _equalizerPresets = <String>[];
  final _activePreset = ''.obs;
  final _activePresetCustom = false.obs;

  final _loudnessKey = GlobalKey<_CuteSliderState>();

  @override
  void initState() {
    _fillPresets();
    super.initState();
  }

  @override
  void dispose() {
    _activePreset.close();
    _activePresetCustom.close();
    super.dispose();
  }

  Future<void> _fillPresets() async {
    final p = await _equalizer.presets;
    setState(() => _equalizerPresets.addAll(p));
    if (_equalizerPresets.isNotEmpty) {
      final activePreset = await _equalizer.getCurrentPreset();
      if (activePreset != null) {
        try {
          _activePreset.value = _equalizerPresets[activePreset];
          _activePresetCustom.value = false;
        } catch (_) {
          _resetPreset(writeSettings: false);
        }
      } else {
        _resetPreset(writeSettings: false);
      }
    }
  }

  void _resetPreset({bool writeSettings = true}) {
    _activePresetCustom.value = true;
    _activePreset.value = '';
    _equalizer.setPreset(null);
    if (writeSettings && settings.equalizer.preset != null) {
      settings.equalizer.save(preset: null, resetPreset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    const verticalInBetweenPaddingH = 18.0;
    const verticalInBetweenPadding = SizedBox(height: verticalInBetweenPaddingH);
    return AnimatedTheme(
      duration: const Duration(milliseconds: kThemeAnimationDurationMS),
      data: context.theme,
      child: BackgroundWrapper(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                color: context.theme.cardColor,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    verticalInBetweenPadding,
                    Row(
                      children: [
                        const SizedBox(width: 12.0),
                        const Icon(Broken.sound),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: Text(
                            "${lang.CONFIGURE} (${lang.BETA})",
                            style: context.textTheme.displayMedium,
                          ),
                        ),
                        NamidaIconButton(
                          horizontalPadding: 0.0,
                          tooltip: lang.TAP_TO_SEEK,
                          icon: null,
                          iconSize: 24.0,
                          onPressed: () => settings.equalizer.save(uiTapToUpdate: !settings.equalizer.uiTapToUpdate.value),
                          child: ObxO(
                            rx: settings.equalizer.uiTapToUpdate,
                            builder: (val) => StackedIcon(
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
                    StreamBuilder<bool>(
                      stream: _equalizer.enabledStream,
                      builder: (context, snapshot) {
                        final enabled = snapshot.data ?? false;
                        return NamidaInkWell(
                          onTap: () {
                            settings.equalizer.save(equalizerEnabled: !_equalizer.enabled);
                            _equalizer.setEnabled(!_equalizer.enabled);
                          },
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: _SliderTextWidget(
                            icon: Broken.chart_3,
                            title: lang.EQUALIZER,
                            value: 0,
                            displayValue: false,
                            trailing: Row(
                              children: [
                                const SizedBox(width: 4.0),
                                NamidaIconButton(
                                  horizontalPadding: 0.0,
                                  tooltip: lang.OPEN_APP,
                                  icon: Broken.export_2,
                                  iconColor: context.defaultIconColor(),
                                  iconSize: 20.0,
                                  onPressed: () => NamidaChannel.inst.openSystemEqualizer(Player.inst.androidSessionId),
                                ),
                                const SizedBox(width: 16.0),
                                CustomSwitch(
                                  active: enabled,
                                  passedColor: null,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 6.0),
                    EqualizerControls(
                      equalizer: _equalizer,
                      onGainSetCallback: _resetPreset,
                      tapToUpdate: () => settings.equalizer.uiTapToUpdate.value,
                    ),
                    verticalInBetweenPadding,
                    if (_equalizerPresets.isNotEmpty) ...[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            const SizedBox(width: 8.0),
                            Obx(
                              () => NamidaInkWell(
                                animationDurationMS: 200,
                                borderRadius: 5.0,
                                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                bgColor: _activePresetCustom.valueR
                                    ? Color.alphaBlend(CurrentColor.inst.color.withOpacity(0.9), context.theme.scaffoldBackgroundColor)
                                    : context.theme.colorScheme.secondary.withOpacity(0.15),
                                onTap: _resetPreset,
                                child: Text(
                                  lang.CUSTOM,
                                  style: context.textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                    color: _activePresetCustom.valueR ? Colors.white.withOpacity(0.7) : null,
                                  ),
                                ),
                              ),
                            ),
                            ..._equalizerPresets.asMap().entries.map(
                                  (e) => Obx(
                                    () => NamidaInkWell(
                                      animationDurationMS: 200,
                                      borderRadius: 5.0,
                                      margin: const EdgeInsets.symmetric(horizontal: 4.0),
                                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                      bgColor: _activePreset.valueR == e.value
                                          ? Color.alphaBlend(CurrentColor.inst.color.withOpacity(0.9), context.theme.scaffoldBackgroundColor)
                                          : context.theme.colorScheme.secondary.withOpacity(0.15),
                                      onTap: () async {
                                        _activePreset.value = e.value;
                                        _activePresetCustom.value = false;
                                        settings.equalizer.save(preset: e.key);
                                        final newPreset = await _equalizer.setPreset(e.key);
                                        if (newPreset != e.key) snackyy(message: lang.ERROR, top: false, isError: true);
                                      },
                                      child: Text(
                                        e.value,
                                        style: context.textTheme.displaySmall?.copyWith(
                                          color: _activePreset.valueR == e.value ? Colors.white.withOpacity(0.7) : null,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            const SizedBox(width: 8.0),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12.0),
                    ],
                    StreamBuilder<bool>(
                      stream: _loudnessEnhancer.enabledStream,
                      builder: (context, snapshot) {
                        final enabled = snapshot.data ?? false;
                        return StreamBuilder<double>(
                          stream: _loudnessEnhancer.targetGainStream,
                          builder: (context, snapshot) {
                            final targetGain = snapshot.data ?? 0.0;
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                NamidaInkWell(
                                  onTap: () {
                                    settings.equalizer.save(loudnessEnhancerEnabled: !_loudnessEnhancer.enabled);
                                    _loudnessEnhancer.setEnabled(!_loudnessEnhancer.enabled);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                                    child: _SliderTextWidget(
                                      icon: targetGain > 0 ? Broken.volume_high : Broken.volume_low_1,
                                      title: lang.LOUDNESS_ENHANCER,
                                      value: targetGain,
                                      restoreDefault: () {
                                        settings.equalizer.save(loudnessEnhancer: 0.0);
                                        _loudnessEnhancer.setTargetGain(0.0);
                                        _loudnessKey.currentState?._updateVal(0.0);
                                      },
                                      trailing: CustomSwitch(
                                        active: enabled,
                                        passedColor: null,
                                      ),
                                    ),
                                  ),
                                ),
                                ObxO(
                                  rx: settings.equalizer.uiTapToUpdate,
                                  builder: (uiTapToUpdate) => _CuteSlider(
                                    key: _loudnessKey,
                                    initialValue: targetGain,
                                    min: -1,
                                    max: 1,
                                    onChanged: (newVal) {
                                      settings.equalizer.save(loudnessEnhancer: newVal);
                                      _loudnessEnhancer.setTargetGain(newVal);
                                    },
                                    tapToUpdate: uiTapToUpdate,
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    ObxO(
                      rx: settings.equalizer.uiTapToUpdate,
                      builder: (uiTapToUpdate) => EqualizerMainSlidersColumn(
                        verticalInBetweenPadding: verticalInBetweenPaddingH,
                        tapToUpdate: uiTapToUpdate,
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
  final double value;
  final VoidCallback? restoreDefault;
  final Widget? trailing;
  final bool displayValue;
  final String Function(double val) valToText;

  const _SliderTextWidget({
    required this.icon,
    required this.title,
    required this.value,
    this.restoreDefault,
    this.trailing,
    this.displayValue = true,
    this.valToText = toPercentage,
  });

  static String toPercentage(double val) => "${(val * 100).toStringAsFixed(0)}%";
  static String toXMultiplier(double val) => "${val.toStringAsFixed(2)}x";

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18.0),
      child: Row(
        children: [
          Icon(icon, color: context.defaultIconColor()),
          const SizedBox(width: 12.0),
          Text(
            title,
            style: context.textTheme.displayLarge,
          ),
          const SizedBox(width: 8.0),
          if (displayValue)
            Text(
              valToText(value),
              style: context.textTheme.displayMedium,
            ),
          const SizedBox(width: 8.0),
          const Spacer(),
          if (restoreDefault != null)
            NamidaIconButton(
              horizontalPadding: 8.0,
              tooltip: lang.RESTORE_DEFAULTS,
              icon: Broken.refresh,
              iconSize: 20.0,
              onPressed: restoreDefault,
            ),
          if (trailing != null) trailing!,
          const SizedBox(width: 8.0),
        ],
      ),
    );
  }
}

class _CuteSlider extends StatefulWidget {
  final double min;
  final double max;
  final double initialValue;
  final void Function(double newValue) onChanged;
  final bool tapToUpdate;

  const _CuteSlider({
    required super.key,
    this.min = 0.0,
    this.max = 2.0,
    required this.initialValue,
    required this.onChanged,
    required this.tapToUpdate,
  });

  @override
  State<_CuteSlider> createState() => _CuteSliderState();
}

class _CuteSliderState extends State<_CuteSlider> {
  late double _currentVal = widget.initialValue;

  void _updateVal(double newVal) {
    final finalVal = newVal.roundDecimals(4);
    if (finalVal != _currentVal) {
      setState(() {
        _currentVal = finalVal;
        widget.onChanged(finalVal);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const incremental = 0.01;
    final interaction = widget.tapToUpdate ? SliderInteraction.tapAndSlide : SliderInteraction.slideOnly;
    return Row(
      children: [
        const SizedBox(width: 16.0),
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
            value: _currentVal,
            onChanged: _updateVal,
            divisions: 200,
            label: "${(_currentVal * 100).toStringAsFixed(0)}%",
            allowedInteraction: interaction,
          ),
        ),
        _getArrowIcon(
          icon: Broken.arrow_right_3,
          callback: () {
            final newVal = (_currentVal + incremental).withMaximum(widget.max);
            _updateVal(newVal);
          },
        ),
        const SizedBox(width: 16.0),
      ],
    );
  }
}

Timer? _longPressTimer;

Widget _getArrowIcon({required IconData icon, required VoidCallback callback}) {
  return NamidaIconButton(
    horizontalPadding: 0.0,
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

class EqualizerControls extends StatelessWidget {
  final AndroidEqualizer equalizer;
  final void Function() onGainSetCallback;
  final bool Function() tapToUpdate;

  const EqualizerControls({
    super.key,
    required this.equalizer,
    required this.onGainSetCallback,
    required this.tapToUpdate,
  });

  void _onGainSet(AndroidEqualizerBand band, AndroidEqualizerParameters parameters, double newValue) {
    final newVal = newValue.clamp(parameters.minDecibels, parameters.maxDecibels).roundDecimals(4);
    settings.equalizer.save(equalizerValue: MapEntry(band.centerFrequency, newVal));
    band.setGain(newVal);
    onGainSetCallback();
  }

  void _onGainSetNoClamp(AndroidEqualizerBand band, AndroidEqualizerParameters parameters, double newValue) {
    final newVal = newValue.roundDecimals(4);
    settings.equalizer.save(equalizerValue: MapEntry(band.centerFrequency, newVal));
    band.setGain(newValue);
    onGainSetCallback();
  }

  @override
  Widget build(BuildContext context) {
    const incremental = 0.005;
    return StreamBuilder<AndroidEqualizerParameters>(
      stream: equalizer.parametersStream,
      builder: (context, snapshot) {
        final parameters = snapshot.data;
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
                            child: StreamBuilder<double>(
                              stream: band.gainStream,
                              builder: (context, snapshot) {
                                return Column(
                                  children: [
                                    _getArrowIcon(
                                      icon: Broken.arrow_up_3,
                                      callback: () => _onGainSet(band, parameters, band.gain + incremental),
                                    ),
                                    const SizedBox(height: 8.0),
                                    Expanded(
                                      child: VerticalSlider(
                                        min: parameters.minDecibels,
                                        max: parameters.maxDecibels,
                                        value: band.gain,
                                        onChanged: (value) => _onGainSetNoClamp(band, parameters, value),
                                        circleWidth: (context.width / allBands.length * 0.7).clamp(8.0, 24.0),
                                        tapToUpdate: tapToUpdate,
                                      ),
                                    ),
                                    const SizedBox(height: 8.0),
                                    _getArrowIcon(
                                      icon: Broken.arrow_down_2,
                                      callback: () => _onGainSet(band, parameters, band.gain - incremental),
                                    ),
                                    const SizedBox(height: 12.0),
                                    FittedBox(
                                      child: Text(
                                        "${band.gain > 0 ? '+' : ''}${(band.gain * 20).toStringAsFixed(2)}",
                                        style: context.textTheme.displayMedium,
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
                                color: context.theme.scaffoldBackgroundColor,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 4.0),
                                child: Text(
                                  band.centerFrequency >= 1000 ? '${(band.centerFrequency / 1000).round()} khz' : '${band.centerFrequency.round()} hz',
                                  style: context.textTheme.displaySmall,
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
    );
  }
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

  void _updateValue(BoxConstraints constraints, double total, double dy) {
    final inversePosition = constraints.maxHeight - dy;
    final heightPerc = inversePosition / constraints.maxHeight;
    final finalValue = (heightPerc * total + widget.min).clamp(widget.min, widget.max);
    widget.onChanged(finalValue);
  }

  @override
  Widget build(BuildContext context) {
    const circleHeight = 32.0;
    final circleWidth = widget.circleWidth;
    final total = widget.min.abs() + widget.max;
    return LayoutBuilder(builder: (context, constraints) {
      final finalVal = (widget.value - widget.min) / (widget.max - widget.min);
      final height = constraints.maxHeight * finalVal;
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (details) {
          if (widget.tapToUpdate()) _updateValue(constraints, total, details.localPosition.dy);
          _isPointerDown.value = true;
        },
        onTapUp: (details) => _isPointerDown.value = false,
        onVerticalDragEnd: (_) {
          _isPointerDown.value = false;
          if (widget.value.abs() <= 0.05) {
            // -- clamp if near center
            widget.onChanged(0);
            Vibration.vibrate(duration: 20, amplitude: 50);
          }
        },
        onVerticalDragCancel: () => _isPointerDown.value = false,
        onVerticalDragStart: (details) {
          _updateValue(constraints, total, details.localPosition.dy);
        },
        onVerticalDragUpdate: (details) {
          _updateValue(constraints, total, details.localPosition.dy);
        },
        child: SizedBox(
          width: circleWidth * 2,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Positioned(
                bottom: 0,
                top: 0,
                child: SizedBox(
                  width: 6.0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.theme.colorScheme.secondary.withOpacity(0.2),
                      borderRadius: const BorderRadius.all(
                        Radius.circular(12.0),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                child: AnimatedSizedBox(
                  duration: const Duration(milliseconds: 50),
                  height: height,
                  width: 8.0,
                  animateWidth: false,
                  decoration: BoxDecoration(
                    color: context.theme.colorScheme.primary.withOpacity(0.5),
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
                  () => AnimatedScale(
                    duration: const Duration(milliseconds: 200),
                    scale: _isPointerDown.valueR ? 1.2 : 1.0,
                    child: Container(
                      width: circleWidth,
                      height: circleHeight,
                      decoration: BoxDecoration(
                        color: context.theme.colorScheme.primary,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(12.0),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      );
    });
  }
}
