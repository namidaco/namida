import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:get/get.dart';
import 'package:jiffy/jiffy.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/packages/dots_triangle.dart';
import 'package:namida/packages/mp.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/youtube/functions/add_to_playlist_sheet.dart';
import 'package:namida/youtube/functions/download_sheet.dart';
import 'package:namida/youtube/widgets/yt_action_button.dart';
import 'package:namida/youtube/widgets/yt_comment_card.dart';
import 'package:namida/youtube/widgets/yt_playlist_card.dart';
import 'package:namida/youtube/widgets/yt_shimmer.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:namida/youtube/widgets/yt_video_card.dart';

class YoutubeMiniPlayer extends StatelessWidget {
  const YoutubeMiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    const space1sb = 8.0;
    const space2 = 90.0;
    const space3sb = 8.0;
    const space4 = 38.0 * 2;
    const space5sb = 8.0;
    const miniplayerHeight = 12.0 + space2 * 9 / 16;

    return SafeArea(
      child: Obx(
        () => NamidaYTMiniplayer(
          key: MiniPlayerController.inst.ytMiniplayerKey,
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeOutExpo,
          bottomMargin: 8.0 + (settings.enableBottomNavBar.value ? kBottomNavigationBarHeight : 0.0),
          minHeight: miniplayerHeight,
          maxHeight: context.height,
          decoration: BoxDecoration(
            color: context.isDarkMode
                ? Color.alphaBlend(
                    CurrentColor.inst.color.withAlpha(10),
                    const Color.fromARGB(255, 25, 25, 25),
                  )
                : Color.alphaBlend(
                    CurrentColor.inst.color.withAlpha(40),
                    context.isDarkMode ? const Color.fromARGB(255, 25, 25, 25) : const Color.fromARGB(255, 250, 250, 250),
                  ),
          ),
          onHeightChange: (percentage) => MiniPlayerController.inst.animateMiniplayer(percentage),
          builder: (double height, double p) {
            final percentage = p.clamp(0.0, 1.0);
            final inversePerc = 1 - percentage;
            final reverseOpacity = (inversePerc * 2 - 1).clamp(0.0, 1.0);
            final finalspace1sb = space1sb * inversePerc;
            final finalspace3sb = space3sb * inversePerc;
            final finalspace4buttons = space4 * inversePerc;
            final finalspace5sb = space5sb * inversePerc;
            final finalpadding = 4.0 * inversePerc;
            final finalbr = (8.0 * inversePerc).multipliedRadius;
            final finalthumbnailsize = (space2 + context.width * percentage).clamp(space2, context.width - finalspace1sb - finalspace3sb);

            return SafeArea(
              child: Obx(
                () {
                  final ytvideo = YoutubeController.inst.currentYoutubeMetadata.value;

                  final parsedDate = ytvideo?.video.uploadDate == null ? null : Jiffy.parse(ytvideo!.video.uploadDate!);
                  final uploadDate = parsedDate?.millisecondsSinceEpoch.dateFormattedOriginal;
                  final uploadDateAgo = parsedDate?.fromNow();

                  final miniTitle = ytvideo?.video.name;
                  final miniSubtitle = ytvideo?.channel.name;
                  final currentId = ytvideo?.video.id ?? Player.inst.nowPlayingVideoID?.id ?? Player.inst.nowPlayingTrack.youtubeID;
                  return DefaultTextStyle(
                    style: context.textTheme.displayMedium!,
                    child: Column(
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
                                    child: VideoController.inst.getVideoWidget(
                                      "${currentId}_$shouldShowVideo",
                                      true,
                                      () {
                                        MiniPlayerController.inst.ytMiniplayerKey.currentState?.animateToState(false);
                                      },
                                      fallbackChild: YoutubeThumbnail(
                                        key: Key("$percentage$currentId"),
                                        width: finalthumbnailsize,
                                        height: finalthumbnailsize * 9 / 16,
                                        borderRadius: 0,
                                        blur: 0,
                                        videoId: currentId,
                                        displayFallbackIcon: false,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            if (reverseOpacity > 0) ...[
                              SizedBox(width: finalspace3sb),
                              SizedBox(
                                width: (context.width - (context.width * percentage) - finalspace1sb - space2 - finalspace3sb - finalspace4buttons - finalspace5sb)
                                    .clamp(0, context.width),
                                child: Opacity(
                                  opacity: reverseOpacity,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      NamidaBasicShimmer(
                                        borderRadius: 4.0,
                                        height: 16.0,
                                        shimmerEnabled: ytvideo == null,
                                        width: context.width - 24.0,
                                        child: Text(
                                          miniTitle?.overflow ?? '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: context.textTheme.displayMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13.5.multipliedFontScale,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4.0),
                                      NamidaBasicShimmer(
                                        borderRadius: 4.0,
                                        height: 10.0,
                                        shimmerEnabled: ytvideo == null,
                                        width: context.width - 24.0 * 2,
                                        child: Text(
                                          miniSubtitle?.overflow ?? '',
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
                              Opacity(
                                opacity: reverseOpacity,
                                child: SizedBox(
                                  width: finalspace4buttons / 2,
                                  height: miniplayerHeight,
                                  child: Obx(
                                    () => NamidaIconButton(
                                      horizontalPadding: 0.0,
                                      onPressed: () => Player.inst.togglePlayPause(),
                                      icon: Player.inst.isPlaying ? Broken.pause : Broken.play,
                                    ),
                                  ),
                                ),
                              ),
                              Opacity(
                                opacity: reverseOpacity,
                                child: SizedBox(
                                  width: finalspace4buttons / 2,
                                  height: miniplayerHeight,
                                  child: NamidaIconButton(
                                    horizontalPadding: 0.0,
                                    icon: Broken.next,
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

                        /// MiniPlayer Body, contains title, description, comments, ..etc.
                        if (percentage > 0)
                          Expanded(
                            child: Opacity(
                              opacity: percentage,
                              child: LazyLoadListView(
                                onReachingEnd: () async => await YoutubeController.inst.updateCurrentComments(currentId, fetchNextOnly: true),
                                extend: 400,
                                scrollController: YoutubeController.inst.scrollController,
                                listview: (controller) => ObxValue<RxBool>(
                                  (isTitleExpanded) => Stack(
                                    children: [
                                      CustomScrollView(
                                        // key: PageStorageKey(currentId), // duplicate errors
                                        controller: controller,
                                        slivers: [
                                          SliverPadding(padding: EdgeInsets.only(top: 100.0 * inversePerc)),

                                          // --START-- title & subtitle
                                          SliverToBoxAdapter(
                                            child: ExpansionTile(
                                              initiallyExpanded: false,
                                              maintainState: true,
                                              expandedAlignment: Alignment.centerLeft,
                                              expandedCrossAxisAlignment: CrossAxisAlignment.start,
                                              tilePadding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 14.0),
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
                                                      maxLines: isTitleExpanded.value ? 6 : 2,
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
                                                    title: ytvideo == null
                                                        ? null
                                                        : (ytvideo.video.likeCount ?? 0) < 1
                                                            ? lang.LIKE
                                                            : ytvideo.video.likeCount?.formatDecimalShort(isTitleExpanded.value) ?? '?',
                                                    icon: Broken.like_1,
                                                    onPressed: () {},
                                                  ),
                                                  const SizedBox(width: 18.0),
                                                  SmallYTActionButton(
                                                    title: (ytvideo?.video.dislikeCount ?? 0) < 1
                                                        ? lang.DISLIKE
                                                        : ytvideo?.video.dislikeCount?.formatDecimalShort(isTitleExpanded.value) ?? '?',
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
                                                        onPressed: () async => await showDownloadVideoBottomSheet(videoId: currentId),
                                                      );
                                                    },
                                                  ),
                                                  const SizedBox(width: 18.0),
                                                  SmallYTActionButton(
                                                    title: lang.SAVE,
                                                    icon: Broken.music_playlist,
                                                    onPressed: () => showAddToPlaylistSheet(
                                                      ids: [currentId],
                                                      idsNamesLookup: {
                                                        currentId: ytvideo?.video.name ?? '',
                                                      },
                                                    ),
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
                                                Expanded(
                                                  child: Column(
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
                                          Obx(
                                            () {
                                              final totalCommentsCount = YoutubeController.inst.currentTotalCommentsCount.value;
                                              return Padding(
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
                                              ).toSliver();
                                            },
                                          ),
                                          Obx(
                                            () {
                                              final comments = YoutubeController.inst.currentComments;
                                              return SliverList.builder(
                                                itemCount: comments.length,
                                                itemBuilder: (context, i) {
                                                  return YTCommentCard(
                                                    margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                                    comment: comments[i],
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
                                        const containerHeight = 20.0;
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
                          ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
