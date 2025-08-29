part of 'yt_channel_subpage.dart';

class YTChannelVideosTab extends StatefulWidget {
  final YoutiPieChannelPageResult? channelInfo;
  final ScrollController scrollController;
  final YoutubeSubscription localChannel;

  const YTChannelVideosTab({
    super.key,
    required this.scrollController,
    required this.channelInfo,
    required this.localChannel,
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
  void initState() {
    channel = widget.localChannel;
    super.initState();
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
      borderColor: color.withValues(alpha: 0.5),
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
    final uploadsScrollController = widget.scrollController;
    const thumbnailHeight = Dimensions.youtubeThumbnailHeight;
    const thumbnailWidth = Dimensions.youtubeThumbnailWidth;
    const thumbnailItemExtent = thumbnailHeight + 8.0 * 2;

    final streamsList = this.streamsList;

    final channelInfo = widget.channelInfo;
    final streamsCount = channelInfo?.videosCount;

    String videosCountVSTotalText = "${streamsList?.length ?? '?'} / ${streamsCount?.formatDecimalShort() ?? '?'}";
    String? peakDatesText;
    if (streamsPeakDates != null) {
      videosCountVSTotalText += ' | ';
      peakDatesText = "${streamsPeakDates!.oldest.millisecondsSinceEpoch.dateFormattedOriginal} (${TimeAgoController.dateFromNow(streamsPeakDates!.oldest)})";
    }
    final hasMoreStreamsLeft = channelVideoTab?.canFetchNext == true;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8.0),
        Row(
          children: [
            const SizedBox(width: 4.0),
            Expanded(child: sortWidget),
            const SizedBox(width: 4.0),
            ObxO(
              rx: isLoadingMoreUploads,
              builder: (context, isLoadingMoreUploads) => NamidaInkWellButton(
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(width: 8.0),
            Expanded(
              child: FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: NamidaInkWell(
                  borderRadius: 6.0,
                  decoration: BoxDecoration(
                    border: Border.all(color: context.theme.colorScheme.secondary.withValues(alpha: 0.5)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 3.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Broken.video_square, size: 16.0),
                      const SizedBox(width: 4.0),
                      Flexible(
                        child: Text(
                          videosCountVSTotalText,
                          style: context.textTheme.displayMedium,
                        ),
                      ),
                      if (peakDatesText != null)
                        Flexible(
                          child: Text(
                            peakDatesText,
                            style: context.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4.0),
            Align(
              alignment: Alignment.centerRight,
              child: YTVideosActionBar(
                queueSource: QueueSourceYoutubeID.channelHosted,
                title: channelInfo?.title ?? widget.localChannel.title,
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
                playlistBasicInfo: () => PlaylistBasicInfo(
                  id: channelInfo?.id ?? '',
                  title: channelInfo?.title ?? '',
                  videosCountText: channelInfo?.videosCountText,
                  videosCount: channelInfo?.videosCount,
                  thumbnails: [],
                ),
              ),
            ),
            const SizedBox(width: 8.0),
          ],
        ),
        const SizedBox(height: 8.0),
        Expanded(
          child: VideoTilePropertiesProvider(
            configs: VideoTilePropertiesConfigs(
              queueSource: QueueSourceYoutubeID.channel,
              showMoreIcon: true,
            ),
            builder: (properties) => NamidaScrollbar(
              controller: uploadsScrollController,
              child: LazyLoadListView(
                scrollController: uploadsScrollController,
                onReachingEnd: fetchStreamsNextPage,
                listview: (controller) => CustomScrollView(
                  controller: controller,
                  slivers: [
                    isLoadingInitialStreams
                        ? SliverToBoxAdapter(
                            child: ShimmerWrapper(
                              shimmerEnabled: true,
                              child: SuperListView.builder(
                                shrinkWrap: true,
                                primary: false,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: EdgeInsets.only(bottom: Dimensions.inst.globalBottomPaddingTotalR),
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
                                child: Center(
                                  child: Text(
                                    lang.ERROR,
                                    style: context.textTheme.displayLarge,
                                  ),
                                ),
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
