import 'package:flutter/material.dart';

import 'package:youtipie/class/chunks/history_chunk.dart';
import 'package:youtipie/class/publish_time.dart';
import 'package:youtipie/class/result_wrapper/history_result.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item_short.dart';
import 'package:youtipie/class/youtipie_feed/channel_info_item.dart';
import 'package:youtipie/class/youtipie_feed/playlist_info_item.dart';
import 'package:youtipie/core/enum.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/class/route.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/pages/youtube_main_page_fetcher_acc_base.dart';
import 'package:namida/youtube/widgets/yt_history_video_card.dart';
import 'package:namida/youtube/widgets/yt_video_card.dart';

class YoutubeUserHistoryPage extends StatelessWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.YOUTUBE_HISTORY_HOSTED_SUBPAGE;

  final void Function(YoutiPieHistoryResult? result)? onListUpdated;
  const YoutubeUserHistoryPage({super.key, required this.onListUpdated});

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    const multiplier = 1;
    const thumbnailHeight = multiplier * Dimensions.youtubeThumbnailHeight;
    const thumbnailWidth = multiplier * Dimensions.youtubeThumbnailWidth;
    const thumbnailItemExtent = thumbnailHeight + 8.0 * 2;

    const beforeSublistHeight = 24.0;
    const afterSublistHeight = 16.0;

    const dummyCard = YoutubeVideoCardDummy(
      thumbnailWidth: thumbnailWidth,
      thumbnailHeight: thumbnailHeight,
      shimmerEnabled: true,
    );

    return VideoTilePropertiesProvider(
      configs: VideoTilePropertiesConfigs(
        queueSource: QueueSourceYoutubeID.historyHosted,
        showMoreIcon: true,
      ),
      builder: (properties) => ObxO(
        rx: settings.youtube.ytVisibleShorts,
        builder: (context, visibleShorts) {
          final isShortsVisible = visibleShorts[YTVisibleShortPlaces.history] ?? true;
          return YoutubeMainPageFetcherAccBase<YoutiPieHistoryResult, YoutiPieHistoryChunk>(
            operation: YoutiPieOperation.fetchHistory,
            onListUpdated: onListUpdated,
            transparentShimmer: true,
            title: lang.HISTORY,
            cacheReader: YoutiPie.cacheBuilder.forHistoryVideos(),
            networkFetcher: (details) => YoutubeInfoController.history.fetchHistory(details: details),
            itemExtent: thumbnailItemExtent,
            dummyCard: dummyCard,
            itemBuilder: (chunk, index, list) {
              final items = chunk.items;
              int itemsLengthWithoutHiddens = items.length;
              if (!isShortsVisible) itemsLengthWithoutHiddens -= chunk.shortsItemsCount.value;
              if (itemsLengthWithoutHiddens <= 0) return const SizedBox();

              final hasBeforeAndAfterPadding = chunk.title.isNotEmpty;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasBeforeAndAfterPadding)
                    SizedBox(
                      height: beforeSublistHeight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text(
                          chunk.title,
                          style: textTheme.displayMedium,
                        ),
                      ),
                    ),
                  SizedBox(
                    height: itemsLengthWithoutHiddens * thumbnailItemExtent,
                    child: SuperSmoothListView.builder(
                      padding: EdgeInsets.zero,
                      scrollDirection: Axis.vertical,
                      primary: false,
                      physics: const NeverScrollableScrollPhysics(),
                      itemExtent: isShortsVisible ? thumbnailItemExtent : null,
                      // -- we use extent builder only if shorts are hidden
                      itemExtentBuilder: isShortsVisible
                          ? null
                          : (index, dimensions) {
                              final item = items[index];
                              if (item.isShortContent) return 0;
                              return thumbnailItemExtent;
                            },
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        if (!isShortsVisible && item.isShortContent) return const SizedBox.shrink();
                        return switch (item.runtimeType) {
                          const (StreamInfoItem) => YoutubeVideoCard(
                              properties: properties,
                              thumbnailHeight: thumbnailHeight,
                              thumbnailWidth: thumbnailWidth,
                              isImageImportantInCache: false,
                              video: item as StreamInfoItem,
                              playlistID: null,
                            ),
                          const (StreamInfoItemShort) => YoutubeShortVideoCard(
                              queueSource: properties.configs.queueSource,
                              thumbnailHeight: thumbnailHeight,
                              thumbnailWidth: thumbnailWidth,
                              short: item as StreamInfoItemShort,
                              playlistID: null,
                            ),
                          _ => dummyCard,
                        };
                      },
                    ),
                  ),
                  if (hasBeforeAndAfterPadding) const SizedBox(height: afterSublistHeight),
                ],
              );
            },
            sliverListBuilder: (listItems, itemBuilder, dummyCard) => SliverVariedExtentList.builder(
              itemExtentBuilder: (index, dimensions) {
                final chunk = listItems.items[index];
                int itemsLengthWithoutHiddens = chunk.items.length;
                if (!isShortsVisible) itemsLengthWithoutHiddens -= chunk.shortsItemsCount.value;
                if (itemsLengthWithoutHiddens <= 0) return 0;

                final hasBeforeAndAfterPadding = chunk.title.isNotEmpty;
                double itemsExtent = itemsLengthWithoutHiddens * thumbnailItemExtent;
                if (hasBeforeAndAfterPadding) {
                  itemsExtent += beforeSublistHeight;
                  itemsExtent += afterSublistHeight;
                }
                return itemsExtent;
              },
              itemCount: listItems.items.length,
              itemBuilder: (context, index) {
                final chunk = listItems.items[index];
                return itemBuilder(chunk, index, listItems);
              },
            ),
          );
        },
      ),
    );
  }
}

class YoutubeUserHistoryPageHorizontal extends StatelessWidget {
  final GlobalKey? pageKey;
  const YoutubeUserHistoryPageHorizontal({super.key, this.pageKey});

  @override
  Widget build(BuildContext context) {
    const multiplier = 1.0;
    const horizontalHeight = multiplier * Dimensions.youtubeCardItemHeight * 1.6;
    const thumbnailHeight = multiplier * horizontalHeight * 0.6;
    const thumbnailWidth = thumbnailHeight * 16 / 9;
    const thumbnailItemExtent = thumbnailWidth;

    final dummyCard = NamidaInkWell(
      animationDurationMS: 200,
      margin: YTHistoryVideoCardBase.cardMargin(true),
      width: thumbnailWidth,
      height: thumbnailHeight,
      bgColor: context.theme.cardColor,
    );

    const isShortsVisible = false;

    return VideoTilePropertiesProvider(
      configs: VideoTilePropertiesConfigs(
        queueSource: QueueSourceYoutubeID.historyFilteredHosted,
        playlistName: k_PLAYLIST_NAME_HISTORY,
      ),
      builder: (properties) => YoutubeMainPageFetcherAccBase<YoutiPieHistoryResult, YoutiPieHistoryChunk>(
        operation: YoutiPieOperation.fetchHistory,
        key: pageKey,
        isHorizontal: true,
        horizontalHeight: horizontalHeight,
        enablePullToRefresh: false,
        transparentShimmer: true,
        topPadding: 12.0,
        bottomPadding: 32.0,
        title: lang.HISTORY,
        onHeaderTap: YoutubeUserHistoryPage(
          onListUpdated: (result) {
            if (result == null) return;
            (pageKey?.currentState as dynamic)?.updateList(result);
          },
        ).navigate,
        cacheReader: YoutiPie.cacheBuilder.forHistoryVideos(),
        networkFetcher: (details) => YoutubeInfoController.history.fetchHistory(details: details),
        itemExtent: thumbnailItemExtent,
        dummyCard: dummyCard,
        itemBuilder: (chunk, chunkIndex, list) {
          final items = chunk.items;
          int itemsLengthWithoutHiddens = items.length;
          if (!isShortsVisible) itemsLengthWithoutHiddens -= chunk.shortsItemsCount.value;
          if (itemsLengthWithoutHiddens <= 0) return const SizedBox();

          return SizedBox(
            height: horizontalHeight,
            width: itemsLengthWithoutHiddens * thumbnailItemExtent,
            child: SuperSmoothListView.builder(
              padding: EdgeInsets.zero,
              scrollDirection: Axis.horizontal,
              primary: false,
              physics: const NeverScrollableScrollPhysics(),
              itemExtentBuilder: (index, dimensions) {
                final item = items[index];
                if (!isShortsVisible && item.isShortContent) return 0;
                return thumbnailItemExtent;
              },
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                if (!isShortsVisible && item.isShortContent) return const SizedBox.shrink();

                return YTHistoryVideoCardBase(
                  properties: properties,
                  mainList: items,
                  itemToYTVideoId: (e) {
                    if (e is StreamInfoItem) {
                      return (e.id, null);
                    } else if (e is StreamInfoItemShort) {
                      return (e.id, null);
                    } else if (e is ChannelInfoItem) {
                      return (e.id, null);
                    } else if (e is PlaylistInfoItem) {
                      return (e.id, null);
                    }
                    throw Exception('itemToYTID unknown type ${e.runtimeType}');
                  },
                  day: null,
                  index: index,
                  minimalCard: true,
                  info: (item) {
                    if (item is StreamInfoItem) {
                      return item;
                    }
                    if (item is StreamInfoItemShort) {
                      return StreamInfoItem(
                        id: item.id,
                        title: item.title,
                        shortDescription: null,
                        channel: const ChannelInfoItem.anonymous(),
                        thumbnailGifUrl: null,
                        publishedFromText: '',
                        publishedAt: const PublishTime.unknown(),
                        indexInPlaylist: null,
                        durSeconds: null,
                        durText: null,
                        viewsText: item.viewsText,
                        viewsCount: item.viewsCount,
                        percentageWatched: null,
                        liveThumbs: item.liveThumbs,
                        isUploaderVerified: null,
                        badges: null,
                        isActuallyShortContent: true,
                      );
                    }
                    return null;
                  },
                  thumbnailHeight: thumbnailHeight,
                  minimalCardWidth: thumbnailWidth,
                );
              },
            ),
          );
        },
        sliverListBuilder: (listItems, itemBuilder, dummyCard) => SliverVariedExtentList.builder(
          itemExtentBuilder: (index, dimensions) {
            final chunk = listItems.items[index];
            int itemsLengthWithoutHiddens = chunk.items.length;
            if (!isShortsVisible) itemsLengthWithoutHiddens -= chunk.shortsItemsCount.value;
            if (itemsLengthWithoutHiddens <= 0) return 0;
            return itemsLengthWithoutHiddens * thumbnailItemExtent;
          },
          itemCount: listItems.items.length,
          itemBuilder: (context, index) {
            final chunk = listItems.items[index];
            return itemBuilder(chunk, index, listItems);
          },
        ),
      ),
    );
  }
}
