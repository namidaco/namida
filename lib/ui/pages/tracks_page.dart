import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/selected_tracks_controller.dart';
import 'package:namida/ui/widgets/expandable_box.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';

class TracksPage extends StatelessWidget {
  TracksPage({super.key});
  final ScrollController _scrollController = ScrollController();
  @override
  Widget build(BuildContext context) {
    return CupertinoScrollbar(
      controller: _scrollController,
      child: AnimationLimiter(
        child: Obx(
          () => Column(
            children: [
              ExpandableBoxForTracks(),
              Expanded(
                child: ListView.builder(
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
