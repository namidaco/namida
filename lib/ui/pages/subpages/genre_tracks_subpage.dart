import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/library/multi_artwork_container.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';

import 'package:namida/main.dart';

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
      child: AnimationLimiter(
        child: ListView(
          children: [
            /// Top Container holding image and info and buttons
            SubpagesTopContainer(
              title: name,
              subtitle: [tracks.displayTrackKeyword, tracks.totalDurationFormatted].join(' - '),
              imageWidget: MultiArtworkContainer(
                size: Get.width * 0.35,
                heroTag: 'genre_artwork_$name',
                tracks: tracks,
              ),
              tracks: tracks,
            ),

            /// tracks
            ...tracks
                .asMap()
                .entries
                .map(
                  (track) => AnimatingTile(
                    position: track.key,
                    child: TrackTile(
                      track: track.value,
                      queue: tracks,
                    ),
                  ),
                )
                .toList(),
            kBottomPaddingWidget,
          ],
        ),
      ),
    );
  }
}
