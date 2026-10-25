part of 'color_picker_dialog.dart';

/// claims the pointer on down, so a scrollable parent can't win vertical drags first.
class _ImmediateDragRecognizer extends OneSequenceGestureRecognizer {
  _ImmediateDragRecognizer({super.debugOwner});

  ValueChanged<Offset>? onUpdate;
  VoidCallback? onEnd;

  int? _activePointer;
  Offset _downPosition = Offset.zero;

  @override
  String get debugDescription => 'immediate drag';

  @override
  bool isPointerAllowed(PointerDownEvent event) {
    if (_activePointer != null) return false;
    final isSecondaryMouseButton = event.kind == PointerDeviceKind.mouse && event.buttons != kPrimaryMouseButton;
    if (isSecondaryMouseButton) return false;
    return super.isPointerAllowed(event);
  }

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _activePointer = event.pointer;
    _downPosition = event.localPosition;
    resolve(GestureDisposition.accepted);
  }

  @override
  void acceptGesture(int pointer) {
    if (pointer == _activePointer) onUpdate?.call(_downPosition);
  }

  @override
  void rejectGesture(int pointer) {
    stopTrackingPointer(pointer);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent && event.pointer == _activePointer) onUpdate?.call(event.localPosition);
    stopTrackingIfPointerNoLongerDown(event);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _activePointer = null;
    onEnd?.call();
  }
}

abstract class _PickerRenderBox extends RenderBox implements MouseTrackerAnnotation {
  _PickerRenderBox(_ColorPickerController controller) : _controller = controller;

  _ColorPickerController _controller;
  set controller(_ColorPickerController value) {
    if (identical(value, _controller)) return;
    if (attached) _controller.current.removeListener(onPickedColorChanged);
    _controller = value;
    if (attached) value.current.addListener(onPickedColorChanged);
    onPickedColorChanged();
  }

  void onPickedColorChanged() => markNeedsPaint();

  @override
  bool get isRepaintBoundary => true;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _controller.current.addListener(onPickedColorChanged);
  }

  @override
  void detach() {
    _controller.current.removeListener(onPickedColorChanged);
    super.detach();
  }

  @override
  MouseCursor get cursor => SystemMouseCursors.click;

  @override
  PointerEnterEventListener? get onEnter => null;

  @override
  PointerExitEventListener? get onExit => null;

  @override
  bool get validForMouseTracker => attached;
}

class _SaturationValuePlane extends LeafRenderObjectWidget {
  final _ColorPickerController controller;

  const _SaturationValuePlane({required this.controller});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSaturationValuePlane(controller);

  @override
  void updateRenderObject(BuildContext context, _RenderSaturationValuePlane renderObject) {
    renderObject.controller = controller;
  }
}

class _RenderSaturationValuePlane extends _PickerRenderBox {
  _RenderSaturationValuePlane(super.controller);

  static const _kThumbRadius = 10.0;

  late final _radius = Radius.circular(12.0.multipliedRadius);

  late final _drag = _ImmediateDragRecognizer(debugOwner: this)
    ..onUpdate = _onDragUpdate
    ..onEnd = _onDragEnd;

  final _planePaint = Paint();
  ui.Image? _cornersImage;
  ImageShader? _planeShader;
  double? _shaderHue;
  Rect? _shaderRect;

  @override
  void dispose() {
    _drag.dispose();
    _planeShader?.dispose();
    _cornersImage?.dispose();
    super.dispose();
  }

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is PointerDownEvent) _drag.addPointer(event);
  }

  void _onDragEnd() => _controller.settle();

  void _onDragUpdate(Offset position) {
    final saturation = (position.dx / size.width).clampDouble(0.0, 1.0);
    final value = 1.0 - (position.dy / size.height).clampDouble(0.0, 1.0);
    final hsv = _controller.hsv.withSaturation(saturation).withValue(value);
    _controller.setHsv(hsv);
  }

  /// the plane is bilinear between its corners, so a stretched 2x2 image draws it in one pass. stacked gradients bled at the rounded edges.
  void _updatePlaneShader(double hue, Rect rect) {
    final isSameHue = hue == _shaderHue;
    if (isSameHue && rect == _shaderRect) return;
    var cornersImage = _cornersImage;
    if (cornersImage == null || !isSameHue) {
      cornersImage?.dispose();
      cornersImage = _ColorPainting.buildPlaneCornersImage(hue);
      _cornersImage = cornersImage;
      _shaderHue = hue;
    }
    _shaderRect = rect;
    final matrix = Matrix4.diagonal3Values(rect.width, rect.height, 1.0)..setTranslationRaw(rect.left - rect.width / 2.0, rect.top - rect.height / 2.0, 0.0);
    final shader = ImageShader(cornersImage, TileMode.clamp, TileMode.clamp, matrix.storage, filterQuality: FilterQuality.low);
    _planeShader?.dispose();
    _planeShader = shader;
    _planePaint.shader = shader;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final rect = offset & size;
    final hsv = _controller.hsv;
    _updatePlaneShader(hsv.hue, rect);
    final rrect = RRect.fromRectAndRadius(rect, _radius);
    canvas.drawRRect(rrect, _planePaint);
    final thumbCenter = Offset(rect.left + hsv.saturation * rect.width, rect.top + (1.0 - hsv.value) * rect.height);
    final thumbColor = hsv.withAlpha(1.0).toColor();
    _ColorPainting.paintThumb(canvas, thumbCenter, _kThumbRadius, thumbColor);
  }
}

class _ColorSlider extends LeafRenderObjectWidget {
  final _ColorPickerController controller;
  final _ColorSliderKind kind;

  const _ColorSlider({
    required this.controller,
    required this.kind,
  });

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderColorSlider(controller, kind: kind);

  @override
  void updateRenderObject(BuildContext context, _RenderColorSlider renderObject) {
    renderObject
      ..controller = controller
      ..kind = kind;
  }
}

class _RenderColorSlider extends _PickerRenderBox {
  _RenderColorSlider(super.controller, {required this._kind});

  static const kHeight = 28.0;
  static const _kTrackHeight = 12.0;
  static const _kThumbRadius = 11.0;
  static const _kWheelDeltaPerFraction = 2500.0;
  static const _kHueColors = [
    Color(0xFFFF0000), Color(0xFFFFFF00), Color(0xFF00FF00), Color(0xFF00FFFF), //
    Color(0xFF0000FF), Color(0xFFFF00FF), Color(0xFFFF0000), //
  ];

  _ColorSliderKind _kind;
  set kind(_ColorSliderKind value) {
    if (value == _kind) return;
    _kind = value;
    _hueShaderRect = null;
    markNeedsPaint();
  }

  late final _drag = _ImmediateDragRecognizer(debugOwner: this)
    ..onUpdate = _onDragUpdate
    ..onEnd = _onDragEnd;

  final _trackPaint = Paint();
  Rect? _hueShaderRect;

  static Rect _thumbCenterRangeOf(Rect rect) => Rect.fromLTRB(rect.left + _kThumbRadius, rect.top, rect.right - _kThumbRadius, rect.bottom);

  @override
  void dispose() {
    _drag.dispose();
    super.dispose();
  }

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is PointerDownEvent) {
      _drag.addPointer(event);
    } else if (event is PointerScrollEvent) {
      GestureBinding.instance.pointerSignalResolver.register(event, _onPointerScroll);
    }
  }

  double _readFraction() {
    final hsv = _controller.hsv;
    return switch (_kind) {
      _ColorSliderKind.hue => hsv.hue / 360.0,
      _ColorSliderKind.alpha => hsv.alpha,
    };
  }

  void _applyFraction(double fractionPre) {
    final fraction = fractionPre.clampDouble(0.0, 1.0);
    final hsv = _controller.hsv;
    final newHsv = switch (_kind) {
      _ColorSliderKind.hue => hsv.withHue(fraction * 360.0),
      _ColorSliderKind.alpha => hsv.withAlpha(fraction),
    };
    _controller.setHsv(newHsv);
  }

  void _onDragEnd() => _controller.settle();

  void _onDragUpdate(Offset position) {
    final thumbRange = _thumbCenterRangeOf(Offset.zero & size);
    final fraction = (position.dx - thumbRange.left) / thumbRange.width;
    _applyFraction(fraction);
  }

  void _onPointerScroll(PointerSignalEvent event) {
    final scrollDelta = (event as PointerScrollEvent).scrollDelta.dy;
    final fractionDelta = -scrollDelta / _kWheelDeltaPerFraction;
    _applyFraction(_readFraction() + fractionDelta);
    _controller.settleSoon();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final rect = offset & size;
    final centerY = rect.center.dy;
    final trackRect = Rect.fromLTRB(rect.left, centerY - _kTrackHeight / 2.0, rect.right, centerY + _kTrackHeight / 2.0);
    final trackRRect = RRect.fromRectAndRadius(trackRect, const Radius.circular(_kTrackHeight / 2.0));
    final thumbRange = _thumbCenterRangeOf(trackRect);
    final hsv = _controller.hsv;
    final Color thumbColor;
    switch (_kind) {
      case _ColorSliderKind.hue:
        if (thumbRange != _hueShaderRect) {
          _hueShaderRect = thumbRange;
          _trackPaint.shader = const LinearGradient(colors: _kHueColors).createShader(thumbRange);
        }
        canvas.drawRRect(trackRRect, _trackPaint);
        thumbColor = HSVColor.fromAHSV(1.0, hsv.hue, 1.0, 1.0).toColor();
      case _ColorSliderKind.alpha:
        final opaqueColor = hsv.withAlpha(1.0).toColor();
        final transparentColor = opaqueColor.withOpacityExt(0.0);
        _trackPaint.shader = LinearGradient(colors: [transparentColor, opaqueColor]).createShader(thumbRange);
        _ColorPainting.paintChecker(canvas, trackRRect.deflate(_ColorPainting.kCheckerInset));
        canvas.drawRRect(trackRRect, _trackPaint);
        thumbColor = _controller.color;
    }
    final thumbCenter = Offset(thumbRange.left + _readFraction() * thumbRange.width, centerY);
    _ColorPainting.paintThumb(canvas, thumbCenter, _kThumbRadius, thumbColor);
  }
}

class _ColorPreview extends LeafRenderObjectWidget {
  final _ColorPickerController controller;
  final bool isInitial;
  final BorderRadius borderRadius;

  const _ColorPreview({
    required this.controller,
    required this.isInitial,
    required this.borderRadius,
  });

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderColorPreview(controller, isInitial: isInitial, borderRadius: borderRadius);

  @override
  void updateRenderObject(BuildContext context, _RenderColorPreview renderObject) {
    renderObject
      ..controller = controller
      ..isInitial = isInitial
      ..borderRadius = borderRadius;
  }
}

class _RenderColorPreview extends _PickerRenderBox {
  _RenderColorPreview(super.controller, {required this._isInitial, required this._borderRadius});

  bool _isInitial;
  set isInitial(bool value) {
    if (value == _isInitial) return;
    _isInitial = value;
    markNeedsPaint();
  }

  BorderRadius _borderRadius;
  set borderRadius(BorderRadius value) {
    if (value == _borderRadius) return;
    _borderRadius = value;
    markNeedsPaint();
  }

  @override
  void onPickedColorChanged() {
    if (!_isInitial) markNeedsPaint();
  }

  @override
  bool hitTestSelf(Offset position) => _isInitial;

  @override
  void paint(PaintingContext context, Offset offset) {
    final color = _isInitial ? _controller.initialColor : _controller.color;
    final rrect = _borderRadius.toRRect(offset & size);
    _ColorPainting.paintFill(context.canvas, rrect, color);
  }
}

class _SwatchGrid extends LeafRenderObjectWidget {
  final _ColorPickerController controller;
  final List<Color> colors;
  final int? maxRows;

  /// the selection compares without alpha too.
  final bool shouldKeepAlpha;
  final _SwatchGridColors gridColors;

  const _SwatchGrid({
    required this.controller,
    required this.colors,
    required this.maxRows,
    required this.shouldKeepAlpha,
    required this.gridColors,
  });

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSwatchGrid(
    controller,
    colors: colors,
    maxRows: maxRows,
    shouldKeepAlpha: shouldKeepAlpha,
    gridColors: gridColors,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderSwatchGrid renderObject) {
    renderObject
      ..controller = controller
      ..colors = colors
      ..maxRows = maxRows
      ..shouldKeepAlpha = shouldKeepAlpha
      ..gridColors = gridColors;
  }
}

class _RenderSwatchGrid extends _PickerRenderBox {
  _RenderSwatchGrid(
    super.controller, {
    required List<Color> colors,
    required this._maxRows,
    required this._shouldKeepAlpha,
    required _SwatchGridColors gridColors,
  }) : _colors = colors,
       _colorValues = _valuesOf(colors),
       _gridColors = gridColors,
       _backgroundValue = gridColors.background.intValue;

  static const kMinSwatchExtent = 26.0;
  static const _kGap = 6.0;
  static const _kRgbMask = 0x00FFFFFF;
  static const _kArgbMask = 0xFFFFFFFF;
  static const _kOutlineMaxChannelDistance = 28;
  static const _kSelectionRingWidth = 2.0;
  static const _kSelectedFillInset = 4.0;

  static int columnsFor(double width) => ((width + _kGap) / (kMinSwatchExtent + _kGap)).floor().withMinimum(1);

  static List<int> _valuesOf(List<Color> colors) => colors.map((c) => c.intValue).toFixedList();

  static int _channelDistanceOf(int argbA, int argbB) {
    final redDistance = (((argbA >> 16) & 0xFF) - ((argbB >> 16) & 0xFF)).abs();
    final greenDistance = (((argbA >> 8) & 0xFF) - ((argbB >> 8) & 0xFF)).abs();
    final blueDistance = ((argbA & 0xFF) - (argbB & 0xFF)).abs();
    return math.max(redDistance, math.max(greenDistance, blueDistance));
  }

  List<Color> _colors;
  List<int> _colorValues;
  set colors(List<Color> value) {
    if (identical(value, _colors)) return;
    _colors = value;
    _colorValues = _valuesOf(value);
    _selectedIndex = _findSelectedIndex();
    markNeedsLayout();
  }

  int? _maxRows;
  set maxRows(int? value) {
    if (value == _maxRows) return;
    _maxRows = value;
    markNeedsLayout();
  }

  bool _shouldKeepAlpha;
  set shouldKeepAlpha(bool value) {
    if (value == _shouldKeepAlpha) return;
    _shouldKeepAlpha = value;
    _selectedIndex = _findSelectedIndex();
    markNeedsPaint();
  }

  _SwatchGridColors _gridColors;
  int _backgroundValue;
  set gridColors(_SwatchGridColors value) {
    if (value == _gridColors) return;
    _gridColors = value;
    _backgroundValue = value.background.intValue;
    markNeedsPaint();
  }

  late final _tap = TapGestureRecognizer(debugOwner: this)..onTapUp = _onTapUp;

  _SwatchGridMetrics _metrics = (columns: 1, swatchExtent: 0.0, visibleCount: 0, size: Size.zero);
  late int _selectedIndex = _findSelectedIndex();

  @override
  void dispose() {
    _tap.dispose();
    super.dispose();
  }

  int _findSelectedIndex() {
    final mask = _shouldKeepAlpha ? _kRgbMask : _kArgbMask;
    final pickedValue = _controller.color.intValue & mask;
    for (int i = 0; i < _colorValues.length; i++) {
      if ((_colorValues[i] & mask) == pickedValue) return i;
    }
    return -1;
  }

  @override
  void onPickedColorChanged() {
    final selectedIndex = _findSelectedIndex();
    if (selectedIndex == _selectedIndex) return;
    _selectedIndex = selectedIndex;
    markNeedsPaint();
  }

  _SwatchGridMetrics _measure(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final columns = columnsFor(width);
    final swatchExtent = (width - (columns - 1) * _kGap) / columns;
    final maxRows = _maxRows;
    final colorsCount = _colors.length;
    final maxCount = maxRows == null ? colorsCount : columns * maxRows;
    final visibleCount = math.min(colorsCount, maxCount);
    final rows = (visibleCount / columns).ceil();
    final height = rows == 0 ? 0.0 : rows * swatchExtent + (rows - 1) * _kGap;
    final size = constraints.constrain(Size(width, height));
    return (columns: columns, swatchExtent: swatchExtent, visibleCount: visibleCount, size: size);
  }

  @override
  bool get sizedByParent => false;

  @override
  Size computeDryLayout(BoxConstraints constraints) => _measure(constraints).size;

  @override
  void performLayout() {
    final metrics = _measure(constraints);
    _metrics = metrics;
    size = metrics.size;
  }

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is PointerDownEvent) _tap.addPointer(event);
  }

  void _onTapUp(TapUpDetails details) {
    final index = _indexAt(details.localPosition);
    if (index == null) return;
    _controller.pickColor(_colors[index], shouldKeepAlpha: _shouldKeepAlpha);
  }

  int? _indexAt(Offset position) {
    final metrics = _metrics;
    final columns = metrics.columns;
    final cellExtent = metrics.swatchExtent + _kGap;
    final column = (position.dx / cellExtent).floor();
    final row = (position.dy / cellExtent).floor();
    if (column < 0 || column >= columns || row < 0) return null;
    final index = row * columns + column;
    if (index >= metrics.visibleCount) return null;
    return index;
  }

  bool _needsOutline(int index) {
    final colorValue = _colorValues[index];
    final isOpaque = (colorValue >>> 24) == 0xFF;
    if (!isOpaque) return true;
    return _channelDistanceOf(colorValue, _backgroundValue) < _kOutlineMaxChannelDistance;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final metrics = _metrics;
    final columns = metrics.columns;
    final extent = metrics.swatchExtent;
    final cellExtent = extent + _kGap;
    final radius = Radius.circular(extent * 0.3);
    final gridColors = _gridColors;
    for (int i = 0; i < metrics.visibleCount; i++) {
      final left = offset.dx + (i % columns) * cellExtent;
      final top = offset.dy + (i ~/ columns) * cellExtent;
      final rrect = RRect.fromLTRBR(left, top, left + extent, top + extent, radius);
      final color = _colors[i];
      final outlineColor = _needsOutline(i) ? gridColors.outline : null;
      if (i == _selectedIndex) {
        const ringInset = _kSelectionRingWidth / 2.0;
        _ColorPainting.paintRing(canvas, rrect.deflate(ringInset), gridColors.selection, _kSelectionRingWidth);
        _ColorPainting.paintSwatch(canvas, rrect.deflate(_kSelectedFillInset), color, outlineColor);
      } else {
        _ColorPainting.paintSwatch(canvas, rrect, color, outlineColor);
      }
    }
  }
}

abstract final class _ColorPainting {
  /// keeps the checker's antialiased rim hidden under the color's edge.
  static const kCheckerInset = 1.0;
  static const _kCheckerCellExtent = 4.0;
  static const _kThumbBorderWidth = 3.0;

  static final _fillPaint = Paint();
  static final _strokePaint = Paint()..style = PaintingStyle.stroke;
  static final _pixelPaint = Paint()..isAntiAlias = false;
  static Paint? _checkerPaint;

  static Paint _getCheckerPaint() => _checkerPaint ??= _buildCheckerPaint();

  /// a tiny tile image repeated by the gpu, instead of drawing every cell.
  static Paint _buildCheckerPaint() {
    const cell = _kCheckerCellExtent;
    const tileExtent = cell * 2.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final lightPaint = Paint()..color = const Color(0xFFFFFFFF);
    final darkPaint = Paint()..color = const Color(0xFFCFCFCF);
    canvas.drawRect(const Rect.fromLTWH(0.0, 0.0, tileExtent, tileExtent), lightPaint);
    canvas.drawRect(const Rect.fromLTWH(0.0, 0.0, cell, cell), darkPaint);
    canvas.drawRect(const Rect.fromLTWH(cell, cell, cell, cell), darkPaint);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(tileExtent.toInt(), tileExtent.toInt());
    picture.dispose();
    final shader = ImageShader(image, TileMode.repeated, TileMode.repeated, Matrix4.identity().storage, filterQuality: FilterQuality.none);
    return Paint()..shader = shader;
  }

  /// white, hue and black corners, black twice for the bottom edge.
  static ui.Image buildPlaneCornersImage(double hue) {
    final hueColor = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _pixelPaint.color = const Color(0xFFFFFFFF);
    canvas.drawRect(const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0), _pixelPaint);
    _pixelPaint.color = hueColor;
    canvas.drawRect(const Rect.fromLTWH(1.0, 0.0, 1.0, 1.0), _pixelPaint);
    _pixelPaint.color = const Color(0xFF000000);
    canvas.drawRect(const Rect.fromLTWH(0.0, 1.0, 2.0, 1.0), _pixelPaint);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(2, 2);
    picture.dispose();
    return image;
  }

  static void paintChecker(Canvas canvas, RRect rrect) {
    canvas.drawRRect(rrect, _getCheckerPaint());
  }

  static void paintFill(Canvas canvas, RRect rrect, Color color) {
    if (color.a < 1.0) paintChecker(canvas, rrect.deflate(kCheckerInset));
    _fillPaint.color = color;
    canvas.drawRRect(rrect, _fillPaint);
  }

  /// the outline goes under the fill, so the fill's edge blends into it instead of the background.
  static void paintSwatch(Canvas canvas, RRect rrect, Color color, Color? outlineColor) {
    if (outlineColor != null) {
      _fillPaint.color = outlineColor;
      canvas.drawRRect(rrect.inflate(1.0), _fillPaint);
    }
    paintFill(canvas, rrect, color);
  }

  static void paintRing(Canvas canvas, RRect rrect, Color color, double width) {
    _strokePaint
      ..color = color
      ..strokeWidth = width;
    canvas.drawRRect(rrect, _strokePaint);
  }

  static void paintThumb(Canvas canvas, Offset center, double radius, Color color) {
    _fillPaint.color = const Color(0x33000000);
    canvas.drawCircle(center, radius + 1.0, _fillPaint);
    _fillPaint.color = const Color(0xFFFFFFFF);
    canvas.drawCircle(center, radius, _fillPaint);
    final innerRadius = radius - _kThumbBorderWidth;
    if (color.a < 1.0) canvas.drawCircle(center, innerRadius - kCheckerInset, _getCheckerPaint());
    _fillPaint.color = color;
    canvas.drawCircle(center, innerRadius, _fillPaint);
  }
}

enum _ColorSliderKind {
  hue,
  alpha,
}

typedef _SwatchGridMetrics = ({int columns, double swatchExtent, int visibleCount, Size size});
typedef _SwatchGridColors = ({Color background, Color outline, Color selection});
