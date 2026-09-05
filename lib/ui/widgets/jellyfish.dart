// fully by claude (no mistakes), me no math
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:namida/class/color_m.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/waveform_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
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

    // -- smaller ones read as further away, so they drift slower and dimmer
    final depth = jelly.sizeFactor = _rng.nextDouble();
    jelly.driftAngle = key.driftAngle + group.driftOffset + (_rng.nextDouble() - 0.5) * 0.16;
    jelly.driftSpeed = _between(3.0, 8.0) / _referenceExtent * group.speedFactor * (0.5 + depth);
    jelly.thrust = _between(5.0, 12.0) / _referenceExtent * (0.5 + depth);
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

  double contractionOf(_Jelly jelly, double time) {
    final phase = (time * jelly.pulseRate + jelly.pulsePhase) % 1.0;
    const squeezePortion = 0.22;
    if (phase < squeezePortion) return Curves.easeOutCubic.transform(phase / squeezePortion);
    return 1.0 - Curves.easeInOutSine.transform((phase - squeezePortion) / (1 - squeezePortion));
  }
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

  /// Recolors the jellies toward this, usually the current track color. Null keeps the original blue.
  final Color? tint;
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
    this.tintStrength = 0.45,
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
          tint: widget.tint,
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
    if (size.isEmpty) return;
    final time = NamidaFloatClock.instance.seconds;
    final fadeBand = math.min(size.width, size.height) * 0.22;
    final tint = this.tint;
    final colorFilter = tint == null ? null : ColorFilter.mode(tint.withValues(alpha: tintStrength), BlendMode.srcATop);
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
      child: Obx(
        (context) => JellyField(
          count: count,
          tint: CurrentColor.inst.color,
          opacity: opacity,
          minHeight: minHeight,
          maxHeight: maxHeight,
          reactToPlayback: reactToPlayback,
          enabled: enabled,
          seed: seed,
        ),
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
    this.tintStrength = 0.45,
    this.opacity = 1.0,
    this.mirrored = false,
    this.amplitude = 6.0,
    this.cycleDuration = const Duration(seconds: 9),
    this.seed,
  });

  @override
  Widget build(BuildContext context) {
    final tint = this.tint;
    Widget image = Image.asset(
      jelly.assetPath,
      height: height,
      cacheHeight: (height * MediaQuery.devicePixelRatioOf(context)).round(),
      opacity: opacity == 1.0 ? null : AlwaysStoppedAnimation(opacity),
      color: tint?.withValues(alpha: tintStrength),
      colorBlendMode: tint == null ? null : BlendMode.srcATop,
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
        jelly: randomJelly ? NamidaJelly.values[rng.nextInt(NamidaJelly.values.length)] : NamidaJelly.jelly100d,
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
      child: Obx(
        (context) {
          final tint = CurrentColor.inst.color;
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
    const art = NamidaJelly.jelly100d;
    final percentage = this.percentage;
    final tint = this.tint;
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
            Image.asset(
              art.assetPath,
              height: height,
              cacheHeight: (height * MediaQuery.devicePixelRatioOf(context)).round(),
              color: tint?.withValues(alpha: 0.45),
              colorBlendMode: tint == null ? null : BlendMode.srcATop,
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
class JellydaGallery extends StatefulWidget {
  const JellydaGallery({super.key});

  static void show() {
    NamidaNavigator.inst.navigateDialog(
      blackBg: true,
      scale: 1.0,
      dialog: const JellydaGallery(),
    );
  }

  @override
  State<JellydaGallery> createState() => _JellydaGalleryState();
}

class _JellydaGalleryState extends State<JellydaGallery> {
  var _art = NamidaJellyArt.v2;

  void _swapArt() {
    setState(() => _art = _art == NamidaJellyArt.v2 ? NamidaJellyArt.v1 : NamidaJellyArt.v2);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        fit: .expand,
        alignment: Alignment.center,
        children: [
          // -- behind the frame
          const Positioned.fill(
            child: IgnorePointer(
              child: JellyField(
                count: 5,
                opacity: 0.3,
                minHeight: 120.0,
                maxHeight: 340.0,
                reactToPlayback: true,
                seed: 11,
              ),
            ),
          ),
          GestureDetector(
            onTap: _swapArt,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: FloatingImage(
                key: ValueKey(_art),
                amplitude: 8.0,
                cycleDuration: const Duration(seconds: 20),
                rotationAmplitude: 0.006,
                scaleAmplitude: 0.015,
                // -- [AnimatedSwitcher] stacks its children with loose constraints, so the
                // -- image has to claim the space itself before [BoxFit.cover] means anything.
                // -- oversized on top of that, otherwise the drift walks an edge into view.
                child: Transform.scale(
                  scale: 1.06,
                  child: SizedBox.expand(
                    child: Image.asset(
                      _art.assetPath,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // -- the artwork now covers the barrier, so tapping away can't dismiss anymore
          Positioned.fill(
            child: SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: NamidaIconButton(
                  padding: const EdgeInsets.all(12.0),
                  onPressed: NamidaNavigator.inst.closeDialog,
                  icon: Broken.arrow_left_2,
                  iconColor: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
          // -- swimming in front of it, gives the art some depth
          const Positioned.fill(
            child: IgnorePointer(
              child: JellyField(
                count: 3,
                opacity: 0.45,
                minHeight: 90.0,
                maxHeight: 220.0,
                reactToPlayback: true,
                seed: 29,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The full artwork, drifting slowly behind whatever sits on top of it.
class JellyFullArt extends StatelessWidget {
  final NamidaJellyArt art;
  final BoxFit fit;
  final Alignment alignment;
  final double opacity;

  /// Extra drift, the artwork is oversized by this fraction so the motion never exposes an edge.
  final double drift;

  const JellyFullArt({
    super.key,
    this.art = NamidaJellyArt.v2,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.opacity = 1.0,
    this.drift = 10.0,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: FloatingImage(
        amplitude: drift,
        cycleDuration: const Duration(seconds: 24),
        rotationAmplitude: 0.004,
        scaleAmplitude: 0.02,
        // -- oversized so the drift never exposes an edge
        child: Transform.scale(
          scale: 1.08,
          child: SizedBox.expand(
            child: Image.asset(
              art.assetPath,
              fit: fit,
              alignment: alignment,
              opacity: opacity == 1.0 ? null : AlwaysStoppedAnimation(opacity),
            ),
          ),
        ),
      ),
    );
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
  jelly100d('assets/jellyda/jelly_100d.webp', 100.0, Alignment(0.10, -0.55)),
  jelly170d('assets/jellyda/jelly_170d.webp', 170.0, Alignment(-0.60, -0.10)),
  jelly190d('assets/jellyda/jelly_190d.webp', 190.0, Alignment(-0.62, 0.05));

  const NamidaJelly(this.assetPath, this.bellAngle, this.bellAlignment);

  final String assetPath;
  final double bellAngle;

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
}

abstract class NamidaJellys {
  /// Whether jellyfishes are allowed to invade the ui.
  static bool get enabled => kAllowJellysInvasion && settings.extra.jellysInvasion == true;

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

  static const _decodeWidth = 400;

  static final _images = <NamidaJelly, ui.Image>{};
  static Future<void>? _loading;

  static ui.Image? imageOf(NamidaJelly jelly) => _images[jelly];

  static bool get imagesReady => _images.length == NamidaJelly.values.length;

  /// Decodes every jelly once for the whole app, they are kept alive on purpose,
  /// the four of them together cost less than a single artwork tile.
  static Future<void> ensureImagesLoaded() {
    if (imagesReady) return Future.value();
    return _loading ??= Future.wait(
      NamidaJelly.values.map((jelly) async {
        final data = await rootBundle.load(jelly.assetPath);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: _decodeWidth);
        final frame = await codec.getNextFrame();
        _images[jelly] = frame.image;
      }),
    ).then((_) => _loading = null);
  }
}

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
