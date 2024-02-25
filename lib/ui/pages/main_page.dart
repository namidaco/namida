import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/controller/clipboard_controller.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/selected_tracks_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/settings_search_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/main.dart';
import 'package:namida/packages/searchbar_animation.dart';
import 'package:namida/ui/pages/albums_page.dart';
import 'package:namida/ui/pages/artists_page.dart';
import 'package:namida/ui/pages/search_page.dart';
import 'package:namida/ui/pages/settings_search_page.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_local_search_controller.dart';

class MainPage extends StatelessWidget {
  final AnimationController animation;
  const MainPage({super.key, required this.animation});

  Widget appbar(double animationMultiplier) => Obx(
        () => AppBar(
          toolbarHeight: 56.0 * animationMultiplier,
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

  @override
  Widget build(BuildContext context) {
    final main = WillPopScope(
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
    );

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: PreferredSize(
        preferredSize: const Size(0, 56.0),
        child: Obx(
          () {
            final isReallyHidden = animation.value > 1; // queue
            return isReallyHidden || !settings.enableMiniplayerParallaxEffect.value
                ? appbar(1.0)
                : AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) => appbar((1 - animation.value * 0.3)),
                  );
          },
        ),
      ),
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Obx(() {
            final isReallyHidden = animation.value > 1; // queue
            return isReallyHidden || !settings.enableMiniplayerParallaxEffect.value
                ? main
                : AnimatedBuilder(
                    animation: animation,
                    child: main,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 1 - (animation.value * 0.05),
                        child: child,
                      );
                    },
                  );
          }),

          /// Search Box
          Positioned.fill(
            child: Obx(
              () => AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: ScrollSearchController.inst.isGlobalSearchMenuShown.value ? const SearchPage() : null,
              ),
            ),
          ),

          // -- Settings Search Box
          Positioned.fill(
            child: Obx(
              () => AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: SettingsSearchController.inst.canShowSearch ? const SettingsSearchPage() : null,
              ),
            ),
          ),

          Obx(
            () {
              final shouldHide = Dimensions.inst.shouldHideFAB;
              return AnimatedPositioned(
                key: const Key('fab_active'),
                right: 12.0,
                bottom: Dimensions.inst.globalBottomPaddingEffective,
                duration: const Duration(milliseconds: 300),
                curve: Curves.fastEaseInToSlowEaseOut,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: shouldHide
                      ? const SizedBox(key: Key('fab_dummy'))
                      : FloatingActionButton(
                          tooltip: ScrollSearchController.inst.isGlobalSearchMenuShown.value ? lang.CLEAR : settings.floatingActionButton.value.toText(),
                          backgroundColor: Color.alphaBlend(CurrentColor.inst.currentColorScheme.withOpacity(0.7), context.theme.cardColor),
                          onPressed: () {
                            final fab = settings.floatingActionButton.value;
                            final forceSearch = ScrollSearchController.inst.isGlobalSearchMenuShown.value;
                            if (forceSearch || fab == FABType.search) {
                              ScrollSearchController.inst.toggleSearchMenu();
                              ScrollSearchController.inst.searchBarKey.currentState?.openCloseSearchBar();
                            } else if (fab == FABType.shuffle || fab == FABType.play) {
                              Player.inst.playOrPause(0, SelectedTracksController.inst.currentAllTracks, QueueSource.allTracks, shuffle: fab == FABType.shuffle);
                            }
                          },
                          child: Icon(
                            ScrollSearchController.inst.isGlobalSearchMenuShown.value ? Broken.search_status_1 : settings.floatingActionButton.value.toIcon(),
                            color: const Color.fromRGBO(255, 255, 255, 0.8),
                          ),
                        ),
                ),
              );
            },
          ),

          /// Bottom Glow/Shadow
          Obx(
            () => AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              child: Player.inst.currentQueue.isNotEmpty
                  ? Container(
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
                    )
                  : const SizedBox(key: Key('emptyglow')),
            ),
          )
        ],
      ),
      bottomNavigationBar: Obx(
        () => !settings.enableBottomNavBar.value
            ? const SizedBox()
            : AnimatedBuilder(
                animation: animation,
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
                    selectedIndex: settings.selectedLibraryTab.value.toInt().toIf(0, -1),
                    destinations: [
                      ...settings.libraryTabs.map(
                        (e) => NavigationDestination(
                          icon: Icon(e.toIcon()),
                          label: settings.libraryTabs.length >= 7 ? '' : e.toText(),
                        ),
                      ),
                    ],
                  ),
                ),
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, (kBottomNavigationBarHeight * animation.value).withMinimum(0)),
                    child: child,
                  );
                }),
      ),
    );
  }
}

class NamidaSearchBar extends StatelessWidget {
  final GlobalKey<SearchBarAnimationState> searchBarKey;
  const NamidaSearchBar({super.key, required this.searchBarKey});

  void _onSubmitted(String val) {
    final ytPlaylistLink = NamidaLinkRegex.youtubePlaylistsLinkRegex.firstMatch(val)?[0];
    if (ytPlaylistLink != null && ytPlaylistLink != '') {
      OnYoutubeLinkOpenAction.alwaysAsk.executePlaylist(ytPlaylistLink, context: rootContext);
      return;
    }

    final ytlink = NamidaLinkRegex.youtubeLinkRegex.firstMatch(val)?[0];
    final ytID = ytlink?.getYoutubeID;

    if (ytlink != null && ytID != null && ytID != '') {
      ScrollSearchController.inst.searchTextEditingController.clear();
      Player.inst.playOrPause(0, [YoutubeID(id: ytlink.getYoutubeID, playlistID: null)], QueueSource.others);
    } else if (ScrollSearchController.inst.currentSearchType.value == SearchType.youtube) {
      ScrollSearchController.inst.ytSearchKey.currentState?.fetchSearch(customText: val);
    }
  }

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
      hintText: /*  ScrollSearchController.inst.currentSearchType.value == SearchType.youtube ? lang.SEARCH_YOUTUBE : */ lang.SEARCH,
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
      buttonWidgetSmallPadding: 24.0 + 8.0,
      buttonWidgetSmall: Obx(
        () {
          final clipboard = ClipboardController.inst.clipboardText;
          final alreadyPasted = clipboard == ClipboardController.inst.lastCopyUsed;
          final empty = ClipboardController.inst.textInControllerEmpty;

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: clipboard != '' && (empty || !alreadyPasted)
                ? NamidaIconButton(
                    horizontalPadding: 0,
                    icon: Broken.clipboard_tick,
                    iconSize: 20.0,
                    onPressed: () {
                      ClipboardController.inst.setLastPasted(clipboard);
                      final c = ScrollSearchController.inst.searchTextEditingController;
                      c.text = "${c.text} $clipboard";
                      c.selection = TextSelection.fromPosition(TextPosition(offset: c.text.length));
                      _onSubmitted(clipboard);
                      ClipboardController.inst.updateTextInControllerEmpty(false);
                    },
                  )
                : const SizedBox(),
          );
        },
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
        ClipboardController.inst.updateTextInControllerEmpty(true);
        if (isOpen) {
          SearchSortController.inst.prepareResources();
          ClipboardController.inst.setClipboardMonitoringStatus(settings.enableClipboardMonitoring.value);
        } else {
          SearchSortController.inst.disposeResources();
          YTLocalSearchController.inst.cleanResources();
          ClipboardController.inst.setClipboardMonitoringStatus(false);
        }
      },
      onFieldSubmitted: _onSubmitted,
      onChanged: (value) {
        if (ScrollSearchController.inst.currentSearchType.value == SearchType.localTracks) {
          _searchFieldTimer?.cancel();
          _searchFieldTimer = Timer(const Duration(milliseconds: 150), () {
            ClipboardController.inst.updateTextInControllerEmpty(value == '');
            SearchSortController.inst.searchAll(value);
          });
        }
      },
      // -- unfocusing produces weird bug while swiping for drawer
      // -- leaving it will leave the pointer while entering miniplayer
      // -- bruh
      // onTapOutside: (event) => FocusScope.of(context).unfocus(),
    );
  }
}

Timer? _searchFieldTimer;

class AlbumSearchResultsPage extends StatelessWidget {
  const AlbumSearchResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AlbumsPage(
      albumIdentifiers: SearchSortController.inst.albumSearchTemp,
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
