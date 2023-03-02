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
    this.padding,
    this.margin,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final downscaledList = WaveformController.inst.changeListSize(WaveformController.inst.curentWaveform.toList(), Get.width ~/ 3);

    return Container(
      width: boxMaxWidth ?? Get.width,
      height: boxMaxHeight ?? 64.0,
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(color: bgColor, borderRadius: borderRadius),
      child: Obx(
        () => Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          mainAxisSize: MainAxisSize.max,
          children: downscaledList
              .asMap()
              .entries
              .map(
                (e) => AnimatedContainer(
                  duration: Duration(milliseconds: durationInMilliseconds),
                  // height: (e.value < (4 / 100) ? (3.0 + 2 * e.value) : e.value * 100) * heightMultiplier,
                  height: (e.value * 100).clamp(3.0, 200.0),
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
      ),
    );
  }
}
