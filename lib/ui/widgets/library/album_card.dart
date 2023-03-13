import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/dialogs/common_dialogs.dart';

class AlbumCard extends StatelessWidget {
  final int? gridCountOverride;
  final List<Track> album;
  final bool staggered;
  final bool compact;

  const AlbumCard({
    super.key,
    this.gridCountOverride,
    required this.album,
    required this.staggered,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final gridCount = gridCountOverride ?? SettingsController.inst.albumGridCount.value;
    final fontSize = (16.0 - (gridCount * 1.8)).multipliedFontScale;
    final shouldDisplayTopRightDate = SettingsController.inst.albumCardTopRightDate.value && album[0].year != 0;
    final shouldDisplayNormalDate = !SettingsController.inst.albumCardTopRightDate.value && album[0].year != 0;
    final shouldDisplayAlbumArtist = album[0].albumArtist != '';

    const double horizontalPadding = 4.0;
    double thumnailSize = (Get.width / gridCount) - horizontalPadding * 2;
    return GridTile(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 0.0, horizontal: horizontalPadding),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.0.multipliedRadius),
          boxShadow: [
            BoxShadow(
              color: context.theme.shadowColor.withAlpha(50),
              blurRadius: 12,
              offset: const Offset(0, 2.0),
            )
          ],
        ),
        child: Material(
          color: context.theme.cardColor,
          child: InkWell(
            highlightColor: const Color.fromARGB(60, 120, 120, 120),
            onLongPress: () => NamidaDialogs.inst.showAlbumDialog(album),
            onTap: () => NamidaOnTaps.inst.onAlbumTap(album[0].album),
            child: Column(
              children: [
                Hero(
                  tag: 'parent_album_artwork_${album[0].album}',
                  child: ArtworkWidget(
                    thumnailSize: thumnailSize,
                    track: album[0],
                    borderRadius: 10.0,
                    blur: 0,
                    iconSize: 32.0,
                    forceSquared: !staggered,
                    staggered: staggered,
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
                Expanded(
                  flex: staggered ? 0 : 1,
                  child: Stack(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: fontSize * 0.7),
                        width: double.infinity,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (staggered && !compact) SizedBox(height: fontSize * 0.7),
                            Text(
                              album[0].album.overflow,
                              style: context.textTheme.displayMedium?.copyWith(fontSize: fontSize * 1.16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (!SettingsController.inst.albumCardTopRightDate.value || album[0].albumArtist != '') ...[
                              // if (!compact) const SizedBox(height: 2.0),
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
                            // if (staggered && !compact) SizedBox(height: fontSize * 0.1),
                            Text(
                              [
                                album.displayTrackKeyword,
                                album.totalDurationFormatted,
                              ].join(' • '),
                              style: context.textTheme.displaySmall?.copyWith(fontSize: fontSize),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (staggered && !compact) SizedBox(height: fontSize * 0.7),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
