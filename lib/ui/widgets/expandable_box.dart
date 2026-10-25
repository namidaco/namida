import 'package:flutter/material.dart';

import 'package:namida/class/count_per_row.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';

class ExpandableBox extends StatefulWidget {
  final bool isBarVisible;
  final bool? initialShowSearchBox;
  final bool displayloadingIndicator;
  final bool Function(bool newShow) onSearchBoxVisibilityChange;
  final String leftText;
  final IconData? leftTextIcon;
  final void Function()? onLeftTextTap;
  final void Function() onCloseButtonPressed;
  final SortByMenu? sortByMenuWidget;
  final CustomTextField textField;
  final bool enableSearch;
  final ChangeGridCountWidget? gridWidget;
  final List<Widget>? leftWidgets;
  final void Function()? onFilterIconLongPress;
  final bool enableHero;

  const ExpandableBox({
    super.key,
    required this.isBarVisible,
    this.initialShowSearchBox,
    this.displayloadingIndicator = false,
    required this.onSearchBoxVisibilityChange,
    required this.leftText,
    this.leftTextIcon,
    this.onLeftTextTap,
    required this.onCloseButtonPressed,
    required this.sortByMenuWidget,
    required this.textField,
    this.enableSearch = true,
    this.gridWidget,
    this.leftWidgets,
    this.onFilterIconLongPress,
    required this.enableHero,
  });

  @override
  State<ExpandableBox> createState() => _ExpandableBoxState();
}

class _ExpandableBoxState extends State<ExpandableBox> with SingleTickerProviderStateMixin {
  final _canShowSearchBoxRx = false.obs;

  @override
  void initState() {
    try {
      _canShowSearchBoxRx.value = widget.initialShowSearchBox ?? widget.textField.textFieldController?.text.isNotEmpty == true;
    } catch (_) {
      // -- text field disposed
      _canShowSearchBoxRx.value = false;
    }
    super.initState();
  }

  @override
  void dispose() {
    _canShowSearchBoxRx.close();
    super.dispose();
  }

  void _onFilterIconTap([bool? newShow]) {
    newShow ??= !_canShowSearchBoxRx.value;
    final accept = widget.onSearchBoxVisibilityChange(newShow);
    if (accept) {
      _canShowSearchBoxRx.value = newShow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final leftWidgets = widget.leftWidgets;
    final sortByMenuWidget = widget.sortByMenuWidget;
    final textFieldRow = Row(
      children: [
        const SizedBox(width: 12.0),
        Expanded(
          child: widget.textField,
        ),
        const SizedBox(width: 12.0),
        NamidaIconButton(
          onPressed: () {
            widget.onCloseButtonPressed();
            _onFilterIconTap(false);
            ScrollSearchController.inst.unfocusKeyboard();
          },
          icon: Broken.close_circle,
        ),
        const SizedBox(width: 8.0),
      ],
    );
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
                        const SizedBox(width: 12.0),
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
                                    ExpandableBoxChip(
                                      icon: widget.leftTextIcon,
                                      label: widget.leftText,
                                      showArrow: false,
                                      onTap: widget.onLeftTextTap,
                                    ),
                                  if (widget.displayloadingIndicator) ...[
                                    const SizedBox(width: 8.0),
                                    const LoadingIndicator(),
                                  ],
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
                                if (widget.gridWidget != null) ...[
                                  widget.gridWidget!,
                                  const SizedBox(width: 2.0),
                                ],
                                const SizedBox(width: 4.0),
                                if (sortByMenuWidget != null) ...[
                                  sortByMenuWidget,
                                  const SizedBox(width: 4.0),
                                ],
                                if (widget.enableSearch)
                                  NamidaIconButton(
                                    horizontalPadding: 6.0,
                                    icon: Broken.filter_search,
                                    onPressed: _onFilterIconTap,
                                    onLongPress: widget.onFilterIconLongPress,
                                    iconSize: 20.0,
                                  ),
                                const SizedBox(width: 8.0),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (widget.enableSearch)
                ObxO(
                  rx: _canShowSearchBoxRx,
                  builder: (context, canShowSearchBox) => AnimatedShow(
                    duration: const Duration(milliseconds: 250),
                    show: canShowSearchBox,
                    child: ExcludeFocusTraversal(
                      excluding: !canShowSearchBox,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: textFieldRow,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class CustomTextField extends StatefulWidget {
  final TextEditingController? textFieldController;
  final String textFieldHintText;
  final void Function(String value)? onTextFieldValueChanged;
  final FocusNode? focusNode;
  const CustomTextField({
    super.key,
    required this.textFieldController,
    required this.textFieldHintText,
    this.onTextFieldValueChanged,
    this.focusNode,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  FocusNode? _internalFocusNode;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      final node = _internalFocusNode = FocusNode();
      ScrollSearchController.inst.registerSearchFocusNode(node);
    }
  }

  @override
  void dispose() {
    final node = _internalFocusNode;
    if (node != null) {
      ScrollSearchController.inst.unregisterSearchFocusNode(node);
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      focusNode: widget.focusNode ?? _internalFocusNode,
      controller: widget.textFieldController,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
        constraints: const BoxConstraints(maxHeight: 42.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.0.multipliedRadius),
        ),
        hintText: widget.textFieldHintText,
      ),
      onChanged: widget.onTextFieldValueChanged,
    );
  }
}

mixin SortByMenuBase {
  List<Widget> children(BuildContext context);
}

class SortByMenuCustom with SortByMenuBase {
  final List<Widget> Function(BuildContext context) childrenCallback;
  const SortByMenuCustom({required this.childrenCallback});

  @override
  List<Widget> children(BuildContext context) => childrenCallback(context);
}

class SortByMenu extends StatelessWidget {
  final SortByMenuBase? popupMenuChild;
  final String title;
  final bool isCurrentlyReversed;
  final void Function()? onSortTap;
  final void Function()? onReverseIconTap;

  const SortByMenu({
    super.key,
    required this.popupMenuChild,
    required this.title,
    this.onSortTap,
    this.onReverseIconTap,
    required this.isCurrentlyReversed,
  });

  static const _kHeight = 31.0;

  @override
  Widget build(BuildContext context) {
    final nColors = NColorsData.targetOf(context);
    final palette = NamidaButton.resolvePalette(nColors, colors: NamidaButtonColors.dimmed);
    final borderRadius = Radius.circular(20.0.multipliedRadius);
    final sortBorderRadius = BorderRadius.horizontal(left: borderRadius);
    final reverseBorderRadius = BorderRadius.horizontal(right: borderRadius);
    final textStyle = NText.medium.of(context).copyWith(color: palette.foreground, fontSize: 0.95 * 15.0);
    final onSortTap =
        this.onSortTap ??
        () => NamidaPopupWrapper(
          children: () => popupMenuChild?.children(context) ?? [],
        ).showPopupMenu(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.bg,
          border: Border.all(width: 0.5, color: palette.border),
          borderRadius: BorderRadius.all(borderRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            NamidaInkWell(
              decoration: BoxDecoration(borderRadius: sortBorderRadius),
              height: _kHeight,
              padding: const EdgeInsets.only(left: 13.0, right: 8.0, top: 7.0, bottom: 7.0),
              onTap: onSortTap,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    style: textStyle,
                    softWrap: false,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 0.5,
              height: 16.0,
              child: ColoredBox(
                color: palette.border,
              ),
            ),
            NamidaInkWell(
              decoration: BoxDecoration(borderRadius: reverseBorderRadius),
              height: _kHeight,
              padding: const EdgeInsets.only(left: 6.0, right: 10.0),
              onTap: onReverseIconTap,
              child: Center(
                child: Icon(
                  isCurrentlyReversed ? Broken.arrow_up_3 : Broken.arrow_down_2,
                  size: 16.0,
                  color: palette.foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExpandableBoxChip extends StatelessWidget {
  final IconData? icon;
  final String label;
  final bool showArrow;
  final VoidCallback? onTap;

  const ExpandableBoxChip({
    super.key,
    required this.icon,
    required this.label,
    required this.showArrow,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return NamidaInkWell(
      bgColor: const NColors(.secondary, opacity: 0.12),
      borderRadius: 10.0,
      padding: showArrow ? const EdgeInsets.only(left: 8.0, right: 6.0, top: 7.0, bottom: 7.0) : const EdgeInsets.symmetric(horizontal: 8.0, vertical: 7.0),
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            NIcon(
              icon,
              size: 16.0,
            ),
            const SizedBox(
              width: 5.0,
            ),
          ],
          NamidaText(
            label,
            style: NText.medium,
            softWrap: false,
          ),
          if (showArrow) ...[
            const SizedBox(
              width: 3.0,
            ),
            const NIcon(
              Broken.arrow_right_3,
              size: 11.0,
            ),
          ],
        ],
      ),
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
        settings.mediaGridCounts.update((counts) => counts[tab] = newCount);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: settings.mediaGridCounts,
      builder: (context, mediaGridCounts) {
        final currentCount = mediaGridCounts.get(tab);
        final count = currentCount.resolve(context);
        final isAuto = currentCount.isAuto;
        final secondaryIcon = isAuto ? Broken.autobrightness : null;
        final countBadge = isAuto
            ? null
            : NamidaText(
                "$count",
                style: const NText(.small, size: .s11p5),
                color: NColors.secondary,
              );
        final baseIcon = _resolveIcon(count);

        return NamidaPopupWrapper(
          openOnTap: currentCount.getNext() == null,
          childrenDefault: () {
            final autoCountPerRow = CountPerRow.autoForTab(tab);
            return [
              NamidaPopupItem(
                icon: _resolveIcon(autoCountPerRow.rawValue),
                title: lang.auto,
                selected: currentCount.rawValue == autoCountPerRow.rawValue,
                onTap: () => _onTap(autoCountPerRow),
              ),
              ...CountPerRow.getAvailableOptions().map(
                (e) => NamidaPopupItem(
                  icon: _resolveIcon(e.rawValue),
                  title: '${e.rawValue}',
                  selected: currentCount.rawValue == e.rawValue,
                  onTap: () => _onTap(e),
                ),
              ),
            ];
          },
          onTap: () => _onTap(currentCount.getNext()),
          child: StackedIcon(
            baseIcon: baseIcon,
            secondaryIcon: secondaryIcon,
            smallChild: countBadge,
            baseIconColor: NColors.secondary,
            secondaryIconColor: NColors.secondary,
            iconSize: 19.0,
            secondaryIconSize: 12.0,
          ),
        );
      },
    );
  }
}

class ExpandableBoxColumn extends StatelessWidget {
  final LibraryTab tab;
  final Widget header;
  final Widget page;

  const ExpandableBoxColumn({
    super.key,
    required this.tab,
    required this.header,
    required this.page,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        header,
        Expanded(
          child: page,
        ),
      ],
    );
  }
}

class ExpandableBoxEmptyAnimatedPadding extends StatelessWidget {
  final LibraryTab tab;
  const ExpandableBoxEmptyAnimatedPadding({super.key, required this.tab});

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: tab.isBarVisible,
      builder: (context, visible) => AnimatedShow(
        show: !visible,
        duration: const Duration(milliseconds: 400),
        child: const SizedBox(height: kExpandableBoxHeight),
      ),
    );
  }
}
