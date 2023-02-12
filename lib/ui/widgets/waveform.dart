import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:namida/controller/now_playing_color.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/waveform_controller.dart';
import 'package:namida/core/extensions.dart';

/* 
class WaveformComponent extends StatefulWidget {
  const WaveformComponent({Key? key, required this.duration, required this.color, required this.curve, required this.boxMaxHeight, required this.boxMaxWidth, this.width, this.height, this.waveDataList}) : super(key: key);

  final int duration;
  final Color color;
  final Curve curve;
  final double boxMaxHeight;
  final double boxMaxWidth;
  final double? width;
  final double? height;
  final List<double>? waveDataList;

  @override
  _WaveformComponentState createState() => _WaveformComponentState();
}

class _WaveformComponentState extends State<WaveformComponent> with SingleTickerProviderStateMixin {
  late Animation<double> animation;
  late AnimationController controller;
  late double width;
  late double height;
  late List<double> randomWaveDataList;

  @override
  void initState() {
    super.initState();
    width = widget.width ?? 4;
    height = widget.height ?? 15;
    animate();
    Random random = Random();
    randomWaveDataList = [];
    randomWaveDataList = List.generate(widget.boxMaxWidth ~/ (6.5), (index) => 5.0 + random.nextDouble() * (widget.boxMaxHeight - 10.0));
  }

  void animate() {
    controller = AnimationController(
      duration: Duration(milliseconds: widget.duration),
      vsync: this,
    );
    animation = Tween<double>(begin: 2, end: height).animate(
      CurvedAnimation(
        parent: controller,
        curve: widget.curve,
      ),
    );
    controller.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.boxMaxWidth,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.min,
        children: List<Widget>.generate(
          // widget.boxMaxWidth ~/ (6.5),
          widget.waveDataList!.length,
          (index) => SizedBox(
            width: width,
            child: Align(
              alignment: Alignment.center,
              child: AnimatedBuilder(
                animation: animation,
                builder: (context, _) => AnimatedContainer(
                  margin: EdgeInsets.only(right: 1.5),
                  duration: const Duration(milliseconds: 300),
                  height: widget.waveDataList![index] * 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5.0.multipliedRadius),
                    color: widget.color,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller.stop();
    controller.reset();
    controller.dispose();
    super.dispose();
  }
} */
class WaveformComponent extends StatelessWidget {
  final int durationInMilliseconds;
  final Color? color;
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
      decoration: BoxDecoration(color: Get.theme.colorScheme.background, borderRadius: borderRadius),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          mainAxisSize: MainAxisSize.max,
          children: downscaledList
              .asMap()
              .entries
              .map(
                (e) => AnimatedContainer(
                  // constraints: BoxConstraints(minWidth: 2),
                  duration: Duration(milliseconds: durationInMilliseconds),
                  height: (e.value < (4 / 100) ? (3.0 + 2 * e.value) : e.value * 100) * heightMultiplier,
                  width: Get.width / downscaledList.length - 2,
                  curve: curve,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5.0.multipliedRadius),
                    color: color ?? CurrentColor.inst.color.value,
                  ),
                  // child: Container(
                  //   // margin: EdgeInsets.symmetric(horizontal: WaveformController.inst.waveFormBarMargin),

                  // ),
                ),
              )
              .toList()),
    );
  }
}
