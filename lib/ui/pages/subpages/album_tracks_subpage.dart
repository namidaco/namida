import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/multi_artwork_container.dart';

class AlbumTracksPage extends StatelessWidget {
  final String name;
  final List<Track> tracks;
  final Color colorScheme;
  const AlbumTracksPage({super.key, required this.name, required this.tracks, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => NamidaTracksList(
        queueSource: QueueSource.album,
        queueLength: tracks.length,
        queue: tracks,
        displayIndex: SettingsController.inst.displayTrackNumberinAlbumPage.value,
        header: SubpagesTopContainer(
          title: name,
          source: QueueSource.album,
          subtitle: [tracks.displayTrackKeyword, tracks.totalDurationFormatted].join(' - '),
          thirdLineText: tracks.albumArtist,
          heroTag: 'album_$name',
          imageWidget: shouldAlbumBeSquared
              ? MultiArtworkContainer(
                  size: Get.width * 0.35,
                  heroTag: 'album_$name',
                  tracks: [tracks.firstTrackWithImage],
                )
              : Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12.0),
                  padding: const EdgeInsets.all(3.0),
                  child: Hero(
                    tag: 'album_$name',
                    child: ArtworkWidget(
                      track: tracks.trackOfImage,
                      thumnailSize: Get.width * 0.35,
                      forceSquared: false,
                      path: tracks.pathToImage,
                      compressed: false,
                      borderRadius: 12.0,
                    ),
                  ),
                ),
          tracks: tracks,
        ),
      ),
    );
  }
}
