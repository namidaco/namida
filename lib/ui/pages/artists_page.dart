import 'package:flutter/material.dart';

import 'package:flutter_scrollbar_modified/flutter_scrollbar_modified.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import 'package:namida/class/count_per_row.dart';
import 'package:namida/class/route.dart';
import 'package:namida/class/sort_chain.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/pages/discover_page.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/expandable_box.dart';
import 'package:namida/ui/widgets/library/artist_card.dart';
import 'package:namida/ui/widgets/library/artist_tile.dart';
import 'package:namida/ui/widgets/sliver_cross_axis_extent_builder.dart';
import 'package:namida/ui/widgets/sort_by_button.dart';

class ArtistsPage extends StatelessWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.PAGE_artists;

  final RxList<String>? artists;
  final CountPerRow countPerRow;
  final bool animateTiles;
  final bool enableHero;
  final MediaType? customType;

  const ArtistsPage({
    super.key,
    this.artists,
    required this.countPerRow,
    this.animateTiles = true,
    required this.enableHero,
    this.customType,
  });

  bool get _shouldAnimate => animateTiles && LibraryTab.artists.shouldAnimateTiles;

  List<NamidaPopupItem> _getTypeChooserChildren() {
    void onTap(MediaType type) {
      GroupSortType? newArtistSort;
      final currentSorting = settings.groupSortingOf(MediaType.artist);
      final firstEntry = currentSorting.entries.first;
      // -- automatically resorting by the new type
      switch (firstEntry.type) {
        case GroupSortType.artistsList:
        case GroupSortType.albumArtist:
        case GroupSortType.composer:
          newArtistSort = switch (type) {
            MediaType.artist => GroupSortType.artistsList,
            MediaType.albumArtist => GroupSortType.albumArtist,
            MediaType.composer => GroupSortType.composer,
            _ => null,
          };
        default:
          null;
      }
      SortChain<GroupSortType>? newSorting;
      if (newArtistSort != null) {
        final otherEntries = currentSorting.entries.skip(1).where((e) => e.type != newArtistSort);
        final newFirstEntry = SortEntry(newArtistSort, reverse: firstEntry.reverse);
        newSorting = currentSorting.copyWith(entries: [newFirstEntry, ...otherEntries]);
      }
      settings.activeArtistType.save(type);
      SearchSortController.inst.sortMedia(type, groupSorting: newSorting);
    }

    return [
      NamidaPopupItem(
        icon: MediaType.artist.toIcon(),
        title: lang.artist,
        selected: MediaType.artist == settings.activeArtistType.value,
        onTap: () => onTap(MediaType.artist),
      ),
      NamidaPopupItem(
        icon: MediaType.albumArtist.toIcon(),
        title: lang.albumArtist,
        selected: MediaType.albumArtist == settings.activeArtistType.value,
        onTap: () => onTap(MediaType.albumArtist),
      ),
      NamidaPopupItem(
        icon: MediaType.composer.toIcon(),
        title: lang.composer,
        selected: MediaType.composer == settings.activeArtistType.value,
        onTap: () => onTap(MediaType.composer),
      ),
      NamidaPopupItem(
        icon: Broken.hierarchy_3,
        title: lang.discoverPage,
        hasDividerAbove: true,
        onTap: const DiscoverPage().navigate,
      ),
    ];
  }

  ScrollbarThumbLabelResolver? _createThumbLabel() {
    final artistType = settings.activeArtistType.value;
    final artists = SearchSortController.inst.artistSearchList.value;
    final labelOf = SearchSortController.inst.getArtistsSortLabelResolver(artistType);
    return NamidaScrollbar.createListThumbLabel(artists, labelOf);
  }

  @override
  Widget build(BuildContext context) {
    const libraryTab = LibraryTab.artists;
    final scrollController = libraryTab.scrollController;
    final countPerRowResolved = countPerRow.resolve(context);
    final isCustomList = artists != null;

    const listHeader = ExpandableBoxEmptyAnimatedPadding(tab: libraryTab);

    return BackgroundWrapper(
      child: AnimationLimiter(
        child: ObxO(
          rx: artists ?? SearchSortController.inst.artistSearchList,
          builder: (context, finalArtists) => Obx(
            (context) {
              final artistTypeSettings = settings.activeArtistType.valueR;
              final artistType = customType ?? artistTypeSettings;

              final sorting = settings.groupSortingOfR(artistType);
              final sort = sorting.entries.first.type;

              final sortTextIsUseless =
                  sort == GroupSortType.artistsList ||
                  (countPerRowResolved == 1 && (sort == GroupSortType.albumsCount || sort == GroupSortType.numberOfTracks || sort == GroupSortType.duration));
              final extraTextResolver = sortTextIsUseless ? null : SearchSortController.inst.getArtistsExtraTextResolver(artistType, sort);

              final pageWidget = NamidaScrollbar(
                controller: scrollController,
                thumbLabel: isCustomList ? null : _createThumbLabel,
                child: SmoothCustomScrollView(
                  controller: scrollController,
                  slivers: [
                    if (!isCustomList) const SliverToBoxAdapter(child: listHeader),
                    countPerRowResolved == 1
                        ? ObxPrefer(
                            enabled: sort.requiresHistory,
                            rx: HistoryController.inst.topTracksMapListens,
                            builder: (context, _) => SliverFixedExtentList.builder(
                              itemCount: finalArtists.length,
                              itemExtent: 65.0 + 2.0 * 9,
                              itemBuilder: (context, i) {
                                final artist = finalArtists[i];
                                final tracks = artist.getArtistTracksFor(artistType);
                                return AnimatingTile(
                                  position: i,
                                  shouldAnimate: _shouldAnimate,
                                  allowTilting: true,
                                  child: ArtistTile(
                                    tracks: tracks,
                                    name: artist,
                                    albums: tracks.toUniqueAlbums(),
                                    type: artistType,
                                    extraText: extraTextResolver?.call(artist, tracks),
                                  ),
                                );
                              },
                            ),
                          )
                        : ObxPrefer(
                            enabled: sort.requiresHistory,
                            rx: HistoryController.inst.topTracksMapListens,
                            builder: (context, _) => SliverCrossAxisExtentBuilder(
                              builder: (context, crossAxisExtent) {
                                const childAspectRatio = 0.88;
                                final cardWidth = crossAxisExtent / countPerRowResolved;
                                final cardHeight = cardWidth / childAspectRatio;
                                return SliverGrid.builder(
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: countPerRowResolved,
                                    childAspectRatio: childAspectRatio,
                                    mainAxisSpacing: 8.0,
                                  ),
                                  itemCount: finalArtists.length,
                                  itemBuilder: (context, i) {
                                    final artist = finalArtists[i];
                                    final tracks = artist.getArtistTracksFor(artistType);
                                    return AnimatingGrid(
                                      countPerRowResolved: countPerRowResolved,
                                      columnCount: finalArtists.length,
                                      position: i,
                                      shouldAnimate: _shouldAnimate,
                                      child: ArtistCard(
                                        name: artist,
                                        artist: tracks,
                                        type: artistType,
                                        bottomCenterText: extraTextResolver?.call(artist, tracks),
                                        width: cardWidth,
                                        height: cardHeight,
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
              if (isCustomList) return pageWidget;

              final Function({required int count}) countToText = switch (artistType) {
                MediaType.artist => lang.countArtists,
                MediaType.albumArtist => lang.countAlbumArtists,
                MediaType.composer => lang.countComposers,
                _ => ({required int count}) => '',
              };
              final finalArtistsLength = finalArtists.length;
              final totalArtistsLength = Indexer.inst.getArtistMapFor(artistType).valueR.length;
              final artistLeftText = finalArtistsLength != totalArtistsLength
                  ? '$finalArtistsLength/${countToText(count: totalArtistsLength)}'
                  : countToText(count: finalArtistsLength);

              final sortReverse = sorting.reverse;
              final sortByMenu = SortByMenu(
                title: sort.toText(),
                popupMenuChild: const SortByMenuArtists(),
                isCurrentlyReversed: sortReverse,
                onReverseIconTap: () => SearchSortController.inst.sortMedia(settings.activeArtistType.value, reverse: !sortReverse),
              );

              return ExpandableBoxColumn(
                tab: libraryTab,
                header: ExpandableBox(
                  enableHero: enableHero,
                  gridWidget: const ChangeGridCountWidget(
                    tab: libraryTab,
                  ),
                  isBarVisible: libraryTab.isBarVisible.valueR,
                  leftText: '',
                  leftTextIcon: artistType.toIcon(),
                  leftWidgets: [
                    NamidaPopupWrapper(
                      childrenDefault: _getTypeChooserChildren,
                      childBuilder: (openMenu) => ExpandableBoxChip(
                        icon: artistType.toIcon(),
                        label: artistLeftText,
                        showArrow: true,
                        onTap: openMenu,
                      ),
                    ),
                  ],
                  onSearchBoxVisibilityChange: (newShow) => ScrollSearchController.inst.onSearchBoxVisibiltyChange(libraryTab, newShow),
                  onCloseButtonPressed: () => ScrollSearchController.inst.clearSearchTextField(libraryTab),
                  sortByMenuWidget: sortByMenu,
                  textFieldController: libraryTab.textSearchControllerR,
                  textFieldHintText: lang.filterArtists,
                  onTextFieldValueChanged: (value) => SearchSortController.inst.searchMedia(value, settings.activeArtistType.value),
                ),
                page: pageWidget,
              );
            },
          ),
        ),
      ),
    );
  }
}
