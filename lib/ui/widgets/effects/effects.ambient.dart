part of 'effects.dart';

class NamidaAmbientBackdrop extends StatelessWidget {
  final AmbientBackdrop kind;
  final bool isReactive;

  final bool isUnderText;

  const NamidaAmbientBackdrop({super.key, required this.kind, required this.isReactive, this.isUnderText = false});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final ambientWidget = Obx(
      (context) {
        final color = CurrentColor.inst.color;
        final palette = CurrentColor.inst.palette;
        final colors = _AmbientPalette.colorsOf(color, palette);
        return _AmbientView(
          kind: kind,
          colors: colors,
          isDark: isDark,
          isReactive: isReactive,
        );
      },
    );
    if (!isUnderText) return ambientWidget;
    final shade = kind.textShadeOf(isDark: isDark);
    final shadeColor = isDark ? Colors.black.withOpacityExt(shade) : Colors.white.withOpacityExt(shade);
    return Stack(
      fit: StackFit.expand,
      children: [
        ambientWidget,
        ColoredBox(
          color: shadeColor,
        ),
      ],
    );
  }
}

class _AmbientView extends StatefulWidget {
  final AmbientBackdrop kind;
  final List<Color> colors;
  final bool isDark;
  final bool isReactive;

  const _AmbientView({
    required this.kind,
    required this.colors,
    required this.isDark,
    required this.isReactive,
  });

  @override
  State<_AmbientView> createState() => _AmbientViewState();
}

class _AmbientViewState extends State<_AmbientView> {
  late final _scene = _AmbientScene(
    colors: List.of(widget.colors, growable: false),
    isDark: widget.isDark,
    time: NamidaFloatClock.instance.seconds,
  );
  late _AmbientPainter _painter = _createPainter(widget.kind);

  late final _fromColors = List.of(widget.colors, growable: false);
  late final _toColors = List.of(widget.colors, growable: false);
  double _blend = 1.0;

  bool _isTicking = false;
  double _lastTime = 0.0;
  double _sinceNotify = 0.0;

  static const _frameInterval = 1 / 30;
  static const _glowTau = 0.6;
  static const _blendSeconds = 1.2;

  _AmbientPainter _createPainter(AmbientBackdrop kind) => switch (kind) {
    AmbientBackdrop.meshGradient => _MeshGradientPainter(_scene),
    AmbientBackdrop.ambientLights => _AmbientLightsPainter(_scene),
    AmbientBackdrop.bokeh => _BokehPainter(_scene),
  };

  Animation<double>? _routeAnimation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeAnimation = ModalRoute.of(context)?.animation;
  }

  @override
  void didUpdateWidget(covariant _AmbientView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind) _painter = _createPainter(widget.kind);
    if (oldWidget.isDark != widget.isDark) _scene.setDark(widget.isDark);
    if (!listEquals(oldWidget.colors, widget.colors)) _startBlend(widget.colors);
  }

  @override
  void dispose() {
    _stopTicking();
    _scene.dispose();
    super.dispose();
  }

  void _startBlend(List<Color> colors) {
    _fromColors.setAll(0, _scene.colors);
    _toColors.setAll(0, colors);
    _blend = 0.0;
  }

  void _startTicking() {
    if (_isTicking) return;
    _isTicking = true;
    _lastTime = NamidaFloatClock.instance.seconds;
    NamidaFloatClock.instance.addListener(_onTick);
  }

  void _stopTicking() {
    if (!_isTicking) return;
    _isTicking = false;
    NamidaFloatClock.instance.removeListener(_onTick);
  }

  void _onTick() {
    final time = NamidaFloatClock.instance.seconds;
    final dt = (time - _lastTime).clampDouble(0.0, 0.05);
    _lastTime = time;
    if (dt <= 0) return;

    _scene.time += dt;
    final isRouteOpen = _routeAnimation?.isCompleted ?? true;
    if (isRouteOpen) _scene.age += dt;

    if (widget.isReactive) {
      _EffectsPulse.update(time, dt);
      final level = _EffectsPulse.level;
      _scene.glow = level + (_scene.glow - level) * math.exp(-dt / _glowTau);
    }

    if (_blend < 1.0) {
      _blend = (_blend + dt / _blendSeconds).withMaximum(1.0);
      final eased = Curves.easeInOut.transform(_blend);
      final colors = _scene.colors;
      for (int i = 0; i < colors.length; i++) {
        colors[i] = Color.lerp(_fromColors[i], _toColors[i], eased)!;
      }
    }

    _sinceNotify += dt;
    if (_sinceNotify < _frameInterval) return;
    _sinceNotify = 0.0;
    _scene.notify();
  }

  @override
  Widget build(BuildContext context) {
    if (namidaAnimationsPaused(context)) {
      _stopTicking();
    } else {
      _startTicking();
    }
    return RepaintBoundary(
      child: CustomPaint(
        painter: _painter,
      ),
    );
  }
}

abstract class _AmbientPainter extends CustomPainter {
  final _AmbientScene scene;

  _AmbientPainter(this.scene) : super(repaint: scene);

  static Color baseToneOf(Color color, {required bool isDark, double shift = 0.0}) {
    final hsl = HSLColor.fromColor(color);
    final saturation = hsl.saturation.withMaximum(0.45);
    final lightness = isDark ? 0.07 + shift : 0.94 - shift;
    return hsl.withSaturation(saturation).withLightness(lightness).toColor();
  }

  static ui.Gradient softGlowShader(Color color, double radius) {
    final colors = [
      color,
      color.withValues(alpha: 0.72),
      color.withValues(alpha: 0.36),
      color.withValues(alpha: 0.12),
      color.withValues(alpha: 0.0),
    ];
    return ui.Gradient.radial(Offset.zero, radius, colors, const [0.0, 0.22, 0.48, 0.74, 1.0]);
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter oldDelegate) => oldDelegate.scene != scene;
}

class _MeshGradientPainter extends _AmbientPainter {
  _MeshGradientPainter(super.scene);

  static const _columns = 12;
  static const _softness = 0.05;
  static const _warp = 0.05;
  static const _points = [
    (x: 0.22, y: 0.20, swayX: 0.26, swayY: 0.18, paceX: 0.11, paceY: 0.08, phase: 0.0),
    (x: 0.78, y: 0.30, swayX: 0.22, swayY: 0.24, paceX: 0.07, paceY: 0.12, phase: 1.7),
    (x: 0.30, y: 0.78, swayX: 0.24, swayY: 0.20, paceX: 0.09, paceY: 0.06, phase: 3.1),
    (x: 0.76, y: 0.74, swayX: 0.20, swayY: 0.26, paceX: 0.12, paceY: 0.09, phase: 4.6),
  ];

  final _paint = Paint()..color = const Color(0xFFFFFFFF);
  final _pointsX = Float32List(_points.length);
  final _pointsY = Float32List(_points.length);
  final _red = Float32List(_points.length);
  final _green = Float32List(_points.length);
  final _blue = Float32List(_points.length);

  Size _meshSize = Size.zero;
  int _rows = 0;
  Float32List _positions = Float32List(0);
  Int32List _vertexColors = Int32List(0);
  Uint16List _indices = Uint16List(0);

  void _buildMesh(Size size) {
    _meshSize = size;
    final rows = (_columns * size.height / size.width).round().withMinimum(8).withMaximum(28);
    _rows = rows;
    final verticesCount = (_columns + 1) * (rows + 1);
    final positions = Float32List(verticesCount * 2);
    for (int row = 0; row <= rows; row++) {
      for (int column = 0; column <= _columns; column++) {
        final at = (row * (_columns + 1) + column) * 2;
        positions[at] = size.width * column / _columns;
        positions[at + 1] = size.height * row / rows;
      }
    }
    _positions = positions;
    _vertexColors = Int32List(verticesCount);
    final indices = Uint16List(_columns * rows * 6);
    int at = 0;
    for (int row = 0; row < rows; row++) {
      for (int column = 0; column < _columns; column++) {
        final vertex = row * (_columns + 1) + column;
        final below = vertex + _columns + 1;
        indices[at++] = vertex;
        indices[at++] = vertex + 1;
        indices[at++] = below;
        indices[at++] = vertex + 1;
        indices[at++] = below + 1;
        indices[at++] = below;
      }
    }
    _indices = indices;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    if (_meshSize != size) _buildMesh(size);

    final time = scene.time;
    final colors = scene.colors;
    final aspect = size.width / size.height;
    for (int i = 0; i < _points.length; i++) {
      final point = _points[i];
      _pointsX[i] = (point.x + point.swayX * math.sin(time * point.paceX + point.phase)) * aspect;
      _pointsY[i] = point.y + point.swayY * math.cos(time * point.paceY + point.phase * 1.3);
      final color = colors[i % colors.length];
      _red[i] = color.r * 255;
      _green[i] = color.g * 255;
      _blue[i] = color.b * 255;
    }

    final rows = _rows;
    final vertexColors = _vertexColors;
    final warpTimeX = time * 0.09;
    final warpTimeY = time * 0.07;
    for (int row = 0; row <= rows; row++) {
      final v = row / rows;
      for (int column = 0; column <= _columns; column++) {
        final u = column / _columns;
        final x = (u + _warp * math.sin(v * 4.0 + warpTimeX)) * aspect;
        final y = v + _warp * math.sin(u * 3.4 - warpTimeY);
        double weights = 0.0;
        double red = 0.0;
        double green = 0.0;
        double blue = 0.0;
        for (int i = 0; i < _points.length; i++) {
          final dx = x - _pointsX[i];
          final dy = y - _pointsY[i];
          final inverse = 1 / (dx * dx + dy * dy + _softness);
          final weight = inverse * inverse;
          weights += weight;
          red += _red[i] * weight;
          green += _green[i] * weight;
          blue += _blue[i] * weight;
        }
        final r = (red / weights).round();
        final g = (green / weights).round();
        final b = (blue / weights).round();
        vertexColors[row * (_columns + 1) + column] = 0xFF000000 | (r << 16) | (g << 8) | b;
      }
    }

    final vertices = ui.Vertices.raw(ui.VertexMode.triangles, _positions, colors: vertexColors, indices: _indices);
    canvas.drawVertices(vertices, BlendMode.modulate, _paint);
    vertices.dispose();
  }
}

class _AmbientLightsPainter extends _AmbientPainter {
  _AmbientLightsPainter(super.scene);

  static const _spotlights = [
    (pivot: 0.15, isTop: false, pace: 0.21, breath: 0.16, phase: 0.0),
    (pivot: 0.50, isTop: false, pace: 0.25, breath: 0.12, phase: 2.1),
    (pivot: 0.85, isTop: false, pace: 0.29, breath: 0.18, phase: 4.0),
    (pivot: 0.50, isTop: true, pace: 0.34, breath: 0.13, phase: 5.3),
  ];
  static const _swingBeams = [
    (pivot: 0.20, startAngle: 2.53, restAngle: 3.09, pace: 0.09, breath: 0.14, phase: 1.1),
    (pivot: 0.30, startAngle: 1.05, restAngle: 2.81, pace: 0.11, breath: 0.17, phase: 3.2),
  ];
  static const _spotlightLength = 0.6;
  static const _spotlightWidth = 0.3;
  static const _spotlightSweep = 0.45;
  static const _swingLength = 0.7;
  static const _swingWidth = 0.35;
  static const _swingSway = 0.06;
  static const _swingAlpha = 0.85;
  static const _swingSeconds = 2.2;
  static const _swingStagger = 0.04;
  static const _pivotOverflow = 0.04;
  static const _restAlpha = 0.42;
  static const _breathAlpha = 0.12;
  static const _glowAlpha = 0.2;
  static const _glowSwell = 0.06;

  final _basePaint = Paint();
  final _spotlightPaints = List.generate(_spotlights.length, (_) => Paint(), growable: false);
  final _swingPaints = List.generate(_swingBeams.length, (_) => Paint(), growable: false);
  final _spotlightColors = List<Color?>.filled(_spotlights.length, null);
  final _swingColors = List<Color?>.filled(_swingBeams.length, null);
  Size _shadedSize = Size.zero;
  Color? _shadedBase;
  bool? _isShadedDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final colors = scene.colors;
    final isDark = scene.isDark;
    final time = scene.time;
    final width = size.width;
    final height = size.height;

    final firstColor = colors.first;
    if (_shadedBase != firstColor || _isShadedDark != isDark) {
      _shadedBase = firstColor;
      _isShadedDark = isDark;
      _basePaint.color = _AmbientPainter.baseToneOf(firstColor, isDark: isDark);
      final blendMode = isDark ? BlendMode.screen : BlendMode.srcOver;
      for (final paint in _spotlightPaints) {
        paint.blendMode = blendMode;
      }
      for (final paint in _swingPaints) {
        paint.blendMode = blendMode;
      }
    }
    canvas.drawRect(Offset.zero & size, _basePaint);

    final isResized = _shadedSize != size;
    _shadedSize = size;
    final glow = scene.glow;
    final swell = 1 + _glowSwell * glow;
    final glowAlpha = _glowAlpha * glow;
    final bottomPivotY = height * (1 + _pivotOverflow);
    final topPivotY = -height * _pivotOverflow;

    final spotlightRadius = height * _spotlightLength;
    final spotlightWidth = _spotlightWidth * swell;
    for (int i = 0; i < _spotlights.length; i++) {
      final beam = _spotlights[i];
      final paint = _spotlightPaints[i];
      final color = colors[i % colors.length];
      if (isResized || _spotlightColors[i] != color) {
        _spotlightColors[i] = color;
        paint.shader = _AmbientPainter.softGlowShader(color, spotlightRadius);
      }
      final breath = math.sin(time * beam.breath + beam.phase);
      final alpha = (_restAlpha + _breathAlpha * breath + glowAlpha).clampDouble(0.0, 1.0);
      paint.color = Color.fromRGBO(255, 255, 255, alpha);
      final pivotY = beam.isTop ? topPivotY : bottomPivotY;
      final baseAngle = beam.isTop ? math.pi : 0.0;
      final angle = baseAngle + _spotlightSweep * math.sin(time * beam.pace + beam.phase);
      _drawBeam(canvas, paint, spotlightRadius, width * beam.pivot, pivotY, angle, spotlightWidth);
    }

    final swingRadius = size.longestSide * _swingLength;
    final swingWidth = _swingWidth * swell;
    final age = scene.age;
    for (int i = 0; i < _swingBeams.length; i++) {
      final beam = _swingBeams[i];
      final paint = _swingPaints[i];
      final color = colors[(i + 1) % colors.length];
      if (isResized || _swingColors[i] != color) {
        _swingColors[i] = color;
        paint.shader = _AmbientPainter.softGlowShader(color, swingRadius);
      }
      final beamAge = (age - i * _swingStagger).withMinimum(0.0);
      final swingProgress = (beamAge / _swingSeconds).withMaximum(1.0);
      final swingLeft = 1 - Curves.easeOutQuart.transform(swingProgress);
      final breath = math.sin(time * beam.breath + beam.phase);
      final alpha = ((_restAlpha + _breathAlpha * breath + glowAlpha) * _swingAlpha).clampDouble(0.0, 1.0);
      paint.color = Color.fromRGBO(255, 255, 255, alpha);
      final sway = _swingSway * math.sin(time * beam.pace + beam.phase);
      final angle = beam.restAngle + (beam.startAngle - beam.restAngle) * swingLeft + sway;
      _drawBeam(canvas, paint, swingRadius, width * beam.pivot, topPivotY, angle, swingWidth);
    }
  }

  void _drawBeam(Canvas canvas, Paint paint, double radius, double pivotX, double pivotY, double angle, double widthScale) {
    canvas.save();
    canvas.translate(pivotX, pivotY);
    canvas.rotate(angle);
    canvas.translate(0, -radius * 0.9);
    canvas.scale(widthScale, 1.0);
    canvas.drawCircle(Offset.zero, radius, paint);
    canvas.restore();
  }
}

class _BokehPainter extends _AmbientPainter {
  _BokehPainter(super.scene);

  static const _dots = [
    (x: 0.14, y: 0.10, depth: 0.85, risePerSecond: 0.0060, sway: 0.030, swayPace: 0.11, twinkle: 0.21, phase: 0.0),
    (x: 0.82, y: 0.22, depth: 0.30, risePerSecond: 0.0110, sway: 0.020, swayPace: 0.16, twinkle: 0.33, phase: 1.3),
    (x: 0.46, y: 0.35, depth: 0.60, risePerSecond: 0.0080, sway: 0.040, swayPace: 0.09, twinkle: 0.26, phase: 2.6),
    (x: 0.26, y: 0.52, depth: 0.15, risePerSecond: 0.0130, sway: 0.025, swayPace: 0.19, twinkle: 0.38, phase: 3.4),
    (x: 0.70, y: 0.60, depth: 0.95, risePerSecond: 0.0050, sway: 0.035, swayPace: 0.08, twinkle: 0.18, phase: 4.2),
    (x: 0.90, y: 0.74, depth: 0.45, risePerSecond: 0.0090, sway: 0.020, swayPace: 0.14, twinkle: 0.29, phase: 5.0),
    (x: 0.08, y: 0.84, depth: 0.55, risePerSecond: 0.0085, sway: 0.030, swayPace: 0.12, twinkle: 0.24, phase: 5.9),
    (x: 0.56, y: 0.92, depth: 0.25, risePerSecond: 0.0120, sway: 0.025, swayPace: 0.17, twinkle: 0.35, phase: 0.7),
    (x: 0.36, y: 0.04, depth: 0.70, risePerSecond: 0.0070, sway: 0.040, swayPace: 0.10, twinkle: 0.22, phase: 2.0),
  ];
  static const _minRadius = 0.08;
  static const _maxRadius = 0.24;
  static const _fieldFraction = 0.7;
  static const _fadeInFraction = 0.3;
  static const _pace = 0.5;
  static const _nearAlpha = 0.5;
  static const _farAlpha = 0.75;
  static const _glowAlpha = 0.2;

  final _basePaint = Paint();
  final _paints = List.generate(_dots.length, (_) => Paint(), growable: false);
  final _shadedColors = List<Color?>.filled(_dots.length, null);
  Size _shadedSize = Size.zero;
  Color? _shadedBaseTop;
  Color? _shadedBaseBottom;
  bool? _isShadedDark;

  static ui.Gradient _discShader(Color color, double radius, double depth) {
    final edge = 0.3 - 0.15 * depth;
    final colors = [
      color,
      color.withValues(alpha: 0.8),
      color.withValues(alpha: 0.35),
      color.withValues(alpha: 0.0),
    ];
    return ui.Gradient.radial(Offset.zero, radius, colors, [0.0, edge, (edge + 1) / 2, 1.0]);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final colors = scene.colors;
    final isDark = scene.isDark;
    final time = scene.time;

    final isResized = _shadedSize != size;
    final baseTop = colors.first;
    final baseBottom = colors[1 % colors.length];
    if (isResized || _shadedBaseTop != baseTop || _shadedBaseBottom != baseBottom || _isShadedDark != isDark) {
      _shadedSize = size;
      _shadedBaseTop = baseTop;
      _shadedBaseBottom = baseBottom;
      final top = _AmbientPainter.baseToneOf(baseTop, isDark: isDark);
      final bottom = _AmbientPainter.baseToneOf(baseBottom, isDark: isDark, shift: 0.05);
      final bottomLeft = Offset(0, size.height);
      _basePaint.shader = ui.Gradient.linear(Offset.zero, bottomLeft, [top, bottom]);
      if (_isShadedDark != isDark) {
        _isShadedDark = isDark;
        final blendMode = isDark ? BlendMode.screen : BlendMode.srcOver;
        for (final paint in _paints) {
          paint.blendMode = blendMode;
        }
      }
    }
    canvas.drawRect(Offset.zero & size, _basePaint);

    final shortestSide = size.shortestSide;
    final glow = scene.glow;
    final fieldHeight = size.height * _fieldFraction;
    final fadeInHeight = fieldHeight * _fadeInFraction;
    final paced = time * _pace;
    for (int i = 0; i < _dots.length; i++) {
      final dot = _dots[i];
      final paint = _paints[i];
      final color = colors[i % colors.length];
      final radius = shortestSide * (_minRadius + (_maxRadius - _minRadius) * dot.depth);
      if (isResized || _shadedColors[i] != color) {
        _shadedColors[i] = color;
        paint.shader = _discShader(color, radius, dot.depth);
      }
      final travel = fieldHeight + radius;
      final risen = (dot.y + paced * dot.risePerSecond) % 1.0;
      final y = fieldHeight - risen * travel;
      final x = size.width * (dot.x + dot.sway * math.sin(paced * dot.swayPace + dot.phase));
      final twinkle = 0.7 + 0.3 * math.sin(paced * dot.twinkle + dot.phase);
      final depthAlpha = _farAlpha + (_nearAlpha - _farAlpha) * dot.depth;
      final entered = ((fieldHeight - y) / fadeInHeight).clampDouble(0.0, 1.0);
      final alpha = ((depthAlpha * twinkle + _glowAlpha * glow) * entered).clampDouble(0.0, 1.0);
      paint.color = Color.fromRGBO(255, 255, 255, alpha);
      canvas.save();
      canvas.translate(x, y);
      canvas.drawCircle(Offset.zero, radius, paint);
      canvas.restore();
    }
  }
}

abstract class _AmbientPalette {
  static const count = 4;
  static const _variants = [
    (hue: 0.0, lightness: 0.0),
    (hue: 14.0, lightness: 0.07),
    (hue: -14.0, lightness: -0.06),
    (hue: 26.0, lightness: -0.02),
  ];
  static const _artworkShare = 0.45;

  static List<Color> colorsOf(Color color, List<Color> palette) {
    final source = HSLColor.fromColor(color);
    final saturation = source.saturation.clampDouble(0.22, 0.55);
    final colors = List<Color>.filled(count, color);
    for (int i = 0; i < count; i++) {
      final variant = _variants[i];
      final hue = (source.hue + variant.hue) % 360;
      final lightness = (source.lightness + variant.lightness).clampDouble(0.35, 0.68);
      colors[i] = source.withHue(hue).withSaturation(saturation).withLightness(lightness).toColor();
    }
    final vivid = _vividColorsOf(palette, const []);
    for (int i = 1; i < count && i <= vivid.length; i++) {
      colors[i] = Color.lerp(colors[i], vivid[i - 1], _artworkShare)!;
    }
    return colors;
  }
}

class _AmbientScene extends ChangeNotifier {
  final List<Color> colors;
  bool isDark;
  double time;
  double glow = 0.0;
  double age = 0.0;

  _AmbientScene({required this.colors, required this.isDark, required this.time});

  void setDark(bool value) {
    isDark = value;
    notifyListeners();
  }

  void notify() => notifyListeners();
}

extension _AmbientBackdropShade on AmbientBackdrop {
  double textShadeOf({required bool isDark}) => switch (this) {
    AmbientBackdrop.meshGradient => isDark ? 0.6 : 0.55,
    AmbientBackdrop.ambientLights => isDark ? 0.35 : 0.35,
    AmbientBackdrop.bokeh => isDark ? 0.15 : 0.2,
  };
}
