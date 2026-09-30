// parametric equalizer and audio output ui by claude
part of 'equalizer_page.dart';

class _ParametricEqualizerSection extends StatefulWidget {
  final _SoundControlMainSlidersColumnUpdateConfig updateConfig;
  final bool isGlobal;

  const _ParametricEqualizerSection({
    required this.updateConfig,
    required this.isGlobal,
  });

  @override
  State<_ParametricEqualizerSection> createState() => _ParametricEqualizerSectionState();
}

class _ParametricEqualizerSectionState extends State<_ParametricEqualizerSection> {
  final _selectedBandId = Rxn<int>();
  bool _showSliders = false;

  @override
  void dispose() {
    _selectedBandId.close();
    super.dispose();
  }

  _SoundControlMainSlidersColumnUpdateConfig get _config => widget.updateConfig;
  ParametricEqualizer get _equalizer => _config.equalizerRx.value;

  void _setEqualizer(ParametricEqualizer equalizer) => _config.setEqualizer(equalizer, null);

  void _updateBand(EqualizerBand band) => _setEqualizer(_equalizer.withBand(band));

  void _deleteBand(int id) {
    _setEqualizer(_equalizer.withoutBand(id));
    if (_selectedBandId.value == id) _selectedBandId.value = null;
  }

  void _addBand() {
    final frequency = _widestGapFrequency(_equalizer);
    _addBandAt(frequency, 0.0);
  }

  void _addBandAt(double frequency, double gain) {
    final equalizer = _equalizer;
    final id = equalizer.getNextBandId();
    final band = EqualizerBand(id: id, frequency: frequency, gain: gain);
    _setEqualizer(equalizer.withBand(band));
    _selectedBandId.value = band.id;
    _openBandEditor(band.id);
  }

  /// the log-center of the widest empty stretch, a new band lands where nothing is shaped yet.
  static double _widestGapFrequency(ParametricEqualizer equalizer) {
    final points = [
      _EqualizerScale.kMinFrequency,
      ...equalizer.bands.map((b) => b.frequency.clampDouble(_EqualizerScale.kMinFrequency, _EqualizerScale.kMaxFrequency)),
      _EqualizerScale.kMaxFrequency,
    ]..sort();
    var bestRatio = 0.0;
    var best = 1000.0;
    for (int i = 1; i < points.length; i++) {
      final ratio = points[i] / points[i - 1];
      if (ratio > bestRatio) {
        bestRatio = ratio;
        best = math.sqrt(points[i] * points[i - 1]);
      }
    }
    return best.roundDecimals(0);
  }

  void _openBandEditor(int id) {
    NamidaNavigator.inst.showSheet(
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context, bottomPadding, maxWidth, maxHeight) => _EqualizerBandEditor(
        bandId: id,
        equalizerRx: _config.equalizerRx,
        onChanged: _updateBand,
        onDelete: () {
          _deleteBand(id);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ObxO(
          rx: _config.equalizerEnabledRx,
          builder: (context, enabled) => NamidaInkWell(
            onTap: () => _config.setEqualizerEnabled(!enabled),
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: _SliderTextWidget(
              icon: Broken.chart_3,
              title: lang.equalizer,
              value: 0.0,
              displayValue: false,
              trailing: Row(
                children: [
                  _EqualizerViewToggle(
                    showSliders: _showSliders,
                    onChanged: (showSliders) => setState(() => _showSliders = showSliders),
                  ),
                  if (NamidaFeaturesVisibility.methodOpenSystemEqualizer && widget.isGlobal) ...[
                    const SizedBox(width: 2.0),
                    IconButton(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      tooltip: lang.openApp,
                      icon: Icon(
                        Broken.export_2,
                        size: 20.0,
                        color: context.defaultIconColor(),
                      ),
                      onPressed: () => NamidaChannel.inst.openSystemEqualizer(
                        Player.inst.androidSessionId,
                        package: settings.customEQPackage.value,
                      ),
                    ),
                  ],
                  const SizedBox(width: 8.0),
                  CustomSwitch(
                    active: enabled,
                    passedColor: null,
                  ),
                ],
              ),
            ),
          ),
        ),
        ObxO(
          rx: _config.equalizerEnabledRx,
          builder: (context, enabled) => AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: enabled ? 1.0 : 0.5,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Obx(
                    (context) {
                      final equalizer = _config.equalizerRx.valueR;
                      final selectedId = _selectedBandId.valueR;
                      return _showSliders
                          ? _EqualizerGainSliders(
                              equalizer: equalizer,
                              onBandChanged: _updateBand,
                            )
                          : _EqualizerCurve(
                              equalizer: equalizer,
                              selectedBandId: selectedId,
                              onBandChanged: _updateBand,
                              onBandSelected: (id) => _selectedBandId.value = id,
                              onBandEditRequested: _openBandEditor,
                              onBandAddRequested: _addBandAt,
                            );
                    },
                  ),
                ),
                const SizedBox(height: 8.0),
                Obx(
                  (context) => _EqualizerBandsRow(
                    equalizer: _config.equalizerRx.valueR,
                    selectedBandId: _selectedBandId.valueR,
                    onBandTap: (id) {
                      _selectedBandId.value = id;
                      _openBandEditor(id);
                    },
                    onAddTap: _addBand,
                  ),
                ),
                const SizedBox(height: 6.0),
                Obx(
                  (context) => _EqualizerPreampRow(
                    equalizer: _config.equalizerRx.valueR,
                    onChanged: _setEqualizer,
                  ),
                ),
                const SizedBox(height: 6.0),
                _EqualizerPresetsRow(
                  config: _config,
                  isGlobal: widget.isGlobal,
                ),
                _EqualizerActionsRow(
                  config: _config,
                ),
                SizedBox(
                  height: 4.0,
                  child: ColoredBox(color: theme.cardColor),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// log frequency axis and a dB axis wide enough for the strongest band.
class _EqualizerScale {
  static const kMinFrequency = 20.0;
  static const kMaxFrequency = 20000.0;
  static final _logSpan = math.log(kMaxFrequency / kMinFrequency);
  static const _kHorizontalInset = 16.0;
  static const _kVerticalInset = 12.0;

  final Size size;
  final double dbRange;

  const _EqualizerScale(this.size, this.dbRange);

  factory _EqualizerScale.forEqualizer(Size size, ParametricEqualizer equalizer) {
    var strongest = 0.0;
    for (final band in equalizer.bands) {
      if (band.type.hasGain && band.gain.abs() > strongest) strongest = band.gain.abs();
    }
    final range = strongest <= 12.0
        ? 12.0
        : strongest <= 18.0
        ? 18.0
        : strongest <= 24.0
        ? 24.0
        : EqualizerBand.kMaxGain;
    return _EqualizerScale(size, range);
  }

  double get _plotWidth => size.width - _kHorizontalInset * 2;
  double get _halfPlotHeight => size.height / 2 - _kVerticalInset;

  double xOf(double frequency) {
    final position = math.log(frequency.clampDouble(kMinFrequency, kMaxFrequency) / kMinFrequency) / _logSpan;
    return _kHorizontalInset + position * _plotWidth;
  }

  double yOf(double db) => size.height / 2 - db.clampDouble(-dbRange, dbRange) / dbRange * _halfPlotHeight;

  double frequencyAt(double x) {
    final position = ((x - _kHorizontalInset) / _plotWidth).clampDouble(0.0, 1.0);
    return kMinFrequency * math.exp(position * _logSpan);
  }

  double dbAt(double y) => (size.height / 2 - y) / _halfPlotHeight * dbRange;

  /// on the curve itself, where the band's effect is actually heard.
  Offset nodeOf(ParametricEqualizer equalizer, EqualizerBand band) {
    final channel = band.channel == EqualizerChannel.right ? EqualizerChannel.right : EqualizerChannel.left;
    final db = equalizer.responseDb(band.frequency, channel: channel);
    return Offset(xOf(band.frequency), yOf(db));
  }
}

class _EqualizerCurve extends StatefulWidget {
  final ParametricEqualizer equalizer;
  final int? selectedBandId;
  final void Function(EqualizerBand band) onBandChanged;
  final void Function(int? id) onBandSelected;
  final void Function(int id) onBandEditRequested;
  final void Function(double frequency, double gain) onBandAddRequested;

  const _EqualizerCurve({
    required this.equalizer,
    required this.selectedBandId,
    required this.onBandChanged,
    required this.onBandSelected,
    required this.onBandEditRequested,
    required this.onBandAddRequested,
  });

  @override
  State<_EqualizerCurve> createState() => _EqualizerCurveState();
}

class _EqualizerCurveState extends State<_EqualizerCurve> {
  static const _kHeight = 220.0;
  static const _kTouchRadius = 26.0;

  int? _draggingBandId;
  double _dragStartGain = 0.0;
  double _dragStartDb = 0.0;

  /// the axis keeps its range while dragging, otherwise the band would jump when the range grows under the finger.
  double? _dragDbRange;

  EqualizerBand? _bandAt(Offset position, _EqualizerScale scale) {
    EqualizerBand? nearest;
    var nearestDistance = _kTouchRadius;
    for (final band in widget.equalizer.bands) {
      final distance = (scale.nodeOf(widget.equalizer, band) - position).distance;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = band;
      }
    }
    return nearest;
  }

  EqualizerBand? _bandById(int? id) => widget.equalizer.bands.firstWhereEff((b) => b.id == id);

  void _startDrag(Offset position, _EqualizerScale scale) {
    final band = _bandAt(position, scale);
    _draggingBandId = band?.id;
    widget.onBandSelected(band?.id);
    if (band == null) return;
    _dragStartGain = band.gain;
    _dragStartDb = scale.dbAt(position.dy);
    _dragDbRange = scale.dbRange;
  }

  /// the gain follows the finger's movement rather than its position, the node sits on the combined curve, not on the band's own gain.
  void _dragTo(Offset position, _EqualizerScale scale) {
    final band = _bandById(_draggingBandId);
    if (band == null) return;
    final frequencyRaw = scale.frequencyAt(position.dx);
    final frequency = frequencyRaw.roundDecimals(frequencyDecimals(frequencyRaw));
    double? gain;
    if (band.type.hasGain) {
      final gainRaw = _dragStartGain + scale.dbAt(position.dy) - _dragStartDb;
      gain = gainRaw.clampDouble(EqualizerBand.kMinGain, EqualizerBand.kMaxGain).roundDecimals(1);
    }
    widget.onBandChanged(band.copyWith(frequency: frequency, gain: gain));
  }

  void _endDrag() {
    _draggingBandId = null;
    if (_dragDbRange == null) return;
    setState(() => _dragDbRange = null);
  }

  void _onTapUp(Offset position, _EqualizerScale scale) {
    final band = _bandAt(position, scale);
    widget.onBandSelected(band?.id);
    if (band != null) widget.onBandEditRequested(band.id);
  }

  void _onLongPress(Offset position, _EqualizerScale scale) {
    final band = _bandAt(position, scale);
    if (band != null) {
      widget.onBandEditRequested(band.id);
      return;
    }
    final frequencyRaw = scale.frequencyAt(position.dx);
    final frequency = frequencyRaw.roundDecimals(frequencyDecimals(frequencyRaw));
    final gain = scale.dbAt(position.dy).clampDouble(-scale.dbRange, scale.dbRange).roundDecimals(1);
    widget.onBandAddRequested(frequency, gain);
  }

  static int frequencyDecimals(double frequency) => frequency < 100 ? 1 : 0;

  void _onScroll(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final band = _bandById(widget.selectedBandId);
    if (band == null) return;
    final factor = event.scrollDelta.dy < 0 ? 1.1 : 1 / 1.1;
    final q = (band.q * factor).clampDouble(EqualizerBand.kMinQ, EqualizerBand.kMaxQ);
    widget.onBandChanged(band.copyWith(q: q.roundDecimals(3)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return SizedBox(
      height: _kHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, _kHeight);
          final dragDbRange = _dragDbRange;
          final scale = dragDbRange == null ? _EqualizerScale.forEqualizer(size, widget.equalizer) : _EqualizerScale(size, dragDbRange);
          return RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: {
              _NodePanGestureRecognizer: GestureRecognizerFactoryWithHandlers<_NodePanGestureRecognizer>(
                () => _NodePanGestureRecognizer(),
                (recognizer) => recognizer
                  ..dragStartBehavior = DragStartBehavior.down
                  ..isOnNode = ((position) => _bandAt(position, scale) != null)
                  ..onStart = (details) {
                    _startDrag(details.localPosition, scale);
                  }
                  ..onUpdate = (details) {
                    _dragTo(details.localPosition, scale);
                  }
                  ..onEnd = (_) {
                    _endDrag();
                  }
                  ..onCancel = () {
                    _endDrag();
                  },
              ),
              TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                () => TapGestureRecognizer(),
                (recognizer) => recognizer.onTapUp = (details) {
                  _onTapUp(details.localPosition, scale);
                },
              ),
              LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(),
                (recognizer) => recognizer.onLongPressStart = (details) {
                  _onLongPress(details.localPosition, scale);
                },
              ),
            },
            child: Listener(
              onPointerSignal: _onScroll,
              child: CustomPaint(
                size: scale.size,
                painter: _EqualizerCurvePainter(
                  equalizer: widget.equalizer,
                  scale: scale,
                  selectedBandId: widget.selectedBandId,
                  curveColor: theme.colorScheme.primary,
                  rightCurveColor: theme.colorScheme.tertiary,
                  gridColor: theme.colorScheme.onSurface.withOpacityExt(0.08),
                  labelStyle: theme.textTheme.displaySmall?.copyWith(fontSize: 10.0) ?? const TextStyle(fontSize: 10.0),
                  nodeTextColor: theme.colorScheme.onPrimary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// only joins the gesture arena when the pointer lands on a band, so the page keeps scrolling everywhere else.
/// it claims the drag after a few pixels, well before the page's own scroll and tab swipe would.
class _NodePanGestureRecognizer extends PanGestureRecognizer {
  static const _kAcceptDistance = 4.0;

  bool Function(Offset localPosition) isOnNode = _never;
  Offset? _downPosition;
  double _movedDistance = 0.0;

  static bool _never(Offset _) => false;

  @override
  bool isPointerAllowed(PointerEvent event) => isOnNode(event.localPosition) && super.isPointerAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _downPosition = event.position;
    _movedDistance = 0.0;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    final downPosition = _downPosition;
    if (event is PointerMoveEvent && downPosition != null) _movedDistance = (event.position - downPosition).distance;
    super.handleEvent(event);
  }

  @override
  bool hasSufficientGlobalDistanceToAccept(PointerDeviceKind pointerDeviceKind, double? deviceTouchSlop) => _movedDistance > _kAcceptDistance;
}

class _EqualizerCurvePainter extends CustomPainter {
  final ParametricEqualizer equalizer;
  final _EqualizerScale scale;
  final int? selectedBandId;
  final Color curveColor;
  final Color rightCurveColor;
  final Color gridColor;
  final TextStyle labelStyle;
  final Color nodeTextColor;

  const _EqualizerCurvePainter({
    required this.equalizer,
    required this.scale,
    required this.selectedBandId,
    required this.curveColor,
    required this.rightCurveColor,
    required this.gridColor,
    required this.labelStyle,
    required this.nodeTextColor,
  });

  static const _kGridFrequencies = <(double, String)>[
    (20.0, '20'), (50.0, '50'), (100.0, '100'), (200.0, '200'), (500.0, '500'), //
    (1000.0, '1k'), (2000.0, '2k'), (5000.0, '5k'), (10000.0, '10k'), (20000.0, '20k'),
  ];

  static final _curveFrequenciesByCount = <int, List<double>>{};

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    for (final (frequency, label) in _kGridFrequencies) {
      final x = scale.xOf(frequency);
      canvas.drawLine(Offset(x, 0.0), Offset(x, size.height), gridPaint);
      _drawLabel(canvas, label, Offset(x + 2.0, size.height - 12.0));
    }
    for (final db in [-scale.dbRange, -scale.dbRange / 2, 0.0, scale.dbRange / 2, scale.dbRange]) {
      final y = scale.yOf(db);
      gridPaint.strokeWidth = db == 0.0 ? 1.6 : 1.0;
      canvas.drawLine(Offset(0.0, y), Offset(size.width, y), gridPaint);
      if (db == 0.0) continue;
      final dbRounded = db.round();
      final label = db > 0 ? '+$dbRounded' : '$dbRounded';
      _drawLabel(canvas, label, Offset(2.0, y - 12.0));
    }

    final pointsCount = size.width.round().clamp(64, 400);
    final frequencies = _curveFrequenciesByCount[pointsCount] ??= ParametricEqualizer.logFrequencies(_EqualizerScale.kMinFrequency, _EqualizerScale.kMaxFrequency, pointsCount);
    if (equalizer.hasChannelSpecificBands()) {
      final rightCurve = equalizer.responseCurve(frequencies, channel: EqualizerChannel.right);
      _drawCurve(canvas, frequencies, rightCurve, rightCurveColor, fill: false);
    }
    final leftCurve = equalizer.responseCurve(frequencies);
    _drawCurve(canvas, frequencies, leftCurve, curveColor, fill: true);

    for (int i = 0; i < equalizer.bands.length; i++) {
      final band = equalizer.bands[i];
      final center = scale.nodeOf(equalizer, band);
      final selected = band.id == selectedBandId;
      final bandColor = band.channel == EqualizerChannel.right ? rightCurveColor : curveColor;
      final color = band.enabled ? bandColor : gridColor.withOpacityExt(0.6);
      canvas.drawCircle(center, selected ? 12.0 : 10.0, Paint()..color = color);
      if (selected) {
        canvas.drawCircle(
          center,
          15.0,
          Paint()
            ..color = color.withOpacityExt(0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
      }
      final text = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: labelStyle.copyWith(color: nodeTextColor, fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
    }
  }

  void _drawCurve(Canvas canvas, List<double> frequencies, List<double> curve, Color color, {required bool fill}) {
    final path = Path();
    for (int i = 0; i < frequencies.length; i++) {
      final point = Offset(scale.xOf(frequencies[i]), scale.yOf(curve[i]));
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    if (fill) {
      final zeroY = scale.yOf(0.0);
      final area = Path.from(path)
        ..lineTo(scale.xOf(frequencies.last), zeroY)
        ..lineTo(scale.xOf(frequencies.first), zeroY)
        ..close();
      canvas.drawPath(area, Paint()..color = color.withOpacityExt(0.15));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawLabel(Canvas canvas, String label, Offset offset) {
    final text = TextPainter(
      text: TextSpan(text: label, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final maxX = scale.size.width - text.width;
    final position = Offset(math.min(offset.dx, maxX), offset.dy);
    text.paint(canvas, position);
  }

  @override
  bool shouldRepaint(covariant _EqualizerCurvePainter oldDelegate) {
    return oldDelegate.equalizer != equalizer ||
        oldDelegate.selectedBandId != selectedBandId ||
        oldDelegate.scale.size != scale.size ||
        oldDelegate.scale.dbRange != scale.dbRange ||
        oldDelegate.curveColor != curveColor ||
        oldDelegate.rightCurveColor != rightCurveColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.nodeTextColor != nodeTextColor;
  }
}

class _EqualizerGainSliders extends StatelessWidget {
  final ParametricEqualizer equalizer;
  final void Function(EqualizerBand band) onBandChanged;

  const _EqualizerGainSliders({
    required this.equalizer,
    required this.onBandChanged,
  });

  static const _kColumnWidth = 44.0;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final bands = equalizer.bands.where((b) => b.type.hasGain).toList();
    final scale = _EqualizerScale.forEqualizer(Size.zero, equalizer);
    final range = scale.dbRange;
    return SizedBox(
      height: context.height * 0.4,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final evenColumnWidth = bands.isEmpty ? 0.0 : constraints.maxWidth / bands.length;
          final columnWidth = evenColumnWidth.withMinimum(_kColumnWidth);
          final circleWidth = (columnWidth * 0.5).clampDouble(8.0, 24.0);
          return SmoothSingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final band in bands)
                  SizedBox(
                    width: columnWidth,
                    child: Column(
                      children: [
                        FittedBox(
                          child: Text(
                            _EqualizerFormat.gain(band.gain),
                            style: textTheme.displaySmall,
                          ),
                        ),
                        const SizedBox(height: 6.0),
                        Expanded(
                          child: VerticalSlider(
                            min: -range,
                            max: range,
                            value: band.gain.clampDouble(-range, range),
                            onChanged: (value) => onBandChanged(band.copyWith(gain: value.roundDecimals(1))),
                            circleWidth: circleWidth,
                            tapToUpdate: () => settings.equalizer.uiTapToUpdate.value,
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        FittedBox(
                          child: Text(
                            _EqualizerFormat.frequency(band.frequency),
                            style: textTheme.displaySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EqualizerBandsRow extends StatelessWidget {
  final ParametricEqualizer equalizer;
  final int? selectedBandId;
  final void Function(int id) onBandTap;
  final VoidCallback onAddTap;

  const _EqualizerBandsRow({
    required this.equalizer,
    required this.selectedBandId,
    required this.onBandTap,
    required this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    return SmoothSingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          for (int i = 0; i < equalizer.bands.length; i++)
            _EqualizerBandChip(
              index: i,
              band: equalizer.bands[i],
              selected: equalizer.bands[i].id == selectedBandId,
              onTap: () => onBandTap(equalizer.bands[i].id),
            ),
          NamidaInkWell(
            borderRadius: 8.0,
            margin: const EdgeInsets.symmetric(horizontal: 4.0),
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            bgColor: theme.colorScheme.secondaryContainer.withOpacityExt(0.4),
            onTap: onAddTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Broken.add,
                  size: 16.0,
                ),
                const SizedBox(width: 4.0),
                Text(
                  lang.addBand,
                  style: textTheme.displaySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EqualizerBandChip extends StatelessWidget {
  final int index;
  final EqualizerBand band;
  final bool selected;
  final VoidCallback onTap;

  const _EqualizerBandChip({
    required this.index,
    required this.band,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final qText = 'Q ${band.q.roundDecimals(2)}';
    final placeText = [
      _EqualizerFormat.frequency(band.frequency),
      if (band.type != EqualizerBandType.peak) band.type.toText(),
      if (band.channel != EqualizerChannel.all) band.channel.toText(),
    ].join(' · ');
    final shapeText = [
      if (band.type.hasGain) _EqualizerFormat.gain(band.gain),
      if (band.type.hasOrder) _EqualizerFormat.slope(band.order) else qText,
    ].join(' · ');
    return Opacity(
      opacity: band.enabled ? 1.0 : 0.5,
      child: NamidaInkWell(
        animationDurationMS: 200,
        borderRadius: 8.0,
        margin: const EdgeInsets.symmetric(horizontal: 4.0),
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
        bgColor: selected ? theme.colorScheme.primary.withOpacityExt(0.3) : theme.colorScheme.secondary.withOpacityExt(0.12),
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${index + 1}',
              style: textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 8.0),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  placeText,
                  style: textTheme.displayMedium?.copyWith(fontSize: 13.0),
                ),
                Text(
                  shapeText,
                  style: textTheme.displaySmall?.copyWith(fontSize: 11.0),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EqualizerPreampRow extends StatelessWidget {
  final ParametricEqualizer equalizer;
  final void Function(ParametricEqualizer equalizer) onChanged;

  const _EqualizerPreampRow({
    required this.equalizer,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final limiterSupported = _EqualizerCapabilities.supportsLimiter();
    final effectivePreamp = equalizer.computeEffectivePreamp();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SliderTextWidget(
          icon: Broken.volume_high,
          title: lang.preamp,
          value: effectivePreamp,
          min: ParametricEqualizer.kMinPreamp,
          max: ParametricEqualizer.kMaxPreamp,
          valToText: _SliderTextWidget.toDecibelMultiplier,
          onManualChange: (value) {
            final preamp = value.clampDouble(ParametricEqualizer.kMinPreamp, ParametricEqualizer.kMaxPreamp);
            onChanged(equalizer.copyWith(autoPreamp: false, preamp: preamp));
          },
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _EqualizerToggleChip(
                title: lang.auto,
                active: equalizer.autoPreamp,
                onTap: () {
                  final preamp = effectivePreamp.clampDouble(ParametricEqualizer.kMinPreamp, ParametricEqualizer.kMaxPreamp);
                  onChanged(equalizer.copyWith(autoPreamp: !equalizer.autoPreamp, preamp: preamp));
                },
              ),
              const SizedBox(width: 6.0),
              AnimatedEnabled(
                enabled: limiterSupported,
                child: _EqualizerToggleChip(
                  title: lang.limiter,
                  active: equalizer.limiter && limiterSupported,
                  onTap: () => onChanged(equalizer.copyWith(limiter: !equalizer.limiter)),
                ),
              ),
            ],
          ),
        ),
        if (!equalizer.autoPreamp)
          Slider.adaptive(
            min: ParametricEqualizer.kMinPreamp,
            max: ParametricEqualizer.kMaxPreamp,
            divisions: 600,
            value: equalizer.preamp,
            label: _SliderTextWidget.toDecibelMultiplier(equalizer.preamp),
            onChanged: (value) => onChanged(equalizer.copyWith(preamp: value.roundDecimals(1))),
          ),
      ],
    );
  }
}

class _EqualizerToggleChip extends StatelessWidget {
  final String title;
  final bool active;
  final VoidCallback onTap;

  const _EqualizerToggleChip({
    required this.title,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return NamidaInkWell(
      animationDurationMS: 200,
      borderRadius: 8.0,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      bgColor: theme.colorScheme.secondaryContainer.withOpacityExt(active ? 0.6 : 0.15),
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (active) ...[
            const Icon(
              Broken.tick_circle,
              size: 12.0,
            ),
            const SizedBox(width: 4.0),
          ],
          Text(
            title,
            style: theme.textTheme.displaySmall,
          ),
        ],
      ),
    );
  }
}

class _EqualizerPresetsRow extends StatelessWidget {
  final _SoundControlMainSlidersColumnUpdateConfig config;
  final bool isGlobal;

  const _EqualizerPresetsRow({
    required this.config,
    required this.isGlobal,
  });

  void _openPresetOptions(EqualizerPreset preset) {
    NamidaNavigator.inst.showSheet(
      showDragHandle: true,
      builder: (context, bottomPadding, maxWidth, maxHeight) => _EqualizerPresetOptions(
        preset: preset,
        config: config,
        isGlobal: isGlobal,
      ),
    );
  }

  static final _defaultPresetNames = {for (final preset in EqualizerPreset.allDefaults) preset.name};

  /// built in presets are recognized by name, so edited ones keep their place too.
  static List<EqualizerPreset> _userPresetsFirst(List<EqualizerPreset> presets) {
    return [
      for (final preset in presets)
        if (!_defaultPresetNames.contains(preset.name)) preset,
      for (final preset in presets)
        if (_defaultPresetNames.contains(preset.name)) preset,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: SmoothSingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Obx(
          (context) {
            final activePreset = config.presetRx.valueR;
            final presets = _userPresetsFirst(settings.equalizer.eqPresets.valueR);
            final devicePresets = settings.equalizer.devicePresets.valueR;
            final routedDevice = AudioOutputController.inst.devices.valueR.firstWhereEff((d) => d.isRouted);
            final routedKey = AudioOutputController.inst.keyForDevicePreset(routedDevice);
            final activeColor = Color.alphaBlend(CurrentColor.inst.color.withOpacityExt(0.9), theme.scaffoldBackgroundColor);
            final inactiveColor = theme.colorScheme.secondary.withOpacityExt(0.15);
            return Row(
              children: [
                const SizedBox(width: 8.0),
                NamidaInkWell(
                  animationDurationMS: 200,
                  borderRadius: 5.0,
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  bgColor: activePreset == null ? activeColor : inactiveColor,
                  onTap: () => config.setEqualizer(config.equalizerRx.value, null),
                  child: Text(
                    lang.custom,
                    style: textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: activePreset == null ? Colors.white.withOpacityExt(0.7) : null,
                    ),
                  ),
                ),
                for (final preset in presets)
                  NamidaInkWell(
                    animationDurationMS: 200,
                    borderRadius: 5.0,
                    margin: const EdgeInsets.symmetric(horizontal: 4.0),
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    bgColor: activePreset?.name == preset.name ? activeColor : inactiveColor,
                    onTap: () => config.setEqualizer(preset.equalizer, preset),
                    onLongPress: () => _openPresetOptions(preset),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (devicePresets[routedKey] == preset.name) ...[
                          const Icon(
                            Broken.headphone,
                            size: 12.0,
                          ),
                          const SizedBox(width: 4.0),
                        ],
                        Text(
                          preset.name,
                          style: textTheme.displaySmall?.copyWith(
                            color: activePreset?.name == preset.name ? Colors.white.withOpacityExt(0.7) : null,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 8.0),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EqualizerPresetOptions extends StatelessWidget {
  final EqualizerPreset preset;
  final _SoundControlMainSlidersColumnUpdateConfig config;
  final bool isGlobal;

  const _EqualizerPresetOptions({
    required this.preset,
    required this.config,
    required this.isGlobal,
  });

  @override
  Widget build(BuildContext context) {
    final output = AudioOutputController.inst;
    final routed = output.getRoutedDevice();
    final deviceKey = output.keyForDevicePreset(routed);
    final deviceName = routed?.name ?? lang.systemDefault;
    final isDevicePreset = settings.equalizer.devicePresets.value[deviceKey] == preset.name;
    void pop() => Navigator.pop(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0).add(const EdgeInsets.only(bottom: 18.0)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            preset.name,
            style: context.textTheme.displayLarge,
          ),
          const SizedBox(height: 12.0),
          if (isGlobal)
            CustomListTile(
              icon: Broken.headphone,
              title: lang.useForDevice(device: deviceName),
              trailing: NamidaCheckMark(
                size: 16.0,
                active: isDevicePreset,
              ),
              onTap: () {
                output.setDevicePreset(deviceKey, isDevicePreset ? null : preset);
                pop();
              },
            ),
          CustomListTile(
            icon: Broken.document_download,
            title: lang.save,
            subtitle: lang.equalizer,
            onTap: () {
              final updated = preset.copyWith(equalizer: config.equalizerRx.value);
              settings.equalizer.putPreset(updated);
              pop();
            },
          ),
          CustomListTile(
            icon: Broken.edit_2,
            title: lang.rename,
            onTap: () {
              pop();
              _EqualizerPresetNameSheet.show(
                initialName: preset.name,
                onName: (name) => settings.equalizer.putPreset(preset.copyWith(name: name), replacing: preset.name),
              );
            },
          ),
          CustomListTile(
            icon: Broken.trash,
            title: lang.delete,
            onTap: () {
              settings.equalizer.removePreset(preset.name);
              pop();
            },
          ),
        ],
      ),
    );
  }
}

abstract final class _EqualizerPresetNameSheet {
  static void show({required String initialName, required void Function(String name) onName}) {
    showNamidaBottomSheetWithTextField(
      title: lang.saveAsPreset,
      textfieldConfig: BottomSheetTextFieldConfig(
        hintText: lang.name,
        labelText: lang.name,
        initalControllerText: initialName,
        validator: (text) => text == null || text.trim().isEmpty ? lang.emptyValue : null,
      ),
      buttonText: lang.save,
      onButtonTap: (text) {
        onName(text.trim());
        return true;
      },
    );
  }
}

class _EqualizerActionsRow extends StatelessWidget {
  final _SoundControlMainSlidersColumnUpdateConfig config;

  const _EqualizerActionsRow({required this.config});

  void _saveAsPreset() {
    _EqualizerPresetNameSheet.show(
      initialName: config.presetRx.value?.name ?? '',
      onName: (name) {
        final preset = EqualizerPreset(name: name, equalizer: config.equalizerRx.value);
        settings.equalizer.putPreset(preset);
        config.setEqualizer(preset.equalizer, preset);
      },
    );
  }

  void _openTemplates() {
    NamidaNavigator.inst.showSheet(
      showDragHandle: true,
      builder: (context, bottomPadding, maxWidth, maxHeight) {
        final current = config.equalizerRx.value;
        void apply(ParametricEqualizer template) {
          final equalizer = template.copyWith(autoPreamp: current.autoPreamp, preamp: current.preamp, limiter: current.limiter);
          config.setEqualizer(equalizer, null);
          Navigator.pop(context);
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0).add(const EdgeInsets.only(bottom: 18.0)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomListTile(
                icon: Broken.refresh,
                title: lang.restoreDefaults,
                onTap: () => apply(ParametricEqualizer.flat),
              ),
              for (final frequencies in const [
                ParametricEqualizer.graphic5Frequencies,
                ParametricEqualizer.graphic10Frequencies,
                ParametricEqualizer.graphic15Frequencies,
                ParametricEqualizer.graphic31Frequencies,
              ])
                CustomListTile(
                  icon: Broken.weight_1,
                  title: lang.graphicEqualizerBands(count: frequencies.length),
                  onTap: () => apply(ParametricEqualizer.graphic(frequencies)),
                ),
            ],
          ),
        );
      },
    );
  }

  void _import(String? text) {
    final imported = text == null ? null : ParametricEqualizer.fromEqualizerApo(text);
    if (imported == null) {
      snackyy(message: lang.equalizerImportFailed, top: false, isError: true);
      return;
    }
    final limiter = config.equalizerRx.value.limiter;
    config.setEqualizer(imported.copyWith(limiter: limiter), null);
  }

  void _openImport() {
    NamidaNavigator.inst.showSheet(
      showDragHandle: true,
      builder: (context, bottomPadding, maxWidth, maxHeight) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0).add(const EdgeInsets.only(bottom: 18.0)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomListTile(
              icon: Broken.copy,
              title: lang.fromClipboard,
              subtitle: 'Equalizer APO / AutoEQ',
              onTap: () async {
                Navigator.pop(context);
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                _import(data?.text);
              },
            ),
            CustomListTile(
              icon: Broken.document_upload,
              title: lang.pickFromStorage,
              subtitle: 'ParametricEQ.txt',
              onTap: () async {
                Navigator.pop(context);
                final file = await NamidaFileBrowser.pickFile(note: lang.equalizer, allowedExtensions: NamidaFileExtensionsWrapper.txt);
                if (file == null) return;
                final text = await file.readAsString();
                _import(text);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _export() async {
    final text = config.equalizerRx.value.toEqualizerApo();
    await Clipboard.setData(ClipboardData(text: text));
    snackyy(message: lang.copiedToClipboard, top: false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _EqualizerActionButton(
                icon: Broken.document_download,
                title: lang.saveAsPreset,
                onTap: _saveAsPreset,
              ),
            ),
            const SizedBox(width: 6.0),
            Expanded(
              child: _EqualizerActionButton(
                icon: Broken.element_equal,
                title: lang.templates,
                onTap: _openTemplates,
              ),
            ),
            const SizedBox(width: 6.0),
            Expanded(
              child: _EqualizerActionButton(
                icon: Broken.import,
                title: lang.import,
                onTap: _openImport,
              ),
            ),
            const SizedBox(width: 6.0),
            Expanded(
              child: _EqualizerActionButton(
                icon: Broken.export,
                title: lang.export,
                onTap: _export,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EqualizerActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _EqualizerActionButton({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return NamidaInkWell(
      borderRadius: 10.0,
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
      bgColor: theme.colorScheme.secondaryContainer.withOpacityExt(0.3),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 18.0,
          ),
          const SizedBox(height: 4.0),
          Text(
            title,
            style: theme.textTheme.displaySmall?.copyWith(fontSize: 11.0),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _EqualizerViewToggle extends StatelessWidget {
  final bool showSliders;
  final ValueChanged<bool> onChanged;

  const _EqualizerViewToggle({
    required this.showSliders,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Container(
      padding: const EdgeInsets.all(2.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withOpacityExt(0.25),
        borderRadius: BorderRadius.circular(8.0.multipliedRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _EqualizerViewToggleItem(
            icon: Broken.activity,
            tooltip: () => lang.curve,
            isSelected: !showSliders,
            onTap: () => onChanged(false),
          ),
          _EqualizerViewToggleItem(
            icon: Broken.candle,
            tooltip: () => lang.sliders,
            isSelected: showSliders,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _EqualizerViewToggleItem extends StatelessWidget {
  final IconData icon;
  final String Function() tooltip;
  final bool isSelected;
  final VoidCallback onTap;

  const _EqualizerViewToggleItem({
    required this.icon,
    required this.tooltip,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final bgColor = isSelected ? theme.colorScheme.primary.withOpacityExt(0.25) : null;
    return NamidaTooltip(
      message: tooltip,
      child: NamidaInkWell(
        animationDurationMS: 200,
        borderRadius: 6.0,
        padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 4.0),
        bgColor: bgColor,
        onTap: onTap,
        child: Icon(
          icon,
          size: 16.0,
        ),
      ),
    );
  }
}

class _EqualizerBandEditor extends StatelessWidget {
  final int bandId;
  final RxBaseCore<ParametricEqualizer> equalizerRx;
  final void Function(EqualizerBand band) onChanged;
  final VoidCallback onDelete;

  const _EqualizerBandEditor({
    required this.bandId,
    required this.equalizerRx,
    required this.onChanged,
    required this.onDelete,
  });

  static const _kMinFrequencyLog = 1.0; // log10(10)
  static final _kMaxFrequencyLog = math.log(EqualizerBand.kMaxFrequency) / math.ln10;
  static final _kMinQLog = math.log(EqualizerBand.kMinQ) / math.ln10;
  static final _kMaxQLog = math.log(EqualizerBand.kMaxQ) / math.ln10;

  static double _log10(double value) => math.log(value) / math.ln10;
  static double _pow10(double value) => math.pow(10, value).toDouble();

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0).add(const EdgeInsets.only(bottom: 18.0)),
      child: Obx(
        (context) {
          final equalizer = equalizerRx.valueR;
          final index = equalizer.bands.indexWhere((b) => b.id == bandId);
          if (index < 0) return const SizedBox();
          final band = equalizer.bands[index];
          final supportedTypes = _EqualizerCapabilities.getBandTypes();
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Text(
                      '${index + 1} · ${band.type.toText()}',
                      style: textTheme.displayLarge,
                    ),
                  ),
                  NamidaIconButton(
                    icon: Broken.trash,
                    tooltip: () => lang.delete,
                    onPressed: onDelete,
                  ),
                  NamidaInkWell(
                    borderRadius: 8.0,
                    padding: const EdgeInsets.all(6.0),
                    onTap: () => onChanged(band.copyWith(enabled: !band.enabled)),
                    child: CustomSwitch(
                      active: band.enabled,
                    ),
                  ),
                  const SizedBox(width: 8.0),
                ],
              ),
              const SizedBox(height: 8.0),
              Wrap(
                spacing: 6.0,
                runSpacing: 6.0,
                alignment: WrapAlignment.center,
                children: [
                  for (final type in EqualizerBandType.values)
                    AnimatedEnabled(
                      enabled: supportedTypes.contains(type),
                      child: Tooltip(
                        message: supportedTypes.contains(type) ? '' : lang.notAvailableForYourDevice,
                        child: _EqualizerToggleChip(
                          title: type.toText(),
                          active: band.type == type,
                          onTap: () => onChanged(band.copyWith(type: type)),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12.0),
              _SliderTextWidget(
                icon: Broken.sound,
                title: lang.frequency,
                value: band.frequency,
                min: EqualizerBand.kMinFrequency,
                max: EqualizerBand.kMaxFrequency,
                valToText: _EqualizerFormat.frequency,
                onManualChange: (value) => onChanged(band.copyWith(frequency: value.clampDouble(EqualizerBand.kMinFrequency, EqualizerBand.kMaxFrequency))),
              ),
              Slider.adaptive(
                min: _kMinFrequencyLog,
                max: _kMaxFrequencyLog,
                value: _log10(band.frequency.clampDouble(EqualizerBand.kMinFrequency, EqualizerBand.kMaxFrequency)),
                onChanged: (value) {
                  final frequencyRaw = _pow10(value);
                  final frequency = frequencyRaw.roundDecimals(_EqualizerCurveState.frequencyDecimals(frequencyRaw));
                  onChanged(band.copyWith(frequency: frequency));
                },
              ),
              if (band.type.hasGain) ...[
                _SliderTextWidget(
                  icon: Broken.volume_high,
                  title: lang.gain,
                  value: band.gain,
                  min: EqualizerBand.kMinGain,
                  max: EqualizerBand.kMaxGain,
                  valToText: _EqualizerFormat.gain,
                  onManualChange: (value) => onChanged(band.copyWith(gain: value.clampDouble(EqualizerBand.kMinGain, EqualizerBand.kMaxGain))),
                  restoreDefault: () => onChanged(band.copyWith(gain: 0.0)),
                ),
                Slider.adaptive(
                  min: EqualizerBand.kMinGain,
                  max: EqualizerBand.kMaxGain,
                  divisions: 600,
                  value: band.gain.clampDouble(EqualizerBand.kMinGain, EqualizerBand.kMaxGain),
                  label: _EqualizerFormat.gain(band.gain),
                  onChanged: (value) => onChanged(band.copyWith(gain: value.roundDecimals(1))),
                ),
              ],
              if (band.type.hasOrder) ...[
                _SliderTextWidget(
                  icon: Broken.chart_1,
                  title: lang.slope,
                  value: 0.0,
                  displayValue: false,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final order in EqualizerBand.kOrders)
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: _EqualizerToggleChip(
                            title: _EqualizerFormat.slope(order),
                            active: band.order == order,
                            onTap: () => onChanged(band.copyWith(order: order)),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8.0),
              ],
              if (!band.type.hasOrder || band.order == 2) ...[
                _SliderTextWidget(
                  icon: Broken.candle,
                  title: lang.qFactor,
                  value: band.q,
                  min: EqualizerBand.kMinQ,
                  max: EqualizerBand.kMaxQ,
                  valToText: (value) => value.roundDecimals(3).toString(),
                  onManualChange: (value) => onChanged(band.copyWith(q: value.clampDouble(EqualizerBand.kMinQ, EqualizerBand.kMaxQ))),
                  restoreDefault: () => onChanged(band.copyWith(q: EqualizerBand.kDefaultQ)),
                ),
                Slider.adaptive(
                  min: _kMinQLog,
                  max: _kMaxQLog,
                  value: _log10(band.q.clampDouble(EqualizerBand.kMinQ, EqualizerBand.kMaxQ)),
                  onChanged: (value) => onChanged(band.copyWith(q: _pow10(value).roundDecimals(3))),
                ),
              ],
              _SliderTextWidget(
                icon: Broken.airpods,
                title: lang.channel,
                value: 0.0,
                displayValue: false,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final channel in EqualizerChannel.values)
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: _EqualizerToggleChip(
                          title: channel.toText(),
                          active: band.channel == channel,
                          onTap: () => onChanged(band.copyWith(channel: channel)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

abstract final class _EqualizerCapabilities {
  static Set<EqualizerBandType> getBandTypes() => Platform.isAndroid ? EqualizerBandType.values.toSet() : CustomMPVPlayer.getSupportedEqualizerBandTypes();
  static bool supportsLimiter() => Platform.isAndroid || CustomMPVPlayer.supportsEqualizerLimiter();
}

abstract final class _EqualizerFormat {
  static String frequency(double value) {
    if (value < 1000) {
      final hz = value.roundDecimals(value < 100 ? 1 : 0);
      return '$hz Hz';
    }
    final khz = (value / 1000).roundDecimals(value < 10000 ? 2 : 1);
    return '$khz kHz';
  }

  static String gain(double value) {
    final sign = value > 0 ? '+' : '';
    final db = value.toStringAsFixed(1);
    return '$sign$db dB';
  }

  static String slope(int order) => '${order * 6} dB/oct';

  static String audioFormat(int bitDepth, int sampleRate) {
    final khz = (sampleRate / 1000).roundDecimals(1);
    return '$bitDepth-bit · $khz kHz';
  }
}

class _AudioOutputSection extends StatelessWidget {
  const _AudioOutputSection();

  void _openDevicePicker() {
    NamidaNavigator.inst.showSheet(
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context, bottomPadding, maxWidth, maxHeight) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0).add(const EdgeInsets.only(bottom: 18.0)),
        child: Obx(
          (context) {
            final selectedKey = settings.player.audioOutputDevice.valueR;
            final devices = AudioOutputController.inst.devices.valueR;
            final isUsbDirectActive = AudioOutputController.inst.isUsbDirectActiveR();
            void select(AudioOutputDevice? device) {
              AudioOutputController.inst.setDevice(device);
              Navigator.pop(context);
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  lang.outputDevice,
                  style: context.textTheme.displayLarge,
                ),
                const SizedBox(height: 12.0),
                AnimatedEnabled(
                  enabled: !isUsbDirectActive,
                  child: CustomListTile(
                    icon: Broken.autobrightness,
                    title: lang.systemDefault,
                    trailing: NamidaCheckMark(
                      size: 16.0,
                      active: selectedKey == null,
                    ),
                    onTap: () => select(null),
                  ),
                ),
                for (final device in devices)
                  AnimatedEnabled(
                    enabled: !isUsbDirectActive || device.isUsbDirect,
                    child: CustomListTile(
                      icon: device.type.toIcon(),
                      title: device.isUsbDirect ? '${device.name} (${lang.usbDirect})' : device.name,
                      subtitle: device.maxSampleRate > 0 ? lang.bitPerfectUpTo(format: _EqualizerFormat.audioFormat(device.maxBitDepth, device.maxSampleRate)) : null,
                      trailing: NamidaCheckMark(
                        size: 16.0,
                        active: device.isUsbDirect || (!isUsbDirectActive && selectedKey == device.key),
                      ),
                      onTap: device.isUsbDirect ? null : () => select(device),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _bitPerfectStatusText(BitPerfectStatusMessage? status) {
    if (!Platform.isAndroid || status == null) return lang.bitPerfectSubtitle;
    final format = _EqualizerFormat.audioFormat(status.bitDepth, status.sampleRate);
    final deviceName = status.deviceName ?? '';
    return switch (status.reason) {
      BitPerfectReasonMessage.active => lang.bitPerfectActiveOn(format: format, device: deviceName),
      BitPerfectReasonMessage.ready => lang.bitPerfectUpTo(format: format),
      BitPerfectReasonMessage.unsupportedAndroid || BitPerfectReasonMessage.noDevice => lang.bitPerfectNoDevice,
      BitPerfectReasonMessage.unsupportedFormat => lang.bitPerfectUnsupportedFormat,
      BitPerfectReasonMessage.disabled => lang.bitPerfectSubtitle,
    };
  }

  static String _usbDirectStatusText(UsbDirectStatusMessage? status) {
    if (status == null) return lang.usbDirectSubtitle;
    final deviceName = status.deviceName ?? '';
    return switch (status.state) {
      UsbDirectStateMessage.off => lang.usbDirectSubtitle,
      UsbDirectStateMessage.noDevice => lang.usbDirectNoDevice,
      UsbDirectStateMessage.awaitingPermission => lang.usbDirectAwaitingPermission(device: deviceName),
      UsbDirectStateMessage.permissionDenied => lang.usbDirectPermissionDenied(device: deviceName),
      UsbDirectStateMessage.unsupportedDevice => lang.usbDirectUnsupportedDevice(device: deviceName),
      UsbDirectStateMessage.failed => lang.usbDirectFailed(device: deviceName),
      UsbDirectStateMessage.active => status.hasHardwareVolume ? '$deviceName · ${lang.usbDirectHardwareVolume}' : deviceName,
    };
  }

  @override
  Widget build(BuildContext context) {
    final output = AudioOutputController.inst;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Obx(
            (context) {
              final selectedKey = settings.player.audioOutputDevice.valueR;
              final devices = output.devices.valueR;
              final shown = devices.firstWhereEff((d) => d.key == selectedKey) ?? devices.firstWhereEff((d) => d.isRouted);
              return CustomListTile(
                icon: shown?.type.toIcon() ?? Broken.sound,
                title: lang.outputDevice,
                subtitle: selectedKey == null ? lang.systemDefault : null,
                trailingText: shown?.name ?? lang.systemDefault,
                onTap: _openDevicePicker,
              );
            },
          ),
        ),
        const SizedBox(height: 4.0),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Obx(
                    (context) {
                      final isEnabled = settings.player.bitPerfect.valueR;
                      final statusText = isEnabled ? _bitPerfectStatusText(output.bitPerfectStatus.valueR) : lang.bitPerfectSubtitle;
                      return _OutputModeCard(
                        icon: Broken.flash,
                        title: lang.bitPerfect,
                        statusText: statusText,
                        isEnabled: isEnabled,
                        onTap: () => output.setBitPerfect(!isEnabled),
                      );
                    },
                  ),
                ),
                if (Platform.isAndroid) ...[
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Obx(
                      (context) {
                        final isEnabled = settings.player.usbDirect.valueR;
                        final statusText = isEnabled ? _usbDirectStatusText(output.usbDirectStatus.valueR) : lang.usbDirectSubtitle;
                        return _OutputModeCard(
                          icon: Broken.cpu,
                          title: lang.usbDirect,
                          statusText: statusText,
                          isEnabled: isEnabled,
                          onTap: () => output.setUsbDirect(!isEnabled),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8.0),
        const _ForcedOffChipsRow(),
        const SizedBox(height: 4.0),
      ],
    );
  }
}

class _OutputModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String statusText;
  final bool isEnabled;
  final VoidCallback onTap;

  const _OutputModeCard({
    required this.icon,
    required this.title,
    required this.statusText,
    required this.isEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final bgOpacity = isEnabled ? 0.35 : 0.12;
    return NamidaInkWell(
      animationDurationMS: 200,
      borderRadius: 12.0,
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
      bgColor: theme.colorScheme.secondaryContainer.withOpacityExt(bgOpacity),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18.0,
              ),
              const SizedBox(width: 6.0),
              Expanded(
                child: Text(
                  title,
                  style: textTheme.displayMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4.0),
              CustomSwitch(
                active: isEnabled,
                height: 18.0,
                width: 34.0,
                passedColor: null,
              ),
            ],
          ),
          const SizedBox(height: 4.0),
          Text(
            statusText,
            style: textTheme.displaySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// what bit-perfect and usb direct turn off in one line, each chip marked with the modes that can, struck through while one does.
class _ForcedOffChipsRow extends StatelessWidget {
  const _ForcedOffChipsRow();

  static final _entries = _buildEntries();

  static List<_ForcedOffEntry> _buildEntries() {
    final causes = AudioOutputForcedOffCause.values.where((c) => c.isAvailable()).toFixedList();
    final entries = <_ForcedOffEntry>[];
    for (final option in AudioOutputForcedOff.values) {
      if (!option.isAvailable()) continue;
      final optionCauses = causes.where((c) => AudioOutputController.getForcedOffOptionsOf(c).contains(option)).toFixedList();
      if (optionCauses.isNotEmpty) entries.add((option: option, causes: optionCauses));
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    return SizedBox(
      height: 28.0,
      child: Row(
        children: [
          const SizedBox(width: 12.0),
          const _SignalPathButton(),
          const SizedBox(width: 8.0),
          Expanded(
            child: Obx(
              (context) {
                final output = AudioOutputController.inst;
                return ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(right: 12.0),
                  children: [
                    Center(
                      child: Text(
                        '${lang.turnsOff}:',
                        style: textTheme.displaySmall,
                      ),
                    ),
                    for (final entry in _entries)
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: _ForcedOffChip(
                          title: entry.option.toText(),
                          causes: entry.causes,
                          activeCause: output.getForcedOffCauseR(entry.option),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ForcedOffChip extends StatelessWidget {
  final String title;
  final List<AudioOutputForcedOffCause> causes;
  final AudioOutputForcedOffCause? activeCause;

  const _ForcedOffChip({
    required this.title,
    required this.causes,
    required this.activeCause,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textStyle = theme.textTheme.displaySmall;
    final activeCause = this.activeCause;
    final isOff = activeCause != null;
    final baseColor = isOff ? theme.colorScheme.error : theme.colorScheme.secondaryContainer;
    final titleStyle = isOff ? textStyle?.copyWith(decoration: TextDecoration.lineThrough) : textStyle;
    final possibleCauseColor = theme.iconTheme.color?.withOpacityExt(0.5);
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
        decoration: BoxDecoration(
          color: baseColor.withOpacityExt(0.15),
          borderRadius: BorderRadius.circular(6.0.multipliedRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (activeCause != null)
              Icon(
                activeCause.toIcon(),
                size: 11.0,
              )
            else
              ...causes
                  .map(
                    (cause) => Icon(
                      cause.toIcon(),
                      size: 11.0,
                      color: possibleCauseColor,
                    ),
                  )
                  .addSeparators(
                    separator: const SizedBox(
                      width: 2.0,
                    ),
                  ),
            const SizedBox(width: 3.0),
            Text(
              title,
              style: titleStyle,
            ),
          ],
        ),
      ),
    );
  }
}

class _SignalPathButton extends StatelessWidget {
  const _SignalPathButton();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return NamidaInkWell(
      borderRadius: 8.0,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      bgColor: theme.colorScheme.secondaryContainer.withOpacityExt(0.35),
      onTap: SoundControlPage.showAudioPath,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Broken.routing_2,
            size: 14.0,
          ),
          const SizedBox(width: 4.0),
          Text(
            lang.signalPath,
            style: theme.textTheme.displaySmall,
          ),
        ],
      ),
    );
  }
}

class _ForcedOffBanner extends StatelessWidget {
  const _ForcedOffBanner();

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) {
        final output = AudioOutputController.inst;
        final cause = output.isBitPerfectActiveR()
            ? AudioOutputForcedOffCause.bitPerfect
            : output.isUsbDirectActiveR()
            ? AudioOutputForcedOffCause.usbDirect
            : null;
        if (cause == null) return const SizedBox();
        final theme = context.theme;
        final modeText = cause.toText();
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: theme.colorScheme.error.withOpacityExt(0.1),
            borderRadius: BorderRadius.circular(8.0.multipliedRadius),
          ),
          child: Row(
            children: [
              Icon(
                cause.toIcon(),
                size: 18.0,
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: Text(
                  lang.forcedOffBy(mode: modeText),
                  style: theme.textTheme.displaySmall,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// namida's own downmix, the system accessibility one affects every app and is only a shortcut here.
class _MonoAudioTile extends StatelessWidget {
  const _MonoAudioTile();

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) {
        final output = AudioOutputController.inst;
        final isEnabled = settings.player.monoAudio.valueR;
        final forcedOffCause = output.getForcedOffCauseR(AudioOutputForcedOff.monoAudio);
        return AnimatedEnabled(
          enabled: forcedOffCause == null,
          child: CustomListTile(
            extraDense: true,
            icon: Broken.airpods,
            title: lang.monoAudio,
            subtitleWidget: forcedOffCause == null
                ? null
                : DisabledByPill(
                    icon: forcedOffCause.toIcon(),
                    title: forcedOffCause.toText(),
                  ),
            onTap: () => output.setMonoAudio(!isEnabled),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (NamidaFeaturesVisibility.methodSetMonoAudio)
                  NamidaIconButton(
                    horizontalPadding: 6.0,
                    tooltip: () => lang.setMonoAudio,
                    icon: Broken.export_2,
                    iconSize: 18.0,
                    onPressed: () => NamidaChannel.inst.setMonoAudio(null),
                  ),
                CustomSwitch(
                  active: isEnabled,
                  passedColor: null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ForcedOffEnabled extends StatelessWidget {
  final AudioOutputForcedOff option;
  final Widget child;

  const _ForcedOffEnabled({
    required this.option,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(
      (context) => AnimatedEnabled(
        enabled: !AudioOutputController.inst.isForcedOffR(option),
        child: child,
      ),
    );
  }
}

typedef _ForcedOffEntry = ({AudioOutputForcedOff option, List<AudioOutputForcedOffCause> causes});
