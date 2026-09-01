// built by claude, source: https://github.com/namidaco/namida/issues/1139#issuecomment-5308338873

import 'dart:math' as math;
import 'dart:ui' show BoxHeightStyle, PathMetric;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:nampack/extensions/extensions.dart';

import 'package:namida/controller/vibrator_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';

/// Extra flavor animations, all usages are guarded by [kEnableFancyAnimations].
///
/// everything here is built to cost nothing once it settles, ie. tickers are stopped
/// and the fancy wrappers get replaced by their plain equivalent as soon as they are done.

// =============================================================================
// -- shared math --
// =============================================================================

double _damp(double current, double target, double tau, double dt) {
  if (dt <= 0) return current;
  return target + (current - target) * math.exp(-dt / tau);
}

Offset _dampOffset(Offset current, Offset target, double tau, double dt) {
  if (dt <= 0) return current;
  final factor = math.exp(-dt / tau);
  return target + (current - target) * factor;
}

/// piecewise-linear keyframe lookup, [stops] must be sorted & same length as [values].
double _keyframe(List<double> stops, List<double> values, double t) {
  if (t <= stops.first) return values.first;
  for (int i = 0; i < stops.length - 1; i++) {
    if (t <= stops[i + 1]) {
      final span = stops[i + 1] - stops[i];
      final localT = span == 0 ? 0.0 : (t - stops[i]) / span;
      return values[i] + (values[i + 1] - values[i]) * localT;
    }
  }
  return values.last;
}

/// cheap value noise, good enough to steer a flow field.
double _perlinHash(double x, double y) {
  final v = 43758.5453 * math.sin(12.9898 * x + 78.233 * y);
  return v - v.floorToDouble();
}

bool _animationsDisabled(BuildContext context) {
  return (MediaQuery.maybeDisableAnimationsOf(context) ?? false) || !TickerMode.valuesOf(context).enabled;
}

/// bumped manually each frame, so that only the transform layer rebuilds instead of the child subtree.
class _TickNotifier extends ChangeNotifier {
  void tick() => notifyListeners();
}

// =============================================================================
// -- CAMagneticButton --
// =============================================================================

/// Pulls [child] towards the pointer.
///
/// on desktop it reacts to hover, on touch devices it reacts to the press position
/// (which is where it actually matters, hover-only effects are invisible on phones).
///
/// this only draws, it never joins the gesture arena, so wrapping an already tappable
/// widget is safe.
class CAMagneticButton extends StatefulWidget {
  final Widget child;

  /// distance at which the pull starts, in logical pixels.
  final double radius;

  /// how much of the pointer delta is applied, `0.32` => the child travels at most a third of the way.
  final double pullFactor;

  /// scale while pressed.
  final double pressScale;

  /// max horizontal shear applied from the pointer velocity.
  final double maxSkewRadians;

  const CAMagneticButton({
    super.key,
    required this.child,
    this.radius = 88.0,
    this.pullFactor = 0.32,
    this.pressScale = 0.94,
    this.maxSkewRadians = 0.12,
  });

  @override
  State<CAMagneticButton> createState() => _CAMagneticButtonState();
}

class _CAMagneticButtonState extends State<CAMagneticButton> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _notifier = _TickNotifier();

  Duration _lastTick = Duration.zero;

  Offset _pos = Offset.zero;
  Offset _targetPos = Offset.zero;
  double _skew = 0.0;
  double _targetSkew = 0.0;
  double _scale = 1.0;
  double _targetScale = 1.0;

  /// decaying overshoot applied on release.
  double _pop = 0.0;

  bool _pressing = false;
  bool _hovering = false;

  Offset? _lastLocal;
  Duration _lastLocalTime = Duration.zero;

  static const _posTau = 0.09;
  static const _skewTau = 0.07;
  static const _scaleTau = 0.10;
  static const _skewDecayTau = 0.12;
  static const _popDecayTau = 0.13;
  static const _epsilon = 0.002;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _notifier.dispose();
    super.dispose();
  }

  void _ensureTicking() {
    if (!_ticker.isTicking) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) _lastTick = elapsed;
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt <= 0) return;

    _pos = _dampOffset(_pos, _targetPos, _posTau, dt);
    _skew = _damp(_skew, _targetSkew, _skewTau, dt);
    _targetSkew *= math.exp(-dt / _skewDecayTau);
    _pop *= math.exp(-dt / _popDecayTau);

    // -- slight swell while being dragged away from center.
    final pullDist = _pos.distance;
    final maxPull = widget.radius * widget.pullFactor;
    final swell = maxPull <= 0 ? 0.0 : 0.02 * (pullDist / maxPull).clamp(0.0, 1.0);
    _scale = _damp(_scale, _targetScale + swell, _scaleTau, dt);

    _notifier.tick();

    if (!_pressing && !_hovering) {
      final settled =
          (_pos - _targetPos).distance < _epsilon && //
          _targetPos == Offset.zero &&
          _skew.abs() < _epsilon &&
          _pop.abs() < _epsilon &&
          (_scale - 1.0).abs() < _epsilon;
      if (settled) {
        _pos = Offset.zero;
        _skew = 0.0;
        _scale = 1.0;
        _pop = 0.0;
        _notifier.tick();
        _ticker.stop();
      }
    }
  }

  void _onPointer(Offset globalPosition, Duration timeStamp, {required bool pressed}) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final local = box.globalToLocal(globalPosition);
    final delta = local - box.size.center(Offset.zero);
    final dist = delta.distance;

    // -- pressing means the pointer is already on the button, so we allow it to be dragged further out.
    final radius = pressed ? widget.radius * 1.6 : widget.radius;
    if (dist < radius) {
      final pull = 1.0 - (dist / radius);
      _targetPos = delta * widget.pullFactor * pull;
    } else {
      _targetPos = Offset.zero;
    }

    final lastLocal = _lastLocal;
    if (lastLocal != null) {
      final dtp = (timeStamp - _lastLocalTime).inMicroseconds / 1e6;
      if (dtp > 0) _targetSkew = (((local.dx - lastLocal.dx) / dtp) / 1200).clamp(-1.0, 1.0) * widget.maxSkewRadians;
    }
    _lastLocal = local;
    _lastLocalTime = timeStamp;

    _ensureTicking();
  }

  void _onPointerDown(PointerDownEvent event) {
    _pressing = true;
    _targetScale = widget.pressScale;
    _lastLocal = null;
    _onPointer(event.position, event.timeStamp, pressed: true);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pressing) return;
    _onPointer(event.position, event.timeStamp, pressed: true);
  }

  void _onPointerEnd(PointerEvent event) {
    if (!_pressing) return;
    _pressing = false;
    _targetScale = 1.0;
    _targetPos = Offset.zero;
    _targetSkew = 0.0;
    _lastLocal = null;
    _pop = 0.05;
    _ensureTicking();
  }

  void _onHover(PointerHoverEvent event) {
    _hovering = true;
    _onPointer(event.position, event.timeStamp, pressed: false);
  }

  void _onExit(PointerExitEvent event) {
    _hovering = false;
    _targetPos = Offset.zero;
    _targetSkew = 0.0;
    _lastLocal = null;
    _ensureTicking();
  }

  @override
  Widget build(BuildContext context) {
    if (_animationsDisabled(context)) return widget.child;

    Widget child = Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerEnd,
      onPointerCancel: _onPointerEnd,
      child: AnimatedBuilder(
        animation: _notifier,
        child: widget.child,
        builder: (context, child) {
          return Transform(
            transform: Matrix4.identity()
              ..translateByDouble(_pos.dx, _pos.dy, 0.0, 1.0)
              ..scaleByDouble(_scale + _pop, _scale + _pop, 1.0, 1.0)
              ..setEntry(0, 1, math.tan(_skew)),
            alignment: Alignment.center,
            child: child,
          );
        },
      ),
    );

    if (isDesktop) {
      // -- `opaque` must stay true, a non opaque [MouseRegion] reports its hit test as a miss,
      // -- which would keep taps from reaching whatever wraps us.
      child = MouseRegion(
        onHover: _onHover,
        onExit: _onExit,
        child: child,
      );
    }

    return RepaintBoundary(child: child);
  }
}

// =============================================================================
// -- CAKineticTypeText --
// =============================================================================

const _kfTextStops = [0.0, 0.55, 0.80, 1.0];
const _kfTextTranslateY = [14.0, -3.0, 1.0, 0.0];
const _kfTextScale = [0.92, 1.04, 0.99, 1.0];
const _kfTextOpacity = [0.0, 1.0, 1.0, 1.0];

enum KineticTypeTrigger {
  /// plays once, as soon as it's built (and again whenever the text changes).
  onMount,

  /// plays on hover, and on press for touch devices where there is no hover to begin with.
  onHover,
}

/// A [Text] that settles in word by word instead of appearing flat.
///
/// splitting is done per word (never per letter) so that shaped scripts (arabic, etc) stay correct,
/// and word placement is taken from the real paragraph layout so it matches a plain [Text] exactly,
/// which lets us drop back to one as soon as the animation is over.
class CAKineticTypeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final int? maxLines;
  final Duration wordDuration;
  final Duration staggerStep;
  final KineticTypeTrigger trigger;

  const CAKineticTypeText({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.wordDuration = const Duration(milliseconds: 560),
    this.staggerStep = const Duration(milliseconds: 65),
    this.trigger = KineticTypeTrigger.onMount,
  });

  @override
  State<CAKineticTypeText> createState() => _CAKineticTypeTextState();
}

/// [CAKineticTypeText] that replays on hover instead of playing by itself.
///
/// on touch devices, where there is no hover, it replays on press instead, through a
/// [Listener] that never joins the gesture arena, so it doesn't eat taps meant for anything around it.
class CAKineticTypeTextHover extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final int? maxLines;
  final Duration wordDuration;
  final Duration staggerStep;

  const CAKineticTypeTextHover({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.wordDuration = const Duration(milliseconds: 560),
    this.staggerStep = const Duration(milliseconds: 65),
  });

  @override
  Widget build(BuildContext context) {
    return CAKineticTypeText(
      text: text,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      wordDuration: wordDuration,
      staggerStep: staggerStep,
      trigger: KineticTypeTrigger.onHover,
    );
  }
}

class _CAKineticTypeTextState extends State<CAKineticTypeText> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  List<_KineticWord>? _words;
  Size _size = Size.zero;

  // -- cache keys, so the layout is only redone when something that affects it changed.
  double _lastMaxWidth = -1;
  String? _lastText;
  TextStyle? _lastStyle;
  TextDirection? _lastDirection;
  TextScaler? _lastScaler;

  bool get _done => _controller.isCompleted;

  @override
  void initState() {
    super.initState();
    // -- the hover variant starts settled, it only plays when asked to.
    _controller = AnimationController(vsync: this, value: widget.trigger == KineticTypeTrigger.onHover ? 1.0 : 0.0);
    _controller.addStatusListener(_onStatus);
  }

  @override
  void didUpdateWidget(covariant CAKineticTypeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text && widget.trigger == KineticTypeTrigger.onMount) _controller.value = 0.0;
  }

  void _replay() {
    if (_controller.isAnimating || _controller.value < 1.0) return;
    if (_animationsDisabled(context)) return;
    setState(() => _controller.value = 0.0); // -- build takes it from here
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatus);
    _controller.dispose();
    _disposeWords();
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    // -- swap back to a plain [Text] once done.
    if (status == AnimationStatus.completed && mounted) setState(() => _disposeWords());
  }

  void _disposeWords() {
    final words = _words;
    if (words != null) {
      for (final w in words) {
        w.painter.dispose();
      }
      _words = null;
    }
    _lastMaxWidth = -1;
  }

  Duration get _totalDuration {
    final count = _words?.length ?? 1;
    return Duration(milliseconds: widget.wordDuration.inMilliseconds + widget.staggerStep.inMilliseconds * (count > 1 ? count - 1 : 0));
  }

  void _prepare(double maxWidth, TextStyle style, TextDirection direction, TextScaler scaler) {
    if (_words != null && _lastMaxWidth == maxWidth && _lastText == widget.text && _lastStyle == style && _lastDirection == direction && _lastScaler == scaler) return;

    _disposeWords();
    _lastMaxWidth = maxWidth;
    _lastText = widget.text;
    _lastStyle = style;
    _lastDirection = direction;
    _lastScaler = scaler;

    final full = TextPainter(
      text: TextSpan(text: widget.text, style: style),
      textDirection: direction,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      textScaler: scaler,
    )..layout(maxWidth: maxWidth);
    _size = full.size;

    final words = <_KineticWord>[];
    final text = widget.text;
    int start = 0;
    for (int i = 0; i <= text.length; i++) {
      final isBreak = i == text.length || text.codeUnitAt(i) == 0x20;
      if (!isBreak) continue;
      if (i > start) {
        final word = text.substring(start, i);
        // -- [BoxHeightStyle.strut] so each box spans the whole line box, like a standalone single-line layout does.
        final boxes = full.getBoxesForSelection(
          TextSelection(baseOffset: start, extentOffset: i),
          boxHeightStyle: BoxHeightStyle.strut,
        );
        if (boxes.isNotEmpty) {
          var rect = boxes.first.toRect();
          for (int b = 1; b < boxes.length; b++) {
            rect = rect.expandToInclude(boxes[b].toRect());
          }
          final painter = TextPainter(
            text: TextSpan(text: word, style: style),
            textDirection: direction,
            textScaler: scaler,
          )..layout();
          words.add(
            _KineticWord(
              painter: painter,
              offset: Offset(rect.left, rect.top + (rect.height - painter.height) / 2),
            ),
          );
        }
      }
      start = i + 1;
    }
    full.dispose();
    _words = words;
    _controller.duration = _totalDuration;
  }

  @override
  Widget build(BuildContext context) {
    Widget result = _buildText(context);
    if (widget.trigger == KineticTypeTrigger.onHover) {
      result = MouseRegion(
        onEnter: (_) => _replay(),
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _replay(),
          child: result,
        ),
      );
    }
    return result;
  }

  Widget _buildText(BuildContext context) {
    if (_done || _animationsDisabled(context)) {
      return Text(
        widget.text,
        style: widget.style,
        textAlign: widget.textAlign,
        maxLines: widget.maxLines,
      );
    }

    // -- resolved the same way [Text] does, otherwise the painted layout wouldn't match the plain one we fall back to.
    final widgetStyle = widget.style;
    final style = widgetStyle == null || widgetStyle.inherit ? DefaultTextStyle.of(context).style.merge(widgetStyle) : widgetStyle;
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);

    return Semantics(
      label: widget.text,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _prepare(constraints.maxWidth, style, direction, scaler);
          final words = _words!;
          if (words.isEmpty) return const SizedBox();

          if (!_controller.isAnimating && _controller.value == 0.0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _controller.value == 0.0) _controller.forward();
            });
          }

          return CustomPaint(
            size: _size,
            painter: _KineticWordsPainter(
              words: words,
              animation: _controller,
              totalMs: _totalDuration.inMilliseconds,
              wordMs: widget.wordDuration.inMilliseconds,
              staggerMs: widget.staggerStep.inMilliseconds,
            ),
          );
        },
      ),
    );
  }
}

class _KineticWord {
  final TextPainter painter;
  final Offset offset;

  const _KineticWord({required this.painter, required this.offset});
}

class _KineticWordsPainter extends CustomPainter {
  final List<_KineticWord> words;
  final Animation<double> animation;
  final int totalMs;
  final int wordMs;
  final int staggerMs;

  _KineticWordsPainter({
    required this.words,
    required this.animation,
    required this.totalMs,
    required this.wordMs,
    required this.staggerMs,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    final total = totalMs <= 0 ? 1 : totalMs;

    for (int i = 0; i < words.length; i++) {
      final startMs = i * staggerMs;
      final localT = ((t * total) - startMs) / (wordMs <= 0 ? 1 : wordMs);
      if (localT <= 0) continue;

      final word = words[i];
      final clamped = localT.clamp(0.0, 1.0);
      final sc = _keyframe(_kfTextStops, _kfTextScale, clamped);
      final ty = _keyframe(_kfTextStops, _kfTextTranslateY, clamped);
      final op = _keyframe(_kfTextStops, _kfTextOpacity, clamped);
      if (op <= 0.0) continue;

      final w = word.painter.width;
      final h = word.painter.height;

      canvas.save();
      canvas.translate(word.offset.dx + w / 2, word.offset.dy + h / 2 + ty);
      canvas.scale(sc);
      canvas.translate(-w / 2, -h / 2);
      if (op < 1.0) {
        // -- tiny layer, only ever a handful of words are mid-flight.
        canvas.saveLayer(Rect.fromLTWH(0, 0, w, h), Paint()..color = Color.fromRGBO(255, 255, 255, op));
        word.painter.paint(canvas, Offset.zero);
        canvas.restore();
      } else {
        word.painter.paint(canvas, Offset.zero);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _KineticWordsPainter oldDelegate) {
    return oldDelegate.words != words || oldDelegate.animation != animation || oldDelegate.totalMs != totalMs || oldDelegate.wordMs != wordMs || oldDelegate.staggerMs != staggerMs;
  }
}

// =============================================================================
// -- CAElasticRevealScope --
// =============================================================================

typedef CAElasticRevealWrapper = Widget Function(int index, Widget child);

/// Gives [builder] a [CAElasticRevealWrapper] to wrap lazily built list items with, items
/// bounce in one after the other.
///
/// a single controller drives the whole list, and once it completes the wrapper becomes a
/// no-op, so items scrolled in later are not animated & cost nothing.
class CAElasticRevealScope extends StatefulWidget {
  final Widget Function(BuildContext context, CAElasticRevealWrapper wrap) builder;
  final Duration itemDuration;
  final Duration staggerStep;

  /// items past this index all start at the same time, keeps the total duration bounded.
  final int maxStaggeredItems;
  final Axis direction;
  final double travel;

  const CAElasticRevealScope({
    super.key,
    required this.builder,
    this.itemDuration = const Duration(milliseconds: 750),
    this.staggerStep = const Duration(milliseconds: 65),
    this.maxStaggeredItems = 8,
    this.direction = Axis.horizontal,
    this.travel = 28.0,
  });

  @override
  State<CAElasticRevealScope> createState() => _CAElasticRevealScopeState();
}

class _CAElasticRevealScopeState extends State<CAElasticRevealScope> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;

  int get _totalMs => widget.itemDuration.inMilliseconds + widget.staggerStep.inMilliseconds * widget.maxStaggeredItems;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _totalMs),
    );
    _controller.addStatusListener(_onStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (_animationsDisabled(context)) {
      _controller.value = 1.0;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatus);
    _controller.dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    // -- rebuild once so that [_wrap] stops wrapping anything at all.
    if (status == AnimationStatus.completed && mounted) setState(() {});
  }

  Widget _wrap(int index, Widget child) {
    if (_controller.isCompleted) return child;
    final i = index < 0
        ? 0
        : index > widget.maxStaggeredItems
        ? widget.maxStaggeredItems
        : index;
    final total = _totalMs <= 0 ? 1 : _totalMs;
    final startMs = i * widget.staggerStep.inMilliseconds;
    return _ElasticRevealItem(
      parent: _controller,
      begin: startMs / total,
      end: (startMs + widget.itemDuration.inMilliseconds) / total,
      direction: widget.direction,
      travel: widget.travel,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _wrap);
}

class _ElasticRevealItem extends StatelessWidget {
  final Animation<double> parent;
  final double begin;
  final double end;
  final Axis direction;
  final double travel;
  final Widget child;

  const _ElasticRevealItem({
    required this.parent,
    required this.begin,
    required this.end,
    required this.direction,
    required this.travel,
    required this.child,
  });

  static const _elastic = ElasticOutCurve(0.62);

  @override
  Widget build(BuildContext context) {
    final travel = direction == Axis.horizontal && Directionality.of(context) == TextDirection.rtl ? -this.travel : this.travel;
    return AnimatedBuilder(
      animation: parent,
      child: child,
      builder: (context, child) {
        final span = end - begin;
        final raw = (span <= 0 ? 1.0 : (parent.value - begin) / span).clamp(0.0, 1.0);
        if (raw >= 1.0) return child!;
        if (raw <= 0.0) return Opacity(opacity: 0.0, child: child);

        final slide = Curves.easeOutCubic.transform(raw);
        final scale = 0.90 + 0.10 * _elastic.transform(raw);
        return Opacity(
          opacity: slide,
          child: Transform.translate(
            offset: direction == Axis.horizontal ? Offset((1 - slide) * travel, 0.0) : Offset(0.0, (1 - slide) * travel),
            child: Transform.scale(
              scale: scale,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// -- CAMorphCheckIcon --
// =============================================================================

/// Morphs the previous icon into a stroked checkmark then into [icon], instead of
/// swapping icons instantly.
///
/// only animates when [isSuccess] flips to `true` while [identity] stays the same, so
/// merely landing on an already-succeeded item doesn't replay it.
class CAMorphCheckIcon extends StatefulWidget {
  final IconData icon;
  final bool isSuccess;
  final Object? identity;
  final double size;
  final Color? color;
  final Color? successColor;
  final Duration duration;

  const CAMorphCheckIcon({
    super.key,
    required this.icon,
    required this.isSuccess,
    this.identity,
    this.size = 25.0,
    this.color,
    this.successColor,
    this.duration = const Duration(milliseconds: 620),
  });

  @override
  State<CAMorphCheckIcon> createState() => _CAMorphCheckIconState();
}

class _CAMorphCheckIconState extends State<CAMorphCheckIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  IconData? _prevIcon;

  static const _outEnd = 0.34;
  static const _checkStart = 0.26;
  static const _checkEnd = 0.78;
  static const _swapStart = 0.76;

  bool get _isMorphing => _controller.isAnimating || (_controller.value > 0.0 && _controller.value < 1.0);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration, value: widget.isSuccess ? 1.0 : 0.0);
    _controller.addStatusListener(_onStatus);
  }

  @override
  void didUpdateWidget(covariant CAMorphCheckIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.identity != oldWidget.identity) {
      _prevIcon = null;
      _controller.value = widget.isSuccess ? 1.0 : 0.0;
      return;
    }
    if (widget.isSuccess == oldWidget.isSuccess) return;

    if (widget.isSuccess) {
      _prevIcon = oldWidget.icon;
      if (_animationsDisabled(context)) {
        _controller.value = 1.0;
      } else {
        _controller.forward(from: 0.0);
        VibratorController.medium();
      }
    } else {
      _prevIcon = null;
      _controller.value = 0.0;
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatus);
    _controller.dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) setState(() => _prevIcon = null);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isMorphing) return Icon(widget.icon, size: widget.size, color: widget.color);

    final prevIcon = _prevIcon;
    final checkColor = widget.successColor ?? widget.color ?? IconTheme.of(context).color ?? Colors.white;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final children = <Widget>[];

          if (prevIcon != null && t < _outEnd) {
            final lt = t / _outEnd;
            children.add(
              Opacity(
                opacity: 1.0 - lt,
                child: Transform.rotate(
                  angle: -0.6 * lt,
                  child: Transform.scale(
                    scale: 1.0 - lt,
                    child: Icon(prevIcon, size: widget.size, color: widget.color),
                  ),
                ),
              ),
            );
          }

          final checkT = ((t - _checkStart) / (_checkEnd - _checkStart)).clamp(0.0, 1.0);
          final checkFade = ((t - _swapStart) / (1.0 - _swapStart)).clamp(0.0, 1.0);
          if (checkT > 0.0 && checkFade < 1.0) {
            children.add(
              Opacity(
                opacity: 1.0 - checkFade,
                child: CustomPaint(
                  size: Size.square(widget.size),
                  painter: _CheckPainter(
                    progress: Curves.easeOutCubic.transform(checkT),
                    color: checkColor,
                    strokeWidth: widget.size * 0.11,
                  ),
                ),
              ),
            );
          }

          if (checkFade > 0.0) {
            children.add(
              Opacity(
                opacity: checkFade,
                child: Transform.scale(
                  scale: 0.72 + 0.28 * Curves.easeOutBack.transform(checkFade),
                  child: Icon(widget.icon, size: widget.size, color: widget.color),
                ),
              ),
            );
          }

          return Stack(alignment: Alignment.center, children: children);
        },
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  const _CheckPainter({required this.progress, required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.52)
      ..lineTo(size.width * 0.42, size.height * 0.76)
      ..lineTo(size.width * 0.84, size.height * 0.26);

    final metric = path.computeMetrics().firstOrNull;
    if (metric == null) return;

    canvas.drawPath(
      progress >= 1.0 ? path : metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _CheckPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}

// =============================================================================
// -- CAMagnitudeOdometer --
// =============================================================================

/// A number/duration readout whose changed characters roll over instead of snapping.
///
/// works on the already formatted [String] (so `12h 34min` rolls just the `4`), characters are
/// matched right aligned. pass [magnitude] (the raw value behind the text) to get the roll direction
/// and speed right, otherwise it falls back to comparing the leading digits.
class CAMagnitudeOdometer extends StatefulWidget {
  final String value;

  /// raw value behind [value], only used to pick direction & duration.
  final num? magnitude;

  /// how big a [magnitude] delta has to be for the roll to reach [maxDuration].
  final num magnitudeRange;

  final TextStyle? style;
  final Color? increaseColor;
  final Color? decreaseColor;
  final Duration minDuration;
  final Duration maxDuration;
  final Duration staggerStep;

  const CAMagnitudeOdometer({
    super.key,
    required this.value,
    this.magnitude,
    this.magnitudeRange = 200,
    this.style,
    this.increaseColor,
    this.decreaseColor,
    this.minDuration = const Duration(milliseconds: 420),
    this.maxDuration = const Duration(milliseconds: 820),
    this.staggerStep = const Duration(milliseconds: 28),
  });

  @override
  State<CAMagnitudeOdometer> createState() => _CAMagnitudeOdometerState();
}

class _OdometerCell {
  final String? from;
  final String to;
  final double width;

  const _OdometerCell({required this.from, required this.to, required this.width});

  bool get changed => from != null && from != to;
}

class _CAMagnitudeOdometerState extends State<CAMagnitudeOdometer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  String _from = '';
  bool _increased = true;
  List<_OdometerCell>? _cells;
  double _cellHeight = 0;

  // -- cache keys
  String? _lastTo;
  TextStyle? _lastStyle;
  TextScaler? _lastScaler;

  bool get _settled => !_controller.isAnimating && _controller.isCompleted;

  @override
  void initState() {
    super.initState();
    _from = widget.value;
    _controller = AnimationController(vsync: this, value: 1.0, duration: widget.minDuration);
    _controller.addStatusListener(_onStatus);
  }

  @override
  void didUpdateWidget(covariant CAMagnitudeOdometer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) return;

    _from = oldWidget.value;
    _increased = _resolveIncreased(oldWidget);
    _cells = null;

    if (_animationsDisabled(context)) {
      _controller.value = 1.0;
    } else {
      _controller.duration = _resolveDuration(oldWidget);
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatus);
    _controller.dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    // -- back to a plain [Text] once done.
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _cells = null);
    }
  }

  bool _resolveIncreased(CAMagnitudeOdometer old) {
    final newMagnitude = widget.magnitude;
    final oldMagnitude = old.magnitude;
    if (newMagnitude != null && oldMagnitude != null) return newMagnitude >= oldMagnitude;
    return (_leadingNumber(widget.value) ?? 0) >= (_leadingNumber(old.value) ?? 0);
  }

  Duration _resolveDuration(CAMagnitudeOdometer old) {
    final newMagnitude = widget.magnitude;
    final oldMagnitude = old.magnitude;
    double t = 0.35;
    if (newMagnitude != null && oldMagnitude != null && widget.magnitudeRange > 0) {
      t = ((newMagnitude - oldMagnitude).abs() / widget.magnitudeRange).clamp(0.0, 1.0).toDouble();
    }
    final min = widget.minDuration.inMilliseconds;
    final max = widget.maxDuration.inMilliseconds;
    return Duration(milliseconds: (min + (max - min) * t).round());
  }

  static double? _leadingNumber(String text) {
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (code >= 0x30 && code <= 0x39) {
        buffer.writeCharCode(code);
      } else if (buffer.isNotEmpty) {
        break;
      }
    }
    return buffer.isEmpty ? null : double.tryParse(buffer.toString());
  }

  void _prepare(TextStyle style, TextDirection direction, TextScaler scaler) {
    if (_cells != null && _lastTo == widget.value && _lastStyle == style && _lastScaler == scaler) return;
    _lastTo = widget.value;
    _lastStyle = style;
    _lastScaler = scaler;

    final to = widget.value;
    final from = _from;
    final count = math.max(to.length, from.length);

    final painter = TextPainter(textDirection: direction, textScaler: scaler);
    painter.text = TextSpan(text: to.isEmpty ? '0' : to, style: style);
    painter.layout();
    _cellHeight = painter.height;

    final cells = <_OdometerCell>[];
    for (int i = 0; i < count; i++) {
      // -- right aligned, so `9h 59min` -> `10h 0min` doesn't roll every single character.
      final toIndex = to.length - count + i;
      final fromIndex = from.length - count + i;
      final toChar = toIndex >= 0 ? to[toIndex] : '';
      final fromChar = fromIndex >= 0 ? from[fromIndex] : null;

      double width = 0;
      final measured = toChar.isEmpty ? fromChar : toChar;
      if (measured != null && measured.isNotEmpty) {
        painter.text = TextSpan(text: measured, style: style);
        painter.layout();
        width = painter.width;
      }
      cells.add(_OdometerCell(from: fromChar, to: toChar, width: width));
    }
    painter.dispose();
    _cells = cells;
  }

  @override
  Widget build(BuildContext context) {
    final widgetStyle = widget.style;
    final resolved = widgetStyle == null || widgetStyle.inherit ? DefaultTextStyle.of(context).style.merge(widgetStyle) : widgetStyle;
    // -- tabular figures keep the digits from jittering while rolling.
    final style = resolved.fontFeatures == null ? resolved.copyWith(fontFeatures: const [FontFeature.tabularFigures()]) : resolved;

    if (_settled || _animationsDisabled(context)) {
      return Text(widget.value, style: style);
    }

    _prepare(style, Directionality.of(context), MediaQuery.textScalerOf(context));
    final cells = _cells!;
    if (cells.isEmpty) return Text(widget.value, style: style);

    final theme = Theme.of(context);
    final neutral = style.color ?? theme.textTheme.bodyLarge?.color ?? theme.colorScheme.onSurface;
    final directionColor = _increased ? (widget.increaseColor ?? theme.colorScheme.primary) : (widget.decreaseColor ?? theme.colorScheme.error);

    final staggerMs = widget.staggerStep.inMilliseconds;
    final rollMs = math.max(1, (_controller.duration?.inMilliseconds ?? 1) - staggerMs * (cells.length - 1));

    return RepaintBoundary(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < cells.length; i++)
            _OdometerCellWidget(
              cell: cells[i],
              animation: _controller,
              // -- rightmost rolls first, like a real odometer.
              startMs: (cells.length - 1 - i) * staggerMs,
              rollMs: rollMs,
              height: _cellHeight,
              increased: _increased,
              neutralColor: neutral,
              directionColor: directionColor,
              style: style,
            ),
        ],
      ),
    );
  }
}

class _OdometerCellWidget extends StatelessWidget {
  final _OdometerCell cell;
  final Animation<double> animation;
  final int startMs;
  final int rollMs;
  final double height;
  final bool increased;
  final Color neutralColor;
  final Color directionColor;
  final TextStyle style;

  const _OdometerCellWidget({
    required this.cell,
    required this.animation,
    required this.startMs,
    required this.rollMs,
    required this.height,
    required this.increased,
    required this.neutralColor,
    required this.directionColor,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (!cell.changed) {
      return SizedBox(
        width: cell.width,
        height: height,
        child: Center(child: Text(cell.to, style: style)),
      );
    }

    final totalMs = startMs + rollMs;
    return SizedBox(
      width: cell.width,
      height: height,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final t = (((animation.value * totalMs) - startMs) / rollMs).clamp(0.0, 1.0);
            final eased = Curves.easeOutCubic.transform(t);
            final sign = increased ? -1.0 : 1.0;
            // -- peaks mid roll then comes back to the normal color, no second controller needed.
            final color = Color.lerp(neutralColor, directionColor, math.sin(t * math.pi) * 0.85)!;
            final digitStyle = style.copyWith(color: color);

            return Stack(
              children: [
                if (cell.from != null)
                  Transform.translate(
                    offset: Offset(0, sign * height * eased),
                    child: Center(child: Text(cell.from!, style: digitStyle)),
                  ),
                Transform.translate(
                  offset: Offset(0, sign * height * (eased - 1)),
                  child: Center(child: Text(cell.to, style: digitStyle)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// =============================================================================
// -- CAMagneticConstellationGrid --
// =============================================================================

/// A link between two items of a [CAMagneticConstellationGrid], by index.
class CAConstellationEdge {
  final int a;
  final int b;

  /// `0..1`, how strongly the two are related. drives the line opacity.
  final double weight;

  const CAConstellationEdge(this.a, this.b, {this.weight = 1.0});
}

/// A grid whose tiles drift towards the pointer and stay wired to the ones they relate to.
///
/// [edges] are real relations, not proximity, so the lines actually mean something. long links
/// fade out with distance so the canvas doesn't turn into a mesh.
class CAMagneticConstellationGrid extends StatefulWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final List<CAConstellationEdge> edges;
  final double tileExtent;
  final double spacing;
  final double pullRadius;
  final double maxPull;

  /// links longer than this are not drawn at all.
  final double maxLinkDistance;
  final Color? lineColor;
  final Duration smoothingTau;

  const CAMagneticConstellationGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.edges = const [],
    this.tileExtent = 76.0,
    this.spacing = 12.0,
    this.pullRadius = 130.0,
    this.maxPull = 14.0,
    this.maxLinkDistance = 320.0,
    this.lineColor,
    this.smoothingTau = const Duration(milliseconds: 90),
  });

  @override
  State<CAMagneticConstellationGrid> createState() => _CAMagneticConstellationGridState();
}

class _CAMagneticConstellationGridState extends State<CAMagneticConstellationGrid> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _notifier = _TickNotifier();

  Duration _lastTick = Duration.zero;
  late List<Offset> _pull;
  late List<Offset> _target;
  List<Offset> _centers = const [];
  Offset? _pointer;

  /// index of the tile the pointer is closest to, its links get highlighted.
  int _focused = -1;

  static const _settleEpsilon = 0.05;

  @override
  void initState() {
    super.initState();
    _pull = List.filled(widget.itemCount, Offset.zero);
    _target = List.filled(widget.itemCount, Offset.zero);
    _ticker = createTicker(_onTick);
  }

  @override
  void didUpdateWidget(covariant CAMagneticConstellationGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemCount != widget.itemCount) {
      _pull = List.filled(widget.itemCount, Offset.zero);
      _target = List.filled(widget.itemCount, Offset.zero);
      _pointer = null;
      _focused = -1;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _notifier.dispose();
    super.dispose();
  }

  void _ensureTicking() {
    if (!_ticker.isTicking) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) _lastTick = elapsed;
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt <= 0) return;

    final tau = widget.smoothingTau.inMicroseconds / 1e6;
    bool settled = true;
    for (int i = 0; i < _pull.length; i++) {
      _pull[i] = _dampOffset(_pull[i], _target[i], tau, dt);
      if (settled && (_pull[i] - _target[i]).distance >= _settleEpsilon) settled = false;
    }

    _notifier.tick();

    if (settled && _pointer == null) {
      for (int i = 0; i < _pull.length; i++) {
        _pull[i] = Offset.zero;
      }
      _notifier.tick();
      _ticker.stop();
    }
  }

  void _updateTargets(Offset? local) {
    _pointer = local;
    if (local == null || _animationsDisabled(context)) {
      _focused = -1;
      for (int i = 0; i < _target.length; i++) {
        _target[i] = Offset.zero;
      }
    } else {
      double closest = double.infinity;
      int focused = -1;
      for (int i = 0; i < _target.length && i < _centers.length; i++) {
        final delta = local - _centers[i];
        final dist = delta.distance;
        if (dist < closest) {
          closest = dist;
          focused = i;
        }
        if (dist < widget.pullRadius && dist > 0.01) {
          final pull = (1 - dist / widget.pullRadius) * widget.maxPull;
          _target[i] = delta * (pull / dist);
        } else {
          _target[i] = Offset.zero;
        }
      }
      _focused = closest <= widget.pullRadius ? focused : -1;
    }
    _ensureTicking();
  }

  @override
  Widget build(BuildContext context) {
    final lineColor = widget.lineColor ?? Theme.of(context).colorScheme.primary;
    final step = widget.tileExtent + widget.spacing;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = math.max(1, ((constraints.maxWidth + widget.spacing) / step).floor());
        final rows = (widget.itemCount / columns).ceil();
        final gridWidth = columns * step - widget.spacing;
        final gridHeight = rows * step - widget.spacing;

        _centers = List.generate(
          widget.itemCount,
          (i) => Offset((i % columns) * step + widget.tileExtent / 2, (i ~/ columns) * step + widget.tileExtent / 2),
          growable: false,
        );

        final extraLeftMargin = ((context.width - (step * columns) - (widget.spacing * (columns - 1))) / 2).withMinimum(0);
        return MouseRegion(
          onExit: (_) => _updateTargets(null),
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerHover: (e) => _updateTargets(e.localPosition),
            onPointerDown: (e) => _updateTargets(e.localPosition),
            onPointerMove: (e) => _updateTargets(e.localPosition),
            onPointerUp: (_) => _updateTargets(null),
            onPointerCancel: (_) => _updateTargets(null),
            child: RepaintBoundary(
              child: SizedBox(
                width: gridWidth,
                height: gridHeight,
                child: Padding(
                  padding: EdgeInsets.only(left: extraLeftMargin),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _ConstellationLinesPainter(
                            repaint: _notifier,
                            centers: _centers,
                            pull: _pull,
                            edges: widget.edges,
                            focusedIndex: () => _focused,
                            maxDistance: widget.maxLinkDistance,
                            lineColor: lineColor,
                          ),
                        ),
                      ),
                      for (int i = 0; i < widget.itemCount; i++)
                        Positioned(
                          left: (i % columns) * step,
                          top: (i ~/ columns) * step,
                          width: widget.tileExtent,
                          height: widget.tileExtent,
                          child: _ConstellationTile(
                            notifier: _notifier,
                            pull: _pull,
                            index: i,
                            maxPull: widget.maxPull,
                            child: widget.itemBuilder(context, i),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ConstellationTile extends StatelessWidget {
  final _TickNotifier notifier;
  final List<Offset> pull;
  final int index;
  final double maxPull;
  final Widget child;

  const _ConstellationTile({
    required this.notifier,
    required this.pull,
    required this.index,
    required this.maxPull,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: notifier,
      child: child,
      builder: (context, child) {
        final offset = index < pull.length ? pull[index] : Offset.zero;
        if (offset == Offset.zero) return child!;
        final scale = 1.0 + 0.05 * (offset.distance / maxPull).clamp(0.0, 1.0);
        return Transform.translate(
          offset: offset,
          child: Transform.scale(scale: scale, child: child),
        );
      },
    );
  }
}

class _ConstellationLinesPainter extends CustomPainter {
  final List<Offset> centers;
  final List<Offset> pull;
  final List<CAConstellationEdge> edges;
  final int Function() focusedIndex;
  final double maxDistance;
  final Color lineColor;

  _ConstellationLinesPainter({
    required Listenable repaint,
    required this.centers,
    required this.pull,
    required this.edges,
    required this.focusedIndex,
    required this.maxDistance,
    required this.lineColor,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    if (edges.isEmpty || centers.isEmpty) return;

    final focused = focusedIndex();
    final corePaint = Paint()..strokeWidth = 1.4;
    final glowPaint = Paint()..strokeWidth = 3.2;

    for (final edge in edges) {
      if (edge.a >= centers.length || edge.b >= centers.length) continue;
      final c1 = centers[edge.a] + (edge.a < pull.length ? pull[edge.a] : Offset.zero);
      final c2 = centers[edge.b] + (edge.b < pull.length ? pull[edge.b] : Offset.zero);

      final dist = (c1 - c2).distance;
      if (dist > maxDistance) continue;

      final isFocused = focused == edge.a || focused == edge.b;
      // -- close & strong links read stronger, far ones fade out instead of cutting off.
      final falloff = (1 - dist / maxDistance).clamp(0.0, 1.0);
      final strength = (edge.weight.clamp(0.0, 1.0) * (0.35 + 0.65 * falloff)) * (isFocused ? 1.0 : 0.6);

      glowPaint.color = lineColor.withValues(alpha: strength * 0.18);
      canvas.drawLine(c1, c2, glowPaint);
      corePaint.color = lineColor.withValues(alpha: strength * 0.7);
      canvas.drawLine(c1, c2, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConstellationLinesPainter oldDelegate) {
    return oldDelegate.centers != centers || oldDelegate.edges != edges || oldDelegate.lineColor != lineColor || oldDelegate.maxDistance != maxDistance;
  }
}

// =============================================================================
// -- CAEmptyStateCTA --
// =============================================================================

enum _ParticleState { drift, converging, exploding }

class _FlowParticle {
  double x, y, vx, vy, targetX, targetY, edgeFade;
  _ParticleState state;

  _FlowParticle({
    required this.x,
    required this.y,
    required this.targetX,
    required this.targetY,
  }) : vx = 0,
       vy = 0,
       edgeFade = 1.0,
       state = _ParticleState.drift;
}

/// An empty state whose dust drifts around, gathers behind the call to action when you reach for it,
/// and bursts when you press it.
class CAEmptyStateCTA extends StatefulWidget {
  final Widget? header;
  final Widget child;
  final int particleCount;
  final double height;
  final Color? particleColor;

  const CAEmptyStateCTA({
    super.key,
    this.header,
    required this.child,
    this.particleCount = 80,
    this.height = 320.0,
    this.particleColor,
  });

  @override
  State<CAEmptyStateCTA> createState() => _CAEmptyStateCTAState();
}

class _CAEmptyStateCTAState extends State<CAEmptyStateCTA> with SingleTickerProviderStateMixin {
  final _rng = math.Random(7);
  final _notifier = _TickNotifier();
  final _particles = <_FlowParticle>[];

  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  double _elapsed = 0;

  Size _size = Size.zero;
  bool _gathered = false;
  bool _exploded = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _notifier.dispose();
    super.dispose();
  }

  void _ensureTicking() {
    if (!_ticker.isTicking) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  void _seed(Size size) {
    if (size.isEmpty) return;
    _size = size;
    final cx = size.width / 2, cy = size.height / 2;
    final hR = math.min(150.0, 0.34 * size.width).clamp(40.0, 150.0) + 24.0;
    const vR = 26.0 + 24.0;

    _particles.clear();
    for (int i = 0; i < widget.particleCount; i++) {
      final angle = (i / widget.particleCount) * 2 * math.pi;
      final inner = (i % 3 == 0) ? 0.7 : 1.0;
      _particles.add(
        _FlowParticle(
          x: _rng.nextDouble() * size.width,
          y: _rng.nextDouble() * size.height,
          targetX: cx + math.cos(angle) * hR * inner,
          targetY: cy + math.sin(angle) * vR * inner,
        ),
      );
    }
    _ensureTicking();
  }

  void _setGathered(bool gathered) {
    if (_exploded || _gathered == gathered || _animationsDisabled(context)) return;
    _gathered = gathered;
    final state = gathered ? _ParticleState.converging : _ParticleState.drift;
    for (final p in _particles) {
      p.state = state;
    }
    _ensureTicking();
  }

  void _onTap() {
    VibratorController.light();
    if (!_animationsDisabled(context)) {
      _exploded = true;
      for (final p in _particles) {
        p.state = _ParticleState.exploding;
        final a = _rng.nextDouble() * 2 * math.pi;
        final speed = 4 + 6 * _rng.nextDouble();
        p.vx = math.cos(a) * speed;
        p.vy = math.sin(a) * speed - 5;
      }
      _ensureTicking();
      Future.delayed(const Duration(milliseconds: 1100), () {
        if (!mounted) return;
        _exploded = false;
        _gathered = false;
        _seed(_size);
      });
    }
  }

  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) _lastTick = elapsed;
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt <= 0) return;
    _elapsed += dt;

    final w = _size.width, h = _size.height;
    if (w <= 0 || h <= 0) return;

    // -- normalized against 60fps so the motion doesn't depend on the refresh rate.
    final f = (dt * 60).clamp(0.0, 3.0);

    for (final p in _particles) {
      switch (p.state) {
        case _ParticleState.drift:
          final angle = _perlinHash(0.005 * p.x, 0.005 * p.y + 0.1 * _elapsed) * math.pi * 4;
          p.vx += 0.04 * math.cos(angle) * f;
          p.vy += 0.04 * math.sin(angle) * f;
          p.vx *= math.pow(0.95, f).toDouble();
          p.vy *= math.pow(0.95, f).toDouble();
          p.x += p.vx * f;
          p.y += p.vy * f;

          const edgeZone = 20.0;
          p.edgeFade = math.min(math.min(p.x, w - p.x).clamp(0.0, edgeZone), math.min(p.y, h - p.y).clamp(0.0, edgeZone)) / edgeZone;

          if (p.x < -10) p.x = w + 10;
          if (p.x > w + 10) p.x = -10;
          if (p.y < -10) p.y = h + 10;
          if (p.y > h + 10) p.y = -10;

        case _ParticleState.converging:
          p.vx += 0.08 * (p.targetX - p.x) * f;
          p.vy += 0.08 * (p.targetY - p.y) * f;
          p.vx *= math.pow(0.72, f).toDouble();
          p.vy *= math.pow(0.72, f).toDouble();
          p.x += p.vx * f;
          p.y += p.vy * f;
          p.edgeFade = 1.0;

        case _ParticleState.exploding:
          p.x += p.vx * f;
          p.y += p.vy * f;
          p.vx *= math.pow(0.96, f).toDouble();
          p.vy *= math.pow(0.96, f).toDouble();
          p.vy += 0.2 * f;
          p.edgeFade = 1.0;
      }
    }

    if (_exploded) _particles.removeWhere((p) => p.x < -50 || p.x > w + 50 || p.y > h + 50);

    _notifier.tick();
    if (_particles.isEmpty) _ticker.stop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduce = _animationsDisabled(context);
    final accent = widget.particleColor ?? theme.colorScheme.primary;

    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          if (!reduce && (size != _size || _particles.isEmpty && !_exploded)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && size != _size) _seed(size);
            });
          }

          return MouseRegion(
            onEnter: (_) => _setGathered(true),
            onExit: (_) => _setGathered(false),
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => _setGathered(true),
              onPointerUp: (_) => _setGathered(false),
              onPointerCancel: (_) => _setGathered(false),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (!reduce)
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _FlowParticlePainter(
                            repaint: _notifier,
                            particles: _particles,
                            accent: accent,
                          ),
                        ),
                      ),
                    ),

                  if (widget.header != null)
                    Positioned(
                      top: 64.0,
                      child: widget.header!,
                    ),

                  // -- force full width
                  SizedBox(
                    width: size.width,
                  ),

                  _CAEmptyStateCTAButton(
                    accent: accent,
                    onTap: _onTap,
                    child: widget.child,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CAEmptyStateCTAButton extends StatelessWidget {
  final Widget child;
  final Color accent;
  final VoidCallback onTap;

  const _CAEmptyStateCTAButton({
    required this.child,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget child = this.child;
    if (kEnableFancyAnimations) {
      child = CAMagneticButton(
        radius: 90.0,
        pullFactor: 0.08,
        child: child,
      );
    }
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: child,
      ),
    );
  }
}

class _FlowParticlePainter extends CustomPainter {
  final List<_FlowParticle> particles;
  final Color accent;

  _FlowParticlePainter({required Listenable repaint, required this.particles, required this.accent}) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in particles) {
      final gathered = p.state != _ParticleState.drift;
      double opacity = switch (p.state) {
        _ParticleState.exploding => math.max(0.0, 1 - 0.02 * math.sqrt(p.vx * p.vx + p.vy * p.vy)),
        _ParticleState.converging => 0.9,
        _ParticleState.drift => 0.35,
      };
      opacity *= p.edgeFade;
      if (opacity <= 0.01) continue;

      paint.color = gathered ? accent.withValues(alpha: (0.5 * opacity).clamp(0.0, 1.0)) : accent.withValues(alpha: (0.3 * opacity).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(p.x, p.y), gathered ? 1.8 : 3.0, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FlowParticlePainter oldDelegate) => oldDelegate.particles != particles || oldDelegate.accent != accent;
}

// =============================================================================
// -- CAKineticPathReveal --
// =============================================================================

class KineticDataPoint {
  final double x;
  final double y;
  final String? label;

  const KineticDataPoint({required this.x, required this.y, this.label});
}

/// A trend line that draws itself, throwing sparks off the head, popping a marker on every data
/// point as the head reaches it.
///
/// takes plain data points and does the smoothing & normalization itself, so it can be dropped
/// straight onto any stats screen.
class CAKineticPathReveal extends StatefulWidget {
  final List<KineticDataPoint> points;
  final double height;
  final EdgeInsets padding;
  final Color? lineColor;
  final Color? ghostColor;
  final Color? labelColor;
  final Duration duration;
  final bool showSparks;
  final bool showMarkers;

  /// forced y range, defaults to the min/max of [points].
  final double? minY;
  final double? maxY;

  const CAKineticPathReveal({
    super.key,
    required this.points,
    this.height = 160.0,
    this.padding = const EdgeInsets.fromLTRB(10.0, 16.0, 10.0, 16.0),
    this.lineColor,
    this.ghostColor,
    this.labelColor,
    this.duration = const Duration(milliseconds: 2200),
    this.showSparks = true,
    this.showMarkers = true,
    this.minY,
    this.maxY,
  });

  @override
  State<CAKineticPathReveal> createState() => _CAKineticPathRevealState();
}

class _SparkParticle {
  double x, y, vx, vy, life;
  _SparkParticle({required this.x, required this.y, required this.vx, required this.vy}) : life = 1.0;
}

class _CAKineticPathRevealState extends State<CAKineticPathReveal> with TickerProviderStateMixin {
  final _rng = math.Random(11);
  final _sparks = <_SparkParticle>[];
  final _sparkNotifier = _TickNotifier();

  late final AnimationController _draw;
  late final Ticker _sparkTicker;

  Duration _lastSparkTick = Duration.zero;
  Offset _lastHead = Offset.zero;
  bool _started = false;

  Path? _path;
  PathMetric? _metric;
  List<Offset> _markerPositions = const [];
  List<double> _markerFractions = const [];

  Size _lastSize = Size.zero;
  List<KineticDataPoint>? _lastPoints;

  @override
  void initState() {
    super.initState();
    _draw = AnimationController(vsync: this, duration: widget.duration);
    _sparkTicker = createTicker(_onSparkTick);
    _draw.addListener(_onDrawTick);
    _draw.addStatusListener(_onDrawStatus);
  }

  @override
  void didUpdateWidget(covariant CAKineticPathReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points) {
      _path = null;
      _started = false;
      _draw.value = 0.0;
    }
  }

  @override
  void dispose() {
    _draw.removeListener(_onDrawTick);
    _draw.removeStatusListener(_onDrawStatus);
    _draw.dispose();
    _sparkTicker.dispose();
    _sparkNotifier.dispose();
    super.dispose();
  }

  void _onDrawStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _lastHead = Offset.zero;
  }

  void _onDrawTick() {
    if (!widget.showSparks || _animationsDisabled(context)) return;
    final metric = _metric;
    if (metric == null) return;
    final progress = _draw.value;
    if (progress <= 0.01 || progress >= 0.99) return;

    final head = metric.getTangentForOffset(metric.length * progress)?.position;
    if (head == null) return;
    if (_lastHead != Offset.zero) {
      final delta = head - _lastHead;
      final speed = delta.distance;
      if (speed > 0.5) {
        final count = speed.floor().clamp(1, 3);
        for (int i = 0; i < count && _sparks.length < 60; i++) {
          _sparks.add(
            _SparkParticle(
              x: head.dx + (_rng.nextDouble() - 0.5) * 4,
              y: head.dy + (_rng.nextDouble() - 0.5) * 4,
              vx: -(0.3 * delta.dx) + (_rng.nextDouble() - 0.5) * 1.5,
              vy: -(0.3 * delta.dy) + (_rng.nextDouble() - 0.5) * 1.5 - 0.3,
            ),
          );
        }
        if (!_sparkTicker.isTicking) {
          _lastSparkTick = Duration.zero;
          _sparkTicker.start();
        }
      }
    }
    _lastHead = head;
  }

  void _onSparkTick(Duration elapsed) {
    if (_lastSparkTick == Duration.zero) _lastSparkTick = elapsed;
    final dt = (elapsed - _lastSparkTick).inMicroseconds / 1e6;
    _lastSparkTick = elapsed;
    if (dt <= 0) return;

    final f = (dt * 60).clamp(0.0, 3.0);
    for (int i = _sparks.length - 1; i >= 0; i--) {
      final s = _sparks[i];
      s.x += s.vx * f;
      s.y += s.vy * f;
      s.vy += 0.04 * f;
      s.vx *= math.pow(0.98, f).toDouble();
      s.vy *= math.pow(0.98, f).toDouble();
      s.life -= 0.022 * f;
      if (s.life <= 0) _sparks.removeAt(i);
    }
    _sparkNotifier.tick();
    if (_sparks.isEmpty) _sparkTicker.stop();
  }

  void _prepare(Size size) {
    if (_path != null && _lastSize == size && identical(_lastPoints, widget.points)) return;
    _lastSize = size;
    _lastPoints = widget.points;

    final points = widget.points;
    if (points.length < 2 || size.isEmpty) {
      _path = Path();
      _metric = null;
      _markerPositions = const [];
      _markerFractions = const [];
      return;
    }

    final left = widget.padding.left;
    final top = widget.padding.top;
    final innerW = math.max(1.0, size.width - widget.padding.horizontal);
    final innerH = math.max(1.0, size.height - widget.padding.vertical);

    double minX = points.first.x, maxX = points.first.x;
    double minY = widget.minY ?? points.first.y, maxY = widget.maxY ?? points.first.y;
    for (final p in points) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (widget.minY == null && p.y < minY) minY = p.y;
      if (widget.maxY == null && p.y > maxY) maxY = p.y;
    }
    final spanX = maxX - minX == 0 ? 1.0 : maxX - minX;
    final spanY = maxY - minY == 0 ? 1.0 : maxY - minY;

    final resolved = List<Offset>.generate(
      points.length,
      (i) => Offset(left + (points[i].x - minX) / spanX * innerW, top + innerH - (points[i].y - minY) / spanY * innerH),
      growable: false,
    );

    // -- catmull-rom through the points, converted to cubics.
    final path = Path()..moveTo(resolved.first.dx, resolved.first.dy);
    for (int i = 0; i < resolved.length - 1; i++) {
      final p0 = resolved[i == 0 ? 0 : i - 1];
      final p1 = resolved[i];
      final p2 = resolved[i + 1];
      final p3 = resolved[i + 2 >= resolved.length ? resolved.length - 1 : i + 2];
      final c1 = p1 + (p2 - p0) / 6;
      final c2 = p2 - (p3 - p1) / 6;
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }

    _path = path;
    _metric = path.computeMetrics().firstOrNull;

    // -- where along the line each point sits, so its marker pops right as the head goes past.
    final cumulative = List<double>.filled(resolved.length, 0);
    for (int i = 1; i < resolved.length; i++) {
      cumulative[i] = cumulative[i - 1] + (resolved[i] - resolved[i - 1]).distance;
    }
    final total = cumulative.last == 0 ? 1.0 : cumulative.last;
    _markerPositions = resolved;
    _markerFractions = List<double>.generate(resolved.length, (i) => cumulative[i] / total, growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lineColor = widget.lineColor ?? theme.colorScheme.primary;
    final ghostColor = widget.ghostColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.16);
    final labelColor = widget.labelColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.7);
    final reduce = _animationsDisabled(context);

    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, widget.height);
          _prepare(size);

          if (!_started && _path != null && _metric != null) {
            _started = true;
            if (reduce) {
              _draw.value = 1.0;
            } else {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _draw.value == 0.0) _draw.forward();
              });
            }
          }

          return RepaintBoundary(
            child: Stack(
              children: [
                CustomPaint(
                  size: size,
                  painter: _KineticPathPainter(
                    repaint: _draw,
                    path: _path ?? Path(),
                    metric: _metric,
                    animation: _draw,
                    markerPositions: widget.showMarkers ? _markerPositions : const [],
                    markerFractions: widget.showMarkers ? _markerFractions : const [],
                    labels: widget.points,
                    lineColor: lineColor,
                    ghostColor: ghostColor,
                    labelColor: labelColor,
                  ),
                ),
                if (widget.showSparks && !reduce)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _SparkParticlePainter(repaint: _sparkNotifier, sparks: _sparks, color: lineColor),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SparkParticlePainter extends CustomPainter {
  final List<_SparkParticle> sparks;
  final Color color;

  _SparkParticlePainter({required Listenable repaint, required this.sparks, required this.color}) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final s in sparks) {
      paint.color = color.withValues(alpha: (0.9 * s.life).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(s.x, s.y), (1.5 * s.life).clamp(0.5, 3.0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkParticlePainter oldDelegate) => oldDelegate.sparks != sparks || oldDelegate.color != color;
}

class _KineticPathPainter extends CustomPainter {
  final Path path;
  final PathMetric? metric;
  final Animation<double> animation;
  final List<Offset> markerPositions;
  final List<double> markerFractions;
  final List<KineticDataPoint> labels;
  final Color lineColor;
  final Color ghostColor;
  final Color labelColor;

  _KineticPathPainter({
    required Listenable repaint,
    required this.path,
    required this.metric,
    required this.animation,
    required this.markerPositions,
    required this.markerFractions,
    required this.labels,
    required this.lineColor,
    required this.ghostColor,
    required this.labelColor,
  }) : super(repaint: repaint);

  /// how long after the head passes a marker it takes to pop in, as a fraction of the whole draw.
  static const _markerPop = 0.12;

  @override
  void paint(Canvas canvas, Size size) {
    final metric = this.metric;
    if (metric == null) return;
    final progress = animation.value.clamp(0.0, 1.0);

    _drawDashed(
      canvas,
      metric,
      Paint()
        ..color = ghostColor
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    if (progress > 0) {
      canvas.drawPath(
        progress >= 1.0 ? path : metric.extractPath(0, metric.length * progress),
        Paint()
          ..color = lineColor
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    for (int i = 0; i < markerPositions.length; i++) {
      final popT = ((progress - markerFractions[i]) / _markerPop).clamp(0.0, 1.0);
      if (popT <= 0) continue;

      final eased = Curves.easeOutBack.transform(popT);
      final opacity = popT.clamp(0.0, 1.0);
      final pos = markerPositions[i];

      canvas.drawCircle(
        pos,
        8 * eased,
        Paint()
          ..color = lineColor.withValues(alpha: 0.45 * opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
      canvas.drawCircle(pos, 3.5 * eased, Paint()..color = lineColor.withValues(alpha: opacity));

      final label = i < labels.length ? labels[i].label : null;
      if (label != null && popT >= 1.0) {
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(fontSize: 11.0, color: labelColor),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, pos + const Offset(10, -6));
        tp.dispose();
      }
    }
  }

  void _drawDashed(Canvas canvas, PathMetric metric, Paint paint, {double dash = 4, double gap = 8}) {
    final total = metric.length;
    double offset = 0;
    while (offset < total) {
      final end = math.min(offset + dash, total);
      canvas.drawPath(metric.extractPath(offset, end), paint);
      offset = end + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _KineticPathPainter oldDelegate) {
    return oldDelegate.path != path || oldDelegate.lineColor != lineColor || oldDelegate.ghostColor != ghostColor || oldDelegate.markerPositions != markerPositions;
  }
}
