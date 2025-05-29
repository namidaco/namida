import 'package:flutter/material.dart';

import 'package:namida/class/count_per_row.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
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
  void didUpdateWidget(covariant ExpandableBox oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.showSearchBox != _latestShowSearchBox) {
      _latestShowSearchBox = widget.showSearchBox;
      _controller.animateTo(widget.showSearchBox ? 1.0 : 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leftWidgets = widget.leftWidgets;
    return NamidaHero(
      enabled: widget.enableHero,
      tag: 'ExpandableBox',
      child: LayoutWidthProvider(
        builder: (context, maxWidth) {
          final partWidthLeftTextOrWidgets = maxWidth * 0.4;
          final partWidthRightActions = maxWidth - partWidthLeftTextOrWidgets;
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
                        Expanded(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: partWidthLeftTextOrWidgets),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ...?leftWidgets,
                                  if (widget.leftText.isNotEmpty)
                                    Text(
                                      widget.leftText,
                                      style: context.textTheme.displayMedium,
                                      softWrap: false,
                                      overflow: TextOverflow.fade,
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
                          constraints: BoxConstraints(maxWidth: partWidthRightActions),
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
              FadeIgnoreTransition(
                completelyKillWhenPossible: true,
                opacity: _controller,
                child: AnimatedBuilder(
                  animation: _controller,
                  child: Row(
                    children: [
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: widget.textField(),
                      ),
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
  final LibraryTab tab;
  final bool forStaggered;

  const ChangeGridCountWidget({
    super.key,
    required this.tab,
    this.forStaggered = false,
  });

  IconData _resolveIcon(int count) => switch (count) {
        1 => Broken.row_vertical,
        2 => forStaggered ? Broken.grid_3 : Broken.grid_2,
        3 => Broken.grid_8,
        4 => Broken.grid_1,
        < 0 => Broken.autobrightness,
        _ => Broken.grid_1,
      };

  void _onTap(CountPerRow? count) {
    if (count != null) {
      if (count.rawValue != settings.mediaGridCounts.value.get(tab).rawValue) {
        final newCount = ScrollSearchController.inst.animateChangingGridSize(tab, count);
        settings.updateMediaGridCounts(tab, newCount);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // final List<IconData> normal = [Broken.grid_1 /* dummy */, Broken.row_vertical, Broken.grid_2, Broken.grid_8, Broken.grid_1];
    // final List<IconData> staggered = [Broken.grid_1 /* dummy */, Broken.row_vertical, Broken.grid_3, Broken.grid_edit, Broken.grid_1];
    return ObxO(
      rx: settings.mediaGridCounts,
      builder: (context, mediaGridCounts) {
        final currentCount = mediaGridCounts.get(tab);
        final count = currentCount.resolve(context);
        String? secondaryText;
        IconData? secondaryIcon;
        if (currentCount.isAuto) {
          secondaryIcon = Broken.autobrightness;
        } else {
          secondaryText = "$count";
        }

        return NamidaPopupWrapper(
          childrenDefault: () {
            final autoCountPerRow = CountPerRow.autoForTab(tab);
            return [
              NamidaPopupItem(
                icon: _resolveIcon(autoCountPerRow.rawValue),
                title: lang.AUTO,
                onTap: () => _onTap(autoCountPerRow),
              ),
              ...CountPerRow.getAvailableOptions().map(
                (e) => NamidaPopupItem(
                  icon: _resolveIcon(e.rawValue),
                  title: '${e.rawValue}',
                  onTap: () => _onTap(e),
                ),
              ),
            ];
          },
          child: NamidaInkWell(
            transparentHighlight: true,
            onTap: () => _onTap(currentCount.getNext()),
            child: StackedIcon(
              baseIcon: _resolveIcon(count),
              secondaryText: secondaryText,
              secondaryIcon: secondaryIcon,
              iconSize: 22.0,
            ),
          ),
        );
      },
    );
  }
}
