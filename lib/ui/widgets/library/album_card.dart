import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/ui/pages/albums_page.dart';
import 'package:namida/ui/widgets/artwork.dart';

class AlbumCard extends StatelessWidget {
  final List<Track> album;

  AlbumCard({
    super.key,
    required this.album,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Get.width / 2,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(0.2.multipliedRadius),
        boxShadow: [
          BoxShadow(
            color: context.theme.shadowColor.withAlpha(20),
            blurRadius: 12.0,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Material(
        color: context.theme.cardColor,
        child: InkWell(
          highlightColor: const Color.fromARGB(60, 120, 120, 120),
          onLongPress: () {
            // stc.selectOrUnselect(track);
          },
          onTap: () {
            Get.to(
              () => AlbumTracksPage(album: album),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Hero(
                tag: 'album_artwork_${album[0].path}',
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                  ),
                  // width: Get.width / 2,
                  // height: Get.width / 2,
                  child: ArtworkWidget(
                    thumnailSize: Get.width / 2,
                    track: album[0],
                    forceSquared: false,
                  ),
                ),
              ),
              Text(album[0].album)
            ],
          ),
        ),
      ),
    );
  }
}

/*   SizedBox(
                  height: 38.0,
                  width: 38.0,
                  child: RotatedBox(
                    quarterTurns: 1,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                      onPressed: () {},
                      icon: const Icon(
                        Broken.more,
                        size: 20,
                      ),
                    ),
                  ),
                ), */
/* 
                  Hero(
                  tag: 'album_artwork_${album[0].path}',
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                    ),
                    width: albumthumnailSize,
                    height: albumthumnailSize,
                    child: ArtworkWidget(
                      thumnailSize: albumthumnailSize,
                      track: album[0],
                      forceSquared: SettingsController.inst.forceSquaredAlbumThumbnail.value,
                    ),
                  ),
                ), */