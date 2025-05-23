import 'package:flutter/material.dart';

import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

typedef PullToRefreshCallback = Future<void> Function();
const double _defaultMaxDistance = 128.0;

class PullToRefreshWidget extends StatelessWidget {
  final Widget child;
  final ScrollController controller;
  final PullToRefreshCallback onRefresh;
  final PullToRefreshMixin state;

  const PullToRefreshWidget({
    super.key,
    required this.child,
    required this.controller,
    required this.onRefresh,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerMove: (event) => state.onPointerMove(controller, event),
      onPointerUp: (_) => state.onRefresh(onRefresh),
      onPointerCancel: (_) => state.onVerticalDragFinish(),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          child,
          state.pullToRefreshWidget,
        ],
      ),
    );
  }
}

class PullToRefresh extends StatefulWidget {
  final Widget child;
  final ScrollController controller;
  final PullToRefreshCallback onRefresh;
  final double maxDistance;
  final bool Function()? enablePullToRefresh;

  const PullToRefresh({
    super.key,
    required this.child,
    required this.controller,
    required this.onRefresh,
    this.maxDistance = _defaultMaxDistance,
    this.enablePullToRefresh,
  });

  @override
  State<PullToRefresh> createState() => _PullToRefreshState();
}

class _PullToRefreshState extends State<PullToRefresh> with TickerProviderStateMixin, PullToRefreshMixin {
  @override
  double get maxDistance => widget.maxDistance;

  @override
  bool get enablePullToRefresh => widget.enablePullToRefresh == null ? true : widget.enablePullToRefresh!();

  @override
  Widget build(BuildContext context) {
    return PullToRefreshWidget(
      state: this,
      controller: widget.controller,
      onRefresh: widget.onRefresh,
      child: widget.child,
    );
  }
}

mixin PullToRefreshMixin<T extends StatefulWidget> on State<T> implements TickerProvider {
  static bool isPulling = false;

  bool enablePullToRefresh = true;

  final turnsTween = Tween<double>(begin: 0.0, end: 1.0);
  late final animation = AnimationController(vsync: this, duration: Duration.zero);

  AnimationController? get refreshAnimation => null;
  AnimationController? _animation2Backup;
  AnimationController get _animation2 => refreshAnimation ?? _animation2Backup!;

  final _minTrigger = 20;
  double get pullNormalizer => 100.0;

  final double maxDistance = _defaultMaxDistance;

  bool? _isDraggingVertically;
  double _distanceDragged = 0;
  bool _onVerticalDragUpdate(double dy) {
    _distanceDragged -= dy;
    if (_distanceDragged < -_minTrigger) {
      animation.animateTo(((_distanceDragged + _minTrigger).abs() / pullNormalizer).clampDouble(0, 1));
    } else if (animation.value > 0) {
      animation.animateTo(0);
    }
    return true;
  }

  void onPointerMove(ScrollController sc, PointerMoveEvent event) {
    if (!enablePullToRefresh) return;
    if (FadeDismissible.isDismissing) return;
    final dy = event.delta.dy;
    if (_isDraggingVertically == null) {
      final dxabs = event.delta.dx.abs();
      if (dxabs >= 0 && dy < 1) return;

      try {
        final canDragVertically = dy > 0 && (sc.hasClients && sc.positions.first.pixels <= 0);
        final horizontalAllowance = dxabs < 1.2;
        _isDraggingVertically = canDragVertically && horizontalAllowance;
        PullToRefreshMixin.isPulling = _isDraggingVertically ?? false;
      } catch (_) {}
    }
    if (_isDraggingVertically == true) _onVerticalDragUpdate(dy);
  }

  void onVerticalDragFinish() {
    PullToRefreshMixin.isPulling = false;

    _distanceDragged = 0;
    _isDraggingVertically = null;
    try {
      animation.animateTo(0, duration: const Duration(milliseconds: 100));
    } catch (_) {}
  }

  bool _isRefreshing = false;

  /// Normally will not continue if not fully swiped, [forceProceed] forces bypassing that,
  /// use if action not triggered by user but u want to show refresh indicator.
  Future<void> onRefresh(PullToRefreshCallback execute, {bool forceProceed = false}) async {
    if (!enablePullToRefresh) return;
    onVerticalDragFinish();
    if (_isRefreshing) return;
    if (animation.value != 1) {
      if (!forceProceed) return;
      animation.animateTo(1, duration: const Duration(milliseconds: 50));
    }

    _isRefreshing = true;
    try {
      _animation2.repeat();
      await execute();
      if (mounted) await _animation2.fling();
      if (mounted) _animation2.stop();
      _isRefreshing = false;
      onVerticalDragFinish();
    } catch (_) {
      if (mounted) await _animation2.fling();
      if (mounted) _animation2.stop();
      _isRefreshing = false;
      onVerticalDragFinish();
      rethrow;
    }
  }

  Widget get pullToRefreshWidget {
    final circleAvatar = RepaintBoundary(
      child: CircleAvatar(
        radius: 24.0,
        backgroundColor: context.theme.colorScheme.secondaryContainer,
        child: const Icon(
          Broken.refresh_2,
          color: AppThemes.fabForegroundColor,
        ),
      ),
    );
    final fadeAnimation = animation.drive(Animatable<double>.fromCallback((value) => _animation2.status == AnimationStatus.forward ? 1.0 : value));
    return Positioned(
      left: 0,
      right: 0,
      child: _StatusListenableBuilder(
        controller: _animation2,
        builder: (status2) {
          final isAnimating2 = (status2 == AnimationStatus.forward || status2 == AnimationStatus.reverse);
          return AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final p = animation.value;
              if (!isAnimating2 && p == 0) return const SizedBox();
              const multiplier = 4.5;
              const minus = multiplier / 3;
              return Padding(
                padding: EdgeInsets.only(top: 12.0 + p * maxDistance),
                child: Transform.rotate(
                  angle: (p * multiplier) - minus,
                  child: FadeTransition(
                    opacity: fadeAnimation,
                    child: RotationTransition(
                      key: const Key('rotatie'),
                      turns: turnsTween.animate(_animation2),
                      child: circleAvatar,
                    ),
                  ),
                ),
              );
            },
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

class _StatusListenableBuilder extends StatefulWidget {
  final AnimationController controller;
  final Widget Function(AnimationStatus status) builder;
  const _StatusListenableBuilder({required this.controller, required this.builder});

  @override
  State<_StatusListenableBuilder> createState() => _StatusListenableBuilderState();
}

class _StatusListenableBuilderState extends State<_StatusListenableBuilder> {
  late AnimationStatus _status = widget.controller.status;

  @override
  void initState() {
    widget.controller.addStatusListener(_statusListener);
    super.initState();
  }

  @override
  void dispose() {
    widget.controller.removeStatusListener(_statusListener);
    super.dispose();
  }

  void _statusListener(AnimationStatus status) {
    _status = status;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(_status);
  }
}
