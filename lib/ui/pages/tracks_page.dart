import 'package:flutter/material.dart';

import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import 'package:namida/base/pull_to_refresh.dart';
import 'package:namida/class/route.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/settings_search_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/expandable_box.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';
import 'package:namida/ui/widgets/settings/indexer_settings.dart';
import 'package:namida/ui/widgets/sort_by_button.dart';

class TracksPage extends StatefulWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.PAGE_allTracks;

  final bool animateTiles;
  const TracksPage({super.key, required this.animateTiles});

  @override
  State<TracksPage> createState() => _TracksPageState();
}

class _TracksPageState extends State<TracksPage> with TickerProviderStateMixin, PullToRefreshMixin {
  bool get _shouldAnimate => widget.animateTiles && LibraryTab.tracks.shouldAnimateTiles;

  final _animationKey = 'tracks_page';

  @override
  AnimationController get refreshAnimation => RefreshLibraryIconController.getController(_animationKey, this);

  @override
  void initState() {
    super.initState();
    RefreshLibraryIconController.init(_animationKey, this);
  }

  @override
  void dispose() {
    super.dispose();
    RefreshLibraryIconController.dispose(_animationKey);
  }

  @override
  Widget build(BuildContext context) {
    const libraryTab = LibraryTab.tracks;
    final scrollController = libraryTab.scrollController;

    const listHeader = ExpandableBoxEmptyAnimatedPadding(tab: libraryTab);

    return BackgroundWrapper(
      child: Listener(
        onPointerMove: (event) {
          onPointerMove(scrollController, event);
        },
        onPointerUp: (event) {
          onRefresh(() async => await showRefreshPromptDialog(false, allowBypassing: true));
        },
        onPointerCancel: (event) => onVerticalDragFinish(),
        child: ExpandableBoxColumn(
          tab: libraryTab,
          header: Obx(
            (context) {
              final finalTracksLength = SearchSortController.inst.trackSearchList.valueR.length;
              final totalTracksLength = Indexer.inst.tracksInfoList.valueR.length;
              String leftText = finalTracksLength != totalTracksLength ? '$finalTracksLength/${totalTracksLength.displayTrackKeyword}' : finalTracksLength.displayTrackKeyword;
              final isIndexingR = Indexer.inst.isIndexing.valueR;
              return ExpandableBox(
                enableHero: false,
                isBarVisible: libraryTab.isBarVisible.valueR,
                displayloadingIndicator: isIndexingR,
                leftWidgets: [
                  NamidaIconButton(
                    icon: Broken.shuffle,
                    onPressed: () => Player.inst.playOrPause(0, SearchSortController.inst.trackSearchList.value, QueueSource.allTracksAll, shuffle: true, gentlePlay: false),
                    onLongPress: () => SubpageInfoContainer.openAdvancedShuffleDialog(() => SearchSortController.inst.trackSearchList.value, QueueSource.allTracksAll),
                    iconSize: 18.0,
                    horizontalPadding: 2.0,
                  ),
                  const SizedBox(width: 10.0),
                  NamidaIconButton(
                    icon: Broken.play,
                    onPressed: () => Player.inst.playOrPause(0, SearchSortController.inst.trackSearchList.value, QueueSource.allTracksAll, gentlePlay: false),
                    onLongPress: () => SubpageInfoContainer.openAdvancedPlayDialog(() => SearchSortController.inst.trackSearchList.value, QueueSource.allTracksAll),
                    iconSize: 18.0,
                    horizontalPadding: 2.0,
                  ),
                  const SizedBox(width: 10.0),
                ],
                leftText: leftText,
                onSearchBoxVisibilityChange: (newShow) => ScrollSearchController.inst.onSearchBoxVisibiltyChange(libraryTab, newShow),
                onCloseButtonPressed: () {
                  ScrollSearchController.inst.clearSearchTextField(libraryTab);
                },
                sortByMenuWidget: SortByMenu(
                  title: settings.mediaItemsTrackSorting.valueR[MediaType.track]?.firstOrNull?.toText() ?? '',
                  popupMenuChild: const SortByMenuTracks(),
                  isCurrentlyReversed: settings.mediaItemsTrackSortingReverse.valueR[MediaType.track] == true,
                  onReverseIconTap: () {
                    SearchSortController.inst.sortMedia(MediaType.track, reverse: !(settings.mediaItemsTrackSortingReverse[MediaType.track] == true));
                  },
                ),
                textField: CustomTextField(
                  textFieldController: libraryTab.textSearchControllerUI,
                  textFieldHintText: lang.filterTracks,
                  onTextFieldValueChanged: (value) => SearchSortController.inst.searchMedia(value, MediaType.track),
                ),
              );
            },
          ),
          page: AnimationLimiter(
            child: TrackTilePropertiesProvider(
              configs: const TrackTilePropertiesConfigs(
                queueSource: QueueSource.allTracks,
              ),
              builder: (properties) => ObxO(
                rx: SearchSortController.inst.trackSearchList,
                builder: (context, trackSearchList) => trackSearchList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              lang.noTracksFound,
                              style: context.textTheme.displayLarge,
                            ),
                            const SizedBox(height: 8.0),
                            NamidaInkWell(
                              borderRadius: 8.0,
                              bgColor: context.theme.cardColor,
                              padding: const EdgeInsetsGeometry.symmetric(horizontal: 12.0, vertical: 6.0),
                              onTap: () {
                                SettingsSearchController.inst
                                    .onResultTap(
                                      settingPage: SettingSubpageEnum.indexer,
                                      key: IndexerSettingsKeysGlobal.addFolder,
                                      context: context,
                                    )
                                    .ignoreError();
                                const IndexerSettings().promptAddFolderType();
                              },
                              child: Text(
                                lang.addFolder,
                                style: context.textTheme.displayLarge,
                              ),
                            ),
                          ],
                        ),
                      )
                    : NamidaListView(
                        itemExtent: Dimensions.inst.trackTileItemExtent,
                        itemCount: trackSearchList.length,
                        scrollController: libraryTab.scrollController,
                        scrollStep: Dimensions.inst.trackTileItemExtent,
                        header: listHeader,
                        itemBuilder: (context, i) {
                          final track = trackSearchList[i];
                          return AnimatingTile(
                            key: Key("$i${track.path}"),
                            position: i,
                            shouldAnimate: _shouldAnimate,
                            child: TrackTile(
                              properties: properties,
                              index: i,
                              trackOrTwd: track,
                              tracks: trackSearchList,
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
            ),
          ),
        ),
      ),
    );
  }
}
