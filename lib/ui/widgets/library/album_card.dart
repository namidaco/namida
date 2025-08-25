import 'package:flutter/material.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/network_artwork.dart';

class AlbumCard extends StatelessWidget {
  final String identifier;
  final List<Track> album;
  final bool staggered;
  final bool compact;
  final bool displayIcon;
  final String? extraInfo;
  final bool forceExtraInfoAtTopRight;
  final String additionalHeroTag;
  final HomePageItems? homepageItem;
  final bool dummyCard;

  const AlbumCard({
    super.key,
    required this.identifier,
    required this.album,
    required this.staggered,
    this.compact = false,
    this.displayIcon = true,
    this.extraInfo,
    this.forceExtraInfoAtTopRight = false,
    this.additionalHeroTag = '',
    this.homepageItem,
    this.dummyCard = false,
  });

  @override
  Widget build(BuildContext context) {
    final finalYear = album.year.yearFormatted;
    final albumArtist = album.albumArtist;

    final hero = 'album_$identifier$additionalHeroTag';

    String? topRightLine;
    String? secondLine;
    if (forceExtraInfoAtTopRight) {
      topRightLine = extraInfo;
    } else if (settings.albumCardTopRightDate.value) {
      secondLine = albumArtist != extraInfo
          ? [
              if (extraInfo != null) extraInfo,
              if (albumArtist.isNotEmpty) albumArtist,
            ].join(' • ')
          : extraInfo;
      topRightLine = finalYear;
      if (secondLine == topRightLine) secondLine = null;
    } else {
      topRightLine = null;
      secondLine = [
        if (extraInfo != null) extraInfo,
        if (finalYear.isNotEmpty && finalYear != extraInfo) finalYear,
        if (albumArtist.isNotEmpty && albumArtist != extraInfo) albumArtist,
      ].join(' • ');
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimensions.gridHorizontalPadding),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.theme.cardColor,
          borderRadius: BorderRadius.circular(12.0.multipliedRadius),
          boxShadow: [
            BoxShadow(
              color: context.theme.shadowColor.withAlpha(50),
              blurRadius: 12,
              offset: const Offset(0, 2.0),
            )
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final imageSize = constraints.maxWidth;
            double remainingVerticalSpace;
            if (constraints.maxHeight.isInfinite || constraints.maxHeight.isNaN) {
              remainingVerticalSpace = 48.0;
            } else {
              remainingVerticalSpace = constraints.maxHeight - imageSize;
            }
            final itemImagePercentageMultiplier = imageSize * 0.015;
            double getFontSize(double m) => (remainingVerticalSpace * m * 0.9).withMaximum(15.0);
            final playIconBgColor = context.theme.cardColor.withValues(alpha: (imageSize / 200).clampDouble(0, 1));

            return NamidaInkWell(
              onTap: () => dummyCard ? null : NamidaOnTaps.inst.onAlbumTap(identifier),
              onLongPress: () => dummyCard ? null : NamidaDialogs.inst.showAlbumDialog(identifier),
              enableSecondaryTap: true,
              child: Column(
                children: [
                  NamidaHero(
                    tag: hero,
                    child: NetworkArtwork.orLocal(
                      key: Key(album.pathToImage),
                      track: album.trackOfImage,
                      thumbnailSize: imageSize,
                      path: album.pathToImage,
                      borderRadius: 10.0,
                      info: NetworkArtworkInfo.albumAutoArtist(identifier),
                      blur: 8.0,
                      // disableBlurBgSizeShrink: true,
                      iconSize: 32.0,
                      displayIcon: displayIcon,
                      forceSquared: !staggered,
                      staggered: staggered,
                      onTopWidgets: dummyCard || (topRightLine == null || topRightLine.isEmpty)
                          ? null
                          : [
                              Positioned(
                                top: 0,
                                right: 0,
                                child: NamidaBlurryContainer(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(maxWidth: imageSize * 0.8),
                                    child: FittedBox(
                                      fit: BoxFit.fitWidth,
                                      child: Text(
                                        topRightLine,
                                        style: context.textTheme.displaySmall?.copyWith(
                                          fontSize: getFontSize(0.18),
                                          fontWeight: FontWeight.bold,
                                        ),
                                        softWrap: false,
                                        overflow: TextOverflow.fade,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 2.0 + itemImagePercentageMultiplier,
                                right: 2.0 + itemImagePercentageMultiplier,
                                child: NamidaInkWell(
                                  decoration: BoxDecoration(
                                    color: playIconBgColor,
                                    boxShadow: [
                                      BoxShadow(
                                        blurRadius: 6.0,
                                        offset: const Offset(0.0, 2.0),
                                        color: playIconBgColor.withValues(alpha: 0.4),
                                      ),
                                    ],
                                  ),
                                  borderRadius: 8.0.withMaximum(imageSize * 0.07),
                                  onTap: () => Player.inst.playOrPause(0, album, QueueSource.album, homePageItem: homepageItem),
                                  padding: EdgeInsets.all(2.5 + itemImagePercentageMultiplier),
                                  child: Icon(
                                    Broken.play,
                                    size: 8.5 + 3.0 * itemImagePercentageMultiplier,
                                  ),
                                ),
                              )
                            ],
                    ),
                  ),
                  if (!dummyCard)
                    SizedBox(
                      width: imageSize,
                      height: remainingVerticalSpace,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (staggered && !compact) SizedBox(height: remainingVerticalSpace * 0.08),
                            NamidaHero(
                              tag: 'line1_$hero',
                              child: Text(
                                album.album.overflow,
                                style: context.textTheme.displayMedium?.copyWith(fontSize: getFontSize(0.28)),
                                textAlign: TextAlign.start,
                                softWrap: false,
                                overflow: TextOverflow.fade,
                              ),
                            ),
                            if (secondLine != null && secondLine.isNotEmpty)
                              NamidaHero(
                                tag: 'line2_$hero',
                                child: Text(
                                  secondLine,
                                  style: context.textTheme.displaySmall?.copyWith(fontSize: getFontSize(0.23)),
                                  softWrap: false,
                                  overflow: TextOverflow.fade,
                                ),
                              ),
                            NamidaHero(
                              tag: 'line3_$hero',
                              child: Text(
                                [
                                  album.displayTrackKeyword,
                                  album.totalDurationFormatted,
                                ].join(' • '),
                                style: context.textTheme.displaySmall?.copyWith(fontSize: getFontSize(0.23)),
                                softWrap: false,
                                overflow: TextOverflow.fade,
                              ),
                            ),
                            if (staggered && !compact) SizedBox(height: remainingVerticalSpace * 0.08),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
