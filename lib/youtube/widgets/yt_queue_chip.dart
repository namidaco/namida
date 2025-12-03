import 'dart:async';

import 'package:flutter/material.dart';

import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:youtipie/class/youtipie_feed/playlist_basic_info.dart';

import 'package:namida/class/route.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/scroll_physics_modified.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
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
  final void Function(bool isFullyExpanded)? onExpandedStateChange;
  const YTMiniplayerQueueChip({super.key, required this.onExpandedStateChange});

  @override
  State<YTMiniplayerQueueChip> createState() => YTMiniplayerQueueChipState();
}

class YTMiniplayerQueueChipState extends State<YTMiniplayerQueueChip> with TickerProviderStateMixin {
  // -- note: animation values are inversed, as they represent offset percentage.

  late final AnimationController _smallBoxAnimation;

  late final AnimationController _bigBoxAnimation;

  late final _queueScrollController = ScrollController();
  late final _canScrollQueue = true.obs;
  late final _arrowIcon = Broken.cd.obs;

  double _screenHeight = 0;

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

    _queueScrollController.addListener(_updateScrollControllerThingys);
    if (widget.onExpandedStateChange != null) _bigBoxAnimation.addListener(_updateIsFullyOpened);
    Timer(Duration.zero, () {
      _screenHeight = context.height;
      _updateIsFullyOpened();
    });
    super.initState();
  }

  @override
  void dispose() {
    _wasOpened = isOpened;
    _smallBoxAnimation.dispose();
    _bigBoxAnimation.dispose();
    _queueScrollController.dispose();
    _canScrollQueue.close();
    _arrowIcon.close();
    _queueScrollController.removeListener(_updateScrollControllerThingys);
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

  void _updateScrollControllerThingys() {
    if (_queueScrollController.hasClients) {
      final p = _queueScrollController.positions.lastOrNull;
      if (p == null) return;
      // -- icon
      final pixels = p.pixels;
      final sizeInSettings = _itemScrollOffsetInQueue.withMinimum(0);
      if (pixels > sizeInSettings) {
        _arrowIcon.value = Broken.arrow_up_1;
      } else if (pixels < sizeInSettings) {
        _arrowIcon.value = Broken.arrow_down;
      } else if (pixels == sizeInSettings) {
        _arrowIcon.value = Broken.cd;
      }
    }
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
    if (!wasAlreadyBig) WidgetsBinding.instance.addPostFrameCallback((_) => _animateQueueToCurrentTrack());
  }

  void _animateBigToSmall() {
    _animate(0, 1);
    YoutubeMiniplayerUiController.inst.startDimTimer();
    NamidaYTGenerator.inst.cleanResources();
    NamidaNavigator.inst.isQueueSheetOpen = false;
  }

  double get _itemScrollOffsetInQueue => Dimensions.youtubeCardItemExtent * Player.inst.currentIndex.value - _screenHeight * 0.3;

  void _animateQueueToCurrentTrack({bool jump = false, bool minZero = false}) {
    if (_queueScrollController.hasClients) {
      final trackTileItemScrollOffsetInQueue = _itemScrollOffsetInQueue;
      if (_queueScrollController.positions.lastOrNull?.pixels == trackTileItemScrollOffsetInQueue) {
        return;
      }
      final finalOffset = minZero ? trackTileItemScrollOffsetInQueue.withMinimum(0) : trackTileItemScrollOffsetInQueue;
      if (jump) {
        _queueScrollController.jumpTo(finalOffset);
      } else {
        _queueScrollController.animateToEff(
          finalOffset,
          duration: const Duration(milliseconds: 600),
          curve: Curves.fastEaseInToSlowEaseOut,
        );
      }
    }
  }

  double _smallBoxDrag = 1.0;
  double _bigBoxDrag = 0.0;

  void _onConfigureTap() {
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        icon: Broken.setting_3,
        title: lang.CONFIGURE,
        normalTitleStyle: true,
        actions: [
          NamidaButton(
            text: lang.DONE,
            onPressed: NamidaNavigator.inst.closeDialog,
          ),
        ],
        child: const _QueueConfigureOptions(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final maxHeight = context.height;
    const minHeight = kYTQueueSheetMinHeight;

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
            //         child: FloatingActionButton(
            //           heroTag: 'yt_queue_fab_hero',
            //           backgroundColor: theme.colorScheme.secondaryContainer.withValues(alpha: 0.9),
            //           onPressed: () => _animateSmallToBig(),
            //           child: const Icon(
            //             Broken.driver,
            //             color: AppThemes.fabForegroundColor,
            //           ),
            //         ),
            //       )
            //     : null;
            return Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _smallBoxAnimation,
                child: GestureDetector(
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
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: NamidaInkWell(
                      onTap: () => _animateSmallToBig(),
                      margin: EdgeInsets.symmetric(horizontal: 18.0, vertical: 6.0),
                      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
                      height: minHeight,
                      bgColor: Color.alphaBlend(theme.cardColor.withValues(alpha: 0.5), theme.scaffoldBackgroundColor).withValues(alpha: 0.95),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Broken.airdrop,
                            size: 24.0,
                            color: theme.iconTheme.color?.withValues(alpha: 0.65),
                          ),
                          const SizedBox(width: 6.0),
                          Expanded(
                            child: Obx(
                              (context) {
                                final currentIndex = Player.inst.currentIndex.valueR;
                                final nextItem =
                                    Player.inst.currentQueue.valueR.length - 1 >= currentIndex + 1 ? Player.inst.currentQueue.valueR[currentIndex + 1] as YoutubeID : null;
                                final nextItemName = nextItem == null ? '' : YoutubeInfoController.utils.getVideoNameSync(nextItem.id);
                                final queueLength = Player.inst.currentQueue.valueR.length;
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${currentIndex + 1}/$queueLength",
                                      style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                    // const SizedBox(height: 2.0),
                                    if (nextItemName != null && nextItemName != '')
                                      Text(
                                        "${lang.NEXT}: $nextItemName",
                                        style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w500),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 6.0),
                          _ActionItemAlt(
                            tooltip: lang.NEW_TRACKS_ADD,
                            icon: Broken.add,
                            iconSize: 22.0,
                            onTap: () => TracksAddOnTap().onAddVideosTap(context),
                          ),
                          _ActionItemAlt(
                            tooltip: lang.OPEN_QUEUE,
                            icon: Broken.arrow_up_3,
                            iconSize: 22.0,
                            onTap: _animateSmallToBig,
                          ),
                        ],
                      ),
                    ),
                  ),
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
          child: ColoredBox(
            color: Color.alphaBlend(theme.cardColor.withValues(alpha: 0.5), theme.scaffoldBackgroundColor),
            child: Listener(
              onPointerMove: (event) {
                if (Player.inst.isModifyingQueue) return;
                if (event.delta.dy > 0) {
                  if (_queueScrollController.hasClients) {
                    if (_queueScrollController.position.pixels <= 0) {
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
                    ConstrainedBox(
                      constraints: BoxConstraints(minHeight: 42.0, maxHeight: (context.height * 0.15).withMinimum(42.0)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: LayoutWidthProvider(
                          builder: (context, maxWidth) {
                            final textMaxWidth = maxWidth * 0.4;
                            final iconsMaxWidth = (maxWidth - textMaxWidth);
                            return Row(
                              children: [
                                Expanded(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(maxWidth: textMaxWidth),
                                    child: FittedBox(
                                      alignment: Alignment.centerLeft,
                                      fit: BoxFit.scaleDown,
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 12.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              lang.QUEUE,
                                              style: textTheme.displayMedium,
                                            ),
                                            Obx(
                                              (context) => Text(
                                                "${Player.inst.currentIndex.valueR + 1}/${Player.inst.currentQueue.valueR.length}",
                                                style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                          ],
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
                                          _ActionItem(
                                            icon: Broken.music_playlist,
                                            tooltip: lang.ADD_TO_PLAYLIST,
                                            onTap: () {
                                              showAddToPlaylistSheet(
                                                ids: Player.inst.currentQueue.value.whereType<YoutubeID>().map((e) => e.id),
                                                idsNamesLookup: const {},
                                              );
                                            },
                                          ),
                                          const SizedBox(width: 6.0),
                                          _ActionItem(
                                            icon: Broken.import,
                                            tooltip: lang.DOWNLOAD,
                                            onTap: () {
                                              YTPlaylistDownloadPage(
                                                ids: Player.inst.currentQueue.value.whereType<YoutubeID>().toList(),
                                                playlistName: lang.QUEUE,
                                                infoLookup: const {},
                                                playlistInfo: PlaylistBasicInfo(
                                                  id: '',
                                                  title: lang.QUEUE,
                                                  videosCountText: Player.inst.currentQueue.value.length.toString(),
                                                  videosCount: Player.inst.currentQueue.value.length,
                                                  thumbnails: [],
                                                ),
                                              ).navigate();
                                            },
                                          ),
                                          const SizedBox(width: 6.0),
                                          _ActionItem(
                                            icon: Broken.setting_3,
                                            tooltip: lang.CONFIGURE,
                                            onTap: () => _onConfigureTap(),
                                          ),
                                          const SizedBox(width: 4.0),
                                          NamidaIconButton(
                                            iconColor: context.defaultIconColor().withValues(alpha: 0.95),
                                            icon: Broken.arrow_down_2,
                                            onPressed: () => _animateBigToSmall(),
                                          ),
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
                    ),
                    Expanded(
                      child: VideoTilePropertiesProvider(
                        configs: VideoTilePropertiesConfigs(
                          queueSource: QueueSourceYoutubeID.playerQueue,
                          playlistName: '',
                          openMenuOnLongPress: false,
                          displayTimeAgo: false,
                          draggingEnabled: true,
                          draggableThumbnail: true,
                          showMoreIcon: true,
                          playlistInfo: () => PlaylistBasicInfo(
                            id: '',
                            title: lang.QUEUE,
                            videosCountText: Player.inst.currentQueue.value.length.displayVideoKeyword,
                            videosCount: Player.inst.currentQueue.value.length,
                            thumbnails: [],
                          ),
                        ),
                        builder: (properties) => Obx(
                          (context) {
                            final queue = Player.inst.currentQueue.valueR;
                            final canScroll = _canScrollQueue.valueR;
                            return IgnorePointer(
                              ignoring: !canScroll,
                              child: NamidaListView(
                                listBottomPadding: 0,
                                scrollController: _queueScrollController,
                                itemCount: queue.length,
                                itemExtent: Dimensions.youtubeCardItemExtent,
                                onReorderStart: (index) => Player.inst.invokeQueueModifyLock(),
                                onReorderEnd: (index) => Player.inst.invokeQueueModifyLockRelease(),
                                onReorder: (oldIndex, newIndex) => Player.inst.reorderTrack(oldIndex, newIndex),
                                onReorderCancel: () => Player.inst.invokeQueueModifyOnModifyCancel(),
                                physics: canScroll ? const ClampingScrollPhysicsModified() : const NeverScrollableScrollPhysics(),
                                itemBuilder: (context, i) {
                                  final video = queue[i] as YoutubeID;
                                  return FadeDismissible(
                                    key: Key("Diss_${video.id}_$i"),
                                    onDismissed: (direction) async {
                                      await Player.inst.removeFromQueueWithUndo(i);
                                      Player.inst.invokeQueueModifyLockRelease();
                                    },
                                    onDismissStart: (_) => Player.inst.invokeQueueModifyLock(),
                                    onDismissCancel: (_) => Player.inst.invokeQueueModifyOnModifyCancel(),
                                    child: YTHistoryVideoCard(
                                      key: Key("${i}_${video.id}"),
                                      properties: properties,
                                      videos: queue,
                                      index: i,
                                      day: null,
                                      isImportantInCache: true,
                                      thumbnailHeight: Dimensions.youtubeThumbnailHeight,
                                      preferFetchNewInfo: true,
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    ColoredBox(
                      color: theme.scaffoldBackgroundColor,
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
                              scrollQueueWidget: (buttonStyle) => ObxO(
                                rx: _arrowIcon,
                                builder: (context, arrowIcon) => NamidaButton(
                                  style: buttonStyle,
                                  onPressed: _animateQueueToCurrentTrack,
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
          builder: (context, child) {
            final p = _bigBoxAnimation.value;
            if (p == 1) return const SizedBox();
            final slowOpacity = ((1 - p) * 1.5 - 0.5).clampDouble(0.0, 1.0);
            return ColoredBox(
              color: Colors.black.withValues(alpha: slowOpacity),
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

class _ActionItem extends StatelessWidget {
  final String tooltip;
  final VoidCallback? onTap;
  final IconData icon;

  const _ActionItem({
    required this.tooltip,
    this.onTap,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return IconButton.filledTonal(
      padding: EdgeInsets.zero,
      style: ButtonStyle(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: const VisualDensity(horizontal: -2.0, vertical: -2.0),
        backgroundColor: WidgetStatePropertyAll(theme.colorScheme.secondary.withValues(alpha: 0.18)),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 20.0),
      tooltip: tooltip,
    );
  }
}

class _ActionItemAlt extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final double iconSize;
  final void Function() onTap;

  const _ActionItemAlt({
    required this.tooltip,
    required this.icon,
    required this.iconSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      tooltip: tooltip,
      icon: Icon(
        icon,
        size: iconSize,
      ),
      color: context.theme.iconTheme.color?.withAlpha(150),
      iconSize: iconSize,
      onPressed: onTap,
    );
  }
}

class _QueueConfigureOptions extends StatelessWidget {
  const _QueueConfigureOptions();

  @override
  Widget build(BuildContext context) {
    final ytSettings = YoutubeSettings();

    return SizedBox(
      width: context.width,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: context.height * 0.6),
        child: SuperListView(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          children: [
            ytSettings.getAutoStartRadioWidget(),
          ],
        ),
      ),
    );
  }
}
