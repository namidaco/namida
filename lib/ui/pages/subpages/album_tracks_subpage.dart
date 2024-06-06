import 'package:flutter/material.dart';
import 'package:namida/core/dimensions.dart';

import 'package:namida/core/utils.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/multi_artwork_container.dart';

class AlbumTracksPage extends StatelessWidget {
  final String albumIdentifier;
  final List<Track> tracks;

  const AlbumTracksPage({
    super.key,
    required this.albumIdentifier,
    required this.tracks,
  });

  @override
  Widget build(BuildContext context) {
    final name = tracks.album;
    final displayTrackNumberinAlbumPage = settings.displayTrackNumberinAlbumPage.value;
    return BackgroundWrapper(
      child: Obx(
        () {
          Indexer.inst.mainMapAlbums.valueR; // to update after sorting
          return NamidaTracksList(
            queueSource: QueueSource.album,
            queueLength: tracks.length,
            queue: tracks,
            displayTrackNumber: displayTrackNumberinAlbumPage,
            header: SubpagesTopContainer(
              title: name,
              source: QueueSource.album,
              subtitle: [tracks.displayTrackKeyword, tracks.totalDurationFormatted].join(' - '),
              thirdLineText: tracks.albumArtist,
              heroTag: 'album_$albumIdentifier',
              imageWidget: Dimensions.inst.shouldAlbumBeSquared // non reactive
                  ? MultiArtworkContainer(
                      size: namida.width * 0.35,
                      heroTag: 'album_$albumIdentifier',
                      tracks: [tracks.trackOfImage ?? kDummyTrack],
                    )
                  : Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12.0),
                      padding: const EdgeInsets.all(3.0),
                      child: NamidaHero(
                        tag: 'album_$albumIdentifier',
                        child: ArtworkWidget(
                          key: Key(tracks.pathToImage),
                          track: tracks.trackOfImage,
                          thumbnailSize: namida.width * 0.35,
                          forceSquared: false,
                          path: tracks.pathToImage,
                          compressed: false,
                          borderRadius: 12.0,
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
