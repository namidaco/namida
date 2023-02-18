import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/ui/widgets/artwork.dart';

class MultiArtworkCard extends StatelessWidget {
  final List<Track> tracks;
  final String name;
  final int gridCount;

  const MultiArtworkCard({super.key, required this.tracks, required this.name, required this.gridCount});

  @override
  Widget build(BuildContext context) {
    const double horizontalPadding = 4.0;
    double thumnailSize = (Get.width / gridCount) - horizontalPadding * 2;
    final fontSize = 18.0 - (gridCount * 1.7);

    return GridTile(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 0.0, horizontal: horizontalPadding),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12.0.multipliedRadius)),
        child: Material(
          color: context.theme.cardColor,
          child: InkWell(
            highlightColor: const Color.fromARGB(60, 120, 120, 120),
            onLongPress: () {},
            onTap: () {},
            child: Column(
              children: [
                Hero(
                  tag: 'multi_artwork_$name$tracks',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                    child: MultiArtworks(
                      tracks: tracks,
                      thumbnailSize: thumnailSize,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    width: double.infinity,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (name != '')
                          Text(
                            name,
                            style: Get.textTheme.displayMedium?.copyWith(fontSize: fontSize),
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          [tracks.displayTrackKeyword, if (tracks.totalDuration != 0) tracks.totalDurationFormatted].join(' - '),
                          style: context.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            fontSize: fontSize * 0.85,
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
