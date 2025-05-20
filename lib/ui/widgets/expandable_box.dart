import 'package:flutter/material.dart';

import 'package:namida/class/count_per_row.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';

class ExpandableBox extends StatefulWidget {
  final bool isBarVisible;
  final bool showSearchBox;
  final bool displayloadingIndicator;
  final void Function() onFilterIconTap;
  final String leftText;
  final void Function() onCloseButtonPressed;
  final SortByMenu sortByMenuWidget;
  final CustomTextFiled Function() textField;
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
  State<ExpandableBox> createState() => _ExpandableBoxState();
}

class _ExpandableBoxState extends State<ExpandableBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late bool _latestShowSearchBox;

  @override
  void initState() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: widget.showSearchBox ? 1.0 : 0.0,
    );
    _latestShowSearchBox = widget.showSearchBox;
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textfieldWidget = widget.textField();
    if (widget.showSearchBox != _latestShowSearchBox) {
      _latestShowSearchBox = widget.showSearchBox;
      _controller.animateTo(widget.showSearchBox ? 1.0 : 0.0);
    }

    return NamidaHero(
      enabled: widget.enableHero,
      tag: 'ExpandableBox',
      child: LayoutWidthProvider(
        builder: (context, maxWidth) {
          final displayLeftWidgets = widget.leftWidgets != null;
          final partWidth1 = displayLeftWidgets ? maxWidth * 0.2 : 0.0;
          final partWidth2 = maxWidth * 0.4 - (partWidth1 / 2);
          final partWidth3 = maxWidth * 0.6 - (partWidth1 / 2);
          return Column(
            children: [
              AnimatedOpacity(
                opacity: widget.isBarVisible ? 1 : 0,
                duration: const Duration(milliseconds: 400),
                child: AnimatedShow(
                  duration: const Duration(milliseconds: 400),
                  show: widget.isBarVisible,
                  child: SizedBox(
                    width: maxWidth,
                    height: kExpandableBoxHeight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(width: 18.0),
                        if (displayLeftWidgets)
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: partWidth1),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: widget.leftWidgets!,
                              ),
                            ),
                          ),
                        Expanded(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: partWidth2),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.leftText,
                                    style: context.textTheme.displayMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (widget.displayloadingIndicator) ...[
                                    const SizedBox(width: 8.0),
                                    const LoadingIndicator(),
                                  ]
                                ],
                              ),
                            ),
                          ),
                        ),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: partWidth3),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (widget.gridWidget != null) widget.gridWidget!,
                                const SizedBox(width: 4.0),
                                widget.sortByMenuWidget,
                                const SizedBox(width: 6.0),
                                NamidaIconButton(
                                  horizontalPadding: 6.0,
                                  icon: Broken.filter_search,
                                  onPressed: widget.onFilterIconTap,
                                  iconSize: 20.0,
                                ),
                                const SizedBox(width: 6.0),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              FadeTransition(
                opacity: _controller,
                child: AnimatedBuilder(
                  animation: _controller,
                  child: Row(
                    children: [
                      const SizedBox(width: 12.0),
                      Expanded(child: textfieldWidget),
                      const SizedBox(width: 12.0),
                      NamidaIconButton(
                        onPressed: () {
                          widget.onCloseButtonPressed();
                          ScrollSearchController.inst.unfocusKeyboard();
                        },
                        icon: Broken.close_circle,
                      ),
                      const SizedBox(width: 8.0),
                    ],
                  ),
                  builder: (context, child) {
                    return SizedBox(
                      height: _controller.value * 58.0,
                      child: child!,
                    );
                  },
                ),
              ),
              if (widget.showSearchBox) const SizedBox(height: 8.0)
            ],
          );
        },
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
  final Widget Function() popupMenuChild;
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
          child: NamidaButtonText(title, style: const TextStyle(fontSize: 14.5)),
          onPressed: () => showMenu(
            color: context.theme.appBarTheme.backgroundColor,
            context: context,
            position: RelativeRect.fromLTRB(context.width, kExpandableBoxHeight + 8.0, 0, 0),
            constraints: BoxConstraints(maxHeight: context.height * 0.6),
            items: [
              PopupMenuItem(
                padding: const EdgeInsets.symmetric(vertical: 0.0),
                child: popupMenuChild(),
              ),
            ],
          ),
        ),
        NamidaIconButton(
          horizontalPadding: 0.0,
          icon: isCurrentlyReversed ? Broken.arrow_up_3 : Broken.arrow_down_2,
          iconSize: 20.0,
          onPressed: onReverseIconTap,
        )
      ],
    );
  }
}

class ChangeGridCountWidget extends StatelessWidget {
  final void Function(CountPerRow countPerRow) onTap;
  final CountPerRow currentCount;
  final bool forStaggered;
  const ChangeGridCountWidget({
    super.key,
    required this.onTap,
    required this.currentCount,
    this.forStaggered = false,
  });

  IconData _resolveIcon(int count) => switch (count) {
        1 => Broken.row_vertical,
        2 => forStaggered ? Broken.grid_3 : Broken.grid_2,
        3 => Broken.grid_8,
        4 => Broken.grid_1,
        _ => Broken.grid_1,
      };

  @override
  Widget build(BuildContext context) {
    //  final List<IconData> normal = [Broken.grid_1 /* dummy */, Broken.row_vertical, Broken.grid_2, Broken.grid_8, Broken.grid_1];
    // final List<IconData> staggered = [Broken.grid_1 /* dummy */, Broken.row_vertical, Broken.grid_3, Broken.grid_edit, Broken.grid_1];
    final count = currentCount.resolve();
    final text = "$count";
    // final text = count == currentCount.rawValue ? "$count" : "${count}x";
    return NamidaPopupWrapper(
      childrenDefault: () => CountPerRow.getAvailableOptions()
          .map(
            (e) => NamidaPopupItem(
              icon: _resolveIcon(e.rawValue),
              title: '${e.rawValue}',
              onTap: () => onTap(e),
            ),
          )
          .toList(),
      child: NamidaInkWell(
        transparentHighlight: true,
        onTap: () => onTap(currentCount.getNext()),
        child: StackedIcon(
          baseIcon: _resolveIcon(count),
          secondaryText: text,
          iconSize: 22.0,
        ),
      ),
    );
  }
}
