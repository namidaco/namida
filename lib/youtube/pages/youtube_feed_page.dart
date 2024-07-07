import 'package:flutter/material.dart';
import 'package:youtipie/class/result_wrapper/feed_result.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item_short.dart';
import 'package:youtipie/class/youtipie_feed/playlist_info_item.dart';
import 'package:youtipie/class/youtipie_feed/yt_feed_base.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/core/dimensions.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/youtube/pages/youtube_main_page_fetcher_acc_base.dart';
import 'package:namida/youtube/widgets/yt_playlist_card.dart';
import 'package:namida/youtube/widgets/yt_video_card.dart';

class YoutubeHomeFeedPage extends StatelessWidget {
  const YoutubeHomeFeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    const thumbnailHeight = Dimensions.youtubeThumbnailHeight;
    const thumbnailWidth = Dimensions.youtubeThumbnailWidth;
    const thumbnailItemExtent = thumbnailHeight + 8.0 * 2;

    return YoutubeMainPageFetcherAccBase<YoutiPieFeedResult, YoutubeFeed>(
        transparentShimmer: false,
        title: lang.HOME,
        cacheReader: YoutiPie.cacheBuilder.forFeedItems(),
        networkFetcher: (details) => YoutiPie.feed.fetchFeed(details: details),
        itemExtent: thumbnailItemExtent,
        dummyCard: const YoutubeVideoCardDummy(
          shimmerEnabled: true,
          thumbnailWidth: thumbnailWidth,
          thumbnailHeight: thumbnailHeight,
        ),
        itemBuilder: (item, i, _) {
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
        });
  }
}
