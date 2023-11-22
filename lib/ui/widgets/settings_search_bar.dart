import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/controller/settings_search_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/packages/searchbar_animation.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class NamidaSettingSearchBar extends StatefulWidget {
  final Widget? closedChild;
  const NamidaSettingSearchBar({super.key, this.closedChild});

  @override
  State<NamidaSettingSearchBar> createState() => _NamidaSettingSearchBarState();
}

class _NamidaSettingSearchBarState extends State<NamidaSettingSearchBar> {
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
  }

  @override
  Widget build(BuildContext context) {
    const animationMs = 300;
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: animationMs),
          child: canShowClosedChild && widget.closedChild != null ? widget.closedChild! : null,
        ),
        SearchBarAnimation(
          isSearchBoxOnRightSide: true,
          textAlignToRight: false,
          durationInMilliSeconds: animationMs,
          enableKeyboardFocus: true,
          isOriginalAnimation: false,
          textEditingController: controller,
          hintText: 'Search Settings',
          searchBoxWidth: context.width / 1.2,
          buttonColour: Colors.transparent,
          enableBoxShadow: false,
          buttonShadowColour: Colors.transparent,
          hintTextStyle: (height) => context.textTheme.displaySmall?.copyWith(
            fontSize: 17.0.multipliedFontScale,
            height: height * 1.1,
          ),
          searchBoxColour: context.theme.cardColor.withAlpha(200),
          enteredTextStyle: context.theme.textTheme.displayMedium,
          cursorColour: context.theme.colorScheme.onBackground,
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
            padding: EdgeInsets.zero,
            iconSize: 22,
            onPressed: () {
              controller.clear();
              SettingsSearchController.inst.searchResults.clear();
            },
          ),
          onTap: () {
            _onSearch(isOpen: true);
          },
          onPressButton: (isOpen) {
            _onSearch(isOpen: isOpen);
            setState(() => canShowClosedChild = !isOpen);
          },
          onChanged: SettingsSearchController.inst.onSearchChanged,
        ),
      ],
    );
  }
}
