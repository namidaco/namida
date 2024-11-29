import 'dart:async';

import 'package:flutter/material.dart';

import 'package:youtipie/class/channels/channel_info.dart';
import 'package:youtipie/class/execute_details.dart';
import 'package:youtipie/class/result_wrapper/search_result.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item_short.dart';
import 'package:youtipie/class/youtipie_feed/playlist_info_item.dart';

import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/three_arched_circle.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/youtube_local_search_controller.dart';
import 'package:namida/youtube/pages/yt_local_search_results.dart';
import 'package:namida/youtube/widgets/yt_channel_card.dart';
import 'package:namida/youtube/widgets/yt_history_video_card.dart';
import 'package:namida/youtube/widgets/yt_playlist_card.dart';
import 'package:namida/youtube/widgets/yt_video_card.dart';

class YoutubeSearchResultsPage extends StatefulWidget {
  final String Function()? searchTextCallback;
  final void Function(StreamInfoItem video)? onVideoTap;
  const YoutubeSearchResultsPage({super.key, required this.searchTextCallback, this.onVideoTap});

  @override
  State<YoutubeSearchResultsPage> createState() => YoutubeSearchResultsPageState();
}

class YoutubeSearchResultsPageState extends State<YoutubeSearchResultsPage> with AutomaticKeepAliveClientMixin<YoutubeSearchResultsPage> {
  Timer? _keepAliveTimer;

  @override
  bool get wantKeepAlive => _wantKeepAlive;

  bool _wantKeepAlive = true;

  void _keepDead() {
    _keepAliveTimer?.cancel();
    if (mounted) return; // return if mounted again
    _wantKeepAlive = false;
    updateKeepAlive();
  }

  String? get currentSearchText => widget.searchTextCallback?.call() ?? _latestSearched;
  String? _latestSearched;

  YoutiPieSearchResult? _searchResult;
  final _isFetchingMoreResults = false.obs;
  bool? _loadingFirstResults;
  bool? _cachedSearchResults;

  final _offlineSearchPageKey = GlobalKey<YTLocalSearchResultsState>();

  @override
  void initState() {
    super.initState();
    fetchSearch();
    YTLocalSearchController.inst.initialize().then((_) {
      YTLocalSearchController.inst.search(currentSearchText ?? '');
    });
  }

  @override
  void dispose() {
    _isFetchingMoreResults.close();
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer(const Duration(seconds: 20), _keepDead);
    super.dispose();
  }

  Future<void> fetchSearch({String customText = ''}) async {
    final newSearch = customText == '' ? widget.searchTextCallback?.call() ?? '' : customText;
    if (_latestSearched == newSearch && _searchResult != null) return;
    _latestSearched = newSearch;

    YTLocalSearchController.inst.search(newSearch);
    if (_searchResult != null) refreshState(() => _searchResult = null);
    if (newSearch == '') return;
    if (NamidaNavigator.inst.isytLocalSearchInFullPage) return;

    refreshState(() => _loadingFirstResults = true);

    YoutiPieSearchResult? result;
    if (ConnectivityController.inst.hasConnection) {
      result = await YoutubeInfoController.search.search(newSearch, details: ExecuteDetails.forceRequest());
      _cachedSearchResults = false;
    } else {
      result = await YoutubeInfoController.search.search(newSearch);
      _cachedSearchResults = result != null;
    }

    _searchResult = result;
    _loadingFirstResults = false;
    refreshState();
  }

  Future<bool> _fetchSearchNextPage() async {
    bool fetched = false;
    final searchRes = _searchResult;
    if (searchRes == null) return fetched; // return if still fetching first results.
    if (!searchRes.canFetchNext) return fetched;
    if (!ConnectivityController.inst.hasConnection) return fetched;
    _isFetchingMoreResults.value = true;
    fetched = await searchRes.fetchNext();
    _isFetchingMoreResults.value = false;
    refreshState();
    return fetched;
  }

  void _onOfflineSearchTap() {
    // if (_isLoadingLocalLookupList.value || currentSearchText == '') return;
    NamidaNavigator.inst.ytLocalSearchNavigatorKey.currentState?.pushPage(
      YTLocalSearchResults(
        key: _offlineSearchPageKey,
        initialSearch: currentSearchText ?? ScrollSearchController.inst.searchTextEditingController.text,
        onVideoTap: widget.onVideoTap,
      ),
      maintainState: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    const thumbnailHeight = Dimensions.youtubeThumbnailHeight;
    const thumbnailWidth = Dimensions.youtubeThumbnailWidth;
    const thumbnailItemExtent = thumbnailHeight + 8.0 * 2;

    const localMultiplier = 0.9;
    const thumbnailWidthLocal = thumbnailWidth * localMultiplier;
    const thumbnailHeightLocal = thumbnailHeight * localMultiplier;
    const thumbnailItemExtentLocal = thumbnailWidthLocal - 2 * 2.0; // - card margin
    final horizontalListHeight = 112.0 * localMultiplier;

    final searchResult = _searchResult;
    const maxLocalSeachHorizontalCount = 40;

    return BackgroundWrapper(
      child: Navigator(
        key: NamidaNavigator.inst.ytLocalSearchNavigatorKey,
        onPopPage: (route, result) => false,
        requestFocus: false,
        pages: [
          MaterialPage(
            child: LazyLoadListView(
              onReachingEnd: _fetchSearchNextPage,
              listview: (controller) {
                return CustomScrollView(
                  controller: controller,
                  slivers: [
                    const SliverPadding(padding: EdgeInsets.only(bottom: 4.0)),
                    // -- local
                    SliverToBoxAdapter(
                      child: SizedBox(
                        width: context.width,
                        height: 54.0,
                        child: NamidaInkWell(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                          margin: const EdgeInsets.symmetric(horizontal: 12.0),
                          onTap: _onOfflineSearchTap,
                          child: Row(
                            children: [
                              const Icon(Broken.radar_2),
                              const SizedBox(width: 8.0),
                              Text(
                                lang.OFFLINE_SEARCH,
                                style: context.textTheme.displayLarge,
                              ),
                              const Spacer(),
                              const SizedBox(width: 6.0),
                              if (_cachedSearchResults == true) ...[
                                const SizedBox(width: 6.0),
                                const Icon(Broken.global_refresh, size: 20.0),
                                const SizedBox(width: 6.0),
                              ],
                              ObxO(
                                rx: YTLocalSearchController.inst.didLoadLookupLists,
                                builder: (context, didLoadLookupLists) => didLoadLookupLists == false ? const LoadingIndicator() : const SizedBox(),
                              ),
                              const SizedBox(width: 6.0),
                              const Icon(Broken.arrow_right_3),
                            ],
                          ),
                        ),
                      ),
                    ),
                    ObxO(
                      rx: YTLocalSearchController.inst.searchResults,
                      builder: (context, searchResultsLocal) {
                        if (searchResultsLocal == null) {
                          return SliverToBoxAdapter(
                            child: ShimmerWrapper(
                              shimmerEnabled: true,
                              child: SizedBox(
                                height: horizontalListHeight,
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                  scrollDirection: Axis.horizontal,
                                  itemCount: 10,
                                  itemBuilder: (context, index) {
                                    return NamidaInkWell(
                                      animationDurationMS: 0,
                                      margin: YTHistoryVideoCardBase.cardMargin(true),
                                      width: thumbnailWidthLocal - YTHistoryVideoCardBase.minimalCardExtraThumbCropWidth,
                                      height: thumbnailHeightLocal - YTHistoryVideoCardBase.minimalCardExtraThumbCropHeight,
                                      bgColor: context.theme.cardColor,
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        }
                        if (searchResultsLocal.isEmpty) {
                          return SliverToBoxAdapter();
                        }
                        final localSearchDisplayExtraCardWithRemainingCount = searchResultsLocal.length > maxLocalSeachHorizontalCount;
                        return SliverToBoxAdapter(
                          child: SizedBox(
                            height: horizontalListHeight,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 6.0),
                              scrollDirection: Axis.horizontal,
                              itemExtent: thumbnailItemExtentLocal,
                              itemCount: localSearchDisplayExtraCardWithRemainingCount ? maxLocalSeachHorizontalCount + 1 : searchResultsLocal.length,
                              itemBuilder: (context, index) {
                                if (index == maxLocalSeachHorizontalCount && localSearchDisplayExtraCardWithRemainingCount) {
                                  final remainingVideosCount = searchResultsLocal.length - maxLocalSeachHorizontalCount;
                                  return remainingVideosCount <= 0
                                      ? const SizedBox()
                                      : NamidaInkWell(
                                          onTap: _onOfflineSearchTap,
                                          margin: const EdgeInsets.all(12.0),
                                          padding: const EdgeInsets.all(12.0),
                                          child: Center(
                                            child: Text(
                                              "+${remainingVideosCount.formatDecimalShort()}",
                                              style: context.textTheme.displayMedium,
                                            ),
                                          ),
                                        );
                                }
                                final item = searchResultsLocal[index];
                                return YTHistoryVideoCardBase(
                                  mainList: searchResultsLocal,
                                  itemToYTVideoId: (e) => (e.id, null),
                                  day: null,
                                  index: index,
                                  playlistID: null,
                                  playlistName: lang.HISTORY,
                                  canHaveDuplicates: true,
                                  minimalCard: true,
                                  info: (item) => item,
                                  thumbnailHeight: thumbnailHeightLocal,
                                  minimalCardWidth: thumbnailWidthLocal,
                                  playSingle: true,
                                  onTap: widget.onVideoTap == null ? null : () => widget.onVideoTap!(item),
                                  minimalCardFontMultiplier: localMultiplier * 0.95,
                                  isImportantInCache: false,
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),

                    const SliverToBoxAdapter(
                      child: NamidaContainerDivider(
                        margin: EdgeInsets.symmetric(
                          vertical: 4.0,
                          horizontal: 12.0,
                        ),
                      ),
                    ),

                    // -- yt (header)
                    if (searchResult != null && searchResult.correctedQuery.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Align(
                          alignment: Alignment.center,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                            child: Material(
                              borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(6.0.multipliedRadius),
                                onTap: () {
                                  final correctedQuery = searchResult.correctedQuery.map((c) => c.text).join();
                                  ScrollSearchController.inst.searchTextEditingController.text = correctedQuery;
                                  fetchSearch(customText: correctedQuery);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                                  child: Text.rich(
                                    TextSpan(
                                      text: "${lang.DID_YOU_MEAN}: ",
                                      style: context.textTheme.displaySmall?.copyWith(fontSize: 13.0),
                                      children: searchResult.correctedQuery
                                          .map((c) => TextSpan(
                                                text: c.text,
                                                style: context.textTheme.displaySmall?.copyWith(
                                                  fontSize: 14.0,
                                                  fontWeight: c.corrected ? FontWeight.w700 : FontWeight.w500,
                                                ),
                                              ))
                                          .toList(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // -- yt (items list)
                    _loadingFirstResults == null
                        ? const SliverToBoxAdapter()
                        : _loadingFirstResults == true
                            ? SliverToBoxAdapter(
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32.0),
                                    child: ThreeArchedCircle(
                                      color: CurrentColor.inst.color.withOpacity(0.4),
                                      size: context.width * 0.35,
                                    ),
                                  ),
                                ),
                              )
                            : searchResult == null
                                ? const SliverToBoxAdapter()
                                : ObxO(
                                    rx: settings.youtube.ytVisibleShorts,
                                    builder: (context, visibleShorts) {
                                      final isShortsVisible = visibleShorts[YTVisibleShortPlaces.search] ?? true;
                                      return ObxO(
                                        rx: settings.youtube.ytVisibleMixes,
                                        builder: (context, visibleMixes) {
                                          final isMixesVisible = visibleMixes[YTVisibleMixesPlaces.search] ?? true;
                                          return SliverList.builder(
                                            itemCount: searchResult.length,
                                            itemBuilder: (context, index) {
                                              final chunk = searchResult.items[index];
                                              final items = chunk.items;
                                              int itemsLengthWithoutHiddens = items.length;
                                              if (!isShortsVisible) itemsLengthWithoutHiddens -= chunk.shortsItemsCount.value;
                                              if (!isMixesVisible) itemsLengthWithoutHiddens -= chunk.mixesPlaylistCount.value;
                                              if (itemsLengthWithoutHiddens <= 0) return const SizedBox();

                                              return Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  if (chunk.title.isNotEmpty)
                                                    Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                                                      child: Text(
                                                        chunk.title,
                                                        style: context.textTheme.displayMedium,
                                                      ),
                                                    ),
                                                  SizedBox(
                                                    height: itemsLengthWithoutHiddens * thumbnailItemExtent,
                                                    child: ListView.builder(
                                                      primary: false,
                                                      physics: const NeverScrollableScrollPhysics(),
                                                      itemExtent: isShortsVisible && isMixesVisible ? thumbnailItemExtent : null,
                                                      // -- we use extent builder only if shorts/mixes are hidden
                                                      itemExtentBuilder: isShortsVisible && isMixesVisible
                                                          ? null
                                                          : (index, dimensions) {
                                                              final item = items[index];
                                                              if (!isShortsVisible && item is StreamInfoItemShort) return 0;
                                                              if (!isMixesVisible && item is PlaylistInfoItem && item.isMix) return 0;
                                                              return thumbnailItemExtent;
                                                            },
                                                      itemCount: items.length,
                                                      itemBuilder: (context, index) {
                                                        final item = items[index];
                                                        if (!isShortsVisible && item is StreamInfoItemShort) return const SizedBox();
                                                        if (!isMixesVisible && item is PlaylistInfoItem && item.isMix) return const SizedBox();
                                                        return switch (item.runtimeType) {
                                                          const (StreamInfoItem) => YoutubeVideoCard(
                                                              thumbnailHeight: thumbnailHeight,
                                                              thumbnailWidth: thumbnailWidth,
                                                              isImageImportantInCache: false,
                                                              video: item as StreamInfoItem,
                                                              playlistID: null,
                                                              onTap: widget.onVideoTap == null ? null : () => widget.onVideoTap!(item),
                                                            ),
                                                          const (StreamInfoItemShort) => !isShortsVisible
                                                              ? const SizedBox.shrink()
                                                              : YoutubeShortVideoCard(
                                                                  thumbnailHeight: thumbnailHeight,
                                                                  thumbnailWidth: thumbnailWidth,
                                                                  short: item as StreamInfoItemShort,
                                                                  playlistID: null,
                                                                ),
                                                          const (PlaylistInfoItem) => (item as PlaylistInfoItem).isMix && !isMixesVisible
                                                              ? const SizedBox.shrink()
                                                              : YoutubePlaylistCard(
                                                                  thumbnailHeight: thumbnailHeight,
                                                                  thumbnailWidth: thumbnailWidth,
                                                                  playOnTap: false,
                                                                  playlist: item,
                                                                  firstVideoID: item.initialVideos.firstOrNull?.id,
                                                                  subtitle: item.subtitle.isNotEmpty ? item.subtitle : item.initialVideos.firstOrNull?.title,
                                                                  isMixPlaylist: item.isMix,
                                                                ),
                                                          const (YoutiPieChannelInfo) => YoutubeChannelCard(
                                                              channel: item as YoutiPieChannelInfo,
                                                              thumbnailSize: thumbnailHeight,
                                                            ),
                                                          _ => const YoutubeVideoCardDummy(
                                                              shimmerEnabled: true,
                                                              thumbnailHeight: thumbnailHeight,
                                                              thumbnailWidth: thumbnailWidth,
                                                            ),
                                                        };
                                                      },
                                                    ),
                                                  ),
                                                  if (chunk.title.isNotEmpty) const SizedBox(height: 8.0),
                                                ],
                                              );
                                            },
                                          );
                                        },
                                      );
                                    },
                                  ),
                    SliverToBoxAdapter(
                      child: Obx(
                        (context) => _isFetchingMoreResults.valueR
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
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
