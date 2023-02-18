import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/multi_artwork_card.dart';
import 'package:namida/ui/widgets/library/playlist_tile.dart';

class PlaylistsPage extends StatelessWidget {
  final int countPerRow;
  // final void Function()? onTap;
  final List<Track>? tracksToAdd;
  final bool displayTopRow;
  PlaylistsPage({
    super.key,
    this.countPerRow = 2,
    this.tracksToAdd,
    this.displayTopRow = true,
  });
  // final ScrollController _scrollController = ScrollController();
  @override
  Widget build(BuildContext context) {
    return Obx(
      () => CupertinoScrollbar(
        child: AnimationLimiter(
          child: CustomScrollView(
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
                          child: CreatePlaylistButton(),
                        ),
                        const SizedBox(
                          width: 8.0,
                        ),
                      ],
                    ),
                  ),
                ),
              if (countPerRow == 1)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final playlist = PlaylistController.inst.playlistList[i];
                      return AnimationConfiguration.staggeredList(
                        position: i,
                        duration: const Duration(milliseconds: 400),
                        child: SlideAnimation(
                          verticalOffset: 25.0,
                          child: FadeInAnimation(
                            duration: const Duration(milliseconds: 400),
                            child: PlaylistTile(
                              playlist: playlist,
                              onTap: tracksToAdd != null ? () => PlaylistController.inst.addTracksToPlaylist(playlist.id, tracksToAdd!) : null,
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: PlaylistController.inst.playlistList.length,
                  ),
                ),
              if (countPerRow > 1)
                SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: countPerRow,
                    childAspectRatio: 0.8,
                    mainAxisSpacing: 8.0,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => AnimationConfiguration.staggeredGrid(
                      columnCount: PlaylistController.inst.playlistList.length,
                      position: i,
                      duration: const Duration(milliseconds: 400),
                      child: SlideAnimation(
                        verticalOffset: 25.0,
                        child: FadeInAnimation(
                          duration: const Duration(milliseconds: 400),
                          child: MultiArtworkCard(
                            tracks: PlaylistController.inst.playlistList[i].tracks,
                            name: PlaylistController.inst.playlistList[i].name,
                            gridCount: countPerRow,
                          ),
                        ),
                      ),
                    ),
                    childCount: PlaylistController.inst.playlistList.length,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
