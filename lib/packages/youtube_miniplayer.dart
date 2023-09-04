import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:get/get.dart';
import 'package:jiffy/jiffy.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';
import 'package:readmore/readmore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/controller/youtube_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/packages/mp.dart';
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
      child: Obx(
        () => Transform.translate(
          offset: Offset(0.0, -64.0 * (1.0 - MiniPlayerController.inst.miniplayerHP.value)),
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 2000),
            offset: Offset(0.0, minioffset.value),
            child: Miniplayer(
              controller: minicontroller,
              minHeight: miniplayerHeight,
              maxHeight: Get.height,
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  context.theme.cardColor.withAlpha(30),
                  context.isDarkMode ? const Color.fromARGB(255, 30, 30, 30) : const Color.fromARGB(255, 250, 250, 250),
                ),
              ),
              builder: (height, percentage) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  MiniPlayerController.inst.miniplayerHP.value = percentage;
                });
                final currentTrack = Player.inst.nowPlayingTrack;
                final currentId = currentTrack.youtubeID;
                final inversePerc = 1 - percentage;
                final finalspace1sb = space1sb * inversePerc;
                final finalspace3sb = space3sb * inversePerc;
                final finalspace4buttons = space4 * inversePerc;
                final finalspace5sb = space5sb * inversePerc;
                final finalpadding = 4.0 * inversePerc;
                final finalbr = (8.0 * inversePerc).multipliedRadius;
                final finalthumbnailsize = (space2 + Get.width * percentage).clamp(space2, Get.width - finalspace1sb - finalspace3sb);
                return GestureDetector(
                  /// prevent tap-to-dismiss while miniplayer is expanded.
                  onTap: percentage == 1 ? () {} : null,
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
                                      child: VideoController.inst.getVideoWidget(const Key('video_widget'), true),
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
                              width: (Get.width - (Get.width * percentage) - finalspace1sb - space2 - finalspace3sb - finalspace4buttons - finalspace5sb).clamp(0, Get.width),
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
                                    minicontroller.animateToHeight(height: 10);
                                    minioffset.value = 1.0;
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
                                              // shrinkWrap: true,
                                              // scrollDirection: Axis.horizontal,
                                              children: [
                                                const SizedBox(width: 18.0),
                                                SmallYTActionButton(
                                                  title: ytvideo == null
                                                      ? null
                                                      : (ytvideo.video.likeCount ?? 0) < 1
                                                          ? Language.inst.LIKE
                                                          : ytvideo.video.likeCount?.formatDecimalShort(isTitleExpanded.value) ?? '?',
                                                  icon: Broken.like_1,
                                                  onPressed: () {},
                                                ),
                                                const SizedBox(width: 18.0),
                                                SmallYTActionButton(
                                                  title: ytvideo == null
                                                      ? null
                                                      : (ytvideo.video.dislikeCount ?? 0) < 1
                                                          ? Language.inst.DISLIKE
                                                          : ytvideo.video.dislikeCount?.formatDecimalShort(isTitleExpanded.value) ?? '?',
                                                  icon: Broken.dislike,
                                                  onPressed: () {},
                                                ),
                                                const SizedBox(width: 18.0),
                                                SmallYTActionButton(
                                                  title: Language.inst.SHARE,
                                                  icon: Broken.share,
                                                  onPressed: () {
                                                    if (ytvideo != null) Share.share(ytvideo.video.url ?? '');
                                                  },
                                                ),
                                                const SizedBox(width: 18.0),
                                                SmallYTActionButton(
                                                  title: Language.inst.REFRESH,
                                                  icon: Broken.refresh,
                                                  onPressed: () async => await YoutubeController.inst.updateVideoDetails(currentId),
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
                                                        (ytvideo?.channel.subscriberCount ?? 0) < 2 ? Language.inst.SUBSCRIBER : Language.inst.SUBSCRIBERS
                                                      ].join(' '),
                                                      style: context.textTheme.displaySmall,
                                                    ),
                                                  ),
                                                ],
                                              ),
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
                                              } else {
                                                if (item is YoutubePlaylist) {
                                                  return Container(
                                                    margin: const EdgeInsets.all(8.0),
                                                    padding: const EdgeInsets.all(12.0),
                                                    decoration: BoxDecoration(
                                                      color: context.theme.cardColor,
                                                      border: Border.all(color: context.theme.cardTheme.color!),
                                                      borderRadius: BorderRadius.circular(12.0.multipliedRadius),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        YoutubeThumbnail(
                                                          channelUrl: item.thumbnailUrl,
                                                          width: context.width * 0.4,
                                                          height: context.width * 0.4 * 9 / 16,
                                                          borderRadius: 12.0,
                                                        ),
                                                        const SizedBox(width: 8.0),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Text(
                                                                item.playlistType?.convertToString ?? '',
                                                              ),
                                                              Text(
                                                                item.name ?? 'name',
                                                              ),
                                                              Text(
                                                                item.streamCount.toString(),
                                                              ),
                                                              Text(
                                                                item.description.toString(),
                                                              ),
                                                              Text(
                                                                item.uploaderName.toString(),
                                                              ),
                                                              Text(
                                                                (item.isUploaderVerified ?? false) ? 'Verified' : '',
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }
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
                                                  Language.inst.COMMENTS,
                                                  if (totalCommentsCount != null) totalCommentsCount.formatDecimalShort(),
                                                ].join(' • '),
                                                style: context.textTheme.displayLarge,
                                                textAlign: TextAlign.start,
                                              ),
                                              const Spacer(),
                                              NamidaIconButton(
                                                tooltip: YoutubeController.inst.isCurrentCommentsFromCache ? Language.inst.CACHE : null,
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
                                                                  Language.inst.PINNED,
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
                                                                    trimCollapsedText: Language.inst.SHOW_MORE,
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
                                                                      Language.inst.REPLIES,
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
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  ///TODO: view channel details.
  _showCommentMenu(BuildContext context, TapDownDetails details, YoutubeComment? comment) {
    Widget _getItem({
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
          child: _getItem(
            icon: Broken.copy,
            title: Language.inst.COPY,
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
  const SmallYTActionButton({
    super.key,
    required this.title,
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
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
          shimmerEnabled: title == null,
          child: Text(
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

  const YoutubeThumbnail({
    super.key,
    this.channelUrl,
    this.videoId,
    this.height,
    required this.width,
    this.borderRadius = 12.0,
    this.isCircle = false,
    this.margin,
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
    imagePath = res?.path;
    setState(() {});
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
        path: imagePath,
        height: widget.height,
        width: widget.width,
        thumbnailSize: widget.width,
        icon: widget.channelUrl != null ? Broken.user : Broken.video,
        iconSize: widget.channelUrl != null ? null : widget.width * 0.3,
        forceSquared: true,
      ),
    );
  }
}
