import 'dart:async';

import 'package:flutter/material.dart';

import 'package:playlist_manager/module/playlist_id.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/class/streams/video_stream_info.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/time_ago_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/pages/subpages/playlist_tracks_subpage.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/functions/add_to_playlist_sheet.dart';
import 'package:namida/youtube/widgets/video_info_dialog.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:namida/youtube/yt_utils.dart';

class VideoTilePropertiesProvider extends StatelessWidget {
  final VideoTilePropertiesConfigs configs;
  final Widget Function(VideoTileProperties properties) builder;

  const VideoTilePropertiesProvider({
    super.key,
    required this.builder,
    required this.configs,
  });

  @override
  Widget build(BuildContext context) {
    var queueSource = configs.queueSource;
    final comingFromQueue = queueSource == QueueSourceYoutubeID.playerQueue;
    final canHaveDuplicates = queueSource.canHaveDuplicates;

    final backgroundColorNotPlaying = context.theme.cardTheme.color ?? Colors.transparent;
    final selectionColorLayer = context.theme.focusColor;

    final itemsColor7 = Colors.white.withValues(alpha: 0.7);
    final itemsColor6 = Colors.white.withValues(alpha: 0.6);
    final itemsColor5 = Colors.white.withValues(alpha: 0.5);

    Widget? threeLines;
    Widget? threeLinesPlaying;
    if (configs.draggableThumbnail) {
      if (configs.reorderableRx != null) {
        threeLines = ObxO(
          rx: configs.reorderableRx!,
          builder: (context, value) => ThreeLineSmallContainers(enabled: value, color: null),
        );
        threeLinesPlaying = ObxO(
          rx: configs.reorderableRx!,
          builder: (context, value) => ThreeLineSmallContainers(enabled: value, color: itemsColor5),
        );
      } else {
        threeLines = ThreeLineSmallContainers(enabled: configs.draggingEnabled, color: null);
        threeLinesPlaying = ThreeLineSmallContainers(enabled: configs.draggingEnabled, color: itemsColor5);
      }
    }

    return ObxO(
      rx: settings.onTrackSwipeLeft,
      builder: (context, onTrackSwipeLeft) => ObxO(
        rx: settings.onTrackSwipeRight,
        builder: (context, onTrackSwipeRight) => ObxO(
          rx: Player.inst.currentIndex,
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
              final currentPlayingVideo = Player.inst.currentVideoR;

              final backgroundColorPlaying =
                  comingFromQueue || settings.autoColor.valueR ? CurrentColor.inst.miniplayerColor : CurrentColor.inst.currentColorScheme; // always follow track color

              final properties = VideoTileProperties(
                threeLines: threeLines,
                threeLinesPlaying: threeLinesPlaying,
                itemsColor7: itemsColor7,
                itemsColor6: itemsColor6,
                itemsColor5: itemsColor5,
                backgroundColorPlaying: backgroundColorPlaying,
                backgroundColorNotPlaying: backgroundColorNotPlaying,
                selectionColorLayer: selectionColorLayer,
                currentPlayingVideo: currentPlayingVideo,
                currentPlayingIndex: currentPlayingIndex,
                sleepingIndex: sleepingIndex,
                comingFromQueue: comingFromQueue,
                configs: configs,
                canHaveDuplicates: canHaveDuplicates,
                allowSwipeLeft: !comingFromQueue && onTrackSwipeLeft != OnTrackTileSwapActions.none,
                allowSwipeRight: !comingFromQueue && onTrackSwipeRight != OnTrackTileSwapActions.none,
              );
              return builder(properties);
            },
          ),
        ),
      ),
    );
  }
}

class VideoTilePropertiesConfigs {
  final QueueSourceYoutubeID queueSource;
  final PlaylistID? playlistID;
  final String playlistName;
  final bool horizontalGestures;
  final bool openMenuOnLongPress;
  final bool displayTimeAgo;
  final bool draggingEnabled;
  final bool draggableThumbnail;
  final bool showMoreIcon;
  final Rx<bool>? reorderableRx;

  const VideoTilePropertiesConfigs({
    required this.queueSource,
    this.playlistID,
    this.playlistName = '',
    this.openMenuOnLongPress = true,
    this.displayTimeAgo = true,
    this.draggingEnabled = false,
    this.draggableThumbnail = false,
    this.horizontalGestures = true,
    this.showMoreIcon = false,
    this.reorderableRx,
  });
}

class VideoTileProperties {
  final VideoTilePropertiesConfigs configs;
  final Widget? threeLines;
  final Widget? threeLinesPlaying;
  final Color? itemsColor7;
  final Color? itemsColor6;
  final Color? itemsColor5;

  final Color backgroundColorPlaying;
  final Color backgroundColorNotPlaying;
  final Color selectionColorLayer;

  final YoutubeID? currentPlayingVideo;
  final int? currentPlayingIndex;
  final int? sleepingIndex;
  final bool comingFromQueue;
  final bool canHaveDuplicates;

  final bool allowSwipeLeft;
  final bool allowSwipeRight;

  const VideoTileProperties({
    required this.configs,
    required this.threeLines,
    required this.threeLinesPlaying,
    required this.itemsColor7,
    required this.itemsColor6,
    required this.itemsColor5,
    required this.backgroundColorPlaying,
    required this.backgroundColorNotPlaying,
    required this.selectionColorLayer,
    required this.currentPlayingVideo,
    required this.currentPlayingIndex,
    required this.sleepingIndex,
    required this.comingFromQueue,
    required this.canHaveDuplicates,
    required this.allowSwipeLeft,
    required this.allowSwipeRight,
  });
}

class YTHistoryVideoCard extends StatelessWidget {
  final List<Playable> videos;
  final int? day;
  final int index;
  final List<int> overrideListens;
  final bool minimalCard;
  final double? thumbnailHeight;
  final double? minimalCardWidth;
  final bool reversedList;
  final double cardColorOpacity;
  final double fadeOpacity;
  final bool isImportantInCache;
  final Color? bgColor;
  final Widget? topRightWidget;
  final int? downloadIndex;
  final int? downloadTotalLength;
  final VideoTileProperties properties;

  const YTHistoryVideoCard({
    super.key,
    required this.videos,
    required this.day,
    required this.index,
    this.overrideListens = const [],
    this.minimalCard = false,
    this.thumbnailHeight,
    this.minimalCardWidth,
    this.reversedList = false,
    this.cardColorOpacity = 0.75,
    this.fadeOpacity = 0,
    this.isImportantInCache = true,
    this.bgColor,
    this.topRightWidget,
    this.downloadIndex,
    this.downloadTotalLength,
    required this.properties,
  });

  @override
  Widget build(BuildContext context) {
    return YTHistoryVideoCardBase(
      properties: properties,
      mainList: videos,
      itemToYTVideoId: (e) {
        e as YoutubeID;
        return (e.id, e.watchNull);
      },
      day: day,
      index: index,
      downloadIndex: downloadIndex,
      downloadTotalLength: downloadTotalLength,
      overrideListens: overrideListens,
      minimalCard: minimalCard,
      thumbnailHeight: thumbnailHeight,
      minimalCardWidth: minimalCardWidth,
      reversedList: reversedList,
      cardColorOpacity: cardColorOpacity,
      fadeOpacity: fadeOpacity,
      isImportantInCache: isImportantInCache,
      bgColor: bgColor,
      info: null,
      topRightWidget: topRightWidget,
    );
  }
}

class YTHistoryVideoCardBase<T> extends StatefulWidget {
  final List<T> mainList;
  final (String, YTWatch?) Function(T item) itemToYTVideoId;
  final int? day;
  final int index;
  final List<int> overrideListens;
  final bool minimalCard;
  final double? thumbnailHeight;
  final double? minimalCardWidth;
  final bool reversedList;
  final double cardColorOpacity;
  final double fadeOpacity;
  final bool isImportantInCache;
  final Color? bgColor;
  final StreamInfoItem? Function(T item)? info;
  final Widget? topRightWidget;
  final int? downloadIndex;
  final int? downloadTotalLength;
  final bool playSingle;
  final void Function()? onTap;
  final double minimalCardFontMultiplier;

  final VideoTileProperties properties;

  const YTHistoryVideoCardBase({
    super.key,
    required this.mainList,
    required this.itemToYTVideoId,
    required this.day,
    required this.index,
    this.overrideListens = const [],
    this.minimalCard = false,
    this.thumbnailHeight,
    this.minimalCardWidth,
    this.reversedList = false,
    this.cardColorOpacity = 0.75,
    this.fadeOpacity = 0,
    this.isImportantInCache = true,
    this.bgColor,
    required this.info,
    this.topRightWidget,
    this.downloadIndex,
    this.downloadTotalLength,
    this.playSingle = false,
    this.onTap,
    this.minimalCardFontMultiplier = 1.0,
    required this.properties,
  });

  static const kDefaultBorderRadiusThumbnail = 8.0;
  static const kDefaultBorderRadiusMinimalCard = kDefaultBorderRadiusThumbnail;
  static const kDefaultBorderRadius = 10.0;

  static const minimalCardExtraThumbCropHeight = 6.0;
  static const minimalCardExtraThumbCropWidth = 8.0;
  static EdgeInsets cardMargin(bool minimal) => EdgeInsets.symmetric(horizontal: minimal ? 2.0 : 4.0, vertical: Dimensions.youtubeCardItemVerticalPadding);

  @override
  State<YTHistoryVideoCardBase<T>> createState() => _YTHistoryVideoCardBaseState<T>();
}

class _YTHistoryVideoCardBaseState<T> extends State<YTHistoryVideoCardBase<T>> {
  YoutubeID itemToYTIDPlay(T item) {
    final e = widget.itemToYTVideoId(item);
    return YoutubeID(id: e.$1, watchNull: e.$2, playlistID: widget.properties.configs.playlistID);
  }

  @override
  void initState() {
    super.initState();
    _assignItemInfoFromIndex();
  }

  @override
  void didUpdateWidget(covariant YTHistoryVideoCardBase<T> oldWidget) {
    _assignItemInfoFromIndex();
    super.didUpdateWidget(oldWidget);
  }

  void _assignItemInfoFromIndex() {
    index = widget.reversedList ? widget.mainList.length - 1 - this.widget.index : this.widget.index;
    item = widget.mainList[index];
    final videoIdWatch = widget.itemToYTVideoId(item);
    final newVideoId = videoIdWatch.$1;
    videoWatch = videoIdWatch.$2;

    if (newVideoId != videoId) {
      videoId = newVideoId;
      refreshState(
        () {
          _infoFinal = null;
          _videoTitle = ' ';
          _videoChannel = ' ';
          _duration = null;
        },
      );
      _initValues(videoId);
    } else {
      refreshState();
    }
  }

  late int index;
  late T item;
  String videoId = '';
  late YTWatch? videoWatch;

  bool _isInitializingValues = false;
  StreamInfoItem? _infoFinal;
  VideoStreamInfo? _infoVideoFinal;
  String? _videoTitle = ' '; // nice hack to preserve an empty verical place for the future title :D
  String? _videoChannel = ' ';
  String? _duration;
  bool _isVideoUnavailable = false;

  void _initValues(String videoId) async {
    if (_isInitializingValues) return;

    StreamInfoItem? infoFinal = this.widget.info?.call(item);
    if (infoFinal != null) {
      _infoFinal = infoFinal;
      _videoTitle = _infoFinal?.title;
      _videoChannel = _infoFinal?.channelName?.nullifyEmpty() ?? _infoFinal?.channel?.title?.nullifyEmpty();
      _duration = infoFinal.durSeconds?.secondsLabel;
      return;
    }

    // -- basic init to reduce eliminate flashes, checkFromStorage is always false to prevent ui blocking
    _infoFinal = YoutubeInfoController.utils.tempVideoInfosFromStreams[videoId];
    _videoTitle = YoutubeInfoController.utils.getVideoNameSync(videoId, checkFromStorage: false);
    _videoChannel = YoutubeInfoController.utils.getVideoChannelNameSync(videoId, checkFromStorage: false);
    _duration = YoutubeInfoController.utils.getVideoDurationSecondsSyncTemp(videoId)?.secondsLabel;

    _isInitializingValues = true;

    final newInfo = await YoutubeInfoController.utils.getStreamInfo(videoId);
    refreshState(
      () {
        _infoFinal = newInfo;
        _videoTitle = _infoFinal?.title;
        _videoChannel = _infoFinal?.channelName?.nullifyEmpty() ?? _infoFinal?.channel?.title?.nullifyEmpty();
        _duration = newInfo?.durSeconds?.secondsLabel;
      },
    );

    String? newVideoTitle = _videoTitle;
    String? newVideoChannel = _videoChannel;
    String? newDuration = _duration;
    bool newIsVideoUnavailable = _isVideoUnavailable;

    await [
      () async {
        if (newDuration?.isEmpty ?? true) {
          final dur = await YoutubeInfoController.utils.getVideoDurationSeconds(videoId);
          newDuration = dur?.secondsLabel;
        }
      }(),
      () async {
        if (newVideoTitle?.isEmpty ?? true) {
          newVideoTitle = await YoutubeInfoController.utils.getVideoName(videoId, onMissingInfo: () {
            VideoController.inst.videosPriorityManager.setVideoPriority(videoId, CacheVideoPriority.VIP);
            newIsVideoUnavailable = true;
          });
        } else if (newVideoTitle?.isYTTitleFaulty() == true) {
          VideoController.inst.videosPriorityManager.setVideoPriority(videoId, CacheVideoPriority.VIP);
          newIsVideoUnavailable = true;
          newVideoTitle = await YoutubeInfoController.utils.getVideoName(videoId, onMissingInfo: null);
        }
      }(),
      () async {
        if (newVideoChannel?.isEmpty ?? true) {
          newVideoChannel = await YoutubeInfoController.utils.getVideoChannelName(videoId);
        }
      }(),
    ].wait;

    if (newVideoTitle != _videoTitle || newVideoChannel != _videoChannel || newDuration != _duration || newIsVideoUnavailable != _isVideoUnavailable) {
      refreshState(
        () {
          _videoTitle = newVideoTitle;
          _videoChannel = newVideoChannel;
          _duration = newDuration;
          _isVideoUnavailable = newIsVideoUnavailable;
        },
      );
    }

    if (mounted && (_videoTitle?.isEmpty ?? true)) {
      await _fetchNewInfo();
    }

    _isInitializingValues = false;
  }

  Future<void> _fetchNewInfo() async {
    if (!ConnectivityController.inst.hasConnection) return;
    final newInfo = await YoutubeInfoController.video.fetchVideoStreams(videoId, forceRequest: false);
    if (newInfo != null) {
      refreshState(
        () {
          _infoVideoFinal = newInfo.info;
          _videoTitle = newInfo.info?.title;
          _videoChannel = newInfo.info?.channelName?.nullifyEmpty();
          _duration = (newInfo.info?.durSeconds ?? newInfo.audioStreams.firstOrNull?.duration?.inSeconds)?.secondsLabel;
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final configs = widget.properties.configs;

    double thumbHeight = widget.thumbnailHeight ?? (widget.minimalCard ? 24.0 * 3.2 : Dimensions.youtubeCardItemHeight);
    double thumbWidth = widget.minimalCardWidth ?? thumbHeight * 16 / 9;
    if (widget.minimalCard) {
      // this might crop the image since we enabling forceSquared.
      thumbHeight -= YTHistoryVideoCardBase.minimalCardExtraThumbCropHeight;
      thumbWidth -= YTHistoryVideoCardBase.minimalCardExtraThumbCropWidth;
    }

    final info = _infoFinal;
    final duration = _duration;

    String? dateText;
    if (configs.displayTimeAgo) {
      final watchMS = videoWatch?.dateMSNull;
      if (watchMS != null) dateText = widget.minimalCard ? TimeAgoController.dateMSSEFromNow(watchMS) : watchMS.dateAndClockFormattedOriginal;
    }

    Widget? draggingThumbWidget;
    if (configs.draggableThumbnail && configs.draggingEnabled) {
      final lis = NamidaReordererableListener(
        key: const ValueKey(0),
        durationMs: 80,
        index: index,
        child: Container(
          color: Colors.transparent,
          height: thumbHeight * 0.9,
          width: thumbWidth * 0.9, // not fully but better, to avoid accidents
        ),
      );
      if (configs.reorderableRx != null) {
        draggingThumbWidget = ObxO(
          rx: configs.reorderableRx!,
          builder: (context, value) => value ? lis : const SizedBox(),
        );
      } else {
        draggingThumbWidget = lis;
      }
    }

    final willSleepAfterThis = widget.properties.sleepingIndex == index;

    final videoTitle = _videoTitle;
    final videoChannel = _videoChannel;

    final displayVideoChannel = videoChannel != null && videoChannel.isNotEmpty;
    final displayDateText = dateText != null && dateText.isNotEmpty;

    final bool isRightIndex = widget.properties.canHaveDuplicates ? index == widget.properties.currentPlayingIndex : true;
    bool isCurrentlyPlaying = false;

    if (isRightIndex) {
      final curr = widget.properties.currentPlayingVideo;
      if (videoId == curr?.id && videoWatch == curr?.watchNull) isCurrentlyPlaying = true;
    }

    Widget? threeLines;
    Color? itemsColor7;
    Color? itemsColor6;
    Color? itemsColor5;

    if (isCurrentlyPlaying) {
      itemsColor7 = widget.properties.itemsColor7;
      itemsColor6 = widget.properties.itemsColor6;
      itemsColor5 = widget.properties.itemsColor5;
      threeLines = widget.properties.threeLinesPlaying;
    } else {
      threeLines = widget.properties.threeLines;
    }

    final children = [
      if (threeLines != null) threeLines,
      Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: Padding(
              padding: widget.minimalCard ? const EdgeInsets.all(1.0) : const EdgeInsets.all(2.0),
              child: YoutubeThumbnail(
                type: ThumbnailType.video,
                key: Key(videoId),
                borderRadius: YTHistoryVideoCardBase.kDefaultBorderRadiusThumbnail,
                isImportantInCache: widget.isImportantInCache,
                width: thumbWidth,
                height: thumbHeight,
                videoId: videoId,
                preferLowerRes: true,
                customUrl: _infoVideoFinal?.thumbnails.pick()?.url ?? info?.liveThumbs.pick()?.url,
                smallBoxText: duration,
                smallBoxIcon: willSleepAfterThis
                    ? Broken.timer_1
                    : _isVideoUnavailable
                        ? Broken.danger
                        : null,
                reduceInitialFlashes: configs.draggingEnabled,
                forceSquared: true, // -- if false, low quality images with black bars would appear
              ),
            ),
          ),
          if (draggingThumbWidget != null) draggingThumbWidget
        ],
      ),
      const SizedBox(width: 8.0),
      Expanded(
        child: Padding(
            padding: widget.minimalCard ? const EdgeInsets.fromLTRB(4.0, 0, 4.0, 4.0) : EdgeInsets.zero,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  videoTitle ?? videoId,
                  maxLines: widget.minimalCard && (displayVideoChannel || displayDateText) ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.displayMedium?.copyWith(
                    fontSize: widget.minimalCard ? 12.0 * widget.minimalCardFontMultiplier : null,
                    color: itemsColor7,
                  ),
                ),
                if (displayVideoChannel)
                  Text(
                    videoChannel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.displaySmall?.copyWith(
                      fontSize: widget.minimalCard ? 11.5 * widget.minimalCardFontMultiplier : null,
                      color: itemsColor6,
                    ),
                  ),
                if (displayDateText)
                  Text(
                    dateText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.displaySmall?.copyWith(
                      fontSize: widget.minimalCard ? 11.0 * widget.minimalCardFontMultiplier : null,
                      color: itemsColor5,
                    ),
                  ),
              ],
            )),
      ),
      const SizedBox(width: 6.0 + 12.0), // right + iconWidth
      const SizedBox(width: 8.0),
    ];

    final borderRadiusRawValue = widget.minimalCard ? YTHistoryVideoCardBase.kDefaultBorderRadiusMinimalCard : YTHistoryVideoCardBase.kDefaultBorderRadius;

    Widget finalChild = NamidaPopupWrapper(
      openOnTap: false,
      openOnLongPress: configs.openMenuOnLongPress,
      childrenDefault: () => YTUtils.getVideoCardMenuItems(
        queueSource: configs.queueSource,
        downloadIndex: widget.downloadIndex,
        totalLength: widget.downloadTotalLength,
        streamInfoItem: info,
        videoId: videoId,
        channelID: _infoVideoFinal?.channelId ?? info?.channelId ?? info?.channel?.id,
        playlistID: configs.playlistID,
        idsNamesLookup: {videoId: _infoVideoFinal?.title},
        playlistName: configs.playlistName,
        videoYTID: itemToYTIDPlay(item),
      ),
      child: NamidaInkWell(
        animationDurationMS: 300,
        borderRadius: borderRadiusRawValue,
        width: widget.minimalCard ? thumbWidth : null,
        onTap: widget.onTap ??
            () {
              YTUtils.expandMiniplayer();
              if (widget.properties.comingFromQueue) {
                final i = this.widget.index;
                if (i == Player.inst.currentIndex.value) {
                  Player.inst.togglePlayPause();
                } else {
                  Player.inst.skipToQueueItem(this.widget.index);
                }
              } else {
                final finalList = widget.reversedList ? widget.mainList.reversed : widget.mainList;
                if (widget.playSingle) {
                  Player.inst.playOrPause(
                    0,
                    [itemToYTIDPlay(finalList.elementAt(this.widget.index))],
                    configs.queueSource,
                    gentlePlay: true,
                  );
                } else {
                  final gentlePlay = finalList.hasSingleItem();
                  Player.inst.playOrPause(
                    this.widget.index,
                    finalList.map(itemToYTIDPlay),
                    configs.queueSource,
                    gentlePlay: gentlePlay,
                  );
                }
              }
            },
        height: widget.minimalCard ? null : Dimensions.youtubeCardItemExtent,
        margin: YTHistoryVideoCardBase.cardMargin(widget.minimalCard),
        bgColor: widget.bgColor ??
            (isCurrentlyPlaying
                ? (widget.properties.comingFromQueue ? CurrentColor.inst.miniplayerColor : CurrentColor.inst.currentColorScheme).withAlpha(140)
                : (context.theme.cardColor.withValues(alpha: widget.cardColorOpacity))),
        child: Stack(
          children: [
            widget.minimalCard
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children,
                  )
                : Row(
                    children: children,
                  ),
            Positioned(
              bottom: 4.0,
              right: widget.minimalCard ? 2.0 : 12.0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: YTUtils.getVideoCacheStatusIcons(
                  context: context,
                  videoId: videoId,
                  iconsColor: itemsColor5,
                  overrideListens: widget.overrideListens,
                  displayCacheIcons: !widget.minimalCard,
                  fontMultiplier: widget.minimalCard ? widget.minimalCardFontMultiplier : null,
                ),
              ),
            ),
            if (configs.showMoreIcon)
              Positioned(
                top: 0.0,
                right: 0.0,
                child: NamidaPopupWrapper(
                  childrenDefault: () => YTUtils.getVideoCardMenuItems(
                    queueSource: configs.queueSource,
                    downloadIndex: widget.downloadIndex,
                    totalLength: widget.downloadTotalLength,
                    streamInfoItem: info,
                    videoId: videoId,
                    channelID: _infoVideoFinal?.channelId ?? info?.channelId ?? info?.channel?.id,
                    playlistID: configs.playlistID,
                    idsNamesLookup: {videoId: videoTitle},
                    playlistName: configs.playlistName,
                    videoYTID: itemToYTIDPlay(item),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: MoreIcon(
                      iconSize: 16.0,
                      iconColor: itemsColor6,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 0.0,
              right: 0.0,
              child: widget.topRightWidget ?? const SizedBox(),
            ),
            if (widget.fadeOpacity > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(borderRadiusRawValue.multipliedRadius),
                      color: context.theme.cardColor.withValues(alpha: widget.fadeOpacity),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (!widget.minimalCard && configs.horizontalGestures && (widget.properties.allowSwipeLeft || widget.properties.allowSwipeRight)) {
      final plItem = itemToYTIDPlay(item);
      return SwipeQueueAddTile(
        item: plItem,
        dismissibleKey: plItem,
        allowSwipeLeft: widget.properties.allowSwipeLeft,
        allowSwipeRight: widget.properties.allowSwipeRight,
        onAddToPlaylist: (_) => showAddToPlaylistSheet(ids: [videoId], idsNamesLookup: {videoId: videoTitle}),
        onOpenInfo: (_) => NamidaNavigator.inst.navigateDialog(dialog: VideoInfoDialog(videoId: videoId)),
        child: finalChild,
      );
    }

    return finalChild;
  }
}
