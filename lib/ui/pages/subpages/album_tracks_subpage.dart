import 'package:flutter/material.dart';

import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/main.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/library/multi_artwork_container.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';

class AlbumTracksPage extends StatelessWidget {
  final String name;
  final List<Track> tracks;
  final Color colorScheme;
  const AlbumTracksPage({super.key, required this.name, required this.tracks, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => MainPageWrapper(
        colorScheme: colorScheme,
        actionsToAdd: [
          NamidaIconButton(
            icon: Broken.more_2,
            padding: const EdgeInsets.only(right: 14, left: 4.0),
            onPressed: () => NamidaDialogs.inst.showAlbumDialog(tracks),
          )
        ],
        child: AnimationLimiter(
          child: ListView(
            children: [
              /// Top Container holding image and info and buttons
              SubpagesTopContainer(
                title: name,
                subtitle: [tracks.displayTrackKeyword, tracks.totalDurationFormatted].join(' - '),
                thirdLineText: tracks.first.albumArtist,
                imageWidget: SettingsController.inst.useAlbumStaggeredGridView.value ||
                        (SettingsController.inst.albumGridCount.value == 1 && !SettingsController.inst.forceSquaredAlbumThumbnail.value)
                    ? Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12.0),
                        padding: const EdgeInsets.all(3.0),
                        child: Hero(
                          tag: 'parent_album_artwork_$name',
                          child: ArtworkWidget(
                            thumnailSize: Get.width * 0.35,
                            forceSquared: false,
                            track: tracks.first,
                            compressed: false,
                            borderRadius: 12.0,
                          ),
                        ),
                      )
                    : MultiArtworkContainer(
                        size: Get.width * 0.35,
                        heroTag: 'album_artwork_$name',
                        tracks: [tracks.first],
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
                        index: track.key,
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
      ),
    );
  }
}
