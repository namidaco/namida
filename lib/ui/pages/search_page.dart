import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:flutter_scrollbar_modified/flutter_scrollbar_modified.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get/get.dart';

import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/pages/homepage.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/album_card.dart';
import 'package:namida/ui/widgets/library/artist_card.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';

class SearchPage extends StatelessWidget {
  SearchPage({super.key});

  final ScrollController _scrollController = ScrollController();
  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: Obx(
        () => AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: !Indexer.inst.isSearching.value
              ? Container(
                  key: const ValueKey('emptysearch'),
                  padding: const EdgeInsets.all(64.0).add(const EdgeInsets.only(bottom: 64.0)),
                  width: context.width,
                  height: context.height,
                  child: Opacity(
                    opacity: 0.8,
                    child: TweenAnimationBuilder(
                      tween: Tween<double>(begin: 4.0, end: ScrollSearchController.inst.isGlobalSearchMenuShown.value ? 4.0 : 12.0),
                      duration: const Duration(milliseconds: 500),
                      builder: (context, value, child) => ImageFiltered(
                        imageFilter: ImageFilter.blur(
                          sigmaX: value,
                          sigmaY: value,
                        ),
                        child: Image.asset('assets/namida_icon.png'),
                      ),
                    ),
                  ),
                )
              : AnimationLimiter(
                  key: const ValueKey('fullsearch'),
                  child: CupertinoScrollbar(
                    controller: _scrollController,
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        const SliverPadding(
                          padding: EdgeInsets.only(bottom: 8.0),
                        ),

                        /// Albums
                        if (Indexer.inst.albumSearchTemp.isNotEmpty) ...[
                          SliverToBoxAdapter(
                            child: SearchPageTitleRow(
                              title: '${Language.inst.ALBUMS} • ${Indexer.inst.albumSearchTemp.length}',
                              icon: Broken.music_dashboard,
                              buttonIcon: Broken.category,
                              buttonText: Language.inst.VIEW_ALL,
                              onPressed: () => NamidaNavigator.inst.navigateTo(const AlbumSearchResultsPage()),
                            ),
                          ),
                          const SliverPadding(
                            padding: EdgeInsets.only(bottom: 12.0),
                          ),
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: 170,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemExtent: 132.0,
                                itemCount: Indexer.inst.albumSearchTemp.length,
                                itemBuilder: (context, i) {
                                  final albumName = Indexer.inst.albumSearchTemp[i];
                                  return Container(
                                    width: 130.0,
                                    margin: const EdgeInsets.only(left: 2.0),
                                    child: AlbumCard(
                                      name: albumName,
                                      gridCountOverride: 3,
                                      album: albumName.getAlbumTracks(),
                                      staggered: false,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SliverPadding(
                            padding: EdgeInsets.only(top: 12.0),
                          ),
                        ],

                        /// Artists
                        if (Indexer.inst.artistSearchTemp.isNotEmpty) ...[
                          SliverToBoxAdapter(
                            child: SearchPageTitleRow(
                              title: '${Language.inst.ARTISTS} • ${Indexer.inst.artistSearchTemp.length}',
                              icon: Broken.profile_2user,
                              buttonIcon: Broken.category,
                              buttonText: Language.inst.VIEW_ALL,
                              onPressed: () => NamidaNavigator.inst.navigateTo(const ArtistSearchResultsPage()),
                            ),
                          ),
                          const SliverPadding(
                            padding: EdgeInsets.only(bottom: 12.0),
                          ),
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: 100,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemExtent: 82.0,
                                itemCount: Indexer.inst.artistSearchTemp.length,
                                itemBuilder: (context, i) {
                                  final artistName = Indexer.inst.artistSearchTemp[i];
                                  return Container(
                                    width: 80.0,
                                    margin: const EdgeInsets.only(left: 2.0),
                                    child: ArtistCard(
                                      gridCount: 5,
                                      name: artistName,
                                      artist: artistName.getArtistTracks(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SliverPadding(
                            padding: EdgeInsets.only(top: 12.0),
                          ),
                        ],

                        /// Tracks
                        if (Indexer.inst.trackSearchTemp.isNotEmpty) ...[
                          SliverToBoxAdapter(
                            child: Tooltip(
                              message: Language.inst.TRACK_PLAY_MODE,
                              child: SearchPageTitleRow(
                                title: '${Language.inst.TRACKS} • ${Indexer.inst.trackSearchTemp.length}',
                                icon: Broken.music_circle,
                                buttonIcon: Broken.play,
                                buttonText: SettingsController.inst.trackPlayMode.value.toText(),
                                onPressed: () => SettingsController.inst.trackPlayMode.value.toggleSetting(),
                              ),
                            ),
                          ),
                          const SliverPadding(
                            padding: EdgeInsets.only(bottom: 12.0),
                          ),
                          SliverFixedExtentList(
                            itemExtent: trackTileItemExtent,
                            delegate: SliverChildBuilderDelegate(
                              (context, i) {
                                final track = Indexer.inst.trackSearchTemp[i];
                                return AnimatingTile(
                                  position: i,
                                  child: TrackTile(
                                    index: i,
                                    track: track,
                                    queueSource: QueueSource.search,
                                  ),
                                );
                              },
                              childCount: Indexer.inst.trackSearchTemp.length,
                            ),
                          ),
                        ],

                        const SliverPadding(
                          padding: EdgeInsets.only(bottom: kBottomPadding),
                        )
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
