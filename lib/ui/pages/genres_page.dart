import 'package:flutter/material.dart';

import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get/get.dart';

import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/expandable_box.dart';
import 'package:namida/ui/widgets/library/multi_artwork_card.dart';
import 'package:namida/ui/widgets/sort_by_button.dart';

class GenresPage extends StatelessWidget {
  final int countPerRow;
  final bool animateTiles;
  final bool enableHero;

  const GenresPage({
    super.key,
    required this.countPerRow,
    this.animateTiles = true,
    required this.enableHero,
  });

  bool get _shouldAnimate => animateTiles && LibraryTab.genres.shouldAnimateTiles;

  @override
  Widget build(BuildContext context) {
    final scrollController = LibraryTab.genres.scrollController;
    final cardDimensions = Dimensions.inst.getMultiCardDimensions(countPerRow);

    return BackgroundWrapper(
      child: NamidaScrollbar(
        controller: scrollController,
        child: AnimationLimiter(
          child: Obx(
            () => Column(
              children: [
                ExpandableBox(
                  enableHero: enableHero,
                  gridWidget: ChangeGridCountWidget(
                    currentCount: settings.genreGridCount.value,
                    onTap: () {
                      final newCount = ScrollSearchController.inst.animateChangingGridSize(LibraryTab.genres, countPerRow, minimum: 2);
                      settings.save(genreGridCount: newCount);
                    },
                  ),
                  isBarVisible: LibraryTab.genres.isBarVisible,
                  showSearchBox: LibraryTab.genres.isSearchBoxVisible,
                  leftText: SearchSortController.inst.genreSearchList.length.displayGenreKeyword,
                  onFilterIconTap: () => ScrollSearchController.inst.switchSearchBoxVisibilty(LibraryTab.genres),
                  onCloseButtonPressed: () => ScrollSearchController.inst.clearSearchTextField(LibraryTab.genres),
                  sortByMenuWidget: SortByMenu(
                    title: settings.genreSort.value.toText(),
                    popupMenuChild: const SortByMenuGenres(),
                    isCurrentlyReversed: settings.genreSortReversed.value,
                    onReverseIconTap: () => SearchSortController.inst.sortMedia(MediaType.genre, reverse: !settings.genreSortReversed.value),
                  ),
                  textField: CustomTextFiled(
                    textFieldController: LibraryTab.genres.textSearchController,
                    textFieldHintText: lang.FILTER_GENRES,
                    onTextFieldValueChanged: (value) => SearchSortController.inst.searchMedia(value, MediaType.genre),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: countPerRow, childAspectRatio: 0.8, mainAxisSpacing: 8.0),
                    controller: scrollController,
                    itemCount: SearchSortController.inst.genreSearchList.length,
                    padding: kBottomPaddingInsets,
                    itemBuilder: (BuildContext context, int i) {
                      final genre = SearchSortController.inst.genreSearchList[i];
                      return AnimatingGrid(
                        columnCount: SearchSortController.inst.genreSearchList.length,
                        position: i,
                        shouldAnimate: _shouldAnimate,
                        child: MultiArtworkCard(
                          dimensions: cardDimensions,
                          heroTag: 'genre_$genre',
                          tracks: genre.getGenresTracks(),
                          name: genre,
                          gridCount: countPerRow,
                          showMenuFunction: () => NamidaDialogs.inst.showGenreDialog(genre),
                          onTap: () => NamidaOnTaps.inst.onGenreTap(genre),
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
