import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/material.dart';
import 'package:jiffy/jiffy.dart';
import 'package:youtipie/class/execute_details.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/base/pull_to_refresh.dart';
import 'package:namida/base/youtube_channel_controller.dart';
import 'package:namida/class/route.dart';
import 'package:namida/controller/file_browser.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/animated_widgets.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/youtube/class/youtube_subscription.dart';
import 'package:namida/youtube/controller/youtube_import_controller.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/youtube_subscriptions_controller.dart';
import 'package:namida/youtube/pages/yt_channel_subpage.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:namida/youtube/widgets/yt_video_card.dart';

class YoutubeChannelsPage extends StatefulWidget {
  const YoutubeChannelsPage({super.key});

  @override
  State<YoutubeChannelsPage> createState() => _YoutubeChannelsPageState();
}

class _YoutubeChannelsPageState extends YoutubeChannelController<YoutubeChannelsPage> with TickerProviderStateMixin, PullToRefreshMixin {
  @override
  double get maxDistance => 64.0;

  @override
  List<StreamInfoItem>? get streamsList => _allStreamsList ?? channelVideoTab?.items;

  List<StreamInfoItem>? _allStreamsList;

  late final ScrollController _horizontalListController;

  final _allChannelsStreamsProgress = 0.0.obs;
  final _allChannelsStreamsLoading = false.obs;

  late final Rx<DateTime> allChannelFetchOldestDate;

  @override
  void initState() {
    super.initState();
    _horizontalListController = ScrollController();
    YoutubeSubscriptionsController.inst.sortByLastFetched();
    final subCh = YoutubeSubscriptionsController.inst.subscribedChannels.lastOrNull;
    if (subCh != null) {
      final sub = YoutubeSubscriptionsController.inst.availableChannels.value[subCh];
      onRefresh(() => _updateChannel(sub, forceRequest: true), forceProceed: true);
    }

    final now = DateTime.now();
    allChannelFetchOldestDate = DateTime(now.year, now.month, now.day - 32).obs;
  }

  @override
  void dispose() {
    _horizontalListController.dispose();
    _allChannelsStreamsProgress.close();
    _allChannelsStreamsLoading.close();
    super.dispose();
  }

  Future<void> _updateChannel(YoutubeSubscription? sub, {required bool forceRequest}) async {
    if (uploadsScrollController.hasClients) uploadsScrollController.jumpTo(0);
    setState(() {
      isLoadingInitialStreams = true;
      channel = sub;
      streamsPeakDates = null;
      _allStreamsList = null;
    });

    if (sub != null) {
      final channelInfo = await YoutubeInfoController.channel.fetchChannelInfo(
        channelId: sub.channelID,
        // details: forceRequest ? ExecuteDetails.forceRequest() : null, // -- info is not force requested
      );

      if (channelInfo != null && channel == sub) {
        return fetchChannelStreams(channelInfo, forceRequest: forceRequest);
      }
    } else {
      return _fetchAllChannelsStreams(forceRequest: forceRequest);
    }
  }

  /// TODO(youtipie): might be faster using rss feed, but limited to 15 vid.
  Future<void> _fetchAllChannelsStreams({required bool forceRequest}) async {
    setState(() {
      isLoadingInitialStreams = true;
      _allStreamsList = [];
    });
    _allChannelsStreamsLoading.value = true;

    final streams = <StreamInfoItem>[];
    final ids = YoutubeSubscriptionsController.inst.subscribedChannels.toList();
    final idsLength = ids.length;

    final maxDateBeforeMS = allChannelFetchOldestDate.value.millisecondsSinceEpoch;

    bool enoughStreams(List<StreamInfoItem> streams) {
      final lastDate = streams.lastOrNull?.publishedAt.date?.toLocal();
      if (lastDate == null || lastDate.millisecondsSinceEpoch < maxDateBeforeMS) {
        streams.removeWhere((element) {
          final date = element.publishedAt.date?.toLocal();
          return date != null && date.millisecondsSinceEpoch < maxDateBeforeMS;
        });
        return true;
      }
      return false;
    }

    void reportError(String msg) => snackyy(message: msg, isError: true, title: lang.ERROR);

    final executeDetails = forceRequest ? ExecuteDetails.forceRequest() : null;

    int pageFetchErrors = 0;
    for (int i = 0; i < idsLength; i++) {
      final channelID = ids[i];
      _allChannelsStreamsProgress.value = i / idsLength;
      final channelPage = await YoutubeInfoController.channel.fetchChannelInfo(channelId: channelID, details: null);
      if (channelPage == null) {
        if (pageFetchErrors < 3) {
          reportError('failed to fetch channel page for $channelID');
          continue;
        } else {
          reportError('failed to fetch channel pages 3 times in row, aborting.');
          break;
        }
      } else {
        pageFetchErrors = 0;
      }
      final videosTab = channelPage.tabs.getVideosTab();
      if (videosTab == null) {
        reportError('failed to fetch video tab for $channelID');
        continue;
      }
      final videosPage = await YoutubeInfoController.channel.fetchChannelTab(channelId: channelPage.id, tab: videosTab, details: executeDetails);
      if (videosPage == null) {
        reportError('failed to fetch initial videos for $channelID');
        continue;
      }
      while (!enoughStreams(videosPage.items)) {
        final didFetch = await videosPage.fetchNext();
        if (!didFetch) break;
      }
      printy('p: $i / $idsLength = ${_allChannelsStreamsProgress.value} =>> ${videosPage.length} videos');
      if (channel != null) {
        _allChannelsStreamsProgress.value = 0.0;
        _allChannelsStreamsLoading.value = false;
        return;
      }
      YoutubeSubscriptionsController.inst.refreshLastFetchedTime(channelID, saveToStorage: false);
      streams.addAll(videosPage.items);
    }
    YoutubeSubscriptionsController.inst.sortByLastFetched();
    _allChannelsStreamsProgress.value = 0.0;
    _allChannelsStreamsLoading.value = false;

    sortStreams(streams: streams);

    setState(() {
      isLoadingInitialStreams = false;
      _allStreamsList?.addAll(streams);
    });
  }

  Future<void> _onSubscriptionFileImportTap() async {
    final file = await NamidaFileBrowser.pickFile(
      note: 'Choose a "subscriptions.csv" file from a google takeout',
      allowedExtensions: ['csv', 'CSV'],
    );
    final fp = file?.path;
    if (fp != null) {
      final imported = await YoutubeImportController.inst.importSubscriptions(fp);
      if (imported > 0) {
        snackyy(message: lang.IMPORTED_N_CHANNELS_SUCCESSFULLY.replaceFirst('_NUM_', '$imported'));
      } else {
        snackyy(message: "${lang.CORRUPTED_FILE}\nPlease choose a valid subscriptions.csv file", isError: true);
      }
    }
  }

  static const _thumbSize = 48.0;
  double get _listBottomPadding => Dimensions.inst.globalBottomPaddingEffectiveR - 6.0;
  final _listTopPadding = 6.0;
  double get listHeight => _thumbSize + 12 * 2 + _listBottomPadding + _listTopPadding;

  @override
  Widget build(BuildContext context) {
    const horizontalPadding = 6.0;

    const thumbnailHeight = Dimensions.youtubeThumbnailHeight;
    const thumbnailWidth = Dimensions.youtubeThumbnailWidth;
    const thumbnailItemExtent = thumbnailHeight + 8.0 * 2;

    final ch = channel;
    final currentChannelInfo = ch == null ? null : YoutubeInfoController.channel.fetchChannelInfoSync(ch.channelID);
    final currentChannelThumbnail = currentChannelInfo?.thumbnails.pick()?.url;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: ch == null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(child: sortWidget),
                        NamidaIconButton(
                          icon: Broken.calendar,
                          onPressed: () {
                            showCalendarDialog(
                              title: lang.DATE,
                              buttonText: lang.CONFIRM,
                              useHistoryDates: false,
                              calendarType: CalendarDatePicker2Type.single,
                              lastDate: DateTime.now(),
                              onGenerate: (dates) {
                                if (dates.isNotEmpty) {
                                  allChannelFetchOldestDate.value = dates.first;
                                  _fetchAllChannelsStreams(forceRequest: true);
                                }
                                NamidaNavigator.inst.closeDialog();
                              },
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12.0),
                    Row(
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: context.theme.cardColor,
                            borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                            border: Border.all(
                              width: 1.2,
                              color: context.theme.colorScheme.secondary.withOpacity(0.6),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
                            child: Text(
                              streamsList?.length.displayVideoKeyword ?? '?',
                              style: context.textTheme.displayMedium,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4.0),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: context.theme.cardColor,
                            borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                            border: Border.all(
                              width: 1.2,
                              color: context.theme.colorScheme.secondary.withOpacity(0.6),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
                            child: Obx(
                              () {
                                final oldestDate = allChannelFetchOldestDate.valueR;
                                return Text(
                                  "${oldestDate.millisecondsSinceEpoch.dateFormattedOriginal} - ${Jiffy.parseFromDateTime(oldestDate).fromNow()}",
                                  style: context.textTheme.displayMedium,
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: NamidaInkWell(
                          borderRadius: 24.0,
                          bgColor: context.theme.cardColor,
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          onTap: YTChannelSubpage(channelID: ch.channelID, sub: ch).navigate,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 4.0),
                              YoutubeThumbnail(
                                type: ThumbnailType.channel,
                                key: Key(currentChannelThumbnail ?? ''),
                                width: 32.0,
                                isImportantInCache: true,
                                customUrl: currentChannelThumbnail,
                                urlSymLinkId: ch.channelID,
                                isCircle: true,
                              ),
                              const SizedBox(width: 8.0),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ch.title != '' ? ch.title : YoutubeInfoController.channel.fetchChannelInfoSync(ch.channelID)?.title ?? '',
                                    style: context.textTheme.displayMedium,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (ch.subscribed ?? false)
                                    Text(
                                      lang.SUBSCRIBED,
                                      style: context.textTheme.displaySmall?.copyWith(fontSize: 10.0),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                              const SizedBox(width: 8.0),
                              const SizedBox(width: 4.0),
                              const SizedBox(width: 4.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4.0),
                    Obx(
                      () => NamidaInkWellButton(
                        icon: Broken.add_circle,
                        text: lang.IMPORT,
                        enabled: !YoutubeImportController.inst.isImportingSubscriptions.valueR,
                        onTap: _onSubscriptionFileImportTap,
                      ),
                    ),
                  ],
                ),
        ),
        Expanded(
          child: YoutubeSubscriptionsController.inst.subscribedChannels.isEmpty
              ? Stack(
                  children: [
                    Center(
                      child: Obx(
                        () => NamidaInkWellButton(
                          sizeMultiplier: 2.0,
                          icon: Broken.add_circle,
                          text: lang.IMPORT,
                          enabled: !YoutubeImportController.inst.isImportingSubscriptions.valueR,
                          onTap: _onSubscriptionFileImportTap,
                        ),
                      ),
                    ),
                  ],
                )
              : NamidaScrollbar(
                  controller: uploadsScrollController,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      Listener(
                        onPointerMove: (event) => onPointerMove(uploadsScrollController, event),
                        onPointerUp: (_) => channel == null ? null : onRefresh(() => _updateChannel(channel!, forceRequest: true)),
                        onPointerCancel: (_) => onVerticalDragFinish(),
                        child: isLoadingInitialStreams
                            ? ShimmerWrapper(
                                shimmerEnabled: true,
                                child: ListView.builder(
                                  controller: uploadsScrollController,
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
                      pullToRefreshWidget,
                    ],
                  ),
                ),
        ),
        Obx(
          () => isLoadingMoreUploads.valueR
              ? const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      LoadingIndicator(),
                    ],
                  ),
                )
              : const SizedBox(),
        ),
        const NamidaContainerDivider(margin: EdgeInsets.only(left: 8.0, right: 8.0)),
        Obx(
          () => AnimatedSizedBox(
            duration: const Duration(milliseconds: 200),
            width: context.width,
            animateWidth: false,
            height: listHeight,
            child: Container(
              padding: EdgeInsets.only(bottom: _listBottomPadding, top: _listTopPadding),
              decoration: BoxDecoration(
                color: Color.alphaBlend(context.theme.scaffoldBackgroundColor.withOpacity(0.4), context.theme.cardTheme.color!),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(12.0.multipliedRadius),
                ),
              ),
              child: Obx(
                () {
                  final channelIDS = YoutubeSubscriptionsController.inst.subscribedChannels.toList();
                  final totalIDsLength = channelIDS.length;
                  return Row(
                    children: [
                      NamidaInkWell(
                        borderRadius: 10.0,
                        animationDurationMS: 150,
                        bgColor: channel == null ? context.theme.colorScheme.secondary.withOpacity(0.15) : null,
                        width: _thumbSize,
                        margin: const EdgeInsets.symmetric(horizontal: horizontalPadding),
                        padding: const EdgeInsets.symmetric(horizontal: horizontalPadding / 2),
                        onTap: () {
                          _updateChannel(null, forceRequest: true); // loading is indicated in the ui rather than a refresh indicator
                        },
                        child: Column(
                          children: [
                            const SizedBox(height: 4.0),
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: _thumbSize / 2,
                                  child: FittedBox(
                                    child: Text("$totalIDsLength"),
                                  ),
                                ),
                                Positioned.fill(
                                  child: FittedBox(
                                    child: Obx(
                                      () => CircularProgressIndicator(
                                        value: _allChannelsStreamsLoading.valueR && _allChannelsStreamsProgress.valueR <= 0 ? null : _allChannelsStreamsProgress.valueR,
                                        strokeWidth: 2.0,
                                      ),
                                    ),
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 4.0),
                            Text(
                              lang.ALL,
                              style: context.textTheme.displaySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          controller: _horizontalListController,
                          padding: EdgeInsets.only(right: Dimensions.inst.globalBottomPaddingFABR + 12.0),
                          scrollDirection: Axis.horizontal,
                          itemCount: totalIDsLength,
                          itemExtent: _thumbSize + horizontalPadding * 2,
                          itemBuilder: (context, indexPre) {
                            final index = totalIDsLength - indexPre - 1;
                            final key = channelIDS[index];
                            final ch = YoutubeSubscriptionsController.inst.availableChannels.valueR[key]!;
                            final info = YoutubeInfoController.channel.fetchChannelInfoSync(ch.channelID);
                            final channelTitle = info?.title;
                            final channelName = channelTitle == null || channelTitle == '' ? ch.title : channelTitle;
                            final channelThumbnail = info?.thumbnails.pick()?.url;
                            return NamidaInkWell(
                              borderRadius: 10.0,
                              animationDurationMS: 150,
                              bgColor: channel?.channelID == ch.channelID ? context.theme.colorScheme.secondary.withOpacity(0.1) : null,
                              width: _thumbSize,
                              padding: const EdgeInsets.symmetric(horizontal: horizontalPadding / 2),
                              margin: const EdgeInsets.symmetric(horizontal: horizontalPadding / 2),
                              onTap: () => _updateChannel(ch, forceRequest: false),
                              child: Column(
                                children: [
                                  const SizedBox(height: 4.0),
                                  YoutubeThumbnail(
                                    type: ThumbnailType.channel,
                                    key: Key(channelThumbnail ?? ''),
                                    width: _thumbSize,
                                    isImportantInCache: true,
                                    customUrl: channelThumbnail,
                                    urlSymLinkId: ch.channelID,
                                    isCircle: true,
                                  ),
                                  const SizedBox(height: 4.0),
                                  Text(
                                    channelName,
                                    style: context.textTheme.displaySmall,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
