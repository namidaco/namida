import 'package:flutter/cupertino.dart';

import 'package:get/get.dart';

import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/expandable_box.dart';
import 'package:namida/ui/widgets/sort_by_button.dart';

class TracksPage extends StatelessWidget {
  const TracksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => NamidaTracksList(
        pageKey: const PageStorageKey(LibraryTab.tracks),
        queueLength: Indexer.inst.trackSearchList.length,
        queue: Indexer.inst.trackSearchList,
        queueSource: QueueSource.allTracks,
        scrollController: ScrollSearchController.inst.trackScrollcontroller,
        widgetsInColumn: [
          ExpandableBox(
            isBarVisible: ScrollSearchController.inst.isTrackBarVisible.value,
            showSearchBox: ScrollSearchController.inst.showTrackSearchBox.value,
            displayloadingIndicator: Indexer.inst.isIndexing.value,
            leftWidgets: [
              NamidaIconButton(
                icon: Broken.shuffle,
                onPressed: () => Player.inst.playOrPause(0, Indexer.inst.trackSearchList.toList(), QueueSource.allTracks, shuffle: true),
                iconSize: 18.0,
                horizontalPadding: 0,
              ),
              const SizedBox(width: 12.0),
              NamidaIconButton(
                icon: Broken.play,
                onPressed: () => Player.inst.playOrPause(0, Indexer.inst.trackSearchList.toList(), QueueSource.allTracks),
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
              textFieldController: Indexer.inst.tracksSearchController,
              textFieldHintText: Language.inst.FILTER_TRACKS,
              onTextFieldValueChanged: (value) => Indexer.inst.searchTracks(value),
            ),
          ),
        ],
      ),
    );
  }
}
