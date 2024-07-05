import 'package:flutter/material.dart';

import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/utils.dart';

typedef PullToRefreshCallback = Future<void> Function();
const double _defaultMaxDistance = 128.0;

class PullToRefresh extends StatefulWidget {
  final Widget child;
  final ScrollController controller;
  final PullToRefreshCallback onRefresh;
  final double maxDistance;

  const PullToRefresh({
    super.key,
    required this.child,
    required this.controller,
    required this.onRefresh,
    this.maxDistance = _defaultMaxDistance,
  });

  @override
  State<PullToRefresh> createState() => _PullToRefreshState();
}

class _PullToRefreshState extends State<PullToRefresh> with TickerProviderStateMixin, PullToRefreshMixin {
  @override
  double get maxDistance => widget.maxDistance;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerMove: (event) => onPointerMove(widget.controller, event),
      onPointerUp: (_) => onRefresh(widget.onRefresh),
      onPointerCancel: (_) => onVerticalDragFinish(),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          widget.child,
          pullToRefreshWidget,
        ],
      ),
    );
  }
}

mixin PullToRefreshMixin<T extends StatefulWidget> on State<T> implements TickerProvider {
  bool enablePullToRefresh = true;

  final turnsTween = Tween<double>(begin: 0.0, end: 1.0);
  late final animation = AnimationController(vsync: this, duration: Duration.zero);

  AnimationController? get refreshAnimation => null;
  AnimationController? _animation2Backup;
  AnimationController get _animation2 => refreshAnimation ?? _animation2Backup!;

  final _minTrigger = 20;
  num get pullNormalizer => 100;

  final double maxDistance = _defaultMaxDistance;

  bool? _isDraggingVertically;
  double _distanceDragged = 0;
  bool _onVerticalDragUpdate(double dy) {
    _distanceDragged -= dy;
    if (_distanceDragged < -_minTrigger) {
      animation.animateTo(((_distanceDragged + _minTrigger).abs() / pullNormalizer).clamp(0, 1));
    } else if (animation.value > 0) {
      animation.animateTo(0);
    }
    return true;
  }

  void onPointerMove(ScrollController sc, PointerMoveEvent event) {
    if (!enablePullToRefresh) return;
    final dy = event.delta.dy;
    if (_isDraggingVertically == null) {
      try {
        final canDragVertically = dy < 0 || (sc.hasClients && sc.positions.first.pixels <= 0);
        final horizontalAllowance = event.delta.dx.abs() < 0.1;
        _isDraggingVertically = canDragVertically && horizontalAllowance;
      } catch (_) {}
    }
    if (_isDraggingVertically == true) _onVerticalDragUpdate(dy);
  }

  void onVerticalDragFinish() {
    animation.animateTo(0, duration: const Duration(milliseconds: 100));
    _distanceDragged = 0;
    _isDraggingVertically = null;
  }

  bool _isRefreshing = false;
  Future<void> onRefresh(PullToRefreshCallback execute, {bool forceShow = false}) async {
    if (!enablePullToRefresh) return;
    onVerticalDragFinish();
    if (_isRefreshing) return;
    if (animation.value != 1) {
      if (!forceShow) return;
      animation.animateTo(1, duration: const Duration(milliseconds: 50));
    }

    _isRefreshing = true;
    _animation2.repeat();
    await execute();
    await _animation2.fling();
    _animation2.stop();
    _isRefreshing = false;
    onVerticalDragFinish();
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
          if (!_animation2.isAnimating && p == 0) return const SizedBox();
          const multiplier = 4.5;
          const minus = multiplier / 3;
          return Padding(
            padding: EdgeInsets.only(top: 12.0 + p * maxDistance),
            child: Transform.rotate(
              angle: (p * multiplier) - minus,
              child: AnimatedBuilder(
                animation: _animation2,
                child: circleAvatar,
                builder: (context, circleAvatar) {
                  return Opacity(
                    opacity: _animation2.status == AnimationStatus.forward ? 1.0 : p,
                    child: RotationTransition(
                      key: const Key('rotatie'),
                      turns: turnsTween.animate(_animation2),
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
  void initState() {
    super.initState();
    if (refreshAnimation == null) {
      _animation2Backup = AnimationController(
        duration: const Duration(milliseconds: 1200),
        vsync: this,
      );
    }
  }

  @override
  void dispose() {
    animation.dispose();
    _animation2Backup?.dispose();
    super.dispose();
  }
}
