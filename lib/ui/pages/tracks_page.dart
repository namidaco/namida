import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get/get.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/selected_tracks_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/expandable_box.dart';
import 'package:namida/ui/widgets/track_tile.dart';

class TracksPage extends StatelessWidget {
  TracksPage({super.key});
  final ScrollController _scrollController = ScrollController();
  @override
  Widget build(BuildContext context) {
    // context.theme;
    return CupertinoScrollbar(
      controller: _scrollController,
      child: AnimationLimiter(
        child: Obx(
          () {
            // final search = Indexer.inst.trackSearchList.isNotEmpty;
            return Column(
              children: [
                // Obx(
                //   () => AnimatedSize(
                //     duration: Duration(milliseconds: 400),
                //     // offset: Offset(0, searchActive ? 0 : -1),
                //     child: Container(
                //       height: searchActive ? 42.0 : 0,
                //       padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
                //       child: Row(
                //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //         mainAxisSize: MainAxisSize.max,
                //         crossAxisAlignment: CrossAxisAlignment.center,
                //         children: [
                //           Text(
                //             "Showing Results for \"${Indexer.inst.tracksSearchController.value.text}\"",
                //             style: Get.textTheme.displayMedium,
                //           ),
                //           IconButton(
                //             onPressed: () {
                //               Indexer.inst.tracksSearchController.value.clear();
                //               Indexer.inst.searchTracks('');
                //             },
                //             icon: Icon(Broken.close_circle),
                //           ),
                //         ],
                //       ),
                //     ),
                //   ),
                // ),
                // Row(
                //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //   mainAxisSize: MainAxisSize.max,
                //   crossAxisAlignment: CrossAxisAlignment.center,
                //   children: [
                //     Text(
                //       Indexer.inst.tracksInfoList.toList().displayTrackKeyword,
                //       style: Get.textTheme.displayMedium,
                //     ),
                //     IconButton(
                //       onPressed: () {
                //         Indexer.inst.tracksSearchController.value.clear();
                //         Indexer.inst.searchTracks('');
                //       },
                //       icon: Icon(Broken.close_circle),
                //     ),
                //     IconButton(
                //       onPressed: () {
                //         showSearchBox = !showSearchBox;
                //       },
                //       icon: Icon(Broken.filter),
                //     ),
                //   ],
                // ),
                // if (showSearchBox)
                //   Container(
                //     padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
                //     child: TextField(
                //       controller: Indexer.inst.tracksSearchController.value,
                //       decoration: InputDecoration(
                //         constraints: const BoxConstraints(maxHeight: 56.0),
                //         border: OutlineInputBorder(
                //           borderRadius: BorderRadius.circular(14.0.multipliedRadius),
                //         ),
                //         hintText: Language.inst.FILTER_TRACKS,
                //       ),
                //       onChanged: (value) {
                //         Indexer.inst.searchTracks(value);
                //       },
                //     ),
                //   ),
                ExpandableBoxForTracks(),
                Expanded(
                  child:
                      //  Obx(
                      //   () =>
                      ListView.builder(
                    padding: EdgeInsets.only(bottom: SelectedTracksController.inst.bottomPadding.value),
                    controller: _scrollController,
                    itemCount: Indexer.inst.trackSearchList.length,
                    itemBuilder: (BuildContext context, int i) {
                      return AnimationConfiguration.staggeredList(
                        position: i,
                        duration: const Duration(milliseconds: 400),
                        child: SlideAnimation(
                          verticalOffset: 25.0,
                          child: FadeInAnimation(
                            duration: const Duration(milliseconds: 400),
                            child: TrackTile(
                              track: Indexer.inst.trackSearchList[i],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // ),
                ),
              ],
            );

            /*   return ImplicitlyAnimatedList(
              controller: _scrollController,
              // The current items in the list.
              items: search ? Indexer.inst.trackSarchList.toList() : Indexer.inst.tracksInfoList.toList(),
              // Called by the DiffUtil to decide whether two object represent the same item.
              // For example, if your items have unique ids, this method should check their id equality.
              areItemsTheSame: (a, b) => a.path == b.path,
              // Called, as needed, to build list item widgets.
              // List items are only built when they're scrolled into view.
              itemBuilder: (context, animation, item, index) {
                // Specifiy a transition to be used by the ImplicitlyAnimatedList.
                // See the Transitions section on how to import this transition.
                return SizeFadeTransition(
                  sizeFraction: 0.7,
                  curve: Curves.easeInOutQuart,
                  animation: animation,
                  child: TrackTile(
                    track: item,
                  ),
                );
              },
            ); */
          },
        ),
      ),
    );
  }
}
