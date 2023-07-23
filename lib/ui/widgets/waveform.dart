import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/waveform_controller.dart';
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

  const WaveformComponent({
    Key? key,
    this.durationInMilliseconds = 600,
    this.color,
    this.bgColor,
    this.curve = Curves.easeInOutQuart,
    this.boxMaxHeight = 64.0,
    this.boxMaxWidth,
    this.barsMinHeight = 3.0,
    this.barsMaxHeight = 200.0,
    this.padding,
    this.margin,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  }) : super(key: key);

  @override
  State<WaveformComponent> createState() => _WaveformComponentState();
}

class _WaveformComponentState extends State<WaveformComponent> {
  late Widget _stockWidget;

  @override
  void initState() {
    super.initState();
    _fillWidget();
  }

  void _fillWidget() {
    _stockWidget = Container(
      key: widget.key,
      width: widget.boxMaxWidth,
      height: widget.boxMaxHeight,
      padding: widget.padding,
      margin: widget.margin,
      decoration: BoxDecoration(color: widget.bgColor, borderRadius: widget.borderRadius),
      child: Obx(
        () {
          final downscaledList = WaveformController.inst.changeListSize(WaveformController.inst.curentWaveform, SettingsController.inst.waveformTotalBars.value);
          final barWidth = Get.width / downscaledList.length * 0.45;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            mainAxisSize: MainAxisSize.max,
            children: [
              ...downscaledList.map(
                (e) => AnimatedContainer(
                  duration: Duration(milliseconds: widget.durationInMilliseconds),
                  height: (e * 100).clamp(widget.barsMinHeight, widget.barsMaxHeight),
                  width: barWidth,
                  curve: widget.curve,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5.0.multipliedRadius),
                    color: widget.color ?? CurrentColor.inst.color,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _stockWidget;
  }
}
