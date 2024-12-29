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
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:namida/youtube/yt_utils.dart';

class YTHistoryVideoCard extends StatelessWidget {
  final List<Playable> videos;
  final int? day;
  final int index;
  final List<int> overrideListens;
  final PlaylistID? playlistID;
  final bool minimalCard;
  final bool displayTimeAgo;
  final double? thumbnailHeight;
  final double? minimalCardWidth;
  final bool reversedList;
  final String playlistName;
  final bool openMenuOnLongPress;
  final bool fromPlayerQueue;
  final bool draggableThumbnail;
  final bool draggingEnabled;
  final bool showMoreIcon;
  final Widget Function(Color? color)? draggingBarsBuilder;
  final Widget Function(Widget draggingTrigger)? draggingThumbnailBuilder;
  final double cardColorOpacity;
  final double fadeOpacity;
  final bool isImportantInCache;
  final Color? bgColor;
  final bool canHaveDuplicates;
  final Widget? topRightWidget;
  final int? downloadIndex;
  final int? downloadTotalLength;

  const YTHistoryVideoCard({
    super.key,
    required this.videos,
    required this.day,
    required this.index,
    this.overrideListens = const [],
    required this.playlistID,
    this.minimalCard = false,
    this.displayTimeAgo = true,
    this.thumbnailHeight,
    this.minimalCardWidth,
    this.reversedList = false,
    required this.playlistName,
    this.openMenuOnLongPress = true,
    this.fromPlayerQueue = false,
    this.draggableThumbnail = false,
    this.draggingEnabled = false,
    this.showMoreIcon = false,
    this.draggingBarsBuilder,
    this.draggingThumbnailBuilder,
    this.cardColorOpacity = 0.75,
    this.fadeOpacity = 0,
    this.isImportantInCache = true,
    this.bgColor,
    required this.canHaveDuplicates,
    this.topRightWidget,
    this.downloadIndex,
    this.downloadTotalLength,
  });

  @override
  Widget build(BuildContext context) {
    return YTHistoryVideoCardBase(
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
      playlistID: playlistID,
      minimalCard: minimalCard,
      displayTimeAgo: displayTimeAgo,
      thumbnailHeight: thumbnailHeight,
      minimalCardWidth: minimalCardWidth,
      reversedList: reversedList,
      playlistName: playlistName,
      openMenuOnLongPress: openMenuOnLongPress,
      fromPlayerQueue: fromPlayerQueue,
      draggableThumbnail: draggableThumbnail,
      draggingEnabled: draggingEnabled,
      showMoreIcon: showMoreIcon,
      draggingBarsBuilder: draggingBarsBuilder,
      draggingThumbnailBuilder: draggingThumbnailBuilder,
      cardColorOpacity: cardColorOpacity,
      fadeOpacity: fadeOpacity,
      isImportantInCache: isImportantInCache,
      bgColor: bgColor,
      canHaveDuplicates: canHaveDuplicates,
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
  final PlaylistID? playlistID;
  final bool minimalCard;
  final bool displayTimeAgo;
  final double? thumbnailHeight;
  final double? minimalCardWidth;
  final bool reversedList;
  final String playlistName;
  final bool openMenuOnLongPress;
  final bool fromPlayerQueue;
  final bool draggableThumbnail;
  final bool draggingEnabled;
  final bool showMoreIcon;
  final Widget Function(Color? color)? draggingBarsBuilder;
  final Widget Function(Widget draggingTrigger)? draggingThumbnailBuilder;
  final double cardColorOpacity;
  final double fadeOpacity;
  final bool isImportantInCache;
  final Color? bgColor;
  final bool canHaveDuplicates;
  final StreamInfoItem? Function(T item)? info;
  final Widget? topRightWidget;
  final int? downloadIndex;
  final int? downloadTotalLength;
  final bool playSingle;
  final void Function()? onTap;
  final double minimalCardFontMultiplier;

  const YTHistoryVideoCardBase({
    super.key,
    required this.mainList,
    required this.itemToYTVideoId,
    required this.day,
    required this.index,
    this.overrideListens = const [],
    required this.playlistID,
    this.minimalCard = false,
    this.displayTimeAgo = true,
    this.thumbnailHeight,
    this.minimalCardWidth,
    this.reversedList = false,
    required this.playlistName,
    this.openMenuOnLongPress = true,
    this.fromPlayerQueue = false,
    this.draggableThumbnail = false,
    this.draggingEnabled = false,
    this.showMoreIcon = false,
    this.draggingBarsBuilder,
    this.draggingThumbnailBuilder,
    this.cardColorOpacity = 0.75,
    this.fadeOpacity = 0,
    this.isImportantInCache = true,
    this.bgColor,
    required this.canHaveDuplicates,
    required this.info,
    this.topRightWidget,
    this.downloadIndex,
    this.downloadTotalLength,
    this.playSingle = false,
    this.onTap,
    this.minimalCardFontMultiplier = 1.0,
  });

  YoutubeID itemToYTIDPlay(T item) {
    final e = itemToYTVideoId(item);
    return YoutubeID(id: e.$1, watchNull: e.$2, playlistID: playlistID);
  }

  static const minimalCardExtraThumbCropHeight = 6.0;
  static const minimalCardExtraThumbCropWidth = 8.0;
  static EdgeInsets cardMargin(bool minimal) => EdgeInsets.symmetric(horizontal: minimal ? 2.0 : 4.0, vertical: Dimensions.youtubeCardItemVerticalPadding);

  @override
  Widget build(BuildContext context) {
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
    if (displayTimeAgo) {
      final watchMS = videoWatch?.dateMSNull;
      if (watchMS != null) dateText = minimalCard ? Jiffy.parseFromMillisecondsSinceEpoch(watchMS).fromNow() : watchMS.dateAndClockFormattedOriginal;
    }

    final draggingThumbWidget = draggableThumbnail && draggingEnabled
        ? NamidaReordererableListener(
            durationMs: 80,
            index: index,
            child: Container(
              color: Colors.transparent,
              height: thumbHeight * 0.9,
              width: thumbWidth * 0.9, // not fully but better, to avoid accidents
            ),
          )
        : null;

    return NamidaPopupWrapper(
      openOnTap: false,
      openOnLongPress: openMenuOnLongPress,
      childrenDefault: () => YTUtils.getVideoCardMenuItems(
        downloadIndex: downloadIndex,
        totalLength: downloadTotalLength,
        streamInfoItem: info,
        videoId: videoId,
        channelID: info?.channelId ?? info?.channel.id,
        playlistID: playlistID,
        idsNamesLookup: {videoId: info?.title},
        playlistName: playlistName,
        videoYTID: itemToYTIDPlay(item),
      ),
      child: Obx(
        (context) {
          final displayVideoChannel = videoChannel != null && videoChannel.isNotEmpty;
          final displayDateText = dateText != null && dateText.isNotEmpty;

          bool willSleepAfterThis = false;
          if (fromPlayerQueue) {
            final sleepconfig = Player.inst.sleepTimerConfig.valueR;
            if (sleepconfig.enableSleepAfterItems) {
              final repeatMode = settings.player.repeatMode.valueR;
              if (repeatMode == RepeatMode.all || repeatMode == RepeatMode.none) {
                willSleepAfterThis = Player.inst.sleepingItemIndex(sleepconfig.sleepAfterItems, Player.inst.currentIndex.valueR) == index;
              }
            }
          }

          final bool isRightIndex = canHaveDuplicates ? index == Player.inst.currentIndex.valueR : true;
          bool isCurrentlyPlaying = false;

          if (isRightIndex) {
            final curr = Player.inst.currentVideoR;
            if (videoId == curr?.id && videoIdWatch.$2 == curr?.watchNull) isCurrentlyPlaying = true;
          }

          final itemsColor7 = isCurrentlyPlaying ? Colors.white.withOpacity(0.7) : null;
          final itemsColor6 = isCurrentlyPlaying ? Colors.white.withOpacity(0.6) : null;
          final itemsColor5 = isCurrentlyPlaying ? Colors.white.withOpacity(0.5) : null;
          final threeLines = draggableThumbnail ? ThreeLineSmallContainers(enabled: draggingEnabled, color: itemsColor5) : null;
          final children = [
            if (threeLines != null) draggingBarsBuilder?.call(itemsColor5) ?? threeLines,
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
                if (draggingThumbWidget != null) draggingThumbnailBuilder?.call(draggingThumbWidget) ?? draggingThumbWidget
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
          return NamidaInkWell(
            borderRadius: minimalCard ? 8.0 : 10.0,
            width: minimalCard ? thumbWidth : null,
            onTap: onTap ??
                () {
                  YTUtils.expandMiniplayer();
                  if (fromPlayerQueue) {
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
                        QueueSource.others,
                      );
                    } else {
                      Player.inst.playOrPause(
                        this.index,
                        finalList.map(itemToYTIDPlay),
                        QueueSource.others,
                      );
                    }
                  }
                },
            height: minimalCard ? null : Dimensions.youtubeCardItemExtent,
            margin: cardMargin(minimalCard),
            bgColor: bgColor ??
                (isCurrentlyPlaying
                    ? (fromPlayerQueue ? CurrentColor.inst.miniplayerColor : CurrentColor.inst.currentColorScheme).withAlpha(140)
                    : (context.theme.cardColor.withOpacity(cardColorOpacity))),
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
                if (showMoreIcon)
                  Positioned(
                    top: 0.0,
                    right: 0.0,
                    child: NamidaPopupWrapper(
                      childrenDefault: () => YTUtils.getVideoCardMenuItems(
                        downloadIndex: downloadIndex,
                        totalLength: downloadTotalLength,
                        streamInfoItem: info,
                        videoId: videoId,
                        channelID: info?.channelId ?? info?.channel.id,
                        playlistID: playlistID,
                        idsNamesLookup: {videoId: videoTitle},
                        playlistName: playlistName,
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
                        color: context.theme.cardColor.withOpacity(fadeOpacity),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

extension _StringChecker on String {
  String? nullifyEmpty() {
    if (isEmpty) return null;
    return this;
  }
}
