import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:jiffy/jiffy.dart';
import 'package:share_plus/share_plus.dart';
import 'package:youtipie/class/youtipie_feed/playlist_info_item.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item_short.dart';

import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/mp.dart';
import 'package:namida/packages/scroll_physics_modified.dart';
import 'package:namida/packages/three_arched_circle.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart';
import 'package:namida/youtube/controller/yt_miniplayer_ui_controller.dart';
import 'package:namida/youtube/functions/add_to_playlist_sheet.dart';
import 'package:namida/youtube/functions/download_sheet.dart';
import 'package:namida/youtube/functions/video_listens_dialog.dart';
import 'package:namida/youtube/pages/yt_channel_subpage.dart';
import 'package:namida/youtube/seek_ready_widget.dart';
import 'package:namida/youtube/widgets/yt_action_button.dart';
import 'package:namida/youtube/widgets/yt_comment_card.dart';
import 'package:namida/youtube/widgets/yt_playlist_card.dart';
import 'package:namida/youtube/widgets/yt_queue_chip.dart';
import 'package:namida/youtube/widgets/yt_shimmer.dart';
import 'package:namida/youtube/widgets/yt_subscribe_buttons.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:namida/youtube/widgets/yt_video_card.dart';
import 'package:namida/youtube/yt_miniplayer_comments_subpage.dart';
import 'package:namida/youtube/yt_utils.dart';
import 'package:youtipie/youtipie.dart';

const _space2ForThumbnail = 90.0;
const _extraPaddingForYTMiniplayer = 12.0;
const kYoutubeMiniplayerHeight = _extraPaddingForYTMiniplayer + _space2ForThumbnail * 9 / 16;

class YoutubeMiniPlayer extends StatefulWidget {
  const YoutubeMiniPlayer({super.key});

  @override
  State<YoutubeMiniPlayer> createState() => YoutubeMiniPlayerState();
}

class YoutubeMiniPlayerState extends State<YoutubeMiniPlayer> {
  final _numberOfRepeats = 1.obs;
  bool _canScrollQueue = true;

  NamidaYTMiniplayerState? get _mpState => MiniPlayerController.inst.ytMiniplayerKey.currentState;

  final _velocity = VelocityTracker.withKind(PointerDeviceKind.touch);

  void _updateCanScrollQueue(bool can) {
    if (_canScrollQueue == can) return;
    setState(() => _canScrollQueue = can);
  }

  final _scrollController = ScrollController();

  void resetGlowUnderVideo() => _shouldShowGlowUnderVideo.value = false;

  final _shouldShowGlowUnderVideo = false.obs;
  final _isTitleExpanded = false.obs;
  final _canDimMiniplayer = false.obs;
  Timer? _dimTimer;

  void cancelDimTimer() {
    _dimTimer?.cancel();
    _dimTimer = null;
    _canDimMiniplayer.value = false;
  }

  void startDimTimer() {
    cancelDimTimer();
    final int defaultMiniplayerDimSeconds = settings.ytMiniplayerDimAfterSeconds.value;
    if (defaultMiniplayerDimSeconds <= 0) return;
    final double defaultMiniplayerOpacity = settings.ytMiniplayerDimOpacity.value;
    if (defaultMiniplayerOpacity <= 0) return;
    _dimTimer = Timer(Duration(seconds: defaultMiniplayerDimSeconds), () {
      _canDimMiniplayer.value = true;
    });
  }

  void _onVideoPageReset() {
    try {
      _scrollController.jumpTo(0);
    } catch (_) {}
    resetGlowUnderVideo();
    startDimTimer();
    _isTitleExpanded.value = false;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final pixels = _scrollController.positions.lastOrNull?.pixels;
      final hasScrolledEnough = pixels != null && pixels > 40;
      _shouldShowGlowUnderVideo.value = hasScrolledEnough;
    });
    YoutubeInfoController.current.onVideoPageReset = _onVideoPageReset;
  }

  @override
  void dispose() {
    YoutubeInfoController.current.onVideoPageReset = null;
    _scrollController.dispose();
    _numberOfRepeats.close();
    _isTitleExpanded.close();
    _shouldShowGlowUnderVideo.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const space1sb = 8.0;
    const space2ForThumbnail = _space2ForThumbnail;
    const space3sb = 8.0;
    const space4 = 38.0 * 2;
    const space5sb = 8.0;
    const miniplayerHeight = kYoutubeMiniplayerHeight;

    const relatedThumbnailHeight = Dimensions.youtubeThumbnailHeight;
    const relatedThumbnailWidth = Dimensions.youtubeThumbnailWidth;
    const relatedThumbnailItemExtent = relatedThumbnailHeight + 8.0 * 2;

    const seekReadyWidget = SeekReadyWidget();

    final maxWidth = context.width;
    final mainTheme = context.theme;
    final mainTextTheme = context.textTheme;

    final miniplayerBGColor = Color.alphaBlend(mainTheme.secondaryHeaderColor.withOpacity(0.25), mainTheme.scaffoldBackgroundColor);

    final absorbBottomDragWidget = AbsorbPointer(
      child: SizedBox(
        height: 18.0,
        width: maxWidth,
      ),
    );

    final miniplayerDimWidget = Positioned.fill(
      key: const Key('dimmie'),
      child: IgnorePointer(
        child: ObxO(
          rx: _canDimMiniplayer,
          builder: (canDimMiniplayer) => AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            reverseDuration: const Duration(milliseconds: 200),
            child: canDimMiniplayer
                ? ObxO(
                    rx: settings.ytMiniplayerDimOpacity,
                    builder: (dimOpacity) => Container(
                      color: Colors.black.withOpacity(dimOpacity),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
    final ytMiniplayerQueueChip = YTMiniplayerQueueChip(key: NamidaNavigator.inst.ytQueueSheetKey);

    final rightDragAbsorberWidget = Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        height: context.height,
        width: (maxWidth * 0.25).withMaximum(324.0),
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            if (NamidaNavigator.inst.isInYTCommentsSubpage) return;
            _mpState?.updatePercentageMultiplier(true);
            _mpState?.setDragExternally(true);
            _mpState?.saveDragHeightStart();
            _velocity.addPosition(event.timeStamp, event.position);
          },
          onPointerMove: (event) {
            if (NamidaNavigator.inst.isInYTCommentsSubpage) return;
            if (!_canScrollQueue) {
              _mpState?.onVerticalDragUpdate(event.delta.dy);
              _velocity.addPosition(event.timeStamp, event.position);
            }
          },
          onPointerUp: (event) {
            if (NamidaNavigator.inst.isInYTCommentsSubpage) return;
            if (_scrollController.hasClients && _scrollController.position.pixels <= 0) {
              _mpState?.onVerticalDragEnd(_velocity.getVelocity().pixelsPerSecond.dy);
            }
            _mpState?.updatePercentageMultiplier(false);
            // thats because the internal GestureDetector executes drag end after Listener's onPointerUp
            WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
              _mpState?.setDragExternally(false);
            });
          },
        ),
      ),
    );

    return DefaultTextStyle(
      style: mainTextTheme.displayMedium!,
      child: ObxO(
        rx: YoutubePlaylistController.inst.favouritesPlaylist,
        builder: (favouritesPlaylist) {
          return ObxO(
            rx: Player.inst.currentItem,
            builder: (currentItem) {
              if (currentItem is! YoutubeID) return const SizedBox();

              final currentId = currentItem.id;
              final isUserLiked = favouritesPlaylist.tracks.firstWhereEff((element) => element.id == currentId) != null;

              return ObxO(
                rx: YoutubeInfoController.current.currentYTStreams,
                builder: (streams) => ObxO(
                  rx: YoutubeInfoController.current.currentVideoPage,
                  builder: (page) {
                    final videoInfo = page?.videoInfo;
                    final videoInfoStream = streams?.info;
                    final channel = page?.channelInfo;

                    String? uploadDate;
                    String? uploadDateAgo;

                    final parsedDate = videoInfo?.publishedAt.date ?? videoInfoStream?.publishedAt.date ?? videoInfoStream?.publishDate.date;

                    if (parsedDate != null) {
                      uploadDate = parsedDate.millisecondsSinceEpoch.dateFormattedOriginal;
                      uploadDateAgo = Jiffy.parseFromDateTime(parsedDate).fromNow();
                    } else {
                      uploadDateAgo = videoInfo?.publishedFromText;
                    }
                    final videoTitle = videoInfo?.title ?? videoInfoStream?.title;
                    final channelName = channel?.title ?? videoInfoStream?.channelName;

                    final channelThumbnail = channel?.thumbnails.pick()?.url;
                    final channelIsVerified = channel?.isVerified ?? false;
                    final channelSubs = channel?.subscribersCount;
                    final channelID = channel?.id ?? videoInfoStream?.channelId;

                    final videoLikeCount = (isUserLiked ? 1 : 0) + (videoInfo?.engagement?.likesCount ?? 0);
                    const int? videoDislikeCount = null;
                    final videoViewCount = videoInfo?.viewsCount;

                    final description = videoInfo?.description;
                    final descriptionWidget = description == null || description == ''
                        ? null
                        : SelectionArea(
                            child: Html(
                              data: description,
                              style: {
                                '*': Style.fromTextStyle(
                                  mainTextTheme.displayMedium!.copyWith(
                                    fontSize: 14.0,
                                  ),
                                ),
                                'a': Style.fromTextStyle(
                                  mainTextTheme.displayMedium!.copyWith(
                                    color: mainTheme.colorScheme.primary.withAlpha(210),
                                    fontSize: 13.5,
                                  ),
                                )
                              },
                              onLinkTap: (url, attributes, element) async {
                                if (url != null) {
                                  final partsDur = url.split("$currentId&t=");
                                  if (partsDur.length > 1) {
                                    try {
                                      await Player.inst.seek(Duration(seconds: int.parse(partsDur.last)));
                                    } catch (e) {
                                      snackyy(title: lang.ERROR, message: e.toString(), isError: true, top: false);
                                    }
                                  } else {
                                    await NamidaLinkUtils.openLink(url);
                                  }
                                }
                              },
                            ),
                          );

                    YoutubeController.inst.downloadedFilesMap; // for refreshing.
                    final downloadedFileExists = YoutubeController.inst.doesIDHasFileDownloaded(currentId) != null;

                    final defaultIconColor = context.defaultIconColor(CurrentColor.inst.miniplayerColor);

                    // ====  MiniPlayer Body, contains title, description, comments, ..etc. ====
                    final miniplayerBody = Stack(
                      alignment: Alignment.bottomCenter, // bottom alignment is for touch absorber
                      children: [
                        // opacity: (percentage * 4 - 3).withMinimum(0),
                        Listener(
                          key: Key("${currentId}_body_listener"),
                          onPointerMove: (event) {
                            if (event.delta.dy > 0) {
                              if (_scrollController.hasClients) {
                                if (_scrollController.position.pixels <= 0) {
                                  _updateCanScrollQueue(false);
                                }
                              }
                            } else {
                              if (_mpState == null || _mpState?.controller.value == 1) _updateCanScrollQueue(true);
                            }
                          },
                          onPointerDown: (_) {
                            cancelDimTimer();
                            _updateCanScrollQueue(true);
                          },
                          onPointerUp: (_) {
                            startDimTimer();
                            _updateCanScrollQueue(true);
                          },
                          child: Navigator(
                            key: NamidaNavigator.inst.ytMiniplayerCommentsPageKey,
                            requestFocus: false,
                            onPopPage: (route, result) => false,
                            restorationScopeId: currentId,
                            pages: [
                              MaterialPage(
                                maintainState: true,
                                child: IgnorePointer(
                                  ignoring: !_canScrollQueue,
                                  child: LazyLoadListView(
                                    key: Key("${currentId}_body_lazy_load_list"),
                                    onReachingEnd: () async {
                                      if (settings.ytTopComments.value) return;
                                      await YoutubeInfoController.current.updateCurrentComments(currentId);
                                    },
                                    extend: 400,
                                    scrollController: _scrollController,
                                    listview: (controller) => Stack(
                                      key: Key("${currentId}_body_stack"),
                                      children: [
                                        CustomScrollView(
                                          // key: PageStorageKey(currentId), // duplicate errors
                                          physics: _canScrollQueue ? const ClampingScrollPhysicsModified() : const NeverScrollableScrollPhysics(),
                                          controller: controller,
                                          slivers: [
                                            // --START-- title & subtitle
                                            SliverToBoxAdapter(
                                              key: Key("${currentId}_title"),
                                              child: ShimmerWrapper(
                                                shimmerDurationMS: 550,
                                                shimmerDelayMS: 250,
                                                shimmerEnabled: page == null,
                                                child: ExpansionTile(
                                                  // key: Key(currentId),
                                                  initiallyExpanded: false,
                                                  maintainState: false,
                                                  expandedAlignment: Alignment.centerLeft,
                                                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                                                  tilePadding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 14.0),
                                                  textColor: Color.alphaBlend(CurrentColor.inst.miniplayerColor.withAlpha(40), mainTheme.colorScheme.onSurface),
                                                  collapsedTextColor: mainTheme.colorScheme.onSurface,
                                                  iconColor: Color.alphaBlend(CurrentColor.inst.miniplayerColor.withAlpha(40), mainTheme.colorScheme.onSurface),
                                                  collapsedIconColor: mainTheme.colorScheme.onSurface,
                                                  childrenPadding: const EdgeInsets.all(18.0),
                                                  onExpansionChanged: (value) => _isTitleExpanded.value = value,
                                                  trailing: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Obx(
                                                        () {
                                                          final videoListens = YoutubeHistoryController.inst.topTracksMapListens[currentId] ?? [];
                                                          if (videoListens.isEmpty) return const SizedBox();
                                                          return NamidaInkWell(
                                                            borderRadius: 6.0,
                                                            bgColor: CurrentColor.inst.miniplayerColor.withOpacity(0.7),
                                                            onTap: () {
                                                              showVideoListensDialog(currentId);
                                                            },
                                                            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                                                            child: Text(
                                                              videoListens.length.formatDecimal(),
                                                              style: mainTextTheme.displaySmall?.copyWith(
                                                                color: Colors.white.withOpacity(0.6),
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                      const SizedBox(width: 8.0),
                                                      NamidaPopupWrapper(
                                                        onPop: () {
                                                          _numberOfRepeats.value = 1;
                                                        },
                                                        childrenDefault: () {
                                                          final videoId = currentId;
                                                          final items = YTUtils.getVideoCardMenuItems(
                                                            videoId: videoId,
                                                            url: videoInfo?.buildUrl(),
                                                            channelID: channelID,
                                                            playlistID: null,
                                                            idsNamesLookup: {videoId: videoTitle},
                                                          );
                                                          if (Player.inst.currentVideo != null && videoId == Player.inst.currentVideo?.id) {
                                                            final repeatForWidget = NamidaPopupItem(
                                                              icon: Broken.cd,
                                                              title: '',
                                                              titleBuilder: (style) => Obx(
                                                                () => Text(
                                                                  lang.REPEAT_FOR_N_TIMES.replaceFirst('_NUM_', _numberOfRepeats.valueR.toString()),
                                                                  style: style,
                                                                ),
                                                              ),
                                                              onTap: () {
                                                                settings.player.save(repeatMode: RepeatMode.forNtimes);
                                                                Player.inst.updateNumberOfRepeats(_numberOfRepeats.value);
                                                              },
                                                              trailing: Row(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  NamidaIconButton(
                                                                    icon: Broken.minus_cirlce,
                                                                    onPressed: () => _numberOfRepeats.value = (_numberOfRepeats.value - 1).clamp(1, 20),
                                                                    iconSize: 20.0,
                                                                  ),
                                                                  NamidaIconButton(
                                                                    icon: Broken.add_circle,
                                                                    onPressed: () => _numberOfRepeats.value = (_numberOfRepeats.value + 1).clamp(1, 20),
                                                                    iconSize: 20.0,
                                                                  ),
                                                                ],
                                                              ),
                                                            );
                                                            items.add(repeatForWidget);
                                                          }
                                                          items.add(
                                                            NamidaPopupItem(
                                                              icon: Broken.trash,
                                                              title: lang.CLEAR,
                                                              onTap: () {
                                                                YTUtils().showVideoClearDialog(context, videoId, CurrentColor.inst.miniplayerColor);
                                                              },
                                                            ),
                                                          );
                                                          return items;
                                                        },
                                                        child: const Icon(
                                                          Broken.arrow_down_2,
                                                          size: 20.0,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  title: ObxO(
                                                    rx: _isTitleExpanded,
                                                    builder: (isTitleExpanded) {
                                                      String? dateToShow;
                                                      if (isTitleExpanded) {
                                                        dateToShow = uploadDate ?? uploadDateAgo;
                                                      } else {
                                                        dateToShow = uploadDateAgo ?? uploadDate;
                                                      }
                                                      return Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          NamidaDummyContainer(
                                                            width: maxWidth * 0.8,
                                                            height: 24.0,
                                                            borderRadius: 6.0,
                                                            shimmerEnabled: page == null,
                                                            child: Text(
                                                              videoTitle ?? '',
                                                              maxLines: isTitleExpanded ? 6 : 2,
                                                              overflow: TextOverflow.ellipsis,
                                                              style: mainTextTheme.displayLarge,
                                                            ),
                                                          ),
                                                          const SizedBox(height: 4.0),
                                                          NamidaDummyContainer(
                                                            width: maxWidth * 0.7,
                                                            height: 12.0,
                                                            shimmerEnabled: page == null,
                                                            child: Text(
                                                              [
                                                                if (videoViewCount != null)
                                                                  "${videoViewCount.formatDecimalShort(isTitleExpanded)} ${videoViewCount == 0 ? lang.VIEW : lang.VIEWS}",
                                                                if (dateToShow != null) dateToShow,
                                                              ].join(' • '),
                                                              style: mainTextTheme.displaySmall?.copyWith(fontWeight: FontWeight.w500),
                                                            ),
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  ),
                                                  children: [
                                                    if (descriptionWidget != null) descriptionWidget,
                                                  ],
                                                ),
                                              ),
                                            ),

                                            // --END-- title & subtitle

                                            // --START-- buttons
                                            SliverToBoxAdapter(
                                              key: Key("${currentId}_buttons"),
                                              child: ShimmerWrapper(
                                                shimmerDurationMS: 550,
                                                shimmerDelayMS: 250,
                                                shimmerEnabled: page == null,
                                                child: SizedBox(
                                                  width: maxWidth,
                                                  child: Wrap(
                                                    alignment: WrapAlignment.spaceEvenly,
                                                    children: [
                                                      const SizedBox(width: 4.0),
                                                      ObxO(
                                                        rx: _isTitleExpanded,
                                                        builder: (isTitleExpanded) => SmallYTActionButton(
                                                          title: page == null
                                                              ? null
                                                              : videoLikeCount < 1
                                                                  ? lang.LIKE
                                                                  : videoLikeCount.formatDecimalShort(isTitleExpanded),
                                                          icon: Broken.like_1,
                                                          smallIconWidget: FittedBox(
                                                            child: NamidaRawLikeButton(
                                                              likedIcon: Broken.like_filled,
                                                              normalIcon: Broken.like_1,
                                                              disabledColor: mainTheme.iconTheme.color,
                                                              isLiked: isUserLiked,
                                                              onTap: (isLiked) async {
                                                                YoutubePlaylistController.inst.favouriteButtonOnPressed(currentId);
                                                              },
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4.0),
                                                      ObxO(
                                                        rx: _isTitleExpanded,
                                                        builder: (isTitleExpanded) => SmallYTActionButton(
                                                          title: (videoDislikeCount ?? 0) < 1 ? lang.DISLIKE : videoDislikeCount?.formatDecimalShort(isTitleExpanded) ?? '?',
                                                          icon: Broken.dislike,
                                                          onPressed: () {},
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4.0),
                                                      SmallYTActionButton(
                                                        title: lang.SHARE,
                                                        icon: Broken.share,
                                                        onPressed: () {
                                                          final url = videoInfo?.buildUrl();
                                                          if (url != null) Share.share(url);
                                                        },
                                                      ),
                                                      const SizedBox(width: 4.0),
                                                      SmallYTActionButton(
                                                        title: lang.REFRESH,
                                                        icon: Broken.refresh,
                                                        onPressed: () async => await YoutubeInfoController.current.updateVideoPage(
                                                          currentId,
                                                          forceRequestPage: true,
                                                          forceRequestComments: true,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4.0),
                                                      Obx(
                                                        () {
                                                          final audioProgress = YoutubeController.inst.downloadsAudioProgressMap[currentId]?.values.firstOrNull;
                                                          final audioPercText = audioProgress?.percentageText(prefix: lang.AUDIO);
                                                          final videoProgress = YoutubeController.inst.downloadsVideoProgressMap[currentId]?.values.firstOrNull;
                                                          final videoPercText = videoProgress?.percentageText(prefix: lang.VIDEO);

                                                          final isDownloading = YoutubeController.inst.isDownloading[currentId]?.values.any((element) => element) == true;

                                                          final wasDownloading = videoProgress != null || audioProgress != null;
                                                          final icon = (wasDownloading && !isDownloading)
                                                              ? Broken.play_circle
                                                              : wasDownloading
                                                                  ? Broken.pause_circle
                                                                  : downloadedFileExists
                                                                      ? Broken.tick_circle
                                                                      : Broken.import;
                                                          return SmallYTActionButton(
                                                            titleWidget: videoPercText == null && audioPercText == null && isDownloading ? const LoadingIndicator() : null,
                                                            title: videoPercText ?? audioPercText ?? lang.DOWNLOAD,
                                                            icon: icon,
                                                            onLongPress: () async => await showDownloadVideoBottomSheet(videoId: currentId),
                                                            onPressed: () async {
                                                              if (isDownloading) {
                                                                YoutubeController.inst.pauseDownloadTask(
                                                                  itemsConfig: [],
                                                                  videosIds: [currentId],
                                                                  groupName: '',
                                                                );
                                                              } else if (wasDownloading) {
                                                                YoutubeController.inst.resumeDownloadTaskForIDs(
                                                                  videosIds: [currentId],
                                                                  groupName: '',
                                                                );
                                                              } else {
                                                                await showDownloadVideoBottomSheet(videoId: currentId);
                                                              }
                                                            },
                                                          );
                                                        },
                                                      ),
                                                      const SizedBox(width: 4.0),
                                                      SmallYTActionButton(
                                                        title: lang.SAVE,
                                                        icon: Broken.music_playlist,
                                                        onPressed: () => showAddToPlaylistSheet(
                                                          ids: [currentId],
                                                          idsNamesLookup: {
                                                            currentId: videoTitle ?? '',
                                                          },
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4.0),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SliverPadding(padding: EdgeInsets.only(top: 24.0)),
                                            // --END- buttons

                                            // --START- channel
                                            SliverToBoxAdapter(
                                              key: Key("${currentId}_channel"),
                                              child: ShimmerWrapper(
                                                shimmerDurationMS: 550,
                                                shimmerDelayMS: 250,
                                                shimmerEnabled: channelName == null || channelThumbnail == null || channelSubs == null,
                                                child: Material(
                                                  type: MaterialType.transparency,
                                                  child: InkWell(
                                                    onTap: () {
                                                      final ch = channel ?? YoutubeInfoController.current.currentVideoPage.value?.channelInfo;
                                                      final chid = ch?.id;
                                                      if (chid != null) NamidaNavigator.inst.navigateTo(YTChannelSubpage(channelID: chid, channel: ch));
                                                    },
                                                    child: Row(
                                                      children: [
                                                        const SizedBox(width: 18.0),
                                                        NamidaDummyContainer(
                                                          width: 42.0,
                                                          height: 42.0,
                                                          borderRadius: 100.0,
                                                          shimmerEnabled: channelThumbnail == null && (channelID == null || channelID.isEmpty),
                                                          child: YoutubeThumbnail(
                                                            key: Key("${channelThumbnail}_$channelID"),
                                                            isImportantInCache: true,
                                                            customUrl: channelThumbnail,
                                                            width: 42.0,
                                                            height: 42.0,
                                                            isCircle: true,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8.0),
                                                        Expanded(
                                                          // key: Key(currentId),
                                                          child: Column(
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              FittedBox(
                                                                child: Row(
                                                                  children: [
                                                                    NamidaDummyContainer(
                                                                      width: 114.0,
                                                                      height: 12.0,
                                                                      borderRadius: 4.0,
                                                                      shimmerEnabled: channelName == null,
                                                                      child: Text(
                                                                        channelName ?? '',
                                                                        style: mainTextTheme.displayMedium?.copyWith(
                                                                          fontSize: 13.5,
                                                                        ),
                                                                        maxLines: 1,
                                                                        overflow: TextOverflow.ellipsis,
                                                                        textAlign: TextAlign.start,
                                                                      ),
                                                                    ),
                                                                    if (channelIsVerified) ...[
                                                                      const SizedBox(width: 4.0),
                                                                      const Icon(
                                                                        Broken.shield_tick,
                                                                        size: 12.0,
                                                                      ),
                                                                    ]
                                                                  ],
                                                                ),
                                                              ),
                                                              const SizedBox(height: 2.0),
                                                              FittedBox(
                                                                child: NamidaDummyContainer(
                                                                  width: 92.0,
                                                                  height: 10.0,
                                                                  borderRadius: 4.0,
                                                                  shimmerEnabled: channelSubs == null,
                                                                  child: ObxO(
                                                                    rx: _isTitleExpanded,
                                                                    builder: (isTitleExpanded) => Text(
                                                                      channelSubs == null
                                                                          ? '? ${lang.SUBSCRIBERS}'
                                                                          : [
                                                                              channelSubs.formatDecimalShort(isTitleExpanded),
                                                                              channelSubs < 2 ? lang.SUBSCRIBER : lang.SUBSCRIBERS,
                                                                            ].join(' '),
                                                                      style: mainTextTheme.displaySmall?.copyWith(
                                                                        fontSize: 12.0,
                                                                      ),
                                                                      maxLines: 1,
                                                                      overflow: TextOverflow.ellipsis,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        const SizedBox(width: 12.0),
                                                        YTSubscribeButton(channelID: channelID),
                                                        const SizedBox(width: 20.0),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SliverPadding(padding: EdgeInsets.only(top: 4.0)),
                                            // --END-- channel

                                            // --SRART-- top comments
                                            const SliverPadding(padding: EdgeInsets.only(top: 4.0)),

                                            ObxO(
                                              rx: settings.ytTopComments,
                                              builder: (ytTopComments) {
                                                if (!ytTopComments) return const SliverToBoxAdapter();
                                                return SliverToBoxAdapter(
                                                  child: ObxO(
                                                    rx: YoutubeInfoController.current.currentComments,
                                                    builder: (comments) => comments == null || comments.isEmpty
                                                        ? const SizedBox()
                                                        : NamidaInkWell(
                                                            key: Key("${currentId}_top_comments_highlight"),
                                                            bgColor: Color.alphaBlend(mainTheme.scaffoldBackgroundColor.withOpacity(0.4), mainTheme.cardColor),
                                                            margin: const EdgeInsets.symmetric(horizontal: 18.0),
                                                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                                            onTap: () {
                                                              NamidaNavigator.inst.isInYTCommentsSubpage = true;
                                                              NamidaNavigator.inst.ytMiniplayerCommentsPageKey.currentState?.pushPage(
                                                                const YTMiniplayerCommentsSubpage(),
                                                                maintainState: false,
                                                              );
                                                            },
                                                            child: Column(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                Row(
                                                                  mainAxisAlignment: MainAxisAlignment.start,
                                                                  children: [
                                                                    const Icon(
                                                                      Broken.document,
                                                                      size: 16.0,
                                                                    ),
                                                                    const SizedBox(width: 8.0),
                                                                    Expanded(
                                                                      child: Text(
                                                                        [
                                                                          lang.COMMENTS,
                                                                          if (comments.commentsCount != null) comments.commentsCount!.formatDecimalShort(),
                                                                        ].join(' • '),
                                                                        style: mainTextTheme.displaySmall,
                                                                        textAlign: TextAlign.start,
                                                                      ),
                                                                    ),
                                                                    ObxO(
                                                                      rx: YoutubeInfoController.current.isCurrentCommentsFromCache,
                                                                      builder: (commFromCache) {
                                                                        commFromCache ??= false;
                                                                        return NamidaIconButton(
                                                                          horizontalPadding: 0.0,
                                                                          tooltip: commFromCache ? () => lang.CACHE : null,
                                                                          icon: Broken.refresh,
                                                                          iconSize: 22.0,
                                                                          onPressed: () async => await YoutubeInfoController.current.updateCurrentComments(
                                                                            currentId,
                                                                            newSortType: YoutubeMiniplayerUiController.inst.currentCommentSort.value,
                                                                            initial: true,
                                                                          ),
                                                                          child: commFromCache
                                                                              ? StackedIcon(
                                                                                  baseIcon: Broken.refresh,
                                                                                  secondaryIcon: Broken.global,
                                                                                  iconSize: 20.0,
                                                                                  secondaryIconSize: 12.0,
                                                                                  baseIconColor: defaultIconColor,
                                                                                  secondaryIconColor: defaultIconColor,
                                                                                )
                                                                              : Icon(
                                                                                  Broken.refresh,
                                                                                  color: defaultIconColor,
                                                                                  size: 20.0,
                                                                                ),
                                                                        );
                                                                      },
                                                                    ),
                                                                  ],
                                                                ),
                                                                const NamidaContainerDivider(margin: EdgeInsets.symmetric(vertical: 4.0)),
                                                                ObxO(
                                                                  rx: YoutubeInfoController.current.isLoadingInitialComments,
                                                                  builder: (loading) => ShimmerWrapper(
                                                                    shimmerEnabled: loading,
                                                                    child: YTCommentCardCompact(comment: loading ? null : comments.items.firstOrNull),
                                                                  ),
                                                                )
                                                              ],
                                                            ),
                                                          ),
                                                  ),
                                                );
                                              },
                                            ),
                                            const SliverPadding(padding: EdgeInsets.only(top: 8.0)),

                                            page == null
                                                ? SliverToBoxAdapter(
                                                    key: Key("${currentId}_feed_shimmer"),
                                                    child: ShimmerWrapper(
                                                      transparent: false,
                                                      shimmerEnabled: true,
                                                      child: ListView.builder(
                                                        padding: EdgeInsets.zero,
                                                        key: Key("${currentId}_feedlist_shimmer"),
                                                        physics: const NeverScrollableScrollPhysics(),
                                                        itemCount: 15,
                                                        shrinkWrap: true,
                                                        itemBuilder: (context, index) {
                                                          return const YoutubeVideoCardDummy(
                                                            shimmerEnabled: true,
                                                            thumbnailHeight: relatedThumbnailHeight,
                                                            thumbnailWidth: relatedThumbnailWidth,
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  )
                                                : SliverFixedExtentList.builder(
                                                    key: Key("${currentId}_feedlist"),
                                                    itemExtent: relatedThumbnailItemExtent,
                                                    itemCount: page.relatedVideosResult.items.length,
                                                    itemBuilder: (context, index) {
                                                      final item = page.relatedVideosResult.items[index];
                                                      return switch (item.runtimeType) {
                                                        const (StreamInfoItem) => YoutubeVideoCard(
                                                            key: Key((item as StreamInfoItem).id),
                                                            thumbnailHeight: relatedThumbnailHeight,
                                                            thumbnailWidth: relatedThumbnailWidth,
                                                            isImageImportantInCache: false,
                                                            video: item,
                                                            playlistID: null,
                                                          ),
                                                        const (StreamInfoItemShort) => YoutubeShortVideoCard(
                                                            key: Key("${(item as StreamInfoItemShort?)?.id}"),
                                                            thumbnailHeight: relatedThumbnailHeight,
                                                            thumbnailWidth: relatedThumbnailWidth,
                                                            short: item as StreamInfoItemShort,
                                                            playlistID: null,
                                                          ),
                                                        const (PlaylistInfoItem) => YoutubePlaylistCard(
                                                            key: Key((item as PlaylistInfoItem).id),
                                                            thumbnailHeight: relatedThumbnailHeight,
                                                            thumbnailWidth: relatedThumbnailWidth,
                                                            playlist: item,
                                                            subtitle: item.subtitle,
                                                            playOnTap: true,
                                                          ),
                                                        _ => const YoutubeVideoCardDummy(
                                                            shimmerEnabled: true,
                                                            thumbnailHeight: relatedThumbnailHeight,
                                                            thumbnailWidth: relatedThumbnailWidth,
                                                          ),
                                                      };
                                                    },
                                                  ),

                                            const SliverPadding(padding: EdgeInsets.only(top: 12.0)),

                                            // --START-- Comments
                                            ObxO(
                                              rx: settings.ytTopComments,
                                              builder: (ytTopComments) {
                                                if (ytTopComments) return const SliverToBoxAdapter();
                                                return SliverToBoxAdapter(
                                                  key: Key("${currentId}_comments_header"),
                                                  child: const Padding(
                                                    padding: EdgeInsets.symmetric(vertical: 8.0),
                                                    child: YoutubeCommentsHeader(
                                                      displayBackButton: false,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                            ObxO(
                                              rx: settings.ytTopComments,
                                              builder: (ytTopComments) {
                                                if (ytTopComments) return const SliverToBoxAdapter();
                                                return ObxO(
                                                  rx: YoutubeInfoController.current.isLoadingInitialComments,
                                                  builder: (loadingInitial) => loadingInitial
                                                      ? SliverToBoxAdapter(
                                                          key: Key("${currentId}_comments_shimmer"),
                                                          child: ShimmerWrapper(
                                                            transparent: false,
                                                            shimmerEnabled: true,
                                                            child: ListView.builder(
                                                              padding: EdgeInsets.zero,
                                                              // key: Key(currentId),
                                                              physics: const NeverScrollableScrollPhysics(),
                                                              itemCount: 10,
                                                              shrinkWrap: true,
                                                              itemBuilder: (context, index) {
                                                                const comment = null;
                                                                return const YTCommentCard(
                                                                  key: Key("${comment == null}"),
                                                                  margin: EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                                                  comment: comment,
                                                                );
                                                              },
                                                            ),
                                                          ),
                                                        )
                                                      : ObxO(
                                                          rx: YoutubeInfoController.current.currentComments,
                                                          builder: (comments) => comments == null
                                                              ? const SliverToBoxAdapter()
                                                              : SliverList.builder(
                                                                  key: Key("${currentId}_comments"),
                                                                  itemCount: comments.length,
                                                                  itemBuilder: (context, i) {
                                                                    final comment = comments[i];
                                                                    return YTCommentCard(
                                                                      key: Key("${comment == null}_${comment?.commentId}"),
                                                                      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                                                      comment: comment,
                                                                    );
                                                                  },
                                                                ),
                                                        ),
                                                );
                                              },
                                            ),
                                            ObxO(
                                              rx: settings.ytTopComments,
                                              builder: (ytTopComments) {
                                                if (ytTopComments) return const SliverToBoxAdapter();
                                                return ObxO(
                                                  rx: YoutubeInfoController.current.isLoadingMoreComments,
                                                  builder: (loadingMoreComments) => loadingMoreComments
                                                      ? const SliverToBoxAdapter(
                                                          child: Padding(
                                                            padding: EdgeInsets.all(12.0),
                                                            child: Center(
                                                              child: LoadingIndicator(),
                                                            ),
                                                          ),
                                                        )
                                                      : const SliverToBoxAdapter(),
                                                );
                                              },
                                            ),

                                            const SliverPadding(padding: EdgeInsets.only(bottom: kYTQueueSheetMinHeight))
                                          ],
                                        ),
                                        ObxO(
                                          rx: _shouldShowGlowUnderVideo,
                                          builder: (shouldShowGlowUnderVideo) {
                                            const containerHeight = 12.0;
                                            return AnimatedSwitcher(
                                              duration: const Duration(milliseconds: 300),
                                              child: shouldShowGlowUnderVideo
                                                  ? Stack(
                                                      key: const Key('actual_glow'),
                                                      children: [
                                                        Container(
                                                          height: containerHeight,
                                                          color: mainTheme.scaffoldBackgroundColor,
                                                        ),
                                                        Container(
                                                          height: containerHeight,
                                                          transform: Matrix4.translationValues(0, containerHeight / 2, 0),
                                                          decoration: BoxDecoration(
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: mainTheme.scaffoldBackgroundColor,
                                                                spreadRadius: containerHeight * 0.25,
                                                                offset: const Offset(0, 0),
                                                                blurRadius: 8.0,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    )
                                                  : const SizedBox(key: Key('empty_glow')),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        rightDragAbsorberWidget,
                        ytMiniplayerQueueChip,
                        miniplayerDimWidget, // -- dimming
                        absorbBottomDragWidget, // prevent accidental scroll while performing home gesture
                      ],
                    );

                    final titleChild = Column(
                      key: Key("${currentId}_title_button1_child"),
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        NamidaDummyContainer(
                          borderRadius: 4.0,
                          height: 16.0,
                          shimmerEnabled: page == null,
                          width: maxWidth - 24.0,
                          child: Text(
                            videoTitle ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: mainTextTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        NamidaDummyContainer(
                          borderRadius: 4.0,
                          height: 10.0,
                          shimmerEnabled: page == null,
                          width: maxWidth - 24.0 * 2,
                          child: Text(
                            channelName ?? '',
                            style: mainTextTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                              fontSize: 13.0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    );

                    final playPauseButtonChild = Obx(
                      () {
                        final isLoading = Player.inst.shouldShowLoadingIndicatorR;
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            if (isLoading)
                              IgnorePointer(
                                child: NamidaOpacity(
                                  key: Key("${currentId}_button_loading"),
                                  enabled: true,
                                  opacity: 0.3,
                                  child: ThreeArchedCircle(
                                    key: Key("${currentId}_button_loading_child"),
                                    color: defaultIconColor,
                                    size: 36.0,
                                  ),
                                ),
                              ),
                            NamidaIconButton(
                              horizontalPadding: 0.0,
                              onPressed: () {
                                Player.inst.togglePlayPause();
                              },
                              icon: null,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Player.inst.isPlayingR
                                    ? Icon(
                                        Broken.pause,
                                        color: defaultIconColor,
                                        key: const Key('pause'),
                                      )
                                    : Icon(
                                        Broken.play,
                                        color: defaultIconColor,
                                        key: const Key('play'),
                                      ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                    final nextButton = NamidaIconButton(
                      horizontalPadding: 0.0,
                      icon: Broken.next,
                      iconColor: defaultIconColor,
                      onPressed: () {
                        Player.inst.next();
                      },
                    );

                    return ObxO(
                      rx: settings.enableBottomNavBar,
                      builder: (enableBottomNavBar) => ObxO(
                        rx: settings.dismissibleMiniplayer,
                        builder: (dismissibleMiniplayer) => NamidaYTMiniplayer(
                          key: MiniPlayerController.inst.ytMiniplayerKey,
                          duration: const Duration(milliseconds: 1000),
                          curve: Curves.easeOutExpo,
                          bottomMargin: 8.0 + (enableBottomNavBar ? kBottomNavigationBarHeight : 0.0) - 1.0, // -1 is just a clip ensurer.
                          minHeight: miniplayerHeight,
                          maxHeight: context.height,
                          bgColor: miniplayerBGColor,
                          displayBottomBGLayer: !enableBottomNavBar,
                          onDismiss: dismissibleMiniplayer ? Player.inst.clearQueue : null,
                          onDismissing: (dismissPercentage) {
                            Player.inst.setPlayerVolume(dismissPercentage.clamp(0.0, settings.player.volume.value));
                          },
                          onHeightChange: (percentage) {
                            MiniPlayerController.inst.animateMiniplayer(percentage);
                          },
                          onAlternativePercentageExecute: () {
                            VideoController.inst.toggleFullScreenVideoView(
                              isLocal: false,
                              setOrientations: false,
                            );
                          },
                          builder: (double height, double p) {
                            final percentage = (p * 2.8).clamp(0.0, 1.0);
                            final percentageFast = (p * 1.5 - 0.5).clamp(0.0, 1.0);
                            final inversePerc = 1 - percentage;
                            final reverseOpacity = (inversePerc * 2.8 - 1.8).clamp(0.0, 1.0);
                            final finalspace1sb = space1sb * inversePerc;
                            final finalspace3sb = space3sb * inversePerc;
                            final finalspace4buttons = space4 * inversePerc;
                            final finalspace5sb = space5sb * inversePerc;
                            final finalpadding = 4.0 * inversePerc;
                            final finalbr = (8.0 * inversePerc).multipliedRadius;
                            final finalthumbnailWidth = (space2ForThumbnail + maxWidth * percentage).clamp(space2ForThumbnail, maxWidth - finalspace1sb - finalspace3sb);
                            final finalthumbnailHeight = finalthumbnailWidth * 9 / 16;

                            return Stack(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        SizedBox(width: finalspace1sb),
                                        Container(
                                          clipBehavior: Clip.antiAlias,
                                          margin: EdgeInsets.symmetric(vertical: finalpadding),
                                          decoration: BoxDecoration(
                                            color: Colors.black,
                                            borderRadius: BorderRadius.circular(finalbr),
                                          ),
                                          width: finalthumbnailWidth,
                                          height: finalthumbnailHeight,
                                          child: NamidaVideoWidget(
                                            isLocal: false,
                                            enableControls: percentage > 0.5,
                                            onMinimizeTap: () => MiniPlayerController.inst.ytMiniplayerKey.currentState?.animateToState(false),
                                            swipeUpToFullscreen: true,
                                          ),
                                        ),
                                        if (reverseOpacity > 0) ...[
                                          SizedBox(width: finalspace3sb),
                                          SizedBox(
                                            width: (maxWidth - finalthumbnailWidth - finalspace1sb - finalspace3sb - finalspace4buttons - finalspace5sb).clamp(0, maxWidth),
                                            child: NamidaOpacity(
                                              key: Key("${currentId}_title_button1"),
                                              enabled: true,
                                              opacity: reverseOpacity,
                                              child: titleChild,
                                            ),
                                          ),
                                          NamidaOpacity(
                                            key: Key("${currentId}_title_button2"),
                                            enabled: true,
                                            opacity: reverseOpacity,
                                            child: SizedBox(
                                              key: Key("${currentId}_title_button2_child"),
                                              width: finalspace4buttons / 2,
                                              height: miniplayerHeight,
                                              child: playPauseButtonChild,
                                            ),
                                          ),
                                          NamidaOpacity(
                                            key: Key("${currentId}_title_button3"),
                                            enabled: true,
                                            opacity: reverseOpacity,
                                            child: SizedBox(
                                              key: Key("${currentId}_title_button3_child"),
                                              width: finalspace4buttons / 2,
                                              height: miniplayerHeight,
                                              child: nextButton,
                                            ),
                                          ),
                                          SizedBox(width: finalspace5sb),
                                        ]
                                      ],
                                    ),

                                    // ---- if was in comments subpage, and this gets hidden, the route is popped
                                    // ---- same with [isQueueSheetOpen]
                                    if (NamidaNavigator.inst.isInYTCommentsSubpage || NamidaNavigator.inst.isQueueSheetOpen ? true : percentage > 0)
                                      Expanded(
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            miniplayerBody,
                                            IgnorePointer(
                                              child: ColoredBox(
                                                color: miniplayerBGColor.withOpacity(1 - percentageFast),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                Positioned(
                                  top: finalthumbnailHeight -
                                      (_extraPaddingForYTMiniplayer / 2 * (1 - percentage)) -
                                      (SeekReadyDimensions.barHeight / 2) -
                                      (SeekReadyDimensions.barHeight / 2 * percentage) +
                                      (SeekReadyDimensions.progressBarHeight / 2),
                                  left: 0,
                                  right: 0,
                                  child: seekReadyWidget,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
