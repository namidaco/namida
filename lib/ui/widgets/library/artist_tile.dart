import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/ui/pages/albums_page.dart';
import 'package:namida/ui/widgets/artwork.dart';

class ArtistTile extends StatelessWidget {
  final List<Track> tracks;
  final String name;

  const ArtistTile({super.key, required this.tracks, required this.name});

  @override
  Widget build(BuildContext context) {
    double artistthumnailSize = 65;
    double artistTileHeight = 65;
    final albums = name.artistAlbums;
    final albumsList = albums.keys.toList();
    final albumTracks = albums.values.toList();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 4.0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular((0.2 * artistTileHeight).multipliedRadius)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          highlightColor: const Color.fromARGB(60, 120, 120, 120),
          // key: ValueKey(track),
          onLongPress: () {
            // stc.selectOrUnselect(track);
          },
          onTap: () {
            Get.to(
              // () => ArtistTracksPage(artist: tracks.toList(), name: name),
              () => AlbumsPage(albums: albums),
              //  duration: Duration(milliseconds: 300),
            );
          },
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 3.0),
            height: artistTileHeight + 14,
            child: Row(
              children: [
                const SizedBox(width: 8.0),
                Container(
                  // padding: const EdgeInsets.all(
                  //   0.0,
                  // ),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: context.theme.cardColor),
                  width: artistthumnailSize,
                  height: artistthumnailSize,
                  child: Hero(
                    tag: 'artist$name',
                    child: ArtworkWidget(
                      thumnailSize: artistthumnailSize,
                      track: tracks[0],
                      borderRadius: 64.0,
                      forceSquared: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Get.textTheme.displayMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Text(
                      //   [
                      //     tracks.toList().displayTrackKeyword,
                      //     tracks[0].year.yearFormatted,
                      //   ].join(' • '),
                      //   style: Get.textTheme.displayMedium?.copyWith(
                      //     fontWeight: FontWeight.w500,
                      //   ),
                      //   overflow: TextOverflow.ellipsis,
                      // ),
                      Text(
                        [
                          tracks.toList().displayTrackKeyword,
                          albumsList.length,
                          tracks[0].year.yearFormatted,
                        ].join(' • '),
                        style: Get.textTheme.displaySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        [
                          albumTracks.length,
                        ].join(' • '),
                        style: Get.textTheme.displaySmall?.copyWith(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  [
                    tracks.toList().totalDurationFormatted,
                  ].join(' - '),
                  style: Get.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(
                  height: 38.0,
                  width: 38.0,
                  child: RotatedBox(
                    quarterTurns: 1,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                      onPressed: () {},
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
