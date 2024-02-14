import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/ui/widgets/animated_widgets.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';

class ExpandableBox extends StatelessWidget {
  final bool isBarVisible;
  final bool showSearchBox;
  final bool displayloadingIndicator;
  final void Function() onFilterIconTap;
  final String leftText;
  final void Function() onCloseButtonPressed;
  final SortByMenu sortByMenuWidget;
  final CustomTextFiled textField;
  final ChangeGridCountWidget? gridWidget;
  final List<Widget>? leftWidgets;
  final bool enableHero;

  const ExpandableBox({
    super.key,
    required this.isBarVisible,
    required this.showSearchBox,
    this.displayloadingIndicator = false,
    required this.onFilterIconTap,
    required this.leftText,
    required this.onCloseButtonPressed,
    required this.sortByMenuWidget,
    required this.textField,
    this.gridWidget,
    this.leftWidgets,
    required this.enableHero,
  });

  @override
  Widget build(BuildContext context) {
    return NamidaHero(
      enabled: enableHero,
      tag: 'ExpandableBox',
      child: Column(
        children: [
          AnimatedOpacity(
            opacity: isBarVisible ? 1 : 0,
            duration: const Duration(milliseconds: 400),
            child: AnimatedSizedBox(
              duration: const Duration(milliseconds: 400),
              height: isBarVisible ? kExpandableBoxHeight : 0.0,
              animateWidth: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(width: 18.0),
                  Row(
                    children: [
                      if (leftWidgets != null) ...leftWidgets!,
                      Text(
                        leftText,
                        style: context.textTheme.displayMedium,
                      ),
                      if (displayloadingIndicator) ...[const SizedBox(width: 8.0), const LoadingIndicator()]
                    ],
                  ),
                  const Spacer(),
                  if (gridWidget != null) gridWidget!,
                  // Sort By Menu
                  const SizedBox(width: 4.0),
                  sortByMenuWidget,
                  const SizedBox(width: 12.0),
                  SmallIconButton(
                    icon: Broken.filter_search,
                    onTap: onFilterIconTap,
                  ),
                  const SizedBox(width: 12.0),
                ],
              ),
            ),
          ),
          AnimatedOpacity(
            opacity: showSearchBox ? 1 : 0,
            duration: const Duration(milliseconds: 400),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 400),
              child: AnimatedSizedBox(
                duration: const Duration(milliseconds: 400),
                height: showSearchBox ? 58.0 : 0,
                animateWidth: false,
                child: Row(
                  children: [
                    const SizedBox(width: 12.0),
                    Expanded(child: textField),
                    const SizedBox(width: 12.0),
                    NamidaIconButton(
                      onPressed: () {
                        onCloseButtonPressed();
                        ScrollSearchController.inst.unfocusKeyboard();
                      },
                      icon: Broken.close_circle,
                    ),
                    const SizedBox(width: 8.0),
                  ],
                ),
              ),
            ),
          ),
          if (showSearchBox) const SizedBox(height: 8.0)
        ],
      ),
    );
  }
}

class CustomTextFiled extends StatelessWidget {
  final TextEditingController? textFieldController;
  final String textFieldHintText;
  final void Function(String value)? onTextFieldValueChanged;
  final FocusNode? focusNode;
  const CustomTextFiled({
    super.key,
    required this.textFieldController,
    required this.textFieldHintText,
    this.onTextFieldValueChanged,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      focusNode: focusNode ?? ScrollSearchController.inst.focusNode,
      controller: textFieldController,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.0.multipliedRadius),
        ),
        hintText: textFieldHintText,
      ),
      onChanged: onTextFieldValueChanged,
    );
  }
}

class SortByMenu extends StatelessWidget {
  final Widget popupMenuChild;
  final String title;
  final bool isCurrentlyReversed;
  final void Function()? onReverseIconTap;
  const SortByMenu({
    super.key,
    required this.popupMenuChild,
    required this.title,
    this.onReverseIconTap,
    required this.isCurrentlyReversed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TextButton(
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
          ),
          child: Text(title),
          onPressed: () => showMenu(
            color: context.theme.appBarTheme.backgroundColor,
            context: context,
            position: RelativeRect.fromLTRB(context.width, kExpandableBoxHeight + 8.0, 0, 0),
            constraints: BoxConstraints(maxHeight: context.height * 0.6),
            items: [
              PopupMenuItem(
                padding: const EdgeInsets.symmetric(vertical: 0.0),
                child: popupMenuChild,
              ),
            ],
          ),
        ),
        SmallIconButton(
          onTap: onReverseIconTap,
          icon: isCurrentlyReversed ? Broken.arrow_up_3 : Broken.arrow_down_2,
        )
      ],
    );
  }
}

class ChangeGridCountWidget extends StatelessWidget {
  final void Function()? onTap;
  final int currentCount;
  final bool forStaggered;
  const ChangeGridCountWidget({super.key, this.onTap, required this.currentCount, this.forStaggered = false});

  @override
  Widget build(BuildContext context) {
    //  final List<IconData> normal = [Broken.grid_1 /* dummy */, Broken.row_vertical, Broken.grid_2, Broken.grid_8, Broken.grid_1];
    // final List<IconData> staggered = [Broken.grid_1 /* dummy */, Broken.row_vertical, Broken.grid_3, Broken.grid_edit, Broken.grid_1];
    return NamidaInkWell(
      transparentHighlight: true,
      onTap: onTap,
      child: StackedIcon(
        baseIcon: currentCount == 2
            ? forStaggered
                ? Broken.grid_3
                : Broken.grid_2
            : currentCount == 3
                ? Broken.grid_8
                : currentCount == 4
                    ? Broken.grid_1
                    : Broken.row_vertical,
        secondaryText: currentCount.toString(),
        iconSize: 22.0,
      ),
    );
  }
}
