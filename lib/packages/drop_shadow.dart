import 'dart:ui';

import 'package:flutter/material.dart';

/// Help to create drop shadow effect using [BackdropFilter]
class DropShadow extends StatelessWidget {
  /// Create DropShadow for any kind of widget with default values
  const DropShadow({
    required this.child,
    this.bottomChild,
    this.blurRadius = 10.0,
    this.borderRadius,
    this.offset = const Offset(0, 8),
    this.spread = 1.0,
    this.boxShadow,
    super.key,
  });

  /// Your widget comes here :)
  final Widget child;

  /// Your bottom widget comes here :)
  final Widget? bottomChild;

  /// Blur radius of the shadow
  final double blurRadius;

  /// BorderRadius to the image and the shadow
  final BorderRadius? borderRadius;

  /// Position of the shadow
  final Offset offset;

  /// Size of the shadow
  final double spread;

  /// Apply Stock Shadow Effect
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    final left = (offset.dx.abs() + (blurRadius * 2)) * spread;
    final right = (offset.dx + (blurRadius * 2)) * spread;
    final top = (offset.dy.abs() + (blurRadius * 2)) * spread;
    final bottom = (offset.dy + (blurRadius * 2)) * spread;

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        boxShadow: boxShadow,
        borderRadius: borderRadius,
      ),

      /// Calculate Shadow's effect field
      padding: EdgeInsets.fromLTRB(left, top, right, bottom),
      child: Stack(
        children: [
          /// Arrange shadow position
          Transform.translate(
            offset: offset,
            child: bottomChild ?? child,
          ),

          /// Apply filter the whole [Stack] space
          Positioned.fill(
            /// Apply blur effect to the layer
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: blurRadius,
                sigmaY: blurRadius,
              ),

              /// Filter effect field
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),

          child,
        ],
      ),
    );
  }
}
