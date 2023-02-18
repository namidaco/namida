import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get/get.dart';

import 'package:namida/controller/folders_controller.dart';
import 'package:namida/controller/selected_tracks_controller.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/folder_tile.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';

class FoldersPage extends StatelessWidget {
  FoldersPage({super.key});

  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    // Folders.inst.stepOut();
    Folders.inst.stepIn();

    return Obx(
      () => CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: TextButton(
              onPressed: () {
                Folders.inst.stepOut();
              },
              child: Text(Folders.inst.currentPath.value),
            ),
          ),

          SliverList(
            delegate: SliverChildListDelegate(
              Folders.inst.currentFoldersMap.entries
                  .map(
                    (e) => FolderTile(
                      path: e.key,
                      tracks: e.value,
                    ),
                  )
                  .toList(),
            ),
          ),

          // if (Folders.inst.currentFoldersMap.isNotEmpty)
          //   SliverToBoxAdapter(
          //     child: Obx(
          //       () => ListView.builder(
          //         physics: const NeverScrollableScrollPhysics(),
          //         // shrinkWrap: true,
          //         padding: EdgeInsets.only(bottom: SelectedTracksController.inst.bottomPadding.value),
          //         controller: _scrollController,
          //         itemCount: Folders.inst.currentFoldersMap.length,
          //         itemBuilder: (BuildContext context, int i) {
          //           final folder = Folders.inst.currentFoldersMap.entries.elementAt(i);
          //           return FolderTile(
          //             path: folder.key,
          //             tracks: folder.value,
          //           );
          //         },
          //       ),
          //     ),
          //   ),
          // if (Folders.inst.currentTracks.isNotEmpty)
          //   SliverFillRemaining(
          //     child: Obx(
          //       () => ListView.builder(
          //         physics: const NeverScrollableScrollPhysics(),
          //         // shrinkWrap: true,
          //         padding: EdgeInsets.only(bottom: SelectedTracksController.inst.bottomPadding.value),
          //         controller: _scrollController,
          //         itemCount: Folders.inst.currentTracks.length,
          //         itemBuilder: (BuildContext context, int i) {
          //           return AnimationConfiguration.staggeredList(
          //             position: Folders.inst.currentFoldersMap.length + i,
          //             duration: const Duration(milliseconds: 400),
          //             child: SlideAnimation(
          //               verticalOffset: 25.0,
          //               child: FadeInAnimation(
          //                   duration: const Duration(milliseconds: 400),
          //                   child: TrackTile(
          //                     track: Folders.inst.currentTracks.elementAt(i),
          //                   )),
          //             ),
          //           );
          //         },
          //       ),
          //     ),
          //   ),

          SliverAnimatedList(
            key: UniqueKey(),
            initialItemCount: Folders.inst.currentTracks.length,
            itemBuilder: (context, i, animation) => TrackTile(
              track: Folders.inst.currentTracks.elementAt(i),
            ),
          ),
          // SliverList(
          //   delegate: SliverChildListDelegate(
          //     Folders.inst.currentTracks
          //         .map(
          //           (e) => AnimationConfiguration.staggeredList(
          //             position: Folders.inst.currentTracks.indexOf(e),
          //             duration: const Duration(milliseconds: 400),
          //             child: SlideAnimation(
          //               verticalOffset: 25.0,
          //               child: FadeInAnimation(
          //                 duration: const Duration(milliseconds: 400),
          //                 child: TrackTile(
          //                   track: e,
          //                 ),
          //               ),
          //             ),
          //           ),
          //         )
          //         .toList(),
          //   ),
          // ),
          // SliverFillRemaining(
          //   child: AnimationLimiter(
          //     child: ListView(
          //       children: Folders.inst.currentTracks
          //           .map(
          //             (e) => AnimationConfiguration.staggeredList(
          //               position: Folders.inst.currentTracks.indexOf(e),
          //               duration: const Duration(milliseconds: 400),
          //               child: SlideAnimation(
          //                 verticalOffset: 25.0,
          //                 child: FadeInAnimation(
          //                   duration: const Duration(milliseconds: 400),
          //                   child: TrackTile(
          //                     track: e,
          //                   ),
          //                 ),
          //               ),
          //             ),
          //           )
          //           .toList(),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
    return CupertinoScrollbar(
      child: AnimationLimiter(
        child: Obx(
          () => ListView(
            // shrinkWrap: true,
            // crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SmallListTile(
                title: Folders.inst.currentPath.value,
                onTap: () => Folders.inst.stepOut(),
                icon: Broken.folder_2,
              ),
              if (Folders.inst.currentFoldersMap.isNotEmpty)
                Expanded(
                  child: AnimationLimiter(
                    child: Obx(
                      () => ListView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        // shrinkWrap: true,
                        padding: EdgeInsets.only(bottom: SelectedTracksController.inst.bottomPadding.value),
                        controller: _scrollController,
                        itemCount: Folders.inst.currentFoldersMap.length,
                        itemBuilder: (BuildContext context, int i) {
                          return AnimationConfiguration.staggeredList(
                            position: i,
                            duration: const Duration(milliseconds: 400),
                            child: SlideAnimation(
                              verticalOffset: 25.0,
                              child: FadeInAnimation(
                                duration: const Duration(milliseconds: 400),
                                child: FolderTile(
                                  path: Folders.inst.currentFoldersMap.entries.elementAt(i).key,
                                  tracks: Folders.inst.currentFoldersMap.entries.elementAt(i).value,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              if (Folders.inst.currentTracks.isNotEmpty)
                Expanded(
                  child: AnimationLimiter(
                    child: Obx(
                      () => ListView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        // shrinkWrap: true,
                        padding: EdgeInsets.only(bottom: SelectedTracksController.inst.bottomPadding.value),
                        controller: _scrollController,
                        itemCount: Folders.inst.currentTracks.length,
                        itemBuilder: (BuildContext context, int i) {
                          return AnimationConfiguration.staggeredList(
                            position: i,
                            duration: const Duration(milliseconds: 400),
                            child: SlideAnimation(
                              verticalOffset: 25.0,
                              child: FadeInAnimation(
                                  duration: const Duration(milliseconds: 400),
                                  child: TrackTile(
                                    track: Folders.inst.currentTracks[i],
                                  )),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              // Expanded(
              //   child: Obx(
              //     () => ListView(
              //       // shrinkWrap: true,
              //       children: [
              //         ...Folders.inst.currentFoldersMap.entries
              //             .map(
              //               (e) => FolderTile(
              //                 path: e.key,
              //                 tracks: e.value,
              //               ),
              //             )
              //             .toList(),
              //         ...Folders.inst.currentTracks
              //             .asMap()
              //             .entries
              //             .map(
              //               (e) => TrackTile(
              //                 track: e.value,
              //               ),
              //             )
              //             .toList(),
              //       ],
              //     ),
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
