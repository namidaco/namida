// ignore_for_file: avoid_rx_value_getter_outside_obx
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/waveform_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/jellyfish.dart';

class WaveformComponent extends StatefulWidget {
  final int durationInMilliseconds;
  final Curve curve;
  final double barsMinHeight;
  final double barsMaxHeight;

  static const barWidthFraction = 0.54;
  static const defaultBarsMinHeight = 3.0;
  static const defaultBarsMaxHeight = 64.0;

  const WaveformComponent({
    super.key,
    this.durationInMilliseconds = 600,
    this.curve = Curves.easeInOutQuart,
    this.barsMinHeight = defaultBarsMinHeight,
    this.barsMaxHeight = defaultBarsMaxHeight,
  });

  static final _activeJellies = <_WaveformJelly>{};

  /// for seeks made by the user, not every position change.
  static void pokeAt(int positionMS, {double strength = 1.0}) {
    for (final jelly in _activeJellies) {
      jelly.pokeAt(positionMS, strength);
    }
  }

  @override
  State<WaveformComponent> createState() => WaveformComponentState();
}

class WaveformComponentState extends State<WaveformComponent> with TickerProviderStateMixin {
  void _updateAnimation(bool enabled) async {
    if (enabled) {
      final alreadygoing = _animation.status == AnimationStatus.forward || _animation.status == AnimationStatus.completed;
      if (!alreadygoing) await _animation.animateTo(1.0, curve: widget.curve);
    } else {
      final alreadygoing = _animation.status == AnimationStatus.reverse || _animation.status == AnimationStatus.dismissed;
      if (!alreadygoing) await _animation.animateBack(0.0, curve: widget.curve);
    }
  }

  late final _animation = AnimationController(
    vsync: this,
    lowerBound: 0.0,
    upperBound: 1.0,
    value: WaveformController.inst.isWaveformUIEnabled.value ? 1.0 : 0.0,
    duration: Duration(milliseconds: widget.durationInMilliseconds),
    reverseDuration: Duration(milliseconds: widget.durationInMilliseconds),
  );

  _WaveformJelly? _jelly;

  void _onJellysEnabledChanged() {
    final isEnabled = NamidaJellys.enabledRx.value;
    if (isEnabled == (_jelly != null)) return;
    _jelly?.dispose();
    final jelly = isEnabled ? _createJelly() : null;
    refreshState(() => _jelly = jelly);
  }

  _WaveformJelly _createJelly() => _WaveformJelly(vsync: this)..attach();

  int get _currentDurationInMSR {
    final totalDur = Player.inst.currentItemDuration.valueR;
    if (totalDur != null) return totalDur.inMilliseconds;
    final current = Player.inst.currentItem.valueR;
    if (current is Selectable) {
      return current.track.durationMS;
    }
    return 0;
  }

  void _onWaveformEnabledChanged() => _updateAnimation(WaveformController.inst.isWaveformUIEnabled.value);

  @override
  void initState() {
    super.initState();
    WaveformController.inst.isWaveformUIEnabled.addListener(_onWaveformEnabledChanged);
    if (NamidaJellys.enabled) _jelly = _createJelly();
    NamidaJellys.enabledRx.addListener(_onJellysEnabledChanged);
  }

  @override
  void dispose() {
    WaveformController.inst.isWaveformUIEnabled.removeListener(_onWaveformEnabledChanged);
    _animation.dispose();
    NamidaJellys.enabledRx.removeListener(_onJellysEnabledChanged);
    _jelly?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final barRadius = Radius.circular(5.0.multipliedRadius);
    const frontAlpha = 110;
    final barColorBehind = theme.colorScheme.onSurface.withAlpha(40);
    final barColorFront = theme.colorScheme.onSurface.withAlpha(frontAlpha);
    final playedColors = [
      Color.alphaBlend(CurrentColor.inst.miniplayerColor.withAlpha(180), theme.colorScheme.onSurface).withAlpha(frontAlpha),
      Color.alphaBlend(CurrentColor.inst.miniplayerColor.withAlpha(140), theme.colorScheme.onSurface).withAlpha(frontAlpha),
    ];
    final jelly = _jelly;
    return LayoutWidthProvider(
      builder: (context, maxWidth) {
        return ObxO(
          rx: WaveformController.inst.currentWaveformUIRx,
          builder: (context, downscaled) {
            final barWidth = maxWidth / downscaled.length * WaveformComponent.barWidthFraction;
            return Center(
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, _) {
                  final barBehind = _NamidaWaveBars(
                    heightPercentage: _animation.value,
                    barColor: barColorBehind,
                    barRadius: barRadius,
                    waveList: downscaled,
                    barWidth: barWidth,
                    barMinHeight: widget.barsMinHeight,
                    barMaxHeight: widget.barsMaxHeight,
                    jelly: jelly,
                  );
                  return Stack(
                    children: [
                      barBehind,
                      ObxO(
                        rx: MiniPlayerController.inst.seekValue,
                        builder: (context, seekNull) => ObxO(
                          rx: Player.inst.nowPlayingPosition,
                          builder: (context, nowPlayingPosition) {
                            final position = seekNull ?? nowPlayingPosition;
                            final durInMs = _currentDurationInMSR;
                            final percentage = durInMs <= 0 ? 0.0 : (position / durInMs).clampDouble(0.0, 1.0);
                            return _NamidaWaveBars(
                              heightPercentage: _animation.value,
                              barColor: barColorFront,
                              barRadius: barRadius,
                              waveList: downscaled,
                              barWidth: barWidth,
                              barMinHeight: widget.barsMinHeight,
                              barMaxHeight: widget.barsMaxHeight,
                              playedPercentage: percentage,
                              playedColors: playedColors,
                              jelly: jelly,
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _NamidaWaveBars extends StatelessWidget {
  final List<double> waveList;
  final double barWidth;
  final double barMinHeight;
  final double barMaxHeight;
  final Color barColor;
  final Radius barRadius;
  final double heightPercentage;
  final double? playedPercentage;
  final List<Color>? playedColors;
  final _WaveformJelly? jelly;

  const _NamidaWaveBars({
    required this.waveList,
    required this.barWidth,
    required this.barMinHeight,
    required this.barMaxHeight,
    required this.barColor,
    required this.barRadius,
    required this.heightPercentage,
    this.playedPercentage,
    this.playedColors,
    required this.jelly,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      isComplex: false,
      willChange: true,
      painter: _NamidaWaveBarsPainter(
        waveList: waveList,
        barWidth: barWidth,
        barMinHeight: barMinHeight,
        barMaxHeight: barMaxHeight,
        barColor: barColor,
        barRadius: barRadius,
        heightPercentage: heightPercentage,
        playedPercentage: playedPercentage,
        playedColors: playedColors,
        jelly: jelly,
      ),
    );
  }
}

/// painted instead of a `Row` of `SizedBox`es: the bars are rebuilt on every animation
/// frame, and building/laying out ~2x80 widgets per frame costs far more than one repaint.
///
/// by claude
class _NamidaWaveBarsPainter extends CustomPainter {
  final List<double> waveList;
  final double barWidth;
  final double barMinHeight;
  final double barMaxHeight;
  final Color barColor;
  final Radius barRadius;
  final double heightPercentage;
  final double? playedPercentage;
  final List<Color>? playedColors;
  final _WaveformJelly? jelly;

  _NamidaWaveBarsPainter({
    required this.waveList,
    required this.barWidth,
    required this.barMinHeight,
    required this.barMaxHeight,
    required this.barColor,
    required this.barRadius,
    required this.heightPercentage,
    required this.playedPercentage,
    required this.playedColors,
    required this.jelly,
  }) : super(repaint: jelly);

  @override
  void paint(Canvas canvas, Size size) {
    final count = waveList.length;
    if (count == 0 || barWidth <= 0 || !barWidth.isFinite) return;

    // -- matches `MainAxisAlignment.spaceEvenly`: equal gaps before, between & after the bars.
    final gap = (size.width - barWidth * count) / (count + 1);
    final centerY = size.height / 2;
    final paint = Paint()
      ..color = barColor
      ..isAntiAlias = true;

    final playedPercentage = this.playedPercentage;
    double maxLeft = size.width;
    if (playedPercentage != null) {
      final playedWidth = size.width * playedPercentage;
      if (playedWidth <= 0) return;
      maxLeft = playedWidth;
      canvas.clipRect(Rect.fromLTWH(0, 0, playedWidth, size.height));
      final playedColors = this.playedColors;
      if (playedColors != null && playedColors.length >= 2) {
        // -- the paint color alpha modulates the shader, the gradient colors already carry the alpha.
        paint.color = const Color(0xFFFFFFFF);
        paint.shader = ui.Gradient.linear(Offset.zero, Offset(playedWidth, 0), playedColors);
      }
    }

    final barPitch = barWidth + gap;
    final halfBarWidth = barWidth / 2;
    var jellyStretch = jelly?.activeStretch();
    if (jellyStretch != null && jellyStretch.length != count) jellyStretch = null;
    if (jellyStretch != null) maxLeft += halfBarWidth * _WaveformJelly.maxExtraWidth; // -- squashed bars widen past the played edge
    double left = gap;
    for (int i = 0; i < count; i++) {
      if (left > maxLeft) break;
      var barHeight = (heightPercentage * waveList[i]).clampDouble(barMinHeight, barMaxHeight);
      var barLeft = left;
      var barRight = left + barWidth;
      if (jellyStretch != null) {
        final heightFactor = _WaveformJelly.heightFactorOf(jellyStretch[i]);
        final halfWidth = halfBarWidth / math.sqrt(heightFactor);
        final barCenterX = left + halfBarWidth;
        barHeight = (barHeight * heightFactor).clampDouble(barMinHeight, size.height);
        barLeft = barCenterX - halfWidth;
        barRight = barCenterX + halfWidth;
      }
      final halfHeight = barHeight / 2;
      canvas.drawRRect(
        RRect.fromLTRBR(barLeft, centerY - halfHeight, barRight, centerY + halfHeight, barRadius),
        paint,
      );
      left += barPitch;
    }
  }

  @override
  bool shouldRepaint(_NamidaWaveBarsPainter oldDelegate) {
    return heightPercentage != oldDelegate.heightPercentage ||
        barColor != oldDelegate.barColor ||
        barWidth != oldDelegate.barWidth ||
        barMinHeight != oldDelegate.barMinHeight ||
        barMaxHeight != oldDelegate.barMaxHeight ||
        barRadius != oldDelegate.barRadius ||
        playedPercentage != oldDelegate.playedPercentage ||
        !identical(playedColors, oldDelegate.playedColors) ||
        !identical(waveList, oldDelegate.waveList) ||
        !identical(jelly, oldDelegate.jelly);
  }
}

// by claude
/// the bars act like a strip of jelly: holding on the waveform presses a dent in, and a seek pokes it so the wobble rolls along the row.
class _WaveformJelly extends ChangeNotifier {
  static const _kStiffness = 350.0;
  static const _kSpread = 1000.0;
  static const _kDampingRatio = 0.4;
  static const _kPokeStrength = 2.0;
  static const _kPokeWidthInBars = 1.6;
  static const _kPressDepth = 0.3;
  static const _kPressWidthInBars = 1.8;
  static const _kHoldInSeconds = 0.06;
  static const _kHoldOutSeconds = 0.02;
  static const _kStepSeconds = 1 / 240;
  static const _kMaxFrameSeconds = 0.05;
  static const _kRestThreshold = 0.001;
  static const _kMinHeightFactor = 0.35;
  static const _kMaxHeightFactor = 2.2;
  static final _kDamping = 2 * _kDampingRatio * math.sqrt(_kStiffness);

  static final maxExtraWidth = 1.0 / math.sqrt(_kMinHeightFactor) - 1.0;

  static double heightFactorOf(double stretch) => (1.0 + stretch).clampDouble(_kMinHeightFactor, _kMaxHeightFactor);

  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  var _stretch = Float32List(0);
  var _velocity = Float32List(0);
  var _pressForce = Float32List(0);
  bool _isPressing = false;
  bool _isHolding = false;
  double _hold = 0.0;
  double _fingerIndex = 0.0;

  _WaveformJelly({required TickerProvider vsync}) {
    _ticker = vsync.createTicker(_onTick);
  }

  void attach() {
    WaveformComponent._activeJellies.add(this);
    MiniPlayerController.inst.seekValue.addListener(_onSeekValueChanged);
  }

  @override
  void dispose() {
    WaveformComponent._activeJellies.remove(this);
    MiniPlayerController.inst.seekValue.removeListener(_onSeekValueChanged);
    _ticker.dispose();
    super.dispose();
  }

  /// null while the strip is at rest.
  Float32List? activeStretch() => _ticker.isActive ? _stretch : null;

  void _onSeekValueChanged() {
    final seekMS = MiniPlayerController.inst.seekValue.value;
    _isHolding = seekMS != null;
    if (seekMS != null) _fingerIndex = _toBarIndex(seekMS);
    if (_isHolding) _startTicking();
  }

  void pokeAt(int positionMS, double strength) {
    final barsCount = _ensureBars();
    if (barsCount == 0) return;
    final center = _toBarIndex(positionMS);
    final kick = _kPokeStrength * strength;
    final velocity = _velocity;
    for (int i = 0; i < barsCount; i++) {
      final u = (i - center) / _kPokeWidthInBars;
      velocity[i] -= kick * math.exp(-u * u);
    }
    _startTicking();
  }

  void _startTicking() {
    if (_ticker.isActive) return;
    _lastElapsed = Duration.zero;
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final frameMicroseconds = (elapsed - _lastElapsed).inMicroseconds;
    _lastElapsed = elapsed;
    final frameSeconds = (frameMicroseconds / Duration.microsecondsPerSecond).withMaximum(_kMaxFrameSeconds);
    if (_ensureBars() == 0) {
      _ticker.stop();
      return;
    }
    _updateHold(frameSeconds);
    _updatePressForce();
    var remainingSeconds = frameSeconds;
    while (remainingSeconds > 0) {
      final stepSeconds = remainingSeconds.withMaximum(_kStepSeconds);
      _step(stepSeconds);
      remainingSeconds -= stepSeconds;
    }
    if (_isAtRest()) {
      _stretch.fillRange(0, _stretch.length, 0.0);
      _velocity.fillRange(0, _velocity.length, 0.0);
      _ticker.stop();
    }
    notifyListeners();
  }

  void _updateHold(double frameSeconds) {
    final target = _isHolding ? 1.0 : 0.0;
    final smoothingSeconds = _isHolding ? _kHoldInSeconds : _kHoldOutSeconds;
    final progress = 1.0 - math.exp(-frameSeconds / smoothingSeconds);
    _hold += (target - _hold) * progress;
  }

  void _updatePressForce() {
    _isPressing = _hold > _kRestThreshold;
    if (!_isPressing) return;
    final pressForce = _pressForce;
    final strength = -_kStiffness * _kPressDepth * _hold;
    for (int i = 0; i < pressForce.length; i++) {
      final u = (i - _fingerIndex) / _kPressWidthInBars;
      final u2 = u * u;
      pressForce[i] = strength * (1.0 - u2) * math.exp(-u2 / 2);
    }
  }

  void _step(double h) {
    final stretch = _stretch;
    final velocity = _velocity;
    final pressForce = _pressForce;
    final isPressing = _isPressing;
    final lastIndex = stretch.length - 1;
    for (int i = 0; i <= lastIndex; i++) {
      final current = stretch[i];
      final left = i == 0 ? current : stretch[i - 1];
      final right = i == lastIndex ? current : stretch[i + 1];
      final neighboursPull = left - 2 * current + right;
      var acceleration = -_kStiffness * current + _kSpread * neighboursPull - _kDamping * velocity[i];
      if (isPressing) acceleration += pressForce[i];
      velocity[i] += acceleration * h;
    }
    for (int i = 0; i <= lastIndex; i++) {
      stretch[i] += velocity[i] * h;
    }
  }

  bool _isAtRest() {
    if (_isHolding || _isPressing) return false;
    final stretch = _stretch;
    final velocity = _velocity;
    for (int i = 0; i < stretch.length; i++) {
      if (stretch[i].abs() > _kRestThreshold || velocity[i].abs() > _kRestThreshold) return false;
    }
    return true;
  }

  int _ensureBars() {
    final barsCount = WaveformController.inst.currentWaveformUIRx.value.length;
    if (_stretch.length != barsCount) {
      _stretch = Float32List(barsCount);
      _velocity = Float32List(barsCount);
      _pressForce = Float32List(barsCount);
    }
    return barsCount;
  }

  static double _toBarIndex(int positionMS) {
    final barsCount = WaveformController.inst.currentWaveformUIRx.value.length;
    return _toFraction(positionMS) * barsCount - 0.5;
  }

  static double _toFraction(int positionMS) {
    final durationMS = _currentDurationInMS();
    if (durationMS <= 0) return 0.0;
    return (positionMS / durationMS).clampDouble(0.0, 1.0);
  }

  static int _currentDurationInMS() {
    final totalDur = Player.inst.currentItemDuration.value;
    if (totalDur != null) return totalDur.inMilliseconds;
    final current = Player.inst.currentItem.value;
    if (current is Selectable) return current.track.durationMS;
    return 0;
  }
}
