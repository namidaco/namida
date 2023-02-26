import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:namida/controller/settings_controller.dart';

import 'package:namida/core/extensions.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/selected_tracks_controller.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/expandable_box.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';
import 'package:namida/ui/widgets/settings/sort_by_button.dart';

class TracksPage extends StatelessWidget {
  TracksPage({super.key});
  final ScrollController _scrollController = ScrollSearchController.inst.trackScrollcontroller.value;
  @override
  Widget build(BuildContext context) {
    return CupertinoScrollbar(
      controller: _scrollController,
      child: AnimationLimiter(
        child: Obx(
          () => Column(
            children: [
              ExpandableBox(
                isBarVisible: ScrollSearchController.inst.isTrackBarVisible.value,
                showSearchBox: ScrollSearchController.inst.showTrackSearchBox.value,
                displayloadingIndicator: Indexer.inst.isIndexing.value,
                leftText: Indexer.inst.trackSearchList.toList().displayTrackKeyword,
                onFilterIconTap: () => ScrollSearchController.inst.switchTrackSearchBoxVisibilty(),
                onCloseButtonPressed: () {
                  ScrollSearchController.inst.clearTrackSearchTextField();
                },
                sortByMenuWidget: SortByMenu(
                  title: SettingsController.inst.tracksSort.value.toText,
                  popupMenuChild: const SortByMenuTracks(),
                  isCurrentlyReversed: SettingsController.inst.tracksSortReversed.value,
                  onReverseIconTap: () {
                    Indexer.inst.sortTracks(reverse: !SettingsController.inst.tracksSortReversed.value);
                  },
                ),
                textField: CustomTextFiled(
                  textFieldController: Indexer.inst.tracksSearchController.value,
                  textFieldHintText: Language.inst.FILTER_TRACKS,
                  onTextFieldValueChanged: (value) => Indexer.inst.searchTracks(value),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  // physics: AlwaysScrollableScrollPhysics(),
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
