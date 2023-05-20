import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/main_page.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/library/album_card.dart';

class ArtistTracksPage extends StatelessWidget {
  final String name;
  final List<Track> tracks;
  final Color colorScheme;
  final Map<String?, Set<Track>> albums;
  const ArtistTracksPage({super.key, required this.name, required this.colorScheme, required this.tracks, required this.albums});

  @override
  Widget build(BuildContext context) {
    return MainPageWrapper(
      colorScheme: colorScheme,
      actionsToAdd: [
        NamidaIconButton(
          icon: Broken.more_2,
          padding: const EdgeInsets.only(right: 14, left: 4.0),
          onPressed: () => NamidaDialogs.inst.showArtistDialog(name, tracks),
        )
      ],
      child: NamidaTracksList(
        queueSource: QueueSource.artist,
        queueLength: tracks.length,
        queue: tracks,
        paddingAfterHeader: const EdgeInsets.only(bottom: 12.0),
        header: Column(
          children: [
            SubpagesTopContainer(
              verticalPadding: 8.0,
              title: name,
              source: QueueSource.artist,
              subtitle: [tracks.displayTrackKeyword, tracks.year.yearFormatted].join(' - '),
              imageWidget: Hero(
                tag: 'artist_$name',
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 2),
                  child: ContainerWithBorder(
                    child: ArtworkWidget(
                      thumnailSize: Get.width * 0.35,
                      path: tracks.pathToImage,
                      forceSquared: true,
                      blur: 0,
                      iconSize: 32.0,
                    ),
                  ),
                ),
              ),
              tracks: tracks,
            ),
            ExpansionTile(
              leading: const Icon(Broken.music_dashboard),
              trailing: const Icon(Broken.arrow_down_2),
              title: Text(
                "${Language.inst.ALBUMS} ${albums.length}",
                style: context.textTheme.displayMedium,
              ),
              initiallyExpanded: true,
              children: [
                SizedBox(
                  height: 130,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: albums.entries
                        .map(
                          (e) => SizedBox(
                            width: 100,
                            child: AlbumCard(
                              gridCountOverride: 4,
                              album: e.value.toList(),
                              staggered: false,
                              compact: true,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12.0),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
