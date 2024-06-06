// ignore_for_file: avoid_rx_value_getter_outside_obx
import 'package:flutter/material.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/namida_channel.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/waveform_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';

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
    value: 1.0,
    duration: Duration(milliseconds: widget.durationInMilliseconds),
    reverseDuration: Duration(milliseconds: widget.durationInMilliseconds),
  );

  int get _currentDurationInMSR {
    final totalDur = Player.inst.currentItemDuration.valueR;
    if (totalDur != null) return totalDur.inMilliseconds;
    final current = Player.inst.currentItem.valueR;
    if (current is Selectable) {
      return current.track.duration * 1000;
    }
    return 0;
  }

  @override
  void initState() {
    super.initState();

    // -- to refresh after coming resuming app
    NamidaChannel.inst.addOnResume('waveform', WaveformController.inst.calculateUIWaveform);
  }

  @override
  void dispose() {
    NamidaChannel.inst.removeOnResume('waveform');
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final view = View.of(context);
    final decorationBoxBehind = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5.0.multipliedRadius),
        color: context.theme.colorScheme.onSurface.withAlpha(40),
      ),
    );
    final decorationBoxFront = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5.0.multipliedRadius),
        color: context.theme.colorScheme.onSurface.withAlpha(110),
      ),
    );
    return ObxO(
        rx: WaveformController.inst.isWaveformUIEnabled,
        builder: (enabled) {
          _updateAnimation(enabled);
          final downscaled = WaveformController.inst.currentWaveformUI;
          final barWidth = view.physicalSize.shortestSide / view.devicePixelRatio / downscaled.length * 0.45;
          return Center(
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, _) => Stack(
                children: [
                  NamidaWaveBars(
                    heightPercentage: _animation.value,
                    decorationBox: decorationBoxBehind,
                    waveList: downscaled,
                    barWidth: barWidth,
                    barMinHeight: widget.barsMinHeight,
                    barMaxHeight: widget.barsMaxHeight,
                  ),
                  Obx(
                    () {
                      final seekValue = MiniPlayerController.inst.seekValue.valueR;
                      final position = seekValue != 0.0 ? seekValue : Player.inst.nowPlayingPositionR;
                      final durInMs = _currentDurationInMSR;
                      final percentage = (position / durInMs).clamp(0.0, durInMs.toDouble());
                      return ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (Rect bounds) {
                          return LinearGradient(
                            tileMode: TileMode.decal,
                            stops: [0.0, percentage, percentage + 0.005, 1.0],
                            colors: [
                              Color.alphaBlend(CurrentColor.inst.miniplayerColor.withAlpha(220), context.theme.colorScheme.onSurface),
                              Color.alphaBlend(CurrentColor.inst.miniplayerColor.withAlpha(180), context.theme.colorScheme.onSurface),
                              Colors.transparent,
                              Colors.transparent,
                            ],
                          ).createShader(bounds);
                        },
                        child: SizedBox(
                          width: namida.width - 16.0 / 2,
                          child: NamidaWaveBars(
                            heightPercentage: _animation.value,
                            decorationBox: decorationBoxFront,
                            waveList: downscaled,
                            barWidth: barWidth,
                            barMinHeight: widget.barsMinHeight,
                            barMaxHeight: widget.barsMaxHeight,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        });
  }
}

class NamidaWaveBars extends StatelessWidget {
  final List<double> waveList;
  final double barWidth;
  final double barMinHeight;
  final double barMaxHeight;
  final Widget decorationBox;
  final double heightPercentage;

  const NamidaWaveBars({
    super.key,
    required this.waveList,
    required this.barWidth,
    required this.barMinHeight,
    required this.barMaxHeight,
    required this.decorationBox,
    required this.heightPercentage,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      mainAxisSize: MainAxisSize.max,
      children: waveList
          .map(
            (e) => SizedBox(
              height: (heightPercentage * e).clamp(barMinHeight, barMaxHeight),
              width: barWidth,
              child: decorationBox,
            ),
          )
          .toList(),
    );
  }
}
