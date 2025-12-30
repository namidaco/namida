import 'dart:async';

import 'package:flutter/material.dart';

import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:youtipie/class/channels/channel_info.dart';
import 'package:youtipie/class/channels/channel_page_result.dart';
import 'package:youtipie/class/channels/channel_tab.dart';
import 'package:youtipie/class/channels/channel_tab_result.dart';
import 'package:youtipie/class/execute_details.dart';
import 'package:youtipie/class/result_wrapper/channel_user_result.dart';
import 'package:youtipie/class/result_wrapper/user_channels_all_videos_result.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/class/youtipie_feed/yt_feed_base.dart';
import 'package:youtipie/core/enum.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/base/pull_to_refresh.dart';
import 'package:namida/base/youtube_channel_controller.dart';
import 'package:namida/class/route.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/file_browser.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/time_ago_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/three_arched_circle.dart';
import 'package:namida/ui/widgets/animated_widgets.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/youtube/class/youtube_subscription.dart';
import 'package:namida/youtube/controller/youtube_account_controller.dart';
import 'package:namida/youtube/controller/youtube_import_controller.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/youtube_subscriptions_controller.dart';
import 'package:namida/youtube/pages/youtube_main_page_fetcher_acc_base.dart';
import 'package:namida/youtube/pages/youtube_user_channels_page.dart';
import 'package:namida/youtube/pages/yt_channel_subpage.dart';
import 'package:namida/youtube/widgets/yt_history_video_card.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:namida/youtube/widgets/yt_video_card.dart';

class YoutubeChannelsPage extends StatefulWidget {
  const YoutubeChannelsPage({super.key});

  @override
  State<YoutubeChannelsPage> createState() => _YoutubeChannelsPageState();
}

class _YoutubeChannelsPageState extends YoutubeChannelController<YoutubeChannelsPage> with TickerProviderStateMixin, PullToRefreshMixin {
  @override
  String? get channelID => channel?.channelID;

  @override
  ScrollController get scrollController => _uploadsScrollController;

  @override
  double get maxDistance => 64.0;

  @override
  List<StreamInfoItem>? get streamsList => _allStreamsList ?? channelVideoTab?.items.cast();

  List<StreamInfoItem>? _allStreamsList;

  late final ScrollController _uploadsScrollController;
  late final ScrollController _horizontalListController;

  final _allChannelsStreamsProgress = 0.0.obs;
  final _allChannelsStreamsLoading = false.obs;

  late final Rx<DateTime> allChannelFetchOldestDate;

  YoutiPieChannelPageResult? currentChannelInfo;

  @override
  void initState() {
    super.initState();

    _uploadsScrollController = ScrollController();
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
    _uploadsScrollController.dispose();
    _allChannelsStreamsProgress.close();
    _allChannelsStreamsLoading.close();
    super.dispose();
  }

  Future<void> _updateChannel(YoutubeSubscription? sub, {required bool forceRequest}) async {
    if (_uploadsScrollController.hasClients) _uploadsScrollController.jumpTo(0);
    setState(() {
      isLoadingInitialStreams = true;
      channel = sub;
      currentChannelInfo = null;
      streamsPeakDates = null;
      _allStreamsList = null;
    });

    if (sub != null) {
      _updateChannelInfoCache(sub.channelID);
      final channelInfo = await YoutubeInfoController.channel.fetchChannelInfo(
        channelId: sub.channelID,
        // details: forceRequest ? ExecuteDetails.forceRequest() : null, // -- info is not force requested
      );

      refreshState(() => currentChannelInfo = channelInfo);

      if (channelInfo != null && channel == sub) {
        return fetchChannelStreams(channelInfo, forceRequest: forceRequest);
      }
    } else {
      return _fetchAllChannelsStreams(forceRequest: forceRequest);
    }
  }

  void _updateChannelInfoCache(String channelID) async {
    final res = await YoutubeInfoController.channel.fetchChannelInfoCache(channelID);
    refreshState(() => currentChannelInfo = res);
  }

  bool get _hasConnection => ConnectivityController.inst.hasConnection;
  void _showNetworkError() {
    Timer(Duration.zero, () {
      snackyy(
        title: lang.ERROR,
        message: lang.NO_NETWORK_AVAILABLE_TO_FETCH_DATA,
        isError: true,
        top: false,
      );
    });
  }

  /// TODO(youtipie): might be faster using rss feed, but limited to 15 vid.
  Future<void> _fetchAllChannelsStreams({required bool forceRequest}) async {
    if (!_hasConnection) {
      _showNetworkError();
      return;
    }
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
        if (!_hasConnection) {
          await Future.delayed(const Duration(seconds: 7));
          if (!_hasConnection) {
            _showNetworkError();
            break;
          }
        }

        if (pageFetchErrors < 3) {
          pageFetchErrors++;
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
      while (!enoughStreams(videosPage.items.cast())) {
        final didFetch = await videosPage.fetchNext();
        if (!didFetch) break;
      }
      printy('p: $i / $idsLength = ${_allChannelsStreamsProgress.value} =>> ${videosPage.length} videos');
      if (channel != null) {
        break;
      }
      YoutubeSubscriptionsController.inst.refreshLastFetchedTime(channelID, saveToStorage: false);
      streams.addAll(videosPage.items.cast());
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
      allowedExtensions: NamidaFileExtensionsWrapper.csv,
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

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    const horizontalPadding = 6.0;

    const thumbnailHeight = Dimensions.youtubeThumbnailHeight;
    const thumbnailWidth = Dimensions.youtubeThumbnailWidth;
    const thumbnailItemExtent = thumbnailHeight + 8.0 * 2;

    final selectedChannel = channel;
    final currentChannelThumbnail = currentChannelInfo?.thumbnails.pick()?.url;

    final selectedChannelBgColor = theme.colorScheme.secondary.withValues(alpha: 0.1);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: selectedChannel == null
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
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                            border: Border.all(
                              width: 1.2,
                              color: theme.colorScheme.secondary.withValues(alpha: 0.6),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
                            child: Text(
                              streamsList?.length.displayVideoKeyword ?? '?',
                              style: textTheme.displayMedium,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4.0),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                            border: Border.all(
                              width: 1.2,
                              color: theme.colorScheme.secondary.withValues(alpha: 0.6),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
                            child: Obx(
                              (context) {
                                final oldestDate = allChannelFetchOldestDate.valueR;
                                return Text(
                                  "${oldestDate.millisecondsSinceEpoch.dateFormattedOriginal} - ${TimeAgoController.dateFromNow(oldestDate)}",
                                  style: textTheme.displayMedium,
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
                      child: SmoothSingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: NamidaInkWell(
                          borderRadius: 24.0,
                          bgColor: theme.cardColor,
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          onTap: YTChannelSubpage(channelID: selectedChannel.channelID, sub: selectedChannel).navigate,
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
                                urlSymLinkId: selectedChannel.channelID,
                                isCircle: true,
                              ),
                              const SizedBox(width: 8.0),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedChannel.title != '' ? selectedChannel.title : currentChannelInfo?.title ?? '',
                                    style: textTheme.displayMedium,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (selectedChannel.subscribed ?? false)
                                    Text(
                                      lang.SUBSCRIBED,
                                      style: textTheme.displaySmall?.copyWith(fontSize: 10.0),
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
                      (context) => NamidaInkWellButton(
                        icon: Broken.import_2,
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
                        (context) => NamidaInkWellButton(
                          sizeMultiplier: 2.0,
                          icon: Broken.import_2,
                          text: lang.IMPORT,
                          enabled: !YoutubeImportController.inst.isImportingSubscriptions.valueR,
                          onTap: _onSubscriptionFileImportTap,
                        ),
                      ),
                    ),
                  ],
                )
              : NamidaScrollbar(
                  controller: _uploadsScrollController,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      Listener(
                        onPointerMove: (event) => onPointerMove(_uploadsScrollController, event),
                        onPointerUp: (_) => channel == null ? null : onRefresh(() => _updateChannel(channel!, forceRequest: true)),
                        onPointerCancel: (_) => onVerticalDragFinish(),
                        child: isLoadingInitialStreams
                            ? ShimmerWrapper(
                                shimmerEnabled: true,
                                child: SuperSmoothListView.builder(
                                  controller: _uploadsScrollController,
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
                            : VideoTilePropertiesProvider(
                                configs: VideoTilePropertiesConfigs(
                                  queueSource: QueueSourceYoutubeID.channel,
                                  showMoreIcon: true,
                                ),
                                builder: (properties) => LazyLoadListView(
                                  scrollController: _uploadsScrollController,
                                  onReachingEnd: fetchStreamsNextPage,
                                  listview: (controller) {
                                    final streamsList = this.streamsList;
                                    if (streamsList == null || streamsList.isEmpty) return const SizedBox();
                                    return SuperSmoothListView.builder(
                                      controller: controller,
                                      itemExtent: thumbnailItemExtent,
                                      itemCount: streamsList.length,
                                      itemBuilder: (context, index) {
                                        final item = streamsList[index];
                                        return YoutubeVideoCard(
                                          properties: properties,
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
                      pullToRefreshWidget,
                    ],
                  ),
                ),
        ),
        Obx(
          (context) => isLoadingMoreUploads.valueR
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
          (context) {
            final channelIDS = YoutubeSubscriptionsController.inst.subscribedChannels.toList();
            final totalIDsLength = channelIDS.length;
            return _ChannelsRowSlider<String>(
              controller: _horizontalListController,
              horizontalPadding: horizontalPadding,
              isAllSelected: channel == null,
              onAllTap: () {
                _updateChannel(null, forceRequest: true); // loading is indicated in the ui rather than a refresh indicator
              },
              loadingAllProgressWidget: Obx(
                (context) => CircularProgressIndicator(
                  value: _allChannelsStreamsLoading.valueR && _allChannelsStreamsProgress.valueR <= 0 ? null : _allChannelsStreamsProgress.valueR,
                  strokeWidth: 2.0,
                ),
              ),
              list: channelIDS,
              listItemBuilder: (context, indexPre, thumbSize) {
                final index = totalIDsLength - indexPre - 1;
                final key = channelIDS[index];
                final sub = YoutubeSubscriptionsController.inst.availableChannels.valueR[key]!;
                return _ChannelSmallCard(
                  sub: sub,
                  bgColor: channel?.channelID == sub.channelID ? selectedChannelBgColor : null,
                  width: thumbSize,
                  horizontalPadding: horizontalPadding,
                  onTap: () => _updateChannel(sub, forceRequest: false),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class YoutubeChannelsHostedPage extends StatefulWidget {
  const YoutubeChannelsHostedPage({super.key});

  @override
  State<YoutubeChannelsHostedPage> createState() => _YoutubeChannelsHostedPageState();
}

class _YoutubeChannelsHostedPageState extends State<YoutubeChannelsHostedPage> with TickerProviderStateMixin, PullToRefreshMixin {
  YoutiPieChannelInfo? _currentChannelInfo;
  YoutiPieUserChannelsResult? _userChannelsResult;

  void _onViewAllTap() {
    const YoutubeUserChannelsPage().navigate();
  }

  void _updateChannel(YoutiPieChannelInfo? channel, {bool forceRequest = false}) {
    if (channel != _currentChannelInfo) {
      setState(() {
        _currentChannelInfo = channel;
      });
    }
  }

  @override
  void initState() {
    _initValues();

    YoutubeAccountController.current.addOnAccountChanged(_onAccChanged);
    super.initState();
  }

  @override
  void dispose() {
    YoutubeAccountController.current.removeOnAccountChanged(_onAccChanged);
    super.dispose();
  }

  void _onAccChanged() {
    if (!mounted) return;
    setState(() {
      _userChannelsResult = null;
      _currentChannelInfo = null;
    });
    _initValues();
  }

  Future<void> _initValues() async {
    final cache = YoutiPie.cacheBuilder.forUserChannels();
    final userChannelsResultCache = await cache.read();
    if (!mounted) return;

    setState(() {
      _userChannelsResult = userChannelsResultCache;
    });

    await _fetchNewInfo(); // always fetch new
  }

  Future<void> _fetchNewInfo() async {
    final userChannelsResult = await YoutubeInfoController.userchannel.fetchUserChannels(details: ExecuteDetails.forceRequest());
    if (!mounted) return;
    setState(() {
      _userChannelsResult = userChannelsResult;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    const horizontalPadding = 6.0;

    final currentChannelInfo = _currentChannelInfo;
    final currentChannelThumbnail = currentChannelInfo?.thumbnails.pick()?.url;

    final selectedChannelBgColor = theme.colorScheme.secondary.withValues(alpha: 0.1);

    final userChannelsResult = _userChannelsResult;
    final userChannels = userChannelsResult?.items ?? List<YoutiPieChannelInfo?>.filled(10, null);

    return Column(
      children: [
        currentChannelInfo == null
            ? const SizedBox()
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: SmoothSingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: NamidaInkWell(
                          borderRadius: 24.0,
                          bgColor: theme.cardColor,
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          onTap: YTChannelSubpage(channelID: currentChannelInfo.id).navigate,
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
                                urlSymLinkId: currentChannelInfo.id,
                                isCircle: true,
                              ),
                              const SizedBox(width: 8.0),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentChannelInfo.title ?? '',
                                    style: textTheme.displayMedium,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (currentChannelInfo.subscribed ?? false)
                                    Text(
                                      lang.SUBSCRIBED,
                                      style: textTheme.displaySmall?.copyWith(fontSize: 10.0),
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
                    NamidaInkWellButton(
                      icon: Broken.category,
                      text: lang.VIEW_ALL,
                      onTap: _onViewAllTap,
                    ),
                  ],
                ),
              ),
        Expanded(
          child: _YoutubeChannelVideosPage(
            key: ValueKey(currentChannelInfo?.id), // -- vip
            channelId: currentChannelInfo?.id,
          ),
        ),
        const NamidaContainerDivider(margin: EdgeInsets.only(left: 8.0, right: 8.0)),
        _ChannelsRowSlider(
          horizontalPadding: horizontalPadding,
          isAllSelected: currentChannelInfo == null,
          onAllTap: () => _updateChannel(null, forceRequest: true),
          list: userChannels,
          listItemBuilder: (context, index, thumbSize) {
            final channel = userChannels[index];
            final channelName = channel?.title;
            final channelThumbnail = channel?.thumbnails.pick()?.url;
            return NamidaInkWell(
              borderRadius: 10.0,
              animationDurationMS: 150,
              bgColor: channel != null && currentChannelInfo?.id == channel.id ? selectedChannelBgColor : null,
              width: thumbSize,
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding / 2),
              margin: EdgeInsets.symmetric(horizontal: horizontalPadding / 2),
              onTap: () => _updateChannel(channel, forceRequest: false),
              child: Column(
                children: [
                  const SizedBox(height: 4.0),
                  YoutubeThumbnail(
                    type: ThumbnailType.channel,
                    key: Key(channelThumbnail ?? ''),
                    width: thumbSize,
                    isImportantInCache: true,
                    customUrl: channelThumbnail,
                    urlSymLinkId: channel?.id,
                    isCircle: true,
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    channelName ?? '',
                    style: textTheme.displaySmall,
                    overflow: TextOverflow.ellipsis,
                  )
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _YoutubeChannelVideosPage extends StatefulWidget {
  final String? channelId;
  const _YoutubeChannelVideosPage({super.key, this.channelId});

  @override
  State<_YoutubeChannelVideosPage> createState() => __YoutubeChannelVideosPageState();
}

class __YoutubeChannelVideosPageState extends State<_YoutubeChannelVideosPage> {
  bool _isLoadingChannelPage = true;
  ChannelTab? _videosTab;

  @override
  void initState() {
    _initValues().whenComplete(() => refreshState(() => _isLoadingChannelPage = false));
    super.initState();
  }

  Future<void> _initValues() async {
    final channelId = widget.channelId;
    if (channelId == null || channelId.isEmpty) return;

    final channelPageCache = await YoutubeInfoController.channel.fetchChannelInfoCache(channelId);
    if (!mounted) return;

    setState(() {
      _videosTab = channelPageCache?.tabs.getVideosTab();
    });

    if (_videosTab != null) return;

    await _fetchNewInfo(channelId);
  }

  Future<void> _fetchNewInfo(String channelId) async {
    final channelPage = await YoutubeInfoController.channel.fetchChannelInfo(channelId: channelId);
    if (!mounted) return;

    setState(() {
      _videosTab = channelPage?.tabs.getVideosTab();
    });
  }

  void _onViewAllTap() {
    const YoutubeUserChannelsPage().navigate();
  }

  @override
  Widget build(BuildContext context) {
    const thumbnailHeight = Dimensions.youtubeThumbnailHeight;
    const thumbnailWidth = Dimensions.youtubeThumbnailWidth;
    const thumbnailItemExtent = thumbnailHeight + 8.0 * 2;

    if (_isLoadingChannelPage) {
      return Center(
        child: ThreeArchedCircle(
          size: 48.0,
          color: context.theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      );
    }

    final channelId = widget.channelId;
    final tab = _videosTab;
    if (channelId == null) {
      return VideoTilePropertiesProvider(
        configs: VideoTilePropertiesConfigs(
          queueSource: QueueSourceYoutubeID.channel,
          showMoreIcon: true,
        ),
        builder: (properties) => YoutubeMainPageFetcherAccBase<YoutiPieUserChannelsAllVideosResult, YoutubeFeed>(
          operation: YoutiPieOperation.fetchChannelTab,
          transparentShimmer: true,
          topPadding: 0.0,
          title: lang.CHANNELS,
          isSortable: true,
          cacheReader: YoutiPie.cacheBuilder.forUserChannelsAllVideos(),
          networkFetcher: (details) => YoutubeInfoController.userchannel.fetchUserChannelsAllVideos(details: details),
          itemExtent: thumbnailItemExtent,
          dummyCard: const YoutubeVideoCardDummy(
            shimmerEnabled: true,
            thumbnailHeight: thumbnailHeight,
            thumbnailWidth: thumbnailWidth,
            thumbnailWidthPercentage: 0.8,
          ),
          itemBuilder: (video, index, list) {
            if (video is! StreamInfoItem) return const SizedBox();
            return YoutubeVideoCard(
              properties: properties,
              key: Key(video.id),
              thumbnailHeight: thumbnailHeight,
              thumbnailWidth: thumbnailWidth,
              isImageImportantInCache: false,
              video: video,
              playlistID: null,
              thumbnailWidthPercentage: 0.8,
              dateInsteadOfChannel: false,
            );
          },
        ),
      );
    } else {
      return tab == null
          ? const SizedBox()
          : VideoTilePropertiesProvider(
              configs: VideoTilePropertiesConfigs(
                queueSource: QueueSourceYoutubeID.channel,
                showMoreIcon: true,
              ),
              builder: (properties) => YoutubeMainPageFetcherAccBase<YoutiPieChannelTabResult, YoutubeFeed>(
                operation: YoutiPieOperation.fetchChannelTab,
                fetchTimeMapKey: ValueKey(channelId),
                transparentShimmer: true,
                topPadding: 0.0,
                title: lang.CHANNEL,
                headerTrailing: NamidaInkWellButton(
                  icon: Broken.category,
                  text: lang.VIEW_ALL,
                  onTap: _onViewAllTap,
                ),
                headerBuilder: (_) => const SizedBox(),
                headerPadding: EdgeInsets.zero,
                isSortable: true,
                cacheReader: YoutiPie.cacheBuilder.forChannelTab(channelId: channelId, tab: tab),
                networkFetcher: (details) => YoutubeInfoController.channel.fetchChannelTab(channelId: channelId, tab: tab, details: details),
                itemExtent: thumbnailItemExtent,
                dummyCard: const YoutubeVideoCardDummy(
                  shimmerEnabled: true,
                  thumbnailHeight: thumbnailHeight,
                  thumbnailWidth: thumbnailWidth,
                  thumbnailWidthPercentage: 0.8,
                ),
                itemBuilder: (video, index, list) {
                  if (video is! StreamInfoItem) return const SizedBox();
                  return YoutubeVideoCard(
                    properties: properties,
                    key: Key(video.id),
                    thumbnailHeight: thumbnailHeight,
                    thumbnailWidth: thumbnailWidth,
                    isImageImportantInCache: false,
                    video: video,
                    playlistID: null,
                    thumbnailWidthPercentage: 0.8,
                    dateInsteadOfChannel: true,
                  );
                },
              ),
            );
    }
  }
}

class _ChannelsRowSlider<T> extends StatelessWidget {
  final ScrollController? controller;
  final double horizontalPadding;
  final bool isAllSelected;
  final void Function() onAllTap;
  final Widget? loadingAllProgressWidget;
  final List<T> list;
  final Widget? Function(BuildContext context, int index, double thumbSize) listItemBuilder;

  const _ChannelsRowSlider({
    this.controller,
    required this.horizontalPadding,
    required this.isAllSelected,
    required this.onAllTap,
    this.loadingAllProgressWidget,
    required this.list,
    required this.listItemBuilder,
  });

  static const _thumbSize = 48.0;
  double get _listBottomPadding => Dimensions.inst.globalBottomPaddingEffectiveR - 6.0;
  final _listTopPadding = 6.0;
  double get listHeight => _thumbSize + 12 * 2 + _listBottomPadding + _listTopPadding;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    return AnimatedSizedBox(
      duration: const Duration(milliseconds: 200),
      width: context.width,
      animateWidth: false,
      height: listHeight,
      child: Container(
        padding: EdgeInsets.only(bottom: _listBottomPadding, top: _listTopPadding),
        decoration: BoxDecoration(
          color: Color.alphaBlend(theme.scaffoldBackgroundColor.withValues(alpha: 0.4), theme.cardTheme.color!),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(12.0.multipliedRadius),
          ),
        ),
        child: Row(
          children: [
            NamidaInkWell(
              borderRadius: 10.0,
              animationDurationMS: 150,
              bgColor: isAllSelected ? theme.colorScheme.secondary.withValues(alpha: 0.15) : null,
              width: _thumbSize,
              margin: EdgeInsets.symmetric(horizontal: horizontalPadding),
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding / 2),
              onTap: onAllTap,
              child: Column(
                children: [
                  const SizedBox(height: 4.0),
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: _thumbSize / 2,
                        child: FittedBox(
                          child: Text("${list.isEmpty || list[0] == null ? '' : list.length}"),
                        ),
                      ),
                      if (loadingAllProgressWidget != null)
                        Positioned.fill(
                          child: FittedBox(
                            child: loadingAllProgressWidget,
                          ),
                        )
                    ],
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    lang.ALL,
                    style: textTheme.displaySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SuperSmoothListView.builder(
                controller: controller,
                padding: EdgeInsets.only(right: kFABSize + 12.0),
                scrollDirection: Axis.horizontal,
                itemCount: list.length,
                itemExtent: _thumbSize + horizontalPadding * 2,
                itemBuilder: (context, i) => listItemBuilder(context, i, _thumbSize),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelSmallCard extends StatefulWidget {
  final YoutubeSubscription sub;
  final Color? bgColor;
  final double width;
  final double horizontalPadding;
  final void Function() onTap;

  const _ChannelSmallCard({
    required this.sub,
    this.bgColor,
    required this.width,
    required this.horizontalPadding,
    required this.onTap,
  });

  @override
  State<_ChannelSmallCard> createState() => __ChannelSmallCardState();
}

class __ChannelSmallCardState extends State<_ChannelSmallCard> {
  YoutiPieChannelPageResult? _channelInfo;

  @override
  void initState() {
    _initValues();
    super.initState();
  }

  void _initValues() async {
    final res = await YoutubeInfoController.channel.fetchChannelInfoCache(widget.sub.channelID);
    refreshState(() => _channelInfo = res);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final ch = widget.sub;
    final info = _channelInfo;
    final channelTitle = info?.title;
    final channelName = channelTitle == null || channelTitle == '' ? ch.title : channelTitle;
    final channelThumbnail = info?.thumbnails.pick()?.url;
    return NamidaInkWell(
      borderRadius: 10.0,
      animationDurationMS: 150,
      bgColor: widget.bgColor,
      width: widget.width,
      padding: EdgeInsets.symmetric(horizontal: widget.horizontalPadding / 2),
      margin: EdgeInsets.symmetric(horizontal: widget.horizontalPadding / 2),
      onTap: widget.onTap,
      child: Column(
        children: [
          const SizedBox(height: 4.0),
          YoutubeThumbnail(
            type: ThumbnailType.channel,
            key: Key(channelThumbnail ?? ''),
            width: widget.width,
            isImportantInCache: true,
            customUrl: channelThumbnail,
            urlSymLinkId: ch.channelID,
            isCircle: true,
          ),
          const SizedBox(height: 4.0),
          Text(
            channelName,
            style: textTheme.displaySmall,
            overflow: TextOverflow.ellipsis,
          )
        ],
      ),
    );
  }
}
