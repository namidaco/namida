import 'package:flutter/material.dart';

import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get/get.dart';

import 'package:namida/class/playlist.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/main.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/library/multi_artwork_container.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';

class PlaylisTracksPage extends StatelessWidget {
  final Playlist playlist;
  PlaylisTracksPage({super.key, required this.playlist});

  final RxBool shouldReorder = false.obs;
  @override
  Widget build(BuildContext context) {
    final isMostPlayedPlaylist = playlist.id == kPlaylistMostPlayed;
    return MainPageWrapper(
      actionsToAdd: [
        if (!isMostPlayedPlaylist)
          Obx(
            () => Tooltip(
              message: shouldReorder.value ? Language.inst.DISABLE_REORDERING : Language.inst.ENABLE_REORDERING,
              child: NamidaIconButton(
                icon: shouldReorder.value ? Broken.forward_item : Broken.lock_1,
                padding: const EdgeInsets.only(right: 14, left: 4.0),
                onPressed: () => shouldReorder.value = !shouldReorder.value,
              ),
            ),
          ),
        NamidaIconButton(
          icon: Broken.more_2,
          padding: const EdgeInsets.only(right: 14, left: 4.0),
          onPressed: () => NamidaDialogs.inst.showPlaylistDialog(playlist),
        ),
      ],
      child: AnimationLimiter(
        child: Obx(
          () {
            final rxplaylist = PlaylistController.inst.playlistList.firstWhere((element) => element == playlist);
            final finalTracks = isMostPlayedPlaylist ? PlaylistController.inst.topTracksMap.keys.toList() : rxplaylist.tracks.map((e) => e.track).toList();
            final topContainer = SubpagesTopContainer(
              title: playlist.name.translatePlaylistName,
              subtitle: [finalTracks.displayTrackKeyword, playlist.date.dateFormatted].join(' - '),
              thirdLineText: playlist.modes.isNotEmpty ? playlist.modes.join(', ') : '',
              imageWidget: MultiArtworkContainer(
                heroTag: 'playlist_artwork_${playlist.id}',
                size: Get.width * 0.35,
                tracks: finalTracks,
              ),
              tracks: finalTracks,
            );

            /// Top Music Playlist
            return isMostPlayedPlaylist
                ? ListView(
                    children: [
                      topContainer,
                      ...PlaylistController.inst.topTracksMap.entries
                          .map(
                            (track) => AnimatingTile(
                              position: PlaylistController.inst.topTracksMap.keys.toList().indexOf(track.key),
                              child: TrackTile(
                                index: track.value,
                                track: track.key,
                                queue: PlaylistController.inst.topTracksMap.keys.toList(),
                                playlist: rxplaylist,
                                trailingWidget: CircleAvatar(
                                  radius: 10.0,
                                  backgroundColor: context.theme.scaffoldBackgroundColor,
                                  child: Text(
                                    track.value.toString(),
                                    style: context.textTheme.displaySmall,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      kBottomPaddingWidget,
                    ],
                  )
                :

                /// Normal Tracks
                Column(
                    children: [
                      Expanded(
                        child: ReorderableListView(
                          header: topContainer,
                          buildDefaultDragHandles: shouldReorder.value,
                          onReorder: (oldIndex, newIndex) {
                            if (newIndex > oldIndex) {
                              newIndex -= 1;
                            }
                            final item = rxplaylist.tracks.elementAt(oldIndex);
                            PlaylistController.inst.removeTracksFromPlaylist(rxplaylist.id, [item]);
                            PlaylistController.inst.insertTracksInPlaylist(rxplaylist.id, [item], newIndex);
                          },
                          children: [
                            ...playlist.tracks
                                .asMap()
                                .entries
                                .map(
                                  (track) => AnimatingTile(
                                    key: ValueKey(track.key),
                                    position: track.key,
                                    child: FadeDismissible(
                                      key: UniqueKey(),
                                      direction: shouldReorder.value ? DismissDirection.horizontal : DismissDirection.none,
                                      onDismissed: (direction) => NamidaOnTaps.inst.onRemoveTrackFromPlaylist([track.value.track], playlist),
                                      child: Stack(
                                        alignment: Alignment.centerLeft,
                                        children: [
                                          TrackTile(
                                            index: track.key,
                                            track: track.value.track,
                                            queue: rxplaylist.tracks.map((e) => e.track).toList(),
                                            playlist: rxplaylist,
                                            draggableThumbnail: shouldReorder.value,
                                          ),
                                          Obx(() => ThreeLineSmallContainers(enabled: shouldReorder.value)),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            const SizedBox(
                              key: ValueKey("sizedbox"),
                              height: kBottomPadding,
                            )
                          ],
                        ),
                      ),
                    ],
                  );
          },
        ),
      ),
    );
  }
}

class ThreeLineSmallContainers extends StatelessWidget {
  final bool enabled;
  const ThreeLineSmallContainers({Key? key, required this.enabled}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(
        3,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.bounceIn,
          width: enabled ? 9.0 : 2.0,
          height: 1.2,
          margin: const EdgeInsets.symmetric(vertical: 1),
          color: context.theme.listTileTheme.iconColor?.withAlpha(120),
        ),
      ),
    );
  }
}
