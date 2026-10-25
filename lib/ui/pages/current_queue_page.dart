import 'package:flutter/material.dart';

import 'package:namida/base/queue_search.dart';
import 'package:namida/class/queue_scroll_follower.dart';
import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/party/party_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/widgets/yt_history_video_card.dart';
import 'package:namida/youtube/widgets/yt_queue_chip.dart';

class CurrentQueuePage extends StatelessWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.PAGE_currentQueue;

  const CurrentQueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const BackgroundWrapper(
      child: CurrentQueueList(
        showHeaderAndFooter: true,
      ),
    );
  }
}

class CurrentQueueList extends StatelessWidget {
  final bool addPageBottomPadding;
  final bool showHeaderAndFooter;

  const CurrentQueueList({
    super.key,
    this.addPageBottomPadding = true,
    this.showHeaderAndFooter = false,
  });

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: Player.inst.currentItem,
      builder: (context, currentItem) {
        if (currentItem == null) return const _EmptyQueue();
        return ObxO(
          rx: settings.mixedQueue,
          builder: (context, mixedQueue) => ObxO(
            rx: PartyController.inst.forcesMixedQueue,
            builder: (context, partyMixedQueue) {
              if (mixedQueue || partyMixedQueue) return _MixedQueueList(addPageBottomPadding: addPageBottomPadding, showHeaderAndFooter: showHeaderAndFooter);
              if (currentItem is YoutubeID) return _YoutubeQueueList(addPageBottomPadding: addPageBottomPadding, showHeaderAndFooter: showHeaderAndFooter);
              return _LocalQueueList(addPageBottomPadding: addPageBottomPadding, showHeaderAndFooter: showHeaderAndFooter);
            },
          ),
        );
      },
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const NIcon(
            Broken.menu_board,
            size: 48.0,
            color: NColors.disabled,
          ),
          const SizedBox(height: 12.0),
          NamidaText(
            lang.noTracksFound,
            style: NText.medium,
          ),
        ],
      ),
    );
  }
}

class _QueueListBase extends StatefulWidget {
  final double itemExtent;
  final double Function(int index)? itemExtentOf;
  final bool addPageBottomPadding;
  final Widget Function(void Function() onSearchTap)? headerBuilder;
  final Widget Function(Widget scrollQueueWidget)? utilsRowBuilder;
  final Widget Function(BuildContext context, int index, List<Playable> queue, void Function(int index)? onResultTap) itemBuilder;

  const _QueueListBase({
    required this.itemExtent,
    this.itemExtentOf,
    required this.addPageBottomPadding,
    required this.headerBuilder,
    required this.utilsRowBuilder,
    required this.itemBuilder,
  });

  @override
  State<_QueueListBase> createState() => _QueueListBaseState();
}

class _QueueListBaseState extends State<_QueueListBase> {
  late final _queueFollower = QueueScrollFollower(currentItemStart: _currentItemStart);
  double? _mixedCurrentItemStart;
  QueueSearch? _search;

  @override
  void initState() {
    super.initState();
    if (widget.headerBuilder != null) _search = QueueSearch(onResultsChanged: _onSearchResultsChanged, onResultSelected: _onSearchResultSelected);
    Player.inst.currentIndex.addListener(_onCurrentItemMoved);
    Player.inst.currentQueue.addListener(_onCurrentItemMoved);
    WidgetsBinding.instance.addPostFrameCallback(_jumpToCurrentItem);
  }

  @override
  void dispose() {
    Player.inst.currentIndex.removeListener(_onCurrentItemMoved);
    Player.inst.currentQueue.removeListener(_onCurrentItemMoved);
    _queueFollower.dispose();
    _search?.dispose();
    super.dispose();
  }

  void _jumpToCurrentItem(Duration _) {
    if (mounted) _queueFollower.jumpToCurrentItem();
  }

  void _onCurrentItemMoved() {
    _mixedCurrentItemStart = null;
    _queueFollower.onCurrentItemMoved();
  }

  void _jumpToStart(Duration _) {
    if (mounted) _queueFollower.jumpToItem(0.0);
  }

  void _onSearchResultsChanged(bool isNewQuery) {
    _mixedCurrentItemStart = null;
    if (!isNewQuery) {
      _queueFollower.onCurrentItemMoved();
      return;
    }
    final isFiltering = _search?.results.value != null;
    WidgetsBinding.instance.addPostFrameCallback(isFiltering ? _jumpToStart : _jumpToCurrentItem);
  }

  void _onSearchResultSelected(int index) {
    _mixedCurrentItemStart = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _queueFollower.jumpToItem(_itemStartOf(index));
    });
  }

  double _itemStartOf(int index) {
    final itemExtentOf = widget.itemExtentOf;
    if (itemExtentOf == null) return widget.itemExtent * index;
    double start = 0.0;
    for (int i = 0; i < index; i++) {
      start += itemExtentOf(i);
    }
    return start;
  }

  double? _currentItemStart() {
    final index = Player.inst.currentIndex.value;
    final search = _search;
    final results = search?.results.value;
    final position = search == null ? index : search.positionOf(index);
    if (position == null) return null;
    final itemExtentOf = widget.itemExtentOf;
    if (itemExtentOf == null) return widget.itemExtent * position;
    final cached = _mixedCurrentItemStart;
    if (cached != null) return cached;
    double start = 0.0;
    for (int i = 0; i < position; i++) {
      final queueIndex = results == null ? i : results[i];
      start += itemExtentOf(queueIndex);
    }
    return _mixedCurrentItemStart = start;
  }

  @override
  Widget build(BuildContext context) {
    final search = _search;
    final headerBuilder = widget.headerBuilder;
    final header = headerBuilder != null && search != null ? headerBuilder(search.toggle) : null;
    final searchBox = search == null
        ? null
        : QueueSearchBox(
            search: search,
          );
    return ObxO(
      rx: Player.inst.currentQueue,
      builder: (context, queue) {
        if (queue.isEmpty) return const _EmptyQueue();
        final utilsRowBuilder = widget.utilsRowBuilder;
        final itemExtentOf = widget.itemExtentOf;
        final scrollController = _queueFollower.scrollController;
        Widget listChild = NamidaScrollbar(
          controller: scrollController,
          child: SmoothCustomScrollView(
            controller: scrollController,
            slivers: [
              const SliverPadding(padding: EdgeInsets.only(top: Dimensions.tileBottomMargin6)),
              QueueSliverList(
                queue: queue,
                search: search,
                itemExtent: itemExtentOf == null ? widget.itemExtent : null,
                itemExtentOf: itemExtentOf,
                itemBuilder: widget.itemBuilder,
              ),
              if (widget.addPageBottomPadding) kBottomPaddingWidgetSliver else const SliverPadding(padding: EdgeInsets.only(bottom: 12.0)),
            ],
          ),
        );
        if (utilsRowBuilder == null) {
          listChild = Stack(
            children: [
              listChild,
              Positioned(
                bottom: 12.0,
                right: 12.0,
                child: ObxO(
                  rx: _queueFollower.arrowIcon,
                  builder: (context, arrowIcon) => _FloatingJumpButton(
                    arrowIcon: arrowIcon,
                    onTap: _queueFollower.animateToCurrentItem,
                  ),
                ),
              ),
            ],
          );
        }
        if (header != null || utilsRowBuilder != null) {
          listChild = Column(
            crossAxisAlignment: .end,
            children: [
              ?header,
              ?searchBox,
              if (utilsRowBuilder != null)
                SizedBox(
                  height: kQueueBottomRowHeight,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: utilsRowBuilder(
                        ObxO(
                          rx: _queueFollower.arrowIcon,
                          builder: (context, arrowIcon) => NamidaButton(
                            tooltip: () => lang.jump,
                            onTap: _queueFollower.animateToCurrentItem,
                            icon: arrowIcon,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: listChild,
              ),
            ],
          );
        }
        return listChild;
      },
    );
  }
}

class _FloatingJumpButton extends StatelessWidget {
  final IconData arrowIcon;
  final void Function() onTap;

  const _FloatingJumpButton({required this.arrowIcon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DelayedAnimatedShow(
      show: arrowIcon != Broken.cd,
      showDelay: const Duration(milliseconds: 1200),
      duration: const Duration(milliseconds: 600),
      child: NamidaInkWell(
        borderRadius: 10.0,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        bgColor: const NColors(.secondary, opacity: 0.3),
        child: Row(
          mainAxisSize: .min,
          children: [
            const SizedBox(width: 12.0),
            Icon(
              arrowIcon,
              size: 18.0,
            ),
            const SizedBox(width: 6.0),
            NamidaText(
              lang.jump,
              style: NText.medium,
            ),
            const SizedBox(width: 12.0),
          ],
        ),
      ),
    );
  }
}

// -- only the row at the last removed index gets re-keyed, for when the next item is the same as the removed one.
// -- better alternative for putting queueLength in each item key
int _lastRemovedIndex = -1;
int _removalNonce = 0;

Widget _dismissibleWrapper({
  required int index,
  required Key childKey,
  required Widget child,
}) {
  return FadeDismissible(
    key: Key(index == _lastRemovedIndex ? "Diss_${index}_${childKey}_$_removalNonce" : "Diss_${index}_$childKey"),
    onDismissed: (direction) async {
      _lastRemovedIndex = index;
      _removalNonce++;
      await Player.inst.removeFromQueueWithUndo(index);
      Player.inst.invokeQueueModifyLockRelease();
    },
    onDismissStart: (_) => Player.inst.invokeQueueModifyLock(),
    onDismissCancel: (_) => Player.inst.invokeQueueModifyOnModifyCancel(),
    child: child,
  );
}

class _LocalQueueList extends StatelessWidget {
  final bool addPageBottomPadding;
  final bool showHeaderAndFooter;

  const _LocalQueueList({required this.addPageBottomPadding, required this.showHeaderAndFooter});

  @override
  Widget build(BuildContext context) {
    return TrackTilePropertiesProvider(
      configs: const TrackTilePropertiesConfigs(
        displayRightDragHandler: true,
        draggableThumbnail: true,
        queueSource: QueueSource.playerQueue,
      ),
      builder: (properties) => _QueueListBase(
        itemExtent: Dimensions.inst.trackTileItemExtent,
        addPageBottomPadding: addPageBottomPadding,
        headerBuilder: showHeaderAndFooter
            ? (onSearchTap) => LocalQueueChipHeaderRow(
                addLeftMargin: true,
                showPlaybackActions: true,
                onArrowDownPressed: null,
                onSearchTap: onSearchTap,
              )
            : null,
        utilsRowBuilder: showHeaderAndFooter
            ? (scrollQueueWidget) => QueueUtilsRow(
                itemsKeyword: (number) => number.displayTrackKeyword,
                onAddItemsTap: () => TracksAddOnTap().onAddTracksTap(context),
                scrollQueueWidget: scrollQueueWidget,
              )
            : null,
        itemBuilder: (context, i, queue, onResultTap) => _localQueueItem(context, i, queue, properties, onResultTap),
      ),
    );
  }
}

Widget _localQueueItem(BuildContext context, int i, List<Playable> queue, TrackTileProperties properties, void Function(int index)? onResultTap) {
  final track = queue[i] as Selectable;
  final key = Key("${i}_${track.track.path}");
  return _dismissibleWrapper(
    index: i,
    childKey: key,
    child: ObxOSelect(
      rx: Player.inst.currentIndex,
      selector: (currentIndex) => i < currentIndex,
      builder: (context, isPlayed) => TrackTile(
        properties: properties,
        key: key,
        index: i,
        trackOrTwd: track,
        tracks: queue,
        fadeOpacity: isPlayed ? 0.3 : 0.0,
        onPlaying: () {
          if (onResultTap == null) {
            Player.inst.playQueueItem(i);
          } else {
            onResultTap(i);
          }
        },
      ),
    ),
  );
}

class _YoutubeQueueList extends StatelessWidget {
  final bool addPageBottomPadding;
  final bool showHeaderAndFooter;

  const _YoutubeQueueList({required this.addPageBottomPadding, required this.showHeaderAndFooter});

  @override
  Widget build(BuildContext context) {
    return VideoTilePropertiesProvider(
      configs: const VideoTilePropertiesConfigs(
        openMenuOnLongPress: false,
        displayTimeAgo: false,
        draggingEnabled: true,
        draggableThumbnail: true,
        queueSource: QueueSourceYoutubeID.ytPlayerQueue,
        showMoreIcon: true,
      ),
      builder: (properties) => _QueueListBase(
        itemExtent: Dimensions.youtubeCardItemExtent,
        addPageBottomPadding: addPageBottomPadding,
        headerBuilder: showHeaderAndFooter
            ? (onSearchTap) => YTQueueChipHeaderRow(
                addLeftMargin: true,
                showPlaybackActions: true,
                onArrowDownPressed: null,
                onSearchTap: onSearchTap,
              )
            : null,
        utilsRowBuilder: showHeaderAndFooter
            ? (scrollQueueWidget) => QueueUtilsRow(
                itemsKeyword: (number) => number.displayVideoKeyword,
                onAddItemsTap: () => TracksAddOnTap().onAddVideosTap(context),
                scrollQueueWidget: scrollQueueWidget,
              )
            : null,
        itemBuilder: (context, i, queue, onResultTap) => _youtubeQueueItem(context, i, queue, properties, onResultTap),
      ),
    );
  }
}

Widget _youtubeQueueItem(BuildContext context, int i, List<Playable> queue, VideoTileProperties properties, void Function(int index)? onResultTap) {
  final video = queue[i] as YoutubeID;
  final key = Key("${i}_${video.id}");
  final onTap = onResultTap == null ? null : () => onResultTap(i);
  return _dismissibleWrapper(
    index: i,
    childKey: key,
    child: ObxOSelect(
      rx: Player.inst.currentIndex,
      selector: (currentIndex) => i < currentIndex,
      builder: (context, isPlayed) => YTHistoryVideoCard(
        properties: properties,
        key: key,
        videos: queue,
        index: i,
        day: null,
        thumbnailHeight: Dimensions.youtubeThumbnailHeight,
        fadeOpacity: isPlayed ? 0.3 : 0.0,
        preferFetchNewInfo: true,
        onTap: onTap,
      ),
    ),
  );
}

class _MixedQueueList extends StatelessWidget {
  final bool addPageBottomPadding;
  final bool showHeaderAndFooter;

  const _MixedQueueList({required this.addPageBottomPadding, required this.showHeaderAndFooter});

  @override
  Widget build(BuildContext context) {
    return TrackTilePropertiesProvider(
      configs: const TrackTilePropertiesConfigs(
        displayRightDragHandler: true,
        draggableThumbnail: true,
        queueSource: QueueSource.playerQueue,
      ),
      builder: (trackTileProperties) => VideoTilePropertiesProvider(
        configs: const VideoTilePropertiesConfigs(
          openMenuOnLongPress: false,
          displayTimeAgo: false,
          draggingEnabled: true,
          draggableThumbnail: true,
          queueSource: QueueSourceYoutubeID.ytPlayerQueue,
          showMoreIcon: true,
        ),
        builder: (videoTileProperties) => _QueueListBase(
          itemExtent: Dimensions.inst.trackTileItemExtent,
          itemExtentOf: (index) {
            final queue = Player.inst.currentQueue.value;
            return index < queue.length && queue[index] is Selectable ? Dimensions.inst.trackTileItemExtent : Dimensions.youtubeCardItemExtent;
          },
          addPageBottomPadding: addPageBottomPadding,
          headerBuilder: showHeaderAndFooter
              ? (onSearchTap) => MixedQueueChipHeaderRow(
                  addLeftMargin: true,
                  showPlaybackActions: true,
                  onArrowDownPressed: null,
                  onSearchTap: onSearchTap,
                )
              : null,
          utilsRowBuilder: showHeaderAndFooter
              ? (scrollQueueWidget) => QueueUtilsRow(
                  itemsKeyword: (number) => number.displayTrackKeyword,
                  onAddItemsTap: () => TracksAddOnTap().onAddTracksTap(context),
                  scrollQueueWidget: scrollQueueWidget,
                )
              : null,
          itemBuilder: (context, i, queue, onResultTap) => queue[i] is Selectable
              ? _localQueueItem(context, i, queue, trackTileProperties, onResultTap)
              : _youtubeQueueItem(context, i, queue, videoTileProperties, onResultTap),
        ),
      ),
    );
  }
}
