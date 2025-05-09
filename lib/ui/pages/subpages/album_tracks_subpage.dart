import 'package:flutter/material.dart';

import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/multi_artwork_container.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';

class AlbumTracksPage extends StatelessWidget with NamidaRouteWidget {
  @override
  String? get name => albumIdentifier;

  @override
  RouteType get route => RouteType.SUBPAGE_albumTracks;

  final String albumIdentifier;
  final List<Track> tracks;

  const AlbumTracksPage({
    super.key,
    required this.albumIdentifier,
    required this.tracks,
  });

  @override
  Widget build(BuildContext context) {
    final name = tracks.album;
    final displayTrackNumberinAlbumPage = settings.displayTrackNumberinAlbumPage.value;
    return BackgroundWrapper(
      child: AnimationLimiter(
        child: TrackTilePropertiesProvider(
          configs: TrackTilePropertiesConfigs(
            queueSource: QueueSource.album,
            displayTrackNumber: displayTrackNumberinAlbumPage,
          ),
          builder: (properties) => ObxO(
            rx: settings.mediaItemsTrackSortingReverse,
            builder: (context, sortingModesReverse) {
              final sortIsReverse = sortingModesReverse[MediaType.album] == true;
              return ObxO(
                rx: settings.mediaItemsTrackSorting,
                builder: (context, sortingModes) {
                  final sortStartsWithDisc = sortingModes[MediaType.album]?.firstOrNull == SortType.discNo;
                  Map<int, List<Track>>? tracksMappedWithDisc;
                  if (sortStartsWithDisc) {
                    tracksMappedWithDisc = <int, List<Track>>{};
                    for (final tr in tracks) {
                      tracksMappedWithDisc.addForce(tr.discNo, tr);
                    }
                    if (sortIsReverse) {
                      tracksMappedWithDisc.sortByReverse((e) => e.key);
                    } else {
                      tracksMappedWithDisc.sortBy((e) => e.key);
                    }
                  }
                  return Obx(
                    (context) {
                      Indexer.inst.mainMapAlbums.valueR; // to update after sorting
                      return NamidaListViewRaw(
                        infoBox: (maxWidth) => SubpageInfoContainer(
                          maxWidth: maxWidth,
                          title: name,
                          source: QueueSource.album,
                          subtitle: [tracks.displayTrackKeyword, tracks.totalDurationFormatted].join(' - '),
                          thirdLineText: tracks.albumArtist,
                          heroTag: 'album_$albumIdentifier',
                          imageBuilder: (size) => Dimensions.inst.shouldAlbumBeSquared // non reactive
                              ? MultiArtworkContainer(
                                  size: size,
                                  heroTag: 'album_$albumIdentifier',
                                  tracks: [tracks.trackOfImage ?? kDummyTrack],
                                )
                              : Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 12.0),
                                  padding: const EdgeInsets.all(3.0),
                                  child: NamidaHero(
                                    tag: 'album_$albumIdentifier',
                                    child: ArtworkWidget(
                                      key: Key(tracks.pathToImage),
                                      track: tracks.trackOfImage,
                                      thumbnailSize: size,
                                      forceSquared: false,
                                      path: tracks.pathToImage,
                                      compressed: false,
                                      borderRadius: 12.0,
                                    ),
                                  ),
                                ),
                          tracksFn: () => tracks,
                        ),
                        slivers: [
                          if (tracksMappedWithDisc != null)
                            for (final discEntry in tracksMappedWithDisc.entries)
                              SliverMainAxisGroup(
                                slivers: [
                                  SliverPadding(
                                    padding: EdgeInsets.symmetric(vertical: 4.0),
                                    sliver: SliverToBoxAdapter(
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                              color: context.theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                                              borderRadius: BorderRadius.horizontal(right: Radius.circular(6.0.multipliedRadius))),
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(vertical: 6.0),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                SizedBox(width: 8.0),
                                                Icon(
                                                  Broken.cd,
                                                  size: 20.0,
                                                ),
                                                SizedBox(width: 4.0),
                                                Flexible(
                                                  child: Text(
                                                    // "${lang.DISC_NUMBER}: ${discEntry.key}",
                                                    " ${discEntry.key}",
                                                    style: context.textTheme.displayMedium,
                                                  ),
                                                ),
                                                SizedBox(width: 12.0),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SliverFixedExtentList.builder(
                                    itemCount: discEntry.value.length,
                                    itemExtent: Dimensions.inst.trackTileItemExtent,
                                    itemBuilder: (context, i) {
                                      final track = discEntry.value[i];
                                      return AnimatingTile(
                                        key: ValueKey(i),
                                        position: i,
                                        child: TrackTile(
                                          properties: properties,
                                          index: i,
                                          trackOrTwd: track,
                                        ),
                                      );
                                    },
                                  ),
                                  SliverPadding(
                                    padding: EdgeInsets.symmetric(vertical: 6.0),
                                  ),
                                ],
                              )
                          else
                            SliverFixedExtentList.builder(
                              itemCount: tracks.length,
                              itemExtent: Dimensions.inst.trackTileItemExtent,
                              itemBuilder: (context, i) {
                                final track = tracks[i];
                                return AnimatingTile(
                                  key: ValueKey(i),
                                  position: i,
                                  child: TrackTile(
                                    properties: properties,
                                    index: i,
                                    trackOrTwd: track,
                                  ),
                                );
                              },
                            )
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
