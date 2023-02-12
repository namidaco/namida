import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get/get.dart';

import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/functions/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/pages/albums_page.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/ui/widgets/track_tile.dart';

class ArtistsPage extends StatelessWidget {
  ArtistsPage({super.key});
  final ScrollController _scrollController = ScrollController();
  @override
  Widget build(BuildContext context) {
    // context.theme;
    return CupertinoScrollbar(
      controller: _scrollController,
      child: AnimationLimiter(
        child: Obx(
          () {
            final search = Indexer.inst.displayArtistSearch.value;
            return ListView.builder(
              controller: _scrollController,
              itemCount: search ? Indexer.inst.artistSearchList.length : Indexer.inst.albumsMap.length,
              itemBuilder: (BuildContext context, int i) {
                // final artist = Indexer.inst.groupedArtistsMap.entries.toList()[i];
                return AnimationConfiguration.staggeredList(
                  position: i,
                  duration: const Duration(milliseconds: 400),
                  child: SlideAnimation(
                    verticalOffset: 25.0,
                    child: FadeInAnimation(
                      duration: const Duration(milliseconds: 400),
                      child: Obx(
                        () => ArtistTile(
                          tracks: (search ? Indexer.inst.artistSearchList : Indexer.inst.groupedArtistsMap).entries.toList()[i].value.toList(),
                          name: (search ? Indexer.inst.artistSearchList : Indexer.inst.groupedArtistsMap).entries.toList()[i].key,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class ArtistTile extends StatelessWidget {
  final List<Track> tracks;
  final String name;

  ArtistTile({super.key, required this.tracks, required this.name});

  @override
  Widget build(BuildContext context) {
    double artistthumnailSize = 65;
    double artistTileHeight = 65;
    final albums = name.artistAlbums;
    final albumsList = albums.keys.toList();
    final albumTracks = albums.values.toList();
    // print(albumName);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 4.0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular((0.2 * artistTileHeight).multipliedRadius)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          highlightColor: const Color.fromARGB(60, 120, 120, 120),
          // key: ValueKey(track),
          onLongPress: () {
            // stc.selectOrUnselect(track);
          },
          onTap: () {
            Get.to(
              // () => ArtistTracksPage(artist: tracks.toList(), name: name),
              () => AlbumsPage(albums: albums),
              //  duration: Duration(milliseconds: 300),
            );
          },
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 3.0),
            height: artistTileHeight + 14,
            child: Row(
              children: [
                const SizedBox(width: 8.0),
                Container(
                  // padding: const EdgeInsets.all(
                  //   0.0,
                  // ),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: context.theme.cardColor),
                  width: artistthumnailSize,
                  height: artistthumnailSize,
                  child: Hero(
                    tag: 'artist$name',
                    child: ArtworkWidget(
                      thumnailSize: artistthumnailSize,
                      track: tracks[0],
                      borderRadius: 64.0,
                      forceSquared: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Get.textTheme.displayMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Text(
                      //   [
                      //     tracks.toList().displayTrackKeyword,
                      //     tracks[0].year.yearFormatted,
                      //   ].join(' • '),
                      //   style: Get.textTheme.displayMedium?.copyWith(
                      //     fontWeight: FontWeight.w500,
                      //   ),
                      //   overflow: TextOverflow.ellipsis,
                      // ),
                      Text(
                        [
                          tracks.toList().displayTrackKeyword,
                          albumsList.length,
                          tracks[0].year.yearFormatted,
                        ].join(' • '),
                        style: Get.textTheme.displaySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        [
                          albumTracks.length,
                        ].join(' • '),
                        style: Get.textTheme.displaySmall?.copyWith(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  [
                    tracks.toList().totalDurationFormatted,
                  ].join(' - '),
                  style: Get.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ArtistTracksPage extends StatelessWidget {
  final List<Track> artist;
  final String name;
  ArtistTracksPage({super.key, required this.artist, required this.name});

  @override
  Widget build(BuildContext context) {
    // final AlbumTracksController albumtracksc = AlbumTracksController(album);
    return Obx(
      () => Scaffold(
        appBar: AppBar(
          leading: IconButton(onPressed: () => Get.back(), icon: const Icon(Broken.arrow_left_2)),
          title: Text(
            artist[0].artistsList.toString(),
            style: Theme.of(context).textTheme.displayLarge,
          ),
        ),
        body: ListView(
          // cacheExtent: 1000,
          children: [
            // Top Container holding image and info and buttons
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(24.0),
              height: Get.width / 2.0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16.0.multipliedRadius),
                    ),
                    width: 140,
                    child: Hero(
                      tag: 'artist$name',
                      child: ArtworkWidget(
                        thumnailSize: SettingsController.inst.albumThumbnailSizeinList.value,
                        track: artist.elementAt(0),
                        compressed: false,
                        // size: (SettingsController.inst.albumThumbnailSizeinList.value * 2).round(),

                        // borderRadiusValue: 8.0,
                        forceSquared: SettingsController.inst.forceSquaredAlbumThumbnail.value,
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 18.0,
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                          height: 18.0,
                        ),
                        Container(
                          padding: const EdgeInsets.only(left: 14.0),
                          child: Text(
                            artist[0].album,
                            style: Theme.of(context).textTheme.displayLarge,
                          ),
                        ),
                        const SizedBox(
                          height: 2.0,
                        ),
                        Container(
                          padding: const EdgeInsets.only(left: 14.0),
                          child: Text(
                            [artist.displayTrackKeyword, if (artist.isNotEmpty) artist.totalDurationFormatted].join(' - '),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 14),
                          ),
                        ),
                        const SizedBox(
                          height: 18.0,
                        ),
                        Row(
                          // mainAxisAlignment:
                          //     MainAxisAlignment.spaceEvenly,
                          children: [
                            const Spacer(),
                            FittedBox(
                              child: ElevatedButton(
                                onPressed: () {
                                  // Playback.instance.open(
                                  //   [...widget.playlist.tracks]..shuffle(),
                                  // );
                                },
                                child: const Icon(Broken.shuffle),
                              ),
                            ),
                            const Spacer(),
                            FittedBox(
                              child: ElevatedButton(
                                onPressed: () {
                                  // Playback.instance.open(
                                  //   [
                                  //     ...widget.playlist.tracks,
                                  //     if (Configuration.instance.seamlessPlayback) ...[...Collection.instance.tracks]..shuffle()
                                  //   ],
                                  // );
                                },
                                child: Row(
                                  children: [
                                    const Icon(Broken.play),
                                    const SizedBox(
                                      width: 8.0,
                                    ),
                                    Text(Language.inst.PLAY_ALL),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
            ...artist
                .asMap()
                .entries
                .map((track) => TrackTile(
                      track: track.value,
                    ))
                .toList()
            // ListView(
            //   shrinkWrap: true,
            //   children: albumtracksc.albumTracksList
            //       .asMap()
            //       .entries
            //       .map((track) => TrackTile(
            //             track: track.value,
            //             trackIndex: track.key,
            //           ))
            //       .toList(),
            // ),
          ],
        ),
      ),
    );
  }
}
