import 'package:flutter/material.dart';

import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/album_card.dart';
import 'package:namida/ui/widgets/network_artwork.dart';

class ArtistTracksPage extends StatelessWidget with NamidaRouteWidget {
  @override
  RouteType get route {
    return type == MediaType.albumArtist
        ? RouteType.SUBPAGE_albumArtistTracks
        : type == MediaType.composer
            ? RouteType.SUBPAGE_composerTracks
            : RouteType.SUBPAGE_artistTracks;
  }

  @override
  final String name;

  final List<Track> tracks;
  final List<String> albumIdentifiers;
  final MediaType type;

  const ArtistTracksPage({
    super.key,
    required this.name,
    required this.tracks,
    required this.albumIdentifiers,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: Obx(
        (context) {
          // to update after sorting
          Indexer.inst.getArtistMapFor(type).valueR;

          return NamidaTracksList(
            queueSource: QueueSource.artist,
            queueLength: tracks.length,
            queue: tracks,
            paddingAfterHeader: const EdgeInsets.only(bottom: 12.0),
            header: NamidaExpansionTile(
              icon: Broken.music_dashboard,
              titleText: "${lang.ALBUMS} ${albumIdentifiers.length}",
              initiallyExpanded: albumIdentifiers.isNotEmpty,
              children: [
                SizedBox(
                  height: 130.0 + 28.0,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    scrollDirection: Axis.horizontal,
                    itemExtent: 100.0,
                    itemCount: albumIdentifiers.length,
                    itemBuilder: (context, i) {
                      final albumId = albumIdentifiers[i];
                      return Container(
                        width: 100.0,
                        margin: const EdgeInsets.only(left: 2.0),
                        child: AlbumCard(
                          identifier: albumId,
                          album: albumId.getAlbumTracks(),
                          staggered: false,
                          compact: true,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            infoBox: (maxWidth) => SubpageInfoContainer(
              maxWidth: maxWidth,
              topPadding: 8.0,
              bottomPadding: 8.0,
              title: name,
              source: QueueSource.artist,
              subtitle: [
                tracks.displayTrackKeyword,
                if (tracks.year != 0) tracks.year.yearFormatted,
              ].join(' - '),
              heroTag: 'artist_$name',
              imageBuilder: (size) => NamidaHero(
                tag: 'artist_$name',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: ContainerWithBorder(
                    child: NetworkArtwork.orLocal(
                      key: Key(tracks.pathToImage),
                      info: NetworkArtworkInfo.artist(name),
                      path: tracks.pathToImage,
                      track: tracks.trackOfImage,
                      thumbnailSize: size,
                      fit: BoxFit.fitHeight,
                      forceSquared: true,
                      isCircle: true,
                      blur: 12.0,
                      iconSize: 32.0,
                    ),
                  ),
                ),
              ),
              tracksFn: () => tracks,
            ),
          );
        },
      ),
    );
  }
}
