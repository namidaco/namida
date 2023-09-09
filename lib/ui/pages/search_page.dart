import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:flutter_scrollbar_modified/flutter_scrollbar_modified.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get/get.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/pages/main_page.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/album_card.dart';
import 'package:namida/ui/widgets/library/artist_card.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';

class SearchPage extends StatelessWidget {
  SearchPage({super.key});

  final ScrollController _scrollController = ScrollController();
  @override
  Widget build(BuildContext context) {
    final albumDimensions = Dimensions.inst.getAlbumCardDimensions(Dimensions.albumSearchGridCount);
    final artistDimensions = Dimensions.inst.getArtistCardDimensions(Dimensions.artistSearchGridCount);
    return BackgroundWrapper(
      child: Obx(
        () => AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: !SearchSortController.inst.isSearching.value
              ? Container(
                  key: const Key('emptysearch'),
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
                  key: const Key('fullsearch'),
                  child: CupertinoScrollbar(
                    controller: _scrollController,
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        const SliverPadding(
                          padding: EdgeInsets.only(bottom: 8.0),
                        ),

                        /// Albums
                        if (SearchSortController.inst.albumSearchTemp.isNotEmpty) ...[
                          SliverToBoxAdapter(
                            child: SearchPageTitleRow(
                              title: '${lang.ALBUMS} • ${SearchSortController.inst.albumSearchTemp.length}',
                              icon: Broken.music_dashboard,
                              buttonIcon: Broken.category,
                              buttonText: lang.VIEW_ALL,
                              onPressed: () => NamidaNavigator.inst.navigateTo(const AlbumSearchResultsPage()),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: 170.0 + 24.0,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(vertical: 12.0),
                                scrollDirection: Axis.horizontal,
                                itemExtent: 132.0,
                                itemCount: SearchSortController.inst.albumSearchTemp.length,
                                itemBuilder: (context, i) {
                                  final albumName = SearchSortController.inst.albumSearchTemp[i];
                                  return Container(
                                    width: 130.0,
                                    margin: const EdgeInsets.only(left: 2.0),
                                    child: AlbumCard(
                                      dimensions: albumDimensions,
                                      name: albumName,
                                      album: albumName.getAlbumTracks(),
                                      staggered: false,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],

                        /// Artists
                        if (SearchSortController.inst.artistSearchTemp.isNotEmpty) ...[
                          SliverToBoxAdapter(
                            child: SearchPageTitleRow(
                              title: '${lang.ARTISTS} • ${SearchSortController.inst.artistSearchTemp.length}',
                              icon: Broken.profile_2user,
                              buttonIcon: Broken.category,
                              buttonText: lang.VIEW_ALL,
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
                                itemCount: SearchSortController.inst.artistSearchTemp.length,
                                itemBuilder: (context, i) {
                                  final artistName = SearchSortController.inst.artistSearchTemp[i];
                                  return Container(
                                    width: 80.0,
                                    margin: const EdgeInsets.only(left: 2.0),
                                    child: ArtistCard(
                                      dimensions: artistDimensions,
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
                        if (SearchSortController.inst.trackSearchTemp.isNotEmpty) ...[
                          SliverToBoxAdapter(
                            child: Tooltip(
                              message: lang.TRACK_PLAY_MODE,
                              child: SearchPageTitleRow(
                                title: '${lang.TRACKS} • ${SearchSortController.inst.trackSearchTemp.length}',
                                icon: Broken.music_circle,
                                buttonIcon: Broken.play,
                                buttonText: settings.trackPlayMode.value.toText(),
                                onPressed: () {
                                  final element = settings.trackPlayMode.value.nextElement(TrackPlayMode.values);
                                  settings.save(trackPlayMode: element);
                                },
                              ),
                            ),
                          ),
                          const SliverPadding(
                            padding: EdgeInsets.only(bottom: 12.0),
                          ),
                          SliverFixedExtentList.builder(
                            itemCount: SearchSortController.inst.trackSearchTemp.length,
                            itemExtent: Dimensions.inst.trackTileItemExtent,
                            itemBuilder: (context, i) {
                              final track = SearchSortController.inst.trackSearchTemp[i];
                              return AnimatingTile(
                                position: i,
                                child: TrackTile(
                                  index: i,
                                  trackOrTwd: track,
                                  queueSource: QueueSource.search,
                                ),
                              );
                            },
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
