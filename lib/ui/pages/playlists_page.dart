import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/pages/queues_page.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/expandable_box.dart';
import 'package:namida/ui/widgets/library/multi_artwork_card.dart';
import 'package:namida/ui/widgets/library/playlist_tile.dart';
import 'package:namida/ui/widgets/sort_by_button.dart';

class PlaylistsPage extends StatelessWidget {
  final int? countPerRow;
  final List<Track>? tracksToAdd;
  final bool displayTopRow;
  final bool disableBottomPadding;
  PlaylistsPage({
    super.key,
    this.countPerRow,
    this.tracksToAdd,
    this.displayTopRow = true,
    this.disableBottomPadding = false,
  });
  final ScrollController _scrollController = ScrollSearchController.inst.playlistScrollcontroller;
  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final playlistGridCount = countPerRow ?? SettingsController.inst.playlistGridCount.value;
        return CupertinoScrollbar(
          controller: _scrollController,
          child: AnimationLimiter(
            child: Column(
              children: [
                ExpandableBox(
                  gridWidget: ChangeGridCountWidget(
                    currentCount: SettingsController.inst.playlistGridCount.value,
                    onTap: () {
                      final n = SettingsController.inst.playlistGridCount.value;
                      if (n < 4) {
                        SettingsController.inst.save(playlistGridCount: n + 1);
                      } else {
                        SettingsController.inst.save(playlistGridCount: 1);
                      }
                    },
                  ),
                  isBarVisible: ScrollSearchController.inst.isPlaylistBarVisible.value,
                  showSearchBox: ScrollSearchController.inst.showPlaylistSearchBox.value,
                  leftText: PlaylistController.inst.playlistSearchList.length.displayPlaylistKeyword,
                  onFilterIconTap: () => ScrollSearchController.inst.switchPlaylistSearchBoxVisibilty(),
                  onCloseButtonPressed: () {
                    ScrollSearchController.inst.clearPlaylistSearchTextField();
                  },
                  sortByMenuWidget: SortByMenu(
                    title: SettingsController.inst.playlistSort.value.toText,
                    popupMenuChild: const SortByMenuPlaylist(),
                    isCurrentlyReversed: SettingsController.inst.playlistSortReversed.value,
                    onReverseIconTap: () {
                      PlaylistController.inst.sortPlaylists(reverse: !SettingsController.inst.playlistSortReversed.value);
                    },
                  ),
                  textField: CustomTextFiled(
                    textFieldController: PlaylistController.inst.playlistSearchController,
                    textFieldHintText: Language.inst.FILTER_PLAYLISTS,
                    onTextFieldValueChanged: (value) => PlaylistController.inst.searchPlaylists(value),
                  ),
                ),
                Expanded(
                  child: CustomScrollView(
                    controller: _scrollController,
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
                                    PlaylistController.inst.playlistList.displayPlaylistKeyword,
                                    style: Theme.of(context).textTheme.displayLarge,
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
                                  DefaultPlaylistCard(
                                    width: context.width / 2.4,
                                    colorScheme: Colors.grey,
                                    icon: Broken.refresh,
                                    title: Language.inst.HISTORY,
                                    playlist: namidaHistoryPlaylist,
                                    onTap: () => NamidaOnTaps.inst.onPlaylistTap(namidaHistoryPlaylist),
                                  ),
                                  DefaultPlaylistCard(
                                    width: context.width / 2.4,
                                    colorScheme: Colors.red,
                                    icon: Broken.heart,
                                    title: Language.inst.FAVOURITES,
                                    playlist: namidaFavouritePlaylist,
                                    onTap: () => NamidaOnTaps.inst.onPlaylistTap(namidaFavouritePlaylist),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12.0),
                              Column(
                                children: [
                                  DefaultPlaylistCard(
                                    width: context.width / 2.4,
                                    colorScheme: Colors.green,
                                    icon: Broken.award,
                                    title: Language.inst.MOST_PLAYED,
                                    playlist: namidaMostPlayedPlaylist,
                                    onTap: () => NamidaOnTaps.inst.onPlaylistTap(namidaMostPlayedPlaylist),
                                  ),
                                  DefaultPlaylistCard(
                                    width: context.width / 2.4,
                                    colorScheme: Colors.blue,
                                    icon: Broken.driver,
                                    title: Language.inst.QUEUES,
                                    text: QueueController.inst.queueList.length.toString(),
                                    onTap: () => Get.to(() => QueuesPage()),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      const SliverPadding(padding: EdgeInsets.only(top: 10.0)),
                      if (playlistGridCount == 1)
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final playlist = PlaylistController.inst.playlistSearchList[i];
                              return AnimatingTile(
                                position: i,
                                child: PlaylistTile(
                                  playlist: playlist,
                                  onTap: tracksToAdd != null
                                      ? () => PlaylistController.inst.addTracksToPlaylist(playlist.name, tracksToAdd!)
                                      : () => NamidaOnTaps.inst.onPlaylistTap(playlist),
                                ),
                              );
                            },
                            childCount: PlaylistController.inst.playlistSearchList.length,
                          ),
                        ),
                      if (playlistGridCount > 1)
                        SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: playlistGridCount,
                            childAspectRatio: 0.8,
                            mainAxisSpacing: 8.0,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final playlist = PlaylistController.inst.playlistSearchList[i];
                              return AnimatingGrid(
                                columnCount: PlaylistController.inst.playlistSearchList.length,
                                position: i,
                                child: MultiArtworkCard(
                                  heroTag: 'parent_playlist_artwork_${playlist.name}',
                                  tracks: playlist.tracks.map((e) => e.track).toList(),
                                  name: playlist.name.translatePlaylistName,
                                  gridCount: playlistGridCount,
                                  showMenuFunction: () => NamidaDialogs.inst.showPlaylistDialog(playlist),
                                  onTap: () => NamidaOnTaps.inst.onPlaylistTap(playlist),
                                ),
                              );
                            },
                            childCount: PlaylistController.inst.playlistSearchList.length,
                          ),
                        ),
                      if (!disableBottomPadding)
                        const SliverPadding(
                          padding: EdgeInsets.only(bottom: kBottomPadding),
                        )
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
