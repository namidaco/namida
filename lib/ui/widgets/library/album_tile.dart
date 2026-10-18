import 'package:flutter/material.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/network_artwork.dart';

class AlbumTile extends StatelessWidget {
  final AlbumIdentifierWrapper identifier;
  final List<Track> album;
  final String? extraText;

  const AlbumTile({
    super.key,
    required this.identifier,
    required this.album,
    this.extraText,
  });

  static BoxDecoration _shadowDecoration(NColorsData colors) => BoxDecoration(
    boxShadow: [
      BoxShadow(
        color: colors.shadow.withOpacityExt(0.08),
        blurRadius: 12.0,
        offset: const Offset(0, 2),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final albumThumbnailSize = settings.albumThumbnailSizeinList.value;
    final albumTileHeight = settings.albumListTileHeight.value;
    final finalYear = album.yearOldest.yearFormatted;
    final name = identifier.displayAlbumName;
    final hero = 'album_$identifier';

    final secondLine = extraText ?? album.albumArtist;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0).add(const EdgeInsets.only(bottom: Dimensions.tileBottomMargin)),
      child: NDecoratedBox(
        decoration: _shadowDecoration,
        child: NamidaInkWell(
          borderRadius: 0.2 * albumTileHeight,
          bgColor: NColors.card,
          onTap: () => NamidaOnTaps.inst.onAlbumTap(identifier),
          onLongPress: () => NamidaDialogs.inst.showAlbumDialog(identifier),
          enableSecondaryTap: true,
          child: SizedBox(
            height: Dimensions.inst.albumTileItemExtent,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Dimensions.tileVerticalPadding),
              child: Row(
                children: [
                  const SizedBox(width: 12.0),
                  SizedBox(
                    width: albumThumbnailSize,
                    height: albumThumbnailSize,
                    child: NamidaHero(
                      tag: hero,
                      child: NetworkArtwork.orLocal(
                        key: Key(album.pathToImage),
                        track: album.trackOfImage,
                        thumbnailSize: albumThumbnailSize,
                        path: album.pathToImage,
                        info: NetworkArtworkInfo.albumAutoArtist(identifier),
                        disableBlurBgSizeShrink: true,
                        forceSquared: settings.forceSquaredAlbumThumbnail.value,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        NamidaHero(
                          tag: 'line1_$hero',
                          child: NamidaText(
                            name,
                            style: NText.medium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (secondLine.isNotEmpty)
                          NamidaHero(
                            tag: 'line2_$hero',
                            child: NamidaText(
                              secondLine,
                              style: NText.small,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        NamidaHero(
                          tag: 'line3_$hero',
                          child: NamidaText(
                            [
                              album.displayTrackKeyword,
                              if (finalYear != '') finalYear,
                            ].join(' • '),
                            style: const NText(.small, weight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  NamidaText(
                    album.totalDurationFormatted,
                    style: const NText(.small, weight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(width: 4.0),
                  MoreIcon(
                    padding: 6.0,
                    onPressed: () => NamidaDialogs.inst.showAlbumDialog(identifier),
                  ),
                  const SizedBox(width: 10.0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
