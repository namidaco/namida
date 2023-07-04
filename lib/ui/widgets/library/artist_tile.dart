import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';

class ArtistTile extends StatelessWidget {
  final String name;
  final List<Track> tracks;
  final Set<String> albums;

  const ArtistTile({super.key, required this.name, required this.tracks, required this.albums});

  @override
  Widget build(BuildContext context) {
    const artistthumnailSize = 65.0;
    const artistTileHeight = 65.0;

    final hero = 'artist_$name';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 4.0),
      child: NamidaInkWell(
        onTap: () => NamidaOnTaps.inst.onArtistTap(name, tracks),
        onLongPress: () => NamidaDialogs.inst.showArtistDialog(name),
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: SizedBox(
          height: artistTileHeight + 14,
          child: Row(
            children: [
              const SizedBox(width: 8.0),
              Hero(
                tag: hero,
                child: ContainerWithBorder(
                  child: ArtworkWidget(
                    thumnailSize: artistthumnailSize,
                    track: tracks.trackOfImage,
                    path: tracks.pathToImage,
                    borderRadius: 64.0,
                    forceSquared: true,
                    blur: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Hero(
                      tag: 'line1_$hero',
                      child: Text(
                        name,
                        style: context.textTheme.displayMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Hero(
                      tag: 'line2_$hero',
                      child: Text(
                        [
                          tracks.displayTrackKeyword,
                          albums.length.displayAlbumKeyword,
                        ].join(' & '),
                        style: context.textTheme.displaySmall?.copyWith(fontSize: 14.0.multipliedFontScale),
                        overflow: TextOverflow.ellipsis,
                      ),
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
                onPressed: () => NamidaDialogs.inst.showArtistDialog(name),
                padding: 6.0,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
