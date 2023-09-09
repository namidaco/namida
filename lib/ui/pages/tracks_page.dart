import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/expandable_box.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';
import 'package:namida/ui/widgets/sort_by_button.dart';

class TracksPage extends StatelessWidget {
  final bool animateTiles;
  const TracksPage({super.key, required this.animateTiles});

  bool get _shouldAnimate => animateTiles && LibraryTab.tracks.shouldAnimateTiles;

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: Obx(
        () {
          SettingsController.inst.trackListTileHeight.value;
          return NamidaTracksList(
            queueLength: SearchSortController.inst.trackSearchList.length,
            queueSource: QueueSource.allTracks,
            scrollController: LibraryTab.tracks.scrollController,
            itemBuilder: (context, i) {
              final track = SearchSortController.inst.trackSearchList[i];
              return AnimatingTile(
                key: ValueKey(i),
                position: i,
                shouldAnimate: _shouldAnimate,
                child: TrackTile(
                  index: i,
                  trackOrTwd: track,
                  draggableThumbnail: false,
                  queueSource: QueueSource.allTracks,
                ),
              );
            },
            widgetsInColumn: [
              ExpandableBox(
                enableHero: false,
                isBarVisible: LibraryTab.tracks.isBarVisible,
                showSearchBox: LibraryTab.tracks.isSearchBoxVisible,
                displayloadingIndicator: Indexer.inst.isIndexing.value,
                leftWidgets: [
                  NamidaIconButton(
                    icon: Broken.shuffle,
                    onPressed: () => Player.inst.playOrPause(0, SearchSortController.inst.trackSearchList, QueueSource.allTracks, shuffle: true),
                    iconSize: 18.0,
                    horizontalPadding: 0,
                  ),
                  const SizedBox(width: 12.0),
                  NamidaIconButton(
                    icon: Broken.play,
                    onPressed: () => Player.inst.playOrPause(0, SearchSortController.inst.trackSearchList, QueueSource.allTracks),
                    iconSize: 18.0,
                    horizontalPadding: 0,
                  ),
                  const SizedBox(width: 12.0),
                ],
                leftText: SearchSortController.inst.trackSearchList.displayTrackKeyword,
                onFilterIconTap: () => ScrollSearchController.inst.switchSearchBoxVisibilty(LibraryTab.tracks),
                onCloseButtonPressed: () {
                  ScrollSearchController.inst.clearSearchTextField(LibraryTab.tracks);
                },
                sortByMenuWidget: SortByMenu(
                  title: SettingsController.inst.tracksSort.value.toText(),
                  popupMenuChild: const SortByMenuTracks(),
                  isCurrentlyReversed: SettingsController.inst.tracksSortReversed.value,
                  onReverseIconTap: () {
                    SearchSortController.inst.sortMedia(MediaType.track, reverse: !SettingsController.inst.tracksSortReversed.value);
                  },
                ),
                textField: CustomTextFiled(
                  textFieldController: LibraryTab.tracks.textSearchController,
                  textFieldHintText: lang.FILTER_TRACKS,
                  onTextFieldValueChanged: (value) => SearchSortController.inst.searchMedia(value, MediaType.track),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
