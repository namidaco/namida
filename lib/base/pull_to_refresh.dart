import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/core/icon_fonts/broken_icons.dart';

mixin PullToRefreshMixin<T extends StatefulWidget> on State<T> implements TickerProvider {
  final turnsTween = Tween<double>(begin: 0.0, end: 1.0);
  late final animation = AnimationController(vsync: this, duration: Duration.zero);
  AnimationController get animation2;

  final _minTrigger = 20;

  num get pullNormalizer => 20;

  double _distanceDragged = 0;
  bool onVerticalDragUpdate(double dy) {
    _distanceDragged -= dy;
    if (_distanceDragged < -_minTrigger) {
      animation.animateTo(((_distanceDragged + _minTrigger).abs() / pullNormalizer).clamp(0, 1));
    } else if (animation.value > 0) {
      animation.animateTo(0);
    }
    return true;
  }

  void onVerticalDragFinish() {
    animation.animateTo(0, duration: const Duration(milliseconds: 100));
    _distanceDragged = 0;
  }

  Future<void> showRefreshingAnimation(Future<void> Function() whileExecuting) async {
    animation2.repeat();
    await whileExecuting();
    await animation2.fling();
    animation2.stop();
  }

  Widget get pullToRefreshWidget {
    return Positioned(
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: animation,
        child: CircleAvatar(
          radius: 24.0,
          backgroundColor: context.theme.colorScheme.secondaryContainer,
          child: const Icon(Broken.refresh_2),
        ),
        builder: (context, circleAvatar) {
          final p = animation.value;
          if (!animation2.isAnimating && p == 0) return const SizedBox();
          const multiplier = 4.5;
          const minus = multiplier / 3;
          return Padding(
            padding: EdgeInsets.only(top: 12.0 + p * 128.0),
            child: Transform.rotate(
              angle: (p * multiplier) - minus,
              child: AnimatedBuilder(
                animation: animation2,
                child: circleAvatar,
                builder: (context, circleAvatar) {
                  return Opacity(
                    opacity: animation2.status == AnimationStatus.forward ? 1.0 : p,
                    child: RotationTransition(
                      key: const Key('rotatie'),
                      turns: turnsTween.animate(animation2),
                      child: circleAvatar,
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }
}
