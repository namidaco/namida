import 'package:flutter/material.dart';

import 'package:flex_list/flex_list.dart';
import 'package:playlist_manager/module/playlist_id.dart';
import 'package:youtipie/class/execute_details.dart';
import 'package:youtipie/class/result_wrapper/list_wrapper_base.dart';
import 'package:youtipie/class/result_wrapper/playlist_mix_result.dart';
import 'package:youtipie/class/result_wrapper/playlist_result.dart';
import 'package:youtipie/class/result_wrapper/playlist_result_base.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/class/youtipie_feed/playlist_basic_info.dart';
import 'package:youtipie/class/youtipie_feed/playlist_info_item_user.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/base/pull_to_refresh.dart';
import 'package:namida/base/youtube_streams_manager.dart';
import 'package:namida/class/route.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/themes.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/pages/subpages/most_played_subpage.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart';
import 'package:namida/youtube/functions/yt_playlist_utils.dart';
import 'package:namida/youtube/pages/yt_playlist_download_subpage.dart';
import 'package:namida/youtube/widgets/yt_history_video_card.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:namida/youtube/widgets/yt_video_card.dart';
import 'package:namida/youtube/yt_utils.dart';

class YTMostPlayedVideosPage extends StatelessWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.YOUTUBE_MOST_PLAYED_SUBPAGE;

  const YTMostPlayedVideosPage({super.key});

  static Widget getChipRow(BuildContext context) {
    final config = MostPlayedItemsPage(
      itemExtent: Dimensions.youtubeCardItemExtent,
      historyController: YoutubeHistoryController.inst,
      onSavingTimeRange: ({dateCustom, isStartOfDay, mptr}) {
        settings.save(
          ytMostPlayedTimeRange: mptr,
          ytMostPlayedCustomDateRange: dateCustom,
          ytMostPlayedCustomisStartOfDay: isStartOfDay,
        );
      },
      infoBox: null,
      header: null,
      itemsCount: 0,
      itemBuilder: (context, i) => const SizedBox(),
    );
    return config.getChipsRow(context);
  }

  @override
  Widget build(BuildContext context) {
    return VideoTilePropertiesProvider(
      configs: VideoTilePropertiesConfigs(
        queueSource: QueueSourceYoutubeID.mostPlayed,
        playlistID: const PlaylistID(id: k_PLAYLIST_NAME_MOST_PLAYED),
        playlistName: k_PLAYLIST_NAME_MOST_PLAYED,
      ),
      builder: (properties) => ObxO(
        rx: YoutubeHistoryController.inst.currentMostPlayedTimeRange,
        builder: (context, currentMostPlayedTimeRange) => ObxO(
          rx: YoutubeHistoryController.inst.currentTopTracksMapListensReactive(currentMostPlayedTimeRange),
          builder: (context, listensMap) {
            final videos = <String>[];
            final ytIds = <YoutubeID>[];
            for (final e in listensMap.keys) {
              videos.add(e);
              ytIds.add(
                YoutubeID(
                  id: e,
                  playlistID: const PlaylistID(id: k_PLAYLIST_NAME_MOST_PLAYED),
                ),
              );
            }

            return MostPlayedItemsPage(
              itemExtent: Dimensions.youtubeCardItemExtent,
              historyController: YoutubeHistoryController.inst,
              onSavingTimeRange: ({dateCustom, isStartOfDay, mptr}) {
                settings.save(
                  ytMostPlayedTimeRange: mptr,
                  ytMostPlayedCustomDateRange: dateCustom,
                  ytMostPlayedCustomisStartOfDay: isStartOfDay,
                );
              },
              infoBox: null,
              header: (timeRangeChips, bottomPadding) {
                return Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: timeRangeChips,
                );
              },
              itemsCount: listensMap.length,
              itemBuilder: (context, i) {
                final videoID = videos[i];
                final listens = listensMap[videoID] ?? [];

                return YTHistoryVideoCard(
                  properties: properties,
                  key: Key("${videoID}_$i"),
                  videos: ytIds,
                  index: i,
                  day: null,
                  overrideListens: listens,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class YTLikedVideosPage extends StatelessWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.YOUTUBE_LIKED_SUBPAGE;

  const YTLikedVideosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const YTNormalPlaylistSubpage(
      playlistName: k_PLAYLIST_NAME_FAV,
      isEditable: false,
      reversedList: true,
      queueSource: QueueSourceYoutubeID.favourites,
    );
  }
}

class YTNormalPlaylistSubpage extends StatefulWidget with NamidaRouteWidget {
  @override
  String? get name => playlistName;

  @override
  RouteType get route => RouteType.YOUTUBE_PLAYLIST_SUBPAGE;

  final String playlistName;
  final bool isEditable;
  final bool reversedList;
  final QueueSourceYoutubeID queueSource;

  const YTNormalPlaylistSubpage({
    super.key,
    required this.playlistName,
    this.isEditable = true,
    this.reversedList = false,
    required this.queueSource,
  });

  @override
  State<YTNormalPlaylistSubpage> createState() => _YTNormalPlaylistSubpageState();
}

class _YTNormalPlaylistSubpageState extends State<YTNormalPlaylistSubpage> {
  Color? bgColor;
  String playlistCurrentName = ''; // to refresh after renaming

  @override
  void initState() {
    playlistCurrentName = widget.playlistName;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    const horizontalBigThumbPadding = 12.0;
    final theme = AppThemes.inst.getAppTheme(bgColor, !context.isDarkMode);
    return AnimatedThemeOrTheme(
      duration: const Duration(milliseconds: 300),
      data: theme,
      child: BackgroundWrapper(
        child: NamidaScrollbarWithController(
          child: (sc) => Obx(
            (context) {
              YoutubePlaylistController.inst.playlistsMap.valueR;
              final playlist = YoutubePlaylistController.inst.getPlaylist(playlistCurrentName);
              if (playlist == null) return const SizedBox();
              final firstID = playlist.tracks.firstOrNull?.id;
              return NamidaListViewRaw(
                scrollController: sc,
                listBottomPadding: 24.0,
                infoBox: (maxWidth) {
                  final bigThumbWidth = maxWidth - horizontalBigThumbPadding * 2;
                  return Align(
                    alignment: Alignment.topCenter,
                    child: Stack(
                      children: [
                        NamidaBlur(
                          blur: 40.0,
                          fixArtifacts: true,
                          child: YoutubeThumbnail(
                            type: ThumbnailType.playlist,
                            key: Key("$firstID"),
                            width: maxWidth,
                            height: maxWidth * 9 / 16,
                            forceSquared: true,
                            compressed: true,
                            isImportantInCache: false,
                            videoId: firstID,
                            blur: 0.0,
                            borderRadius: 0.0,
                            disableBlurBgSizeShrink: true,
                            extractColor: true,
                            onColorReady: (color) async {
                              if (color != null) {
                                await Future.delayed(const Duration(milliseconds: 200)); // navigation delay
                                refreshState(() {
                                  bgColor = color.color;
                                });
                              }
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: horizontalBigThumbPadding, vertical: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              YoutubeThumbnail(
                                type: ThumbnailType.playlist,
                                key: Key("$firstID"),
                                width: bigThumbWidth,
                                height: (bigThumbWidth * 9 / 16),
                                forceSquared: true,
                                compressed: false,
                                isImportantInCache: true,
                                videoId: firstID,
                                blur: 0.0,
                              ),
                              const SizedBox(height: 24.0),
                              FlexList(
                                verticalSpacing: 8.0,
                                children: [
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        playlistCurrentName.translatePlaylistName(),
                                        style: theme.textTheme.displayLarge,
                                      ),
                                      const SizedBox(height: 6.0),
                                      Text(
                                        playlist.tracks.length.displayVideoKeyword,
                                        style: theme.textTheme.displaySmall,
                                      ),
                                      if (playlist.comment != '') ...[
                                        const SizedBox(height: 2.0),
                                        Text(
                                          playlist.comment,
                                          style: theme.textTheme.displaySmall,
                                        ),
                                      ],
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      NamidaIconButton(
                                        iconColor: context.defaultIconColor(bgColor),
                                        icon: Broken.shuffle,
                                        tooltip: () => lang.SHUFFLE,
                                        onPressed: () => Player.inst.playOrPause(0, playlist.tracks, widget.queueSource, shuffle: true),
                                      ),
                                      NamidaIconButton(
                                        iconColor: context.defaultIconColor(bgColor),
                                        icon: Broken.play_cricle,
                                        tooltip: () => lang.PLAY_LAST,
                                        onPressed: () => Player.inst.addToQueue(playlist.tracks, insertNext: false),
                                      ),
                                      NamidaIconButton(
                                        iconColor: context.defaultIconColor(bgColor),
                                        icon: Broken.import,
                                        onPressed: () async {
                                          YTPlaylistDownloadPage(
                                            ids: playlist.tracks,
                                            playlistName: playlistCurrentName.translatePlaylistName(),
                                            infoLookup: const {},
                                            playlistInfo: null, // this is a local playlist, passing info messes things up inside.
                                          ).navigate();
                                        },
                                      ),
                                      NamidaPopupWrapper(
                                        openOnLongPress: false,
                                        childrenDefault: () => [
                                          NamidaPopupItem(
                                            icon: Broken.share,
                                            title: lang.SHARE,
                                            onTap: playlist.shareVideos,
                                          ),
                                          if (widget.isEditable) ...[
                                            NamidaPopupItem(
                                              icon: Broken.edit_2,
                                              title: lang.RENAME_PLAYLIST,
                                              onTap: () async {
                                                final newName = await playlist.showRenamePlaylistSheet(playlistName: playlistCurrentName);
                                                if (newName == null) return;
                                                refreshState(() => playlistCurrentName = newName);
                                              },
                                            ),
                                            NamidaPopupItem(
                                              icon: Broken.trash,
                                              title: lang.DELETE_PLAYLIST,
                                              onTap: () async {
                                                final didDelete = await playlist.promptDelete(name: playlistCurrentName, colorScheme: bgColor);
                                                if (didDelete) NamidaNavigator.inst.popPage();
                                              },
                                            ),
                                          ],
                                        ],
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                          child: Icon(
                                            Broken.more_2,
                                            color: context.defaultIconColor(bgColor),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  );
                },
                slivers: [
                  VideoTilePropertiesProvider(
                    configs: VideoTilePropertiesConfigs(
                      queueSource: widget.queueSource,
                      playlistName: playlistCurrentName,
                      draggableThumbnail: true, // shows three lines
                      draggingEnabled: true, // actual is managed using reorderableRx
                      showMoreIcon: true,
                      reorderableRx: YoutubePlaylistController.inst.canReorderItems,
                    ),
                    builder: (properties) => NamidaSliverReorderableList(
                      onReorder: (oldIndex, newIndex) => YoutubePlaylistController.inst.reorderTrack(playlist, oldIndex, newIndex),
                      itemExtent: Dimensions.youtubeCardItemExtent,
                      itemCount: playlist.tracks.length,
                      itemBuilder: (context, index) {
                        final video = playlist.tracks[index];
                        return FadeDismissible(
                          key: Key("Diss_$index$video"),
                          draggableRx: YoutubePlaylistController.inst.canReorderItems,
                          onDismissed: (direction) => YTUtils.onRemoveVideosFromPlaylist(playlistCurrentName, [video]),
                          child: YTHistoryVideoCard(
                            properties: properties,
                            key: ValueKey(index),
                            videos: playlist.tracks,
                            index: index,
                            downloadIndex: index,
                            downloadTotalLength: playlist.tracks.length,
                            reversedList: widget.reversedList,
                            day: null,
                          ),
                        );
                      },
                    ),
                  ),
                  kBottomPaddingWidgetSliver,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class YTHostedPlaylistSubpage extends StatefulWidget with NamidaRouteWidget {
  @override
  String? get name => playlist.basicInfo.title;
  @override
  RouteType get route => RouteType.YOUTUBE_PLAYLIST_SUBPAGE_HOSTED;

  final YoutiPiePlaylistResultBase playlist;
  final PlaylistInfoItemUser? userPlaylist;
  final bool isMixPlaylist;

  const YTHostedPlaylistSubpage({
    super.key,
    required this.playlist,
    required this.userPlaylist,
  }) : isMixPlaylist = playlist is YoutiPieMixPlaylistResult;

  YTHostedPlaylistSubpage.fromId({
    super.key,
    required String playlistId,
    required this.userPlaylist,
  })  : playlist = _EmptyPlaylistResult(playlistId: playlistId),
        isMixPlaylist = playlistId.startsWith('RD') && playlistId.length == 13;

  @override
  State<YTHostedPlaylistSubpage> createState() => _YTHostedPlaylistSubpageState();
}

class _YTHostedPlaylistSubpageState extends State<YTHostedPlaylistSubpage> with YoutubeStreamsManager, TickerProviderStateMixin, PullToRefreshMixin {
  @override
  double get maxDistance => 64.0;

  @override
  List<StreamInfoItem> get streamsList => _playlist.items;

  @override
  YoutiPieListWrapper<StreamInfoItem>? get listWrapper => _playlist;

  @override
  ScrollController get scrollController => _controller;

  @override
  Color? get sortChipBGColor => bgColor?.withValues(alpha: 0.6);

  @override
  void onSortChanged(void Function() fn) => refreshState(fn);

  @override
  void onListChange(void Function() fn) => refreshState(fn);

  @override
  bool canRefreshList(_) => true;

  late final ScrollController _controller;
  final _isLoadingMoreItems = false.obs;

  YoutiPieFetchAllRes? _currentFetchAllRes;

  late YoutiPiePlaylistResultBase _playlist;

  late final YoutiPiePlaylistEditCallbacks _playlistInfoEditUpdater = YoutiPiePlaylistEditCallbacks(
    oldPlaylist: () => _playlist,
    newPlaylistCallback: (newPlaylist) {
      refreshState(() => _playlist = newPlaylist);
    },
  );

  @override
  void initState() {
    // we eventually need to implement playlist sort if account is signed in.
    _playlist = widget.playlist;
    _controller = ScrollController();
    super.initState();

    _initValues();

    YtUtilsPlaylist.activePlaylists.add(_playlistInfoEditUpdater);
  }

  @override
  void dispose() {
    _isLoadingMoreItems.close();
    disposeResources();
    YtUtilsPlaylist.activePlaylists.remove(_playlistInfoEditUpdater);
    super.dispose();
  }

  void _initValues() async {
    final cached = await YoutiPie.cacheBuilder.forPlaylistVideos(playlistId: _playlist.basicInfo.id).read();
    if (cached != null) {
      refreshState(
        () {
          _playlist = cached;
          trySortStreams();
        },
      );
    }

    onRefresh(() => _fetch100Video(forceRequest: _playlist is YoutiPiePlaylistResult), forceProceed: true);
  }

  Color? bgColor;

  Future<List<YoutubeID>> _getAllPlaylistVideos() async {
    return await _playlist.basicInfo.fetchAllPlaylistAsYTIDs(showProgressSheet: true, playlistToFetch: _playlist);
  }

  Future<bool> _fetch100Video({bool forceRequest = false}) async {
    if (_isLoadingMoreItems.value) return false;
    _isLoadingMoreItems.value = true;

    bool fetched = false;

    try {
      final currentPlaylist = _playlist;
      if (forceRequest || currentPlaylist.items.isEmpty) {
        YoutiPiePlaylistResultBase? newPlaylist;
        if (widget.isMixPlaylist) {
          final mixId = currentPlaylist.basicInfo.id;
          final mixVideoId = mixId.substring(2);
          newPlaylist = await YoutubeInfoController.playlist.getMixPlaylist(
            videoId: mixVideoId,
            mixId: mixId,
            details: ExecuteDetails.forceRequest(),
          );
        } else {
          String? plId;
          if (currentPlaylist is YoutiPiePlaylistResult) plId = currentPlaylist.playlistId;
          plId ??= currentPlaylist.basicInfo.id;
          newPlaylist = await YoutubeInfoController.playlist.fetchPlaylist(
            playlistId: plId,
            details: ExecuteDetails.forceRequest(),
          );
        }
        if (newPlaylist != null) {
          _playlist = newPlaylist;
          fetched = true;
        }
      } else {
        if (currentPlaylist.canFetchNext) {
          fetched = await currentPlaylist.fetchNext();
        }
      }
    } catch (_) {}

    _isLoadingMoreItems.value = false;
    if (fetched) refreshState(trySortStreams);
    return fetched;
  }

  @override
  Widget build(BuildContext context) {
    const horizontalBigThumbPadding = 12.0;
    final playlist = _playlist;

    const itemsThumbnailHeight = Dimensions.youtubeThumbnailHeight;
    const itemsThumbnailWidth = Dimensions.youtubeThumbnailWidth;
    const itemsThumbnailItemExtent = itemsThumbnailHeight + 8.0 * 2;

    String? description;
    String uploaderTitleAndViews = '';
    String? thumbnailUrl;
    String? plId;

    if (playlist is YoutiPiePlaylistResult) {
      description = playlist.info.description;
      final uploaderTitle = playlist.info.uploader?.title;
      final viewsCount = playlist.info.viewsCount;
      final viewsCountText = viewsCount == null ? playlist.info.viewsCountText : viewsCount.displayViewsKeywordShort;
      uploaderTitleAndViews = [
        if (uploaderTitle != null) uploaderTitle,
        if (viewsCountText != null) viewsCountText,
      ].join(' - ');
      thumbnailUrl = playlist.info.thumbnails.pick()?.url;
      plId = playlist.playlistId;
    }

    String? videosCountTextFinal;
    final videosCount = playlist.basicInfo.videosCount;
    if (playlist is YoutiPieMixPlaylistResult) {
      videosCountTextFinal = videosCount?.displayVideoKeyword;
    } else if (playlist is YoutiPiePlaylistResult) {
      videosCountTextFinal = videosCount?.displayVideoKeyword;
    }
    videosCountTextFinal ??= playlist.basicInfo.videosCountText ?? '?';

    plId ??= playlist.basicInfo.id;
    final plIdWrapper = PlaylistID(id: plId);
    final firstID = playlist.items.firstOrNull?.id;
    final hasMoreStreamsLeft = playlist.canFetchNext;
    final theme = AppThemes.inst.getAppTheme(bgColor, !context.isDarkMode);
    return VideoTilePropertiesProvider(
      configs: VideoTilePropertiesConfigs(
        queueSource: QueueSourceYoutubeID.playlistHosted,
        showMoreIcon: true,
      ),
      builder: (properties) => AnimatedThemeOrTheme(
        duration: const Duration(milliseconds: 300),
        data: theme,
        child: BackgroundWrapper(
          child: PullToRefreshWidget(
            state: this,
            controller: _controller,
            onRefresh: () => _fetch100Video(forceRequest: true),
            child: LazyLoadListView(
              scrollController: _controller,
              onReachingEnd: _fetch100Video,
              listview: (controller) => NamidaListViewRaw(
                scrollController: controller,
                infoBox: (maxWidth) {
                  final bigThumbWidth = maxWidth - horizontalBigThumbPadding * 2;
                  return Align(
                    alignment: Alignment.topCenter,
                    child: Stack(
                      children: [
                        NamidaBlur(
                          blur: 40.0,
                          fixArtifacts: true,
                          child: YoutubeThumbnail(
                            type: ThumbnailType.playlist,
                            key: Key("$firstID"),
                            width: maxWidth,
                            height: maxWidth * 9 / 16,
                            forceSquared: true,
                            compressed: true,
                            isImportantInCache: false,
                            preferLowerRes: true,
                            // customUrl: thumbnailUrl,
                            videoId: firstID,
                            blur: 0.0,
                            borderRadius: 0.0,
                            disableBlurBgSizeShrink: true,
                            extractColor: true,
                            onColorReady: (color) async {
                              if (color != null) {
                                await Future.delayed(const Duration(milliseconds: 200)); // navigation delay
                                refreshState(() {
                                  bgColor = color.color;
                                });
                              }
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: horizontalBigThumbPadding, vertical: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              YoutubeThumbnail(
                                type: ThumbnailType.playlist,
                                key: Key("$firstID"),
                                width: bigThumbWidth,
                                height: (bigThumbWidth * 9 / 16),
                                forceSquared: true,
                                compressed: false,
                                isImportantInCache: true,
                                preferLowerRes: false,
                                customUrl: thumbnailUrl,
                                videoId: firstID,
                                blur: 0.0,
                              ),
                              const SizedBox(height: 24.0),
                              FlexList(
                                verticalSpacing: 8.0,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        playlist.basicInfo.title,
                                        style: theme.textTheme.displayLarge,
                                      ),
                                      const SizedBox(height: 6.0),
                                      Text(
                                        videosCountTextFinal ?? '',
                                        style: theme.textTheme.displaySmall,
                                      ),
                                      if (uploaderTitleAndViews.isNotEmpty == true) ...[
                                        const SizedBox(height: 2.0),
                                        Text(
                                          uploaderTitleAndViews,
                                          style: theme.textTheme.displaySmall,
                                        ),
                                      ],
                                      if (description != null && description.isNotEmpty) ...[
                                        const SizedBox(height: 2.0),
                                        Text(
                                          description,
                                          style: theme.textTheme.displaySmall,
                                        ),
                                      ],
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      NamidaIconButton(
                                        iconColor: context.defaultIconColor(bgColor),
                                        icon: Broken.shuffle,
                                        tooltip: () => lang.SHUFFLE,
                                        onPressed: () async {
                                          final videos = await _getAllPlaylistVideos();
                                          if (videos.isEmpty) return;
                                          Player.inst.playOrPause(0, videos, QueueSourceYoutubeID.playlistHosted, shuffle: true);
                                        },
                                      ),
                                      NamidaIconButton(
                                        iconColor: context.defaultIconColor(bgColor),
                                        icon: Broken.play_cricle,
                                        tooltip: () => lang.PLAY_LAST,
                                        onPressed: () async {
                                          final videos = await _getAllPlaylistVideos();
                                          if (videos.isEmpty) return;
                                          Player.inst.addToQueue(videos, insertNext: false);
                                        },
                                      ),
                                      NamidaIconButton(
                                        iconColor: context.defaultIconColor(bgColor),
                                        icon: Broken.import,
                                        onPressed: () async {
                                          final videos = await _getAllPlaylistVideos();
                                          if (videos.isEmpty) return;
                                          final infoLookup = <String, StreamInfoItem>{};
                                          _playlist.items.loop((e) => infoLookup[e.id] = e);
                                          YTPlaylistDownloadPage(
                                            ids: videos,
                                            playlistName: playlist.basicInfo.title,
                                            infoLookup: infoLookup,
                                            playlistInfo: playlist.basicInfo,
                                          ).navigate();
                                        },
                                      ),
                                      NamidaPopupWrapper(
                                        openOnLongPress: false,
                                        childrenDefault: () => playlist.basicInfo.getPopupMenuItems(
                                          queueSource: QueueSourceYoutubeID.playlistHosted,
                                          playlistToFetch: _playlist,
                                          userPlaylist: widget.userPlaylist,
                                          showProgressSheet: true,
                                          displayDownloadItem: false,
                                          displayShuffle: false,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                          child: Icon(
                                            Broken.more_2,
                                            color: context.defaultIconColor(bgColor),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  );
                },
                slivers: [
                  const SliverPadding(padding: EdgeInsets.only(bottom: 4.0)),
                  SliverMainAxisGroup(
                    slivers: [
                      PinnedHeaderSliver(
                        child: ColoredBox(
                          color: theme.scaffoldBackgroundColor,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: sortWidget,
                                ),
                                ObxO(
                                  rx: _isLoadingMoreItems,
                                  builder: (context, isLoadingMoreItems) => NamidaInkWellButton(
                                    animationDurationMS: 100,
                                    sizeMultiplier: 0.95,
                                    borderRadius: 8.0,
                                    icon: Broken.task_square,
                                    text: lang.LOAD_ALL,
                                    enabled: !isLoadingMoreItems && hasMoreStreamsLeft, // this for lazylist
                                    disableWhenLoading: false,
                                    showLoadingWhenDisabled: hasMoreStreamsLeft,
                                    onTap: () async {
                                      if (_currentFetchAllRes != null) {
                                        _currentFetchAllRes?.cancel();
                                        _currentFetchAllRes = null;
                                      } else {
                                        _playlist.basicInfo.fetchAllPlaylistStreams(
                                          playlist: _playlist,
                                          showProgressSheet: false,
                                          onStart: () => _isLoadingMoreItems.value = true,
                                          onEnd: () => _isLoadingMoreItems.value = false,
                                          controller: (fetchAllRes) => _currentFetchAllRes = fetchAllRes,
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SliverFixedExtentList.builder(
                        itemExtent: itemsThumbnailItemExtent,
                        itemCount: playlist.items.length,
                        itemBuilder: (context, index) {
                          final item = playlist.items[index];
                          return YoutubeVideoCard(
                            properties: properties,
                            thumbnailHeight: itemsThumbnailHeight,
                            thumbnailWidth: itemsThumbnailWidth,
                            isImageImportantInCache: false,
                            video: item,
                            playlistID: plIdWrapper,
                            playlist: playlist,
                            playlistIndexAndCount: (index: index, totalLength: playlist.basicInfo.videosCount ?? playlist.items.length, playlistId: playlist.basicInfo.id),
                          );
                        },
                      ),
                    ],
                  ),
                  SliverToBoxAdapter(
                    child: ObxO(
                      rx: _isLoadingMoreItems,
                      builder: (context, isLoadingMoreItems) => isLoadingMoreItems
                          ? const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  LoadingIndicator(),
                                ],
                              ),
                            )
                          : const SizedBox(),
                    ),
                  ),
                  kBottomPaddingWidgetSliver,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// not meant for usage, just a placeholder instead of nullifying everything
class _EmptyPlaylistResult extends YoutiPiePlaylistResultBase {
  _EmptyPlaylistResult({
    required String playlistId,
  }) : super(
          basicInfo: PlaylistBasicInfo(id: playlistId, title: '', videosCountText: null, videosCount: null, thumbnails: []),
          items: [],
          cacheKey: null,
          continuation: null,
        );

  @override
  Future<bool> fetchNextFunction(ExecuteDetails? details) async {
    return false;
  }

  @override
  Map<String, dynamic> toMap() {
    return {};
  }
}
