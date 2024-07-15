import 'package:flutter/material.dart';
import 'package:youtipie/class/result_wrapper/playlist_user_result.dart';
import 'package:youtipie/class/youtipie_feed/playlist_info_item_user.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/core/dimensions.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/pages/youtube_main_page_fetcher_acc_base.dart';
import 'package:namida/youtube/pages/youtube_user_history_page.dart';
import 'package:namida/youtube/widgets/yt_playlist_card.dart';
import 'package:namida/youtube/widgets/yt_video_card.dart';

class YoutubeUserPlaylistsPage extends StatelessWidget {
  const YoutubeUserPlaylistsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const multiplier = 0.8;
    const thumbnailHeight = multiplier * Dimensions.youtubeThumbnailHeight;
    const thumbnailWidth = multiplier * Dimensions.youtubeThumbnailWidth;
    const thumbnailItemExtent = thumbnailHeight + 8.0 * 2;
    final horizontalHistoryKey = GlobalKey();
    final horizontalHistory = YoutubeUserHistoryPageHorizontal(pageKey: horizontalHistoryKey);
    return YoutubeMainPageFetcherAccBase<YoutiPieUserPlaylistsResult, PlaylistInfoItemUser>(
        transparentShimmer: true,
        topPadding: 12.0,
        pageHeader: horizontalHistory,
        onPullToRefresh: () => (horizontalHistoryKey.currentState as dynamic)?.forceFetchFeed() as Future<void>,
        title: lang.PLAYLISTS,
        cacheReader: YoutiPie.cacheBuilder.forUserPlaylists(),
        networkFetcher: (details) => YoutubeInfoController.userplaylist.getUserPlaylists(details: details),
        itemExtent: thumbnailItemExtent,
        dummyCard: const YoutubeVideoCardDummy(
          thumbnailWidth: thumbnailWidth,
          thumbnailHeight: thumbnailHeight,
          shimmerEnabled: true,
        ),
        itemBuilder: (playlist, index, list) {
          return YoutubePlaylistCard(
            key: Key(playlist.id),
            playlist: playlist,
            subtitle: playlist.infoTexts?.firstOrNull, // the second text is mostly like 'updated today' etc
            thumbnailWidth: thumbnailWidth,
            thumbnailHeight: thumbnailHeight,
            firstVideoID: null,
            isMixPlaylist: false, // TODO: is it possible?
            playingId: null,
            playOnTap: false,
          );
        });
  }
}
