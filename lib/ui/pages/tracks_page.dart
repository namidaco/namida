import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/expandable_box.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';
import 'package:namida/ui/widgets/sort_by_button.dart';

class TracksPage extends StatelessWidget {
  const TracksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => NamidaTracksList(
        queueLength: Indexer.inst.trackSearchList.length,
        queueSource: QueueSource.allTracks,
        scrollController: LibraryTab.tracks.scrollController,
        itemBuilder: (context, i) {
          final track = Indexer.inst.trackSearchList[i];
          return AnimatingTile(
            key: ValueKey(i),
            position: i,
            shouldAnimate: LibraryTab.tracks.shouldAnimateTiles,
            child: TrackTile(
              index: i,
              track: track,
              draggableThumbnail: false,
              queueSource: QueueSource.allTracks,
            ),
          );
        },
        widgetsInColumn: [
          ExpandableBox(
            isBarVisible: LibraryTab.tracks.isBarVisible,
            showSearchBox: LibraryTab.tracks.isSearchBoxVisible,
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
            onFilterIconTap: () => ScrollSearchController.inst.switchSearchBoxVisibilty(LibraryTab.tracks),
            onCloseButtonPressed: () {
              ScrollSearchController.inst.clearSearchTextField(LibraryTab.tracks);
            },
            sortByMenuWidget: SortByMenu(
              title: SettingsController.inst.tracksSort.value.toText(),
              popupMenuChild: const SortByMenuTracks(),
              isCurrentlyReversed: SettingsController.inst.tracksSortReversed.value,
              onReverseIconTap: () {
                Indexer.inst.sortTracks(reverse: !SettingsController.inst.tracksSortReversed.value);
              },
            ),
            textField: CustomTextFiled(
              textFieldController: LibraryTab.tracks.textSearchController,
              textFieldHintText: Language.inst.FILTER_TRACKS,
              onTextFieldValueChanged: (value) => Indexer.inst.searchTracks(value),
            ),
          ),
        ],
      ),
    );
  }
}
