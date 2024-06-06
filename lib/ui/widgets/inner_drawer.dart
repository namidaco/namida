import 'package:flutter/material.dart';

import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/animated_widgets.dart';
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
  bool get isOpened => _isOpened;
  void toggle() => isOpened ? _closeDrawer() : _openDrawer();
  void open() => _openDrawer();
  void close() => _closeDrawer();
  void toggleCanSwipe(bool swipe) {
    if (_canSwipe == swipe) return;
    setState(() => _canSwipe = swipe);
  }

  late final AnimationController controller;

  @override
  void initState() {
    controller = AnimationController(
      vsync: this,
      duration: Duration.zero,
      lowerBound: 0,
      upperBound: widget.maxPercentage,
    );
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  late bool _canSwipe = widget.initiallySwipeable;
  bool _isOpened = false;
  double _distanceTraveled = 0;

  void _recalculateDistanceTraveled() {
    _distanceTraveled = controller.value * context.width;
  }

  void _openDrawer() {
    _isOpened = true;
    controller.animateTo(controller.upperBound, duration: widget.duration, curve: widget.curve);
  }

  void _closeDrawer() {
    _isOpened = false;
    controller.animateTo(controller.lowerBound, duration: widget.duration, curve: widget.curve);
  }

  @override
  Widget build(BuildContext context) {
    final drawerChild = widget.drawerChild;
    final scaffoldBody = widget.child;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final child = Stack(
          children: [
            scaffoldBody,
            Positioned.fill(
              child: TapDetector(
                onTap: controller.value == controller.lowerBound ? null : _closeDrawer,
                child: IgnorePointer(
                  ignoring: controller.value == controller.lowerBound,
                  child: ColoredBox(
                    color: Colors.black.withOpacity(controller.value * 1.2),
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
            if (controller.value > 0) ...[
              Positioned.fill(
                child: AnimatedColor(
                  duration: const Duration(milliseconds: kThemeAnimationDurationMS),
                  color: context.theme.scaffoldBackgroundColor,
                ),
              ),
              Positioned.fill(
                child: Transform.translate(
                  offset: Offset(context.width * controller.value * 0.6, 0),
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
              Padding(
                padding: EdgeInsets.only(right: context.width * (1 - controller.upperBound)),
                child: Transform.translate(
                  offset: Offset(-((controller.upperBound - controller.value) * context.width * 0.5), 0),
                  child: drawerChild,
                ),
              ),
              // -- drawer dim
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Colors.black.withOpacity((controller.upperBound - controller.value) * 1.8),
                  ),
                ),
              ),
            ],

            // -- child
            Transform.translate(
              offset: Offset(context.width * controller.value, 0),
              child: widget.borderRadius > 0
                  ? ClipPath(
                      clipper: DecorationClipper(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(widget.borderRadius * controller.value),
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
                  _distanceTraveled = (_distanceTraveled + details.delta.dx).withMinimum(0);
                  controller.animateTo(_distanceTraveled / context.width);
                },
                onEnd: (details) {
                  final velocity = details.velocity.pixelsPerSecond.dx;
                  if (velocity > 300) {
                    _openDrawer();
                  } else if (velocity < -300) {
                    _closeDrawer();
                  } else if (controller.value > (controller.upperBound * 0.4)) {
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
