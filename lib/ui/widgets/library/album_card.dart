import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';

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
    final inverseGrid = 4 - gridCount;
    final fontSize = (16.0 - (gridCount * 1.8)).multipliedFontScale;
    final finalYear = album.year.yearFormatted;
    final shouldDisplayTopRightDate = SettingsController.inst.albumCardTopRightDate.value && finalYear != '';
    final shouldDisplayNormalDate = !SettingsController.inst.albumCardTopRightDate.value && finalYear != '';
    final shouldDisplayAlbumArtist = album.albumArtist != '';
    const double horizontalPadding = 4.0;
    double thumnailSize = (Get.width / gridCount) - horizontalPadding * 2;
    return GridTile(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 0.0, horizontal: horizontalPadding),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: context.theme.cardColor,
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
          color: Colors.transparent,
          child: InkWell(
            highlightColor: const Color.fromARGB(60, 120, 120, 120),
            onLongPress: () => NamidaDialogs.inst.showAlbumDialog(album, heroTag: 'parent_album_artwork_${album.album}'),
            onTap: () => NamidaOnTaps.inst.onAlbumTap(album.album),
            child: Column(
              children: [
                Hero(
                  tag: 'parent_album_artwork_${album.album}',
                  child: ArtworkWidget(
                    thumnailSize: thumnailSize,
                    path: album.pathToImage,
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
                                finalYear,
                                style: context.textTheme.displaySmall?.copyWith(fontSize: fontSize, fontWeight: FontWeight.bold),
                              ),
                            ),
                          )
                        : null,
                    onTopWidgets: [
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          margin: EdgeInsets.all(4.0 + 2.0 * inverseGrid),
                          decoration: BoxDecoration(
                            color: context.theme.cardColor,
                            borderRadius: BorderRadius.circular(10.0.multipliedRadius),
                            boxShadow: [
                              BoxShadow(
                                offset: const Offset(0.0, 2.0),
                                color: context.theme.cardColor,
                              ),
                            ],
                          ),
                          child: Material(
                            color: context.theme.cardColor,
                            borderRadius: BorderRadius.circular(10.0.multipliedRadius),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10.0.multipliedRadius),
                              onTap: () => Player.inst.playOrPause(0, album, QueueSource.album),
                              child: Padding(
                                padding: EdgeInsets.all(2.5 + 2.0 * inverseGrid),
                                child: Icon(Broken.play, size: 12.5 + 4.0 * inverseGrid),
                              ),
                            ),
                          ),
                        ),
                      )
                    ],
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
                              album.album.overflow,
                              style: context.textTheme.displayMedium?.copyWith(fontSize: fontSize * 1.16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (!SettingsController.inst.albumCardTopRightDate.value || album.albumArtist != '') ...[
                              // if (!compact) const SizedBox(height: 2.0),
                              if (shouldDisplayNormalDate || shouldDisplayAlbumArtist)
                                Text(
                                  [
                                    if (shouldDisplayNormalDate) finalYear,
                                    if (shouldDisplayAlbumArtist) album.albumArtist.overflow,
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
