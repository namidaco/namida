part of 'lyrics_editor_page.dart';

/// waveform around the playhead with a marker per line, markers can be dragged and the rest scrubs.
class _EditorTimeline extends StatefulWidget {
  final _LyricsEditorPageState state;

  const _EditorTimeline({required this.state});

  @override
  State<_EditorTimeline> createState() => _EditorTimelineState();
}

class _EditorTimelineState extends State<_EditorTimeline> {
  static const _kWindowMS = 8000;
  static const _kPlayheadFraction = 0.35;
  static const _kMarkerHitSlop = 14.0;
  static const _kHeight = 76.0;

  /// applied as a seek when the scrub ends.
  final _scrubOffsetMS = 0.obs;
  final _labelsCache = <int, TextPainter>{};

  double _width = 1.0;
  int? _draggedLine;
  int _dragStartMS = 0;
  double _dragDistancePx = 0.0;

  _LyricsEditorPageState get _state => widget.state;

  @override
  void initState() {
    super.initState();
    SpectrumController.inst.attach(isSpectrumNeeded: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _clearLabels();
  }

  @override
  void dispose() {
    SpectrumController.inst.detach(isSpectrumNeeded: true);
    _scrubOffsetMS.close();
    _clearLabels();
    super.dispose();
  }

  void _clearLabels() {
    for (final label in _labelsCache.values) {
      label.dispose();
    }
    _labelsCache.clear();
  }

  int _windowStartMS() {
    final positionMS = _state._positionMS.value + _scrubOffsetMS.value;
    return positionMS - (_kWindowMS * _kPlayheadFraction).round();
  }

  double _msPerPx() => _kWindowMS / _width;

  int? _hitMarker(double dx) {
    final windowStartMS = _windowStartMS();
    final msPerPx = _msPerPx();
    int? hitLine;
    var hitDistance = _kMarkerHitSlop;
    _state._doc.forEachTimedInRange(windowStartMS, windowStartMS + _kWindowMS, (lineIndex, startMS) {
      final x = (startMS - windowStartMS) / msPerPx;
      final distance = (x - dx).abs();
      if (distance > hitDistance) return;
      hitDistance = distance;
      hitLine = lineIndex;
    });
    return hitLine;
  }

  void _onTapUp(TapUpDetails details) {
    final dx = details.localPosition.dx;
    final hitLine = _hitMarker(dx);
    if (hitLine != null) {
      _state._select(hitLine);
      return;
    }
    final positionMS = _windowStartMS() + (dx * _msPerPx()).round();
    _state._seekTo(positionMS);
  }

  void _onDragStart(DragStartDetails details) {
    final hitLine = _hitMarker(details.localPosition.dx);
    _draggedLine = hitLine;
    if (hitLine == null) return;
    _dragStartMS = _state._doc.lines[hitLine].startMS ?? 0;
    _dragDistancePx = 0.0;
    _state._selectedIndex.value = hitLine;
    _state._pushUndo();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final msPerPx = _msPerPx();
    final draggedLine = _draggedLine;
    if (draggedLine != null) {
      _dragDistancePx += details.delta.dx;
      final newStartMS = _dragStartMS + (_dragDistancePx * msPerPx).round();
      _state._moveLineTo(draggedLine, newStartMS, saveUndo: false);
      return;
    }
    _scrubOffsetMS.value -= (details.delta.dx * msPerPx).round();
  }

  void _onDragEnd([DragEndDetails? _]) async {
    final draggedLine = _draggedLine;
    if (draggedLine != null) {
      _draggedLine = null;
      _state._placeLineInTimeOrder(draggedLine);
      return;
    }
    final offsetMS = _scrubOffsetMS.value;
    if (offsetMS == 0) return;
    final targetMS = _state._positionMS.value + offsetMS;
    await _state._seekTo(targetMS);
    if (mounted) _scrubOffsetMS.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colorScheme = theme.colorScheme;
    final accentColor = colorScheme.secondary;
    final onSurface = colorScheme.onSurface;
    final labelStyle = theme.textTheme.displaySmall?.copyWith(fontSize: 10.0, fontWeight: FontWeight.w600);
    return SizedBox(
      height: _kHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _width = constraints.maxWidth.withMinimum(1.0);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: _onTapUp,
            onHorizontalDragStart: _onDragStart,
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: _onDragEnd,
            onHorizontalDragCancel: _onDragEnd,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10.0.multipliedRadius),
              child: ColoredBox(
                color: theme.scaffoldBackgroundColor.withOpacityExt(0.5),
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: Size(_width, _kHeight),
                    painter: _TimelinePainter(
                      state: _state,
                      scrubOffsetMS: _scrubOffsetMS,
                      labelsCache: _labelsCache,
                      labelStyle: labelStyle,
                      barColor: onSurface.withOpacityExt(0.22),
                      playedBarColor: accentColor.withOpacityExt(0.55),
                      markerColor: onSurface.withOpacityExt(0.35),
                      selectedMarkerColor: accentColor,
                      wordColor: accentColor.withOpacityExt(0.35),
                      vocalsColor: accentColor.withOpacityExt(0.5),
                      playheadColor: onSurface,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  static const _kBarStepMS = 50;
  static const _kBarsCapacity = _EditorTimelineState._kWindowMS ~/ _kBarStepMS + 2;

  /// bars are vertical round-capped segments, x1 y1 x2 y2 each, so all of one color go in a single draw call.
  final _playedBarPoints = Float32List(_kBarsCapacity * 4);
  final _upcomingBarPoints = Float32List(_kBarsCapacity * 4);
  final _barPaint = Paint()..strokeCap = StrokeCap.round;

  /// ~1.2kHz to ~3.6kHz of the 40Hz-16kHz log spaced bands (namida_spectrum.c), the presence range voices stand out in.
  static const _kVocalBandsFrom = 9;
  static const _kVocalBandsTo = 12;
  static const _kVocalsLaneHeight = 10.0;
  static const _kVocalsRiseScale = 4.0;
  static const _kVocalsFrameMS = 1000 / SpectrumController.framesPerSecond;
  static const _kVocalsCapacity = _EditorTimelineState._kWindowMS ~/ _kVocalsFrameMS + 2;
  final _vocalsPoints = Float32List(_kVocalsCapacity * 4);
  final _vocalsPaint = Paint();

  final _LyricsEditorPageState state;
  final RxBaseCore<int> scrubOffsetMS;
  final Map<int, TextPainter> labelsCache;
  final TextStyle? labelStyle;
  final Color barColor;
  final Color playedBarColor;
  final Color markerColor;
  final Color selectedMarkerColor;
  final Color wordColor;
  final Color vocalsColor;
  final Color playheadColor;

  _TimelinePainter({
    required this.state,
    required this.scrubOffsetMS,
    required this.labelsCache,
    required this.labelStyle,
    required this.barColor,
    required this.playedBarColor,
    required this.markerColor,
    required this.selectedMarkerColor,
    required this.wordColor,
    required this.vocalsColor,
    required this.playheadColor,
  }) : super(repaint: Listenable.merge([state._positionMS, state._revision, state._selectedIndex, scrubOffsetMS]));

  TextPainter _getLabel(int number, bool isSelected) {
    final key = number * 2 + (isSelected ? 1 : 0);
    return labelsCache[key] ??= TextPainter(
      text: TextSpan(
        text: '$number',
        style: labelStyle?.copyWith(color: isSelected ? selectedMarkerColor : markerColor),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final positionMS = state._positionMS.value + scrubOffsetMS.value;
    const windowMS = _EditorTimelineState._kWindowMS;
    final windowStartMS = positionMS - (windowMS * _EditorTimelineState._kPlayheadFraction).round();
    final windowEndMS = windowStartMS + windowMS;
    final pxPerMS = width / windowMS;
    final paint = Paint();

    final vocalsLaneTop = height - _kVocalsLaneHeight;
    if (state._isCurrentItem.value) {
      final waveform = WaveformController.inst;
      final spectrum = SpectrumController.inst;
      final hasSpectrum = spectrum.hasSpectrum;
      final centerY = height * 0.52;
      final maxBarHeight = height * 0.52;
      final barWidth = _kBarStepMS * pxPerMS * 0.6;
      final capLength = barWidth / 2;
      final firstBarMS = (windowStartMS - windowStartMS % _kBarStepMS).withMinimum(0);
      final playedPoints = _playedBarPoints;
      final upcomingPoints = _upcomingBarPoints;
      var playedLength = 0;
      var upcomingLength = 0;
      for (var ms = firstBarMS; ms <= windowEndMS; ms += _kBarStepMS) {
        final level = waveform.getCurrentLevel(ms.toDouble());
        final halfLength = (level * maxBarHeight / 2 - capLength).withMinimum(0.5);
        final x = (ms - windowStartMS) * pxPerMS;
        final top = centerY - halfLength;
        final bottom = centerY + halfLength;
        if (ms <= positionMS) {
          playedPoints[playedLength++] = x;
          playedPoints[playedLength++] = top;
          playedPoints[playedLength++] = x;
          playedPoints[playedLength++] = bottom;
        } else {
          upcomingPoints[upcomingLength++] = x;
          upcomingPoints[upcomingLength++] = top;
          upcomingPoints[upcomingLength++] = x;
          upcomingPoints[upcomingLength++] = bottom;
        }
      }
      final playedView = Float32List.sublistView(playedPoints, 0, playedLength);
      final upcomingView = Float32List.sublistView(upcomingPoints, 0, upcomingLength);
      final barPaint = _barPaint..strokeWidth = barWidth;
      barPaint.color = playedBarColor;
      canvas.drawRawPoints(ui.PointMode.lines, playedView, barPaint);
      barPaint.color = barColor;
      canvas.drawRawPoints(ui.PointMode.lines, upcomingView, barPaint);
      if (hasSpectrum) _paintVocalsRises(canvas, spectrum, windowStartMS, windowEndMS, pxPerMS, height);
    }

    final lines = state._doc.lines;
    final selectedIndex = state._selectedIndex.value;
    final selectedWords = selectedIndex < lines.length ? lines[selectedIndex].words : null;
    if (selectedWords != null) {
      paint.color = wordColor;
      final wordTop = vocalsLaneTop - 7.0;
      for (final w in selectedWords) {
        final startMS = w.startMS;
        if (startMS == null) continue;
        final endMS = w.endMS ?? startMS;
        if (endMS < windowStartMS || startMS > windowEndMS) continue;
        final left = (startMS - windowStartMS) * pxPerMS;
        final right = (endMS - windowStartMS) * pxPerMS;
        final rect = Rect.fromLTRB(left, wordTop, right.withMinimum(left + 2.0), wordTop + 5.0);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2.0)), paint);
      }
    }

    // -- labels sit right of their marker, so lines a bit before the window can still show theirs
    state._doc.forEachTimedInRange(windowStartMS - 1000, windowEndMS, (lineIndex, startMS) {
      final x = (startMS - windowStartMS) * pxPerMS;
      final isSelected = lineIndex == selectedIndex;
      paint.color = isSelected ? selectedMarkerColor : markerColor;
      final markerWidth = isSelected ? 2.5 : 1.5;
      canvas.drawRect(Rect.fromLTWH(x - markerWidth / 2, 0.0, markerWidth, height), paint);
      final label = _getLabel(lineIndex + 1, isSelected);
      label.paint(canvas, Offset(x + 3.0, 2.0));
    });

    final playheadX = (positionMS - windowStartMS) * pxPerMS;
    paint.color = playheadColor;
    canvas.drawRect(Rect.fromLTWH(playheadX - 1.0, 0.0, 2.0, height), paint);
  }

  /// how much the presence range rose since the frame before, new syllables show as spikes while held notes stay flat.
  void _paintVocalsRises(Canvas canvas, SpectrumController spectrum, int windowStartMS, int windowEndMS, double pxPerMS, double height) {
    const frameMS = _kVocalsFrameMS;
    final points = _vocalsPoints;
    var length = 0;
    final firstFrame = (windowStartMS / frameMS).ceil().withMinimum(1);
    final lastFrame = windowEndMS ~/ frameMS;
    var previousLevel = spectrum.averageBands((firstFrame - 1) * frameMS, _kVocalBandsFrom, _kVocalBandsTo);
    for (int frame = firstFrame; frame <= lastFrame; frame++) {
      final frameStartMS = frame * frameMS;
      final level = spectrum.averageBands(frameStartMS, _kVocalBandsFrom, _kVocalBandsTo);
      final rise = level - previousLevel;
      previousLevel = level;
      if (rise <= 0.0) continue;
      final x = (frameStartMS - windowStartMS) * pxPerMS;
      final riseHeight = (rise * _kVocalsRiseScale).withMaximum(1.0) * _kVocalsLaneHeight;
      points[length++] = x;
      points[length++] = height;
      points[length++] = x;
      points[length++] = height - riseHeight;
    }
    final view = Float32List.sublistView(points, 0, length);
    final paint = _vocalsPaint
      ..strokeWidth = frameMS * pxPerMS * 0.6
      ..color = vocalsColor;
    canvas.drawRawPoints(ui.PointMode.lines, view, paint);
  }

  @override
  bool shouldRepaint(_TimelinePainter oldDelegate) {
    return oldDelegate.barColor != barColor ||
        oldDelegate.playedBarColor != playedBarColor ||
        oldDelegate.markerColor != markerColor ||
        oldDelegate.selectedMarkerColor != selectedMarkerColor ||
        oldDelegate.vocalsColor != vocalsColor ||
        oldDelegate.playheadColor != playheadColor;
  }
}
