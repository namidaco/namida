part of 'eggs.dart';

/// the balance counts eggs only once they land on the shelf.
class _EggsStage extends StatefulWidget {
  final List<NamidaEgg> revealOnStart;
  final void Function()? onEggLanded;

  const _EggsStage({this.revealOnStart = const [], this.onEggLanded});

  @override
  State<_EggsStage> createState() => _EggsStageState();
}

class _EggsStageState extends State<_EggsStage> with TickerProviderStateMixin, _AfterRouteSettled {
  static const _kFallDurationMS = 900;
  static const _kStaggerMS = 170;
  static const _kWaveGap = Duration(seconds: 5);
  static const _kSlotSpacing = 8.0;
  static const _kFirstRowShare = 2 / 3;

  // -- where Curves.bounceOut first touches the ground
  static const _kLandingPoint = 1 / 2.75;

  late final _revealController = AnimationController(vsync: this);
  late final _waveController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  late final _wiggleController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );
  late final _gainController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  final _shown = <NamidaEgg>{};
  var _revealing = const <NamidaEgg>[];
  int _landedCount = 0;
  int _lastGain = 0;
  NamidaEgg? _wigglingEgg;
  Timer? _waveTimer;

  @override
  void initState() {
    super.initState();
    final data = settings.eggs.value;
    final revealOnStart = widget.revealOnStart;
    for (final egg in NamidaEgg.values) {
      if (data.isCollected(egg) && !revealOnStart.contains(egg)) _shown.add(egg);
    }
    _revealController.addListener(_landEggs);
    _waveController.addStatusListener(_onWaveStatusChanged);
    settings.eggs.addListener(_revealNewlyCollected);
  }

  @override
  void dispose() {
    _waveTimer?.cancel();
    settings.eggs.removeListener(_revealNewlyCollected);
    _revealController.dispose();
    _waveController.dispose();
    _wiggleController.dispose();
    _gainController.dispose();
    super.dispose();
  }

  @override
  void onRouteSettled() {
    _revealNewlyCollected();
    _queueWave();
  }

  void _queueWave() {
    _waveTimer?.cancel();
    _waveTimer = Timer(_kWaveGap, _playWave);
  }

  void _playWave() => _waveController.forward(from: 0.0);

  void _onWaveStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) _queueWave();
  }

  void _revealNewlyCollected() {
    final data = settings.eggs.value;
    final newlyCollected = <NamidaEgg>[];
    for (final egg in NamidaEgg.values) {
      if (data.isCollected(egg) && !_shown.contains(egg)) newlyCollected.add(egg);
    }
    if (newlyCollected.isEmpty) return;
    _shown.addAll(newlyCollected);
    final durationMS = _kFallDurationMS + _kStaggerMS * (newlyCollected.length - 1);
    _revealController.duration = Duration(milliseconds: durationMS);
    setState(() {
      _revealing = newlyCollected;
      _landedCount = 0;
    });
    _revealController.forward(from: 0.0);
  }

  double _landingMSOf(int order) => order * _kStaggerMS + _kLandingPoint * _kFallDurationMS;

  void _landEggs() {
    final totalMS = _revealController.duration?.inMilliseconds ?? _kFallDurationMS;
    final elapsedMS = _revealController.value * totalMS;
    int landedCount = _landedCount;
    while (landedCount < _revealing.length && elapsedMS >= _landingMSOf(landedCount)) {
      final egg = _revealing[landedCount];
      landedCount++;
      _onEggLanded(egg);
    }
    if (landedCount == _landedCount) return;
    setState(() => _landedCount = landedCount);
  }

  void _onEggLanded(NamidaEgg egg) {
    VibratorController.light();
    _lastGain = egg.worth;
    _gainController.forward(from: 0.0);
    widget.onEggLanded?.call();
  }

  void _wiggle(NamidaEgg egg) {
    setState(() => _wigglingEgg = egg);
    _wiggleController.forward(from: 0.0);
  }

  int _unlandedWorth(EggsData data) {
    int worth = 0;
    for (final egg in NamidaEgg.values) {
      if (data.isCollected(egg) && !_shown.contains(egg)) worth += egg.worth;
    }
    for (int i = _landedCount; i < _revealing.length; i++) {
      worth += _revealing[i].worth;
    }
    return worth;
  }

  /// splits the eggs so no row is left with a lonely egg, with two rows the first one holds about two thirds.
  static double _rowWidthOf(double maxWidth, int count) {
    const slotExtent = _EggSlot._kWidth + _kSlotSpacing;
    final fitCount = ((maxWidth + _kSlotSpacing) / slotExtent).floor().withMinimum(1);
    final rowsCount = (count / fitCount).ceil();
    final balancedCount = (count / rowsCount).ceil();
    final firstRowShareCount = (count * _kFirstRowShare).round();
    final firstRowCount = rowsCount == 2 ? firstRowShareCount.withMinimum(balancedCount).withMaximum(fitCount) : balancedCount;
    return firstRowCount * slotExtent - _kSlotSpacing;
  }

  Animation<double>? _fallOf(NamidaEgg egg) {
    final order = _revealing.indexOf(egg);
    if (order == -1) return null;
    final totalMS = _revealController.duration?.inMilliseconds ?? _kFallDurationMS;
    final startMS = order * _kStaggerMS;
    final endMS = startMS + _kFallDurationMS;
    final interval = Interval(startMS / totalMS, endMS / totalMS);
    return _revealController.drive(CurveTween(curve: interval));
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final eggColor = theme.colorScheme.primary;
    final shine = _waveController.drive(CurveTween(curve: const Interval(0.2, 0.8)));
    final slots = [
      for (final (index, egg) in NamidaEgg.values.indexed)
        _EggSlot(
          egg: egg,
          isCollected: _shown.contains(egg),
          color: egg.worth > 1 ? _kGoldenEggColor : eggColor,
          fall: _fallOf(egg),
          hop: _waveController.drive(_HopOffset(index)),
          shine: egg.worth > 1 ? shine : null,
          wiggle: _wigglingEgg == egg ? _wiggleController : kAlwaysDismissedAnimation,
          onTap: () => _wiggle(egg),
        ),
    ];
    final shelf = LayoutWidthProvider(
      builder: (context, maxWidth) {
        final rowWidth = _rowWidthOf(maxWidth, slots.length);
        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: rowWidth,
            child: Wrap(
              spacing: _kSlotSpacing,
              runSpacing: 10.0,
              children: slots,
            ),
          ),
        );
      },
    );
    return RepaintBoundary(
      child: Row(
        children: [
          Expanded(
            child: shelf,
          ),
          const SizedBox(
            width: 8.0,
          ),
          ObxO(
            rx: settings.eggs,
            builder: (context, data) {
              final unlandedWorth = _unlandedWorth(data);
              final balance = data.balance() - unlandedWorth;
              return _EggBalance(
                count: balance,
                gain: _gainController,
                lastGain: _lastGain,
                color: eggColor,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EggSlot extends StatelessWidget {
  final NamidaEgg egg;
  final bool isCollected;
  final Color color;
  final Animation<double>? fall;
  final Animation<Offset> hop;
  final Animation<double>? shine;
  final Animation<double> wiggle;
  final void Function() onTap;

  const _EggSlot({
    required this.egg,
    required this.isCollected,
    required this.color,
    required this.fall,
    required this.hop,
    required this.shine,
    required this.wiggle,
    required this.onTap,
  });

  static const _kWidth = 16.0;
  static const _kSize = Size(_kWidth, 21.0);
  static const _wiggleTurns = _WiggleTurns();
  static final _fallOffset = Tween(begin: const Offset(0.0, -3.5), end: Offset.zero).chain(CurveTween(curve: Curves.bounceOut));
  static final _fadeIn = CurveTween(curve: const Interval(0.0, 0.15));
  static final _landingBurst = CurveTween(curve: const Interval(_EggsStageState._kLandingPoint, 0.9));

  String _tooltipText() {
    final text = isCollected ? '${egg.toText()} · found' : egg.toHint();
    return egg.worth > 1 ? '$text (×${egg.worth})' : text;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final questionMark = isCollected
        ? null
        : Center(
            child: Text(
              '?',
              style: textTheme.displaySmall?.copyWith(
                fontSize: 10.0,
                color: color.withOpacityExt(0.7),
              ),
            ),
          );
    Widget eggWidget = SizedBox.fromSize(
      size: _kSize,
      child: CustomPaint(
        painter: _EggPainter(color: color, isFilled: isCollected, shine: isCollected ? shine : null),
        child: questionMark,
      ),
    );
    final fall = this.fall;
    if (fall != null) {
      eggWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _BurstPainter(progress: fall.drive(_landingBurst), color: color),
            ),
          ),
          FadeTransition(
            opacity: fall.drive(_fadeIn),
            child: SlideTransition(
              position: fall.drive(_fallOffset),
              child: eggWidget,
            ),
          ),
        ],
      );
    }
    return NamidaTooltip(
      message: _tooltipText,
      triggerMode: TooltipTriggerMode.tap,
      onTriggered: onTap,
      child: SlideTransition(
        position: hop,
        child: RotationTransition(
          turns: wiggle.drive(_wiggleTurns),
          alignment: Alignment.bottomCenter,
          child: eggWidget,
        ),
      ),
    );
  }
}

class _EggBalance extends StatelessWidget {
  final int count;
  final Animation<double> gain;
  final int lastGain;
  final Color color;

  const _EggBalance({
    required this.count,
    required this.gain,
    required this.lastGain,
    required this.color,
  });

  static final _gainRise = Tween(begin: const Offset(0.0, 0.4), end: const Offset(0.0, -0.9)).chain(CurveTween(curve: Curves.easeOutCubic));
  static final _gainFade = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15.0),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 45.0),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 40.0),
  ]);

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final gainStyle = textTheme.displaySmall?.copyWith(
      color: color,
      fontWeight: FontWeight.w800,
    );
    return NamidaTooltip(
      message: () => 'eggs to spend',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size: const Size(18.0, 24.0),
            painter: _EggPainter(color: color, isFilled: true),
          ),
          const SizedBox(
            width: 6.0,
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              _RollingCount(
                count: count,
                style: textTheme.displayMedium,
              ),
              Positioned(
                left: 0.0,
                bottom: 0.0,
                child: FadeTransition(
                  opacity: gain.drive(_gainFade),
                  child: SlideTransition(
                    position: gain.drive(_gainRise),
                    child: Text(
                      '+$lastGain',
                      style: gainStyle,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RollingCount extends StatelessWidget {
  final int count;
  final TextStyle? style;

  const _RollingCount({required this.count, required this.style});

  static final _rollIn = Tween(begin: const Offset(0.0, 0.6), end: Offset.zero);

  static Widget _rollTransition(Widget child, Animation<double> animation) {
    return ClipRect(
      child: SlideTransition(
        position: animation.drive(_rollIn),
        child: FadeTransition(
          opacity: animation,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: _rollTransition,
      child: Text(
        '×$count',
        key: ValueKey(count),
        style: style,
      ),
    );
  }
}

class _FloatingEgg extends StatelessWidget {
  final bool isActive;

  const _FloatingEgg({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final color = isActive ? theme.colorScheme.primary : theme.disabledColor;
    final egg = SizedBox(
      width: 14.0,
      height: 18.0,
      child: CustomPaint(
        painter: _EggPainter(color: color, isFilled: isActive),
        foregroundPainter: isActive ? _GlintPainter(clock: NamidaFloatClock.instance) : null,
      ),
    );
    return RepaintBoundary(
      child: FloatingImage(
        enabled: isActive,
        amplitude: 1.6,
        cycleDuration: const Duration(milliseconds: 3600),
        randomness: 0.35,
        rotationAmplitude: 0.1,
        alignment: Alignment.bottomCenter,
        child: egg,
      ),
    );
  }
}

class _PoppingEgg extends StatefulWidget {
  final NamidaEgg egg;

  const _PoppingEgg({required this.egg});

  @override
  State<_PoppingEgg> createState() => _PoppingEggState();
}

class _PoppingEggState extends State<_PoppingEgg> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  static final _scale = CurveTween(curve: Curves.elasticOut);
  static final _burst = CurveTween(curve: const Interval(0.15, 0.8));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.egg.worth > 1 ? _kGoldenEggColor : context.theme.colorScheme.primary;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _BurstPainter(progress: _controller.drive(_burst), color: color),
          ),
        ),
        ScaleTransition(
          scale: _controller.drive(_scale),
          child: CustomPaint(
            size: const Size(17.0, 22.0),
            painter: _EggPainter(color: color, isFilled: true),
          ),
        ),
      ],
    );
  }
}

class _HopOffset extends Animatable<Offset> {
  final int index;

  const _HopOffset(this.index);

  static const _kAirShare = 0.35;
  static const _kHeight = 0.22;
  static final _step = (1.0 - _kAirShare) / (NamidaEgg.values.length - 1);

  @override
  Offset transform(double t) {
    final start = index * _step;
    final airborne = (t - start) / _kAirShare;
    if (airborne <= 0.0 || airborne >= 1.0) return Offset.zero;
    final lift = math.sin(airborne * math.pi);
    return Offset(0.0, -_kHeight * lift);
  }
}

class _WiggleTurns extends Animatable<double> {
  const _WiggleTurns();

  static const _kSwings = 3;
  static const _kMaxTurns = 0.045;

  @override
  double transform(double t) {
    if (t <= 0.0 || t >= 1.0) return 0.0;
    final swing = math.sin(t * _kSwings * 2 * math.pi);
    return swing * _kMaxTurns * (1.0 - t);
  }
}
