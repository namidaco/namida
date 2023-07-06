import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';

class ArtistCard extends StatelessWidget {
  final int gridCount;
  final String name;
  final List<Track> artist;

  const ArtistCard({
    super.key,
    required this.gridCount,
    required this.name,
    required this.artist,
  });

  @override
  Widget build(BuildContext context) {
    final d = Dimensions.inst.artistCardDimensions;
    final thumbnailSize = d.$1;
    final fontSize = d.$2.multipliedFontScale;

    final hero = 'artist_$name';
    return GridTile(
      child: NamidaInkWell(
        onTap: () => NamidaOnTaps.inst.onArtistTap(name, artist),
        onLongPress: () => NamidaDialogs.inst.showArtistDialog(name),
        child: Column(
          children: [
            NamidaHero(
              tag: hero,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: Dimensions.gridHorizontalPadding),
                child: ContainerWithBorder(
                  child: ArtworkWidget(
                    thumbnailSize: thumbnailSize,
                    track: artist.trackOfImage,
                    path: artist.pathToImage,
                    borderRadius: 10.0,
                    forceSquared: true,
                    blur: 0,
                    iconSize: 32.0,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                width: double.infinity,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (name != '')
                      NamidaHero(
                        tag: 'line1_$hero',
                        child: Text(
                          name.overflow,
                          style: context.textTheme.displayMedium?.copyWith(fontSize: fontSize),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
