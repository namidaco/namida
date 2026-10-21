// rewritten by claude, new one keeps active items on top in their order, slides toggled ones into place and toggles items dragged across the edge

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class NamidaReorderableActiveItemsList<E extends Enum> extends StatefulWidget {
  static const kLockedOpacity = 0.5;

  final List<E> items;
  final List<E> activeItems;
  final int minimumItems;
  final String Function(E item) toText;
  final IconData Function(E item) toIcon;
  final IconData? Function(E item)? toSecondaryIcon;
  final String Function(E item)? toSubtitle;
  final Widget? Function(E item, bool isActive)? trailingBuilder;

  /// can be reordered but never toggled.
  final bool Function(E item)? isLocked;

  /// false blocks activating, the caller shows why.
  final bool Function(E item)? canActivate;

  /// true when the caller handled the tap, it toggles the item later by changing [activeItems].
  final bool Function(E item, bool isActive)? interceptTap;

  final void Function(List<E> activeItems) onChanged;

  const NamidaReorderableActiveItemsList({
    super.key,
    required this.items,
    required this.activeItems,
    this.minimumItems = 0,
    required this.toText,
    required this.toIcon,
    this.toSecondaryIcon,
    this.toSubtitle,
    this.trailingBuilder,
    this.isLocked,
    this.canActivate,
    this.interceptTap,
    required this.onChanged,
  });

  @override
  State<NamidaReorderableActiveItemsList<E>> createState() => _NamidaReorderableActiveItemsListState<E>();
}

class _NamidaReorderableActiveItemsListState<E extends Enum> extends State<NamidaReorderableActiveItemsList<E>> with SingleTickerProviderStateMixin {
  late final _motion = _ItemsMotion(this, widget.items.length);

  /// keeps tile state (check animations) across index changes.
  late final _tileKeys = List<GlobalKey>.generate(widget.items.length, (_) => GlobalKey(), growable: false);

  /// ids are indices in [NamidaReorderableActiveItemsList.items].
  late List<int> _shownIds;
  late int _activeCount;

  @override
  void initState() {
    super.initState();
    final naturalOrder = List<int>.generate(widget.items.length, (id) => id, growable: false);
    _applyActiveItems(widget.activeItems, naturalOrder);
  }

  @override
  void didUpdateWidget(covariant NamidaReorderableActiveItemsList<E> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final activeItems = widget.activeItems;
    if (_isShowingActiveItems(activeItems)) return;
    _motion.recordTops(_shownIds);
    _applyActiveItems(activeItems, _shownIds);
    _motion.animateTo(_shownIds);
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  void _applyActiveItems(List<E> activeItems, List<int> inactiveOrder) {
    final items = widget.items;
    final isPlaced = List<bool>.filled(items.length, false);
    final shownIds = <int>[];
    for (final item in activeItems) {
      final id = items.indexOf(item);
      if (id == -1 || isPlaced[id]) continue;
      isPlaced[id] = true;
      shownIds.add(id);
    }
    _activeCount = shownIds.length;
    for (final id in inactiveOrder) {
      if (!isPlaced[id]) shownIds.add(id);
    }
    _shownIds = shownIds;
  }

  bool _isShowingActiveItems(List<E> activeItems) {
    if (activeItems.length != _activeCount) return false;
    final items = widget.items;
    for (int i = 0; i < _activeCount; i++) {
      if (items[_shownIds[i]] != activeItems[i]) return false;
    }
    return true;
  }

  List<E> _getActiveItems() {
    final items = widget.items;
    return _shownIds.take(_activeCount).map((id) => items[id]).toList();
  }

  bool _canToggle(E item, bool wasActive) {
    if (widget.isLocked?.call(item) == true) return false;
    if (!wasActive) return widget.canActivate?.call(item) ?? true;
    if (_activeCount > widget.minimumItems) return true;
    showMinimumItemsSnack(widget.minimumItems);
    return false;
  }

  void _onTap(int id) {
    final item = widget.items[id];
    final position = _shownIds.indexOf(id);
    final wasActive = position < _activeCount;
    if (widget.interceptTap?.call(item, wasActive) == true) return;
    if (!_canToggle(item, wasActive)) return;
    final newActiveCount = wasActive ? _activeCount - 1 : _activeCount + 1;
    final edgePosition = wasActive ? newActiveCount : _activeCount;
    setState(() {
      _motion.recordTops(_shownIds);
      _shownIds
        ..removeAt(position)
        ..insert(edgePosition, id);
      _motion.animateTo(_shownIds);
      _activeCount = newActiveCount;
    });
    widget.onChanged(_getActiveItems());
  }

  void _onReorder(int oldPosition, int newPosition) {
    if (newPosition > oldPosition) newPosition -= 1;
    final id = _shownIds[oldPosition];
    final wasActive = oldPosition < _activeCount;
    final otherActiveCount = wasActive ? _activeCount - 1 : _activeCount;
    final isDroppedActive = newPosition <= otherActiveCount;
    final didCrossEdge = isDroppedActive != wasActive;
    final canToggle = !didCrossEdge || _canToggle(widget.items[id], wasActive);

    // -- no animation, the drag already shows it at the drop position
    _shownIds
      ..removeAt(oldPosition)
      ..insert(newPosition, id);

    if (canToggle) {
      _activeCount = isDroppedActive ? otherActiveCount + 1 : otherActiveCount;
    } else {
      _motion.recordTops(_shownIds);
      _shownIds
        ..removeAt(newPosition)
        ..insert(otherActiveCount, id);
      _motion.animateTo(_shownIds);
    }
    final isActive = canToggle ? isDroppedActive : wasActive;
    setState(() {});
    if (wasActive || isActive) widget.onChanged(_getActiveItems());
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final toSecondaryIcon = widget.toSecondaryIcon;
    final toSubtitle = widget.toSubtitle;
    final trailingBuilder = widget.trailingBuilder;
    final isLocked = widget.isLocked;
    return NamidaListView(
      itemExtent: null,
      listBottomPadding: 12.0,
      showScrollbarOnStart: true,
      itemCount: _shownIds.length,
      onReorder: _onReorder,
      itemBuilder: (context, i) {
        final id = _shownIds[i];
        final item = items[id];
        final isActive = i < _activeCount;
        final text = widget.toText(item);
        final title = isActive ? '${i + 1}. $text' : text;
        final mainIcon = widget.toIcon(item);
        final secondaryIcon = toSecondaryIcon?.call(item);
        final leading = secondaryIcon == null
            ? null
            : StackedIcon(
                baseIcon: mainIcon,
                secondaryIcon: secondaryIcon,
                disableColor: true,
              );
        final subtitle = toSubtitle?.call(item) ?? '';
        final tile = ListTileWithCheckMark(
          icon: secondaryIcon == null ? mainIcon : null,
          leading: leading,
          title: title,
          subtitle: subtitle,
          active: isActive,
          trailing: trailingBuilder?.call(item, isActive),
          onTap: () => _onTap(id),
        );
        final isItemLocked = isLocked?.call(item) ?? false;
        final shownTile = isItemLocked
            ? Opacity(
                opacity: NamidaReorderableActiveItemsList.kLockedOpacity,
                child: tile,
              )
            : tile;
        return KeyedSubtree(
          key: ValueKey(id),
          child: _ItemMotion(
            key: _tileKeys[id],
            motion: _motion,
            id: id,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
              child: shownTile,
            ),
          ),
        );
      },
    );
  }
}

class _ItemsMotion {
  static const _curve = Curves.fastEaseInToSlowEaseOut;

  final AnimationController controller;
  final Float64List _heights;
  final Float64List _shiftsFrom;
  final Float64List _recordedTops;
  double _lastMeasuredHeight = 0.0;

  _ItemsMotion(TickerProvider vsync, int count)
    : controller = AnimationController(vsync: vsync, duration: const Duration(milliseconds: 300), value: 1.0),
      _heights = Float64List(count),
      _shiftsFrom = Float64List(count),
      _recordedTops = Float64List(count);

  double shiftOf(int id) {
    final shiftFrom = _shiftsFrom[id];
    if (shiftFrom == 0.0) return 0.0;
    final progress = _curve.transform(controller.value);
    return shiftFrom * (1.0 - progress);
  }

  void reportHeight(int id, double height) {
    _heights[id] = height;
    _lastMeasuredHeight = height;
  }

  double _heightOf(int id) {
    final height = _heights[id];
    return height == 0.0 ? _lastMeasuredHeight : height;
  }

  void recordTops(List<int> shownIds) {
    double top = 0.0;
    for (final id in shownIds) {
      _recordedTops[id] = top;
      top += _heightOf(id);
    }
  }

  /// slides every item from where it was shown at [recordTops] to its new position.
  void animateTo(List<int> shownIds) {
    double top = 0.0;
    for (final id in shownIds) {
      final currentShift = shiftOf(id);
      _shiftsFrom[id] = currentShift + _recordedTops[id] - top;
      top += _heightOf(id);
    }
    controller.forward(from: 0.0);
  }

  void dispose() => controller.dispose();
}

class _ItemMotion extends SingleChildRenderObjectWidget {
  final _ItemsMotion motion;
  final int id;

  const _ItemMotion({
    required super.key,
    required this.motion,
    required this.id,
    required super.child,
  });

  @override
  _RenderItemMotion createRenderObject(BuildContext context) => _RenderItemMotion(motion: motion, id: id);
}

class _RenderItemMotion extends RenderProxyBox {
  final _ItemsMotion motion;
  final int id;
  double _shift = 0.0;

  _RenderItemMotion({
    required this.motion,
    required this.id,
  });

  void _syncShift() {
    final shift = motion.shiftOf(id);
    if (shift == _shift) return;
    _shift = shift;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    motion.controller.addListener(_syncShift);
    _syncShift();
  }

  @override
  void detach() {
    motion.controller.removeListener(_syncShift);
    super.detach();
  }

  @override
  void performLayout() {
    super.performLayout();
    motion.reportHeight(id, size.height);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final shiftedOffset = offset.translate(0.0, _shift);
    super.paint(context, shiftedOffset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final shiftOffset = Offset(0.0, _shift);
    return result.addWithPaintOffset(
      offset: shiftOffset,
      position: position,
      hitTest: (result, shiftedPosition) => super.hitTestChildren(result, position: shiftedPosition),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.translateByDouble(0.0, _shift, 0.0, 1.0);
  }
}
