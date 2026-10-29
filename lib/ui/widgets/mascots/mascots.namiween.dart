part of 'mascots.dart';

abstract class _Namiween {
  static const _catAssetPath = 'assets/namiween/cat.webp';

  /// Offered once per halloween, otherwise the pack only shows to whoever finds the icon.
  static bool offerIconOnce() {
    if (!NamidaChannel.inst.supportsAppIcons) return false;
    if (NamidaEffects.season.value != EffectTheme.halloween) return false;
    if (NamidaChannel.inst.enabledAppIcon.value == NamidaAppIcons.namiween) return false;
    final year = DateTime.now().year;
    if (settings.extra.namiweenOfferedYear.value == year) return false;
    settings.extra.namiweenOfferedYear.save(year);
    snackyy(
      iconWidget: const _NamiweenIcon(
        height: 38.0,
      ),
      title: 'Namiween',
      message: 'namida is knocking.. trick or treat ?',
      displayDuration: SnackDisplayDuration.tutorial,
      button: SnackbarButton(
        text: lang.accept,
        function: () => NamidaChannel.inst.changeAppIcon(NamidaAppIcons.namiween),
      ),
    );
    return true;
  }
}

/// The halloween artwork as a live scene.
///
/// The castle lights fail now and then, sometimes calmly and sometimes like a cheap horror movie.
/// The clouds drift over the castle, bats circle it, namida floats on her broom and the cat
/// blinks from its cloud or from her shoulder, picked anew whenever the scene opens.
class NamiweenScene extends StatefulWidget {
  final Alignment alignment;
  final double opacity;

  const NamiweenScene({
    super.key,
    this.alignment = Alignment.topCenter,
    this.opacity = 1.0,
  });

  @override
  State<NamiweenScene> createState() => _NamiweenSceneState();
}

class _NamiweenSceneState extends State<NamiweenScene> {
  /// The whole art canvas decodes to this width, every layer to its own share of it.
  static const _decodeWidth = 1100;

  final _catPerch = _CatPerch.values[math.Random().nextInt(_CatPerch.values.length)];

  final _cloudsTimeShiftSeconds = math.Random().nextDouble() * 1000.0;

  Map<_NamiweenLayer, ui.Image>? _images;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _disposeImages(_images);
    super.dispose();
  }

  static void _disposeImages(Map<_NamiweenLayer, ui.Image>? images) {
    if (images == null) return;
    for (final image in images.values) {
      image.dispose();
    }
  }

  Future<void> _load() async {
    final images = <_NamiweenLayer, ui.Image>{};
    await Future.wait(
      _NamiweenLayer.values.map((layer) async {
        final rect = _catPerch.rectOf(layer);
        final targetWidth = (_decodeWidth * rect.width).round();
        final image = await NamidaMascots.decodeAsset(layer.assetPath, targetWidth);
        if (image != null) images[layer] = image;
      }),
    );
    // -- a half decoded scene would draw with pieces missing, nothing is better
    final isComplete = images.length == _NamiweenLayer.values.length;
    if (!mounted || !isComplete) {
      _disposeImages(images);
      return;
    }
    setState(() => _images = images);
  }

  @override
  Widget build(BuildContext context) {
    final images = _images;
    final isAnimating = !namidaAnimationsPaused(context);
    final veil = NColorsData.of(context).scaffold.withOpacityExt(1.0 - widget.opacity);
    final sceneWidget = images == null
        ? const SizedBox.expand()
        : RepaintBoundary(
            child: CustomPaint(
              isComplex: true,
              painter: _NamiweenScenePainter(
                images: images,
                catPerch: _catPerch,
                alignment: widget.alignment,
                veil: veil,
                isAnimating: isAnimating,
                cloudsTimeShiftSeconds: _cloudsTimeShiftSeconds,
              ),
            ),
          );
    return AnimatedOpacity(
      opacity: images == null ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 400),
      child: sceneWidget,
    );
  }
}

/// Paints [_NamiweenLayer]s back to front.
///
/// Drawn opaque and then veiled with the page color, a lower opacity per layer would let
/// the castle show through namida.
class _NamiweenScenePainter extends CustomPainter {
  final Map<_NamiweenLayer, ui.Image> images;
  final _CatPerch catPerch;
  final Alignment alignment;
  final bool isAnimating;
  final double cloudsTimeShiftSeconds;
  final Paint _veilPaint;
  final _paint = Paint()..filterQuality = FilterQuality.medium;
  final _batPaint = Paint();

  _NamiweenScenePainter({
    required this.images,
    required this.catPerch,
    required this.alignment,
    required Color veil,
    required this.isAnimating,
    required this.cloudsTimeShiftSeconds,
  }) : _veilPaint = Paint()..color = veil,
       super(repaint: isAnimating ? NamidaFloatClock.instance : null);

  static const _opaque = Color(0xFFFFFFFF);

  static const _artSize = Size(3900.0, 4300.0);

  /// Covers the box and then some, so the floating never walks an edge in.
  static const _zoom = 1.04;

  static const _moonCenter = Offset(0.8585, 0.1232);
  static const _moonGlowRadius = 0.2;
  static const _moonGlowRate = 1 / 6.5;

  static const _figurePivot = Offset(0.42, 0.9);
  static const _floatRate = 1 / 7.5;
  static const _tiltRate = 1 / 9.5;

  static const _sceneSpeed = 0.8;

  static const _cloudFadeOutFraction = 0.15;

  static const _blinkCycleSeconds = 4.7;
  static const _blinkSeconds = 0.18;

  static const _batFadeSeconds = 0.8;
  static final _batFlights = List.generate(6, _BatFlight.ofSlot, growable: false);
  static const _batPoseCount = 8;
  static final _batPoses = List.generate(_batPoseCount, (i) => NamidaBatShape.pathAt(i / (_batPoseCount - 1)), growable: false);

  static final _moonGlowPaint = Paint()
    ..blendMode = BlendMode.plus
    ..shader = ui.Gradient.radial(
      Offset.zero,
      1.0,
      const [Color(0x2EFFF3D6), Color(0x1FFFF3D6), Color(0x00FFF3D6)],
      const [0.0, 0.52, 1.0],
    );

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final cover = math.max(size.width / _artSize.width, size.height / _artSize.height) * _zoom;
    final dest = alignment.inscribe(_artSize * cover, Offset.zero & size);
    final time = NamidaFloatClock.instance.seconds * _sceneSpeed;
    final paint = _paint;

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    _draw(canvas, paint, dest, _NamiweenLayer.sky);
    _drawMoonGlow(canvas, dest, time);

    for (final layer in _NamiweenLayer.flickering) {
      final level = _flickerLevel(time, layer.flickerCycleSeconds!, layer.index);
      if (level > 0.02) _draw(canvas, paint, dest, layer, alpha: level);
    }

    final cloudsTime = time + cloudsTimeShiftSeconds;
    for (final layer in _NamiweenLayer.drifting) {
      final drift = layer.drift!;
      final progress = (cloudsTime / drift.periodSeconds) % 1.0;
      final visibility = ((1.0 - progress) / _cloudFadeOutFraction).withMaximum(1.0);
      final alpha = Curves.easeInOut.transform(visibility);
      if (alpha < 0.02) continue;
      final offset = Offset(-drift.distance * progress * dest.width, 0.0);
      _draw(canvas, paint, dest, layer, offset: offset, alpha: alpha);
    }

    final catRidesHer = catPerch.ridesHer;
    if (!catRidesHer) _drawCat(canvas, paint, dest, time);

    _drawBats(canvas, dest, time);

    final float = math.sin(time * _floatRate * math.pi * 2) * dest.height * 0.005;
    final tilt = math.sin(time * _tiltRate * math.pi * 2 + 0.8) * 0.006;
    final pivot = Offset(dest.left + _figurePivot.dx * dest.width, dest.top + _figurePivot.dy * dest.height);
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy + float);
    canvas.rotate(tilt);
    canvas.translate(-pivot.dx, -pivot.dy);
    _draw(canvas, paint, dest, _NamiweenLayer.namida);
    if (catRidesHer) _drawCat(canvas, paint, dest, time);
    canvas.restore();

    _draw(canvas, paint, dest, _NamiweenLayer.text);

    if (_veilPaint.color.a > 0.0) canvas.drawRect(Offset.zero & size, _veilPaint);
    canvas.restore();
  }

  void _drawMoonGlow(Canvas canvas, Rect dest, double time) {
    final breath = math.sin(time * _moonGlowRate * math.pi * 2);
    final radius = dest.width * _moonGlowRadius * (1 + breath * 0.06);
    canvas.save();
    canvas.translate(dest.left + _moonCenter.dx * dest.width, dest.top + _moonCenter.dy * dest.height);
    canvas.scale(radius);
    canvas.drawCircle(Offset.zero, 1.0, _moonGlowPaint);
    canvas.restore();
  }

  void _drawCat(Canvas canvas, Paint paint, Rect dest, double time) {
    final perch = catPerch;
    _draw(canvas, paint, dest, _NamiweenLayer.cat, rect: perch.cat);
    final eyesOpen = 1.0 - _blinkAmount(time);
    if (eyesOpen <= 0.02) return;
    _draw(canvas, paint, dest, _NamiweenLayer.catEyeLeft, rect: perch.eyeLeft, scaleY: eyesOpen);
    _draw(canvas, paint, dest, _NamiweenLayer.catEyeRight, rect: perch.eyeRight, scaleY: eyesOpen);
  }

  /// A varying few bats circling the castle, nearer and bigger at the bottom of their loop.
  void _drawBats(Canvas canvas, Rect dest, double time) {
    for (int slot = 0; slot < _batFlights.length; slot++) {
      final presence = _batPresence(time, slot);
      if (presence <= 0.01) continue;
      final flight = _batFlights[slot];
      final angle = time * flight.angularSpeed + flight.angleOffset;
      final wobble = math.sin(time * 1.3 + slot * 2.1) * 0.3;

      // -- the flap rate swings up and down, integrated so the wings never jump between poses
      final flapSwingSeconds = flight.flapSwingSeconds;
      final flapSwing = math.sin(time / flapSwingSeconds * math.pi * 2) * 2.5 * flapSwingSeconds / (math.pi * 2);
      final flapCycles = time * flight.flapRate + flapSwing;
      final flap = math.sin(flapCycles * math.pi * 2);
      final wingsLift = (flap + 1.0) / 2.0;
      final pose = _batPoses[(wingsLift * (_batPoseCount - 1)).round()];

      final depth = 0.85 + 0.15 * math.sin(angle);
      final size = flight.size * dest.width * depth * (0.6 + 0.4 * presence);
      final x = dest.left + (flight.center.dx + math.cos(angle) * flight.radiusX) * dest.width;
      final y = dest.top + (flight.center.dy + math.sin(angle + wobble) * flight.radiusY) * dest.height - flap * size * 0.08;
      final roll = -math.sin(angle) * flight.direction * 0.2;
      final scale = size / NamidaBatShape.cellSize;

      _batPaint.color = Color.fromRGBO(11, 7, 16, presence);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(roll);
      canvas.scale(scale);
      canvas.translate(-NamidaBatShape.cellSize / 2, -NamidaBatShape.cellSize / 2);
      canvas.drawPath(pose, _batPaint);
      canvas.restore();
    }
  }

  void _draw(
    Canvas canvas,
    Paint paint,
    Rect dest,
    _NamiweenLayer layer, {
    Rect? rect,
    Offset offset = Offset.zero,
    double alpha = 1.0,
    double scaleY = 1.0,
  }) {
    final image = images[layer];
    if (image == null) return;
    final color = alpha == 1.0 ? _opaque : Color.fromRGBO(255, 255, 255, alpha);
    paint.color = color;
    final placement = rect ?? layer.rect;
    final target = Rect.fromLTRB(
      dest.left + placement.left * dest.width,
      dest.top + placement.top * dest.height,
      dest.left + placement.right * dest.width,
      dest.top + placement.bottom * dest.height,
    ).shift(offset);
    final source = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    if (scaleY == 1.0) {
      canvas.drawImageRect(image, source, target, paint);
      return;
    }
    final center = target.center;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1.0, scaleY);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawImageRect(image, source, target, paint);
    canvas.restore();
  }

  /// `1.0` steadily on, failing now and then: a calm dim in one to three soft waves,
  /// rapid stutters like a bad bulb, or a blackout that stutters back on.
  static double _flickerLevel(double time, double cycleSeconds, int seed) {
    final cycle = (time / cycleSeconds).floor();
    final steady = 0.93 + 0.07 * math.sin(time * 7.3 + seed);
    final kind = _noise(cycle, seed, 0);
    if (kind < 0.2) return steady;
    final isCalm = kind < 0.6;
    final lengthNoise = _noise(cycle, seed, 1);
    final burstSeconds = isCalm ? 1.4 + lengthNoise * 1.8 : 0.35 + lengthNoise * 1.1;
    final burstStart = cycle * cycleSeconds + _noise(cycle, seed, 2) * (cycleSeconds - burstSeconds);
    final burstTime = time - burstStart;
    if (burstTime < 0.0 || burstTime > burstSeconds) return steady;
    final progress = burstTime / burstSeconds;
    if (isCalm) {
      final waves = kind < 0.42 ? 1 : (kind < 0.52 ? 2 : 3);
      final depth = 0.45 + _noise(cycle, seed, 4) * 0.45;
      final wave = math.sin(progress * waves * math.pi);
      return steady * (1.0 - depth * wave * wave);
    }
    final step = (burstTime / 0.045).floor();
    final flick = _noise(step, seed + cycle * 31, 3);
    final isBlackout = kind > 0.86;
    if (isBlackout) {
      if (progress < 0.65) return flick < 0.12 ? 0.35 : 0.0;
      return flick < 0.5 ? steady : 0.05;
    }
    return flick < 0.45 ? 0.04 + flick * 0.2 : steady;
  }

  /// `0.0` gone to `1.0` flying, fading only where it arrives or leaves. The first bat never leaves.
  static double _batPresence(double time, int slot) {
    if (slot == 0) return 1.0;
    final windowSeconds = 6.0 + slot * 1.7;
    final window = (time / windowSeconds).floor();
    bool isFlying(int window) => _noise(window, slot, 12) < 0.5;
    if (!isFlying(window)) return 0.0;
    final windowTime = time - window * windowSeconds;
    final arriving = isFlying(window - 1) ? 1.0 : (windowTime / _batFadeSeconds).withMaximum(1.0);
    final leaving = isFlying(window + 1) ? 1.0 : ((windowSeconds - windowTime) / _batFadeSeconds).withMaximum(1.0);
    return math.min(arriving, leaving);
  }

  /// `0.0` open to `1.0` shut, a quick blink every few seconds and a double one now and then.
  static double _blinkAmount(double time) {
    final cycle = (time / _blinkCycleSeconds).floor();
    final blinkStart = cycle * _blinkCycleSeconds + _noise(cycle, 7, 0) * (_blinkCycleSeconds - 1.0);
    final sinceBlink = time - blinkStart;
    final isDouble = _noise(cycle, 7, 1) > 0.75;
    final blinkTime = isDouble && sinceBlink > _blinkSeconds + 0.12 ? sinceBlink - _blinkSeconds - 0.12 : sinceBlink;
    if (blinkTime < 0.0 || blinkTime > _blinkSeconds) return 0.0;
    return math.sin(blinkTime / _blinkSeconds * math.pi);
  }

  /// Stable `0.0` to `1.0` noise for a tuple of ints.
  static double _noise(int a, int b, int c) {
    var hash = (a * 374761393 + b * 668265263 + c * 1274126177) & 0xFFFFFFFF;
    hash = ((hash ^ (hash >> 13)) * 1274126177) & 0xFFFFFFFF;
    hash ^= hash >> 16;
    return (hash & 0xFFFF) / 0xFFFF;
  }

  @override
  bool shouldRepaint(covariant _NamiweenScenePainter oldDelegate) {
    return oldDelegate.images != images ||
        oldDelegate.catPerch != catPerch ||
        oldDelegate.alignment != alignment ||
        oldDelegate.isAnimating != isAnimating ||
        oldDelegate.cloudsTimeShiftSeconds != cloudsTimeShiftSeconds ||
        oldDelegate._veilPaint.color != _veilPaint.color;
  }
}

class _NamiweenIcon extends StatelessWidget {
  final double height;

  const _NamiweenIcon({required this.height});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      NamidaAppIcons.namiween.assetPath,
      height: height,
      cacheHeight: (height * MediaQuery.devicePixelRatioOf(context)).round(),
    );
  }
}

class _NamiweenFigure extends StatelessWidget {
  static const _catHeightFactor = 0.7;

  final double height;
  final double opacity;

  const _NamiweenFigure({
    required this.height,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    final catHeight = height * _catHeightFactor;
    return FloatingImage(
      amplitude: 4.0,
      cycleDuration: const Duration(seconds: 16),
      rotationAmplitude: 0.03,
      scaleAmplitude: 0.02,
      child: Image.asset(
        _Namiween._catAssetPath,
        height: catHeight,
        cacheHeight: (catHeight * MediaQuery.devicePixelRatioOf(context)).round(),
        opacity: opacity == 1.0 ? null : AlwaysStoppedAnimation(opacity),
      ),
    );
  }
}

class _NamiweenListEnd extends StatelessWidget {
  static const _height = 110.0;

  const _NamiweenListEnd();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32.0),
      child: Center(
        child: FloatingImage(
          amplitude: 4.0,
          cycleDuration: const Duration(seconds: 18),
          rotationAmplitude: 0.04,
          scaleAmplitude: 0.02,
          child: Image.asset(
            _Namiween._catAssetPath,
            height: _height,
            cacheHeight: (_height * MediaQuery.devicePixelRatioOf(context)).round(),
            opacity: const AlwaysStoppedAnimation(0.5),
          ),
        ),
      ),
    );
  }
}

/// Where the cat sits instead of the broom, as fractions of the art canvas.
enum _CatPerch {
  cloud(
    cat: Rect.fromLTRB(0.6040, 0.0620, 0.6734, 0.1520),
    eyeLeft: Rect.fromLTRB(0.6141, 0.1314, 0.6210, 0.1352),
    eyeRight: Rect.fromLTRB(0.6245, 0.1295, 0.6291, 0.1341),
    ridesHer: false,
  ),
  shoulder(
    cat: Rect.fromLTRB(0.4200, 0.2180, 0.5434, 0.3780),
    eyeLeft: Rect.fromLTRB(0.4380, 0.3415, 0.4503, 0.3481),
    eyeRight: Rect.fromLTRB(0.4564, 0.3381, 0.4646, 0.3461),
    ridesHer: true,
  ),
  ;

  final Rect cat;
  final Rect eyeLeft;
  final Rect eyeRight;

  /// Sitting on her shoulder, so it floats along with her.
  final bool ridesHer;

  const _CatPerch({
    required this.cat,
    required this.eyeLeft,
    required this.eyeRight,
    required this.ridesHer,
  });

  Rect rectOf(_NamiweenLayer layer) => switch (layer) {
    _NamiweenLayer.cat => cat,
    _NamiweenLayer.catEyeLeft => eyeLeft,
    _NamiweenLayer.catEyeRight => eyeRight,
    _NamiweenLayer.sky ||
    _NamiweenLayer.lightLeftTower ||
    _NamiweenLayer.lightTower ||
    _NamiweenLayer.lightDots ||
    _NamiweenLayer.cloudLeft ||
    _NamiweenLayer.cloudRight ||
    _NamiweenLayer.namida ||
    _NamiweenLayer.text => layer.rect,
  };
}

/// How one bat circles the castle, sizes and center are fractions of the art canvas.
class _BatFlight {
  final double direction;
  final double angularSpeed;
  final double angleOffset;
  final Offset center;
  final double radiusX;
  final double radiusY;
  final double flapRate;
  final double flapSwingSeconds;
  final double size;

  const _BatFlight({
    required this.direction,
    required this.angularSpeed,
    required this.angleOffset,
    required this.center,
    required this.radiusX,
    required this.radiusY,
    required this.flapRate,
    required this.flapSwingSeconds,
    required this.size,
  });

  static const _castleCenter = Offset(0.80, 0.25);

  factory _BatFlight.ofSlot(int slot) {
    double noise(int index) => _NamiweenScenePainter._noise(slot, 11, index);
    final direction = noise(4) < 0.5 ? -1.0 : 1.0;
    final center = _castleCenter + Offset((noise(2) - 0.5) * 0.08, (noise(3) - 0.5) * 0.12);
    return _BatFlight(
      direction: direction,
      angularSpeed: (0.3 + noise(5) * 0.35) * direction,
      angleOffset: noise(6) * math.pi * 2,
      center: center,
      radiusX: 0.05 + noise(0) * 0.07,
      radiusY: 0.025 + noise(1) * 0.045,
      flapRate: 6.5 + noise(7) * 1.5,
      flapSwingSeconds: 5.0 + noise(8) * 4.0,
      size: 0.026 + noise(9) * 0.014,
    );
  }
}

/// The halloween artwork split into pieces that move on their own, back to front.
///
/// [rect] is where a piece sits inside the art canvas as fractions of it, so each ships
/// cropped instead of on a full size canvas. The cat never stays on the broom it was drawn on,
/// the page fades the bottom of the art away, [_CatPerch] moves it up. The clouds sit higher than drawn for the same reason.
enum _NamiweenLayer {
  sky('assets/namiween/layers/sky.webp', Rect.fromLTRB(0.0, 0.0, 1.0, 1.0)),
  lightLeftTower('assets/namiween/layers/light_left_tower.webp', Rect.fromLTRB(0.7254, 0.3691, 0.7454, 0.3965), flickerCycleSeconds: 5.3),
  lightTower('assets/namiween/layers/light_tower.webp', Rect.fromLTRB(0.7828, 0.3098, 0.8000, 0.3533), flickerCycleSeconds: 7.1),
  lightDots('assets/namiween/layers/light_dots.webp', Rect.fromLTRB(0.8446, 0.3647, 0.8808, 0.4223), flickerCycleSeconds: 9.4),
  cloudLeft('assets/namiween/layers/cloud_left.webp', Rect.fromLTRB(1.0, 0.3491, 1.2428, 0.5056), drift: _CloudDrift(distance: 0.58, periodSeconds: 71.0)),
  cloudRight('assets/namiween/layers/cloud_right.webp', Rect.fromLTRB(1.0, 0.4191, 1.1592, 0.5872), drift: _CloudDrift(distance: 0.50, periodSeconds: 40.0)),
  namida('assets/namiween/layers/namida.webp', Rect.fromLTRB(0.0, 0.0205, 1.0, 1.0)),
  cat('assets/namiween/layers/cat.webp', Rect.fromLTRB(0.0779, 0.6395, 0.3559, 1.0)),
  catEyeLeft('assets/namiween/layers/cat_eye_left.webp', Rect.fromLTRB(0.1185, 0.9177, 0.1462, 0.9326)),
  catEyeRight('assets/namiween/layers/cat_eye_right.webp', Rect.fromLTRB(0.1600, 0.9100, 0.1785, 0.9281)),
  text('assets/namiween/layers/text.webp', Rect.fromLTRB(0.4028, 0.6633, 0.8082, 0.9791)),
  ;

  final String assetPath;
  final Rect rect;

  /// Castle windows that fail now and then, each on its own cycle so they never fail together.
  final double? flickerCycleSeconds;

  /// Clouds start at [rect], past the right edge, and drift left over the castle.
  final _CloudDrift? drift;

  const _NamiweenLayer(this.assetPath, this.rect, {this.flickerCycleSeconds, this.drift});

  static final flickering = values.where((e) => e.flickerCycleSeconds != null).toFixedList();
  static final drifting = values.where((e) => e.drift != null).toFixedList();
}

/// Moves left by [distance] of the art width every [periodSeconds], fading out behind her at the end.
///
/// The cloud drawn on top drifts faster, the speed difference reads as depth.
class _CloudDrift {
  final double distance;
  final double periodSeconds;

  const _CloudDrift({required this.distance, required this.periodSeconds});
}
