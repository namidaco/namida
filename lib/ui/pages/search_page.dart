import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/pages/albums_page.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/expandable_box.dart';
import 'package:namida/ui/widgets/library/album_card.dart';
import 'package:namida/ui/widgets/library/album_tile.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';
import 'package:namida/ui/widgets/settings/sort_by_button.dart';

class SearchPage extends StatelessWidget {
  SearchPage({super.key});

  final ScrollController _scrollController = ScrollController();
  @override
  Widget build(BuildContext context) {
    // return Obx(() => SizedBox(height: 222, child: AlbumsPage(isSearch: true)));
    return Obx(
      () => Container(
        color: context.theme.scaffoldBackgroundColor,
        child: Indexer.inst.tracksInfoList.length == Indexer.inst.trackSearchList.length
            ? Container(
                width: double.infinity,
                height: double.infinity,
                child: const Text("FSAIOMsdiom"),
              )
            : AnimationLimiter(
                child: CustomScrollView(
                  slivers: [
                    // Albums
                    if (Indexer.inst.albumSearchList.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              const SizedBox(
                                width: 12.0,
                              ),
                              Expanded(
                                child: Text(
                                  Language.inst.ALBUMS,
                                  style: context.textTheme.displayLarge,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const FittedBox(
                                child: CreatePlaylistButton(),
                              ),
                              const SizedBox(
                                width: 8.0,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: Get.height / 4.2,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: Indexer.inst.albumSearchList.entries
                                .map(
                                  (e) => Container(
                                    width: Get.width / 3,
                                    margin: const EdgeInsets.symmetric(horizontal: 3.0),
                                    child: AlbumCard(
                                      gridCountOverride: 3,
                                      album: e.value.toList(),
                                      staggered: false,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                      const SliverPadding(
                        padding: EdgeInsets.only(top: 18.0),
                      ),
                    ],

                    // Artists
                    // if (Indexer.inst.artistSearchList.isNotEmpty) ...[
                    //   SliverToBoxAdapter(
                    //     child: Container(
                    //       padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    //       child: Row(
                    //         mainAxisAlignment: MainAxisAlignment.start,
                    //         children: [
                    //           const SizedBox(
                    //             width: 12.0,
                    //           ),
                    //           Expanded(
                    //             child: Text(
                    //               Language.inst.ARTISTS,
                    //               style: context.textTheme.displayLarge,
                    //               maxLines: 1,
                    //               overflow: TextOverflow.ellipsis,
                    //             ),
                    //           ),
                    //           const FittedBox(
                    //             child: CreatePlaylistButton(),
                    //           ),
                    //           const SizedBox(
                    //             width: 8.0,
                    //           ),
                    //         ],
                    //       ),
                    //     ),
                    //   ),
                    //   SliverToBoxAdapter(
                    //     child: SizedBox(
                    //       height: Get.height / 4.2,
                    //       child: ListView(
                    //         scrollDirection: Axis.horizontal,
                    //         children: Indexer.inst.albumSearchList.entries
                    //             .map(
                    //               (e) => Container(
                    //                 width: Get.width / 3,
                    //                 margin: const EdgeInsets.symmetric(horizontal: 3.0),
                    //                 child: AlbumCard(
                    //                   gridCountOverride: 3,
                    //                   album: e.value.toList(),
                    //                   staggered: false,
                    //                 ),
                    //               ),
                    //             )
                    //             .toList(),
                    //       ),
                    //     ),
                    //   ),
                    //   const SliverPadding(
                    //     padding: EdgeInsets.only(top: 18.0),
                    //   ),
                    // ],
                    // Tracks
                    if (Indexer.inst.trackSearchList.isNotEmpty)
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final album = Indexer.inst.trackSearchList
                                .asMap()
                                .entries
                                .map(
                                  (e) => TrackTile(track: e.value),
                                )
                                .toList();
                            return AnimationConfiguration.staggeredList(
                              position: i,
                              duration: const Duration(milliseconds: 400),
                              child: SlideAnimation(
                                verticalOffset: 25.0,
                                child: FadeInAnimation(
                                  duration: const Duration(milliseconds: 400),
                                  child: album[i],
                                ),
                              ),
                            );
                          },
                          childCount: Indexer.inst.trackSearchList.length,
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
