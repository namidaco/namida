part of 'yt_channel_subpage.dart';

class YTChannelSubpageTab extends StatefulWidget {
  final ScrollController scrollController;
  final String channelId;
  final ChannelTab tab;
  final Future<void> Function(Future<YoutiPieChannelTabResult?> Function({YoutiPieItemsSort? sort, bool forceRequest}) fetch) tabFetcher;
  final bool Function() shouldForceRequest;
  final void Function() onSuccessFetch;

  const YTChannelSubpageTab({
    super.key,
    required this.scrollController,
    required this.channelId,
    required this.tab,
    required this.tabFetcher,
    required this.onSuccessFetch,
    required this.shouldForceRequest,
  });

  @override
  State<YTChannelSubpageTab> createState() => _YTChannelSubpageTabState();
}

class _YTChannelSubpageTabState extends State<YTChannelSubpageTab> {
  YoutiPieChannelTabResult? _tabResult;
  YoutiPieItemsSort? _currentSort;
  bool _isLoadingInitial = false;
  final _isLoadingMoreItems = false.obs;

  Completer<void>? _initCompleter = Completer<void>();

  Future<YoutiPieChannelTabResult?> fetchTabAndUpdate({YoutiPieItemsSort? sort, bool? forceRequest}) async {
    if (_initCompleter != null) {
      await _initCompleter?.future;
    }

    sort ??= _currentSort; // use set sort when refreshing.
    forceRequest ??= widget.shouldForceRequest();

    if (forceRequest == false && _tabResult != null) return null; // prevent calling widget.onSuccessFetch

    final tabResult = await YoutubeInfoController.channel.fetchChannelTab(
      channelId: widget.channelId,
      tab: widget.tab,
      sort: sort,
      details: forceRequest ? ExecuteDetails.forceRequest() : null,
    );

    if (tabResult != null) widget.onSuccessFetch();

    refreshState(() {
      if (tabResult != null) _tabResult = tabResult;
      _currentSort = tabResult?.customSort ?? tabResult?.itemsSort.firstWhereEff((e) => e.initiallySelected);
      _isLoadingInitial = false;
    });

    return tabResult;
  }

  Future<bool> _fetchNextPage() async {
    if (_isLoadingMoreItems.value) return false;

    final tabResult = _tabResult;
    if (tabResult == null || !tabResult.canFetchNext) return false;
    if (!ConnectivityController.inst.hasConnection) return false;
    _isLoadingMoreItems.value = true;
    final fetched = await tabResult.fetchNext();
    _isLoadingMoreItems.value = false;
    if (fetched && mounted) setState(() {});
    return fetched;
  }

  @override
  void initState() {
    _initValues().whenComplete(
      () {
        _initCompleter?.complete();
        _initCompleter = null;
      },
    );
    if (widget.shouldForceRequest()) widget.tabFetcher(fetchTabAndUpdate);
    super.initState();
  }

  @override
  void dispose() {
    _isLoadingMoreItems.close();
    super.dispose();
  }

  Future<void> _initValues() async {
    final tabResultCache = await YoutubeInfoController.channel.fetchChannelTabCache(channelId: widget.channelId, tab: widget.tab);
    refreshState(() {
      if (tabResultCache != null) {
        _tabResult = tabResultCache;
        _currentSort = tabResultCache.itemsSort.firstWhereEff((e) => e.initiallySelected);
      } else {
        _isLoadingInitial = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
    final tabResult = _tabResult;
    final displaySortChips = tabResult != null && tabResult.itemsSort.isNotEmpty;

    const paddingBeforeHeader = 18.0;
    const paddingForThumbnail = 12.0;
    const paddingAfterHeader = 6.0;

    const itemThumbnailHeight = Dimensions.youtubeThumbnailHeight;
    const itemThumbnailWidth = Dimensions.youtubeThumbnailWidth;
    const itemThumbnailItemExtent = itemThumbnailHeight + 8.0 * 2;

    const homeSectionHeight = itemThumbnailHeight * 2.1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8.0),
        if (displaySortChips)
          SmoothSingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const SizedBox(width: 8.0),
                ...tabResult.itemsSort.map(
                  (s) => NamidaInkWell(
                    borderRadius: 10.0,
                    bgColor: _currentSort?.title == s.title ? theme.colorScheme.secondaryContainer : theme.cardColor.withValues(alpha: 0.5),
                    margin: const EdgeInsets.symmetric(horizontal: 4.0),
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                    onTap: () async {
                      if (_currentSort?.title == s.title) return;

                      try {
                        widget.scrollController.jumpTo(0);
                      } catch (_) {}
                      final initialSort = _currentSort;
                      setState(() {
                        _currentSort = s;
                        _isLoadingInitial = true;
                      });
                      final didFetch = await tabResult.fetchWithNewSort(sort: s, details: ExecuteDetails.forceRequest());
                      if (_currentSort?.title != s.title) return; // if interrupted
                      if (mounted) {
                        setState(() {
                          if (!didFetch) _currentSort = initialSort;
                          _isLoadingInitial = false;
                        });
                      }
                    },
                    child: Text(
                      s.title,
                      style: textTheme.displayMedium,
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
              ],
            ),
          ),
        if (displaySortChips) const SizedBox(height: 8.0),
        Expanded(
          child: VideoTilePropertiesProvider(
            configs: VideoTilePropertiesConfigs(
              queueSource: QueueSourceYoutubeID.channelHosted,
            ),
            builder: (properties) => NamidaScrollbar(
              controller: widget.scrollController,
              child: LazyLoadListView(
                scrollController: widget.scrollController,
                onReachingEnd: _fetchNextPage,
                listview: (controller) => SmoothCustomScrollView(
                  controller: controller,
                  slivers: [
                    _isLoadingInitial
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
                                    thumbnailHeight: itemThumbnailHeight,
                                    thumbnailWidth: itemThumbnailWidth,
                                  );
                                },
                              ),
                            ),
                          )
                        : tabResult == null
                        ? SliverToBoxAdapter(
                            // child: Center(
                            //   child: Text(
                            //     lang.ERROR,
                            //     style: textTheme.displayLarge,
                            //   ),
                            // ),
                          )
                        : SliverVariedExtentList.builder(
                            itemExtentBuilder: (index, dimensions) {
                              final item = tabResult.items[index];
                              if (item is YoutiPieChannelHomeSection) {
                                var headerExtent = paddingBeforeHeader;
                                if (item.thumbnails.isNotEmpty) headerExtent += paddingForThumbnail;
                                headerExtent += paddingAfterHeader;
                                if (item.items.firstOrNull is PlaylistInfoItem) return homeSectionHeight * 0.9 + headerExtent;
                                return homeSectionHeight + headerExtent;
                              }
                              return itemThumbnailItemExtent;
                            },
                            itemCount: tabResult.items.length,
                            itemBuilder: (context, index) {
                              final item = tabResult.items[index];

                              if (item is YoutiPieChannelHomeSection) {
                                final subItems = item.items;
                                final headerTitle = item.title;
                                final headerThumbUrl = item.thumbnails.pick()?.url;
                                final playlistId = item.playlistId;
                                return Padding(
                                  padding: const EdgeInsets.only(top: paddingBeforeHeader),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          const SizedBox(width: 12.0),
                                          if (headerThumbUrl != null)
                                            YoutubeThumbnail(
                                              key: ValueKey(headerThumbUrl),
                                              width: 36.0,
                                              isImportantInCache: false,
                                              type: ThumbnailType.channel,
                                              isCircle: true,
                                              customUrl: headerThumbUrl,
                                            ),
                                          if (headerThumbUrl != null) const SizedBox(width: 12.0),
                                          Expanded(
                                            child: Text(
                                              headerTitle,
                                              style: textTheme.displayMedium,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (playlistId != null) const SizedBox(width: 8.0),
                                          if (playlistId != null)
                                            NamidaIconButton(
                                              icon: Broken.export_2,
                                              iconSize: 20.0,
                                              onPressed: () {
                                                YTHostedPlaylistSubpage.fromId(
                                                  playlistId: playlistId,
                                                  userPlaylist: null,
                                                ).navigate();
                                              },
                                            ),
                                          const SizedBox(width: 12.0),
                                        ],
                                      ),
                                      const SizedBox(height: paddingAfterHeader),
                                      Expanded(
                                        child: SuperSmoothListView.builder(
                                          padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                          scrollDirection: Axis.horizontal,
                                          itemExtent: itemThumbnailWidth + paddingForThumbnail,
                                          itemCount: subItems.length,
                                          itemBuilder: (context, index) {
                                            final subItem = subItems[index];

                                            if (subItem is PlaylistInfoItem) {
                                              return YoutubePlaylistCard(
                                                queueSource: QueueSourceYoutubeID.channelHosted,
                                                playlist: subItem,
                                                minimalCard: true,
                                                thumbnailHeight: itemThumbnailHeight,
                                                thumbnailWidth: itemThumbnailWidth + paddingForThumbnail,
                                                subtitle: subItem.subtitle,
                                                firstVideoID: subItem.initialVideos.firstOrNull?.id,
                                                isMixPlaylist: subItem.isMix,
                                              );
                                            }
                                            if (subItem is YoutiPieChannelInfo) {
                                              return YoutubeChannelCard(
                                                channel: subItem,
                                                mininmalCard: true,
                                                thumbnailSize: itemThumbnailHeight,
                                              );
                                            }
                                            return YTHistoryVideoCardBase(
                                              properties: properties,
                                              mainList: subItems,
                                              itemToYTVideoId: (e) {
                                                if (e is StreamInfoItem) {
                                                  return (e.id, null);
                                                } else if (e is StreamInfoItemShort) {
                                                  return (e.id, null);
                                                } else if (e is ChannelInfoItem) {
                                                  return (e.id, null);
                                                } else if (e is PlaylistInfoItem) {
                                                  return (e.id, null);
                                                }
                                                throw Exception('itemToYTID unknown type ${e.runtimeType}');
                                              },
                                              day: null,
                                              index: index,
                                              minimalCard: true,
                                              info: (item) {
                                                if (item is StreamInfoItem) {
                                                  return item;
                                                }
                                                if (item is StreamInfoItemShort) {
                                                  return StreamInfoItem(
                                                    id: item.id,
                                                    title: item.title,
                                                    shortDescription: null,
                                                    channel: const ChannelInfoItem.anonymous(),
                                                    thumbnailGifUrl: null,
                                                    publishedFromText: '',
                                                    publishedAt: const PublishTime.unknown(),
                                                    indexInPlaylist: null,
                                                    durSeconds: null,
                                                    durText: null,
                                                    viewsText: item.viewsText,
                                                    viewsCount: item.viewsCount,
                                                    percentageWatched: null,
                                                    liveThumbs: item.liveThumbs,
                                                    isUploaderVerified: null,
                                                    badges: null,
                                                    isActuallyShortContent: true,
                                                  );
                                                }
                                                return null;
                                              },
                                              minimalCardWidth: itemThumbnailWidth + paddingForThumbnail,
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return switch (item.runtimeType) {
                                const (StreamInfoItem) => YoutubeVideoCard(
                                  properties: properties,
                                  key: Key((item as StreamInfoItem).id),
                                  thumbnailHeight: itemThumbnailHeight,
                                  thumbnailWidth: itemThumbnailWidth,
                                  isImageImportantInCache: false,
                                  video: item,
                                  playlistID: null,
                                  dateInsteadOfChannel: true,
                                  showThirdLine: false,
                                ),
                                const (StreamInfoItemShort) => YoutubeShortVideoCard(
                                  queueSource: QueueSourceYoutubeID.channelHosted,
                                  key: Key("${(item as StreamInfoItemShort?)?.id}"),
                                  thumbnailHeight: itemThumbnailHeight,
                                  thumbnailWidth: itemThumbnailWidth,
                                  short: item as StreamInfoItemShort,
                                  playlistID: null,
                                ),
                                const (PlaylistInfoItem) => YoutubePlaylistCard(
                                  queueSource: QueueSourceYoutubeID.channelHosted,
                                  key: Key((item as PlaylistInfoItem).id),
                                  thumbnailHeight: itemThumbnailHeight,
                                  thumbnailWidth: itemThumbnailWidth,
                                  playlist: item,
                                  subtitle: item.subtitle,
                                  playOnTap: false,
                                  firstVideoID: item.initialVideos.firstOrNull?.id,
                                  isMixPlaylist: item.isMix,
                                ),
                                const (YoutiPieChannelInfo) => YoutubeChannelCard(
                                  channel: item as YoutiPieChannelInfo,
                                  thumbnailSize: itemThumbnailHeight,
                                ),
                                _ => const YoutubeVideoCardDummy(
                                  shimmerEnabled: true,
                                  thumbnailHeight: itemThumbnailHeight,
                                  thumbnailWidth: itemThumbnailWidth,
                                  dateInsteadOfChannel: true,
                                  displaythirdLineText: false,
                                ),
                              };
                            },
                          ),
                    SliverToBoxAdapter(
                      child: ObxO(
                        rx: _isLoadingMoreItems,
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
