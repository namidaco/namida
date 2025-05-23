// This is originally a part of [Tear Music](https://github.com/tearone/tearmusic), edited to fit Namida.
// Credits goes for the original author @55nknown

import 'package:flutter/material.dart';

import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';

typedef MiniplayerBuilderCallback = Widget Function(
  double maxOffset,
  bool bounceUp,
  bool bounceDown,
  double topInset,
  double bottomInset,
  double rightInset,
  Size screenSize,
  double sMaxOffset,
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
  double miniplayerbottomnavheight,
  double bottomOffset,
  double navBarHeight,
);

class MiniplayerRaw extends StatelessWidget {
  final MiniplayerBuilderCallback builder;
  final bool enableHorizontalGestures;

  const MiniplayerRaw({
    super.key,
    required this.builder,
    this.enableHorizontalGestures = true,
  });

  @override
  Widget build(BuildContext context) {
    double navBarHeight = MediaQuery.viewPaddingOf(context).bottom;

    final child = AnimatedBuilder(
        animation: MiniPlayerController.inst.animation,
        builder: (context, _) {
          final maxOffset = MiniPlayerController.inst.maxOffset;
          final bounceUp = MiniPlayerController.inst.bounceUp;
          final bounceDown = MiniPlayerController.inst.bounceDown;
          final topInset = MiniPlayerController.inst.topInset;
          final bottomInset = MiniPlayerController.inst.bottomInset;
          final rightInset = MiniPlayerController.inst.rightInset;
          final screenSize = MiniPlayerController.inst.screenSize;
          final sMaxOffset = MiniPlayerController.inst.sMaxOffset;

          final double p = MiniPlayerController.inst.animation.value;
          final double cp = p.clampDouble(0.0, 1.0);
          final double ip = 1 - p;
          final double icp = 1 - cp;

          final double rp = inverseAboveOne(p);
          final double rcp = rp.clampDouble(0, 1);

          final double qp = p.clampDouble(1.0, 3.0) - 1.0;
          final double qcp = qp.clampDouble(0.0, 1.0);

          final double bp = !bounceUp
              ? !bounceDown
                  ? rp
                  : 1 - (p - 1)
              : p;
          final double bcp = bp.clampDouble(0.0, 1.0);

          final miniplayerbottomnavheight = settings.enableBottomNavBar.value && !Dimensions.inst.miniplayerIsWideScreen ? 60.0 : 0.0;
          final double bottomOffset = (-miniplayerbottomnavheight * icp + p.clampDouble(-1, 0) * -200) - (bottomInset * icp);

          return builder(maxOffset - navBarHeight, bounceUp, bounceDown, topInset, bottomInset, rightInset, screenSize, sMaxOffset, p, cp, ip, icp, rp, rcp, qp, qcp, bp, bcp,
              miniplayerbottomnavheight, bottomOffset, navBarHeight);
        });
    return Listener(
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
