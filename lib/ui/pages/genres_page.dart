import 'package:flutter/material.dart';

import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import 'package:namida/class/count_per_row.dart';
import 'package:namida/class/route.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/expandable_box.dart';
import 'package:namida/ui/widgets/library/multi_artwork_card.dart';
import 'package:namida/ui/widgets/sort_by_button.dart';

class GenresPage extends StatelessWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.PAGE_genres;

  final CountPerRow countPerRow;
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
    final countPerRowResolved = countPerRow.resolve(context);

    return BackgroundWrapper(
      child: NamidaScrollbar(
        controller: scrollController,
        child: AnimationLimiter(
          child: Obx(
            (context) {
              final sort = settings.genreSort.valueR;
              final sortReverse = settings.genreSortReversed.valueR;

              final sortTextIsUseless = sort == GroupSortType.genresList || sort == GroupSortType.numberOfTracks || sort == GroupSortType.duration;
              final extraTextResolver = sortTextIsUseless ? null : SearchSortController.inst.getGroupSortExtraTextResolver(sort);

              return Column(
                children: [
                  ExpandableBox(
                    enableHero: enableHero,
                    gridWidget: const ChangeGridCountWidget(
                      tab: LibraryTab.genres,
                    ),
                    isBarVisible: LibraryTab.genres.isBarVisible.valueR,
                    showSearchBox: LibraryTab.genres.isSearchBoxVisible.valueR,
                    leftText: SearchSortController.inst.genreSearchList.length.displayGenreKeyword,
                    onFilterIconTap: () => ScrollSearchController.inst.switchSearchBoxVisibilty(LibraryTab.genres),
                    onCloseButtonPressed: () => ScrollSearchController.inst.clearSearchTextField(LibraryTab.genres),
                    sortByMenuWidget: SortByMenu(
                      title: sort.toText(),
                      popupMenuChild: () => const SortByMenuGenres(),
                      isCurrentlyReversed: sortReverse,
                      onReverseIconTap: () => SearchSortController.inst.sortMedia(MediaType.genre, reverse: !settings.genreSortReversed.value),
                    ),
                    textField: () => CustomTextFiled(
                      textFieldController: LibraryTab.genres.textSearchController,
                      textFieldHintText: lang.FILTER_GENRES,
                      onTextFieldValueChanged: (value) => SearchSortController.inst.searchMedia(value, MediaType.genre),
                    ),
                  ),
                  Expanded(
                    child: ObxPrefer(
                      enabled: sort.requiresHistory,
                      rx: HistoryController.inst.topTracksMapListens,
                      builder: (context, _) => GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: countPerRowResolved,
                          childAspectRatio: 0.8,
                          mainAxisSpacing: 8.0,
                        ),
                        controller: scrollController,
                        itemCount: SearchSortController.inst.genreSearchList.length,
                        padding: kBottomPaddingInsets,
                        itemBuilder: (BuildContext context, int i) {
                          final genre = SearchSortController.inst.genreSearchList[i];
                          final tracks = genre.getGenresTracks();
                          final topRightText = extraTextResolver?.call(tracks);
                          return AnimatingGrid(
                            columnCount: SearchSortController.inst.genreSearchList.length,
                            position: i,
                            shouldAnimate: _shouldAnimate,
                            child: MultiArtworkCard(
                              heroTag: 'genre_$genre',
                              tracks: tracks,
                              name: genre,
                              countPerRow: countPerRow,
                              showMenuFunction: () => NamidaDialogs.inst.showGenreDialog(genre),
                              onTap: () => NamidaOnTaps.inst.onGenreTap(genre),
                              widgetsInStack: topRightText == null
                                  ? const []
                                  : [
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: NamidaBlurryContainer(
                                          child: Text(
                                            topRightText,
                                            style: context.textTheme.displaySmall?.copyWith(
                                              fontSize: 12.0,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            softWrap: false,
                                            overflow: TextOverflow.fade,
                                          ),
                                        ),
                                      ),
                                    ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
