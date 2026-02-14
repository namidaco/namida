// ignore_for_file: avoid_rx_value_getter_outside_obx
import 'package:flutter/material.dart';

import 'package:namida/class/count_per_row.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/youtube_miniplayer.dart';

class Dimensions {
  static Dimensions get inst => _instance;
  static final Dimensions _instance = Dimensions._internal();
  Dimensions._internal();

  bool get showNavigationAtSide => miniplayerIsWideScreen;
  bool get showSubpageInfoAtSide => availableAppContentWidth > 524.0;
  bool showSubpageInfoAtSideContext(BuildContext context) {
    context.width; // vip to rebuild
    return showSubpageInfoAtSide;
  }

  double availableAppContentWidthContext(BuildContext context) {
    context.width; // vip to rebuild
    return availableAppContentWidth;
  }

  double miniplayerMaxWidth = 0.0;
  double sideInfoMaxWidth = 0.0;
  double availableAppContentWidth = 0.0;
  bool miniplayerIsWideScreen = false;

  double getSettingsHorizontalMargin(BuildContext context) {
    if (context.width < 600) return 0.0;
    return 0.12 * calculateDialogHorizontalMargin(context, 0.0);
  }

  static double calculateDialogHorizontalMargin(BuildContext context, double minimum) {
    final screenWidth = context.width;
    final val = (screenWidth / 1000).clampDouble(0.0, 1.0);
    double percentage = 0.25 * val * val;
    percentage = percentage.clampDouble(0.0, 0.25);
    return (screenWidth * percentage).withMinimum(minimum);
  }

  bool get shouldHideFABR {
    final fab = settings.floatingActionButton.valueR;
    final currentRoute = NamidaNavigator.inst.currentRouteR;
    final route = currentRoute?.route;
    final shouldHide = ScrollSearchController.inst.isGlobalSearchMenuShown.valueR
        ? false
        : fab == FABType.none ||
              route == RouteType.SETTINGS_page || // bcz no search
              route == RouteType.SETTINGS_subpage || // bcz no search
              route == RouteType.YOUTUBE_PLAYLIST_DOWNLOAD_SUBPAGE || // bcz has fab
              route == RouteType.SUBPAGE_INDEXER_UPDATE_MISSING_TRACKS || // bcz has fab
              route == RouteType.YOUTUBE_USER_MANAGE_ACCOUNT_SUBPAGE || // bcz has middle button
              route == RouteType.YOUTUBE_USER_MANAGE_SUBSCRIPTION_SUBPAGE || // bcz bcz..
              ((fab == FABType.shuffle || fab == FABType.play) && currentRoute?.hasTracksInsideReactive() != true) ||
              (settings.extra.selectedLibraryTab.valueR == LibraryTab.tracks && LibraryTab.tracks.isBarVisible.valueR == false);
    return shouldHide;
  }

  static const _kMiniplayerBottomPadding = 90.0;

  /// + active miniplayer padding
  double get globalBottomPaddingEffectiveR {
    final currentItem = Player.inst.currentItem.valueR;
    return (currentItem is YoutubeID
            ? settings.youtube.youtubeStyleMiniplayer.valueR
                  ? kYoutubeMiniplayerHeight
                  : _kMiniplayerBottomPadding
            : currentItem is Selectable
            ? _kMiniplayerBottomPadding
            : 0.0) +
        12.0;
  }

  /// + floating action button padding
  double get globalBottomPaddingFABR {
    return shouldHideFABR ? 0.0 : kFABSize;
  }

  /// + active miniplayer padding
  /// + floating action button padding
  double get globalBottomPaddingTotalR {
    return globalBottomPaddingFABR + globalBottomPaddingEffectiveR;
  }

  static const globalBottomPaddingTotal = kFABSize + _kMiniplayerBottomPadding + 12.0;

  bool shouldAlbumBeSquared(BuildContext context) {
    final countPerRow = settings.mediaGridCounts.value.get(LibraryTab.albums);
    final albumGridCount = countPerRow.resolve(context);
    if (albumGridCount == 1) {
      return settings.forceSquaredAlbumThumbnail.value;
    } else if (albumGridCount > 1) {
      return !settings.useAlbumStaggeredGridView.value;
    }
    return false;
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
  static const youtubeCardItemExtent = youtubeCardItemHeight + tileBottomMargin + 2 * youtubeCardItemVerticalPadding;
  static const youtubeThumbnailHeight = youtubeCardItemHeight - youtubeCardItemVerticalPadding;
  static const youtubeThumbnailWidth = youtubeThumbnailHeight * 16 / 9;

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

  static const albumSearchGridCount = CountPerRow(4);
  static const artistSearchGridCount = CountPerRow(5);
  static const genreSearchGridCount = CountPerRow(4);
  static const playlistSearchGridCount = CountPerRow(4);
  static const albumInsideArtistGridCount = CountPerRow(4);

  void updateAllTileDimensions() {
    updateTrackTileDimensions();
    updateAlbumTileDimensions();
  }

  void updateTrackTileDimensions() {
    trackTileItemExtent = settings.trackListTileHeight.value + totalVerticalDistance;
  }

  void updateAlbumTileDimensions() {
    albumTileItemExtent = settings.albumListTileHeight.value + totalVerticalDistance;
  }
}

const kBottomPaddingInsets = EdgeInsets.only(bottom: Dimensions.globalBottomPaddingTotal);
const kBottomPaddingWidget = SizedBox(height: Dimensions.globalBottomPaddingTotal);
SliverPadding get kBottomPaddingWidgetSliver => SliverPadding(padding: kBottomPaddingInsets);

// ---- Constant Values ----
const kHistoryDayHeaderHeight = 40.0;
const kHistoryDayListTopPadding = 6.0;
const kHistoryDayListBottomPadding = 12.0;

const kQueueBottomRowHeight = 48.0;
const kExpandableBoxHeight = 48.0;
const kFABSize = 56.0;

const kHistoryDayHeaderHeightWithPadding = kHistoryDayHeaderHeight + kHistoryDayListTopPadding + kHistoryDayListBottomPadding;

// -- yt
const kYoutubeHistoryDayHeaderHeight = 40.0;
const kYoutubeHistoryDayListTopPadding = 6.0;
const kYoutubeHistoryDayListBottomPadding = 12.0;

const kYoutubeHistoryDayHeaderHeightWithPadding = kYoutubeHistoryDayHeaderHeight + kYoutubeHistoryDayListTopPadding + kYoutubeHistoryDayListBottomPadding;

const kYTQueueSheetMinHeight = 60.0;

const kDialogMaxWidth = 428.0;
