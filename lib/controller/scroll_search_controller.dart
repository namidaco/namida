import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'package:get/get.dart';

import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/packages/searchbar_animation.dart';
import 'package:namida/ui/pages/main_page.dart';
import 'package:namida/youtube/pages/yt_search_results_page.dart';

class ScrollSearchController {
  static ScrollSearchController get inst => _instance;
  static final ScrollSearchController _instance = ScrollSearchController._internal();
  ScrollSearchController._internal() {
    searchBarWidget = NamidaSearchBar(searchBarKey: searchBarKey);
  }

  final ytSearchKey = GlobalKey<YoutubeSearchResultsPageState>();
  final currentSearchType = SearchType.localTracks.obs;

  final RxBool isGlobalSearchMenuShown = false.obs;
  final TextEditingController searchTextEditingController = TextEditingController();

  final Map<LibraryTab, RxBool> isSearchBoxVisibleMap = <LibraryTab, RxBool>{};
  final Map<LibraryTab, RxBool> isBarVisibleMap = <LibraryTab, RxBool>{};

  ScrollController scrollController = ScrollController();
  final Map<LibraryTab, double> scrollPositionsMap = {};

  final Map<LibraryTab, TextEditingController> textSearchControllers = {};

  final FocusNode focusNode = FocusNode();

  final searchBarKey = GlobalKey<SearchBarAnimationState>();

  late final NamidaSearchBar searchBarWidget;

  void animatePageController(LibraryTab tab) async {
    if (tab == LibraryTab.search) {
      ScrollSearchController.inst.toggleSearchMenu();
      await Future.delayed(const Duration(milliseconds: 100));
      SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
        ScrollSearchController.inst.searchBarKey.currentState?.openCloseSearchBar();
      });
      return;
    }

    final w = tab.toWidget();
    hideSearchMenu();

    if (w.toNamidaRoute() == NamidaNavigator.inst.currentRoute) {
      if (scrollController.hasClients) {
        MiniPlayerController.inst.snapToMini();
        scrollController.animateToEff(0.0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOutQuart);
      }
      return;
    }

    final isPageToTheRight = tab.toInt() > settings.selectedLibraryTab.value.toInt();
    final transition = isPageToTheRight ? Transition.rightToLeft : Transition.leftToRight;

    _updateScrollPositions(settings.selectedLibraryTab.value, tab);
    settings.save(selectedLibraryTab: tab);
    NamidaNavigator.inst.navigateOffAll(w, transition: transition);
  }

  int animateChangingGridSize(LibraryTab tab, int currentGridCount, {int minimum = 1, int maximum = 4, bool animateTiles = true}) {
    final n = currentGridCount;
    final nToSave = n < maximum ? n + 1 : minimum;
    _updateScrollPositions(tab, tab);
    NamidaNavigator.inst.navigateOff(tab.toWidget(nToSave, false, true), durationInMs: 500);
    return nToSave;
  }

  void initialize() {
    _assignScrollController(settings.selectedLibraryTab.value);
  }

  void _assignScrollController(LibraryTab tab) {
    scrollController.removeListener(() {});
    scrollController.dispose();
    scrollController = ScrollController(initialScrollOffset: tab.scrollPosition);
    scrollController.addListener(() {
      isBarVisibleMap[tab]?.value = scrollController.positions.lastOrNull?.userScrollDirection == ScrollDirection.forward;
    });
  }

  bool getIsSearchBoxVisible(LibraryTab tab) {
    if (isSearchBoxVisibleMap[tab] != null) {
      return isSearchBoxVisibleMap[tab]!.value;
    }
    isSearchBoxVisibleMap[tab] = false.obs;
    return isSearchBoxVisibleMap[tab]!.value;
  }

  bool getIsBarVisible(LibraryTab tab) {
    if (isBarVisibleMap[tab] != null) {
      return isBarVisibleMap[tab]!.value;
    }
    isBarVisibleMap[tab] = true.obs;
    return isBarVisibleMap[tab]!.value;
  }

  double getScrollPosition(LibraryTab tab) {
    if (scrollPositionsMap[tab] != null) {
      return scrollPositionsMap[tab]!;
    }
    scrollPositionsMap[tab] = 0.0;
    return scrollPositionsMap[tab]!;
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

  void toggleSearchMenu() {
    if (isGlobalSearchMenuShown.value) {
      hideSearchMenu();
    } else {
      showSearchMenu();
    }
  }

  void resetSearch() {
    searchTextEditingController.clear();
    SearchSortController.inst.searchAll('');
  }

  void unfocusKeyboard() => Get.focusScope?.unfocus();
  void focusKeyboard() => Get.focusScope?.requestFocus(focusNode);

  void switchSearchBoxVisibilty(LibraryTab libraryTab) {
    textSearchControllers[libraryTab] ??= TextEditingController();

    if (textSearchControllers[libraryTab]!.text == '') {
      final isCurrentyVisible = isSearchBoxVisibleMap[libraryTab]!.value;
      if (isCurrentyVisible) {
        _closeTextController(libraryTab);
      } else {
        _openTextController(libraryTab);
      }

      isSearchBoxVisibleMap[libraryTab]!.value = !isCurrentyVisible;
    }
  }

  void _closeTextController(LibraryTab libraryTab) {
    textSearchControllers[libraryTab]?.dispose();
    textSearchControllers.remove(libraryTab);
    unfocusKeyboard();
    isSearchBoxVisibleMap[libraryTab]!.value = false;
  }

  void _openTextController(LibraryTab libraryTab) {
    textSearchControllers[libraryTab] ??= TextEditingController();
    focusKeyboard();
  }

  void clearSearchTextField(LibraryTab libraryTab) {
    SearchSortController.inst.searchMedia('', libraryTab.toMediaType());
    isSearchBoxVisibleMap[libraryTab]!.value = true;
    _closeTextController(libraryTab);
  }
}

extension LibraryTabStuff on LibraryTab {
  ScrollController get scrollController => ScrollSearchController.inst.scrollController;
  TextEditingController? get textSearchController => ScrollSearchController.inst.textSearchControllers[this];
  double get scrollPosition => ScrollSearchController.inst.getScrollPosition(this);
  bool get isBarVisible => ScrollSearchController.inst.getIsBarVisible(this);
  bool get isSearchBoxVisible => ScrollSearchController.inst.getIsSearchBoxVisible(this);
  double get offsetOrZero => (ScrollSearchController.inst.scrollController.hasClients) ? scrollController.positions.lastOrNull?.pixels ?? 0.0 : 0.0;
  bool get shouldAnimateTiles => offsetOrZero == 0.0;
}
