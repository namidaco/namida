import 'package:flutter/cupertino.dart';

import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/main_page.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
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
    return MainPageWrapper(
      actionsToAdd: [
        NamidaIconButton(
          icon: Broken.more_2,
          padding: const EdgeInsets.only(right: 14, left: 4.0),
          onPressed: () => NamidaDialogs.inst.showGenreDialog(name, tracks),
        )
      ],
      child: NamidaTracksList(
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
      ),
    );
  }
}
