import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:namida/base/audio_handler.dart';
import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/clipboard_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/selected_tracks_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/settings_search_controller.dart';
import 'package:namida/controller/window_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/main_page_wrapper.dart';
import 'package:namida/packages/searchbar_animation.dart';
import 'package:namida/ui/pages/albums_page.dart';
import 'package:namida/ui/pages/artists_page.dart';
import 'package:namida/ui/pages/search_page.dart';
import 'package:namida/ui/pages/settings_page.dart';
import 'package:namida/ui/pages/settings_search_page.dart';
import 'package:namida/ui/widgets/animated_widgets.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/customization_settings.dart';
import 'package:namida/ui/widgets/settings/theme_settings.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_local_search_controller.dart';

class MainPage extends StatelessWidget {
  final AnimationController animation;
  final bool isMiniplayerAlwaysVisible;

  const MainPage({
    super.key,
    required this.animation,
    this.isMiniplayerAlwaysVisible = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final showNavigationAtSide = Dimensions.inst.showNavigationAtSide;
    final main = RepaintBoundary(
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
          onGenerateInitialRoutes: (_, _) {
            NamidaNavigator.inst.onFirstLoad();
            return [MaterialPageRoute(builder: (_) => const SizedBox())];
          },
        ),
      ),
    );

    final fabChild = _MainPageFABButton();
    Widget mainChild = Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: PreferredSize(
        preferredSize: const Size(0, kToolbarHeight),
        child: _CustomAppBar(
          animation: animation,
          isMiniplayerAlwaysVisible: isMiniplayerAlwaysVisible,
        ),
      ),
      body: SafeArea(
        left: !showNavigationAtSide,
        bottom: false,
        child: DefaultTextStyle(
          style: const TextStyle(
            fontFamilyFallback: AppThemes.fontFamilyFallback,
          ),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              isMiniplayerAlwaysVisible
                  ? main
                  : AnimatedBuilder(
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
                  (context) => AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: ScrollSearchController.inst.isGlobalSearchMenuShown.valueR ? const SearchPage() : null,
                  ),
                ),
              ),

              // -- Settings Search Box
              Positioned.fill(
                child: ObxO(
                  rx: SettingsSearchController.inst.canShowSearch,
                  builder: (context, canShowSearch) => AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: canShowSearch ? const SettingsSearchPage() : null,
                  ),
                ),
              ),

              Builder(
                builder: (context) {
                  final fabBottomOffset = MediaQuery.viewInsetsOf(context).bottom - MediaQuery.viewPaddingOf(context).bottom - kBottomNavigationBarHeight + 8.0;
                  return Obx(
                    (context) {
                      final currentRoute = NamidaNavigator.inst.currentRouteR;
                      if (currentRoute == null) return const SizedBox();

                      final mainFABHidden = Dimensions.inst.shouldHideFABR;
                      final bottom = fabBottomOffset.withMinimum(isMiniplayerAlwaysVisible ? 12.0 : Dimensions.inst.globalBottomPaddingEffectiveR);
                      final right = (mainFABHidden ? 0.0 : kFABSize + 12.0) + 8.0;
                      bool shouldHide;
                      bool shouldPlay = false;

                      final currentQueueSource = currentRoute.toQueueSource();
                      if (!currentQueueSource.supportResuming) {
                        shouldHide = true;
                      } else {
                        shouldHide = ScrollSearchController.inst.isGlobalSearchMenuShown.valueR;
                        if (!shouldHide) {
                          final item = QueueController.latestPlayedForSourceManager.map.valueR[currentQueueSource];
                          if (item == null) {
                            shouldHide = true;
                          } else if (Player.inst.currentItem.valueR != item) {
                            shouldPlay = true;
                          }
                        }
                      }

                      if (!shouldHide) {
                        // -- only update shouldPlay when fab is showing
                        // -- to prevent switching buttons while hiding
                        _MainPageFABResumeButton._latestShouldPlay = shouldPlay;
                      }

                      return AnimatedPositioned(
                        key: const Key('fab_resume_active'),
                        right: right,
                        bottom: bottom,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.fastEaseInToSlowEaseOut,
                        child: AnimatedShow(
                          isHorizontal: true,
                          show: !shouldHide,
                          duration: const Duration(milliseconds: 400),
                          child: _MainPageFABResumeButton._latestShouldPlay
                              ? _MainPageFABResumeButton(
                                  key: const ValueKey('shouldPlay_true'),
                                  shouldPlay: true,
                                  getInfo: () => (currentRoute: currentRoute, currentQueueSource: currentQueueSource),
                                )
                              : _MainPageFABResumeButton(
                                  key: const ValueKey('shouldPlay_false'),
                                  shouldPlay: false,
                                  getInfo: () => (currentRoute: currentRoute, currentQueueSource: currentQueueSource),
                                ),
                        ),
                      );
                    },
                  );
                },
              ),
              Builder(
                builder: (context) {
                  final fabBottomOffset = MediaQuery.viewInsetsOf(context).bottom - MediaQuery.viewPaddingOf(context).bottom - kBottomNavigationBarHeight + 8.0;
                  return Obx(
                    (context) {
                      final shouldHide = Dimensions.inst.shouldHideFABR;
                      final bottom = fabBottomOffset.withMinimum(isMiniplayerAlwaysVisible ? 12.0 : Dimensions.inst.globalBottomPaddingEffectiveR);
                      return AnimatedPositioned(
                        key: const Key('fab_active'),
                        right: 12.0,
                        bottom: bottom,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.fastEaseInToSlowEaseOut,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: shouldHide ? const SizedBox(key: Key('fab_dummy')) : fabChild,
                        ),
                      );
                    },
                  );
                },
              ),

              /// Bottom Glow/Shadow
              if (!isMiniplayerAlwaysVisible)
                Obx(
                  (context) {
                    final currentItem = Player.inst.currentItem.valueR;
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 600),
                      child: currentItem is Selectable || (currentItem is YoutubeID && !settings.youtube.youtubeStyleMiniplayer.valueR)
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
                                        color: theme.scaffoldBackgroundColor,
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
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: showNavigationAtSide ? null : _CustomNavBar(animation: animation),
    );

    mainChild = Row(
      children: [
        if (showNavigationAtSide) const _CustomRailBar(),
        Expanded(
          child: mainChild,
        ),
      ],
    );

    return ObxO(
      rx: settings.animatedTheme,
      builder: (context, animatedTheme) {
        if (!animatedTheme) {
          return Builder(
            builder: (context) => Theme(
              data: theme,
              child: mainChild,
            ),
          );
        }

        final animatedThemeWidget = Builder(
          builder: (context) => _AnimatedTheme(
            key: _animatedThemeGlobalKey,
            duration: const Duration(milliseconds: kThemeAnimationDurationMS),
            data: theme,
            child: mainChild,
          ),
        );
        final animatedThemeState = _animatedThemeGlobalKey.currentState;
        animatedThemeState?.setAnimated(animation.value < 1);

        if (isMiniplayerAlwaysVisible) return animatedThemeWidget;

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
      },
    );
  }
}

class _MainPageFABButton extends StatefulWidget {
  const _MainPageFABButton();

  @override
  State<_MainPageFABButton> createState() => __MainPageFABButtonState();
}

class __MainPageFABButtonState extends State<_MainPageFABButton> {
  @override
  void initState() {
    super.initState();
    ScrollSearchController.inst.searchTextEditingController.addListener(_onControllerValueChangedListener);
    ScrollSearchController.inst.latestSubmittedYTSearch.addListener(_onControllerValueChangedListener);
    _onControllerValueChangedListener();
  }

  @override
  void dispose() {
    ScrollSearchController.inst.searchTextEditingController.removeListener(_onControllerValueChangedListener);
    ScrollSearchController.inst.latestSubmittedYTSearch.removeListener(_onControllerValueChangedListener);
    super.dispose();
  }

  bool _shouldShowSubmitSearch = false;

  void _onControllerValueChangedListener() {
    final val = ScrollSearchController.inst.searchTextEditingController.text;
    final latestSubmitted = ScrollSearchController.inst.latestSubmittedYTSearch.value;

    final newShouldShowSubmitSearch = val != latestSubmitted && val.isNotEmpty;
    if (_shouldShowSubmitSearch != newShouldShowSubmitSearch) {
      setState(() => _shouldShowSubmitSearch = newShouldShowSubmitSearch);
    }
  }

  double _dragValue = 0;
  static const _dragThreshold = 0.2;

  void _onDragUpwards() {
    ScrollSearchController.inst.focusKeyboard();
  }

  void _onDragDownwards() {
    ScrollSearchController.inst.unfocusKeyboard();
  }

  void _onTap() {
    final fab = settings.floatingActionButton.value;
    final isMenuOpened = ScrollSearchController.inst.isGlobalSearchMenuShown.value;
    if (fab == FABType.search || isMenuOpened) {
      if (_shouldShowSubmitSearch && ScrollSearchController.inst.currentSearchType.value == SearchType.youtube) {
        ScrollSearchController.inst.searchBarWidget.submit(ScrollSearchController.inst.searchTextEditingController.text);
        return;
      }
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
  }

  String _tooltip() => ScrollSearchController.inst.isGlobalSearchMenuShown.value ? lang.clear : settings.floatingActionButton.value.toText();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final searchProgressWidget = Builder(
      builder: (context) {
        return CircularProgressIndicator(
          strokeWidth: 2.0,
          strokeCap: StrokeCap.round,
          color: theme.colorScheme.onSecondaryContainer.withOpacityExt(0.4),
        );
      },
    );
    return Builder(
      builder: (context) => ObxO(
        rx: ScrollSearchController.inst.isGlobalSearchMenuShown,
        builder: (context, isGlobalSearchMenuShown) => isGlobalSearchMenuShown
            ? VerticalDragDetector(
                onUpdate: (details) {
                  _dragValue += details.delta.dy * 0.02;
                },
                onEnd: (details) {
                  if (_dragValue < -_dragThreshold) {
                    _onDragUpwards();
                  } else if (_dragValue > _dragThreshold) {
                    _onDragDownwards();
                  }
                  _dragValue = 0;
                },
                onCancel: () => _dragValue = 0,
                child: ObxO(
                  rx: SearchSortController.inst.runningSearchesTempCount,
                  builder: (context, runningSearchesCount) => Stack(
                    alignment: Alignment.center,
                    children: [
                      ObxO(
                        rx: ScrollSearchController.inst.currentSearchType,
                        builder: (context, currentSearchType) => NamidaFABButton(
                          tooltip: _tooltip,
                          icon: _shouldShowSubmitSearch && currentSearchType == SearchType.youtube ? Broken.search_normal : Broken.shield_slash,
                          onTap: _onTap,
                        ),
                      ),
                      if (runningSearchesCount > 0) searchProgressWidget,
                    ],
                  ),
                ),
              )
            : ObxO(
                rx: settings.floatingActionButton,
                builder: (context, fabButton) => NamidaFABButton(
                  tooltip: _tooltip,
                  onTap: _onTap,
                  icon: fabButton.toIcon(),
                ),
              ),
      ),
    );
  }
}

class _MainPageFABResumeButton extends StatelessWidget {
  final bool shouldPlay;
  final ({NamidaRoute currentRoute, QueueSourceBase currentQueueSource}) Function() getInfo;

  const _MainPageFABResumeButton({
    super.key,
    required this.shouldPlay,
    required this.getInfo,
  });

  static bool _latestShouldPlay = false;

  T? _resumeFABResolver<T>(NamidaRoute currentRoute, QueueSourceBase currentQueueSource, {required T Function(int index, List<Playable> items) callback}) {
    final latestItemPlayable = QueueController.latestPlayedForSourceManager.map.value[currentQueueSource];
    return latestItemPlayable?.execute(
      selectable: (latestItem) {
        final tracks = currentRoute.tracksListInside();
        var index = tracks.indexWhere((e) => e == latestItem);
        if (index < 0) index = tracks.indexWhere((e) => e.track == latestItem.track);
        if (index < 0) index = 0;
        return callback(index, tracks);
      },
      youtubeID: (latestItem) {
        final videos = currentRoute.videosListInside();
        var index = videos.indexWhere((e) => e == latestItem);
        if (index < 0) index = videos.indexWhere((e) => e.id == latestItem.id);
        if (index < 0) index = 0;
        return callback(index, videos);
      },
    );
  }

  void _resumeFABJumpToItem(int index, List<Playable> items) {
    try {
      final itemExtent = items.firstOrNull is YoutubeID ? Dimensions.youtubeCardItemExtent : Dimensions.inst.trackTileItemExtent;
      final offset = (index + 1) * itemExtent;
      final controllerPosition = NamidaScrollController.latestAddedScrollController?.positions.lastOrNull;
      final maxOffset = controllerPosition?.maxScrollExtent;
      if (maxOffset != null && offset > maxOffset) {
        return;
      }
      controllerPosition?.animateToEff(
        offset,
        duration: const Duration(milliseconds: 400),
        curve: Curves.fastLinearToSlowEaseIn,
      );
    } catch (_) {}
  }

  void _onTap() {
    final info = getInfo();
    _resumeFABResolver(
      info.currentRoute,
      info.currentQueueSource,
      callback: (index, items) {
        _resumeFABJumpToItem(index, items);
        if (shouldPlay) {
          Player.inst.playOrPause(
            index,
            items,
            info.currentQueueSource,
            gentlePlay: false,
          );
        }
      },
    );
  }

  void _onLongPress() {
    final info = getInfo();
    _resumeFABResolver(
      info.currentRoute,
      info.currentQueueSource,
      callback: _resumeFABJumpToItem,
    );
  }

  @override
  Widget build(BuildContext context) {
    return NamidaTooltip(
      message: () => lang.resume,
      child: shouldPlay
          ? NamidaFABButton(
              tooltip: null,
              icon: Broken.play_circle,
              text: lang.resume,
              onTap: _onTap,
              onLongPress: _onLongPress,
            )
          : NamidaFABButton(
              tooltip: () => lang.jump,
              icon: Broken.cd,
              text: null,
              onTap: _onTap,
              onLongPress: _onLongPress,
            ),
    );
  }
}

class NamidaSearchBar extends StatelessWidget {
  final GlobalKey<SearchBarAnimationState> searchBarKey;
  const NamidaSearchBar({super.key, required this.searchBarKey});

  void submit(String val) {
    _onSubmitted(val);
  }

  void _onSubmitted(String val) {
    final didOpen = NamidaLinkUtils.tryOpeningPlaylistOrVideo(val);
    if (didOpen) {
      ScrollSearchController.inst.searchTextEditingController.clear();
      return;
    }

    if (ScrollSearchController.inst.currentSearchType.value == SearchType.youtube) {
      ScrollSearchController.inst.latestSubmittedYTSearch.value = val;
      ScrollSearchController.inst.ytSearchKey.currentState?.fetchSearch(customText: val);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    return SearchBarAnimation(
      key: searchBarKey,
      initiallyAlwaysExpanded: settings.alwaysExpandedSearchbar.value,
      isSearchBoxOnRightSide: true,
      textAlignToRight: false,
      durationInMilliSeconds: 300,
      enableKeyboardFocus: true,
      isOriginalAnimation: false,
      textEditingController: ScrollSearchController.inst.searchTextEditingController,
      hintText: /*  ScrollSearchController.inst.currentSearchType.value == SearchType.youtube ? lang.searchYoutube : */ lang.search,
      searchBoxWidth: context.width / 1.2,
      buttonColour: Colors.transparent,
      enableBoxShadow: false,
      buttonShadowColour: Colors.transparent,
      hintTextStyle: (height) => textTheme.displaySmall?.copyWith(
        fontSize: 17.0,
        height: height * 1.1,
      ),
      searchBoxColour: context.isDarkMode ? theme.cardColor.withAlpha(200) : Color.alphaBlend(theme.cardColor.withAlpha(200), theme.colorScheme.onSurface.withAlpha(40)),
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
      buttonWidgetSmallPadding: 24.0 + 8.0,
      buttonWidgetSmall: Obx(
        (context) {
          final clipboard = ClipboardController.inst.clipboardText.valueR;
          final alreadyPasted = clipboard == ClipboardController.inst.lastCopyUsed.valueR;
          final empty = ClipboardController.inst.textInControllerEmpty.valueR;

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: clipboard != '' && (empty || !alreadyPasted)
                ? NamidaIconButton(
                    horizontalPadding: 2.0,
                    verticalPadding: 8.0,
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
        padding: const EdgeInsets.all(8.0),
        icon: Broken.close_circle,
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

class AlbumSearchResultsPage extends StatelessWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.SEARCH_albumResults;

  const AlbumSearchResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AlbumsPage(
      albumIdentifiers: SearchSortController.inst.albumSearchTemp,
      countPerRow: settings.mediaGridCounts.value.get(LibraryTab.albums),
      enableGridIconButton: false,
    );
  }
}

class ArtistSearchResultsPage extends StatelessWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.SEARCH_artistResults;

  final RxList<String> artists;
  final MediaType type;
  const ArtistSearchResultsPage({super.key, required this.artists, required this.type});

  @override
  Widget build(BuildContext context) {
    return ArtistsPage(
      enableHero: false,
      artists: artists,
      countPerRow: settings.mediaGridCounts.value.get(LibraryTab.artists),
      enableGridIconButton: false,
      customType: type,
    );
  }
}

class _CustomAppBar extends StatelessWidget {
  final AnimationController animation;
  final bool isMiniplayerAlwaysVisible;

  const _CustomAppBar({
    required this.animation,
    required this.isMiniplayerAlwaysVisible,
  });

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
      (context) {
        final currentWidgetStack = NamidaNavigator.inst.currentWidgetStack.valueR;
        final isInnerPage = currentWidgetStack.length > 1;
        final title = ScrollSearchController.inst.isGlobalSearchMenuShown.valueR
            ? ScrollSearchController.inst.searchBarWidget
            : NamidaNavigator.inst.currentRouteR?.toTitle(context);
        final actions = NamidaNavigator.inst.currentRouteR?.toActions(isInnerPage: isInnerPage);
        return Row(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints.tightFor(width: kToolbarHeight),
              child: isInnerPage
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
    final showNavigationAtSide = Dimensions.inst.showNavigationAtSide;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Material(
        shadowColor: Colors.transparent,
        type: MaterialType.canvas,
        color: backgroundColor,
        surfaceTintColor: surfaceTintColor,
        child: SafeArea(
          left: !showNavigationAtSide,
          bottom: false,
          child: isMiniplayerAlwaysVisible
              ? SizedBox(
                  height: kToolbarHeight,
                  child: appbar,
                )
              : Obx(
                  (context) {
                    return !settings.enableMiniplayerParallaxEffect.valueR
                        ? SizedBox(
                            height: kToolbarHeight,
                            child: appbar,
                          )
                        : AnimatedBuilder(
                            animation: animation,
                            builder: (context, _) {
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
    final theme = context.theme;
    final bottomNavBar = NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: theme.navigationBarTheme.backgroundColor,
        indicatorColor: Color.alphaBlend(theme.colorScheme.primary.withAlpha(20), theme.colorScheme.secondaryContainer),
      ),
      child: ObxO(
        rx: settings.libraryTabs,
        builder: (context, libraryTabs) => ObxO(
          rx: settings.extra.selectedLibraryTab,
          builder: (context, selectedLibraryTab) {
            final selectedIndex = selectedLibraryTab.toInt().toIf(0, -1);
            return NavigationBar(
              animationDuration: const Duration(seconds: 1),
              elevation: 22,
              labelBehavior: libraryTabs.length >= 8 ? NavigationDestinationLabelBehavior.alwaysHide : NavigationDestinationLabelBehavior.onlyShowSelected,
              height: 64.0,
              selectedIndex: selectedIndex,
              onDestinationSelected: (destinationIndex) {
                final tab = libraryTabs[destinationIndex];
                ScrollSearchController.inst.animatePageController(tab);
              },
              destinations: [
                ...libraryTabs.mapIndexed(
                  (e, i) => DefaultTextStyle(
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: const TextStyle(
                      fontSize: 13.0,
                    ),
                    child: NavigationDestination(
                      icon: Icon(
                        e.toIcon(),
                        color: selectedIndex == i ? AppThemes.selectedNavigationIconColor : null,
                      ),
                      label: e.toText(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );

    return Obx(
      (context) => !settings.enableBottomNavBar.valueR
          ? const SizedBox()
          : AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                return Transform.translate(
                  offset: Offset(0, (kBottomNavigationBarHeight * animation.value).withMinimum(0)),
                  child: bottomNavBar,
                );
              },
            ),
    );
  }
}

class _CustomRailBar extends StatefulWidget {
  const _CustomRailBar();

  @override
  State<_CustomRailBar> createState() => __CustomRailBarState();
}

class __CustomRailBarState extends State<_CustomRailBar> {
  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final maxHeight = context.height;

    const hMargin = 4.0;
    const itemWidth = 42.0;
    const iconSize = itemWidth * 0.6;
    const iconPadding = itemWidth * 0.2;
    const maxWidth = itemWidth + hMargin * 2;

    const bottomActionSizeMultiplier = 0.75;
    const itemWidthBottomAction = itemWidth * bottomActionSizeMultiplier;
    const iconSizeBottomAction = iconSize * bottomActionSizeMultiplier;
    const iconPaddingBottomAction = iconPadding * bottomActionSizeMultiplier;

    final showCustomizationIcon = maxHeight > 550;
    final showLogo = WindowController.instance?.usingCustomWindowTitleBar != true;

    final bgColor = Color.alphaBlend(
      (theme.navigationRailTheme.backgroundColor ?? theme.colorScheme.surface).withOpacityExt(.5),
      theme.colorScheme.surfaceContainer,
    );
    Widget child = Material(
      color: bgColor,
      child: SafeArea(
        child: SizedBox(
          width: maxWidth,
          height: maxHeight,
          child: ObxO(
            rx: settings.libraryTabs,
            builder: (context, libraryTabs) => ObxO(
              rx: settings.extra.selectedLibraryTab,
              builder: (context, selectedLibraryTab) => Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Expanded(
                    child: FittedBox(
                      alignment: Alignment.topCenter,
                      fit: BoxFit.fitWidth,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: hMargin),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            if (showLogo) const SizedBox(height: 6.0) else const SizedBox(height: 4.0),
                            if (showLogo)
                              const NamidaLogoContainer(
                                displayText: false,
                                lighterShadow: true,
                                width: maxWidth - iconPadding,
                                height: maxWidth - iconPadding,
                                iconSize: iconSize * 1.5,
                                margin: EdgeInsets.zero,
                                padding: EdgeInsets.zero,
                              ),
                            const NamidaContainerDivider(
                              margin: EdgeInsets.only(top: 6.0),
                              width: itemWidth - 4.0,
                            ),
                            ...libraryTabs
                                .map(
                                  (e) {
                                    final isSelected = selectedLibraryTab == e;
                                    return AnimatedDecoration(
                                      duration: Duration(milliseconds: 400),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular((isSelected ? 16.0 : 24.0).multipliedRadius),
                                        color: isSelected ? theme.colorScheme.secondaryContainer : null,
                                      ),
                                      child: NamidaIconButton(
                                        tooltip: () => e.toText(),
                                        padding: EdgeInsets.all(iconPadding),
                                        icon: e.toIcon(),
                                        iconColor: isSelected ? AppThemes.selectedNavigationIconColor : null,
                                        iconSize: iconSize,
                                        onPressed: () {
                                          ScrollSearchController.inst.animatePageController(e);
                                        },
                                      ),
                                    );
                                  },
                                )
                                .addSeparators(separator: SizedBox(height: 6.0)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxHeight * 0.25),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FittedBox(
                        alignment: Alignment.bottomCenter,
                        fit: BoxFit.fitWidth,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: hMargin),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(height: 6.0),
                              ObxO(
                                rx: settings.themeMode,
                                builder: (context, themeMode) => IconButton(
                                  visualDensity: VisualDensity.compact,
                                  style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                  padding: EdgeInsets.all(iconPaddingBottomAction),
                                  iconSize: iconSizeBottomAction,
                                  icon: Icon(
                                    themeMode.toIcon(),
                                    size: iconSizeBottomAction,
                                  ),
                                  onPressed: () {
                                    final nextMode = themeMode.nextElement(ThemeMode.values);
                                    ToggleThemeModeContainer.onThemeChangeTap(nextMode);
                                  },
                                ),
                              ),
                              const NamidaContainerDivider(
                                margin: EdgeInsets.symmetric(vertical: 4.0),
                                width: itemWidth - 4.0,
                              ),
                              NamidaTooltip(
                                message: () => lang.sleepTimer,
                                child: NamidaDrawerListTile(
                                  margin: EdgeInsets.zero,
                                  padding: EdgeInsets.all(iconPaddingBottomAction),
                                  enabled: false,
                                  isCentered: true,
                                  iconSize: iconSizeBottomAction,
                                  title: '',
                                  width: itemWidthBottomAction,
                                  icon: Broken.timer_1,
                                  onTap: () {
                                    NamidaDrawer.openSleepTimerDialog(context);
                                  },
                                ),
                              ),
                              SizedBox(height: 6.0),
                              if (showCustomizationIcon) ...[
                                NamidaTooltip(
                                  message: () => lang.customizations,
                                  child: NamidaDrawerListTile(
                                    margin: EdgeInsets.zero,
                                    padding: EdgeInsets.all(iconPaddingBottomAction),
                                    enabled: false,
                                    isCentered: true,
                                    iconSize: iconSizeBottomAction,
                                    title: '',
                                    width: itemWidthBottomAction,
                                    icon: Broken.brush_1,
                                    onTap: () {
                                      SettingsSubPage(
                                        title: () => lang.customizations,
                                        child: const CustomizationSettings(),
                                      ).navigate();
                                    },
                                  ),
                                ),
                                SizedBox(height: 6.0),
                              ],
                              NamidaTooltip(
                                message: () => lang.settings,
                                child: NamidaDrawerListTile(
                                  margin: EdgeInsets.zero,
                                  padding: EdgeInsets.all(iconPaddingBottomAction),
                                  enabled: false,
                                  isCentered: true,
                                  iconSize: iconSizeBottomAction,
                                  title: '',
                                  width: itemWidthBottomAction,
                                  icon: Broken.setting,
                                  onTap: () {
                                    const SettingsPage().navigate();
                                  },
                                ),
                              ),
                              SizedBox(height: 6.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final drawerState = NamidaNavigator.inst.innerDrawerKey.currentState;
    if (drawerState == null) return child;

    double getDrawerPercentage() {
      final fastValue = ((1 - drawerState.drawerPercentage) * 1.5 - 0.5).clampDouble(0.0, 1.0);
      return fastValue;
    }

    return FadeTransition(
      opacity: Animation.fromValueListenable(
        drawerState.animationView,
        transformer: (_) => getDrawerPercentage(),
      ),
      child: AnimatedBuilder(
        animation: drawerState.animationView,
        builder: (context, _) {
          return Align(
            widthFactor: getDrawerPercentage(),
            child: child,
          );
        },
      ),
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
