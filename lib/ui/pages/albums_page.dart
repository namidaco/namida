import 'package:flutter/material.dart';

import 'package:flutter_scrollbar_modified/flutter_scrollbar_modified.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';

import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/expandable_box.dart';
import 'package:namida/ui/widgets/library/album_card.dart';
import 'package:namida/ui/widgets/library/album_tile.dart';
import 'package:namida/ui/widgets/sort_by_button.dart';

class AlbumsPage extends StatelessWidget {
  final List<String>? albums;
  final int countPerRow;
  final bool animateTiles;
  final bool enableHero;

  const AlbumsPage({
    super.key,
    this.albums,
    required this.countPerRow,
    this.animateTiles = true,
    this.enableHero = true,
  });

  bool get _shouldAnimate => animateTiles && LibraryTab.albums.shouldAnimateTiles;

  @override
  Widget build(BuildContext context) {
    final finalAlbums = albums ?? SearchSortController.inst.albumSearchList;
    final scrollController = LibraryTab.albums.scrollController;

    return BackgroundWrapper(
      child: CupertinoScrollbar(
        controller: scrollController,
        child: AnimationLimiter(
          child: Column(
            children: [
              Obx(
                () => ExpandableBox(
                  enableHero: enableHero,
                  gridWidget: ChangeGridCountWidget(
                    currentCount: countPerRow,
                    forStaggered: SettingsController.inst.useAlbumStaggeredGridView.value,
                    onTap: () {
                      final newCount = ScrollSearchController.inst.animateChangingGridSize(LibraryTab.albums, countPerRow, animateTiles: false);
                      SettingsController.inst.save(albumGridCount: newCount);
                    },
                  ),
                  isBarVisible: LibraryTab.albums.isBarVisible,
                  showSearchBox: LibraryTab.albums.isSearchBoxVisible,
                  leftText: finalAlbums.length.displayAlbumKeyword,
                  onFilterIconTap: () => ScrollSearchController.inst.switchSearchBoxVisibilty(LibraryTab.albums),
                  onCloseButtonPressed: () => ScrollSearchController.inst.clearSearchTextField(LibraryTab.albums),
                  sortByMenuWidget: SortByMenu(
                    title: SettingsController.inst.albumSort.value.toText(),
                    popupMenuChild: const SortByMenuAlbums(),
                    isCurrentlyReversed: SettingsController.inst.albumSortReversed.value,
                    onReverseIconTap: () => SearchSortController.inst.sortMedia(MediaType.album, reverse: !SettingsController.inst.albumSortReversed.value),
                  ),
                  textField: CustomTextFiled(
                    textFieldController: LibraryTab.albums.textSearchController,
                    textFieldHintText: Language.inst.FILTER_ALBUMS,
                    onTextFieldValueChanged: (value) => SearchSortController.inst.searchMedia(value, MediaType.album),
                  ),
                ),
              ),
              Obx(
                () {
                  SettingsController.inst.albumListTileHeight.value;
                  return countPerRow == 1
                      ? Expanded(
                          child: ListView.builder(
                            controller: scrollController,
                            itemCount: finalAlbums.length,
                            itemExtent: SettingsController.inst.albumListTileHeight.value + 4.0 * 5,
                            padding: const EdgeInsets.only(bottom: kBottomPadding),
                            itemBuilder: (BuildContext context, int i) {
                              final albumName = finalAlbums[i];
                              return AnimatingTile(
                                position: i,
                                shouldAnimate: _shouldAnimate,
                                child: AlbumTile(
                                  name: albumName,
                                  album: albumName.getAlbumTracks(),
                                ),
                              );
                            },
                          ),
                        )
                      : SettingsController.inst.useAlbumStaggeredGridView.value
                          ? Expanded(
                              child: MasonryGridView.builder(
                                controller: scrollController,
                                padding: const EdgeInsets.only(bottom: kBottomPadding),
                                itemCount: finalAlbums.length,
                                mainAxisSpacing: 8.0,
                                gridDelegate: SliverSimpleGridDelegateWithFixedCrossAxisCount(crossAxisCount: countPerRow),
                                itemBuilder: (context, i) {
                                  final albumName = finalAlbums[i];
                                  return AnimatingGrid(
                                    columnCount: finalAlbums.length,
                                    position: i,
                                    shouldAnimate: _shouldAnimate,
                                    child: AlbumCard(
                                      name: albumName,
                                      album: albumName.getAlbumTracks(),
                                      staggered: true,
                                    ),
                                  );
                                },
                              ),
                            )
                          : Expanded(
                              child: GridView.builder(
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: countPerRow, childAspectRatio: 0.75, mainAxisSpacing: 8.0),
                                controller: scrollController,
                                itemCount: finalAlbums.length,
                                padding: const EdgeInsets.only(bottom: kBottomPadding),
                                itemBuilder: (BuildContext context, int i) {
                                  final albumName = finalAlbums[i];
                                  return AnimatingGrid(
                                    columnCount: finalAlbums.length,
                                    position: i,
                                    shouldAnimate: _shouldAnimate,
                                    child: AlbumCard(
                                      name: albumName,
                                      album: albumName.getAlbumTracks(),
                                      gridCountOverride: countPerRow,
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
    );
  }
}
