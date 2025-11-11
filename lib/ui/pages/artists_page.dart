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
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/expandable_box.dart';
import 'package:namida/ui/widgets/library/artist_card.dart';
import 'package:namida/ui/widgets/library/artist_tile.dart';
import 'package:namida/ui/widgets/sort_by_button.dart';

class ArtistsPage extends StatelessWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.PAGE_artists;

  final RxList<String>? artists;
  final CountPerRow countPerRow;
  final bool enableGridIconButton;
  final bool animateTiles;
  final bool enableHero;
  final MediaType? customType;

  const ArtistsPage({
    super.key,
    this.artists,
    required this.countPerRow,
    this.enableGridIconButton = true,
    this.animateTiles = true,
    required this.enableHero,
    this.customType,
  });

  bool get _shouldAnimate => animateTiles && LibraryTab.artists.shouldAnimateTiles;

  List<NamidaPopupItem> _getTypeChooserChildren() {
    void onTap(MediaType type) {
      GroupSortType? newArtistSort;
      final currentArtistSort = settings.artistSort.value;
      // -- automatically resorting by the new type
      switch (currentArtistSort) {
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
      settings.save(activeArtistType: type);
      SearchSortController.inst.sortMedia(type, groupSortBy: newArtistSort, reverse: null);
    }

    return [
      NamidaPopupItem(
        icon: Broken.microphone,
        title: lang.ARTIST,
        onTap: () => onTap(MediaType.artist),
      ),
      NamidaPopupItem(
        icon: Broken.user,
        title: lang.ALBUM_ARTIST,
        onTap: () => onTap(MediaType.albumArtist),
      ),
      NamidaPopupItem(
        icon: Broken.profile_2user,
        title: lang.COMPOSER,
        onTap: () => onTap(MediaType.composer),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final scrollController = LibraryTab.artists.scrollController;
    final countPerRowResolved = countPerRow.resolve(context);
    final artistTypeColor = context.theme.colorScheme.onSecondaryContainer.withValues(alpha: 0.8);

    return BackgroundWrapper(
      child: NamidaScrollbar(
        controller: scrollController,
        child: AnimationLimiter(
          child: ObxO(
            rx: artists ?? SearchSortController.inst.artistSearchList,
            builder: (context, finalArtists) => Obx(
              (context) {
                final artistTypeSettings = settings.activeArtistType.valueR;
                final artistType = customType ?? artistTypeSettings;
                final (String, String) artistTypeTextSinglePlural = switch (artistType) {
                  MediaType.artist => (lang.ARTIST, lang.ARTISTS),
                  MediaType.albumArtist => (lang.ALBUM_ARTIST, lang.ALBUM_ARTISTS),
                  MediaType.composer => (lang.COMPOSER, lang.COMPOSER),
                  _ => ('', ''),
                };
                String countToText(int count) => count.displayKeyword(artistTypeTextSinglePlural.$1, artistTypeTextSinglePlural.$2);
                final finalArtistsLength = finalArtists.length;
                final totalArtistsLength = Indexer.inst.getArtistMapFor(artistType).valueR.length;
                String artistLeftText = finalArtistsLength != totalArtistsLength ? '$finalArtistsLength/${countToText(totalArtistsLength)}' : countToText(finalArtistsLength);

                final sort = settings.artistSort.valueR;
                final sortReverse = settings.artistSortReversed.valueR;

                final sortTextIsUseless = sort == GroupSortType.artistsList ||
                    (countPerRowResolved == 1 && (sort == GroupSortType.albumsCount || sort == GroupSortType.numberOfTracks || sort == GroupSortType.duration));
                final extraTextResolver = sortTextIsUseless ? null : SearchSortController.inst.getGroupSortExtraTextResolver(sort);

                return Column(
                  children: [
                    ExpandableBox(
                      enableHero: enableHero,
                      gridWidget: enableGridIconButton
                          ? const ChangeGridCountWidget(
                              tab: LibraryTab.artists,
                            )
                          : null,
                      isBarVisible: LibraryTab.artists.isBarVisible.valueR,
                      showSearchBox: LibraryTab.artists.isSearchBoxVisible.valueR,
                      leftText: customType != null ? artistLeftText : '',
                      leftWidgets: customType != null
                          ? null
                          : [
                              NamidaPopupWrapper(
                                childrenDefault: _getTypeChooserChildren,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Broken.arrange_circle,
                                      size: 14.0,
                                      color: artistTypeColor,
                                    ),
                                    const SizedBox(width: 4.0),
                                    Text(
                                      artistLeftText,
                                      style: textTheme.displayMedium?.copyWith(
                                        color: artistTypeColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                      onFilterIconTap: () => ScrollSearchController.inst.switchSearchBoxVisibilty(LibraryTab.artists),
                      onCloseButtonPressed: () => ScrollSearchController.inst.clearSearchTextField(LibraryTab.artists),
                      sortByMenuWidget: SortByMenu(
                        title: sort.toText(),
                        popupMenuChild: () => const SortByMenuArtists(),
                        isCurrentlyReversed: sortReverse,
                        onReverseIconTap: () => SearchSortController.inst.sortMedia(settings.activeArtistType.value, reverse: !settings.artistSortReversed.value),
                      ),
                      textField: () => CustomTextFiled(
                        textFieldController: LibraryTab.artists.textSearchController,
                        textFieldHintText: lang.FILTER_ARTISTS,
                        onTextFieldValueChanged: (value) => SearchSortController.inst.searchMedia(value, settings.activeArtistType.value),
                      ),
                    ),
                    if (countPerRowResolved == 1)
                      Expanded(
                        child: ObxPrefer(
                          enabled: sort.requiresHistory,
                          rx: HistoryController.inst.topTracksMapListens,
                          builder: (context, _) => ListView.builder(
                            controller: scrollController,
                            itemCount: finalArtists.length,
                            padding: kBottomPaddingInsets,
                            itemExtent: 65.0 + 2.0 * 9,
                            itemBuilder: (BuildContext context, int i) {
                              final artist = finalArtists[i];
                              final tracks = artist.getArtistTracksFor(artistType);
                              return AnimatingTile(
                                position: i,
                                shouldAnimate: _shouldAnimate,
                                child: ArtistTile(
                                  tracks: tracks,
                                  name: artist,
                                  albums: tracks.toUniqueAlbums(),
                                  type: artistType,
                                  extraText: extraTextResolver?.call(tracks),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    if (countPerRowResolved > 1)
                      Expanded(
                        child: ObxPrefer(
                          enabled: sort.requiresHistory,
                          rx: HistoryController.inst.topTracksMapListens,
                          builder: (context, _) => GridView.builder(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: countPerRowResolved,
                              childAspectRatio: 0.88,
                              mainAxisSpacing: 8.0,
                            ),
                            controller: scrollController,
                            itemCount: finalArtists.length,
                            padding: kBottomPaddingInsets,
                            itemBuilder: (BuildContext context, int i) {
                              final artist = finalArtists[i];
                              final tracks = artist.getArtistTracksFor(artistType);
                              return AnimatingGrid(
                                columnCount: finalArtists.length,
                                position: i,
                                shouldAnimate: _shouldAnimate,
                                child: ArtistCard(
                                  name: artist,
                                  artist: tracks,
                                  type: artistType,
                                  bottomCenterText: extraTextResolver?.call(tracks),
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
      ),
    );
  }
}
