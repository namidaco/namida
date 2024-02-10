import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';

class AlbumCard extends StatelessWidget {
  final String identifier;
  final List<Track> album;
  final bool staggered;
  final bool compact;
  final (double, double, double) dimensions;
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
    required this.dimensions,
    this.displayIcon = true,
    this.topRightText,
    this.additionalHeroTag = '',
    this.homepageItem,
    this.dummyCard = false,
  });

  @override
  Widget build(BuildContext context) {
    // final d = Dimensions.inst.albumCardDimensions;
    final thumbnailSize = dimensions.$1;
    final fontSize = dimensions.$2.multipliedFontScale;
    final fontSizeBigger = topRightText == null ? null : (dimensions.$2 + (topRightText != null ? 3.0 : 0.0)).multipliedFontScale;
    final sizeAlternative = dimensions.$3;

    final finalYear = album.year.yearFormatted;
    final shouldDisplayTopRightDate = topRightText != null || (settings.albumCardTopRightDate.value && finalYear != '');
    final shouldDisplayNormalDate = topRightText == null && !settings.albumCardTopRightDate.value && finalYear != '';
    final shouldDisplayAlbumArtist = album.albumArtist != '';

    final hero = 'album_$identifier$additionalHeroTag';

    return GridTile(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 0.0, horizontal: Dimensions.gridHorizontalPadding),
        clipBehavior: Clip.antiAlias,
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
        child: NamidaInkWell(
          onTap: () => dummyCard ? null : NamidaOnTaps.inst.onAlbumTap(identifier),
          onLongPress: () => dummyCard ? null : NamidaDialogs.inst.showAlbumDialog(identifier),
          child: Column(
            children: [
              NamidaHero(
                tag: hero,
                child: ArtworkWidget(
                  key: Key(album.pathToImage),
                  track: album.trackOfImage,
                  thumbnailSize: thumbnailSize,
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
                                child: Text(
                                  topRightText ?? finalYear,
                                  style: context.textTheme.displaySmall?.copyWith(fontSize: fontSizeBigger ?? fontSize, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          Positioned(
                            bottom: 2.0 + sizeAlternative,
                            right: 2.0 + sizeAlternative,
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
                              padding: EdgeInsets.all(2.5 + sizeAlternative),
                              child: Icon(Broken.play, size: 12.5 + 2.0 * sizeAlternative),
                            ),
                          )
                        ],
                ),
              ),
              if (!dummyCard)
                Expanded(
                  flex: staggered ? 0 : 1,
                  child: Stack(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: fontSize * 0.7),
                        width: double.infinity,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (staggered && !compact) SizedBox(height: fontSize * 0.7),
                            NamidaHero(
                              tag: 'line1_$hero',
                              child: Text(
                                album.album.overflow,
                                style: context.textTheme.displayMedium?.copyWith(fontSize: fontSize * 1.16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!settings.albumCardTopRightDate.value || album.albumArtist != '') ...[
                              // if (!compact) const SizedBox(height: 2.0),
                              if (shouldDisplayNormalDate || shouldDisplayAlbumArtist)
                                NamidaHero(
                                  tag: 'line2_$hero',
                                  child: Text(
                                    [
                                      if (shouldDisplayNormalDate) finalYear,
                                      if (shouldDisplayAlbumArtist) album.albumArtist.overflow,
                                    ].join(' - '),
                                    style: context.textTheme.displaySmall?.copyWith(fontSize: fontSize * 1.08),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            // if (staggered && !compact) SizedBox(height: fontSize * 0.1),
                            NamidaHero(
                              tag: 'line3_$hero',
                              child: Text(
                                [
                                  album.displayTrackKeyword,
                                  album.totalDurationFormatted,
                                ].join(' • '),
                                style: context.textTheme.displaySmall?.copyWith(fontSize: fontSize),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (staggered && !compact) SizedBox(height: fontSize * 0.7),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
