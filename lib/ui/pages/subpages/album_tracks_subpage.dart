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
                  Map<int, int>? tracksIndicesIncrement;
                  if (sortStartsWithDisc) {
                    tracksMappedWithDisc = <int, List<Track>>{};
                    tracksIndicesIncrement = <int, int>{};
                    for (final tr in tracks) {
                      tracksMappedWithDisc.addForce(tr.discNo, tr);
                    }
                    if (sortIsReverse) {
                      tracksMappedWithDisc.sortByReverse((e) => e.key);
                    } else {
                      tracksMappedWithDisc.sortBy((e) => e.key);
                    }
                    int countTillNow = 0;
                    for (final e in tracksMappedWithDisc.entries) {
                      tracksIndicesIncrement[e.key] = countTillNow;
                      countTillNow += e.value.length;
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
                          imageBuilder: (size) => Dimensions.inst.shouldAlbumBeSquared(context) // non reactive
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
                          if (tracksMappedWithDisc != null && tracksMappedWithDisc.keys.any((n) => n > 1))
                            ...tracksMappedWithDisc.entries.mapIndexed(
                              (discEntry, discSectionIndex) {
                                final indicesToIncrement = tracksIndicesIncrement?[discEntry.key] ?? 0;
                                return SliverMainAxisGroup(
                                  slivers: [
                                    PinnedHeaderSliver(
                                      child: Padding(
                                        padding: EdgeInsets.only(bottom: 4.0),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: Color.alphaBlend(context.theme.colorScheme.secondaryContainer.withValues(alpha: 0.5), context.theme.scaffoldBackgroundColor),
                                                borderRadius: BorderRadius.horizontal(
                                                  right: Radius.circular(6.0.multipliedRadius),
                                                ),
                                              ),
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
                                                        " ${discEntry.key}",
                                                        style: context.textTheme.displayMedium,
                                                      ),
                                                    ),
                                                    SizedBox(width: 12.0),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            Flexible(
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: DecoratedBox(
                                                  decoration: BoxDecoration(
                                                    color: context.theme.scaffoldBackgroundColor,
                                                    borderRadius: BorderRadius.only(
                                                      bottomLeft: Radius.circular(6.0.multipliedRadius),
                                                    ),
                                                  ),
                                                  child: Padding(
                                                    padding: EdgeInsets.symmetric(vertical: 6.0),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        SizedBox(width: 8.0),
                                                        Text(
                                                          [
                                                            discEntry.value.displayTrackKeyword,
                                                            discEntry.value.totalDurationFormatted,
                                                          ].join(' • '),
                                                          style: context.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w500),
                                                        ),
                                                        SizedBox(width: 12.0),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    SliverFixedExtentList.builder(
                                      itemCount: discEntry.value.length,
                                      itemExtent: Dimensions.inst.trackTileItemExtent,
                                      itemBuilder: (context, i) {
                                        final track = discEntry.value[i];
                                        final trackEffectiveIndex = i + indicesToIncrement;
                                        return AnimatingTile(
                                          key: ValueKey(i),
                                          position: trackEffectiveIndex,
                                          child: TrackTile(
                                            properties: properties,
                                            index: trackEffectiveIndex,
                                            trackOrTwd: track,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                );
                              },
                            ).addSeparators(
                              separator: SliverPadding(
                                padding: EdgeInsets.symmetric(vertical: 12.0),
                              ),
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
