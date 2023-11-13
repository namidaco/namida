import 'dart:ui';

import 'package:flutter/material.dart';

/// Help to create drop shadow effect using [BackdropFilter]
class DropShadow extends StatelessWidget {
  /// Create DropShadow for any kind of widget with default values
  const DropShadow({
    required this.child,
    this.bottomChild,
    this.blurRadius = 10.0,
    this.borderRadius = 0.0,
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
  final double borderRadius;

  /// Position of the shadow
  final Offset offset;

  /// Size of the shadow
  final double spread;

  /// Apply Stock Shadow Effect
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    double left = 0.0;
    double right = 0.0;
    double top = 0.0;
    double bottom = 0.0;

    left = (offset.dx.abs() + (blurRadius * 2)) * spread;
    right = (offset.dx + (blurRadius * 2)) * spread;
    top = (offset.dy.abs() + (blurRadius * 2)) * spread;
    bottom = (offset.dy + (blurRadius * 2)) * spread;

    /// [ClipRRect] to isolate [BackDropFilter] from other widgets
    return ClipRRect(
      child: Container(
        decoration: BoxDecoration(boxShadow: boxShadow),

        /// Calculate Shadow's effect field
        padding: EdgeInsets.fromLTRB(left, top, right, bottom),
        child: Stack(
          children: [
            /// Arrange shadow position
            Transform.translate(
              offset: offset,

              /// Apply [BorderRadius] to the shadow
              child: ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius),
                child: bottomChild ?? child,
              ),
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

            /// [Widget] itself with given [BorderRadius]
            ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
