import 'package:flutter/material.dart';

import 'package:namida/core/extensions.dart';
import 'package:namida/core/ntheme.dart';

class NamidaDummyContainer extends StatelessWidget {
  final double? width;
  final double? height;
  final Widget? child;
  final bool shimmerEnabled;
  final double borderRadius;
  final bool isCircle;

  const NamidaDummyContainer({
    super.key,
    required this.width,
    required this.height,
    required this.child,
    required this.shimmerEnabled,
    this.borderRadius = 12.0,
    this.isCircle = false,
  });

  @override
  Widget build(BuildContext context) {
    return child != null && !shimmerEnabled
        ? child!
        : NContainer(
            width: width,
            height: height,
            clipBehavior: Clip.antiAlias,
            decoration: (colors) => BoxDecoration(
              color: colors.surface,
              borderRadius: isCircle ? null : BorderRadius.circular(borderRadius.multipliedRadius),
              shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
            ),
          );
  }
}
