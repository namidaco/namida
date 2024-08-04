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
import 'package:namida/youtube/widgets/yt_thumbnail.dart';

class YoutubeChannelCard extends StatefulWidget {
  final YoutiPieChannelInfo? channel;
  final double thumbnailSize;

  const YoutubeChannelCard({
    super.key,
    required this.channel,
    required this.thumbnailSize,
  });

  @override
  State<YoutubeChannelCard> createState() => _YoutubeChannelCardState();
}

class _YoutubeChannelCardState extends State<YoutubeChannelCard> {
  Color? bgColor;

  @override
  Widget build(BuildContext context) {
    final channel = widget.channel;
    final thumbnailSize = widget.thumbnailSize;
    const verticalPadding = 8.0;
    final shimmerEnabled = channel == null;
    final subscribersCount = channel?.subscribersCount;
    final avatarUrl = channel?.thumbnails.pick()?.url;
    // const int? streamsCount = null; // not available with outside [YoutiPieChannelPageResult]
    return NamidaInkWell(
      margin: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      bgColor: bgColor?.withAlpha(100) ?? context.theme.cardColor,
      animationDurationMS: 300,
      borderRadius: 20.0,
      onTap: () {
        final chid = channel?.id;
        if (chid != null) YTChannelSubpage(channelID: chid, channel: channel).navigate();
      },
      height: thumbnailSize + verticalPadding,
      child: Row(
        children: [
          SizedBox(width: thumbnailSize * 0.15),
          Padding(
            padding: EdgeInsets.symmetric(vertical: thumbnailSize * 0.06),
            child: NamidaDummyContainer(
              width: thumbnailSize,
              height: thumbnailSize,
              shimmerEnabled: shimmerEnabled,
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
            ),
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 12.0),
                NamidaDummyContainer(
                  width: context.width,
                  height: 10.0,
                  borderRadius: 4.0,
                  shimmerEnabled: shimmerEnabled,
                  child: Text(
                    channel?.title ?? '',
                    style: context.textTheme.displayLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (subscribersCount != null) ...[
                  const SizedBox(height: 2.0),
                ],
                NamidaDummyContainer(
                  width: context.width,
                  height: 8.0,
                  borderRadius: 4.0,
                  shimmerEnabled: shimmerEnabled,
                  child: Text(
                    subscribersCount == null ? '' : "${subscribersCount.formatDecimalShort()} ${subscribersCount < 2 ? lang.SUBSCRIBER : lang.SUBSCRIBERS}",
                    style: context.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w400),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 12.0),
              ],
            ),
          ),
          const SizedBox(width: 8.0),
        ],
      ),
    );
  }
}
