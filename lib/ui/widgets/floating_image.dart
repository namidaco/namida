// by claude, me no math
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// A single app-wide ticker driving every floating animation.
///
/// Each subscriber would otherwise own a [Ticker], sharing one keeps the cost flat
/// no matter how many things float at once. Runs only while something listens.
///
/// Every painter driven by this clock calls [markPainted] from its paint. Ticking pauses once
/// nothing painted for [_kIdleSeconds] (ex: all of them scrolled off screen), the next paint resumes it.
class NamidaFloatClock extends ChangeNotifier {
  NamidaFloatClock._();

  static final instance = NamidaFloatClock._();

  static const _kMaxFps = 60;
  static const _kIdleSeconds = 0.25;

  /// Seconds of ticking so far, never goes backwards.
  ///
  /// A [Ticker] restarts its elapsed time from zero, and this one is thrown away
  /// whenever nothing is animating. Carrying the total across restarts keeps every
  /// float, fade and drift going from where it was instead of snapping to a new phase.
  double get seconds => _seconds;
  double _seconds = 0.0;
  double _elapsedBeforeRestart = 0.0;
  double _lastPaintedSeconds = 0.0;

  Ticker? _ticker;
  bool _isIdle = false;
  Timer? _unmuteTimer;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _lastPaintedSeconds = _seconds;
    if (_ticker == null) {
      _ticker = Ticker(_onTick)..start();
    } else if (_isIdle) {
      _resume();
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      _elapsedBeforeRestart = _seconds;
      _isIdle = false;
      _unmuteTimer?.cancel();
      _ticker?.dispose();
      _ticker = null;
    }
  }

  void markPainted() {
    _lastPaintedSeconds = _seconds;
    if (_isIdle) _resume();
  }

  void _resume() {
    _isIdle = false;
    _ticker?.start();
  }

  void _pause() {
    _isIdle = true;
    _elapsedBeforeRestart = _seconds;
    _ticker?.stop();
  }

  void _onTick(Duration elapsed) {
    _seconds = _elapsedBeforeRestart + elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    if (_seconds - _lastPaintedSeconds > _kIdleSeconds) {
      _pause();
      return;
    }
    notifyListeners();
    _skipVsyncsAboveMaxFps();
  }

  /// Mutes the ticker through the vsyncs above [_kMaxFps], no frame is produced for them at all.
  void _skipVsyncsAboveMaxFps() {
    final ticker = _ticker;
    if (ticker == null) return;
    final refreshRate = PlatformDispatcher.instance.implicitView?.display.refreshRate ?? 0.0;
    final vsyncsPerTick = (refreshRate / _kMaxFps).floor();
    if (vsyncsPerTick <= 1) return;
    // -- unmuting mid-way through the last skipped vsync lands the next tick right on the wanted one
    final vsyncMicros = Duration.microsecondsPerSecond / refreshRate;
    final unmuteAfterMicros = ((vsyncsPerTick - 0.5) * vsyncMicros).round();
    final unmuteAfter = Duration(microseconds: unmuteAfterMicros);
    ticker.muted = true;
    _unmuteTimer = Timer(unmuteAfter, _unmute);
  }

  void _unmute() => _ticker?.muted = false;
}

/// Whether a drifting decoration should hold still.
///
/// The system remove-animations setting is deliberately not honored here: these are
/// opt-in decorations that draw nothing at all when they aren't moving, so respecting it
/// would silently hide the whole feature from anyone who turned animations off system-wide.
/// Offstage subtrees still stop, nobody is looking at them.
bool namidaAnimationsPaused(BuildContext context) => !TickerMode.valuesOf(context).enabled;

/// Animates [child] (typically an image) in a smooth slow floating/drifting effect.
///
/// [randomness] controls how organic the motion is:
/// - `0.0` => a clean repeating elliptical loop.
/// - `1.0` => layered incommensurate waves, drifting around without a visible repeating pattern.
///
/// The motion is deterministic for the same [seed], pass null for a different motion per instance.
class FloatingImage extends StatefulWidget {
  final Widget child;

  /// Max distance in logical pixels the child drifts away from its original position.
  final double amplitude;

  /// Duration of one base wave cycle, higher => slower floating.
  final Duration cycleDuration;

  /// How random/organic the floating path is, clamped between 0.0 and 1.0.
  final double randomness;

  /// Max rotation in radians, 0.0 disables rotation.
  final double rotationAmplitude;

  /// Max zoom deviation, ex: 0.05 => scale drifts between 0.95 and 1.05. 0.0 disables zooming.
  final double scaleAmplitude;

  /// Pivot of the rotation & scale, useful to swing a shape around its heavy end.
  final Alignment alignment;

  /// Whether the child repeatedly fades in and out.
  final bool fade;

  /// The time spent fading in, and again fading out.
  final Duration fadeDuration;

  /// The time the child stays fully visible between fading in and out.
  final Duration fadeHoldDuration;

  /// The amount the fade timings can vary per instance, from `0.0` to `1.0`.
  final double fadeRandomness;

  final bool enabled;
  final int? seed;

  const FloatingImage({
    super.key,
    required this.child,
    this.amplitude = 8.0,
    this.cycleDuration = const Duration(seconds: 6),
    this.randomness = 0.5,
    this.rotationAmplitude = 0.0,
    this.scaleAmplitude = 0.0,
    this.alignment = Alignment.center,
    this.fade = false,
    this.fadeDuration = const Duration(seconds: 4),
    this.fadeHoldDuration = const Duration(seconds: 12),
    this.fadeRandomness = 0.25,
    this.enabled = true,
    this.seed,
  });

  @override
  State<FloatingImage> createState() => _FloatingImageState();
}

class _FloatingImageState extends State<FloatingImage> {
  late _FloatPhases _phases;

  @override
  void initState() {
    super.initState();
    _phases = _FloatPhases.random(widget);
  }

  @override
  void didUpdateWidget(covariant FloatingImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seed != widget.seed ||
        oldWidget.fadeDuration != widget.fadeDuration ||
        oldWidget.fadeHoldDuration != widget.fadeHoldDuration ||
        oldWidget.fadeRandomness != widget.fadeRandomness) {
      _phases = _FloatPhases.random(widget);
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = RepaintBoundary(child: widget.child);
    if (!widget.enabled || namidaAnimationsPaused(context)) return child;

    final cycleUS = widget.cycleDuration.inMicroseconds;
    final omega = cycleUS <= 0 ? 0.0 : 2 * math.pi / (cycleUS / Duration.microsecondsPerSecond);
    final randomness = widget.randomness.clamp(0.0, 1.0);
    final motion = _FloatMotion(
      amplitude: widget.amplitude,
      omega: omega,
      randomness: randomness,
      rotationAmplitude: widget.rotationAmplitude,
      scaleAmplitude: widget.scaleAmplitude,
      alignment: widget.alignment,
      fade: widget.fade,
      phases: _phases,
    );
    return _FloatingBox(
      motion: motion,
      child: child,
    );
  }
}

/// Moves its child at paint time, ticks only repaint it instead of rebuilding.
class _FloatingBox extends SingleChildRenderObjectWidget {
  final _FloatMotion motion;

  const _FloatingBox({
    required this.motion,
    required super.child,
  });

  @override
  _RenderFloatingBox createRenderObject(BuildContext context) => _RenderFloatingBox(motion);

  @override
  void updateRenderObject(BuildContext context, _RenderFloatingBox renderObject) {
    renderObject.motion = motion;
  }
}

class _RenderFloatingBox extends RenderProxyBox {
  _RenderFloatingBox(this._motion);

  _FloatMotion _motion;
  set motion(_FloatMotion value) {
    if (identical(value, _motion)) return;
    _motion = value;
    markNeedsPaint();
  }

  Matrix4 _paintTransform = Matrix4.identity();
  int _paintAlpha = 255;
  final _opacityLayer = LayerHandle<OpacityLayer>();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    NamidaFloatClock.instance.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    NamidaFloatClock.instance.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _opacityLayer.layer = null;
    super.dispose();
  }

  // -- like [RenderTransform], the untransformed size isn't checked, the child is hit where it's painted.
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) => hitTestChildren(result, position: position);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return result.addWithPaintTransform(
      transform: _paintTransform,
      position: position,
      hitTest: (result, position) => super.hitTestChildren(result, position: position),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_paintTransform);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    final clock = NamidaFloatClock.instance;
    clock.markPainted();
    final time = clock.seconds;
    final motion = _motion;
    _paintTransform = motion.transformAt(time, size);
    _paintAlpha = motion.fade ? motion.alphaAt(time) : 255;
    layer = context.pushTransform(
      needsCompositing,
      offset,
      _paintTransform,
      _paintFaded,
      oldLayer: layer as TransformLayer?,
    );
  }

  // -- opacity sits under the transform so the child stays the repaint boundary,
  // -- composited as an opacity layer instead of a saveLayer.
  void _paintFaded(PaintingContext context, Offset offset) {
    final alpha = _paintAlpha;
    if (alpha == 0) {
      _opacityLayer.layer = null;
      return;
    }
    if (alpha == 255) {
      _opacityLayer.layer = null;
      super.paint(context, offset);
      return;
    }
    _opacityLayer.layer = context.pushOpacity(offset, alpha, super.paint, oldLayer: _opacityLayer.layer);
  }
}

class _FloatMotion {
  final double amplitude;
  final double omega;
  final double randomness;
  final double rotationAmplitude;
  final double scaleAmplitude;
  final Alignment alignment;
  final bool fade;
  final _FloatPhases phases;

  const _FloatMotion({
    required this.amplitude,
    required this.omega,
    required this.randomness,
    required this.rotationAmplitude,
    required this.scaleAmplitude,
    required this.alignment,
    required this.fade,
    required this.phases,
  });

  /// base wave + a faster incommensurate wave scaled by [randomness], normalized to [-1, 1].
  double _wave(double angle, double phase1, double freq2, double phase2, {required bool cosBase}) {
    final base = cosBase ? math.cos(angle + phase1) : math.sin(angle + phase1);
    if (randomness <= 0) return base;
    final wander = math.sin(angle * freq2 + phase2);
    return (base + wander * randomness) / (1 + randomness);
  }

  Matrix4 transformAt(double time, Size size) {
    final angle = time * omega;
    final dx = amplitude * _wave(angle, phases.x1, phases.freqX2, phases.x2, cosBase: false);
    final dy = amplitude * _wave(angle, phases.y1, phases.freqY2, phases.y2, cosBase: true);
    final origin = alignment.alongSize(size);
    final transform = Matrix4.translationValues(origin.dx + dx, origin.dy + dy, 0.0);
    if (rotationAmplitude != 0.0) {
      transform.rotateZ(rotationAmplitude * _wave(angle * 0.8, phases.rotation, 1.86, phases.x2, cosBase: false));
    }
    if (scaleAmplitude != 0.0) {
      // -- slightly slower than the positional drift, feels more natural
      final scale = 1.0 + scaleAmplitude * _wave(angle * 0.7, phases.scale1, phases.freqS2, phases.scale2, cosBase: false);
      transform.scaleByDouble(scale, scale, 1.0, 1.0);
    }
    transform.translateByDouble(-origin.dx, -origin.dy, 0.0, 1.0);
    return transform;
  }

  int alphaAt(double time) {
    final opacity = _opacityAt(time);
    return Color.getAlphaFromOpacity(opacity);
  }

  double _opacityAt(double time) {
    final fadeInS = phases.fadeInS;
    final fadeHoldS = phases.fadeHoldS;
    final period = fadeInS + fadeHoldS + phases.fadeOutS;
    final t = (time + phases.fadeOffsetS) % period;
    if (t < fadeInS) return Curves.easeInOutSine.transform(t / fadeInS);
    if (t < fadeInS + fadeHoldS) return 1.0;
    return Curves.easeInOutSine.transform(1.0 - (t - fadeInS - fadeHoldS) / phases.fadeOutS);
  }
}

/// Kept across rebuilds so changing other params doesn't make the path jump.
class _FloatPhases {
  final double x1, y1, x2, y2, rotation, scale1, scale2;
  final double freqX2, freqY2, freqS2;
  final double fadeInS, fadeHoldS, fadeOutS, fadeOffsetS;

  const _FloatPhases({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.rotation,
    required this.scale1,
    required this.scale2,
    required this.freqX2,
    required this.freqY2,
    required this.freqS2,
    required this.fadeInS,
    required this.fadeHoldS,
    required this.fadeOutS,
    required this.fadeOffsetS,
  });

  factory _FloatPhases.random(FloatingImage widget) {
    final rng = math.Random(widget.seed);
    double randomPhase() => rng.nextDouble() * 2 * math.pi;

    double vary(Duration d) {
      final factor = 1.0 + (rng.nextDouble() - 0.5) * widget.fadeRandomness;
      return math.max(0.001, d.inMicroseconds / Duration.microsecondsPerSecond * factor);
    }

    final x1 = randomPhase();
    final y1 = randomPhase();
    final x2 = randomPhase();
    final y2 = randomPhase();
    final rotation = randomPhase();
    final scale1 = randomPhase();
    final scale2 = randomPhase();
    // -- irrational-ish frequency ratios => the combined wave doesn't visibly repeat
    final freqX2 = 1.618 + rng.nextDouble() * 0.8;
    final freqY2 = 1.414 + rng.nextDouble() * 0.8;
    final freqS2 = 1.732 + rng.nextDouble() * 0.8;
    final fadeInS = vary(widget.fadeDuration);
    final fadeHoldS = vary(widget.fadeHoldDuration);
    final fadeOutS = vary(widget.fadeDuration);
    final fadeOffsetS = rng.nextDouble() * (fadeInS + fadeHoldS + fadeOutS);
    return _FloatPhases(
      x1: x1,
      y1: y1,
      x2: x2,
      y2: y2,
      rotation: rotation,
      scale1: scale1,
      scale2: scale2,
      freqX2: freqX2,
      freqY2: freqY2,
      freqS2: freqS2,
      fadeInS: fadeInS,
      fadeHoldS: fadeHoldS,
      fadeOutS: fadeOutS,
      fadeOffsetS: fadeOffsetS,
    );
  }
}
