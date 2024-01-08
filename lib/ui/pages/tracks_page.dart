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
import 'package:namida/ui/widgets/settings/indexer_settings.dart';
import 'package:namida/ui/widgets/sort_by_button.dart';

class TracksPage extends StatefulWidget {
  final bool animateTiles;
  const TracksPage({super.key, required this.animateTiles});

  @override
  State<TracksPage> createState() => _TracksPageState();
}

class _TracksPageState extends State<TracksPage> with TickerProviderStateMixin {
  bool get _shouldAnimate => widget.animateTiles && LibraryTab.tracks.shouldAnimateTiles;

  final _animationKey = 'tracks_page';
  final turnsTween = Tween<double>(begin: 0.0, end: 1.0);
  late final animation = AnimationController(vsync: this, duration: Duration.zero);
  AnimationController get animation2 => RefreshLibraryIconController.getController(_animationKey, this);

  final _minTrigger = 20;

  @override
  void initState() {
    RefreshLibraryIconController.init(_animationKey, this);
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    animation.dispose();
    RefreshLibraryIconController.dispose(_animationKey);
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: Listener(
        onPointerUp: (event) {
          if (animation.value == 1) {
            showRefreshPromptDialog(false);
          }
        },
        child: NotificationListener<ScrollMetricsNotification>(
          onNotification: (notification) {
            final pixels = notification.metrics.pixels;
            if (pixels < -_minTrigger) {
              animation.animateTo(((pixels + _minTrigger).abs() / 20).clamp(0, 1));
            } else if (animation.value > 0) {
              animation.animateTo(0);
            }
            return true;
          },
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
                      itemCount: SearchSortController.inst.trackSearchList.length,
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
                      listBuilder: (list) {
                        return Stack(
                          children: [
                            list,
                            Positioned(
                              left: 0,
                              right: 0,
                              child: AnimatedBuilder(
                                animation: animation,
                                child: CircleAvatar(
                                  radius: 24.0,
                                  backgroundColor: context.theme.colorScheme.secondaryContainer,
                                  child: const Icon(Broken.refresh_2),
                                ),
                                builder: (context, circleAvatar) {
                                  final p = animation.value;
                                  const multiplier = 4.5;
                                  const minus = multiplier / 3;
                                  return Padding(
                                    padding: EdgeInsets.only(top: 12.0 + p * 128.0),
                                    child: Transform.rotate(
                                      angle: (p * multiplier) - minus,
                                      child: AnimatedBuilder(
                                        animation: animation2,
                                        child: circleAvatar,
                                        builder: (context, circleAvatar) {
                                          return Opacity(
                                            opacity: animation2.status == AnimationStatus.forward ? 1.0 : p,
                                            child: RotationTransition(
                                              key: const Key('rotatie'),
                                              turns: turnsTween.animate(animation2),
                                              child: circleAvatar,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
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
      ),
    );
  }
}
