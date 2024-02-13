import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jiffy/jiffy.dart';
import 'package:playlist_manager/module/playlist_id.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/controller/youtube_import_controller.dart';
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

  List<YoutubeID> get getFavouriteVideos {
    final videos = <YoutubeID>[];
    final all = YoutubePlaylistController.inst.favouritesPlaylist.value.tracks;
    for (int i = all.length - 1; i >= 0; i--) {
      videos.add(all[i]);
      if (videos.length >= 50) break;
    }

    return videos;
  }

  List<NamidaPopupItem> getMenuItems(YoutubePlaylist playlist) {
    return displayMenu
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
                return _HorizontalSliverList(
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
                  return _HorizontalSliverList(
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
                    listensMap: YoutubeHistoryController.inst.currentTopTracksMapListens,
                  );
                },
              );
            }(),
            const SliverPadding(padding: EdgeInsets.only(bottom: 8.0)),
            Obx(
              () {
                YoutubePlaylistController.inst.favouritesPlaylist.value;
                return _HorizontalSliverList(
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
              child: Row(
                children: [
                  Expanded(
                    child: Obx(
                      () => SearchPageTitleRow(
                        title: "${lang.PLAYLISTS} - ${YoutubePlaylistController.inst.playlistsMap.length}",
                        icon: Broken.music_library_2,
                        trailing: const SizedBox(),
                        subtitleWidget: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            NamidaPopupWrapper(
                              useRootNavigator: false,
                              children: () => [
                                Obx(
                                  () {
                                    final playlistSort = settings.ytPlaylistSort.value;
                                    return Column(
                                      children: [
                                        ListTileWithCheckMark(
                                          active: settings.ytPlaylistSortReversed.value,
                                          onTap: () => YoutubePlaylistController.inst.sortYTPlaylists(reverse: !settings.ytPlaylistSortReversed.value),
                                        ),
                                        ...[
                                          GroupSortType.title,
                                          GroupSortType.creationDate,
                                          GroupSortType.modifiedDate,
                                          GroupSortType.numberOfTracks,
                                          GroupSortType.shuffle,
                                        ].map(
                                          (e) => SmallListTile(
                                            title: e.toText(),
                                            active: playlistSort == e,
                                            onTap: () => YoutubePlaylistController.inst.sortYTPlaylists(sortBy: e),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                              child: NamidaInkWell(
                                child: Obx(
                                  () => Text(
                                    settings.ytPlaylistSort.value.toText(),
                                    style: context.textTheme.displaySmall?.copyWith(
                                      color: context.theme.colorScheme.secondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4.0),
                            NamidaInkWell(
                              onTap: () {
                                YoutubePlaylistController.inst.sortYTPlaylists(reverse: !settings.ytPlaylistSortReversed.value);
                              },
                              child: Obx(
                                () => Icon(
                                  settings.ytPlaylistSortReversed.value ? Broken.arrow_up_3 : Broken.arrow_down_2,
                                  size: 16.0,
                                  color: context.theme.colorScheme.secondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4.0),
                  Obx(
                    () => NamidaInkWellButton(
                      icon: Broken.add_circle,
                      text: lang.IMPORT,
                      enabled: !YoutubeImportController.inst.isImportingPlaylists.value,
                      onTap: () async {
                        showSystemToast(message: 'choose playlist directory from a google takeout');
                        final dirPath = await FilePicker.platform.getDirectoryPath();
                        if (dirPath != null) {
                          final imported = await YoutubeImportController.inst.importPlaylists(dirPath);
                          if (imported > 0) {
                            snackyy(message: lang.IMPORTED_N_PLAYLISTS_SUCCESSFULLY.replaceFirst('_NUM_', '$imported'));
                          } else {
                            snackyy(message: "Failed to import\nPlease choose a valid playlists directory taken from google takeout", isError: true);
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 4.0),
                ],
              ),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 8.0)),
          Obx(
            () {
              final playlistsMap = YoutubePlaylistController.inst.playlistsMap;
              final playlistsNames = playlistsMap.keys.toList();
              return SliverFixedExtentList.builder(
                itemExtent: Dimensions.youtubeCardItemExtent * 0.9,
                itemCount: playlistsNames.length,
                itemBuilder: (context, index) {
                  final name = playlistsNames[index];
                  final playlist = playlistsMap[name]!;
                  return NamidaPopupWrapper(
                    childrenDefault: () => getMenuItems(playlist),
                    openOnTap: false,
                    child: Obx(
                      () {
                        final idsExist = idsToAdd.isEmpty ? null : playlist.tracks.firstWhereEff((e) => e.id == idsToAdd.firstOrNull) != null;
                        return YoutubeCard(
                          isImageImportantInCache: true,
                          extractColor: true,
                          thumbnailWidthPercentage: 0.75,
                          videoId: playlist.tracks.firstOrNull?.id,
                          thumbnailUrl: null,
                          shimmerEnabled: false,
                          title: playlist.name,
                          subtitle: playlist.creationDate.dateFormattedOriginal,
                          displaythirdLineText: true,
                          thirdLineText: Jiffy.parseFromMillisecondsSinceEpoch(playlist.modifiedDate).fromNow(),
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
                              NamidaNavigator.inst.navigateTo(YTNormalPlaylistSubpage(playlistName: playlist.name));
                            }
                          },
                          smallBoxText: playlist.tracks.length.formatDecimal(),
                          smallBoxIcon: Broken.play_cricle,
                          checkmarkStatus: idsExist,
                          menuChildrenDefault: () => getMenuItems(playlist),
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

class _HorizontalSliverList extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget viewAllPage;
  final Iterable<YoutubeID> videos;
  final String playlistName;
  final String playlistID;
  final int totalVideosCountInMainList;
  final Widget? subHeader;
  final EdgeInsets padding;
  final bool displayTimeAgo;
  final bool displayShimmer;
  final Map<String, List<int>>? listensMap;

  const _HorizontalSliverList({
    required this.title,
    required this.icon,
    required this.viewAllPage,
    required this.videos,
    required this.playlistName,
    required this.playlistID,
    required this.totalVideosCountInMainList,
    this.subHeader,
    this.padding = const EdgeInsets.symmetric(vertical: 8.0),
    this.displayTimeAgo = false,
    this.displayShimmer = false,
    this.listensMap,
  });

  void onTap() => NamidaNavigator.inst.navigateTo(viewAllPage);

  @override
  Widget build(BuildContext context) {
    final finalVideos = videos is List<YoutubeID> ? videos as List<YoutubeID> : videos.toList();
    final remainingVideosCount = totalVideosCountInMainList - finalVideos.length;

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
                if (subHeader != null) subHeader!,
              ],
            ),
          ),
          SizedBox(
            height: displayTimeAgo ? 132.0 : 124.0,
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
                        overrideListens: listensMap?[finalVideos[index].id] ?? [],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
