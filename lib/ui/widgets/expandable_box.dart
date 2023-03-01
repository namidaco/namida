import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extras.dart';

class ExpandableBox extends StatelessWidget {
  final bool isBarVisible;
  final bool showSearchBox;
  final bool displayloadingIndicator;
  final void Function()? onFilterIconTap;
  final String leftText;
  final void Function() onCloseButtonPressed;
  final SortByMenu sortByMenuWidget;
  final CustomTextFiled textField;
  final ChangeGridCountWidget? gridWidget;
  const ExpandableBox({
    super.key,
    required this.isBarVisible,
    required this.showSearchBox,
    this.displayloadingIndicator = false,
    this.onFilterIconTap,
    required this.leftText,
    required this.onCloseButtonPressed,
    required this.sortByMenuWidget,
    required this.textField,
    this.gridWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedOpacity(
          opacity: isBarVisible ? 1 : 0,
          duration: const Duration(milliseconds: 400),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            height: isBarVisible ? 48.0 : 0.0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(width: 18.0),
                Row(
                  children: [
                    Text(
                      leftText,
                      style: Get.textTheme.displayMedium,
                    ),
                    if (displayloadingIndicator) ...[const SizedBox(width: 8.0), const LoadingIndicator()]
                  ],
                ),
                const Spacer(),
                if (gridWidget != null) gridWidget!,
                // Sort By Menu
                const SizedBox(width: 4),
                sortByMenuWidget,
                const SizedBox(width: 12),
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              height: showSearchBox ? 58.0 : 0,
              child: Row(
                children: [
                  const SizedBox(width: 12.0),
                  Expanded(child: textField),
                  const SizedBox(width: 12.0),
                  IconButton(
                    onPressed: onCloseButtonPressed,
                    icon: const Icon(Broken.close_circle),
                  ),
                  const SizedBox(width: 8.0),
                ],
              ),
            ),
          ),
        ),
        if (showSearchBox) const SizedBox(height: 8.0)
      ],
    );
  }
}

class CustomTextFiled extends StatelessWidget {
  final TextEditingController textFieldController;
  final String textFieldHintText;
  final void Function(String value)? onTextFieldValueChanged;
  const CustomTextFiled({
    super.key,
    required this.textFieldController,
    required this.textFieldHintText,
    this.onTextFieldValueChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
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
          onPressed: () async => await showMenu(
            color: context.theme.appBarTheme.backgroundColor,
            context: context,
            position: RelativeRect.fromLTRB(Get.width, Get.statusBarHeight + 64.0, 20, 0),
            constraints: BoxConstraints(maxHeight: Get.height / 1.5),
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
    return InkWell(
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
      ),
    );
  }
}
