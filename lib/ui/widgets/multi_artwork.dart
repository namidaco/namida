import 'package:drop_shadow/drop_shadow.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/ui/widgets/artwork.dart';

class MultiArtworks extends StatelessWidget {
  final List<Track> tracks;
  final double thumbnailSize;
  const MultiArtworks({super.key, required this.tracks, required this.thumbnailSize});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: thumbnailSize,
      width: thumbnailSize,
      child: tracks.length == 1
          ? ArtworkWidget(
              thumnailSize: thumbnailSize,
              track: tracks.elementAt(0),
              forceSquared: true,
              blur: 0,
              borderRadius: 0,
              cacheHeight: 480,
            )
          : tracks.length == 2
              ? Row(
                  children: [
                    ArtworkWidget(
                      thumnailSize: thumbnailSize / 2,
                      height: thumbnailSize,
                      track: tracks.elementAt(0),
                      forceSquared: true,
                      blur: 0,
                      borderRadius: 0,
                      cacheHeight: 480,
                    ),
                    ArtworkWidget(
                      thumnailSize: thumbnailSize / 2,
                      height: thumbnailSize,
                      track: tracks.elementAt(1),
                      forceSquared: true,
                      blur: 0,
                      borderRadius: 0,
                      cacheHeight: 480,
                    ),
                  ],
                )
              : tracks.length == 3
                  ? Row(
                      children: [
                        Column(
                          children: [
                            ArtworkWidget(
                              thumnailSize: thumbnailSize / 2,
                              track: tracks.elementAt(0),
                              forceSquared: true,
                              blur: 0,
                              borderRadius: 0,
                            ),
                            ArtworkWidget(
                              thumnailSize: thumbnailSize / 2,
                              track: tracks.elementAt(1),
                              forceSquared: true,
                              blur: 0,
                              borderRadius: 0,
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            ArtworkWidget(
                              thumnailSize: thumbnailSize / 2,
                              track: tracks.elementAt(2),
                              forceSquared: true,
                              blur: 0,
                              borderRadius: 0,
                              height: thumbnailSize,
                              cacheHeight: 480,
                            ),
                          ],
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Row(
                          children: [
                            ArtworkWidget(
                              thumnailSize: thumbnailSize / 2,
                              track: tracks.elementAt(0),
                              forceSquared: true,
                              blur: 0,
                              borderRadius: 0,
                            ),
                            ArtworkWidget(
                              thumnailSize: thumbnailSize / 2,
                              track: tracks.elementAt(1),
                              forceSquared: true,
                              blur: 0,
                              borderRadius: 0,
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            ArtworkWidget(
                              thumnailSize: thumbnailSize / 2,
                              track: tracks.elementAt(2),
                              forceSquared: true,
                              blur: 0,
                              borderRadius: 0,
                            ),
                            ArtworkWidget(
                              thumnailSize: thumbnailSize / 2,
                              track: tracks.elementAt(3),
                              forceSquared: true,
                              blur: 0,
                              borderRadius: 0,
                              // width: 100,
                            ),
                          ],
                        ),
                      ],
                    ),
    );
  }
}
