import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/waveform_controller.dart';
import 'package:namida/core/extensions.dart';

class WaveformComponent extends StatelessWidget {
  final int durationInMilliseconds;
  final Color? color;
  final Color? bgColor;
  final Curve curve;
  final double? boxMaxHeight;
  final double? boxMaxWidth;
  final double? width;
  final double heightMultiplier;
  final List<double>? waveDataList;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadiusGeometry? borderRadius;

  const WaveformComponent({
    Key? key,
    this.durationInMilliseconds = 600,
    this.color,
    this.bgColor,
    this.curve = Curves.easeInOutQuart,
    this.boxMaxHeight,
    this.boxMaxWidth,
    this.width,
    this.heightMultiplier = 1.0,
    this.waveDataList,
    this.padding,
    this.margin,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final downscaledList = waveDataList ?? WaveformController.inst.downscaleList(WaveformController.inst.curentWaveform.toList(), Get.width.toInt() ~/ 3.5);

    return Container(
      width: boxMaxWidth ?? Get.width,
      height: boxMaxHeight ?? 64.0,
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(color: bgColor, borderRadius: borderRadius),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.max,
        children: downscaledList
            .asMap()
            .entries
            .map(
              (e) => AnimatedContainer(
                duration: Duration(milliseconds: durationInMilliseconds),
                height: (e.value < (4 / 100) ? (3.0 + 2 * e.value) : e.value * 100) * heightMultiplier,
                width: Get.width / downscaledList.length - 2,
                curve: curve,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5.0.multipliedRadius),
                  color: color ?? CurrentColor.inst.color.value,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
