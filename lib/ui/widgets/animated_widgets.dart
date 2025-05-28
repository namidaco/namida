import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:namida/ui/widgets/custom_widgets.dart';

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

class AnimatedBlur extends ImplicitlyAnimatedWidget {
  final double? blur;
  final bool enabled;
  final Widget child;

  const AnimatedBlur({
    super.key,
    this.blur,
    this.enabled = true,
    required this.child,
    super.curve,
    required super.duration,
    super.onEnd,
  });

  @override
  AnimatedWidgetBaseState<AnimatedBlur> createState() => __AnimatedBlurState();
}

class __AnimatedBlurState extends AnimatedWidgetBaseState<AnimatedBlur> {
  DoubleTween? _blurTween;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _blurTween = visitor(_blurTween, widget.blur, (value) => DoubleTween(begin: value as double)) as DoubleTween?;
  }

  @override
  Widget build(BuildContext context) {
    final blurValue = _blurTween?.evaluate(animation) ?? 0.0;
    return NamidaBlur(
      enabled: widget.enabled,
      blur: blurValue,
      child: widget.child,
    );
  }
}
