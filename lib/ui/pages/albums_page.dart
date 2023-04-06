import 'package:flutter/cupertino.dart';

import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';

import 'package:namida/class/group.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/expandable_box.dart';
import 'package:namida/ui/widgets/library/album_card.dart';
import 'package:namida/ui/widgets/library/album_tile.dart';
import 'package:namida/ui/widgets/sort_by_button.dart';

class AlbumsPage extends StatelessWidget {
  final List<Group>? albums;
  AlbumsPage({super.key, this.albums});
  final ScrollController _scrollController = ScrollSearchController.inst.albumScrollcontroller;
  @override
  Widget build(BuildContext context) {
    final finalAlbums = albums ?? Indexer.inst.albumSearchList;
    return CupertinoScrollbar(
      controller: _scrollController,
      child: AnimationLimiter(
        child: Column(
          children: [
            Obx(
              () => ExpandableBox(
                gridWidget: ChangeGridCountWidget(
                  currentCount: SettingsController.inst.albumGridCount.value,
                  forStaggered: SettingsController.inst.useAlbumStaggeredGridView.value,
                  onTap: () {
                    final n = SettingsController.inst.albumGridCount.value;
                    if (n < 4) {
                      SettingsController.inst.save(albumGridCount: n + 1);
                    } else {
                      SettingsController.inst.save(albumGridCount: 1);
                    }
                  },
                ),
                isBarVisible: ScrollSearchController.inst.isAlbumBarVisible.value,
                showSearchBox: ScrollSearchController.inst.showAlbumSearchBox.value,
                leftText: finalAlbums.length.displayAlbumKeyword,
                onFilterIconTap: () => ScrollSearchController.inst.switchAlbumSearchBoxVisibilty(),
                onCloseButtonPressed: () {
                  ScrollSearchController.inst.clearAlbumSearchTextField();
                },
                sortByMenuWidget: SortByMenu(
                  title: SettingsController.inst.albumSort.value.toText,
                  popupMenuChild: const SortByMenuAlbums(),
                  isCurrentlyReversed: SettingsController.inst.albumSortReversed.value,
                  onReverseIconTap: () {
                    Indexer.inst.sortAlbums(reverse: !SettingsController.inst.albumSortReversed.value);
                  },
                ),
                textField: CustomTextFiled(
                  textFieldController: Indexer.inst.albumsSearchController,
                  textFieldHintText: Language.inst.FILTER_ALBUMS,
                  onTextFieldValueChanged: (value) => Indexer.inst.searchAlbums(value),
                ),
              ),
            ),
            Obx(
              () {
                return SettingsController.inst.albumGridCount.value == 1
                    ? Expanded(
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount: finalAlbums.length,
                          itemExtent: SettingsController.inst.albumListTileHeight.value + 4.0 * 5,
                          padding: const EdgeInsets.only(bottom: kBottomPadding),
                          itemBuilder: (BuildContext context, int i) {
                            return AnimatingTile(
                              position: i,
                              child: AlbumTile(
                                album: finalAlbums[i].tracks,
                              ),
                            );
                          },
                        ),
                      )
                    : SettingsController.inst.useAlbumStaggeredGridView.value
                        ? Expanded(
                            child: MasonryGridView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.only(bottom: kBottomPadding),
                              itemCount: finalAlbums.length,
                              mainAxisSpacing: 8.0,
                              gridDelegate: SliverSimpleGridDelegateWithFixedCrossAxisCount(crossAxisCount: SettingsController.inst.albumGridCount.value),
                              itemBuilder: (context, i) {
                                final album = finalAlbums[i].tracks;
                                return AnimatingGrid(
                                  columnCount: finalAlbums.length,
                                  position: i,
                                  child: AlbumCard(
                                    album: album,
                                    staggered: true,
                                  ),
                                );
                              },
                            ),
                          )
                        : Expanded(
                            child: GridView.builder(
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: SettingsController.inst.albumGridCount.value, childAspectRatio: 0.75, mainAxisSpacing: 8.0),
                              controller: _scrollController,
                              itemCount: finalAlbums.length,
                              padding: const EdgeInsets.only(bottom: kBottomPadding),
                              itemBuilder: (BuildContext context, int i) {
                                final album = finalAlbums[i].tracks;
                                return AnimatingGrid(
                                  columnCount: finalAlbums.length,
                                  position: i,
                                  child: AlbumCard(
                                    album: album,
                                    gridCountOverride: SettingsController.inst.albumGridCount.value,
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
    );
  }
}
