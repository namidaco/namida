import 'package:flutter/material.dart';

import 'package:youtipie/class/result_wrapper/notification_result.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item_notification.dart';
import 'package:youtipie/core/enum.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/youtube_settings.dart';
import 'package:namida/youtube/pages/youtube_main_page_fetcher_acc_base.dart';
import 'package:namida/youtube/widgets/yt_history_video_card.dart';
import 'package:namida/youtube/widgets/yt_notification_card.dart';
import 'package:namida/youtube/yt_utils.dart';

class YoutubeNotificationsPage extends StatefulWidget {
  const YoutubeNotificationsPage({super.key});

  @override
  State<YoutubeNotificationsPage> createState() => _YoutubeNotificationsPageState();
}

class _YoutubeNotificationsPageState extends State<YoutubeNotificationsPage> {
  final _pageKey = GlobalKey();

  YoutubeMainPageFetcherActions<YoutiPieNotificationResult>? get _pageActions => _pageKey.currentState as YoutubeMainPageFetcherActions<YoutiPieNotificationResult>?;

  void _onPlayAllUnread() => _pageActions?.currentList?.playNotifications(unreadOnly: true);

  void _showFlagsDialog() {
    NamidaNavigator.inst.navigateDialog(
      dialog: CustomBlurryDialog(
        icon: Broken.flag,
        title: lang.configure,
        normalTitleStyle: true,
        horizontalInset: 32.0,
        actions: const [
          DoneButton(),
        ],
        child: YoutubeSettings.getNotificationsExtractorFlagWidget(
          afterChanged: () {
            _pageActions?.forceFetchFeed();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const multiplier = 0.8;
    const thumbnailHeight = multiplier * Dimensions.youtubeThumbnailHeight;
    const thumbnailWidth = multiplier * Dimensions.youtubeThumbnailWidth;
    const thumbnailItemExtent = thumbnailHeight + 8.0 * 2;

    return VideoTilePropertiesProvider(
      configs: const VideoTilePropertiesConfigs(
        queueSource: QueueSourceYoutubeID.ytNotificationsHosted,
      ),
      builder: (properties) => YoutubeMainPageFetcherAccBase<YoutiPieNotificationResult, StreamInfoItemNotification>(
        key: _pageKey,
        operation: YoutiPieOperation.fetchNotifications,
        transparentShimmer: true,
        title: lang.notifications,
        headerTrailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            NamidaIconButton(
              horizontalPadding: 8.0,
              icon: Broken.play_circle,
              iconColor: context.defaultIconColor(),
              tooltip: () => lang.playAll,
              onPressed: _onPlayAllUnread,
            ),
            const SizedBox(width: 2.0),
            NamidaIconButton(
              horizontalPadding: 8.0,
              icon: Broken.setting_4,
              iconColor: context.defaultIconColor(),
              tooltip: () => lang.configure,
              onPressed: _showFlagsDialog,
            ),
          ],
        ),
        cacheReader: YoutiPie.cacheBuilder.forNotificationItems(),
        networkFetcher: (details) => YoutiPie.feed.fetchNotifications(
          details: details,
          useNewExtractor: settings.youtube.useNewNotificationExtractor.valueF,
        ),
        itemExtent: thumbnailItemExtent,
        dummyCard: const YoutubeVideoCardNotificationDummy(
          thumbnailWidth: thumbnailWidth,
          thumbnailHeight: thumbnailHeight,
        ),
        itemBuilder: (notification, index, list) {
          return YoutubeVideoCardNotification(
            properties: properties,
            key: Key(notification.notificationId),
            notification: notification,
            thumbnailWidth: thumbnailWidth,
            thumbnailHeight: thumbnailHeight,
            playlistID: null,
            mainList: () => list,
            index: index,
            onRemoved: () => _pageActions?.refreshList(),
          );
        },
      ),
    );
  }
}
