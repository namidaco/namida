part of 'eggs.dart';

class _EggPainter extends CustomPainter {
  final Color color;
  final bool isFilled;
  final bool isRainbow;
  final Animation<double>? shine;

  _EggPainter({required this.color, required this.isFilled, this.isRainbow = false, this.shine}) : super(repaint: shine);

  @override
  void paint(Canvas canvas, Size size) {
    final shell = _EggBrush.shellOf(size);
    _EggBrush.paintShell(canvas, size, shell, color, isFilled: isFilled, isRainbow: isRainbow, opacity: 1.0);
    final shine = this.shine;
    if (shine != null) _EggBrush.paintShine(canvas, size, shell, shine.value);
  }

  @override
  bool shouldRepaint(_EggPainter oldDelegate) => oldDelegate.color != color || oldDelegate.isFilled != isFilled || oldDelegate.isRainbow != isRainbow || oldDelegate.shine != shine;
}

abstract class _EggBrush {
  static const _kRainbowColors = [
    Color(0xFFFF6B6B), Color(0xFFFFB347), Color(0xFFFFE156), //
    Color(0xFF6BE585), Color(0xFF5EB8FF), Color(0xFFB08CFF), //
  ];
  static const _kRainbowGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: _kRainbowColors,
  );

  static Path shellOf(Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    return Path()
      ..moveTo(cx, 0.0)
      ..cubicTo(cx + w * 0.36, 0.0, w, h * 0.36, w, h * 0.62)
      ..cubicTo(w, h * 0.86, cx + w * 0.28, h, cx, h)
      ..cubicTo(cx - w * 0.28, h, 0.0, h * 0.86, 0.0, h * 0.62)
      ..cubicTo(0.0, h * 0.36, cx - w * 0.36, 0.0, cx, 0.0)
      ..close();
  }

  static void paintShell(Canvas canvas, Size size, Path shell, Color color, {required bool isFilled, bool isRainbow = false, required double opacity}) {
    final bounds = Offset.zero & size;
    if (!isFilled) {
      final outline = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3;
      if (isRainbow) {
        outline.shader = _rainbowShaderOf(bounds, 0.45 * opacity);
      } else {
        outline.color = color.withOpacityExt(0.45 * opacity);
      }
      canvas.drawPath(shell, outline);
      return;
    }
    final fill = Paint();
    if (isRainbow) {
      fill.shader = _rainbowShaderOf(bounds, opacity);
    } else {
      final lightColor = Color.alphaBlend(Colors.white.withOpacityExt(0.45), color);
      final darkColor = Color.alphaBlend(Colors.black.withOpacityExt(0.25), color);
      final gradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          lightColor.withOpacityExt(opacity),
          color.withOpacityExt(opacity),
          darkColor.withOpacityExt(opacity),
        ],
      );
      fill.shader = gradient.createShader(bounds);
    }
    canvas.drawPath(shell, fill);
    final highlight = Paint()..color = Colors.white.withOpacityExt(0.4 * opacity);
    final highlightRect = Rect.fromLTWH(size.width * 0.24, size.height * 0.18, size.width * 0.18, size.height * 0.24);
    canvas.drawOval(highlightRect, highlight);
  }

  static Shader _rainbowShaderOf(Rect bounds, double opacity) {
    if (opacity >= 1.0) return _kRainbowGradient.createShader(bounds);
    final colors = [
      for (final color in _kRainbowColors) color.withOpacityExt(opacity),
    ];
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors,
    );
    return gradient.createShader(bounds);
  }

  static void paintShine(Canvas canvas, Size size, Path shell, double progress) {
    if (progress <= 0.0 || progress >= 1.0) return;
    final w = size.width;
    final h = size.height;
    final bandX = -0.6 * w + progress * 2.2 * w;
    final band = Rect.fromCenter(center: Offset.zero, width: w * 0.4, height: h * 2.0);
    const gradient = LinearGradient(
      colors: [Color(0x00FFFFFF), Color(0xB3FFFFFF), Color(0x00FFFFFF)],
    );
    final paint = Paint()..shader = gradient.createShader(band);
    canvas.save();
    canvas.clipPath(shell);
    canvas.translate(bandX, h / 2);
    canvas.rotate(0.45);
    canvas.drawRect(band, paint);
    canvas.restore();
  }

  static void paintCracked(Canvas canvas, Size size, Color color, double progress) {
    final shell = shellOf(size);
    final opacity = 1.0 - Curves.easeInQuad.transform(progress);
    final lift = Curves.easeOutCubic.transform(progress);
    final hinge = Offset(size.width * 0.15, size.height * 0.52);
    final topLiftY = hinge.dy - size.height * 0.2 * lift;
    final bottomDropY = size.height * 0.06 * lift;

    canvas.save();
    canvas.translate(hinge.dx, topLiftY);
    canvas.rotate(-0.6 * lift);
    canvas.translate(-hinge.dx, -hinge.dy);
    canvas.clipPath(_halfOf(size, isTop: true));
    paintShell(canvas, size, shell, color, isFilled: true, opacity: opacity);
    canvas.restore();

    canvas.save();
    canvas.translate(0.0, bottomDropY);
    canvas.clipPath(_halfOf(size, isTop: false));
    paintShell(canvas, size, shell, color, isFilled: true, opacity: opacity);
    canvas.restore();
  }

  static Path _halfOf(Size size, {required bool isTop}) {
    final w = size.width;
    final h = size.height;
    final y = h * 0.52;
    final zig = h * 0.07;
    final edgeY = isTop ? -h : h * 2;
    return Path()
      ..moveTo(-w, edgeY)
      ..lineTo(-w, y)
      ..lineTo(0.0, y)
      ..lineTo(w * 0.2, y - zig)
      ..lineTo(w * 0.4, y + zig)
      ..lineTo(w * 0.6, y - zig)
      ..lineTo(w * 0.8, y + zig)
      ..lineTo(w, y)
      ..lineTo(w * 2, y)
      ..lineTo(w * 2, edgeY)
      ..close();
  }
}

class _BurstPainter extends CustomPainter {
  final Animation<double> progress;
  final Color color;

  _BurstPainter({required this.progress, required this.color}) : super(repaint: progress);

  static const _kSparksCount = 10;
  static const _kReach = 1.1;
  static final _directions = _directionsOf(_kSparksCount);

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t <= 0.0 || t >= 1.0) return;
    final center = size.center(Offset.zero);
    final spread = Curves.easeOutCubic.transform(t) * size.longestSide * _kReach;
    final fade = 1.0 - t;
    final sparkPaint = Paint()..color = color.withOpacityExt(fade);
    final glintPaint = Paint()..color = Colors.white.withOpacityExt(fade * 0.8);
    final radiusFactor = 1.0 - t * 0.5;
    for (int i = 0; i < _kSparksCount; i++) {
      final isSpark = i.isEven;
      final distance = isSpark ? spread : spread * 0.7;
      final position = center + _directions[i] * distance;
      final radius = (isSpark ? 2.0 : 1.4) * radiusFactor;
      canvas.drawCircle(position, radius, isSpark ? sparkPaint : glintPaint);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.color != color;
}

class _GlintPainter extends CustomPainter {
  final NamidaFloatClock clock;

  _GlintPainter({required this.clock}) : super(repaint: clock);

  static const _kPeriodSeconds = 2.6;
  static const _kFlashSeconds = 0.45;

  @override
  void paint(Canvas canvas, Size size) {
    final phase = clock.seconds % _kPeriodSeconds;
    if (phase >= _kFlashSeconds) return;
    final intensity = math.sin(phase / _kFlashSeconds * math.pi);
    final center = Offset(size.width * 0.82, size.height * 0.16);
    final arm = size.width * 0.42 * intensity;
    final paint = Paint()
      ..color = Colors.white.withOpacityExt(0.9 * intensity)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center.translate(-arm, 0.0), center.translate(arm, 0.0), paint);
    canvas.drawLine(center.translate(0.0, -arm), center.translate(0.0, arm), paint);
  }

  @override
  bool shouldRepaint(_GlintPainter oldDelegate) => oldDelegate.clock != clock;
}

class _FestiveFramePainter extends CustomPainter {
  final NamidaFloatClock clock;
  final double radius;
  final Color accent;
  final Color ink;

  _FestiveFramePainter({
    required this.clock,
    required this.radius,
    required this.accent,
    required this.ink,
  }) : super(repaint: clock);

  static const _kTurnSeconds = 12.0;
  static const _kLineWidth = 2.2;
  static const _kGlowWidth = 12.0;
  static const _kFlagsCount = 8;
  static const _kFlagHalfWidth = 6.0;
  static const _kFlagHeight = 13.0;
  static const _kPartyColors = [Color(0xFFFF5A5A), Color(0xFFFFD24D), Color(0xFF5AD1FF), Color(0xFFFF7AE0)];
  static const _kFlagColors = [0xFF5A5A, 0xFFD24D, 0x5AD1FF, 0x8CFF7A, 0xFF7AE0];
  static const _kHatHeight = 40.0;
  static const _kHatHalfWidth = 15.0;
  static const _kHatTilt = 0.38;
  static const _kHatStripeColor = Color(0xE6FFD24D);
  static const _kHatTrimColor = Color(0xF2FFFFFF);
  static const _kPompomColor = Color(0xFFFFE27A);

  final _flagPositions = Float32List(_kFlagsCount * 6);
  final _flagColors = Int32List(_kFlagsCount * 3);
  final _flagsPaint = Paint()..color = Colors.white;

  @override
  void paint(Canvas canvas, Size size) {
    final seconds = clock.seconds;
    _paintBorder(canvas, size, seconds);
    _paintBunting(canvas, size, seconds);
    _paintHat(canvas, size, seconds);
  }

  List<Color> _borderColorsOf(double alpha) {
    return [
      accent.withOpacityExt(alpha),
      for (final color in _kPartyColors) color.withOpacityExt(alpha),
      accent.withOpacityExt(alpha),
    ];
  }

  // -- the card clips its edges, so only the inner half of each stroke shows
  void _paintBorder(Canvas canvas, Size size, double seconds) {
    final bounds = Offset.zero & size;
    final rotation = GradientRotation(seconds / _kTurnSeconds * 2 * math.pi);
    final glowGradient = SweepGradient(transform: rotation, colors: _borderColorsOf(0.14));
    final lineGradient = SweepGradient(transform: rotation, colors: _borderColorsOf(0.85));
    final edge = RRect.fromRectAndRadius(bounds, Radius.circular(radius));
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _kGlowWidth
      ..shader = glowGradient.createShader(bounds);
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _kLineWidth * 2
      ..shader = lineGradient.createShader(bounds);
    canvas.drawRRect(edge, glowPaint);
    canvas.drawRRect(edge, linePaint);
  }

  void _paintBunting(Canvas canvas, Size size, double seconds) {
    final w = size.width;
    final start = Offset(w * 0.08, 3.0);
    final end = Offset(w * 0.8, 3.0);
    final control = Offset(w * 0.44, 22.0);
    final string = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
    final stringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = ink.withOpacityExt(0.3);
    canvas.drawPath(string, stringPaint);

    for (int i = 0; i < _kFlagsCount; i++) {
      final t = (i + 1) / (_kFlagsCount + 1);
      final u = 1.0 - t;
      final anchorX = u * u * start.dx + 2 * u * t * control.dx + t * t * end.dx;
      final anchorY = u * u * start.dy + 2 * u * t * control.dy + t * t * end.dy;
      final sway = math.sin(seconds * 1.8 + i * 0.9) * 0.14;
      final cos = math.cos(sway);
      final sin = math.sin(sway);
      final p = i * 6;
      _flagPositions[p] = anchorX - _kFlagHalfWidth * cos;
      _flagPositions[p + 1] = anchorY - _kFlagHalfWidth * sin;
      _flagPositions[p + 2] = anchorX + _kFlagHalfWidth * cos;
      _flagPositions[p + 3] = anchorY + _kFlagHalfWidth * sin;
      _flagPositions[p + 4] = anchorX - _kFlagHeight * sin;
      _flagPositions[p + 5] = anchorY + _kFlagHeight * cos;
      final color = 0xD9000000 | _kFlagColors[i % _kFlagColors.length];
      final c = i * 3;
      _flagColors[c] = color;
      _flagColors[c + 1] = color;
      _flagColors[c + 2] = color;
    }
    final vertices = ui.Vertices.raw(ui.VertexMode.triangles, _flagPositions, colors: _flagColors);
    canvas.drawVertices(vertices, BlendMode.modulate, _flagsPaint);
    vertices.dispose();
  }

  void _paintHat(Canvas canvas, Size size, double seconds) {
    const h = _kHatHeight;
    const b = _kHatHalfWidth;
    final wobble = math.sin(seconds * 1.3) * 0.05;
    final cone = Path()
      ..moveTo(-b, 0.0)
      ..lineTo(0.0, -h)
      ..lineTo(b, 0.0)
      ..quadraticBezierTo(0.0, 5.0, -b, 0.0)
      ..close();
    final coneBounds = Rect.fromLTRB(-b, -h, b, 5.0);
    final lightAccent = Color.alphaBlend(Colors.white.withOpacityExt(0.35), accent);
    final darkAccent = Color.alphaBlend(Colors.black.withOpacityExt(0.25), accent);
    final coneGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [lightAccent, accent, darkAccent],
    );
    final conePaint = Paint()..shader = coneGradient.createShader(coneBounds);
    final stripePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6
      ..color = _kHatStripeColor;
    final trimPaint = Paint()..color = _kHatTrimColor;
    final pompomPaint = Paint()..color = _kPompomColor;
    final shinePaint = Paint()..color = Colors.white.withOpacityExt(0.7);

    canvas.save();
    canvas.translate(size.width - 34.0, 50.0);
    canvas.rotate(_kHatTilt + wobble);
    canvas.drawPath(cone, conePaint);
    canvas.save();
    canvas.clipPath(cone);
    for (int i = 0; i < 3; i++) {
      final y = -h * (0.22 + 0.27 * i);
      canvas.drawLine(Offset(-b - 4.0, y + 5.0), Offset(b + 4.0, y - 5.0), stripePaint);
    }
    canvas.restore();
    canvas.drawOval(Rect.fromCenter(center: const Offset(0.0, 1.0), width: b * 2 + 4.0, height: 6.5), trimPaint);
    canvas.drawCircle(const Offset(0.0, -h), 4.6, pompomPaint);
    canvas.drawCircle(const Offset(-1.4, -h - 1.4), 1.4, shinePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FestiveFramePainter oldDelegate) {
    return oldDelegate.clock != clock || oldDelegate.radius != radius || oldDelegate.accent != accent || oldDelegate.ink != ink;
  }
}

class _HeartPainter extends CustomPainter {
  final NamidaFloatClock clock;

  _HeartPainter({required this.clock}) : super(repaint: clock);

  static const _kBeatSeconds = 1.5;
  static const _kPulseSeconds = 0.18;
  static const _kSecondBeatDelay = 0.24;
  static const _kLightColor = Color(0xFFFF9EBB);
  static const _kColor = Color(0xFFFF4F7B);
  static const _kDarkColor = Color(0xFFD81B4F);

  static double _pulseOf(double phase, double at) {
    final local = (phase - at) / _kPulseSeconds;
    if (local <= 0.0 || local >= 1.0) return 0.0;
    return math.sin(local * math.pi);
  }

  static Path _heartOf(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w * 0.5, h * 0.28)
      ..cubicTo(w * 0.5, h * 0.12, w * 0.38, h * 0.04, w * 0.26, h * 0.04)
      ..cubicTo(w * 0.1, h * 0.04, 0.0, h * 0.17, 0.0, h * 0.33)
      ..cubicTo(0.0, h * 0.58, w * 0.26, h * 0.76, w * 0.5, h * 0.97)
      ..cubicTo(w * 0.74, h * 0.76, w, h * 0.58, w, h * 0.33)
      ..cubicTo(w, h * 0.17, w * 0.9, h * 0.04, w * 0.74, h * 0.04)
      ..cubicTo(w * 0.62, h * 0.04, w * 0.5, h * 0.12, w * 0.5, h * 0.28)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final phase = clock.seconds % _kBeatSeconds;
    final scale = 1.0 + 0.16 * _pulseOf(phase, 0.0) + 0.1 * _pulseOf(phase, _kSecondBeatDelay);
    final center = size.center(Offset.zero);
    final bounds = Offset.zero & size;
    const gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_kLightColor, _kColor, _kDarkColor],
    );
    final fill = Paint()..shader = gradient.createShader(bounds);
    final highlight = Paint()..color = Colors.white.withOpacityExt(0.45);
    final highlightRect = Rect.fromLTWH(size.width * 0.14, size.height * 0.16, size.width * 0.18, size.height * 0.16);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawPath(_heartOf(size), fill);
    canvas.drawOval(highlightRect, highlight);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HeartPainter oldDelegate) => oldDelegate.clock != clock;
}

class _GlitterPainter extends CustomPainter {
  final NamidaFloatClock clock;
  final Color color;

  _GlitterPainter({required this.clock, required this.color}) : super(repaint: clock);

  static const _kPeriodSeconds = 4.2;
  static const _kFlashSeconds = 0.7;
  static const _kMaxArm = 3.4;
  static const _kSpots = [Offset(0.93, 0.28), Offset(0.4, 0.22), Offset(0.72, 0.62), Offset(0.14, 0.3)];

  @override
  void paint(Canvas canvas, Size size) {
    final seconds = clock.seconds;
    final phase = seconds % _kPeriodSeconds;
    if (phase >= _kFlashSeconds) return;
    final intensity = math.sin(phase / _kFlashSeconds * math.pi);
    final cycle = seconds ~/ _kPeriodSeconds;
    final spot = _kSpots[cycle % _kSpots.length];
    final cx = size.width * spot.dx;
    final cy = size.height * spot.dy;
    final arm = _kMaxArm * intensity;
    final waist = arm * 0.25;
    final star = Path()
      ..moveTo(cx, cy - arm)
      ..lineTo(cx + waist, cy - waist)
      ..lineTo(cx + arm, cy)
      ..lineTo(cx + waist, cy + waist)
      ..lineTo(cx, cy + arm)
      ..lineTo(cx - waist, cy + waist)
      ..lineTo(cx - arm, cy)
      ..lineTo(cx - waist, cy - waist)
      ..close();
    final paint = Paint()..color = color.withOpacityExt(0.55 * intensity);
    canvas.drawPath(star, paint);
  }

  @override
  bool shouldRepaint(_GlitterPainter oldDelegate) => oldDelegate.clock != clock || oldDelegate.color != color;
}

class _BlushPainter extends CustomPainter {
  final Animation<double> blush;

  _BlushPainter({required this.blush}) : super(repaint: blush);

  static const _kBlushColor = Color(0xFFFF7A9C);
  static const _kRiseShare = 0.25;

  @override
  void paint(Canvas canvas, Size size) {
    final t = blush.value;
    if (t <= 0.0 || t >= 1.0) return;
    final intensity = t < _kRiseShare ? t / _kRiseShare : 1.0 - (t - _kRiseShare) / (1.0 - _kRiseShare);
    final paint = Paint()..color = _kBlushColor.withOpacityExt(0.55 * intensity);
    final cheekWidth = size.width * 0.24;
    final cheekHeight = size.height * 0.16;
    final cheekY = size.height * 0.74;
    final leftCheek = Rect.fromCenter(center: Offset(size.width * 0.08, cheekY), width: cheekWidth, height: cheekHeight);
    final rightCheek = Rect.fromCenter(center: Offset(size.width * 0.92, cheekY), width: cheekWidth, height: cheekHeight);
    canvas.drawOval(leftCheek, paint);
    canvas.drawOval(rightCheek, paint);
  }

  @override
  bool shouldRepaint(_BlushPainter oldDelegate) => oldDelegate.blush != blush;
}

List<Offset> _directionsOf(int count) {
  return List<Offset>.generate(
    count,
    (i) {
      final angle = i * (2 * math.pi / count);
      return Offset(math.cos(angle), math.sin(angle));
    },
    growable: false,
  );
}
