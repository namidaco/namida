import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';

class Dimensions {
  static Dimensions get inst => _instance;
  static final Dimensions _instance = Dimensions._internal();
  Dimensions._internal();

  RxList<double> allItemsExtentsHistory = <double>[].obs;

  static const tileBottomMargin = 4.0;
  static const tileBottomMargin6 = 6.0;
  static const _tileAdditionalMargin = 4.0;
  static const _tileVerticalPadding = 4.0;
  static const totalVerticalDistance = tileBottomMargin + 2 * _tileVerticalPadding;

  static const gridHorizontalPadding = 4.0;

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
  static const queueTileItemExtent = _queueTileHeight + tileBottomMargin6 + 2 * _tileVerticalPadding + _tileAdditionalMargin;

  /// {@macro card_dimensions}
  (double, double, double) albumCardDimensions = (0.0, 0.0, 0.0);

  /// {@macro card_dimensions}
  (double, double, double) artistCardDimensions = (0.0, 0.0, 0.0);

  /// {@macro card_dimensions}
  (double, double, double) multiCardDimensions = (0.0, 0.0, 0.0);

  static const albumSearchGridCount = 3;
  static const artistSearchGridCount = 5;
  static const albumInsideArtistGridCount = 4;

  void updateDimensions(LibraryTab tab, {int? gridOverride}) {
    switch (tab) {
      case LibraryTab.albums:
        _updateAlbumDimensions(gridOverride);
      case LibraryTab.artists:
        _updateArtistDimensions(gridOverride);
      case LibraryTab.genres || LibraryTab.playlists:
        _updateMultiDimensions(tab, gridOverride);
      default:
        null;
    }
    updateTrackTileDimensions();
    updateAlbumTileDimensions();
  }

  void updateSearchDimensions(bool isOpen) {
    _updateAlbumDimensions(isOpen ? albumSearchGridCount : null);
    _updateArtistDimensions(isOpen ? artistSearchGridCount : null);
  }

  void updateTrackTileDimensions() {
    trackTileItemExtent = SettingsController.inst.trackListTileHeight.value + totalVerticalDistance;
    calculateAllItemsExtentsInHistory();
  }

  void updateAlbumTileDimensions() {
    albumTileItemExtent = SettingsController.inst.albumListTileHeight.value + totalVerticalDistance;
  }

  void _updateAlbumDimensions(int? gridOverride) {
    final gridCount = gridOverride ?? SettingsController.inst.albumGridCount.value;
    albumCardDimensions = _getSizes(gridCount, false);
  }

  void _updateArtistDimensions(int? gridOverride) {
    final gridCount = gridOverride ?? SettingsController.inst.artistGridCount.value;
    artistCardDimensions = _getSizes(gridCount, true);
  }

  void _updateMultiDimensions(LibraryTab tab, int? gridOverride) {
    int getGridInSett() {
      if (tab == LibraryTab.genres) {
        return SettingsController.inst.genreGridCount.value;
      }
      if (tab == LibraryTab.playlists) {
        return SettingsController.inst.playlistGridCount.value;
      }
      return 0;
    }

    final gridCount = gridOverride ?? getGridInSett();
    multiCardDimensions = _getSizes(gridCount, true);
  }

  (double, double, double) _getSizes(int gridCount, bool biggerFont) {
    final inverseGrid = 4 - gridCount;
    final fontSize = biggerFont ? (18.0 - (gridCount * 1.7)) : (16.0 - (gridCount * 1.8));
    final thumbnailSize = (Get.width / gridCount) - gridHorizontalPadding * 2;
    return (thumbnailSize, fontSize, 2.0 * inverseGrid);
  }

  void calculateAllItemsExtentsInHistory() {
    final tie = Dimensions.inst.trackTileItemExtent;
    allItemsExtentsHistory
      ..clear()
      ..addAll(HistoryController.inst.historyMap.value.entries.map(
        (e) => kHistoryDayHeaderHeightWithPadding + (e.value.length * tie),
      ));
  }

  /// {@template card_dimensions}
  /// $1: thumbnailSize.
  /// $2: fontSize.
  /// $3: size alternative.
  /// {@endtemplate}
}

// ---- Constant Values ----

const kBottomPadding = 102.0;
const kBottomPaddingWidget = SizedBox(height: 102.0);

const kHistoryDayHeaderHeight = 40.0;
const kHistoryDayListTopPadding = 6.0;
const kHistoryDayListBottomPadding = 12.0;

const kHistoryDayHeaderHeightWithPadding = kHistoryDayHeaderHeight + kHistoryDayListTopPadding + kHistoryDayListBottomPadding;
