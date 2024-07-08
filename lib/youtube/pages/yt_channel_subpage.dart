import 'dart:io';

import 'package:flutter/material.dart';
import 'package:jiffy/jiffy.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:youtipie/class/channels/channel_page_result.dart';
import 'package:youtipie/class/execute_details.dart';
import 'package:youtipie/class/result_wrapper/list_wrapper_base.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/class/thumbnail.dart';
import 'package:youtipie/class/youtipie_feed/channel_info_item.dart';

import 'package:namida/base/pull_to_refresh.dart';
import 'package:namida/base/youtube_channel_controller.dart';
import 'package:namida/class/route.dart';
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
import 'package:youtipie/core/extensions.dart';

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

class _YTChannelSubpageState extends YoutubeChannelController<YTChannelSubpage> with TickerProviderStateMixin, PullToRefreshMixin {
  @override
  double get maxDistance => 64.0;

  late final YoutubeSubscription ch = YoutubeSubscriptionsController.inst.availableChannels.value[widget.channelID] ??
      YoutubeSubscription(
        channelID: widget.channelID.splitLast('/'),
        subscribed: false,
      );

  YoutiPieChannelPageResult? _channelInfo;
  YoutiPieFetchAllRes? _currentFetchAllRes;

  @override
  void initState() {
    super.initState();

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
          onRefresh(() => fetchChannelStreams(value, forceRequest: true), forceProceed: true);
        }
      },
    );
  }

  @override
  void dispose() {
    _currentFetchAllRes?.cancel();
    _currentFetchAllRes = null;
    super.dispose();
  }

  File? _getThumbFileForCache(String url, {required bool temp}) {
    return ThumbnailManager.inst.imageUrlToCacheFile(id: null, url: url, isTemp: temp);
  }

  void _onImageTap({
    required BuildContext context,
    required String channelID,
    required List<YoutiPieThumbnail> imagesList,
    required bool isPfp,
  }) {
    final files = <(String, File?)>[];
    imagesList.loop(
      (item) {
        File? cf = _getThumbFileForCache(item.url, temp: false);
        if (cf?.existsSync() == false) cf = _getThumbFileForCache(item.url, temp: true);
        files.add((item.url, cf));
      },
    );
    if (isPfp) {
      final cf = _getThumbFileForCache(channelID, temp: false);
      if (cf != null) files.add((channelID, cf));
    }
    if (files.isEmpty) return;

    int fileIndex = 0;

    final pageController = PageController(initialPage: fileIndex);

    NamidaNavigator.inst.navigateDialog(
      scale: 1.0,
      blackBg: true,
      dialog: LongPressDetector(
        onLongPress: () async {
          final file = files[fileIndex].$2;
          if (file == null) return;
          final saveDirPath = await EditDeleteController.inst.saveImageToStorage(file);
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
        child: PhotoViewGallery.builder(
          pageController: pageController,
          onPageChanged: (index) => fileIndex = index,
          gaplessPlayback: true,
          backgroundDecoration: const BoxDecoration(color: Colors.transparent),
          itemCount: files.length,
          builder: (context, index) {
            final fileWKey = files[index];
            final file = fileWKey.$2;
            return PhotoViewGalleryPageOptions(
              heroAttributes: PhotoViewHeroAttributes(tag: _getHeroTag(channelID, isPfp, fileWKey.$1)),
              tightMode: true,
              minScale: PhotoViewComputedScale.contained,
              filterQuality: FilterQuality.high,
              imageProvider: file != null ? FileImage(file) : NetworkImage(fileWKey.$1),
            );
          },
        ),
      ),
    );
  }

  String _getHeroTag(String channelID, bool isPfp, String? url) {
    return '${isPfp}_${channelID}_$url';
  }

  void _showSnack(YoutiPieFetchAllResType type) {
    String message;
    Color color;
    switch (type) {
      case YoutiPieFetchAllResType.success:
        message = lang.SUCCEEDED;
        color = Colors.green;
      case YoutiPieFetchAllResType.fail:
        message = lang.FAILED;
        color = Colors.red;
      case YoutiPieFetchAllResType.alreadyCanceled:
        message = lang.CANCELED;
        color = Colors.red;
      case YoutiPieFetchAllResType.alreadyDone:
        message = lang.DONE;
        color = Colors.green;
      case YoutiPieFetchAllResType.inProgress:
        message = lang.PROGRESS;
        color = Colors.orange;
    }
    snackyy(
      message: "${lang.FETCHING_OF_ALL_VIDEOS}: $message",
      borderColor: color.withOpacity(0.5),
    );
  }

  Future<void> _onLoadAllTap() async {
    if (_currentFetchAllRes != null) {
      _currentFetchAllRes?.cancel();
      _currentFetchAllRes = null;
    } else {
      final result = await fetchAllStreams((fetchAllRes) => _currentFetchAllRes = fetchAllRes);
      if (result != null) _showSnack(result);
    }
  }

  void _addNull<E>(List<E> list, E? item) {
    if (item != null) list.add(item);
  }

  @override
  Widget build(BuildContext context) {
    final channelInfo = _channelInfo;
    const thumbnailHeight = Dimensions.youtubeThumbnailHeight;
    const thumbnailWidth = Dimensions.youtubeThumbnailWidth;
    const thumbnailItemExtent = thumbnailHeight + 8.0 * 2;
    final channelID = channelInfo?.id ?? ch.channelID;

    final pfps = <YoutiPieThumbnail>[];
    final banners = <YoutiPieThumbnail>[];
    if (channelInfo != null) {
      _addNull(pfps, channelInfo.thumbnails.pick());
      _addNull(banners, channelInfo.banners.pick());
      _addNull(banners, channelInfo.tvbanners.pick());
      _addNull(banners, channelInfo.mobileBanners.pick());
    }

    final pfp = pfps.firstOrNull?.url ?? channelID; // channelID can be fetched from cache in some cases
    final banner = banners.firstOrNull;
    final bannerUrl = banner?.url;
    double bannerHeight;
    if (banner != null) {
      bannerHeight = banner.height / (banner.width / context.width);
    } else {
      bannerHeight = 69.0;
    }
    if (bannerHeight.isNaN || bannerHeight.isInfinite) bannerHeight = 69.0;

    final subsCount = channelInfo?.subscribersCount;
    final subsCountText = channelInfo?.subscribersCountText;
    final streamsCount = channelInfo?.videosCount;

    String videosCountVSTotalText = "${streamsList?.length ?? '?'} / ${streamsCount ?? '?'}";
    String? peakDatesText;
    if (streamsPeakDates != null) {
      videosCountVSTotalText += ' | ';
      peakDatesText = "${streamsPeakDates!.oldest.millisecondsSinceEpoch.dateFormattedOriginal} (${Jiffy.parseFromDateTime(streamsPeakDates!.oldest).fromNow()})";
    }
    final hasMoreStreamsLeft = channelVideoTab?.canFetchNext == true;
    return BackgroundWrapper(
      child: Listener(
        onPointerMove: (event) => onPointerMove(uploadsScrollController, event),
        onPointerUp: (_) => channelInfo == null ? null : onRefresh(() => fetchChannelStreams(channelInfo, forceRequest: true)),
        onPointerCancel: (_) => onVerticalDragFinish(),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Column(
              children: [
                Stack(
                  children: [
                    if (bannerUrl != null)
                      TapDetector(
                        onTap: () => _onImageTap(
                          context: context,
                          channelID: channelID,
                          imagesList: banners,
                          isPfp: false,
                        ),
                        child: NamidaHero(
                          tag: _getHeroTag(channelID, false, bannerUrl),
                          child: YoutubeThumbnail(
                            type: ThumbnailType.channel, // banner akshully
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
                      padding: (banners.isEmpty ? EdgeInsets.zero : EdgeInsets.only(top: bannerHeight * 0.95)),
                      child: Row(
                        children: [
                          const SizedBox(width: 12.0),
                          Transform.translate(
                            offset: banners.isEmpty ? const Offset(0, 0) : Offset(0, -bannerHeight * 0.1),
                            child: TapDetector(
                              onTap: () => _onImageTap(
                                context: context,
                                channelID: channelID,
                                imagesList: pfps,
                                isPfp: true,
                              ),
                              child: NamidaHero(
                                tag: _getHeroTag(channelID, true, pfp),
                                child: YoutubeThumbnail(
                                  type: ThumbnailType.channel,
                                  key: Key('${channelID}_$pfp'),
                                  width: context.width * 0.14,
                                  isImportantInCache: true,
                                  customUrl: pfp,
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
                                    channelInfo?.title ?? ch.title,
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
                    ObxO(
                      rx: isLoadingMoreUploads,
                      builder: (isLoadingMoreUploads) => NamidaInkWellButton(
                        animationDurationMS: 100,
                        sizeMultiplier: 0.95,
                        borderRadius: 8.0,
                        icon: Broken.task_square,
                        text: lang.LOAD_ALL,
                        enabled: !isLoadingMoreUploads && hasMoreStreamsLeft,
                        disableWhenLoading: false,
                        showLoadingWhenDisabled: hasMoreStreamsLeft,
                        onTap: _onLoadAllTap,
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
                                  videosCountVSTotalText,
                                  style: context.textTheme.displayMedium,
                                ),
                                if (peakDatesText != null)
                                  Text(
                                    peakDatesText,
                                    style: context.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w500),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4.0),
                    YTVideosActionBar(
                      title: channelInfo?.title ?? ch.title,
                      urlBuilder: channelInfo?.buildUrl,
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
                              padding: EdgeInsets.zero,
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
                            onReachingEnd: fetchStreamsNextPage,
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
            pullToRefreshWidget,
          ],
        ),
      ),
    );
  }
}
