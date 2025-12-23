import 'package:flutter/material.dart';

import 'package:youtipie/class/result_wrapper/feed_result.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item_short.dart';
import 'package:youtipie/class/youtipie_feed/playlist_info_item.dart';
import 'package:youtipie/class/youtipie_feed/yt_feed_base.dart';
import 'package:youtipie/core/enum.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/pages/youtube_main_page_fetcher_acc_base.dart';
import 'package:namida/youtube/widgets/yt_history_video_card.dart';
import 'package:namida/youtube/widgets/yt_playlist_card.dart';
import 'package:namida/youtube/widgets/yt_video_card.dart';

class YoutubeHomeFeedPage extends StatelessWidget {
  const YoutubeHomeFeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    const thumbnailHeight = Dimensions.youtubeThumbnailHeight;
    const thumbnailWidth = Dimensions.youtubeThumbnailWidth;
    const thumbnailItemExtent = thumbnailHeight + 8.0 * 2;

    return VideoTilePropertiesProvider(
      configs: VideoTilePropertiesConfigs(
        queueSource: QueueSourceYoutubeID.homeFeed,
        showMoreIcon: true,
      ),
      builder: (properties) => ObxO(
        rx: settings.youtube.ytVisibleShorts,
        builder: (context, visibleShorts) {
          final isShortsVisible = visibleShorts[YTVisibleShortPlaces.homeFeed] ?? true;
          return ObxO(
            rx: settings.youtube.ytVisibleMixes,
            builder: (context, visibleMixes) {
              final isMixesVisible = visibleMixes[YTVisibleMixesPlaces.homeFeed] ?? true;
              return YoutubeMainPageFetcherAccBase<YoutiPieFeedResult, YoutubeFeed>(
                operation: YoutiPieOperation.fetchFeed,
                showRefreshInsteadOfRefreshing: true,
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
                sliverListBuilder: (feed, itemBuilder, dummyCard) {
                  return SliverVariedExtentList.builder(
                    itemExtentBuilder: (index, dimensions) {
                      if (isShortsVisible) {
                        if (feed.shortsSection.relatedItemsShortsData[index] != null) {
                          return 64.0 * 3 + 24.0 * 2;
                        } else if (feed.shortsSection.shortsIndicesLookup[index] == true) {
                          return 0;
                        }
                      }

                      final item = feed.items[index];
                      if (!isShortsVisible && item.isShortContent) return 0;
                      if (!isMixesVisible && item.isMixPlaylist) return 0;
                      return thumbnailItemExtent;
                    },
                    itemCount: feed.items.length,
                    itemBuilder: (context, index) {
                      final shortsData = feed.shortsSection;

                      final shortSection = shortsData.relatedItemsShortsData[index];
                      if (shortSection != null) {
                        if (isShortsVisible == false) return const SizedBox();
                        const height = 64.0 * 3;
                        const width = height * (9 / 16 * 1.2);
                        const hPadding = 4.0;
                        return SizedBox(
                          height: height,
                          child: SuperSmoothListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 24.0 / 6, horizontal: 4.0),
                            scrollDirection: Axis.horizontal,
                            itemExtent: width + hPadding * 2,
                            itemCount: shortSection.length,
                            itemBuilder: (context, index) {
                              final shortIndex = shortSection[index];
                              final short = feed.items[shortIndex] as StreamInfoItemShort;
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: hPadding),
                                child: YoutubeShortVideoTallCard(
                                  queueSource: QueueSourceYoutubeID.homeFeed,
                                  index: index,
                                  short: short,
                                  thumbnailWidth: width,
                                  thumbnailHeight: height,
                                ),
                              );
                            },
                          ),
                        );
                      }
                      if (shortsData.shortsIndicesLookup[index] == true) {
                        return const SizedBox.shrink();
                      }
                      return itemBuilder(feed.items[index], index, feed);
                    },
                  );
                },
                itemBuilder: (item, i, _) {
                  if (!isShortsVisible && item.isShortContent) return const SizedBox.shrink();
                  if (!isMixesVisible && item.isMixPlaylist) return const SizedBox.shrink();

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
                        queueSource: QueueSourceYoutubeID.homeFeed,
                        key: Key("${(item as StreamInfoItemShort?)?.id}"),
                        thumbnailWidth: thumbnailWidth,
                        thumbnailHeight: thumbnailHeight,
                        short: item as StreamInfoItemShort,
                        playlistID: null,
                      ),
                    const (PlaylistInfoItem) => YoutubePlaylistCard(
                        queueSource: QueueSourceYoutubeID.homeFeed,
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
              );
            },
          );
        },
      ),
    );
  }
}
