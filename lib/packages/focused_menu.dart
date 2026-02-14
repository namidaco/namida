library;

import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:namida/ui/widgets/custom_widgets.dart';

class FocusedMenuHolder extends StatefulWidget {
  final Widget child;
  final FocusedMenuDetails Function(GlobalKey containerKey) options;
  final Function? onPressed;

  /// Open with tap insted of long press.
  final bool openWithTap;

  const FocusedMenuHolder({
    super.key,
    required this.child,
    required this.options,
    this.onPressed,
    this.openWithTap = false,
  });

  @override
  State<FocusedMenuHolder> createState() => _FocusedMenuHolderState();
}

class _FocusedMenuHolderState extends State<FocusedMenuHolder> {
  final GlobalKey containerKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: containerKey,
      onTap: () async {
        widget.onPressed?.call();
        if (widget.openWithTap) {
          await openMenu(context);
        }
      },
      onSecondaryTap: widget.openWithTap ? null : () => openMenu(context),
      onLongPress: widget.openWithTap ? null : () => openMenu(context),
      child: widget.child,
    );
  }

  Future<void> openMenu(BuildContext context) async {
    final options = widget.options(containerKey);
    if (options.onMenuOpen?.call() ?? true) {
      await Navigator.push(
        context,
        PageRouteBuilder(
          transitionDuration: options.duration,
          pageBuilder: (context, animation, secondaryAnimation) {
            animation = Tween(begin: 0.0, end: 1.0).animate(animation);
            return FadeTransition(
              opacity: animation,
              child: options,
            );
          },
          fullscreenDialog: true,
          opaque: false,
        ),
      );
    }
  }
}

class FocusedMenuDetails extends StatelessWidget {
  final GlobalKey containerKey;
  final List<FocusedMenuItem> menuItems;
  final Duration duration;
  final BoxDecoration? menuBoxDecoration;
  final double menuItemExtent;
  final bool animateMenuItems;
  final double blurSize;
  final double Function(BuildContext context)? menuWidth;
  final Color blurBackgroundColor;
  final double backgroundOpacity;
  final double bottomOffsetHeight;
  final double leftOffsetHeight;
  final double? menuOffset;
  final int itemsAnimationDurationMS;
  final bool popOnItemTap;
  final double borderRadius;
  final Widget? menuWidget;
  final bool Function()? onMenuOpen;
  final VoidCallback? onMenuClose;
  final bool enableBackgroundEffects;
  final double? menuHeight;
  final Alignment menuOpenAlignment;

  const FocusedMenuDetails({
    super.key,
    required this.containerKey,
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
    this.itemsAnimationDurationMS = 100,
    this.popOnItemTap = false,
    this.borderRadius = 8.0,
    this.menuWidget,
    this.onMenuOpen,
    this.onMenuClose,
    this.enableBackgroundEffects = false,
    this.menuHeight,
    this.menuOpenAlignment = Alignment.center,
  });

  void _onDismiss(BuildContext context) {
    onMenuClose?.call();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    RenderBox renderBox = containerKey.currentContext!.findRenderObject() as RenderBox;
    Offset offset = renderBox.localToGlobal(Offset.zero);
    final childOffset = Offset(offset.dx, offset.dy);
    final childSize = renderBox.size;

    final maxMenuHeight = this.menuHeight ?? size.height * 0.45;
    final listHeight = menuItems.length * menuItemExtent;

    final maxMenuWidth = menuWidth?.call(context) ?? (size.width * 0.70);
    final menuHeight = listHeight != 0 && listHeight < maxMenuHeight ? listHeight : maxMenuHeight;
    final leftOffset = (childOffset.dx + maxMenuWidth) < size.width ? childOffset.dx : (childOffset.dx - maxMenuWidth + childSize.width);
    final topOffset = (childOffset.dy + menuHeight + childSize.height) < size.height - bottomOffsetHeight
        ? childOffset.dy + childSize.height + menuOffset!
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
                  ? BackdropFilter.grouped(
                      filter: ImageFilter.blur(sigmaX: blurSize, sigmaY: blurSize, tileMode: NamidaBlur.kDefaultTileMode),
                      child: Container(
                        color: (blurBackgroundColor).withValues(alpha: backgroundOpacity),
                      ),
                    )
                  : Container(color: Colors.transparent),
            ),
            Positioned(
              top: topOffset - bottomOffsetHeight,
              left: leftOffset + leftOffsetHeight,
              child: TweenAnimationBuilder<double>(
                duration: duration,
                builder: (BuildContext context, double value, Widget? child) {
                  return Transform.scale(
                    scale: value,
                    alignment: Alignment.bottomCenter,
                    child: child,
                  );
                },
                tween: Tween(begin: 0.0, end: 1.0),
                child: Container(
                  constraints: BoxConstraints(maxWidth: maxMenuWidth),
                  height: menuHeight,
                  decoration:
                      menuBoxDecoration ??
                      BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
                        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10, spreadRadius: 1)],
                      ),
                  child:
                      menuWidget ??
                      SuperSmoothListView.builder(
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
                              height: menuItemExtent,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 14),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    item.title,
                                    if (item.trailingIcon != null) ...[item.trailingIcon!],
                                  ],
                                ),
                              ),
                            ),
                          );
                          if (animateMenuItems) {
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
                              child: listItem,
                            );
                          } else {
                            return listItem;
                          }
                        },
                      ),
                ),
              ),
            ),
            // if (displayChildWhileMenuOpen)
            //   Positioned(
            //     top: childOffset.dy,
            //     left: childOffset.dx,
            //     child: TapDetector(
            //       onTap: () => _onDismiss(context),
            //       child: AbsorbPointer(
            //         absorbing: true,
            //         child: SizedBox(
            //           width: childSize!.width,
            //           height: childSize!.height,
            //           child: child,
            //         ),
            //       ),
            //     ),
            //   ),
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
