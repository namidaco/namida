import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:namida/core/extensions.dart';

class AnimatedDecoration extends ImplicitlyAnimatedWidget {
  final Widget? child;
  final Decoration? decoration;
  final Matrix4? transform;

  const AnimatedDecoration({
    super.key,
    required this.decoration,
    this.transform,
    this.child,
    super.curve,
    required super.duration,
    super.onEnd,
  });

  @override
  AnimatedWidgetBaseState<AnimatedDecoration> createState() => _AnimatedDecorationState();
}

class _AnimatedDecorationState extends AnimatedWidgetBaseState<AnimatedDecoration> {
  DecorationTween? _decoration;
  Matrix4Tween? _transform;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _decoration = visitor(_decoration, widget.decoration, (dynamic value) => DecorationTween(begin: value as Decoration)) as DecorationTween?;
    _transform = visitor(_transform, widget.transform, (dynamic value) => Matrix4Tween(begin: value as Matrix4)) as Matrix4Tween?;
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: _decoration?.evaluate(animation) ?? const BoxDecoration(),
      child: widget.child,
    );
  }
}

class AnimatedColoredBox extends ImplicitlyAnimatedWidget {
  final Widget? child;
  final Color? color;

  const AnimatedColoredBox({
    super.key,
    required this.color,
    this.child,
    super.curve,
    required super.duration,
    super.onEnd,
  });

  @override
  AnimatedWidgetBaseState<AnimatedColoredBox> createState() => _AnimatedColoredBoxState();
}

class _AnimatedColoredBoxState extends AnimatedWidgetBaseState<AnimatedColoredBox> {
  ColorTween? _color;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _color = visitor(_color, widget.color, (dynamic value) => ColorTween(begin: value as Color)) as ColorTween?;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _color?.evaluate(animation) ?? Colors.transparent,
      child: widget.child,
    );
  }
}

class AnimatedSizedBox extends ImplicitlyAnimatedWidget {
  final Widget? child;
  final Decoration? decoration;
  final double? width;
  final double? height;
  final bool animateWidth;
  final bool animateHeight;

  const AnimatedSizedBox({
    super.key,
    this.decoration,
    this.width,
    this.height,
    this.animateWidth = true,
    this.animateHeight = true,
    this.child,
    super.curve,
    required super.duration,
    super.onEnd,
  });

  @override
  AnimatedWidgetBaseState<AnimatedSizedBox> createState() => _AnimatedSizedBoxState();
}

class _AnimatedSizedBoxState extends AnimatedWidgetBaseState<AnimatedSizedBox> {
  DecorationTween? _decoration;
  DoubleTween? _width;
  DoubleTween? _height;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _decoration = visitor(_decoration, widget.decoration, (dynamic value) => DecorationTween(begin: value as Decoration)) as DecorationTween?;
    if (widget.animateWidth) _width = visitor(_width, widget.width, (dynamic value) => DoubleTween(begin: value as double)) as DoubleTween?;
    if (widget.animateHeight) _height = visitor(_height, widget.height, (dynamic value) => DoubleTween(begin: value as double)) as DoubleTween?;
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: _decoration?.evaluate(animation) ?? const BoxDecoration(),
      child: SizedBox(
        width: widget.animateWidth ? _width?.evaluate(animation) : widget.width,
        height: widget.animateHeight ? _height?.evaluate(animation) : widget.height,
        child: widget.child,
      ),
    );
  }
}

class DoubleTween extends Tween<double?> {
  DoubleTween({super.begin, super.end});

  @override
  double? lerp(double t) => ui.lerpDouble(begin, end, t);
}

class AnimatedColor extends ImplicitlyAnimatedWidget {
  final Widget? child;
  final Color? color;

  const AnimatedColor({
    super.key,
    this.color,
    this.child,
    super.curve,
    required super.duration,
    super.onEnd,
  });

  @override
  AnimatedWidgetBaseState<AnimatedColor> createState() => __AnimatedColorState();
}

class __AnimatedColorState extends AnimatedWidgetBaseState<AnimatedColor> {
  ColorTween? _colorTween;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _colorTween = visitor(_colorTween, widget.color, (dynamic value) => ColorTween(begin: value as Color)) as ColorTween?;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _colorTween?.evaluate(animation) ?? Colors.transparent,
      child: widget.child,
    );
  }
}

class AnimatedRotatingBorder extends StatefulWidget {
  final Widget child;
  final bool isLoading;
  final List<Color> colors;
  final double borderWidth;
  final double borderRadius;
  final Duration duration;

  const AnimatedRotatingBorder({
    super.key,
    required this.child,
    required this.isLoading,
    required this.colors,
    this.borderWidth = 2.0,
    this.borderRadius = 12.0,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<AnimatedRotatingBorder> createState() => _AnimatedRotatingBorderState();
}

class _AnimatedRotatingBorderState extends State<AnimatedRotatingBorder> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (widget.isLoading) _controller.repeat();
  }

  @override
  void didUpdateWidget(AnimatedRotatingBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isLoading) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => CustomPaint(
        painter: _AnimatedRotatingBorderPainter(
          progress: _controller.value,
          colors: widget.colors,
          borderWidth: widget.borderWidth,
          borderRadius: widget.borderRadius,
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _AnimatedRotatingBorderPainter extends CustomPainter {
  final double progress;
  final List<Color> colors;
  final double borderWidth;
  final double borderRadius;

  const _AnimatedRotatingBorderPainter({
    required this.progress,
    required this.colors,
    required this.borderWidth,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: 2 * math.pi,
        transform: GradientRotation(2 * math.pi * progress),
        colors: [
          colors.first.withOpacityExt(0.0),
          ...colors,
          colors.last.withOpacityExt(0.0),
        ],
      ).createShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  @override
  bool shouldRepaint(_AnimatedRotatingBorderPainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.colors != colors;
}
