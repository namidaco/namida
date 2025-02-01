import 'package:flutter/material.dart';

import 'package:jiffy/jiffy.dart';
import 'package:playlist_manager/module/playlist_id.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
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

class YTHistoryVideoCardBase<T> extends StatelessWidget {
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

  YoutubeID itemToYTIDPlay(T item) {
    final e = itemToYTVideoId(item);
    return YoutubeID(id: e.$1, watchNull: e.$2, playlistID: properties.configs.playlistID);
  }

  static const minimalCardExtraThumbCropHeight = 6.0;
  static const minimalCardExtraThumbCropWidth = 8.0;
  static EdgeInsets cardMargin(bool minimal) => EdgeInsets.symmetric(horizontal: minimal ? 2.0 : 4.0, vertical: Dimensions.youtubeCardItemVerticalPadding);

  @override
  Widget build(BuildContext context) {
    final configs = properties.configs;

    final index = reversedList ? mainList.length - 1 - this.index : this.index;
    final item = mainList[index];
    final videoIdWatch = itemToYTVideoId(item);
    final videoId = videoIdWatch.$1;
    final videoWatch = videoIdWatch.$2;
    double thumbHeight = thumbnailHeight ?? (minimalCard ? 24.0 * 3.2 : Dimensions.youtubeCardItemHeight);
    double thumbWidth = minimalCardWidth ?? thumbHeight * 16 / 9;
    if (minimalCard) {
      // this might crop the image since we enabling forceSquared.
      thumbHeight -= minimalCardExtraThumbCropHeight;
      thumbWidth -= minimalCardExtraThumbCropWidth;
    }

    final info = this.info?.call(item) ?? YoutubeInfoController.utils.getStreamInfoSync(videoId);
    final duration = (info?.durSeconds ?? YoutubeInfoController.utils.getVideoDurationSeconds(videoId))?.secondsLabel;
    String? videoTitle = info?.title;
    bool isVideoUnavailable = false;

    if (videoTitle == null || videoTitle.isEmpty) {
      videoTitle = YoutubeInfoController.utils.getVideoName(videoId, onMissingInfo: () {
        VideoController.inst.videosPriorityManager.setVideoPriority(videoId, CacheVideoPriority.VIP);
        isVideoUnavailable = true;
      });
    } else if (videoTitle.isYTTitleFaulty()) {
      VideoController.inst.videosPriorityManager.setVideoPriority(videoId, CacheVideoPriority.VIP);
      isVideoUnavailable = true;
      videoTitle = YoutubeInfoController.utils.getVideoName(videoId, onMissingInfo: null);
    }

    String? videoChannel = info?.channelName?.nullifyEmpty() ?? info?.channel.title.nullifyEmpty() ?? YoutubeInfoController.utils.getVideoChannelName(videoId);

    String? dateText;
    if (configs.displayTimeAgo) {
      final watchMS = videoWatch?.dateMSNull;
      if (watchMS != null) dateText = minimalCard ? Jiffy.parseFromMillisecondsSinceEpoch(watchMS).fromNow() : watchMS.dateAndClockFormattedOriginal;
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

    final willSleepAfterThis = properties.sleepingIndex == index;

    final displayVideoChannel = videoChannel != null && videoChannel.isNotEmpty;
    final displayDateText = dateText != null && dateText.isNotEmpty;

    final bool isRightIndex = properties.canHaveDuplicates ? index == properties.currentPlayingIndex : true;
    bool isCurrentlyPlaying = false;

    if (isRightIndex) {
      final curr = properties.currentPlayingVideo;
      if (videoId == curr?.id && videoIdWatch.$2 == curr?.watchNull) isCurrentlyPlaying = true;
    }

    Widget? threeLines;
    Color? itemsColor7;
    Color? itemsColor6;
    Color? itemsColor5;

    if (isCurrentlyPlaying) {
      itemsColor7 = properties.itemsColor7;
      itemsColor6 = properties.itemsColor6;
      itemsColor5 = properties.itemsColor5;
      threeLines = properties.threeLinesPlaying;
    } else {
      threeLines = properties.threeLines;
    }

    final children = [
      if (threeLines != null) threeLines,
      Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: Padding(
              padding: minimalCard ? const EdgeInsets.all(1.0) : const EdgeInsets.all(2.0),
              child: YoutubeThumbnail(
                type: ThumbnailType.video,
                key: Key(videoId),
                borderRadius: 8.0,
                isImportantInCache: isImportantInCache,
                width: thumbWidth,
                height: thumbHeight,
                videoId: videoId,
                preferLowerRes: true,
                customUrl: info?.liveThumbs.pick()?.url,
                smallBoxText: duration,
                smallBoxIcon: willSleepAfterThis
                    ? Broken.timer_1
                    : isVideoUnavailable
                        ? Broken.danger
                        : null,
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
            padding: minimalCard ? const EdgeInsets.fromLTRB(4.0, 0, 4.0, 4.0) : EdgeInsets.zero,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  videoTitle ?? videoId,
                  maxLines: minimalCard && (displayVideoChannel || displayDateText) ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.displayMedium?.copyWith(
                    fontSize: minimalCard ? 12.0 * minimalCardFontMultiplier : null,
                    color: itemsColor7,
                  ),
                ),
                if (displayVideoChannel)
                  Text(
                    videoChannel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.displaySmall?.copyWith(
                      fontSize: minimalCard ? 11.5 * minimalCardFontMultiplier : null,
                      color: itemsColor6,
                    ),
                  ),
                if (displayDateText)
                  Text(
                    dateText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.displaySmall?.copyWith(
                      fontSize: minimalCard ? 11.0 * minimalCardFontMultiplier : null,
                      color: itemsColor5,
                    ),
                  ),
              ],
            )),
      ),
      const SizedBox(width: 6.0 + 12.0), // right + iconWidth
      const SizedBox(width: 8.0),
    ];

    Widget finalChild = NamidaPopupWrapper(
      openOnTap: false,
      openOnLongPress: configs.openMenuOnLongPress,
      childrenDefault: () => YTUtils.getVideoCardMenuItems(
        queueSource: configs.queueSource,
        downloadIndex: downloadIndex,
        totalLength: downloadTotalLength,
        streamInfoItem: info,
        videoId: videoId,
        channelID: info?.channelId ?? info?.channel.id,
        playlistID: configs.playlistID,
        idsNamesLookup: {videoId: info?.title},
        playlistName: configs.playlistName,
        videoYTID: itemToYTIDPlay(item),
      ),
      child: NamidaInkWell(
        borderRadius: minimalCard ? 8.0 : 10.0,
        width: minimalCard ? thumbWidth : null,
        onTap: onTap ??
            () {
              YTUtils.expandMiniplayer();
              if (properties.comingFromQueue) {
                final i = this.index;
                if (i == Player.inst.currentIndex.value) {
                  Player.inst.togglePlayPause();
                } else {
                  Player.inst.skipToQueueItem(this.index);
                }
              } else {
                final finalList = reversedList ? mainList.reversed : mainList;
                if (playSingle) {
                  Player.inst.playOrPause(
                    0,
                    [itemToYTIDPlay(finalList.elementAt(this.index))],
                    configs.queueSource,
                  );
                } else {
                  Player.inst.playOrPause(
                    this.index,
                    finalList.map(itemToYTIDPlay),
                    configs.queueSource,
                  );
                }
              }
            },
        height: minimalCard ? null : Dimensions.youtubeCardItemExtent,
        margin: cardMargin(minimalCard),
        bgColor: bgColor ??
            (isCurrentlyPlaying
                ? (properties.comingFromQueue ? CurrentColor.inst.miniplayerColor : CurrentColor.inst.currentColorScheme).withAlpha(140)
                : (context.theme.cardColor.withValues(alpha: cardColorOpacity))),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.0.multipliedRadius),
        ),
        child: Stack(
          children: [
            minimalCard
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children,
                  )
                : Row(
                    children: children,
                  ),
            Positioned(
              bottom: 4.0,
              right: minimalCard ? 2.0 : 12.0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: YTUtils.getVideoCacheStatusIcons(
                  context: context,
                  videoId: videoId,
                  iconsColor: itemsColor5,
                  overrideListens: overrideListens,
                  displayCacheIcons: !minimalCard,
                  fontMultiplier: minimalCard ? minimalCardFontMultiplier : null,
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
                    downloadIndex: downloadIndex,
                    totalLength: downloadTotalLength,
                    streamInfoItem: info,
                    videoId: videoId,
                    channelID: info?.channelId ?? info?.channel.id,
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
            if (topRightWidget != null)
              Positioned(
                top: 0.0,
                right: 0.0,
                child: topRightWidget!,
              ),
            if (fadeOpacity > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: context.theme.cardColor.withValues(alpha: fadeOpacity),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (!minimalCard && configs.horizontalGestures && (properties.allowSwipeLeft || properties.allowSwipeRight)) {
      final plItem = itemToYTIDPlay(item);
      return SwipeQueueAddTile(
        item: plItem,
        dismissibleKey: plItem,
        allowSwipeLeft: properties.allowSwipeLeft,
        allowSwipeRight: properties.allowSwipeRight,
        onAddToPlaylist: (item) => showAddToPlaylistSheet(ids: [videoId], idsNamesLookup: {videoId: videoTitle}),
        child: finalChild,
      );
    }

    return finalChild;
  }
}

extension _StringChecker on String {
  String? nullifyEmpty() {
    if (isEmpty) return null;
    return this;
  }
}
