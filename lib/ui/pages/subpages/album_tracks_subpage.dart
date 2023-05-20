import 'package:flutter/cupertino.dart';

import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/main_page.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/library/multi_artwork_container.dart';

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
        child: NamidaTracksList(
          queueSource: QueueSource.album,
          queueLength: tracks.length,
          queue: tracks,
          header: SubpagesTopContainer(
            title: name,
            source: QueueSource.album,
            subtitle: [tracks.displayTrackKeyword, tracks.totalDurationFormatted].join(' - '),
            thirdLineText: tracks.albumArtist,
            imageWidget: shouldAlbumBeSquared
                ? MultiArtworkContainer(
                    size: Get.width * 0.35,
                    heroTag: 'album_artwork_$name',
                    tracks: [tracks.firstTrackWithImage],
                  )
                : Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12.0),
                    padding: const EdgeInsets.all(3.0),
                    child: Hero(
                      tag: 'parent_album_artwork_$name',
                      child: ArtworkWidget(
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
      ),
    );
  }
}
