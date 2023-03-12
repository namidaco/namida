import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
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
                leftWidgets: [
                  NamidaIconButton(
                    icon: Broken.shuffle,
                    onPressed: () => Player.inst.playOrPause(0, Indexer.inst.trackSearchList.first, queue: Indexer.inst.trackSearchList.toList(), shuffle: true),
                    iconSize: 18.0,
                    horizontalPadding: 0,
                  ),
                  const SizedBox(width: 12.0),
                  NamidaIconButton(
                    icon: Broken.play,
                    onPressed: () => Player.inst.playOrPause(0, Indexer.inst.trackSearchList.first, queue: Indexer.inst.trackSearchList.toList()),
                    iconSize: 18.0,
                    horizontalPadding: 0,
                  ),
                  const SizedBox(width: 12.0),
                ],
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
                  padding: const EdgeInsets.only(bottom: kBottomPadding),
                  controller: _scrollController,
                  itemCount: Indexer.inst.trackSearchList.length,
                  itemBuilder: (BuildContext context, int i) {
                    return AnimatingTile(
                      position: i,
                      child: TrackTile(
                        index: i,
                        track: Indexer.inst.trackSearchList[i],
                        queue: Indexer.inst.trackSearchList.toList(),
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
