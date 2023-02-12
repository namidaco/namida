import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/functions/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/album_card.dart';
import 'package:namida/ui/widgets/album_tile.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/ui/widgets/track_tile.dart';

class AlbumsPage extends StatelessWidget {
  final Map<String?, Set<Track>>? albums;
  AlbumsPage({super.key, this.albums});
  final ScrollController _scrollController = ScrollController();
  @override
  Widget build(BuildContext context) {
    // context.theme;

    return CupertinoScrollbar(
      controller: _scrollController,
      child: AnimationLimiter(
        child: Obx(
          () {
            final search = Indexer.inst.displayAlbumSearch.value;
            return SettingsController.inst.albumGridCount.value == 1
                ? ListView.builder(
                    controller: _scrollController,
                    itemCount: albums?.length ?? Indexer.inst.albumSearchList.length,
                    itemBuilder: (BuildContext context, int i) {
                      return AnimationConfiguration.staggeredList(
                        position: i,
                        duration: const Duration(milliseconds: 400),
                        child: SlideAnimation(
                          verticalOffset: 25.0,
                          child: FadeInAnimation(
                            duration: const Duration(milliseconds: 400),
                            child: AlbumTile(
                              album: (albums ?? Indexer.inst.albumSearchList).entries.toList()[i].value.toList(),
                            ),
                          ),
                        ),
                      );
                    },
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: albums?.length ?? Indexer.inst.albumSearchList.length,
                    // itemCount: 100,
                    itemBuilder: (BuildContext context, int i) {
                      return AnimationConfiguration.staggeredGrid(
                        columnCount: Indexer.inst.albumSearchList.length,
                        position: i,
                        duration: const Duration(milliseconds: 400),
                        child: SlideAnimation(
                          verticalOffset: 25.0,
                          child: FadeInAnimation(
                            duration: const Duration(milliseconds: 400),
                            child: AlbumTile(
                              album: (albums ?? (search ? Indexer.inst.albumSearchList : Indexer.inst.albumsMap)).entries.toList()[i].value.toList(),
                            ),
                          ),
                        ),
                      );
                    },
                  );
            // /
            // : MasonryGridView.builder(
            //     // crossAxisCount: 4, children: Indexer.inst.albumsMap.entries.map((e) => AlbumCard(album: e.value.toList())).toList(),

            //     gridDelegate: SliverSimpleGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
            //     itemCount: 8, semanticChildCount: 2,
            //     itemBuilder: (context, i) {
            //       return AlbumCard(
            //         album: (search ? Indexer.inst.albumSearchList : Indexer.inst.albumsMap).entries.toList()[i].value.toList(),
            //       );
            //     },

            //     // staggeredTileBuilder: (int index) => StaggeredTile.fit(2),
            //     mainAxisSpacing: 4.0,
            //     crossAxisSpacing: 4.0,
            //   );
            // : SingleChildScrollView(
            //     child: Wrap(
            //       children: Indexer.inst.albumsMap.entries.map((e) => AlbumCard(album: e.value.toList())).toList(),
            //     ),
            //   );

            // MasonryGridView.count(
            //   crossAxisCount: SettingsController.inst.albumGridCount.value,
            //   mainAxisSpacing: 4,
            //   crossAxisSpacing: 4,
            //   itemCount: (search ? Indexer.inst.albumSearchList.length : Indexer.inst.albumsMap.length),
            //   itemBuilder: (context, i) {
            //     return AlbumCard(
            //       album: (search ? Indexer.inst.albumSearchList : Indexer.inst.albumsMap).entries.toList()[i].value.toList(),
            //     );
            //   },
            // );

            // GridView.builder(
            //     gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            //       crossAxisCount: SettingsController.inst.albumGridCount.value,
            //       crossAxisSpacing: 0.0,
            //       mainAxisSpacing: 0.0,
            //     ),
            //     controller: _scrollController,
            //     itemCount: albums?.length ?? (search ? Indexer.inst.albumSearchList.length : Indexer.inst.albumsMap.length),
            //     // itemCount: 100,
            //     itemBuilder: (BuildContext context, int i) {
            //       return AnimationConfiguration.staggeredGrid(
            //         columnCount: (search ? Indexer.inst.albumSearchList.length : Indexer.inst.albumsMap.length),
            //         position: i,
            //         duration: const Duration(milliseconds: 400),
            //         child: SlideAnimation(
            //           verticalOffset: 25.0,
            //           child: FadeInAnimation(
            //             duration: const Duration(milliseconds: 400),
            //             child: AlbumCard(
            //               album: (albums ?? (search ? Indexer.inst.albumSearchList : Indexer.inst.albumsMap)).entries.toList()[i].value.toList(),
            //             ),
            //           ),
            //         ),
            //       );
            //     },
            //   );
          },
        ),
      ),
    );
  }
}

class AlbumTracksPage extends StatelessWidget {
  final List<Track> album;
  AlbumTracksPage({super.key, required this.album});

  @override
  Widget build(BuildContext context) {
    // final AlbumTracksController albumtracksc = AlbumTracksController(album);
    return Obx(
      () => Scaffold(
        appBar: AppBar(
          leading: IconButton(onPressed: () => Get.back(), icon: const Icon(Broken.arrow_left_2)),
          title: Text(
            album[0].album,
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
                  Hero(
                    tag: 'album_artwork_${album[0].path}',
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16.0.multipliedRadius),
                      ),
                      width: 140,
                      height: 140,
                      child: ArtworkWidget(
                        thumnailSize: SettingsController.inst.albumThumbnailSizeinList.value,
                        forceSquared: SettingsController.inst.forceSquaredAlbumThumbnail.value,
                        track: album[0],
                        compressed: false,
                        // size: (SettingsController.inst.albumThumbnailSizeinList.value * 2).round(),

                        borderRadius: 8.0,
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
                            album[0].album,
                            style: Theme.of(context).textTheme.displayLarge,
                          ),
                        ),
                        const SizedBox(
                          height: 2.0,
                        ),
                        Container(
                          padding: const EdgeInsets.only(left: 14.0),
                          child: Text(
                            [album.displayTrackKeyword, if (album.isNotEmpty) album.totalDurationFormatted].join(' - '),
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
            ...album
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
