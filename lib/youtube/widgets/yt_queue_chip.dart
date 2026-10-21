import 'dart:async';

import 'package:flutter/material.dart';

import 'package:youtipie/class/youtipie_feed/playlist_basic_info.dart';

import 'package:namida/base/queue_search.dart';
import 'package:namida/base/setting_subpage_provider.dart';
import 'package:namida/class/queue_scroll_follower.dart';
import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/lyrics_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
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
import 'package:namida/packages/miniplayer_base.dart';
import 'package:namida/packages/scroll_physics_modified.dart';
import 'package:namida/ui/dialogs/add_to_playlist_dialog.dart';
import 'package:namida/ui/dialogs/general_popup_dialog.dart';
import 'package:namida/ui/dialogs/set_lrc_dialog.dart';
import 'package:namida/ui/pages/party_page.dart';
import 'package:namida/ui/pages/settings_page.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/playback_settings.dart';
import 'package:namida/ui/widgets/settings/youtube_settings.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/yt_generators_controller.dart';
import 'package:namida/youtube/controller/yt_miniplayer_ui_controller.dart';
import 'package:namida/youtube/functions/add_to_playlist_sheet.dart';
import 'package:namida/youtube/pages/yt_playlist_download_subpage.dart';
import 'package:namida/youtube/widgets/yt_history_video_card.dart';

/// save state after resuming app from pip
bool _wasOpened = false;

class YTMiniplayerQueueChip extends StatefulWidget {
  final Widget? overlay;
  final void Function(bool isFullyExpanded)? onExpandedStateChange;
  const YTMiniplayerQueueChip({super.key, this.overlay, required this.onExpandedStateChange});

  @override
  State<YTMiniplayerQueueChip> createState() => YTMiniplayerQueueChipState();
}

class YTMiniplayerQueueChipState extends State<YTMiniplayerQueueChip> with TickerProviderStateMixin {
  // -- note: animation values are inversed, as they represent offset percentage.

  late final AnimationController _smallBoxAnimation;

  late final AnimationController _bigBoxAnimation;

  late final _queueFollower = QueueScrollFollower(currentItemStart: _currentItemStart, canFollow: () => isOpened);
  late final _canScrollQueue = true.obs;
  late final _search = QueueSearch(onResultsChanged: _onSearchResultsChanged, onResultSelected: _onSearchResultSelected);

  bool get isOpened => _smallBoxAnimation.value == 1 && _bigBoxAnimation.value == 0;
  void toggleSheet() => isOpened ? dismissSheet() : openSheet();
  void openSheet() => _animateSmallToBig();
  void dismissSheet() => _animateBigToSmall();

  @override
  void initState() {
    _smallBoxAnimation = AnimationController(
      vsync: this,
      value: _wasOpened ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 500),
    );

    _bigBoxAnimation = AnimationController(
      vsync: this,
      value: _wasOpened ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 500),
    );

    Player.inst.currentIndex.addListener(_queueFollower.onCurrentItemMoved);
    Player.inst.currentQueue.addListener(_queueFollower.onCurrentItemMoved);
    if (widget.onExpandedStateChange != null) _bigBoxAnimation.addListener(_updateIsFullyOpened);
    Timer(Duration.zero, () {
      _updateIsFullyOpened();
    });
    super.initState();
  }

  @override
  void dispose() {
    _wasOpened = isOpened;
    _smallBoxAnimation.dispose();
    _bigBoxAnimation.dispose();
    Player.inst.currentIndex.removeListener(_queueFollower.onCurrentItemMoved);
    Player.inst.currentQueue.removeListener(_queueFollower.onCurrentItemMoved);
    _queueFollower.dispose();
    _canScrollQueue.close();
    _search.dispose();
    super.dispose();
  }

  bool _isFullyCovering = false;
  void _updateIsFullyOpened() {
    final isNowCovering = isOpened;
    if (isNowCovering != _isFullyCovering) {
      _isFullyCovering = isNowCovering;
      widget.onExpandedStateChange!(isNowCovering);
    }
  }

  void _updateCanScrollQueue(bool can) {
    if (_canScrollQueue.value != can) _canScrollQueue.value = can;
  }

  void _animate(double small, double big) {
    _smallBoxAnimation.animateTo(small, curve: Curves.fastEaseInToSlowEaseOut, duration: const Duration(milliseconds: 600));
    _bigBoxAnimation.animateTo(big, curve: Curves.fastEaseInToSlowEaseOut, duration: const Duration(milliseconds: 600));
  }

  void _jump(double small, double big) {
    _smallBoxAnimation.animateTo(small, duration: Duration.zero);
    _bigBoxAnimation.animateTo(big, duration: Duration.zero);
  }

  void _animateSmallToBig() {
    final wasAlreadyBig = NamidaNavigator.inst.isQueueSheetOpen;
    _animate(1, 0);
    YoutubeMiniplayerUiController.inst.startDimTimer();
    NamidaNavigator.inst.isQueueSheetOpen = true;
    _updateCanScrollQueue(true);
    if (!wasAlreadyBig) WidgetsBinding.instance.addPostFrameCallback((_) => _queueFollower.animateToCurrentItem());
  }

  void _animateBigToSmall() {
    _search.close();
    _animate(0, 1);
    YoutubeMiniplayerUiController.inst.startDimTimer();
    NamidaYTGenerator.inst.cleanResources();
    NamidaNavigator.inst.isQueueSheetOpen = false;
  }

  void _onSearchResultsChanged(bool isNewQuery) {
    if (isNewQuery) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _queueFollower.jumpToCurrentItem());
    } else {
      _queueFollower.onCurrentItemMoved();
    }
  }

  void _onSearchResultSelected(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _queueFollower.jumpToItem(Dimensions.youtubeCardItemExtent * index));
  }

  double? _currentItemStart() {
    final index = Player.inst.currentIndex.value;
    final results = _search.results.value;
    final position = results == null ? index : QueueSearch.positionOf(results, index);
    if (position == null) return null;
    return Dimensions.youtubeCardItemExtent * position;
  }

  double _smallBoxDrag = 1.0;
  double _bigBoxDrag = 0.0;

  @override
  Widget build(BuildContext context) {
    final maxHeight = context.height;
    const minHeight = kYTQueueSheetMinHeight;
    const smallChipBorderRadius = 12.0;
    const smallChipMargin = EdgeInsets.symmetric(horizontal: 18.0, vertical: 6.0);

    return Stack(
      alignment: Alignment.bottomCenter,
      fit: StackFit.expand,
      children: [
        ObxO(
          rx: Player.inst.currentQueue,
          builder: (context, queue) {
            // -- single design.. byebye
            // final singleWidget = queue.length == 1
            //     ? Padding(
            //         padding: const EdgeInsets.all(12.0),
            //         child: NamidaFABButton(
            //           icon: Broken.driver,
            //           onTap: () => _animateSmallToBig(),
            //         ),
            //       )
            //     : null;
            return Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _smallBoxAnimation,
                child: Stack(
                  children: [
                    GestureDetector(
                      onVerticalDragUpdate: (event) {
                        _smallBoxDrag = (_smallBoxDrag + event.delta.dy * 0.002).clampDouble(0, 1);
                        if (_smallBoxDrag > 0.0 && _smallBoxDrag < 1.0) {
                          _jump(1 - _smallBoxDrag, _smallBoxDrag);
                        }
                      },
                      onVerticalDragEnd: (d) {
                        if (1 - _smallBoxDrag > 0.4 || d.velocity.pixelsPerSecond.dy < -250) {
                          _animateSmallToBig();
                        } else {
                          _animateBigToSmall();
                        }
                        _smallBoxDrag = 1.0;
                      },
                      child: NamidaInkWell(
                        borderRadius: smallChipBorderRadius,
                        onTap: () => _animateSmallToBig(),
                        margin: smallChipMargin,
                        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
                        height: minHeight,
                        bgColor: NColors.custom((c) => Color.alphaBlend(c.card.withOpacityExt(0.5), c.scaffold).withOpacityExt(0.95)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const NIcon(
                              Broken.airdrop,
                              size: 24.0,
                              color: NColors(.icon, opacity: 0.65),
                            ),
                            const SizedBox(width: 6.0),
                            Expanded(
                              child: Obx(
                                (context) {
                                  final currentIndex = Player.inst.currentIndex.valueR;
                                  final nextItem = Player.inst.currentQueue.valueR.length - 1 >= currentIndex + 1
                                      ? Player.inst.currentQueue.valueR[currentIndex + 1] as YoutubeID
                                      : null;
                                  YoutubeInfoController.utils.lazyInfoRefresh.valueR;
                                  final nextItemName = nextItem == null ? '' : YoutubeInfoController.utils.getVideoNameSyncLazy(nextItem.id);
                                  final queueLength = Player.inst.currentQueue.valueR.length;
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      NamidaText(
                                        "${currentIndex + 1}/$queueLength",
                                        style: const NText(.small, weight: FontWeight.w600),
                                      ),
                                      // const SizedBox(height: 2.0),
                                      if (nextItemName != null && nextItemName != '')
                                        NamidaText(
                                          "${lang.next}: $nextItemName",
                                          style: const NText(.small, weight: FontWeight.w500),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 6.0),
                            LongPressDetector(
                              enableSecondaryTap: true,
                              onLongPress: () {
                                final currentItem = Player.inst.currentItem.value;
                                if (currentItem == null) return;
                                showLRCSetDialog(currentItem, CurrentColor.inst.miniplayerColor);
                              },
                              child: _ActionItemAlt(
                                iconSize: 20.0, // not used
                                tooltip: null, // long press above
                                onTap: () {
                                  settings.enableLyrics.save(!settings.enableLyrics.value);
                                  Lyrics.inst.updateLyrics(Player.inst.currentItem.value!);
                                },
                                icon: null,
                                iconWidget: NamidaMiniPlayerBase.getLrcButton(
                                  color: _ActionItemAlt.iconColor,
                                  iconSize: 22.0,
                                ),
                              ),
                            ),
                            _ActionItemAlt(
                              tooltip: lang.newTracksAdd,
                              icon: Broken.add,
                              iconSize: 22.0,
                              onTap: () => TracksAddOnTap().onAddVideosTap(context),
                            ),
                            _ActionItemAlt(
                              tooltip: lang.openQueue,
                              icon: Broken.arrow_up_3,
                              iconSize: 22.0,
                              onTap: _animateSmallToBig,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (widget.overlay != null)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Padding(
                            padding: smallChipMargin,
                            child: SizedBox(
                              height: kQueueBottomRowHeight,
                              width: context.width,
                              child: BorderRadiusClip(
                                borderRadius: BorderRadius.circular(smallChipBorderRadius.multipliedRadius),
                                child: widget.overlay!,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _smallBoxAnimation.value * minHeight),
                    child: child,
                  );
                },
              ),
            );
          },
        ),
        AnimatedBuilder(
          animation: _bigBoxAnimation,
          child: Stack(
            children: [
              NColoredBox(
                color: NColors.custom((colors) => Color.alphaBlend(colors.card.withOpacityExt(0.5), colors.scaffold)),
                child: Listener(
                  onPointerMove: (event) {
                    if (Player.inst.isModifyingQueue) return;
                    if (event.delta.dy > 0) {
                      final queueScrollController = _queueFollower.scrollController;
                      if (queueScrollController.hasClients) {
                        if (queueScrollController.position.pixels <= 0) {
                          _updateCanScrollQueue(false);
                        }
                      }
                    } else {
                      _updateCanScrollQueue(true);
                    }
                  },
                  onPointerDown: (_) {
                    _updateCanScrollQueue(true);
                    YoutubeMiniplayerUiController.inst.cancelDimTimer();
                  },
                  onPointerUp: (_) {
                    _updateCanScrollQueue(true);
                    YoutubeMiniplayerUiController.inst.startDimTimer();
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragUpdate: (event) {
                      if (Player.inst.isModifyingQueue) return;
                      _updateCanScrollQueue(false);
                      _bigBoxDrag = (_bigBoxDrag + event.delta.dy * 0.001).clampDouble(0, 1);
                      if (_bigBoxDrag > 0.0 && _bigBoxDrag < 1.0) {
                        _jump(1 - _bigBoxDrag, _bigBoxDrag);
                      }
                    },
                    onVerticalDragEnd: (d) {
                      _updateCanScrollQueue(true);
                      if (_bigBoxDrag > 0.2 || d.velocity.pixelsPerSecond.dy > 250) {
                        _animateBigToSmall();
                      } else {
                        _animateSmallToBig();
                      }
                      _bigBoxDrag = 0.0;
                    },
                    child: Column(
                      children: [
                        YTQueueChipHeaderRow(
                          onArrowDownPressed: _animateBigToSmall,
                          onSearchTap: _search.toggle,
                        ),
                        QueueSearchBox(
                          search: _search,
                        ),
                        Expanded(
                          child: VideoTilePropertiesProvider(
                            configs: VideoTilePropertiesConfigs(
                              queueSource: QueueSourceYoutubeID.ytPlayerQueue,
                              playlistName: '',
                              openMenuOnLongPress: false,
                              displayTimeAgo: false,
                              draggingEnabled: true,
                              draggableThumbnail: true,
                              showMoreIcon: true,
                              playlistInfo: () => PlaylistBasicInfo(
                                id: '',
                                title: lang.queue,
                                videosCountText: Player.inst.currentQueue.value.length.displayVideoKeyword,
                                videosCount: Player.inst.currentQueue.value.length,
                                thumbnails: [],
                              ),
                            ),
                            builder: (properties) => ObxO(
                              rx: _search.results,
                              builder: (context, results) => Obx(
                                (context) {
                                  final queue = Player.inst.currentQueue.valueR;
                                  final canScroll = _canScrollQueue.valueR;
                                  final onResultTap = results == null ? null : _search.selectResult;
                                  return IgnorePointer(
                                    ignoring: !canScroll,
                                    child: NamidaListView(
                                      listBottomPadding: 0,
                                      scrollController: _queueFollower.scrollController,
                                      itemCount: results?.length ?? queue.length,
                                      itemExtent: Dimensions.youtubeCardItemExtent,
                                      onReorderStart: (index) => Player.inst.invokeQueueModifyLock(),
                                      onReorderEnd: (index) => Player.inst.invokeQueueModifyLockRelease(),
                                      onReorder: results != null ? null : (oldIndex, newIndex) => Player.inst.reorderTrack(oldIndex, newIndex),
                                      onReorderCancel: () => Player.inst.invokeQueueModifyOnModifyCancel(),
                                      physics: canScroll ? const ClampingScrollPhysicsModified() : const NeverScrollableScrollPhysics(),
                                      itemBuilder: (context, i) {
                                        final index = results == null ? i : results[i];
                                        final video = queue[index] as YoutubeID;
                                        final onTap = onResultTap == null ? null : () => onResultTap(index);
                                        return FadeDismissible(
                                          key: Key("Diss_${video.id}_$index"),
                                          onDismissed: (direction) async {
                                            await Player.inst.removeFromQueueWithUndo(index);
                                            Player.inst.invokeQueueModifyLockRelease();
                                          },
                                          onDismissStart: (_) => Player.inst.invokeQueueModifyLock(),
                                          onDismissCancel: (_) => Player.inst.invokeQueueModifyOnModifyCancel(),
                                          child: YTHistoryVideoCard(
                                            key: Key("${index}_${video.id}"),
                                            properties: properties,
                                            videos: queue,
                                            index: index,
                                            day: null,
                                            isImportantInCache: true,
                                            thumbnailHeight: Dimensions.youtubeThumbnailHeight,
                                            preferFetchNewInfo: true,
                                            onTap: onTap,
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        NColoredBox(
                          color: NColors.scaffold,
                          child: SizedBox(
                            width: context.width,
                            height: kQueueBottomRowHeight,
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: QueueUtilsRow(
                                  itemsKeyword: (number) => number.displayVideoKeyword,
                                  onAddItemsTap: () => TracksAddOnTap().onAddVideosTap(context),
                                  scrollQueueWidget: ObxO(
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
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (widget.overlay != null)
                Positioned.fill(
                  child: widget.overlay!,
                ),
            ],
          ),
          builder: (context, child) {
            final p = _bigBoxAnimation.value;
            if (p == 1) return const SizedBox();
            final slowOpacity = ((1 - p) * 1.5 - 0.5).clampDouble(0.0, 1.0);
            return ColoredBox(
              color: Colors.black.withOpacityExt(slowOpacity),
              child: Transform.translate(
                offset: Offset(0, _bigBoxAnimation.value * maxHeight),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24.0.multipliedRadius * p)),
                  ),
                  child: child,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class LocalQueueChipHeaderRow extends StatelessWidget {
  final bool addLeftMargin;
  final bool showPlaybackActions;
  final void Function()? onArrowDownPressed;
  final void Function()? onSearchTap;
  const LocalQueueChipHeaderRow({
    super.key,
    required this.addLeftMargin,
    this.showPlaybackActions = false,
    required this.onArrowDownPressed,
    this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    return QueueChipHeaderRow(
      isLocal: true,
      addLeftMargin: addLeftMargin,
      showPlaybackActions: showPlaybackActions,
      onArrowDownPressed: onArrowDownPressed,
      onSearchTap: onSearchTap,
      durationFormatter: (items) => items.map((e) => e as Selectable).totalDurationFormatted,
    );
  }
}

class YTQueueChipHeaderRow extends StatelessWidget {
  final bool addLeftMargin;
  final bool showPlaybackActions;
  final void Function()? onArrowDownPressed;
  final void Function()? onSearchTap;
  const YTQueueChipHeaderRow({
    super.key,
    this.addLeftMargin = false,
    this.showPlaybackActions = false,
    required this.onArrowDownPressed,
    this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    return QueueChipHeaderRow(
      isLocal: false,
      addLeftMargin: addLeftMargin,
      showPlaybackActions: showPlaybackActions,
      onArrowDownPressed: onArrowDownPressed,
      onSearchTap: onSearchTap,
      durationFormatter: null,
    );
  }
}

class MixedQueueChipHeaderRow extends StatelessWidget {
  final bool addLeftMargin;
  final bool showPlaybackActions;
  final void Function()? onArrowDownPressed;
  final void Function()? onSearchTap;
  const MixedQueueChipHeaderRow({
    super.key,
    this.addLeftMargin = false,
    this.showPlaybackActions = false,
    required this.onArrowDownPressed,
    this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    return QueueChipHeaderRow(
      isLocal: true,
      isMixed: true,
      addLeftMargin: addLeftMargin,
      showPlaybackActions: showPlaybackActions,
      onArrowDownPressed: onArrowDownPressed,
      onSearchTap: onSearchTap,
      durationFormatter: null,
    );
  }
}

class QueueChipHeaderRow extends StatelessWidget {
  final bool isLocal;
  final bool isMixed;
  final bool addLeftMargin;
  final bool showPlaybackActions;
  final void Function()? onArrowDownPressed;
  final void Function()? onSearchTap;
  final String Function(Iterable<Playable> items)? durationFormatter;

  const QueueChipHeaderRow({
    super.key,
    required this.isLocal,
    this.isMixed = false,
    required this.addLeftMargin,
    this.showPlaybackActions = false,
    required this.onArrowDownPressed,
    this.onSearchTap,
    required this.durationFormatter,
  });

  static const minHeight = 42.0;

  void _onConfigureTap() {
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        icon: Broken.setting_3,
        title: lang.configure,
        normalTitleStyle: true,
        trailingWidgets: [
          NamidaIconButton(
            icon: Broken.export_1,
            tooltip: () => lang.playbackSetting,
            iconSize: 20.0,
            onPressed: () {
              SettingsSubPage(
                title: () => lang.playbackSetting,
                child: const PlaybackSettings(),
              ).navigate();
            },
          ),
        ],
        actions: [
          NamidaButton(
            text: lang.done,
            onTap: NamidaNavigator.inst.closeDialog,
          ),
        ],
        child: _QueueConfigureOptions(isLocal: isLocal && !isMixed),
      ),
    );
  }

  static List<Track> _localQueueTracks() => Player.inst.currentQueue.value.whereType<Selectable>().map((e) => e.track).toList();

  static void _addLocalToPlaylist() => showAddToPlaylistDialog(_localQueueTracks());

  static void _addYoutubeToPlaylist() => showAddToPlaylistSheet(
    ids: Player.inst.currentQueue.value.whereType<YoutubeID>().map((e) => e.id),
    idsNamesLookup: const {},
  );

  static void _showMixedAddToPlaylistMenu(BuildContext context) {
    int tracksCount = 0;
    int videosCount = 0;
    for (final item in Player.inst.currentQueue.value) {
      if (item is YoutubeID) {
        videosCount++;
      } else {
        tracksCount++;
      }
    }
    NamidaPopupWrapper(
      childrenDefault: () => [
        NamidaPopupItem(
          icon: Broken.music_circle,
          title: tracksCount.displayTrackKeyword,
          enabled: tracksCount > 0,
          onTap: _addLocalToPlaylist,
        ),
        NamidaPopupItem(
          icon: Broken.video_circle,
          title: videosCount.displayVideoKeyword,
          enabled: videosCount > 0,
          onTap: _addYoutubeToPlaylist,
        ),
      ],
    ).showPopupMenu(context);
  }

  void _onMoreTap() {
    final tracks = _localQueueTracks();
    showGeneralPopupDialog(
      tracks,
      tracks.displayTrackKeyword,
      [
        tracks.totalSizeFormatted,
        tracks.totalDurationFormatted,
      ].join(' • '),
      QueueSource.playerQueue,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = NText.small.of(context).copyWith(fontWeight: FontWeight.w600);
    final playbackActionsIconColor = showPlaybackActions ? CustomIconButtonTonal.iconColor : null;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: 42.0, maxHeight: (context.height * 0.15).withMinimum(42.0)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: LayoutWidthProvider(
          builder: (context, maxWidth) {
            final textMaxWidth = maxWidth * 0.4;
            final iconsMaxWidth = (maxWidth - textMaxWidth);
            return Row(
              children: [
                if (addLeftMargin) const SizedBox(width: 6.0),
                Expanded(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: textMaxWidth),
                    child: FittedBox(
                      alignment: Alignment.centerLeft,
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12.0),
                        child: ObxO(
                          rx: Player.inst.currentIndex,
                          builder: (context, currentIndex) => ObxO(
                            rx: Player.inst.currentQueue,
                            builder: (context, currentQueue) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                NamidaText(
                                  lang.queue,
                                  style: NText.medium,
                                ),

                                if (durationFormatter != null)
                                  Row(
                                    mainAxisSize: .min,
                                    children: [
                                      Text(
                                        "${currentIndex + 1}/${currentQueue.length} •",
                                        style: textStyle,
                                      ),
                                      const SizedBox(width: 4.0),
                                      const Icon(
                                        Broken.timer,
                                        size: 8.0,
                                      ),
                                      const SizedBox(width: 2.0),
                                      Text(
                                        durationFormatter!(currentQueue.skip(currentIndex)),
                                        style: textStyle,
                                      ),
                                    ],
                                  )
                                else
                                  Text(
                                    "${currentIndex + 1}/${currentQueue.length}",
                                    style: textStyle,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: iconsMaxWidth),
                  child: FittedBox(
                    alignment: Alignment.centerRight,
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const SizedBox(width: 6.0),
                          ObxO(
                            rx: PartyController.inst.isActive,
                            builder: (context, isActive) => isActive
                                ? Padding(
                                    padding: const EdgeInsets.only(right: 6.0),
                                    child: _ActionItem(
                                      icon: Broken.people,
                                      tooltip: '${lang.partyListeningParty}: ${PartyController.inst.state.roomName}',
                                      onTap: const NamidaPartyPage().navigate,
                                    ),
                                  )
                                : const SizedBox(),
                          ),
                          if (onSearchTap != null) ...[
                            _ActionItem(
                              icon: Broken.filter_search,
                              tooltip: lang.search,
                              onTap: onSearchTap,
                            ),
                            const SizedBox(width: 6.0),
                          ],
                          if (showPlaybackActions) ...[
                            RepeatModeIconButton(
                              iconSize: _ActionItem.iconSize,
                              color: playbackActionsIconColor,
                              builder: (child, tooltipCallback, onTap) => _ActionItem(
                                tooltip: tooltipCallback?.call(),
                                onTap: onTap,
                                iconWidget: child,
                              ),
                            ),
                            const SizedBox(width: 6.0),
                            SoundControlButton(
                              iconSize: _ActionItem.iconSize,
                              color: playbackActionsIconColor,
                              builder: (child, tooltipCallback, onTap) => _ActionItem(
                                tooltip: tooltipCallback(),
                                onTap: onTap,
                                iconWidget: child,
                              ),
                            ),
                            const SizedBox(width: 6.0),
                            // LongPressDetector(
                            //   enableSecondaryTap: true,
                            //   onLongPress: () {
                            //     final currentItem = Player.inst.currentItem.value;
                            //     if (currentItem == null) return;
                            //     showLRCSetDialog(currentItem, CurrentColor.inst.miniplayerColor);
                            //   },
                            //   child: _ActionItem(
                            //     tooltip: lang.lyrics,
                            //     onTap: () {
                            //       final currentItem = Player.inst.currentItem.value;
                            //       if (currentItem == null) return;
                            //       settings.enableLyrics.save(!settings.enableLyrics.value);
                            //       Lyrics.inst.updateLyrics(currentItem);
                            //     },
                            //     iconWidget: NamidaMiniPlayerBase.getLrcButton(
                            //       theme,
                            //       color: playbackActionsIconColor,
                            //       iconSize: _ActionItem.iconSize,
                            //     ),
                            //   ),
                            // ),
                            // const SizedBox(width: 6.0),
                          ],
                          _ActionItem(
                            icon: Broken.music_playlist,
                            tooltip: lang.addToPlaylist,
                            onTap: () {
                              if (isMixed) {
                                _showMixedAddToPlaylistMenu(context);
                              } else if (isLocal) {
                                _addLocalToPlaylist();
                              } else {
                                _addYoutubeToPlaylist();
                              }
                            },
                          ),
                          const SizedBox(width: 6.0),
                          if (!isLocal || isMixed) ...[
                            _ActionItem(
                              icon: Broken.import,
                              tooltip: lang.download,
                              onTap: () {
                                final ids = Player.inst.currentQueue.value.whereType<YoutubeID>().toList();
                                YTPlaylistDownloadPage(
                                  ids: ids,
                                  playlistName: lang.queue,
                                  infoLookup: const {},
                                  playlistInfo: PlaylistBasicInfo(
                                    id: '',
                                    title: lang.queue,
                                    videosCountText: ids.length.toString(),
                                    videosCount: ids.length,
                                    thumbnails: [],
                                  ),
                                ).navigate();
                              },
                            ),
                            const SizedBox(width: 6.0),
                          ],
                          _ActionItem(
                            icon: Broken.setting_3,
                            tooltip: lang.configure,
                            onTap: () => _onConfigureTap(),
                          ),
                          if (isLocal) ...[
                            const SizedBox(width: 6.0),
                            _ActionItem(
                              icon: Broken.more,
                              tooltip: lang.more,
                              onTap: _onMoreTap,
                            ),
                          ],
                          if (onArrowDownPressed != null) ...[
                            SizedBox(width: isLocal ? 4.0 : 6.0),
                            NamidaIconButton(
                              iconColor: NColors.defaultIcon(opacity: 0.95),
                              icon: Broken.arrow_down_2,
                              onPressed: onArrowDownPressed,
                            ),
                          ],
                        ],
                      ),
                    ),
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

class _ActionItem extends StatelessWidget {
  final String? tooltip;
  final VoidCallback? onTap;
  final IconData? icon;
  final Widget? iconWidget;

  const _ActionItem({
    required this.tooltip,
    this.onTap,
    this.icon,
    this.iconWidget,
  });

  static const iconSize = 20.0;

  @override
  Widget build(BuildContext context) {
    return CustomIconButtonTonal(
      onTap: onTap,
      icon: icon,
      iconWidget: iconWidget,
      iconSize: iconSize,
      tooltip: tooltip,
    );
  }
}

class _ActionItemAlt extends StatelessWidget {
  final String? tooltip;
  final Widget? iconWidget;
  final IconData? icon;
  final double iconSize;
  final void Function() onTap;

  const _ActionItemAlt({
    required this.tooltip,
    this.iconWidget,
    required this.icon,
    required this.iconSize,
    required this.onTap,
  });

  static const iconColor = NColors(.icon, opacity: 0.59);

  @override
  Widget build(BuildContext context) {
    final colors = NColorsData.of(context);
    return IconButton(
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      tooltip: tooltip,
      icon:
          iconWidget ??
          Icon(
            icon,
            size: iconSize,
          ),
      color: iconColor.resolve(colors),
      iconSize: iconSize,
      onPressed: onTap,
    );
  }
}

class _QueueConfigureOptions extends StatelessWidget {
  final bool isLocal;
  const _QueueConfigureOptions({required this.isLocal});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: context.width,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: context.height * 0.6),
        child: SuperSmoothListView(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          children: [
            const SizedBox(height: 8.0),
            if (!isLocal) ...[
              SettingEntryTile(
                entry: YoutubeSettings.autoStartRadio,
              ),
              const NamidaContainerDivider(
                margin: EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
              ),
            ],
            SettingEntryTile(
              entry: PlaybackSettings.autoPlayOnNextPrev,
            ),
            SettingEntryTile(
              entry: PlaybackSettings.infinityQueueOnNextPrev,
            ),
            SettingEntryTile(
              entry: PlaybackSettings.jumpToFirstTrackAfterFinishing,
            ),
            SettingEntryTile(
              entry: PlaybackSettings.previousButtonReplays,
            ),
          ],
        ),
      ),
    );
  }
}
