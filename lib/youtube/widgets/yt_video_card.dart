import 'dart:async';

import 'package:flutter/material.dart';

import 'package:playlist_manager/module/playlist_id.dart';
import 'package:youtipie/class/result_wrapper/playlist_result.dart';
import 'package:youtipie/class/result_wrapper/playlist_result_base.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item_short.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/time_ago_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/functions/yt_playlist_utils.dart';
import 'package:namida/youtube/widgets/yt_card.dart';
import 'package:namida/youtube/widgets/yt_history_video_card.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:namida/youtube/yt_utils.dart';

class YoutubeVideoCard extends StatelessWidget {
  final VideoTileProperties properties;
  final StreamInfoItem video;
  final PlaylistID? playlistID;
  final bool isImageImportantInCache;
  final void Function()? onTap;
  final double? thumbnailWidth;
  final double? thumbnailHeight;
  final YoutiPiePlaylistResultBase? playlist;
  final ({int index, int totalLength, String playlistId})? playlistIndexAndCount;
  final double fontMultiplier;
  final double thumbnailWidthPercentage;
  final bool dateInsteadOfChannel;
  final bool showThirdLine;

  const YoutubeVideoCard({
    super.key,
    required this.properties,
    required this.video,
    required this.playlistID,
    required this.isImageImportantInCache,
    this.onTap,
    this.thumbnailWidth,
    this.thumbnailHeight,
    this.playlist,
    this.playlistIndexAndCount,
    this.fontMultiplier = 1.0,
    this.thumbnailWidthPercentage = 1.0,
    this.dateInsteadOfChannel = false,
    this.showThirdLine = true,
  });

  FutureOr<List<NamidaPopupItem>> getMenuItems() {
    final videoId = video.id;
    return YTUtils.getVideoCardMenuItems(
      queueSource: properties.configs.queueSource,
      downloadIndex: playlistIndexAndCount?.index,
      totalLength: playlistIndexAndCount?.totalLength,
      playlistId: playlistIndexAndCount?.playlistId,
      streamInfoItem: video,
      videoId: videoId,
      channelID: video.channel?.id,
      playlistID: playlistID,
      idsNamesLookup: {videoId: video.title},
      playlistName: playlist?.basicInfo.title ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final videoId = video.id;
    final viewsCount = video.viewsCount;
    String? viewsCountText = video.viewsText;
    if (viewsCount != null) {
      viewsCountText = viewsCount.displayViewsKeywordShort;
    }

    DateTime? publishedDate = video.publishedAt.date;
    final uploadDateAgo = publishedDate == null ? null : TimeAgoController.dateFromNow(publishedDate);

    final percentageWatched = video.percentageWatched;

    final smallBoxText = video.durSeconds?.secondsLabel;
    final firstBadge = smallBoxText == null || smallBoxText.isEmpty ? video.badges?.firstOrNull : null;

    final enableGifThumbnails = settings.youtube.enableGifThumbnails;
    final thumbnailGifUrl = enableGifThumbnails ? video.thumbnailGifUrl : null;
    Widget finalChild = NamidaPopupWrapper(
      openOnTap: false,
      childrenDefault: getMenuItems,
      child: YoutubeCard(
        thumbnailType: ThumbnailType.video,
        thumbnailWidthPercentage: thumbnailWidthPercentage,
        fontMultiplier: fontMultiplier,
        thumbnailWidth: thumbnailWidth,
        thumbnailHeight: thumbnailHeight,
        isImageImportantInCache: isImageImportantInCache,
        borderRadius: 12.0,
        videoId: thumbnailGifUrl != null ? null : videoId,
        thumbnailUrl: thumbnailGifUrl,
        shimmerEnabled: false,
        title: video.title,
        subtitle: [
          if (viewsCountText != null && viewsCountText.isNotEmpty) viewsCountText,
          ?uploadDateAgo,
        ].join(' - '),
        displaythirdLineText: showThirdLine,
        thirdLineText: dateInsteadOfChannel ? video.badges?.join(' - ') ?? '' : video.channelName ?? '',
        displayChannelThumbnail: !dateInsteadOfChannel,
        channelThumbnailUrl: video.channel?.thumbnails.pick()?.url ?? YoutubeInfoController.utils.getVideoChannelThumbnailsSync(videoId, checkFromStorage: false)?.pick()?.url,
        onTap:
            onTap ??
            () async {
              _VideoCardUtils.onVideoTap(
                videoId: videoId,
                index: playlistIndexAndCount?.index,
                playlist: playlist,
                playlistID: playlistID,
                queueSource: properties.configs.queueSource,
              );
            },
        smallBoxText: smallBoxText,
        bottomRightWidgets: YTUtils.getVideoCacheStatusIcons(videoId: videoId, context: context),
        menuChildrenDefault: getMenuItems,
        extractColor: false,
        onTopWidgets: percentageWatched == null && firstBadge == null
            ? null
            : (thumbWidth, thumbHeight, imageColors) => [
                if (percentageWatched != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: SizedBox(
                      height: 1.25,
                      width: thumbWidth * percentageWatched,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color.fromARGB(140, 255, 20, 20),
                        ),
                      ),
                    ),
                  ),
                if (firstBadge != null)
                  Positioned(
                    bottom: 3.0,
                    right: 4.0,
                    child: NamidaInkWell(
                      borderRadius: 5.0,
                      padding: EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.0),
                      bgColor: firstBadge == 'LIVE' ? Color.fromARGB(100, 255, 20, 20) : context.theme.cardColor,
                      child: Icon(
                        Broken.radar_1,
                        size: 14.0,
                        color: Color.fromARGB(222, 222, 222, 222),
                      ),
                    ),
                  ),
              ],
      ),
    );
    if (properties.configs.horizontalGestures && (properties.allowSwipeLeft || properties.allowSwipeRight)) {
      final plItem = YoutubeID(id: videoId, playlistID: playlistID);
      return SwipeQueueAddTile(
        item: plItem,
        infoCallback: () => SwipeQueueAddTileInfo(
          queueSource: properties.configs.queueSource,
          heroTag: null,
        ),
        dismissibleKey: plItem,
        allowSwipeLeft: properties.allowSwipeLeft,
        allowSwipeRight: properties.allowSwipeRight,
        child: finalChild,
      );
    }
    return finalChild;
  }
}

class YoutubeShortVideoCard extends StatelessWidget {
  final QueueSourceYoutubeID queueSource;
  final StreamInfoItemShort short;
  final PlaylistID? playlistID;
  final void Function()? onTap;
  final double? thumbnailWidth;
  final double? thumbnailHeight;
  final YoutiPiePlaylistResult? playlist;
  final int? index;
  final double fontMultiplier;
  final double thumbnailWidthPercentage;

  const YoutubeShortVideoCard({
    super.key,
    required this.queueSource,
    required this.short,
    this.playlistID,
    this.onTap,
    this.thumbnailWidth,
    this.thumbnailHeight,
    this.playlist,
    this.index,
    this.fontMultiplier = 1.0,
    this.thumbnailWidthPercentage = 1.0,
  });

  FutureOr<List<NamidaPopupItem>> getMenuItems() {
    final videoId = short.id;
    return YTUtils.getVideoCardMenuItems(
      queueSource: queueSource,
      downloadIndex: null,
      totalLength: null,
      streamInfoItem: null,
      videoId: videoId,
      channelID: null,
      playlistID: playlistID,
      idsNamesLookup: {videoId: short.title},
      playlistName: playlist?.basicInfo.title ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final String videoId = short.id;
    final String viewsCountText = short.viewsText;

    return NamidaPopupWrapper(
      openOnTap: false,
      childrenDefault: getMenuItems,
      child: YoutubeCard(
        thumbnailType: ThumbnailType.video,
        thumbnailWidthPercentage: thumbnailWidthPercentage,
        fontMultiplier: fontMultiplier,
        thumbnailWidth: thumbnailWidth,
        thumbnailHeight: thumbnailHeight,
        isImageImportantInCache: false,
        borderRadius: 12.0,
        videoId: short.id,
        thumbnailUrl: null,
        shimmerEnabled: false,
        title: short.title,
        subtitle: viewsCountText,
        displaythirdLineText: false,
        thirdLineText: '',
        displayChannelThumbnail: false,
        channelThumbnailUrl: null,
        onTap:
            onTap ??
            () {
              _VideoCardUtils.onVideoTap(
                videoId: videoId,
                index: index,
                playlist: playlist,
                playlistID: playlistID,
                queueSource: queueSource,
                openInFullScreen: true,
              );
            },
        bottomRightWidgets: YTUtils.getVideoCacheStatusIcons(videoId: short.id, context: context),
        menuChildrenDefault: getMenuItems,
      ),
    );
  }
}

class YoutubeShortVideoTallCard extends StatelessWidget {
  final QueueSourceYoutubeID queueSource;
  final int index;
  final StreamInfoItemShort short;
  final double thumbnailWidth;
  final double? thumbnailHeight;

  const YoutubeShortVideoTallCard({
    super.key,
    required this.queueSource,
    required this.index,
    required this.short,
    required this.thumbnailWidth,
    required this.thumbnailHeight,
  });

  FutureOr<List<NamidaPopupItem>> getMenuItems() {
    final videoId = short.id;
    return YTUtils.getVideoCardMenuItems(
      queueSource: queueSource,
      downloadIndex: null,
      totalLength: null,
      streamInfoItem: null,
      videoId: videoId,
      channelID: null,
      playlistID: null,
      idsNamesLookup: {videoId: short.title},
    );
  }

  Future<void> _onShortTap() => _VideoCardUtils.onVideoTap(
    videoId: short.id,
    queueSource: queueSource,
    openInFullScreen: true,
  );

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final videoId = short.id;
    final title = short.title;
    final viewsCountText = short.viewsText;
    final thumbnail = short.liveThumbs.pick()?.url;

    return NamidaPopupWrapper(
      openOnTap: false,
      childrenDefault: getMenuItems,
      child: NamidaInkWell(
        bgColor: context.theme.cardColor,
        borderRadius: 8.0,
        onTap: _onShortTap,
        child: YoutubeThumbnail(
          key: Key(videoId),
          borderRadius: 8.0,
          videoId: videoId,
          customUrl: thumbnail,
          width: thumbnailWidth,
          height: thumbnailHeight,
          isImportantInCache: false,
          type: ThumbnailType.video,
          onTopWidgets: (color) {
            return [
              Positioned(
                bottom: 0,
                left: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                  child: SizedBox(
                    width: thumbnailWidth,
                    height: thumbnailHeight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: textTheme.displayMedium?.copyWith(
                            fontSize: 12.0,
                            color: Colors.white70,
                            shadows: [
                              const BoxShadow(
                                spreadRadius: 1.0,
                                blurRadius: 12.0,
                                color: Colors.black38,
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          viewsCountText,
                          style: textTheme.displaySmall?.copyWith(
                            fontSize: 11.0,
                            color: Colors.white60,
                            shadows: [
                              const BoxShadow(
                                spreadRadius: 1.0,
                                blurRadius: 12.0,
                                color: Colors.black38,
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ];
          },
        ),
      ),
    );
  }
}

class YoutubeVideoCardDummy extends StatelessWidget {
  final double? thumbnailWidth;
  final double? thumbnailHeight;
  final double fontMultiplier;
  final double thumbnailWidthPercentage;
  final bool shimmerEnabled;
  final bool displaythirdLineText;
  final bool dateInsteadOfChannel;

  const YoutubeVideoCardDummy({
    super.key,
    this.thumbnailWidth,
    this.thumbnailHeight,
    this.fontMultiplier = 1.0,
    this.thumbnailWidthPercentage = 1.0,
    required this.shimmerEnabled,
    this.displaythirdLineText = true,
    this.dateInsteadOfChannel = false,
  });

  @override
  Widget build(BuildContext context) {
    return YoutubeCard(
      thumbnailType: ThumbnailType.video,
      thumbnailWidthPercentage: thumbnailWidthPercentage,
      fontMultiplier: fontMultiplier,
      thumbnailWidth: thumbnailWidth,
      thumbnailHeight: thumbnailHeight,
      isImageImportantInCache: false,
      borderRadius: 12.0,
      videoId: null,
      thumbnailUrl: null,
      shimmerEnabled: shimmerEnabled,
      title: '',
      subtitle: '',
      displaythirdLineText: displaythirdLineText,
      thirdLineText: '',
      displayChannelThumbnail: !dateInsteadOfChannel,
      channelThumbnailUrl: null,
    );
  }
}

class _VideoCardUtils {
  static Future<void> onVideoTap({
    required QueueSourceYoutubeID queueSource,
    required String videoId,
    PlaylistID? playlistID,
    int? index,
    YoutiPiePlaylistResultBase? playlist,
    bool openInFullScreen = false,
  }) async {
    YTUtils.expandMiniplayer();
    if (openInFullScreen) {
      VideoController.inst.toggleFullScreenVideoView(isLocal: false, setOrientations: false);
    }
    final gentlePlay = playlist == null ? true : false;
    return Player.inst.playOrPause(
      0,
      [YoutubeID(id: videoId, playlistID: playlistID)],
      queueSource,
      gentlePlay: gentlePlay,
      onAssigningCurrentItem: (currentItem) async {
        // -- add the remaining playlist videos, only if the same item is still playing

        if (playlist != null && index != null) {
          await playlist.basicInfo.fetchAllPlaylistStreams(showProgressSheet: false, playlist: playlist);
          if (currentItem != Player.inst.currentItem.value) return; // nvm if item changed
          if (currentItem is YoutubeID && currentItem.id == videoId) {
            try {
              final firstHalf = playlist.items.getRange(0, index).map((e) => YoutubeID(id: e.id, playlistID: playlistID));
              final lastHalf = playlist.items.getRange(index + 1, playlist.items.length).map((e) => YoutubeID(id: e.id, playlistID: playlistID));

              Player.inst.addToQueue(lastHalf); // adding first bcz inserting would mess up indexes in lastHalf.
              await Player.inst.insertInQueue(firstHalf, 0);
            } catch (e) {
              printo(e, isError: true);
            }
          }
        }
      },
    );
  }
}
