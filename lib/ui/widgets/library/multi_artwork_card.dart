import 'package:flutter/material.dart';

import 'package:namida/class/track.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';
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
  final bool enableHero;

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
    this.enableHero = true,
  });

  @override
  Widget build(BuildContext context) {
    final thumbnailSize = dimensions.$1;
    final fontSize = dimensions.$2;

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
                MultiArtworks(
                  borderRadius: 12.0,
                  heroTag: heroTag,
                  disableHero: !enableHero,
                  tracks: tracks.toImageTracks(),
                  thumbnailSize: thumbnailSize,
                  iconSize: 92.0 - 14 * gridCount,
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
                            enabled: enableHero,
                            tag: 'line1_$heroTag',
                            child: Text(
                              name.overflow,
                              style: context.textTheme.displayMedium?.copyWith(fontSize: fontSize),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        NamidaHero(
                          enabled: enableHero,
                          tag: 'line2_$heroTag',
                          child: Text(
                            [
                              tracks.displayTrackKeyword,
                              tracks.totalDurationFormatted,
                            ].join(' - '),
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
