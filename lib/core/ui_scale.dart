// by claude
import 'dart:math' as math;
import 'dart:ui' as ui;

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = NamidaUIScale._resolve(constraints.biggest);
        if (scale == 1.0) return child;

        final inverse = 1 / scale;
        // -- [FittedBox] rather than [Transform] + [SizedBox], since the incoming
        // -- constraints are tight and would shrink the child back down.
        return FittedBox(
          fit: BoxFit.fill,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: constraints.maxWidth * inverse,
            height: constraints.maxHeight * inverse,
            child: MediaQuery(
              data: MediaQuery.of(context).scaledForUI(scale),
              child: child,
            ),
          ),
        );
      },
    );
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
