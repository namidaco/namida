import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get/get.dart';

import 'package:namida/class/playlist.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/library/multi_artwork_container.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';

import 'package:namida/main.dart';

class PlaylisTracksPage extends StatelessWidget {
  final Playlist playlist;
  const PlaylisTracksPage({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    return MainPageWrapper(
      actionsToAdd: [
        NamidaIconButton(
          icon: Broken.more_2,
          padding: const EdgeInsets.only(right: 14, left: 4.0),
          onPressed: () => NamidaDialogs.inst.showPlaylistDialog(playlist),
        )
      ],
      child: Obx(
        () {
          final rxplaylist = PlaylistController.inst.playlistList.firstWhere((element) => element == playlist);
          final finalTracks = playlist.id == kPlaylistTopMusic ? PlaylistController.inst.topTracksMap.keys.toList() : rxplaylist.tracks.map((e) => e.track).toList();
          return AnimationLimiter(
            child: ListView(
              children: [
                /// Top Container holding image and info and buttons
                SubpagesTopContainer(
                  title: playlist.name.translatePlaylistName,
                  subtitle: [finalTracks.displayTrackKeyword, playlist.date.dateFormatted].join(' - '),
                  thirdLineText: playlist.modes.isNotEmpty ? playlist.modes.join(', ') : '',
                  imageWidget: MultiArtworkContainer(
                    heroTag: 'playlist_artwork_${playlist.id}',
                    size: Get.width * 0.35,
                    tracks: finalTracks,
                  ),
                  tracks: finalTracks,
                ),

                /// Tracks for Top Music Playlist
                if (rxplaylist.id == kPlaylistTopMusic) ...[
                  ...PlaylistController.inst.topTracksMap.entries
                      .map(
                        (track) => AnimatingTile(
                          position: PlaylistController.inst.topTracksMap.keys.toList().indexOf(track.key),
                          child: TrackTile(
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
                ],

                /// Tracks
                if (rxplaylist.id != kPlaylistTopMusic)
                  ...rxplaylist.tracks
                      .asMap()
                      .entries
                      .map(
                        (track) => AnimatingTile(
                          position: track.key,
                          child: TrackTile(
                            track: track.value.track,
                            queue: rxplaylist.tracks.map((e) => e.track).toList(),
                            playlist: rxplaylist,
                          ),
                        ),
                      )
                      .toList(),
                kBottomPaddingWidget,
              ],
            ),
          );
        },
      ),
    );
  }
}
