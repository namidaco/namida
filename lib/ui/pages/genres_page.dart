import 'package:flutter/cupertino.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get/get.dart';

import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/selected_tracks_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/ui/widgets/expandable_box.dart';
import 'package:namida/ui/widgets/library/multi_artwork_card.dart';
import 'package:namida/ui/widgets/settings/sort_by_button.dart';

class GenresPage extends StatelessWidget {
  GenresPage({super.key});
  final ScrollController _scrollController = ScrollSearchController.inst.genreScrollcontroller.value;
  @override
  Widget build(BuildContext context) {
    const countPerRow = 2;
    return CupertinoScrollbar(
      controller: _scrollController,
      child: AnimationLimiter(
        child: Obx(
          () => Column(
            children: [
              ExpandableBox(
                isBarVisible: ScrollSearchController.inst.isGenreBarVisible.value,
                showSearchBox: ScrollSearchController.inst.showGenreSearchBox.value,
                leftText: Indexer.inst.genreSearchList.length.displayGenreKeyword,
                onFilterIconTap: () => ScrollSearchController.inst.switchGenreSearchBoxVisibilty(),
                onCloseButtonPressed: () {
                  ScrollSearchController.inst.clearGenreSearchTextField();
                },
                sortByMenuWidget: SortByMenu(
                  title: SettingsController.inst.genreSort.value.toText,
                  popupMenuChild: const SortByMenuGenres(),
                  isCurrentlyReversed: SettingsController.inst.genreSortReversed.value,
                  onReverseIconTap: () {
                    Indexer.inst.sortGenres(reverse: !SettingsController.inst.genreSortReversed.value);
                  },
                ),
                textField: CustomTextFiled(
                  textFieldController: Indexer.inst.genresSearchController.value,
                  textFieldHintText: Language.inst.FILTER_GENRES,
                  onTextFieldValueChanged: (value) => Indexer.inst.searchGenres(value),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: countPerRow, childAspectRatio: 0.8, mainAxisSpacing: 8.0),
                  controller: _scrollController,
                  itemCount: Indexer.inst.genreSearchList.length,
                  padding: EdgeInsets.only(bottom: SelectedTracksController.inst.bottomPadding.value),
                  itemBuilder: (BuildContext context, int i) {
                    final genre = Indexer.inst.genreSearchList.entries.toList()[i];
                    return AnimationConfiguration.staggeredGrid(
                      columnCount: Indexer.inst.genreSearchList.length,
                      position: i,
                      duration: const Duration(milliseconds: 400),
                      child: SlideAnimation(
                        verticalOffset: 25.0,
                        child: FadeInAnimation(
                          duration: const Duration(milliseconds: 400),
                          child: MultiArtworkCard(
                            tracks: genre.value.toList(),
                            name: genre.key,
                            gridCount: countPerRow,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
