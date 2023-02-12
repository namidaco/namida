import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/ui/widgets/artwork.dart';

class GenreCard extends StatelessWidget {
  final List<Track> tracks;
  final String name;

  const GenreCard({super.key, required this.tracks, required this.name});

  @override
  Widget build(BuildContext context) {
    const double horizontalPadding = 6.0;
    double genrethumnailSize = (Get.width / 2) - horizontalPadding * 2;

    return GridTile(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2.0, horizontal: horizontalPadding),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12.0.multipliedRadius)),
        child: Material(
          color: context.theme.cardColor,
          child: InkWell(
            highlightColor: const Color.fromARGB(60, 120, 120, 120),
            // key: ValueKey(track),
            onLongPress: () {
              // stc.selectOrUnselect(track);
            },
            onTap: () {
              // Get.to(
              //   AlbumTracksPage(album: album),
              //   //  duration: Duration(milliseconds: 300),
              // );
            },
            child: Column(
              children: [
                Hero(
                  tag: 'genre_artwork_$name',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                    child: MultiArtworks(
                      tracks: tracks,
                      thumbnailSize: genrethumnailSize,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.0),
                    width: double.infinity,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      // mainAxisSize: MainAxisSize.max,
                      children: [
                        Text(
                          name,
                          style: Get.textTheme.displayMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          [tracks.displayTrackKeyword, tracks.totalDurationFormatted].join(' - '),
                          style: Get.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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
