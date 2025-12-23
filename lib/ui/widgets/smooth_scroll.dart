// ignore_for_file: unused_element_parameter

part of 'custom_widgets.dart';

// source: https://pub.dev/packages/web_smooth_scroll
// modified to fit namida
class _DesktopSmoothMouseScroll extends StatefulWidget {
  /// Extra scroll offset to be added while the scroll is happened
  static const double _kDefaultScrollOffset = 1.5;

  /// Duration/length for how long the animation should go
  /// after the scroll has happened
  static const int _kDefaultAnimationDuration = 300;

  final ScrollController controller;

  final Axis scrollDirection;

  final bool reverse;

  /// Scroll speed for adjusting the smoothness and add a bit of extra scroll
  /// Default value is 2.5
  /// You can try it for a range of 2 - 5
  final double scrollSpeed;

  /// Duration/length for how long the animation should go
  /// after the scroll has happened
  /// Default value is 1500ms
  final int scrollAnimationLength;

  final Curve curve;

  final Widget child;

  const _DesktopSmoothMouseScroll({
    super.key,
    required this.controller,
    required this.scrollDirection,
    required this.reverse,
    this.scrollSpeed = _kDefaultScrollOffset,
    this.scrollAnimationLength = _kDefaultAnimationDuration,
    this.curve = Curves.easeOutCubic,
    required this.child,
  });

  @override
  State<_DesktopSmoothMouseScroll> createState() => _DesktopSmoothMouseScrollState();
}

class _DesktopSmoothMouseScrollState extends State<_DesktopSmoothMouseScroll> {
  double _scroll = 0;
  bool _isAnimating = false;
  double _targetScroll = 0;
  DateTime _lastScrollTime = DateTime.now();

  @override
  void initState() {
    super.initState();

    widget.controller.addListener(_scrollListener);
    _targetScroll = widget.controller.initialScrollOffset;
  }

  @override
  void didUpdateWidget(covariant _DesktopSmoothMouseScroll oldWidget) {
    if (!widget.controller.hasClients) {
      widget.controller.addListener(_scrollListener);
    }

    super.didUpdateWidget(oldWidget);
  }

  void _smoothScrollTo(double delta) {
    final controller = widget.controller;
    final now = DateTime.now();
    final timeDiff = now.difference(_lastScrollTime).inMilliseconds;
    _lastScrollTime = now;

    if (widget.reverse) delta = -delta;

    // Update target scroll position
    _targetScroll += (delta * widget.scrollSpeed);

    // Bound the scroll value
    if (_targetScroll > controller.position.maxScrollExtent) {
      _targetScroll = controller.position.maxScrollExtent;
    }
    if (_targetScroll < 0) {
      _targetScroll = 0;
    }

    // Calculate animation duration based on time between scrolls
    int animationDuration = timeDiff < 50
        ? widget.scrollAnimationLength ~/ 4 // Faster for rapid scrolling
        : widget.scrollAnimationLength;

    // If at bounds, use shorter animation
    if (_targetScroll == controller.position.maxScrollExtent || _targetScroll == 0) {
      animationDuration = widget.scrollAnimationLength ~/ 4;
    }

    _isAnimating = true;

    // Always start a new animation to the target
    controller
        .animateTo(
          _targetScroll,
          duration: Duration(milliseconds: animationDuration),
          curve: widget.curve,
        )
        .then((_) => _isAnimating = false);

    if (controller is ScrollControllerWithDirection) {
      // -- manually update controllers that need reliable direction, since "NeverScrollableScrollPhysics" won't update it
      final newDirection = delta.isNegative ? fr.ScrollDirection.forward : fr.ScrollDirection.reverse;
      for (final p in controller.positions) {
        if (p is _DirectionTrackingScrollPosition) {
          p.updateUserScrollDirection(newDirection);
        }
      }
    }
  }

  void _scrollListener() {
    _scroll = widget.controller.offset;
    // Update target scroll when user manually scrolls
    if (!_isAnimating) {
      _targetScroll = _scroll;
    }
  }

  void _onPointerSignal(PointerSignalEvent pointerSignal) {
    if (pointerSignal is PointerScrollEvent) {
      if (pointerSignal.kind != PointerDeviceKind.trackpad) {
        final isHorizontal = HardwareKeyboard.instance.isShiftPressed;
        final accept = switch (widget.scrollDirection) {
          Axis.horizontal => isHorizontal,
          Axis.vertical => !isHorizontal,
        };
        if (!accept) return;

        // Apply smooth scrolling for mouse wheel
        _smoothScrollTo(pointerSignal.scrollDelta.dy);
      } else {
        // For trackpad, calculate new offset with bounds checking
        final newOffset = (widget.controller.offset + pointerSignal.scrollDelta.dy).clamp(0.0, widget.controller.position.maxScrollExtent);
        // Directly update scroll position without smoothing
        widget.controller.jumpTo(newOffset);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _onPointerSignal,
      child: widget.child,
    );
  }
}

class _SuperSmoothScrollViewBuilder extends StatefulWidget {
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final Axis scrollDirection;
  final bool reverse;
  final Widget Function(ScrollController controller, ScrollPhysics? physics) builder;

  const _SuperSmoothScrollViewBuilder({
    super.key,
    required this.controller,
    required this.physics,
    required this.scrollDirection,
    required this.reverse,
    required this.builder,
  });

  @override
  State<_SuperSmoothScrollViewBuilder> createState() => __SuperSmoothScrollViewBuilderState();
}

class __SuperSmoothScrollViewBuilderState extends State<_SuperSmoothScrollViewBuilder> {
  late ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ScrollController();
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = _isDesktop;
    final physics = isDesktop ? const _CustomNeverScrollableScrollPhysics() : widget.physics;
    Widget child = widget.builder(_controller, physics);
    if (isDesktop) {
      child = _DesktopSmoothMouseScroll(
        controller: _controller,
        scrollDirection: widget.scrollDirection,
        reverse: widget.reverse,
        child: child,
      );
    }
    return child;
  }
}

class SmoothCustomScrollView extends StatelessWidget {
  final List<Widget> slivers;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final bool? primary;
  final Axis scrollDirection;
  final bool reverse;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final String? restorationId;
  final Clip clipBehavior;
  final DragStartBehavior dragStartBehavior;
  final double? cacheExtent;
  final double anchor;
  final bool shrinkWrap;

  const SmoothCustomScrollView({
    super.key,
    required this.slivers,
    this.controller,
    this.physics,
    this.primary,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
    this.dragStartBehavior = DragStartBehavior.start,
    this.cacheExtent,
    this.anchor = 0.0,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    return _SuperSmoothScrollViewBuilder(
      controller: controller,
      physics: physics,
      scrollDirection: scrollDirection,
      reverse: reverse,
      builder: (controller, physics) => CustomScrollView(
        controller: controller,
        slivers: slivers,
        physics: physics,
        primary: primary,
        anchor: anchor,
        shrinkWrap: shrinkWrap,
        scrollDirection: scrollDirection,
        reverse: reverse,
        keyboardDismissBehavior: keyboardDismissBehavior,
        restorationId: restorationId,
        clipBehavior: clipBehavior,
        dragStartBehavior: dragStartBehavior,
        cacheExtent: cacheExtent,
      ),
    );
  }
}

class SmoothSingleChildScrollView extends StatelessWidget {
  final Axis scrollDirection;
  final bool reverse;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;
  final bool? primary;
  final ScrollPhysics? physics;
  final Widget? child;
  final DragStartBehavior dragStartBehavior;
  final Clip clipBehavior;
  final HitTestBehavior hitTestBehavior;
  final String? restorationId;
  final ScrollViewKeyboardDismissBehavior? keyboardDismissBehavior;

  const SmoothSingleChildScrollView({
    super.key,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.padding,
    this.primary,
    this.physics,
    this.controller,
    this.child,
    this.dragStartBehavior = DragStartBehavior.start,
    this.clipBehavior = Clip.hardEdge,
    this.hitTestBehavior = HitTestBehavior.opaque,
    this.restorationId,
    this.keyboardDismissBehavior,
  });

  @override
  Widget build(BuildContext context) {
    return _SuperSmoothScrollViewBuilder(
      controller: controller,
      physics: physics,
      scrollDirection: scrollDirection,
      reverse: reverse,
      builder: (controller, physics) => SingleChildScrollView(
        controller: controller,
        physics: physics,
        scrollDirection: scrollDirection,
        reverse: reverse,
        padding: padding,
        primary: primary,
        dragStartBehavior: dragStartBehavior,
        clipBehavior: clipBehavior,
        hitTestBehavior: hitTestBehavior,
        restorationId: restorationId,
        keyboardDismissBehavior: keyboardDismissBehavior,
        child: child,
      ),
    );
  }
}

class SuperSmoothListView extends StatelessWidget {
  final Axis scrollDirection;
  final bool reverse;
  final ScrollController? controller;
  final bool? primary;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final EdgeInsetsGeometry? padding;
  final double? cacheExtent;
  final List<Widget> children;
  final bool addAutomaticKeepAlives;
  final bool addRepaintBoundaries;
  final bool addSemanticIndexes;
  final int? semanticChildCount;
  final DragStartBehavior dragStartBehavior;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final String? restorationId;
  final Clip clipBehavior;
  final ListController? listController;
  final ExtentEstimationProvider? extentEstimation;
  final ExtentPrecalculationPolicy? extentPrecalculationPolicy;
  final bool delayPopulatingCacheArea;

  const SuperSmoothListView({
    super.key,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.controller,
    this.primary,
    this.physics,
    this.shrinkWrap = false,
    this.padding,
    this.cacheExtent,
    required this.children,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
    this.semanticChildCount,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
    this.listController,
    this.extentEstimation,
    this.extentPrecalculationPolicy,
    this.delayPopulatingCacheArea = false,
  });

  @override
  Widget build(BuildContext context) => _SuperSmoothScrollViewBuilder(
        controller: controller,
        physics: physics,
        scrollDirection: scrollDirection,
        reverse: reverse,
        builder: (controller, physics) => SuperListView(
          controller: controller,
          physics: physics,
          listController: listController,
          extentEstimation: extentEstimation,
          extentPrecalculationPolicy: extentPrecalculationPolicy,
          delayPopulatingCacheArea: delayPopulatingCacheArea,
          scrollDirection: scrollDirection,
          reverse: reverse,
          primary: primary,
          shrinkWrap: shrinkWrap,
          padding: padding,
          cacheExtent: cacheExtent,
          semanticChildCount: semanticChildCount ?? children.length,
          dragStartBehavior: dragStartBehavior,
          keyboardDismissBehavior: keyboardDismissBehavior,
          restorationId: restorationId,
          clipBehavior: clipBehavior,
          addAutomaticKeepAlives: addAutomaticKeepAlives,
          addRepaintBoundaries: addRepaintBoundaries,
          addSemanticIndexes: addSemanticIndexes,
          children: children,
        ),
      );

  static Widget builder({
    Key? key,
    Axis scrollDirection = Axis.vertical,
    bool reverse = false,
    ScrollController? controller,
    bool? primary,
    ScrollPhysics? physics,
    bool shrinkWrap = false,
    EdgeInsetsGeometry? padding,
    double? cacheExtent,
    required NullableIndexedWidgetBuilder itemBuilder,
    ChildIndexGetter? findChildIndexCallback,
    int? itemCount,
    double? itemExtent,
    fr.ItemExtentBuilder? itemExtentBuilder,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
    bool addSemanticIndexes = true,
    int? semanticChildCount,
    DragStartBehavior dragStartBehavior = DragStartBehavior.start,
    ScrollViewKeyboardDismissBehavior keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    String? restorationId,
    Clip clipBehavior = Clip.hardEdge,
    ListController? listController,
    ExtentEstimationProvider? extentEstimation,
    ExtentPrecalculationPolicy? extentPrecalculationPolicy,
    bool delayPopulatingCacheArea = false,
  }) =>
      _SuperSmoothScrollViewBuilder(
        key: key,
        controller: controller,
        physics: physics,
        scrollDirection: scrollDirection,
        reverse: reverse,
        builder: (controller, physics) => itemExtent == null && itemExtentBuilder == null
            ? SuperListView.builder(
                controller: controller,
                physics: physics,
                scrollDirection: scrollDirection,
                listController: listController,
                extentEstimation: extentEstimation,
                extentPrecalculationPolicy: extentPrecalculationPolicy,
                delayPopulatingCacheArea: delayPopulatingCacheArea,
                reverse: reverse,
                primary: primary,
                shrinkWrap: shrinkWrap,
                padding: padding,
                cacheExtent: cacheExtent,
                itemBuilder: itemBuilder,
                findChildIndexCallback: findChildIndexCallback,
                itemCount: itemCount,
                addAutomaticKeepAlives: addAutomaticKeepAlives,
                addRepaintBoundaries: addRepaintBoundaries,
                addSemanticIndexes: addSemanticIndexes,
                semanticChildCount: semanticChildCount ?? itemCount,
                dragStartBehavior: dragStartBehavior,
                keyboardDismissBehavior: keyboardDismissBehavior,
                restorationId: restorationId,
                clipBehavior: clipBehavior,
              )
            : ListView.builder(
                controller: controller,
                physics: physics,
                scrollDirection: scrollDirection,
                itemExtent: itemExtent,
                itemExtentBuilder: itemExtentBuilder,
                reverse: reverse,
                primary: primary,
                shrinkWrap: shrinkWrap,
                padding: padding,
                cacheExtent: cacheExtent,
                itemBuilder: itemBuilder,
                findChildIndexCallback: findChildIndexCallback,
                itemCount: itemCount,
                addAutomaticKeepAlives: addAutomaticKeepAlives,
                addRepaintBoundaries: addRepaintBoundaries,
                addSemanticIndexes: addSemanticIndexes,
                semanticChildCount: semanticChildCount ?? itemCount,
                dragStartBehavior: dragStartBehavior,
                keyboardDismissBehavior: keyboardDismissBehavior,
                restorationId: restorationId,
                clipBehavior: clipBehavior,
              ),
      );

  static Widget separated({
    Key? key,
    Axis scrollDirection = Axis.vertical,
    bool reverse = false,
    ScrollController? controller,
    bool? primary,
    ScrollPhysics? physics,
    bool shrinkWrap = false,
    EdgeInsetsGeometry? padding,
    double? cacheExtent,
    required NullableIndexedWidgetBuilder itemBuilder,
    ChildIndexGetter? findChildIndexCallback,
    required IndexedWidgetBuilder separatorBuilder,
    required int itemCount,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
    bool addSemanticIndexes = true,
    DragStartBehavior dragStartBehavior = DragStartBehavior.start,
    ScrollViewKeyboardDismissBehavior keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    String? restorationId,
    Clip clipBehavior = Clip.hardEdge,
    ListController? listController,
    ExtentEstimationProvider? extentEstimation,
    ExtentPrecalculationPolicy? extentPrecalculationPolicy,
    bool delayPopulatingCacheArea = false,
  }) =>
      _SuperSmoothScrollViewBuilder(
        key: key,
        controller: controller,
        physics: physics,
        scrollDirection: scrollDirection,
        reverse: reverse,
        builder: (controller, physics) => SuperListView.separated(
          controller: controller,
          physics: physics,
          listController: listController,
          extentEstimation: extentEstimation,
          extentPrecalculationPolicy: extentPrecalculationPolicy,
          delayPopulatingCacheArea: delayPopulatingCacheArea,
          scrollDirection: scrollDirection,
          reverse: reverse,
          primary: primary,
          shrinkWrap: shrinkWrap,
          padding: padding,
          cacheExtent: cacheExtent,
          itemBuilder: itemBuilder,
          findChildIndexCallback: findChildIndexCallback,
          separatorBuilder: separatorBuilder,
          itemCount: itemCount,
          addAutomaticKeepAlives: addAutomaticKeepAlives,
          addRepaintBoundaries: addRepaintBoundaries,
          addSemanticIndexes: addSemanticIndexes,
          dragStartBehavior: dragStartBehavior,
          keyboardDismissBehavior: keyboardDismissBehavior,
          restorationId: restorationId,
          clipBehavior: clipBehavior,
        ),
      );

  static Widget custom({
    Key? key,
    Axis scrollDirection = Axis.vertical,
    bool reverse = false,
    ScrollController? controller,
    bool? primary,
    ScrollPhysics? physics,
    bool shrinkWrap = false,
    EdgeInsetsGeometry? padding,
    double? cacheExtent,
    required SliverChildDelegate childrenDelegate,
    int? semanticChildCount,
    DragStartBehavior dragStartBehavior = DragStartBehavior.start,
    ScrollViewKeyboardDismissBehavior keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    String? restorationId,
    Clip clipBehavior = Clip.hardEdge,
    ListController? listController,
    ExtentEstimationProvider? extentEstimation,
    ExtentPrecalculationPolicy? extentPrecalculationPolicy,
    bool delayPopulatingCacheArea = false,
  }) =>
      _SuperSmoothScrollViewBuilder(
        key: key,
        controller: controller,
        physics: physics,
        scrollDirection: scrollDirection,
        reverse: reverse,
        builder: (controller, physics) => SuperListView.custom(
          controller: controller,
          physics: physics,
          listController: listController,
          extentEstimation: extentEstimation,
          extentPrecalculationPolicy: extentPrecalculationPolicy,
          delayPopulatingCacheArea: delayPopulatingCacheArea,
          scrollDirection: scrollDirection,
          reverse: reverse,
          primary: primary,
          shrinkWrap: shrinkWrap,
          padding: padding,
          cacheExtent: cacheExtent,
          childrenDelegate: childrenDelegate,
          semanticChildCount: semanticChildCount,
          dragStartBehavior: dragStartBehavior,
          keyboardDismissBehavior: keyboardDismissBehavior,
          restorationId: restorationId,
          clipBehavior: clipBehavior,
        ),
      );
}

class SmoothGridView {
  static Widget builder({
    Key? key,
    required SliverGridDelegate gridDelegate,
    Axis scrollDirection = Axis.vertical,
    bool reverse = false,
    ScrollController? controller,
    bool? primary,
    ScrollPhysics? physics,
    bool shrinkWrap = false,
    EdgeInsetsGeometry? padding,
    double? cacheExtent,
    required NullableIndexedWidgetBuilder itemBuilder,
    ChildIndexGetter? findChildIndexCallback,
    int? itemCount,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
    bool addSemanticIndexes = true,
    int? semanticChildCount,
    DragStartBehavior dragStartBehavior = DragStartBehavior.start,
    ScrollViewKeyboardDismissBehavior keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    String? restorationId,
    Clip clipBehavior = Clip.hardEdge,
  }) =>
      _SuperSmoothScrollViewBuilder(
        key: key,
        controller: controller,
        physics: physics,
        scrollDirection: scrollDirection,
        reverse: reverse,
        builder: (controller, physics) => GridView.builder(
          gridDelegate: gridDelegate,
          controller: controller,
          physics: physics,
          scrollDirection: scrollDirection,
          reverse: reverse,
          primary: primary,
          shrinkWrap: shrinkWrap,
          padding: padding,
          cacheExtent: cacheExtent,
          itemBuilder: itemBuilder,
          findChildIndexCallback: findChildIndexCallback,
          itemCount: itemCount,
          addAutomaticKeepAlives: addAutomaticKeepAlives,
          addRepaintBoundaries: addRepaintBoundaries,
          addSemanticIndexes: addSemanticIndexes,
          semanticChildCount: semanticChildCount ?? itemCount,
          dragStartBehavior: dragStartBehavior,
          keyboardDismissBehavior: keyboardDismissBehavior,
          restorationId: restorationId,
          clipBehavior: clipBehavior,
        ),
      );
}

class SmoothMasonryGridView {
  static Widget builder({
    Key? key,
    required SliverSimpleGridDelegate gridDelegate,
    Axis scrollDirection = Axis.vertical,
    bool reverse = false,
    ScrollController? controller,
    bool? primary,
    ScrollPhysics? physics,
    bool shrinkWrap = false,
    EdgeInsetsGeometry? padding,
    double? cacheExtent,
    required IndexedWidgetBuilder itemBuilder,
    int? itemCount,
    double mainAxisSpacing = 0.0,
    double crossAxisSpacing = 0.0,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
    bool addSemanticIndexes = true,
    int? semanticChildCount,
    DragStartBehavior dragStartBehavior = DragStartBehavior.start,
    ScrollViewKeyboardDismissBehavior keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    String? restorationId,
    Clip clipBehavior = Clip.hardEdge,
  }) =>
      _SuperSmoothScrollViewBuilder(
        key: key,
        controller: controller,
        physics: physics,
        scrollDirection: scrollDirection,
        reverse: reverse,
        builder: (controller, physics) => MasonryGridView.builder(
          gridDelegate: gridDelegate,
          controller: controller,
          physics: physics,
          scrollDirection: scrollDirection,
          reverse: reverse,
          primary: primary,
          shrinkWrap: shrinkWrap,
          padding: padding,
          cacheExtent: cacheExtent,
          itemBuilder: itemBuilder,
          itemCount: itemCount,
          mainAxisSpacing: mainAxisSpacing,
          crossAxisSpacing: crossAxisSpacing,
          addAutomaticKeepAlives: addAutomaticKeepAlives,
          addRepaintBoundaries: addRepaintBoundaries,
          addSemanticIndexes: addSemanticIndexes,
          semanticChildCount: semanticChildCount ?? itemCount,
          dragStartBehavior: dragStartBehavior,
          keyboardDismissBehavior: keyboardDismissBehavior,
          restorationId: restorationId,
          clipBehavior: clipBehavior,
        ),
      );
}

class ScrollControllerWithDirection extends ScrollController {
  ScrollControllerWithDirection({
    super.initialScrollOffset,
    super.keepScrollOffset = true,
    super.debugLabel,
    super.onAttach,
    super.onDetach,
  });

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _DirectionTrackingScrollPosition(
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
    );
  }

  fr.ScrollDirection? get userScrollDirection {
    return positions.lastOrNull?.userScrollDirection;
  }
}

// custom scroll position that tracks direction, since "NeverScrollableScrollPhysics" will prevent reports
class _DirectionTrackingScrollPosition extends ScrollPositionWithSingleContext {
  _DirectionTrackingScrollPosition({
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  @override
  fr.ScrollDirection get userScrollDirection => _userScrollDirection;
  fr.ScrollDirection _userScrollDirection = fr.ScrollDirection.idle;

  @override
  void updateUserScrollDirection(fr.ScrollDirection value) {
    if (userScrollDirection == value) {
      return;
    }
    _userScrollDirection = value;
    super.updateUserScrollDirection(value);
  }

  // @override
  // Future<void> moveTo(double to, {Duration? duration, Curve? curve, bool? clamp = true}) {
  //   print('-------- moveTo $to');
  //   assert(clamp != null);

  //   if (clamp!) {
  //     to = clampDouble(to, minScrollExtent, maxScrollExtent);
  //   }

  //   return super.moveTo(to, duration: duration, curve: curve);
  // }
}

class _CustomNeverScrollableScrollPhysics extends ScrollPhysics {
  const _CustomNeverScrollableScrollPhysics({super.parent});

  @override
  _CustomNeverScrollableScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _CustomNeverScrollableScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  bool get allowUserScrolling => false;

  @override
  bool get allowImplicitScrolling => true;
}
