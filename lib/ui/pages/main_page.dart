import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/packages/searchbar_animation.dart';
import 'package:namida/ui/pages/albums_page.dart';
import 'package:namida/ui/pages/artists_page.dart';
import 'package:namida/ui/pages/search_page.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class MainPage extends StatelessWidget {
  final AnimationController animation;
  const MainPage({super.key, required this.animation});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: PreferredSize(
        preferredSize: const Size(0, 56.0),
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Obx(
              () => AppBar(
                toolbarHeight: 56.0 * (1 - animation.value * 0.3),
                leading: NamidaNavigator.inst.currentWidgetStack.length > 1
                    ? NamidaAppBarIcon(
                        icon: Broken.arrow_left_2,
                        onPressed: NamidaNavigator.inst.popPage,
                      )
                    : NamidaAppBarIcon(
                        icon: Broken.menu_1,
                        onPressed: NamidaNavigator.inst.toggleDrawer,
                      ),
                titleSpacing: 0,
                automaticallyImplyLeading: false,
                title: ScrollSearchController.inst.isGlobalSearchMenuShown.value ? ScrollSearchController.inst.searchBarWidget : NamidaNavigator.inst.currentRoute?.toTitle(),
                actions: NamidaNavigator.inst.currentRoute?.toActions(),
              ),
            );
          },
        ),
      ),
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              return Transform.scale(
                scale: 1 - (animation.value * 0.05),
                child: WillPopScope(
                  onWillPop: () async {
                    await NamidaNavigator.inst.popPage();
                    return false;
                  },
                  child: Navigator(
                    key: NamidaNavigator.inst.navKey,
                    restorationScopeId: 'namida',
                    requestFocus: false,
                    observers: [NamidaNavigator.inst.heroController],
                    onGenerateRoute: (settings) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        NamidaNavigator.inst.onFirstLoad();
                      });
                      return GetPageRoute(page: () => const SizedBox());
                    },
                  ),
                ),
              );
            },
          ),

          /// Search Box
          Positioned.fill(
            child: Obx(
              () => AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: ScrollSearchController.inst.isGlobalSearchMenuShown.value ? const SearchPage() : null,
              ),
            ),
          ),

          /// Bottom Glow/Shadow
          Obx(
            () => AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              child: Player.inst.nowPlayingTrack == kDummyTrack && Player.inst.currentQueueYoutube.isEmpty
                  ? const SizedBox(key: Key('emptyglow'))
                  : Container(
                      key: const Key('actualglow'),
                      height: 28.0,
                      transform: Matrix4.translationValues(0, 8.0, 0),
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: context.theme.scaffoldBackgroundColor,
                            spreadRadius: 4.0,
                            blurRadius: 8.0,
                          ),
                        ],
                      ),
                    ),
            ),
          )
        ],
      ),
      bottomNavigationBar: Obx(
        () => !settings.enableBottomNavBar.value
            ? const SizedBox()
            : AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, kBottomNavigationBarHeight * animation.value),
                    child: Obx(
                      () => NavigationBar(
                        animationDuration: const Duration(seconds: 1),
                        elevation: 22,
                        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
                        height: 64.0,
                        onDestinationSelected: (value) async {
                          final tab = value.toEnum();
                          ScrollSearchController.inst.animatePageController(tab);
                        },
                        selectedIndex: settings.selectedLibraryTab.value.toInt(),
                        destinations: [
                          ...settings.libraryTabs.map(
                            (e) => NavigationDestination(
                              icon: Icon(e.toIcon()),
                              label: e.toText(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
      ),
    );
  }
}

class NamidaSearchBar extends StatelessWidget {
  final GlobalKey<SearchBarAnimationState> searchBarKey;
  const NamidaSearchBar({super.key, required this.searchBarKey});

  @override
  Widget build(BuildContext context) {
    return SearchBarAnimation(
      key: searchBarKey,
      isSearchBoxOnRightSide: true,
      textAlignToRight: false,
      durationInMilliSeconds: 300,
      enableKeyboardFocus: true,
      isOriginalAnimation: false,
      textEditingController: ScrollSearchController.inst.searchTextEditingController,
      hintText: lang.SEARCH,
      searchBoxWidth: context.width / 1.2,
      buttonColour: Colors.transparent,
      enableBoxShadow: false,
      buttonShadowColour: Colors.transparent,
      hintTextColour: context.theme.colorScheme.onSurface,
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
        onPressed: ScrollSearchController.inst.resetSearch,
      ),
      onTap: () {
        ScrollSearchController.inst.searchBarKey.currentState?.openCloseSearchBar(forceOpen: true);
        ScrollSearchController.inst.showSearchMenu();
      },
      onPressButton: (isOpen) {
        ScrollSearchController.inst.showSearchMenu(isOpen);
        ScrollSearchController.inst.resetSearch();
      },
      onFieldSubmitted: (val) {
        if (ScrollSearchController.inst.currentSearchType == SearchType.youtube) {
          final latestSearch = ScrollSearchController.inst.ytSearchKey.currentState?.currentSearchText;
          if (latestSearch != val) {
            ScrollSearchController.inst.ytSearchKey.currentState?.fetchSearch(customText: val);
          }
        }
      },
      onChanged: (value) => SearchSortController.inst.searchAll(value),
    );
  }
}

class AlbumSearchResultsPage extends StatelessWidget {
  const AlbumSearchResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AlbumsPage(
      albums: SearchSortController.inst.albumSearchTemp,
      countPerRow: settings.albumGridCount.value,
    );
  }
}

class ArtistSearchResultsPage extends StatelessWidget {
  const ArtistSearchResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ArtistsPage(
      enableHero: false,
      artists: SearchSortController.inst.artistSearchTemp,
      countPerRow: settings.artistGridCount.value,
    );
  }
}
