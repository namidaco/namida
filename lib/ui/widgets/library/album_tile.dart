import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';

class AlbumTile extends StatelessWidget {
  final String identifier;
  final List<Track> album;

  const AlbumTile({
    super.key,
    required this.identifier,
    required this.album,
  });

  @override
  Widget build(BuildContext context) {
    final albumThumbnailSize = settings.albumThumbnailSizeinList.value;
    final albumTileHeight = settings.albumListTileHeight.value;
    final finalYear = album.year.yearFormatted;
    final hero = 'album_$identifier';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0).add(const EdgeInsets.only(bottom: Dimensions.tileBottomMargin)),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: context.theme.shadowColor.withAlpha(20),
            blurRadius: 12.0,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: NamidaInkWell(
        borderRadius: 0.2 * albumTileHeight,
        bgColor: context.theme.cardColor,
        onTap: () => NamidaOnTaps.inst.onAlbumTap(identifier),
        onLongPress: () => NamidaDialogs.inst.showAlbumDialog(identifier),
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
                    child: ArtworkWidget(
                      key: Key(album.pathToImage),
                      track: album.trackOfImage,
                      thumbnailSize: albumThumbnailSize,
                      path: album.pathToImage,
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
                          style: context.textTheme.displayMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (album.albumArtist != '')
                        NamidaHero(
                          tag: 'line2_$hero',
                          child: Text(
                            album.albumArtist,
                            style: context.textTheme.displaySmall,
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
                          style: context.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  [
                    album.totalDurationFormatted,
                  ].join(' - '),
                  style: context.textTheme.displaySmall?.copyWith(
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
