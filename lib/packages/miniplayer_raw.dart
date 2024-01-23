// This is originally a part of [Tear Music](https://github.com/tearone/tearmusic), edited to fit Namida.
// Credits goes for the original author @55nknown

import 'package:flutter/material.dart';

import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/extensions.dart';

typedef MiniplayerBuilderCallback = Widget Function(
  double maxOffset,
  bool bounceUp,
  bool bounceDown,
  double topInset,
  double bottomInset,
  Size screenSize,
  AnimationController sAnim,
  double sMaxOffset,
  double stParallax,
  double siParallax,
  double p,
  double cp,
  double ip,
  double icp,
  double rp,
  double rcp,
  double qp,
  double qcp,
  double bp,
  double bcp,
  BorderRadius borderRadius,
  double slowOpacity,
  double opacity,
  double fastOpacity,
  double miniplayerbottomnavheight,
  double bottomOffset,
  double navBarHeight,
  Widget? constantChild,
);

class MiniplayerRaw extends StatelessWidget {
  final MiniplayerBuilderCallback builder;
  final double topBorderRadius;
  final double bottomBorderRadius;
  final bool enableHorizontalGestures;
  final Widget? constantChild;

  const MiniplayerRaw({
    super.key,
    required this.builder,
    this.topBorderRadius = 20.0,
    this.bottomBorderRadius = 20.0,
    this.enableHorizontalGestures = true,
    this.constantChild,
  });

  @override
  Widget build(BuildContext context) {
    final navBarHeight = MediaQuery.paddingOf(context).bottom;
    final child = AnimatedBuilder(
      animation: MiniPlayerController.inst.animation,
      builder: (context, child) {
        final maxOffset = MiniPlayerController.inst.maxOffset;
        final bounceUp = MiniPlayerController.inst.bounceUp;
        final bounceDown = MiniPlayerController.inst.bounceDown;
        final topInset = MiniPlayerController.inst.topInset;
        final bottomInset = MiniPlayerController.inst.bottomInset;
        final screenSize = MiniPlayerController.inst.screenSize;
        final sAnim = MiniPlayerController.inst.sAnim;
        final sMaxOffset = MiniPlayerController.inst.sMaxOffset;
        final stParallax = MiniPlayerController.inst.stParallax;
        final siParallax = MiniPlayerController.inst.siParallax;

        final double p = MiniPlayerController.inst.animation.value;
        final double cp = p.clamp(0.0, 1.0);
        final double ip = 1 - p;
        final double icp = 1 - cp;

        final double rp = inverseAboveOne(p);
        final double rcp = rp.clamp(0, 1);

        final double qp = p.clamp(1.0, 3.0) - 1.0;
        final double qcp = qp.clamp(0.0, 1.0);

        final double bp = !bounceUp
            ? !bounceDown
                ? rp
                : 1 - (p - 1)
            : p;
        final double bcp = bp.clamp(0.0, 1.0);

        final BorderRadius borderRadius = BorderRadius.only(
          topLeft: Radius.circular(topBorderRadius.multipliedRadius + 6.0 * p),
          topRight: Radius.circular(topBorderRadius.multipliedRadius + 6.0 * p),
          bottomLeft: Radius.circular(bottomBorderRadius.multipliedRadius * (1 - p * 10 + 9).clamp(0, 1)),
          bottomRight: Radius.circular(bottomBorderRadius.multipliedRadius * (1 - p * 10 + 9).clamp(0, 1)),
        );
        final double slowOpacity = (bcp * 4 - 3).clamp(0, 1);
        final double opacity = (bcp * 5 - 4).clamp(0, 1);
        final double fastOpacity = (bcp * 10 - 9).clamp(0, 1);

        final miniplayerbottomnavheight = settings.enableBottomNavBar.value ? 60.0 : 0.0;
        final double bottomOffset = (-miniplayerbottomnavheight * icp + p.clamp(-1, 0) * -200) - (bottomInset * icp);

        return builder(
          maxOffset - navBarHeight,
          bounceUp,
          bounceDown,
          topInset,
          bottomInset,
          screenSize,
          sAnim,
          sMaxOffset,
          stParallax,
          siParallax,
          p,
          cp,
          ip,
          icp,
          rp,
          rcp,
          qp,
          qcp,
          bp,
          bcp,
          borderRadius,
          slowOpacity,
          opacity,
          fastOpacity,
          miniplayerbottomnavheight,
          bottomOffset,
          navBarHeight,
          child,
        );
      },
      child: constantChild,
    );
    return WillPopScope(
      onWillPop: MiniPlayerController.inst.onWillPop,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: MiniPlayerController.inst.onPointerDown,
        onPointerMove: MiniPlayerController.inst.onPointerMove,
        onPointerUp: MiniPlayerController.inst.onPointerUp,
        child: enableHorizontalGestures
            ? GestureDetector(
                behavior: HitTestBehavior.deferToChild,
                onTap: MiniPlayerController.inst.gestureDetectorOnTap,
                onVerticalDragUpdate: MiniPlayerController.inst.gestureDetectorOnVerticalDragUpdate,
                onVerticalDragEnd: (_) => MiniPlayerController.inst.verticalSnapping(),
                onHorizontalDragStart: MiniPlayerController.inst.gestureDetectorOnHorizontalDragStart,
                onHorizontalDragUpdate: MiniPlayerController.inst.gestureDetectorOnHorizontalDragUpdate,
                onHorizontalDragEnd: MiniPlayerController.inst.gestureDetectorOnHorizontalDragEnd,
                child: child,
              )
            : child,
      ),
    );
  }
}

double inverseAboveOne(double n) {
  if (n > 1) return (1 - (1 - n) * -1);
  return n;
}

double velpy({
  required final double a,
  required final double b,
  required final double c,
}) {
  return c * (b - a) + a;
}
