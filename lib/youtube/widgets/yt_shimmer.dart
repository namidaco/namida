import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/core/extensions.dart';

class NamidaDummyContainer extends StatelessWidget {
  final double? width;
  final double? height;
  final Widget? child;
  final bool shimmerEnabled;
  final double borderRadius;

  const NamidaDummyContainer({
    super.key,
    required this.width,
    required this.height,
    required this.child,
    required this.shimmerEnabled,
    this.borderRadius = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    return child != null && !shimmerEnabled
        ? child!
        : Container(
            width: width,
            height: height,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: context.theme.colorScheme.background,
              borderRadius: BorderRadius.circular(borderRadius.multipliedRadius),
            ),
          );
  }
}
