import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart';

import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/packages/three_arched_circle.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/controller/youtube_local_search_controller.dart';
import 'package:namida/youtube/pages/yt_local_search_results.dart';
import 'package:namida/youtube/widgets/yt_channel_card.dart';
import 'package:namida/youtube/widgets/yt_playlist_card.dart';
import 'package:namida/youtube/widgets/yt_video_card.dart';

class YoutubeSearchResultsPage extends StatefulWidget {
  final String searchText;
  final void Function(StreamInfoItem video)? onVideoTap;
  const YoutubeSearchResultsPage({super.key, required this.searchText, this.onVideoTap});

  @override
  State<YoutubeSearchResultsPage> createState() => YoutubeSearchResultsPageState();
}

class YoutubeSearchResultsPageState extends State<YoutubeSearchResultsPage> with AutomaticKeepAliveClientMixin<YoutubeSearchResultsPage> {
  @override
  bool get wantKeepAlive => true;

  String get currentSearchText => _latestSearched ?? widget.searchText;
  String? _latestSearched;

  final _searchResult = <dynamic>[];
  final _isFetchingMoreResults = false.obs;
  bool? _loadingFirstResults;

  List<StreamInfoItem> get _searchResultsLocal => YTLocalSearchController.inst.searchResults;

  int get _maxSearchResultsMini => 100;

  @override
  void initState() {
    super.initState();
    fetchSearch();
    YTLocalSearchController.inst.initializeLookupMap(onSearchDone: () => setState(() {})).then((value) {
      if (currentSearchText != '') {
        YTLocalSearchController.inst.search(currentSearchText, maxResults: _maxSearchResultsMini);
        if (NamidaNavigator.inst.isytLocalSearchInFullPage) {
          NamidaNavigator.inst.ytLocalSearchNavigatorKey?.currentState?.setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    _isFetchingMoreResults.close();
    super.dispose();
  }

  Future<void> fetchSearch({String customText = ''}) async {
    final newSearch = customText == '' ? widget.searchText : customText;
    _latestSearched = newSearch;
    YTLocalSearchController.inst.search(newSearch, maxResults: NamidaNavigator.inst.isytLocalSearchInFullPage ? null : _maxSearchResultsMini);
    _searchResult.clear();
    if (newSearch == '') return;
    if (!ConnectivityController.inst.hasConnection) return;
    if (NamidaNavigator.inst.isytLocalSearchInFullPage) return;

    if (mounted) {
      setState(() {
        _loadingFirstResults = true;
      });
    }
    final result = await YoutubeController.inst.searchForItems(newSearch);
    _searchResult.addAll(result);
    _loadingFirstResults = false;
    if (mounted) setState(() {});
  }

  Future<void> _fetchSearchNextPage() async {
    if (_searchResult.isEmpty) return; // return if still fetching first results.
    if (!ConnectivityController.inst.hasConnection) return;
    _isFetchingMoreResults.value = true;
    final result = await YoutubeController.inst.searchNextPage();
    _isFetchingMoreResults.value = false;
    if (mounted) {
      setState(() {
        _searchResult.addAll(result);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final thumbnailWidth = context.width * 0.36;
    final thumbnailHeight = thumbnailWidth * 9 / 16;
    final thumbnailItemExtent = thumbnailHeight + 8.0 * 2;
    const localMultiplier = 0.7;
    final thumbnailWidthLocal = thumbnailWidth * localMultiplier;
    final thumbnailHeightLocal = thumbnailHeight * localMultiplier;
    final thumbnailItemExtentLocal = thumbnailItemExtent * localMultiplier;
    return BackgroundWrapper(
      child: Navigator(
        key: NamidaNavigator.inst.ytLocalSearchNavigatorKey,
        onPopPage: (route, result) => true,
        requestFocus: false,
        pages: [
          MaterialPage(
            child: LazyLoadListView(
              onReachingEnd: () async => await _fetchSearchNextPage(),
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
                          onTap: () {
                            // if (_isLoadingLocalLookupList.value || currentSearchText == '') return;
                            NamidaNavigator.inst.isytLocalSearchInFullPage = true;
                            NamidaNavigator.inst.ytLocalSearchNavigatorKey?.currentState?.push(
                              GetPageRoute(
                                transition: Transition.cupertino,
                                page: () => YTLocalSearchResults(
                                  initialSearch: currentSearchText,
                                  onVideoTap: widget.onVideoTap,
                                  onPopping: (didChangeSort) {
                                    if (didChangeSort) setState(() {});
                                  },
                                ),
                              ),
                            );
                          },
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
                              Obx(
                                () => YTLocalSearchController.inst.isLoadingLookupLists.value ? const LoadingIndicator() : const SizedBox(),
                              ),
                              const SizedBox(width: 6.0),
                              const Icon(Broken.arrow_right_3),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SliverFixedExtentList.builder(
                      itemExtent: thumbnailItemExtentLocal,
                      itemCount: _searchResultsLocal.length.withMaximum(3),
                      itemBuilder: (context, index) {
                        final item = _searchResultsLocal[index];
                        return YoutubeVideoCard(
                          fontMultiplier: 0.8,
                          thumbnailWidthPercentage: 0.6,
                          thumbnailHeight: thumbnailHeightLocal,
                          thumbnailWidth: thumbnailWidthLocal,
                          isImageImportantInCache: false,
                          video: item,
                          playlistID: null,
                          onTap: widget.onVideoTap == null ? null : () => widget.onVideoTap!(item),
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

                    // -- yt
                    _loadingFirstResults == null
                        ? const SliverToBoxAdapter()
                        : _loadingFirstResults == true
                            ? SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Center(
                                    child: ThreeArchedCircle(
                                      color: CurrentColor.inst.color,
                                      size: context.width * 0.4,
                                    ),
                                  ),
                                ),
                              )
                            : SliverFixedExtentList.builder(
                                itemExtent: thumbnailItemExtent,
                                itemCount: _searchResult.length,
                                itemBuilder: (context, index) {
                                  final item = _searchResult[index];
                                  switch (item.runtimeType) {
                                    case StreamInfoItem:
                                      return YoutubeVideoCard(
                                        thumbnailHeight: thumbnailHeight,
                                        thumbnailWidth: thumbnailWidth,
                                        isImageImportantInCache: false,
                                        video: item,
                                        playlistID: null,
                                        onTap: widget.onVideoTap == null ? null : () => widget.onVideoTap!(item as StreamInfoItem),
                                      );
                                    case YoutubePlaylist:
                                      return YoutubePlaylistCard(
                                        playlist: item,
                                        thumbnailHeight: thumbnailHeight,
                                        thumbnailWidth: thumbnailWidth,
                                      );
                                    case YoutubeChannel:
                                      return YoutubeChannelCard(
                                        channel: item,
                                        thumbnailSize: context.width * 0.18,
                                      );
                                  }
                                  return const SizedBox();
                                },
                              ),
                    SliverToBoxAdapter(
                      child: Obx(
                        () => _isFetchingMoreResults.value
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
