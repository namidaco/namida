import 'package:flutter/material.dart';

import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
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
        if (currentItem is YoutubeID) return _YoutubeQueueList(addPageBottomPadding: addPageBottomPadding, showHeaderAndFooter: showHeaderAndFooter);
        return _LocalQueueList(addPageBottomPadding: addPageBottomPadding, showHeaderAndFooter: showHeaderAndFooter);
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
          Icon(
            Broken.menu_board,
            size: 48.0,
            color: context.theme.disabledColor,
          ),
          const SizedBox(height: 12.0),
          Text(
            lang.noTracksFound,
            style: context.textTheme.displayMedium,
          ),
        ],
      ),
    );
  }
}

class _QueueListBase extends StatefulWidget {
  final double itemExtent;
  final bool addPageBottomPadding;
  final Widget? header;
  final Widget Function(Widget scrollQueueWidget)? utilsRowBuilder;
  final Widget Function(BuildContext context, int index, List<Playable> queue) itemBuilder;

  const _QueueListBase({
    required this.itemExtent,
    required this.addPageBottomPadding,
    required this.header,
    required this.utilsRowBuilder,
    required this.itemBuilder,
  });

  @override
  State<_QueueListBase> createState() => _QueueListBaseState();
}

class _QueueListBaseState extends State<_QueueListBase> {
  late final _scrollController = NamidaScrollController.create();
  late final _arrowIcon = Broken.cd.obs;

  @override
  void initState() {
    super.initState();
    if (widget.utilsRowBuilder != null) _scrollController.addListener(_updateArrowIcon);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _arrowIcon.close();
    super.dispose();
  }

  /// clamped, otherwise the icon never settles on [Broken.cd] for items near the edges.
  double? _currentItemScrollOffset() {
    final position = _scrollController.positions.lastOrNull;
    if (position == null) return null;
    final offset = widget.itemExtent * Player.inst.currentIndex.value - position.viewportDimension * 0.2;
    return offset.clampDouble(position.minScrollExtent, position.maxScrollExtent);
  }

  void _updateArrowIcon() {
    final target = _currentItemScrollOffset();
    if (target == null) return;
    final pixels = _scrollController.positions.last.pixels;
    _arrowIcon.value = pixels > target
        ? Broken.arrow_up_1
        : pixels < target
        ? Broken.arrow_down
        : Broken.cd;
  }

  void _animateToCurrentItem() {
    final target = _currentItemScrollOffset();
    if (target == null || _scrollController.positions.last.pixels == target) return;
    _scrollController.animateToEff(
      target,
      duration: const Duration(milliseconds: 600),
      curve: Curves.fastEaseInToSlowEaseOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ObxO(
      rx: Player.inst.currentQueue,
      builder: (context, queue) {
        final queueLength = queue.length;
        if (queueLength == 0) return const _EmptyQueue();
        final header = widget.header;
        final utilsRowBuilder = widget.utilsRowBuilder;
        Widget listChild = NamidaScrollbar(
          controller: _scrollController,
          child: SmoothCustomScrollView(
            controller: _scrollController,
            slivers: [
              const SliverPadding(padding: EdgeInsets.only(top: Dimensions.tileBottomMargin6)),
              NamidaSliverReorderableList(
                itemCount: queueLength,
                itemExtent: widget.itemExtent,
                onReorderStart: (index) => Player.inst.invokeQueueModifyLock(),
                onReorderEnd: (index) => Player.inst.invokeQueueModifyLockRelease(),
                onReorder: (oldIndex, newIndex) => Player.inst.reorderTrack(oldIndex, newIndex),
                onReorderCancel: () => Player.inst.invokeQueueModifyOnModifyCancel(),
                itemBuilder: (context, i) => widget.itemBuilder(context, i, queue),
              ),
              if (widget.addPageBottomPadding) kBottomPaddingWidgetSliver else const SliverPadding(padding: EdgeInsets.only(bottom: 12.0)),
            ],
          ),
        );
        if (header != null || utilsRowBuilder != null) {
          listChild = Column(
            crossAxisAlignment: .end,
            children: [
              ?header,
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
                          rx: _arrowIcon,
                          builder: (context, arrowIcon) => NamidaButton(
                            tooltip: () => lang.jump,
                            onTap: _animateToCurrentItem,
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

Widget _dismissibleWrapper({
  required int index,
  required Key childKey,
  required int queueLength,
  required Widget child,
}) {
  return FadeDismissible(
    key: Key("Diss_${index}_${childKey}_$queueLength"), // queue length only for when removing current item and next is the same.
    onDismissed: (direction) async {
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
        header: showHeaderAndFooter
            ? const LocalQueueChipHeaderRow(
                addLeftMargin: true,
                showPlaybackActions: true,
                onArrowDownPressed: null,
              )
            : null,
        utilsRowBuilder: showHeaderAndFooter
            ? (scrollQueueWidget) => QueueUtilsRow(
                itemsKeyword: (number) => number.displayTrackKeyword,
                onAddItemsTap: () => TracksAddOnTap().onAddTracksTap(context),
                scrollQueueWidget: scrollQueueWidget,
              )
            : null,
        itemBuilder: (context, i, queue) {
          final track = queue[i] as Selectable;
          final key = Key("${i}_${track.track.path}");
          return _dismissibleWrapper(
            index: i,
            childKey: key,
            queueLength: queue.length,
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
                  // -- to improve performance, skipping process of checking new queues, etc..
                  if (i == Player.inst.currentIndex.value) {
                    Player.inst.togglePlayPause();
                  } else {
                    Player.inst.skipToQueueItem(i);
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }
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
        header: showHeaderAndFooter
            ? const YTQueueChipHeaderRow(
                addLeftMargin: true,
                showPlaybackActions: true,
                onArrowDownPressed: null,
              )
            : null,
        utilsRowBuilder: showHeaderAndFooter
            ? (scrollQueueWidget) => QueueUtilsRow(
                itemsKeyword: (number) => number.displayVideoKeyword,
                onAddItemsTap: () => TracksAddOnTap().onAddVideosTap(context),
                scrollQueueWidget: scrollQueueWidget,
              )
            : null,
        itemBuilder: (context, i, queue) {
          final video = queue[i] as YoutubeID;
          final key = Key("${i}_${video.id}");
          return _dismissibleWrapper(
            index: i,
            childKey: key,
            queueLength: queue.length,
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
              ),
            ),
          );
        },
      ),
    );
  }
}
