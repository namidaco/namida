import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// [SliverLayoutBuilder] rebuilds on every scroll frame since [SliverConstraints.scrollOffset] changes,
/// which rebuilds every visible child of a builder based grid. this one rebuilds only when the width changes.
///
/// by claude
class SliverCrossAxisExtentBuilder extends AbstractLayoutBuilder<double> {
  @override
  final Widget Function(BuildContext context, double crossAxisExtent) builder;

  const SliverCrossAxisExtentBuilder({
    super.key,
    required this.builder,
  });

  @override
  RenderAbstractLayoutBuilderMixin<double, RenderSliver> createRenderObject(BuildContext context) => _RenderSliverCrossAxisExtentBuilder();
}

class _RenderSliverCrossAxisExtentBuilder extends RenderSliver
    with RenderObjectWithChildMixin<RenderSliver>, RenderObjectWithLayoutCallbackMixin, RenderAbstractLayoutBuilderMixin<double, RenderSliver> {
  @override
  double get layoutInfo => constraints.crossAxisExtent;

  @override
  double childMainAxisPosition(RenderObject child) => 0;

  @override
  void performLayout() {
    runLayoutCallback();
    final child = this.child;
    if (child == null) {
      geometry = SliverGeometry.zero;
      return;
    }
    child.layout(constraints, parentUsesSize: true);
    geometry = child.geometry;
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {}

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child != null && child.geometry!.visible) context.paintChild(child, offset);
  }

  @override
  bool hitTestChildren(SliverHitTestResult result, {required double mainAxisPosition, required double crossAxisPosition}) {
    final child = this.child;
    return child != null &&
        child.geometry!.hitTestExtent > 0 &&
        child.hitTest(
          result,
          mainAxisPosition: mainAxisPosition,
          crossAxisPosition: crossAxisPosition,
        );
  }
}
