import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:playlist_manager/module/playlist_id.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart';
import 'package:namida/youtube/functions/yt_playlist_utils.dart';
import 'package:namida/youtube/pages/yt_history_page.dart';
import 'package:namida/youtube/pages/yt_playlist_subpage.dart';
import 'package:namida/youtube/widgets/yt_card.dart';
import 'package:namida/youtube/widgets/yt_history_video_card.dart';
import 'package:namida/youtube/yt_utils.dart';

class YoutubePlaylistsView extends StatelessWidget {
  final Iterable<String> idsToAdd;
  final bool displayMenu;
  final double bottomPadding;
  final bool scrollable;
  final bool? minimalView;

  const YoutubePlaylistsView({
    super.key,
    this.idsToAdd = const <String>[],
    this.displayMenu = true,
    this.bottomPadding = 0.0,
    this.scrollable = true,
    this.minimalView,
  });

  Widget _getHorizontalSliverList({
    required String title,
    required IconData icon,
    required Widget viewAllPage,
    required Iterable<YoutubeID> videos,
    required String playlistName,
    required String playlistID,
    required int totalVideosCountInMainList,
    Widget? subHeader,
    EdgeInsets padding = const EdgeInsets.symmetric(vertical: 8.0),
    bool displayTimeAgo = false,
    bool displayShimmer = false,
  }) {
    final finalVideos = videos.toList();
    final remainingVideosCount = totalVideosCountInMainList - finalVideos.length;

    void onTap() => NamidaNavigator.inst.navigateTo(viewAllPage);

    const thumbHeight = 24.0 * 3.2;
    const thumbWidth = thumbHeight * 16 / 9;

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NamidaInkWell(
            margin: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
            padding: padding,
            onTap: () => NamidaNavigator.inst.navigateTo(viewAllPage),
            child: Column(
              children: [
                SearchPageTitleRow(
                  title: title,
                  subtitle: totalVideosCountInMainList.displayVideoKeyword,
                  icon: icon,
                  trailing: const Icon(Broken.arrow_right_3),
                  onPressed: onTap,
                ),
                if (subHeader != null) subHeader,
              ],
            ),
          ),
          SizedBox(
            height: 130.0,
            child: displayShimmer
                ? ShimmerWrapper(
                    shimmerEnabled: true,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                      scrollDirection: Axis.horizontal,
                      itemCount: 10,
                      itemBuilder: (context, index) {
                        return NamidaInkWell(
                          animationDurationMS: 200,
                          margin: const EdgeInsets.symmetric(horizontal: 4.0),
                          width: thumbWidth,
                          bgColor: context.theme.cardColor,
                        );
                      },
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    scrollDirection: Axis.horizontal,
                    itemCount: finalVideos.length + 1,
                    itemBuilder: (context, index) {
                      if (index == finalVideos.length + 1 - 1) {
                        return remainingVideosCount <= 0
                            ? const SizedBox()
                            : NamidaInkWell(
                                onTap: onTap,
                                margin: const EdgeInsets.all(12.0),
                                padding: const EdgeInsets.all(12.0),
                                child: Center(
                                  child: Text(
                                    "+${remainingVideosCount.formatDecimalShort()}",
                                    style: context.textTheme.displayMedium,
                                  ),
                                ),
                              );
                      }
                      return YTHistoryVideoCard(
                        minimalCard: true,
                        videos: finalVideos,
                        index: index,
                        day: null,
                        playlistName: playlistName,
                        playlistID: PlaylistID(id: playlistID),
                        displayTimeAgo: displayTimeAgo,
                        minimalCardWidth: thumbWidth,
                        thumbnailHeight: thumbHeight,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Iterable<YoutubeID> get getHistoryVideos {
    final videos = <String, YoutubeID>{};
    for (final trs in YoutubeHistoryController.inst.historyMap.value.values) {
      trs.loop((e, _) {
        videos[e.id] ??= e;
      });
      if (videos.length >= 50) break;
    }
    return videos.values;
  }

  Iterable<YoutubeID> get getFavouriteVideos {
    final videos = <YoutubeID>[];
    final all = YoutubePlaylistController.inst.favouritesPlaylist.value.tracks;
    for (int i = all.length - 1; i >= 0; i--) {
      videos.add(all[i]);
      if (videos.length >= 50) break;
    }

    return videos;
  }

  @override
  Widget build(BuildContext context) {
    final isMinimalView = minimalView ?? idsToAdd.isNotEmpty;

    return NamidaScrollbar(
      child: CustomScrollView(
        slivers: [
          const SliverPadding(padding: EdgeInsets.only(bottom: 12.0)),
          if (!isMinimalView) ...[
            Obx(
              () {
                YoutubeHistoryController.inst.historyMap.value;
                return _getHorizontalSliverList(
                  title: lang.HISTORY,
                  icon: Broken.refresh,
                  viewAllPage: const YoutubeHistoryPage(),
                  videos: getHistoryVideos,
                  playlistName: k_PLAYLIST_NAME_HISTORY,
                  playlistID: k_PLAYLIST_NAME_HISTORY,
                  displayTimeAgo: true,
                  totalVideosCountInMainList: YoutubeHistoryController.inst.historyTracksLength,
                  displayShimmer: YoutubeHistoryController.inst.isLoadingHistory,
                );
              },
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 8.0)),
            () {
              const page = YTMostPlayedVideosPage();
              return Obx(
                () {
                  YoutubeHistoryController.inst.historyMap.value;
                  return _getHorizontalSliverList(
                    title: lang.MOST_PLAYED,
                    icon: Broken.crown_1,
                    viewAllPage: page,
                    padding: const EdgeInsets.only(top: 8.0),
                    videos: YoutubeHistoryController.inst.currentMostPlayedTracks
                        .map((e) => YoutubeID(
                              id: e,
                              playlistID: const PlaylistID(id: k_PLAYLIST_NAME_MOST_PLAYED),
                            ))
                        .toList(),
                    subHeader: page.getMainWidget(YoutubeHistoryController.inst.currentMostPlayedTracks.toList()).getChipsRow(context),
                    playlistName: '',
                    playlistID: k_PLAYLIST_NAME_MOST_PLAYED,
                    totalVideosCountInMainList: YoutubeHistoryController.inst.currentMostPlayedTracks.length,
                    displayShimmer: YoutubeHistoryController.inst.isLoadingHistory,
                  );
                },
              );
            }(),
            const SliverPadding(padding: EdgeInsets.only(bottom: 8.0)),
            Obx(
              () {
                YoutubePlaylistController.inst.favouritesPlaylist.value;
                return _getHorizontalSliverList(
                  title: lang.LIKED,
                  icon: Broken.like_1,
                  viewAllPage: const YTLikedVideosPage(),
                  videos: getFavouriteVideos,
                  playlistName: k_PLAYLIST_NAME_FAV,
                  playlistID: k_PLAYLIST_NAME_FAV,
                  displayTimeAgo: false,
                  totalVideosCountInMainList: YoutubePlaylistController.inst.favouritesPlaylist.value.tracks.length,
                );
              },
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 8.0)),
          ],
          const SliverPadding(padding: EdgeInsets.only(bottom: 12.0)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
              child: Obx(
                () => SearchPageTitleRow(
                  title: "${lang.PLAYLISTS} - ${YoutubePlaylistController.inst.playlistsMap.length}",
                  icon: Broken.music_library_2,
                  trailing: const SizedBox(),
                ),
              ),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 8.0)),
          Obx(
            () {
              final playlistsMap = YoutubePlaylistController.inst.playlistsMap;
              final playlistsNames = playlistsMap.keys.toList();
              return SliverFixedExtentList.builder(
                itemExtent: Dimensions.youtubeCardItemExtent,
                itemCount: playlistsNames.length,
                itemBuilder: (context, index) {
                  final name = playlistsNames[index];
                  final playlist = playlistsMap[name]!;
                  final menuItems = displayMenu
                      ? YTUtils.getVideosMenuItems(
                          videos: playlist.tracks,
                          playlistName: '',
                          moreItems: [
                            NamidaPopupItem(
                              icon: Broken.trash,
                              title: lang.DELETE_PLAYLIST,
                              onTap: () => playlist.promptDelete(name: playlist.name),
                            ),
                          ],
                        )
                      : <NamidaPopupItem>[];
                  return NamidaPopupWrapper(
                    childrenDefault: menuItems,
                    openOnTap: false,
                    child: Obx(
                      () {
                        final idsExist = idsToAdd.isEmpty ? null : playlist.tracks.firstWhereEff((e) => e.id == idsToAdd.firstOrNull) != null;
                        return YoutubeCard(
                          isImageImportantInCache: true,
                          extractColor: true,
                          thumbnailWidthPercentage: 0.8,
                          videoId: playlist.tracks.firstOrNull?.id,
                          thumbnailUrl: null,
                          shimmerEnabled: false,
                          title: playlist.name,
                          subtitle: playlist.creationDate.dateFormattedOriginal,
                          thirdLineText: playlist.tracks.length.displayVideoKeyword,
                          displayChannelThumbnail: false,
                          channelThumbnailUrl: '',
                          onTap: () {
                            if (idsToAdd.isNotEmpty) {
                              if (idsExist == true) {
                                final indexes = <int>[];
                                playlist.tracks.loop((e, index) {
                                  if (idsToAdd.contains(e.id)) {
                                    indexes.add(index);
                                  }
                                });
                                YoutubePlaylistController.inst.removeTracksFromPlaylist(playlist, indexes);
                              } else {
                                YoutubePlaylistController.inst.addTracksToPlaylist(playlist, idsToAdd);
                              }
                            } else {
                              NamidaNavigator.inst.navigateTo(
                                Obx(() => YTNormalPlaylistSubpage(playlist: YoutubePlaylistController.inst.getPlaylist(playlist.name)!)),
                              );
                            }
                          },
                          smallBoxText: playlist.tracks.length.formatDecimal(),
                          checkmarkStatus: idsExist,
                          menuChildrenDefault: menuItems,
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
          if (!isMinimalView) kBottomPaddingWidgetSliver,
        ],
      ),
    );
  }
}
