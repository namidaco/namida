import 'dart:async';

import 'package:flutter/material.dart';

import 'package:history_manager/history_manager.dart';
import 'package:playlist_manager/module/playlist_id.dart';
import 'package:playlist_manager/playlist_manager.dart';
import 'package:youtipie/class/youtipie_feed/playlist_basic_info.dart';

import 'package:namida/class/route.dart';
import 'package:namida/controller/file_browser.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/time_ago_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/pages/subpages/playlist_tracks_subpage.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/controller/youtube_import_controller.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart';
import 'package:namida/youtube/pages/yt_playlist_subpage.dart';
import 'package:namida/youtube/widgets/yt_card.dart';
import 'package:namida/youtube/widgets/yt_history_video_card.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:namida/youtube/yt_utils.dart';

class YoutubePlaylistsView extends StatefulWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.YOUTUBE_PLAYLISTS;

  final Iterable<String> idsToAdd;
  final bool displayMenu;
  final bool disableSorting;
  final bool? minimalView;

  const YoutubePlaylistsView({
    super.key,
    this.idsToAdd = const <String>[],
    this.displayMenu = true,
    this.disableSorting = false,
    this.minimalView,
  });

  @override
  State<YoutubePlaylistsView> createState() => _YoutubePlaylistsViewState();
}

class _YoutubePlaylistsViewState extends State<YoutubePlaylistsView> {
  Iterable<YoutubeID> getHistoryVideos(Map<int, List<YoutubeID>> map) {
    final videos = <String, YoutubeID>{};
    for (final trs in map.values) {
      trs.loop((e) {
        videos[e.id] ??= e;
      });
      if (videos.length >= 50) break;
    }
    return videos.values;
  }

  List<YoutubeID> getFavouriteVideos(YoutubePlaylist playlist) {
    final videos = <YoutubeID>[];
    final all = playlist.tracks;
    for (int i = all.length - 1; i >= 0; i--) {
      videos.add(all[i]);
      if (videos.length >= 50) break;
    }

    return videos;
  }

  FutureOr<List<NamidaPopupItem>> getMenuItems(BuildContext context, YoutubePlaylist playlist, QueueSourceYoutubeID queueSource) {
    return YTUtils.getVideosMenuItems(
      queueSource: queueSource,
      context: context,
      videos: playlist.tracks,
      playlistName: '',
      playlistToRemove: playlist,
    );
  }

  void _onAddToPlaylist({required YoutubePlaylist playlist, required bool allIdsExist, required bool allowAddingEverything}) {
    if (allIdsExist == true) {
      final indexes = <int>[];
      playlist.tracks.loopAdv((e, index) {
        if (widget.idsToAdd.contains(e.id)) {
          indexes.add(index);
        }
      });
      NamidaNavigator.inst.navigateDialog(
        dialog: CustomBlurryDialog(
          isWarning: true,
          normalTitleStyle: true,
          bodyText: "${lang.REMOVE_FROM_PLAYLIST} ${playlist.name.addDQuotation()}?",
          actions: [
            const CancelButton(),
            const SizedBox(width: 6.0),
            NamidaButton(
              text: lang.REMOVE.toUpperCase(),
              onPressed: () {
                NamidaNavigator.inst.closeDialog();
                YoutubePlaylistController.inst.removeTracksFromPlaylist(playlist, indexes);
              },
            ),
          ],
        ),
      );
    } else {
      final duplicateActions = allowAddingEverything ? PlaylistAddDuplicateAction.valuesForAdd : PlaylistAddDuplicateAction.valuesForAddExcludingAddEverything;
      YoutubePlaylistController.inst.addTracksToPlaylist(playlist, widget.idsToAdd, duplicationActions: duplicateActions);
    }
  }

  bool _isReordering = false;

  void _toggleReordering() {
    setState(() => _isReordering = !_isReordering);
    if (_isReordering && settings.ytPlaylistSort.value != GroupSortType.custom) {
      // -- for consistent order while enabling/disabling
      settings.save(ytPlaylistSort: GroupSortType.custom);
      YoutubePlaylistController.inst.sortPlaylists();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final idsToAdd = widget.idsToAdd;
    final isMinimalView = widget.minimalView ?? idsToAdd.isNotEmpty;

    const playlistsItemExtent = Dimensions.youtubeCardItemExtent * 0.9;
    const playlistThumbnailHeight = playlistsItemExtent - Dimensions.tileBottomMargin - (Dimensions.youtubeCardItemVerticalPadding * 2);
    const playlistThumbnailWidth = playlistThumbnailHeight * 16 / 9;

    return NamidaScrollbarWithController(
      child: (sc) => SmoothCustomScrollView(
        controller: sc,
        slivers: [
          if (!isMinimalView) ...[
            const SliverPadding(padding: EdgeInsets.only(bottom: 12.0)),
            Obx(
              (context) {
                final history = YoutubeHistoryController.inst.historyMap.valueR;
                final length = YoutubeHistoryController.inst.totalHistoryItemsCount.valueR;
                final lengthDummy = length == -1;
                return _HorizontalSliverList(
                  queueSource: QueueSourceYoutubeID.historyFiltered,
                  title: lang.HISTORY,
                  icon: Broken.refresh,
                  onPageOpen: YTUtils.onYoutubeHistoryPlaylistTap,
                  onPlusTap: (lastItem) => YTUtils.onYoutubeHistoryPlaylistTap(initialListen: lastItem.dateAddedMS),
                  videos: getHistoryVideos(history),
                  playlistName: k_PLAYLIST_NAME_HISTORY,
                  playlistID: k_PLAYLIST_NAME_HISTORY,
                  displayTimeAgo: true,
                  totalVideosCountInMainList: lengthDummy ? 0 : length,
                  displayShimmer: lengthDummy,
                  playlistInfo: () => PlaylistBasicInfo(
                    id: '',
                    title: lang.HISTORY,
                    videosCountText: length.displayVideoKeyword,
                    videosCount: length,
                    thumbnails: [],
                  ),
                );
              },
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 8.0)),
            ObxO(
              rx: YoutubeHistoryController.inst.totalHistoryItemsCount,
              builder: (context, totalLength) => ObxO(
                rx: YoutubeHistoryController.inst.currentMostPlayedTimeRange,
                builder: (context, currentMostPlayedTimeRange) => ObxO(
                  rx: YoutubeHistoryController.inst.currentTopTracksMapListensReactive(currentMostPlayedTimeRange),
                  builder: (context, listensMap) {
                    final videos = listensMap.keysSortedByValue
                        .map(
                          (e) => YoutubeID(
                            id: e,
                            playlistID: const PlaylistID(id: k_PLAYLIST_NAME_MOST_PLAYED),
                          ),
                        )
                        .toList();
                    return _HorizontalSliverList(
                      queueSource: QueueSourceYoutubeID.mostPlayed,
                      title: lang.MOST_PLAYED,
                      icon: Broken.crown_1,
                      onPageOpen: YTUtils.onYoutubeMostPlayedPlaylistTap,
                      padding: const EdgeInsets.only(top: 8.0),
                      videos: videos,
                      subHeader: YTMostPlayedVideosPage.getChipRow(context),
                      playlistName: '',
                      playlistID: k_PLAYLIST_NAME_MOST_PLAYED,
                      totalVideosCountInMainList: videos.length,
                      displayShimmer: totalLength == -1,
                      listensMap: listensMap,
                      playlistInfo: () => PlaylistBasicInfo(
                        id: '',
                        title: lang.MOST_PLAYED,
                        videosCountText: videos.length.displayVideoKeyword,
                        videosCount: videos.length,
                        thumbnails: [],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 8.0)),
            ObxOClass(
              rx: YoutubePlaylistController.inst.favouritesPlaylist,
              builder: (context, favs) {
                return ObxO(
                  rx: YoutubeHistoryController.inst.topTracksMapListens, // refresh cards after listens initialized
                  builder: (context, _) => _HorizontalSliverList(
                    queueSource: QueueSourceYoutubeID.favourites,
                    title: lang.FAVOURITES,
                    icon: Broken.heart_circle,
                    onPageOpen: YTUtils.onYoutubeLikedPlaylistTap,
                    videos: getFavouriteVideos(favs.value),
                    playlistName: k_PLAYLIST_NAME_FAV,
                    playlistID: k_PLAYLIST_NAME_FAV,
                    displayTimeAgo: false,
                    totalVideosCountInMainList: favs.value.tracks.length,
                    playlistInfo: () => PlaylistBasicInfo(
                      id: '',
                      title: lang.FAVOURITES,
                      videosCountText: favs.value.tracks.length.displayVideoKeyword,
                      videosCount: favs.value.tracks.length,
                      thumbnails: [],
                    ),
                  ),
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
                      (context) => SearchPageTitleRow(
                        title: "${lang.PLAYLISTS} - ${YoutubePlaylistController.inst.playlistsMap.length}",
                        icon: Broken.music_library_2,
                        trailing: const SizedBox(),
                        subtitleWidget: widget.disableSorting
                            ? null
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  NamidaPopupWrapper(
                                    children: () => [
                                      Column(
                                        children: [
                                          ListTileWithCheckMark(
                                            activeRx: settings.ytPlaylistSortReversed,
                                            onTap: () => YoutubePlaylistController.inst.sortYTPlaylists(reverse: !settings.ytPlaylistSortReversed.value),
                                          ),
                                          ...[
                                            GroupSortType.title,
                                            GroupSortType.creationDate,
                                            GroupSortType.modifiedDate,
                                            GroupSortType.numberOfTracks,
                                            GroupSortType.playCount,
                                            GroupSortType.firstListen,
                                            GroupSortType.latestPlayed,
                                            GroupSortType.shuffle,
                                            GroupSortType.custom,
                                          ].map(
                                            (e) => ObxO(
                                              rx: settings.ytPlaylistSort,
                                              builder: (context, ytPlaylistSort) => SmallListTile(
                                                title: e.toText(),
                                                active: ytPlaylistSort == e,
                                                onTap: () => YoutubePlaylistController.inst.sortYTPlaylists(sortBy: e),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    child: ObxO(
                                      rx: settings.ytPlaylistSort,
                                      builder: (context, ytPlaylistSort) => Text(
                                        ytPlaylistSort.toText(),
                                        style: textTheme.displaySmall?.copyWith(
                                          color: theme.colorScheme.secondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4.0),
                                  NamidaInkWell(
                                    onTap: () => YoutubePlaylistController.inst.sortYTPlaylists(reverse: !settings.ytPlaylistSortReversed.value),
                                    child: ObxO(
                                      rx: settings.ytPlaylistSortReversed,
                                      builder: (context, ytPlaylistSortReversed) => Icon(
                                        ytPlaylistSortReversed ? Broken.arrow_up_3 : Broken.arrow_down_2,
                                        size: 16.0,
                                        color: theme.colorScheme.secondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4.0),
                  NamidaInkWellButton(
                    icon: Broken.add_circle,
                    text: lang.CREATE,
                    borderRadius: 8.0,
                    onTap: YTUtils.showCreateLocalYTPlaylistSheet,
                  ),
                  SizedBox(width: 6.0),
                  NamidaTooltip(
                    message: () => _isReordering ? lang.DISABLE_REORDERING : lang.ENABLE_REORDERING,
                    child: NamidaInkWellButton(
                      icon: Broken.edit_2,
                      text: '',
                      borderRadius: 8.0,
                      decoration: _isReordering
                          ? BoxDecoration(
                              border: Border.all(
                                color: theme.iconTheme.color?.withValues(alpha: 0.4) ?? theme.colorScheme.primaryContainer.withValues(alpha: 0.8),
                              ),
                            )
                          : const BoxDecoration(),
                      onTap: _toggleReordering,
                    ),
                  ),
                  SizedBox(width: 6.0),
                  ObxO(
                    rx: YoutubeImportController.inst.isImportingPlaylists,
                    builder: (context, isImportingPlaylists) => Tooltip(
                      message: lang.IMPORT,
                      child: NamidaInkWellButton(
                        icon: Broken.import_2,
                        text: '',
                        enabled: !isImportingPlaylists,
                        borderRadius: 8.0,
                        onTap: () {
                          NamidaNavigator.inst.navigateDialog(
                            dialog: CustomBlurryDialog(
                              title: lang.NOTE,
                              normalTitleStyle: true,
                              bodyText:
                                  'Importing takeout playlists works by picking a single playlists directory, or a main directory that contains multiple takeouts, in that case playlists will be merged and video-sorted by date added',
                              actions: [
                                NamidaButton(
                                  onPressed: () async {
                                    NamidaNavigator.inst.closeDialog();

                                    final dirPath = await NamidaFileBrowser.getDirectory(note: 'choose playlist directory from a google takeout');
                                    if (dirPath == null) return;

                                    final details = await YoutubeImportController.inst.importPlaylists(dirPath);
                                    if (details == null) {
                                      snackyy(
                                        icon: Broken.forbidden,
                                        message: "Operation Canceled",
                                      );
                                      return;
                                    }
                                    if (details.totalCount <= 0) {
                                      snackyy(
                                        icon: Broken.danger,
                                        message: "Failed to import\nPlease choose a valid playlists directory taken from google takeout",
                                        isError: true,
                                      );
                                      return;
                                    }

                                    final importedSucessText = lang.IMPORTED_N_PLAYLISTS_SUCCESSFULLY.replaceFirst('_NUM_', '${details.countAfterMerging}');
                                    final detailsText = 'Total Count: ${details.totalCount} | Merged Count: ${details.mergedCount} | Final Count: ${details.countAfterMerging}';
                                    snackyy(
                                      icon: Broken.copy_success,
                                      message: '$importedSucessText\n$detailsText',
                                      borderColor: Colors.green.withValues(alpha: 0.8),
                                    );
                                  },
                                  text: lang.PICK_FROM_STORAGE,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 4.0),
                ],
              ),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 8.0)),
          if (idsToAdd.isNotEmpty)
            SliverToBoxAdapter(
              child: ObxOClass(
                rx: YoutubePlaylistController.inst.favouritesPlaylist,
                builder: (context, favouritesPlaylist) {
                  bool? allIdsExist;
                  if (idsToAdd.isNotEmpty) {
                    allIdsExist = idsToAdd.every(favouritesPlaylist.isSubItemFavourite);
                  }

                  return YoutubeCard(
                    thumbnailType: ThumbnailType.playlist,
                    isImageImportantInCache: true,
                    extractColor: true,
                    thumbnailWidthPercentage: 0.75,
                    videoId: favouritesPlaylist.value.tracks.firstOrNull?.id,
                    thumbnailUrl: null,
                    shimmerEnabled: false,
                    title: favouritesPlaylist.value.name.translatePlaylistName(),
                    subtitle: favouritesPlaylist.value.creationDate.dateFormattedOriginal,
                    displaythirdLineText: true,
                    thirdLineText: TimeAgoController.dateMSSEFromNow(favouritesPlaylist.value.modifiedDate),
                    displayChannelThumbnail: false,
                    channelThumbnailUrl: '',
                    thumbnailHeight: playlistThumbnailHeight,
                    thumbnailWidth: playlistThumbnailWidth,
                    onTap: () {
                      _onAddToPlaylist(
                        playlist: favouritesPlaylist.value,
                        allIdsExist: allIdsExist == true,
                        allowAddingEverything: false,
                      );
                    },
                    smallBoxText: favouritesPlaylist.value.tracks.length.formatDecimal(),
                    smallBoxIcon: Broken.play_cricle,
                    checkmarkStatus: allIdsExist,
                    menuChildrenDefault: widget.displayMenu ? () => getMenuItems(context, favouritesPlaylist.value, QueueSourceYoutubeID.favourites) : null,
                  );
                },
              ),
            ),
          if (idsToAdd.isNotEmpty)
            const SliverToBoxAdapter(
              child: NamidaContainerDivider(margin: EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0)),
            ),
          _isReordering
              ? ObxO(
                  rx: YoutubePlaylistController.inst.playlistsMap,
                  builder: (context, playlistsMap) => ObxO(
                    rx: YoutubePlaylistController.inst.getCustomIndicesOrderListRx(),
                    builder: (context, customIndicesOrderList) => NamidaSliverReorderableList(
                      itemExtent: playlistsItemExtent,
                      onReorder: (oldIndex, newIndex) async {
                        if (settings.ytPlaylistSort.value != GroupSortType.custom) {
                          settings.save(ytPlaylistSort: GroupSortType.custom);
                        }
                        YoutubePlaylistController.inst.onPlaylistReorder(oldIndex, newIndex);
                      },
                      itemCount: customIndicesOrderList!.length,
                      itemBuilder: (context, i) {
                        final name = customIndicesOrderList[i];
                        final playlist = playlistsMap[name]!;

                        final creationDateText = playlist.creationDate.dateFormattedOriginal;
                        return NamidaReordererableListener(
                          key: ValueKey(i),
                          durationMs: 100,
                          index: i,
                          child: InkWell(
                            onTap: () {},
                            child: Row(
                              children: [
                                const ThreeLineSmallContainers(
                                  enabled: true,
                                ),
                                Expanded(
                                  child: AbsorbPointer(
                                    child: YoutubeCard(
                                      thumbnailType: ThumbnailType.playlist,
                                      isImageImportantInCache: true,
                                      extractColor: true,
                                      thumbnailWidthPercentage: 0.75,
                                      videoId: playlist.tracks.firstOrNull?.id,
                                      thumbnailUrl: null,
                                      shimmerEnabled: false,
                                      title: playlist.name,
                                      subtitle: creationDateText,
                                      displaythirdLineText: true,
                                      thirdLineText: TimeAgoController.dateMSSEFromNow(playlist.modifiedDate),
                                      displayChannelThumbnail: false,
                                      channelThumbnailUrl: '',
                                      thumbnailHeight: playlistThumbnailHeight,
                                      thumbnailWidth: playlistThumbnailWidth,
                                      smallBoxText: playlist.tracks.length.formatDecimal(),
                                      smallBoxIcon: Broken.play_cricle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                )
              : ObxO(
                  rx: settings.ytPlaylistSort,
                  builder: (context, sort) {
                    final sortTextIsUseless =
                        sort == GroupSortType.title ||
                        sort == GroupSortType.numberOfTracks ||
                        sort == GroupSortType.duration ||
                        sort == GroupSortType.modifiedDate ||
                        sort == GroupSortType.creationDate;
                    final extraTextResolver = sortTextIsUseless ? null : YoutubePlaylistController.inst.getGroupSortExtraTextResolverPlaylist(sort);

                    late final existingStatus = <String, bool>{};
                    late final sortedIndices = <String, int>{};

                    return ObxPrefer(
                      enabled: sort.requiresHistory,
                      rx: YoutubeHistoryController.inst.topTracksMapListens,
                      builder: (context, _) => Obx(
                        (context) {
                          final playlistsMap = YoutubePlaylistController.inst.playlistsMap.valueR;

                          List<String> playlistsNames;
                          if (idsToAdd.isNotEmpty) {
                            // -- put playlists having the tracks at first
                            final playlistsNamesSorted = <String>[];
                            final shouldReSort = existingStatus.isEmpty; // sort only once, so that refresh won't make them jump around

                            for (final key in playlistsMap.keys) {
                              playlistsNamesSorted.add(key);
                              final playlist = playlistsMap[key]!;
                              final allTracksExist = idsToAdd.every((idToAdd) => playlist.tracks.firstWhereEff((e) => e.id == idToAdd) != null);
                              existingStatus[key] = allTracksExist;
                            }
                            playlistsNamesSorted.sortBy((key) => sortedIndices[key] ?? (existingStatus[key] == true ? -2 : -1));
                            if (shouldReSort) {
                              for (var i = 0; i < playlistsNamesSorted.length; i++) {
                                sortedIndices[playlistsNamesSorted[i]] = i;
                              }
                            }
                            playlistsNames = playlistsNamesSorted;
                          } else {
                            playlistsNames = playlistsMap.keys.toList();
                          }
                          return SliverFixedExtentList.builder(
                            itemExtent: playlistsItemExtent,
                            itemCount: playlistsNames.length,
                            itemBuilder: (context, index) {
                              final name = playlistsNames[index];
                              final playlist = playlistsMap[name]!;
                              final allIdsExist = existingStatus[name];

                              final extraText = extraTextResolver?.call(playlist);

                              final creationDateText = playlist.creationDate.dateFormattedOriginal;
                              final subtitle = extraText != null && extraText.isNotEmpty
                                  ? [
                                      creationDateText,
                                      extraText,
                                    ].join(' • ')
                                  : creationDateText;

                              return NamidaPopupWrapper(
                                childrenDefault: widget.displayMenu ? () => getMenuItems(context, playlist, QueueSourceYoutubeID.playlist) : null,
                                openOnTap: false,
                                child: YoutubeCard(
                                  thumbnailType: ThumbnailType.playlist,
                                  isImageImportantInCache: true,
                                  extractColor: true,
                                  thumbnailWidthPercentage: 0.75,
                                  videoId: playlist.tracks.firstOrNull?.id,
                                  thumbnailUrl: null,
                                  shimmerEnabled: false,
                                  title: playlist.name,
                                  subtitle: subtitle,
                                  displaythirdLineText: true,
                                  thirdLineText: TimeAgoController.dateMSSEFromNow(playlist.modifiedDate),
                                  displayChannelThumbnail: false,
                                  channelThumbnailUrl: '',
                                  thumbnailHeight: playlistThumbnailHeight,
                                  thumbnailWidth: playlistThumbnailWidth,
                                  onTap: () {
                                    if (idsToAdd.isNotEmpty) {
                                      _onAddToPlaylist(playlist: playlist, allIdsExist: allIdsExist == true, allowAddingEverything: true);
                                    } else {
                                      YTNormalPlaylistSubpage(
                                        playlistName: playlist.name,
                                        queueSource: QueueSourceYoutubeID.playlist,
                                      ).navigate();
                                    }
                                  },
                                  smallBoxText: playlist.tracks.length.formatDecimal(),
                                  smallBoxIcon: Broken.play_cricle,
                                  checkmarkStatus: allIdsExist,
                                  menuChildrenDefault: widget.displayMenu ? () => getMenuItems(context, playlist, QueueSourceYoutubeID.playlist) : null,
                                ),
                              );
                            },
                          );
                        },
                      ),
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
  final QueueSourceYoutubeID queueSource;
  final String title;
  final IconData icon;
  final void Function() onPageOpen;
  final void Function(YoutubeID lastItem)? onPlusTap;
  final Iterable<YoutubeID> videos;
  final String playlistName;
  final String playlistID;
  final PlaylistBasicInfo Function()? playlistInfo;
  final int totalVideosCountInMainList;
  final Widget? subHeader;
  final EdgeInsets padding;
  final bool displayTimeAgo;
  final bool displayShimmer;
  final ListensSortedMap<String>? listensMap;

  const _HorizontalSliverList({
    required this.queueSource,
    required this.title,
    required this.icon,
    required this.onPageOpen,
    this.onPlusTap,
    required this.videos,
    required this.playlistName,
    required this.playlistID,
    required this.playlistInfo,
    required this.totalVideosCountInMainList,
    this.subHeader,
    this.padding = const EdgeInsets.symmetric(vertical: 8.0),
    this.displayTimeAgo = false,
    this.displayShimmer = false,
    this.listensMap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final finalVideos = videos is List<YoutubeID> ? videos as List<YoutubeID> : videos.toList();
    final remainingVideosCount = totalVideosCountInMainList - finalVideos.length;

    const thumbHeight = 24.0 * 3.2;
    const thumbWidth = thumbHeight * 16 / 9;

    return VideoTilePropertiesProvider(
      configs: VideoTilePropertiesConfigs(
        queueSource: queueSource,
        playlistName: playlistName,
        playlistID: PlaylistID(id: playlistID),
        displayTimeAgo: displayTimeAgo,
        playlistInfo: playlistInfo,
      ),
      builder: (properties) => SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NamidaInkWell(
              margin: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
              padding: padding,
              onTap: onPageOpen,
              child: Column(
                children: [
                  SearchPageTitleRow(
                    title: title,
                    subtitle: totalVideosCountInMainList.displayVideoKeyword,
                    icon: icon,
                    trailing: const Icon(Broken.arrow_right_3),
                    onPressed: onPageOpen,
                  ),
                  ?subHeader,
                ],
              ),
            ),
            SizedBox(
              height: displayTimeAgo ? 132.0 : 124.0,
              child: displayShimmer
                  ? ShimmerWrapper(
                      shimmerEnabled: true,
                      child: SuperSmoothListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0),
                        scrollDirection: Axis.horizontal,
                        itemCount: 10,
                        itemBuilder: (context, index) {
                          return NamidaInkWell(
                            animationDurationMS: 200,
                            margin: const EdgeInsets.symmetric(horizontal: 4.0),
                            width: thumbWidth,
                            bgColor: theme.cardColor,
                          );
                        },
                      ),
                    )
                  : SuperSmoothListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                      scrollDirection: Axis.horizontal,
                      itemCount: finalVideos.length + 1,
                      itemBuilder: (context, index) {
                        if (index == finalVideos.length + 1 - 1) {
                          return remainingVideosCount <= 0
                              ? const SizedBox()
                              : NamidaInkWell(
                                  onTap: onPlusTap != null ? () => onPlusTap!(finalVideos[finalVideos.length - 1]) : onPageOpen,
                                  margin: const EdgeInsets.all(12.0),
                                  padding: const EdgeInsets.all(12.0),
                                  child: Center(
                                    child: Text(
                                      "+${remainingVideosCount.formatDecimalShort()}",
                                      style: textTheme.displayMedium,
                                    ),
                                  ),
                                );
                        }
                        return YTHistoryVideoCard(
                          properties: properties,
                          minimalCard: true,
                          videos: finalVideos,
                          index: index,
                          day: null,
                          minimalCardWidth: thumbWidth,
                          thumbnailHeight: thumbHeight,
                          overrideListens: listensMap?[finalVideos[index].id] ?? [],
                          preferFetchNewInfo: true,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
