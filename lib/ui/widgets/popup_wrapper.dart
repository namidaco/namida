import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

part '../../../packages/custom_popup.dart';

class NamidaPopupWrapper extends StatelessWidget {
  final Widget child;
  final PopupMenuController? controller;
  final FutureOr<List<Widget>> Function()? children;
  final FutureOr<List<NamidaPopupItem>> Function()? childrenDefault;
  final bool childrenAfterChildrenDefault;
  final BoxDecoration? contentDecoration;
  final VoidCallback? onTap;
  final VoidCallback? onPop;
  final bool openOnTap;
  final bool openOnLongPress;
  final Listenable? refreshListenable;

  const NamidaPopupWrapper({
    super.key,
    this.controller,
    this.child = const MoreIcon(),
    this.children,
    this.childrenAfterChildrenDefault = true,
    this.childrenDefault,
    this.contentDecoration,
    this.onTap,
    this.onPop,
    this.openOnTap = true,
    this.openOnLongPress = true,
    this.refreshListenable,
  });

  void popMenu({bool handleClosing = true}) {
    onPop?.call();
    NamidaNavigator.inst.popMenu(handleClosing: handleClosing);
  }

  Iterable<Widget> _mapChildren(List<Widget> children) {
    return children.map(
      (e) => ConstrainedBox(
        constraints: BoxConstraints(minHeight: 12.0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: double.infinity,
            child: e,
          ),
        ),
      ),
    );
  }

  Iterable<Widget> _mapChildrenDefault(BuildContext context, List<NamidaPopupItem> childrenDefault) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    return childrenDefault.map(
      (e) {
        final titleStyle = textTheme.displayMedium?.copyWith(color: e.enabled ? null : textTheme.displayMedium?.color?.withValues(alpha: 0.4));
        Widget popupItem = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: Row(
            children: [
              e.secondaryIcon != null
                  ? StackedIcon(
                      baseIcon: e.icon,
                      iconSize: 20.0,
                      secondaryIcon: e.secondaryIcon,
                      baseIconColor: theme.iconTheme.color?.withValues(alpha: 0.8),
                      secondaryIconColor: theme.iconTheme.color?.withValues(alpha: 0.8),
                      secondaryIconSize: 11.0,
                    )
                  : Icon(
                      e.icon,
                      size: 20.0,
                      shadows: [
                        Shadow(
                          blurRadius: 2.0,
                          color: Color(0x10202020),
                        ),
                      ],
                      color: theme.iconTheme.color?.withValues(alpha: 0.8),
                    ),
              const SizedBox(width: 6.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    e.titleBuilder?.call(titleStyle) ??
                        Text(
                          e.title,
                          style: titleStyle,
                        ),
                    if (e.subtitle != '')
                      Text(
                        e.subtitle,
                        style: textTheme.displaySmall,
                        maxLines: e.oneLinedSub ? 1 : null,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (e.trailing != null) const SizedBox(width: 6.0),
              if (e.trailing != null) e.trailing!,
              const SizedBox(width: 2.0),
            ],
          ),
        );

        if (e.enabled) {
          popupItem = NamidaInkWell(
            borderRadius: 8.0,
            enableSecondaryTap: true,
            onTap: () {
              popMenu();
              e.onTap();
            },
            onLongPress: e.onLongPress,
            child: popupItem,
          );
        } else {
          popupItem = Opacity(
            opacity: 0.5,
            child: popupItem,
          );
        }
        return ConstrainedBox(
          constraints: BoxConstraints(minHeight: 40.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: popupItem,
          ),
        );
      },
    );
  }

  FutureOr<Widget> _getMenuContent(BuildContext context) async {
    final maxWidth = context.width * 0.5;
    final maxHeight = context.height * 0.7;
    final items = [
      if (children != null && !childrenAfterChildrenDefault) ..._mapChildren(await children!()),

      // ignore: use_build_context_synchronously
      if (childrenDefault != null) ..._mapChildrenDefault(context, await childrenDefault!()),

      if (children != null && childrenAfterChildrenDefault) ..._mapChildren(await children!()),
    ];
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      ),
      child: NamidaScrollbarWithController(
        showOnStart: true,
        child: (sc) => SmoothSingleChildScrollView(
          controller: sc,
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: items,
            ),
          ),
        ),
      ),
    );
  }

  void showPopupMenu(BuildContext context) async {
    _toCustomPopup(context).show(context);
  }

  CustomPopup _toCustomPopup(BuildContext context) {
    final colorScheme = CurrentColor.inst.color /* ?? context.theme.colorScheme.surface */;
    final scaffoldBgColor = Color.alphaBlend(context.theme.scaffoldBackgroundColor.withValues(alpha: 0.5), context.isDarkMode ? Colors.black : Colors.white);
    return CustomPopup(
      controller: controller,
      openOnTap: openOnTap,
      onTap: onTap,
      openOnLongPress: openOnLongPress,
      contentPadding: EdgeInsets.symmetric(horizontal: 2.0, vertical: 8.0),
      contentRadius: 12.0.multipliedRadius,
      position: PopupPosition.bottom,
      contentDecoration: contentDecoration ??
          BoxDecoration(
            borderRadius: BorderRadius.circular(12.0.multipliedRadius),
            border: Border.all(
              color: colorScheme.withValues(alpha: 0.8),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(scaffoldBgColor.withValues(alpha: 0.90), colorScheme).withValues(alpha: 1.0),
                Color.alphaBlend(scaffoldBgColor.withValues(alpha: 0.65), colorScheme).withValues(alpha: 1.0),
              ],
            ),
          ),
      arrowColor: colorScheme,
      backgroundColor: colorScheme,
      onAfterPopup: () => popMenu(handleClosing: false),
      content: () => _getMenuContent(context),
      refreshListenable: refreshListenable,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _toCustomPopup(context);
  }
}

class NamidaPopupItem {
  final IconData icon;
  final IconData? secondaryIcon;
  final String title;
  final Widget Function(TextStyle? style)? titleBuilder;
  final String subtitle;
  final void Function() onTap;
  final void Function()? onLongPress;
  final bool enabled;
  final bool oneLinedSub;
  final Widget? trailing;

  const NamidaPopupItem({
    required this.icon,
    this.secondaryIcon,
    required this.title,
    this.titleBuilder,
    this.subtitle = '',
    required this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.oneLinedSub = false,
    this.trailing,
  });
}
