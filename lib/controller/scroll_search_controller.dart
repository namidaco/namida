import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'package:namida/class/count_per_row.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/searchbar_animation.dart';
import 'package:namida/ui/pages/main_page.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/pages/yt_search_results_page.dart';

class ScrollSearchController {
  static ScrollSearchController get inst => _instance;
  static final ScrollSearchController _instance = ScrollSearchController._internal();
  ScrollSearchController._internal();

  final ytSearchKey = GlobalKey<YoutubeSearchResultsPageState>();
  final currentSearchType = SearchType.localTracks.obs;

  final isGlobalSearchMenuShown = false.obs;
  final latestSubmittedYTSearch = ''.obs;
  final TextEditingController searchTextEditingController = TextEditingController();

  final Map<LibraryTab, Rx<bool>> isBarVisibleMap = <LibraryTab, Rx<bool>>{};

  ScrollController scrollController = ScrollController();
  final Map<LibraryTab, double> scrollPositionsMap = {};

  final _textSearchControllers = <LibraryTab, TextEditingController>{}.obs;

  final FocusNode focusNode = FocusNode();

  final searchBarKey = GlobalKey<SearchBarAnimationState>();
  final tabViewKey = GlobalKey<NamidaTabViewState>();

  late final NamidaSearchBar searchBarWidget = NamidaSearchBar(searchBarKey: searchBarKey);

  void toggleSearch({bool forceOpen = false, bool instant = false}) async {
    MiniPlayerController.inst.snapToMini();
    MiniPlayerController.inst.ytMiniplayerKey.currentState?.animateToState(false);
    final shouldShow = this.toggleSearchMenu();
    void openFn() => ScrollSearchController.inst.searchBarKey.currentState?.openCloseSearchBar(forceOpen: shouldShow);
    if (instant) {
      openFn();
    } else {
      await Future.delayed(const Duration(milliseconds: 100));
      SchedulerBinding.instance.addPostFrameCallback((_) {
        openFn();
      });
    }
  }

  void animatePageController(LibraryTab tab) async {
    if (tab == LibraryTab.search) {
      toggleSearch();

      return;
    }

    final w = tab.toWidget();
    hideSearchMenu();

    if (NamidaNavigator.inst.currentRoute?.isSameRouteAs(w) == true) {
      if (scrollController.hasClients) {
        MiniPlayerController.inst.snapToMini();
        scrollController.animateToEff(0.0, duration: const Duration(milliseconds: 400), curve: Curves.easeInOutQuart);
      }
      return;
    }

    final isVertical = Dimensions.inst.showNavigationAtSide;
    final isPageNext = tab.toInt() > settings.extra.selectedLibraryTab.value.toInt();
    final transition = isVertical
        ? isPageNext
            ? Transition.downToUp
            : Transition.upToDown
        : isPageNext
            ? Transition.rightToLeft
            : Transition.leftToRight;

    _updateScrollPositions(settings.extra.selectedLibraryTab.value, tab);
    settings.extra.save(selectedLibraryTab: tab);
    NamidaNavigator.inst.navigateOffAll(w, transition: transition, durationMs: isVertical ? 300 : 400);
  }

  CountPerRow animateChangingGridSize(LibraryTab tab, CountPerRow gridCount) {
    _updateScrollPositions(tab, tab);
    NamidaNavigator.inst.navigateOff(tab.toWidget(gridCount, false, true), durationInMs: 500);
    return gridCount;
  }

  void initialize() {
    _assignScrollController(settings.extra.selectedLibraryTab.value);
  }

  void _assignScrollController(LibraryTab tab) {
    scrollController.dispose();
    scrollController = ScrollController(initialScrollOffset: tab.scrollPosition);

    final rx = isBarVisibleMap[tab] ??= true.obs;
    rx.value = true;
    scrollController.addListener(() {
      isBarVisibleMap[tab]?.value = scrollController.positions.lastOrNull?.userScrollDirection == ScrollDirection.forward;
    });
  }

  RxBaseCore<bool> getIsBarVisible(LibraryTab tab) {
    return isBarVisibleMap[tab] ??= true.obs;
  }

  double getScrollPosition(LibraryTab tab) {
    return scrollPositionsMap[tab] ??= 0.0;
  }

  void _updateScrollPositions(LibraryTab oldTab, LibraryTab newTab) {
    scrollPositionsMap[oldTab] = oldTab.offsetOrZero;
    _assignScrollController(newTab);
  }

  void hideSearchMenu() {
    unfocusKeyboard();
    isGlobalSearchMenuShown.value = false;
  }

  void showSearchMenu([bool show = true]) {
    isGlobalSearchMenuShown.value = show;
  }

  // returns wether search menu is now shown or not.
  bool toggleSearchMenu() {
    if (isGlobalSearchMenuShown.value) {
      hideSearchMenu();
      return false;
    } else {
      showSearchMenu();
      return true;
    }
  }

  void resetSearch() {
    searchTextEditingController.clear();
    SearchSortController.inst.searchAll('');
  }

  void unfocusKeyboard() {
    final globalFocusNode = searchBarKey.currentState?.focusNode;
    final focusNode = FocusManager.instance.primaryFocus;

    // // this causes issue on emulator when trying to edit textfield and yt miniplayer is shown,
    // // but removing it makes keyboard shows after closing dialog on all devices.
    // ^-- probably outdated

    focusNode?.unfocus();
    globalFocusNode?.unfocus();
  }

  void focusKeyboard() {
    final globalSearchState = searchBarKey.currentState;
    if (globalSearchState != null && isGlobalSearchMenuShown.value) {
      globalSearchState.focusNode.requestFocus();
    } else {
      focusNode.requestFocus();
    }
  }

  bool onSearchBoxVisibiltyChange(LibraryTab libraryTab, bool newShow) {
    _textSearchControllers[libraryTab] ??= TextEditingController();

    if (_textSearchControllers.value[libraryTab]!.text == '') {
      if (!newShow) {
        _closeTextController(libraryTab);
        return true;
      } else {
        _openTextController(libraryTab);
        return true;
      }
    }
    return false;
  }

  void _closeTextController(LibraryTab libraryTab) {
    _textSearchControllers.value[libraryTab]?.dispose();
    _textSearchControllers.remove(libraryTab);
    unfocusKeyboard();
  }

  void _openTextController(LibraryTab libraryTab) {
    _textSearchControllers[libraryTab] ??= TextEditingController();
    focusKeyboard();
  }

  void clearSearchTextField(LibraryTab libraryTab) {
    final mediaType = libraryTab.toMediaType();
    SearchSortController.inst.disposeMediaResources(mediaType);
    SearchSortController.inst.searchMedia('', mediaType);
    _closeTextController(libraryTab);
  }
}

extension LibraryTabStuff on LibraryTab {
  ScrollController get scrollController => ScrollSearchController.inst.scrollController;
  TextEditingController? get textSearchController => ScrollSearchController.inst._textSearchControllers.value[this];
  TextEditingController? get textSearchControllerUI => ScrollSearchController.inst._textSearchControllers.valueR[this];
  double get scrollPosition => ScrollSearchController.inst.getScrollPosition(this);
  RxBaseCore<bool> get isBarVisible => ScrollSearchController.inst.getIsBarVisible(this);
  double get offsetOrZero => (ScrollSearchController.inst.scrollController.hasClients) ? scrollController.positions.lastOrNull?.pixels ?? 0.0 : 0.0;
  bool get shouldAnimateTiles => offsetOrZero == 0.0;
}
