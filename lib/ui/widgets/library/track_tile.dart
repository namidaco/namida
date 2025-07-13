import 'package:flutter/material.dart';

import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/player_controller.dart';
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
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/add_to_playlist_dialog.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/dialogs/track_info_dialog.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

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
    var queueSource = configs.queueSource;
    final comingFromQueue = queueSource == QueueSource.playerQueue;
    final canHaveDuplicates = queueSource.canHaveDuplicates;

    final backgroundColorNotPlaying = context.theme.cardTheme.color ?? Colors.transparent;
    final selectionColorLayer = context.theme.focusColor;

    final listenToTopHistoryItems =
        settings.trackItem.values.any((element) => element == TrackTileItem.listenCount || element == TrackTileItem.latestListenDate || element == TrackTileItem.firstListenDate);

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
                  rx: settings.trackListTileHeight,
                  builder: (context, trackTileHeight) => ObxO(
                    rx: Indexer.inst.tracksInfoList,
                    builder: (context, _) => ObxO(
                      rx: SelectedTracksController.inst.existingTracksMap,
                      builder: (context, selectedTracksMap) => _ObxPrefer(
                        rx: HistoryController.inst.topTracksMapListens,
                        enabled: listenToTopHistoryItems,
                        builder: (context, _) => ObxO(
                          rx: CurrentColor.inst.currentPlayingTrack,
                          builder: (context, currentPlayingTrack) => ObxO(
                            rx: CurrentColor.inst.currentPlayingIndex,
                            builder: (context, currentPlayingIndex) => Obx(
                              (context) {
                                int? sleepingIndex;
                                if (comingFromQueue) {
                                  final sleepconfig = Player.inst.sleepTimerConfig.valueR;
                                  if (sleepconfig.enableSleepAfterItems) {
                                    final repeatMode = settings.player.repeatMode.valueR;
                                    if (repeatMode == RepeatMode.all || repeatMode == RepeatMode.none) {
                                      sleepingIndex = Player.inst.sleepingItemIndex(sleepconfig.sleepAfterItems, Player.inst.currentIndex.valueR);
                                    }
                                  }
                                }

                                final backgroundColorPlaying = comingFromQueue || settings.autoColor.valueR
                                    ? CurrentColor.inst.miniplayerColor
                                    : CurrentColor.inst.currentColorScheme; // always follow track color

                                final properties = TrackTileProperties(
                                  backgroundColorPlaying: backgroundColorPlaying,
                                  backgroundColorNotPlaying: backgroundColorNotPlaying,
                                  selectionColorLayer: selectionColorLayer,
                                  thumbnailSize: thumbnailSize,
                                  trackTileHeight: trackTileHeight,
                                  forceSquaredThumbnails: forceSquaredThumbnails,
                                  sleepingIndex: sleepingIndex,
                                  displayThirdRow: displayThirdRow,
                                  displayFavouriteIconInListTile: displayFavouriteIconInListTile,
                                  comingFromQueue: comingFromQueue,
                                  configs: configs,
                                  canHaveDuplicates: canHaveDuplicates,
                                  currentPlayingTrack: currentPlayingTrack,
                                  currentPlayingIndex: currentPlayingIndex,
                                  isTrackSelected: (trOrTwd) => selectedTracksMap[trOrTwd.track] != null,
                                  allowSwipeLeft: !comingFromQueue && onTrackSwipeLeft != OnTrackTileSwapActions.none,
                                  allowSwipeRight: !comingFromQueue && onTrackSwipeRight != OnTrackTileSwapActions.none,
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
    );
  }
}

class _ObxPrefer<T> extends StatelessWidget {
  final RxBaseCore<T> rx;
  final Widget Function(BuildContext context, T? value) builder;
  final bool enabled;
  const _ObxPrefer({required this.rx, required this.builder, required this.enabled, super.key});

  @override
  Widget build(BuildContext context) {
    return enabled ? ObxO(rx: rx, builder: builder) : builder(context, null);
  }
}

class TrackTilePropertiesConfigs {
  final QueueSource queueSource;

  /// Disable if you want to have priority to hold & reorder instead of selecting.
  final bool Function()? selectable;
  final bool draggableThumbnail;
  final bool displayRightDragHandler;
  final bool displayTrackNumber;
  final bool horizontalGestures;
  final String? playlistName;

  const TrackTilePropertiesConfigs({
    required this.queueSource,
    this.selectable,
    this.draggableThumbnail = false,
    this.displayRightDragHandler = false,
    this.displayTrackNumber = false,
    this.horizontalGestures = true,
    this.playlistName,
  });
}

class TrackTileProperties {
  final TrackTilePropertiesConfigs configs;
  final Color backgroundColorPlaying;
  final Color backgroundColorNotPlaying;
  final Color selectionColorLayer;

  final double thumbnailSize;
  final double trackTileHeight;
  final bool forceSquaredThumbnails;
  final int? sleepingIndex;
  final bool displayThirdRow;
  final bool displayFavouriteIconInListTile;
  final bool comingFromQueue;
  final bool canHaveDuplicates;
  final Selectable? currentPlayingTrack;
  final int? currentPlayingIndex;
  final Function(Selectable trOrTwd) isTrackSelected;

  final bool allowSwipeLeft;
  final bool allowSwipeRight;

  const TrackTileProperties({
    required this.configs,
    required this.backgroundColorPlaying,
    required this.backgroundColorNotPlaying,
    required this.selectionColorLayer,
    required this.thumbnailSize,
    required this.trackTileHeight,
    required this.forceSquaredThumbnails,
    required this.sleepingIndex,
    required this.displayThirdRow,
    required this.displayFavouriteIconInListTile,
    required this.comingFromQueue,
    required this.canHaveDuplicates,
    required this.currentPlayingTrack,
    required this.currentPlayingIndex,
    required this.isTrackSelected,
    required this.allowSwipeLeft,
    required this.allowSwipeRight,
  });
}

class TrackTile extends StatelessWidget {
  final int index;
  final Selectable trackOrTwd;
  final TrackTileProperties properties;
  final VoidCallback? onTap;
  final VoidCallback? onPlaying;

  final Color? bgColor;
  final double cardColorOpacity;
  final double fadeOpacity;
  final void Function()? onRightAreaTap;
  final Widget? trailingWidget;
  final Widget? topRightWidget;
  final String? thirdLineText;

  const TrackTile({
    super.key,
    required this.properties,
    required this.trackOrTwd,
    this.onTap,
    this.onPlaying,
    required this.index,
    this.bgColor,
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
  bool get _isFromQueue => properties.configs.queueSource == QueueSource.playerQueue;
  String get _heroTag => obtainHeroTag(_twd, _tr, index, properties.comingFromQueue);

  void _triggerTrackDialog() => NamidaDialogs.inst.showTrackDialog(
        _tr,
        playlistName: properties.configs.playlistName,
        index: index,
        comingFromQueue: _isFromQueue,
        trackWithDate: trackOrTwd.trackWithDate,
        source: properties.configs.queueSource,
        heroTag: _heroTag,
      );

  void _triggerTrackInfoDialog() => showTrackInfoDialog(
        _tr,
        true,
        comingFromQueue: _isFromQueue,
        index: index,
        queueSource: properties.configs.queueSource,
        heroTag: _heroTag,
      );

  void _selectTrack() => SelectedTracksController.inst.selectOrUnselect(trackOrTwd, properties.configs.queueSource, properties.configs.playlistName);

  @override
  Widget build(BuildContext context) {
    final queueSource = properties.configs.queueSource;
    final track = _tr;
    final trackWithDate = _twd;
    final isInSelectedTracksPreview = queueSource == QueueSource.selectedTracks;

    final willSleepAfterThis = properties.sleepingIndex == index;

    final bool isTrackSelected = properties.isTrackSelected(trackOrTwd);
    final bool isTrackSame = track == properties.currentPlayingTrack?.track;
    final bool isRightHistoryList = queueSource == QueueSource.history ? trackWithDate == properties.currentPlayingTrack?.trackWithDate : true;
    final bool isRightIndex = properties.canHaveDuplicates ? index == properties.currentPlayingIndex : true;
    final bool isTrackCurrentlyPlaying = isRightIndex && isTrackSame && isRightHistoryList;

    final textColor = isTrackCurrentlyPlaying && !isTrackSelected ? Colors.white : null;

    Color backgroundColor;
    if (bgColor != null) {
      backgroundColor = bgColor!;
    } else {
      backgroundColor = isTrackCurrentlyPlaying ? properties.backgroundColorPlaying : properties.backgroundColorNotPlaying.withValues(alpha: cardColorOpacity);
      if (isTrackSelected && queueSource != QueueSource.selectedTracks) {
        backgroundColor = Color.alphaBlend(
          properties.selectionColorLayer,
          backgroundColor,
        );
      }
    }
    Widget threeLinesColumn;
    if (trackOrTwd.track.toTrackExtOrNull() == null) {
      threeLinesColumn = Text(
        trackOrTwd.track.path,
        style: context.textTheme.displaySmall?.copyWith(
          color: textColor?.withAlpha(170),
        ),
      );
    } else {
      final thirdLineText = this.thirdLineText;
      final row1Text = TrackTileManager._joinTrackItems(_TrackTileRowOrder.first, track);
      final row2Text = TrackTileManager._joinTrackItems(_TrackTileRowOrder.second, track);
      final row3Text = thirdLineText != null && thirdLineText.isNotEmpty
          ? thirdLineText
          : properties.displayThirdRow
              ? TrackTileManager._joinTrackItems(_TrackTileRowOrder.third, track)
              : null;

      threeLinesColumn = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // check if first row isnt empty
          if (row1Text != '')
            Text(
              row1Text,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: context.textTheme.displayMedium!.copyWith(
                color: textColor?.withAlpha(170),
              ),
            ),

          // check if second row isnt empty
          if (row2Text != '')
            Text(
              row2Text,
              style: context.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: textColor?.withAlpha(140),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

          // check if third row isnt empty
          if (row3Text != null && row3Text != '')
            Text(
              row3Text,
              style: context.textTheme.displaySmall?.copyWith(
                color: textColor?.withAlpha(130),
              ),
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
            color: textColor?.withAlpha(100) ?? context.textTheme.displaySmall?.color?.withAlpha(100),
          )
        : null;

    Widget finalChild = Stack(
      alignment: Alignment.centerRight,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: Dimensions.tileBottomMargin),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap ??
                  () async {
                    if (SelectedTracksController.inst.selectedTracks.value.isNotEmpty && !isInSelectedTracksPreview) {
                      _selectTrack();
                    } else {
                      if (onPlaying != null) {
                        onPlaying!();
                        return;
                      }
                      if (queueSource == QueueSource.search) {
                        ScrollSearchController.inst.unfocusKeyboard();
                        await Player.inst.playOrPause(
                          settings.trackPlayMode.value.shouldBeIndex0 ? 0 : index,
                          settings.trackPlayMode.value.generateQueue(track),
                          queueSource,
                          maximumItems: 1000,
                        );
                      } else {
                        await Player.inst.playOrPause(
                          index,
                          queueSource.toTracks(null, trackWithDate?.dateAdded.toDaysSince1970()),
                          queueSource,
                          maximumItems: queueSource == QueueSource.allTracks ? 1000 : null,
                        );
                      }
                    }
                  },
              onLongPress: onTap != null
                  ? null
                  : () {
                      var selectable = properties.configs.selectable;
                      if (selectable != null && selectable() == false) return;
                      if (isInSelectedTracksPreview) return;

                      ScrollSearchController.inst.unfocusKeyboard();
                      _selectTrack();
                    },
              onSecondaryTap: _triggerTrackDialog,
              child: ColoredBox(
                color: backgroundColor,
                child: SizedBox(
                  height: Dimensions.inst.trackTileItemExtent,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: Dimensions.tileVerticalPadding),
                    child: Row(
                      children: [
                        const SizedBox(width: 12.0),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedScale(
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
                                    icon: track is Video ? Broken.video : Broken.musicnote,
                                    iconSize: (properties.trackTileHeight.withMaximum(properties.thumbnailSize)) * 0.5,
                                    onTopWidgets: [
                                      if (properties.configs.displayTrackNumber)
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: NamidaBlurryContainer(
                                            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
                                            borderRadius: BorderRadius.only(topLeft: Radius.circular(4.0.multipliedRadius)),
                                            child: Text(
                                              (track.trackNo).toString(),
                                              style: context.textTheme.displaySmall,
                                            ),
                                          ),
                                        ),
                                      if (willSleepAfterThis)
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(2.0),
                                            decoration: BoxDecoration(
                                              color: context.theme.colorScheme.surface.withAlpha(160),
                                              borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                                            ),
                                            child: const Icon(
                                              Broken.timer_1,
                                              size: 16.0,
                                            ),
                                          ),
                                        )
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (properties.configs.draggableThumbnail)
                              NamidaReordererableListener(
                                durationMs: 80,
                                index: index,
                                child: Container(
                                  color: Colors.transparent,
                                  height: properties.trackTileHeight,
                                  width: properties.thumbnailSize,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: threeLinesColumn,
                        ),
                        const SizedBox(width: 6.0),
                        if (properties.displayFavouriteIconInListTile || rightItem1Text != '' || rightItem2Text != '')
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (rightItem1Text != '')
                                Text(
                                  rightItem1Text,
                                  style: context.textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: textColor?.withAlpha(170),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (rightItem2Text != '')
                                Text(
                                  rightItem2Text,
                                  style: context.textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: textColor?.withAlpha(170),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (properties.displayFavouriteIconInListTile)
                                NamidaLocalLikeButton(
                                  track: track,
                                  size: 22.0,
                                  color: textColor?.withAlpha(140) ?? context.textTheme.displayMedium?.color?.withAlpha(140),
                                ),
                            ],
                          ),
                        if (properties.configs.displayRightDragHandler) ...[
                          const SizedBox(width: 8.0),
                          NamidaReordererableListener(
                            durationMs: 20,
                            index: index,
                            child: FittedBox(
                              child: Icon(
                                Broken.menu_1,
                                color: textColor?.withAlpha(160),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 2.0),
                        MoreIcon(
                          padding: 6.0,
                          iconColor: textColor?.withAlpha(160),
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
        if (fadeOpacity > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: context.theme.scaffoldBackgroundColor.withValues(alpha: fadeOpacity),
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
        dismissibleKey: heroTag,
        allowSwipeLeft: properties.allowSwipeLeft,
        allowSwipeRight: properties.allowSwipeRight,
        onAddToPlaylist: (item) => showAddToPlaylistDialog([item.track]),
        onOpenInfo: (_) => _triggerTrackInfoDialog(),
        child: finalChild,
      );
    }
    return finalChild;
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

    final length = positions.length;
    for (int i = 0; i < length; i++) {
      final itemPosition = positions[i];
      final trackItem = settings.trackItem.value[itemPosition];
      if (trackItem == TrackTileItem.latestListenDate || trackItem == TrackTileItem.listenCount) shouldNotCache = true;

      var info = _buildChoosenTrackTileItem(trackItem, track);

      if (info.isNotEmpty) {
        if (needsSeparator) _buffer.write(_separator);
        _buffer.write(info);
        needsSeparator = true;
      }
    }

    return (text: _buffer.toString(), shouldNotCache: shouldNotCache);
  }

  static String _buildChoosenTrackTileItem(TrackTileItem? trackItem, Track trackPre) {
    if (trackItem == null || trackItem == TrackTileItem.none) return '';

    final fn = _lookup[trackItem];
    if (fn != null) {
      final track = trackPre.toTrackExt();
      return fn(track);
    }

    return '';
  }

  static final _lookup = <TrackTileItem, String Function(TrackExtended track)>{
    TrackTileItem.title: (track) => track.title.overflow,
    TrackTileItem.artists: (track) => track.originalArtist.overflow,
    TrackTileItem.album: (track) => track.album.overflow,
    TrackTileItem.albumArtist: (track) => track.albumArtist.overflow,
    TrackTileItem.genres: (track) => track.originalGenre.overflow,
    TrackTileItem.duration: (track) => track.durationMS.milliSecondsLabel,
    TrackTileItem.year: (track) => track.year.yearFormatted,
    TrackTileItem.trackNumber: (track) => track.trackNo.toString(),
    TrackTileItem.discNumber: (track) => track.discNo.toString(),
    TrackTileItem.fileNameWOExt: (track) => track.filenameWOExt.overflow,
    TrackTileItem.extension: (track) => track.extension,
    TrackTileItem.fileName: (track) => track.filename.overflow,
    TrackTileItem.folder: (track) => track.folderName.overflow,
    TrackTileItem.path: (track) => track.path.formatPath(),
    TrackTileItem.channels: (track) => track.channels.channelToLabel,
    TrackTileItem.comment: (track) => track.comment.overflow,
    TrackTileItem.composer: (track) => track.composer.overflow,
    TrackTileItem.dateAdded: (track) => track.dateAdded.dateFormatted,
    TrackTileItem.format: (track) => track.format,
    TrackTileItem.sampleRate: (track) => '${track.sampleRate}Hz',
    TrackTileItem.size: (track) => track.size.fileSizeFormatted,
    TrackTileItem.bitrate: (track) => "${(track.bitrate)} kbps",
    TrackTileItem.dateModified: (track) {
      final finalDate = track.dateModified.dateFormatted;
      final finalClock = track.dateModified.clockFormatted;
      return '$finalDate, $finalClock';
    },
    TrackTileItem.dateModifiedClock: (track) {
      final finalClock = track.dateModified.clockFormatted;
      return finalClock;
    },
    TrackTileItem.dateModifiedDate: (track) {
      final finalDate = track.dateModified.dateFormatted;
      return finalDate;
    },
    // -- stats
    TrackTileItem.rating: (track) => "${track.stats?.rating ?? 0}%",
    TrackTileItem.moods: (track) => track.stats?.moods?.join(', ') ?? '',
    TrackTileItem.tags: (track) => track.stats?.tags?.join(', ') ?? '',
    TrackTileItem.listenCount: (track) => HistoryController.inst.topTracksMapListens.value[track.asTrack()]?.length.formatDecimal() ?? '0',
    TrackTileItem.latestListenDate: (track) {
      final date = HistoryController.inst.topTracksMapListens.value[track.asTrack()]?.lastOrNull;
      if (date == null) return '';
      return TimeAgoController.dateFromNow(date.milliSecondsSinceEpoch);
    },
    TrackTileItem.firstListenDate: (track) {
      final firstListenDateMS = HistoryController.inst.topTracksMapListens.value[track.asTrack()]?.firstOrNull;
      if (firstListenDateMS == null) return '';
      if (isKuru) {
        final releaseDate = DateTime.tryParse(track.year.toString());
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
