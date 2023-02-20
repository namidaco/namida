import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/ui/pages/albums_page.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class ArtistCard extends StatelessWidget {
  final int? gridCountOverride;
  final String name;
  final List<Track> artist;

  ArtistCard({
    super.key,
    this.gridCountOverride,
    required this.name,
    required this.artist,
  });

  @override
  Widget build(BuildContext context) {
    final gridCount = gridCountOverride ?? 2;
    final fontSize = 16.0 - (gridCount * 1.8);
    // final shouldDisplayAlbumArtist = artist[0].albumArtist != '';
    return Container(
      width: Get.width / gridCount - 34.0,
      // margin: const EdgeInsets.symmetric(horizontal: 4.0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.0.multipliedRadius),
        boxShadow: [
          BoxShadow(
            color: context.theme.shadowColor.withAlpha(20),
            blurRadius: 12.0,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Material(
        // color: context.theme.cardColor,
        child: InkWell(
          highlightColor: const Color.fromARGB(60, 120, 120, 120),
          onLongPress: () {},
          onTap: () {},
          child: Column(
            mainAxisSize: MainAxisSize.min,
            // crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: 'album_artwork_${artist[0].path}',
                child: Container(
                  // padding: const EdgeInsets.all(8.0),
                  clipBehavior: Clip.antiAlias,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  child: ArtworkWidget(
                    thumnailSize: Get.width / gridCount,
                    track: artist[0],
                    borderRadius: 10.0,
                    forceSquared: true,
                    blur: 0,
                  ),
                ),
              ),
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: Get.width / gridCount - 30.0, minWidth: Get.width / gridCount - 30.0),
                          child: Column(
                            // crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 10.0),
                              Text(
                                name,
                                style: context.textTheme.displayMedium?.copyWith(fontSize: fontSize * 1.16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),

                              // if (album[0].albumArtist != '') ...[
                              //   const SizedBox(height: 2.0),
                              //   Text(
                              //     album[0].albumArtist.overflow,
                              //     style: context.textTheme.displaySmall,
                              //     maxLines: 1,
                              //     overflow: TextOverflow.ellipsis,
                              //   ),
                              // ],
                              const SizedBox(height: 2.0),
                              Text(
                                [
                                  artist.length.displayAlbumKeyword,
                                  artist.totalDurationFormatted,
                                ].join(' • '),
                                style: context.textTheme.displaySmall?.copyWith(fontSize: fontSize),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),

                              const SizedBox(height: 10.0),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8.0),
                      child: MoreIcon(
                        rotated: false,
                        onPressed: () {},
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
