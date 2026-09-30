import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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

// by claude
/// Rebuilds only when [condition] flips for [listenable]'s value, instead of on every change.
class ValueConditionBuilder<T> extends StatefulWidget {
  final ValueListenable<T> listenable;
  final bool Function(T value) condition;
  final Widget Function(BuildContext context, bool isMet, Widget? child) builder;
  final Widget? child;

  const ValueConditionBuilder({
    super.key,
    required this.listenable,
    required this.condition,
    required this.builder,
    this.child,
  });

  @override
  State<ValueConditionBuilder<T>> createState() => _ValueConditionBuilderState<T>();
}

class _ValueConditionBuilderState<T> extends State<ValueConditionBuilder<T>> {
  late bool _isMet = widget.condition(widget.listenable.value);

  @override
  void initState() {
    super.initState();
    widget.listenable.addListener(_onValueChanged);
  }

  @override
  void didUpdateWidget(covariant ValueConditionBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listenable != widget.listenable) {
      oldWidget.listenable.removeListener(_onValueChanged);
      widget.listenable.addListener(_onValueChanged);
    }
    _isMet = widget.condition(widget.listenable.value);
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_onValueChanged);
    super.dispose();
  }

  void _onValueChanged() {
    final isMet = widget.condition(widget.listenable.value);
    if (isMet == _isMet) return;
    setState(() => _isMet = isMet);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _isMet, widget.child);
}

// by claude
/// Keeps a render object synced with a [ValueListenable] while attached, so a
/// per frame value never has to rebuild the widget that owns it.
mixin _ListenableSync<T> on RenderObject {
  late ValueListenable<T> _listenable;

  void applyValue(T value);

  /// re-reads even the same listenable, what a derived one reads may have changed with the rebuild.
  set listenable(ValueListenable<T> value) {
    if (value != _listenable) {
      if (attached) {
        _listenable.removeListener(_sync);
        value.addListener(_sync);
      }
      _listenable = value;
    }
    _sync();
  }

  void _sync() => applyValue(_listenable.value);

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _listenable.addListener(_sync);
    _sync();
  }

  @override
  void detach() {
    _listenable.removeListener(_sync);
    super.detach();
  }
}

/// [Transform.translate] following [offset], painted at an offset instead of through a transform layer.
class ListenableTranslate extends SingleChildRenderObjectWidget {
  final ValueListenable<Offset> offset;
  final bool transformHitTests;

  const ListenableTranslate({
    super.key,
    required this.offset,
    this.transformHitTests = true,
    required super.child,
  });

  @override
  RenderListenableTranslate createRenderObject(BuildContext context) => RenderListenableTranslate(offset, transformHitTests);

  @override
  void updateRenderObject(BuildContext context, RenderListenableTranslate renderObject) {
    renderObject
      ..listenable = offset
      ..transformHitTests = transformHitTests;
  }
}

class RenderListenableTranslate extends RenderProxyBox with _ListenableSync<Offset> {
  RenderListenableTranslate(ValueListenable<Offset> offset, this.transformHitTests) : _translation = offset.value {
    _listenable = offset;
  }

  Offset _translation;
  bool transformHitTests;

  @override
  void applyValue(Offset value) {
    if (value == _translation) return;
    _translation = value;
    markNeedsPaint();
  }

  // -- like [RenderTransform], the untransformed size isn't checked, the child is hit where it's painted.
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) => hitTestChildren(result, position: position);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    if (!transformHitTests) return child.hitTest(result, position: position);
    return result.addWithPaintOffset(
      offset: _translation,
      position: position,
      hitTest: (result, transformed) => child.hitTest(result, position: transformed),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.translateByDouble(_translation.dx, _translation.dy, 0.0, 1.0);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    context.paintChild(child, offset + _translation);
  }
}

class ListenablePadding extends SingleChildRenderObjectWidget {
  final ValueListenable<EdgeInsets> padding;

  const ListenablePadding({
    super.key,
    required this.padding,
    required super.child,
  });

  @override
  RenderListenablePadding createRenderObject(BuildContext context) => RenderListenablePadding(padding);

  @override
  void updateRenderObject(BuildContext context, RenderListenablePadding renderObject) => renderObject.listenable = padding;
}

class RenderListenablePadding extends RenderPadding with _ListenableSync<EdgeInsets> {
  RenderListenablePadding(ValueListenable<EdgeInsets> padding) : super(padding: padding.value) {
    _listenable = padding;
  }

  @override
  void applyValue(EdgeInsets value) => padding = value;
}

class ListenableConstrainedBox extends SingleChildRenderObjectWidget {
  final ValueListenable<BoxConstraints> constraints;

  const ListenableConstrainedBox({
    super.key,
    required this.constraints,
    super.child,
  });

  @override
  RenderListenableConstrainedBox createRenderObject(BuildContext context) => RenderListenableConstrainedBox(constraints);

  @override
  void updateRenderObject(BuildContext context, RenderListenableConstrainedBox renderObject) => renderObject.listenable = constraints;
}

class RenderListenableConstrainedBox extends RenderConstrainedBox with _ListenableSync<BoxConstraints> {
  RenderListenableConstrainedBox(ValueListenable<BoxConstraints> constraints) : super(additionalConstraints: constraints.value) {
    _listenable = constraints;
  }

  @override
  void applyValue(BoxConstraints value) => additionalConstraints = value;
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
