import 'package:flutter/material.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/network_artwork.dart';

class AlbumTile extends StatelessWidget {
  final String identifier;
  final List<Track> album;
  final String? extraText;

  const AlbumTile({
    super.key,
    required this.identifier,
    required this.album,
    this.extraText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final albumThumbnailSize = settings.albumThumbnailSizeinList.value;
    final albumTileHeight = settings.albumListTileHeight.value;
    final finalYear = album.year.yearFormatted;
    final hero = 'album_$identifier';

    final secondLine = extraText ?? album.albumArtist;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0).add(const EdgeInsets.only(bottom: Dimensions.tileBottomMargin)),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withAlpha(20),
            blurRadius: 12.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: NamidaInkWell(
        borderRadius: 0.2 * albumTileHeight,
        bgColor: theme.cardColor,
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
                        child: Text(
                          album.album,
                          style: textTheme.displayMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (secondLine.isNotEmpty)
                        NamidaHero(
                          tag: 'line2_$hero',
                          child: Text(
                            secondLine,
                            style: textTheme.displaySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      NamidaHero(
                        tag: 'line3_$hero',
                        child: Text(
                          [
                            album.displayTrackKeyword,
                            if (finalYear != '') finalYear,
                          ].join(' • '),
                          style: textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  album.totalDurationFormatted,
                  style: textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
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
    );
  }
}
