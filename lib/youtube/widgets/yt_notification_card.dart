import 'dart:async';

import 'package:flutter/material.dart';

import 'package:playlist_manager/module/playlist_id.dart';
import 'package:youtipie/class/result_wrapper/notification_result.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item_notification.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/class/route.dart';
import 'package:namida/controller/time_ago_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/pages/youtube_notification_comments_page.dart';
import 'package:namida/youtube/pages/yt_channel_subpage.dart';
import 'package:namida/youtube/widgets/yt_history_video_card.dart';
import 'package:namida/youtube/widgets/yt_shimmer.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:namida/youtube/yt_utils.dart';

class YoutubeVideoCardNotification extends StatefulWidget {
  final VideoTileProperties properties;
  final StreamInfoItemNotification notification;
  final YoutiPieNotificationResult Function() mainList;
  final int index;
  final PlaylistID? playlistID;
  final double thumbnailWidth;
  final double thumbnailHeight;
  final double fontMultiplier;
  final bool canOpenComments;

  const YoutubeVideoCardNotification({
    super.key,
    required this.properties,
    required this.notification,
    required this.mainList,
    required this.index,
    this.playlistID,
    required this.thumbnailWidth,
    required this.thumbnailHeight,
    this.fontMultiplier = 1.0,
    this.canOpenComments = true,
  });

  @override
  State<YoutubeVideoCardNotification> createState() => _YoutubeVideoCardNotificationState();
}

class _YoutubeVideoCardNotificationState extends State<YoutubeVideoCardNotification> {
  final _borderColor = Rxn<Color>();
  final _isNowRead = Rxn<bool>();
  late final bool shouldExtractColor;

  @override
  void initState() {
    final isRead = widget.notification.isRead;
    shouldExtractColor = isRead != true;
    _isNowRead.value = isRead;
    super.initState();
  }

  @override
  void dispose() {
    _borderColor.close();
    _isNowRead.close();
    super.dispose();
  }

  Future<void> _markAsRead(YoutiPieNotificationResult mainList) async {
    final marked = await YoutubeInfoController.notificationsAction.markNotficationRead(
      mainList: mainList,
      notification: widget.notification,
    );
    if (marked == true) _isNowRead.value = true;
  }

  void _openCommentsPage() {
    YoutubeNotificationCommentsPage(
      notification: widget.notification,
      mainNotificationsList: widget.mainList,
      index: widget.index,
      thumbnailWidth: widget.thumbnailWidth,
      thumbnailHeight: widget.thumbnailHeight,
    ).navigate();
  }

  Future<void> _onTapInternal() async {
    final mainList = widget.mainList();
    if (widget.notification.isComment) {
      if (!widget.canOpenComments) return;
      _openCommentsPage();
    } else {
      mainList.playNotifications(startAtIndex: widget.index);
    }
    await _markAsRead(mainList);
  }

  FutureOr<List<NamidaPopupItem>> getMenuItems() async {
    final mainList = widget.mainList();
    final videoId = widget.notification.id;
    final isComment = widget.notification.isComment;

    // -- the video menu resolves its own channel, notifications carry none.
    final channelID = isComment && videoId.isNotEmpty ? await YoutubeInfoController.utils.getVideoChannelID(videoId) : null;

    final moreMenuChildren = [
      if (isComment) ...[
        NamidaPopupItem(
          icon: Broken.export_2,
          title: lang.open,
          onTap: _openCommentsPage,
        ),
        if (channelID != null && channelID.isNotEmpty)
          NamidaPopupItem(
            icon: Broken.user,
            title: lang.goToChannel,
            onTap: () => YTChannelSubpage(channelID: channelID).navigate(),
          ),
      ],
      if (_isNowRead.value != true)
        NamidaPopupItem(
          icon: Broken.notification_status,
          title: lang.markAsRead,
          onTap: () => _markAsRead(mainList),
        ),
    ];
    if (videoId.isEmpty || isComment) {
      return moreMenuChildren;
    }

    return YTUtils.getVideoCardMenuItems(
      queueSource: QueueSourceYoutubeID.ytNotificationsHosted,
      downloadIndex: null,
      totalLength: null,
      streamInfoItem: null,
      videoId: videoId,
      channelID: null,
      playlistID: widget.playlistID,
      moreMenuChildren: moreMenuChildren,
      idsNamesLookup: {videoId: widget.notification.shortText},
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;

    if (widget.notification.isRead == true && _isNowRead.value == false) _isNowRead.value = true; // after refreshing response and was read outside

    final thumbnailWidth = this.widget.thumbnailWidth;
    final thumbnailHeight = this.widget.thumbnailHeight;

    DateTime? publishedDate = widget.notification.publishedAt.date;
    final uploadDateAgo = publishedDate == null ? null : TimeAgoController.dateFromNow(publishedDate);

    String firstLine;
    String secondLine;

    final possibleInfo = widget.notification.possibleInfo;
    if (possibleInfo != null && possibleInfo.channelTitle.isNotEmpty) {
      firstLine = possibleInfo.title;
      secondLine = [possibleInfo.channelTitle, uploadDateAgo].joinText(separator: ' - ');
    } else {
      firstLine = widget.notification.shortText;
      secondLine = uploadDateAgo ?? '';
    }

    const verticalPadding = 8.0;
    final channelThumbSize = thumbnailWidth * 0.35;
    const shimmerEnabled = false;
    final videoThumbnail = widget.notification.thumbs.pick()?.url;
    final channelThumbnailUrl = widget.notification.uploaderthumbs.pick()?.url;

    final isComment = widget.notification.isComment;
    final badgeSize = channelThumbSize * 0.35;

    final child = Row(
      children: [
        const SizedBox(width: 8.0),
        Stack(
          clipBehavior: Clip.none,
          alignment: AlignmentDirectional.bottomEnd,
          children: [
            NamidaDummyContainer(
              width: channelThumbSize,
              height: channelThumbSize,
              shimmerEnabled: false,
              child: YoutubeThumbnail(
                type: ThumbnailType.channel,
                key: ValueKey(channelThumbnailUrl),
                isImportantInCache: false,
                customUrl: channelThumbnailUrl,
                width: channelThumbSize,
                isCircle: true,
                extractColor: shouldExtractColor,
                onColorReady: (color) {
                  _borderColor.value = color?.color;
                },
              ),
            ),
            if (isComment)
              Positioned(
                bottom: -3.0,
                right: -3.0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.scaffoldBackgroundColor,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: Icon(
                      widget.notification.isCommentReply ? Broken.messages_1 : Broken.message_text,
                      size: badgeSize,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 8.0),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              NamidaDummyContainer(
                width: context.width,
                height: 10.0,
                borderRadius: 4.0,
                shimmerEnabled: false,
                child: Text(
                  firstLine,
                  style: textTheme.displayMedium?.copyWith(fontSize: 13.0 * widget.fontMultiplier),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 2.0),
              NamidaDummyContainer(
                width: context.width,
                height: 8.0,
                borderRadius: 4.0,
                shimmerEnabled: false,
                child: Text(
                  secondLine,
                  style: textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w400,
                    fontSize: 13.0 * widget.fontMultiplier,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6.0),
        NamidaDummyContainer(
          width: thumbnailWidth,
          height: thumbnailHeight,
          shimmerEnabled: shimmerEnabled,
          child: YoutubeThumbnail(
            type: widget.notification.isComment ? ThumbnailType.comment : ThumbnailType.video,
            key: ValueKey(videoThumbnail),
            isImportantInCache: false,
            customUrl: videoThumbnail,
            videoId: widget.notification.id, // just as a backup. note: the id might be weird like `community?lb=UgkxpUHPp...`
            preferLowerRes: true,
            width: thumbnailWidth,
            height: thumbnailHeight,
            borderRadius: 8.0,
          ),
        ),
        NamidaPopupWrapper(
          childrenDefault: getMenuItems,
          child: const MoreIcon(
            iconSize: 16.0,
            padding: 2.0,
          ),
        ),
      ],
    );

    final finalChild = Padding(
      padding: const EdgeInsets.symmetric(vertical: verticalPadding * 0.5, horizontal: 8.0),
      child: NamidaHero(
        tag: widget.notification.notificationId,
        enabled: widget.notification.isComment && !widget.notification.isCommentReply, // replies page covers it right away
        child: NamidaPopupWrapper(
          openOnTap: false,
          childrenDefault: getMenuItems,
          child: ObxO(
            rx: _isNowRead,
            builder: (context, isNowRead) => ObxO(
              rx: _borderColor,
              builder: (context, borderColor) => NamidaInkWell(
                animationDurationMS: 100,
                decoration: BoxDecoration(
                  border: isNowRead == false
                      ? Border(
                          left: BorderSide(
                            width: 2.0,
                            color: borderColor ?? Colors.red.withOpacityExt(0.6),
                          ),
                        )
                      : null,
                ),
                borderRadius: 12.0,
                onTap: _onTapInternal,
                height: thumbnailHeight + verticalPadding,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );

    final properties = widget.properties;
    if (properties.configs.horizontalGestures && (properties.allowSwipeLeft || properties.allowSwipeRight)) {
      var videoId = widget.notification.id;
      final plItem = YoutubeID(id: videoId, playlistID: null);
      return SwipeQueueAddTile(
        item: plItem,
        infoCallback: () => SwipeQueueAddTileInfo(
          queueSource: QueueSourceYoutubeID.ytNotificationsHosted,
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

class YoutubeVideoCardNotificationDummy extends StatelessWidget {
  final double? thumbnailWidth;
  final double? thumbnailHeight;
  const YoutubeVideoCardNotificationDummy({super.key, this.thumbnailWidth, this.thumbnailHeight});

  @override
  Widget build(BuildContext context) {
    final thumbnailWidth = this.thumbnailWidth ?? Dimensions.youtubeThumbnailHeight;
    const verticalPadding = 8.0;
    final channelThumbSize = thumbnailWidth * 0.35;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: verticalPadding * 0.5, horizontal: 8.0),
      child: Row(
        children: [
          const SizedBox(width: 8.0),
          NamidaDummyContainer(
            width: channelThumbSize,
            height: channelThumbSize,
            shimmerEnabled: true,
            isCircle: true,
            child: null,
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                NamidaDummyContainer(
                  width: context.width,
                  height: 10.0,
                  borderRadius: 4.0,
                  shimmerEnabled: true,
                  child: null,
                ),
                const SizedBox(height: 4.0),
                NamidaDummyContainer(
                  width: context.width * 0.2,
                  height: 8.0,
                  borderRadius: 4.0,
                  shimmerEnabled: true,
                  child: null,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6.0),
          NamidaDummyContainer(
            width: thumbnailWidth,
            height: thumbnailHeight,
            shimmerEnabled: true,
            child: null,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2.0),
            child: SizedBox(width: 16.0),
          ),
        ],
      ),
    );
  }
}
