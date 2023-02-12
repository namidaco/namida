import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get/get.dart';

import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/functions/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/ui/widgets/multi_artwork.dart';

class GenresPage extends StatelessWidget {
  GenresPage({super.key});
  final ScrollController _scrollController = ScrollController();
  @override
  Widget build(BuildContext context) {
    // context.theme;
    return Obx(
      () {
        final search = Indexer.inst.displayGenreSearch.value;
        return CupertinoScrollbar(
          controller: _scrollController,
          child:
              // Wrap(
              //   children: Indexer.inst.groupedGenresMap.entries
              //       .map(
              //         (e) => GenreTile(tracks: e.value.toList(), name: e.key!),
              //       )
              //       .toList(),
              // )

              //       AnimationLimiter(
              //     child: GridView.count(
              //       childAspectRatio: 0.8,
              //       crossAxisCount: 2,
              //       controller: _scrollController,
              //       children: (search ? Indexer.inst.genreSearchList : Indexer.inst.groupedGenresMap)
              //           .entries
              //           .map((e) => AnimationConfiguration.staggeredGrid(
              //                 columnCount: search ? Indexer.inst.genreSearchList.length : Indexer.inst.groupedGenresMap.length,
              //                 position: 0,
              //                 duration: const Duration(milliseconds: 400),
              //                 child: SlideAnimation(
              //                   verticalOffset: 25.0,
              //                   child: FadeInAnimation(
              //                     duration: const Duration(milliseconds: 400),
              //                     child: GenreTile(
              //                       tracks: e.value.toList(),
              //                       name: e.key!,
              //                     ),
              //                   ),
              //                 ),
              //               ))
              //           .toList(),
              //     ),
              //   ),
              // );

              AnimationLimiter(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.8, mainAxisSpacing: 4.0),
              controller: _scrollController,
              itemCount: search ? Indexer.inst.genreSearchList.length : Indexer.inst.groupedGenresMap.length,
              itemBuilder: (BuildContext context, int i) {
                final genre = (search ? Indexer.inst.genreSearchList : Indexer.inst.groupedGenresMap).entries.toList()[i];
                return AnimationConfiguration.staggeredGrid(
                  columnCount: search ? Indexer.inst.genreSearchList.length : Indexer.inst.groupedGenresMap.length,
                  position: i,
                  duration: const Duration(milliseconds: 400),
                  child: SlideAnimation(
                    verticalOffset: 25.0,
                    child: FadeInAnimation(
                      duration: const Duration(milliseconds: 400),
                      child: GenreTile(
                        tracks: genre.value.toList(),
                        name: genre.key,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class GenreTile extends StatelessWidget {
  final List<Track> tracks;
  final String name;

  const GenreTile({super.key, required this.tracks, required this.name});

  @override
  Widget build(BuildContext context) {
    const double horizontalPadding = 6.0;
    double genrethumnailSize = (Get.width / 2) - horizontalPadding * 2;

    return GridTile(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2.0, horizontal: horizontalPadding),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12.0.multipliedRadius)),
        child: Material(
          color: context.theme.cardColor,
          child: InkWell(
            highlightColor: const Color.fromARGB(60, 120, 120, 120),
            // key: ValueKey(track),
            onLongPress: () {
              // stc.selectOrUnselect(track);
            },
            onTap: () {
              // Get.to(
              //   AlbumTracksPage(album: album),
              //   //  duration: Duration(milliseconds: 300),
              // );
            },
            child: Column(
              children: [
                Hero(
                  tag: 'genre_artwork_$name',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                    child: MultiArtworks(
                      tracks: tracks,
                      thumbnailSize: genrethumnailSize,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.0),
                    width: double.infinity,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      // mainAxisSize: MainAxisSize.max,
                      children: [
                        Text(
                          name,
                          style: Get.textTheme.displayMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          [tracks.displayTrackKeyword, tracks.totalDurationFormatted].join(' - '),
                          style: Get.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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
