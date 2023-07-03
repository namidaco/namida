import 'package:flutter/material.dart';

import 'package:flutter_scrollbar_modified/flutter_scrollbar_modified.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get/get.dart';

import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/expandable_box.dart';
import 'package:namida/ui/widgets/library/artist_card.dart';
import 'package:namida/ui/widgets/library/artist_tile.dart';
import 'package:namida/ui/widgets/sort_by_button.dart';

class ArtistsPage extends StatelessWidget {
  final List<String>? artists;
  final int countPerRow;
  final bool animateTiles;
  const ArtistsPage({super.key, this.artists, required this.countPerRow, this.animateTiles = true});

  bool get _shouldAnimate => animateTiles && LibraryTab.artists.shouldAnimateTiles;

  @override
  Widget build(BuildContext context) {
    final finalArtists = artists ?? Indexer.inst.artistSearchList;
    final scrollController = LibraryTab.artists.scrollController;

    return BackgroundWrapper(
      child: CupertinoScrollbar(
        controller: scrollController,
        child: AnimationLimiter(
          child: Obx(
            () => Column(
              children: [
                ExpandableBox(
                  gridWidget: ChangeGridCountWidget(
                    currentCount: SettingsController.inst.artistGridCount.value,
                    onTap: () {
                      final newCount = ScrollSearchController.inst.animateChangingGridSize(LibraryTab.artists, countPerRow);
                      SettingsController.inst.save(artistGridCount: newCount);
                    },
                  ),
                  isBarVisible: LibraryTab.artists.isBarVisible,
                  showSearchBox: LibraryTab.artists.isSearchBoxVisible,
                  leftText: finalArtists.length.displayArtistKeyword,
                  onFilterIconTap: () => ScrollSearchController.inst.switchSearchBoxVisibilty(LibraryTab.artists),
                  onCloseButtonPressed: () => ScrollSearchController.inst.clearSearchTextField(LibraryTab.artists),
                  sortByMenuWidget: SortByMenu(
                    title: SettingsController.inst.artistSort.value.toText(),
                    popupMenuChild: const SortByMenuArtists(),
                    isCurrentlyReversed: SettingsController.inst.artistSortReversed.value,
                    onReverseIconTap: () => Indexer.inst.sortArtists(reverse: !SettingsController.inst.artistSortReversed.value),
                  ),
                  textField: CustomTextFiled(
                    textFieldController: LibraryTab.artists.textSearchController,
                    textFieldHintText: Language.inst.FILTER_ARTISTS,
                    onTextFieldValueChanged: (value) => Indexer.inst.searchArtists(value),
                  ),
                ),
                if (countPerRow == 1)
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: finalArtists.length,
                      padding: const EdgeInsets.only(bottom: kBottomPadding),
                      itemExtent: 65.0 + 2.0 * 9,
                      itemBuilder: (BuildContext context, int i) {
                        final artist = finalArtists[i];
                        return AnimatingTile(
                          position: i,
                          shouldAnimate: _shouldAnimate,
                          child: ArtistTile(
                            tracks: artist.getArtistTracks(),
                            name: artist,
                            albums: artist.getArtistAlbums(),
                          ),
                        );
                      },
                    ),
                  ),
                if (countPerRow > 1)
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: countPerRow,
                        childAspectRatio: 0.88,
                        mainAxisSpacing: 8.0,
                      ),
                      controller: scrollController,
                      itemCount: finalArtists.length,
                      padding: const EdgeInsets.only(bottom: kBottomPadding),
                      itemBuilder: (BuildContext context, int i) {
                        final artist = finalArtists[i];
                        return AnimatingGrid(
                          columnCount: finalArtists.length,
                          position: i,
                          shouldAnimate: _shouldAnimate,
                          child: ArtistCard(
                            name: artist,
                            artist: artist.getArtistTracks(),
                            gridCount: countPerRow,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
