import 'package:flutter/material.dart';

import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'package:namida/class/count_per_row.dart';
import 'package:namida/class/route.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/expandable_box.dart';
import 'package:namida/ui/widgets/library/album_card.dart';
import 'package:namida/ui/widgets/library/album_tile.dart';
import 'package:namida/ui/widgets/sort_by_button.dart';

class AlbumsPage extends StatelessWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.PAGE_albums;

  final RxList<String>? albumIdentifiers;
  final CountPerRow countPerRow;
  final bool animateTiles;
  final bool enableHero;

  const AlbumsPage({
    super.key,
    this.albumIdentifiers,
    required this.countPerRow,
    this.animateTiles = true,
    this.enableHero = true,
  });

  bool get _shouldAnimate => animateTiles && LibraryTab.albums.shouldAnimateTiles;

  @override
  Widget build(BuildContext context) {
    final scrollController = LibraryTab.albums.scrollController;
    final countPerRowResolved = countPerRow.resolve();

    return BackgroundWrapper(
      child: NamidaScrollbar(
        controller: scrollController,
        child: AnimationLimiter(
          child: ObxO(
            rx: albumIdentifiers ?? SearchSortController.inst.albumSearchList,
            builder: (context, finalAlbums) => Column(
              children: [
                Obx(
                  (context) => ExpandableBox(
                    enableHero: enableHero,
                    gridWidget: ChangeGridCountWidget(
                      currentCount: countPerRow,
                      forStaggered: settings.useAlbumStaggeredGridView.valueR,
                      onTap: () {
                        final newCount = ScrollSearchController.inst.animateChangingGridSize(LibraryTab.albums, countPerRow, animateTiles: false);
                        settings.save(albumGridCount: newCount);
                      },
                    ),
                    isBarVisible: LibraryTab.albums.isBarVisible.valueR,
                    showSearchBox: LibraryTab.albums.isSearchBoxVisible.valueR,
                    leftText: finalAlbums.length.displayAlbumKeyword,
                    onFilterIconTap: () => ScrollSearchController.inst.switchSearchBoxVisibilty(LibraryTab.albums),
                    onCloseButtonPressed: () => ScrollSearchController.inst.clearSearchTextField(LibraryTab.albums),
                    sortByMenuWidget: SortByMenu(
                      title: settings.albumSort.valueR.toText(),
                      popupMenuChild: () => const SortByMenuAlbums(),
                      isCurrentlyReversed: settings.albumSortReversed.valueR,
                      onReverseIconTap: () => SearchSortController.inst.sortMedia(MediaType.album, reverse: !settings.albumSortReversed.value),
                    ),
                    textField: () => CustomTextFiled(
                      textFieldController: LibraryTab.albums.textSearchController,
                      textFieldHintText: lang.FILTER_ALBUMS,
                      onTextFieldValueChanged: (value) => SearchSortController.inst.searchMedia(value, MediaType.album),
                    ),
                  ),
                ),
                Obx(
                  (context) {
                    settings.albumListTileHeight.valueR;
                    return countPerRowResolved == 1
                        ? Expanded(
                            child: ListView.builder(
                              controller: scrollController,
                              itemCount: finalAlbums.length,
                              itemExtent: settings.albumListTileHeight.valueR + 4.0 * 5,
                              padding: kBottomPaddingInsets,
                              itemBuilder: (BuildContext context, int i) {
                                final albumId = finalAlbums[i];
                                return AnimatingTile(
                                  position: i,
                                  shouldAnimate: _shouldAnimate,
                                  child: AlbumTile(
                                    identifier: albumId,
                                    album: albumId.getAlbumTracks(),
                                  ),
                                );
                              },
                            ),
                          )
                        : settings.useAlbumStaggeredGridView.valueR
                            ? Expanded(
                                child: MasonryGridView.builder(
                                  controller: scrollController,
                                  padding: kBottomPaddingInsets,
                                  itemCount: finalAlbums.length,
                                  mainAxisSpacing: 8.0,
                                  gridDelegate: SliverSimpleGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: countPerRow.resolve(),
                                  ),
                                  itemBuilder: (context, i) {
                                    final albumId = finalAlbums[i];
                                    return AnimatingGrid(
                                      columnCount: finalAlbums.length,
                                      position: i,
                                      shouldAnimate: _shouldAnimate,
                                      child: AlbumCard(
                                        identifier: albumId,
                                        album: albumId.getAlbumTracks(),
                                        staggered: true,
                                      ),
                                    );
                                  },
                                ),
                              )
                            : Expanded(
                                child: GridView.builder(
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: countPerRow.resolve(),
                                    childAspectRatio: 0.75,
                                    mainAxisSpacing: 8.0,
                                  ),
                                  controller: scrollController,
                                  itemCount: finalAlbums.length,
                                  padding: kBottomPaddingInsets,
                                  itemBuilder: (BuildContext context, int i) {
                                    final albumId = finalAlbums[i];
                                    return AnimatingGrid(
                                      columnCount: finalAlbums.length,
                                      position: i,
                                      shouldAnimate: _shouldAnimate,
                                      child: AlbumCard(
                                        identifier: albumId,
                                        album: albumId.getAlbumTracks(),
                                        staggered: false,
                                      ),
                                    );
                                  },
                                ),
                              );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
