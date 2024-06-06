import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:namida/class/track.dart';
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
import 'package:namida/core/utils.dart';
import 'package:namida/main.dart';
import 'package:namida/packages/searchbar_animation.dart';
import 'package:namida/ui/pages/albums_page.dart';
import 'package:namida/ui/pages/artists_page.dart';
import 'package:namida/ui/pages/search_page.dart';
import 'package:namida/ui/pages/settings_search_page.dart';
import 'package:namida/ui/widgets/animated_widgets.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_local_search_controller.dart';

class MainPage extends StatelessWidget {
  final AnimationController animation;
  const MainPage({super.key, required this.animation});

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
          return MaterialPageRoute(
            builder: (_) => const SizedBox(),
          );
        },
      ),
    );

    final searchProgressColor = context.theme.colorScheme.onSecondaryContainer.withOpacity(0.4);
    final searchProgressWidget = CircularProgressIndicator(
      strokeWidth: 2.0,
      strokeCap: StrokeCap.round,
      color: searchProgressColor,
    );

    final fabBottomOffset = MediaQuery.viewInsetsOf(context).bottom - MediaQuery.viewPaddingOf(context).bottom - kBottomNavigationBarHeight + 8.0;

    final mainChild = Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: PreferredSize(
        preferredSize: const Size(0, kToolbarHeight),
        child: _CustomAppBar(animation: animation),
      ),
      body: DefaultTextStyle(
        style: const TextStyle(
          fontFamilyFallback: ['sans-serif', 'Roboto'],
        ),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                return Visibility(
                  maintainState: true,
                  visible: animation.value < 1,
                  child: !settings.enableMiniplayerParallaxEffect.value
                      ? main
                      : Transform.scale(
                          scale: 1 - (animation.value * 0.05),
                          child: main,
                        ),
                );
              },
            ),

            /// Search Box
            Positioned.fill(
              child: Obx(
                () => AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: ScrollSearchController.inst.isGlobalSearchMenuShown.valueR ? const SearchPage() : null,
                ),
              ),
            ),

            // -- Settings Search Box
            Positioned.fill(
              child: ObxO(
                rx: SettingsSearchController.inst.canShowSearch,
                builder: (canShowSearch) => AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: canShowSearch ? const SettingsSearchPage() : null,
                ),
              ),
            ),

            Obx(
              () {
                final shouldHide = Dimensions.inst.shouldHideFABR;
                return AnimatedPositioned(
                  key: const Key('fab_active'),
                  right: 12.0,
                  bottom: fabBottomOffset.withMinimum(Dimensions.inst.globalBottomPaddingEffectiveR),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.fastEaseInToSlowEaseOut,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: shouldHide
                        ? const SizedBox(key: Key('fab_dummy'))
                        : FloatingActionButton(
                            heroTag: 'main_page_fab_hero',
                            tooltip: ScrollSearchController.inst.isGlobalSearchMenuShown.valueR ? lang.CLEAR : settings.floatingActionButton.valueR.toText(),
                            backgroundColor: Color.alphaBlend(CurrentColor.inst.currentColorScheme.withOpacity(0.6), context.theme.cardColor),
                            onPressed: () {
                              final fab = settings.floatingActionButton.value;
                              final isMenuOpened = ScrollSearchController.inst.isGlobalSearchMenuShown.value;
                              if (fab == FABType.search || isMenuOpened) {
                                final isOpen = ScrollSearchController.inst.searchBarKey.currentState?.isOpen ?? false;
                                if (isOpen && !isMenuOpened) {
                                  SearchSortController.inst.prepareResources();
                                  ScrollSearchController.inst.showSearchMenu();
                                  ScrollSearchController.inst.searchBarKey.currentState?.focusNode.requestFocus();
                                } else {
                                  isMenuOpened ? SearchSortController.inst.disposeResources() : SearchSortController.inst.prepareResources();
                                  ScrollSearchController.inst.toggleSearchMenu();
                                  ScrollSearchController.inst.searchBarKey.currentState?.openCloseSearchBar();
                                }
                              } else if (fab == FABType.shuffle || fab == FABType.play) {
                                Player.inst.playOrPause(0, SelectedTracksController.inst.getCurrentAllTracks(), QueueSource.allTracks, shuffle: fab == FABType.shuffle);
                              }
                            },
                            child: ScrollSearchController.inst.isGlobalSearchMenuShown.valueR
                                ? Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      const Icon(
                                        Broken.search_status_1,
                                        color: Color.fromRGBO(255, 255, 255, 0.8),
                                      ),
                                      if (SearchSortController.inst.hasRunningSearch) searchProgressWidget,
                                    ],
                                  )
                                : Icon(
                                    settings.floatingActionButton.valueR.toIcon(),
                                    color: const Color.fromRGBO(255, 255, 255, 0.8),
                                  ),
                          ),
                  ),
                );
              },
            ),

            /// Bottom Glow/Shadow
            Obx(
              () {
                final currentItem = Player.inst.currentItem.valueR;
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  child: currentItem is Selectable || (currentItem is YoutubeID && !settings.youtubeStyleMiniplayer.valueR)
                      ? SizedBox(
                          key: const Key('actualglow'),
                          height: 28.0,
                          width: context.width,
                          child: Transform(
                            transform: Matrix4.translationValues(0, 8.0, 0),
                            child: AnimatedDecoration(
                              duration: const Duration(milliseconds: kThemeAnimationDurationMS),
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
                      : const SizedBox(key: Key('emptyglow')),
                );
              },
            )
          ],
        ),
      ),
      bottomNavigationBar: _CustomNavBar(animation: animation),
    );

    final theme = context.theme;

    final animatedThemeWidget = _AnimatedTheme(
      key: _animatedThemeGlobalKey,
      duration: const Duration(milliseconds: kThemeAnimationDurationMS),
      data: theme,
      child: mainChild,
    );
    final animatedThemeState = _animatedThemeGlobalKey.currentState;
    animatedThemeState?.setAnimated(animation.value < 1);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final mainPlayerVisible = animation.value < 1;
        animatedThemeState?.setAnimated(mainPlayerVisible);
        return Visibility(
          maintainState: true,
          visible: mainPlayerVisible,
          child: animatedThemeWidget,
        );
      },
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
        fontSize: 17.0,
        height: height * 1.1,
      ),
      searchBoxColour: context.theme.cardColor.withAlpha(200),
      enteredTextStyle: context.theme.textTheme.displayMedium,
      cursorColour: context.theme.colorScheme.onSurface,
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
          final clipboard = ClipboardController.inst.clipboardText.valueR;
          final alreadyPasted = clipboard == ClipboardController.inst.lastCopyUsed.valueR;
          final empty = ClipboardController.inst.textInControllerEmpty.valueR;

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: clipboard != '' && (empty || !alreadyPasted)
                ? NamidaIconButton(
                    horizontalPadding: 0,
                    icon: Broken.clipboard_tick,
                    iconSize: 20.0,
                    onPressed: () {
                      ClipboardController.inst.setLastPasted(ClipboardController.inst.clipboardText.value);
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
          ClipboardController.inst.updateTextInControllerEmpty(value == '');
          SearchSortController.inst.searchAll(value);
        }
      },
      // -- unfocusing produces weird bug while swiping for drawer
      // -- leaving it will leave the pointer while entering miniplayer
      // -- bruh
      // onTapOutside: (event) => FocusScope.of(context).unfocus(),
    );
  }
}

class AlbumSearchResultsPage extends StatelessWidget {
  const AlbumSearchResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AlbumsPage(
      albumIdentifiers: SearchSortController.inst.albumSearchTemp.value,
      countPerRow: settings.albumGridCount.value,
    );
  }
}

class ArtistSearchResultsPage extends StatelessWidget {
  final List<String> artists;
  final MediaType type;
  const ArtistSearchResultsPage({super.key, required this.artists, required this.type});

  @override
  Widget build(BuildContext context) {
    return ArtistsPage(
      enableHero: false,
      artists: artists,
      countPerRow: settings.artistGridCount.value,
      customType: type,
    );
  }
}

class _CustomAppBar extends StatelessWidget {
  final AnimationController animation;
  const _CustomAppBar({required this.animation});

  SystemUiOverlayStyle _systemOverlayStyleForBrightness(Brightness brightness, [Color? backgroundColor]) {
    final SystemUiOverlayStyle style = brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
    // For backward compatibility, create an overlay style without system navigation bar settings.
    return SystemUiOverlayStyle(
      statusBarColor: backgroundColor,
      statusBarBrightness: style.statusBarBrightness,
      statusBarIconBrightness: style.statusBarIconBrightness,
      systemStatusBarContrastEnforced: style.systemStatusBarContrastEnforced,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appBarTheme = AppBarTheme.of(context);
    final theme = context.theme;
    final colorscheme = theme.colorScheme;
    final backgroundColor = appBarTheme.backgroundColor ?? colorscheme.surface;
    final surfaceTintColor = appBarTheme.surfaceTintColor ?? colorscheme.surfaceTint;
    final overlayStyle = _systemOverlayStyleForBrightness(ThemeData.estimateBrightnessForColor(backgroundColor), theme.useMaterial3 ? const Color(0x00000000) : null);
    final appbar = Obx(
      () {
        final title =
            ScrollSearchController.inst.isGlobalSearchMenuShown.valueR ? ScrollSearchController.inst.searchBarWidget : NamidaNavigator.inst.currentRouteR?.toTitle(context);
        final actions = NamidaNavigator.inst.currentRouteR?.toActions();
        return Row(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints.tightFor(width: kToolbarHeight),
              child: NamidaNavigator.inst.currentWidgetStack.length > 1
                  ? NamidaAppBarIcon(
                      icon: Broken.arrow_left_2,
                      onPressed: NamidaNavigator.inst.popPage,
                    )
                  : NamidaAppBarIcon(
                      icon: Broken.menu_1,
                      onPressed: NamidaNavigator.inst.toggleDrawer,
                    ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: title ?? const SizedBox(),
              ),
            ),
            ...?actions,
          ],
        );
      },
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Material(
        shadowColor: Colors.transparent,
        type: MaterialType.canvas,
        color: backgroundColor,
        surfaceTintColor: surfaceTintColor,
        child: SafeArea(
          bottom: false,
          child: Obx(
            () {
              return !settings.enableMiniplayerParallaxEffect.valueR
                  ? SizedBox(
                      height: kToolbarHeight,
                      child: appbar,
                    )
                  : AnimatedBuilder(
                      animation: animation,
                      builder: (context, _) {
                        if (animation.value > 1) return const SizedBox(); // expanded/queue
                        return SizedBox(
                          height: kToolbarHeight * (1 - animation.value * 0.3),
                          child: appbar,
                        );
                      },
                    );
            },
          ),
        ),
      ),
    );
  }
}

class _CustomNavBar extends StatelessWidget {
  final AnimationController animation;
  const _CustomNavBar({required this.animation});

  @override
  Widget build(BuildContext context) {
    final bottomNavBar = NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: context.theme.navigationBarTheme.backgroundColor,
        indicatorColor: Color.alphaBlend(context.theme.colorScheme.primary.withAlpha(20), context.theme.colorScheme.secondaryContainer),
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(
            overflow: TextOverflow.ellipsis,
            fontSize: 13.0,
          ),
        ),
      ),
      child: Obx(
        () => NavigationBar(
          animationDuration: const Duration(seconds: 1),
          elevation: 22,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          height: 64.0,
          onDestinationSelected: (destinationIndex) {
            final tab = settings.libraryTabs.value[destinationIndex];
            ScrollSearchController.inst.animatePageController(tab);
          },
          selectedIndex: settings.selectedLibraryTab.valueR.toInt().toIf(0, -1),
          destinations: [
            ...settings.libraryTabs.valueR.map(
              (e) => NavigationDestination(
                icon: Icon(e.toIcon()),
                label: settings.libraryTabs.length >= 7 ? '' : e.toText(),
              ),
            ),
          ],
        ),
      ),
    );

    return Obx(
      () => !settings.enableBottomNavBar.valueR
          ? const SizedBox()
          : AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                if (animation.value > 1) return const SizedBox(); // expanded/queue
                return Transform.translate(
                  offset: Offset(0, (kBottomNavigationBarHeight * animation.value).withMinimum(0)),
                  child: bottomNavBar,
                );
              }),
    );
  }
}

final _animatedThemeGlobalKey = GlobalKey<_AnimatedThemeState>();

class _AnimatedTheme extends ImplicitlyAnimatedWidget {
  const _AnimatedTheme({
    required super.key,
    required this.data,
    required this.child,
    required super.duration,
  });

  final ThemeData data;
  final Widget child;

  @override
  AnimatedWidgetBaseState<_AnimatedTheme> createState() => _AnimatedThemeState();
}

class _AnimatedThemeState extends AnimatedWidgetBaseState<_AnimatedTheme> {
  ThemeDataTween? _data;
  bool _animated = true;
  bool _themeDidChange = true;

  void setAnimated(bool animated) {
    if (animated != _animated) {
      refreshState(() {
        _themeDidChange = false;
        _animated = animated;
      });
    }
  }

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    if (!_animated) return;
    _themeDidChange = true;
    _data = visitor(_data, widget.data, (dynamic value) => ThemeDataTween(begin: value as ThemeData))! as ThemeDataTween;
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: !_animated || !_themeDidChange ? widget.data : _data?.evaluate(animation) ?? widget.data,
      child: widget.child,
    );
  }
}
