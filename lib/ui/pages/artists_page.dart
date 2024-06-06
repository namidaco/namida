import 'package:flutter/material.dart';

import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:namida/core/utils.dart';

import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/expandable_box.dart';
import 'package:namida/ui/widgets/library/artist_card.dart';
import 'package:namida/ui/widgets/library/artist_tile.dart';
import 'package:namida/ui/widgets/sort_by_button.dart';

class ArtistsPage extends StatelessWidget {
  final List<String>? artists;
  final int countPerRow;
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
    final finalArtists = artists ?? SearchSortController.inst.artistSearchList.value;
    final scrollController = LibraryTab.artists.scrollController;
    final artistDimensions = Dimensions.inst.getArtistCardDimensions(countPerRow);

    final artistTypeColor = context.theme.colorScheme.onSecondaryContainer.withOpacity(0.8);
    return BackgroundWrapper(
      child: NamidaScrollbar(
        controller: scrollController,
        child: AnimationLimiter(
          child: Obx(
            () {
              final artistTypeSettings = settings.activeArtistType.valueR;
              final artistType = customType ?? artistTypeSettings;
              final artistTypeText = artistType.toText();
              final artistLeftText = finalArtists.length.displayKeyword(artistTypeText, artistTypeText);
              return Column(
                children: [
                  ExpandableBox(
                    enableHero: enableHero,
                    gridWidget: ChangeGridCountWidget(
                      currentCount: settings.artistGridCount.valueR,
                      onTap: () {
                        final newCount = ScrollSearchController.inst.animateChangingGridSize(LibraryTab.artists, countPerRow);
                        settings.save(artistGridCount: newCount);
                      },
                    ),
                    isBarVisible: LibraryTab.artists.isBarVisible.valueR,
                    showSearchBox: LibraryTab.artists.isSearchBoxVisible.valueR,
                    leftText: customType != null ? artistLeftText : '',
                    leftWidgets: customType != null
                        ? []
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
                                    style: context.textTheme.displayMedium?.copyWith(
                                      color: context.theme.colorScheme.onSecondaryContainer.withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                    onFilterIconTap: () => ScrollSearchController.inst.switchSearchBoxVisibilty(LibraryTab.artists),
                    onCloseButtonPressed: () => ScrollSearchController.inst.clearSearchTextField(LibraryTab.artists),
                    sortByMenuWidget: SortByMenu(
                      title: settings.artistSort.valueR.toText(),
                      popupMenuChild: () => const SortByMenuArtists(),
                      isCurrentlyReversed: settings.artistSortReversed.valueR,
                      onReverseIconTap: () => SearchSortController.inst.sortMedia(settings.activeArtistType.value, reverse: !settings.artistSortReversed.value),
                    ),
                    textField: () => CustomTextFiled(
                      textFieldController: LibraryTab.artists.textSearchController,
                      textFieldHintText: lang.FILTER_ARTISTS,
                      onTextFieldValueChanged: (value) => SearchSortController.inst.searchMedia(value, settings.activeArtistType.value),
                    ),
                  ),
                  if (countPerRow == 1)
                    Expanded(
                      child: ListView.builder(
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
                        padding: kBottomPaddingInsets,
                        itemBuilder: (BuildContext context, int i) {
                          final artist = finalArtists[i];
                          final tracks = artist.getArtistTracksFor(artistType);
                          return AnimatingGrid(
                            columnCount: finalArtists.length,
                            position: i,
                            shouldAnimate: _shouldAnimate,
                            child: ArtistCard(
                              dimensions: artistDimensions,
                              name: artist,
                              artist: tracks,
                              type: artistType,
                            ),
                          );
                        },
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
