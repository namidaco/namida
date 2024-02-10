import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class MultiArtworkCard extends StatelessWidget {
  final List<Track> tracks;
  final String name;
  final int gridCount;
  final String heroTag;
  final void Function()? onTap;
  final void Function()? showMenuFunction;
  final (double, double, double) dimensions;
  final List<Widget> widgetsInStack;

  const MultiArtworkCard({
    super.key,
    required this.tracks,
    required this.name,
    required this.gridCount,
    this.onTap,
    this.showMenuFunction,
    required this.heroTag,
    required this.dimensions,
    this.widgetsInStack = const [],
  });

  @override
  Widget build(BuildContext context) {
    final thumbnailSize = dimensions.$1;
    final fontSize = dimensions.$2.multipliedFontScale;

    return GridTile(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 0.0, horizontal: Dimensions.gridHorizontalPadding),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: context.theme.cardColor,
          borderRadius: BorderRadius.circular(12.0.multipliedRadius),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                NamidaHero(
                  tag: heroTag,
                  child: MultiArtworks(
                    borderRadius: 12.0,
                    heroTag: heroTag,
                    disableHero: true,
                    tracks: tracks.toImageTracks(),
                    thumbnailSize: thumbnailSize,
                    iconSize: 92.0 - 14 * gridCount,
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
                          NamidaHero(
                            tag: 'line1_$heroTag',
                            child: Text(
                              name.overflow,
                              style: context.textTheme.displayMedium?.copyWith(fontSize: fontSize),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        NamidaHero(
                          tag: 'line2_$heroTag',
                          child: Text(
                            [tracks.displayTrackKeyword, if (tracks.totalDurationInS != 0) tracks.totalDurationFormatted].join(' - '),
                            style: context.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                              fontSize: fontSize * 0.85,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned.fill(
              child: NamidaInkWell(
                onTap: onTap,
                onLongPress: showMenuFunction,
              ),
            ),
            ...widgetsInStack,
          ],
        ),
      ),
    );
  }
}
