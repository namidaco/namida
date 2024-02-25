library focused_menu;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class FocusedMenuHolder extends StatefulWidget {
  final Widget child;
  final double menuItemExtent;
  final double? menuWidth;
  final List<FocusedMenuItem> menuItems;
  final bool animateMenuItems;
  final BoxDecoration? menuBoxDecoration;
  final Function? onPressed;
  final Duration duration;
  final double blurSize;
  final Color blurBackgroundColor;
  final double backgroundOpacity;
  final double bottomOffsetHeight;
  final double leftOffsetHeight;
  final double menuOffset;
  final double borderRadius;

  /// Main Widget of the menu, replaces [menuItems]
  final Widget? menuWidget;

  /// Open with tap insted of long press.
  final bool openWithTap;

  final int itemsAnimationDurationMS;
  final bool popOnItemTap;
  final bool Function()? onMenuOpen;
  final VoidCallback? onMenuClose;
  final bool enableBackgroundEffects;
  final double? menuHeight;
  final Alignment menuOpenAlignment;

  const FocusedMenuHolder({
    Key? key,
    required this.child,
    this.onPressed,
    this.menuItems = const <FocusedMenuItem>[],
    this.duration = const Duration(milliseconds: 100),
    this.menuBoxDecoration,
    this.menuItemExtent = 50.0,
    this.animateMenuItems = true,
    this.blurSize = 4.0,
    this.blurBackgroundColor = Colors.black,
    this.backgroundOpacity = 0.7,
    this.menuWidth,
    this.bottomOffsetHeight = 0.0,
    this.leftOffsetHeight = 0.0,
    this.menuOffset = 0.0,
    this.openWithTap = false,
    this.itemsAnimationDurationMS = 100,
    this.popOnItemTap = false,
    this.borderRadius = 8.0,
    this.menuWidget,
    this.onMenuOpen,
    this.onMenuClose,
    this.enableBackgroundEffects = false,
    this.menuHeight,
    this.menuOpenAlignment = Alignment.center,
  }) : super(key: key);

  @override
  State<FocusedMenuHolder> createState() => _FocusedMenuHolderState();
}

class _FocusedMenuHolderState extends State<FocusedMenuHolder> {
  final GlobalKey containerKey = GlobalKey();
  Offset childOffset = const Offset(0, 0);
  Size? childSize;

  getOffset() {
    RenderBox renderBox = containerKey.currentContext!.findRenderObject() as RenderBox;
    Size size = renderBox.size;
    Offset offset = renderBox.localToGlobal(Offset.zero);
    setState(() {
      childOffset = Offset(offset.dx, offset.dy);
      childSize = size;
    });
  }

  Future<void> _menuOpenFunction(BuildContext context) async {
    if (widget.onMenuOpen?.call() ?? true) {
      await openMenu(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: containerKey,
      onTap: () async {
        widget.onPressed?.call();
        if (widget.openWithTap) {
          await _menuOpenFunction(context);
        }
      },
      onLongPress: widget.openWithTap ? null : () => _menuOpenFunction(context),
      child: widget.child,
    );
  }

  Future<void> openMenu(BuildContext context) async {
    getOffset();
    widget.onMenuOpen?.call();
    await Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: widget.duration,
        pageBuilder: (context, animation, secondaryAnimation) {
          animation = Tween(begin: 0.0, end: 1.0).animate(animation);
          return FadeTransition(
              opacity: animation,
              child: FocusedMenuDetails(
                itemExtent: widget.menuItemExtent,
                menuBoxDecoration: widget.menuBoxDecoration,
                childOffset: childOffset,
                childSize: childSize,
                menuItems: widget.menuItems,
                blurSize: widget.blurSize,
                menuWidth: widget.menuWidth,
                blurBackgroundColor: widget.blurBackgroundColor,
                backgroundOpacity: widget.backgroundOpacity,
                animateMenu: widget.animateMenuItems,
                bottomOffsetHeight: widget.bottomOffsetHeight,
                leftOffsetHeight: widget.leftOffsetHeight,
                menuOffset: widget.menuOffset,
                itemsAnimationDurationMS: widget.itemsAnimationDurationMS,
                popOnItemTap: widget.popOnItemTap,
                menuAnimationDuration: widget.duration,
                borderRadius: widget.borderRadius,
                menuWidget: widget.menuWidget,
                onMenuClose: widget.onMenuClose,
                enableBackgroundEffects: widget.enableBackgroundEffects,
                menuHeightPre: widget.menuHeight,
                menuOpenAlignment: widget.menuOpenAlignment,
                child: widget.child,
              ));
        },
        fullscreenDialog: true,
        opaque: false,
      ),
    );
  }
}

class FocusedMenuDetails extends StatelessWidget {
  final List<FocusedMenuItem> menuItems;
  final BoxDecoration? menuBoxDecoration;
  final Offset childOffset;
  final double itemExtent;
  final Size? childSize;
  final Widget child;
  final bool animateMenu;
  final double blurSize;
  final double? menuWidth;
  final Color blurBackgroundColor;
  final double backgroundOpacity;
  final double bottomOffsetHeight;
  final double leftOffsetHeight;
  final double? menuOffset;
  final int itemsAnimationDurationMS;
  final bool popOnItemTap;
  final Duration menuAnimationDuration;
  final double borderRadius;
  final Widget? menuWidget;
  final VoidCallback? onMenuClose;
  final bool enableBackgroundEffects;
  final double? menuHeightPre;
  final Alignment menuOpenAlignment;

  const FocusedMenuDetails({
    Key? key,
    required this.menuItems,
    required this.child,
    required this.childOffset,
    required this.childSize,
    required this.menuBoxDecoration,
    required this.itemExtent,
    required this.animateMenu,
    required this.blurSize,
    required this.blurBackgroundColor,
    required this.backgroundOpacity,
    required this.menuWidth,
    required this.bottomOffsetHeight,
    required this.leftOffsetHeight,
    required this.menuOffset,
    required this.itemsAnimationDurationMS,
    required this.popOnItemTap,
    required this.menuAnimationDuration,
    required this.borderRadius,
    required this.menuWidget,
    required this.onMenuClose,
    required this.enableBackgroundEffects,
    required this.menuHeightPre,
    required this.menuOpenAlignment,
  }) : super(key: key);

  void _onDismiss(BuildContext context) {
    onMenuClose?.call();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    final maxMenuHeight = menuHeightPre ?? size.height * 0.45;
    final listHeight = menuItems.length * itemExtent;

    final maxMenuWidth = menuWidth ?? (size.width * 0.70);
    final menuHeight = listHeight != 0 && listHeight < maxMenuHeight ? listHeight : maxMenuHeight;
    final leftOffset = (childOffset.dx + maxMenuWidth) < size.width ? childOffset.dx : (childOffset.dx - maxMenuWidth + childSize!.width);
    final topOffset = (childOffset.dy + menuHeight + childSize!.height) < size.height - bottomOffsetHeight
        ? childOffset.dy + childSize!.height + menuOffset!
        : childOffset.dy - menuHeight - menuOffset!;
    return WillPopScope(
      onWillPop: () async {
        _onDismiss(context);
        return false;
      },
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            TapDetector(
              onTap: () => _onDismiss(context),
              child: enableBackgroundEffects
                  ? BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: blurSize, sigmaY: blurSize),
                      child: Container(
                        color: (blurBackgroundColor).withOpacity(backgroundOpacity),
                      ),
                    )
                  : Container(color: Colors.transparent),
            ),
            Positioned(
              top: topOffset - bottomOffsetHeight,
              left: leftOffset + leftOffsetHeight,
              child: TweenAnimationBuilder<double>(
                duration: menuAnimationDuration,
                builder: (BuildContext context, double value, Widget? child) {
                  return Transform.scale(
                    scale: value,
                    alignment: Alignment.bottomCenter,
                    child: child,
                  );
                },
                tween: Tween(begin: 0.0, end: 1.0),
                child: Container(
                  width: maxMenuWidth,
                  height: menuHeight,
                  decoration: menuBoxDecoration ??
                      BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
                          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10, spreadRadius: 1)]),
                  child: menuWidget ??
                      ListView.builder(
                        itemCount: menuItems.length,
                        padding: EdgeInsets.zero,
                        itemBuilder: (context, index) {
                          final FocusedMenuItem item = menuItems[index];
                          final Widget listItem = TapDetector(
                              onTap: () {
                                if (popOnItemTap) Navigator.pop(context);
                                item.onPressed();
                              },
                              child: Container(
                                  alignment: Alignment.center,
                                  margin: const EdgeInsets.only(bottom: 1),
                                  color: item.backgroundColor,
                                  height: itemExtent,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 14),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: <Widget>[
                                        item.title,
                                        if (item.trailingIcon != null) ...[item.trailingIcon!]
                                      ],
                                    ),
                                  )));
                          if (animateMenu) {
                            return TweenAnimationBuilder(
                                builder: (context, dynamic value, child) {
                                  return Transform(
                                    transform: Matrix4.rotationX(1.5708 * value),
                                    alignment: Alignment.bottomCenter,
                                    child: child,
                                  );
                                },
                                tween: Tween(begin: 1.0, end: 0.0),
                                duration: Duration(milliseconds: index * itemsAnimationDurationMS),
                                child: listItem);
                          } else {
                            return listItem;
                          }
                        },
                      ),
                ),
              ),
            ),
            Positioned(
              top: childOffset.dy,
              left: childOffset.dx,
              child: TapDetector(
                onTap: () => _onDismiss(context),
                child: AbsorbPointer(
                  absorbing: true,
                  child: SizedBox(
                    width: childSize!.width,
                    height: childSize!.height,
                    child: child,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FocusedMenuItem {
  final Color? backgroundColor;
  final Widget title;
  final Icon? trailingIcon;
  final Function onPressed;

  const FocusedMenuItem({
    this.backgroundColor,
    required this.title,
    this.trailingIcon,
    required this.onPressed,
  });
}
