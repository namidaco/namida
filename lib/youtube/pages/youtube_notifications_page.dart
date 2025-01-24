import 'package:flutter/material.dart';

import 'package:youtipie/class/result_wrapper/notification_result.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item_notification.dart';
import 'package:youtipie/core/enum.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/core/dimensions.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/youtube/pages/youtube_main_page_fetcher_acc_base.dart';
import 'package:namida/youtube/widgets/yt_notification_card.dart';

class YoutubeNotificationsPage extends StatelessWidget {
  const YoutubeNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const multiplier = 0.8;
    const thumbnailHeight = multiplier * Dimensions.youtubeThumbnailHeight;
    const thumbnailWidth = multiplier * Dimensions.youtubeThumbnailWidth;
    const thumbnailItemExtent = thumbnailHeight + 8.0 * 2;

    return YoutubeMainPageFetcherAccBase<YoutiPieNotificationResult, StreamInfoItemNotification>(
        operation: YoutiPieOperation.fetchNotifications,
        transparentShimmer: true,
        title: lang.NOTIFICATIONS,
        cacheReader: YoutiPie.cacheBuilder.forNotificationItems(),
        networkFetcher: (details) => YoutiPie.feed.fetchNotifications(details: details),
        itemExtent: thumbnailItemExtent,
        dummyCard: const YoutubeVideoCardNotificationDummy(
          thumbnailWidth: thumbnailWidth,
          thumbnailHeight: thumbnailHeight,
        ),
        itemBuilder: (notification, index, list) {
          return YoutubeVideoCardNotification(
            key: Key(notification.notificationId),
            notification: notification,
            thumbnailWidth: thumbnailWidth,
            thumbnailHeight: thumbnailHeight,
            playlistID: null,
            mainList: () => list,
            index: index,
          );
        });
  }
}
