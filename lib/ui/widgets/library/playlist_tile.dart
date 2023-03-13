import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/playlist.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/ui/widgets/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/library/multi_artwork_container.dart';

class PlaylistTile extends StatelessWidget {
  final Playlist playlist;
  final void Function()? onTap;

  const PlaylistTile({
    super.key,
    required this.playlist,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const double playlistThumnailSize = 75;
    const double playlistTileHeight = 75;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          highlightColor: const Color.fromARGB(60, 120, 120, 120),
          onLongPress: () => NamidaDialogs.inst.showPlaylistDialog(playlist),
          onTap: onTap ?? () {},
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            height: playlistTileHeight + 14,
            child: Row(
              children: [
                MultiArtworkContainer(
                  heroTag: 'playlist_artwork_${playlist.id}',
                  size: playlistThumnailSize,
                  tracks: playlist.tracks.map((e) => e.track).toList(),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.name.translatePlaylistName,
                        style: Get.textTheme.displayMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        [playlist.tracks.map((e) => e.track).toList().displayTrackKeyword, playlist.date.dateFormatted].join(' • '),
                        style: Get.textTheme.displaySmall?.copyWith(fontSize: 13.7),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (playlist.modes.isNotEmpty)
                        Text(
                          playlist.modes.join(', ').overflow,
                          style: Get.textTheme.displaySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12.0),
                Text(
                  playlist.tracks.map((e) => e.track).toList().totalDurationFormatted,
                  style: Get.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 2.0),
                SizedBox(
                  height: 38.0,
                  width: 38.0,
                  child: RotatedBox(
                    quarterTurns: 1,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => NamidaDialogs.inst.showPlaylistDialog(playlist),
                      icon: const Icon(
                        Broken.more,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
