import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/class/playlist.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/ui/widgets/artwork.dart';

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
    double playlistThumnailSize = 75;
    double playlistTileHeight = 75;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3.0),
      child: Material(
        child: InkWell(
          highlightColor: const Color.fromARGB(60, 120, 120, 120),
          onLongPress: () {},
          onTap: onTap ?? () {},
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            height: playlistTileHeight + 14,
            child: Row(
              children: [
                Hero(
                  tag: 'playlist_artwork_${playlist.date}',
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12.0),
                    padding: const EdgeInsets.all(3.0),
                    width: playlistThumnailSize,
                    height: playlistThumnailSize,
                    decoration: BoxDecoration(color: context.theme.cardTheme.color?.withAlpha(180), borderRadius: BorderRadius.circular(16.0.multipliedRadius), boxShadow: [
                      BoxShadow(
                        color: context.theme.shadowColor,
                        blurRadius: 8,
                        offset: const Offset(0, 2.0),
                      )
                    ]),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                      child: MultiArtworks(
                        tracks: playlist.tracks,
                        thumbnailSize: playlistThumnailSize - 6.0,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.name,
                        style: Get.textTheme.displayMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        playlist.tracks.displayTrackKeyword,
                        style: Get.textTheme.displaySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 38.0,
                  width: 38.0,
                  child: RotatedBox(
                    quarterTurns: 1,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        PlaylistController.inst.removePlaylist(playlist);
                      },
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
