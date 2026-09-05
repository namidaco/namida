// ignore_for_file: unused_element_parameter

part of 'custom_widgets.dart';

// this scary probing and position finder code is by claude
class NamidaScrollController {
  static final _registeredScrollControllers = <ScrollController>[];

  static const _probeFractions = <(double, double)>[
    (0.75, 0.4), // -- right side, since side info box (when displayed) takes the left
    (0.5, 0.4),
    (0.25, 0.4),
    (0.6, 0.75),
  ];

  /// Returns the [ScrollPosition] of the scrollable actually painted at [globalPosition],
  /// by hit testing, which respects paint order, routes stack, offstage subtrees, etc.
  ///
  /// [withinAncestor] rejects hits that arent inside that render object (ex: miniplayer queue).
  static ScrollPosition? positionAt(
    Offset globalPosition, {
    required int viewId,
    Axis? axis,
    RenderObject? withinAncestor,
  }) {
    if (_registeredScrollControllers.isEmpty) return null;

    final positionsByRenderObject = <RenderObject, ScrollPosition>{};
    for (final controller in _registeredScrollControllers) {
      for (final position in controller.positions) {
        if (axis != null && position.axis != axis) continue;
        final scrollableContext = position.context.notificationContext ?? position.context.storageContext;
        final renderObject = scrollableContext.findRenderObject();
        if (renderObject != null) positionsByRenderObject[renderObject] = position;
      }
    }
    if (positionsByRenderObject.isEmpty) return null;

    final hitTestResult = HitTestResult();
    WidgetsBinding.instance.hitTestInView(hitTestResult, globalPosition, viewId);

    ScrollPosition? found;
    bool ancestorMatched = withinAncestor == null;
    // -- path is ordered from deepest to root
    for (final entry in hitTestResult.path) {
      final target = entry.target;
      if (found == null) {
        found = positionsByRenderObject[target];
        if (found != null && ancestorMatched) break;
      } else if (identical(target, withinAncestor)) {
        ancestorMatched = true;
        break;
      }
    }
    return ancestorMatched ? found : null;
  }

  /// Probes few points of the screen to find the scrollable currently displayed.
  static ScrollPosition? findVisiblePosition({
    Axis? axis = Axis.vertical,
    RenderObject? withinAncestor,
  }) {
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    if (view == null) return null;
    final size = view.physicalSize / view.devicePixelRatio;
    if (size.isEmpty) return null;

    for (final fraction in _probeFractions) {
      final position = positionAt(
        Offset(size.width * fraction.$1, size.height * fraction.$2),
        viewId: view.viewId,
        axis: axis,
        withinAncestor: withinAncestor,
      );
      if (position != null) return position;
    }
    return null;
  }

  /// Like [findVisiblePosition] but keeps retrying each frame until [timeout],
  /// useful when the ui is still settling (ex: a miniplayer being minimized).
  static Future<ScrollPosition?> findVisiblePositionAfterSettle({
    Axis? axis = Axis.vertical,
    RenderObject? withinAncestor,
    Duration timeout = const Duration(milliseconds: 600),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final position = findVisiblePosition(axis: axis, withinAncestor: withinAncestor);
      if (position != null) return position;
      if (DateTime.now().isAfter(deadline)) return null;
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  static ScrollController create({
    double initialScrollOffset = 0.0,
    bool keepScrollOffset = true,
    String? debugLabel,
    void Function(ScrollPosition)? onAttach,
    void Function(ScrollPosition)? onDetach,
  }) {
    if (NamidaFeaturesVisibility.smoothScrolling) {
      return SmoothScrollController(
        smooth: () => settings.extra.smoothScrolling ?? true,
        initialScrollOffset: initialScrollOffset,
        keepScrollOffset: keepScrollOffset,
        debugLabel: debugLabel,
        onAttach: onAttach,
        onDetach: onDetach,
      );
    }
    return ScrollController(
      initialScrollOffset: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      debugLabel: debugLabel,
      onAttach: onAttach,
      onDetach: onDetach,
    );
  }
}

class _SmoothScrollControllerBuilder extends StatefulWidget {
  final ScrollController? controller;
  final Widget Function(ScrollController controller) builder;

  const _SmoothScrollControllerBuilder({
    super.key,
    required this.controller,
    required this.builder,
  });

  @override
  State<_SmoothScrollControllerBuilder> createState() => __SmoothScrollControllerBuilderState();
}

class __SmoothScrollControllerBuilderState extends State<_SmoothScrollControllerBuilder> {
  late ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? NamidaScrollController.create();
    NamidaScrollController._registeredScrollControllers.add(_controller);
  }

  @override
  void activate() {
    super.activate();
    NamidaScrollController._registeredScrollControllers.add(_controller);
  }

  @override
  void deactivate() {
    super.deactivate();
    NamidaScrollController._registeredScrollControllers.remove(_controller);
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    NamidaScrollController._registeredScrollControllers.remove(_controller);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(_controller);
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
  final fr.ScrollCacheExtent? scrollCacheExtent;
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
    this.scrollCacheExtent,
    this.anchor = 0.0,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    return _SmoothScrollControllerBuilder(
      controller: controller,
      builder: (controller) => CustomScrollView(
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
        scrollCacheExtent: scrollCacheExtent,
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
    return _SmoothScrollControllerBuilder(
      controller: controller,
      builder: (controller) => SingleChildScrollView(
        controller: controller,
        padding: padding,
        physics: physics,
        reverse: reverse,
        scrollDirection: scrollDirection,
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
  final fr.ScrollCacheExtent? scrollCacheExtent;
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
    this.scrollCacheExtent,
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
  Widget build(BuildContext context) => _SmoothScrollControllerBuilder(
    controller: controller,
    builder: (controller) => SuperListView(
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
      cacheExtent: scrollCacheExtent?.value,
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
    fr.ScrollCacheExtent? scrollCacheExtent,
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
  }) => _SmoothScrollControllerBuilder(
    key: key,
    controller: controller,
    builder: (controller) => itemExtent == null && itemExtentBuilder == null
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
            cacheExtent: scrollCacheExtent?.value,
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
            scrollCacheExtent: scrollCacheExtent,
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
    fr.ScrollCacheExtent? scrollCacheExtent,
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
  }) => _SmoothScrollControllerBuilder(
    key: key,
    controller: controller,
    builder: (controller) => SuperListView.separated(
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
      cacheExtent: scrollCacheExtent?.value,
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
    fr.ScrollCacheExtent? scrollCacheExtent,
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
  }) => _SmoothScrollControllerBuilder(
    key: key,
    controller: controller,
    builder: (controller) => SuperListView.custom(
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
      cacheExtent: scrollCacheExtent?.value,
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
    fr.ScrollCacheExtent? scrollCacheExtent,
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
  }) => _SmoothScrollControllerBuilder(
    key: key,
    controller: controller,
    builder: (controller) => GridView.builder(
      gridDelegate: gridDelegate,
      controller: controller,
      physics: physics,
      scrollDirection: scrollDirection,
      reverse: reverse,
      primary: primary,
      shrinkWrap: shrinkWrap,
      padding: padding,
      scrollCacheExtent: scrollCacheExtent,
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
    fr.ScrollCacheExtent? scrollCacheExtent,
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
  }) => _SmoothScrollControllerBuilder(
    key: key,
    controller: controller,
    builder: (controller) => MasonryGridView.builder(
      gridDelegate: gridDelegate,
      controller: controller,
      physics: physics,
      scrollDirection: scrollDirection,
      reverse: reverse,
      primary: primary,
      shrinkWrap: shrinkWrap,
      padding: padding,
      cacheExtent: scrollCacheExtent?.value,
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
