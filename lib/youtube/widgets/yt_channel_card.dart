import 'package:flutter/material.dart';

import 'package:youtipie/class/channels/channel_info.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/class/route.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/pages/yt_channel_subpage.dart';
import 'package:namida/youtube/widgets/yt_shimmer.dart';
import 'package:namida/youtube/widgets/yt_subscribe_buttons.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';

class YoutubeChannelCard extends StatefulWidget {
  final YoutiPieChannelInfo? channel;
  final RxBaseCore<YoutiPieChannelInfo?>? channelRx;
  final double thumbnailSize;
  final double vMargin;
  final bool mininmalCard;
  final bool altDesign;

  const YoutubeChannelCard({
    super.key,
    required this.channel,
    this.channelRx,
    required this.thumbnailSize,
    this.vMargin = 8.0,
    this.mininmalCard = false,
    this.altDesign = false,
  });

  @override
  State<YoutubeChannelCard> createState() => _YoutubeChannelCardState();
}

class _YoutubeChannelCardState extends State<YoutubeChannelCard> {
  Color? bgColor;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final channel = widget.channel;
    final thumbnailSize = widget.thumbnailSize;
    const verticalPadding = 8.0;
    final shimmerEnabled = channel == null;
    final subscribersCount = channel?.subscribersCount;
    final avatarUrl = channel?.thumbnails.pick()?.url;
    // const int? streamsCount = null; // not available with outside [YoutiPieChannelPageResult]
    final mininmalCard = widget.mininmalCard;
    final altDesign = widget.altDesign;

    final thumbnailWidget = NamidaDummyContainer(
      width: thumbnailSize,
      height: thumbnailSize,
      shimmerEnabled: shimmerEnabled,
      isCircle: true,
      child: YoutubeThumbnail(
        type: ThumbnailType.channel,
        key: Key("${avatarUrl}_${channel?.id}"),
        compressed: false,
        isImportantInCache: true,
        customUrl: avatarUrl,
        width: thumbnailSize,
        height: thumbnailSize,
        borderRadius: 10.0,
        extractColor: true,
        isCircle: true,
        forceSquared: false,
        onColorReady: (color) {
          bgColor = color?.color;
          if (mounted) setState(() {});
        },
      ),
    );
    final titleTextWidget = Text(
      channel?.title ?? '',
      style: mininmalCard ? textTheme.displayMedium : textTheme.displayLarge,
      maxLines: mininmalCard ? 1 : 2,
      overflow: TextOverflow.ellipsis,
    );
    final subtitleTextWidget = Text(
      subscribersCount == null ? '' : "${subscribersCount.formatDecimalShort()} ${subscribersCount < 2 ? lang.SUBSCRIBER : lang.SUBSCRIBERS}",
      style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w400),
      maxLines: mininmalCard ? 1 : 2,
      overflow: TextOverflow.ellipsis,
    );
    final dummyMaxWidth = (context.width * 0.3).withMaximum(224.0);
    final dummyMaxWidthSubtitle = dummyMaxWidth * 0.95;
    return NamidaInkWell(
      margin: mininmalCard ? const EdgeInsets.symmetric(horizontal: 4.0) : EdgeInsets.symmetric(horizontal: 24.0, vertical: widget.vMargin),
      bgColor: bgColor?.withOpacityExt(0.12) ?? theme.cardColor,
      animationDurationMS: 300,
      borderRadius: mininmalCard ? 16.0 : 20.0,
      onTap: () {
        final chid = channel?.id;
        if (chid != null) YTChannelSubpage(channelID: chid, channel: channel).navigate();
      },
      height: thumbnailSize + verticalPadding,
      child: mininmalCard
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 6.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  thumbnailWidget,
                  const SizedBox(height: 4.0),
                  titleTextWidget,
                  subtitleTextWidget,
                ],
              ),
            )
          : Row(
              children: [
                SizedBox(width: thumbnailSize * 0.15),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: thumbnailSize * 0.06),
                  child: thumbnailWidget,
                ),
                const SizedBox(width: 8.0),
                if (altDesign) const SizedBox(width: 8.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: altDesign ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 12.0),
                      NamidaDummyContainer(
                        width: dummyMaxWidth,
                        height: 10.0,
                        borderRadius: 4.0,
                        shimmerEnabled: shimmerEnabled,
                        child: titleTextWidget,
                      ),
                      if (shimmerEnabled || subscribersCount != null) ...[
                        const SizedBox(height: 2.0),
                      ],
                      NamidaDummyContainer(
                        width: dummyMaxWidthSubtitle,
                        height: 8.0,
                        borderRadius: 4.0,
                        shimmerEnabled: shimmerEnabled,
                        child: subtitleTextWidget,
                      ),
                      const SizedBox(height: 12.0),
                    ],
                  ),
                ),
                const SizedBox(width: 8.0),
                if (altDesign && widget.channelRx != null && widget.channel != null) ...[
                  YTSubscribeButton(
                    channelID: channel?.id,
                    mainChannelInfo: widget.channelRx!,
                    subscribeTextOnLeft: true,
                    subscribeTextDisplayPolicy: SubscribeTextDisplayPolicy.always,
                  ),
                  const SizedBox(width: 12.0),
                ],
              ],
            ),
    );
  }
}
