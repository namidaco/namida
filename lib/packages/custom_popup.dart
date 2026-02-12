/// source: https://pub.dev/packages/flutter_popup
/// modified to fit namida

// ignore_for_file: unused_element_parameter, use_build_context_synchronously, deprecated_member_use

part of '../../ui/widgets/popup_wrapper.dart';

enum _ArrowDirection { top, bottom }

enum PopupPosition { auto, top, bottom }

const double _kMenuMaxWidth = 5.0 * _kMenuWidthStep;
const double _kMenuMinWidth = 2.5 * _kMenuWidthStep;
const double _kMenuWidthStep = 56.0;

class CustomPopup extends StatefulWidget {
  final PopupMenuController? controller;
  final GlobalKey? anchorKey;
  final FutureOr<Widget> Function() content;
  final Widget child;
  final Listenable? refreshListenable;
  final void Function()? onTap;
  final bool openOnTap;
  final bool openOnLongPress;
  final Color? backgroundColor;
  final Color? arrowColor;
  final Color? barrierColor;
  final bool showArrow;
  final EdgeInsets contentPadding;
  final double? contentRadius;
  final BoxDecoration? contentDecoration;
  final VoidCallback? onBeforePopup;
  final VoidCallback? onAfterPopup;
  final PopupPosition position;
  final Duration animationDuration;
  final Curve animationCurve;

  const CustomPopup({
    super.key,
    this.controller,
    required this.content,
    required this.child,
    this.refreshListenable,
    this.onTap,
    this.anchorKey,
    this.openOnTap = true,
    this.openOnLongPress = true,
    this.backgroundColor,
    this.arrowColor,
    this.showArrow = true,
    this.barrierColor,
    this.contentPadding = const EdgeInsets.all(8),
    this.contentRadius,
    this.contentDecoration,
    this.onBeforePopup,
    this.onAfterPopup,
    this.position = PopupPosition.bottom,
    this.animationDuration = const Duration(milliseconds: 100),
    this.animationCurve = Curves.easeInOutQuart,
  });

  @override
  State<CustomPopup> createState() => CustomPopupState();

  Future<void> show(BuildContext context) async {
    final anchor = anchorKey?.currentContext ?? context;
    final renderBox = anchor.findRenderObject() as RenderBox?;

    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(renderBox.paintBounds.topLeft);

    onBeforePopup?.call();

    await NamidaNavigator.inst.showMenu(
      route: _PopupRoute(
        menuController: controller,
        targetRect: offset & renderBox.paintBounds.size,
        backgroundColor: backgroundColor,
        arrowColor: arrowColor,
        showArrow: showArrow,
        barriersColor: barrierColor,
        contentPadding: contentPadding,
        contentRadius: contentRadius,
        contentDecoration: contentDecoration,
        position: position,
        animationDuration: animationDuration,
        animationCurve: animationCurve,
        refreshListenable: refreshListenable,
        reOpenMenuCallback: () {
          NamidaNavigator.inst.popMenu();
          show(context);
        },
        child: await content(),
      ),
    );

    onAfterPopup?.call();
  }
}

class CustomPopupState extends State<CustomPopup> {
  void show() {
    widget.show(context);
  }

  @override
  Widget build(BuildContext context) {
    return TapDetector(
      onTap: () {
        if (widget.onTap != null) widget.onTap!();
        if (widget.openOnTap) {
          show();
        }
      },
      child: LongPressDetector(
        enableSecondaryTap: true,
        onLongPress: widget.openOnLongPress ? () => show() : null,
        child: isDesktop
            ? Stack(
                children: [
                  widget.child,
                  Positioned.fill(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      hitTestBehavior: HitTestBehavior.translucent,
                    ),
                  ),
                ],
              )
            : widget.child,
      ),
    );
  }
}

class _PopupContent extends StatelessWidget {
  final Widget child;
  final GlobalKey childKey;
  final GlobalKey arrowKey;
  final _ArrowDirection? arrowDirection;
  final double arrowHorizontal;
  final Color? backgroundColor;
  final Color? arrowColor;
  final bool showArrow;
  final EdgeInsets contentPadding;
  final double? contentRadius;
  final BoxDecoration? contentDecoration;

  const _PopupContent({
    super.key,
    required this.child,
    required this.childKey,
    required this.arrowKey,
    required this.arrowHorizontal,
    required this.showArrow,
    this.arrowDirection,
    this.backgroundColor,
    this.arrowColor,
    this.contentRadius,
    required this.contentPadding,
    this.contentDecoration,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: arrowDirection == _ArrowDirection.top ? 4.0 : null,
          bottom: arrowDirection == _ArrowDirection.bottom ? 4.0 : null,
          left: arrowHorizontal,
          child: RotatedBox(
            key: arrowKey,
            quarterTurns: arrowDirection == _ArrowDirection.top ? 2 : 4,
            child: arrowDirection == null || !showArrow
                ? SizedBox()
                : CustomPaint(
                    size: const Size(16, 8),
                    painter: _TrianglePainter(color: arrowColor ?? Colors.white),
                  ),
          ),
        ),
        Container(
          key: childKey,
          padding: contentPadding,
          margin: const EdgeInsets.symmetric(vertical: 10).copyWith(
            top: arrowDirection == _ArrowDirection.bottom ? 0 : null,
            bottom: arrowDirection == _ArrowDirection.top ? 0 : null,
          ),
          constraints: const BoxConstraints(minWidth: 50),
          decoration: contentDecoration ??
              BoxDecoration(
                color: backgroundColor ?? Colors.white,
                borderRadius: BorderRadius.circular(contentRadius ?? 10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                  ),
                ],
              ),
          child: IntrinsicWidth(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: _kMenuMinWidth,
                maxWidth: _kMenuMaxWidth,
              ),
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;

  const _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final path = Path();
    paint.isAntiAlias = true;
    paint.color = color;

    path.lineTo(size.width * 0.66, size.height * 0.86);
    path.cubicTo(size.width * 0.58, size.height * 1.05, size.width * 0.42, size.height * 1.05, size.width * 0.34, size.height * 0.86);
    path.cubicTo(size.width * 0.34, size.height * 0.86, 0, 0, 0, 0);
    path.cubicTo(0, 0, size.width, 0, size.width, 0);
    path.cubicTo(size.width, 0, size.width * 0.66, size.height * 0.86, size.width * 0.66, size.height * 0.86);
    path.cubicTo(size.width * 0.66, size.height * 0.86, size.width * 0.66, size.height * 0.86, size.width * 0.66, size.height * 0.86);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}

class PopupMenuController {
  PopupMenuController();

  _PopupRoute? _instance;

  void addListenable(Listenable listenable) {
    _instance?.addListenable(listenable);
  }

  void removeListenable(Listenable listenable) {
    _instance?.removeListenable(listenable);
  }

  void reOpenMenu() {
    _instance?.reOpenMenuCallback();
  }
}

class _PopupRoute extends PopupRoute<void> {
  final PopupMenuController? menuController;
  final Rect targetRect;
  final PopupPosition position;
  final Widget child;
  final Duration animationDuration;
  final Curve animationCurve;

  static const double _margin = 10;
  static final Rect _viewportRect = Rect.fromLTWH(
    _margin,
    Screen.statusBar + _margin,
    Screen.width - _margin * 2,
    Screen.height - Screen.statusBar - Screen.bottomBar - _margin * 2,
  );

  final GlobalKey _childKey = GlobalKey();
  final GlobalKey _arrowKey = GlobalKey();
  final Color? backgroundColor;
  final Color? arrowColor;
  final bool showArrow;
  final Color? barriersColor;
  final EdgeInsets contentPadding;
  final double? contentRadius;
  final BoxDecoration? contentDecoration;
  final Listenable? refreshListenable;
  final void Function() reOpenMenuCallback;

  double _maxHeight = _viewportRect.height;
  _ArrowDirection? _arrowDirection;
  double _arrowHorizontal = 0;
  double _scaleAlignDx = 0.5;
  double _scaleAlignDy = 0.5;
  double? _bottom;
  double? _top;
  double? _left;
  double? _right;

  _PopupRoute({
    this.menuController,
    super.settings,
    super.filter,
    super.traversalEdgeBehavior,
    required this.child,
    required this.targetRect,
    this.backgroundColor,
    this.arrowColor,
    required this.showArrow,
    this.barriersColor,
    required this.contentPadding,
    this.contentRadius,
    this.contentDecoration,
    this.position = PopupPosition.auto,
    required this.animationDuration,
    this.animationCurve = Curves.fastEaseInToSlowEaseOut,
    this.refreshListenable,
    required this.reOpenMenuCallback,
  });

  @override
  Color? get barrierColor => barriersColor ?? Colors.black.withOpacity(0.1);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Popup';

  @override
  TickerFuture didPush() {
    super.offstage = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final childRect = _getRect(_childKey);
      final arrowRect = _getRect(_arrowKey);
      _calculateArrowOffset(arrowRect, childRect);
      _calculateChildOffset(childRect);
      super.offstage = false;
    });
    return super.didPush();
  }

  @override
  void install() {
    super.install();

    menuController?._instance = this;

    if (refreshListenable != null) {
      addListenable(refreshListenable!);
    }
  }

  @override
  void didComplete(void result) {
    super.didComplete(result);

    if (refreshListenable != null) {
      // -- prefer removing it before the animation ends
      removeListenable(refreshListenable!);
    }
  }

  @override
  void dispose() {
    super.dispose();
    if (refreshListenable != null) {
      // -- just in case didComplete was not called for idk reasons
      removeListenable(refreshListenable!);
    }
  }

  void addListenable(Listenable listenable) {
    listenable.addListener(reOpenMenuCallback);
  }

  void removeListenable(Listenable listenable) {
    listenable.removeListener(reOpenMenuCallback);
  }

  Rect? _getRect(GlobalKey key) {
    final currentContext = key.currentContext;
    final renderBox = currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || currentContext == null) return null;
    final offset = renderBox.localToGlobal(renderBox.paintBounds.topLeft);
    var rect = offset & renderBox.paintBounds.size;

    if (Directionality.of(currentContext) == TextDirection.rtl) {
      rect = Rect.fromLTRB(0, rect.top, rect.right - rect.left, rect.bottom);
    }

    return rect;
  }

  // Calculate the horizontal position of the arrow
  void _calculateArrowOffset(Rect? arrowRect, Rect? childRect) {
    if (childRect == null || arrowRect == null) return;
    // Calculate the distance from the left side of the screen based on the middle position of the target and the popover layer
    var leftEdge = targetRect.center.dx - childRect.center.dx;
    final rightEdge = leftEdge + childRect.width;
    leftEdge = leftEdge < _viewportRect.left ? _viewportRect.left : leftEdge;
    // If it exceeds the screen, subtract the excess part
    if (rightEdge > _viewportRect.right) {
      leftEdge -= rightEdge - _viewportRect.right;
    }
    final center = targetRect.center.dx - leftEdge - arrowRect.center.dx;

    final leftSafeZone = (contentRadius ?? 0) + 15.0;
    final rightSafeZone = (contentRadius ?? 0) + 15.0;

    final minPosition = leftSafeZone;
    final maxPosition = childRect.width - rightSafeZone - arrowRect.width;

    _arrowHorizontal = center.clamp(minPosition, maxPosition);

    _scaleAlignDx = (_arrowHorizontal + arrowRect.center.dx) / childRect.width;
  }

  // Calculate the position of the popover
  void _calculateChildOffset(Rect? childRect) {
    if (childRect == null) return;

    // final topHeight = targetRect.top - _viewportRect.top;
    final bottomHeight = _viewportRect.bottom - targetRect.bottom;
    // final maximum = max(topHeight, bottomHeight);
    _maxHeight = childRect.height;

    if (position == PopupPosition.top || (position == PopupPosition.auto && _maxHeight > bottomHeight)) {
      _bottom = Screen.height - targetRect.top;
      _arrowDirection = _ArrowDirection.bottom;
      _scaleAlignDy = 1;
    } else {
      // Simple check: if child would go below viewport, adjust _top upwards
      _top = targetRect.bottom - Screen.bottomBar - 42.0;
      _top = _top! + _viewportRect.top;

      // Check if bottom of child would be outside viewport
      final childBottom = _top! + childRect.height;
      if (childBottom > _viewportRect.bottom) {
        // Move _top up by the overflow amount
        _scaleAlignDy = 2 * ((childBottom / _viewportRect.height) - 1.0);
        _top = _top! - (childBottom - _viewportRect.bottom + 32.0);
        _arrowDirection = null; // inaccurate arrow
      } else {
        _arrowDirection = _ArrowDirection.top;
        _scaleAlignDy = 0;
      }
    }

    // Horizontal positioning
    final left = targetRect.center.dx - childRect.center.dx;
    final right = left + childRect.width;

    if (right > _viewportRect.right) {
      _right = _margin;
      _left = null;
    } else {
      _left = left < _margin ? _margin : left;
      _right = null;
    }
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return child;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    child = _PopupContent(
      childKey: _childKey,
      arrowKey: _arrowKey,
      arrowHorizontal: _arrowHorizontal,
      arrowDirection: _arrowDirection,
      backgroundColor: backgroundColor,
      arrowColor: arrowColor,
      showArrow: showArrow,
      contentPadding: contentPadding,
      contentRadius: contentRadius,
      contentDecoration: contentDecoration,
      child: child,
    );
    if (!animation.isCompleted) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: animationCurve,
      );
      child = FadeTransition(
        opacity: curvedAnimation,
        child: ScaleTransition(
          alignment: FractionalOffset(_scaleAlignDx, _scaleAlignDy),
          scale: curvedAnimation,
          child: child,
        ),
      );
    }
    return Stack(
      children: [
        Positioned(
          left: _left,
          right: _right,
          top: _top,
          bottom: _bottom,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: _viewportRect.width,
              maxHeight: _maxHeight,
            ),
            child: child,
          ),
        ),
      ],
    );
  }

  @override
  Duration get transitionDuration => animationDuration;
}

abstract class Screen {
  static MediaQueryData get mediaQuery => MediaQueryData.fromView(
        PlatformDispatcher.instance.views.first,
      );

  /// screen width
  static double get width => mediaQuery.size.width;

  // /screen height
  static double get height => mediaQuery.size.height;

  /// dp
  static double get scale => mediaQuery.devicePixelRatio;

  /// top
  static double get statusBar => mediaQuery.padding.top;

  /// bottom
  static double get bottomBar => mediaQuery.padding.bottom;
}
