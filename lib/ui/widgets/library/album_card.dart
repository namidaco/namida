import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/ui/pages/albums_page.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/dialogs/common_dialogs.dart';

class AlbumCard extends StatelessWidget {
  final int? gridCountOverride;
  final List<Track> album;
  final bool? staggered;

  AlbumCard({
    super.key,
    this.gridCountOverride,
    required this.album,
    this.staggered,
  });

  @override
  Widget build(BuildContext context) {
    final gridCount = gridCountOverride ?? SettingsController.inst.albumGridCount.value;
    final fontSize = (16.0 - (gridCount * 1.8)).multipliedFontScale;
    final shouldDisplayTopRightDate = SettingsController.inst.albumCardTopRightDate.value && album[0].year != 0;
    final shouldDisplayNormalDate = !SettingsController.inst.albumCardTopRightDate.value && album[0].year != 0;
    final shouldDisplayAlbumArtist = album[0].albumArtist != '';
    return Container(
      width: Get.width / gridCount - 34.0,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.0.multipliedRadius),
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
          onLongPress: () => NamidaDialogs.inst.showAlbumDialog(album),
          onTap: () {
            Get.to(
              () => AlbumTracksPage(album: album),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: 'album_artwork_${album[0].path}',
                child: ArtworkWidget(
                  thumnailSize: Get.width / gridCount,
                  track: album[0],
                  borderRadius: 10.0,
                  blur: 0,
                  forceSquared: !(staggered ?? SettingsController.inst.useAlbumStaggeredGridView.value),
                  staggered: staggered ?? SettingsController.inst.useAlbumStaggeredGridView.value,
                  onTopWidget: shouldDisplayTopRightDate
                      ? Positioned(
                          top: 0,
                          right: 0,
                          child: NamidaBlurryContainer(
                            child: Text(
                              album[0].year.yearFormatted,
                              style: context.textTheme.displaySmall?.copyWith(fontSize: fontSize, fontWeight: FontWeight.bold),
                            ),
                          ),
                        )
                      : null,
                ),
              ),
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: Get.width / gridCount - 28.0, minWidth: Get.width / gridCount - 28.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 10.0),
                              Text(
                                album[0].album.overflow,
                                style: context.textTheme.displayMedium?.copyWith(fontSize: fontSize * 1.16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (!SettingsController.inst.albumCardTopRightDate.value || album[0].albumArtist != '') ...[
                                const SizedBox(height: 2.0),
                                if (shouldDisplayNormalDate || shouldDisplayAlbumArtist)
                                  Text(
                                    [
                                      if (shouldDisplayNormalDate) album[0].year.yearFormatted,
                                      if (shouldDisplayAlbumArtist) album[0].albumArtist.overflow,
                                    ].join(' - '),
                                    style: context.textTheme.displaySmall?.copyWith(fontSize: fontSize * 1.08),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                              // if (album[0].albumArtist != '') ...[
                              //   const SizedBox(height: 2.0),
                              //   Text(
                              //     album[0].albumArtist.overflow,
                              //     style: context.textTheme.displaySmall,
                              //     maxLines: 1,
                              //     overflow: TextOverflow.ellipsis,
                              //   ),
                              // ],
                              const SizedBox(height: 2.0),
                              Text(
                                [
                                  album.displayTrackKeyword,
                                  album.totalDurationFormatted,
                                ].join(' • '),
                                style: context.textTheme.displaySmall?.copyWith(fontSize: fontSize),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),

                              const SizedBox(height: 10.0),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8.0 - (gridCount * 1.2)),
                      child: MoreIcon(
                        rotated: false,
                        iconSize: 18 - (gridCount * 1.1),
                        onPressed: () => NamidaDialogs.inst.showAlbumDialog(album),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
