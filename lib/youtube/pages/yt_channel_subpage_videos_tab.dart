part of 'yt_channel_subpage.dart';

class YTChannelVideosTab extends StatefulWidget {
  final YoutiPieChannelPageResult? channelInfo;
  final ScrollController scrollController;
  final YoutubeSubscription localChannel;
  final Future<void> Function(Future<void> Function() fetch) tabFetcher;
  final bool Function() shouldForceRequest;
  final void Function() onSuccessFetch;

  const YTChannelVideosTab({
    super.key,
    required this.scrollController,
    required this.channelInfo,
    required this.localChannel,
    required this.tabFetcher,
    required this.shouldForceRequest,
    required this.onSuccessFetch,
  });

  @override
  State<YTChannelVideosTab> createState() => _YTChannelVideosTabState();
}

class _YTChannelVideosTabState extends YoutubeChannelController<YTChannelVideosTab> {
  @override
  String? get channelID => widget.channelInfo?.id ?? widget.localChannel.channelID;

  @override
  ScrollController get scrollController => widget.scrollController;

  YoutiPieFetchAllRes? _currentFetchAllRes;

  @override
  Future<bool> fetchStreamsNextPage() async {
    final res = await super.fetchStreamsNextPage();
    if (res && mounted && listWrapper != null) setState(() => updatePeakDates(listWrapper!.items.cast()));
    return res;
  }

  @override
  void onSuccessFetch() {
    widget.onSuccessFetch();
  }

  @override
  void initState() {
    channel = widget.localChannel;
    super.initState();
    _fetchOnMount();
  }

  Future<void> _fetchOnMount() async {
    final channelInfo = widget.channelInfo;
    if (channelInfo == null) return;
    if (widget.shouldForceRequest()) {
      await widget.tabFetcher(() => fetchChannelStreams(channelInfo, forceRequest: true));
    } else {
      await cachedStreamsLoad;
      if (mounted && channelVideoTab == null) await fetchChannelStreams(channelInfo);
    }
  }

  @override
  void dispose() {
    _currentFetchAllRes?.cancel();
    _currentFetchAllRes = null;
    super.dispose();
  }

  void _showSnack(YoutiPieFetchAllResType type) {
    String message;
    Color color;
    switch (type) {
      case YoutiPieFetchAllResType.success:
        message = lang.succeeded;
        color = Colors.green;
      case YoutiPieFetchAllResType.fail:
        message = lang.failed;
        color = Colors.red;
      case YoutiPieFetchAllResType.alreadyCanceled:
        message = lang.canceled;
        color = Colors.red;
      case YoutiPieFetchAllResType.alreadyDone:
        message = lang.done;
        color = Colors.green;
      case YoutiPieFetchAllResType.inProgress:
        message = lang.progress;
        color = Colors.orange;
    }
    snackyy(
      message: "${lang.fetchingOfAllVideos}: $message",
      borderColor: color.withOpacityExt(0.5),
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

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final uploadsScrollController = widget.scrollController;
    const thumbnailHeight = Dimensions.youtubeThumbnailHeight;
    const thumbnailWidth = Dimensions.youtubeThumbnailWidth;
    const thumbnailItemExtent = thumbnailHeight + 8.0 * 2;

    final streamsList = this.sortedStreams;

    final channelInfo = widget.channelInfo;
    final streamsCount = channelInfo?.videosCount;

    String? peakDatesText;
    final peakDates = streamsPeakDates;
    if (peakDates != null) {
      final oldest = peakDates.oldest;
      peakDatesText = "${peakDates.oldestIsApproximate ? '~' : ''}${oldest.dateFormattedOriginal} (${TimeAgoController.dateFromNow(oldest)})";
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(child: sortWidget),
                    const SizedBox(width: 6.0),
                    Flexible(
                      child: ObxO(
                        rx: isLoadingMoreUploads,
                        builder: (context, isLoading) => YTLoadedCountChip(
                          loadedCount: streamsList?.length,
                          totalCount: streamsCount,
                          isLoading: isLoading,
                          canLoadMore: channelVideoTab?.canFetchNext == true,
                          onTap: _onLoadAllTap,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4.0),
              YTVideosActionBar(
                queueSource: QueueSourceYoutubeID.ytChannelHosted,
                title: channelInfo?.title ?? widget.localChannel.title,
                urlBuilder: channelInfo?.buildUrl,
                barOptions: const YTVideosActionBarOptions(
                  addToPlaylist: false,
                  playLast: false,
                ),
                videosCallback: () => streamsList
                    ?.map(
                      (e) => YoutubeID(
                        id: e.id,
                        playlistID: null,
                      ),
                    )
                    .toList(),
                infoLookupCallback: () {
                  final streamsList = this.sortedStreams;
                  if (streamsList == null) return null;
                  final m = <String, StreamInfoItem>{};
                  for (var e in streamsList) {
                    m[e.id] = e;
                  }
                  return m;
                },
                playlistBasicInfo: () => PlaylistBasicInfo(
                  id: channelInfo?.id ?? '',
                  title: channelInfo?.title ?? '',
                  videosCountText: channelInfo?.videosCountText,
                  videosCount: channelInfo?.videosCount,
                  thumbnails: [],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: VideoTilePropertiesProvider(
            configs: VideoTilePropertiesConfigs(
              queueSource: QueueSourceYoutubeID.ytChannel(channelID),
              showMoreIcon: true,
            ),
            builder: (properties) => NamidaScrollbar(
              controller: uploadsScrollController,
              child: LazyLoadListView(
                scrollController: uploadsScrollController,
                onReachingEnd: fetchStreamsNextPage,
                listview: (controller) => SmoothCustomScrollView(
                  controller: controller,
                  slivers: [
                    isLoadingInitialStreams
                        ? SliverToBoxAdapter(
                            child: ShimmerWrapper(
                              shimmerEnabled: true,
                              child: SuperSmoothListView.builder(
                                shrinkWrap: true,
                                primary: false,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: const EdgeInsets.only(bottom: Dimensions.globalBottomPaddingTotal),
                                itemCount: 10,
                                itemBuilder: (context, index) {
                                  return const YoutubeVideoCardDummy(
                                    shimmerEnabled: true,
                                    thumbnailHeight: thumbnailHeight,
                                    thumbnailWidth: thumbnailWidth,
                                    thumbnailWidthPercentage: 0.8,
                                  );
                                },
                              ),
                            ),
                          )
                        : streamsList == null
                        ? SliverToBoxAdapter(
                            // child: Center(
                            //   child: Text(
                            //     lang.error,
                            //     style: textTheme.displayLarge,
                            //   ),
                            // ),
                          )
                        : SliverFixedExtentList.builder(
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
                          ),
                    if (peakDatesText != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Broken.calendar_1,
                                size: 14.0,
                                color: textTheme.displaySmall?.color,
                              ),
                              const SizedBox(width: 4.0),
                              Flexible(
                                child: Text(
                                  peakDatesText,
                                  style: textTheme.displaySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: ObxO(
                        rx: isLoadingMoreUploads,
                        builder: (context, loading) => loading
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
                    ),
                    kBottomPaddingWidgetSliver,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
