// fully by claude (no mistakes), me no math
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:namida/class/color_m.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/waveform_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/floating_image.dart';

/// How hard the currently playing track is hitting right now, `0.0` when nothing plays.
double _playbackPulse() {
  if (!Player.inst.isPlaying.value) return 0.0;
  final bars = WaveformController.inst.currentWaveformUIRx.value;
  if (bars.isEmpty) return 0.0;
  final durationMS = Player.inst.currentItemDuration.value?.inMilliseconds ?? 0;
  if (durationMS <= 0) return 0.0;
  final index = (Player.inst.nowPlayingPosition.value / durationMS * bars.length).floor().clamp(0, bars.length - 1);
  final bar = bars[index];
  if (bar <= 0) return 0.0;
  return (bar / 64.0).clamp(0.0, 1.0); // -- waveform bars are clamped to 64
}

/// How far a bell is squeezed at [time], `0.0` fully relaxed through `1.0` fully contracted.
double _jellyContraction(double time, double rate, double phase) {
  final progress = (time * rate + phase) % 1.0;
  const squeezePortion = 0.22;
  if (progress < squeezePortion) return Curves.easeOutCubic.transform(progress / squeezePortion);
  return 1.0 - Curves.easeInOutSine.transform((progress - squeezePortion) / (1 - squeezePortion));
}

/// A loose bloom of jellies, sharing a drift and pulsing roughly together.
class _JellyGroup {
  late double driftOffset;
  late double pulsePhase;
  late double band;
  late double speedFactor;
}

class _Jelly {
  late _JellyGroup group;
  late NamidaJelly art;
  late bool flipX;

  /// Rotation from how the art was drawn to where it settles, capped so it never warps.
  late double settledRotation;

  /// Extra rotation it drifted in with, decays away as it rights itself upward.
  late double tilt;
  late double rightingTau;

  late double swayAmplitude, swayRate, swayPhase;

  /// Where the bell points right now, this is what the pulse pushes against.
  double orientation = 0.0;

  /// Position and speed live in a unit square, so any sized field can draw the same swarm.
  late double x, y;
  late double driftAngle, driftSpeed;
  late double thrust, sink;

  /// `0.0` to `1.0` across whatever height range the field asks for.
  late double sizeFactor;

  late double alpha;
  late double pulseRate, pulsePhase;
  late double bobAmplitude, bobRate, bobPhase;
}

/// What makes two fields the same swarm, everything else is presentation.
typedef _SwarmKey = ({int seed, int count, int groups, double driftAngle, bool reactToPlayback});

/// The jellies themselves, kept outside the widget tree.
///
/// Fields come and go as pages are navigated, the swarm doesn't: it holds its
/// positions so a new page picks the jellies up mid-swim instead of reseeding them,
/// and several fields sharing a key all draw the very same swarm. Ticking stops
/// whenever nothing is on screen to draw it.
class _JellySwarm extends ChangeNotifier {
  _JellySwarm._(this.key) {
    _seed();
  }

  final _SwarmKey key;
  final jellies = <_Jelly>[];
  final _groups = <_JellyGroup>[];
  late final _rng = math.Random(key.seed);

  double pulse = 0.0;
  int _refs = 0;
  double _lastTime = 0.0;

  /// Speeds were tuned against a surface about this tall, in logical pixels.
  static const _referenceExtent = 400.0;

  /// Travel is scaled down from what it was first tuned at, they drift rather than swim off.
  static const _speedScale = 0.55;
  static const _spawnMargin = 0.25;
  static const _despawnMargin = 0.45;
  static const _upright = math.pi / 2;
  static const _spawnTilt = 25 * math.pi / 180;

  // -- swarms are tiny and outlive any page, so they are cached rather than disposed
  static final _swarms = <_SwarmKey, _JellySwarm>{};

  static _JellySwarm attach(_SwarmKey key) {
    final swarm = _swarms[key] ??= _JellySwarm._(key);
    swarm._refs++;
    if (swarm._refs == 1) {
      swarm._lastTime = NamidaFloatClock.instance.seconds;
      NamidaFloatClock.instance.addListener(swarm._onTick);
    }
    return swarm;
  }

  void detach() {
    _refs--;
    if (_refs <= 0) {
      _refs = 0;
      NamidaFloatClock.instance.removeListener(_onTick);
    }
  }

  double _between(double min, double max) => min + _rng.nextDouble() * (max - min);

  /// Box-Muller, so orientations cluster around upright instead of spreading evenly.
  double _gaussian() {
    final u1 = 1.0 - _rng.nextDouble();
    final u2 = _rng.nextDouble();
    return (math.sqrt(-2.0 * math.log(u1)) * math.cos(2 * math.pi * u2)).clampDouble(-2.5, 2.5);
  }

  void _seed() {
    final groupCount = math.max(1, math.min(key.groups, key.count));
    for (int i = 0; i < groupCount; i++) {
      _groups.add(
        _JellyGroup()
          ..driftOffset = (_rng.nextDouble() - 0.5) * 0.5
          ..pulsePhase = _rng.nextDouble()
          ..band = (i + 0.5) / groupCount
          ..speedFactor = _between(0.75, 1.3),
      );
    }
    for (int i = 0; i < key.count; i++) {
      final jelly = _Jelly()..group = _groups[i % groupCount];
      _respawn(jelly, initial: true);
      jellies.add(jelly);
    }
  }

  void _respawn(_Jelly jelly, {bool initial = false}) {
    final group = jelly.group;

    // -- smaller ones read as further away, so they drift slower and dimmer
    final depth = jelly.sizeFactor = _rng.nextDouble();

    // -- orientation clusters around upright, a jellyfish never swims belly up
    final wanted = (_upright + _gaussian() * (40 * math.pi / 180)).clampDouble(0.0, math.pi);
    final pose = JellyPose.resolve(wanted);
    jelly.art = pose.jelly;
    jelly.flipX = pose.flipX;
    // -- it settles leaning upward, as far as the art tolerates being turned
    jelly.settledRotation = (_upright - pose.restingAngle).clampDouble(-kJellyMaxArtRotation, kJellyMaxArtRotation);
    jelly.tilt = (_rng.nextDouble() - 0.5) * 2 * _spawnTilt;
    jelly.rightingTau = _between(4.0, 12.0);

    jelly.swayAmplitude = _between(0.03, 0.10);
    jelly.swayRate = _between(0.04, 0.10);
    jelly.swayPhase = _rng.nextDouble() * math.pi * 2;

    jelly.driftAngle = key.driftAngle + group.driftOffset + (_rng.nextDouble() - 0.5) * 0.16;
    jelly.driftSpeed = _between(3.0, 8.0) * _speedScale / _referenceExtent * group.speedFactor * (0.5 + depth);
    jelly.thrust = _between(5.0, 12.0) * _speedScale / _referenceExtent * (0.5 + depth);
    // -- a squeeze averages 0.555 of full thrust and the relax 0.445, so 1.247x cancels it out.
    // -- straddling that leaves each jelly wandering a touch up or down, never climbing away.
    jelly.sink = jelly.thrust * _between(1.12, 1.40);
    jelly.alpha = _between(0.35, 1.0) * (0.55 + 0.45 * depth);
    jelly.pulseRate = _between(0.14, 0.26);
    jelly.pulsePhase = group.pulsePhase + (_rng.nextDouble() - 0.5) * 0.16;
    jelly.bobAmplitude = _between(3.0, 9.0);
    jelly.bobRate = _between(0.06, 0.15);
    jelly.bobPhase = _rng.nextDouble() * math.pi * 2;

    if (initial) {
      jelly.x = _rng.nextDouble();
      jelly.y = _rng.nextDouble();
      return;
    }

    // -- enter from the edge the current comes from, grouped along their bloom's band
    final dx = math.cos(jelly.driftAngle);
    final dy = -math.sin(jelly.driftAngle);
    double alongBand() => (group.band + (_rng.nextDouble() - 0.5) * 0.24).clampDouble(0.0, 1.0);
    if (dx.abs() > dy.abs()) {
      jelly.x = dx >= 0 ? -_spawnMargin : 1 + _spawnMargin;
      jelly.y = alongBand();
    } else {
      jelly.y = dy >= 0 ? -_spawnMargin : 1 + _spawnMargin;
      jelly.x = alongBand();
    }
  }

  void _onTick() {
    final time = NamidaFloatClock.instance.seconds;
    final dt = (time - _lastTime).clampDouble(0.0, 0.05);
    _lastTime = time;
    if (dt <= 0) return;

    if (key.reactToPlayback) {
      // -- damped so a quiet bar doesn't drop the whole swarm mid-swim
      final target = _playbackPulse();
      pulse = target + (pulse - target) * math.exp(-dt / 0.22);
    }

    for (final jelly in jellies) {
      // -- rights itself back toward upright
      jelly.tilt *= math.exp(-dt / jelly.rightingTau);
      jelly.orientation = orientationOf(jelly, swayOf(jelly, time));

      final contract = contractionOf(jelly, time);
      var vx = math.cos(jelly.driftAngle) * jelly.driftSpeed;
      var vy = -math.sin(jelly.driftAngle) * jelly.driftSpeed;
      // -- every squeeze shoves it along its own bell axis, then it sinks back while relaxing
      final thrust = jelly.thrust * contract;
      vx += math.cos(jelly.orientation) * thrust;
      vy += -math.sin(jelly.orientation) * thrust;
      vy += jelly.sink * (1 - contract);

      jelly.x += vx * dt;
      jelly.y += vy * dt;

      if (jelly.x < -_despawnMargin || jelly.x > 1 + _despawnMargin || jelly.y < -_despawnMargin || jelly.y > 1 + _despawnMargin) {
        _respawn(jelly);
      }
    }
    notifyListeners();
  }

  double rotationOf(_Jelly jelly, double sway) => jelly.settledRotation + jelly.tilt + sway;

  double orientationOf(_Jelly jelly, double sway) {
    final angle = jelly.art.bellAngle * math.pi / 180;
    final resting = jelly.flipX ? math.pi - angle : angle;
    return resting + rotationOf(jelly, sway);
  }

  double swayOf(_Jelly jelly, double time) => math.sin(time * jelly.swayRate * math.pi * 2 + jelly.swayPhase) * jelly.swayAmplitude;

  double contractionOf(_Jelly jelly, double time) => _jellyContraction(time, jelly.pulseRate, jelly.pulsePhase);
}

/// A drifting field of jellyfishes, painted as one layer.
///
/// Every field shares [NamidaFloatClock] and paints into a single [CustomPaint], so it
/// costs one ticker and one repaint boundary regardless of [count]. Fields with matching
/// [seed], [count], [groups], [driftAngle] and [reactToPlayback] draw the same swarm,
/// which lives on between pages so navigating never restarts the drift.
///
/// Jellies keep themselves upright: which way the bell points is independent of where
/// they travel, and any tilt they spawn with decays away. Travel is a slow shared
/// current plus the little shove each bell squeeze gives, against a gentle sink.
class JellyField extends StatefulWidget {
  final int count;

  /// Recolors the jellies toward this, defaults to the theme secondary.
  final Color? tint;

  /// How far the original blue is pushed into [tint], `1.0` leaves none of it, `0.0` keeps the artwork as drawn.
  final double tintStrength;
  final double opacity;

  /// Drawn height range in logical pixels.
  final double minHeight;
  final double maxHeight;

  /// The current everything drifts along, in radians (0 = right, math convention).
  final double driftAngle;

  /// How many blooms the field is split into, each drifting and pulsing together.
  final int groups;

  /// Jellies squeeze their bell in time with the playing track.
  final bool reactToPlayback;

  final bool enabled;
  final int seed;

  const JellyField({
    super.key,
    this.count = 5,
    this.tint,
    this.tintStrength = kJellyDefaultTintStrength,
    this.opacity = 0.5,
    this.minHeight = 80.0,
    this.maxHeight = 220.0,
    this.driftAngle = 0.14,
    this.groups = 3,
    this.reactToPlayback = false,
    this.enabled = true,
    this.seed = 0,
  });

  @override
  State<JellyField> createState() => _JellyFieldState();
}

class _JellyFieldState extends State<JellyField> {
  _JellySwarm? _swarm;
  bool _imagesReady = NamidaJellys.imagesReady;

  _SwarmKey get _key => (
    seed: widget.seed,
    count: widget.count,
    groups: widget.groups,
    driftAngle: widget.driftAngle,
    reactToPlayback: widget.reactToPlayback,
  );

  @override
  void initState() {
    super.initState();
    if (!_imagesReady) {
      NamidaJellys.ensureImagesLoaded().then((_) {
        if (mounted) setState(() => _imagesReady = true);
      });
    }
  }

  @override
  void didUpdateWidget(covariant JellyField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_swarm != null && _swarm!.key != _key) _detach();
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _attach() {
    _swarm ??= _JellySwarm.attach(_key);
  }

  void _detach() {
    _swarm?.detach();
    _swarm = null;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || !_imagesReady || namidaAnimationsDisabled(context)) {
      _detach();
      return const SizedBox();
    }
    _attach();
    return RepaintBoundary(
      child: CustomPaint(
        isComplex: true,
        painter: _JellyFieldPainter(
          swarm: _swarm!,
          tint: widget.tint ?? context.theme.colorScheme.primary,
          tintStrength: widget.tintStrength,
          opacity: widget.opacity,
          minHeight: widget.minHeight,
          maxHeight: widget.maxHeight,
        ),
      ),
    );
  }
}

class _JellyFieldPainter extends CustomPainter {
  final _JellySwarm swarm;
  final Color? tint;
  final double tintStrength;
  final double opacity;
  final double minHeight;
  final double maxHeight;

  _JellyFieldPainter({
    required this.swarm,
    required this.tint,
    required this.tintStrength,
    required this.opacity,
    required this.minHeight,
    required this.maxHeight,
  }) : super(repaint: swarm);

  @override
  void paint(Canvas canvas, Size size) {
    final tint = this.tint;
    _paintJellySwarm(
      canvas,
      size,
      swarm,
      opacity: opacity,
      minHeight: minHeight,
      maxHeight: maxHeight,
      colorFilter: tint == null || tintStrength <= 0 ? null : NamidaJellys.tintFilter(tint, tintStrength),
    );
  }

  @override
  bool shouldRepaint(covariant _JellyFieldPainter oldDelegate) {
    return oldDelegate.swarm != swarm ||
        oldDelegate.tint != tint ||
        oldDelegate.tintStrength != tintStrength ||
        oldDelegate.opacity != opacity ||
        oldDelegate.minHeight != minHeight ||
        oldDelegate.maxHeight != maxHeight;
  }
}

/// Draws every jelly of [swarm] into [size], the one place the swarm is ever rendered.
void _paintJellySwarm(
  Canvas canvas,
  Size size,
  _JellySwarm swarm, {
  required double opacity,
  required double minHeight,
  required double maxHeight,
  ColorFilter? colorFilter,
}) {
  if (size.isEmpty) return;
  final time = NamidaFloatClock.instance.seconds;
  final fadeBand = math.min(size.width, size.height) * 0.22;
  final paint = Paint()
    ..filterQuality = FilterQuality.low
    ..colorFilter = colorFilter;

  for (final jelly in swarm.jellies) {
    final image = NamidaJellys.imageOf(jelly.art);
    if (image == null) continue;

    final bob = math.sin(time * jelly.bobRate * math.pi * 2 + jelly.bobPhase) * jelly.bobAmplitude;
    // -- the swarm swims in a unit square, so a resizing box carries it along
    // -- instead of leaving the jellies behind wherever they were in pixels
    final x = jelly.x * size.width;
    final y = jelly.y * size.height + bob;

    final edgeDistance = math.min(math.min(x, size.width - x), math.min(y, size.height - y));
    final edgeFade = (edgeDistance / fadeBand).clampDouble(0.0, 1.0);
    final alpha = jelly.alpha * edgeFade * opacity;
    if (alpha <= 0.01) continue;
    paint.color = Color.fromRGBO(255, 255, 255, alpha);

    final contract = swarm.contractionOf(jelly, time);
    final squash = (0.06 + 0.14 * swarm.pulse) * contract;
    final rotation = swarm.rotationOf(jelly, swarm.swayOf(jelly, time));
    final orientation = jelly.orientation;

    final height = minHeight + jelly.sizeFactor * (maxHeight - minHeight);
    final width = height * image.width / image.height;
    final bell = jelly.art.bellAlignment;

    canvas.save();
    canvas.translate(x, y);
    // -- squeeze along the bell axis, the bell widens as it contracts
    canvas.rotate(-orientation);
    canvas.scale(1 - squash, 1 + squash * 0.6);
    canvas.rotate(orientation);
    // -- canvas y grows downward, so a math-positive rotation is a negative one here
    canvas.rotate(-rotation);
    if (jelly.flipX) canvas.scale(-1.0, 1.0);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(
        -width / 2 - bell.x * width / 2,
        -height / 2 - bell.y * height / 2,
        width,
        height,
      ),
      paint,
    );
    canvas.restore();
  }
}

/// A [JellyField] tinted with the current track color, ready to drop behind any page.
///
/// Renders nothing unless the user let the jellyfishes in.
class NamidaJellyBackground extends StatelessWidget {
  final int count;
  final double opacity;
  final double minHeight;
  final double maxHeight;
  final bool reactToPlayback;

  /// Keeps the widget mounted while pausing the swarm, so hiding it doesn't churn siblings.
  final bool enabled;
  final int seed;

  const NamidaJellyBackground({
    super.key,
    this.count = 5,
    this.opacity = 0.4,
    this.minHeight = 80.0,
    this.maxHeight = 220.0,
    this.reactToPlayback = false,
    this.enabled = true,
    this.seed = 0,
  });

  static const NamidaJellyBackground forSettingsPage = NamidaJellyBackground(
    count: 6,
    opacity: 0.32,
    minHeight: 90.0,
    maxHeight: 260.0,
  );

  @override
  Widget build(BuildContext context) {
    if (!NamidaJellys.enabled) return const SizedBox();
    return IgnorePointer(
      child: JellyField(
        count: count,
        opacity: opacity,
        minHeight: minHeight,
        maxHeight: maxHeight,
        reactToPlayback: reactToPlayback,
        enabled: enabled,
        seed: seed,
      ),
    );
  }
}

/// A single jellyfish drifting in place, for spots where a whole field would be noise.
class FloatingJelly extends StatelessWidget {
  final NamidaJelly jelly;
  final double height;
  final Color? tint;
  final double tintStrength;
  final double opacity;
  final bool mirrored;
  final double amplitude;
  final Duration cycleDuration;
  final int? seed;

  const FloatingJelly({
    super.key,
    this.jelly = NamidaJelly.jelly170d,
    this.height = 160.0,
    this.tint,
    this.tintStrength = kJellyDefaultTintStrength,
    this.opacity = 1.0,
    this.mirrored = false,
    this.amplitude = 6.0,
    this.cycleDuration = const Duration(seconds: 9),
    this.seed,
  });

  @override
  Widget build(BuildContext context) {
    final tint = this.tint ?? context.theme.colorScheme.primary;
    Widget image = ColorFiltered(
      colorFilter: NamidaJellys.tintFilter(tint, tintStrength),
      child: Image.asset(
        jelly.assetPath,
        height: height,
        cacheHeight: (height * MediaQuery.devicePixelRatioOf(context)).round(),
        opacity: opacity == 1.0 ? null : AlwaysStoppedAnimation(opacity),
      ),
    );
    if (mirrored) {
      image = Transform.flip(flipX: true, child: image);
    }
    return FloatingImage(
      amplitude: amplitude,
      cycleDuration: cycleDuration,
      rotationAmplitude: 0.05,
      scaleAmplitude: 0.02,
      alignment: mirrored ? Alignment(-jelly.bellAlignment.x, jelly.bellAlignment.y) : jelly.bellAlignment,
      seed: seed,
      child: image,
    );
  }
}

/// A jellyfish resting at the very bottom of a long list, marking its end.
class JellyListEnd extends StatefulWidget {
  final double height;

  const JellyListEnd({super.key, this.height = 128.0});

  @override
  State<JellyListEnd> createState() => _JellyListEndState();
}

class _JellyListEndState extends State<JellyListEnd> {
  late final List<_RestingJelly> _jellies;

  @override
  void initState() {
    super.initState();
    final rng = math.Random();
    const randomJelly = false;
    // final randomCount = 1 + rng.nextInt(3);
    final randomCount = 1;
    _jellies = List.generate(randomCount, (i) {
      return _RestingJelly(
        // ignore: dead_code
        jelly: randomJelly ? NamidaJelly.values[rng.nextInt(NamidaJelly.values.length)] : NamidaJelly.jelly70d,
        mirrored: rng.nextBool(),
        // -- staggered sizes so a group reads as depth instead of a row of clones
        scale: 0.65 + rng.nextDouble() * 0.45,
        verticalOffset: (rng.nextDouble() - 0.5) * 0.3,
        cycleSeconds: 16 + rng.nextInt(9),
        seed: rng.nextInt(1 << 30),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!NamidaJellys.enabled) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32.0),
      child: Builder(
        builder: (context) {
          final tint = context.theme.colorScheme.primary;
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _jellies.map(
              (e) {
                final height = widget.height * e.scale;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
                  child: Transform.translate(
                    offset: Offset(0, height * e.verticalOffset),
                    child: FloatingJelly(
                      jelly: e.jelly,
                      mirrored: e.mirrored,
                      height: height,
                      tint: tint,
                      opacity: 0.5,
                      amplitude: 4.0,
                      cycleDuration: Duration(seconds: e.cycleSeconds),
                      seed: e.seed,
                    ),
                  ),
                );
              },
            ).toList(),
          );
        },
      ),
    );
  }
}

class _RestingJelly {
  final NamidaJelly jelly;
  final bool mirrored;
  final double scale;
  final double verticalOffset;
  final int cycleSeconds;
  final int seed;

  const _RestingJelly({
    required this.jelly,
    required this.mirrored,
    required this.scale,
    required this.verticalOffset,
    required this.cycleSeconds,
    required this.seed,
  });
}

/// A jellyfish holding a progress percentage inside its bell, for loading & empty states.
class JellyLoader extends StatelessWidget {
  /// `0.0` to `1.0`, null leaves the bell empty.
  final double? percentage;
  final double height;
  final Color? tint;

  const JellyLoader({
    super.key,
    this.percentage,
    this.height = 190.0,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    const art = NamidaJelly.jelly70d;
    final percentage = this.percentage;
    final tint = this.tint ?? context.theme.colorScheme.primary;
    return SizedBox(
      height: height,
      child: FloatingImage(
        amplitude: 5.0,
        cycleDuration: const Duration(seconds: 7),
        rotationAmplitude: 0.04,
        scaleAmplitude: 0.03,
        alignment: art.bellAlignment,
        child: Stack(
          alignment: art.bellAlignment,
          children: [
            ColorFiltered(
              colorFilter: NamidaJellys.tintFilter(tint, kJellyDefaultTintStrength),
              child: Image.asset(
                art.assetPath,
                height: height,
                cacheHeight: (height * MediaQuery.devicePixelRatioOf(context)).round(),
              ),
            ),
            if (percentage != null && percentage.isFinite)
              Text(
                "${(percentage.clamp(0.0, 1.0) * 100).toStringAsFixed(0)}%",
                style: context.textTheme.displayMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  shadows: const [Shadow(color: Colors.black38, blurRadius: 6.0)],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Fullscreen viewer for the full artworks, with jellyfishes drifting free of the frame.
///
/// Tap the artwork to swap versions, tap anywhere else to leave.
// class JellydaGallery extends StatefulWidget {
//   const JellydaGallery({super.key});

//   static void show() {
//     NamidaNavigator.inst.navigateDialog(
//       blackBg: true,
//       scale: 1.0,
//       dialog: const JellydaGallery(),
//     );
//   }

//   @override
//   State<JellydaGallery> createState() => _JellydaGalleryState();
// }

// class _JellydaGalleryState extends State<JellydaGallery> {
//   var _art = NamidaJellyArt.v2;

//   void _swapArt() {
//     setState(() => _art = _art == NamidaJellyArt.v2 ? NamidaJellyArt.v1 : NamidaJellyArt.v2);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox.expand(
//       child: Stack(
//         fit: .expand,
//         alignment: Alignment.center,
//         children: [
//           // -- behind the frame
//           const Positioned.fill(
//             child: IgnorePointer(
//               child: JellyField(
//                 count: 5,
//                 opacity: 0.3,
//                 minHeight: 120.0,
//                 maxHeight: 340.0,
//                 reactToPlayback: true,
//                 seed: 11,
//               ),
//             ),
//           ),
//           GestureDetector(
//             onTap: _swapArt,
//             child: AnimatedSwitcher(
//               duration: const Duration(milliseconds: 500),
//               child: FloatingImage(
//                 key: ValueKey(_art),
//                 amplitude: 8.0,
//                 cycleDuration: const Duration(seconds: 20),
//                 rotationAmplitude: 0.006,
//                 scaleAmplitude: 0.015,
//                 // -- [AnimatedSwitcher] stacks its children with loose constraints, so the
//                 // -- image has to claim the space itself before [BoxFit.cover] means anything.
//                 // -- oversized on top of that, otherwise the drift walks an edge into view.
//                 child: Transform.scale(
//                   scale: 1.06,
//                   child: SizedBox.expand(
//                     child: Image.asset(
//                       _art.assetPath,
//                       fit: BoxFit.cover,
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//           // -- the artwork now covers the barrier, so tapping away can't dismiss anymore
//           Positioned.fill(
//             child: SafeArea(
//               child: Align(
//                 alignment: Alignment.topLeft,
//                 child: NamidaIconButton(
//                   padding: const EdgeInsets.all(12.0),
//                   onPressed: NamidaNavigator.inst.closeDialog,
//                   icon: Broken.arrow_left_2,
//                   iconColor: Colors.white.withValues(alpha: 0.9),
//                 ),
//               ),
//             ),
//           ),
//           // -- swimming in front of it, gives the art some depth
//           const Positioned.fill(
//             child: IgnorePointer(
//               child: JellyField(
//                 count: 3,
//                 opacity: 0.45,
//                 minHeight: 90.0,
//                 maxHeight: 220.0,
//                 reactToPlayback: true,
//                 seed: 29,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

/// A jellyfish moored where the artwork painted one, floating in place instead of swimming off.
///
/// The layered art ships without its jellyfishes, these put them back: same spots, same sizes,
/// only now they bob, sway and squeeze. Nothing here travels, so the composition never drifts
/// away from the one the piece was drawn as.
class _MooredJelly {
  final NamidaJelly art;

  /// Where the bell sits inside the art canvas, as fractions of it.
  final Offset position;

  /// Drawn height, as a fraction of the art canvas height.
  final double height;
  final bool flipX;

  /// How far it is turned from the way the art was drawn, in radians.
  final double rotation;
  final double alpha;

  /// Drawn over the figure rather than behind it, a couple of them overlap her in the artwork.
  final bool inFront;

  /// Keeps each one on its own float and squeeze, `0.0` to `1.0`.
  final double phase;

  const _MooredJelly({
    required this.art,
    required this.position,
    required this.height,
    required this.rotation,
    required this.phase,
    this.flipX = false,
    this.alpha = 1.0,
    this.inFront = false,
  });
}

/// Traced off [NamidaJellyArt.v2], back to front.
const _kMooredJellies = [
  _MooredJelly(art: NamidaJelly.jelly70d, position: Offset(0.175, 0.315), height: 0.68, rotation: 0.42, phase: 0.00),
  _MooredJelly(art: NamidaJelly.jelly70d, position: Offset(0.430, 0.155), height: 0.46, rotation: 0.05, phase: 0.18, flipX: true, alpha: 0.95),
  _MooredJelly(art: NamidaJelly.jelly70d, position: Offset(0.825, 0.130), height: 0.52, rotation: -0.30, phase: 0.37),
  _MooredJelly(art: NamidaJelly.jelly120dSmall, position: Offset(0.340, 0.575), height: 0.17, rotation: 0.0, phase: 0.55, flipX: true, alpha: 0.9),
  _MooredJelly(art: NamidaJelly.jelly170d, position: Offset(0.215, 0.865), height: 0.27, rotation: 0.0, phase: 0.71, alpha: 0.9),
  _MooredJelly(art: NamidaJelly.jelly70d, position: Offset(0.715, 0.780), height: 0.50, rotation: 0.25, phase: 0.89, flipX: true, inFront: true),
];

/// Ticks the layered scene and keeps a damped playback pulse for it.
///
/// The moored jellies hold no state of their own, they are a function of the clock, so this
/// is all the scene needs to stay alive.
class _JellySceneDriver extends ChangeNotifier {
  double pulse = 0.0;
  double _lastTime = 0.0;

  void start() {
    _lastTime = NamidaFloatClock.instance.seconds;
    NamidaFloatClock.instance.addListener(_onTick);
  }

  @override
  void dispose() {
    NamidaFloatClock.instance.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    final time = NamidaFloatClock.instance.seconds;
    final dt = (time - _lastTime).clampDouble(0.0, 0.05);
    _lastTime = time;
    if (dt <= 0) return;
    // -- damped so a quiet bar doesn't drop the whole scene mid-breath
    final target = _playbackPulse();
    pulse = target + (pulse - target) * math.exp(-dt / 0.22);
    notifyListeners();
  }
}

/// The full artwork, drifting slowly behind whatever sits on top of it.
///
/// A layered art ([NamidaJellyArt.isLayered]) is painted as a live scene once its pieces
/// have decoded: the water and ribbons drift against the figure, the live swarm swims
/// where the artwork used to have its jellyfishes painted in, and the figure breathes
/// with the dress and hand swinging after it. Anything else falls back to the flat art.
class JellyFullArt extends StatefulWidget {
  final NamidaJellyArt art;
  final BoxFit fit;
  final Alignment alignment;
  final double opacity;

  /// Extra drift, the artwork is oversized by this fraction so the motion never exposes an edge.
  ///
  /// Only used by the flat fallback, the scene drifts each layer on its own instead.
  final double drift;

  /// The raised hand alone, `0.0` drops it entirely.
  ///
  /// Only the ends are worth using: the body underneath is drawn complete, so anything
  /// in between lets the headphone cup and its lettering read straight through the palm.
  final double handOpacity;

  static void show() {
    NamidaNavigator.inst.navigateDialog(
      blackBg: true,
      scale: 1.0,
      dialog: const JellyFullArt(),
    );
  }

  const JellyFullArt({
    super.key,
    this.art = NamidaJellyArt.v2,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.opacity = 1.0,
    this.drift = 10.0,
    this.handOpacity = 1.0,
  });

  @override
  State<JellyFullArt> createState() => _JellyFullArtState();
}

class _JellyFullArtState extends State<JellyFullArt> {
  _JellySceneDriver? _driver;
  bool _sceneReady = NamidaJellys.layersReady && NamidaJellys.sceneArtsReady;
  bool _loadRequested = false;

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _detach() {
    _driver?.dispose();
    _driver = null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.art.isLayered && !namidaAnimationsDisabled(context)) {
      if (_sceneReady) {
        _driver ??= (_JellySceneDriver()..start());
        return RepaintBoundary(
          child: CustomPaint(
            isComplex: true,
            painter: _JellydaScenePainter(
              driver: _driver!,
              alignment: widget.alignment,
              opacity: widget.opacity,
              handOpacity: widget.handOpacity,
            ),
          ),
        );
      }
      if (!_loadRequested) {
        _loadRequested = true;
        Future.wait([
          NamidaJellys.ensureLayersLoaded(),
          NamidaJellys.ensureSceneArtsLoaded(),
        ]).then((_) {
          if (mounted) setState(() => _sceneReady = true);
        });
      }
    }

    _detach();
    return ClipRect(
      child: FloatingImage(
        amplitude: widget.drift,
        cycleDuration: const Duration(seconds: 24),
        rotationAmplitude: 0.004,
        scaleAmplitude: 0.02,
        // -- oversized so the drift never exposes an edge
        child: Transform.scale(
          scale: 1.08,
          child: SizedBox.expand(
            child: Image.asset(
              widget.art.assetPath,
              fit: widget.fit,
              alignment: widget.alignment,
              opacity: widget.opacity == 1.0 ? null : AlwaysStoppedAnimation(widget.opacity),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the layered artwork as one scene, back to front, with the live swarm in the middle.
///
/// Every piece rides the same slow swell, each one further behind the last: the body leads,
/// the dress and the raised hand follow a beat later. That lag is the whole trick, moving
/// them together would only read as four sliding pictures.
class _JellydaScenePainter extends CustomPainter {
  final _JellySceneDriver driver;
  final Alignment alignment;
  final double opacity;
  final double handOpacity;

  _JellydaScenePainter({
    required this.driver,
    required this.alignment,
    required this.opacity,
    required this.handOpacity,
  }) : super(repaint: driver);

  static const _swellRate = 1 / 8.5;
  static const _waterRate = 1 / 23;
  static const _strips = [NamidaJellyLayer.stripTopLeft, NamidaJellyLayer.stripRight, NamidaJellyLayer.stripBottomLeft];

  /// Covers the box and then some, the art is never squeezed to fit a screen it wasn't drawn for.
  static const _zoom = 1.06;

  static const _floatRateX = 1 / 17;
  static const _floatRateY = 1 / 11;
  static const _swayRate = 1 / 13;
  static const _pulseRate = 0.1;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !NamidaJellys.layersReady) return;
    // -- cover, keeping the art's own aspect: it overflows the short side and gets clipped
    final cover = math.max(size.width / _kJellyArtSize.width, size.height / _kJellyArtSize.height) * _zoom;
    final dest = alignment.inscribe(Size(_kJellyArtSize.width * cover, _kJellyArtSize.height * cover), Offset.zero & size);
    final time = NamidaFloatClock.instance.seconds;
    double swell(double lag) => math.sin((time - lag) * _swellRate * math.pi * 2);

    final paint = Paint()..filterQuality = FilterQuality.medium;

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    // -- the water slides against the figure, oversized so the slide never walks an edge in
    final waterPhase = time * _waterRate * math.pi * 2;
    _draw(
      canvas,
      paint,
      dest,
      NamidaJellyLayer.bg,
      offset: Offset(math.sin(waterPhase) * dest.width * 0.008, math.cos(waterPhase) * dest.height * 0.005),
      scale: 1.04,
    );

    // -- ribbons are the loosest thing in the water, they trail everything else
    for (int i = 0; i < _strips.length; i++) {
      final drift = swell(2.0 + i * 1.7);
      _draw(canvas, paint, dest, _strips[i], offset: Offset(drift * dest.width * 0.010, drift * dest.height * 0.006));
    }

    // -- the jellyfishes the artwork used to have painted in, back in their own spots
    for (final moored in _kMooredJellies) {
      if (!moored.inFront) _drawMoored(canvas, paint, dest, moored, time);
    }

    // -- one breath for the whole figure, the pieces only add their own lag on top of it
    final lead = swell(0.0);
    final figurePivot = Offset(dest.left + _kJellyFigurePivot.dx * dest.width, dest.top + _kJellyFigurePivot.dy * dest.height);
    canvas.save();
    canvas.translate(figurePivot.dx, figurePivot.dy + lead * dest.height * 0.007);
    canvas.scale(1 + lead * 0.005);
    canvas.translate(-figurePivot.dx, -figurePivot.dy);

    // -- the glow lags the figure and swells with whatever is playing
    _draw(canvas, paint, dest, NamidaJellyLayer.halo, scale: 1 + swell(0.45) * 0.012 + driver.pulse * 0.05, pivot: _kJellyFigurePivot);
    _draw(canvas, paint, dest, NamidaJellyLayer.body);
    _draw(canvas, paint, dest, NamidaJellyLayer.dress, rotation: swell(0.6) * 0.022, pivot: _kJellyDressPivot);
    _draw(canvas, paint, dest, NamidaJellyLayer.hand, rotation: swell(0.32) * 0.013, pivot: _kJellyHandPivot, alpha: handOpacity);
    canvas.restore();

    for (final moored in _kMooredJellies) {
      if (moored.inFront) _drawMoored(canvas, paint, dest, moored, time);
    }

    canvas.restore();
  }

  /// Floats one moored jelly: a slow lissajous around its spot, a sway, and the bell squeeze.
  void _drawMoored(Canvas canvas, Paint paint, Rect dest, _MooredJelly moored, double time) {
    final image = NamidaJellys.imageOf(moored.art);
    if (image == null) return;
    // -- every rate is nudged by the phase, so no two ever come back around together
    final spread = 0.85 + moored.phase * 0.3;
    final phase = moored.phase * math.pi * 2;
    final floatX = math.sin(time * _floatRateX * spread * math.pi * 2 + phase) * dest.width * 0.007;
    final floatY = math.sin(time * _floatRateY * spread * math.pi * 2 + phase * 1.7) * dest.height * 0.014;
    final rotation = moored.rotation + math.sin(time * _swayRate * spread * math.pi * 2 + phase * 2.3) * 0.04;

    final restingAngle = moored.art.bellAngle * math.pi / 180;
    final orientation = (moored.flipX ? math.pi - restingAngle : restingAngle) + rotation;
    final squash = (0.05 + 0.12 * driver.pulse) * _jellyContraction(time, _pulseRate * spread, moored.phase);

    final height = moored.height * dest.height;
    final width = height * image.width / image.height;
    final bell = moored.art.bellAlignment;
    paint.color = Color.fromRGBO(255, 255, 255, opacity * moored.alpha);

    canvas.save();
    canvas.translate(dest.left + moored.position.dx * dest.width + floatX, dest.top + moored.position.dy * dest.height + floatY);
    // -- squeeze along the bell axis, the bell widens as it contracts
    canvas.rotate(-orientation);
    canvas.scale(1 - squash, 1 + squash * 0.6);
    canvas.rotate(orientation);
    // -- canvas y grows downward, so a math-positive rotation is a negative one here
    canvas.rotate(-rotation);
    if (moored.flipX) canvas.scale(-1.0, 1.0);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(-width / 2 - bell.x * width / 2, -height / 2 - bell.y * height / 2, width, height),
      paint,
    );
    canvas.restore();
  }

  void _draw(
    Canvas canvas,
    Paint paint,
    Rect dest,
    NamidaJellyLayer layer, {
    Offset offset = Offset.zero,
    double rotation = 0.0,
    double scale = 1.0,
    Offset? pivot,
    double alpha = 1.0,
  }) {
    if (alpha <= 0.0) return;
    final image = NamidaJellys.layerImageOf(layer);
    if (image == null) return;
    paint.color = Color.fromRGBO(255, 255, 255, opacity * alpha);
    final rect = layer.rect;
    final target = Rect.fromLTRB(
      dest.left + rect.left * dest.width,
      dest.top + rect.top * dest.height,
      dest.left + rect.right * dest.width,
      dest.top + rect.bottom * dest.height,
    ).shift(offset);

    final transformed = rotation != 0.0 || scale != 1.0;
    if (transformed) {
      final origin = pivot == null ? target.center : Offset(dest.left + pivot.dx * dest.width, dest.top + pivot.dy * dest.height);
      canvas.save();
      canvas.translate(origin.dx, origin.dy);
      if (rotation != 0.0) canvas.rotate(rotation);
      if (scale != 1.0) canvas.scale(scale);
      canvas.translate(-origin.dx, -origin.dy);
    }
    canvas.drawImageRect(image, Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()), target, paint);
    if (transformed) canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _JellydaScenePainter oldDelegate) {
    return oldDelegate.driver != driver || oldDelegate.alignment != alignment || oldDelegate.opacity != opacity || oldDelegate.handOpacity != handOpacity;
  }
}

// ===================================

/// The jellyfish artworks, each drawn facing a different way.
///
/// [bellAngle] is where the bell points at, in math degrees (0 = right, 90 = up).
/// Flipping an art horizontally maps its angle to `180 - bellAngle`, so these four
/// cover 8 poses and nothing ever has to be rotated far from how it was drawn.
enum NamidaJelly {
  jelly0d('assets/jellyda/jelly_0d.webp', 0.0, Alignment(0.58, -0.10)),
  jelly70d('assets/jellyda/jelly_70d.webp', 70.0, Alignment(0.10, -0.55)),
  jelly170d('assets/jellyda/jelly_170d.webp', 170.0, Alignment(-0.60, -0.10)),
  jelly190d('assets/jellyda/jelly_190d.webp', 190.0, Alignment(-0.62, 0.05)),
  jelly80dSmall('assets/jellyda/jelly_80d_small.webp', 80.0, Alignment(0.02, -0.22), lowRes: true),
  jelly120dSmall('assets/jellyda/jelly_120d_small.webp', 120.0, Alignment(-0.48, -0.29), lowRes: true);

  const NamidaJelly(this.assetPath, this.bellAngle, this.bellAlignment, {this.lowRes = false});

  final String assetPath;
  final double bellAngle;

  /// Coarse art, only ever placed by hand in the layered scene, never picked by [JellyPose.resolve].
  final bool lowRes;

  /// Decoded once at this width for the whole app, the coarse ones have nothing to gain past it.
  int get decodeWidth => lowRes ? 280 : 400;

  /// Where the bell sits inside the image, used as the pivot so that tentacles
  /// swing wider than the bell instead of the whole sprite spinning around its box.
  final Alignment bellAlignment;
}

/// The full artworks, namida surrounded by jellyfishes.
enum NamidaJellyArt {
  v1('assets/jellyda/jellyda_v1.webp'),
  v2('assets/jellyda/jellyda_v2.webp');

  const NamidaJellyArt(this.assetPath);
  final String assetPath;

  /// Whether the art also ships split into [NamidaJellyLayer]s, so it can be animated.
  bool get isLayered => this == NamidaJellyArt.v2;
}

/// [NamidaJellyArt.v2] split into pieces that can drift apart, drawn back to front.
///
/// The big jellyfishes are deliberately missing: they are the live swarm now, drawn
/// between [stripBottomLeft] and [halo]. [rect] is where a piece sits inside the art
/// canvas as fractions of it, so each ships cropped instead of on a full-size canvas.
enum NamidaJellyLayer {
  bg('bg', Rect.fromLTRB(0.0, 0.0, 1.0, 1.0)),
  stripTopLeft('strip_tl', Rect.fromLTRB(0.0, 0.0, 0.3730, 0.1221)),
  stripRight('strip_r', Rect.fromLTRB(0.8976, 0.0, 1.0, 0.2452)),
  stripBottomLeft('strip_bl', Rect.fromLTRB(0.0, 0.8072, 0.1464, 1.0)),
  halo('halo', Rect.fromLTRB(0.4005, 0.1127, 0.8856, 1.0)),
  body('body', Rect.fromLTRB(0.4163, 0.1705, 0.8555, 1.0)),
  dress('dress', Rect.fromLTRB(0.5100, 0.7014, 0.7501, 1.0)),
  hand('hand', Rect.fromLTRB(0.6093, 0.4859, 0.7226, 0.7514));

  const NamidaJellyLayer(this._fileName, this.rect);

  final String _fileName;
  final Rect rect;

  String get assetPath => 'assets/jellyda/layers/$_fileName.webp';
}

/// The art canvas the [NamidaJellyLayer.rect]s are fractions of.
const _kJellyArtSize = Size(2657.0, 2023.0);

/// The figure is pinned here while it breathes, and the loose pieces swing from these joints.
const _kJellyFigurePivot = Offset(0.640, 1.0);
const _kJellyDressPivot = Offset(0.678, 0.714);
const _kJellyHandPivot = Offset(0.655, 0.716);

abstract class NamidaJellys {
  /// Whether jellyfishes are allowed to invade the ui.
  static bool get enabled => kAllowJellysInvasion && settings.extra.jellysInvasion == true;
  static bool get enableColorPaletteHijack => kAllowJellysInvasion && settings.extra.jellysPalette == true;

  /// Sampled off the artworks, abyss blue through to bell-glow cyan.
  static const palette = <Color>[
    Color(0xFF2157AD),
    Color(0xFF2B3FA8),
    Color(0xFF1668B4),
    Color(0xFF0E77A8),
    Color(0xFF127E9B),
    Color(0xFF1A9AC0),
    Color(0xFF229CB6),
    Color(0xFF6FA9D8),
  ];

  static const paletteLight = Color(0xFF3D6EA8);
  static const paletteDark = Color(0xFF0E2A4D);

  /// Same key always gets the same jelly color, so a track keeps its color across sessions.
  static Color colorFor(String? key) {
    if (key == null || key.isEmpty) return paletteLight;
    return palette[_hash(key) % palette.length];
  }

  /// A full color set built around this key's jelly color, for wherever a palette is expected.
  static NamidaColor namidaColorFor(String? key, {int? alpha}) {
    if (key == null || key.isEmpty) {
      final color = alpha == null ? paletteLight : paletteLight.withAlpha(alpha);
      return NamidaColor.single(color);
    }
    final index = _hash(key) % palette.length;
    final color = palette[index];
    return NamidaColor.create(
      used: alpha == null ? color : color.withAlpha(alpha),
      palette: [
        color,
        palette[(index + 3) % palette.length],
        palette[(index + 5) % palette.length],
      ],
    );
  }

  /// FNV-1a, [String.hashCode] is not guaranteed stable between runs.
  static int _hash(String key) {
    var hash = 0x811C9DC5;
    for (int i = 0; i < key.length; i++) {
      hash = ((hash ^ key.codeUnitAt(i)) * 0x01000193) & 0x7FFFFFFF;
    }
    return hash;
  }

  // -- luminance weights, so the recolor keeps the artwork's own shading
  static const _lumR = 0.2126, _lumG = 0.7152, _lumB = 0.0722;

  static final _tintFilters = <(int, double), ColorFilter>{};

  /// Recolors the blue-ish artwork into a [tint]-toned duotone.
  ///
  /// Luminance is mapped between a darkened and a lightened [tint], so the bell keeps
  /// glowing brighter than the body instead of the whole sprite turning one flat color.
  /// [strength] blends back toward the original blue, `1.0` leaves none of it.
  static ColorFilter tintFilter(Color tint, [double strength = kJellyDefaultTintStrength]) {
    final key = (tint.intValue, strength);
    final cached = _tintFilters[key];
    if (cached != null) return cached;
    if (_tintFilters.length >= 16) _tintFilters.clear(); // -- themes change, the map shouldn't grow forever
    return _tintFilters[key] = _buildTintFilter(tint, strength);
  }

  static ColorFilter _buildTintFilter(Color tint, double strength) {
    final dark = Color.lerp(tint, Colors.black, 0.5)!;
    final light = Color.lerp(tint, Colors.white, 0.72)!;
    final s = strength.clampDouble(0.0, 1.0);
    final identity = 1 - s;

    List<double> row(double darkChannel, double lightChannel, int channelIndex) {
      final span = (lightChannel - darkChannel) * s;
      final values = [_lumR * span, _lumG * span, _lumB * span, 0.0, darkChannel * 255 * s];
      values[channelIndex] += identity;
      return values;
    }

    return ColorFilter.matrix([
      ...row(dark.r, light.r, 0),
      ...row(dark.g, light.g, 1),
      ...row(dark.b, light.b, 2),
      0.0, 0.0, 0.0, 1.0, 0.0, //
    ]);
  }

  /// Every [NamidaJellyLayer] decodes to its own share of this, so they all land on
  /// one scale and drop straight into the scene without any resampling.
  static const _sceneDecodeWidth = 1000;

  static final _layerImages = <NamidaJellyLayer, ui.Image>{};
  static Future<void>? _layersLoading;

  static ui.Image? layerImageOf(NamidaJellyLayer layer) => _layerImages[layer];

  static bool get layersReady => _layerImages.length == NamidaJellyLayer.values.length;

  static Future<void> ensureLayersLoaded() {
    if (layersReady) return Future.value();
    return _layersLoading ??= Future.wait(
      NamidaJellyLayer.values.map((layer) async {
        final data = await rootBundle.load(layer.assetPath);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: (_sceneDecodeWidth * layer.rect.width).round());
        final frame = await codec.getNextFrame();
        _layerImages[layer] = frame.image;
      }),
    ).then((_) => _layersLoading = null);
  }

  static final _images = <NamidaJelly, ui.Image>{};
  static final _detailedArts = NamidaJelly.values.where((e) => !e.lowRes).toList();
  static final _sceneArts = _kMooredJellies.map((e) => e.art).toSet();
  static Future<void>? _loading;
  static Future<void>? _sceneArtsLoading;

  static ui.Image? imageOf(NamidaJelly jelly) => _images[jelly];

  static bool get imagesReady => _detailedArts.every(_images.containsKey);

  static bool get sceneArtsReady => _sceneArts.every(_images.containsKey);

  /// Decodes every jelly once for the whole app, they are kept alive on purpose,
  /// the four of them together cost less than a single artwork tile.
  static Future<void> ensureImagesLoaded() {
    if (imagesReady) return Future.value();
    return _loading ??= Future.wait(_detailedArts.map(_decodeArt)).then((_) => _loading = null);
  }

  /// The arts the layered scene moors, undecoded until it is actually shown.
  static Future<void> ensureSceneArtsLoaded() {
    if (sceneArtsReady) return Future.value();
    return _sceneArtsLoading ??= Future.wait(_sceneArts.where((e) => !_images.containsKey(e)).map(_decodeArt)).then((_) => _sceneArtsLoading = null);
  }

  static Future<void> _decodeArt(NamidaJelly jelly) async {
    final data = await rootBundle.load(jelly.assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: jelly.decodeWidth);
    final frame = await codec.getNextFrame();
    _images[jelly] = frame.image;
  }
}

/// How far the jelly artwork is pushed into the theme color by default.
const kJellyDefaultTintStrength = 0.85;

/// How far an art may be rotated away from how it was drawn, in radians.
const kJellyMaxArtRotation = 35 * math.pi / 180;

/// The art picked to sit closest to a wanted orientation, plus the rotation left over.
class JellyPose {
  final NamidaJelly jelly;
  final bool flipX;

  /// Radians between the art's own [NamidaJelly.bellAngle] and the wanted orientation.
  final double residual;

  const JellyPose(this.jelly, this.flipX, this.residual);

  /// The angle this art actually points at once flipped, in radians.
  double get restingAngle {
    final angle = jelly.bellAngle * math.pi / 180;
    return flipX ? math.pi - angle : angle;
  }

  /// Picks the art, in whichever flip, already drawn closest to [orientation].
  ///
  /// Only ever asked for upright-ish orientations, a jellyfish never swims belly up.
  static JellyPose resolve(double orientation) {
    NamidaJelly? best;
    var bestFlipX = false;
    var bestResidual = double.infinity;
    for (final jelly in NamidaJelly.values) {
      if (jelly.lowRes) continue; // -- placed by hand in the scene, never picked by angle
      final angle = jelly.bellAngle * math.pi / 180;
      for (final flipX in const [false, true]) {
        final effective = flipX ? math.pi - angle : angle;
        final residual = _shortestAngle(orientation - effective);
        if (residual.abs() < bestResidual.abs()) {
          best = jelly;
          bestFlipX = flipX;
          bestResidual = residual;
        }
      }
    }
    return JellyPose(best!, bestFlipX, bestResidual);
  }
}

double _shortestAngle(double angle) {
  const twoPi = math.pi * 2;
  var diff = (angle + math.pi) % twoPi;
  if (diff < 0) diff += twoPi;
  return diff - math.pi;
}
