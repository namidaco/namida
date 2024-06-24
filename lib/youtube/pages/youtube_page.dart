import 'package:flutter/material.dart';
import 'package:namida/core/dimensions.dart';

import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/widgets/yt_playlist_card.dart';
import 'package:namida/youtube/widgets/yt_video_card.dart';
import 'package:youtipie/class/youtipie_feed/playlist_info_item.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item_short.dart';
import 'package:youtipie/class/youtipie_feed/yt_feed_base.dart';

class YoutubePage extends StatefulWidget {
  const YoutubePage({super.key});

  @override
  State<YoutubePage> createState() => _YoutubePageState();
}

class _YoutubePageState extends State<YoutubePage> with AutomaticKeepAliveClientMixin<YoutubePage> {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    YoutubeInfoController.current.prepareFeed();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    const thumbnailHeight = Dimensions.youtubeThumbnailHeight;
    const thumbnailWidth = Dimensions.youtubeThumbnailWidth;
    const thumbnailItemExtent = thumbnailHeight + 8.0 * 2;
    return BackgroundWrapper(
      child: ObxO(
        rx: YoutubeController.inst.homepageFeed,
        builder: (homepageFeed) {
          final feed = homepageFeed.isEmpty ? List<YoutubeFeed?>.filled(10, null) : homepageFeed;

          if (feed.isNotEmpty && feed.first == null) {
            return ShimmerWrapper(
              transparent: false,
              shimmerEnabled: true,
              child: ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: feed.length,
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  return const YoutubeVideoCardDummy(
                    shimmerEnabled: true,
                    thumbnailWidth: thumbnailWidth,
                    thumbnailHeight: thumbnailHeight,
                  );
                },
              ),
            );
          }
          return NamidaListView(
            // padding: const EdgeInsets.only(top: 32.0, bottom: kBottomPadding),
            header: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                lang.HOME,
                style: context.textTheme.displayLarge?.copyWith(fontSize: 38.0),
              ),
            ),
            itemBuilder: (context, i) {
              final item = feed[i];

              return switch (item.runtimeType) {
                const (StreamInfoItem) => YoutubeVideoCard(
                    key: Key((item as StreamInfoItem).id),
                    thumbnailWidth: thumbnailWidth,
                    thumbnailHeight: thumbnailHeight,
                    isImageImportantInCache: false,
                    video: item,
                    playlistID: null,
                  ),
                const (StreamInfoItemShort) => YoutubeShortVideoCard(
                    key: Key("${(item as StreamInfoItemShort?)?.id}"),
                    thumbnailWidth: thumbnailWidth,
                    thumbnailHeight: thumbnailHeight,
                    short: item as StreamInfoItemShort,
                    playlistID: null,
                  ),
                const (PlaylistInfoItem) => YoutubePlaylistCard(
                    key: Key((item as PlaylistInfoItem).id),
                    playlist: item,
                    thumbnailWidth: thumbnailWidth,
                    thumbnailHeight: thumbnailHeight,
                    subtitle: item.subtitle,
                    playOnTap: true,
                  ),
                _ => const YoutubeVideoCardDummy(
                    shimmerEnabled: true,
                    thumbnailWidth: thumbnailWidth,
                    thumbnailHeight: thumbnailHeight,
                  ),
              };
            },
            itemCount: feed.length,
            itemExtent: thumbnailItemExtent,
          );
        },
      ),
    );
  }
}
