import 'package:flutter/material.dart';

import 'package:nampack/reactive/reactive.dart';
import 'package:youtipie/class/channels/channel_info.dart';
import 'package:youtipie/class/result_wrapper/channel_user_result.dart';
import 'package:youtipie/core/enum.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/class/route.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/pages/youtube_main_page_fetcher_acc_base.dart';
import 'package:namida/youtube/widgets/yt_channel_card.dart';

class YoutubeUserChannelsPage extends StatelessWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.YOUTUBE_USER_CHANNELS_PAGE_HOSTED;

  const YoutubeUserChannelsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const thumbnailHeight = Dimensions.youtubeThumbnailHeight;
    const thumbnailWidth = thumbnailHeight;
    const thumbnailItemExtent = thumbnailWidth + 8.0 * 2;
    return YoutubeMainPageFetcherAccBase<YoutiPieUserChannelsResult, YoutiPieChannelInfo>(
      operation: YoutiPieOperation.fetchUserChannels,
      transparentShimmer: true,
      topPadding: 12.0,
      // onInitState: (wrapper) {
      //   YtUtilsChannel.activeUserChannelsList = wrapper;
      // },
      // onDispose: (wrapper) {
      //   YtUtilsChannel.activeUserChannelsList = null;
      // },
      title: lang.CHANNELS,
      isSortable: true,
      cacheReader: YoutiPie.cacheBuilder.forUserChannels(),
      networkFetcher: (details) => YoutubeInfoController.userchannel.fetchUserChannels(details: details),
      itemExtent: thumbnailItemExtent,
      dummyCard: const _ReactiveChannelCard(
        channel: null,
        thumbnailSize: thumbnailWidth,
      ),
      itemBuilder: (channel, index, list) {
        return _ReactiveChannelCard(
          channel: channel,
          thumbnailSize: thumbnailWidth,
        );
      },
    );
  }
}

class _ReactiveChannelCard extends StatefulWidget {
  final YoutiPieChannelInfo? channel;
  final double thumbnailSize;

  const _ReactiveChannelCard({
    required this.channel,
    required this.thumbnailSize,
  });

  @override
  State<_ReactiveChannelCard> createState() => _ReactiveChannelCardState();
}

class _ReactiveChannelCardState extends State<_ReactiveChannelCard> {
  late final _channelRx = widget.channel.obs;

  @override
  void dispose() {
    _channelRx.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubeChannelCard(
      channel: widget.channel,
      channelRx: _channelRx,
      thumbnailSize: widget.thumbnailSize,
      altDesign: true,
      vMargin: 4.0,
    );
  }
}
