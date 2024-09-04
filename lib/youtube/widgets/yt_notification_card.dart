import 'dart:async';

import 'package:flutter/material.dart';

import 'package:jiffy/jiffy.dart';
import 'package:playlist_manager/module/playlist_id.dart';
import 'package:youtipie/class/result_wrapper/notification_result.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item_notification.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/widgets/yt_shimmer.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:namida/youtube/yt_utils.dart';

class YoutubeVideoCardNotification extends StatefulWidget {
  final StreamInfoItemNotification notification;
  final YoutiPieNotificationResult Function() mainList;
  final int index;
  final PlaylistID? playlistID;
  final double thumbnailWidth;
  final double thumbnailHeight;
  final double fontMultiplier;

  const YoutubeVideoCardNotification({
    super.key,
    required this.notification,
    required this.mainList,
    required this.index,
    this.playlistID,
    required this.thumbnailWidth,
    required this.thumbnailHeight,
    this.fontMultiplier = 1.0,
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

  Future<void> _onTapInternal() async {
    if (widget.notification.isComment) return;

    final mainList = widget.mainList();
    Player.inst.playOrPause(
      mainList.items.length - widget.index - 1,
      mainList.items.reversed.where((element) => !element.isComment).map((e) => YoutubeID(id: e.id, playlistID: null)),
      QueueSource.others,
    );
    YTUtils.expandMiniplayer();
    await _markAsRead(mainList);
  }

  List<NamidaPopupItem> getMenuItems() {
    final mainList = widget.mainList();
    final videoId = widget.notification.id;
    if (videoId.isEmpty) return [];
    if (widget.notification.isComment) return [];
    return YTUtils.getVideoCardMenuItems(
      index: widget.index, // original index
      streamInfoItem: null,
      videoId: videoId,
      url: widget.notification.buildUrl(),
      channelID: null,
      playlistID: widget.playlistID,
      moreMenuChildren: _isNowRead.value == true
          ? null
          : [
              NamidaPopupItem(
                icon: Broken.notification_status,
                title: lang.MARK_AS_READ,
                onTap: () => _markAsRead(mainList),
              ),
            ],
      idsNamesLookup: {videoId: widget.notification.shortText},
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.notification.isRead == true && _isNowRead.value == false) _isNowRead.value = true; // after refreshing response and was read outside

    final thumbnailWidth = this.widget.thumbnailWidth;
    final thumbnailHeight = this.widget.thumbnailHeight;

    final title = widget.notification.shortText;

    DateTime? publishedDate = widget.notification.publishedAt.date;
    final uploadDateAgo = publishedDate == null ? null : Jiffy.parseFromDateTime(publishedDate).fromNow();

    const verticalPadding = 8.0;
    final channelThumbSize = thumbnailWidth * 0.35;
    const shimmerEnabled = false;
    final videoThumbnail = widget.notification.thumbs.pick()?.url;
    final channelThumbnailUrl = widget.notification.uploaderthumbs.pick()?.url;

    final child = Row(
      children: [
        const SizedBox(width: 8.0),
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
                  title,
                  style: context.textTheme.displayMedium?.copyWith(fontSize: 13.0 * widget.fontMultiplier),
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
                  uploadDateAgo ?? '',
                  style: context.textTheme.displaySmall?.copyWith(
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
            type: ThumbnailType.video,
            key: ValueKey(videoThumbnail),
            isImportantInCache: false,
            customUrl: videoThumbnail,
            videoId: widget.notification.id, // just as a backup
            preferLowerRes: true,
            width: thumbnailWidth,
            height: thumbnailHeight,
            borderRadius: 8.0,
          ),
        ),
        NamidaPopupWrapper(
          childrenDefault: getMenuItems,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2.0),
            child: MoreIcon(iconSize: 16.0),
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: verticalPadding * 0.5, horizontal: 8.0),
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
                          color: borderColor ?? Colors.red.withOpacity(0.6),
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
    );
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
