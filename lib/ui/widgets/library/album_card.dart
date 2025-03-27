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
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class AlbumCard extends StatelessWidget {
  final String identifier;
  final List<Track> album;
  final bool staggered;
  final bool compact;
  final bool displayIcon;
  final String? topRightText;
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
    this.topRightText,
    this.additionalHeroTag = '',
    this.homepageItem,
    this.dummyCard = false,
  });

  @override
  Widget build(BuildContext context) {
    final finalYear = album.year.yearFormatted;
    final shouldDisplayTopRightDate = topRightText != null || (settings.albumCardTopRightDate.value && finalYear != '');
    final shouldDisplayNormalDate = topRightText == null && !settings.albumCardTopRightDate.value && finalYear != '';
    final shouldDisplayAlbumArtist = album.albumArtist != '';

    final hero = 'album_$identifier$additionalHeroTag';

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
            final itemImagePercentageMultiplier = imageSize * 0.02;
            double getFontSize(double m) => (remainingVerticalSpace * m).withMaximum(15.0);
            return NamidaInkWell(
              onTap: () => dummyCard ? null : NamidaOnTaps.inst.onAlbumTap(identifier),
              onLongPress: () => dummyCard ? null : NamidaDialogs.inst.showAlbumDialog(identifier),
              child: Column(
                children: [
                  NamidaHero(
                    tag: hero,
                    child: ArtworkWidget(
                      key: Key(album.pathToImage),
                      track: album.trackOfImage,
                      thumbnailSize: imageSize,
                      path: album.pathToImage,
                      borderRadius: 10.0,
                      blur: 0,
                      iconSize: 32.0,
                      displayIcon: displayIcon,
                      forceSquared: !staggered,
                      staggered: staggered,
                      onTopWidgets: dummyCard
                          ? []
                          : [
                              if (shouldDisplayTopRightDate)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: NamidaBlurryContainer(
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(maxWidth: imageSize * 0.8),
                                      child: FittedBox(
                                        fit: BoxFit.fitWidth,
                                        child: Text(
                                          topRightText ?? finalYear,
                                          style: context.textTheme.displaySmall?.copyWith(fontSize: 12.0, fontWeight: FontWeight.bold),
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
                                    boxShadow: [
                                      BoxShadow(
                                        offset: const Offset(0.0, 2.0),
                                        color: context.theme.cardColor,
                                      ),
                                    ],
                                  ),
                                  borderRadius: 10.0,
                                  bgColor: context.theme.cardColor,
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
                            if (!settings.albumCardTopRightDate.value || album.albumArtist != '') ...[
                              if (shouldDisplayNormalDate || shouldDisplayAlbumArtist)
                                NamidaHero(
                                  tag: 'line2_$hero',
                                  child: Text(
                                    [
                                      if (shouldDisplayNormalDate) finalYear,
                                      if (shouldDisplayAlbumArtist) album.albumArtist.overflow,
                                    ].join(' - '),
                                    style: context.textTheme.displaySmall?.copyWith(fontSize: getFontSize(0.23)),
                                    softWrap: false,
                                    overflow: TextOverflow.fade,
                                  ),
                                ),
                            ],
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
