import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/core/extensions.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class NamidaBasicShimmer extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final Widget? child;
  final bool shimmerEnabled;
  final int fadeDurationMS;

  const NamidaBasicShimmer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12.0,
    required this.child,
    required this.shimmerEnabled,
    this.fadeDurationMS = 600,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerWrapper(
      fadeDurationMS: fadeDurationMS,
      shimmerEnabled: shimmerEnabled,
      transparent: false,
      child: child != null && !shimmerEnabled
          ? child!
          : Container(
              width: width,
              height: height,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: context.theme.colorScheme.background,
                borderRadius: BorderRadius.circular(borderRadius.multipliedRadius),
              ),
            ),
    );
  }
}
