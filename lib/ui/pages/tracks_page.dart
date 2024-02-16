import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:namida/base/pull_to_refresh.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/expandable_box.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';
import 'package:namida/ui/widgets/settings/indexer_settings.dart';
import 'package:namida/ui/widgets/sort_by_button.dart';

class TracksPage extends StatefulWidget {
  final bool animateTiles;
  const TracksPage({super.key, required this.animateTiles});

  @override
  State<TracksPage> createState() => _TracksPageState();
}

class _TracksPageState extends State<TracksPage> with TickerProviderStateMixin, PullToRefreshMixin {
  bool get _shouldAnimate => widget.animateTiles && LibraryTab.tracks.shouldAnimateTiles;

  final _animationKey = 'tracks_page';

  @override
  AnimationController get animation2 => RefreshLibraryIconController.getController(_animationKey, this);

  @override
  void initState() {
    RefreshLibraryIconController.init(_animationKey, this);
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    RefreshLibraryIconController.dispose(_animationKey);
  }

  @override
  Widget build(BuildContext context) {
    final scrollController = LibraryTab.tracks.scrollController;
    return BackgroundWrapper(
      child: Listener(
        onPointerMove: (event) {
          final c = scrollController;
          if (!c.hasClients) return;
          final p = c.position.pixels;
          if (p <= 0 && event.delta.dx < 0.1) onVerticalDragUpdate(event.delta.dy);
        },
        onPointerUp: (event) {
          if (animation.value == 1) {
            showRefreshPromptDialog(false);
          }
          onVerticalDragFinish();
        },
        onPointerCancel: (event) => onVerticalDragFinish(),
        child: Obx(
          () {
            settings.trackListTileHeight.value;
            return Column(
              children: [
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
                    title: settings.tracksSort.value.toText(),
                    popupMenuChild: const SortByMenuTracks(),
                    isCurrentlyReversed: settings.tracksSortReversed.value,
                    onReverseIconTap: () {
                      SearchSortController.inst.sortMedia(MediaType.track, reverse: !settings.tracksSortReversed.value);
                    },
                  ),
                  textField: CustomTextFiled(
                    textFieldController: LibraryTab.tracks.textSearchController,
                    textFieldHintText: lang.FILTER_TRACKS,
                    onTextFieldValueChanged: (value) => SearchSortController.inst.searchMedia(value, MediaType.track),
                  ),
                ),
                Expanded(
                  child: NamidaListViewRaw(
                    itemExtents: List.filled(SearchSortController.inst.trackSearchList.length, Dimensions.inst.trackTileItemExtent),
                    itemCount: SearchSortController.inst.trackSearchList.length,
                    scrollController: LibraryTab.tracks.scrollController,
                    scrollStep: Dimensions.inst.trackTileItemExtent,
                    itemBuilder: (context, i) {
                      final track = SearchSortController.inst.trackSearchList[i];
                      return AnimatingTile(
                        key: Key("$i${track.path}"),
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
                    listBuilder: (list) {
                      return Stack(
                        children: [
                          list,
                          pullToRefreshWidget,
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
