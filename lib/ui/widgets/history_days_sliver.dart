// rewritten by claude, old per-day StickyHeader with a nested list built all tiles of a day at once (lag on big days) and summed every day's extent each layout.
// new one is a single lazy list (only visible tiles built, binary search over per-day counts) with one pinned header pushed by the next day.

import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:namida/core/extensions.dart';

class HistoryDaysSliver extends StatelessWidget {
  final int daysCount;
  final int Function(int dayIndex) dayItemsCount;
  final double itemExtent;
  final double headerExtent;
  final double itemsTopPadding;
  final double itemsBottomPadding;
  final Widget Function(BuildContext context, int dayIndex) headerBuilder;
  final Widget Function(BuildContext context, int dayIndex, int itemIndex) itemBuilder;

  const HistoryDaysSliver({
    super.key,
    required this.daysCount,
    required this.dayItemsCount,
    required this.itemExtent,
    required this.headerExtent,
    required this.itemsTopPadding,
    required this.itemsBottomPadding,
    required this.headerBuilder,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final daysLayout = _HistoryDaysLayout.compute(
      daysCount: daysCount,
      dayItemsCount: dayItemsCount,
      itemExtent: itemExtent,
      headerExtent: headerExtent,
      itemsTopPadding: itemsTopPadding,
      itemsBottomPadding: itemsBottomPadding,
    );
    final delegate = SliverChildBuilderDelegate(
      (context, childIndex) {
        final dayIndex = daysLayout.dayOfChild(childIndex);
        final itemIndex = childIndex - daysLayout.headerChildOf(dayIndex) - 1;
        if (itemIndex < 0) return headerBuilder(context, dayIndex);
        return itemBuilder(context, dayIndex, itemIndex);
      },
      childCount: daysLayout.childCount,
    );
    return _PinnedDayHeaderSliver(
      daysLayout: daysLayout,
      headerBuilder: headerBuilder,
      list: _HistoryDaysList(
        daysLayout: daysLayout,
        delegate: delegate,
      ),
    );
  }
}

class _PinnedDayHeaderSliver extends RenderObjectWidget {
  final _HistoryDaysLayout daysLayout;
  final Widget Function(BuildContext context, int dayIndex) headerBuilder;
  final Widget list;

  const _PinnedDayHeaderSliver({
    required this.daysLayout,
    required this.headerBuilder,
    required this.list,
  });

  @override
  _PinnedDayHeaderElement createElement() => _PinnedDayHeaderElement(this);

  @override
  _RenderPinnedDayHeaderSliver createRenderObject(BuildContext context) => _RenderPinnedDayHeaderSliver(daysLayout: daysLayout);

  @override
  void updateRenderObject(BuildContext context, _RenderPinnedDayHeaderSliver renderObject) {
    renderObject.daysLayout = daysLayout;
  }
}

class _PinnedDayHeaderElement extends RenderObjectElement {
  _PinnedDayHeaderElement(_PinnedDayHeaderSliver super.widget);

  Element? _list;
  Element? _header;

  @override
  _PinnedDayHeaderSliver get widget => super.widget as _PinnedDayHeaderSliver;

  @override
  _RenderPinnedDayHeaderSliver get renderObject => super.renderObject as _RenderPinnedDayHeaderSliver;

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    renderObject._element = this;
    _list = updateChild(_list, widget.list, null);
  }

  @override
  void update(_PinnedDayHeaderSliver newWidget) {
    super.update(newWidget);
    _list = updateChild(_list, newWidget.list, null);
    renderObject.scheduleLayoutCallback();
  }

  @override
  void performRebuild() {
    super.performRebuild();
    renderObject.scheduleLayoutCallback();
  }

  @override
  void unmount() {
    renderObject._element = null;
    super.unmount();
  }

  void _buildHeader(int? dayIndex) {
    owner!.buildScope(this, () {
      final header = dayIndex == null ? null : widget.headerBuilder(this, dayIndex);
      _header = updateChild(_header, header, null);
    });
  }

  @override
  void forgetChild(Element child) {
    if (child == _list) _list = null;
    if (child == _header) _header = null;
    super.forgetChild(child);
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    final list = _list;
    if (list != null) visitor(list);
    final header = _header;
    if (header != null) visitor(header);
  }

  @override
  void insertRenderObjectChild(RenderObject child, Object? slot) {
    switch (child) {
      case final RenderSliver list:
        renderObject.list = list;
      case final RenderBox header:
        renderObject.header = header;
    }
  }

  @override
  void moveRenderObjectChild(RenderObject child, Object? oldSlot, Object? newSlot) {
    assert(false);
  }

  @override
  void removeRenderObjectChild(RenderObject child, Object? slot) {
    switch (child) {
      case RenderSliver():
        renderObject.list = null;
      case RenderBox():
        renderObject.header = null;
    }
  }
}

class _RenderPinnedDayHeaderSliver extends RenderSliver with RenderSliverHelpers, RenderObjectWithLayoutCallbackMixin {
  _RenderPinnedDayHeaderSliver({required this._daysLayout});

  _PinnedDayHeaderElement? _element;

  _HistoryDaysLayout _daysLayout;
  set daysLayout(_HistoryDaysLayout value) {
    if (identical(value, _daysLayout)) return;
    _daysLayout = value;
    markNeedsLayout();
  }

  RenderSliver? _list;
  set list(RenderSliver? value) {
    final list = _list;
    if (list != null) dropChild(list);
    _list = value;
    if (value != null) adoptChild(value);
  }

  RenderBox? _header;
  set header(RenderBox? value) {
    final header = _header;
    if (header != null) dropChild(header);
    _header = value;
    if (value != null) adoptChild(value);
  }

  int? _headerDayIndex;
  double _headerOffset = 0.0;
  bool _shouldBuildHeader = true;

  @override
  void scheduleLayoutCallback() {
    _shouldBuildHeader = true;
    super.scheduleLayoutCallback();
  }

  @override
  void layoutCallback() => _element!._buildHeader(_headerDayIndex);

  @override
  void performLayout() {
    final list = _list!;
    list.layout(constraints, parentUsesSize: true);
    final listGeometry = list.geometry!;
    geometry = listGeometry;

    final daysLayout = _daysLayout;
    final scrollOffset = constraints.scrollOffset;
    final isPinned = scrollOffset > 0.0 && scrollOffset < listGeometry.scrollExtent;
    final dayIndex = isPinned ? daysLayout.dayAtOffset(scrollOffset) : null;
    if (_shouldBuildHeader || dayIndex != _headerDayIndex) {
      _shouldBuildHeader = false;
      _headerDayIndex = dayIndex;
      runLayoutCallback();
    }

    final header = _header;
    if (header == null || dayIndex == null) return;
    final headerExtent = daysLayout.headerExtent;
    final headerConstraints = constraints.asBoxConstraints(minExtent: headerExtent, maxExtent: headerExtent);
    header.layout(headerConstraints);
    final nextDayStartOffset = daysLayout.dayStartOffset(dayIndex + 1);
    final pushedOffset = nextDayStartOffset - scrollOffset - headerExtent;
    _headerOffset = pushedOffset.withMaximum(0.0);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final list = _list;
    if (list != null && list.geometry!.visible) context.paintChild(list, offset);
    final header = _header;
    if (header == null) return;
    final headerPaintOffset = offset.translate(0.0, _headerOffset);
    context.paintChild(header, headerPaintOffset);
  }

  @override
  bool hitTestChildren(SliverHitTestResult result, {required double mainAxisPosition, required double crossAxisPosition}) {
    final header = _header;
    if (header != null) {
      final boxResult = BoxHitTestResult.wrap(result);
      final didHitHeader = hitTestBoxChild(boxResult, header, mainAxisPosition: mainAxisPosition, crossAxisPosition: crossAxisPosition);
      if (didHitHeader) return true;
    }
    final list = _list;
    return list != null &&
        list.geometry!.hitTestExtent > 0 &&
        list.hitTest(
          result,
          mainAxisPosition: mainAxisPosition,
          crossAxisPosition: crossAxisPosition,
        );
  }

  @override
  double childMainAxisPosition(RenderObject child) => child == _header ? _headerOffset : 0.0;

  @override
  double childScrollOffset(RenderObject child) => child == _header ? constraints.scrollOffset + _headerOffset : 0.0;

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    final header = _header;
    if (header != null && child == header) applyPaintTransformForBoxChild(header, transform);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _list?.attach(owner);
    _header?.attach(owner);
  }

  @override
  void detach() {
    super.detach();
    _list?.detach();
    _header?.detach();
  }

  @override
  void redepthChildren() {
    final list = _list;
    if (list != null) redepthChild(list);
    final header = _header;
    if (header != null) redepthChild(header);
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    final list = _list;
    if (list != null) visitor(list);
    final header = _header;
    if (header != null) visitor(header);
  }
}

class _HistoryDaysList extends SliverMultiBoxAdaptorWidget {
  final _HistoryDaysLayout daysLayout;

  const _HistoryDaysList({
    required this.daysLayout,
    required super.delegate,
  });

  @override
  _RenderHistoryDaysList createRenderObject(BuildContext context) {
    final element = context as SliverMultiBoxAdaptorElement;
    return _RenderHistoryDaysList(childManager: element, daysLayout: daysLayout);
  }

  @override
  void updateRenderObject(BuildContext context, _RenderHistoryDaysList renderObject) {
    renderObject.daysLayout = daysLayout;
  }
}

class _RenderHistoryDaysList extends RenderSliverMultiBoxAdaptor {
  _RenderHistoryDaysList({required super.childManager, required this._daysLayout});

  _HistoryDaysLayout _daysLayout;
  set daysLayout(_HistoryDaysLayout value) {
    if (identical(value, _daysLayout)) return;
    _daysLayout = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final constraints = this.constraints;
    final daysLayout = _daysLayout;
    childManager.didStartLayout();
    childManager.setDidUnderflow(false);

    if (daysLayout.childCount == 0) {
      collectGarbage(0, 0);
      geometry = SliverGeometry.zero;
      childManager.didFinishLayout();
      return;
    }

    final scrollOffset = constraints.scrollOffset + constraints.cacheOrigin;
    final targetEndScrollOffset = scrollOffset + constraints.remainingCacheExtent;
    final firstIndex = daysLayout.childAtOffset(scrollOffset);
    final lastIndex = daysLayout.childAtOffset(targetEndScrollOffset);

    if (firstChild != null) {
      final leadingGarbage = calculateLeadingGarbage(firstIndex: firstIndex);
      final trailingGarbage = calculateTrailingGarbage(lastIndex: lastIndex);
      collectGarbage(leadingGarbage, trailingGarbage);
    } else {
      collectGarbage(0, 0);
    }

    if (firstChild == null) {
      final firstOffset = daysLayout.childOffset(firstIndex);
      addInitialChild(index: firstIndex, layoutOffset: firstOffset);
    }

    final headerExtent = daysLayout.headerExtent;
    final itemExtent = daysLayout.itemExtent;
    final headerConstraints = constraints.asBoxConstraints(minExtent: headerExtent, maxExtent: headerExtent);
    final itemConstraints = constraints.asBoxConstraints(minExtent: itemExtent, maxExtent: itemExtent);

    for (var index = indexOf(firstChild!) - 1; index >= firstIndex; index--) {
      final isHeader = daysLayout.isHeaderChild(index);
      insertAndLayoutLeadingChild(isHeader ? headerConstraints : itemConstraints);
    }

    var dayIndex = daysLayout.dayOfChild(firstIndex);
    var dayHeaderChild = daysLayout.headerChildOf(dayIndex);
    var nextDayHeaderChild = daysLayout.headerChildOf(dayIndex + 1);
    RenderBox? previousChild;
    for (var index = firstIndex; index <= lastIndex; index++) {
      if (index == nextDayHeaderChild) {
        dayIndex++;
        dayHeaderChild = nextDayHeaderChild;
        nextDayHeaderChild = daysLayout.headerChildOf(dayIndex + 1);
      }
      final childConstraints = index == dayHeaderChild ? headerConstraints : itemConstraints;
      var child = previousChild == null ? firstChild : childAfter(previousChild);
      if (child == null || indexOf(child) != index) {
        child = insertAndLayoutChild(childConstraints, after: previousChild)!;
      } else {
        child.layout(childConstraints);
      }
      final childParentData = child.parentData as SliverMultiBoxAdaptorParentData;
      childParentData.layoutOffset = daysLayout.childOffsetInDay(dayIndex, index);
      previousChild = child;
    }

    final leadingScrollOffset = daysLayout.childOffset(firstIndex);
    final trailingScrollOffset = daysLayout.childOffset(lastIndex + 1);
    final totalExtent = daysLayout.totalExtent;
    final paintExtent = calculatePaintOffset(constraints, from: leadingScrollOffset, to: trailingScrollOffset);
    final cacheExtent = calculateCacheOffset(constraints, from: leadingScrollOffset, to: trailingScrollOffset);
    final paintEndScrollOffset = constraints.scrollOffset + constraints.remainingPaintExtent;
    final lastPaintIndex = daysLayout.childAtOffset(paintEndScrollOffset);

    geometry = SliverGeometry(
      scrollExtent: totalExtent,
      paintExtent: paintExtent,
      cacheExtent: cacheExtent,
      maxPaintExtent: totalExtent,
      hasVisualOverflow: lastIndex >= lastPaintIndex || constraints.scrollOffset > 0.0,
    );

    if (trailingScrollOffset == totalExtent) childManager.setDidUnderflow(true);
    childManager.didFinishLayout();
  }
}

/// children are flat, each day is its header child followed by its item children.
class _HistoryDaysLayout {
  final int daysCount;
  final int childCount;
  final double totalExtent;
  final double itemExtent;
  final double headerExtent;
  final double _firstItemOffset;
  final double _dayBaseExtent;
  final Int32List _itemsBefore;

  const _HistoryDaysLayout._({
    required this.daysCount,
    required this.childCount,
    required this.totalExtent,
    required this.itemExtent,
    required this.headerExtent,
    required this._firstItemOffset,
    required this._dayBaseExtent,
    required this._itemsBefore,
  });

  factory _HistoryDaysLayout.compute({
    required int daysCount,
    required int Function(int dayIndex) dayItemsCount,
    required double itemExtent,
    required double headerExtent,
    required double itemsTopPadding,
    required double itemsBottomPadding,
  }) {
    final itemsBefore = Int32List(daysCount + 1);
    var itemsCount = 0;
    for (var i = 0; i < daysCount; i++) {
      itemsBefore[i] = itemsCount;
      itemsCount += dayItemsCount(i);
    }
    itemsBefore[daysCount] = itemsCount;

    final childCount = daysCount + itemsCount;
    final dayBaseExtent = headerExtent + itemsTopPadding + itemsBottomPadding;
    final totalExtent = daysCount * dayBaseExtent + itemsCount * itemExtent;
    final firstItemOffset = headerExtent + itemsTopPadding;
    return _HistoryDaysLayout._(
      daysCount: daysCount,
      childCount: childCount,
      totalExtent: totalExtent,
      itemExtent: itemExtent,
      headerExtent: headerExtent,
      firstItemOffset: firstItemOffset,
      dayBaseExtent: dayBaseExtent,
      itemsBefore: itemsBefore,
    );
  }

  double dayStartOffset(int dayIndex) => dayIndex * _dayBaseExtent + _itemsBefore[dayIndex] * itemExtent;

  int headerChildOf(int dayIndex) => dayIndex + _itemsBefore[dayIndex];

  int dayAtOffset(double offset) {
    var low = 0;
    var high = daysCount - 1;
    while (low < high) {
      final mid = (low + high + 1) >> 1;
      if (dayStartOffset(mid) <= offset) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low;
  }

  int dayOfChild(int childIndex) {
    var low = 0;
    var high = daysCount - 1;
    while (low < high) {
      final mid = (low + high + 1) >> 1;
      if (headerChildOf(mid) <= childIndex) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low;
  }

  bool isHeaderChild(int childIndex) {
    final dayIndex = dayOfChild(childIndex);
    return childIndex == headerChildOf(dayIndex);
  }

  double childOffsetInDay(int dayIndex, int childIndex) {
    final dayStart = dayStartOffset(dayIndex);
    final itemIndex = childIndex - headerChildOf(dayIndex) - 1;
    if (itemIndex < 0) return dayStart;
    return dayStart + _firstItemOffset + itemIndex * itemExtent;
  }

  double childOffset(int childIndex) {
    if (childIndex >= childCount) return totalExtent;
    final dayIndex = dayOfChild(childIndex);
    return childOffsetInDay(dayIndex, childIndex);
  }

  int childAtOffset(double offset) {
    final dayIndex = dayAtOffset(offset);
    final headerChild = headerChildOf(dayIndex);
    final offsetInDay = offset - dayStartOffset(dayIndex);
    if (offsetInDay < _firstItemOffset) return headerChild;
    final itemsCount = _itemsBefore[dayIndex + 1] - _itemsBefore[dayIndex];
    final itemsEndOffset = _firstItemOffset + itemsCount * itemExtent;
    if (offsetInDay >= itemsEndOffset) return headerChild + itemsCount;
    final itemIndex = (offsetInDay - _firstItemOffset) ~/ itemExtent;
    return headerChild + 1 + itemIndex;
  }
}
