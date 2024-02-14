import 'dart:ui' as ui;

import 'package:flutter/material.dart';

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
