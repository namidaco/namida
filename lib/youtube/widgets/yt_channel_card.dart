import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/pages/yt_channel_subpage.dart';
import 'package:namida/youtube/widgets/yt_shimmer.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';

class YoutubeChannelCard extends StatefulWidget {
  final YoutubeChannel? channel;
  final double? thumbnailSize;
  const YoutubeChannelCard({super.key, required this.channel, this.thumbnailSize});

  @override
  State<YoutubeChannelCard> createState() => _YoutubeChannelCardState();
}

class _YoutubeChannelCardState extends State<YoutubeChannelCard> {
  Color? bgColor;
  @override
  Widget build(BuildContext context) {
    final channel = widget.channel;
    final subscribers = channel?.subscriberCount?.formatDecimalShort();
    final thumbnailSize = widget.thumbnailSize ?? context.width * 0.2;
    const verticalPadding = 8.0;
    final shimmerEnabled = channel == null;
    final avatarUrl = channel?.avatarUrl ?? channel?.thumbnailUrl;
    return NamidaInkWell(
      margin: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      bgColor: bgColor?.withAlpha(100) ?? context.theme.cardColor,
      animationDurationMS: 300,
      borderRadius: 24.0,
      onTap: () {
        final chid = channel?.id;
        if (chid != null) NamidaNavigator.inst.navigateTo(YTChannelSubpage(channelID: chid, channel: channel));
      },
      height: thumbnailSize + verticalPadding,
      child: Row(
        children: [
          SizedBox(width: thumbnailSize * 0.25),
          NamidaDummyContainer(
            width: thumbnailSize,
            height: thumbnailSize,
            shimmerEnabled: shimmerEnabled,
            child: YoutubeThumbnail(
              key: Key("${avatarUrl}_${channel?.id}"),
              compressed: false,
              isImportantInCache: true,
              channelUrl: avatarUrl,
              channelIDForHQImage: channel?.id ?? '',
              width: thumbnailSize,
              height: thumbnailSize,
              borderRadius: 10.0,
              extractColor: true,
              isCircle: true,
              onColorReady: (color) {
                bgColor = color?.color;
                if (mounted) setState(() {});
              },
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
                    channel?.name ?? '',
                    style: context.textTheme.displayLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2.0),
                NamidaDummyContainer(
                  width: context.width,
                  height: 8.0,
                  borderRadius: 4.0,
                  shimmerEnabled: shimmerEnabled,
                  child: Text(
                    subscribers == null ? '' : "${subscribers.toIf('?', '-1')} ${subscribers.length < 2 ? lang.SUBSCRIBER : lang.SUBSCRIBERS}",
                    style: context.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w400),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (channel?.streamCount != null && channel?.streamCount != -1) ...[
                  const SizedBox(height: 2.0),
                  NamidaDummyContainer(
                    width: context.width,
                    height: 8.0,
                    borderRadius: 4.0,
                    shimmerEnabled: shimmerEnabled,
                    child: Text(
                      channel?.streamCount.displayVideoKeyword ?? '',
                      style: context.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w300),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(height: 12.0),
              ],
            ),
          ),
          const SizedBox(width: 24.0),
        ],
      ),
    );
  }
}
