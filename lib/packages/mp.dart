import 'package:flutter/material.dart';

import 'package:namida/core/extensions.dart';

/// Used to retain state for cases like navigating after pip mode.
bool _wasExpanded = false;

class NamidaYTMiniplayer extends StatefulWidget {
  final double minHeight, maxHeight, bottomMargin;
  final Widget Function(double height, double percentage) builder;
  final Decoration? decoration;
  final void Function(double percentage)? onHeightChange;
  final Duration duration;
  final Curve curve;
  final AnimationController? animationController;

  const NamidaYTMiniplayer({
    super.key,
    required this.minHeight,
    required this.maxHeight,
    required this.builder,
    this.decoration,
    this.onHeightChange,
    this.bottomMargin = 0.0,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.decelerate,
    this.animationController,
  });

  @override
  State<NamidaYTMiniplayer> createState() => NamidaYTMiniplayerState();
}

class NamidaYTMiniplayerState extends State<NamidaYTMiniplayer> with SingleTickerProviderStateMixin {
  late AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = widget.animationController ??
        AnimationController(
          vsync: this,
          duration: Duration.zero,
          lowerBound: widget.minHeight,
          upperBound: widget.maxHeight,
        );
    controller.addListener(() {
      widget.onHeightChange?.call(percentage);
    });
    animateToState(_wasExpanded, dur: Duration.zero);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  double _dragheight = 0;

  double get percentage => (controller.value - widget.minHeight) / (widget.maxHeight - widget.minHeight);

  void _updateHeight(double height, {Duration? duration}) {
    controller.animateTo(
      height,
      duration: duration,
      curve: widget.curve,
    );
    _dragheight = height;
  }

  void animateToState(bool toExpanded, {Duration? dur}) {
    _updateHeight(toExpanded ? widget.maxHeight : widget.minHeight, duration: dur ?? widget.duration);
    _wasExpanded = toExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_dragheight >= widget.maxHeight) {
          animateToState(false);
          return false;
        }
        return true;
      },
      child: AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            return Padding(
              padding: EdgeInsets.only(bottom: (widget.bottomMargin * (1.0 - percentage)).withMinimum(0)),
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      color: Colors.brown,
                      child: GestureDetector(
                        onTap: _dragheight == widget.minHeight
                            ? () {
                                animateToState(true);
                              }
                            : null,
                        onVerticalDragUpdate: (details) {
                          final dd = details.delta.dy;
                          _dragheight -= dd;
                          controller.animateTo(_dragheight);
                        },
                        onVerticalDragEnd: (details) {
                          final v = details.velocity.pixelsPerSecond.dy;

                          bool shouldSnapToMax = false;
                          if (v > 200) {
                            shouldSnapToMax = false;
                          } else if (v < -200) {
                            shouldSnapToMax = true;
                          } else {
                            final percentage = _dragheight / widget.maxHeight;
                            if (percentage > 0.4) {
                              shouldSnapToMax = true;
                            } else {
                              shouldSnapToMax = false;
                            }
                          }
                          animateToState(shouldSnapToMax);
                        },
                        child: Material(
                          type: MaterialType.transparency,
                          child: Container(
                            height: controller.value,
                            decoration: widget.decoration,
                            child: widget.builder(controller.value, percentage),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
    );
  }
}
