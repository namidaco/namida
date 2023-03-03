// ignore_for_file: no_leading_underscores_for_local_identifiers, prefer_const_constructors

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:searchbar_animation/searchbar_animation.dart';

import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/pages/search_page.dart';
import 'package:namida/ui/widgets/settings/stats.dart';
import 'package:namida/main.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/ui/pages/settings_page.dart';

class HomePage extends StatelessWidget {
  final Widget? child;
  final Widget? title;
  final List<Widget>? actions;
  final List<Widget>? actionsToAdd;
  HomePage({super.key, this.child, this.title, this.actions, this.actionsToAdd});

  final PageController _pageController = PageController(initialPage: SettingsController.inst.selectedLibraryTab.value.toInt);

  final TextEditingController searchTextEditingController = Indexer.inst.globalSearchController.value;
  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          leading: Hero(
            tag: 'BACKICON',
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: child != null
                  ? NamidaIconButton(
                      key: ValueKey('arrowleft'),
                      icon: Broken.arrow_left_2,
                      onPressed: () {
                        Get.back();
                        Get.focusScope?.unfocus();
                        ScrollSearchController.inst.isGlobalSearchMenuShown.value = false;
                      },
                    )
                  : NamidaIconButton(
                      key: ValueKey('drawericon'),
                      icon: Broken.menu_1,
                      onPressed: () {
                        // open drawer
                      },
                    ),
            ),
          ),
          titleSpacing: 0,
          automaticallyImplyLeading: false,
          title: title ??
              SearchBarAnimation(
                isSearchBoxOnRightSide: true,
                textAlignToRight: false,
                textEditingController: searchTextEditingController,
                durationInMilliSeconds: 300,
                enableKeyboardFocus: true,
                isOriginalAnimation: false,
                onPressButton: (isOpen) {
                  ScrollSearchController.inst.isGlobalSearchMenuShown.value = isOpen;
                  searchTextEditingController.clear();
                  Indexer.inst.searchAll('');
                },
                onChanged: (value) {
                  Indexer.inst.searchAll(value);
                  if (value != '') {
                    ScrollSearchController.inst.isGlobalSearchMenuShown.value = true;
                  }
                },
                searchBoxWidth: context.width / 1.2, searchBoxHeight: 180,
                buttonColour: Colors.transparent,
                buttonShadowColour: Colors.transparent,
                hintTextColour: context.theme.colorScheme.onSurface,
                searchBoxColour: context.theme.cardColor,
                enteredTextStyle: context.theme.textTheme.displayMedium,
                cursorColour: context.theme.colorScheme.onBackground,
                buttonBorderColour: Colors.black45,
                // hintText: refresh.isCompleted ? Language.instance.SEARCH_WELCOME : Language.instance.COLLECTION_INDEXING_HINT,
                buttonWidget: Hero(
                  tag: 'SEARCHOPEN',
                  child: IgnorePointer(
                    child: NamidaIconButton(
                      icon: Broken.search_normal,
                      onPressed: () {},
                    ),
                  ),
                ),
                secondaryButtonWidget: Hero(
                  tag: 'SEARCHCLOSE',
                  child: IgnorePointer(
                    child: NamidaIconButton(
                      icon: Broken.search_status_1,
                      onPressed: () {},
                    ),
                  ),
                ),
                trailingWidget: NamidaIconButton(
                  icon: Broken.close_circle,
                  padding: EdgeInsets.zero,
                  iconSize: 22,
                  onPressed: () {
                    searchTextEditingController.clear();
                    Indexer.inst.searchAll('');
                  },
                ),
              ),
          actions: actions ??
              [
                Hero(
                  tag: 'STATICON',
                  child: NamidaIconButton(
                    icon: Broken.chart_21,
                    onPressed: () => Get.to(() => SettingsSubPage(
                          title: Language.inst.STATS,
                          child: Stats(),
                        )),
                  ),
                ),
                Hero(
                  tag: 'SETTINGICON',
                  child: NamidaIconButton(
                    icon: Broken.setting_2,
                    onPressed: () => Get.to(() => SettingsPage()),
                  ),
                ),
                if (actionsToAdd != null) ...actionsToAdd!,
              ],
        ),
        body: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            child ??
                PageView(
                  controller: _pageController,
                  onPageChanged: (page) {
                    SettingsController.inst.save(selectedLibraryTab: page.toEnum);
                    printInfo(info: page.toString());
                  },
                  children: SettingsController.inst.libraryTabs
                      .asMap()
                      .entries
                      .map(
                        (e) => KeepAliveWrapper(
                          child: e.value.toEnum.toWidget,
                        ),
                      )
                      .toList(),
                ),

            // Search Box
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: 400),
                child: ScrollSearchController.inst.isGlobalSearchMenuShown.value ? SearchPage() : null,
              ),
            ),
          ],
        ),
        bottomNavigationBar: Hero(
          tag: "NAVBAR",
          child: NavigationBar(
            animationDuration: Duration(seconds: 1),
            elevation: 22,
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            height: 64.0,
            onDestinationSelected: (value) async {
              SettingsController.inst.save(selectedLibraryTab: value.toEnum);
              if (child != null) {
                Get.offAll(() => MainPageWrapper());
              } else {
                _pageController.animateToPage(value, duration: Duration(milliseconds: 400), curve: Curves.easeInOutQuart);
              }
              ScrollSearchController.inst.isGlobalSearchMenuShown.value = false;
              searchTextEditingController.clear();
              Indexer.inst.searchAll('');
              printInfo(info: value.toEnum.toText);
            },
            selectedIndex: SettingsController.inst.selectedLibraryTab.value.toInt,
            destinations: SettingsController.inst.libraryTabs
                .asMap()
                .entries
                .map(
                  (e) => NavigationDestination(
                    icon: Icon(e.value.toEnum.toIcon),
                    label: e.value.toEnum.toText,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}
