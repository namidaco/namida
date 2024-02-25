import 'package:flutter/material.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:get/get.dart';
import 'package:known_extents_list_view_builder/known_extents_sliver_reorderable_list.dart';
import 'package:newpipeextractor_dart/models/stream_info_item.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart' as yt;
import 'package:playlist_manager/module/playlist_id.dart';

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
import 'package:namida/ui/pages/subpages/most_played_subpage.dart';
import 'package:namida/ui/pages/subpages/playlist_tracks_subpage.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart';
import 'package:namida/base/youtube_streams_manager.dart';
import 'package:namida/youtube/functions/yt_playlist_utils.dart';
import 'package:namida/youtube/pages/yt_playlist_download_subpage.dart';
import 'package:namida/youtube/widgets/yt_history_video_card.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:namida/youtube/widgets/yt_video_card.dart';

class YTMostPlayedVideosPage extends StatelessWidget {
  const YTMostPlayedVideosPage({super.key});

  MostPlayedItemsPage getMainWidget(List<String> videos) {
    final ytIds = videos
        .map(
          (e) => YoutubeID(
            id: e,
            playlistID: const PlaylistID(id: k_PLAYLIST_NAME_MOST_PLAYED),
          ),
        )
        .toList();
    return MostPlayedItemsPage(
      itemExtents: List.filled(videos.length, Dimensions.youtubeCardItemExtent),
      historyController: YoutubeHistoryController.inst,
      customDateRange: settings.ytMostPlayedCustomDateRange,
      isTimeRangeChipEnabled: (type) => type == settings.ytMostPlayedTimeRange.value,
      onSavingTimeRange: ({dateCustom, isStartOfDay, mptr}) {
        settings.save(
          ytMostPlayedTimeRange: mptr,
          ytMostPlayedCustomDateRange: dateCustom,
          ytMostPlayedCustomisStartOfDay: isStartOfDay,
        );
      },
      header: (timeRangeChips, bottomPadding) {
        return Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: timeRangeChips,
        );
      },
      itemBuilder: (context, i, listensMap) {
        final videoID = videos[i];
        final listens = listensMap[videoID] ?? [];

        return YTHistoryVideoCard(
          key: Key("${videoID}_$i"),
          videos: ytIds,
          index: i,
          day: null,
          overrideListens: listens,
          playlistID: const PlaylistID(id: k_PLAYLIST_NAME_MOST_PLAYED),
          playlistName: '',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final videos = YoutubeHistoryController.inst.currentMostPlayedTracks.toList();
        return getMainWidget(videos);
      },
    );
  }
}

class YTLikedVideosPage extends StatelessWidget {
  const YTLikedVideosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const YTNormalPlaylistSubpage(
      playlistName: k_PLAYLIST_NAME_FAV,
      isEditable: false,
      reversedList: true,
    );
  }
}

class YTNormalPlaylistSubpage extends StatefulWidget {
  final String playlistName;
  final bool isEditable;
  final bool reversedList;

  const YTNormalPlaylistSubpage({
    super.key,
    required this.playlistName,
    this.isEditable = true,
    this.reversedList = false,
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
    final bigThumbWidth = context.width - horizontalBigThumbPadding * 2;
    return AnimatedTheme(
      duration: const Duration(milliseconds: 300),
      data: AppThemes.inst.getAppTheme(bgColor, !context.isDarkMode),
      child: BackgroundWrapper(
        child: NamidaScrollbar(
          child: Obx(
            () {
              final playlist = YoutubePlaylistController.inst.getPlaylist(playlistCurrentName);
              if (playlist == null) return const SizedBox();
              final firstID = playlist.tracks.firstOrNull?.id;
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Stack(
                      children: [
                        YoutubeThumbnail(
                          key: Key("$firstID"),
                          width: context.width,
                          height: context.width * 9 / 16,
                          compressed: true,
                          isImportantInCache: false,
                          videoId: firstID,
                          blur: 0.0,
                          borderRadius: 0.0,
                          extractColor: true,
                          onColorReady: (color) async {
                            if (color != null) {
                              await Future.delayed(const Duration(milliseconds: 200)); // navigation delay
                              setState(() {
                                bgColor = color.color;
                              });
                            }
                          },
                        ),
                        const Positioned.fill(
                          child: ClipRect(
                            child: NamidaBgBlur(
                              blur: 30.0,
                              child: ColoredBox(color: Colors.transparent),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: horizontalBigThumbPadding, vertical: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              YoutubeThumbnail(
                                key: Key("$firstID"),
                                width: bigThumbWidth,
                                height: (bigThumbWidth * 9 / 16),
                                compressed: false,
                                isImportantInCache: true,
                                videoId: firstID,
                                blur: 4.0,
                              ),
                              const SizedBox(height: 24.0),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          playlistCurrentName.translatePlaylistName(liked: true),
                                          style: context.textTheme.displayLarge,
                                        ),
                                        const SizedBox(height: 6.0),
                                        Text(
                                          playlist.tracks.length.displayVideoKeyword,
                                          style: context.textTheme.displaySmall,
                                        ),
                                        if (playlist.comment != '') ...[
                                          const SizedBox(height: 2.0),
                                          Text(
                                            playlist.comment,
                                            style: context.textTheme.displaySmall,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  NamidaIconButton(
                                    iconColor: context.defaultIconColor(bgColor),
                                    icon: Broken.shuffle,
                                    tooltip: lang.SHUFFLE,
                                    onPressed: () => Player.inst.playOrPause(0, playlist.tracks, QueueSource.others, shuffle: true),
                                  ),
                                  NamidaIconButton(
                                    iconColor: context.defaultIconColor(bgColor),
                                    icon: Broken.play_cricle,
                                    tooltip: lang.PLAY_LAST,
                                    onPressed: () => Player.inst.addToQueue(playlist.tracks, insertNext: false),
                                  ),
                                  NamidaIconButton(
                                    iconColor: context.defaultIconColor(bgColor),
                                    icon: Broken.import,
                                    onPressed: () async {
                                      NamidaNavigator.inst.navigateTo(
                                        YTPlaylistDownloadPage(
                                          ids: playlist.tracks,
                                          playlistName: playlistCurrentName,
                                          infoLookup: const {},
                                        ),
                                      );
                                    },
                                  ),
                                  NamidaPopupWrapper(
                                    openOnLongPress: false,
                                    childrenDefault: () => [
                                      NamidaPopupItem(icon: Broken.share, title: lang.SHARE, onTap: playlist.shareVideos),
                                      if (widget.isEditable) ...[
                                        NamidaPopupItem(
                                          icon: Broken.edit_2,
                                          title: lang.RENAME_PLAYLIST,
                                          onTap: () async {
                                            final newName = await playlist.showRenamePlaylistSheet(context: context, playlistName: playlistCurrentName);
                                            if (context.mounted) {
                                              setState(() {
                                                playlistCurrentName = newName;
                                              });
                                            }
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
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 24.0)),
                  SliverKnownExtentsReorderableList(
                    overlayOffset: Offset.zero,
                    onReorder: (oldIndex, newIndex) => YoutubePlaylistController.inst.reorderTrack(playlist, oldIndex, newIndex),
                    itemExtents: List.filled(playlist.tracks.length, Dimensions.youtubeCardItemExtent),
                    itemCount: playlist.tracks.length,
                    itemBuilder: (context, index) {
                      return YTHistoryVideoCard(
                        key: Key("$index"),
                        videos: playlist.tracks,
                        index: index,
                        reversedList: widget.reversedList,
                        day: null,
                        playlistID: playlist.playlistID,
                        playlistName: playlistCurrentName,
                        draggingEnabled: YoutubePlaylistController.inst.canReorderVideos.value,
                        draggableThumbnail: true,
                        showMoreIcon: true,
                        draggingBarsBuilder: (color) {
                          return Obx(
                            () => ThreeLineSmallContainers(enabled: YoutubePlaylistController.inst.canReorderVideos.value, color: color),
                          );
                        },
                        draggingThumbnailBuilder: (draggingTrigger) {
                          return Obx(() => YoutubePlaylistController.inst.canReorderVideos.value ? draggingTrigger : const SizedBox());
                        },
                      );
                    },
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

class YTHostedPlaylistSubpage extends StatefulWidget {
  final yt.YoutubePlaylist playlist;

  const YTHostedPlaylistSubpage({
    super.key,
    required this.playlist,
  });

  @override
  State<YTHostedPlaylistSubpage> createState() => _YTHostedPlaylistSubpageState();
}

class _YTHostedPlaylistSubpageState extends State<YTHostedPlaylistSubpage> with YoutubeStreamsManager {
  @override
  List<StreamInfoItem> get streamsList => widget.playlist.streams;

  @override
  ScrollController get scrollController => controller;

  @override
  Color? get sortChipBGColor => bgColor?.withOpacity(0.6);

  @override
  void onSortChanged(void Function() fn) => setState(fn);

  late final ScrollController controller;
  final _isLoadingMoreItems = false.obs;

  bool _canKeepFetching = false;

  void _scrollListener() async {
    if (_isLoadingMoreItems.value) return;
    if (!controller.hasClients) return;

    final fetched = widget.playlist.streams.length;
    final total = widget.playlist.streamCount;
    // -- mainly a workaround for playlists containing hidden videos
    // -- works only for small playlists (<=100 videos).
    if (fetched > 0 && fetched <= 100 && total > 0 && total <= 100) return;
    final needsToLoadMore = total >= 0 && fetched < total;
    if (needsToLoadMore && controller.offset >= controller.position.maxScrollExtent - 400 && !controller.position.outOfRange) {
      await _fetch100Video();
    }
  }

  @override
  void initState() {
    super.initState();
    controller = ScrollController()..addListener(_scrollListener);
    _fetch100Video();
  }

  @override
  void dispose() {
    controller.removeListener(_scrollListener);
    controller.dispose();
    _isLoadingMoreItems.close();
    disposeResources();
    super.dispose();
  }

  Color? bgColor;

  Future<List<YoutubeID>> _getAllPlaylistVideos() async {
    return await widget.playlist.fetchAllPlaylistAsYTIDs(context: context);
  }

  PlaylistID? get _getPlaylistID {
    final plId = widget.playlist.id;
    return plId == null ? null : PlaylistID(id: plId);
  }

  Future<void> _fetch100Video() async {
    _isLoadingMoreItems.value = true;
    await YoutubeController.inst.getPlaylistStreams(widget.playlist, forceInitial: widget.playlist.streams.isEmpty);
    trySortStreams();
    _isLoadingMoreItems.value = false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    const horizontalBigThumbPadding = 12.0;
    final bigThumbWidth = context.width - horizontalBigThumbPadding * 2;
    final playlist = widget.playlist;

    const hmultiplier = 0.3;
    final itemsThumbnailWidth = context.width * hmultiplier;
    final itemsThumbnailHeight = itemsThumbnailWidth * 9 / 16;
    final itemsThumbnailItemExtent = itemsThumbnailHeight + 8.0 * 2;

    final firstID = playlist.streams.firstOrNull?.id;
    final hasMoreStreamsLeft = playlist.streams.length < playlist.streamCount;
    return AnimatedTheme(
      duration: const Duration(milliseconds: 300),
      data: AppThemes.inst.getAppTheme(bgColor, !context.isDarkMode),
      child: BackgroundWrapper(
        child: NamidaScrollbar(
          controller: controller,
          child: CustomScrollView(
            controller: controller,
            slivers: [
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    YoutubeThumbnail(
                      key: Key("$firstID"),
                      width: context.width,
                      height: context.width * 9 / 16,
                      compressed: true,
                      isImportantInCache: false,
                      channelUrl: playlist.thumbnailUrl,
                      videoId: firstID,
                      blur: 0.0,
                      borderRadius: 0.0,
                      extractColor: true,
                      onColorReady: (color) async {
                        if (color != null) {
                          await Future.delayed(const Duration(milliseconds: 200)); // navigation delay
                          setState(() {
                            bgColor = color.color;
                          });
                        }
                      },
                    ),
                    const Positioned.fill(
                      child: ClipRect(
                        child: NamidaBgBlur(
                          blur: 30.0,
                          child: ColoredBox(color: Colors.transparent),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: horizontalBigThumbPadding, vertical: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          YoutubeThumbnail(
                            key: Key("$firstID"),
                            width: bigThumbWidth,
                            height: (bigThumbWidth * 9 / 16),
                            compressed: false,
                            isImportantInCache: true,
                            channelUrl: playlist.thumbnailUrl,
                            videoId: firstID,
                            blur: 4.0,
                          ),
                          const SizedBox(height: 24.0),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      playlist.name ?? '',
                                      style: context.textTheme.displayLarge,
                                    ),
                                    const SizedBox(height: 6.0),
                                    Text(
                                      playlist.streamCount < 0 ? '+25' : playlist.streamCount.displayVideoKeyword,
                                      style: context.textTheme.displaySmall,
                                    ),
                                    const SizedBox(height: 2.0),
                                    Text(
                                      playlist.uploaderName ?? '',
                                      style: context.textTheme.displaySmall,
                                    ),
                                    if (playlist.description != null && playlist.description != '') ...[
                                      const SizedBox(height: 2.0),
                                      Text(
                                        playlist.description!,
                                        style: context.textTheme.displaySmall,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              NamidaIconButton(
                                iconColor: context.defaultIconColor(bgColor),
                                icon: Broken.shuffle,
                                tooltip: lang.SHUFFLE,
                                onPressed: () async {
                                  final videos = await _getAllPlaylistVideos();
                                  Player.inst.playOrPause(0, videos, QueueSource.others, shuffle: true);
                                },
                              ),
                              NamidaIconButton(
                                iconColor: context.defaultIconColor(bgColor),
                                icon: Broken.play_cricle,
                                tooltip: lang.PLAY_LAST,
                                onPressed: () async {
                                  final videos = await _getAllPlaylistVideos();
                                  Player.inst.addToQueue(videos, insertNext: false);
                                },
                              ),
                              NamidaIconButton(
                                iconColor: context.defaultIconColor(bgColor),
                                icon: Broken.import,
                                onPressed: () async {
                                  final videos = await _getAllPlaylistVideos();
                                  NamidaNavigator.inst.navigateTo(
                                    YTPlaylistDownloadPage(
                                      ids: videos,
                                      playlistName: playlist.name ?? '',
                                      infoLookup: const {},
                                    ),
                                  );
                                },
                              ),
                              NamidaPopupWrapper(
                                openOnLongPress: false,
                                childrenDefault: () => playlist.getPopupMenuItems(
                                  context,
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
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 4.0)),
              SliverStickyHeader.builder(
                builder: (context, state) => ColoredBox(
                  color: context.theme.scaffoldBackgroundColor,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: sortWidget,
                        ),
                        Obx(
                          () => NamidaInkWellButton(
                            animationDurationMS: 100,
                            sizeMultiplier: 0.95,
                            borderRadius: 8.0,
                            icon: Broken.task_square,
                            text: lang.LOAD_ALL,
                            enabled: !_isLoadingMoreItems.value && hasMoreStreamsLeft,
                            disableWhenLoading: false,
                            showLoadingWhenDisabled: hasMoreStreamsLeft,
                            onTap: () async {
                              _canKeepFetching = !_canKeepFetching;
                              widget.playlist.fetchAllPlaylistStreams(
                                context: null,
                                onStart: () => _isLoadingMoreItems.value = true,
                                onEnd: () => _isLoadingMoreItems.value = false,
                                canKeepFetching: () => _canKeepFetching,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                sliver: SliverFixedExtentList.builder(
                  itemExtent: itemsThumbnailItemExtent,
                  itemCount: playlist.streams.length,
                  itemBuilder: (context, index) {
                    final item = playlist.streams[index];
                    return YoutubeVideoCard(
                      thumbnailHeight: itemsThumbnailHeight,
                      thumbnailWidth: itemsThumbnailWidth,
                      isImageImportantInCache: false,
                      video: item,
                      playlistID: _getPlaylistID,
                      playlist: playlist,
                      index: index,
                    );
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: Obx(
                  () => _isLoadingMoreItems.value
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
    );
  }
}
