import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:fade_shimmer/fade_shimmer.dart';
import 'package:get/get.dart';
import 'package:lazy_load_scrollview/lazy_load_scrollview.dart';
import 'package:miniplayer/miniplayer.dart';
import 'package:readmore/readmore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/youtube_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

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
    const miniplayerHeight = 12.0 + space2 * 9 / 16;

    return SafeArea(
      child: Obx(
        () => Transform.translate(
          offset: Offset(0.0, -64.0 * (1.0 - ScrollSearchController.inst.miniplayerHeightPercentage.value)),
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 2000),
            offset: Offset(0.0, minioffset.value),
            child: Miniplayer(
              onDismiss: () {},
              onDismissed: () {},
              controller: minicontroller,
              minHeight: miniplayerHeight,
              maxHeight: Get.height,
              builder: (height, percentage) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ScrollSearchController.inst.miniplayerHeightPercentage.value = percentage;
                });
                final currentTrack = Player.inst.nowPlayingTrack.value;
                final inversePerc = 1 - percentage;
                final finalspace1sb = space1sb * inversePerc;
                final finalspace3sb = space3sb * inversePerc;
                final finalspace4buttons = space4 * inversePerc;
                final finalspace5sb = space5sb * inversePerc;
                final finalpadding = 4.0 * inversePerc;
                final finalbr = 8.0 * inversePerc;
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
                                color: CurrentColor.inst.color.value,
                                borderRadius: BorderRadius.circular(finalbr),
                              ),
                              child: ArtworkWidget(
                                path: currentTrack.pathToImage,
                                thumnailSize: finalthumbnailsize,
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
                                      currentTrack.artistsList.take(4).join(', ').overflow,
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
                                child: InkWell(
                                  onTap: () => Player.inst.playOrPause(Player.inst.currentIndex.value, []),
                                  child: Obx(() => Icon(Player.inst.isPlaying.value ? Broken.pause : Broken.play)),
                                ),
                              ),
                            ),
                            Opacity(
                              opacity: inversePerc,
                              child: SizedBox(
                                width: finalspace4buttons / 2,
                                height: miniplayerHeight,
                                child: Material(
                                  child: InkWell(
                                    onTap: () {
                                      minicontroller.animateToHeight(height: 10);
                                      minioffset.value = 1.0;
                                    },
                                    child: const Icon(Broken.close_circle),
                                  ),
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
                            child: Obx(
                              () {
                                final ytvideo = YoutubeController.inst.currentYoutubeMetadata.value;
                                final comments = YoutubeController.inst.comments.value;
                                return AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: ytvideo == null
                                      ? const ShimmerScreen()
                                      : NotificationListener(
                                          // onNotification: (notification) {
                                          //   if (notification is ScrollEndNotification) {
                                          //     final before = notification.metrics.extentBefore;
                                          //     final max = notification.metrics.maxScrollExtent;

                                          //     if (max > context.height && before > (max - 300)) {
                                          //       YoutubeController.inst.updateCurrentComments(ytvideo.video, forceReload: true, loadNext: true);
                                          //     }
                                          //   }
                                          //   return false;
                                          // },
                                          child: LazyLoadScrollView(
                                            onEndOfPage: () => YoutubeController.inst.updateCurrentComments(ytvideo.video, forceReload: true, loadNext: true),
                                            scrollOffset: 300,
                                            child: ListView(
                                              physics: const ClampingScrollPhysics(),
                                              children: [
                                                SizedBox(height: 100.0 * inversePerc),
                                                ExpansionTile(
                                                  maintainState: true,
                                                  expandedAlignment: Alignment.centerLeft,
                                                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                                                  tilePadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                                                  textColor: Color.alphaBlend(CurrentColor.inst.color.value.withAlpha(40), context.theme.colorScheme.onBackground),
                                                  collapsedTextColor: context.theme.colorScheme.onBackground,
                                                  iconColor: Color.alphaBlend(CurrentColor.inst.color.value.withAlpha(40), context.theme.colorScheme.onBackground),
                                                  collapsedIconColor: context.theme.colorScheme.onBackground,
                                                  childrenPadding: const EdgeInsets.all(18.0),
                                                  onExpansionChanged: (value) => isTitleExpanded.value = value,
                                                  title: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        ytvideo.video.title,
                                                        maxLines: isTitleExpanded.value ? null : 2,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      const SizedBox(height: 4.0),
                                                      Obx(
                                                        () => Text(
                                                          [
                                                            ytvideo.video.engagement.viewCount.formatDecimal(isTitleExpanded.value),
                                                            ytvideo.video.uploadDate?.millisecondsSinceEpoch.dateFormatted,
                                                            if (ytvideo.video.uploadDate != null)
                                                              '(${timeago.format(ytvideo.video.uploadDate!, locale: 'en_short')} ${Language.inst.AGO})'
                                                          ].join(' • '),
                                                          style: context.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w500),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  children: [
                                                    NamidaSelectableAutoLinkText(text: ytvideo.video.description),
                                                  ],
                                                ),
                                                Container(
                                                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                                                  height: 60,
                                                  child: ListView(
                                                    shrinkWrap: true,
                                                    scrollDirection: Axis.horizontal,
                                                    children: [
                                                      const SizedBox(width: 12.0),
                                                      SmallYTActionButton(
                                                        title:
                                                            (ytvideo.video.engagement.likeCount ?? 0) < 1 ? Language.inst.LIKE : ytvideo.video.engagement.likeCount.formatDecimal(),
                                                        icon: Broken.like_1,
                                                        onPressed: () {},
                                                      ),
                                                      const SizedBox(width: 22.0),
                                                      SmallYTActionButton(
                                                        title: (ytvideo.video.engagement.dislikeCount ?? 0) < 1
                                                            ? Language.inst.DISLIKE
                                                            : ytvideo.video.engagement.dislikeCount.formatDecimal(),
                                                        icon: Broken.dislike,
                                                        onPressed: () {},
                                                      ),
                                                      const SizedBox(width: 22.0),
                                                      SmallYTActionButton(
                                                        title: Language.inst.SHARE,
                                                        icon: Broken.share,
                                                        onPressed: () => Share.share(ytvideo.video.url),
                                                      ),
                                                      const SizedBox(width: 12.0),
                                                      SmallYTActionButton(
                                                        title: Language.inst.REFRESH,
                                                        icon: Broken.refresh,
                                                        onPressed: () async =>
                                                            await YoutubeController.inst.updateCurrentVideoMetadata(Player.inst.nowPlayingTrack.value.youtubeID, forceReload: true),
                                                      ),
                                                      const SizedBox(width: 12.0),
                                                    ],
                                                  ),
                                                ),
                                                Row(
                                                  children: [
                                                    YoutubeThumbnail(
                                                      url: ytvideo.channel.logoUrl,
                                                      width: 48.0,
                                                      height: 48.0,
                                                      margin: const EdgeInsets.symmetric(horizontal: 12.0),
                                                      isCircle: true,
                                                    ),
                                                    // Text(ytvideo.channel.title),
                                                    // const Text(' • '),
                                                    // Text(
                                                    //   ytvideo.channel.subscribersCount.formatDecimal(),
                                                    //   style: context.textTheme.displaySmall,
                                                    // ),
                                                    Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(ytvideo.channel.title),
                                                        Text(
                                                          [
                                                            ytvideo.channel.subscribersCount.formatDecimal(),
                                                            (ytvideo.channel.subscribersCount ?? 0) < 2 ? Language.inst.SUBSCRIBER : Language.inst.SUBSCRIBERS
                                                          ].join(' '),
                                                          style: context.textTheme.displaySmall,
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12.0),

                                                /// Comments
                                                Padding(
                                                  padding: const EdgeInsets.all(12.0),
                                                  child: Text([Language.inst.COMMENT, comments?.totalLength.formatDecimal() ?? 0].join(' • ')),
                                                ),
                                                AnimatedSwitcher(
                                                  duration: const Duration(milliseconds: 300),
                                                  child: comments == null
                                                      ? const ShimmerScreen()
                                                      : Column(
                                                          children: comments.comments.asMap().entries.map((e) {
                                                            final commentChannel =
                                                                YoutubeController.inst.commentsChannels.firstWhereOrNull((element) => element.id == e.value.channelId);

                                                            return Container(
                                                              margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                                              padding: const EdgeInsets.all(10.0),
                                                              decoration: BoxDecoration(
                                                                color: Color.alphaBlend(context.theme.cardColor, context.theme.colorScheme.onBackground).withAlpha(180),
                                                                borderRadius: BorderRadius.circular(
                                                                  12.0.multipliedRadius,
                                                                ),
                                                              ),
                                                              child: SizedBox(
                                                                width: context.width,
                                                                child: Row(
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  children: [
                                                                    YoutubeThumbnail(
                                                                      url: commentChannel?.logoUrl ?? '',
                                                                      width: 42.0,
                                                                      isCircle: true,
                                                                      errorWidget: (context, url, error) => ArtworkWidget(
                                                                        thumnailSize: 42.0,
                                                                        forceDummyArtwork: true,
                                                                        borderRadius: 124.0.multipliedRadius,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(width: 10.0),
                                                                    Expanded(
                                                                      child: Column(
                                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                                        children: [
                                                                          Text(
                                                                            e.value.author,
                                                                            style: context.textTheme.displaySmall?.copyWith(
                                                                                fontWeight: FontWeight.w400, color: context.theme.colorScheme.onBackground.withAlpha(180)),
                                                                          ),
                                                                          const SizedBox(height: 2.0),
                                                                          ReadMoreText(
                                                                            e.value.text,
                                                                            trimLines: 5,
                                                                            colorClickableText: context.theme.colorScheme.primary.withAlpha(200),
                                                                            trimMode: TrimMode.Line,
                                                                            trimCollapsedText: Language.inst.SHOW_MORE,
                                                                            trimExpandedText: '',
                                                                            style: context.textTheme.displaySmall?.copyWith(
                                                                                fontWeight: FontWeight.w500, color: context.theme.colorScheme.onBackground.withAlpha(220)),
                                                                          ),
                                                                          const SizedBox(height: 8.0),
                                                                          Row(
                                                                            children: [
                                                                              const Icon(Broken.like_1, size: 16.0),
                                                                              const SizedBox(width: 4.0),
                                                                              Text(
                                                                                e.value.likeCount.formatDecimal(),
                                                                                style: context.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w300),
                                                                              ),
                                                                              const SizedBox(width: 12.0),
                                                                              const Icon(Broken.dislike, size: 16.0),
                                                                              const SizedBox(width: 16.0),
                                                                              SizedBox(
                                                                                height: 24.0,
                                                                                child: TextButton.icon(
                                                                                  style: TextButton.styleFrom(
                                                                                    visualDensity: VisualDensity.compact,
                                                                                    foregroundColor: context.theme.colorScheme.onBackground.withAlpha(200),
                                                                                  ),
                                                                                  onPressed: () {},
                                                                                  icon: const Icon(Broken.document, size: 16.0),
                                                                                  label: Text(
                                                                                    Language.inst.REPLIES,
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
                                                                      onTapDown: (details) => _showCommentMenu(context, details, e.value, commentChannel!),
                                                                    ),

                                                                    //  MoreIcon(
                                                                    //       onPressed: _showCommentMenu(e.value, commentChannel),
                                                                    //     ),
                                                                  ],
                                                                ),
                                                              ),
                                                            );
                                                          }).toList(),
                                                        ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                );
                              },
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

  _showCommentMenu(BuildContext context, TapDownDetails details, Comment comment, Channel commentChannel) {
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
          child: SmallListTile(
            icon: Broken.copy,
            title: Language.inst.COPY,
            padding: const EdgeInsets.symmetric(horizontal: 0.0),
            titleGap: 0,
          ),
          onTap: () => Clipboard.setData(ClipboardData(text: comment.text)),
        ),
        PopupMenuItem(
          child: SmallListTile(
            icon: Broken.ghost,
            title: Language.inst.GO_TO_CHANNEL,
            padding: const EdgeInsets.symmetric(horizontal: 0.0),
            titleGap: 0,
          ),
          onTap: () {},
        ),
      ],
    );
  }
}

class SmallYTActionButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final void Function()? onPressed;
  const SmallYTActionButton({super.key, required this.title, required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          child: InkWell(
            borderRadius: BorderRadius.circular(32.0.multipliedRadius),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(6.0),
              child: Icon(icon),
            ),
          ),
        ),
        const SizedBox(height: 4.0),
        Text(
          title,
          style: context.textTheme.displaySmall,
        ),
      ],
    );
  }
}

class YoutubeThumbnail extends StatelessWidget {
  final String url;
  final double? height;
  final double width;
  final double borderRadius;
  final bool isCircle;
  final EdgeInsetsGeometry? margin;
  final Widget Function(BuildContext context, String url, dynamic error)? errorWidget;
  final Widget Function(BuildContext context, String url, DownloadProgress progress)? progressIndicatorBuilder;
  const YoutubeThumbnail({
    super.key,
    required this.url,
    this.height,
    required this.width,
    this.borderRadius = 12.0,
    this.isCircle = false,
    this.margin,
    this.errorWidget,
    this.progressIndicatorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      margin: margin,
      decoration: BoxDecoration(
        color: context.theme.cardColor.withAlpha(100),
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle
            ? null
            : BorderRadius.circular(
                borderRadius.multipliedRadius,
              ),
      ),
      child: CachedNetworkImage(
        imageUrl: url,
        height: height,
        width: width,
        errorWidget: errorWidget,
        progressIndicatorBuilder: progressIndicatorBuilder ?? errorWidget,
        fit: BoxFit.cover,
      ),
    );
  }
}

class ShimmerScreen extends StatelessWidget {
  const ShimmerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children: const [
        ShimmerCard(index: 0),
        ShimmerCard(index: 1),
      ],
    );
  }
}

class ShimmerCard extends StatelessWidget {
  final int index;
  const ShimmerCard({super.key, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: context.theme.cardColor.withAlpha(100),
        borderRadius: BorderRadius.circular(
          12.0.multipliedRadius,
        ),
      ),
      child: Row(
        children: [
          FadeShimmer.round(
            size: 70,
            highlightColor: context.theme.colorScheme.onBackground.withAlpha(100),
            baseColor: context.theme.colorScheme.onBackground.withAlpha(10),
            millisecondsDelay: index * 200,
          ),
          const SizedBox(width: 14.0),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: context.theme.cardColor.withAlpha(100),
                  borderRadius: BorderRadius.circular(
                    12.0.multipliedRadius,
                  ),
                ),
                child: FadeShimmer(
                  width: context.width / 2,
                  height: 10,
                  highlightColor: context.theme.colorScheme.onBackground.withAlpha(100),
                  baseColor: context.theme.colorScheme.onBackground.withAlpha(10),
                  millisecondsDelay: index * 100,
                ),
              ),
              const SizedBox(height: 24.0),
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: context.theme.cardColor.withAlpha(100),
                  borderRadius: BorderRadius.circular(
                    12.0.multipliedRadius,
                  ),
                ),
                child: FadeShimmer(
                  width: context.width / 2,
                  height: 10,
                  highlightColor: context.theme.colorScheme.onBackground.withAlpha(100),
                  baseColor: context.theme.colorScheme.onBackground.withAlpha(10),
                  millisecondsDelay: index * 300,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
