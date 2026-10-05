part of 'custom_widgets.dart';

// by claude

const _kCheckStart = Offset(0.3083, 0.5167);
const _kCheckCorner = Offset(0.4375, 0.6417);
const _kCheckEnd = Offset(0.6917, 0.375);
const _kCheckStroke = 0.1;
const _kMorphDuration = Duration(milliseconds: 600);

// rewritten by claude, new one tints or outlines the tile when active and supports a tristate check
class ListTileWithCheckMark extends StatelessWidget {
  final bool active;
  final RxBase<bool>? activeRx;

  /// non-null switches to a tristate check.
  final bool? halfActive;
  final void Function()? onTap;
  final String? title;
  final String subtitle;
  final IconData? icon;
  final Color? tileColor;
  final Widget? titleWidget;
  final Widget? leading;
  final double? iconSize;
  final bool dense;
  final bool expanded;
  final double borderRadius;
  final bool outlined;
  final bool burst;

  const ListTileWithCheckMark({
    super.key,
    this.active = false,
    this.activeRx,
    this.halfActive,
    this.onTap,
    this.title,
    this.subtitle = '',
    this.icon = Broken.arrange_circle,
    this.tileColor,
    this.titleWidget,
    this.leading,
    this.iconSize,
    this.dense = false,
    this.expanded = true,
    this.borderRadius = 14.0,
    this.outlined = false,
    this.burst = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = context.theme.textTheme;
    final titleWidgetFinal = Padding(
      padding: EdgeInsets.symmetric(horizontal: dense ? 10.0 : 14.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleWidget ??
              Text(
                title ?? lang.reverseOrder,
                style: textTheme.displayMedium,
              ),
          if (subtitle != '')
            Text(
              subtitle,
              style: textTheme.displaySmall,
            ),
        ],
      ),
    );
    final activeRx = this.activeRx;
    if (activeRx != null) {
      return ObxO(
        rx: activeRx,
        builder: (context, active) => _CheckTileFrame(
          tile: this,
          active: active,
          title: titleWidgetFinal,
        ),
      );
    }
    return _CheckTileFrame(
      tile: this,
      active: active,
      title: titleWidgetFinal,
    );
  }
}

class NamidaCheckMark extends StatefulWidget {
  final double size;
  final bool active;
  final bool burst;

  const NamidaCheckMark({
    super.key,
    required this.size,
    required this.active,
    this.burst = false,
  });

  @override
  State<NamidaCheckMark> createState() => _NamidaCheckMarkState();
}

class _NamidaCheckMarkState extends State<NamidaCheckMark> with SingleTickerProviderStateMixin {
  _DiscCheckAnimation? _animation;

  @override
  void didUpdateWidget(covariant NamidaCheckMark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;
    final animation = _animation ??= _DiscCheckAnimation(this, wasActive: oldWidget.active);
    if (widget.active) {
      animation.controller.forward();
    } else {
      animation.controller.reverse();
    }
  }

  @override
  void dispose() {
    _animation?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;
    final color = colorScheme.secondary;
    final ringColor = color.withOpacityExt(0.3);
    return CustomPaint(
      size: Size.square(widget.size),
      painter: _DiscCheckPainter(
        animation: _animation,
        active: widget.active,
        burst: widget.burst,
        color: color,
        checkColor: colorScheme.onSecondary,
        ringColor: ringColor,
      ),
    );
  }
}

class NamidaTristateCheckMark extends StatefulWidget {
  final double size;
  final bool active;
  final bool halfActive;

  const NamidaTristateCheckMark({
    super.key,
    required this.size,
    required this.active,
    required this.halfActive,
  });

  @override
  State<NamidaTristateCheckMark> createState() => _NamidaTristateCheckMarkState();
}

class _NamidaTristateCheckMarkState extends State<NamidaTristateCheckMark> with SingleTickerProviderStateMixin {
  static final _bouncySpring = SpringSimulation(const SpringDescription(mass: 1.0, stiffness: 520.0, damping: 24.0), 0.0, 1.0, 0.0);
  static final _settleSpring = SpringSimulation(const SpringDescription(mass: 1.0, stiffness: 520.0, damping: 46.0), 0.0, 1.0, 0.0);

  AnimationController? _controller;
  late _MorphFrame _from = _targetFrame();
  late _MorphFrame _to = _from;
  SpringSimulation _spring = _bouncySpring;

  _MorphFrame _targetFrame() {
    if (widget.halfActive) return _MorphFrame.half;
    if (widget.active) return _MorphFrame.on;
    return _MorphFrame.off;
  }

  @override
  void didUpdateWidget(covariant NamidaTristateCheckMark oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = _targetFrame();
    if (identical(target, _to)) return;
    final controller = _controller ??= AnimationController(vsync: this, duration: _kMorphDuration);
    final progress = _MorphFrame.springProgress(_spring, controller.value);
    _from = _MorphFrame.lerp(_from, _to, progress);
    _to = target;
    _spring = identical(target, _MorphFrame.off) ? _settleSpring : _bouncySpring;
    controller.forward(from: 0.0);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;
    final color = colorScheme.secondary;
    final boxColor = color.withOpacityExt(0.3);
    return CustomPaint(
      size: Size.square(widget.size),
      painter: _TristateCheckPainter(
        controller: _controller,
        from: _from,
        to: _to,
        spring: _spring,
        color: color,
        checkColor: colorScheme.onSecondary,
        boxColor: boxColor,
      ),
    );
  }
}

class _CheckTileFrame extends StatelessWidget {
  final ListTileWithCheckMark tile;
  final bool active;
  final Widget title;

  const _CheckTileFrame({
    required this.tile,
    required this.active,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colorScheme = theme.colorScheme;
    final halfActive = tile.halfActive;
    final isHalf = halfActive == true;
    final isSelected = active || isHalf;
    final tileAlpha = context.isDarkMode ? 5 : 20;
    final tileTint = colorScheme.onSurface.withAlpha(tileAlpha);
    final baseColor = tile.tileColor ?? Color.alphaBlend(tileTint, theme.cardTheme.color!);
    final inactiveColor = baseColor.withOpacityExt(0.65);
    final activeTint = colorScheme.secondary.withOpacityExt(tile.outlined ? 0.1 : 0.12);
    final activeColor = Color.alphaBlend(activeTint, baseColor);
    final halfTint = activeColor.withOpacityExt(0.45);
    final halfColor = Color.alphaBlend(halfTint, inactiveColor);
    final bgColor = isHalf
        ? halfColor
        : active
        ? activeColor
        : inactiveColor;
    final borderOpacity = isHalf
        ? 0.5
        : active
        ? 1.0
        : 0.0;
    final borderColor = colorScheme.secondary.withOpacityExt(borderOpacity);
    final decoration = tile.outlined
        ? BoxDecoration(
            border: Border.all(
              color: borderColor,
              width: 1.5,
            ),
          )
        : const BoxDecoration();
    final icon = tile.icon;
    final iconColor = isSelected ? colorScheme.secondary : IconTheme.of(context).color;
    Widget? leading = tile.leading;
    if (leading == null && icon != null) {
      leading = _CheckTileIcon(
        icon: icon,
        size: tile.iconSize,
        color: iconColor,
      );
    }
    final check = halfActive == null
        ? NamidaCheckMark(
            size: 20.0,
            active: active,
            burst: tile.burst,
          )
        : NamidaTristateCheckMark(
            size: 20.0,
            active: active,
            halfActive: halfActive,
          );
    return NamidaInkWell(
      animationDurationMS: 200,
      borderRadius: tile.borderRadius,
      bgColor: bgColor,
      decoration: decoration,
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      onTap: tile.onTap,
      child: Row(
        mainAxisSize: tile.expanded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          ?leading,
          tile.expanded
              ? Expanded(
                  child: title,
                )
              : Flexible(
                  child: title,
                ),
          check,
        ],
      ),
    );
  }
}

class _CheckTileIcon extends StatelessWidget {
  final IconData icon;
  final double? size;
  final Color? color;

  const _CheckTileIcon({
    required this.icon,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: color),
      duration: const Duration(milliseconds: 200),
      builder: (context, color, _) => Icon(
        icon,
        size: size,
        color: color,
      ),
    );
  }
}

class _DiscCheckPainter extends CustomPainter {
  static const _ringRadius = 0.379;
  static const _ringStroke = 0.075;
  static const _discRadius = 0.4167;
  static const _pulseStroke = 0.058;
  static const _pulseCurve = Cubic(0.2, 0.7, 0.3, 1.0);
  static final _burstDirections = List<Offset>.generate(
    8,
    (i) {
      final angle = (i * 45.0 + 22.5) * math.pi / 180.0;
      return Offset(math.sin(angle), -math.cos(angle));
    },
    growable: false,
  );
  static final _checkFirstLength = (_kCheckCorner - _kCheckStart).distance;
  static final _checkSecondLength = (_kCheckEnd - _kCheckCorner).distance;

  final _DiscCheckAnimation? animation;
  final bool active;
  final bool burst;
  final Color color;
  final Color checkColor;
  final Color ringColor;

  _DiscCheckPainter({
    required this.animation,
    required this.active,
    required this.burst,
    required this.color,
    required this.checkColor,
    required this.ringColor,
  }) : super(repaint: animation?.controller);

  @override
  void paint(Canvas canvas, Size size) {
    final animation = this.animation;
    final staticProgress = active ? 1.0 : 0.0;
    final disc = animation?.disc.value ?? staticProgress;
    final tick = animation?.tick.value ?? staticProgress;
    final side = size.shortestSide;
    final center = size.center(Offset.zero);
    final discRadius = side * _discRadius;

    if (disc < 1.0) {
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = side * _ringStroke
        ..color = ringColor;
      canvas.drawCircle(center, side * _ringRadius, ringPaint);
    }
    if (disc > 0.0) {
      final discPaint = Paint()..color = color;
      canvas.drawCircle(center, discRadius * disc, discPaint);
    }
    if (animation != null && animation.controller.status == AnimationStatus.forward) {
      final pulse = _pulseCurve.transform(animation.controller.value);
      _paintPulse(canvas, center, side, discRadius, pulse);
      if (burst) _paintBurst(canvas, center, side, pulse);
    }
    if (tick > 0.0) _paintCheck(canvas, side, tick);
  }

  void _paintPulse(Canvas canvas, Offset center, double side, double discRadius, double pulse) {
    final opacity = 0.6 * (1.0 - pulse);
    final radius = discRadius * (1.0 + 0.75 * pulse);
    final pulsePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = side * _pulseStroke
      ..color = color.withOpacityExt(opacity);
    canvas.drawCircle(center, radius, pulsePaint);
  }

  void _paintBurst(Canvas canvas, Offset center, double side, double pulse) {
    final distance = side * (0.42 + 0.53 * pulse);
    final opacity = 1.0 - pulse;
    final shrink = 1.0 - 0.8 * pulse;
    final altOpacity = ringColor.a * opacity;
    final mainPaint = Paint()..color = color.withOpacityExt(opacity);
    final altPaint = Paint()..color = ringColor.withOpacityExt(altOpacity);
    final mainRadius = side * 0.055 * shrink;
    final altRadius = side * 0.04 * shrink;
    for (int i = 0; i < _burstDirections.length; i++) {
      final isMain = i.isEven;
      final particleCenter = center + _burstDirections[i] * distance;
      canvas.drawCircle(particleCenter, isMain ? mainRadius : altRadius, isMain ? mainPaint : altPaint);
    }
  }

  void _paintCheck(Canvas canvas, double side, double progress) {
    final start = _kCheckStart * side;
    final corner = _kCheckCorner * side;
    final end = _kCheckEnd * side;
    final drawn = progress * (_checkFirstLength + _checkSecondLength);
    final path = Path()..moveTo(start.dx, start.dy);
    if (drawn <= _checkFirstLength) {
      final point = start + (corner - start) * (drawn / _checkFirstLength);
      path.lineTo(point.dx, point.dy);
    } else {
      final point = corner + (end - corner) * ((drawn - _checkFirstLength) / _checkSecondLength);
      path
        ..lineTo(corner.dx, corner.dy)
        ..lineTo(point.dx, point.dy);
    }
    final checkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = side * _kCheckStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = checkColor;
    canvas.drawPath(path, checkPaint);
  }

  @override
  bool shouldRepaint(covariant _DiscCheckPainter oldDelegate) {
    return oldDelegate.animation != animation ||
        oldDelegate.active != active ||
        oldDelegate.burst != burst ||
        oldDelegate.color != color ||
        oldDelegate.checkColor != checkColor ||
        oldDelegate.ringColor != ringColor;
  }
}

class _TristateCheckPainter extends CustomPainter {
  static const _boxInset = 0.125;
  static const _boxRadius = 0.25;
  static const _boxStroke = 0.075;
  static const _popDurationMS = 340;

  final AnimationController? controller;
  final _MorphFrame from;
  final _MorphFrame to;
  final SpringSimulation spring;
  final Color color;
  final Color checkColor;
  final Color boxColor;

  _TristateCheckPainter({
    required this.controller,
    required this.from,
    required this.to,
    required this.spring,
    required this.color,
    required this.checkColor,
    required this.boxColor,
  }) : super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    final t = controller?.value ?? 1.0;
    final progress = _MorphFrame.springProgress(spring, t);
    final frame = _MorphFrame.lerp(from, to, progress);
    final side = size.shortestSide;
    final center = size.center(Offset.zero);
    final isPopping = !identical(to, _MorphFrame.off) && t < 1.0;
    final popProgress = t * _kMorphDuration.inMilliseconds / _popDurationMS;
    final scale = isPopping ? _popScale(popProgress) : 1.0;

    if (scale != 1.0) {
      canvas
        ..save()
        ..translate(center.dx, center.dy)
        ..scale(scale)
        ..translate(-center.dx, -center.dy);
    }

    final inset = side * _boxInset;
    final boxSide = side - inset * 2;
    final box = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, boxSide, boxSide),
      Radius.circular(side * _boxRadius),
    );
    final fill = frame.fill;
    if (fill > 0.0) {
      canvas.drawRRect(box, Paint()..color = color.withOpacityExt(fill));
    }
    final boxPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = side * _boxStroke
      ..color = Color.lerp(boxColor, color, fill)!;
    canvas.drawRRect(box, boxPaint);

    final line = frame.line;
    if (line > 0.0) {
      final start = frame.start * side;
      final corner = frame.corner * side;
      final end = frame.end * side;
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(corner.dx, corner.dy)
        ..lineTo(end.dx, end.dy);
      final linePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = side * _kCheckStroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = checkColor.withOpacityExt(line);
      canvas.drawPath(path, linePaint);
    }

    if (scale != 1.0) canvas.restore();
  }

  static double _popScale(double u) {
    if (u >= 1.0) return 1.0;
    if (u < 0.3) return lerpDouble(1.0, 0.84, Curves.easeOut.transform(u / 0.3))!;
    if (u < 0.65) return lerpDouble(0.84, 1.08, Curves.easeInOut.transform((u - 0.3) / 0.35))!;
    return lerpDouble(1.08, 1.0, Curves.easeInOut.transform((u - 0.65) / 0.35))!;
  }

  @override
  bool shouldRepaint(covariant _TristateCheckPainter oldDelegate) {
    return oldDelegate.controller != controller ||
        oldDelegate.from != from ||
        oldDelegate.to != to ||
        oldDelegate.spring != spring ||
        oldDelegate.color != color ||
        oldDelegate.checkColor != checkColor ||
        oldDelegate.boxColor != boxColor;
  }
}

class _DiscCheckAnimation {
  final AnimationController controller;
  late final disc = CurvedAnimation(
    parent: controller,
    curve: const Interval(0.0, 0.57, curve: Cubic(0.34, 1.56, 0.64, 1.0)),
    reverseCurve: Curves.easeIn,
  );
  late final tick = CurvedAnimation(
    parent: controller,
    curve: const Interval(0.21, 0.68, curve: Curves.easeInOutCubic),
    reverseCurve: const Interval(0.4, 1.0),
  );

  _DiscCheckAnimation(TickerProvider vsync, {required bool wasActive})
    : controller = AnimationController(
        vsync: vsync,
        value: wasActive ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 560),
        reverseDuration: const Duration(milliseconds: 180),
      );

  void dispose() {
    disc.dispose();
    tick.dispose();
    controller.dispose();
  }
}

class _MorphFrame {
  final Offset start;
  final Offset corner;
  final Offset end;
  final double fill;
  final double line;

  const _MorphFrame({
    required this.start,
    required this.corner,
    required this.end,
    required this.fill,
    required this.line,
  });

  static const off = _MorphFrame(start: Offset(0.5, 0.5), corner: Offset(0.5, 0.5), end: Offset(0.5, 0.5), fill: 0.0, line: 0.0);
  static const half = _MorphFrame(start: Offset(0.3125, 0.5), corner: Offset(0.5, 0.5), end: Offset(0.6875, 0.5), fill: 1.0, line: 1.0);
  static const on = _MorphFrame(start: _kCheckStart, corner: _kCheckCorner, end: _kCheckEnd, fill: 1.0, line: 1.0);

  static double springProgress(SpringSimulation spring, double t) {
    if (t >= 1.0) return 1.0;
    final seconds = t * _kMorphDuration.inMilliseconds / 1000.0;
    return spring.x(seconds);
  }

  static _MorphFrame lerp(_MorphFrame a, _MorphFrame b, double t) {
    final clamped = t.withMinimum(0.0).withMaximum(1.0);
    return _MorphFrame(
      start: a.start + (b.start - a.start) * t,
      corner: a.corner + (b.corner - a.corner) * t,
      end: a.end + (b.end - a.end) * t,
      fill: lerpDouble(a.fill, b.fill, clamped)!,
      line: lerpDouble(a.line, b.line, clamped)!,
    );
  }
}
