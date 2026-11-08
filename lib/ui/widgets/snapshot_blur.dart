// by claude
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// [ImageFiltered] blur that draws an image of its result once [child] stops changing, until anything inside repaints.
/// a parent transforming it every frame (the artwork bounce, a pulsing backdrop) then re-composites one image instead of re-running the blur.
/// content that can change without a repaint here (textures, repaint boundaries inside) always blurs live.
class NamidaSnapshotBlur extends StatelessWidget {
  final double blur;

  /// how far the blurred [child] paints past its box.
  final double overflow;

  final TileMode tileMode;

  /// snapshot at the size it shows on screen, aligned to screen pixels so a still frame draws it back 1:1.
  /// otherwise the snapshot keeps the child's own size, for blurs drawn small then stretched.
  final bool isPixelExact;

  final Widget child;

  const NamidaSnapshotBlur({
    super.key,
    required this.blur,
    this.overflow = 0.0,
    this.tileMode = TileMode.decal,
    this.isPixelExact = true,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return _SnapshotBlurBox(
      blur: blur,
      overflow: overflow,
      tileMode: tileMode,
      isPixelExact: isPixelExact,
      child: child,
    );
  }
}

class _SnapshotBlurBox extends SingleChildRenderObjectWidget {
  final double blur;
  final double overflow;
  final TileMode tileMode;
  final bool isPixelExact;

  const _SnapshotBlurBox({
    required this.blur,
    required this.overflow,
    required this.tileMode,
    required this.isPixelExact,
    required super.child,
  });

  @override
  _RenderSnapshotBlur createRenderObject(BuildContext context) {
    final viewPixelRatio = View.of(context).devicePixelRatio;
    return _RenderSnapshotBlur(blur, overflow, tileMode, isPixelExact, viewPixelRatio);
  }

  @override
  void updateRenderObject(BuildContext context, _RenderSnapshotBlur renderObject) {
    renderObject
      ..blur = blur
      ..overflow = overflow
      ..tileMode = tileMode
      ..isPixelExact = isPixelExact
      ..viewPixelRatio = View.of(context).devicePixelRatio;
  }
}

class _RenderSnapshotBlur extends RenderProxyBox {
  _RenderSnapshotBlur(this._blur, this._overflow, this._tileMode, this._isPixelExact, this._viewPixelRatio);

  static const _kStableDuration = Duration(milliseconds: 200);
  static final _snapshotPaint = Paint()..filterQuality = FilterQuality.low;

  final _filterLayer = LayerHandle<ImageFilterLayer>();
  ui.Image? _snapshot;
  Rect _snapshotRect = Rect.zero;
  Timer? _stableTimer;
  bool _isShowingNewSnapshot = false;

  double _blur;
  set blur(double value) {
    if (value == _blur) return;
    _blur = value;
    markNeedsPaint();
  }

  double _overflow;
  set overflow(double value) {
    if (value == _overflow) return;
    _overflow = value;
    markNeedsPaint();
  }

  TileMode _tileMode;
  set tileMode(TileMode value) {
    if (value == _tileMode) return;
    _tileMode = value;
    markNeedsPaint();
  }

  bool _isPixelExact;
  set isPixelExact(bool value) {
    if (value == _isPixelExact) return;
    _isPixelExact = value;
    markNeedsPaint();
  }

  double _viewPixelRatio;
  set viewPixelRatio(double value) {
    if (value == _viewPixelRatio) return;
    _viewPixelRatio = value;
    markNeedsPaint();
  }

  @override
  bool get isRepaintBoundary => true;

  // -- every repaint inside reaches the closest repaint boundary, which is this one
  @override
  void markNeedsPaint() {
    if (!_isShowingNewSnapshot) _dropSnapshot();
    super.markNeedsPaint();
  }

  @override
  void detach() {
    _dropSnapshot();
    super.detach();
  }

  @override
  void dispose() {
    _dropSnapshot();
    _filterLayer.layer = null;
    super.dispose();
  }

  void _dropSnapshot() {
    _stableTimer?.cancel();
    _stableTimer = null;
    _snapshot?.dispose();
    _snapshot = null;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final snapshot = _snapshot;
    if (snapshot != null) {
      _filterLayer.layer = null;
      final source = Rect.fromLTWH(0.0, 0.0, snapshot.width.toDouble(), snapshot.height.toDouble());
      final destination = _snapshotRect.shift(offset);
      context.canvas.drawImageRect(snapshot, source, destination, _snapshotPaint);
      return;
    }
    final blur = _blur;
    if (blur <= 0.0) {
      _filterLayer.layer = null;
      super.paint(context, offset);
      return;
    }
    final filterLayer = _filterLayer.layer ??= ImageFilterLayer();
    filterLayer.imageFilter = ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur, tileMode: _tileMode);
    context.pushLayer(filterLayer, super.paint, offset);
    _stableTimer?.cancel();
    _stableTimer = Timer(_kStableDuration, _takeSnapshot);
  }

  void _takeSnapshot() {
    _stableTimer = null;
    final layer = this.layer;
    if (!attached || layer is! OffsetLayer || _hasLiveOnlyContent()) return;
    final paintRect = (Offset.zero & size).inflate(_overflow);
    double pixelRatio = _viewPixelRatio;
    Rect rect = paintRect;
    if (_isPixelExact) {
      final toView = getTransformTo(null);
      pixelRatio = _viewPixelRatio * toView.getMaxScaleOnAxis();
      // -- starts on a whole screen pixel, so a still frame draws it back 1:1 instead of resampling
      final screenOrigin = MatrixUtils.transformPoint(toView, paintRect.topLeft) * _viewPixelRatio;
      final shiftX = (screenOrigin.dx - screenOrigin.dx.floorToDouble()) / pixelRatio;
      final shiftY = (screenOrigin.dy - screenOrigin.dy.floorToDouble()) / pixelRatio;
      rect = Rect.fromLTRB(paintRect.left - shiftX, paintRect.top - shiftY, paintRect.right, paintRect.bottom);
    }
    final snapshot = layer.toImageSync(rect, pixelRatio: pixelRatio);
    _snapshot = snapshot;
    _snapshotRect = Rect.fromLTWH(rect.left, rect.top, snapshot.width / pixelRatio, snapshot.height / pixelRatio);
    _isShowingNewSnapshot = true;
    markNeedsPaint();
    _isShowingNewSnapshot = false;
  }

  bool _hasLiveOnlyContent() {
    var hasLiveOnly = false;
    void visit(RenderObject child) {
      if (hasLiveOnly) return;
      if (child.isRepaintBoundary || child is TextureBox || child is PlatformViewRenderBox) {
        hasLiveOnly = true;
        return;
      }
      child.visitChildren(visit);
    }

    visitChildren(visit);
    return hasLiveOnly;
  }
}
