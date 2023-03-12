// InnerDrawer is based on Drawer.
// The source code of the Drawer has been re-adapted for Inner Drawer.

// more details:
// https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/material/drawer.dart

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Signature for the callback that's called when a [InnerDrawer] is
/// opened or closed.
typedef InnerDrawerCallback = void Function(bool isOpened);

/// Signature for when a pointer that is in contact with the screen and moves to the right or left
/// values between 1 and 0
typedef InnerDragUpdateCallback = void Function(
  double value,
  InnerDrawerDirection? direction,
);

/// The possible position of a [InnerDrawer].
enum InnerDrawerDirection {
  /// An inner-drawer that is positioned to the left of the screen
  start,

  /// An inner-drawer that is positioned to the right of the screen
  end,
}

/// Animation type of a [InnerDrawer].
enum InnerDrawerAnimation {
  /// There is no animation
  static,

  /// The animation is linear.
  linear,

  /// The animation is quadratic.
  quadratic,
}

//width before initState
const double _kWidth = 400;
const double _kMinFlingVelocity = 365;
const double _kEdgeDragWidth = 20;
const Duration _kBaseSettleDuration = Duration(milliseconds: 246);

/// The [InnerDrawer] widget is a container for widgets that slide in from
/// one of two sides of the screen.
class InnerDrawer extends StatefulWidget {
  /// Creates an InnerDrawer.
  const InnerDrawer({
    GlobalKey? key,
    this.leftChild,
    this.rightChild,
    required this.scaffold,
    this.offset = const IDOffset.horizontal(0.4),
    this.scale = const IDOffset.horizontal(1),
    this.proportionalChildArea = true,
    this.borderRadius = 0,
    this.onTapClose = false,
    this.tapScaffoldEnabled = false,
    this.swipe = true,
    this.swipeChild = false,
    this.duration,
    this.velocity = 1,
    this.boxShadow,
    this.colorTransitionChild,
    this.colorTransitionScaffold,
    this.leftAnimationType = InnerDrawerAnimation.static,
    this.rightAnimationType = InnerDrawerAnimation.static,
    this.backgroundDecoration,
    this.innerDrawerCallback,
    this.onDragUpdate,
  })  : assert(
          leftChild != null || rightChild != null,
          'You must specify at least one child',
        ),
        super(key: key);

  /// Left child
  final Widget? leftChild;

  /// Right child
  final Widget? rightChild;

  /// A Scaffold is generally used but you are free to use other widgets
  final Widget scaffold;

  /// When the [InnerDrawer] is open, it's possible to set the offset of each of the four cardinal directions
  final IDOffset offset;

  /// When the [InnerDrawer] is open to the left or to the right
  /// values between 1 and 0. (default 1)
  final IDOffset scale;

  /// The proportionalChild Area = true dynamically sets the width based on the selected offset.
  /// On false it leaves the width at 100% of the screen
  final bool proportionalChildArea;

  /// edge radius when opening the scaffold - (default 0)
  final double borderRadius;

  /// Closes the open scaffold
  final bool tapScaffoldEnabled;

  /// Closes the open scaffold
  final bool onTapClose;

  /// activate or deactivate the swipe. NOTE: when deactivate, onTap Close is implicitly activated
  final bool swipe;

  /// activate or deactivate the swipeChild. NOTE: when deactivate, onTap Close is implicitly activated
  final bool swipeChild;

  /// duration animation controller
  final Duration? duration;

  /// possibility to set the opening and closing velocity
  final double velocity;

  /// BoxShadow of scaffold open
  final List<BoxShadow>? boxShadow;

  ///Color of gradient background
  final Color? colorTransitionChild;

  ///Color of gradient background
  final Color? colorTransitionScaffold;

  /// Static or Linear or Quadratic
  final InnerDrawerAnimation leftAnimationType;

  /// Static or Linear or Quadratic
  final InnerDrawerAnimation rightAnimationType;

  /// Color of the main background
  final Decoration? backgroundDecoration;

  /// Optional callback that is called when a [InnerDrawer] is open or closed.
  final InnerDrawerCallback? innerDrawerCallback;

  /// when a pointer that is in contact with the screen and moves to the right or left
  final InnerDragUpdateCallback? onDragUpdate;

  @override
  InnerDrawerState createState() => InnerDrawerState();
}

/// The [InnerDrawerState] for a [InnerDrawer].
class InnerDrawerState extends State<InnerDrawer> with SingleTickerProviderStateMixin {
  ColorTween _colorTransitionChild = ColorTween(begin: Colors.transparent, end: Colors.black54);
  ColorTween _colorTransitionScaffold = ColorTween(begin: Colors.black54, end: Colors.transparent);

  double _initWidth = _kWidth;
  Orientation _orientation = Orientation.portrait;
  late InnerDrawerDirection _position;

  @override
  void initState() {
    _position = _leftChild != null ? InnerDrawerDirection.start : InnerDrawerDirection.end;

    _controller = AnimationController(
      value: 1,
      duration: widget.duration ?? _kBaseSettleDuration,
      vsync: this,
    )
      ..addListener(_animationChanged)
      ..addStatusListener(_animationStatusChanged);
    super.initState();
  }

  @override
  void dispose() {
    _historyEntry?.remove();
    _controller.dispose();
    _focusScopeNode.dispose();
    super.dispose();
  }

  void _animationChanged() {
    setState(() {
      //   // The animation controller's state is our build state, and it changed already.
    });
    if (widget.colorTransitionChild != null) {
      _colorTransitionChild = ColorTween(
        begin: widget.colorTransitionChild!.withOpacity(0),
        end: widget.colorTransitionChild,
      );
    }

    if (widget.colorTransitionScaffold != null) {
      _colorTransitionScaffold = ColorTween(
        begin: widget.colorTransitionScaffold,
        end: widget.colorTransitionScaffold!.withOpacity(0),
      );
    }

    if (widget.onDragUpdate != null && _controller.value < 1) {
      widget.onDragUpdate!(1 - _controller.value, _position);
    }
  }

  LocalHistoryEntry? _historyEntry;
  final FocusScopeNode _focusScopeNode = FocusScopeNode();

  void _ensureHistoryEntry() {
    if (_historyEntry == null) {
      final ModalRoute<dynamic>? route = ModalRoute.of(context);
      if (route != null) {
        _historyEntry = LocalHistoryEntry(onRemove: _handleHistoryEntryRemoved);
        route.addLocalHistoryEntry(_historyEntry!);
        FocusScope.of(context).setFirstFocus(_focusScopeNode);
      }
    }
  }

  void _animationStatusChanged(AnimationStatus status) {
    final opened = _controller.value < 0.5;

    switch (status) {
      case AnimationStatus.reverse:
        break;
      case AnimationStatus.forward:
        break;
      case AnimationStatus.dismissed:
        if (_previouslyOpened != opened) {
          _previouslyOpened = opened;
          widget.innerDrawerCallback?.call(opened);
        }
        _ensureHistoryEntry();
        break;
      case AnimationStatus.completed:
        if (_previouslyOpened != opened) {
          _previouslyOpened = opened;
          widget.innerDrawerCallback?.call(opened);
        }
        _historyEntry?.remove();
        _historyEntry = null;
    }
  }

  void _handleHistoryEntryRemoved() {
    _historyEntry = null;
    close();
  }

  late AnimationController _controller;

  void _handleDragDown(DragDownDetails details) {
    _controller.stop();
    //_ensureHistoryEntry();
  }

  final GlobalKey _drawerKey = GlobalKey();

  double get _width {
    return _initWidth;
  }

  double get _velocity {
    return widget.velocity;
  }

  /// get width of screen after initState
  void _updateWidth() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = _drawerKey.currentContext!.findRenderObject() as RenderBox?;
      //final RenderBox box = context.findRenderObject();
      if (box != null && box.hasSize && box.size.width > 300) {
        setState(() {
          _initWidth = box.size.width;
        });
      }
    });
  }

  bool _previouslyOpened = false;

  void _move(DragUpdateDetails details) {
    var delta = details.primaryDelta! / _width;

    if (delta > 0 && _controller.value == 1 && _leftChild != null) {
      _position = InnerDrawerDirection.start;
    } else if (delta < 0 && _controller.value == 1 && _rightChild != null) {
      _position = InnerDrawerDirection.end;
    }

    var offset = _position == InnerDrawerDirection.start ? widget.offset.left : widget.offset.right;

    var ee = 1.0;
    if (offset <= 0.2) {
      ee = 1.7;
    } else if (offset <= 0.4) {
      ee = 1.2;
    } else if (offset <= 0.6) {
      ee = 1.05;
    }

    offset = 1 - (pow(offset / ee, 1 / 2) as double); //(num.parse(pow(offset/2,1/3).toStringAsFixed(1)));

    switch (_position) {
      case InnerDrawerDirection.end:
        break;
      case InnerDrawerDirection.start:
        delta = -delta;
        break;
    }
    switch (Directionality.of(context)) {
      case TextDirection.rtl:
        _controller.value -= delta + (delta * offset);
        break;
      case TextDirection.ltr:
        _controller.value += delta + (delta * offset);
        break;
    }

    final opened = _controller.value < 0.5;
    if (opened != _previouslyOpened && widget.innerDrawerCallback != null) {
      widget.innerDrawerCallback!(opened);
    }
    _previouslyOpened = opened;
  }

  void _settle(DragEndDetails details) {
    if (_controller.isDismissed) return;
    if (details.velocity.pixelsPerSecond.dx.abs() >= _kMinFlingVelocity) {
      var visualVelocity = (details.velocity.pixelsPerSecond.dx + _velocity) / _width;

      switch (_position) {
        case InnerDrawerDirection.end:
          break;
        case InnerDrawerDirection.start:
          visualVelocity = -visualVelocity;
          break;
      }
      switch (Directionality.of(context)) {
        case TextDirection.rtl:
          _controller.fling(velocity: -visualVelocity);
          break;
        case TextDirection.ltr:
          _controller.fling(velocity: visualVelocity);
          break;
      }
    } else if (_controller.value < 0.5) {
      open();
    } else {
      close();
    }
  }

  /// open the drawer
  void open({InnerDrawerDirection? direction}) {
    if (direction != null) _position = direction;
    _controller.fling(velocity: -_velocity);
  }

  /// close the drawer
  void close({InnerDrawerDirection? direction}) {
    if (direction != null) _position = direction;
    _controller.fling(velocity: _velocity);
  }

  /// Open or Close InnerDrawer
  void toggle({InnerDrawerDirection? direction}) {
    if (_previouslyOpened) {
      close(direction: direction);
    } else {
      open(direction: direction);
    }
  }

  final GlobalKey _gestureDetectorKey = GlobalKey();

  /// Outer Alignment
  AlignmentDirectional get _drawerOuterAlignment {
    switch (_position) {
      case InnerDrawerDirection.start:
        return AlignmentDirectional.centerEnd;
      case InnerDrawerDirection.end:
        return AlignmentDirectional.centerStart;
    }
  }

  /// Inner Alignment
  AlignmentDirectional get _drawerInnerAlignment {
    switch (_position) {
      case InnerDrawerDirection.start:
        return AlignmentDirectional.centerStart;
      case InnerDrawerDirection.end:
        return AlignmentDirectional.centerEnd;
    }
  }

  /// returns the left or right animation type based on InnerDrawerDirection
  InnerDrawerAnimation get _animationType {
    return _position == InnerDrawerDirection.start ? widget.leftAnimationType : widget.rightAnimationType;
  }

  /// returns the left or right scale based on InnerDrawerDirection
  double get _scaleFactor {
    return _position == InnerDrawerDirection.start ? widget.scale.left : widget.scale.right;
  }

  /// returns the left or right offset based on InnerDrawerDirection
  double get _offset {
    return _position == InnerDrawerDirection.start ? widget.offset.left : widget.offset.right;
  }

  /// return width with specific offset
  double get _widthWithOffset {
    return (_width / 2) - (_width / 2) * _offset;
    //NEW
    //return _width  - _width * _offset;
  }

  /// return swipe
  bool get _swipe {
    //NEW
    //if( _offset == 0 ) return false;
    return widget.swipe;
  }

  /// return swipeChild
  bool get _swipeChild {
    //NEW
    //if( _offset == 0 ) return false;
    return widget.swipeChild;
  }

  /// Scaffold
  Widget _scaffold() {
    assert(
      widget.borderRadius >= 0,
      'borderRadius must be greater than or equal to 0',
    );

    final invC = _invisibleCover();

    final Widget scaffoldChild = Stack(
      children: <Widget?>[widget.scaffold, if (invC != null) invC else null].whereType<Widget>().toList(),
    );

    Widget container = DecoratedBox(
      key: _drawerKey,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          widget.borderRadius * (1 - _controller.value),
        ),
        boxShadow: widget.boxShadow ??
            [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 5,
              )
            ],
      ),
      child: widget.borderRadius != 0
          ? ClipRRect(
              borderRadius: BorderRadius.circular(
                (1 - _controller.value) * widget.borderRadius,
              ),
              child: scaffoldChild,
            )
          : scaffoldChild,
    );

    if (_scaleFactor < 1) {
      container = Transform.scale(
        alignment: _drawerInnerAlignment,
        scale: ((1 - _scaleFactor) * _controller.value) + _scaleFactor,
        child: container,
      );
    }

    // Vertical translate
    if (widget.offset.top > 0 || widget.offset.bottom > 0) {
      final translateY = MediaQuery.of(context).size.height * (widget.offset.top > 0 ? -widget.offset.top : widget.offset.bottom);
      container = Transform.translate(
        offset: Offset(0, translateY * (1 - _controller.value)),
        child: container,
      );
    }

    return container;
  }

  ///Disable the scaffolding tap when the drawer is open
  Widget? _invisibleCover() {
    // ignore: use_colored_box
    final container = Container(
      color: _colorTransitionScaffold.evaluate(_controller),
    );
    if (_controller.value != 1.0 && !widget.tapScaffoldEnabled) {
      return BlockSemantics(
        child: GestureDetector(
          // On Android, the back button is used to dismiss a modal.
          excludeFromSemantics: defaultTargetPlatform == TargetPlatform.android,
          onTap: widget.onTapClose || !_swipe ? close : null,
          child: Semantics(
            label: MaterialLocalizations.of(context).modalBarrierDismissLabel,
            child: container,
          ),
        ),
      );
    }
    return null;
  }

  Widget? get _leftChild {
    return widget.leftChild;
  }

  Widget? get _rightChild {
    return widget.rightChild;
  }

  /// return widget with specific animation
  Widget _animatedChild() {
    var child = _position == InnerDrawerDirection.start ? _leftChild : _rightChild;
    if (_swipeChild) {
      child = GestureDetector(
        onHorizontalDragUpdate: _move,
        onHorizontalDragEnd: _settle,
        child: child,
      );
    }
    final Widget container = SizedBox(
      width: widget.proportionalChildArea ? _width - _widthWithOffset : _width,
      height: MediaQuery.of(context).size.height,
      child: child,
    );

    switch (_animationType) {
      case InnerDrawerAnimation.linear:
        return Align(
          alignment: _drawerOuterAlignment,
          widthFactor: 1 - (_controller.value),
          child: container,
        );
      case InnerDrawerAnimation.quadratic:
        return Align(
          alignment: _drawerOuterAlignment,
          widthFactor: 1 - (_controller.value / 2),
          child: container,
        );
      case InnerDrawerAnimation.static:
        return container;
    }
  }

  /// Trigger Area
  Widget? _trigger(AlignmentDirectional alignment, Widget? child) {
    final drawerIsStart = _position == InnerDrawerDirection.start;
    final padding = MediaQuery.of(context).padding;
    var dragAreaWidth = drawerIsStart ? padding.left : padding.right;

    if (Directionality.of(context) == TextDirection.rtl) {
      dragAreaWidth = drawerIsStart ? padding.right : padding.left;
    }
    dragAreaWidth = max(dragAreaWidth, _kEdgeDragWidth);

    if (_controller.status == AnimationStatus.completed && _swipe && child != null) {
      return Align(
        alignment: alignment,
        child: Container(color: Colors.transparent, width: dragAreaWidth),
      );
    } else {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    //assert(debugCheckHasMaterialLocalizations(context));

    /// initialize the correct width
    if (_initWidth == 400 || MediaQuery.of(context).orientation != _orientation) {
      _updateWidth();
      _orientation = MediaQuery.of(context).orientation;
    }

    /// wFactor depends of offset and is used by the second Align that contains the Scaffold
    final offset = 0.5 - _offset * 0.5;
    //NEW
    //final double offset = 1 - _offset * 1;
    final wFactor = (_controller.value * (1 - offset)) + offset;

    return DecoratedBox(
      decoration: widget.backgroundDecoration ??
          BoxDecoration(
            color: Theme.of(context).backgroundColor,
          ),
      child: Stack(
        alignment: _drawerInnerAlignment,
        children: <Widget>[
          FocusScope(node: _focusScopeNode, child: _animatedChild()),
          GestureDetector(
            key: _gestureDetectorKey,
            onTap: () {},
            onHorizontalDragDown: _swipe ? _handleDragDown : null,
            onHorizontalDragUpdate: _swipe ? _move : null,
            onHorizontalDragEnd: _swipe ? _settle : null,
            excludeFromSemantics: true,
            child: RepaintBoundary(
              child: Stack(
                children: <Widget?>[
                  ///Gradient
                  Container(
                    width: _controller.value == 0 || _animationType == InnerDrawerAnimation.linear ? 0 : null,
                    color: _colorTransitionChild.evaluate(_controller),
                  ),
                  Align(
                    alignment: _drawerOuterAlignment,
                    child: Align(
                      alignment: _drawerInnerAlignment,
                      widthFactor: wFactor,
                      child: RepaintBoundary(child: _scaffold()),
                    ),
                  ),

                  ///Trigger
                  _trigger(AlignmentDirectional.centerStart, _leftChild),
                  _trigger(AlignmentDirectional.centerEnd, _rightChild),
                ].whereType<Widget>().toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

///An immutable set of offset in each of the four cardinal directions.
class IDOffset {
  /// Creates horizontal offset.
  const IDOffset.horizontal(
    double horizontal,
  )   : left = horizontal,
        top = 0.0,
        right = horizontal,
        bottom = 0.0,
        assert(
          horizontal > 0.0 && horizontal <= 1.0,
          'horizontal offset must be between 0.0 and 1.0',
        );

  /// Creates offsets for each of the four cardinal directions.
  const IDOffset.only({
    this.left = 0.0,
    this.top = 0.0,
    this.right = 0.0,
    this.bottom = 0.0,
  })  : assert(
          top >= 0.0 && top <= 1.0 && left >= 0.0 && left <= 1.0 && right >= 0.0 && right <= 1.0 && bottom >= 0.0 && bottom <= 1.0,
          'Offset(top: $top, left: $left, right: $right, bottom: $bottom) must'
          ' be between 0.0 and 1.0.',
        ),
        assert(
          top >= 0.0 && bottom == 0.0 || top == 0.0 && bottom >= 0.0,
          'top'
          ' and bottom offset cannot be set at the same time.',
        );

  /// The offset from the left.
  final double left;

  /// The offset from the top.
  final double top;

  /// The offset from the right.
  final double right;

  /// The offset from the bottom.
  final double bottom;
}
