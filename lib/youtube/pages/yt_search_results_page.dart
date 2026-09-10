import 'dart:async';

import 'package:flutter/material.dart';

import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:youtipie/class/channels/channel_info.dart';
import 'package:youtipie/class/execute_details.dart';
import 'package:youtipie/class/result_wrapper/search_result.dart';
import 'package:youtipie/class/search_filters.dart';
import 'package:youtipie/class/search_suggestion_info.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item_short.dart';
import 'package:youtipie/class/youtipie_feed/playlist_info_item.dart';
import 'package:youtipie/youtipie.dart';

import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/three_arched_circle.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/youtube_local_search_controller.dart';
import 'package:namida/youtube/pages/yt_local_search_results.dart';
import 'package:namida/youtube/widgets/yt_channel_card.dart';
import 'package:namida/youtube/widgets/yt_history_video_card.dart';
import 'package:namida/youtube/widgets/yt_playlist_card.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:namida/youtube/widgets/yt_video_card.dart';

class YoutubeSearchResultsPage extends StatefulWidget {
  final String Function()? searchTextCallback;
  final void Function(StreamInfoItem video)? onVideoTap;
  const YoutubeSearchResultsPage({super.key, required this.searchTextCallback, this.onVideoTap});

  @override
  State<YoutubeSearchResultsPage> createState() => YoutubeSearchResultsPageState();
}

class YoutubeSearchResultsPageState extends State<YoutubeSearchResultsPage> {
  String? get currentSearchText => widget.searchTextCallback?.call() ?? _latestSearched;
  static String? _latestSearched;
  List<SearchSuggestionInfo>? _suggestions;

  static YoutiPieSearchResult? _searchResult;
  final _isFetchingMoreResults = false.obs;
  static bool? _loadingFirstResults;
  static bool? _cachedSearchResults;

  static YoutiPieSearchFilters _filters = YoutiPieSearchFilters.defaults;
  static YoutiPieSearchFilters? _latestSearchedFilters;
  static bool _dateRangeFromText = false;

  static void setFilters(YoutiPieSearchFilters filters) {
    _filters = filters;
    _dateRangeFromText = false;
  }

  final _offlineSearchPageKey = GlobalKey<YTLocalSearchResultsState>();

  @override
  void initState() {
    super.initState();
    YTLocalSearchController.inst.initialize();
    // -- must be asap and before [fetchSearch], will execute once internal initialization ends
    YTLocalSearchController.inst.search(currentSearchText ?? '', after: _filters.after, before: _filters.before);
    fetchSearch();
    _onTextFieldChanged();
    ScrollSearchController.inst.searchTextEditingController.addListener(_onTextFieldChanged);
  }

  @override
  void dispose() {
    _isFetchingMoreResults.close();
    ScrollSearchController.inst.searchTextEditingController.removeListener(_onTextFieldChanged);
    _debouncerTimer?.cancel();
    super.dispose();
  }

  Timer? _debouncerTimer;
  bool get shouldFetchOrDisplaySuggestions => _loadingFirstResults == null || (_loadingFirstResults == false && _searchResult == null);
  void _onTextFieldChanged() async {
    _debouncerTimer?.cancel();
    if (ScrollSearchController.inst.searchTextEditingController.text.isNotEmpty && shouldFetchOrDisplaySuggestions && ConnectivityController.inst.hasConnection) {
      _debouncerTimer = Timer(const Duration(milliseconds: 400), () async {
        final query = ScrollSearchController.inst.searchTextEditingController.text;
        final suggestions = query.isEmpty ? null : await YoutubeInfoController.search.getSuggestions(query, details: ExecuteDetails.kForceRequest);
        if (mounted) {
          if (suggestions != null && suggestions.isNotEmpty && shouldFetchOrDisplaySuggestions) {
            setState(() => _suggestions = suggestions);
          } else {
            setState(() => _suggestions = null);
          }
        }
      });
    } else {
      if (_suggestions != null) {
        setState(() => _suggestions = null);
      }
    }
  }

  void _syncDateRangeFromText(String text) {
    final parsed = YoutiPieSearchFilters.parseDateOperators(text);
    if (parsed != null) {
      _filters = _filters.copyWith(
        after: parsed.after,
        before: parsed.before,
        clearAfter: parsed.after == null,
        clearBefore: parsed.before == null,
      );
      _dateRangeFromText = true;
    } else if (_dateRangeFromText) {
      _filters = _filters.copyWith(clearAfter: true, clearBefore: true);
      _dateRangeFromText = false;
    }
  }

  void _onFiltersChanged(YoutiPieSearchFilters newFilters, {bool dateRangeChanged = false}) {
    if (newFilters == _filters) return;
    if (dateRangeChanged) {
      _dateRangeFromText = false;
      if (widget.searchTextCallback == null) {
        final textController = ScrollSearchController.inst.searchTextEditingController;
        final stripped = YoutiPieSearchFilters.stripDateOperators(textController.text);
        if (stripped != textController.text) textController.text = stripped;
      }
    }
    _filters = newFilters;
    refreshState();
    fetchSearch();
  }

  Future<void> fetchSearch({String customText = ''}) async {
    _debouncerTimer?.cancel();

    final newSearch = customText == '' ? widget.searchTextCallback?.call() ?? ScrollSearchController.inst.searchTextEditingController.text : customText;
    _syncDateRangeFromText(newSearch);
    final filters = _filters;
    if (_latestSearched == newSearch && _latestSearchedFilters == filters && _searchResult != null) {
      YTLocalSearchController.inst.search(newSearch, after: filters.after, before: filters.before); // has its own latest search checks
      return;
    }
    _latestSearched = newSearch;
    _latestSearchedFilters = filters;

    YTLocalSearchController.inst.search(newSearch, after: filters.after, before: filters.before);
    if (_searchResult != null) refreshState(() => _searchResult = null);
    if (newSearch == '') return;
    if (NamidaNavigator.inst.isytLocalSearchInFullPage) return;

    refreshState(() => _loadingFirstResults = true);

    YoutiPieSearchResult? result;
    if (ConnectivityController.inst.hasConnection) {
      result = await YoutubeInfoController.search.search(newSearch, filters: filters, details: ExecuteDetails.kForceRequest);
      _cachedSearchResults = false;
    } else {
      result = await YoutubeInfoController.search.search(newSearch, filters: filters);
      _cachedSearchResults = result != null;
    }

    if (_latestSearched != newSearch || _latestSearchedFilters != filters) return; // -- a newer search was started

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
      params: const NamPackPushPageParams(
        maintainState: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textTheme = theme.textTheme;
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

    final suggestions = _suggestions;

    return BackgroundWrapper(
      child: NamidaNavigatorWidget(
        navKey: NamidaNavigator.inst.ytLocalSearchNavigatorKey,
        allowPop: false,
        pages: [
          MaterialPage(
            child: LazyLoadListView(
              onReachingEnd: _fetchSearchNextPage,
              listview: (controller) {
                return SmoothCustomScrollView(
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
                                lang.offlineSearch,
                                style: textTheme.displayLarge,
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
                                child: SuperSmoothListView.builder(
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
                                      bgColor: theme.cardColor,
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
                          child: VideoTilePropertiesProvider(
                            configs: VideoTilePropertiesConfigs(
                              queueSource: QueueSourceYoutubeID.ytSearch,
                            ),
                            builder: (properties) => SizedBox(
                              height: horizontalListHeight,
                              child: SuperSmoothListView.builder(
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
                                                style: textTheme.displayMedium,
                                              ),
                                            ),
                                          );
                                  }
                                  final item = searchResultsLocal[index];
                                  return YTHistoryVideoCardBase(
                                    properties: properties,
                                    mainList: searchResultsLocal,
                                    itemToYTVideoId: (e) => (e.id, null),
                                    day: null,
                                    index: index,
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

                    // -- yt (filters)
                    SliverToBoxAdapter(
                      child: _YTSearchFiltersRow(
                        filters: _filters,
                        onChanged: _onFiltersChanged,
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
                                      text: "${lang.didYouMean}: ",
                                      style: textTheme.displaySmall?.copyWith(fontSize: 13.0),
                                      children: searchResult.correctedQuery
                                          .map(
                                            (c) => TextSpan(
                                              text: c.text,
                                              style: textTheme.displaySmall?.copyWith(
                                                fontSize: 14.0,
                                                fontWeight: c.corrected ? FontWeight.w700 : FontWeight.w500,
                                              ),
                                            ),
                                          )
                                          .toFixedList(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // -- yt (items list)
                    suggestions != null && shouldFetchOrDisplaySuggestions
                        ? SliverList.builder(
                            itemCount: suggestions.length,
                            itemBuilder: (context, index) {
                              final suggestionInfo = suggestions[index];
                              final fullText = suggestionInfo.fullText;
                              final typed = suggestionInfo.typedAndCompletion?.$1;
                              final completion = suggestionInfo.typedAndCompletion?.$2;
                              final subtitle = suggestionInfo.subtitle ?? suggestionInfo.displayName ?? suggestionInfo.entityId;
                              final thumbnailUrl = suggestionInfo.thumbnailUrl;
                              final isChannel = suggestionInfo.isChannel;
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 3.0),
                                child: NamidaInkWell(
                                  borderRadius: 10.0,
                                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                                  bgColor: theme.cardColor,
                                  onTap: () {
                                    ScrollSearchController.inst.searchTextEditingController.text = fullText;
                                    fetchSearch(customText: fullText);
                                  },
                                  child: Row(
                                    mainAxisSize: .min,
                                    children: [
                                      const SizedBox(width: 12.0),
                                      const Icon(
                                        Broken.magicpen,
                                        size: 18.0,
                                      ),
                                      const SizedBox(width: 8.0),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: .start,
                                          mainAxisAlignment: .start,
                                          children: [
                                            Text.rich(
                                              TextSpan(
                                                text: typed ?? fullText,
                                                style: textTheme.displaySmall?.copyWith(fontSize: 14.0, fontWeight: FontWeight.w700),
                                                children: completion == null
                                                    ? null
                                                    : [
                                                        TextSpan(
                                                          text: completion,
                                                          style: textTheme.displaySmall?.copyWith(fontSize: 14.0, fontWeight: FontWeight.w400),
                                                        ),
                                                      ],
                                              ),
                                            ),
                                            if (subtitle != null && subtitle.isNotEmpty)
                                              Text(
                                                subtitle,
                                                style: textTheme.displaySmall?.copyWith(fontSize: 11.0, fontWeight: FontWeight.w200),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) ...[
                                        const SizedBox(width: 12.0),
                                        YoutubeThumbnail(
                                          type: isChannel ? ThumbnailType.channel : ThumbnailType.other,
                                          key: Key(thumbnailUrl),
                                          width: 24.0,
                                          height: 24.0,
                                          borderRadius: 4.0,
                                          forceSquared: true,
                                          isImportantInCache: true,
                                          customUrl: thumbnailUrl,
                                          isCircle: isChannel,
                                        ),
                                      ],
                                      const SizedBox(width: 4.0),
                                      Transform.flip(
                                        flipX: true,
                                        child: NamidaIconButton(
                                          horizontalPadding: 8.0,
                                          icon: Broken.export_1,
                                          iconSize: 18.0,
                                          onPressed: () {
                                            ScrollSearchController.inst.searchTextEditingController.text = fullText;
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 4.0),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                        : _loadingFirstResults == null
                        ? const SliverToBoxAdapter()
                        : _loadingFirstResults == true
                        ? SliverToBoxAdapter(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: ThreeArchedCircle(
                                  color: CurrentColor.inst.color.withOpacityExt(0.4),
                                  size: Dimensions.inst.availableAppContentWidth * 0.35,
                                ),
                              ),
                            ),
                          )
                        : searchResult == null
                        ? const SliverToBoxAdapter()
                        : VideoTilePropertiesProvider(
                            configs: VideoTilePropertiesConfigs(
                              queueSource: QueueSourceYoutubeID.ytSearchHosted,
                            ),
                            builder: (properties) => ObxO(
                              rx: settings.youtube.ytVisibleShorts,
                              builder: (context, visibleShorts) {
                                final isShortsVisible = visibleShorts[YTVisibleShortPlaces.search] ?? true;
                                return ObxO(
                                  rx: settings.youtube.ytVisibleMixes,
                                  builder: (context, visibleMixes) {
                                    final isMixesVisible = visibleMixes[YTVisibleMixesPlaces.search] ?? true;
                                    return SuperSliverList.builder(
                                      itemCount: searchResult.length,
                                      itemBuilder: (context, index) {
                                        final chunk = searchResult.items[index];
                                        final items = chunk.items;
                                        int itemsLengthWithoutHiddens = items.length;
                                        if (!isShortsVisible) itemsLengthWithoutHiddens -= chunk.shortsItemsCount.value;
                                        if (!isMixesVisible) itemsLengthWithoutHiddens -= chunk.mixesPlaylistCount.value;
                                        if (itemsLengthWithoutHiddens <= 0) return const SizedBox();

                                        if (settings.youtube.searchCleanup.value) {
                                          if (chunk.title.isNotEmpty) {
                                            return const SizedBox();
                                          }
                                        }

                                        return Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (chunk.title.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                                                child: Text(
                                                  chunk.title,
                                                  style: textTheme.displayMedium,
                                                ),
                                              ),
                                            SizedBox(
                                              height: itemsLengthWithoutHiddens * thumbnailItemExtent,
                                              child: SuperSmoothListView.builder(
                                                padding: EdgeInsets.zero,
                                                primary: false,
                                                physics: const NeverScrollableScrollPhysics(),
                                                itemExtent: isShortsVisible && isMixesVisible ? thumbnailItemExtent : null,
                                                // -- we use extent builder only if shorts/mixes are hidden
                                                itemExtentBuilder: isShortsVisible && isMixesVisible
                                                    ? null
                                                    : (index, dimensions) {
                                                        final item = items[index];
                                                        if (!isShortsVisible && item.isShortContent) return 0;
                                                        if (!isMixesVisible && item.isMixPlaylist) return 0;
                                                        return thumbnailItemExtent;
                                                      },
                                                itemCount: items.length,
                                                itemBuilder: (context, index) {
                                                  final item = items[index];
                                                  if (!isShortsVisible && item.isShortContent) return const SizedBox.shrink();
                                                  if (!isMixesVisible && item.isMixPlaylist) return const SizedBox.shrink();
                                                  return switch (item.runtimeType) {
                                                    const (StreamInfoItem) => YoutubeVideoCard(
                                                      properties: properties,
                                                      thumbnailHeight: thumbnailHeight,
                                                      thumbnailWidth: thumbnailWidth,
                                                      isImageImportantInCache: false,
                                                      video: item as StreamInfoItem,
                                                      playlistID: null,
                                                      onTap: widget.onVideoTap == null ? null : () => widget.onVideoTap!(item),
                                                    ),
                                                    const (StreamInfoItemShort) => YoutubeShortVideoCard(
                                                      queueSource: QueueSourceYoutubeID.ytSearchHosted,
                                                      thumbnailHeight: thumbnailHeight,
                                                      thumbnailWidth: thumbnailWidth,
                                                      short: item as StreamInfoItemShort,
                                                      playlistID: null,
                                                    ),
                                                    const (PlaylistInfoItem) => YoutubePlaylistCard(
                                                      queueSource: QueueSourceYoutubeID.ytSearchHosted,
                                                      thumbnailHeight: thumbnailHeight,
                                                      thumbnailWidth: thumbnailWidth,
                                                      playOnTap: false,
                                                      playlist: item as PlaylistInfoItem,
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
          ),
        ],
      ),
    );
  }
}

// by claude
class _YTSearchFiltersRow extends StatelessWidget {
  final YoutiPieSearchFilters filters;
  final void Function(YoutiPieSearchFilters newFilters, {bool dateRangeChanged}) onChanged;

  const _YTSearchFiltersRow({required this.filters, required this.onChanged});

  static String _typeToText(YoutiPieSearchType type) => switch (type) {
    YoutiPieSearchType.all => lang.all,
    YoutiPieSearchType.video => lang.videos,
    YoutiPieSearchType.channel => lang.channels,
    YoutiPieSearchType.playlist => lang.playlists,
    YoutiPieSearchType.movie => lang.movies,
  };

  static IconData _typeToIcon(YoutiPieSearchType type) => switch (type) {
    YoutiPieSearchType.all => Broken.category,
    YoutiPieSearchType.video => Broken.video,
    YoutiPieSearchType.channel => Broken.user,
    YoutiPieSearchType.playlist => Broken.music_playlist,
    YoutiPieSearchType.movie => Broken.video_play,
  };

  static String _sortToText(YoutiPieSearchSort sort) => switch (sort) {
    YoutiPieSearchSort.relevance => lang.relevance,
    YoutiPieSearchSort.rating => lang.rating,
    YoutiPieSearchSort.date => lang.uploadDate,
    YoutiPieSearchSort.views => lang.views,
  };

  static IconData _sortToIcon(YoutiPieSearchSort sort) => switch (sort) {
    YoutiPieSearchSort.relevance => Broken.award,
    YoutiPieSearchSort.rating => Broken.star,
    YoutiPieSearchSort.date => Broken.calendar_1,
    YoutiPieSearchSort.views => Broken.eye,
  };

  static String _uploadDateToText(YoutiPieSearchUploadDate uploadDate) => switch (uploadDate) {
    YoutiPieSearchUploadDate.none => lang.all,
    YoutiPieSearchUploadDate.lastHour => lang.lastHour,
    YoutiPieSearchUploadDate.today => lang.today,
    YoutiPieSearchUploadDate.thisWeek => lang.thisWeek,
    YoutiPieSearchUploadDate.thisMonth => lang.thisMonth,
    YoutiPieSearchUploadDate.thisYear => lang.thisYear,
  };

  static String _dateRangeToText(YoutiPieSearchFilters filters) {
    final after = filters.after;
    final before = filters.before;
    if (after != null && before != null) return '$after - $before';
    if (after != null) return '${lang.isAfter} $after';
    return '${lang.isBefore} $before';
  }

  Future<void> _pickDate({required bool isAfter}) async {
    final initial = isAfter ? filters.after : filters.before;
    final date = await showYTSearchDateDialog(
      title: isAfter ? lang.isAfter : lang.isBefore,
      initial: initial,
    );
    if (date == null) return;
    onChanged(
      isAfter ? filters.copyWith(after: date, uploadDate: YoutiPieSearchUploadDate.none) : filters.copyWith(before: date, uploadDate: YoutiPieSearchUploadDate.none),
      dateRangeChanged: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filters = this.filters;
    final hasDateRange = filters.hasDateRange;
    final isDateActive = hasDateRange || filters.uploadDate != YoutiPieSearchUploadDate.none;
    return SizedBox(
      height: 40.0,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        children: [
          _YTSearchFilterChip(
            icon: _typeToIcon(filters.type),
            title: filters.type == YoutiPieSearchType.all ? lang.type : _typeToText(filters.type),
            isActive: filters.type != YoutiPieSearchType.all,
            onClear: () => onChanged(filters.copyWith(type: YoutiPieSearchType.all)),
            items: () => YoutiPieSearchType.values.map(
              (e) => NamidaPopupItem(
                icon: _typeToIcon(e),
                title: _typeToText(e),
                selected: e == filters.type,
                onTap: () => onChanged(filters.copyWith(type: e)),
              ),
            ),
          ),
          _YTSearchFilterChip(
            icon: _sortToIcon(filters.sort),
            title: filters.sort == YoutiPieSearchSort.relevance ? lang.sortBy : _sortToText(filters.sort),
            isActive: filters.sort != YoutiPieSearchSort.relevance,
            onClear: () => onChanged(filters.copyWith(sort: YoutiPieSearchSort.relevance)),
            items: () => YoutiPieSearchSort.values.map(
              (e) => NamidaPopupItem(
                icon: _sortToIcon(e),
                title: _sortToText(e),
                selected: e == filters.sort,
                onTap: () => onChanged(filters.copyWith(sort: e)),
              ),
            ),
          ),
          _YTSearchFilterChip(
            icon: Broken.calendar,
            title: hasDateRange
                ? _dateRangeToText(filters)
                : filters.uploadDate == YoutiPieSearchUploadDate.none
                ? lang.date
                : _uploadDateToText(filters.uploadDate),
            isActive: isDateActive,
            onClear: () => onChanged(
              filters.copyWith(uploadDate: YoutiPieSearchUploadDate.none, clearAfter: true, clearBefore: true),
              dateRangeChanged: hasDateRange,
            ),
            items: () => [
              ...YoutiPieSearchUploadDate.values.map(
                (e) => NamidaPopupItem(
                  icon: e == YoutiPieSearchUploadDate.none ? Broken.calendar : Broken.clock,
                  title: _uploadDateToText(e),
                  selected: !hasDateRange && e == filters.uploadDate,
                  onTap: () => onChanged(
                    filters.copyWith(uploadDate: e, clearAfter: true, clearBefore: true),
                    dateRangeChanged: hasDateRange,
                  ),
                ),
              ),
              NamidaPopupItem(
                icon: Broken.calendar_search,
                title: '${lang.isAfter}...',
                subtitle: filters.after?.toString() ?? '',
                selected: filters.after != null,
                onTap: () => _pickDate(isAfter: true),
              ),
              NamidaPopupItem(
                icon: Broken.calendar_search,
                title: '${lang.isBefore}...',
                subtitle: filters.before?.toString() ?? '',
                selected: filters.before != null,
                onTap: () => _pickDate(isAfter: false),
              ),
            ],
          ),
          if (!filters.isDefault)
            _YTSearchFilterChip(
              icon: Broken.close_circle,
              title: lang.clear,
              isActive: false,
              onTap: () => onChanged(YoutiPieSearchFilters.defaults, dateRangeChanged: hasDateRange),
            ),
        ],
      ),
    );
  }
}

class _YTSearchFilterChip extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isActive;
  final VoidCallback? onClear;
  final VoidCallback? onTap;
  final Iterable<NamidaPopupItem> Function()? items;

  const _YTSearchFilterChip({
    required this.icon,
    required this.title,
    required this.isActive,
    this.onClear,
    this.onTap,
    this.items,
  });

  void _showMenu(BuildContext context) {
    final items = this.items;
    if (items == null) return;
    NamidaPopupWrapper(childrenDefault: items).showPopupMenu(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final color = isActive ? Colors.white.withOpacityExt(0.8) : null;
    return NamidaInkWell(
      bgColor: isActive ? CurrentColor.inst.color : theme.cardColor,
      borderRadius: 8.0,
      margin: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 6.0),
      padding: const EdgeInsets.only(left: 10.0, right: 6.0),
      animationDurationMS: 200,
      onTap: onTap ?? () => _showMenu(context),
      onLongPress: isActive ? onClear : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16.0, color: color),
          const SizedBox(width: 6.0),
          Text(
            title,
            style: context.textTheme.displaySmall?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
          if (isActive && onClear != null)
            NamidaIconButton(
              horizontalPadding: 4.0,
              verticalPadding: 4.0,
              icon: Broken.close_circle,
              iconSize: 16.0,
              iconColor: color,
              onPressed: onClear,
            )
          else
            const SizedBox(width: 4.0),
        ],
      ),
    );
  }
}

Future<YoutiPieSearchDate?> showYTSearchDateDialog({required String title, YoutiPieSearchDate? initial}) async {
  final controller = TextEditingController(text: initial?.toString() ?? '');
  final formKey = GlobalKey<FormState>();
  YoutiPieSearchDate? result;

  void submit() {
    final parsed = YoutiPieSearchDate.parse(controller.text);
    if (parsed == null) {
      formKey.currentState?.validate();
      return;
    }
    result = parsed;
    NamidaNavigator.inst.closeDialog();
  }

  await NamidaNavigator.inst.navigateDialog(
    onDisposing: controller.dispose,
    dialog: CustomBlurryDialog(
      title: title,
      icon: Broken.calendar_search,
      normalTitleStyle: true,
      actions: [
        const CancelButton(),
        NamidaButton(
          text: lang.confirm,
          onTap: submit,
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.only(top: 12.0),
        child: Form(
          key: formKey,
          child: Row(
            children: [
              Expanded(
                child: CustomTagTextField(
                  controller: controller,
                  hintText: 'YYYY-MM-DD',
                  labelText: title,
                  keyboardType: TextInputType.datetime,
                  validator: (value) => YoutiPieSearchDate.parse(value ?? '') == null ? 'YYYY | YYYY-MM | YYYY-MM-DD' : null,
                  onFieldSubmitted: (_) => submit(),
                ),
              ),
              const SizedBox(width: 8.0),
              NamidaIconButton(
                icon: Broken.calendar,
                onPressed: () {
                  showCalendarDialog(
                    title: title,
                    buttonText: lang.confirm,
                    useHistoryDates: false,
                    calendarType: NamidaCalendarDatePickerType.single,
                    initialDate: initial?.toDateTime(),
                    onGenerate: (dates) {
                      if (dates.isNotEmpty) controller.text = YoutiPieSearchDate.fromDateTime(dates.first).toString();
                      NamidaNavigator.inst.closeDialog();
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return result;
}
