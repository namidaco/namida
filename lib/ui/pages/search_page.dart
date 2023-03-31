import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get/get.dart';

import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/main_page.dart';
import 'package:namida/ui/pages/albums_page.dart';
import 'package:namida/ui/pages/artists_page.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/album_card.dart';
import 'package:namida/ui/widgets/library/artist_card.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';

class SearchPage extends StatelessWidget {
  SearchPage({super.key});

  final ScrollController _scrollController = ScrollController();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.theme.scaffoldBackgroundColor,
      child: Obx(
        () => AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Indexer.inst.trackSearchTemp.isEmpty && Indexer.inst.albumSearchTemp.isEmpty && Indexer.inst.artistSearchTemp.isEmpty
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
                              title: Language.inst.ALBUMS,
                              icon: Broken.music_dashboard,
                              buttonIcon: Broken.category,
                              buttonText: Language.inst.VIEW_ALL,
                              onPressed: () {
                                Get.offAll(() => MainPageWrapper(
                                      getOffAll: true,
                                      title: Text(Language.inst.ALBUMS),
                                      child: AlbumsPage(albums: Indexer.inst.albumSearchTemp),
                                    ));
                                ScrollSearchController.inst.isGlobalSearchMenuShown.value = false;
                              },
                            ),
                          ),
                          const SliverPadding(
                            padding: EdgeInsets.only(bottom: 12.0),
                          ),
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: 170,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: Indexer.inst.albumSearchTemp
                                    .map(
                                      (e) => Container(
                                        width: 130,
                                        margin: const EdgeInsets.only(left: 2.0),
                                        child: AlbumCard(
                                          gridCountOverride: 3,
                                          album: e.tracks,
                                          staggered: false,
                                        ),
                                      ),
                                    )
                                    .toList(),
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
                              title: Language.inst.ARTISTS,
                              icon: Broken.profile_2user,
                              buttonIcon: Broken.category,
                              buttonText: Language.inst.VIEW_ALL,
                              onPressed: () {
                                Get.offAll(() => MainPageWrapper(
                                      getOffAll: true,
                                      title: Text(Language.inst.ARTISTS),
                                      child: ArtistsPage(artists: Indexer.inst.artistSearchTemp),
                                    ));
                                ScrollSearchController.inst.isGlobalSearchMenuShown.value = false;
                              },
                            ),
                          ),
                          const SliverPadding(
                            padding: EdgeInsets.only(bottom: 12.0),
                          ),
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: 100,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: Indexer.inst.artistSearchTemp
                                    .map(
                                      (e) => Container(
                                        width: 80,
                                        margin: const EdgeInsets.only(left: 2.0),
                                        child: ArtistCard(
                                          gridCount: 5,
                                          name: e.name,
                                          artist: e.tracks,
                                        ),
                                      ),
                                    )
                                    .toList(),
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
                              title: Language.inst.TRACKS,
                              icon: Broken.music_circle,
                              buttonIcon: Broken.play,
                              buttonText: SettingsController.inst.trackPlayMode.value.toText,
                              onPressed: () => SettingsController.inst.trackPlayMode.value.toggleSetting(),
                            ),
                          )),
                          const SliverPadding(
                            padding: EdgeInsets.only(bottom: 12.0),
                          ),
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, i) {
                                final track = Indexer.inst.trackSearchTemp[i];
                                return AnimatingTile(
                                  position: i,
                                  child: TrackTile(
                                    index: i,
                                    track: track,
                                    queue: Indexer.inst.trackSearchTemp,
                                    oiRespectPlayMode: true,
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
