import 'dart:io';

import 'package:flutter/material.dart';
import 'package:jiffy/jiffy.dart';
import 'package:photo_view/photo_view.dart';
import 'package:youtipie/class/channels/channel_page_result.dart';
import 'package:youtipie/class/execute_details.dart';
import 'package:youtipie/class/youtipie_feed/channel_info_item.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item.dart';

import 'package:namida/base/youtube_channel_controller.dart';
import 'package:namida/class/route.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/edit_delete_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/thumbnail_manager.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/class/youtube_subscription.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/youtube_subscriptions_controller.dart';
import 'package:namida/youtube/widgets/yt_subscribe_buttons.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:namida/youtube/widgets/yt_video_card.dart';
import 'package:namida/youtube/widgets/yt_videos_actions_bar.dart';

class YTChannelSubpage extends StatefulWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.YOUTUBE_CHANNEL_SUBPAGE;

  final String channelID;
  final YoutubeSubscription? sub;
  final ChannelInfoItem? channel;
  const YTChannelSubpage({super.key, required this.channelID, this.sub, this.channel});

  @override
  State<YTChannelSubpage> createState() => _YTChannelSubpageState();
}

class _YTChannelSubpageState extends YoutubeChannelController<YTChannelSubpage> {
  late final YoutubeSubscription ch = YoutubeSubscriptionsController.inst.availableChannels.value[widget.channelID] ??
      YoutubeSubscription(
        channelID: widget.channelID.splitLast('/'),
        subscribed: false,
      );

  YoutiPieChannelPageResult? _channelInfo;
  bool _canKeepLoadingMore = false;

  @override
  void initState() {
    channel = ch;

    final channelInfoCache = YoutubeInfoController.channel.fetchChannelInfoSync(ch.channelID);
    if (channelInfoCache != null) {
      _channelInfo = channelInfoCache;
      fetchChannelStreams(channelInfoCache);
    }

    // -- always get new info.
    YoutubeInfoController.channel.fetchChannelInfo(channelId: ch.channelID, details: ExecuteDetails.forceRequest()).then(
      (value) {
        if (value != null) {
          setState(() => _channelInfo = value);
          fetchChannelStreams(value);
        }
      },
    );

    super.initState();
  }

  void _onImageTap(BuildContext context, String channelID, String? imageUrl, bool isBanner) {
    // TODO(youtipie): a way to navigate through all banners?
    File? file;
    if (!isBanner) {
      file = ThumbnailManager.inst.imageUrlToCacheFile(id: null, url: channelID);
    }
    file ??= ThumbnailManager.inst.imageUrlToCacheFile(id: null, url: imageUrl);
    if (file == null) return;
    NamidaNavigator.inst.navigateDialog(
      scale: 1.0,
      blackBg: true,
      dialog: LongPressDetector(
        onLongPress: () async {
          final saveDirPath = await EditDeleteController.inst.saveImageToStorage(file!);
          String title = lang.COPIED_ARTWORK;
          String subtitle = '${lang.SAVED_IN} $saveDirPath';
          // ignore: use_build_context_synchronously
          Color snackColor = context.theme.colorScheme.surface;

          if (saveDirPath == null) {
            title = lang.ERROR;
            subtitle = lang.COULDNT_SAVE_IMAGE;
            snackColor = Colors.red;
          }
          snackyy(
            title: title,
            message: subtitle,
            leftBarIndicatorColor: snackColor,
            margin: EdgeInsets.zero,
            top: false,
            borderRadius: 0,
          );
        },
        child: PhotoView(
          heroAttributes: PhotoViewHeroAttributes(tag: '${isBanner}_${channelID}_$imageUrl'),
          gaplessPlayback: true,
          tightMode: true,
          minScale: PhotoViewComputedScale.contained,
          loadingBuilder: (context, event) => const SizedBox(),
          backgroundDecoration: const BoxDecoration(color: Colors.transparent),
          filterQuality: FilterQuality.high,
          imageProvider: FileImage(file),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const thumbnailHeight = Dimensions.youtubeThumbnailHeight;
    const thumbnailWidth = Dimensions.youtubeThumbnailWidth;
    const thumbnailItemExtent = thumbnailHeight + 8.0 * 2;
    final channelID = _channelInfo?.id ?? ch.channelID;
    final avatarUrl = _channelInfo?.thumbnails.firstOrNull?.url;
    final bannerUrl = (_channelInfo?.banners.firstOrNull ?? _channelInfo?.tvbanners.firstOrNull ?? _channelInfo?.mobileBanners.firstOrNull)?.url;
    final subsCount = _channelInfo?.subscribersCount;
    final subsCountText = _channelInfo?.subscribersCountText;
    final streamsCount = _channelInfo?.videosCount;
    const bannerHeight = 69.0;

    return BackgroundWrapper(
      child: Column(
        children: [
          Stack(
            children: [
              if (bannerUrl != null)
                TapDetector(
                  onTap: () => _onImageTap(context, channelID, bannerUrl, true),
                  child: NamidaHero(
                    tag: 'true_${channelID}_$bannerUrl',
                    child: YoutubeThumbnail(
                      key: Key('${channelID}_$bannerUrl'),
                      width: context.width,
                      compressed: false,
                      isImportantInCache: false,
                      customUrl: bannerUrl,
                      borderRadius: 0,
                      displayFallbackIcon: false,
                      height: bannerHeight,
                    ),
                  ),
                ),
              Padding(
                padding: (bannerUrl == null ? EdgeInsets.zero : const EdgeInsets.only(top: bannerHeight * 0.95)),
                child: Row(
                  children: [
                    const SizedBox(width: 12.0),
                    Transform.translate(
                      offset: bannerUrl == null ? const Offset(0, 0) : const Offset(0, -bannerHeight * 0.1),
                      child: TapDetector(
                        onTap: () => _onImageTap(context, channelID, avatarUrl, false),
                        child: NamidaHero(
                          tag: 'false_${channelID}_$avatarUrl',
                          child: YoutubeThumbnail(
                            key: Key('${channelID}_$avatarUrl'),
                            width: context.width * 0.14,
                            isImportantInCache: true,
                            customUrl: avatarUrl,
                            isCircle: true,
                            compressed: false,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 2.0),
                            child: Text(
                              _channelInfo?.title ?? ch.title,
                              style: context.textTheme.displayLarge,
                            ),
                          ),
                          const SizedBox(height: 4.0),
                          Text(
                            subsCountText ??
                                (subsCount == null
                                    ? '? ${lang.SUBSCRIBERS}'
                                    : [
                                        subsCount.formatDecimalShort(),
                                        subsCount < 2 ? lang.SUBSCRIBER : lang.SUBSCRIBERS,
                                      ].join(' ')),
                            style: context.textTheme.displayMedium?.copyWith(
                              fontSize: 12.0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4.0),
                    YTSubscribeButton(channelID: channelID),
                    const SizedBox(width: 12.0),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4.0),
          Row(
            children: [
              const SizedBox(width: 4.0),
              Expanded(child: sortWidget),
              const SizedBox(width: 4.0),
              Obx(
                () => NamidaInkWellButton(
                  animationDurationMS: 100,
                  sizeMultiplier: 0.95,
                  borderRadius: 8.0,
                  icon: Broken.task_square,
                  text: lang.LOAD_ALL,
                  enabled: !isLoadingMoreUploads.valueR && !lastLoadingMoreWasEmpty.valueR,
                  disableWhenLoading: false,
                  showLoadingWhenDisabled: !lastLoadingMoreWasEmpty.valueR,
                  onTap: () async {
                    _canKeepLoadingMore = !_canKeepLoadingMore;
                    while (_canKeepLoadingMore && !lastLoadingMoreWasEmpty.value && ConnectivityController.inst.hasConnection) {
                      await fetchStreamsNextPage();
                    }
                  },
                ),
              ),
              const SizedBox(width: 4.0),
            ],
          ),
          const SizedBox(height: 10.0),
          Row(
            children: [
              const SizedBox(width: 8.0),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 4.0,
                  children: [
                    NamidaInkWell(
                      borderRadius: 6.0,
                      decoration: BoxDecoration(
                        border: Border.all(color: context.theme.colorScheme.secondary.withOpacity(0.5)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 3.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Broken.video_square, size: 16.0),
                          const SizedBox(width: 4.0),
                          Text(
                            "${streamsList?.length ?? '?'} / ${streamsCount ?? '?'}",
                            style: context.textTheme.displayMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4.0),
                    if (streamsPeakDates != null)
                      NamidaInkWell(
                        borderRadius: 6.0,
                        decoration: BoxDecoration(
                          border: Border.all(color: context.theme.colorScheme.secondary.withOpacity(0.5)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                        child: Text(
                          "${streamsPeakDates!.oldest.millisecondsSinceEpoch.dateFormattedOriginal} (${Jiffy.parseFromDateTime(streamsPeakDates!.oldest).fromNow()})",
                          style: context.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 4.0),
              YTVideosActionBar(
                title: _channelInfo?.title ?? ch.title,
                urlBuilder: _channelInfo?.buildUrl,
                barOptions: const YTVideosActionBarOptions(
                  addToPlaylist: false,
                  playLast: false,
                ),
                videosCallback: () => streamsList
                    ?.map((e) => YoutubeID(
                          id: e.id,
                          playlistID: null,
                        ))
                    .toList(),
                infoLookupCallback: () {
                  final streamsList = this.streamsList;
                  if (streamsList == null) return null;
                  final m = <String, StreamInfoItem>{};
                  streamsList.loop((e) => m[e.id] = e);
                  return m;
                },
              ),
              const SizedBox(width: 8.0),
            ],
          ),
          const SizedBox(height: 8.0),
          Expanded(
            child: NamidaScrollbar(
              controller: uploadsScrollController,
              child: isLoadingInitialStreams
                  ? ShimmerWrapper(
                      shimmerEnabled: true,
                      child: ListView.builder(
                        itemCount: 15,
                        itemBuilder: (context, index) {
                          return const YoutubeVideoCardDummy(
                            shimmerEnabled: true,
                            thumbnailHeight: thumbnailHeight,
                            thumbnailWidth: thumbnailWidth,
                            thumbnailWidthPercentage: 0.8,
                          );
                        },
                      ),
                    )
                  : LazyLoadListView(
                      scrollController: uploadsScrollController,
                      onReachingEnd: () async {
                        await fetchStreamsNextPage();
                      },
                      listview: (controller) {
                        final streamsList = this.streamsList;
                        if (streamsList == null || streamsList.isEmpty) return const SizedBox();
                        return ListView.builder(
                          padding: EdgeInsets.only(bottom: Dimensions.inst.globalBottomPaddingTotalR),
                          controller: controller,
                          itemExtent: thumbnailItemExtent,
                          itemCount: streamsList.length,
                          itemBuilder: (context, index) {
                            final item = streamsList[index];
                            return YoutubeVideoCard(
                              key: Key(item.id),
                              thumbnailHeight: thumbnailHeight,
                              thumbnailWidth: thumbnailWidth,
                              isImageImportantInCache: false,
                              video: item,
                              playlistID: null,
                              thumbnailWidthPercentage: 0.8,
                              dateInsteadOfChannel: true,
                            );
                          },
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
