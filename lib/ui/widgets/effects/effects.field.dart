part of 'effects.dart';

class _EffectField extends ChangeNotifier {
  _EffectField._(this.emitters, this.pace) : count = _countOf(emitters) {
    _seed();
  }

  final List<_Emitter> emitters;
  final double pace;
  final int count;

  static final _fields = Map<List<_Emitter>, _EffectField>.identity();

  static _EffectField attach(List<_Emitter> emitters, {required double pace}) {
    final field = _fields[emitters] ??= _EffectField._(emitters, pace);
    field._refs++;
    if (field._refs == 1) field._start();
    return field;
  }

  void detach() {
    _refs--;
    if (_refs == 0) _stop();
  }

  static int _countOf(List<_Emitter> emitters) {
    int count = 0;
    for (final emitter in emitters) {
      count += emitter.count;
    }
    return count;
  }

  static int _hungCountOf(List<_Emitter> emitters) {
    int count = 0;
    for (final emitter in emitters) {
      if (emitter.motion == _Motion.hang) count += emitter.count;
    }
    return count;
  }

  static const _sprites = _Sprite.values;
  static const _twoPi = math.pi * 2;

  static const _wanderPush = 160.0;
  static const _wanderFadeInRate = 0.25;
  static const _driftBobRate = 0.25;

  static const _twinkleSwayRate = 0.12;
  static const _pulsesPerSway = 3.0;

  static const _hangSpread = 0.618034;
  static const _stringRgb = 0xC08A2A;
  static const _stringAlpha = 0.7;

  static const _orbitArms = 2;
  static const _orbitTwist = 5.2;
  static const _orbitScatter = 0.3;
  static const _orbitStray = 0.16;
  static const _orbitTilt = 0.42;
  static const _orbitLeanCos = 0.9004;
  static const _orbitLeanSin = -0.4350;
  static const _orbitSwell = 0.08;
  static const _orbitFlickerRate = 0.3;

  static const _burstGravity = 38.0;
  static const _burstMinLength = 1.3;
  static const _burstMaxLength = 2.0;
  static const _burstBeat = 0.55;
  static const _burstBeatWait = 0.25;

  static const _wireTop = 12.0;
  static const _wireSag = 26.0;
  static const _wireSwagWidth = 190.0;

  final _random = math.Random();
  int _refs = 0;
  double _lastTime = 0.0;
  double _time = 0.0;

  double get time => _time;

  // -- positions are fractions of it, speeds are in pixels
  Size _lastPaintedSize = const Size(400.0, 800.0);

  late final _emitterOf = Uint8List(count);
  late final _spriteOf = Uint8List(count);
  late final _colorOf = Uint8List(count);
  late final _x = Float32List(count);
  late final _y = Float32List(count);
  late final _size = Float32List(count);
  late final _speed = Float32List(count);
  late final _depth = Float32List(count);
  late final _alpha = Float32List(count);
  late final _rate = Float32List(count);
  late final _phase = Float32List(count);
  late final _angle = Float32List(count);
  late final _spin = Float32List(count);
  late final _direction = Float32List(count);

  late final _fadedIn = Float32List(count);
  late final _cycle = Float32List(count);

  late final _burstOf = Uint16List(count);
  late final _burstStart = Float32List(count);
  late final _burstLength = Float32List(count);

  late final _transforms = Float32List(count * 4);
  late final _rects = Float32List(count * 4);
  late final _colors = Int32List(count);

  final _atlasPaint = Paint()..filterQuality = FilterQuality.low;
  final _wirePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;
  final _stringPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  late final _stringPoints = Float32List(_hungCountOf(emitters) * 4);
  late final _hangShift = _random.nextDouble();
  Path? _wire;
  Size _wireExtent = Size.zero;
  late final _hasWire = emitters.any((e) => e.motion == _Motion.string);

  double _between(double min, double max) => min + _random.nextDouble() * (max - min);

  void _seed() {
    int i = 0;
    for (int e = 0; e < emitters.length; e++) {
      final emitter = emitters[e];
      final sprites = emitter.sprites;
      final region = emitter.region;
      for (int slot = 0; slot < emitter.count; slot++, i++) {
        final depth = _random.nextDouble();
        final depthWithNoise = depth * 0.7 + _random.nextDouble() * 0.3;
        final sprite = emitter.isFlapping ? sprites.first : sprites[_random.nextInt(sprites.length)];
        _emitterOf[i] = e;
        _spriteOf[i] = sprite.index;
        _colorOf[i] = _random.nextInt(256);
        _depth[i] = depth;
        _size[i] = emitter.minSize + depth * (emitter.maxSize - emitter.minSize);
        _speed[i] = emitter.minSpeed + depthWithNoise * (emitter.maxSpeed - emitter.minSpeed);
        _alpha[i] = emitter.minAlpha + depthWithNoise * (emitter.maxAlpha - emitter.minAlpha);
        _rate[i] = _between(emitter.minRate, emitter.maxRate);
        _phase[i] = _random.nextDouble() * _twoPi;
        _spin[i] = (_random.nextDouble() - 0.5) * 2 * emitter.spin;
        _angle[i] = emitter.spin > 0 ? _random.nextDouble() * _twoPi : 0.0;
        _setRect(i, sprite);

        switch (emitter.motion) {
          case _Motion.fall || _Motion.rise || _Motion.twinkle:
            _placeInside(i, region);
          case _Motion.drift:
            final heading = _random.nextBool() ? 1.0 : -1.0;
            _placeInside(i, region);
            _direction[i] = heading;
            if (emitter.isFacing) {
              final facing = heading > 0 ? sprites[0] : sprites[1];
              _spriteOf[i] = facing.index;
              _setRect(i, facing);
            }
            if (emitter.isAligned) _angle[i] = math.atan2(-heading, emitter.slope);
            if (emitter.pause > 0) _x[i] = _awayFrom(i, heading, emitter.pause);
          case _Motion.wander:
            _placeInside(i, region);
            _direction[i] = _random.nextDouble() * _twoPi;
            _fadedIn[i] = _random.nextDouble();
          case _Motion.hang:
            final along = (slot + 0.5 + (_random.nextDouble() - 0.5) * 0.5) / emitter.count;
            final hung = sprites[slot % sprites.length];
            final lowered = (slot * _hangSpread + _hangShift) % 1.0;
            _x[i] = region.left + along * region.width;
            _y[i] = region.top + lowered * region.height;
            _spriteOf[i] = hung.index;
            _setRect(i, hung);
          case _Motion.orbit:
            final arm = slot % _orbitArms;
            final alongArm = 0.06 + 0.94 * math.pow(_random.nextDouble(), 0.8);
            final scattered = (_random.nextDouble() + _random.nextDouble() - 1) * _orbitScatter;
            final strayed = (_random.nextDouble() + _random.nextDouble() - 1) * _orbitStray;
            final fromCore = alongArm + strayed;
            _x[i] = fromCore.withMinimum(0.0);
            _direction[i] = arm * _twoPi / _orbitArms + alongArm * _orbitTwist + scattered;
          case _Motion.string:
            _x[i] = (slot + 0.5) / emitter.count;
          case _Motion.burst:
            final burstSize = emitter.burstSize;
            final leader = i - slot % burstSize;
            _burstOf[i] = leader;
            _direction[i] = (slot % burstSize + _random.nextDouble()) / burstSize * _twoPi;
            // -- most of a shell ends up near its rim
            _depth[i] = 0.5 + 0.5 * math.sqrt(depth);
            if (leader == i) _burstStart[i] = _random.nextDouble() * emitter.pause;
        }
        if (emitter.motion == _Motion.fall && emitter.isAligned) _angle[i] = math.atan2(-emitter.wind, _speed[i]);
      }
    }
  }

  double _awayFrom(int i, double heading, double pause) {
    final margin = _size[i] / _lastPaintedSize.width;
    final waited = _random.nextDouble() * pause * _speed[i] / _lastPaintedSize.width;
    return heading > 0 ? -margin - waited : 1 + margin + waited;
  }

  void _launch(int leader, _Emitter emitter, double startAt) {
    final region = emitter.region;
    final colorIndex = _random.nextInt(256);
    _x[leader] = region.left + _random.nextDouble() * region.width;
    _y[leader] = region.top + _random.nextDouble() * region.height;
    _burstStart[leader] = startAt;
    _burstLength[leader] = _between(_burstMinLength, _burstMaxLength);
    final end = leader + emitter.burstSize;
    for (int i = leader; i < end; i++) {
      _colorOf[i] = colorIndex;
    }
  }

  void _placeInside(int i, Rect region) {
    _x[i] = region.left + _random.nextDouble() * region.width;
    _y[i] = region.top + _random.nextDouble() * region.height;
  }

  // -- towards white above 0, towards black under it
  static int _shadeOf(int rgb, double shift) {
    final red = (rgb >> 16) & 0xFF;
    final green = (rgb >> 8) & 0xFF;
    final blue = rgb & 0xFF;
    if (shift > 0) {
      final shadedRed = red + ((255 - red) * shift).round();
      final shadedGreen = green + ((255 - green) * shift).round();
      final shadedBlue = blue + ((255 - blue) * shift).round();
      return (shadedRed << 16) | (shadedGreen << 8) | shadedBlue;
    }
    final kept = 1 + shift;
    final shadedRed = (red * kept).round();
    final shadedGreen = (green * kept).round();
    final shadedBlue = (blue * kept).round();
    return (shadedRed << 16) | (shadedGreen << 8) | shadedBlue;
  }

  void _setRect(int i, _Sprite sprite) {
    final at = i * 4;
    _rects[at] = sprite.left;
    _rects[at + 1] = sprite.top;
    _rects[at + 2] = sprite.left + sprite.width;
    _rects[at + 3] = sprite.top + sprite.height;
  }

  void _start() {
    _lastTime = NamidaFloatClock.instance.seconds;
    SpectrumController.inst.attach(isSpectrumNeeded: false);
    NamidaFloatClock.instance.addListener(_onTick);
  }

  void _stop() {
    NamidaFloatClock.instance.removeListener(_onTick);
    SpectrumController.inst.detach(isSpectrumNeeded: false);
  }

  void _onTick() {
    final clockTime = NamidaFloatClock.instance.seconds;
    final elapsed = (clockTime - _lastTime).clampDouble(0.0, 0.05);
    _lastTime = clockTime;
    if (elapsed <= 0) return;
    _EffectsPulse.update(clockTime, elapsed);
    final dt = elapsed * pace;
    advance(_time + dt, dt);
    notifyListeners();
  }

  void advance(double time, double dt) {
    _time = time;
    final level = _EffectsPulse.level;
    final width = _lastPaintedSize.width;
    final height = _lastPaintedSize.height;
    for (int i = 0; i < count; i++) {
      final emitter = emitters[_emitterOf[i]];
      final push = 1 + emitter.audio * level;
      switch (emitter.motion) {
        case _Motion.fall || _Motion.rise:
          final isFalling = emitter.motion == _Motion.fall;
          final travelled = _speed[i] * push * dt / height;
          final turning = _rate[i] * _twoPi;
          final swayed = math.cos(time * turning + _phase[i]) * emitter.sway * turning * dt / width;
          final blown = emitter.wind * push * dt / width;
          final margin = _size[i] / height;
          double y = isFalling ? _y[i] + travelled : _y[i] - travelled;
          double x = _x[i] + swayed + blown;
          final isGone = isFalling ? y > 1 + margin : y < -margin;
          if (isGone) {
            final region = emitter.region;
            y = isFalling ? -margin : 1 + margin;
            x = region.left + _random.nextDouble() * region.width;
          } else if (x > 1 + margin) {
            x -= 1 + margin * 2;
          }
          _x[i] = x;
          _y[i] = y;
          _angle[i] += _spin[i] * push * dt;

        case _Motion.drift:
          final heading = _direction[i];
          final turning = _driftBobRate * _twoPi;
          final bobbed = math.cos(time * turning + _phase[i]) * emitter.sway * turning * dt / height;
          final margin = _size[i] / width;
          final travelled = _speed[i] * push * dt;
          double x = _x[i] + heading * travelled / width;
          double y = _y[i] + bobbed + emitter.slope * travelled / height;
          final isGone = heading > 0 ? x > 1 + margin : x < -margin;
          if (isGone || y > 1 + margin) {
            final region = emitter.region;
            x = _awayFrom(i, heading, emitter.pause);
            y = region.top + _random.nextDouble() * region.height;
          }
          _x[i] = x;
          _y[i] = y;

        case _Motion.wander:
          final heading = _direction[i];
          final speed = _speed[i] + level * emitter.audio * (1 + _depth[i]) * _wanderPush;
          final x = _x[i] + math.cos(heading) * speed * dt / width;
          final y = _y[i] + math.sin(heading) * speed * dt / height;
          final isGone = x < 0 || x > 1 || y < 0 || y > 1;
          if (isGone) {
            _placeInside(i, emitter.region);
            _direction[i] = _random.nextDouble() * _twoPi;
            _fadedIn[i] = 0.0;
          } else {
            _x[i] = x;
            _y[i] = y;
            final fadedIn = _fadedIn[i] + _wanderFadeInRate * dt;
            _fadedIn[i] = fadedIn > 1 ? 1.0 : fadedIn;
          }

        case _Motion.twinkle:
          if (!emitter.doesRelocate) continue;
          // -- a cycle starts faded out, nobody sees it move
          final cycle = (time * _rate[i] + _phase[i] / _twoPi).floorToDouble();
          if (cycle != _cycle[i]) {
            _cycle[i] = cycle;
            _placeInside(i, emitter.region);
          }

        case _Motion.burst:
          if (_burstOf[i] != i) continue;
          final sinceLaunch = time - _burstStart[i];
          final isOver = sinceLaunch > _burstLength[i];
          final isDue = sinceLaunch > _burstLength[i] + emitter.pause;
          final isOnBeat = emitter.audio > 0 && _EffectsPulse.beat > _burstBeat;
          if (isDue || (isOver && isOnBeat)) {
            // -- staggered, so they never all go off together
            final longestWait = isDue ? emitter.pause : _burstBeatWait;
            final startAt = time + _random.nextDouble() * longestWait;
            _launch(i, emitter, startAt);
          }

        case _Motion.hang || _Motion.string || _Motion.orbit:
          break;
      }
    }
  }

  int _wireSwags = 1;

  double _wireYAt(double x, double width) {
    final alongSwag = (x / width * _wireSwags) % 1.0;
    return _wireTop + math.sin(alongSwag * math.pi) * _wireSag;
  }

  Path _buildWire(double width) {
    const step = 8.0;
    final path = Path()..moveTo(0.0, _wireYAt(0.0, width));
    for (double x = step; x < width + step; x += step) {
      final clamped = x > width ? width - 0.01 : x;
      path.lineTo(clamped, _wireYAt(clamped, width));
    }
    return path;
  }

  void paint(Canvas canvas, Size size, {required int tint, required int ink, required bool isDark, required double opacity}) {
    if (size.isEmpty) return;
    _lastPaintedSize = size;
    final time = _time;
    final level = _EffectsPulse.level;
    final beat = _EffectsPulse.beat;
    final width = size.width;
    final height = size.height;
    final shortestSide = width < height ? width : height;
    int strung = 0;

    if (_hasWire) {
      if (_wire == null || _wireExtent.width != width) {
        _wireSwags = (width / _wireSwagWidth).round().withMinimum(1);
        _wire = _buildWire(width);
        _wireExtent = size;
      }
      final wireAlphaByte = (0.35 * opacity * 255).round();
      _wirePaint.color = Color((wireAlphaByte << 24) | ink);
      canvas.drawPath(_wire!, _wirePaint);
    }

    for (int i = 0; i < count; i++) {
      final emitter = emitters[_emitterOf[i]];
      _Sprite sprite = _sprites[_spriteOf[i]];
      double x = _x[i] * width;
      double y = _y[i] * height;
      double drawnSize = _size[i];
      double rotation = _angle[i];
      double alpha = _alpha[i];

      switch (emitter.motion) {
        case _Motion.fall || _Motion.rise:
          if (emitter.pulse > 0) {
            final pulsed = math.sin(time * _rate[i] * _pulsesPerSway * _twoPi + _phase[i]);
            drawnSize *= 1 + emitter.pulse * pulsed;
          }

        case _Motion.drift:
          if (emitter.isFlapping) {
            final sprites = emitter.sprites;
            final flap = (time * _rate[i] * (1 + emitter.audio * level) + _phase[i]) % 1.0;
            sprite = sprites[(flap * sprites.length).floor()];
            _setRect(i, sprite);
          }
          if (!emitter.isAligned) rotation = math.sin(time * _driftBobRate * _twoPi + _phase[i]) * 0.12 * _direction[i];

        case _Motion.wander:
          alpha *= _fadedIn[i];
          if (emitter.doesFlicker) {
            final flicker = 0.5 + 0.5 * math.sin(time * _rate[i] * _twoPi + _phase[i]);
            alpha *= 0.3 + 0.7 * flicker;
          }

        case _Motion.burst:
          final leader = _burstOf[i];
          final sinceLaunch = time - _burstStart[leader];
          final length = _burstLength[leader];
          if (sinceLaunch < 0 || sinceLaunch > length) {
            alpha = 0.0;
          } else {
            final progress = sinceLaunch / length;
            final remaining = 1 - progress;
            final reach = _speed[i] * _depth[i] * (1 - remaining * remaining * remaining);
            final heading = _direction[i];
            final flicker = 0.75 + 0.25 * math.sin(time * 22.0 + _phase[i]);
            x = _x[leader] * width + math.cos(heading) * reach;
            y = _y[leader] * height + math.sin(heading) * reach + _burstGravity * sinceLaunch * sinceLaunch;
            alpha *= math.sqrt(remaining) * flicker;
            drawnSize *= 0.6 + 0.4 * remaining;
          }

        case _Motion.hang:
          final swing = math.sin(time * _rate[i] * _twoPi + _phase[i]);
          final drop = _y[i] * height;
          final hungFromX = x;
          rotation = swing * emitter.sway * (1 + emitter.audio * level);
          x -= math.sin(rotation) * drop;
          y = math.cos(rotation) * drop;
          final stringAt = strung * 4;
          _stringPoints[stringAt] = hungFromX;
          _stringPoints[stringAt + 1] = 0.0;
          _stringPoints[stringAt + 2] = x;
          _stringPoints[stringAt + 3] = y;
          strung++;

        case _Motion.twinkle:
          final fade = 0.5 - 0.5 * math.cos(time * _rate[i] * _twoPi + _phase[i]);
          final hit = emitter.audio * beat;
          alpha *= emitter.doesRelocate ? fade : 0.35 + 0.65 * fade;
          alpha = (alpha * (1 + hit)).withMaximum(1.0);
          drawnSize *= 1 + 0.25 * hit;
          if (emitter.maxSpeed > 0) {
            final rate = _rate[i];
            final intoCycle = (time * rate + _phase[i] / _twoPi) % 1.0;
            x += math.sin(time * _twinkleSwayRate * _twoPi + _phase[i]) * emitter.sway;
            y -= _speed[i] * (intoCycle - 0.5) / rate;
          }

        case _Motion.orbit:
          final region = emitter.region;
          final turned = _direction[i] + time * _rate[i] * _twoPi;
          final swell = 1 + emitter.audio * level * _orbitSwell;
          final reach = _x[i] * region.width * 0.5 * shortestSide * swell;
          final flatX = math.cos(turned) * reach;
          final flatY = math.sin(turned) * reach * _orbitTilt;
          x = (region.left + region.right) * 0.5 * width + flatX * _orbitLeanCos - flatY * _orbitLeanSin;
          y = (region.top + region.bottom) * 0.5 * height + flatX * _orbitLeanSin + flatY * _orbitLeanCos;
          if (emitter.doesFlicker) {
            final flicker = 0.5 + 0.5 * math.sin(time * _orbitFlickerRate * _twoPi + _phase[i]);
            alpha *= 0.4 + 0.6 * flicker;
          }

        case _Motion.string:
          y = _wireYAt(x, width) + drawnSize * 0.3;
          final lit = 0.5 + 0.5 * math.sin(time * _rate[i] * _twoPi + _phase[i]);
          final hit = emitter.audio * beat;
          final brightness = hit > lit ? hit : lit;
          alpha = emitter.minAlpha + brightness * (emitter.maxAlpha - emitter.minAlpha);
      }

      final scale = drawnSize / sprite.height;
      final scos = math.cos(rotation) * scale;
      final ssin = math.sin(rotation) * scale;
      final anchorX = sprite.width * 0.5;
      final anchorY = sprite.height * sprite.anchorY;
      final at = i * 4;
      _transforms[at] = scos;
      _transforms[at + 1] = ssin;
      _transforms[at + 2] = x - scos * anchorX + ssin * anchorY;
      _transforms[at + 3] = y - ssin * anchorX - scos * anchorY;

      int rgb = 0xFFFFFF;
      if (sprite.isTinted) {
        final colors = isDark ? emitter.colors : emitter.colorsLight ?? emitter.colors;
        if (colors != null) {
          rgb = colors[_colorOf[i] % colors.length];
        } else if (emitter.shades > 0) {
          final shift = (_colorOf[i] / 127.5 - 1) * emitter.shades;
          rgb = _shadeOf(tint, shift);
        } else {
          rgb = tint;
        }
      }
      final alphaByte = (alpha * opacity * 255).round().clampInt(0, 255);
      _colors[i] = (alphaByte << 24) | rgb;
    }

    if (strung > 0) {
      final stringAlphaByte = (_stringAlpha * opacity * 255).round();
      _stringPaint.color = Color((stringAlphaByte << 24) | _stringRgb);
      canvas.drawRawPoints(ui.PointMode.lines, _stringPoints, _stringPaint);
    }

    final atlas = _SpriteAtlas.obtain();
    canvas.drawRawAtlas(atlas, _transforms, _rects, _colors, BlendMode.modulate, null, _atlasPaint);
  }
}

abstract class _EffectsPulse {
  static double level = 0.0;
  static double beat = 0.0;

  static final bands = Float32List(SpectrumController.bandCount);

  static double _updatedAt = -1.0;

  static const _levelTau = 0.12;
  static const _beatTau = 0.2;

  static void update(double time, double dt) {
    if (time == _updatedAt) return;
    _updatedAt = time;

    double loudness = 0.0;
    double hit = 0.0;
    if (Player.inst.isPlaying.value) {
      final spectrum = SpectrumController.inst;
      final positionMS = spectrum.positionMS();
      loudness = WaveformController.inst.getCurrentLevel(positionMS);
      if (spectrum.hasSpectrum) {
        hit = spectrum.sample(positionMS, bands);
      } else {
        hit = ((loudness - level) * 3.0).clampDouble(0.0, 1.0);
      }
    }
    level = loudness + (level - loudness) * math.exp(-dt / _levelTau);
    final faded = beat * math.exp(-dt / _beatTau);
    beat = hit > faded ? hit : faded;
  }
}

class _EffectFieldView extends StatefulWidget {
  final _EffectPreset preset;
  final double opacity;

  const _EffectFieldView({
    required this.preset,
    required this.opacity,
  });

  @override
  State<_EffectFieldView> createState() => _EffectFieldViewState();
}

class _EffectFieldViewState extends State<_EffectFieldView> {
  _EffectField? _field;

  @override
  void didUpdateWidget(covariant _EffectFieldView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.preset.emitters, widget.preset.emitters)) _detach();
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _detach() {
    _field?.detach();
    _field = null;
  }

  @override
  Widget build(BuildContext context) {
    if (namidaAnimationsPaused(context)) {
      _detach();
      return const SizedBox();
    }
    final preset = widget.preset;
    final scenery = preset.scenery;
    final opacity = widget.opacity;
    final field = _field ??= _EffectField.attach(preset.emitters, pace: NamidaEffects._pace);
    if (scenery != _Scenery.aurora) {
      return _EffectFieldCanvas(
        field: field,
        scenery: scenery,
        sceneryColors: const [],
        opacity: opacity,
      );
    }
    return Obx(
      (context) {
        final palette = CurrentColor.inst.palette;
        final sceneryColors = _vividColorsOf(palette, _SceneryBrush.auroraColors);
        return _EffectFieldCanvas(
          field: field,
          scenery: scenery,
          sceneryColors: sceneryColors,
          opacity: opacity,
        );
      },
    );
  }
}

class _EffectFieldCanvas extends StatelessWidget {
  final _EffectField field;
  final _Scenery scenery;
  final List<Color> sceneryColors;
  final double opacity;

  const _EffectFieldCanvas({
    required this.field,
    required this.scenery,
    required this.sceneryColors,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final tint = isDark ? Color.lerp(primary, Colors.white, 0.45)! : primary;
    final ink = isDark ? Colors.white : Colors.black;
    return RepaintBoundary(
      child: CustomPaint(
        painter: _EffectFieldPainter(
          field: field,
          brush: _SceneryBrush(scenery, sceneryColors),
          tint: tint.intValue & 0xFFFFFF,
          ink: ink.intValue & 0xFFFFFF,
          isDark: isDark,
          opacity: opacity,
        ),
      ),
    );
  }
}

class _EffectFieldPainter extends CustomPainter {
  final _EffectField field;
  final _SceneryBrush brush;
  final int tint;
  final int ink;
  final bool isDark;
  final double opacity;

  _EffectFieldPainter({
    required this.field,
    required this.brush,
    required this.tint,
    required this.ink,
    required this.isDark,
    required this.opacity,
  }) : super(repaint: field);

  @override
  void paint(Canvas canvas, Size size) {
    brush.paint(canvas, size, time: field.time, isDark: isDark, opacity: opacity);
    field.paint(canvas, size, tint: tint, ink: ink, isDark: isDark, opacity: opacity);
  }

  @override
  bool shouldRepaint(covariant _EffectFieldPainter oldDelegate) {
    return oldDelegate.field != field ||
        oldDelegate.brush.scenery != brush.scenery ||
        oldDelegate.brush.colors != brush.colors ||
        oldDelegate.tint != tint ||
        oldDelegate.ink != ink ||
        oldDelegate.isDark != isDark ||
        oldDelegate.opacity != opacity;
  }
}
