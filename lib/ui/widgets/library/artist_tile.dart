import 'package:flutter/material.dart';

import 'package:namida/class/track.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/network_artwork.dart';

class ArtistTile extends StatelessWidget {
  final String name;
  final List<Track> tracks;
  final Set<String> albums;
  final MediaType type;
  final String? extraText;

  const ArtistTile({
    super.key,
    required this.name,
    required this.tracks,
    required this.albums,
    required this.type,
    this.extraText,
  });

  @override
  Widget build(BuildContext context) {
    final hero = 'artist_$name';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0).add(const EdgeInsets.only(bottom: Dimensions.tileBottomMargin)),
      child: NamidaInkWell(
        onTap: () => NamidaOnTaps.inst.onArtistTap(name, type, tracks),
        onLongPress: () => NamidaDialogs.inst.showArtistDialog(name, type),
        enableSecondaryTap: true,
        child: SizedBox(
          height: Dimensions.artistTileItemExtent,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Dimensions.tileVerticalPadding),
            child: Row(
              children: [
                const SizedBox(width: 8.0),
                NamidaHero(
                  tag: hero,
                  child: ContainerWithBorder(
                    child: NetworkArtwork.orLocal(
                      key: Key(tracks.pathToImage),
                      path: tracks.pathToImage,
                      track: tracks.trackOfImage,
                      info: NetworkArtworkInfo.artist(name),
                      thumbnailSize: Dimensions.artistThumbnailSize,
                      borderRadius: 0,
                      forceSquared: true,
                      blur: 6.0,
                      disableBlurBgSizeShrink: true,
                      isCircle: true,
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
                          name,
                          style: context.textTheme.displayMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      NamidaHero(
                        tag: 'line2_$hero',
                        child: Text(
                          [
                            tracks.displayTrackKeyword,
                            albums.length.displayAlbumKeyword,
                          ].join(' & '),
                          style: context.textTheme.displaySmall?.copyWith(fontSize: 14.0),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (extraText != null && extraText!.isNotEmpty && extraText != name)
                        Text(
                          extraText!,
                          style: context.textTheme.displaySmall?.copyWith(fontSize: 12.0),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Text(
                  tracks.totalDurationFormatted,
                  style: context.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 4.0),
                MoreIcon(
                  onPressed: () => NamidaDialogs.inst.showArtistDialog(name, type),
                  padding: 6.0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
