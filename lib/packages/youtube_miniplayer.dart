import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:jiffy/jiffy.dart';
import 'package:newpipeextractor_dart/models/videoInfo.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';
import 'package:readmore/readmore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/ffmpeg_controller.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/controller/youtube_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/packages/mp.dart';
import 'package:namida/packages/dots_triangle.dart';
import 'package:namida/packages/three_arched_circle.dart';
import 'package:namida/ui/pages/youtube_page.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';

class YoutubeMiniPlayer extends StatelessWidget {
  YoutubeMiniPlayer({super.key});
  final MiniplayerController minicontroller = MiniplayerController();
  final RxDouble minioffset = 0.0.obs;
  final isTitleExpanded = false.obs;

  @override
  Widget build(BuildContext context) {
    const space1sb = 8.0;
    const space2 = 90.0;
    const space3sb = 8.0;
    const space4 = 42.0 * 2;
    const space5sb = 8.0;
    const miniplayerHeight = 12.0 + 12.0 + space2 * 9 / 16;

    return SafeArea(
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 2000),
        offset: Offset(0.0, minioffset.value),
        child: Miniplayer(
          navBarHeight: 64.0,
          controller: minicontroller,
          minHeight: miniplayerHeight,
          maxHeight: context.height,
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              context.theme.cardColor.withAlpha(30),
              context.isDarkMode ? const Color.fromARGB(255, 30, 30, 30) : const Color.fromARGB(255, 250, 250, 250),
            ),
          ),
          onHeightChange: (percentage) => MiniPlayerController.inst.animation.animateTo(percentage, duration: Duration.zero),
          builder: (double height, double percentage) {
            final currentTrack = Player.inst.nowPlayingTrack;
            final currentId = currentTrack.youtubeID;
            final inversePerc = 1 - percentage;
            final finalspace1sb = space1sb * inversePerc;
            final finalspace3sb = space3sb * inversePerc;
            final finalspace4buttons = space4 * inversePerc;
            final finalspace5sb = space5sb * inversePerc;
            final finalpadding = 4.0 * inversePerc;
            final finalbr = (8.0 * inversePerc).multipliedRadius;
            final finalthumbnailsize = (space2 + context.width * percentage).clamp(space2, context.width - finalspace1sb - finalspace3sb);
            return SafeArea(
              child: Stack(
                children: [
                  Material(
                    // type: MaterialType.transparency,
                    child: DefaultTextStyle(
                      style: context.textTheme.displayMedium!,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              SizedBox(width: finalspace1sb),
                              Container(
                                margin: EdgeInsets.symmetric(vertical: finalpadding),
                                decoration: BoxDecoration(
                                  color: CurrentColor.inst.color,
                                  borderRadius: BorderRadius.circular(finalbr),
                                ),
                                width: finalthumbnailsize,
                                height: finalthumbnailsize * 9 / 16,
                                child: VideoController.inst.currentVideo.value != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(finalbr),
                                        child: VideoController.inst.getVideoWidget(const Key('video_widget'), true, () {
                                          minicontroller.animateToHeight(state: PanelState.min);
                                        }),
                                      )
                                    : ArtworkWidget(
                                        key: Key("$percentage$currentTrack"),
                                        path: currentTrack.pathToImage,
                                        thumbnailSize: finalthumbnailsize,
                                        width: finalthumbnailsize,
                                        height: finalthumbnailsize * 9 / 16,
                                        blur: 0,
                                        borderRadius: finalbr,
                                      ),
                              ),
                              SizedBox(width: finalspace3sb),
                              SizedBox(
                                width: (context.width - (context.width * percentage) - finalspace1sb - space2 - finalspace3sb - finalspace4buttons - finalspace5sb)
                                    .clamp(0, context.width),
                                child: Opacity(
                                  opacity: inversePerc,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        currentTrack.originalArtist.overflow,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        currentTrack.title.overflow,
                                        style: context.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w500),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Opacity(
                                opacity: inversePerc,
                                child: SizedBox(
                                  width: finalspace4buttons / 2,
                                  child: NamidaInkWell(
                                    transparentHighlight: true,
                                    onTap: () => Player.inst.playOrPause(Player.inst.currentIndex, [], QueueSource.playerQueue),
                                    child: Obx(() => Icon(Player.inst.isPlaying ? Broken.pause : Broken.play)),
                                  ),
                                ),
                              ),
                              Opacity(
                                opacity: inversePerc,
                                child: SizedBox(
                                  width: finalspace4buttons / 2,
                                  height: miniplayerHeight,
                                  child: NamidaInkWell(
                                    transparentHighlight: true,
                                    onTap: () {
                                      minicontroller.animateToHeight(height: 0);
                                      minioffset.value = 0.0;
                                    },
                                    child: const Icon(Broken.close_circle),
                                  ),
                                ),
                              ),
                              SizedBox(width: finalspace5sb),
                            ],
                          ),

                          /// MiniPlayer Body, contains title, description, comments, ..etc.
                          Expanded(
                            child: Opacity(
                              opacity: percentage,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: LazyLoadListView(
                                  onReachingEnd: () async => await YoutubeController.inst.updateCurrentComments(currentId, fetchNextOnly: true),
                                  extend: 400,
                                  scrollController: YoutubeController.inst.scrollController,
                                  listview: (controller) => Obx(
                                    () {
                                      final isLoadingComments = YoutubeController.inst.isLoadingComments.value;
                                      final totalCommentsCount = YoutubeController.inst.currentTotalCommentsCount.value;
                                      final ytvideo = YoutubeController.inst.currentYoutubeMetadata.value;
                                      final comments = YoutubeController.inst.currentComments;

                                      final parsedDate = ytvideo?.video.uploadDate == null ? null : Jiffy.parse(ytvideo!.video.uploadDate!);
                                      final uploadDate = parsedDate?.millisecondsSinceEpoch.dateFormattedOriginal;
                                      final uploadDateAgo = parsedDate?.fromNow();
                                      return CustomScrollView(
                                        key: PageStorageKey(currentId),
                                        controller: controller,
                                        slivers: [
                                          SliverPadding(padding: EdgeInsets.only(top: 100.0 * inversePerc)),

                                          // --START-- title & subtitle
                                          SliverToBoxAdapter(
                                            child: ExpansionTile(
                                              maintainState: true,
                                              expandedAlignment: Alignment.centerLeft,
                                              expandedCrossAxisAlignment: CrossAxisAlignment.start,
                                              tilePadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 18.0),
                                              textColor: Color.alphaBlend(CurrentColor.inst.color.withAlpha(40), context.theme.colorScheme.onBackground),
                                              collapsedTextColor: context.theme.colorScheme.onBackground,
                                              iconColor: Color.alphaBlend(CurrentColor.inst.color.withAlpha(40), context.theme.colorScheme.onBackground),
                                              collapsedIconColor: context.theme.colorScheme.onBackground,
                                              childrenPadding: const EdgeInsets.all(18.0),
                                              onExpansionChanged: (value) => isTitleExpanded.value = value,
                                              title: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  NamidaBasicShimmer(
                                                    width: context.width * 0.8,
                                                    height: 24.0,
                                                    borderRadius: 6.0,
                                                    shimmerEnabled: ytvideo == null,
                                                    child: Text(
                                                      ytvideo?.video.name ?? '',
                                                      maxLines: isTitleExpanded.value ? null : 2,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: context.textTheme.displayLarge,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4.0),
                                                  NamidaBasicShimmer(
                                                    width: context.width * 0.7,
                                                    height: 12.0,
                                                    shimmerEnabled: ytvideo == null,
                                                    child: Text(
                                                      [
                                                        ytvideo?.video.viewCount.formatDecimalShort(isTitleExpanded.value),
                                                        if (parsedDate != null) isTitleExpanded.value ? uploadDate : uploadDateAgo,
                                                      ].join(' • '),
                                                      style: context.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w500),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              children: [
                                                if (ytvideo != null)
                                                  Html(
                                                    data: ytvideo.video.description ?? '',
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
                                                  ),
                                              ],
                                            ),
                                          ),
                                          // --END-- title & subtitle

                                          // --START-- buttons
                                          SliverToBoxAdapter(
                                            child: SizedBox(
                                              height: 60.0,
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                // shrinkWrap: true,
                                                // scrollDirection: Axis.horizontal,
                                                children: [
                                                  const SizedBox(width: 18.0),
                                                  SmallYTActionButton(
                                                    title: (ytvideo?.video.likeCount ?? 0) < 1
                                                        ? lang.LIKE
                                                        : ytvideo?.video.likeCount?.formatDecimalShort(isTitleExpanded.value) ?? '?',
                                                    icon: Broken.like_1,
                                                    onPressed: () {},
                                                  ),
                                                  const SizedBox(width: 18.0),
                                                  SmallYTActionButton(
                                                    title: ytvideo == null
                                                        ? null
                                                        : (ytvideo.video.dislikeCount ?? 0) < 1
                                                            ? lang.DISLIKE
                                                            : ytvideo.video.dislikeCount?.formatDecimalShort(isTitleExpanded.value) ?? '?',
                                                    icon: Broken.dislike,
                                                    onPressed: () {},
                                                  ),
                                                  const SizedBox(width: 18.0),
                                                  SmallYTActionButton(
                                                    title: lang.SHARE,
                                                    icon: Broken.share,
                                                    onPressed: () {
                                                      final url = ytvideo?.video.url;
                                                      if (url != null) Share.share(url);
                                                    },
                                                  ),
                                                  const SizedBox(width: 18.0),
                                                  SmallYTActionButton(
                                                    title: lang.REFRESH,
                                                    icon: Broken.refresh,
                                                    onPressed: () async => await YoutubeController.inst.updateVideoDetails(currentId),
                                                  ),
                                                  const SizedBox(width: 18.0),
                                                  Obx(
                                                    () {
                                                      final audioProgress = YoutubeController.inst.downloadsAudioProgressMap[currentId];
                                                      final audioPerc = audioProgress == null
                                                          ? null
                                                          : "${lang.AUDIO} ${(audioProgress.progress / audioProgress.totalProgress * 100).toStringAsFixed(0)}%";
                                                      final videoProgress = YoutubeController.inst.downloadsVideoProgressMap[currentId];
                                                      final videoPerc = videoProgress == null
                                                          ? null
                                                          : "${lang.VIDEO} ${(videoProgress.progress / videoProgress.totalProgress * 100).toStringAsFixed(0)}%";

                                                      final isDownloading = YoutubeController.inst.isDownloading[currentId] == true;
                                                      return SmallYTActionButton(
                                                        iconWidget: isDownloading
                                                            ? DotsTriangle(
                                                                color: context.defaultIconColor(),
                                                                size: 24.0,
                                                              )
                                                            : null,
                                                        titleWidget: videoPerc == null && audioPerc == null && isDownloading ? const LoadingIndicator() : null,
                                                        title: videoPerc ?? audioPerc ?? lang.DOWNLOAD,
                                                        icon: false ? Broken.tick_circle : Broken.import, // TODO: check if video already downloaded
                                                        onPressed: () async => await showDownloadVideoBottomSheet(context: context, videoId: currentId),
                                                      );
                                                    },
                                                  ),
                                                  const SizedBox(width: 18.0),
                                                  SmallYTActionButton(
                                                    title: lang.SAVE,
                                                    icon: Broken.music_playlist,
                                                    onPressed: () {},
                                                  ),
                                                  const SizedBox(width: 18.0),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SliverPadding(padding: EdgeInsets.only(top: 24.0)),
                                          // --END- buttons

                                          // --START- channel
                                          SliverToBoxAdapter(
                                            child: Row(
                                              children: [
                                                const SizedBox(width: 18.0),
                                                NamidaBasicShimmer(
                                                  width: 48.0,
                                                  height: 48.0,
                                                  borderRadius: 100.0,
                                                  shimmerEnabled: ytvideo == null,
                                                  child: YoutubeThumbnail(
                                                    channelUrl: ytvideo?.channel.avatarUrl ?? '',
                                                    width: 48.0,
                                                    height: 48.0,
                                                    isCircle: true,
                                                  ),
                                                ),
                                                const SizedBox(width: 12.0),
                                                Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    NamidaBasicShimmer(
                                                      width: 114.0,
                                                      height: 12.0,
                                                      borderRadius: 4.0,
                                                      shimmerEnabled: ytvideo == null,
                                                      child: Text(ytvideo?.channel.name ?? ''),
                                                    ),
                                                    const SizedBox(height: 2.0),
                                                    NamidaBasicShimmer(
                                                      width: 92.0,
                                                      height: 10.0,
                                                      borderRadius: 4.0,
                                                      shimmerEnabled: ytvideo == null,
                                                      child: Text(
                                                        [
                                                          ytvideo?.channel.subscriberCount?.formatDecimalShort(isTitleExpanded.value) ?? '?',
                                                          (ytvideo?.channel.subscriberCount ?? 0) < 2 ? lang.SUBSCRIBER : lang.SUBSCRIBERS
                                                        ].join(' '),
                                                        style: context.textTheme.displaySmall,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const Spacer(),
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
                                          const SliverPadding(padding: EdgeInsets.only(top: 12.0)),
                                          // --END-- channel

                                          Obx(
                                            () => SliverList.builder(
                                              itemCount: YoutubeController.inst.currentRelatedVideos.length,
                                              itemBuilder: (context, index) {
                                                final item = YoutubeController.inst.currentRelatedVideos[index];
                                                if (item is StreamInfoItem || item == null) {
                                                  return YoutubeVideoCard(video: item as StreamInfoItem?);
                                                } else if (item is YoutubePlaylist) {
                                                  return YoutubePlaylistCard(playlist: item);
                                                }
                                                return const SizedBox();
                                              },
                                            ),
                                          ),
                                          const SliverPadding(padding: EdgeInsets.only(top: 12.0)),

                                          // --START-- Comments
                                          Padding(
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
                                                  tooltip: YoutubeController.inst.isCurrentCommentsFromCache ? lang.CACHE : null,
                                                  icon: Broken.refresh,
                                                  iconSize: 22.0,
                                                  onPressed: () async => await YoutubeController.inst.updateCurrentComments(currentId, forceRequest: true),
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
                                          ).toSliver(),
                                          SliverList.builder(
                                            itemCount: comments.length,
                                            itemBuilder: (context, i) {
                                              final com = comments[i];
                                              final uploaderAvatar = com?.uploaderAvatarUrl;
                                              final author = com?.author;
                                              final uploadedFrom = com?.uploadDate;
                                              final commentText = com?.commentText;
                                              final likeCount = com?.likeCount;
                                              final repliesCount = com?.replyCount == -1 ? null : com?.replyCount;
                                              final isHearted = com?.hearted ?? false;
                                              final isPinned = com?.pinned ?? false;

                                              final containerColor = context.theme.cardColor.withAlpha(100);

                                              return Container(
                                                key: ValueKey(i),
                                                margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                                padding: const EdgeInsets.all(10.0),
                                                decoration: BoxDecoration(
                                                  color: containerColor,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: context.theme.shadowColor.withAlpha(60),
                                                      blurRadius: 4.0,
                                                      spreadRadius: 1.0,
                                                      offset: const Offset(0.0, 2.0),
                                                    ),
                                                  ],
                                                  borderRadius: BorderRadius.circular(
                                                    12.0.multipliedRadius,
                                                  ),
                                                ),
                                                child: SizedBox(
                                                  width: context.width,
                                                  child: Row(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      NamidaBasicShimmer(
                                                        width: 42.0,
                                                        height: 42.0,
                                                        borderRadius: 999,
                                                        shimmerEnabled: uploaderAvatar == null,
                                                        child: YoutubeThumbnail(
                                                          channelUrl: uploaderAvatar,
                                                          width: 42.0,
                                                          isCircle: true,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 10.0),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            const SizedBox(height: 2.0),
                                                            if (isPinned) ...[
                                                              Row(
                                                                children: [
                                                                  const Icon(
                                                                    Broken.path,
                                                                    size: 16.0,
                                                                  ),
                                                                  const SizedBox(width: 4.0),
                                                                  Text(
                                                                    lang.PINNED,
                                                                    style: context.textTheme.displaySmall,
                                                                  ),
                                                                ],
                                                              ),
                                                              const SizedBox(height: 4.0),
                                                            ],
                                                            NamidaBasicShimmer(
                                                              width: context.width * 0.5,
                                                              height: 12.0,
                                                              borderRadius: 6.0,
                                                              shimmerEnabled: author == null,
                                                              child: Row(
                                                                children: [
                                                                  Text(
                                                                    [
                                                                      author,
                                                                      if (uploadedFrom != null) uploadedFrom,
                                                                    ].join(' • '),
                                                                    style: context.textTheme.displaySmall
                                                                        ?.copyWith(fontWeight: FontWeight.w400, color: context.theme.colorScheme.onBackground.withAlpha(180)),
                                                                  ),
                                                                  if (isHearted) ...[
                                                                    const SizedBox(width: 4.0),
                                                                    const Icon(
                                                                      Broken.heart_tick,
                                                                      size: 16.0,
                                                                      color: Colors.red,
                                                                    ),
                                                                  ],
                                                                ],
                                                              ),
                                                            ),
                                                            const SizedBox(height: 4.0),
                                                            AnimatedSwitcher(
                                                              duration: const Duration(milliseconds: 200),
                                                              child: commentText == null
                                                                  ? Column(
                                                                      children: [
                                                                        ...List.filled(
                                                                          3,
                                                                          const Padding(
                                                                            padding: EdgeInsets.only(top: 2.0),
                                                                            child: NamidaBasicShimmer(
                                                                              width: null,
                                                                              height: 12.0,
                                                                              borderRadius: 4.0,
                                                                              shimmerEnabled: true,
                                                                              child: null,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    )
                                                                  : ReadMoreText(
                                                                      HtmlParser.parseHTML(commentText).text,
                                                                      trimLines: 5,
                                                                      colorClickableText: context.theme.colorScheme.primary.withAlpha(200),
                                                                      trimMode: TrimMode.Line,
                                                                      trimCollapsedText: lang.SHOW_MORE,
                                                                      trimExpandedText: '',
                                                                      style: context.textTheme.displaySmall?.copyWith(
                                                                        fontSize: 13.5.multipliedFontScale,
                                                                        fontWeight: FontWeight.w500,
                                                                        color: context.theme.colorScheme.onBackground.withAlpha(220),
                                                                      ),
                                                                    ),
                                                            ),
                                                            const SizedBox(height: 8.0),
                                                            Row(
                                                              children: [
                                                                const Icon(Broken.like_1, size: 16.0),
                                                                const SizedBox(width: 4.0),
                                                                NamidaBasicShimmer(
                                                                  width: 18.0,
                                                                  height: 8.0,
                                                                  borderRadius: 4.0,
                                                                  shimmerEnabled: likeCount == null,
                                                                  child: Text(
                                                                    likeCount?.formatDecimalShort(isTitleExpanded.value) ?? '?',
                                                                    style: context.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w300),
                                                                  ),
                                                                ),
                                                                const SizedBox(width: 12.0),
                                                                const Icon(Broken.dislike, size: 16.0),
                                                                const SizedBox(width: 16.0),
                                                                SizedBox(
                                                                  height: 28.0,
                                                                  child: TextButton.icon(
                                                                    style: TextButton.styleFrom(
                                                                      visualDensity: VisualDensity.compact,
                                                                      foregroundColor: context.theme.colorScheme.onBackground.withAlpha(200),
                                                                    ),
                                                                    onPressed: () {},
                                                                    icon: const Icon(Broken.document, size: 16.0),
                                                                    label: Text(
                                                                      [
                                                                        lang.REPLIES,
                                                                        if (repliesCount != null) repliesCount,
                                                                      ].join(' • '),
                                                                      style: context.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w300),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      GestureDetector(
                                                        child: const MoreIcon(),
                                                        onTapDown: (details) => _showCommentMenu(context, details, com),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          if (isLoadingComments)
                                            SliverPadding(
                                              padding: const EdgeInsets.all(12.0),
                                              sliver: const Center(
                                                child: LoadingIndicator(),
                                              ).toSliver(),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // TODO: view channel details.
  _showCommentMenu(BuildContext context, TapDownDetails details, YoutubeComment? comment) {
    Widget getItem({
      required String title,
      required IconData icon,
    }) {
      return Row(
        children: [
          Icon(icon, size: 20.0),
          const SizedBox(width: 6.0),
          Text(title),
        ],
      );
    }

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx,
        details.globalPosition.dy,
      ),
      items: [
        PopupMenuItem(
          child: getItem(
            icon: Broken.copy,
            title: lang.COPY,
          ),
          onTap: () => comment?.commentText != null ? Clipboard.setData(ClipboardData(text: comment!.commentText!)) : null,
        ),
      ],
    );
  }
}

class SmallYTActionButton extends StatelessWidget {
  final String? title;
  final IconData icon;
  final void Function()? onPressed;
  final Widget? iconWidget;
  final Widget? titleWidget;

  const SmallYTActionButton({
    super.key,
    required this.title,
    required this.icon,
    this.onPressed,
    this.iconWidget,
    this.titleWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        iconWidget ??
            NamidaInkWell(
              borderRadius: 32.0,
              onTap: onPressed,
              padding: const EdgeInsets.all(6.0),
              child: Icon(icon),
            ),
        NamidaBasicShimmer(
          width: 24.0,
          height: 8.0,
          borderRadius: 4.0,
          fadeDurationMS: titleWidget == null ? 600 : 100,
          shimmerEnabled: title == null,
          child: titleWidget ??
              Text(
                title ?? '',
                style: context.textTheme.displaySmall,
              ),
        ),
      ],
    );
  }
}

class YoutubeThumbnail extends StatefulWidget {
  final String? channelUrl;
  final String? videoId;
  final double? height;
  final double width;
  final double borderRadius;
  final bool isCircle;
  final EdgeInsetsGeometry? margin;
  final void Function(File? imageFile)? onImageReady;
  final List<Widget> onTopWidgets;

  const YoutubeThumbnail({
    super.key,
    this.channelUrl,
    this.videoId,
    this.height,
    required this.width,
    this.borderRadius = 12.0,
    this.isCircle = false,
    this.margin,
    this.onImageReady,
    this.onTopWidgets = const <Widget>[],
  });

  @override
  State<YoutubeThumbnail> createState() => _YoutubeThumbnailState();
}

class _YoutubeThumbnailState extends State<YoutubeThumbnail> {
  String? imagePath;
  @override
  void initState() {
    super.initState();
    _getThumbnail();
  }

  Future<void> _getThumbnail() async {
    final res = await VideoController.inst.getYoutubeThumbnailAndCache(id: widget.videoId, channelUrl: widget.channelUrl);
    widget.onImageReady?.call(res);
    imagePath = res?.path;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      margin: widget.margin,
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        color: context.theme.cardColor.withAlpha(100),
        shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: widget.isCircle
            ? null
            : BorderRadius.circular(
                widget.borderRadius.multipliedRadius,
              ),
      ),
      child: ArtworkWidget(
        fadeMilliSeconds: 600,
        path: imagePath,
        height: widget.height,
        width: widget.width,
        thumbnailSize: widget.width,
        icon: widget.channelUrl != null ? Broken.user : Broken.video,
        iconSize: widget.channelUrl != null ? null : widget.width * 0.3,
        forceSquared: true,
        onTopWidgets: widget.onTopWidgets,
      ),
    );
  }
}

Future<void> showDownloadVideoBottomSheet({
  required BuildContext context,
  required String videoId,
  Color? colorScheme,
}) async {
  colorScheme ??= CurrentColor.inst.color;

  final showAudioWebm = false.obs;
  final showVideoWebm = false.obs;
  final video = Rxn<YoutubeVideo>();
  final selectedAudioOnlyStream = Rxn<AudioOnlyStream>();
  final selectedVideoOnlyStream = Rxn<VideoOnlyStream>();
  final videoInfo = Rxn<VideoInfo>();
  final videoOutputFilename = ''.obs;
  final videoThumbnail = Rxn<File>();

  void updatefilenameOutput() {
    final videoTitle = videoInfo.value?.name ?? videoId;
    if (selectedAudioOnlyStream.value == null && selectedVideoOnlyStream.value == null) {
      videoOutputFilename.value = videoTitle;
    } else {
      final audioOnly = selectedAudioOnlyStream.value != null && selectedVideoOnlyStream.value == null;
      if (audioOnly) {
        final filenameRealAudio = "$videoTitle.${selectedAudioOnlyStream.value?.formatSuffix}";
        videoOutputFilename.value = filenameRealAudio;
      } else {
        final filenameRealVideo = "${videoTitle}_${selectedVideoOnlyStream.value?.resolution}.${selectedVideoOnlyStream.value?.formatSuffix}";
        videoOutputFilename.value = filenameRealVideo;
      }
    }
  }

  YoutubeController.inst.getAvailableStreams(videoId).then((value) {
    video.value = value;
    videoInfo.value = video.value?.videoInfo;

    selectedAudioOnlyStream.value = video.value?.audioOnlyStreams?.firstWhereEff((e) => e.formatSuffix != 'webm');

    selectedVideoOnlyStream.value = video.value?.videoOnlyStreams?.firstWhereEff(
          (e) =>
              e.formatSuffix != 'webm' &&
              settings.youtubeVideoQualities.contains(
                e.resolution?.videoLabelToSettingLabel(),
              ),
        ) ??
        video.value?.videoOnlyStreams?.firstWhereEff((e) => e.formatSuffix != 'webm');
    video.value?.videoStreams?.loopFuture(
      (e, index) async {
        final size = await YoutubeController.inst.getContentSize(e.url ?? '');
        e.sizeInBytes = size;
        video.refresh();
      },
    );

    updatefilenameOutput();
  });

  Widget getQualityButton({
    required final String title,
    final String subtitle = '',
    required final bool cacheExists,
    required final bool selected,
    final double horizontalPadding = 8.0,
    final double verticalPadding = 8.0,
    required void Function() onTap,
  }) {
    final selectedColor = colorScheme!;
    return NamidaInkWell(
      decoration: selected
          ? BoxDecoration(
              border: Border.all(
                color: selectedColor,
              ),
            )
          : const BoxDecoration(),
      animationDurationMS: 100,
      margin: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 4.0),
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      onTap: () {
        onTap();
        updatefilenameOutput();
      },
      borderRadius: 8.0,
      bgColor: selected ? Color.alphaBlend(selectedColor.withAlpha(40), context.theme.cardTheme.color!) : context.theme.cardTheme.color,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: horizontalPadding),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.textTheme.displayMedium?.copyWith(
                  fontSize: 12.0.multipliedFontScale,
                ),
              ),
              if (subtitle != '')
                Text(
                  subtitle,
                  style: context.textTheme.displaySmall?.copyWith(
                    fontSize: 12.0.multipliedFontScale,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 6.0),
          Icon(cacheExists ? Broken.tick_circle : Broken.import, size: 18.0),
          SizedBox(width: horizontalPadding),
        ],
      ),
    );
  }

  Widget getTextWidget({
    required final String title,
    required final String? subtitle,
    final IconData? icon,
    final Widget? leading,
    final TextStyle? style,
    required final void Function()? onSussyIconTap,
    required final void Function() onCloseIconTap,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          leading ?? Icon(icon),
          const SizedBox(width: 8.0),
          Text(
            title,
            style: style ?? context.textTheme.displayMedium,
          ),
          if (subtitle != null) ...[
            const SizedBox(width: 8.0),
            Text(
              '• $subtitle',
              style: style ?? context.textTheme.displaySmall,
            ),
          ],
          const Spacer(),
          NamidaIconButton(
            tooltip: lang.SHOW_WEBM,
            horizontalPadding: 0.0,
            iconSize: 20.0,
            icon: Broken.video_octagon,
            onPressed: onSussyIconTap,
          ),
          const SizedBox(width: 12.0),
          NamidaIconButton(
            horizontalPadding: 0.0,
            iconSize: 20.0,
            icon: Broken.close_circle,
            onPressed: () {
              onCloseIconTap();
              updatefilenameOutput();
            },
          ),
          const SizedBox(width: 12.0),
        ],
      ),
    );
  }

  Widget getDivider() => const NamidaContainerDivider(margin: EdgeInsets.symmetric(vertical: 8.0));

  Widget getPopupItem<T>({
    required List<T> items,
    required Widget Function(T item) itemBuilder,
  }) {
    return Wrap(
      children: [
        ...items.map((element) => itemBuilder(element)).toList(),
      ],
    );
  }

  showModalBottomSheet(
    context: context,
    builder: (context) {
      return SizedBox(
        width: context.width,
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Obx(
            () => video.value == null
                ? Center(
                    child: ThreeArchedCircle(
                      color: colorScheme!,
                      size: context.width * 0.4,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Obx(
                          () => Row(
                            children: [
                              YoutubeThumbnail(
                                videoId: videoId,
                                width: context.width * 0.2,
                                height: context.width * 0.2 * 9 / 16,
                                onImageReady: (imageFile) {
                                  videoThumbnail.value = imageFile;
                                },
                              ),
                              const SizedBox(width: 12.0),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    NamidaBasicShimmer(
                                      borderRadius: 6.0,
                                      width: context.width,
                                      height: 18.0,
                                      shimmerEnabled: videoInfo.value == null,
                                      child: Text(
                                        videoInfo.value?.name ?? videoId,
                                        style: context.textTheme.displayMedium,
                                      ),
                                    ),
                                    const SizedBox(height: 2.0),
                                    NamidaBasicShimmer(
                                      borderRadius: 4.0,
                                      width: context.width - 24.0,
                                      height: 12.0,
                                      shimmerEnabled: videoInfo.value == null,
                                      child: () {
                                        final dateFormatted =
                                            videoInfo.value?.uploadDate != null ? Jiffy.parse(videoInfo.value!.uploadDate!).millisecondsSinceEpoch.dateFormattedOriginal : null;
                                        return Text(
                                          [
                                            videoInfo.value?.duration?.inSeconds.secondsLabel ?? "00:00",
                                            if (dateFormatted != null) dateFormatted,
                                          ].join(' - '),
                                          style: context.textTheme.displaySmall,
                                        );
                                      }(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            Obx(
                              () {
                                final e = selectedAudioOnlyStream.value;
                                final subtitle = e == null ? null : "${e.bitrateText} • ${e.formatSuffix} • ${e.sizeInBytes?.fileSizeFormatted}";
                                return getTextWidget(
                                  title: lang.AUDIO,
                                  subtitle: subtitle,
                                  icon: Broken.audio_square,
                                  onCloseIconTap: () => selectedAudioOnlyStream.value = null,
                                  onSussyIconTap: () {
                                    showAudioWebm.value = !showAudioWebm.value;
                                    if (showAudioWebm.value == false && selectedAudioOnlyStream.value?.formatSuffix == 'webm') {
                                      selectedAudioOnlyStream.value = video.value?.audioOnlyStreams?.firstOrNull;
                                    }
                                  },
                                );
                              },
                            ),
                            if (video.value!.audioOnlyStreams != null)
                              Obx(
                                () => getPopupItem(
                                  items: showAudioWebm.value
                                      ? video.value!.audioOnlyStreams!
                                      : video.value!.audioOnlyStreams!.where((element) => element.formatSuffix != 'webm').toList(),
                                  itemBuilder: (element) {
                                    return Obx(
                                      () {
                                        return getQualityButton(
                                          selected: selectedAudioOnlyStream.value == element,
                                          cacheExists: false,
                                          title: "${element.codec} • ${element.sizeInBytes?.fileSizeFormatted}",
                                          subtitle: "${element.formatSuffix} • ${element.bitrateText}",
                                          onTap: () => selectedAudioOnlyStream.value = element,
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            getDivider(),
                            Obx(
                              () {
                                final e = selectedVideoOnlyStream.value;
                                final subtitle = e == null ? null : "${e.resolution} • ${e.sizeInBytes?.fileSizeFormatted}";
                                return getTextWidget(
                                  title: lang.VIDEO,
                                  subtitle: subtitle,
                                  icon: Broken.video_square,
                                  onCloseIconTap: () => selectedVideoOnlyStream.value = null,
                                  onSussyIconTap: () {
                                    showVideoWebm.value = !showVideoWebm.value;
                                    if (showVideoWebm.value == false && selectedVideoOnlyStream.value?.formatSuffix == 'webm') {
                                      selectedVideoOnlyStream.value = video.value?.videoOnlyStreams?.firstOrNull;
                                    }
                                  },
                                );
                              },
                            ),
                            if (video.value!.videoOnlyStreams != null)
                              Obx(
                                () {
                                  return getPopupItem(
                                    items: showVideoWebm.value
                                        ? video.value!.videoOnlyStreams!
                                        : video.value!.videoOnlyStreams!.where((element) => element.formatSuffix != 'webm').toList(),
                                    itemBuilder: (element) {
                                      return Obx(
                                        () {
                                          final cacheFile = VideoController.inst.videoInCacheRealCheck(videoId, element);
                                          return getQualityButton(
                                            selected: selectedVideoOnlyStream.value == element,
                                            cacheExists: cacheFile != null,
                                            title: "${element.resolution} • ${element.sizeInBytes?.fileSizeFormatted}",
                                            subtitle: "${element.formatSuffix} • ${element.bitrateText}",
                                            onTap: () => selectedVideoOnlyStream.value = element,
                                          );
                                        },
                                      );
                                    },
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12.0),
                      Obx(() {
                        final videoOnly = selectedVideoOnlyStream.value != null && selectedAudioOnlyStream.value == null ? "Video Only" : null;
                        final audioOnly = selectedVideoOnlyStream.value == null && selectedAudioOnlyStream.value != null ? "Audio Only" : null;
                        final audioAndVideo = selectedVideoOnlyStream.value != null && selectedAudioOnlyStream.value != null ? "${lang.VIDEO} + ${lang.AUDIO}" : null;

                        return RichText(
                          text: TextSpan(
                            text: "${lang.OUTPUT}: ",
                            style: context.textTheme.displaySmall,
                            children: [
                              TextSpan(
                                text: videoOnly ?? audioOnly ?? audioAndVideo ?? lang.NONE,
                                style: context.textTheme.displayMedium?.copyWith(color: videoOnly != null ? Colors.red : null),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 6.0),
                      Obx(() {
                        return RichText(
                          text: TextSpan(
                            text: "${lang.FILE_NAME}: ",
                            style: context.textTheme.displaySmall,
                            children: [
                              TextSpan(
                                text: videoOutputFilename.value,
                                style: context.textTheme.displayMedium,
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 12.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            flex: 1,
                            child: NamidaButton(
                              text: lang.CANCEL,
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          const SizedBox(width: 12.0),
                          Expanded(
                            flex: 2,
                            child: Obx(
                              () {
                                final sizeSum = (selectedVideoOnlyStream.value?.sizeInBytes ?? 0) + (selectedAudioOnlyStream.value?.sizeInBytes ?? 0);
                                final sizeText = sizeSum > 0 ? "(${sizeSum.fileSizeFormatted})" : '';
                                return NamidaButton(
                                  enabled: sizeSum > 0,
                                  text: '${lang.DOWNLOAD} $sizeText',
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    final id = videoId;
                                    await YoutubeController.inst.downloadYoutubeVideoRaw(
                                      id: id,
                                      useCachedVersionsIfAvailable: true,
                                      saveDirectory: Directory(AppDirs.INTERNAL_STORAGE),
                                      filename: videoOutputFilename.value,
                                      videoStream: selectedVideoOnlyStream.value,
                                      audioStream: selectedAudioOnlyStream.value,
                                      merge: true,
                                      onInitialVideoFileSize: (initialFileSize) {},
                                      onInitialAudioFileSize: (initialFileSize) {},
                                      videoDownloadingStream: (downloadedBytes) {},
                                      audioDownloadingStream: (downloadedBytes) {},
                                      onAudioFileReady: (audioFile) async {
                                        final dateTime = DateTime.tryParse(videoInfo.value?.uploadDate ?? '');
                                        if (videoThumbnail.value != null) {
                                          await NamidaFFMPEG.inst.editAudioThumbnail(audioPath: audioFile.path, thumbnailPath: videoThumbnail.value!.path);
                                        }
                                        await NamidaFFMPEG.inst.editMetadata(
                                          path: audioFile.path,
                                          tagsMap: {
                                            FFMPEGTagField.title: videoInfo.value?.name,
                                            FFMPEGTagField.artist: videoInfo.value?.uploaderName,
                                            FFMPEGTagField.comment: YoutubeController.inst.getYoutubeLink(id),
                                            FFMPEGTagField.year: dateTime == null ? null : DateFormat('yyyyMMdd').format(dateTime),
                                            FFMPEGTagField.synopsis: videoInfo.value?.description == null ? null : HtmlParser.parseHTML(videoInfo.value!.description!).text,
                                          },
                                        );
                                      },
                                      onVideoFileReady: (videoFile) async {},
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
          ),
        ),
      );
    },
  );
}
