import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:namida/controller/settings_controller.dart';

import 'package:namida/controller/waveform_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';

class WaveformComponent extends StatefulWidget {
  final int durationInMilliseconds;
  final Color? color;
  final Color? bgColor;
  final Curve curve;
  final double? boxMaxHeight;
  final double? boxMaxWidth;
  final double barsMinHeight;
  final double barsMaxHeight;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadiusGeometry? borderRadius;
  final Widget Function(NamidaWaveBars barsWidget)? widgetOnTop;
  final Color? barsColorOnTop;

  const WaveformComponent({
    Key? key,
    this.durationInMilliseconds = 600,
    this.color,
    this.bgColor,
    this.curve = Curves.easeInOutQuart,
    this.boxMaxHeight = 64.0,
    this.boxMaxWidth,
    this.barsMinHeight = 3.0,
    this.barsMaxHeight = 64.0,
    this.padding,
    this.margin,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.widgetOnTop,
    this.barsColorOnTop,
  }) : super(key: key);

  @override
  State<WaveformComponent> createState() => _WaveformComponentState();
}

class _WaveformComponentState extends State<WaveformComponent> {
  late Widget _stockWidget;
  Key? _lastKey;

  NamidaWaveBars barRows(List<double> waveList, double barWidth, Color? color) => NamidaWaveBars(
        waveList: waveList,
        color: color,
        borderRadius: 5.0,
        barWidth: barWidth,
        barMinHeight: widget.barsMinHeight,
        barMaxHeight: widget.barsMaxHeight,
        animationDurationMS: widget.durationInMilliseconds,
        animationCurve: widget.curve,
      );

  void _fillWidget() {
    _lastKey = widget.key;
    _stockWidget = Container(
      width: widget.boxMaxWidth,
      height: widget.boxMaxHeight,
      padding: widget.padding,
      margin: widget.margin,
      decoration: BoxDecoration(color: widget.bgColor, borderRadius: widget.borderRadius),
      child: Obx(
        () {
          final waveform = WaveformController.inst.currentWaveform;
          final clamping = waveform.isEqualTo(kDefaultWaveFormData) ? null : widget.barsMaxHeight;
          final downscaled = waveform.changeListSize(
            targetSize: settings.waveformTotalBars.value,
            multiplier: 0.9,
            clampToMax: clamping,
            enforceClampToMax: false,
          );
          final barWidth = Get.width / downscaled.length * 0.45;

          return Center(
            child: Stack(
              children: [
                barRows(downscaled, barWidth, widget.color),
                if (widget.widgetOnTop != null) widget.widgetOnTop!(barRows(downscaled, barWidth, widget.barsColorOnTop)),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.key == null || widget.key != _lastKey) {
      _fillWidget();
    }
    return _stockWidget;
  }
}

class NamidaWaveBars extends StatelessWidget {
  final List<double> waveList;
  final Color? color;
  final double borderRadius;
  final double barWidth;
  final double barMinHeight;
  final double barMaxHeight;
  final Curve animationCurve;
  final int animationDurationMS;

  const NamidaWaveBars({
    super.key,
    required this.waveList,
    required this.color,
    this.borderRadius = 5.0,
    required this.barWidth,
    required this.barMinHeight,
    required this.barMaxHeight,
    this.animationCurve = Curves.easeInOutQuart,
    required this.animationDurationMS,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      mainAxisSize: MainAxisSize.max,
      children: [
        ...waveList.map(
          (e) => AnimatedContainer(
            duration: Duration(milliseconds: animationDurationMS),
            height: e.clamp(barMinHeight, barMaxHeight),
            width: barWidth,
            curve: animationCurve,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius.multipliedRadius),
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
