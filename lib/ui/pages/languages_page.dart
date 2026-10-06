import 'package:flutter/material.dart';

import 'package:flutter_scrollbar_modified/flutter_scrollbar_modified.dart';
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
import 'package:namida/core/functions.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/expandable_box.dart';
import 'package:namida/ui/widgets/library/multi_artwork_card.dart';
import 'package:namida/ui/widgets/sliver_cross_axis_extent_builder.dart';
import 'package:namida/ui/widgets/sort_by_button.dart';

class LanguagesPage extends StatelessWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.PAGE_languages;

  final CountPerRow countPerRow;
  final bool animateTiles;
  final bool enableHero;

  const LanguagesPage({
    super.key,
    required this.countPerRow,
    this.animateTiles = true,
    required this.enableHero,
  });

  bool get _shouldAnimate => animateTiles && LibraryTab.languages.shouldAnimateTiles;

  ScrollbarThumbLabelResolver? _createThumbLabel() {
    final languages = SearchSortController.inst.languageSearchList.value;
    final labelOf = SearchSortController.inst.getLanguagesSortLabelResolver();
    return NamidaScrollbar.createListThumbLabel(languages, labelOf);
  }

  @override
  Widget build(BuildContext context) {
    const libraryTab = LibraryTab.languages;
    final scrollController = libraryTab.scrollController;
    final countPerRowResolved = countPerRow.resolve(context);

    const listHeader = ExpandableBoxEmptyAnimatedPadding(tab: libraryTab);

    return BackgroundWrapper(
      child: NamidaScrollbar(
        controller: scrollController,
        thumbLabel: _createThumbLabel,
        child: AnimationLimiter(
          child: Obx(
            (context) {
              final sort = settings.languageSorts.valueR.first;
              final sortReverse = settings.languageSortReversed.valueR;

              final sortTextIsUseless = sort == GroupSortType.title || sort == GroupSortType.numberOfTracks || sort == GroupSortType.duration;
              final extraTextResolver = sortTextIsUseless ? null : SearchSortController.inst.getLanguagesExtraTextResolver(sort);

              final finalLanguagesLength = SearchSortController.inst.languageSearchList.valueR.length;
              final totalLanguagesLength = Indexer.inst.mainMapLanguages.valueR.length;
              final leftText = finalLanguagesLength != totalLanguagesLength
                  ? '$finalLanguagesLength/${lang.countLanguages(count: totalLanguagesLength)}'
                  : lang.countLanguages(count: finalLanguagesLength);

              return ExpandableBoxColumn(
                tab: libraryTab,
                header: ExpandableBox(
                  enableHero: enableHero,
                  gridWidget: const ChangeGridCountWidget(
                    tab: libraryTab,
                  ),
                  isBarVisible: libraryTab.isBarVisible.valueR,
                  leftText: leftText,
                  onSearchBoxVisibilityChange: (newShow) => ScrollSearchController.inst.onSearchBoxVisibiltyChange(libraryTab, newShow),
                  onCloseButtonPressed: () => ScrollSearchController.inst.clearSearchTextField(libraryTab),
                  sortByMenuWidget: SortByMenu(
                    title: sort.toText(),
                    popupMenuChild: const SortByMenuLanguages(),
                    isCurrentlyReversed: sortReverse,
                    onReverseIconTap: () => SearchSortController.inst.sortMedia(MediaType.language, reverse: !settings.languageSortReversed.value),
                  ),
                  textField: CustomTextField(
                    textFieldController: libraryTab.textSearchControllerR,
                    textFieldHintText: lang.filterLanguages,
                    onTextFieldValueChanged: (value) => SearchSortController.inst.searchMedia(value, MediaType.language),
                  ),
                ),
                page: SmoothCustomScrollView(
                  controller: scrollController,
                  slivers: [
                    SliverToBoxAdapter(child: listHeader),
                    ObxPrefer(
                      enabled: sort.requiresHistory,
                      rx: HistoryController.inst.topTracksMapListens,
                      builder: (context, _) => SliverCrossAxisExtentBuilder(
                        builder: (context, crossAxisExtent) {
                          const childAspectRatio = 0.8;
                          final cardWidth = crossAxisExtent / countPerRowResolved;
                          final cardHeight = cardWidth / childAspectRatio;
                          return SliverGrid.builder(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: countPerRowResolved,
                              childAspectRatio: childAspectRatio,
                              mainAxisSpacing: 8.0,
                            ),
                            itemCount: SearchSortController.inst.languageSearchList.length,
                            itemBuilder: (context, i) {
                              final language = SearchSortController.inst.languageSearchList[i];
                              final tracks = language.getLanguagesTracks();
                              final topRightText = extraTextResolver?.call(language, tracks);
                              return AnimatingGrid(
                                countPerRowResolved: countPerRowResolved,
                                columnCount: SearchSortController.inst.languageSearchList.length,
                                position: i,
                                shouldAnimate: _shouldAnimate,
                                child: MultiArtworkCard(
                                  heroTag: 'language_$language',
                                  tracks: tracks,
                                  name: language,
                                  countPerRow: countPerRow,
                                  width: cardWidth,
                                  height: cardHeight,
                                  showMenuFunction: () => NamidaDialogs.inst.showGenreDialog(language, MediaType.language),
                                  onTap: () => NamidaOnTaps.inst.onGenreTap(language, MediaType.language),
                                  topRightText: topRightText,
                                ),
                              );
                            },
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
