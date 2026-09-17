// ignore_for_file: avoid_rx_value_getter_outside_obx
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/waveform_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class WaveformComponent extends StatefulWidget {
  final int durationInMilliseconds;
  final Curve curve;
  final double barsMinHeight;
  final double barsMaxHeight;

  const WaveformComponent({
    super.key,
    this.durationInMilliseconds = 600,
    this.curve = Curves.easeInOutQuart,
    this.barsMinHeight = 3.0,
    this.barsMaxHeight = 64.0,
  });

  @override
  State<WaveformComponent> createState() => WaveformComponentState();
}

class WaveformComponentState extends State<WaveformComponent> with SingleTickerProviderStateMixin {
  void _updateAnimation(bool enabled) async {
    if (enabled) {
      final alreadygoing = _animation.status == AnimationStatus.forward || _animation.status == AnimationStatus.completed;
      if (!alreadygoing) await _animation.animateTo(1.0, curve: widget.curve);
    } else {
      final alreadygoing = _animation.status == AnimationStatus.reverse || _animation.status == AnimationStatus.dismissed;
      if (!alreadygoing) await _animation.animateBack(0.0, curve: widget.curve);
    }
  }

  late final _animation = AnimationController(
    vsync: this,
    lowerBound: 0.0,
    upperBound: 1.0,
    value: WaveformController.inst.isWaveformUIEnabled.value ? 1.0 : 0.0,
    duration: Duration(milliseconds: widget.durationInMilliseconds),
    reverseDuration: Duration(milliseconds: widget.durationInMilliseconds),
  );

  int get _currentDurationInMSR {
    final totalDur = Player.inst.currentItemDuration.valueR;
    if (totalDur != null) return totalDur.inMilliseconds;
    final current = Player.inst.currentItem.valueR;
    if (current is Selectable) {
      return current.track.durationMS;
    }
    return 0;
  }

  void _onWaveformEnabledChanged() => _updateAnimation(WaveformController.inst.isWaveformUIEnabled.value);

  @override
  void initState() {
    super.initState();
    WaveformController.inst.isWaveformUIEnabled.addListener(_onWaveformEnabledChanged);
  }

  @override
  void dispose() {
    WaveformController.inst.isWaveformUIEnabled.removeListener(_onWaveformEnabledChanged);
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final barRadius = Radius.circular(5.0.multipliedRadius);
    const frontAlpha = 110;
    final barColorBehind = theme.colorScheme.onSurface.withAlpha(40);
    final barColorFront = theme.colorScheme.onSurface.withAlpha(frontAlpha);
    final playedColors = [
      Color.alphaBlend(CurrentColor.inst.miniplayerColor.withAlpha(180), theme.colorScheme.onSurface).withAlpha(frontAlpha),
      Color.alphaBlend(CurrentColor.inst.miniplayerColor.withAlpha(140), theme.colorScheme.onSurface).withAlpha(frontAlpha),
    ];
    return LayoutWidthProvider(
      builder: (context, maxWidth) {
        return ObxO(
          rx: WaveformController.inst.currentWaveformUIRx,
          builder: (context, downscaled) {
            final barWidth = maxWidth / downscaled.length * 0.54;
            return Center(
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, _) {
                  final barBehind = NamidaWaveBars(
                    heightPercentage: _animation.value,
                    barColor: barColorBehind,
                    barRadius: barRadius,
                    waveList: downscaled,
                    barWidth: barWidth,
                    barMinHeight: widget.barsMinHeight,
                    barMaxHeight: widget.barsMaxHeight,
                  );
                  return Stack(
                    children: [
                      barBehind,
                      ObxO(
                        rx: MiniPlayerController.inst.seekValue,
                        builder: (context, seekNull) => ObxO(
                          rx: Player.inst.nowPlayingPosition,
                          builder: (context, nowPlayingPosition) {
                            final position = seekNull ?? nowPlayingPosition;
                            final durInMs = _currentDurationInMSR;
                            final percentage = durInMs <= 0 ? 0.0 : (position / durInMs).clampDouble(0.0, 1.0);
                            return NamidaWaveBars(
                              heightPercentage: _animation.value,
                              barColor: barColorFront,
                              barRadius: barRadius,
                              waveList: downscaled,
                              barWidth: barWidth,
                              barMinHeight: widget.barsMinHeight,
                              barMaxHeight: widget.barsMaxHeight,
                              playedPercentage: percentage,
                              playedColors: playedColors,
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class NamidaWaveBars extends StatelessWidget {
  final List<double> waveList;
  final double barWidth;
  final double barMinHeight;
  final double barMaxHeight;
  final Color barColor;
  final Radius barRadius;
  final double heightPercentage;
  final double? playedPercentage;
  final List<Color>? playedColors;

  const NamidaWaveBars({
    super.key,
    required this.waveList,
    required this.barWidth,
    required this.barMinHeight,
    required this.barMaxHeight,
    required this.barColor,
    required this.barRadius,
    required this.heightPercentage,
    this.playedPercentage,
    this.playedColors,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      isComplex: false,
      willChange: true,
      painter: _NamidaWaveBarsPainter(
        waveList: waveList,
        barWidth: barWidth,
        barMinHeight: barMinHeight,
        barMaxHeight: barMaxHeight,
        barColor: barColor,
        barRadius: barRadius,
        heightPercentage: heightPercentage,
        playedPercentage: playedPercentage,
        playedColors: playedColors,
      ),
    );
  }
}

/// painted instead of a `Row` of `SizedBox`es: the bars are rebuilt on every animation
/// frame, and building/laying out ~2x80 widgets per frame costs far more than one repaint.
///
/// by claude
class _NamidaWaveBarsPainter extends CustomPainter {
  final List<double> waveList;
  final double barWidth;
  final double barMinHeight;
  final double barMaxHeight;
  final Color barColor;
  final Radius barRadius;
  final double heightPercentage;
  final double? playedPercentage;
  final List<Color>? playedColors;

  const _NamidaWaveBarsPainter({
    required this.waveList,
    required this.barWidth,
    required this.barMinHeight,
    required this.barMaxHeight,
    required this.barColor,
    required this.barRadius,
    required this.heightPercentage,
    required this.playedPercentage,
    required this.playedColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final count = waveList.length;
    if (count == 0 || barWidth <= 0 || !barWidth.isFinite) return;

    // -- matches `MainAxisAlignment.spaceEvenly`: equal gaps before, between & after the bars.
    final gap = (size.width - barWidth * count) / (count + 1);
    final centerY = size.height / 2;
    final paint = Paint()
      ..color = barColor
      ..isAntiAlias = true;

    final playedPercentage = this.playedPercentage;
    double maxLeft = size.width;
    if (playedPercentage != null) {
      final playedWidth = size.width * playedPercentage;
      if (playedWidth <= 0) return;
      maxLeft = playedWidth;
      canvas.clipRect(Rect.fromLTWH(0, 0, playedWidth, size.height));
      final playedColors = this.playedColors;
      if (playedColors != null && playedColors.length >= 2) {
        // -- the paint color alpha modulates the shader, the gradient colors already carry the alpha.
        paint.color = const Color(0xFFFFFFFF);
        paint.shader = ui.Gradient.linear(Offset.zero, Offset(playedWidth, 0), playedColors);
      }
    }

    double left = gap;
    for (int i = 0; i < count; i++) {
      if (left > maxLeft) break;
      final barHeight = (heightPercentage * waveList[i]).clampDouble(barMinHeight, barMaxHeight);
      final halfHeight = barHeight / 2;
      canvas.drawRRect(
        RRect.fromLTRBR(left, centerY - halfHeight, left + barWidth, centerY + halfHeight, barRadius),
        paint,
      );
      left += barWidth + gap;
    }
  }

  @override
  bool shouldRepaint(_NamidaWaveBarsPainter oldDelegate) {
    return heightPercentage != oldDelegate.heightPercentage ||
        barColor != oldDelegate.barColor ||
        barWidth != oldDelegate.barWidth ||
        barMinHeight != oldDelegate.barMinHeight ||
        barMaxHeight != oldDelegate.barMaxHeight ||
        barRadius != oldDelegate.barRadius ||
        playedPercentage != oldDelegate.playedPercentage ||
        !identical(playedColors, oldDelegate.playedColors) ||
        !identical(waveList, oldDelegate.waveList);
  }
}
