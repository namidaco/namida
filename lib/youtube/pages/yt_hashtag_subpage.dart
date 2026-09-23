import 'package:flutter/material.dart';

import 'package:youtipie/class/result_wrapper/hashtag_result.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item_short.dart';
import 'package:youtipie/class/youtipie_feed/playlist_info_item.dart';
import 'package:youtipie/class/youtipie_feed/yt_feed_base.dart';
import 'package:youtipie/core/enum.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/class/route.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/pages/youtube_main_page_fetcher_acc_base.dart';
import 'package:namida/youtube/widgets/yt_history_video_card.dart';
import 'package:namida/youtube/widgets/yt_playlist_card.dart';
import 'package:namida/youtube/widgets/yt_video_card.dart';

/// [params] is what youtube attaches to a hashtag, it also decides which tab the page lands on.
class YTHashtagSubpage extends StatelessWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.YOUTUBE_HASHTAG_SUBPAGE;

  @override
  String? get name => hashtag;

  final String hashtag;
  final String params;

  const YTHashtagSubpage({
    super.key,
    required this.hashtag,
    required this.params,
  });

  @override
  Widget build(BuildContext context) {
    const thumbnailHeight = Dimensions.youtubeThumbnailHeight;
    const thumbnailWidth = Dimensions.youtubeThumbnailWidth;
    const thumbnailItemExtent = thumbnailHeight + 8.0 * 2;

    final queueSource = QueueSourceYoutubeID.ytHashtag(hashtag);

    return VideoTilePropertiesProvider(
      configs: VideoTilePropertiesConfigs(
        queueSource: queueSource,
        showMoreIcon: true,
      ),
      builder: (properties) => YoutubeMainPageFetcherAccBase<YoutiPieHashtagResult, YoutubeFeed>(
        operation: YoutiPieOperation.fetchHashtag,
        transparentShimmer: false,
        title: hashtag.isEmpty ? lang.hashtag : hashtag,
        cacheReader: YoutiPie.cacheBuilder.forHashtag(params: params),
        networkFetcher: (details) => YoutubeInfoController.hashtag.fetchHashtag(params: params, details: details),
        itemExtent: thumbnailItemExtent,
        dummyCard: const YoutubeVideoCardDummy(
          shimmerEnabled: true,
          thumbnailWidth: thumbnailWidth,
          thumbnailHeight: thumbnailHeight,
        ),
        itemBuilder: (item, index, list) {
          return switch (item.runtimeType) {
            const (StreamInfoItem) => YoutubeVideoCard(
              properties: properties,
              key: Key((item as StreamInfoItem).id),
              thumbnailWidth: thumbnailWidth,
              thumbnailHeight: thumbnailHeight,
              isImageImportantInCache: false,
              video: item,
              playlistID: null,
            ),
            const (StreamInfoItemShort) => YoutubeShortVideoCard(
              queueSource: queueSource,
              key: Key("${(item as StreamInfoItemShort?)?.id}"),
              thumbnailWidth: thumbnailWidth,
              thumbnailHeight: thumbnailHeight,
              short: item as StreamInfoItemShort,
              playlistID: null,
            ),
            const (PlaylistInfoItem) => YoutubePlaylistCard(
              queueSource: queueSource,
              key: Key((item as PlaylistInfoItem).id),
              playlist: item,
              firstVideoID: item.initialVideos.firstOrNull?.id,
              thumbnailWidth: thumbnailWidth,
              thumbnailHeight: thumbnailHeight,
              subtitle: item.subtitle,
              playOnTap: true,
              isMixPlaylist: item.isMix,
            ),
            _ => const YoutubeVideoCardDummy(
              shimmerEnabled: true,
              thumbnailWidth: thumbnailWidth,
              thumbnailHeight: thumbnailHeight,
            ),
          };
        },
      ),
    );
  }
}
