import 'package:flutter/material.dart';

import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';

/// Used to retain state for cases like navigating after pip mode.
bool _wasExpanded = false;

class NamidaYTMiniplayer extends StatefulWidget {
  final double minHeight, maxHeight, bottomMargin;
  final Widget Function(double height, double percentage) builder;
  final Decoration? decoration;
  final void Function(double percentage)? onHeightChange;
  final void Function(double dismissPercentage)? onDismissing;
  final Duration duration;
  final Curve curve;
  final AnimationController? animationController;
  final void Function()? onDismiss;

  const NamidaYTMiniplayer({
    super.key,
    required this.minHeight,
    required this.maxHeight,
    required this.builder,
    this.decoration,
    this.onHeightChange,
    this.onDismissing,
    this.bottomMargin = 0.0,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.decelerate,
    this.animationController,
    this.onDismiss,
  });

  @override
  State<NamidaYTMiniplayer> createState() => NamidaYTMiniplayerState();
}

class NamidaYTMiniplayerState extends State<NamidaYTMiniplayer> with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = widget.animationController ??
        AnimationController(
          vsync: this,
          duration: Duration.zero,
          lowerBound: 0,
          upperBound: widget.maxHeight,
        );
    controller.addListener(() {
      widget.onHeightChange?.call(percentage);
      if (widget.onDismissing != null) {
        if (controller.value <= widget.minHeight) {
          widget.onDismissing!(dismissPercentage);
        }
      }
    });
    animateToState(_wasExpanded, dur: Duration.zero);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  bool get isExpanded => _dragheight >= widget.maxHeight - widget.minHeight;
  bool get _dismissible => widget.onDismiss != null;

  double _dragheight = 0;

  double get percentage => (controller.value - widget.minHeight) / (widget.maxHeight - widget.minHeight);
  double get dismissPercentage => (controller.value / widget.minHeight).clamp(0.0, 1.0);

  void _updateHeight(double heightPre, {Duration? duration}) {
    final height = _dismissible ? heightPre : heightPre.withMinimum(widget.minHeight);
    controller.animateTo(
      height,
      duration: duration,
      curve: widget.curve,
    );
    _dragheight = height;
  }

  void animateToState(bool toExpanded, {Duration? dur, bool dismiss = false}) {
    if (dismiss) {
      _updateHeight(0, duration: dur ?? widget.duration);
      _toggleWakelockOff();
      return;
    }

    _updateHeight(toExpanded ? widget.maxHeight : widget.minHeight, duration: dur ?? widget.duration);
    _wasExpanded = toExpanded;
    if (toExpanded) {
      _toggleWakelockOn();
    } else {
      _toggleWakelockOff();
    }
  }

  void _toggleWakelockOn() {
    settings.wakelockMode.value.toggleOn(VideoController.vcontroller.isInitialized);
  }

  void _toggleWakelockOff() {
    settings.wakelockMode.value.toggleOff();
  }

  Widget _opacityWrapper({bool enabled = true, required double opacity, required Widget child}) {
    return enabled
        ? Opacity(
            opacity: opacity,
            child: child,
          )
        : child;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final percentage = this.percentage;
          return Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: (widget.bottomMargin * (1.0 - percentage)).withMinimum(0)),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: GestureDetector(
                    onTap: _dragheight == widget.minHeight
                        ? () {
                            animateToState(true);
                          }
                        : null,
                    onVerticalDragUpdate: (details) {
                      final dd = details.delta.dy;
                      _dragheight -= dd;
                      _updateHeight(_dragheight, duration: Duration.zero);
                    },
                    onVerticalDragCancel: () => animateToState(_wasExpanded),
                    onVerticalDragEnd: (details) {
                      final v = details.velocity.pixelsPerSecond.dy;

                      if (widget.onDismiss != null && ((v > 200 && _dragheight <= widget.minHeight * 0.9) || _dragheight <= widget.minHeight * 0.65)) {
                        animateToState(false, dismiss: true);
                        widget.onDismiss!();
                        return;
                      }

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
                      clipBehavior: Clip.hardEdge,
                      type: MaterialType.transparency,
                      child: _opacityWrapper(
                        enabled: controller.value < widget.minHeight,
                        opacity: dismissPercentage,
                        child: Container(
                          height: controller.value,
                          decoration: widget.decoration,
                          child: widget.builder(controller.value, percentage),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        });
  }
}
