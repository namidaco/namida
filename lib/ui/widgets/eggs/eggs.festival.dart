part of 'eggs.dart';

class _Festival extends StatefulWidget {
  final Animation<double> progress;
  final EggUnlockable unlockable;

  const _Festival({required this.progress, required this.unlockable});

  @override
  State<_Festival> createState() => _FestivalState();
}

class _FestivalState extends State<_Festival> {
  late final _icon = _layoutIcon(widget.unlockable.toIcon());
  final _confetti = _Confetti(seed: 11);
  final _fireworks = _Fireworks();

  static TextPainter _layoutIcon(IconData icon) {
    final glyph = String.fromCharCode(icon.codePoint);
    final style = TextStyle(
      fontFamily: icon.fontFamily,
      package: icon.fontPackage,
      fontSize: 28.0,
      height: 1.0,
      color: Colors.white,
    );
    final painter = TextPainter(
      text: TextSpan(text: glyph, style: style),
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    return painter;
  }

  @override
  void dispose() {
    _icon.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eggColor = context.theme.colorScheme.primary;
    return RepaintBoundary(
      child: CustomPaint(
        painter: _FestivalPainter(
          progress: widget.progress,
          eggColor: eggColor,
          icon: _icon,
          confetti: _confetti,
          fireworks: _fireworks,
        ),
      ),
    );
  }
}

class _FestiveFrame extends StatelessWidget {
  const _FestiveFrame();

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;
    return CustomPaint(
      painter: _FestiveFramePainter(
        clock: NamidaFloatClock.instance,
        radius: 24.0.multipliedRadius,
        accent: colorScheme.primary,
        ink: colorScheme.onSurface,
      ),
    );
  }
}

class _Glittering extends StatelessWidget {
  final Widget child;

  const _Glittering({required this.child});

  @override
  Widget build(BuildContext context) {
    final primary = context.theme.colorScheme.primary;
    final glitterColor = Color.alphaBlend(Colors.white.withOpacityExt(0.6), primary);
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _GlitterPainter(
                  clock: NamidaFloatClock.instance,
                  color: glitterColor,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BeatingHeart extends StatelessWidget {
  const _BeatingHeart();

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: const Size(17.0, 17.0),
        painter: _HeartPainter(
          clock: NamidaFloatClock.instance,
        ),
      ),
    );
  }
}

class _FestivalPainter extends CustomPainter {
  final Animation<double> progress;
  final Color eggColor;
  final TextPainter icon;
  final _Confetti confetti;
  final _Fireworks fireworks;

  _FestivalPainter({
    required this.progress,
    required this.eggColor,
    required this.icon,
    required this.confetti,
    required this.fireworks,
  }) : super(repaint: progress);

  static const _kEggSize = Size(58.0, 76.0);
  static const _kShakes = 3;
  static const _kRaysCount = 12;
  static const _kRayHalfAngle = 0.09;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t <= 0.0 || t >= 1.0) return;
    final center = size.center(Offset.zero);
    final outro = _Finale.phaseOf(t, _Finale.outroBegin, 1.0);
    final presence = 1.0 - Curves.easeIn.transform(outro);
    _paintScrim(canvas, size, t, presence);
    fireworks.paint(canvas, size, t);
    _paintGlow(canvas, center, t, presence);
    _paintRays(canvas, center, t, presence);
    _paintShockwave(canvas, center, t);
    _paintEgg(canvas, center, t);
    _paintIcon(canvas, center, t, presence);
    confetti.paint(canvas, center, t);
  }

  void _paintScrim(Canvas canvas, Size size, double t, double presence) {
    final fadeIn = _Finale.phaseOf(t, 0.0, 0.08);
    final paint = Paint()..color = Colors.black.withOpacityExt(0.35 * fadeIn * presence);
    canvas.drawRect(Offset.zero & size, paint);
  }

  void _paintGlow(Canvas canvas, Offset center, double t, double presence) {
    final glowPhase = _Finale.phaseOf(t, _Finale.crackBegin, _Finale.hatchEnd);
    if (glowPhase <= 0.0) return;
    final radius = 90.0 * Curves.easeOutCubic.transform(glowPhase);
    final glowRect = Rect.fromCircle(center: center, radius: radius);
    final glow = RadialGradient(
      colors: [
        eggColor.withOpacityExt(0.6 * presence),
        eggColor.withOpacityExt(0.0),
      ],
    );
    final paint = Paint()..shader = glow.createShader(glowRect);
    canvas.drawCircle(center, radius, paint);
  }

  void _paintRays(Canvas canvas, Offset center, double t, double presence) {
    final raysPhase = _Finale.phaseOf(t, _Finale.crackBegin, _Finale.hatchEnd);
    if (raysPhase <= 0.0) return;
    final length = 140.0 * Curves.easeOutCubic.transform(raysPhase);
    final rotation = t * math.pi * 0.6;
    final rays = Path();
    for (int i = 0; i < _kRaysCount; i++) {
      final angle = i * (2 * math.pi / _kRaysCount) + rotation;
      final fromAngle = angle - _kRayHalfAngle;
      final toAngle = angle + _kRayHalfAngle;
      rays
        ..moveTo(center.dx, center.dy)
        ..lineTo(center.dx + math.cos(fromAngle) * length, center.dy + math.sin(fromAngle) * length)
        ..lineTo(center.dx + math.cos(toAngle) * length, center.dy + math.sin(toAngle) * length)
        ..close();
    }
    final raysRect = Rect.fromCircle(center: center, radius: length);
    final fade = RadialGradient(
      colors: [
        Colors.white.withOpacityExt(0.35 * presence),
        Colors.white.withOpacityExt(0.0),
      ],
    );
    final paint = Paint()..shader = fade.createShader(raysRect);
    canvas.drawPath(rays, paint);
  }

  void _paintShockwave(Canvas canvas, Offset center, double t) {
    final wave = _Finale.phaseOf(t, _Finale.crackBegin, _Finale.crackBegin + 0.18);
    if (wave <= 0.0 || wave >= 1.0) return;
    final fade = 1.0 - wave;
    final radius = 24.0 + 110.0 * Curves.easeOutCubic.transform(wave);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0 * fade
      ..color = Colors.white.withOpacityExt(0.8 * fade);
    canvas.drawCircle(center, radius, paint);
  }

  void _paintEgg(Canvas canvas, Offset center, double t) {
    final crack = _Finale.phaseOf(t, _Finale.crackBegin, _Finale.crackEnd);
    if (crack >= 1.0) return;
    final pop = _Finale.phaseOf(t, 0.0, _Finale.popEnd);
    final scale = Curves.elasticOut.transform(pop);
    final shake = _Finale.phaseOf(t, _Finale.shakeBegin, _Finale.shakeEnd);
    final isShaking = shake > 0.0 && shake < 1.0;
    final amplitude = isShaking ? 0.06 + 0.2 * shake : 0.0;
    final angle = math.sin(shake * _kShakes * 2 * math.pi) * amplitude;
    const eggSize = _kEggSize;
    canvas.save();
    canvas.translate(center.dx, center.dy + eggSize.height / 2);
    canvas.rotate(angle);
    canvas.scale(scale);
    canvas.translate(-eggSize.width / 2, -eggSize.height);
    if (crack == 0.0) {
      final shell = _EggBrush.shellOf(eggSize);
      _EggBrush.paintShell(canvas, eggSize, shell, eggColor, isFilled: true, opacity: 1.0);
    } else {
      _EggBrush.paintCracked(canvas, eggSize, eggColor, crack);
    }
    canvas.restore();
  }

  void _paintIcon(Canvas canvas, Offset center, double t, double presence) {
    final rise = _Finale.phaseOf(t, _Finale.hatchBegin, _Finale.hatchEnd);
    if (rise <= 0.0) return;
    final scale = Curves.elasticOut.transform(rise) * presence;
    final lift = 16.0 * Curves.easeOutCubic.transform(rise);
    final iconCenter = center.translate(0.0, -lift);
    final discPaint = Paint()..color = eggColor;
    canvas.drawCircle(iconCenter, 27.0 * scale, discPaint);
    final iconSize = icon.size;
    canvas.save();
    canvas.translate(iconCenter.dx, iconCenter.dy);
    canvas.scale(scale);
    icon.paint(canvas, Offset(-iconSize.width / 2, -iconSize.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FestivalPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.eggColor != eggColor || oldDelegate.icon != icon;
  }
}

class _Confetti {
  static const _kCount = 64;
  static const _kGravity = 900.0;
  static const _kDrag = 2.2;
  static const _kFlightSeconds = 1.8;
  static const _kColors = [0xFF5A5A, 0xFFD24D, 0x5AD1FF, 0x8CFF7A, 0xFF7AE0, 0xFFFFFF];

  final _velocityX = Float32List(_kCount);
  final _velocityY = Float32List(_kCount);
  final _spin = Float32List(_kCount);
  final _halfWidth = Float32List(_kCount);
  final _halfHeight = Float32List(_kCount);
  final _rgb = Int32List(_kCount);
  final _positions = Float32List(_kCount * 8);
  final _colors = Int32List(_kCount * 4);
  final _indices = Uint16List(_kCount * 6);
  final _paint = Paint()..color = Colors.white;

  _Confetti({required int seed}) {
    final random = math.Random(seed);
    for (int i = 0; i < _kCount; i++) {
      final angle = -math.pi / 2 + (random.nextDouble() - 0.5) * math.pi * 0.95;
      final speed = 420.0 + random.nextDouble() * 560.0;
      _velocityX[i] = math.cos(angle) * speed;
      _velocityY[i] = math.sin(angle) * speed;
      _spin[i] = (random.nextDouble() - 0.5) * 16.0;
      _halfWidth[i] = 2.2 + random.nextDouble() * 2.0;
      _halfHeight[i] = 3.6 + random.nextDouble() * 3.2;
      _rgb[i] = _kColors[random.nextInt(_kColors.length)];
      final vertex = i * 4;
      final index = i * 6;
      _indices[index] = vertex;
      _indices[index + 1] = vertex + 1;
      _indices[index + 2] = vertex + 2;
      _indices[index + 3] = vertex;
      _indices[index + 4] = vertex + 2;
      _indices[index + 5] = vertex + 3;
    }
  }

  void paint(Canvas canvas, Offset origin, double t) {
    final phase = _Finale.phaseOf(t, _Finale.crackBegin, 1.0);
    if (phase <= 0.0 || phase >= 1.0) return;
    final seconds = phase * _kFlightSeconds;
    final decay = (1.0 - math.exp(-_kDrag * seconds)) / _kDrag;
    const terminalSpeed = _kGravity / _kDrag;
    final fade = 1.0 - Curves.easeInQuad.transform(phase);
    final alpha = (fade * 255).round() << 24;
    for (int i = 0; i < _kCount; i++) {
      final x = origin.dx + _velocityX[i] * decay;
      final y = origin.dy + terminalSpeed * seconds + (_velocityY[i] - terminalSpeed) * decay;
      final angle = _spin[i] * seconds;
      final cos = math.cos(angle);
      final sin = math.sin(angle);
      final tumble = math.cos(angle * 1.7).abs();
      final halfWidth = _halfWidth[i] * (0.25 + 0.75 * tumble);
      final halfHeight = _halfHeight[i];
      final ax = halfWidth * cos;
      final ay = halfWidth * sin;
      final bx = -halfHeight * sin;
      final by = halfHeight * cos;
      final p = i * 8;
      _positions[p] = x - ax - bx;
      _positions[p + 1] = y - ay - by;
      _positions[p + 2] = x + ax - bx;
      _positions[p + 3] = y + ay - by;
      _positions[p + 4] = x + ax + bx;
      _positions[p + 5] = y + ay + by;
      _positions[p + 6] = x - ax + bx;
      _positions[p + 7] = y - ay + by;
      final color = alpha | _rgb[i];
      final c = i * 4;
      _colors[c] = color;
      _colors[c + 1] = color;
      _colors[c + 2] = color;
      _colors[c + 3] = color;
    }
    final vertices = ui.Vertices.raw(ui.VertexMode.triangles, _positions, colors: _colors, indices: _indices);
    canvas.drawVertices(vertices, BlendMode.modulate, _paint);
    vertices.dispose();
  }
}

class _Fireworks {
  static const _kSparksCount = 30;
  static const _kTrailLag = 0.12;
  static const _kCenters = [Offset(0.2, 0.2), Offset(0.8, 0.15), Offset(0.26, 0.8), Offset(0.78, 0.74)];
  static const _kColors = [Color(0xFFFF5A5A), Color(0xFFFFD24D), Color(0xFF5AD1FF), Color(0xFFFF7AE0)];
  static final _directions = _directionsOf(_kSparksCount);
  static final _speeds = _speedsOf(_kSparksCount);

  final _streaks = Float32List(_kSparksCount * 4);
  final _heads = Float32List(_kSparksCount * 2);
  final _glowPaint = Paint()..strokeCap = StrokeCap.round;
  final _streakPaint = Paint()..strokeCap = StrokeCap.round;
  final _headPaint = Paint()..strokeCap = StrokeCap.round;
  final _flashPaint = Paint();

  static Float32List _speedsOf(int count) {
    final random = math.Random(5);
    final speeds = Float32List(count);
    for (int i = 0; i < count; i++) {
      speeds[i] = 0.72 + random.nextDouble() * 0.28;
    }
    return speeds;
  }

  void paint(Canvas canvas, Size size, double t) {
    final reach = size.shortestSide * 0.22;
    const starts = _Finale.fireworkStarts;
    for (int b = 0; b < starts.length; b++) {
      final start = starts[b];
      final phase = _Finale.phaseOf(t, start, start + _Finale.fireworkLength);
      if (phase <= 0.0 || phase >= 1.0) continue;
      final fraction = _kCenters[b];
      final center = Offset(size.width * fraction.dx, size.height * fraction.dy);
      _paintBurst(canvas, center, phase, reach, _kColors[b]);
    }
  }

  void _paintBurst(Canvas canvas, Offset center, double phase, double reach, Color color) {
    final trailPhase = (phase - _kTrailLag).withMinimum(0.0);
    final spread = reach * Curves.easeOutCubic.transform(phase);
    final trailSpread = reach * Curves.easeOutCubic.transform(trailPhase);
    final sag = reach * 0.3 * phase * phase;
    final trailSag = reach * 0.3 * trailPhase * trailPhase;
    for (int i = 0; i < _kSparksCount; i++) {
      final direction = _directions[i];
      final speed = _speeds[i];
      final headX = center.dx + direction.dx * spread * speed;
      final headY = center.dy + direction.dy * spread * speed + sag;
      final s = i * 4;
      _streaks[s] = center.dx + direction.dx * trailSpread * speed;
      _streaks[s + 1] = center.dy + direction.dy * trailSpread * speed + trailSag;
      _streaks[s + 2] = headX;
      _streaks[s + 3] = headY;
      final h = i * 2;
      _heads[h] = headX;
      _heads[h + 1] = headY;
    }
    final fade = 1.0 - Curves.easeInQuad.transform(phase);
    final shrink = 1.0 - phase * 0.5;
    final coreColor = Color.alphaBlend(Colors.white.withOpacityExt(0.55), color);
    _glowPaint
      ..color = color.withOpacityExt(0.28 * fade)
      ..strokeWidth = 7.0 * shrink;
    _streakPaint
      ..color = color.withOpacityExt(0.9 * fade)
      ..strokeWidth = 2.0 * shrink;
    _headPaint
      ..color = coreColor.withOpacityExt(fade)
      ..strokeWidth = 3.4 * shrink;
    canvas.drawRawPoints(ui.PointMode.lines, _streaks, _glowPaint);
    canvas.drawRawPoints(ui.PointMode.lines, _streaks, _streakPaint);
    canvas.drawRawPoints(ui.PointMode.points, _heads, _headPaint);
    final flash = 1.0 - _Finale.phaseOf(phase, 0.0, 0.15);
    if (flash <= 0.0) return;
    _flashPaint.color = coreColor.withOpacityExt(0.9 * flash);
    canvas.drawCircle(center, 3.0 + 9.0 * flash, _flashPaint);
  }
}

/// timeline of the crack finale, as fractions of the whole animation.
abstract class _Finale {
  static const popEnd = 0.2;
  static const shakeBegin = 0.08;
  static const shakeEnd = 0.34;
  static const crackBegin = 0.34;
  static const crackEnd = 0.56;
  static const hatchBegin = 0.4;
  static const hatchEnd = 0.64;
  static const outroBegin = 0.86;
  static const fireworkStarts = [0.46, 0.56, 0.66, 0.74];
  static const fireworkLength = 0.24;

  static double phaseOf(double t, double begin, double end) {
    final phase = (t - begin) / (end - begin);
    return phase.withMinimum(0.0).withMaximum(1.0);
  }
}
