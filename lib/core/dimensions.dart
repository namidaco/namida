import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/selected_tracks_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/youtube/youtube_miniplayer.dart';

class Dimensions {
  static Dimensions get inst => _instance;
  static final Dimensions _instance = Dimensions._internal();
  Dimensions._internal();

  final _kMiniplayerBottomPadding = 90.0;

  bool get shouldHideFAB {
    final fab = settings.floatingActionButton.value;
    final route = NamidaNavigator.inst.currentRoute?.route;
    final shouldHide = ScrollSearchController.inst.isGlobalSearchMenuShown.value
        ? false
        : fab == FABType.none ||
            route == RouteType.SETTINGS_page || // bcz no search
            route == RouteType.SETTINGS_subpage || // bcz no search
            route == RouteType.YOUTUBE_PLAYLIST_DOWNLOAD_SUBPAGE || // bcz has fab
            ((fab == FABType.shuffle || fab == FABType.play) && SelectedTracksController.inst.currentAllTracks.isEmpty) ||
            (settings.selectedLibraryTab.value == LibraryTab.tracks && LibraryTab.tracks.isBarVisible == false);
    return shouldHide;
  }

  /// + active miniplayer padding
  double get globalBottomPaddingEffective {
    return (Player.inst.currentQueueYoutube.isNotEmpty
            ? kYoutubeMiniplayerHeight
            : Player.inst.currentQueue.isNotEmpty
                ? _kMiniplayerBottomPadding
                : 0.0) +
        12.0;
  }

  /// + floating action button padding
  double get globalBottomPaddingFAB {
    return shouldHideFAB ? 0.0 : kFABHeight;
  }

  /// + active miniplayer padding
  /// + floating action button padding
  double get globalBottomPaddingTotal {
    return globalBottomPaddingFAB + globalBottomPaddingEffective;
  }

  static const tileBottomMargin = 4.0;
  static const tileBottomMargin6 = 6.0;
  static const _tileAdditionalMargin = 4.0;
  static const tileVerticalPadding = 4.0;
  static const totalVerticalDistance = tileBottomMargin + 2 * tileVerticalPadding;

  static const gridHorizontalPadding = 4.0;

  // -- YT --
  static const youtubeCardItemHeight = 24.0 * 3;
  static const youtubeCardItemVerticalPadding = 4.0;
  static double get youtubeCardItemExtent => youtubeCardItemHeight + tileBottomMargin + 2 * youtubeCardItemVerticalPadding;

  // -- Track Tile --
  double trackTileItemExtent = 0.0;

  // -- Album Tile --
  double albumTileItemExtent = 0.0;

  // -- Artist Tile --
  static const artistThumbnailSize = 64.0;
  static const _artistTileHeight = 64.0;
  static const artistTileItemExtent = _artistTileHeight + totalVerticalDistance;

  // -- Playlist Tile --
  static const playlistThumbnailSize = 74.0;
  static const _playlistTileHeight = 74.0;
  static const playlistTileItemExtent = _playlistTileHeight + totalVerticalDistance + 3 * _tileAdditionalMargin;

  // -- Queue Tile --
  static const queueThumbnailSize = 64.0;
  static const _queueTileHeight = 72.0;
  static const queueTileItemExtent = _queueTileHeight + tileBottomMargin6 + 2 * tileVerticalPadding + _tileAdditionalMargin;

  static const albumSearchGridCount = 4;
  static const artistSearchGridCount = 5;
  static const genreSearchGridCount = 4;
  static const playlistSearchGridCount = 4;
  static const albumInsideArtistGridCount = 4;

  /// {@macro card_dimensions}
  (double, double, double) getAlbumCardDimensions(int gridCount) {
    return _getSizes(gridCount, false);
  }

  /// {@macro card_dimensions}
  (double, double, double) getArtistCardDimensions(int gridCount) {
    return _getSizes(gridCount, true);
  }

  /// {@macro card_dimensions}
  (double, double, double) getMultiCardDimensions(int gridCount) {
    return _getSizes(gridCount, true);
  }

  void updateAllTileDimensions() {
    updateTrackTileDimensions();
    updateAlbumTileDimensions();
  }

  void updateTrackTileDimensions() {
    trackTileItemExtent = settings.trackListTileHeight.value + totalVerticalDistance;
    HistoryController.inst.calculateAllItemsExtentsInHistory();
  }

  void updateAlbumTileDimensions() {
    albumTileItemExtent = settings.albumListTileHeight.value + totalVerticalDistance;
  }

  (double, double, double) _getSizes(int gridCount, bool biggerFont) {
    final inverseGrid = 4 - gridCount;
    final fontSize = biggerFont ? (18.0 - (gridCount * 1.7)) : (16.0 - (gridCount * 1.8));
    final thumbnailSize = (Get.width / gridCount) - gridHorizontalPadding * 2;
    return (thumbnailSize, fontSize, 2.0 * inverseGrid);
  }

  /// {@template card_dimensions}
  /// $1: thumbnailSize.
  /// $2: fontSize.
  /// $3: size alternative.
  /// {@endtemplate}
}

EdgeInsets get kBottomPaddingInsets => EdgeInsets.only(bottom: Dimensions.inst.globalBottomPaddingTotal);
SizedBox get kBottomPaddingWidget => SizedBox(height: Dimensions.inst.globalBottomPaddingTotal);
SliverPadding get kBottomPaddingWidgetSliver => SliverPadding(padding: kBottomPaddingInsets);

// ---- Constant Values ----
const kHistoryDayHeaderHeight = 40.0;
const kHistoryDayListTopPadding = 6.0;
const kHistoryDayListBottomPadding = 12.0;

const kQueueBottomRowHeight = 48.0;
const kExpandableBoxHeight = 48.0;
const kFABHeight = 56.0;

const kHistoryDayHeaderHeightWithPadding = kHistoryDayHeaderHeight + kHistoryDayListTopPadding + kHistoryDayListBottomPadding;

// -- yt
const kYoutubeHistoryDayHeaderHeight = 40.0;
const kYoutubeHistoryDayListTopPadding = 6.0;
const kYoutubeHistoryDayListBottomPadding = 12.0;

const kYoutubeHistoryDayHeaderHeightWithPadding = kYoutubeHistoryDayHeaderHeight + kYoutubeHistoryDayListTopPadding + kYoutubeHistoryDayListBottomPadding;

const kYTQueueSheetMinHeight = 60.0;
