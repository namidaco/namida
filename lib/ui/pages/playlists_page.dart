import 'package:flutter/material.dart';

import 'package:flutter_scrollbar_modified/flutter_scrollbar_modified.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/pages/queues_page.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/expandable_box.dart';
import 'package:namida/ui/widgets/library/multi_artwork_card.dart';
import 'package:namida/ui/widgets/library/playlist_tile.dart';
import 'package:namida/ui/widgets/sort_by_button.dart';

class PlaylistsPage extends StatelessWidget {
  final List<Track>? tracksToAdd;
  final bool displayTopRow;
  final bool disableBottomPadding;
  final int countPerRow;
  final bool animateTiles;

  const PlaylistsPage({
    super.key,
    this.tracksToAdd,
    this.displayTopRow = true,
    this.disableBottomPadding = false,
    required this.countPerRow,
    this.animateTiles = true,
  });

  bool get _shouldAnimate => animateTiles && LibraryTab.playlists.shouldAnimateTiles;

  @override
  Widget build(BuildContext context) {
    final scrollController = LibraryTab.playlists.scrollController;

    return BackgroundWrapper(
      child: CupertinoScrollbar(
        controller: scrollController,
        child: AnimationLimiter(
          child: Column(
            children: [
              Obx(
                () => ExpandableBox(
                  gridWidget: ChangeGridCountWidget(
                    currentCount: SettingsController.inst.playlistGridCount.value,
                    onTap: () {
                      final newCount = ScrollSearchController.inst.animateChangingGridSize(LibraryTab.playlists, countPerRow);
                      SettingsController.inst.save(playlistGridCount: newCount);
                    },
                  ),
                  isBarVisible: LibraryTab.playlists.isBarVisible,
                  showSearchBox: LibraryTab.playlists.isSearchBoxVisible,
                  leftText: SearchSortController.inst.playlistSearchList.length.displayPlaylistKeyword,
                  onFilterIconTap: () => ScrollSearchController.inst.switchSearchBoxVisibilty(LibraryTab.playlists),
                  onCloseButtonPressed: () => ScrollSearchController.inst.clearSearchTextField(LibraryTab.playlists),
                  sortByMenuWidget: SortByMenu(
                    title: SettingsController.inst.playlistSort.value.toText(),
                    popupMenuChild: const SortByMenuPlaylist(),
                    isCurrentlyReversed: SettingsController.inst.playlistSortReversed.value,
                    onReverseIconTap: () => SearchSortController.inst.sortMedia(MediaType.playlist, reverse: !SettingsController.inst.playlistSortReversed.value),
                  ),
                  textField: CustomTextFiled(
                    textFieldController: LibraryTab.playlists.textSearchController,
                    textFieldHintText: Language.inst.FILTER_PLAYLISTS,
                    onTextFieldValueChanged: (value) => SearchSortController.inst.searchMedia(value, MediaType.playlist),
                  ),
                ),
              ),
              Expanded(
                child: Obx(
                  () => CustomScrollView(
                    controller: scrollController,
                    slivers: [
                      if (displayTopRow)
                        SliverToBoxAdapter(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                const SizedBox(
                                  width: 12.0,
                                ),
                                Expanded(
                                  child: Text(
                                    PlaylistController.inst.playlistsMap.length.displayPlaylistKeyword,
                                    style: context.textTheme.displayLarge,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const FittedBox(
                                  child: GeneratePlaylistButton(),
                                ),
                                const SizedBox(
                                  width: 8.0,
                                ),
                                const FittedBox(
                                  child: CreatePlaylistButton(),
                                ),
                                const SizedBox(
                                  width: 8.0,
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SliverPadding(padding: EdgeInsets.only(top: 6.0)),

                      /// Default Playlists.
                      if (displayTopRow)
                        SliverToBoxAdapter(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Column(
                                children: [
                                  Obx(
                                    () => DefaultPlaylistCard(
                                      width: context.width / 2.4,
                                      colorScheme: Colors.grey,
                                      icon: Broken.refresh,
                                      title: Language.inst.HISTORY,
                                      text: HistoryController.inst.historyTracksLength.toString(),
                                      onTap: () => NamidaOnTaps.inst.onHistoryPlaylistTap(),
                                    ),
                                  ),
                                  Obx(
                                    () => DefaultPlaylistCard(
                                      width: context.width / 2.4,
                                      colorScheme: Colors.red,
                                      icon: Broken.heart,
                                      title: Language.inst.FAVOURITES,
                                      text: PlaylistController.inst.favouritesPlaylist.value.tracks.length.toString(),
                                      onTap: () => NamidaOnTaps.inst.onNormalPlaylistTap(k_PLAYLIST_NAME_FAV),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12.0),
                              Column(
                                children: [
                                  Obx(
                                    () => DefaultPlaylistCard(
                                      width: context.width / 2.4,
                                      colorScheme: Colors.green,
                                      icon: Broken.award,
                                      title: Language.inst.MOST_PLAYED,
                                      text: HistoryController.inst.topTracksMapListens.length.toString(),
                                      onTap: () => NamidaOnTaps.inst.onMostPlayedPlaylistTap(),
                                    ),
                                  ),
                                  Obx(
                                    () => DefaultPlaylistCard(
                                      width: context.width / 2.4,
                                      colorScheme: Colors.blue,
                                      icon: Broken.driver,
                                      title: Language.inst.QUEUES,
                                      text: QueueController.inst.queuesMap.value.length.toString(),
                                      onTap: () => NamidaNavigator.inst.navigateTo(const QueuesPage()),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      const SliverPadding(padding: EdgeInsets.only(top: 10.0)),
                      if (countPerRow == 1)
                        SliverFixedExtentList.builder(
                          itemCount: SearchSortController.inst.playlistSearchList.length,
                          itemExtent: Dimensions.playlistTileItemExtent,
                          itemBuilder: (context, i) {
                            final key = SearchSortController.inst.playlistSearchList[i];
                            final playlist = PlaylistController.inst.playlistsMap[key]!;
                            return AnimatingTile(
                              position: i,
                              shouldAnimate: _shouldAnimate,
                              child: PlaylistTile(
                                playlistName: key,
                                onTap: tracksToAdd != null
                                    ? () => PlaylistController.inst.addTracksToPlaylist(playlist, tracksToAdd!)
                                    : () => NamidaOnTaps.inst.onNormalPlaylistTap(key),
                              ),
                            );
                          },
                        ),
                      if (countPerRow > 1)
                        SliverGrid.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: countPerRow,
                            childAspectRatio: 0.8,
                            mainAxisSpacing: 8.0,
                          ),
                          itemCount: SearchSortController.inst.playlistSearchList.length,
                          itemBuilder: (context, i) {
                            final key = SearchSortController.inst.playlistSearchList[i];
                            final playlist = PlaylistController.inst.playlistsMap[key]!;
                            return AnimatingGrid(
                              columnCount: SearchSortController.inst.playlistSearchList.length,
                              position: i,
                              shouldAnimate: _shouldAnimate,
                              child: MultiArtworkCard(
                                heroTag: 'playlist_${playlist.name}',
                                tracks: playlist.tracks.toTracks(),
                                name: playlist.name.translatePlaylistName(),
                                gridCount: countPerRow,
                                showMenuFunction: () => NamidaDialogs.inst.showPlaylistDialog(key),
                                onTap: () => NamidaOnTaps.inst.onNormalPlaylistTap(key),
                              ),
                            );
                          },
                        ),
                      if (!disableBottomPadding)
                        const SliverPadding(
                          padding: EdgeInsets.only(bottom: kBottomPadding),
                        )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
