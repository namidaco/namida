import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/expandable_box.dart';
import 'package:namida/ui/widgets/library/album_card.dart';
import 'package:namida/ui/widgets/library/album_tile.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/ui/widgets/settings/sort_by_button.dart';

class AlbumsPage extends StatelessWidget {
  final Map<String?, Set<Track>>? albums;
  AlbumsPage({super.key, this.albums});
  final ScrollController _scrollController = ScrollSearchController.inst.albumScrollcontroller.value;
  @override
  Widget build(BuildContext context) {
    return CupertinoScrollbar(
      controller: _scrollController,
      child: AnimationLimiter(
        child: Obx(
          () => Column(
            children: [
              ExpandableBox(
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
                leftText: Indexer.inst.albumSearchList.length.displayAlbumKeyword,
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
                  textFieldController: Indexer.inst.albumsSearchController.value,
                  textFieldHintText: Language.inst.FILTER_ALBUMS,
                  onTextFieldValueChanged: (value) => Indexer.inst.searchAlbums(value),
                ),
              ),
              Obx(
                () {
                  return SettingsController.inst.albumGridCount.value == 1
                      ? Expanded(
                          child: ListView.builder(
                            controller: _scrollController,
                            itemCount: albums?.length ?? Indexer.inst.albumSearchList.length,
                            padding: const EdgeInsets.only(bottom: kBottomPadding),
                            itemBuilder: (BuildContext context, int i) {
                              return AnimatingTile(
                                position: i,
                                child: AlbumTile(
                                  album: (albums ?? Indexer.inst.albumSearchList).entries.toList()[i].value.toList(),
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
                                itemCount: albums?.length ?? Indexer.inst.albumSearchList.length,
                                mainAxisSpacing: 8.0,
                                gridDelegate: SliverSimpleGridDelegateWithFixedCrossAxisCount(crossAxisCount: SettingsController.inst.albumGridCount.value),
                                itemBuilder: (context, i) {
                                  final album = (albums ?? Indexer.inst.albumSearchList).entries.toList()[i].value.toList();
                                  return AnimatingGrid(
                                    columnCount: Indexer.inst.albumSearchList.length,
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
                                itemCount: albums?.length ?? Indexer.inst.albumSearchList.length,
                                padding: const EdgeInsets.only(bottom: kBottomPadding),
                                itemBuilder: (BuildContext context, int i) {
                                  final album = (albums ?? Indexer.inst.albumSearchList).entries.toList()[i].value.toList();
                                  return AnimatingGrid(
                                    columnCount: Indexer.inst.albumSearchList.length,
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
      ),
    );
  }
}
