import 'package:flutter/material.dart';

import 'package:namida/controller/settings_search_controller.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/searchbar_animation.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class NamidaSettingSearchBar extends StatefulWidget {
  final Widget? closedChild;
  NamidaSettingSearchBar.keyed({this.closedChild}) : super(key: globalKey);

  static final globalKey = GlobalKey<_NamidaSettingSearchBarState>();

  @override
  State<NamidaSettingSearchBar> createState() => _NamidaSettingSearchBarState();
}

class _NamidaSettingSearchBarState extends State<NamidaSettingSearchBar> {
  void open() {
    _searchBarKey.currentState?.openCloseSearchBar(forceOpen: true);
    _onSearch(isOpen: true);
  }

  void toggle() {
    _searchBarKey.currentState?.openCloseSearchBar();
    final isOpen = _searchBarKey.currentState?.isOpen ?? false;
    _onSearch(isOpen: isOpen);
  }

  static final _searchBarKey = GlobalKey<SearchBarAnimationState>();

  late final TextEditingController controller;
  bool canShowClosedChild = true;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _onSearch({required bool isOpen}) {
    SettingsSearchController.inst.onSearchTap(isOpen: isOpen);
    if (controller.text != '') {
      SettingsSearchController.inst.onSearchChanged(controller.text);
    }
    setState(() => canShowClosedChild = !isOpen);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    const animationMs = 300;
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: animationMs),
          child: canShowClosedChild && widget.closedChild != null ? widget.closedChild! : null,
        ),
        SearchBarAnimation(
          key: _searchBarKey,
          isSearchBoxOnRightSide: true,
          textAlignToRight: false,
          durationInMilliSeconds: animationMs,
          enableKeyboardFocus: true,
          isOriginalAnimation: false,
          textEditingController: controller,
          hintText: "${lang.SEARCH}: ${lang.SETTINGS}",
          searchBoxWidth: context.width / 1.2,
          buttonColour: Colors.transparent,
          enableBoxShadow: false,
          buttonShadowColour: Colors.transparent,
          hintTextStyle: (height) => textTheme.displaySmall?.copyWith(
            fontSize: 17.0,
            height: height * 1.1,
          ),
          searchBoxColour: theme.cardColor.withAlpha(200),
          enteredTextStyle: theme.textTheme.displayMedium,
          cursorColour: theme.colorScheme.onSurface,
          buttonBorderColour: Colors.black45,
          cursorRadius: const Radius.circular(12.0),
          buttonWidget: const IgnorePointer(
            child: NamidaIconButton(
              icon: Broken.search_normal,
            ),
          ),
          secondaryButtonWidget: const IgnorePointer(
            child: NamidaIconButton(
              icon: Broken.search_status_1,
            ),
          ),
          trailingWidget: NamidaIconButton(
            icon: Broken.close_circle,
            padding: const EdgeInsets.all(8.0),
            iconSize: 22,
            onPressed: () {
              controller.clear();
              SettingsSearchController.inst.searchResults.clear();
            },
          ),
          onTap: () => _onSearch(isOpen: true),
          onPressButton: (isOpen) => _onSearch(isOpen: isOpen),
          onChanged: SettingsSearchController.inst.onSearchChanged,
        ),
      ],
    );
  }
}
