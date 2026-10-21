import 'package:flutter/material.dart';

import 'package:namida/controller/settings_search_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/searchbar_animation.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/eggs/eggs.dart';

class NamidaSettingSearchBar extends StatefulWidget {
  final Widget? closedChild;
  const NamidaSettingSearchBar({super.key, this.closedChild});

  static _NamidaSettingSearchBarState? _activeState;

  static void open() => _activeState?.open();
  static void toggle() => _activeState?.toggle();

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

  final _searchBarKey = GlobalKey<SearchBarAnimationState>();

  late final TextEditingController controller;
  bool canShowClosedChild = true;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
    NamidaSettingSearchBar._activeState = this;
  }

  @override
  void dispose() {
    if (NamidaSettingSearchBar._activeState == this) NamidaSettingSearchBar._activeState = null;
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
    const animationMs = 300;
    final trailingWidget = NamidaIconButton(
      padding: const EdgeInsets.all(8.0 + 2.0),
      icon: Broken.eraser,
      iconSize: 18.0,
      iconColor: NColors.defaultIcon(),
      onPressed: () {
        controller.clear();
        SettingsSearchController.inst.onSearchChanged('');
      },
    );
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        CustomAnimatedSwitcher(
          duration: const Duration(milliseconds: animationMs),
          child: canShowClosedChild && widget.closedChild != null ? widget.closedChild! : null,
        ),
        NBuilder(
          builder: (context, colors) => SearchBarAnimation(
            key: _searchBarKey,
            isSearchBoxOnRightSide: true,
            textAlignToRight: false,
            durationInMilliSeconds: animationMs,
            enableKeyboardFocus: true,
            isOriginalAnimation: false,
            textEditingController: controller,
            hintText: "${lang.search}: ${lang.settings}",
            searchBoxWidth: context.width / 1.2,
            buttonColour: Colors.transparent,
            enableBoxShadow: false,
            buttonShadowColour: Colors.transparent,
            hintTextStyle: (height) => NText.small
                .of(context)
                .copyWith(
                  fontSize: 17.0,
                  height: height * 1.1,
                ),
            searchBoxColour: colors.card.withOpacityExt(0.78),
            enteredTextStyle: NText.medium.of(context),
            cursorColour: colors.onSurface,
            buttonBorderColour: Colors.black45,
            cursorRadius: const Radius.circular(12.0),
            buttonWidget: const IgnorePointer(
              child: NamidaIconButton(
                icon: Broken.shield_search,
              ),
            ),
            secondaryButtonWidget: const IgnorePointer(
              child: NamidaIconButton(
                icon: Broken.shield_slash,
              ),
            ),
            trailingWidget: trailingWidget,
            onTap: () => _onSearch(isOpen: true),
            onPressButton: (isOpen) => _onSearch(isOpen: isOpen),
            onChanged: SettingsSearchController.inst.onSearchChanged,
            onFieldSubmitted: EggHunt.onSettingsSearchSubmitted,
          ),
        ),
      ],
    );
  }
}
