import 'package:flutter/cupertino.dart';

import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/multi_artwork_container.dart';

class GenreTracksPage extends StatelessWidget {
  final String name;
  final List<Track> tracks;
  const GenreTracksPage({
    super.key,
    required this.name,
    required this.tracks,
  });

  @override
  Widget build(BuildContext context) {
    return NamidaTracksList(
      queueSource: QueueSource.genre,
      queueLength: tracks.length,
      queue: tracks,
      header: SubpagesTopContainer(
        title: name,
        source: QueueSource.genre,
        subtitle: [tracks.displayTrackKeyword, tracks.totalDurationFormatted].join(' - '),
        imageWidget: MultiArtworkContainer(
          size: Get.width * 0.35,
          heroTag: 'genre_artwork_$name',
          tracks: tracks,
        ),
        tracks: tracks,
      ),
    );
  }
}
