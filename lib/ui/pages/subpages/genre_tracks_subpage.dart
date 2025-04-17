import 'package:flutter/material.dart';

import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/multi_artwork_container.dart';

class GenreTracksPage extends StatelessWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.SUBPAGE_genreTracks;

  @override
  final String name;
  final List<Track> tracks;
  const GenreTracksPage({
    super.key,
    required this.name,
    required this.tracks,
  });

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: Obx(
        (context) {
          Indexer.inst.mainMapGenres.valueR; // to update after sorting
          return NamidaTracksList(
            queueSource: QueueSource.genre,
            queueLength: tracks.length,
            queue: tracks,
            infoBox: (maxWidth) => SubpageInfoContainer(
              maxWidth: maxWidth,
              title: name,
              source: QueueSource.genre,
              subtitle: [tracks.displayTrackKeyword, tracks.totalDurationFormatted].join(' - '),
              heroTag: 'genre_$name',
              imageBuilder: (size) => MultiArtworkContainer(
                size: size,
                heroTag: 'genre_$name',
                tracks: tracks.toImageTracks(),
              ),
              tracksFn: () => tracks,
            ),
          );
        },
      ),
    );
  }
}
