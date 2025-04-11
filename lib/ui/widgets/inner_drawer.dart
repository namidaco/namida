import 'package:flutter/material.dart';

import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/animated_widgets.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class NamidaInnerDrawer extends StatefulWidget {
  final Widget drawerChild;
  final Color? drawerBG;
  final Widget child;
  final Duration duration;
  final Curve curve;
  final double borderRadius;
  final double maxPercentage;
  final bool initiallySwipeable;

  const NamidaInnerDrawer({
    super.key,
    required this.drawerChild,
    this.drawerBG,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
    this.curve = Curves.fastEaseInToSlowEaseOut,
    this.borderRadius = 0,
    this.maxPercentage = 0.472,
    required this.initiallySwipeable,
  });

  @override
  State<NamidaInnerDrawer> createState() => NamidaInnerDrawerState();
}

class NamidaInnerDrawerState extends State<NamidaInnerDrawer> with SingleTickerProviderStateMixin {
  Animation<double> get animationView => controller.view;
  double get drawerPercentage => (controller.value / _upperBoundRx.value).clamp(0.0, 1.0);
  bool get isOpened => _isOpened;
  void toggle() => isOpened ? _closeDrawer() : _openDrawer();
  void open() => _openDrawer();
  void close() => _closeDrawer();
  void toggleCanSwipe(bool swipe) {
    if (_canSwipe == swipe) return;
    setState(() => _canSwipe = swipe);
  }

  late final AnimationController controller;
  final _upperBoundRx = Rx(0.0);

  @override
  void initState() {
    controller = AnimationController(
      vsync: this,
      upperBound: 2.0,
      duration: Duration.zero,
    );
    controller.addStatusListener(_statusListener);
    _upperBoundRx.value = widget.maxPercentage;
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    _upperBoundRx.close();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NamidaInnerDrawer oldWidget) {
    if (widget.maxPercentage != oldWidget.maxPercentage) {
      _upperBoundRx.value = widget.maxPercentage;
      if (_isOpened) controller.animateTo(_upperBoundRx.value, duration: Duration.zero); // just reanimate
    }
    super.didUpdateWidget(oldWidget);
  }

  late bool _canSwipe = widget.initiallySwipeable;
  bool _isOpened = false;
  double _distanceTraveled = 0;

  void _recalculateDistanceTraveled() {
    _distanceTraveled = controller.value * context.width;
  }

  void _statusListener(AnimationStatus status) {
    final isMoving = switch (status) {
      AnimationStatus.forward || AnimationStatus.reverse => true,
      AnimationStatus.completed || AnimationStatus.dismissed => false,
    };
    ArtworkWidget.isMovingDrawer = isMoving;
  }

  void _openDrawer() {
    _isOpened = true;
    controller.animateTo(_upperBoundRx.value, duration: widget.duration, curve: widget.curve);
  }

  void _closeDrawer() {
    _isOpened = false;
    controller.animateTo(controller.lowerBound, duration: widget.duration, curve: widget.curve);
  }

  @override
  Widget build(BuildContext context) {
    final drawerChild = RepaintBoundary(child: widget.drawerChild);
    final scaffoldBody = RepaintBoundary(child: widget.child);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        double animationValue = controller.value;
        final child = Stack(
          children: [
            scaffoldBody,
            Positioned.fill(
              child: TapDetector(
                onTap: animationValue == controller.lowerBound ? null : _closeDrawer,
                child: IgnorePointer(
                  ignoring: animationValue == controller.lowerBound,
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: (animationValue * 1.2).clamp(0.0, 1.0)),
                  ),
                ),
              ),
            ),
            // -- absort edge drags so that drawer can be swiped
            if (_canSwipe)
              ColoredBox(
                color: Colors.transparent,
                child: SizedBox(
                  height: context.height,
                  width: MediaQuery.paddingOf(context).left.withMinimum(20.0),
                ),
              ),
          ],
        );
        final finalBuilder = Stack(
          children: [
            // -- bg
            if (animationValue > 0) ...[
              Positioned.fill(
                child: AnimatedColor(
                  duration: const Duration(milliseconds: kThemeAnimationDurationMS),
                  color: context.theme.scaffoldBackgroundColor,
                ),
              ),
              Positioned.fill(
                child: Transform.translate(
                  offset: Offset(context.width * animationValue * 0.6, 0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: context.theme.colorScheme.primary.withAlpha(context.isDarkMode ? 5 : 25),
                          blurRadius: 58.0,
                          spreadRadius: 12.0,
                          offset: const Offset(-2.0, 0),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // -- drawer
              ObxO(
                rx: _upperBoundRx,
                builder: (context, upperBound) => Padding(
                  padding: EdgeInsets.only(right: context.width * (1 - upperBound)),
                  child: Transform.translate(
                    offset: Offset(-((upperBound - animationValue) * context.width * 0.5), 0),
                    child: drawerChild,
                  ),
                ),
              ),
              // -- drawer dim
              Positioned.fill(
                child: IgnorePointer(
                  child: ObxO(
                    rx: _upperBoundRx,
                    builder: (context, upperBound) => ColoredBox(
                      color: Colors.black.withValues(alpha: ((upperBound - animationValue) * 1.8).clamp(0.0, 1.0)),
                    ),
                  ),
                ),
              ),
            ],

            // -- child
            Transform.translate(
              offset: Offset(context.width * animationValue, 0),
              child: widget.borderRadius > 0
                  ? ClipPath(
                      clipper: DecorationClipper(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(widget.borderRadius * animationValue),
                        ),
                      ),
                      child: child,
                    )
                  : child,
            ),
          ],
        );
        return _canSwipe
            // -- touch absorber
            ? HorizontalDragDetector(
                behavior: HitTestBehavior.translucent,
                onDown: (details) {
                  controller.stop();
                  _recalculateDistanceTraveled();
                },
                onUpdate: (details) {
                  double toAdd = details.delta.dx;
                  if (controller.value > widget.maxPercentage) {
                    double toSubtract = (toAdd * (0.15 + controller.value));
                    toAdd -= toSubtract;
                  }

                  _distanceTraveled = (_distanceTraveled + toAdd).withMinimum(0);
                  controller.animateTo(_distanceTraveled / context.width);
                },
                onEnd: (details) {
                  final velocity = details.velocity.pixelsPerSecond.dx;
                  if (velocity > 300) {
                    _openDrawer();
                  } else if (velocity < -300) {
                    _closeDrawer();
                  } else if (animationValue > (_upperBoundRx.value * 0.4)) {
                    _openDrawer();
                  } else {
                    _closeDrawer();
                  }
                },
                child: finalBuilder,
              )
            : finalBuilder;
      },
    );
  }
}
