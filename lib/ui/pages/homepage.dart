// ignore_for_file: no_leading_underscores_for_local_identifiers, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:searchbar_animation/searchbar_animation.dart';

import 'package:namida/controller/playlist_controller.dart';
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
  final Widget? folderChild;
  HomePage({super.key, this.folderChild});

  final PageController _pageController = PageController(initialPage: SettingsController.inst.selectedLibraryTab.value.toInt);

  final TextEditingController searchTextEditingController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          titleSpacing: 0,
          automaticallyImplyLeading: false,
          // title: Obx(() => Text("${Indexer.inst.tracksInfoList.length} ${Language.inst.OF} ${Indexer.inst.allTracksPaths}")),
          title: SearchBarAnimation(
            isSearchBoxOnRightSide: true,
            textAlignToRight: false,
            textEditingController: searchTextEditingController,
            durationInMilliSeconds: 300,
            enableKeyboardFocus: true,
            isOriginalAnimation: false,
            onPressButton: (isOpen) {
              ScrollSearchController.inst.isGlobalSearchMenuShown.value = isOpen;
              Indexer.inst.globalSearchController.value.clear();
              Indexer.inst.searchAll('');
            },
            onChanged: (value) {
              Indexer.inst.searchAll(value);
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
            buttonWidget: Icon(
              Broken.search_normal,
              color: context.theme.appBarTheme.actionsIconTheme?.color,
              size: 22.0,
            ),
            secondaryButtonWidget: Icon(
              Broken.search_status_1,
              color: context.theme.appBarTheme.actionsIconTheme?.color,
              size: 22.0,
            ),
            trailingWidget: GestureDetector(
              onTap: () {
                searchTextEditingController.clear();
                Indexer.inst.searchAll('');
              },
              child: Icon(
                Broken.close_circle,
                color: context.theme.appBarTheme.actionsIconTheme?.color,
                size: 22.0,
              ),
            ),
          ),
          actions: [
            // FilterSortByMenu(),

            IconButton(
              constraints: BoxConstraints(maxWidth: 60, minWidth: 56.0),
              onPressed: () => Get.to(() => SettingsSubPage(
                    title: Language.inst.STATS,
                    child: Stats(),
                  )),
              icon: const Icon(Broken.chart_21),
            ),
            IconButton(
              constraints: BoxConstraints(maxWidth: 60, minWidth: 56.0),
              onPressed: () => Get.to(() => SettingsPage()),
              icon: const Icon(Broken.setting_2),
            ),
          ],
        ),
        body: Stack(
          alignment: Alignment.bottomCenter,
          children: [
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
        /*    bottomNavigationBar: AnimatedBottomNavigationBar(
            // backgroundColor: Color.alphaBlend(context.theme.scaffoldBackgroundColor.withAlpha(240), context.theme.colorScheme.onBackground),
            backgroundColor: Colors.transparent,
            icons: [
              Broken.music_dashboard,
              Broken.music_circle,
              Broken.profile_2user,
              Broken.smileys,
            ],
            activeIndex: SettingsController.inst.selectedLibraryTab.value.toInt,
            gapLocation: GapLocation.center,
            notchSmoothness: NotchSmoothness.smoothEdge,
            blurEffect: false,
            leftCornerRadius: 32,
            rightCornerRadius: 32,
            onTap: (value) {
              SettingsController.inst.save(selectedLibraryTab: value.toEnum);
              _pageController.animateToPage(value, duration: Duration(milliseconds: 400), curve: Curves.easeInOutQuart);
            }, //other params
          ),
        ), */

        bottomNavigationBar: NavigationBar(
          animationDuration: Duration(seconds: 1),
          elevation: 22,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          height: 64.0,
          onDestinationSelected: (value) {
            SettingsController.inst.save(selectedLibraryTab: value.toEnum);
            _pageController.animateToPage(value, duration: Duration(milliseconds: 400), curve: Curves.easeInOutQuart);
            printInfo(info: value.toString());
          },
          selectedIndex: SettingsController.inst.selectedLibraryTab.value.toInt,
          // selectedIndex: SettingsController.inst.libraryTabs.indexOf(SettingsController.inst.selectedLibraryTab.value.toText),
          // selectedIndex: 0,
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
    );
  }
}
