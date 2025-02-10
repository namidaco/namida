import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:jiffy/jiffy.dart';
import 'package:share_plus/share_plus.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item_short.dart';
import 'package:youtipie/class/youtipie_feed/playlist_info_item.dart';
import 'package:youtipie/core/enum.dart';
import 'package:youtipie/core/url_utils.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/base/yt_video_like_manager.dart';
import 'package:namida/class/route.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/video_controller.dart';
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
import 'package:namida/youtube/class/download_task_base.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/yt_miniplayer_ui_controller.dart';
import 'package:namida/youtube/functions/add_to_playlist_sheet.dart';
import 'package:namida/youtube/functions/download_sheet.dart';
import 'package:namida/youtube/functions/video_listens_dialog.dart';
import 'package:namida/youtube/pages/yt_channel_subpage.dart';
import 'package:namida/youtube/seek_ready_widget.dart';
import 'package:namida/youtube/widgets/yt_action_button.dart';
import 'package:namida/youtube/widgets/yt_comment_card.dart';
import 'package:namida/youtube/widgets/yt_description_widget.dart';
import 'package:namida/youtube/widgets/yt_history_video_card.dart';
import 'package:namida/youtube/widgets/yt_playlist_card.dart';
import 'package:namida/youtube/widgets/yt_queue_chip.dart';
import 'package:namida/youtube/widgets/yt_shimmer.dart';
import 'package:namida/youtube/widgets/yt_subscribe_buttons.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:namida/youtube/widgets/yt_video_card.dart';
import 'package:namida/youtube/yt_miniplayer_comments_subpage.dart';
import 'package:namida/youtube/yt_utils.dart';

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
    final bool defaultKeepActive = settings.youtube.ytMiniplayerDimAfterSeconds.value == 0;
    if (!defaultKeepActive) _canDimMiniplayer.value = false;
  }

  void startDimTimer() {
    _dimTimer?.cancel();
    if (settings.youtube.enableDimInLightMode == false && namida.context?.isDarkMode == false) {
      _canDimMiniplayer.value = false;
      return;
    }
    final double defaultMiniplayerOpacity = settings.youtube.ytMiniplayerDimOpacity.value;
    if (defaultMiniplayerOpacity <= 0) return;
    final int defaultMiniplayerDimSeconds = settings.youtube.ytMiniplayerDimAfterSeconds.value;
    if (defaultMiniplayerDimSeconds <= -1) return; // dont dim
    final bool defaultKeepActive = defaultMiniplayerDimSeconds == 0;
    if (defaultKeepActive) {
      _canDimMiniplayer.value = true;
    } else {
      _dimTimer = Timer(Duration(seconds: defaultMiniplayerDimSeconds), () {
        _canDimMiniplayer.value = true;
      });
    }
  }

  void _onVideoPageReset() {
    try {
      _scrollController.jumpTo(0);
    } catch (_) {}
    resetGlowUnderVideo();
    startDimTimer();
    _isTitleExpanded.value = false;
  }

  final _videoLikeManager = YtVideoLikeManager(page: YoutubeInfoController.current.currentVideoPage);

  @override
  void initState() {
    super.initState();
    startDimTimer();
    _scrollController.addListener(() {
      final pixels = _scrollController.positions.lastOrNull?.pixels;
      final hasScrolledEnough = pixels != null && pixels > 40;
      _shouldShowGlowUnderVideo.value = hasScrolledEnough;
    });
    YoutubeInfoController.current.onVideoPageReset = _onVideoPageReset;
    _videoLikeManager.init();
  }

  @override
  void dispose() {
    YoutubeInfoController.current.onVideoPageReset = null;
    _scrollController.dispose();
    _numberOfRepeats.close();
    _isTitleExpanded.close();
    _shouldShowGlowUnderVideo.close();
    _videoLikeManager.dispose();
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

    const dummyVideoCard = YoutubeVideoCardDummy(
      shimmerEnabled: true, // this actually just to display dummy boxes
      thumbnailHeight: relatedThumbnailHeight,
      thumbnailWidth: relatedThumbnailWidth,
      displaythirdLineText: false,
    );

    const seekReadyWidget = SeekReadyWidget();

    final maxWidth = context.width;
    final mainTheme = context.theme;
    final mainTextTheme = context.textTheme;

    final miniplayerBGColor = Color.alphaBlend(mainTheme.secondaryHeaderColor.withValues(alpha: 0.25), mainTheme.scaffoldBackgroundColor);

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
          builder: (context, canDimMiniplayer) => AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            reverseDuration: const Duration(milliseconds: 200),
            child: canDimMiniplayer
                ? ObxO(
                    rx: settings.youtube.ytMiniplayerDimOpacity,
                    builder: (context, dimOpacity) => Container(
                      color: Colors.black.withValues(alpha: dimOpacity),
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
            if (NamidaNavigator.inst.isInYTCommentsSubpage || NamidaNavigator.inst.isInYTCommentRepliesSubpage) return;
            _mpState?.setDragExternally(true);
            _mpState?.saveDragHeightStart();
            _velocity.addPosition(event.timeStamp, event.position);
          },
          onPointerMove: (event) {
            if (NamidaNavigator.inst.isInYTCommentsSubpage || NamidaNavigator.inst.isInYTCommentRepliesSubpage) return;
            if (!_canScrollQueue) {
              _mpState?.onVerticalDragUpdate(event.delta.dy);
              _velocity.addPosition(event.timeStamp, event.position);
            }
          },
          onPointerCancel: (event) {
            WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
              _mpState?.setDragExternally(false);
            });
          },
          onPointerUp: (event) {
            if (!NamidaNavigator.inst.isInYTCommentsSubpage && !NamidaNavigator.inst.isInYTCommentRepliesSubpage) {
              if (_scrollController.hasClients && _scrollController.position.pixels <= 0) {
                _mpState?.onVerticalDragEnd(_velocity.getVelocity().pixelsPerSecond.dy);
              }
            }
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
        rx: settings.youtube.topComments,
        builder: (context, ytTopComments) => ObxO(
          rx: Player.inst.currentItem,
          builder: (context, currentItem) {
            if (currentItem is! YoutubeID) return const SizedBox();

            final currentId = currentItem.id;
            final currentIdTask = DownloadTaskVideoId(videoId: currentItem.id);

            return ObxO(
              rx: YoutubeController.inst.downloadedFilesMap,
              builder: (context, _) {
                final downloadedFileExists = YoutubeController.inst.doesIDHasFileDownloaded(currentId) != null;
                return ObxO(
                  rx: YoutubeInfoController.current.currentYTStreams,
                  builder: (context, streams) => ObxO(
                    rx: YoutubeInfoController.current.currentStreamInfo,
                    builder: (context, streamInfo) => ObxO(
                      rx: YoutubeInfoController.current.isLoadingVideoPage,
                      builder: (context, isLoadingVideoPage) => ObxO(
                        rx: YoutubeInfoController.current.currentRelatedVideos,
                        builder: (context, currentRelatedVideos) => ObxO(
                          rx: YoutubeInfoController.current.currentVideoPage,
                          builder: (context, page) {
                            final shimmerEnabledDummyContainer = page == null;
                            final shimmerEnabled = isLoadingVideoPage && page == null;
                            final videoInfo = page?.videoInfo;
                            final videoInfoStream = streams?.info ?? streamInfo;
                            final channel = page?.channelInfo;

                            String? uploadDate;
                            String? uploadDateAgo;

                            DateTime? parsedDate = videoInfoStream?.publishedAt.date ??
                                videoInfoStream?.publishDate.date ??
                                videoInfo?.publishedAt.accurateDate; // videoInfo?.publishedAt.date aint no way near accurate
                            bool accurateDate = true;
                            if (parsedDate == null) {
                              parsedDate = videoInfo?.publishedAt.date;
                              accurateDate = false;
                            }
                            if (parsedDate != null) {
                              if (accurateDate) uploadDate = parsedDate.millisecondsSinceEpoch.dateFormattedOriginal;
                              uploadDateAgo = Jiffy.parseFromDateTime(parsedDate).fromNow();
                            } else {
                              // uploadDateAgo = videoInfo?.publishedFromText; // warcrime
                            }
                            final videoTitle = videoInfo?.title ?? videoInfoStream?.title;
                            final channelName = channel?.title ?? videoInfoStream?.channelName;

                            final channelThumbnail = channel?.thumbnails.pick()?.url;
                            final channelIsVerified = channel?.isVerified ?? false;
                            final channelSubs = channel?.subscribersCount;
                            String? channelID = channel?.id ?? videoInfoStream?.channelId;
                            if (channelID == null || channelID.isEmpty) channelID = YoutubeInfoController.utils.getVideoChannelID(currentId);

                            final videoViewCount = videoInfo?.viewsCount;

                            final description = videoInfo?.description;
                            final descriptionWidget = description == null
                                ? null
                                : YoutubeDescriptionWidget(
                                    videoId: currentId,
                                    content: description,
                                  );

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
                                          child: VideoTilePropertiesProvider(
                                            configs: VideoTilePropertiesConfigs(
                                              queueSource: QueueSourceYoutubeID.relatedVideos,
                                              showMoreIcon: true,
                                            ),
                                            builder: (properties) => LazyLoadListView(
                                              key: Key("${currentId}_body_lazy_load_list"),
                                              onReachingEnd: ytTopComments ? () => false : () => YoutubeInfoController.current.updateCurrentComments(currentId),
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
                                                          shimmerEnabled: shimmerEnabled && videoTitle == null,
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
                                                                ObxO(
                                                                  rx: YoutubeHistoryController.inst.topTracksMapListens,
                                                                  builder: (context, topTracksMapListens) {
                                                                    final videoListens = topTracksMapListens[currentId] ?? [];
                                                                    if (videoListens.isEmpty) return const SizedBox();
                                                                    return NamidaInkWell(
                                                                      borderRadius: 6.0,
                                                                      bgColor: CurrentColor.inst.miniplayerColor.withValues(alpha: 0.7),
                                                                      onTap: () {
                                                                        showVideoListensDialog(currentId);
                                                                      },
                                                                      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                                                                      child: Text(
                                                                        videoListens.length.formatDecimal(),
                                                                        style: mainTextTheme.displaySmall?.copyWith(
                                                                          color: Colors.white.withValues(alpha: 0.6),
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
                                                                  childrenDefault: () => YTUtils.getVideoCardMenuItemsForCurrentlyPlaying(
                                                                    queueSource: QueueSourceYoutubeID.playerQueue,
                                                                    context: context,
                                                                    numberOfRepeats: _numberOfRepeats,
                                                                    videoId: currentId,
                                                                    videoTitle: videoTitle,
                                                                    channelID: null,
                                                                    displayGoToChannel: false,
                                                                    displayCopyUrl: false,
                                                                  ),
                                                                  child: const Icon(
                                                                    Broken.arrow_down_2,
                                                                    size: 20.0,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            title: ObxO(
                                                              rx: _isTitleExpanded,
                                                              builder: (context, isTitleExpanded) {
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
                                                                      shimmerEnabled: shimmerEnabledDummyContainer && videoTitle == null,
                                                                      child: Text(
                                                                        videoTitle ?? '',
                                                                        maxLines: isTitleExpanded ? 6 : 2,
                                                                        overflow: TextOverflow.ellipsis,
                                                                        style: mainTextTheme.displayLarge,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(height: 4.0),
                                                                    NamidaDummyContainer(
                                                                      width: maxWidth * 0.4,
                                                                      height: 12.0,
                                                                      shimmerEnabled: shimmerEnabledDummyContainer && dateToShow == null,
                                                                      child: Text(
                                                                        [
                                                                          if (videoViewCount != null)
                                                                            isTitleExpanded ? videoViewCount.displayViewsKeyword : videoViewCount.displayViewsKeywordShort,
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
                                                          shimmerEnabled: shimmerEnabled,
                                                          child: SizedBox(
                                                            width: maxWidth,
                                                            child: Wrap(
                                                              alignment: WrapAlignment.spaceEvenly,
                                                              children: [
                                                                const SizedBox(width: 4.0),
                                                                ObxO(
                                                                  rx: _videoLikeManager.currentVideoLikeStatus,
                                                                  builder: (context, currentLikeStatus) {
                                                                    final isUserLiked = currentLikeStatus == LikeStatus.liked;
                                                                    final videoLikeCount = (isUserLiked ? 1 : 0) + (videoInfo?.engagement?.likesCount ?? 0);
                                                                    return ObxO(
                                                                      rx: _isTitleExpanded,
                                                                      builder: (context, isTitleExpanded) => SmallYTActionButton(
                                                                        title: shimmerEnabled
                                                                            ? null
                                                                            : videoLikeCount < 1
                                                                                ? lang.LIKE
                                                                                : videoLikeCount.formatDecimalShort(isTitleExpanded),
                                                                        icon: Broken.like_1,
                                                                        smallIconWidget: FittedBox(
                                                                          child: NamidaLoadingSwitcher(
                                                                            size: 24.0,
                                                                            builder: (loadingController) => NamidaRawLikeButton(
                                                                              isLiked: isUserLiked,
                                                                              likedIcon: Broken.like_filled,
                                                                              normalIcon: Broken.like_1,
                                                                              disabledColor: context.theme.iconTheme.color,
                                                                              size: 24.0,
                                                                              onTap: (isLiked) {
                                                                                return _videoLikeManager.onLikeClicked(
                                                                                  YTVideoLikeParamters(
                                                                                    isActive: isLiked,
                                                                                    action: isLiked ? LikeAction.removeLike : LikeAction.addLike,
                                                                                    onStart: loadingController.startLoading,
                                                                                    onEnd: loadingController.stopLoading,
                                                                                  ),
                                                                                );
                                                                              },
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    );
                                                                  },
                                                                ),
                                                                const SizedBox(width: 4.0),
                                                                ObxO(
                                                                  rx: _videoLikeManager.currentVideoLikeStatus,
                                                                  builder: (context, currentLikeStatus) {
                                                                    final isUserDisLiked = currentLikeStatus == LikeStatus.disliked;
                                                                    const int? videoDislikeCount = null; // should have a value if ReturnYoutubeDislikes implemented.
                                                                    return ObxO(
                                                                      rx: _isTitleExpanded,
                                                                      builder: (context, isTitleExpanded) => SmallYTActionButton(
                                                                        title: (videoDislikeCount ?? 0) < 1
                                                                            ? lang.DISLIKE
                                                                            : videoDislikeCount?.formatDecimalShort(isTitleExpanded) ?? '?',
                                                                        icon: Broken.dislike,
                                                                        smallIconWidget: FittedBox(
                                                                          child: NamidaLoadingSwitcher(
                                                                            size: 24.0,
                                                                            builder: (loadingController) => NamidaRawLikeButton(
                                                                              isLiked: isUserDisLiked,
                                                                              likedIcon: Broken.dislike_filled,
                                                                              normalIcon: Broken.dislike,
                                                                              disabledColor: context.theme.iconTheme.color,
                                                                              size: 24.0,
                                                                              onTap: (isDisLiked) async {
                                                                                return _videoLikeManager.onDisLikeClicked(
                                                                                  YTVideoLikeParamters(
                                                                                    isActive: isDisLiked,
                                                                                    action: isDisLiked ? LikeAction.removeDislike : LikeAction.addDislike,
                                                                                    onStart: loadingController.startLoading,
                                                                                    onEnd: loadingController.stopLoading,
                                                                                  ),
                                                                                );
                                                                              },
                                                                            ),
                                                                          ),
                                                                        ),
                                                                        onPressed: () {},
                                                                      ),
                                                                    );
                                                                  },
                                                                ),
                                                                const SizedBox(width: 4.0),
                                                                SmallYTActionButton(
                                                                  title: lang.SHARE,
                                                                  icon: Broken.share,
                                                                  onPressed: () {
                                                                    final url = videoInfo?.buildUrl() ?? YTUrlUtils.buildVideoUrl(currentId);
                                                                    Share.share(url);
                                                                  },
                                                                ),
                                                                const SizedBox(width: 4.0),
                                                                SmallYTActionButton(
                                                                  title: lang.REFRESH,
                                                                  icon: Broken.refresh,
                                                                  onPressed: () async => await YoutubeInfoController.current.updateVideoPage(
                                                                    currentId,
                                                                    requestPage: true,
                                                                    requestComments: true,
                                                                  ),
                                                                ),
                                                                const SizedBox(width: 4.0),
                                                                Obx(
                                                                  (context) {
                                                                    final audioProgress = YoutubeController.inst.downloadsAudioProgressMap[currentIdTask]?.values.firstOrNull;
                                                                    final audioPercText = audioProgress?.percentageText(prefix: lang.AUDIO);
                                                                    final videoProgress = YoutubeController.inst.downloadsVideoProgressMap[currentIdTask]?.values.firstOrNull;
                                                                    final videoPercText = videoProgress?.percentageText(prefix: lang.VIDEO);

                                                                    final isDownloading =
                                                                        YoutubeController.inst.isDownloading[currentIdTask]?.values.any((element) => element) == true;

                                                                    final wasDownloading = videoProgress != null || audioProgress != null;
                                                                    final icon = (wasDownloading && !isDownloading)
                                                                        ? Broken.play_circle
                                                                        : wasDownloading
                                                                            ? Broken.pause_circle
                                                                            : downloadedFileExists
                                                                                ? Broken.tick_circle
                                                                                : Broken.import;
                                                                    return SmallYTActionButton(
                                                                      titleWidget:
                                                                          videoPercText == null && audioPercText == null && isDownloading ? const LoadingIndicator() : null,
                                                                      title: videoPercText ?? audioPercText ?? lang.DOWNLOAD,
                                                                      icon: icon,
                                                                      onLongPress: () async => await showDownloadVideoBottomSheet(
                                                                          videoId: currentId, originalIndex: null, totalLength: null, playlistId: null, streamInfoItem: null),
                                                                      onPressed: () async {
                                                                        if (isDownloading) {
                                                                          YoutubeController.inst.pauseDownloadTask(
                                                                            itemsConfig: [],
                                                                            videosIds: [currentIdTask],
                                                                            groupName: const DownloadTaskGroupName.defaulty(),
                                                                          );
                                                                        } else if (wasDownloading) {
                                                                          YoutubeController.inst.resumeDownloadTaskForIDs(
                                                                            videosIds: [currentIdTask],
                                                                            groupName: const DownloadTaskGroupName.defaulty(),
                                                                          );
                                                                        } else {
                                                                          await showDownloadVideoBottomSheet(
                                                                              videoId: currentId, originalIndex: null, totalLength: null, playlistId: null, streamInfoItem: null);
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
                                                          shimmerEnabled: shimmerEnabled && (channelName == null || channelThumbnail == null || channelSubs == null),
                                                          child: Material(
                                                            type: MaterialType.transparency,
                                                            child: InkWell(
                                                              onTap: () {
                                                                final channelInfo = channel ?? YoutubeInfoController.current.currentVideoPage.value?.channelInfo;
                                                                String? chid = channel?.id ?? YoutubeInfoController.current.currentVideoPage.value?.channelInfo?.id;
                                                                if (chid == null || chid.isEmpty) chid = YoutubeInfoController.utils.getVideoChannelID(currentId);
                                                                if (chid != null) YTChannelSubpage(channelID: chid, channel: channelInfo).navigate();
                                                              },
                                                              child: Row(
                                                                children: [
                                                                  const SizedBox(width: 16.0),
                                                                  NamidaDummyContainer(
                                                                    width: 42.0,
                                                                    height: 42.0,
                                                                    borderRadius: 100.0,
                                                                    shimmerEnabled: channelThumbnail == null && (channelID == null || channelID.isEmpty),
                                                                    child: YoutubeThumbnail(
                                                                      type: ThumbnailType.channel,
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
                                                                    child: Column(
                                                                      mainAxisSize: MainAxisSize.min,
                                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                                      children: [
                                                                        FittedBox(
                                                                          child: Row(
                                                                            mainAxisSize: MainAxisSize.min,
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
                                                                              builder: (context, isTitleExpanded) => Text(
                                                                                channelSubs == null ? '? ${lang.SUBSCRIBERS}' : channelSubs.displaySubscribersKeywordShort,
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
                                                                  YTSubscribeButton(
                                                                    channelID: channelID,
                                                                    mainChannelInfo: YoutubeInfoController.current.currentChannelPage,
                                                                  ),
                                                                  const SizedBox(width: 12.0),
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

                                                      if (ytTopComments)
                                                        SliverToBoxAdapter(
                                                          child: Padding(
                                                            padding: const EdgeInsets.only(top: 8.0),
                                                            child: ObxO(
                                                              rx: YoutubeInfoController.current.currentComments,
                                                              builder: (context, comments) => ShimmerWrapper(
                                                                shimmerEnabled: shimmerEnabled && (comments == null || comments.isEmpty),
                                                                child: NamidaInkWell(
                                                                  key: Key("${currentId}_top_comments_highlight"),
                                                                  bgColor: Color.alphaBlend(mainTheme.scaffoldBackgroundColor.withValues(alpha: 0.4), mainTheme.cardColor),
                                                                  margin: const EdgeInsets.symmetric(horizontal: 18.0),
                                                                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                                                  onTap: () {
                                                                    NamidaNavigator.inst.isInYTCommentsSubpage = true;
                                                                    NamidaNavigator.inst.ytMiniplayerCommentsPageKey.currentState?.pushPage(
                                                                      const YTMiniplayerCommentsSubpage(),
                                                                      maintainState: true, // vip to maintain scroll offset
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
                                                                                if (comments?.commentsCount != null) comments!.commentsCount!.formatDecimalShort(),
                                                                              ].join(' • '),
                                                                              style: mainTextTheme.displaySmall,
                                                                              textAlign: TextAlign.start,
                                                                            ),
                                                                          ),
                                                                          ObxO(
                                                                            rx: YoutubeInfoController.current.isCurrentCommentsFromCache,
                                                                            builder: (context, commFromCache) {
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
                                                                        builder: (context, loading) => ShimmerWrapper(
                                                                          shimmerEnabled: loading,
                                                                          child: YTCommentCardCompact(comment: loading ? null : comments?.items.firstOrNull),
                                                                        ),
                                                                      )
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),

                                                      const SliverPadding(padding: EdgeInsets.only(top: 8.0)),

                                                      currentRelatedVideos == null // we display dummy boxes but shimmer would be disabled
                                                          ? SliverToBoxAdapter(
                                                              key: Key("${currentId}_feed_shimmer"),
                                                              child: ShimmerWrapper(
                                                                transparent: false,
                                                                shimmerEnabled: shimmerEnabled,
                                                                child: ListView.builder(
                                                                  padding: EdgeInsets.zero,
                                                                  key: Key("${currentId}_feedlist_shimmer"),
                                                                  physics: const NeverScrollableScrollPhysics(),
                                                                  itemCount: 15,
                                                                  shrinkWrap: true,
                                                                  itemBuilder: (_, __) => dummyVideoCard,
                                                                ),
                                                              ),
                                                            )
                                                          : ObxO(
                                                              rx: settings.youtube.ytVisibleShorts,
                                                              builder: (context, visibleShorts) {
                                                                final isShortsVisible = visibleShorts[YTVisibleShortPlaces.relatedVideos] ?? true;
                                                                return ObxO(
                                                                  rx: settings.youtube.ytVisibleMixes,
                                                                  builder: (context, visibleMixes) {
                                                                    final isMixesVisible = visibleMixes[YTVisibleMixesPlaces.relatedVideos] ?? true;
                                                                    return SliverVariedExtentList.builder(
                                                                      key: Key("${currentId}_feedlist"),
                                                                      itemExtentBuilder: (index, dimensions) {
                                                                        if (isShortsVisible && currentRelatedVideos.shortsSection.relatedItemsShortsData[index] != null) {
                                                                          return 64.0 * 3 + 24.0 * 2;
                                                                        }
                                                                        final item = currentRelatedVideos.items[index];
                                                                        if (!isShortsVisible && item is StreamInfoItemShort) return 0;
                                                                        if (!isMixesVisible && item is PlaylistInfoItem && item.isMix) return 0;
                                                                        return relatedThumbnailItemExtent;
                                                                      },
                                                                      itemCount: currentRelatedVideos.items.length,
                                                                      itemBuilder: (context, index) {
                                                                        final shortSection = currentRelatedVideos.shortsSection.relatedItemsShortsData[index];
                                                                        if (shortSection != null) {
                                                                          if (isShortsVisible == false) return const SizedBox();
                                                                          const height = 64.0 * 3;
                                                                          const width = height * (9 / 16 * 1.2);
                                                                          const hPadding = 4.0;
                                                                          return SizedBox(
                                                                            height: height,
                                                                            child: ListView.builder(
                                                                              padding: const EdgeInsets.symmetric(vertical: 24.0 / 6, horizontal: 4.0),
                                                                              scrollDirection: Axis.horizontal,
                                                                              itemExtent: width + hPadding * 2,
                                                                              itemCount: shortSection.length,
                                                                              itemBuilder: (context, index) {
                                                                                final shortIndex = shortSection[index];
                                                                                final short = currentRelatedVideos.items[shortIndex] as StreamInfoItemShort;
                                                                                return Padding(
                                                                                  padding: const EdgeInsets.symmetric(horizontal: hPadding),
                                                                                  child: YoutubeShortVideoTallCard(
                                                                                    queueSource: QueueSourceYoutubeID.relatedVideos,
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

                                                                        final item = currentRelatedVideos.items[index];
                                                                        return switch (item.runtimeType) {
                                                                          const (StreamInfoItem) => YoutubeVideoCard(
                                                                              properties: properties,
                                                                              key: Key((item as StreamInfoItem).id),
                                                                              thumbnailHeight: relatedThumbnailHeight,
                                                                              thumbnailWidth: relatedThumbnailWidth,
                                                                              isImageImportantInCache: false,
                                                                              video: item,
                                                                              playlistID: null,
                                                                            ),
                                                                          const (StreamInfoItemShort) => !isShortsVisible
                                                                              ? const SizedBox.shrink()
                                                                              : YoutubeShortVideoCard(
                                                                                  queueSource: QueueSourceYoutubeID.relatedVideos,
                                                                                  key: Key("${(item as StreamInfoItemShort?)?.id}"),
                                                                                  thumbnailHeight: relatedThumbnailHeight,
                                                                                  thumbnailWidth: relatedThumbnailWidth,
                                                                                  short: item as StreamInfoItemShort,
                                                                                  playlistID: null,
                                                                                ),
                                                                          const (PlaylistInfoItem) => (item as PlaylistInfoItem).isMix && !isMixesVisible
                                                                              ? const SizedBox.shrink()
                                                                              : YoutubePlaylistCard(
                                                                                  queueSource: QueueSourceYoutubeID.relatedVideos,
                                                                                  key: Key(item.id),
                                                                                  thumbnailHeight: relatedThumbnailHeight,
                                                                                  thumbnailWidth: relatedThumbnailWidth,
                                                                                  playlist: item,
                                                                                  subtitle: item.subtitle,
                                                                                  playOnTap: true,
                                                                                  firstVideoID: item.initialVideos.firstOrNull?.id,
                                                                                  isMixPlaylist: item.isMix,
                                                                                ),
                                                                          _ => dummyVideoCard,
                                                                        };
                                                                      },
                                                                    );
                                                                  },
                                                                );
                                                              },
                                                            ),

                                                      const SliverPadding(padding: EdgeInsets.only(top: 12.0)),

                                                      // --START-- Comments
                                                      if (!ytTopComments)
                                                        SliverToBoxAdapter(
                                                          key: Key("${currentId}_comments_header"),
                                                          child: const Padding(
                                                            padding: EdgeInsets.symmetric(vertical: 8.0),
                                                            child: YoutubeCommentsHeader(
                                                              displayBackButton: false,
                                                            ),
                                                          ),
                                                        ),
                                                      if (!ytTopComments)
                                                        ObxO(
                                                          rx: YoutubeInfoController.current.isLoadingInitialComments,
                                                          builder: (context, loadingInitial) => loadingInitial
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
                                                                        return const YTCommentCard(
                                                                          margin: EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                                                          comment: null,
                                                                          mainList: null,
                                                                          videoId: null,
                                                                        );
                                                                      },
                                                                    ),
                                                                  ),
                                                                )
                                                              : ObxO(
                                                                  rx: YoutubeInfoController.current.currentComments,
                                                                  builder: (context, comments) => comments == null
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
                                                                              mainList: () => comments,
                                                                              videoId: currentId,
                                                                            );
                                                                          },
                                                                        ),
                                                                ),
                                                        ),
                                                      if (!ytTopComments)
                                                        ObxO(
                                                          rx: YoutubeInfoController.current.isLoadingMoreComments,
                                                          builder: (context, loadingMoreComments) => loadingMoreComments
                                                              ? const SliverToBoxAdapter(
                                                                  child: Padding(
                                                                    padding: EdgeInsets.all(12.0),
                                                                    child: Center(
                                                                      child: LoadingIndicator(),
                                                                    ),
                                                                  ),
                                                                )
                                                              : const SliverToBoxAdapter(),
                                                        ),

                                                      const SliverPadding(padding: EdgeInsets.only(bottom: kYTQueueSheetMinHeight))
                                                    ],
                                                  ),
                                                  ObxO(
                                                    rx: _shouldShowGlowUnderVideo,
                                                    builder: (context, shouldShowGlowUnderVideo) {
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
                                  shimmerEnabled: shimmerEnabledDummyContainer && videoTitle == null,
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
                                  shimmerEnabled: shimmerEnabledDummyContainer && channelName == null,
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

                            final playPauseButtonChild = ObxO(
                              rx: Player.inst.playWhenReady,
                              builder: (context, playWhenReady) => Obx(
                                (context) {
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
                                        verticalPadding: 4.0,
                                        horizontalPadding: 4.0,
                                        onPressed: Player.inst.togglePlayPause,
                                        icon: null,
                                        child: AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 200),
                                          child: playWhenReady
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
                              ),
                            );
                            final nextButton = NamidaIconButton(
                              verticalPadding: 4.0,
                              horizontalPadding: 4.0,
                              icon: Broken.next,
                              iconColor: defaultIconColor,
                              onPressed: () {
                                Player.inst.next();
                              },
                            );

                            return ObxO(
                              rx: settings.enableBottomNavBar,
                              builder: (context, enableBottomNavBar) => ObxO(
                                rx: settings.dismissibleMiniplayer,
                                builder: (context, dismissibleMiniplayer) => NamidaYTMiniplayer(
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
                                    final double finalthumbnailWidth =
                                        (space2ForThumbnail + maxWidth * percentage).clamp(space2ForThumbnail, maxWidth - finalspace1sb - finalspace3sb);
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
                                                    disableControlsUnderPercentage: 0.5,
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
                                            if (NamidaNavigator.inst.isInYTCommentsSubpage ||
                                                    NamidaNavigator.inst.isInYTCommentRepliesSubpage ||
                                                    NamidaNavigator.inst.isQueueSheetOpen
                                                ? true
                                                : percentage > 0)
                                              Expanded(
                                                child: Stack(
                                                  fit: StackFit.expand,
                                                  children: [
                                                    miniplayerBody,
                                                    IgnorePointer(
                                                      child: ColoredBox(
                                                        color: miniplayerBGColor.withValues(alpha: 1 - percentageFast),
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
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
