import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:get/get.dart';

import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';

class ScrollSearchController {
  static ScrollSearchController get inst => _instance;
  static final ScrollSearchController _instance = ScrollSearchController._internal();
  ScrollSearchController._internal();

  final RxDouble miniplayerHeightPercentage = 0.0.obs;
  final RxDouble miniplayerHeightPercentageQueue = 0.0.obs;

  final RxBool isGlobalSearchMenuShown = false.obs;
  final TextEditingController searchTextEditingController = Indexer.inst.globalSearchController;

  ScrollController queueScrollController = ScrollController();
  double get trackTileItemScrollOffsetInQueue => trackTileItemExtent * Player.inst.currentIndex.value - Get.height * 0.3;

  final Map<LibraryTab, RxBool> isSearchBoxVisibleMap = <LibraryTab, RxBool>{};
  final Map<LibraryTab, RxBool> isBarVisibleMap = <LibraryTab, RxBool>{};

  final Map<LibraryTab, ScrollController> scrollControllersMap = <LibraryTab, ScrollController>{};
  final Map<LibraryTab, double> scrollPositionsMap = {};

  final Map<LibraryTab, TextEditingController> textSearchControllers = {};

  final FocusNode focusNode = FocusNode();

  void animatePageController(LibraryTab tab) {
    final w = tab.toWidget();

    if (w.runtimeType == NamidaNavigator.inst.currentWidgetStack.lastOrNull.runtimeType) {
      tab.scrollController.animateTo(0.0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOutQuart);
      return;
    }

    final isPageToTheRight = tab.toInt() > SettingsController.inst.selectedLibraryTab.value.toInt();
    final transition = isPageToTheRight ? Transition.rightToLeft : Transition.leftToRight;

    _updateScrollPositions(SettingsController.inst.selectedLibraryTab.value, tab);
    SettingsController.inst.save(selectedLibraryTab: tab);
    NamidaNavigator.inst.navigateOffAll(w, transition: transition);
  }

  int animateChangingGridSize(LibraryTab tab, int currentGridCount, {int minimum = 1, int maximum = 4}) {
    final n = currentGridCount;
    final nToSave = n < maximum ? n + 1 : minimum;
    _updateScrollPositions(tab, tab);
    NamidaNavigator.inst.navigateOff(tab.toWidget(nToSave), durationInMs: 300);
    return nToSave;
  }

  void initialize() {
    _assignScrollController(SettingsController.inst.selectedLibraryTab.value);
  }

  void _assignScrollController(LibraryTab tab) {
    scrollControllersMap[tab]?.removeListener(() {});
    scrollControllersMap[tab] = ScrollController(initialScrollOffset: tab.scrollPosition);
    scrollControllersMap[tab]!.addListener(() {
      isBarVisibleMap[tab]!.value = scrollControllersMap[tab]!.position.userScrollDirection == ScrollDirection.forward;
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

  void showSearchMenu() {
    isGlobalSearchMenuShown.value = true;
  }

  void resetSearch() {
    searchTextEditingController.clear();
    Indexer.inst.searchAll('');
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
    if (libraryTab == LibraryTab.tracks) {
      Indexer.inst.searchTracks('');
    }
    if (libraryTab == LibraryTab.albums) {
      Indexer.inst.searchAlbums('');
    }
    if (libraryTab == LibraryTab.artists) {
      Indexer.inst.searchArtists('');
    }
    if (libraryTab == LibraryTab.genres) {
      Indexer.inst.searchGenres('');
    }
    if (libraryTab == LibraryTab.playlists) {
      PlaylistController.inst.searchPlaylists('');
    }
    isSearchBoxVisibleMap[libraryTab]!.value = true;
    _closeTextController(libraryTab);
  }

  void animateQueueToCurrentTrack() {
    if (queueScrollController.hasClients) {
      queueScrollController.animateTo(
        trackTileItemScrollOffsetInQueue,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutQuart,
      );
    }
  }
}

extension LibraryTabStuff on LibraryTab {
  ScrollController get scrollController => ScrollSearchController.inst.scrollControllersMap[this]!;
  TextEditingController? get textSearchController => ScrollSearchController.inst.textSearchControllers[this];
  double get scrollPosition => ScrollSearchController.inst.getScrollPosition(this);
  bool get isBarVisible => ScrollSearchController.inst.getIsBarVisible(this);
  bool get isSearchBoxVisible => ScrollSearchController.inst.getIsSearchBoxVisible(this);
  double get offsetOrZero => (ScrollSearchController.inst.scrollControllersMap[this]?.hasClients ?? false) ? scrollController.positions.lastOrNull?.pixels ?? 0.0 : 0.0;
  bool get shouldAnimateTiles => offsetOrZero == 0.0;
}
