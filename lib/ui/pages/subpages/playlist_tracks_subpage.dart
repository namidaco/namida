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
          return AnimationLimiter(
            child: ListView(
              children: [
                /// Top Container holding image and info and buttons
                SubpagesTopContainer(
                  title: playlist.name,
                  subtitle: [playlist.tracks.displayTrackKeyword, playlist.date.dateFormatted].join(' - '),
                  thirdLineText: playlist.modes.isNotEmpty ? playlist.modes.join(', ') : '',
                  imageWidget: MultiArtworkContainer(
                    heroTag: 'playlist_artwork_${playlist.id}',
                    size: Get.width / 3,
                    tracks: playlist.tracks,
                  ),
                  tracks: playlist.tracks,
                ),

                /// Tracks
                ...rxplaylist.tracks
                    .asMap()
                    .entries
                    .map(
                      (track) => AnimatingTile(
                        position: track.key,
                        child: TrackTile(
                          track: track.value,
                          queue: rxplaylist.tracks,
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
