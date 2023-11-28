import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:get/get.dart';
import 'package:jiffy/jiffy.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/packages/mp.dart';
import 'package:namida/packages/three_arched_circle.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart' hide YoutubePlaylist;
import 'package:namida/youtube/functions/add_to_playlist_sheet.dart';
import 'package:namida/youtube/functions/download_sheet.dart';
import 'package:namida/youtube/functions/video_listens_dialog.dart';
import 'package:namida/youtube/widgets/yt_action_button.dart';
import 'package:namida/youtube/widgets/yt_channel_card.dart';
import 'package:namida/youtube/widgets/yt_comment_card.dart';
import 'package:namida/youtube/widgets/yt_playlist_card.dart';
import 'package:namida/youtube/widgets/yt_shimmer.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:namida/youtube/widgets/yt_video_card.dart';

const _space2ForThumbnail = 90.0;
const kYoutubeMiniplayerHeight = 12.0 + _space2ForThumbnail * 9 / 16;

class YoutubeMiniPlayer extends StatelessWidget {
  const YoutubeMiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    const space1sb = 8.0;
    const space2ForThumbnail = _space2ForThumbnail;
    const space3sb = 8.0;
    const space4 = 38.0 * 2;
    const space5sb = 8.0;
    const miniplayerHeight = kYoutubeMiniplayerHeight;

    final relatedThumbnailWidth = context.width * 0.36;
    final relatedThumbnailHeight = relatedThumbnailWidth * 9 / 16;
    final relatedThumbnailItemExtent = relatedThumbnailHeight + 8.0 * 2;

    return SafeArea(
      child: DefaultTextStyle(
        style: context.textTheme.displayMedium!,
        child: Obx(
          () {
            final videoInfo = YoutubeController.inst.currentYoutubeMetadataVideo.value ?? Player.inst.currentVideoInfo;
            final videoChannel = YoutubeController.inst.currentYoutubeMetadataChannel.value;

            String? uploadDate;
            String? uploadDateAgo;

            final parsedDate = videoInfo?.date ?? Player.inst.currentVideoInfo?.date;

            if (parsedDate != null) {
              uploadDate = parsedDate.millisecondsSinceEpoch.dateFormattedOriginal;
              uploadDateAgo = Jiffy.parseFromDateTime(parsedDate).fromNow();
            }

            final miniTitle = videoInfo?.name;
            final miniSubtitle = videoChannel?.name ?? videoInfo?.uploaderName;
            final currentId = videoInfo?.id ?? Player.inst.nowPlayingVideoID?.id ?? Player.inst.nowPlayingTrack.youtubeID; // last one not needed

            final channelName = videoChannel?.name ?? videoInfo?.uploaderName;
            final channelThumbnail = videoChannel?.thumbnailUrl ?? videoInfo?.uploaderAvatarUrl;
            final channelIsVerified = videoChannel?.isVerified ?? videoInfo?.isUploaderVerified ?? false;
            final channelSubs = videoChannel?.subscriberCount ?? Player.inst.currentChannelInfo?.subscriberCount;

            final isUserLiked = YoutubePlaylistController.inst.favouritesPlaylist.value.tracks.firstWhereEff((element) => element.id == currentId) != null;

            final videoLikeCount = (isUserLiked ? 1 : 0) + (videoInfo?.likeCount ?? Player.inst.currentVideoInfo?.likeCount ?? 0);
            final videoDislikeCount = videoInfo?.dislikeCount ?? Player.inst.currentVideoInfo?.dislikeCount;
            final videoViewCount = videoInfo?.viewCount ?? Player.inst.currentVideoInfo?.viewCount;

            final descriptionWidget = videoInfo == null
                ? null
                : Html(
                    data: videoInfo.description ?? '',
                    style: {
                      '*': Style.fromTextStyle(
                        context.textTheme.displayMedium!.copyWith(
                          fontSize: 14.0.multipliedFontScale,
                        ),
                      ),
                      'a': Style.fromTextStyle(
                        context.textTheme.displayMedium!.copyWith(
                          color: context.theme.colorScheme.primary.withAlpha(210),
                          fontSize: 13.5.multipliedFontScale,
                        ),
                      )
                    },
                    onLinkTap: (url, attributes, element) async {
                      if (url != null) {
                        try {
                          await launchUrlString(url, mode: LaunchMode.externalNonBrowserApplication);
                        } catch (e) {
                          await launchUrlString(url);
                        }
                      }
                    },
                  );

            YoutubeController.inst.downloadedFilesMap; // for refreshing.
            final downloadedFileExists = YoutubeController.inst.doesIDHasFileDownloaded(currentId) != null;

            return NamidaYTMiniplayer(
              key: MiniPlayerController.inst.ytMiniplayerKey,
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutExpo,
              bottomMargin: 8.0 + (settings.enableBottomNavBar.value ? kBottomNavigationBarHeight : 0.0),
              minHeight: miniplayerHeight,
              maxHeight: context.height,
              decoration: BoxDecoration(
                color: context.theme.scaffoldBackgroundColor,
              ),
              onDismiss: settings.dismissibleMiniplayer.value
                  ? () async {
                      CurrentColor.inst.resetCurrentPlayingTrack();
                      await Player.inst.pause();
                      await [
                        Player.inst.clearQueue(),
                        Player.inst.dispose(),
                      ].execute();
                      Player.inst.setPlayerVolume(settings.playerVolume.value);
                    }
                  : null,
              onDismissing: (dismissPercentage) {
                Player.inst.setPlayerVolume(dismissPercentage.clamp(0.0, settings.playerVolume.value));
              },
              onHeightChange: (percentage) => MiniPlayerController.inst.animateMiniplayer(percentage),
              builder: (double height, double p) {
                final percentageOriginal = p.clamp(0.0, 1.0);
                final percentage = (p * 2.8).clamp(0.0, 1.0);
                final inversePercOriginal = 1 - percentageOriginal;
                final inversePerc = 1 - percentage;
                final reverseOpacity = (inversePerc * 2.8 - 1.8).clamp(0.0, 1.0);
                final finalspace1sb = space1sb * inversePerc;
                final finalspace3sb = space3sb * inversePerc;
                final finalspace4buttons = space4 * inversePerc;
                final finalspace5sb = space5sb * inversePerc;
                final finalpadding = 4.0 * inversePerc;
                final finalbr = (8.0 * inversePerc).multipliedRadius;
                final finalthumbnailsize = (space2ForThumbnail + context.width * percentage).clamp(space2ForThumbnail, context.width - finalspace1sb - finalspace3sb);

                return Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomLeft,
                      children: [
                        Row(
                          children: [
                            SizedBox(width: finalspace1sb),
                            Obx(
                              () {
                                final shouldShowVideo = VideoController.vcontroller.isInitialized;
                                return Container(
                                  margin: EdgeInsets.symmetric(vertical: finalpadding),
                                  decoration: BoxDecoration(
                                    // color: shouldShowVideo ? Colors.black : CurrentColor.inst.color,
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(finalbr),
                                  ),
                                  width: finalthumbnailsize,
                                  height: finalthumbnailsize * 9 / 16,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(finalbr),
                                    child: NamidaVideoWidget(
                                      key: Key("${currentId}_$shouldShowVideo"),
                                      enableControls: percentage > 0.5,
                                      onMinimizeTap: () {
                                        MiniPlayerController.inst.ytMiniplayerKey.currentState?.animateToState(false);
                                      },
                                      swipeUpToFullscreen: true,
                                      fallbackChild: YoutubeThumbnail(
                                        isImportantInCache: true,
                                        width: finalthumbnailsize,
                                        height: finalthumbnailsize * 9 / 16,
                                        borderRadius: 0,
                                        blur: 0,
                                        videoId: currentId,
                                        displayFallbackIcon: false,
                                        compressed: false,
                                        preferLowerRes: false,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            if (reverseOpacity > 0) ...[
                              SizedBox(width: finalspace3sb),
                              SizedBox(
                                width: (context.width - finalthumbnailsize - finalspace1sb - finalspace3sb - finalspace4buttons - finalspace5sb).clamp(0, context.width),
                                child: NamidaOpacity(
                                  key: Key("${currentId}_title_button1"),
                                  enabled: true,
                                  opacity: reverseOpacity,
                                  child: Column(
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
                                            fontSize: 13.5.multipliedFontScale,
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
                                            fontSize: 13.0.multipliedFontScale,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
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
                                  child: Obx(
                                    () {
                                      final isLoading = Player.inst.shouldShowLoadingIndicator || VideoController.vcontroller.isBuffering;

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
                                                  color: context.defaultIconColor(),
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
                                              child: Player.inst.isPlaying
                                                  ? Icon(
                                                      Broken.pause,
                                                      color: context.defaultIconColor(),
                                                      key: const Key('pause'),
                                                    )
                                                  : Icon(
                                                      Broken.play,
                                                      color: context.defaultIconColor(),
                                                      key: const Key('play'),
                                                    ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
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
                                  child: NamidaIconButton(
                                    horizontalPadding: 0.0,
                                    icon: Broken.next,
                                    iconColor: context.defaultIconColor(),
                                    onPressed: () {
                                      Player.inst.next();
                                    },
                                  ),
                                ),
                              ),
                              SizedBox(width: finalspace5sb),
                            ]
                          ],
                        ),
                        // -- progress bar
                        NamidaOpacity(
                          key: Key("${currentId}_progress_bar"),
                          enabled: true,
                          opacity: 1.0 * reverseOpacity,
                          child: IgnorePointer(
                            key: Key("${currentId}_progress_bar_child"),
                            child: Obx(
                              () {
                                final dur = Player.inst.currentItemDuration?.inMilliseconds;
                                final percentage = dur == null ? 0 : Player.inst.nowPlayingPosition / dur;
                                return Container(
                                  alignment: Alignment.centerLeft,
                                  height: 2.0,
                                  decoration: BoxDecoration(
                                    color: CurrentColor.inst.color.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                                  ),
                                  width: percentage * context.width,
                                );
                              },
                            ),
                          ),
                        )
                      ],
                    ),

                    /// MiniPlayer Body, contains title, description, comments, ..etc.
                    if (percentage > 0)
                      Expanded(
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            // opacity: (percentage * 4 - 3).withMinimum(0),
                            Listener(
                              key: Key("${currentId}_body_listener"),
                              onPointerDown: (event) => YoutubeController.inst.cancelDimTimer(),
                              onPointerUp: (event) => YoutubeController.inst.startDimTimer(),
                              child: LazyLoadListView(
                                onReachingEnd: () async => await YoutubeController.inst.updateCurrentComments(currentId, fetchNextOnly: true),
                                extend: 400,
                                scrollController: YoutubeController.inst.scrollController,
                                listview: (controller) => ObxValue<RxBool>(
                                  (isTitleExpanded) => Stack(
                                    key: Key("${currentId}_body_stack"),
                                    children: [
                                      CustomScrollView(
                                        // key: PageStorageKey(currentId), // duplicate errors
                                        physics: const ClampingScrollPhysics(),
                                        controller: controller,
                                        slivers: [
                                          SliverPadding(padding: EdgeInsets.only(top: inversePercOriginal * 48.0)),

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
                                                textColor: Color.alphaBlend(CurrentColor.inst.color.withAlpha(40), context.theme.colorScheme.onBackground),
                                                collapsedTextColor: context.theme.colorScheme.onBackground,
                                                iconColor: Color.alphaBlend(CurrentColor.inst.color.withAlpha(40), context.theme.colorScheme.onBackground),
                                                collapsedIconColor: context.theme.colorScheme.onBackground,
                                                childrenPadding: const EdgeInsets.all(18.0),
                                                onExpansionChanged: (value) => isTitleExpanded.value = value,
                                                trailing: Obx(
                                                  () {
                                                    final videoListens = YoutubeHistoryController.inst.topTracksMapListens[currentId] ?? [];
                                                    return Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        if (videoListens.isNotEmpty)
                                                          NamidaInkWell(
                                                            borderRadius: 6.0,
                                                            bgColor: CurrentColor.inst.color.withOpacity(0.7),
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
                                                          ),
                                                        const SizedBox(width: 8.0),
                                                        const Icon(
                                                          Broken.arrow_down_2,
                                                          size: 20.0,
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                ),
                                                title: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    NamidaDummyContainer(
                                                      width: context.width * 0.8,
                                                      height: 24.0,
                                                      borderRadius: 6.0,
                                                      shimmerEnabled: videoInfo == null,
                                                      child: Text(
                                                        videoInfo?.name ?? '',
                                                        maxLines: isTitleExpanded.value ? 6 : 2,
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
                                                        final expandedDate = isTitleExpanded.value ? uploadDate : null;
                                                        final collapsedDate = isTitleExpanded.value ? null : uploadDateAgo;
                                                        return Text(
                                                          [
                                                            if (videoViewCount != null)
                                                              "${videoViewCount.formatDecimalShort(isTitleExpanded.value)} ${videoViewCount == 0 ? lang.VIEW : lang.VIEWS}",
                                                            if (expandedDate != null) expandedDate,
                                                            if (collapsedDate != null) collapsedDate,
                                                          ].join(' • '),
                                                          style: context.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w500),
                                                        );
                                                      }(),
                                                    ),
                                                  ],
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
                                                    SmallYTActionButton(
                                                      title: videoInfo == null
                                                          ? null
                                                          : videoLikeCount < 1
                                                              ? lang.LIKE
                                                              : videoLikeCount.formatDecimalShort(isTitleExpanded.value),
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
                                                    const SizedBox(width: 4.0),
                                                    SmallYTActionButton(
                                                      title: (videoDislikeCount ?? 0) < 1 ? lang.DISLIKE : videoDislikeCount?.formatDecimalShort(isTitleExpanded.value) ?? '?',
                                                      icon: Broken.dislike,
                                                      onPressed: () {},
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
                                                        final audioPerc = audioProgress == null
                                                            ? null
                                                            : "${lang.AUDIO} ${(audioProgress.progress / audioProgress.totalProgress * 100).toStringAsFixed(0)}%";
                                                        final videoProgress = YoutubeController.inst.downloadsVideoProgressMap[currentId]?.values.firstOrNull;
                                                        final videoPerc = videoProgress == null
                                                            ? null
                                                            : "${lang.VIDEO} ${(videoProgress.progress / videoProgress.totalProgress * 100).toStringAsFixed(0)}%";

                                                        final isDownloading = YoutubeController.inst.isDownloading[currentId]?.values.any((element) => element) == true;

                                                        final wasDownloading = videoPerc != null || audioPerc != null;
                                                        final icon = (wasDownloading && !isDownloading)
                                                            ? Broken.play_circle
                                                            : wasDownloading
                                                                ? Broken.pause_circle
                                                                : downloadedFileExists
                                                                    ? Broken.tick_circle
                                                                    : Broken.import;
                                                        return SmallYTActionButton(
                                                          titleWidget: videoPerc == null && audioPerc == null && isDownloading ? const LoadingIndicator() : null,
                                                          title: videoPerc ?? audioPerc ?? lang.DOWNLOAD,
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
                                              child: Row(
                                                children: [
                                                  const SizedBox(width: 18.0),
                                                  NamidaDummyContainer(
                                                    width: 48.0,
                                                    height: 48.0,
                                                    borderRadius: 100.0,
                                                    shimmerEnabled: channelThumbnail == null,
                                                    child: YoutubeThumbnail(
                                                      key: Key(channelThumbnail ?? ''),
                                                      isImportantInCache: true,
                                                      channelUrl: channelThumbnail ?? '',
                                                      width: 48.0,
                                                      height: 48.0,
                                                      isCircle: true,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12.0),
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
                                                                    fontSize: 12.5.multipliedFontScale,
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
                                                                  size: 14.0,
                                                                ),
                                                              ]
                                                            ],
                                                          ),
                                                        ),
                                                        const SizedBox(height: 4.0),
                                                        FittedBox(
                                                          child: NamidaDummyContainer(
                                                            width: 92.0,
                                                            height: 10.0,
                                                            borderRadius: 4.0,
                                                            shimmerEnabled: channelSubs == null,
                                                            child: Text(
                                                              [
                                                                channelSubs?.formatDecimalShort(isTitleExpanded.value) ?? '?',
                                                                (channelSubs ?? 0) < 2 ? lang.SUBSCRIBER : lang.SUBSCRIBERS
                                                              ].join(' '),
                                                              style: context.textTheme.displaySmall,
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12.0),
                                                  TextButton(
                                                    child: Row(
                                                      children: [
                                                        const Icon(Broken.video, size: 20.0),
                                                        const SizedBox(width: 8.0),
                                                        Text(lang.SUBSCRIBE),
                                                      ],
                                                    ),
                                                    onPressed: () {},
                                                  ),
                                                  const SizedBox(width: 24.0),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SliverPadding(padding: EdgeInsets.only(top: 18.0)),
                                          // --END-- channel

                                          Obx(
                                            () {
                                              final feed = YoutubeController.inst.currentRelatedVideos;
                                              if (feed.isNotEmpty && feed.first == null) {
                                                return SliverToBoxAdapter(
                                                  key: Key("${currentId}_feed_shimmer"),
                                                  child: ShimmerWrapper(
                                                    transparent: false,
                                                    shimmerEnabled: true,
                                                    child: ListView.builder(
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
                                                    return ShimmerWrapper(
                                                      transparent: false,
                                                      shimmerDurationMS: 550,
                                                      shimmerDelayMS: 250,
                                                      shimmerEnabled: item == null,
                                                      child: YoutubeVideoCard(
                                                        key: Key("${item == null}_${context.hashCode}_${(item as StreamInfoItem?)?.id}"),
                                                        thumbnailHeight: relatedThumbnailHeight,
                                                        thumbnailWidth: relatedThumbnailWidth,
                                                        isImageImportantInCache: false,
                                                        video: item,
                                                        playlistID: null,
                                                      ),
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
                                              final totalCommentsCount = YoutubeController.inst.currentTotalCommentsCount.value;
                                              return Padding(
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
                                                              color: context.defaultIconColor(),
                                                            ),
                                                    )
                                                  ],
                                                ),
                                              ).toSliver();
                                            },
                                          ),
                                          Obx(
                                            () {
                                              final comments = YoutubeController.inst.currentComments;
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
                                                  return ShimmerWrapper(
                                                    transparent: false,
                                                    shimmerDurationMS: 550,
                                                    shimmerDelayMS: 250,
                                                    shimmerEnabled: comment == null,
                                                    child: YTCommentCard(
                                                      key: Key("${comment == null}_${context.hashCode}_${comment?.commentId}"),
                                                      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                                      comment: comment,
                                                    ),
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                          Obx(
                                            () {
                                              final isLoadingComments = YoutubeController.inst.isLoadingComments.value;
                                              return isLoadingComments
                                                  ? SliverPadding(
                                                      padding: const EdgeInsets.all(12.0),
                                                      sliver: const Center(
                                                        child: LoadingIndicator(),
                                                      ).toSliver(),
                                                    )
                                                  : const SizedBox().toSliver();
                                            },
                                          ),
                                        ],
                                      ),
                                      () {
                                        const containerHeight = 12.0;
                                        return Obx(
                                          () => AnimatedSwitcher(
                                            duration: const Duration(milliseconds: 300),
                                            child: YoutubeController.inst.shouldShowGlowUnderVideo
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
                                          ),
                                        );
                                      }()
                                    ],
                                  ),
                                  false.obs,
                                ),
                              ),
                            ),

                            // -- dimming
                            Positioned.fill(
                              key: const Key('dimmie'),
                              child: IgnorePointer(
                                child: Obx(
                                  () => AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 600),
                                    reverseDuration: const Duration(milliseconds: 200),
                                    child: YoutubeController.inst.canDimMiniplayer
                                        ? Container(
                                            color: Colors.black.withOpacity(settings.ytMiniplayerDimOpacity.value),
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
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
