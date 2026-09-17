// by claude
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:namida/core/utils.dart';

/// A global DPI override.
///
/// Every dimension in the app is an absolute logical value, and logical pixels are
/// density-independent but not size-independent, so small screens end up with
/// oversized items. Scaling down the whole app hands the layout more logical
/// pixels to work with, without touching any widget.
///
/// This is applied as a root scaling box rather than by overriding
/// `RendererBinding.createViewConfigurationFor`, because pointer events are
/// converted to logical pixels using the raw [ui.FlutterView.devicePixelRatio],
/// so a view configuration override would desync input from layout.
abstract class NamidaUIScale {
  /// shortest side (in logical pixels) at and above which nothing is scaled.
  static const _referenceShortestSide = 400.0;
  static const _minimum = 0.70;

  static double get value => _value;
  static double _value = 1.0;

  /// [Listener] callbacks and [DragUpdateDetails.globalPosition] carry raw root
  /// coordinates, unlike [PointerEvent.localDelta]/[DragUpdateDetails.delta] which
  /// are already corrected by the hit-test transform. Use this to bring them into
  /// the space the ui is laid out in.
  static double fromRoot(double value) => _value == 1.0 ? value : value / _value;
  static Offset fromRootOffset(Offset value) => _value == 1.0 ? value : value / _value;

  static double _resolve(Size size) {
    final shortestSide = size.shortestSide;
    // -- sqrt so the ramp stays gentle around the reference and only bites near the floor.
    final scale = shortestSide > 0 ? math.sqrt(shortestSide / _referenceShortestSide).clamp(_minimum, 1.0).toDouble() : 1.0;
    _value = scale;
    namida.viewScale = scale;
    return scale;
  }
}

class NamidaUIScaleWrapper extends StatelessWidget {
  final Widget child;
  const NamidaUIScaleWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // -- at the root the incoming constraints are the view size, same as the media query.
    final mediaQuery = MediaQuery.of(context);
    final scale = NamidaUIScale._resolve(mediaQuery.size);
    // -- the tree shape must never depend on [scale], switching it would remount the whole app.
    return _NamidaScaleBox(
      scale: scale,
      roundVirtualSize: false,
      child: MediaQuery(
        data: mediaQuery.scaledForUI(scale),
        child: child,
      ),
    );
  }
}

/// Lays its child out in a bigger virtual box then scales it down to fit, for subtrees
/// whose absolute sizes would otherwise feel cramped in a narrow area.
///
/// Also hands the subtree a [MediaQuery] sized to the box, which panels otherwise lack,
/// they inherit the whole screen's size through the layout padding.
class NamidaUiScaleBox extends StatelessWidget {
  final double scale;
  final Widget child;

  const NamidaUiScaleBox({super.key, required this.scale, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaQuery = MediaQuery.of(context);
        return _NamidaScaleBox(
          scale: scale,
          roundVirtualSize: true,
          child: MediaQuery(
            data: scale == 1.0 ? mediaQuery : mediaQuery.scaledForUI(scale).copyWith(size: _NamidaScaleBox.virtualSizeFor(constraints.biggest, scale, true)),
            child: child,
          ),
        );
      },
    );
  }
}

class _NamidaScaleBox extends SingleChildRenderObjectWidget {
  final double scale;
  final bool roundVirtualSize;

  const _NamidaScaleBox({required this.scale, required this.roundVirtualSize, required Widget super.child});

  static Size virtualSizeFor(Size size, double scale, bool round) {
    final inverse = 1 / scale;
    // -- whole pixels, fractional virtual sizes leave sub pixel overflows behind.
    return round ? Size((size.width * inverse).ceilToDouble(), (size.height * inverse).ceilToDouble()) : size * inverse;
  }

  @override
  _RenderNamidaScaleBox createRenderObject(BuildContext context) => _RenderNamidaScaleBox(scale, roundVirtualSize);

  @override
  void updateRenderObject(BuildContext context, _RenderNamidaScaleBox renderObject) {
    renderObject
      ..scale = scale
      ..roundVirtualSize = roundVirtualSize;
  }
}

/// A pass-through at 1.0, otherwise lays the child out in the virtual box and stretches it to fill.
class _RenderNamidaScaleBox extends RenderProxyBox {
  _RenderNamidaScaleBox(this._scale, this._roundVirtualSize);

  double _scale;
  set scale(double value) {
    if (_scale == value) return;
    _scale = value;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  bool _roundVirtualSize;
  set roundVirtualSize(bool value) {
    if (_roundVirtualSize == value) return;
    _roundVirtualSize = value;
    markNeedsLayout();
  }

  final _transform = Matrix4.identity();
  final _inverseTransform = Matrix4.identity();

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    if (_scale == 1.0) return super.computeDryLayout(constraints);
    return constraints.biggest;
  }

  @override
  void performLayout() {
    final child = this.child!;
    if (_scale == 1.0) {
      child.layout(constraints, parentUsesSize: true);
      size = child.size;
      return;
    }
    final biggest = constraints.biggest;
    final virtualSize = _NamidaScaleBox.virtualSizeFor(biggest, _scale, _roundVirtualSize);
    child.layout(BoxConstraints.tight(virtualSize));
    size = biggest;

    final sx = virtualSize.width > 0 ? biggest.width / virtualSize.width : _scale;
    final sy = virtualSize.height > 0 ? biggest.height / virtualSize.height : _scale;
    _transform
      ..setEntry(0, 0, sx)
      ..setEntry(1, 1, sy);
    _inverseTransform
      ..setEntry(0, 0, 1 / sx)
      ..setEntry(1, 1, 1 / sy);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_scale == 1.0) {
      layer = null;
      context.paintChild(child!, offset);
      return;
    }
    layer = context.pushTransform(needsCompositing, offset, _transform, super.paint, oldLayer: layer as TransformLayer?);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child!;
    if (_scale == 1.0) return child.hitTest(result, position: position);
    return result.addWithRawTransform(
      transform: _inverseTransform,
      position: position,
      hitTest: (result, position) => child.hitTest(result, position: position),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    if (_scale != 1.0) transform.multiply(_transform);
  }
}

extension NamidaMediaQueryUIScale on MediaQueryData {
  MediaQueryData scaledForUI(double scale) {
    if (scale == 1.0) return this;
    final inverse = 1 / scale;
    return copyWith(
      size: size * inverse,
      devicePixelRatio: devicePixelRatio * scale,
      padding: padding * inverse,
      viewPadding: viewPadding * inverse,
      viewInsets: viewInsets * inverse,
      systemGestureInsets: systemGestureInsets * inverse,
      displayFeatures: displayFeatures.isEmpty
          ? null
          : displayFeatures
                .map(
                  (e) => ui.DisplayFeature(
                    bounds: Rect.fromLTRB(e.bounds.left * inverse, e.bounds.top * inverse, e.bounds.right * inverse, e.bounds.bottom * inverse),
                    type: e.type,
                    state: e.state,
                  ),
                )
                .toList(),
    );
  }
}

extension FlutterViewUtils on ui.FlutterView {
  double get devicePixelRatioWithScale => this.devicePixelRatio * NamidaUIScale.value;
}
