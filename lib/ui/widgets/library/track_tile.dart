import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:namida/class/jump_highlight.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/selected_tracks_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/time_ago_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/ntheme.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/dialogs/track_info_dialog.dart';
import 'package:namida/ui/widgets/animated_widgets.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/server_cache_widgets.dart';

class TrackTilePropertiesProvider extends StatelessWidget {
  final TrackTilePropertiesConfigs configs;
  final Widget Function(TrackTileProperties properties) builder;

  const TrackTilePropertiesProvider({
    super.key,
    required this.builder,
    required this.configs,
  });

  @override
  Widget build(BuildContext context) {
    final queueSource = configs.queueSource;
    final comingFromQueue = queueSource == QueueSource.playerQueue;
    final canHaveDuplicates = queueSource.canHaveDuplicates;

    final listenToTopHistoryItems = settings.trackItem.value.values.any(
      (element) => element == TrackTileItem.listenCount || element == TrackTileItem.latestListenDate || element == TrackTileItem.firstListenDate,
    );

    final listenToStatsMap = settings.trackItem.value.values.any(
      (element) => element == TrackTileItem.rating || element == TrackTileItem.moods || element == TrackTileItem.tags,
    );

    return ObxO(
      rx: settings.forceSquaredTrackThumbnail,
      builder: (context, forceSquaredThumbnails) => ObxO(
        rx: settings.displayThirdRow,
        builder: (context, displayThirdRow) => ObxO(
          rx: settings.displayFavouriteIconInListTile,
          builder: (context, displayFavouriteIconInListTile) => ObxO(
            rx: settings.trackThumbnailSizeinList,
            builder: (context, thumbnailSize) => ObxO(
              rx: settings.onTrackSwipeLeft,
              builder: (context, onTrackSwipeLeft) => ObxO(
                rx: settings.onTrackSwipeRight,
                builder: (context, onTrackSwipeRight) => ObxO(
                  rx: settings.thumbnailTapAction,
                  builder: (context, thumbnailTapAction) => ObxO(
                    rx: settings.thumbnailLongPressAction,
                    builder: (context, thumbnailLongPressAction) => ObxO(
                      rx: settings.trackListTileHeight,
                      builder: (context, trackTileHeight) => ObxO(
                        rx: Indexer.inst.tracksInfoList,
                        builder: (context, _) => ObxPrefer(
                          enabled: listenToStatsMap,
                          rx: Indexer.inst.trackStatsMap,
                          builder: (context, trackStatsMap) => ObxO(
                            rx: SelectedTracksController.inst.existingTracksMap,
                            builder: (context, selectedTracksMap) => ObxPrefer(
                              rx: HistoryController.inst.topTracksMapListens,
                              enabled: listenToTopHistoryItems,
                              builder: (context, _) => ObxOSelect(
                                rx: JumpHighlight.briefTarget,
                                selector: (briefHighlight) => briefHighlight?.inQueue == comingFromQueue ? briefHighlight : null,
                                builder: (context, briefHighlight) {
                                  final properties = TrackTileProperties(
                                    thumbnailSize: thumbnailSize,
                                    trackTileHeight: trackTileHeight,
                                    forceSquaredThumbnails: forceSquaredThumbnails,
                                    displayThirdRow: displayThirdRow,
                                    displayFavouriteIconInListTile: displayFavouriteIconInListTile,
                                    comingFromQueue: comingFromQueue,
                                    configs: configs,
                                    canHaveDuplicates: canHaveDuplicates,
                                    isTrackSelected: (trOrTwd) => selectedTracksMap[trOrTwd.track] != null,
                                    allowSwipeLeft: !comingFromQueue && onTrackSwipeLeft != TrackExecuteActions.none,
                                    allowSwipeRight: !comingFromQueue && onTrackSwipeRight != TrackExecuteActions.none,
                                    thumbnailTapAction: thumbnailTapAction,
                                    thumbnailLongPressAction: thumbnailLongPressAction,
                                    briefHighlight: briefHighlight,
                                  );
                                  return builder(properties);
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TrackTilePropertiesConfigs {
  final QueueSourceBase queueSource;

  /// Disable if you want to have priority to hold & reorder instead of selecting.
  final bool Function()? selectable;
  final bool draggableThumbnail;
  final bool displayRightDragHandler;
  final bool displayTrackNumber;
  final bool fallbackToAlbumCover;
  final bool horizontalGestures;
  final String? playlistName;
  final Rx<bool>? reorderableRx;

  /// for ranged selection when the list isn't the current route's, ex: inside dialogs.
  final List<Selectable>? rangeSelectionTracks;

  const TrackTilePropertiesConfigs({
    required this.queueSource,
    this.selectable,
    this.draggableThumbnail = false,
    this.displayRightDragHandler = false,
    this.displayTrackNumber = false,
    this.fallbackToAlbumCover = false,
    this.horizontalGestures = true,
    this.playlistName,
    this.reorderableRx,
    this.rangeSelectionTracks,
  });
}

class TrackTileProperties {
  final TrackTilePropertiesConfigs configs;

  final double thumbnailSize;
  final double trackTileHeight;
  final bool forceSquaredThumbnails;
  final bool displayThirdRow;
  final bool displayFavouriteIconInListTile;
  final bool comingFromQueue;
  final bool canHaveDuplicates;
  final bool Function(Selectable trOrTwd) isTrackSelected;

  final bool allowSwipeLeft;
  final bool allowSwipeRight;
  final TrackExecuteActions thumbnailTapAction;
  final TrackExecuteActions thumbnailLongPressAction;
  final JumpHighlightTarget? briefHighlight;

  const TrackTileProperties({
    required this.configs,
    required this.thumbnailSize,
    required this.trackTileHeight,
    required this.forceSquaredThumbnails,
    required this.displayThirdRow,
    required this.displayFavouriteIconInListTile,
    required this.comingFromQueue,
    required this.canHaveDuplicates,
    required this.isTrackSelected,
    required this.allowSwipeLeft,
    required this.allowSwipeRight,
    required this.thumbnailTapAction,
    required this.thumbnailLongPressAction,
    required this.briefHighlight,
  });
}

class TrackTile extends StatelessWidget {
  static const _thumbnailLeftPadding = 12.0;

  final int index;
  final Selectable trackOrTwd;
  final List<Playable> tracks;
  final TrackTileProperties properties;
  final HomePageItems? homePageItem;
  final VoidCallback? onTap;
  final VoidCallback? onPlaying;

  final NColors? bgColor;
  final bool isJumpHighlighted;
  final double cardColorOpacity;
  final double fadeOpacity;
  final void Function()? onRightAreaTap;
  final Widget? trailingWidget;
  final Widget? topRightWidget;
  final String? thirdLineText;

  const TrackTile({
    super.key,
    required this.properties,
    this.homePageItem,
    required this.trackOrTwd,
    required this.tracks,
    this.onTap,
    this.onPlaying,
    required this.index,
    this.bgColor,
    this.isJumpHighlighted = false,
    this.cardColorOpacity = 0.9,
    this.fadeOpacity = 0.0,
    this.onRightAreaTap,
    this.trailingWidget,
    this.topRightWidget,
    this.thirdLineText,
  });

  static String obtainHeroTag(TrackWithDate? trackWithDate, Track track, int index, bool isFromPlayerQueue) {
    final additionalHero = trackWithDate?.dateAdded.toString() ?? '';
    return '$isFromPlayerQueue${index}_sussydialogs_${track.path}$additionalHero';
  }

  Track get _tr => trackOrTwd.track;
  TrackWithDate? get _twd => trackOrTwd.trackWithDate;
  String get _heroTag => obtainHeroTag(_twd, _tr, index, properties.comingFromQueue);

  void _triggerTrackDialog() => NamidaDialogs.inst.showTrackDialog(
    _tr,
    playlistName: properties.configs.playlistName,
    index: index,
    trackWithDate: trackOrTwd.trackWithDate,
    source: properties.configs.queueSource,
    heroTag: _heroTag,
  );

  void _triggerTrackInfoDialog() => showTrackInfoDialog(
    _tr,
    true,
    heroTag: _heroTag,
  );

  void _selectTrack({required bool ranged}) =>
      SelectedTracksController.inst.selectOrUnselect(
        trackOrTwd,
        index,
        properties.configs.queueSource,
        properties.configs.playlistName,
        ranged: ranged,
        tracksOverride: properties.configs.rangeSelectionTracks,
      );

  bool _trySelectOnTap() {
    if (properties.configs.queueSource == QueueSource.selectedTracks) return false;

    bool shouldSelect = false;
    bool shouldSelectRanged = false;
    if (isDesktop) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        shouldSelect = true;
        shouldSelectRanged = true;
      } else if (HardwareKeyboard.instance.isControlPressed) {
        shouldSelect = true;
      } else if (SelectedTracksController.inst.selectedTracks.value.isNotEmpty) {
        shouldSelect = true;
      }
    } else {
      if (SelectedTracksController.inst.selectedTracks.value.isNotEmpty) {
        shouldSelect = true;
      }
    }

    if (shouldSelect) _selectTrack(ranged: shouldSelectRanged);
    return shouldSelect;
  }

  void _executeThumbnailAction(TrackExecuteActions action) => action.execute(
    trackOrTwd,
    info: SwipeQueueAddTileInfo(
      queueSource: properties.configs.queueSource,
      heroTag: _heroTag,
      queue: tracks,
      index: index,
    ),
  );

  void _onThumbnailTap(TrackExecuteActions action) {
    if (_trySelectOnTap()) return;
    _executeThumbnailAction(action);
  }

  _TrackTilePlayState _selectPlayState() {
    final queueSource = properties.configs.queueSource;
    final currentPlayingTrack = CurrentColor.inst.currentPlayingTrack.valueR;
    final isTrackSame = _tr == currentPlayingTrack?.track;
    final isRightHistoryList = queueSource == QueueSource.history ? _twd == currentPlayingTrack?.trackWithDate : true;
    final isRightIndex = properties.canHaveDuplicates ? index == CurrentColor.inst.currentPlayingIndex.valueR : true;
    final isPlaying = isRightIndex && isTrackSame && isRightHistoryList;

    var isHighlighted = false;
    if (queueSource.supportResuming) {
      final highlighted = QueueController.latestPlayedForSourceManager.map.valueR[queueSource];
      if (highlighted is Selectable) isHighlighted = _twd == highlighted.trackWithDate || _tr == highlighted.track;
    }

    var willSleep = false;
    if (properties.comingFromQueue) {
      final sleepconfig = Player.inst.sleepTimerConfig.valueR;
      if (sleepconfig.enableSleepAfterItems) {
        final repeatMode = settings.player.repeatMode.valueR;
        if (repeatMode == PlayerRepeatMode.all || repeatMode == PlayerRepeatMode.none) {
          willSleep = Player.inst.sleepingItemIndex(sleepconfig.sleepAfterItems, Player.inst.currentIndex.valueR) == index;
        }
      }
    }
    return (isPlaying: isPlaying, isHighlighted: isHighlighted, willSleep: willSleep);
  }

  @override
  Widget build(BuildContext context) {
    return ObxSelect(
      selector: _selectPlayState,
      builder: (context, playState) {
        final queueSource = properties.configs.queueSource;
        final track = _tr;
        final isInSelectedTracksPreview = queueSource == QueueSource.selectedTracks;

        final willSleepAfterThis = playState.willSleep;

        final bool isTrackSelected = properties.isTrackSelected(trackOrTwd);
        final bool isTrackCurrentlyPlaying = playState.isPlaying;
        final bool isTrackHighlighted = playState.isHighlighted;

        final textColor = isTrackCurrentlyPlaying && !isTrackSelected ? Colors.white : null;

        final briefHighlight = properties.briefHighlight;
        final isBriefHighlighted = briefHighlight != null && index == briefHighlight.index && trackOrTwd == briefHighlight.item;

        final background = _TrackTileBackgroundState(
          bgColor: bgColor,
          isPlaying: isTrackCurrentlyPlaying,
          hasSelectionLayer: isTrackSelected && queueSource != QueueSource.selectedTracks,
          hasHighlightLayer: !isTrackCurrentlyPlaying && isTrackHighlighted && queueSource.supportResuming,
          hasJumpHighlightLayer: isJumpHighlighted || isBriefHighlighted,
          comingFromQueue: properties.comingFromQueue,
          cardColorOpacity: cardColorOpacity,
        );

        Widget threeLinesColumn;
        if (trackOrTwd.track.toTrackExtOrNull() == null) {
          threeLinesColumn = NamidaText(
            trackOrTwd.track.path,
            style: NText.small,
            color: NColors.fixed(textColor?.withOpacityExt(0.67)),
          );
        } else {
          final thirdLineText = this.thirdLineText;
          final row1Text = TrackTileManager._joinTrackItems(_TrackTileRowOrder.first, track);
          final row2Text = TrackTileManager._joinTrackItems(_TrackTileRowOrder.second, track);
          final row3Text = thirdLineText != null && thirdLineText.isNotEmpty
              ? thirdLineText
              : properties.displayThirdRow
              ? TrackTileManager._joinTrackItems(_TrackTileRowOrder.third, track)
              : '';

          threeLinesColumn = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (row1Text.isNotEmpty)
                NamidaText(
                  row1Text,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: NText.medium,
                  color: NColors.fixed(textColor?.withOpacityExt(0.67)),
                ),

              // -- add small spacing if there is no third row
              if (row3Text.isEmpty) const SizedBox(height: 1.0),

              if (row2Text.isNotEmpty)
                NamidaText(
                  row2Text,
                  style: const NText(.small, weight: FontWeight.w500),
                  color: NColors.fixed(textColor?.withOpacityExt(0.55)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

              if (row3Text.isNotEmpty)
                NamidaText(
                  row3Text,
                  style: NText.small,
                  color: NColors.fixed(textColor?.withOpacityExt(0.51)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          );
        }
        final rightItem1Text = TrackTileManager._joinTrackItems(_TrackTileRowOrder.right1, track);
        final rightItem2Text = TrackTileManager._joinTrackItems(_TrackTileRowOrder.right2, track);

        final heroTag = this._heroTag;

        final topRightWidget = this.topRightWidget;
        final videoIcon = track is Video
            ? Icon(
                Broken.video,
                size: 12.0,
                color: textColor?.withOpacityExt(0.39) ?? NText.small.of(context).color?.withOpacityExt(0.39),
              )
            : null;

        Widget? draggingTileWidget;
        if (properties.configs.draggableThumbnail) {
          final listener = NamidaReordererableListener(
            durationMs: 80,
            index: index,
            child: const ColoredBox(color: Colors.transparent),
          );
          final reorderableRx = properties.configs.reorderableRx;
          draggingTileWidget = Positioned(
            left: 0.0,
            top: 0.0,
            bottom: 0.0,
            width: _thumbnailLeftPadding + properties.thumbnailSize,
            child: reorderableRx != null
                ? ObxO(
                    rx: reorderableRx,
                    builder: (context, reorderable) => reorderable ? listener : const SizedBox(),
                  )
                : listener,
          );
        }

        Widget thumbnail = AnimatedScale(
          duration: const Duration(milliseconds: 400),
          scale: isTrackCurrentlyPlaying ? 0.96 : 1.0,
          curve: Curves.easeInOut,
          child: SizedBox(
            width: properties.thumbnailSize,
            height: properties.thumbnailSize,
            child: NamidaHero(
              tag: heroTag,
              child: ArtworkWidget(
                key: Key("$willSleepAfterThis${trackOrTwd.hashCode}"),
                track: track,
                thumbnailSize: properties.thumbnailSize,
                path: track.pathToImage,
                forceSquared: properties.forceSquaredThumbnails,
                fallbackToAlbumCover: properties.configs.fallbackToAlbumCover,
                icon: track is Video ? Broken.video : Broken.musicnote,
                iconSize: (properties.trackTileHeight.withMaximum(properties.thumbnailSize)) * 0.5,
                onTopWidgets: [
                  if (track.isNetwork)
                    Positioned.fill(
                      child: ServerCacheTrackIndicator(
                        track: track,
                      ),
                    ),
                  if (properties.configs.displayTrackNumber)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: NamidaBlurryContainer(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
                        borderRadius: BorderRadius.only(topLeft: Radius.circular(4.0.multipliedRadius)),
                        child: NamidaText(
                          track.trackNo.toString(),
                          style: NText.small,
                        ),
                      ),
                    ),
                  if (willSleepAfterThis)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: NDecoratedBox(
                        decoration: (colors) => BoxDecoration(
                          color: colors.surface.withOpacityExt(0.63),
                          borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(3.0),
                          child: Icon(
                            Broken.timer_1,
                            size: 15.0,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
        if (onTap == null) {
          final thumbnailTapAction = properties.thumbnailTapAction;
          final thumbnailLongPressAction = properties.thumbnailLongPressAction;
          final hasThumbnailTap = thumbnailTapAction != TrackExecuteActions.none;
          final hasThumbnailLongPress = thumbnailLongPressAction != TrackExecuteActions.none;
          if (hasThumbnailTap || hasThumbnailLongPress) {
            thumbnail = GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: hasThumbnailTap ? () => _onThumbnailTap(thumbnailTapAction) : null,
              onLongPress: hasThumbnailLongPress ? () => _executeThumbnailAction(thumbnailLongPressAction) : null,
              child: thumbnail,
            );
          }
        }

        Widget finalChild = Stack(
          alignment: Alignment.centerRight,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: Dimensions.tileBottomMargin),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap:
                      onTap ??
                      () async {
                        if (_trySelectOnTap()) return;

                        if (onPlaying != null) {
                          onPlaying!();
                          return;
                        }
                        if (queueSource.s == QueueSourceEnum.search) {
                          ScrollSearchController.inst.unfocusKeyboard();
                          final playMode = settings.trackPlayMode.value;
                          await Player.inst.playOrPause(
                            playMode.shouldBeIndex0 ? 0 : index,
                            playMode.generateQueue(track),
                            queueSource,
                            homePageItem: homePageItem,
                            gentlePlay: playMode.gentlePlay,
                            maximumItems: null,
                          );
                        } else {
                          final queueSourceNormalized = queueSource.s == QueueSourceEnum.allTracks ? QueueSource.allTracksAll : queueSource;
                          await Player.inst.playOrPause(
                            index,
                            tracks,
                            queueSourceNormalized,
                            homePageItem: homePageItem,
                            maximumItems: null,
                          );
                        }
                      },
                  onLongPress: onTap != null
                      ? null
                      : () {
                          var selectable = properties.configs.selectable;
                          if (selectable != null && selectable() == false) return;
                          if (isInSelectedTracksPreview) return;

                          ScrollSearchController.inst.unfocusKeyboard();
                          _selectTrack(ranged: true);
                        },
                  onSecondaryTap: _triggerTrackDialog,
                  child: _TrackTileBackground(
                    state: background,
                    child: SizedBox(
                      height: Dimensions.inst.trackTileItemExtent,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: Dimensions.tileVerticalPadding),
                        child: Row(
                          children: [
                            const SizedBox(width: _thumbnailLeftPadding),
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                thumbnail,
                              ],
                            ),
                            const SizedBox(width: 12.0),
                            Expanded(
                              child: threeLinesColumn,
                            ),
                            const SizedBox(width: 6.0),
                            if (properties.displayFavouriteIconInListTile || rightItem1Text.isNotEmpty || rightItem2Text.isNotEmpty)
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (rightItem1Text.isNotEmpty)
                                    NamidaText(
                                      rightItem1Text,
                                      style: const NText(.small, weight: FontWeight.w500),
                                      color: NColors.fixed(textColor?.withOpacityExt(0.67)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  if (rightItem2Text.isNotEmpty)
                                    NamidaText(
                                      rightItem2Text,
                                      style: const NText(.small, weight: FontWeight.w500),
                                      color: NColors.fixed(textColor?.withOpacityExt(0.67)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  if (properties.displayFavouriteIconInListTile)
                                    _TrackTileLikeButton(
                                      track: track,
                                      isPlaying: isTrackCurrentlyPlaying,
                                      textColor: textColor,
                                    ),
                                ],
                              ),
                            if (properties.configs.displayRightDragHandler) ...[
                              const SizedBox(width: 8.0),
                              NamidaReordererableListener(
                                durationMs: 40,
                                index: index,
                                child: FittedBox(
                                  child: Icon(
                                    Broken.menu_1,
                                    color: textColor?.withOpacityExt(0.63),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 2.0),
                            MoreIcon(
                              padding: 6.0,
                              iconColor: textColor?.withOpacityExt(0.63),
                              onPressed: _triggerTrackDialog,
                              onLongPress: _triggerTrackInfoDialog,
                            ),
                            if (trailingWidget == null)
                              const SizedBox(width: 4.0)
                            else ...[
                              trailingWidget!,
                              const SizedBox(width: 10.0),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ?draggingTileWidget,
            if (fadeOpacity > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: NColoredBox(
                    color: NColors(.scaffold, opacity: fadeOpacity),
                  ),
                ),
              ),
            GestureDetector(
              onTap: onRightAreaTap ?? _triggerTrackDialog,
              onLongPress: _triggerTrackInfoDialog,
              onSecondaryTap: _triggerTrackInfoDialog,
              child: Container(
                width: 36.0,
                color: Colors.transparent,
              ),
            ),
            if (videoIcon != null && topRightWidget != null)
              Positioned(
                top: 0.0,
                right: 0.0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    videoIcon,
                    const SizedBox(width: 2.0),
                    topRightWidget,
                  ],
                ),
              )
            else if (videoIcon != null)
              Positioned(
                top: 6.0,
                right: 6.0,
                child: videoIcon,
              )
            else if (topRightWidget != null)
              Positioned(
                top: 0.0,
                right: 0.0,
                child: topRightWidget,
              ),
          ],
        );

        if (properties.configs.horizontalGestures && (properties.allowSwipeLeft || properties.allowSwipeRight)) {
          finalChild = SwipeQueueAddTile(
            item: trackOrTwd,
            infoCallback: () => SwipeQueueAddTileInfo(
              queueSource: queueSource,
              heroTag: heroTag,
              queue: tracks,
              index: index,
            ),
            dismissibleKey: heroTag,
            allowSwipeLeft: properties.allowSwipeLeft,
            allowSwipeRight: properties.allowSwipeRight,
            disabledRx: properties.configs.reorderableRx,
            child: finalChild,
          );
        }
        return finalChild;
      },
    );
  }
}

enum _TrackTileRowOrder {
  first,
  second,
  third,

  right1,
  right2,
}

class TrackTileManager {
  const TrackTileManager._();

  static void initialize() {
    settings.trackItem.addListener(onTrackItemPropChange);
    settings.displayThirdItemInEachRow.addListener(onTrackItemPropChange);
    settings.trackTileSeparator.addListener(onTrackItemPropChange);
    settings.trackArtistsDisplaySeparator.addListener(onTrackItemPropChange);
    settings.dateTimeFormat.addListener(onTrackItemPropChange);
    settings.hourFormat12.addListener(onTrackItemPropChange);
  }

  static const _rowOrderToPosition = <_TrackTileRowOrder, List<TrackTilePosition>>{
    _TrackTileRowOrder.first: [TrackTilePosition.row1Item1, TrackTilePosition.row1Item2, TrackTilePosition.row1Item3],
    _TrackTileRowOrder.second: [TrackTilePosition.row2Item1, TrackTilePosition.row2Item2, TrackTilePosition.row2Item3],
    _TrackTileRowOrder.third: [TrackTilePosition.row3Item1, TrackTilePosition.row3Item2, TrackTilePosition.row3Item3],
    _TrackTileRowOrder.right1: [TrackTilePosition.rightItem1],
    _TrackTileRowOrder.right2: [TrackTilePosition.rightItem2],
  };
  static const _rowOrderToPositionWithoutThird = <_TrackTileRowOrder, List<TrackTilePosition>>{
    _TrackTileRowOrder.first: [TrackTilePosition.row1Item1, TrackTilePosition.row1Item2],
    _TrackTileRowOrder.second: [TrackTilePosition.row2Item1, TrackTilePosition.row2Item2],
    _TrackTileRowOrder.third: [TrackTilePosition.row3Item1, TrackTilePosition.row3Item2],
    _TrackTileRowOrder.right1: [TrackTilePosition.rightItem1],
    _TrackTileRowOrder.right2: [TrackTilePosition.rightItem2],
  };

  static final _infoFullMap = <Track, Map<_TrackTileRowOrder, String>?>{};

  static void onTrackItemPropChange() {
    _infoFullMap.clear();
    _separator = _buildSeparator();
  }

  static void rebuildTrackInfo(Track track) {
    _infoFullMap[track] = null;
  }

  static String _separator = _buildSeparator();
  static String _buildSeparator() => ' ${settings.trackTileSeparator.value} ';
  static final _buffer = StringBuffer(); // clearing and reusing is more performant

  static String _joinTrackItems(
    _TrackTileRowOrder rowOrder,
    Track track,
  ) {
    final row = _infoFullMap[track]?[rowOrder];
    if (row != null) return row;

    final positions = settings.displayThirdItemInEachRow.value ? _rowOrderToPosition[rowOrder] : _rowOrderToPositionWithoutThird[rowOrder];
    final newRowDetails = _joinTrackItemsInternal(positions!, track);
    final newRow = newRowDetails.text;

    if (newRowDetails.shouldNotCache) return newRow;

    final innerMap = _infoFullMap[track] ??= {};
    innerMap[rowOrder] = newRow;

    return newRow;
  }

  static ({String text, bool shouldNotCache}) _joinTrackItemsInternal(List<TrackTilePosition> positions, Track track) {
    _buffer.clear();

    bool needsSeparator = false;
    bool shouldNotCache = false;
    final trExt = track.toTrackExt();

    for (final itemPosition in positions) {
      final trackItem = settings.trackItem.value[itemPosition];
      if (trackItem == TrackTileItem.latestListenDate || trackItem == TrackTileItem.listenCount) shouldNotCache = true;

      var info = _buildChoosenTrackTileItem(trackItem, trExt, track);

      if (info.isNotEmpty) {
        if (needsSeparator) _buffer.write(_separator);
        _buffer.write(info);
        needsSeparator = true;
      }
    }

    return (text: _buffer.toString(), shouldNotCache: shouldNotCache);
  }

  static String buildItem(TrackTileItem trackItem, Track track) => _buildChoosenTrackTileItem(trackItem, track.toTrackExt(), track);

  static String _buildChoosenTrackTileItem(TrackTileItem? trackItem, TrackExtended trExt, Track track) {
    if (trackItem == null || trackItem == TrackTileItem.none) return '';

    final fn = _lookup[trackItem];
    if (fn != null) return fn(trExt, track);

    return '';
  }

  static final _lookup = <TrackTileItem, String Function(TrackExtended track, Track rawTrack)>{
    TrackTileItem.title: (track, _) => track.title,
    TrackTileItem.artists: (track, _) => track.displayArtist(),
    TrackTileItem.album: (track, _) => track.originalAlbum,
    TrackTileItem.albumArtist: (track, _) => track.albumArtist,
    TrackTileItem.genres: (track, _) => track.originalGenre,
    TrackTileItem.styles: (track, _) => track.originalStyle,
    TrackTileItem.languages: (track, _) => track.languagesList.join(', '),
    TrackTileItem.duration: (track, _) => track.durationMS.milliSecondsLabel,
    TrackTileItem.year: (track, _) => track.year.yearFormatted,
    TrackTileItem.trackNumber: (track, _) => track.trackNo.toString(),
    TrackTileItem.discNumber: (track, _) => track.discNo.toString(),
    TrackTileItem.fileNameWOExt: (track, _) => track.filenameWOExt,
    TrackTileItem.extension: (track, _) => track.extension,
    TrackTileItem.fileName: (track, _) => track.filename,
    TrackTileItem.folder: (track, _) => track.folderName,
    TrackTileItem.path: (track, _) => track.path.formatPath(),
    TrackTileItem.channels: (track, _) => track.channels.channelToLabel,
    TrackTileItem.comment: (track, _) => track.comment,
    TrackTileItem.composer: (track, _) => track.composer,
    TrackTileItem.dateAdded: (track, _) => track.dateAdded.dateFormatted,
    TrackTileItem.format: (track, _) => track.format.toUpperCase(),
    TrackTileItem.sampleRate: (track, _) => '${track.sampleRate}Hz',
    TrackTileItem.bitDepth: (track, _) => '${track.bits} bit',
    TrackTileItem.lossless: (track, _) => track.audioQualityText(),
    TrackTileItem.bpm: (track, _) => '${track.bpm ?? 0} BPM',
    TrackTileItem.size: (track, _) => track.size.fileSizeFormatted,
    TrackTileItem.bitrate: (track, _) => "${(track.bitrate)} kb/s",
    TrackTileItem.dateModified: (track, _) {
      final finalDate = track.dateModified.dateFormatted;
      final finalClock = track.dateModified.clockFormatted;
      return '$finalDate, $finalClock';
    },
    TrackTileItem.dateModifiedClock: (track, _) {
      final finalClock = track.dateModified.clockFormatted;
      return finalClock;
    },
    TrackTileItem.dateModifiedDate: (track, _) {
      final finalDate = track.dateModified.dateFormatted;
      return finalDate;
    },
    // -- stats
    TrackTileItem.rating: (track, _) => "${track.effectiveRating}%",
    TrackTileItem.moods: (track, _) => track.effectiveMoods.join(', '),
    TrackTileItem.tags: (track, _) => track.effectiveTags.join(', '),
    TrackTileItem.listenCount: (_, rawTrack) => HistoryController.inst.topTracksMapListens.value[rawTrack]?.length.formatDecimal() ?? '0',
    TrackTileItem.latestListenDate: (_, rawTrack) {
      final date = HistoryController.inst.topTracksMapListens.value[rawTrack]?.lastOrNull;
      if (date == null) return '';
      return TimeAgoController.dateFromNow(date.milliSecondsSinceEpoch);
    },
    TrackTileItem.firstListenDate: (track, rawTrack) {
      final firstListenDateMS = HistoryController.inst.topTracksMapListens.value[rawTrack]?.firstOrNull;
      if (firstListenDateMS == null) return '';
      if (isKuru) {
        final releaseDate = track.yearAsDateTime();
        if (releaseDate != null) {
          final firstListenDate = DateTime.fromMillisecondsSinceEpoch(firstListenDateMS);
          if (firstListenDate.day != releaseDate.day) {
            final diffDays = firstListenDate.difference(releaseDate).inDays.abs();
            if (diffDays == 1) {
              return "${firstListenDateMS.dateFormatted}?";
            } else if (diffDays > 1 && diffDays <= 8) {
              return "${firstListenDateMS.dateFormatted}+$diffDays?";
            }
          }
        }
      }
      return firstListenDateMS.dateFormatted;
    },
  };
}

class _TrackTileBackground extends StatelessWidget {
  final _TrackTileBackgroundState state;
  final Widget child;

  const _TrackTileBackground({
    required this.state,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final needsAccent = state.bgColor == null && (state.isPlaying || state.hasHighlightLayer);
    // -- always an Obx so the tree keeps its shape when the tile starts playing
    return Obx(
      (context) {
        if (!needsAccent) {
          return _TrackTileDecoration(
            state: state,
            accent: null,
            child: child,
          );
        }
        final pageColorScheme = CurrentColor.inst.currentColorScheme;
        final playingColor = state.comingFromQueue || settings.autoColor.valueR ? CurrentColor.inst.miniplayerColor : pageColorScheme; // always follow track color
        final palette = CurrentColor.inst.miniplayerColorM.palette;
        final playingColorAlt = palette.isNotEmpty ? palette[0].withOpacityExt(0.4) : null;
        return _TrackTileDecoration(
          state: state,
          accent: (pageColorScheme: pageColorScheme, playingColor: playingColor, playingColorAlt: playingColorAlt),
          child: child,
        );
      },
    );
  }
}

class _TrackTileDecoration extends StatelessWidget {
  final _TrackTileBackgroundState state;
  final _TrackTileAccent? accent;
  final Widget child;

  const _TrackTileDecoration({
    required this.state,
    required this.accent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NColorsData.targetOf(context);
    final accent = this.accent;
    Color backgroundColor;
    Color? backgroundColorAlt;
    Border? border;
    final bgColor = state.bgColor?.resolve(colors);
    if (bgColor != null) {
      backgroundColor = bgColor;
    } else {
      if (state.isPlaying && accent != null) {
        backgroundColor = accent.playingColor;
        backgroundColorAlt = accent.playingColorAlt;
      } else {
        backgroundColor = colors.cardTheme.withOpacityExt(state.cardColorOpacity);
      }
      if (state.hasSelectionLayer) {
        backgroundColor = Color.alphaBlend(
          colors.focus,
          backgroundColor,
        );
      } else if (state.hasHighlightLayer && accent != null) {
        border = Border(
          right: BorderSide(
            width: 3.0,
            color: accent.pageColorScheme,
          ),
        );
        backgroundColor = Color.alphaBlend(
          colors.focus.withOpacityExt(0.2),
          backgroundColor,
        );
      }
    }

    if (state.hasJumpHighlightLayer) {
      final jumpHighlight = state.comingFromQueue ? JumpHighlight.queueColor : JumpHighlight.color;
      final jumpHighlightColor = jumpHighlight.resolve(colors);
      backgroundColor = Color.alphaBlend(jumpHighlightColor, backgroundColor);
      if (backgroundColorAlt != null) backgroundColorAlt = Color.alphaBlend(jumpHighlightColor, backgroundColorAlt);
    }

    BoxDecoration decoration;
    if (settings.gradientTiles.value) {
      // -- has to be always gradient to animate properly
      decoration = BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            backgroundColor,
            backgroundColorAlt ?? backgroundColor,
          ],
          stops: const [0.6, 1.0],
        ),
        border: border,
      );
    } else {
      decoration = BoxDecoration(
        color: backgroundColor,
        border: border,
      );
    }
    return AnimatedDecoration(
      duration: const Duration(milliseconds: 300),
      decoration: decoration,
      child: child,
    );
  }
}

class _TrackTileLikeButton extends StatelessWidget {
  final Track track;
  final bool isPlaying;
  final Color? textColor;

  const _TrackTileLikeButton({
    required this.track,
    required this.isPlaying,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final textMediumColor = NText.medium.of(context).color?.withOpacityExt(0.55);
    return Obx(
      (context) {
        if (isPlaying) {
          return NamidaLocalLikeButton(
            track: track,
            size: 22.0,
            color: textColor?.withOpacityExt(0.55) ?? textMediumColor,
          );
        }
        final pageColorScheme = CurrentColor.inst.currentColorScheme;
        final baseColor = textColor ?? textMediumColor ?? Colors.transparent;
        final iconColor = Color.alphaBlend(
          pageColorScheme.withOpacityExt(0.4),
          baseColor.withOpacityExt(0.4),
        );
        return NamidaLocalLikeButton(
          track: track,
          size: 22.0,
          color: iconColor,
        );
      },
    );
  }
}

class _TrackTileBackgroundState {
  final NColors? bgColor;
  final bool isPlaying;
  final bool hasSelectionLayer;
  final bool hasHighlightLayer;
  final bool hasJumpHighlightLayer;
  final bool comingFromQueue;
  final double cardColorOpacity;

  const _TrackTileBackgroundState({
    required this.bgColor,
    required this.isPlaying,
    required this.hasSelectionLayer,
    required this.hasHighlightLayer,
    required this.hasJumpHighlightLayer,
    required this.comingFromQueue,
    required this.cardColorOpacity,
  });
}

typedef _TrackTileAccent = ({Color pageColorScheme, Color playingColor, Color? playingColorAlt});

typedef _TrackTilePlayState = ({bool isPlaying, bool isHighlighted, bool willSleep});
