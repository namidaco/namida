import 'package:flutter/material.dart';

import 'package:namida/controller/wakelock_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

/// Used to retain state for cases like navigating after pip mode.
bool _wasExpanded = false;

/// this exists as a workaround for using pip widget height instead of device real height.
/// using split screen might make this buggy.
///
/// another possible workaround is to wait until activity gets resized, but we dont know exact numbers.
double _maxHeight = 0;

class NamidaYTMiniplayer extends StatefulWidget {
  final double minHeight, maxHeight, bottomMargin;
  final Widget Function(double height, double percentage, List<Widget> constantChildren) builder;
  final Decoration? decoration;
  final void Function(double percentage)? onHeightChange;
  final void Function(double dismissPercentage)? onDismissing;
  final Duration duration;
  final Curve curve;
  final AnimationController? animationController;
  final void Function()? onDismiss;
  final List<Widget> constantChildren;

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
    required this.constantChildren,
  });

  @override
  State<NamidaYTMiniplayer> createState() => NamidaYTMiniplayerState();
}

class NamidaYTMiniplayerState extends State<NamidaYTMiniplayer> with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    if (_maxHeight < widget.maxHeight) _maxHeight = widget.maxHeight;

    controller = widget.animationController ??
        AnimationController(
          vsync: this,
          duration: Duration.zero,
          lowerBound: 0,
          upperBound: 1,
          value: _wasExpanded ? 1.0 : widget.minHeight / _maxHeight,
        );

    if (widget.onHeightChange != null) {
      controller.addListener(_listenerHeightChange);
    }
    if (widget.onDismissing != null) {
      controller.addListener(_listenerDismissing);
    }

    _dragheight = _wasExpanded ? _maxHeight : widget.minHeight;

    WakelockController.inst.updateMiniplayerStatus(_wasExpanded);
  }

  void _listenerHeightChange() {
    widget.onHeightChange!(percentage);
  }

  void _listenerDismissing() {
    if (controllerHeight <= widget.minHeight) {
      widget.onDismissing!(dismissPercentage);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    controller.removeListener(_listenerHeightChange);
    controller.removeListener(_listenerDismissing);
    super.dispose();
  }

  bool get isExpanded => _dragheight >= widget.maxHeight - widget.minHeight;
  bool get _dismissible => widget.onDismiss != null;

  double _dragheight = 0;

  double get controllerHeight => controller.value * widget.maxHeight;
  double get percentage => (controllerHeight - widget.minHeight) / (widget.maxHeight - widget.minHeight);
  double get dismissPercentage => (controllerHeight / widget.minHeight).clamp(0.0, 1.0);

  void _updateHeight(double heightPre, {Duration? duration}) {
    final height = _dismissible ? heightPre : heightPre.withMinimum(widget.minHeight);
    controller.animateTo(
      height / widget.maxHeight,
      duration: duration,
      curve: widget.curve,
    );
    _dragheight = height;
  }

  void animateToState(bool toExpanded, {Duration? dur, bool dismiss = false}) {
    if (dismiss) {
      _updateHeight(0, duration: dur ?? widget.duration);
      WakelockController.inst.updateMiniplayerStatus(false);
      return;
    }

    _updateHeight(toExpanded ? widget.maxHeight : widget.minHeight, duration: dur ?? widget.duration);
    _wasExpanded = toExpanded;
    WakelockController.inst.updateMiniplayerStatus(toExpanded);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilderMulti(
      animation: controller,
      builder: (context, children) {
        final percentage = this.percentage;
        return Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: (widget.bottomMargin * (1.0 - percentage)).clamp(0, widget.bottomMargin)),
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
                    child: NamidaOpacity(
                      enabled: controllerHeight < widget.minHeight,
                      opacity: dismissPercentage,
                      child: Container(
                        height: controllerHeight,
                        decoration: widget.decoration,
                        child: widget.builder(controllerHeight, percentage, children),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      children: widget.constantChildren,
    );
  }
}
