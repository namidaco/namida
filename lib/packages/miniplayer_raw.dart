// This is originally a part of [Tear Music](https://github.com/tearone/tearmusic), edited to fit Namida.
// Credits goes for the original author @55nknown

import 'package:flutter/material.dart';

import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/core/ui_scale.dart';

class MiniplayerRaw extends StatelessWidget {
  final Widget child;
  final bool enableHorizontalGestures;

  const MiniplayerRaw({
    super.key,
    required this.child,
    this.enableHorizontalGestures = true,
  });

  @override
  Widget build(BuildContext context) {
    return NamidaUiScaleBox(
      scale: MiniPlayerController.inst.panelScale,
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
