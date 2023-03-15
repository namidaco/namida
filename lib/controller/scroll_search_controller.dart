import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';

import 'package:get/get.dart';

import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/main.dart';

class ScrollSearchController extends GetxController {
  static final ScrollSearchController inst = ScrollSearchController();

  RxDouble miniPlayerHeight = 0.1.obs;

  RxBool isGlobalSearchMenuShown = false.obs;
  final TextEditingController searchTextEditingController = Indexer.inst.globalSearchController.value;
  final PageController homepageController = PageController(initialPage: SettingsController.inst.selectedLibraryTab.value.toInt);

  RxBool showTrackSearchBox = false.obs;
  RxBool showAlbumSearchBox = false.obs;
  RxBool showArtistSearchBox = false.obs;
  RxBool showGenreSearchBox = false.obs;
  RxBool showPlaylistSearchBox = false.obs;

  ScrollController trackScrollcontroller = ScrollController();
  ScrollController albumScrollcontroller = ScrollController();
  ScrollController artistScrollcontroller = ScrollController();
  ScrollController genreScrollcontroller = ScrollController();
  ScrollController playlistScrollcontroller = ScrollController();

  ScrollController queueScrollController = ScrollController();

  RxBool isTrackBarVisible = true.obs;
  RxBool isAlbumBarVisible = true.obs;
  RxBool isArtistBarVisible = true.obs;
  RxBool isGenreBarVisible = true.obs;
  RxBool isPlaylistBarVisible = true.obs;

  ScrollSearchController() {
    trackScrollcontroller.addListener(() {
      if (trackScrollcontroller.position.userScrollDirection == ScrollDirection.reverse) {
        isTrackBarVisible.value = false;
      }
      if (trackScrollcontroller.position.userScrollDirection == ScrollDirection.forward) {
        isTrackBarVisible.value = true;
      }
    });

    albumScrollcontroller.addListener(() {
      if (albumScrollcontroller.position.userScrollDirection == ScrollDirection.reverse) {
        isAlbumBarVisible.value = false;
      }
      if (albumScrollcontroller.position.userScrollDirection == ScrollDirection.forward) {
        isAlbumBarVisible.value = true;
      }
    });
    artistScrollcontroller.addListener(() {
      if (artistScrollcontroller.position.userScrollDirection == ScrollDirection.reverse) {
        isArtistBarVisible.value = false;
      }
      if (artistScrollcontroller.position.userScrollDirection == ScrollDirection.forward) {
        isArtistBarVisible.value = true;
      }
    });
    genreScrollcontroller.addListener(() {
      if (genreScrollcontroller.position.userScrollDirection == ScrollDirection.reverse) {
        isGenreBarVisible.value = false;
      }
      if (genreScrollcontroller.position.userScrollDirection == ScrollDirection.forward) {
        isGenreBarVisible.value = true;
      }
    });
    playlistScrollcontroller.addListener(() {
      if (playlistScrollcontroller.position.userScrollDirection == ScrollDirection.reverse) {
        isPlaylistBarVisible.value = false;
      }
      if (playlistScrollcontroller.position.userScrollDirection == ScrollDirection.forward) {
        isPlaylistBarVisible.value = true;
      }
    });
  }
  animatePageController(int animateTo, {bool shouldGoBack = false}) {
    SettingsController.inst.save(selectedLibraryTab: animateTo.toEnum);
    if (shouldGoBack) {
      Get.offAll(() => MainPageWrapper());
    } else {
      homepageController.animateToPage(animateTo, duration: const Duration(milliseconds: 400), curve: Curves.easeInOutQuart);
    }
    clearGlobalSearchAndCloseThingys();
    printInfo(info: animateTo.toEnum.toText);
  }

  clearGlobalSearchAndCloseThingys() {
    isGlobalSearchMenuShown.value = false;
    Indexer.inst.searchAll('');
  }

  /// Tracks
  void switchTrackSearchBoxVisibilty({bool forceHide = false, bool forceShow = false}) {
    if (forceHide) {
      showTrackSearchBox.value = false;
      return;
    }
    if (forceShow) {
      showTrackSearchBox.value = true;
      return;
    }
    if (Indexer.inst.tracksSearchController.value.text == '') {
      showTrackSearchBox.value = !showTrackSearchBox.value;
    } else {
      showTrackSearchBox.value = true;
    }
  }

  void clearTrackSearchTextField() {
    Indexer.inst.searchTracks('');
    showTrackSearchBox.value = false;
  }

  /// Albums
  void switchAlbumSearchBoxVisibilty({bool forceHide = false, bool forceShow = false}) {
    if (forceHide) {
      showAlbumSearchBox.value = false;
      return;
    }
    if (forceShow) {
      showAlbumSearchBox.value = true;
      return;
    }
    if (Indexer.inst.albumsSearchController.value.text == '') {
      showAlbumSearchBox.value = !showAlbumSearchBox.value;
    } else {
      showAlbumSearchBox.value = true;
    }
  }

  void clearAlbumSearchTextField() {
    Indexer.inst.searchAlbums('');
    showAlbumSearchBox.value = false;
  }

  /// Artists
  void switchArtistSearchBoxVisibilty({bool forceHide = false, bool forceShow = false}) {
    if (forceHide) {
      showArtistSearchBox.value = false;
      return;
    }
    if (forceShow) {
      showArtistSearchBox.value = true;
      return;
    }
    if (Indexer.inst.artistsSearchController.value.text == '') {
      showArtistSearchBox.value = !showArtistSearchBox.value;
    } else {
      showArtistSearchBox.value = true;
    }
  }

  void clearArtistSearchTextField() {
    Indexer.inst.searchArtists('');
    showArtistSearchBox.value = false;
  }

  /// Genres
  void switchGenreSearchBoxVisibilty({bool forceHide = false, bool forceShow = false}) {
    if (forceHide) {
      showGenreSearchBox.value = false;
      return;
    }
    if (forceShow) {
      showGenreSearchBox.value = true;
      return;
    }
    if (Indexer.inst.genresSearchController.value.text == '') {
      showGenreSearchBox.value = !showGenreSearchBox.value;
    } else {
      showGenreSearchBox.value = true;
    }
  }

  void clearGenreSearchTextField() {
    Indexer.inst.searchGenres('');
    showGenreSearchBox.value = false;
  }

  /// Playlists
  void switchPlaylistSearchBoxVisibilty({bool forceHide = false, bool forceShow = false}) {
    if (forceHide) {
      showPlaylistSearchBox.value = false;
      return;
    }
    if (forceShow) {
      showPlaylistSearchBox.value = true;
      return;
    }
    if (PlaylistController.inst.playlistSearchController.value.text == '') {
      showPlaylistSearchBox.value = !showPlaylistSearchBox.value;
    } else {
      showPlaylistSearchBox.value = true;
    }
  }

  void clearPlaylistSearchTextField() {
    PlaylistController.inst.searchPlaylists('');
    showPlaylistSearchBox.value = false;
  }

  void animateQueueToCurrentTrack([int? index]) {
    index ??= Player.inst.currentIndex.value;
    if (queueScrollController.hasClients) {
      queueScrollController.animateTo(
        (SettingsController.inst.trackListTileHeight.value * 1.15) * index - 120,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutQuint,
      );
    }
  }
}
