import 'package:flutter/material.dart';

import 'package:namida/controller/vibrator_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';

abstract class SeekMagnet {
  static double threshold({bool isFullscreen = false}) => isDesktop || isFullscreen ? 0.01 : 0.05;

  static const uiThreshold = 0.25;

  static double uiIntensity(double percentage) => ((uiThreshold - percentage) / uiThreshold).clampDouble(0.0, 1.0);

  static bool _isWithin(double percentage, double threshold) {
    final within = percentage <= threshold;
    if (within) VibratorController.veryhigh();
    return within;
  }

  static double snapPercentage(double percentage, double threshold) => _isWithin(percentage, threshold) ? 0.0 : percentage;

  static int snapMilliseconds(int positionMS, int durationMS, double threshold) => durationMS > 0 && _isWithin(positionMS / durationMS, threshold) ? 0 : positionMS;
}

class SeekMagnetGlow extends StatelessWidget {
  final double width;
  final double height;
  final double intensity;
  final Color color;

  const SeekMagnetGlow({
    super.key,
    required this.width,
    required this.height,
    required this.intensity,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: [
            BoxShadow(
              blurRadius: intensity * 12.0,
              spreadRadius: intensity * 6.0,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}
