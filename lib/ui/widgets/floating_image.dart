// by claude, me no math
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// A single app-wide ticker driving every floating animation.
///
/// Each subscriber would otherwise own a [Ticker], sharing one keeps the cost flat
/// no matter how many things float at once. Runs only while something listens.
class NamidaFloatClock extends ChangeNotifier {
  NamidaFloatClock._();

  static final instance = NamidaFloatClock._();

  /// Seconds of ticking so far, never goes backwards.
  ///
  /// A [Ticker] restarts its elapsed time from zero, and this one is thrown away
  /// whenever nothing is animating. Carrying the total across restarts keeps every
  /// float, fade and drift going from where it was instead of snapping to a new phase.
  double get seconds => _seconds;
  double _seconds = 0.0;
  double _elapsedBeforeRestart = 0.0;

  Ticker? _ticker;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    if (_ticker == null) {
      _ticker = Ticker(_onTick);
      _ticker!.start();
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      _elapsedBeforeRestart = _seconds;
      _ticker?.dispose();
      _ticker = null;
    }
  }

  void _onTick(Duration elapsed) {
    _seconds = _elapsedBeforeRestart + elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    notifyListeners();
  }
}

bool namidaAnimationsDisabled(BuildContext context) {
  return (MediaQuery.maybeDisableAnimationsOf(context) ?? false) || !TickerMode.valuesOf(context).enabled;
}

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
  late double _phX1, _phY1, _phX2, _phY2, _phR, _phS1, _phS2, _phFade;
  late double _freqX2, _freqY2, _freqS2;
  late double _fadeInS, _fadeHoldS, _fadeOutS;

  @override
  void initState() {
    super.initState();
    _initRandoms();
  }

  @override
  void didUpdateWidget(covariant FloatingImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seed != widget.seed ||
        oldWidget.fadeDuration != widget.fadeDuration ||
        oldWidget.fadeHoldDuration != widget.fadeHoldDuration ||
        oldWidget.fadeRandomness != widget.fadeRandomness) {
      _initRandoms();
    }
  }

  void _initRandoms() {
    final rng = math.Random(widget.seed);
    double randomPhase() => rng.nextDouble() * 2 * math.pi;
    _phX1 = randomPhase();
    _phY1 = randomPhase();
    _phX2 = randomPhase();
    _phY2 = randomPhase();
    _phR = randomPhase();
    _phS1 = randomPhase();
    _phS2 = randomPhase();
    // -- irrational-ish frequency ratios => the combined wave doesn't visibly repeat
    _freqX2 = 1.618 + rng.nextDouble() * 0.8;
    _freqY2 = 1.414 + rng.nextDouble() * 0.8;
    _freqS2 = 1.732 + rng.nextDouble() * 0.8;

    double vary(Duration d) {
      final factor = 1.0 + (rng.nextDouble() - 0.5) * widget.fadeRandomness;
      return math.max(0.001, d.inMicroseconds / Duration.microsecondsPerSecond * factor);
    }

    _fadeInS = vary(widget.fadeDuration);
    _fadeHoldS = vary(widget.fadeHoldDuration);
    _fadeOutS = vary(widget.fadeDuration);
    _phFade = rng.nextDouble() * (_fadeInS + _fadeHoldS + _fadeOutS);
  }

  /// base wave + a faster incommensurate wave scaled by [randomness], normalized to [-1, 1].
  double _wave(double angle, double phase1, double freq2, double phase2, double randomness, {required bool cosBase}) {
    final base = cosBase ? math.cos(angle + phase1) : math.sin(angle + phase1);
    if (randomness <= 0) return base;
    final wander = math.sin(angle * freq2 + phase2);
    return (base + wander * randomness) / (1 + randomness);
  }

  double _fadeOpacity(double time) {
    final period = _fadeInS + _fadeHoldS + _fadeOutS;
    final t = (time + _phFade) % period;
    if (t < _fadeInS) return Curves.easeInOutSine.transform(t / _fadeInS);
    if (t < _fadeInS + _fadeHoldS) return 1.0;
    return Curves.easeInOutSine.transform(1.0 - (t - _fadeInS - _fadeHoldS) / _fadeOutS);
  }

  @override
  Widget build(BuildContext context) {
    final child = RepaintBoundary(child: widget.child);
    if (!widget.enabled || namidaAnimationsDisabled(context)) return child;

    final cycleUS = widget.cycleDuration.inMicroseconds;
    final omega = cycleUS <= 0 ? 0.0 : 2 * math.pi / (cycleUS / Duration.microsecondsPerSecond);
    final randomness = widget.randomness.clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: NamidaFloatClock.instance,
      child: child,
      builder: (context, child) {
        final time = NamidaFloatClock.instance.seconds;
        final angle = time * omega;
        final dx = widget.amplitude * _wave(angle, _phX1, _freqX2, _phX2, randomness, cosBase: false);
        final dy = widget.amplitude * _wave(angle, _phY1, _freqY2, _phY2, randomness, cosBase: true);
        final transform = Matrix4.translationValues(dx, dy, 0.0);
        if (widget.rotationAmplitude != 0.0) {
          transform.rotateZ(widget.rotationAmplitude * _wave(angle * 0.8, _phR, 1.86, _phX2, randomness, cosBase: false));
        }
        if (widget.scaleAmplitude != 0.0) {
          // -- slightly slower than the positional drift, feels more natural
          final scale = 1.0 + widget.scaleAmplitude * _wave(angle * 0.7, _phS1, _freqS2, _phS2, randomness, cosBase: false);
          transform.multiply(Matrix4.diagonal3Values(scale, scale, 1.0));
        }
        return Transform(
          transform: transform,
          alignment: widget.alignment,
          // -- opacity sits under the transform so its child stays the repaint
          // -- boundary, composited as an opacity layer instead of a saveLayer.
          child: widget.fade
              ? Opacity(
                  opacity: _fadeOpacity(time),
                  child: child,
                )
              : child,
        );
      },
    );
  }
}
