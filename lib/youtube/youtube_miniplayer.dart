import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:jiffy/jiffy.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';
import 'package:share_plus/share_plus.dart';

import 'package:namida/controller/connectivity.dart';
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
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart' hide YoutubePlaylist;
import 'package:namida/youtube/functions/add_to_playlist_sheet.dart';
import 'package:namida/youtube/functions/download_sheet.dart';
import 'package:namida/youtube/functions/video_listens_dialog.dart';
import 'package:namida/youtube/pages/yt_channel_subpage.dart';
import 'package:namida/youtube/seek_ready_widget.dart';
import 'package:namida/youtube/widgets/yt_action_button.dart';
import 'package:namida/youtube/widgets/yt_channel_card.dart';
import 'package:namida/youtube/widgets/yt_comment_card.dart';
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
  State<YoutubeMiniPlayer> createState() => _YoutubeMiniPlayerState();
}

class _YoutubeMiniPlayerState extends State<YoutubeMiniPlayer> {
  final _numberOfRepeats = 1.obs;
  bool _canScrollQueue = true;

  NamidaYTMiniplayerState? get _mpState => MiniPlayerController.inst.ytMiniplayerKey.currentState;

  final _velocity = VelocityTracker.withKind(PointerDeviceKind.touch);

  void _updateCanScrollQueue(bool can) {
    if (_canScrollQueue == can) return;
    setState(() => _canScrollQueue = can);
  }

  @override
  void dispose() {
    _numberOfRepeats.close();
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

    final miniplayerBGColor = Color.alphaBlend(context.theme.secondaryHeaderColor.withOpacity(0.25), context.theme.scaffoldBackgroundColor);

    const seekReadyWidget = SeekReadyWidget();

    return DefaultTextStyle(
      style: context.textTheme.displayMedium!,
      child: ObxO(
        rx: YoutubePlaylistController.inst.favouritesPlaylist,
        builder: (favouritesPlaylist) {
          return Obx(
            () {
              final videoInfo = YoutubeController.inst.currentYoutubeMetadataVideo.valueR ?? Player.inst.currentVideoInfo.valueR;
              final videoChannel = YoutubeController.inst.currentYoutubeMetadataChannel.valueR;

              String? uploadDate;
              String? uploadDateAgo;

              final parsedDate = videoInfo?.date ?? Player.inst.currentVideoInfo.valueR?.date;

              if (parsedDate != null) {
                uploadDate = parsedDate.millisecondsSinceEpoch.dateFormattedOriginal;
                uploadDateAgo = Jiffy.parseFromDateTime(parsedDate).fromNow();
              }

              final miniTitle = videoInfo?.name;
              final miniSubtitle = videoChannel?.name ?? videoInfo?.uploaderName;
              final currentId = Player.inst.getCurrentVideoIdR;

              final channelName = videoChannel?.name ?? videoInfo?.uploaderName;
              final channelThumbnail = videoChannel?.avatarUrl ?? videoInfo?.uploaderAvatarUrl;
              final channelIsVerified = videoChannel?.isVerified ?? videoInfo?.isUploaderVerified ?? false;
              final channelSubs = videoChannel?.subscriberCount ?? Player.inst.currentChannelInfo.valueR?.subscriberCount;
              final channelIDOrURL = videoChannel?.id ?? videoInfo?.uploaderUrl ?? Player.inst.currentChannelInfo.valueR?.id;

              final isUserLiked = favouritesPlaylist.tracks.firstWhereEff((element) => element.id == currentId) != null;

              final videoLikeCount = (isUserLiked ? 1 : 0) + (videoInfo?.likeCount ?? Player.inst.currentVideoInfo.valueR?.likeCount ?? 0);
              final videoDislikeCount = videoInfo?.dislikeCount ?? Player.inst.currentVideoInfo.valueR?.dislikeCount;
              final videoViewCount = videoInfo?.viewCount ?? Player.inst.currentVideoInfo.valueR?.viewCount;

              final description = videoInfo?.description;
              final descriptionWidget = description == null || description == ''
                  ? null
                  : SelectionArea(
                      child: Html(
                        data: description,
                        style: {
                          '*': Style.fromTextStyle(
                            context.textTheme.displayMedium!.copyWith(
                              fontSize: 14.0,
                            ),
                          ),
                          'a': Style.fromTextStyle(
                            context.textTheme.displayMedium!.copyWith(
                              color: context.theme.colorScheme.primary.withAlpha(210),
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
                alignment: Alignment.bottomCenter,
                children: [
                  // opacity: (percentage * 4 - 3).withMinimum(0),
                  Listener(
                    key: Key("${currentId}_body_listener"),
                    onPointerMove: (event) {
                      if (event.delta.dy > 0) {
                        if (YoutubeController.inst.scrollController.hasClients) {
                          if (YoutubeController.inst.scrollController.position.pixels <= 0) {
                            _updateCanScrollQueue(false);
                          }
                        }
                      } else {
                        if (_mpState == null || _mpState?.controller.value == 1) _updateCanScrollQueue(true);
                      }
                    },
                    onPointerDown: (_) {
                      YoutubeController.inst.cancelDimTimer();
                      _updateCanScrollQueue(true);
                    },
                    onPointerUp: (_) {
                      YoutubeController.inst.startDimTimer();
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
                                await YoutubeController.inst.updateCurrentComments(currentId, fetchNextOnly: true);
                              },
                              extend: 400,
                              scrollController: YoutubeController.inst.scrollController,
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
                                          shimmerEnabled: videoInfo == null,
                                          child: ExpansionTile(
                                            // key: Key(currentId),
                                            initiallyExpanded: false,
                                            maintainState: false,
                                            expandedAlignment: Alignment.centerLeft,
                                            expandedCrossAxisAlignment: CrossAxisAlignment.start,
                                            tilePadding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 14.0),
                                            textColor: Color.alphaBlend(CurrentColor.inst.miniplayerColor.withAlpha(40), context.theme.colorScheme.onSurface),
                                            collapsedTextColor: context.theme.colorScheme.onSurface,
                                            iconColor: Color.alphaBlend(CurrentColor.inst.miniplayerColor.withAlpha(40), context.theme.colorScheme.onSurface),
                                            collapsedIconColor: context.theme.colorScheme.onSurface,
                                            childrenPadding: const EdgeInsets.all(18.0),
                                            onExpansionChanged: (value) => YoutubeController.inst.isTitleExpanded.value = value,
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
                                                        style: context.textTheme.displaySmall?.copyWith(
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
                                                      url: videoInfo?.url,
                                                      channelUrl: channelIDOrURL,
                                                      playlistID: null,
                                                      idsNamesLookup: {videoId: videoInfo?.name},
                                                    );
                                                    if (Player.inst.currentVideo != null && videoId == Player.inst.getCurrentVideoId) {
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
                                              rx: YoutubeController.inst.isTitleExpanded,
                                              builder: (isTitleExpanded) => Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  NamidaDummyContainer(
                                                    width: context.width * 0.8,
                                                    height: 24.0,
                                                    borderRadius: 6.0,
                                                    shimmerEnabled: videoInfo == null,
                                                    child: Text(
                                                      videoInfo?.name ?? '',
                                                      maxLines: isTitleExpanded ? 6 : 2,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: context.textTheme.displayLarge,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4.0),
                                                  NamidaDummyContainer(
                                                    width: context.width * 0.7,
                                                    height: 12.0,
                                                    shimmerEnabled: videoInfo == null,
                                                    child: () {
                                                      final expandedDate = isTitleExpanded ? uploadDate : null;
                                                      final collapsedDate = isTitleExpanded ? null : uploadDateAgo;
                                                      return Text(
                                                        [
                                                          if (videoViewCount != null)
                                                            "${videoViewCount.formatDecimalShort(isTitleExpanded)} ${videoViewCount == 0 ? lang.VIEW : lang.VIEWS}",
                                                          if (expandedDate != null) expandedDate,
                                                          if (collapsedDate != null) collapsedDate,
                                                        ].join(' • '),
                                                        style: context.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w500),
                                                      );
                                                    }(),
                                                  ),
                                                ],
                                              ),
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
                                          shimmerEnabled: videoInfo == null,
                                          child: SizedBox(
                                            width: context.width,
                                            child: Wrap(
                                              alignment: WrapAlignment.spaceEvenly,
                                              children: [
                                                const SizedBox(width: 4.0),
                                                ObxO(
                                                  rx: YoutubeController.inst.isTitleExpanded,
                                                  builder: (isTitleExpanded) => SmallYTActionButton(
                                                    title: videoInfo == null
                                                        ? null
                                                        : videoLikeCount < 1
                                                            ? lang.LIKE
                                                            : videoLikeCount.formatDecimalShort(isTitleExpanded),
                                                    icon: Broken.like_1,
                                                    smallIconWidget: FittedBox(
                                                      child: NamidaRawLikeButton(
                                                        likedIcon: Broken.like_filled,
                                                        normalIcon: Broken.like_1,
                                                        disabledColor: context.theme.iconTheme.color,
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
                                                  rx: YoutubeController.inst.isTitleExpanded,
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
                                                    final url = videoInfo?.url;
                                                    if (url != null) Share.share(url);
                                                  },
                                                ),
                                                const SizedBox(width: 4.0),
                                                SmallYTActionButton(
                                                  title: lang.REFRESH,
                                                  icon: Broken.refresh,
                                                  onPressed: () async => await YoutubeController.inst.updateVideoDetails(currentId, forceRequest: true),
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
                                                      currentId: videoInfo?.name ?? '',
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
                                                final channel = videoChannel ?? Player.inst.currentChannelInfo.value;
                                                final chid = channel?.id;
                                                if (chid != null) NamidaNavigator.inst.navigateTo(YTChannelSubpage(channelID: chid, channel: channel));
                                              },
                                              child: Row(
                                                children: [
                                                  const SizedBox(width: 18.0),
                                                  NamidaDummyContainer(
                                                    width: 42.0,
                                                    height: 42.0,
                                                    borderRadius: 100.0,
                                                    shimmerEnabled: channelThumbnail == null && (channelIDOrURL == null || channelIDOrURL == ''),
                                                    child: YoutubeThumbnail(
                                                      key: Key("${channelThumbnail}_$channelIDOrURL"),
                                                      isImportantInCache: true,
                                                      channelUrl: channelThumbnail ?? '',
                                                      channelIDForHQImage: channelIDOrURL ?? '',
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
                                                                  style: context.textTheme.displayMedium?.copyWith(
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
                                                              rx: YoutubeController.inst.isTitleExpanded,
                                                              builder: (isTitleExpanded) => Text(
                                                                channelSubs == null
                                                                    ? '? ${lang.SUBSCRIBERS}'
                                                                    : [
                                                                        channelSubs.formatDecimalShort(isTitleExpanded),
                                                                        channelSubs < 2 ? lang.SUBSCRIBER : lang.SUBSCRIBERS,
                                                                      ].join(' '),
                                                                style: context.textTheme.displaySmall?.copyWith(
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
                                                  YTSubscribeButton(channelIDOrURL: channelIDOrURL),
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
                                      Obx(
                                        () {
                                          if (!settings.ytTopComments.valueR) return const SliverToBoxAdapter(child: SizedBox());
                                          final totalCommentsCount = YoutubeController.inst.currentTotalCommentsCount.valueR;
                                          final comments = YoutubeController.inst.currentComments.valueR;
                                          return SliverToBoxAdapter(
                                            child: comments.isEmpty
                                                ? const SizedBox()
                                                : NamidaInkWell(
                                                    key: Key("${currentId}_top_comments_highlight"),
                                                    bgColor: Color.alphaBlend(context.theme.scaffoldBackgroundColor.withOpacity(0.4), context.theme.cardColor),
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
                                                      children: [
                                                        Row(
                                                          mainAxisAlignment: MainAxisAlignment.start,
                                                          children: [
                                                            const Icon(
                                                              Broken.document,
                                                              size: 16.0,
                                                            ),
                                                            const SizedBox(width: 8.0),
                                                            Text(
                                                              [
                                                                lang.COMMENTS,
                                                                if (totalCommentsCount != null) totalCommentsCount.formatDecimalShort(),
                                                              ].join(' • '),
                                                              style: context.textTheme.displaySmall,
                                                              textAlign: TextAlign.start,
                                                            ),
                                                            const Spacer(),
                                                            NamidaIconButton(
                                                              horizontalPadding: 0.0,
                                                              tooltip: YoutubeController.inst.isCurrentCommentsFromCache ? lang.CACHE : null,
                                                              icon: Broken.refresh,
                                                              iconSize: 22.0,
                                                              onPressed: () async => await YoutubeController.inst.updateCurrentComments(
                                                                currentId,
                                                                forceRequest: ConnectivityController.inst.hasConnection,
                                                              ),
                                                              child: YoutubeController.inst.isCurrentCommentsFromCache
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
                                                            )
                                                          ],
                                                        ),
                                                        const NamidaContainerDivider(margin: EdgeInsets.symmetric(vertical: 4.0)),
                                                        ShimmerWrapper(
                                                          shimmerEnabled: comments.isNotEmpty && comments.first == null,
                                                          child: YTCommentCardCompact(comment: comments.firstOrNull),
                                                        )
                                                      ],
                                                    ),
                                                  ),
                                          );
                                        },
                                      ),
                                      const SliverPadding(padding: EdgeInsets.only(top: 8.0)),

                                      Obx(
                                        () {
                                          final feed = YoutubeController.inst.currentRelatedVideos.valueR;
                                          if (feed.isNotEmpty && feed.first == null) {
                                            return SliverToBoxAdapter(
                                              key: Key("${currentId}_feed_shimmer"),
                                              child: ShimmerWrapper(
                                                transparent: false,
                                                shimmerEnabled: true,
                                                child: ListView.builder(
                                                  padding: EdgeInsets.zero,
                                                  key: Key("${currentId}_feedlist_shimmer"),
                                                  physics: const NeverScrollableScrollPhysics(),
                                                  itemCount: feed.length,
                                                  shrinkWrap: true,
                                                  itemBuilder: (context, index) {
                                                    const item = null;
                                                    return YoutubeVideoCard(
                                                      key: Key("${item == null}_${context.hashCode}"),
                                                      thumbnailHeight: relatedThumbnailHeight,
                                                      thumbnailWidth: relatedThumbnailWidth,
                                                      isImageImportantInCache: false,
                                                      video: item,
                                                      playlistID: null,
                                                    );
                                                  },
                                                ),
                                              ),
                                            );
                                          }
                                          return SliverFixedExtentList.builder(
                                            key: Key("${currentId}_feedlist"),
                                            itemExtent: relatedThumbnailItemExtent,
                                            itemCount: feed.length,
                                            itemBuilder: (context, index) {
                                              final item = feed[index];
                                              if (item is StreamInfoItem || item == null) {
                                                return YoutubeVideoCard(
                                                  key: Key("${item == null}_${context.hashCode}_${(item as StreamInfoItem?)?.id}"),
                                                  thumbnailHeight: relatedThumbnailHeight,
                                                  thumbnailWidth: relatedThumbnailWidth,
                                                  isImageImportantInCache: false,
                                                  video: item,
                                                  playlistID: null,
                                                );
                                              } else if (item is YoutubePlaylist) {
                                                return YoutubePlaylistCard(
                                                  key: Key("${context.hashCode}_${(item).id}"),
                                                  playlist: item,
                                                  playOnTap: true,
                                                );
                                              } else if (item is YoutubeChannel) {
                                                return YoutubeChannelCard(
                                                  key: Key("${context.hashCode}_${(item as YoutubeChannelCard).channel?.id}"),
                                                  channel: item,
                                                );
                                              }
                                              return const SizedBox();
                                            },
                                          );
                                        },
                                      ),
                                      const SliverPadding(padding: EdgeInsets.only(top: 12.0)),

                                      // --START-- Comments
                                      Obx(
                                        () {
                                          if (settings.ytTopComments.valueR) return const SliverToBoxAdapter(child: SizedBox());

                                          final totalCommentsCount = YoutubeController.inst.currentTotalCommentsCount.valueR;
                                          return SliverToBoxAdapter(
                                            child: Padding(
                                              key: Key("${currentId}_comments_header"),
                                              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.start,
                                                children: [
                                                  const Icon(Broken.document),
                                                  const SizedBox(width: 8.0),
                                                  Text(
                                                    [
                                                      lang.COMMENTS,
                                                      if (totalCommentsCount != null) totalCommentsCount.formatDecimalShort(),
                                                    ].join(' • '),
                                                    style: context.textTheme.displayLarge,
                                                    textAlign: TextAlign.start,
                                                  ),
                                                  const Spacer(),
                                                  NamidaIconButton(
                                                    // key: Key(currentId),
                                                    tooltip: YoutubeController.inst.isCurrentCommentsFromCache ? lang.CACHE : null,
                                                    icon: Broken.refresh,
                                                    iconSize: 22.0,
                                                    onPressed: () async => await YoutubeController.inst.updateCurrentComments(
                                                      currentId,
                                                      forceRequest: ConnectivityController.inst.hasConnection,
                                                    ),
                                                    child: YoutubeController.inst.isCurrentCommentsFromCache
                                                        ? const StackedIcon(
                                                            baseIcon: Broken.refresh,
                                                            secondaryIcon: Broken.global,
                                                          )
                                                        : Icon(
                                                            Broken.refresh,
                                                            color: defaultIconColor,
                                                          ),
                                                  )
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      Obx(
                                        () {
                                          if (settings.ytTopComments.valueR) return const SliverToBoxAdapter(child: SizedBox());

                                          final comments = YoutubeController.inst.currentComments.valueR;
                                          if (comments.isNotEmpty && comments.first == null) {
                                            return SliverToBoxAdapter(
                                              key: Key("${currentId}_comments_shimmer"),
                                              child: ShimmerWrapper(
                                                transparent: false,
                                                shimmerEnabled: true,
                                                child: ListView.builder(
                                                  // key: Key(currentId),
                                                  physics: const NeverScrollableScrollPhysics(),
                                                  itemCount: comments.length,
                                                  shrinkWrap: true,
                                                  itemBuilder: (context, index) {
                                                    const comment = null;
                                                    return YTCommentCard(
                                                      key: Key("${comment == null}_${context.hashCode}"),
                                                      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                                      comment: comment,
                                                    );
                                                  },
                                                ),
                                              ),
                                            );
                                          }
                                          return SliverList.builder(
                                            key: Key("${currentId}_comments"),
                                            itemCount: comments.length,
                                            itemBuilder: (context, i) {
                                              final comment = comments[i];
                                              return YTCommentCard(
                                                key: Key("${comment == null}_${context.hashCode}_${comment?.commentId}"),
                                                margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                                comment: comment,
                                              );
                                            },
                                          );
                                        },
                                      ),
                                      Obx(
                                        () {
                                          if (settings.ytTopComments.valueR) return const SliverToBoxAdapter(child: SizedBox());

                                          final isLoadingComments = YoutubeController.inst.isLoadingComments.valueR;
                                          return isLoadingComments
                                              ? const SliverToBoxAdapter(
                                                  child: Padding(
                                                    padding: EdgeInsets.all(12.0),
                                                    child: Center(
                                                      child: LoadingIndicator(),
                                                    ),
                                                  ),
                                                )
                                              : const SliverToBoxAdapter(child: SizedBox());
                                        },
                                      ),

                                      const SliverPadding(padding: EdgeInsets.only(bottom: kYTQueueSheetMinHeight))
                                    ],
                                  ),
                                  ObxO(
                                    rx: YoutubeController.inst.shouldShowGlowUnderVideo,
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
                                                    color: context.theme.scaffoldBackgroundColor,
                                                  ),
                                                  Container(
                                                    height: containerHeight,
                                                    transform: Matrix4.translationValues(0, containerHeight / 2, 0),
                                                    decoration: BoxDecoration(
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: context.theme.scaffoldBackgroundColor,
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

                  YTMiniplayerQueueChip(key: NamidaNavigator.inst.ytQueueSheetKey),

                  // -- dimming
                  Positioned.fill(
                    key: const Key('dimmie'),
                    child: IgnorePointer(
                      child: Obx(
                        () => AnimatedSwitcher(
                          duration: const Duration(milliseconds: 600),
                          reverseDuration: const Duration(milliseconds: 200),
                          child: YoutubeController.inst.canDimMiniplayer.valueR
                              ? Container(
                                  color: Colors.black.withOpacity(settings.ytMiniplayerDimOpacity.valueR),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),

                  // prevent accidental scroll while performing home gesture
                  AbsorbPointer(
                    child: SizedBox(
                      height: 18.0,
                      width: context.width,
                    ),
                  ),
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
                    shimmerEnabled: videoInfo == null,
                    width: context.width - 24.0,
                    child: Text(
                      miniTitle ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  NamidaDummyContainer(
                    borderRadius: 4.0,
                    height: 10.0,
                    shimmerEnabled: videoInfo == null,
                    width: context.width - 24.0 * 2,
                    child: Text(
                      miniSubtitle ?? '',
                      style: context.textTheme.displaySmall?.copyWith(
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

              final rightDragAbsorberWidget = Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  height: context.height,
                  width: (context.width * 0.25).withMaximum(324.0),
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: (event) {
                      _mpState?.updatePercentageMultiplier(true);
                      _mpState?.setDragExternally(true);
                      _mpState?.saveDragHeightStart();
                      _velocity.addPosition(event.timeStamp, event.position);
                    },
                    onPointerMove: (event) {
                      if (!_canScrollQueue) {
                        _mpState?.onVerticalDragUpdate(event.delta.dy);
                        _velocity.addPosition(event.timeStamp, event.position);
                      }
                    },
                    onPointerUp: (event) {
                      if (YoutubeController.inst.scrollController.hasClients && YoutubeController.inst.scrollController.position.pixels <= 0) {
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
              return NamidaYTMiniplayer(
                key: MiniPlayerController.inst.ytMiniplayerKey,
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutExpo,
                bottomMargin: 8.0 + (settings.enableBottomNavBar.valueR ? kBottomNavigationBarHeight : 0.0) - 1.0, // -1 is just a clip ensurer.
                minHeight: miniplayerHeight,
                maxHeight: context.height,
                bgColor: miniplayerBGColor,
                displayBottomBGLayer: !settings.enableBottomNavBar.valueR,
                onDismiss: settings.dismissibleMiniplayer.valueR ? Player.inst.clearQueue : null,
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
                  final finalthumbnailWidth = (space2ForThumbnail + context.width * percentage).clamp(space2ForThumbnail, context.width - finalspace1sb - finalspace3sb);
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
                                  width: (context.width - finalthumbnailWidth - finalspace1sb - finalspace3sb - finalspace4buttons - finalspace5sb).clamp(0, context.width),
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
                                  rightDragAbsorberWidget,
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
              );
            },
          );
        },
      ),
    );
  }
}
