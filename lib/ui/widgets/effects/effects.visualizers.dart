part of 'effects.dart';

class NamidaVisualizer extends StatelessWidget {
  final _Placement _placement;
  final double opacity;

  final double artworkScale;
  final double artworkRadius;

  /// how far above the bottom edge the waveform sits.
  final double baseline;
  final double waveformScale;
  final double waveformPadding;

  const NamidaVisualizer.wallpaper({super.key, this.opacity = 1.0})
    : _placement = _Placement.wallpaper,
      artworkScale = 1.0,
      artworkRadius = 0.0,
      baseline = 0.0,
      waveformScale = 1.0,
      waveformPadding = 0.0;

  const NamidaVisualizer.aroundPlayer({super.key, this.opacity = 1.0})
    : _placement = _Placement.player,
      artworkScale = 1.0,
      artworkRadius = 0.0,
      baseline = 0.0,
      waveformScale = 1.0,
      waveformPadding = 0.0;

  const NamidaVisualizer.insidePanel({super.key, this.opacity = 1.0, required this.baseline, required this.waveformScale, required this.waveformPadding})
    : _placement = _Placement.panel,
      artworkScale = 1.0,
      artworkRadius = 0.0;

  const NamidaVisualizer.aroundArtwork({super.key, this.opacity = 1.0, required this.artworkScale, required this.artworkRadius})
    : _placement = _Placement.artwork,
      baseline = 0.0,
      waveformScale = 1.0,
      waveformPadding = 0.0;

  static ({bool hasAroundPlayer, bool hasInsidePanel, bool hasAroundArtwork}) placementsOf(Set<MiniplayerVisualizer> enabled) {
    bool hasAroundPlayer = false;
    bool hasInsidePanel = false;
    bool hasAroundArtwork = false;
    for (final style in enabled) {
      switch (style.toPlacement()) {
        case _Placement.player:
          hasAroundPlayer = true;
        case _Placement.panel:
          hasInsidePanel = true;
        case _Placement.artwork:
          hasAroundArtwork = true;
        case _Placement.wallpaper:
          break;
      }
    }
    return (hasAroundPlayer: hasAroundPlayer, hasInsidePanel: hasInsidePanel, hasAroundArtwork: hasAroundArtwork);
  }

  @override
  Widget build(BuildContext context) {
    final placement = _placement;
    return Obx(
      (context) {
        final views = <Widget>[];
        if (placement == _Placement.wallpaper) {
          final hasParticles = settings.enableMiniplayerParticles.valueR;
          if (hasParticles) {
            views.add(
              _VisualizerView(
                kind: _VisualizerKind.particles,
                opacity: opacity,
                artworkScale: artworkScale,
                artworkRadius: artworkRadius,
                baseline: baseline,
                waveformScale: waveformScale,
                waveformPadding: waveformPadding,
                hasArtworkColors: settings.visualizerArtworkColors.valueR,
              ),
            );
          }
        } else {
          final enabled = settings.miniplayerVisualizers.valueR;
          for (final style in MiniplayerVisualizer.values) {
            if (style.toPlacement() != placement || !enabled.contains(style)) continue;
            views.add(
              _VisualizerView(
                kind: style.toKind(),
                opacity: opacity,
                artworkScale: artworkScale,
                artworkRadius: artworkRadius,
                baseline: baseline,
                waveformScale: waveformScale,
                waveformPadding: waveformPadding,
                hasArtworkColors: settings.visualizerArtworkColors.valueR,
              ),
            );
          }
        }
        if (views.isEmpty) return const SizedBox();
        return IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: views,
          ),
        );
      },
    );
  }
}

class _VisualizerDriver extends ChangeNotifier {
  _VisualizerDriver._();

  static final _shared = _VisualizerDriver._();

  static _VisualizerDriver attach({required bool isSpectrumNeeded, required bool hasParticles}) {
    final driver = _shared;
    SpectrumController.inst.attach(isSpectrumNeeded: isSpectrumNeeded);
    if (hasParticles) driver._particlesRefs++;
    driver._refs++;
    if (driver._refs == 1) driver._start();
    driver._syncField();
    return driver;
  }

  void detach({required bool isSpectrumNeeded, required bool hasParticles}) {
    if (hasParticles) _particlesRefs--;
    _refs--;
    if (_refs == 0) _stop();
    _syncField();
    SpectrumController.inst.detach(isSpectrumNeeded: isSpectrumNeeded);
  }

  _EffectField? field;

  final bands = Float32List(SpectrumController.bandCount);
  double level = 0.0;
  double beat = 0.0;

  int beatsCount = 0;
  double lastBeatStrength = 0.0;

  double presence = 0.0;

  int _refs = 0;
  int _particlesRefs = 0;
  bool _isTicking = false;
  double _lastTime = 0.0;
  double _previousBeat = 0.0;
  double _lastBeatAt = 0.0;

  static const _floor = 0.35;
  static const _riseTau = 0.03;
  static const _fallTau = 0.16;
  static const _presenceTau = 0.3;
  static const _settled = 0.004;

  static const _beatRise = 0.12;
  static const _beatFloor = 0.3;
  static const _beatGap = 0.14;

  void _start() {
    Player.inst.isPlaying.addListener(_onPlayingChanged);
    if (Player.inst.isPlaying.value) _startTicking();
  }

  void _stop() {
    _stopTicking();
    Player.inst.isPlaying.removeListener(_onPlayingChanged);
  }

  void _onPlayingChanged() {
    if (Player.inst.isPlaying.value) _startTicking();
  }

  void _startTicking() {
    if (_isTicking) return;
    _isTicking = true;
    _lastTime = NamidaFloatClock.instance.seconds;
    NamidaFloatClock.instance.addListener(_onTick);
    _syncField();
  }

  void _stopTicking() {
    if (!_isTicking) return;
    _isTicking = false;
    NamidaFloatClock.instance.removeListener(_onTick);
    _syncField();
  }

  void _syncField() {
    final isWanted = _isTicking && _particlesRefs > 0;
    final current = field;
    if (isWanted && current == null) {
      field = _EffectField.attach(_kVisualizerParticles, pace: 1.0);
    } else if (!isWanted && current != null) {
      current.detach();
      field = null;
    }
  }

  void _onTick() {
    final time = NamidaFloatClock.instance.seconds;
    final dt = (time - _lastTime).clampDouble(0.0, 0.05);
    _lastTime = time;
    if (dt <= 0) return;
    _EffectsPulse.update(time, dt);

    final isPlaying = Player.inst.isPlaying.value;
    final hasSpectrum = isPlaying && SpectrumController.inst.hasSpectrum;
    final raw = _EffectsPulse.bands;
    final rise = math.exp(-dt / _riseTau);
    final fall = math.exp(-dt / _fallTau);
    for (int b = 0; b < bands.length; b++) {
      double target = 0.0;
      if (hasSpectrum) {
        target = ((raw[b] - _floor) / (1 - _floor)).withMinimum(0.0);
      } else if (isPlaying) {
        target = 0.10 + 0.06 * math.sin(time * 1.3 + b * 0.8);
      }
      final current = bands[b];
      final ease = target > current ? rise : fall;
      bands[b] = target + (current - target) * ease;
    }
    level = _EffectsPulse.level;
    beat = _EffectsPulse.beat;

    final isRising = beat > _previousBeat + _beatRise;
    if (isRising && beat > _beatFloor && time - _lastBeatAt > _beatGap) {
      beatsCount++;
      lastBeatStrength = beat;
      _lastBeatAt = time;
    }
    _previousBeat = beat;

    final wanted = isPlaying ? 1.0 : 0.0;
    presence = wanted + (presence - wanted) * math.exp(-dt / _presenceTau);
    notifyListeners();

    if (!isPlaying && presence < _settled) {
      presence = 0.0;
      _stopTicking();
    }
  }

  double levelAt(double position) {
    final scaled = position * (bands.length - 1);
    final index = scaled.floor();
    if (index >= bands.length - 1) return bands[bands.length - 1];
    final toNext = scaled - index;
    final current = bands[index];
    return current + (bands[index + 1] - current) * toNext;
  }

  double averageOf(int fromBand, int toBand) {
    double sum = 0.0;
    for (int b = fromBand; b < toBand; b++) {
      sum += bands[b];
    }
    return sum / (toBand - fromBand);
  }
}

class _VisualizerView extends StatefulWidget {
  final _VisualizerKind kind;
  final double opacity;
  final double artworkScale;
  final double artworkRadius;
  final double baseline;
  final double waveformScale;
  final double waveformPadding;
  final bool hasArtworkColors;

  const _VisualizerView({
    required this.kind,
    required this.opacity,
    required this.artworkScale,
    required this.artworkRadius,
    required this.baseline,
    required this.waveformScale,
    required this.waveformPadding,
    required this.hasArtworkColors,
  });

  @override
  State<_VisualizerView> createState() => _VisualizerViewState();
}

class _VisualizerViewState extends State<_VisualizerView> {
  _VisualizerDriver? _driver;
  bool _isParticles = false;

  @override
  void didUpdateWidget(covariant _VisualizerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind) _detach();
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  _VisualizerDriver _attach() {
    final attached = _driver;
    if (attached != null) return attached;
    final isParticles = widget.kind == _VisualizerKind.particles;
    final driver = _VisualizerDriver.attach(isSpectrumNeeded: !isParticles, hasParticles: isParticles);
    _isParticles = isParticles;
    _driver = driver;
    return driver;
  }

  void _detach() {
    final driver = _driver;
    if (driver == null) return;
    driver.detach(isSpectrumNeeded: !_isParticles, hasParticles: _isParticles);
    _driver = null;
  }

  @override
  Widget build(BuildContext context) {
    final opacity = widget.opacity;
    if (opacity <= 0.01 || namidaAnimationsPaused(context)) {
      _detach();
      return const SizedBox();
    }
    final driver = _attach();
    final themeColors = [context.theme.colorScheme.secondary];
    if (!widget.hasArtworkColors) {
      return _VisualizerCanvas(
        view: widget,
        driver: driver,
        colors: themeColors,
      );
    }
    return Obx(
      (context) {
        final palette = CurrentColor.inst.palette;
        final colors = _vividColorsOf(palette, themeColors);
        return _VisualizerCanvas(
          view: widget,
          driver: driver,
          colors: colors,
        );
      },
    );
  }
}

class _VisualizerCanvas extends StatelessWidget {
  final _VisualizerView view;
  final _VisualizerDriver driver;
  final List<Color> colors;

  const _VisualizerCanvas({
    required this.view,
    required this.driver,
    required this.colors,
  });

  static const _spectrumOpacity = 0.4;

  @override
  Widget build(BuildContext context) {
    final kind = view.kind;
    final opacity = kind == _VisualizerKind.particles ? view.opacity : view.opacity * _spectrumOpacity;
    final artworkScale = view.artworkScale;
    final artworkRadius = view.artworkRadius;
    final painter = switch (kind) {
      _VisualizerKind.particles => _ParticlesPainter(driver: driver, colors: colors, opacity: opacity),
      _VisualizerKind.bars => _BarsPainter(driver: driver, colors: colors, opacity: opacity),
      _VisualizerKind.mirroredBars => _MirroredBarsPainter(
        driver: driver,
        colors: colors,
        opacity: opacity,
        baseline: view.baseline,
        waveformScale: view.waveformScale,
        waveformPadding: view.waveformPadding,
      ),
      _VisualizerKind.waves => _WavesPainter(driver: driver, colors: colors, opacity: opacity),
      _VisualizerKind.edgeLights => _EdgeLightsPainter(driver: driver, colors: colors, opacity: opacity),
      _VisualizerKind.glow => _GlowPainter(driver: driver, colors: colors, opacity: opacity, artworkScale: artworkScale),
      _VisualizerKind.outline => _OutlinePainter(driver: driver, colors: colors, opacity: opacity, artworkScale: artworkScale, artworkRadius: artworkRadius),
      _VisualizerKind.beatRings => _BeatRingsPainter(driver: driver, colors: colors, opacity: opacity, artworkScale: artworkScale, artworkRadius: artworkRadius),
      _VisualizerKind.reactiveParticles => _ReactiveParticlesPainter(driver: driver, colors: colors, opacity: opacity, artworkScale: artworkScale),
    };
    return RepaintBoundary(
      child: CustomPaint(
        painter: painter,
      ),
    );
  }
}

abstract class _VisualizerPainter extends CustomPainter {
  final _VisualizerDriver driver;
  final List<Color> colors;
  final double opacity;

  _VisualizerPainter({
    required this.driver,
    required this.colors,
    required this.opacity,
  }) : super(repaint: driver);

  Color get color => colors.first;

  double _lastPaintedAt = 0.0;

  double takeElapsed() {
    final time = NamidaFloatClock.instance.seconds;
    final elapsed = (time - _lastPaintedAt).clampDouble(0.0, 0.05);
    _lastPaintedAt = time;
    return elapsed;
  }

  ui.Shader buildHorizontalShader(double width, double alpha) {
    final count = colors.length;
    final faded = <Color>[];
    final stops = <double>[];
    for (int i = 0; i < count; i++) {
      final fadedColor = colors[i].withValues(alpha: alpha);
      faded.add(fadedColor);
      stops.add(i / (count - 1));
    }
    return ui.Gradient.linear(Offset.zero, Offset(width, 0), faded, stops);
  }

  @override
  bool shouldRepaint(covariant _VisualizerPainter oldDelegate) {
    return oldDelegate.driver != driver || oldDelegate.colors != colors || oldDelegate.opacity != opacity;
  }
}

class _ParticlesPainter extends _VisualizerPainter {
  _ParticlesPainter({
    required super.driver,
    required super.colors,
    required super.opacity,
  });

  static const _swell = 0.12;

  @override
  void paint(Canvas canvas, Size size) {
    final presence = driver.presence;
    final field = driver.field;
    if (presence <= 0 || field == null) return;
    final scale = 1 + driver.level * _swell;
    final rgb = color.intValue & 0xFFFFFF;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    canvas.translate(-size.width / 2, -size.height / 2);
    field.paint(canvas, size, tint: rgb, ink: rgb, isDark: true, opacity: opacity * presence);
    canvas.restore();
  }
}

class _BarsPainter extends _VisualizerPainter {
  _BarsPainter({
    required super.driver,
    required super.colors,
    required super.opacity,
  });

  static const barsCount = SpectrumController.bandCount * 2 - 1;
  static const gapFraction = 0.32;
  static const _maxHeightFraction = 0.34;
  static const _minHeight = 3.0;

  final _points = Float32List(barsCount * 4);
  final _paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  Size _shadedSize = Size.zero;
  double _shadedStrength = -1.0;

  @override
  void paint(Canvas canvas, Size size) {
    final presence = driver.presence;
    if (presence <= 0 || size.isEmpty) return;

    final maxHeight = size.height * _maxHeightFraction;
    final slot = size.width / (barsCount + gapFraction);
    final gap = slot * gapFraction;
    final barWidth = slot - gap;
    final capRadius = barWidth / 2;
    final bottom = size.height;

    for (int i = 0; i < barsCount; i++) {
      final level = driver.levelAt(i / (barsCount - 1));
      final height = _minHeight + level * maxHeight * presence;
      final x = gap + capRadius + i * slot;
      final at = i * 4;
      _points[at] = x;
      _points[at + 1] = bottom + capRadius;
      _points[at + 2] = x;
      _points[at + 3] = bottom - height + capRadius;
    }
    _paint.strokeWidth = barWidth;

    final strength = opacity * presence;
    if (_shadedSize != size || _shadedStrength != strength) {
      _shadedSize = size;
      _shadedStrength = strength;
      if (colors.length > 1) {
        _paint.shader = buildHorizontalShader(size.width, 0.45 * strength);
      } else {
        final colorAtBottom = color.withValues(alpha: 0.6 * strength);
        final colorAtTop = color.withValues(alpha: 0.12 * strength);
        final from = Offset(0, bottom);
        final to = Offset(0, bottom - maxHeight);
        _paint.shader = ui.Gradient.linear(from, to, [colorAtBottom, colorAtTop]);
      }
    }
    canvas.drawRawPoints(ui.PointMode.lines, _points, _paint);
  }
}

class _MirroredBarsPainter extends _VisualizerPainter {
  final double baseline;
  final double waveformScale;
  final double waveformPadding;

  _MirroredBarsPainter({
    required super.driver,
    required super.colors,
    required super.opacity,
    required this.baseline,
    required this.waveformScale,
    required this.waveformPadding,
  });

  static const _maxReach = 34.0;
  static const _strength = 0.35;

  Float32List _points = Float32List(0);
  final _paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  Size _shadedSize = Size.zero;
  double _shadedStrength = -1.0;

  @override
  void paint(Canvas canvas, Size size) {
    final presence = driver.presence;
    if (presence <= 0 || size.isEmpty) return;

    final waveform = WaveformController.inst.currentWaveformUIRx.value;
    final barsCount = waveform.length;
    if (barsCount < 2) return;
    if (_points.length != barsCount * 4) _points = Float32List(barsCount * 4);
    final points = _points;

    const minHeight = WaveformComponent.defaultBarsMinHeight;
    const maxHeight = WaveformComponent.defaultBarsMaxHeight;
    final isWaveformShown = WaveformController.inst.isWaveformUIEnabled.value;
    final trackWidth = size.width - waveformPadding * 2;
    final barWidth = trackWidth / barsCount * WaveformComponent.barWidthFraction;
    final gap = (trackWidth - barWidth * barsCount) / (barsCount + 1);
    final slot = barWidth + gap;
    final capRadius = barWidth / 2;
    final firstX = waveformPadding + gap + capRadius;
    final middle = size.height - baseline;
    final maxReach = _maxReach * waveformScale * presence;

    for (int i = 0; i < barsCount; i++) {
      final level = driver.levelAt(i / (barsCount - 1));
      final waveformHeight = isWaveformShown ? waveform[i].clampDouble(minHeight, maxHeight) : minHeight;
      final covered = waveformHeight * waveformScale / 2 - capRadius;
      final reach = covered.withMinimum(0.0) + level * maxReach;
      final x = firstX + i * slot;
      final at = i * 4;
      points[at] = x;
      points[at + 1] = middle - reach;
      points[at + 2] = x;
      points[at + 3] = middle + reach;
    }
    _paint.strokeWidth = barWidth;

    final strength = _strength * opacity * presence;
    if (_shadedSize != size || _shadedStrength != strength) {
      _shadedSize = size;
      _shadedStrength = strength;
      if (colors.length > 1) {
        _paint.shader = buildHorizontalShader(size.width, strength);
      } else {
        _paint.color = color.withValues(alpha: strength);
      }
    }
    canvas.drawRawPoints(ui.PointMode.lines, points, _paint);
  }

  @override
  bool shouldRepaint(covariant _MirroredBarsPainter oldDelegate) {
    return oldDelegate.baseline != baseline || oldDelegate.waveformScale != waveformScale || oldDelegate.waveformPadding != waveformPadding || super.shouldRepaint(oldDelegate);
  }
}

class _WavesPainter extends _VisualizerPainter {
  _WavesPainter({
    required super.driver,
    required super.colors,
    required super.opacity,
  });

  static const _step = 14.0;
  static const _maxHeightFraction = 0.26;
  static const _layers = [
    (rest: 0.30, ripple: 0.0085, pace: 0.55, alpha: 0.16, isMirrored: false),
    (rest: 0.20, ripple: 0.0120, pace: -0.80, alpha: 0.20, isMirrored: true),
    (rest: 0.10, ripple: 0.0170, pace: 1.10, alpha: 0.26, isMirrored: false),
  ];

  final _path = Path();
  final _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final presence = driver.presence;
    if (presence <= 0 || size.isEmpty) return;

    final time = NamidaFloatClock.instance.seconds;
    final width = size.width;
    final bottom = size.height;
    final maxHeight = size.height * _maxHeightFraction;
    final strength = opacity * presence;

    for (int i = 0; i < _layers.length; i++) {
      final layer = _layers[i];
      final layerColor = colors[i % colors.length];
      final firstHeight = _heightAt(0.0, width, time, layer.rest, layer.ripple, layer.pace, layer.isMirrored);
      double previousX = 0.0;
      double previousY = bottom - firstHeight * maxHeight * presence;
      _path.reset();
      _path.moveTo(0, bottom);
      _path.lineTo(previousX, previousY);
      for (double x = _step; x < width + _step; x += _step) {
        final height = _heightAt(x, width, time, layer.rest, layer.ripple, layer.pace, layer.isMirrored);
        final y = bottom - height * maxHeight * presence;
        _path.quadraticBezierTo(previousX, previousY, (previousX + x) / 2, (previousY + y) / 2);
        previousX = x;
        previousY = y;
      }
      _path.lineTo(previousX, previousY);
      _path.lineTo(previousX, bottom);
      _path.close();
      _paint.color = layerColor.withValues(alpha: layer.alpha * strength);
      canvas.drawPath(_path, _paint);
    }
  }

  double _heightAt(double x, double width, double time, double rest, double ripple, double pace, bool isMirrored) {
    final along = (x / width).clampDouble(0.0, 1.0);
    final level = driver.levelAt(isMirrored ? 1 - along : along);
    final rippled = 0.5 + 0.5 * math.sin(x * ripple + time * pace);
    return rest + level * (0.45 + 0.55 * rippled);
  }
}

class _EdgeLightsPainter extends _VisualizerPainter {
  _EdgeLightsPainter({
    required super.driver,
    required super.colors,
    required super.opacity,
  });

  static const _depthFraction = 0.2;
  static const _strength = 0.7;
  static const _falloff = [0.0, 0.4, 1.0];
  static const _lowsEnd = 5;
  static const _midsEnd = 11;

  final _bottomPaint = Paint();
  final _topPaint = Paint();
  final _leftPaint = Paint();
  final _rightPaint = Paint();
  Size _shadedSize = Size.zero;

  void _shade(Size size, double depth) {
    _shadedSize = size;
    final width = size.width;
    final height = size.height;
    final lows = colors[0];
    final highs = colors[1 % colors.length];
    final mids = colors[2 % colors.length];
    final lowsFade = [lows, lows.withValues(alpha: 0.28), lows.withValues(alpha: 0.0)];
    final highsFade = [highs, highs.withValues(alpha: 0.28), highs.withValues(alpha: 0.0)];
    final midsFade = [mids, mids.withValues(alpha: 0.28), mids.withValues(alpha: 0.0)];
    final bottomLeft = Offset(0, height);
    final topRight = Offset(width, 0);
    final up = Offset(0, height - depth);
    final down = Offset(0, depth);
    final right = Offset(depth, 0);
    final left = Offset(width - depth, 0);
    _bottomPaint.shader = ui.Gradient.linear(bottomLeft, up, lowsFade, _falloff);
    _topPaint.shader = ui.Gradient.linear(Offset.zero, down, highsFade, _falloff);
    _leftPaint.shader = ui.Gradient.linear(Offset.zero, right, midsFade, _falloff);
    _rightPaint.shader = ui.Gradient.linear(topRight, left, midsFade, _falloff);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final presence = driver.presence;
    if (presence <= 0 || size.isEmpty) return;

    final width = size.width;
    final height = size.height;
    final depth = size.shortestSide * _depthFraction;
    if (_shadedSize != size) _shade(size, depth);

    final strength = _strength * opacity * presence;
    final lows = driver.averageOf(0, _lowsEnd);
    final mids = driver.averageOf(_lowsEnd, _midsEnd);
    final highs = driver.averageOf(_midsEnd, driver.bands.length);
    final lowsAlpha = ((lows * 0.75 + driver.beat * 0.25) * strength).withMaximum(1.0);
    final midsAlpha = (mids * strength).withMaximum(1.0);
    final highsAlpha = (highs * 1.3 * strength).withMaximum(1.0);
    _bottomPaint.color = Color.fromRGBO(255, 255, 255, lowsAlpha);
    _topPaint.color = Color.fromRGBO(255, 255, 255, highsAlpha);
    _leftPaint.color = Color.fromRGBO(255, 255, 255, midsAlpha);
    _rightPaint.color = Color.fromRGBO(255, 255, 255, midsAlpha);

    final bottomEdge = Rect.fromLTRB(0, height - depth, width, height);
    final topEdge = Rect.fromLTRB(0, 0, width, depth);
    final leftEdge = Rect.fromLTRB(0, 0, depth, height);
    final rightEdge = Rect.fromLTRB(width - depth, 0, width, height);
    canvas.drawRect(bottomEdge, _bottomPaint);
    canvas.drawRect(topEdge, _topPaint);
    canvas.drawRect(leftEdge, _leftPaint);
    canvas.drawRect(rightEdge, _rightPaint);
  }
}

class _GlowPainter extends _VisualizerPainter {
  final double artworkScale;

  _GlowPainter({
    required super.driver,
    required super.colors,
    required super.opacity,
    required this.artworkScale,
  });

  final _paint = Paint()..filterQuality = FilterQuality.low;

  @override
  void paint(Canvas canvas, Size size) {
    final presence = driver.presence;
    if (presence <= 0 || size.isEmpty) return;

    final hit = driver.beat;
    final swell = artworkScale * (1 + 0.06 * driver.level + 0.10 * hit);
    final core = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.width * swell,
      height: size.height * swell,
    );
    final brightness = (0.30 + 0.35 * driver.level + 0.45 * hit).withMaximum(1.0);
    final alpha = brightness * opacity * presence;
    final halo = _HaloSprite.obtain();
    final destination = _HaloSprite.destinationFor(core);
    _paint.color = Color.fromRGBO(255, 255, 255, alpha);
    _paint.colorFilter = _HaloSprite.tintOf(color);
    canvas.drawImageRect(halo, _HaloSprite.source, destination, _paint);
  }

  @override
  bool shouldRepaint(covariant _GlowPainter oldDelegate) {
    return oldDelegate.artworkScale != artworkScale || super.shouldRepaint(oldDelegate);
  }
}

class _OutlinePainter extends _VisualizerPainter {
  final double artworkScale;
  final double artworkRadius;

  _OutlinePainter({
    required super.driver,
    required super.colors,
    required super.opacity,
    required this.artworkScale,
    required this.artworkRadius,
  });

  static const _spacing = 9.0;
  static const _extraBarsPerCorner = 2;
  static const _gap = 7.0;
  static const _minLength = 2.0;
  static const _maxLengthFraction = 0.11;
  static const _thickness = 3.4;
  static const _strength = 0.5;

  Float32List _anchors = Float32List(0);
  Float32List _points = Float32List(0);
  int _barsCount = 0;
  Size _laidOutSize = Size.zero;

  final _paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = _thickness;

  void _place(int index, double x, double y, double outX, double outY) {
    final at = index * 4;
    _anchors[at] = x;
    _anchors[at + 1] = y;
    _anchors[at + 2] = outX;
    _anchors[at + 3] = outY;
  }

  // -- the right half, from under the artwork up to above it
  void _layOut(Size size) {
    _laidOutSize = size;
    final width = size.width * artworkScale;
    final height = size.height * artworkScale;
    final shortestSide = math.min(width, height);
    final radius = (artworkRadius * artworkScale).withMaximum(shortestSide / 2);
    final halfStraightX = width / 2 - radius;
    final halfStraightY = height / 2 - radius;
    final cornerArc = radius * math.pi / 2;
    final edgeBars = (halfStraightX / _spacing).floor();
    final sideBars = (halfStraightY * 2 / _spacing).floor();
    final cornerBars = (cornerArc / _spacing).floor() + _extraBarsPerCorner;
    final barsCount = edgeBars * 2 + sideBars + cornerBars * 2;
    if (barsCount != _barsCount) {
      _barsCount = barsCount;
      _anchors = Float32List(barsCount * 4);
      _points = Float32List(barsCount * 8);
    }
    if (colors.length > 1) {
      final center = size.center(Offset.zero);
      final loop = [...colors, colors.first];
      final stops = <double>[for (int i = 0; i < loop.length; i++) i / (loop.length - 1)];
      _paint.shader = ui.Gradient.sweep(center, loop, stops);
    }

    int index = 0;
    for (int k = 0; k < edgeBars; k++, index++) {
      final x = (k + 0.5) * halfStraightX / edgeBars;
      _place(index, x, height / 2, 0.0, 1.0);
    }
    for (int k = 0; k < cornerBars; k++, index++) {
      final turned = (k + 0.5) / cornerBars * math.pi / 2;
      final outX = math.sin(turned);
      final outY = math.cos(turned);
      _place(index, halfStraightX + outX * radius, halfStraightY + outY * radius, outX, outY);
    }
    for (int k = 0; k < sideBars; k++, index++) {
      final y = halfStraightY - (k + 0.5) * halfStraightY * 2 / sideBars;
      _place(index, width / 2, y, 1.0, 0.0);
    }
    for (int k = 0; k < cornerBars; k++, index++) {
      final turned = (k + 0.5) / cornerBars * math.pi / 2;
      final outX = math.cos(turned);
      final outY = -math.sin(turned);
      _place(index, halfStraightX + outX * radius, -halfStraightY + outY * radius, outX, outY);
    }
    for (int k = 0; k < edgeBars; k++, index++) {
      final x = halfStraightX - (k + 0.5) * halfStraightX / edgeBars;
      _place(index, x, -height / 2, 0.0, -1.0);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final presence = driver.presence;
    if (presence <= 0 || size.isEmpty) return;
    if (_laidOutSize != size) _layOut(size);
    final barsCount = _barsCount;
    if (barsCount <= 0) return;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final maxLength = size.width * _maxLengthFraction * presence;
    final anchors = _anchors;
    final points = _points;

    for (int i = 0; i < barsCount; i++) {
      final from = i * 4;
      final outX = anchors[from + 2];
      final outY = anchors[from + 3];
      final level = driver.levelAt((i + 0.5) / barsCount);
      final length = _minLength + level * maxLength;
      final startX = anchors[from] + outX * _gap;
      final startY = centerY + anchors[from + 1] + outY * _gap;
      final endX = startX + outX * length;
      final endY = startY + outY * length;
      final at = i * 8;
      points[at] = centerX + startX;
      points[at + 1] = startY;
      points[at + 2] = centerX + endX;
      points[at + 3] = endY;
      points[at + 4] = centerX - startX;
      points[at + 5] = startY;
      points[at + 6] = centerX - endX;
      points[at + 7] = endY;
    }

    final strength = _strength * opacity * presence;
    final hasSweep = colors.length > 1;
    _paint.color = hasSweep ? Color.fromRGBO(255, 255, 255, strength) : color.withValues(alpha: strength);
    canvas.drawRawPoints(ui.PointMode.lines, points, _paint);
  }

  @override
  bool shouldRepaint(covariant _OutlinePainter oldDelegate) {
    return oldDelegate.artworkScale != artworkScale || oldDelegate.artworkRadius != artworkRadius || super.shouldRepaint(oldDelegate);
  }
}

class _BeatRingsPainter extends _VisualizerPainter {
  final double artworkScale;
  final double artworkRadius;

  _BeatRingsPainter({
    required super.driver,
    required super.colors,
    required super.opacity,
    required this.artworkScale,
    required this.artworkRadius,
  });

  static const _ringsCount = 6;
  static const _lifetime = 0.9;
  static const _growFraction = 0.2;
  static const _thickness = 3.2;
  static const _strength = 0.6;

  final _ages = Float32List(_ringsCount)..fillRange(0, _ringsCount, _lifetime);
  final _strengths = Float32List(_ringsCount);
  int _nextRing = 0;
  int _seenBeats = -1;

  final _paint = Paint()..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final presence = driver.presence;
    if (presence <= 0 || size.isEmpty) return;

    final elapsed = takeElapsed();
    final beatsCount = driver.beatsCount;
    if (_seenBeats != beatsCount) {
      if (_seenBeats != -1) {
        _ages[_nextRing] = 0.0;
        _strengths[_nextRing] = driver.lastBeatStrength;
        _nextRing = (_nextRing + 1) % _ringsCount;
      }
      _seenBeats = beatsCount;
    }

    final core = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.width * artworkScale,
      height: size.height * artworkScale,
    );
    final coreRadius = artworkRadius * artworkScale;
    final maxGrow = size.width * _growFraction;
    final strength = _strength * opacity * presence;

    for (int i = 0; i < _ringsCount; i++) {
      final age = _ages[i] + elapsed;
      if (age >= _lifetime) continue;
      _ages[i] = age;
      final progress = age / _lifetime;
      final remaining = 1 - progress;
      final grown = (1 - remaining * remaining) * maxGrow;
      final ringColor = colors[i % colors.length];
      final alpha = remaining * remaining * (0.5 + 0.5 * _strengths[i]) * strength;
      final bounds = core.inflate(grown);
      final ring = RRect.fromRectAndRadius(bounds, Radius.circular(coreRadius + grown));
      _paint.strokeWidth = _thickness * (0.4 + 0.6 * remaining);
      _paint.color = ringColor.withValues(alpha: alpha);
      canvas.drawRRect(ring, _paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BeatRingsPainter oldDelegate) {
    return oldDelegate.artworkScale != artworkScale || oldDelegate.artworkRadius != artworkRadius || super.shouldRepaint(oldDelegate);
  }
}

class _ReactiveParticlesPainter extends _VisualizerPainter {
  final double artworkScale;

  _ReactiveParticlesPainter({
    required super.driver,
    required super.colors,
    required super.opacity,
    required this.artworkScale,
  });

  static const _capacity = 96;
  static const _perBeat = 16;
  static const _minLife = 0.8;
  static const _maxLife = 1.5;
  static const _minSpeed = 50.0;
  static const _maxSpeed = 170.0;
  static const _minSize = 5.0;
  static const _maxSize = 10.0;
  static const _drag = 1.4;
  static const _strength = 0.9;
  static const _sprite = _Sprite.glow;

  final _random = math.Random();
  final _x = Float32List(_capacity);
  final _y = Float32List(_capacity);
  final _speedX = Float32List(_capacity);
  final _speedY = Float32List(_capacity);
  final _ages = Float32List(_capacity);
  final _lives = Float32List(_capacity);
  final _sizes = Float32List(_capacity);
  final _colorOf = Uint8List(_capacity);
  final _transforms = Float32List(_capacity * 4);
  final _rects = _buildRects();
  final _tints = Int32List(_capacity);
  final _paint = Paint()..filterQuality = FilterQuality.low;
  int _nextParticle = 0;
  int _seenBeats = -1;

  static Float32List _buildRects() {
    final rects = Float32List(_capacity * 4);
    for (int i = 0; i < _capacity; i++) {
      final at = i * 4;
      rects[at] = _sprite.left;
      rects[at + 1] = _sprite.top;
      rects[at + 2] = _sprite.left + _sprite.width;
      rects[at + 3] = _sprite.top + _sprite.height;
    }
    return rects;
  }

  void _burst(Size size, double beatStrength) {
    final halfWidth = size.width * artworkScale / 2;
    final halfHeight = size.height * artworkScale / 2;
    for (int k = 0; k < _perBeat; k++) {
      final i = _nextParticle;
      _nextParticle = (i + 1) % _capacity;
      final heading = _random.nextDouble() * math.pi * 2;
      final outX = math.cos(heading);
      final outY = math.sin(heading);
      final reachX = halfWidth / outX.abs().withMinimum(0.0001);
      final reachY = halfHeight / outY.abs().withMinimum(0.0001);
      final toEdge = math.min(reachX, reachY);
      final speed = (_minSpeed + _random.nextDouble() * (_maxSpeed - _minSpeed)) * (0.6 + 0.4 * beatStrength);
      _x[i] = outX * toEdge;
      _y[i] = outY * toEdge;
      _speedX[i] = outX * speed;
      _speedY[i] = outY * speed;
      _ages[i] = 0.0;
      _lives[i] = _minLife + _random.nextDouble() * (_maxLife - _minLife);
      _sizes[i] = _minSize + _random.nextDouble() * (_maxSize - _minSize);
      _colorOf[i] = _random.nextInt(256);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final presence = driver.presence;
    if (presence <= 0 || size.isEmpty) return;

    final elapsed = takeElapsed();
    final beatsCount = driver.beatsCount;
    if (_seenBeats != beatsCount) {
      if (_seenBeats != -1) _burst(size, driver.lastBeatStrength);
      _seenBeats = beatsCount;
    }

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final slowed = math.exp(-elapsed * _drag);
    final strength = _strength * opacity * presence;
    final anchor = _sprite.width / 2;

    for (int i = 0; i < _capacity; i++) {
      final life = _lives[i];
      final age = _ages[i] + elapsed;
      if (life <= 0 || age >= life) {
        _tints[i] = 0;
        continue;
      }
      _ages[i] = age;
      final x = _x[i] + _speedX[i] * elapsed;
      final y = _y[i] + _speedY[i] * elapsed;
      _x[i] = x;
      _y[i] = y;
      _speedX[i] *= slowed;
      _speedY[i] *= slowed;

      final remaining = 1 - age / life;
      final scale = _sizes[i] * (0.5 + 0.5 * remaining) / _sprite.height;
      final at = i * 4;
      _transforms[at] = scale;
      _transforms[at + 1] = 0.0;
      _transforms[at + 2] = centerX + x - scale * anchor;
      _transforms[at + 3] = centerY + y - scale * anchor;
      final particleColor = colors[_colorOf[i] % colors.length];
      final alphaByte = (remaining * math.sqrt(remaining) * strength * 255).round();
      _tints[i] = (alphaByte << 24) | (particleColor.intValue & 0xFFFFFF);
    }

    final atlas = _SpriteAtlas.obtain();
    canvas.drawRawAtlas(atlas, _transforms, _rects, _tints, BlendMode.modulate, null, _paint);
  }

  @override
  bool shouldRepaint(covariant _ReactiveParticlesPainter oldDelegate) {
    return oldDelegate.artworkScale != artworkScale || super.shouldRepaint(oldDelegate);
  }
}

abstract class _HaloSprite {
  static const _size = 256;
  static const _coreInset = 72.0;
  static const _coreRadius = 18.0;
  static const _blurSigma = 22.0;

  static const source = Rect.fromLTWH(0, 0, 256, 256);

  static ui.Image? _image;
  static Color? _tintColor;
  static ColorFilter? _tint;

  static ui.Image obtain() => _image ??= _paintHalo();

  static Rect destinationFor(Rect core) {
    const coreSize = _size - _coreInset * 2;
    final scaleX = core.width / coreSize;
    final scaleY = core.height / coreSize;
    return Rect.fromLTRB(
      core.left - _coreInset * scaleX,
      core.top - _coreInset * scaleY,
      core.right + _coreInset * scaleX,
      core.bottom + _coreInset * scaleY,
    );
  }

  static ColorFilter tintOf(Color color) {
    final tint = _tint;
    if (tint != null && _tintColor == color) return tint;
    _tintColor = color;
    return _tint = ColorFilter.mode(color, BlendMode.srcIn);
  }

  static ui.Image _paintHalo() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final core = RRect.fromLTRBR(_coreInset, _coreInset, _size - _coreInset, _size - _coreInset, const Radius.circular(_coreRadius));
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _blurSigma);
    canvas.drawRRect(core, paint);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(_size, _size);
    picture.dispose();
    return image;
  }
}

const _kVisualizerParticles = [
  _Emitter(
    motion: _Motion.wander,
    sprites: [_Sprite.dot],
    count: 50,
    minSize: 4.0,
    maxSize: 8.0,
    minSpeed: 0.0,
    maxSpeed: 60.0,
    minAlpha: 0.0,
    maxAlpha: 0.3,
    audio: 1.0,
  ),
];

enum _Placement {
  wallpaper,
  player,
  panel,
  artwork,
}

enum _VisualizerKind {
  particles,
  bars,
  mirroredBars,
  waves,
  edgeLights,
  glow,
  outline,
  beatRings,
  reactiveParticles,
}

extension _VisualizerPlacement on MiniplayerVisualizer {
  _Placement toPlacement() => switch (this) {
    MiniplayerVisualizer.edgeLights => _Placement.player,
    MiniplayerVisualizer.bars || MiniplayerVisualizer.mirroredBars || MiniplayerVisualizer.waves => _Placement.panel,
    MiniplayerVisualizer.glow || MiniplayerVisualizer.outline || MiniplayerVisualizer.beatRings || MiniplayerVisualizer.reactiveParticles => _Placement.artwork,
  };

  _VisualizerKind toKind() => switch (this) {
    MiniplayerVisualizer.bars => _VisualizerKind.bars,
    MiniplayerVisualizer.mirroredBars => _VisualizerKind.mirroredBars,
    MiniplayerVisualizer.waves => _VisualizerKind.waves,
    MiniplayerVisualizer.edgeLights => _VisualizerKind.edgeLights,
    MiniplayerVisualizer.glow => _VisualizerKind.glow,
    MiniplayerVisualizer.outline => _VisualizerKind.outline,
    MiniplayerVisualizer.beatRings => _VisualizerKind.beatRings,
    MiniplayerVisualizer.reactiveParticles => _VisualizerKind.reactiveParticles,
  };
}
