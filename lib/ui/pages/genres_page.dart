import 'package:flutter/material.dart';

import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import 'package:namida/class/count_per_row.dart';
import 'package:namida/class/route.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
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

  List<NamidaPopupItem> _getTypeChooserChildren() {
    void onTap(MediaType type) {
      settings.save(activeGenreType: type);
      SearchSortController.inst.sortMedia(type, reverse: null);
    }

    return [
      NamidaPopupItem(
        icon: Broken.smileys,
        title: lang.genre,
        selected: MediaType.genre == settings.activeGenreType.value,
        onTap: () => onTap(MediaType.genre),
      ),
      NamidaPopupItem(
        icon: Broken.brush_1,
        title: lang.style,
        selected: MediaType.style == settings.activeGenreType.value,
        onTap: () => onTap(MediaType.style),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    const libraryTab = LibraryTab.genres;
    final scrollController = libraryTab.scrollController;
    final countPerRowResolved = countPerRow.resolve(context);
    final genreTypeColor = context.theme.colorScheme.onSecondaryContainer.withOpacityExt(0.8);

    const listHeader = ExpandableBoxEmptyAnimatedPadding(tab: libraryTab);

    return BackgroundWrapper(
      child: NamidaScrollbar(
        controller: scrollController,
        child: AnimationLimiter(
          child: Obx(
            (context) {
              final genreType = settings.activeGenreType.valueR;
              final sort = settings.genreSort.valueR;
              final sortReverse = settings.genreSortReversed.valueR;

              final sortTextIsUseless = sort == GroupSortType.genresList || sort == GroupSortType.numberOfTracks || sort == GroupSortType.duration;
              final extraTextResolver = sortTextIsUseless ? null : SearchSortController.inst.getGroupSortExtraTextResolver(sort);

              final String Function({required int count}) countToText = switch (genreType) {
                MediaType.style => lang.countStyles,
                _ => lang.countGenres,
              };
              final finalGenresLength = SearchSortController.inst.genreSearchList.valueR.length;
              final totalGenresLength = Indexer.inst.getGenreMapFor(genreType).valueR.length;
              String leftText = finalGenresLength != totalGenresLength ? '$finalGenresLength/${countToText(count: totalGenresLength)}' : countToText(count: finalGenresLength);

              return ExpandableBoxColumn(
                tab: libraryTab,
                header: ExpandableBox(
                  enableHero: enableHero,
                  gridWidget: const ChangeGridCountWidget(
                    tab: libraryTab,
                  ),
                  isBarVisible: libraryTab.isBarVisible.valueR,
                  leftText: '',
                  leftWidgets: [
                    NamidaPopupWrapper(
                      childrenDefault: _getTypeChooserChildren,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Broken.arrange_circle,
                            size: 14.0,
                            color: genreTypeColor,
                          ),
                          const SizedBox(width: 4.0),
                          Text(
                            leftText,
                            style: textTheme.displayMedium?.copyWith(
                              color: genreTypeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onSearchBoxVisibilityChange: (newShow) => ScrollSearchController.inst.onSearchBoxVisibiltyChange(libraryTab, newShow),
                  onCloseButtonPressed: () => ScrollSearchController.inst.clearSearchTextField(libraryTab),
                  sortByMenuWidget: SortByMenu(
                    title: sort.toText(),
                    popupMenuChild: const SortByMenuGenres(),
                    isCurrentlyReversed: sortReverse,
                    onReverseIconTap: () => SearchSortController.inst.sortMedia(settings.activeGenreType.value, reverse: !settings.genreSortReversed.value),
                  ),
                  textField: CustomTextField(
                    textFieldController: libraryTab.textSearchControllerUI,
                    textFieldHintText: lang.filterGenres,
                    onTextFieldValueChanged: (value) => SearchSortController.inst.searchMedia(value, settings.activeGenreType.value),
                  ),
                ),
                page: SmoothCustomScrollView(
                  controller: scrollController,
                  slivers: [
                    SliverToBoxAdapter(child: listHeader),
                    ObxPrefer(
                      enabled: sort.requiresHistory,
                      rx: HistoryController.inst.topTracksMapListens,
                      builder: (context, _) => SliverGrid.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: countPerRowResolved,
                          childAspectRatio: 0.8,
                          mainAxisSpacing: 8.0,
                        ),
                        itemCount: SearchSortController.inst.genreSearchList.length,
                        itemBuilder: (context, i) {
                          final genre = SearchSortController.inst.genreSearchList[i];
                          final tracks = genre.getGenresTracksFor(genreType);
                          final topRightText = extraTextResolver?.call(tracks);
                          return AnimatingGrid(
                            countPerRowResolved: countPerRowResolved,
                            columnCount: SearchSortController.inst.genreSearchList.length,
                            position: i,
                            shouldAnimate: _shouldAnimate,
                            child: MultiArtworkCard(
                              heroTag: genreType == MediaType.style ? 'style_$genre' : 'genre_$genre',
                              tracks: tracks,
                              name: genre,
                              countPerRow: countPerRow,
                              showMenuFunction: () => NamidaDialogs.inst.showGenreDialog(genre, genreType),
                              onTap: () => NamidaOnTaps.inst.onGenreTap(genre, genreType),
                              widgetsInStack: topRightText == null
                                  ? const []
                                  : [
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: NamidaBlurryContainer(
                                          child: Text(
                                            topRightText,
                                            style: textTheme.displaySmall?.copyWith(
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
                    kBottomPaddingWidgetSliver,
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
