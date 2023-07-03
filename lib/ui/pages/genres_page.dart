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
import 'package:namida/core/functions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/expandable_box.dart';
import 'package:namida/ui/widgets/library/multi_artwork_card.dart';
import 'package:namida/ui/widgets/sort_by_button.dart';

class GenresPage extends StatelessWidget {
  final int countPerRow;
  const GenresPage({super.key, required this.countPerRow});

  ScrollController get _scrollController => LibraryTab.genres.scrollController;

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: CupertinoScrollbar(
        controller: _scrollController,
        child: AnimationLimiter(
          child: Obx(
            () => Column(
              children: [
                ExpandableBox(
                  gridWidget: ChangeGridCountWidget(
                    currentCount: SettingsController.inst.genreGridCount.value,
                    onTap: () {
                      final newCount = ScrollSearchController.inst.animateChangingGridSize(LibraryTab.genres, countPerRow, minimum: 2);
                      SettingsController.inst.save(genreGridCount: newCount);
                    },
                  ),
                  isBarVisible: LibraryTab.genres.isBarVisible,
                  showSearchBox: LibraryTab.genres.isSearchBoxVisible,
                  leftText: Indexer.inst.genreSearchList.length.displayGenreKeyword,
                  onFilterIconTap: () => ScrollSearchController.inst.switchSearchBoxVisibilty(LibraryTab.genres),
                  onCloseButtonPressed: () => ScrollSearchController.inst.clearSearchTextField(LibraryTab.genres),
                  sortByMenuWidget: SortByMenu(
                    title: SettingsController.inst.genreSort.value.toText(),
                    popupMenuChild: const SortByMenuGenres(),
                    isCurrentlyReversed: SettingsController.inst.genreSortReversed.value,
                    onReverseIconTap: () => Indexer.inst.sortGenres(reverse: !SettingsController.inst.genreSortReversed.value),
                  ),
                  textField: CustomTextFiled(
                    textFieldController: LibraryTab.genres.textSearchController,
                    textFieldHintText: Language.inst.FILTER_GENRES,
                    onTextFieldValueChanged: (value) => Indexer.inst.searchGenres(value),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: countPerRow, childAspectRatio: 0.8, mainAxisSpacing: 8.0),
                    controller: _scrollController,
                    itemCount: Indexer.inst.genreSearchList.length,
                    padding: const EdgeInsets.only(bottom: kBottomPadding),
                    itemBuilder: (BuildContext context, int i) {
                      final genre = Indexer.inst.genreSearchList[i];
                      return AnimatingGrid(
                        columnCount: Indexer.inst.genreSearchList.length,
                        position: i,
                        shouldAnimate: LibraryTab.genres.shouldAnimateTiles,
                        child: MultiArtworkCard(
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
