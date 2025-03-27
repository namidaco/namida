import 'dart:io';

import 'package:flutter/material.dart';

import 'package:namida/class/count_per_row.dart';
import 'package:namida/class/track.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class MultiArtworkCard extends StatelessWidget {
  final List<Track> tracks;
  final String name;
  final CountPerRow countPerRow;
  final String heroTag;
  final void Function()? onTap;
  final void Function()? showMenuFunction;
  final List<Widget> widgetsInStack;
  final bool enableHero;
  final File? artworkFile;

  const MultiArtworkCard({
    super.key,
    required this.tracks,
    required this.name,
    required this.countPerRow,
    this.onTap,
    this.showMenuFunction,
    required this.heroTag,
    this.widgetsInStack = const [],
    this.enableHero = true,
    this.artworkFile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: Dimensions.gridHorizontalPadding),
      decoration: BoxDecoration(
        color: context.theme.cardColor,
        borderRadius: BorderRadius.circular(12.0.multipliedRadius),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final imageSize = constraints.maxWidth;
          final remainingVerticalSpace = constraints.maxHeight - imageSize;
          final itemImagePercentageMultiplier = imageSize * 0.02;
          double getFontSize(double m) => (remainingVerticalSpace * m).withMaximum(15.0);
          return Stack(
            children: [
              MultiArtworks(
                borderRadius: 12.0,
                heroTag: heroTag,
                disableHero: !enableHero,
                tracks: tracks.toImageTracks(),
                thumbnailSize: constraints.maxWidth,
                iconSize: (12.0 * itemImagePercentageMultiplier).withMinimum(12.0),
                artworkFile: artworkFile,
              ),
              Positioned(
                left: 0.0,
                bottom: 0.0,
                child: SizedBox(
                  width: imageSize,
                  height: remainingVerticalSpace,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: remainingVerticalSpace * 0.1),
                        if (name != '')
                          NamidaHero(
                            enabled: enableHero,
                            tag: 'line1_$heroTag',
                            child: Text(
                              name.overflow,
                              style: context.textTheme.displayMedium?.copyWith(fontSize: getFontSize(0.38)),
                              softWrap: false,
                              overflow: TextOverflow.fade,
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
                              fontWeight: FontWeight.w400,
                              fontSize: getFontSize(0.28),
                            ),
                            softWrap: false,
                            overflow: TextOverflow.fade,
                          ),
                        ),
                        SizedBox(height: remainingVerticalSpace * 0.1),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: NamidaInkWell(
                  onTap: onTap,
                  onLongPress: showMenuFunction,
                ),
              ),
              ...widgetsInStack,
            ],
          );
        },
      ),
    );
  }
}
