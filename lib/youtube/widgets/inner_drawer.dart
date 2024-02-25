// ignore_for_file: unused_element

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/ui/widgets/custom_widgets.dart';

class NamidaInnerDrawer extends StatefulWidget {
  final Widget drawerChild;
  final Color? drawerBG;
  final Widget child;
  final Duration duration;
  final Curve curve;
  final double borderRadius;
  final double maxPercentage;
  final bool swipeable;

  const NamidaInnerDrawer({
    super.key,
    required this.drawerChild,
    this.drawerBG,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
    this.curve = Curves.fastEaseInToSlowEaseOut,
    this.borderRadius = 0,
    this.maxPercentage = 0.472,
    this.swipeable = true,
  });

  @override
  State<NamidaInnerDrawer> createState() => NamidaInnerDrawerState();
}

class NamidaInnerDrawerState extends State<NamidaInnerDrawer> with SingleTickerProviderStateMixin {
  bool get isOpened => _isOpened;
  void toggle() => isOpened ? _closeDrawer() : _openDrawer();
  void open() => _openDrawer();
  void close() => _closeDrawer();
  void toggleCanSwipe(bool swipe) => setState(() => _canSwipe = swipe);

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

  late bool _canSwipe = widget.swipeable;
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
    return AnimatedBuilderMulti(
      animation: controller,
      children: [
        widget.drawerChild,
        widget.child,
      ],
      builder: (context, children) {
        final child = Stack(
          children: [
            children[1],
            Positioned.fill(
              child: TapDetector(
                onTap: controller.value != controller.upperBound ? null : _closeDrawer,
                child: IgnorePointer(
                  ignoring: controller.value != controller.upperBound,
                  child: ColoredBox(
                    color: Colors.black.withOpacity(controller.value),
                  ),
                ),
              ),
            ),
          ],
        );
        return Stack(
          children: [
            // -- bg
            if (controller.value > 0) ...[
              Positioned.fill(
                child: ColoredBox(
                  color: context.theme.scaffoldBackgroundColor,
                ),
              ),
              // -- drawer
              Padding(
                padding: EdgeInsets.only(right: context.width * (1 - controller.upperBound)),
                child: Transform.translate(
                  offset: Offset(-((controller.upperBound - controller.value) * context.width * 0.5), 0),
                  child: children[0],
                ),
              ),
              // -- drawer dim
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Colors.black.withOpacity(controller.upperBound - controller.value),
                  ),
                ),
              ),
            ],

            // -- child
            Transform.translate(
              offset: Offset(context.width * controller.value, 0),
              child: widget.borderRadius > 0
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(widget.borderRadius * controller.value),
                      child: child,
                    )
                  : child,
            ),
            // -- touch absorber
            if (_canSwipe)
              _HorizontalDragDetector(
                behavior: HitTestBehavior.translucent,
                onDown: (details) {
                  controller.stop();
                  _recalculateDistanceTraveled();
                },
                onUpdate: (details) {
                  _distanceTraveled += details.delta.dx;
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
              ),
          ],
        );
      },
    );
  }
}

class _HorizontalDragDetector extends StatelessWidget {
  final GestureDragDownCallback? onDown;
  final GestureDragUpdateCallback? onUpdate;
  final GestureDragEndCallback? onEnd;
  final void Function(HorizontalDragGestureRecognizer instance)? initializer;
  final Widget? child;
  final HitTestBehavior? behavior;

  const _HorizontalDragDetector({
    super.key,
    this.initializer,
    this.child,
    this.behavior,
    this.onDown,
    this.onUpdate,
    this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    final Map<Type, GestureRecognizerFactory> gestures = <Type, GestureRecognizerFactory>{};
    gestures[HorizontalDragGestureRecognizer] = GestureRecognizerFactoryWithHandlers<HorizontalDragGestureRecognizer>(
      () => HorizontalDragGestureRecognizer(debugOwner: this),
      initializer ??
          (HorizontalDragGestureRecognizer instance) {
            instance
              ..onDown = onDown
              ..onUpdate = onUpdate
              ..onEnd = onEnd
              ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
          },
    );

    return RawGestureDetector(
      behavior: behavior,
      gestures: gestures,
      child: child,
    );
  }
}
