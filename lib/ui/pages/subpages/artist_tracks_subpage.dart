import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/main_page.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/library/album_card.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';

class ArtistTracksPage extends StatelessWidget {
  final String name;
  final List<Track> tracks;
  final Color colorScheme;
  final Map<String?, Set<Track>> albums;
  ArtistTracksPage({super.key, required this.name, required this.colorScheme, required this.tracks, required this.albums});

  final ScrollController _scrollController = ScrollController();
  @override
  Widget build(BuildContext context) {
    return MainPageWrapper(
      colorScheme: colorScheme,
      actionsToAdd: [
        NamidaIconButton(
          icon: Broken.more_2,
          padding: const EdgeInsets.only(right: 14, left: 4.0),
          onPressed: () => NamidaDialogs.inst.showArtistDialog(name, tracks),
        )
      ],
      child: AnimationLimiter(
        child: CupertinoScrollbar(
          controller: _scrollController,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Top Container holding image and info and buttons
              SliverToBoxAdapter(
                child: SubpagesTopContainer(
                  verticalPadding: 8.0,
                  title: name,
                  subtitle: [tracks.displayTrackKeyword, tracks[0].dateAdded.dateFormatted].join(' - '),
                  imageWidget: Hero(
                    tag: 'artist$name',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 2),
                      child: ContainerWithBorder(
                        child: ArtworkWidget(
                          thumnailSize: Get.width * 0.35,
                          track: tracks[0],
                          forceSquared: true,
                          blur: 0,
                          iconSize: 32.0,
                        ),
                      ),
                    ),
                  ),
                  tracks: tracks,
                ),
              ),

              /// Albums
              SliverToBoxAdapter(
                  child: ExpansionTile(
                leading: const Icon(Broken.music_dashboard),
                trailing: const Icon(Broken.arrow_down_2),
                title: Text(
                  "${Language.inst.ALBUMS} ${albums.length}",
                  style: context.textTheme.displayMedium,
                ),
                initiallyExpanded: true,
                children: [
                  SizedBox(
                    height: 130,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: albums.entries
                          .map(
                            (e) => SizedBox(
                              width: 100,
                              child: AlbumCard(
                                gridCountOverride: 4,
                                album: e.value.toList(),
                                staggered: false,
                                compact: true,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 12.0),
                ],
              )),
              const SliverPadding(
                padding: EdgeInsets.only(bottom: 12.0),
              ),

              /// Tracks
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    return AnimatingTile(
                      position: i,
                      child: TrackTile(
                        index: i,
                        track: tracks[i],
                        queue: tracks,
                      ),
                    );
                  },
                  childCount: tracks.length,
                ),
              ),

              const SliverPadding(
                padding: EdgeInsets.only(bottom: kBottomPadding),
              )
            ],
          ),
        ),
      ),
    );
  }
}
